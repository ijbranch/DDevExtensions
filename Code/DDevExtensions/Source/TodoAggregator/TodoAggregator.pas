{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit TodoAggregator;

/// <summary>
/// Plugin that scans the current project's Pascal sources for TODO/FIXME-style comments
/// and presents them in a sortable, filterable list. Provides a configurable comma-
/// separated pattern list, optional priority parsing such as TODO(high), and integrates
/// into the IDE through a DDevExtensions submenu entry.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Generics.Collections, Vcl.Menus, System.Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main;

type
  /// <summary>
  /// Single hit produced by the TODO scanner: source location, category (TODO, FIXME, ...),
  /// optional priority and the comment body text.
  /// </summary>
  TTodoItem = record
    /// <summary>Full path to the source file containing the comment.</summary>
    FileName: string;
    /// <summary>Unit name (file name without extension).</summary>
    UnitName: string;
    /// <summary>1-based line number of the comment.</summary>
    Line: Integer;
    /// <summary>0-based column where the comment starts.</summary>
    Column: Integer;
    /// <summary>Matched category keyword (e.g. TODO, FIXME, HACK, BUG, NOTE, XXX).</summary>
    Category: string;      // TODO, FIXME, HACK, BUG, NOTE, XXX
    /// <summary>Parsed priority text: High, Normal or Low (defaults to Normal).</summary>
    Priority: string;      // High, Medium, Low
    /// <summary>Comment body text after the category and optional priority/colon.</summary>
    Text: string;          // Full comment text
  end;

  /// <summary>
  /// Lexer-driven scanner that walks the comment tokens of a Delphi source file and
  /// extracts items matching the configured pattern list.
  /// </summary>
  TTodoScanner = class
  private
    /// <summary>Most recently scanned file name, exposed via ProgressFileName for UI feedback.</summary>
    FProgressFileName: string;
    /// <summary>Active list of category keywords to recognise.</summary>
    FPatterns: TStringList;
    /// <summary>Parses one comment body looking for any configured keyword and optional priority.</summary>
    /// <param name="CommentText">Text of the comment without delimiters.</param>
    /// <param name="Category">Receives the matched keyword in its configured case.</param>
    /// <param name="Priority">Receives the parsed priority (High, Normal or Low).</param>
    /// <param name="Text">Receives the trimmed remainder of the comment.</param>
    /// <returns>True if a pattern was recognised; False otherwise.</returns>
    function ParseTodoComment( const CommentText: string; out Category, Priority, Text: string ): Boolean;
  public
    /// <summary>Creates the scanner with the default pattern list (TODO, FIXME, HACK, BUG, NOTE, XXX).</summary>
    constructor Create;
    /// <summary>Releases the pattern list.</summary>
    destructor Destroy; override;
    /// <summary>Replaces the active patterns from a comma-separated string.</summary>
    /// <param name="PatternList">Comma-separated list of keywords.</param>
    procedure SetPatterns( const PatternList: string );
    /// <summary>Scans a single .pas file and returns matching TODO items.</summary>
    /// <param name="FileName">Path to a Pascal source file.</param>
    /// <param name="TodoItems">Receives the matches (empty array on no matches or failure).</param>
    /// <returns>True if the file was readable and scanning completed.</returns>
    function ScanFile( const FileName: string; out TodoItems: TArray<TTodoItem> ): Boolean;
    /// <summary>Scans every .pas module in the supplied IDE project, raising OnProgress per file.</summary>
    /// <param name="Project">IDE project to walk.</param>
    /// <param name="AllTodoItems">Receives the aggregated matches.</param>
    /// <param name="OnProgress">Optional callback invoked before each file is scanned.</param>
    /// <returns>True on success; False if Project is nil.</returns>
    function ScanProject( const Project: IOTAProject; out AllTodoItems: TArray<TTodoItem>;
      OnProgress: TNotifyEvent ): Boolean;
    /// <summary>Name of the file currently being scanned, suitable for status labels.</summary>
    property ProgressFileName: string read FProgressFileName;
  end;

  /// <summary>
  /// Persistent plugin configuration that owns the menu entry and exposes Enabled/Patterns
  /// as published settings (stored in TodoAggregator.xml).
  /// </summary>
  TTodoAggregatorPlugin = class( TPluginConfig )
  private
    /// <summary>Backing field for the Enabled property.</summary>
    FEnabled: Boolean;
    /// <summary>Backing field for the Patterns property (comma-separated).</summary>
    FPatterns: string;
    /// <summary>Menu item added under the DDevExtensions submenu.</summary>
    FMenuItem: TMenuItem;
    /// <summary>OnClick handler that opens the aggregator window.</summary>
    procedure MenuItemClick( Sender: TObject );
  protected
    /// <summary>Returns the configuration page shown in the IDE Options dialog.</summary>
    /// <returns>A TTreePage describing the TODO/FIXME Aggregator settings.</returns>
    function GetOptionPages: TTreePage; override;
    /// <summary>Sets default Enabled and Patterns values.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the configuration object and adds the IDE menu item.</summary>
    constructor Create;
    /// <summary>Removes the menu item.</summary>
    destructor Destroy; override;
    /// <summary>Shows the TODO aggregator form (singleton).</summary>
    procedure ShowAggregator;
  published
    /// <summary>True when the aggregator menu/feature is active (currently informational).</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
    /// <summary>Comma-separated list of category keywords used by the scanner.</summary>
    property Patterns: string read FPatterns write FPatterns;
  end;

/// <summary>
/// Creates or destroys the singleton TodoAggregator plugin instance.
/// </summary>
/// <param name="Unload">True to shut down, False to start up.</param>
procedure InitPlugin( Unload: Boolean );

var
  /// <summary>Singleton plugin instance accessed by the form and option page.</summary>
  TodoAggregatorPlugin: TTodoAggregatorPlugin;

implementation

uses
  Vcl.Forms, Vcl.Controls, ToolsAPIHelpers, AppConsts, DelphiLexer,
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
    on E: Exception do
    begin
      // Skip this file but record why rather than swallowing silently.
      OutputDebugString( PChar( 'DDevExtensions TodoAggregator: ' + FileName + ' - ' + E.Message ) );
      Exit;
    end;
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
begin

  inherited Create( AppDataDirectory + '\TodoAggregator.xml', 'TodoAggregator' );

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem         := TMenuItem.Create( DDevExtensionsMenu );
    FMenuItem.Caption := 'TODO/FIXME &Aggregator...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add( FMenuItem );
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
