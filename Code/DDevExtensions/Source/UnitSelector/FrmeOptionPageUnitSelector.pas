{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageUnitSelector;

/// <summary>
/// Hosts the Unit Selector / Find Unit feature configuration: persistent options,
/// hooks into the IDE's File Use Unit and View Unit dialogs, and the matching IDE
/// options page frame.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, SimpleXmlIntf, SimpleXmlImport, FrmTreePages,
  PluginConfig, FrmeBase, ExtCtrls, ComCtrls, Menus, ToolsAPI;

type
  /// <summary>
  /// Persistent configuration for the Unit Selector feature. Manages the optional
  /// active flag (legacy Delphi 2009), the Find/Use Unit hotkey and the toggle that
  /// replaces the IDE's stock File Use Unit dialog with the custom Unit Selector.
  /// </summary>
  TUnitSelectorConfig = class(TPluginConfig)
  private
    {$IF CompilerVersion < 21.0} // Delphi 2009
    /// <summary>Active flag for the Delphi 2009 implementation only.</summary>
    FActive: Boolean;
    {$IFEND}
    /// <summary>Backing store for <see cref="FindUseUnitHotKey"/>.</summary>
    FFindUseUnitHotKey: TShortCut;
    /// <summary>Backing store for <see cref="ReplaceUseUnit"/>.</summary>
    FReplaceUseUnit: Boolean;
    {$IF CompilerVersion < 21.0} // Delphi 2009
    /// <summary>Setter that hooks/unhooks the legacy view dialog when toggled.</summary>
    /// <param name="Value">New active state.</param>
    procedure SetActive(const Value: Boolean);
    {$IFEND}
    /// <summary>Setter that updates the IDE menu hotkey when changed.</summary>
    /// <param name="Value">The new shortcut.</param>
    procedure SetFindUseUnitHotKey(const Value: TShortCut);
    /// <summary>Setter that hooks/unhooks the File Use Unit command override when toggled.</summary>
    /// <param name="Value">True to install the override, false to remove it.</param>
    procedure SetReplaceUseUnit(const Value: Boolean);
  protected
    /// <summary>Returns the option page tree node registered for this feature.</summary>
    function GetOptionPages: TTreePage; override;
    /// <summary>Sets default values when no configuration file exists.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the configuration, loading from the standard XML file.</summary>
    constructor Create;
    /// <summary>Tears down all installed hooks before releasing the configuration.</summary>
    destructor Destroy; override;
  published
    {$IF CompilerVersion < 21.0} // Delphi 2009
    /// <summary>Whether the legacy View Unit dialog override is enabled (Delphi 2009 only).</summary>
    property Active: Boolean read FActive write SetActive;
    {$IFEND}
    /// <summary>When true, the IDE's File Use Unit command is replaced by the custom selector.</summary>
    property ReplaceUseUnit: Boolean read FReplaceUseUnit write SetReplaceUseUnit;
    /// <summary>Shortcut that opens the Find/Use Unit dialog from anywhere in the IDE.</summary>
    property FindUseUnitHotKey: TShortCut read FFindUseUnitHotKey write SetFindUseUnitHotKey;
  end;

  /// <summary>
  /// IDE options page frame that lets the user enable the Unit Selector and configure
  /// its hotkey and File Use Unit replacement.
  /// </summary>
  TFrameOptionPageUnitSelector = class(TFrameBase, ITreePageComponent)
    /// <summary>Toggles the legacy Unit Selector replacement (Delphi 2009 only).</summary>
    cbxUseUnitSelector: TCheckBox;
    /// <summary>Editor for the Find/Use Unit hotkey.</summary>
    hkFindUseUnit: THotKey;
    /// <summary>Caption for the hotkey editor.</summary>
    lblFindUseUnitHotKey: TLabel;
    /// <summary>Toggles replacement of the IDE's File Use Unit dialog.</summary>
    chkReplaceUseUnit: TCheckBox;
  private
    { Private declarations }
    /// <summary>Configuration object the page edits.</summary>
    FUnitSelectorConfig: TUnitSelectorConfig;
  public
    /// <summary>Receives the <see cref="TUnitSelectorConfig"/> instance edited by this page.</summary>
    /// <param name="UserData">The configuration cast to TObject.</param>
    procedure SetUserData(UserData: TObject);
    /// <summary>Populates the controls from the configuration's current values.</summary>
    procedure LoadData;
    /// <summary>Writes the control values back to the configuration and persists them.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes active in the options dialog.</summary>
    procedure Selected;
    /// <summary>Called when the page is deactivated in the options dialog.</summary>
    procedure Unselected;
    { Public declarations }
  end;

/// <summary>Singleton configuration instance owned by the plugin.</summary>
var
  UnitSelectorConfig: TUnitSelectorConfig;

/// <summary>Plugin entry point; creates or destroys the singleton configuration.</summary>
/// <param name="Unload">When true, the configuration is freed; otherwise it is created.</param>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  {$IF CompilerVersion < 21.0} // Delphi 2009
  FrmUnitSelector,
  {$IFEND}
  Hooking, IDEHooks, IDEUtils, Main, IDEMenuHandler,
  FrmFileSelector, ToolsAPIHelpers;

{$R *.dfm}

const
  DelphicmdsDll = delphicoreide_bpl;

var
  HookTDelphiCommands_FileUseUnitCommandExecute: TRedirectCode;
  TDelphiCommands_FileUseUnitCommandExecute: procedure(Self: TObject; Sender: TObject) = nil;

{$IF CompilerVersion < 21.0} // Delphi 2009
var
  HookTViewDialog_Execute: TRedirectCode;
//  HookTViewDialog_Create: TRedirectCode;
//  HookTViewDialog_FormCreate: TRedirectCode;
  OrgTViewDialog_Create: function(ViewDialog: TFormClass; DL: Byte; Owner: TComponent; GetFiles: TViewDialogGetFiles): TForm;

function TViewDialog_Execute(ViewDialog: TForm): Boolean;
  external coreide_bpl name '@Viewdlg@TViewDialog@Execute$qqrv';

function TViewDialog_Create(ViewDialog: TFormClass; DL: Byte; Owner: TComponent; GetFiles: TViewDialogGetFiles): TForm;
  external coreide_bpl name '@Viewdlg@TViewDialog@$bctr$qqrp18Classes@TComponentpqqrp28Collections@TStringHashTableo$v';

procedure TViewDialog_FormCreate(ViewDialog: TForm; Sender: TObject);
  external coreide_bpl name '@Viewdlg@TViewDialog@FormCreate$qqrp14System@TObject';

type
  TViewDialogGetFilesComponent = class(TComponent)
  public
    GetFiles: TViewDialogGetFiles;
  end;

  TFormAccess = class(TForm);

procedure ViewDialogDoCreate(ViewDialog: TForm);
var
  FS: ^TFormState;
begin
  FS := @ViewDialog.FormState;
  if fsActivated in FS^ then
  begin
    TFormAccess(ViewDialog).Activate;
    Exclude(FS^, fsActivated);
  end;
end;

function Hooked_TViewDialog_Create(AClass: TFormClass; DL: Byte; Owner: TComponent; GetFiles: TViewDialogGetFiles): TForm;
var
  C: TViewDialogGetFilesComponent;
begin
  // disable the OnFormCreate call as we don't need it
  ReplaceVmtField(AClass, GetActualAddr(@TFormAccess.DoCreate), @ViewDialogDoCreate);
  Result := OrgTViewDialog_Create(AClass, DL, Owner, GetFiles);
  ReplaceVmtField(AClass, @ViewDialogDoCreate, GetActualAddr(@TFormAccess.DoCreate));

  C := TViewDialogGetFilesComponent.Create(Result);
  C.GetFiles := GetFiles;
  C.Name := '__GetFiles';
end;


function Hooked_TViewDialog_Execute(ViewDialog: TForm): Boolean;
var
  Form: TFormUnitSelector;
begin
  try
    Form := TFormUnitSelector.Create(nil);
    try
      Result := Form.Execute(ViewDialog, (ViewDialog.FindComponent('__GetFiles') as TViewDialogGetFilesComponent).GetFiles);
    finally
      Form.Free;
    end;
  except
    Application.HandleException(ViewDialog);

    // failsafe code
    UnhookFunction(HookTViewDialog_Execute);
    try
      // We disabled the FormCreate code, so we must execute it now.
      TViewDialog_FormCreate(ViewDialog, ViewDialog);

      Result := TViewDialog_Execute(ViewDialog);
    finally
      CodeRedirect(@TViewDialog_Execute, @Hooked_TViewDialog_Execute, HookTViewDialog_Execute);
    end;
  end;
end;

{$IFEND}

procedure Hooked_TDelphiCommands_FileUseUnitCommandExecute(Self: TObject; Sender: TObject);
var
  Project: IOTAProject;
begin
  Project := GetActiveProject;
  if (Project <> nil) and (IsDelphiPersonality(Project) or IsDelphiNetPersonality(Project)) then
  begin
    try
      TFormFileSelector.Execute(False);
      Exit;
    except
      Application.HandleException(Self);
    end;
  end;

  // failsafe code
  UnhookFunction(HookTDelphiCommands_FileUseUnitCommandExecute);
  try
    TDelphiCommands_FileUseUnitCommandExecute(Self, Sender);
  finally
    CodeRedirect(@TDelphiCommands_FileUseUnitCommandExecute, @Hooked_TDelphiCommands_FileUseUnitCommandExecute, HookTDelphiCommands_FileUseUnitCommandExecute);
  end;
end;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    UnitSelectorConfig := TUnitSelectorConfig.Create
  else
    FreeAndNil(UnitSelectorConfig);
end;

{ TUnitSelectorConfig }

constructor TUnitSelectorConfig.Create;
begin
  inherited Create(AppDataDirectory + '\UnitSelector.xml', 'UnitSelector');
end;

destructor TUnitSelectorConfig.Destroy;
begin
  {$IF CompilerVersion < 21.0} // Delphi 2009
  Active := False;
  {$IFEND}
  ReplaceUseUnit := False;
  inherited Destroy;
end;

procedure TUnitSelectorConfig.Init;
begin
  inherited Init;
  {$IF CompilerVersion < 21.0} // Delphi 2009
  Active := True;
  {$IFEND}
  //FindUseUnitHotKey := Menus.ShortCut(Ord('U'), [ssCtrl, ssAlt]);
  FindUseUnitHotKey := scNone;
  ReplaceUseUnit := True;
end;

function TUnitSelectorConfig.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('Find Unit/Use Unit', TFrameOptionPageUnitSelector, Self);
end;

{$IF CompilerVersion < 21.0} // Delphi 2009
procedure TUnitSelectorConfig.SetActive(const Value: Boolean);
begin
  if Value <> FActive then
  begin
    if FActive then
    begin
      UnhookFunction(HookTViewDialog_Execute);
      RestoreOrgCall(@TViewDialog_Create, @OrgTViewDialog_Create);
    end;
    FActive := Value;
    if FActive then
    begin
      CodeRedirect(@TViewDialog_Execute, @Hooked_TViewDialog_Execute, HookTViewDialog_Execute);
      if Assigned(OrgTViewDialog_Create) then
        ReRedirectOrgCall(@TViewDialog_Create, @Hooked_TViewDialog_Create, @OrgTViewDialog_Create)
      else
        @OrgTViewDialog_Create := RedirectOrgCall(@TViewDialog_Create, @Hooked_TViewDialog_Create);
    end;
  end;
end;
{$IFEND}

procedure TUnitSelectorConfig.SetFindUseUnitHotKey(const Value: TShortCut);
begin
  if Value <> FindUseUnitHotKey then
  begin
    FFindUseUnitHotKey := Value;
    TIDEMenuHandler.SetFindUseUnitHotKey(Value);
  end;
end;

procedure TUnitSelectorConfig.SetReplaceUseUnit(const Value: Boolean);
begin
  if Value <> FReplaceUseUnit then
  begin
    if not Assigned(TDelphiCommands_FileUseUnitCommandExecute) then
      @TDelphiCommands_FileUseUnitCommandExecute := DbgStrictGetProcAddress(GetModuleHandle(PChar(DelphicmdsDll)), '@Delphicmds@TDelphiCommands@FileUseUnitCommandExecute$qqrp14System@TObject');
    if Assigned(TDelphiCommands_FileUseUnitCommandExecute) then
    begin
      if FReplaceUseUnit then
        UnhookFunction(HookTDelphiCommands_FileUseUnitCommandExecute);
      FReplaceUseUnit := Value;
      if FReplaceUseUnit then
        CodeRedirect(@TDelphiCommands_FileUseUnitCommandExecute,
          @Hooked_TDelphiCommands_FileUseUnitCommandExecute,
          HookTDelphiCommands_FileUseUnitCommandExecute);
    end;
  end;
end;

{ TFrameOptionPageUnitSelector }

procedure TFrameOptionPageUnitSelector.SetUserData(UserData: TObject);
begin
  FUnitSelectorConfig := UserData as TUnitSelectorConfig;
end;

procedure TFrameOptionPageUnitSelector.LoadData;
begin
  {$IF CompilerVersion < 21.0} // Delphi 2009
  cbxUseUnitSelector.Checked := FUnitSelectorConfig.Active;
  {$ELSE}
  cbxUseUnitSelector.Free;
  {$IFEND}
  hkFindUseUnit.HotKey := FUnitSelectorConfig.FindUseUnitHotKey;
  chkReplaceUseUnit.Checked := FUnitSelectorConfig.ReplaceUseUnit;
end;

procedure TFrameOptionPageUnitSelector.SaveData;
begin
  FUnitSelectorConfig.FindUseUnitHotKey := hkFindUseUnit.HotKey;
  FUnitSelectorConfig.ReplaceUseUnit := chkReplaceUseUnit.Checked;
  {$IF CompilerVersion < 21.0} // Delphi 2009
  FUnitSelectorConfig.Active := cbxUseUnitSelector.Checked;
  {$IFEND}
  FUnitSelectorConfig.Save;
end;

procedure TFrameOptionPageUnitSelector.Selected;
begin
end;

procedure TFrameOptionPageUnitSelector.Unselected;
begin
end;

end.

