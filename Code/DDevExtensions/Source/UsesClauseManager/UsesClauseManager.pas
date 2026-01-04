{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit UsesClauseManager;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Variants, Generics.Collections, Menus,
  ToolsAPI, FrmTreePages, PluginConfig, Main;

type
  TUsesSection = ( usInterface, usImplementation );

  TExportKind = ( ekType, ekProcedure, ekFunction, ekConst, ekVar );

  TUnitExport = record
    Identifier: string;
    Kind: TExportKind;
  end;

  TUnitPlacement = record
    UnitName: string;
    CurrentSection: TUsesSection;
    RecommendedSection: TUsesSection;
    Reason: string;
    IdentifiersUsedInInterface: TStringList;
    IdentifiersUsedInImplementation: TStringList;
  end;

  /// <summary>
  /// Database of what identifiers each unit exports.
  /// Built by scanning interface sections of units in the search path.
  /// </summary>
  TUnitExportsDatabase = class
  private
    FExports: TDictionary<string, TList<TUnitExport>>;
    FIdentifierToUnits: TDictionary<string, TStringList>;  // Reverse lookup: identifier -> units
    FRTLVCLPriority: TStringList;  // Priority order for RTL/VCL units
    FProgressFileName: string;
    procedure ScanUnit( const UnitPath: string );
    procedure BuildRTLVCLPriority;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure BuildFromSearchPath( Project: IOTAProject; OnProgress: TNotifyEvent );
    function GetExports( const UnitName: string ): TList<TUnitExport>;
    function FindUnitsForIdentifier( const Identifier: string ): TStringList;
    function GetPreferredUnit( const Identifier: string; const CandidateUnits: TStringList ): string;
    function GetUnitCount: Integer;
    property ProgressFileName: string read FProgressFileName;
    property UnitCount: Integer read GetUnitCount;
  end;

  TUsedUnitInfo = record
    UnitName: string;
    Section: TUsesSection;
    LineNumber: Integer;
  end;

  /// <summary>
  /// Analyzes which identifiers are used in interface vs implementation sections.
  /// </summary>
  TIdentifierUsageAnalyzer = class
  private
    FInterfaceIdentifiers: TStringList;
    FImplementationIdentifiers: TStringList;
    FQualifiedReferences: TDictionary<string, string>;  // Identifier -> QualifyingUnit
    FInterfaceUsedUnits: TList<TUsedUnitInfo>;
    FImplementationUsedUnits: TList<TUsedUnitInfo>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Analyze( const Source: UTF8String );
    procedure Clear;
    property InterfaceIdentifiers: TStringList read FInterfaceIdentifiers;
    property ImplementationIdentifiers: TStringList read FImplementationIdentifiers;
    property QualifiedReferences: TDictionary<string, string> read FQualifiedReferences;
    property InterfaceUsedUnits: TList<TUsedUnitInfo> read FInterfaceUsedUnits;
    property ImplementationUsedUnits: TList<TUsedUnitInfo> read FImplementationUsedUnits;
  end;

  /// <summary>
  /// Refactors uses clauses based on analysis results.
  /// </summary>
  TUsesClauseRefactorer = class
  private
    FExportsDB: TUnitExportsDatabase;
    FUsageAnalyzer: TIdentifierUsageAnalyzer;
  public
    constructor Create( AExportsDB: TUnitExportsDatabase );
    destructor Destroy; override;
    function Analyze( const Source: UTF8String ): TArray<TUnitPlacement>;
    function GenerateRefactoredSource( const Source: UTF8String;
      const Placements: TArray<TUnitPlacement> ): UTF8String;
  end;

  TUsesClauseManagerPlugin = class( TPluginConfig )
  private
    FEnabled: Boolean;
    FMenuItem: TMenuItem;
    FExportsDB: TUnitExportsDatabase;
    procedure MenuItemClick( Sender: TObject );
  protected
    function GetOptionPages: TTreePage; override;
    procedure Init; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ShowManager;
    property ExportsDB: TUnitExportsDatabase read FExportsDB;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

procedure InitPlugin( Unload: Boolean );

var
  UsesClauseManagerPlugin: TUsesClauseManagerPlugin;

implementation

uses
  Forms, Controls, ToolsAPIHelpers, AppConsts, DelphiLexer,
  FrmUsesClauseManager, FrmeOptionPageUsesClause;

{ TUnitExportsDatabase }

constructor TUnitExportsDatabase.Create;
begin
  inherited Create;
  FExports := TDictionary<string, TList<TUnitExport>>.Create;
  FIdentifierToUnits := TDictionary<string, TStringList>.Create;
  FRTLVCLPriority := TStringList.Create;
  FRTLVCLPriority.CaseSensitive := False;
  BuildRTLVCLPriority;
end;

destructor TUnitExportsDatabase.Destroy;
begin
  Clear;
  FExports.Free;
  FIdentifierToUnits.Free;
  FRTLVCLPriority.Free;
  inherited Destroy;
end;

procedure TUnitExportsDatabase.BuildRTLVCLPriority;
begin
  // RTL/VCL units in priority order - these take precedence when
  // the same identifier is exported by multiple units
  FRTLVCLPriority.Add( 'System' );
  FRTLVCLPriority.Add( 'SysUtils' );
  FRTLVCLPriority.Add( 'Classes' );
  FRTLVCLPriority.Add( 'Types' );
  FRTLVCLPriority.Add( 'TypInfo' );
  FRTLVCLPriority.Add( 'Windows' );
  FRTLVCLPriority.Add( 'Messages' );
  FRTLVCLPriority.Add( 'Vcl.Forms' );
  FRTLVCLPriority.Add( 'Forms' );
  FRTLVCLPriority.Add( 'Vcl.Controls' );
  FRTLVCLPriority.Add( 'Controls' );
  FRTLVCLPriority.Add( 'Vcl.StdCtrls' );
  FRTLVCLPriority.Add( 'StdCtrls' );
  FRTLVCLPriority.Add( 'Vcl.ExtCtrls' );
  FRTLVCLPriority.Add( 'ExtCtrls' );
  FRTLVCLPriority.Add( 'Vcl.Graphics' );
  FRTLVCLPriority.Add( 'Graphics' );
  FRTLVCLPriority.Add( 'Vcl.Dialogs' );
  FRTLVCLPriority.Add( 'Dialogs' );
  FRTLVCLPriority.Add( 'Vcl.Menus' );
  FRTLVCLPriority.Add( 'Menus' );
  FRTLVCLPriority.Add( 'Vcl.ComCtrls' );
  FRTLVCLPriority.Add( 'ComCtrls' );
  FRTLVCLPriority.Add( 'Vcl.Grids' );
  FRTLVCLPriority.Add( 'Grids' );
  FRTLVCLPriority.Add( 'Data.DB' );
  FRTLVCLPriority.Add( 'DB' );
  FRTLVCLPriority.Add( 'Generics.Collections' );
  FRTLVCLPriority.Add( 'Generics.Defaults' );
  FRTLVCLPriority.Add( 'System.IOUtils' );
  FRTLVCLPriority.Add( 'System.JSON' );
  FRTLVCLPriority.Add( 'System.RegularExpressions' );
end;

procedure TUnitExportsDatabase.Clear;
var
  Pair: TPair<string, TList<TUnitExport>>;
  Pair2: TPair<string, TStringList>;
begin
  for Pair in FExports do
    Pair.Value.Free;
  FExports.Clear;

  for Pair2 in FIdentifierToUnits do
    Pair2.Value.Free;
  FIdentifierToUnits.Clear;
end;

procedure TUnitExportsDatabase.ScanUnit( const UnitPath: string );
var
  Source: UTF8String;
  Lexer: TDelphiLexer;
  Token: TToken;
  UnitName: string;
  InInterface: Boolean;
  InType, InConst, InVar: Boolean;
  BraceDepth: Integer;
  Export: TUnitExport;
  ExportList: TList<TUnitExport>;
  UnitList: TStringList;
  LowerIdent: string;
begin
  if not FileExists( UnitPath ) then
    Exit;

  try
    Source := LoadTextFileToUtf8String( UnitPath, 0 );
  except
    Exit;
  end;

  UnitName := ChangeFileExt( ExtractFileName( UnitPath ), '' );
  ExportList := TList<TUnitExport>.Create;

  Lexer := TDelphiLexer.Create( UnitPath, Source );
  try
    InInterface := False;
    InType := False;
    InConst := False;
    InVar := False;
    BraceDepth := 0;

    while Lexer.NextToken( Token ) do
    begin
      // Skip comments and directives
      if Token.Kind in [ tkComment, tkDirective ] then
        Continue;

      // Track interface/implementation sections
      if Token.Kind = tkI_interface then
      begin
        InInterface := True;
        Continue;
      end;

      if Token.Kind = tkI_implementation then
        Break;  // Stop at implementation

      if not InInterface then
        Continue;

      // Track section keywords
      if Token.Kind = tkI_type then
      begin
        InType := True;
        InConst := False;
        InVar := False;
        Continue;
      end;

      if Token.Kind = tkI_const then
      begin
        InType := False;
        InConst := True;
        InVar := False;
        Continue;
      end;

      if Token.Kind = tkI_var then
      begin
        InType := False;
        InConst := False;
        InVar := True;
        Continue;
      end;

      // End of section
      if Token.Kind in [ tkI_procedure, tkI_function, tkI_uses ] then
      begin
        InType := False;
        InConst := False;
        InVar := False;
      end;

      // Track brace depth for skipping nested declarations
      if Token.Kind = tkLParan then
        Inc( BraceDepth )
      else if Token.Kind = tkRParan then
        Dec( BraceDepth );

      if BraceDepth > 0 then
        Continue;

      // Collect exports based on current section
      if Token.Kind >= tkIdent then  // Identifier tokens
      begin
        if InType then
        begin
          Export.Identifier := Token.Value;
          Export.Kind := ekType;
          ExportList.Add( Export );
        end
        else if InConst then
        begin
          Export.Identifier := Token.Value;
          Export.Kind := ekConst;
          ExportList.Add( Export );
        end
        else if InVar then
        begin
          Export.Identifier := Token.Value;
          Export.Kind := ekVar;
          ExportList.Add( Export );
        end;
      end;

      // Procedures and functions
      if Token.Kind = tkI_procedure then
      begin
        if Lexer.NextToken( Token ) and ( Token.Kind >= tkIdent ) then
        begin
          Export.Identifier := Token.Value;
          Export.Kind := ekProcedure;
          ExportList.Add( Export );
        end;
      end
      else if Token.Kind = tkI_function then
      begin
        if Lexer.NextToken( Token ) and ( Token.Kind >= tkIdent ) then
        begin
          Export.Identifier := Token.Value;
          Export.Kind := ekFunction;
          ExportList.Add( Export );
        end;
      end;
    end;

    // Store in exports dictionary
    if ExportList.Count > 0 then
    begin
      FExports.Add( LowerCase( UnitName ), ExportList );

      // Build reverse lookup
      for Export in ExportList do
      begin
        LowerIdent := LowerCase( Export.Identifier );
        if not FIdentifierToUnits.TryGetValue( LowerIdent, UnitList ) then
        begin
          UnitList := TStringList.Create;
          UnitList.CaseSensitive := False;
          UnitList.Duplicates := dupIgnore;
          FIdentifierToUnits.Add( LowerIdent, UnitList );
        end;
        UnitList.Add( UnitName );
      end;
    end
    else
      ExportList.Free;
  finally
    Lexer.Free;
  end;
end;

procedure TUnitExportsDatabase.BuildFromSearchPath( Project: IOTAProject;
  OnProgress: TNotifyEvent );
var
  I: Integer;
  Options: IOTAProjectOptions;
  SearchPath: string;
  Paths: TStringList;
  SR: TSearchRec;
  Path: string;
begin
  Clear;

  if Project = nil then
    Exit;

  Paths := TStringList.Create;
  try
    // Add project directory
    Paths.Add( ExtractFileDir( Project.FileName ) );

    // Get search paths from project options
    Options := Project.ProjectOptions;
    if Options <> nil then
    begin
      SearchPath := VarToStr( Options.Values[ 'UnitDir' ] );
      Paths.Delimiter := ';';
      Paths.StrictDelimiter := True;
      Paths.DelimitedText := SearchPath;
    end;

    // Scan all .pas files in search paths
    for I := 0 to Paths.Count - 1 do
    begin
      Path := ExpandFileName( Trim( Paths[ I ] ) );
      if not DirectoryExists( Path ) then
        Continue;

      if FindFirst( IncludeTrailingPathDelimiter( Path ) + '*.pas', faAnyFile, SR ) = 0 then
      try
        repeat
          FProgressFileName := SR.Name;
          if Assigned( OnProgress ) then
            OnProgress( Self );

          ScanUnit( IncludeTrailingPathDelimiter( Path ) + SR.Name );
        until FindNext( SR ) <> 0;
      finally
        FindClose( SR );
      end;
    end;
  finally
    Paths.Free;
  end;
end;

function TUnitExportsDatabase.GetExports( const UnitName: string ): TList<TUnitExport>;
begin
  if not FExports.TryGetValue( LowerCase( UnitName ), Result ) then
    Result := nil;
end;

function TUnitExportsDatabase.FindUnitsForIdentifier( const Identifier: string ): TStringList;
begin
  if not FIdentifierToUnits.TryGetValue( LowerCase( Identifier ), Result ) then
    Result := nil;
end;

function TUnitExportsDatabase.GetPreferredUnit( const Identifier: string;
  const CandidateUnits: TStringList ): string;
var
  I, J: Integer;
  LowerUnit: string;
begin
  Result := '';
  if ( CandidateUnits = nil ) or ( CandidateUnits.Count = 0 ) then
    Exit;

  if CandidateUnits.Count = 1 then
  begin
    Result := CandidateUnits[ 0 ];
    Exit;
  end;

  // Check RTL/VCL priority list
  for I := 0 to FRTLVCLPriority.Count - 1 do
  begin
    LowerUnit := LowerCase( FRTLVCLPriority[ I ] );
    for J := 0 to CandidateUnits.Count - 1 do
    begin
      if SameText( CandidateUnits[ J ], FRTLVCLPriority[ I ] ) then
      begin
        Result := CandidateUnits[ J ];
        Exit;
      end;
    end;
  end;

  // Default to first candidate
  Result := CandidateUnits[ 0 ];
end;

function TUnitExportsDatabase.GetUnitCount: Integer;
begin
  Result := FExports.Count;
end;

{ TIdentifierUsageAnalyzer }

constructor TIdentifierUsageAnalyzer.Create;
begin
  inherited Create;
  FInterfaceIdentifiers := TStringList.Create;
  FInterfaceIdentifiers.CaseSensitive := False;
  FInterfaceIdentifiers.Sorted := True;
  FInterfaceIdentifiers.Duplicates := dupIgnore;

  FImplementationIdentifiers := TStringList.Create;
  FImplementationIdentifiers.CaseSensitive := False;
  FImplementationIdentifiers.Sorted := True;
  FImplementationIdentifiers.Duplicates := dupIgnore;

  FQualifiedReferences := TDictionary<string, string>.Create;
  FInterfaceUsedUnits := TList<TUsedUnitInfo>.Create;
  FImplementationUsedUnits := TList<TUsedUnitInfo>.Create;
end;

destructor TIdentifierUsageAnalyzer.Destroy;
begin
  FInterfaceIdentifiers.Free;
  FImplementationIdentifiers.Free;
  FQualifiedReferences.Free;
  FInterfaceUsedUnits.Free;
  FImplementationUsedUnits.Free;
  inherited Destroy;
end;

procedure TIdentifierUsageAnalyzer.Clear;
begin
  FInterfaceIdentifiers.Clear;
  FImplementationIdentifiers.Clear;
  FQualifiedReferences.Clear;
  FInterfaceUsedUnits.Clear;
  FImplementationUsedUnits.Clear;
end;

procedure TIdentifierUsageAnalyzer.Analyze( const Source: UTF8String );
var
  Lexer: TDelphiLexer;
  Token, NextToken: TToken;
  InInterface, InImplementation: Boolean;
  InUses: Boolean;
  CurrentIdentList: TStringList;
  CurrentUnitList: TList<TUsedUnitInfo>;
  UsedUnit: TUsedUnitInfo;
  PrevIdentifier: string;
  TokenList: TList<TToken>;
  I: Integer;
begin
  Clear;

  // First pass: collect all tokens
  // IMPORTANT: TToken is a class owned by the lexer - don't free lexer until done!
  TokenList := TList<TToken>.Create;
  Lexer := TDelphiLexer.Create( '', Source );
  try
    while Lexer.NextToken( Token ) do
    begin
      // Skip comments but keep directives for tracking
      if Token.Kind = tkComment then
        Continue;
      TokenList.Add( Token );
    end;

    // Second pass: analyze tokens (must be inside lexer's try block)
    InInterface := False;
    InImplementation := False;
    InUses := False;
    CurrentIdentList := nil;
    CurrentUnitList := nil;
    PrevIdentifier := '';
    I := 0;

    while I < TokenList.Count do
    begin
      Token := TokenList[ I ];

      // Skip directives
      if Token.Kind = tkDirective then
      begin
        Inc( I );
        Continue;
      end;

      // Track sections
      if Token.Kind = tkI_interface then
      begin
        InInterface := True;
        InImplementation := False;
        CurrentIdentList := FInterfaceIdentifiers;
        CurrentUnitList := FInterfaceUsedUnits;
        Inc( I );
        Continue;
      end;

      if Token.Kind = tkI_implementation then
      begin
        InInterface := False;
        InImplementation := True;
        CurrentIdentList := FImplementationIdentifiers;
        CurrentUnitList := FImplementationUsedUnits;
        Inc( I );
        Continue;
      end;

      // Track uses clauses - extract unit names
      if Token.Kind = tkI_uses then
      begin
        InUses := True;
        Inc( I );
        Continue;
      end;

      if InUses then
      begin
        if Token.Kind = tkSemicolon then
        begin
          InUses := False;
          Inc( I );
          Continue;
        end;

        // Collect unit names in uses clause
        if ( Token.Kind >= tkIdent ) and ( CurrentUnitList <> nil ) then
        begin
          UsedUnit.UnitName := Token.Value;

          // Handle dotted unit names (e.g., System.SysUtils)
          while ( I + 2 < TokenList.Count ) and ( TokenList[ I + 1 ].Kind = tkDot ) do
          begin
            UsedUnit.UnitName := UsedUnit.UnitName + '.' + TokenList[ I + 2 ].Value;
            Inc( I, 2 );
          end;

          if InInterface and not InImplementation then
            UsedUnit.Section := usInterface
          else
            UsedUnit.Section := usImplementation;

          UsedUnit.LineNumber := Token.Line;
          CurrentUnitList.Add( UsedUnit );
        end;

        Inc( I );
        Continue;
      end;

      // Collect identifiers outside of uses clauses
      if ( CurrentIdentList <> nil ) and ( Token.Kind >= tkIdent ) then
      begin
        // Check for qualified reference: Identifier.Something
        if ( I + 1 < TokenList.Count ) and ( TokenList[ I + 1 ].Kind = tkDot ) then
        begin
          // This might be a qualified reference like SysUtils.Format
          // Record it as a qualified reference
          if I + 2 < TokenList.Count then
          begin
            NextToken := TokenList[ I + 2 ];
            if NextToken.Kind >= tkIdent then
            begin
              // Record: NextToken.Value came from Token.Value unit
              FQualifiedReferences.AddOrSetValue( LowerCase( NextToken.Value ), Token.Value );
            end;
          end;

          // Also add the unit name itself as a used identifier
          CurrentIdentList.Add( Token.Value );
        end
        else
        begin
          // Regular identifier - add it
          CurrentIdentList.Add( Token.Value );
        end;
      end;

      Inc( I );
    end;
  finally
    TokenList.Free;
    Lexer.Free;  // Free lexer AFTER processing all tokens
  end;
end;

{ TUsesClauseRefactorer }

constructor TUsesClauseRefactorer.Create( AExportsDB: TUnitExportsDatabase );
begin
  inherited Create;
  FExportsDB := AExportsDB;
  FUsageAnalyzer := TIdentifierUsageAnalyzer.Create;
end;

destructor TUsesClauseRefactorer.Destroy;
begin
  FUsageAnalyzer.Free;
  inherited Destroy;
end;

function TUsesClauseRefactorer.Analyze( const Source: UTF8String ): TArray<TUnitPlacement>;
var
  ResultList: TList<TUnitPlacement>;
  UsedUnit: TUsedUnitInfo;
  Placement: TUnitPlacement;
  UnitExports: TList<TUnitExport>;
  Export: TUnitExport;
  I: Integer;
  LowerUnitName, LowerIdent: string;
  UsedInInterface, UsedInImplementation: Boolean;
  QualifyingUnit: string;
  CandidateUnits: TStringList;
  AllUnits: TDictionary<string, TUsedUnitInfo>;
begin
  // Step 1: Analyze the source to extract uses clauses and identifier usage
  FUsageAnalyzer.Analyze( Source );

  ResultList := TList<TUnitPlacement>.Create;
  AllUnits := TDictionary<string, TUsedUnitInfo>.Create;
  try
    // Collect all units from both interface and implementation uses clauses
    for UsedUnit in FUsageAnalyzer.InterfaceUsedUnits do
      AllUnits.AddOrSetValue( LowerCase( UsedUnit.UnitName ), UsedUnit );

    for UsedUnit in FUsageAnalyzer.ImplementationUsedUnits do
      if not AllUnits.ContainsKey( LowerCase( UsedUnit.UnitName ) ) then
        AllUnits.AddOrSetValue( LowerCase( UsedUnit.UnitName ), UsedUnit );

    // Step 2: For each unit in uses clauses, determine optimal placement
    for UsedUnit in FUsageAnalyzer.InterfaceUsedUnits do
    begin
      Placement.UnitName := UsedUnit.UnitName;
      Placement.CurrentSection := usInterface;
      Placement.IdentifiersUsedInInterface := TStringList.Create;
      Placement.IdentifiersUsedInImplementation := TStringList.Create;

      LowerUnitName := LowerCase( UsedUnit.UnitName );
      // Also handle dotted names - get just the last part for matching
      if Pos( '.', LowerUnitName ) > 0 then
        LowerUnitName := LowerCase( Copy( UsedUnit.UnitName, LastDelimiter( '.', UsedUnit.UnitName ) + 1, MaxInt ) );

      UsedInInterface := False;
      UsedInImplementation := False;

      // Check for qualified references to this unit (e.g., SysUtils.Format)
      for I := 0 to FUsageAnalyzer.InterfaceIdentifiers.Count - 1 do
      begin
        if SameText( FUsageAnalyzer.InterfaceIdentifiers[ I ], UsedUnit.UnitName ) or
           SameText( FUsageAnalyzer.InterfaceIdentifiers[ I ], LowerUnitName ) then
        begin
          UsedInInterface := True;
          Placement.IdentifiersUsedInInterface.Add( '(qualified reference)' );
        end;
      end;

      for I := 0 to FUsageAnalyzer.ImplementationIdentifiers.Count - 1 do
      begin
        if SameText( FUsageAnalyzer.ImplementationIdentifiers[ I ], UsedUnit.UnitName ) or
           SameText( FUsageAnalyzer.ImplementationIdentifiers[ I ], LowerUnitName ) then
        begin
          UsedInImplementation := True;
          Placement.IdentifiersUsedInImplementation.Add( '(qualified reference)' );
        end;
      end;

      // Check exported identifiers from this unit
      UnitExports := FExportsDB.GetExports( LowerUnitName );
      if UnitExports <> nil then
      begin
        for Export in UnitExports do
        begin
          LowerIdent := LowerCase( Export.Identifier );

          // Check if this identifier is used in interface section
          if FUsageAnalyzer.InterfaceIdentifiers.IndexOf( Export.Identifier ) >= 0 then
          begin
            // Verify it's from this unit (check qualified refs or use heuristics)
            if FUsageAnalyzer.QualifiedReferences.TryGetValue( LowerIdent, QualifyingUnit ) then
            begin
              // Only count if qualified reference points to this unit
              if SameText( QualifyingUnit, UsedUnit.UnitName ) or
                 SameText( QualifyingUnit, LowerUnitName ) then
              begin
                UsedInInterface := True;
                Placement.IdentifiersUsedInInterface.Add( Export.Identifier );
              end;
            end
            else
            begin
              // No qualified reference - check if this unit is the preferred source
              CandidateUnits := FExportsDB.FindUnitsForIdentifier( Export.Identifier );
              if ( CandidateUnits <> nil ) and ( CandidateUnits.Count > 0 ) then
              begin
                if SameText( FExportsDB.GetPreferredUnit( Export.Identifier, CandidateUnits ), UsedUnit.UnitName ) or
                   ( CandidateUnits.IndexOf( UsedUnit.UnitName ) >= 0 ) then
                begin
                  UsedInInterface := True;
                  Placement.IdentifiersUsedInInterface.Add( Export.Identifier );
                end;
              end;
            end;
          end;

          // Check if this identifier is used in implementation section
          if FUsageAnalyzer.ImplementationIdentifiers.IndexOf( Export.Identifier ) >= 0 then
          begin
            if FUsageAnalyzer.QualifiedReferences.TryGetValue( LowerIdent, QualifyingUnit ) then
            begin
              if SameText( QualifyingUnit, UsedUnit.UnitName ) or
                 SameText( QualifyingUnit, LowerUnitName ) then
              begin
                UsedInImplementation := True;
                Placement.IdentifiersUsedInImplementation.Add( Export.Identifier );
              end;
            end
            else
            begin
              CandidateUnits := FExportsDB.FindUnitsForIdentifier( Export.Identifier );
              if ( CandidateUnits <> nil ) and ( CandidateUnits.Count > 0 ) then
              begin
                if SameText( FExportsDB.GetPreferredUnit( Export.Identifier, CandidateUnits ), UsedUnit.UnitName ) or
                   ( CandidateUnits.IndexOf( UsedUnit.UnitName ) >= 0 ) then
                begin
                  UsedInImplementation := True;
                  Placement.IdentifiersUsedInImplementation.Add( Export.Identifier );
                end;
              end;
            end;
          end;
        end;
      end;

      // Determine recommended section
      if UsedInInterface then
      begin
        Placement.RecommendedSection := usInterface;
        if UsedInImplementation then
          Placement.Reason := 'OK - used in both sections'
        else
          Placement.Reason := 'OK - used in interface section';
      end
      else if UsedInImplementation then
      begin
        Placement.RecommendedSection := usImplementation;
        Placement.Reason := 'Only used in implementation section';
      end
      else
      begin
        // No detected usage - might be unused or used implicitly
        Placement.RecommendedSection := usInterface;
        Placement.Reason := 'No direct usage detected - review manually';
      end;

      ResultList.Add( Placement );
    end;

    // Also analyze implementation uses clause units
    for UsedUnit in FUsageAnalyzer.ImplementationUsedUnits do
    begin
      Placement.UnitName := UsedUnit.UnitName;
      Placement.CurrentSection := usImplementation;
      Placement.RecommendedSection := usImplementation;
      Placement.IdentifiersUsedInInterface := TStringList.Create;
      Placement.IdentifiersUsedInImplementation := TStringList.Create;

      LowerUnitName := LowerCase( UsedUnit.UnitName );
      if Pos( '.', LowerUnitName ) > 0 then
        LowerUnitName := LowerCase( Copy( UsedUnit.UnitName, LastDelimiter( '.', UsedUnit.UnitName ) + 1, MaxInt ) );

      // Check if any exports are used in interface (would indicate it should be moved up)
      UsedInInterface := False;

      UnitExports := FExportsDB.GetExports( LowerUnitName );
      if UnitExports <> nil then
      begin
        for Export in UnitExports do
        begin
          if FUsageAnalyzer.InterfaceIdentifiers.IndexOf( Export.Identifier ) >= 0 then
          begin
            UsedInInterface := True;
            Placement.IdentifiersUsedInInterface.Add( Export.Identifier );
          end;

          if FUsageAnalyzer.ImplementationIdentifiers.IndexOf( Export.Identifier ) >= 0 then
            Placement.IdentifiersUsedInImplementation.Add( Export.Identifier );
        end;
      end;

      if UsedInInterface then
      begin
        Placement.RecommendedSection := usInterface;
        Placement.Reason := 'Identifiers used in interface section';
      end
      else
        Placement.Reason := 'OK - only used in implementation';

      ResultList.Add( Placement );
    end;

    Result := ResultList.ToArray;
  finally
    AllUnits.Free;
    ResultList.Free;
  end;
end;

function TUsesClauseRefactorer.GenerateRefactoredSource( const Source: UTF8String;
  const Placements: TArray<TUnitPlacement> ): UTF8String;
var
  Lexer: TDelphiLexer;
  Token: TToken;
  TokenList: TList<TToken>;
  InterfaceUsesStart, InterfaceUsesEnd: Integer;
  ImplUsesStart, ImplUsesEnd: Integer;
  ImplKeywordPos: Integer;
  InInterface, InImplementation, InUses: Boolean;
  NewInterfaceUnits, NewImplUnits: TStringList;
  OrigInterfaceUnits, OrigImplUnits: TStringList;
  Placement: TUnitPlacement;
  ResultStr: UTF8String;
  I: Integer;
  HasInterfaceUses, HasImplUses: Boolean;
  NewInterfaceUsesStr, NewImplUsesStr: UTF8String;
  InsertPos: Integer;

  function BuildUsesClause( const Units: TStringList; const Indent: string ): UTF8String;
  var
    J: Integer;
    LineLen: Integer;
  begin
    if Units.Count = 0 then
    begin
      Result := '';
      Exit;
    end;

    Result := UTF8String( 'uses' + #13#10 + Indent );
    LineLen := Length( Indent );

    for J := 0 to Units.Count - 1 do
    begin
      if J > 0 then
      begin
        Result := Result + ',';
        // Check if we need a new line (keep lines under ~80 chars)
        if LineLen + Length( Units[ J ] ) + 2 > 78 then
        begin
          Result := Result + UTF8String( #13#10 + Indent );
          LineLen := Length( Indent );
        end
        else
        begin
          Result := Result + ' ';
          Inc( LineLen );
        end;
      end;

      Result := Result + UTF8String( Units[ J ] );
      Inc( LineLen, Length( Units[ J ] ) );
    end;

    Result := Result + ';' + #13#10;
  end;

begin
  // Collect units for each section based on recommendations
  NewInterfaceUnits := TStringList.Create;
  NewImplUnits := TStringList.Create;
  OrigInterfaceUnits := TStringList.Create;
  OrigImplUnits := TStringList.Create;
  TokenList := TList<TToken>.Create;

  try
    // Separate units by recommended section
    for Placement in Placements do
    begin
      if Placement.RecommendedSection = usInterface then
        NewInterfaceUnits.Add( Placement.UnitName )
      else
        NewImplUnits.Add( Placement.UnitName );

      // Track original placement
      if Placement.CurrentSection = usInterface then
        OrigInterfaceUnits.Add( Placement.UnitName )
      else
        OrigImplUnits.Add( Placement.UnitName );
    end;

    // Check if anything changed
    if ( NewInterfaceUnits.CommaText = OrigInterfaceUnits.CommaText ) and
       ( NewImplUnits.CommaText = OrigImplUnits.CommaText ) then
    begin
      // No changes needed
      Result := Source;
      Exit;
    end;

    // Parse source to find uses clause positions
    Lexer := TDelphiLexer.Create( '', Source );
    try
      while Lexer.NextToken( Token ) do
      begin
        if Token.Kind <> tkComment then
          TokenList.Add( Token );
      end;
    finally
      Lexer.Free;
    end;

    // Find positions of uses clauses
    InterfaceUsesStart := 0;
    InterfaceUsesEnd := 0;
    ImplUsesStart := 0;
    ImplUsesEnd := 0;
    ImplKeywordPos := 0;
    InInterface := False;
    InImplementation := False;
    InUses := False;
    HasInterfaceUses := False;
    HasImplUses := False;

    I := 0;
    while I < TokenList.Count do
    begin
      Token := TokenList[ I ];

      if Token.Kind = tkI_interface then
      begin
        InInterface := True;
        InImplementation := False;
      end
      else if Token.Kind = tkI_implementation then
      begin
        InInterface := False;
        InImplementation := True;
        ImplKeywordPos := Token.Index;
      end
      else if Token.Kind = tkI_uses then
      begin
        InUses := True;
        if InInterface and not InImplementation then
        begin
          InterfaceUsesStart := Token.Index;
          HasInterfaceUses := True;
        end
        else if InImplementation then
        begin
          ImplUsesStart := Token.Index;
          HasImplUses := True;
        end;
      end
      else if InUses and ( Token.Kind = tkSemicolon ) then
      begin
        if InInterface and not InImplementation and ( InterfaceUsesStart > 0 ) then
          InterfaceUsesEnd := Token.Index + 1  // Include the semicolon
        else if InImplementation and ( ImplUsesStart > 0 ) then
          ImplUsesEnd := Token.Index + 1;
        InUses := False;
      end;

      Inc( I );
    end;

    // Build the result string
    ResultStr := Source;

    // Process from end to start so positions remain valid
    // Handle implementation uses clause first (it comes later in the file)
    if HasImplUses and ( ImplUsesStart > 0 ) and ( ImplUsesEnd > 0 ) then
    begin
      if NewImplUnits.Count > 0 then
      begin
        // Replace implementation uses clause
        NewImplUsesStr := BuildUsesClause( NewImplUnits, '  ' );
        Delete( ResultStr, ImplUsesStart, ImplUsesEnd - ImplUsesStart );
        Insert( NewImplUsesStr, ResultStr, ImplUsesStart );
      end
      else
      begin
        // Remove implementation uses clause entirely (skip any trailing whitespace)
        Delete( ResultStr, ImplUsesStart, ImplUsesEnd - ImplUsesStart );
        // Also try to remove the trailing newline
        while ( ImplUsesStart <= Length( ResultStr ) ) and
              CharInSet( ResultStr[ ImplUsesStart ], [ #13, #10, ' ' ] ) do
          Delete( ResultStr, ImplUsesStart, 1 );
      end;
    end
    else if ( not HasImplUses ) and ( NewImplUnits.Count > 0 ) and ( ImplKeywordPos > 0 ) then
    begin
      // Need to insert implementation uses clause after 'implementation' keyword
      NewImplUsesStr := UTF8String( #13#10 + #13#10 ) + BuildUsesClause( NewImplUnits, '  ' );

      // Find position after 'implementation' keyword
      InsertPos := ImplKeywordPos + Length( 'implementation' );
      Insert( NewImplUsesStr, ResultStr, InsertPos );

      // Adjust interface uses end position since we inserted before potential changes
      // (not needed since we process from end to start)
    end;

    // Handle interface uses clause
    if HasInterfaceUses and ( InterfaceUsesStart > 0 ) and ( InterfaceUsesEnd > 0 ) then
    begin
      if NewInterfaceUnits.Count > 0 then
      begin
        // Replace interface uses clause
        NewInterfaceUsesStr := BuildUsesClause( NewInterfaceUnits, '  ' );
        Delete( ResultStr, InterfaceUsesStart, InterfaceUsesEnd - InterfaceUsesStart );
        Insert( NewInterfaceUsesStr, ResultStr, InterfaceUsesStart );
      end
      else
      begin
        // Remove interface uses clause entirely
        Delete( ResultStr, InterfaceUsesStart, InterfaceUsesEnd - InterfaceUsesStart );
        while ( InterfaceUsesStart <= Length( ResultStr ) ) and
              CharInSet( ResultStr[ InterfaceUsesStart ], [ #13, #10, ' ' ] ) do
          Delete( ResultStr, InterfaceUsesStart, 1 );
      end;
    end;

    Result := ResultStr;
  finally
    NewInterfaceUnits.Free;
    NewImplUnits.Free;
    OrigInterfaceUnits.Free;
    OrigImplUnits.Free;
    TokenList.Free;
  end;
end;

{ TUsesClauseManagerPlugin }

constructor TUsesClauseManagerPlugin.Create;
begin
  FExportsDB := TUnitExportsDatabase.Create;

  inherited Create( AppDataDirectory + '\UsesClauseManager.xml', 'UsesClauseManager' );

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem := TMenuItem.Create( DDevExtensionsMenu );
    FMenuItem.Caption := 'Uses Clause &Manager...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add( FMenuItem );
  end;
end;

destructor TUsesClauseManagerPlugin.Destroy;
begin
  FreeAndNil( FMenuItem );
  FreeAndNil( FExportsDB );
  inherited Destroy;
end;

procedure TUsesClauseManagerPlugin.Init;
begin
  FEnabled := True;
end;

function TUsesClauseManagerPlugin.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create( 'Uses Clause Manager', TFrameOptionPageUsesClause, Self );
end;

procedure TUsesClauseManagerPlugin.MenuItemClick( Sender: TObject );
begin
  ShowManager;
end;

procedure TUsesClauseManagerPlugin.ShowManager;
begin
  TFormUsesClauseManager.Execute;
end;

procedure InitPlugin( Unload: Boolean );
begin
  if not Unload then
    UsesClauseManagerPlugin := TUsesClauseManagerPlugin.Create
  else
  begin
    UsesClauseManagerPlugin.Free;
    UsesClauseManagerPlugin := nil;
  end;
end;

end.
