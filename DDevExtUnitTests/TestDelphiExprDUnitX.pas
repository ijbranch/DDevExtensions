unit TestDelphiExprDUnitX;

/// <summary>
/// DUnitX test fixture for <c>DelphiExpr</c>, the expression-tree evaluator behind
/// <c>{$IF}</c> conditions.  Drives the arithmetic and boolean node classes directly
/// (literals, binary operators, int/float coercion, unary minus, the division-by-zero
/// error path, relational and boolean operators) and runs a few end-to-end
/// <c>TExpressionParser.Parse</c> cases.
/// </summary>
/// <remarks>
/// Converted from the retired console harness <c>TestDelphiExpr.pas</c>.  The legacy
/// harness folded "evaluation succeeded" and "value is right" into one condition; here
/// each is its own assertion, so a failure says which part broke.
/// </remarks>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising the $IF expression nodes and parser.</summary>
  [TestFixture]
  TTestDelphiExpr = class
  public
    /// <summary>
    /// Proves integer, float and string literal nodes evaluate successfully to their own
    /// value with the matching value kind, which every operator node builds on.
    /// </summary>
    [Test]
    procedure TestConstants;
    /// <summary>
    /// Proves integer addition and multiplication stay integers, int plus float is
    /// promoted to float, and unary minus negates; a wrong promotion would make
    /// <c>{$IF CompilerVersion &gt;= 37.0}</c>-style comparisons misbehave.
    /// </summary>
    [Test]
    procedure TestArithmetic;
    /// <summary>
    /// Proves float division by zero is reported as a failed evaluation with an error
    /// message, not raised; the preprocessor runs inside the IDE, where an unhandled
    /// exception would surface to the user.
    /// </summary>
    [Test]
    procedure TestDivByZero;
    /// <summary>
    /// Proves the boolean constant, not, relational (&gt;, &lt;, =) and and/or nodes each
    /// give the right truth value, and that a successful evaluation leaves the error empty.
    /// </summary>
    [Test]
    procedure TestBooleanNodes;
    /// <summary>
    /// Proves the parser turns lexed text into a tree that evaluates correctly, including
    /// operator precedence (<c>10 - 4 * 2 = 2</c> holds only when <c>*</c> binds tighter).
    /// </summary>
    [Test]
    procedure TestParserEndToEnd;
  end;

implementation

uses
  System.SysUtils, DelphiLexer, DelphiExpr;

/// <summary>Builds a literal arithmetic node.</summary>
/// <param name="AKind">Token kind of the literal (<c>tkInt</c>, <c>tkFloat</c> or <c>tkString</c>).</param>
/// <param name="AValue">Literal text as the lexer would supply it.</param>
/// <returns>A constant node holding the literal.</returns>
function Lit( AKind: TTokenKind; const AValue: string ): IExprNode;
begin
  Result := TExprNodeConst.Create( AKind, AValue );
end;

/// <summary>Lexes, parses and evaluates a $IF-style boolean expression.</summary>
/// <param name="AExpression">Expression text, for example <c>5 &gt; 3</c>.</param>
/// <returns>The truth value the parser computes for AExpression.</returns>
function EvalExpr( const AExpression: string ): Boolean;
begin
  var oLexer := TDelphiLexer.Create( 'expr', UTF8String( AExpression ) );
  try
    var oParser := TExpressionParser.Create( oLexer );
    try
      Result := oParser.Parse;
    finally
      oParser.Free;
    end;
  finally
    oLexer.Free;
  end;
end;

{ TTestDelphiExpr }

procedure TTestDelphiExpr.TestConstants;
var
  rValue: TExprNodeValueRec;
begin
  Assert.IsTrue( Lit( tkInt, '42' ).GetValue( rValue ), 'int 42 evaluates' );
  Assert.AreEqual<TValueKind>( vkIsInt, rValue.Typ, 'int 42 kind' );
  Assert.AreEqual<Int64>( 42, rValue.ValueInt, 'int 42 value' );

  Assert.IsTrue( Lit( tkFloat, '3.5' ).GetValue( rValue ), 'float 3.5 evaluates' );
  Assert.AreEqual<TValueKind>( vkIsFloat, rValue.Typ, 'float 3.5 kind' );
  Assert.AreEqual( 3.5, rValue.ValueFloat, 1E-9, 'float 3.5 value' );

  Assert.IsTrue( Lit( tkString, 'abc' ).GetValue( rValue ), 'string abc evaluates' );
  Assert.AreEqual<TValueKind>( vkIsString, rValue.Typ, 'string abc kind' );
  Assert.AreEqual( 'abc', rValue.ValueStr, 'string abc value' );
end;

procedure TTestDelphiExpr.TestArithmetic;
var
  rValue: TExprNodeValueRec;
begin
  var intfNode: IExprNode := TExprNodeBinOp.Create( tkPlus, '+', Lit( tkInt, '2' ), Lit( tkInt, '3' ) );
  Assert.IsTrue( intfNode.GetValue( rValue ), '2 + 3 evaluates' );
  Assert.AreEqual<TValueKind>( vkIsInt, rValue.Typ, '2 + 3 stays an integer' );
  Assert.AreEqual<Int64>( 5, rValue.ValueInt, '2 + 3 = 5' );

  intfNode := TExprNodeBinOp.Create( tkMultiply, '*', Lit( tkInt, '4' ), Lit( tkInt, '5' ) );
  Assert.IsTrue( intfNode.GetValue( rValue ), '4 * 5 evaluates' );
  Assert.AreEqual<Int64>( 20, rValue.ValueInt, '4 * 5 = 20' );

  intfNode := TExprNodeBinOp.Create( tkPlus, '+', Lit( tkInt, '2' ), Lit( tkFloat, '3.0' ) );
  Assert.IsTrue( intfNode.GetValue( rValue ), '2 + 3.0 evaluates' );
  Assert.AreEqual<TValueKind>( vkIsFloat, rValue.Typ, 'int + float is promoted to float' );
  Assert.AreEqual( 5.0, rValue.ValueFloat, 1E-9, '2 + 3.0 = 5.0' );

  intfNode := TExprNodeUnaryMinus.Create( Lit( tkInt, '7' ) );
  Assert.IsTrue( intfNode.GetValue( rValue ), '-( 7 ) evaluates' );
  Assert.AreEqual<Int64>( -7, rValue.ValueInt, 'unary minus gives -7' );
end;

procedure TTestDelphiExpr.TestDivByZero;
var
  rValue: TExprNodeValueRec;
begin
  var intfNode: IExprNode := TExprNodeBinOp.Create( tkDivide, '/', Lit( tkFloat, '1.0' ), Lit( tkFloat, '0.0' ) );
  Assert.IsFalse( intfNode.GetValue( rValue ), 'float / 0 reports failure' );
  Assert.AreNotEqual( '', rValue.Error, 'float / 0 carries an error message' );
end;

procedure TTestDelphiExpr.TestBooleanNodes;
begin
  var sError := '';
  var intfNode: IBoolNode := TBoolNodeConst.Create( True );
  Assert.IsTrue( intfNode.GetValue( sError ), 'const True' );
  Assert.AreEqual( '', sError, 'const True leaves no error' );

  sError   := '';
  intfNode := TBoolNodeConst.Create( False );
  Assert.IsFalse( intfNode.GetValue( sError ), 'const False' );

  sError   := '';
  intfNode := TBoolNodeNot.Create( TBoolNodeConst.Create( True ) );
  Assert.IsFalse( intfNode.GetValue( sError ), 'not True = False' );

  sError   := '';
  intfNode := TBoolNodeRelOp.Create( tkGreaterThan, '>', Lit( tkInt, '5' ), Lit( tkInt, '3' ) );
  Assert.IsTrue( intfNode.GetValue( sError ), '5 > 3 = True' );
  Assert.AreEqual( '', sError, '5 > 3 leaves no error' );

  sError   := '';
  intfNode := TBoolNodeRelOp.Create( tkLessThan, '<', Lit( tkInt, '5' ), Lit( tkInt, '3' ) );
  Assert.IsFalse( intfNode.GetValue( sError ), '5 < 3 = False' );

  sError   := '';
  intfNode := TBoolNodeRelOp.Create( tkEqual, '=', Lit( tkInt, '4' ), Lit( tkInt, '4' ) );
  Assert.IsTrue( intfNode.GetValue( sError ), '4 = 4 = True' );

  sError   := '';
  intfNode := TBoolNodeOp.Create( tkI_And, 'and', TBoolNodeConst.Create( True ), TBoolNodeConst.Create( False ) );
  Assert.IsFalse( intfNode.GetValue( sError ), 'True and False = False' );

  sError   := '';
  intfNode := TBoolNodeOp.Create( tkI_Or, 'or', TBoolNodeConst.Create( True ), TBoolNodeConst.Create( False ) );
  Assert.IsTrue( intfNode.GetValue( sError ), 'True or False = True' );
end;

procedure TTestDelphiExpr.TestParserEndToEnd;
begin
  Assert.IsTrue( EvalExpr( '5 > 3' ), '''5 > 3'' = True' );
  Assert.IsFalse( EvalExpr( '3 > 5' ), '''3 > 5'' = False' );
  Assert.IsTrue( EvalExpr( '1 + 2 = 3' ), '''1 + 2 = 3'' = True' );
  Assert.IsTrue( EvalExpr( '2 * 3 = 6' ), '''2 * 3 = 6'' = True' );
  Assert.IsTrue( EvalExpr( '10 - 4 * 2 = 2' ), '''10 - 4 * 2 = 2'' = True (precedence)' );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestDelphiExpr );

end.
