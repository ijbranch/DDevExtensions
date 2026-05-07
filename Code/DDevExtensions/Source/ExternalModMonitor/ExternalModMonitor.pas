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
  Windows, SysUtils, Classes, ExtCtrls, ShellAPI, ToolsAPI,
  FrmTreePages, PluginConfig, IDENotifiers, FileWatcher;

type
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

    /// <summary>Re-parses MonitoredExtensions into FExtensionSet.</summary>
    procedure RebuildExtensionSet;
    /// <summary>Begins watching the directory of the supplied project file and starts the grace period.</summary>
    /// <param name="ProjectFileName">Full path to the project file ( .dproj, .dpr, .dpk or .groupproj ).</param>
    procedure StartWatchingProject( const ProjectFileName: string );
    /// <summary>Stops watching the directory associated with the supplied project file.</summary>
    /// <param name="ProjectFileName">Full path to the project file being closed.</param>
    procedure StopWatchingProject( const ProjectFileName: string );
    /// <summary>Scans the IDE module list and starts watching directories for projects already loaded.</summary>
    procedure ScanAndWatchOpenProjects;

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
    procedure HandleDebounceTimer( Sender: TObject );

    /// <summary>Returns True when FileName has an extension on the monitored list.</summary>
    function IsMonitoredExtension( const FileName: string ): Boolean;
    /// <summary>Looks up the IOTAModule for FileName among the modules currently open in the IDE.</summary>
    /// <returns>The matching module, or nil if it is not open.</returns>
    function FindOpenModule( const FileName: string ): IOTAModule;
    /// <summary>Returns True when any source editor of Module has unsaved changes ( so it must not be refreshed ).</summary>
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
  Forms, Main, FrmeOptionPageExternalModMonitor;

var
  ExternalModMonitorConfig: TExternalModMonitorConfig;

procedure InitPlugin( Unload: Boolean );
begin

  if not Unload then
    ExternalModMonitorConfig := TExternalModMonitorConfig.Create
  else
    FreeAndNil( ExternalModMonitorConfig );

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

  FFileWatcher := TFileWatcher.Create;
  FFileWatcher.OnFileChanged := HandleFileChanged;

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

end;

destructor TExternalModMonitorConfig.Destroy;
begin

  FFileWatcher.ClearWatches;
  // Remove any lingering tray icon
  Shell_NotifyIcon( NIM_DELETE, @FNotifyIconData );
  FIDENotifier.Free;
  FNotifyCleanupTimer.Free;
  FDebounceTimer.Free;
  FFileWatcher.Free;
  FPendingReloads.Free;
  FExtensionSet.Free;

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

procedure TExternalModMonitorConfig.StartWatchingProject( const ProjectFileName: string );
var
  Dir: string;
begin

  Dir := ExtractFileDir( ProjectFileName );
  if ( Dir <> '' ) and DirectoryExists( Dir ) then
  begin
    FFileWatcher.AddWatch( Dir );
    FGraceUntilTick := GetTickCount64 + UInt64( FProjectLoadGraceMs );
  end;

end;

procedure TExternalModMonitorConfig.StopWatchingProject( const ProjectFileName: string );
var
  Dir: string;
begin

  Dir := ExtractFileDir( ProjectFileName );
  if Dir <> '' then
    FFileWatcher.RemoveWatch( Dir );

end;

procedure TExternalModMonitorConfig.ScanAndWatchOpenProjects;
var
  ProjectGroup: IOTAProjectGroup;
  ModuleServices: IOTAModuleServices;
  I: Integer;
begin

  if not Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
    Exit;

  for I := 0 to ModuleServices.ModuleCount - 1 do
  begin
    if Supports( ModuleServices.Modules[I], IOTAProjectGroup, ProjectGroup ) then
    begin
      // Watch each project in the group
      // Projects fire their own ofnProjectDesktopLoad so this handles
      // the case where the plugin loads after projects are already open
    end;

    if Supports( ModuleServices.Modules[I], IOTAProject ) then
      StartWatchingProject( ModuleServices.Modules[I].FileName );
  end;

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

      if Module = nil then
        Continue;

      { Skip if the user has unsaved changes in the editor }
      if IsModuleModifiedInEditor( Module ) then
        Continue;

      try
        Module.Refresh( False );
        RefreshedFiles.Add( FileName );
      except
        { Silently ignore refresh failures }
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
  SourceEditor: IOTASourceEditor;
begin

  Result := False;

  for I := 0 to Module.ModuleFileCount - 1 do
  begin
    Editor := Module.ModuleFileEditors[I];
    if Supports( Editor, IOTASourceEditor, SourceEditor ) then
    begin
      if SourceEditor.Modified then
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
