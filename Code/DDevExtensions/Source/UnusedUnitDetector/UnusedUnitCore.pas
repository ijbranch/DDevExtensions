{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit UnusedUnitCore;

/// <summary>
/// Pure analysis core of the Unused Unit Detector: decides which entries of a unit's uses clauses
/// nothing in the unit (or its form) refers to.
/// </summary>
/// <remarks>
/// RTL and <c>DelphiLexer</c> only - no ToolsAPI, no VCL - so it is unit-testable outside the IDE.
/// <para>
/// A false "unused" leads the user to delete a uses entry the program needs - silently, when the
/// unit only registers a class, a graphic format or a database driver in its initialization - so
/// every doubt resolves to "used".  A uses entry is reported only when ALL of these hold: its
/// source can be found (through <see cref="TUnitAnalyzer.OnResolveUnit"/>); it has no
/// initialization or finalization section, class constructor or destructor, Register procedure,
/// helper, operator overload or interface-section include file; it is not inside a
/// conditional-compilation block; and not one name its interface declares appears in the using
/// unit's code (outside its uses clauses, comments and strings) or in the unit's form.
/// </para>
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  /// <summary>One reference to a unit appearing in a uses clause.</summary>
  TUsedUnitInfo = record
    /// <summary>Name of the unit being used.</summary>
    UnitName: string;
    /// <summary>True when the reference appears in the interface uses clause.</summary>
    IsInterface: Boolean;
    /// <summary>True when the entry sits inside a conditional-compilation block ($IF / $IFDEF ...).</summary>
    IsConditional: Boolean;
    /// <summary>1-based source line of the unit reference.</summary>
    LineNumber: Integer;
  end;

  /// <summary>A potentially unused uses entry detected by the analyser.</summary>
  TUnusedUnitInfo = record
    /// <summary>Name of the unit containing the suspected unused reference.</summary>
    SourceUnit: string;
    /// <summary>Path of the unit containing the reference.</summary>
    SourceFileName: string;
    /// <summary>Name of the unit that appears to be unused.</summary>
    UnusedUnit: string;
    /// <summary>True when the unused reference is in the interface uses clause.</summary>
    IsInterface: Boolean;
    /// <summary>1-based source line number of the unused reference.</summary>
    LineNumber: Integer;
  end;

  /// <summary>Supplies the source text of a used unit, by unit name.</summary>
  /// <param name="UnitName">The unit name as written in the uses clause.</param>
  /// <param name="Source">Receives the unit's text.</param>
  /// <returns>True when the source was found; False makes the unit "used" (never reported).</returns>
  TResolveUnitSourceFunc = reference to function( const UnitName: string; out Source: string ): Boolean;

  /// <summary>What a used unit offers: the names its interface declares, and whether it must be kept regardless.</summary>
  TUnitExports = class
  public
    /// <summary>True when the unit's source was found.</summary>
    Resolved: Boolean;
    /// <summary>True when the unit must never be reported (side effects, helpers, operators, includes).</summary>
    MustKeep: Boolean;
    /// <summary>Names declared in the unit's interface (case-insensitive, sorted).</summary>
    Names: TStringList;
    /// <summary>Creates an empty, unresolved record.</summary>
    constructor Create;
    /// <summary>Frees the name list.</summary>
    destructor Destroy; override;
  end;

  /// <summary>
  /// Analyser for unused uses entries.  Set <see cref="OnResolveUnit"/>, then call
  /// <see cref="AnalyseSource"/> per unit; resolved units are cached until OnResolveUnit is set again.
  /// </summary>
  TUnitAnalyzer = class
  private
    /// <summary>Unit names never reported.</summary>
    FIgnoreList: TStringList;
    /// <summary>Backing field for <see cref="OnResolveUnit"/>.</summary>
    FOnResolveUnit: TResolveUnitSourceFunc;
    /// <summary>Exports of every unit resolved so far, by upper-case unit name (owned).</summary>
    FExports: TObjectDictionary<string, TUnitExports>;
    /// <summary>Property setter: replaces the resolver and drops the cache built with the old one.</summary>
    /// <param name="Value">The new resolver.</param>
    procedure SetOnResolveUnit( const Value: TResolveUnitSourceFunc );
    /// <summary>Returns (resolving and caching on first use) what UnitName exports.</summary>
    /// <param name="UnitName">The used unit's name.</param>
    /// <returns>The unit's exports record (owned by the cache).</returns>
    function GetUnitExports( const UnitName: string ): TUnitExports;
  public
    /// <summary>Creates an analyser with an empty ignore list and no resolver.</summary>
    constructor Create;
    /// <summary>Releases all owned resources.</summary>
    destructor Destroy; override;
    /// <summary>Replaces the list of unit names that are never reported.</summary>
    /// <param name="Names">The unit names.</param>
    procedure SetIgnoreList( const Names: TStrings );
    /// <summary>Analyses one unit's uses clauses.</summary>
    /// <param name="FileName">Full path of the unit, for reporting.</param>
    /// <param name="Content">The unit's source text.</param>
    /// <param name="DfmText">The text of the unit's form file; empty when it has none.</param>
    /// <param name="UnusedUnits">Receives the uses entries nothing refers to.</param>
    /// <returns>True when the unit was analysed; False when it cannot be judged safely (an include file after "interface").</returns>
    function AnalyseSource( const FileName, Content, DfmText: string; out UnusedUnits: TArray<TUnusedUnitInfo> ): Boolean;
    /// <summary>Supplies used units' source; a unit it cannot find is never reported.</summary>
    property OnResolveUnit: TResolveUnitSourceFunc read FOnResolveUnit write SetOnResolveUnit;
  end;

/// <summary>
/// Returns the names a unit's interface declares (types, enumeration values, constants, variables,
/// routines, fields, properties), and whether the unit must be kept whatever its names' use.
/// </summary>
/// <param name="Source">The unit's text.</param>
/// <param name="Names">Receives the declared names (the list is not cleared).</param>
/// <returns>True when the unit must be kept regardless: it has side effects (initialization,
/// finalization, class constructor / destructor, Register), declares a helper or an operator, or
/// includes a file in its interface.</returns>
function CollectInterfaceDeclarations( const Source: string; Names: TStrings ): Boolean;

implementation

uses
  DelphiLexer;

/// <summary>True for a token that can be an identifier in code: a plain identifier or a context-sensitive directive word.</summary>
/// <param name="Token">The token.</param>
/// <returns>True when the token can name something.</returns>
function IsNameToken( Token: TToken ): Boolean;
begin
  Result := ( Token <> nil ) and
            ( ( Token.Kind = tkIdent ) or
              ( Token.Kind in [ tkI_read, tkI_write, tkI_add, tkI_remove, tkI_default, tkI_name, tkI_index, tkI_message,
                                tkI_platform, tkI_local, tkI_reference, tkI_package, tkI_contains, tkI_requires,
                                tkI_at, tkI_on, tkI_out, tkI_helper, tkI_strict, tkI_final, tkI_sealed, tkI_static ] ) );
end;

/// <summary>The upper-case directive name of a directive token ("IFDEF" for "{$IFDEF X}").</summary>
/// <param name="Token">A tkDirective token.</param>
/// <returns>The directive name.</returns>
function DirectiveName( Token: TToken ): string;
begin
  var s := Token.Value;
  var i := Pos( '$', s ) + 1;
  var iStart := i;
  while ( i <= Length( s ) ) and CharInSet( s[ i ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) do
    Inc( i );
  Result := UpperCase( Copy( s, iStart, i - iStart ) );
end;

/// <summary>
/// True for an include-file directive: <c>{$INCLUDE file}</c> or <c>{$I file}</c>, but not the
/// I/O-checking switch <c>{$I+}</c> / <c>{$I-}</c>.
/// </summary>
/// <param name="Token">A tkDirective token.</param>
/// <returns>True when the directive names a file to include.</returns>
function IsIncludeDirective( Token: TToken ): Boolean;
begin
  var sName := DirectiveName( Token );
  if sName = 'INCLUDE' then
    Exit( True );
  if sName <> 'I' then
    Exit( False );

  var s := Token.Value;
  var i := Pos( '$', s ) + 2;   // just after the "I"
  var sArg := Trim( Copy( s, i, MaxInt ) );
  Result := ( i <= Length( s ) ) and CharInSet( s[ i ], [ ' ', #9 ] ) and
            ( sArg <> '' ) and not CharInSet( sArg[ 1 ], [ '+', '-', '}', '*' ] );
end;

/// <summary>
/// True for a directive that makes a used unit necessary whatever its names' use: an included file
/// (unknown declarations) or a linked resource or object file ({$R}, {$RESOURCE}, {$L}, {$LINK}).
/// </summary>
/// <param name="Token">A tkDirective token.</param>
/// <returns>True when the unit must be kept.</returns>
function IsKeepDirective( Token: TToken ): Boolean;
begin
  var sName := DirectiveName( Token );
  var iAfter := Pos( '$', Token.Value ) + 2;   // just after a one-letter name
  Result := IsIncludeDirective( Token ) or
            ( ( ( sName = 'R' ) or ( sName = 'L' ) ) and ( iAfter <= Length( Token.Value ) ) and
              CharInSet( Token.Value[ iAfter ], [ ' ', #9 ] ) ) or   // not the {$R+} / {$L-} switches
            ( sName = 'RESOURCE' ) or ( sName = 'LINK' );
end;

/// <summary>Removes the escape of an &amp;-escaped identifier (&amp;Type is the name Type).</summary>
/// <param name="Name">The identifier as written.</param>
/// <returns>The name without a leading &amp;.</returns>
function BareName( const Name: string ): string;
begin
  if ( Name <> '' ) and ( Name[ 1 ] = '&' ) then
    Result := Copy( Name, 2, MaxInt )
  else
    Result := Name;
end;

/// <summary>Returns the next token that is not a comment or directive.</summary>
/// <param name="Lexer">The lexer.</param>
/// <param name="Token">Receives the token; nil at the end of the text.</param>
/// <param name="SawKeep">Set to True when a directive that makes the unit necessary is passed over (see <see cref="IsKeepDirective"/>).</param>
/// <returns>True when a token was read.</returns>
function NextCode( Lexer: TDelphiLexer; out Token: TToken; var SawKeep: Boolean ): Boolean;
begin
  repeat
    Result := Lexer.NextToken( Token );
    if Result and ( Token.Kind = tkDirective ) and IsKeepDirective( Token ) then
      SawKeep := True;
  until not Result or not ( Token.Kind in [ tkComment, tkDirective ] );
end;

/// <summary>
/// True when the unit ends with an old-style initialization block, <c>begin ... end.</c>: the
/// final <c>end</c> closes a <c>begin</c> that belongs to no routine.
/// </summary>
/// <param name="Source">The unit text.</param>
/// <returns>True when the final end closes a block (any doubt about the structure also gives True).</returns>
function HasInitializationBlock( const Source: string ): Boolean;
begin
  Result := False;

  var oCode  := TList<TToken>.Create;
  var oLexer := TDelphiLexer.Create( '', UTF8Encode( Source ) );
  try
    var iImpl := -1;
    var oToken: TToken;
    while oLexer.NextToken( oToken ) do
      if not ( oToken.Kind in [ tkComment, tkDirective ] ) then
      begin
        if ( oToken.Kind = tkI_implementation ) and ( iImpl < 0 ) then
          iImpl := oCode.Count;
        oCode.Add( oToken );
      end;

    // the unit's final "end."
    var iEnd := oCode.Count - 2;
    while ( iEnd >= 0 ) and not ( ( oCode[ iEnd ].Kind = tkI_end ) and ( oCode[ iEnd + 1 ].Kind = tkQualifier ) ) do
      Dec( iEnd );
    if ( iEnd < 0 ) or ( iImpl < 0 ) then
      Exit;

    // Walk back to what the final end closes.  In a unit without an initialization block it closes
    // nothing, and the walk reaches "implementation" first.
    var iDepth := 1;
    for var i := iEnd - 1 downto iImpl + 1 do
    begin
      var eKind := oCode[ i ].Kind;
      if eKind = tkI_end then
        Inc( iDepth )
      else if eKind in [ tkI_begin, tkI_try, tkI_case, tkI_asm, tkI_record ] then
        Dec( iDepth )
      else if ( eKind in [ tkI_class, tkI_object, tkI_interface, tkI_dispinterface ] ) and
              ( oCode[ i - 1 ].Kind in [ tkEqual, tkI_packed ] ) and
              not ( oCode[ i + 1 ].Kind in [ tkSemicolon, tkI_of ] ) then
        Dec( iDepth );   // a class / interface body (forward declarations and "class of" have no end)
      if iDepth = 0 then
        Exit( True );   // a begin with no routine, or a structure this walk cannot follow: keep the unit
    end;
  finally
    oLexer.Free;
    oCode.Free;
  end;
end;

function CollectInterfaceDeclarations( const Source: string; Names: TStrings ): Boolean;
type
  TSection = ( secNone, secType, secConst, secVar );
var
  Token: TToken;
begin
  // The section each open body was entered from: a class var / nested const / nested type inside a
  // body must not leak out (the type section's later enumerations would be skipped as "constants").
  var oSections := TStack<TSection>.Create;
  var oLexer    := TDelphiLexer.Create( '', UTF8Encode( Source ) );
  try
    var bInInterface      := False;
    var bInImplementation := False;
    var bSawInclude       := False;   // a directive that makes the unit necessary (include, resource, link)
    var eSection          := secNone;
    var iBody             := 0;       // nesting of class / record / interface bodies

    // Adds a declared name; an attribute class TFooAttribute is used as [TFoo] / [Foo].
    var AddName: TProc<string> :=
      procedure( AName: string )
      begin
        AName := BareName( AName );
        Names.Add( AName );
        if ( Length( AName ) > 9 ) and SameText( Copy( AName, Length( AName ) - 8, 9 ), 'Attribute' ) then
          Names.Add( Copy( AName, 1, Length( AName ) - 9 ) );
      end;

    // Skips past the semicolon that ends the current declaration at bracket depth 0, or up to (not
    // past) an "end" that closes the enclosing body first.
    var SkipToSemicolon: TProc :=
      procedure
      begin
        var iDepth := 0;
        while NextCode( oLexer, Token, bSawInclude ) do
        begin
          if Token.Kind in [ tkLParan, tkLBracket ] then
            Inc( iDepth )
          else if Token.Kind in [ tkRParan, tkRBracket ] then
            Dec( iDepth )
          else if ( Token.Kind = tkSemicolon ) and ( iDepth <= 0 ) then
            Break
          else if ( Token.Kind = tkI_end ) and ( iDepth <= 0 ) then
          begin
            oLexer.RewindLastToken;   // "X: Integer end" - let the caller see the end
            Break;
          end;
        end;
      end;

    while oLexer.NextToken( Token ) do
    begin
      if Token.Kind = tkDirective then
      begin
        // a linked resource or object file anywhere, or an include file in the interface
        if IsKeepDirective( Token ) and ( ( bInInterface and not bInImplementation ) or not IsIncludeDirective( Token ) ) then
          bSawInclude := True;
        Continue;
      end;
      if Token.Kind = tkComment then
        Continue;

      // Side effects anywhere in the unit
      if Token.Kind in [ tkI_initialization, tkI_finalization ] then
        Exit( True );
      if ( Token.Kind = tkI_class ) and ( oLexer.LookAheadNoComment <> nil ) and
         ( oLexer.LookAheadNoComment.Kind in [ tkI_constructor, tkI_destructor, tkI_operator ] ) then
        Exit( True );
      // "class helper" / "record helper" ("Helper" alone is also an ordinary name)
      if Token.Kind = tkI_helper then
      begin
        var oPrev := oLexer.PreTokenNoCommentOf( Token );
        if ( oPrev <> nil ) and ( oPrev.Kind in [ tkI_class, tkI_record ] ) then
          Exit( True );
      end;

      if Token.Kind = tkI_interface then
      begin
        if not bInInterface and ( iBody = 0 ) and ( eSection = secNone ) then
        begin
          bInInterface := True;
          Continue;
        end;
      end;

      if Token.Kind = tkI_implementation then
        bInImplementation := True;

      // Past "implementation" only the side-effect checks above apply: nothing there is exported.
      if not bInInterface or bInImplementation then
        Continue;

      if Token.Kind = tkI_uses then
      begin
        SkipToSemicolon();
        Continue;
      end;

      case Token.Kind of
        tkI_type:
          begin
            eSection := secType;
            Continue;
          end;
        tkI_const, tkI_resourcestring:
          begin
            eSection := secConst;
            Continue;
          end;
        tkI_var, tkI_threadvar:
          begin
            eSection := secVar;
            Continue;
          end;
      end;

      // Routine headers: the name only, then skip parameters, result type and directives.
      if Token.Kind in [ tkI_procedure, tkI_function, tkI_constructor, tkI_destructor ] then
      begin
        if NextCode( oLexer, Token, bSawInclude ) then
        begin
          // "Register" lexes as the calling-convention keyword, so test it before IsNameToken
          if ( Token.Kind = tkI_register ) and ( iBody = 0 ) then
            Exit( True );   // a design-time registration unit
          if IsNameToken( Token ) then
            AddName( Token.Value );
        end;
        if ( Token <> nil ) and ( Token.Kind <> tkSemicolon ) then
          SkipToSemicolon();
        Continue;
      end;

      if Token.Kind = tkI_property then
      begin
        if NextCode( oLexer, Token, bSawInclude ) and IsNameToken( Token ) then
          AddName( Token.Value );
        SkipToSemicolon();
        Continue;
      end;

      if Token.Kind = tkI_end then
      begin
        if iBody > 0 then
        begin
          Dec( iBody );
          eSection := oSections.Pop;
        end;
        Continue;
      end;

      if not IsNameToken( Token ) then
        Continue;

      // A declared name: a list of names followed by ":" (field / variable / typed constant) or a
      // single name followed by "=" (type / constant), possibly generic ("TList<T> =").
      var oFirst := Token;
      var oNames := TList<string>.Create;
      try
        oNames.Add( oFirst.Value );
        var bOk := True;
        while bOk and NextCode( oLexer, Token, bSawInclude ) do
        begin
          if Token.Kind = tkComma then
          begin
            if NextCode( oLexer, Token, bSawInclude ) and IsNameToken( Token ) then
              oNames.Add( Token.Value )
            else
              bOk := False;
          end
          else if Token.Kind = tkLessThan then
          begin
            // generic parameters of a type name
            var iAngle := 1;
            while ( iAngle > 0 ) and NextCode( oLexer, Token, bSawInclude ) do
              if Token.Kind = tkLessThan then
                Inc( iAngle )
              else if Token.Kind = tkGreaterThan then
                Dec( iAngle );
          end
          else
            Break;
        end;

        if not bOk or ( Token = nil ) then
          Continue;

        if Token.Kind in [ tkColon, tkEqual ] then
          for var sName in oNames do
            AddName( sName );

        if Token.Kind = tkColon then
        begin
          // a field or variable whose type is an inline record opens a body
          var oNext := oLexer.LookAheadNoComment;
          if ( oNext <> nil ) and ( oNext.Kind in [ tkI_record, tkI_packed ] ) then
          begin
            NextCode( oLexer, Token, bSawInclude );
            if Token.Kind = tkI_packed then
              NextCode( oLexer, Token, bSawInclude );
            Inc( iBody );
            oSections.Push( eSection );
            eSection := secNone;
          end
          else
            SkipToSemicolon();
        end
        else if Token.Kind = tkEqual then
        begin
          if ( eSection <> secType ) or ( iBody > 0 ) then
          begin
            SkipToSemicolon();   // a constant's value
            Continue;
          end;

          // type TName = ...
          if not NextCode( oLexer, Token, bSawInclude ) then
            Break;
          if Token.Kind = tkI_type then
            NextCode( oLexer, Token, bSawInclude );   // "type TName = type Integer"
          if ( Token <> nil ) and ( Token.Kind = tkI_packed ) then
            NextCode( oLexer, Token, bSawInclude );
          if Token = nil then
            Break;

          if Token.Kind = tkLParan then
          begin
            // enumeration: every value is a name (an explicit ordinal's identifiers are kept too -
            // an extra name only ever makes the unit look used)
            while NextCode( oLexer, Token, bSawInclude ) and ( Token.Kind <> tkRParan ) do
              if IsNameToken( Token ) then
                AddName( Token.Value );
            SkipToSemicolon();
          end
          else if Token.Kind in [ tkI_class, tkI_record, tkI_interface, tkI_dispinterface, tkI_object ] then
          begin
            // a body unless it is a forward declaration, "class of", or "class( TBase );"
            var oNext := oLexer.LookAheadNoComment;
            if ( oNext <> nil ) and ( oNext.Kind in [ tkSemicolon, tkI_of ] ) then
              SkipToSemicolon()
            else
            begin
              if ( oNext <> nil ) and ( oNext.Kind = tkLParan ) then
              begin
                // heritage list: references, not declarations
                NextCode( oLexer, Token, bSawInclude );
                var iDepth := 1;
                while ( iDepth > 0 ) and NextCode( oLexer, Token, bSawInclude ) do
                  if Token.Kind = tkLParan then
                    Inc( iDepth )
                  else if Token.Kind = tkRParan then
                    Dec( iDepth );
                oNext := oLexer.LookAheadNoComment;
                if ( oNext <> nil ) and ( oNext.Kind = tkSemicolon ) then
                begin
                  NextCode( oLexer, Token, bSawInclude );
                  Continue;   // "EFoo = class( Exception );"
                end;
              end;
              Inc( iBody );
              oSections.Push( eSection );
              eSection := secNone;
            end;
          end
          else
            SkipToSemicolon();   // an alias, array, set, pointer or procedural type: references
        end;
      finally
        oNames.Free;
      end;
    end;

    Result := bSawInclude;
  finally
    oSections.Free;
    oLexer.Free;
  end;
end;

{ TUnitExports }

constructor TUnitExports.Create;
begin
  inherited Create;
  Names := TStringList.Create;
  Names.CaseSensitive := False;
  Names.Sorted        := True;
  Names.Duplicates    := dupIgnore;
end;

destructor TUnitExports.Destroy;
begin
  Names.Free;
  inherited Destroy;
end;

{ TUnitAnalyzer }

constructor TUnitAnalyzer.Create;
begin
  inherited Create;
  FIgnoreList := TStringList.Create;
  FIgnoreList.CaseSensitive := False;
  FExports := TObjectDictionary<string, TUnitExports>.Create( [ doOwnsValues ] );
end;

destructor TUnitAnalyzer.Destroy;
begin
  FExports.Free;
  FIgnoreList.Free;
  inherited Destroy;
end;

procedure TUnitAnalyzer.SetIgnoreList( const Names: TStrings );
begin
  FIgnoreList.Assign( Names );
end;

procedure TUnitAnalyzer.SetOnResolveUnit( const Value: TResolveUnitSourceFunc );
begin
  FOnResolveUnit := Value;
  FExports.Clear;
end;

function TUnitAnalyzer.GetUnitExports( const UnitName: string ): TUnitExports;
begin
  if FExports.TryGetValue( UpperCase( UnitName ), Result ) then
    Exit;

  Result := TUnitExports.Create;
  FExports.Add( UpperCase( UnitName ), Result );

  var sSource: string;
  if Assigned( FOnResolveUnit ) and FOnResolveUnit( UnitName, sSource ) then
  begin
    Result.Resolved := True;
    Result.MustKeep := CollectInterfaceDeclarations( sSource, Result.Names ) or HasInitializationBlock( sSource );
  end;
end;

function TUnitAnalyzer.AnalyseSource( const FileName, Content, DfmText: string;
  out UnusedUnits: TArray<TUnusedUnitInfo> ): Boolean;
var
  Token: TToken;
begin
  UnusedUnits := nil;

  var oUsed       := TList<TUsedUnitInfo>.Create;
  var oReferences := TStringList.Create;
  var oLexer      := TDelphiLexer.Create( FileName, UTF8Encode( Content ) );
  try
    oReferences.CaseSensitive := False;
    oReferences.Sorted        := True;
    oReferences.Duplicates    := dupIgnore;

    // One pass: uses entries (with their conditional state) and every name the code refers to.
    var bInInterface := False;
    var bInImpl      := False;
    var bInUses      := False;
    var bExpectName  := False;
    var iCondDepth   := 0;
    var sUnitName    := '';
    var iUnitLine    := 0;
    var bUnitCond    := False;
    var bIncludeSeen := False;

    while oLexer.NextToken( Token ) do
    begin
      if Token.Kind = tkComment then
        Continue;

      if Token.Kind = tkDirective then
      begin
        var sName := DirectiveName( Token );
        if ( sName = 'IF' ) or ( sName = 'IFDEF' ) or ( sName = 'IFNDEF' ) or ( sName = 'IFOPT' ) then
          Inc( iCondDepth )
        else if ( ( sName = 'ENDIF' ) or ( sName = 'IFEND' ) ) and ( iCondDepth > 0 ) then
          Dec( iCondDepth )
        else if IsIncludeDirective( Token ) then
        begin
          // an include file after "interface" may hold code that uses any unit: do not judge
          if bInInterface or bInImpl then
            bIncludeSeen := True;
        end;
        Continue;
      end;

      if bInUses then
      begin
        if bExpectName and IsNameToken( Token ) then
        begin
          if sUnitName = '' then
          begin
            iUnitLine := Token.Line + 1;
            bUnitCond := iCondDepth > 0;
          end;
          sUnitName   := sUnitName + Token.Value;
          bExpectName := False;
        end
        else if Token.Kind = tkQualifier then
        begin
          sUnitName   := sUnitName + '.';
          bExpectName := True;
        end
        else if Token.Kind in [ tkComma, tkSemicolon ] then
        begin
          if sUnitName <> '' then
          begin
            var rInfo: TUsedUnitInfo;
            rInfo.UnitName      := sUnitName;
            rInfo.IsInterface   := not bInImpl;
            rInfo.IsConditional := bUnitCond or ( iCondDepth > 0 );
            rInfo.LineNumber    := iUnitLine;
            oUsed.Add( rInfo );
          end;
          sUnitName   := '';
          bExpectName := True;
          if Token.Kind = tkSemicolon then
            bInUses := False;
        end;
        // "in 'path'" and anything else inside the clause is skipped
        Continue;
      end;

      case Token.Kind of
        tkI_interface:
          if not bInImpl then
            bInInterface := True;
        tkI_implementation:
          begin
            bInInterface := False;
            bInImpl      := True;
          end;
        tkI_uses:
          if bInInterface or bInImpl then
          begin
            bInUses     := True;
            bExpectName := True;
            sUnitName   := '';
          end;
      else
        if IsNameToken( Token ) then
          oReferences.Add( BareName( Token.Value ) );
      end;
    end;

    if bIncludeSeen then
      Exit( False );

    // Every word of the form text counts as a reference: streamed class names (object X: TFoo)
    // and identifier property values (Align = alClient) alike.
    var i := 1;
    while i <= Length( DfmText ) do
    begin
      if CharInSet( DfmText[ i ], [ 'A'..'Z', 'a'..'z', '_' ] ) then
      begin
        var iStart := i;
        while ( i <= Length( DfmText ) ) and CharInSet( DfmText[ i ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) do
          Inc( i );
        oReferences.Add( Copy( DfmText, iStart, i - iStart ) );
      end
      else
        Inc( i );
    end;

    var sSourceUnit := ChangeFileExt( ExtractFileName( FileName ), '' );
    var oUnused := TList<TUnusedUnitInfo>.Create;
    try
      for var rUsed in oUsed do
      begin
        if rUsed.IsConditional or ( FIgnoreList.IndexOf( rUsed.UnitName ) >= 0 ) then
          Continue;

        var oExports := GetUnitExports( rUsed.UnitName );
        if not oExports.Resolved or oExports.MustKeep or ( oExports.Names.Count = 0 ) then
          Continue;

        // A qualified reference (UnitB.Thing) names the unit itself.
        var bUsed := oReferences.IndexOf( rUsed.UnitName ) >= 0;
        var aParts := rUsed.UnitName.Split( [ '.' ] );
        if not bUsed and ( Length( aParts ) > 1 ) then
          bUsed := oReferences.IndexOf( aParts[ High( aParts ) ] ) >= 0;

        if not bUsed then
          for var sName in oExports.Names do
            if oReferences.IndexOf( sName ) >= 0 then
            begin
              bUsed := True;
              Break;
            end;

        if bUsed then
          Continue;

        var rInfo: TUnusedUnitInfo;
        rInfo.SourceUnit     := sSourceUnit;
        rInfo.SourceFileName := FileName;
        rInfo.UnusedUnit     := rUsed.UnitName;
        rInfo.IsInterface    := rUsed.IsInterface;
        rInfo.LineNumber     := rUsed.LineNumber;
        oUnused.Add( rInfo );
      end;

      UnusedUnits := oUnused.ToArray;
    finally
      oUnused.Free;
    end;

    Result := True;
  finally
    oLexer.Free;
    oReferences.Free;
    oUsed.Free;
  end;
end;

end.
