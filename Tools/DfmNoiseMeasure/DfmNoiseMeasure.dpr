{******************************************************************************}
{*                                                                            *}
{* DfmNoiseMeasure - measures the IDE noise left in saved .dfm files          *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

program DfmNoiseMeasure;

/// <summary>
/// Console tool with two commands.  <c>identity &lt;folder&gt;...</c> proves the DFM parser
/// round-trips every text <c>.dfm</c> under the folders byte for byte.  <c>compare &lt;pairs.tsv&gt;
/// [&lt;detail.csv&gt;]</c> compares each old/new pair listed ( made from git history by
/// <c>Export-DfmHistory.py</c> ) and reports the differences by category.  Exit code: 0 done,
/// 1 bad command line, 2 a file failed to round-trip or to parse.
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
  gllDfmCompare in '..\..\Shared\PascalParser\gllDfmCompare.pas';

/// <summary>Prints the command line forms.</summary>
procedure ShowUsage;
begin
  Writeln( 'DfmNoiseMeasure identity <folder> [<folder>...]' );
  Writeln( '  Parses and re-serialises every text .dfm under the folders and reports any that do not come back byte for byte.' );
  Writeln( 'DfmNoiseMeasure compare <pairs.tsv> [<detail.csv>]' );
  Writeln( '  Compares each old/new pair ( columns: repo, commit, date, path, old file, new file ) and reports the differences by category.' );
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
