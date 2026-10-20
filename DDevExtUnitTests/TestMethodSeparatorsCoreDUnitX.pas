unit TestMethodSeparatorsCoreDUnitX;

/// <summary>
/// DUnitX test fixture for <c>MethodSeparatorsCore</c> - the IDE-free scan that
/// decides which editor lines get a method separator, and the colour arithmetic
/// that keeps the line visible on light and dark editor themes.
/// </summary>
/// <remarks>
/// Each fixture source is built from an array of lines, so the expected line
/// numbers can be read straight off the array: element 0 is editor line 1.
/// Results are compared as comma-separated text so a failure shows the whole
/// set rather than the first differing element.
/// </remarks>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising the method separator scan and colour rules.</summary>
  [TestFixture]
  TTestMethodSeparatorsCore = class
  public
    /// <summary>
    /// Proves each top-level routine in the implementation section gets a
    /// separator on its header line, and that interface declarations get none by
    /// default (the editor would otherwise be striped through the interface).
    /// </summary>
    [Test]
    procedure TestRoutinesInImplementationOnly;
    /// <summary>
    /// Proves the separator climbs over a DocInsight block stacked directly above
    /// a routine, so the documentation stays with the routine it describes.
    /// </summary>
    [Test]
    procedure TestLeadingCommentBlockStaysBelowSeparator;
    /// <summary>
    /// Proves a blank line stops the climb, and a comment trailing code on the
    /// line above is not taken as the routine's documentation.
    /// </summary>
    [Test]
    procedure TestClimbStopsAtBlankLineAndTrailingComment;
    /// <summary>
    /// Proves nested routines and anonymous methods do not get separators: only
    /// the outer routine does, and the routine after it is still found (the
    /// nested body did not desynchronise the scan).
    /// </summary>
    [Test]
    procedure TestNestedAndAnonymousRoutinesIgnored;
    /// <summary>
    /// Proves procedural types, reference types and procedural-type fields are
    /// not mistaken for routine headers.
    /// </summary>
    [Test]
    procedure TestProceduralTypesAreNotRoutines;
    /// <summary>
    /// Proves a class declared in the implementation section gets one separator,
    /// its member declarations none, and body-less forms (forward, short
    /// "class( Exception );", "class of") none at all.
    /// </summary>
    [Test]
    procedure TestTypeDeclarations;
    /// <summary>
    /// Proves a generic "record" constraint does not open a record body: were it
    /// taken as one, the scan would swallow the routine that follows.
    /// </summary>
    [Test]
    procedure TestGenericRecordConstraintDoesNotOpenBody;
    /// <summary>
    /// Proves an attribute above a type moves the separator up to the attribute
    /// line.
    /// </summary>
    [Test]
    procedure TestAttributeMovesSeparatorUp;
    /// <summary>
    /// Proves initialization and finalization get separators, but a compound
    /// "begin" statement inside the initialization section does not.
    /// </summary>
    [Test]
    procedure TestSectionsAndInitializationStatements;
    /// <summary>
    /// Proves a program has no interface section to skip: its routines and its
    /// main block are separated.
    /// </summary>
    [Test]
    procedure TestProgramMainBlock;
    /// <summary>
    /// Proves forward and external declarations have no body: the routine after
    /// each is still recognised as a separate top-level routine.
    /// </summary>
    [Test]
    procedure TestForwardAndExternalDeclarations;
    /// <summary>
    /// Proves class methods, class operators and an asm body (whose labels look
    /// like keywords) are handled without losing the routines that follow.
    /// </summary>
    [Test]
    procedure TestClassMethodsAndAsm;
    /// <summary>
    /// Proves the IncludeTypes, IncludeSections and IncludeInterface options each
    /// switch their kind of separator on or off independently.
    /// </summary>
    [Test]
    procedure TestOptionsSwitchKindsIndependently;
    /// <summary>
    /// Proves truncated and malformed sources return without hanging or raising,
    /// because the scan runs inside the editor's paint cycle.
    /// </summary>
    [Test]
    procedure TestMalformedSourceTerminates;
    /// <summary>
    /// Proves nested types, record and class helpers, packed variant records with an
    /// embedded record, GUID interfaces and old-style objects each get exactly one
    /// separator and are skipped as a whole, so the routine after them is found.
    /// </summary>
    [Test]
    procedure TestNestedTypesHelpersAndVariantRecords;
    /// <summary>
    /// Proves keywords inside string literals and all three comment forms are
    /// invisible to the scan: none opens or closes a block.
    /// </summary>
    [Test]
    procedure TestKeywordsInStringsAndCommentsIgnored;
    /// <summary>
    /// Proves alternative headers under {$IFDEF}/{$ELSE} are treated as one routine.
    /// Before the fix the second header was taken for a nested routine and the
    /// routine after it lost its separator.
    /// </summary>
    [Test]
    procedure TestConditionalAlternativeHeaders;
    /// <summary>
    /// Proves line numbers stay right for an LF-only source with multi-byte UTF-8
    /// characters: the lexer counts bytes, the editor counts lines.
    /// </summary>
    [Test]
    procedure TestLineFeedOnlyAndNonAsciiSource;
    /// <summary>
    /// Proves that with IncludeInterface on, a class in the interface section gets
    /// one separator and its method declarations none.
    /// </summary>
    [Test]
    procedure TestInterfaceClassMembersNotSeparated;
    /// <summary>
    /// Proves the paint-cycle throttle: at most one read per cycle and per interval,
    /// and a check that comes too soon is deferred rather than dropped (dropping it
    /// would leave stale separators after the last keystroke of a burst).
    /// </summary>
    [Test]
    procedure TestRecheckDecision;
    /// <summary>
    /// Proves only Pascal sources (.pas, .dpr, .dpk, any case) are painted, never
    /// include files, forms or backups.
    /// </summary>
    [Test]
    procedure TestPascalSourceFiles;
    /// <summary>Proves the binary-search lookup finds members and rejects neighbours.</summary>
    [Test]
    procedure TestIsSeparatorLine;
    /// <summary>
    /// Proves the automatic colour is darker than a light background and lighter
    /// than a dark one, so the line shows on either theme.
    /// </summary>
    [Test]
    procedure TestAutoColorFollowsTheme;
    /// <summary>
    /// Proves a custom colour is used when it contrasts with the background and
    /// replaced by the automatic colour when it would be invisible.
    /// </summary>
    [Test]
    procedure TestCustomColorContrastProtection;
  end;

implementation

uses
  System.SysUtils, System.UITypes, MethodSeparatorsCore;

/// <summary>Joins ALines with CRLF into the UTF-8 source the scanner takes.</summary>
function Src( const ALines: array of string ): UTF8String;
begin
  Result := UTF8String( string.Join( #13#10, ALines ) + #13#10 );
end;

/// <summary>Formats separator lines as "1,5,9" for whole-set comparison.</summary>
function LinesText( const ALines: TArray<Integer> ): string;
begin
  Result := '';
  for var Line in ALines do
  begin
    if Result <> '' then
      Result := Result + ',';
    Result := Result + IntToStr( Line );
  end;
end;

/// <summary>Scans ALines with the default options and returns the result as text.</summary>
function Scan( const ALines: array of string ): string;
begin
  Result := LinesText( FindSeparatorLines( Src( ALines ), TSeparatorOptions.Default ) );
end;

/// <summary>Scans ALines with AOptions and returns the result as text.</summary>
function ScanWith( const ALines: array of string; const AOptions: TSeparatorOptions ): string;
begin
  Result := LinesText( FindSeparatorLines( Src( ALines ), AOptions ) );
end;

{ TTestMethodSeparatorsCore }

procedure TTestMethodSeparatorsCore.TestRoutinesInImplementationOnly;
begin
  Assert.AreEqual( '7,12', Scan( [
    'unit U;',                       // 1
    'interface',                     // 2
    'procedure A;',                  // 3
    'function B: Integer;',          // 4
    'implementation',                // 5
    '',                              // 6
    'procedure A;',                  // 7
    'begin',                         // 8
    '  if True then begin end;',     // 9
    'end;',                          // 10
    '',                              // 11
    'function B: Integer;',          // 12
    'begin',                         // 13
    '  Result := 1;',                // 14
    'end;',                          // 15
    '',                              // 16
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestLeadingCommentBlockStaysBelowSeparator;
begin
  Assert.AreEqual( '5,10', Scan( [
    'unit U;',                       // 1
    'interface',                     // 2
    'implementation',                // 3
    '',                              // 4
    '/// <summary>A.</summary>',     // 5
    '/// <remarks>More.</remarks>',  // 6
    'procedure A;',                  // 7
    'begin end;',                    // 8
    '',                              // 9
    '{ Multi-line',                  // 10
    '  brace comment }',             // 11
    'procedure B;',                  // 12
    'begin end;',                    // 13
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestClimbStopsAtBlankLineAndTrailingComment;
begin
  Assert.AreEqual( '7,10', Scan( [
    'unit U;',                       // 1
    'interface',                     // 2
    'implementation',                // 3
    '',                              // 4
    '{ TFoo }',                      // 5
    '',                              // 6
    'procedure A;',                  // 7
    'begin',                         // 8
    'end; // A',                     // 9
    'procedure B;',                  // 10
    'begin end;',                    // 11
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestNestedAndAnonymousRoutinesIgnored;
begin
  Assert.AreEqual( '4,20', Scan( [
    'unit U;',                                   // 1
    'interface',                                 // 2
    'implementation',                            // 3
    'procedure Outer;',                          // 4
    '  procedure Inner;',                        // 5
    '  var R: record X: Integer; end;',          // 6
    '  begin',                                   // 7
    '    case R.X of 0: ; end;',                 // 8
    '  end;',                                    // 9
    'var',                                       // 10
    '  P: TProc;',                               // 11
    'begin',                                     // 12
    '  P := procedure',                          // 13
    '    begin',                                 // 14
    '      try Inner; finally end;',             // 15
    '    end;',                                  // 16
    '  Run( 1, procedure begin end );',          // 17
    'end;',                                      // 18
    '',                                          // 19
    'procedure After;',                          // 20
    'begin end;',                                // 21
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestProceduralTypesAreNotRoutines;
begin
  Assert.AreEqual( '9', Scan( [
    'unit U;',                                     // 1
    'interface',                                   // 2
    'implementation',                              // 3
    'type',                                        // 4
    '  TProcA = reference to procedure;',          // 5
    '  TEvent = procedure( Sender: TObject ) of object;',  // 6
    'var',                                         // 7
    '  Callback: function: Integer;',              // 8
    'procedure Real;',                             // 9
    'begin end;',                                  // 10
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestTypeDeclarations;
begin
  Assert.AreEqual( '5,14', Scan( [
    'unit U;',                                     // 1
    'interface',                                   // 2
    'implementation',                              // 3
    'type',                                        // 4
    '  THelper = class( TObject )',                // 5
    '  strict private',                            // 6
    '    FValue: Integer;',                        // 7
    '    class procedure Go; static;',             // 8
    '    procedure Run;',                          // 9
    '  end;',                                      // 10
    '  TFwd = class;',                             // 11
    '  EOops = class( Exception );',               // 12
    '  TRef = class of THelper;',                  // 13
    'procedure THelper.Run;',                      // 14
    'begin end;',                                  // 15
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestGenericRecordConstraintDoesNotOpenBody;
begin
  Assert.AreEqual( '5,9', Scan( [
    'unit U;',                                     // 1
    'interface',                                   // 2
    'implementation',                              // 3
    'type',                                        // 4
    '  TBox<T: record> = record',                  // 5
    '    Value: T;',                               // 6
    '    function Get<X: record, constructor>: X;',  // 7
    '  end;',                                      // 8
    'function TBox<T>.Get<X>: X;',                 // 9
    'begin end;',                                  // 10
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestAttributeMovesSeparatorUp;
begin
  Assert.AreEqual( '5', Scan( [
    'unit U;',                                     // 1
    'interface',                                   // 2
    'implementation',                              // 3
    'type',                                        // 4
    '  [Weak]',                                    // 5
    '  TTagged = class',                           // 6
    '  end;',                                      // 7
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestSectionsAndInitializationStatements;
begin
  Assert.AreEqual( '4,6,10', Scan( [
    'unit U;',                                     // 1
    'interface',                                   // 2
    'implementation',                              // 3
    'procedure A; begin end;',                     // 4
    '',                                            // 5
    'initialization',                              // 6
    '  if True then',                              // 7
    '  begin',                                     // 8
    '  end;',                                      // 9
    'finalization',                                // 10
    '  try A; except end;',                        // 11
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestProgramMainBlock;
begin
  Assert.AreEqual( '5,8', Scan( [
    'program P;',                                  // 1
    'uses',                                        // 2
    '  System.SysUtils in ''x.pas'';',             // 3
    '',                                            // 4
    'procedure Work;',                             // 5
    'begin end;',                                  // 6
    '',                                            // 7
    'begin',                                       // 8
    '  Work;',                                     // 9
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestForwardAndExternalDeclarations;
begin
  Assert.AreEqual( '4,5,6,7', Scan( [
    'unit U;',                                                  // 1
    'interface',                                                // 2
    'implementation',                                           // 3
    'procedure Later; forward;',                                // 4
    'function Beep( F: Cardinal ): Boolean; stdcall; external ''kernel32.dll'' name ''Beep'';',  // 5
    'procedure Now; overload; inline; begin end;',              // 6
    'procedure Later;',                                         // 7
    'begin Now; end;',                                          // 8
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestClassMethodsAndAsm;
begin
  Assert.AreEqual( '4,6,8,15', Scan( [
    'unit U;',                                                      // 1
    'interface',                                                    // 2
    'implementation',                                               // 3
    'class procedure TFoo.Go;',                                     // 4
    'begin end;',                                                   // 5
    'class operator TFoo.Add( const A, B: TFoo ): TFoo;',           // 6
    'begin end;',                                                   // 7
    'function Swap( V: Cardinal ): Cardinal;',                      // 8
    'asm',                                                          // 9
    '  @@case:',                                                    // 10
    '  @@begin:',                                                   // 11
    '  bswap eax',                                                  // 12
    'end;',                                                         // 13
    '',                                                             // 14
    'procedure After;',                                             // 15
    'begin end;',                                                   // 16
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestOptionsSwitchKindsIndependently;
const
  Lines: array[0..14] of string = (
    'unit U;',                       // 1
    'interface',                     // 2
    'type',                          // 3
    '  TPub = class end;',           // 4
    'procedure Pub;',                // 5
    'implementation',                // 6
    'type',                          // 7
    '  TPriv = record end;',         // 8
    'procedure Pub;',                // 9
    'begin end;',                    // 10
    'initialization',                // 11
    '  Pub;',                        // 12
    'finalization',                  // 13
    '  Pub;',                        // 14
    'end.' );                        // 15
var
  Options: TSeparatorOptions;
begin
  Options := TSeparatorOptions.Default;
  Assert.AreEqual( '8,9,11,13', ScanWith( Lines, Options ), 'defaults' );

  Options.IncludeTypes := False;
  Assert.AreEqual( '9,11,13', ScanWith( Lines, Options ), 'types off' );

  Options := TSeparatorOptions.Default;
  Options.IncludeSections := False;
  Assert.AreEqual( '8,9', ScanWith( Lines, Options ), 'sections off' );

  Options := TSeparatorOptions.Default;
  Options.IncludeInterface := True;
  Assert.AreEqual( '4,5,8,9,11,13', ScanWith( Lines, Options ), 'interface on' );
end;

procedure TTestMethodSeparatorsCore.TestMalformedSourceTerminates;
begin
  Assert.AreEqual( '', LinesText( FindSeparatorLines( '', TSeparatorOptions.Default ) ), 'empty' );
  // Truncated mid-body, mid-header and mid-type: the routine already seen is kept.
  Assert.AreEqual( '3', Scan( [ 'unit U; interface implementation', '', 'procedure A;', 'begin', '  if X then begin' ] ) );
  Assert.AreEqual( '1', Scan( [ 'procedure A( X: Integer' ] ) );
  Assert.AreEqual( '', Scan( [ 'unit U; interface type T = class', 'procedure A;' ] ) );
  // Stray closers and keywords out of place.
  Assert.WillNotRaise(
    procedure
    begin
      Scan( [ 'end end ; ) ] > class record interface = procedure class', 'unit', 'begin begin asm' ] );
    end );
end;

procedure TTestMethodSeparatorsCore.TestNestedTypesHelpersAndVariantRecords;
begin
  Assert.AreEqual( '5,13,16,21,25,28', Scan( [
    'unit U;',                                                   // 1
    'interface',                                                 // 2
    'implementation',                                            // 3
    'type',                                                      // 4
    '  TOuter = class',                                          // 5
    '  type',                                                    // 6
    '    TInner = record',                                       // 7
    '      A: Integer;',                                         // 8
    '    end;',                                                  // 9
    '  strict private',                                          // 10
    '    class var FCount: Integer;',                            // 11
    '  end;',                                                    // 12
    '  TStrHelper = record helper for string',                   // 13
    '    function Len: Integer;',                                // 14
    '  end;',                                                    // 15
    '  TVariant = packed record',                                // 16
    '    case Tag: Integer of',                                  // 17
    '      0: ( I: Integer );',                                  // 18
    '      1: ( R: record X, Y: Integer; end );',                // 19
    '  end;',                                                    // 20
    '  IThing = interface',                                      // 21
    '    [''{11111111-2222-3333-4444-555555555555}'']',          // 22
    '    procedure Go;',                                         // 23
    '  end;',                                                    // 24
    '  TObj = object',                                           // 25
    '    procedure M;',                                          // 26
    '  end;',                                                    // 27
    'function TStrHelper.Len: Integer;',                         // 28
    'begin Result := 0; end;',                                   // 29
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestKeywordsInStringsAndCommentsIgnored;
begin
  Assert.AreEqual( '4,11', Scan( [
    'unit U;',                                       // 1
    'interface',                                     // 2
    'implementation',                                // 3
    'procedure A;',                                  // 4
    'begin',                                         // 5
    '  S := ''end; procedure X; begin'';',           // 6
    '  { procedure Fake; begin }',                   // 7
    '  (* end; end; *)',                             // 8
    '  // function Nope; end;',                      // 9
    'end;',                                          // 10
    'procedure B;',                                  // 11
    'begin end;',                                    // 12
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestConditionalAlternativeHeaders;
begin
  Assert.AreEqual( '4,10', Scan( [
    'unit U;',                                       // 1
    'interface',                                     // 2
    'implementation',                                // 3
    '{$IFDEF WIN64}',                                // 4
    'procedure A( X: Int64 );',                      // 5
    '{$ELSE}',                                       // 6
    'procedure A( X: Integer );',                    // 7
    '{$ENDIF}',                                      // 8
    'begin end;',                                    // 9
    'procedure B;',                                  // 10
    'begin end;',                                    // 11
    'end.' ] ) );
end;

procedure TTestMethodSeparatorsCore.TestLineFeedOnlyAndNonAsciiSource;
var
  Source: UTF8String;
begin
  Source := UTF8String( string.Join( #10, [
    'unit U;',                                       // 1
    'interface',                                     // 2
    'implementation',                                // 3
    '// Grüße – naïve 日本語',                        // 4
    '',                                              // 5
    'procedure A;',                                  // 6
    'begin S := ''é€''; end;',                       // 7
    'procedure B;',                                  // 8
    'begin end;',                                    // 9
    'end.' ] ) );
  Assert.AreEqual( '6,8', LinesText( FindSeparatorLines( Source, TSeparatorOptions.Default ) ) );
end;

procedure TTestMethodSeparatorsCore.TestInterfaceClassMembersNotSeparated;
var
  Options: TSeparatorOptions;
begin
  Options := TSeparatorOptions.Default;
  Options.IncludeInterface := True;
  Assert.AreEqual( '4,8', ScanWith( [
    'unit U;',                                       // 1
    'interface',                                     // 2
    'type',                                          // 3
    '  TFoo = class',                                // 4
    '    procedure A;',                              // 5
    '    function B: Integer;',                      // 6
    '  end;',                                        // 7
    'procedure Free;',                               // 8
    'implementation',                                // 9
    'end.' ], Options ) );
end;

procedure TTestMethodSeparatorsCore.TestRecheckDecision;
const
  Interval = 250;
begin
  Assert.AreEqual( Ord( raNone ), Ord( DecideRecheck( True, 10000, 0, Interval ) ), 'already decided this cycle' );
  Assert.AreEqual( Ord( raRefresh ), Ord( DecideRecheck( False, 10000, 9000, Interval ) ), 'interval elapsed' );
  Assert.AreEqual( Ord( raRefresh ), Ord( DecideRecheck( False, 10250, 10000, Interval ) ), 'exactly the interval' );
  Assert.AreEqual( Ord( raDefer ), Ord( DecideRecheck( False, 10249, 10000, Interval ) ), 'too soon is deferred' );
  Assert.AreEqual( Ord( raDefer ), Ord( DecideRecheck( False, 10000, 10000, Interval ) ), 'same tick is deferred' );
  Assert.AreEqual( Ord( raRefresh ), Ord( DecideRecheck( False, 5, 10000, Interval ) ), 'tick went backwards' );
end;

procedure TTestMethodSeparatorsCore.TestPascalSourceFiles;
begin
  Assert.IsTrue( IsPascalSourceFile( 'C:\src\Unit1.pas' ), '.pas' );
  Assert.IsTrue( IsPascalSourceFile( 'C:\src\UNIT1.PAS' ), '.PAS' );
  Assert.IsTrue( IsPascalSourceFile( 'Project1.dpr' ), '.dpr' );
  Assert.IsTrue( IsPascalSourceFile( 'Package1.dpk' ), '.dpk' );
  Assert.IsFalse( IsPascalSourceFile( 'Defines.inc' ), '.inc' );
  Assert.IsFalse( IsPascalSourceFile( 'Unit1.dfm' ), '.dfm' );
  Assert.IsFalse( IsPascalSourceFile( 'Unit1.pas.bak' ), '.bak' );
  Assert.IsFalse( IsPascalSourceFile( '' ), 'empty' );
end;

procedure TTestMethodSeparatorsCore.TestIsSeparatorLine;
var
  Lines: TArray<Integer>;
begin
  Lines := [3, 10, 42];
  Assert.IsTrue( IsSeparatorLine( Lines, 3 ), '3' );
  Assert.IsTrue( IsSeparatorLine( Lines, 42 ), '42' );
  Assert.IsFalse( IsSeparatorLine( Lines, 4 ), '4' );
  Assert.IsFalse( IsSeparatorLine( Lines, 41 ), '41' );
  Assert.IsFalse( IsSeparatorLine( nil, 1 ), 'empty' );
end;

procedure TTestMethodSeparatorsCore.TestAutoColorFollowsTheme;
const
  LightEditor = TColor( $00FFFFFF );
  DarkEditor = TColor( $00282828 );
begin
  Assert.AreEqual( 255, ColorLuminance( LightEditor ), 'white luminance' );
  Assert.AreEqual( 0, ColorLuminance( TColors.Black ), 'black luminance' );
  Assert.IsTrue( ColorLuminance( AutoSeparatorColor( LightEditor ) ) < ColorLuminance( LightEditor ) - MinSeparatorContrast,
    'light theme: separator is clearly darker' );
  Assert.IsTrue( ColorLuminance( AutoSeparatorColor( DarkEditor ) ) > ColorLuminance( DarkEditor ) + MinSeparatorContrast,
    'dark theme: separator is clearly lighter' );
end;

procedure TTestMethodSeparatorsCore.TestCustomColorContrastProtection;
const
  DarkEditor = TColor( $00282828 );
  Orange = TColor( $000080FF );
  NearlyBackground = TColor( $00303030 );
begin
  Assert.AreEqual( Integer( Orange ), Integer( ResolveSeparatorColor( DarkEditor, Orange, True ) ), 'contrasting custom colour is used' );
  Assert.AreEqual( Integer( AutoSeparatorColor( DarkEditor ) ), Integer( ResolveSeparatorColor( DarkEditor, NearlyBackground, True ) ),
    'invisible custom colour falls back to automatic' );
  Assert.AreEqual( Integer( AutoSeparatorColor( DarkEditor ) ), Integer( ResolveSeparatorColor( DarkEditor, Orange, False ) ),
    'custom colour ignored when not chosen' );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestMethodSeparatorsCore );

end.
