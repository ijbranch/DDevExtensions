{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit TodoAggregatorCore;

/// <summary>
/// Pure core of the TODO/FIXME Aggregator: recognising a tagged comment and collecting every
/// one in a unit's source.  No ToolsAPI and no VCL, so it is unit-testable outside the IDE; the
/// plugin unit decides where the source comes from.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

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
    /// <summary>1-based column where the comment starts, as TToken.Column reports it; used to place the caret.</summary>
    Column: Integer;
    /// <summary>Matched category keyword (e.g. TODO, FIXME, HACK, BUG, NOTE, XXX).</summary>
    Category: string;
    /// <summary>Parsed priority text: High, Normal or Low (defaults to Normal).</summary>
    Priority: string;
    /// <summary>Comment body text after the category and optional priority/colon.</summary>
    Text: string;
  end;

  /// <summary>
  /// Lexer-driven scanner that walks the comment tokens of a Delphi source and extracts the
  /// items matching the configured pattern list.
  /// </summary>
  TTodoScanner = class
  private
    /// <summary>Backing field for <see cref="ProgressFileName"/>.</summary>
    FProgressFileName: string;
    /// <summary>Active list of category keywords to recognise.</summary>
    FPatterns: TStringList;
  public
    /// <summary>Creates the scanner with the default pattern list (TODO, FIXME, HACK, BUG, NOTE, XXX).</summary>
    constructor Create;
    /// <summary>Releases the pattern list.</summary>
    destructor Destroy; override;
    /// <summary>Replaces the active patterns from a comma-separated string.</summary>
    /// <param name="PatternList">Comma-separated list of keywords.</param>
    procedure SetPatterns( const PatternList: string );
    /// <summary>Parses one comment body for the first configured tag and an optional priority.  A tag
    /// is a whole word written in capitals, opening the comment, or followed by a colon or a
    /// priority ( "TODO fix", "todo: fix", "Fixme(high)" ); a word in prose ( "a bug in" ) is not.</summary>
    /// <param name="CommentText">Text of the comment without delimiters.</param>
    /// <param name="Category">Receives the matched keyword in its configured case.</param>
    /// <param name="Priority">Receives the parsed priority (High, Normal or Low).</param>
    /// <param name="Text">Receives the trimmed remainder of the comment.</param>
    /// <returns>True if a pattern was recognised; False otherwise.</returns>
    function ParseTodoComment( const CommentText: string; out Category, Priority, Text: string ): Boolean;
    /// <summary>Collects the tagged comments of one unit's source.</summary>
    /// <param name="Content">The unit's text as UTF-8 without a BOM.</param>
    /// <param name="FileName">The unit's file, recorded in each item.</param>
    /// <returns>The items in source order; empty when there are none.</returns>
    function ScanSource( const Content: UTF8String; const FileName: string ): TArray<TTodoItem>;
    /// <summary>Name of the file currently being scanned, suitable for status labels.</summary>
    property ProgressFileName: string read FProgressFileName write FProgressFileName;
  end;

implementation

uses
  DelphiLexer;

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

  function IsWordChar( AChar: Char ): Boolean;
  begin
    Result := CharInSet( AChar, [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] );
  end;

  { True when nothing but layout comes before the tag: blanks, comment decoration ( "/// todo",
    "//- todo", "// @todo" ) and a date or number ( "// 2026-11 fixme" ) - no word of prose. }
  function OnlyLeadIn( AUpTo: Integer ): Boolean;
  begin
    for var K := 1 to AUpTo - 1 do
      if ( not CharInSet( CommentText[ K ], [ ' ', #9, #13, #10, '/', '@', '-', '*', '#', '!', '~', '=', '>',
        '<', '.', ':', ';', ',', '+', '0'..'9' ] ) ) then
        Exit( False );
    Result := True;
  end;

  { A tag counts when it is a whole word AND it is written in capitals, opens the comment ( after
    any lead-in ), or is followed by a colon or a priority - so "a bug in the parser" is prose. }
  function IsTagAt( APos: Integer; const APattern: string ): Boolean;
  var
    iAfter: Integer;
  begin
    iAfter := APos + Length( APattern );
    if ( APos > 1 ) and IsWordChar( CommentText[ APos - 1 ] ) then
      Exit( False );
    if ( iAfter <= Length( CommentText ) ) and IsWordChar( CommentText[ iAfter ] ) then
      Exit( False );

    if ( Copy( CommentText, APos, Length( APattern ) ) = UpperCase( APattern ) ) then
      Exit( True );
    if OnlyLeadIn( APos ) then
      Exit( True );
    while ( iAfter <= Length( CommentText ) ) and CharInSet( CommentText[ iAfter ], [ ' ', #9 ] ) do
      Inc( iAfter );
    Result := ( iAfter <= Length( CommentText ) ) and CharInSet( CommentText[ iAfter ], [ ':', '(' ] );
  end;

var
  I, J: Integer;
  sPattern: string;
  sUpperComment: string;
  iPos, iBestPos, iBestIndex: Integer;
  iPriorityStart, iPriorityEnd: Integer;
  sPriorityText: string;
begin
  Result        := False;
  Category      := '';
  Priority      := 'Normal';
  Text          := '';
  sUpperComment := UpperCase( CommentText );

  { The tag that comes first in the comment wins, whatever the order of the patterns, and every
    occurrence of a pattern is tried ( "BUGFIX ... BUG:" finds the second ). }
  iBestPos   := 0;
  iBestIndex := -1;
  for I := 0 to FPatterns.Count - 1 do
  begin
    sPattern := UpperCase( FPatterns[ I ] );
    if ( sPattern = '' ) then
      Continue;
    iPos := Pos( sPattern, sUpperComment );
    while ( iPos > 0 ) and ( ( iBestIndex < 0 ) or ( iPos < iBestPos ) ) do
    begin
      if IsTagAt( iPos, sPattern ) then
      begin
        iBestPos   := iPos;
        iBestIndex := I;
        Break;
      end;
      iPos := Pos( sPattern, sUpperComment, iPos + 1 );
    end;
  end;
  if ( iBestIndex < 0 ) then
    Exit;

  Category := FPatterns[ iBestIndex ];  // Use original case from patterns

  // Check for priority in parentheses: TODO(high): or FIXME(low):
  J := iBestPos + Length( Category );

  if ( J <= Length( CommentText ) ) and ( CommentText[ J ] = '(' ) then
  begin
    iPriorityStart := J + 1;
    iPriorityEnd   := iPriorityStart;

    while ( iPriorityEnd <= Length( CommentText ) ) and ( CommentText[ iPriorityEnd ] <> ')' ) do
      Inc( iPriorityEnd );

    if ( iPriorityEnd <= Length( CommentText ) ) then
    begin
      sPriorityText := Trim( Copy( CommentText, iPriorityStart, iPriorityEnd - iPriorityStart ) );

      if SameText( sPriorityText, 'high' ) or SameText( sPriorityText, '!' ) or SameText( sPriorityText, '1' ) then
        Priority := 'High'
      else if SameText( sPriorityText, 'low' ) or SameText( sPriorityText, '3' ) then
        Priority := 'Low'
      else if SameText( sPriorityText, 'medium' ) or SameText( sPriorityText, 'normal' ) or SameText( sPriorityText, '2' ) then
        Priority := 'Normal';

      J := iPriorityEnd + 1;
    end;
  end;

  // Skip colon and whitespace after category/priority
  while ( J <= Length( CommentText ) ) and ( CharInSet( CommentText[ J ], [ ':', ' ', #9 ] ) ) do
    Inc( J );

  Text   := Trim( Copy( CommentText, J, MaxInt ) );
  Result := True;
end;

function TTodoScanner.ScanSource( const Content: UTF8String; const FileName: string ): TArray<TTodoItem>;
var
  Lexer: TDelphiLexer;
  Token: TToken;
  TodoList: TList<TTodoItem>;
  TodoItem: TTodoItem;
  Category, Priority, Text: string;
begin
  var sUnitName := ChangeFileExt( ExtractFileName( FileName ), '' );
  TodoList      := TList<TTodoItem>.Create;
  try
    Lexer := TDelphiLexer.Create( FileName, Content );
    try
      while Lexer.NextToken( Token ) do
        if ( Token.Kind = tkComment ) and ParseTodoComment( Token.GetCommentBody, Category, Priority, Text ) then
        begin
          TodoItem.FileName := FileName;
          TodoItem.UnitName := sUnitName;
          TodoItem.Line     := Token.Line + 1;  // Token.Line is 0-based
          TodoItem.Column   := Token.Column;
          TodoItem.Category := Category;
          TodoItem.Priority := Priority;
          TodoItem.Text     := Text;
          TodoList.Add( TodoItem );
        end;
    finally
      Lexer.Free;
    end;
    Result := TodoList.ToArray;
  finally
    TodoList.Free;
  end;
end;

end.
