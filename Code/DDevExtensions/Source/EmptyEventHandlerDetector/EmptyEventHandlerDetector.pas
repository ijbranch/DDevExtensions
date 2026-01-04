{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit EmptyEventHandlerDetector;

{$I ..\DelphiExtension.inc}

interface

uses
  SysUtils, Classes, Menus, ToolsAPI, PluginConfig, FrmTreePages,
  FrmeOptionPageEmptyHandler;

type
  TEmptyHandlerInfo = record
    UnitName: string;
    MethodName: string;
    ClassName: string;
    LineNumber: Integer;
    FileName: string;
  end;

  TEmptyEventHandlerDetectorPlugin = class(TPluginConfig)
  private
    FMenuItem: TMenuItem;
    FEnabled: Boolean;
    procedure MenuItemClick(Sender: TObject);
  protected
    function GetOptionPages: TTreePage; override;
    procedure Init; override;
  public
    constructor Create;
    destructor Destroy; override;

    class function AnalyzeUnit(const Source: UTF8String; const FileName: string): TArray<TEmptyHandlerInfo>;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

var
  EmptyEventHandlerDetectorPlugin: TEmptyEventHandlerDetectorPlugin;

procedure InitPlugin(Unload: Boolean);

implementation

uses
  Windows, Forms, Dialogs, Generics.Collections, Main, IDENotifiers,
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

  function IsEventHandlerName(const Name: string): Boolean;
  var
    LowerName: string;
  begin
    // Event handlers typically have patterns like:
    // Button1Click, FormCreate, Edit1Change, Timer1Timer, etc.
    LowerName := LowerCase(Name);
    Result := (Pos('click', LowerName) > 0) or
              (Pos('change', LowerName) > 0) or
              (Pos('create', LowerName) > 0) or
              (Pos('destroy', LowerName) > 0) or
              (Pos('show', LowerName) > 0) or
              (Pos('hide', LowerName) > 0) or
              (Pos('close', LowerName) > 0) or
              (Pos('activate', LowerName) > 0) or
              (Pos('deactivate', LowerName) > 0) or
              (Pos('enter', LowerName) > 0) or
              (Pos('exit', LowerName) > 0) or
              (Pos('keydown', LowerName) > 0) or
              (Pos('keyup', LowerName) > 0) or
              (Pos('keypress', LowerName) > 0) or
              (Pos('mousedown', LowerName) > 0) or
              (Pos('mouseup', LowerName) > 0) or
              (Pos('mousemove', LowerName) > 0) or
              (Pos('dblclick', LowerName) > 0) or
              (Pos('timer', LowerName) > 0) or
              (Pos('paint', LowerName) > 0) or
              (Pos('resize', LowerName) > 0) or
              (Pos('scroll', LowerName) > 0) or
              (Pos('execute', LowerName) > 0) or
              (Pos('update', LowerName) > 0) or
              (Pos('validate', LowerName) > 0) or
              (Pos('notify', LowerName) > 0) or
              (Pos('action', LowerName) > 0);
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
          // Get the method name (might be ClassName.MethodName)
          if Lexer.NextToken(Token) and (Token.Kind >= tkIdent) then
          begin
            CurrentClassName := '';
            CurrentMethodName := string(Token.Value);
            MethodStartLine := Token.Line + 1;  // Token.Line is 0-based, convert to 1-based

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
              // Skip to the begin
              while Lexer.NextToken(Token) do
              begin
                if Token.Kind = tkI_begin then
                begin
                  InMethodBody := True;
                  BeginCount := 1;
                  HasStatements := False;
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
            tkI_begin, tkI_case, tkI_try:
              Inc(BeginCount);

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
                if BeginCount = 1 then
                  HasStatements := True;
              end;

            tkI_if, tkI_for, tkI_while, tkI_repeat, tkI_with, tkI_raise,
            tkI_goto, tkI_asm, tkI_inherited:
              begin
                // Control flow statements
                if BeginCount = 1 then
                  HasStatements := True;
              end;

            tkAssign, tkPlus, tkMinus, tkMultiply, tkDivide:
              begin
                // Operators indicate actual code
                if BeginCount = 1 then
                  HasStatements := True;
              end;
          else
            // Check for identifiers that are not just the method name
            if (Token.Kind >= tkIdent) and (BeginCount = 1) then
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
