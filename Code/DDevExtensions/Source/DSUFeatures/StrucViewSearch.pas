unit StrucViewSearch;

/// <summary>
/// Adds an incremental search/filter combo box to the IDE's Structure View. Typing in the
/// combo narrows a drop-down list of matching nodes; selecting an entry navigates the
/// underlying VirtualStringTree to that node and, for source code, opens it in the editor.
/// </summary>

interface

uses
  Windows, SysUtils, Classes, Contnrs, Controls, Forms, StdCtrls, ExtCtrls, ImgList,
  Graphics, ActnList, Math,
  EditPopupCtrl, VirtTreeHandler, ToolsAPI, StructureViewAPI;

type
  /// <summary>
  /// Lightweight item describing one match in the search drop-down: the displayed caption,
  /// the position of the matched filter substring, the underlying structure node and its
  /// path within the tree.
  /// </summary>
  TNodeItem = class(TObject)
  public
    /// <summary>Visible caption for the item (without parent path).</summary>
    Caption: string;
    /// <summary>1-based position of the filter text inside Caption, or -1 if no filter is active.</summary>
    FoundPos: Integer;
    /// <summary>Underlying IDE structure node for navigation.</summary>
    Node: IOTAStructureNode;
    /// <summary>Parent-chain text shown in grey after the caption.</summary>
    Path: string;

    /// <summary>Creates a node item with the given caption, match offset, structure node and path.</summary>
    /// <param name="ACaption">Caption text to display.</param>
    /// <param name="AFoundPos">1-based position of the filter substring or -1.</param>
    /// <param name="ANode">Structure node referenced by the item.</param>
    /// <param name="APath">Parent-chain path string.</param>
    constructor Create(const ACaption: string; AFoundPos: Integer; const ANode: IOTAStructureNode;
      const APath: string);
  end;

  /// <summary>
  /// Owner of the search combo and the IDE-wide hot-key action that focuses it. Manages
  /// the filter timer, drop-down population, owner-draw rendering and node navigation.
  /// </summary>
  TStructureViewSearch = class(TComponent)
  private
    /// <summary>Search combo placed above the Structure View tree.</summary>
    FEdit: TDropDownEditSearchBase;
    /// <summary>Debounce timer that delays UpdateList until typing pauses.</summary>
    FFilterTimer: TTimer;
    /// <summary>Wrapper around the Structure View's VirtualStringTree.</summary>
    FTree: TIDEVirtualTreeHandler;
    /// <summary>Owns the TNodeItem objects shown in the drop-down list.</summary>
    FItems: TObjectList;
    /// <summary>Length of the current filter text, used by the owner-draw routine.</summary>
    FFilterLen: Integer;
    /// <summary>Action registered with the IDE that fires SetEditFocus on the configured hot-key.</summary>
    FHotkeyAction: TAction;
    /// <summary>Owner-draw handler that renders a list item with bolded match, icon and grey path.</summary>
    /// <param name="Control">The list box being drawn.</param>
    /// <param name="Index">Index of the item.</param>
    /// <param name="R">Rectangle in which to paint.</param>
    /// <param name="State">Drawing state flags.</param>
    procedure DrawItem(Control: TWinControl; Index: Integer; R: TRect; State: TOwnerDrawState);
  protected
    /// <summary>Creates and configures the search combo box and docks it to the parent form.</summary>
    /// <param name="AParent">Parent control (typically the Structure View form).</param>
    procedure CreateComboBox(AParent: TWinControl);
    /// <summary>Filter timer tick; calls UpdateList once typing has paused.</summary>
    procedure TimerFilterTimer(Sender: TObject);
    /// <summary>Restarts the debounce timer when the search text changes.</summary>
    procedure EditChange(Sender: TObject);
    /// <summary>Treats Enter as either "click selected item" or "force filter refresh".</summary>
    /// <param name="Sender">The combo edit raising the event.</param>
    /// <param name="Key">Character pressed; set to #0 to swallow.</param>
    procedure EditKeyPress(Sender: TObject; var Key: Char);
    /// <summary>List mouse-up handler that activates the item under the cursor.</summary>
    procedure ListMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    /// <summary>Navigates the Structure View tree to the selected drop-down item and opens its source.</summary>
    procedure ClickItem(Sender: TObject);
    /// <summary>Refreshes the drop-down list before it opens, provided the application is still running.</summary>
    procedure BeforeDropDown(Sender: TObject);
    /// <summary>Rebuilds FItems and the list box contents from the current Structure View context using the active filter.</summary>
    procedure UpdateList;
    /// <summary>Brings the Structure View to the foreground and focuses the search edit.</summary>
    procedure SetEditFocus(Sender: TObject);
  public
    /// <summary>Creates the component, locates the Structure View, builds the search UI and attaches the timer.</summary>
    /// <param name="AOwner">Owning component (may be nil).</param>
    constructor Create(AOwner: TComponent); override;
    /// <summary>Removes the hot-key action and frees owned resources.</summary>
    destructor Destroy; override;
    /// <summary>Installs or replaces the IDE hot-key that focuses the search edit.</summary>
    /// <param name="AHotkey">New shortcut, or 0 to remove the binding.</param>
    procedure SetHotkey(AHotkey: TShortCut);
  end;

/// <summary>
/// Creates or destroys the singleton structure-view search component.
/// </summary>
/// <param name="Unload">True to shut down, False to start up.</param>
procedure InitPlugin(Unload: Boolean);

var
  /// <summary>Singleton instance referenced by other plugin units.</summary>
  StructureViewSearch: TStructureViewSearch;

implementation

uses
  IDEUtils, FrmeOptionPageDSUFeatures;

type
  PStructureData = ^TStructureData;
  TStructureData = record
    Node: IOTAStructureNode;
  end;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    StructureViewSearch := TStructureViewSearch.Create(nil)
  else
    FreeAndNil(StructureViewSearch);
end;

{ TNodeItem }

constructor TNodeItem.Create(const ACaption: string; AFoundPos: Integer;
  const ANode: IOTAStructureNode; const APath: string);
begin
  inherited Create;
  Caption := ACaption;
  FoundPos := AFoundPos;
  Node := ANode;
  Path := APath;
end;

{ TStructureViewSearch }

constructor TStructureViewSearch.Create(AOwner: TComponent);
var
  Form: TCustomForm;
  LTree: TComponent;
begin
  inherited Create(AOwner);
  FItems := TObjectList.Create;

  Form := FindForm('StructureViewForm', '');
  if Form <> nil then
  begin
    LTree := Form.FindComponent('VirtualStringTree1');
    if LTree <> nil then
    begin
      CreateComboBox(Form);
      FTree := TIDEVirtualTreeHandler.Create(LTree as TCustomControl);
    end;
  end;

  FFilterTimer := TTimer.Create(Self);
  FFilterTimer.Interval := 170;
  FFilterTimer.OnTimer := TimerFilterTimer;

  if FEdit <> nil then
  begin
    Form := FindForm('ToolForm', 'TToolForm');
    if Form <> nil then
    begin
      FEdit.Images := TCustomImageList(Form.FindComponent('imgListToolbar'));
      FEdit.ImageIndex := 5;
    end;
  end;

  { The configuration is in another plugin }
  if DSUFeaturesConfig <> nil then
    SetHotkey(DSUFeaturesConfig.StructureViewSearchHotKey);

  FFilterTimer.Enabled := False; // ignore all previously generated changes
end;

destructor TStructureViewSearch.Destroy;
begin
  SetHotkey(0);
  FItems.Free;
  inherited Destroy;
end;

procedure TStructureViewSearch.CreateComboBox(AParent: TWinControl);
begin
  FEdit := TDropDownEditSearchBase.Create(Self);
  FEdit.ListAlignment := taLeftJustify;
  FEdit.Name := 'DDevExtensions_SearchComboBox';
  FEdit.Text := '';
  FEdit.Align := alTop;
  FEdit.Parent := AParent;
  FEdit.ListBox.Style := lbOwnerDrawFixed;
  FEdit.ListBox.ItemHeight := 18;
  FEdit.ListBox.OnDrawItem := DrawItem;
  FEdit.DropDownHeight := FEdit.ListBox.ItemHeight * 32;
  FEdit.DropDownWidth := 400;
  FEdit.Panel.BorderStyle := bsNone;
  FEdit.Panel.Color := FEdit.Color;
  FEdit.OnChange := EditChange;
  FEdit.OnKeyPress := EditKeyPress;
  FEdit.OnBeforeDropDown := BeforeDropDown;
  FEdit.ListBox.OnMouseUp := ListMouseUp;
end;

procedure TStructureViewSearch.DrawItem(Control: TWinControl; Index: Integer; R: TRect;
  State: TOwnerDrawState);
var
  Item: TNodeItem;
  TextOffset: Integer;
  C: TColorRef;
  Images: TCustomImageList;
  S: string;
  W: Integer;
  Lbx: TListBox;
  Canvas: TCanvas;
begin
  Lbx := TListBox(Control);
  Canvas := Lbx.Canvas;
  { Normal/Alternate color rows }
  Item := TNodeItem(Lbx.Items.Objects[Index]);
  if not (odSelected in State) then
  begin
    if Index mod 2 = 0 then
    begin
      C := ColorToRGB(Lbx.Color);
      Canvas.Brush.Color := RGB(GetRValue(C) - 10, GetGValue(C) - 10, GetBValue(C) - 10);
    end
    else
      Canvas.Brush.Color := Lbx.Color;
  end;
  Canvas.FillRect(R);

  TextOffset := 0;
  if Item.Node.ImageIndex <> -1 then
  begin
    Images := FTree.Images;
    if Images <> nil then
    begin
      Images.Draw(Canvas, R.Left + TextOffset + 1, R.Top + (R.Bottom - R.Top - Images.Height) div 2, Item.Node.ImageIndex);
      Inc(TextOffset, Images.Width + 1);
    end;
  end;

  // draw caption (part 1)
  if Item.FoundPos <> -1 then
    S := Copy(Item.Caption, 1, Item.FoundPos - 1)
  else
    S := Item.Caption;

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Assign(Lbx.Font);
  if odSelected in State then
    Canvas.Font.Color := clHighlightText;
  Canvas.TextRect(R, R.Left + TextOffset + 3, R.Top + (Lbx.ItemHeight - Canvas.TextHeight('Ag')) div 2, S);
  Inc(TextOffset, Canvas.TextWidth(S));

  if Item.FoundPos <> -1 then
  begin
    // draw filter text (part 2)
    S := Copy(Item.Caption, Item.FoundPos, FFilterLen);
    if S <> '' then
    begin
      Canvas.Font.Style := [fsBold];
      Canvas.TextRect(R, R.Left + TextOffset + 3, R.Top + (Lbx.ItemHeight - Canvas.TextHeight('Ag')) div 2, S);
      Inc(TextOffset, Canvas.TextWidth(S));
    end;

    // draw caption (part 3)
    S := Copy(Item.Caption, Item.FoundPos + FFilterLen, MaxInt);
    if S <> '' then
    begin
      Canvas.Font.Assign(Lbx.Font);
      if odSelected in State then
        Canvas.Font.Color := clHighlightText;
      Canvas.TextRect(R, R.Left + TextOffset + 3, R.Top + (Lbx.ItemHeight - Canvas.TextHeight('Ag')) div 2, S);
      Inc(TextOffset, Canvas.TextWidth(S));
    end;
  end;

  { Draw "Path" text }
  if Item.Path <> '' then
  begin
    Inc(TextOffset, 10);
    S := '(' + Item.Path + ')';

    Canvas.Font.Name := 'Arial';
    Canvas.Font.Size := 7;
    Canvas.Font.Style := [];
    if odSelected in State then
      Canvas.Font.Color := clHighlightText
    else
      Canvas.Font.Color := clGrayText;

    W := Canvas.TextWidth(S) + 4;
    if FEdit.ListBox.ScrollWidth < TextOffset + W + 2 then
    begin
      FEdit.ListBox.ScrollWidth := TextOffset + W + 2;
      FEdit.ListBox.Invalidate;
    end;

    if TextOffset + W <= FEdit.ListBox.ClientWidth then
      TextOffset := FEdit.ListBox.ClientWidth - W
    else
      TextOffset := FEdit.ListBox.ScrollWidth - W;

    Canvas.TextRect(R, R.Left + TextOffset, R.Top + (Lbx.ItemHeight - Canvas.TextHeight('Ag')) div 2, S);
  end;
end;

procedure TStructureViewSearch.EditChange(Sender: TObject);
begin
  FFilterTimer.Enabled := False;
  FFilterTimer.Enabled := True;
end;

procedure TStructureViewSearch.EditKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    if FEdit.ListBox.ItemIndex <> -1 then
      ClickItem(FEdit.ListBox)
    else
      TimerFilterTimer(FFilterTimer);
  end;
end;

procedure TStructureViewSearch.ListMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  if FEdit.ListBox.ItemAtPos(Point(X, Y), False) <> -1 then
  begin
    ClickItem(Sender);
  end;
end;

procedure TStructureViewSearch.SetEditFocus(Sender: TObject);
var
  Form: TCustomForm;
begin
  Form := FindForm('StructureViewForm', '');
  if Form <> nil then
  begin
    if not IsWindowVisible(Form.Handle) then
    begin
      if not (Form.FindComponent('ViewStructureCmd') as TAction).Execute then
        Exit;
    end;
    if FEdit.CanFocus then
      FEdit.SetFocus;
  end;
end;

procedure TStructureViewSearch.SetHotkey(AHotkey: TShortCut);
begin
  if AHotkey = 0 then
    FreeAndNil(FHotkeyAction)
  else
  begin
    if FHotkeyAction = nil then
    begin
      FHotkeyAction := TAction.Create(nil);
      FHotkeyAction.OnExecute := SetEditFocus;
      FHotkeyAction.ActionList := (BorlandIDEServices as INTAServices).ActionList;
    end;
    FHotkeyAction.ShortCut := AHotkey;
  end;
end;

procedure TStructureViewSearch.ClickItem(Sender: TObject);
var
  Item: TNodeItem;
  Node: PVirtualNode;
  Data: PStructureData;
begin
  if TListBox(Sender).ItemIndex <> -1 then
  begin
    Item := TNodeItem(TListBox(Sender).Items.Objects[TListBox(Sender).ItemIndex]);
    FEdit.SelectAll;

    Node := FTree.GetFirst;
    while Node <> nil do
    begin
      Data := FTree.GetNodeData(Node);
      if Data.Node = Item.Node then
        Break;
      Node := FTree.GetNext(Node);
    end;

    if Node <> nil then
    begin
      FTree.ClearSelection;
      FTree.ScrollIntoView(Node, True, False);
      FTree.Selected[Node] := True;
      FTree.FocusedNode := Node;
      try
        FTree.Tree.SetFocus;
      except
        on EInvalidOperation do ;
      end;
      if (BorlandIDEServices as IOTAStructureView).GetStructureContext.StructureType = SourceCodeStructureType then
        FTree.DblClick;
    end;
  end;
end;

procedure TStructureViewSearch.TimerFilterTimer(Sender: TObject);
begin
  FFilterTimer.Enabled := False;
  UpdateList;
end;

procedure TStructureViewSearch.BeforeDropDown(Sender: TObject);
begin
  if (Application <> nil) and not Application.Terminated then
    UpdateList;
end;

procedure TStructureViewSearch.UpdateList;
var
  Filter: string;
  StructureView: IOTAStructureView;
  I: Integer;
  MinLenDiff: Integer;
  MinLenDiffIndex: Integer;

  procedure CollectNodes(Node: IOTAStructureNode; const NamePath: string; Level: Integer; Designer: Boolean);
  var
    S, Caption, FilterStr: string;
    I: Integer;
    Item: TNodeItem;
    LenDiff: Integer;
    CompName: string;
  begin
    if Node.Name <> ErrorsNodeType then
    begin
      if Level > 0 then
      begin
        Caption := Node.Caption;
        I := Pos('(', Caption);
        if I > 0 then
          Caption := TrimRight(Copy(Caption, 1, I - 1));

        { Child NamePath }
        S := Caption;
        if NamePath <> '' then
          S := S + ' - ' + NamePath;

        if Designer or (Node.ChildCount = 0) then
        begin
          CompName := Node.Name;
          if not Designer or
             ((Pos('.', CompName) = 0) and (Pos('<', CompName) = 0) and (Pos('{', CompName) = 0)) then
          begin
            if Designer then
              Caption := CompName;
            I := -1;
            if Filter <> '' then
            begin
              FilterStr := AnsiLowerCase(Caption);
              if not Designer then
              begin
                I := Pos(':', FilterStr);
                if I > 0 then
                  FilterStr := TrimRight(Copy(FilterStr, 1, I - 1));
              end;
              I := Pos(Filter, AnsiLowerCase(Caption));
              if I <> 0 then
              begin
                LenDiff := Length(FilterStr) - Length(Filter);
                if LenDiff < MinLenDiff then
                begin
                  MinLenDiff := LenDiff;
                  MinLenDiffIndex := FItems.Count;
                end;
              end;
            end;

            if I <> 0 then
            begin
              Item := TNodeItem.Create(Caption, I, Node, NamePath);
              FItems.Add(Item);
              FEdit.ListBox.Items.AddObject(S, Item);
            end;
          end;
        end;
      end
      else
      begin
        { Child NamePath }
        S := '';
      end;

      { Filter children }
      Inc(Level);
      for I := 0 to Node.ChildCount - 1 do
        CollectNodes(Node.Child[I], S, Level, Designer);
    end;
  end;

var
  Context: IOTAStructureContext;
  Count: Integer;
begin
  Filter := AnsiLowerCase(Trim(FEdit.Text));
  FFilterLen := Length(Filter);
  FEdit.ListBox.Items.BeginUpdate;
  try
    MinLenDiff := MaxInt;
    MinLenDiffIndex := 0;
    FItems.Clear;
    FEdit.ListBox.Items.Clear;
    FEdit.ListBox.ScrollWidth := 0;
    if Supports(BorlandIDEServices, IOTAStructureView, StructureView) then
    begin
      Context := StructureView.GetStructureContext;
      if Context <> nil then
        for I := 0 to Context.RootNodeCount - 1 do
          CollectNodes(Context.GetRootStructureNode(I), '', 0, StructureView.GetStructureType = DesignerStructureType);
    end;
    Count := FEdit.ListBox.Items.Count;
    if Count > 32 then
      Count := 32;
    FEdit.DropDownHeight := FEdit.ListBox.ItemHeight * Max(2, Count) + 4;
  finally
    FEdit.ListBox.Items.EndUpdate;
  end;
  FEdit.ListBox.ItemIndex := MinLenDiffIndex;
end;

end.

