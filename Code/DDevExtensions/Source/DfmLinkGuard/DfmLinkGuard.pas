{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude Code                                           *}
{*                                                                            *}
{******************************************************************************}

unit DfmLinkGuard;

/// <summary>
/// DFM Link Guard: compares a form's <c>.dfm</c> file before and after every IDE save and writes a
/// warning to the Messages pane ( tab "DFM Link Guard" ) when the save removed a link to a component
/// of another module while that module was not loaded and the component still exists.  The IDE drops
/// such a link silently when the other module is not loaded; the guard makes the loss visible at the
/// save that causes it.  The decision is <c>DfmLinkGuardCore.FindLostModuleLinks</c>; this unit only
/// snapshots the file, asks where the linked module lives and writes the message.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Vcl.ExtCtrls, ToolsAPI, PluginConfig,
  FrmTreePages, ModuleData;

type
  /// <summary>Plug-in configuration and runtime of the DFM Link Guard.</summary>
  TDfmLinkGuardPlugin = class( TPluginConfig )
  private
    /// <summary>Backing field for <see cref="Active"/>.</summary>
    FActive: Boolean;
    /// <summary>Delivers each module's BeforeSave, AfterSave and Destroying.</summary>
    FModuleNotifier: TModuleDataNotifier;
    /// <summary>
    /// Makes sure every open module has its module data ( and so its save notifications ); on the 64-bit
    /// IDE the file notifier that normally does this is not registered.
    /// </summary>
    FModuleScanTimer: TTimer;
    /// <summary>True once a scan failure has been reported, so a failing scan is reported once, not every tick.</summary>
    FScanFailureReported: Boolean;
    /// <summary>
    /// Module -> its <c>.dfm</c> bytes before the save in progress.  Keyed by the module, not the file name,
    /// so a Save As ( which renames the module between BeforeSave and AfterSave ) still finds its snapshot.
    /// </summary>
    FSnapshots: TDictionary<TModuleData, TBytes>;
    /// <summary><c>.dfm</c> file name -> its root name ( empty when unreadable ), for one AfterSave only; nil otherwise.</summary>
    FRootNames: TDictionary<string, string>;
    /// <summary>The Messages pane tab the warnings go to; created on the first warning.</summary>
    FGroup: IOTAMessageGroup;

    /// <summary>Snapshots the module's <c>.dfm</c> before the IDE writes it.</summary>
    /// <param name="Data">The module about to be saved.</param>
    procedure HandleBeforeSave( Data: TModuleData );
    /// <summary>Compares the saved <c>.dfm</c> with its snapshot and reports every lost link.</summary>
    /// <param name="Data">The module just saved.</param>
    procedure HandleAfterSave( Data: TModuleData );
    /// <summary>Forgets the snapshot of a module being closed ( a save that failed or was cancelled left it ).</summary>
    /// <param name="Data">The module being destroyed.</param>
    procedure HandleDestroying( Data: TModuleData );
    /// <summary>Creates module data for modules opened since the last scan.</summary>
    /// <param name="Sender">The scan timer.</param>
    procedure HandleModuleScanTimer( Sender: TObject );
    /// <summary>
    /// Whether a removed link to <paramref name="ModuleName"/>.<paramref name="ComponentName"/> was dropped by the
    /// IDE rather than by the user.  The IDE drops such a link only when the linked module is not loaded, so a
    /// loaded module means a deliberate edit ( False ).  Otherwise True when a <c>.dfm</c> on disk whose root is
    /// <paramref name="ModuleName"/>, from the modules of the open projects, still declares the component.
    /// </summary>
    /// <param name="ModuleName">The linked module's root component name.</param>
    /// <param name="ComponentName">The component's name in that module.</param>
    /// <returns>True for a loss to report; False when deliberate, the component is gone or the module is not found.</returns>
    function IsUnexpectedLoss( const ModuleName, ComponentName: string ): Boolean;
    /// <summary>The root name of a <c>.dfm</c> file, read once per AfterSave.</summary>
    /// <param name="DfmFileName">The <c>.dfm</c> file.</param>
    /// <returns>The root's name; empty when the file is binary, unreadable or has no root.</returns>
    function CachedRootName( const DfmFileName: string ): string;
    /// <summary>Writes one line to the guard's Messages pane tab and brings the tab forward; never raises.</summary>
    /// <param name="FileName">The file the message is about ( double-click opens it ).</param>
    /// <param name="Text">The message.</param>
    procedure AddMessage( const FileName, Text: string );
  protected
    /// <summary>Sets the defaults: active.</summary>
    procedure Init; override;
    /// <summary>Returns the options page of this feature.</summary>
    /// <returns>A new page for the options dialog, which owns it.</returns>
    function GetOptionPages: TTreePage; override;
  public
    /// <summary>Loads the settings and subscribes to module saves.</summary>
    constructor Create;
    /// <summary>Unsubscribes and frees the snapshots.</summary>
    destructor Destroy; override;
  published
    /// <summary>Master switch: when False no file is read and nothing is reported.</summary>
    property Active: Boolean read FActive write FActive;
  end;

/// <summary>Creates the plug-in on load and frees it on unload.</summary>
/// <param name="Unload">False to load the plug-in, True to unload it.</param>
procedure InitPlugin( Unload: Boolean );

implementation

uses
  Winapi.Windows, System.IOUtils, System.Generics.Defaults, Main, gllDfmCompare, DfmLinkGuardCore,
  FrmeOptionPageDfmLinkGuard;

const
  /// <summary>The Messages pane tab and message prefix.</summary>
  CGroupName        = 'DFM Link Guard';

var
  /// <summary>The plug-in instance while loaded.</summary>
  DfmLinkGuardPlugin: TDfmLinkGuardPlugin;

procedure InitPlugin( Unload: Boolean );
begin
  if not Unload then
    DfmLinkGuardPlugin := TDfmLinkGuardPlugin.Create
  else
    FreeAndNil( DfmLinkGuardPlugin );
end;

/// <summary>The <c>.dfm</c> of a module file, when it has one.</summary>
/// <param name="ModuleFileName">The module's file name ( usually the <c>.pas</c> ).</param>
/// <returns>The <c>.dfm</c> file name; empty when there is none on disk.</returns>
function DfmFileOf( const ModuleFileName: string ): string;
begin
  Result            := '';
  if ModuleFileName = '' then Exit;
  var sDfm          := ChangeFileExt( ModuleFileName, '.dfm' );
  if FileExists( sDfm ) then Result := sDfm;
end;

/// <summary>Reads a <c>.dfm</c> file's bytes, without a UTF-8 byte order mark, which the parser would take as text.</summary>
/// <param name="DfmFileName">The file.</param>
/// <returns>The bytes.</returns>
function ReadDfmBytes( const DfmFileName: string ): TBytes;
begin
  Result            := TFile.ReadAllBytes( DfmFileName );
  if ( Length( Result ) >= 3 ) and ( Result[ 0 ] = $EF ) and ( Result[ 1 ] = $BB ) and ( Result[ 2 ] = $BF ) then
    Delete( Result, 0, 3 );
end;

{ TDfmLinkGuardPlugin }

constructor TDfmLinkGuardPlugin.Create;
begin
  FSnapshots        := TDictionary<TModuleData, TBytes>.Create;

  FModuleNotifier   := TModuleDataNotifier.Create;
  FModuleNotifier.BeforeSave := HandleBeforeSave;
  FModuleNotifier.AfterSave := HandleAfterSave;
  FModuleNotifier.Destroying := HandleDestroying;

  FModuleScanTimer  := TTimer.Create( nil );
  FModuleScanTimer.Interval := 3000;
  FModuleScanTimer.OnTimer := HandleModuleScanTimer;

  inherited Create( AppDataDirectory + '\DfmLinkGuard.xml', 'DfmLinkGuard' );
end;

destructor TDfmLinkGuardPlugin.Destroy;
begin
  FModuleScanTimer.Free;
  FModuleNotifier.Free;
  FSnapshots.Free;
  FGroup            := nil;
  inherited Destroy;
end;

procedure TDfmLinkGuardPlugin.Init;
begin
  inherited Init;
  FActive           := True;
end;

function TDfmLinkGuardPlugin.GetOptionPages: TTreePage;
begin
  Result            := TTreePage.Create( 'DFM Link Guard', TFrameOptionPageDfmLinkGuard, Self );
end;

procedure TDfmLinkGuardPlugin.HandleModuleScanTimer( Sender: TObject );
var
  intfModules       : IOTAModuleServices;
begin
  if not Active or not Supports( BorlandIDEServices, IOTAModuleServices, intfModules ) then Exit;
  try
    // Looking a module up creates its TModuleData ( and its IOTAModuleNotifier ) when it has none yet.
    for var iI := 0 to intfModules.ModuleCount - 1 do
      ModuleDataList[ intfModules.Modules[ iI ] ];
  except
    // A timer that raised would show an error dialog every three seconds: report the first failure, once.
    on E: Exception do
      if not FScanFailureReported then
      begin
        FScanFailureReported := True;
        AddMessage( '', 'Could not watch the modules opened since the last check ( reported once ): ' +
          E.ClassName + ': ' + E.Message );
      end;
  end;
end;

procedure TDfmLinkGuardPlugin.HandleBeforeSave( Data: TModuleData );
begin
  if not Active then Exit;
  var sDfm          := DfmFileOf( Data.Filename );
  if sDfm = '' then Exit;
  try
    FSnapshots.AddOrSetValue( Data, ReadDfmBytes( sDfm ) );
  except
    // A save notification must never raise into the IDE ( it could abort the save ); say so instead.
    on E: Exception do
    begin
      FSnapshots.Remove( Data );
      AddMessage( Data.Filename, 'Could not read ' + ExtractFileName( sDfm ) + ' before the save, so this save is not checked: ' +
        E.ClassName + ': ' + E.Message );
    end;
  end;
end;

procedure TDfmLinkGuardPlugin.HandleAfterSave( Data: TModuleData );
begin
  var aOld          : TBytes;
  if not FSnapshots.TryGetValue( Data, aOld ) then Exit; // not snapshotted: inactive or no .dfm
  FSnapshots.Remove( Data );
  var sDfm          := DfmFileOf( Data.Filename ); // after a Save As, the new name
  if not Active or ( sDfm = '' ) then Exit;

  FRootNames        := TDictionary<string, string>.Create( TIStringComparer.Ordinal );
  try
    try
      var aNew      := ReadDfmBytes( sDfm );
      if IsBinaryDfm( aOld ) or IsBinaryDfm( aNew ) then Exit;
      var sOld      := DfmBytesToText( aOld );
      var sNew      := DfmBytesToText( aNew );
      if sOld = sNew then Exit;

      for var rLink in FindLostModuleLinks( sOld, sNew, IsUnexpectedLoss ) do
        AddMessage( Data.Filename, FormatLostLinkMessage( rLink ) );
    except
      // A save notification must never raise into the IDE; say so instead of staying silent.
      on E: Exception do
        AddMessage( Data.Filename, 'Could not check ' + ExtractFileName( sDfm ) + ' for lost links: ' + E.ClassName + ': ' + E.Message );
    end;
  finally
    FreeAndNil( FRootNames );
  end;
end;

procedure TDfmLinkGuardPlugin.HandleDestroying( Data: TModuleData );
begin
  FSnapshots.Remove( Data );
end;

function TDfmLinkGuardPlugin.CachedRootName( const DfmFileName: string ): string;
begin
  if FRootNames.TryGetValue( DfmFileName, Result ) then Exit;
  Result            := '';
  try
    var aBytes      := ReadDfmBytes( DfmFileName );
    if not IsBinaryDfm( aBytes ) then Result := DfmRootName( DfmBytesToText( aBytes ) );
  except
    // One unreadable file ( locked by a scanner or a sync tool, or gone ) must not abort the whole check:
    // it counts as not this module.
    on EInOutError do ;
    on EFOpenError do ;
    on EFileNotFoundException do ;
    on EDirectoryNotFoundException do ;
  end;
  FRootNames.Add( DfmFileName, Result );
end;

function TDfmLinkGuardPlugin.IsUnexpectedLoss( const ModuleName, ComponentName: string ): Boolean;
var
  intfModules       : IOTAModuleServices;
begin
  Result            := False;
  if not Supports( BorlandIDEServices, IOTAModuleServices, intfModules ) then Exit;

  // Loaded: an open module ( project files aside ) whose .dfm root is the linked module.  The IDE does not drop a
  // link to a loaded module, so the user removed it.
  for var iI := 0 to intfModules.ModuleCount - 1 do
  begin
    var intfModule  := intfModules.Modules[ iI ];
    if Supports( intfModule, IOTAProject ) or Supports( intfModule, IOTAProjectGroup ) then Continue;
    var sDfm        := DfmFileOf( intfModule.FileName );
    if ( sDfm <> '' ) and SameText( CachedRootName( sDfm ), ModuleName ) then Exit( False );
  end;

  // Not loaded: find it among the open projects' modules and ask its .dfm on disk.
  for var iI := 0 to intfModules.ModuleCount - 1 do
  begin
    var intfProject : IOTAProject;
    if not Supports( intfModules.Modules[ iI ], IOTAProject, intfProject ) then Continue;
    for var iJ := 0 to intfProject.GetModuleCount - 1 do
    begin
      var intfInfo  := intfProject.GetModule( iJ );
      if not SameText( intfInfo.FormName, ModuleName ) then Continue;
      var sDfm      := DfmFileOf( intfInfo.FileName );
      if ( sDfm = '' ) or not SameText( CachedRootName( sDfm ), ModuleName ) then Continue;
      try
        var aBytes  := ReadDfmBytes( sDfm );
        if DfmDeclaresComponent( DfmBytesToText( aBytes ), ComponentName ) then Exit( True );
      except
        on EInOutError do ;
        on EFOpenError do ;
        on EFileNotFoundException do ;
        on EDirectoryNotFoundException do ;
      end;
    end;
  end;
end;

procedure TDfmLinkGuardPlugin.AddMessage( const FileName, Text: string );
var
  intfMessages      : IOTAMessageServices;
begin
  try
    if not Supports( BorlandIDEServices, IOTAMessageServices, intfMessages ) then Exit;
    if FGroup = nil then
    begin
      FGroup        := intfMessages.GetGroup( CGroupName );
      if FGroup = nil then FGroup := intfMessages.AddMessageGroup( CGroupName );
    end;
    var pLineRef    : Pointer;
    intfMessages.AddToolMessage( FileName, Text, CGroupName, 0, 0, nil, pLineRef, FGroup );
    intfMessages.ShowMessageView( FGroup );
  except
    // Called from IDE notifications that must not raise; with the Messages pane itself failing, the debug
    // output is the only place left to say it.
    on E: Exception do
      OutputDebugString( PChar( 'DDevExtensions DFM Link Guard: could not write to the Messages pane: ' + E.ClassName + ': ' +
        E.Message + ' ( message: ' + Text + ' )' ) );
  end;
end;

end.
