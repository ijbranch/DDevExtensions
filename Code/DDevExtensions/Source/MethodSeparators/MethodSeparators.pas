{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude Code                                           *}
{*                                                                            *}
{* MethodSeparators - draws a faint horizontal line in the code editor above  *}
{* each top-level routine, type declaration and unit section.                 *}
{*                                                                            *}
{* Idea credit: Tulip Method Separators by Samer Assil (MIT licence),         *}
{* https://github.com/SamerAssil/Tulip_Method_Separators                      *}
{* This is an independent implementation; no Tulip source is included.        *}
{*                                                                            *}
{******************************************************************************}

unit MethodSeparators;

/// <summary>
/// Method Separators feature: registers an <c>INTACodeEditorEvents</c> notifier that
/// draws a separator line at the top of every editor line returned by
/// <see cref="MethodSeparatorsCore.FindSeparatorLines"/>, with a per-file cache that is
/// re-checked at most every <see cref="TMethodSeparatorsConfig.RecheckIntervalMs"/> while
/// painting.
/// </summary>
/// <remarks>
/// All parsing and colour rules live in <c>MethodSeparatorsCore</c> ( covered by DUnitX );
/// this unit only reads editor buffers, caches results and paints.  The notifier
/// implements <c>INTACodeEditorEvents</c> alone, with no overloaded methods, so the IDE's
/// interface dispatch has exactly one method per slot on Win64 as well as Win32.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Generics.Collections, Vcl.Controls, Vcl.Graphics, Vcl.ExtCtrls,
  ToolsAPI, ToolsAPI.Editor, FrmTreePages, PluginConfig, MethodSeparatorsCore;

type
  /// <summary>Pen style of the separator line.</summary>
  TSeparatorLineStyle = (
    /// <summary>A dotted line ( the default; least intrusive ).</summary>
    slsDotted,
    /// <summary>A dashed line.</summary>
    slsDashed,
    /// <summary>A solid line.</summary>
    slsSolid
  );

  /// <summary>Cached scan result for one open source file.</summary>
  TSeparatorCacheEntry = class
  public
    /// <summary>The buffer text the separator lines were computed from.</summary>
    Text: UTF8String;
    /// <summary>The sorted 1-based separator lines for <see cref="Text"/>.</summary>
    Lines: TArray<Integer>;
    /// <summary>GetTickCount64 value when the buffer was last compared with <see cref="Text"/>.</summary>
    CheckedTick: UInt64;
  end;

  TMethodSeparatorsConfig = class;

  /// <summary>
  /// Code-editor notifier registered with the IDE.  Forwards the begin-paint and
  /// end-of-line paint events to its owning configuration and ignores the rest.
  /// </summary>
  TMethodSeparatorPainter = class( TNotifierObject, INTACodeEditorEvents )
  private
    /// <summary>The configuration that paints; nil once unregistered, so a late call does nothing.</summary>
    FOwner: TMethodSeparatorsConfig;
  public
    /// <summary>Creates a painter that forwards to AOwner.</summary>
    /// <param name="AOwner">The configuration that handles the paint events.</param>
    constructor Create( AOwner: TMethodSeparatorsConfig );
    /// <summary>Detaches the painter from its owner; later IDE calls do nothing.</summary>
    procedure Detach;
    /// <summary>INTACodeEditorEvents: ignored.</summary>
    /// <param name="Editor">The editor control.</param>
    /// <param name="Direction">The scroll direction.</param>
    procedure EditorScrolled( const Editor: TWinControl; const Direction: TCodeEditorScrollDirection );
    /// <summary>INTACodeEditorEvents: ignored.</summary>
    /// <param name="Editor">The editor control.</param>
    procedure EditorResized( const Editor: TWinControl );
    /// <summary>INTACodeEditorEvents: ignored.</summary>
    /// <param name="Editor">The editor control.</param>
    /// <param name="LogicalLineNum">The folded line.</param>
    procedure EditorElided( const Editor: TWinControl; const LogicalLineNum: Integer );
    /// <summary>INTACodeEditorEvents: ignored.</summary>
    /// <param name="Editor">The editor control.</param>
    /// <param name="LogicalLineNum">The unfolded line.</param>
    procedure EditorUnElided( const Editor: TWinControl; const LogicalLineNum: Integer );
    /// <summary>INTACodeEditorEvents: ignored.</summary>
    /// <param name="Editor">The editor control.</param>
    /// <param name="Button">The mouse button.</param>
    /// <param name="Shift">The modifier keys.</param>
    /// <param name="X">The horizontal position.</param>
    /// <param name="Y">The vertical position.</param>
    procedure EditorMouseDown( const Editor: TWinControl; Button: TMouseButton; Shift: TShiftState; X, Y: Integer );
    /// <summary>INTACodeEditorEvents: ignored.</summary>
    /// <param name="Editor">The editor control.</param>
    /// <param name="Shift">The modifier keys.</param>
    /// <param name="X">The horizontal position.</param>
    /// <param name="Y">The vertical position.</param>
    procedure EditorMouseMove( const Editor: TWinControl; Shift: TShiftState; X, Y: Integer );
    /// <summary>INTACodeEditorEvents: ignored.</summary>
    /// <param name="Editor">The editor control.</param>
    /// <param name="Button">The mouse button.</param>
    /// <param name="Shift">The modifier keys.</param>
    /// <param name="X">The horizontal position.</param>
    /// <param name="Y">The vertical position.</param>
    procedure EditorMouseUp( const Editor: TWinControl; Button: TMouseButton; Shift: TShiftState; X, Y: Integer );
    /// <summary>INTACodeEditorEvents: starts a paint cycle on the owner.</summary>
    /// <param name="Editor">The editor about to paint.</param>
    /// <param name="ForceFullRepaint">True when the whole editor repaints.</param>
    procedure BeginPaint( const Editor: TWinControl; const ForceFullRepaint: Boolean );
    /// <summary>INTACodeEditorEvents: ignored.</summary>
    /// <param name="Editor">The editor that has painted.</param>
    procedure EndPaint( const Editor: TWinControl );
    /// <summary>INTACodeEditorEvents: forwards each line's end-of-paint stage to the owner.</summary>
    /// <param name="Rect">The line's bounds.</param>
    /// <param name="Stage">The paint stage.</param>
    /// <param name="BeforeEvent">True before the IDE paints the stage, False after.</param>
    /// <param name="AllowDefaultPainting">Left unchanged: the IDE always paints the line.</param>
    /// <param name="Context">The editor and line being painted.</param>
    procedure PaintLine( const Rect: TRect; const Stage: TPaintLineStage; const BeforeEvent: Boolean;
      var AllowDefaultPainting: Boolean; const Context: INTACodeEditorPaintContext );
    /// <summary>INTACodeEditorEvents: not requested, so never called.</summary>
    /// <param name="Rect">The gutter bounds.</param>
    /// <param name="Stage">The paint stage.</param>
    /// <param name="BeforeEvent">True before the IDE paints the stage.</param>
    /// <param name="AllowDefaultPainting">Left unchanged.</param>
    /// <param name="Context">The editor and line being painted.</param>
    procedure PaintGutter( const Rect: TRect; const Stage: TPaintGutterStage; const BeforeEvent: Boolean;
      var AllowDefaultPainting: Boolean; const Context: INTACodeEditorPaintContext );
    /// <summary>INTACodeEditorEvents: not requested, so never called.</summary>
    /// <param name="Rect">The text bounds.</param>
    /// <param name="ColNum">The first column of the text.</param>
    /// <param name="Text">The text being painted.</param>
    /// <param name="SyntaxCode">The syntax element of the text.</param>
    /// <param name="Hilight">True when the text is highlighted.</param>
    /// <param name="BeforeEvent">True before the IDE paints the text.</param>
    /// <param name="AllowDefaultPainting">Left unchanged.</param>
    /// <param name="Context">The editor and line being painted.</param>
    procedure PaintText( const Rect: TRect; const ColNum: SmallInt; const Text: string; const SyntaxCode: TOTASyntaxCode;
      const Hilight, BeforeEvent: Boolean; var AllowDefaultPainting: Boolean; const Context: INTACodeEditorPaintContext );
    /// <summary>INTACodeEditorEvents: requests begin/end-paint and line-paint events only.</summary>
    /// <returns>The event groups this notifier handles.</returns>
    function AllowedEvents: TCodeEditorEvents;
    /// <summary>INTACodeEditorEvents: no gutter stages.</summary>
    /// <returns>An empty set.</returns>
    function AllowedGutterStages: TPaintGutterStages;
    /// <summary>INTACodeEditorEvents: only the end of each line's paint.</summary>
    /// <returns>The line stages this notifier handles.</returns>
    function AllowedLineStages: TPaintLineStages;
    /// <summary>INTACodeEditorEvents: no editor UI tweaks.</summary>
    /// <returns>An empty set.</returns>
    function UIOptions: TCodeEditorUIOptions;
  end;

  /// <summary>
  /// Plug-in configuration that owns the Method Separators feature: its settings, the
  /// registered editor notifier and the per-file cache of separator lines.
  /// </summary>
  TMethodSeparatorsConfig = class( TPluginConfig )
  private
    /// <summary>Backing field for Active.</summary>
    FActive: Boolean;
    /// <summary>Backing field for ShowTypes.</summary>
    FShowTypes: Boolean;
    /// <summary>Backing field for ShowSections.</summary>
    FShowSections: Boolean;
    /// <summary>Backing field for ShowInterface.</summary>
    FShowInterface: Boolean;
    /// <summary>Backing field for LineStyle.</summary>
    FLineStyle: TSeparatorLineStyle;
    /// <summary>Backing field for UseCustomColor.</summary>
    FUseCustomColor: Boolean;
    /// <summary>Backing field for CustomColor.</summary>
    FCustomColor: TColor;
    /// <summary>The registered notifier object; nil while unregistered.</summary>
    FPainter: TMethodSeparatorPainter;
    /// <summary>Interface reference that keeps FPainter alive while registered.</summary>
    FPainterIntf: INTACodeEditorEvents;
    /// <summary>Index returned by AddEditorEventsNotifier; -1 while unregistered.</summary>
    FNotifierIndex: Integer;
    /// <summary>Scan results keyed by lower-cased file name.</summary>
    FCache: TObjectDictionary<string, TSeparatorCacheEntry>;
    /// <summary>One-shot timer that repaints the top editor once a throttled re-check is due.</summary>
    FRecheckTimer: TTimer;
    /// <summary>True once the current paint cycle has re-checked its file.</summary>
    FCycleChecked: Boolean;
    /// <summary>Separator colour resolved at the start of the current paint cycle.</summary>
    FLineColor: TColor;

    /// <summary>Registers the editor notifier when it is not registered yet.</summary>
    procedure RegisterPainter;
    /// <summary>Unregisters the editor notifier when it is registered.</summary>
    procedure UnregisterPainter;
    /// <summary>Returns the scan options matching the current settings.</summary>
    /// <returns>The options passed to FindSeparatorLines.</returns>
    function ScanOptions: TSeparatorOptions;
    /// <summary>Re-reads View's buffer and rescans it when its text changed.</summary>
    /// <param name="Entry">The cache entry to bring up to date.</param>
    /// <param name="View">The edit view whose buffer is read.</param>
    procedure RefreshEntry( Entry: TSeparatorCacheEntry; const View: IOTAEditView );
    /// <summary>Returns the up-to-date cache entry for the file being painted, or nil for a non-Pascal file.</summary>
    /// <param name="Context">The paint context of the current line.</param>
    /// <returns>The cache entry, or nil.</returns>
    function EntryFor( const Context: INTACodeEditorPaintContext ): TSeparatorCacheEntry;
    /// <summary>Draws the separator along the top edge of Rect without disturbing the canvas state.</summary>
    /// <param name="Canvas">The editor canvas.</param>
    /// <param name="Rect">The line's bounds.</param>
    procedure DrawSeparator( Canvas: TCanvas; const Rect: TRect );
    /// <summary>Recheck-timer callback: repaints the top editor so the pending re-check runs.</summary>
    /// <param name="Sender">The timer.</param>
    procedure HandleRecheckTimer( Sender: TObject );
  protected
    /// <summary>Sets default values for newly created configurations.</summary>
    procedure Init; override;
    /// <summary>Returns the options-tree page used to edit this plug-in's settings.</summary>
    /// <returns>The Method Separators options page.</returns>
    function GetOptionPages: TTreePage; override;
  public
    const
      /// <summary>Shortest interval, in milliseconds, between two reads of the same buffer while painting.</summary>
      RecheckIntervalMs = 250;
      /// <summary>Delay, in milliseconds, before a throttled re-check is forced by a repaint.</summary>
      RecheckDelayMs = 300;
      /// <summary>Number of cached files above which the cache is emptied ( closed files are not tracked ).</summary>
      MaxCachedFiles = 64;
    /// <summary>Creates the configuration, loads its settings and registers the notifier when Active.</summary>
    constructor Create;
    /// <summary>Unregisters the notifier and frees the cache and timer.</summary>
    destructor Destroy; override;
    /// <summary>Applies changed settings: registers or unregisters the notifier, drops the cache and repaints.</summary>
    procedure ApplySettings;
    /// <summary>Starts a paint cycle: the next painted line re-checks its file and the colour is resolved.</summary>
    procedure HandleBeginPaint;
    /// <summary>Draws a separator above the painted line when it starts a block.</summary>
    /// <param name="Rect">The line's bounds.</param>
    /// <param name="Stage">The paint stage.</param>
    /// <param name="BeforeEvent">True before the IDE paints the stage, False after.</param>
    /// <param name="Context">The editor and line being painted.</param>
    procedure HandlePaintLine( const Rect: TRect; const Stage: TPaintLineStage; const BeforeEvent: Boolean;
      const Context: INTACodeEditorPaintContext );
  published
    /// <summary>Master switch that shows or hides the separators.</summary>
    property Active: Boolean read FActive write FActive;
    /// <summary>Also separate class, record and interface declarations.</summary>
    property ShowTypes: Boolean read FShowTypes write FShowTypes;
    /// <summary>Also separate the initialization and finalization sections and a program's main block.</summary>
    property ShowSections: Boolean read FShowSections write FShowSections;
    /// <summary>Also separate declarations in the interface section.</summary>
    property ShowInterface: Boolean read FShowInterface write FShowInterface;
    /// <summary>Pen style of the separator.</summary>
    property LineStyle: TSeparatorLineStyle read FLineStyle write FLineStyle;
    /// <summary>Use CustomColor instead of the colour derived from the editor background.</summary>
    property UseCustomColor: Boolean read FUseCustomColor write FUseCustomColor;
    /// <summary>The user's separator colour; replaced by the automatic one when it would not show against the background.</summary>
    property CustomColor: TColor read FCustomColor write FCustomColor;
  end;

/// <summary>
/// Initialises or shuts down the Method Separators plug-in by creating or freeing
/// the global TMethodSeparatorsConfig instance.
/// </summary>
/// <param name="Unload">False to load the plug-in, True to unload it.</param>
procedure InitPlugin( Unload: Boolean );

implementation

uses
  Main, ToolsAPIHelpers, FrmeOptionPageMethodSeparators;

var
  MethodSeparatorsConfig: TMethodSeparatorsConfig;

procedure InitPlugin( Unload: Boolean );
begin

  if not Unload then
    MethodSeparatorsConfig := TMethodSeparatorsConfig.Create
  else
    FreeAndNil( MethodSeparatorsConfig );

end;

{ TMethodSeparatorPainter }

constructor TMethodSeparatorPainter.Create( AOwner: TMethodSeparatorsConfig );
begin

  inherited Create;
  FOwner := AOwner;

end;

procedure TMethodSeparatorPainter.Detach;
begin

  FOwner := nil;

end;

procedure TMethodSeparatorPainter.EditorScrolled( const Editor: TWinControl; const Direction: TCodeEditorScrollDirection );
begin
end;

procedure TMethodSeparatorPainter.EditorResized( const Editor: TWinControl );
begin
end;

procedure TMethodSeparatorPainter.EditorElided( const Editor: TWinControl; const LogicalLineNum: Integer );
begin
end;

procedure TMethodSeparatorPainter.EditorUnElided( const Editor: TWinControl; const LogicalLineNum: Integer );
begin
end;

procedure TMethodSeparatorPainter.EditorMouseDown( const Editor: TWinControl; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer );
begin
end;

procedure TMethodSeparatorPainter.EditorMouseMove( const Editor: TWinControl; Shift: TShiftState; X, Y: Integer );
begin
end;

procedure TMethodSeparatorPainter.EditorMouseUp( const Editor: TWinControl; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer );
begin
end;

procedure TMethodSeparatorPainter.BeginPaint( const Editor: TWinControl; const ForceFullRepaint: Boolean );
begin

  if FOwner <> nil then
    FOwner.HandleBeginPaint;

end;

procedure TMethodSeparatorPainter.EndPaint( const Editor: TWinControl );
begin
end;

procedure TMethodSeparatorPainter.PaintLine( const Rect: TRect; const Stage: TPaintLineStage; const BeforeEvent: Boolean;
  var AllowDefaultPainting: Boolean; const Context: INTACodeEditorPaintContext );
begin

  if FOwner <> nil then
    FOwner.HandlePaintLine( Rect, Stage, BeforeEvent, Context );

end;

procedure TMethodSeparatorPainter.PaintGutter( const Rect: TRect; const Stage: TPaintGutterStage; const BeforeEvent: Boolean;
  var AllowDefaultPainting: Boolean; const Context: INTACodeEditorPaintContext );
begin
end;

procedure TMethodSeparatorPainter.PaintText( const Rect: TRect; const ColNum: SmallInt; const Text: string;
  const SyntaxCode: TOTASyntaxCode; const Hilight, BeforeEvent: Boolean; var AllowDefaultPainting: Boolean;
  const Context: INTACodeEditorPaintContext );
begin
end;

function TMethodSeparatorPainter.AllowedEvents: TCodeEditorEvents;
begin

  Result := [cevBeginEndPaintEvents, cevPaintLineEvents];

end;

function TMethodSeparatorPainter.AllowedGutterStages: TPaintGutterStages;
begin

  Result := [];

end;

function TMethodSeparatorPainter.AllowedLineStages: TPaintLineStages;
begin

  Result := [plsEndPaint];

end;

function TMethodSeparatorPainter.UIOptions: TCodeEditorUIOptions;
begin

  Result := [];

end;

{ TMethodSeparatorsConfig }

constructor TMethodSeparatorsConfig.Create;
begin

  FNotifierIndex := -1;
  FCache := TObjectDictionary<string, TSeparatorCacheEntry>.Create( [doOwnsValues] );
  FRecheckTimer := TTimer.Create( nil );
  FRecheckTimer.Enabled := False;
  FRecheckTimer.Interval := RecheckDelayMs;
  FRecheckTimer.OnTimer := HandleRecheckTimer;

  inherited Create( AppDataDirectory + '\MethodSeparators.xml', 'MethodSeparators' );

  ApplySettings;

end;

destructor TMethodSeparatorsConfig.Destroy;
begin

  UnregisterPainter;
  FRecheckTimer.Free;
  FCache.Free;

  inherited Destroy;

end;

procedure TMethodSeparatorsConfig.Init;
begin

  inherited Init;
  FActive := True;
  FShowTypes := True;
  FShowSections := True;
  FShowInterface := False;
  FLineStyle := slsDotted;
  FUseCustomColor := False;
  FCustomColor := TColors.Gray;

end;

function TMethodSeparatorsConfig.GetOptionPages: TTreePage;
begin

  Result := TTreePage.Create( 'Method Separators', TFrameOptionPageMethodSeparators, Self );

end;

procedure TMethodSeparatorsConfig.ApplySettings;
var
  Services: INTACodeEditorServices;
begin

  FRecheckTimer.Enabled := False;
  FCache.Clear;
  if FActive then
    RegisterPainter
  else
    UnregisterPainter;

  if Supports( BorlandIDEServices, INTACodeEditorServices, Services ) then
    Services.InvalidateTopEditor;

end;

procedure TMethodSeparatorsConfig.RegisterPainter;
var
  Services: INTACodeEditorServices;
begin

  if FNotifierIndex >= 0 then
    Exit;
  if not Supports( BorlandIDEServices, INTACodeEditorServices, Services ) then
    Exit;

  FPainter := TMethodSeparatorPainter.Create( Self );
  FPainterIntf := FPainter;
  FNotifierIndex := Services.AddEditorEventsNotifier( FPainterIntf );

end;

procedure TMethodSeparatorsConfig.UnregisterPainter;
var
  Services: INTACodeEditorServices;
begin

  if FNotifierIndex < 0 then
    Exit;

  // Detach first: should the IDE still hold the notifier and call it, it must not reach a freed configuration.
  FPainter.Detach;
  if Supports( BorlandIDEServices, INTACodeEditorServices, Services ) then
    Services.RemoveEditorEventsNotifier( FNotifierIndex );
  FNotifierIndex := -1;
  FPainter := nil;
  FPainterIntf := nil;

end;

function TMethodSeparatorsConfig.ScanOptions: TSeparatorOptions;
begin

  Result.IncludeTypes := FShowTypes;
  Result.IncludeSections := FShowSections;
  Result.IncludeInterface := FShowInterface;

end;

procedure TMethodSeparatorsConfig.RefreshEntry( Entry: TSeparatorCacheEntry; const View: IOTAEditView );
var
  Text: UTF8String;
begin

  Entry.CheckedTick := GetTickCount64;
  if ( View = nil ) or ( View.Buffer = nil ) then
    Exit;

  Text := GetEditorSource( View.Buffer );
  if Text = Entry.Text then
    Exit;
  Entry.Text := Text;
  Entry.Lines := FindSeparatorLines( Text, ScanOptions );

end;

function TMethodSeparatorsConfig.EntryFor( const Context: INTACodeEditorPaintContext ): TSeparatorCacheEntry;
var
  FileName: string;
  Key: string;
begin

  FileName := Context.FileName;
  if not IsPascalSourceFile( FileName ) then
    Exit( nil );

  Key := AnsiLowerCase( FileName );
  if not FCache.TryGetValue( Key, Result ) then
  begin
    if FCache.Count >= MaxCachedFiles then
      FCache.Clear;
    Result := TSeparatorCacheEntry.Create;
    FCache.Add( Key, Result );
    RefreshEntry( Result, Context.EditView );
    FCycleChecked := True;
    Exit;
  end;

  // A deferred check is made up by a repaint shortly after, so the last
  // keystroke of a burst is never left with stale separators.
  case DecideRecheck( FCycleChecked, GetTickCount64, Result.CheckedTick, RecheckIntervalMs ) of
    raRefresh:
      RefreshEntry( Result, Context.EditView );
    raDefer:
      if not FRecheckTimer.Enabled then
        FRecheckTimer.Enabled := True;
  end;
  FCycleChecked := True;

end;

procedure TMethodSeparatorsConfig.HandleBeginPaint;
var
  Services: INTACodeEditorServices;
  Background: TColor;
begin

  FCycleChecked := False;
  Background := clWindow;
  if Supports( BorlandIDEServices, INTACodeEditorServices, Services ) and ( Services.Options <> nil ) then
    Background := Services.Options.BackgroundColor[atWhiteSpace];
  FLineColor := ResolveSeparatorColor( ColorToRGB( Background ), ColorToRGB( FCustomColor ), FUseCustomColor );

end;

procedure TMethodSeparatorsConfig.HandlePaintLine( const Rect: TRect; const Stage: TPaintLineStage; const BeforeEvent: Boolean;
  const Context: INTACodeEditorPaintContext );
var
  Entry: TSeparatorCacheEntry;
begin

  if ( Stage <> plsEndPaint ) or BeforeEvent or ( Context = nil ) then
    Exit;

  Entry := EntryFor( Context );
  if ( Entry <> nil ) and IsSeparatorLine( Entry.Lines, Context.LogicalLineNum ) then
    DrawSeparator( Context.Canvas, Rect );

end;

procedure TMethodSeparatorsConfig.DrawSeparator( Canvas: TCanvas; const Rect: TRect );
const
  PenStyles: array[TSeparatorLineStyle] of TPenStyle = ( psDot, psDash, psSolid );
var
  OldColor: TColor;
  OldStyle: TPenStyle;
  OldWidth: Integer;
  OldMode: TPenMode;
  OldBkMode: Integer;
begin

  OldColor := Canvas.Pen.Color;
  OldStyle := Canvas.Pen.Style;
  OldWidth := Canvas.Pen.Width;
  OldMode := Canvas.Pen.Mode;
  // Transparent background mode, or the gaps of a dotted line are filled with the brush colour.
  OldBkMode := SetBkMode( Canvas.Handle, TRANSPARENT );
  try
    Canvas.Pen.Color := FLineColor;
    Canvas.Pen.Style := PenStyles[FLineStyle];
    Canvas.Pen.Width := 1;
    Canvas.Pen.Mode := pmCopy;
    Canvas.MoveTo( Rect.Left, Rect.Top );
    Canvas.LineTo( Rect.Right, Rect.Top );
  finally
    SetBkMode( Canvas.Handle, OldBkMode );
    Canvas.Pen.Mode := OldMode;
    Canvas.Pen.Width := OldWidth;
    Canvas.Pen.Style := OldStyle;
    Canvas.Pen.Color := OldColor;
  end;

end;

procedure TMethodSeparatorsConfig.HandleRecheckTimer( Sender: TObject );
var
  Services: INTACodeEditorServices;
begin

  FRecheckTimer.Enabled := False;
  if Supports( BorlandIDEServices, INTACodeEditorServices, Services ) then
    Services.InvalidateTopEditor;

end;

end.
