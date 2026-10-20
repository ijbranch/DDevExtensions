{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude Code                                           *}
{*                                                                            *}
{* MethodSeparatorsCore - finds the source lines above which the code editor  *}
{* draws a method separator.                                                  *}
{*                                                                            *}
{* Idea credit: Tulip Method Separators by Samer Assil (MIT licence),         *}
{* https://github.com/SamerAssil/Tulip_Method_Separators                      *}
{* This is an independent implementation; no Tulip source is included.        *}
{*                                                                            *}
{******************************************************************************}

unit MethodSeparatorsCore;

/// <summary>
/// IDE-free analysis behind the Method Separators feature.  Tokenises a Pascal
/// source with <c>DelphiLexer</c> and returns the lines that start a top-level
/// block (a routine, a class / record / interface declaration, or an
/// <c>initialization</c> / <c>finalization</c> / main <c>begin</c> section), plus the
/// colour arithmetic that keeps the separator visible on light and dark themes.
/// </summary>
/// <remarks>
/// Depends on the RTL and <c>DelphiLexer</c> only - no ToolsAPI and no VCL - so
/// every rule here is covered by DUnitX tests without an IDE.  A separator line
/// is the first line of the block, moved up over any comment, directive or
/// attribute lines attached directly above it, so a DocInsight block stays
/// with the routine it documents.
/// </remarks>

interface

uses
  System.SysUtils, System.UITypes;

type
  /// <summary>Which kinds of block, beyond top-level routines, receive a separator.</summary>
  TSeparatorOptions = record
    /// <summary>Separate class, record, object and interface declarations that have a body.</summary>
    IncludeTypes: Boolean;
    /// <summary>Separate the <c>initialization</c> and <c>finalization</c> sections and a main <c>begin</c> block.</summary>
    IncludeSections: Boolean;
    /// <summary>Also separate blocks in the interface section ( by default only the implementation section is marked ).</summary>
    IncludeInterface: Boolean;
    /// <summary>Returns the default options: types and sections on, interface section off.</summary>
    /// <returns>The default option set.</returns>
    class function Default: TSeparatorOptions; static;
  end;

/// <summary>
/// Returns the 1-based line numbers above which a separator is drawn, sorted
/// ascending with no duplicates.
/// </summary>
/// <param name="Source">The complete unit, program or package source as UTF-8.</param>
/// <param name="Options">Which kinds of block receive a separator.</param>
/// <returns>The sorted separator lines; empty for an empty or unparsable source.</returns>
function FindSeparatorLines( const Source: UTF8String; const Options: TSeparatorOptions ): TArray<Integer>;

/// <summary>Returns True when Line is one of the separator lines returned by <see cref="FindSeparatorLines"/>.</summary>
/// <param name="Lines">A sorted array from <see cref="FindSeparatorLines"/>.</param>
/// <param name="Line">The 1-based line number to test.</param>
/// <returns>True when a separator is drawn above Line.</returns>
function IsSeparatorLine( const Lines: TArray<Integer>; Line: Integer ): Boolean;

/// <summary>Returns the perceived brightness of an RGB colour ( ITU-R BT.601 weights ).</summary>
/// <param name="Color">An RGB colour; a system colour must be converted with <c>ColorToRGB</c> first.</param>
/// <returns>The luminance, 0 ( black ) to 255 ( white ).</returns>
function ColorLuminance( Color: TColor ): Integer;

/// <summary>Returns a separator colour derived from the editor background: darker on a light theme, lighter on a dark one.</summary>
/// <param name="Background">The editor background as an RGB colour.</param>
/// <returns>The separator colour.</returns>
function AutoSeparatorColor( Background: TColor ): TColor;

/// <summary>
/// Returns the colour to draw with: Custom when requested and distinguishable
/// from the background, otherwise <see cref="AutoSeparatorColor"/>.
/// </summary>
/// <param name="Background">The editor background as an RGB colour.</param>
/// <param name="Custom">The user's chosen colour as an RGB colour.</param>
/// <param name="UseCustom">True when the user chose a custom colour.</param>
/// <returns>The separator colour.</returns>
function ResolveSeparatorColor( Background, Custom: TColor; UseCustom: Boolean ): TColor;

type
  /// <summary>What a paint cycle does with a file's cached separator lines.</summary>
  TRecheckAction = (
    /// <summary>Use the cache as it is.</summary>
    raNone,
    /// <summary>Re-read the buffer now and rescan it if its text changed.</summary>
    raRefresh,
    /// <summary>Too soon to re-read: use the cache and repaint shortly so the check still happens.</summary>
    raDefer
  );

/// <summary>
/// Decides whether the paint cycle in progress re-reads its file.  A file is read at
/// most once per paint cycle and at most once every IntervalMs; a check skipped for
/// being too soon is deferred, never dropped, so the final keystroke of a burst
/// still updates the separators.
/// </summary>
/// <param name="CycleChecked">True when this paint cycle has already decided.</param>
/// <param name="NowTick">The current GetTickCount64 value.</param>
/// <param name="CheckedTick">The GetTickCount64 value of the file's last read.</param>
/// <param name="IntervalMs">Shortest interval between two reads of the same file.</param>
/// <returns>The action to take.</returns>
function DecideRecheck( CycleChecked: Boolean; NowTick, CheckedTick: UInt64; IntervalMs: Cardinal ): TRecheckAction;

/// <summary>Returns True for the file kinds the scanner understands ( .pas, .dpr, .dpk ).</summary>
/// <param name="FileName">The file name or path; only its extension is examined, ignoring case.</param>
/// <returns>True when separators are drawn for the file.</returns>
function IsPascalSourceFile( const FileName: string ): Boolean;

const
  /// <summary>Smallest luminance difference at which a custom colour is still visible against the background.</summary>
  MinSeparatorContrast = 32;

implementation

uses
  System.Generics.Collections, DelphiLexer;

const
  RoutineKinds = [tkI_procedure, tkI_function, tkI_constructor, tkI_destructor, tkI_operator];
  StructureKinds = [tkI_class, tkI_object, tkI_interface, tkI_dispinterface];

type
  /// <summary>Single-use scanner that walks the significant tokens of one source.</summary>
  TSeparatorScanner = class
  private
    FOptions: TSeparatorOptions;
    FText: UTF8String;
    FAll: TList<TToken>;
    FSig: TList<Integer>;
    FLines: TList<Integer>;
    function Kind( SigIndex: Integer ): TTokenKind;
    function EndLine( Token: TToken ): Integer;
    function FirstLineOf( SigIndex: Integer ): Integer;
    procedure AddSeparator( SigIndex: Integer );
    function SkipBackOverAttributes( SigIndex: Integer ): Integer;
    function IsDeclarationBoundary( SigIndex: Integer ): Boolean;
    function IsRoutineStart( SigIndex: Integer ): Boolean;
    function IsRecordOpener( SigIndex: Integer ): Boolean;
    function IsStructureOpener( SigIndex: Integer ): Boolean;
    function TypeDeclarationStart( OpenerIndex: Integer ): Integer;
    function SkipMatching( SigIndex: Integer; Open, Close: TTokenKind ): Integer;
    function SkipBlock( SigIndex: Integer ): Integer;
    function SkipStructure( SigIndex: Integer; out HasBody: Boolean ): Integer;
    function HasElseDirectiveBefore( SigIndex: Integer ): Boolean;
    function SkipRoutine( SigIndex: Integer; AllowBody: Boolean ): Integer;
    procedure Scan;
  public
    constructor Create( const Source: UTF8String; const Options: TSeparatorOptions );
    destructor Destroy; override;
    function Execute: TArray<Integer>;
  end;

{ TSeparatorOptions }

class function TSeparatorOptions.Default: TSeparatorOptions;
begin

  Result.IncludeTypes := True;
  Result.IncludeSections := True;
  Result.IncludeInterface := False;

end;

{ TSeparatorScanner }

constructor TSeparatorScanner.Create( const Source: UTF8String; const Options: TSeparatorOptions );
begin

  inherited Create;
  FText := Source;
  FOptions := Options;
  FAll := TList<TToken>.Create;
  FSig := TList<Integer>.Create;
  FLines := TList<Integer>.Create;

end;

destructor TSeparatorScanner.Destroy;
begin

  FLines.Free;
  FSig.Free;
  FAll.Free;
  inherited Destroy;

end;

function TSeparatorScanner.Execute: TArray<Integer>;
var
  Lexer: TDelphiLexer;
  Token: TToken;
begin

  Lexer := TDelphiLexer.Create( '', FText );
  try
    while Lexer.NextToken( Token ) do
    begin
      if not ( Token.Kind in [tkComment, tkDirective] ) then
        FSig.Add( FAll.Count );
      FAll.Add( Token );
    end;
    Scan;
  finally
    // The lexer owns the tokens; drop the references before it frees them.
    FAll.Clear;
    Lexer.Free;
  end;

  FLines.Sort;
  var Unique := TList<Integer>.Create;
  try
    for var Line in FLines do
      if ( Unique.Count = 0 ) or ( Unique.Last <> Line ) then
        Unique.Add( Line );
    Result := Unique.ToArray;
  finally
    Unique.Free;
  end;

end;

function TSeparatorScanner.Kind( SigIndex: Integer ): TTokenKind;
begin

  if ( SigIndex >= 0 ) and ( SigIndex < FSig.Count ) then
    Result := FAll[FSig[SigIndex]].Kind
  else
    Result := tkNone;

end;

function TSeparatorScanner.EndLine( Token: TToken ): Integer;
var
  I: Integer;
  Last: Integer;
begin

  // A token spans Index..EndIndex inclusive; a line break the lexer swallowed at
  // its end ( a "//" comment ) does not move it onto the next line.
  Result := Token.Line;
  Last := Token.EndIndex;
  if Last > Length( FText ) then
    Last := Length( FText );
  while ( Last >= Token.Index ) and ( FText[Last] in [#10, #13] ) do
    Dec( Last );
  for I := Token.Index to Last do
    if FText[I] = #10 then
      Inc( Result );

end;

function TSeparatorScanner.FirstLineOf( SigIndex: Integer ): Integer;
var
  AllIndex: Integer;
  Candidate: TToken;
begin

  // Climb over comment and directive lines stacked directly above the block, so
  // its documentation sits below the separator.  A comment trailing code on its
  // own line belongs to that code and stops the climb.
  AllIndex := FSig[SigIndex];
  Result := FAll[AllIndex].Line;
  while AllIndex > 0 do
  begin
    Candidate := FAll[AllIndex - 1];
    if not ( Candidate.Kind in [tkComment, tkDirective] ) then
      Break;
    if EndLine( Candidate ) < Result - 1 then
      Break;
    if ( AllIndex > 1 ) and ( EndLine( FAll[AllIndex - 2] ) >= Candidate.Line ) then
      Break;
    Result := Candidate.Line;
    Dec( AllIndex );
  end;

end;

procedure TSeparatorScanner.AddSeparator( SigIndex: Integer );
begin

  // Lexer lines are 0-based; the editor numbers lines from 1.
  FLines.Add( FirstLineOf( SigIndex ) + 1 );

end;

function TSeparatorScanner.SkipBackOverAttributes( SigIndex: Integer ): Integer;
var
  Depth: Integer;
  I: Integer;
begin

  // SigIndex is the first token of a declaration; step back over each
  // [Attribute] group immediately before it.
  Result := SigIndex;
  while Kind( Result - 1 ) = tkRBracket do
  begin
    Depth := 0;
    I := Result - 1;
    while I >= 0 do
    begin
      if Kind( I ) = tkRBracket then
        Inc( Depth )
      else if Kind( I ) = tkLBracket then
      begin
        Dec( Depth );
        if Depth = 0 then
          Break;
      end;
      Dec( I );
    end;
    if I < 0 then
      Exit;
    Result := I;
  end;

end;

function TSeparatorScanner.IsDeclarationBoundary( SigIndex: Integer ): Boolean;
begin

  // True when a declaration may start right after SigIndex.
  Result := Kind( SigIndex ) in [tkNone, tkSemicolon, tkRBracket, tkI_implementation, tkI_interface];

end;

function TSeparatorScanner.IsRoutineStart( SigIndex: Integer ): Boolean;
begin

  // A routine header, not a procedural type ( "= procedure" ), a reference type
  // ( "to procedure" ), a field of procedural type ( ": procedure" ) nor an
  // anonymous method ( ", procedure" ).
  case Kind( SigIndex ) of
    tkI_class:
      Result := ( Kind( SigIndex + 1 ) in RoutineKinds ) and IsDeclarationBoundary( SigIndex - 1 );
    tkI_procedure, tkI_function, tkI_constructor, tkI_destructor, tkI_operator:
      Result := IsDeclarationBoundary( SigIndex - 1 );
  else
    Result := False;
  end;

end;

function TSeparatorScanner.IsRecordOpener( SigIndex: Integer ): Boolean;
begin

  // "record" also appears as a generic constraint ( <T: record> ), which has no body.
  Result := ( Kind( SigIndex ) = tkI_record ) and not ( Kind( SigIndex + 1 ) in [tkGreaterThan, tkComma, tkSemicolon] );

end;

function TSeparatorScanner.IsStructureOpener( SigIndex: Integer ): Boolean;
begin

  if IsRecordOpener( SigIndex ) then
    Exit( True );
  // "class" / "object" / "interface" open a type only directly after "=" ( or
  // "= packed" ), which rules out "class procedure", "of object", constraints
  // and the interface section keyword.
  Result := ( Kind( SigIndex ) in StructureKinds ) and
    ( ( Kind( SigIndex - 1 ) = tkEqual ) or ( ( Kind( SigIndex - 1 ) = tkI_packed ) and ( Kind( SigIndex - 2 ) = tkEqual ) ) );

end;

function TSeparatorScanner.TypeDeclarationStart( OpenerIndex: Integer ): Integer;
var
  Depth: Integer;
begin

  // Opener is preceded by "Name [<Params>] = [packed]"; return the index of Name
  // ( or of its attributes ), or -1 when the shape is not a named declaration.
  Result := OpenerIndex - 1;
  if Kind( Result ) = tkI_packed then
    Dec( Result );
  if Kind( Result ) <> tkEqual then
    Exit( -1 );
  Dec( Result );
  if Kind( Result ) = tkGreaterThan then
  begin
    Depth := 0;
    while Result >= 0 do
    begin
      if Kind( Result ) = tkGreaterThan then
        Inc( Depth )
      else if Kind( Result ) = tkLessThan then
      begin
        Dec( Depth );
        if Depth = 0 then
          Break;
      end;
      Dec( Result );
    end;
    Dec( Result );
  end;
  if ( Result < 0 ) or ( Kind( Result ) < tkIdent ) then
    Exit( -1 );
  Result := SkipBackOverAttributes( Result );

end;

function TSeparatorScanner.SkipMatching( SigIndex: Integer; Open, Close: TTokenKind ): Integer;
var
  Depth: Integer;
begin

  // SigIndex is on Open; return the index after its matching Close.
  Depth := 0;
  Result := SigIndex;
  while Result < FSig.Count do
  begin
    if Kind( Result ) = Open then
      Inc( Depth )
    else if Kind( Result ) = Close then
    begin
      Dec( Depth );
      if Depth = 0 then
        Exit( Result + 1 );
    end;
    Inc( Result );
  end;

end;

function TSeparatorScanner.SkipBlock( SigIndex: Integer ): Integer;
var
  Depth: Integer;
begin

  // SigIndex is on "begin" or "asm"; return the index after the matching "end".
  // An asm block has no nested blocks, and its labels may look like keywords.
  Result := SigIndex;
  if Kind( Result ) = tkI_asm then
  begin
    Inc( Result );
    while ( Result < FSig.Count ) and ( Kind( Result ) <> tkI_end ) do
      Inc( Result );
    Exit( Result + 1 );
  end;

  Depth := 0;
  while Result < FSig.Count do
  begin
    case Kind( Result ) of
      tkI_asm:
        begin
          Result := SkipBlock( Result );
          Continue;
        end;
      tkI_begin, tkI_case, tkI_try:
        Inc( Depth );
      tkI_end:
        begin
          Dec( Depth );
          if Depth = 0 then
            Exit( Result + 1 );
        end;
    end;
    Inc( Result );
  end;

end;

function TSeparatorScanner.SkipStructure( SigIndex: Integer; out HasBody: Boolean ): Integer;
var
  Opener: TTokenKind;
  Depth: Integer;
  Nested: Boolean;
begin

  // SigIndex is on an opener accepted by IsStructureOpener.  Returns the index
  // after the closing "end", or of the ";" of a body-less declaration such as
  // "TFoo = class;", "TFoo = class( TBar );" or "TRef = class of TFoo".
  HasBody := False;
  Opener := Kind( SigIndex );
  Result := SigIndex + 1;
  if Opener <> tkI_record then
  begin
    if ( Opener = tkI_class ) and ( Kind( Result ) = tkI_of ) then
      Exit;
    // Modifiers: sealed, abstract, helper for TType.
    while ( Kind( Result ) >= tkIdent ) and ( Kind( Result ) < tkIdentStrictReserved ) or ( Kind( Result ) in [tkI_for, tkQualifier] ) do
    begin
      if ( Kind( Result + 1 ) = tkColon ) then
        Break; // A field directly after "class": the body has started.
      Inc( Result );
    end;
    if Kind( Result ) = tkLParan then
      Result := SkipMatching( Result, tkLParan, tkRParan );
    if Kind( Result ) = tkSemicolon then
      Exit;
  end;

  HasBody := True;
  Depth := 1;
  while Result < FSig.Count do
  begin
    if Kind( Result ) = tkI_end then
    begin
      Dec( Depth );
      if Depth = 0 then
        Exit( Result + 1 );
    end
    else if IsRecordOpener( Result ) then
      Inc( Depth )
    else if IsStructureOpener( Result ) then
    begin
      Result := SkipStructure( Result, Nested );
      Continue;
    end;
    Inc( Result );
  end;

end;

function TSeparatorScanner.HasElseDirectiveBefore( SigIndex: Integer ): Boolean;
var
  AllIndex: Integer;
  Token: TToken;
begin

  // True when an {$ELSE} or {$ELSEIF} sits between SigIndex and the significant token before it.
  Result := False;
  if ( SigIndex <= 0 ) or ( SigIndex >= FSig.Count ) then
    Exit;
  for AllIndex := FSig[SigIndex - 1] + 1 to FSig[SigIndex] - 1 do
  begin
    Token := FAll[AllIndex];
    if ( Token.Kind = tkDirective ) and
      UpperCase( Token.Value ).TrimLeft( ['{', '(', '*', '$', ' '] ).StartsWith( 'ELSE' ) then
      Exit( True );
  end;

end;

function TSeparatorScanner.SkipRoutine( SigIndex: Integer; AllowBody: Boolean ): Integer;
var
  Depth: Integer;
  HasBody: Boolean;
  Ignored: Boolean;
begin

  // SigIndex is on a header accepted by IsRoutineStart.  Skips the header, its
  // directives and - when AllowBody and the routine is neither forward nor
  // external - its local declarations ( nested routines included ) and body.
  // Alternative headers for one body ( "{$IFDEF X} procedure A( I: Int64 );
  // {$ELSE} procedure A( I: Integer ); {$ENDIF}" ) are skipped as one header, or
  // the second would be taken for a nested routine and swallow what follows.
  Result := SigIndex;
  repeat
    if Kind( Result ) = tkI_class then
      Inc( Result );
    Inc( Result );

    // Header up to the ";" outside the parameter list.
    Depth := 0;
    while Result < FSig.Count do
    begin
      case Kind( Result ) of
        tkLParan:
          Inc( Depth );
        tkRParan:
          Dec( Depth );
        tkSemicolon:
          if Depth <= 0 then
            Break;
      end;
      Inc( Result );
    end;
    Inc( Result );

    // Directive clauses: overload; inline; external 'x' name 'y'; deprecated 'z'; ...
    HasBody := AllowBody;
    while ( ( Kind( Result ) >= tkIdent ) and ( Kind( Result ) < tkIdentStrictReserved ) ) or ( Kind( Result ) in [tkI_inline, tkI_library] ) do
    begin
      if Kind( Result ) in [tkI_forward, tkI_external] then
        HasBody := False;
      while ( Result < FSig.Count ) and ( Kind( Result ) <> tkSemicolon ) do
        Inc( Result );
      Inc( Result );
    end;
  until not ( IsRoutineStart( Result ) and HasElseDirectiveBefore( Result ) );
  if not HasBody then
    Exit;

  // Local declarations, then the body.
  while Result < FSig.Count do
  begin
    case Kind( Result ) of
      tkI_begin, tkI_asm:
        begin
          Result := SkipBlock( Result );
          if Kind( Result ) = tkSemicolon then
            Inc( Result );
          Exit;
        end;
      tkI_implementation, tkI_initialization, tkI_finalization:
        Exit; // Lost sync: let the caller resume at the section keyword.
    end;
    if IsRoutineStart( Result ) then
      Result := SkipRoutine( Result, True )
    else if IsStructureOpener( Result ) then
      Result := SkipStructure( Result, Ignored )
    else
      Inc( Result );
  end;

end;

procedure TSeparatorScanner.Scan;
var
  P: Integer;
  InImplementation: Boolean;
  InSectionCode: Boolean;
  Marking: Boolean;
  Start: Integer;
  HasBody: Boolean;
  Next: Integer;
begin

  // A program, library or package has no interface section: all of it is "implementation".
  InImplementation := Kind( 0 ) <> tkI_unit;
  InSectionCode := False;
  P := 0;
  while P < FSig.Count do
  begin
    Marking := InImplementation or FOptions.IncludeInterface;
    case Kind( P ) of
      tkI_implementation:
        begin
          InImplementation := True;
          Inc( P );
          Continue;
        end;
      tkI_initialization, tkI_finalization:
        begin
          if FOptions.IncludeSections then
            AddSeparator( P );
          InSectionCode := True;
          Inc( P );
          Continue;
        end;
      tkI_begin:
        begin
          // A program's main block, or a unit's old-style initialisation; a
          // compound statement inside an initialization section is neither.
          if FOptions.IncludeSections and InImplementation and not InSectionCode then
            AddSeparator( P );
          P := SkipBlock( P );
          Continue;
        end;
      tkI_end:
        if Kind( P + 1 ) = tkQualifier then
          Break; // "end." - nothing after it is code.
    end;

    if IsRoutineStart( P ) then
    begin
      if Marking then
        AddSeparator( SkipBackOverAttributes( P ) );
      Next := SkipRoutine( P, InImplementation );
    end
    else if IsStructureOpener( P ) then
    begin
      Start := TypeDeclarationStart( P );
      Next := SkipStructure( P, HasBody );
      if HasBody and Marking and FOptions.IncludeTypes and ( Start >= 0 ) then
        AddSeparator( Start );
    end
    else
      Next := P + 1;

    // Every branch must make progress, whatever the source looks like.
    if Next <= P then
      Next := P + 1;
    P := Next;
  end;

end;

{ Public routines }

function FindSeparatorLines( const Source: UTF8String; const Options: TSeparatorOptions ): TArray<Integer>;
var
  Scanner: TSeparatorScanner;
begin

  if Source = '' then
    Exit( nil );

  Scanner := TSeparatorScanner.Create( Source, Options );
  try
    Result := Scanner.Execute;
  finally
    Scanner.Free;
  end;

end;

function IsSeparatorLine( const Lines: TArray<Integer>; Line: Integer ): Boolean;
var
  FoundIndex: Integer;
begin

  Result := TArray.BinarySearch<Integer>( Lines, Line, FoundIndex );

end;

function DecideRecheck( CycleChecked: Boolean; NowTick, CheckedTick: UInt64; IntervalMs: Cardinal ): TRecheckAction;
begin

  if CycleChecked then
    Result := raNone
  else if ( NowTick < CheckedTick ) or ( NowTick - CheckedTick >= IntervalMs ) then
    Result := raRefresh // A tick that went backwards is treated as "long ago", never as "just now".
  else
    Result := raDefer;

end;

function IsPascalSourceFile( const FileName: string ): Boolean;
var
  Ext: string;
begin

  Ext := ExtractFileExt( FileName );
  Result := SameText( Ext, '.pas' ) or SameText( Ext, '.dpr' ) or SameText( Ext, '.dpk' );

end;

function ColorLuminance( Color: TColor ): Integer;
var
  Rgb: Cardinal;
begin

  Rgb := Cardinal( Color ) and $00FFFFFF;
  Result := ( Integer( Rgb and $FF ) * 299 + Integer( ( Rgb shr 8 ) and $FF ) * 587 + Integer( ( Rgb shr 16 ) and $FF ) * 114 ) div 1000;

end;

/// <summary>Mixes Percent of Target into Base, channel by channel.</summary>
function BlendColor( Base, Target: TColor; Percent: Integer ): TColor;
var
  BaseRgb, TargetRgb: Cardinal;
  Shift: Integer;
  Channel: Integer;
  Mixed: Cardinal;
begin

  BaseRgb := Cardinal( Base ) and $00FFFFFF;
  TargetRgb := Cardinal( Target ) and $00FFFFFF;
  Mixed := 0;
  Shift := 0;
  while Shift <= 16 do
  begin
    Channel := Integer( ( BaseRgb shr Shift ) and $FF );
    Channel := Channel + ( Integer( ( TargetRgb shr Shift ) and $FF ) - Channel ) * Percent div 100;
    Mixed := Mixed or ( Cardinal( Channel ) shl Shift );
    Inc( Shift, 8 );
  end;
  Result := TColor( Mixed );

end;

function AutoSeparatorColor( Background: TColor ): TColor;
begin

  if ColorLuminance( Background ) >= 128 then
    Result := BlendColor( Background, TColors.Black, 25 )
  else
    Result := BlendColor( Background, TColors.White, 30 );

end;

function ResolveSeparatorColor( Background, Custom: TColor; UseCustom: Boolean ): TColor;
begin

  if UseCustom and ( Abs( ColorLuminance( Custom ) - ColorLuminance( Background ) ) >= MinSeparatorContrast ) then
    Result := TColor( Cardinal( Custom ) and $00FFFFFF )
  else
    Result := AutoSeparatorColor( Background );

end;

end.
