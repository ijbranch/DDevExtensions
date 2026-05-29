{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmProjectSettingsSetVersioninfo;

/// <summary>
/// Hosts the multi-page "Set Version Info" dialog used to view, set, increment and bulk-apply
/// version-resource fields and the main icon across the projects of the active project group.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, ToolsAPI, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.ExtCtrls, FrmBase, Vcl.Buttons, Vcl.ExtDlgs,
  ProjectResource;

type
  /// <summary>Open-array alias of IOTAProject used to pass several projects through "for in" loops.</summary>
  IOTAProjectArray = array of IOTAProject;

  /// <summary>
  /// Modal dialog used to view, set, increment and bulk-apply VersionInfo string and numeric fields
  /// (and the main icon) across one or more projects.
  /// </summary>
  TFormProjectSettingsSetVersioninfo = class(TFormBase)
    /// <summary>Caption label for the Major file version field.</summary>
    lblFileVersionMajor: TLabel;
    /// <summary>Caption label for the Minor file version field.</summary>
    lblFileVersionMinor: TLabel;
    /// <summary>Caption label for the Release file version field.</summary>
    lblFileVersionRelease: TLabel;
    /// <summary>Edit box bound to udMajor for the file version major component.</summary>
    edtMajor: TEdit;
    /// <summary>Up/down spinner for the file version major component.</summary>
    udMajor: TUpDown;
    /// <summary>Edit box bound to udMinor for the file version minor component.</summary>
    edtMinor: TEdit;
    /// <summary>Up/down spinner for the file version minor component.</summary>
    udMinor: TUpDown;
    /// <summary>Edit box bound to udRelease for the file version release component.</summary>
    edtRelease: TEdit;
    /// <summary>Up/down spinner for the file version release component.</summary>
    udRelease: TUpDown;
    /// <summary>Caption label for the Product Version field.</summary>
    lblProductVersion: TLabel;
    /// <summary>Edit box for the free-text Product Version string.</summary>
    edtProductVersion: TEdit;
    /// <summary>Caption label for the file version block.</summary>
    lblFileVersion: TLabel;
    /// <summary>Container panel for the projects list.</summary>
    pnlProjects: TPanel;
    /// <summary>Caption label for the projects list.</summary>
    lblProjects: TLabel;
    /// <summary>List view of projects; checkbox column drives apply-to-selected behaviour.</summary>
    lvwProjects: TListView;
    /// <summary>Applies the Product Version string to the eligible projects.</summary>
    btnApplyProductVersion: TButton;
    /// <summary>Applies the Major/Minor/Release file version to the eligible projects.</summary>
    btnApplyFileVersion: TButton;
    /// <summary>Caption label for the Product Name field.</summary>
    lblProductName: TLabel;
    /// <summary>Edit box for the free-text Product Name string.</summary>
    edtProductName: TEdit;
    /// <summary>Applies the Product Name string to the eligible projects.</summary>
    btnApplyProductName: TButton;
    /// <summary>Caption label for the Build file version field.</summary>
    lblFileVersionBuild: TLabel;
    /// <summary>Edit box bound to udBuild for the file version build component.</summary>
    edtBuild: TEdit;
    /// <summary>Up/down spinner for the file version build component.</summary>
    udBuild: TUpDown;
    /// <summary>Applies the Build file version to the eligible projects.</summary>
    btnApplyBuild: TButton;
    /// <summary>Date picker for the project's build start date (used by btnDaysbetween).</summary>
    dtpStartDay: TDateTimePicker;
    /// <summary>Computes the number of days between dtpStartDay and today.</summary>
    btnDaysbetween: TButton;
    /// <summary>Read-only edit displaying the days-between result.</summary>
    edtDaysBetween: TEdit;
    /// <summary>Timer that hides the "applied" notification label after a short delay.</summary>
    TimerAppliedHide: TTimer;
    /// <summary>Caption label for dtpStartDay.</summary>
    lblStartDay: TLabel;
    /// <summary>Page control hosting the Set, Increment and Main Icon tabs.</summary>
    pgcPages: TPageControl;
    /// <summary>Tab page for the "Set Version Info" UI.</summary>
    tsSetVersionInfo: TTabSheet;
    /// <summary>Left container panel hosting the projects list.</summary>
    pnlLeft: TPanel;
    /// <summary>Bottom strip panel hosting the close button and applied notification.</summary>
    pnlBottom: TPanel;
    /// <summary>Visual divider above the bottom strip.</summary>
    bvlDivider: TBevel;
    /// <summary>Transient label that confirms an Apply has just succeeded.</summary>
    lblApplied: TLabel;
    /// <summary>Close button for the dialog.</summary>
    btnClose: TButton;
    /// <summary>Tab page for the "Increment Version Info" UI.</summary>
    tsIncrementVersionInfo: TTabSheet;
    /// <summary>Main client panel for the Increment tab.</summary>
    pnlClient: TPanel;
    /// <summary>Increment Major component on Execute.</summary>
    cbxIncMajor: TCheckBox;
    /// <summary>Increment Minor component on Execute.</summary>
    cbxIncMinor: TCheckBox;
    /// <summary>Increment Release component on Execute.</summary>
    cbxIncRelease: TCheckBox;
    /// <summary>Increment Build component on Execute.</summary>
    cbxIncBuild: TCheckBox;
    /// <summary>Reset Minor to zero when Major is incremented.</summary>
    cbxZeroMinor: TCheckBox;
    /// <summary>Reset Release to zero when Major is incremented.</summary>
    cbxZeroRelease: TCheckBox;
    /// <summary>Reset Release to zero when Minor is incremented.</summary>
    cbxZeroRelease2: TCheckBox;
    /// <summary>Performs the configured version increment on the eligible projects.</summary>
    btnExecuteIncrement: TButton;
    /// <summary>If checked, Apply only affects projects whose row is checked.</summary>
    cbxApplyToSelectedOnly: TCheckBox;
    /// <summary>Edit box bound to udIncMajor (increment-by amount for Major).</summary>
    edtIncMajor: TEdit;
    /// <summary>Up/down spinner for the increment-by amount for Major.</summary>
    udIncMajor: TUpDown;
    /// <summary>Edit box bound to udIncMinor (increment-by amount for Minor).</summary>
    edtIncMinor: TEdit;
    /// <summary>Up/down spinner for the increment-by amount for Minor.</summary>
    udIncMinor: TUpDown;
    /// <summary>Edit box bound to udIncRelease (increment-by amount for Release).</summary>
    edtIncRelease: TEdit;
    /// <summary>Up/down spinner for the increment-by amount for Release.</summary>
    udIncRelease: TUpDown;
    /// <summary>Edit box bound to udIncBuild (increment-by amount for Build).</summary>
    edtIncBuild: TEdit;
    /// <summary>Up/down spinner for the increment-by amount for Build.</summary>
    udIncBuild: TUpDown;
    /// <summary>Caption label for the Company Name field.</summary>
    lblCompanyName: TLabel;
    /// <summary>Edit box for the free-text Company Name string.</summary>
    edtCompanyName: TEdit;
    /// <summary>Applies the Company Name string to the eligible projects.</summary>
    btnApplyCompanyName: TButton;
    /// <summary>Caption label for the Legal Copyright field.</summary>
    lblLegalCopyright: TLabel;
    /// <summary>Edit box for the free-text Legal Copyright string.</summary>
    edtLegalCopyright: TEdit;
    /// <summary>Applies the Legal Copyright string to the eligible projects.</summary>
    btnApplyLegalCopyright: TButton;
    /// <summary>Tab page for the "Main Icon" UI.</summary>
    tsMainIcon: TTabSheet;
    /// <summary>Caption label for the icon images list.</summary>
    lblMainIcons: TLabel;
    /// <summary>Saves the loaded icon to the eligible projects' main icon resource.</summary>
    btnApplyMainIcon: TButton;
    /// <summary>Loads a new icon from a file into FIcon.</summary>
    btnLoadMainIcon: TBitBtn;
    /// <summary>Common Open dialog used to pick an icon file.</summary>
    dlgOpenMainIcon: TOpenPictureDialog;
    /// <summary>Paint box that previews the currently selected icon image.</summary>
    pbxMainIcon: TPaintBox;
    /// <summary>List of images contained in the loaded icon (size/colour-depth).</summary>
    lbxMainIcons: TListBox;
    /// <summary>Clears the loaded icon (FIcon).</summary>
    btnRemoveMainIcon: TBitBtn;
    /// <summary>Help text describing how to change the main icon.</summary>
    lblChangeMainIcon: TLabel;
    /// <summary>If checked, version writes apply to all build configurations/platforms.</summary>
    cbxApplyToAllPlatforms: TCheckBox;
    /// <summary>Caption label for the Legal Trademarks field.</summary>
    lblLegalTrademarks: TLabel;
    /// <summary>Edit box for the free-text Legal Trademarks string.</summary>
    edtLegalTrademarks: TEdit;
    /// <summary>Applies the Legal Trademarks string to the eligible projects.</summary>
    btnApplyLegalTrademarks: TButton;
    /// <summary>Caption label for the File Description field.</summary>
    LblFileDescription: TLabel;
    /// <summary>Edit box for the free-text File Description string.</summary>
    edtFileDescription: TEdit;
    /// <summary>Applies the File Description string to the eligible projects.</summary>
    btnApplyFileDescription: TButton;
    /// <summary>Caption label for the Internal Name field.</summary>
    LblInternalName: TLabel;
    /// <summary>Edit box for the free-text Internal Name string.</summary>
    edtInternalName: TEdit;
    /// <summary>Applies the Internal Name string to the eligible projects.</summary>
    btnApplyInternalName: TButton;
    /// <summary>Caption label for the Original Filename field.</summary>
    LblOriginalFilename: TLabel;
    /// <summary>Edit box for the free-text Original Filename string.</summary>
    edtOriginalFilename: TEdit;
    /// <summary>Applies the Original Filename string to the eligible projects.</summary>
    btnApplyOriginalFilename: TButton;
    /// <summary>Caption label for the Comments field.</summary>
    LblComment: TLabel;
    /// <summary>Edit box for the free-text Comments string.</summary>
    edtComments: TEdit;
    /// <summary>Applies the Comments string to the eligible projects.</summary>
    btnApplyComments: TButton;
    /// <summary>Sets each project's Original Filename to its target output file name.</summary>
    btnApplyAutoSetOriginalFilename: TButton;
    /// <summary>Reflects the OnExit of an edit field into its corresponding TUpDown spinner.</summary>
    procedure edtFileVersionExit(Sender: TObject);
    /// <summary>Loads the version-info fields for the newly selected project.</summary>
    procedure lvwProjectsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    /// <summary>Greys out projects without a valid VersionInfo resource on non-icon tabs.</summary>
    procedure lvwProjectsCustomDrawItem(Sender: TCustomListView;
      Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
    /// <summary>Generic Apply handler that writes the corresponding string field to the projects.</summary>
    procedure btnApplyStringClick(Sender: TObject);
    /// <summary>Applies the file version triplet (Major/Minor/Release) to the projects.</summary>
    procedure btnApplyFileVersionClick(Sender: TObject);
    /// <summary>Computes today minus the start day and writes the value to edtDaysBetween.</summary>
    procedure btnDaysbetweenClick(Sender: TObject);
    /// <summary>Hides the "applied" notification when the timer elapses.</summary>
    procedure TimerAppliedHideTimer(Sender: TObject);
    /// <summary>Applies the Build component of the file version to the projects.</summary>
    procedure btnApplyBuildClick(Sender: TObject);
    /// <summary>Initialises FIcon, sets default tab and adjusts platform check visibility.</summary>
    procedure FormCreate(Sender: TObject);
    /// <summary>Enables/disables Major-related sub-options based on cbxIncMajor.</summary>
    procedure cbxIncMajorClick(Sender: TObject);
    /// <summary>Enables/disables Minor-related sub-options based on cbxIncMinor.</summary>
    procedure cbxIncMinorClick(Sender: TObject);
    /// <summary>Performs the configured version increment across the eligible projects.</summary>
    procedure btnExecuteIncrementClick(Sender: TObject);
    /// <summary>Toggles the apply-to-selected-only mode and updates UI accordingly.</summary>
    procedure cbxApplyToSelectedOnlyClick(Sender: TObject);
    /// <summary>Enables/disables Release-related sub-options based on cbxIncRelease.</summary>
    procedure cbxIncReleaseClick(Sender: TObject);
    /// <summary>Enables/disables Build-related sub-options based on cbxIncBuild.</summary>
    procedure cbxIncBuildClick(Sender: TObject);
    /// <summary>Loads a new icon from disk into FIcon.</summary>
    procedure btnLoadMainIconClick(Sender: TObject);
    /// <summary>Writes the loaded icon to the eligible projects' main icon resource.</summary>
    procedure btnApplyMainIconClick(Sender: TObject);
    /// <summary>Refreshes the icon preview when a different icon image is selected.</summary>
    procedure lbxMainIconsClick(Sender: TObject);
    /// <summary>Frees FIcon when the form is destroyed.</summary>
    procedure FormDestroy(Sender: TObject);
    /// <summary>Renders the currently selected icon image inside pbxMainIcon.</summary>
    procedure pbxMainIconPaint(Sender: TObject);
    /// <summary>Clears the loaded icon and updates the preview.</summary>
    procedure btnRemoveMainIconClick(Sender: TObject);
    /// <summary>Triggers a redraw of lvwProjects when the active page changes.</summary>
    procedure pgcPagesChange(Sender: TObject);
    /// <summary>Sets each project's Original Filename to ExtractFileName(TargetName).</summary>
    procedure btnApplyAutoSetOriginalFilenameClick(Sender: TObject);
  private
    { Private-Deklarationen }
    /// <summary>Working icon resource used by the Main Icon tab.</summary>
    FIcon: TIconResource;
    /// <summary>Populates the projects list, runs the dialog and persists settings on close.</summary>
    function DoExecute(Projects: TInterfaceList): Boolean; virtual;
    /// <summary>Returns the file creation date/time of the project's main file.</summary>
    function GetStartDateTimeOf(const Project: IOTAProject): TDateTime;
    /// <summary>Loads persisted dialog settings (apply-to-selected and platform flags).</summary>
    procedure LoadSettings;
    /// <summary>Saves persisted dialog settings (apply-to-selected and platform flags).</summary>
    procedure SaveSettings;
    /// <summary>Returns the projects eligible for the current Apply (respecting the checkbox filter).</summary>
    function GetValidApplyProjects: IOTAProjectArray;
    /// <summary>Returns True if at least one project is eligible for the current Apply.</summary>
    function HasValidProjects: Boolean;
    /// <summary>Returns the currently selected project if it has a valid VersionInfo resource.</summary>
    function GetSelectedApplyProject: IOTAProject;
  protected
    /// <summary>Refreshes the Main Icon preview and the icon-images list.</summary>
    procedure UpdateMainIconPreview;
    /// <summary>Recomputes which Apply buttons are enabled based on the current state.</summary>
    procedure UpdateActions; override;
    /// <summary>Shows the transient "applied" notification with the supplied (or default) text.</summary>
    procedure ApplyFinished(const Text: string = '');
  public
    { Public-Deklarationen }
    /// <summary>Creates the form, runs the dialog over the supplied projects and frees the form.</summary>
    /// <param name="Projects">Projects whose version info should be edited.</param>
    /// <returns>True if the user confirmed with OK.</returns>
    class function Execute(Projects: TInterfaceList): Boolean;
  end;

/// <summary>Plugin entry point that creates or frees the global TVersionInfoHandler.</summary>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  IDEUtils, IDEHooks, Hooking, DtmImages,
  Vcl.ActnList, Vcl.Menus, AppConsts, ToolsAPIHelpers, System.DateUtils, System.Math, PluginConfig, SimpleXmlIntf;

{$R *.dfm}

type
  TVersionInfoHandler = class(TComponent)
  private
    FMenuItemSetVersionInfo: TMenuItem;
    FActionSetVersionInfo: TAction;
    FActionList: TActionList;
  public
    constructor Create(AOwner: TComponent); override;

    procedure DoUpdateSetVersionInfo(Sender: TObject = nil);
    procedure DoSetVersionInfo(Sender: TObject = nil);
  end;

var
  VersionInfoHandler: TVersionInfoHandler;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    VersionInfoHandler := TVersionInfoHandler.Create(nil)
  else
    FreeAndNil(VersionInfoHandler);
end;

{ TVersionInfoHandler }

constructor TVersionInfoHandler.Create(AOwner: TComponent);
var
  ProjectMenu: TMenuItem;
begin
  inherited Create(AOwner);
  FActionList := TActionList.Create(Self);
  FActionList.Images := DataModuleImages.imlIcons;

  ProjectMenu := FindMenuItem('ProjectMenu');
  if ProjectMenu <> nil then
  begin
    { "Set Versioninfo..." }
    FActionSetVersionInfo := TAction.Create(Self);
    FActionSetVersionInfo.ActionList := FActionList;
    FActionSetVersionInfo.Caption := sMenuItemSetVersionInfo;
    FActionSetVersionInfo.OnUpdate := DoUpdateSetVersionInfo;
    FActionSetVersionInfo.OnExecute := DoSetVersionInfo;
    FActionSetVersionInfo.ImageIndex := 7;

    FMenuItemSetVersionInfo := TMenuItem.Create(Self);
    FMenuItemSetVersionInfo.Name := 'ProjectSetVersionInfoItem';
    FMenuItemSetVersionInfo.Action := FActionSetVersionInfo;

    { add menu items }
    ProjectMenu.Add(FMenuItemSetVersionInfo);
  end;
end;

procedure TVersionInfoHandler.DoUpdateSetVersionInfo(Sender: TObject);
var
  Group: IOTAProjectGroup;
begin
  Group := GetActiveProjectGroup;
  FActionSetVersionInfo.Enabled := (Group <> nil) and (Group.ProjectCount > 0)
    and (GetActiveProject <> nil)
    and ((GetActiveProject.GetPersonality = sDelphiPersonality) or
         (GetActiveProject.GetPersonality = sCBuilderPersonality));
end;

procedure TVersionInfoHandler.DoSetVersionInfo(Sender: TObject);
var
  I: Integer;
  List: TInterfaceList;
  Group: IOTAProjectGroup;
begin
  Group := GetActiveProjectGroup;
  if Assigned(Group) then
  begin
    List := TInterfaceList.Create;
    try
      for I := 0 to Group.ProjectCount - 1 do
        List.Add(Group.Projects[I]);
      TFormProjectSettingsSetVersioninfo.Execute(List);
    finally
      List.Free;
    end;
  end;
end;


{ TFormProjectSettingsSetVersioninfo }

class function TFormProjectSettingsSetVersioninfo.Execute(Projects: TInterfaceList): Boolean;
begin
  with Self.Create(nil) do
  try
    Result := DoExecute(Projects);
  finally
    Free;
  end;
end;

function TFormProjectSettingsSetVersioninfo.DoExecute(Projects: TInterfaceList): Boolean;
var
  I: Integer;
  Version: TProjectVersion;
  Item: TListItem;
  Project: IOTAProject;
begin
  LoadSettings;

  lvwProjects.Items.BeginUpdate;
  try
    lvwProjects.Items.Clear;
    for I := 0 to Projects.Count - 1 do
    begin
      Project := IOTAProject(Projects[I]);
      Item := lvwProjects.Items.Add;
      Item.Caption := ExtractFileName(Project.FileName);
      Item.Data := Pointer(Project);
      Version := GetProjectVersion(Project);
      if Version.Valid then
      begin
        Item.SubItems.Add('');
        Item.ImageIndex := 4;
      end
      else
      begin
        Item.SubItems.Add('no resource');
        Item.ImageIndex := 8;
      end;
    end;
    if lvwProjects.Items.Count > 0 then
      lvwProjects.Selected := lvwProjects.Items[0];
  finally
    lvwProjects.Items.EndUpdate;
  end;
  Result := ShowModal = mrOk;

  SaveSettings;
end;

procedure TFormProjectSettingsSetVersioninfo.SaveSettings;
var
  Node: IXmlNode;
begin
  Node := Configuration.GetNode('ProjectSetVersionInfo');
  Node.Attributes['ApplyToSelected'] := cbxApplyToSelectedOnly.Checked;
  Node.Attributes['ApplyToAllPlatforms'] := cbxApplyToAllPlatforms.Checked;
  Configuration.Modified;
end;

procedure TFormProjectSettingsSetVersioninfo.LoadSettings;
var
  Node: IXmlNode;
begin
  Node := Configuration.FindNode('ProjectSetVersionInfo');
  if Node <> nil then
  begin
    cbxApplyToSelectedOnly.Checked := VarToBoolDef(Node.Attributes['ApplyToSelected'], False);
    cbxApplyToAllPlatforms.Checked := VarToBoolDef(Node.Attributes['ApplyToAllPlatforms'], False);
  end;

  cbxApplyToSelectedOnlyClick(cbxApplyToSelectedOnly);
end;

function TFormProjectSettingsSetVersioninfo.GetSelectedApplyProject: IOTAProject;
var
  Item: TListItem;
begin
  Result := nil;
  Item := lvwProjects.Selected;
  if (Item <> nil) then
    if (Item.SubItems.Count = 0) or (Item.SubItems[0] = '') then // Has valid version resource then
      Result := IOTAProject(Item.Data);
end;

function TFormProjectSettingsSetVersioninfo.GetValidApplyProjects: IOTAProjectArray;
var
  I, Count: Integer;
  ApplyToSelectedOnly: Boolean;
  Item: TListItem;
  SelProject: IOTAProject;
begin
  ApplyToSelectedOnly := cbxApplyToSelectedOnly.Checked;
  SetLength(Result, lvwProjects.Items.Count); // worst case

  Count := 0;
  for I := 0 to lvwProjects.Items.Count - 1 do
  begin
    Item := lvwProjects.Items[I];
    if (Item.SubItems.Count = 0) or (Item.SubItems[0] = '') then // Has valid version resource
    begin
      if not ApplyToSelectedOnly or lvwProjects.Items[I].Checked then
      begin
        Result[Count] := IOTAProject(lvwProjects.Items[I].Data);
        Inc(Count);
      end;
    end;
  end;

  if (Count = 0) and ApplyToSelectedOnly then
  begin
    SelProject := GetSelectedApplyProject;
    if SelProject <> nil then
    begin
      Result[0] := SelProject;
      Count := 1;
    end;
  end;

  SetLength(Result, Count);
end;

function TFormProjectSettingsSetVersioninfo.HasValidProjects: Boolean;
var
  I: Integer;
  ApplyToSelectedOnly: Boolean;
  Item: TListItem;
begin
  ApplyToSelectedOnly := cbxApplyToSelectedOnly.Checked;
  Result := True;
  for I := 0 to lvwProjects.Items.Count - 1 do
  begin
    Item := lvwProjects.Items[I];
    if (Item.SubItems.Count = 0) or (Item.SubItems[0] = '') then // Has valid version resource
      if not ApplyToSelectedOnly or lvwProjects.Items[I].Checked then
        Exit;
  end;

  if ApplyToSelectedOnly and (GetSelectedApplyProject <> nil) then
    Exit;

  Result := False;
end;

function TFormProjectSettingsSetVersioninfo.GetStartDateTimeOf(const Project: IOTAProject): TDateTime;
var
  sh: THandle;
  Data: TWin32FindData;
  LocalFileTime: TFileTime;
  SystemTime: TSystemTime;
begin
  Result := Date;
  if Project <> nil then
  begin
    { Get file creation time }
    sh := FindFirstFile(PChar(Project.FileName), Data);
    if sh <> INVALID_HANDLE_VALUE then
    begin
      Winapi.Windows.FindClose(sh);
      FileTimeToLocalFileTime(Data.ftCreationTime, LocalFileTime);
      FileTimeToSystemTime(LocalFileTime, SystemTime);
      with SystemTime do
        Result := EncodeDate(wYear, wMonth, wDay) +
                  EncodeTime(wHour, wMinute, wSecond, wMilliSeconds);
    end
  end;
end;

procedure TFormProjectSettingsSetVersioninfo.lvwProjectsSelectItem(
  Sender: TObject; Item: TListItem; Selected: Boolean);
var
  Version: TProjectVersion;
begin
  if csDestroying in ComponentState then
    Exit;

  Version.Valid := False;
  if Selected then
  begin
    Version := GetProjectVersion(IOTAProject(Item.Data));
    {if not Version.Valid then
      lvwProjects.Selected := nil;}
  end;
  if Version.Valid then
  begin
    udMajor.Position := Version.FileVersion.Major;
    udMinor.Position := Version.FileVersion.Minor;
    udRelease.Position := Version.FileVersion.Release;
    udBuild.Position := Version.FileVersion.Build;
    edtProductVersion.Text := Version.ProductVersionStr;
    edtProductName.Text := Version.ProductName;
    edtCompanyName.Text := Version.CompanyName;
    edtLegalCopyright.Text := Version.LegalCopyright;
    edtLegalTrademarks.Text := Version.LegalTrademarks;
    edtFileDescription.Text := Version.FileDescription;
    edtInternalName.Text := Version.InternalName;
    edtOriginalFilename.Text := Version.OriginalFilename;
    edtComments.Text := Version.Comments;

    dtpStartDay.Date := GetStartDateTimeOf(IOTAProject(Item.Data));
  end
  else
  begin
    udMajor.Position := 1;
    udMinor.Position := 0;
    udRelease.Position := 0;
    udBuild.Position := 0;
    edtProductVersion.Text := '';
    edtProductName.Text := '';
    edtCompanyName.Text := '';
    edtLegalCopyright.Text := '';
    edtLegalTrademarks.Text := '';
    edtFileDescription.Text := '';
    edtInternalName.Text := '';
    edtOriginalFilename.Text := '';
    edtComments.Text := '';
  end;
  FIcon.LoadFromProjectResource(IOTAProject(Item.Data));
  UpdateMainIconPreview;
end;

procedure TFormProjectSettingsSetVersioninfo.pbxMainIconPaint(Sender: TObject);
var
  Ico: HICON;
  Index: Integer;
  Item: TIconResourceItem;
  R: TRect;
begin
  Index := lbxMainIcons.ItemIndex;
  if Index = -1 then
    Index := 0;
  if Index >= FIcon.Count then
    Exit;
  Ico := FIcon.GetPaintIcon(Index);
  if Ico = 0 then
    Exit;

  Item := FIcon.Images[Index];

  R := Rect(0, 0, Max(48, Item.Width), Max(48, Item.Height));
  InflateRect(R, 4, 4);
  OffsetRect(R, -R.Left, -R.Top);

  if Ico <> 0 then
    DrawIconEx(
      pbxMainIcon.Canvas.Handle,
      R.Left + (R.Right - R.Left - Item.Width) div 2,
      R.Top + (R.Bottom - R.Top - Item.Height) div 2,
      Ico, Item.Width, Item.Height, 0, 0, DI_NORMAL
    );

  { Border }
  Inc(R.Right);
  Inc(R.Bottom);
  pbxMainIcon.Canvas.Brush.Style := bsClear;
  pbxMainIcon.Canvas.Pen.Color := $FF9933;
  pbxMainIcon.Canvas.Pen.Width := 2;
  pbxMainIcon.Canvas.RoundRect(R, 8, 8);
  pbxMainIcon.Canvas.Pen.Width := 1;
  InflateRect(R, -1, -1);
  pbxMainIcon.Canvas.RoundRect(R, 7, 7);
end;

procedure TFormProjectSettingsSetVersioninfo.pgcPagesChange(Sender: TObject);
begin
  lvwProjects.Invalidate;
end;

procedure TFormProjectSettingsSetVersioninfo.lbxMainIconsClick(Sender: TObject);
begin
  pbxMainIcon.Invalidate;
end;

procedure TFormProjectSettingsSetVersioninfo.lvwProjectsCustomDrawItem(
  Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
  var DefaultDraw: Boolean);
begin
  DefaultDraw := True;
  if (Item.SubItems.Count > 0) and (Item.SubItems[0] <> '') and (pgcPages.ActivePage <> tsMainIcon) then
    Sender.Canvas.Font.Color := clSilver;
end;

procedure TFormProjectSettingsSetVersioninfo.btnApplyStringClick(Sender: TObject);

  function GetVersionPString(var {ref} Version: TProjectVersion): PString;
  begin
    if Sender = btnApplyProductName then
      Result := @Version.ProductName

    else if Sender = btnApplyProductVersion then
      Result := @Version.ProductVersionStr

    else if Sender = btnApplyCompanyName then
      Result := @Version.CompanyName

    else if Sender = btnApplyLegalCopyright then
      Result := @Version.LegalCopyright

    else if Sender = btnApplyLegalTrademarks then
      Result := @Version.LegalTrademarks

    else if Sender = btnApplyFileDescription then
      Result := @Version.FileDescription

    else if Sender = btnApplyInternalName then
      Result := @Version.InternalName

    else if Sender = btnApplyComments then
      Result := @Version.Comments

    else if Sender = btnApplyOriginalFilename then
      Result := @Version.OriginalFilename

    else
      raise Exception.CreateFmt('Unhandled Apply button: %s', [(Sender as TComponent).Name]);
  end;

var
  Version: TProjectVersion;
  Value: string;
  Edit: TEdit;
  EditName: string;
  P: PString;
  Project: IOTAProject;
  Projects: IOTAProjectArray;
begin
  EditName := 'edt' + Copy((Sender as TComponent).Name, Length('btnApply') + 1, MaxInt);
  Edit := FindComponent(EditName) as TEdit;
  Assert( Edit <> nil, 'Edit "' + EditName + '" not found' );

  Value := Trim(Edit.Text);
  if Sender = btnApplyOriginalFilename then // Apply to this
  begin
    Project := GetSelectedApplyProject();
    if Project <> nil then
      Projects := IOTAProjectArray.Create(Project)
    else
      Projects := nil;
  end
  else
    Projects := GetValidApplyProjects();

  for Project in Projects do
  begin
    Version := GetProjectVersion(Project);
    if Version.Valid then
    begin
      P := GetVersionPString(Version);
      if P^ <> Value then
      begin
        P^ := Value;
        SetProjectVersion(Project, Version, cbxApplyToAllPlatforms.Checked);
      end;
    end;
  end;
  ApplyFinished;
end;

procedure TFormProjectSettingsSetVersioninfo.btnLoadMainIconClick(Sender: TObject);
begin
  if dlgOpenMainIcon.Execute then
  begin
    FIcon.LoadFromIconFile(dlgOpenMainIcon.FileName);
    UpdateMainIconPreview;
  end;
end;

procedure TFormProjectSettingsSetVersioninfo.btnRemoveMainIconClick(Sender: TObject);
begin
  FIcon.Clear;
  UpdateMainIconPreview;
end;

procedure TFormProjectSettingsSetVersioninfo.btnApplyFileVersionClick(Sender: TObject);
var
  Project: IOTAProject;
  Version: TProjectVersion;
begin
  for Project in GetValidApplyProjects() do
  begin
    Version := GetProjectVersion(Project);
    if Version.Valid and
      ((udMajor.Position <> SmallInt(Version.FileVersion.Major)) or
       (udMinor.Position <> SmallInt(Version.FileVersion.Minor)) or
       (udRelease.Position <> SmallInt(Version.FileVersion.Release))) then
    begin
      Version.FileVersion.Major := udMajor.Position;
      Version.FileVersion.Minor := udMinor.Position;
      Version.FileVersion.Release := udRelease.Position;
      with Version.FileVersion do
        Version.FileVersionStr := Format('%d.%d.%d.%d', [Major, Minor, Release, Build]);
      SetProjectVersion(Project, Version, cbxApplyToAllPlatforms.Checked);
    end;
  end;
  ApplyFinished;
end;

procedure TFormProjectSettingsSetVersioninfo.btnApplyMainIconClick(Sender: TObject);
var
  Project: IOTAProject;
begin
  for Project in GetValidApplyProjects() do
    FIcon.SaveToProjectResource(Project);
  ApplyFinished('Main Icons replaced.');
end;

procedure TFormProjectSettingsSetVersioninfo.btnApplyAutoSetOriginalFilenameClick(Sender: TObject);
var
  Project: IOTAProject;
  Version: TProjectVersion;
  Value: string;
begin
  for Project in GetValidApplyProjects() do
  begin
    Version := GetProjectVersion(Project);
    if Version.Valid then
    begin
      Value := ExtractFileName(Project.ProjectOptions.TargetName);
      if Value <> Version.OriginalFilename then
      begin
        Version.OriginalFilename := Value;
        SetProjectVersion(Project, Version, cbxApplyToAllPlatforms.Checked);
      end;
    end;
  end;
  // Update selected version info
  if GetSelectedApplyProject <> nil then
  begin
    Version := GetProjectVersion(GetSelectedApplyProject);
    edtOriginalFilename.Text := Version.OriginalFilename;
  end;
  ApplyFinished;
end;

procedure TFormProjectSettingsSetVersioninfo.btnApplyBuildClick(Sender: TObject);
var
  Project: IOTAProject;
  Version: TProjectVersion;
  Value: Integer;
begin
  Value := udBuild.Position;
  for Project in GetValidApplyProjects() do
  begin
    Version := GetProjectVersion(Project);
    if Version.Valid and (SmallInt(Version.FileVersion.Build) <> Value) then
    begin
      Version.FileVersion.Build := Value;
      with Version.FileVersion do
        Version.FileVersionStr := Format('%d.%d.%d.%d', [Major, Minor, Release, Build]);
      SetProjectVersion(Project, Version, cbxApplyToAllPlatforms.Checked);
    end;
  end;
  ApplyFinished;
end;

procedure TFormProjectSettingsSetVersioninfo.UpdateActions;
var
  ValidProjectsAvailable: Boolean;
begin
  inherited UpdateActions;

  { Check if there is at least one project that has a VersionInfo resource }
  ValidProjectsAvailable := HasValidProjects();

  { Enable the Apply buttons }
  btnApplyProductVersion.Enabled := (Trim(edtProductVersion.Text) <> '') and ValidProjectsAvailable;
  btnApplyProductName.Enabled := {(Trim(edtProductName.Text) <> '') and} ValidProjectsAvailable;
  btnApplyCompanyName.Enabled := {(Trim(edtCompanyName.Text) <> '') and} ValidProjectsAvailable;
  btnApplyLegalCopyright.Enabled := {(Trim(edtLegalCopyright.Text) <> '') and} ValidProjectsAvailable;
  btnApplyLegalTrademarks.Enabled := {(Trim(edtLegalTrademarks.Text) <> '') and} ValidProjectsAvailable;
  btnApplyFileDescription.Enabled := {(Trim(edtFileDescription.Text) <> '') and} ValidProjectsAvailable;
  btnApplyInternalName.Enabled := {(Trim(edtInternalName.Text) <> '') and} ValidProjectsAvailable;
  btnApplyComments.Enabled := {(Trim(edtComments.Text) <> '') and} ValidProjectsAvailable;
  btnApplyOriginalFilename.Enabled := GetSelectedApplyProject <> nil;
  btnApplyAutoSetOriginalFilename.Enabled := ValidProjectsAvailable;

  btnApplyBuild.Enabled := (Trim(edtBuild.Text) <> '') and ValidProjectsAvailable;
  btnApplyFileVersion.Enabled := (Trim(edtMajor.Text) <> '') and
                                 (Trim(edtMinor.Text) <> '') and
                                 (Trim(edtRelease.Text) <> '') and
                                 ValidProjectsAvailable;

  if pgcPages.ActivePage = tsIncrementVersionInfo then
  begin
    btnExecuteIncrement.Enabled := ValidProjectsAvailable and
                                   (cbxIncMajor.Checked or cbxIncMinor.Checked or
                                    cbxIncRelease.Checked or cbxIncBuild.Checked);

    cbxIncMinor.Enabled := not cbxIncMajor.Checked or not cbxZeroMinor.Checked;
    if not cbxIncMinor.Enabled then
      cbxIncMinor.Checked := False;
    cbxIncRelease.Enabled := (not cbxIncMajor.Checked or not cbxZeroRelease.Checked) and
                             (not cbxIncMinor.Checked or not cbxZeroRelease2.Checked);
    if not cbxIncRelease.Enabled then
      cbxIncRelease.Checked := False;

    cbxIncMajorClick(cbxIncMajor);
    cbxIncMinorClick(cbxIncMinor);
    cbxIncReleaseClick(cbxIncRelease);
    cbxIncBuildClick(cbxIncBuild);
  end;
end;

procedure TFormProjectSettingsSetVersioninfo.UpdateMainIconPreview;
var
  I: Integer;
  Item: TIconResourceItem;
begin
  lbxMainIcons.Items.BeginUpdate;
  try
    lbxMainIcons.Items.Clear;
    for I := 0 to FIcon.Count - 1 do
    begin
      Item := FIcon.Images[I];
      lbxMainIcons.AddItem(Format('%dx%d - %d', [Item.Width, Item.Height, Item.BitCount]), TObject(I));
    end;
  finally
    lbxMainIcons.Items.EndUpdate;
  end;
  if lbxMainIcons.Items.Count > 0 then
    lbxMainIcons.ItemIndex := 0;
  pbxMainIcon.Invalidate;
end;

procedure TFormProjectSettingsSetVersioninfo.ApplyFinished(const Text: string);
begin
  if Text = '' then
    lblApplied.Caption := 'Versioninfo updated.'
  else
    lblApplied.Caption := Text;
  lblApplied.Visible := True;
  TimerAppliedHide.Enabled := False; // reset timer
  TimerAppliedHide.Enabled := True;
end;

procedure TFormProjectSettingsSetVersioninfo.btnDaysbetweenClick(
  Sender: TObject);
begin
  edtDaysBetween.Text := IntToStr(Trunc(Date) - Trunc(dtpStartDay.Date));
end;

procedure TFormProjectSettingsSetVersioninfo.TimerAppliedHideTimer(Sender: TObject);
begin
  TimerAppliedHide.Enabled := False;
  lblApplied.Visible := False;
end;

procedure TFormProjectSettingsSetVersioninfo.edtFileVersionExit(Sender: TObject);
var
  Value: Integer;
begin
  if TryStrToInt((Sender as TEdit).Text, Value) then
    (FindComponent('ud' + Copy(TComponent(Sender).Name, 4, MaxInt)) as TUpDown).Position := Value;
end;

procedure TFormProjectSettingsSetVersioninfo.FormCreate(Sender: TObject);
begin
  FIcon := TIconResource.Create;
  dtpStartDay.Date := Date;
  pgcPages.ActivePageIndex := 0;
  btnClose.Anchors := [akTop, akRight];
  {$IF CompilerVersion >= 23.0} // Delphi XE2+
  {$ELSE}
  cbxApplyToAllPlatforms.Visible := False;
  {$IFEND}
end;

procedure TFormProjectSettingsSetVersioninfo.FormDestroy(Sender: TObject);
begin
  inherited;
  FIcon.Free;
end;

procedure TFormProjectSettingsSetVersioninfo.cbxIncMajorClick(Sender: TObject);
begin
  cbxZeroMinor.Enabled := cbxIncMajor.Checked;
  cbxZeroRelease.Enabled := cbxIncMajor.Checked;
  edtIncMajor.Enabled := cbxIncMajor.Checked;
  udIncMajor.Enabled := cbxIncMajor.Checked;
end;

procedure TFormProjectSettingsSetVersioninfo.cbxIncMinorClick(Sender: TObject);
begin
  cbxZeroRelease2.Enabled := cbxIncMinor.Checked;
  edtIncMinor.Enabled := cbxIncMinor.Checked;
  udIncMinor.Enabled := cbxIncMinor.Checked;
end;

procedure TFormProjectSettingsSetVersioninfo.btnExecuteIncrementClick(Sender: TObject);
var
  Project: IOTAProject;
  Version: TProjectVersion;
begin
  for Project in GetValidApplyProjects() do
  begin
    Version := GetProjectVersion(Project);
    if Version.Valid then
    begin
      if cbxIncBuild.Checked then
        Inc(Version.FileVersion.Build, udIncBuild.Position);
      if cbxIncRelease.Checked then
        Inc(Version.FileVersion.Release, udIncRelease.Position);
      if cbxIncMinor.Checked then
      begin
        Inc(Version.FileVersion.Minor, udIncMinor.Position);
        if cbxZeroRelease2.Checked then
          Version.FileVersion.Release := 0;
      end;
      if cbxIncMajor.Checked then
      begin
        Inc(Version.FileVersion.Major, udIncMajor.Position);
        if cbxZeroMinor.Checked then
          Version.FileVersion.Minor := 0;
        if cbxZeroRelease.Checked then
          Version.FileVersion.Release := 0;
      end;

      with Version.FileVersion do
        Version.FileVersionStr := Format('%d.%d.%d.%d', [Major, Minor, Release, Build]);
      SetProjectVersion(Project, Version, cbxApplyToAllPlatforms.Checked);
    end;
  end;
  ApplyFinished;
end;

procedure TFormProjectSettingsSetVersioninfo.cbxApplyToSelectedOnlyClick(Sender: TObject);
var
  ApplyStr: string;
begin
  if cbxApplyToSelectedOnly.Checked then
    ApplyStr := 'Apply'
  else
    ApplyStr := 'Apply to all';
  btnApplyProductVersion.Caption := ApplyStr;
  btnApplyFileVersion.Caption := ApplyStr;
  btnApplyProductName.Caption := ApplyStr;
  btnApplyCompanyName.Caption := ApplyStr;
  btnApplyLegalCopyright.Caption := ApplyStr;
  btnApplyLegalTrademarks.Caption := ApplyStr;
  btnApplyFileDescription.Caption := ApplyStr;
  btnApplyInternalName.Caption := ApplyStr;
  btnApplyComments.Caption := ApplyStr;
  //btnApplyOriginalFilename.Caption := do not change;
  if cbxApplyToSelectedOnly.Checked then
    btnApplyAutoSetOriginalFilename.Caption := 'Auto set'
  else
    btnApplyAutoSetOriginalFilename.Caption := 'Auto set to all';

  btnApplyBuild.Caption := ApplyStr;
  btnApplyMainIcon.Caption := ApplyStr;

  lvwProjects.Checkboxes := cbxApplyToSelectedOnly.Checked;
end;

procedure TFormProjectSettingsSetVersioninfo.cbxIncReleaseClick(Sender: TObject);
begin
  edtIncRelease.Enabled := cbxIncRelease.Checked;
  udIncRelease.Enabled := cbxIncRelease.Checked;
end;

procedure TFormProjectSettingsSetVersioninfo.cbxIncBuildClick(Sender: TObject);
begin
  edtIncBuild.Enabled := cbxIncBuild.Checked;
  udIncBuild.Enabled := cbxIncBuild.Checked;
end;

end.
