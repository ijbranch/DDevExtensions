{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit IDEMenuHandler;

/// <summary>
/// Adds DDevExtensions menu items and shortcut bindings to the IDE main menu. Inserts a "File
/// Selector" entry under the Search menu, intercepts the View > Swap Source/Form action so it
/// also fires when the editor isn't focused, and (on Delphi 2007+) adds a placeholder for
/// future Set-Active-Build-Configuration handling.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  {$IFDEF COMPILER9_UP}
  ActnMan, ActnPopup,
  {$ENDIF COMPILER9_UP}
  Windows, Messages, SysUtils, Classes, Contnrs, Menus, ActnList, Forms, Controls,
  ToolsAPI;

type
  /// <summary>
  /// Owns the actions and menu items that this plug-in injects into the IDE. The class is
  /// instantiated once per session by InitPlugin and tears the additions back down on
  /// shutdown so that re-opening the package leaves no stale entries.
  /// </summary>
  TIDEMenuHandler = class(TObject)
  private
    /// <summary>Cached reference to the IDE's Project menu item (used to inject sub-items).</summary>
    FMenuProject: TMenuItem;
    /// <summary>List of TMenuItem instances created by the handler (frees them on destroy).</summary>
    FMenuItems: TObjectList;
    /// <summary>List of TAction instances created by the handler (frees them on destroy).</summary>
    FActionItems: TObjectList;

    {$IFDEF COMPILER9_UP}
    /// <summary>Original OnUpdate handler for ViewSwapSourceFormItem, restored at destroy.</summary>
    FOrgUpdateSwapSourceForm, FOrgExecuteSwapSourceForm: TNotifyEvent;
    /// <summary>Cached IDE menu item for View > Swap Source/Form.</summary>
    FViewSwapSourceFormItem: TMenuItem;
    {$ENDIF COMPILER9_UP}
    {$IFDEF DELPHI2007_UP}
    /// <summary>Action that triggers the (currently disabled) build-configuration sub-menu.</summary>
    FActionSetActiveBuildConfiguration: TAction;
    //FBuildConfigActions: TObjectList;
    {$ENDIF DELPHI2007_UP}

    /// <summary>Action that opens the DDevExtensions File Selector dialog.</summary>
    FActionFileSelector: TAction;

  protected
    /// <summary>
    /// Creates an IDE action plus a hosting menu item, registers them with INTAServices and
    /// inserts the menu item adjacent to BaseItemName.
    /// </summary>
    /// <param name="BaseMainItemName">Top-level menu (used as fall-back insertion target).</param>
    /// <param name="BaseItemName">The sibling or parent item to insert against.</param>
    /// <param name="ItemName">Component name to assign to the new menu item.</param>
    /// <param name="Caption">Menu item caption.</param>
    /// <param name="Execute">OnExecute handler for the action.</param>
    /// <param name="InsertAfter">True to insert after BaseItemName, False for before.</param>
    /// <param name="InsertAsChild">True to insert as a child of BaseItemName.</param>
    /// <param name="ShortCut">Initial keyboard shortcut (defaults to scNone).</param>
    /// <returns>The newly created TAction.</returns>
    function AddMenuAction(const BaseMainItemName, BaseItemName, ItemName, Caption: string;
      Execute: TNotifyEvent; InsertAfter, InsertAsChild: Boolean; ShortCut: TShortCut = scNone): TAction;

    /// <summary>Shared OnUpdate handler that adjusts visibility/enabled state of injected actions.</summary>
    procedure ActionUpdate(Sender: TObject);

    {$IFDEF COMPILER9_UP}
    /// <summary>Override for View > Swap Source/Form that synthesises the shortcut on the editor.</summary>
    procedure ExecuteSwapSourceForm(Sender: TObject);
    /// <summary>Override for View > Swap Source/Form's update handler so it stays enabled.</summary>
    procedure UpdateSwapSourceForm(Sender: TObject);
    {$ENDIF COMPILER9_UP}

    /// <summary>OnExecute handler for the File Selector action; opens TFormFileSelector.</summary>
    procedure FileSelectorItemClick(Sender: TObject);
  public
    /// <summary>Creates the handler and injects every menu item/action it manages.</summary>
    constructor Create;
    /// <summary>Restores any swapped IDE handlers and frees the injected actions/items.</summary>
    destructor Destroy; override;

    /// <summary>
    /// Updates the global hot-key associated with the File Selector action. Safe to call before
    /// the handler exists (the value is cached for the next Create).
    /// </summary>
    /// <param name="Value">The new TShortCut to assign, or scNone to clear it.</param>
    class procedure SetFindUseUnitHotKey(Value: TShortCut);
  end;

/// <summary>
/// Plug-in entry point. Creates the global TIDEMenuHandler instance on load and frees it on
/// unload.
/// </summary>
/// <param name="Unload">False during plug-in initialisation, True during plug-in shutdown.</param>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  ToolsAPIHelpers, AppConsts, FrmFileSelector;

var
  GlobalIDEMenuHandler: TIDEMenuHandler;
  GlobalFindUseUnitHotKey: TShortCut = scNone;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
  begin
    GlobalIDEMenuHandler := TIDEMenuHandler.Create;
  end
  else
  begin
    FreeAndNil(GlobalIDEMenuHandler);
  end;
end;

procedure SetActionShortCut(Action: TAction; Value: TShortCut);
begin
  if Action <> nil then
  begin
    Action.ShortCut := Value;
    {$IFDEF COMPILER6_UP}
    {$IFNDEF COMPILER9_UP}
    // Delphi 5-7 delete the shortcut without invoking the TBaseAction.Changed method
    Action.SecondaryShortCuts.Clear;
    if Value <> scNone then
      Action.SecondaryShortCuts.Add(ShortCutToText(Value));
    {$ENDIF ~COMPILER9_UP}
    {$ENDIF COMPILER6_UP}
  end;
end;

class procedure TIDEMenuHandler.SetFindUseUnitHotKey(Value: TShortCut);
begin
  GlobalFindUseUnitHotKey := Value;
  if GlobalIDEMenuHandler <> nil then
    SetActionShortCut(GlobalIDEMenuHandler.FActionFileSelector, GlobalFindUseUnitHotKey);
end;

{ TIDEMenuHandler }

constructor TIDEMenuHandler.Create;
begin
  inherited Create;
  FMenuItems := TObjectList.Create;
  FActionItems := TObjectList.Create;

  FMenuProject := FindMenuItem('ProjectMenu');

  {$IFDEF COMPILER9_UP}
  {$IFNDEF DELPHI2007_UP}
  FViewSwapSourceFormItem := FindMenuItem('ViewSwapSourceFormItem');
  if (FViewSwapSourceFormItem <> nil) and (FViewSwapSourceFormItem.Action <> nil) then
  begin
    FOrgUpdateSwapSourceForm := FViewSwapSourceFormItem.Action.OnUpdate;
    FOrgExecuteSwapSourceForm := FViewSwapSourceFormItem.Action.OnExecute;
    FViewSwapSourceFormItem.Action.OnUpdate := UpdateSwapSourceForm;
    FViewSwapSourceFormItem.Action.OnExecute := ExecuteSwapSourceForm;
  end;
  {$ENDIF ~DELPHI2007_UP}
  {$ENDIF COMPILER9_UP}

  {$IFDEF INCLUDE_FILESELECTOR}
  if FindMenuItem('SearchGotoAddressItem') <> nil then
    FActionFileSelector := AddMenuAction('SearchMenu', 'SearchGotoAddressItem',
      'DDevExtFileSelectorItem', sMenuItemDDevExtensionsFileSelector,
      FileSelectorItemClick, True, False, GlobalFindUseUnitHotKey)
  else
    FActionFileSelector := AddMenuAction('SearchMenu', 'SearchGoToItem',
      'DDevExtFileSelectorItem', sMenuItemDDevExtensionsFileSelector,
      FileSelectorItemClick, True, False, GlobalFindUseUnitHotKey);
  {$ENDIF INCLUDE_FILESELECTOR}

  ActionUpdate(nil);
end;

destructor TIDEMenuHandler.Destroy;
begin
  {$IFDEF COMPILER9_UP}
  if Assigned(FViewSwapSourceFormItem) and Assigned(FViewSwapSourceFormItem.Action) then
  begin
    FViewSwapSourceFormItem.Action.OnUpdate := FOrgUpdateSwapSourceForm;
    FViewSwapSourceFormItem.Action.OnExecute := FOrgExecuteSwapSourceForm;
  end;
  {$ENDIF COMPILER9_UP}

  FMenuItems.Free;
  FActionItems.Free;
  inherited Destroy;
end;

procedure TIDEMenuHandler.FileSelectorItemClick(Sender: TObject);
begin
  {$IFDEF INCLUDE_FILESELECTOR}
  TFormFileSelector.Execute(True);
  {$ENDIF INCLUDE_FILESELECTOR}
end;

procedure TIDEMenuHandler.ActionUpdate(Sender: TObject);
var
  {$IFDEF DELPHI2007_UP}
  //ActiveConfig, Config: IBuildConfiguration;
  MenuProjectBuildConfigsItem: TMenuItem;
  i: Integer;
  {$ENDIF DELPHI2007_UP}
  IsDelphiPers, IsDelphiNetPers: Boolean;
begin
  {$IFDEF COMPILER6_UP}
  {$IFNDEF COMPILER9_UP}
  if Sender is TAction then
  begin
    // Delphi 5-7 delete the shortcut without invoking the TBaseAction.Changed method
    if (TAction(Sender).ShortCut = 0) and (TAction(Sender).SecondaryShortCuts.Count > 0) then
    begin
      TAction(Sender).ShortCut := TAction(Sender).SecondaryShortCuts.ShortCuts[0];
      TAction(Sender).SecondaryShortCuts.Clear;
    end;
  end;
  {$ENDIF ~COMPILER9_UP}
  {$ENDIF COMPILER6_UP}

  IsDelphiPers := IsDelphiPersonality(nil);
  IsDelphiNetPers := IsDelphiNetPersonality(nil);
  if Assigned(FActionFileSelector) then
  begin
    FActionFileSelector.Visible := IsDelphiPers or IsDelphiNetPers;
    FActionFileSelector.Enabled := FActionFileSelector.Visible;
  end;

  {$IFDEF DELPHI2007_UP}
  { The ProjectBuildConfigsItem is created by the CBuilder-Personality and that
    is too late for the PluginInit code. So we create the menu item here. }
  if Assigned(FMenuProject) and not Assigned(FActionSetActiveBuildConfiguration) then
  begin
    MenuProjectBuildConfigsItem := nil;
    for i := 0 to FMenuProject.Count - 1 do
    begin
      if FMenuProject.Items[i].Name = 'ProjectBuildConfigsItem' then
      begin
        MenuProjectBuildConfigsItem := FMenuProject.Items[i];
        Break;
      end;
    end;
    if Assigned(MenuProjectBuildConfigsItem) then
    begin
      FActionSetActiveBuildConfiguration := AddMenuAction('ProjectMenu', MenuProjectBuildConfigsItem.Name,
        'MenuProjectSetActiveBuildConfigItem', RsSetActiveBuildConfiguration, nil, False, False);
      FActionSetActiveBuildConfiguration.OnUpdate := ActionUpdate;
    end;
  end;

  if Assigned(FActionSetActiveBuildConfiguration) then
    FActionSetActiveBuildConfiguration.Visible := IsDelphiPers;

  if Assigned(FActionSetActiveBuildConfiguration) and (Sender = FActionSetActiveBuildConfiguration) then
  begin
    { Easier Build Configuration selection }
(*    ProjOpts := nil;
    if (ActiveProject <> nil) and not Active then
      ProjOpts := GetProjectOptions(ActiveProject);

    FActionSetActiveBuildConfiguration.Enabled := (ProjOpts <> nil) and (ProjOpts.GetBuildConfigurationCount > 1);

    TMenuItem(FActionSetActiveBuildConfiguration.Tag).Clear;
    FBuildConfigActions.Clear;
    if (ProjOpts <> nil) and FActionSetActiveBuildConfiguration.Enabled then
    begin
      { Build sub menu }
      ActiveConfig := ProjOpts.GetActiveConfiguration;
      for i := 0 to ProjOpts.GetBuildConfigurationCount - 1 do
      begin
        Config := ProjOpts.GetBuildConfiguration(i);
        SubAction := TAction.Create(nil);
        SubAction.Caption := Config.Name;
        SubAction.Hint := Config.Name;
        SubAction.Tag := i;
        SubAction.AutoCheck := True;
        SubAction.Checked := Config = ActiveConfig;
        SubAction.OnExecute := DoExecuteSetActiveBuildConfig;

        MenuItem := TMenuItem.Create(SubAction);
        MenuItem.Name := 'bcc32pch_MenuItemBuildConfig' + IntToStr(i);
        MenuItem.Action := SubAction;
        MenuItem.RadioItem := True;

        FBuildConfigActions.Add(SubAction);
        NServices.AddActionMenu(TMenuItem(FActionSetActiveBuildConfiguration.Tag).Name, SubAction, MenuItem, True, True);
      end;
    end;*)
  end

  {$ENDIF DELPHI2007_UP}
end;

function TIDEMenuHandler.AddMenuAction(const BaseMainItemName, BaseItemName, ItemName, Caption: string;
  Execute: TNotifyEvent; InsertAfter: Boolean; InsertAsChild: Boolean; ShortCut: TShortCut): TAction;
var
  MenuItem: TMenuItem;
  {$IFNDEF COMPILER9_UP}
  Item: TMenuItem;
  i: Integer;
  {$ELSE}
  NServices: INTAServices;
  {$ENDIF ~COMPILER9_UP}
begin
  Result := TAction.Create(nil);
  Result.Name := 'Action' + ItemName;
  Result.Caption := Caption;
  SetActionShortCut(Result, ShortCut);
  Result.OnExecute := Execute;
  Result.OnUpdate := ActionUpdate;

  MenuItem := TMenuItem.Create(Result);
  MenuItem.Name := ItemName;
  MenuItem.Action := Result;
  MenuItem.ShortCut := ShortCut;
  Result.Tag := NativeInt(MenuItem);

  FActionItems.Add(Result);
  FMenuItems.Add(MenuItem);

  {$IFDEF COMPILER9_UP}
  NServices := BorlandIDEServices as INTAServices;
  NServices.AddActionMenu(BaseItemName, Result, MenuItem, InsertAfter, InsertAsChild);
  {$ELSE}
  Item := nil;
  for i := 0 to FMenuItems.Count - 1 do
  begin
    if CompareText(TMenuItem(FMenuItems[i]).Name, BaseItemName) = 0 then
    begin
      Item := TMenuItem(FMenuItems[i]);
      Break;
    end;
  end;

  if Item = nil then
  begin
    Item := TMenuItem(Application.MainForm.FindComponent(BaseItemName));
    if not (TObject(Item) is TMenuItem) then
    begin
      Item := TMenuItem(Application.MainForm.FindComponent(BaseMainItemName));
      if not (TObject(Item) is TMenuItem) then
        Item := nil;
      InsertAsChild := True;
    end;
  end;

  if Item <> nil then
  begin
    if InsertAsChild then
    begin
      if InsertAfter then
        Item.Add(MenuItem)
      else
        Item.Insert(0, MenuItem);
    end
    else
      Item.Parent.Insert(Item.Parent.IndexOf(Item) + Ord(InsertAfter), MenuItem);

    Result.ActionList := (BorlandIDEServices as INTAServices).ActionList;
    Result.ShortCut := ShortCut;
  end
  else
    raise Exception.CreateFmt('Menu item "%s" not found.', [BaseItemName]);
  {$ENDIF COMPILER9_UP}
end;


{$IFDEF COMPILER9_UP}
procedure TIDEMenuHandler.ExecuteSwapSourceForm(Sender: TObject);
const
  AltMask = $20000000;
var
  i: Integer;
  EditorLocalMenu: TPopupActionBar;
  Msg: TWMKey;
  Shift: TShiftState;
begin
  for i := 0 to Screen.FormCount - 1 do
  begin
    if Screen.Forms[i].Visible and Screen.Forms[i].Enabled and
       Screen.Forms[i].CanFocus and
       Screen.Forms[i].ClassNameIs('TEditWindow') then
    begin
      EditorLocalMenu := TPopupActionBar(Screen.Forms[i].FindComponent('EditorLocalMenu'));
      if EditorLocalMenu <> nil then
      begin
        Msg.Msg := WM_KEYDOWN;
        ShortCutToKey(TAction(Sender).ShortCut, Msg.CharCode, Shift);
        if ssAlt in Shift then
          Msg.KeyData := AltMask;
        EditorLocalMenu.IsShortCut(Msg);
      end;
      Break;
    end;
  end;
end;

procedure TIDEMenuHandler.UpdateSwapSourceForm(Sender: TObject);
begin
  FOrgUpdateSwapSourceForm(Sender);
  TAction(Sender).Enabled := True;
end;
{$ENDIF COMPILER9_UP}


end.

