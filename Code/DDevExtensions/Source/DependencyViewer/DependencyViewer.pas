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

/// <summary>
/// Implements the Dependency Viewer DDevExtensions plugin: scans the active project's
/// uses clauses to build a unit dependency graph, detects circular references, performs
/// impact analysis and enforces architectural layer rules.
/// </summary>
/// <remarks>
/// Provides the core scanner, layer-rule engine and plugin host class. The visual
/// presentation lives in FrmDependencyViewer; the IDE Tools options page lives in
/// FrmeOptionPageDependencyViewer.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Generics.Collections, Vcl.Menus, System.Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main;

type
  /// <summary>
  /// One entry of a unit's uses clause, indicating which section it appears in.
  /// </summary>
  TUnitDependency = record
    /// <summary>Name of the unit being referenced.</summary>
    UnitName: string;
    /// <summary>Resolved source file path for the referenced unit, if known.</summary>
    FileName: string;
    /// <summary>True when the reference appears in the interface uses clause; False for implementation.</summary>
    IsInterface: Boolean;
  end;

  /// <summary>
  /// Definition of an architectural layer: a name plus a set of unit-name match patterns.
  /// </summary>
  TLayerDefinition = record
    /// <summary>Layer name (e.g. "UI", "Business", "DataAccess").</summary>
    Name: string;
    /// <summary>Wildcard patterns matching unit names belonging to this layer (* = many chars, ? = single).</summary>
    Patterns: TArray<string>;
  end;

  /// <summary>
  /// A single layer-rule violation: a source unit using a target unit across a forbidden layer boundary.
  /// </summary>
  TLayerViolation = record
    /// <summary>Name of the unit containing the offending uses reference.</summary>
    SourceUnit: string;
    /// <summary>Layer that the source unit belongs to.</summary>
    SourceLayer: string;
    /// <summary>Name of the unit being used.</summary>
    TargetUnit: string;
    /// <summary>Layer that the target unit belongs to.</summary>
    TargetLayer: string;
    /// <summary>True when the violating reference is in the interface uses clause.</summary>
    IsInterface: Boolean;
  end;

  {$WARN HIDING_MEMBER OFF}
  /// <summary>
  /// Information about a single Pascal unit, including its parsed dependencies.
  /// </summary>
  TUnitInfo = class
  private
    /// <summary>Backing field for <see cref="UnitName"/>.</summary>
    FUnitName: string;
    /// <summary>Backing field for <see cref="FileName"/>.</summary>
    FFileName: string;
    /// <summary>Backing field for <see cref="Dependencies"/>.</summary>
    FDependencies: TList<TUnitDependency>;
    /// <summary>Backing field for <see cref="Parsed"/>.</summary>
    FParsed: Boolean;
  public
    /// <summary>Creates a new unit info record for the given unit name and source file path.</summary>
    /// <param name="AUnitName">The unit name (without extension).</param>
    /// <param name="AFileName">The full path to the .pas file (may be empty for external units).</param>
    constructor Create( const AUnitName, AFileName: string );
    /// <summary>Releases the dependency list.</summary>
    destructor Destroy; override;
    /// <summary>Read-only unit name.</summary>
    property UnitName: string read FUnitName;
    /// <summary>Read-only source file path.</summary>
    property FileName: string read FFileName;
    /// <summary>List of units this unit depends on (interface and implementation uses).</summary>
    property Dependencies: TList<TUnitDependency> read FDependencies;
    /// <summary>True after the source has been parsed for its uses clauses.</summary>
    property Parsed: Boolean read FParsed write FParsed;
  end;
  {$WARN HIDING_MEMBER ON}

  /// <summary>
  /// One step in a circular dependency path.
  /// </summary>
  TCircularReferenceStep = record
    /// <summary>Unit name at this step.</summary>
    UnitName: string;
    /// <summary>True when this unit is reached via the interface uses clause of the previous step.</summary>
    IsInterface: Boolean;
  end;

  /// <summary>
  /// A complete circular reference cycle expressed as an ordered chain of steps.
  /// </summary>
  TCircularReference = record
    /// <summary>Ordered sequence of steps that closes back on the first step.</summary>
    Steps: TArray<TCircularReferenceStep>;
  end;

  /// <summary>
  /// Result of impact analysis for a single unit: how many units would be affected by changes to it.
  /// </summary>
  TImpactAnalysis = record
    /// <summary>The unit being analysed.</summary>
    UnitName: string;
    /// <summary>Units that directly use this unit.</summary>
    DirectDependents: TArray<string>;
    /// <summary>All units affected, computed recursively through reverse dependencies.</summary>
    TransitiveDependents: TArray<string>;
    /// <summary>Count of direct dependents (length of DirectDependents).</summary>
    DirectCount: Integer;
    /// <summary>Count of all transitively affected units.</summary>
    TransitiveCount: Integer;
    /// <summary>Risk score: 0=Safe, 1=Low, 2=Medium, 3=High.</summary>
    RiskLevel: Integer;
    /// <summary>Returns the risk level as a human-readable string ("Safe", "Low", "Medium", "High").</summary>
    function RiskLevelText: string;
  end;

  /// <summary>
  /// Persistent layer configuration: layer definitions plus allowed inter-layer dependencies.
  /// Loaded from / saved to a simple INI-like text file.
  /// </summary>
  TLayerConfig = class
  private
    /// <summary>Backing field for <see cref="Layers"/>.</summary>
    FLayers: TList<TLayerDefinition>;
    /// <summary>Maps each layer name to the list of layer names it is allowed to depend on.</summary>
    FAllowedDeps: TDictionary<string, TStringList>;
    /// <summary>Path of the configuration file used by LoadFromFile/SaveToFile.</summary>
    FConfigFile: string;
  public
    /// <summary>Creates a layer config bound to the given configuration file path.</summary>
    /// <param name="AConfigFile">Path of the file used for persistence.</param>
    constructor Create( const AConfigFile: string );
    /// <summary>Releases all owned layer/dependency resources.</summary>
    destructor Destroy; override;
    /// <summary>Removes all layer definitions and rules.</summary>
    procedure Clear;
    /// <summary>Adds a new layer with the supplied wildcard patterns.</summary>
    /// <param name="Name">Layer name.</param>
    /// <param name="Patterns">Unit-name match patterns.</param>
    procedure AddLayer( const Name: string; const Patterns: TArray<string> );
    /// <summary>Sets the layers that <paramref name="FromLayer"/> is permitted to depend on.</summary>
    /// <param name="FromLayer">Source layer name.</param>
    /// <param name="ToLayers">Allowed target layer names.</param>
    procedure SetAllowedDependencies( const FromLayer: string; const ToLayers: TArray<string> );
    /// <summary>Returns the layer name a given unit belongs to, or empty if no pattern matches.</summary>
    function GetLayerForUnit( const UnitName: string ): string;
    /// <summary>Returns True when <paramref name="FromLayer"/> may depend on <paramref name="ToLayer"/>.</summary>
    /// <remarks>Same-layer dependencies are always allowed; layers with no rules allow all targets.</remarks>
    function IsDependencyAllowed( const FromLayer, ToLayer: string ): Boolean;
    /// <summary>Returns a snapshot of all defined layers.</summary>
    function GetLayers: TArray<TLayerDefinition>;
    /// <summary>Returns the allowed target layer names for the given source layer.</summary>
    function GetAllowedDependencies( const LayerName: string ): TArray<string>;
    /// <summary>Loads layers and rules from the configured file; falls back to defaults if missing.</summary>
    procedure LoadFromFile;
    /// <summary>Persists the current layers and rules to the configured file.</summary>
    procedure SaveToFile;
    /// <summary>Loads a sensible default configuration for typical Delphi projects.</summary>
    procedure LoadDefaults;
    /// <summary>Read-only access to the underlying layer list.</summary>
    property Layers: TList<TLayerDefinition> read FLayers;
  end;

  /// <summary>
  /// Scans a project's units to build the dependency graph, detect cycles, compute depth
  /// and reverse-dependency information, and report layer violations.
  /// Honours conditional compilation directives when <see cref="RespectConditionals"/> is True.
  /// </summary>
  TDependencyScanner = class
  private
    /// <summary>All units known to the scanner, keyed by lower-case name.</summary>
    FUnits: TObjectDictionary<string, TUnitInfo>;
    /// <summary>Search paths used to resolve unit source files.</summary>
    FSearchPaths: TStringList;
    /// <summary>List of detected circular references.</summary>
    FCircularRefs: TList<TCircularReference>;
    /// <summary>Maps each unit (lower-case) to the units that reference it.</summary>
    FReverseDeps: TObjectDictionary<string, TStringList>;
    /// <summary>Cached depth (longest dependency chain) for each unit.</summary>
    FDepthMap: TDictionary<string, Integer>;
    /// <summary>Optional progress callback.</summary>
    FOnProgress: TNotifyEvent;
    /// <summary>Backing field for <see cref="ProgressUnit"/>.</summary>
    FProgressUnit: string;
    /// <summary>Conditional defines extracted from the project options.</summary>
    FProjectDefines: TStringList;
    /// <summary>Backing field for <see cref="RespectConditionals"/>.</summary>
    FRespectConditionals: Boolean;
    /// <summary>Parses the supplied source content and populates <paramref name="UnitInfo"/>'s dependencies.</summary>
    procedure ParseUsesClause( const Content: string; UnitInfo: TUnitInfo );
    /// <summary>Loads and parses a single unit, adding it to the graph if not already present.</summary>
    procedure ScanUnit( const UnitName, FileName: string );
    /// <summary>Walks every unit looking for cycles and populates <see cref="CircularReferences"/>.</summary>
    procedure DetectCircularReferences;
    /// <summary>Recursive cycle-detection helper used by <see cref="DetectCircularReferences"/>.</summary>
    function CheckCircular( const UnitName: string; IsInterface: Boolean;
      const Path: TList<TCircularReferenceStep>;
      var Visited: TDictionary<string, Boolean> ): Boolean;
    /// <summary>Builds the reverse-dependency map after scanning is complete.</summary>
    procedure BuildReverseDependencies;
    /// <summary>Computes the depth of every unit in the graph.</summary>
    procedure CalculateDepths;
    /// <summary>Recursively computes the depth of a single unit, guarding against cycles.</summary>
    function CalculateUnitDepth( const UnitName: string;
      var Calculating: TDictionary<string, Boolean> ): Integer;
    /// <summary>Returns True when the supplied conditional define is active for this project.</summary>
    function IsDefineDefined( const DefineName: string ): Boolean;
    /// <summary>Evaluates a conditional expression. Returns 1 (true), 0 (false) or -1 (unknown).</summary>
    function EvaluateIfCondition( const Condition: string ): Integer;
  public
    /// <summary>Creates a new scanner with empty state.</summary>
    constructor Create;
    /// <summary>Releases all owned resources.</summary>
    destructor Destroy; override;
    /// <summary>Clears all scan results, search paths and project defines.</summary>
    procedure Clear;
    /// <summary>Adds a directory to the unit search path (duplicates are ignored).</summary>
    procedure AddSearchPath( const Path: string );
    /// <summary>Scans every .pas module belonging to the supplied project.</summary>
    /// <param name="Project">The active project to scan.</param>
    procedure ScanProject( const Project: IOTAProject );
    /// <summary>Scans a single .pas file (also adding its directory to the search path).</summary>
    procedure ScanFile( const FileName: string );
    /// <summary>Returns the <see cref="TUnitInfo"/> for a unit name, or nil if not scanned.</summary>
    function GetUnitInfo( const UnitName: string ): TUnitInfo;
    /// <summary>Returns a snapshot of all units known to the scanner.</summary>
    function GetAllUnits: TArray<TUnitInfo>;
    /// <summary>Returns the list of units that reference the named unit, or nil if none.</summary>
    function GetReverseDependencies( const UnitName: string ): TStringList;
    /// <summary>Returns the dependency depth of a unit (0 for external/leaf units).</summary>
    function GetUnitDepth( const UnitName: string ): Integer;
    /// <summary>Computes impact analysis for a unit, including direct and transitive dependents.</summary>
    function AnalyzeImpact( const UnitName: string ): TImpactAnalysis;
    /// <summary>Returns all dependencies that violate the supplied layer configuration.</summary>
    function DetectLayerViolations( LayerConfig: TLayerConfig ): TArray<TLayerViolation>;
    /// <summary>Detected circular references after the most recent scan.</summary>
    property CircularReferences: TList<TCircularReference> read FCircularRefs;
    /// <summary>Notification fired periodically during scanning so the UI can update progress.</summary>
    property OnProgress: TNotifyEvent read FOnProgress write FOnProgress;
    /// <summary>Name of the unit currently being processed (set just before <see cref="OnProgress"/> fires).</summary>
    property ProgressUnit: string read FProgressUnit;
    /// <summary>When True, the parser honours $IFDEF/$IF directives using the project defines.</summary>
    property RespectConditionals: Boolean read FRespectConditionals write FRespectConditionals;
  end;

  /// <summary>
  /// Plugin host class: registers the menu item, owns the persisted options and exposes
  /// the entry point for displaying the Dependency Viewer form.
  /// </summary>
  TDependencyViewerPlugin = class( TPluginConfig )
  private
    /// <summary>Backing field for <see cref="Enabled"/>.</summary>
    FEnabled: Boolean;
    /// <summary>Backing field for <see cref="RespectConditionals"/>.</summary>
    FRespectConditionals: Boolean;
    /// <summary>Owned menu item under the DDevExtensions submenu.</summary>
    FMenuItem: TMenuItem;
    /// <summary>Menu click handler that opens the viewer.</summary>
    procedure MenuItemClick( Sender: TObject );
  protected
    /// <summary>Returns the IDE Tools options page for this plugin.</summary>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises default option values when no persisted state is found.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the plugin and adds its menu item.</summary>
    constructor Create;
    /// <summary>Frees the menu item.</summary>
    destructor Destroy; override;
    /// <summary>Opens (or focuses) the Dependency Viewer form.</summary>
    procedure ShowDependencyViewer;
  published
    /// <summary>Whether the plugin's features are enabled.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
    /// <summary>Whether the scanner should honour conditional compilation directives.</summary>
    property RespectConditionals: Boolean read FRespectConditionals write FRespectConditionals;
  end;

/// <summary>
/// Plugin entry point invoked by the IDE host. Creates or releases the singleton plugin instance.
/// </summary>
/// <param name="Unload">When True the plugin is being unloaded; otherwise it is being loaded.</param>
procedure InitPlugin( Unload: Boolean );

var
  /// <summary>Singleton instance of the Dependency Viewer plugin (set by InitPlugin).</summary>
  DependencyViewerPlugin: TDependencyViewerPlugin;

implementation

uses
  Vcl.Forms, Vcl.Controls, ToolsAPIHelpers, AppConsts,
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
  FProjectDefines            := TStringList.Create;
  FProjectDefines.CaseSensitive := False;
  FProjectDefines.Sorted     := True;
  FProjectDefines.Duplicates := dupIgnore;
  FRespectConditionals       := True;

end;

destructor TDependencyScanner.Destroy;
begin

  FProjectDefines.Free;
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
  FProjectDefines.Clear;

end;

procedure TDependencyScanner.AddSearchPath( const Path: string );
var
  ExpandedPath: string;
begin

  ExpandedPath := ExcludeTrailingPathDelimiter( Path );

  if ( ExpandedPath <> '' ) and DirectoryExists( ExpandedPath ) then
    FSearchPaths.Add( ExpandedPath );

end;

function TDependencyScanner.IsDefineDefined( const DefineName: string ): Boolean;
begin

  Result := FProjectDefines.IndexOf( DefineName ) >= 0;

end;

function TDependencyScanner.EvaluateIfCondition( const Condition: string ): Integer;
var
  TrimmedCond: string;
  P1, P2: Integer;
  DefName: string;
  InnerResult: Integer;
  NotPrefix: Boolean;

  function EvaluateSingleTerm( const Term: string ): Integer;
  var
    TTerm: string;
    IsNot: Boolean;
    TP1, TP2: Integer;
    TDefName: string;
  begin
    // Returns: 1 = true, 0 = false, -1 = unknown
    Result := -1;
    TTerm  := Trim( Term );

    if TTerm = '' then
      Exit;

    // Handle NOT prefix
    IsNot := False;

    if SameText( Copy( TTerm, 1, 4 ), 'NOT ' ) then
    begin
      IsNot := True;
      TTerm := Trim( Copy( TTerm, 5, MaxInt ) );
    end;

    // Handle Defined(X) syntax
    if SameText( Copy( TTerm, 1, 8 ), 'DEFINED(' ) then
    begin
      TP1 := Pos( '(', TTerm );
      TP2 := Pos( ')', TTerm );

      if ( TP1 > 0 ) and ( TP2 > TP1 ) then
      begin
        TDefName := Trim( Copy( TTerm, TP1 + 1, TP2 - TP1 - 1 ) );

        if IsDefineDefined( TDefName ) then
          Result := 1
        else
          Result := 0;

        if IsNot then
          Result := 1 - Result;

        Exit;
      end;
    end;

    // Handle simple identifier (treat as Defined(X))
    if ( Pos( '(', TTerm ) = 0 ) and ( Pos( ' ', TTerm ) = 0 ) then
    begin

      if IsDefineDefined( TTerm ) then
        Result := 1
      else
        Result := 0;

      if IsNot then
        Result := 1 - Result;
    end;

  end;

  function SplitByOperator( const S, Op: string ): TArray<string>;
  var
    UpperS: string;
    StartPos, FoundPos: Integer;
    Count: Integer;
  begin
    SetLength( Result, 0 );
    UpperS   := UpperCase( S );
    StartPos := 1;
    Count    := 0;

    while StartPos <= Length( S ) do
    begin
      FoundPos := Pos( Op, Copy( UpperS, StartPos, MaxInt ) );

      if FoundPos = 0 then
      begin
        SetLength( Result, Count + 1 );
        Result[ Count ] := Trim( Copy( S, StartPos, MaxInt ) );
        Break;
      end
      else
      begin
        SetLength( Result, Count + 1 );
        Result[ Count ] := Trim( Copy( S, StartPos, FoundPos - 1 ) );
        Inc( Count );
        StartPos := StartPos + FoundPos + Length( Op ) - 1;
      end;
    end;

  end;

var
  OrParts, AndParts: TArray<string>;
  I, J: Integer;
  OrResult, AndResult, TermResult: Integer;
  HasUnknown: Boolean;
begin

  // Returns: 1 = true, 0 = false, -1 = unknown/cannot evaluate
  Result      := -1;
  TrimmedCond := Trim( Condition );

  if TrimmedCond = '' then
    Exit;

  // Handle NOT prefix for entire expression
  NotPrefix := False;

  if SameText( Copy( TrimmedCond, 1, 4 ), 'NOT ' ) then
  begin
    NotPrefix   := True;
    TrimmedCond := Trim( Copy( TrimmedCond, 5, MaxInt ) );
  end;

  // Check for compound OR expression
  if Pos( ' OR ', UpperCase( TrimmedCond ) ) > 0 then
  begin
    OrParts    := SplitByOperator( TrimmedCond, ' OR ' );
    OrResult   := 0;     // Start with false for OR
    HasUnknown := False;

    for I := 0 to High( OrParts ) do
    begin
      // Each OR part might have AND sub-parts
      if Pos( ' AND ', UpperCase( OrParts[ I ] ) ) > 0 then
      begin
        AndParts  := SplitByOperator( OrParts[ I ], ' AND ' );
        AndResult := 1; // Start with true for AND

        for J := 0 to High( AndParts ) do
        begin
          TermResult := EvaluateSingleTerm( AndParts[ J ] );

          if TermResult = -1 then
            HasUnknown := True
          else if TermResult = 0 then
          begin
            AndResult := 0;
            Break; // AND fails if any term is false
          end;
        end;

        if AndResult = 1 then
        begin
          OrResult := 1;
          Break; // OR succeeds if any term is true
        end;
      end
      else
      begin
        TermResult := EvaluateSingleTerm( OrParts[ I ] );

        if TermResult = -1 then
          HasUnknown := True
        else if TermResult = 1 then
        begin
          OrResult := 1;
          Break; // OR succeeds if any term is true
        end;
      end;
    end;

    if OrResult = 1 then
      Result := 1
    else if HasUnknown then
      Result := -1
    else
      Result := 0;

    if NotPrefix and ( Result >= 0 ) then
      Result := 1 - Result;

    Exit;
  end;

  // Check for compound AND expression (without OR)
  if Pos( ' AND ', UpperCase( TrimmedCond ) ) > 0 then
  begin
    AndParts   := SplitByOperator( TrimmedCond, ' AND ' );
    AndResult  := 1; // Start with true for AND
    HasUnknown := False;

    for I := 0 to High( AndParts ) do
    begin
      TermResult := EvaluateSingleTerm( AndParts[ I ] );

      if TermResult = -1 then
        HasUnknown := True
      else if TermResult = 0 then
      begin
        AndResult := 0;
        Break; // AND fails if any term is false
      end;
    end;

    if AndResult = 0 then
      Result := 0
    else if HasUnknown then
      Result := -1
    else
      Result := 1;

    if NotPrefix and ( Result >= 0 ) then
      Result := 1 - Result;

    Exit;
  end;

  // Handle Defined(X) syntax - simple case
  if SameText( Copy( TrimmedCond, 1, 8 ), 'DEFINED(' ) then
  begin
    P1 := Pos( '(', TrimmedCond );
    P2 := Pos( ')', TrimmedCond );

    if ( P1 > 0 ) and ( P2 > P1 ) then
    begin
      DefName := Trim( Copy( TrimmedCond, P1 + 1, P2 - P1 - 1 ) );

      if IsDefineDefined( DefName ) then
        InnerResult := 1
      else
        InnerResult := 0;

      if NotPrefix then
        InnerResult := 1 - InnerResult;

      Result := InnerResult;
      Exit;
    end;
  end;

  // Handle simple identifier (treat as Defined(X))
  if ( Pos( '(', TrimmedCond ) = 0 ) and ( Pos( ' ', TrimmedCond ) = 0 ) then
  begin

    if IsDefineDefined( TrimmedCond ) then
      InnerResult := 1
    else
      InnerResult := 0;

    if NotPrefix then
      InnerResult := 1 - InnerResult;

    Result := InnerResult;
  end;

end;

procedure TDependencyScanner.ParseUsesClause( const Content: string; UnitInfo: TUnitInfo );
type
  TCondState = record
    Active: Boolean;       // Is this block active (condition was true)?
    WasActive: Boolean;    // Was any branch in this IF/ELSE chain active?
    ParentActive: Boolean; // Was parent block active when we entered?
  end;
var
  I, Len, BraceEnd: Integer;
  InInterface, InImplementation: Boolean;
  InUses, InString, InComment, InLineComment: Boolean;
  Token: string;
  Ch: Char;
  Dep: TUnitDependency;
  CondStack: TList<TCondState>;
  DirectiveContent, DefineName, IfCondition: string;

  function IsCodeActive: Boolean;
  var
    J: Integer;
  begin

    Result := True;

    if FRespectConditionals then
    begin

      for J := 0 to CondStack.Count - 1 do
      begin

        if not CondStack[ J ].Active then
        begin
          Result := False;
          Exit;
        end;
      end;
    end;

  end;

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
      else if SameText( Token, 'uses' ) and IsCodeActive then
        InUses := True
      else if InUses and IsCodeActive and ( not SameText( Token, 'in' ) ) then
      begin
        Dep.UnitName    := Token;
        Dep.FileName    := '';
        Dep.IsInterface := InInterface;
        UnitInfo.Dependencies.Add( Dep );
      end;

      Token := '';
    end;

  end;

  procedure ProcessDirective( const Directive: string );
  var
    DirUpper: string;
    NewState: TCondState;
    TopState: TCondState;
    EvalResult: Integer;
  begin

    DirUpper := UpperCase( Trim( Directive ) );

    // {$IFDEF X}
    if Copy( DirUpper, 1, 6 ) = 'IFDEF ' then
    begin
      DefineName          := Trim( Copy( Directive, 7, MaxInt ) );
      NewState.ParentActive := IsCodeActive;
      NewState.Active     := NewState.ParentActive and IsDefineDefined( DefineName );
      NewState.WasActive  := NewState.Active;
      CondStack.Add( NewState );
    end
    // {$IFNDEF X}
    else if Copy( DirUpper, 1, 7 ) = 'IFNDEF ' then
    begin
      DefineName          := Trim( Copy( Directive, 8, MaxInt ) );
      NewState.ParentActive := IsCodeActive;
      NewState.Active     := NewState.ParentActive and ( not IsDefineDefined( DefineName ) );
      NewState.WasActive  := NewState.Active;
      CondStack.Add( NewState );
    end
    // {$IF ...}
    else if ( Copy( DirUpper, 1, 3 ) = 'IF ' ) or ( Copy( DirUpper, 1, 3 ) = 'IF(' ) then
    begin

      if Copy( DirUpper, 1, 3 ) = 'IF ' then
        IfCondition := Trim( Copy( Directive, 4, MaxInt ) )
      else
        IfCondition := Trim( Copy( Directive, 3, MaxInt ) );

      NewState.ParentActive := IsCodeActive;
      EvalResult          := EvaluateIfCondition( IfCondition );

      if EvalResult = 1 then
        NewState.Active := NewState.ParentActive
      else if EvalResult = 0 then
        NewState.Active := False
      else
        NewState.Active := NewState.ParentActive; // Unknown - include for safety

      NewState.WasActive := NewState.Active;
      CondStack.Add( NewState );
    end
    // {$ELSEIF ...}
    else if ( Copy( DirUpper, 1, 7 ) = 'ELSEIF ' ) or ( Copy( DirUpper, 1, 7 ) = 'ELSEIF(' ) then
    begin

      if CondStack.Count > 0 then
      begin
        TopState := CondStack[ CondStack.Count - 1 ];

        // Only consider ELSEIF if no previous branch was active
        if TopState.WasActive then
          TopState.Active := False
        else
        begin

          if Copy( DirUpper, 1, 7 ) = 'ELSEIF ' then
            IfCondition := Trim( Copy( Directive, 8, MaxInt ) )
          else
            IfCondition := Trim( Copy( Directive, 7, MaxInt ) );

          EvalResult := EvaluateIfCondition( IfCondition );

          if EvalResult = 1 then
          begin
            TopState.Active    := TopState.ParentActive;
            TopState.WasActive := True;
          end
          else
            TopState.Active := False;
        end;

        CondStack[ CondStack.Count - 1 ] := TopState;
      end;
    end
    // {$ELSE}
    else if DirUpper = 'ELSE' then
    begin

      if CondStack.Count > 0 then
      begin
        TopState := CondStack[ CondStack.Count - 1 ];

        // ELSE is active only if no previous branch was active
        if TopState.WasActive then
          TopState.Active := False
        else
        begin
          TopState.Active    := TopState.ParentActive;
          TopState.WasActive := True;
        end;

        CondStack[ CondStack.Count - 1 ] := TopState;
      end;
    end
    // {$ENDIF} or {$IFEND}
    else if ( DirUpper = 'ENDIF' ) or ( DirUpper = 'IFEND' ) then
    begin

      if CondStack.Count > 0 then
        CondStack.Delete( CondStack.Count - 1 );
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
  Token            := '';
  CondStack        := TList<TCondState>.Create;

  try

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

      // Handle block comments (* ... *)
      if InComment then
      begin

        if ( Ch = '*' ) and ( I < Len ) and ( Content[ I + 1 ] = ')' ) then
        begin
          InComment := False;
          Inc( I );
        end;

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

      // Check for comment start //
      if ( Ch = '/' ) and ( I < Len ) and ( Content[ I + 1 ] = '/' ) then
      begin
        AddToken;
        InLineComment := True;
        Inc( I, 2 );
        Continue;
      end;

      // Check for comment start (*
      if ( Ch = '(' ) and ( I < Len ) and ( Content[ I + 1 ] = '*' ) then
      begin
        AddToken;
        InComment := True;
        Inc( I, 2 );
        Continue;
      end;

      // Handle braces { ... } - could be comment or directive
      if Ch = '{' then
      begin
        AddToken;

        // Find the closing brace
        BraceEnd := I + 1;

        while ( BraceEnd <= Len ) and ( Content[ BraceEnd ] <> '}' ) do
          Inc( BraceEnd );

        if BraceEnd <= Len then
        begin
          // Extract content between braces
          DirectiveContent := Copy( Content, I + 1, BraceEnd - I - 1 );

          // Check if it's a compiler directive
          if ( Length( DirectiveContent ) > 0 ) and ( DirectiveContent[ 1 ] = '$' ) then
          begin
            // It's a directive - process it
            DirectiveContent := Copy( DirectiveContent, 2, MaxInt ); // Remove $
            ProcessDirective( DirectiveContent );
          end;
          // Else it's just a comment - ignore

          I := BraceEnd + 1;
          Continue;
        end
        else
        begin
          // No closing brace found - skip to end
          I := Len + 1;
          Continue;
        end;
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
  finally
    CondStack.Free;
  end;

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
      try
        SL.LoadFromFile( FileName );
        Content := SL.Text;
      except
        // Locked / unreadable / encoding-rejected file: skip it rather than
        // aborting the whole project scan with an unhandled exception.
        on E: Exception do
          Content := '';
      end;
    finally
      SL.Free;
    end;

    if Content <> '' then
    begin
      ParseUsesClause( Content, UnitInfo );
      UnitInfo.Parsed := True;
    end;

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
  SearchPath, OutputDir, DefinesStr: string;
  SL: TStringList;
begin

  if Project = nil then
    Exit;

  Clear;

  // Add project directory as search path
  AddSearchPath( ExtractFileDir( Project.FileName ) );

  // Get search paths and defines from project options
  Options := Project.ProjectOptions;

  if Options <> nil then
  begin
    // Extract conditional defines
    if FRespectConditionals then
    begin
      DefinesStr := VarToStr( Options.Values[ 'Defines' ] );

      if DefinesStr <> '' then
      begin
        SL := TStringList.Create;

        try
          SL.Delimiter       := ';';
          SL.StrictDelimiter := True;
          SL.DelimitedText   := DefinesStr;

          for I := 0 to SL.Count - 1 do
          begin

            if Trim( SL[ I ] ) <> '' then
              FProjectDefines.Add( Trim( SL[ I ] ) );
          end;
        finally
          SL.Free;
        end;
      end;
    end;

    // Extract search paths
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
    if ModuleInfo = nil then
      Continue;
    FileName := ModuleInfo.FileName;

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

{ TLayerConfig }

constructor TLayerConfig.Create( const AConfigFile: string );
begin

  inherited Create;
  FConfigFile  := AConfigFile;
  FLayers      := TList<TLayerDefinition>.Create;
  FAllowedDeps := TDictionary<string, TStringList>.Create;

end;

destructor TLayerConfig.Destroy;
var
  Pair: TPair<string, TStringList>;
begin

  for Pair in FAllowedDeps do
    Pair.Value.Free;

  FAllowedDeps.Free;
  FLayers.Free;
  inherited Destroy;

end;

procedure TLayerConfig.Clear;
var
  Pair: TPair<string, TStringList>;
begin

  FLayers.Clear;

  for Pair in FAllowedDeps do
    Pair.Value.Free;

  FAllowedDeps.Clear;

end;

procedure TLayerConfig.AddLayer( const Name: string; const Patterns: TArray<string> );
var
  Layer: TLayerDefinition;
begin

  Layer.Name     := Name;
  Layer.Patterns := Patterns;
  FLayers.Add( Layer );

end;

procedure TLayerConfig.SetAllowedDependencies( const FromLayer: string;
  const ToLayers: TArray<string> );
var
  SL: TStringList;
  I: Integer;
begin

  SL := TStringList.Create;
  SL.CaseSensitive := False;
  SL.Sorted        := True;
  SL.Duplicates    := dupIgnore;

  for I := 0 to High( ToLayers ) do
    SL.Add( ToLayers[ I ] );

  if FAllowedDeps.ContainsKey( FromLayer ) then
    FAllowedDeps[ FromLayer ].Free;

  FAllowedDeps.AddOrSetValue( FromLayer, SL );

end;

function TLayerConfig.GetLayerForUnit( const UnitName: string ): string;
var
  Layer: TLayerDefinition;
  Pattern: string;
  UpperUnit, UpperPattern: string;

  function MatchesWildcard( const S, Pattern: string ): Boolean;
  var
    SI, PI: Integer;
  begin
    // Simple wildcard matching: * matches any sequence, ? matches single char
    Result := False;
    SI     := 1;
    PI     := 1;

    while ( SI <= Length( S ) ) and ( PI <= Length( Pattern ) ) do
    begin

      if Pattern[ PI ] = '*' then
      begin
        // Skip consecutive stars
        while ( PI <= Length( Pattern ) ) and ( Pattern[ PI ] = '*' ) do
          Inc( PI );

        if PI > Length( Pattern ) then
        begin
          Result := True;
          Exit;
        end;

        // Find next matching position
        while SI <= Length( S ) do
        begin

          if MatchesWildcard( Copy( S, SI, MaxInt ), Copy( Pattern, PI, MaxInt ) ) then
          begin
            Result := True;
            Exit;
          end;

          Inc( SI );
        end;

        Exit;
      end
      else if ( Pattern[ PI ] = '?' ) or ( Pattern[ PI ] = S[ SI ] ) then
      begin
        Inc( SI );
        Inc( PI );
      end
      else
        Exit;
    end;

    // Skip trailing stars
    while ( PI <= Length( Pattern ) ) and ( Pattern[ PI ] = '*' ) do
      Inc( PI );

    Result := ( SI > Length( S ) ) and ( PI > Length( Pattern ) );

  end;

begin

  Result    := '';
  UpperUnit := UpperCase( UnitName );

  for Layer in FLayers do
  begin

    for Pattern in Layer.Patterns do
    begin
      UpperPattern := UpperCase( Pattern );

      if MatchesWildcard( UpperUnit, UpperPattern ) then
      begin
        Result := Layer.Name;
        Exit;
      end;
    end;
  end;

end;

function TLayerConfig.IsDependencyAllowed( const FromLayer, ToLayer: string ): Boolean;
var
  SL: TStringList;
begin

  Result := True;

  // Same layer is always allowed
  if SameText( FromLayer, ToLayer ) then
    Exit;

  // If no rules defined for this layer, allow all
  if not FAllowedDeps.TryGetValue( FromLayer, SL ) then
    Exit;

  // Check if target layer is in allowed list
  Result := SL.IndexOf( ToLayer ) >= 0;

end;

function TLayerConfig.GetLayers: TArray<TLayerDefinition>;
begin

  Result := FLayers.ToArray;

end;

function TLayerConfig.GetAllowedDependencies( const LayerName: string ): TArray<string>;
var
  SL: TStringList;
  I: Integer;
begin

  if FAllowedDeps.TryGetValue( LayerName, SL ) then
  begin
    SetLength( Result, SL.Count );

    for I := 0 to SL.Count - 1 do
      Result[ I ] := SL[ I ];
  end
  else
    SetLength( Result, 0 );

end;

procedure TLayerConfig.LoadDefaults;
begin

  Clear;

  // Default layer configuration for a typical Delphi project
  AddLayer( 'UI', [ '*Frm', '*Form', '*Frame', 'Frm*', 'Form*', 'Frame*' ] );
  AddLayer( 'Business', [ '*Logic', '*Service', '*Manager', '*Controller' ] );
  AddLayer( 'DataAccess', [ '*DM', '*DataModule', '*Data', '*Repository', 'dm*' ] );
  AddLayer( 'Core', [ '*Utils', '*Types', '*Consts', '*Common', '*Helpers' ] );

  // Default rules: UI -> Business, DataAccess, Core; Business -> DataAccess, Core; DataAccess -> Core
  SetAllowedDependencies( 'UI', [ 'Business', 'DataAccess', 'Core' ] );
  SetAllowedDependencies( 'Business', [ 'DataAccess', 'Core' ] );
  SetAllowedDependencies( 'DataAccess', [ 'Core' ] );
  SetAllowedDependencies( 'Core', [ ] );

end;

procedure TLayerConfig.LoadFromFile;
var
  SL, Lines: TStringList;
  I, J: Integer;
  Line, LayerName, PatternStr, AllowedStr: string;
  Patterns, Allowed: TArray<string>;
  InLayers, InRules: Boolean;
begin

  if not FileExists( FConfigFile ) then
  begin
    LoadDefaults;
    Exit;
  end;

  Clear;
  SL       := TStringList.Create;
  Lines    := TStringList.Create;
  InLayers := False;
  InRules  := False;

  try
    SL.LoadFromFile( FConfigFile );

    for I := 0 to SL.Count - 1 do
    begin
      Line := Trim( SL[ I ] );

      if ( Line = '' ) or ( Line[ 1 ] = '#' ) then
        Continue;

      if Line = '[Layers]' then
      begin
        InLayers := True;
        InRules  := False;
        Continue;
      end;

      if Line = '[Rules]' then
      begin
        InLayers := False;
        InRules  := True;
        Continue;
      end;

      if InLayers then
      begin
        // Format: LayerName=Pattern1,Pattern2,Pattern3
        J := Pos( '=', Line );

        if J > 0 then
        begin
          LayerName  := Trim( Copy( Line, 1, J - 1 ) );
          PatternStr := Trim( Copy( Line, J + 1, MaxInt ) );

          Lines.Clear;
          Lines.Delimiter       := ',';
          Lines.StrictDelimiter := True;
          Lines.DelimitedText   := PatternStr;

          SetLength( Patterns, Lines.Count );

          for J := 0 to Lines.Count - 1 do
            Patterns[ J ] := Trim( Lines[ J ] );

          AddLayer( LayerName, Patterns );
        end;
      end;

      if InRules then
      begin
        // Format: FromLayer=ToLayer1,ToLayer2,ToLayer3
        J := Pos( '=', Line );

        if J > 0 then
        begin
          LayerName  := Trim( Copy( Line, 1, J - 1 ) );
          AllowedStr := Trim( Copy( Line, J + 1, MaxInt ) );

          Lines.Clear;
          Lines.Delimiter       := ',';
          Lines.StrictDelimiter := True;
          Lines.DelimitedText   := AllowedStr;

          SetLength( Allowed, Lines.Count );

          for J := 0 to Lines.Count - 1 do
            Allowed[ J ] := Trim( Lines[ J ] );

          SetAllowedDependencies( LayerName, Allowed );
        end;
      end;
    end;
  finally
    Lines.Free;
    SL.Free;
  end;

end;

procedure TLayerConfig.SaveToFile;
var
  SL: TStringList;
  Layer: TLayerDefinition;
  I: Integer;
  Line: string;
  Pair: TPair<string, TStringList>;
begin

  SL := TStringList.Create;

  try
    SL.Add( '# Layer Configuration for Dependency Viewer' );
    SL.Add( '# Patterns support wildcards: * (multiple chars), ? (single char)' );
    SL.Add( '' );
    SL.Add( '[Layers]' );

    for Layer in FLayers do
    begin
      Line := Layer.Name + '=';

      for I := 0 to High( Layer.Patterns ) do
      begin

        if I > 0 then
          Line := Line + ',';

        Line := Line + Layer.Patterns[ I ];
      end;

      SL.Add( Line );
    end;

    SL.Add( '' );
    SL.Add( '[Rules]' );

    for Pair in FAllowedDeps do
    begin
      Line := Pair.Key + '=';

      for I := 0 to Pair.Value.Count - 1 do
      begin

        if I > 0 then
          Line := Line + ',';

        Line := Line + Pair.Value[ I ];
      end;

      SL.Add( Line );
    end;

    SL.SaveToFile( FConfigFile );
  finally
    SL.Free;
  end;

end;

function TDependencyScanner.DetectLayerViolations( LayerConfig: TLayerConfig ): TArray<TLayerViolation>;
var
  Violations: TList<TLayerViolation>;
  Pair: TPair<string, TUnitInfo>;
  UnitInfo: TUnitInfo;
  Dep: TUnitDependency;
  SourceLayer, TargetLayer: string;
  Violation: TLayerViolation;
begin

  Violations := TList<TLayerViolation>.Create;

  try

    for Pair in FUnits do
    begin
      UnitInfo    := Pair.Value;
      SourceLayer := LayerConfig.GetLayerForUnit( UnitInfo.UnitName );

      // Skip units that don't belong to any defined layer
      if SourceLayer = '' then
        Continue;

      for Dep in UnitInfo.Dependencies do
      begin
        TargetLayer := LayerConfig.GetLayerForUnit( Dep.UnitName );

        // Skip dependencies to units not in any layer
        if TargetLayer = '' then
          Continue;

        // Check if this dependency violates layer rules
        if not LayerConfig.IsDependencyAllowed( SourceLayer, TargetLayer ) then
        begin
          Violation.SourceUnit  := UnitInfo.UnitName;
          Violation.SourceLayer := SourceLayer;
          Violation.TargetUnit  := Dep.UnitName;
          Violation.TargetLayer := TargetLayer;
          Violation.IsInterface := Dep.IsInterface;
          Violations.Add( Violation );
        end;
      end;
    end;

    Result := Violations.ToArray;
  finally
    Violations.Free;
  end;

end;

{ TDependencyViewerPlugin }

constructor TDependencyViewerPlugin.Create;
begin

  inherited Create( AppDataDirectory + '\DependencyViewer.xml', 'DependencyViewer' );

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem         := TMenuItem.Create( DDevExtensionsMenu );
    FMenuItem.Caption := '&Dependency Viewer...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add( FMenuItem );
  end;

end;

destructor TDependencyViewerPlugin.Destroy;
begin

  FreeAndNil( FMenuItem );
  inherited Destroy;

end;

procedure TDependencyViewerPlugin.Init;
begin

  FEnabled             := True;
  FRespectConditionals := True;

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
