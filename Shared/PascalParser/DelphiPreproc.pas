{******************************************************************************}
{*                                                                            *}
{* Delphi Preprocessor                                                        *}
{*                                                                            *}
{* (C) 2005 Andreas Hausladen                                                 *}
{*                                                                            *}
{******************************************************************************}

unit DelphiPreproc;

/// <summary>
/// Preprocessor layered on top of TDelphiLexer. Tracks $DEFINE/$UNDEF state, evaluates $IF/$IFDEF/
/// $IFNDEF/$IFOPT/$ELSE/$ELSEIF/$ENDIF/$IFEND blocks and inlines $INCLUDE files. Subscribers
/// resolve unknown identifiers via OnGetDeclared / OnGetConstBoolValue / OnGetConstValue.
/// </summary>

interface

uses
  System.SysUtils, System.Classes, System.Contnrs, DelphiParserContainers, DelphiLexer, DelphiExpr;

type
  /// <summary>Notification raised when the preprocessor emits a token (such as a comment or directive).</summary>
  TTokenEvent = procedure( Sender: TObject; Token: TToken ) of object;
  /// <summary>Notification raised when an $INCLUDE file is encountered, before its contents are inlined.</summary>
  TIncludeEvent = procedure( Sender: TObject; const Name: string ) of object;
  /// <summary>Notification raised when the preprocessor reports an error.</summary>
  TPreprocessorErrorEvent = procedure( Sender: TObject; const Msg: string; Token: TToken ) of object;
  /// <summary>Subscriber-supplied resolver for Boolean compile-time constants in $IF expressions.</summary>
  TGetConstBoolValueEvent = procedure( Sender: TObject; const Name: string; var Value: Boolean ) of object;
  /// <summary>Subscriber-supplied resolver for non-Boolean compile-time constants in $IF expressions.</summary>
  TGetConstValueEvent = procedure( Sender: TObject; const Name: string; var Kind: TTokenKind; var Value: string ) of object;
  /// <summary>Subscriber-supplied resolver for the Declared() pseudo-function.</summary>
  TGetDeclaredEvent = procedure( Sender: TObject; const Name: string; var Value: Boolean ) of object;

  /// <summary>Method used to handle a single compiler directive token (such as $IFDEF or $DEFINE).</summary>
  TTokenParserMethod = procedure( Token: TToken; Lexer: TDelphiLexer ) of object;

  /// <summary>Exception type raised by the preprocessor on unrecoverable errors.</summary>
  EDelphiPreprocessor = class( Exception );

  /// <summary>Hash-table entry pairing a directive name with its handler method.</summary>
  TTokenParserItem = class( TObject )
  private
    /// <summary>The handler for the directive.</summary>
    FMethod: TTokenParserMethod;
  public
    /// <summary>Creates the entry for a handler.</summary>
    /// <param name="AMethod">The handler for the directive.</param>
    constructor Create( AMethod: TTokenParserMethod );
    /// <summary>The handler for the directive.</summary>
    property Method: TTokenParserMethod read FMethod;
  end;

  /// <summary>Hash-table mapping directive names to TTokenParserMethod handlers.</summary>
  TTokenParserList = class( THashtable )
  private
    /// <summary>Getter for Methods.</summary>
    /// <param name="Name">Directive name ( without the '$' ).</param>
    /// <returns>The handler registered for Name, or nil when there is none.</returns>
    function GetMethod( const Name: string ): TTokenParserMethod;
  public
    /// <summary>Registers a handler for a directive name, wrapping it in an owned TTokenParserItem.</summary>
    /// <param name="Name">Directive name ( without the '$' ).</param>
    /// <param name="Method">The handler.</param>
    procedure Add( const Name: string; Method: TTokenParserMethod );
    /// <summary>Handlers by directive name; nil for a directive with no handler.</summary>
    property Methods[ const Name: string ]: TTokenParserMethod read GetMethod; default;
  end;

  /// <summary>State for a single $IF/$IFDEF block on TIfdefStack.</summary>
  TIfdefStackItem = class( TObject )
  private
    /// <summary>Whether the block's current branch is excluded by its own condition.</summary>
    FSkip: Boolean;
    /// <summary>The stack's skip state when the block opened ( True inside an excluded enclosing branch ).</summary>
    FOuterSkip: Boolean;
    /// <summary>Setter for Skip; clearing it also marks a branch of the block as taken ( Processed ).</summary>
    /// <param name="Value">True to exclude the current branch.</param>
    procedure SetSkip( const Value: Boolean );
  public
    /// <summary>True for a block opened by $IFDEF, $IFNDEF or $IFOPT; False for $IF, or once an $ELSEIF has been seen.</summary>
    IsIfdef: Boolean;
    /// <summary>True once the block's $ELSE has been seen, so a second $ELSE is an error.</summary>
    ElseProceeded: Boolean;
    /// <summary>True once one of the block's branches has been taken, so every later $ELSEIF and $ELSE branch is excluded.</summary>
    Processed: Boolean;
    /// <summary>
    /// True for a block whose condition cannot be judged ($IFOPT: compiler option states are not
    /// tracked): every branch, $ELSE included, is kept, so nothing either branch declares is lost.
    /// </summary>
    AllBranches: Boolean;

    /// <summary>Whether the block's current branch is excluded by its own condition.</summary>
    property Skip: Boolean read FSkip write SetSkip;
    /// <summary>The stack's skip state when the block opened.</summary>
    property OuterSkip: Boolean read FOuterSkip write FOuterSkip;
  end;

  /// <summary>Stack of nested $IF/$IFDEF blocks; combines outer-skip flags so nested blocks remain skipped.</summary>
  TIfdefStack = class( TObject )
  private
    /// <summary>The open blocks ( owned TIfdefStackItem objects ), innermost on top.</summary>
    FStack: TStack;
    /// <summary>True while tokens are being excluded: the top block's branch or an enclosing one is skipped.</summary>
    FSkip: Boolean;
    /// <summary>Getter for Count.</summary>
    /// <returns>The number of open blocks.</returns>
    function GetCount: Integer;
    /// <summary>Getter for InElse.</summary>
    /// <returns>True when the innermost block has reached its $ELSE; False when no block is open.</returns>
    function GetInElse: Boolean;
  public
    /// <summary>Creates an empty stack, not skipping.</summary>
    constructor Create;
    /// <summary>Frees any blocks still open, then the stack.</summary>
    destructor Destroy; override;

    /// <summary>Opens an $IFDEF-style block ( $IFDEF, $IFNDEF, $IFOPT ).</summary>
    /// <param name="ASkip">True when the condition excludes the block's first branch.</param>
    procedure Ifdef( ASkip: Boolean );
    /// <summary>Switches the innermost block to its $ELSE branch, which is excluded when an earlier branch was taken (except in an all-branches block).</summary>
    procedure _Else;
    /// <summary>Closes the innermost block, whichever directive opened it, and restores the enclosing skip state.</summary>
    /// <returns>True when the closed block was $IFDEF-style.</returns>
    function EndIf: Boolean;
    /// <summary>
    /// Applies an $ELSEIF to the innermost block: excluded when an earlier branch was taken, kept in an
    /// all-branches block, otherwise decided by ASkip; either way the block is switched to $IF mode.
    /// </summary>
    /// <param name="ASkip">True when the $ELSEIF condition is false (ignored when the branch is decided otherwise).</param>
    procedure ElseIf( ASkip: Boolean );
    /// <summary>
    /// True when the innermost block's next $ELSEIF branch depends on its condition: no earlier branch
    /// was taken, the block is not all-branches, and no enclosing branch is excluded.  When False the
    /// condition need not (and, in excluded text, should not) be evaluated.
    /// </summary>
    /// <returns>True when the $ELSEIF condition must be evaluated.</returns>
    function ElseIfNeedsCondition: Boolean;
    /// <summary>
    /// Opens a block whose condition cannot be judged ($IFOPT): its first branch and its $ELSE are both
    /// kept (see TIfdefStackItem.AllBranches); it stays excluded inside an excluded enclosing branch.
    /// </summary>
    procedure IfUnknown;
    /// <summary>Opens an $IF block.</summary>
    /// <param name="ASkip">True when the condition excludes the block's first branch.</param>
    procedure _If( ASkip: Boolean );
    /// <summary>Closes the innermost block for $IFEND and restores the enclosing skip state.</summary>
    /// <returns>True when the closed block was an $IF block; False when $IFEND closed an $IFDEF-style block.</returns>
    function IfEnd: Boolean;

    /// <summary>True while tokens are being excluded by a conditional block.</summary>
    property Skip: Boolean read FSkip;
    /// <summary>The number of open blocks.</summary>
    property Count: Integer read GetCount;
    /// <summary>True when the innermost block has reached its $ELSE.</summary>
    property InElse: Boolean read GetInElse;
  end;

  /// <summary>
  /// Pascal preprocessor. Owns a stack of TDelphiLexer instances (one per active $INCLUDE) and
  /// emits tokens via GetToken with conditional-compilation rules applied.
  /// </summary>
  TDelphiPreprocessor = class( TObject )
  private
    /// <summary>Owned stack of lexers: the main file first, then one per active $INCLUDE; the last is the current one.</summary>
    FLexers: TObjectList;
    /// <summary>The lexer tokens are read from ( the last in FLexers ); nil once every lexer is exhausted.</summary>
    FCurLexer: TDelphiLexer;
    /// <summary>Owns every token GetToken has returned, keeping them valid until the preprocessor is destroyed.</summary>
    FTokens: TObjectList;

    /// <summary>Distinct names of the files passed to AddInclude.</summary>
    FIncludeFiles: TStrings;
    /// <summary>Handler for directives that have no registered handler.</summary>
    FOnDirective: TTokenEvent;
    /// <summary>Handler called for every comment token read.</summary>
    FOnComment: TTokenEvent;
    /// <summary>The defined conditional symbols ( case-insensitive keys, nil values ).</summary>
    FDefines: THashtable;
    /// <summary>Handler called for an $INCLUDE / $I directive in a branch that is not skipped.</summary>
    FOnIncludeFile: TIncludeEvent;
    /// <summary>Error handler; when assigned, Error calls it instead of raising.</summary>
    FOnError: TPreprocessorErrorEvent;
    /// <summary>The directive token being processed, or nil; the location used for errors that have no token of their own.</summary>
    FPreprocToken: TToken;

    /// <summary>Handlers for the directives the preprocessor interprets, by directive name.</summary>
    FCompilerDirectives: TTokenParserList;
    /// <summary>The open conditional blocks and the resulting skip state.</summary>
    FIfdefStack: TIfdefStack;
    /// <summary>Resolver for declared() in $IF expressions.</summary>
    FOnGetDeclared: TGetDeclaredEvent;
    /// <summary>Resolver for bare identifiers used as Booleans in $IF expressions.</summary>
    FOnGetConstBoolValue: TGetConstBoolValueEvent;
    /// <summary>Resolver for identifiers used as values in $IF expressions.</summary>
    FOnGetConstValue: TGetConstValueEvent;

    /// <summary>Getter for CurrentToken.</summary>
    /// <returns>The token GetToken returned last, or nil before the first.</returns>
    function GetCurrentToken: TToken;
    /// <summary>Getter for TokenCount.</summary>
    /// <returns>The number of tokens GetToken has returned.</returns>
    function GetTokenCount: Integer;
    /// <summary>Getter for Tokens.</summary>
    /// <param name="Index">Zero-based index, in the order GetToken returned them.</param>
    /// <returns>The token at Index.</returns>
    function GetTokenProp( Index: Integer ): TToken;
    /// <summary>Getter for CurrentFileName.</summary>
    /// <returns>The file name of the current lexer, or '' once every lexer is exhausted.</returns>
    function GetCurrentFileName: string;
  protected
    /// <summary>Registers the handlers for the directives the preprocessor interprets; descendants may add more.</summary>
    procedure InitCompilerDirectives; virtual;
    /// <summary>
    /// Extracts the directive name from a directive token and calls its handler; a directive with no handler goes to
    /// OnDirective unless the current branch is skipped.
    /// </summary>
    /// <param name="Token">The directive token.</param>
    /// <exception cref="EDelphiPreprocessor">The directive is malformed or its handler reports an error, and OnError is not assigned.</exception>
    procedure ProcessDirective( Token: TToken ); virtual;
    /// <summary>Reports an error at a token: calls OnError when assigned, otherwise raises.</summary>
    /// <param name="Fmt">Format string of the message.</param>
    /// <param name="Args">Arguments for Fmt.</param>
    /// <param name="Token">The token the error refers to; must not be nil.</param>
    /// <exception cref="EDelphiPreprocessor">OnError is not assigned; the message is prefixed with the file name and line.</exception>
    procedure Error( const Fmt: string; const Args: array of const; Token: TToken );
    /// <summary>Resolves a bare identifier used as a Boolean in an $IF expression through OnGetConstBoolValue.</summary>
    /// <param name="Name">The identifier.</param>
    /// <returns>The value OnGetConstBoolValue supplies; False when it is not assigned.</returns>
    function GetConstBoolValue( const Name: string ): Boolean; virtual;
    /// <summary>Resolves an identifier used as a value in an $IF expression through OnGetConstValue.</summary>
    /// <param name="Name">The identifier.</param>
    /// <param name="Kind">Receives the token kind of the value; tkString unless the handler changes it.</param>
    /// <param name="Value">Receives the value as literal text; '' unless the handler changes it.</param>
    procedure GetConstValue( const Name: string; out Kind: TTokenKind; out Value: string ); virtual;
    /// <summary>Evaluates declared() through OnGetDeclared.</summary>
    /// <param name="Name">The identifier passed to declared().</param>
    /// <returns>The value OnGetDeclared supplies; False when it is not assigned.</returns>
    function GetDeclared( const Name: string ): Boolean; virtual;
    /// <summary>Evaluates defined().</summary>
    /// <param name="Name">The conditional symbol.</param>
    /// <returns>True when Name is currently defined.</returns>
    function GetDefined( const Name: string ): Boolean; virtual;

    /// <summary>Handlers for the directives the preprocessor interprets, by directive name.</summary>
    property CompilerDirectives: TTokenParserList read FCompilerDirectives;

    /// <summary>Handles $DEFINE: defines the symbol unless the current branch is skipped.</summary>
    /// <param name="Token">The directive token, used for error locations.</param>
    /// <param name="L">Lexer positioned after the directive name.</param>
    /// <exception cref="EDelphiPreprocessor">No identifier follows, and OnError is not assigned.</exception>
    procedure ParseDefine( Token: TToken; L: TDelphiLexer );
    /// <summary>Handles $UNDEF: removes the symbol unless the current branch is skipped.</summary>
    /// <param name="Token">The directive token, used for error locations.</param>
    /// <param name="L">Lexer positioned after the directive name.</param>
    /// <exception cref="EDelphiPreprocessor">No identifier follows, and OnError is not assigned.</exception>
    procedure ParseUndef( Token: TToken; L: TDelphiLexer );
    /// <summary>Handles $IFDEF: opens a block whose first branch is taken when the symbol is defined.</summary>
    /// <param name="Token">The directive token, used for error locations.</param>
    /// <param name="L">Lexer positioned after the directive name.</param>
    /// <exception cref="EDelphiPreprocessor">No identifier follows, and OnError is not assigned.</exception>
    procedure ParseIfdef( Token: TToken; L: TDelphiLexer );
    /// <summary>Handles $IFNDEF: opens a block whose first branch is taken when the symbol is not defined.</summary>
    /// <param name="Token">The directive token, used for error locations.</param>
    /// <param name="L">Lexer positioned after the directive name.</param>
    /// <exception cref="EDelphiPreprocessor">No identifier follows, and OnError is not assigned.</exception>
    procedure ParseIfndef( Token: TToken; L: TDelphiLexer );
    /// <summary>
    /// Handles $IFOPT: opens a block.  Compiler option states are not tracked, so both the first branch and its
    /// $ELSE are kept (an all-branches block): neither branch's declarations, such as uses entries, are dropped.
    /// </summary>
    /// <param name="Token">The directive token, used for error locations.</param>
    /// <param name="L">Lexer positioned after the directive name.</param>
    /// <exception cref="EDelphiPreprocessor">No identifier follows, and OnError is not assigned.</exception>
    procedure ParseIfopt( Token: TToken; L: TDelphiLexer );
    /// <summary>Handles $ENDIF: closes the innermost block, whether $IF or $IFDEF-style.</summary>
    /// <param name="Token">The directive token, used for error locations.</param>
    /// <param name="L">Lexer positioned after the directive name ( not used ).</param>
    /// <exception cref="EDelphiPreprocessor">No block is open, and OnError is not assigned.</exception>
    procedure ParseEndif( Token: TToken; L: TDelphiLexer );
    /// <summary>Handles $ELSE: switches the innermost block to its else branch.</summary>
    /// <param name="Token">The directive token, used for error locations.</param>
    /// <param name="L">Lexer positioned after the directive name ( not used ).</param>
    /// <exception cref="EDelphiPreprocessor">No block is open or it already had an $ELSE, and OnError is not assigned.</exception>
    procedure ParseElse( Token: TToken; L: TDelphiLexer );
    /// <summary>
    /// Handles $ELSEIF: evaluates its expression when it can decide the branch (no earlier branch taken, the block
    /// not all-branches, no enclosing branch excluded) and applies the result to the innermost block.
    /// </summary>
    /// <param name="Token">The directive token, used for error locations.</param>
    /// <param name="L">Lexer positioned at the start of the expression.</param>
    /// <exception cref="EDelphiPreprocessor">No block is open, or the expression is invalid, and OnError is not assigned.</exception>
    procedure ParseElseif( Token: TToken; L: TDelphiLexer );
    /// <summary>Handles $IF: evaluates its expression ( unless skipping ) and opens an $IF block.</summary>
    /// <param name="Token">The directive token, used for error locations.</param>
    /// <param name="L">Lexer positioned at the start of the expression.</param>
    /// <exception cref="EDelphiPreprocessor">The expression is invalid, and OnError is not assigned.</exception>
    procedure ParseIf( Token: TToken; L: TDelphiLexer );
    /// <summary>Handles $IFEND: closes the innermost block, which must be an $IF block.</summary>
    /// <param name="Token">The directive token, used for error locations.</param>
    /// <param name="L">Lexer positioned after the directive name ( not used ).</param>
    /// <exception cref="EDelphiPreprocessor">
    /// No block is open, or the closed block was $IFDEF-style ( "$ENDIF expected" ), and OnError is not assigned.
    /// </exception>
    procedure ParseIfEnd( Token: TToken; L: TDelphiLexer );
    /// <summary>
    /// Handles $INCLUDE / $I: unless skipping, extracts the file name ( quoted or bare ) and passes it to OnIncludeFile,
    /// whose handler is expected to load the file and call AddInclude.
    /// </summary>
    /// <param name="Token">The directive token, used for error locations.</param>
    /// <param name="L">Lexer positioned after the directive name.</param>
    /// <exception cref="EDelphiPreprocessor">The file name is missing or unterminated, and OnError is not assigned.</exception>
    procedure ParseInclude( Token: TToken; L: TDelphiLexer );
  public
    /// <summary>Creates a preprocessor for a source text, with CONDITIONALEXPRESSIONS defined.</summary>
    /// <param name="AFilename">File name of the source, used in error messages and token locations.</param>
    /// <param name="Text">The source text.</param>
    constructor Create( const AFilename: string; const Text: UTF8String );
    /// <summary>Frees the lexers, the definitions and every token returned, which become invalid.</summary>
    destructor Destroy; override;

    /// <summary>
    /// Pushes an include file's text as the current lexer, so GetToken reads it before resuming the including file;
    /// refuses a file already open more than 50 times ( include recursion ).
    /// </summary>
    /// <param name="Filename">File name of the include, recorded in IncludeFiles.</param>
    /// <param name="Text">The include file's text.</param>
    /// <exception cref="EDelphiPreprocessor">Include recursion, and OnError is not assigned.</exception>
    procedure AddInclude( const Filename: string; const Text: UTF8String ); overload;
    /// <summary>Defines a conditional symbol; does nothing when it is already defined.</summary>
    /// <param name="Name">The symbol ( case-insensitive ).</param>
    procedure Define( const Name: string );
    /// <summary>Removes a conditional symbol; does nothing when it is not defined.</summary>
    /// <param name="Name">The symbol ( case-insensitive ).</param>
    procedure Undefine( const Name: string );
    /// <summary>
    /// Returns the next token that survives conditional compilation: directives are processed and consumed, tokens in
    /// skipped branches are dropped, and include files are read in place.
    /// </summary>
    /// <param name="AllowComments">True to return comment tokens; otherwise they are only passed to OnComment.</param>
    /// <returns>The next token, owned by the preprocessor; nil at the end of the main file.</returns>
    /// <exception cref="EDelphiPreprocessor">A directive reports an error, and OnError is not assigned.</exception>
    function GetToken( AllowComments: Boolean = False ): TToken;

    /// <summary>Distinct names of the files passed to AddInclude.</summary>
    property IncludeFiles: TStrings read FIncludeFiles;
    /// <summary>The defined conditional symbols ( case-insensitive keys ).</summary>
    property Defines: THashtable read FDefines;

    /// <summary>Called for every comment token read, whether or not comments are returned.</summary>
    property OnComment: TTokenEvent read FOnComment write FOnComment;
    /// <summary>Called for a directive with no registered handler ( such as $R or $WARN ) in a branch that is not skipped.</summary>
    property OnDirective: TTokenEvent read FOnDirective write FOnDirective;
    /// <summary>Called with the file name of an $INCLUDE / $I directive; the handler loads the file and calls AddInclude.</summary>
    property OnIncludeFile: TIncludeEvent read FOnIncludeFile write FOnIncludeFile;
    /// <summary>When assigned, receives errors instead of Error raising EDelphiPreprocessor; processing then continues.</summary>
    property OnError: TPreprocessorErrorEvent read FOnError write FOnError;
    /// <summary>Resolves bare identifiers used as Booleans in $IF expressions; unresolved ones are False.</summary>
    property OnGetConstBoolValue: TGetConstBoolValueEvent read FOnGetConstBoolValue write FOnGetConstBoolValue;
    /// <summary>Resolves identifiers used as values in $IF expressions; unresolved ones are the empty string.</summary>
    property OnGetConstValue: TGetConstValueEvent read FOnGetConstValue write FOnGetConstValue;
    /// <summary>Evaluates declared() in $IF expressions; unresolved ones are False.</summary>
    property OnGetDeclared: TGetDeclaredEvent read FOnGetDeclared write FOnGetDeclared;

    /// <summary>File name of the file being read ( the innermost include ), or '' at the end.</summary>
    property CurrentFileName: string read GetCurrentFileName;
    /// <summary>The token GetToken returned last, or nil before the first.</summary>
    property CurrentToken: TToken read GetCurrentToken;

    /// <summary>The number of tokens GetToken has returned.</summary>
    property TokenCount: Integer read GetTokenCount;
    /// <summary>Every token GetToken has returned, in order; owned by the preprocessor.</summary>
    property Tokens[ Index: Integer ]: TToken read GetTokenProp;
  end;

  /// <summary>Discriminator passed to TExpressionParser.Match to decide whether failure raises an exception.</summary>
  MatchFail = ( mfYes, mfNo );

  /// <summary>$IF expression evaluator that consults the owning preprocessor for identifier resolution.</summary>
  TPreprocessorIfParser = class( TExpressionParser )
  private
    /// <summary>The preprocessor that resolves identifiers and reports errors ( not owned ).</summary>
    FPreprocessor: TDelphiPreprocessor;
  public
    /// <summary>Creates a parser for one $IF or $ELSEIF expression.</summary>
    /// <param name="APreprocessor">The preprocessor that resolves identifiers and reports errors.</param>
    /// <param name="ALexer">Lexer positioned at the start of the expression.</param>
    constructor Create( APreprocessor: TDelphiPreprocessor; ALexer: TDelphiLexer );
  protected
    /// <summary>Resolves an identifier through the preprocessor's OnGetConstValue; every identifier is accepted.</summary>
    /// <param name="Name">The identifier.</param>
    /// <param name="Kind">Receives the token kind of the value.</param>
    /// <param name="Value">Receives the value as literal text ( '' when unresolved ).</param>
    /// <returns>Always True.</returns>
    function GetConstValue( const Name: string; out Kind: TTokenKind; out Value: string ): Boolean; override;
    /// <summary>Resolves True and False itself, and any other identifier through the preprocessor's OnGetConstBoolValue.</summary>
    /// <param name="Name">The identifier.</param>
    /// <returns>The identifier's Boolean value.</returns>
    function GetConstBoolValue( const Name: string ): Boolean; override;
    /// <summary>Recognises the $IF functions defined() and declared().</summary>
    /// <param name="Name">The identifier.</param>
    /// <returns>True for 'defined' or 'declared' ( case-insensitive ).</returns>
    function IsBoolFunction( const Name: string ): Boolean; override;
    /// <summary>Evaluates defined( Ident ) against the defined symbols, or declared( Ident ) through OnGetDeclared.</summary>
    /// <param name="IdentToken">Token holding the function name.</param>
    /// <param name="Args">The argument tokens; exactly one identifier is required.</param>
    /// <returns>The function's result.</returns>
    /// <exception cref="EDelphiPreprocessor">A wrong argument list or an unknown function, and OnError is not assigned.</exception>
    function EvalBoolFunction( IdentToken: TToken; const Args: TDynTokenArray ): Boolean; override;
    /// <summary>Forwards the error to the preprocessor's Error, located at the directive token when Token is nil.</summary>
    /// <param name="Msg">Format string of the message.</param>
    /// <param name="Args">Arguments for Msg.</param>
    /// <param name="Token">Token the error refers to, or nil.</param>
    /// <exception cref="EDelphiPreprocessor">OnError is not assigned.</exception>
    procedure ErrorMsg( const Msg: string; const Args: array of const; Token: TToken ); override;
  end;

/// <summary>
/// Case-insensitive file name comparison; when either name contains '~' both are converted to their short ( 8.3 )
/// form first, so a short and a long form of the same existing file match.
/// </summary>
/// <param name="Filename1">First file name.</param>
/// <param name="Filename2">Second file name.</param>
/// <returns>True when the names refer to the same file.</returns>
function CompareFileName( const Filename1, Filename2: string ): Boolean;

/// <summary>
/// The conditional symbols the compiler predefines for a Windows target, so a source scan sees the
/// branches the compiler compiles: MSWINDOWS, UNICODE, CONDITIONALEXPRESSIONS, NATIVECODE, DCC,
/// ASSEMBLER, this compiler's VERnnn, and WIN32 / CPUX86 / CPU386 / CPU32BITS /
/// UNDERSCOREIMPORTNAME or WIN64 / CPUX64 / CPU64BITS.
/// </summary>
/// <param name="Platform">Target platform as the IDE names it: "Win64", or "Win32" (also the fallback for anything else).</param>
/// <returns>The predefined symbol names, upper case.</returns>
function PredefinedSymbols( const Platform: string ): TArray<string>;

implementation

resourcestring
  RsIncludeRecursion = 'Include recursion detected in file %s';
  RsUnknownCompilerDirective = 'Unknown compiler directive "%s"';
  RsIdentifierExpected = 'Identifier expected';
  RsFilenameExpected = 'Filename expected';
  RsStringEndMissing = 'String end is missing';
  RsNoIfdefOpen     = 'No conditional block open';
  RsExpected        = '%s expected';
  RsMultipleElseNotAllowed = '$ELSE already used';

function CompareFileName( const Filename1, Filename2: string ): Boolean;
{$IFDEF MSWINDOWS}
var
  Fn1, Fn2          : string;
{$ENDIF MSWINDOWS}
begin
{$IFDEF LINUX}
  Result            := CompareStr( Filename1, Filename2 ) = 0;
{$ENDIF LINUX}
{$IFDEF MSWINDOWS}
  if ( Pos( '~', Filename1 ) > 0 ) or ( Pos( '~', Filename2 ) > 0 ) then
  begin
    Fn1             := ExtractShortPathName( Filename1 );
    Fn2             := ExtractShortPathName( Filename2 );
    Result          := ( Fn1 <> '' ) and ( Fn2 <> '' ) and ( CompareText( Fn1, Fn2 ) = 0 );
  end
  else
    Result          := CompareText( Filename1, Filename2 ) = 0; // it compared the empty locals, so every pair matched
{$ENDIF MSWINDOWS}
end;

function PredefinedSymbols( const Platform: string ): TArray<string>;
begin
  Result            := [ 'MSWINDOWS', 'UNICODE', 'CONDITIONALEXPRESSIONS', 'NATIVECODE', 'DCC', 'ASSEMBLER',
    'VER' + IntToStr( Trunc( CompilerVersion * 10 ) ) ];

  if SameText( Platform, 'Win64' ) then
    Result          := Result + [ 'WIN64', 'CPUX64', 'CPU64BITS' ]
  else
    Result          := Result + [ 'WIN32', 'CPUX86', 'CPU386', 'CPU32BITS', 'UNDERSCOREIMPORTNAME' ];
end;

{ TPreprocessorIfParser }

constructor TPreprocessorIfParser.Create( APreprocessor: TDelphiPreprocessor; ALexer: TDelphiLexer );
begin
  inherited Create( ALexer );
  FPreprocessor     := APreprocessor;
end;

{function TPreprocessorIfParser.BoolIdent: IBoolNode;
var
  Node: IBoolNode;
  Macro: TToken;
  Ident: TToken;
begin
  Ident := Look;
  if SameText(Ident.Value, 'defined') then
  begin
    Next;
    Match(mfNo, [tkLParan]);
    Next;
    Macro := Look;
    if Macro = nil then
      Error('Invalid defined() syntax')
    else
      if (Macro.Kind <> tkIdent) then
        Error(Format('defined() requires an identifier: %s', [Macro.Value]));
    Node := TBoolNodeConst.Create(FPreprocessor.GetDefined(Macro.Value));
    Next;
    Match(mfYes, [tkRParan]);
    Next;
    Result := Node;
  end
  else if SameText(Ident.Value, 'declared') then
  begin
    Next;
    Match(mfNo, [tkLParan]);
    Next;
    Macro := Look;
    if Macro = nil then
      Error('Invalid declared() syntax')
    else
      if (Macro.Kind <> tkIdent) then
        Error(Format('declared() requires an identifier: %s', [Macro.Value]));
    Node := TBoolNodeConst.Create(FPreprocessor.GetDeclared(Macro.Value));
    Next;
    Match(mfYes, [tkRParan]);
    Next;
    Result := Node;
  end
  else
  begin
    Next;
    if SameText(Ident.Value, 'True') then
      Result := TBoolNodeConst.Create(True)
    else if SameText(Ident.Value, 'False') then
      Result := TBoolNodeConst.Create(False)
    else
      Result := TBoolNodeConst.Create(FPreprocessor.GetConstBoolValue(Ident.Value))
  end;
end;}

function TPreprocessorIfParser.GetConstBoolValue( const Name: string ): Boolean;
begin
  if SameText( Name, 'True' ) then
    Result          := True
  else if SameText( Name, 'False' ) then
    Result          := False
  else
    Result          := FPreprocessor.GetConstBoolValue( Name );
end;

function TPreprocessorIfParser.GetConstValue( const Name: string; out Kind: TTokenKind;
  out Value: string ): Boolean;
begin
  FPreprocessor.GetConstValue( Name, Kind, Value );
  Result            := True;
end;

function TPreprocessorIfParser.IsBoolFunction( const Name: string ): Boolean;
begin
  Result            := SameText( Name, 'defined' ) or
    SameText( Name, 'declared' );
end;

procedure TPreprocessorIfParser.ErrorMsg( const Msg: string; const Args: array of const; Token: TToken );
begin
  if Token = nil then
    Token           := FPreprocessor.FPreprocToken;
  FPreprocessor.Error( Msg, Args, Token );
end;

function TPreprocessorIfParser.EvalBoolFunction( IdentToken: TToken; const Args: TDynTokenArray ): Boolean;
begin
  if SameText( IdentToken.Value, 'defined' ) then
  begin
    if Length( Args ) <> 1 then
      Error( 'Invalid defined() syntax' )
    else if Args[ 0 ].Kind <> tkIdent then
      Error( Format( 'defined() requires an identifier: %s', [ Args[ 0 ].Value ] ) );
    Result          := FPreprocessor.GetDefined( Args[ 0 ].Value );
  end
  else if SameText( IdentToken.Value, 'declared' ) then
  begin
    if Length( Args ) <> 1 then
      Error( 'Invalid declared() syntax' )
    else if Args[ 0 ].Kind <> tkIdent then
      Error( Format( 'declared() requires an identifier: %s', [ Args[ 0 ].Value ] ) );
    Result          := FPreprocessor.GetDeclared( Args[ 0 ].Value );
  end
  else
  begin
    ErrorMsg( 'Unknown $IF function "%s"', [ IdentToken.Value ], IdentToken );
    Result          := False;
  end;
end;

{ TTokenParserList }

procedure TTokenParserList.Add( const Name: string; Method: TTokenParserMethod );
begin
  inherited Add( Name, TTokenParserItem.Create( Method ) );
end;

function TTokenParserList.GetMethod( const Name: string ): TTokenParserMethod;
var
  Item              : TTokenParserItem;
begin
  Item              := TTokenParserItem( Values[ Name ] );
  if Item <> nil then
    Result          := Item.Method
  else
    Result          := nil;
end;

{ TTokenParserItem }

constructor TTokenParserItem.Create( AMethod: TTokenParserMethod );
begin
  inherited Create;
  FMethod           := AMethod;
end;

{ TDelphiPreprocessor }

constructor TDelphiPreprocessor.Create( const AFilename: string; const Text: UTF8String );
begin
  inherited Create;
  FLexers           := TObjectList.Create;
  FLexers.Add( TDelphiLexer.Create( AFilename, Text, {OwnsObjects:=}False ) );
  FCurLexer         := TDelphiLexer( FLexers[ 0 ] );
  FDefines          := THashtable.Create( False );
  FIncludeFiles     := TStringList.Create;
  FTokens           := TObjectList.Create;
  FIfdefStack       := TIfdefStack.Create;

  FCompilerDirectives := TTokenParserList.Create( False );
  InitCompilerDirectives;
  Define( 'CONDITIONALEXPRESSIONS' );
end;

destructor TDelphiPreprocessor.Destroy;
begin
  FIfdefStack.Free;
  FCompilerDirectives.Free;
  FIncludeFiles.Free;
  FDefines.Free;
  FLexers.Free;
  FTokens.Free; // from here on all tokens are invalid
  inherited Destroy;
end;

procedure TDelphiPreprocessor.AddInclude( const Filename: string; const Text: UTF8String );
var
  InclCount, i      : Integer;
begin
  // detect include recursion
  InclCount         := 0;
  for i := 0 to FLexers.Count - 1 do
    if CompareFileName( TDelphiLexer( FLexers[ i ] ).Filename, Filename ) then
      Inc( InclCount );
  if InclCount > 50 then
  begin
    Error( RsIncludeRecursion, [ ExtractFileName( Filename ) ], FPreprocToken );
    Exit;
  end;

  FCurLexer         := TDelphiLexer.Create( Filename, Text, {OwnsObjects:=}False );
  FCurLexer.SupportMacroTokens := TDelphiLexer( FLexers[ 0 ] ).SupportMacroTokens;
  FLexers.Add( FCurLexer );

  if FIncludeFiles.IndexOf( Filename ) < 0 then
    FIncludeFiles.Add( Filename );
end;

function TDelphiPreprocessor.GetCurrentFileName: string;
begin
  if FCurLexer <> nil then
    Result          := FCurLexer.Filename
  else
    Result          := '';
end;

function TDelphiPreprocessor.GetCurrentToken: TToken;
begin
  if FTokens.Count > 0 then
    Result          := TToken( FTokens[ FTokens.Count - 1 ] )
  else
    Result          := nil;
end;

procedure TDelphiPreprocessor.Define( const Name: string );
begin
  if not FDefines.Contains( Name ) then
    FDefines.Add( Name, nil );
end;

procedure TDelphiPreprocessor.Undefine( const Name: string );
begin
  FDefines.Remove( Name );
end;

procedure TDelphiPreprocessor.InitCompilerDirectives;
begin
  CompilerDirectives.Add( 'define', ParseDefine );
  CompilerDirectives.Add( 'undef', ParseUndef );
  CompilerDirectives.Add( 'ifdef', ParseIfdef );
  CompilerDirectives.Add( 'ifopt', ParseIfopt );
  CompilerDirectives.Add( 'ifndef', ParseIfndef );
  CompilerDirectives.Add( 'endif', ParseEndif );
  CompilerDirectives.Add( 'else', ParseElse );
  CompilerDirectives.Add( 'if', ParseIf );
  CompilerDirectives.Add( 'ifend', ParseIfend );
  CompilerDirectives.Add( 'elseif', ParseElseif );

  CompilerDirectives.Add( 'i', ParseInclude );
  CompilerDirectives.Add( 'include', ParseInclude );
end;

function TDelphiPreprocessor.GetToken( AllowComments: Boolean ): TToken;
begin
  if Assigned( FCurLexer ) then
  begin
    Result          := nil;
    repeat
      Result.Free;
      Result        := FCurLexer.GetToken;
      if Result = nil then
      begin
        // lexer has no further tokens, return to previous lexer
        FLexers.Delete( FLexers.Count - 1 );
        if FLexers.Count > 0 then
        begin
          FCurLexer := TDelphiLexer( FLexers[ FLexers.Count - 1 ] );
          Continue; // next token
        end
        else
        begin
          FCurLexer := nil;
          // there are no more lexers available
          Break; // ignore FIfdefStack.Skip and return
        end;
      end
      else
      begin
        // evaluate preprocessor tokens and remove comments
        if Result.Kind = tkComment then
        begin
          if Assigned( FOnComment ) then
            FOnComment( Self, Result );
          if not AllowComments then
            Continue; // next token
        end
        else if Result.Kind = tkDirective then
        begin
          ProcessDirective( Result );
          Continue; // next token
        end;
      end;

      if not FIfdefStack.Skip then
        Break;
    until False; // for "continue"

    if Result <> nil then
      FTokens.Add( Result );
  end
  else
    Result          := nil;
end;

procedure TDelphiPreprocessor.ProcessDirective( Token: TToken );
var
  ps                : Integer;
  Opt               : string;
  S                 : string;
  L                 : TDelphiLexer;
  NameToken         : TToken;
  TokenParser       : TTokenParserMethod;
begin
  FPreprocToken     := Token;
  try
    S               := Token.Value;
    ps              := Pos( '$', S );
    Opt             := Copy( S, ps + 1, Length( S ) - ps * 2 + 1 );

    L               := TDelphiLexer.Create( '', UTF8Encode( Opt ), {OwnsObjects:=}True ); // we do not put the tokens into the FTokens list
    try
      NameToken     := L.GetToken;
      if ( NameToken = nil ) or ( NameToken.Kind < tkIdent ) then
      begin
        Error( RsUnknownCompilerDirective, [ ], Token );
        Exit;
      end;

      TokenParser   := CompilerDirectives[ NameToken.Value ];
      if Assigned( TokenParser ) then
        TokenParser( Token, L )
      else if not FIfdefStack.Skip and Assigned( FOnDirective ) then
        FOnDirective( Self, Token );
      { TODO : reactivate when all directives are parsed };
      //Error(RsUnknownCompilerDirective, [NameToken.Value], Token);
    finally
      L.Free;
    end;

  finally
    FPreprocToken   := nil;
  end;
end;

procedure TDelphiPreprocessor.Error( const Fmt: string; const Args: array of const;
  Token: TToken );
begin
  Assert( Token <> nil );
  if Assigned( FOnError ) then
    FOnError( Self, Format( Fmt, Args ), Token )
  else
    raise EDelphiPreprocessor.CreateFmt( '%s(%d): %s',
      [ Token.Filename, ( Token.Line + 1 ), Format( Fmt, Args ) ] );
end;

procedure TDelphiPreprocessor.ParseInclude( Token: TToken; L: TDelphiLexer );
var
  S, Filename       : string;
  i                 : Integer;
  Len               : Integer;
begin
  if FIfdefStack.Skip then
    Exit;

  Filename          := Trim( Copy( UTF8ToString( L.Text ), L.Index, MaxInt ) );
  if Filename = '' then
  begin
    Error( RsFilenameExpected, [ ], Token );
    Exit; // an OnError handler that does not raise must not reach Filename[1]
  end;
  Len               := Length( Filename );
  if Filename[ 1 ] = '''' then
  begin
    S               := Filename;
    Filename        := '';
    for i := 2 to Len do
      if S[ i ] = '''' then
      begin
        Filename    := Copy( S, 2, i - 2 );
        Break;
      end;
    if Filename = '' then
    begin
      Error( RsStringEndMissing, [ ], Token );
      Exit;
    end;
  end
  else
  begin
    i               := 2;
    while ( i <= Len ) and ( Filename[ i ] > ' ' ) do
      Inc( i );
    Filename        := Copy( Filename, 1, i - 1 );
  end;

  if Assigned( FOnIncludeFile ) then
    FOnIncludeFile( Self, Filename );
end;

procedure TDelphiPreprocessor.ParseIfEnd( Token: TToken; L: TDelphiLexer );
begin
  if FIfdefStack.Count = 0 then
    Error( RsNoIfdefOpen, [ ], Token )
  else if not FIfdefStack.IfEnd then
    Error( RsExpected, [ '$ENDIF' ], Token );
end;

procedure TDelphiPreprocessor.ParseEndif( Token: TToken; L: TDelphiLexer );
begin
  // $ENDIF closes $IFDEF, $IFNDEF, $IFOPT and - since XE4 - $IF as well, so which kind of block it
  // closes is not checked (it used to demand $IFEND for $IF and raise on legal code).
  if FIfdefStack.Count = 0 then
    Error( RsNoIfdefOpen, [ ], Token )
  else
    FIfdefStack.EndIf;
end;

procedure TDelphiPreprocessor.ParseIf( Token: TToken; L: TDelphiLexer );
var
  p                 : TPreprocessorIfParser;
begin
  if FIfdefStack.Skip then
    FIfdefStack._If( False )
  else
  begin
    p               := TPreprocessorIfParser.Create( Self, L );
    try
      FIfdefStack._If( not p.Parse );
    finally
      p.Free;
    end;
  end;
end;

procedure TDelphiPreprocessor.ParseIfdef( Token: TToken; L: TDelphiLexer );
var
  t                 : TToken;
begin
  t                 := L.ParseIfdefToken;
  if ( t = nil ) or ( t.Kind < tkIdent ) then
  begin
    Error( RsIdentifierExpected, [ ], Token );
    FIfdefStack.Ifdef( False ); // default to undefined if no exception was raised
    Exit;
  end;
  if FIfdefStack.Skip then
    FIfdefStack.Ifdef( False )
  else
    FIfdefStack.Ifdef( not FDefines.Contains( t.Value ) );
end;

procedure TDelphiPreprocessor.ParseIfndef( Token: TToken; L: TDelphiLexer );
var
  t                 : TToken;
begin
  t                 := L.ParseIfdefToken;
  if ( t = nil ) or ( t.Kind < tkIdent ) then
  begin
    Error( RsIdentifierExpected, [ ], Token );
    FIfdefStack.Ifdef( True ); // default to undefined if no exception was raised
    Exit;
  end;

  if FIfdefStack.Skip then
    FIfdefStack.Ifdef( False )
  else
    FIfdefStack.Ifdef( FDefines.Contains( t.Value ) );
end;

procedure TDelphiPreprocessor.ParseIfopt( Token: TToken; L: TDelphiLexer );
var
  t                 : TToken;
begin
  t                 := L.ParseIfdefToken;
  if ( t = nil ) or ( t.Kind < tkIdent ) then
  begin
    Error( RsIdentifierExpected, [ ], Token );
    FIfdefStack.Ifdef( False ); // default to undefined if no exception was raised
    Exit;
  end;
  // Compiler option states are not tracked, so neither branch can be ruled out: both are kept, and a
  // caller collecting declarations (the uses lists) sees both.  (It used to pick a branch by whether
  // the option letter happened to name a directive handler.)
  if FIfdefStack.Skip then
    FIfdefStack.Ifdef( False )
  else
    FIfdefStack.IfUnknown;
end;

procedure TDelphiPreprocessor.ParseElse( Token: TToken; L: TDelphiLexer );
begin
  if FIfdefStack.Count = 0 then
    Error( RsNoIfdefOpen, [ ], Token )
  else if FIfdefStack.InElse then
    Error( RsMultipleElseNotAllowed, [ ], Token )
  else
    FIfdefStack._Else;
end;

procedure TDelphiPreprocessor.ParseElseif( Token: TToken; L: TDelphiLexer );
var
  p                 : TPreprocessorIfParser;
begin
  if FIfdefStack.Count = 0 then
    Error( RsNoIfdefOpen, [ ], Token )
  else
  begin
    // An earlier branch was taken, the block keeps every branch, or the whole block is excluded: the
    // condition does not decide anything.  (It used to test the stack's Skip, which is also True when
    // only this block's own false $IF excluded the text - the $ELSEIF was then taken unevaluated.)
    if not FIfdefStack.ElseIfNeedsCondition then
      FIfdefStack.ElseIf( True )
    else
    begin
      p             := TPreprocessorIfParser.Create( Self, L );
      try
        FIfdefStack.ElseIf( not p.Parse );
      finally
        p.Free;
      end;
    end;
  end;
end;

procedure TDelphiPreprocessor.ParseDefine( Token: TToken; L: TDelphiLexer );
var
  t                 : TToken;
begin
  if not FIfdefStack.Skip then
  begin
    t               := L.ParseIfdefToken;
    if ( t = nil ) or ( t.Kind < tkIdent ) then
    begin
      Error( RsIdentifierExpected, [ ], Token );
      Exit;
    end;
    Define( t.Value );
  end;
end;

procedure TDelphiPreprocessor.ParseUndef( Token: TToken; L: TDelphiLexer );
var
  t                 : TToken;
begin
  if not FIfdefStack.Skip then
  begin
    t               := L.ParseIfdefToken;
    if ( t = nil ) or ( t.Kind < tkIdent ) then
    begin
      Error( RsIdentifierExpected, [ ], Token );
      Exit;
    end;
    Undefine( t.Value );
  end;
end;

function TDelphiPreprocessor.GetConstBoolValue( const Name: string ): Boolean;
begin
  Result            := False;
  if Assigned( FOnGetConstBoolValue ) then
    FOnGetConstBoolValue( Self, Name, Result );
end;

function TDelphiPreprocessor.GetDeclared( const Name: string ): Boolean;
begin
  Result            := False;
  if Assigned( FOnGetDeclared ) then
    FOnGetDeclared( Self, Name, Result );
end;

function TDelphiPreprocessor.GetDefined( const Name: string ): Boolean;
begin
  Result            := Defines.Contains( Name );
end;

function TDelphiPreprocessor.GetTokenCount: Integer;
begin
  Result            := FTokens.Count;
end;

function TDelphiPreprocessor.GetTokenProp( Index: Integer ): TToken;
begin
  Result            := TToken( FTokens[ Index ] );
end;

procedure TDelphiPreprocessor.GetConstValue( const Name: string;
  out Kind: TTokenKind; out Value: string );
begin
  Value             := '';
  Kind              := tkString;
  if Assigned( FOnGetConstValue ) then
    FOnGetConstValue( Self, Name, Kind, Value );
end;

{ TIfdefStackItem }

procedure TIfdefStackItem.SetSkip( const Value: Boolean );
begin
  FSkip             := Value;
  if not Value then
    Processed       := True;
end;

{ TIfdefStack }

constructor TIfdefStack.Create;
begin
  inherited Create;
  FSkip             := False;
  FStack            := TObjectStack.Create;
end;

destructor TIfdefStack.Destroy;
begin
  while FStack.Count > 0 do // there shouldn't be anything but keep memory leaks low
    TObject( FStack.Pop ).Free;
  FStack.Free;
  inherited Destroy;
end;

function TIfdefStack.GetCount: Integer;
begin
  Result            := FStack.Count;
end;

procedure TIfdefStack._If( ASkip: Boolean );
var
  Item              : TIfdefStackItem;
begin
  Item              := TIfdefStackItem.Create;
  Item.IsIfdef      := False;
  Item.Skip         := ASkip;
  Item.OuterSkip    := FSkip;
  FStack.Push( Item );
  FSkip             := Item.OuterSkip or Item.Skip;
end;

function TIfdefStack.IfEnd: Boolean;
var
  LOuterSkip        : Boolean;
begin
  with TIfdefStackItem( FStack.Pop ) do
  begin
    LOuterSkip      := OuterSkip;
    Result          := not IsIfdef;
    Free;
  end;
  FSkip             := LOuterSkip;
end;

procedure TIfdefStack.ElseIf( ASkip: Boolean );
var
  Item              : TIfdefStackItem;
begin
  Item              := TIfdefStackItem( FStack.Peek );
  //Assert(not Item.ElseProceeded);
  if Item.AllBranches then
    Item.Skip       := False
  else if Item.Processed then
    Item.Skip       := True // an earlier branch was taken: this one is excluded (it used to stay as it was)
  else
    Item.Skip       := ASkip;
  FSkip             := Item.OuterSkip or Item.Skip;
  Item.IsIfdef      := False; // switch to $IF mode
end;

function TIfdefStack.ElseIfNeedsCondition: Boolean;
var
  Item              : TIfdefStackItem;
begin
  Item              := TIfdefStackItem( FStack.Peek );
  Result            := not ( Item.OuterSkip or Item.Processed or Item.AllBranches );
end;

procedure TIfdefStack.IfUnknown;
var
  Item              : TIfdefStackItem;
begin
  Item              := TIfdefStackItem.Create;
  Item.IsIfdef      := True;
  Item.AllBranches  := True;
  Item.Skip         := False;
  Item.OuterSkip    := FSkip;
  FStack.Push( Item );
  FSkip             := Item.OuterSkip;
end;

procedure TIfdefStack.Ifdef( ASkip: Boolean );
var
  Item              : TIfdefStackItem;
begin
  Item              := TIfdefStackItem.Create;
  Item.IsIfdef      := True;
  Item.Skip         := ASkip;
  Item.OuterSkip    := FSkip;
  FStack.Push( Item );
  FSkip             := Item.OuterSkip or Item.Skip;
end;

procedure TIfdefStack._Else;
var
  Item              : TIfdefStackItem;
begin
  Item              := TIfdefStackItem( FStack.Peek );
  Item.Skip         := Item.Processed and not Item.AllBranches;
  FSkip             := Item.OuterSkip or Item.Skip;
  Item.ElseProceeded := True;
end;

function TIfdefStack.EndIf: Boolean;
var
  LOuterSkip        : Boolean;
begin
  with TIfdefStackItem( FStack.Pop ) do
  begin
    LOuterSkip      := OuterSkip;
    Result          := IsIfdef;
    Free;
  end;
  FSkip             := LOuterSkip;
end;

function TIfdefStack.GetInElse: Boolean;
begin
  if FStack.Count > 0 then
    Result          := TIfdefStackItem( FStack.Peek ).ElseProceeded
  else
    Result          := False;
end;

end.

