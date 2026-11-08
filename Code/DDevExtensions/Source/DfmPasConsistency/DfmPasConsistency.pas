{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit DfmPasConsistency;

/// <summary>
/// DDevExtensions plugin that compares each form's <c>.dfm</c> file with its companion <c>.pas</c>
/// unit, looking for components that appear in one file but not the other, or whose declared type
/// does not match. Helps surface stale designer state and orphaned field declarations.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, Vcl.Menus, ToolsAPI, PluginConfig, FrmTreePages,
  FrmeOptionPageDfmPas, System.Generics.Collections;

type
  /// <summary>
  /// Plugin host integrating the DFM/PAS consistency check into DDevExtensions.  The comparison
  /// itself is <c>DfmPasConsistencyCore.AnalyseFormUnit</c>.
  /// </summary>
  TDfmPasConsistencyPlugin = class(TPluginConfig)
  private
    /// <summary>Menu item added to the DDevExtensions submenu.</summary>
    FMenuItem: TMenuItem;
    /// <summary>Master enable flag for the plugin.</summary>
    FEnabled: Boolean;
    /// <summary>Menu OnClick handler that opens the result form.</summary>
    /// <param name="Sender">The menu item clicked.</param>
    procedure MenuItemClick(Sender: TObject);
  protected
    /// <summary>Returns the option page used in the IDE options dialog.</summary>
    /// <returns>A new page for the options dialog, which owns it.</returns>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises configuration to its built-in defaults.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the plugin and registers its menu item.</summary>
    constructor Create;
    /// <summary>Removes the menu item and releases the plugin.</summary>
    destructor Destroy; override;
  published
    /// <summary>Persisted master enable flag.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

var
  /// <summary>Singleton plugin instance.</summary>
  DfmPasConsistencyPlugin: TDfmPasConsistencyPlugin;

/// <summary>
/// Plugin lifecycle entry point — creates or releases <see cref="DfmPasConsistencyPlugin"/>.
/// </summary>
/// <param name="Unload"><c>True</c> to release the plugin, <c>False</c> to create it.</param>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  Vcl.Forms, Vcl.Dialogs, Main, IDENotifiers, ToolsAPIHelpers,
  FrmDfmPasConsistency;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    DfmPasConsistencyPlugin := TDfmPasConsistencyPlugin.Create
  else
  begin
    { Close the form first: it is modeless and owned by the IDE's Application, so it would
      otherwise outlive the code that implements it. }
    TFormDfmPasConsistency.CloseInstance;
    FreeAndNil( DfmPasConsistencyPlugin );
  end;
end;

{ TDfmPasConsistencyPlugin }

constructor TDfmPasConsistencyPlugin.Create;
begin
  inherited Create(AppDataDirectory + '\DfmPasConsistency.xml', 'DfmPasConsistency');

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem := TMenuItem.Create(DDevExtensionsMenu);
    FMenuItem.Caption := 'DFM/PAS &Consistency...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add(FMenuItem);
  end;
end;

destructor TDfmPasConsistencyPlugin.Destroy;
begin
  FreeAndNil(FMenuItem);
  inherited Destroy;
end;

function TDfmPasConsistencyPlugin.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('DFM/PAS Consistency', TFrameOptionPageDfmPas, Self);
end;

procedure TDfmPasConsistencyPlugin.Init;
begin
  inherited Init;
  FEnabled := True;
end;

procedure TDfmPasConsistencyPlugin.MenuItemClick(Sender: TObject);
begin
  if not Enabled then
  begin
    ShowMessage('DFM/PAS Consistency Checker is disabled. Enable it in DDevExtensions options.');
    Exit;
  end;

  TFormDfmPasConsistency.Execute;
end;

end.
