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

/// <summary>
/// Main entry point and orchestration unit for the DDevExtensions design-time
/// package. Owns the IDE menu, plug-in load lifecycle (expert-loader and
/// late-loader queues), the AppData configuration directory and the global
/// API hook list.
/// </summary>
/// <remarks>
/// <para><b>Lifecycle:</b> <see cref="InstallHooks"/> is called from the
/// package <c>Register</c> entry point. It initialises <see cref="AppDataDirectory"/>,
/// hooks <c>SysUtils.FinalizePackage</c> (so unloaded design packages have
/// their components removed from <see cref="ComponentManager.RegisteredComponents"/>),
/// then runs the expert-loader queue. After the IDE main form becomes visible
/// the <c>Splash</c> unit calls <see cref="IDELoaded"/>, which builds the
/// "DDevExtensions" tool-menu sub-menu and runs the late-loader queue.</para>
/// <para><b>Late vs Expert loaders:</b> Expert loaders run before the main
/// IDE form exists; late loaders run after the IDE has fully initialised.</para>
/// </remarks>

{$I DelphiExtension.inc}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Hooking, IDEUtils, Splash, System.Win.Registry, Vcl.Forms, Vcl.Menus,
  Vcl.Graphics, Vcl.Controls, Vcl.ExtCtrls, Vcl.ActnList, AppConsts, ToolsAPI, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ComCtrls, Winapi.ActiveX, Winapi.ShlObj, ImportHooking;

type
  /// <summary>
  /// Callback signature for plug-in loaders.
  /// Called once with <c>Unload=False</c> at startup and once with
  /// <c>Unload=True</c> at shutdown.
  /// </summary>
  TLateLoaderProc = procedure(Unload: Boolean);

/// <summary>
/// Installs all DDevExtensions IDE hooks and runs the expert-loader queue.
/// Called from the package's design-time <c>Register</c> entry point.
/// </summary>
procedure InstallHooks;
/// <summary>Tears down hooks, runs every loader with <c>Unload=True</c>, and frees the menu/data module.</summary>
procedure UninstallHooks;

/// <summary>Runs the expert-loader queue (each registered <see cref="TLateLoaderProc"/> with <c>Unload=False</c>).</summary>
procedure ExpertLoaded;
/// <summary>
/// Builds the "DDevExtensions" Tool-menu sub-menu and runs the late-loader
/// queue. Invoked by <c>Splash</c> once the IDE main form is visible.
/// </summary>
procedure IDELoaded; // called by Splash

/// <summary>Adds a callback to the expert-loader queue (runs before the IDE main form is shown).</summary>
procedure RegisterExpertLoader(Proc: TLateLoaderProc);
/// <summary>Adds a callback to the late-loader queue (runs after the IDE main form is visible).</summary>
procedure RegisterLateLoader(Proc: TLateLoaderProc);
/// <summary>
/// Resolves and creates the per-user DDevExtensions AppData directory
/// (e.g. <c>%APPDATA%\DDevExtensions</c>) and stores it in
/// <see cref="AppDataDirectory"/>. Safe to call multiple times.
/// </summary>
procedure InitAppDataDirectory; // called by InstallHooks

{$IFDEF CPUX64}
/// <summary>
/// Win64 shutdown diagnostic — appends a line to <c>%APPDATA%\DDevExtensions\Win64Shutdown.log</c>
/// describing where in the teardown path an exception was swallowed. Public so feature
/// destructors that wrap their own steps in try/except can attribute precisely.
/// </summary>
procedure LogWin64UnloadFailure(const LoaderKind: string; Index: Integer; E: Exception);
/// <summary>
/// Win64 shutdown diagnostic — like <see cref="LogWin64UnloadFailure"/> but takes a
/// free-form step label (e.g. <c>'TCompileProgress.FBuildStatsMenuItem.Free'</c>).
/// </summary>
procedure LogWin64UnloadStep(const StepName: string; E: Exception);
{$ENDIF}

var
  /// <summary>Global PE-import-table hook list shared by features that need to redirect Windows API calls.</summary>
  APIHookList: TJclPeMapImgHooks;
  /// <summary>Per-user directory used to persist DDevExtensions configuration files.</summary>
  AppDataDirectory: string;
  /// <summary>Sub-menu inserted into the IDE Tools menu; hosts every DDevExtensions menu item.</summary>
  DDevExtensionsMenu: TMenuItem;  // Submenu for DDevExtensions tools

implementation

uses
  System.SysConst, IDEHooks, ComponentManager, DtmImages, FrmDDevExtOptions, RegisterPlugins,
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
  // If the AppData directory cannot be created (locked-down / redirected APPDATA),
  // fall back beside the executable so later config saves are not silently lost.
  if not ForceDirectories(AppDataDirectory) then
  begin
    OutputDebugString(PChar('DDevExtensions: cannot create ' + AppDataDirectory +
      '; falling back to the executable directory.'));
    AppDataDirectory := ExtractFileDir(ParamStr(0));
  end;
end;

procedure InstallHooks;
begin
  InitAppDataDirectory;
  DataModuleImages := TDataModuleImages.Create(nil);

  OrgFinalizePackage := @FinalizePackage;
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
  Item, SeparatorItem, AnchorItem: TMenuItem;
begin
  // IDELoaded is reached from both the splash poll timer and the splash
  // component's destructor; run it exactly once. Otherwise the submenu and every
  // late loader (notifiers, hooks) would be created twice and the previous
  // DDevExtensionsMenu would leak.
  if Assigned(DDevExtensionsMenu) then
    Exit;

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
    // Resolve a known anchor and compute the insert position from it. Resolving
    // the anchor first avoids the -2 magic intermediate (IndexOf(nil) - 1) when
    // neither anchor exists on this personality, in which case we insert near top.
    Index := -1;
    AnchorItem := FindMenuItem('ToolsDebuggerOptionsItem');
    if AnchorItem <> nil then
      Index := Item.IndexOf(AnchorItem) + 1   // insert after the Debugger Options item
    else
    begin
      AnchorItem := FindMenuItem('ToolsToolsItem');
      if AnchorItem <> nil then
        Index := Item.IndexOf(AnchorItem);     // insert before the Tools item
    end;
    if Index >= 1 then
      Item.Insert(Index, DDevExtensionsMenu)
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

{$IFDEF CPUX64}
/// <summary>
/// Writes a single line to <c>%APPDATA%\DDevExtensions\Win64Shutdown.log</c> and
/// also emits it via <c>OutputDebugString</c>. Every operation is wrapped in
/// <c>try/except</c> because we are already on the exception path during process
/// teardown.
/// </summary>
procedure WriteWin64ShutdownLine(const Line: string);
var
  LogPath: string;
  Stream: TFileStream;
  Bytes: TBytes;
begin
  if Line = '' then Exit;
  try
    OutputDebugString(PChar(Line));
  except
    // OutputDebugString isn't expected to throw, but defensive on teardown.
  end;
  try
    LogPath := AppDataDirectory + '\Win64Shutdown.log';
    if FileExists(LogPath) then
      Stream := TFileStream.Create(LogPath, fmOpenWrite or fmShareDenyWrite)
    else
      Stream := TFileStream.Create(LogPath, fmCreate or fmShareDenyWrite);
    try
      Stream.Seek(0, soEnd);
      Bytes := TEncoding.UTF8.GetBytes(Line);
      if Length(Bytes) > 0 then
        Stream.WriteBuffer(Bytes[0], Length(Bytes));
    finally
      Stream.Free;
    end;
  except
    // If we can't write the log we still got the dialog suppressed; don't
    // re-raise during teardown.
  end;
end;

/// <summary>
/// Win64-only diagnostic helper. Appends a line describing an unloader failure
/// to the Win64 shutdown log. Used by <see cref="UninstallHooks"/> to attribute
/// the cascade of "Delphi 13 (64-bit)" AV dialogs that earlier appeared at
/// Win64 IDE shutdown.
/// </summary>
procedure LogWin64UnloadFailure(const LoaderKind: string; Index: Integer; E: Exception);
var
  Line: string;
begin
  try
    Line := Format('%s  DDevExtensions[Win64]: %s[%d] unload threw %s: %s'#13#10,
      [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now), LoaderKind, Index,
       string(E.ClassName), E.Message]);
  except
    Line := '';
  end;
  WriteWin64ShutdownLine(Line);
end;

/// <summary>
/// Win64-only diagnostic helper for fine-grained step labels — used by feature
/// destructors that wrap individual cleanup operations in their own try/except.
/// </summary>
procedure LogWin64UnloadStep(const StepName: string; E: Exception);
var
  Line: string;
begin
  try
    Line := Format('%s  DDevExtensions[Win64]: step %s threw %s: %s'#13#10,
      [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now), StepName,
       string(E.ClassName), E.Message]);
  except
    Line := '';
  end;
  WriteWin64ShutdownLine(Line);
end;
{$ENDIF}

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
              {$IFDEF CPUX64}
              on E: Exception do
              begin
                // Win64: per-unloader failures on shutdown trigger one IDE-owned
                // "Delphi 13 (64-bit)" AV dialog per call, producing a cascade of
                // 16+ identical dialogs. The IDE is already exiting, so swallow
                // silently rather than spam the user.
                //
                // TODO(Win64): we don't yet know *which* unloader(s) throw or why.
                // The actual fault may originate in a dependent BPL's finalization
                // (e.g. edbrun240rsdelphiwin6413.bpl + 0x300D44) and bubble up to
                // us, or one of our own unloaders may be calling a ToolsAPI service
                // whose Win64 vtable layout we mishandle. Replace this swallow with
                // proper per-feature fixes once we've attributed each fault.
                LogWin64UnloadFailure('LateLoader', I, E);
              end;
              {$ELSE}
              Application.HandleException(Application);
              {$ENDIF}
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
              {$IFDEF CPUX64}
              on E: Exception do
              begin
                // See LateLoader loop above — silent on Win64 shutdown.
                // TODO(Win64): attribute each throwing unloader and fix at source.
                LogWin64UnloadFailure('ExpertLoader', I, E);
              end;
              {$ELSE}
              Application.HandleException(Application);
              {$ENDIF}
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
