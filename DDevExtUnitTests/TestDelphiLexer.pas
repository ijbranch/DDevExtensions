unit TestDelphiLexer;

/// <summary>
/// Console-driven smoke tests for <c>DelphiLexer</c> (the hand-written Object Pascal
/// tokeniser every analyzer and the DFM parser build on). Verifies token classification
/// (keywords vs identifiers, literals, operators, brackets, comments, directives) and the
/// line/column contract (<c>Line</c> is 0-based, <c>Column</c> is 1-based) that the code
/// analyzers and their v3.19.9 navigation fixes rely on. Writes PASS/FAIL lines and a
/// summary to standard output; raises on the first failed assertion so the host program
/// exits non-zero.
/// </summary>

interface

/// <summary>Runs every lexer test, writing PASS lines and a summary; raises on failure.</summary>
procedure RunLexerTests;

implementation

uses
  System.SysUtils, System.Generics.Collections, System.Classes,
  DelphiLexer;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Assert(Condition: Boolean; const Msg: string);
begin
  if not Condition then
  begin
    Inc(TestsFailed);
    raise Exception.Create('Assertion failed: ' + Msg);
  end;
  Inc(TestsPassed);
end;

/// <summary>Tokenises Src and returns the ordered list of token kinds (values copied out).</summary>
function LexKinds(const Src: string): TArray<TTokenKind>;
var
  Lexer: TDelphiLexer;
  Tok: TToken;
  List: TList<TTokenKind>;
begin
  List := TList<TTokenKind>.Create;
  try
    Lexer := TDelphiLexer.Create('test.pas', UTF8String(Src));
    try
      while Lexer.NextToken(Tok) do
        List.Add(Tok.Kind);
    finally
      Lexer.Free;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function KindsToStr(const Kinds: array of TTokenKind): string;
var
  I: Integer;
begin
  Result := '';
  for I := Low(Kinds) to High(Kinds) do
  begin
    if I > Low(Kinds) then
      Result := Result + ', ';
    Result := Result + TokenKindToString(Kinds[I]);
  end;
end;

/// <summary>Asserts the tokenised kinds of Src match Expected exactly (in order and count).</summary>
procedure AssertKinds(const Src: string; const Expected: array of TTokenKind; const TestName: string);
var
  Actual: TArray<TTokenKind>;
  I: Integer;
  Ok: Boolean;
begin
  Actual := LexKinds(Src);
  Ok := Length(Actual) = Length(Expected);
  if Ok then
    for I := 0 to High(Actual) do
      if Actual[I] <> Expected[I] then
      begin
        Ok := False;
        Break;
      end;
  Assert(Ok, Format('%s: expected [%s] but got [%s]',
    [ TestName, KindsToStr(Expected), KindsToStr(Actual) ]));
end;

/// <summary>Returns the first token of the given kind, or nil; keeps Lexer alive via the out param.</summary>
function FirstTokenOfKind(Lexer: TDelphiLexer; Kind: TTokenKind): TToken;
var
  Tok: TToken;
begin
  Result := nil;
  while Lexer.NextToken(Tok) do
    if Tok.Kind = Kind then
      Exit(Tok);
end;

procedure TestProcedureTokens;
begin
  WriteLn('Test: procedure declaration tokens');
  AssertKinds('procedure Foo;', [ tkI_procedure, tkIdent, tkSemicolon ], 'procedure Foo;');
  WriteLn('  PASS');
end;

procedure TestKeywordVsIdentifier;
var
  Kinds: TArray<TTokenKind>;
begin
  WriteLn('Test: keyword vs identifier');
  Kinds := LexKinds('begin');
  Assert((Length(Kinds) = 1) and (Kinds[0] = tkI_begin), '''begin'' should be tkI_begin');
  Kinds := LexKinds('MyVar');
  Assert((Length(Kinds) = 1) and (Kinds[0] = tkIdent), '''MyVar'' should be tkIdent');
  WriteLn('  PASS');
end;

procedure TestNumericLiterals;
var
  Kinds: TArray<TTokenKind>;
begin
  WriteLn('Test: numeric literals (int / float / hex)');
  Kinds := LexKinds('42');
  Assert((Length(Kinds) = 1) and (Kinds[0] = tkInt), '''42'' should be tkInt');
  Kinds := LexKinds('3.14');
  Assert((Length(Kinds) = 1) and (Kinds[0] = tkFloat), '''3.14'' should be tkFloat');
  Kinds := LexKinds('$FF');
  Assert((Length(Kinds) = 1) and (Kinds[0] = tkInt), 'hex ''$FF'' should be tkInt');
  WriteLn('  PASS');
end;

procedure TestStringLiteral;
var
  Kinds: TArray<TTokenKind>;
begin
  WriteLn('Test: string literal');
  Kinds := LexKinds('''hello world''');
  Assert((Length(Kinds) = 1) and (Kinds[0] = tkString), 'quoted text should be a single tkString');
  WriteLn('  PASS');
end;

procedure TestOperators;
begin
  WriteLn('Test: multi-char operators (:= <> <= >= ..)');
  AssertKinds('a := b', [ tkIdent, tkAssign, tkIdent ], 'assignment');
  AssertKinds('a <> b', [ tkIdent, tkNotEqual, tkIdent ], 'not-equal');
  AssertKinds('a <= b', [ tkIdent, tkLessEqualThan, tkIdent ], 'less-equal');
  AssertKinds('a >= b', [ tkIdent, tkGreaterEqualThan, tkIdent ], 'greater-equal');
  AssertKinds('1..9', [ tkInt, tkRange, tkInt ], 'range');
  WriteLn('  PASS');
end;

procedure TestArrayIndexBrackets;
begin
  WriteLn('Test: bracket tokens (guards v3.19.9 magic-number bracket-depth fix)');
  // The Code Quality analyzer exempts literals inside [ ... ] using bracket depth;
  // that relies on tkLBracket/tkRBracket bracketing the inner expression.
  AssertKinds('A[1]', [ tkIdent, tkLBracket, tkInt, tkRBracket ], 'A[1]');
  AssertKinds('A[ I + 5 ]',
    [ tkIdent, tkLBracket, tkIdent, tkPlus, tkInt, tkRBracket ], 'A[ I + 5 ]');
  WriteLn('  PASS');
end;

procedure TestComments;
var
  Kinds: TArray<TTokenKind>;
begin
  WriteLn('Test: comment styles (// { } (* *))');
  Kinds := LexKinds('// line comment');
  Assert((Length(Kinds) = 1) and (Kinds[0] = tkComment), '// should be tkComment');
  Kinds := LexKinds('{ brace comment }');
  Assert((Length(Kinds) = 1) and (Kinds[0] = tkComment), '{ } should be tkComment');
  Kinds := LexKinds('(* paren comment *)');
  Assert((Length(Kinds) = 1) and (Kinds[0] = tkComment), '(* *) should be tkComment');
  WriteLn('  PASS');
end;

procedure TestDirective;
var
  Kinds: TArray<TTokenKind>;
begin
  WriteLn('Test: compiler directive');
  Kinds := LexKinds('{$IFDEF DEBUG}');
  Assert((Length(Kinds) = 1) and (Kinds[0] = tkDirective), '{$IFDEF} should be tkDirective');
  WriteLn('  PASS');
end;

procedure TestLineIsZeroBasedColumnOneBased;
var
  Lexer: TDelphiLexer;
  Tok, ProcTok: TToken;
begin
  WriteLn('Test: Line is 0-based, Column is 1-based (analyzer navigation contract)');
  // Line 1 (index 0): 'unit X;'  | Line 2 (index 1): 'procedure Foo;'
  Lexer := TDelphiLexer.Create('test.pas', UTF8String('unit X;'#13#10'procedure Foo;'));
  try
    Assert(Lexer.NextToken(Tok), 'should read first token');
    Assert(Tok.Line = 0, 'first line is 0-based (expected 0, got ' + IntToStr(Tok.Line) + ')');
    Assert(Tok.Column = 1, 'first column is 1-based (expected 1, got ' + IntToStr(Tok.Column) + ')');

    ProcTok := FirstTokenOfKind(Lexer, tkI_procedure);
    Assert(ProcTok <> nil, 'should find the procedure keyword');
    Assert(ProcTok.Line = 1, 'second source line reports Line=1 (got ' + IntToStr(ProcTok.Line) + ')');
    Assert(ProcTok.Column = 1, 'procedure starts at column 1 (got ' + IntToStr(ProcTok.Column) + ')');
  finally
    Lexer.Free;
  end;
  WriteLn('  PASS');
end;

procedure RunLexerTests;
begin
  WriteLn('DelphiLexer Tests:');
  WriteLn('------------------');
  TestProcedureTokens;
  TestKeywordVsIdentifier;
  TestNumericLiterals;
  TestStringLiteral;
  TestOperators;
  TestArrayIndexBrackets;
  TestComments;
  TestDirective;
  TestLineIsZeroBasedColumnOneBased;
  WriteLn;
  WriteLn(Format('Lexer Test Summary: Passed: %d  Failed: %d', [ TestsPassed, TestsFailed ]));
end;

end.
