{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit Main;

{$I DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Hooking, IDEUtils, Splash, Registry, Forms, Menus,
  Graphics, Controls, ExtCtrls, ActnList, AppConsts, ToolsAPI, Dialogs,
  StdCtrls, ComCtrls, ActiveX, ShlObj, ImportHooking;

type
  TLateLoaderProc = procedure(Unload: Boolean);

procedure InstallHooks;
procedure UninstallHooks;

procedure ExpertLoaded;
procedure IDELoaded; // called by Splash

procedure RegisterExpertLoader(Proc: TLateLoaderProc);
procedure RegisterLateLoader(Proc: TLateLoaderProc);
procedure InitAppDataDirectory; // called by InstallHooks

var
  APIHookList: TJclPeMapImgHooks;
  AppDataDirectory: string;
  DDevExtensionsMenu: TMenuItem;  // Submenu for DDevExtensions tools

implementation

uses
  SysConst, IDEHooks, ComponentManager, DtmImages, FrmDDevExtOptions, RegisterPlugins,
  ToolsAPIHelpers, PluginConfig;

var
  HookFinalizePackage: TRedirectCode;
  OrgFinalizePackage: Pointer;
  LateLoaderList: TList;
  ExpertLoaderList: TList;
  MenuItemOptions: TMenuItem;
  MenuItemAbout: TMenuItem;

procedure RegisterExpertLoader(Proc: TLateLoaderProc);
begin
  if not Assigned(ExpertLoaderList) then
    ExpertLoaderList := TList.Create;
  ExpertLoaderList.Add(@Proc);
end;

procedure RegisterLateLoader(Proc: TLateLoaderProc);
begin
  if not Assigned(LateLoaderList) then
    LateLoaderList := TList.Create;
  LateLoaderList.Add(@Proc);
end;

procedure ShowOptionsDialog(Data: TObject; Sender: TObject);
begin
  TFormDDevExtOptions.Execute;
end;

procedure ShowAboutDialog( Data: TObject; Sender: TObject );
var
  Frm: TForm;
  Lbl: TLabel;
  Btn: TButton;
  iY: Integer;
begin

  Frm := TForm.CreateNew( Application );
  try
    Frm.Caption := 'About DDevExtensions';
    Frm.BorderStyle := bsDialog;
    Frm.Position := poScreenCenter;
    Frm.ClientWidth := 380;
    Frm.ClientHeight := 200;

    iY := 20;

    Lbl := TLabel.Create( Frm );
    Lbl.Parent := Frm;
    Lbl.Left := 20;
    Lbl.Top := iY;
    Lbl.Font.Size := 14;
    Lbl.Font.Style := [fsBold];
    Lbl.Caption := 'DDevExtensions';
    Inc( iY, 30 );

    Lbl := TLabel.Create( Frm );
    Lbl.Parent := Frm;
    Lbl.Left := 20;
    Lbl.Top := iY;
    Lbl.Caption := 'Version ' + sPluginVersion;
    Inc( iY, 24 );

    Lbl := TLabel.Create( Frm );
    Lbl.Parent := Frm;
    Lbl.Left := 20;
    Lbl.Top := iY;
    Lbl.Caption := sPluginCopyright;
    Inc( iY, 20 );

    Lbl := TLabel.Create( Frm );
    Lbl.Parent := Frm;
    Lbl.Left := 20;
    Lbl.Top := iY;
    Lbl.Caption := '(C) 2021-2025 DelphiPraxis';
    Inc( iY, 20 );

    Lbl := TLabel.Create( Frm );
    Lbl.Parent := Frm;
    Lbl.Left := 20;
    Lbl.Top := iY;
    Lbl.Caption := '(C) 2026 Ian Branch, Claude Code';
    Inc( iY, 30 );

    Lbl := TLabel.Create( Frm );
    Lbl.Parent := Frm;
    Lbl.Left := 20;
    Lbl.Top := iY;
    Lbl.Caption := 'Extensions for the Delphi IDE';

    Btn := TButton.Create( Frm );
    Btn.Parent := Frm;
    Btn.Caption := 'OK';
    Btn.ModalResult := mrOk;
    Btn.Default := True;
    Btn.Cancel := True;
    Btn.Width := 75;
    Btn.Left := ( Frm.ClientWidth - Btn.Width ) div 2;
    Btn.Top := Frm.ClientHeight - Btn.Height - 12;

    Frm.ShowModal;
  finally
    Frm.Free;
  end;

end;

procedure HookedFinalizePackage(Module: HMODULE);
type
  TPackageUnload = procedure;
var
  PackageUnload: TPackageUnload;
begin
  {.$IFNDEF COMPILER9_UP}
  if (Application <> nil) and not Application.Terminated then
    try
      RegisteredComponents.DeletePackageComponents(Module);
    except
      on E: Exception do
        OutputDebugString(PChar('DDevExtensions: Error deleting package components: ' + E.Message));
    end;
  {.$ENDIF ~COMPILER9_UP}
  @PackageUnload := GetProcAddress(Module, 'Finalize'); //Do not localize
  if Assigned(PackageUnload) then
    PackageUnload
  else
    raise EPackageError.CreateRes(@sInvalidPackageHandle);
end;

procedure InitAppDataDirectory;
var
  Malloc: IMalloc;
  pidl: PItemIDList;
  Buffer: string;
begin
  AppDataDirectory := ExtractFileDir(ExtractFileDir((ParamStr(0))));
  { Windows 95 compatible way, Win98 supports SHGetSpecialFolderPath() }
  SHGetMalloc(Malloc);
  if SHGetSpecialFolderLocation(Application.Handle, CSIDL_APPDATA, pidl) = S_OK then
  begin
    try
      SetLength(Buffer, MAX_PATH * 2); // SHGetPathFromIDList has no MaxLen parameter
      if SHGetPathFromIDList(pidl, PChar(Buffer)) then
        AppDataDirectory := ExcludeTrailingPathDelimiter(Copy(Buffer, 1, StrLen(PChar(Buffer))));
    finally
      Malloc.Free(pidl);
      Malloc := nil;
    end;
  end;
  if AppDataDirectory = '' then
    AppDataDirectory := ExtractFileDir(ExtractFileDir((ParamStr(0))));
  AppDataDirectory := AppDataDirectory + '\DDevExtensions';
  ForceDirectories(AppDataDirectory);
end;

procedure InstallHooks;
begin
  InitAppDataDirectory;
  DataModuleImages := TDataModuleImages.Create(nil);

  OrgFinalizePackage := @SysUtils.FinalizePackage;
  if Assigned(OrgFinalizePackage) then
    CodeRedirect(OrgFinalizePackage, @HookedFinalizePackage, HookFinalizePackage);

  Configuration.BeginUpdate;
  try
    InitComponentManager;
    RegisterIDEPlugins;
    ExpertLoaded;
  finally
    Configuration.EndUpdate;
  end;
end;

procedure ExpertLoaded;
var
  I: Integer;
begin
  Configuration.BeginUpdate;
  try
    if Assigned(ExpertLoaderList) then
    begin
      for I := 0 to ExpertLoaderList.Count - 1 do
      begin
        try
          TLateLoaderProc(ExpertLoaderList[I])(False);
        except
          Application.HandleException(Application);
        end;
      end;
    end;
  finally
    Configuration.EndUpdate;
  end;
end;

procedure IDELoaded;
var
  I, Index: Integer;
  Item, SeparatorItem: TMenuItem;
begin
  // Create main DDevExtensions submenu
  DDevExtensionsMenu := TMenuItem.Create(nil);
  DDevExtensionsMenu.Caption := 'DDevExtensions';

  // Create Options... menu item as first child
  MenuItemOptions := TMenuItem.Create(DDevExtensionsMenu);
  MenuItemOptions.OnClick := MakeNotifyEvent(nil, @ShowOptionsDialog);
  MenuItemOptions.Caption := '&Options...';
  DDevExtensionsMenu.Add(MenuItemOptions);

  // Add separator after Options
  SeparatorItem := TMenuItem.Create(DDevExtensionsMenu);
  SeparatorItem.Caption := '-';
  DDevExtensionsMenu.Add(SeparatorItem);

  // Add DDevExtensions submenu to Tools menu
  Item := FindMenuItem('ToolsMenu');
  if Item <> nil then
  begin
    Index := Item.IndexOf(FindMenuItem('ToolsDebuggerOptionsItem'));
    if Index = -1 then
      Index := Item.IndexOf(FindMenuItem('ToolsToolsItem')) - 1;
    if Index >= 0 then
      Item.Insert(Index + 1, DDevExtensionsMenu)
    else
      Item.Insert(1, DDevExtensionsMenu);
  end;

  Configuration.BeginUpdate;
  try
    if Assigned(LateLoaderList) then
    begin
      for I := 0 to LateLoaderList.Count - 1 do
      begin
        try
          TLateLoaderProc(LateLoaderList[I])(False);
        except
          Application.HandleException(Application);
        end;
      end;
    end;
  finally
    Configuration.EndUpdate;
  end;

  // Add separator and About... at end of submenu
  SeparatorItem := TMenuItem.Create( DDevExtensionsMenu );
  SeparatorItem.Caption := '-';
  DDevExtensionsMenu.Add( SeparatorItem );

  MenuItemAbout := TMenuItem.Create( DDevExtensionsMenu );
  MenuItemAbout.OnClick := MakeNotifyEvent( nil, @ShowAboutDialog );
  MenuItemAbout.Caption := '&About...';
  DDevExtensionsMenu.Add( MenuItemAbout );
end;

procedure UninstallHooks;
var
  I: Integer;
begin
  try
    if (LateLoaderList <> nil) or (ExpertLoaderList <> nil) then
    begin
      Configuration.BeginUpdate;
      try
        // LateLoader
        if LateLoaderList <> nil then
        begin
          for I := LateLoaderList.Count - 1 downto 0 do
          begin
            try
              TLateLoaderProc(LateLoaderList[I])(True);
            except
              Application.HandleException(Application);
            end;
          end;
          FreeAndNil(LateLoaderList);
        end;
        // ExpertLoader
        if ExpertLoaderList <> nil then
        begin
          for I := ExpertLoaderList.Count - 1 downto 0 do
          begin
            try
              TLateLoaderProc(ExpertLoaderList[I])(True);
            except
              Application.HandleException(Application);
            end;
          end;
          FreeAndNil(ExpertLoaderList);
        end;
      finally
        Configuration.EndUpdate;
      end;
    end;
  finally
    DoneSplash;

    if Assigned(OrgFinalizePackage) then
      CodeRestore(HookFinalizePackage);

    FiniComponentManager;

    FreeAndNil(DDevExtensionsMenu);
    FreeAndNil(DataModuleImages);
  end;
end;

end.
