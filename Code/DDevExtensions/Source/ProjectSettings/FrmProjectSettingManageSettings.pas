{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmProjectSettingManageSettings;

/// <summary>
/// Hosts the dialog used to manage local and global project settings: lets the user create, edit,
/// rename, delete and assign reusable project option presets and apply them across the projects of
/// the active project group.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  System.Variants, Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ToolWin, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.ImgList, Vcl.ActnList,
  ProjectSettingsData, ToolsAPI, Vcl.Menus, FrmBase;

type
  /// <summary>
  /// Modal form that displays local and global project setting presets together with the projects
  /// they may be assigned to, allowing the user to create, edit, delete and assign presets.
  /// </summary>
  TFormManageProjectSetting = class(TFormBase)
    /// <summary>OK button that confirms changes and closes the dialog.</summary>
    btnOk: TButton;
    /// <summary>Cancel button that aborts changes and closes the dialog.</summary>
    btnCancel: TButton;
    /// <summary>Main client panel of the dialog hosting all sub-panels.</summary>
    pnlClient: TPanel;
    /// <summary>Splitter between the settings panels and the projects list.</summary>
    spltProjects: TSplitter;
    /// <summary>Action list owning the toolbar/menu actions of the form.</summary>
    aclButtons: TActionList;
    /// <summary>Creates a new local project setting preset.</summary>
    actLocalNewSetting: TAction;
    /// <summary>Edits the currently selected local project setting preset.</summary>
    actLocalEditSetting: TAction;
    /// <summary>Deletes the currently selected local project setting preset.</summary>
    actLocalDeleteSetting: TAction;
    /// <summary>Assigns the selected local preset to the selected projects.</summary>
    actLocalAssignSetting: TAction;
    /// <summary>Creates a new global project setting preset.</summary>
    actGlobalNewSetting: TAction;
    /// <summary>Edits the currently selected global project setting preset.</summary>
    actGlobalEditSetting: TAction;
    /// <summary>Deletes the currently selected global project setting preset.</summary>
    actGlobalDeleteSetting: TAction;
    /// <summary>Assigns the selected global preset to the selected projects.</summary>
    actGlobalAssignSetting: TAction;
    /// <summary>Left container panel that holds the local and global settings panels.</summary>
    pnlLeft: TPanel;
    /// <summary>Container panel for the global settings list and toolbar.</summary>
    pnlGlobal: TPanel;
    /// <summary>Container panel for the local settings list and toolbar.</summary>
    pnlLocal: TPanel;
    /// <summary>List view displaying the project's local setting presets.</summary>
    lvwLocal: TListView;
    /// <summary>List view displaying the global setting presets.</summary>
    lvwGlobal: TListView;
    /// <summary>Splitter between the local and global setting panels.</summary>
    spltLocalGlobal: TSplitter;
    /// <summary>Caption label for the local settings list.</summary>
    lblLocalSettings: TLabel;
    /// <summary>Caption label for the global settings list.</summary>
    lblGlobalSettings: TLabel;
    /// <summary>Toolbar hosting the local settings actions.</summary>
    tbToolbarLocal: TToolBar;
    /// <summary>Local toolbar button (New).</summary>
    ToolButton1: TToolButton;
    /// <summary>Local toolbar button (Edit).</summary>
    ToolButton2: TToolButton;
    /// <summary>Local toolbar button (Delete).</summary>
    ToolButton3: TToolButton;
    /// <summary>Local toolbar separator.</summary>
    ToolButton4: TToolButton;
    /// <summary>Local toolbar button (Assign).</summary>
    ToolButton5: TToolButton;
    /// <summary>Local toolbar separator.</summary>
    ToolButton6: TToolButton;
    /// <summary>Toolbar hosting the global settings actions.</summary>
    tbToolbarGlobal: TToolBar;
    /// <summary>Global toolbar button (New).</summary>
    ToolButton7: TToolButton;
    /// <summary>Global toolbar button (Edit).</summary>
    ToolButton8: TToolButton;
    /// <summary>Global toolbar button (Delete).</summary>
    ToolButton9: TToolButton;
    /// <summary>Global toolbar separator.</summary>
    ToolButton10: TToolButton;
    /// <summary>Global toolbar button (Assign).</summary>
    ToolButton11: TToolButton;
    /// <summary>Global toolbar separator.</summary>
    ToolButton12: TToolButton;
    /// <summary>Container panel for the projects list and its toolbar.</summary>
    pnlProjects: TPanel;
    /// <summary>List view displaying projects in the current project group.</summary>
    lvwProjects: TListView;
    /// <summary>Caption label for the projects list.</summary>
    lblProjects: TLabel;
    /// <summary>Local toolbar button (Edit Options flags).</summary>
    ToolButton13: TToolButton;
    /// <summary>Opens the option-flag editor for the selected local preset.</summary>
    actLocalEditOptions: TAction;
    /// <summary>Opens the option-flag editor for the selected global preset.</summary>
    actGlobalEditOptions: TAction;
    /// <summary>Global toolbar button (Edit Options flags).</summary>
    ToolButton14: TToolButton;
    /// <summary>Popup menu shown for the local settings list.</summary>
    popLocalSettings: TPopupMenu;
    /// <summary>Local popup menu item: New.</summary>
    New1: TMenuItem;
    /// <summary>Local popup menu item: Edit.</summary>
    Edit1: TMenuItem;
    /// <summary>Local popup menu item: Set active flags.</summary>
    Setactiveflags1: TMenuItem;
    /// <summary>Local popup menu item: Delete.</summary>
    Delete1: TMenuItem;
    /// <summary>Local popup menu item: Assign.</summary>
    Assign1: TMenuItem;
    /// <summary>Local popup menu separator.</summary>
    N1: TMenuItem;
    /// <summary>Local popup menu separator.</summary>
    N2: TMenuItem;
    /// <summary>Popup menu shown for the global settings list.</summary>
    popGlobalSettings: TPopupMenu;
    /// <summary>Global popup menu item: New.</summary>
    MenuItem1: TMenuItem;
    /// <summary>Global popup menu item: Edit.</summary>
    MenuItem2: TMenuItem;
    /// <summary>Global popup menu item: Set active flags.</summary>
    MenuItem3: TMenuItem;
    /// <summary>Global popup menu item: Delete.</summary>
    MenuItem4: TMenuItem;
    /// <summary>Global popup menu item: Assign.</summary>
    MenuItem5: TMenuItem;
    /// <summary>Global popup menu separator.</summary>
    MenuItem6: TMenuItem;
    /// <summary>Global popup menu separator.</summary>
    MenuItem7: TMenuItem;
    /// <summary>Toolbar hosting the project actions.</summary>
    tbToolbarProjects: TToolBar;
    /// <summary>Project toolbar button (Edit Project Options).</summary>
    ToolButton16: TToolButton;
    /// <summary>Project toolbar button (Set Version Info).</summary>
    ToolButton18: TToolButton;
    /// <summary>Opens the IDE project options dialog for the selected project.</summary>
    actProjectEditProjectOptions: TAction;
    /// <summary>Project toolbar separator.</summary>
    ToolButton15: TToolButton;
    /// <summary>Opens the version info dialog for the selected projects.</summary>
    actProjectSetVersionInfo: TAction;
    /// <summary>Initialises owned fields, sets anchors, captions and double-buffering.</summary>
    procedure FormCreate(Sender: TObject);
    /// <summary>Frees owned setting lists and project-assignment storage.</summary>
    procedure FormDestroy(Sender: TObject);
    /// <summary>Updates the enabled state of an action based on the current selection.</summary>
    procedure ActionUpdate(Sender: TObject);
    /// <summary>Dispatches the New/Edit/Delete/Assign/EditOptions actions for both local and global settings.</summary>
    procedure ActionExecute(Sender: TObject);
    /// <summary>Custom-draws the active project's row in bold.</summary>
    procedure lvwProjectsCustomDrawItem(Sender: TCustomListView;
      Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
    /// <summary>Implements Ctrl+A select-all on the projects list view.</summary>
    procedure lvwProjectsKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    /// <summary>Triggers Edit Setting on double-click in the local settings list.</summary>
    procedure lvwLocalDblClick(Sender: TObject);
    /// <summary>Validates the renamed preset and propagates the new name to project assignments.</summary>
    procedure lvwGlobalEdited(Sender: TObject; Item: TListItem; var S: String);
    /// <summary>Triggers in-place rename on F2.</summary>
    procedure lvwGlobalKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    /// <summary>Disallows renaming the protected "Default" local preset.</summary>
    procedure lvwGlobalEditing(Sender: TObject; Item: TListItem;
      var AllowEdit: Boolean);
    /// <summary>Triggers Edit Setting on double-click in the global settings list.</summary>
    procedure lvwGlobalDblClick(Sender: TObject);
    /// <summary>Updates the enabled state of the project-related actions.</summary>
    procedure ActionProjectUpdate(Sender: TObject);
    /// <summary>Dispatches Edit Project Options and Set Version Info actions.</summary>
    procedure ActionProjectExecute(Sender: TObject);
  private
    { Private-Deklarationen }
    /// <summary>Working copy of the local project setting presets.</summary>
    FSettings: TProjectSettingList;
    /// <summary>Working copy of the global project setting presets.</summary>
    FGlobalSettings: TProjectSettingList;
    /// <summary>Maps each project (Objects[]) to its assigned preset id (Strings[]).</summary>
    FProjectAssignments: TStrings;
  protected
    /// <summary>Populates a settings list view with the items from the supplied list.</summary>
    procedure FillSettingsListViews(ListView: TListView; Settings: TProjectSettingList);
    /// <summary>Populates the projects list view from the active project group.</summary>
    procedure FillProjectListView;
    /// <summary>Runs the modal dialog using the supplied local and global settings.</summary>
    /// <param name="ASettings">Local presets to manage.</param>
    /// <param name="AGlobalSettings">Global presets to manage.</param>
    /// <returns>True if the user confirmed with OK.</returns>
    function DoExecute(ASettings, AGlobalSettings: TProjectSettingList): Boolean;
    /// <summary>Adds a list item representing the given preset to the list view.</summary>
    function AddSettingListItem(ListView: TListView; Setting: TProjectSetting): TListItem;
    /// <summary>Recomputes which preset (if any) currently matches each project.</summary>
    procedure RefreshProjectAssignment;
    /// <summary>Stores the chosen preset id for the supplied project.</summary>
    procedure SetProjectAssignment(Project: IOTAProject; const Value: string);
    /// <summary>Returns the preset id currently assigned to the supplied project.</summary>
    function GetProjectAssignment(Project: IOTAProject): string;
    /// <summary>Keeps OK as the default button only when no list is in edit mode.</summary>
    procedure UpdateActions; override;
  public
    { Public-Deklarationen }
    /// <summary>Creates the form, runs the dialog and frees the form.</summary>
    /// <returns>True if the user confirmed with OK.</returns>
    class function Execute(ASettings, AGlobalSettings: TProjectSettingList): Boolean;
  end;

/// <summary>Auto-created (but unused) form variable retained for IDE compatibility.</summary>
var
  FormManageProjectSetting: TFormManageProjectSetting;

implementation

uses
  Vcl.Consts, Utils, ToolsAPIHelpers, FrmProjectSettingsEditOptions, ProjectData,
  ProjectSettings, FrmProjectSettingsSetVersioninfo, DtmImages, AppConsts;

{$R *.dfm}

{$IFDEF COMPILER5}
type
  TExListView = class(TListView)
    procedure SelectAll;
  end;

procedure TExListView.SelectAll;
var
  I: Integer;
begin
  for I := 0 to Items.Count - 1 do
    Items[I].Selected := True;
end;
{$ENDIF COMPILER5}

class function TFormManageProjectSetting.Execute(ASettings, AGlobalSettings: TProjectSettingList): Boolean;
begin
  if GetActiveProject <> nil then
  begin
    with Self.Create(nil) do
    begin
      try
        Result := DoExecute(ASettings, AGlobalSettings);
      finally
        Free;
      end;
    end;
  end
  else
    Result := False;
end;

function TFormManageProjectSetting.DoExecute(ASettings, AGlobalSettings: TProjectSettingList): Boolean;
var
  i, Index: Integer;
begin
  // Populate ListView
  FSettings.Assign(ASettings);
  FGlobalSettings.Assign(AGlobalSettings);
  try
    lvwLocal.Tag := NativeInt(FSettings);
    lvwGlobal.Tag := NativeInt(FGlobalSettings);
    if (FSettings.Count = 0) and (GetProjectAssignment(GetActiveProject) = '') then
    begin
      // Create "Default" setting
      with FSettings.Add do
      begin
        Name := 'Default';
        CopyFrom(GetActiveProject);
        SetProjectAssignment(GetActiveProject, 'Local:Default');
      end;
    end;

    FillSettingsListViews(lvwLocal, FSettings);
    FillSettingsListViews(lvwGlobal, FGlobalSettings);
    FillProjectListView;
    lblLocalSettings.Caption := Format(_('%s from %s'), [lblLocalSettings.Caption, ExtractFileName(GetActiveProject.FileName)]);

    Result := ShowModal = mrOk;
    if Result then
    begin
      for i := 0 to lvwProjects.Items.Count - 1 do
      begin
        Index := FProjectAssignments.IndexOfObject(lvwProjects.Items[i].Data);
        if Index <> -1 then
          ProjectDataList[IOTAProject(lvwProjects.Items[i].Data)].Values[sProjectSettings] := FProjectAssignments[Index];
      end;
      // Update data
      ASettings.Assign(FSettings);
      AGlobalSettings.Assign(FGlobalSettings);
    end;
  finally
    FGlobalSettings.Clear;
    FSettings.Clear;
  end;
end;

procedure TFormManageProjectSetting.FormCreate(Sender: TObject);
begin
  FSettings := TProjectSettingList.Create;
  FGlobalSettings := TProjectSettingList.Create;
  FProjectAssignments := TStringList.Create;

  // Set anchors by code, otherwise Delphi 5 makes trouble
  pnlClient.Anchors := [akLeft, akTop, akRight, akBottom];
  btnOk.Caption := SOKButton;
  btnOk.Anchors := [akRight, akBottom];
  btnCancel.Caption := SCancelButton;
  btnCancel.Anchors := [akRight, akBottom];
  Constraints.MinWidth := 240;
  Constraints.MinHeight := 100;
  {$IFDEF COMPILER10_UP}
  tbToolbarLocal.DrawingStyle := Vcl.ComCtrls.dsGradient;
  tbToolbarGlobal.DrawingStyle := Vcl.ComCtrls.dsGradient;
  tbToolbarProjects.DrawingStyle := Vcl.ComCtrls.dsGradient;
  {$ENDIF COMPILER10_UP}

  tbToolbarLocal.Images := DataModuleImages.imlIcons;
  tbToolbarGlobal.Images := DataModuleImages.imlIcons;
  tbToolbarProjects.Images := DataModuleImages.imlIcons;

  pnlLocal.DoubleBuffered := True;
  pnlGlobal.DoubleBuffered := True;
  pnlProjects.DoubleBuffered := True;
end;

procedure TFormManageProjectSetting.FormDestroy(Sender: TObject);
begin
  FProjectAssignments.Free;
  FGlobalSettings.Free;
  FSettings.Free;
end;

function TFormManageProjectSetting.AddSettingListItem(ListView: TListView; Setting: TProjectSetting): TListItem;
begin
  Result := ListView.Items.Add;
  Result.Caption := Setting.Name;
  Result.Data := Setting;
  Result.ImageIndex := 6;
end;

procedure TFormManageProjectSetting.FillSettingsListViews(ListView: TListView; Settings: TProjectSettingList);
var
  i: Integer;
begin
  ListView.Items.BeginUpdate;
  try
    ListView.Items.Clear;
    for i := 0 to Settings.Count - 1 do
      AddSettingListItem(ListView, Settings[i]);
  finally
    ListView.Items.EndUpdate;
  end;
end;

procedure TFormManageProjectSetting.FillProjectListView;
var
  Item: TListItem;
  i: Integer;
  ProjectGroup: IOTAProjectGroup;
  Options: TProjectSetting;
begin
  lvwProjects.Items.BeginUpdate;
  try
    lvwProjects.Items.Clear;

    Options := TProjectSetting.Create;
    try
      ProjectGroup := GetActiveProjectGroup;
      if ProjectGroup <> nil then
      begin
        for i := 0 to ProjectGroup.ProjectCount - 1 do
        begin
          Options.CopyFrom(ProjectGroup.Projects[i]);
          Item := lvwProjects.Items.Add;
          Item.Caption := ExtractFileName(ProjectGroup.Projects[i].FileName);
          Item.Data := Pointer(ProjectGroup.Projects[i]);
          Item.SubItems.AddObject('', nil);
          Item.Selected := ProjectGroup.Projects[i] = ProjectGroup.ActiveProject;
          Item.ImageIndex := 4;
        end;
      end;
    finally
      Options.Free;
    end;
    RefreshProjectAssignment;
  finally
    lvwProjects.Items.EndUpdate;
  end;
end;

procedure TFormManageProjectSetting.ActionUpdate(Sender: TObject);

  function HaveSelectedProjectsTheSetting(ListView: TListView): Boolean;
  var
    i: Integer;
    Options: TProjectSetting;
  begin
    Result := False;
    Options := ListView.Selected.Data;
    for i := 0 to lvwProjects.Items.Count - 1 do
      if lvwProjects.Items[i].Selected then
        if (lvwProjects.Items[i].SubItems.Objects[0] <> Options) or
           EndsText('*', lvwProjects.Items[i].SubItems[0]) then
          Exit;
    Result := True;
  end;

begin
  if Sender = actLocalEditSetting then
    actLocalEditSetting.Enabled := lvwLocal.Selected <> nil
  else if Sender = actLocalDeleteSetting then
    actLocalDeleteSetting.Enabled := (lvwLocal.Selected <> nil) and
      (TProjectSetting(lvwLocal.Selected.Data).Name <> 'Default')
  else if Sender = actLocalAssignSetting then
    actLocalAssignSetting.Enabled := (lvwLocal.Selected <> nil) and (lvwProjects.SelCount > 0) and
      not HaveSelectedProjectsTheSetting(lvwLocal)
  else if Sender = actLocalEditOptions then
    actLocalEditOptions.Enabled := lvwLocal.Selected <> nil

  else if Sender = actGlobalEditSetting then
    actGlobalEditSetting.Enabled := lvwGlobal.Selected <> nil
  else if Sender = actGlobalDeleteSetting then
    actGlobalDeleteSetting.Enabled := lvwGlobal.Selected <> nil
  else if Sender = actGlobalAssignSetting then
    actGlobalAssignSetting.Enabled := (lvwGlobal.Selected <> nil) and (lvwProjects.SelCount > 0) and
      not HaveSelectedProjectsTheSetting(lvwGlobal)
  else if Sender = actGlobalEditOptions then
    actGlobalEditOptions.Enabled := lvwGlobal.Selected <> nil
  ;
end;

procedure TFormManageProjectSetting.ActionExecute(Sender: TObject);
var
  List: TProjectSettingList;
  ListView: TListView;
  Backup: TProjectSetting;
  Options, OrgOptions: TProjectSetting;
  i: Integer;
  Asked: Boolean;
  Prefix: string;
begin
  if Pos('Local', TAction(Sender).Name) > 0 then
  begin
    List := FSettings;
    ListView := lvwLocal;
    Prefix := 'Local:';
  end
  else
  begin
    List := FGlobalSettings;
    ListView := lvwGlobal;
    Prefix := 'Global:';
  end;

  if (Sender = actLocalNewSetting) or (Sender = actGlobalNewSetting) then
  begin
    Options := List.Add;
    i := 1;
    while List.FindByName('Project Options ' + IntToStr(i)) <> nil do
      Inc(i);
    Options.Name := 'Project Options ' + IntToStr(i);
    with AddSettingListItem(ListView, Options) do
    begin
      Selected := True;

      // Capture the active project once and nil-check it: it can change or close
      // while the modal EditOptions dialog is open, and is dereferenced repeatedly.
      var ProjNew := GetActiveProject;
      if ProjNew <> nil then
      begin
        Backup := TProjectSetting.Create;
        try
          Backup.CopyFrom(ProjNew, scCopyAll);
          ProjNew.ProjectOptions.EditOptions; // edit dialog
          Options.CopyFrom(ProjNew);
        finally
          Backup.CopyTo(ProjNew, scCopyAll);
          Backup.Free;
        end;
      end;

      ListView.Selected.EditCaption;
    end;
  end
  {----------------------}
  else if (Sender = actLocalEditSetting) or (Sender = actGlobalEditSetting) then
  begin
    Options := TProjectSetting(ListView.Selected.Data);
    OrgOptions := TProjectSetting.Create;
    try
      OrgOptions.Assign(Options);
      // Capture the active project once and nil-check it (it can change/close
      // while the modal EditOptions dialog is open).
      var ProjEdit := GetActiveProject;
      if ProjEdit <> nil then
      begin
        Backup := TProjectSetting.Create;
        try
          Backup.CopyFrom(ProjEdit, scCopyAll);
          Options.CopyTo(ProjEdit);
          ProjEdit.ProjectOptions.EditOptions; // edit dialog
          Options.CopyFrom(ProjEdit);
        finally
          Backup.CopyTo(ProjEdit, scCopyAll);
          Backup.Free;
        end;
      end;

      { Copy the changes to the projects that use the Settings. But first ask
        the user. } 
      if not Options.Compare(OrgOptions) then
      begin
        Asked := False;
        for i := 0 to lvwProjects.Items.Count - 1 do
        begin
          if lvwProjects.Items[i].SubItems.Objects[0] = Options then
          begin
            if not Asked then
            begin
              if MessageDlg(_('Do you want to assign the changes to the projects?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
              begin
                RefreshProjectAssignment;
                Break;
              end;
              Asked := True;
            end;
            Options.CopyTo(IOTAProject(lvwProjects.Items[i].Data));
          end;
        end;
      end;
    finally
      OrgOptions.Free;
    end;
  end
  {----------------------}
  else if (Sender = actLocalDeleteSetting) or (Sender = actGlobalDeleteSetting) then
  begin
    Options := TProjectSetting(ListView.Selected.Data);
    if MessageDlg(Format(_('Do you really want to delete the project settings %s'), [Options.Name]),
                  mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;
    List.Remove(Options);
    ListView.Selected.Delete;
    RefreshProjectAssignment;
  end
  {----------------------}
  else if (Sender = actLocalAssignSetting) or (Sender = actGlobalAssignSetting) then
  begin
    lvwProjects.Items.BeginUpdate;
    try
      Options := ListView.Selected.Data;
      for i := 0 to lvwProjects.Items.Count - 1 do
      begin
        if lvwProjects.Items[i].Selected then
        begin
          Options.CopyTo(IOTAProject(lvwProjects.Items[i].Data), scAssign);
          SetProjectAssignment(IOTAProject(lvwProjects.Items[i].Data), Prefix + Options.Name);

          lvwProjects.Items[i].SubItems.Objects[0] := Options;
          lvwProjects.Items[i].SubItems[0] := Options.Name;
        end;
      end;
    finally
      lvwProjects.Items.EndUpdate;
    end;
  end
  {----------------------}
  else if (Sender = actLocalEditOptions) or (Sender = actGlobalEditOptions) then
  begin
    TFormProjectSettingsEditOptions.Execute(ListView.Selected.Data);
  end;
end;

procedure TFormManageProjectSetting.lvwProjectsCustomDrawItem(
  Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
  var DefaultDraw: Boolean);
begin
  DefaultDraw := True;
  if Item.Data = Pointer(GetActiveProject) then
    Sender.Canvas.Font.Style := [fsBold]
  else
    Sender.Canvas.Font.Style := [];
end;

procedure TFormManageProjectSetting.lvwProjectsKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if (Key = Ord('A')) and (Shift = [ssCtrl]) then
    {$IFDEF COMPILER6_UP}
    (Sender as TListView).SelectAll;
    {$ELSE}
    TExListView(Sender).SelectAll;
    {$ENDIF COMPILER6_UP}
end;

procedure TFormManageProjectSetting.lvwLocalDblClick(Sender: TObject);
begin
  actLocalEditSetting.Execute;
end;

procedure TFormManageProjectSetting.lvwGlobalEdited(Sender: TObject; Item: TListItem; var S: String);
var
  List: TProjectSettingList;
  i: Integer;
  Options: TProjectSetting;
  Prefix: string;
begin
  List := TProjectSettingList(TListView(Sender).Tag);
  if List = FSettings then
    Prefix := 'Local:'
  else
    Prefix := 'Global:';
  S := Trim(S);
  if (S = '') or (List.FindByName(S) <> nil) then
    S := Item.Caption
  else
  begin
    Options := Item.Data;
    Options.Name := S;
    for i := 0 to lvwProjects.Items.Count - 1 do
      if lvwProjects.Items[i].SubItems.Objects[0] = Options then
      begin
        SetProjectAssignment(IOTAProject(lvwProjects.Items[i].Data), Prefix + Options.Name);
        lvwProjects.Items[i].SubItems[0] := Options.Name;
      end;
  end;
end;

procedure TFormManageProjectSetting.lvwGlobalKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_F2) and (Shift = []) then
  begin
    if TListView(Sender).Selected <> nil then
      TListView(Sender).Selected.EditCaption;
  end;
end;

procedure TFormManageProjectSetting.lvwGlobalEditing(Sender: TObject;
  Item: TListItem; var AllowEdit: Boolean);
begin
  AllowEdit := (Item.ListView <> lvwLocal) or (Item.Caption <> 'Default');
end;

procedure TFormManageProjectSetting.lvwGlobalDblClick(Sender: TObject);
begin
  actGlobalEditSetting.Execute;
end;

procedure TFormManageProjectSetting.RefreshProjectAssignment;
var
  i: Integer;
  Options, EqualOpt: TProjectSetting;
  Item: TListItem;
  OptionsId: string;
begin
  Options := TProjectSetting.Create;
  try
    for i := 0 to lvwProjects.Items.Count - 1 do
    begin
      Item := lvwProjects.Items[i];
      Options.CopyFrom(IOTAProject(Item.Data));
      OptionsId := GetProjectAssignment(IOTAProject(lvwProjects.Items[i].Data));
      if Pos('Local:', OptionsId) = 1 then
        EqualOpt := FSettings.FindByName(Copy(OptionsId, 7, MaxInt))
      else
        EqualOpt := FGlobalSettings.FindByName(Copy(OptionsId, 8, MaxInt));

      if EqualOpt = nil then
        EqualOpt := FSettings.FindEqual(Options);
      if EqualOpt = nil then
        EqualOpt := FGlobalSettings.FindEqual(Options);
      if EqualOpt <> nil then
      begin
        if not EqualOpt.Compare(Options) then
          Item.SubItems[0] := EqualOpt.Name + '*'
        else
          Item.SubItems[0] := EqualOpt.Name;
        Item.SubItems.Objects[0] := EqualOpt;
      end
      else
      begin
        Item.SubItems[0] := '';
        Item.SubItems.Objects[0] := nil;
      end;
    end;
  finally
    Options.Free;
  end;
end;

procedure TFormManageProjectSetting.SetProjectAssignment(Project: IOTAProject; const Value: string);
var
  Index: Integer;
begin
  Index := FProjectAssignments.IndexOfObject(Pointer(Project));
  if Index = -1 then
    FProjectAssignments.AddObject(Value, Pointer(Project))
  else
    FProjectAssignments[Index] := Value;
end;

function TFormManageProjectSetting.GetProjectAssignment(Project: IOTAProject): string;
var
  Index: Integer;
begin
  Index := FProjectAssignments.IndexOfObject(Pointer(Project));
  if Index <> -1 then
    Result := FProjectAssignments[Index]
  else
    Result := VarToStr(ProjectDataList[Project].Values[sProjectSettings]);
end;

procedure TFormManageProjectSetting.UpdateActions;
begin
  inherited UpdateActions;
  btnOk.Default := not (lvwLocal.IsEditing or lvwGlobal.IsEditing);
  btnCancel.Cancel := btnOk.Default;
end;

procedure TFormManageProjectSetting.ActionProjectUpdate(Sender: TObject);
begin
  if Sender = actProjectEditProjectOptions then
    actProjectEditProjectOptions.Enabled := (lvwProjects.SelCount = 1) and (lvwProjects.Selected <> nil)
  else if Sender = actProjectSetVersionInfo then
    actProjectSetVersionInfo.Enabled := lvwProjects.SelCount > 0;
end;

procedure TFormManageProjectSetting.ActionProjectExecute(Sender: TObject);
var
  i: Integer;
  List: TInterfaceList;
begin
  if Sender = actProjectEditProjectOptions then
  begin
    IOTAProject(lvwProjects.Selected.Data).ProjectOptions.EditOptions;
    RefreshProjectAssignment;
  end
  else if Sender = actProjectSetVersionInfo then
  begin
    List := TInterfaceList.Create;
    try
      for i := 0 to lvwProjects.Items.Count - 1 do
        if lvwProjects.Items[i].Selected then
          List.Add(IOTAProject(lvwProjects.Items[i].Data));
      TFormProjectSettingsSetVersioninfo.Execute(List);
    finally
      List.Free;
    end;
  end;
end;

end.

