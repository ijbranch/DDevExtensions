{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude Code                                           *}
{*                                                                            *}
{* Parallel Build All: the RTL-only planning, scheduling and parsing logic    *}
{*                                                                            *}
{******************************************************************************}

unit ParallelBuildCore;

/// <summary>
/// The pure logic behind "Parallel Build All": reading what a build needs from <c>.dproj</c> and
/// <c>.groupproj</c> text, working out which projects may build at the same time, scheduling them,
/// composing the MSBuild and EurekaLog command lines, and parsing the compiler's output.
/// </summary>
/// <remarks>
/// RTL only and free of the ToolsAPI, so every rule here is unit-tested.  Launching processes lives in
/// <c>ParallelBuildRunner</c>; the IDE hook and the options live in <c>ParallelBuild</c>.
/// </remarks>

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  /// <summary>What a project produces, as far as build ordering and EurekaLog are concerned.</summary>
  TParallelProjectKind = (
    /// <summary>An executable ( <c>AppType</c> Application or Console ).</summary>
    pkApplication,
    /// <summary>A package ( <c>AppType</c> Package ): built before every non-package project.</summary>
    pkPackage,
    /// <summary>A DLL ( <c>AppType</c> Library ).</summary>
    pkLibrary );

  /// <summary>One project as the IDE describes it, before any ordering is worked out.</summary>
  TPlanInput = record
    /// <summary>Absolute path of the <c>.dproj</c>.</summary>
    FileName: string;
    /// <summary>The text of the <c>.dproj</c>.</summary>
    DprojText: string;
    /// <summary>The configuration to build, for example <c>Release</c>.</summary>
    Config: string;
    /// <summary>The platform to build, for example <c>Win64</c>.</summary>
    Platform: string;
  end;

  /// <summary>One project of a build plan: what to build, what it waits for and what it must not overlap.</summary>
  TParallelProject = record
    /// <summary>Absolute path of the <c>.dproj</c>.</summary>
    FileName: string;
    /// <summary>The configuration to build.</summary>
    Config: string;
    /// <summary>The platform to build.</summary>
    Platform: string;
    /// <summary>What the project produces.</summary>
    Kind: TParallelProjectKind;
    /// <summary>Indexes ( into the plan ) of the projects that must succeed before this one starts.</summary>
    DependsOn: TArray<Integer>;
    /// <summary>
    /// The DCU output folder, upper-cased.  Two projects with the same key never build at the same time,
    /// because both would write the same DCU files.
    /// </summary>
    LockKey: string;
  end;

  /// <summary>Where a project stands in a running build.</summary>
  TProjectState = (
    /// <summary>Not started yet.</summary>
    psWaiting,
    /// <summary>Building now.</summary>
    psRunning,
    /// <summary>Built without error.</summary>
    psSucceeded,
    /// <summary>Built with an error.</summary>
    psFailed,
    /// <summary>Never built: a project it depends on failed or was skipped, or the build was cancelled.</summary>
    psSkipped );

  /// <summary>
  /// Decides which project starts next.  It holds no threads and no locks: one caller ( the build
  /// co-ordinator ) asks it what to start and tells it what finished.
  /// </summary>
  /// <example>
  ///   <code>
  ///     var oSchedule := TParallelSchedule.Create( saPlan, 8 );
  ///     var iNext := oSchedule.NextToStart;      // -1 when nothing can start right now
  ///     oSchedule.Finished( iNext, True );
  ///   </code>
  /// </example>
  TParallelSchedule = class
  private
    /// <summary>The plan being scheduled.</summary>
    FProjects: TArray<TParallelProject>;
    /// <summary>Each project's state, by plan index.</summary>
    FStates: TArray<TProjectState>;
    /// <summary>Why each skipped project was skipped, by plan index.</summary>
    FSkipReasons: TArray<string>;
    /// <summary>The most projects that may build at once.</summary>
    FMaxWorkers: Integer;
    /// <summary>The number of projects building now.</summary>
    FRunningCount: Integer;
    /// <summary>Marks every waiting project whose dependency failed or was skipped as skipped, until none is left.</summary>
    procedure SkipBlockedProjects;
    /// <summary>True when every dependency of the project has succeeded.</summary>
    /// <param name="AIndex">The plan index.</param>
    /// <returns>True when nothing it depends on is still outstanding.</returns>
    function DependenciesMet( AIndex: Integer ): Boolean;
    /// <summary>True when a running project uses the same DCU folder.</summary>
    /// <param name="AIndex">The plan index.</param>
    /// <returns>True when starting it now would overlap another build's DCU output.</returns>
    function LockHeld( AIndex: Integer ): Boolean;
    /// <summary>Reads a project's state.</summary>
    /// <param name="AIndex">The plan index.</param>
    /// <returns>The state.</returns>
    function GetState( AIndex: Integer ): TProjectState;
    /// <summary>Reads why a project was skipped.</summary>
    /// <param name="AIndex">The plan index.</param>
    /// <returns>The reason, or an empty string.</returns>
    function GetSkipReason( AIndex: Integer ): string;
  public
    /// <summary>Creates a schedule over a plan.</summary>
    /// <param name="AProjects">The plan, from <see cref="BuildPlan"/>.</param>
    /// <param name="AMaxWorkers">The most projects that may build at once; values below 1 mean 1.</param>
    constructor Create( const AProjects: TArray<TParallelProject>; AMaxWorkers: Integer );
    /// <summary>
    /// Picks the next project to start and marks it running.  The lowest plan index wins, so the order
    /// of the project group is kept wherever the rules allow.
    /// </summary>
    /// <returns>The plan index, or -1 when nothing can start until a running project finishes.</returns>
    function NextToStart: Integer;
    /// <summary>Records that a running project has finished.</summary>
    /// <param name="AIndex">The plan index returned by <see cref="NextToStart"/>.</param>
    /// <param name="ASucceeded">True when it built without error.</param>
    /// <exception cref="EInvalidOpException">The project is not running.</exception>
    procedure Finished( AIndex: Integer; ASucceeded: Boolean );
    /// <summary>Skips every project that has not started; running projects are left to finish.</summary>
    /// <param name="AReason">The reason recorded against each skipped project.</param>
    procedure CancelWaiting( const AReason: string );
    /// <summary>True when nothing is running and nothing is left to start.</summary>
    /// <returns>True once the build is over.</returns>
    function Done: Boolean;
    /// <summary>The number of projects in a given state.</summary>
    /// <param name="AState">The state to count.</param>
    /// <returns>The count.</returns>
    function CountOf( AState: TProjectState ): Integer;
    /// <summary>The number of projects building now.</summary>
    property RunningCount: Integer read FRunningCount;
    /// <summary>A project's state, by plan index.</summary>
    property States[ AIndex: Integer ]: TProjectState read GetState;
    /// <summary>Why a project was skipped, by plan index.</summary>
    property SkipReasons[ AIndex: Integer ]: string read GetSkipReason;
  end;

  /// <summary>How serious one line of compiler output is.</summary>
  TDiagnosticKind = (
    /// <summary>A compiler hint ( code <c>H</c> ).</summary>
    dkHint,
    /// <summary>A compiler or MSBuild warning.</summary>
    dkWarning,
    /// <summary>A compiler or MSBuild error.</summary>
    dkError,
    /// <summary>A fatal compiler error ( code <c>F</c> ).</summary>
    dkFatal );

  /// <summary>One hint, warning or error read from MSBuild's output.</summary>
  TBuildDiagnostic = record
    /// <summary>How serious it is.</summary>
    Kind: TDiagnosticKind;
    /// <summary>The source file it names, or an empty string when the line names none.</summary>
    FileName: string;
    /// <summary>The 1-based source line, or 0 when the line names none.</summary>
    Line: Integer;
    /// <summary>The code, for example <c>E2003</c> or <c>MSB3073</c>.</summary>
    Code: string;
    /// <summary>The message text, without the trailing <c>[project]</c> MSBuild appends.</summary>
    Text: string;
  end;

const
  /// <summary>The most workers chosen automatically: measured 2026-11-10, twelve gained under 10% over eight.</summary>
  DEFAULT_MAX_WORKERS = 8;
  /// <summary>The most workers a setting may ask for.</summary>
  WORKER_LIMIT = 32;

/// <summary>Reads a project's kind from its <c>AppType</c>.</summary>
/// <param name="ADprojText">The text of the <c>.dproj</c>.</param>
/// <returns>The kind; an unknown or missing <c>AppType</c> is an application.</returns>
function ProjectKindFromDproj( const ADprojText: string ): TParallelProjectKind;

/// <summary>
/// Reads the value a <c>.dproj</c> gives a property for one configuration and platform: the last value
/// among the property groups that apply ( Base, the configuration and its parents, each with and without
/// the platform ), with <c>$(Platform)</c> and <c>$(Config)</c> replaced.
/// </summary>
/// <param name="ADprojText">The text of the <c>.dproj</c>.</param>
/// <param name="AProperty">The property name, for example <c>DCC_DcuOutput</c>.</param>
/// <param name="AConfig">The configuration name.</param>
/// <param name="APlatform">The platform name.</param>
/// <returns>The value, or an empty string when no applicable group sets it.</returns>
function ResolveDprojProperty( const ADprojText, AProperty, AConfig, APlatform: string ): string;

/// <summary>Works out the DCU folder a build writes to, as a key for "these two must not overlap".</summary>
/// <param name="ADprojFile">Absolute path of the <c>.dproj</c>.</param>
/// <param name="ADprojText">The text of the <c>.dproj</c>.</param>
/// <param name="AConfig">The configuration name.</param>
/// <param name="APlatform">The platform name.</param>
/// <returns>The absolute folder, upper-cased and without a trailing delimiter; the project folder when none is set.</returns>
function DcuLockKey( const ADprojFile, ADprojText, AConfig, APlatform: string ): string;

/// <summary>Lists the packages a package project requires, from its <c>.dcp</c> references.</summary>
/// <param name="ADprojText">The text of the <c>.dproj</c>.</param>
/// <returns>The package names without path or extension.</returns>
function RequiredPackages( const ADprojText: string ): TArray<string>;

/// <summary>Reads a project group's members and the dependencies it declares between them.</summary>
/// <param name="AGroupText">The text of the <c>.groupproj</c>.</param>
/// <param name="AProjects">Receives each member's <c>Include</c> path, as written.</param>
/// <param name="ADependencies">Receives, for each member, the paths in its <c>Dependencies</c> element.</param>
procedure ParseGroupProjects( const AGroupText: string; out AProjects: TArray<string>;
  out ADependencies: TArray<TArray<string>> );

/// <summary>
/// Turns the projects of a group into a build plan.  A project waits for: the projects the group declares
/// it depends on; for a package, the group's packages it requires; and, for anything that is not a package,
/// every package in the group.
/// </summary>
/// <param name="AGroupFile">Absolute path of the <c>.groupproj</c>; its folder resolves the group's relative paths.</param>
/// <param name="AGroupText">The text of the <c>.groupproj</c>; empty when there is no group file.</param>
/// <param name="AInputs">The projects, in group order.</param>
/// <returns>The plan, one entry per input and in the same order.</returns>
function BuildPlan( const AGroupFile, AGroupText: string; const AInputs: TArray<TPlanInput> ): TArray<TParallelProject>;

/// <summary>Chooses the worker count: the setting when it is positive, otherwise one per logical CPU up to eight.</summary>
/// <param name="AConfigured">The user's setting; 0 or less means automatic.</param>
/// <param name="ACpuCount">The number of logical CPUs.</param>
/// <returns>A count from 1 to <see cref="WORKER_LIMIT"/>.</returns>
function EffectiveWorkerCount( AConfigured, ACpuCount: Integer ): Integer;

/// <summary>Quotes one command-line argument so that <c>CommandLineToArgvW</c> reads it back unchanged.</summary>
/// <param name="AValue">The argument.</param>
/// <returns>The argument, quoted when it is empty or holds a space, tab or quote.</returns>
function QuoteArgument( const AValue: string ): string;

/// <summary>Composes the command line that builds one project with MSBuild.</summary>
/// <param name="AMSBuildExe">Full path of <c>MSBuild.exe</c>.</param>
/// <param name="ADprojFile">Absolute path of the <c>.dproj</c>.</param>
/// <param name="AConfig">The configuration name.</param>
/// <param name="APlatform">The platform name.</param>
/// <returns>The command line: target Build, minimal output, no node reuse.</returns>
function MSBuildCommandLine( const AMSBuildExe, ADprojFile, AConfig, APlatform: string ): string;

/// <summary>Composes the command line that post-processes one output file with EurekaLog's <c>ecc32</c>.</summary>
/// <param name="AEcc32Exe">Full path of <c>ecc32.exe</c>.</param>
/// <param name="ADprojFile">Absolute path of the <c>.dproj</c>.</param>
/// <param name="AOutputFile">Absolute path of the exe or DLL just built.</param>
/// <param name="AProfile">Absolute path of the <c>.eof</c> profile, from <see cref="EurekaLogProfilePath"/>.</param>
/// <returns>The command line.</returns>
function Ecc32CommandLine( const AEcc32Exe, ADprojFile, AOutputFile, AProfile: string ): string;

/// <summary>Turns the output of <c>set</c> into a list of <c>NAME=VALUE</c> strings.</summary>
/// <param name="ASetOutput">The text <c>cmd /c set</c> printed.</param>
/// <returns>One entry per variable; lines that are not <c>NAME=VALUE</c> are dropped.</returns>
function ParseSetOutput( const ASetOutput: string ): TArray<string>;

/// <summary>Reads one variable from a list of <c>NAME=VALUE</c> strings.</summary>
/// <param name="AVariables">The list, from <see cref="ParseSetOutput"/>.</param>
/// <param name="AName">The variable name; case does not matter.</param>
/// <returns>The value, or an empty string when the variable is not there.</returns>
function EnvironmentValue( const AVariables: TArray<string>; const AName: string ): string;

/// <summary>Builds the environment block <c>CreateProcess</c> expects from a list of <c>NAME=VALUE</c> strings.</summary>
/// <param name="AVariables">The list.</param>
/// <returns>The entries separated by #0, ending with #0 ( the string's own terminator makes the final double #0 ).</returns>
function EnvironmentBlock( const AVariables: TArray<string> ): string;

/// <summary>Finds <c>MSBuild.exe</c> from the environment <c>rsvars.bat</c> sets up.</summary>
/// <param name="AVariables">The environment, from <see cref="ParseSetOutput"/>.</param>
/// <returns><c>%FrameworkDir%\MSBuild.exe</c>, or an empty string when <c>FrameworkDir</c> is not set.</returns>
function MSBuildExeFromEnvironment( const AVariables: TArray<string> ): string;

/// <summary>Reads one line of MSBuild output as a hint, warning or error.</summary>
/// <param name="ALine">The line.</param>
/// <param name="ADiagnostic">Receives the diagnostic when the line is one.</param>
/// <returns>True when the line is a diagnostic.</returns>
function ParseBuildLine( const ALine: string; out ADiagnostic: TBuildDiagnostic ): Boolean;

/// <summary>Reads every hint, warning and error from MSBuild's output, each distinct line once.</summary>
/// <param name="AOutput">Everything the build printed.</param>
/// <returns>The diagnostics in output order.</returns>
function ParseBuildOutput( const AOutput: string ): TArray<TBuildDiagnostic>;

/// <summary>True when a diagnostic list holds an error or a fatal error.</summary>
/// <param name="ADiagnostics">The list.</param>
/// <returns>True when the build it came from must count as failed.</returns>
function HasErrors( const ADiagnostics: TArray<TBuildDiagnostic> ): Boolean;

/// <summary>True when a program is a DUnitX test runner.</summary>
/// <param name="ADprText">The text of the project's <c>.dpr</c>.</param>
/// <returns>True when it uses <c>DUnitX.TestFramework</c>.</returns>
function IsDUnitXRunner( const ADprText: string ): Boolean;

/// <summary>
/// Decides whether a built project is post-processed by EurekaLog: only when the step is switched on, the
/// project has a <c>.eof</c> beside its <c>.dproj</c>, it is not a package, it is not a DUnitX runner ( an
/// EurekaLog dialog would block an unattended run ) and the configuration is Release ( an injected exe
/// cannot be source-debugged ).
/// </summary>
/// <param name="AEnabled">The user's "run EurekaLog" setting.</param>
/// <param name="AConfig">The configuration built.</param>
/// <param name="AKind">The project's kind.</param>
/// <param name="AHasEof">True when <c>&lt;Project&gt;.eof</c> exists beside the <c>.dproj</c>.</param>
/// <param name="AIsTestRunner">True when the project is a DUnitX runner.</param>
/// <returns>True when <c>ecc32</c> must run on the output.</returns>
function ShouldRunEurekaLog( AEnabled: Boolean; const AConfig: string; AKind: TParallelProjectKind;
  AHasEof, AIsTestRunner: Boolean ): Boolean;

/// <summary>
/// The profile <c>ecc32</c> must be given.  A stub <c>.eof</c> names the real one in <c>ExternalConfig=</c>,
/// usually through <c>%%APPDATA%%</c>, which <c>ecc32</c> does not expand; a full <c>.eof</c> is its own profile.
/// </summary>
/// <param name="AEofText">The text of the project's <c>.eof</c>.</param>
/// <param name="AEofPath">Absolute path of the project's <c>.eof</c>.</param>
/// <param name="AAppDataDir">The user's roaming application-data folder.</param>
/// <returns>The absolute path to pass as <c>--el_config</c>.</returns>
function EurekaLogProfilePath( const AEofText, AEofPath, AAppDataDir: string ): string;

/// <summary>Works out the file a build produces, from the project's exe output folder and its name.</summary>
/// <param name="ADprojFile">Absolute path of the <c>.dproj</c>.</param>
/// <param name="ADprojText">The text of the <c>.dproj</c>.</param>
/// <param name="AConfig">The configuration name.</param>
/// <param name="APlatform">The platform name.</param>
/// <param name="AKind">The project's kind: a library gives a <c>.dll</c>, anything else an <c>.exe</c>.</param>
/// <returns>The absolute path; the project folder is used when no output folder is set.</returns>
function ProjectOutputFile( const ADprojFile, ADprojText, AConfig, APlatform: string; AKind: TParallelProjectKind ): string;

/// <summary>Where EurekaLog installs <c>ecc32.exe</c> for one RAD Studio version.</summary>
/// <param name="AProgramFilesX86">The 32-bit Program Files folder.</param>
/// <param name="AStudioFolder">EurekaLog's folder for the IDE version, for example <c>Studio37</c>.</param>
/// <returns>The full path; the file may not exist.</returns>
function DefaultEcc32Path( const AProgramFilesX86, AStudioFolder: string ): string;

implementation

uses
  System.StrUtils, System.RegularExpressions, System.Math;

{ Helpers }

/// <summary>True when a path names its own root ( a drive, a UNC share or an unresolved MSBuild macro ).</summary>
/// <param name="APath">The path.</param>
/// <returns>True when it must not be joined to the project folder.</returns>
function IsRootedPath( const APath: string ): Boolean;
begin

  Result := ( ExtractFileDrive( APath ) <> '' ) or APath.StartsWith( '\' ) or APath.StartsWith( '$(' );

end;

/// <summary>Resolves a folder a <c>.dproj</c> names against the project's own folder.</summary>
/// <param name="ADprojFile">Absolute path of the <c>.dproj</c>.</param>
/// <param name="AFolder">The folder as written; empty means the project folder.</param>
/// <returns>The absolute folder without a trailing delimiter.</returns>
function ResolveProjectFolder( const ADprojFile, AFolder: string ): string;
begin

  var sProjectDir := ExtractFilePath( ADprojFile );

  if AFolder = '' then
    Result := sProjectDir
  else if AFolder.StartsWith( '$(' ) then
    Result := AFolder
  else if IsRootedPath( AFolder ) then
    Result := ExpandFileName( AFolder )
  else
    Result := ExpandFileName( sProjectDir + AFolder );

  Result := ExcludeTrailingPathDelimiter( Result );

end;

/// <summary>Adds a value to an integer array when it is not there yet.</summary>
/// <param name="AValues">The array.</param>
/// <param name="AValue">The value to add.</param>
procedure AddUnique( var AValues: TArray<Integer>; AValue: Integer );
begin

  for var iI := 0 to High( AValues ) do
    if AValues[ iI ] = AValue then Exit;

  AValues := AValues + [ AValue ];

end;

{ .dproj and .groupproj reading }

function ProjectKindFromDproj( const ADprojText: string ): TParallelProjectKind;
begin

  var oMatch := TRegEx.Match( ADprojText, '<AppType>\s*(\w+)\s*</AppType>', [ roIgnoreCase ] );
  var sType  := '';

  if oMatch.Success then
    sType := oMatch.Groups[ 1 ].Value;

  if SameText( sType, 'Package' ) then
    Result := pkPackage
  else if SameText( sType, 'Library' ) then
    Result := pkLibrary
  else
    Result := pkApplication;

end;

function ResolveDprojProperty( const ADprojText, AProperty, AConfig, APlatform: string ): string;
begin

  // The configuration's key ( Cfg_N ) and its parent chain, from the BuildConfiguration items.
  var saFlags: TArray<string> := [ 'Base', 'Base_' + APlatform ];
  var sName := AConfig;

  for var iGuard := 1 to 8 do
  begin
    var oItem := TRegEx.Match( ADprojText, '<BuildConfiguration\s+Include="' + TRegEx.Escape( sName ) +
      '">(.*?)</BuildConfiguration>', [ roSingleLine, roIgnoreCase ] );
    if not oItem.Success then Break;
    var oKey := TRegEx.Match( oItem.Groups[ 1 ].Value, '<Key>\s*(\w+)\s*</Key>' );
    if not oKey.Success then Break;
    saFlags := saFlags + [ oKey.Groups[ 1 ].Value, oKey.Groups[ 1 ].Value + '_' + APlatform ];
    var oParent := TRegEx.Match( oItem.Groups[ 1 ].Value, '<CfgParent>\s*(\w+)\s*</CfgParent>' );
    if ( not oParent.Success ) or SameText( oParent.Groups[ 1 ].Value, 'Base' ) then Break;
    // A parent is named by key; find the configuration name that owns that key.
    var oOwner := TRegEx.Match( ADprojText, '<BuildConfiguration\s+Include="([^"]+)">\s*<Key>\s*' +
      oParent.Groups[ 1 ].Value + '\s*</Key>', [ roIgnoreCase ] );
    if not oOwner.Success then Break;
    sName := oOwner.Groups[ 1 ].Value;
  end;

  Result := '';
  var sValuePattern := '<' + TRegEx.Escape( AProperty ) + '>([^<]*)</' + TRegEx.Escape( AProperty ) + '>';

  for var oGroup in TRegEx.Matches( ADprojText, '<PropertyGroup([^>]*)>(.*?)</PropertyGroup>', [ roSingleLine, roIgnoreCase ] ) do
  begin
    var oCondition := TRegEx.Match( oGroup.Groups[ 1 ].Value, 'Condition="([^"]*)"', [ roIgnoreCase ] );
    var bApplies   := not oCondition.Success;
    if not bApplies then
      for var oFlag in TRegEx.Matches( oCondition.Groups[ 1 ].Value, '''\$\((\w+)\)''!=''''' ) do
        if MatchText( oFlag.Groups[ 1 ].Value, saFlags ) then bApplies := True;
    if not bApplies then Continue;
    var oValue := TRegEx.Match( oGroup.Groups[ 2 ].Value, sValuePattern, [ roIgnoreCase ] );
    if oValue.Success then Result := Trim( oValue.Groups[ 1 ].Value );
  end;

  Result := StringReplace( Result, '$(Platform)', APlatform, [ rfReplaceAll, rfIgnoreCase ] );
  Result := StringReplace( Result, '$(Config)', AConfig, [ rfReplaceAll, rfIgnoreCase ] );

end;

function DcuLockKey( const ADprojFile, ADprojText, AConfig, APlatform: string ): string;
begin

  var sFolder := ResolveDprojProperty( ADprojText, 'DCC_DcuOutput', AConfig, APlatform );

  Result := UpperCase( ResolveProjectFolder( ADprojFile, sFolder ) );

end;

function RequiredPackages( const ADprojText: string ): TArray<string>;
begin

  Result := [];

  for var oMatch in TRegEx.Matches( ADprojText, '<DCCReference\s+Include="([^"]+\.dcp)"', [ roIgnoreCase ] ) do
    Result := Result + [ ChangeFileExt( ExtractFileName( oMatch.Groups[ 1 ].Value ), '' ) ];

end;

procedure ParseGroupProjects( const AGroupText: string; out AProjects: TArray<string>;
  out ADependencies: TArray<TArray<string>> );
begin

  AProjects     := [];
  ADependencies := [];

  for var oMatch in TRegEx.Matches( AGroupText, '<Projects\s+Include="([^"]+)"\s*(?:/>|>(.*?)</Projects>)',
    [ roSingleLine, roIgnoreCase ] ) do
  begin
    var saDependencies: TArray<string> := [];
    // TRegEx leaves a trailing group that took no part out of Groups, so a self-closing element has no Groups[ 2 ].
    var sBody := '';
    if oMatch.Groups.Count > 2 then sBody := oMatch.Groups[ 2 ].Value;
    var oDependencies := TRegEx.Match( sBody, '<Dependencies>([^<]*)</Dependencies>', [ roIgnoreCase ] );
    if oDependencies.Success then
      for var sPart in oDependencies.Groups[ 1 ].Value.Split( [ ';' ] ) do
        if Trim( sPart ) <> '' then saDependencies := saDependencies + [ Trim( sPart ) ];
    AProjects     := AProjects + [ oMatch.Groups[ 1 ].Value ];
    ADependencies := ADependencies + [ saDependencies ];
  end;

end;

function BuildPlan( const AGroupFile, AGroupText: string; const AInputs: TArray<TPlanInput> ): TArray<TParallelProject>;
var
  saGroupProjects   : TArray<string>;
  saGroupDependencies: TArray<TArray<string>>;
begin

  SetLength( Result, Length( AInputs ) );

  var oByFile := TDictionary<string, Integer>.Create;
  var oByName := TDictionary<string, Integer>.Create;
  try
    for var iI := 0 to High( AInputs ) do
    begin
      var rInput := AInputs[ iI ];
      Result[ iI ].FileName  := rInput.FileName;
      Result[ iI ].Config    := rInput.Config;
      Result[ iI ].Platform  := rInput.Platform;
      Result[ iI ].Kind      := ProjectKindFromDproj( rInput.DprojText );
      Result[ iI ].LockKey   := DcuLockKey( rInput.FileName, rInput.DprojText, rInput.Config, rInput.Platform );
      Result[ iI ].DependsOn := [];
      oByFile.AddOrSetValue( UpperCase( ExpandFileName( rInput.FileName ) ), iI );
      if Result[ iI ].Kind = pkPackage then
        oByName.AddOrSetValue( UpperCase( ChangeFileExt( ExtractFileName( rInput.FileName ), '' ) ), iI );
    end;

    // Dependencies the group declares.
    ParseGroupProjects( AGroupText, saGroupProjects, saGroupDependencies );
    var sGroupDir := ExtractFilePath( AGroupFile );
    for var iI := 0 to High( saGroupProjects ) do
    begin
      var iProject: Integer;
      if not oByFile.TryGetValue( UpperCase( ExpandFileName( sGroupDir + saGroupProjects[ iI ] ) ), iProject ) then Continue;
      for var sDependency in saGroupDependencies[ iI ] do
      begin
        var iDependency: Integer;
        if oByFile.TryGetValue( UpperCase( ExpandFileName( sGroupDir + sDependency ) ), iDependency ) and
          ( iDependency <> iProject ) then
          AddUnique( Result[ iProject ].DependsOn, iDependency );
      end;
    end;

    for var iI := 0 to High( AInputs ) do
      if Result[ iI ].Kind = pkPackage then
      begin
        // A package waits for the group's packages it requires.
        for var sPackage in RequiredPackages( AInputs[ iI ].DprojText ) do
        begin
          var iRequired: Integer;
          if oByName.TryGetValue( UpperCase( sPackage ), iRequired ) and ( iRequired <> iI ) then
            AddUnique( Result[ iI ].DependsOn, iRequired );
        end;
      end
      else
        // Anything else may use any package's DCP or DCUs, so it waits for all of them.
        for var iPackage in oByName.Values do
          AddUnique( Result[ iI ].DependsOn, iPackage );
  finally
    oByName.Free;
    oByFile.Free;
  end;

end;

function EffectiveWorkerCount( AConfigured, ACpuCount: Integer ): Integer;
begin

  if AConfigured > 0 then
    Result := Min( AConfigured, WORKER_LIMIT )
  else
    Result := EnsureRange( ACpuCount, 1, DEFAULT_MAX_WORKERS );

end;

{ Command lines and environment }

function QuoteArgument( const AValue: string ): string;
begin

  if ( AValue <> '' ) and ( AValue.IndexOfAny( [ ' ', #9, '"' ] ) < 0 ) then Exit( AValue );

  // The rules CommandLineToArgvW applies: backslashes are literal unless they precede a quote.
  var oBuilder := TStringBuilder.Create;
  try
    oBuilder.Append( '"' );
    var iBackslashes := 0;
    for var cChar in AValue do
      if cChar = '\' then
        Inc( iBackslashes )
      else
      begin
        if cChar = '"' then
          oBuilder.Append( '\', iBackslashes * 2 + 1 )
        else
          oBuilder.Append( '\', iBackslashes );
        oBuilder.Append( cChar );
        iBackslashes := 0;
      end;
    oBuilder.Append( '\', iBackslashes * 2 );
    oBuilder.Append( '"' );
    Result := oBuilder.ToString;
  finally
    oBuilder.Free;
  end;

end;

function MSBuildCommandLine( const AMSBuildExe, ADprojFile, AConfig, APlatform: string ): string;
begin

  Result := QuoteArgument( AMSBuildExe ) + ' ' + QuoteArgument( ADprojFile ) + ' /t:Build ' +
    QuoteArgument( '/p:Config=' + AConfig ) + ' ' + QuoteArgument( '/p:Platform=' + APlatform ) +
    ' /nologo /v:minimal /nr:false';

end;

function Ecc32CommandLine( const AEcc32Exe, ADprojFile, AOutputFile, AProfile: string ): string;
begin

  Result := QuoteArgument( AEcc32Exe ) + ' "--el_alter_exe=' + ADprojFile + ';' + AOutputFile + '" "--el_config=' +
    AProfile + '"';

end;

function ParseSetOutput( const ASetOutput: string ): TArray<string>;
begin

  Result := [];

  for var sLine in ASetOutput.Split( [ #13#10, #10 ], TStringSplitOptions.ExcludeEmpty ) do
    // A name is never empty; cmd's hidden "=C:=..." entries are not printed by set, and are dropped if they were.
    if sLine.IndexOf( '=' ) > 0 then Result := Result + [ sLine ];

end;

function EnvironmentValue( const AVariables: TArray<string>; const AName: string ): string;
begin

  Result := '';

  for var sVariable in AVariables do
    if StartsText( AName + '=', sVariable ) then Exit( sVariable.Substring( Length( AName ) + 1 ) );

end;

function EnvironmentBlock( const AVariables: TArray<string> ): string;
begin

  Result := '';

  for var sVariable in AVariables do
    Result := Result + sVariable + #0;

end;

function MSBuildExeFromEnvironment( const AVariables: TArray<string> ): string;
begin

  var sFrameworkDir := EnvironmentValue( AVariables, 'FrameworkDir' );

  if sFrameworkDir = '' then
    Result := ''
  else
    Result := IncludeTrailingPathDelimiter( sFrameworkDir ) + 'MSBuild.exe';

end;

{ Compiler output }

/// <summary>Maps a diagnostic code and MSBuild's own word for it to a kind.</summary>
/// <param name="ACode">The code, for example <c>H2077</c> or <c>MSB3073</c>.</param>
/// <param name="AWord">MSBuild's word, <c>error</c> or <c>warning</c>.</param>
/// <returns>The kind: by the code's letter for a compiler code, by the word for an MSBuild code.</returns>
function KindOf( const ACode, AWord: string ): TDiagnosticKind;
begin

  if StartsText( 'MSB', ACode ) or ( ACode = '' ) then
  begin
    if SameText( AWord, 'warning' ) then
      Result := dkWarning
    else
      Result := dkError;
    Exit;
  end;

  case UpCase( ACode[ 1 ] ) of
    'H': Result := dkHint;
    'W': Result := dkWarning;
    'F': Result := dkFatal;
  else
    Result := dkError;
  end;

end;

/// <summary>Removes the <c>[project.dproj]</c> MSBuild appends to a message.</summary>
/// <param name="AText">The message as printed.</param>
/// <returns>The message alone.</returns>
function WithoutProjectSuffix( const AText: string ): string;
begin

  Result := Trim( TRegEx.Replace( AText, '\s*\[[^\[\]]+proj\]\s*$', '', [ roIgnoreCase ] ) );

end;

function ParseBuildLine( const ALine: string; out ADiagnostic: TBuildDiagnostic ): Boolean;
begin

  ADiagnostic := Default( TBuildDiagnostic );
  var sLine   := Trim( ALine );

  // file(line[,col]): [<delphi severity> ]error|warning CODE: message [project]
  // MSBuild reports a Delphi hint as "Hint warning H2077:", so the leading word is stepped over.
  var oMatch := TRegEx.Match( sLine, '^(.+?)\((\d+)(?:,\d+)?\):\s+(?:\w+\s+)?(error|warning)\s+([EWHF]\d+|MSB\d+):\s+(.+)$',
    [ roIgnoreCase ] );

  if oMatch.Success then
  begin
    ADiagnostic.FileName := oMatch.Groups[ 1 ].Value;
    ADiagnostic.Line     := StrToIntDef( oMatch.Groups[ 2 ].Value, 0 );
    ADiagnostic.Code     := UpperCase( oMatch.Groups[ 4 ].Value );
    ADiagnostic.Kind     := KindOf( ADiagnostic.Code, oMatch.Groups[ 3 ].Value );
    ADiagnostic.Text     := WithoutProjectSuffix( oMatch.Groups[ 5 ].Value );
    Exit( True );
  end;

  // A positionless error: an optional "source :" prefix, then "[fatal ]error CODE: message".
  oMatch := TRegEx.Match( sLine, '^(?:(.+?)\s+:\s+)?(?:fatal\s+)?error\s+([A-Za-z]+\d+):\s+(.+)$', [ roIgnoreCase ] );

  if oMatch.Success then
  begin
    ADiagnostic.Code := UpperCase( oMatch.Groups[ 2 ].Value );
    ADiagnostic.Kind := KindOf( ADiagnostic.Code, 'error' );
    if ADiagnostic.Kind in [ dkHint, dkWarning ] then ADiagnostic.Kind := dkError;
    ADiagnostic.Text := WithoutProjectSuffix( oMatch.Groups[ 3 ].Value );
    Exit( True );
  end;

  // A positionless MSBuild warning; limited to MSBnnnn so ordinary chatter starting "warning" is not swept up.
  oMatch := TRegEx.Match( sLine, '^(?:(.+?)\s+:\s+)?warning\s+(MSB\d+):\s+(.+)$', [ roIgnoreCase ] );

  if oMatch.Success then
  begin
    ADiagnostic.Code := UpperCase( oMatch.Groups[ 2 ].Value );
    ADiagnostic.Kind := dkWarning;
    ADiagnostic.Text := WithoutProjectSuffix( oMatch.Groups[ 3 ].Value );
    Exit( True );
  end;

  Result := False;

end;

function ParseBuildOutput( const AOutput: string ): TArray<TBuildDiagnostic>;
begin

  Result := [];

  var oSeen := TDictionary<string, Boolean>.Create;
  try
    for var sLine in AOutput.Split( [ #13#10, #10, #13 ], TStringSplitOptions.ExcludeEmpty ) do
    begin
      var rDiagnostic: TBuildDiagnostic;
      var sKey := Trim( sLine );
      if oSeen.ContainsKey( sKey ) or not ParseBuildLine( sLine, rDiagnostic ) then Continue;
      oSeen.Add( sKey, True );
      Result := Result + [ rDiagnostic ];
    end;
  finally
    oSeen.Free;
  end;

end;

function HasErrors( const ADiagnostics: TArray<TBuildDiagnostic> ): Boolean;
begin

  Result := False;

  for var rDiagnostic in ADiagnostics do
    if rDiagnostic.Kind in [ dkError, dkFatal ] then Exit( True );

end;

{ EurekaLog }

function IsDUnitXRunner( const ADprText: string ): Boolean;
begin

  Result := TRegEx.IsMatch( ADprText, '\bDUnitX\.TestFramework\b', [ roIgnoreCase ] );

end;

function ShouldRunEurekaLog( AEnabled: Boolean; const AConfig: string; AKind: TParallelProjectKind;
  AHasEof, AIsTestRunner: Boolean ): Boolean;
begin

  Result := AEnabled and AHasEof and ( AKind <> pkPackage ) and ( not AIsTestRunner ) and SameText( AConfig, 'Release' );

end;

function EurekaLogProfilePath( const AEofText, AEofPath, AAppDataDir: string ): string;
begin

  var oMatch := TRegEx.Match( AEofText, '^\s*ExternalConfig\s*=\s*(.+?)\s*$', [ roMultiLine, roIgnoreCase ] );

  if not oMatch.Success then Exit( AEofPath );

  var sAppData := ExcludeTrailingPathDelimiter( AAppDataDir );

  Result := oMatch.Groups[ 1 ].Value;
  Result := StringReplace( Result, '%%APPDATA%%', sAppData, [ rfReplaceAll, rfIgnoreCase ] );
  Result := StringReplace( Result, '%APPDATA%', sAppData, [ rfReplaceAll, rfIgnoreCase ] );

  if not IsRootedPath( Result ) then Result := ExpandFileName( ExtractFilePath( AEofPath ) + Result );

end;

function ProjectOutputFile( const ADprojFile, ADprojText, AConfig, APlatform: string; AKind: TParallelProjectKind ): string;
begin

  var sFolder    := ResolveDprojProperty( ADprojText, 'DCC_ExeOutput', AConfig, APlatform );
  var sExtension := '.exe';

  if AKind = pkLibrary then sExtension := '.dll';

  Result := IncludeTrailingPathDelimiter( ResolveProjectFolder( ADprojFile, sFolder ) ) +
    ChangeFileExt( ExtractFileName( ADprojFile ), sExtension );

end;

function DefaultEcc32Path( const AProgramFilesX86, AStudioFolder: string ): string;
begin

  Result := IncludeTrailingPathDelimiter( AProgramFilesX86 ) + 'Neos Eureka S.r.l\EurekaLog 7\Packages\' + AStudioFolder +
    '\ecc32.exe';

end;

{ TParallelSchedule }

constructor TParallelSchedule.Create( const AProjects: TArray<TParallelProject>; AMaxWorkers: Integer );
begin

  inherited Create;

  FProjects   := AProjects;
  FMaxWorkers := Max( AMaxWorkers, 1 );
  SetLength( FStates, Length( FProjects ) );
  SetLength( FSkipReasons, Length( FProjects ) );

end;

function TParallelSchedule.GetState( AIndex: Integer ): TProjectState;
begin

  Result := FStates[ AIndex ];

end;

function TParallelSchedule.GetSkipReason( AIndex: Integer ): string;
begin

  Result := FSkipReasons[ AIndex ];

end;

function TParallelSchedule.CountOf( AState: TProjectState ): Integer;
begin

  Result := 0;

  for var eState in FStates do
    if eState = AState then Inc( Result );

end;

function TParallelSchedule.DependenciesMet( AIndex: Integer ): Boolean;
begin

  Result := True;

  for var iDependency in FProjects[ AIndex ].DependsOn do
    if FStates[ iDependency ] <> psSucceeded then Exit( False );

end;

function TParallelSchedule.LockHeld( AIndex: Integer ): Boolean;
begin

  Result := False;

  for var iI := 0 to High( FProjects ) do
    if ( FStates[ iI ] = psRunning ) and ( FProjects[ iI ].LockKey = FProjects[ AIndex ].LockKey ) then Exit( True );

end;

procedure TParallelSchedule.SkipBlockedProjects;
begin

  var bChanged := True;

  while bChanged do
  begin
    bChanged := False;
    for var iI := 0 to High( FProjects ) do
      if FStates[ iI ] = psWaiting then
        for var iDependency in FProjects[ iI ].DependsOn do
          if FStates[ iDependency ] in [ psFailed, psSkipped ] then
          begin
            FStates[ iI ]      := psSkipped;
            FSkipReasons[ iI ] := 'not built: ' + ChangeFileExt( ExtractFileName( FProjects[ iDependency ].FileName ), '' ) +
              ' did not build';
            bChanged := True;
            Break;
          end;
  end;

end;

function TParallelSchedule.NextToStart: Integer;
begin

  Result := -1;
  SkipBlockedProjects;

  if FRunningCount < FMaxWorkers then
    for var iI := 0 to High( FProjects ) do
      if ( FStates[ iI ] = psWaiting ) and DependenciesMet( iI ) and ( not LockHeld( iI ) ) then
      begin
        FStates[ iI ] := psRunning;
        Inc( FRunningCount );
        Exit( iI );
      end;

  // Nothing is running and nothing can start, yet projects wait: they depend on each other in a circle.
  if FRunningCount = 0 then
    for var iI := 0 to High( FProjects ) do
      if FStates[ iI ] = psWaiting then
      begin
        FStates[ iI ]      := psSkipped;
        FSkipReasons[ iI ] := 'not built: its dependencies form a circle';
      end;

end;

procedure TParallelSchedule.Finished( AIndex: Integer; ASucceeded: Boolean );
begin

  if FStates[ AIndex ] <> psRunning then
    raise EInvalidOpException.CreateFmt( 'Project %d is not running', [ AIndex ] );

  if ASucceeded then
    FStates[ AIndex ] := psSucceeded
  else
    FStates[ AIndex ] := psFailed;

  Dec( FRunningCount );

end;

procedure TParallelSchedule.CancelWaiting( const AReason: string );
begin

  for var iI := 0 to High( FProjects ) do
    if FStates[ iI ] = psWaiting then
    begin
      FStates[ iI ]      := psSkipped;
      FSkipReasons[ iI ] := AReason;
    end;

end;

function TParallelSchedule.Done: Boolean;
begin

  Result := ( FRunningCount = 0 ) and ( CountOf( psWaiting ) = 0 );

end;

end.
