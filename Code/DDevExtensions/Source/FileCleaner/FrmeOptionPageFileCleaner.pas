{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageFileCleaner;

/// <summary>
/// Plugin that listens for module-save notifications and removes IDE-generated artefacts
/// the user does not want to keep: legacy .ddp files, empty Together "Model"/"Modell"
/// folders and empty __history folders. Settings are exposed via an IDE Options page.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, ToolsAPI, FrmTreePages, PluginConfig, Vcl.StdCtrls,
  ModuleData, FrmeBase, Vcl.ExtCtrls;

type
  /// <summary>
  /// Persistent plugin configuration that drives the post-save cleanup logic.
  /// </summary>
  TFileCleaner = class(TPluginConfig)
  private
    /// <summary>Module-save notifier registered with the IDE.</summary>
    FModuleNotifier: TModuleDataNotifier;
    /// <summary>Backing field for the Active property.</summary>
    FActive: Boolean;
    /// <summary>Backing field for RemoveEmptyHistory.</summary>
    FRemoveEmptyHistory: Boolean;
    /// <summary>Backing field for DeleteDdp.</summary>
    FDeleteDdp: Boolean;
    /// <summary>Backing field for RemoveEmptyModel.</summary>
    FRemoveEmptyModel: Boolean;
  protected
    /// <summary>Returns the configuration page for the IDE Options dialog.</summary>
    /// <returns>A TTreePage describing the File Cleaner settings.</returns>
    function GetOptionPages: TTreePage; override;
    /// <summary>Sets default values for all options.</summary>
    procedure Init; override;
    /// <summary>Module-save callback that performs the configured cleanup actions.</summary>
    /// <param name="Data">Module data describing the file just saved.</param>
    procedure DoModuleAfterSave(Data: TModuleData); virtual;
  public
    /// <summary>Creates the configuration object and registers the module-save notifier.</summary>
    constructor Create;
    /// <summary>Releases the notifier and disables the cleaner.</summary>
    destructor Destroy; override;
  published
    /// <summary>Master switch enabling all post-save cleanup actions.</summary>
    property Active: Boolean read FActive write FActive;
    /// <summary>When True, deletes the corresponding .ddp file after a source module is saved.</summary>
    property DeleteDdp: Boolean read FDeleteDdp write FDeleteDdp;
    /// <summary>When True, removes empty __history folders left behind by the IDE backup feature.</summary>
    property RemoveEmptyHistory: Boolean read FRemoveEmptyHistory write FRemoveEmptyHistory;
    /// <summary>When True, removes empty Together Model/Modell folders.</summary>
    property RemoveEmptyModel: Boolean read FRemoveEmptyModel write FRemoveEmptyModel;
  end;

  /// <summary>
  /// VCL frame that hosts the File Cleaner options page in the IDE Options tree.
  /// </summary>
  TFrameOptionPageFileCleaner = class(TFrameBase, ITreePageComponent)
    /// <summary>Master enable check box.</summary>
    cbxActive: TCheckBox;
    /// <summary>Toggles the DeleteDdp option.</summary>
    cbxDeleteDdp: TCheckBox;
    /// <summary>Toggles the RemoveEmptyModel option.</summary>
    cbxRemoveEmptyModel: TCheckBox;
    /// <summary>Toggles the RemoveEmptyHistory option.</summary>
    cbxRemoveEmptyHistory: TCheckBox;
    /// <summary>Enables or disables the dependent check boxes when Active changes.</summary>
    procedure cbxActiveClick(Sender: TObject);
  private
    { Private-Deklarationen }
    /// <summary>Backing configuration object supplied via SetUserData.</summary>
    FFileCleaner: TFileCleaner;
  public
    { Public-Deklarationen }
    /// <summary>Stores the supplied configuration object for later Load/Save calls.</summary>
    /// <param name="UserData">Configuration object expected to be a TFileCleaner instance.</param>
    procedure SetUserData(UserData: TObject);
    /// <summary>Loads configuration values into the frame controls.</summary>
    procedure LoadData;
    /// <summary>Reads frame controls back into the configuration and persists.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes visible; no-op.</summary>
    procedure Selected;
    /// <summary>Called when the page is hidden; no-op.</summary>
    procedure Unselected;
  end;

/// <summary>
/// Creates or destroys the singleton FileCleaner instance and its module notifier.
/// </summary>
/// <param name="Unload">True to shut down, False to start up.</param>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  Main;

{$R *.dfm}

var
  FileCleaner: TFileCleaner;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    FileCleaner := TFileCleaner.Create
  else
    FreeAndNil(FileCleaner);
end;

{ TFrameOptionPageFileCleaner }

procedure TFrameOptionPageFileCleaner.cbxActiveClick(Sender: TObject);
begin
  cbxDeleteDdp.Enabled := cbxActive.Checked;
  cbxRemoveEmptyModel.Enabled := cbxActive.Checked;
  cbxRemoveEmptyHistory.Enabled := cbxActive.Checked;
end;

procedure TFrameOptionPageFileCleaner.SetUserData(UserData: TObject);
begin
  FFileCleaner := UserData as TFileCleaner;
end;

procedure TFrameOptionPageFileCleaner.LoadData;
begin
  cbxActive.Checked := FFileCleaner.Active;
  cbxDeleteDdp.Checked := FFileCleaner.DeleteDdp;
  cbxRemoveEmptyModel.Checked := FFileCleaner.RemoveEmptyModel;
  cbxRemoveEmptyHistory.Checked := FFileCleaner.RemoveEmptyHistory;
  {$IFDEF COMPILER9_UP}
  cbxRemoveEmptyModel.Visible := True;
  {$ENDIF COMPILER9_UP}
  {$IFDEF COMPILER10_UP}
  cbxRemoveEmptyHistory.Visible := True;
  {$ENDIF COMPILER10_UP}

  cbxActiveClick(cbxActive);
end;

procedure TFrameOptionPageFileCleaner.SaveData;
begin
  FFileCleaner.DeleteDdp := cbxDeleteDdp.Checked;
  FFileCleaner.RemoveEmptyHistory := cbxRemoveEmptyHistory.Checked;
  FFileCleaner.RemoveEmptyModel := cbxRemoveEmptyModel.Checked;

  FFileCleaner.Active := cbxActive.Checked;
  FFileCleaner.Save;
end;

procedure TFrameOptionPageFileCleaner.Selected;
begin
end;

procedure TFrameOptionPageFileCleaner.Unselected;
begin
end;

{ TFileCleaner }

constructor TFileCleaner.Create;
begin
  inherited Create(AppDataDirectory + '\FileCleaner.xml', 'FileCleaner');

  FModuleNotifier := TModuleDataNotifier.Create;
  FModuleNotifier.AfterSave := DoModuleAfterSave;
end;

destructor TFileCleaner.Destroy;
begin
  FModuleNotifier.Free;
  Active := False;
  inherited Destroy;
end;

procedure TFileCleaner.Init;
begin
  inherited Init;
  DeleteDdp := False;
  RemoveEmptyHistory := True;
  RemoveEmptyModel := True;
  Active := True;
end;

function TFileCleaner.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('File Cleaner', TFrameOptionPageFileCleaner, Self);
end;

procedure TFileCleaner.DoModuleAfterSave(Data: TModuleData);
var
  Ext: string;
  Filename: string;
  IsProjectExt: Boolean;
begin
  if Active then
  begin
    Filename := Data.Module.FileName;
    Ext := AnsiLowerCase(ExtractFileExt(FileName));
    IsProjectExt := (Ext = '.dpr') or (Ext = '.dpk') or (Ext = '.bpr') or (Ext = '.bpk') or (Ext = '.bdsproj');
    if (Ext = '.pas') or (Ext = '.cpp') or (Ext = '.dfm') or (Ext = '.nfm') or (Ext = '.xfm') or (Ext = '.h') or
       IsProjectExt then
    begin
      try
        if DeleteDdp and not IsProjectExt then
          DeleteFile(ChangeFileExt(FileName, '.ddp'));
        {$IFDEF COMPILER9_UP}
        if RemoveEmptyModel then
        begin
          RemoveDir(ExtractFilePath(FileName) + 'Modell');
          RemoveDir(ExtractFilePath(FileName) + 'Model');
        end;
        {$ENDIF COMPILER9_UP}
        {$IFDEF COMPILER10_UP}
        if RemoveEmptyHistory then
          RemoveDir(ExtractFilePath(FileName) + '__history');
        {$ENDIF COMPILER10_UP}
      except
        on E: Exception do
          // Best-effort cleanup must never disrupt the IDE save pipeline; log and continue.
          OutputDebugString(PChar('DDevExtensions FileCleaner: ' + FileName + ' - ' + E.Message));
      end;
    end;
  end;
end;

end.
