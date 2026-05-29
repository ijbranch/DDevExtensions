{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit EmptyEventHandlerDetector;

/// <summary>
/// DDevExtensions plugin that scans Pascal sources for VCL/FMX event-handler methods whose body
/// contains only <c>begin..end</c> with no real statements. Such handlers are typically left over
/// from form designer experiments and clutter the codebase.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, Vcl.Menus, ToolsAPI, PluginConfig, FrmTreePages,
  FrmeOptionPageEmptyHandler;

type
  /// <summary>Description of one empty event handler discovered during analysis.</summary>
  TEmptyHandlerInfo = record
    /// <summary>Bare unit name (without extension).</summary>
    UnitName: string;
    /// <summary>Method name as written in the source.</summary>
    MethodName: string;
    /// <summary>Owning class name (or empty for unit-scope routines).</summary>
    ClassName: string;
    /// <summary>One-based line number of the method declaration.</summary>
    LineNumber: Integer;
    /// <summary>Absolute path of the source file.</summary>
    FileName: string;
  end;

  /// <summary>
  /// Plugin host for the Empty Event Handler Detector. Adds a menu item to DDevExtensions and
  /// exposes the static <see cref="AnalyzeUnit"/> entry point used by the result form.
  /// </summary>
  TEmptyEventHandlerDetectorPlugin = class(TPluginConfig)
  private
    /// <summary>Menu item added to the DDevExtensions submenu.</summary>
    FMenuItem: TMenuItem;
    /// <summary>Master enable flag for the plugin.</summary>
    FEnabled: Boolean;
    /// <summary>Menu OnClick handler that opens the result form.</summary>
    procedure MenuItemClick(Sender: TObject);
  protected
    /// <summary>Returns the option page used in the IDE options dialog.</summary>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises configuration to its built-in defaults.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the plugin and registers its menu item.</summary>
    constructor Create;
    /// <summary>Removes the menu item and releases the plugin.</summary>
    destructor Destroy; override;

    /// <summary>
    /// Lexes <paramref name="Source"/> looking for routines whose name matches a VCL/FMX event
    /// suffix (<c>Click</c>, <c>Change</c>, <c>Create</c>, ...) and whose body contains no real
    /// statements.
    /// </summary>
    /// <param name="Source">UTF-8 source text.</param>
    /// <param name="FileName">Absolute path of the source file (used for report metadata).</param>
    /// <returns>Array of <see cref="TEmptyHandlerInfo"/> values; empty when none are found.</returns>
    class function AnalyzeUnit(const Source: UTF8String; const FileName: string): TArray<TEmptyHandlerInfo>;
  published
    /// <summary>Persisted master enable flag.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

var
  /// <summary>Singleton plugin instance.</summary>
  EmptyEventHandlerDetectorPlugin: TEmptyEventHandlerDetectorPlugin;

/// <summary>
/// Plugin lifecycle entry point — creates or releases <see cref="EmptyEventHandlerDetectorPlugin"/>.
/// </summary>
/// <param name="Unload"><c>True</c> to release the plugin, <c>False</c> to create it.</param>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  Winapi.Windows, Vcl.Forms, Vcl.Dialogs, System.Generics.Collections, Main, IDENotifiers,
  ToolsAPIHelpers, DelphiLexer, FrmEmptyEventHandlerDetector;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    EmptyEventHandlerDetectorPlugin := TEmptyEventHandlerDetectorPlugin.Create
  else
    FreeAndNil(EmptyEventHandlerDetectorPlugin);
end;

{ TEmptyEventHandlerDetectorPlugin }

constructor TEmptyEventHandlerDetectorPlugin.Create;
begin
  inherited Create(AppDataDirectory + '\EmptyEventHandlerDetector.xml', 'EmptyEventHandlerDetector');

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem := TMenuItem.Create(DDevExtensionsMenu);
    FMenuItem.Caption := 'Empty Event &Handler Detector...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add(FMenuItem);
  end;
end;

destructor TEmptyEventHandlerDetectorPlugin.Destroy;
begin
  FreeAndNil(FMenuItem);
  inherited Destroy;
end;

function TEmptyEventHandlerDetectorPlugin.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('Empty Event Handler', TFrameOptionPageEmptyHandler, Self);
end;

procedure TEmptyEventHandlerDetectorPlugin.Init;
begin
  inherited Init;
  FEnabled := True;
end;

procedure TEmptyEventHandlerDetectorPlugin.MenuItemClick(Sender: TObject);
begin
  if not Enabled then
  begin
    ShowMessage('Empty Event Handler Detector is disabled. Enable it in DDevExtensions options.');
    Exit;
  end;

  TFormEmptyEventHandlerDetector.Execute;
end;

class function TEmptyEventHandlerDetectorPlugin.AnalyzeUnit(const Source: UTF8String;
  const FileName: string): TArray<TEmptyHandlerInfo>;
var
  Lexer: TDelphiLexer;
  Token: TToken;
  Results: TList<TEmptyHandlerInfo>;
  Info: TEmptyHandlerInfo;
  InImplementation: Boolean;
  InMethodBody: Boolean;
  CurrentClassName: string;
  CurrentMethodName: string;
  MethodStartLine: Integer;
  BeginCount: Integer;
  HasStatements: Boolean;
  SawSender: Boolean;

  function IsEventHandlerName(const Name: string): Boolean;
  var
    LowerName: string;
    Len: Integer;
  begin
    // Event handlers typically have patterns like:
    // Button1Click, FormCreate, Edit1Change, Timer1Timer, etc.
    // Must end with the event suffix, not just contain it anywhere.
    LowerName := LowerCase(Name);
    Len := Length(LowerName);
    Result := False;

    // Check for common event handler suffixes (must be at end of name)
    if (Len >= 5) and (Copy(LowerName, Len - 4, 5) = 'click') then Result := True
    else if (Len >= 8) and (Copy(LowerName, Len - 7, 8) = 'dblclick') then Result := True
    else if (Len >= 6) and (Copy(LowerName, Len - 5, 6) = 'change') then Result := True
    else if (Len >= 6) and (Copy(LowerName, Len - 5, 6) = 'create') then Result := True
    else if (Len >= 7) and (Copy(LowerName, Len - 6, 7) = 'destroy') then Result := True
    else if (Len >= 4) and (Copy(LowerName, Len - 3, 4) = 'show') then Result := True
    else if (Len >= 4) and (Copy(LowerName, Len - 3, 4) = 'hide') then Result := True
    else if (Len >= 5) and (Copy(LowerName, Len - 4, 5) = 'close') then Result := True
    else if (Len >= 8) and (Copy(LowerName, Len - 7, 8) = 'activate') then Result := True
    else if (Len >= 10) and (Copy(LowerName, Len - 9, 10) = 'deactivate') then Result := True
    else if (Len >= 5) and (Copy(LowerName, Len - 4, 5) = 'enter') then Result := True
    else if (Len >= 4) and (Copy(LowerName, Len - 3, 4) = 'exit') then Result := True
    else if (Len >= 7) and (Copy(LowerName, Len - 6, 7) = 'keydown') then Result := True
    else if (Len >= 5) and (Copy(LowerName, Len - 4, 5) = 'keyup') then Result := True
    else if (Len >= 8) and (Copy(LowerName, Len - 7, 8) = 'keypress') then Result := True
    else if (Len >= 9) and (Copy(LowerName, Len - 8, 9) = 'mousedown') then Result := True
    else if (Len >= 7) and (Copy(LowerName, Len - 6, 7) = 'mouseup') then Result := True
    else if (Len >= 9) and (Copy(LowerName, Len - 8, 9) = 'mousemove') then Result := True
    else if (Len >= 5) and (Copy(LowerName, Len - 4, 5) = 'timer') then Result := True
    else if (Len >= 5) and (Copy(LowerName, Len - 4, 5) = 'paint') then Result := True
    else if (Len >= 6) and (Copy(LowerName, Len - 5, 6) = 'resize') then Result := True
    else if (Len >= 6) and (Copy(LowerName, Len - 5, 6) = 'scroll') then Result := True
    else if (Len >= 7) and (Copy(LowerName, Len - 6, 7) = 'execute') then Result := True
    else if (Len >= 6) and (Copy(LowerName, Len - 5, 6) = 'update') then Result := True
    else if (Len >= 8) and (Copy(LowerName, Len - 7, 8) = 'validate') then Result := True
    else if (Len >= 6) and (Copy(LowerName, Len - 5, 6) = 'notify') then Result := True;
    // Note: Removed 'action' - too broad, catches GetTerminateActionText etc.
    // Action handlers end with 'Execute' or 'Update' which are already covered.
  end;

begin
  Results := TList<TEmptyHandlerInfo>.Create;
  try
    Lexer := TDelphiLexer.Create('', Source);
    try
      InImplementation := False;
      InMethodBody := False;
      CurrentClassName := '';
      CurrentMethodName := '';
      MethodStartLine := 0;
      BeginCount := 0;
      HasStatements := False;

      while Lexer.NextToken(Token) do
      begin
        // Track implementation section
        if Token.Kind = tkI_implementation then
        begin
          InImplementation := True;
          Continue;
        end;

        if not InImplementation then
          Continue;

        // Look for procedure/function definitions
        if not InMethodBody and (Token.Kind in [tkI_procedure, tkI_function]) then
        begin
          // Record the line of the procedure/function keyword itself so navigation
          // lands on the declaration's first line even when the name wraps onto a
          // following line (Token.Line is 0-based, convert to 1-based).
          MethodStartLine := Token.Line + 1;

          // Get the method name (might be ClassName.MethodName)
          if Lexer.NextToken(Token) and (Token.Kind >= tkIdent) then
          begin
            CurrentClassName := '';
            CurrentMethodName := string(Token.Value);

            // Check for ClassName.MethodName pattern
            if Lexer.NextToken(Token) then
            begin
              if Token.Kind = tkQualifier then
              begin
                CurrentClassName := CurrentMethodName;
                if Lexer.NextToken(Token) and (Token.Kind >= tkIdent) then
                  CurrentMethodName := string(Token.Value);
              end;
            end;

            // Check if this looks like an event handler
            if IsEventHandlerName(CurrentMethodName) then
            begin
              SawSender := False;
              // Skip to the begin. Require a 'Sender' parameter in the signature
              // (a genuine VCL event handler) so ordinary methods that merely end
              // in a common word (DoExit, ForceClose, RefreshUpdate, ...) are not
              // misreported as empty event handlers.
              while Lexer.NextToken(Token) do
              begin
                if (Token.Kind >= tkIdent) and SameText(string(Token.Value), 'Sender') then
                  SawSender := True
                else if Token.Kind = tkI_begin then
                begin
                  if SawSender then
                  begin
                    InMethodBody := True;
                    BeginCount := 1;
                    HasStatements := False;
                  end;
                  Break;
                end
                else if Token.Kind in [tkI_procedure, tkI_function, tkI_implementation,
                                       tkI_initialization, tkI_finalization] then
                begin
                  // Another declaration before begin - forward declaration or similar
                  Break;
                end;
              end;
            end;
          end;
        end
        else if InMethodBody then
        begin
          case Token.Kind of
            tkI_begin:
              Inc(BeginCount);

            tkI_case, tkI_try:
              begin
                Inc(BeginCount);
                // case and try are actual statements - method is not empty
                if BeginCount >= 2 then  // a case/try block anywhere in the body
                  HasStatements := True;
              end;

            tkI_end:
              begin
                Dec(BeginCount);
                if BeginCount = 0 then
                begin
                  // Method ended
                  if not HasStatements then
                  begin
                    // This is an empty event handler!
                    Info.UnitName := ChangeFileExt(ExtractFileName(FileName), '');
                    Info.MethodName := CurrentMethodName;
                    Info.ClassName := CurrentClassName;
                    Info.LineNumber := MethodStartLine;
                    Info.FileName := FileName;
                    Results.Add(Info);
                  end;
                  InMethodBody := False;
                  CurrentClassName := '';
                  CurrentMethodName := '';
                end;
              end;

            tkString, tkInt, tkFloat:
              begin
                // These indicate actual code content
                if BeginCount >= 1 then
                  HasStatements := True;
              end;

            tkI_if, tkI_for, tkI_while, tkI_repeat, tkI_with, tkI_raise,
            tkI_goto, tkI_asm, tkI_inherited:
              begin
                // Control flow statements
                if BeginCount >= 1 then
                  HasStatements := True;
              end;

            tkAssign, tkPlus, tkMinus, tkMultiply, tkDivide:
              begin
                // Operators indicate actual code
                if BeginCount >= 1 then
                  HasStatements := True;
              end;
          else
            // Check for identifiers that are not just the method name
            if (Token.Kind >= tkIdent) and (BeginCount >= 1) then
            begin
              // Check if it's a statement keyword by value
              if SameText(string(Token.Value), 'Exit') or
                 SameText(string(Token.Value), 'Break') or
                 SameText(string(Token.Value), 'Continue') or
                 SameText(string(Token.Value), 'Abort') or
                 SameText(string(Token.Value), 'Halt') then
                HasStatements := True
              else if not SameText(string(Token.Value), 'end') then
                HasStatements := True;
            end;
          end;
        end;
      end;
    finally
      Lexer.Free;
    end;

    Result := Results.ToArray;
  finally
    Results.Free;
  end;
end;

end.
