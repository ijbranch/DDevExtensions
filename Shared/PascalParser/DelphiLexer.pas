{******************************************************************************}
{*                                                                            *}
{* Delphi Lexer                                                               *}
{*                                                                            *}
{* (C) 2003-2008 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit DelphiLexer;

/// <summary>
/// Hand-written lexer for Object Pascal source. Produces a stream of TToken values classified by
/// TTokenKind (symbols, identifiers, keywords, comments, directives, numeric and string literals)
/// suitable for the higher-level DelphiPreproc / DelphiDesignerParser units. UTF-8 input is
/// preferred; PUTF8Char/UTF8Char aliases are provided so the same code compiles on pre-Unicode
/// Delphi versions.
/// </summary>

{$STRINGCHECKS OFF}
{$DEFINE SUPPORTS_INLINE}

interface

uses
  System.SysUtils, System.Classes, System.Contnrs, System.TypInfo;

const
  /// <summary>Control characters and the space, which the lexer skips between tokens.</summary>
  WhiteChars        = [ #1..#32 ];
  /// <summary>Decimal digits, used to recognise integer and float literals.</summary>
  NumberChars       = [ '0'..'9' ];
  /// <summary>Digits allowed in a $-prefixed hexadecimal literal.</summary>
  HexNumberChars    = NumberChars + [ 'A'..'F', 'a'..'f' ];
  /// <summary>ASCII characters that may start an identifier.</summary>
  IdentFirstChars   = [ 'a'..'z', 'A'..'Z', '_' ];
  /// <summary>ASCII characters that may continue an identifier after its first character.</summary>
  IdentChars        = IdentFirstChars + NumberChars;

type
  /// <summary>Pointer to a byte of the UTF-8 source text the lexer scans.</summary>
  PUTF8Char = PAnsiChar;
  /// <summary>One byte of the UTF-8 source text the lexer scans.</summary>
  UTF8Char = AnsiChar;
{$IFNDEF UNICODE}
  /// <summary>Fallback for compilers before Delphi 2009, which lack RawByteString.</summary>
  RawByteString = AnsiString;
  /// <summary>Fallback for compilers before Delphi 2009, which lack UnicodeString.</summary>
  UnicodeString = WideString;
{$ENDIF UNICODE}

  /// <summary>
  /// Classification of a lexed token.  The values are ordered in ranges that callers compare against:
  /// symbols from tkSymbol (compound operators from tkSymbolLevel2), then comments, directives and literals,
  /// then tkIdent followed by the context-sensitive directive words (tkI_read ...) and, from
  /// tkIdentStrictReserved, the strictly reserved words.  A word token's name is its enum name less the
  /// "tkI_" prefix.
  /// </summary>
  TTokenKind = (
    tkNone,

    tkSymbol,
    tkEqual,
    tkGreaterThan,
    tkLessThan,
    tkMinus,
    tkPlus,
    tkMultiply,
    tkDivide,

    tkLParan,
    tkRParan,
    tkLBracket,
    tkRBracket,
    tkColon,
    tkSemicolon,
    tkComma,
    tkPointer, // '^'
    tkAddr, // '@'
    tkAmp, // '&' // D8/9
    tkQualifier, // '.'

    // tkSymbolLevel2 >= tkGreaterEqualThan
    tkGreaterEqualThan, // '>='
    tkLessEqualThan, // '<='
    tkNotEqual, // '<>'
    tkRange, // '..'
    tkAssign, // ':='

    tkComment,
    tkDirective,

    tkString,
    tkInt,
    tkFloat,

    tkMacro, // macro support
    tkIdent,
    tkI_read,
    tkI_write,
    tkI_add,
    tkI_remove,
    tkI_default,
    tkI_name,
    tkI_index,
    tkI_message,
    tkI_static, // D9
    tkI_forward,
    tkI_requires,
    tkI_contains,
    tkI_platform,
    tkI_deprecated,
    tkI_experimental, // D9
    tkI_out,
    tkI_helper,

    tkI_overload,
    tkI_virtual,
    tkI_override,
    tkI_dynamic,
    tkI_abstract,
    tkI_reintroduce,

    tkI_assembler,
    tkI_register,
    tkI_stdcall,
    tkI_cdecl,
    tkI_safecall,
    tkI_pascal,
    tkI_external,

    tkI_automated,
    tkI_strict, // D9
    tkI_private,
    tkI_protected,
    tkI_public,
    tkI_published,
    tkI_local, // D9
    tkI_export,
    tkI_resident, // D9
    tkI_far,
    tkI_near,
    tkI_readonly,
    tkI_writeonly,
    tkI_nodefault,
    tki_stored,
    tkI_implements,
    tkI_varargs,
    tkI_dispid,

    tkI_absolute,
    tkI_final, // D9
    tkI_unsafe, // D9
    tkI_sealed, // D9

    tkI_package,
    tkI_reference,

    tkI_on,
    tkI_at,

    //tkIdentStrictReserved >= tkI_if
    tkI_if,
    tkI_else,
    tkI_then,
    tkI_while,
    tkI_do,
    tkI_for,
    tkI_to,
    tkI_downto,
    tkI_repeat,
    tkI_until,
    tkI_case,
    tkI_with,
    tkI_raise,
    tkI_in,
    tkI_is,
    tkI_as,
    tkI_of,
    tkI_file,
    tkI_goto,
    tkI_except,
    tkI_finally,
    tkI_try,
    tkI_nil,

    tkI_shl,
    tkI_shr,
    tkI_mod,
    tkI_div,
    tkI_and,
    tkI_or,
    tkI_not,
    tkI_xor,

    tkI_class,
    tkI_object,
    tkI_record,
    tkI_var,
    tkI_const,
    tkI_type,
    tkI_threadvar,
    tkI_label,
    tkI_exports,
    tkI_resourcestring,
    tkI_unit,
    tkI_program,
    tkI_uses,
    tkI_interface,
    tkI_implementation,
    tkI_begin,
    tkI_end,
    tkI_procedure,
    tkI_function,
    tkI_operator,
    tkI_constructor,
    tkI_destructor,
    tkI_property,
    tkI_packed,
    tkI_dispinterface,
    tkI_string,

    tkI_array,
    tkI_set,

    tkI_asm,

    tkI_inherited,
    tkI_inline,

    tkI_library,
    tkI_initialization,
    tkI_finalization
    );

  /// <summary>Set of token kinds, for testing a token against several kinds at once.</summary>
  TTokenKindSet = set of TTokenKind;

const
  /// <summary>First token kind that represents a multi-character compound operator (&gt;=, &lt;=, ...).</summary>
  tkSymbolLevel2    = tkGreaterEqualThan;
  /// <summary>First token kind that represents a strictly-reserved keyword (if, else, ...).</summary>
  tkIdentStrictReserved = tkI_if;
  /// <summary>Highest TTokenKind value; useful for array bounds.</summary>
  tkLast            = High( TTokenKind );
  /// <summary>Alias for tkQualifier so callers can use the more descriptive name "tkDot".</summary>
  tkDot             = tkQualifier;

type
  /// <summary>Forward declaration of the lexer.</summary>
  TDelphiLexer = class;

  /// <summary>Single token produced by the lexer: classification, source value and source location.</summary>
  TToken = class( TObject )
  private
    /// <summary>0-based position of this token in the lexer's token list.</summary>
    FTokenIndex: Integer;
    /// <summary>Classification of the token.</summary>
    FKind: TTokenKind;
    /// <summary>The token's text as a native string.</summary>
    FValue: string;
    /// <summary>1-based column of the token's first character.</summary>
    FColumn: Integer;
    /// <summary>0-based line of the token's first character.</summary>
    FLine: Integer;
    /// <summary>1-based byte index of the token's first character in the lexer's UTF-8 text.</summary>
    FIndex: Integer;
    /// <summary>Name of the file the token was lexed from.</summary>
    FFilename: string;
    /// <summary>Number of bytes the token occupies in the lexer's UTF-8 text.</summary>
    FTokenLength: Integer;
    /// <summary>Computes the 1-based byte index of the token's last character.</summary>
    /// <returns>Index + TokenLength - 1.</returns>
    function GetEndIndex: Integer; {$IFDEF SUPPORTS_INLINE} inline; {$ENDIF}
  protected
    /// <summary>Shifts the token's position after the lexer's text was edited before it.</summary>
    /// <param name="OffsetTokenIndex">Amount added to TokenIndex.</param>
    /// <param name="OffsetIndex">Amount added to Index.</param>
    /// <param name="OffsetColumn">Amount added to Column.</param>
    /// <param name="OffsetLine">Amount added to Line.</param>
    procedure OffsetToken( OffsetTokenIndex, OffsetIndex, OffsetColumn, OffsetLine: Integer );
  public
    /// <summary>Creates a token with the classification, text and position the lexer found.</summary>
    /// <param name="ATokenIndex">0-based position of the token in the lexer's token list.</param>
    /// <param name="AKind">Classification of the token.</param>
    /// <param name="AValue">The token's text.</param>
    /// <param name="AFilename">Name of the file the token was lexed from.</param>
    /// <param name="ALine">0-based line of the token's first character.</param>
    /// <param name="AColumn">1-based column of the token's first character.</param>
    /// <param name="AIndex">1-based byte index of the token's first character.</param>
    /// <param name="ATokenLength">Number of bytes the token occupies in the source text.</param>
    constructor Create( ATokenIndex: Integer; AKind: TTokenKind; const AValue, AFilename: string;
      ALine, AColumn, AIndex, ATokenLength: Integer );
    //class function NewInstance: TObject; override;
    //procedure FreeInstance; override;

    /// <summary>Tells whether the token is an identifier or any keyword or directive word.</summary>
    /// <returns>True when Kind is tkIdent or later.</returns>
    function IsIdent: Boolean; {$IFDEF SUPPORTS_INLINE} inline; {$ENDIF}
    /// <summary>Tells whether the token can be used as a plain identifier, i.e. is not a strictly reserved word.</summary>
    /// <returns>True when Kind is from tkIdent up to, but not including, tkIdentStrictReserved.</returns>
    function IsFreeUsableIdent: Boolean; {$IFDEF SUPPORTS_INLINE} inline; {$ENDIF}
    /// <summary>Tells whether the token can name a type: a freely usable identifier or the word "string".</summary>
    /// <returns>True for a freely usable identifier or tkI_string.</returns>
    function IsTypeIdent: Boolean; {$IFDEF SUPPORTS_INLINE} inline; {$ENDIF}

    /// <summary>Extracts the text of a comment token without its delimiters.</summary>
    /// <returns>The text inside { }, (* *) or after //; empty when the token is not a comment.</returns>
    function GetCommentBody: string;

    /// <summary>Classification of the token.</summary>
    property Kind: TTokenKind read FKind;
    /// <summary>The token's text.  WARNING: Index + Length(Value) &lt;&gt; EndIndex; use TokenLength for source positions.</summary>
    property Value: string read FValue;

    /// <summary>0-based line of the token's first character (0..n-1).</summary>
    property Line: Integer read FLine;
    /// <summary>1-based column of the token's first character (1..m).</summary>
    property Column: Integer read FColumn;
    /// <summary>1-based byte index of the token's first character in the lexer's UTF-8 text (1..k).</summary>
    property Index: Integer read FIndex;
    /// <summary>Name of the file the token was lexed from.</summary>
    property Filename: string read FFilename;
    /// <summary>0-based position of the token in the lexer's token list (0..j-1).</summary>
    property TokenIndex: Integer read FTokenIndex;
    /// <summary>Number of bytes the token occupies in the lexer's UTF-8 text.</summary>
    property TokenLength: Integer read FTokenLength;
    /// <summary>1-based byte index of the token's last character (1..k).</summary>
    property EndIndex: Integer read GetEndIndex;
  end;

  /// <summary>
  /// Delphi lexer. Text must not contain a BOM. On Delphi 2009 and later Text is interpreted as
  /// UTF-8; on Delphi 5..2007 it is treated as ANSI. Maintains a list of previously parsed tokens
  /// so the caller can rewind, look ahead and edit the source via DeleteToken / InsertText.
  /// </summary>
  TDelphiLexer = class( TObject )
  private
    /// <summary>Name of the file being lexed, copied into every token.</summary>
    FFilename: string;
    /// <summary>The UTF-8 source text; edited in place by the modification methods.</summary>
    FText: UTF8String;
    /// <summary>0-based line number of the first line of Text, restored when the token list is discarded.</summary>
    FStartLine: Integer;
    /// <summary>0-based line of the scan position.</summary>
    FLine: Integer;
    /// <summary>1-based column of the first character of Text, restored when the token list is discarded.</summary>
    FStartColumn: Integer;
    /// <summary>1-based column of the scan position.</summary>
    FColumn: Integer;
    /// <summary>1-based byte index in Text of the next character to lex.</summary>
    FIndex: Integer;

    /// <summary>Every token lexed so far, in source order.</summary>
    FTokens: TObjectList;
    /// <summary>Position in FTokens of the token NextToken returns next; CurrentToken is the one before it.</summary>
    FCurTokenIndex: Integer;
    /// <summary>True once Text has been changed by a modification method.</summary>
    FModified: Boolean;
    /// <summary>When True, $__name is lexed as a single tkMacro token.</summary>
    FSupportMacroTokens: Boolean;
    /// <summary>Set by ParseIfdefToken so that an identifier may start with a digit (e.g. 7ZIP_LINKONREQUEST).</summary>
    FPreprocMode: Boolean;
    /// <summary>Reads Count.</summary>
    /// <returns>Number of tokens lexed so far.</returns>
    function GetCount: Integer;
    /// <summary>Reads Tokens[Index].</summary>
    /// <param name="Index">0-based position in the token list.</param>
    /// <returns>The token at Index.</returns>
    function GetTokenProp( Index: Integer ): TToken;
    /// <summary>
    /// Drops the lexed tokens at or after StartIndex after an edit and moves the scan position back to
    /// re-lex from there; drops all tokens and restarts from the beginning when StartIndex is at or before the
    /// first token.
    /// </summary>
    /// <param name="StartIndex">1-based byte index in Text where the edit began.</param>
    procedure DiscardTokens( StartIndex: Integer );
    /// <summary>Reads CurrentToken.</summary>
    /// <returns>The token NextToken returned last, or nil.</returns>
    function GetCurrentToken: TToken;
    /// <summary>Reads PreviousToken.</summary>
    /// <returns>The token before CurrentToken, or nil at the start.</returns>
    function GetPreviousToken: TToken;
    /// <summary>Counts the tabs and spaces in Text from StartIndex on.</summary>
    /// <param name="StartIndex">1-based byte index in Text to start counting at.</param>
    /// <returns>Number of consecutive tab and space characters.</returns>
    function CountSpaces( StartIndex: Integer ): Integer;
  public
    /// <summary>Creates a lexer over AText, positioned at its start.</summary>
    /// <param name="AFilename">Name of the file AText came from, copied into every token.</param>
    /// <param name="AText">UTF-8 source text without a BOM.</param>
    /// <param name="AOwnsTokens">True to free the tokens with the lexer; False when the caller keeps them.</param>
    /// <param name="AStartLine">0-based line number to give the first line of AText.</param>
    /// <param name="AStartColumn">1-based column to give the first character of AText (values below 1 become 1).</param>
    constructor Create( const AFilename: string; const AText: UTF8String;
      AOwnsTokens: Boolean = True; AStartLine: Integer = 0; AStartColumn: Integer = 1 );
    /// <summary>Frees the token list (and the tokens when the lexer owns them).</summary>
    destructor Destroy; override;

    /// <summary>
    /// Low level: lexes the next token from the scan position and appends it to Tokens, regardless of
    /// the NextToken read position.  Handles Delphi 12 multi-line strings, &amp;-escaped identifiers,
    /// binary literals and digit separators.
    /// </summary>
    /// <returns>The new token, or nil at the end of Text.</returns>
    function GetToken: TToken; overload;
    /// <summary>Low level: lexes the next token from the scan position and appends it to Tokens.</summary>
    /// <param name="Token">Receives the new token, or nil at the end of Text.</param>
    /// <returns>True when a token was lexed.</returns>
    function GetToken( out Token: TToken ): Boolean; overload;

    /// <summary>High level: moves the read position back to the first token; lexed tokens are kept.</summary>
    procedure RestartLexer;
    /// <summary>Moves the read position back one token, so NextToken returns CurrentToken again.</summary>
    procedure RewindLastToken;
    /// <summary>Returns the token at the read position, lexing it if needed, and advances the read position.</summary>
    /// <returns>The next token, or nil at the end of Text.</returns>
    function NextToken: TToken; overload;
    /// <summary>Returns the token at the read position, lexing it if needed, and advances the read position.</summary>
    /// <param name="Token">Receives the next token, or nil at the end of Text.</param>
    /// <returns>True when there was a token.</returns>
    function NextToken( out Token: TToken ): Boolean; overload;
    /// <summary>
    /// As NextToken, but skips comments and compiler directives - except an include directive
    /// (<c>{$I file}</c>, <c>{$INCLUDE file}</c> and the <c>(*$ *)</c> forms; not the <c>{$I+}</c>
    /// switch), which is returned so the caller can see that text from another file belongs there.
    /// </summary>
    /// <returns>The next token that is not a comment or a non-include directive, or nil at the end of Text.</returns>
    function NextTokenNoComment: TToken; overload;
    /// <summary>As NextToken, but skips comments and compiler directives other than include directives.</summary>
    /// <param name="Token">Receives the next token that is not a comment or a non-include directive, or nil.</param>
    /// <returns>True when there was such a token.</returns>
    function NextTokenNoComment( out Token: TToken ): Boolean; overload;
    /// <summary>Finds the already-lexed token before Token.</summary>
    /// <param name="Token">A token of this lexer.</param>
    /// <returns>The preceding token, or nil when Token is the first.</returns>
    function PreTokenOf( Token: TToken ): TToken;
    /// <summary>Finds the nearest already-lexed token before Token that is not a comment (directives count).</summary>
    /// <param name="Token">A token of this lexer.</param>
    /// <returns>The preceding non-comment token, or nil when there is none.</returns>
    function PreTokenNoCommentOf( Token: TToken ): TToken;
    /// <summary>Finds the already-lexed token after Token; does not lex further.</summary>
    /// <param name="Token">A token of this lexer.</param>
    /// <returns>The following token, or nil when Token is the last lexed so far.</returns>
    function NextTokenOf( Token: TToken ): TToken;
    /// <summary>Finds the nearest already-lexed token after Token that is not a comment; does not lex further.</summary>
    /// <param name="Token">A token of this lexer.</param>
    /// <returns>The following non-comment token, or nil when there is none yet.</returns>
    function NextTokenNoCommentOf( Token: TToken ): TToken;
    /// <summary>
    /// Builds the source text of the string expression starting at CurrentToken: the string constant and
    /// every following "+ string" or "+ identifier" part.  Leaves the read position after the last part.
    /// </summary>
    /// <returns>The concatenated source text, joined with " + "; empty when CurrentToken is not a string.</returns>
    function GetFullStringNext: string;
    /// <summary>
    /// Joins CurrentToken's string constant with directly adjacent #-character tokens (as in 'a'#13#10, but
    /// not #13 #10).  Leaves the read position on the token after the last string part.
    /// </summary>
    /// <param name="CombinedString">Receives the combined source text when CurrentToken is a string.</param>
    /// <returns>Number of string tokens joined; 0 when CurrentToken is not a string.</returns>
    function GetCombinedStringConstantNext( var CombinedString: string ): Integer;
    /// <summary>Peeks at the next token without moving the read position.</summary>
    /// <returns>The token NextToken would return, or nil.</returns>
    function LookAhead: TToken;
    /// <summary>Peeks at the next token that is not a comment or a non-include directive, without moving the read position.</summary>
    /// <returns>The token NextTokenNoComment would return, or nil.</returns>
    function LookAheadNoComment: TToken;

    /// <summary>
    /// Reads a dotted name (e.g. System.SysUtils.TObject) from CurrentToken, skipping comments and
    /// directives between the parts.  Leaves the read position on the token after the last part.
    /// </summary>
    /// <returns>The dotted name; empty when CurrentToken is nil or not a type identifier.</returns>
    function ParseIdentifierName: string;
    /// <summary>Lexes the next token in preprocessor mode, where an identifier may start with a digit (e.g. 7ZIP_LINKONREQUEST).</summary>
    /// <returns>The new token, or nil at the end of Text.</returns>
    function ParseIfdefToken: TToken;

    /// <summary>Modification: removes Token's text from Text and the token from Tokens, shifting later tokens.</summary>
    /// <param name="Token">Token to delete; nil does nothing.</param>
    /// <param name="DeleteEndSpaces">True to delete the tabs and spaces after the token as well.</param>
    procedure DeleteToken( Token: TToken; DeleteEndSpaces: Boolean = False );
    /// <summary>Removes the text from StartToken to EndToken inclusive, and those tokens, shifting later tokens.</summary>
    /// <param name="StartToken">First token to delete; when nil only EndToken is deleted.</param>
    /// <param name="EndToken">Last token to delete; when nil only StartToken is deleted.</param>
    /// <param name="DeleteEndSpaces">True to delete the tabs and spaces after EndToken as well.</param>
    procedure DeleteTokens( StartToken, EndToken: TToken; DeleteEndSpaces: Boolean = False );
    /// <summary>Inserts UTF-8 text directly after Token; tokens from there on are re-lexed.</summary>
    /// <param name="Token">Token to insert after.</param>
    /// <param name="Text">UTF-8 text to insert.</param>
    procedure InsertTextAfter( Token: TToken; const Text: UTF8String ); overload;
    /// <summary>Inserts text directly after Token; tokens from there on are re-lexed.</summary>
    /// <param name="Token">Token to insert after.</param>
    /// <param name="Text">Text to insert (stored as UTF-8).</param>
    procedure InsertTextAfter( Token: TToken; const Text: string ); overload;
    /// <summary>Replaces Token's text with UTF-8 text; tokens from there on are re-lexed.</summary>
    /// <param name="Token">Token to replace.</param>
    /// <param name="Text">UTF-8 replacement text.</param>
    procedure ReplaceToken( Token: TToken; const Text: UTF8String ); overload;
    /// <summary>Replaces Token's text; tokens from there on are re-lexed.</summary>
    /// <param name="Token">Token to replace.</param>
    /// <param name="Text">Replacement text (stored as UTF-8).</param>
    procedure ReplaceToken( Token: TToken; const Text: string ); overload;
    /// <summary>Deletes Len bytes of Text at StartIndex; tokens from there on are re-lexed.</summary>
    /// <param name="StartIndex">1-based byte index of the first byte to delete.</param>
    /// <param name="Len">Number of bytes to delete; 0 or less does nothing.</param>
    procedure DeleteText( StartIndex, Len: Integer );
    /// <summary>Inserts UTF-8 text at StartIndex; tokens from there on are re-lexed.</summary>
    /// <param name="StartIndex">1-based byte index to insert at.</param>
    /// <param name="Text">UTF-8 text to insert; empty does nothing.</param>
    procedure InsertText( StartIndex: Integer; const Text: UTF8String ); overload;
    /// <summary>Inserts text at StartIndex; tokens from there on are re-lexed.</summary>
    /// <param name="StartIndex">1-based byte index to insert at.</param>
    /// <param name="Text">Text to insert (stored as UTF-8).</param>
    procedure InsertText( StartIndex: Integer; const Text: string ); overload;
    /// <summary>Replaces Len bytes of Text at StartIndex with UTF-8 text; tokens from there on are re-lexed.</summary>
    /// <param name="StartIndex">1-based byte index of the first byte to replace.</param>
    /// <param name="Len">Number of bytes to replace.</param>
    /// <param name="Text">UTF-8 replacement text.</param>
    procedure ReplaceText( StartIndex, Len: Integer; const Text: UTF8String ); overload;
    /// <summary>Replaces Len bytes of Text at StartIndex; tokens from there on are re-lexed.</summary>
    /// <param name="StartIndex">1-based byte index of the first byte to replace.</param>
    /// <param name="Len">Number of bytes to replace.</param>
    /// <param name="Text">Replacement text (stored as UTF-8).</param>
    procedure ReplaceText( StartIndex, Len: Integer; const Text: string ); overload;

    /// <summary>1-based byte index in Text of the next character to lex.</summary>
    property Index: Integer read FIndex;
    /// <summary>0-based line of the scan position.</summary>
    property Line: Integer read FLine;
    /// <summary>1-based column of the scan position.</summary>
    property Column: Integer read FColumn;
    /// <summary>The UTF-8 source text, including any edits made through the modification methods.</summary>
    property Text: UTF8String read FText;
    /// <summary>Name of the file being lexed.</summary>
    property Filename: string read FFilename;

    /// <summary>Number of tokens already lexed.</summary>
    property Count: Integer read GetCount;
    /// <summary>The already-lexed tokens, by 0-based position.</summary>
    property Tokens[ Index: Integer ]: TToken read GetTokenProp;
    /// <summary>True once Text has been changed by a modification method.</summary>
    property Modified: Boolean read FModified;
    /// <summary>The token before CurrentToken, or nil.</summary>
    property PreviousToken: TToken read GetPreviousToken;
    /// <summary>The token NextToken returned last.</summary>
    property CurrentToken: TToken read GetCurrentToken;

    /// <summary>When True, $__name is lexed as a single tkMacro token; off by default.</summary>
    property SupportMacroTokens: Boolean read FSupportMacroTokens write FSupportMacroTokens;
  end;

type
  /// <summary>Byte-order-mark identifier returned by TTextFileReader after BOM detection.</summary>
  TBOMType = ( bomAnsi, bomUtf8, bomUcs2BE, bomUcs2LE, bomUcs4BE, bomUcs4LE );

{$IFDEF CONDITIONALEXPRESSIONS}
{$IF not declared(TBytes)}
  /// <summary>Fallback declaration of TBytes for Delphi versions that lack it.</summary>
  TBytes = array of Byte;
{$IFEND}
{$ELSE}
  /// <summary>Fallback declaration of TBytes for pre-conditional-expression compilers.</summary>
  TBytes = array of Byte;
{$ENDIF}

  /// <summary>
  /// Buffered text reader that detects the input's BOM and decodes the text to a native or UTF-8 string.
  /// A file without a BOM is read as UTF-8 when its first block is valid UTF-8, otherwise as ANSI; that
  /// decision is made once and holds for the whole file.
  /// </summary>
  TTextFileReader = class( TObject )
  private
    /// <summary>True when the reader frees FStream on destruction.</summary>
    FOwnStream: Boolean;
    /// <summary>The stream the text is read from.</summary>
    FStream: TStream;
    /// <summary>Read buffer; its size is rounded up to a whole number of characters for UCS-2 and UCS-4.</summary>
    FBuffer: TBytes;
    /// <summary>Index in FBuffer of the next unconsumed byte.</summary>
    FBufStart: Integer;
    /// <summary>Number of valid bytes in FBuffer; 0 at the end of the input.</summary>
    FBufCount: Integer;
    /// <summary>Encoding found by ReadBOM; bomAnsi when the input has no BOM.</summary>
    FBOMType: TBOMType;
    /// <summary>Most bytes to read from the stream; 0 for no limit.</summary>
    FMaxReadBytes: Cardinal;
    /// <summary>Bytes read from the stream by FillBuffer so far, checked against FMaxReadBytes.</summary>
    FBytesRead: Cardinal;
    /// <summary>For a file without a BOM: 0 = not decided yet, 1 = UTF-8, 2 = ANSI.  The first block read decides for the whole file.</summary>
    FBomlessEncoding: Integer;
    /// <summary>Returns True when the BOM-less file is UTF-8, deciding from Data on the first call.</summary>
    /// <param name="Data">The first block of text read (later calls ignore it).</param>
    /// <returns>True for UTF-8, False for the ANSI code page.</returns>
    function AnsiDataIsUtf8( const Data: TBytes ): Boolean;

    /// <summary>Fills the buffer with the first block of the stream and sets BOMType from any BOM, skipping it.</summary>
    procedure ReadBOM;
    /// <summary>Refills the buffer from the stream once it is used up, honouring MaxReadBytes.</summary>
    procedure FillBuffer;
    /// <summary>Reads Eof.</summary>
    /// <returns>True when the buffer holds no more data.</returns>
    function GetEof: Boolean;
    /// <summary>Decodes Data according to the BOM found by ReadBOM: ANSI, UTF-8, UTF-16 (either byte order) or UCS-4.</summary>
    /// <param name="Data">Raw bytes read after the BOM.</param>
    /// <returns>The decoded text; empty when Data is nil.</returns>
    function DataToString( const Data: TBytes ): string;
    /// <summary>Converts Data to UTF-8: UTF-8 (and BOM-less UTF-8) bytes are copied as they are, anything else is decoded first.</summary>
    /// <param name="Data">Raw bytes read after the BOM.</param>
    /// <returns>The text as UTF-8; empty when Data is nil.</returns>
    function DataToUtf8String( const Data: TBytes ): UTF8String;
    /// <summary>Reads every remaining byte of the stream, up to MaxReadBytes.</summary>
    /// <returns>The raw bytes read.</returns>
    function InternReadAll: TBytes;
    /// <summary>Reads raw bytes up to the next line break (CR, LF or CR LF) and consumes the line break.</summary>
    /// <returns>The line's bytes without the line break; nil at the end of the input.</returns>
    /// <exception cref="Exception">The input is UCS-2 or UCS-4: only ANSI and UTF-8 can be read by line.</exception>
    function InternReadLine: TBytes;
  public
    /// <summary>Opens AFileName for reading (deny write) and detects its BOM; the reader owns the file stream.</summary>
    /// <param name="AFileName">File to read.</param>
    /// <param name="ABufferSize">Read buffer size in bytes (at least 16).</param>
    constructor Create( const AFileName: string; ABufferSize: Integer = 4096 ); overload;
    /// <summary>Reads from AStream, starting at its current position, and detects its BOM.</summary>
    /// <param name="AStream">Stream to read.</param>
    /// <param name="ABufferSize">Read buffer size in bytes (at least 16).</param>
    /// <param name="AOwnStream">True to free AStream with the reader.</param>
    constructor Create( AStream: TStream; ABufferSize: Integer = 4096; AOwnStream: Boolean = False ); overload;
    /// <summary>Frees the stream when the reader owns it.</summary>
    destructor Destroy; override;

    /// <summary>Reads the rest of the input, up to MaxReadBytes, decoded to a native string.</summary>
    /// <returns>The decoded text.</returns>
    function ReadAll: string;
    /// <summary>Reads the next line, decoded to a native string.</summary>
    /// <returns>The line without its line break; empty at the end of the input.</returns>
    /// <exception cref="Exception">The input is UCS-2 or UCS-4: only ANSI and UTF-8 can be read by line.</exception>
    function ReadLine: string;
    /// <summary>Reads the rest of the input, up to MaxReadBytes, as UTF-8.</summary>
    /// <returns>The text as UTF-8, without the BOM.</returns>
    function Utf8ReadAll: UTF8String;
    /// <summary>Reads the next line as UTF-8.</summary>
    /// <returns>The line without its line break; empty at the end of the input.</returns>
    /// <exception cref="Exception">The input is UCS-2 or UCS-4: only ANSI and UTF-8 can be read by line.</exception>
    function Utf8ReadLine: UTF8String;

    /// <summary>Most bytes to read from the stream (counting the first block read with the BOM); 0 for no limit.</summary>
    property MaxReadBytes: Cardinal read FMaxReadBytes write FMaxReadBytes;
    /// <summary>True when the buffer holds no more data.</summary>
    property Eof: Boolean read GetEof;
    /// <summary>Encoding found from the BOM; bomAnsi when the input has none.</summary>
    property BOMType: TBOMType read FBOMType;
  end;

/// <summary>Returns a display name for a token kind: the symbol itself, the keyword in upper case, or a literal kind's name.</summary>
/// <param name="Kind">Token kind to name.</param>
/// <returns>The display name; tkNone, tkSymbol, tkComment, tkDirective and tkMacro have none and are not assigned one.</returns>
function TokenKindToString( Kind: TTokenKind ): string;
/// <summary>Reads Filename via TTextFileReader and returns its content as a native string.</summary>
/// <param name="Filename">File to read.</param>
/// <param name="MaxReadBytes">Most bytes to read; 0 for the whole file.</param>
/// <returns>The decoded text, without the BOM.</returns>
function LoadTextFileToString( const Filename: string; MaxReadBytes: Cardinal = 0 ): string;
/// <summary>Reads up to MaxReadBytes from Filename and returns it as UTF-8 (BOM-stripped).</summary>
/// <param name="Filename">File to read.</param>
/// <param name="MaxReadBytes">Most bytes to read; 0 for the whole file.</param>
/// <returns>The text as UTF-8.</returns>
function LoadTextFileToUtf8String( const Filename: string; MaxReadBytes: Cardinal ): UTF8String; overload;
/// <summary>Reads up to MaxReadBytes from Filename as UTF-8 (BOM-stripped) and reports the encoding found.</summary>
/// <param name="Filename">File to read.</param>
/// <param name="MaxReadBytes">Most bytes to read; 0 for the whole file.</param>
/// <param name="Encoding">
/// Receives the encoding found from the BOM: TEncoding.UTF8, Unicode or BigEndianUnicode (UCS-4 is reported as the
/// UTF-16 encoding of the same byte order), or TEncoding.Default when there is no BOM, even when the text was read as UTF-8.
/// </param>
/// <returns>The text as UTF-8.</returns>
function LoadTextFileToUtf8String( const Filename: string; MaxReadBytes: Cardinal; out Encoding: TEncoding ): UTF8String; overload;
/// <summary>Reads the entire Filename and returns it as UTF-8 (BOM-stripped).</summary>
/// <param name="Filename">File to read.</param>
/// <returns>The text as UTF-8.</returns>
function LoadTextFileToUtf8String( const Filename: string ): UTF8String; overload;
/// <summary>Reads the entire Filename as UTF-8 (BOM-stripped) and reports the encoding found.</summary>
/// <param name="Filename">File to read.</param>
/// <param name="Encoding">Receives the encoding found from the BOM, as for the MaxReadBytes overload.</param>
/// <returns>The text as UTF-8.</returns>
function LoadTextFileToUtf8String( const Filename: string; out Encoding: TEncoding ): UTF8String; overload;
/// <summary>Returns the C++Builder mangled form of a name: its length followed by the name, with every '.' replaced by '_'.</summary>
/// <param name="Name">Name to mangle.</param>
/// <returns>The mangled name.</returns>
function Mangle( const Name: string ): string;
/// <summary>Tells whether Token is an $ENDIF or $IFEND directive, in { } or (* *) form.</summary>
/// <param name="Token">Token to test.</param>
/// <returns>True for an $ENDIF or $IFEND directive.</returns>
function IsEndIfToken( Token: TToken ): Boolean; {$IFDEF SUPPORTS_INLINE} inline; {$ENDIF}
/// <summary>ASCII-only case-insensitive StartsText that does not depend on the locale.</summary>
/// <param name="SubStr">Prefix to look for.</param>
/// <param name="S">String to test.</param>
/// <returns>True when S starts with SubStr, ignoring ASCII case.</returns>
function AsciiStartsText( const SubStr, S: string ): Boolean;

implementation

uses
  Winapi.Windows{$IFDEF UNICODE}, System.WideStrUtils, System.Character{$ENDIF UNICODE};

resourcestring
  RsIdentifier      = 'Identifier';
  RsString          = 'String';
  RsInteger         = 'Integer';
  RsFloat           = 'Float number';

type
  TLexerTokenStringList = class( TStringList )
  protected
    function CompareStrings( const S1: string; const S2: string ): Integer; override;
  end;

function TLexerTokenStringList.CompareStrings( const S1: string; const S2: string ): Integer;
begin
  Result            := CompareText( S1, S2 );
end;

var
  TokenStrings      : TLexerTokenStringList;

procedure InitTokenStrings;
var
  Kind              : TTokenKind;
  Info              : PTypeInfo;
begin
  TokenStrings      := TLexerTokenStringList.Create;

  Info              := TypeInfo( TTokenKind );
  for Kind := Succ( tkIdent ) to High( TTokenKind ) do
    TokenStrings.AddObject(
      Copy( GetEnumName( Info, Ord( Kind ) ), 5, MaxInt ),
      TObject( Integer( Kind ) )
      );

  TokenStrings.Sorted := True;
end;

function FindTokenIdentKind( const Value: string ): TTokenKind;
var
  Index             : Integer;
begin
  if TokenStrings.Find( Value, Index ) then
    Result          := TTokenKind( Integer( TokenStrings.Objects[ Index ] ) )
  else
    Result          := tkIdent;
end;

function TokenKindToString( Kind: TTokenKind ): string;
begin
  if Kind > tkIdent then
    Result          := AnsiUpperCase( Copy( GetEnumName( TypeInfo( TTokenKind ), Integer( Kind ) ), 5, MaxInt ) )
  else
  begin
    case Kind of
      tkEqual: Result := '=';
      tkGreaterThan: Result := '>';
      tkLessThan: Result := '<';
      tkMinus: Result := '-';
      tkPlus: Result := '+';
      tkMultiply: Result := '*';
      tkDivide: Result := '/';

      tkLParan: Result := '(';
      tkRParan: Result := ')';
      tkLBracket: Result := '[';
      tkRBracket: Result := ']';
      tkColon: Result := ':';
      tkSemicolon: Result := ';';
      tkComma: Result := ',';
      tkPointer: Result := '^';
      tkAddr: Result := '@';
      tkAmp: Result := '&';
      tkQualifier: Result := '.';

      tkGreaterEqualThan: Result := '>=';
      tkLessEqualThan: Result := '<=';
      tkNotEqual: Result := '<>';
      tkRange: Result := '..';
      tkAssign: Result := ':=';

      {tkComment: Result := RsComment;
      tkDirective: Result := RsCompilerDirective}

      tkIdent: Result := RsIdentifier;
      tkString: Result := RsString;
      tkInt: Result := RsInteger;
      tkFloat: Result := RsFloat;
    end;
    Result          := '' + Result + '';
  end;
end;

{$IFDEF UNICODE}
procedure SetStringFromUtf8( var S: string; P: PAnsiChar; Len: Integer );
begin
  SetLength( S, Len );
  Len               := Utf8ToUnicode( PWideChar( S ), Len + 1, P, Len );
  if Len <= 0 then
    S               := ''
  else if Length( S ) <> Len - 1 then
    SetLength( S, Len - 1 );
end;
{$ENDIF UNICODE}

function LoadTextFileToString( const Filename: string; MaxReadBytes: Cardinal = 0 ): string;
var
  Reader            : TTextFileReader;
begin
  Reader            := TTextFileReader.Create( Filename );
  try
    Reader.MaxReadBytes := MaxReadBytes;
    Result          := Reader.ReadAll;
  finally
    Reader.Free;
  end;
end;

function LoadTextFileToUtf8String( const Filename: string; MaxReadBytes: Cardinal ): UTF8String;
var
  Encoding          : TEncoding;
begin
  Result            := LoadTextFileToUtf8String( FileName, MaxReadBytes, Encoding );
end;

function LoadTextFileToUtf8String( const Filename: string; MaxReadBytes: Cardinal; out Encoding: TEncoding ): UTF8String; overload;
var
  Reader            : TTextFileReader;
begin
  Reader            := TTextFileReader.Create( Filename );
  try
    if MaxReadBytes > 0 then
      Reader.MaxReadBytes := MaxReadBytes;
    Result          := Reader.Utf8ReadAll;

    Encoding        := TEncoding.Default;
    case Reader.BOMType of
      //bomAnsi: Encoding := TEncoding.Default;
      bomUtf8: Encoding := TEncoding.UTF8;
      bomUcs2BE: Encoding := TEncoding.BigEndianUnicode;
      bomUcs2LE: Encoding := TEncoding.Unicode;
      bomUcs4BE: Encoding := TEncoding.BigEndianUnicode;
      bomUcs4LE: Encoding := TEncoding.Unicode;
    end;
  finally
    Reader.Free;
  end;
end;

function LoadTextFileToUtf8String( const Filename: string ): UTF8String;
var
  Encoding          : TEncoding;
begin
  Result            := LoadTextFileToUtf8String( Filename, 0, Encoding );
end;

function LoadTextFileToUtf8String( const Filename: string; out Encoding: TEncoding ): UTF8String; overload;
begin
  Result            := LoadTextFileToUtf8String( FileName, 0, Encoding );
end;

function AsciiStartsText( const SubStr, S: string ): Boolean;
var
  Len               : Integer;
begin
  Len               := Length( SubStr );
  if Len <= Length( S ) then
    Result          := StrLIComp( PChar( SubStr ), PChar( S ), Length( SubStr ) ) = 0
  else
    Result          := False;
end;

function Mangle( const Name: string ): string;
var
  P                 : PChar;
begin
  Result            := IntToStr( Length( Name ) ) + Name;
  P                 := PChar( Result );
  while P[ 0 ] <> #0 do
  begin
    if P[ 0 ] = '.' then
      P[ 0 ]        := '_';
    Inc( P );
  end;
end;

function IsEndIfToken( Token: TToken ): Boolean;
begin
  Result            := ( Token.Kind = tkDirective ) and
    ( AsciiStartsText( '{$ENDIF', Token.Value ) or AsciiStartsText( '{$IFEND', Token.Value ) or
    AsciiStartsText( '(*$ENDIF', Token.Value ) or AsciiStartsText( '(*$IFEND', Token.Value ) );
end;

function FindLineStart( const S: UTF8String; Index: Integer ): Integer;
begin
  Result            := Index;
  while ( Result > 0 ) do
  begin
    case S[ Result ] of
      #10, #13:
        Break;
    end;
    Dec( Result );
  end;
  Inc( Result );
end;

{$IFDEF UNICODE}
/// <summary>
/// Decodes the UTF-8 sequence at P[Index] into its first UTF-16 code unit.  Fails, without reading
/// past the sequence, when the lead byte is not a multi-byte lead or a continuation byte is missing
/// (a truncated sequence at the end of the text stops at the terminating #0, which is no
/// continuation byte).
/// </summary>
/// <param name="P">The text.</param>
/// <param name="Index">Offset of the lead byte in P.</param>
/// <param name="Ch">Receives the first decoded code unit.</param>
/// <returns>True when a complete, valid sequence was decoded.</returns>
function DecodeUtf8Char( P: PUTF8Char; Index: Integer; out Ch: WideChar ): Boolean;
var
  C                 : array[ 0..2 ] of WideChar;
  iSize, i          : Integer;
begin
  Result            := False;
  Ch                := #0;
  iSize             := UTF8CharSize( P[ Index ] );
  if ( iSize < 2 ) or ( iSize > 4 ) then
    Exit;
  for i := 1 to iSize - 1 do
    if ( Byte( P[ Index + i ] ) and $C0 ) <> $80 then
      Exit;

  FillChar( C, SizeOf( C ), 0 );
  if Utf8ToUnicode( @C, Length( C ), @P[ Index ], iSize ) <= 0 then
    Exit;
  Ch                := C[ 0 ];
  Result            := True;
end;

function IsUtf8Letter( P: PUTF8Char; Index: Integer ): Boolean;
var
  Ch                : WideChar;
begin
  Result            := DecodeUtf8Char( P, Index, Ch ) and Ch.IsLetter;
end;

function IsUtf8LetterOrDigit( P: PUTF8Char; Index: Integer ): Boolean;
var
  Ch                : WideChar;
begin
  Result            := DecodeUtf8Char( P, Index, Ch ) and Ch.IsLetterOrDigit;
end;
{$ENDIF UNICODE}

/// <summary>Returns True when only blanks (space, tab) follow P up to a line break.</summary>
/// <param name="P">The first character after the candidate multi-line string opener.</param>
/// <returns>True when the line ends (CR or LF) after nothing but blanks; False at the end of the text.</returns>
function IsBlankToLineEnd( P: PUTF8Char ): Boolean;
begin
  while P[ 0 ] in [ #9, ' ' ] do
    Inc( P );
  Result            := P[ 0 ] in [ #10, #13 ];
end;

/// <summary>
/// Returns True when Data is valid UTF-8 (a BOM-less file is then read as UTF-8, not ANSI).  A
/// multi-byte sequence cut short by the end of Data (a read limit or block boundary) is tolerated.
/// </summary>
/// <param name="Data">The file bytes after any BOM.</param>
/// <returns>True when Data decodes as UTF-8 without an invalid sequence.</returns>
function IsValidUtf8( const Data: TBytes ): Boolean;
var
  Len, Lead, Need   : Integer;
begin
  Len               := Length( Data );

  // drop an incomplete final sequence: find its lead byte among the last three bytes
  Lead              := Len - 1;
  while ( Lead >= 0 ) and ( Lead >= Len - 3 ) and ( ( Data[ Lead ] and $C0 ) = $80 ) do
    Dec( Lead );
  if ( Lead >= 0 ) and ( Data[ Lead ] >= $C0 ) then
  begin
    if Data[ Lead ] >= $F0 then
      Need          := 4
    else if Data[ Lead ] >= $E0 then
      Need          := 3
    else
      Need          := 2;
    if Len - Lead < Need then
      Len           := Lead;
  end;

  Result            := ( Len = 0 ) or
    ( MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, PAnsiChar( @Data[ 0 ] ), Len, nil, 0 ) > 0 );
end;

{ TTextFileReader }

constructor TTextFileReader.Create( const AFileName: string; ABufferSize: Integer );
begin
  Create( TFileStream.Create( AFileName, fmOpenRead or fmShareDenyWrite ), ABufferSize, True );
end;

constructor TTextFileReader.Create( AStream: TStream; ABufferSize: Integer; AOwnStream: Boolean );
begin
  inherited Create;
  FOwnStream        := AOwnStream;
  FStream           := AStream;

  if ABufferSize < 16 then
    ABufferSize     := 16;
  SetLength( FBuffer, ABufferSize );

  ReadBOM;

  { Adjust buffer size to match the char size }
  case BOMType of
    bomUcs2BE, bomUcs2LE:
      if ABufferSize mod 2 <> 0 then
        SetLength( FBuffer, ABufferSize + 1 );
    bomUcs4BE, bomUcs4LE:
      if ABufferSize mod 4 <> 0 then
        SetLength( FBuffer, ABufferSize + ( 4 - ( ABufferSize mod 4 ) ) );
  end;
end;

destructor TTextFileReader.Destroy;
begin
  if FOwnStream then
    FStream.Free;
  inherited Destroy;
end;

procedure TTextFileReader.FillBuffer;
var
  BufSize           : Integer;
begin
  if FBufStart >= FBufCount then
  begin
    FBufStart       := 0;
    BufSize         := Length( FBuffer );
    if FMaxReadBytes > 0 then
    begin
      if FBytesRead + Cardinal( BufSize ) > FMaxReadBytes then
        BufSize     := FMaxReadBytes - FBytesRead;
      if BufSize <= 0 then
      begin
        FBufCount   := 0;
        Exit;
      end;
    end;
    FBufCount       := FStream.Read( FBuffer[ 0 ], BufSize );
    Inc( FBytesRead, FBufCount );
  end;
end;

function TTextFileReader.GetEof: Boolean;
begin
  Result            := FBufCount = 0;
end;

function TTextFileReader.DataToString( const Data: TBytes ): string;

  procedure SwapBytes( Data: TBytes );
  var
    I               : Integer;
    b               : Byte;
  begin
    for I := 0 to Length( Data ) div 2 - 1 do
    begin
      b             := Data[ I * 2 ];
      Data[ I * 2 ] := Data[ I * 2 + 1 ];
      Data[ I * 2 + 1 ] := b;
    end;
  end;

var
  A                 : AnsiString;
  W                 : UnicodeString;
  UCS4              : UCS4String;
begin
  Result            := '';
  if Data = nil then
    Exit;
  case BOMType of
    bomAnsi:
      begin
        SetString( A, PAnsiChar( @Data[ 0 ] ), Length( Data ) );
        // No BOM: Delphi source is UTF-8 in practice, so valid UTF-8 is read as UTF-8; only text
        // that is not valid UTF-8 falls back to the ANSI code page.
        if AnsiDataIsUtf8( Data ) then
          Result    := UTF8ToString( A )
        else
          Result    := string( A );
      end;
    bomUtf8:
      begin
        SetString( A, PAnsiChar( @Data[ 0 ] ), Length( Data ) );
        Result      := UTF8ToString( A ); // Utf8ToAnsi would drop every character outside the ANSI code page
      end;
    bomUcs2BE:
      begin
        SwapBytes( Data );
        // the length is in characters: two bytes each (it used to pass the byte count and read
        // twice the data's length)
        SetString( W, PWideChar( @Data[ 0 ] ), Length( Data ) div SizeOf( WideChar ) );
        Result      := W;
      end;
    bomUcs2LE:
      begin
        SetString( W, PWideChar( @Data[ 0 ] ), Length( Data ) div SizeOf( WideChar ) );
        Result      := W;
      end;
    bomUcs4BE, bomUcs4LE:
      begin
        if BOMType = bomUcs4BE then
          SwapBytes( Data );
        // UCS4String carries a terminating #0 element; copy the data INTO it (the arguments used to
        // be reversed, which overwrote the file data with zeros)
        SetLength( UCS4, Length( Data ) div SizeOf( UCS4Char ) + 1 );
        Move( Data[ 0 ], UCS4[ 0 ], ( Length( UCS4 ) - 1 ) * SizeOf( UCS4Char ) );
        UCS4[ High( UCS4 ) ] := 0;
        Result      := UCS4StringToWideString( UCS4 );
      end;
  end;
end;

function TTextFileReader.AnsiDataIsUtf8( const Data: TBytes ): Boolean;
begin
  if FBomlessEncoding = 0 then
  begin
    if IsValidUtf8( Data ) then
      FBomlessEncoding := 1
    else
      FBomlessEncoding := 2;
  end;
  Result            := FBomlessEncoding = 1;
end;

function TTextFileReader.DataToUtf8String( const Data: TBytes ): UTF8String;
begin
  if Data = nil then
    Exit;
  if ( BOMType = bomUtf8 ) or ( ( BOMType = bomAnsi ) and AnsiDataIsUtf8( Data ) ) then
    SetString( Result, PAnsiChar( @Data[ 0 ] ), Length( Data ) )
  else
    Result          := UTF8Encode( DataToString( Data ) );
end;

function TTextFileReader.InternReadAll: TBytes;
var
  Len               : Integer;
begin
  SetLength( Result, FStream.Size - ( FStream.Position - FBufCount ) );
  FillBuffer;
  Len               := 0;
  while FBufCount > 0 do
  begin
    Move( FBuffer[ FBufStart ], Result[ Len ], FBufCount );
    Inc( Len, FBufCount );
    FBufStart       := FBufCount;
    FillBuffer;
  end;
  if Len <> Length( Result ) then
    SetLength( Result, Len );
end;

function TTextFileReader.InternReadLine: TBytes;
var
  Start             : Integer;
  Len, AddLen       : Integer;

  procedure AppendData;
  begin
    AddLen          := ( FBufStart - Start );
    SetLength( Result, Len + AddLen );
    Move( FBuffer[ Start ], Result[ Len ], AddLen );
    Inc( Len, AddLen );
  end;

begin
  FillBuffer;
  if FBufCount = 0 then
  begin
    Result          := nil;
    Exit;
  end;

  Len               := 0;
  Start             := FBufStart;

  if BOMType in [ bomAnsi, bomUtf8 ] then
  begin
    while FBufCount > 0 do
    begin
      if FBuffer[ FBufStart ] in [ 10, 13 ] then
      begin
        AppendData;

        { Skip line break }
        if FBuffer[ FBufStart ] = 13 then // => leading byte of #13#10
        begin
          Inc( FBufStart );
          if FBufStart >= FBufCount then
            FillBuffer;
        end;
        if FBuffer[ FBufStart ] = 10 then
        begin
          Inc( FBufStart );
          if FBufStart >= FBufCount then
            FillBuffer;
        end;

        Break;
      end;
      Inc( FBufStart );
      if FBufStart >= FBufCount then
      begin
        AppendData;
        FillBuffer;
        Start       := FBufStart;
      end;
    end;
  end
  else
    raise Exception.Create( 'Only ANSI and UTF8 encodings are supported' );
end;

function TTextFileReader.ReadAll: string;
begin
  Result            := DataToString( InternReadAll );
end;

function TTextFileReader.ReadLine: string;
begin
  Result            := DataToString( InternReadLine );
end;

function TTextFileReader.Utf8ReadAll: UTF8String;
begin
  Result            := DataToUtf8String( InternReadAll );
end;

function TTextFileReader.Utf8ReadLine: UTF8String;
begin
  Result            := DataToUtf8String( InternReadLine );
end;

procedure TTextFileReader.ReadBOM;
begin
  Assert( Length( FBuffer ) >= 4 );

  FBOMType          := bomAnsi;
  FBufCount         := FStream.Read( FBuffer[ 0 ], Length( FBuffer ) );
  if FBufCount >= 2 then
  begin
    if ( FBuffer[ 0 ] = $EF ) and ( FBuffer[ 1 ] = $BB ) then
    begin
      if FBuffer[ 2 ] = $BF then
      begin
        FBOMType    := bomUtf8;
        FBufStart   := 3;
      end;
    end
    else if ( FBuffer[ 0 ] = $FF ) and ( FBuffer[ 1 ] = $FE ) then
    begin
      if ( FBuffer[ 2 ] = 0 ) and ( FBuffer[ 3 ] = 0 ) then
      begin
        FBOMType    := bomUcs4LE;
        FBufStart   := 4;
      end
      else
      begin
        FBOMType    := bomUcs2LE;
        FBufStart   := 2;
      end;
    end
    else if ( FBuffer[ 0 ] = $FE ) and ( FBuffer[ 1 ] = $FF ) then
    begin
      FBOMType      := bomUcs2BE;
      FBufStart     := 2;
    end
    else if ( FBuffer[ 0 ] = 0 ) and ( FBuffer[ 1 ] = 0 ) then
    begin
      if ( FBuffer[ 2 ] = $FE ) and ( FBuffer[ 3 ] = $FF ) then
      begin
        FBOMType    := bomUcs4BE;
        FBufStart   := 4;
      end;
    end;
  end;

  Dec( FBufCount, FBufStart );
end;

{ TToken }

constructor TToken.Create( ATokenIndex: Integer; AKind: TTokenKind;
  const AValue, AFilename: string; ALine, AColumn, AIndex, ATokenLength: Integer );
begin
  inherited Create;
  FTokenIndex       := ATokenIndex;
  FKind             := AKind;
  FValue            := AValue;
  FLine             := ALine;
  FColumn           := AColumn;
  FIndex            := AIndex;
  FTokenLength      := ATokenLength;
  FFilename         := AFilename;
end;

{procedure TToken.FreeInstance;
begin
  inherited FreeInstance;
  //CleanupInstance;
end;

class function TToken.NewInstance: TObject;
begin
  Result := inherited NewInstance;
end;}

function TToken.IsIdent: Boolean;
begin
  Result            := Kind >= tkIdent;
end;

function TToken.IsTypeIdent: Boolean;
begin
  Result            := ( Kind >= tkIdent ) and ( ( Kind < tkIdentStrictReserved ) or ( Kind = tkI_string ) );
end;

function TToken.GetCommentBody: string;
begin
  if Kind = tkComment then
  begin
    if Value[ 1 ] = '{' then
      Result        := Copy( Value, 2, Length( Value ) - 2 )
    else if Value[ 1 ] = '(' then
      Result        := Copy( Value, 3, Length( Value ) - 4 )
    else if Value[ 1 ] = '/' then
      Result        := Copy( Value, 3, MaxInt )
    else
      Result        := '';
  end
  else
    Result          := '';
end;

function TToken.GetEndIndex: Integer;
begin
  Result            := Index + TokenLength - 1;
end;

function TToken.IsFreeUsableIdent: Boolean;
begin
  Result            := ( Kind >= tkIdent ) and ( Kind < tkIdentStrictReserved );
end;

procedure TToken.OffsetToken( OffsetTokenIndex, OffsetIndex, OffsetColumn, OffsetLine: Integer );
begin
  Inc( FTokenIndex, OffsetTokenIndex );
  Inc( FColumn, OffsetColumn );
  Inc( FLine, OffsetLine );
  Inc( FIndex, OffsetIndex );
end;

{ TDelphiLexer }

constructor TDelphiLexer.Create( const AFilename: string; const AText: UTF8String;
  AOwnsTokens: Boolean; AStartLine: Integer; AStartColumn: Integer );
begin
  inherited Create;
  FTokens           := TObjectList.Create( AOwnsTokens );
  FFilename         := AFilename;
  FText             := AText;
  FStartLine        := AStartLine;
  FLine             := AStartLine;
  FIndex            := 1;
  if AStartColumn < 1 then
    AStartColumn    := 1;
  FStartColumn      := AStartColumn;
  FColumn           := AStartColumn;
end;

destructor TDelphiLexer.Destroy;
begin
  FTokens.Free;
  inherited Destroy;
end;

function TDelphiLexer.GetTokenProp( Index: Integer ): TToken;
begin
  Result            := TToken( FTokens[ Index ] );
end;

function TDelphiLexer.GetCount: Integer;
begin
  Result            := FTokens.Count;
end;

function TDelphiLexer.GetToken( out Token: TToken ): Boolean;
begin
  Token             := GetToken;
  Result            := Token <> nil;
end;

function TDelphiLexer.CountSpaces( StartIndex: Integer ): Integer;
var
  Len               : Integer;
begin
  Len               := Length( FText );
  Result            := 0;
  while ( StartIndex <= Len ) and ( FText[ StartIndex ] in [ #9, ' ' ] ) do
  begin
    Inc( Result );
    Inc( StartIndex );
  end;
end;

procedure TDelphiLexer.DeleteToken( Token: TToken; DeleteEndSpaces: Boolean );
var
  TokenIndex, Len   : Integer;
  I                 : Integer;
  Tk                : TToken;
  Line              : Integer;
begin
  if Token <> nil then
  begin
    { There is no line break change by deleting one token }
    Len             := Token.TokenLength;
    if DeleteEndSpaces then
      Inc( Len, CountSpaces( Token.Index + Len ) );
    System.Delete( FText, Token.Index, Len );
    TokenIndex      := Token.TokenIndex;
    Line            := Token.Line;
    for I := TokenIndex + 1 to FTokens.Count - 1 do
    begin
      Tk            := TToken( FTokens[ I ] );
      if Tk.Line = Line then
        Tk.OffsetToken( -1, -Len, 0, 0 )
      else
        Tk.OffsetToken( -1, -Len, -Len, 0 );
    end;
    FTokens.Delete( TokenIndex );
    if FCurTokenIndex > 0 then
      Dec( FCurTokenIndex );
    FModified       := True;
  end;
end;

procedure TDelphiLexer.DeleteTokens( StartToken, EndToken: TToken; DeleteEndSpaces: Boolean );
var
  I                 : Integer;
  StartIndex, EndIndex: Integer;
  StartTokenIndex, EndTokenIndex: Integer;
  OffsetLine, Len   : Integer;
  TokenDeleteCount  : Integer;
  Tk                : TToken;
  LineStartIndex    : Integer;
begin
  if ( StartToken <> nil ) or ( EndToken <> nil ) then
  begin
    if StartToken = nil then
      DeleteToken( EndToken, DeleteEndSpaces )
    else if EndToken = nil then
      DeleteToken( StartToken, DeleteEndSpaces )
    else
    begin
      StartIndex    := StartToken.Index;
      EndIndex      := EndToken.Index + EndToken.TokenLength;
      if DeleteEndSpaces then
        Inc( EndIndex, CountSpaces( EndIndex ) );

      Delete( FText, StartIndex, EndIndex - StartIndex );
      StartTokenIndex := StartToken.TokenIndex;
      EndTokenIndex := EndToken.TokenIndex;
      TokenDeleteCount := EndTokenIndex - StartTokenIndex + 1;
      Len           := EndIndex - StartIndex;

      LineStartIndex := FindLineStart( FText, EndToken.Index - 1 );
      if LineStartIndex < StartIndex then
        LineStartIndex := StartIndex;

      OffsetLine    := EndToken.Line - StartToken.Line;
      Dec( FLine, OffsetLine );
      for I := EndTokenIndex + 1 to FTokens.Count - 1 do
      begin
        Tk          := TToken( FTokens[ I ] );
        if Tk.Line = Line then
          Tk.OffsetToken( -TokenDeleteCount, -Len, -( EndIndex - LineStartIndex ), -OffsetLine )
        else
          Tk.OffsetToken( -TokenDeleteCount, -Len, 0, -OffsetLine );
      end;
      for I := EndTokenIndex downto StartTokenIndex do
        FTokens.Delete( I );

      if FCurTokenIndex >= TokenDeleteCount then
        Dec( FCurTokenIndex, TokenDeleteCount );
      FModified     := True;
    end;
  end;
end;

procedure TDelphiLexer.InsertTextAfter( Token: TToken; const Text: UTF8String );
begin
  InsertText( Token.EndIndex + 1, Text );
end;

procedure TDelphiLexer.InsertTextAfter( Token: TToken; const Text: string );
begin
  InsertText( Token.EndIndex + 1, Text );
end;

procedure TDelphiLexer.ReplaceToken( Token: TToken; const Text: UTF8String );
var
  Index             : Integer;
begin
  Index             := Token.Index;
  DeleteToken( Token );
  InsertText( Index, Text );
end;

procedure TDelphiLexer.ReplaceToken( Token: TToken; const Text: string );
begin
  ReplaceToken( Token, UTF8Encode( Text ) );
end;

procedure TDelphiLexer.DiscardTokens( StartIndex: Integer );
var
  I                 : Integer;
  Tk                : TToken;
begin
  if FTokens.Count > 0 then
  begin
    Tk              := TToken( FTokens[ 0 ] );
    if StartIndex <= Tk.Index then
    begin
      FIndex        := 1;
      FLine         := FStartLine;
      FColumn       := FStartColumn;
      FCurTokenIndex := 0;
      FTokens.Clear;
    end
    else
    begin
      for I := FTokens.Count - 1 downto 0 do
      begin
        Tk          := TToken( FTokens[ I ] );
        if Tk.Index >= StartIndex then
          FTokens.Delete( I )
        else
        begin
          if Tk.Index + Tk.TokenLength > StartIndex then
          begin
            FIndex  := Tk.Index;
            FLine   := Tk.Line;
            FColumn := Tk.Column;
            FTokens.Delete( I );
          end
          else
          begin
            FIndex  := Tk.Index + Tk.TokenLength;
            FColumn := Tk.Column + Tk.TokenLength;
            FLine   := Tk.Line;
          end;
          if FCurTokenIndex > FTokens.Count then
            FCurTokenIndex := FTokens.Count;
          Break;
        end;
      end;
    end;
    FModified       := True;
  end;
end;

procedure TDelphiLexer.DeleteText( StartIndex, Len: Integer );
begin
  if Len > 0 then
  begin
    Delete( FText, StartIndex, Len );
    DiscardTokens( StartIndex );
    FModified       := True;
  end;
end;

procedure TDelphiLexer.InsertText( StartIndex: Integer; const Text: UTF8String );
begin
  if Text <> '' then
  begin
    Insert( Text, FText, StartIndex );
    DiscardTokens( StartIndex );
    FModified       := True;
  end;
end;

procedure TDelphiLexer.InsertText( StartIndex: Integer; const Text: string );
begin
  InsertText( StartIndex, UTF8Encode( Text ) );
end;

procedure TDelphiLexer.ReplaceText( StartIndex, Len: Integer; const Text: UTF8String );
begin
  if ( Len > 0 ) and ( Text = '' ) then
    DeleteText( StartIndex, Len )
  else if ( Len = 0 ) and ( Text <> '' ) then
    InsertText( StartIndex, Text )
  else
  begin
    Delete( FText, StartIndex, Len );
    Insert( Text, FText, StartIndex );

    DiscardTokens( StartIndex );
    FModified       := True;
  end;
end;

procedure TDelphiLexer.ReplaceText( StartIndex, Len: Integer; const Text: string );
begin
  ReplaceText( StartIndex, Len, UTF8Encode( Text ) );
end;

procedure TDelphiLexer.RestartLexer;
begin
  FCurTokenIndex    := 0;
end;

procedure TDelphiLexer.RewindLastToken;
begin
  if FCurTokenIndex > 0 then
    Dec( FCurTokenIndex );
end;

function TDelphiLexer.LookAhead: TToken;
var
  Idx               : Integer;
begin
  Idx               := FCurTokenIndex;
  Result            := NextToken;
  FCurTokenIndex    := Idx;
end;

function TDelphiLexer.LookAheadNoComment: TToken;
var
  Idx               : Integer;
begin
  Idx               := FCurTokenIndex;
  Result            := NextTokenNoComment;
  FCurTokenIndex    := Idx;
end;

function TDelphiLexer.NextToken: TToken;
begin
  Result            := nil;
  while FTokens.Count <= FCurTokenIndex do
  begin
    Result          := GetToken;
    if Result = nil then
      Break;
  end;
  if FCurTokenIndex < FTokens.Count then
  begin
    Result          := TToken( FTokens[ FCurTokenIndex ] );
    Inc( FCurTokenIndex );
  end;
end;

function TDelphiLexer.NextToken( out Token: TToken ): Boolean;
begin
  Token             := NextToken;
  Result            := Token <> nil;
end;

function TDelphiLexer.NextTokenNoComment: TToken;
begin
  repeat
    Result          := NextToken;
    if ( Result <> nil ) and ( Result.Kind = tkDirective ) then
    begin
      // AsciiStartsText takes the prefix first, and a directive's text starts with "{$" / "(*$"
      // (the test used to pass the token first and omit the "$", so it never matched).
      if AsciiStartsText( '{$INCLUDE ', Result.Value ) or
        AsciiStartsText( '{$I ', Result.Value ) or
        AsciiStartsText( '(*$INCLUDE ', Result.Value ) or
        AsciiStartsText( '(*$I ', Result.Value ) then
        Break;
    end;
  until ( Result = nil ) or not ( Result.Kind in [ tkComment, tkDirective ] );
end;

function TDelphiLexer.NextTokenNoComment( out Token: TToken ): Boolean;
begin
  Token             := NextTokenNoComment;
  Result            := Token <> nil;
end;

function TDelphiLexer.ParseIdentifierName: string;
var
  Token             : TToken;
begin
  Result            := '';
  Token             := CurrentToken;
  if Token <> nil then
  begin
    repeat
      while ( Token <> nil ) and ( Token.Kind in [ tkComment, tkDirective ] ) do
        Token       := NextToken;
      if not Token.IsTypeIdent then
        Exit;
      Result        := Result + Token.Value;
      Token         := NextToken;
      while ( Token <> nil ) and ( Token.Kind in [ tkComment, tkDirective ] ) do
        Token       := NextToken;

      if Token.Kind <> tkQualifier then
        Break;
      Result        := Result + '.';
    until not NextTokenNoComment( Token );
  end;
  // leave: token after last identifier part
end;

function TDelphiLexer.ParseIfdefToken: TToken;
begin
  FPreprocMode      := True;
  try
    Result          := GetToken;
  finally
    FPreprocMode    := False;
  end;
end;

function TDelphiLexer.PreTokenOf( Token: TToken ): TToken;
begin
  Result            := nil;
  if Token.TokenIndex > 0 then
    Result          := Tokens[ Token.TokenIndex - 1 ];
end;

function TDelphiLexer.PreTokenNoCommentOf( Token: TToken ): TToken;
begin
  Result            := Token;
  while Result.TokenIndex > 0 do
  begin
    Result          := Tokens[ Result.TokenIndex - 1 ];
    if Result.Kind <> tkComment then
      Exit;
  end;
  Result            := nil;
end;

function TDelphiLexer.NextTokenOf( Token: TToken ): TToken;
begin
  Result            := nil;
  if Token.TokenIndex + 1 < Count then
    Result          := Tokens[ Token.TokenIndex + 1 ];
end;

function TDelphiLexer.NextTokenNoCommentOf( Token: TToken ): TToken;
begin
  Result            := Token;
  while Result.TokenIndex + 1 < Count do
  begin
    Result          := Tokens[ Result.TokenIndex + 1 ];
    if Result.Kind <> tkComment then
      Exit;
  end;
  Result            := nil;
end;

function TDelphiLexer.GetCurrentToken: TToken;
begin
  if FCurTokenIndex - 1 < FTokens.Count then
    Result          := TToken( FTokens[ FCurTokenIndex - 1 ] )
  else
    Result          := nil;
end;

function TDelphiLexer.GetFullStringNext: string;
var
  Token             : TToken;
  S                 : string;
begin
  Token             := CurrentToken;
  if ( Token <> nil ) and ( Token.Kind = tkString ) then
  begin
    if GetCombinedStringConstantNext( Result ) > 0 then
      RewindLastToken;

    while NextTokenNoComment( Token ) and ( Token.Kind = tkPlus ) do
    begin
      Result        := Result + ' + ';
      if NextTokenNoComment( Token ) and ( ( Token.Kind = tkString ) or Token.IsIdent ) then
      begin
        if Token.Kind = tkString then
        begin
          if GetCombinedStringConstantNext( S ) > 0 then
            RewindLastToken;
          Result    := Result + S;
        end
        else
          Result    := Result + Token.Value;
      end
      else
        Break;
    end;
  end;
end;

function TDelphiLexer.GetCombinedStringConstantNext( var CombinedString: string ): Integer;
var
  Token             : TToken;
  LastEndIndex      : Integer;
begin
  Result            := 0;
  Token             := CurrentToken;
  if ( Token <> nil ) and ( Token.Kind = tkString ) then
  begin
    CombinedString  := Token.Value;
    Result          := 1;

    { Handle "'a'#13#10" but not "#13 #10"}
    LastEndIndex    := Token.EndIndex;
    while True do
    begin
      Token := NextToken;
      if ( Token = nil ) or ( Token.Kind <> tkString ) or ( Token.Value[ 1 ] <> '#' ) or
        ( Token.Index <> LastEndIndex + 1 ) then
      begin
        Break;
      end;
      Inc( Result );
      CombinedString := CombinedString + Token.Value;
      LastEndIndex  := Token.EndIndex;
    end;
  end;
end;

function TDelphiLexer.GetPreviousToken: TToken;
begin
  if ( FCurTokenIndex > 0 ) and ( FCurTokenIndex - 1 - 1 < FTokens.Count ) then
    Result          := TToken( FTokens[ FCurTokenIndex - 1 - 1 ] )
  else
    Result          := nil;
end;

function TDelphiLexer.GetToken: TToken;
var
  Data, P, F        : PUTF8Char;
  ch1, ch2          : UTF8Char;
  S                 : UTF8String;
  TokenValue        : string;

  CharSize          : Integer;
  IndexAdd          : Integer;
  IsDecimal         : Boolean;
  IsExp             : Boolean;
  IsExpSign         : Boolean;
  StartLine, StartColumn, Line, Column: Integer;
  Kind              : TTokenKind;
  StartIndex        : Integer;
  IsEscapedIdent    : Boolean;
  QuoteRun, ClosingRun: Integer;
  ClosingFound      : Boolean;
begin
  Result            := nil;
  if FIndex > Length( FText ) then
    Exit;
  Data              := Pointer( Text );
  P                 := Data + FIndex - 1;

  // skip white chars
  Column            := FColumn;
  Line              := FLine;
  ch1               := P[ 0 ];
  while ch1 in WhiteChars do
  begin
    if ch1 = #10 then
    begin
      Inc( Line );
      Column        := 0;
    end;
    Inc( P );
    ch1             := P[ 0 ];
    if ch1 <> #13 then
      Inc( Column );
  end;

  if ch1 = #0 then
  begin
    FLine           := Line;
    FColumn         := Column;
    Exit;
  end;

  StartLine         := Line;
  StartColumn       := Column;
  StartIndex        := P - Data + 1;

  F                 := P;
  IndexAdd          := 0;
  IsEscapedIdent    := False;
  QuoteRun          := 0;
  while P[ QuoteRun ] = '''' do
    Inc( QuoteRun );

  if ( QuoteRun >= 3 ) and Odd( QuoteRun ) and IsBlankToLineEnd( P + QuoteRun ) then
  begin
    // Delphi 12 multi-line string: an odd run of three or more quotes ends the line; the string
    // runs to the first later line that holds, after leading blanks, the same run of quotes.
    // Its lines are text, never code.
    Inc( P, QuoteRun );
    Inc( Column, QuoteRun );
    ClosingFound    := False;
    while not ClosingFound and ( P[ 0 ] <> #0 ) do
    begin
      // to the start of the next line
      while not ( P[ 0 ] in [ #0, #10, #13 ] ) do
      begin
        Inc( P );
        Inc( Column );
      end;
      if P[ 0 ] = #0 then
        Break; // unterminated at the end of the text
      if P[ 0 ] = #13 then
        Inc( P );
      if P[ 0 ] = #10 then
        Inc( P );
      Inc( Line );
      Column        := 1;

      // a closing line: blanks, then the quote run
      while P[ 0 ] in [ #9, ' ' ] do
      begin
        Inc( P );
        Inc( Column );
      end;
      ClosingRun    := 0;
      while P[ ClosingRun ] = '''' do
        Inc( ClosingRun );
      if ClosingRun >= QuoteRun then
      begin
        Inc( P, QuoteRun );
        Inc( Column, QuoteRun );
        ClosingFound := True;
      end;
    end;
    Kind            := tkString;
  end
  else if ch1 = '''' then
  begin
    Inc( P );
    Inc( Column );
    // string
    while True do
    begin
      case P[ 0 ] of
        #0:
          Break;
        '''':
          begin
            if P[ 1 ] = '''' then
              Inc( P )
            else
              Break;
          end;
        #10, #13:
          begin
            Dec( P );
            Column  := 0;
            Break; // line end is string end in pascal
          end;
      end;
      Inc( P );
      Inc( Column );
    end;
    if P[ 0 ] <> #0 then
    begin
      Inc( P ); // include P[0] which is now P[-1]
      Inc( Column );
    end;
    Kind            := tkString;
  end
  else if ch1 = '{' then
  begin
    // comment { ... } -> find comment end
    Inc( P );
    Inc( Column );
    if P[ 0 ] = '$' then
    begin
      Kind          := tkDirective;
      Inc( P );
      Inc( Column );
    end
    else
      Kind          := tkComment;

    while True do
    begin
      case P[ 0 ] of
        #0, '}':
          Break;
        #10:
          begin
            Inc( Line );
            Column  := 0;
          end;
      end;
      Inc( P );
      if P[ 0 ] <> #13 then
        Inc( Column );
    end;

    if P[ 0 ] <> #0 then
    begin
      Inc( P ); // include P[0] which is now P[-1]
      Inc( Column );
    end;
  end
  else if ( ch1 = '(' ) and ( P[ 1 ] = '*' ) then
  begin
    // comment (* ... *) -> find comment end
    Inc( P, 2 );
    Inc( Column, 2 );
    if P[ 0 ] = '$' then
    begin
      Kind          := tkDirective;
      Inc( P );
      Inc( Column );
    end
    else
      Kind          := tkComment;

    ch1             := P[ 0 ];
    while ( ch1 <> #0 ) and not ( ( ch1 = '*' ) and ( P[ 1 ] = ')' ) ) do
    begin
      if ch1 = #10 then
      begin
        Inc( Line );
        Column      := 0;
      end;
      Inc( P );
      ch1           := P[ 0 ];
      if ch1 <> #13 then
        Inc( Column );
    end;

    if ch1 <> #0 then
    begin
      Inc( P, 2 ); // include P[0],P[1] which is now P[-2],P[-1]
      Inc( Column, 2 );
    end;
  end
  else if ( ch1 = '/' ) and ( P[ 1 ] = '/' ) then
  begin
    // comment "// ..." -> find comment end
    Inc( P, 2 );
    Inc( Column, 2 );
    while not ( P[ 0 ] in [ #0, #10, #13 ] ) do
    begin
      Inc( P );
      Inc( Column );
    end;
    Kind            := tkComment;
    if P[ 0 ] <> #0 then
    begin
      if P[ 0 ] = #13 then
        Inc( IndexAdd ); {do not parse the #13 again}
      Inc( Line );
      Inc( IndexAdd ); {do not parse the #10 again}
      Column        := 1;
    end;
  end
  else if ( ch1 in IdentFirstChars ){$IFDEF UNICODE} or ( ( P[ 0 ] >= #128 ) and IsUtf8Letter( P, 0 ) ){$ENDIF}
  or ( FPreprocMode and ( ch1 in IdentChars ) ) then
  begin
    // identifier
    CharSize        := UTF8CharLength( ch1 );
    Inc( P, CharSize );
    Inc( Column, CharSize );

    while ( P[ 0 ] in IdentChars ){$IFDEF UNICODE} or ( ( P[ 0 ] >= #128 ) and IsUtf8LetterOrDigit( P, 0 ) ){$ENDIF} do
    begin
      if Byte( P[ 0 ] ) and $80 > 0 then
      begin
        CharSize    := UTF8CharLength( P[ 0 ] );
        Inc( P, CharSize );
        Inc( Column, CharSize );
      end
      else
      begin
        Inc( P );
        Inc( Column );
      end;
    end;

    Kind            := tkIdent;
  end
  else if ch1 in NumberChars then
  begin
    // number
    Inc( P );
    Inc( Column );

    IsDecimal       := False;
    IsExp           := False;
    IsExpSign       := False;
    repeat
      case P[ 0 ] of
        '0'..'9', '_': ; // '_' is a digit separator (Delphi 11+): 1_000_000

        '.':
          begin
            if P[ 1 ] = '.' then // '..' "range symbol"
              Break;
            if IsDecimal or IsExp then
              Break
            else
              IsDecimal := True;
          end;

        '+', '-':
          if not IsExp or IsExpSign then
            Break
          else
            IsExpSign := True;

        'e', 'E':
          if IsDecimal or IsExp then
            Break
          else
            IsExp   := True;

      else
        Break;
      end;
      Inc( P );
      Inc( Column );
    until False;
    if IsExp or IsDecimal then
      Kind          := tkFloat
    else
      Kind          := tkInt;
  end
  else if ( ch1 = '$' ) and ( P[ 1 ] in HexNumberChars ) then
  begin
    // hex number ('_' digit separators allowed: $FF_FF)
    Inc( P, 2 );
    Inc( Column, 2 );
    while P[ 0 ] in HexNumberChars + [ '_' ] do
    begin
      Inc( P );
      Inc( Column );
    end;
    Kind            := tkInt;
  end
  else if ( ch1 = '%' ) and ( P[ 1 ] in [ '0', '1' ] ) then
  begin
    // binary literal (Delphi 11+): %1010, separators allowed
    Inc( P, 2 );
    Inc( Column, 2 );
    while P[ 0 ] in [ '0', '1', '_' ] do
    begin
      Inc( P );
      Inc( Column );
    end;
    Kind            := tkInt;
  end
  else if ( ch1 = '&' ) and ( ( P[ 1 ] in IdentFirstChars ){$IFDEF UNICODE} or ( ( P[ 1 ] >= #128 ) and IsUtf8Letter( P, 1 ) ){$ENDIF} ) then
  begin
    // &-escaped identifier (&End, &Type): an identifier even when the word is reserved
    Inc( P );
    Inc( Column );
    while ( P[ 0 ] in IdentChars ){$IFDEF UNICODE} or ( ( P[ 0 ] >= #128 ) and IsUtf8LetterOrDigit( P, 0 ) ){$ENDIF} do
    begin
      if Byte( P[ 0 ] ) and $80 > 0 then
      begin
        CharSize    := UTF8CharLength( P[ 0 ] );
        Inc( P, CharSize );
        Inc( Column, CharSize );
      end
      else
      begin
        Inc( P );
        Inc( Column );
      end;
    end;
    Kind            := tkIdent;
    IsEscapedIdent  := True;
  end
  else if SupportMacroTokens and ( ch1 = '$' ) and ( P[ 1 ] = '_' ) and ( P[ 2 ] = '_' ) then // macro support
  begin
    // identifier
    Inc( P, 2 );
    Inc( Column, 2 );
    while P[ 0 ] in IdentChars do
    begin
      Inc( P );
      Inc( Column );
    end;
    SetString( S, F, P - F );
    Kind            := tkMacro;
  end
  else if ( ch1 = '#' ) and ( ( P[ 1 ] = '$' ) or ( P[ 1 ] in NumberChars ) ) then
  begin
    // char
    Inc( P, 2 );
    Inc( Column, 2 );
    if P[ -1 ] = '$' then
    begin
      while P[ 0 ] in HexNumberChars do
      begin
        Inc( P );
        Inc( Column );
      end;
    end
    else
    begin
      while P[ 0 ] in NumberChars do
      begin
        Inc( P );
        Inc( Column );
      end;
    end;
    Kind            := tkString;
  end
  else {if ch1 in SymbolChars then}
  begin
    Inc( P );
    Inc( Column );
    ch2             := P[ 0 ];
    case ch1 of
      ';': Kind     := tkSemicolon;
      ',': Kind     := tkComma;
      '^': Kind     := tkPointer;
      '@': Kind     := tkAddr;
      '&': Kind     := tkAmp;
      '[': Kind     := tkLBracket;
      ']': Kind     := tkRBracket;
      '+': Kind     := tkPlus;
      '-': Kind     := tkMinus;
      '*': Kind     := tkMultiply;
      '/': Kind     := tkDivide;
      '=': Kind     := tkEqual;
      ':': if ch2 = '=' then
          Kind      := tkAssign
        else
          Kind      := tkColon;
      '<': if ch2 = '=' then
          Kind      := tkLessEqualThan
        else if ch2 = '>' then
          Kind      := tkNotEqual
        else
          Kind      := tkLessThan;
      '>': if ch2 = '=' then
          Kind      := tkGreaterEqualThan
        else
          Kind      := tkGreaterThan;
      '.': if ch2 = '.' then
          Kind      := tkRange
        else if ch2 = ')' then
        begin
          Kind      := tkRBracket; // '.)' => ']'
          Inc( P );
          Inc( Column );
        end
        else
          Kind      := tkQualifier;
      '(': if ch2 = '.' then
        begin
          Kind      := tkLBracket; // '(.' => '['
          Inc( P );
          Inc( Column );
        end
        else
          Kind      := tkLParan;
      ')': Kind     := tkRParan;
    else
      Kind          := tkSymbol;
    end;
    if Kind >= tkSymbolLevel2 then
    begin
      Inc( P );
      Inc( Column );
    end;
  end;
  FIndex            := P - Data + 1;
  FLine             := Line;
  FColumn           := Column;

{$IFDEF UNICODE}
  SetStringFromUtf8( TokenValue, F, P - F );
{$ELSE}
  SetString( TokenValue, F, P - F );
{$ENDIF UNICODE}
  if ( Kind = tkIdent ) and not IsEscapedIdent then
    Kind            := FindTokenIdentKind( TokenValue );

  Result            := TToken.Create( FTokens.Count, Kind, TokenValue, FFilename, StartLine, StartColumn, StartIndex, P - F );
  FTokens.Add( Result );

  Inc( FIndex, IndexAdd ); // skip some chars if necessary
end;

initialization
  InitTokenStrings;

finalization
  FreeAndNil( TokenStrings );

end.

