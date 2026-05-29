{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2009 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageKeybindings;

/// <summary>
/// Configuration class and options-page frame for the Key Bindings plug-in. Implements an
/// IOTAKeyboardBinding that intercepts a configurable set of editor keystrokes (smart Tab,
/// extended Home/Ctrl-Left/Ctrl-Right, Move-Line-Block, Find-Declaration on caret and
/// Interface/Implementation Section Toggle) and persists user choices to KeyBindings.xml.
/// </summary>

{$I ..\DelphiExtension.inc}
{.$O-}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FrmTreePages, ToolsAPI, PluginConfig, SimpleXmlIntf, Menus,
  ActnList, FrmeBase, ExtCtrls, ComCtrls, AnsiStrings;

type
  /// <summary>
  /// Persistent configuration plus IOTAKeyboardBinding implementation. Owns every preference
  /// that the Key Bindings options page exposes and (un)registers IDE key bindings as
  /// settings change.
  /// </summary>
  TKeybindings = class(TPluginConfig, IOTAKeyboardBinding)
  private
    /// <summary>Notifier index returned by AddKeyboardBinding; -1 when not currently registered.</summary>
    FNotifierIndex: Integer;
    /// <summary>Master on/off switch for every key binding the plug-in installs.</summary>
    FActive: Boolean;
    /// <summary>True to indent/un-indent the selection with Tab/Shift-Tab.</summary>
    FTabIndent: Boolean;
    /// <summary>True to apply Tab indentation to single-line selections too.</summary>
    FIndentSingleLine: Boolean;
    /// <summary>True to make Home toggle between BOL and first non-whitespace.</summary>
    FExtendedHome: Boolean;
    /// <summary>True to invert the Extended Home order (first non-whitespace, then BOL).</summary>
    FSwitchedExtendedHome: Boolean;
    /// <summary>True to enable richer Ctrl-Left/Ctrl-Right cursor moves through tokens/operators.</summary>
    FExtendedCtrlLeftRight: Boolean;
    {$IF CompilerVersion <= 20.0}
    /// <summary>True to make Shift-F3 perform a reverse search on Delphi 2009 and earlier.</summary>
    FShiftF3: Boolean;
    {$IFEND}
    /// <summary>True to enable the Move-Line/Block-up/down feature.</summary>
    FMoveLineBlock: Boolean;
    /// <summary>True to enable Ctrl-Alt-PgUp Find-Declaration-on-caret.</summary>
    FFindDeclOnCaret: Boolean;
    /// <summary>True to enable the interface/implementation Section Toggle feature.</summary>
    FSectionToggle: Boolean;
    /// <summary>User-chosen shortcut to jump up to the previous section heading.</summary>
    FSectionToggleUpKey: TShortCut;
    /// <summary>User-chosen shortcut to jump down to the next section heading.</summary>
    FSectionToggleDownKey: TShortCut;
    /// <summary>User-chosen shortcut to move the current line/block up.</summary>
    FMoveLineBlockUpKey: TShortCut;
    /// <summary>User-chosen shortcut to move the current line/block down.</summary>
    FMoveLineBlockDownKey: TShortCut;
    /// <summary>Updates FActive and (un)registers the keyboard binding with the IDE.</summary>
    procedure SetActive(const Value: Boolean);
    /// <summary>Implements the Section Toggle, jumping between interface and implementation.</summary>
    procedure ToggleSection(EditBuffer: IOTAEditBuffer);
    /// <summary>IOTAKeyboardBinding callback that dispatches each registered shortcut.</summary>
    /// <param name="Context">Editor context for the keystroke.</param>
    /// <param name="KeyCode">The shortcut that was pressed.</param>
    /// <param name="BindingResult">Out parameter set to krHandled / krUnhandled / krNextProc.</param>
    procedure DoKeyBinding(const Context: IOTAKeyContext; KeyCode: TShortcut;
      var BindingResult: TKeyBindingResult);
    /// <summary>Internal worker for CtrlMoveCursor that consumes a single token starting at the caret.</summary>
    procedure InternCtrlMoveCursor(EditPosition: IOTAEditPosition; InComment: Boolean);
    /// <summary>Smart Ctrl-Left/Ctrl-Right cursor movement with optional selection extension.</summary>
    procedure CtrlMoveCursor(EditBuffer: IOTAEditBuffer; View: IOTAEditView;
      EditPosition: IOTAEditPosition; ForwardMove: Boolean);
    /// <summary>Moves the current line or selected block up or down within the buffer.</summary>
    /// <param name="EditBuffer">Buffer to operate on.</param>
    /// <param name="Down">True to move down, False to move up.</param>
    procedure MoveLineBlockText(EditBuffer: IOTAEditBuffer; Down: Boolean);
    /// <summary>Triggers the IDE's Find Declaration action against the caret position.</summary>
    procedure FindDeclaration(EditBuffer: IOTAEditBuffer);
    //procedure ReturnPressed(EditBuffer: IOTAEditBuffer);
  protected
    /// <summary>Returns the option-page descriptor for the IDE Tools > Options dialog.</summary>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises preferences to factory defaults.</summary>
    procedure Init; override;
    /// <summary>Re-arms the keyboard binding once configuration has been loaded.</summary>
    procedure Loaded; override;
  public
    /// <summary>Creates the configuration and loads it from KeyBindings.xml in the app data directory.</summary>
    constructor Create;
    /// <summary>Deactivates the binding (removes the notifier) and frees the instance.</summary>
    destructor Destroy; override;

    { IOTAKeyboardBinding }
    /// <summary>Adds every active key binding to the IDE's keyboard service.</summary>
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
    /// <summary>Returns btPartial - this binding only handles selected shortcuts.</summary>
    function GetBindingType: TBindingType;
    /// <summary>Returns the display name shown in Tools > Options &gt; Editor &gt; Key Mappings.</summary>
    function GetDisplayName: string;
    /// <summary>Returns the unique internal name of the binding.</summary>
    function GetName: string;
    /// <summary>IOTAKeyboardBinding hook fired after a save; no-op.</summary>
    procedure AfterSave;
    /// <summary>IOTAKeyboardBinding hook fired before a save; no-op.</summary>
    procedure BeforeSave;
    /// <summary>IOTAKeyboardBinding hook fired when the binding is destroyed; no-op.</summary>
    procedure Destroyed;
    /// <summary>IOTAKeyboardBinding hook fired when the binding is marked modified; no-op.</summary>
    procedure Modified;
  published
    /// <summary>Master switch that enables or disables every key binding at once.</summary>
    property Active: Boolean read FActive write SetActive;
    /// <summary>Enables Tab / Shift-Tab block indentation.</summary>
    property TabIndent: Boolean read FTabIndent write FTabIndent;
    /// <summary>True to apply TabIndent even when only a single line is selected.</summary>
    property IndentSingleLine: Boolean read FIndentSingleLine write FIndentSingleLine;
    /// <summary>True to enable Extended Home behaviour.</summary>
    property ExtendedHome: Boolean read FExtendedHome write FExtendedHome;
    /// <summary>True to invert the Extended Home toggle order.</summary>
    property SwitchedExtendedHome: Boolean read FSwitchedExtendedHome write FSwitchedExtendedHome;
    /// <summary>True to enable the smarter Ctrl-Left/Ctrl-Right movement.</summary>
    property ExtendedCtrlLeftRight: Boolean read FExtendedCtrlLeftRight write FExtendedCtrlLeftRight;
    {$IF CompilerVersion <= 20.0}
    /// <summary>True to provide reverse-Find behaviour for Shift-F3 on Delphi 2009 and earlier.</summary>
    property ShiftF3: Boolean read FShiftF3 write FShiftF3;
    {$IFEND}
    /// <summary>True to enable the Move-Line/Block feature.</summary>
    property MoveLineBlock: Boolean read FMoveLineBlock write FMoveLineBlock;
    /// <summary>True to enable Ctrl-Alt-PgUp Find-Declaration-on-caret.</summary>
    property FindDeclOnCaret: Boolean read FFindDeclOnCaret write FFindDeclOnCaret;
    /// <summary>True to enable the interface/implementation Section Toggle.</summary>
    property SectionToggle: Boolean read FSectionToggle write FSectionToggle;
    /// <summary>Shortcut for Section Toggle - jump to previous section heading.</summary>
    property SectionToggleUpKey: TShortCut read FSectionToggleUpKey write FSectionToggleUpKey;
    /// <summary>Shortcut for Section Toggle - jump to next section heading.</summary>
    property SectionToggleDownKey: TShortCut read FSectionToggleDownKey write FSectionToggleDownKey;
    /// <summary>Shortcut to move the current line or selection up.</summary>
    property MoveLineBlockUpKey: TShortCut read FMoveLineBlockUpKey write FMoveLineBlockUpKey;
    /// <summary>Shortcut to move the current line or selection down.</summary>
    property MoveLineBlockDownKey: TShortCut read FMoveLineBlockDownKey write FMoveLineBlockDownKey;
  end;

  /// <summary>
  /// Designer frame providing the user interface for the Key Bindings options page hosted in
  /// the IDE's Tools > Options dialog.
  /// </summary>
  TFrameOptionPageKeybindings = class(TFrameBase, ITreePageComponent)
    /// <summary>Master on/off check box.</summary>
    cbxActive: TCheckBox;
    /// <summary>Toggle for Tab indentation.</summary>
    cbxTabIndent: TCheckBox;
    /// <summary>Toggle for the Extended Home behaviour.</summary>
    cbxExtendedHome: TCheckBox;
    /// <summary>Toggle for swapping the Extended Home order (first non-whitespace first).</summary>
    cbxSwitchExtendedHome: TCheckBox;
    /// <summary>Toggle for indenting single-line selections.</summary>
    cbxIndentSingleLine: TCheckBox;
    /// <summary>Toggle for the Ctrl-Left/Ctrl-Right enhancement.</summary>
    cbxExtendedCtrlLeftRight: TCheckBox;
    /// <summary>Toggle for the legacy Shift-F3 reverse search (Delphi 2009 and earlier only).</summary>
    cbxShiftF3: TCheckBox;
    /// <summary>Toggle for Move-Line/Block.</summary>
    chkMoveLineBlock: TCheckBox;
    /// <summary>Toggle for Find-Declaration-on-caret.</summary>
    chkFindDeclOnCaret: TCheckBox;
    /// <summary>Toggle for Section Toggle.</summary>
    chkSectionToggle: TCheckBox;
    /// <summary>Caption for hkMoveLineUp.</summary>
    lblMoveLineUp: TLabel;
    /// <summary>Caption for hkMoveLineDown.</summary>
    lblMoveLineDown: TLabel;
    /// <summary>Caption for hkSectionUp.</summary>
    lblSectionUp: TLabel;
    /// <summary>Caption for hkSectionDown.</summary>
    lblSectionDown: TLabel;
    /// <summary>Hot-key control for capturing the Move-Line-Up shortcut.</summary>
    hkMoveLineUp: THotKey;
    /// <summary>Hot-key control for capturing the Move-Line-Down shortcut.</summary>
    hkMoveLineDown: THotKey;
    /// <summary>Hot-key control for capturing the Section-Toggle-Up shortcut.</summary>
    hkSectionUp: THotKey;
    /// <summary>Hot-key control for capturing the Section-Toggle-Down shortcut.</summary>
    hkSectionDown: THotKey;
    /// <summary>Re-evaluates dependent control enabled state when Active changes.</summary>
    procedure cbxActiveClick(Sender: TObject);
    /// <summary>Enables/disables the swap-order check box based on cbxExtendedHome.</summary>
    procedure cbxExtendedHomeClick(Sender: TObject);
    /// <summary>Enables/disables cbxIndentSingleLine based on cbxTabIndent.</summary>
    procedure cbxTabIndentClick(Sender: TObject);
    /// <summary>Enables/disables the Move-Line shortcut controls based on the master check box.</summary>
    procedure chkMoveLineBlockClick(Sender: TObject);
    /// <summary>Enables/disables the Section-Toggle shortcut controls based on the master check box.</summary>
    procedure chkSectionToggleClick(Sender: TObject);
  private
    { Private-Deklarationen }
    /// <summary>Configuration object passed in via SetUserData.</summary>
    FKeyBindings: TKeybindings;
  public
    { Public-Deklarationen }
    /// <summary>Receives the TKeybindings configuration object that backs this page.</summary>
    /// <param name="UserData">Must be a TKeybindings instance.</param>
    procedure SetUserData(UserData: TObject);
    /// <summary>Copies current configuration values into the controls.</summary>
    procedure LoadData;
    /// <summary>Persists control values back into the configuration object and saves to disk.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes visible. No-op.</summary>
    procedure Selected;
    /// <summary>Called when the page is hidden. No-op.</summary>
    procedure Unselected;
  end;

/// <summary>
/// Plug-in entry point. Creates the global TKeybindings instance on load and frees it on
/// unload.
/// </summary>
/// <param name="Unload">False during plug-in initialisation, True during plug-in shutdown.</param>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  Main, IDEHooks, Hooking, ToolsAPIHelpers, IDEUtils;

{$R *.dfm}

type
  UTF8Char = AnsiChar;
  PUTF8Char = ^UTF8Char;

var
  Keybindings: TKeybindings;

{$IF CompilerVersion <= 20.0}
procedure TCustomEditControl_RepeatSearch(AEditControl: TWinControl);
  external coreide_bpl name '@Editorcontrol@TCustomEditControl@RepeatSearch$qqrv' {$IFDEF WIN64} delayed {$ENDIF};
procedure EnvironmentOptionsAddr;
  external coreide_bpl name '@Envoptions@EnvironmentOptions' {$IFDEF WIN64} delayed {$ENDIF};
{$IFEND}

procedure EditorActionListsPtr;
  external coreide_bpl name '@Editoractions@EditorActionLists' {$IFDEF WIN64} delayed {$ENDIF};

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    Keybindings := TKeybindings.Create
  else
    FreeAndNil(Keybindings);
end;

function GetEndColumn(EditPosition: IOTAEditPosition): Integer;
var
  Col: Integer;
begin
  Col := EditPosition.Column;
  EditPosition.MoveEOL;
  Result := EditPosition.Column;
  EditPosition.Move(EditPosition.Row, Col);
end;

{function IsPascalFile(const Filename: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  Result := (Ext = '.pas') or (Ext = '.pp') or (Ext = '.inc') or (Ext = '.dpr') or (Ext = '.dpk'));
end;}

{ TFrameOptionPageKeybindings }

procedure TFrameOptionPageKeybindings.SetUserData(UserData: TObject);
begin
  FKeyBindings := UserData as TKeyBindings;
end;

procedure TFrameOptionPageKeybindings.cbxActiveClick(Sender: TObject);
begin
  cbxTabIndent.Enabled := cbxActive.Checked;
  cbxTabIndentClick(cbxTabIndent);
  cbxExtendedHome.Enabled := cbxActive.Checked;
  cbxExtendedCtrlLeftRight.Enabled := cbxActive.Checked;
  chkMoveLineBlock.Enabled := cbxActive.Checked;
  chkFindDeclOnCaret.Enabled := cbxActive.Checked;
  chkSectionToggle.Enabled := cbxActive.Checked;
  cbxExtendedHomeClick(cbxExtendedHome);
  chkMoveLineBlockClick(chkMoveLineBlock);
  chkSectionToggleClick(chkSectionToggle);
end;

procedure TFrameOptionPageKeybindings.cbxExtendedHomeClick(Sender: TObject);
begin
  cbxSwitchExtendedHome.Enabled := cbxExtendedHome.Enabled and cbxExtendedHome.Checked;
end;

procedure TFrameOptionPageKeybindings.cbxTabIndentClick(Sender: TObject);
begin
  cbxIndentSingleLine.Enabled := cbxTabIndent.Enabled;
end;

procedure TFrameOptionPageKeybindings.chkMoveLineBlockClick(Sender: TObject);
var
  FieldsEnabled: Boolean;
begin
  FieldsEnabled := chkMoveLineBlock.Enabled and chkMoveLineBlock.Checked;
  lblMoveLineUp.Enabled := FieldsEnabled;
  lblMoveLineDown.Enabled := FieldsEnabled;
  hkMoveLineUp.Enabled := FieldsEnabled;
  hkMoveLineDown.Enabled := FieldsEnabled;
end;

procedure TFrameOptionPageKeybindings.chkSectionToggleClick(Sender: TObject);
var
  FieldsEnabled: Boolean;
begin
  FieldsEnabled := chkSectionToggle.Enabled and chkSectionToggle.Checked;
  lblSectionUp.Enabled := FieldsEnabled;
  lblSectionDown.Enabled := FieldsEnabled;
  hkSectionUp.Enabled := FieldsEnabled;
  hkSectionDown.Enabled := FieldsEnabled;
end;

procedure TFrameOptionPageKeybindings.LoadData;
begin
  cbxActive.Checked := FKeybindings.Active;
  cbxTabIndent.Checked := FKeybindings.TabIndent;
  cbxIndentSingleLine.Checked := FKeyBindings.IndentSingleLine;
  cbxExtendedHome.Checked := FKeyBindings.ExtendedHome;
  cbxSwitchExtendedHome.Checked := FKeyBindings.SwitchedExtendedHome;
  cbxExtendedCtrlLeftRight.Checked := FKeyBindings.ExtendedCtrlLeftRight;
  {$IF CompilerVersion <= 20.0}
  cbxShiftF3.Checked := FKeyBindings.ShiftF3;
  cbxShiftF3.Visible := True;
  {$IFEND}
  chkMoveLineBlock.Checked := FKeyBindings.MoveLineBlock;
  chkFindDeclOnCaret.Checked := FKeyBindings.FindDeclOnCaret;
  chkSectionToggle.Checked := FKeyBindings.SectionToggle;
  hkMoveLineUp.HotKey := FKeyBindings.MoveLineBlockUpKey;
  hkMoveLineDown.HotKey := FKeyBindings.MoveLineBlockDownKey;
  hkSectionUp.HotKey := FKeyBindings.SectionToggleUpKey;
  hkSectionDown.HotKey := FKeyBindings.SectionToggleDownKey;

  cbxActiveClick(cbxActive);
  cbxExtendedHomeClick(cbxExtendedHome);
end;

procedure TFrameOptionPageKeybindings.SaveData;
begin
  FKeybindings.Active := False; // => remove all key bindings
  FKeybindings.TabIndent := cbxTabIndent.Checked;
  FKeyBindings.IndentSingleLine := cbxIndentSingleLine.Checked;
  FKeyBindings.ExtendedHome := cbxExtendedHome.Checked;
  FKeyBindings.SwitchedExtendedHome := cbxSwitchExtendedHome.Checked;
  FKeyBindings.ExtendedCtrlLeftRight := cbxExtendedCtrlLeftRight.Checked;
  {$IF CompilerVersion <= 20.0}
  FKeyBindings.ShiftF3 := cbxShiftF3.Checked;
  {$IFEND}
  FKeyBindings.MoveLineBlock := chkMoveLineBlock.Checked;
  FKeyBindings.FindDeclOnCaret := chkFindDeclOnCaret.Checked;
  FKeyBindings.SectionToggle := chkSectionToggle.Checked;
  FKeyBindings.MoveLineBlockUpKey := hkMoveLineUp.HotKey;
  FKeyBindings.MoveLineBlockDownKey := hkMoveLineDown.HotKey;
  FKeyBindings.SectionToggleUpKey := hkSectionUp.HotKey;
  FKeyBindings.SectionToggleDownKey := hkSectionDown.HotKey;
  FKeybindings.Active := cbxActive.Checked; // => add all active key bindings
  FKeyBindings.Save;
end;

procedure TFrameOptionPageKeybindings.Selected;
begin
end;

procedure TFrameOptionPageKeybindings.Unselected;
begin
end;

{ TKeybindings }

constructor TKeybindings.Create;
begin
  inherited Create(AppDataDirectory + '\KeyBindings.xml', 'KeyBindings');
end;

destructor TKeybindings.Destroy;
begin
  Active := False;
  inherited Destroy;
end;

function TKeybindings.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('Key Bindings', TFrameOptionPageKeybindings, Self);
end;

procedure TKeybindings.Init;
begin
  inherited Init;
  TabIndent := True;
  IndentSingleLine := False;
  ExtendedHome := True;
  ExtendedCtrlLeftRight := False;
  {$IF CompilerVersion <= 20.0}
  ShiftF3 := True;
  {$IFEND}
  MoveLineBlock := True;
  MoveLineBlockUpKey := ShortCut(VK_UP, [ssShift, ssCtrl, ssAlt]);
  MoveLineBlockDownKey := ShortCut(VK_DOWN, [ssShift, ssCtrl, ssAlt]);
  FindDeclOnCaret := True;
  // SectionToggle defaults off. When the feature first shipped it was on and
  // silently shadowed the IDE's native Ctrl+Shift+Up/Down (jump between method
  // declaration and implementation body). Users must now opt in and pick keys.
  SectionToggle := False;
  SectionToggleUpKey := scNone;
  SectionToggleDownKey := scNone;
  Active := True;
end;

procedure TKeybindings.InternCtrlMoveCursor(EditPosition: IOTAEditPosition; InComment: Boolean);
const
  TwoChars: array[0..25] of string = (
    // Common
    '<=', '>=', '//',

    // Delphi
    '<>', ':=', '..', '(*', '*)',

    // C++
    '==', '!=',
    '++', '--', '+=', '-=', '*=', '/=', '~=', '^=', '|=', '&=',
    '&&', '||', '::', '->', '/*', '*/'
  );

var
  EndCol: Integer;
  BufferPos: Integer;
  Buffer: string;
  Ch, StartCh: Char;

  procedure ReadChar;
  begin
    if BufferPos > Length(Buffer) then
    begin
      Buffer := EditPosition.Read(1024);
      BufferPos := 1;
    end;
    if BufferPos > Length(Buffer) then
      Ch := #0
    else
    begin
      Ch := Buffer[BufferPos];
      Inc(BufferPos);
    end;
    //Ch := EditPosition.Character;
  end;

  function StepNext: Boolean;
  begin
    if EditPosition.Column > EndCol then
      Result := False
    else
      Result := EditPosition.MoveRelative(0, 1);
    if Result then
      ReadChar
    else
      Ch := #0;
  end;

  function IsWhiteSpace(Ch: Char): Boolean; inline;
  begin
    Result := (Ch = ' ') or (Ch = #9);
  end;

var
  Ch1: Char;
  I: Integer;
  Handled: Boolean;
begin
  EndCol := GetEndColumn(EditPosition);
  Handled := False;

  BufferPos := 1;
  Buffer := '';
  ReadChar;

  if Ch = '#' then // string-code
  begin
    Handled := True;
    if StepNext then
    begin
      if Ch = '$' then
      begin
        while StepNext and (Ch in ['0'..'9', 'A'..'F', 'a'..'f']) do ; // hex
      end
      else
      begin
        while (Ch in ['0'..'9']) and StepNext do ;
      end;
    end;
  end
  else if Ch in ['0'..'9', '$', '.'] then // number, hex number
  begin
    Handled := True;
    StartCh := Ch;
    if StepNext then
    begin
      if (StartCh = '$') or ((StartCh = '0') and (Ch = 'x')) then // hex
      begin
        while StepNext and (Ch in ['0'..'9', 'A'..'F', 'a'..'f']) do ;
      end
      else if not ((StartCh = '.') and (Ch in ['E', 'e'])) then
      begin
        if (StartCh = '.') and (Ch = '.') then // ".."
          StepNext
        else
        begin  // 1.23e-45
          while (Ch in ['0'..'9']) and StepNext do ; // digit
          if (Ch = '.') then
            StepNext;
          while (Ch in ['0'..'9']) and StepNext do ; // digit
          if Ch in ['E', 'e'] then
          begin
            if StepNext then
            begin
              if Ch in ['-', '+'] then
                StepNext;
            end;
            while (Ch in ['0'..'9']) and StepNext do ; // digit
          end;
        end;
      end;
    end;
  end
  else if (Ch = '_') or IsCharAlphaNumeric(Ch){EditPosition.IsWordCharacter} then
  begin
    Handled := True;
    if StepNext then
    begin
      while (Ch in ['_', '0'..'9']) or IsCharAlphaNumeric(Ch){EditPosition.IsWordCharacter} do
        if not StepNext then
          Break;
    end;
  end;

  if not Handled then
  begin
    if InComment then
    begin
      { Skip whitespaces }
      while (EditPosition.Column < EndCol) and not IsCharAlphaNumeric(Ch) and not IsWhiteSpace(Ch) {EditPosition.IsSpecialCharacter} do
        if not StepNext then
          Break;
    end
    else
    begin
      Ch1 := Ch;
      if StepNext then
      begin
        for I := 0 to High(TwoChars) do
        begin
          if (Ch1 = TwoChars[I][1]) and (Ch = TwoChars[I][2]) then
          begin
            StepNext;
            Break;
          end;
        end
      end;
    end;
  end;

  { Skip whitespaces }
  while (EditPosition.Column < EndCol) and EditPosition.IsWhiteSpace do
    if not StepNext then
      Break;
end;

procedure TKeybindings.CtrlMoveCursor(EditBuffer: IOTAEditBuffer; View: IOTAEditView;
  EditPosition: IOTAEditPosition; ForwardMove: Boolean);

  function IsInComment: Boolean;
  var
    Element, LineFlag: Integer;
  begin
    View.GetAttributeAtPos(View.CursorPos, False, Element, LineFlag);
    Result := Element = atComment;
  end;

var
  CurCol, EndCol, Col, CurRow: Integer;
  OldCol, OldRow: Integer;
  TopLeft: TOTAEditPos;
begin
  EditPosition.Save;
  if EditBuffer <> nil then
    EditBuffer.EditBlock.Save;
  TopLeft := View.TopPos;

  OldCol := EditPosition.Column;
  OldRow := EditPosition.Row;

  CurCol := OldCol;
  EndCol := GetEndColumn(EditPosition); // makes the block invisible

  repeat
    if ForwardMove then
    begin
      if CurCol >= EndCol then
      begin
        if EditPosition.Row < EditPosition.LastRow then
        begin
          EditPosition.Move(EditPosition.Row + 1, 1);
          EndCol := GetEndColumn(EditPosition);
          // skip only whitespaces
          while (EditPosition.Column < EndCol) and EditPosition.IsWhiteSpace do
            if not EditPosition.MoveRelative(0, 1) then
              Break;
        end;
      end
      else
        InternCtrlMoveCursor(EditPosition, IsInComment);
    end
    else
    begin
      if CurCol = 1 then
      begin
        if EditPosition.Row > 1 then
        begin
          EditPosition.Move(EditPosition.Row - 1, 1);
          EditPosition.MoveEOL;
          CurCol := EditPosition.Column;
        end
        else
          Break; // nothing to do
      end
      else
        if CurCol > EndCol then
          CurCol := EndCol;
      { Find the column by stepping from the BOL to the CurCol }
      EditPosition.Move(EditPosition.Row, 1);
      repeat
        Col := EditPosition.Column;
        InternCtrlMoveCursor(EditPosition, IsInComment);
      until EditPosition.Column >= CurCol;
      EditPosition.Move(EditPosition.Row, Col);
    end;
  until True;

  CurRow := EditPosition.Row;
  CurCol := EditPosition.Column;
  EditPosition.Restore;
  View.TopPos := TopLeft;

  if EditBuffer = nil then
    EditPosition.Move(CurRow, CurCol)
  else
  begin
    EditBuffer.EditBlock.Restore;
    EditBuffer.EditBlock.ExtendRelative(CurRow - OldRow, CurCol - OldCol);
  end;
end;

function SkipToNextLine(P: PAnsiChar): PAnsiChar;
begin
  Result := P;
  while True do
  begin
    case Result^ of
      #0:
        Break;
      #10:
        Inc(Result);
      #13:
        begin
          Inc(Result);
          if Result^ = #10 then
            Inc(Result);
          Break;
        end;
    end;
    Inc(Result);
  end;
end;

function GetLenWithoutLastLineBreak(S: UTF8String): Integer;
begin
  Result := Length(S);
  while (Result > 0) and (S[Result] in [#10, #13]) do
    Dec(Result);
end;


const
  emKeepTrailingBlanks = $00000020;
  emOptimalFill        = $00000040;
  emGroupUndo          = $00000100;
  emPersistentBlocks   = $00000200;
  emDisableUndo        = $00000800;

type
  TCharIndex = SmallInt;
  TLineNum = LongInt;

  PCharPos = ^TCharPos;
  TCharPos = packed record
    Index: TCharIndex;
    LineNum: TLineNum;
  end;

  PEdFile = ^TEdFile;
  TEdFile = packed record
    Pos: Longint;
    CharPos: TCharPos;
    MidChar: Boolean;
  end;

  TEdModes = LongWord;
  TEdModFlags = Word;

  PEditorBuffer = ^TEditorBuffer;
  TEditorBuffer = packed record
    NLines: TLineNum;
    ModifyFlags: TEdModFlags;
    EdModes: TEdModes;

    UndoAvailable: Boolean;
    RedoAvailable: Boolean;
    // ...
  end;

  PEkView = ^TEkView;
  TEkView = record
    PrevWin: PEkView;
    NextWin: PEkView;
    ViewData: Pointer;

    Editor: PEditorBuffer;
    // ...
  end;

  TEditWriter = class(TInterfacedObject)
  protected
    EkView: PEkView;
    EdFile: TEdFile;
    FilePos: Longint;
  end;

function SetEkViewEdModes(EkView: PEkView; SetFlags, ClearFlags: TEdModes): Int64;
begin
  Result := 0;
  if SetFlags and emDisableUndo <> 0 then
  begin
    ClearFlags := ClearFlags or emOptimalFill;
    SetFlags := SetFlags or emKeepTrailingBlanks;
  end;

  // Prefer ClearFlags over SetFlags
  SetFlags := SetFlags and not ClearFlags;

  if (EkView <> nil) and (EkView.Editor <> nil) then
  begin
    ULARGE_INTEGER(Result).LowPart := SetFlags and not (EkView.Editor.EdModes and SetFlags);
    ULARGE_INTEGER(Result).HighPart := EkView.Editor.EdModes and ClearFlags;

    EkView.Editor.EdModes := (EkView.Editor.EdModes and not ClearFlags) or SetFlags;
  end;
end;

procedure RestoreEkViewEdModes(EkView: PEkView; RestoreFlags: Int64);
var
  SetFlags, ClearFlags: TEdModes;
begin
  if (EkView <> nil) and (EkView.Editor <> nil) then
  begin
    ClearFlags := ULARGE_INTEGER(RestoreFlags).LowPart;
    SetFlags := ULARGE_INTEGER(RestoreFlags).HighPart;

    // apply in revers to restore the original settings
    EkView.Editor.EdModes := (EkView.Editor.EdModes and not ClearFlags) or SetFlags;
  end;
end;

procedure TKeybindings.MoveLineBlockText(EditBuffer: IOTAEditBuffer; Down: Boolean);
type
  TBlock = record
    Row: Integer;
    Col: Integer;
    StartingRow: Integer;
    EndingRow: Integer;
    StartingColumn: Integer;
    EndingColumn: Integer;
  end;

var
  StartRow, EndRow, LastRow, Row, RowOffset: Integer;
  BlockSize: Integer;
  EditBlock: IOTAEditBlock;
  EditPosition: IOTAEditPosition;
  Source: UTF8String;
  Start, UnchangedP, BlockStart, BlockEnd, AffectedLineP: PAnsiChar;
  Writer: IOTAEditWriter;
  S: UTF8String;
  LastUnchangedRow: Integer;
  Block: TBlock;
  {$IFNDEF CPUX64}
  EkView: PEkView;
  RestoreFlags: Int64;
  EditWriter: TEditWriter;
  {$ENDIF}
begin
  EditPosition := EditBuffer.EditPosition;
  EditBlock := EditBuffer.EditBlock;
  StartRow := EditPosition.Row;
  BlockSize := EditBlock.Size;

  Block.Row := EditPosition.Row;
  Block.Col := EditPosition.Column;
  Block.StartingRow := EditBlock.StartingRow;
  Block.EndingRow := EditBlock.EndingRow;
  Block.StartingColumn := EditBlock.StartingColumn;
  Block.EndingColumn := EditBlock.EndingColumn;

  if (BlockSize <> 0) and (EditBlock.Style = btColumn) then
  begin
    // EditBlock.Starting*/Ending* are wrong in this mode, stick to moving one line
    Block.StartingRow := Block.Row;
    Block.EndingRow := Block.Row;
    BlockSize := 0;
  end;
  // If only the caret is in the last line and first column than ignore that line.
  if (BlockSize > 0) and (Block.EndingRow > Block.StartingRow) and (Block.EndingColumn = 1) then
  begin
    if Block.Row = Block.EndingRow then
      Dec(Block.Row);
    Dec(Block.EndingRow);
  end;

  LastRow := EditBuffer.GetLinesInBuffer;
  if BlockSize = 0 then
    EndRow := StartRow
  else
  begin
    StartRow := Block.StartingRow;
    EndRow := Block.EndingRow;
  end;

  // MoveUp on first line is not allowed. MoveUp/Down is not allowed on the last line because it doesn't work and Delphi inserts #13#10 where it wants
  if (not Down and ((StartRow <= 1) or (EndRow >= LastRow))) or (Down and (EndRow >= LastRow - 1)) then
    Exit;

  Source := GetEditorSource(EditBuffer);
  UnchangedP := PAnsiChar(Source);
  Start := UnchangedP;
  LastUnchangedRow := StartRow;
  if not Down then
    Dec(LastUnchangedRow);
  Row := 1;
  while (UnchangedP^ <> #0) and (Row < LastUnchangedRow) do
  begin
    UnchangedP := SkipToNextLine(UnchangedP);
    Inc(Row);
  end;

  if Row = LastUnchangedRow then
  begin
    BlockStart :=  UnchangedP;
    if not Down then // we skippt the unchanged line
    begin
      BlockStart := SkipToNextLine(BlockStart);
      Inc(Row);
    end;
    BlockEnd := BlockStart;
    while (BlockEnd^ <> #0) and (Row <= EndRow) do
    begin
      BlockEnd := SkipToNextLine(BlockEnd);
      Inc(Row);
    end;

    AffectedLineP := nil;
    if Down then
      AffectedLineP := SkipToNextLine(BlockEnd);

    SetString(S, BlockStart, BlockEnd - BlockStart);

    Writer := EditBuffer.CreateUndoableWriter;
    {$IFNDEF CPUX64}
    // Acquire the IDE-internal EkView by hand-casting the IOTAEditWriter to the
    // replica TEditWriter, whose fields sit at fixed 32-bit offsets. On Win64 the
    // 8-byte pointer fields shift every offset, so this cast and the EdModes
    // poking below are skipped; the block move itself uses only the documented
    // IOTAEditWriter API and stays correct (only undo grouping / persistent-block
    // restoration is degraded on x64).
    EditWriter := TEditWriter(DelphiInterfaceToObject(Writer));
    if not EditWriter.ClassNameIs('TEditWriter') then
      raise Exception.CreateFmt('EditBuffer (%s) is not of type TEditWriter', [EditWriter.ClassName]);
    EkView := EditWriter.EkView;
    {$ENDIF}

    // Copy unaffected part
    Writer.CopyTo(UnchangedP - Start);
    if Down then
    begin
      // Delete moved block
      Writer.DeleteTo(BlockEnd - Start);
      // Copy line that was moved up due to the moved block
      Writer.CopyTo(AffectedLineP - Start);
    end;

    // Insert moved block
    Writer.Insert(PAnsiChar(S));

    if not Down then
    begin
      // Copy line that was moved down due to the moved block
      Writer.CopyTo(BlockStart - Start);
      // Delete moved block
      Writer.DeleteTo(BlockEnd - Start);
    end;
    // Copy unaffected part
    Writer.CopyTo(Length(Source));
    Writer := nil; // end undo group

    if Down then
      RowOffset := 1
    else
      RowOffset := -1;

    {$IFNDEF CPUX64}
    RestoreFlags := SetEkViewEdModes(EkView, emDisableUndo or emPersistentBlocks, 0);
    try
    {$ENDIF}
      if BlockSize = 0 then
        EditPosition.Move(Block.Row + RowOffset, 0)
      else
      begin
        EditBlock.Reset;
        EditBlock.Style := btNonInclusive;

        //PersistentBlocks := EditBuffer.BufferOptions.PersistentBlocks;
        try
          //EditBuffer.BufferOptions.PersistentBlocks := True;
          EditPosition.Move(Block.StartingRow + RowOffset, 1);
          EditBlock.BeginBlock;
          try
            EditPosition.Move(Block.EndingRow + 1 + RowOffset, 1);
            //EditPosition.MoveEOL;
          finally
            EditBlock.EndBlock;
          end;
          EditPosition.Move(Block.StartingRow + RowOffset, 1);
        finally
          //EditBuffer.BufferOptions.PersistentBlocks := PersistentBlocks;
        end;
      end;
    {$IFNDEF CPUX64}
    finally
      RestoreEkViewEdModes(EkView, RestoreFlags);
    end;
    {$ENDIF}
  end;
end;

(*
procedure TKeybindings.ReturnPressed(EditBuffer: IOTAEditBuffer);
var
  TopLeft: TOTAEditPos;
  EditPosition: IOTAEditPosition;
  EndCol: Integer;
  NeedIndention: Boolean;
  Ch: Char;

  function StepBack: Boolean;
  begin
    Result := EditPosition.MoveRelative(0, -1);
  end;

var
  Element, LineFlag: Integer;
  Text: string;
begin
  EditPosition := EditBuffer.EditPosition;
  EditPosition.Save;
  TopLeft := EditBuffer.TopView.TopPos;
  EndCol := GetEndColumn(EditPosition);

  NeedIndention := False;
  if (EditPosition.Column >= EndCol) and (EditPosition.Column > 1) then
  begin
    while EditPosition.IsSpecialCharacter and StepBack do ; // skip whitespaces
    while EditPosition.IsWhiteSpace and StepBack do ; // skip whitespaces

    NeedIndention := True;
    //EditBuffer.TopView.GetAttributeAtPos(EditBuffer.TopView.CursorPos, False, Element, LineFlag);
    if EditPosition.Character = ';' then
    begin
      EditPosition.MoveRelative(0, -1);
      while EditPosition.IsWhiteSpace and StepBack do ; // skip whitespaces

      // If it is "end", we have to indent it correctly
      EditPosition.MoveRelative(0, -3);
      Text := EditPosition.Read(3);
      if SameText(Text, 'end') then
      begin

      end;
    end;

  end;
  EditPosition.Restore;
  EditBuffer.TopView.TopPos := TopLeft;

  EditPosition.InsertCharacter(#13);
  {if NeedIndention then
    EditBuffer.EditBlock.Indent(1);}
end;*)

procedure TKeybindings.DoKeyBinding(const Context: IOTAKeyContext; KeyCode: TShortcut;
  var BindingResult: TKeyBindingResult);

  function GetIndentSize: Integer;
  begin
    Result := (BorlandIDEServices as IOTAEditorServices).EditOptions.BlockIndent;
  end;

var
  EditPosition: IOTAEditPosition;
  EditBuffer: IOTAEditBuffer;
  EditBlock: IOTAEditBlock;
  Column: Integer;
  BindingRec: TKeyBindingRec;
  {$IF CompilerVersion <= 20.0}
  SearchForwardEnvProp: TPropField;
  OldSearchForwardValue: Boolean;
  {$IFEND}
begin
  BindingResult := krUnhandled;

  EditBuffer := Context.EditBuffer;
  if EditBuffer <> nil then
  begin
    EditPosition := EditBuffer.EditPosition;
    if Active then
    begin
      EditBlock := EditBuffer.EditBlock;
      if (EditBlock <> nil) and (EditBlock.Size > 0) then
      begin
        if TabIndent and (KeyCode = ShortCut(VK_TAB, [])) then
        begin
          if (IndentSingleLine or (EditBlock.StartingRow <> EditBlock.EndingRow)) then // un/indent only if a line break is included in the block
            EditBlock.Indent(GetIndentSize)
          else
            EditPosition.InsertCharacter(#9); // Delphi 2010 always uses "IndentSingleLine"
          BindingResult := krHandled;
        end
        else
        if TabIndent and (KeyCode = ShortCut(VK_TAB, [ssShift])) then
        begin
          if (IndentSingleLine or (EditBlock.StartingRow <> EditBlock.EndingRow)) then // un/indent only if a line break is included in the block
            EditBlock.Indent(-GetIndentSize)
          else
            EditPosition.Tab(-1);
          BindingResult := krHandled;
        end;
      end;

      if BindingResult <> krHandled then
      begin
        if ExtendedHome and (KeyCode = ShortCut(VK_HOME, [])) then
        begin
          if SwitchedExtendedHome and (EditPosition.Column > 1) then
          begin
            { First jump to the first non-whitespace and then to the BOL }
            Column := EditPosition.Column;
            EditPosition.MoveBOL;
            while (EditPosition.Character in [#9, ' ']) and EditPosition.MoveRelative(0, 1) do
              ;
            if EditPosition.Column = Column then
              EditPosition.MoveBOL;
            BindingResult := krHandled;
          end
          else
          begin
            { First jump to the BOL and then to the first non-whitespace }
            if EditPosition.Column = 1 then
            begin
              while (EditPosition.Character in [#9, ' ']) and EditPosition.MoveRelative(0, 1) do
                ;
              BindingResult := krHandled;
            end;
          end;
        end

        else if (KeyCode = ShortCut(VK_RIGHT, [ssCtrl])) or
                (KeyCode = ShortCut(VK_LEFT, [ssCtrl])) then
        begin
          CtrlMoveCursor(nil, EditBuffer.TopView, EditPosition, Byte(KeyCode) = VK_RIGHT{, IsPascalFile(EditBuffer.FileName)});
          BindingResult := krHandled;
        end
        else if (KeyCode = ShortCut(VK_RIGHT, [ssCtrl, ssShift])) or
                (KeyCode = ShortCut(VK_LEFT, [ssCtrl, ssShift])) then
        begin
          CtrlMoveCursor(EditBuffer, EditBuffer.TopView, EditPosition, Byte(KeyCode) = VK_RIGHT{, IsPascalFile(EditBuffer.FileName)});
          BindingResult := krHandled;
        end

        else if MoveLineBlock and (FMoveLineBlockUpKey <> scNone) and (KeyCode = FMoveLineBlockUpKey) then
        begin
          MoveLineBlockText(EditBuffer, False);
          BindingResult := krHandled;
        end
        else if MoveLineBlock and (FMoveLineBlockDownKey <> scNone) and (KeyCode = FMoveLineBlockDownKey) then
        begin
          MoveLineBlockText(EditBuffer, True);
          BindingResult := krHandled;
        end

        else if KeyCode = ShortCut(VK_PRIOR, [ssCtrl, ssAlt]) then
        begin
          FindDeclaration(EditBuffer);
          BindingResult := krHandled;
        end

        else if SectionToggle and (FSectionToggleUpKey <> scNone) and (KeyCode = FSectionToggleUpKey) then
        begin
          ToggleSection(EditBuffer);
          BindingResult := krHandled;
        end
        else if SectionToggle and (FSectionToggleDownKey <> scNone) and (KeyCode = FSectionToggleDownKey) then
        begin
          ToggleSection(EditBuffer);
          BindingResult := krHandled;
        end;


        {else if KeyCode = ShortCut(VK_RETURN, []) then
        begin
          ReturnPressed(EditBuffer);
          BindingResult := krHandled;
        end;}
      end;

      {$IF CompilerVersion <= 20.0} // Delphi 2009- (Delphi 2010 introduced Shift-F3)
      if BindingResult <> krHandled then
      begin
        if ShiftF3 and (KeyCode = ShortCut(VK_F3, [ssShift])) then
        begin
          if (Screen.ActiveControl <> nil) and (Screen.ActiveControl.Name = 'Editor') and
             Screen.ActiveControl.ClassNameIs('TEditControl') then
          begin
            SearchForwardEnvProp := TPropField((TObject(PPointer(GetActualAddr(@EnvironmentOptionsAddr))^) as TComponent).FindComponent('SearchForward'));
            if SearchForwardEnvProp <> nil then
            begin
              OldSearchForwardValue := SearchForwardEnvProp.Value;
              try
                SearchForwardEnvProp.Value := not OldSearchForwardValue;
                TCustomEditControl_RepeatSearch(Screen.ActiveControl);
              finally
                SearchForwardEnvProp.Value := OldSearchForwardValue;
              end;
              BindingResult := krHandled;
            end;
          end;
        end;
      end;
      {$IFEND}
    end;

    if BindingResult = krUnhandled then
    begin
      if Context.GetKeyBindingRec(BindingRec) and Context.KeyboardServices.GetNextBindingRec(BindingRec) then
      begin
        { Let the next proc struggle with the IDE }
        BindingResult := krNextProc;
        Exit;
      end;

      { The HOME key isn't processed when bound to a method }
      if KeyCode = ShortCut(VK_HOME, []) then
      begin
        EditPosition.MoveBOL;
        BindingResult := krHandled;
      end
      else
      if KeyCode = ShortCut(VK_TAB, [ssShift]) then
      begin
        { The Shift-TAB key isn't processed when bound to a method }
        EditPosition.Tab(-1);
        BindingResult := krHandled;
      end
      else
      if KeyCode = ShortCut(VK_TAB, []) then
      begin
        { The TAB key isn't processed when bound to a method }
        if not (BorlandIDEServices as IOTAEditorServices).EditOptions.BufferOptions.SmartTab then
        begin
          EditPosition.InsertCharacter(#9);
          BindingResult := krHandled;
        end
        else
        begin
          EditPosition.Align(1);
          BindingResult := krHandled;
        end;
      end;
    end;
  end;
end;

procedure TKeybindings.FindDeclaration(EditBuffer: IOTAEditBuffer);
var
  DataModule: TDataModule;
  FindDecl: TComponent;
  EditCtrl: TWinControl;
begin
  DataModule := TDataModule(GetActualAddr(@EditorActionListsPtr)^);
  if DataModule <> nil then
  begin
    FindDecl := DataModule.FindComponent('FindDeclaration');
    if FindDecl is TAction then
    begin
      EditCtrl := Screen.ActiveControl;
      if (EditCtrl <> nil) and (EditCtrl.Name = 'Editor') and EditCtrl.ClassNameIs('TEditControl') then
      begin
        TAction(FindDecl).ActionList.Tag := NativeInt(EditCtrl);
        TAction(FindDecl).Execute;
      end;
    end;
  end;
end;

procedure TKeybindings.ToggleSection(EditBuffer: IOTAEditBuffer);
var
  Source: UTF8String;
  EditPosition: IOTAEditPosition;
  CurrentRow: Integer;
  InterfaceRow, ImplementationRow: Integer;
  P: PAnsiChar;
  LineNum: Integer;
  InInterface: Boolean;
  TargetRow: Integer;

  function SkipWhitespace(P: PAnsiChar): PAnsiChar;
  begin
    Result := P;
    while Result^ in [' ', #9] do
      Inc(Result);
  end;

  function MatchKeyword(P: PAnsiChar; const Keyword: AnsiString): Boolean;
  var
    Len: Integer;
  begin
    Len := Length(Keyword);
    Result := (AnsiStrings.StrLIComp(P, PAnsiChar(Keyword), Len) = 0) and
              not (P[Len] in ['A'..'Z', 'a'..'z', '0'..'9', '_']);
  end;

begin
  if EditBuffer = nil then
    Exit;

  Source := GetEditorSource(EditBuffer);
  if Source = '' then
    Exit;

  EditPosition := EditBuffer.EditPosition;
  CurrentRow := EditPosition.Row;

  // Find interface and implementation line numbers
  InterfaceRow := 0;
  ImplementationRow := 0;
  P := PAnsiChar(Source);
  LineNum := 1;

  while P^ <> #0 do
  begin
    // Skip to start of line content
    P := SkipWhitespace(P);

    // Check for interface keyword (not 'interface' as type modifier)
    if (InterfaceRow = 0) and MatchKeyword(P, 'interface') then
    begin
      // Make sure it's not inside a type declaration (check if previous non-space is '=')
      // Simple check: interface at start of line or after only whitespace
      InterfaceRow := LineNum;
    end
    else if MatchKeyword(P, 'implementation') then
    begin
      ImplementationRow := LineNum;
      Break; // We have both, no need to continue
    end;

    // Skip to next line
    while (P^ <> #0) and (P^ <> #10) and (P^ <> #13) do
      Inc(P);
    if P^ = #13 then
      Inc(P);
    if P^ = #10 then
      Inc(P);
    Inc(LineNum);
  end;

  // If we didn't find both sections, nothing to do
  if (InterfaceRow = 0) or (ImplementationRow = 0) then
    Exit;

  // Determine current section and target
  InInterface := CurrentRow < ImplementationRow;

  if InInterface then
    TargetRow := ImplementationRow + 1  // Jump to implementation
  else
    TargetRow := InterfaceRow + 1;      // Jump to interface

  // Move cursor
  EditPosition.Move(TargetRow, 1);
  EditBuffer.TopView.MoveViewToCursor;
end;

procedure TKeybindings.BindKeyboard(const BindingServices: IOTAKeyBindingServices);
begin
  if TabIndent then
  begin
    BindingServices.AddKeyBinding([ShortCut(VK_TAB, [ssShift])], DoKeyBinding, nil, 0);
    BindingServices.AddKeyBinding([ShortCut(VK_TAB, [])], DoKeyBinding, nil, 0);
  end;

  if ExtendedHome then
  begin
    BindingServices.AddKeyBinding([ShortCut(VK_HOME, [])], DoKeyBinding, nil, 0);
  end;

  if ExtendedCtrlLeftRight then
  begin
    BindingServices.AddKeyBinding([ShortCut(VK_RIGHT, [ssCtrl])], DoKeyBinding, nil, 0);
    BindingServices.AddKeyBinding([ShortCut(VK_RIGHT, [ssCtrl, ssShift])], DoKeyBinding, nil, 0);
    BindingServices.AddKeyBinding([ShortCut(VK_LEFT, [ssCtrl])], DoKeyBinding, nil, 0);
    BindingServices.AddKeyBinding([ShortCut(VK_LEFT, [ssCtrl, ssShift])], DoKeyBinding, nil, 0);
  end;

  //BindingServices.AddKeyBinding([ShortCut(VK_RETURN, [])], DoKeyBinding, nil, 0);

  {$IF CompilerVersion <= 20.0}
  if ShiftF3 then
  begin
    BindingServices.AddKeyBinding([ShortCut(VK_F3, [ssShift])], DoKeyBinding, nil, 0);
  end;
  {$IFEND}

  if MoveLineBlock then
  begin
    if FMoveLineBlockUpKey <> scNone then
      BindingServices.AddKeyBinding([FMoveLineBlockUpKey], DoKeyBinding, nil, 0);
    if FMoveLineBlockDownKey <> scNone then
      BindingServices.AddKeyBinding([FMoveLineBlockDownKey], DoKeyBinding, nil, 0);
  end;

  if FindDeclOnCaret then
  begin
    BindingServices.AddKeyBinding([ShortCut(VK_PRIOR, [ssCtrl, ssAlt])], DoKeyBinding, nil, 0);
  end;

  if SectionToggle then
  begin
    if FSectionToggleUpKey <> scNone then
      BindingServices.AddKeyBinding([FSectionToggleUpKey], DoKeyBinding, nil, 0);
    if FSectionToggleDownKey <> scNone then
      BindingServices.AddKeyBinding([FSectionToggleDownKey], DoKeyBinding, nil, 0);
  end;

end;

function TKeybindings.GetBindingType: TBindingType;
begin
  Result := btPartial;
end;

function TKeybindings.GetDisplayName: string;
begin
  Result := 'DDevExtensions KeyBindings';
end;

function TKeybindings.GetName: string;
begin
  Result := 'DDevExtensions.KeyBindings';
end;

procedure TKeybindings.AfterSave;
begin
end;

procedure TKeybindings.BeforeSave;
begin
end;

procedure TKeybindings.Destroyed;
begin
end;

procedure TKeybindings.Modified;
begin
end;

procedure TKeybindings.SetActive(const Value: Boolean);
begin
  if Value <> FActive then
  begin
    if FActive then
    begin
      if FNotifierIndex >= 0 then
        (BorlandIDEServices as IOTAKeyboardServices).RemoveKeyboardBinding(FNotifierIndex);
      FNotifierIndex := -1;
    end;
    FActive := Value;
    if FActive then
      FNotifierIndex := (BorlandIDEServices as IOTAKeyboardServices).AddKeyboardBinding(Self);
    if not Application.Terminated then
      (BorlandIDEServices as IOTAKeyboardServices).RestartKeyboardServices;
  end;
end;

procedure TKeybindings.Loaded;
begin
  inherited Loaded;
  if Active then
  begin
    Active := False;
    Active := True;
  end;
end;

end.
