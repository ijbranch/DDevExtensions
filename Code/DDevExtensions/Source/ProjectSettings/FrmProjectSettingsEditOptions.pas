{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmProjectSettingsEditOptions;

/// <summary>
/// Hosts the dialog that lets the user pick which individual options of a TProjectSetting preset
/// are active (i.e. will be applied when the preset is assigned to a project).
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  System.Variants, Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.Grids, ProjectSettingsData, Vcl.StdCtrls, Vcl.CheckLst, FrmBase;

type
  /// <summary>
  /// Modal dialog that displays the options of a TProjectSetting in a checklist box and lets the
  /// user toggle which options are considered "active" for the preset.
  /// </summary>
  TFormProjectSettingsEditOptions = class(TFormBase)
    /// <summary>OK button that confirms changes and closes the dialog.</summary>
    btnOk: TButton;
    /// <summary>Cancel button that aborts changes and closes the dialog.</summary>
    btnCancel: TButton;
    /// <summary>Checklist of preset options; checked items are active.</summary>
    clbOptions: TCheckListBox;
    /// <summary>Caption label displayed above the checklist.</summary>
    lblCaption: TLabel;
    /// <summary>Checks every option in the list.</summary>
    btnCheckAll: TButton;
    /// <summary>Unchecks every option in the list.</summary>
    btnUncheckAll: TButton;
    /// <summary>Resets the active state of every option to the built-in defaults.</summary>
    btnDefault: TButton;
    /// <summary>Toggles the checked state of every option.</summary>
    btnToggle: TButton;
    /// <summary>Hooks the checklist's window procedure and configures anchors.</summary>
    procedure FormCreate(Sender: TObject);
    /// <summary>Handles both Check All and Uncheck All buttons.</summary>
    procedure btnCheckAllClick(Sender: TObject);
    /// <summary>Resets every option's active state to the built-in defaults.</summary>
    procedure btnDefaultClick(Sender: TObject);
    /// <summary>Inverts the checked state of every option.</summary>
    procedure btnToggleClick(Sender: TObject);
  private
    { Private-Deklarationen }
    /// <summary>Original window procedure of the checklist box (used for chaining).</summary>
    FOrgListBoxWndProc: TWndMethod;
    /// <summary>Populates the checklist, runs the dialog and writes results back to ASettings.</summary>
    /// <param name="ASettings">Setting whose option flags are being edited.</param>
    /// <returns>True if the user confirmed with OK.</returns>
    function DoExecute(ASettings: TProjectSetting): Boolean;
    /// <summary>Replacement window procedure that guards CN_DRAWITEM against an out-of-range item id.</summary>
    procedure ListBoxWndProc(var Msg: TMessage);
  public
    { Public-Deklarationen }
    /// <summary>Creates the form, runs the dialog and frees the form.</summary>
    /// <param name="ASettings">Setting whose option flags should be edited; nil short-circuits to False.</param>
    /// <returns>True if the user confirmed with OK.</returns>
    class function Execute(ASettings: TProjectSetting): Boolean;
  end;

{var
  FormProjectSettingsEditOptions: TFormProjectSettingsEditOptions;}

implementation

{$R *.dfm}

{ TFormProjectSettingsEditOptions }

class function TFormProjectSettingsEditOptions.Execute(ASettings: TProjectSetting): Boolean;
begin
  if ASettings <> nil then
  begin
    with Self.Create(nil) do
    try
      Result := DoExecute(ASettings);
    finally
      Free;
    end;
  end
  else
    Result := False;
end;

function TFormProjectSettingsEditOptions.DoExecute(ASettings: TProjectSetting): Boolean;
var
  i, Index: Integer;
begin
  for i := 0 to ASettings.Count - 1 do
  begin
    Index := clbOptions.Items.Add(ASettings.Items[i].Name);
    clbOptions.Checked[Index] := ASettings.Items[i].Active;
  end;
  Caption := ASettings.Name + ' - Option';
  Result := ShowModal = mrOk;
  if Result then
  begin
    for i := 0 to clbOptions.Items.Count - 1 do
    begin
      Index := ASettings.IndexOf(clbOptions.Items[i]);
      if Index <> -1 then
        ASettings.Items[Index].Active := clbOptions.Checked[Index];
    end;
  end;
end;

procedure TFormProjectSettingsEditOptions.FormCreate(Sender: TObject);
begin
  FOrgListBoxWndProc := clbOptions.WindowProc;
  clbOptions.WindowProc := ListBoxWndProc;

  clbOptions.Anchors := [akLeft, akTop, akRight, akBottom];
  btnOk.Anchors := [akRight, akBottom];
  btnCancel.Anchors := [akRight, akBottom];
  btnCheckAll.Anchors := [akLeft, akBottom];
  btnUncheckAll.Anchors := [akLeft, akBottom];
  btnDefault.Anchors := [akLeft, akBottom];
  btnToggle.Anchors := [akLeft, akBottom];
end;

procedure TFormProjectSettingsEditOptions.ListBoxWndProc(var Msg: TMessage);
begin
  if Msg.Msg = CN_DRAWITEM then
  begin
    { fix bug }
    with clbOptions do
      if (Items.Count = 0) or (TWMDrawItem(Msg).DrawItemStruct^.itemID >= UINT(Items.Count)) then
        Exit;
  end;

  if Assigned(FOrgListBoxWndProc) then
    FOrgListBoxWndProc(Msg);
end;

procedure TFormProjectSettingsEditOptions.btnCheckAllClick(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to clbOptions.Items.Count - 1 do
    clbOptions.Checked[i] := Sender = btnCheckAll;
end;

procedure TFormProjectSettingsEditOptions.btnDefaultClick(Sender: TObject);
var
  i, Index: Integer;
  List: TStrings;
begin
  List := TStringList.Create;
  try
    TProjectSettingList.FillOptionNames(List);
    for i := 0 to clbOptions.Items.Count - 1 do
    begin
      Index := List.IndexOf(clbOptions.Items[i]);
      clbOptions.Checked[i] := (Index = -1) or (List.Objects[Index] = nil);
    end;
  finally
    List.Free;
  end;
end;

procedure TFormProjectSettingsEditOptions.btnToggleClick(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to clbOptions.Items.Count - 1 do
    clbOptions.Checked[i] := not clbOptions.Checked[i];
end;

end.
