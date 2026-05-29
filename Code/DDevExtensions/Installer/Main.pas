{******************************************************************************}
{*                                                                            *}
{* DelphiSpeedUp Installer                                                    *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit Main;

/// <summary>
/// Installer / uninstaller main form. Detects which Delphi or RAD Studio editions
/// (and which IDE-host bitness) are installed on the user's machine, lets the user
/// tick which IDEs to install <c>DDevExtensions</c> into, then copies the
/// appropriate <c>DDevExtensionsNNN.dll</c> + <c>CompileInterceptorW(x64).dll</c>
/// alongside the IDE and registers the wizard under the IDE's per-bitness
/// <c>Experts</c> / <c>Experts x64</c> registry key.
/// </summary>

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, CheckLst, Registry, ShlObj, ActiveX, AppConsts,
  ExtCtrls, ComCtrls;

type
  /// <summary>
  /// Identifies a supported Delphi / RAD Studio installation that the installer
  /// can target. One enum value per (product version, IDE-host bitness) pair —
  /// e.g. <c>ekDelphi130</c> for the 32-bit Delphi 13 IDE host and
  /// <c>ekDelphi130x64</c> for its 64-bit sibling.
  /// </summary>
  TEnvKind = ({ekDelphi5, ekBCB5, ekDelphi6, ekBCB6, ekDelphi7,
              ekDelphi9, ekBDS2006, ekDelphi2007,} ekDelphi2009, ekDelphi2010,
              ekDelphiXE, ekDelphiXE2, ekDelphiXE3, ekDelphiXE4, ekDelphiXE5,
              ekDelphiXE6, ekDelphiXE7, ekDelphiXE8, ekDelphi10Seattle,
              ekDelphi101Berlin, ekDelphi102, ekDelphi103, ekDelphi104,
              ekDelphi110, ekDelphi120, ekDelphi130, ekDelphi130x64);

  /// <summary>Set of <see cref="TEnvKind"/> values (currently unused at run time but kept for API symmetry).</summary>
  TEnvKinds = set of TEnvKind;

  /// <summary>
  /// Static metadata describing one installer target. Populated once via the
  /// <see cref="EnvDatas"/> constant and consumed by detection, install and
  /// uninstall logic to locate the IDE root and write the right registry key.
  /// </summary>
  TEnvData = record
    /// <summary>File-name suffix used to pick the correct plug-in DLL (e.g. <c>'D130'</c> for 32-bit Delphi 13, <c>'D130x64'</c> for 64-bit).</summary>
    Version: string;
    /// <summary>Human-readable IDE name shown in the installer's check-list box.</summary>
    IDEName: string;
    /// <summary>Registry product key under <c>HKLM\Software\</c> / <c>HKCU\Software\</c> identifying the IDE installation.</summary>
    Key: string;
    /// <summary>Per-bitness Experts subkey under <see cref="Key"/>: <c>'Experts'</c> for the 32-bit IDE host, <c>'Experts x64'</c> for the 64-bit host.</summary>
    ExpertsSubKey: string;
    /// <summary>Path to the IDE host executable relative to <see cref="GetRootDir"/>, e.g. <c>'bin\bds.exe'</c> or <c>'bin64\bds.exe'</c>.</summary>
    HostExeRelPath: string;
    /// <summary>File name of the <c>CompileInterceptor</c> helper DLL deployed alongside the plug-in (per-bitness: <c>CompileInterceptorW.dll</c> or <c>CompileInterceptorWx64.dll</c>).</summary>
    CompInterceptorDll: string;
  end;

const
{  AllEnvKinds = [ekDelphi5, ekBCB5, ekDelphi6, ekBCB6, ekDelphi7, ekDelphi9, ekBDS2006, ekDelphi2007, ekDelphi2009];
  AllDelphiEnvKinds = [ekDelphi5, ekDelphi6, ekDelphi7, ekDelphi9, ekBDS2006, ekDelphi2007, ekDelphi2009];
  AllBCBEnvKinds = [ekBCB5, ekBCB6, ekBDS2006, ekDelphi2007, ekDelphi2009];
  AllBDSEnvKinds = [ekDelphi9, ekBDS2006, ekDelphi2007, ekDelphi2009];
  AllOldEnvKinds = [ekDelphi5, ekBCB5, ekDelphi6, ekBCB6, ekDelphi7];}

  /// <summary>
  /// One <see cref="TEnvData"/> per <see cref="TEnvKind"/>. Indexed by enum
  /// value to look up the registry key, target DLL suffix, host executable and
  /// per-bitness Experts subkey for a given IDE.
  /// </summary>
  EnvDatas: array[TEnvKind] of TEnvData = (
{    (Version:  '5'; IDEName: 'Delphi 5'; Key: 'Borland\Delphi\5.0'),
    (Version:  '6'; IDEName: 'Delphi 6'; Key: 'Borland\Delphi\6.0'),
    (Version:  '7'; IDEName: 'Delphi 7'; Key: 'Borland\Delphi\7.0'),
    (Version:  '5'; IDEName: 'C++Builder 5'; Key: 'Borland\C++Builder\5.0'),
    (Version:  '6'; IDEName: 'C++Builder 6'; Key: 'Borland\C++Builder\6.0'),
    (Version:  '9'; IDEName: 'Delphi 2005'; Key: 'Borland\BDS\3.0'),
    (Version: '10'; IDEName: 'Borland Developer Studio 2006'; Key: 'Borland\BDS\4.0'),
    (Version: '105'; IDEName: 'CodeGear Delphi 2007'; Key: 'Borland\BDS\5.0'),}
    (Version: '2009';    IDEName: 'CodeGear RAD Studio 2009';        Key: 'CodeGear\BDS\6.0';     ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: '2010';    IDEName: 'Embarcadero RAD Studio 2010';     Key: 'CodeGear\BDS\7.0';     ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE';      IDEName: 'Embarcadero RAD Studio XE';       Key: 'Embarcadero\BDS\8.0';  ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE2';     IDEName: 'Embarcadero RAD Studio XE2';      Key: 'Embarcadero\BDS\9.0';  ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE3';     IDEName: 'RAD Studio XE3';                  Key: 'Embarcadero\BDS\10.0'; ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE4';     IDEName: 'RAD Studio XE4';                  Key: 'Embarcadero\BDS\11.0'; ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE5';     IDEName: 'RAD Studio XE5';                  Key: 'Embarcadero\BDS\12.0'; ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE6';     IDEName: 'RAD Studio XE6';                  Key: 'Embarcadero\BDS\14.0'; ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE7';     IDEName: 'RAD Studio XE7';                  Key: 'Embarcadero\BDS\15.0'; ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE8';     IDEName: 'RAD Studio XE8';                  Key: 'Embarcadero\BDS\16.0'; ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D10';     IDEName: 'RAD Studio 10 Seattle';           Key: 'Embarcadero\BDS\17.0'; ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D101';    IDEName: 'RAD Studio 10.1 Berlin';          Key: 'Embarcadero\BDS\18.0'; ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D102';    IDEName: 'RAD Studio 10.2';                 Key: 'Embarcadero\BDS\19.0'; ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D103';    IDEName: 'RAD Studio 10.3';                 Key: 'Embarcadero\BDS\20.0'; ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D104';    IDEName: 'RAD Studio 10.4';                 Key: 'Embarcadero\BDS\21.0'; ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D110';    IDEName: 'RAD Studio 11.0';                 Key: 'Embarcadero\BDS\22.0'; ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D120';    IDEName: 'RAD Studio 12.0';                 Key: 'Embarcadero\BDS\23.0'; ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D130';    IDEName: 'RAD Studio 13.0 (32-bit IDE)';    Key: 'Embarcadero\BDS\37.0'; ExpertsSubKey: 'Experts';     HostExeRelPath: 'bin\bds.exe';   CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D130x64'; IDEName: 'RAD Studio 13.0 (64-bit IDE)';    Key: 'Embarcadero\BDS\37.0'; ExpertsSubKey: 'Experts x64'; HostExeRelPath: 'bin64\bds.exe'; CompInterceptorDll: 'CompileInterceptorWx64.dll')
  );

type
  /// <summary>
  /// Main form of the installer. Owns a check-list of detected IDE installations
  /// and the Install / Uninstall / Quit buttons. Build-time DFM-bound members are
  /// the controls; private and public methods implement file-copy, expert
  /// registration and detection.
  /// </summary>
  TFormMain = class(TForm)
    /// <summary>Install-selected-IDEs button.</summary>
    btnInstall: TButton;
    /// <summary>Close-the-installer button.</summary>
    btnQuit: TButton;
    /// <summary>Uninstall-selected-IDEs button.</summary>
    btnUninstall: TButton;
    /// <summary>Static label introducing the IDE check-list.</summary>
    Label1: TLabel;
    /// <summary>Check-list of detected IDE installations the user can tick to (un)install.</summary>
    cbxEnvs: TCheckListBox;
    /// <summary>Progress bar advanced as each ticked IDE is processed.</summary>
    pbProgress: TProgressBar;
    /// <summary>Handler for the Quit button — closes the form.</summary>
    procedure btnQuitClick(Sender: TObject);
    /// <summary>Handler for the Install button — iterates ticked IDEs and calls <see cref="DoInstall"/>.</summary>
    procedure btnInstallClick(Sender: TObject);
    /// <summary>Handler for the Uninstall button — iterates ticked IDEs and calls <see cref="DoUninstall"/>.</summary>
    procedure btnUninstallClick(Sender: TObject);
    /// <summary>Form constructor: detects installed IDEs and populates the check-list, pre-ticking those already registered.</summary>
    procedure FormCreate(Sender: TObject);
    /// <summary>Suppresses resizing while the form is visible (cancels every resize attempt).</summary>
    procedure FormCanResize(Sender: TObject; var NewWidth, NewHeight: Integer; var Resize: Boolean);
  private
    /// <summary>Cached path to the per-user <c>AppData</c> roaming directory, populated in <see cref="FormCreate"/>.</summary>
    FAppDataDirectory: string;
    /// <summary>Pumps the message queue while keeping the form disabled, used to refresh the progress bar during long operations.</summary>
    procedure SafeProcessMessages;

    /// <summary>
    /// Copies a single file from the installer's directory (or absolute path) into
    /// <paramref name="InstallDir"/>, creating the directory if missing.
    /// </summary>
    /// <param name="InstallDir">Destination directory.</param>
    /// <param name="FileName">Source file name (relative to installer) or absolute path.</param>
    /// <param name="Force">When <c>True</c>, the copy is mandatory and a missing source raises. When <c>False</c>, a missing source is silently skipped — used for optional companion files such as <c>.map</c>.</param>
    procedure InstallFile(const InstallDir, FileName: string; Force: Boolean = True);
    /// <summary>Writes the wizard registration value under <c>HKCU\Software\&lt;Key&gt;\&lt;ExpertsSubKey&gt;</c>.</summary>
    /// <param name="EnvData">Target IDE metadata.</param>
    /// <param name="Name">Wizard name (the registry value name, conventionally <c>'DDevExtensions'</c>).</param>
    /// <param name="Filename">Absolute path to the registered DLL.</param>
    procedure RegisterExpert(const EnvData: TEnvData; const Name, Filename: string);
    /// <summary>Deletes a single file from <paramref name="InstallDir"/> if it exists.</summary>
    /// <param name="InstallDir">Directory that the file resides in.</param>
    /// <param name="FileName">File name (or path; only the file name component is used).</param>
    procedure UninstallFile(const InstallDir, FileName: string);
    /// <summary>Removes the wizard registration value under <c>HKCU\Software\&lt;Key&gt;\&lt;ExpertsSubKey&gt;</c>.</summary>
    /// <param name="EnvData">Target IDE metadata.</param>
    /// <param name="Name">Wizard name (the registry value to delete).</param>
    procedure UnregisterExpert(const EnvData: TEnvData; const Name: string);
    /// <summary>Returns <c>True</c> when the named expert is already registered for the given IDE.</summary>
    /// <param name="EnvData">Target IDE metadata.</param>
    /// <param name="Name">Wizard name to check (case-insensitive registry value).</param>
    /// <returns><c>True</c> when registered, <c>False</c> otherwise (including when the key is missing).</returns>
    function HasExpert(const EnvData: TEnvData; const Name: string): Boolean;

    /// <summary>
    /// Performs the full installation for a single IDE target — creates the install directory,
    /// copies the appropriate <c>DDevExtensions&lt;Version&gt;.dll</c>, the matching <c>.map</c>
    /// (when present), and <see cref="TEnvData.CompInterceptorDll"/>, then registers the wizard.
    /// </summary>
    procedure DoInstall(const EnvData: TEnvData);
    /// <summary>
    /// Reverses <see cref="DoInstall"/> for a single IDE target — deletes the files copied at
    /// install time, removes the registry entry and tries to remove the now-empty install dir.
    /// </summary>
    procedure DoUninstall(const EnvData: TEnvData);
  protected
    /// <summary>
    /// Per-frame action-state update: enables the Install / Uninstall buttons only when at
    /// least one IDE in the check-list is ticked.
    /// </summary>
    procedure UpdateActions; override;
  public
    /// <summary>
    /// Returns the IDE's root directory by reading the <c>RootDir</c> value first from
    /// <c>HKLM\Software\&lt;Key&gt;</c>, falling back to <c>HKCU\Software\&lt;Key&gt;</c>.
    /// </summary>
    /// <param name="EnvData">Target IDE metadata.</param>
    /// <returns>Trailing-slash-trimmed root directory, or empty string if not installed.</returns>
    function GetRootDir(const EnvData: TEnvData): string;
    /// <summary>
    /// Returns the directory the plug-in should be copied into. On Windows 9x the IDE's
    /// own root is used; on modern Windows the per-user <c>%AppData%\DDevExtensions</c>
    /// is used (so a standard user account can install without admin rights).
    /// </summary>
    /// <param name="EnvData">Target IDE metadata.</param>
    /// <returns>Absolute install directory (created by <see cref="DoInstall"/> if missing).</returns>
    function GetInstallDir(const EnvData: TEnvData): string;
  end;

var
  /// <summary>Auto-created singleton main form, owned by <c>Application</c>.</summary>
  FormMain: TFormMain;

implementation

{$R *.dfm}

{$IF CompilerVersion >= 24.0}
uses
  System.UITypes; // inline
{$IFEND}

function TFormMain.GetRootDir(const EnvData: TEnvData): string;
var
  Reg: TRegistry;
begin
  Result := '';
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKeyReadOnly('\Software\' + EnvData.Key) and Reg.ValueExists('RootDir') then
      Result := ExcludeTrailingPathDelimiter(Reg.ReadString('RootDir'))
    else
    begin
      Reg.Free;
      { Work around a bug in TRegistry }
      Reg := TRegistry.Create;
      Reg.RootKey := HKEY_CURRENT_USER;
      if Reg.OpenKeyReadOnly('\Software\' + EnvData.Key) and Reg.ValueExists('RootDir') then
        Result := ExcludeTrailingPathDelimiter(Reg.ReadString('RootDir'));
    end;
  finally
    Reg.Free;
  end;
end;

function TFormMain.GetInstallDir(const EnvData: TEnvData): string;
begin
  if Win32Platform = VER_PLATFORM_WIN32_WINDOWS then
    Result := GetRootDir(EnvData)
  else
    Result := FAppDataDirectory;
  Result := Result + '\DDevExtensions';
end;

procedure TFormMain.btnQuitClick(Sender: TObject);
begin
  Close;
end;

procedure TFormMain.btnInstallClick(Sender: TObject);
var
  i: Integer;
begin
  pbProgress.Position := 0;
  pbProgress.Visible := True;
  try
    for i := 0 to cbxEnvs.Items.Count - 1 do
    begin
      if cbxEnvs.Checked[i] then
        DoInstall(EnvDatas[TEnvKind(cbxEnvs.Items.Objects[i])]);
      pbProgress.Position := i + 1;
      SafeProcessMessages;
    end;
    MessageDlg('Installation was successful.', mtInformation, [mbOk], 0);
  finally
    pbProgress.Visible := False;
  end;
end;

procedure TFormMain.btnUninstallClick(Sender: TObject);
var
  i: Integer;
begin
  pbProgress.Position := 0;
  pbProgress.Visible := True;
  try
    for i := 0 to cbxEnvs.Items.Count - 1 do
    begin
      if cbxEnvs.Checked[i] then
        DoUninstall(EnvDatas[TEnvKind(cbxEnvs.Items.Objects[i])]);
      pbProgress.Position := i + 1;
      SafeProcessMessages;
    end;
  finally
    pbProgress.Visible := False;
  end;
  MessageDlg('Uninstallation was successful.', mtInformation, [mbOk], 0)
end;

procedure TFormMain.UpdateActions;
var
  i: Integer;
begin
  inherited UpdateActions;
  for i := 0 to cbxEnvs.Items.Count - 1 do
    if cbxEnvs.Checked[i] then
    begin
      btnInstall.Enabled := True;
      btnUninstall.Enabled := True;
      Exit;
    end;
  btnInstall.Enabled := False;
  btnUninstall.Enabled := False;
end;

procedure TFormMain.SafeProcessMessages;
begin
  Enabled := False;
  try
    Application.ProcessMessages;
  finally
    Enabled := True;
  end;
end;

procedure TFormMain.FormCreate(Sender: TObject);
var
  Malloc: IMalloc;
  pidl: PItemIDList;
  Buffer, RootDir: string;
  ek: TEnvKind;
  i: Integer;
  Found: Boolean;
begin
  Caption := Caption + ' ' + sPluginName;
  { Windows 95 compatible way, Win98 supports SHGetSpecialFolderPath() }
  SHGetMalloc(Malloc);
  if SHGetSpecialFolderLocation(FormMain.Handle, CSIDL_APPDATA, pidl) = S_OK then
  begin
    try
      SetLength(Buffer, MAX_PATH * 2); // SHGetPathFromIDList has no MaxLen parameter
      if SHGetPathFromIDList(pidl, PChar(Buffer)) then
        FAppDataDirectory := ExcludeTrailingPathDelimiter(Copy(Buffer, 1, StrLen(PChar(Buffer))));
    finally
      Malloc.Free(pidl);
      Malloc := nil;
    end;
  end;

  for ek := Low(ek) to High(ek) do
  begin
    // check modules
    RootDir := GetRootDir(EnvDatas[ek]);
    if FileExists(RootDir + '\' + EnvDatas[ek].HostExeRelPath) then
    begin
      if FileExists(Format('%s\DDevExtensions%s.dll', [ExtractFileDir(ParamStr(0)), EnvDatas[ek].Version])) then
        cbxEnvs.AddItem(EnvDatas[ek].IDEName, Pointer(ek));
    end;
  end;
  Found := False;
  for i := 0 to cbxEnvs.Items.Count - 1 do
    if HasExpert(EnvDatas[TEnvKind(cbxEnvs.Items.Objects[i])], 'DDevExtensions') then
    begin
      cbxEnvs.Checked[i] := True;
      Found := True;
    end;
  if not Found then
    for i := 0 to cbxEnvs.Items.Count - 1 do
       cbxEnvs.Checked[i] := True;

  pbProgress.Max := cbxEnvs.Items.Count;
end;

procedure TFormMain.InstallFile(const InstallDir, FileName: string; Force: Boolean);
var
  Source, Dest: string;
  LastError: Cardinal;
begin
  if ExtractFileDir(FileName) = '' then
    Source := ExtractFilePath(ParamStr(0)) + FileName
  else
    Source := FileName;
  if Force or FileExists(Source) then
  begin
    if (InstallDir = '') or (InstallDir = '\') then
      raise Exception.CreateFmt('Invalid installation directory: "%s"', [InstallDir]);
    if not ForceDirectories(InstallDir) then
      raise Exception.CreateFmt('Cannot create installation directory "%s"', [InstallDir]);
    Dest := InstallDir + PathDelim + ExtractFileName(FileName);

    SetFileAttributes(PChar(Dest), 0);
    if not CopyFile(PChar(Source), PChar(Dest), False) then
    begin
      LastError := GetLastError();
      raise Exception.CreateFmt('Cannot copy file "%s" to "%s"' + sLineBreak + sLineBreak + '%s', [Source, Dest, SysErrorMessage(LastError)]);
    end;
    SetFileAttributes(PChar(Dest), 0);
  end;
end;

procedure TFormMain.RegisterExpert(const EnvData: TEnvData; const Name, Filename: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey('\Software\' + EnvData.Key + '\' + EnvData.ExpertsSubKey, True) then
      Reg.WriteString(Name, Filename)
    else
      raise Exception.CreateFmt('Cannot register expert "%s"', [Name]);
  finally
    Reg.Free;
  end;
end;

procedure TFormMain.UninstallFile(const InstallDir, FileName: string);
var
  Dest: string;
begin
  Dest := InstallDir + PathDelim + ExtractFileName(FileName);
  if FileExists(Dest) then
  begin
    SetFileAttributes(PChar(Dest), 0);
    if not DeleteFile(Dest) then
      raise Exception.CreateFmt('Cannot delete file "%s"', [Dest]);
  end;
end;

procedure TFormMain.UnregisterExpert(const EnvData: TEnvData; const Name: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey('\Software\' + EnvData.Key + '\' + EnvData.ExpertsSubKey, False) then
      if Reg.ValueExists(Name) then
        Reg.DeleteValue(Name);
  finally
    Reg.Free;
  end;
end;

function TFormMain.HasExpert(const EnvData: TEnvData;
  const Name: string): Boolean;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly('\Software\' + EnvData.Key + '\' + EnvData.ExpertsSubKey) then
      Result := Reg.ValueExists(Name)
    else
      Result := False;
  finally
    Reg.Free;
  end;
end;

{------------------------------------------------------------------------------}

procedure TFormMain.DoInstall(const EnvData: TEnvData);
var
  InstallDir: string;
begin
  InstallDir := GetInstallDir(EnvData);
  if not ForceDirectories(InstallDir) then
    raise Exception.Create('Cannot create installation directory "' + InstallDir + '"');

  InstallFile(InstallDir, Format('DDevExtensions%s.dll', [EnvData.Version]));
  InstallFile(InstallDir, Format('DDevExtensions%s.map', [EnvData.Version]), False);
  InstallFile(InstallDir, EnvData.CompInterceptorDll, False);
  RegisterExpert(EnvData, 'DDevExtensions', InstallDir + PathDelim + Format('DDevExtensions%s.dll', [EnvData.Version]));
end;

procedure TFormMain.DoUninstall(const EnvData: TEnvData);
var
  InstallDir: string;
begin
  InstallDir := GetInstallDir(EnvData);
  if DirectoryExists(InstallDir) then
  begin
    UninstallFile(InstallDir, Format('DDevExtensions%s.dll', [EnvData.Version]));
    UninstallFile(InstallDir, Format('DDevExtensions%s.map', [EnvData.Version]));
    UninstallFile(InstallDir, EnvData.CompInterceptorDll);
    UnregisterExpert(EnvData, 'DDevExtensions');

    RemoveDir(InstallDir); // try to delete the directory
  end;
end;

procedure TFormMain.FormCanResize(Sender: TObject; var NewWidth, NewHeight: Integer;
  var Resize: Boolean);
begin
  if Showing then
    Resize := False;
end;

end.
