unit FrmSwitchToModuleProject;

/// <summary>
/// Provides the dialog that prompts the user to switch the active project when they
/// initiate a compile from a module that belongs to a different project ( or several
/// projects ) than the one currently active in the IDE.
/// </summary>

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, FrmBase, Vcl.StdCtrls, Vcl.ExtCtrls, ToolsAPI, Vcl.Buttons;

type
  /// <summary>
  /// Modal dialog that lets the user choose which of the owning projects of the current
  /// module should become the active project before the compile proceeds.
  /// </summary>
  TFormSwitchToModuleProject = class(TFormBase)
    /// <summary>Bottom panel containing the action buttons.</summary>
    PanelBottom: TPanel;
    /// <summary>Confirms the project switch ( returns mrYes ).</summary>
    ButtonYes: TBitBtn;
    /// <summary>Continues without switching the project ( returns mrNo ).</summary>
    ButtonNo: TBitBtn;
    /// <summary>Cancels the compile ( returns mrCancel ).</summary>
    ButtonCancel: TBitBtn;
    /// <summary>When checked the dialog will not be shown again for the same situation.</summary>
    CheckBoxDontShowAgain: TCheckBox;
    /// <summary>Visual separator above the bottom panel.</summary>
    BevelBottom: TBevel;
    /// <summary>Drop-down listing all the projects that own the current module.</summary>
    ComboBoxProjects: TComboBox;
    /// <summary>Caption label for the active module section.</summary>
    LabelModuleCaption: TLabel;
    /// <summary>Displays the file name of the module being compiled.</summary>
    LabelFileName: TLabel;
    /// <summary>Caption label for the active project section.</summary>
    LabelActiveProjectCaption: TLabel;
    /// <summary>Displays the name of the currently active project.</summary>
    LabelActiveProject: TLabel;
    /// <summary>Prompt asking the user whether they want to switch project.</summary>
    LabelQuestion: TLabel;
    /// <summary>Explanatory text shown above the question.</summary>
    LabelText: TLabel;
    /// <summary>When checked the project switch is only applied for this single compile.</summary>
    CheckBoxTempSwitch: TCheckBox;
    /// <summary>Form-create handler that localises the captions of all controls.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure FormCreate(Sender: TObject);
    /// <summary>
    /// Toggles CheckBoxTempSwitch once per press of the Shift key itself; Shift held as a
    /// modifier (Shift+Tab) and keyboard auto-repeat do not toggle it.
    /// </summary>
    /// <param name="Sender">The form.</param>
    /// <param name="Key">Virtual-key code of the key pressed.</param>
    /// <param name="Shift">Modifier state.</param>
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    /// <summary>True from the Shift key's first key-down until its key-up, so auto-repeat does not toggle again.</summary>
    FShiftKeyDown: Boolean;
    /// <summary>Returns a friendly project name ( file name without path or extension ) for display.</summary>
    /// <param name="AProject">Project to obtain the display name for; may be nil.</param>
    /// <returns>Project name without extension, or an empty string if AProject is nil.</returns>
    function GetProjectName(const AProject: IOTAProject): string;
    /// <summary>Populates the controls and shows the dialog modally; called by ShowDialog.</summary>
    /// <param name="AModule">Module being compiled.</param>
    /// <param name="AProject">On entry the active project; on exit the project the user chose.</param>
    /// <param name="ADontShowAgain">On exit, True if the user ticked the "don't show again" check box.</param>
    /// <param name="SwitchTemporary">Initial state of the "temporary switch" check box.</param>
    /// <returns>mrYes, mrNo, mrCancel or mrRetry ( retry indicates a temporary switch ).</returns>
    function InternShowDialog(AModule: IOTAModule; var AProject: IOTAProject;
      var ADontShowAgain: Boolean; SwitchTemporary: Boolean): TModalResult;
  protected
    /// <summary>Clears the Shift-held flag when the Shift key is released (KeyPreview routes it here).</summary>
    /// <param name="Key">Virtual-key code of the key released.</param>
    /// <param name="Shift">Modifier state.</param>
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    /// <summary>
    /// Takes the Shift key's current state when the dialog appears, so a Shift already held
    /// down ( its auto-repeat ) does not toggle the "temporary switch" box.
    /// </summary>
    procedure DoShow; override;
  public
    /// <summary>Shows the switch-to-module-project dialog and returns the user's choice.</summary>
    /// <param name="AModule">Module that triggered the compile.</param>
    /// <param name="AProject">On entry the currently active project; on exit the project chosen by the user.</param>
    /// <param name="ADontShowAgain">On exit, True if the user wishes to suppress this dialog in future.</param>
    /// <param name="SwitchTemporary">Initial value for the "temporary switch" check box.</param>
    /// <returns>mrYes to switch project, mrNo to compile as-is, mrCancel to abort, mrRetry for a temporary switch.</returns>
    class function ShowDialog(AModule: IOTAModule; var AProject: IOTAProject;
      var ADontShowAgain: Boolean; SwitchTemporary: Boolean): TModalResult;
  end;

implementation

uses
  Vcl.Consts, AppConsts;

{$R *.dfm}

class function TFormSwitchToModuleProject.ShowDialog(AModule: IOTAModule;
  var AProject: IOTAProject; var ADontShowAgain: Boolean; SwitchTemporary: Boolean): TModalResult;
begin
  if AModule.OwnerCount > 0 then
  begin
    var Dlg := TFormSwitchToModuleProject.Create(nil);
    try
      Result := Dlg.InternShowDialog(AModule, AProject, ADontShowAgain, SwitchTemporary);
    finally
      Dlg.Free;
    end;
  end
  else
    Result := mrNo;
end;

function TFormSwitchToModuleProject.InternShowDialog(AModule: IOTAModule;
  var AProject: IOTAProject; var ADontShowAgain: Boolean; SwitchTemporary: Boolean): TModalResult;
var
  I: Integer;
begin
  // Keep the visible order aligned with the owner index so ItemIndex 0 is
  // Owners[0]; the selection is still resolved via Items.Objects[] below.
  ComboBoxProjects.Sorted := False;
  for I := 0 to AModule.OwnerCount - 1 do
    ComboBoxProjects.Items.AddObject(GetProjectName(AModule.Owners[I]), TObject(I));
  ComboBoxProjects.ItemIndex := 0;

  CheckBoxTempSwitch.Checked := SwitchTemporary;
  AProject := GetActiveProject;
  LabelActiveProject.Caption := GetProjectName(AProject);
  if AProject <> nil then
    LabelActiveProject.Hint := AProject.FileName;
  LabelFileName.Caption := ExtractFileName(AModule.FileName);
  LabelFileName.Hint := AModule.FileName;

  Result := ShowModal;
  if Result = mrYes then
  begin
    AProject := AModule.Owners[Integer(ComboBoxProjects.Items.Objects[ComboBoxProjects.ItemIndex])];
    if CheckBoxTempSwitch.Checked then
      Result := mrRetry;
  end;
  if Result <> mrCancel then
    ADontShowAgain := CheckBoxDontShowAgain.Checked;
end;

procedure TFormSwitchToModuleProject.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  inherited;
  if ( Key = VK_SHIFT ) and ( not FShiftKeyDown ) then
  begin
    FShiftKeyDown := True;
    CheckBoxTempSwitch.Checked := not CheckBoxTempSwitch.Checked;
  end;
end;

procedure TFormSwitchToModuleProject.DoShow;
begin
  FShiftKeyDown := GetKeyState( VK_SHIFT ) < 0;
  inherited DoShow;
end;

procedure TFormSwitchToModuleProject.KeyUp(var Key: Word; Shift: TShiftState);
begin
  if ( Key = VK_SHIFT ) then
    FShiftKeyDown := False;
  inherited KeyUp( Key, Shift );
end;

function TFormSwitchToModuleProject.GetProjectName(const AProject: IOTAProject): string;
begin
  if AProject <> nil then
    Result := ChangeFileExt(ExtractFileName(AProject.FileName), '')
  else
    Result := '';
end;

procedure TFormSwitchToModuleProject.FormCreate(Sender: TObject);
begin
  inherited;
  { Localise dialog }
  ButtonYes.Caption := SYesButton;
  ButtonNo.Caption := SNoButton;
  ButtonCancel.Caption := SCancelButton;

  Caption := sCapSwitchToModuleProject;
  LabelActiveProjectCaption.Caption := sLblActiveProject;
  LabelModuleCaption.Caption := sLblActiveModule;
  LabelText.Caption := sLblSwitchCurrentModuleProject;
  LabelQuestion.Caption := sLblSwitchToModuleProjectQuestion;
  CheckBoxDontShowAgain.Caption := sLblDontShowAgain;
  CheckBoxTempSwitch.Caption := sLblTemporarySwitch;
end;

end.

