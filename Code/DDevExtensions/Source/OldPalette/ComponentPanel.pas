{-----------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/MPL-1.1.html

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either expressed or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: JvComponentPanel.PAS, released on 2002-07-04.

The Initial Developers of the Original Code are: Andrei Prygounkov <a dott prygounkov att gmx dott de>
Copyright (c) 1999, 2002 Andrei Prygounkov
All Rights Reserved.

Contributor(s):
  Andreas Hausladen

You may retrieve the latest version of this file at the Project JEDI's JVCL home page,
located at http://jvcl.delphi-jedi.org

components : TJvComponentPanel
description: Component panel for GUI developers

Known Issues:
-----------------------------------------------------------------------------}
// $Id: JvComponentPanel.pas 12461 2009-08-14 17:21:33Z obones $

unit ComponentPanel;

/// <summary>
/// Provides the visual building blocks for the legacy ("Old Palette") component panel:
/// a borderless speed button, a button glyph helper that supports disabled state and
/// transparency, and the scrollable component panel itself with left/right navigators.
/// Adapted from JEDI VCL's TJvComponentPanel.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.Classes, Vcl.Controls, Vcl.Buttons, Vcl.Forms, Vcl.ExtCtrls, Vcl.Graphics;

type
  /// <summary>Click handler invoked with the index of the panel button that was activated.</summary>
  TButtonClick = procedure(Sender: TObject; Button: Integer) of object;

  /// <summary>
  /// Speed button extension that allows the caller to override the hint window class
  /// used when the IDE's tooltip pops up.
  /// </summary>
  TJvExSpeedButton = class(TSpeedButton)
  private
    /// <summary>Hint window class used by this button's tooltips.</summary>
    FHintWindowClass: THintWindowClass;
    /// <summary>Inserts <see cref="FHintWindowClass"/> into the hint info before display.</summary>
    procedure CMHintShow(var Msg: TCMHintShow); message CM_HINTSHOW;
  public
    /// <summary>Hint window class used when the button shows a tooltip.</summary>
    property HintWindowClass: THintWindowClass read FHintWindowClass write FHintWindowClass;
  end;


  /// <summary>
  /// Helper that draws a button glyph with proper handling of up/down/disabled/exclusive
  /// states, transparent backgrounds and BiDi text. Used by <see cref="TJvNoFrameButton"/>
  /// to render its bitmap without forcing the glyph to live on the button itself.
  /// </summary>
  { VCL Buttons unit does not publish TJvButtonGlyph class,
    so we do it for other programers (Delphi 3 version) }
  TJvButtonGlyph = class(TObject)
  private
    /// <summary>Cached image list holding the rendered per-state glyphs.</summary>
    FGlyphList: TImageList;
    /// <summary>Per-state index into <see cref="FGlyphList"/>.</summary>
    FIndexs: array [TButtonState] of Integer;
    /// <summary>Colour treated as transparent in the source bitmap.</summary>
    FTransparentColor: TColor;
    /// <summary>Number of glyph frames in the source bitmap.</summary>
    FNumGlyphs: TNumGlyphs;
    /// <summary>Fired whenever the rendered glyph changes.</summary>
    FOnChange: TNotifyEvent;
    /// <summary>Background colour used during disabled-state rendering.</summary>
    FColor: TColor;
    /// <summary>Bidirectional text mode used when drawing captions.</summary>
    FBiDiMode: TBiDiMode; {o}
    /// <summary>True when the button inherits its BiDi mode from its parent.</summary>
    FParentBiDiMode: Boolean;
    /// <summary>Setter that invalidates cached glyphs when BiDi mode changes.</summary>
    procedure SetBiDiMode(Value: TBiDiMode);
    /// <summary>Setter that invalidates cached glyphs when the parent BiDi flag changes.</summary>
    procedure SetParentBiDiMode(Value: Boolean);
    /// <summary>Notification handler called when the source glyph bitmap changes.</summary>
    procedure GlyphChanged(Sender: TObject);
    /// <summary>Setter that copies the new bitmap and infers the glyph count.</summary>
    procedure SetGlyph(Value: TBitmap);
    /// <summary>Setter that updates the number of frames and invalidates caches.</summary>
    procedure SetNumGlyphs(Value: TNumGlyphs);
    /// <summary>Setter that updates the background colour used for disabled rendering.</summary>
    procedure SetColor(Value: TColor);
    /// <summary>Discards cached per-state bitmaps so they will be re-created on demand.</summary>
    procedure Invalidate;
    /// <summary>Builds and caches the glyph for the requested state and returns its index.</summary>
    function CreateButtonGlyph(State: TButtonState): Integer;
    /// <summary>Paints the cached glyph for <paramref name="State"/> at <paramref name="GlyphPos"/>.</summary>
    procedure DrawButtonGlyph(Canvas: TCanvas; const GlyphPos: TPoint;
      State: TButtonState; Transparent: Boolean);
    /// <summary>Draws the caption text into <paramref name="TextBounds"/> respecting BiDi and disabled state.</summary>
    procedure DrawButtonText(Canvas: TCanvas; const Caption: string;
      TextBounds: TRect; State: TButtonState); virtual;
    /// <summary>Calculates glyph and text positions for the supplied client rect, layout and margins.</summary>
    procedure CalcButtonLayout(Canvas: TCanvas; const Client: TRect;
      const Offset: TPoint; const Caption: string; Layout: TButtonLayout;
      Margin, Spacing: Integer; var GlyphPos: TPoint; var TextBounds: TRect);
  protected
    /// <summary>Original (uncached) glyph bitmap supplied by the caller.</summary>
    FOriginal: TBitmap;
    /// <summary>Calculates the bounding rectangle required to render <paramref name="Caption"/>.</summary>
    procedure CalcTextRect(Canvas: TCanvas; var TextRect: TRect; const Caption: string); virtual;
  public
    /// <summary>Creates the helper and registers it with the shared glyph cache.</summary>
    constructor Create;
    /// <summary>Releases the original bitmap and removes the helper from the glyph cache.</summary>
    destructor Destroy; override;
    /// <summary>Renders glyph and caption for the supplied state and returns the text rectangle used.</summary>
    /// <returns>The bounding rectangle of the rendered text.</returns>
    { return the text rectangle }
    function Draw(Canvas: TCanvas; const Client: TRect; const Offset: TPoint;
      const Caption: string; Layout: TButtonLayout; Margin, Spacing: Integer;
      State: TButtonState; Transparent: Boolean): TRect;
    /// <summary>Draws an externally supplied bitmap rather than the held glyph.</summary>
    /// <param name="AGlyph">Bitmap to render.</param>
    /// <param name="ANumGlyphs">Number of frames in the bitmap.</param>
    /// <param name="AColor">Background colour for disabled rendering.</param>
    /// <param name="IgnoreOld">Skip restoring the original glyph for performance.</param>
    /// <returns>The bounding rectangle of the rendered text.</returns>
    { DrawExternal draws any glyph (not glyph property) -
      if you don't needed to save previous glyph set IgnoreOld to True -
      this increases performance }
    function DrawExternal(AGlyph: TBitmap; ANumGlyphs: TNumGlyphs; AColor: TColor; IgnoreOld: Boolean;
      Canvas: TCanvas; const Client: TRect; const Offset: TPoint; const Caption: string;
      Layout: TButtonLayout; Margin, Spacing: Integer; State: TButtonState; Transparent: Boolean): TRect;
    /// <summary>Bidirectional text mode used when drawing captions.</summary>
    property BiDiMode: TBiDiMode read FBiDiMode write SetBiDiMode;
    /// <summary>True when BiDi mode is inherited from the parent control.</summary>
    property ParentBiDiMode: Boolean read FParentBiDiMode write SetParentBiDiMode;
    /// <summary>Source glyph bitmap.</summary>
    property Glyph: TBitmap read FOriginal write SetGlyph;
    /// <summary>Number of frames in the glyph bitmap (1, 2 or 4).</summary>
    property NumGlyphs: TNumGlyphs read FNumGlyphs write SetNumGlyphs;
    /// <summary>Background colour used during disabled-state rendering.</summary>
    property Color: TColor read FColor write SetColor;
    /// <summary>Fired whenever the rendered glyph changes.</summary>
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  /// <summary>Custom button paint event with the live state passed to the handler.</summary>
  TPaintButtonEvent = procedure(Sender: TObject; IsDown, IsDefault: Boolean; State: TButtonState) of object;

  /// <summary>
  /// Borderless speed button with optional repeated click behaviour, used by the
  /// component panel for the left/right scroll arrows.
  /// </summary>
  TJvNoFrameButton = class(TJvExSpeedButton)
  private
    /// <summary>Glyph helper used to paint the button's bitmap.</summary>
    FGlyphDrawer: TJvButtonGlyph;
    /// <summary>True when the button paints without an outer border.</summary>
    FNoBorder: Boolean;
    /// <summary>Optional custom paint handler.</summary>
    FOnPaint: TPaintButtonEvent;
    /// <summary>True when the button auto-repeats while held down.</summary>
    FRepeatedClick: Boolean;
    /// <summary>Timer used to drive auto-repeat.</summary>
    FRepeatTimer: TTimer;
    /// <summary>Initial delay (ms) before the first auto-repeat fires.</summary>
    FInitRepeatPause: Integer;
    /// <summary>Delay (ms) between subsequent auto-repeats.</summary>
    FRepeatPause: Integer;
    /// <summary>True after the auto-repeat has produced at least one click.</summary>
    FClicked: Boolean;
    /// <summary>Setter for <see cref="NoBorder"/> that triggers a repaint.</summary>
    procedure SetNoBorder(Value: Boolean);
    /// <summary>Timer tick handler implementing auto-repeat.</summary>
    procedure TimerExpired(Sender: TObject);
  protected
    /// <summary>Custom paint method delegating to <see cref="DefaultDrawing"/>.</summary>
    procedure Paint; override;
    /// <summary>Starts the auto-repeat timer when armed.</summary>
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer); override;
    /// <summary>Stops auto-repeat and ensures the synthetic click does not double-fire.</summary>
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X: Integer; Y: Integer); override;
  public
    /// <summary>Creates the button with default repeat timings.</summary>
    /// <param name="AOwner">Owner component.</param>
    constructor Create(AOwner: TComponent); override;
    /// <summary>Releases the repeat timer and glyph drawer.</summary>
    destructor Destroy; override;
    /// <summary>Default paint routine used when no <see cref="OnPaint"/> handler is set.</summary>
    procedure DefaultDrawing(const IsDown: Boolean; const State: TButtonState);
    /// <summary>Exposes the inherited canvas for custom painting.</summary>
    property Canvas;
  published
    /// <summary>Background colour, exposed from the ancestor.</summary>
    property Color;
    /// <summary>Inherits its background colour from the parent, exposed from the ancestor.</summary>
    property ParentColor;
    /// <summary>True to render the button without an outer border.</summary>
    property NoBorder: Boolean read FNoBorder write SetNoBorder default True;
    /// <summary>True to enable auto-repeat while the mouse is held down.</summary>
    property RepeatedClick: Boolean read FRepeatedClick write FRepeatedClick default False;
    /// <summary>Initial delay (ms) before auto-repeat begins.</summary>
    property InitRepeatPause: Integer read FInitRepeatPause write FInitRepeatPause default 400;
    /// <summary>Delay (ms) between auto-repeated clicks.</summary>
    property RepeatPause: Integer read FRepeatPause write FRepeatPause default 100;
    /// <summary>Optional custom paint handler.</summary>
    property OnPaint: TPaintButtonEvent read FOnPaint write FOnPaint;
  end;

  /// <summary>Event fired so callers can paint custom content into a panel rectangle.</summary>
  TJvPaintPanelContentEvent = procedure(Sender: TObject; Canvas: TCanvas; R: TRect) of object;

  /// <summary>
  /// Scrollable panel that hosts a series of speed buttons representing components.
  /// Provides a fixed pointer button on the left, scroll arrows that page the visible
  /// buttons, mouse-wheel paging and selection-state management.
  /// </summary>
  TJvComponentPanel = class(TCustomPanel)
  private
    /// <summary>Width of each component button in pixels.</summary>
    FButtonWidth: Integer;
    /// <summary>Height of each component button in pixels.</summary>
    FButtonHeight: Integer;
    /// <summary>List of component buttons displayed in the panel.</summary>
    FButtons: TList;
    /// <summary>Click event raised when a button is clicked.</summary>
    FOnClick: TButtonClick;
    /// <summary>Double-click event raised when a button is double-clicked.</summary>
    FOnDblClick: TButtonClick;
    /// <summary>Fixed left-most "pointer" button used to deselect the palette.</summary>
    FButtonPointer: TJvExSpeedButton;
    /// <summary>Left-pointing scroll arrow.</summary>
    FButtonLeft: TJvNoFrameButton;
    /// <summary>Right-pointing scroll arrow.</summary>
    FButtonRight: TJvNoFrameButton;
    /// <summary>Index of the first currently visible button.</summary>
    FFirstVisible: Integer;
    /// <summary>Update lock counter for batched layout changes.</summary>
    FLockUpdate: Integer;
    /// <summary>Currently selected button.</summary>
    FSelectButton: TJvExSpeedButton;
    /// <summary>Hint window class propagated to child buttons.</summary>
    FHintWindowClass: THintWindowClass;
    /// <summary>Optional callback invoked to paint the panel's content area.</summary>
    FOnPaintContent: TJvPaintPanelContentEvent;
    /// <summary>Returns the button at <paramref name="Index"/> or nil when out of range.</summary>
    function GetButton(Index: Integer): TJvExSpeedButton;
    /// <summary>Returns the number of buttons in the panel.</summary>
    function GetButtonCount: Integer;
    /// <summary>Setter that grows or shrinks the button list to the requested count.</summary>
    procedure SetButtonCount(AButtonCount: Integer);
    /// <summary>Setter that resizes all buttons horizontally.</summary>
    procedure SetButtonWidth(AButtonWidth: Integer);
    /// <summary>Setter that resizes all buttons vertically.</summary>
    procedure SetButtonHeight(AButtonHeight: Integer);
    /// <summary>Setter for <see cref="FirstVisible"/> with bounds checking.</summary>
    procedure SetFirstVisible(AButton: Integer);
    /// <summary>Internal click dispatcher that raises <see cref="OnClick"/> with the button index.</summary>
    procedure BtnClick(Sender: TObject);
    /// <summary>Internal double-click dispatcher that raises <see cref="OnDblClick"/>.</summary>
    procedure BtnDblClick(Sender: TObject);
    /// <summary>Click handler for the left/right scroll arrows.</summary>
    procedure MoveClick(Sender: TObject);
    /// <summary>Returns the maximum number of buttons currently fitting in the visible area.</summary>
    function GetVisibleCount: Integer;
    /// <summary>Setter that selects the button at <paramref name="Value"/>.</summary>
    procedure SetSelectedButton(Value: Integer);
    /// <summary>Returns the index of the currently selected button, or -1.</summary>
    function GetSelectedButton: Integer;
    /// <summary>Suppresses Caption changes; the panel renders no caption.</summary>
    procedure WMSetText(var Msg: TWMSetText); message WM_SETTEXT;
    /// <summary>Forwards the panel's hint window class to the displayed tooltip.</summary>
    procedure CMHintShow(var Msg: TCMHintShow); message CM_HINTSHOW;
  protected
    /// <summary>Repositions all child buttons to honour the current sizes and scroll position.</summary>
    procedure Resize; override;
    /// <summary>Translates mouse wheel events into left/right scrolling.</summary>
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    /// <summary>Paints the panel background and delegates content drawing to <see cref="PaintContent"/>.</summary>
    procedure Paint; override;
    /// <summary>Calls <see cref="OnPaintContent"/> if assigned to allow custom content drawing.</summary>
    procedure PaintContent(const R: TRect);
  public
    /// <summary>Creates the panel and its fixed pointer/arrow buttons.</summary>
    /// <param name="AOwner">Owner component.</param>
    constructor Create(AOwner: TComponent); override;
    /// <summary>Releases all owned buttons and the internal list.</summary>
    destructor Destroy; override;
    /// <summary>Recreates every component button after resetting state.</summary>
    procedure RecreateButtons;
    /// <summary>Selects the fixed pointer button.</summary>
    procedure SetMainButton;
    /// <summary>Custom Invalidate that respects the update lock counter.</summary>
    procedure Invalidate; override;
    /// <summary>Begins a batch of layout changes; pair with <see cref="EndUpdate"/>.</summary>
    procedure BeginUpdate;
    /// <summary>Ends a batch begun by <see cref="BeginUpdate"/> and triggers re-layout.</summary>
    procedure EndUpdate;
    /// <summary>Default indexed access to the component buttons.</summary>
    property Buttons[Index: Integer]: TJvExSpeedButton read GetButton; default;
    /// <summary>Index of the first button currently visible in the scrolling area.</summary>
    property FirstVisible: Integer read FFirstVisible write SetFirstVisible;
    /// <summary>Read-only access to the left scroll arrow.</summary>
    property ButtonLeft: TJvNoFrameButton read FButtonLeft;
    /// <summary>Read-only access to the right scroll arrow.</summary>
    property ButtonRight: TJvNoFrameButton read FButtonRight;
    /// <summary>Number of buttons currently visible in the scrolling area.</summary>
    property VisibleCount: Integer read GetVisibleCount;
    /// <summary>Index of the currently selected button, or -1 when only the pointer is selected.</summary>
    property SelectedButton: Integer read GetSelectedButton write SetSelectedButton;
    /// <summary>Hint window class propagated to child buttons' tooltips.</summary>
    property HintWindowClass: THintWindowClass read FHintWindowClass write FHintWindowClass;
  published
    /// <summary>Alignment within the parent control.</summary>
    property Align;
    /// <summary>Fired when one of the component buttons is clicked.</summary>
    property OnClick: TButtonClick read FOnClick write FOnClick;
    /// <summary>Fired when one of the component buttons is double-clicked.</summary>
    property OnDblClick: TButtonClick read FOnDblClick write FOnDblClick;
    /// <summary>Width of every component button in pixels.</summary>
    property ButtonWidth: Integer read FButtonWidth write SetButtonWidth default 28;
    /// <summary>Height of every component button in pixels.</summary>
    property ButtonHeight: Integer read FButtonHeight write SetButtonHeight default 28;
    /// <summary>Number of component buttons displayed in the panel.</summary>
    property ButtonCount: Integer read GetButtonCount write SetButtonCount default 0;
    /// <summary>Anchors, exposed from the ancestor.</summary>
    property Anchors;
    /// <summary>Size constraints, exposed from the ancestor.</summary>
    property Constraints;
    /// <summary>AutoSize behaviour, exposed from the ancestor.</summary>
    property AutoSize;
    /// <summary>Bidirectional mode, exposed from the ancestor.</summary>
    property BiDiMode;
    /// <summary>Whether the panel acts as its own dock manager, exposed from the ancestor.</summary>
    property UseDockManager default True;
    /// <summary>DockSite flag, exposed from the ancestor.</summary>
    property DockSite;
    /// <summary>ParentBiDiMode, exposed from the ancestor.</summary>
    property ParentBiDiMode;
    /// <summary>DragKind, exposed from the ancestor.</summary>
    property DragKind;
    /// <summary>OnDockDrop, exposed from the ancestor.</summary>
    property OnDockDrop;
    /// <summary>OnDockOver, exposed from the ancestor.</summary>
    property OnDockOver;
    /// <summary>OnEndDock, exposed from the ancestor.</summary>
    property OnEndDock;
    /// <summary>OnGetSiteInfo, exposed from the ancestor.</summary>
    property OnGetSiteInfo;
    /// <summary>OnStartDock, exposed from the ancestor.</summary>
    property OnStartDock;
    /// <summary>OnUnDock, exposed from the ancestor.</summary>
    property OnUnDock;
    /// <summary>OnCanResize, exposed from the ancestor.</summary>
    property OnCanResize;
    /// <summary>OnConstrainedResize, exposed from the ancestor.</summary>
    property OnConstrainedResize;
    /// <summary>Optional callback invoked to paint custom content on the panel.</summary>
    property OnPaintContent: TJvPaintPanelContentEvent read FOnPaintContent write FOnPaintContent;
    /// <summary>Popup menu, exposed from the ancestor.</summary>
    property PopupMenu;
  end;

implementation

uses
  Winapi.CommCtrl, System.SysUtils;

{$R ComponentPanel.res}

const
  ROP_DSPDxax = $00E20746;

type
  TJvGlyphList = class(TImageList)
  private
    FUsed: TBits;
    FCount: Integer;
    function AllocateIndex: Integer;
  public
    constructor CreateSize(AWidth, AHeight: Integer);
    destructor Destroy; override;
    function AddMasked(Image: TBitmap; MaskColor: TColor): Integer;
    procedure Delete(Index: Integer);
    property Count: Integer read FCount;
  end;

  TJvGlyphCache = class(TObject)
  private
    FGlyphLists: TList;
  public
    constructor Create;
    destructor Destroy; override;
    function GetList(AWidth, AHeight: Integer): TJvGlyphList;
    procedure ReturnList(List: TJvGlyphList);
    function Empty: Boolean;
  end;

//=== { TJvGlyphList } =======================================================

constructor TJvGlyphList.CreateSize(AWidth, AHeight: Integer);
begin
  inherited CreateSize(AWidth, AHeight);
  FUsed := TBits.Create;
end;

destructor TJvGlyphList.Destroy;
begin
  FUsed.Free;
  inherited Destroy;
end;

function TJvGlyphList.AllocateIndex: Integer;
begin
  Result := FUsed.OpenBit;
  if Result >= FUsed.Size then
  begin
    Result := inherited Add(nil, nil);
    FUsed.Size := Result + 1;
  end;
  FUsed[Result] := True;
end;

function TJvGlyphList.AddMasked(Image: TBitmap; MaskColor: TColor): Integer;
begin
  Result := AllocateIndex;
  ReplaceMasked(Result, Image, MaskColor);
  Inc(FCount);
end;

procedure TJvGlyphList.Delete(Index: Integer);
begin
  if FUsed[Index] then
  begin
    Dec(FCount);
    FUsed[Index] := False;
  end;
end;

//=== { TJvGlyphCache } ======================================================

constructor TJvGlyphCache.Create;
begin
  inherited Create;
  FGlyphLists := TList.Create;
end;

destructor TJvGlyphCache.Destroy;
begin
  FGlyphLists.Free;
  inherited Destroy;
end;

function TJvGlyphCache.GetList(AWidth, AHeight: Integer): TJvGlyphList;
var
  I: Integer;
begin
  for I := FGlyphLists.Count - 1 downto 0 do
  begin
    Result := FGlyphLists[I];
    with Result do
      if (AWidth = Width) and (AHeight = Height) then
        Exit;
  end;
  Result := TJvGlyphList.CreateSize(AWidth, AHeight);
  FGlyphLists.Add(Result);
end;

procedure TJvGlyphCache.ReturnList(List: TJvGlyphList);
begin
  if List = nil then
    Exit;
  if List.Count = 0 then
  begin
    FGlyphLists.Remove(List);
    List.Free;
  end;
end;

function TJvGlyphCache.Empty: Boolean;
begin
  Result := FGlyphLists.Count = 0;
end;

//=== { TJvButtonGlyph } =====================================================

var
  GlyphCache: TJvGlyphCache = nil;
  Pattern: TBitmap = nil;

procedure CreateBrushPattern(FaceColor, HighLightColor: TColor);
var
  X, Y: Integer;
begin
  Pattern := TBitmap.Create;
  Pattern.Width := 8;
  Pattern.Height := 8;
  with Pattern.Canvas do
  begin
    Brush.Style := bsSolid;
    Brush.Color := FaceColor; // clBtnFace
    FillRect(Rect(0, 0, Pattern.Width, Pattern.Height));
    for Y := 0 to 7 do
      for X := 0 to 7 do
        if (Y mod 2) = (X mod 2) then { toggles between even/odd pixels }
          Pixels[X, Y] := HighLightColor; {clBtnHighlight}; { on even/odd rows }
  end;
end;

constructor TJvButtonGlyph.Create;
var
  I: TButtonState;
begin
  inherited Create;
  FOriginal := TBitmap.Create;
  FOriginal.OnChange := GlyphChanged;
  FTransparentColor := clOlive;
  FNumGlyphs := 1;
  for I := Low(I) to High(I) do
    FIndexs[I] := -1;
  if GlyphCache = nil then
    GlyphCache := TJvGlyphCache.Create;
end;

destructor TJvButtonGlyph.Destroy;
begin
  FOriginal.Free;
  Invalidate;
  if Assigned(GlyphCache) and GlyphCache.Empty then
  begin
    GlyphCache.Free;
    GlyphCache := nil;
  end;
  inherited Destroy;
end;

procedure TJvButtonGlyph.Invalidate;
var
  I: TButtonState;
begin
  for I := Low(I) to High(I) do
  begin
    if FIndexs[I] <> -1 then
      TJvGlyphList(FGlyphList).Delete(FIndexs[I]);
    FIndexs[I] := -1;
  end;
  GlyphCache.ReturnList(TJvGlyphList(FGlyphList));
  FGlyphList := nil;
end;

procedure TJvButtonGlyph.GlyphChanged(Sender: TObject);
begin
  if Sender = FOriginal then
  begin
    FTransparentColor := FOriginal.TransparentColor;
    Invalidate;
    if Assigned(FOnChange) then
      FOnChange(Self);
  end;
end;

procedure TJvButtonGlyph.SetBiDiMode(Value: TBiDiMode);
begin
  if FBiDiMode <> Value then
  begin
    FBiDiMode := Value;
    FParentBiDiMode := False;
    Invalidate;
  end;
end;

procedure TJvButtonGlyph.SetParentBiDiMode(Value: Boolean);
begin
  if FParentBiDiMode <> Value then
  begin
    FParentBiDiMode := Value;
    Invalidate;
  end;
end;

procedure TJvButtonGlyph.SetGlyph(Value: TBitmap);
var
  Glyphs: Integer;
begin
  Invalidate;
  FOriginal.Assign(Value);
  if (Value <> nil) and (Value.Height > 0) then
  begin
    FTransparentColor := Value.TransparentColor;
    if Value.Width mod Value.Height = 0 then
    begin
      Glyphs := Value.Width div Value.Height;
      if Glyphs > 4 then
        Glyphs := 1;
      SetNumGlyphs(Glyphs);
    end;
  end;
end;

procedure TJvButtonGlyph.SetNumGlyphs(Value: TNumGlyphs);
begin
  if (Value <> FNumGlyphs) and (Value > 0) then
  begin
    Invalidate;
    FNumGlyphs := Value;
    GlyphChanged(Glyph);
  end;
end;

procedure TJvButtonGlyph.SetColor(Value: TColor);
begin
  if FColor <> Value then
  begin
    FColor := Value;
    GlyphChanged(Glyph);
  end;
end;

function TJvButtonGlyph.CreateButtonGlyph(State: TButtonState): Integer;
var
  TmpImage, DDB, MonoBmp: TBitmap;
  IWidth, IHeight: Integer;
  IRect, ORect: TRect;
  I: TButtonState;
  DestDC: HDC;
begin
  if (State = bsDown) and (NumGlyphs < 3) then
    State := bsUp;
  Result := FIndexs[State];
  if Result <> -1 then
    Exit;
  if (FOriginal.Width or FOriginal.Height) = 0 then
    Exit;
  IWidth := FOriginal.Width div FNumGlyphs;
  IHeight := FOriginal.Height;
  if FGlyphList = nil then
  begin
    if GlyphCache = nil then
      GlyphCache := TJvGlyphCache.Create;
    FGlyphList := GlyphCache.GetList(IWidth, IHeight);
  end;
  TmpImage := TBitmap.Create;
  try
    TmpImage.Width := IWidth;
    TmpImage.Height := IHeight;
    IRect := Rect(0, 0, IWidth, IHeight);
    TmpImage.Canvas.Brush.Color := Color {clBtnFace};
    TmpImage.Palette := CopyPalette(FOriginal.Palette);
    I := State;
    if Ord(I) >= NumGlyphs then
      I := bsUp;
    ORect := Rect(Ord(I) * IWidth, 0, (Ord(I) + 1) * IWidth, IHeight);
    case State of
      bsUp, bsDown,
        bsExclusive:
        begin
          TmpImage.Canvas.CopyRect(IRect, FOriginal.Canvas, ORect);
          if FOriginal.TransparentMode = tmFixed then
            FIndexs[State] := TJvGlyphList(FGlyphList).AddMasked(TmpImage, FTransparentColor)
          else
            FIndexs[State] := TJvGlyphList(FGlyphList).AddMasked(TmpImage, clDefault);
        end;
      bsDisabled:
        begin
          MonoBmp := nil;
          DDB := nil;
          try
            MonoBmp := TBitmap.Create;
            DDB := TBitmap.Create;
            DDB.Assign(FOriginal);
            DDB.HandleType := bmDDB;
            if NumGlyphs > 1 then
              with TmpImage.Canvas do
              begin { Change white & gray to clBtnHighlight and clBtnShadow }
                CopyRect(IRect, DDB.Canvas, ORect);
                MonoBmp.Monochrome := True;
                MonoBmp.Width := IWidth;
                MonoBmp.Height := IHeight;

                { Convert white to clBtnHighlight }
                DDB.Canvas.Brush.Color := clWhite;
                MonoBmp.Canvas.CopyRect(IRect, DDB.Canvas, ORect);
                Brush.Color := clBtnHighlight;
                DestDC := Handle;
                SetTextColor(DestDC, clBlack);
                SetBkColor(DestDC, clWhite);
                BitBlt(DestDC, 0, 0, IWidth, IHeight,
                  MonoBmp.Canvas.Handle, 0, 0, ROP_DSPDxax);

                { Convert gray to clBtnShadow }
                DDB.Canvas.Brush.Color := clGray;
                MonoBmp.Canvas.CopyRect(IRect, DDB.Canvas, ORect);
                Brush.Color := clBtnShadow;
                DestDC := Handle;
                SetTextColor(DestDC, clBlack);
                SetBkColor(DestDC, clWhite);
                BitBlt(DestDC, 0, 0, IWidth, IHeight,
                  MonoBmp.Canvas.Handle, 0, 0, ROP_DSPDxax);

                { Convert transparent color to clBtnFace }
                DDB.Canvas.Brush.Color := ColorToRGB(FTransparentColor);
                MonoBmp.Canvas.CopyRect(IRect, DDB.Canvas, ORect);
                Brush.Color := Color {clBtnFace};
                DestDC := Handle;
                SetTextColor(DestDC, clBlack);
                SetBkColor(DestDC, clWhite);
                BitBlt(DestDC, 0, 0, IWidth, IHeight,
                  MonoBmp.Canvas.Handle, 0, 0, ROP_DSPDxax);
              end
            else
            begin
              { Create a disabled version }
              with MonoBmp do
              begin
                Assign(FOriginal);
                HandleType := bmDDB;
                Canvas.Brush.Color := clBlack;
                Width := IWidth;
                if Monochrome then
                begin
                  Canvas.Font.Color := clWhite;
                  Monochrome := False;
                  Canvas.Brush.Color := clWhite;
                end;
                Monochrome := True;
              end;
              with TmpImage.Canvas do
              begin
                Brush.Color := Color {clBtnFace};
                FillRect(IRect);
                Brush.Color := clBtnHighlight;
                SetTextColor(Handle, clBlack);
                SetBkColor(Handle, clWhite);
                BitBlt(Handle, 1, 1, IWidth, IHeight,
                  MonoBmp.Canvas.Handle, 0, 0, ROP_DSPDxax);
                Brush.Color := clBtnShadow;
                SetTextColor(Handle, clBlack);
                SetBkColor(Handle, clWhite);
                BitBlt(Handle, 0, 0, IWidth, IHeight,
                  MonoBmp.Canvas.Handle, 0, 0, ROP_DSPDxax);
              end;
            end;
          finally
            DDB.Free;
            MonoBmp.Free;
          end;
          FIndexs[State] := TJvGlyphList(FGlyphList).AddMasked(TmpImage, clDefault);
        end;
    end;
  finally
    TmpImage.Free;
  end;
  Result := FIndexs[State];
  FOriginal.Dormant;
end;

procedure TJvButtonGlyph.DrawButtonGlyph(Canvas: TCanvas; const GlyphPos: TPoint;
  State: TButtonState; Transparent: Boolean);
var
  Index: Integer;
begin
  if FOriginal = nil then
    Exit;
  if (FOriginal.Width = 0) or (FOriginal.Height = 0) then
    Exit;
  Index := CreateButtonGlyph(State);
  with GlyphPos do
    if Transparent or (State = bsExclusive) then
      ImageList_DrawEx(FGlyphList.Handle, Index, Canvas.Handle, X, Y, 0, 0,
        clNone, clNone, ILD_Transparent)
    else
      ImageList_DrawEx(FGlyphList.Handle, Index, Canvas.Handle, X, Y, 0, 0,
        ColorToRGB(Color {clBtnFace}), clNone, ILD_Normal);
end;

procedure TJvButtonGlyph.DrawButtonText(Canvas: TCanvas; const Caption: string;
  TextBounds: TRect; State: TButtonState);
var
  Flags: Longint;
begin
  Flags := 0;
  if FBiDiMode <> bdLeftToRight then
    Flags := DT_RTLREADING;
  with Canvas do
  begin
    Brush.Style := bsClear;
    if State = bsDisabled then
    begin
      OffsetRect(TextBounds, 1, 1);
      Font.Color := clBtnHighlight;
      DrawText(Canvas.Handle, PChar(Caption), Length(Caption), TextBounds, Flags);
      OffsetRect(TextBounds, -1, -1);
      Font.Color := clBtnShadow;
      DrawText(Canvas.Handle, PChar(Caption), Length(Caption), TextBounds, Flags);
    end
    else
      DrawText(Canvas.Handle, PChar(Caption), Length(Caption), TextBounds,
        DT_CENTER or DT_VCENTER or DT_SINGLELINE or Flags);
  end;
end;

procedure TJvButtonGlyph.CalcButtonLayout(Canvas: TCanvas; const Client: TRect;
  const Offset: TPoint; const Caption: string; Layout: TButtonLayout; Margin,
  Spacing: Integer; var GlyphPos: TPoint; var TextBounds: TRect);
var
  TextPos: TPoint;
  ClientSize, GlyphSize, TextSize: TPoint;
  TotalSize: TPoint;
begin
  { calculate the item sizes }
  ClientSize := Point(Client.Right - Client.Left, Client.Bottom - Client.Top);

  if FOriginal <> nil then
    GlyphSize := Point(FOriginal.Width div FNumGlyphs, FOriginal.Height)
  else
    GlyphSize := Point(0, 0);

  if Caption <> '' then
  begin
    CalcTextRect(Canvas, TextBounds, Caption);
    TextSize := Point(TextBounds.Right - TextBounds.Left, TextBounds.Bottom - TextBounds.Top);
  end
  else
  begin
    TextBounds := Rect(0, 0, 0, 0);
    TextSize := Point(0, 0);
  end;

  { If the layout has the glyph on the right or the left, then both the
    text and the glyph are centered vertically.  If the glyph is on the top
    or the bottom, then both the text and the glyph are centered horizontally.}
  if Layout in [blGlyphLeft, blGlyphRight] then
  begin
    GlyphPos.Y := (ClientSize.Y - GlyphSize.Y + 1) div 2;
    TextPos.Y := (ClientSize.Y - TextSize.Y + 1) div 2;
  end
  else
  begin
    GlyphPos.X := (ClientSize.X - GlyphSize.X + 1) div 2;
    TextPos.X := (ClientSize.X - TextSize.X + 1) div 2;
  end;

  { if there is no text or no bitmap, then Spacing is irrelevant }
  if (TextSize.X = 0) or (GlyphSize.X = 0) then
    Spacing := 0;

  { adjust Margin and Spacing }
  if Margin = -1 then
  begin
    if Spacing = -1 then
    begin
      TotalSize := Point(GlyphSize.X + TextSize.X, GlyphSize.Y + TextSize.Y);
      if Layout in [blGlyphLeft, blGlyphRight] then
        Margin := (ClientSize.X - TotalSize.X) div 3
      else
        Margin := (ClientSize.Y - TotalSize.Y) div 3;
      Spacing := Margin;
    end
    else
    begin
      TotalSize := Point(GlyphSize.X + Spacing + TextSize.X, GlyphSize.Y + Spacing + TextSize.Y);
      if Layout in [blGlyphLeft, blGlyphRight] then
        Margin := (ClientSize.X - TotalSize.X + 1) div 2
      else
        Margin := (ClientSize.Y - TotalSize.Y + 1) div 2;
    end;
  end
  else
  begin
    if Spacing = -1 then
    begin
      TotalSize := Point(ClientSize.X - (Margin + GlyphSize.X), ClientSize.Y -
        (Margin + GlyphSize.Y));
      if Layout in [blGlyphLeft, blGlyphRight] then
        Spacing := (TotalSize.X - TextSize.X) div 2
      else
        Spacing := (TotalSize.Y - TextSize.Y) div 2;
    end;
  end;

  case Layout of
    blGlyphLeft:
      begin
        GlyphPos.X := Margin;
        TextPos.X := GlyphPos.X + GlyphSize.X + Spacing;
      end;
    blGlyphRight:
      begin
        GlyphPos.X := ClientSize.X - Margin - GlyphSize.X;
        TextPos.X := GlyphPos.X - Spacing - TextSize.X;
      end;
    blGlyphTop:
      begin
        GlyphPos.Y := Margin;
        TextPos.Y := GlyphPos.Y + GlyphSize.Y + Spacing;
      end;
    blGlyphBottom:
      begin
        GlyphPos.Y := ClientSize.Y - Margin - GlyphSize.Y;
        TextPos.Y := GlyphPos.Y - Spacing - TextSize.Y;
      end;
  end;

  { fixup the result variables }
  Inc(GlyphPos.X, Client.Left + Offset.X);
  Inc(GlyphPos.Y, Client.Top + Offset.Y);
  OffsetRect(TextBounds, TextPos.X + Client.Left + Offset.X,
    TextPos.Y + Client.Top + Offset.Y);
end;

function TJvButtonGlyph.Draw(Canvas: TCanvas; const Client: TRect;
  const Offset: TPoint; const Caption: string; Layout: TButtonLayout;
  Margin, Spacing: Integer; State: TButtonState; Transparent: Boolean): TRect;
var
  GlyphPos: TPoint;
begin
  CalcButtonLayout(Canvas, Client, Offset, Caption, Layout, Margin, Spacing,
    GlyphPos, Result);
  DrawButtonGlyph(Canvas, GlyphPos, State, Transparent);
  DrawButtonText(Canvas, Caption, Result, State);
end;

function TJvButtonGlyph.DrawExternal(AGlyph: TBitmap; ANumGlyphs: TNumGlyphs; AColor: TColor; IgnoreOld: Boolean;
  Canvas: TCanvas; const Client: TRect; const Offset: TPoint; const Caption: string;
  Layout: TButtonLayout; Margin, Spacing: Integer; State: TButtonState; Transparent: Boolean): TRect;
var
  OldGlyph: TBitmap;
  OldNumGlyphs: TNumGlyphs;
  OldColor: TColor;
begin
  OldGlyph := FOriginal;
  OldNumGlyphs := NumGlyphs;
  OldColor := FColor;
  try
    FOriginal := AGlyph;
    NumGlyphs := ANumGlyphs;
    FColor := AColor;
    GlyphChanged(FOriginal);
    Result := Draw(Canvas, Client, Offset, Caption, Layout, Margin,
      Spacing, State, Transparent);
  finally
    FOriginal := OldGlyph;
    NumGlyphs := OldNumGlyphs;
    FColor := OldColor;
    if not IgnoreOld then
      GlyphChanged(FOriginal);
  end;
end;

procedure TJvButtonGlyph.CalcTextRect(Canvas: TCanvas; var TextRect: TRect; const Caption: string);
begin
  TextRect := Rect(0, 0, TextRect.Right - TextRect.Left, 0);
  DrawText(Canvas.Handle, PChar(Caption), Length(Caption), TextRect, DT_CALCRECT);
end;

{ TJvExSpeedButton }

procedure TJvExSpeedButton.CMHintShow(var Msg: TCMHintShow);
begin
  if FHintWindowClass <> nil then
    Msg.HintInfo.HintWindowClass := FHintWindowClass;
  inherited;
end;

//=== { TJvNoFrameButton } ===================================================

constructor TJvNoFrameButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGlyphDrawer := TJvButtonGlyph.Create;
  FNoBorder := True;
  FInitRepeatPause := 400;
  FRepeatPause := 100;
end;

destructor TJvNoFrameButton.Destroy;
begin
  FRepeatTimer.Free;
  FGlyphDrawer.Free;
  FGlyphDrawer := nil;
  inherited Destroy;
end;

procedure TJvNoFrameButton.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and Enabled and RepeatedClick then
  begin
    if FRepeatTimer = nil then
      FRepeatTimer := TTimer.Create(Self);
    FRepeatTimer.OnTimer := TimerExpired;
    FRepeatTimer.Interval := InitRepeatPause;
    FRepeatTimer.Enabled := True;
    FClicked := False;
  end;
end;

procedure TJvNoFrameButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  OrgMouseUp: TMouseEvent;
begin
  if FClicked then
  begin
    // prevent the OnClick event to trigger again
    if Assigned(OnMouseUp) then
      OnMouseUp(Self, Button, Shift, X, Y);
    OrgMouseUp := OnMouseUp;
    try
      OnMouseUp := nil;
      inherited MouseUp(Button, Shift, -1, -1)
    finally
      OnMouseUp := OrgMouseUp;
    end;
  end
  else
    inherited MouseUp(Button, Shift, X, Y);
  FreeAndNil(FRepeatTimer);
end;

procedure TJvNoFrameButton.TimerExpired(Sender: TObject);
begin
  FRepeatTimer.Interval := RepeatPause;
  if (FState = bsDown) and Enabled and MouseCapture then
  begin
    try
      FClicked := True;
      Click;
    except
      FRepeatTimer.Enabled := False;
      raise;
    end;
  end
  else
    FreeAndNil(FRepeatTimer);
end;

procedure TJvNoFrameButton.Paint;
begin
  if not Enabled then
  begin
    FState := bsDisabled;
    // FDragging := False;
  end
  else
  if FState = bsDisabled then
    if Down and (GroupIndex <> 0) then
      FState := bsExclusive
    else
      FState := bsUp;
  if Assigned(FOnPaint) then
    FOnPaint(Self, Down, False, FState)
  else
    DefaultDrawing(Down, FState);
end;

procedure TJvNoFrameButton.DefaultDrawing(const IsDown: Boolean; const State: TButtonState);
const
  DownStyles: array [Boolean] of Integer = (BDR_RAISEDINNER, BDR_SUNKENOUTER);
  FillStyles: array [Boolean] of Integer = (BF_MIDDLE, 0);
var
  PaintRect: TRect;
  Offset: TPoint;
begin
  if Flat and not NoBorder then
    inherited Paint
  else
  begin
    Canvas.Font := Self.Font;
    PaintRect := Rect(0, 0, Width, Height);
    if not NoBorder then
    begin
      DrawEdge(Canvas.Handle, PaintRect, DownStyles[FState in [bsDown, bsExclusive]],
        FillStyles[Transparent] or BF_RECT);
      InflateRect(PaintRect, -1, -1);
    end;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := Color;
    Canvas.FillRect(PaintRect);
    //if NoBorder and (csDesigning in ComponentState) then
    //  DrawDesignFrame(Canvas, PaintRect);
    InflateRect(PaintRect, -1, -1);

    if FState in [bsDown, bsExclusive] then
    begin
      if (FState = bsExclusive) then
      begin
        if Pattern = nil then
          CreateBrushPattern(clBtnFace, clBtnHighlight);
        Canvas.Brush.Bitmap := Pattern;
        Canvas.FillRect(PaintRect);
      end;
      Offset.X := 1;
      Offset.Y := 1;
    end
    else
    begin
      Offset.X := 0;
      Offset.Y := 0;
    end;
    {O}
    FGlyphDrawer.BiDiMode := BiDiMode;
    FGlyphDrawer.DrawExternal(Glyph, NumGlyphs, Color, True, Canvas, PaintRect, Offset, Caption, Layout, Margin,
      Spacing, FState, False {True});
  end;
end;

procedure TJvNoFrameButton.SetNoBorder(Value: Boolean);
begin
  if FNoBorder <> Value then
  begin
    FNoBorder := Value;
    Refresh;
  end;
end;

{ TJvComponentPanel }

constructor TJvComponentPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  BevelOuter := bvNone;
  FButtons := TList.Create;
  FFirstVisible := 0;
  FButtonWidth := 28;
  FButtonHeight := 28;
  FButtonLeft := TJvNoFrameButton.Create(Self);
  FButtonLeft.RepeatedClick := True;
  FButtonRight := TJvNoFrameButton.Create(Self);
  FButtonRight.RepeatedClick := True;
  FButtonPointer := TJvExSpeedButton.Create(Self);
  with FButtonLeft do
  begin
    Parent := Self;
    Tag := 0;
    Width := 12;
    Top := 0;
    Glyph.LoadFromResourceName(HInstance, 'JvComponentPanelLEFT');
    NumGlyphs := 2;
    OnClick := MoveClick;
  end;
  with FButtonRight do
  begin
    Parent := Self;
    Tag := 1;
    Width := 12;
    Top := 0;
    Glyph.LoadFromResourceName(HInstance, 'JvComponentPanelRIGHT');
    NumGlyphs := 2;
    OnClick := MoveClick;
  end;
  with FButtonPointer do
  begin
    Flat := True;
    Parent := Self;
    Top := 0;
    Glyph.LoadFromResourceName(HInstance, 'JvComponentPanelPOINTER');
    GroupIndex := 1;
    OnClick := BtnClick;
  end;
  SetMainButton;
end;

destructor TJvComponentPanel.Destroy;
var
  I: Integer;
begin
  for I := 0 to FButtons.Count - 1 do
    TJvExSpeedButton(FButtons[I]).Free;
  FButtons.Free;
  inherited Destroy;
end;

procedure TJvComponentPanel.CMHintShow(var Msg: TCMHintShow);
begin
  if FHintWindowClass <> nil then
    Msg.HintInfo.HintWindowClass := FHintWindowClass;
  inherited;
end;

procedure TJvComponentPanel.Invalidate;
begin
  if FLockUpdate = 0 then
    inherited Invalidate;
end;

procedure TJvComponentPanel.RecreateButtons;
var
  I: Integer;
  TmpNum: Integer;
begin
  TmpNum := FButtons.Count;
  for I := 0 to FButtons.Count - 1 do
    TJvExSpeedButton(FButtons[I]).Free;
  FButtons.Clear;
  FFirstVisible := 0;
  ButtonCount := TmpNum;
end;

procedure TJvComponentPanel.SetMainButton;
begin
  FButtonPointer.Down := True;
  FSelectButton := FButtonPointer;
end;

procedure TJvComponentPanel.SetSelectedButton(Value: Integer);
begin
  if (Value <> GetSelectedButton) and (Value >= -1) and (Value < ButtonCount) then
  begin
    if Value = -1 then
      SetMainButton
    else
    begin
      FSelectButton := Buttons[Value];
      FSelectButton.Down := True;
    end;
  end;
end;

function TJvComponentPanel.GetSelectedButton: Integer;
begin
  if FSelectButton <> nil then
  begin
    for Result := 0 to ButtonCount - 1 do
      if Buttons[Result] = FSelectButton then
        Exit;
  end;
  Result := -1;
end;

function TJvComponentPanel.GetButton(Index: Integer): TJvExSpeedButton;
begin
  if (Index < 0) or (Index > FButtons.Count - 1) then
    Result := nil
  else
    Result := TJvExSpeedButton(FButtons[Index]);
end;

function TJvComponentPanel.GetButtonCount: Integer;
begin
  Result := FButtons.Count;
end;

function TJvComponentPanel.GetVisibleCount: Integer;
begin
  Result := (Width - (12 + 12 + FButtonWidth)) div FButtonWidth;
end;

procedure TJvComponentPanel.SetButtonCount(AButtonCount: Integer);
var
  TmpButton: TJvExSpeedButton;
begin
  if AButtonCount < 0 then
    Exit;
  BeginUpdate;
  try
    SetMainButton;
    while FButtons.Count > AButtonCount do
    begin
      TJvExSpeedButton(FButtons[FButtons.Count - 1]).Free;
      FButtons.Delete(FButtons.Count - 1);
    end;
    while FButtons.Count < AButtonCount do
    begin
      TmpButton := TJvExSpeedButton.Create(Self);
      with TmpButton do
      begin
        Flat := True;
        Top := 0;
        GroupIndex := 1;
        HintWindowClass := Self.HintWindowClass;
        Parent := Self;
        OnClick := BtnClick;
        OnDblClick := BtnDblClick;
      end;
      FButtons.Add(TmpButton);
    end;
  finally
    EndUpdate;
  end;
end;

procedure TJvComponentPanel.SetButtonWidth(AButtonWidth: Integer);
begin
  if FButtonWidth <> AButtonWidth then
  begin
    FButtonWidth := AButtonWidth;
    Resize;
  end;
end;

procedure TJvComponentPanel.SetButtonHeight(AButtonHeight: Integer);
begin
  if FButtonHeight <> AButtonHeight then
  begin
    FButtonHeight := AButtonHeight;
    Resize;
  end;
end;

procedure TJvComponentPanel.MoveClick(Sender: TObject);
begin
  case TJvExSpeedButton(Sender).Tag of
    0:
      if FFirstVisible > 0 then
        Dec(FFirstVisible);
    1:
      if FButtons.Count > FFirstVisible + VisibleCount then
        Inc(FFirstVisible);
  end;
  Resize;
end;

procedure TJvComponentPanel.Paint;
begin
  inherited Paint;
  PaintContent(ClientRect);
end;

procedure TJvComponentPanel.PaintContent(const R: TRect);
begin
  if Assigned(FOnPaintContent) then
    FOnPaintContent(Self, Canvas, R);
end;

procedure TJvComponentPanel.BtnClick(Sender: TObject);
begin
  if FSelectButton <> Sender then
  begin
    FSelectButton := TJvExSpeedButton(Sender);
    if Assigned(FOnClick) then
      FOnClick(Sender, FButtons.IndexOf(FSelectButton));
  end;
end;

procedure TJvComponentPanel.BtnDblClick(Sender: TObject);
begin
  if Assigned(FOnDblClick) then
    FOnDblClick(Sender, FButtons.IndexOf(Sender));
end;

procedure TJvComponentPanel.WMSetText(var Msg: TWMSetText);
begin
  inherited;
  Caption := '';
end;

procedure TJvComponentPanel.Resize;
var
  I: Integer;
begin
  Height := FButtonHeight;
  if FButtonPointer = nil then
    Exit; // asn: for visualclx
  DisableAlign;
  try
    FButtonPointer.Height := FButtonHeight;
    FButtonPointer.Width := FButtonWidth;
    FButtonLeft.Height := FButtonHeight;
    FButtonRight.Height := FButtonHeight;
    FButtonPointer.Left := 0;
    FButtonLeft.Left := FButtonWidth + 6;
    FButtonRight.Left := (FButtonWidth + 12 + 6) + VisibleCount * FButtonWidth;
    FButtonLeft.Enabled := FFirstVisible > 0;
    FButtonRight.Enabled := FButtons.Count > FFirstVisible + VisibleCount;
    for I := 0 to FButtons.Count - 1 do
    begin
      if (I >= FFirstVisible) and (I < FFirstVisible + VisibleCount) then
        TJvExSpeedButton(FButtons[I]).SetBounds((FButtonWidth + 12 + 6) + (I - FFirstVisible) * FButtonWidth, 0, FButtonWidth, FButtonHeight)
      else
        TJvExSpeedButton(FButtons[I]).SetBounds(-100, 0, FButtonWidth, FButtonHeight);
    end;
  finally
    ControlState := ControlState - [csAlignmentNeeded];
    EnableAlign;
  end;
end;

function TJvComponentPanel.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if not Result then
  begin
    Result := True;

    WheelDelta := WheelDelta div WHEEL_DELTA;
    while WheelDelta <> 0 do
    begin
      if WheelDelta < 0 then
      begin
        if ButtonRight.Enabled then
          ButtonRight.Click
        else
          Break;
      end
      else
      begin
        if ButtonLeft.Enabled then
          ButtonLeft.Click
        else
          Break;
      end;

      if WheelDelta < 0 then
        Inc(WheelDelta)
      else
        Dec(WheelDelta);
    end;
  end;
end;

procedure TJvComponentPanel.SetFirstVisible(AButton: Integer);
begin
  if AButton >= ButtonCount then
    AButton := ButtonCount - 1;
  if AButton < 0 then
    AButton := 0;
  if FFirstVisible <> AButton then
  begin
    FFirstVisible := AButton;
    Resize;
  end;
end;

procedure TJvComponentPanel.BeginUpdate;
begin
  Inc(FLockUpdate);
  DisableAlign;
end;

procedure TJvComponentPanel.EndUpdate;
begin
  Dec(FLockUpdate);
  if FLockUpdate = 0 then
  begin
    Resize;
    ControlState := ControlState - [csAlignmentNeeded];
    EnableAlign;
  end;
end;

end.
