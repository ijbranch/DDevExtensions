unit FrmSwitchToModuleProject;

/// <summary>
/// Provides the dialog that prompts the user to switch the active project when they
/// initiate a compile from a module that belongs to a different project ( or several
/// projects ) than the one currently active in the IDE.
/// </summary>

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, FrmBase, StdCtrls, ExtCtrls, ToolsAPI;

type
  /// <summary>
  /// Modal dialog that lets the user choose which of the owning projects of the current
  /// module should become the active project before the compile proceeds.
  /// </summary>
  TFormSwitchToModuleProject = class(TFormBase)
    /// <summary>Bottom panel containing the action buttons.</summary>
    PanelBottom: TPanel;
    /// <summary>Confirms the project switch ( returns mrYes ).</summary>
    ButtonYes: TButton;
    /// <summary>Continues without switching the project ( returns mrNo ).</summary>
    ButtonNo: TButton;
    /// <summary>Cancels the compile ( returns mrCancel ).</summary>
    ButtonCancel: TButton;
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
    procedure FormCreate(Sender: TObject);
    /// <summary>Toggles CheckBoxTempSwitch when the user holds Shift while a key is pressed.</summary>
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    { Private-Deklarationen }
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
  public
    { Public-Deklarationen }
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
  Consts, AppConsts;

{$R *.dfm}

class function TFormSwitchToModuleProject.ShowDialog(AModule: IOTAModule;
  var AProject: IOTAProject; var ADontShowAgain: Boolean; SwitchTemporary: Boolean): TModalResult;
begin
  if AModule.OwnerCount > 0 then
  begin
    with TFormSwitchToModuleProject.Create(nil) do
    try
      Result := InternShowDialog(AModule, AProject, ADontShowAgain, SwitchTemporary)
    finally
      Free;
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
  if ssShift in Shift then
    CheckBoxTempSwitch.Checked := not CheckBoxTempSwitch.Checked;
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
  { Localize dialog }
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

