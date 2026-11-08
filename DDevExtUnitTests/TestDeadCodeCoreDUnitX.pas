unit TestDeadCodeCoreDUnitX;

/// <summary>
/// DUnitX fixture for <c>DeadCodeCore</c>, the analysis core of the Dead Code Detector.  Each case
/// feeds one or two small units through the collect and reference passes and asserts which
/// symbols are reported.  The detector's danger is a false "never referenced": a user who trusts
/// it deletes code that something still uses, so most cases prove a used symbol is NOT reported.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture for the Dead Code Detector's analysis core.</summary>
  [ TestFixture ]
  TTestDeadCodeCore = class
  public
    /// <summary>
    /// Proves a routine declared in a unit's interface and called only from another unit is not
    /// reported.  The implementation header used to be collected as a second, unit-scoped symbol
    /// that only a call in the same file could mark as used.
    /// </summary>
    [ Test ]
    procedure TestInterfaceRoutineUsedFromOtherUnitIsNotReported;
    /// <summary>
    /// Proves a protected field used only by a descendant class in another unit is not reported:
    /// protected members are visible to descendants anywhere, not only in their own unit.
    /// </summary>
    [ Test ]
    procedure TestProtectedMemberUsedByDescendantInOtherUnitIsNotReported;
    /// <summary>
    /// Proves a private field read and written only by a property of a class declared in the
    /// interface section is not reported; references in the interface used to be ignored.
    /// </summary>
    [ Test ]
    procedure TestFieldUsedOnlyByInterfacePropertyIsNotReported;
    /// <summary>
    /// Proves the analyser still finds real dead code - an implementation-only routine nobody
    /// calls - and reports it on its 1-based line (it used to report the 0-based token line, so
    /// the list and navigation were one line off).
    /// </summary>
    [ Test ]
    procedure TestUnusedImplementationRoutineIsReportedOnOneBasedLine;
    /// <summary>
    /// Proves that with "Check procedures" off, a private method's parameter is not collected as a
    /// field, and that a private property is never collected as a field.
    /// </summary>
    [ Test ]
    procedure TestParametersAndPropertiesAreNotFields;
    /// <summary>
    /// Proves a private method nobody calls is reported while one that is called is not: the name
    /// in the method's own implementation header (<c>procedure TThing.Unused;</c>) used to count as
    /// a reference, so no method with a body was ever reported.
    /// </summary>
    [ Test ]
    procedure TestUnusedPrivateMethodIsReported;
    /// <summary>Proves a message handler (<c>message WM_SIZE</c>), which the VCL calls by message number, is never reported.</summary>
    [ Test ]
    procedure TestMessageHandlerIsNotReported;
    /// <summary>Proves a field carrying an attribute (used through RTTI) is never reported.</summary>
    [ Test ]
    procedure TestAttributedFieldIsNotReported;
    /// <summary>Proves a reference inside an include file, scanned on behalf of its unit, marks a unit-local routine as used.</summary>
    [ Test ]
    procedure TestReferenceInIncludeFileCounts;
    /// <summary>Proves that, when some units could not be read, only private and unit-local symbols are reported.</summary>
    [ Test ]
    procedure TestLocalOnlyReportWhenUnitsSkipped;
    /// <summary>Proves a routine declared with an &amp; escape (<c>&amp;Sample</c>) is matched by its unescaped call.</summary>
    [ Test ]
    procedure TestEscapedNameMatchesPlainCall;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.Generics.Collections, DeadCodeCore;

/// <summary>Runs both passes over the given units and returns the reported element names, comma-separated.</summary>
/// <param name="AUnits">File name and source pairs: name0, source0, name1, source1, ...</param>
/// <param name="ACheckProcedures">Whether procedures are checked.</param>
/// <param name="AItems">Receives the reported items.</param>
/// <returns>The reported element names in report order, joined with ", ".</returns>
function RunAnalysis( const AUnits: array of string; ACheckProcedures: Boolean; out AItems: TArray<TDeadCodeItem> ): string;
begin
  var oAnalyzer     := TDeadCodeAnalyzer.Create;
  try
    oAnalyzer.CheckProcedures := ACheckProcedures;

    var i           := 0;
    while i < High( AUnits ) do
    begin
      oAnalyzer.CollectSymbols( AUnits[ i ], UTF8String( AUnits[ i + 1 ] ) );
      Inc( i, 2 );
    end;

    i               := 0;
    while i < High( AUnits ) do
    begin
      oAnalyzer.ScanForReferences( AUnits[ i ], UTF8String( AUnits[ i + 1 ] ) );
      Inc( i, 2 );
    end;

    AItems          := oAnalyzer.GetDeadCode;
  finally
    oAnalyzer.Free;
  end;

  Result            := '';
  for var rItem in AItems do
  begin
    if Result <> '' then
      Result        := Result + ', ';
    Result          := Result + rItem.ElementName;
  end;
end;

/// <summary>Shorthand for <see cref="RunAnalysis"/> with procedures checked, returning only the names.</summary>
/// <param name="AUnits">File name and source pairs.</param>
/// <returns>The reported element names, comma-separated.</returns>
function DeadNames( const AUnits: array of string ): string;
begin
  var aItems: TArray<TDeadCodeItem>;
  Result            := RunAnalysis( AUnits, True, aItems );
end;

const
  CRLF              = #13#10;

  { TTestDeadCodeCore }

procedure TTestDeadCodeCore.TestInterfaceRoutineUsedFromOtherUnitIsNotReported;
begin
  var sUnitA        :=
    'unit UnitA;' + CRLF +
    'interface' + CRLF +
    'procedure SharedHelper;' + CRLF +
    'const' + CRLF +
    '  Limit = 10;' + CRLF +
    'implementation' + CRLF +
    'procedure SharedHelper;' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    'end.';
  var sUnitB        :=
    'unit UnitB;' + CRLF +
    'interface' + CRLF +
    'implementation' + CRLF +
    'uses UnitA;' + CRLF +
    'procedure Caller;' + CRLF +
    'begin' + CRLF +
    '  SharedHelper;' + CRLF +
    'end;' + CRLF +
    'initialization' + CRLF +
    '  Caller;' + CRLF +
    'end.';

  Assert.AreEqual( '', DeadNames( [ 'C:\p\UnitA.pas', sUnitA, 'C:\p\UnitB.pas', sUnitB ] ),
    'SharedHelper is called from UnitB, so nothing is dead' );
end;

procedure TTestDeadCodeCore.TestProtectedMemberUsedByDescendantInOtherUnitIsNotReported;
begin
  var sBase         :=
    'unit BaseUnit;' + CRLF +
    'interface' + CRLF +
    'type' + CRLF +
    '  TBase = class' + CRLF +
    '  protected' + CRLF +
    '    FWorkCount: Integer;' + CRLF +
    '  end;' + CRLF +
    'implementation' + CRLF +
    'end.';
  var sChild        :=
    'unit ChildUnit;' + CRLF +
    'interface' + CRLF +
    'uses BaseUnit;' + CRLF +
    'type' + CRLF +
    '  TChild = class( TBase )' + CRLF +
    '  public' + CRLF +
    '    procedure Run;' + CRLF +
    '  end;' + CRLF +
    'implementation' + CRLF +
    'procedure TChild.Run;' + CRLF +
    'begin' + CRLF +
    '  Inc( FWorkCount );' + CRLF +
    'end;' + CRLF +
    'end.';

  var sDead         := DeadNames( [ 'C:\p\BaseUnit.pas', sBase, 'C:\p\ChildUnit.pas', sChild ] );
  Assert.IsFalse( sDead.Contains( 'FWorkCount' ), 'protected FWorkCount is used by TChild in another unit; reported: ' + sDead );
end;

procedure TTestDeadCodeCore.TestFieldUsedOnlyByInterfacePropertyIsNotReported;
begin
  var sUnit         :=
    'unit PropUnit;' + CRLF +
    'interface' + CRLF +
    'type' + CRLF +
    '  TThing = class' + CRLF +
    '  private' + CRLF +
    '    FCaption: string;' + CRLF +
    '  public' + CRLF +
    '    property Caption: string read FCaption write FCaption;' + CRLF +
    '  end;' + CRLF +
    'implementation' + CRLF +
    'end.';

  var sDead         := DeadNames( [ 'C:\p\PropUnit.pas', sUnit ] );
  Assert.IsFalse( sDead.Contains( 'FCaption' ), 'FCaption is read and written by the Caption property; reported: ' + sDead );
end;

procedure TTestDeadCodeCore.TestUnusedImplementationRoutineIsReportedOnOneBasedLine;
begin
  var sUnit         :=
    'unit DeadUnit;' + CRLF + // line 1
    'interface' + CRLF + // line 2
    'implementation' + CRLF + // line 3
    'procedure NobodyCallsMe;' + CRLF + // line 4
    'begin' + CRLF +
    'end;' + CRLF +
    'end.';

  var aItems: TArray<TDeadCodeItem>;
  Assert.AreEqual( 'NobodyCallsMe', RunAnalysis( [ 'C:\p\DeadUnit.pas', sUnit ], True, aItems ),
    'an implementation-only routine nobody calls is dead' );
  Assert.AreEqual<Integer>( 4, aItems[ 0 ].Line, 'the declaration is reported on its 1-based line' );
end;

procedure TTestDeadCodeCore.TestParametersAndPropertiesAreNotFields;
begin
  var sUnit         :=
    'unit FieldUnit;' + CRLF +
    'interface' + CRLF +
    'type' + CRLF +
    '  TThing = class' + CRLF +
    '  private' + CRLF +
    '    FValue: Integer;' + CRLF +
    '    procedure SetValue( AValue: Integer );' + CRLF +
    '    property Value: Integer read FValue write SetValue;' + CRLF +
    '  end;' + CRLF +
    'implementation' + CRLF +
    'end.';

  var aItems: TArray<TDeadCodeItem>;
  var sDead         := RunAnalysis( [ 'C:\p\FieldUnit.pas', sUnit ], False, aItems );
  Assert.IsFalse( sDead.Contains( 'AValue' ), 'a method parameter is not a field; reported: ' + sDead );
  Assert.IsFalse( sDead.Contains( 'TThing.Value' ), 'a property is not a field; reported: ' + sDead );
end;

procedure TTestDeadCodeCore.TestUnusedPrivateMethodIsReported;
begin
  var sUnit         :=
    'unit MethodUnit;' + CRLF +
    'interface' + CRLF +
    'type' + CRLF +
    '  TThing = class' + CRLF +
    '  private' + CRLF +
    '    procedure Used;' + CRLF +
    '    procedure Unused;' + CRLF +
    '  public' + CRLF +
    '    procedure Run;' + CRLF +
    '  end;' + CRLF +
    'implementation' + CRLF +
    'procedure TThing.Used;' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    'procedure TThing.Unused;' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    'procedure TThing.Run;' + CRLF +
    'begin' + CRLF +
    '  Used;' + CRLF +
    'end;' + CRLF +
    'initialization' + CRLF +
    '  TThing.Create.Run;' + CRLF +
    'end.';

  var sDead         := DeadNames( [ 'C:\p\MethodUnit.pas', sUnit ] );
  Assert.IsTrue( sDead.Contains( 'TThing.Unused' ), 'Unused is never called; reported: ' + sDead );
  Assert.IsFalse( sDead.Contains( 'TThing.Used' ), 'Used is called by Run; reported: ' + sDead );
  Assert.IsFalse( sDead.Contains( 'TThing.Run' ), 'Run is called at start-up; reported: ' + sDead );
end;

procedure TTestDeadCodeCore.TestMessageHandlerIsNotReported;
begin
  var sUnit         :=
    'unit MsgUnit;' + CRLF +
    'interface' + CRLF +
    'type' + CRLF +
    '  TPanelEx = class( TPanel )' + CRLF +
    '  private' + CRLF +
    '    procedure WMSize( var Msg: TWMSize ); message WM_SIZE;' + CRLF +
    '  end;' + CRLF +
    'implementation' + CRLF +
    'procedure TPanelEx.WMSize( var Msg: TWMSize );' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    'end.';

  var sDead         := DeadNames( [ 'C:\p\MsgUnit.pas', sUnit ] );
  Assert.IsFalse( sDead.Contains( 'WMSize' ), 'a message handler is called by message number; reported: ' + sDead );
end;

procedure TTestDeadCodeCore.TestAttributedFieldIsNotReported;
begin
  var sUnit         :=
    'unit AttrUnit;' + CRLF +
    'interface' + CRLF +
    'type' + CRLF +
    '  TThing = class' + CRLF +
    '  private' + CRLF +
    '    [Weak] FOwner: TObject;' + CRLF +
    '    [JSONName( ''id'' )]' + CRLF +
    '    FId: Integer;' + CRLF +
    '    FPlain: Integer;' + CRLF +
    '  end;' + CRLF +
    'implementation' + CRLF +
    'end.';

  var sDead         := DeadNames( [ 'C:\p\AttrUnit.pas', sUnit ] );
  Assert.IsFalse( sDead.Contains( 'FOwner' ), 'an attributed field is used through RTTI; reported: ' + sDead );
  Assert.IsFalse( sDead.Contains( 'FId' ), 'an attribute on the line before counts too; reported: ' + sDead );
  Assert.IsTrue( sDead.Contains( 'FPlain' ), 'a plain unused field is still reported; reported: ' + sDead );
end;

procedure TTestDeadCodeCore.TestReferenceInIncludeFileCounts;
begin
  var sUnit         :=
    'unit IncUnit;' + CRLF +
    'interface' + CRLF +
    'implementation' + CRLF +
    'procedure CalledFromInclude;' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    '{$I IncUnit.inc}' + CRLF +
    'end.';
  var sInclude      := 'initialization' + CRLF + '  CalledFromInclude;' + CRLF;

  Assert.AreEqual( 'IncUnit.inc', string.Join( ',', ExtractIncludeFileNames( UTF8String( sUnit ) ) ),
    'the include file name is found' );

  var oAnalyzer     := TDeadCodeAnalyzer.Create;
  try
    oAnalyzer.CollectSymbols( 'C:\p\IncUnit.pas', UTF8String( sUnit ) );
    oAnalyzer.ScanForReferences( 'C:\p\IncUnit.pas', UTF8String( sUnit ) );
    oAnalyzer.ScanForReferences( 'C:\p\IncUnit.inc', UTF8String( sInclude ), 'C:\p\IncUnit.pas' );
    Assert.AreEqual<Integer>( 0, Length( oAnalyzer.GetDeadCode ), 'the include calls the unit-local routine' );
  finally
    oAnalyzer.Free;
  end;
end;

procedure TTestDeadCodeCore.TestLocalOnlyReportWhenUnitsSkipped;
begin
  var sUnit         :=
    'unit MixUnit;' + CRLF +
    'interface' + CRLF +
    'procedure PublicHelper;' + CRLF +
    'implementation' + CRLF +
    'procedure PublicHelper;' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    'procedure LocalHelper;' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    'end.';

  var oAnalyzer     := TDeadCodeAnalyzer.Create;
  try
    oAnalyzer.CollectSymbols( 'C:\p\MixUnit.pas', UTF8String( sUnit ) );
    oAnalyzer.ScanForReferences( 'C:\p\MixUnit.pas', UTF8String( sUnit ) );

    var sAll        := '';
    for var rItem in oAnalyzer.GetDeadCode( False ) do
      sAll          := sAll + rItem.ElementName + ' ';
    Assert.AreEqual( 'PublicHelper LocalHelper', Trim( sAll ), 'with every unit read both are reported' );

    var sLocal      := '';
    for var rItem in oAnalyzer.GetDeadCode( True ) do
      sLocal        := sLocal + rItem.ElementName + ' ';
    Assert.AreEqual( 'LocalHelper', Trim( sLocal ), 'an unread unit might call PublicHelper, so only LocalHelper' );
  finally
    oAnalyzer.Free;
  end;
end;

procedure TTestDeadCodeCore.TestEscapedNameMatchesPlainCall;
begin
  var sUnit         :=
    'unit EscUnit;' + CRLF +
    'interface' + CRLF +
    'implementation' + CRLF +
    'procedure &Sample;' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    'procedure Other;' + CRLF +
    'begin' + CRLF +
    'end;' + CRLF +
    'initialization' + CRLF +
    '  Sample;' + CRLF +
    '  &Other;' + CRLF +
    'end.';
  Assert.AreEqual( '', DeadNames( [ 'C:\p\EscUnit.pas', sUnit ] ), '&Sample is called as Sample, Other as &Other' );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestDeadCodeCore );

end.

