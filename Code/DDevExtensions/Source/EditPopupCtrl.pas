unit EditPopupCtrl;

/// <summary>
/// Drop-down edit primitives used by DDevExtensions search/selector UIs:
/// a borderless popup panel, a borderless list box embedded in it, and a
/// <c>TEdit</c> descendant that displays the panel just below the edit.
/// </summary>
/// <remarks>
/// The popup uses <c>WS_POPUP</c>/<c>HWND_TOPMOST</c> so it floats over IDE
/// tool windows without stealing focus from the underlying edit.
/// </remarks>

interface

uses
  Windows, Messages, SysUtils, Classes, Contnrs, Graphics, Controls, Forms,
  StdCtrls, ExtCtrls, ComCtrls, ToolsAPI, ActnList, MultiMon, Menus, ImgList;

const
  /// <summary>Custom message posted to a <see cref="TDropDownEditBase"/> to open its drop-down.</summary>
  WM_DROPDOWN = WM_USER + 101;

type
  TDropDownEditBase = class;

  /// <summary>Borderless top-most panel that hosts the popup list box.</summary>
  TPopupPanel = class(TPanel)
  private
    /// <summary>Owning edit control whose drop-down this panel implements.</summary>
    FEdit: TDropDownEditBase;
    /// <summary>Suppresses focus activation when the user clicks the panel.</summary>
    procedure WMMouseActivate(var Message: TMessage); message WM_MOUSEACTIVATE;
    /// <summary>Closes the drop-down when the panel is deactivated.</summary>
    procedure WMActivate(var Msg: TWMActivate); message WM_ACTIVATE;
  protected
    /// <summary>Adds <c>WS_POPUP</c>/<c>WS_EX_TOOLWINDOW</c> style flags so the panel floats and saves bits.</summary>
    procedure CreateParams(var Params: TCreateParams); override;
    /// <summary>Closes the drop-down on a left-mouse-up.</summary>
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    /// <summary>Marks the panel <c>csNoDesignVisible</c>/<c>csReplicatable</c>.</summary>
    constructor Create(AOwner: TComponent); override;
    /// <summary>The owning drop-down edit.</summary>
    property Edit: TDropDownEditBase read FEdit write FEdit;
  end;

  /// <summary>Borderless list box rendered inside <see cref="TPopupPanel"/>.</summary>
  TPopupListBox = class(TListBox)
  private
    /// <summary>Owning edit control.</summary>
    FEdit: TDropDownEditBase;
    /// <summary>If True, a mouse click in the list executes the selected item rather than just selecting it.</summary>
    FAllowMouseExecute: Boolean;
    /// <summary>Suppresses focus activation when the user clicks the list.</summary>
    procedure WMMouseActivate(var Message: TMessage); message WM_MOUSEACTIVATE;
    /// <summary>Closes the drop-down when the list loses activation.</summary>
    procedure WMActivate(var Msg: TWMActivate); message WM_ACTIVATE;
  protected
    /// <summary>Closes the drop-down on a left-mouse-up.</summary>
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    /// <summary>Releases the control without re-creating the window handle.</summary>
    destructor Destroy; override;
    /// <summary>Clears the list contents.</summary>
    procedure ClearList;
    /// <summary>The owning drop-down edit.</summary>
    property Edit: TDropDownEditBase read FEdit write FEdit;
    /// <summary>Controls whether a mouse click executes the highlighted item.</summary>
    property AllowMouseExecute: Boolean read FAllowMouseExecute write FAllowMouseExecute;
  end;

  /// <summary>
  /// Base class for edit controls with a custom popup list. Manages the
  /// <see cref="TPopupPanel"/>/<see cref="TPopupListBox"/> lifecycle, drop-down
  /// positioning, focus juggling and key/mouse forwarding to the list.
  /// </summary>
  TDropDownEditBase = class(TEdit)
  private
    /// <summary>List box rendered inside <see cref="FPanel"/>.</summary>
    FListBox: TPopupListBox;
    /// <summary>Floating popup panel that hosts the list box.</summary>
    FPanel: TPopupPanel;
    /// <summary>True while the drop-down is showing.</summary>
    FListVisible: Boolean;
    /// <summary>Fired immediately before the drop-down is shown so the host can populate the list.</summary>
    FOnBeforeDropDown: TNotifyEvent;
    /// <summary>Alignment used to position the panel relative to the edit (left- or right-justify).</summary>
    FListAlignment: TAlignment;
    /// <summary>If True, the drop-down may be shown even when the list has no items.</summary>
    FAllowEmptyList: Boolean;
    /// <summary>Closes the drop-down when the IDE broadcasts a cancel-mode targeted outside the popup.</summary>
    procedure CMCancelMode(var Msg: TCMCancelMode); message CM_CANCELMODE;
    /// <summary>Repaints when the edit gains focus.</summary>
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    /// <summary>Closes the drop-down when focus moves outside the popup.</summary>
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    /// <summary>Handles <see cref="WM_DROPDOWN"/> by opening the popup if the edit is focused.</summary>
    procedure WMDropDown(var Msg: TMessage); message WM_DROPDOWN;
    /// <summary>Paints the edit background (Delphi 2009+ no longer does this implicitly).</summary>
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    /// <summary>Returns the current drop-down panel height.</summary>
    function GetDropDownHeight: Integer;
    /// <summary>Returns the current drop-down panel width.</summary>
    function GetDropDownWidth: Integer;
    /// <summary>Sets the drop-down height and re-positions if visible.</summary>
    procedure SetDropDownHeight(const Value: Integer);
    /// <summary>Sets the drop-down width and re-positions if visible.</summary>
    procedure SetDropDownWidth(const Value: Integer);
  protected
    /// <summary>Routes navigation/character keys to the list box and opens the drop-down on first key.</summary>
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    /// <summary>Selects all text when the edit gains keyboard focus.</summary>
    procedure DoEnter; override;
    /// <summary>Posts a <see cref="WM_DROPDOWN"/> when the user clicks the edit while the popup is hidden.</summary>
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    /// <summary>Suppresses the Beep when the user presses Esc.</summary>
    procedure KeyPress(var Key: Char); override;
  public
    /// <summary>Creates the popup panel/list-box pair and applies default styles.</summary>
    constructor Create(AOwner: TComponent); override;
    /// <summary>Hides the drop-down (no-op if already hidden).</summary>
    procedure CloseUp;
    /// <summary>Displays the drop-down (raises <see cref="OnBeforeDropDown"/> first).</summary>
    procedure DropDown;
    /// <summary>Width of the drop-down panel in pixels.</summary>
    property DropDownWidth: Integer read GetDropDownWidth write SetDropDownWidth;
    /// <summary>Height of the drop-down panel in pixels.</summary>
    property DropDownHeight: Integer read GetDropDownHeight write SetDropDownHeight;
    /// <summary>Embedded list box; populate this in <see cref="OnBeforeDropDown"/>.</summary>
    property ListBox: TPopupListBox read FListBox;
    /// <summary>Hosting popup panel.</summary>
    property Panel: TPopupPanel read FPanel;
    /// <summary>True while the drop-down is shown.</summary>
    property ListVisible: Boolean read FListVisible;
    /// <summary>Alignment used when positioning the popup (left or right-justified to the edit).</summary>
    property ListAlignment: TAlignment read FListAlignment write FListAlignment;

    /// <summary>Recomputes the popup panel's screen position and size.</summary>
    procedure UpdateDropDownBounds; virtual;

    /// <summary>Fired immediately before the drop-down is shown so the host can populate the list.</summary>
    property OnBeforeDropDown: TNotifyEvent read FOnBeforeDropDown write FOnBeforeDropDown;
  end;

  /// <summary>
  /// Drop-down edit variant that paints a small image (typically a magnifying
  /// glass) inside the left margin of the edit control.
  /// </summary>
  TDropDownEditSearchBase = class(TDropDownEditBase)
  private
    /// <summary>Source image list for the in-edit glyph.</summary>
    FImages: TCustomImageList;
    /// <summary>Index in <see cref="FImages"/> of the glyph to draw.</summary>
    FImageIndex: Integer;
    /// <summary>Sets <see cref="FImages"/> with appropriate free-notification wiring.</summary>
    procedure SetImages(const Value: TCustomImageList);
    /// <summary>Updates the edit's left margin to make space for the glyph; returns True if a margin change was applied.</summary>
    function UpdateEditMargins: Boolean; reintroduce;
  protected
    /// <summary>Draws the glyph after the standard edit paints itself.</summary>
    procedure WMPaint(var Msg: TWMPaint); message WM_PAINT;
    /// <summary>Detaches the image list when it is being destroyed.</summary>
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    /// <summary>Applies edit margins after the window is created.</summary>
    procedure CreateWnd; override;
    /// <summary>Handles theme/colour control messages and updates margins on resize.</summary>
    procedure WndProc(var Msg: TMessage); override;
  public
    /// <summary>Detaches the image list and releases the control.</summary>
    destructor Destroy; override;
    /// <summary>Image list providing the in-edit glyph.</summary>
    property Images: TCustomImageList read FImages write SetImages;
    /// <summary>Index of the glyph in <see cref="Images"/>.</summary>
    property ImageIndex: Integer read FImageIndex write FImageIndex;
  end;

implementation

uses
  CommCtrl, Themes;

{ TPopupPanel }

constructor TPopupPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csNoDesignVisible, csReplicatable];
end;

procedure TPopupPanel.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  with Params do
  begin
    Style := Style or WS_POPUP or WS_BORDER or WS_CLIPCHILDREN;
    ExStyle := WS_EX_TOOLWINDOW;
    WindowClass.Style := WindowClass.Style or CS_SAVEBITS;
  end;
end;

procedure TPopupPanel.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button = mbLeft then
    FEdit.CloseUp;
end;

procedure TPopupPanel.WMActivate(var Msg: TWMActivate);
begin
  if Msg.Active = WA_INACTIVE then
    FEdit.CloseUp;
end;

procedure TPopupPanel.WMMouseActivate(var Message: TMessage);
begin
//  Message.Result := MA_NOACTIVATEANDEAT;
  Message.Result := MA_NOACTIVATE;
end;

{ TPopupListBox }

destructor TPopupListBox.Destroy;
begin
  // ClearList; can't be called here because the hWnd is already destroyed and accessing Items[] recreates the control => exception
  inherited Destroy;
end;

procedure TPopupListBox.ClearList;
begin
  Items.Clear;
end;

procedure TPopupListBox.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button = mbLeft then
    FEdit.CloseUp;
end;

procedure TPopupListBox.WMActivate(var Msg: TWMActivate);
begin
  if Msg.Active = WA_INACTIVE then
    FEdit.CloseUp;
end;

procedure TPopupListBox.WMMouseActivate(var Message: TMessage);
begin
//  Message.Result := MA_NOACTIVATEANDEAT;
  Message.Result := MA_NOACTIVATE;
end;

{ TDropDownEditBase }

constructor TDropDownEditBase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csCaptureMouse];
  FListAlignment := taRightJustify;
  FAllowEmptyList := True;

  FPanel := TPopupPanel.Create(Self);
  FPanel.ParentBackground := False;
  FPanel.Color := clBtnFace;
  FPanel.Visible := False;
  FPanel.Edit := Self;
  FPanel.Parent := Self;

  FListBox := TPopupListBox.Create(Self);
  FListBox.Edit := Self;
  FListBox.BorderStyle := bsNone;
  FListBox.Align := alClient;
  FListBox.Parent := FPanel;
  Text := '';
end;

procedure TDropDownEditBase.CMCancelMode(var Msg: TCMCancelMode);
begin
  if (Msg.Sender <> Self) and (Msg.Sender <> FPanel) and (Msg.Sender <> FListBox) and
     (Panel <> nil) and not Panel.ContainsControl(Msg.Sender) then
    CloseUp;
end;

procedure TDropDownEditBase.CloseUp;
begin
  if FListVisible then
  begin
    if (GetCapture <> 0) then
      SendMessage(GetCapture, WM_CANCELMODE, 0, 0);

    SetWindowPos(FPanel.Handle, 0, 0, 0, 0, 0, SWP_NOZORDER or
      SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_HIDEWINDOW);
    FListVisible := False;
    FPanel.Visible := False;
    //SetFocus; steals the focus from the code editor and hides the caret of the edit control
  end;
end;

procedure TDropDownEditBase.UpdateDropDownBounds;
var
  Pt: TPoint;
begin
  if ListAlignment = taRightJustify then
  begin
    Pt := ClientToScreen(Point(Width, Height));
    Pt.X := Pt.X - FPanel.Width;
    if Pt.X < Screen.DesktopLeft then
      Pt.X := Screen.DesktopLeft;
  end
  else
  begin
    Pt := ClientToScreen(Point(0, Height));
  end;

  SetWindowPos(Panel.Handle, HWND_TOPMOST, Pt.X, Pt.Y, Panel.Width + 2, Panel.Height + 2, SWP_NOACTIVATE);
end;

procedure TDropDownEditBase.DropDown;
begin
  if not FListVisible then
  begin
    if Assigned(FOnBeforeDropDown) then
      FOnBeforeDropDown(Self);
    {if (FListBox.Items.Count = 0) then  This doesn't work because the listbox will popup and close all the time
      Exit; // nothing to show}
    UpdateDropDownBounds;

    FListVisible := True;
    SetWindowPos(FPanel.Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_SHOWWINDOW or SWP_NOACTIVATE or SWP_NOMOVE or SWP_NOSIZE);
    FPanel.Visible := True;
  end;
end;

procedure TDropDownEditBase.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) or ((Key = VK_RETURN) and (ListBox.ItemIndex <> -1))then
  begin
    CloseUp;
    Key := 0;
  end
  else
  begin
    case Key of
      VK_SHIFT, VK_CONTROL, VK_MENU, VK_TAB, VK_PRINT: ;
    else
      DropDown;
    end;
  end;
  inherited KeyDown(Key, Shift);
  if not (((Key = VK_F4) and (ssAlt in Shift)) or
    (Key in [VK_DELETE, VK_LEFT, VK_RIGHT]) or
    ((Key in [VK_HOME, VK_END]) and not (ssCtrl in Shift)) or
    ((Key in [VK_INSERT]) and ((ssShift in Shift) or (ssCtrl in Shift)))) then
  begin
    SendMessage(FListBox.Handle, WM_KEYDOWN, Key, 0);
    Key := 0;
  end;
end;

procedure TDropDownEditBase.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
  PostMessage(Handle, EM_SETSEL, 0, -1);
end;

procedure TDropDownEditBase.WMKillFocus(var Message: TWMKillFocus);
begin
  if FListVisible and not FPanel.ContainsControl(FindControl(Message.FocusedWnd)) then
    CloseUp;
  inherited;
  Invalidate;
end;

procedure TDropDownEditBase.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if not FListVisible then
    PostMessage(Handle, WM_DROPDOWN, 0, 0);
end;

function TDropDownEditBase.GetDropDownHeight: Integer;
begin
  Result := FPanel.Height;
end;

function TDropDownEditBase.GetDropDownWidth: Integer;
begin
  Result := FPanel.Width;
end;

procedure TDropDownEditBase.SetDropDownHeight(const Value: Integer);
begin
  FPanel.Height := Value;
  if ListVisible then
    UpdateDropDownBounds;
end;

procedure TDropDownEditBase.SetDropDownWidth(const Value: Integer);
begin
  FPanel.Width := Value;
  if ListVisible then
    UpdateDropDownBounds;
end;

procedure TDropDownEditBase.KeyPress(var Key: Char);
begin
  inherited;
  if Key = #27 then
    Key := #0;
end;

procedure TDropDownEditBase.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  { Delphi 2009 doesn't paint the background anymore }
  FillRect(Message.DC, ClientRect, Brush.Handle);
  Message.Result := 1;
end;

procedure TDropDownEditBase.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  Invalidate;
end;

procedure TDropDownEditBase.WMDropDown(var Msg: TMessage);
begin
  if Focused and not FListVisible then
    DropDown;
  Invalidate;
end;

{ TDropDownEditSearchBase }

procedure TDropDownEditSearchBase.CreateWnd;
begin
  inherited CreateWnd;
  UpdateEditMargins;
end;

destructor TDropDownEditSearchBase.Destroy;
begin
  SetImages(nil);
  inherited Destroy;
end;

procedure TDropDownEditSearchBase.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FImages) then
    SetImages(nil);
end;

procedure TDropDownEditSearchBase.SetImages(const Value: TCustomImageList);
begin
  if Value <> FImages then
  begin
    if FImages <> nil then
      FImages.RemoveFreeNotification(Self);
    FImages := Value;
    if FImages <> nil then
      FImages.FreeNotification(Self);
  end;
end;

function TDropDownEditSearchBase.UpdateEditMargins: Boolean;
var
  Margins: Integer;
  LeftMargin: Integer;
begin
  Result := False;
  if HandleAllocated then
  begin
    LeftMargin := 0;
    if Images <> nil then
      LeftMargin := Images.Width + 2;

    Margins := SendMessage(Handle, EM_GETMARGINS, 0, 0);
    if (Margins and $FFFF) <> LeftMargin then
    begin
      SendMessage(Handle, EM_SETMARGINS, EC_LEFTMARGIN, MakeLong(LeftMargin, 0));
      Invalidate;
      Result := True;
    end;
  end;
end;

procedure TDropDownEditSearchBase.WMPaint(var Msg: TWMPaint);
var
  MyDC: Boolean;
  ps: TPaintStruct;
{  hFnt: HFONT;
  S: string;
  R: TRect;}
begin
  if Images <> nil then
  begin
    if UpdateEditMargins then
      Exit; // Invalidate() was triggered

    MyDC := Msg.DC = 0;
    if MyDC then
      Msg.DC := BeginPaint(Handle, ps);

    inherited;

    FillRect(Msg.DC, Rect(0, 0, Images.Width, Images.Height), Brush.Handle);
    if ImageIndex <> -1 then
      ImageList_Draw(Images.Handle, ImageIndex, Msg.DC, 0, 0, ILS_NORMAL);

{      if Text = '' then
    begin
      S := sSearchComponent;
      R := ClientRect;
      Inc(R.Left, Images.Width);
      Inc(R.Top, 2);
      hFnt := SelectObject(Msg.DC, Font.Handle);
      SetBkMode(Msg.DC, TRANSPARENT);
      DrawText(Msg.DC, PChar(S), Length(S), R, DT_LEFT or DT_TOP or DT_NOPREFIX);
      SetBkMode(Msg.DC, OPAQUE);
      SelectObject(Msg.DC, hFnt);
    end;}

    if MyDC then
      EndPaint(Handle, ps);
  end
  else
    inherited;
end;

procedure TDropDownEditSearchBase.WndProc(var Msg: TMessage);
var
  LLeft, LTop: Integer;
begin
  case Msg.Msg of
    CN_CTLCOLORSTATIC,
    CN_CTLCOLOREDIT:
      begin
        if Images <> nil then
        begin
          LLeft := 0;
          LTop := 0;
          {$IF CompilerVersion >= 23.0}
          if StyleServices.Enabled and Ctl3D then
          {$ELSE}
          if ThemeServices.ThemesEnabled and Ctl3D then
          {$IFEND}
          begin
            Inc(LLeft);
            Inc(LTop);
          end;
          ExcludeClipRect(Msg.WParam, LLeft + 1, LTop + 1, Images.Width, Images.Height);
        end;
      end;
  end;

  inherited;

  case Msg.Msg of
    WM_SIZE, WM_SETFONT, WM_FONTCHANGE, WM_WINDOWPOSCHANGED,
    CM_FONTCHANGED, CM_BORDERCHANGED, CM_CTL3DCHANGED:
      if not (csLoading in ComponentState) then
        UpdateEditMargins;
  end;
end;

end.

