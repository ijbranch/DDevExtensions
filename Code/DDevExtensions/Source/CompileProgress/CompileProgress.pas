{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* Modified: 2026-01-10 - Added style violation tracking                      *}
{*                                                                            *}
{******************************************************************************}

unit CompileProgress;

/// <summary>
/// Core unit of the CompileProgress plug-in. Hooks into the Delphi IDE compile pipeline to
/// display a native progress bar with file count and taskbar progress, optionally release
/// the compiler unit cache of inactive projects, prompt the user when compiling a file
/// from a non-active project, write a "Last Compile" version-info entry, gather per-unit
/// build statistics and run an optional code-style check after the build.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.SyncObjs, Vcl.Menus, Hooking, IDEHooks, ToolsAPI, Vcl.Controls, Vcl.Forms,
  System.Win.Registry, FrmTreePages, IDENotifiers, InterceptIntf, InterceptLoader,
  {$IF CompilerVersion >= 21.0} // Delphi 2010+
  System.Rtti,
  {$IFEND}
  PluginConfig, Vcl.Dialogs;

type
  /// <summary>
  /// Local copy of CodeStyleChecker.TStyleViolation, declared here to avoid a circular
  /// dependency between CompileProgress and CodeStyleChecker. Describes one detected
  /// coding-style violation in a Delphi source file.
  /// </summary>
  // Local copy of TStyleViolation to avoid circular dependency with CodeStyleChecker
  TStyleViolation = record
    /// <summary>Absolute file name where the violation was detected.</summary>
    FileName: string;
    /// <summary>Unit name ( file name without extension ) where the violation was detected.</summary>
    UnitName: string;
    /// <summary>1-based line number of the violation.</summary>
    Line: Integer;
    /// <summary>1-based column number of the violation.</summary>
    Column: Integer;
    /// <summary>Identifier of the rule that was violated.</summary>
    Rule: string;
    /// <summary>What the rule expected to see.</summary>
    Expected: string;
    /// <summary>What was actually found in the source.</summary>
    Actual: string;
    /// <summary>Severity label ( e.g. "Warning", "Error" ).</summary>
    Severity: string;
    /// <summary>Category of the violation: "NamingConvention" or "AntiPattern".</summary>
    Category: string;  // 'NamingConvention' or 'AntiPattern'
  end;

  /// <summary>
  /// Per-unit timing record captured during a project build.
  /// </summary>
  TBuildUnitInfo = record
    /// <summary>Unit name ( file name without extension ).</summary>
    UnitName: string;
    /// <summary>Source file name ( may be a relative path until resolved ).</summary>
    FileName: string;
    /// <summary>Time the compiler began processing this unit.</summary>
    StartTime: TDateTime;
    /// <summary>Time the compiler finished processing this unit.</summary>
    EndTime: TDateTime;
    /// <summary>Duration in milliseconds.</summary>
    DurationMs: Int64;
    /// <summary>Lines of code calculated for this unit ( populated by the metrics pass ).</summary>
    LinesOfCode: Integer;
    /// <summary>Cyclomatic complexity calculated for this unit ( populated by the metrics pass ).</summary>
    CyclomaticComplexity: Integer;
  end;

  /// <summary>
  /// Thread-safe accumulator for per-unit build statistics. Used by TCompileProgress to
  /// record timings during a compile and by TFormBuildStatistics to display them.
  /// </summary>
  TBuildStatistics = class
  private
    /// <summary>Backing storage for unit info; may be over-allocated and trimmed on FinalizeBuild.</summary>
    FUnits: TArray<TBuildUnitInfo>;
    /// <summary>Number of valid entries in FUnits.</summary>
    FUnitCount: Integer;
    /// <summary>Name of the unit currently being timed; empty when no unit is active.</summary>
    FCurrentUnit: string;
    /// <summary>Start time of the unit currently being timed.</summary>
    FCurrentStartTime: TDateTime;
    /// <summary>Sum of all per-unit DurationMs values.</summary>
    FTotalBuildTime: Int64;
    /// <summary>True when the most recent build succeeded.</summary>
    FBuildSucceeded: Boolean;
    /// <summary>Path of the first project compiled, used to resolve relative file names.</summary>
    FProjectPath: string;
    /// <summary>Sorted list of project file names ( upper-case, no path ) used by IsProjectFile.</summary>
    FProjectFiles: TStringList;
    /// <summary>Critical section guarding all mutable state.</summary>
    FLock: TCriticalSection;
    /// <summary>Style violations collected by the optional post-build style checker.</summary>
    FStyleViolations: TArray<TStyleViolation>;
    /// <summary>Closes off the timing of the current unit; must be called while holding FLock.</summary>
    procedure DoEndCurrentUnit; // Internal - must be called while holding FLock
  public
    /// <summary>Creates the statistics container with an empty unit list.</summary>
    constructor Create;
    /// <summary>Releases all resources held by the container.</summary>
    destructor Destroy; override;
    /// <summary>Clears all collected statistics in preparation for a new build.</summary>
    procedure Clear;
    /// <summary>Records the start of compilation for a unit.</summary>
    /// <param name="UnitName">Unit name without extension.</param>
    /// <param name="FileName">Full path to the source file.</param>
    procedure StartUnit(const UnitName, FileName: string);
    /// <summary>Records the end of compilation for the unit currently being timed.</summary>
    procedure EndCurrentUnit;
    /// <summary>Finalises the build by closing any open unit, recording the result and trimming the array.</summary>
    /// <param name="Succeeded">True when the compile succeeded.</param>
    procedure FinalizeBuild(Succeeded: Boolean);
    /// <summary>Adds a file to the project-files filter list ( stored upper-cased without path ).</summary>
    /// <param name="FileName">File name to register as belonging to the project.</param>
    procedure AddProjectFile(const FileName: string);
    /// <summary>Returns True when FileName matches an entry registered with AddProjectFile.</summary>
    /// <param name="FileName">File name to test.</param>
    /// <returns>True for project files; True for all files if none have been registered.</returns>
    function IsProjectFile(const FileName: string): Boolean;
    /// <summary>Returns a thread-safe snapshot of the recorded unit information.</summary>
    function GetUnits: TArray<TBuildUnitInfo>;
    /// <summary>Stores the supplied violations as a copy under the lock.</summary>
    /// <param name="Violations">Violations produced by the style checker.</param>
    procedure SetStyleViolations( const Violations: TArray<TStyleViolation> );
    /// <summary>Returns a thread-safe snapshot of the recorded style violations.</summary>
    function GetStyleViolations: TArray<TStyleViolation>;
    /// <summary>Total milliseconds across all units in the most recent build.</summary>
    property TotalBuildTime: Int64 read FTotalBuildTime;
    /// <summary>Result of the most recent build.</summary>
    property BuildSucceeded: Boolean read FBuildSucceeded;
    /// <summary>Number of units recorded for the most recent build.</summary>
    property UnitCount: Integer read FUnitCount;
    /// <summary>Path used to resolve relative file names returned by the compiler.</summary>
    property ProjectPath: string read FProjectPath write FProjectPath;
    /// <summary>Style violations gathered by the post-build style checker.</summary>
    property StyleViolations: TArray<TStyleViolation> read GetStyleViolations write SetStyleViolations;
  end;

  /// <summary>
  /// Plug-in configuration object that owns the CompileProgress feature. Implements
  /// ICompileInterceptor to receive compile-time file events and exposes the user
  /// settings that drive the various sub-features.
  /// </summary>
  TCompileProgress = class(TPluginConfig, ICompileInterceptor)
  private
    /// <summary>Identifier returned by the compile-interceptor service registration.</summary>
    FCompileInterceptorId: Integer;
    /// <summary>IDE notifier that delivers Before/AfterCompile callbacks.</summary>
    FIDENotifier: TIDENotifier;
    /// <summary>List of .pas/.dcu file names expected during the current build, used to update the progress bar.</summary>
    FPasFiles: TStrings;
    /// <summary>Critical section that protects FPasFiles ( retained for legacy use; see implementation ).</summary>
    FPasFilesLock: TCriticalSection;
    /// <summary>Backing field for ReleaseCompilerUnitCache.</summary>
    FReleaseCompilerUnitCache: Boolean;
    /// <summary>Backing field for ReleaseCompilerUnitCacheHigh.</summary>
    FReleaseCompilerUnitCacheHigh: Boolean;
    /// <summary>Backing field for AutoSaveAfterSuccessfulCompile.</summary>
    FAutoSaveAfterSuccessfulCompile: Boolean;
    {$IF CompilerVersion < 23.0} // XE2+ changed how version info works
    /// <summary>Backing field for LastCompileVersionInfo ( pre-XE2 only ).</summary>
    FLastCompileVersionInfo: Boolean;
    /// <summary>Backing field for LastCompileVersionInfoFormat ( pre-XE2 only ).</summary>
    FLastCompileVersionInfoFormat: string;
    {$IFEND}
    /// <summary>Backing field for AskCompileFromDiffProject.</summary>
    FAskCompileFromDiffProject: Boolean;
    /// <summary>Backing field for AskCompileFromDiffProjectTemporary.</summary>
    FAskCompileFromDiffProjectTemporary: Boolean;
    /// <summary>Backing field for EnableBuildStatistics.</summary>
    FEnableBuildStatistics: Boolean;
    /// <summary>Backing field for ShowBuildStatisticsAfterCompile.</summary>
    FShowBuildStatisticsAfterCompile: Boolean;
    /// <summary>Backing field for RunStyleCheckAfterCompile.</summary>
    FRunStyleCheckAfterCompile: Boolean;
    /// <summary>Build statistics container populated during compiles.</summary>
    FBuildStatistics: TBuildStatistics;
    /// <summary>Tools menu item that opens the Build Statistics dialog on demand.</summary>
    FBuildStatsMenuItem: TMenuItem;
    {$IF CompilerVersion < 23.0} // XE2+ changed how version info works
    /// <summary>Writes a "Last Compile" key into the project version info ( pre-XE2 only ).</summary>
    /// <param name="Project">Project to update.</param>
    procedure UpdateLastCompileVersionInfo(const Project: IOTAProject);
    {$IFEND}
    /// <summary>Setter for AskCompileFromDiffProject.</summary>
    procedure SetAskCompileFromDiffProject(const Value: Boolean);
    /// <summary>Increments the progress bar from the main thread ( queued from worker threads ).</summary>
    procedure UpdateInMainThread;
    /// <summary>Setter for ReleaseCompilerUnitCache; updates the active hook.</summary>
    procedure SetReleaseCompilerUnitCache(const Value: Boolean);
    /// <summary>Setter for ReleaseCompilerUnitCacheHigh; updates the active hook.</summary>
    procedure SetReleaseCompilerUnitCacheHigh(const Value: Boolean);
    /// <summary>Setter for EnableBuildStatistics; toggles the menu item visibility.</summary>
    procedure SetEnableBuildStatistics(const Value: Boolean);
    /// <summary>Shows the singleton Build Statistics dialog.</summary>
    procedure ShowBuildStatisticsDialog;
    /// <summary>Click handler for the Build Statistics menu item.</summary>
    procedure BuildStatsMenuItemClick(Sender: TObject);
  {$IF CompilerVersion < 22.0} // XE has its own option
  private
    /// <summary>Backing field for DisableRebuildDlg ( pre-XE only ).</summary>
    FDisableRebuildDlg: Boolean;
    /// <summary>Address of the patched code in the IDE binary used to suppress the rebuild dialog.</summary>
    FRebuildAddress: Pointer;
    /// <summary>Original bytes preserved at FRebuildAddress so the patch can be reversed.</summary>
    FRebuildOrgBytes: array[0..2] of Byte;
    /// <summary>Setter for DisableRebuildDlg; applies or reverses the in-memory patch.</summary>
    procedure SetDisableRebuildDlg(const Value: Boolean);
  {$IFEND}
  protected
    /// <summary>IDE callback invoked after every compile; finalises statistics, runs style checks, auto-saves, etc.</summary>
    /// <param name="Project">Project that was compiled.</param>
    /// <param name="Succeeded">True if the compile succeeded.</param>
    /// <param name="IsCodeInsight">True if this is a Code Insight background compile.</param>
    procedure AfterCompile(const Project: IOTAProject; Succeeded: Boolean; IsCodeInsight: Boolean);
    /// <summary>IDE callback invoked before every compile; primes the progress bar and statistics.</summary>
    /// <param name="Project">Project about to be compiled.</param>
    /// <param name="IsCodeInsight">True if this is a Code Insight background compile.</param>
    /// <param name="Cancel">Set to True to cancel the compile.</param>
    procedure BeforeCompile(const Project: IOTAProject; IsCodeInsight: Boolean; var Cancel: Boolean);
  protected
    /// <summary>Returns the options-tree page used to edit this plug-in's settings.</summary>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises default values when the configuration object is first created.</summary>
    procedure Init; override;

    { ICompileInterceptor }
    /// <summary>Returns the set of compile-interceptor features required by this plug-in.</summary>
    function GetOptions: TCompileInterceptOptions; stdcall;
    /// <summary>ICompileInterceptor: returns a virtual replacement for Filename, or nil for none.</summary>
    function GetVirtualFile(Filename: PWideChar): IVirtualStream; stdcall;
    /// <summary>ICompileInterceptor: optionally returns altered file content; this plug-in returns nil.</summary>
    function AlterFile(Filename: PWideChar; Content: PByte; FileDate, FileSize: Integer): IVirtualStream; stdcall;
    /// <summary>ICompileInterceptor: receives notifications when the compiler opens or closes a file.</summary>
    /// <param name="Filename">File being inspected.</param>
    /// <param name="FileMode">Whether the file was opened or closed.</param>
    procedure InspectFilename(Filename: PWideChar; FileMode: TInspectFileMode); stdcall;
    /// <summary>ICompileInterceptor: optionally rewrites compiler messages; this plug-in does not.</summary>
    function AlterMessage(IsCompilerMessage: Boolean; var MsgKind: TMsgKind;
      var Code: Integer; const Filename: IWideString; var Line, Column: Integer;
      const Msg: IWideString): Boolean; stdcall;
    /// <summary>ICompileInterceptor: invoked when the compiler starts work on a project; not used by this plug-in.</summary>
    procedure CompileProject(ProjectFilename: PWideChar; UnitPaths: PWideChar;
      SourcePaths: PWideChar; DcuOutputDir: PWideChar; IsCodeInsight: Boolean;
      var Cancel: Boolean); stdcall;
  public
    /// <summary>Constructs the plug-in, registers IDE notifiers, the compile interceptor and the menu item.</summary>
    constructor Create;
    /// <summary>Releases all resources, unregisters notifiers and removes the menu item.</summary>
    destructor Destroy; override;
    /// <summary>Build statistics container populated during compiles.</summary>
    property BuildStatistics: TBuildStatistics read FBuildStatistics;
  published
    /// <summary>When True the cache of inactive projects is released after every compile to recover memory.</summary>
    property ReleaseCompilerUnitCache: Boolean read FReleaseCompilerUnitCache write SetReleaseCompilerUnitCache;
    /// <summary>When True ReleaseCompilerUnitCache is restricted to high memory-pressure situations.</summary>
    property ReleaseCompilerUnitCacheHigh: Boolean read FReleaseCompilerUnitCacheHigh write SetReleaseCompilerUnitCacheHigh;
    {$IF CompilerVersion < 22.0} // XE has its own option
    /// <summary>Suppresses the IDE "Rebuild required" dialog ( pre-XE only ).</summary>
    property DisableRebuildDlg: Boolean read FDisableRebuildDlg write SetDisableRebuildDlg;
    {$IFEND}
    /// <summary>When True all modified files are saved automatically after a successful compile.</summary>
    property AutoSaveAfterSuccessfulCompile: Boolean read FAutoSaveAfterSuccessfulCompile write FAutoSaveAfterSuccessfulCompile;
    {$IF CompilerVersion < 23.0} // XE2+ changed how version info works
    /// <summary>When True a "Last Compile" version-info entry is written before every compile ( pre-XE2 only ).</summary>
    property LastCompileVersionInfo: Boolean read FLastCompileVersionInfo write FLastCompileVersionInfo;
    /// <summary>FormatDateTime mask used for the "Last Compile" version-info entry ( pre-XE2 only ).</summary>
    property LastCompileVersionInfoFormat: string read FLastCompileVersionInfoFormat write FLastCompileVersionInfoFormat;
    {$IFEND}
    /// <summary>When True the user is asked before compiling a file from a non-active project.</summary>
    property AskCompileFromDiffProject: Boolean read FAskCompileFromDiffProject write SetAskCompileFromDiffProject;
    /// <summary>Initial value for the "temporary switch" check box of the switch-project dialog.</summary>
    property AskCompileFromDiffProjectTemporary: Boolean read FAskCompileFromDiffProjectTemporary write FAskCompileFromDiffProjectTemporary;
    /// <summary>When True per-unit build statistics are collected during every compile.</summary>
    property EnableBuildStatistics: Boolean read FEnableBuildStatistics write SetEnableBuildStatistics;
    /// <summary>When True the Build Statistics dialog is shown automatically after each compile.</summary>
    property ShowBuildStatisticsAfterCompile: Boolean read FShowBuildStatisticsAfterCompile write FShowBuildStatisticsAfterCompile;
    /// <summary>When True the code-style checker is run after each successful compile.</summary>
    property RunStyleCheckAfterCompile: Boolean read FRunStyleCheckAfterCompile write FRunStyleCheckAfterCompile;
  end;

/// <summary>
/// Initialises or shuts down the CompileProgress plug-in. Hooks the IDE compile entry
/// points and creates the global TCompileProgress instance when Unload is False; restores
/// the original code and frees the instance when Unload is True.
/// </summary>
/// <param name="Unload">False to load the plug-in, True to unload it.</param>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  Main, NativeProgressForm, AppConsts, IDEUtils,
  FrmeOptionPageCompilerProgress, ProjectResource, UnitVersionInfo, ToolsAPIHelpers,
  FrmSwitchToModuleProject, CompilerClearOtherStates, FrmBuildStatistics,
  CodeStyleChecker;

function TimeStr(dt: TDateTime; Exact: Boolean = False): string;
var
  ms: Cardinal;
  h, m, s: Integer;
  nms: Int64;
begin
  Result := '';
  if Int(dt) > 0 then
    Result := IntToStr(Trunc(dt)) + ' d ';
  nms := Round(Frac(dt) * MSecsPerDay);

  ms := nms div 1000;
  h := ms div 3600;
  ms := ms mod 3600;
  m := ms div 60;
  s := ms mod 60;

  Result := '';
  if h > 0 then
    Result := Result + IntToStr(h) + 'h ';
  if (m > 0) or (h > 0) then
  begin
    {if (h > 0) and (m < 10) then
      Result := Result + '0';}
    Result := Result + IntToStr(m) + 'm ';
  end;
  {if (m > 0) or (h > 0) and (s < 10) then
    Result := Result + '0';}
  if Exact and (h = 0) and (m = 0) then
    Result := Result + Format('%1.2f', [s + (nms mod 1000)/1000]) + 's'
  else
    Result := Result + IntToStr(s) + 's';
end;

{ TBuildStatistics }

constructor TBuildStatistics.Create;
begin

  inherited Create;
  FLock := TCriticalSection.Create;
  FProjectFiles := TStringList.Create;
  FProjectFiles.CaseSensitive := False;
  FProjectFiles.Sorted := True;
  FProjectFiles.Duplicates := dupIgnore;

end;

destructor TBuildStatistics.Destroy;
begin

  FProjectFiles.Free;
  FLock.Free;
  inherited Destroy;

end;

procedure TBuildStatistics.Clear;
begin

  FLock.Enter;

  try
    SetLength( FUnits, 0 );
    SetLength( FStyleViolations, 0 );
    FUnitCount        := 0;
    FCurrentUnit      := '';
    FCurrentStartTime := 0;
    FTotalBuildTime   := 0;
    FBuildSucceeded   := False;
    FProjectPath      := '';
    FProjectFiles.Clear;
  finally
    FLock.Leave;
  end;

end;

procedure TBuildStatistics.AddProjectFile(const FileName: string);
begin

  FLock.Enter;

  try
    // Store just the filename (without path) for reliable matching
    FProjectFiles.Add(AnsiUpperCase(ExtractFileName(FileName)));
  finally
    FLock.Leave;
  end;

end;

function TBuildStatistics.IsProjectFile(const FileName: string): Boolean;
begin

  FLock.Enter;

  try
    // If no project files were added, consider all files as project files
    if FProjectFiles.Count = 0 then
      Result := True
    else
      // Compare by filename only (without path) for reliable matching
      Result := FProjectFiles.IndexOf(AnsiUpperCase(ExtractFileName(FileName))) >= 0;
  finally
    FLock.Leave;
  end;

end;

procedure TBuildStatistics.DoEndCurrentUnit;
// Internal method - must be called while holding FLock
var
  EndTime: TDateTime;
  DurationMs: Int64;
begin

  if ( FCurrentUnit <> '' ) and ( FUnitCount > 0 ) then
  begin
    EndTime    := Now;
    DurationMs := Round( ( EndTime - FCurrentStartTime ) * MSecsPerDay );
    FUnits[ FUnitCount - 1 ].EndTime    := EndTime;
    FUnits[ FUnitCount - 1 ].DurationMs := DurationMs;
    FTotalBuildTime := FTotalBuildTime + DurationMs;
    FCurrentUnit    := '';
  end;

end;

procedure TBuildStatistics.StartUnit( const UnitName, FileName: string );
begin

  FLock.Enter;

  try
    // End the previous unit if one was being tracked
    if FCurrentUnit <> '' then
      DoEndCurrentUnit;

    FCurrentUnit      := UnitName;
    FCurrentStartTime := Now;

    // Expand array if needed
    if FUnitCount >= Length( FUnits ) then
      SetLength( FUnits, FUnitCount + 64 );

    FUnits[ FUnitCount ].UnitName   := UnitName;
    FUnits[ FUnitCount ].FileName   := FileName;
    FUnits[ FUnitCount ].StartTime  := FCurrentStartTime;
    FUnits[ FUnitCount ].EndTime    := 0;
    FUnits[ FUnitCount ].DurationMs := 0;
    Inc( FUnitCount );
  finally
    FLock.Leave;
  end;

end;

procedure TBuildStatistics.EndCurrentUnit;
begin

  FLock.Enter;

  try
    DoEndCurrentUnit;
  finally
    FLock.Leave;
  end;

end;

procedure TBuildStatistics.FinalizeBuild( Succeeded: Boolean );
begin

  FLock.Enter;

  try
    // End the last unit if still being tracked
    if FCurrentUnit <> '' then
      DoEndCurrentUnit;

    FBuildSucceeded := Succeeded;
    // Trim the array to actual size
    SetLength( FUnits, FUnitCount );
  finally
    FLock.Leave;
  end;

end;

function TBuildStatistics.GetUnits: TArray<TBuildUnitInfo>;
begin

  FLock.Enter;

  try
    Result := Copy( FUnits, 0, FUnitCount );
  finally
    FLock.Leave;
  end;

end;

function TBuildStatistics.GetStyleViolations: TArray<TStyleViolation>;
begin

  FLock.Enter;

  try
    Result := Copy( FStyleViolations );
  finally
    FLock.Leave;
  end;

end;

procedure TBuildStatistics.SetStyleViolations( const Violations: TArray<TStyleViolation> );
begin

  FLock.Enter;

  try
    FStyleViolations := Copy( Violations );
  finally
    FLock.Leave;
  end;

end;

var
  OrgStartCompile, OrgCallStartCompile: procedure(Inst: TObject); register;
  GlobalCompileProgress: TCompileProgress;

procedure HookedStartCompile(Inst: TForm);
var
  t: TDateTime;
begin
  {$IF CompilerVersion >= 21.0} // Delphi 2010+
  // Delphi 2010+ call StartCompile once, which then calls BeforeCompile for each project.
  // Older Delphi versions call BeforeCompile, then StartCompile for the first project.
  // BeforeCompile, then StartCompile for the second project, ...
  if GlobalCompileProgress <> nil then
  begin
    TStringList(GlobalCompileProgress.FPasFiles).Sorted := False;
    GlobalCompileProgress.FPasFiles.Clear;
  end;
  {$IFEND}

  if FormNativeProgress <> nil then
    FormNativeProgress.ShowProgressBar(True);
  t := Now;
  try
    OrgCallStartCompile(Inst);
  finally
    t := Now - t;
    if GlobalCompileProgress <> nil then
      GlobalCompileProgress.FPasFiles.Clear;
  end;

  if FormNativeProgress <> nil then
  begin
    FormNativeProgress.ProjectFilesCompiled := FormNativeProgress.MaxFiles;
    if FormNativeProgress <> nil then
      FormNativeProgress.ShowProgressBar(False);

    FormNativeProgress.CurrFile := FormNativeProgress.CurrFile  + '     Time: ' + TimeStr(t);
  end;
end;

type
  TCompileMode = (cmMake, cmBuild, cmCheck, cmKibitz, cmClean, cmLink); // I really start to love the new RTTI :-)

{$IF CompilerVersion >= 21.0} // Delphi 2010+
var
  OrgProjectGroupCompileActive, OrgCallProjectGroupCompileActive: function(Instance: TObject; CompileMode: TCompileMode; Wait: Boolean): Boolean;
  OrgAppBuilderCompile: Pointer;

{$IFDEF CPUX86}
procedure HookedProjectGroupCompileActive;
  forward;
{$ELSE}
function HookedProjectGroupCompileActive(Instance: TObject; CompileMode: TCompileMode; Wait: Boolean): Boolean;
  forward;
{$ENDIF}

function CallOrgProjectGroupCompileActive(Instance: TObject; CompileMode: TCompileMode; Wait: Boolean): Boolean;
begin
  { Compile/Build/Check/... }
  Result := OrgCallProjectGroupCompileActive(Instance, CompileMode, Wait);
end;
{$ELSE}
var
  OrgCompileActiveProject, OrgCallCompileActiveProject: function(Instance: TObject; CompileMode: TCompileMode; Wait: Boolean): Boolean;

function CompileActiveProject(Instance: TObject; CompileMode: TCompileMode; Wait: Boolean): Boolean;
  forward;

function CallOrgProjectGroupCompileActive(Instance: TObject; CompileMode: TCompileMode; Wait: Boolean): Boolean;
begin
  { Compile/Build/Check/... }
  Result := OrgCallCompileActiveProject(Instance, CompileMode, Wait);
end;
{$IFEND}

function CompileActiveProject(Instance: TObject; CompileMode: TCompileMode; Wait: Boolean): Boolean;

  procedure CollectDependencies(const Dependencies: IOTAProjectGroupProjectDependencies;
    const DependentProjects: TInterfaceList; const Project: IOTAProject);
  var
    List: IOTAProjectDependenciesList;
    Prj: IOTAProject;
    I: Integer;
  begin
    DependentProjects.Add(Project);
    List := Dependencies.GetProjectDependencies(Project);
    for I := 0 to List.ProjectCount - 1 do
    begin
      Prj := List.Projects[I];
      if DependentProjects.IndexOf(Prj) = -1 then
        CollectDependencies(Dependencies, DependentProjects, Prj);
    end;
  end;

const
  sOptAutoCloseProgressDlg = 'AutoCloseProgressDlg';
var
  Module: IOTAModule;
  Project, ActiveProject: IOTAProject;
  I: Integer;
  Found: Boolean;
  Dependencies: IOTAProjectGroupProjectDependencies;
  ModuleServices: IOTAModuleServices;
  Services: IOTAServices;
  DependentProjects: TInterfaceList;
  DontShowAgain: Boolean;
  AutoClose, ConfigModified: Boolean;
begin
  if (GlobalCompileProgress <> nil) and GlobalCompileProgress.AskCompileFromDiffProject then
  begin
    ModuleServices :=  BorlandIDEServices as IOTAModuleServices;
    Services := BorlandIDEServices as IOTAServices;
    Module := ModuleServices.CurrentModule;
    if (Module <> nil) and (Module.OwnerCount > 0) then
    begin
      ActiveProject := GetActiveProject;
      Project := ActiveProject;
      if Project <> nil then
      begin
        Found := False;
        { Check if one of the module's projects is the active project }
        for I := 0 to Module.OwnerCount - 1 do
        begin
          if Module.Owners[I] = Project then
          begin
            Found := True;
            Break;
          end;
        end;

        { Check if one of the module's projects is in the active project's dependency tree }
        if not Found then
        begin
          if Supports(ModuleServices.GetMainProjectGroup, IOTAProjectGroupProjectDependencies, Dependencies) then
          begin
            DependentProjects := TInterfaceList.Create;
            try
              { Obtain all projects on which the active project depend }
              CollectDependencies(Dependencies, DependentProjects, Project);
              Found := False;
              for I := 0 to Module.OwnerCount - 1 do
              begin
                { Either the module's project is the active project or it is }
                if DependentProjects.IndexOf(Module.Owners[I]) <> -1 then
                begin
                  Found := True;
                  Break;
                end;
              end;
            finally
              DependentProjects.Free;
            end;
          end;
        end;

        { Ask the user to switch the project }
        if not Found then
        begin
          ConfigModified := False;
          try
            case TFormSwitchToModuleProject.ShowDialog(Module, Project, DontShowAgain,
                                                       GlobalCompileProgress.AskCompileFromDiffProjectTemporary) of
              mrYes:
                begin
                  ModuleServices.GetMainProjectGroup.ActiveProject := Project;
                  if GlobalCompileProgress.AskCompileFromDiffProjectTemporary then
                  begin
                    GlobalCompileProgress.AskCompileFromDiffProjectTemporary := False;
                    ConfigModified := True;
                  end;
                end;
              mrRetry:
                begin
                  ModuleServices.GetMainProjectGroup.ActiveProject := Project;

                  // Variant -> Boolean via a value comparison; a hard Boolean()
                  // cast can read the wrong value depending on the variant type.
                  AutoClose := Services.GetEnvironmentOptions.Values[sOptAutoCloseProgressDlg] = True;
                  { Compile/Build/Check/... the module's project. The active-project
                    restore is in an outer finally so a compile that raises cannot
                    leave the IDE pointing at the wrong active project. }
                  try
                    {$IF CompilerVersion >= 21.0} // Delphi 2010+
                    try
                      if not AutoClose then
                        Services.GetEnvironmentOptions.Values[sOptAutoCloseProgressDlg] := True;
                      Result := OrgCallProjectGroupCompileActive(Instance, CompileMode, Wait);
                    finally
                      if not AutoClose then
                        Services.GetEnvironmentOptions.Values[sOptAutoCloseProgressDlg] := False;
                    end;
                    {$ELSE}
                    try
                      if not AutoClose then
                        Services.GetEnvironmentOptions.Values[sOptAutoCloseProgressDlg] := True;
                      Result := OrgCallCompileActiveProject(Instance, CompileMode, Wait);
                    finally
                      if not AutoClose then
                        Services.GetEnvironmentOptions.Values[sOptAutoCloseProgressDlg] := False;
                    end;
                    {$IFEND}
                  finally
                    { Restore the last active project so it is also compiled }
                    ModuleServices.GetMainProjectGroup.ActiveProject := ActiveProject;
                  end;

                  if not GlobalCompileProgress.AskCompileFromDiffProjectTemporary then
                  begin
                    GlobalCompileProgress.AskCompileFromDiffProjectTemporary := True;
                    ConfigModified := True;
                  end;

                  if not Result then
                    Exit;
                end;
              mrCancel:
                Exit(False);
            end;
            if DontShowAgain then
            begin
              GlobalCompileProgress.AskCompileFromDiffProject := False;
              ConfigModified := True;
            end;

          finally
            if ConfigModified then
              GlobalCompileProgress.Save;
          end;
        end;
      end;
    end;
  end;
  Result := CallOrgProjectGroupCompileActive(Instance, CompileMode, Wait);
end;

{$IF CompilerVersion >= 21.0} // Delphi 2010+
{$IFDEF CPUX86}
procedure HookedProjectGroupCompileActive;
asm
  // Only show the dialog if we are called by TAppBuilder.Compile()
  push eax
  mov eax, [esp+8] // ret-addr
  {$IF CompilerVersion >= 25.0}
  // Read through the CopyProtection Obfuscation (XE6 Update 1)
  cmp BYTE PTR [eax], $E9  // jmp DwordOffset
  jne @@Simple
  cmp BYTE PTR [eax - 3], $FF // call [ebx+ByteOffset]
  jne @@Simple
  add eax, DWORD PTR [eax + 1]
@@Simple:
  {$IFEND}
  sub eax, 5 // call instruction size
  sub eax, OrgAppBuilderCompile // eax = difference between TAppBuilder.Compile and the return address
  jns @@Compare                 // eax was smaller than TAppBuilder.Compile => use abs()
  neg eax
@@Compare:
  cmp eax, 30                   // We can be called from TAppBuilder.Compile() within 30 bytes
  pop eax

  jb CompileActiveProject
  jmp CallOrgProjectGroupCompileActive
end;
{$ELSE}
function HookedProjectGroupCompileActive(Instance: TObject; CompileMode: TCompileMode; Wait: Boolean): Boolean;
begin
  // Win64: the x86 caller-detection trick (inspecting the return address against
  // TAppBuilder.Compile via stack/eax) does not translate to x64 reliably, so always
  // route through the enhanced compile-active-project handler.
  Result := CompileActiveProject(Instance, CompileMode, Wait);
end;
{$ENDIF}

procedure InitPlugin(Unload: Boolean);
// We can't hook into bds.exe because the copy protection will catch us. So we need to go a different
// way than what we used to do in Delphi 2009.
const
  StartCompileSymbol = '@Comprgrs@TProgressForm@StartCompile$qqrv';
  ProjectGroupCompileActiveSymbol = '@Projectgroup@TProjectGroup@CompileActive$qqr21Compintf@TCompileModeo';
var
  Ctx: TRttiContext;
  MainType: TRttiType;
  CompileMethod: TRttiMethod;
  coreideLib: THandle;
begin
  if not Unload then
  begin
    GlobalCompileProgress := TCompileProgress.Create;
    coreideLib := GetModuleHandle(coreide_bpl);

    @OrgStartCompile := DbgStrictGetProcAddress(coreideLib, StartCompileSymbol);
    if Assigned(OrgStartCompile) then
      @OrgCallStartCompile := RedirectOrgCall(@OrgStartCompile, @HookedStartCompile);

    @OrgProjectGroupCompileActive := DbgStrictGetProcAddress(coreideLib, ProjectGroupCompileActiveSymbol);
    if Assigned(OrgProjectGroupCompileActive) then
      @OrgCallProjectGroupCompileActive := RedirectOrgCall(@OrgProjectGroupCompileActive, @HookedProjectGroupCompileActive);

    { Get "TAppBuilder.Compile" method address }
    Ctx := TRttiContext.Create;
    try
      MainType := Ctx.GetType(Application.MainForm.ClassInfo);
      if MainType <> nil then
      begin
        CompileMethod := MainType.GetMethod('Compile');
        if CompileMethod <> nil then
          OrgAppBuilderCompile := CompileMethod.CodeAddress;
      end;
    finally
      Ctx.Free;
    end;
  end
  else
  begin
    RestoreOrgCall(@OrgStartCompile, @OrgCallStartCompile);
    RestoreOrgCall(@OrgProjectGroupCompileActive, @OrgCallProjectGroupCompileActive);
    GlobalCompileProgress.Free;
  end;
end;
{$IFEND}

{$IF CompilerVersion < 21.0} // Delphi 2009
procedure InitPlugin(Unload: Boolean);
const
  ProjectMakeCode: array[0..29] of SmallInt = (
    $53,                                    // push ebx
    $8B, $D8,                               // mov ebx,eax
    $8B, $C3,                               // mov eax,ebx
    $E8, -1, -1, -1, -1,                    // call $00420f60
    $C6, $83, $74, $08, $00, $00, $0B,      // mov byte ptr [ebx+$00000874],$0b
    $B1, $01,                               // mov cl,$01
    $33, $D2,                               // xor edx,edx
    $8B, $C3,                               // mov eax,ebx
    $E8, -1, -1, -1, -1, // <<              // call $004191fc
    $5B,                                    // pop ebx
    $C3                                     // ret
  );

  StartCompileSymbol = '@Comprgrs@TProgressForm@StartCompile$qqrv';
var
  coreideLib: THandle;
  P: PByteArray;
begin
  if not Unload then
  begin
    GlobalCompileProgress := TCompileProgress.Create;
    coreideLib := GetModuleHandle(coreide_bpl);

    @OrgStartCompile := DbgStrictGetProcAddress(coreideLib, StartCompileSymbol);
    if Assigned(OrgStartCompile) then
      @OrgCallStartCompile := RedirectOrgCall(@OrgStartCompile, @HookedStartCompile);

    { Hook "TAppBuilder.Compile" method }
    P := Application.MainForm.MethodAddress('ProjectMake');
    if P <> nil then
    begin
      if FindMethodPtr(Cardinal(P), ProjectMakeCode, 1) <> nil then
      begin
        if P[23] = $E8 then // a last check for changes in ProjectMakeCode
        begin
          @OrgCompileActiveProject := Pointer(INT_PTR(@P[23 + 5]) + PInteger(@P[24])^);
          if Assigned(OrgCompileActiveProject) then
            @OrgCallCompileActiveProject := RedirectOrgCall(@OrgCompileActiveProject, @CompileActiveProject);
        end;
      end;
    end;
  end
  else
  begin
    RestoreOrgCall(@OrgStartCompile, @OrgCallStartCompile);
    RestoreOrgCall(@OrgCompileActiveProject, @OrgCallCompileActiveProject);
    GlobalCompileProgress.Free;
  end;
end;
{$IFEND}

{ TCompileProgress }

constructor TCompileProgress.Create;
var
  MenuItem: TMenuItem;
begin
  inherited Create(AppDataDirectory + '\CompileProgress.xml', 'CompileProgress');
  FPasFiles := TStringList.Create;
  FPasFilesLock := TCriticalSection.Create;
  FBuildStatistics := TBuildStatistics.Create;
  FormNativeProgress := TNativeProgressForm.Create;

  FIDENotifier := TIDENotifier.Create;
  FIDENotifier.OnBeforeCompile := BeforeCompile;
  FIDENotifier.OnAfterCompile := AfterCompile;

  {$IFNDEF CPUX64}
  // Win64: CompileInterceptorWx64.dll's TPascalComInOut callback-table patch
  // rewrites 8-byte function pointers as 4-byte (Cardinal arithmetic) — keep
  // RegisterInterceptor off until/unless that's redesigned. The Win64
  // CompileInterceptor is currently a no-op (InitCompileInterceptor early-exits).
  FCompileInterceptorId := GetCompileInterceptorServices.RegisterInterceptor(Self);
  {$ENDIF}

  // Add Build Statistics menu item under Tools menu
  MenuItem := FindMenuItem( 'ToolsMenu' );

  if MenuItem <> nil then
  begin
    FBuildStatsMenuItem         := TMenuItem.Create( MenuItem );
    FBuildStatsMenuItem.Caption := 'Build &Statistics...';
    FBuildStatsMenuItem.OnClick := BuildStatsMenuItemClick;
    FBuildStatsMenuItem.Visible := FEnableBuildStatistics;
    MenuItem.Add( FBuildStatsMenuItem );
  end;

end;

destructor TCompileProgress.Destroy;
begin
  {$IFDEF CPUX64}
  // Win64 shutdown: each step is independently swallowed + logged so that one
  // failure (typically a partially-torn-down ToolsAPI dispatch into rtl370.bpl)
  // doesn't abort the rest of the destructor.
  try
    if ( FBuildStatsMenuItem <> nil ) and ( FBuildStatsMenuItem.Parent <> nil ) then
      FBuildStatsMenuItem.Parent.Remove( FBuildStatsMenuItem );
    FreeAndNil( FBuildStatsMenuItem );
  except on E: Exception do LogWin64UnloadStep('TCompileProgress.FBuildStatsMenuItem.Free', E); end;
  // RegisterInterceptor was never called on Win64 — see TCompileProgress.Create.
  try FIDENotifier.Free;                                  except on E: Exception do LogWin64UnloadStep('TCompileProgress.FIDENotifier.Free', E); end;
  try FormNativeProgress.Free;                            except on E: Exception do LogWin64UnloadStep('TCompileProgress.FormNativeProgress.Free', E); end;
  try FBuildStatistics.Free;                              except on E: Exception do LogWin64UnloadStep('TCompileProgress.FBuildStatistics.Free', E); end;
  try FPasFilesLock.Free;                                 except on E: Exception do LogWin64UnloadStep('TCompileProgress.FPasFilesLock.Free', E); end;
  try FPasFiles.Free;                                     except on E: Exception do LogWin64UnloadStep('TCompileProgress.FPasFiles.Free', E); end;
  try inherited Destroy;                                  except on E: Exception do LogWin64UnloadStep('TCompileProgress.inherited Destroy', E); end;
  {$ELSE}
  // Remove from the IDE Tools menu before freeing so the menu (which owns it)
  // cannot double-free it during its own teardown.
  if ( FBuildStatsMenuItem <> nil ) and ( FBuildStatsMenuItem.Parent <> nil ) then
    FBuildStatsMenuItem.Parent.Remove( FBuildStatsMenuItem );
  FreeAndNil( FBuildStatsMenuItem );
  GetCompileInterceptorServices.UnregisterInterceptor( FCompileInterceptorId );
  FIDENotifier.Free;
  FormNativeProgress.Free;
  FBuildStatistics.Free;
  FPasFilesLock.Free;
  FPasFiles.Free;
  inherited Destroy;
  {$ENDIF}
end;

procedure TCompileProgress.Init;
begin
  ReleaseCompilerUnitCache := False;
  ReleaseCompilerUnitCacheHigh := True;
  {$IF CompilerVersion < 22.0} // XE has its own option
  DisableRebuildDlg := True;
  {$IFEND}
  AutoSaveAfterSuccessfulCompile := False;
  AskCompileFromDiffProject := True;
  AskCompileFromDiffProjectTemporary := True;
  {$IF CompilerVersion < 23.0} // XE2+ changed how version info works
  LastCompileVersionInfoFormat := 'yyyy-mm-dd hh:nn';
  {$IFEND}
  EnableBuildStatistics := True;
  ShowBuildStatisticsAfterCompile := False;
  RunStyleCheckAfterCompile := False;  // Off by default

  SetClearCompilerUnitCacheOtherStates(FReleaseCompilerUnitCache, FReleaseCompilerUnitCacheHigh);
end;

procedure TCompileProgress.AfterCompile( const Project: IOTAProject; Succeeded, IsCodeInsight: Boolean );
var
  StyleChecker: TStyleChecker;
  CheckerViolations: TArray<CodeStyleChecker.TStyleViolation>;
  LocalViolations: TArray<TStyleViolation>;
  I: Integer;
begin

  if ( not IsCodeInsight ) then
  begin

    if Succeeded and AutoSaveAfterSuccessfulCompile and ( Project <> nil ) then
      ( BorlandIDEServices as IOTAModuleServices ).SaveAll;

    // Finalise build statistics
    if FEnableBuildStatistics then
    begin
      FBuildStatistics.FinalizeBuild( Succeeded );

      // Run style checker if enabled and build succeeded
      if Succeeded and FRunStyleCheckAfterCompile and ( Project <> nil ) then
      begin
        StyleChecker := TStyleChecker.Create;
        try
          if StyleChecker.CheckProject( Project, CheckerViolations, nil ) then
          begin
            // Convert from CodeStyleChecker.TStyleViolation to local TStyleViolation
            SetLength( LocalViolations, Length( CheckerViolations ) );
            for I := 0 to High( CheckerViolations ) do
            begin
              LocalViolations[I].FileName := CheckerViolations[I].FileName;
              LocalViolations[I].UnitName := CheckerViolations[I].UnitName;
              LocalViolations[I].Line     := CheckerViolations[I].Line;
              LocalViolations[I].Column   := CheckerViolations[I].Column;
              LocalViolations[I].Rule     := CheckerViolations[I].Rule;
              LocalViolations[I].Expected := CheckerViolations[I].Expected;
              LocalViolations[I].Actual   := CheckerViolations[I].Actual;
              LocalViolations[I].Severity := CheckerViolations[I].Severity;
              LocalViolations[I].Category := CheckerViolations[I].Category;
            end;
            FBuildStatistics.SetStyleViolations( LocalViolations );
          end;
        finally
          StyleChecker.Free;
        end;
      end;

      if FShowBuildStatisticsAfterCompile and ( FBuildStatistics.UnitCount > 0 ) then
        ShowBuildStatisticsDialog;
    end;
  end;

end;

procedure TCompileProgress.BeforeCompile(const Project: IOTAProject;
  IsCodeInsight: Boolean; var Cancel: Boolean);
var
  i: Integer;
  Ext: string;
  FileName: string;
begin
  if not IsCodeInsight then
  begin
    {$IF CompilerVersion < 23.0} // XE2+ changed how version info works
    if LastCompileVersionInfo then
      UpdateLastCompileVersionInfo(Project);
    {$IFEND}

    {$IF CompilerVersion <= 20.0} // Delphi 2009-
    // Delphi 2009 and older call BeforeCompile and then StartCompile for the first project,
    // BeforeCompile and then StartCompile for the second project, ...
    TStringList(FPasFiles).Sorted := False;
    FPasFiles.Clear;
    {$IFEND}
    // BeforeCompile is called multiple times for multiple projects (Delphi 2010+)
    if FPasFiles.Count = 0 then
    begin
      FormNativeProgress.ProjectFilesCompiled := 0;
      // Clear build statistics at the start of a new build
      if FEnableBuildStatistics then
      begin
        FBuildStatistics.Clear;
        // Store project path for filtering (use first project's path)
        if Project <> nil then
          FBuildStatistics.ProjectPath := ExtractFilePath( Project.FileName );
      end;
    end;

    FPasFiles.Add(ExtractFileName(Project.FileName));
    for i := 0 to Project.GetModuleCount - 1 do
    begin
      FileName := Project.GetModule(i).FileName;
      Ext := AnsiLowerCase(ExtractFileExt(FileName));
      if Ext = '.pas' then
      begin
        FPasFiles.Add(ExtractFileName(FileName));
        FPasFiles.Add(ChangeFileExt(ExtractFileName(FileName), '.dcu'));
        // Add to build statistics for filtering
        if FEnableBuildStatistics then
          FBuildStatistics.AddProjectFile(FileName);
      end;
    end;
    TStringList(FPasFiles).Sorted := True;
    FormNativeProgress.MaxFiles := FPasFiles.Count div 2;
  end;
end;

procedure TCompileProgress.SetAskCompileFromDiffProject(const Value: Boolean);
begin
  if Value <> FAskCompileFromDiffProject then
  begin
    FAskCompileFromDiffProject := Value;
  end;
end;

procedure TCompileProgress.SetReleaseCompilerUnitCache(const Value: Boolean);
begin
  FReleaseCompilerUnitCache := Value;
  SetClearCompilerUnitCacheOtherStates(FReleaseCompilerUnitCache, FReleaseCompilerUnitCacheHigh);
end;

procedure TCompileProgress.SetReleaseCompilerUnitCacheHigh(const Value: Boolean);
begin
  FReleaseCompilerUnitCacheHigh := Value;
  SetClearCompilerUnitCacheOtherStates(FReleaseCompilerUnitCache, FReleaseCompilerUnitCacheHigh);
end;

procedure TCompileProgress.SetEnableBuildStatistics( const Value: Boolean );
begin

  FEnableBuildStatistics := Value;

  if FBuildStatsMenuItem <> nil then
    FBuildStatsMenuItem.Visible := Value;

end;

procedure TCompileProgress.ShowBuildStatisticsDialog;
begin

  TFormBuildStatistics.Execute( FBuildStatistics );

end;

procedure TCompileProgress.BuildStatsMenuItemClick( Sender: TObject );
begin

  ShowBuildStatisticsDialog;

end;

{$IF CompilerVersion < 22.0} // XE has its own option
procedure TCompileProgress.SetDisableRebuildDlg(const Value: Boolean);
{
Delphi 2009:
20729AC5 8B45E4           mov eax,[ebp-$1c]
20729AC8 8B10             mov edx,[eax]
20729ACA FF521C           call dword ptr [edx+$1c]
20729ACD 50               push eax
20729ACE 8D45E0           lea eax,[ebp-$20]
20729AD1 8B55FC           mov edx,[ebp-$04]
20729AD4 B9E09D7220       mov ecx,$20729de0
20729AD9 E82A7AEEFF       call $20611508
20729ADE 8B45E0           mov eax,[ebp-$20]
20729AE1 5A               pop edx
20729AE2 8B08             mov ecx,[eax]
20729AE4 FF510C           call dword ptr [ecx+$0c]
20729AE7 84C0             test al,al
20729AE9 7508             jnz $20729af3
20729AEB 8D45FC           lea eax,[ebp-$04]
20729AEE E8057AEEFF       call $206114f8
20729AF3 837DFC00         cmp dword ptr [ebp-$04],$00
20729AF7 0F844D020000     jz $20729d4a

Delphi 2010:
208A356C 8B45F8           mov eax,[ebp-$08]
208A356F 8B10             mov edx,[eax]
208A3571 FF521C           call dword ptr [edx+$1c]  <<==
208A3574 84C0             test al,al
208A3576 0F8488000000     jz $208a3604
208A357C 8D55C8           lea edx,[ebp-$38]
208A357F B8081A8A20       mov eax,$208a1a08
208A3584 E84FE0E3FF       call $206e15d8
208A3589 8B45C8           mov eax,[ebp-$38]
208A358C 6888130000       push $00001388
208A3591 6AFF             push $ff
208A3593 6AFF             push $ff
208A3595 6A00             push $00
208A3597 0FB70DE0378A20   movzx ecx,[$208a37e0]
208A359E B202             mov dl,$02
208A35A0 E8472AE4FF       call $206e5fec
208A35A5 83E802           sub eax,$02
208A35A8 744C             jz $208a35f6
}
const
  {$IFDEF COMPILER12} // Delphi 2009:
  Bytes: array[0..37] of SmallInt = (
    $8B, $45, $E4,
    $8B, $10,
    $FF, $52, -1,
    $50,
    $8D, $45, $E0,
    $8B, $55, $FC,
    $B9, -1, -1, -1, -1,
    $E8, -1, -1, -1, -1,
    $8B, $45, $E0,
    $5A,
    $8B, 08,
    $FF, $51, $0C,
    $84, $C0,
    $75, $08
  );
  {$ELSE} // Delphi 2010:
  Bytes: array[0..60] of SmallInt = (
    $8B, $45, $F8,
    $8B, $10,
    $FF, $52, -1,
    $84, $C0,
    $0F, $84, -1, -1, -1, -1,
    $8D, $55, -1, //$C8,
    $B8, -1, -1, -1, -1,
    $E8, -1, -1, -1, -1,
    $8B, $45, -1, //$C8,
    $68, -1, -1, -1, -1,
    $6A, $FF,
    $6A, $FF,
    $6A, $00,
    $0F, $B7, $0D, -1, -1, -1, -1,
    $B2, $02,
    $E8, -1, -1, -1, -1,
    $83, $E8, $02,
    $74
  );
  {$ENDIF COMPILER12}

  PatchBytes: array[0..2] of Byte = (
    $31, $C0,         // xor eax,eax
    $90               // nop
  );

var
  P, EndP: PByte;
  I: Integer;
  Found: Boolean;
  n: DWORD;
begin
  if FRebuildAddress = nil then
  begin
    { Find the position that must be patched }
    P := DbgStrictGetProcAddress(GetModuleHandle(coreide_bpl), '@Debuggermgr@TDebuggerMgr@MakeCurrentProject$qqrv');
    EndP := DbgStrictGetProcAddress(GetModuleHandle(coreide_bpl), '@Debuggermgr@TDebuggerMgr@GetSupportedDebugCommands$qqrv');
    if (P <> nil) and (EndP > P) then
    begin
      while P < EndP do
      begin
        while (P < EndP) and (P[0] <> $8B) do
          Inc(P);
        if (P < EndP) then
        begin
          Found := True;
          for I := 0 to High(Bytes) do
          begin
            if (Bytes[I] <> -1) and (P[I] <> Byte(Bytes[I])) then
            begin
              Found := False;
              Break;
            end;
          end;
          if Found then
          begin
            FRebuildAddress := P + 5;
            Move(FRebuildAddress^, FRebuildOrgBytes[0], 3);
            Break;
          end;
        end;
        Inc(P);
      end;
    end;
  end;

  if Value <> FDisableRebuildDlg then
  begin
    if FDisableRebuildDlg and (FRebuildAddress <> nil) then
      WriteProcessMemory(GetCurrentProcess, FRebuildAddress, @FRebuildOrgBytes, SizeOf(FRebuildOrgBytes), n);

    FDisableRebuildDlg := Value;

    if FDisableRebuildDlg and (FRebuildAddress <> nil) then
      WriteProcessMemory(GetCurrentProcess, FRebuildAddress, @PatchBytes, SizeOf(PatchBytes), n);
  end;
end;
{$IFEND}

{$IF CompilerVersion < 23.0} // XE2+ changed how version info works
procedure TCompileProgress.UpdateLastCompileVersionInfo(const Project: IOTAProject);
var
  FormatSettings: TFormatSettings;
begin
  {$IF CompilerVersion >= 22.0} // Delphi XE+
  FormatSettings := TFormatSettings.Create((SUBLANG_NEUTRAL shl 10) or LANG_ENGLISH);
  {$ELSE}
  GetLocaleFormatSettings((SUBLANG_NEUTRAL shl 10) or LANG_ENGLISH, FormatSettings);
  {$IFEND}
  if Trim(LastCompileVersionInfoFormat) <> '' then
    SetVersionInfoExtraKey(Project, 'Last Compile', FormatDateTime(LastCompileVersionInfoFormat, Now, FormatSettings))
  else
    SetVersionInfoExtraKey(Project, 'Last Compile', DateTimeToStr(Now, FormatSettings));
end;
{$IFEND}

function TCompileProgress.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('Compilation', TFrameOptionPageCompilerProgress, Self);
end;

function TCompileProgress.GetOptions: TCompileInterceptOptions;
begin
  Result := CIO_INSPECTFILENAMES;
end;

procedure TCompileProgress.CompileProject(ProjectFilename, UnitPaths, SourcePaths, DcuOutputDir: PWideChar;
  IsCodeInsight: Boolean; var Cancel: Boolean);
begin
end;

function TCompileProgress.AlterFile(Filename: PWideChar; Content: PByte; FileDate, FileSize: Integer): IVirtualStream;
begin
  Result := nil;
end;

function TCompileProgress.AlterMessage(IsCompilerMessage: Boolean;
  var MsgKind: TMsgKind; var Code: Integer; const Filename: IWideString;
  var Line, Column: Integer; const Msg: IWideString): Boolean;
begin
  Result := False;
end;

function TCompileProgress.GetVirtualFile(Filename: PWideChar): IVirtualStream;
begin
  Result := nil;
end;

procedure TCompileProgress.UpdateInMainThread;
begin
  FormNativeProgress.ProjectFilesCompiled := FormNativeProgress.ProjectFilesCompiled + 1;
end;

procedure TCompileProgress.InspectFilename(Filename: PWideChar; FileMode: TInspectFileMode);
var
  Index: Integer;
  SFilename: string;
  SFullFilename: string;
  Ext: string;
begin
  if (FileMode = ifmOpen) and (GetCurrentThreadId = MainThreadId) {and (FormNativeProgress.Form <> nil)} then
  begin
    SFullFilename := Filename;
    SFilename := ExtractFileName(SFullFilename);
    Ext := AnsiLowerCase(ExtractFileExt(SFilename));

    // Track build statistics for .pas files
    if FEnableBuildStatistics and (Ext = '.pas') then
      FBuildStatistics.StartUnit(ChangeFileExt(SFilename, ''), SFullFilename);

    Index := FPasFiles.IndexOf(SFilename);
    if Index <> -1 then
    begin
      //GlobalCompileProgress.FPasFiles.Delete(Index); // prevent the file to be listed twice
      Index := FPasFiles.IndexOf(ChangeFileExt(SFilename, '.dcu'));
      if Index <> -1 then
        FPasFiles.Delete(Index);

      if FormNativeProgress.Form <> nil then
      begin
        if GetCurrentThreadId = MainThreadId then
          FormNativeProgress.ProjectFilesCompiled := FormNativeProgress.ProjectFilesCompiled + 1
        else
          TThread.Queue(nil, UpdateInMainThread);
      end;
    end;
    {if AnsiCompareText(ExtractFileExt(SFilename), '.pas') = 0 then
      FormNativeProgress.FilesCompiled := FormNativeProgress.FilesCompiled + 1;}
  end;
  //OutputDebugString(Filename);
end;

end.
