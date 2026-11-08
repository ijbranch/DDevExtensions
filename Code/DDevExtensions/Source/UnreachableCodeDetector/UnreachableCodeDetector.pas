{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2025 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit UnreachableCodeDetector;

/// <summary>
/// Implements the Unreachable Code Detector DDevExtensions plugin: scans implementation
/// sections looking for code that follows an unconditional control-flow terminator
/// (Exit, Raise, Break, Continue, Halt, Abort) before the next end/else/finally/until.
/// </summary>
/// <remarks>
/// Honours $IFDEF/$IFNDEF/$IF blocks and skips terminators that are conditional (e.g.
/// "if X then Exit;"), assignments to variables named like keywords, and case labels.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Generics.Collections, Vcl.Menus,
  ToolsAPI, FrmTreePages, PluginConfig, Main, UnreachableCodeCore, ProjectSources;

type
  /// <summary>
  /// Plugin host: registers the menu item and exposes the entry point for the detector form.
  /// </summary>
  TUnreachableCodeDetectorPlugin = class( TPluginConfig )
  private
    /// <summary>Backing field for <see cref="Enabled"/>.</summary>
    FEnabled: Boolean;
    /// <summary>Owned menu item under the DDevExtensions submenu.</summary>
    FMenuItem: TMenuItem;
    /// <summary>Menu click handler that opens the detector form.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure MenuItemClick( Sender: TObject );
  protected
    /// <summary>Returns the IDE Tools options page for this plugin.</summary>
    /// <returns>The page shown under this plugin in the DDevExtensions options.</returns>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises default option values.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the plugin and adds its menu item.</summary>
    constructor Create;
    /// <summary>Frees the menu item.</summary>
    destructor Destroy; override;
    /// <summary>Opens the Unreachable Code Detector form.</summary>
    procedure ShowUnreachableCodeDetector;
  published
    /// <summary>Whether the plugin's features are enabled.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

/// <summary>
/// Scans every .pas unit of Project, honouring the compiler's predefined symbols for the project's
/// active platform and the project's conditional defines.  Each unit is read from its open editor
/// buffer when it has one, else from disk; a unit that cannot be read is skipped and counted.
/// </summary>
/// <param name="Scanner">The scanner; its previous items are discarded.</param>
/// <param name="Project">The project to scan.</param>
/// <param name="OnProgress">Optional progress callback; it can cancel the scan.</param>
/// <param name="SkippedFiles">Receives the number of units that could not be read.</param>
/// <returns>True when the scan ran to the end; False when there was no project or it was cancelled.</returns>
function ScanProject( Scanner: TUnreachableCodeScanner; const Project: IOTAProject; OnProgress: TSourceScanProgressEvent;
  out SkippedFiles: Integer ): Boolean;

/// <summary>Plugin entry point invoked by the IDE host to load or unload the plugin singleton.</summary>
/// <param name="Unload">When True the plugin is unloaded; otherwise it is loaded.</param>
procedure InitPlugin( Unload: Boolean );

var
  /// <summary>Singleton instance of the Unreachable Code Detector plugin.</summary>
  UnreachableCodeDetectorPlugin: TUnreachableCodeDetectorPlugin;

implementation

uses
  Vcl.Forms, Vcl.Controls, Vcl.Dialogs, System.Variants, ToolsAPIHelpers, AppConsts,
  FrmUnreachableCodeDetector, FrmeOptionPageUnreachableCode;

/// <summary>
/// The project's conditional defines for the active build configuration and platform, merged with
/// everything they inherit (Base, then the configuration, then the platform), as the compiler sees them.
/// </summary>
/// <param name="Project">The project.</param>
/// <returns>The defines, semicolon-separated; the legacy "Defines" option when the configuration API is unavailable.</returns>
function ActiveDefines( const Project: IOTAProject ): string;
begin
  Result := '';
  var oOptions := Project.ProjectOptions;
  if oOptions = nil then
    Exit;

  var oConfigs: IOTAProjectOptionsConfigurations;
  if Supports( oOptions, IOTAProjectOptionsConfigurations, oConfigs ) and ( oConfigs.ActiveConfiguration <> nil ) then
  begin
    var oConfig := oConfigs.ActiveConfiguration;
    var oPlatformConfig := oConfig.PlatformConfiguration[ Project.CurrentPlatform ];
    if oPlatformConfig <> nil then
      oConfig := oPlatformConfig;
    Exit( oConfig.GetValue( 'DCC_Define', True ) );
  end;

  Result := VarToStrDef( oOptions.Values[ 'Defines' ], '' );
end;

function ScanProject( Scanner: TUnreachableCodeScanner; const Project: IOTAProject; OnProgress: TSourceScanProgressEvent;
  out SkippedFiles: Integer ): Boolean;
begin
  Result       := False;
  SkippedFiles := 0;

  if Project = nil then
    Exit;

  Scanner.Clear;

  Scanner.SetTarget( Project.CurrentPlatform, ActiveDefines( Project ) );

  for var sFileName in GetProjectSourceFiles( Project, [ '.pas' ] ) do
  begin
    if ScanShouldStop( OnProgress, 'Scanning: ' + ExtractFileName( sFileName ) ) then
      Exit;

    try
      var sSource := UTF8ToString( ReadModuleSource( sFileName ) );
      Scanner.ScanSource( sSource, sFileName, ChangeFileExt( ExtractFileName( sFileName ), '' ) );
    except
      on E: EStreamError do
        Inc( SkippedFiles );   // locked / unreadable unit: skip it, the rest of the scan still runs
      on E: EOSError do
        Inc( SkippedFiles );
    end;
  end;

  Result := True;
end;

{ TUnreachableCodeDetectorPlugin }

constructor TUnreachableCodeDetectorPlugin.Create;
begin

  inherited Create( AppDataDirectory + '\UnreachableCodeDetector.xml', 'UnreachableCodeDetector' );

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem         := TMenuItem.Create( DDevExtensionsMenu );
    FMenuItem.Caption := 'Unreachable Code Detector...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add( FMenuItem );
  end;

end;

destructor TUnreachableCodeDetectorPlugin.Destroy;
begin

  FreeAndNil( FMenuItem );
  inherited Destroy;

end;

procedure TUnreachableCodeDetectorPlugin.Init;
begin

  FEnabled := True;

end;

function TUnreachableCodeDetectorPlugin.GetOptionPages: TTreePage;
begin

  Result := TTreePage.Create( 'Unreachable Code', TFrameOptionPageUnreachableCode, Self );

end;

procedure TUnreachableCodeDetectorPlugin.MenuItemClick( Sender: TObject );
begin
  if not FEnabled then
  begin
    ShowMessage( 'The Unreachable Code Detector is disabled. Enable it in the DDevExtensions options.' );
    Exit;
  end;

  ShowUnreachableCodeDetector;
end;

procedure TUnreachableCodeDetectorPlugin.ShowUnreachableCodeDetector;
begin

  TFormUnreachableCodeDetector.Execute;

end;

procedure InitPlugin( Unload: Boolean );
begin

  if not Unload then
    UnreachableCodeDetectorPlugin := TUnreachableCodeDetectorPlugin.Create
  else
  begin
    // Close the form first: it is owned by the IDE's Application and would otherwise outlive the
    // plugin (and, on package unload, its own code).
    TFormUnreachableCodeDetector.CloseInstance;
    FreeAndNil( UnreachableCodeDetectorPlugin );
  end;

end;

end.
