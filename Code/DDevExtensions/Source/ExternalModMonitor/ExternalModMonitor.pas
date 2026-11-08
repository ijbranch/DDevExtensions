{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude Code                                           *}
{*                                                                            *}
{* ExternalModMonitor - Real-time external file modification detection         *}
{* Monitors project directories for file changes and silently refreshes        *}
{* modified modules in the IDE. Inspired by VSoft.ExternalModDetector.         *}
{*                                                                            *}
{******************************************************************************}

unit ExternalModMonitor;

/// <summary>
/// Real-time external file modification detector. Watches the directories of all open
/// projects for changes to source files ( .pas, .inc, .dfm, .dpr, etc. ) and silently
/// refreshes the corresponding modules in the IDE when an external editor saves them,
/// while skipping changes that occur during compilation or the brief grace window after
/// a project is loaded. Inspired by VSoft.ExternalModDetector.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.ExtCtrls, Winapi.ShellAPI, ToolsAPI,
  FrmTreePages, PluginConfig, IDENotifiers, FileWatcher, System.Generics.Collections, System.Generics.Defaults, ModuleData;

type
  /// <summary>The folders one watched project contributes to the file watcher.</summary>
  TWatchedProject = class
  public
    /// <summary>Folders this project holds a reference on in the shared folder set.</summary>
    Dirs: TStringList;
    /// <summary>
    /// Folders found missing ( or unreachable ) for this project; not checked again on later
    /// scans, so a disconnected share cannot stall the main thread every few seconds.
    /// </summary>
    Rejected: TStringList;
    /// <summary>Creates the two empty, case-insensitive folder lists.</summary>
    constructor Create;
    /// <summary>Frees both folder lists.</summary>
    destructor Destroy; override;
  end;

  /// <summary>
  /// Plug-in configuration object that owns the External Mod Monitor feature, the file
  /// watcher and the IDE notifiers used to detect and apply external changes.
  /// </summary>
  TExternalModMonitorConfig = class( TPluginConfig )
  private
    /// <summary>Backing field for Active.</summary>
    FActive: Boolean;
    /// <summary>Backing field for DebounceMs.</summary>
    FDebounceMs: Integer;
    /// <summary>Backing field for ProjectLoadGraceMs.</summary>
    FProjectLoadGraceMs: Integer;
    /// <summary>Backing field for MonitoredExtensions ( semicolon-separated list ).</summary>
    FMonitoredExtensions: string;
    /// <summary>Backing field for ShowNotifications.</summary>
    FShowNotifications: Boolean;
    /// <summary>IDE notifier delivering file and compile callbacks.</summary>
    FIDENotifier: TIDENotifier;
    /// <summary>Underlying directory-change watcher.</summary>
    FFileWatcher: TFileWatcher;
    /// <summary>Timer used to debounce a burst of file change notifications.</summary>
    FDebounceTimer: TTimer;
    /// <summary>Timer used to remove the tray notification icon after a delay.</summary>
    FNotifyCleanupTimer: TTimer;
    /// <summary>Native shell notify-icon record reused between notifications.</summary>
    FNotifyIconData: TNotifyIconData;
    /// <summary>Set of file names queued for refresh once the debounce timer fires.</summary>
    FPendingReloads: TStringList;
    /// <summary>True while a compile is in progress; suppresses refresh activity.</summary>
    FCompiling: Boolean;
    /// <summary>GetTickCount64 value before which file changes are ignored ( project load grace period ).</summary>
    FGraceUntilTick: UInt64;
    /// <summary>Lower-cased extensions parsed from MonitoredExtensions for fast lookup.</summary>
    FExtensionSet: TStringList;
    /// <summary>
    /// Watched projects, keyed by <see cref="ProjectKey"/> ( full project file name, with a
    /// .dpr/.dpk mapped to its .dproj ), each with the folders it contributes.
    /// </summary>
    FWatchedProjects: TObjectDictionary<string, TWatchedProject>;
    /// <summary>
    /// Folder -> number of watched projects using it.  A folder is handed to the file watcher
    /// once, however many projects share it, so each folder costs a single watch handle.
    /// </summary>
    FWatchedDirs: TDictionary<string, Integer>;
    /// <summary>
    /// Periodically re-synchronises the watch set with the open projects: picks up projects
    /// and unit folders added since the last scan, and is the only way projects opened later
    /// are noticed on the 64-bit IDE, where the IDE file notifier is not registered.
    /// </summary>
    FProjectScanTimer: TTimer;
    /// <summary>Module-save notifier: files the IDE itself just saved are not reported as external changes.</summary>
    FModuleNotifier: TModuleDataNotifier;
    /// <summary>File name -> GetTickCount64 deadline until which a change to that file is the IDE's own save.</summary>
    FRecentSaves: TDictionary<string, UInt64>;

    /// <summary>Re-parses MonitoredExtensions into FExtensionSet.</summary>
    procedure RebuildExtensionSet;
    /// <summary>
    /// Watches the folder of the supplied project and the folder of every unit in it.  A project
    /// seen for the first time starts the grace period; for a project already watched only
    /// folders not yet watched are added.
    /// </summary>
    /// <param name="ProjectFileName">Full path to the project file ( .dproj, .dpr, .dpk or .groupproj ).</param>
    procedure StartWatchingProject( const ProjectFileName: string );
    /// <summary>Stops watching every folder that was watched for the supplied project.</summary>
    /// <param name="ProjectFileName">Full path to the project file being closed.</param>
    procedure StopWatchingProject( const ProjectFileName: string );
    /// <summary>
    /// Brings the watch set in line with the projects open in the IDE: watches every open
    /// project (and group member) and stops watching projects that are no longer open.
    /// </summary>
    procedure ScanAndWatchOpenProjects;
    /// <summary>Project-scan timer callback; re-synchronises the watch set while monitoring is active.</summary>
    /// <param name="Sender">The scan timer.</param>
    procedure HandleProjectScanTimer( Sender: TObject );
    /// <summary>Records the files of a module the IDE has just saved, so the resulting change event is ignored.</summary>
    /// <param name="Data">The saved module.</param>
    procedure HandleModuleAfterSave( Data: TModuleData );
    /// <summary>
    /// Returns the dictionary key for a project file: its full file name, except that a .dpr or
    /// .dpk maps to the .dproj of the same name ( one project ), so Foo.dpr, Foo.dpk and
    /// Foo.groupproj in one folder never share a key by accident.
    /// </summary>
    /// <param name="ProjectFileName">Project file name.</param>
    /// <returns>The key used in FWatchedProjects.</returns>
    function ProjectKey( const ProjectFileName: string ): string;
    /// <summary>Adds a reference on a folder; hands it to the file watcher on the first reference.</summary>
    /// <param name="ADir">Folder to watch.</param>
    procedure AcquireDir( const ADir: string );
    /// <summary>Drops a reference on a folder; removes it from the file watcher on the last one.</summary>
    /// <param name="ADir">Folder no longer needed by a project.</param>
    procedure ReleaseDir( const ADir: string );
    /// <summary>Releases every folder of the project with the given key and forgets the project.</summary>
    /// <param name="AKey">Key in FWatchedProjects.</param>
    procedure ForgetProject( const AKey: string );
    /// <summary>
    /// Makes sure every open module has its module data, so the AfterSave notification that
    /// filters the IDE's own saves also covers modules opened later ( on the 64-bit IDE the
    /// file notifier that normally does this is not registered ).
    /// </summary>
    procedure EnsureModuleData;

    /// <summary>IDE file-notification callback; tracks project open / close to add or remove watches.</summary>
    /// <param name="NotifyCode">Type of file notification.</param>
    /// <param name="FileName">File name the notification refers to.</param>
    /// <param name="Cancel">May be set to True to cancel the action ( unused here ).</param>
    procedure HandleFileNotification( NotifyCode: TOTAFileNotification;
      const FileName: string; var Cancel: Boolean );
    /// <summary>BeforeCompile callback; sets FCompiling to True so file changes are ignored during the build.</summary>
    procedure HandleBeforeCompile( const Project: IOTAProject;
      IsCodeInsight: Boolean; var Cancel: Boolean );
    /// <summary>AfterCompile callback; clears FCompiling and discards any change events queued during the build.</summary>
    procedure HandleAfterCompile( const Project: IOTAProject;
      Succeeded: Boolean; IsCodeInsight: Boolean );
    /// <summary>File-watcher callback ( on the main thread ); queues the file for refresh and resets the debounce timer.</summary>
    /// <param name="FileName">File reported as changed.</param>
    procedure HandleFileChanged( const FileName: string );
    /// <summary>Debounce-timer callback; refreshes all queued modules whose editor buffers have not been modified.</summary>
    /// <param name="Sender">The debounce timer.</param>
    procedure HandleDebounceTimer( Sender: TObject );

    /// <summary>Returns True when FileName has an extension on the monitored list.</summary>
    function IsMonitoredExtension( const FileName: string ): Boolean;
    /// <summary>Looks up the IOTAModule for FileName among the modules currently open in the IDE.</summary>
    /// <returns>The matching module, or nil if it is not open.</returns>
    function FindOpenModule( const FileName: string ): IOTAModule;
    /// <summary>
    /// Returns True when any editor of Module ( source, form designer or project ) has unsaved
    /// changes, so it must not be refreshed.
    /// </summary>
    /// <param name="Module">The module about to be refreshed.</param>
    /// <returns>True when the module has unsaved changes, or when that cannot be determined.</returns>
    function IsModuleModifiedInEditor( Module: IOTAModule ): Boolean;
    /// <summary>Displays a Windows shell balloon listing the files that were refreshed.</summary>
    /// <param name="RefreshedFiles">List of file names just refreshed.</param>
    procedure ShowBalloonNotification( RefreshedFiles: TStringList );
    /// <summary>Removes the tray notification icon when the cleanup timer fires.</summary>
    procedure HandleNotifyCleanup( Sender: TObject );
  protected
    /// <summary>Sets default values for newly created configurations.</summary>
    procedure Init; override;
    /// <summary>Returns the options-tree page used to edit this plug-in's settings.</summary>
    function GetOptionPages: TTreePage; override;
  public
    /// <summary>Constructs the configuration, the file watcher, the timers and the IDE notifier.</summary>
    constructor Create;
    /// <summary>Stops watching, removes any tray icon, releases timers and notifiers.</summary>
    destructor Destroy; override;
    /// <summary>Syncs the runtime watch set to the current <see cref="Active"/> flag; call after toggling Active at runtime.</summary>
    procedure ApplyActiveState;
  published
    /// <summary>Master switch that enables or disables external file monitoring.</summary>
    property Active: Boolean read FActive write FActive;
    /// <summary>Debounce window in milliseconds; multiple changes within this period trigger a single refresh pass.</summary>
    property DebounceMs: Integer read FDebounceMs write FDebounceMs;
    /// <summary>Semicolon-separated list of file extensions to monitor ( e.g. ".pas;.inc;.dfm" ).</summary>
    property MonitoredExtensions: string read FMonitoredExtensions write FMonitoredExtensions;
    /// <summary>When True a tray balloon is shown listing the refreshed files.</summary>
    property ShowNotifications: Boolean read FShowNotifications write FShowNotifications;
    /// <summary>Grace period in milliseconds after a project is loaded during which file changes are ignored.</summary>
    property ProjectLoadGraceMs: Integer read FProjectLoadGraceMs write FProjectLoadGraceMs;
  end;

/// <summary>
/// Initialises or shuts down the External Mod Monitor plug-in by creating or freeing
/// the global TExternalModMonitorConfig instance.
/// </summary>
/// <param name="Unload">False to load the plug-in, True to unload it.</param>
procedure InitPlugin( Unload: Boolean );

implementation

uses
  Vcl.Forms, Main, FrmeOptionPageExternalModMonitor;

var
  ExternalModMonitorConfig: TExternalModMonitorConfig;

procedure InitPlugin( Unload: Boolean );
begin

  if not Unload then
    ExternalModMonitorConfig := TExternalModMonitorConfig.Create
  else
    FreeAndNil( ExternalModMonitorConfig );

end;

{ TWatchedProject }

constructor TWatchedProject.Create;
begin

  inherited Create;
  Dirs := TStringList.Create;
  Dirs.CaseSensitive := False;
  Rejected := TStringList.Create;
  Rejected.CaseSensitive := False;

end;

destructor TWatchedProject.Destroy;
begin

  Rejected.Free;
  Dirs.Free;
  inherited Destroy;

end;

{ TExternalModMonitorConfig }

constructor TExternalModMonitorConfig.Create;
begin

  FPendingReloads := TStringList.Create;
  FPendingReloads.Sorted := True;
  FPendingReloads.Duplicates := dupIgnore;
  FPendingReloads.CaseSensitive := False;

  FExtensionSet := TStringList.Create;
  FExtensionSet.Sorted := True;
  FExtensionSet.Duplicates := dupIgnore;
  FExtensionSet.CaseSensitive := False;

  FWatchedProjects := TObjectDictionary<string, TWatchedProject>.Create( [ doOwnsValues ],
    TIStringComparer.Ordinal );
  FWatchedDirs := TDictionary<string, Integer>.Create( TIStringComparer.Ordinal );
  FRecentSaves := TDictionary<string, UInt64>.Create( TIStringComparer.Ordinal );

  FFileWatcher := TFileWatcher.Create;
  FFileWatcher.OnFileChanged := HandleFileChanged;

  FModuleNotifier := TModuleDataNotifier.Create;
  FModuleNotifier.AfterSave := HandleModuleAfterSave;

  FProjectScanTimer := TTimer.Create( nil );
  FProjectScanTimer.Enabled := False;
  FProjectScanTimer.Interval := 5000;
  FProjectScanTimer.OnTimer := HandleProjectScanTimer;

  FDebounceTimer := TTimer.Create( nil );
  FDebounceTimer.Enabled := False;
  FDebounceTimer.OnTimer := HandleDebounceTimer;

  FNotifyCleanupTimer := TTimer.Create( nil );
  FNotifyCleanupTimer.Enabled := False;
  FNotifyCleanupTimer.Interval := 8000;
  FNotifyCleanupTimer.OnTimer := HandleNotifyCleanup;

  FIDENotifier := TIDENotifier.Create;
  FIDENotifier.OnFileNotification := HandleFileNotification;
  FIDENotifier.OnBeforeCompile := HandleBeforeCompile;
  FIDENotifier.OnAfterCompile := HandleAfterCompile;

  inherited Create( AppDataDirectory + '\ExternalModMonitor.xml', 'ExternalModMonitor' );

  FDebounceTimer.Interval := FDebounceMs;
  RebuildExtensionSet;

  { Watch any projects already open when plugin loads }
  if FActive then
    ScanAndWatchOpenProjects;
  FProjectScanTimer.Enabled := FActive;

end;

destructor TExternalModMonitorConfig.Destroy;
begin

  FProjectScanTimer.Free;
  FFileWatcher.ClearWatches;
  // Remove any lingering tray icon
  Shell_NotifyIcon( NIM_DELETE, @FNotifyIconData );
  FIDENotifier.Free;
  FModuleNotifier.Free;
  FNotifyCleanupTimer.Free;
  FDebounceTimer.Free;
  FFileWatcher.Free;
  FPendingReloads.Free;
  FExtensionSet.Free;
  FWatchedProjects.Free;
  FWatchedDirs.Free;
  FRecentSaves.Free;

  inherited Destroy;

end;

procedure TExternalModMonitorConfig.Init;
begin

  inherited Init;
  FActive := True;
  FDebounceMs := 200;
  FMonitoredExtensions := '.pas;.inc;.dfm;.dpr;.dproj;.dpk';
  FShowNotifications := True;
  FProjectLoadGraceMs := 3000;

end;

function TExternalModMonitorConfig.GetOptionPages: TTreePage;
begin

  Result := TTreePage.Create( 'External Mod Monitor',
    TFrameOptionPageExternalModMonitor, Self );

end;

procedure TExternalModMonitorConfig.RebuildExtensionSet;
var
  Parts: TArray<string>;
  Part: string;
begin

  FExtensionSet.Clear;
  Parts := FMonitoredExtensions.Split( [';'] );
  for Part in Parts do
  begin
    if Trim( Part ) <> '' then
      FExtensionSet.Add( LowerCase( Trim( Part ) ) );
  end;

end;

function TExternalModMonitorConfig.IsMonitoredExtension( const FileName: string ): Boolean;
begin

  Result := FExtensionSet.IndexOf( LowerCase( ExtractFileExt( FileName ) ) ) >= 0;

end;

function TExternalModMonitorConfig.ProjectKey( const ProjectFileName: string ): string;
begin

  Result := ExpandFileName( ProjectFileName );
  // .dpr/.dpk and .dproj are two files of one project: one key.
  if SameText( ExtractFileExt( Result ), '.dpr' ) or SameText( ExtractFileExt( Result ), '.dpk' ) then
    Result := ChangeFileExt( Result, '.dproj' );

end;

procedure TExternalModMonitorConfig.AcquireDir( const ADir: string );
var
  RefCount: Integer;
begin

  if ( FWatchedDirs.TryGetValue( ADir, RefCount ) ) then
    FWatchedDirs[ ADir ] := RefCount + 1
  else
  begin
    FWatchedDirs.Add( ADir, 1 );
    FFileWatcher.AddWatch( ADir );
  end;

end;

procedure TExternalModMonitorConfig.ReleaseDir( const ADir: string );
var
  RefCount: Integer;
begin

  if ( FWatchedDirs.TryGetValue( ADir, RefCount ) ) then
  begin
    if ( RefCount > 1 ) then
      FWatchedDirs[ ADir ] := RefCount - 1
    else
    begin
      FWatchedDirs.Remove( ADir );
      FFileWatcher.RemoveWatch( ADir );
    end;
  end;

end;

procedure TExternalModMonitorConfig.ForgetProject( const AKey: string );
var
  Watched: TWatchedProject;
begin

  if ( FWatchedProjects.TryGetValue( AKey, Watched ) ) then
  begin
    for var Dir in Watched.Dirs do
      ReleaseDir( Dir );
    FWatchedProjects.Remove( AKey );
  end;

end;

procedure TExternalModMonitorConfig.StartWatchingProject( const ProjectFileName: string );
var
  Watched: TWatchedProject;
  Project: IOTAProject;

  procedure AddDir( const ADir: string );
  begin
    // Each folder is probed at most once per project: a folder already used, or already
    // found missing, is not touched again ( no repeated DirectoryExists on a dead share ).
    if ( ADir = '' ) or ( Watched.Dirs.IndexOf( ADir ) >= 0 ) or ( Watched.Rejected.IndexOf( ADir ) >= 0 ) then
      Exit;
    if ( FWatchedDirs.ContainsKey( ADir ) ) or DirectoryExists( ADir ) then
    begin
      Watched.Dirs.Add( ADir );
      AcquireDir( ADir );
    end
    else
      Watched.Rejected.Add( ADir );
  end;

begin

  if ( ExtractFileDir( ProjectFileName ) = '' ) then
    Exit;

  var Key := ProjectKey( ProjectFileName );
  if ( not FWatchedProjects.TryGetValue( Key, Watched ) ) then
  begin
    Watched := TWatchedProject.Create;
    FWatchedProjects.Add( Key, Watched );
    FGraceUntilTick := GetTickCount64 + UInt64( FProjectLoadGraceMs );
  end;

  AddDir( ExcludeTrailingPathDelimiter( ExtractFileDir( Key ) ) );

  // Units commonly live outside the project folder ( ..\Source, sub-folders ); watch the
  // folder of every unit so their external changes are seen too.  A folder shared by
  // several projects is handed to the file watcher once ( see AcquireDir ).
  if ( Supports( FindOpenModule( ProjectFileName ), IOTAProject, Project ) ) then
    for var I := 0 to Project.GetModuleCount - 1 do
      AddDir( ExcludeTrailingPathDelimiter( ExtractFileDir( Project.GetModule( I ).FileName ) ) );

end;

procedure TExternalModMonitorConfig.StopWatchingProject( const ProjectFileName: string );
begin

  ForgetProject( ProjectKey( ProjectFileName ) );

end;

procedure TExternalModMonitorConfig.ApplyActiveState;
begin

  // Keep the live watch set in step with the persisted Active flag: on enable,
  // pick up projects already open; on disable, drop all watches and the tray icon
  // (otherwise the background thread and directory handles linger until restart).
  FProjectScanTimer.Enabled := FActive;
  if FActive then
    ScanAndWatchOpenProjects
  else
  begin
    FFileWatcher.ClearWatches;
    FWatchedProjects.Clear;
    FWatchedDirs.Clear;
    Shell_NotifyIcon( NIM_DELETE, @FNotifyIconData );
  end;

end;

procedure TExternalModMonitorConfig.ScanAndWatchOpenProjects;
var
  ProjectGroup: IOTAProjectGroup;
  ModuleServices: IOTAModuleServices;
  I: Integer;
  OpenKeys: TStringList;
  Module: IOTAModule;

  procedure Watch( const AFileName: string );
  begin
    if ( ExtractFileDir( AFileName ) = '' ) then
      Exit;
    OpenKeys.Add( ProjectKey( AFileName ) );
    StartWatchingProject( AFileName );
  end;

begin

  if not Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
    Exit;

  OpenKeys := TStringList.Create;
  try
    OpenKeys.Sorted := True;
    OpenKeys.Duplicates := dupIgnore;
    OpenKeys.CaseSensitive := False;

    for I := 0 to ModuleServices.ModuleCount - 1 do
    begin
      Module := ModuleServices.Modules[I];
      if Supports( Module, IOTAProjectGroup, ProjectGroup ) then
      begin
        // Watch every project in the group explicitly. Relying on each project's
        // ofnProjectDesktopLoad is not enough: that notifier may not fire for
        // projects already open at plugin load (and is unregistered on Win64).
        Watch( Module.FileName );
        for var K := 0 to ProjectGroup.ProjectCount - 1 do
          Watch( ProjectGroup.Projects[K].FileName );
      end
      else
      if Supports( Module, IOTAProject ) then
        Watch( Module.FileName );
    end;

    // Drop projects that are no longer open (closed without a notification, e.g. on
    // the 64-bit IDE).
    for var Key in FWatchedProjects.Keys.ToArray do
      if ( OpenKeys.IndexOf( Key ) < 0 ) then
        ForgetProject( Key );
  finally
    OpenKeys.Free;
  end;

end;

procedure TExternalModMonitorConfig.EnsureModuleData;
var
  ModuleServices: IOTAModuleServices;
begin

  // Same path TModuleDataList takes for the modules open at start-up: looking a module up
  // creates its TModuleData ( and its IOTAModuleNotifier ) when it has none yet.
  if not Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
    Exit;
  for var I := 0 to ModuleServices.ModuleCount - 1 do
    ModuleDataList[ ModuleServices.Modules[ I ] ];

end;

procedure TExternalModMonitorConfig.HandleProjectScanTimer( Sender: TObject );
begin

  if FActive then
  begin
    EnsureModuleData;
    ScanAndWatchOpenProjects;
  end;

end;

procedure TExternalModMonitorConfig.HandleModuleAfterSave( Data: TModuleData );
begin

  if ( not Assigned( Data ) ) or ( not Assigned( Data.Module ) ) then
    Exit;

  // The change notification for the IDE's own write arrives shortly after the save; give
  // it two seconds, then a change to the same file counts as external again.
  var Deadline := GetTickCount64 + 2000;
  for var I := 0 to Data.Module.ModuleFileCount - 1 do
    FRecentSaves.AddOrSetValue( Data.Module.ModuleFileEditors[I].FileName, Deadline );

end;

procedure TExternalModMonitorConfig.HandleFileNotification(
  NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean );
begin

  if not FActive then
    Exit;

  case NotifyCode of
    ofnFileOpened,
    ofnProjectDesktopLoad:
      begin
        if SameText( ExtractFileExt( FileName ), '.dproj' ) or
           SameText( ExtractFileExt( FileName ), '.dpk' ) or
           SameText( ExtractFileExt( FileName ), '.dpr' ) or
           SameText( ExtractFileExt( FileName ), '.groupproj' ) then
          StartWatchingProject( FileName );
      end;

    ofnFileClosing:
      begin
        if SameText( ExtractFileExt( FileName ), '.dproj' ) or
           SameText( ExtractFileExt( FileName ), '.dpk' ) or
           SameText( ExtractFileExt( FileName ), '.dpr' ) or
           SameText( ExtractFileExt( FileName ), '.groupproj' ) then
          StopWatchingProject( FileName );
      end;
  end;

end;

procedure TExternalModMonitorConfig.HandleBeforeCompile(
  const Project: IOTAProject; IsCodeInsight: Boolean; var Cancel: Boolean );
begin

  if not IsCodeInsight then
    FCompiling := True;

end;

procedure TExternalModMonitorConfig.HandleAfterCompile(
  const Project: IOTAProject; Succeeded: Boolean; IsCodeInsight: Boolean );
begin

  if not IsCodeInsight then
  begin
    FCompiling := False;
    { Discard any changes detected during compilation }
    FPendingReloads.Clear;
  end;

end;

procedure TExternalModMonitorConfig.HandleFileChanged( const FileName: string );
begin

  { This is called on the main thread via TThread.Queue }
  if not FActive then
    Exit;

  if FCompiling then
    Exit;

  if GetTickCount64 < FGraceUntilTick then
    Exit;

  if not IsMonitoredExtension( FileName ) then
    Exit;

  // A change caused by the IDE's own save is not an external modification.
  var SavedUntil: UInt64;
  if ( FRecentSaves.TryGetValue( FileName, SavedUntil ) ) then
  begin
    if ( GetTickCount64 < SavedUntil ) then
      Exit;
    FRecentSaves.Remove( FileName );
  end;

  FPendingReloads.Add( FileName );

  { Reset debounce timer }
  FDebounceTimer.Enabled := False;
  FDebounceTimer.Interval := FDebounceMs;
  FDebounceTimer.Enabled := True;

end;

procedure TExternalModMonitorConfig.HandleDebounceTimer( Sender: TObject );
var
  I: Integer;
  FileName: string;
  Module: IOTAModule;
  FilesToProcess: TStringList;
  RefreshedFiles: TStringList;
begin

  FDebounceTimer.Enabled := False;

  if FCompiling then
  begin
    FPendingReloads.Clear;
    Exit;
  end;

  if GetTickCount64 < FGraceUntilTick then
  begin
    FPendingReloads.Clear;
    Exit;
  end;

  FilesToProcess := TStringList.Create;
  RefreshedFiles := TStringList.Create;
  try
    FilesToProcess.Assign( FPendingReloads );
    FPendingReloads.Clear;

    for I := 0 to FilesToProcess.Count - 1 do
    begin
      FileName := FilesToProcess[I];
      Module := FindOpenModule( FileName );
      // A form file belongs to the module of its unit.
      if ( Module = nil ) and SameText( ExtractFileExt( FileName ), '.dfm' ) then
        Module := FindOpenModule( ChangeFileExt( FileName, '.pas' ) );

      if Module = nil then
        Continue;

      { Skip if the user has unsaved changes in the editor }
      if IsModuleModifiedInEditor( Module ) then
        Continue;

      try
        Module.Refresh( False );
        RefreshedFiles.Add( FileName );
      except
        on E: Exception do
          // Don't trust a stale buffer silently: log the failed refresh.
          OutputDebugString( PChar( 'DDevExtensions ExternalModMonitor refresh: ' + FileName + ' - ' + E.Message ) );
      end;
    end;

    if FShowNotifications and ( RefreshedFiles.Count > 0 ) then
      ShowBalloonNotification( RefreshedFiles );
  finally
    RefreshedFiles.Free;
    FilesToProcess.Free;
  end;

end;

function TExternalModMonitorConfig.FindOpenModule( const FileName: string ): IOTAModule;
var
  ModuleServices: IOTAModuleServices;
begin

  Result := nil;
  if Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
    Result := ModuleServices.FindModule( FileName );

end;

function TExternalModMonitorConfig.IsModuleModifiedInEditor( Module: IOTAModule ): Boolean;
var
  I: Integer;
  Editor: IOTAEditor;
begin

  Result := False;

  for I := 0 to Module.ModuleFileCount - 1 do
  begin
    try
      // Every editor of the module counts, not only source editors: a form designer
      // (IOTAFormEditor) or a project editor with unsaved changes would otherwise be
      // silently discarded by Refresh when another file of the module changes on disk.
      Editor := Module.ModuleFileEditors[I];
      if ( Assigned( Editor ) ) and ( Editor.Modified ) then
      begin
        Result := True;
        Exit;
      end;
    except
      // A transient ToolsAPI fault on one editor: conservatively treat the module
      // as modified so we never overwrite possibly-unsaved work.
      on E: Exception do
      begin
        Result := True;
        Exit;
      end;
    end;
  end;

end;

procedure TExternalModMonitorConfig.ShowBalloonNotification( RefreshedFiles: TStringList );
var
  Msg: string;
  Title: string;
  I: Integer;
begin

  if RefreshedFiles.Count = 0 then
    Exit;

  // Build message with filenames only (max 5, then summary)
  Msg := '';
  for I := 0 to RefreshedFiles.Count - 1 do
  begin
    if I >= 5 then
    begin
      Msg := Msg + #13#10 + Format( '... and %d more', [RefreshedFiles.Count - 5] );
      Break;
    end;
    if I > 0 then
      Msg := Msg + #13#10;
    Msg := Msg + ExtractFileName( RefreshedFiles[I] );
  end;

  if RefreshedFiles.Count = 1 then
    Title := 'File Refreshed'
  else
    Title := Format( '%d Files Refreshed', [RefreshedFiles.Count] );

  // Remove any previous icon
  Shell_NotifyIcon( NIM_DELETE, @FNotifyIconData );

  ZeroMemory( @FNotifyIconData, SizeOf( FNotifyIconData ) );
  FNotifyIconData.cbSize := SizeOf( TNotifyIconData );
  FNotifyIconData.Wnd := Application.Handle;
  FNotifyIconData.uID := 42;
  FNotifyIconData.uFlags := NIF_ICON or NIF_INFO;
  FNotifyIconData.hIcon := LoadIcon( 0, IDI_APPLICATION );
  FNotifyIconData.dwInfoFlags := NIIF_INFO;
  StrPLCopy( FNotifyIconData.szInfoTitle, Title, Length( FNotifyIconData.szInfoTitle ) - 1 );
  StrPLCopy( FNotifyIconData.szInfo, Msg, Length( FNotifyIconData.szInfo ) - 1 );

  Shell_NotifyIcon( NIM_ADD, @FNotifyIconData );

  // Schedule cleanup to remove the tray icon
  FNotifyCleanupTimer.Enabled := False;
  FNotifyCleanupTimer.Enabled := True;

end;

procedure TExternalModMonitorConfig.HandleNotifyCleanup( Sender: TObject );
begin

  FNotifyCleanupTimer.Enabled := False;
  Shell_NotifyIcon( NIM_DELETE, @FNotifyIconData );

end;

end.
