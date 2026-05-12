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

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, CheckLst, Registry, ShlObj, ActiveX, AppConsts,
  ExtCtrls, ComCtrls;

type
  TEnvKind = ({ekDelphi5, ekBCB5, ekDelphi6, ekBCB6, ekDelphi7,
              ekDelphi9, ekBDS2006, ekDelphi2007,} ekDelphi2009, ekDelphi2010,
              ekDelphiXE, ekDelphiXE2, ekDelphiXE3, ekDelphiXE4, ekDelphiXE5,
              ekDelphiXE6, ekDelphiXE7, ekDelphiXE8, ekDelphi10Seattle,
              ekDelphi101Berlin, ekDelphi102, ekDelphi103, ekDelphi104,
              ekDelphi110, ekDelphi120, ekDelphi130, ekDelphi130x64);

  TEnvKinds = set of TEnvKind;

  TEnvData = record
    Version: string;        // file-name suffix (e.g. 'D130', 'D130x64')
    IDEName: string;        // human-readable name shown in the installer list
    Key: string;            // registry product key under HKLM\Software\
    ExpertsSubKey: string;  // 'Experts' for 32-bit IDE host, 'Experts64' for 64-bit IDE host
    HostExeRelPath: string; // host executable relative to RootDir ('bin\bds.exe' or 'bin64\bds.exe')
    CompInterceptorDll: string; // CompileInterceptor helper DLL to copy alongside the plugin
  end;

const
{  AllEnvKinds = [ekDelphi5, ekBCB5, ekDelphi6, ekBCB6, ekDelphi7, ekDelphi9, ekBDS2006, ekDelphi2007, ekDelphi2009];
  AllDelphiEnvKinds = [ekDelphi5, ekDelphi6, ekDelphi7, ekDelphi9, ekBDS2006, ekDelphi2007, ekDelphi2009];
  AllBCBEnvKinds = [ekBCB5, ekBCB6, ekBDS2006, ekDelphi2007, ekDelphi2009];
  AllBDSEnvKinds = [ekDelphi9, ekBDS2006, ekDelphi2007, ekDelphi2009];
  AllOldEnvKinds = [ekDelphi5, ekBCB5, ekDelphi6, ekBCB6, ekDelphi7];}

  EnvDatas: array[TEnvKind] of TEnvData = (
{    (Version:  '5'; IDEName: 'Delphi 5'; Key: 'Borland\Delphi\5.0'),
    (Version:  '6'; IDEName: 'Delphi 6'; Key: 'Borland\Delphi\6.0'),
    (Version:  '7'; IDEName: 'Delphi 7'; Key: 'Borland\Delphi\7.0'),
    (Version:  '5'; IDEName: 'C++Builder 5'; Key: 'Borland\C++Builder\5.0'),
    (Version:  '6'; IDEName: 'C++Builder 6'; Key: 'Borland\C++Builder\6.0'),
    (Version:  '9'; IDEName: 'Delphi 2005'; Key: 'Borland\BDS\3.0'),
    (Version: '10'; IDEName: 'Borland Developer Studio 2006'; Key: 'Borland\BDS\4.0'),
    (Version: '105'; IDEName: 'CodeGear Delphi 2007'; Key: 'Borland\BDS\5.0'),}
    (Version: '2009'; IDEName: 'CodeGear RAD Studio 2009';     Key: 'CodeGear\BDS\6.0';     ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: '2010'; IDEName: 'Embarcadero RAD Studio 2010';  Key: 'CodeGear\BDS\7.0';     ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE';   IDEName: 'Embarcadero RAD Studio XE';    Key: 'Embarcadero\BDS\8.0';  ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE2';  IDEName: 'Embarcadero RAD Studio XE2';   Key: 'Embarcadero\BDS\9.0';  ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE3';  IDEName: 'RAD Studio XE3';               Key: 'Embarcadero\BDS\10.0'; ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE4';  IDEName: 'RAD Studio XE4';               Key: 'Embarcadero\BDS\11.0'; ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE5';  IDEName: 'RAD Studio XE5';               Key: 'Embarcadero\BDS\12.0'; ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE6';  IDEName: 'RAD Studio XE6';               Key: 'Embarcadero\BDS\14.0'; ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE7';  IDEName: 'RAD Studio XE7';               Key: 'Embarcadero\BDS\15.0'; ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'XE8';  IDEName: 'RAD Studio XE8';               Key: 'Embarcadero\BDS\16.0'; ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D10';  IDEName: 'RAD Studio 10 Seattle';        Key: 'Embarcadero\BDS\17.0'; ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D101'; IDEName: 'RAD Studio 10.1 Berlin';       Key: 'Embarcadero\BDS\18.0'; ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D102'; IDEName: 'RAD Studio 10.2';              Key: 'Embarcadero\BDS\19.0'; ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D103'; IDEName: 'RAD Studio 10.3';              Key: 'Embarcadero\BDS\20.0'; ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D104'; IDEName: 'RAD Studio 10.4';              Key: 'Embarcadero\BDS\21.0'; ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D110'; IDEName: 'RAD Studio 11.0';              Key: 'Embarcadero\BDS\22.0'; ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D120'; IDEName: 'RAD Studio 12.0';              Key: 'Embarcadero\BDS\23.0'; ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D130'; IDEName: 'RAD Studio 13.0 (32-bit IDE)'; Key: 'Embarcadero\BDS\37.0'; ExpertsSubKey: 'Experts'; HostExeRelPath: 'bin\bds.exe'; CompInterceptorDll: 'CompileInterceptorW.dll'),
    (Version: 'D130x64'; IDEName: 'RAD Studio 13.0 (64-bit IDE)'; Key: 'Embarcadero\BDS\37.0'; ExpertsSubKey: 'Experts x64'; HostExeRelPath: 'bin64\bds.exe'; CompInterceptorDll: 'CompileInterceptorWx64.dll')
  );

type
  TFormMain = class(TForm)
    btnInstall: TButton;
    btnQuit: TButton;
    btnUninstall: TButton;
    Label1: TLabel;
    cbxEnvs: TCheckListBox;
    pbProgress: TProgressBar;
    procedure btnQuitClick(Sender: TObject);
    procedure btnInstallClick(Sender: TObject);
    procedure btnUninstallClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormCanResize(Sender: TObject; var NewWidth, NewHeight: Integer; var Resize: Boolean);
  private
    { Private-Deklarationen }
    FAppDataDirectory: string;
    procedure SafeProcessMessages;

    procedure InstallFile(const InstallDir, FileName: string; Force: Boolean = True);
    procedure RegisterExpert(const EnvData: TEnvData; const Name, Filename: string);
    procedure UninstallFile(const InstallDir, FileName: string);
    procedure UnregisterExpert(const EnvData: TEnvData; const Name: string);
    function HasExpert(const EnvData: TEnvData; const Name: string): Boolean;

    procedure DoInstall(const EnvData: TEnvData);
    procedure DoUninstall(const EnvData: TEnvData);
  protected
    procedure UpdateActions; override;
  public
    { Public-Deklarationen }
    function GetRootDir(const EnvData: TEnvData): string;
    function GetInstallDir(const EnvData: TEnvData): string;
  end;

var
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
