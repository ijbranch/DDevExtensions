{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageCompileBackup;

/// <summary>
/// Implements the Compile Backup feature: before each compile any modified, unsaved
/// editor buffers are written to ".cbk" sidecar files so the user can recover them if
/// the IDE crashes during the compile. The backups are removed after the file is saved
/// or when the module is closed ( configurable ).
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FrmTreePages, PluginConfig, IDENotifiers, ModuleData,
  ToolsAPI, ExtCtrls, FrmeBase;

type
  /// <summary>
  /// Plug-in configuration object that owns the Compile Backup feature and its IDE
  /// notifiers.
  /// </summary>
  TCompileBackupConfig = class(TPluginConfig)
  private
    /// <summary>IDE notifier delivering BeforeCompile callbacks.</summary>
    FIDENofifier: TIDENotifier;
    /// <summary>Module-data notifier delivering save and destroy callbacks.</summary>
    FModuleDataNotifier: TModuleDataNotifier;
    /// <summary>Backing field for Active.</summary>
    FActive: Boolean;
    /// <summary>Backing field for DeleteBackupAfterClose.</summary>
    FDeleteBackupAfterClose: Boolean;
  protected
    /// <summary>Sets default values for newly created configurations.</summary>
    procedure Init; override;

    /// <summary>Deletes all backup files associated with the supplied module data.</summary>
    /// <param name="Data">Module data whose backup file list should be removed.</param>
    procedure DeleteBackupFiles(Data: TModuleData);
    /// <summary>Iterates over all open modules and writes a ".cbk" backup for each modified file.</summary>
    procedure BackupModifiedFiles;

    /// <summary>IDE callback invoked before each compile; triggers BackupModifiedFiles when active.</summary>
    /// <param name="Project">Project being compiled.</param>
    /// <param name="IsCodeInsight">True for Code Insight background compiles ( ignored ).</param>
    /// <param name="Cancel">May be set to True to cancel the compile.</param>
    procedure BeforeCompile(const Project: IOTAProject; IsCodeInsight: Boolean;
      var Cancel: Boolean);
    /// <summary>Module-data callback: deletes backup files after a module has been saved.</summary>
    /// <param name="Data">Module data describing the module that was just saved.</param>
    procedure ModuleAfterSave(Data: TModuleData);
    /// <summary>Module-data callback: optionally deletes backups when the module is being destroyed.</summary>
    /// <param name="Data">Module data describing the module being destroyed.</param>
    procedure ModuleDestroying(Data: TModuleData);

    /// <summary>Returns the options-tree page used to edit this plug-in's settings.</summary>
    function GetOptionPages: TTreePage; override;
    /// <summary>Builds the backup file name for the supplied source file ( appends ".cbk" ).</summary>
    /// <param name="Filename">Source file name.</param>
    /// <returns>Filename with the ".cbk" extension appended.</returns>
    function GetCompileBackupFilename(const Filename: string): string;
  public
    /// <summary>Constructs the configuration and registers the IDE notifiers.</summary>
    constructor Create;
    /// <summary>Releases all notifiers and saved state.</summary>
    destructor Destroy; override;
  published
    /// <summary>Master switch enabling or disabling the Compile Backup feature.</summary>
    property Active: Boolean read FActive write FActive;
    /// <summary>When True backup files are deleted as soon as their owning module is closed.</summary>
    property DeleteBackupAfterClose: Boolean read FDeleteBackupAfterClose write FDeleteBackupAfterClose;
  end;

  /// <summary>
  /// Frame implementing ITreePageComponent for the Compile Backup options page.
  /// </summary>
  TFrameOptionPageCompileBackup = class(TFrameBase, ITreePageComponent)
    /// <summary>Master enable check box, bound to TCompileBackupConfig.Active.</summary>
    cbxActive: TCheckBox;
    /// <summary>Bound to TCompileBackupConfig.DeleteBackupAfterClose.</summary>
    cbxDeleteBackupAfterClose: TCheckBox;
    /// <summary>Enables or disables dependent controls when the master switch changes.</summary>
    procedure cbxActiveClick(Sender: TObject);
  private
    { Private-Deklarationen }
    /// <summary>Configuration instance bound to this frame.</summary>
    FCompileBackupConfig: TCompileBackupConfig;
  public
    { Public-Deklarationen }
    /// <summary>Receives the TCompileBackupConfig instance to edit.</summary>
    /// <param name="UserData">A TCompileBackupConfig instance.</param>
    procedure SetUserData(UserData: TObject);
    /// <summary>Loads the configuration values into the visual controls.</summary>
    procedure LoadData;
    /// <summary>Persists values from the visual controls back into the configuration.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes the selected page.</summary>
    procedure Selected;
    /// <summary>Called when the page is no longer selected.</summary>
    procedure Unselected;
  end;

/// <summary>
/// Initialises or shuts down the Compile Backup plug-in by creating or freeing the
/// global TCompileBackupConfig instance.
/// </summary>
/// <param name="Unload">False to load the plug-in, True to unload it.</param>
procedure InitPlugin(Unload: Boolean);
  
implementation

uses
  Main, ToolsAPIHelpers, IDEUtils;

{$R *.dfm}

var
  CompileBackupConfig: TCompileBackupConfig;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    CompileBackupConfig := TCompileBackupConfig.Create
  else
    FreeAndNil(CompileBackupConfig);
end;

{ TFrameOptionPageCompileBackup }

procedure TFrameOptionPageCompileBackup.SetUserData(UserData: TObject);
begin
  FCompileBackupConfig := UserData as TCompileBackupConfig;
end;

procedure TFrameOptionPageCompileBackup.LoadData;
begin
  cbxActive.Checked := FCompileBackupConfig.Active;
  cbxDeleteBackupAfterClose.Checked := FCompileBackupConfig.DeleteBackupAfterClose;
  cbxActiveClick(cbxActive);
end;

procedure TFrameOptionPageCompileBackup.SaveData;
begin
  FCompileBackupConfig.Active := cbxActive.Checked;
  FCompileBackupConfig.DeleteBackupAfterClose := cbxDeleteBackupAfterClose.Checked;
  FCompileBackupConfig.Save;
end;

procedure TFrameOptionPageCompileBackup.Selected;
begin
end;

procedure TFrameOptionPageCompileBackup.Unselected;
begin
end;

procedure TFrameOptionPageCompileBackup.cbxActiveClick(Sender: TObject);
begin
  cbxDeleteBackupAfterClose.Enabled := cbxActive.Checked;
end;

{ TCompileBackupConfig }

constructor TCompileBackupConfig.Create;
begin
  inherited Create(AppDataDirectory + '\CompileBackup.xml', 'CompileBackup');
  FIDENofifier := TIDENotifier.Create;
  FIDENofifier.OnBeforeCompile := BeforeCompile;
  FModuleDataNotifier := TModuleDataNotifier.Create;
  FModuleDataNotifier.AfterSave := ModuleAfterSave;
  FModuleDataNotifier.Destroying := ModuleDestroying;
end;

destructor TCompileBackupConfig.Destroy;
begin
  FModuleDataNotifier.Free;
  FIDENofifier.Free;
  inherited Destroy;
end;

procedure TCompileBackupConfig.Init;
begin
  inherited Init;
  Active := True;
  DeleteBackupAfterClose := True;
end;

procedure TCompileBackupConfig.BeforeCompile(const Project: IOTAProject;
  IsCodeInsight: Boolean; var Cancel: Boolean);
begin
  if not IsCodeInsight and Active then
    BackupModifiedFiles;
end;

procedure TCompileBackupConfig.ModuleDestroying(Data: TModuleData);
begin
  if Active and DeleteBackupAfterClose then
    DeleteBackupFiles(Data);
  { Destroy the associated BackupFiles-TStringList }
  Data.Bucket[Self].Free;
end;

procedure TCompileBackupConfig.ModuleAfterSave(Data: TModuleData);
begin
  if Active then
    DeleteBackupFiles(Data);
end;

procedure TCompileBackupConfig.DeleteBackupFiles(Data: TModuleData);
var
  List: TStrings;
  i: Integer;
begin
  List := TStrings(Data.Bucket[Self]);
  if List <> nil then
  begin
    for i := 0 to List.Count - 1 do
      DeleteFile(List[i]);
    List.Free;
    Data.Bucket[Self] := nil;
  end;
end;

procedure TCompileBackupConfig.BackupModifiedFiles;
const
  Utf8BOM: array[0..2] of Byte = ($EF, $BB, $BF);
var
  Modules: IOTAModuleServices;
  Module: IOTAModule;
  FileEditor: IOTAEditor;
  SourceEditor: IOTAEditBuffer;
  FormEditor: IOTAFormEditor;
  i, k: Integer;
  BackupFilename: string;
  BackupedFiles: TStrings;
begin
  if Supports(BorlandIDEServices, IOTAModuleServices, Modules) then
  begin
    BackupedFiles := TStringList.Create;
    try
      for i := 0 to Modules.ModuleCount - 1 do
      begin
        Module := Modules.Modules[i];
        try
          for k := 0 to Module.GetModuleFileCount - 1 do
          begin
            FileEditor := Module.GetModuleFileEditor(k);
            if Supports(FileEditor, IOTAEditBuffer, SourceEditor) then
            begin
              if SourceEditor.Modified and FastFileExists(SourceEditor.FileName) then
              begin
                BackupFilename := GetCompileBackupFilename(SourceEditor.FileName);
                SaveEditorSourceTo(SourceEditor, BackupFilename);
                BackupedFiles.Add(BackupFilename);
              end;
            end
            else
            if Supports(FileEditor, IOTAFormEditor, FormEditor) then
            begin
              if FormEditor.Modified and FastFileExists(FormEditor.FileName) then
              begin
                BackupFilename := GetCompileBackupFilename(FormEditor.FileName);
                SaveFormResourceTo(FormEditor, BackupFilename);
                BackupedFiles.Add(BackupFilename);
              end;
            end;
          end;

          if BackupedFiles.Count > 0 then
          begin
            ModuleDataList[Module].Bucket[Self].Free;
            ModuleDataList[Module].Bucket[Self] := BackupedFiles;
            BackupedFiles := TStringList.Create;
          end;
        except
          // ignore Delphi 5 exceptions
        end;
      end;
    finally
      BackupedFiles.Free;
    end;
  end;

end;

function TCompileBackupConfig.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('Compile Backup', TFrameOptionPageCompileBackup, Self);
end;

function TCompileBackupConfig.GetCompileBackupFilename(const Filename: string): string;
begin
  Result := Filename + '.cbk';
end;

end.
