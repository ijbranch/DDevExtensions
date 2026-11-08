{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2025 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit UnreachableCodeCore;

/// <summary>
/// Pure analysis core of the Unreachable Code Detector: scans a unit's implementation for code that
/// follows an unconditional control-flow terminator (Exit, Raise, Break, Continue, Halt, Abort).
/// </summary>
/// <remarks>
/// RTL and <c>DelphiPreproc</c> only - no ToolsAPI, no VCL - so it is unit-testable outside the IDE.
/// A report invites the user to delete code, so every doubt resolves to "reachable": a terminator
/// reached through <c>then</c>, <c>else</c>, <c>do</c> or a case / statement label is conditional;
/// code after a conditional-compilation directive belongs to another configuration; a qualified
/// call (<c>Printer.Abort</c>) is not a terminator; and a <c>$IF</c> the scanner cannot evaluate is
/// skipped rather than scanned.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  /// <summary>Identifies which terminator keyword preceded a block of unreachable code.</summary>
  TUnreachableReason = (
    /// <summary>Code follows an unconditional Exit.</summary>
    urAfterExit,
    /// <summary>Code follows a Raise statement.</summary>
    urAfterRaise,
    /// <summary>Code follows a Break statement.</summary>
    urAfterBreak,
    /// <summary>Code follows a Continue statement.</summary>
    urAfterContinue,
    /// <summary>Code follows a Halt call.</summary>
    urAfterHalt,
    /// <summary>Code follows an Abort call.</summary>
    urAfterAbort
    );

  /// <summary>One detected block of unreachable code.</summary>
  TUnreachableCodeItem = record
    /// <summary>Full path of the file containing the unreachable code.</summary>
    FileName: string;
    /// <summary>Unit name (without extension).</summary>
    UnitName: string;
    /// <summary>1-based source line of the unreachable code.</summary>
    Line: Integer;
    /// <summary>Source column (currently always 1).</summary>
    Column: Integer;
    /// <summary>Terminator type that made this code unreachable.</summary>
    Reason: TUnreachableReason;
    /// <summary>1-based source line of the terminator statement that preceded the unreachable code.</summary>
    TerminatorLine: Integer;
    /// <summary>Up to 50 characters of the unreachable code, used for display.</summary>
    CodePreview: string;
    /// <summary>Returns the reason as a human-readable phrase ("After Exit", "After Raise", ...).</summary>
    /// <returns>The phrase shown in the result list.</returns>
    function ReasonText: string;
  end;

  /// <summary>
  /// Source-level scanner that detects unreachable code following unconditional control-flow terminators.
  /// </summary>
  TUnreachableCodeScanner = class
  private
    /// <summary>List of detected unreachable code items.</summary>
    FItems: TList<TUnreachableCodeItem>;
    /// <summary>Active conditional symbols: the compiler's predefined ones for the target plus the project's.</summary>
    FDefines: TStringList;
    /// <summary>Routine and method names the unit being scanned declares itself; a call to its own Abort or Halt is not the System one.</summary>
    FOwnRoutines: TStringList;
    /// <summary>Returns True when DefineName is an active conditional symbol.</summary>
    /// <param name="DefineName">The symbol.</param>
    /// <returns>True when defined.</returns>
    function IsDefineDefined( const DefineName: string ): Boolean;
    /// <summary>Evaluates a $IF / $ELSEIF condition.</summary>
    /// <param name="Condition">The condition text after the directive name.</param>
    /// <returns>1 (true), 0 (false) or -1 (not understood: the block is treated as inactive).</returns>
    function EvaluateIfCondition( const Condition: string ): Integer;
    /// <summary>Handles the compiler directive starting at Pos while scanning active code.</summary>
    /// <param name="Source">The unit text.</param>
    /// <param name="Pos">Position of the directive's opening brace or parenthesis.</param>
    /// <returns>The position where scanning continues: after the directive, or after the inactive block it opens.</returns>
    function HandleDirective( const Source: string; Pos: Integer ): Integer;
    /// <summary>Skips an inactive conditional block to its end, or to an active $ELSE / $ELSEIF branch.</summary>
    /// <param name="Source">The unit text.</param>
    /// <param name="Pos">Position just after the directive that opened the inactive block.</param>
    /// <param name="AllowElse">True when an $ELSE or a true $ELSEIF at this level starts active code (False when the active branch has already run).</param>
    /// <returns>The position where scanning continues.</returns>
    function SkipInactiveBlock( const Source: string; Pos: Integer; AllowElse: Boolean ): Integer;
    /// <summary>Checks the identifier at WordStart and, when it is an unconditional terminator followed by code, records that code.</summary>
    /// <param name="Source">The unit text.</param>
    /// <param name="WordStart">Position of the identifier.</param>
    /// <param name="WordEnd">Position just after the identifier.</param>
    /// <returns>The position where scanning continues.</returns>
    function CheckTerminator( const Source: string; WordStart, WordEnd: Integer ): Integer;
  public
    /// <summary>Creates a new scanner; until <see cref="SetTarget"/> is called it assumes Win64 and no project defines.</summary>
    constructor Create;
    /// <summary>Releases all owned resources.</summary>
    destructor Destroy; override;
    /// <summary>Discards all previously detected items.</summary>
    procedure Clear;
    /// <summary>Sets the conditional symbols the scan honours: the compiler's predefined symbols for Platform plus the project's own.</summary>
    /// <param name="Platform">Target platform name, "Win32" or "Win64".</param>
    /// <param name="ProjectDefines">The project's conditional defines, separated by semicolons.</param>
    procedure SetTarget( const Platform, ProjectDefines: string );
    /// <summary>Scans the supplied source text for unreachable code in its implementation section (the whole text for a program or library).</summary>
    /// <param name="Source">The unit text.</param>
    /// <param name="FileName">Full path of the unit, for reporting.</param>
    /// <param name="UnitName">Unit name, for reporting.</param>
    procedure ScanSource( const Source, FileName, UnitName: string );
    /// <summary>Scans a single file and replaces any previously detected items.</summary>
    /// <param name="FileName">Full path of the unit.</param>
    /// <exception cref="EFOpenError">Raised when the file cannot be opened.</exception>
    procedure ScanFile( const FileName: string );
    /// <summary>Returns a snapshot of all detected unreachable code items.</summary>
    /// <returns>The items in detection order.</returns>
    function GetItems: TArray<TUnreachableCodeItem>;
  end;

implementation

uses
  System.Character, DelphiPreproc;

const
  /// <summary>Control-flow terminators, lower case, with the reason each reports.</summary>
  Terminators       : array[ 0..5 ] of record
    Keyword: string;
    Reason: TUnreachableReason;
  end               = (
    ( Keyword: 'exit'; Reason: urAfterExit ),
    ( Keyword: 'raise'; Reason: urAfterRaise ),
    ( Keyword: 'break'; Reason: urAfterBreak ),
    ( Keyword: 'continue'; Reason: urAfterContinue ),
    ( Keyword: 'halt'; Reason: urAfterHalt ),
    ( Keyword: 'abort'; Reason: urAfterAbort )
    );

{ Lexical helpers }

/// <summary>True for a character that can start an identifier.</summary>
/// <param name="C">The character.</param>
/// <returns>True for a letter or underscore.</returns>
function IsIdentStart( C: Char ): Boolean;
begin
  Result            := CharInSet( C, [ 'A'..'Z', 'a'..'z', '_' ] ) or ( ( Ord( C ) >= 128 ) and C.IsLetter );
end;

/// <summary>True for a character that can continue an identifier.</summary>
/// <param name="C">The character.</param>
/// <returns>True for a letter, digit or underscore.</returns>
function IsIdentChar( C: Char ): Boolean;
begin
  Result            := CharInSet( C, [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) or ( ( Ord( C ) >= 128 ) and C.IsLetterOrDigit );
end;

/// <summary>Returns the position just after the string literal starting at Pos (a quote).</summary>
/// <param name="Source">The text.</param>
/// <param name="Pos">Position of the opening quote.</param>
/// <returns>The position after the literal.  A Delphi 12 multi-line string (an odd run of three or
/// more quotes ending its line) runs to the line that holds the same run after leading blanks; an
/// ordinary literal ends at its closing quote or, unterminated, at the end of its line.</returns>
function SkipString( const Source: string; Pos: Integer ): Integer;
begin
  var iLen          := Length( Source );

  var iRun          := 0;
  while ( Pos + iRun <= iLen ) and ( Source[ Pos + iRun ] = '''' ) do
    Inc( iRun );

  if ( iRun >= 3 ) and Odd( iRun ) then
  begin
    var j           := Pos + iRun;
    while ( j <= iLen ) and CharInSet( Source[ j ], [ ' ', #9 ] ) do
      Inc( j );

    if ( j <= iLen ) and CharInSet( Source[ j ], [ #10, #13 ] ) then
    begin
      // multi-line string: find the closing line
      while j <= iLen do
      begin
        while ( j <= iLen ) and not CharInSet( Source[ j ], [ #10, #13 ] ) do
          Inc( j );
        while ( j <= iLen ) and CharInSet( Source[ j ], [ #10, #13 ] ) do
          Inc( j );
        while ( j <= iLen ) and CharInSet( Source[ j ], [ ' ', #9 ] ) do
          Inc( j );

        var iClosing := 0;
        while ( j + iClosing <= iLen ) and ( Source[ j + iClosing ] = '''' ) do
          Inc( iClosing );
        if iClosing >= iRun then
          Exit( j + iRun );
      end;
      Exit( iLen + 1 );
    end;
  end;

  // ordinary literal: '' is an escaped quote
  Result            := Pos + 1;
  while Result <= iLen do
  begin
    if Source[ Result ] = '''' then
    begin
      if ( Result < iLen ) and ( Source[ Result + 1 ] = '''' ) then
        Inc( Result, 2 )
      else
        Exit( Result + 1 );
    end
    else if CharInSet( Source[ Result ], [ #10, #13 ] ) then
      Exit( Result ) // a Pascal literal ends with its line
    else
      Inc( Result );
  end;
end;

/// <summary>True when a brace or parenthesis-star comment starting at Pos is a compiler directive.</summary>
/// <param name="Source">The text.</param>
/// <param name="Pos">Position of the opening character.</param>
/// <returns>True for "{$" and "(*$".</returns>
function IsDirectiveAt( const Source: string; Pos: Integer ): Boolean;
begin
  var iLen          := Length( Source );
  Result            := ( ( Source[ Pos ] = '{' ) and ( Pos < iLen ) and ( Source[ Pos + 1 ] = '$' ) ) or
    ( ( Source[ Pos ] = '(' ) and ( Pos + 2 <= iLen ) and ( Source[ Pos + 1 ] = '*' ) and ( Source[ Pos + 2 ] = '$' ) );
end;

/// <summary>True when a comment (or directive) starts at Pos.</summary>
/// <param name="Source">The text.</param>
/// <param name="Pos">Position to test.</param>
/// <returns>True for "{", "(*" and "//".</returns>
function IsCommentStart( const Source: string; Pos: Integer ): Boolean;
begin
  var iLen          := Length( Source );
  Result            := ( Source[ Pos ] = '{' ) or
    ( ( Pos < iLen ) and ( Source[ Pos ] = '(' ) and ( Source[ Pos + 1 ] = '*' ) ) or
    ( ( Pos < iLen ) and ( Source[ Pos ] = '/' ) and ( Source[ Pos + 1 ] = '/' ) );
end;

/// <summary>Returns the position just after the comment or directive starting at Pos.</summary>
/// <param name="Source">The text.</param>
/// <param name="Pos">Position of "{", "(*" or "//".</param>
/// <returns>The position after it; past the end of the text when it is unterminated.</returns>
function SkipComment( const Source: string; Pos: Integer ): Integer;
begin
  var iLen          := Length( Source );
  if Source[ Pos ] = '{' then
  begin
    Result          := Pos + 1;
    while ( Result <= iLen ) and ( Source[ Result ] <> '}' ) do
      Inc( Result );
    Inc( Result );
  end
  else if Source[ Pos ] = '(' then
  begin
    Result          := Pos + 2;
    while ( Result < iLen ) and not ( ( Source[ Result ] = '*' ) and ( Source[ Result + 1 ] = ')' ) ) do
      Inc( Result );
    Inc( Result, 2 );
  end
  else
  begin
    Result          := Pos + 2;
    while ( Result <= iLen ) and not CharInSet( Source[ Result ], [ #10, #13 ] ) do
      Inc( Result );
  end;
end;

/// <summary>Splits the directive at Pos into its upper-case name and its argument text.</summary>
/// <param name="Source">The text.</param>
/// <param name="Pos">Position of the directive's opening "{" or "(".</param>
/// <param name="Name">Receives the directive name, upper case (IFDEF, ENDIF, ...).</param>
/// <param name="Argument">Receives the trimmed text after the name.</param>
/// <returns>The position just after the directive.</returns>
function ReadDirective( const Source: string; Pos: Integer; out Name, Argument: string ): Integer;
begin
  Result            := SkipComment( Source, Pos );

  var iBodyStart    := Pos + 2; // after "{$"
  var iBodyEnd      := Result - 2; // before "}"
  if Source[ Pos ] = '(' then
  begin
    iBodyStart      := Pos + 3; // after "(*$"
    iBodyEnd        := Result - 3; // before "*)"
  end;

  var sBody         := Copy( Source, iBodyStart, iBodyEnd - iBodyStart + 1 );
  var i             := 1;
  while ( i <= Length( sBody ) ) and IsIdentChar( sBody[ i ] ) do
    Inc( i );
  Name              := UpperCase( Copy( sBody, 1, i - 1 ) );
  Argument          := Trim( Copy( sBody, i, MaxInt ) );
end;

/// <summary>Returns the position of the first character after whitespace and comments (directives are NOT skipped).</summary>
/// <param name="Source">The text.</param>
/// <param name="Pos">Starting position.</param>
/// <returns>The position of the next code character or directive; past the end of the text at its end.</returns>
function SkipBlanksAndComments( const Source: string; Pos: Integer ): Integer;
begin
  var iLen          := Length( Source );
  Result            := Pos;
  while Result <= iLen do
  begin
    if CharInSet( Source[ Result ], [ ' ', #9, #10, #13 ] ) then
      Inc( Result )
    else if IsCommentStart( Source, Result ) and not IsDirectiveAt( Source, Result ) then
      Result        := SkipComment( Source, Result )
    else
      Break;
  end;
end;

/// <summary>Returns the word (identifier) starting at Pos, or '' when none starts there.</summary>
/// <param name="Source">The text.</param>
/// <param name="Pos">Position to read from.</param>
/// <returns>The identifier text.</returns>
function WordAt( const Source: string; Pos: Integer ): string;
begin
  Result            := '';
  if ( Pos > Length( Source ) ) or not IsIdentStart( Source[ Pos ] ) then
    Exit;
  var i             := Pos;
  while ( i <= Length( Source ) ) and IsIdentChar( Source[ i ] ) do
    Inc( i );
  Result            := Copy( Source, Pos, i - Pos );
end;

/// <summary>True when Word ends a statement list (end, else, until, except, finally).</summary>
/// <param name="Word">The identifier.</param>
/// <returns>True for a block-closing keyword.</returns>
function IsBlockEndWord( const Word: string ): Boolean;
begin
  Result            := SameText( Word, 'end' ) or SameText( Word, 'else' ) or SameText( Word, 'until' ) or
    SameText( Word, 'except' ) or SameText( Word, 'finally' );
end;

/// <summary>
/// Finds the end of the statement that starts at Pos: the semicolon at bracket depth 0, skipping
/// strings, comments and directives.
/// </summary>
/// <param name="Source">The text.</param>
/// <param name="Pos">Position just after the terminator keyword.</param>
/// <returns>The position of the semicolon, or 0 when the statement is instead closed by a block keyword (end, else, ...) or the text ends.</returns>
function FindStatementEnd( const Source: string; Pos: Integer ): Integer;
begin
  var iLen          := Length( Source );
  var iDepth        := 0;
  var i             := Pos;
  while i <= iLen do
  begin
    var C           := Source[ i ];
    if C = '''' then
      i             := SkipString( Source, i )
    else if IsCommentStart( Source, i ) then
      i             := SkipComment( Source, i )
    else if CharInSet( C, [ '(', '[' ] ) then
    begin
      Inc( iDepth );
      Inc( i );
    end
    else if CharInSet( C, [ ')', ']' ] ) then
    begin
      Dec( iDepth );
      Inc( i );
    end
    else if ( C = ';' ) and ( iDepth <= 0 ) then
      Exit( i )
    else if IsIdentStart( C ) then
    begin
      var sWord     := WordAt( Source, i );
      if ( iDepth <= 0 ) and IsBlockEndWord( sWord ) then
        Exit( 0 ); // "begin Exit end" - nothing follows inside this block
      Inc( i, Length( sWord ) );
    end
    else
      Inc( i );
  end;
  Result            := 0;
end;

/// <summary>
/// True when the text at Pos is a case label or statement label: a list of constants, ranges,
/// qualified names and character literals up to a ":" that is not ":=".
/// </summary>
/// <param name="Source">The text.</param>
/// <param name="Pos">Position of the first code character after the terminator's statement.</param>
/// <returns>True for "tkB, tkC:", "'a'..'z':", "TKind.B:", "-1:", "Lbl:".</returns>
function IsLabelAt( const Source: string; Pos: Integer ): Boolean;
begin
  Result            := False;
  var iLen          := Length( Source );
  var i             := Pos;
  while ( i <= iLen ) and ( i - Pos < 1000 ) do
  begin
    var C           := Source[ i ];
    if C = '''' then
      i             := SkipString( Source, i )
    else if IsCommentStart( Source, i ) then
      i             := SkipComment( Source, i )
    else if C = ':' then
      Exit( ( i = iLen ) or ( Source[ i + 1 ] <> '=' ) )
    else if IsIdentChar( C ) or CharInSet( C, [ '.', ',', ' ', #9, #10, #13, '+', '-', '#', '$', '%' ] ) then
      Inc( i )
    else
      Exit; // ";", "(", ":=" ... - a statement, not a label
  end;
end;

/// <summary>
/// Returns the position of a "//" line comment that starts on the line holding Pos, at or before
/// Pos, outside strings and brace / parenthesis comments; 0 when the line has none.
/// </summary>
/// <param name="Source">The text.</param>
/// <param name="Pos">A position on the line.</param>
/// <returns>The position of the first "/" of the comment, or 0.</returns>
function LineCommentStart( const Source: string; Pos: Integer ): Integer;
begin
  Result            := 0;
  var iStart        := Pos;
  while ( iStart > 1 ) and not CharInSet( Source[ iStart - 1 ], [ #10, #13 ] ) do
    Dec( iStart );

  var i             := iStart;
  while i <= Pos do
  begin
    if Source[ i ] = '''' then
      i             := SkipString( Source, i )
    else if ( Source[ i ] = '{' ) or ( ( i < Length( Source ) ) and ( Source[ i ] = '(' ) and ( Source[ i + 1 ] = '*' ) ) then
    begin
      var iAfter    := SkipComment( Source, i );
      if iAfter > Pos then
        Exit; // Pos is inside a block comment that began on this line
      i             := iAfter;
    end
    else if ( i < Length( Source ) ) and ( Source[ i ] = '/' ) and ( Source[ i + 1 ] = '/' ) then
      Exit( i )
    else
      Inc( i );
  end;
end;

/// <summary>
/// True when the terminator at TerminatorPos is reached conditionally: it follows "then", "else" or
/// "do", or a ":" that ends a case label, an exception handler's type or a statement label, or a
/// compiler directive stands between it and the code before it.
/// </summary>
/// <param name="Source">The text.</param>
/// <param name="TerminatorPos">Position of the terminator keyword.</param>
/// <returns>True when the code after it may still run.</returns>
function IsConditionalTerminator( const Source: string; TerminatorPos: Integer ): Boolean;
begin
  Result            := False;

  // Back over blanks, comments and line comments.  A directive on the way back ends the walk as
  // "conditional": the text before it may be another configuration's, which this backward walk
  // cannot tell apart from active code.
  var i             := TerminatorPos - 1;
  while i >= 1 do
  begin
    if CharInSet( Source[ i ], [ ' ', #9, #10, #13 ] ) then
      Dec( i )
    else if Source[ i ] = '}' then
    begin
      while ( i >= 1 ) and ( Source[ i ] <> '{' ) do
        Dec( i );
      if ( i >= 1 ) and ( i < Length( Source ) ) and ( Source[ i + 1 ] = '$' ) then
        Exit( True );
      Dec( i );
    end
    else if ( i > 1 ) and ( Source[ i ] = ')' ) and ( Source[ i - 1 ] = '*' ) then
    begin
      Dec( i, 2 );
      while ( i > 1 ) and not ( ( Source[ i ] = '*' ) and ( Source[ i - 1 ] = '(' ) ) do
        Dec( i );
      if ( i < Length( Source ) ) and ( Source[ i + 1 ] = '$' ) then
        Exit( True );
      Dec( i, 2 );
    end
    else
    begin
      // "then // bail out" on the line above: the text found is inside a line comment
      var iComment  := LineCommentStart( Source, i );
      if iComment = 0 then
        Break;
      i             := iComment - 1;
    end;
  end;

  if i < 1 then
    Exit;

  if Source[ i ] = ':' then
    Exit( True );

  if not IsIdentChar( Source[ i ] ) then
    Exit;

  var iEnd          := i;
  while ( i > 1 ) and IsIdentChar( Source[ i - 1 ] ) do
    Dec( i );
  var sPrev         := Copy( Source, i, iEnd - i + 1 );

  Result            := SameText( sPrev, 'then' ) or SameText( sPrev, 'else' ) or SameText( sPrev, 'do' );
end;

/// <summary>
/// Collects the names of the routines and methods Source declares (the last part of a qualified
/// header name), skipping strings and comments.
/// </summary>
/// <param name="Source">The unit text.</param>
/// <param name="Names">Cleared, then filled with the declared names.</param>
procedure CollectOwnRoutineNames( const Source: string; Names: TStrings );
begin
  Names.Clear;
  var iLen          := Length( Source );
  var i             := 1;
  var bHeader       := False; // reading the name after procedure / function / constructor / destructor
  var sLastName     := '';
  while i <= iLen do
  begin
    var C           := Source[ i ];
    if C = '''' then
      i             := SkipString( Source, i )
    else if IsCommentStart( Source, i ) then
      i             := SkipComment( Source, i )
    else if CharInSet( C, [ ' ', #9, #10, #13 ] ) then
      Inc( i )
    else if IsIdentStart( C ) then
    begin
      var sWord     := WordAt( Source, i );
      Inc( i, Length( sWord ) );
      if bHeader then
        sLastName   := sWord
      else
        bHeader     := SameText( sWord, 'procedure' ) or SameText( sWord, 'function' ) or
          SameText( sWord, 'constructor' ) or SameText( sWord, 'destructor' );
    end
    else if ( C = '.' ) and bHeader then
      Inc( i ) // TFoo.Abort: the name part follows
    else
    begin
      if bHeader and ( sLastName <> '' ) then
        Names.Add( sLastName );
      bHeader       := False;
      sLastName     := '';
      Inc( i );
    end;
  end;
end;

/// <summary>Returns the 1-based line number of Position in Source.</summary>
/// <param name="Source">The text.</param>
/// <param name="Position">1-based character position.</param>
/// <returns>The line number.</returns>
function GetLineNumber( const Source: string; Position: Integer ): Integer;
begin
  Result            := 1;
  for var i := 1 to Position - 1 do
  begin
    if i > Length( Source ) then
      Break;
    if Source[ i ] = #10 then
      Inc( Result )
    else if ( Source[ i ] = #13 ) and ( i < Length( Source ) ) and ( Source[ i + 1 ] <> #10 ) then
      Inc( Result );
  end;
end;

/// <summary>Returns up to 50 characters of the line starting at StartPos, for display.</summary>
/// <param name="Source">The text.</param>
/// <param name="StartPos">Position of the first character.</param>
/// <returns>The trimmed text, with "..." when it was cut short.</returns>
function GetCodePreview( const Source: string; StartPos: Integer ): string;
begin
  var iEnd          := StartPos;
  var iCount        := 0;
  while ( iEnd <= Length( Source ) ) and ( iCount < 50 ) and not CharInSet( Source[ iEnd ], [ #10, #13 ] ) do
  begin
    Inc( iEnd );
    Inc( iCount );
  end;

  // Truncated only when the 50-char cap was hit with more non-EOL content remaining.
  var bTruncated    := ( iCount >= 50 ) and ( iEnd <= Length( Source ) ) and not CharInSet( Source[ iEnd ], [ #10, #13 ] );

  Result            := Trim( Copy( Source, StartPos, iEnd - StartPos ) );
  if bTruncated then
    Result          := Result + '...';
end;

{ TUnreachableCodeItem }

function TUnreachableCodeItem.ReasonText: string;
begin
  case Reason of
    urAfterExit: Result := 'After Exit';
    urAfterRaise: Result := 'After Raise';
    urAfterBreak: Result := 'After Break';
    urAfterContinue: Result := 'After Continue';
    urAfterHalt: Result := 'After Halt';
    urAfterAbort: Result := 'After Abort';
  else
    Result          := 'Unknown';
  end;
end;

{ TUnreachableCodeScanner }

constructor TUnreachableCodeScanner.Create;
begin
  inherited Create;
  FItems            := TList<TUnreachableCodeItem>.Create;
  FOwnRoutines      := TStringList.Create;
  FOwnRoutines.CaseSensitive := False;
  FOwnRoutines.Sorted := True;
  FOwnRoutines.Duplicates := dupIgnore;
  FDefines          := TStringList.Create;
  FDefines.CaseSensitive := False;
  FDefines.Sorted   := True;
  FDefines.Duplicates := dupIgnore;
  SetTarget( 'Win64', '' );
end;

destructor TUnreachableCodeScanner.Destroy;
begin
  FDefines.Free;
  FOwnRoutines.Free;
  FItems.Free;
  inherited Destroy;
end;

procedure TUnreachableCodeScanner.Clear;
begin
  FItems.Clear;
end;

procedure TUnreachableCodeScanner.SetTarget( const Platform, ProjectDefines: string );
begin
  FDefines.Clear;
  FDefines.AddStrings( PredefinedSymbols( Platform ) );
  for var sDefine in ProjectDefines.Split( [ ';' ] ) do
    if ( Trim( sDefine ) <> '' ) and ( Pos( '$(', sDefine ) = 0 ) then // an unexpanded $(DCC_Define) is no symbol
      FDefines.Add( Trim( sDefine ) );
end;

function TUnreachableCodeScanner.IsDefineDefined( const DefineName: string ): Boolean;
begin
  Result            := FDefines.IndexOf( DefineName ) >= 0;
end;

function TUnreachableCodeScanner.EvaluateIfCondition( const Condition: string ): Integer;
begin
  var sCond         := Trim( Condition );
  if sCond = '' then
    Exit( -1 );

  var bNot          := False;
  if SameText( Copy( sCond, 1, 4 ), 'NOT ' ) then
  begin
    bNot            := True;
    sCond           := Trim( Copy( sCond, 5, MaxInt ) );
  end;

  var sName         := '';
  if SameText( Copy( sCond, 1, 7 ), 'Defined' ) and ( Pos( '(', sCond ) > 0 ) and ( sCond[ Length( sCond ) ] = ')' ) then
  begin
    var iOpen       := Pos( '(', sCond );
    if Trim( Copy( sCond, 8, iOpen - 8 ) ) <> '' then
      Exit( -1 );
    sName           := Trim( Copy( sCond, iOpen + 1, Length( sCond ) - iOpen - 1 ) );
  end
  else if ( Pos( '(', sCond ) = 0 ) and ( Pos( ' ', sCond ) = 0 ) then
    sName           := sCond; // {$IF MyDefine}

  // a complex expression (and / or / CompilerVersion ...) is not evaluated: skip the block
  if ( sName = '' ) or ( WordAt( sName, 1 ) <> sName ) then
    Exit( -1 );

  Result            := Ord( IsDefineDefined( sName ) );
  if bNot then
    Result          := 1 - Result;
end;

function TUnreachableCodeScanner.SkipInactiveBlock( const Source: string; Pos: Integer; AllowElse: Boolean ): Integer;
begin
  var iLen          := Length( Source );
  var iLevel        := 1;
  Result            := Pos;
  while Result <= iLen do
  begin
    var C           := Source[ Result ];
    if C = '''' then
      Result        := SkipString( Source, Result )
    else if IsCommentStart( Source, Result ) then
    begin
      if not IsDirectiveAt( Source, Result ) then
      begin
        Result      := SkipComment( Source, Result );
        Continue;
      end;

      var sName, sArg: string;
      var iAfter    := ReadDirective( Source, Result, sName, sArg );
      Result        := iAfter;

      // ENDIF / IFEND are tested by exact name before any IF: "IFEND" starts with "IF" and used to
      // count as a new nested block, so the inactive block never closed.
      if ( sName = 'ENDIF' ) or ( sName = 'IFEND' ) then
      begin
        Dec( iLevel );
        if iLevel = 0 then
          Exit;
      end
      else if ( sName = 'IF' ) or ( sName = 'IFDEF' ) or ( sName = 'IFNDEF' ) or ( sName = 'IFOPT' ) then
        Inc( iLevel )
      else if ( iLevel = 1 ) and AllowElse and ( sName = 'ELSE' ) then
        Exit
      else if ( iLevel = 1 ) and AllowElse and ( sName = 'ELSEIF' ) and ( EvaluateIfCondition( sArg ) = 1 ) then
        Exit; // a false or unknown $ELSEIF stays inactive
    end
    else
      Inc( Result );
  end;
end;

function TUnreachableCodeScanner.HandleDirective( const Source: string; Pos: Integer ): Integer;
begin
  var sName, sArg: string;
  Result            := ReadDirective( Source, Pos, sName, sArg );

  if sName = 'IFDEF' then
  begin
    if not IsDefineDefined( WordAt( sArg, 1 ) ) then
      Result        := SkipInactiveBlock( Source, Result, True );
  end
  else if sName = 'IFNDEF' then
  begin
    if IsDefineDefined( WordAt( sArg, 1 ) ) then
      Result        := SkipInactiveBlock( Source, Result, True );
  end
  else if sName = 'IF' then
  begin
    if EvaluateIfCondition( sArg ) <> 1 then
      Result        := SkipInactiveBlock( Source, Result, True );
  end
  else if sName = 'IFOPT' then
    Result          := SkipInactiveBlock( Source, Result, True ) // compiler options are unknown here: treat as inactive
  else if ( sName = 'ELSE' ) or ( sName = 'ELSEIF' ) then
    Result          := SkipInactiveBlock( Source, Result, False ); // the active branch has run: skip to the $ENDIF
  // ENDIF, IFEND and every other directive: carry on after it
end;

function TUnreachableCodeScanner.CheckTerminator( const Source: string; WordStart, WordEnd: Integer ): Integer;
begin
  Result            := WordEnd;
  var iLen          := Length( Source );
  var sWord         := LowerCase( Copy( Source, WordStart, WordEnd - WordStart ) );

  var iTerminator   := -1;
  for var j := Low( Terminators ) to High( Terminators ) do
    if Terminators[ j ].Keyword = sWord then
      iTerminator   := j;
  if iTerminator < 0 then
    Exit;

  // The unit declares its own routine or method of this name (procedure Abort; ...): an
  // unqualified call may well be that one, which returns.  Raise is a keyword and cannot be.
  if ( sWord <> 'raise' ) and ( FOwnRoutines.IndexOf( sWord ) >= 0 ) then
    Exit;

  // The character before the word, past blanks
  var k             := WordStart - 1;
  while ( k >= 1 ) and CharInSet( Source[ k ], [ ' ', #9 ] ) do
    Dec( k );

  // Obj.Abort / LoopState.Break: a method call, not the terminator
  if ( k >= 1 ) and CharInSet( Source[ k ], [ '.', '&' ] ) then
    Exit;

  // Used as a value or argument: X := Continue, Func( Continue ), Func( A, Continue )
  if ( k >= 1 ) and CharInSet( Source[ k ], [ '=', '(', ',' ] ) then
    Exit;

  // A parameter or variable named like the keyword: var / const / out Continue
  var sPrevWord     := '';
  if ( k >= 1 ) and IsIdentChar( Source[ k ] ) then
  begin
    var iPrevEnd    := k;
    while ( k > 1 ) and IsIdentChar( Source[ k - 1 ] ) do
      Dec( k );
    sPrevWord       := Copy( Source, k, iPrevEnd - k + 1 );
  end;
  if SameText( sPrevWord, 'var' ) or SameText( sPrevWord, 'const' ) or SameText( sPrevWord, 'out' ) then
    Exit;

  // A declaration of a routine or property with that name: procedure Abort; override;
  if SameText( sPrevWord, 'procedure' ) or SameText( sPrevWord, 'function' ) or SameText( sPrevWord, 'constructor' ) or
    SameText( sPrevWord, 'destructor' ) or SameText( sPrevWord, 'property' ) or SameText( sPrevWord, 'operator' ) then
    Exit;

  // An assignment target (Continue := False) or a declaration (Break: Boolean)
  var m             := WordEnd;
  while ( m <= iLen ) and CharInSet( Source[ m ], [ ' ', #9 ] ) do
    Inc( m );
  if ( m <= iLen ) and ( Source[ m ] = ':' ) then
    Exit;

  if IsConditionalTerminator( Source, WordStart ) then
    Exit;

  var iSemicolon    := FindStatementEnd( Source, WordEnd );
  if iSemicolon = 0 then
    Exit;
  Result            := iSemicolon + 1;

  var iNext         := SkipBlanksAndComments( Source, iSemicolon + 1 );
  if iNext > iLen then
    Exit;

  // A directive next means the following code belongs to another configuration's view of this
  // block ({$ENDIF}, {$ELSE}): reachable wherever the terminator is not compiled.
  if IsDirectiveAt( Source, iNext ) then
    Exit;

  if IsBlockEndWord( WordAt( Source, iNext ) ) then
    Exit;

  // The next case label (or a goto label) is reachable from elsewhere
  if IsLabelAt( Source, iNext ) then
    Exit;

  var rItem: TUnreachableCodeItem;
  rItem.FileName    := '';
  rItem.UnitName    := '';
  rItem.Line        := GetLineNumber( Source, iNext );
  rItem.Column      := 1;
  rItem.Reason      := Terminators[ iTerminator ].Reason;
  rItem.TerminatorLine := GetLineNumber( Source, WordStart );
  rItem.CodePreview := GetCodePreview( Source, iNext );
  FItems.Add( rItem );
end;

procedure TUnreachableCodeScanner.ScanSource( const Source, FileName, UnitName: string );
begin
  var iFirstNew     := FItems.Count;
  CollectOwnRoutineNames( Source, FOwnRoutines );
  var iLen          := Length( Source );
  var i             := 1;
  var bInCode       := False; // in the implementation section (or anywhere in a program / library)
  var bSawFirst     := False;

  while i <= iLen do
  begin
    var C           := Source[ i ];

    if C = '''' then
      i             := SkipString( Source, i )
    else if IsCommentStart( Source, i ) then
    begin
      if IsDirectiveAt( Source, i ) then
        i           := HandleDirective( Source, i )
      else
        i           := SkipComment( Source, i );
    end
    else if ( C = '&' ) and ( i < iLen ) and IsIdentStart( Source[ i + 1 ] ) then
    begin
      // &-escaped identifier: never a keyword
      Inc( i );
      while ( i <= iLen ) and IsIdentChar( Source[ i ] ) do
        Inc( i );
    end
    else if IsIdentStart( C ) then
    begin
      var iStart    := i;
      while ( i <= iLen ) and IsIdentChar( Source[ i ] ) do
        Inc( i );

      if not bSawFirst then
      begin
        // a unit's code starts at "implementation"; a program's or library's at once
        bSawFirst   := True;
        bInCode     := not SameText( Copy( Source, iStart, i - iStart ), 'unit' );
      end
      else if not bInCode then
        bInCode     := SameText( Copy( Source, iStart, i - iStart ), 'implementation' )
      else
        i           := CheckTerminator( Source, iStart, i );
    end
    else if CharInSet( C, [ '0'..'9', '$', '#', '%' ] ) then
    begin
      // a number or character code: its letters ($FF, 1E5) are not identifiers
      Inc( i );
      while ( i <= iLen ) and IsIdentChar( Source[ i ] ) do
        Inc( i );
    end
    else
      Inc( i );
  end;

  for var j := iFirstNew to FItems.Count - 1 do
  begin
    var rItem       := FItems[ j ];
    rItem.FileName  := FileName;
    rItem.UnitName  := UnitName;
    FItems[ j ]     := rItem;
  end;
end;

procedure TUnreachableCodeScanner.ScanFile( const FileName: string );
begin
  Clear;

  var oLines        := TStringList.Create;
  try
    oLines.LoadFromFile( FileName );
    ScanSource( oLines.Text, FileName, ChangeFileExt( ExtractFileName( FileName ), '' ) );
  finally
    oLines.Free;
  end;
end;

function TUnreachableCodeScanner.GetItems: TArray<TUnreachableCodeItem>;
begin
  Result            := FItems.ToArray;
end;

end.

