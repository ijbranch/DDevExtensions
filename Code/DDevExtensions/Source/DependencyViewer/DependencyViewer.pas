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
  System.SysUtils, System.Classes, Vcl.Menus, ToolsAPI, FrmTreePages, PluginConfig, Main,
  DependencyViewerCore;

type
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
    /// <param name="Sender">The menu item clicked.</param>
    procedure MenuItemClick( Sender: TObject );
  protected
    /// <summary>Returns the IDE Tools options page for this plugin.</summary>
    /// <returns>A new page for the options dialog, which owns it.</returns>
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
/// Scans every .pas unit of a project into the scanner and analyses the graph: an open unit is read
/// from its editor buffer and any other from disk; no module is opened.
/// </summary>
/// <param name="AScanner">The scanner; it is cleared first.</param>
/// <param name="AProject">The project to scan; nil leaves the scanner empty.</param>
/// <param name="AOnProgress">Called with each unit name before it is read; it may raise
/// <c>EAbort</c> to stop the scan.</param>
procedure ScanDependencyProject( AScanner: TDependencyScanner; const AProject: IOTAProject;
  AOnProgress: TProc<string> );

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
  System.Variants, Vcl.Forms, Vcl.Controls, ToolsAPIHelpers, AppConsts, IdeUnitSource,
  FrmDependencyViewer, FrmeOptionPageDependencyViewer;

procedure ScanDependencyProject( AScanner: TDependencyScanner; const AProject: IOTAProject;
  AOnProgress: TProc<string> );
var
  Options: IOTAProjectOptions;
  Content: UTF8String;
begin

  AScanner.Clear;
  if ( AProject = nil ) then
    Exit;

  AScanner.AddSearchPath( ExtractFileDir( AProject.FileName ) );

  // The compiler's own symbols ( MSWINDOWS, WIN64, VER370 ... ) for the platform being built, so a
  // unit used under $IFDEF MSWINDOWS is a dependency and its $ELSE branch is not.
  if AScanner.RespectConditionals then
    for var sSymbol in PredefinedSymbols( AProject.CurrentPlatform ) do
      AScanner.AddDefine( sSymbol );

  Options := AProject.ProjectOptions;
  if ( Options <> nil ) then
  begin
    if AScanner.RespectConditionals then
      for var sDefine in VarToStr( Options.Values[ 'Defines' ] ).Split( [ ';' ] ) do
        AScanner.AddDefine( sDefine );

    for var sPath in VarToStr( Options.Values[ 'UnitDir' ] ).Split( [ ';' ] ) do
      if ( Trim( sPath ) <> '' ) then
        AScanner.AddSearchPath( ExpandFileName( Trim( sPath ) ) );
  end;

  { The file list is taken once: the progress callback pumps messages, and the project can change
    or close meanwhile - after each pump the scan stops if it is no longer the active project. }
  var Identity := ProjectIdentity( AProject );
  for var sFileName in ProjectPascalFiles( AProject ) do
  begin
    var sUnitName := ChangeFileExt( ExtractFileName( sFileName ), '' );
    if Assigned( AOnProgress ) then
    begin
      AOnProgress( sUnitName );
      CheckProjectUnchanged( Identity );
    end;

    { An open unit is read from its editor buffer, any other from disk. }
    try
      if ( not ReadUnitSource( sFileName, Content ) ) then
        Content := '';
    except
      // Locked or vanished: the unit stays in the graph with no dependencies.
      on EFOpenError do
        Content := '';
    end;
    AScanner.ScanSource( sUnitName, sFileName, string( Content ) );
  end;

  AScanner.Analyse;

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
    { Close the form first: it is modeless and owned by the IDE's Application, so it would
      otherwise outlive the code that implements it. }
    TFormDependencyViewer.CloseInstance;
    FreeAndNil( DependencyViewerPlugin );
  end;

end;

end.
