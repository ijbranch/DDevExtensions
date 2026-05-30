unit TestDelphiExpr;

/// <summary>
/// Console-driven tests for <c>DelphiExpr</c>, the expression-tree evaluator behind $IF
/// conditions. Tests the arithmetic/boolean node classes directly (literals, binary ops,
/// int/float coercion, unary minus, division-by-zero error path, relational and boolean
/// operators) and a few end-to-end <c>TExpressionParser.Parse</c> cases. Writes PASS lines
/// + a summary; raises on first failure.
/// </summary>

interface

/// <summary>Runs every expression test, writing PASS lines and a summary; raises on failure.</summary>
procedure RunExprTests;

implementation

uses
  System.SysUtils,
  DelphiLexer, DelphiExpr;

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

/// <summary>Builds a literal arithmetic node.</summary>
function Lit(Kind: TTokenKind; const Value: string): IExprNode;
begin
  Result := TExprNodeConst.Create(Kind, Value);
end;

procedure TestConstants;
var
  V: TExprNodeValueRec;
begin
  WriteLn('Test: literal constants (int / float / string)');
  Assert(Lit(tkInt, '42').GetValue(V) and (V.Typ = vkIsInt) and (V.ValueInt = 42), 'int 42');
  Assert(Lit(tkFloat, '3.5').GetValue(V) and (V.Typ = vkIsFloat) and (Abs(V.ValueFloat - 3.5) < 1E-9), 'float 3.5');
  Assert(Lit(tkString, 'abc').GetValue(V) and (V.Typ = vkIsString) and (V.ValueStr = 'abc'), 'string abc');
  WriteLn('  PASS');
end;

procedure TestArithmetic;
var
  V: TExprNodeValueRec;
  Node: IExprNode;
begin
  WriteLn('Test: arithmetic (+ * unary-minus, int/float coercion)');
  // 2 + 3 = 5 (int)
  Node := TExprNodeBinOp.Create(tkPlus, '+', Lit(tkInt, '2'), Lit(tkInt, '3'));
  Assert(Node.GetValue(V) and (V.Typ = vkIsInt) and (V.ValueInt = 5), '2 + 3 = 5');
  // 4 * 5 = 20 (int)
  Node := TExprNodeBinOp.Create(tkMultiply, '*', Lit(tkInt, '4'), Lit(tkInt, '5'));
  Assert(Node.GetValue(V) and (V.ValueInt = 20), '4 * 5 = 20');
  // 2 + 3.0 = 5.0 (int+float -> float)
  Node := TExprNodeBinOp.Create(tkPlus, '+', Lit(tkInt, '2'), Lit(tkFloat, '3.0'));
  Assert(Node.GetValue(V) and (V.Typ = vkIsFloat) and (Abs(V.ValueFloat - 5.0) < 1E-9), '2 + 3.0 = 5.0 (float)');
  // -(7) = -7
  Node := TExprNodeUnaryMinus.Create(Lit(tkInt, '7'));
  Assert(Node.GetValue(V) and (V.ValueInt = -7), 'unary minus -7');
  WriteLn('  PASS');
end;

procedure TestDivByZero;
var
  V: TExprNodeValueRec;
  Node: IExprNode;
begin
  WriteLn('Test: float division by zero is a handled error (not a crash)');
  Node := TExprNodeBinOp.Create(tkDivide, '/', Lit(tkFloat, '1.0'), Lit(tkFloat, '0.0'));
  Assert((not Node.GetValue(V)) and (V.Error <> ''), 'float / 0 returns False with an error message');
  WriteLn('  PASS');
end;

procedure TestBooleanNodes;
var
  Err: string;
  BNode: IBoolNode;
begin
  WriteLn('Test: boolean nodes (const / not / relop / and / or)');
  Err := '';
  Assert(TBoolNodeConst.Create(True).GetValue(Err) and (Err = ''), 'const True');
  Err := '';
  Assert(not TBoolNodeConst.Create(False).GetValue(Err), 'const False');
  Err := '';
  Assert(not TBoolNodeNot.Create(TBoolNodeConst.Create(True)).GetValue(Err), 'not True = False');

  // 5 > 3 = True ; 5 < 3 = False ; 4 = 4 = True
  Err := '';
  BNode := TBoolNodeRelOp.Create(tkGreaterThan, '>', Lit(tkInt, '5'), Lit(tkInt, '3'));
  Assert(BNode.GetValue(Err) and (Err = ''), '5 > 3 = True');
  Err := '';
  BNode := TBoolNodeRelOp.Create(tkLessThan, '<', Lit(tkInt, '5'), Lit(tkInt, '3'));
  Assert(not BNode.GetValue(Err), '5 < 3 = False');
  Err := '';
  BNode := TBoolNodeRelOp.Create(tkEqual, '=', Lit(tkInt, '4'), Lit(tkInt, '4'));
  Assert(BNode.GetValue(Err), '4 = 4 = True');

  // True and False = False ; True or False = True
  Err := '';
  BNode := TBoolNodeOp.Create(tkI_And, 'and', TBoolNodeConst.Create(True), TBoolNodeConst.Create(False));
  Assert(not BNode.GetValue(Err), 'True and False = False');
  Err := '';
  BNode := TBoolNodeOp.Create(tkI_Or, 'or', TBoolNodeConst.Create(True), TBoolNodeConst.Create(False));
  Assert(BNode.GetValue(Err), 'True or False = True');
  WriteLn('  PASS');
end;

/// <summary>Parses and evaluates a $IF-style boolean expression end-to-end.</summary>
function EvalExpr(const Expr: string): Boolean;
var
  Lexer: TDelphiLexer;
  Parser: TExpressionParser;
begin
  Lexer := TDelphiLexer.Create('expr', UTF8String(Expr));
  try
    Parser := TExpressionParser.Create(Lexer);
    try
      Result := Parser.Parse;
    finally
      Parser.Free;
    end;
  finally
    Lexer.Free;
  end;
end;

procedure TestParserEndToEnd;
begin
  WriteLn('Test: TExpressionParser end-to-end (relational + precedence)');
  Assert(EvalExpr('5 > 3'), '''5 > 3'' = True');
  Assert(not EvalExpr('3 > 5'), '''3 > 5'' = False');
  Assert(EvalExpr('1 + 2 = 3'), '''1 + 2 = 3'' = True');
  Assert(EvalExpr('2 * 3 = 6'), '''2 * 3 = 6'' = True');
  Assert(EvalExpr('10 - 4 * 2 = 2'), '''10 - 4 * 2 = 2'' = True (precedence)');
  WriteLn('  PASS');
end;

procedure RunExprTests;
begin
  WriteLn('DelphiExpr Tests:');
  WriteLn('-----------------');
  TestConstants;
  TestArithmetic;
  TestDivByZero;
  TestBooleanNodes;
  TestParserEndToEnd;
  WriteLn;
  WriteLn(Format('Expr Test Summary: Passed: %d  Failed: %d', [ TestsPassed, TestsFailed ]));
end;

end.
