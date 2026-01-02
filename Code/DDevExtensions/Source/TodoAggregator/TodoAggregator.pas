{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit TodoAggregator;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Generics.Collections, Menus, Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main;

type
  TTodoItem = record
    FileName: string;
    UnitName: string;
    Line: Integer;
    Column: Integer;
    Category: string;      // TODO, FIXME, HACK, BUG, NOTE, XXX
    Priority: string;      // High, Medium, Low
    Text: string;          // Full comment text
  end;

  TTodoScanner = class
  private
    FProgressFileName: string;
    FPatterns: TStringList;
    function ParseTodoComment( const CommentText: string; out Category, Priority, Text: string ): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetPatterns( const PatternList: string );
    function ScanFile( const FileName: string; out TodoItems: TArray<TTodoItem> ): Boolean;
    function ScanProject( const Project: IOTAProject; out AllTodoItems: TArray<TTodoItem>;
      OnProgress: TNotifyEvent ): Boolean;
    property ProgressFileName: string read FProgressFileName;
  end;

  TTodoAggregatorPlugin = class( TPluginConfig )
  private
    FEnabled: Boolean;
    FPatterns: string;
    FMenuItem: TMenuItem;
    procedure MenuItemClick( Sender: TObject );
  protected
    function GetOptionPages: TTreePage; override;
    procedure Init; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ShowAggregator;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
    property Patterns: string read FPatterns write FPatterns;
  end;

procedure InitPlugin( Unload: Boolean );

var
  TodoAggregatorPlugin: TTodoAggregatorPlugin;

implementation

uses
  Forms, Controls, ToolsAPIHelpers, AppConsts, DelphiLexer,
  FrmTodoAggregator, FrmeOptionPageTodoAggregator;

{ TTodoScanner }

constructor TTodoScanner.Create;
begin

  inherited Create;
  FPatterns                := TStringList.Create;
  FPatterns.CaseSensitive  := False;
  FPatterns.Duplicates     := dupIgnore;
  // Default patterns
  FPatterns.Add( 'TODO' );
  FPatterns.Add( 'FIXME' );
  FPatterns.Add( 'HACK' );
  FPatterns.Add( 'BUG' );
  FPatterns.Add( 'NOTE' );
  FPatterns.Add( 'XXX' );

end;

destructor TTodoScanner.Destroy;
begin

  FPatterns.Free;
  inherited Destroy;

end;

procedure TTodoScanner.SetPatterns( const PatternList: string );
var
  I: Integer;
  SL: TStringList;
begin

  FPatterns.Clear;
  SL := TStringList.Create;

  try
    SL.Delimiter       := ',';
    SL.StrictDelimiter := True;
    SL.DelimitedText   := PatternList;

    for I := 0 to SL.Count - 1 do
    begin
      if Trim( SL[ I ] ) <> '' then
        FPatterns.Add( Trim( SL[ I ] ) );
    end;
  finally
    SL.Free;
  end;

end;

function TTodoScanner.ParseTodoComment( const CommentText: string;
  out Category, Priority, Text: string ): Boolean;
var
  I, J: Integer;
  Pattern: string;
  UpperComment: string;
  PatternPos: Integer;
  PriorityStart, PriorityEnd: Integer;
  PriorityText: string;
begin

  Result       := False;
  Category     := '';
  Priority     := 'Normal';
  Text         := '';
  UpperComment := UpperCase( CommentText );

  // Search for any of the configured patterns
  for I := 0 to FPatterns.Count - 1 do
  begin
    Pattern    := UpperCase( FPatterns[ I ] );
    PatternPos := Pos( Pattern, UpperComment );

    if PatternPos > 0 then
    begin
      // Found a match - verify it's a word boundary (not part of another word)
      if ( PatternPos > 1 ) and CharInSet( CommentText[ PatternPos - 1 ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) then
        Continue;

      if ( PatternPos + Length( Pattern ) <= Length( CommentText ) ) and
         CharInSet( CommentText[ PatternPos + Length( Pattern ) ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) then
        Continue;

      Category := FPatterns[ I ];  // Use original case from patterns

      // Check for priority in parentheses: TODO(high): or FIXME(low):
      J := PatternPos + Length( Pattern );

      if ( J <= Length( CommentText ) ) and ( CommentText[ J ] = '(' ) then
      begin
        PriorityStart := J + 1;
        PriorityEnd   := PriorityStart;

        while ( PriorityEnd <= Length( CommentText ) ) and ( CommentText[ PriorityEnd ] <> ')' ) do
          Inc( PriorityEnd );

        if PriorityEnd <= Length( CommentText ) then
        begin
          PriorityText := Trim( Copy( CommentText, PriorityStart, PriorityEnd - PriorityStart ) );

          if SameText( PriorityText, 'high' ) or SameText( PriorityText, '!' ) or SameText( PriorityText, '1' ) then
            Priority := 'High'
          else if SameText( PriorityText, 'low' ) or SameText( PriorityText, '3' ) then
            Priority := 'Low'
          else if SameText( PriorityText, 'medium' ) or SameText( PriorityText, 'normal' ) or SameText( PriorityText, '2' ) then
            Priority := 'Normal';

          J := PriorityEnd + 1;
        end;
      end;

      // Skip colon and whitespace after category/priority
      while ( J <= Length( CommentText ) ) and ( CharInSet( CommentText[ J ], [ ':', ' ', #9 ] ) ) do
        Inc( J );

      Text   := Trim( Copy( CommentText, J, MaxInt ) );
      Result := True;
      Exit;
    end;
  end;

end;

function TTodoScanner.ScanFile( const FileName: string;
  out TodoItems: TArray<TTodoItem> ): Boolean;
var
  Content: UTF8String;
  Lexer: TDelphiLexer;
  Token: TToken;
  CommentBody: string;
  TodoList: TList<TTodoItem>;
  TodoItem: TTodoItem;
  Category, Priority, Text: string;
  UnitName: string;
begin

  Result := False;
  SetLength( TodoItems, 0 );

  if not FileExists( FileName ) then
    Exit;

  try
    Content := LoadTextFileToUtf8String( FileName );
  except
    Exit;
  end;

  UnitName := ChangeFileExt( ExtractFileName( FileName ), '' );
  TodoList := TList<TTodoItem>.Create;

  try
    Lexer := TDelphiLexer.Create( FileName, Content );

    try
      while Lexer.NextToken( Token ) do
      begin
        if Token.Kind = tkComment then
        begin
          CommentBody := Token.GetCommentBody;

          if ParseTodoComment( CommentBody, Category, Priority, Text ) then
          begin
            TodoItem.FileName := FileName;
            TodoItem.UnitName := UnitName;
            TodoItem.Line     := Token.Line + 1;  // Token.Line is 0-based
            TodoItem.Column   := Token.Column;
            TodoItem.Category := Category;
            TodoItem.Priority := Priority;
            TodoItem.Text     := Text;
            TodoList.Add( TodoItem );
          end;
        end;
      end;

      TodoItems := TodoList.ToArray;
      Result    := True;
    finally
      Lexer.Free;
    end;
  finally
    TodoList.Free;
  end;

end;

function TTodoScanner.ScanProject( const Project: IOTAProject;
  out AllTodoItems: TArray<TTodoItem>; OnProgress: TNotifyEvent ): Boolean;
var
  I: Integer;
  ModuleInfo: IOTAModuleInfo;
  FileName: string;
  TodoItems: TArray<TTodoItem>;
  AllTodos: TList<TTodoItem>;
  TodoItem: TTodoItem;
begin

  Result := False;
  SetLength( AllTodoItems, 0 );

  if Project = nil then
    Exit;

  AllTodos := TList<TTodoItem>.Create;

  try
    for I := 0 to Project.GetModuleCount - 1 do
    begin
      ModuleInfo := Project.GetModule( I );
      FileName   := ModuleInfo.FileName;

      if SameText( ExtractFileExt( FileName ), '.pas' ) then
      begin

        if Assigned( OnProgress ) then
        begin
          FProgressFileName := ExtractFileName( FileName );
          OnProgress( Self );
        end;

        if ScanFile( FileName, TodoItems ) then
        begin

          for TodoItem in TodoItems do
            AllTodos.Add( TodoItem );
        end;
      end;
    end;

    AllTodoItems := AllTodos.ToArray;
    Result       := True;
  finally
    AllTodos.Free;
  end;

end;

{ TTodoAggregatorPlugin }

constructor TTodoAggregatorPlugin.Create;
var
  ToolsMenu: TMenuItem;
begin

  inherited Create( AppDataDirectory + '\TodoAggregator.xml', 'TodoAggregator' );

  // Add menu item under Tools menu
  ToolsMenu := FindMenuItem( 'ToolsMenu' );

  if ToolsMenu <> nil then
  begin
    FMenuItem         := TMenuItem.Create( ToolsMenu );
    FMenuItem.Caption := 'TODO/FIXME &Aggregator...';
    FMenuItem.OnClick := MenuItemClick;
    ToolsMenu.Add( FMenuItem );
  end;

end;

destructor TTodoAggregatorPlugin.Destroy;
begin

  FreeAndNil( FMenuItem );
  inherited Destroy;

end;

procedure TTodoAggregatorPlugin.Init;
begin

  FEnabled  := True;
  FPatterns := 'TODO,FIXME,HACK,BUG,NOTE,XXX';

end;

function TTodoAggregatorPlugin.GetOptionPages: TTreePage;
begin

  Result := TTreePage.Create( 'TODO/FIXME Aggregator', TFrameOptionPageTodoAggregator, Self );

end;

procedure TTodoAggregatorPlugin.MenuItemClick( Sender: TObject );
begin

  ShowAggregator;

end;

procedure TTodoAggregatorPlugin.ShowAggregator;
begin

  TFormTodoAggregator.Execute;

end;

procedure InitPlugin( Unload: Boolean );
begin

  if not Unload then
    TodoAggregatorPlugin := TTodoAggregatorPlugin.Create
  else
  begin
    TodoAggregatorPlugin.Free;
    TodoAggregatorPlugin := nil;
  end;

end;

end.
