{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit DependencyViewerCore;

/// <summary>
/// Pure core of the Dependency Viewer: the uses-clause parser ( with conditional compilation ),
/// the dependency graph with its cycles, depths and impact analysis, and the layer rules.  No
/// ToolsAPI and no VCL, so it is unit-testable outside the IDE; the plugin unit feeds it a
/// project's units.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

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
    /// <summary>Ordered sequence of steps that closes back on the first step: the shortest cycle
    /// through the group's first member.</summary>
    Steps: TArray<TCircularReferenceStep>;
    /// <summary>Every unit of the strongly-connected group, alphabetically; the cycle in
    /// <see cref="Steps"/> may pass through only some of them.</summary>
    Members: TArray<string>;
  end;

  /// <summary>Supplies a file's text to the scanner ( a unit's, or an <c>{$I}</c> include file's ).</summary>
  /// <param name="AFileName">The file to read.</param>
  /// <param name="AContent">Receives its text.</param>
  /// <returns>False when the file cannot be read.</returns>
  TDependencySourceReader = reference to function( const AFileName: string; out AContent: string ): Boolean;

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
    /// <returns>"Safe", "Low", "Medium" or "High"; "Unknown" for any other level.</returns>
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
    /// <summary>Removes the layer definitions and keeps every rule line, so the Layers dialog can
    /// redefine the layers without losing rules for layers it does not show.</summary>
    procedure ClearLayers;
    /// <summary>Removes a layer's rule line, so that it may depend on every layer again.</summary>
    /// <param name="LayerName">The source layer.</param>
    procedure RemoveRules( const LayerName: string );
    /// <summary>Adds a new layer with the supplied wildcard patterns.</summary>
    /// <param name="Name">Layer name.</param>
    /// <param name="Patterns">Unit-name match patterns.</param>
    procedure AddLayer( const Name: string; const Patterns: TArray<string> );
    /// <summary>Sets the layers that <paramref name="FromLayer"/> is permitted to depend on.</summary>
    /// <param name="FromLayer">Source layer name.</param>
    /// <param name="ToLayers">Allowed target layer names.</param>
    procedure SetAllowedDependencies( const FromLayer: string; const ToLayers: TArray<string> );
    /// <summary>Returns the layer name a given unit belongs to, or empty if no pattern matches.</summary>
    /// <param name="UnitName">The unit name to match against the layer patterns.</param>
    /// <returns>The first layer with a matching pattern; empty when none matches.</returns>
    function GetLayerForUnit( const UnitName: string ): string;
    /// <summary>Returns True when <paramref name="FromLayer"/> may depend on <paramref name="ToLayer"/>.</summary>
    /// <remarks>Same-layer dependencies are always allowed; layers with no rules allow all targets.</remarks>
    /// <param name="FromLayer">The layer of the using unit.</param>
    /// <param name="ToLayer">The layer of the used unit.</param>
    /// <returns>True when the dependency breaks no rule.</returns>
    function IsDependencyAllowed( const FromLayer, ToLayer: string ): Boolean;
    /// <summary>Returns a snapshot of all defined layers.</summary>
    /// <returns>A copy of the layer list, in definition order.</returns>
    function GetLayers: TArray<TLayerDefinition>;
    /// <summary>True when the layer has a rule line, even an empty one; a layer without one may
    /// depend on every layer.</summary>
    /// <param name="LayerName">The source layer.</param>
    /// <returns>True when a rule is stored for the layer.</returns>
    function HasRules( const LayerName: string ): Boolean;
    /// <summary>Returns the allowed target layer names for the given source layer.</summary>
    /// <param name="LayerName">The source layer.</param>
    /// <returns>The allowed target layers; empty both when none is allowed and when the layer has no rule line ( see HasRules ).</returns>
    function GetAllowedDependencies( const LayerName: string ): TArray<string>;
    /// <summary>Loads layers and rules from the configured file; falls back to defaults if missing.</summary>
    procedure LoadFromFile;
    /// <summary>Loads layers and rules from the lines of a configuration file.</summary>
    /// <param name="SL">The lines; nothing is kept from the previous configuration.</param>
    procedure LoadFromStrings( SL: TStrings );
    /// <summary>Writes the layers and rules as the lines of a configuration file.</summary>
    /// <param name="SL">Receives the lines; it is cleared first.</param>
    procedure SaveToStrings( SL: TStrings );
    /// <summary>Persists the current layers and rules to the configured file, as UTF-8, replacing
    /// it only once the new text is written.</summary>
    /// <exception cref="EFCreateError">Raised when the file cannot be written or replaced.</exception>
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
    /// <summary>Backing field for <see cref="OnReadSource"/>.</summary>
    FOnReadSource: TDependencySourceReader;
    /// <summary>While a unit is parsed: the project defines plus its own {$DEFINE}s, less its
    /// {$UNDEF}s.  Nil otherwise.</summary>
    FActiveDefines: TStringList;
    /// <summary>Parses the supplied source content and populates <paramref name="UnitInfo"/>'s dependencies.</summary>
    /// <param name="Content">The unit's source text.</param>
    /// <param name="UnitInfo">The unit; each uses entry found is added to its Dependencies.</param>
    procedure ParseUsesClause( const Content: string; UnitInfo: TUnitInfo );
    /// <summary>Finds each strongly-connected group of units once and populates
    /// <see cref="CircularReferences"/>.</summary>
    procedure DetectCircularReferences;
    /// <summary>Reads a unit or include file through <see cref="OnReadSource"/>, or from disk.</summary>
    /// <param name="AFileName">The file to read.</param>
    /// <param name="AContent">Receives its text.</param>
    /// <returns>False when the file cannot be read.</returns>
    function ReadSourceText( const AFileName: string; out AContent: string ): Boolean;
    /// <summary>Builds the reverse-dependency map after scanning is complete.</summary>
    procedure BuildReverseDependencies;
    /// <summary>Computes the depth of every unit in the graph.</summary>
    procedure CalculateDepths;
    /// <summary>Recursively computes the depth of a single unit, guarding against cycles.</summary>
    /// <param name="UnitName">The unit whose depth is wanted.</param>
    /// <param name="Calculating">Units whose depth is being worked out on the current walk; meeting one again means a cycle, which counts as depth 0.</param>
    /// <returns>The length of the longest chain of project units below the unit; 0 for a unit outside the project or one met again on a cycle.</returns>
    function CalculateUnitDepth( const UnitName: string;
      var Calculating: TDictionary<string, Boolean> ): Integer;
    /// <summary>Returns True when the supplied conditional define is active for this project.</summary>
    /// <param name="DefineName">The conditional symbol.</param>
    /// <returns>True when the symbol is defined for the unit being parsed ( or for the project, outside a parse ).</returns>
    function IsDefineDefined( const DefineName: string ): Boolean;
    /// <summary>Evaluates a conditional expression. Returns 1 (true), 0 (false) or -1 (unknown).</summary>
    /// <param name="Condition">The expression after $IF or $ELSEIF.</param>
    /// <returns>1 when the expression is true, 0 when false, -1 when it cannot be judged here.</returns>
    function EvaluateIfCondition( const Condition: string ): Integer;
  public
    /// <summary>Creates a new scanner with empty state.</summary>
    constructor Create;
    /// <summary>Releases all owned resources.</summary>
    destructor Destroy; override;
    /// <summary>Clears all scan results, search paths and project defines.</summary>
    procedure Clear;
    /// <summary>Adds a directory to the unit search path (duplicates are ignored).</summary>
    /// <param name="Path">A directory; one that does not exist is ignored.</param>
    procedure AddSearchPath( const Path: string );
    /// <summary>Adds a conditional symbol that counts as defined ( project define or predefined ).</summary>
    /// <param name="ADefine">The symbol.</param>
    procedure AddDefine( const ADefine: string );
    /// <summary>Parses one unit's text and adds it to the graph.</summary>
    /// <param name="AUnitName">Unit name without path or extension.</param>
    /// <param name="AFileName">Its file; empty for an in-memory unit.</param>
    /// <param name="AContent">Its text.</param>
    procedure ScanSource( const AUnitName, AFileName, AContent: string );
    /// <summary>Loads and parses a single unit, adding it to the graph if not already present.</summary>
    /// <param name="UnitName">Unit name without path or extension.</param>
    /// <param name="FileName">Its file.</param>
    procedure ScanUnit( const UnitName, FileName: string );
    /// <summary>Works out the cycles, reverse dependencies and depths once every unit is scanned.</summary>
    procedure Analyse;
    /// <summary>Scans a single .pas file (also adding its directory to the search path).</summary>
    /// <param name="FileName">The .pas file; any other file is ignored.</param>
    procedure ScanFile( const FileName: string );
    /// <summary>Returns the <see cref="TUnitInfo"/> for a unit name, or nil if not scanned.</summary>
    /// <param name="UnitName">The unit name, without path or extension.</param>
    /// <returns>The unit, or nil when it was not scanned.</returns>
    function GetUnitInfo( const UnitName: string ): TUnitInfo;
    /// <summary>Returns a snapshot of all units known to the scanner.</summary>
    /// <returns>Every scanned unit, in no particular order; the scanner still owns them.</returns>
    function GetAllUnits: TArray<TUnitInfo>;
    /// <summary>Returns the list of units that reference the named unit, or nil if none.</summary>
    /// <param name="UnitName">The used unit.</param>
    /// <returns>The units that use it, sorted; nil when none does.  The scanner owns the list.</returns>
    function GetReverseDependencies( const UnitName: string ): TStringList;
    /// <summary>Returns the dependency depth of a unit (0 for external/leaf units).</summary>
    /// <param name="UnitName">The unit name, without path or extension.</param>
    /// <returns>The unit's depth; 0 for an unknown unit.</returns>
    function GetUnitDepth( const UnitName: string ): Integer;
    /// <summary>Computes impact analysis for a unit, including direct and transitive dependents.</summary>
    /// <param name="UnitName">The unit a change would start from.</param>
    /// <returns>Its direct and transitive dependents and a risk level from the transitive count.</returns>
    function AnalyzeImpact( const UnitName: string ): TImpactAnalysis;
    /// <summary>Returns all dependencies that violate the supplied layer configuration.</summary>
    /// <param name="LayerConfig">The layer definitions and rules to check against.</param>
    /// <returns>Each uses entry between two layered units that the rules forbid.</returns>
    function DetectLayerViolations( LayerConfig: TLayerConfig ): TArray<TLayerViolation>;
    /// <summary>Detected circular references after the most recent scan.</summary>
    property CircularReferences: TList<TCircularReference> read FCircularRefs;
    /// <summary>Notification fired periodically during scanning so the UI can update progress.</summary>
    property OnProgress: TNotifyEvent read FOnProgress write FOnProgress;
    /// <summary>Name of the unit currently being processed (set just before <see cref="OnProgress"/> fires).</summary>
    property ProgressUnit: string read FProgressUnit;
    /// <summary>When True, the parser honours $IFDEF/$IF directives using the project defines.</summary>
    property RespectConditionals: Boolean read FRespectConditionals write FRespectConditionals;
    /// <summary>Reads units and include files; nil reads them from disk.</summary>
    property OnReadSource: TDependencySourceReader read FOnReadSource write FOnReadSource;
  end;

/// <summary>The conditional symbols the compiler defines by itself for a target platform.</summary>
/// <param name="APlatform">The platform as the IDE names it ( <c>Win32</c>, <c>Win64</c> ).</param>
/// <returns>The symbols, e.g. MSWINDOWS, WIN64, CPUX64, UNICODE and the VERnnn of this compiler.</returns>
function PredefinedSymbols( const APlatform: string ): TArray<string>;

/// <summary>The layer rules as a From x To matrix of ticks, as the Layers dialog shows them.</summary>
/// <param name="AConfig">The configuration to read.</param>
/// <param name="ALayerNames">The layers, in matrix order.</param>
/// <returns>[From][To] True where From may depend on To.</returns>
function LayerRulesMatrix( AConfig: TLayerConfig; const ALayerNames: TArray<string> ): TArray<TArray<Boolean>>;

/// <summary>Stores a From x To matrix of ticks as the rules of the layers named; rule lines of any
/// other layer are left as they are.  A row with every box ticked is stored as no rule line.</summary>
/// <param name="AConfig">The configuration to change; its layers must already be set.</param>
/// <param name="ALayerNames">The layers, in matrix order.</param>
/// <param name="AMatrix">[From][To] True where From may depend on To.</param>
procedure ApplyLayerRulesMatrix( AConfig: TLayerConfig; const ALayerNames: TArray<string>;
  const AMatrix: TArray<TArray<Boolean>> );

implementation

uses
  Winapi.Windows, System.Generics.Defaults, System.IOUtils, DecirculariserCore;

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

  if ( FActiveDefines <> nil ) then
    Result := FActiveDefines.IndexOf( DefineName ) >= 0
  else
    Result := FProjectDefines.IndexOf( DefineName ) >= 0;

end;

function TDependencyScanner.EvaluateIfCondition( const Condition: string ): Integer;

  { One operand of an AND/OR list: [NOT] Defined(X), True or False.  Anything else - a constant,
    a comparison ( "CompilerVersion>=36" ), Declared(X), a call - cannot be judged here: -1. }
  function EvaluateSingleTerm( const Term: string ): Integer;
  var
    sTerm, sUpper, sName: string;
    bNot: Boolean;
  begin
    sTerm  := Trim( Term );
    bNot   := False;
    if SameText( Copy( sTerm, 1, 4 ), 'NOT ' ) then
    begin
      bNot  := True;
      sTerm := Trim( Copy( sTerm, 5, MaxInt ) );
    end;
    sUpper := UpperCase( sTerm );

    if sUpper.StartsWith( 'DEFINED(' ) and sUpper.EndsWith( ')' ) then
    begin
      sName := Trim( Copy( sTerm, 9, Length( sTerm ) - 9 ) );
      if ( sName = '' ) or ( Pos( '(', sName ) > 0 ) or ( Pos( ')', sName ) > 0 ) then
        Exit( -1 );
      Result := Ord( IsDefineDefined( sName ) );
    end
    else if ( sUpper = 'TRUE' ) then
      Result := 1
    else if ( sUpper = 'FALSE' ) then
      Result := 0
    else
      Exit( -1 );

    if bNot then
      Result := 1 - Result;
  end;

  { The operands of S separated by Op ( ' OR ' / ' AND ', matched without regard to case ). }
  function SplitByOperator( const S, Op: string ): TArray<string>;
  var
    sUpper: string;
    iStart, iFound: Integer;
  begin
    Result := nil;
    sUpper := UpperCase( S );
    iStart := 1;
    repeat
      iFound := Pos( Op, sUpper, iStart );
      if ( iFound = 0 ) then
        Result := Result + [ Trim( Copy( S, iStart, MaxInt ) ) ]
      else
      begin
        Result := Result + [ Trim( Copy( S, iStart, iFound - iStart ) ) ];
        iStart := iFound + Length( Op );
      end;
    until ( iFound = 0 );
  end;

var
  sCond, sStripped: string;
  bAny, bUnknown, bAll: Boolean;
begin

  // Returns: 1 = true, 0 = false, -1 = unknown/cannot evaluate
  sCond := Trim( Condition );
  if ( sCond = '' ) then
    Exit( -1 );

  { Only a flat AND/OR list of Defined() terms is judged.  Grouping parentheses would change what
    belongs to which operator, so an expression with any parenthesis that is not a Defined(X)
    call is left unknown - included, the safe side for a dependency list. }
  sStripped := UpperCase( sCond );
  while ( Pos( 'DEFINED(', sStripped ) > 0 ) do
  begin
    var iOpen  := Pos( 'DEFINED(', sStripped );
    var iClose := Pos( ')', sStripped, iOpen );
    if ( iClose = 0 ) then
      Exit( -1 );
    Delete( sStripped, iOpen, iClose - iOpen + 1 );
  end;
  if ( Pos( '(', sStripped ) > 0 ) or ( Pos( ')', sStripped ) > 0 ) then
    Exit( -1 );

  { OR of ANDs, each operand with its own NOT: "not Defined(A) and Defined(B)" is
    (not A) and B, never not (A and B). }
  bAny     := False;
  bUnknown := False;
  for var sOrPart in SplitByOperator( sCond, ' OR ' ) do
  begin
    bAll := True;
    var bAndUnknown := False;
    for var sAndPart in SplitByOperator( sOrPart, ' AND ' ) do
      case EvaluateSingleTerm( sAndPart ) of
        0:
          begin
            bAll := False;
            Break;
          end;
        -1:
          bAndUnknown := True;
      end;
    if bAll and ( not bAndUnknown ) then
      bAny := True
    else if bAll then
      bUnknown := True;
  end;

  if bAny then
    Result := 1
  else if bUnknown then
    Result := -1
  else
    Result := 0;

end;

procedure TDependencyScanner.ParseUsesClause( const Content: string; UnitInfo: TUnitInfo );
type
  TCondState = record
    Active: Boolean;       // Is this block active (condition was true)?
    WasActive: Boolean;    // Was any branch in this IF/ELSE chain active?
    ParentActive: Boolean; // Was parent block active when we entered?
  end;
const
  /// <summary>How deep {$I} files may nest before the parser stops following them ( a guard
  /// against an include file that includes itself ).</summary>
  MAX_INCLUDE_DEPTH = 16;
var
  InInterface, InImplementation: Boolean;
  InUses: Boolean;
  Token: string;
  Dep: TUnitDependency;
  CondStack: TList<TCondState>;
  DefineName, IfCondition: string;

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

  procedure ParseText( const AText: string; ADepth: Integer ); forward;

  // $I name / $INCLUDE name: the file is read like a unit - its defines and any uses entries
  // in it count - looked up beside the unit first, then on the search path.
  procedure IncludeFile( const AName: string; ADepth: Integer );
  var
    sName, sContent: string;
  begin

    if ( ADepth >= MAX_INCLUDE_DEPTH ) then
      Exit;

    sName := Trim( AName );
    if ( sName <> '' ) and CharInSet( sName[ 1 ], [ '''', '"' ] ) then
      sName := Copy( sName, 2, Length( sName ) - 2 );
    if ( sName = '' ) then
      Exit;

    var Candidates := TStringList.Create;
    try
      if ( ExtractFileDrive( sName ) <> '' ) or sName.StartsWith( '\' ) then
        Candidates.Add( sName )
      else
      begin
        if ( UnitInfo.FileName <> '' ) then
          Candidates.Add( ExpandFileName( IncludeTrailingPathDelimiter( ExtractFilePath( UnitInfo.FileName ) ) + sName ) );
        for var sPath in FSearchPaths do
          Candidates.Add( IncludeTrailingPathDelimiter( sPath ) + sName );
      end;

      for var sCandidate in Candidates do
        if ReadSourceText( sCandidate, sContent ) then
        begin
          AddToken;
          ParseText( sContent, ADepth + 1 );
          AddToken;
          Exit;
        end;
    finally
      Candidates.Free;
    end;

  end;

  procedure ProcessDirective( const Directive: string; ADepth: Integer );
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
      DefineName          := Trim( Copy( Trim( Directive ), 7, MaxInt ) );
      NewState.ParentActive := IsCodeActive;
      NewState.Active     := NewState.ParentActive and IsDefineDefined( DefineName );
      NewState.WasActive  := NewState.Active;
      CondStack.Add( NewState );
    end
    // {$IFNDEF X}
    else if Copy( DirUpper, 1, 7 ) = 'IFNDEF ' then
    begin
      DefineName          := Trim( Copy( Trim( Directive ), 8, MaxInt ) );
      NewState.ParentActive := IsCodeActive;
      NewState.Active     := NewState.ParentActive and ( not IsDefineDefined( DefineName ) );
      NewState.WasActive  := NewState.Active;
      CondStack.Add( NewState );
    end
    // {$IFOPT R+}: a compiler switch cannot be judged here, so BOTH branches count ( WasActive
    // stays False, so an {$ELSE} is taken too ) - but it is a block, and its {$ENDIF} must close
    // it and not the enclosing one.
    else if Copy( DirUpper, 1, 6 ) = 'IFOPT ' then
    begin
      NewState.ParentActive := IsCodeActive;
      NewState.Active       := NewState.ParentActive;
      NewState.WasActive    := False;
      CondStack.Add( NewState );
    end
    // {$IF ...}
    else if ( Copy( DirUpper, 1, 3 ) = 'IF ' ) or ( Copy( DirUpper, 1, 3 ) = 'IF(' ) then
    begin

      if Copy( DirUpper, 1, 3 ) = 'IF ' then
        IfCondition := Trim( Copy( Trim( Directive ), 4, MaxInt ) )
      else
        IfCondition := Trim( Copy( Trim( Directive ), 3, MaxInt ) );

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
            IfCondition := Trim( Copy( Trim( Directive ), 8, MaxInt ) )
          else
            IfCondition := Trim( Copy( Trim( Directive ), 7, MaxInt ) );

          EvalResult := EvaluateIfCondition( IfCondition );

          // Unknown counts as true, as it does for {$IF}: the branch is included.
          if ( EvalResult <> 0 ) then
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
    else if ( DirUpper = 'ENDIF' ) or ( DirUpper = 'IFEND' ) or
            DirUpper.StartsWith( 'ENDIF ' ) or DirUpper.StartsWith( 'IFEND ' ) then
    begin

      if CondStack.Count > 0 then
        CondStack.Delete( CondStack.Count - 1 );
    end
    // {$DEFINE X} / {$UNDEF X}: in force from here on, for this unit only.
    else if DirUpper.StartsWith( 'DEFINE ' ) then
    begin
      if IsCodeActive then
        FActiveDefines.Add( Trim( Copy( Trim( Directive ), 8, MaxInt ) ) );
    end
    else if DirUpper.StartsWith( 'UNDEF ' ) then
    begin
      if IsCodeActive then
      begin
        var iIndex := FActiveDefines.IndexOf( Trim( Copy( Trim( Directive ), 7, MaxInt ) ) );
        if ( iIndex >= 0 ) then
          FActiveDefines.Delete( iIndex );
      end;
    end
    // {$I file} / {$INCLUDE file} - not {$I+} / {$I-}, the I/O-checking switch.
    else if DirUpper.StartsWith( 'I ' ) or DirUpper.StartsWith( 'INCLUDE ' ) then
    begin
      if IsCodeActive then
        IncludeFile( Copy( Trim( Directive ), Pos( ' ', Trim( Directive ) ) + 1, MaxInt ), ADepth );
    end;

  end;

  procedure ParseText( const AText: string; ADepth: Integer );
  var
    I, Len, CloseIdx: Integer;
    InString, InComment, InLineComment: Boolean;
    Ch: Char;
    DirectiveContent: string;
  begin

    I             := 1;
    Len           := Length( AText );
    InString      := False;
    InComment     := False;
    InLineComment := False;

    while I <= Len do
    begin
      Ch := AText[ I ];

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

        if ( Ch = '*' ) and ( I < Len ) and ( AText[ I + 1 ] = ')' ) then
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
      if ( Ch = '/' ) and ( I < Len ) and ( AText[ I + 1 ] = '/' ) then
      begin
        AddToken;
        InLineComment := True;
        Inc( I, 2 );
        Continue;
      end;

      // (* ... *): a comment, or a directive when it opens with $ ( "(*$IFDEF X*)" )
      if ( Ch = '(' ) and ( I < Len ) and ( AText[ I + 1 ] = '*' ) then
      begin
        AddToken;
        if ( I + 2 <= Len ) and ( AText[ I + 2 ] = '$' ) then
        begin
          CloseIdx := Pos( '*)', AText, I + 3 );
          if ( CloseIdx = 0 ) then
            Break;
          ProcessDirective( Copy( AText, I + 3, CloseIdx - I - 3 ), ADepth );
          I := CloseIdx + 2;
          Continue;
        end;
        InComment := True;
        Inc( I, 2 );
        Continue;
      end;

      // Handle braces { ... } - could be comment or directive
      if Ch = '{' then
      begin
        AddToken;

        CloseIdx := Pos( '}', AText, I + 1 );
        if ( CloseIdx = 0 ) then
          Break;  // No closing brace: nothing after it can be read

        // Extract content between braces
        DirectiveContent := Copy( AText, I + 1, CloseIdx - I - 1 );

        // A compiler directive; anything else is a comment
        if ( Length( DirectiveContent ) > 0 ) and ( DirectiveContent[ 1 ] = '$' ) then
          ProcessDirective( Copy( DirectiveContent, 2, MaxInt ), ADepth );

        I := CloseIdx + 1;
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

begin

  InInterface      := False;
  InImplementation := False;
  InUses           := False;
  Token            := '';
  CondStack        := TList<TCondState>.Create;
  // The unit's own $DEFINEs and $UNDEFs apply to the rest of this unit only.
  FActiveDefines   := TStringList.Create;
  try
    FActiveDefines.CaseSensitive := False;
    FActiveDefines.Sorted        := True;
    FActiveDefines.Duplicates    := dupIgnore;
    FActiveDefines.Assign( FProjectDefines );

    ParseText( Content, 0 );
  finally
    FreeAndNil( FActiveDefines );
    CondStack.Free;
  end;

end;

function TDependencyScanner.ReadSourceText( const AFileName: string; out AContent: string ): Boolean;
begin

  AContent := '';
  if Assigned( FOnReadSource ) then
    Exit( FOnReadSource( AFileName, AContent ) );

  Result := FileExists( AFileName );
  if Result then
  try
    AContent := string( DecodeSourceBytes( TFile.ReadAllBytes( AFileName ) ) );
  except
    // Locked or vanished between the check and the read: treated as unreadable.
    on EInOutError do
      Result := False;
    on EFOpenError do
      Result := False;
  end;

end;

procedure TDependencyScanner.ScanUnit( const UnitName, FileName: string );
var
  Content: string;
begin

  if FUnits.ContainsKey( LowerCase( UnitName ) ) and FUnits[ LowerCase( UnitName ) ].Parsed then
    Exit;

  FProgressUnit := UnitName;
  if Assigned( FOnProgress ) then
    FOnProgress( Self );

  if ( FileName = '' ) or ( not ReadSourceText( FileName, Content ) ) then
    Content := '';
  ScanSource( UnitName, FileName, Content );

end;

procedure TDependencyScanner.AddDefine( const ADefine: string );
begin

  if ( Trim( ADefine ) <> '' ) then
    FProjectDefines.Add( Trim( ADefine ) );

end;

procedure TDependencyScanner.ScanSource( const AUnitName, AFileName, AContent: string );
var
  UnitInfo: TUnitInfo;
begin

  if ( not FUnits.TryGetValue( LowerCase( AUnitName ), UnitInfo ) ) then
  begin
    UnitInfo := TUnitInfo.Create( AUnitName, AFileName );
    FUnits.Add( LowerCase( AUnitName ), UnitInfo );
  end;

  if ( AContent <> '' ) then
  begin
    ParseUsesClause( AContent, UnitInfo );
    UnitInfo.Parsed := True;
  end;

end;

procedure TDependencyScanner.Analyse;
begin

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
  Adjacency: TObjectDictionary<string, TStringList>;
  Members: TStringList;
  Nodes: TArray<string>;
  Ref: TCircularReference;

  { The shortest cycle through AStart that stays inside the group: a breadth-first walk from it
    back to itself, recording for each unit the edge that reached it. }
  function ShortestCycle( const AStart: string; AGroup: TStringList ): TArray<TCircularReferenceStep>;
  var
    Queue: TQueue<string>;
    Parent: TDictionary<string, string>;
    ViaInterface: TDictionary<string, Boolean>;
    Chain: TList<TCircularReferenceStep>;
    Step: TCircularReferenceStep;
    sNode, sLast: string;
    UnitInfo: TUnitInfo;
  begin
    Result       := nil;
    Queue        := TQueue<string>.Create;
    Parent       := TDictionary<string, string>.Create;
    ViaInterface := TDictionary<string, Boolean>.Create;
    Chain        := TList<TCircularReferenceStep>.Create;
    try
      sLast := '';
      Queue.Enqueue( AStart );
      while ( Queue.Count > 0 ) and ( sLast = '' ) do
      begin
        sNode := Queue.Dequeue;
        if ( not FUnits.TryGetValue( sNode, UnitInfo ) ) then
          Continue;
        for var Dep in UnitInfo.Dependencies do
        begin
          var sTo := LowerCase( Dep.UnitName );
          if ( AGroup.IndexOf( sTo ) < 0 ) then
            Continue;
          if ( sTo = AStart ) then
          begin
            { Back at the start: remember how, and stop. }
            sLast := sNode;
            ViaInterface.AddOrSetValue( #0, Dep.IsInterface );
            Break;
          end;
          if Parent.ContainsKey( sTo ) then
            Continue;
          Parent.Add( sTo, sNode );
          ViaInterface.Add( sTo, Dep.IsInterface );
          Queue.Enqueue( sTo );
        end;
      end;
      if ( sLast = '' ) then
        Exit;

      { Walk the parents back from the last unit to the start, then close the chain. }
      sNode := sLast;
      while ( sNode <> AStart ) do
      begin
        Step.UnitName    := FUnits[ sNode ].UnitName;
        Step.IsInterface := ViaInterface[ sNode ];
        Chain.Insert( 0, Step );
        sNode := Parent[ sNode ];
      end;
      Step.UnitName    := FUnits[ AStart ].UnitName;
      Step.IsInterface := False;
      Chain.Insert( 0, Step );
      Step.UnitName    := FUnits[ AStart ].UnitName;
      Step.IsInterface := ViaInterface[ #0 ];
      Chain.Add( Step );
      Result := Chain.ToArray;
    finally
      Chain.Free;
      ViaInterface.Free;
      Parent.Free;
      Queue.Free;
    end;
  end;

begin

  FCircularRefs.Clear;

  { One entry per strongly-connected group, found by the same iterative Tarjan the Decirculariser
    uses: a group of n units can hold a factorial number of cycles, and walking from every unit
    reported each cycle once per member. }
  Adjacency := TObjectDictionary<string, TStringList>.Create( [ doOwnsValues ] );
  try
    for var Pair in FUnits do
    begin
      Members            := TStringList.Create;
      Members.Sorted     := True;
      Members.Duplicates := dupIgnore;
      for var Dep in Pair.Value.Dependencies do
        if FUnits.ContainsKey( LowerCase( Dep.UnitName ) ) then
          Members.Add( LowerCase( Dep.UnitName ) );
      Adjacency.Add( Pair.Key, Members );
    end;

    Nodes := FUnits.Keys.ToArray;
    TArray.Sort<string>( Nodes );
    for var Group in FindStronglyConnectedGroups( Nodes, Adjacency ) do
    begin
      var GroupList := TStringList.Create;
      try
        GroupList.Sorted := True;
        GroupList.AddStrings( Group );
        Ref.Steps := ShortestCycle( Group[ 0 ], GroupList );
        SetLength( Ref.Members, Length( Group ) );
        for var I := 0 to High( Group ) do
          Ref.Members[ I ] := FUnits[ Group[ I ] ].UnitName;
        TArray.Sort<string>( Ref.Members, TIStringComparer.Ordinal );
      finally
        GroupList.Free;
      end;
      FCircularRefs.Add( Ref );
    end;
  finally
    Adjacency.Free;
  end;

end;

constructor TLayerConfig.Create( const AConfigFile: string );
begin

  inherited Create;
  FConfigFile  := AConfigFile;
  FLayers      := TList<TLayerDefinition>.Create;
  { Layer names are matched without regard to case everywhere else, so the rules are too: a
    hand-edited "ui=Core" line belongs to layer UI. }
  FAllowedDeps := TDictionary<string, TStringList>.Create( TIStringComparer.Ordinal );

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

procedure TLayerConfig.ClearLayers;
begin

  FLayers.Clear;

end;

procedure TLayerConfig.RemoveRules( const LayerName: string );
var
  SL: TStringList;
begin

  if FAllowedDeps.TryGetValue( LayerName, SL ) then
  begin
    FAllowedDeps.Remove( LayerName );
    SL.Free;
  end;

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

function TLayerConfig.HasRules( const LayerName: string ): Boolean;
begin

  Result := FAllowedDeps.ContainsKey( LayerName );

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
  SL: TStringList;
begin

  if not FileExists( FConfigFile ) then
  begin
    LoadDefaults;
    Exit;
  end;

  SL := TStringList.Create;
  try
    SL.LoadFromFile( FConfigFile );
    LoadFromStrings( SL );
  finally
    SL.Free;
  end;

end;

procedure TLayerConfig.LoadFromStrings( SL: TStrings );
var
  Lines: TStringList;
  I, J: Integer;
  Line, LayerName, PatternStr, AllowedStr: string;
  Patterns, Allowed: TArray<string>;
  InLayers, InRules: Boolean;
begin

  Clear;
  Lines    := TStringList.Create;
  InLayers := False;
  InRules  := False;

  try
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
  end;

end;

procedure TLayerConfig.SaveToFile;
var
  SL: TStringList;
begin

  SL := TStringList.Create;
  try
    SaveToStrings( SL );
    { UTF-8, and written beside the file then swapped in, so a failed write ( full disk, locked
      folder ) leaves the previous configuration intact instead of a truncated one. }
    var sTemp := FConfigFile + '.tmp';
    SL.SaveToFile( sTemp, TEncoding.UTF8 );
    if ( not MoveFileEx( PChar( sTemp ), PChar( FConfigFile ), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH ) ) then
    begin
      var iError := Winapi.Windows.GetLastError;
      System.SysUtils.DeleteFile( sTemp );
      raise EFCreateError.CreateFmt( 'Could not save %s: %s', [ FConfigFile, SysErrorMessage( iError ) ] );
    end;
  finally
    SL.Free;
  end;

end;

procedure TLayerConfig.SaveToStrings( SL: TStrings );
var
  Layer: TLayerDefinition;
  I: Integer;
  Line: string;
  Pair: TPair<string, TStringList>;
begin

  SL.Clear;
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

function PredefinedSymbols( const APlatform: string ): TArray<string>;
begin
  { What every Delphi compiler for Windows defines by itself, plus this compiler's VERnnn
    ( CompilerVersion 37.0 gives VER370 ). }
  Result := [ 'MSWINDOWS', 'UNICODE', 'CONDITIONALEXPRESSIONS', 'NATIVECODE', 'ASSEMBLER',
    Format( 'VER%d', [ Round( CompilerVersion * 10 ) ] ) ];
  if SameText( APlatform, 'Win64' ) then
    Result := Result + [ 'WIN64', 'CPUX64', 'CPU64BITS' ]
  else
    Result := Result + [ 'WIN32', 'CPUX86', 'CPU386', 'CPU32BITS' ];
end;

function LayerRulesMatrix( AConfig: TLayerConfig; const ALayerNames: TArray<string> ): TArray<TArray<Boolean>>;
begin
  SetLength( Result, Length( ALayerNames ), Length( ALayerNames ) );
  for var I := 0 to High( ALayerNames ) do
  begin
    { A layer with no rule line may use every layer: show that as every box ticked, so that OK
      on an untouched dialog keeps the meaning instead of turning it into "none allowed". }
    if ( not AConfig.HasRules( ALayerNames[ I ] ) ) then
    begin
      for var J := 0 to High( ALayerNames ) do
        Result[ I ][ J ] := ( I <> J );
      Continue;
    end;
    for var sAllowed in AConfig.GetAllowedDependencies( ALayerNames[ I ] ) do
      for var J := 0 to High( ALayerNames ) do
        if SameText( ALayerNames[ J ], sAllowed ) then
          Result[ I ][ J ] := True;
  end;
end;

procedure ApplyLayerRulesMatrix( AConfig: TLayerConfig; const ALayerNames: TArray<string>;
  const AMatrix: TArray<TArray<Boolean>> );
begin
  for var I := 0 to High( ALayerNames ) do
  begin
    var Allowed: TArray<string> := nil;
    var bAll := True;
    for var J := 0 to High( ALayerNames ) do
      if ( I <> J ) then
      begin
        if AMatrix[ I ][ J ] then
          Allowed := Allowed + [ ALayerNames[ J ] ]
        else
          bAll := False;
      end;
    { Every box ticked means "may use every layer": stored as no rule line, which keeps meaning
      that for layers added later, rather than freezing today's list. }
    if bAll then
      AConfig.RemoveRules( ALayerNames[ I ] )
    else
      AConfig.SetAllowedDependencies( ALayerNames[ I ], Allowed );
  end;
end;

end.
