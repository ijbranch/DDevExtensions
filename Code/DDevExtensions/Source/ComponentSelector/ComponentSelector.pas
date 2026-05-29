{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit ComponentSelector;

/// <summary>
/// Provides the Component Selector toolbar control that lives in the IDE main toolbar
/// and lets the developer locate and pick a VCL/FMX component by typing all or part of
/// its class name. Supports a sortable, filtered drop-down list with optional palette
/// grouping plus a configurable hotkey to focus the search edit.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Vcl.CategoryButtons, PaletteAPI,
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Contnrs, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, ToolsAPI, Vcl.ActnList, System.Win.Registry, FrmTreePages,
  Winapi.MultiMon, Vcl.Menus, Vcl.ImgList, ToolsAPIHelpers, EditPopupCtrl;

type
  /// <summary>
  /// Persisted layout state for the Component Selector toolbar (position and visibility).
  /// </summary>
  TToolbarInfo = packed record
    /// <summary>Toolbar X coordinate within its parent ControlBar.</summary>
    Left, Top: Integer;
    /// <summary>True when the toolbar is currently shown in the IDE.</summary>
    Visible: Boolean;
  end;

  /// <summary>
  /// Represents a single component palette entry shown in the selector drop-down list,
  /// together with its owning module, palette page, class reference and any additional
  /// data needed for icon painting and selection.
  /// </summary>
  TCompItem = class(TObject)
  private
    /// <summary>Module handle of the BPL providing the component.</summary>
    FModule: HMODULE;
    /// <summary>Palette page (category) caption that owns the component.</summary>
    FPalette: string;
    /// <summary>Display name of the component on the palette.</summary>
    FCompName: string;
    /// <summary>Auxiliary data, typically a <see cref="TPaletteItemHolder"/>.</summary>
    FData: TObject;
    /// <summary>Class reference of the component when known.</summary>
    FComponentClass: TComponentClass;
  public
    /// <summary>
    /// Creates the item, capturing the module handle, palette page, component name,
    /// optional class reference and arbitrary holder data.
    /// </summary>
    /// <param name="AModule">Module handle of the providing BPL.</param>
    /// <param name="APalette">Palette page caption.</param>
    /// <param name="ACompName">Display name of the component.</param>
    /// <param name="AComponentClass">Class reference, or nil when unknown.</param>
    /// <param name="AData">Optional auxiliary data; freed when it is a <see cref="TPaletteItemHolder"/>.</param>
    constructor Create(AModule: HMODULE; const APalette, ACompName: string;
      AComponentClass: TComponentClass; AData: TObject);
    /// <summary>Frees the item and any owned <see cref="TPaletteItemHolder"/> data.</summary>
    destructor Destroy; override;
    /// <summary>Loads the component bitmap for the represented class.</summary>
    /// <returns>A bitmap handle for the component glyph, or 0 when not available.</returns>
    function LoadBitmap: HBitmap;

    /// <summary>Palette page caption that owns the component.</summary>
    property Palette: string read FPalette;
    /// <summary>Display name of the component.</summary>
    property CompName: string read FCompName;
    /// <summary>Optional auxiliary data attached to the item.</summary>
    property Data: TObject read FData;
    /// <summary>Class reference for the component, when known.</summary>
    property ComponentClass: TComponentClass read FComponentClass;
    /// <summary>Module handle of the providing BPL.</summary>
    property Module: HMODULE read FModule;
  end;

  /// <summary>
  /// Specialised drop-down edit used by the Component Selector. Hosts a bottom panel
  /// with the simple-search and palette-sort checkboxes plus a status caption, and
  /// paints the search prompt graphic when the edit is unfocused.
  /// </summary>
  TDropDownEdit = class(TDropDownEditBase)
  private
    /// <summary>Footer panel hosting the option checkboxes and result count caption.</summary>
    FPanelBottom: TPanel;
    /// <summary>Toggles prefix-match (simple) versus substring search.</summary>
    FCheckBoxSimpleSearch: TCheckBox;
    /// <summary>Notifies the owning selector when the user changes an option.</summary>
    FOnOptionsChanged: TNotifyEvent;
    /// <summary>Toggles grouping of results by palette page.</summary>
    FCheckBoxPaletteSort: TCheckBox;
    /// <summary>Custom WM_PAINT handler that draws the search prompt when unfocused.</summary>
    procedure WMPaint(var Msg: TWMPaint); message WM_PAINT;
  protected
    /// <summary>Returns focus to the drop-down panel after a checkbox click.</summary>
    /// <param name="Sender">The control that triggered the focus change.</param>
    procedure LooseFocus(Sender: TObject);
    /// <summary>Common click handler for the option checkboxes; raises <see cref="OnOptionsChanged"/>.</summary>
    /// <param name="Sender">The checkbox that changed.</param>
    procedure DoOptionChangeClick(Sender: TObject);
  public
    /// <summary>Creates the edit and constructs its hosted footer panel and checkboxes.</summary>
    /// <param name="AOwner">Owner component for memory management.</param>
    constructor Create(AOwner: TComponent); override;
    /// <summary>Footer panel hosting the option checkboxes and counter.</summary>
    property PanelBottom: TPanel read FPanelBottom;
    /// <summary>Checkbox toggling simple (prefix) search mode.</summary>
    property CheckBoxSimpleSearch: TCheckBox read FCheckBoxSimpleSearch;
    /// <summary>Checkbox toggling palette grouping in the result list.</summary>
    property CheckBoxPaletteSort: TCheckBox read FCheckBoxPaletteSort;
    /// <summary>Recalculates the drop-down bounds, accounting for the footer panel.</summary>
    procedure UpdateDropDownBounds; override;

    /// <summary>Fired after any option checkbox changes value.</summary>
    property OnOptionsChanged: TNotifyEvent read FOnOptionsChanged write FOnOptionsChanged;
  end;

  /// <summary>
  /// Top-level controller for the Component Selector feature. Creates and owns the
  /// IDE toolbar, the drop-down edit, the filter debounce timer and the global
  /// hotkey action; persists configuration in the registry.
  /// </summary>
  TComponentSelector = class(TComponent)
  private
    /// <summary>Drop-down edit that hosts the search field and result list.</summary>
    FEdit: TDropDownEdit;
    /// <summary>Custom IDE toolbar that hosts the search edit.</summary>
    FToolBar: TToolBar;
    /// <summary>Timer that debounces user typing before the result list is rebuilt.</summary>
    FTimerFilterUpdate: TTimer;
    /// <summary>Reference to the IDE component palette being mirrored.</summary>
    FPalette: TCategoryButtons;
    /// <summary>Owns the per-result <see cref="TPaletteItemHolder"/> instances.</summary>
    FCompObjects: TObjectList;
    /// <summary>IDE action providing the configurable focus hotkey.</summary>
    FHotkeyAction: TAction;

    /// <summary>Timer tick handler that performs the debounced list rebuild.</summary>
    /// <param name="Sender">The triggering timer.</param>
    procedure TimerFilterUpdateTimer(Sender: TObject);
    /// <summary>OnChange handler for the search edit; restarts the filter timer.</summary>
    /// <param name="Sender">The search edit control.</param>
    procedure EditChange(Sender: TObject);
    /// <summary>OnKeyPress handler that selects the highlighted item on Enter.</summary>
    /// <param name="Sender">The search edit control.</param>
    /// <param name="Key">The pressed character; cleared after handling.</param>
    procedure EditKeyPress(Sender: TObject; var Key: Char);

    /// <summary>Owner-draw callback used to render each list entry with its glyph and palette label.</summary>
    /// <param name="Control">The host listbox.</param>
    /// <param name="Index">Index of the item being painted.</param>
    /// <param name="Rect">Bounds of the item.</param>
    /// <param name="State">Current draw state flags.</param>
    procedure DrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    /// <summary>Selects the clicked component palette item without executing it.</summary>
    /// <param name="Sender">The host listbox.</param>
    procedure ClickItem(Sender: TObject); overload;
    /// <summary>Selects the clicked component palette item and optionally executes it.</summary>
    /// <param name="Sender">The host listbox.</param>
    /// <param name="ExecuteItem">When true, simulates a double-click to instantiate the component immediately.</param>
    procedure ClickItem(Sender: TObject; ExecuteItem: Boolean); overload;
    /// <summary>Refreshes the result list immediately before the drop-down is shown.</summary>
    /// <param name="Sender">The drop-down edit raising the event.</param>
    procedure BeforeDropDown(Sender: TObject);
    /// <summary>Handles option changes by saving config and refreshing the list.</summary>
    /// <param name="Sender">The drop-down edit.</param>
    procedure OptionsChanged(Sender: TObject);
    /// <summary>Setter for <see cref="Hotkey"/>; updates the IDE action shortcut.</summary>
    /// <param name="Value">The new shortcut.</param>
    procedure SetHotkey(const Value: TShortCut);
    /// <summary>Returns the currently configured hotkey shortcut.</summary>
    function GetHotkey: TShortCut;
  protected
    /// <summary>Determines whether <paramref name="AClassName"/> matches the current filter text.</summary>
    /// <param name="AClassName">Component class name to test.</param>
    /// <returns>True when the entry should appear in the result list.</returns>
    function Filter(const AClassName: string): Boolean;
    /// <summary>Executes the focus hotkey action by opening and focusing the search edit.</summary>
    /// <param name="Sender">The source action.</param>
    procedure ExecuteHotkeyAction(Sender: TObject);
    /// <summary>Walks the IDE palette and rebuilds the filtered result list.</summary>
    procedure UpdateComponentList;
//    procedure DoTimer(Sender: TObject); //testing
    /// <summary>Returns the option page tree node registered for this feature.</summary>
    function GetOptionPages: TTreePage; virtual;
    /// <summary>Loads the toolbar geometry, options and hotkey from the registry.</summary>
    procedure LoadToolbarConfig;
  public
    /// <summary>Creates the controller, registering hooks, options page and IDE action.</summary>
    /// <param name="AOwner">Owner component, typically the IDE main form.</param>
    constructor Create(AOwner: TComponent); override;
    /// <summary>Saves toolbar configuration and releases owned resources.</summary>
    destructor Destroy; override;

    /// <summary>Persists the toolbar geometry, options and hotkey to the registry.</summary>
    procedure SaveToolbarConfig;

    /// <summary>Configurable IDE-wide hotkey that focuses and opens the search edit.</summary>
    property Hotkey: TShortCut read GetHotkey write SetHotkey;
    /// <summary>The drop-down edit hosting the search input and result list.</summary>
    property Edit: TDropDownEdit read FEdit;
    /// <summary>The IDE toolbar that hosts the search edit.</summary>
    property ToolBar: TToolBar read FToolBar;
  end;

  /// <summary>
  /// Lightweight wrapper that owns a reference to a <see cref="TButtonItem"/> palette
  /// entry so it can be safely attached to <see cref="TCompItem.Data"/>.
  /// </summary>
  TPaletteItemHolder = class(TObject)
  private
    /// <summary>The wrapped palette button item.</summary>
    FItem: TButtonItem;
  public
    /// <summary>Creates the holder for the supplied palette button item.</summary>
    /// <param name="AItem">The palette button item to hold.</param>
    constructor Create(AItem: TButtonItem);
    /// <summary>The wrapped palette button item.</summary>
    property Item: TButtonItem read FItem;
  end;

/// <summary>Returns the singleton <see cref="TComponentSelector"/> instance, or nil when the plugin is unloaded.</summary>
function ComponentSelectorCtrl: TComponentSelector;
/// <summary>Plugin entry point; creates or destroys the singleton controller.</summary>
/// <param name="Unload">When true, the controller is freed; otherwise it is created.</param>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  ComponentManager, IDEUtils, IDEHooks, System.Math, AppConsts, System.TypInfo,
  FrmeOptionPageComponentSelector, FrmOptions, DtmImages;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    TComponentSelector.Create(Application.MainForm)
  else
    ComponentSelectorCtrl.Free;
end;

var
  GlobalComponentSelectorCtrl: TComponentSelector;

function ComponentSelectorCtrl: TComponentSelector;
begin
  Result := GlobalComponentSelectorCtrl;
end;

{ TPaletteItemHolder }

constructor TPaletteItemHolder.Create(AItem: TButtonItem);
begin
  inherited Create;
  FItem := AItem;
end;

{ TCompItem }

constructor TCompItem.Create(AModule: HMODULE; const APalette, ACompName: string;
  AComponentClass: TComponentClass; AData: TObject);
begin
  inherited Create;
  FModule := AModule;
  FPalette := APalette;
  FCompName := ACompName;
  FData := AData;
  FComponentClass := AComponentClass;
end;

destructor TCompItem.Destroy;
begin
  if FData is TPaletteItemHolder then
    FData.Free;
  inherited Destroy;
end;

function TCompItem.LoadBitmap: HBitmap;
begin
  Result := LoadComponentBitmap(ComponentClass);
end;

function PaletteSortCompare(List: TStringList; Index1, Index2: Integer): Integer;
var
  c1, c2: TCompItem;
begin
  c1 := TCompItem(List.Objects[Index1]);
  c2 := TCompItem(List.Objects[Index2]);
  Result := AnsiCompareText(c1.Palette, c2.Palette);
  if Result = 0 then
    Result := AnsiCompareText(c1.CompName, c2.CompName);
end;

{ TComponentSelector }

constructor TComponentSelector.Create(AOwner: TComponent);
var
  ControlBar: TControlBar;
  Services: INTAServices;
begin
  inherited Create(AOwner);

  GlobalComponentSelectorCtrl := Self;
  TFormOptions.RegisterPages(GetOptionPages);
  FHotkeyAction := TAction.Create(nil);
  FHotkeyAction.OnExecute := ExecuteHotkeyAction;
  FCompObjects := TObjectList.Create;

  ControlBar := TControlBar(Application.MainForm.FindComponent('ControlBar1'));
  if ControlBar <> nil then
  begin
    if Supports(BorlandIDEServices, INTAServices, Services) then
      FHotkeyAction.ActionList := Services.ActionList;
    FToolBar := NewToolBar(Self, 'ToolBarDDevExtensionsComponentSelector', 'ComponentSelector', False);

    FEdit := TDropDownEdit.Create(Self);
    FEdit.Name := 'EditDDevExtensionsComponentSelector';
    FEdit.Text := '';
    FEdit.Width := 150;
    FToolBar.Top := Application.MainForm.Height;
    FToolBar.Left := ControlBar.ClientWidth - FToolBar.Width;
    FEdit.Parent := FToolBar;
    FToolBar.Left := ControlBar.ClientWidth - FToolBar.Width;
    FEdit.OnChange := EditChange;
    FEdit.OnKeyPress := EditKeyPress;
    FEdit.ListBox.Color := clBtnFace;
    FEdit.ListBox.Style := lbOwnerDrawFixed;
    FEdit.ListBox.OnDrawItem := DrawItem;
    FEdit.ListBox.ItemHeight := 26;
    FEdit.DropDownWidth := 250;
    FEdit.DropDownHeight := FEdit.ListBox.ItemHeight * 25;
    FEdit.CheckBoxPaletteSort.Checked := True;
    FEdit.ListBox.OnClick := ClickItem;
    FEdit.OnBeforeDropDown := BeforeDropDown;
    FEdit.OnOptionsChanged := OptionsChanged;

    FTimerFilterUpdate := TTimer.Create(Self);
    FTimerFilterUpdate.Enabled := False;
    FTimerFilterUpdate.Interval := 170;
    FTimerFilterUpdate.OnTimer := TimerFilterUpdateTimer;

    LoadToolbarConfig;
  end;
end;

destructor TComponentSelector.Destroy;
begin
  if Assigned(FToolBar) then
    SaveToolbarConfig;
  GlobalComponentSelectorCtrl := nil;
  FHotkeyAction.Free; // must be destroyed after SaveToolbarConfig
  FCompObjects.Free;
  inherited Destroy;
end;

procedure TComponentSelector.UpdateComponentList;
var
  i: Integer;
  List: TStrings;
  PaletteName, CompName: string;
  PalIndex: Integer;
  Categories: TButtonCategories;
  PalGroup: TButtonCategory;
  PalGroupItems: TButtonCollection;
  PalItem: TButtonItem;
  Holder: TPaletteItemHolder;
  SelText: string;
  EditTextLen: Integer;
  Len: Integer;
  MinLenDiff: Integer;
  MinLenDiffIndex: Integer;
  Valid: Boolean;
begin
  FEdit.ListBox.AllowMouseExecute := False;
  if FEdit.ListBox.ItemIndex <> -1 then
    SelText := FEdit.ListBox.Items[FEdit.ListBox.ItemIndex];

  List := TStringList.Create;
  try
    FCompObjects.Clear;
    FPalette := GetComponentPalette;
    if FPalette <> nil then
    begin
      Categories := GetPaletteCategories(FPalette);
      for PalIndex := 0 to Categories.Count - 1 do
      begin
        PalGroup := Categories.Items[PalIndex];
        PalGroupItems := PalGroup.Items;
        PaletteName := PalGroup.Caption;
        for i := 0 to PalGroupItems.Count - 1 do
        begin
          PalItem := PalGroupItems[i];
          CompName := PalItem.Caption;
          if Filter(CompName) then
          begin
            Holder := TPaletteItemHolder.Create(PalItem);
            FCompObjects.Add(Holder);
            List.AddObject(CompName, TCompItem.Create(0, PaletteName, CompName, nil, Holder));
          end;
        end;
      end;
    end;
    if FEdit.CheckBoxPaletteSort.Checked then
      TStringList(List).CustomSort(PaletteSortCompare)
    else
      TStringList(List).Sort;

    if List.Count = 1 then
      FEdit.PanelBottom.Caption := '1 component  '
    else
      FEdit.PanelBottom.Caption := Format('%d components  ', [List.Count]);

    // transfer list to ListBox
    FEdit.ListBox.Items.BeginUpdate;
    try
      FEdit.ListBox.ClearList;
      FEdit.ListBox.Items.Assign(List);

      if SelText <> '' then
        FEdit.ListBox.ItemIndex := List.IndexOf(SelText);
      if (FEdit.ListBox.ItemIndex = -1) and (List.Count > 0) then
      begin
        { Is the SelText already in the list }
        Valid := False;
        for i := 0 to List.Count - 1 do
        begin
          if Pos(AnsiLowerCase(SelText), AnsiLowerCase(List[i])) <> 0 then
          begin
            Valid := True;
            Break;
          end;
        end;
        if not Valid then
          SelText := '';

        { Select the best fitting item }
        MinLenDiffIndex := 0;
        if FEdit.Text <> '' then
        begin
          EditTextLen := Length(FEdit.Text);
          // Pick the entry whose length is closest to the typed text. The
          // difference must be absolute, otherwise an entry shorter than the
          // text always wins regardless of how poorly it matches.
          MinLenDiff := Abs(Length(List[0]) - EditTextLen);
          for i := 1 to List.Count - 1 do
          begin
            Len := Abs(Length(List[i]) - EditTextLen);
            if Len < MinLenDiff then
            begin
              MinLenDiff := Len;
              MinLenDiffIndex := i;
            end;
          end;
        end;
        FEdit.ListBox.ItemIndex := MinLenDiffIndex;
      end;
    finally
      FEdit.UpdateDropDownBounds;
      FEdit.ListBox.Items.EndUpdate;
    end;
  finally
    List.Free;
  end;
end;

procedure TComponentSelector.EditChange(Sender: TObject);
begin
  FTimerFilterUpdate.Enabled := False;
  FTimerFilterUpdate.Enabled := True;
end;

procedure TComponentSelector.EditKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    if FEdit.ListBox.ItemIndex <> -1 then
      ClickItem(FEdit.ListBox, True)
    else
      TimerFilterUpdateTimer(FTimerFilterUpdate);
  end;
end;

procedure TComponentSelector.TimerFilterUpdateTimer(Sender: TObject);
begin
  FTimerFilterUpdate.Enabled := False;
  UpdateComponentList;
end;

function TComponentSelector.Filter(const AClassName: string): Boolean;
begin
  if FEdit.CheckBoxSimpleSearch.Checked and (FEdit.Text <> '') then
  begin
    Result := AnsiLowerCase(Copy(AClassName, 1, Length(FEdit.Text))) = AnsiLowerCase(FEdit.Text); // AnsiStartsText
    if not Result and (UpCase(FEdit.Text[1]) <> 'T') then // try it with a leading "T"
      Result := AnsiLowerCase(Copy(AClassName, 1, 1 + Length(FEdit.Text))) = 't' + AnsiLowerCase(FEdit.Text); // AnsiStartsText
  end
  else
    Result := (FEdit.Text = '') or (Pos(AnsiLowerCase(FEdit.Text), AnsiLowerCase(AClassName)) <> 0);
end;

procedure TComponentSelector.DrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  Item: TCompItem;
  TextOffset: Integer;
  //PaintIcon: INTAPalettePaintIcon;
  r: TColorRef;
  LUnitName: string;
begin
  with TListBox(Control) do
  begin
    Item := TCompItem(Items.Objects[Index]);
    if not (odSelected in State) then
    begin
      if Index mod 2 = 0 then
      begin
        r := ColorToRGB(Color);
        Canvas.Brush.Color := RGB(GetRValue(r) + 10, GetGValue(r) + 10, GetBValue(r) + 10);
      end
      else
        Canvas.Brush.Color := Color;
    end;
    Canvas.FillRect(Rect);

    // draw palette name text
    Canvas.Brush.Style := bsClear;
    LUnitName := '';
    {if Assigned(Item.FComponentClass) and (Item.FComponentClass.ClassInfo <> nil) then
      LUnitName := ', ' + GetTypeData(Item.FComponentClass.ClassInfo).LUnitName + '.pas';}
    Canvas.Font.Name := 'Arial';
    Canvas.Font.Size := 7;
    Canvas.Font.Color := clGrayText;
    Canvas.TextRect(Rect, Rect.Right - Canvas.TextWidth(Item.Palette + LUnitName), Rect.Top + 1 + Canvas.TextHeight('Ag') + 1, Item.Palette + LUnitName);

    TextOffset := 24;
    if (Item.Data <> nil) and Assigned(FPalette) and Assigned(FPalette.OnDrawIcon) then
    begin
      TextOffset := 0;
      {if Supports(TPaletteItemHolder(Item.Data).Item, INTAPalettePaintIcon, PaintIcon) then
        PaintIcon.Paint(Canvas, Rect.Left, Rect.Top, pi16x16);
      Inc(TextOffset, 16);}
      FPalette.OnDrawIcon(FPalette, TButtonItem(TPaletteItemHolder(Item.Data).Item), Canvas, Rect, [], TextOffset);
      Inc(TextOffset, 2);
    end;

    // draw component name text
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Assign(Font);
    if odSelected in State then
      Canvas.Font.Color := clHighlightText;
    Canvas.TextRect(Rect, Rect.Left + TextOffset + 3, Rect.Top + (ItemHeight - Canvas.TextHeight('Ag')) div 2, Item.CompName);

    if FEdit.CheckBoxPaletteSort.Checked then
    begin
      if (Index + 1 < Items.Count) and (AnsiCompareText(TCompItem(Items.Objects[Index + 1]).Palette, Item.Palette) <> 0) then
      begin
        Canvas.Pen.Color := clBlack;
        Canvas.MoveTo(Rect.Left, Rect.Bottom - 1);
        Canvas.LineTo(Rect.Right, Rect.Bottom - 1);
      end;
    end;
  end;
end;

procedure TComponentSelector.ClickItem(Sender: TObject);
begin
  ClickItem(Sender, False);
end;

procedure TComponentSelector.ClickItem(Sender: TObject; ExecuteItem: Boolean);
var
  Item: TCompItem;
begin
  with TListBox(Sender) do
  begin
    if ItemIndex <> -1 then
    begin
      Item := TCompItem(Items.Objects[ItemIndex]);
      if (Item <> nil) and (Item.Data <> nil) then
        SelectComponentPalette(TPaletteItemHolder(Item.Data).Item, ExecuteItem);
    end;
  end;
end;

procedure TComponentSelector.BeforeDropDown(Sender: TObject);
begin
  if (Application <> nil) and not Application.Terminated then
  begin
    UpdateComponentList;
  end;
end;

procedure TComponentSelector.LoadToolbarConfig;
var
  Reg: TRegistry;
  ToolbarInfo: TToolbarInfo;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;

    {if Reg.OpenKeyReadOnly('\Software\DelphiTools\DelphiSpeedUp\' + DelphiVersion) then
    begin
      if Reg.ValueExists('ComponentSelector') and (Reg.GetDataSize('ComponentSelector') = SizeOf(TToolbarInfo)) then
      begin
        Reg.ReadBinaryData('ComponentSelector', ToolbarInfo, SizeOf(TToolbarInfo));
        FToolBar.Left := ToolbarInfo.Left;
        FToolBar.Top := ToolbarInfo.Top;
        FToolBar.Visible := ToolbarInfo.Visible;
      end;
    end;}

    // A locked/corrupt HKCU subtree must not propagate ERegistryException; the
    // settings simply fall back to their defaults.
    try
      if Reg.OpenKeyReadOnly('\Software\DelphiTools\DDevExtensions\' + DelphiVersion + '\ComponentSelector') then
      begin
        if Reg.ValueExists('Toolbar') and (Reg.GetDataSize('Toolbar') = SizeOf(TToolbarInfo)) then
        begin
          Reg.ReadBinaryData('Toolbar', ToolbarInfo, SizeOf(TToolbarInfo));
          FToolBar.Left := ToolbarInfo.Left;
          FToolBar.Top := ToolbarInfo.Top;
          FToolBar.Visible := ToolbarInfo.Visible;
        end;
        if Reg.ValueExists('SimpleSearch') then
          FEdit.CheckBoxSimpleSearch.Checked := Reg.ReadInteger('SimpleSearch') <> 0;
        if Reg.ValueExists('SortByPalette') then
          FEdit.CheckBoxPaletteSort.Checked := Reg.ReadInteger('SortByPalette') <> 0;
        if Reg.ValueExists('Hotkey') then
          SetHotkey( Reg.ReadInteger('Hotkey') );
      end;
    except
      on E: Exception do
        OutputDebugString( PChar( 'ComponentSelector.LoadToolbarConfig failed: ' + E.ClassName + ': ' + E.Message ) );
    end;
  finally
    Reg.Free;
  end;
end;

procedure TComponentSelector.SaveToolbarConfig;
var
  Reg: TRegistry;
  ToolbarInfo: TToolbarInfo;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    // SaveToolbarConfig also runs from Destroy: a registry failure must never
    // re-raise out of the destructor, so swallow and log.
    try
      if Reg.OpenKey('\Software\DelphiTools\DDevExtensions\' + DelphiVersion + '\ComponentSelector', True) then
      begin
        ToolbarInfo.Left := FToolBar.Left;
        ToolbarInfo.Top := FToolBar.Top;
        ToolbarInfo.Visible := FToolBar.Visible;
        Reg.WriteBinaryData('Toolbar', ToolbarInfo, SizeOf(TToolbarInfo));

        Reg.WriteBool('SimpleSearch', FEdit.CheckBoxSimpleSearch.Checked);
        Reg.WriteBool('SortByPalette', FEdit.CheckBoxPaletteSort.Checked);
        Reg.WriteInteger('Hotkey', GetHotkey);
      end;
    except
      on E: Exception do
        OutputDebugString( PChar( 'ComponentSelector.SaveToolbarConfig failed: ' + E.ClassName + ': ' + E.Message ) );
    end;
    {if Reg.OpenKey('\Software\DelphiTools\DelphiSpeedUp\' + DelphiVersion, False) then
    begin
      // clean up old DelphiSpeedup integration
      if Reg.ValueExists('ComponentSelector') then
        Reg.DeleteValue('ComponentSelector');
    end;}
  finally
    Reg.Free;
  end;
end;

procedure TComponentSelector.OptionsChanged(Sender: TObject);
begin
  SaveToolbarConfig;
  UpdateComponentList;
end;

function TComponentSelector.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('Component Selector', TFrameOptionPageComponentSelector, Self);
end;

procedure TComponentSelector.SetHotkey(const Value: TShortCut);
begin
  FHotkeyAction.ShortCut := Value;
end;

procedure TComponentSelector.ExecuteHotkeyAction(Sender: TObject);
begin
  // The toolbar/edit are only created when a ControlBar was found at construction;
  // guard so a fired hotkey cannot dereference them when they were never built.
  if (FToolBar = nil) or (FEdit = nil) then
    Exit;

  if FToolBar.Visible and not (FEdit.Focused or FEdit.ListVisible) then
  begin
    FEdit.SetFocus;
    FEdit.DropDown;
  end;
end;

function TComponentSelector.GetHotkey: TShortCut;
begin
  Result := FHotkeyAction.ShortCut;
end;

{ TDropDownEdit }

constructor TDropDownEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FPanelBottom := TPanel.Create(Self);
  FPanelBottom.ParentBackground := False;
  FPanelBottom.Height := 18 * 2;
  FPanelBottom.Alignment := taRightJustify;
  FPanelBottom.Align := alBottom;
  FPanelBottom.Parent := Panel;
  FPanelBottom.ParentColor := True;

  FCheckBoxSimpleSearch := TCheckBox.Create(Self);
  FCheckBoxSimpleSearch.Left := 2;
  FCheckBoxSimpleSearch.Top := 1;
  FCheckBoxSimpleSearch.Caption := 'Simple search';
  FCheckBoxSimpleSearch.OnClick := DoOptionChangeClick;
  FCheckBoxSimpleSearch.Parent := FPanelBottom;
  FCheckBoxSimpleSearch.Width := 100;

  FCheckBoxPaletteSort := TCheckBox.Create(Self);
  FCheckBoxPaletteSort.Left := 2;
  FCheckBoxPaletteSort.Top := FCheckBoxPaletteSort.BoundsRect.Bottom + 1;
  FCheckBoxPaletteSort.Caption := 'Sort by palette';
  FCheckBoxPaletteSort.OnClick := DoOptionChangeClick;
  FCheckBoxPaletteSort.Parent := FPanelBottom;
  FCheckBoxPaletteSort.Width := 120;
end;

procedure TDropDownEdit.UpdateDropDownBounds;
var
  Pt, HPt: TPoint;
  h: Integer;
  HM: HMONITOR;
  MonitorInfo: TMonitorInfo;
begin
  Pt := ClientToScreen(Point(Width, Height));
  Pt.X := Pt.X - Panel.Width;
  if Pt.X < Screen.DesktopLeft then
    Pt.X := Screen.DesktopLeft;

  HM := MonitorFromWindow(Handle, MONITOR_DEFAULTTONEAREST);
  MonitorInfo.cbSize := SizeOf(MonitorInfo);
  if (HM <> 0) and GetMonitorInfo(HM, @MonitorInfo) then
    h := MonitorInfo.rcWork.Bottom
  else
    h := Screen.Height;

  HPt := ClientToScreen(Point(0, Height + 2));
  HPt.Y := Min(h - (HPt.Y + PanelBottom.Height), 2 + ListBox.Items.Count * ListBox.ItemHeight + 2 + PanelBottom.Height);
  SetWindowPos(Panel.Handle, HWND_TOPMOST, Pt.X, Pt.Y, Panel.Width, HPt.Y, SWP_NOACTIVATE);
end;

procedure TDropDownEdit.WMPaint(var Msg: TWMPaint);
var
  ps: TPaintStruct;
  dc: HDC;
  hFnt: HFONT;
  bmp, orgBmp: HBITMAP;
  w, h: Integer;
  DibSect: TDIBSection;
  S: string;
  R: TRect;
begin
  if not Focused then
  begin
    bmp := LoadBitmap(GetModuleHandle(delphicoreide_bpl), 'DEFAULT');
    if bmp <> 0 then
    begin
      GetObject(bmp, SizeOf(DibSect), @DibSect);
      w := DibSect.dsBm.bmWidth;
      h := DibSect.dsBm.bmHeight;

      Msg.DC := BeginPaint(Handle, ps);
      dc := CreateCompatibleDC(Msg.DC);
      try
        orgBmp := SelectObject(dc, bmp);
        FillRect(Msg.DC, Rect(0, 0, w, h), Brush.Handle);

        StretchBltTransparent(Msg.DC, 0, -2, w, h,
                              dc, 0, 0, w, h, SRCCOPY, GetPixel(dc, 0, h - 1));
        SelectObject(dc, orgBmp);
      finally
        DeleteObject(bmp);
        DeleteDC(dc);
      end;
      S := sSearchComponent;
      R := ClientRect;
      Inc(R.Left, w);
      Inc(R.Top, 2);
      hFnt := SelectObject(Msg.DC, Font.Handle);
      SetBkMode(Msg.DC, TRANSPARENT);
      DrawText(Msg.DC, PChar(S), Length(S), R, DT_LEFT or DT_TOP or DT_NOPREFIX);
      SetBkMode(Msg.DC, OPAQUE);
      SelectObject(Msg.DC, hFnt);
      EndPaint(Handle, ps);
      Exit;
    end;
  end;
  inherited;
end;

procedure TDropDownEdit.DoOptionChangeClick(Sender: TObject);
begin
  LooseFocus(Sender);
  if Assigned(FOnOptionsChanged) then
    FOnOptionsChanged(Self);
end;

procedure TDropDownEdit.LooseFocus(Sender: TObject);
begin
  if ListVisible then
    Winapi.Windows.SetFocus(Panel.Handle);
end;

end.
