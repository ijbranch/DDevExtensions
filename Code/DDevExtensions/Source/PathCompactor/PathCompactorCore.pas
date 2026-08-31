{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit PathCompactorCore;

/// <summary>
/// Pure analysis core for the IDE Path Compactor: expands and normalises the
/// entries of the IDE's per-platform library path values, proposes
/// <c>$(NAME)</c> macro substitutions for repeated directory prefixes, and
/// reports duplicate, missing and undefined-macro entries.
/// </summary>
/// <remarks>
/// RTL-only by design — no ToolsAPI, no VCL and no registry access — so the
/// interesting logic is unit-testable by a standalone console executable, in
/// the same way as <c>ProjectGroupSorterCore</c>. The caller supplies the macro
/// table (see <see cref="TPathCompactorAnalysis.SetMacros"/>), which is what
/// keeps this unit free of the IDE.
///
/// The single most important rule in here is that saving is measured in
/// <b>stored</b> space, never expanded space. Candidates must be generated from
/// expanded ancestors so that a prefix can be matched across entries written in
/// different forms, but an entry already stored as <c>$(BDS)\...</c> has a
/// stored prefix only a few characters long, and re-expressing it under a new
/// variable would make it longer. Scoring in expanded space silently inverts
/// the feature.
/// </remarks>

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  /// <summary>Identifies which Library-key value name a path operation targets.</summary>
  TLibraryPathType = (
    /// <summary>"Search Path" registry value (the Library Path).</summary>
    lptSearchPath,
    /// <summary>"Browsing Path" registry value.</summary>
    lptBrowsingPath,
    /// <summary>"Debug DCU Path" registry value.</summary>
    lptDebugDCUPath,
    /// <summary>"HPP Output Directory" registry value.</summary>
    lptHPPOutputDirectory,
    /// <summary>"Namespace Prefixes" registry value.</summary>
    lptNamespacePrefixes,
    /// <summary>"Package DCP Output" registry value.</summary>
    lptPackageDCPOutput,
    /// <summary>"Package DPL Output" registry value.</summary>
    lptPackageDPLOutput,
    /// <summary>"Translated Debug Library Path" registry value.</summary>
    lptTranslatedDebugLibraryPath,
    /// <summary>"Translated Library Path" registry value.</summary>
    lptTranslatedLibraryPath,
    /// <summary>"Translated Resource Path" registry value.</summary>
    lptTranslatedResourcePath
  );

  /// <summary>Helper that exposes the registry value name and display name of a path-type value.</summary>
  TLibraryPathTypeHelper = record helper for TLibraryPathType
    /// <summary>Returns the registry value name corresponding to the path type.</summary>
    function ToRegistryValueName: string;
    /// <summary>Returns a user-facing display name for the path type.</summary>
    function ToDisplayName: string;
  end;

  /// <summary>Raised when the compactor is asked to do something it must refuse.</summary>
  EPathCompactorError = class( Exception );

  /// <summary>Links one path entry to a candidate prefix it matches.</summary>
  TEntryMatch = record
    /// <summary>Index into the analysis's candidate array.</summary>
    CandidateIndex: Integer;
    /// <summary>Length of the RAW text in this entry that the candidate prefix replaces.</summary>
    StoredPrefixLen: Integer;
    /// <summary>Length of the candidate's expanded prefix (used for longest-prefix-wins).</summary>
    ExpandedPrefixLen: Integer;
  end;

  /// <summary>One entry from a semicolon-separated path value, with its analysis state.</summary>
  TPathEntry = record
    /// <summary>Exactly as stored in the registry, macros intact.</summary>
    Raw: string;
    /// <summary>Fully expanded and normalised: absolute, no trailing separator.</summary>
    Expanded: string;
    /// <summary>Contains a build-time macro; never rewritten, never deduplicated.</summary>
    Opaque: Boolean;
    /// <summary>Directory present on disc. False also when existence cannot be determined.</summary>
    Exists: Boolean;
    /// <summary>An earlier entry in the same set expands to the same path.</summary>
    Duplicate: Boolean;
    /// <summary>References a macro that resolves nowhere at all — not deferred, simply dead.</summary>
    UndefinedMacro: Boolean;
    /// <summary>
    /// References a macro this IDE cannot resolve but the other IDE bitness can.
    /// Reported, never removed: the entry is live in the other IDE, so the fix
    /// is to define the variable in both lists, not to delete the entry.
    /// </summary>
    DivergentMacro: Boolean;
    /// <summary>Proposed replacement for Raw; empty means unchanged.</summary>
    NewRaw: string;
    /// <summary>Proposed for removal (duplicate or missing).</summary>
    Drop: Boolean;
    /// <summary>Candidate prefixes this entry matches, with their stored-space cost.</summary>
    Matches: TArray<TEntryMatch>;
  end;

  /// <summary>A candidate directory prefix that could be replaced by a $(NAME) macro.</summary>
  TVarCandidate = record
    /// <summary>Variable name without the surrounding <c>$(</c> and <c>)</c>.</summary>
    Name: string;
    /// <summary>Expanded prefix, no trailing separator.</summary>
    Prefix: string;
    /// <summary>Number of entries whose expanded path starts with Prefix at a segment boundary.</summary>
    Occurrences: Integer;
    /// <summary>Characters removed from STORED length across the whole scope if accepted.</summary>
    NetSaving: Integer;
    /// <summary>Selected for use by <see cref="TPathCompactorAnalysis.Analyse"/>.</summary>
    Accepted: Boolean;
    /// <summary>An IDE variable or built-in of this name already holds exactly this value.</summary>
    PreExisting: Boolean;
  end;

  /// <summary>One platform/path-type registry value and its parsed entries.</summary>
  TPathSet = class( TObject )
  private
    /// <summary>Platform name the value belongs to (e.g. "Win64").</summary>
    FPlatformName: string;
    /// <summary>Path type the value belongs to.</summary>
    FPathType: TLibraryPathType;
    /// <summary>The value exactly as read from the registry.</summary>
    FOriginal: string;
    /// <summary>Parsed entries, in registry order.</summary>
    FEntries: TArray<TPathEntry>;
  public
    /// <summary>Creates the set and splits AValue on semicolons, discarding empty entries.</summary>
    constructor Create( const APlatformName: string; APathType: TLibraryPathType;
      const AValue: string );

    /// <summary>Rebuilds the semicolon-separated value from the entries, honouring NewRaw and Drop.</summary>
    /// <remarks>Joins with a plain <c>;</c> and never quotes — Delphi's native format uses no quotes.</remarks>
    function BuildResult: string;
    /// <summary>Number of entries that survive into <see cref="BuildResult"/>.</summary>
    function KeptCount: Integer;
    /// <summary>Stored length of the value as it currently stands in the registry.</summary>
    function OriginalLength: Integer;
    /// <summary>Stored length of the value <see cref="BuildResult"/> would produce.</summary>
    function ResultLength: Integer;

    /// <summary>Platform name the value belongs to.</summary>
    property PlatformName: string read FPlatformName;
    /// <summary>Path type the value belongs to.</summary>
    property PathType: TLibraryPathType read FPathType;
    /// <summary>The value exactly as read from the registry.</summary>
    property Original: string read FOriginal;
    /// <summary>Parsed entries, in registry order.</summary>
    property Entries: TArray<TPathEntry> read FEntries write FEntries;
  end;

  /// <summary>
  /// Analyses a collection of path sets, proposes macro variables and rewrites
  /// the entries. Nothing here touches the registry — the caller reads the
  /// values in, and writes <see cref="TPathSet.BuildResult"/> back out.
  /// </summary>
  TPathCompactorAnalysis = class( TObject )
  private
    /// <summary>Owned path sets in the analysis scope.</summary>
    FSets: TObjectList<TPathSet>;
    /// <summary>Macro table (Name=Value), highest precedence first. Never modified.</summary>
    FMacros: TStringList;
    /// <summary>Names that must never be redefined (IDE built-ins and process environment).</summary>
    FReservedNames: TStringList;
    /// <summary>Candidate prefixes discovered by <see cref="GenerateCandidates"/>.</summary>
    FCandidates: TArray<TVarCandidate>;
    /// <summary>Indices into FCandidates, in acceptance order.</summary>
    FAccepted: TArray<Integer>;
    /// <summary>Maximum number of variables to propose.</summary>
    FMaxVariables: Integer;
    /// <summary>Minimum occurrences before a prefix is considered at all.</summary>
    FMinOccurrences: Integer;
    /// <summary>Minimum stored-space saving before a candidate is accepted.</summary>
    FMinNetSaving: Integer;
    /// <summary>When False, <c>$(Platform)</c> entries are treated as opaque.</summary>
    FBakePlatformMacro: Boolean;
    /// <summary>When True, duplicate entries are marked for removal.</summary>
    FRemoveDuplicates: Boolean;
    /// <summary>When True, entries whose directory is absent are marked for removal.</summary>
    FRemoveMissing: Boolean;
    /// <summary>When True, entries referencing a macro that resolves nowhere are marked for removal.</summary>
    FRemoveUndefinedMacros: Boolean;
    /// <summary>Macro names this IDE cannot resolve but the other IDE bitness can.</summary>
    FDivergentNames: TStringList;
    /// <summary>When False, existence is not probed (used by tests, which have no disc layout).</summary>
    FCheckExistence: Boolean;

    /// <summary>Expands, normalises and classifies every entry in every set.</summary>
    procedure ExpandEntries;
    /// <summary>Flags entries whose expanded path repeats earlier in the SAME set.</summary>
    procedure DetectDuplicates;
    /// <summary>Tallies ancestor prefixes across the scope and builds the candidate array.</summary>
    procedure GenerateCandidates;
    /// <summary>Greedily accepts candidates by incremental stored-space saving.</summary>
    procedure SelectVariables;
    /// <summary>Applies the accepted variables, longest expanded prefix first.</summary>
    procedure RewriteEntries;
    /// <summary>Marks entries for removal according to the RemoveDuplicates/RemoveMissing flags.</summary>
    procedure ApplyHygiene;

    /// <summary>Stored length of AEntry's raw text once AAcceptedSet has been applied.</summary>
    function StoredLengthUnder( const AEntry: TPathEntry;
      const AAcceptedSet: TArray<Integer> ): Integer;
    /// <summary>Total stored-space characters saved across the scope by additionally accepting ACandidate.</summary>
    function IncrementalSaving( ACandidateIndex: Integer ): Integer;
    /// <summary>Returns the length of the raw prefix of AEntry.Raw that expands to APrefix, or 0.</summary>
    function StoredPrefixLengthFor( const AEntry: TPathEntry; const APrefix: string ): Integer;
    /// <summary>Chooses a unique, legal variable name for APrefix.</summary>
    function UniqueVariableName( const APrefix: string ): string;
    /// <summary>Returns the name of an existing macro whose value equals APrefix, or an empty string.</summary>
    function ExistingMacroFor( const APrefix: string ): string;
  public
    /// <summary>Creates an empty analysis with the documented defaults.</summary>
    constructor Create;
    /// <summary>Frees the owned path sets and string lists.</summary>
    destructor Destroy; override;

    /// <summary>Replaces the macro table. The supplied list is copied, never retained or modified.</summary>
    procedure SetMacros( AMacros: TStrings );
    /// <summary>Replaces the reserved-name list (IDE built-ins plus the process environment).</summary>
    procedure SetReservedNames( ANames: TStrings );
    /// <summary>
    /// Supplies the macro names the OTHER IDE bitness defines but this one does
    /// not. An entry using one of these is flagged <c>DivergentMacro</c> rather
    /// than <c>UndefinedMacro</c>, and is never removed by cleanup — it still
    /// resolves in the other IDE, so deleting it would break that IDE.
    /// </summary>
    procedure SetDivergentNames( ANames: TStrings );
    /// <summary>Adds one platform/path-type value to the analysis scope.</summary>
    /// <exception cref="EPathCompactorError">
    /// Raised for <c>lptNamespacePrefixes</c>, which is a list of unit-scope
    /// prefixes rather than directories; compacting it would corrupt it.
    /// </exception>
    procedure AddPathSet( const APlatformName: string; APathType: TLibraryPathType;
      const AValue: string );

    /// <summary>Runs the full analysis: expand, detect, generate, select, rewrite, hygiene.</summary>
    procedure Analyse;

    /// <summary>Returns the accepted candidates, in acceptance order.</summary>
    function AcceptedVariables: TArray<TVarCandidate>;
    /// <summary>Total stored characters across every set before rewriting.</summary>
    function TotalStoredBefore: Integer;
    /// <summary>Total stored characters across every set after rewriting.</summary>
    function TotalStoredAfter: Integer;
    /// <summary>Number of entries flagged as duplicates across the whole scope.</summary>
    function DuplicateCount: Integer;
    /// <summary>Number of entries whose directory is absent across the whole scope.</summary>
    function MissingCount: Integer;
    /// <summary>Number of entries referencing a macro that resolves nowhere.</summary>
    function UndefinedMacroCount: Integer;
    /// <summary>Number of entries whose macro resolves only in the other IDE bitness.</summary>
    function DivergentMacroCount: Integer;
    /// <summary>Number of entries currently marked for removal.</summary>
    function DropCount: Integer;
    /// <summary>Returns a description of every entry currently marked for removal.</summary>
    function DropSummary: TArray<string>;

    /// <summary>
    /// Re-tests every entry marked for removal and clears the mark on any that
    /// now passes. Call immediately before writing: a directory can appear
    /// between Analyse and Apply — a share reconnects, an install finishes —
    /// and nothing should be deleted on the strength of a stale probe.
    /// </summary>
    /// <returns>The number of entries rescued (previously marked, now kept).</returns>
    function RevalidateDrops: Integer;

    /// <summary>Owned path sets in the analysis scope.</summary>
    property Sets: TObjectList<TPathSet> read FSets;
    /// <summary>Every candidate considered, whether accepted or not.</summary>
    property Candidates: TArray<TVarCandidate> read FCandidates;

    /// <summary>Maximum number of variables to propose. Default 12.</summary>
    property MaxVariables: Integer read FMaxVariables write FMaxVariables;
    /// <summary>Minimum occurrences before a prefix is considered. Default 2.</summary>
    property MinOccurrences: Integer read FMinOccurrences write FMinOccurrences;
    /// <summary>Minimum stored-space saving before acceptance. Default 40.</summary>
    property MinNetSaving: Integer read FMinNetSaving write FMinNetSaving;
    /// <summary>When False (the default), <c>$(Platform)</c> entries are opaque.</summary>
    property BakePlatformMacro: Boolean read FBakePlatformMacro write FBakePlatformMacro;
    /// <summary>Remove duplicate entries. Default False — detection is always on, removal is opt-in.</summary>
    property RemoveDuplicates: Boolean read FRemoveDuplicates write FRemoveDuplicates;
    /// <summary>Remove entries whose directory is absent. Default False.</summary>
    property RemoveMissing: Boolean read FRemoveMissing write FRemoveMissing;
    /// <summary>
    /// Remove entries referencing a macro that resolves nowhere. Default False.
    /// Never removes a <c>DivergentMacro</c> entry, which is live in the other IDE.
    /// </summary>
    property RemoveUndefinedMacros: Boolean read FRemoveUndefinedMacros
      write FRemoveUndefinedMacros;
    /// <summary>Probe the file system for entry existence. Default True; tests set False.</summary>
    property CheckExistence: Boolean read FCheckExistence write FCheckExistence;
  end;

/// <summary>
/// Expands <c>$(NAME)</c> macros in APath using AMacros (Name=Value,
/// case-insensitive). An unknown macro is left intact and terminates the pass —
/// deliberately unlike <c>IDEUtils.ExpandDirMacros</c>, which deletes it.
/// Cycles are broken by AMaxDepth.
/// </summary>
function ExpandLibraryMacros( const APath: string; AMacros: TStrings;
  AMaxDepth: Integer = 16 ): string;

/// <summary>Returns APath absolute, with <c>..</c> resolved and any trailing separator removed.</summary>
/// <remarks>A bare drive root such as <c>D:\</c> keeps its separator.</remarks>
function NormalisePath( const APath: string ): string;

/// <summary>True when APath equals APrefix or continues it at a directory-separator boundary.</summary>
function StartsWithSegment( const APath, APrefix: string ): Boolean;

/// <summary>True when ASegment is a platform name or a build configuration name.</summary>
function IsPlatformOrConfigToken( const ASegment: string ): Boolean;

/// <summary>
/// True when ASegment is nothing but digits and separators — a version folder
/// such as <c>37.0</c>, <c>13</c> or <c>8.0.2</c>. Such a segment names nothing
/// on its own and must not become a variable name.
/// </summary>
function IsVersionLikeSegment( const ASegment: string ): Boolean;

/// <summary>
/// Derives a candidate variable name from APrefix's trailing segment, widening
/// to earlier segments while the trailing one is a platform token, a config
/// token or a bare version number — so <c>...\Dcp\Win32</c> yields
/// <c>DCP_WIN32</c> rather than <c>WIN32</c>, and <c>...\Florence\37.0</c>
/// does not yield <c>V37_0</c>.
/// </summary>
/// <param name="AExtraSegments">
/// Additional parent segments to fold in beyond the automatic widening. Used to
/// resolve a collision with a meaningful name rather than a <c>_2</c> suffix.
/// </param>
/// <param name="AMaxLength">Longest name to emit; widened names are allowed to run longer.</param>
function DeriveVariableName( const APrefix: string; AExtraSegments: Integer = 0;
  AMaxLength: Integer = 0 ): string;

/// <summary>Splits a semicolon-separated path value, trimming entries and discarding empty ones.</summary>
procedure SplitPathValue( AList: TStrings; const AValue: string );

/// <summary>
/// Returns the name of the first <c>$(NAME)</c> still present in APath, or an
/// empty string when none remains.
/// </summary>
function FirstMacroName( const APath: string ): string;

implementation

uses
  System.IOUtils, System.StrUtils;

const
  /// <summary>Registry value names, indexed by TLibraryPathType.</summary>
  PathTypeRegistryNames: array[TLibraryPathType] of string = (
    'Search Path',
    'Browsing Path',
    'Debug DCU Path',
    'HPP Output Directory',
    'Namespace Prefixes',
    'Package DCP Output',
    'Package DPL Output',
    'Translated Debug Library Path',
    'Translated Library Path',
    'Translated Resource Path'
  );

  /// <summary>User-facing display names, indexed by TLibraryPathType.</summary>
  PathTypeDisplayNames: array[TLibraryPathType] of string = (
    'Library Path',
    'Browsing Path',
    'Debug DCU Path',
    'HPP Output Directory',
    'Namespace Prefixes',
    'Package DCP Output',
    'Package DPL Output',
    'Translated Debug Library Path',
    'Translated Library Path',
    'Translated Resource Path'
  );

  /// <summary>Platform names that must never become a variable name on their own.</summary>
  PlatformTokens: array[0..12] of string = (
    'Win32', 'Win64', 'Win64x', 'WinArm64EC', 'Android32', 'Android64',
    'iOSDevice32', 'iOSDevice64', 'iOSSimARM64', 'iOSSimulator',
    'Linux64', 'OSX64', 'OSXARM64'
  );

  /// <summary>Build configuration names that must never become a variable name on their own.</summary>
  ConfigTokens: array[0..1] of string = ( 'Debug', 'Release' );

  /// <summary>Shortest prefix worth replacing with a macro.</summary>
  MinPrefixLength = 8;

  /// <summary>Longest generated variable name.</summary>
  MaxVariableNameLength = 16;

  /// <summary>Longest name allowed once segments have been folded in to break a collision.</summary>
  MaxWidenedNameLength = 28;

  /// <summary>How many parent segments may be folded in before falling back to a numeric suffix.</summary>
  MaxWidenSteps = 3;

{ TLibraryPathTypeHelper }

function TLibraryPathTypeHelper.ToRegistryValueName: string;
begin
  Result := PathTypeRegistryNames[Self];
end;

function TLibraryPathTypeHelper.ToDisplayName: string;
begin
  Result := PathTypeDisplayNames[Self];
end;

{ Unit-level helpers }

function ExpandLibraryMacros( const APath: string; AMacros: TStrings;
  AMaxDepth: Integer ): string;
var
  Depth, Start, Stop, Index: Integer;
  MacroName: string;
begin
  Result := APath;
  if AMacros = nil then
    Exit;

  for Depth := 1 to AMaxDepth do
  begin
    Start := Pos( '$(', Result );
    if Start = 0 then
      Exit;

    Stop := Pos( ')', Result, Start + 2 );
    if Stop = 0 then
      Exit;

    MacroName := Copy( Result, Start + 2, Stop - Start - 2 );
    Index := AMacros.IndexOfName( MacroName );
    if Index < 0 then
      Exit; // Unknown macro: leave it intact and stop, so the caller can see it.

    Result := Copy( Result, 1, Start - 1 ) + AMacros.ValueFromIndex[Index] +
      Copy( Result, Stop + 1, MaxInt );
  end;
end;

function NormalisePath( const APath: string ): string;
begin
  Result := Trim( APath );
  if Result = '' then
    Exit;

  // A path still carrying a macro cannot be made absolute; leave it alone.
  if Pos( '$(', Result ) > 0 then
    Exit;

  try
    Result := TPath.GetFullPath( Result );
  except
    // Malformed paths are left as they were rather than aborting the analysis.
  end;

  // Strip a trailing separator, but never from a bare drive root such as "D:\".
  if ( Length( Result ) > 3 ) and ( Result[Length( Result )] = PathDelim ) then
    SetLength( Result, Length( Result ) - 1 );
end;

function StartsWithSegment( const APath, APrefix: string ): Boolean;
begin
  Result := False;
  if ( APrefix = '' ) or ( Length( APath ) < Length( APrefix ) ) then
    Exit;

  if not SameText( Copy( APath, 1, Length( APrefix ) ), APrefix ) then
    Exit;

  Result := ( Length( APath ) = Length( APrefix ) ) or
            ( APath[Length( APrefix ) + 1] = PathDelim );
end;

function IsPlatformOrConfigToken( const ASegment: string ): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := Low( PlatformTokens ) to High( PlatformTokens ) do
    if SameText( ASegment, PlatformTokens[I] ) then
      Exit;
  for I := Low( ConfigTokens ) to High( ConfigTokens ) do
    if SameText( ASegment, ConfigTokens[I] ) then
      Exit;
  Result := False;
end;

function IsVersionLikeSegment( const ASegment: string ): Boolean;
var
  I: Integer;
  HasDigit: Boolean;
begin
  Result := False;
  HasDigit := False;
  if ASegment = '' then
    Exit;

  for I := 1 to Length( ASegment ) do
  begin
    if CharInSet( ASegment[I], ['0'..'9'] ) then
      HasDigit := True
    else if not CharInSet( ASegment[I], ['.', '-', '_', ' '] ) then
      Exit;
  end;

  Result := HasDigit;
end;

function DeriveVariableName( const APrefix: string; AExtraSegments: Integer;
  AMaxLength: Integer ): string;
var
  Segments: TArray<string>;
  Last, First, I, J, Limit: Integer;
  Raw: string;
  Ch: Char;
begin
  Segments := APrefix.Split( [PathDelim] );

  Last := High( Segments );
  while ( Last > 0 ) and ( Segments[Last] = '' ) do
    Dec( Last );
  if Last < 0 then
    Exit( 'PATH' );

  // Widen while the trailing segment names nothing on its own: a platform or
  // config token ("...\Dcp\Win32" -> DCP_WIN32, not WIN32) or a bare version
  // folder ("...\Florence\37.0" -> FLORENCE_37_0, not V37_0).
  First := Last;
  while ( First > 0 ) and
        ( IsPlatformOrConfigToken( Segments[First] ) or
          IsVersionLikeSegment( Segments[First] ) ) do
    Dec( First );

  // Fold in further parents on request, to break a collision with a name that
  // actually distinguishes the two paths instead of a bare _2. Skip over
  // version and token segments while doing so: folding in "37.0" to break a
  // clash on "source" gives V37_0_SOURCE, which is no more meaningful than the
  // suffix it replaced. Reach past it to the segment that actually names
  // something.
  for I := 1 to AExtraSegments do
  begin
    if First <= 1 then
      Break;
    Dec( First );
    while ( First > 1 ) and
          ( IsPlatformOrConfigToken( Segments[First] ) or
            IsVersionLikeSegment( Segments[First] ) ) do
      Dec( First );
  end;

  Raw := '';
  for I := First to Last do
  begin
    if Raw <> '' then
      Raw := Raw + '_';
    Raw := Raw + Segments[I];
  end;

  Result := '';
  for J := 1 to Length( Raw ) do
  begin
    Ch := Raw[J];
    if CharInSet( Ch, ['A'..'Z', 'a'..'z', '0'..'9'] ) then
      Result := Result + UpCase( Ch )
    else
      Result := Result + '_';
  end;

  // A name must start with a letter to be a legal macro identifier.
  if ( Result = '' ) or not CharInSet( Result[1], ['A'..'Z'] ) then
    Result := 'V' + Result;

  Limit := AMaxLength;
  if Limit <= 0 then
    if AExtraSegments > 0 then
      Limit := MaxWidenedNameLength
    else
      Limit := MaxVariableNameLength;

  if Length( Result ) > Limit then
    SetLength( Result, Limit );

  // Never end on a separator left behind by truncation.
  while ( Result <> '' ) and ( Result[Length( Result )] = '_' ) do
    SetLength( Result, Length( Result ) - 1 );
end;

procedure SplitPathValue( AList: TStrings; const AValue: string );
var
  Parts: TArray<string>;
  I: Integer;
  Item: string;
begin
  AList.Clear;
  Parts := AValue.Split( [';'] );
  for I := Low( Parts ) to High( Parts ) do
  begin
    // The IDE stores paths unquoted, but tolerate quotes on the read side.
    Item := Trim( Parts[I] ).DeQuotedString( '"' );
    Item := Trim( Item );
    if Item <> '' then
      AList.Add( Item );
  end;
end;

function FirstMacroName( const APath: string ): string;
var
  Start, Stop: Integer;
begin
  Result := '';
  Start := Pos( '$(', APath );
  if Start = 0 then
    Exit;
  Stop := Pos( ')', APath, Start + 2 );
  if Stop = 0 then
    Exit;
  Result := Copy( APath, Start + 2, Stop - Start - 2 );
end;

{ TPathSet }

constructor TPathSet.Create( const APlatformName: string; APathType: TLibraryPathType;
  const AValue: string );
var
  List: TStringList;
  I: Integer;
begin
  inherited Create;
  FPlatformName := APlatformName;
  FPathType := APathType;
  FOriginal := AValue;

  List := TStringList.Create;
  try
    SplitPathValue( List, AValue );
    SetLength( FEntries, List.Count );
    for I := 0 to List.Count - 1 do
      FEntries[I].Raw := List[I];
  finally
    List.Free;
  end;
end;

function TPathSet.BuildResult: string;
var
  I, Expected: Integer;
  Item: string;
  Count: Integer;
begin
  Result := '';
  Count := 0;
  for I := Low( FEntries ) to High( FEntries ) do
  begin
    if FEntries[I].Drop then
      Continue;

    if FEntries[I].NewRaw <> '' then
      Item := FEntries[I].NewRaw
    else
      Item := FEntries[I].Raw;

    if Result = '' then
      Result := Item
    else
      Result := Result + ';' + Item;
    Inc( Count );
  end;

  // Losing a library path silently is the worst failure this feature has, so
  // verify the count the way TLibraryPathHandler.SortPaths does.
  Expected := KeptCount;
  if Count <> Expected then
    raise EPathCompactorError.CreateFmt(
      'Path count mismatch while rebuilding %s / %s: expected %d, produced %d',
      [FPlatformName, FPathType.ToDisplayName, Expected, Count] );
end;

function TPathSet.KeptCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := Low( FEntries ) to High( FEntries ) do
    if not FEntries[I].Drop then
      Inc( Result );
end;

function TPathSet.OriginalLength: Integer;
begin
  Result := Length( FOriginal );
end;

function TPathSet.ResultLength: Integer;
begin
  Result := Length( BuildResult );
end;

{ TPathCompactorAnalysis }

constructor TPathCompactorAnalysis.Create;
begin
  inherited Create;
  FSets := TObjectList<TPathSet>.Create( True );

  FMacros := TStringList.Create;
  FMacros.CaseSensitive := False;
  FMacros.NameValueSeparator := '=';

  FReservedNames := TStringList.Create;
  FReservedNames.CaseSensitive := False;
  FReservedNames.Duplicates := dupIgnore;
  FReservedNames.Sorted := True;

  FDivergentNames := TStringList.Create;
  FDivergentNames.CaseSensitive := False;
  FDivergentNames.Duplicates := dupIgnore;
  FDivergentNames.Sorted := True;

  FMaxVariables := 12;
  FMinOccurrences := 2;
  FMinNetSaving := 40;
  FBakePlatformMacro := False;
  FRemoveDuplicates := False;
  FRemoveMissing := False;
  FRemoveUndefinedMacros := False;
  FCheckExistence := True;
end;

destructor TPathCompactorAnalysis.Destroy;
begin
  FDivergentNames.Free;
  FReservedNames.Free;
  FMacros.Free;
  FSets.Free;
  inherited Destroy;
end;

procedure TPathCompactorAnalysis.SetMacros( AMacros: TStrings );
begin
  FMacros.Clear;
  if AMacros <> nil then
    FMacros.Assign( AMacros );
  FMacros.CaseSensitive := False;
  FMacros.NameValueSeparator := '=';
end;

procedure TPathCompactorAnalysis.SetReservedNames( ANames: TStrings );
var
  I: Integer;
begin
  FReservedNames.Clear;
  if ANames = nil then
    Exit;
  for I := 0 to ANames.Count - 1 do
    if Trim( ANames[I] ) <> '' then
      FReservedNames.Add( Trim( ANames[I] ) );
end;

procedure TPathCompactorAnalysis.SetDivergentNames( ANames: TStrings );
var
  I: Integer;
begin
  FDivergentNames.Clear;
  if ANames = nil then
    Exit;
  for I := 0 to ANames.Count - 1 do
    if Trim( ANames[I] ) <> '' then
      FDivergentNames.Add( Trim( ANames[I] ) );
end;

procedure TPathCompactorAnalysis.AddPathSet( const APlatformName: string;
  APathType: TLibraryPathType; const AValue: string );
begin
  // Enforced here rather than only in the dialog: the dialog is not the only
  // caller, and a stale or hand-edited configuration must not reach the
  // compactor with a value that is a unit-scope prefix list, not directories.
  if APathType = lptNamespacePrefixes then
    raise EPathCompactorError.Create(
      'Namespace Prefixes is a list of unit-scope prefixes, not directories, ' +
      'and must never be compacted.' );

  FSets.Add( TPathSet.Create( APlatformName, APathType, AValue ) );
end;

procedure TPathCompactorAnalysis.ExpandEntries;
var
  SetIndex, I: Integer;
  PathSet: TPathSet;
  Entries: TArray<TPathEntry>;
  Expanded: string;
begin
  for SetIndex := 0 to FSets.Count - 1 do
  begin
    PathSet := FSets[SetIndex];
    Entries := PathSet.Entries;

    for I := Low( Entries ) to High( Entries ) do
    begin
      // $(Config) and $(LangDir) are always deferred to build time; $(Platform)
      // is too unless the caller has explicitly asked for it to be baked.
      // $(LangDir) is resolved per translation language and appears only in the
      // three Translated* path types — it is genuinely deferred, not undefined,
      // and must not be reported as a dead macro reference.
      Entries[I].Opaque :=
        ContainsText( Entries[I].Raw, '$(Config)' ) or
        ContainsText( Entries[I].Raw, '$(LangDir)' ) or
        ( not FBakePlatformMacro and ContainsText( Entries[I].Raw, '$(Platform)' ) );

      Expanded := ExpandLibraryMacros( Entries[I].Raw, FMacros );

      // A macro that resolves nowhere is not "deferred", it simply does not
      // exist — but it still cannot be rewritten, so it is opaque as well. The
      // build-time macros handled above are already opaque and are deliberately
      // never counted here, or every Translated* entry would be a false report.
      Entries[I].UndefinedMacro := False;
      Entries[I].DivergentMacro := False;

      if ( Pos( '$(', Expanded ) > 0 ) and not Entries[I].Opaque then
      begin
        // Distinguish dead from merely divergent: a macro the OTHER IDE bitness
        // defines still resolves there, so the entry is live and must never be
        // removed — the fix for it is to define the variable in both lists.
        if FDivergentNames.IndexOf( FirstMacroName( Expanded ) ) >= 0 then
          Entries[I].DivergentMacro := True
        else
          Entries[I].UndefinedMacro := True;
        Entries[I].Opaque := True;
      end;

      Entries[I].Expanded := NormalisePath( Expanded );

      Entries[I].Exists := False;
      if FCheckExistence and not Entries[I].UndefinedMacro and
         ( Entries[I].Expanded <> '' ) then
        Entries[I].Exists := TDirectory.Exists( Entries[I].Expanded );
    end;

    PathSet.Entries := Entries;
  end;
end;

procedure TPathCompactorAnalysis.DetectDuplicates;
var
  SetIndex, I: Integer;
  PathSet: TPathSet;
  Entries: TArray<TPathEntry>;
  Seen: TStringList;
begin
  for SetIndex := 0 to FSets.Count - 1 do
  begin
    PathSet := FSets[SetIndex];
    Entries := PathSet.Entries;

    Seen := TStringList.Create;
    try
      Seen.CaseSensitive := False;
      Seen.Duplicates := dupIgnore;
      Seen.Sorted := True;

      for I := Low( Entries ) to High( Entries ) do
      begin
        Entries[I].Duplicate := False;
        // Opaque entries are never deduplicated — two $(Config) entries may
        // resolve to different directories at build time.
        if Entries[I].Opaque or ( Entries[I].Expanded = '' ) then
          Continue;

        if Seen.IndexOf( Entries[I].Expanded ) >= 0 then
          Entries[I].Duplicate := True
        else
          Seen.Add( Entries[I].Expanded );
      end;
    finally
      Seen.Free;
    end;

    PathSet.Entries := Entries;
  end;
end;

function TPathCompactorAnalysis.StoredPrefixLengthFor( const AEntry: TPathEntry;
  const APrefix: string ): Integer;
var
  Segments: TArray<string>;
  I: Integer;
  Trial: string;
begin
  Result := 0;
  if APrefix = '' then
    Exit;

  // Find the shortest RAW prefix of the entry that expands to APrefix. For an
  // entry stored as "$(BDS)\source" that is 6 characters, not 46 — which is
  // exactly why saving must be scored here and not in expanded space.
  Segments := AEntry.Raw.Split( [PathDelim] );
  Trial := '';
  for I := Low( Segments ) to High( Segments ) do
  begin
    if Trial <> '' then
      Trial := Trial + PathDelim;
    Trial := Trial + Segments[I];

    if SameText( NormalisePath( ExpandLibraryMacros( Trial, FMacros ) ), APrefix ) then
      Exit( Length( Trial ) );
  end;
end;

procedure TPathCompactorAnalysis.GenerateCandidates;
var
  Tally: TDictionary<string, Integer>;
  Canonical: TDictionary<string, string>;
  SetIndex, I, J, K: Integer;
  PathSet: TPathSet;
  Entries: TArray<TPathEntry>;
  Segments: TArray<string>;
  Prefix: string;
  Pair: TPair<string, Integer>;
  Candidate: TVarCandidate;
  Matches: TArray<TEntryMatch>;
  StoredLen: Integer;
  ExistingName: string;
begin
  SetLength( FCandidates, 0 );
  SetLength( FAccepted, 0 );

  Tally := TDictionary<string, Integer>.Create;
  Canonical := TDictionary<string, string>.Create;
  try
    // Ancestors only: a prefix equal to the entry itself saves nothing worth a
    // variable, and walking segments gives boundary alignment for free.
    for SetIndex := 0 to FSets.Count - 1 do
    begin
      Entries := FSets[SetIndex].Entries;
      for I := Low( Entries ) to High( Entries ) do
      begin
        // A dropped entry is not going to be written, so it neither votes for a
        // candidate nor contributes to its saving.
        if Entries[I].Opaque or Entries[I].Drop or ( Entries[I].Expanded = '' ) then
          Continue;

        Segments := Entries[I].Expanded.Split( [PathDelim] );
        Prefix := '';
        for J := Low( Segments ) to High( Segments ) - 1 do
        begin
          if Prefix <> '' then
            Prefix := Prefix + PathDelim;
          Prefix := Prefix + Segments[J];

          if Length( Prefix ) < MinPrefixLength then
            Continue;
          // A bare drive root is never worth a variable.
          if ( Length( Prefix ) <= 3 ) or ( Pos( PathDelim, Prefix ) = 0 ) then
            Continue;

          // Tally case-insensitively, but remember the first casing seen so the
          // proposed variable value reads the way the user wrote it.
          if Tally.ContainsKey( Prefix.ToLower ) then
            Tally[Prefix.ToLower] := Tally[Prefix.ToLower] + 1
          else
          begin
            Tally.Add( Prefix.ToLower, 1 );
            Canonical.Add( Prefix.ToLower, Prefix );
          end;
        end;
      end;
    end;

    // Promote the tally into candidates, keeping the original casing by
    // re-deriving it from the first entry that matches.
    for Pair in Tally do
    begin
      if Pair.Value < FMinOccurrences then
        Continue;

      Candidate := Default( TVarCandidate );
      if not Canonical.TryGetValue( Pair.Key, Candidate.Prefix ) then
        Candidate.Prefix := Pair.Key;
      Candidate.Occurrences := Pair.Value;
      Candidate.Accepted := False;

      // Reuse an existing macro of the same value where one exists, rather than
      // defining a redundant new variable; this is where the real wins are.
      ExistingName := ExistingMacroFor( Candidate.Prefix );
      if ExistingName <> '' then
      begin
        Candidate.Name := ExistingName;
        Candidate.PreExisting := True;
      end
      else
      begin
        // Provisional name only. The final, collision-free name is assigned at
        // acceptance time (see SelectVariables) so that the highest-value
        // candidate gets the clean name rather than whichever one happened to
        // be generated first — otherwise the 499-use prefix ends up as
        // $(SOURCE_4) while a 50-use one takes $(SOURCE).
        Candidate.Name := DeriveVariableName( Candidate.Prefix );
        Candidate.PreExisting := False;
      end;

      SetLength( FCandidates, Length( FCandidates ) + 1 );
      FCandidates[High( FCandidates )] := Candidate;
    end;
  finally
    Canonical.Free;
    Tally.Free;
  end;

  // Record, per entry, which candidates it matches and what each would cost in
  // stored space. Doing it once keeps the selection loop cheap.
  for SetIndex := 0 to FSets.Count - 1 do
  begin
    PathSet := FSets[SetIndex];
    Entries := PathSet.Entries;

    for I := Low( Entries ) to High( Entries ) do
    begin
      SetLength( Matches, 0 );
      if not Entries[I].Opaque and not Entries[I].Drop and ( Entries[I].Expanded <> '' ) then
        for K := Low( FCandidates ) to High( FCandidates ) do
          if StartsWithSegment( Entries[I].Expanded, FCandidates[K].Prefix ) then
          begin
            StoredLen := StoredPrefixLengthFor( Entries[I], FCandidates[K].Prefix );
            if StoredLen <= 0 then
              Continue;

            SetLength( Matches, Length( Matches ) + 1 );
            Matches[High( Matches )].CandidateIndex := K;
            Matches[High( Matches )].StoredPrefixLen := StoredLen;
            Matches[High( Matches )].ExpandedPrefixLen := Length( FCandidates[K].Prefix );
          end;
      Entries[I].Matches := Matches;
    end;

    PathSet.Entries := Entries;
  end;
end;

function TPathCompactorAnalysis.StoredLengthUnder( const AEntry: TPathEntry;
  const AAcceptedSet: TArray<Integer> ): Integer;
var
  I, J, BestMatch: Integer;
begin
  Result := Length( AEntry.Raw );
  if AEntry.Opaque then
    Exit;

  // Longest accepted expanded prefix wins, so $(GITLAKTHIRD) is not pre-empted
  // by $(GITLAK).
  BestMatch := -1;
  for I := Low( AEntry.Matches ) to High( AEntry.Matches ) do
    for J := Low( AAcceptedSet ) to High( AAcceptedSet ) do
      if AEntry.Matches[I].CandidateIndex = AAcceptedSet[J] then
      begin
        if ( BestMatch < 0 ) or
           ( AEntry.Matches[I].ExpandedPrefixLen >
             AEntry.Matches[BestMatch].ExpandedPrefixLen ) then
          BestMatch := I;
        Break;
      end;

  if BestMatch < 0 then
    Exit;

  Result := Length( AEntry.Raw ) - AEntry.Matches[BestMatch].StoredPrefixLen +
    Length( FCandidates[AEntry.Matches[BestMatch].CandidateIndex].Name ) + 3;
end;

function TPathCompactorAnalysis.IncrementalSaving( ACandidateIndex: Integer ): Integer;
var
  Trial: TArray<Integer>;
  SetIndex, I: Integer;
  Entries: TArray<TPathEntry>;
begin
  Result := 0;
  if FCandidates[ACandidateIndex].Accepted then
    Exit;

  Trial := Copy( FAccepted );
  SetLength( Trial, Length( Trial ) + 1 );
  Trial[High( Trial )] := ACandidateIndex;

  for SetIndex := 0 to FSets.Count - 1 do
  begin
    Entries := FSets[SetIndex].Entries;
    for I := Low( Entries ) to High( Entries ) do
    begin
      if Entries[I].Drop then
        Continue;
      Inc( Result, StoredLengthUnder( Entries[I], FAccepted ) -
                   StoredLengthUnder( Entries[I], Trial ) );
    end;
  end;
end;

procedure TPathCompactorAnalysis.SelectVariables;
var
  Best, BestGain, Gain, I: Integer;
begin
  while Length( FAccepted ) < FMaxVariables do
  begin
    Best := -1;
    BestGain := 0;

    // Re-score after every acceptance: prefixes nest, so a static ranking is
    // wrong the moment the first candidate is taken.
    for I := Low( FCandidates ) to High( FCandidates ) do
    begin
      Gain := IncrementalSaving( I );
      if Gain > BestGain then
      begin
        BestGain := Gain;
        Best := I;
      end;
    end;

    if ( Best < 0 ) or ( BestGain < FMinNetSaving ) then
      Break;

    // Assign the final name now, in descending order of value, so the most
    // valuable prefix gets the unsuffixed name and only genuine collisions
    // between ACCEPTED variables ever pick up a _2/_3 suffix.
    if not FCandidates[Best].PreExisting then
      FCandidates[Best].Name := UniqueVariableName( FCandidates[Best].Prefix );

    FCandidates[Best].Accepted := True;
    FCandidates[Best].NetSaving := BestGain;
    SetLength( FAccepted, Length( FAccepted ) + 1 );
    FAccepted[High( FAccepted )] := Best;
  end;
end;

procedure TPathCompactorAnalysis.RewriteEntries;
var
  SetIndex, I: Integer;
  PathSet: TPathSet;
  Entries: TArray<TPathEntry>;
  J, K, BestMatch: Integer;
  Candidate: TVarCandidate;
begin
  for SetIndex := 0 to FSets.Count - 1 do
  begin
    PathSet := FSets[SetIndex];
    Entries := PathSet.Entries;

    for I := Low( Entries ) to High( Entries ) do
    begin
      Entries[I].NewRaw := '';
      if Entries[I].Opaque or Entries[I].Drop then
        Continue;

      BestMatch := -1;
      for J := Low( Entries[I].Matches ) to High( Entries[I].Matches ) do
        for K := Low( FAccepted ) to High( FAccepted ) do
          if Entries[I].Matches[J].CandidateIndex = FAccepted[K] then
          begin
            if ( BestMatch < 0 ) or
               ( Entries[I].Matches[J].ExpandedPrefixLen >
                 Entries[I].Matches[BestMatch].ExpandedPrefixLen ) then
              BestMatch := J;
            Break;
          end;

      if BestMatch < 0 then
        Continue;

      Candidate := FCandidates[Entries[I].Matches[BestMatch].CandidateIndex];

      // Rewrite from the RAW text, replacing the raw prefix that maps to the
      // accepted expanded prefix. Rewriting from the expanded path instead
      // would lengthen every entry that was already stored as a macro.
      Entries[I].NewRaw := '$(' + Candidate.Name + ')' +
        Copy( Entries[I].Raw, Entries[I].Matches[BestMatch].StoredPrefixLen + 1, MaxInt );

      // Never emit a change that makes the stored string longer.
      if Length( Entries[I].NewRaw ) >= Length( Entries[I].Raw ) then
        Entries[I].NewRaw := '';
    end;

    PathSet.Entries := Entries;
  end;
end;

procedure TPathCompactorAnalysis.ApplyHygiene;
var
  SetIndex, I: Integer;
  PathSet: TPathSet;
  Entries: TArray<TPathEntry>;
begin
  for SetIndex := 0 to FSets.Count - 1 do
  begin
    PathSet := FSets[SetIndex];
    Entries := PathSet.Entries;

    for I := Low( Entries ) to High( Entries ) do
    begin
      Entries[I].Drop := False;

      // A dead macro reference is removable even though it is opaque — there is
      // nothing behind it to preserve. A DIVERGENT one never is.
      if FRemoveUndefinedMacros and Entries[I].UndefinedMacro then
      begin
        Entries[I].Drop := True;
        Continue;
      end;

      if Entries[I].Opaque then
        Continue;

      if FRemoveDuplicates and Entries[I].Duplicate then
        Entries[I].Drop := True;

      if FRemoveMissing and FCheckExistence and not Entries[I].Exists then
        Entries[I].Drop := True;
    end;

    PathSet.Entries := Entries;
  end;
end;

function TPathCompactorAnalysis.ExistingMacroFor( const APrefix: string ): string;
var
  I: Integer;
  Value: string;
begin
  Result := '';
  for I := 0 to FMacros.Count - 1 do
  begin
    if FMacros.Names[I] = '' then
      Continue;

    // Compare fully expanded, so "InterBase=$(BDS)\InterBase2020" is matched
    // by its resolved value rather than its literal text.
    Value := NormalisePath( ExpandLibraryMacros( FMacros.ValueFromIndex[I], FMacros ) );
    if ( Value <> '' ) and SameText( Value, APrefix ) then
      Exit( FMacros.Names[I] );
  end;
end;

function TPathCompactorAnalysis.UniqueVariableName( const APrefix: string ): string;
var
  Base: string;
  Suffix, I, Widen: Integer;
  Taken: Boolean;

  function NameIsTaken( const AName: string ): Boolean;
  var
    K: Integer;
  begin
    Result := True;

    // Never shadow an IDE built-in or a process environment variable.
    if FReservedNames.IndexOf( AName ) >= 0 then
      Exit;
    // Nor an existing IDE variable holding a different value.
    if FMacros.IndexOfName( AName ) >= 0 then
      Exit;
    // Only ALREADY-ACCEPTED variables can genuinely collide.
    for K := Low( FAccepted ) to High( FAccepted ) do
      if SameText( FCandidates[FAccepted[K]].Name, AName ) then
        Exit;

    Result := False;
  end;

begin
  // Prefer a name that distinguishes the path: fold in another parent segment
  // before resorting to a numeric suffix, so two libraries that both end in
  // "...\Delphi 13 Florence\37.0" get their own names rather than X and X_2.
  for Widen := 0 to MaxWidenSteps do
  begin
    Result := DeriveVariableName( APrefix, Widen );
    if not NameIsTaken( Result ) then
      Exit;
  end;

  Base := DeriveVariableName( APrefix, MaxWidenSteps );
  Result := Base;
  Suffix := 1;

  repeat
    Taken := False;

    // Never shadow an IDE built-in or a process environment variable: the
    // IDE's own expander consults the process environment first, so shadowing
    // one would break path resolution well beyond this feature.
    if FReservedNames.IndexOf( Result ) >= 0 then
      Taken := True;

    // Nor an existing IDE variable holding a different value.
    if not Taken and ( FMacros.IndexOfName( Result ) >= 0 ) then
      Taken := True;

    // Only ALREADY-ACCEPTED variables can genuinely collide. Testing every
    // candidate would compare against provisional names — including this
    // candidate's own — so every name would pick up a needless _2 suffix.
    if not Taken then
      for I := Low( FAccepted ) to High( FAccepted ) do
        if SameText( FCandidates[FAccepted[I]].Name, Result ) then
        begin
          Taken := True;
          Break;
        end;

    if Taken then
    begin
      Inc( Suffix );
      Result := Base + '_' + IntToStr( Suffix );
    end;
  until not Taken;
end;

procedure TPathCompactorAnalysis.Analyse;
begin
  ExpandEntries;
  DetectDuplicates;

  // Hygiene BEFORE candidate selection. An entry that is about to be removed
  // must not vote for a variable: doing so can define a variable whose every
  // user then disappears, and it overstates the saving by counting characters
  // that were never going to be written.
  ApplyHygiene;

  GenerateCandidates;
  SelectVariables;
  RewriteEntries;
end;

function TPathCompactorAnalysis.AcceptedVariables: TArray<TVarCandidate>;
var
  I: Integer;
begin
  SetLength( Result, Length( FAccepted ) );
  for I := Low( FAccepted ) to High( FAccepted ) do
    Result[I] := FCandidates[FAccepted[I]];
end;

function TPathCompactorAnalysis.TotalStoredBefore: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FSets.Count - 1 do
    Inc( Result, FSets[I].OriginalLength );
end;

function TPathCompactorAnalysis.TotalStoredAfter: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FSets.Count - 1 do
    Inc( Result, FSets[I].ResultLength );
end;

function TPathCompactorAnalysis.DuplicateCount: Integer;
var
  SetIndex, I: Integer;
  Entries: TArray<TPathEntry>;
begin
  Result := 0;
  for SetIndex := 0 to FSets.Count - 1 do
  begin
    Entries := FSets[SetIndex].Entries;
    for I := Low( Entries ) to High( Entries ) do
      if Entries[I].Duplicate then
        Inc( Result );
  end;
end;

function TPathCompactorAnalysis.MissingCount: Integer;
var
  SetIndex, I: Integer;
  Entries: TArray<TPathEntry>;
begin
  Result := 0;
  if not FCheckExistence then
    Exit;

  for SetIndex := 0 to FSets.Count - 1 do
  begin
    Entries := FSets[SetIndex].Entries;
    for I := Low( Entries ) to High( Entries ) do
      if not Entries[I].Opaque and not Entries[I].Exists then
        Inc( Result );
  end;
end;

function TPathCompactorAnalysis.RevalidateDrops: Integer;
var
  SetIndex, I: Integer;
  PathSet: TPathSet;
  Entries: TArray<TPathEntry>;
  Expanded: string;
  StillGone: Boolean;
begin
  Result := 0;

  for SetIndex := 0 to FSets.Count - 1 do
  begin
    PathSet := FSets[SetIndex];
    Entries := PathSet.Entries;

    for I := Low( Entries ) to High( Entries ) do
    begin
      if not Entries[I].Drop then
        Continue;

      // A duplicate cannot stop being a duplicate, so only the two disc- and
      // macro-dependent reasons are worth re-testing.
      if Entries[I].UndefinedMacro then
      begin
        Expanded := ExpandLibraryMacros( Entries[I].Raw, FMacros );
        StillGone := Pos( '$(', Expanded ) > 0;
        if not StillGone then
        begin
          // The macro resolves now; keep the entry and correct its state.
          Entries[I].Drop := False;
          Entries[I].UndefinedMacro := False;
          Entries[I].Expanded := NormalisePath( Expanded );
          Inc( Result );
        end;
      end
      else if not Entries[I].Duplicate and FCheckExistence then
      begin
        // Re-probe the file system: a share may have reconnected, or an
        // installer finished, since the analysis ran.
        if ( Entries[I].Expanded <> '' ) and TDirectory.Exists( Entries[I].Expanded ) then
        begin
          Entries[I].Drop := False;
          Entries[I].Exists := True;
          Inc( Result );
        end;
      end;
    end;

    PathSet.Entries := Entries;
  end;
end;

function TPathCompactorAnalysis.DropCount: Integer;
var
  SetIndex, I: Integer;
  Entries: TArray<TPathEntry>;
begin
  Result := 0;
  for SetIndex := 0 to FSets.Count - 1 do
  begin
    Entries := FSets[SetIndex].Entries;
    for I := Low( Entries ) to High( Entries ) do
      if Entries[I].Drop then
        Inc( Result );
  end;
end;

function TPathCompactorAnalysis.DropSummary: TArray<string>;
var
  SetIndex, I: Integer;
  PathSet: TPathSet;
  Entries: TArray<TPathEntry>;
  Reason: string;
begin
  SetLength( Result, 0 );
  for SetIndex := 0 to FSets.Count - 1 do
  begin
    PathSet := FSets[SetIndex];
    Entries := PathSet.Entries;
    for I := Low( Entries ) to High( Entries ) do
    begin
      if not Entries[I].Drop then
        Continue;

      if Entries[I].UndefinedMacro then
        Reason := 'undefined macro'
      else if Entries[I].Duplicate then
        Reason := 'duplicate'
      else
        Reason := 'directory missing';

      SetLength( Result, Length( Result ) + 1 );
      Result[High( Result )] := Format( '%s / %s  [%s]  %s',
        [PathSet.PlatformName, PathSet.PathType.ToDisplayName, Reason, Entries[I].Raw] );
    end;
  end;
end;

function TPathCompactorAnalysis.DivergentMacroCount: Integer;
var
  SetIndex, I: Integer;
  Entries: TArray<TPathEntry>;
begin
  Result := 0;
  for SetIndex := 0 to FSets.Count - 1 do
  begin
    Entries := FSets[SetIndex].Entries;
    for I := Low( Entries ) to High( Entries ) do
      if Entries[I].DivergentMacro then
        Inc( Result );
  end;
end;

function TPathCompactorAnalysis.UndefinedMacroCount: Integer;
var
  SetIndex, I: Integer;
  Entries: TArray<TPathEntry>;
begin
  Result := 0;
  for SetIndex := 0 to FSets.Count - 1 do
  begin
    Entries := FSets[SetIndex].Entries;
    for I := Low( Entries ) to High( Entries ) do
      if Entries[I].UndefinedMacro then
        Inc( Result );
  end;
end;

end.
