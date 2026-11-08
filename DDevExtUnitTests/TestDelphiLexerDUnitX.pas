unit TestDelphiLexerDUnitX;

/// <summary>
/// DUnitX test fixture for <c>DelphiLexer</c> - the hand-written Object Pascal
/// tokeniser that every code analyser and the DFM parser build on.  Covers token
/// classification (keywords against identifiers, literals, operators, brackets,
/// comments, directives) and the line/column contract (<c>Line</c> is 0-based,
/// <c>Column</c> is 1-based) that the analysers' v3.19.9 navigation fixes rely on.
/// </summary>
/// <remarks>
/// Converted from the retired console harness <c>TestDelphiLexer.pas</c>.  Token
/// sequences are compared as comma-separated kind names, so a failure shows the whole
/// sequence the lexer produced rather than the first differing element, and a token
/// count mismatch fails the same assertion as a wrong kind.
/// </remarks>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising the Delphi lexer's token kinds and positions.</summary>
  [TestFixture]
  TTestDelphiLexer = class
  public
    /// <summary>
    /// Proves a routine header splits into keyword, identifier and semicolon, so the
    /// analysers that look for <c>tkI_procedure</c> followed by a name can find one.
    /// </summary>
    [Test]
    procedure TestProcedureTokens;
    /// <summary>
    /// Proves a reserved word is classified as its keyword kind and an ordinary name as
    /// <c>tkIdent</c>; the analysers would otherwise mistake keywords for symbols.
    /// </summary>
    [Test]
    procedure TestKeywordVsIdentifier;
    /// <summary>
    /// Proves decimal integers, floats and <c>$</c>-prefixed hex literals each lex as a
    /// single token of the right numeric kind (the magic-number analyser keys on them).
    /// </summary>
    [Test]
    procedure TestNumericLiterals;
    /// <summary>Proves a quoted literal containing a space is one <c>tkString</c> token, not split at the space.</summary>
    [Test]
    procedure TestStringLiteral;
    /// <summary>
    /// Proves the two-character operators <c>:=</c>, <c>&lt;&gt;</c>, <c>&lt;=</c>,
    /// <c>&gt;=</c> and <c>..</c> each lex as one token, not as two single-character ones.
    /// </summary>
    [Test]
    procedure TestOperators;
    /// <summary>
    /// Proves <c>[</c> and <c>]</c> bracket the inner index expression as their own
    /// tokens; the Code Quality analyser's bracket-depth exemption for array-index
    /// literals (v3.19.9) depends on it.
    /// </summary>
    [Test]
    procedure TestArrayIndexBrackets;
    /// <summary>Proves all three comment styles (<c>//</c>, braces, parenthesis-star) lex as a single <c>tkComment</c>.</summary>
    [Test]
    procedure TestComments;
    /// <summary>Proves a brace beginning with <c>$</c> is a <c>tkDirective</c>, not a comment, so the preprocessor sees it.</summary>
    [Test]
    procedure TestDirective;
    /// <summary>
    /// Proves the position contract: the first token is Line 0, Column 1, and a token
    /// at the start of the second source line is Line 1, Column 1.  Analyser navigation
    /// adds one to <c>Line</c>; an off-by-one here lands every jump on the wrong line.
    /// </summary>
    [Test]
    procedure TestLineIsZeroBasedColumnOneBased;
    /// <summary>
    /// Proves a Delphi 12 multi-line string (<c>'''</c> to <c>'''</c>, including the five-quote
    /// form) is one <c>tkString</c>, so the keywords, braces and apostrophes inside it are not
    /// lexed as code, and that the next token's line accounts for the string's lines.
    /// </summary>
    [Test]
    procedure TestMultilineString;
    /// <summary>
    /// Proves an <c>&amp;</c>-escaped reserved word (<c>&amp;End</c>, <c>&amp;Type</c>) is one
    /// <c>tkIdent</c>; it used to lex as <c>&amp;</c> plus the keyword, so an analyser counting
    /// begin/end saw a phantom <c>end</c>.
    /// </summary>
    [Test]
    procedure TestEscapedIdentifier;
    /// <summary>Proves binary literals (<c>%1010</c>) and digit separators (<c>1_000</c>, <c>$FF_FF</c>) are single <c>tkInt</c> tokens.</summary>
    [Test]
    procedure TestBinaryLiteralAndDigitSeparators;
    /// <summary>
    /// Proves malformed UTF-8 (a lead byte with its continuation bytes missing, at the end of the
    /// text and mid-text) lexes to a finite token stream without reading past the text.
    /// </summary>
    [Test]
    procedure TestTruncatedUtf8;
    /// <summary>
    /// Proves the file reader decodes a UTF-16 file with a BOM to the same text (it used to read
    /// twice the file's length as characters) and a BOM-less UTF-8 file as UTF-8, not ANSI - even when
    /// a read limit cuts a multi-byte character in half at the end of the block.
    /// </summary>
    [Test]
    procedure TestFileReaderEncodings;
    /// <summary>
    /// Proves <c>NextTokenNoComment</c> skips comments and other directives but stops at an include
    /// directive (<c>{$I file}</c>, <c>{$INCLUDE file}</c>), and not at the <c>{$I+}</c> switch.  The
    /// test used to compare the arguments the wrong way round, so it never stopped.
    /// </summary>
    [Test]
    procedure TestNextTokenNoCommentStopsAtInclude;
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, System.IOUtils, System.Generics.Collections, DelphiLexer;

/// <summary>Tokenises ASource and returns the ordered list of token kinds.</summary>
/// <param name="ASource">Object Pascal source text to tokenise.</param>
/// <returns>The kinds of every token the lexer produced, in source order.</returns>
function LexKinds( const ASource: string ): TArray<TTokenKind>;
begin
  var oList := TList<TTokenKind>.Create;
  try
    var oLexer := TDelphiLexer.Create( 'test.pas', UTF8String( ASource ) );
    try
      var oToken: TToken;
      while oLexer.NextToken( oToken ) do oList.Add( oToken.Kind );
    finally
      oLexer.Free;
    end;

    Result := oList.ToArray;
  finally
    oList.Free;
  end;
end;

/// <summary>Formats token kinds as "tkIdent, tkAssign, tkIdent" for whole-sequence comparison.</summary>
/// <param name="AKinds">Token kinds to format.</param>
/// <returns>The kind names joined with a comma and a space; empty for no kinds.</returns>
function KindsText( const AKinds: array of TTokenKind ): string;
begin
  Result := '';
  for var eKind in AKinds do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + TokenKindToString( eKind );
  end;
end;

/// <summary>Asserts that ASource tokenises to exactly AExpected, in order and count.</summary>
/// <param name="ASource">Object Pascal source text to tokenise.</param>
/// <param name="AExpected">The token kinds the lexer must produce.</param>
/// <param name="ACaseName">Names the case in the failure message.</param>
procedure AssertKinds( const ASource: string; const AExpected: array of TTokenKind; const ACaseName: string );
begin
  Assert.AreEqual( KindsText( AExpected ), KindsText( LexKinds( ASource ) ), ACaseName );
end;

/// <summary>Reads tokens from ALexer until one of kind AKind is found.</summary>
/// <param name="ALexer">Lexer to read from; it keeps ownership of the token returned.</param>
/// <param name="AKind">Token kind to look for.</param>
/// <returns>The first token of kind AKind, or nil when the source runs out first.</returns>
function FirstTokenOfKind( ALexer: TDelphiLexer; AKind: TTokenKind ): TToken;
begin
  Result := nil;

  var oToken: TToken;
  while ALexer.NextToken( oToken ) do
    if oToken.Kind = AKind then Exit( oToken );
end;

{ TTestDelphiLexer }

procedure TTestDelphiLexer.TestProcedureTokens;
begin
  AssertKinds( 'procedure Foo;', [ tkI_procedure, tkIdent, tkSemicolon ], 'procedure Foo;' );
end;

procedure TTestDelphiLexer.TestKeywordVsIdentifier;
begin
  AssertKinds( 'begin', [ tkI_begin ], '''begin'' is tkI_begin' );
  AssertKinds( 'MyVar', [ tkIdent ], '''MyVar'' is tkIdent' );
end;

procedure TTestDelphiLexer.TestNumericLiterals;
begin
  AssertKinds( '42', [ tkInt ], '''42'' is tkInt' );
  AssertKinds( '3.14', [ tkFloat ], '''3.14'' is tkFloat' );
  AssertKinds( '$FF', [ tkInt ], 'hex ''$FF'' is tkInt' );
end;

procedure TTestDelphiLexer.TestStringLiteral;
begin
  AssertKinds( '''hello world''', [ tkString ], 'quoted text is a single tkString' );
end;

procedure TTestDelphiLexer.TestOperators;
begin
  AssertKinds( 'a := b', [ tkIdent, tkAssign, tkIdent ], 'assignment' );
  AssertKinds( 'a <> b', [ tkIdent, tkNotEqual, tkIdent ], 'not-equal' );
  AssertKinds( 'a <= b', [ tkIdent, tkLessEqualThan, tkIdent ], 'less-equal' );
  AssertKinds( 'a >= b', [ tkIdent, tkGreaterEqualThan, tkIdent ], 'greater-equal' );
  AssertKinds( '1..9', [ tkInt, tkRange, tkInt ], 'range' );
end;

procedure TTestDelphiLexer.TestArrayIndexBrackets;
begin
  AssertKinds( 'A[1]', [ tkIdent, tkLBracket, tkInt, tkRBracket ], 'A[1]' );
  AssertKinds( 'A[ I + 5 ]', [ tkIdent, tkLBracket, tkIdent, tkPlus, tkInt, tkRBracket ], 'A[ I + 5 ]' );
end;

procedure TTestDelphiLexer.TestComments;
begin
  AssertKinds( '// line comment', [ tkComment ], '// is tkComment' );
  AssertKinds( '{ brace comment }', [ tkComment ], '{ } is tkComment' );
  AssertKinds( '(* paren comment *)', [ tkComment ], '(* *) is tkComment' );
end;

procedure TTestDelphiLexer.TestDirective;
begin
  AssertKinds( '{$IFDEF DEBUG}', [ tkDirective ], '{$IFDEF} is tkDirective' );
end;

procedure TTestDelphiLexer.TestLineIsZeroBasedColumnOneBased;
begin
  var oLexer := TDelphiLexer.Create( 'test.pas', UTF8String( 'unit X;'#13#10'procedure Foo;' ) );
  try
    var oToken: TToken;
    Assert.IsTrue( oLexer.NextToken( oToken ), 'reads the first token' );
    Assert.AreEqual<Integer>( 0, oToken.Line, 'first line is 0-based' );
    Assert.AreEqual<Integer>( 1, oToken.Column, 'first column is 1-based' );

    var oProcToken := FirstTokenOfKind( oLexer, tkI_procedure );
    Assert.IsNotNull( oProcToken, 'finds the procedure keyword' );
    Assert.AreEqual<Integer>( 1, oProcToken.Line, 'second source line reports Line 1' );
    Assert.AreEqual<Integer>( 1, oProcToken.Column, 'procedure starts at column 1' );
  finally
    oLexer.Free;
  end;
end;

procedure TTestDelphiLexer.TestMultilineString;
begin
  AssertKinds(
    'S := '''''' '#13#10 +
    '  begin { it''s not code'#13#10 +
    '  end'#13#10 +
    '  '''''';'#13#10 +
    'X',
    [ tkIdent, tkAssign, tkString, tkSemicolon, tkIdent ], 'three-quote multi-line string is one token' );

  AssertKinds(
    'S := '''''''''''#13#10 +
    '  holds ''''''three'''''' quotes'#13#10 +
    '  '''''''''';',
    [ tkIdent, tkAssign, tkString, tkSemicolon ], 'five-quote multi-line string is one token' );

  var oLexer := TDelphiLexer.Create( 'test.pas', UTF8String( 'S := '''''''#13#10'  a'#13#10'  '''''';'#13#10'X' ) );
  try
    Assert.IsNotNull( FirstTokenOfKind( oLexer, tkIdent ), 'finds S' );
    var oToken := FirstTokenOfKind( oLexer, tkIdent );   // X
    Assert.IsNotNull( oToken, 'finds X after the string' );
    Assert.AreEqual( 'X', oToken.Value, 'the token after the string is X' );
    Assert.AreEqual<Integer>( 3, oToken.Line, 'X is on the fourth line (0-based 3)' );
  finally
    oLexer.Free;
  end;

  AssertKinds( 'S := '''''''' + X;', [ tkIdent, tkAssign, tkString, tkPlus, tkIdent, tkSemicolon ],
    'the quote-character literal is an ordinary string' );
end;

procedure TTestDelphiLexer.TestEscapedIdentifier;
begin
  AssertKinds( 'X.&End := &Type;', [ tkIdent, tkQualifier, tkIdent, tkAssign, tkIdent, tkSemicolon ],
    '&End and &Type are identifiers' );
  AssertKinds( 'A & B', [ tkIdent, tkAmp, tkIdent ], 'a lone & is still a symbol' );
end;

procedure TTestDelphiLexer.TestBinaryLiteralAndDigitSeparators;
begin
  AssertKinds( 'X := %1010;', [ tkIdent, tkAssign, tkInt, tkSemicolon ], '%1010 is one integer' );
  AssertKinds( 'X := 1_000_000;', [ tkIdent, tkAssign, tkInt, tkSemicolon ], '1_000_000 is one integer' );
  AssertKinds( 'X := $FF_FF;', [ tkIdent, tkAssign, tkInt, tkSemicolon ], '$FF_FF is one integer' );
end;

/// <summary>Builds a UTF-8 string from raw bytes, with no code-page conversion.</summary>
/// <param name="ABytes">The bytes, in order.</param>
/// <returns>A UTF8String holding exactly ABytes.</returns>
function RawUtf8( const ABytes: array of Byte ): UTF8String;
begin
  SetLength( Result, Length( ABytes ) );
  for var i := 0 to High( ABytes ) do
    Result[ i + 1 ] := AnsiChar( ABytes[ i ] );
end;

procedure TTestDelphiLexer.TestTruncatedUtf8;
begin
  for var sText in [ RawUtf8( [ $41, $20, $E4 ] ), RawUtf8( [ $41, $20, $E4, $B8 ] ), RawUtf8( [ $41, $20, $F0, $9F ] ) ] do
  begin
    var oLexer := TDelphiLexer.Create( 'test.pas', sText );
    try
      var iCount := 0;
      var oToken: TToken;
      while oLexer.NextToken( oToken ) and ( iCount < 100 ) do
      begin
        Assert.IsTrue( oToken.EndIndex <= Length( sText ), 'no token runs past the end of the text' );
        Inc( iCount );
      end;
      Assert.IsTrue( iCount < 100, 'the token stream ends' );
    finally
      oLexer.Free;
    end;
  end;

  var oLexer := TDelphiLexer.Create( 'test.pas', RawUtf8( [ $41, $20, $E4, $20, $42 ] ) );
  try
    Assert.IsNotNull( FirstTokenOfKind( oLexer, tkIdent ), 'A is read' );
    var oB := FirstTokenOfKind( oLexer, tkIdent );
    Assert.IsNotNull( oB, 'B after the stray lead byte is read' );
    Assert.AreEqual( 'B', oB.Value, 'the stray byte does not swallow B' );
  finally
    oLexer.Free;
  end;
end;

procedure TTestDelphiLexer.TestFileReaderEncodings;
begin
  var sDir := IncludeTrailingPathDelimiter( TPath.GetTempPath ) + 'DDevExtLexerTest' + IntToStr( GetCurrentProcessId );
  ForceDirectories( sDir );
  try
    var sUtf16 := sDir + '\utf16.pas';
    TFile.WriteAllText( sUtf16, 'unit Größe;', TEncoding.Unicode );   // with BOM
    Assert.AreEqual( 'unit Größe;', UTF8ToString( LoadTextFileToUtf8String( sUtf16 ) ), 'UTF-16 LE with BOM' );

    var sUtf8 := sDir + '\utf8.pas';
    var oNoBom := TUTF8Encoding.Create( False );
    try
      TFile.WriteAllText( sUtf8, 'unit Größe;', oNoBom );   // no BOM
    finally
      oNoBom.Free;
    end;
    Assert.AreEqual( 'unit Größe;', UTF8ToString( LoadTextFileToUtf8String( sUtf8 ) ), 'UTF-8 without a BOM' );

    // A read limit that ends the text inside a two-byte "ö" (the reader stops at a 4 KB block
    // boundary; the "ö" straddles byte 8192): still UTF-8, not ANSI mojibake ("Ã").
    var sLong := sDir + '\long.pas';
    var oNoBom2 := TUTF8Encoding.Create( False );
    try
      TFile.WriteAllText( sLong, StringOfChar( 'a', 8191 ) + 'ö' + StringOfChar( 'b', 100 ), oNoBom2 );
    finally
      oNoBom2.Free;
    end;
    var sCut := UTF8ToString( LoadTextFileToUtf8String( sLong, 4096 ) );
    Assert.IsTrue( sCut.StartsWith( 'aaaa' ), 'the text before the cut is kept' );
    Assert.AreEqual( 0, Pos( 'Ã', sCut ), 'a sequence cut at the block end does not turn the file into ANSI' );
  finally
    TDirectory.Delete( sDir, True );
  end;
end;

procedure TTestDelphiLexer.TestNextTokenNoCommentStopsAtInclude;
begin
  var oLexer := TDelphiLexer.Create( 'test.pas',
    UTF8String( 'A { note } {$IFDEF X} {$I+} {$I Settings.inc} B (*$INCLUDE More.inc*) C' ) );
  try
    var sSeen := '';
    var oToken: TToken;
    while oLexer.NextTokenNoComment( oToken ) do
      sSeen := sSeen + oToken.Value + ' ';
    Assert.AreEqual( 'A {$I Settings.inc} B (*$INCLUDE More.inc*) C', Trim( sSeen ),
      'comments, $IFDEF and $I+ are skipped; the two include directives are returned' );
  finally
    oLexer.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestDelphiLexer );

end.
