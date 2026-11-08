unit TestUnusedUnitCoreDUnitX;

/// <summary>
/// DUnitX fixture for <c>UnusedUnitCore</c>, the analyser behind the Unused Unit Detector.  A
/// false "unused" leads the user to delete a uses entry the program needs - silently, when the
/// unit only registers something in its initialization section - so the analyser must err on
/// "used".  One case proves a genuinely unused unit IS reported (the detector used to report
/// nothing at all); every other case is a way a unit is needed without being named in the code.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture for the Unused Unit Detector's analyser.</summary>
  [ TestFixture ]
  TTestUnusedUnitCore = class
  public
    /// <summary>
    /// Proves a used unit none of whose declarations the code refers to is reported, on the 1-based
    /// line of its uses entry.  The detector used to find the unit's own name in the uses clause and
    /// so never reported anything.
    /// </summary>
    [ Test ]
    procedure TestUnreferencedUnitIsReported;
    /// <summary>Proves a unit whose routine the code calls is not reported.</summary>
    [ Test ]
    procedure TestReferencedUnitIsNotReported;
    /// <summary>Proves a unit with an initialization section (side effects: class registration, drivers) is never reported.</summary>
    [ Test ]
    procedure TestUnitWithInitializationIsNotReported;
    /// <summary>Proves a unit whose source cannot be found is never reported: unknown means "used".</summary>
    [ Test ]
    procedure TestUnresolvedUnitIsNotReported;
    /// <summary>Proves a uses entry inside a conditional-compilation block is never reported (the other platform or configuration may need it).</summary>
    [ Test ]
    procedure TestConditionalUsesEntryIsNotReported;
    /// <summary>Proves a unit that declares a class streamed by the unit's form (.dfm) is not reported.</summary>
    [ Test ]
    procedure TestUnitDeclaringFormStreamedClassIsNotReported;
    /// <summary>Proves a reference inside a comment or a string does not count as a use.</summary>
    [ Test ]
    procedure TestReferenceInCommentOrStringDoesNotCount;
    /// <summary>Proves a unit referred to by a qualified name (<c>UnitB.Thing</c>) is not reported.</summary>
    [ Test ]
    procedure TestQualifiedReferenceCounts;
    /// <summary>
    /// Proves a nested section inside a class body (<c>const</c>, <c>class var</c>) does not leak out:
    /// an enumeration declared after the class is still collected, so a unit used only for one of its
    /// values is not reported.
    /// </summary>
    [ Test ]
    procedure TestNestedSectionDoesNotHideLaterEnumeration;
    /// <summary>Proves a used unit with an old-style <c>begin ... end.</c> initialization block is kept.</summary>
    [ Test ]
    procedure TestOldStyleInitializationBlockKeepsUnit;
    /// <summary>Proves a design-time unit declaring <c>procedure Register;</c> is kept (Register lexes as a keyword).</summary>
    [ Test ]
    procedure TestRegisterProcedureKeepsUnit;
    /// <summary>Proves a used unit that links a resource or object file (<c>{$R}</c>, <c>{$L}</c>) is kept.</summary>
    [ Test ]
    procedure TestLinkedResourceKeepsUnit;
    /// <summary>Proves the I/O switch <c>{$I-}</c> is not an include file: the unit is still analysed.</summary>
    [ Test ]
    procedure TestIoSwitchIsNotAnInclude;
    /// <summary>Proves a name declared with an <c>&amp;</c> escape matches its unescaped use.</summary>
    [ Test ]
    procedure TestEscapedNameMatchesPlainUse;
    /// <summary>
    /// Proves a unit declaring a class helper is kept, while a routine merely named "Helper" (the
    /// word lexes as a keyword) does not make a unit look like a helper unit.
    /// </summary>
    [ Test ]
    procedure TestClassHelperKeepsUnitButRoutineNamedHelperDoesNot;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.Generics.Collections, UnusedUnitCore;

const
  CRLF              = #13#10;

  /// <summary>A used unit exporting one routine and one class.</summary>
  UnitBSource       =
    'unit UnitB;' + CRLF +
    'interface' + CRLF +
    'type' + CRLF +
    '  TBWidget = class' + CRLF +
    '  end;' + CRLF +
    'procedure BRoutine;' + CRLF +
    'implementation' + CRLF +
    'procedure BRoutine;' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    'end.';

/// <summary>Analyses AContent with a resolver that knows only the units in AKnownUnits.</summary>
/// <param name="AContent">The analysed unit's source.</param>
/// <param name="AKnownUnits">Unit name and source pairs the resolver can find.</param>
/// <param name="ADfmText">The analysed unit's form text; empty for none.</param>
/// <param name="AItems">Receives the reported entries.</param>
/// <returns>The reported unit names, comma-separated.</returns>
function Analyse( const AContent: string; const AKnownUnits: array of string; const ADfmText: string;
  out AItems: TArray<TUnusedUnitInfo> ): string;
begin
  var oKnown        := TDictionary<string, string>.Create;
  var oAnalyzer     := TUnitAnalyzer.Create;
  try
    var i           := 0;
    while i < High( AKnownUnits ) do
    begin
      oKnown.Add( UpperCase( AKnownUnits[ i ] ), AKnownUnits[ i + 1 ] );
      Inc( i, 2 );
    end;

    oAnalyzer.OnResolveUnit :=
      function( const UnitName: string; out Source: string ): Boolean
      begin
        Result      := oKnown.TryGetValue( UpperCase( UnitName ), Source );
      end;

    Assert.IsTrue( oAnalyzer.AnalyseSource( 'C:\p\UnitA.pas', AContent, ADfmText, AItems ), 'analysis ran' );
    oAnalyzer.OnResolveUnit := nil;
  finally
    oAnalyzer.Free;
    oKnown.Free;
  end;

  Result            := '';
  for var rItem in AItems do
  begin
    if Result <> '' then
      Result        := Result + ', ';
    Result          := Result + rItem.UnusedUnit;
  end;
end;

/// <summary>Shorthand for <see cref="Analyse"/> with UnitB known and no form, returning only the names.</summary>
/// <param name="AContent">The analysed unit's source.</param>
/// <returns>The reported unit names, comma-separated.</returns>
function UnusedNames( const AContent: string ): string;
begin
  var aItems: TArray<TUnusedUnitInfo>;
  Result            := Analyse( AContent, [ 'UnitB', UnitBSource ], '', aItems );
end;

{ TTestUnusedUnitCore }

procedure TTestUnusedUnitCore.TestUnreferencedUnitIsReported;
begin
  var sUnitA        :=
    'unit UnitA;' + CRLF + // 1
    'interface' + CRLF + // 2
    'uses' + CRLF + // 3
    '  System.SysUtils,' + CRLF + // 4
    '  UnitB;' + CRLF + // 5
    'implementation' + CRLF +
    'procedure Local;' + CRLF +
    'begin' + CRLF +
    '  FreeAndNil( X );' + CRLF +
    'end;' + CRLF +
    'end.';

  var aItems: TArray<TUnusedUnitInfo>;
  Assert.AreEqual( 'UnitB', Analyse( sUnitA, [ 'UnitB', UnitBSource ], '', aItems ),
    'UnitB is resolved and nothing it declares is used; System.SysUtils is unresolved, so not reported' );
  Assert.AreEqual<Integer>( 5, aItems[ 0 ].LineNumber, 'reported on the 1-based line of its uses entry' );
  Assert.IsTrue( aItems[ 0 ].IsInterface, 'it is an interface uses entry' );
end;

procedure TTestUnusedUnitCore.TestReferencedUnitIsNotReported;
begin
  Assert.AreEqual( '', UnusedNames(
      'unit UnitA;' + CRLF +
      'interface' + CRLF +
      'implementation' + CRLF +
      'uses UnitB;' + CRLF +
      'procedure Local;' + CRLF +
      'begin' + CRLF +
      '  BRoutine;' + CRLF +
      'end;' + CRLF +
      'end.' ), 'BRoutine is called' );
end;

procedure TTestUnusedUnitCore.TestUnitWithInitializationIsNotReported;
begin
  var sRegistering  :=
    'unit Registering;' + CRLF +
    'interface' + CRLF +
    'type TPlugin = class end;' + CRLF +
    'implementation' + CRLF +
    'initialization' + CRLF +
    '  RegisterClass( TPlugin );' + CRLF +
    'end.';

  var aItems: TArray<TUnusedUnitInfo>;
  Assert.AreEqual( '', Analyse(
      'unit UnitA;' + CRLF +
      'interface' + CRLF +
      'uses Registering;' + CRLF +
      'implementation' + CRLF +
      'end.', [ 'Registering', sRegistering ], '', aItems ),
    'a unit with an initialization section is kept for its side effects' );
end;

procedure TTestUnusedUnitCore.TestUnresolvedUnitIsNotReported;
begin
  Assert.AreEqual( '', UnusedNames(
      'unit UnitA;' + CRLF +
      'interface' + CRLF +
      'uses Vcl.Imaging.pngimage;' + CRLF +
      'implementation' + CRLF +
      'end.' ), 'no source for Vcl.Imaging.pngimage: unknown means used' );
end;

procedure TTestUnusedUnitCore.TestConditionalUsesEntryIsNotReported;
begin
  Assert.AreEqual( '', UnusedNames(
      'unit UnitA;' + CRLF +
      'interface' + CRLF +
      'uses' + CRLF +
      '  {$IFDEF MSWINDOWS}' + CRLF +
      '  UnitB,' + CRLF +
      '  {$ENDIF}' + CRLF +
      '  System.SysUtils;' + CRLF +
      'implementation' + CRLF +
      'end.' ), 'an entry inside $IFDEF is never reported' );
end;

procedure TTestUnusedUnitCore.TestUnitDeclaringFormStreamedClassIsNotReported;
begin
  var aItems: TArray<TUnusedUnitInfo>;
  Assert.AreEqual( '', Analyse(
      'unit UnitA;' + CRLF +
      'interface' + CRLF +
      'uses Vcl.Forms, UnitB;' + CRLF +
      'type TFormA = class( TForm ) end;' + CRLF +
      'implementation' + CRLF +
      '{$R *.dfm}' + CRLF +
      'end.', [ 'UnitB', UnitBSource ],
      'object FormA: TFormA' + CRLF +
      '  object Widget1: TBWidget' + CRLF +
      '  end' + CRLF +
      'end', aItems ),
    'the form streams a TBWidget, which UnitB declares' );
end;

procedure TTestUnusedUnitCore.TestReferenceInCommentOrStringDoesNotCount;
begin
  Assert.AreEqual( 'UnitB', UnusedNames(
      'unit UnitA;' + CRLF +
      'interface' + CRLF +
      'implementation' + CRLF +
      'uses UnitB;' + CRLF +
      '{ BRoutine used to be called here }' + CRLF +
      'const S = ''BRoutine'';' + CRLF +
      'end.' ), 'mentions in a comment and a string are not uses' );
end;

procedure TTestUnusedUnitCore.TestQualifiedReferenceCounts;
begin
  Assert.AreEqual( '', UnusedNames(
      'unit UnitA;' + CRLF +
      'interface' + CRLF +
      'implementation' + CRLF +
      'uses UnitB;' + CRLF +
      'procedure Local;' + CRLF +
      'begin' + CRLF +
      '  UnitB.BRoutine;' + CRLF +
      'end;' + CRLF +
      'end.' ), 'a qualified call uses the unit' );
end;

/// <summary>Analyses a unit that uses only UnitC and calls ACall, with UnitC's source given.</summary>
/// <param name="AUnitCSource">UnitC's source.</param>
/// <param name="ACall">A statement placed in UnitA's implementation.</param>
/// <returns>The reported unit names, comma-separated.</returns>
function AnalyseWithUnitC( const AUnitCSource, ACall: string ): string;
begin
  var aItems: TArray<TUnusedUnitInfo>;
  Result            := Analyse(
    'unit UnitA;' + CRLF +
    'interface' + CRLF +
    'implementation' + CRLF +
    'uses UnitC;' + CRLF +
    'procedure Local;' + CRLF +
    'begin' + CRLF +
    '  ' + ACall + CRLF +
    'end;' + CRLF +
    'end.', [ 'UnitC', AUnitCSource ], '', aItems );
end;

procedure TTestUnusedUnitCore.TestNestedSectionDoesNotHideLaterEnumeration;
begin
  var sUnitC        :=
    'unit UnitC;' + CRLF +
    'interface' + CRLF +
    'type' + CRLF +
    '  THolder = class' + CRLF +
    '  const' + CRLF +
    '    Limit = 10;' + CRLF +
    '  class var Count: Integer;' + CRLF +
    '  end;' + CRLF +
    '  TShade = ( shLight, shDark );' + CRLF +
    'implementation' + CRLF +
    'end.';
  Assert.AreEqual( '', AnalyseWithUnitC( sUnitC, 'X := shDark;' ), 'shDark comes from UnitC' );
end;

procedure TTestUnusedUnitCore.TestOldStyleInitializationBlockKeepsUnit;
begin
  var sUnitC        :=
    'unit UnitC;' + CRLF +
    'interface' + CRLF +
    'procedure Helper;' + CRLF +
    'implementation' + CRLF +
    'procedure Helper;' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    'begin' + CRLF +
    '  RegisterSomething;' + CRLF +
    'end.';
  Assert.AreEqual( '', AnalyseWithUnitC( sUnitC, 'X := 1;' ), 'the begin..end. block runs at start-up' );
end;

procedure TTestUnusedUnitCore.TestRegisterProcedureKeepsUnit;
begin
  var sUnitC        :=
    'unit UnitC;' + CRLF +
    'interface' + CRLF +
    'procedure Helper;' + CRLF +
    'procedure Register;' + CRLF +
    'implementation' + CRLF +
    'procedure Register;' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    'end.';
  Assert.AreEqual( '', AnalyseWithUnitC( sUnitC, 'X := 1;' ), 'a registration unit is kept' );
end;

procedure TTestUnusedUnitCore.TestLinkedResourceKeepsUnit;
begin
  var sUnitC        :=
    'unit UnitC;' + CRLF +
    'interface' + CRLF +
    'procedure Helper;' + CRLF +
    'implementation' + CRLF +
    '{$R UnitC.res}' + CRLF +
    'procedure Helper;' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    'end.';
  Assert.AreEqual( '', AnalyseWithUnitC( sUnitC, 'X := 1;' ), 'a unit that links a resource is kept' );
  Assert.AreEqual( '', AnalyseWithUnitC( StringReplace( sUnitC, '{$R UnitC.res}', '{$L helper.obj}', [ ] ), 'X := 1;' ),
    'a unit that links an object file is kept' );
end;

procedure TTestUnusedUnitCore.TestIoSwitchIsNotAnInclude;
begin
  Assert.AreEqual( 'UnitB', UnusedNames(
      'unit UnitA;' + CRLF +
      'interface' + CRLF +
      'implementation' + CRLF +
      'uses UnitB;' + CRLF +
      '{$I-}' + CRLF +
      'procedure Local;' + CRLF +
      'begin' + CRLF +
      'end;' + CRLF +
      '{$I+}' + CRLF +
      'end.' ), '{$I-} / {$I+} switch I/O checking; UnitB is still judged unused' );
end;

procedure TTestUnusedUnitCore.TestEscapedNameMatchesPlainUse;
begin
  var sUnitC        :=
    'unit UnitC;' + CRLF +
    'interface' + CRLF +
    'procedure &Sample;' + CRLF +
    'implementation' + CRLF +
    'procedure &Sample;' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    'end.';
  Assert.AreEqual( '', AnalyseWithUnitC( sUnitC, 'Sample;' ), '&Sample is the routine Sample' );
end;

procedure TTestUnusedUnitCore.TestClassHelperKeepsUnitButRoutineNamedHelperDoesNot;
begin
  var sHelperUnit   :=
    'unit UnitC;' + CRLF +
    'interface' + CRLF +
    'type' + CRLF +
    '  TStringsHelper = class helper for TStrings' + CRLF +
    '    function IsBlank: Boolean;' + CRLF +
    '  end;' + CRLF +
    'implementation' + CRLF +
    'function TStringsHelper.IsBlank: Boolean;' + CRLF +
    'begin' + CRLF +
    '  Result := True;' + CRLF +
    'end;' + CRLF +
    'end.';
  Assert.AreEqual( '', AnalyseWithUnitC( sHelperUnit, 'X := 1;' ), 'a helper unit is kept' );

  var sPlainUnit    :=
    'unit UnitC;' + CRLF +
    'interface' + CRLF +
    'procedure Helper;' + CRLF +
    'implementation' + CRLF +
    'procedure Helper;' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    'end.';
  Assert.AreEqual( 'UnitC', AnalyseWithUnitC( sPlainUnit, 'X := 1;' ), 'a routine named Helper is no helper' );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestUnusedUnitCore );

end.

