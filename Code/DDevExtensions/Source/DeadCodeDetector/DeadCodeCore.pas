{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit DeadCodeCore;

/// <summary>
/// Pure analysis core of the Dead Code Detector: collects the procedures, functions and class
/// fields declared in a set of units, then scans the same units for references and reports the
/// symbols nothing refers to.
/// </summary>
/// <remarks>
/// RTL and <c>DelphiLexer</c> only - no ToolsAPI, no VCL - so it is unit-testable outside the IDE
/// like the other <c>*Core</c> units.  Detection is heuristic and deliberately errs on the side of
/// "referenced": published, virtual / override / abstract members, constructors, destructors and
/// event-handler-shaped methods are never reported, nor are message handlers and declarations
/// carrying an attribute (used through RTTI, not by name).
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  /// <summary>One reported dead-code finding.</summary>
  TDeadCodeItem = record
    /// <summary>Full path of the file containing the symbol.</summary>
    FileName: string;
    /// <summary>Unit name (without extension).</summary>
    UnitName: string;
    /// <summary>1-based source line of the declaration.</summary>
    Line: Integer;
    /// <summary>Kind of symbol: "Procedure", "Function", "Constructor", "Destructor" or "Field".</summary>
    ElementType: string;
    /// <summary>Name of the symbol (qualified with the class name when applicable).</summary>
    ElementName: string;
    /// <summary>Visibility / placement: "private", "protected", "public", "published", "unit" or "interface".</summary>
    Scope: string;
    /// <summary>Reason for reporting (currently always "Never referenced").</summary>
    Reason: string;
  end;

  /// <summary>
  /// Mutable record describing a single declared symbol gathered during the collection pass
  /// and updated during the reference-scanning pass.
  /// </summary>
  TSymbolInfo = class
  public
    /// <summary>Identifier name as declared in the source.</summary>
    Name: string;
    /// <summary>Full path of the declaring file.</summary>
    FileName: string;
    /// <summary>Unit name (without extension).</summary>
    UnitName: string;
    /// <summary>1-based source line of the declaration.</summary>
    Line: Integer;
    /// <summary>Byte index (1-based, in the UTF-8 text) of the declaring token, so that token alone is not counted as a reference.</summary>
    DeclIndex: Integer;
    /// <summary>Kind of symbol (see <see cref="TDeadCodeItem.ElementType"/>).</summary>
    ElementType: string;
    /// <summary>Visibility / placement (see <see cref="TDeadCodeItem.Scope"/>).</summary>
    Scope: string;
    /// <summary>Set during the reference-scanning pass when at least one reference is found.</summary>
    IsReferenced: Boolean;
    /// <summary>True when the method has the virtual directive.</summary>
    IsVirtual: Boolean;
    /// <summary>True when the method has the override directive.</summary>
    IsOverride: Boolean;
    /// <summary>True when the method has the abstract directive.</summary>
    IsAbstract: Boolean;
    /// <summary>True when the symbol is in a published section (used by RTTI/DFM streaming).</summary>
    IsPublished: Boolean;
    /// <summary>True when the symbol is a constructor.</summary>
    IsConstructor: Boolean;
    /// <summary>True when the symbol is a destructor.</summary>
    IsDestructor: Boolean;
    /// <summary>True when the parameter list resembles a VCL event handler (has Sender: TObject).</summary>
    IsEventHandler: Boolean;
    /// <summary>True for a message handler ("message WM_X") or a dispatch method ("dispid N"): called by number, never by name.</summary>
    IsMessageHandler: Boolean;
    /// <summary>True when the declaration carries an attribute ([Weak], [JSONName(...)], ...): it is used through RTTI.</summary>
    IsAttributed: Boolean;
    /// <summary>For methods and fields, the name of the owning class.</summary>
    ClassName: string;
  end;

  /// <summary>
  /// Two-pass analyser: <see cref="CollectSymbols"/> over every unit, then
  /// <see cref="ScanForReferences"/> over every unit, then <see cref="GetDeadCode"/>.
  /// </summary>
  TDeadCodeAnalyzer = class
  private
    /// <summary>All symbols collected so far (owned).</summary>
    FSymbols: TObjectList<TSymbolInfo>;
    /// <summary>Symbols indexed by upper-cased name, for the reference scan (lists owned, symbols not).</summary>
    FSymbolsByName: TObjectDictionary<string, TList<TSymbolInfo>>;
    /// <summary>User-supplied wildcard ignore patterns.</summary>
    FIgnorePatterns: TStringList;
    /// <summary>Backing field for <see cref="CheckProcedures"/>.</summary>
    FCheckProcedures: Boolean;
    /// <summary>Backing field for <see cref="CheckFields"/>.</summary>
    FCheckFields: Boolean;
    /// <summary>
    /// Name tokens of implementation headers ("procedure TThing.Bar;"), keyed "FILE|index": the
    /// header names the routine it implements, it does not call it, so it is no reference.
    /// </summary>
    FHeaderTokens: TDictionary<string, Boolean>;
    /// <summary>The key of a token in <see cref="FHeaderTokens"/>.</summary>
    /// <param name="FileName">The unit.</param>
    /// <param name="Index">The token's byte index.</param>
    /// <returns>The key.</returns>
    function HeaderKey( const FileName: string; Index: Integer ): string;
    /// <summary>Adds Symbol to the symbol list and the name index.</summary>
    /// <param name="Symbol">The symbol to add; ownership passes to the analyser.</param>
    procedure AddSymbol( Symbol: TSymbolInfo );
    /// <summary>Returns True when the symbol should be excluded from the report (published, polymorphic, ignored pattern, ...).</summary>
    /// <param name="Symbol">The unreferenced symbol being considered.</param>
    /// <returns>True to leave the symbol out of the report.</returns>
    function ShouldIgnore( const Symbol: TSymbolInfo ): Boolean;
    /// <summary>Returns True when the parameter text contains "Sender" and "TObject" - a heuristic for VCL event handlers.</summary>
    /// <param name="Params">The parameter-list text of the routine.</param>
    /// <returns>True when the routine looks like an event handler.</returns>
    function IsEventHandlerSignature( const Params: string ): Boolean;
  public
    /// <summary>Creates a new analyser with empty state; both checks are on.</summary>
    constructor Create;
    /// <summary>Releases all owned resources.</summary>
    destructor Destroy; override;
    /// <summary>Discards all collected symbols.</summary>
    procedure ClearSymbols;
    /// <summary>Discards all ignore patterns.</summary>
    procedure ClearIgnorePatterns;
    /// <summary>Adds an ignore pattern. Patterns may use a leading or trailing '*' wildcard.</summary>
    /// <param name="Pattern">The pattern; blank patterns are ignored.</param>
    procedure AddIgnorePattern( const Pattern: string );
    /// <summary>Lexes one unit and adds every declared procedure, function and qualifying field to the symbol list.</summary>
    /// <param name="FileName">Full path of the unit (used for reporting and same-unit scoping).</param>
    /// <param name="Content">The unit's text as UTF-8 without a BOM.</param>
    procedure CollectSymbols( const FileName: string; const Content: UTF8String );
    /// <summary>Lexes one unit (or a file it includes) and marks every collected symbol it refers to as referenced.</summary>
    /// <param name="FileName">Full path of the unit, as passed to <see cref="CollectSymbols"/>, or of the include file.</param>
    /// <param name="Content">The text as UTF-8 without a BOM.</param>
    /// <param name="IncludedFrom">For an include file, the unit that includes it (its references count as that unit's); empty for a unit.</param>
    procedure ScanForReferences( const FileName: string; const Content: UTF8String; const IncludedFrom: string = '' );
    /// <summary>Returns the unreferenced, non-ignored symbols collected so far.</summary>
    /// <param name="LocalOnly">
    /// True when some unit could not be read: a symbol other units can see might be used there, so
    /// only private and unit-local symbols (judged by their own unit alone) are returned.
    /// </param>
    /// <returns>One item per dead symbol, in collection order.</returns>
    function GetDeadCode( LocalOnly: Boolean = False ): TArray<TDeadCodeItem>;
    /// <summary>Whether procedures, functions and methods are reported.</summary>
    property CheckProcedures: Boolean read FCheckProcedures write FCheckProcedures;
    /// <summary>Whether private and protected class fields are reported.</summary>
    property CheckFields: Boolean read FCheckFields write FCheckFields;
  end;

/// <summary>Returns the file names a unit includes with {$I file} / {$INCLUDE file} (not the {$I+} / {$I-} switches).</summary>
/// <param name="Content">The unit's text as UTF-8 without a BOM.</param>
/// <returns>The names as written, without quotes, in source order.</returns>
function ExtractIncludeFileNames( const Content: UTF8String ): TArray<string>;

implementation

uses
  DelphiLexer;

{ TDeadCodeAnalyzer }

constructor TDeadCodeAnalyzer.Create;
begin
  inherited Create;
  FSymbols          := TObjectList<TSymbolInfo>.Create( True );
  FSymbolsByName    := TObjectDictionary<string, TList<TSymbolInfo>>.Create( [ doOwnsValues ] );
  FIgnorePatterns   := TStringList.Create;
  FIgnorePatterns.CaseSensitive := False;
  FCheckProcedures  := True;
  FCheckFields      := True;
  FHeaderTokens     := TDictionary<string, Boolean>.Create;
end;

destructor TDeadCodeAnalyzer.Destroy;
begin
  FIgnorePatterns.Free;
  FHeaderTokens.Free;
  FSymbolsByName.Free;
  FSymbols.Free;
  inherited Destroy;
end;

procedure TDeadCodeAnalyzer.ClearSymbols;
begin
  FHeaderTokens.Clear;
  FSymbolsByName.Clear;
  FSymbols.Clear;
end;

procedure TDeadCodeAnalyzer.ClearIgnorePatterns;
begin
  FIgnorePatterns.Clear;
end;

procedure TDeadCodeAnalyzer.AddIgnorePattern( const Pattern: string );
begin
  if Trim( Pattern ) <> '' then
    FIgnorePatterns.Add( Trim( Pattern ) );
end;

function TDeadCodeAnalyzer.HeaderKey( const FileName: string; Index: Integer ): string;
begin
  Result            := UpperCase( FileName ) + '|' + IntToStr( Index );
end;

/// <summary>The name an identifier stands for: an &amp;-escaped identifier (&amp;Type) names Type.</summary>
/// <param name="Name">The identifier as written.</param>
/// <returns>The name without a leading &amp;.</returns>
function NameKey( const Name: string ): string;
begin
  if ( Name <> '' ) and ( Name[ 1 ] = '&' ) then
    Result          := Copy( Name, 2, MaxInt )
  else
    Result          := Name;
end;

function ExtractIncludeFileNames( const Content: UTF8String ): TArray<string>;
begin
  Result            := nil;
  var oLexer        := TDelphiLexer.Create( '', Content );
  try
    var oToken: TToken;
    while oLexer.NextToken( oToken ) do
    begin
      if oToken.Kind <> tkDirective then
        Continue;

      // the directive body without its "{$" / "(*$" and closing "}" / "*)"
      var s         := oToken.Value;
      var iStart    := Pos( '$', s ) + 1;
      var iEnd      := Length( s ) - 1;
      if ( iEnd >= 1 ) and ( s[ iEnd ] = '*' ) then
        Dec( iEnd );
      var sBody     := Trim( Copy( s, iStart, iEnd - iStart + 1 ) );

      var sArg      := '';
      if SameText( Copy( sBody, 1, 8 ), 'INCLUDE ' ) then
        sArg        := Trim( Copy( sBody, 9, MaxInt ) )
      else if ( Length( sBody ) > 2 ) and CharInSet( sBody[ 1 ], [ 'I', 'i' ] ) and CharInSet( sBody[ 2 ], [ ' ', #9 ] ) then
        sArg        := Trim( Copy( sBody, 3, MaxInt ) ); // {$I file}; {$I+} / {$I-} have no blank after the I

      if ( sArg = '' ) or CharInSet( sArg[ 1 ], [ '+', '-' ] ) then
        Continue;
      if sArg[ 1 ] = #39 then
        sArg        := AnsiDequotedStr( sArg, #39 ); // a quoted name
      Result        := Result + [ sArg ];
    end;
  finally
    oLexer.Free;
  end;
end;

procedure TDeadCodeAnalyzer.AddSymbol( Symbol: TSymbolInfo );
begin
  FSymbols.Add( Symbol );

  var oList: TList<TSymbolInfo>;
  if not FSymbolsByName.TryGetValue( UpperCase( NameKey( Symbol.Name ) ), oList ) then
  begin
    oList           := TList<TSymbolInfo>.Create;
    FSymbolsByName.Add( UpperCase( NameKey( Symbol.Name ) ), oList );
  end;
  oList.Add( Symbol );
end;

function TDeadCodeAnalyzer.IsEventHandlerSignature( const Params: string ): Boolean;
begin
  Result            := ( Pos( 'SENDER', UpperCase( Params ) ) > 0 ) and
    ( Pos( 'TOBJECT', UpperCase( Params ) ) > 0 );
end;

function TDeadCodeAnalyzer.ShouldIgnore( const Symbol: TSymbolInfo ): Boolean;
begin
  // Published members are used by RTTI
  if Symbol.IsPublished then
    Exit( True );

  // Virtual/override/abstract methods may be called polymorphically
  if Symbol.IsVirtual or Symbol.IsOverride or Symbol.IsAbstract then
    Exit( True );

  // Constructors and destructors are special
  if Symbol.IsConstructor or Symbol.IsDestructor then
    Exit( True );

  // Event handlers are typically assigned at design time
  if Symbol.IsEventHandler then
    Exit( True );

  // Called by message number / dispatch id, or used through RTTI: never named in code
  if Symbol.IsMessageHandler or Symbol.IsAttributed then
    Exit( True );

  // User-defined ignore patterns: '*suffix', 'prefix*' or an exact name
  for var sPattern in FIgnorePatterns do
  begin
    if sPattern[ 1 ] = '*' then
    begin
      if SameText( Copy( Symbol.Name, Length( Symbol.Name ) - Length( sPattern ) + 2, MaxInt ),
        Copy( sPattern, 2, MaxInt ) ) then
        Exit( True );
    end
    else if sPattern[ Length( sPattern ) ] = '*' then
    begin
      if SameText( Copy( Symbol.Name, 1, Length( sPattern ) - 1 ), Copy( sPattern, 1, Length( sPattern ) - 1 ) ) then
        Exit( True );
    end
    else if SameText( Symbol.Name, sPattern ) then
      Exit( True );
  end;

  Result            := False;
end;

/// <summary>Reads the next token that is not a comment or a compiler directive.</summary>
/// <param name="Lexer">The lexer to read from.</param>
/// <param name="Token">Receives the token; nil at the end of the text.</param>
/// <returns>True when a token was read.</returns>
function NextCodeToken( Lexer: TDelphiLexer; out Token: TToken ): Boolean;
begin
  repeat
    Result          := Lexer.NextToken( Token );
  until not Result or not ( Token.Kind in [ tkComment, tkDirective ] );
end;

/// <summary>Returns True when Token is a routine directive that may follow a routine header's semicolon.</summary>
/// <param name="Token">The token after the header.</param>
/// <returns>True for virtual, override, overload, stdcall, inline, deprecated, external, ...</returns>
function IsRoutineDirective( Token: TToken ): Boolean;
const
  DirectiveKinds    = [ tkI_virtual, tkI_override, tkI_abstract, tkI_overload, tkI_reintroduce, tkI_dynamic, tkI_static,
    tkI_inline, tkI_assembler, tkI_register, tkI_stdcall, tkI_cdecl, tkI_safecall, tkI_pascal,
    tkI_external, tkI_forward, tkI_message, tkI_final, tkI_platform, tkI_deprecated, tkI_experimental,
    tkI_varargs, tkI_dispid, tkI_export, tkI_local, tkI_far, tkI_near, tkI_unsafe ];
begin
  Result            := ( Token <> nil ) and
    ( ( Token.Kind in DirectiveKinds ) or
    ( ( Token.Kind = tkIdent ) and ( SameText( Token.Value, 'winapi' ) or SameText( Token.Value, 'delayed' ) ) ) );
end;

procedure TDeadCodeAnalyzer.CollectSymbols( const FileName: string; const Content: UTF8String );
var
  Token             : TToken;
  PrevTokenKind     : TTokenKind;
  InImplementation  : Boolean;
  InType, InClass, InRecord: Boolean;
  InPrivate, InProtected, InPublic, InPublished: Boolean;
  CurrentClassName  : string;
begin
  var sUnitName     := ChangeFileExt( ExtractFileName( FileName ), '' );
  InImplementation  := False;
  InType            := False;
  InClass           := False;
  InRecord          := False;
  InPrivate         := False;
  InProtected       := False;
  InPublic          := False;
  InPublished       := False;
  CurrentClassName  := '';

  // Routines declared in this unit's interface: their implementation headers are the bodies, not
  // further symbols (a second, unit-scoped copy could only be "used" from this file).
  var bAttributed   := False; // an attribute ([Weak], [JSONName(...)]) precedes the next declaration
  var oInterfaceRoutines := TStringList.Create;
  var oLexer        := TDelphiLexer.Create( FileName, Content );
  try
    oInterfaceRoutines.CaseSensitive := False;
    oInterfaceRoutines.Sorted := True;
    oInterfaceRoutines.Duplicates := dupIgnore;

    PrevTokenKind   := tkNone;

    while NextCodeToken( oLexer, Token ) do
    begin
      // Track section
      if Token.Kind = tkI_implementation then
      begin
        InImplementation := True;
        InType      := False;
        InClass     := False;
        InRecord    := False;
      end;

      // Track type section
      if Token.Kind = tkI_type then
      begin
        InType      := True;
        InClass     := False;
        InRecord    := False;
      end
      else if Token.Kind in [ tkI_var, tkI_const, tkI_begin ] then
      begin
        if not InClass and not InRecord then
          InType    := False;
      end;

      // Track class/record
      if Token.Kind = tkI_class then
      begin
        if InType and ( PrevTokenKind = tkEqual ) then
        begin
          InClass   := True;
          InRecord  := False;
          // Don't assume private - the implicit section before any visibility
          // keyword is "published" for forms/components (used by DFM streaming).
          // Only collect fields after an explicit private/protected keyword.
          InPrivate := False;
          InProtected := False;
          InPublic  := False;
          InPublished := False;
        end;
      end
      else if Token.Kind = tkI_record then
      begin
        if InType and ( PrevTokenKind = tkEqual ) then
        begin
          InRecord  := True;
          InClass   := False;
        end;
      end
      else if Token.Kind = tkI_end then
      begin
        if InClass or InRecord then
        begin
          InClass   := False;
          InRecord  := False;
          InPrivate := False;
          InProtected := False;
          InPublic  := False;
          InPublished := False;
        end;
      end;

      // Track class name - only when NOT already inside a class
      if InType and not InClass and ( Token.Kind = tkIdent ) and ( PrevTokenKind in [ tkNone, tkSemicolon, tkI_type ] ) then
        CurrentClassName := Token.Value;

      // Track visibility
      if InClass then
      begin
        if Token.Kind = tkI_private then
        begin
          InPrivate := True; InProtected := False; InPublic := False; InPublished := False;
        end
        else if Token.Kind = tkI_protected then
        begin
          InPrivate := False; InProtected := True; InPublic := False; InPublished := False;
        end
        else if Token.Kind = tkI_public then
        begin
          InPrivate := False; InProtected := False; InPublic := True; InPublished := False;
        end
        else if Token.Kind = tkI_published then
        begin
          InPrivate := False; InProtected := False; InPublic := False; InPublished := True;
        end;
      end;

      // A property is not a field: skip the whole declaration (an indexed property's parameter
      // list may hold semicolons inside its brackets).
      if InClass and ( Token.Kind = tkI_property ) then
      begin
        var iDepth  := 0;
        while NextCodeToken( oLexer, Token ) do
        begin
          if Token.Kind in [ tkLBracket, tkLParan ] then
            Inc( iDepth )
          else if Token.Kind in [ tkRBracket, tkRParan ] then
            Dec( iDepth )
          else if ( Token.Kind = tkSemicolon ) and ( iDepth <= 0 ) then
            Break;
        end;
        PrevTokenKind := tkSemicolon;
        Continue;
      end;

      // An attribute in a class body: it marks the declaration that follows as used through RTTI.
      // ("[" starts one only where a declaration may start - not "array[0..3]" in a field's type.)
      if InClass and ( Token.Kind = tkLBracket ) and
        ( PrevTokenKind in [ tkSemicolon, tkRBracket, tkRParan, tkI_class, tkI_private, tkI_protected, tkI_public,
          tkI_published, tkI_strict ] ) then
      begin
        var iBrackets := 1;
        while ( iBrackets > 0 ) and NextCodeToken( oLexer, Token ) do
          if Token.Kind = tkLBracket then
            Inc( iBrackets )
          else if Token.Kind = tkRBracket then
            Dec( iBrackets );
        bAttributed := True;
        PrevTokenKind := tkRBracket;
        Continue;
      end;

      // Collect private/protected fields in classes
      if FCheckFields and InClass and ( InPrivate or InProtected ) and ( Token.Kind = tkIdent ) then
      begin
        var oNameToken := Token;
        var bFieldAttributed := bAttributed;
        bAttributed := False;

        if NextCodeToken( oLexer, Token ) and ( Token.Kind = tkColon ) then
        begin
          var oSymbol := TSymbolInfo.Create;
          oSymbol.Name := oNameToken.Value;
          oSymbol.FileName := FileName;
          oSymbol.UnitName := sUnitName;
          oSymbol.Line := oNameToken.Line + 1;
          oSymbol.DeclIndex := oNameToken.Index;
          oSymbol.ElementType := 'Field';
          oSymbol.ClassName := CurrentClassName;
          oSymbol.IsPublished := InPublished;
          oSymbol.IsAttributed := bFieldAttributed;

          if InPrivate then
            oSymbol.Scope := 'private'
          else
            oSymbol.Scope := 'protected';

          AddSymbol( oSymbol );
        end;

        PrevTokenKind := Token.Kind;
        Continue;
      end;

      // Routine headers.  Always parsed to their end, even when procedures are not checked, so the
      // parameter list is never mistaken for fields.
      if Token.Kind in [ tkI_procedure, tkI_function, tkI_constructor, tkI_destructor ] then
      begin
        var eRoutineKind := Token.Kind;

        if not NextCodeToken( oLexer, Token ) or ( Token.Kind <> tkIdent ) then
        begin
          // "procedure of object" / anonymous method type: no name, nothing to collect
          if Token <> nil then
            PrevTokenKind := Token.Kind;
          Continue;
        end;

        var oNameToken := Token;
        var bIsMethodBody := False;
        var bRoutineAttributed := bAttributed;
        bAttributed := False;

        // In the implementation every name part of the header is a declaration, not a reference.
        if InImplementation then
          FHeaderTokens.AddOrSetValue( HeaderKey( FileName, Token.Index ), True );

        // ClassName.MethodName (or TList<T>.Add): the implementation of a method
        NextCodeToken( oLexer, Token );
        repeat
          if ( Token <> nil ) and ( Token.Kind = tkLessThan ) then
          begin
            // generic parameters: skip to the matching ">"
            var iAngle := 1;
            while ( iAngle > 0 ) and NextCodeToken( oLexer, Token ) do
              if Token.Kind = tkLessThan then
                Inc( iAngle )
              else if Token.Kind = tkGreaterThan then
                Dec( iAngle );
            NextCodeToken( oLexer, Token );
          end;

          if ( Token = nil ) or ( Token.Kind <> tkQualifier ) then
            Break;

          bIsMethodBody := True;
          NextCodeToken( oLexer, Token ); // the next name part
          if ( Token <> nil ) and InImplementation then
            FHeaderTokens.AddOrSetValue( HeaderKey( FileName, Token.Index ), True );
          NextCodeToken( oLexer, Token ); // and what follows it
        until False;

        // Skip the rest of the header: parameters and result type, to the semicolon at depth 0.
        var sParamText := '';
        var iDepth  := 0;
        while Token <> nil do
        begin
          if Token.Kind = tkLParan then
            Inc( iDepth )
          else if Token.Kind = tkRParan then
            Dec( iDepth )
          else if ( Token.Kind = tkSemicolon ) and ( iDepth <= 0 ) then
            Break;

          sParamText := sParamText + Token.Value + ' ';
          NextCodeToken( oLexer, Token );
        end;

        // Directives follow the header's semicolon: "procedure Foo; virtual; abstract;".
        var bVirtual := False;
        var bOverride := False;
        var bAbstract := False;
        var bMessage := False;
        while IsRoutineDirective( oLexer.LookAheadNoComment ) do
        begin
          NextCodeToken( oLexer, Token );
          case Token.Kind of
            tkI_virtual, tkI_dynamic: bVirtual := True;
            tkI_override: bOverride := True;
            tkI_abstract: bAbstract := True;
            tkI_message, tkI_dispid: bMessage := True;
          end;
          // the directive's own arguments ("message WM_X", "external 'a.dll' name 'b'") up to its semicolon
          while ( Token <> nil ) and ( Token.Kind <> tkSemicolon ) do
            NextCodeToken( oLexer, Token );
        end;

        if Token <> nil then
          PrevTokenKind := Token.Kind;

        if bIsMethodBody or not FCheckProcedures then
          Continue;

        // The implementation header of a routine this unit's interface declares is its body.
        if InImplementation and ( oInterfaceRoutines.IndexOf( oNameToken.Value ) >= 0 ) then
          Continue;

        var oSymbol := TSymbolInfo.Create;
        oSymbol.Name := oNameToken.Value;
        oSymbol.FileName := FileName;
        oSymbol.UnitName := sUnitName;
        oSymbol.Line := oNameToken.Line + 1;
        oSymbol.DeclIndex := oNameToken.Index;
        oSymbol.IsPublished := InPublished;
        oSymbol.IsConstructor := eRoutineKind = tkI_constructor;
        oSymbol.IsDestructor := eRoutineKind = tkI_destructor;
        oSymbol.IsVirtual := bVirtual;
        oSymbol.IsOverride := bOverride;
        oSymbol.IsAbstract := bAbstract;
        oSymbol.IsEventHandler := IsEventHandlerSignature( sParamText );
        oSymbol.IsMessageHandler := bMessage;
        oSymbol.IsAttributed := bRoutineAttributed;

        if eRoutineKind = tkI_function then
          oSymbol.ElementType := 'Function'
        else if oSymbol.IsConstructor then
          oSymbol.ElementType := 'Constructor'
        else if oSymbol.IsDestructor then
          oSymbol.ElementType := 'Destructor'
        else
          oSymbol.ElementType := 'Procedure';

        if InImplementation then
          oSymbol.Scope := 'unit'
        else if InClass then
        begin
          if InPrivate then
            oSymbol.Scope := 'private'
          else if InProtected then
            oSymbol.Scope := 'protected'
          else if InPublic then
            oSymbol.Scope := 'public'
          else if InPublished then
            oSymbol.Scope := 'published'
          else
            oSymbol.Scope := 'private';

          oSymbol.ClassName := CurrentClassName;
        end
        else
        begin
          oSymbol.Scope := 'interface';
          oInterfaceRoutines.Add( oSymbol.Name );
        end;

        AddSymbol( oSymbol );
        Continue;
      end;

      if Token.Kind = tkSemicolon then
        bAttributed := False;
      PrevTokenKind := Token.Kind;
    end;
  finally
    oLexer.Free;
    oInterfaceRoutines.Free;
  end;
end;

procedure TDeadCodeAnalyzer.ScanForReferences( const FileName: string; const Content: UTF8String;
  const IncludedFrom: string );
var
  Token             : TToken;
begin
  // An include file's references count as its unit's; it holds no declaration or header token of
  // that unit, so none of its tokens is skipped.
  var bInclude      := IncludedFrom <> '';
  var sScopeFile    := FileName;
  if bInclude then
    sScopeFile      := IncludedFrom;

  // The whole unit is scanned: a field read only by a property in an interface-section class is
  // used, and so is a routine referenced only from an initialization section.
  var oLexer        := TDelphiLexer.Create( FileName, Content );
  try
    while oLexer.NextToken( Token ) do
    begin
      if Token.Kind <> tkIdent then
        Continue;

      var oList: TList<TSymbolInfo>;
      if not FSymbolsByName.TryGetValue( UpperCase( NameKey( Token.Value ) ), oList ) then
        Continue;

      // "procedure TThing.Bar;" names the routine it implements: no reference
      if not bInclude and FHeaderTokens.ContainsKey( HeaderKey( FileName, Token.Index ) ) then
        Continue;

      var bSameFile: Boolean;
      for var oSymbol in oList do
      begin
        if oSymbol.IsReferenced then
          Continue;

        bSameFile   := SameText( oSymbol.FileName, sScopeFile );

        // The declaring token itself is not a reference.
        if bSameFile and not bInclude and ( oSymbol.DeclIndex = Token.Index ) then
          Continue;

        // Unit-scoped routines and private members are visible only in their own unit; protected
        // members are visible to descendants in any unit, so they count anywhere like public ones.
        if ( oSymbol.Scope = 'unit' ) or ( oSymbol.Scope = 'private' ) then
        begin
          if bSameFile then
            oSymbol.IsReferenced := True;
        end
        else
          oSymbol.IsReferenced := True;
      end;
    end;
  finally
    oLexer.Free;
  end;
end;

function TDeadCodeAnalyzer.GetDeadCode( LocalOnly: Boolean ): TArray<TDeadCodeItem>;
begin
  var oList         := TList<TDeadCodeItem>.Create;
  try
    for var oSymbol in FSymbols do
    begin
      if oSymbol.IsReferenced or ShouldIgnore( oSymbol ) then
        Continue;

      // Only symbols no other unit can see are judged when a unit could not be read.
      if LocalOnly and ( oSymbol.Scope <> 'private' ) and ( oSymbol.Scope <> 'unit' ) then
        Continue;

      var rItem: TDeadCodeItem;
      rItem.FileName := oSymbol.FileName;
      rItem.UnitName := oSymbol.UnitName;
      rItem.Line    := oSymbol.Line;
      rItem.ElementType := oSymbol.ElementType;
      rItem.ElementName := oSymbol.Name;
      rItem.Scope   := oSymbol.Scope;
      rItem.Reason  := 'Never referenced';

      if oSymbol.ClassName <> '' then
        rItem.ElementName := oSymbol.ClassName + '.' + oSymbol.Name;

      oList.Add( rItem );
    end;

    Result          := oList.ToArray;
  finally
    oList.Free;
  end;
end;

end.

