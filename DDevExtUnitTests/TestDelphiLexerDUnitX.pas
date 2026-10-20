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
  end;

implementation

uses
  System.SysUtils, System.Generics.Collections, DelphiLexer;

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

initialization
  TDUnitX.RegisterTestFixture( TTestDelphiLexer );

end.
