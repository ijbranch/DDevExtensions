{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageComponentSelector;

/// <summary>
/// Implements the IDE options page frame for the Component Selector feature, exposing
/// the active flag, search-mode toggles and the focus hotkey to the user.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, ComponentSelector, FrmTreePages, Vcl.ComCtrls, FrmeBase, Vcl.ExtCtrls;

type
  /// <summary>
  /// Options page frame that hosts the Component Selector configuration controls and
  /// applies them to the running <see cref="TComponentSelector"/> instance.
  /// </summary>
  TFrameOptionPageComponentSelector = class(TFrameBase, ITreePageComponent)
    /// <summary>Toggles prefix-only (simple) search.</summary>
    cbxSimpleSearch: TCheckBox;
    /// <summary>Toggles palette grouping in the result list.</summary>
    cbxSortByPalette: TCheckBox;
    /// <summary>Toggles whether the Component Selector toolbar is visible.</summary>
    cbxActive: TCheckBox;
    /// <summary>Editor for the focus hotkey.</summary>
    HotKey: THotKey;
    /// <summary>Caption for the hotkey editor.</summary>
    lblHotkey: TLabel;
    /// <summary>Enables or disables dependent controls when the active state changes.</summary>
    /// <param name="Sender">The active checkbox.</param>
    procedure cbxActiveClick(Sender: TObject);
  private
    { Private-Deklarationen }
    /// <summary>Selector instance the page edits.</summary>
    FComponentSelector: TComponentSelector;
  public
    { Public-Deklarationen }
    /// <summary>Receives the <see cref="TComponentSelector"/> instance edited by this page.</summary>
    /// <param name="UserData">The selector cast to TObject.</param>
    procedure SetUserData(UserData: TObject);
    /// <summary>Populates the controls from the controller's current configuration.</summary>
    procedure LoadData;
    /// <summary>Writes the control values back to the controller and persists them.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes active in the options dialog.</summary>
    procedure Selected;
    /// <summary>Called when the page is deactivated in the options dialog.</summary>
    procedure Unselected;
  end;

implementation

{$R *.dfm}

{ TFrameOptionPageComponentSelector }

procedure TFrameOptionPageComponentSelector.SetUserData(UserData: TObject);
begin
  FComponentSelector := UserData as TComponentSelector;
end;

procedure TFrameOptionPageComponentSelector.LoadData;
begin
  cbxActive.Checked := FComponentSelector.ToolBar.Visible;
  cbxSimpleSearch.Checked := FComponentSelector.Edit.CheckBoxSimpleSearch.Checked;
  cbxSortByPalette.Checked := FComponentSelector.Edit.CheckBoxPaletteSort.Checked;
  HotKey.HotKey := FComponentSelector.Hotkey;

  cbxActiveClick(cbxActive);
end;

procedure TFrameOptionPageComponentSelector.SaveData;
begin
  FComponentSelector.ToolBar.Visible := cbxActive.Checked;
  FComponentSelector.Edit.CheckBoxSimpleSearch.Checked := cbxSimpleSearch.Checked;
  FComponentSelector.Edit.CheckBoxPaletteSort.Checked := cbxSortByPalette.Checked;
  FComponentSelector.Hotkey := HotKey.HotKey;
  FComponentSelector.SaveToolbarConfig;
end;

procedure TFrameOptionPageComponentSelector.Selected;
begin
end;

procedure TFrameOptionPageComponentSelector.Unselected;
begin
end;

procedure TFrameOptionPageComponentSelector.cbxActiveClick(Sender: TObject);
begin
  cbxSimpleSearch.Enabled := cbxActive.Checked;
  cbxSortByPalette.Enabled := cbxActive.Checked;
  lblHotkey.Enabled := cbxActive.Checked;
  HotKey.Enabled := cbxActive.Checked;
end;

end.
