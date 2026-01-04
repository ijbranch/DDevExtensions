{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit DependencyViewer;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Generics.Collections, Menus, Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main;

type
  TUnitDependency = record
    UnitName: string;
    FileName: string;
    IsInterface: Boolean; // True if in interface uses, False if in implementation uses
  end;

  {$WARN HIDING_MEMBER OFF}
  TUnitInfo = class
  private
    FUnitName: string;
    FFileName: string;
    FDependencies: TList<TUnitDependency>;
    FParsed: Boolean;
  public
    constructor Create( const AUnitName, AFileName: string );
    destructor Destroy; override;
    property UnitName: string read FUnitName;
    property FileName: string read FFileName;
    property Dependencies: TList<TUnitDependency> read FDependencies;
    property Parsed: Boolean read FParsed write FParsed;
  end;
  {$WARN HIDING_MEMBER ON}

  TCircularReferenceStep = record
    UnitName: string;
    IsInterface: Boolean;  // True if this unit is referenced via interface uses
  end;

  TCircularReference = record
    Steps: TArray<TCircularReferenceStep>;
  end;

  TImpactAnalysis = record
    UnitName: string;
    DirectDependents: TArray<string>;      // Units that directly use this unit
    TransitiveDependents: TArray<string>;  // All units affected (recursive)
    DirectCount: Integer;
    TransitiveCount: Integer;
    RiskLevel: Integer;                    // 0=Safe, 1=Low, 2=Medium, 3=High
    function RiskLevelText: string;
  end;

  TDependencyScanner = class
  private
    FUnits: TObjectDictionary<string, TUnitInfo>;
    FSearchPaths: TStringList;
    FCircularRefs: TList<TCircularReference>;
    FReverseDeps: TObjectDictionary<string, TStringList>;
    FDepthMap: TDictionary<string, Integer>;
    FOnProgress: TNotifyEvent;
    FProgressUnit: string;
    procedure ParseUsesClause( const Content: string; UnitInfo: TUnitInfo );
    procedure ScanUnit( const UnitName, FileName: string );
    procedure DetectCircularReferences;
    function CheckCircular( const UnitName: string; IsInterface: Boolean;
      const Path: TList<TCircularReferenceStep>;
      var Visited: TDictionary<string, Boolean> ): Boolean;
    procedure BuildReverseDependencies;
    procedure CalculateDepths;
    function CalculateUnitDepth( const UnitName: string;
      var Calculating: TDictionary<string, Boolean> ): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure AddSearchPath( const Path: string );
    procedure ScanProject( const Project: IOTAProject );
    procedure ScanFile( const FileName: string );
    function GetUnitInfo( const UnitName: string ): TUnitInfo;
    function GetAllUnits: TArray<TUnitInfo>;
    function GetReverseDependencies( const UnitName: string ): TStringList;
    function GetUnitDepth( const UnitName: string ): Integer;
    function AnalyzeImpact( const UnitName: string ): TImpactAnalysis;
    property CircularReferences: TList<TCircularReference> read FCircularRefs;
    property OnProgress: TNotifyEvent read FOnProgress write FOnProgress;
    property ProgressUnit: string read FProgressUnit;
  end;

  TDependencyViewerPlugin = class( TPluginConfig )
  private
    FEnabled: Boolean;
    FMenuItem: TMenuItem;
    procedure MenuItemClick( Sender: TObject );
  protected
    function GetOptionPages: TTreePage; override;
    procedure Init; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ShowDependencyViewer;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

procedure InitPlugin( Unload: Boolean );

var
  DependencyViewerPlugin: TDependencyViewerPlugin;

implementation

uses
  Forms, Controls, ToolsAPIHelpers, AppConsts,
  FrmDependencyViewer, FrmeOptionPageDependencyViewer;

{ TUnitInfo }

constructor TUnitInfo.Create( const AUnitName, AFileName: string );
begin

  inherited Create;
  FUnitName     := AUnitName;
  FFileName     := AFileName;
  FDependencies := TList<TUnitDependency>.Create;
  FParsed       := False;

end;

destructor TUnitInfo.Destroy;
begin

  FDependencies.Free;
  inherited Destroy;

end;

{ TDependencyScanner }

constructor TDependencyScanner.Create;
begin

  inherited Create;
  FUnits                     := TObjectDictionary<string, TUnitInfo>.Create( [ doOwnsValues ] );
  FSearchPaths               := TStringList.Create;
  FSearchPaths.CaseSensitive := False;
  FSearchPaths.Duplicates    := dupIgnore;
  FCircularRefs              := TList<TCircularReference>.Create;
  FReverseDeps               := TObjectDictionary<string, TStringList>.Create( [ doOwnsValues ] );
  FDepthMap                  := TDictionary<string, Integer>.Create;

end;

destructor TDependencyScanner.Destroy;
begin

  FDepthMap.Free;
  FReverseDeps.Free;
  FCircularRefs.Free;
  FSearchPaths.Free;
  FUnits.Free;
  inherited Destroy;

end;

procedure TDependencyScanner.Clear;
begin

  FUnits.Clear;
  FSearchPaths.Clear;
  FCircularRefs.Clear;
  FReverseDeps.Clear;
  FDepthMap.Clear;

end;

procedure TDependencyScanner.AddSearchPath( const Path: string );
var
  ExpandedPath: string;
begin

  ExpandedPath := ExcludeTrailingPathDelimiter( Path );

  if ( ExpandedPath <> '' ) and DirectoryExists( ExpandedPath ) then
    FSearchPaths.Add( ExpandedPath );

end;

procedure TDependencyScanner.ParseUsesClause( const Content: string; UnitInfo: TUnitInfo );
var
  I, Len: Integer;
  InInterface, InImplementation: Boolean;
  InUses, InString, InComment, InLineComment: Boolean;
  BraceDepth: Integer;
  Token: string;
  Ch: Char;
  Dep: TUnitDependency;

  procedure AddToken;
  begin

    if Token <> '' then
    begin

      if SameText( Token, 'interface' ) then
      begin
        InInterface      := True;
        InImplementation := False;
      end
      else if SameText( Token, 'implementation' ) then
      begin
        InInterface      := False;
        InImplementation := True;
        InUses           := False;
      end
      else if SameText( Token, 'uses' ) then
        InUses := True
      else if InUses and ( not SameText( Token, 'in' ) ) then
      begin
        Dep.UnitName    := Token;
        Dep.FileName    := '';
        Dep.IsInterface := InInterface;
        UnitInfo.Dependencies.Add( Dep );
      end;

      Token := '';
    end;

  end;

begin

  I                := 1;
  Len              := Length( Content );
  InInterface      := False;
  InImplementation := False;
  InUses           := False;
  InString         := False;
  InComment        := False;
  InLineComment    := False;
  BraceDepth       := 0;
  Token            := '';

  while I <= Len do
  begin
    Ch := Content[ I ];

    // Handle line comments
    if InLineComment then
    begin

      if ( Ch = #13 ) or ( Ch = #10 ) then
        InLineComment := False;

      Inc( I );
      Continue;
    end;

    // Handle block comments
    if InComment then
    begin

      if ( Ch = '*' ) and ( I < Len ) and ( Content[ I + 1 ] = ')' ) then
      begin
        InComment := False;
        Inc( I );
      end
      else if ( Ch = '}' ) and ( BraceDepth > 0 ) then
        Dec( BraceDepth );

      Inc( I );
      Continue;
    end;

    if BraceDepth > 0 then
    begin

      if Ch = '}' then
        Dec( BraceDepth );

      Inc( I );
      Continue;
    end;

    // Handle strings
    if InString then
    begin

      if Ch = '''' then
        InString := False;

      Inc( I );
      Continue;
    end;

    // Check for comment start
    if ( Ch = '/' ) and ( I < Len ) and ( Content[ I + 1 ] = '/' ) then
    begin
      AddToken;
      InLineComment := True;
      Inc( I, 2 );
      Continue;
    end;

    if ( Ch = '(' ) and ( I < Len ) and ( Content[ I + 1 ] = '*' ) then
    begin
      AddToken;
      InComment := True;
      Inc( I, 2 );
      Continue;
    end;

    if Ch = '{' then
    begin
      AddToken;
      Inc( BraceDepth );
      Inc( I );
      Continue;
    end;

    if Ch = '''' then
    begin
      AddToken;
      InString := True;
      Inc( I );
      Continue;
    end;

    // Parse tokens
    if CharInSet( Ch, [ 'A'..'Z', 'a'..'z', '_', '0'..'9', '.' ] ) then
      Token := Token + Ch
    else
    begin
      AddToken;

      if InUses and ( Ch = ';' ) then
        InUses := False;
    end;

    Inc( I );
  end;

  AddToken;

end;

procedure TDependencyScanner.ScanUnit( const UnitName, FileName: string );
var
  UnitInfo: TUnitInfo;
  Content: string;
  SL: TStringList;
  LowerName: string;
begin

  LowerName := LowerCase( UnitName );

  if FUnits.ContainsKey( LowerName ) then
  begin
    UnitInfo := FUnits[ LowerName ];

    if UnitInfo.Parsed then
      Exit;
  end
  else
  begin
    UnitInfo := TUnitInfo.Create( UnitName, FileName );
    FUnits.Add( LowerName, UnitInfo );
  end;

  FProgressUnit := UnitName;

  if Assigned( FOnProgress ) then
    FOnProgress( Self );

  if ( FileName <> '' ) and FileExists( FileName ) then
  begin
    SL := TStringList.Create;

    try
      SL.LoadFromFile( FileName );
      Content := SL.Text;
    finally
      SL.Free;
    end;

    ParseUsesClause( Content, UnitInfo );
    UnitInfo.Parsed := True;

    // Recursively scan dependencies
    // (Disabled for performance - only scan on demand)
  end;

end;

procedure TDependencyScanner.ScanProject( const Project: IOTAProject );
var
  I: Integer;
  ModuleInfo: IOTAModuleInfo;
  FileName, UnitName: string;
  Options: IOTAProjectOptions;
  SearchPath, OutputDir: string;
  SL: TStringList;
begin

  if Project = nil then
    Exit;

  Clear;

  // Add project directory as search path
  AddSearchPath( ExtractFileDir( Project.FileName ) );

  // Get search paths from project options
  Options := Project.ProjectOptions;

  if Options <> nil then
  begin
    SearchPath := VarToStr( Options.Values[ 'UnitDir' ] );
    SL         := TStringList.Create;

    try
      SL.Delimiter       := ';';
      SL.StrictDelimiter := True;
      SL.DelimitedText   := SearchPath;

      for I := 0 to SL.Count - 1 do
        AddSearchPath( ExpandFileName( SL[ I ] ) );
    finally
      SL.Free;
    end;

    OutputDir := VarToStr( Options.Values[ 'UnitOutputDir' ] );

    if OutputDir <> '' then
      AddSearchPath( ExpandFileName( OutputDir ) );
  end;

  // Scan all units in the project
  for I := 0 to Project.GetModuleCount - 1 do
  begin
    ModuleInfo := Project.GetModule( I );
    FileName   := ModuleInfo.FileName;

    if SameText( ExtractFileExt( FileName ), '.pas' ) then
    begin
      UnitName := ChangeFileExt( ExtractFileName( FileName ), '' );
      ScanUnit( UnitName, FileName );
    end;
  end;

  DetectCircularReferences;
  BuildReverseDependencies;
  CalculateDepths;

end;

procedure TDependencyScanner.ScanFile( const FileName: string );
var
  UnitName: string;
begin

  if FileExists( FileName ) and SameText( ExtractFileExt( FileName ), '.pas' ) then
  begin
    UnitName := ChangeFileExt( ExtractFileName( FileName ), '' );
    AddSearchPath( ExtractFileDir( FileName ) );
    ScanUnit( UnitName, FileName );
  end;

end;

function TDependencyScanner.GetUnitInfo( const UnitName: string ): TUnitInfo;
begin

  if ( not FUnits.TryGetValue( LowerCase( UnitName ), Result ) ) then
    Result := nil;

end;

function TDependencyScanner.GetAllUnits: TArray<TUnitInfo>;
var
  List: TList<TUnitInfo>;
  Pair: TPair<string, TUnitInfo>;
begin

  List := TList<TUnitInfo>.Create;

  try

    for Pair in FUnits do
      List.Add( Pair.Value );

    Result := List.ToArray;
  finally
    List.Free;
  end;

end;

function TDependencyScanner.GetReverseDependencies( const UnitName: string ): TStringList;
begin

  if not FReverseDeps.TryGetValue( LowerCase( UnitName ), Result ) then
    Result := nil;

end;

function TDependencyScanner.GetUnitDepth( const UnitName: string ): Integer;
begin

  if not FDepthMap.TryGetValue( LowerCase( UnitName ), Result ) then
    Result := 0;

end;

{ TImpactAnalysis }

function TImpactAnalysis.RiskLevelText: string;
begin

  case RiskLevel of
    0: Result := 'Safe';
    1: Result := 'Low';
    2: Result := 'Medium';
    3: Result := 'High';
  else
    Result := 'Unknown';
  end;

end;

function TDependencyScanner.AnalyzeImpact( const UnitName: string ): TImpactAnalysis;
var
  Visited: TStringList;
  RevDeps: TStringList;
  I: Integer;

  procedure CollectTransitive( const Name: string );
  var
    ChildRevDeps: TStringList;
    J: Integer;
  begin

    ChildRevDeps := GetReverseDependencies( Name );

    if ChildRevDeps = nil then
      Exit;

    for J := 0 to ChildRevDeps.Count - 1 do
    begin

      if Visited.IndexOf( ChildRevDeps[ J ] ) < 0 then
      begin
        Visited.Add( ChildRevDeps[ J ] );
        CollectTransitive( ChildRevDeps[ J ] );
      end;
    end;

  end;

begin

  Result.UnitName := UnitName;

  // Get direct dependents
  RevDeps := GetReverseDependencies( UnitName );

  if RevDeps <> nil then
  begin
    SetLength( Result.DirectDependents, RevDeps.Count );

    for I := 0 to RevDeps.Count - 1 do
      Result.DirectDependents[ I ] := RevDeps[ I ];
  end
  else
    SetLength( Result.DirectDependents, 0 );

  Result.DirectCount := Length( Result.DirectDependents );

  // Collect transitive dependents
  Visited := TStringList.Create;

  try
    Visited.CaseSensitive := False;
    Visited.Sorted        := True;
    Visited.Duplicates    := dupIgnore;

    CollectTransitive( UnitName );

    SetLength( Result.TransitiveDependents, Visited.Count );

    for I := 0 to Visited.Count - 1 do
      Result.TransitiveDependents[ I ] := Visited[ I ];

    Result.TransitiveCount := Visited.Count;
  finally
    Visited.Free;
  end;

  // Calculate risk level based on transitive impact
  if Result.TransitiveCount = 0 then
    Result.RiskLevel := 0      // Safe - nothing depends on it
  else if Result.TransitiveCount <= 3 then
    Result.RiskLevel := 1      // Low
  else if Result.TransitiveCount <= 10 then
    Result.RiskLevel := 2      // Medium
  else
    Result.RiskLevel := 3;     // High - many units affected

end;

procedure TDependencyScanner.BuildReverseDependencies;
var
  Pair: TPair<string, TUnitInfo>;
  UnitInfo: TUnitInfo;
  Dep: TUnitDependency;
  LowerDepName: string;
  RevList: TStringList;
begin

  FReverseDeps.Clear;

  // Build reverse dependency map: for each unit, find all units that use it
  for Pair in FUnits do
  begin
    UnitInfo := Pair.Value;

    for Dep in UnitInfo.Dependencies do
    begin
      LowerDepName := LowerCase( Dep.UnitName );

      if not FReverseDeps.TryGetValue( LowerDepName, RevList ) then
      begin
        RevList            := TStringList.Create;
        RevList.Sorted     := True;
        RevList.Duplicates := dupIgnore;
        FReverseDeps.Add( LowerDepName, RevList );
      end;

      RevList.Add( UnitInfo.UnitName );
    end;
  end;

end;

procedure TDependencyScanner.CalculateDepths;
var
  Calculating: TDictionary<string, Boolean>;
  Pair: TPair<string, TUnitInfo>;
begin

  FDepthMap.Clear;
  Calculating := TDictionary<string, Boolean>.Create;

  try

    for Pair in FUnits do
      CalculateUnitDepth( Pair.Key, Calculating );
  finally
    Calculating.Free;
  end;

end;

function TDependencyScanner.CalculateUnitDepth( const UnitName: string;
  var Calculating: TDictionary<string, Boolean> ): Integer;
var
  UnitInfo: TUnitInfo;
  Dep: TUnitDependency;
  DepDepth: Integer;
  LowerName, LowerDepName: string;
  IsCalculating: Boolean;
begin

  LowerName := LowerCase( UnitName );

  // Return cached depth if already calculated
  if FDepthMap.TryGetValue( LowerName, Result ) then
    Exit;

  // Check for circular dependency (being calculated)
  if Calculating.TryGetValue( LowerName, IsCalculating ) and IsCalculating then
  begin
    Result := 0;
    Exit;
  end;

  // If unit not in project, depth is 0 (external dependency)
  if not FUnits.TryGetValue( LowerName, UnitInfo ) then
  begin
    Result := 0;
    FDepthMap.Add( LowerName, Result );
    Exit;
  end;

  // Mark as being calculated
  Calculating.AddOrSetValue( LowerName, True );

  try
    Result := 0;

    // Depth is 1 + max depth of dependencies (only project units count)
    for Dep in UnitInfo.Dependencies do
    begin
      LowerDepName := LowerCase( Dep.UnitName );

      if FUnits.ContainsKey( LowerDepName ) then
      begin
        DepDepth := CalculateUnitDepth( Dep.UnitName, Calculating );

        if DepDepth + 1 > Result then
          Result := DepDepth + 1;
      end;
    end;

    FDepthMap.AddOrSetValue( LowerName, Result );
  finally
    Calculating.AddOrSetValue( LowerName, False );
  end;

end;

procedure TDependencyScanner.DetectCircularReferences;
var
  Visited: TDictionary<string, Boolean>;
  Path: TList<TCircularReferenceStep>;
  Pair: TPair<string, TUnitInfo>;
begin

  FCircularRefs.Clear;
  Visited := TDictionary<string, Boolean>.Create;
  Path    := TList<TCircularReferenceStep>.Create;

  try

    for Pair in FUnits do
    begin
      Visited.Clear;
      Path.Clear;
      CheckCircular( Pair.Key, True, Path, Visited );
    end;
  finally
    Path.Free;
    Visited.Free;
  end;

end;

function TDependencyScanner.CheckCircular( const UnitName: string; IsInterface: Boolean;
  const Path: TList<TCircularReferenceStep>;
  var Visited: TDictionary<string, Boolean> ): Boolean;
var
  UnitInfo: TUnitInfo;
  Dep: TUnitDependency;
  CircRef: TCircularReference;
  Step: TCircularReferenceStep;
  I, J, StartIdx: Integer;
  IsVisited: Boolean;
  LowerName: string;
begin

  Result    := False;
  LowerName := LowerCase( UnitName );

  // Check if we've found a cycle
  for I := 0 to Path.Count - 1 do
  begin

    if SameText( Path[ I ].UnitName, UnitName ) then
    begin
      // Found a cycle - record it
      StartIdx := I;
      SetLength( CircRef.Steps, Path.Count - StartIdx + 1 );

      for J := StartIdx to Path.Count - 1 do
        CircRef.Steps[ J - StartIdx ] := Path[ J ];

      // Last step closes the cycle with current IsInterface info
      CircRef.Steps[ High( CircRef.Steps ) ].UnitName    := UnitName;
      CircRef.Steps[ High( CircRef.Steps ) ].IsInterface := IsInterface;
      FCircularRefs.Add( CircRef );
      Result := True;
      Exit;
    end;
  end;

  if Visited.TryGetValue( LowerName, IsVisited ) and IsVisited then
    Exit;

  Visited.AddOrSetValue( LowerName, True );

  Step.UnitName    := UnitName;
  Step.IsInterface := IsInterface;
  Path.Add( Step );

  try

    if FUnits.TryGetValue( LowerName, UnitInfo ) then
    begin

      for Dep in UnitInfo.Dependencies do
        CheckCircular( Dep.UnitName, Dep.IsInterface, Path, Visited );
    end;
  finally
    Path.Delete( Path.Count - 1 );
  end;

end;

{ TDependencyViewerPlugin }

constructor TDependencyViewerPlugin.Create;
var
  ToolsMenu: TMenuItem;
begin

  inherited Create( AppDataDirectory + '\DependencyViewer.xml', 'DependencyViewer' );

  // Add menu item under Tools menu
  ToolsMenu := FindMenuItem( 'ToolsMenu' );

  if ToolsMenu <> nil then
  begin
    FMenuItem         := TMenuItem.Create( ToolsMenu );
    FMenuItem.Caption := '&Dependency Viewer...';
    FMenuItem.OnClick := MenuItemClick;
    ToolsMenu.Add( FMenuItem );
  end;

end;

destructor TDependencyViewerPlugin.Destroy;
begin

  FreeAndNil( FMenuItem );
  inherited Destroy;

end;

procedure TDependencyViewerPlugin.Init;
begin

  FEnabled := True;

end;

function TDependencyViewerPlugin.GetOptionPages: TTreePage;
begin

  Result := TTreePage.Create( 'Dependency Viewer', TFrameOptionPageDependencyViewer, Self );

end;

procedure TDependencyViewerPlugin.MenuItemClick( Sender: TObject );
begin

  ShowDependencyViewer;

end;

procedure TDependencyViewerPlugin.ShowDependencyViewer;
begin

  TFormDependencyViewer.Execute;

end;

procedure InitPlugin( Unload: Boolean );
begin

  if ( not Unload ) then
    DependencyViewerPlugin := TDependencyViewerPlugin.Create
  else
  begin
    DependencyViewerPlugin.Free;
    DependencyViewerPlugin := nil;
  end;

end;

end.
