{******************************************************************************}
{*                                                                            *}
{* DfmNoiseMeasure - measures the IDE noise left in saved .dfm files          *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

program DfmNoiseMeasure;

/// <summary>
/// Console tool with three commands.  <c>identity &lt;folder&gt;...</c> proves the DFM parser
/// round-trips every text <c>.dfm</c> under the folders byte for byte.  <c>compare &lt;pairs.tsv&gt;
/// [&lt;detail.csv&gt;]</c> compares each old/new pair listed ( made from git history by
/// <c>Export-DfmHistory.py</c> ) and reports the differences by category.  <c>links &lt;root&gt;
/// [&lt;pairs.tsv&gt;] [--out &lt;folder&gt;]</c> checks every link to another module has a target and, with
/// pairs, which links past saves lost are still lost ( <c>Check-DfmLinks.ps1</c> runs both steps ).  Exit
/// code: 0 done, 1 bad command line, 2 a file failed to round-trip or to parse, 3 links found broken.
/// </summary>

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.StrUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  gllDelphiDFMParser in '..\..\Shared\PascalParser\gllDelphiDFMParser.pas',
  gllDfmCompare in '..\..\Shared\PascalParser\gllDfmCompare.pas',
  DfmLinkGuardCore in '..\..\Code\DDevExtensions\Source\DfmLinkGuard\DfmLinkGuardCore.pas',
  DfmLinkCheck in 'DfmLinkCheck.pas';

/// <summary>Prints the command line forms.</summary>
procedure ShowUsage;
begin
  Writeln( 'DfmNoiseMeasure identity <folder> [<folder>...]' );
  Writeln( '  Parses and re-serialises every text .dfm under the folders and reports any that do not come back byte for byte.' );
  Writeln( 'DfmNoiseMeasure compare <pairs.tsv> [<detail.csv>]' );
  Writeln( '  Compares each old/new pair ( columns: repo, commit, date, path, old file, new file ) and reports the differences by category.' );
  Writeln( 'DfmNoiseMeasure links <root> [<pairs.tsv>] [--out <folder>] [--files <list.txt>]' );
  Writeln( '  Checks every Module.Component link in the text .dfm files under <root> ( a repository, or a folder whose first-level folders are )' );
  Writeln( '  has a target; with <pairs.tsv>, also runs the DFM Link Guard''s rule over every past save and says which losses' );
  Writeln( '  are still lost.  --out writes links-today.csv and links-history.csv.  --files checks only the .dfm files listed' );
  Writeln( '  ( one full path per line; Check-DfmLinks.ps1 lists the ones git knows ).  Exit code 3 when anything is found.' );
end;

/// <summary>Quotes a value for a CSV field ( declared below ).</summary>
/// <param name="Value">The value.</param>
/// <returns>The quoted field.</returns>
function CsvField( const Value: string ): string; forward;

/// <summary>Today's text of a <c>.dfm</c> file, or empty when it is missing or binary.</summary>
/// <param name="FileName">The file.</param>
/// <returns>The text.</returns>
function TextOfDfm( const FileName: string ): string;
begin
  Result            := '';
  if not FileExists( FileName ) then Exit;
  var aBytes        := TFile.ReadAllBytes( FileName );
  if not IsBinaryDfm( aBytes ) then Result := DfmBytesToText( aBytes );
end;

/// <summary>Runs the links command.</summary>
/// <param name="RootFolder">The folder whose first-level folders are the repositories, or one repository.</param>
/// <param name="PairsFile">The pairs from <c>Export-DfmHistory.py</c> for the same repositories; empty for none.</param>
/// <param name="OutFolder">Where to write the two CSV files; empty for none.</param>
/// <param name="FilesList">A file listing the <c>.dfm</c> files to check, one full path per line; empty to take every <c>.dfm</c> under the root.</param>
/// <returns>0 when every link resolves and no loss is still lost, else 3.  An unreadable past save is only reported.</returns>
function RunLinks( const RootFolder, PairsFile, OutFolder, FilesList: string ): Integer;
begin
  Result            := 0;
  var sRoot         := IncludeTrailingPathDelimiter( TPath.GetFullPath( RootFolder ) );
  // A root that is itself a repository ( GITLAKLib ) is the one repository, named as Export-DfmHistory.py names it.
  var sSingleRepo   := '';
  if DirectoryExists( sRoot + '.git' ) or FileExists( sRoot + '.git' ) then
    sSingleRepo     := ExtractFileName( ExcludeTrailingPathDelimiter( sRoot ) );
  var oIndex        := TDfmModuleIndex.Create;
  var dFiles        := TDictionary<string, string>.Create( TIStringComparer.Ordinal ); // file -> repository
  var slToday       := TStringList.Create;
  var slHistory     := TStringList.Create;
  try
    // Today: index every text .dfm, then check each one's links against the index.  A list of files ( from git:
    // tracked or new, not ignored ) keeps out the copies a build leaves beside its DCUs, which could still
    // declare a component deleted from the real form.
    var aFiles      : TArray<string>;
    if FilesList <> '' then aFiles := TFile.ReadAllLines( FilesList, TEncoding.UTF8 )
    else aFiles     := TDirectory.GetFiles( sRoot, '*.dfm', TSearchOption.soAllDirectories );
    for var sListed in aFiles do
    begin
      if Trim( sListed ) = '' then Continue;
      var sFile     := TPath.GetFullPath( Trim( sListed ) );
      if not StartsText( sRoot, sFile ) or dFiles.ContainsKey( sFile ) then Continue;
      if ContainsText( sFile, '\__history\' ) or ContainsText( sFile, '\__recovery\' ) or ContainsText( sFile, '\.git\' ) then Continue;
      var sText     := TextOfDfm( sFile );
      if sText = '' then Continue;
      var sRepo     := sSingleRepo;
      if sRepo = '' then sRepo := sFile.Substring( Length( sRoot ) ).Split( [ '\' ] )[ 0 ];
      oIndex.Add( sRepo, sText );
      dFiles.Add( sFile, sRepo );
    end;

    // Nothing to check is a failure, not a clean result: an empty list ( git failed ) must not read as all clear.
    if dFiles.Count = 0 then
    begin
      Writeln( 'No text .dfm files to check under ', sRoot, IfThen( FilesList <> '', ' in ' + FilesList, '' ) );
      Exit( 1 );
    end;

    slToday.Add( 'repo,file,component,property,value,problem' );
    var iLinks      := 0;
    for var rFile in dFiles do
    begin
      var iFileLinks: Integer;
      for var rLink in FindDanglingLinks( oIndex, rFile.Value, TextOfDfm( rFile.Key ), iFileLinks ) do
      begin
        var sRel    := rFile.Key.Substring( Length( sRoot ) );
        Writeln( Format( '%-18s %s  %s.%s = %s', [ DanglingKindName( rLink.Kind ), sRel, rLink.Path, rLink.PropName, rLink.Value ] ) );
        slToday.Add( string.Join( ',', [ CsvField( rFile.Value ), CsvField( sRel ), CsvField( rLink.Path ), CsvField( rLink.PropName ),
          CsvField( rLink.Value ), CsvField( DanglingKindName( rLink.Kind ) ) ] ) );
      end;
      Inc( iLinks, iFileLinks );
    end;
    var iDangling   := slToday.Count - 1;
    Writeln( Format( 'Today: %d text .dfm files, %d modules, %d links to another module, %d without a target',
      [ dFiles.Count, oIndex.ModuleCount, iLinks, iDangling ] ) );
    if iDangling > 0 then Result := 3;

    // History: the guard's rule on every past save, each loss checked against today's file.
    if PairsFile <> '' then
    begin
      var sBase     := ExtractFilePath( TPath.GetFullPath( PairsFile ) );
      var iPairs    := 0;
      var iFailed   := 0;
      var iStill    := 0;
      slHistory.Add( 'repo,commit,date,path,component,property,value,today' );
      for var sLine in TFile.ReadAllLines( PairsFile, TEncoding.UTF8 ) do
      begin
        var aCols   := sLine.Split( [ #9 ] );
        if ( Length( aCols ) < 6 ) or SameText( aCols[ 0 ], 'repo' ) then Continue;
        Inc( iPairs );
        var sRepo   := aCols[ 0 ];
        var sOldFile := TPath.Combine( sBase, aCols[ 4 ] );
        var sNewFile := TPath.Combine( sBase, aCols[ 5 ] );
        if not FileExists( sOldFile ) or not FileExists( sNewFile ) then
        begin
          Inc( iFailed );
          Writeln( 'FAILED  ', sRepo, ' ', aCols[ 1 ], ' ', aCols[ 3 ], ': a file of the pair is missing ( ', aCols[ 4 ], ', ', aCols[ 5 ], ' )' );
          Continue;
        end;
        var aOld    := TFile.ReadAllBytes( sOldFile );
        var aNew    := TFile.ReadAllBytes( sNewFile );
        if IsBinaryDfm( aOld ) or IsBinaryDfm( aNew ) then Continue;
        var aLost   : TArray<TDfmLostLink>;
        try
          aLost     := FindLostModuleLinks( DfmBytesToText( aOld ), DfmBytesToText( aNew ),
            function( const ModuleName, ComponentName: string ): Boolean
            begin
              Result := oIndex.TargetExists( sRepo, ModuleName, ComponentName );
            end );
        except
          on E: EDfmCompareError do
          begin
            Inc( iFailed );
            Writeln( 'FAILED  ', sRepo, ' ', aCols[ 1 ], ' ', aCols[ 3 ], ': ', E.Message );
            Continue;
          end;
        end;
        if aLost = nil then Continue;

        var sRepoFolder := sRoot + sRepo;
        if sSingleRepo <> '' then sRepoFolder := sRoot;
        var sToday  := TextOfDfm( TPath.Combine( sRepoFolder, StringReplace( aCols[ 3 ], '/', '\', [ rfReplaceAll ] ) ) );
        for var rLink in aLost do
        begin
          var eState := LossToday( rLink, sToday );
          if eState = ltStillLost then
          begin
            Inc( iStill );
            Writeln( Format( 'STILL LOST  %s %s %s  %s.%s = %s', [ sRepo, aCols[ 2 ], aCols[ 3 ], rLink.Path, rLink.PropName, rLink.Value ] ) );
          end;
          slHistory.Add( string.Join( ',', [ CsvField( sRepo ), CsvField( aCols[ 1 ] ), CsvField( aCols[ 2 ] ), CsvField( aCols[ 3 ] ),
            CsvField( rLink.Path ), CsvField( rLink.PropName ), CsvField( rLink.Value ), CsvField( LossTodayName( eState ) ) ] ) );
        end;
      end;
      Writeln( Format( 'History: %d saves, %d links the DFM Link Guard would have reported, %d still lost today, %d saves unreadable',
        [ iPairs, slHistory.Count - 1, iStill, iFailed ] ) );
      // An unreadable past save is reported but does not set the exit code: history cannot change, so it would
      // fail every later run.
      if iStill > 0 then Result := 3;
    end;

    if OutFolder <> '' then
    begin
      ForceDirectories( OutFolder );
      slToday.SaveToFile( TPath.Combine( OutFolder, 'links-today.csv' ), TEncoding.UTF8 );
      if PairsFile <> '' then slHistory.SaveToFile( TPath.Combine( OutFolder, 'links-history.csv' ), TEncoding.UTF8 );
    end;
  finally
    slHistory.Free;
    slToday.Free;
    dFiles.Free;
    oIndex.Free;
  end;
end;

/// <summary>Runs the identity command over the given folders.</summary>
/// <param name="Folders">The folders to search, recursively.</param>
/// <returns>0 when every text DFM round-trips, else 2.</returns>
function RunIdentity( const Folders: TArray<string> ): Integer;
begin
  var iText         := 0;
  var iBinary       := 0;
  var iFailed       := 0;
  for var sFolder in Folders do
    for var sFile in TDirectory.GetFiles( sFolder, '*.dfm', TSearchOption.soAllDirectories ) do
    begin
      var aBytes    := TFile.ReadAllBytes( sFile );
      if IsBinaryDfm( aBytes ) then
      begin
        Inc( iBinary );
        Continue;
      end;
      Inc( iText );
      var sDifference: string;
      if not RoundTripsExactly( aBytes, sDifference ) then
      begin
        Inc( iFailed );
        Writeln( 'DIFFERS  ', sFile, '  ', sDifference );
      end;
    end;
  Writeln( Format( 'Text DFMs: %d   round-trip exact: %d   differ: %d   binary skipped: %d', [ iText, iText - iFailed, iFailed, iBinary ] ) );
  if iFailed = 0 then Result := 0 else Result := 2;
end;

/// <summary>Quotes a value for a CSV field: doubles quotes, flattens line breaks, cuts very long values.</summary>
/// <param name="Value">The value.</param>
/// <returns>The quoted field.</returns>
function CsvField( const Value: string ): string;
begin
  var sValue        := StringReplace( StringReplace( Value, #13#10, '\n', [ rfReplaceAll ] ), #10, '\n', [ rfReplaceAll ] );
  if Length( sValue ) > 200 then sValue := Copy( sValue, 1, 200 ) + '...';
  Result            := '"' + StringReplace( sValue, '"', '""', [ rfReplaceAll ] ) + '"';
end;

/// <summary>Runs the compare command.</summary>
/// <param name="PairsFile">The tab-separated list of pairs.</param>
/// <param name="DetailFile">Where to write one CSV row per change; empty for none.</param>
/// <returns>0 when every pair was compared, else 2.</returns>
function RunCompare( const PairsFile, DetailFile: string ): Integer;
type
  TCount = record
    Files: Integer;
    Changes: Integer;
  end;
begin
  Result            := 0;
  var sBase         := ExtractFilePath( TPath.GetFullPath( PairsFile ) );
  var aCounts: array[ TDfmNoiseCategory, TDfmChangeKind ] of TCount;
  FillChar( aCounts, SizeOf( aCounts ), 0 );
  var dOther        := TDictionary<string, Integer>.Create;
  var slDetail      := TStringList.Create;
  try
    slDetail.Add( 'repo,commit,date,path,component,property,kind,category,old,new' );
    var iPairs      := 0;
    var iSkipped    := 0;
    var iUnchanged  := 0;
    var iNoiseOnly  := 0;
    var iFailed     := 0;

    for var sLine in TFile.ReadAllLines( PairsFile, TEncoding.UTF8 ) do
    begin
      var aCols     := sLine.Split( [ #9 ] );
      if ( Length( aCols ) < 6 ) or SameText( aCols[ 0 ], 'repo' ) then Continue;
      Inc( iPairs );
      var aOld      := TFile.ReadAllBytes( TPath.Combine( sBase, aCols[ 4 ] ) );
      var aNew      := TFile.ReadAllBytes( TPath.Combine( sBase, aCols[ 5 ] ) );
      if IsBinaryDfm( aOld ) or IsBinaryDfm( aNew ) then
      begin
        Inc( iSkipped );
        Continue;
      end;

      var aChanges: TArray<TDfmChange>;
      try
        aChanges    := CompareDfmText( DfmBytesToText( aOld ), DfmBytesToText( aNew ) );
      except
        on E: Exception do
        begin
          Inc( iFailed );
          Writeln( 'FAILED  ', aCols[ 0 ], ' ', aCols[ 1 ], ' ', aCols[ 3 ], ': ', E.Message );
          Continue;
        end;
      end;

      if Length( aChanges ) = 0 then
      begin
        Inc( iUnchanged );
        Continue;
      end;

      var bNoiseOnly := True;
      var aSeen: array[ TDfmNoiseCategory, TDfmChangeKind ] of Boolean;
      FillChar( aSeen, SizeOf( aSeen ), 0 );
      for var rChange in aChanges do
      begin
        Inc( aCounts[ rChange.Category, rChange.Kind ].Changes );
        if not aSeen[ rChange.Category, rChange.Kind ] then
        begin
          aSeen[ rChange.Category, rChange.Kind ] := True;
          Inc( aCounts[ rChange.Category, rChange.Kind ].Files );
        end;
        if not IsKnownIdeNoise( rChange.Category ) then bNoiseOnly := False;
        if rChange.Category = ncOther then
        begin
          var sKey  := rChange.PropName + ' (' + ChangeKindName( rChange.Kind ) + ')';
          var iCount: Integer;
          if not dOther.TryGetValue( sKey, iCount ) then iCount := 0;
          dOther.AddOrSetValue( sKey, iCount + 1 );
        end;
        slDetail.Add( string.Join( ',', [ CsvField( aCols[ 0 ] ), CsvField( aCols[ 1 ] ), CsvField( aCols[ 2 ] ), CsvField( aCols[ 3 ] ),
          CsvField( rChange.Path ), CsvField( rChange.PropName ), CsvField( ChangeKindName( rChange.Kind ) ),
          CsvField( CategoryName( rChange.Category ) ), CsvField( rChange.OldValue ), CsvField( rChange.NewValue ) ] ) );
      end;
      if bNoiseOnly then Inc( iNoiseOnly );
    end;

    Writeln( Format( 'Pairs: %d   compared: %d   no structural change: %d   binary skipped: %d   failed: %d',
      [ iPairs, iPairs - iSkipped - iFailed, iUnchanged, iSkipped, iFailed ] ) );
    Writeln( Format( 'Pairs whose ONLY changes are known IDE noise: %d', [ iNoiseOnly ] ) );
    Writeln;
    Writeln( Format( '%-32s %-22s %8s %8s', [ 'Category', 'Kind', 'Pairs', 'Changes' ] ) );
    for var eCategory := Low( TDfmNoiseCategory ) to High( TDfmNoiseCategory ) do
      for var eKind := Low( TDfmChangeKind ) to High( TDfmChangeKind ) do
        if aCounts[ eCategory, eKind ].Changes > 0 then
          Writeln( Format( '%-32s %-22s %8d %8d', [ CategoryName( eCategory ) + IfThen( IsKnownIdeNoise( eCategory ), ' *', '' ),
            ChangeKindName( eKind ), aCounts[ eCategory, eKind ].Files, aCounts[ eCategory, eKind ].Changes ] ) );
    Writeln( '  * known IDE noise' );

    Writeln;
    Writeln( 'Most frequent "Other" changes:' );
    var aOther      := dOther.ToArray;
    TArray.Sort<TPair<string, Integer>>( aOther, TComparer<TPair<string, Integer>>.Construct(
      function( const Left, Right: TPair<string, Integer> ): Integer
      begin
        Result      := Right.Value - Left.Value;
        if Result = 0 then Result := CompareText( Left.Key, Right.Key );
      end ) );
    for var I := 0 to High( aOther ) do
    begin
      if I >= 30 then Break;
      Writeln( Format( '%8d  %s', [ aOther[ I ].Value, aOther[ I ].Key ] ) );
    end;

    if DetailFile <> '' then slDetail.SaveToFile( DetailFile, TEncoding.UTF8 );
    if iFailed > 0 then Result := 2;
  finally
    slDetail.Free;
    dOther.Free;
  end;
end;

begin
  try
    if ( ParamCount >= 2 ) and SameText( ParamStr( 1 ), 'identity' ) then
    begin
      var aFolders: TArray<string> := nil;
      for var I := 2 to ParamCount do
        aFolders    := aFolders + [ ParamStr( I ) ];
      ExitCode      := RunIdentity( aFolders );
    end
    else if ( ParamCount in [ 2, 3 ] ) and SameText( ParamStr( 1 ), 'compare' ) then
    begin
      var sDetail   := '';
      if ParamCount = 3 then sDetail := ParamStr( 3 );
      ExitCode      := RunCompare( ParamStr( 2 ), sDetail );
    end
    else if ( ParamCount >= 2 ) and SameText( ParamStr( 1 ), 'links' ) then
    begin
      var sPairs    := '';
      var sOut      := '';
      var sFiles    := '';
      var bBad      := False;
      var I         := 3;
      while I <= ParamCount do
      begin
        if SameText( ParamStr( I ), '--out' ) and ( I < ParamCount ) then
        begin
          sOut      := ParamStr( I + 1 );
          Inc( I );
        end
        else if SameText( ParamStr( I ), '--files' ) and ( I < ParamCount ) then
        begin
          sFiles    := ParamStr( I + 1 );
          Inc( I );
        end
        else if sPairs = '' then sPairs := ParamStr( I )
        else bBad   := True;
        Inc( I );
      end;
      if bBad then
      begin
        ShowUsage;
        ExitCode    := 1;
      end
      else
        ExitCode    := RunLinks( ParamStr( 2 ), sPairs, sOut, sFiles );
    end
    else
    begin
      ShowUsage;
      ExitCode      := 1;
    end;
  except
    on E: Exception do
    begin
      Writeln( E.ClassName, ': ', E.Message );
      ExitCode      := 2;
    end;
  end;
end.
