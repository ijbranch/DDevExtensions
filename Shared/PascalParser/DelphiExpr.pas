{******************************************************************************}
{*                                                                            *}
{* Delphi Expression Parser                                                   *}
{*                                                                            *}
{* (C) 2005 Andreas Hausladen                                                 *}
{*                                                                            *}
{******************************************************************************}

unit DelphiExpr;

/// <summary>
/// Expression-tree builder used by the preprocessor to evaluate $IF (...) expressions. Splits
/// the parse into arithmetic IExprNode (returning Int/Float/String) and Boolean IBoolNode
/// (returning True/False) trees so operator precedence and type-checking are straightforward.
/// </summary>

interface

uses
  System.SysUtils, System.Classes, System.Contnrs, DelphiLexer;

type
  /// <summary>Discriminator for the runtime type of an evaluated TExprNode value.</summary>
  TValueKind = ( vkIsInt, vkIsFloat, vkIsString {, vkIsSet} );

  /// <summary>Dynamic array of TToken values used for bool-function argument lists.</summary>
  TDynTokenArray = array of TToken;

  /// <summary>Tagged union holding the result of evaluating an arithmetic IExprNode.</summary>
  TExprNodeValueRec = record
    /// <summary>Active value kind.</summary>
    Typ: TValueKind;
    /// <summary>Integer value (used when Typ = vkIsInt).</summary>
    ValueInt: Int64;
    /// <summary>Floating-point value (used when Typ = vkIsFloat).</summary>
    ValueFloat: Double;
    /// <summary>String value (used when Typ = vkIsString).</summary>
    ValueStr: string;
    /// <summary>Non-empty when evaluation produced an error.</summary>
    Error: string;
  end;

  /// <summary>Raised for unsupported operator combinations.</summary>
  EInvalidOp = class( Exception );

  /// <summary>Common interface for arithmetic expression nodes.</summary>
  IExprNode = interface
    /// <summary>Renders the node as expression source text, for diagnostics.</summary>
    /// <returns>The source representation of the node.</returns>
    function ToString: string;
    /// <summary>Evaluates the node.</summary>
    /// <param name="Value">Receives the result; its Error field carries the message when evaluation fails.</param>
    /// <returns>False when an error occurred.</returns>
    function GetValue( out Value: TExprNodeValueRec ): Boolean;
  end;

  /// <summary>Abstract base class for arithmetic expression nodes.</summary>
  TExprNode = class( TInterfacedObject, IExprNode )
  public
    /// <summary>Subclass-specific evaluation of the node.</summary>
    /// <param name="Value">Receives the result; its Error field carries the message when evaluation fails.</param>
    /// <returns>False when an error occurred.</returns>
    function GetValue( out Value: TExprNodeValueRec ): Boolean; virtual; abstract;
  end;

  /// <summary>Unary "-" applied to FOperand.</summary>
  TExprNodeUnaryMinus = class( TExprNode )
  private
    /// <summary>The expression being negated.</summary>
    FOperand: IExprNode;
  public
    /// <summary>Creates the node over its operand.</summary>
    /// <param name="AOperand">The expression to negate.</param>
    constructor Create( AOperand: IExprNode );
    /// <summary>Renders the node as '-' followed by the operand's text.</summary>
    /// <returns>The source representation of the node.</returns>
    function ToString: string; override;
    /// <summary>Evaluates the operand and negates an integer or float result; a string operand sets Value.Error.</summary>
    /// <param name="Value">Receives the negated result.</param>
    /// <returns>False when the operand could not be evaluated.</returns>
    function GetValue( out Value: TExprNodeValueRec ): Boolean; override;
  end;

  /// <summary>Bitwise "not" applied to FOperand.</summary>
  TExprNodeBitOpNeg = class( TExprNode )
  private
    /// <summary>The expression whose bits are inverted.</summary>
    FOperand: IExprNode;
  public
    /// <summary>Creates the node over its operand.</summary>
    /// <param name="AOperand">The expression whose bits are inverted.</param>
    constructor Create( AOperand: IExprNode );
    /// <summary>Renders the node as '~' followed by the operand's text.</summary>
    /// <returns>The source representation of the node.</returns>
    function ToString: string; override;
    /// <summary>Evaluates the operand and inverts the bits of an integer result; a float operand is an error.</summary>
    /// <param name="Value">Receives the inverted result.</param>
    /// <returns>False when the operand could not be evaluated or is a float.</returns>
    function GetValue( out Value: TExprNodeValueRec ): Boolean; override;
  end;

  /// <summary>Binary arithmetic / bitwise operator (FOperation) applied to FOperand1 and FOperand2.</summary>
  TExprNodeBinOp = class( TExprNode )
  private
    /// <summary>Token kind of the operator ( +, -, *, /, mod, or, xor, and ).</summary>
    FOperation: TTokenKind;
    /// <summary>Operator text as written, used by ToString and error messages.</summary>
    FOpName: string;
    /// <summary>Left-hand operand.</summary>
    FOperand1: IExprNode;
    /// <summary>Right-hand operand.</summary>
    FOperand2: IExprNode;
  public
    /// <summary>Creates the node from its operator and operands.</summary>
    /// <param name="AOperation">Token kind of the operator.</param>
    /// <param name="AOpName">Operator text as written.</param>
    /// <param name="AOperand1">Left-hand operand.</param>
    /// <param name="AOperand2">Right-hand operand.</param>
    constructor Create( AOperation: TTokenKind; const AOpName: string; AOperand1, AOperand2: IExprNode );
    /// <summary>Renders the node as a parenthesised infix expression.</summary>
    /// <returns>The source representation of the node.</returns>
    function ToString: string; override;
    /// <summary>
    /// Evaluates both operands and applies the operator: string + string concatenates, two integers give an integer, any other
    /// numeric mix gives a float.  Float division or mod by zero, and bitwise operators on floats, are errors.
    /// </summary>
    /// <param name="Value">Receives the result.</param>
    /// <returns>False when either operand fails or the operation is invalid for the operand types.</returns>
    function GetValue( out Value: TExprNodeValueRec ): Boolean; override;
  end;

  /// <summary>Literal constant node (integer, floating-point or string).</summary>
  TExprNodeConst = class( TExprNode )
  private
    /// <summary>Token kind of the literal ( tkInt, tkFloat, tkString, or tkIdent for True/False ).</summary>
    FKind: TTokenKind;
    /// <summary>Literal text as written.</summary>
    FValue: string;
  public
    /// <summary>Creates the node from a literal token.</summary>
    /// <param name="AKind">Token kind of the literal.</param>
    /// <param name="AValue">Literal text.</param>
    constructor Create( AKind: TTokenKind; const AValue: string );
    /// <summary>Returns the literal text.</summary>
    /// <returns>The source representation of the node.</returns>
    function ToString: string; override;
    /// <summary>Converts the literal into a value; the identifiers True and False become the integers 1 and 0.</summary>
    /// <param name="Value">Receives the converted value.</param>
    /// <returns>False when a float literal does not convert.</returns>
    /// <exception cref="Exception">An identifier other than True or False ( an internal error ).</exception>
    function GetValue( out Value: TExprNodeValueRec ): Boolean; override;
  end;

  /// <summary>Common interface for Boolean expression nodes.</summary>
  IBoolNode = interface
    /// <summary>Renders the node as expression source text, for diagnostics.</summary>
    /// <returns>The source representation of the node.</returns>
    function ToString: string;
    /// <summary>Evaluates the node.</summary>
    /// <param name="Error">Set to a message when evaluation fails; left unchanged otherwise.</param>
    /// <returns>The Boolean result ( False when an error occurred ).</returns>
    function GetValue( var Error: string ): Boolean;
  end;

  /// <summary>Abstract base class for Boolean expression nodes.</summary>
  TBoolNode = class( TInterfacedObject, IBoolNode )
  public
    /// <summary>Subclass-specific evaluation; sets Error on failure.</summary>
    /// <param name="Error">Set to a message when evaluation fails.</param>
    /// <returns>The Boolean result ( False when an error occurred ).</returns>
    function GetValue( var Error: string ): Boolean; virtual; abstract;
  end;

  /// <summary>Boolean binary operator (and/or/xor) applied to FLeft and FRight.</summary>
  TBoolNodeOp = class( TBoolNode )
  private
    /// <summary>Token kind of the operator ( tkI_And, tkI_Or or tkI_Xor ).</summary>
    FOperation: TTokenKind;
    /// <summary>Operator text as written, used by ToString and error messages.</summary>
    FOpName: string;
    /// <summary>Left-hand operand.</summary>
    FLeft: IBoolNode;
    /// <summary>Right-hand operand.</summary>
    FRight: IBoolNode;
  public
    /// <summary>Creates the node from its operator and operands.</summary>
    /// <param name="AOperation">Token kind of the operator.</param>
    /// <param name="AOpName">Operator text as written.</param>
    /// <param name="ALeft">Left-hand operand.</param>
    /// <param name="ARight">Right-hand operand.</param>
    constructor Create( AOperation: TTokenKind; const AOpName: string; ALeft, ARight: IBoolNode );
    /// <summary>Renders the node as a parenthesised infix expression.</summary>
    /// <returns>The source representation of the node.</returns>
    function ToString: string; override;
    /// <summary>Evaluates the left operand, then combines it with the right ( short-circuiting and/or ).</summary>
    /// <param name="Error">Set to a message when an operand fails or the operator is unknown.</param>
    /// <returns>The Boolean result ( False when an error occurred ).</returns>
    function GetValue( var Error: string ): Boolean; override;
  end;

  /// <summary>Logical "not" applied to FNode.</summary>
  TBoolNodeNot = class( TBoolNode )
  private
    /// <summary>The Boolean expression being negated.</summary>
    FNode: IBoolNode;
  public
    /// <summary>Creates the node over its operand.</summary>
    /// <param name="ANode">The Boolean expression to negate.</param>
    constructor Create( ANode: IBoolNode );
    /// <summary>Renders the node as 'not ' followed by the operand's text.</summary>
    /// <returns>The source representation of the node.</returns>
    function ToString: string; override;
    /// <summary>Evaluates the operand and negates it.</summary>
    /// <param name="Error">Set by the operand when its evaluation fails.</param>
    /// <returns>The negated result.</returns>
    function GetValue( var Error: string ): Boolean; override;
  end;

  /// <summary>Boolean literal.</summary>
  TBoolNodeConst = class( TBoolNode )
  private
    /// <summary>The literal value.</summary>
    FValue: Boolean;
  public
    /// <summary>Creates the node holding a fixed value.</summary>
    /// <param name="AValue">The literal value.</param>
    constructor Create( AValue: Boolean );
    /// <summary>Renders the value as 'True' or 'False'.</summary>
    /// <returns>The source representation of the node.</returns>
    function ToString: string; override;
    /// <summary>Returns the literal value; never fails.</summary>
    /// <param name="Error">Not used.</param>
    /// <returns>The literal value.</returns>
    function GetValue( var Error: string ): Boolean; override;
  end;

  {  TBoolNodeIdent = class(TBoolNode)
    private
      FIdent: string;
      FPreProc: TDelphiPreprocessor;
    public
      constructor Create(APreProc: TDelphiPreprocessor; const AIdent: string);
      function ToString: string; override;
      function GetValue(var Error: string): Boolean; override;
    end;}

    /// <summary>Adapter that exposes an arithmetic IExprNode as a Boolean node (non-zero = True).</summary>
  TBoolNodeExp = class( TBoolNode )
  private
    /// <summary>The arithmetic expression being tested.</summary>
    FExpr: IExprNode;
  public
    /// <summary>Creates the adapter over an arithmetic expression.</summary>
    /// <param name="AExpr">The arithmetic expression to test.</param>
    constructor Create( AExpr: IExprNode );
    /// <summary>Renders the wrapped expression in parentheses.</summary>
    /// <returns>The source representation of the node.</returns>
    function ToString: string; override;
    /// <summary>Evaluates the expression; an integer is True when non-zero, while a float or string is an error.</summary>
    /// <param name="Error">Set to a message when the expression fails or is not an integer.</param>
    /// <returns>The Boolean result ( False when an error occurred ).</returns>
    function GetValue( var Error: string ): Boolean; override;
  end;

  /// <summary>Relational operator (=, &lt;&gt;, &lt;=, &gt;=, &lt;, &gt;) applied to two arithmetic operands.</summary>
  TBoolNodeRelOp = class( TBoolNode )
  private
    /// <summary>Token kind of the relational operator.</summary>
    FRelOperation: TTokenKind;
    /// <summary>Operator text as written, used by ToString and error messages.</summary>
    FRelOpName: string;
    /// <summary>Left-hand operand.</summary>
    FLeft: IExprNode;
    /// <summary>Right-hand operand.</summary>
    FRight: IExprNode;
  public
    /// <summary>Creates the node from its operator and operands.</summary>
    /// <param name="ARelOperation">Token kind of the relational operator.</param>
    /// <param name="ARelOpName">Operator text as written.</param>
    /// <param name="ALeft">Left-hand operand.</param>
    /// <param name="ARight">Right-hand operand.</param>
    constructor Create( ARelOperation: TTokenKind; const ARelOpName: string;
      ALeft, ARight: IExprNode );
    /// <summary>Renders the node as a parenthesised infix expression.</summary>
    /// <returns>The source representation of the node.</returns>
    function ToString: string; override;
    /// <summary>
    /// Evaluates both operands and compares them: two strings compare as strings, two integers as integers, any other mix
    /// as floating-point values.
    /// </summary>
    /// <param name="Error">Set to the operands' messages when either fails, or when the operator is unknown.</param>
    /// <returns>The result of the comparison ( False when an error occurred ).</returns>
    function GetValue( var Error: string ): Boolean; override;
  end;

  /// <summary>Boolean equality operator (= or &lt;&gt;) comparing two Boolean operands.</summary>
  TBoolNodeBoolOp = class( TBoolNode )
  private
    /// <summary>Token kind of the operator ( tkEqual or tkNotEqual ).</summary>
    FOperation: TTokenKind;
    /// <summary>Operator text as written, used by ToString and error messages.</summary>
    FOpName: string;
    /// <summary>Left-hand operand.</summary>
    FLeft: IBoolNode;
    /// <summary>Right-hand operand.</summary>
    FRight: IBoolNode;
  public
    /// <summary>Creates the node from its operator and operands.</summary>
    /// <param name="AOperation">Token kind of the operator.</param>
    /// <param name="AOpName">Operator text as written.</param>
    /// <param name="ALeft">Left-hand operand.</param>
    /// <param name="ARight">Right-hand operand.</param>
    constructor Create( AOperation: TTokenKind; const AOpName: string; ALeft, ARight: IBoolNode );
    /// <summary>Renders the node as an infix expression ( without parentheses ).</summary>
    /// <returns>The source representation of the node.</returns>
    function ToString: string; override;
    /// <summary>Evaluates both operands and tests them for equality or inequality.</summary>
    /// <param name="Error">Set by an operand that fails, or to a message when the operator is unknown.</param>
    /// <returns>The result of the comparison ( False when the operator is unknown ).</returns>
    function GetValue( var Error: string ): Boolean; override;
  end;

  /// <summary>Discriminator passed to TExpressionParser.Match to control whether failure raises an exception.</summary>
  MatchFail = ( mfYes, mfNo );

  /// <summary>
  /// Recursive-descent parser that consumes tokens from a TDelphiLexer and produces an IBoolNode
  /// expression tree. Subclasses override the resolver hooks to plug in compile-time identifier
  /// look-ups for $IF/$IFDEF style expressions.
  /// </summary>
  TExpressionParser = class( TObject )
  private
    /// <summary>The current look-ahead token; nil at the end of the expression.</summary>
    Look: TToken;
    /// <summary>Lexer supplying the expression's tokens ( not owned ).</summary>
    FLexer: TDelphiLexer;
    /// <summary>Every token read so far ( not owned ), kept so the parser can back up with Rescan.</summary>
    FRescanTokens: TObjectList;
    /// <summary>Position in FRescanTokens of the next token to re-read; at or past the end, Next reads from the lexer.</summary>
    FRescanIndex: Integer;
  public
    /// <summary>Creates a parser reading from a lexer positioned at the start of the expression.</summary>
    /// <param name="ALexer">Lexer supplying the tokens; the caller keeps ownership.</param>
    constructor Create( ALexer: TDelphiLexer );
    /// <summary>Frees the rescan list ( not the tokens it references ).</summary>
    destructor Destroy; override;
  protected
    /// <summary>Resolves an identifier used in an arithmetic expression to a constant; the base class knows none.</summary>
    /// <param name="Name">The identifier.</param>
    /// <param name="Kind">Receives the token kind of the constant's value.</param>
    /// <param name="Value">Receives the constant's value as literal text.</param>
    /// <returns>True when the identifier names a constant.</returns>
    function GetConstValue( const Name: string; out Kind: TTokenKind; out Value: string ): Boolean; virtual;
    /// <summary>Resolves a bare identifier used as a Boolean; the base class treats only 'True' as True.</summary>
    /// <param name="Name">The identifier.</param>
    /// <returns>The identifier's Boolean value.</returns>
    function GetConstBoolValue( const Name: string ): Boolean; virtual;
    /// <summary>Tells whether an identifier is a Boolean function such as defined() or declared(); the base class has none.</summary>
    /// <param name="Name">The identifier.</param>
    /// <returns>True when Name is a Boolean function the parser should call through EvalBoolFunction.</returns>
    function IsBoolFunction( const Name: string ): Boolean; virtual;
    /// <summary>Evaluates a call to a Boolean function; the base class reports every function as unknown.</summary>
    /// <param name="IdentToken">Token holding the function name.</param>
    /// <param name="Args">The argument tokens.</param>
    /// <returns>The function's result.</returns>
    /// <exception cref="Exception">The base class raises for every function ( through ErrorMsg ).</exception>
    function EvalBoolFunction( IdentToken: TToken; const Args: TDynTokenArray ): Boolean; virtual;
    /// <summary>Reports a parse or evaluation error; the base class raises it, and descendants may redirect it.</summary>
    /// <param name="Msg">Format string of the message.</param>
    /// <param name="Args">Arguments for Msg.</param>
    /// <param name="Token">Token the error refers to, or nil.</param>
    /// <exception cref="Exception">Always, in the base class.</exception>
    procedure ErrorMsg( const Msg: string; const Args: array of const; Token: TToken ); virtual;
    /// <summary>Reports an error with no arguments and no token, through ErrorMsg.</summary>
    /// <param name="Msg">The message ( passed to ErrorMsg as a format string ).</param>
    /// <exception cref="Exception">Raised by the base ErrorMsg.</exception>
    procedure Error( const Msg: string );
  private
    /// <summary>Returns the next token of the expression, from the look-ahead cache when it holds one.</summary>
    /// <returns>The next token, or nil at the end of the expression.</returns>
    function NextCache: TToken; inline;
    /// <summary>Advances Look to the next token, re-reading the rescan list before asking the lexer.</summary>
    procedure Next;
    /// <summary>Backs the parser up so that the next call to Next returns Token again.</summary>
    /// <param name="Token">A token already read in this expression.</param>
    /// <exception cref="Exception">Token was never read ( an internal error, through ErrorMsg ).</exception>
    procedure Rescan( Token: TToken );
    /// <summary>Tests whether the look-ahead token is one of the given kinds.</summary>
    /// <param name="Tokens">The acceptable token kinds.</param>
    /// <returns>True when Look is not nil and its kind is in Tokens.</returns>
    function Match( const Tokens: array of TTokenKind ): Boolean; overload;
    /// <summary>Tests whether the look-ahead token is one of the given kinds, optionally treating a mismatch as a syntax error.</summary>
    /// <param name="Fail">mfYes reports a mismatch through Error; mfNo just returns False.</param>
    /// <param name="Tokens">The acceptable token kinds.</param>
    /// <returns>True when the token matches ( always True with mfYes, which raises otherwise ).</returns>
    /// <exception cref="Exception">Fail is mfYes and the token does not match.</exception>
    function Match( Fail: MatchFail; const Tokens: array of TTokenKind ): Boolean; overload;
    /// <summary>Parses an arithmetic expression: an optional sign or 'not', then terms joined by +, -, or, xor.</summary>
    /// <returns>The expression tree.</returns>
    function Expression: IExprNode;
    /// <summary>Parses an arithmetic term: factors joined by *, /, mod, and.</summary>
    /// <returns>The term's expression tree.</returns>
    function Term: IExprNode;
    /// <summary>Parses a number, string, True/False, constant identifier or parenthesised expression.</summary>
    /// <returns>The factor's expression tree.</returns>
    /// <exception cref="Exception">Unexpected token, or an identifier that is not a known constant.</exception>
    function Factor: IExprNode;

    /// <summary>Parses a Boolean expression: Boolean terms joined by or / xor.</summary>
    /// <returns>The Boolean expression tree.</returns>
    function BoolExpression: IBoolNode;
    /// <summary>Parses a Boolean term: not-factors joined by 'and', then checks what may follow it.</summary>
    /// <returns>The term's Boolean tree.</returns>
    /// <exception cref="Exception">The term is followed by a token that cannot continue the expression.</exception>
    function BoolTerm: IBoolNode;
    /// <summary>Parses an optional 'not' followed by a Boolean factor.</summary>
    /// <returns>The factor's Boolean tree, wrapped in a not node when negated.</returns>
    function BoolNotFactor: IBoolNode;
    /// <summary>Tests whether the look-ahead token is a relational operator.</summary>
    /// <returns>True for &lt;, &gt;, &lt;=, &gt;=, = or &lt;&gt;.</returns>
    function IsRelOp: Boolean;
    /// <summary>Tests whether the look-ahead token is a Boolean comparison operator.</summary>
    /// <returns>True for = or &lt;&gt;.</returns>
    function IsBoolOp: Boolean;
    /// <summary>Parses an identifier used as a Boolean: a Boolean function call, evaluated now, or a constant.</summary>
    /// <returns>A constant node holding the identifier's value.</returns>
    /// <exception cref="Exception">A malformed function argument list, or an unknown function.</exception>
    function BoolIdent: IBoolNode;
    /// <summary>Parses an arithmetic expression optionally followed by a relational operator and a second expression.</summary>
    /// <returns>A relational node, or an adapter testing the single expression for non-zero.</returns>
    function RelOp: IBoolNode;
    /// <summary>Parses a single Boolean factor, optionally compared with a second one by = or &lt;&gt;.</summary>
    /// <returns>The factor's Boolean tree.</returns>
    function BoolFactor: IBoolNode;
    /// <summary>
    /// Parses a parenthesised Boolean expression, a Boolean identifier or a relational expression, backing up with Rescan
    /// when the tokens turn out to start an arithmetic comparison.
    /// </summary>
    /// <returns>The factor's Boolean tree.</returns>
    /// <exception cref="Exception">Unexpected token.</exception>
    function BoolSingleFactor: IBoolNode;
  public
    /// <summary>Parses the whole expression from the lexer and evaluates it.</summary>
    /// <returns>The value of the expression.</returns>
    /// <exception cref="Exception">A syntax error, or an evaluation error ( through ErrorMsg ).</exception>
    function Parse: Boolean;
  end;

implementation

//{$AUTOBOX ON}
//{$HINTS OFF}
//{$WARNINGS OFF}

constructor TExprNodeUnaryMinus.Create( AOperand: IExprNode );
begin
  inherited Create;
  FOperand          := AOperand;
end;

function TExprNodeUnaryMinus.ToString: string;
begin
  Result            := '-' + FOperand.ToString;
end;

function TExprNodeUnaryMinus.GetValue( out Value: TExprNodeValueRec ): Boolean;
var
  Calculatable      : Boolean;
begin
  Calculatable      := FOperand.GetValue( Value );
  if Calculatable then
  begin
    case Value.Typ of
      vkIsInt:
        Value.ValueInt := -Value.ValueInt;
      vkIsFloat:
        Value.ValueFloat := -Value.ValueFloat;
      vkIsString:
        // TODO: invalid operation
        Value.Error := Format( 'Invalid operation %s', [ '-' ] );
    end;
  end;
  Result            := Calculatable;
end;

constructor TExprNodeBitOpNeg.Create( AOperand: IExprNode );
begin
  inherited Create;
  FOperand          := AOperand;
end;

function TExprNodeBitOpNeg.ToString: string;
begin
  Result            := '~' + FOperand.ToString;
end;

function TExprNodeBitOpNeg.GetValue( out Value: TExprNodeValueRec ): Boolean;
var
  Calculatable      : Boolean;
begin
  Calculatable      := FOperand.GetValue( Value );
  if Calculatable then
  begin
    case Value.Typ of
      vkIsInt:
        Value.ValueInt := not Value.ValueInt;
      vkIsFloat:
        begin
          Value.Error := 'Operation ~ cannot be applied to float value';
          Result    := False;
          Exit;
        end;
      vkIsString:
        // TODO: invalid operation
        Value.Error := Format( 'Invalid operation %s', [ 'not' ] );
    end;
  end;
  Result            := Calculatable;
end;

constructor TExprNodeBinOp.Create( AOperation: TTokenKind; const AOpName: string; AOperand1, AOperand2: IExprNode );
begin
  inherited Create;
  FOperation        := AOperation;
  FOpName           := AOpName;
  FOperand1         := AOperand1;
  FOperand2         := AOperand2;
end;

function TExprNodeBinOp.ToString: string;
begin
  Result            := '(' + FOperand1.ToString + ' ' + FOpName + ' ' + FOperand2.ToString + ')';
end;

function TExprNodeBinOp.GetValue( out Value: TExprNodeValueRec ): Boolean;
var
  Calculatable2     : Boolean;
  Calculatable1     : Boolean;
  V2                : Double;
  V1                : Double;
  Value2            : TExprNodeValueRec;
  Value1            : TExprNodeValueRec;
begin
  Calculatable1     := FOperand1.GetValue( Value1 );
  Calculatable2     := FOperand2.GetValue( Value2 );
  if ( Calculatable1 = False ) then
    Value.Error     := Value1.Error
  else
    Value.Error     := Value2.Error;
  Value.ValueFloat  := 0;
  Value.ValueInt    := 0;
  Value.Typ         := vkIsInt;
  if ( Calculatable1 and Calculatable2 ) then
  begin
    if ( ( Value1.Typ = vkIsString ) and ( Value2.Typ = vkIsString ) ) then
    begin
      Value.Typ     := vkIsString;
      Result        := True;
      // calculate
      case FOperation of
        tkPlus:
          Value.ValueStr := Value1.ValueStr + Value2.ValueStr;
      else
        // TODO: invalid operation
        Value.Error := Format( 'Invalid operation %s', [ FOpName ] );
        Result      := False;
      end;
    end
    else if ( ( Value1.Typ = vkIsInt ) and ( Value2.Typ = vkIsInt ) ) then
    begin
      Value.Typ     := vkIsInt;
      Result        := True;
      // calculate
      case FOperation of
        tkPlus:
          Value.ValueInt := Value1.ValueInt + Value2.ValueInt;
        tkMinus:
          Value.ValueInt := Value1.ValueInt - Value2.ValueInt;
        tkMultiply:
          Value.ValueInt := Value1.ValueInt * Value2.ValueInt;
        tkDivide:
          Value.ValueInt := Value1.ValueInt div Value2.ValueInt; // warning: division by 0
        tkI_Mod:
          Value.ValueInt := Value1.ValueInt mod Value2.ValueInt; // warning: division by 0
        tkI_Or:
          Value.ValueInt := Value1.ValueInt or Value2.ValueInt;
        tkI_Xor:
          Value.ValueInt := Value1.ValueInt xor Value2.ValueInt;
        tkI_And:
          Value.ValueInt := Value1.ValueInt and Value2.ValueInt;
      else
        Result      := False;
      end;
    end
    else
    begin
      V1            := 0;
      V2            := 0;
      Value.Typ     := vkIsFloat;
      if ( ( Value1.Typ = vkIsFloat ) and ( Value2.Typ = vkIsInt ) ) then
      begin
        V1          := Value1.ValueFloat;
        V2          := Value2.ValueInt;
      end
      else if ( ( Value1.Typ = vkIsInt ) and ( Value2.Typ = vkIsFloat ) ) then
      begin
        V1          := Value1.ValueInt;
        V2          := Value2.ValueFloat;
      end
      else if ( ( Value1.Typ = vkIsFloat ) and ( Value2.Typ = vkIsFloat ) ) then
      begin
        V1          := Value1.ValueFloat;
        V2          := Value2.ValueFloat;
      end;
      Result        := True;
      // calculate
      case FOperation of
        tkPlus:
          Value.ValueFloat := V1 + V2;
        tkMinus:
          Value.ValueFloat := V1 - V2;
        tkMultiply:
          Value.ValueFloat := V1 * V2;
        tkDivide:
          if V2 = 0 then
          begin
            Value.Error := 'division by zero';
            Result  := False;
          end
          else
            Value.ValueFloat := V1 / V2;
        tkI_Mod:
          if V2 = 0 then
          begin
            Value.Error := 'division by zero';
            Result  := False;
          end
          else
            Value.ValueFloat := Frac( V1 / V2 );
        tkI_Or, tkI_Xor, tkI_And:
          begin
            // TODO: invalid operation
            Value.Error := Format( 'Invalid operation %s', [ FOpName ] );
            Result  := False;
          end;
      end;
    end;
  end
  else
    Result          := False;
end;

constructor TExprNodeConst.Create( AKind: TTokenKind; const AValue: string );
begin
  inherited Create;
  FKind             := AKind;
  FValue            := AValue;
end;

function TExprNodeConst.ToString: string;
begin
  Result            := FValue;
end;

function TExprNodeConst.GetValue( out Value: TExprNodeValueRec ): Boolean;
var
  ErrCode           : Integer;
begin
  Value.Error       := '';
  Value.ValueInt    := 0;
  Value.ValueFloat  := 0;
  Value.ValueStr    := '';
  Value.Typ         := vkIsInt;
  case FKind of
    tkIdent:
      begin
        Value.Typ   := vkIsInt;
        if SameText( FValue, 'true' ) then
          Value.ValueInt := 1
        else if SameText( FValue, 'false' ) then
          Value.ValueInt := 0
        else
          raise Exception.Create( 'Internal error: Unknown identifier found' );
      end;
    tkInt:
      begin
        Value.Typ   := vkIsInt;
        Value.ValueInt := StrToInt( FValue );
      end;
    tkFloat:
      begin
        Value.Typ   := vkIsFloat;
        Val( FValue, Value.ValueFloat, ErrCode );
        if ErrCode > 0 then
        begin
          Value.Error := Format( '%s is no valid float value', [ FValue ] );
          Result    := False;
          Exit;
        end;
      end;
    tkString:
      begin
        Value.Typ   := vkIsString;
        Value.ValueStr := FValue;
      end;
  end;
  Result            := True;
end;

constructor TBoolNodeOp.Create( AOperation: TTokenKind; const AOpName: string;
  ALeft: IBoolNode; ARight: IBoolNode );
begin
  inherited Create;
  FOperation        := AOperation;
  FOpName           := AOpName;
  FLeft             := ALeft;
  FRight            := ARight;
end;

function TBoolNodeOp.ToString: string;
begin
  Result            := '(' + FLeft.ToString + ' ' + FOpName + ' ' + FRight.ToString + ')';
end;

function TBoolNodeOp.GetValue( var Error: string ): Boolean;
var
  L                 : Boolean;
begin
  L                 := FLeft.GetValue( Error );
  if Error <> '' then
  begin
    Result          := False;
    Exit;
  end;
  case FOperation of
    tkI_And:
      Result        := L and FRight.GetValue( Error );
    tkI_Or:
      Result        := L or FRight.GetValue( Error );
    tkI_Xor:
      Result        := L xor FRight.GetValue( Error );
  else
    Error           := Format( 'Unknown operation %s', [ FOpName ] );
    Result          := False;
  end;
end;

constructor TBoolNodeNot.Create( ANode: IBoolNode );
begin
  inherited Create;
  FNode             := ANode;
end;

function TBoolNodeNot.ToString: string;
begin
  Result            := 'not ' + FNode.ToString;
end;

function TBoolNodeNot.GetValue( var Error: string ): Boolean;
begin
  Result            := not FNode.GetValue( Error );
end;

constructor TBoolNodeConst.Create( AValue: Boolean );
begin
  inherited Create;
  FValue            := AValue;
end;

function TBoolNodeConst.ToString: string;
const
  BoolToStr         : array[ Boolean ] of string = ( 'False', 'True' );
begin
  Result            := BoolToStr[ FValue ];
end;

function TBoolNodeConst.GetValue( var Error: string ): Boolean;
begin
  Result            := FValue;
end;

{constructor TBoolNodeIdent.Create(APreProc: TDelphiPreprocessor; const AIdent: string);
begin
  inherited Create;
  FIdent := AIdent;
  FPreProc := APreProc;
end;

function TBoolNodeIdent.ToString: string;
begin
  Result := FIdent;
end;

function TBoolNodeIdent.GetValue(var Error: string): Boolean;
begin
  Result := FPreProc.Defines.Contains(FIdent);
end;}

constructor TBoolNodeExp.Create( AExpr: IExprNode );
begin
  inherited Create;
  FExpr             := AExpr;
end;

function TBoolNodeExp.ToString: string;
begin
  Result            := '(' + FExpr.ToString + ')';
end;

function TBoolNodeExp.GetValue( var Error: string ): Boolean;
var
  Value             : TExprNodeValueRec;
begin
  if FExpr.GetValue( Value ) then
  begin
    if Value.Typ = vkIsFloat then
      Error         := 'Float Value cannot be evaluated to true or false.'
    else if Value.Typ = vkIsString then
      Error         := 'String Value cannot be evaluated to true or false.'
    else if Value.Typ = vkIsInt then
    begin
      Result        := ( Value.ValueInt <> 0 );
      Exit;
    end
    else
      Error         := 'Unknown number type.'
  end
  else
    Error           := Value.Error;
  Result            := False;
end;

constructor TBoolNodeRelOp.Create( ARelOperation: TTokenKind; const ARelOpName: string;
  ALeft, ARight: IExprNode );
begin
  inherited Create;
  FRelOperation     := ARelOperation;
  FRelOpName        := ARelOpName;
  FLeft             := ALeft;
  FRight            := ARight;
end;

function TBoolNodeRelOp.ToString: string;
begin
  Result            := '(' + FLeft.ToString + ' ' + FRelOpName + ' ' + FRight.ToString + ')';
end;

function TBoolNodeRelOp.GetValue( var Error: string ): Boolean;
var
  D1, D2            : Double;
  V1, V2            : TExprNodeValueRec;
  S1, S2            : string;
begin
  Result            := False;
  V1.Error          := '';
  V2.Error          := '';
  if FLeft.GetValue( V1 ) and FRight.GetValue( V2 ) then
  begin
    D1              := 0;
    D2              := 0;
    if V1.Typ = vkIsInt then
      D1            := V1.ValueInt
    else if V1.Typ = vkIsFloat then
      D1            := V1.ValueFloat
    else
      S1            := V1.ValueStr;

    if V2.Typ = vkIsInt then
      D2            := V2.ValueInt
    else if V2.Typ = vkIsFloat then
      D2            := V2.ValueFloat // tested V1 here, so 1 < 2.5 read the 2.5 as 0
    else
      S2            := V2.ValueStr;

    case FRelOperation of
      tkEqual: // ==
        if ( V1.Typ = vkIsString ) and ( V2.Typ = vkIsString ) then
          Result    := S1 = S2
        else if ( V1.Typ = vkIsInt ) and ( V2.Typ = vkIsInt ) then
          Result    := V1.ValueInt = V2.ValueInt
        else
          Result    := D1 = D2;

      tkNotEqual: // !=
        if ( V1.Typ = vkIsString ) and ( V2.Typ = vkIsString ) then
          Result    := S1 <> S2
        else if ( V1.Typ = vkIsInt ) and ( V2.Typ = vkIsInt ) then
          Result    := V1.ValueInt <> V2.ValueInt
        else
          Result    := D1 <> D2;

      tkLessThan: // <
        if ( V1.Typ = vkIsString ) and ( V2.Typ = vkIsString ) then
          Result    := S1 < S2
        else if ( V1.Typ = vkIsInt ) and ( V2.Typ = vkIsInt ) then
          Result    := V1.ValueInt < V2.ValueInt
        else
          Result    := D1 < D2;

      tkGreaterThan: // >
        if ( V1.Typ = vkIsString ) and ( V2.Typ = vkIsString ) then
          Result    := S1 > S2
        else if ( V1.Typ = vkIsInt ) and ( V2.Typ = vkIsInt ) then
          Result    := V1.ValueInt > V2.ValueInt
        else
          Result    := D1 > D2;

      tkLessEqualThan: // <=
        if ( V1.Typ = vkIsString ) and ( V2.Typ = vkIsString ) then
          Result    := S1 <= S2
        else if ( V1.Typ = vkIsInt ) and ( V2.Typ = vkIsInt ) then
          Result    := V1.ValueInt <= V2.ValueInt
        else
          Result    := D1 <= D2;

      tkGreaterEqualThan: // >=
        if ( V1.Typ = vkIsString ) and ( V2.Typ = vkIsString ) then
          Result    := S1 >= S2
        else if ( V1.Typ = vkIsInt ) and ( V2.Typ = vkIsInt ) then
          Result    := V1.ValueInt >= V2.ValueInt
        else
          Result    := D1 >= D2;
    else
      Error         := Format( 'Unknown relation operation: %s', [ FRelOpName ] );
    end;
  end
  else
    Error           := ( V1.Error + '. ' + V2.Error );
end;

{ TBoolNodeBoolOp }

constructor TBoolNodeBoolOp.Create( AOperation: TTokenKind; const AOpName: string; ALeft, ARight: IBoolNode );
begin
  inherited Create;
  FOperation        := AOperation;
  FOpName           := AOpName;
  FLeft             := ALeft;
  FRight            := ARight;
end;

function TBoolNodeBoolOp.GetValue( var Error: string ): Boolean;
begin
  Result            := FLeft.GetValue( Error );
  if FOperation = tkEqual then
    Result          := Result = FRight.GetValue( Error )
  else if FOperation = tkNotEqual then
    Result          := Result <> FRight.GetValue( Error )
  else
  begin
    Error           := Format( 'Unknown boolean operator "%s"', [ FOpName ] );
    Result          := False;
  end;
end;

function TBoolNodeBoolOp.ToString: string;
begin
  Result            := FLeft.ToString + ' ' + FOpName + ' ' + FRight.ToString;
end;

{ TExpressionParser }

constructor TExpressionParser.Create( ALexer: TDelphiLexer );
begin
  inherited Create;
  FLexer            := ALexer;
  FRescanTokens     := TObjectList.Create( False );
end;

destructor TExpressionParser.Destroy;
begin
  FRescanTokens.Free;
  inherited Destroy;
end;

function TExpressionParser.NextCache: TToken;
begin
  Result            := nil;
  if FRescanIndex < FRescanTokens.Count then
    Result          := TToken( FRescanTokens[ FRescanIndex ] );
  Inc( FRescanIndex );
end;

procedure TExpressionParser.Next;
begin
  Look              := NextCache;
  if Look = nil then
  begin
    Look            := FLexer.GetToken;
    FRescanTokens.Add( Look );
  end;
end;

procedure TExpressionParser.Rescan( Token: TToken );
begin
  FRescanIndex      := FRescanTokens.IndexOf( token );
  if FRescanIndex = -1 then
    ErrorMsg( 'Internal error 0100: Cannot rescan token.', [ ], Token );
end;

procedure TExpressionParser.Error( const Msg: string );
begin
  ErrorMsg( Msg, [ ], nil );
end;

procedure TExpressionParser.ErrorMsg( const Msg: string; const Args: array of const; Token: TToken );
begin
  raise Exception.CreateFmt( Msg, Args );
end;

function TExpressionParser.EvalBoolFunction( IdentToken: TToken; const Args: TDynTokenArray ): Boolean;
begin
  ErrorMsg( 'Unknown boolean function "%s"', [ IdentToken.Value ], IdentToken );
  Result            := False;
end;

function TExpressionParser.Match( const Tokens: array of TTokenKind ): Boolean;
var
  I                 : Integer;
begin
  if Look <> nil then
  begin
    for I := 0 to High( Tokens ) do
      if Look.Kind = Tokens[ I ] then
      begin
        Result      := True;
        Exit;
      end;
  end;
  Result            := False;
end;

function TExpressionParser.Match( Fail: MatchFail; const Tokens: array of TTokenKind ): Boolean;
begin
  if Fail = mfNo then
  begin
    Result          := Match( Tokens );
    Exit;
  end;
  if not Match( Tokens ) then
  begin
    if Look <> nil then
      Self.Error( Format( 'Unexpected token: %s', [ Look.Value ] ) )
    else
      Self.Error( 'Unexpected end of file' );
  end;
  Result            := True;
end;

(*
 <expression>  ::=  [ "+" | "-" | "not" ] <term> { [ "+" | "-" | "or" | "xor" ] <term> }*

  <term>  ::=  <factor> { [ "*" | "/" | "mod" | "and" ] <factor> }*

  <factor>  ::=  <number>  | <ident> | "(" <expression> ")"
*)
function TExpressionParser.Expression: IExprNode;
var
  Op                : TToken;
  Exp               : IExprNode;
  BitNeg            : Boolean;
  Negative          : Boolean;
begin
  Negative          := False;
  BitNeg            := False;
  case Look.Kind of
    tkPlus, tkMinus:
      begin
        Negative    := True;
        Next;
      end;
    tkI_Not:
      begin
        BitNeg      := True;
        Next;
      end;
  end;
  Exp               := Term;
  if Negative then
    Exp             := TExprNodeUnaryMinus.Create( Exp );
  if BitNeg then
    Exp             := TExprNodeBitOpNeg.Create( Exp );
  while Match( mfNo, [ tkPlus, tkMinus, tkI_Or, tkI_Xor ] ) do
  begin
    Op              := Look;
    Next;
    Exp             := TExprNodeBinOp.Create( Op.Kind, Op.Value, Exp, Term );
  end;
  Result            := Exp;
end;

function TExpressionParser.Term: IExprNode;
var
  Op                : TToken;
  t                 : IExprNode;
begin
  t                 := Factor;
  while Match( mfNo, [ tkMultiply, tkDivide, tkI_Mod, tkI_And ] ) do
  begin
    Op              := Look;
    Next;
    t               := TExprNodeBinOp.Create( Op.Kind, Op.Value, t, Factor );
  end;
  Result            := t;
end;

function TExpressionParser.Factor: IExprNode;
var
  Fact              : IExprNode;
  Ident             : TToken;
  Kind              : TTokenKind;
  S                 : string;
begin
  Fact              := nil;
  Match( mfYes, [ tkInt, tkFloat, tkString, tkIdent, tkLParan ] );

  case Look.Kind of
    tkInt, tkFloat, tkString:
      Fact          := TExprNodeConst.Create( Look.Kind, Look.Value );
    tkIdent:
      begin
        Ident       := Look;
        if SameText( Ident.Value, 'True' ) or SameText( Ident.Value, 'False' ) then
          Fact      := TExprNodeConst.Create( Ident.Kind, Ident.Value )
        else
        begin
          if Match( mfNo, [ tkLParan ] ) then
            Self.Error( Format( 'Call to undefined function: %s', [ Ident.Value ] ) )
          else
          begin
            if not GetConstValue( Ident.Value, Kind, S ) then
              ErrorMsg( 'Unknown identifier %s', [ Ident.Value ], Ident );
            Fact    := TExprNodeConst.Create( Kind, S );
          end;
        end;
      end;
    tkLParan:
      begin
        Next( );
        Fact        := Expression( );
        Match( mfYes, [ tkRParan ] );
      end;
  end;
  Next;
  Result            := Fact;
end;

(*
  <B-expression>  ::=  <B-term> { [ "or" | "xor" ] <B-term> }*

  <B-term>  ::=  <B-not-factor> { "and" <B-not-factor> }*

  <B-not-factor>  ::=  [ "not" ] <B-factor>

  <relop>  ::=  "<" | "<=" | ">" | ">=" | "=" | "<>"

  <boolop>  ::=  "=" | "<>"

  <B-factor>  ::= <B-single-factor> [ <boolop> <B-single-factor> ]

  <B-single-factor>  ::=  <number> | <string> | true | false | "(" <B-expression> ")"
                     ::=  "defined" "(" <Ident> ")"
                     ::=  "declared" "(" <Ident> ")"
                     ::=  <Ident>
                     ::=  <expression> <relop> <expression>
*)
function TExpressionParser.BoolExpression: IBoolNode;
var
  Right             : IBoolNode;
  Op                : TToken;
  Left              : IBoolNode;
begin
  Left              := BoolTerm;
  while Match( mfNo, [ tkI_Or, tkI_Xor ] ) do
  begin
    Op              := Look;
    Next;
    Right           := BoolTerm;
    Left            := TBoolNodeOp.Create( Op.Kind, Op.Value, Left, Right );
  end;
  Result            := Left;
end;

function TExpressionParser.BoolTerm: IBoolNode;
var
  Right             : IBoolNode;
  Op                : TToken;
  Left              : IBoolNode;
begin
  Left              := BoolNotFactor;
  while Match( mfNo, [ tkI_And ] ) do
  begin
    Op              := Look;
    Next;
    Right           := BoolNotFactor;
    Left            := TBoolNodeOp.Create( Op.Kind, Op.Value, Left, Right );
  end;
  if ( Look <> nil ) then
    Match( mfYes, [ tkRParan, tkI_Or, tkI_Not, tkI_Xor ] );
  Result            := Left;
end;

function TExpressionParser.BoolNotFactor: IBoolNode;
begin
  if Match( mfNo, [ tkI_Not ] ) then
  begin
    Next;
    Result          := TBoolNodeNot.Create( BoolFactor );
  end
  else
    Result          := BoolFactor;
end;

function TExpressionParser.IsBoolFunction( const Name: string ): Boolean;
begin
  Result            := False;
end;

function TExpressionParser.IsRelOp: Boolean;
begin
  Result            := Match( mfNo, [ tkLessThan, tkGreaterThan, tkLessEqualThan,
      tkGreaterEqualThan, tkEqual, tkNotEqual ] );
end;

function TExpressionParser.IsBoolOp: Boolean;
begin
  Result            := Match( mfNo, [ tkEqual, tkNotEqual ] );
end;

function TExpressionParser.BoolIdent: IBoolNode;
var
  Ident             : TToken;
  Args              : TDynTokenArray;
begin
  Ident             := Look;
  if IsBoolFunction( Ident.Value ) then
  begin
    Next;
    Match( mfNo, [ tkLParan ] );
    Next;
    SetLength( Args, 0 );
    while ( Look <> nil ) and ( Look.Kind <> tkRParan ) do
    begin
      Match( mfYes, [ tkIdent, tkInt, tkFloat, tkString ] );
      SetLength( Args, Length( Args ) + 1 );
      Args[ High( Args ) ] := Look;
      Next;
      Match( mfYes, [ tkComma, tkRParan ] );
      if Look.Kind = tkComma then
      begin
        Next;
        Match( mfYes, [ tkIdent, tkInt, tkFloat, tkString ] ); // catch "(ident,)"
      end;
    end;
    Match( mfYes, [ tkRParan ] );
    Next;
    Result          := TBoolNodeConst.Create( EvalBoolFunction( Ident, Args ) );
  end
  else
  begin
    Next;
    Result          := TBoolNodeConst.Create( GetConstBoolValue( Ident.Value ) );
  end;
end;

function TExpressionParser.RelOp: IBoolNode;
var
  Exp2              : IExprNode;
  Op                : TToken;
  Exp               : IExprNode;
begin
  Exp               := Expression;
  if IsRelOp then
  begin
    Op              := Look;
    Next;
    Exp2            := Expression;
    Result          := TBoolNodeRelOp.Create( Op.Kind, Op.Value, Exp, Exp2 );
  end
  else
    Result          := TBoolNodeExp.Create( Exp );
end;

function TExpressionParser.BoolFactor: IBoolNode;
var
  Op                : TToken;
  Exp2              : IBoolNode;
begin
  Result            := BoolSingleFactor;
  if IsBoolOp then
  begin
    Op              := Look;
    Next;
    Exp2            := BoolSingleFactor;
    Result          := TBoolNodeBoolOp.Create( Op.Kind, Op.Value, Result, Exp2 );
  end;
end;

function TExpressionParser.BoolSingleFactor: IBoolNode;
var
  Node              : IBoolNode;
  LParan, Ident     : TToken;
begin
  Match( mfYes, [ tkInt, tkFloat, tkString, tkLParan, tkIdent ] );
  case Look.Kind of
    tkLParan:
      begin
        LParan      := Look;
        Next;
        Node        := BoolExpression;
        Match( mfYes, [ tkRParan ] );
        Next;
        if IsRelOp then
        begin
          Rescan( LParan );
          Next;
          Node      := RelOp;
        end;
        Result      := Node;
      end;

    tkIdent:
      begin
        // it could be a simple Ident or a part of an expression
        Ident       := Look;
        Next;
        if IsRelOp or Match( mfNo, [ tkPlus, tkMinus, tkI_Or, tkI_Xor,
            tkMultiply, tkDivide, tkI_Mod, tkI_And ] ) then
        begin
          Rescan( Ident );
          Next;
          Node      := RelOp;
        end
        else
        begin
          Rescan( Ident );
          Next;
          Node      := BoolIdent;
        end;
        Result      := Node;
      end;

    tkInt, tkFloat, tkString:
      Result        := RelOp;
  else
    Result          := nil; // never reached but the compiler does not know that Match raises an exception
  end;
end;

function TExpressionParser.Parse: Boolean;
var
  B                 : Boolean;
  Bn                : IBoolNode;
  BoolError         : string;
begin
  Next;
  BoolError         := '';
  Bn                := BoolExpression;
  B                 := Bn.GetValue( BoolError );
  if BoolError <> '' then
    Self.Error( BoolError );
  Result            := B;
end;

function TExpressionParser.GetConstBoolValue( const Name: string ): Boolean;
begin
  if SameText( Name, 'True' ) then
    Result          := True
      //  else if SameText(Name, 'False') then
      //    Result := False
  else
    Result          := False;
end;

function TExpressionParser.GetConstValue( const Name: string; out Kind: TTokenKind; out Value: string ): Boolean;
begin
  Result            := False;
end;

end.

