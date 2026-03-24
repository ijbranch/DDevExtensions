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

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, ExtCtrls, ShellAPI, ToolsAPI,
  FrmTreePages, PluginConfig, IDENotifiers, FileWatcher;

type
  TExternalModMonitorConfig = class( TPluginConfig )
  private
    FActive: Boolean;
    FDebounceMs: Integer;
    FMonitoredExtensions: string;
    FShowNotifications: Boolean;
    FIDENotifier: TIDENotifier;
    FFileWatcher: TFileWatcher;
    FDebounceTimer: TTimer;
    FNotifyCleanupTimer: TTimer;
    FNotifyIconData: TNotifyIconData;
    FPendingReloads: TStringList;
    FCompiling: Boolean;
    FExtensionSet: TStringList;

    procedure RebuildExtensionSet;
    procedure StartWatchingProject( const ProjectFileName: string );
    procedure StopWatchingProject( const ProjectFileName: string );
    procedure ScanAndWatchOpenProjects;

    procedure HandleFileNotification( NotifyCode: TOTAFileNotification;
      const FileName: string; var Cancel: Boolean );
    procedure HandleBeforeCompile( const Project: IOTAProject;
      IsCodeInsight: Boolean; var Cancel: Boolean );
    procedure HandleAfterCompile( const Project: IOTAProject;
      Succeeded: Boolean; IsCodeInsight: Boolean );
    procedure HandleFileChanged( const FileName: string );
    procedure HandleDebounceTimer( Sender: TObject );

    function IsMonitoredExtension( const FileName: string ): Boolean;
    function FindOpenModule( const FileName: string ): IOTAModule;
    function IsModuleModifiedInEditor( Module: IOTAModule ): Boolean;
    procedure ShowBalloonNotification( RefreshedFiles: TStringList );
    procedure HandleNotifyCleanup( Sender: TObject );
  protected
    procedure Init; override;
    function GetOptionPages: TTreePage; override;
  public
    constructor Create;
    destructor Destroy; override;
  published
    property Active: Boolean read FActive write FActive;
    property DebounceMs: Integer read FDebounceMs write FDebounceMs;
    property MonitoredExtensions: string read FMonitoredExtensions write FMonitoredExtensions;
    property ShowNotifications: Boolean read FShowNotifications write FShowNotifications;
  end;

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
    FFileWatcher.AddWatch( Dir );

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
