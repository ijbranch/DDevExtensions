unit TestUsesClauseManagerCoreDUnitX;

/// <summary>
/// DUnitX test fixtures for <c>UsesClauseManagerCore</c> — the RTL-only analysis behind the
/// Uses Clause Manager. Covers the exports database, the interface/implementation identifier
/// usage analyser, and the placement recommendations and source rewrite built on top of them.
/// </summary>
/// <remarks>
/// The core takes its source as text rather than as a file name, and its scan directories from
/// the caller, so every test here runs with no IDE, no project and nothing on disk.
///
/// <c>TUsesClauseRefactorer.Analyze</c> hands the caller two owned <c>TStringList</c> instances
/// per placement, so every test that calls it disposes of them through <c>FreePlacements</c>.
/// The FastMM5 leak gate in the runner turns a missed one into a failure.
/// </remarks>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising the unit exports database.</summary>
  [TestFixture]
  TTestUnitExportsDatabase = class
  public
    /// <summary>Constants declared in the interface are recorded as ekConst.</summary>
    [Test]
    procedure TestInterfaceConstIsExported;
    /// <summary>Procedures and functions are recorded with their own kinds.</summary>
    [Test]
    procedure TestRoutineKindsAreDistinguished;
    /// <summary>Declarations below the implementation keyword are not exported.</summary>
    [Test]
    procedure TestImplementationDeclarationsAreNotExported;
    /// <summary>A unit that exports nothing is not added to the database.</summary>
    [Test]
    procedure TestUnitWithNoExportsIsNotStored;
    /// <summary>Unit lookup ignores the case of the supplied name.</summary>
    [Test]
    procedure TestGetExportsIsCaseInsensitive;
    /// <summary>The reverse lookup maps an identifier back to its declaring unit.</summary>
    [Test]
    procedure TestFindUnitsForIdentifier;
    /// <summary>An identifier nothing declares resolves to nil, not an empty list.</summary>
    [Test]
    procedure TestFindUnitsForUnknownIdentifierReturnsNil;
    /// <summary>With one candidate, that candidate is preferred.</summary>
    [Test]
    procedure TestGetPreferredUnitWithSingleCandidate;
    /// <summary>An RTL/VCL unit outranks a project unit declaring the same identifier.</summary>
    [Test]
    procedure TestGetPreferredUnitHonoursRTLPriority;
    /// <summary>An empty candidate list yields an empty result rather than raising.</summary>
    [Test]
    procedure TestGetPreferredUnitWithNoCandidates;
    /// <summary>Clear empties both the exports and the reverse lookup.</summary>
    [Test]
    procedure TestClearEmptiesDatabase;
    /// <summary>Scanning a path that does not exist is a no-op, not an exception.</summary>
    [Test]
    procedure TestScanUnitOfMissingFileIsSilent;
    /// <summary>A nil directory list is tolerated and simply clears the database.</summary>
    [Test]
    procedure TestBuildFromDirectoriesAcceptsNil;
    /// <summary>
    /// CHARACTERISATION — scanning two units that share a name currently raises, because the
    /// exports dictionary is populated with Add and has no duplicate guard. Two search
    /// directories each holding a Utils.pas is enough to trigger it in the IDE. This test pins
    /// the behaviour so that changing it is a deliberate act; it is not an endorsement.
    /// </summary>
    [Test]
    procedure TestDuplicateUnitNameCurrentlyRaises;
  end;

  /// <summary>DUnitX test fixture exercising the identifier usage analyser.</summary>
  [TestFixture]
  TTestIdentifierUsageAnalyzer = class
  public
    /// <summary>Units listed in the interface uses clause are captured with that section.</summary>
    [Test]
    procedure TestInterfaceUsesAreCaptured;
    /// <summary>Units listed in the implementation uses clause are captured separately.</summary>
    [Test]
    procedure TestImplementationUsesAreCaptured;
    /// <summary>An identifier appearing in the interface is recorded against the interface.</summary>
    [Test]
    procedure TestInterfaceIdentifierIsRecorded;
    /// <summary>An identifier appearing only below implementation is recorded there.</summary>
    [Test]
    procedure TestImplementationIdentifierIsRecorded;
    /// <summary>A qualified Unit.Identifier reference records its qualifying unit.</summary>
    [Test]
    procedure TestQualifiedReferenceIsRecorded;
    /// <summary>Clear resets every collection so the analyser can be reused.</summary>
    [Test]
    procedure TestClearResetsAllCollections;
  end;

  /// <summary>DUnitX test fixture exercising placement recommendations and the rewrite.</summary>
  [TestFixture]
  TTestUsesClauseRefactorer = class
  public
    /// <summary>A unit in the interface clause used only below implementation should move down.</summary>
    [Test]
    procedure TestInterfaceUnitUsedOnlyInImplementationMovesDown;
    /// <summary>A unit genuinely used in the interface stays in the interface.</summary>
    [Test]
    procedure TestInterfaceUnitUsedInInterfaceStays;
    /// <summary>A unit with no detected usage is left alone and flagged for review.</summary>
    [Test]
    procedure TestUnusedUnitIsFlaggedForReview;
    /// <summary>A unit in the implementation clause whose identifiers appear in the interface moves up.</summary>
    [Test]
    procedure TestImplementationUnitUsedInInterfaceMovesUp;
    /// <summary>The rewritten source really does relocate the unit between the two clauses.</summary>
    [Test]
    procedure TestGenerateRefactoredSourceRelocatesUnit;
    /// <summary>Analysing a source with no uses clause at all yields no placements.</summary>
    [Test]
    procedure TestSourceWithoutUsesClauseYieldsNoPlacements;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  UsesClauseManagerCore;

{ ---------------------------------------------------------------------------
  Helpers
  --------------------------------------------------------------------------- }

/// <summary>Joins the supplied lines with CRLF and returns them as UTF-8 source text.</summary>
function Src( const ALines: array of string ): UTF8String;
var
  sb: TStringBuilder;
  I: Integer;
begin
  sb := TStringBuilder.Create;
  try
    for I := Low( ALines ) to High( ALines ) do
      sb.Append( ALines[ I ] ).Append( sLineBreak );
    Result := UTF8Encode( sb.ToString );
  finally
    sb.Free;
  end;
end;

/// <summary>Releases the two TStringList instances each placement hands to the caller.</summary>
procedure FreePlacements( const APlacements: TArray<TUnitPlacement> );
var
  P: TUnitPlacement;
begin
  for P in APlacements do
  begin
    P.IdentifiersUsedInInterface.Free;
    P.IdentifiersUsedInImplementation.Free;
  end;
end;

/// <summary>Finds the placement for a named unit; fails the test when it is absent.</summary>
function PlacementFor( const APlacements: TArray<TUnitPlacement>;
  const AUnitName: string ): TUnitPlacement;
var
  P: TUnitPlacement;
begin
  for P in APlacements do
    if SameText( P.UnitName, AUnitName ) then
      Exit( P );
  Assert.Fail( 'No placement returned for unit ' + AUnitName );
  Result := Default( TUnitPlacement );
end;

/// <summary>True when the unit declares the identifier with the given kind.</summary>
function HasExport( ADB: TUnitExportsDatabase; const AUnitName, AIdentifier: string;
  AKind: TExportKind ): Boolean;
var
  L: TList<TUnitExport>;
  E: TUnitExport;
begin
  Result := False;
  L := ADB.GetExports( AUnitName );
  if L = nil then
    Exit;
  for E in L do
    if SameText( E.Identifier, AIdentifier ) and ( E.Kind = AKind ) then
      Exit( True );
end;

{ TTestUnitExportsDatabase }

procedure TTestUnitExportsDatabase.TestInterfaceConstIsExported;
var
  DB: TUnitExportsDatabase;
begin
  DB := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'AppConsts', 'AppConsts.pas', Src( [
      'unit AppConsts;', 'interface', 'const', '  APP_TITLE = 1;', 'implementation', 'end.' ] ) );
    Assert.IsTrue( HasExport( DB, 'AppConsts', 'APP_TITLE', ekConst ),
      'APP_TITLE should be recorded as a const export' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestRoutineKindsAreDistinguished;
var
  DB: TUnitExportsDatabase;
begin
  DB := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Helpers', 'Helpers.pas', Src( [
      'unit Helpers;', 'interface',
      'procedure DoThing;',
      'function GetThing: Integer;',
      'implementation', 'end.' ] ) );
    Assert.IsTrue( HasExport( DB, 'Helpers', 'DoThing', ekProcedure ),
      'DoThing should be recorded as a procedure' );
    Assert.IsTrue( HasExport( DB, 'Helpers', 'GetThing', ekFunction ),
      'GetThing should be recorded as a function' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestImplementationDeclarationsAreNotExported;
var
  DB: TUnitExportsDatabase;
begin
  DB := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Hidden', 'Hidden.pas', Src( [
      'unit Hidden;', 'interface',
      'const', '  PUBLIC_VALUE = 1;',
      'implementation',
      'const', '  PRIVATE_VALUE = 2;',
      'end.' ] ) );
    Assert.IsTrue( HasExport( DB, 'Hidden', 'PUBLIC_VALUE', ekConst ),
      'the interface constant should be exported' );
    Assert.IsFalse( HasExport( DB, 'Hidden', 'PRIVATE_VALUE', ekConst ),
      'an implementation-section constant must not be exported' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestUnitWithNoExportsIsNotStored;
var
  DB: TUnitExportsDatabase;
begin
  DB := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Empty', 'Empty.pas', Src( [
      'unit Empty;', 'interface', 'implementation', 'end.' ] ) );
    Assert.AreEqual( 0, DB.UnitCount, 'a unit with no exports should not be stored' );
    Assert.IsNull( DB.GetExports( 'Empty' ), 'GetExports should return nil for it' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestGetExportsIsCaseInsensitive;
var
  DB: TUnitExportsDatabase;
begin
  DB := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'MixedCase', 'MixedCase.pas', Src( [
      'unit MixedCase;', 'interface', 'const', '  VALUE = 1;', 'implementation', 'end.' ] ) );
    Assert.IsNotNull( DB.GetExports( 'MIXEDCASE' ), 'upper-case lookup should succeed' );
    Assert.IsNotNull( DB.GetExports( 'mixedcase' ), 'lower-case lookup should succeed' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestFindUnitsForIdentifier;
var
  DB: TUnitExportsDatabase;
  Units: TStringList;
begin
  DB := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Provider', 'Provider.pas', Src( [
      'unit Provider;', 'interface', 'procedure UniqueRoutine;', 'implementation', 'end.' ] ) );
    Units := DB.FindUnitsForIdentifier( 'UniqueRoutine' );
    Assert.IsNotNull( Units, 'the identifier should be in the reverse lookup' );
    Assert.IsTrue( Units.IndexOf( 'Provider' ) >= 0, 'Provider should be listed as the declaring unit' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestFindUnitsForUnknownIdentifierReturnsNil;
var
  DB: TUnitExportsDatabase;
begin
  DB := TUnitExportsDatabase.Create;
  try
    Assert.IsNull( DB.FindUnitsForIdentifier( 'NothingDeclaresThis' ),
      'an unknown identifier should resolve to nil' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestGetPreferredUnitWithSingleCandidate;
var
  DB: TUnitExportsDatabase;
  Candidates: TStringList;
begin
  DB := TUnitExportsDatabase.Create;
  Candidates := TStringList.Create;
  try
    Candidates.Add( 'OnlyOption' );
    Assert.AreEqual( 'OnlyOption', DB.GetPreferredUnit( 'Anything', Candidates ), False,
      'the sole candidate should be returned unchanged' );
  finally
    Candidates.Free;
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestGetPreferredUnitHonoursRTLPriority;
var
  DB: TUnitExportsDatabase;
  Candidates: TStringList;
begin
  DB := TUnitExportsDatabase.Create;
  Candidates := TStringList.Create;
  try
    Candidates.Add( 'MyOwnForms' );
    Candidates.Add( 'Forms' );
    Assert.AreEqual( 'Forms', DB.GetPreferredUnit( 'TForm', Candidates ), False,
      'the RTL/VCL priority list should outrank an unrelated project unit' );
  finally
    Candidates.Free;
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestGetPreferredUnitWithNoCandidates;
var
  DB: TUnitExportsDatabase;
  Empty: TStringList;
begin
  DB := TUnitExportsDatabase.Create;
  Empty := TStringList.Create;
  try
    Assert.AreEqual( '', DB.GetPreferredUnit( 'Anything', Empty ), False,
      'an empty candidate list should yield an empty result' );
    Assert.AreEqual( '', DB.GetPreferredUnit( 'Anything', nil ), False,
      'a nil candidate list should yield an empty result' );
  finally
    Empty.Free;
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestClearEmptiesDatabase;
var
  DB: TUnitExportsDatabase;
begin
  DB := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Provider', 'Provider.pas', Src( [
      'unit Provider;', 'interface', 'procedure UniqueRoutine;', 'implementation', 'end.' ] ) );
    Assert.AreEqual( 1, DB.UnitCount, 'the unit should be stored before Clear' );

    DB.Clear;

    Assert.AreEqual( 0, DB.UnitCount, 'Clear should empty the exports' );
    Assert.IsNull( DB.FindUnitsForIdentifier( 'UniqueRoutine' ),
      'Clear should empty the reverse lookup too' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestScanUnitOfMissingFileIsSilent;
var
  DB: TUnitExportsDatabase;
  Probe: TProc;
begin
  DB := TUnitExportsDatabase.Create;
  try
    Probe :=
      procedure
      begin
        DB.ScanUnit( 'X:\no\such\directory\NoSuchUnit.pas' );
      end;
    Assert.WillNotRaiseAny( Probe, 'scanning a missing file should be a silent no-op' );
    Assert.AreEqual( 0, DB.UnitCount, 'nothing should have been added' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestBuildFromDirectoriesAcceptsNil;
var
  DB: TUnitExportsDatabase;
  Probe: TProc;
begin
  DB := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Provider', 'Provider.pas', Src( [
      'unit Provider;', 'interface', 'procedure UniqueRoutine;', 'implementation', 'end.' ] ) );
    Probe :=
      procedure
      begin
        DB.BuildFromDirectories( nil, nil );
      end;
    Assert.WillNotRaiseAny( Probe, 'a nil directory list should be tolerated' );
    Assert.AreEqual( 0, DB.UnitCount, 'it should still have cleared the database' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestDuplicateUnitNameCurrentlyRaises;
var
  DB: TUnitExportsDatabase;
  Probe: TProc;
begin
  DB := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Utils', 'A\Utils.pas', Src( [
      'unit Utils;', 'interface', 'procedure FromA;', 'implementation', 'end.' ] ) );
    Probe :=
      procedure
      begin
        DB.ScanSource( 'Utils', 'B\Utils.pas', Src( [
          'unit Utils;', 'interface', 'procedure FromB;', 'implementation', 'end.' ] ) );
      end;
    Assert.WillRaiseAny( Probe,
      'a second unit of the same name currently raises - see the fixture remarks' );
  finally
    DB.Free;
  end;
end;

{ TTestIdentifierUsageAnalyzer }

procedure TTestIdentifierUsageAnalyzer.TestInterfaceUsesAreCaptured;
var
  A: TIdentifierUsageAnalyzer;
  Found: Boolean;
  U: TUsedUnitInfo;
begin
  A := TIdentifierUsageAnalyzer.Create;
  try
    A.Analyze( Src( [
      'unit Subject;', 'interface', 'uses SysUtils, Classes;', 'implementation', 'end.' ] ) );
    Found := False;
    for U in A.InterfaceUsedUnits do
      if SameText( U.UnitName, 'Classes' ) then
      begin
        Found := True;
        Assert.IsTrue( U.Section = usInterface, 'Classes should be marked as an interface use' );
      end;
    Assert.IsTrue( Found, 'Classes should appear in the interface uses list' );
  finally
    A.Free;
  end;
end;

procedure TTestIdentifierUsageAnalyzer.TestImplementationUsesAreCaptured;
var
  A: TIdentifierUsageAnalyzer;
  Found: Boolean;
  U: TUsedUnitInfo;
begin
  A := TIdentifierUsageAnalyzer.Create;
  try
    A.Analyze( Src( [
      'unit Subject;', 'interface', 'uses Classes;',
      'implementation', 'uses Dialogs;', 'end.' ] ) );
    Found := False;
    for U in A.ImplementationUsedUnits do
      if SameText( U.UnitName, 'Dialogs' ) then
        Found := True;
    Assert.IsTrue( Found, 'Dialogs should appear in the implementation uses list' );

    for U in A.InterfaceUsedUnits do
      Assert.IsFalse( SameText( U.UnitName, 'Dialogs' ),
        'Dialogs must not also be listed as an interface use' );
  finally
    A.Free;
  end;
end;

procedure TTestIdentifierUsageAnalyzer.TestInterfaceIdentifierIsRecorded;
var
  A: TIdentifierUsageAnalyzer;
begin
  A := TIdentifierUsageAnalyzer.Create;
  try
    A.Analyze( Src( [
      'unit Subject;', 'interface', 'uses Classes;',
      'type', '  TThing = class( TComponent )', '  end;',
      'implementation', 'end.' ] ) );
    Assert.IsTrue( A.InterfaceIdentifiers.IndexOf( 'TComponent' ) >= 0,
      'TComponent is referenced in the interface and should be recorded there' );
  finally
    A.Free;
  end;
end;

procedure TTestIdentifierUsageAnalyzer.TestImplementationIdentifierIsRecorded;
var
  A: TIdentifierUsageAnalyzer;
begin
  A := TIdentifierUsageAnalyzer.Create;
  try
    A.Analyze( Src( [
      'unit Subject;', 'interface', 'uses Classes;',
      'implementation',
      'procedure Local;', 'var', '  L: TStringList;', 'begin', '  L := nil;', 'end;',
      'end.' ] ) );
    Assert.IsTrue( A.ImplementationIdentifiers.IndexOf( 'TStringList' ) >= 0,
      'TStringList appears only below implementation and should be recorded there' );
    Assert.IsTrue( A.InterfaceIdentifiers.IndexOf( 'TStringList' ) < 0,
      'and must not be recorded as an interface identifier' );
  finally
    A.Free;
  end;
end;

procedure TTestIdentifierUsageAnalyzer.TestQualifiedReferenceIsRecorded;
var
  A: TIdentifierUsageAnalyzer;
  Qualifier: string;
begin
  A := TIdentifierUsageAnalyzer.Create;
  try
    A.Analyze( Src( [
      'unit Subject;', 'interface', 'implementation',
      'procedure Local;', 'begin', '  SysUtils.FreeAndNil( Obj );', 'end;',
      'end.' ] ) );
    Assert.IsTrue( A.QualifiedReferences.TryGetValue( 'freeandnil', Qualifier ),
      'the qualified reference should be recorded' );
    Assert.AreEqual( 'SysUtils', Qualifier, False, 'and should name its qualifying unit' );
  finally
    A.Free;
  end;
end;

procedure TTestIdentifierUsageAnalyzer.TestClearResetsAllCollections;
var
  A: TIdentifierUsageAnalyzer;
begin
  A := TIdentifierUsageAnalyzer.Create;
  try
    A.Analyze( Src( [
      'unit Subject;', 'interface', 'uses Classes;', 'implementation', 'end.' ] ) );
    Assert.IsTrue( A.InterfaceUsedUnits.Count > 0, 'there should be something to clear' );

    A.Clear;

    Assert.AreEqual<Integer>( 0, A.InterfaceUsedUnits.Count, 'interface uses should be cleared' );
    Assert.AreEqual<Integer>( 0, A.ImplementationUsedUnits.Count, 'implementation uses should be cleared' );
    Assert.AreEqual( 0, A.InterfaceIdentifiers.Count, 'interface identifiers should be cleared' );
    Assert.AreEqual( 0, A.ImplementationIdentifiers.Count, 'implementation identifiers should be cleared' );
    Assert.AreEqual<Integer>( 0, A.QualifiedReferences.Count, 'qualified references should be cleared' );
  finally
    A.Free;
  end;
end;

{ TTestUsesClauseRefactorer }

/// <summary>Builds a database holding one provider unit that exports a single routine.</summary>
function ProviderDB: TUnitExportsDatabase;
begin
  Result := TUnitExportsDatabase.Create;
  Result.ScanSource( 'Provider', 'Provider.pas', Src( [
    'unit Provider;', 'interface', 'procedure ProviderRoutine;', 'implementation', 'end.' ] ) );
end;

procedure TTestUsesClauseRefactorer.TestInterfaceUnitUsedOnlyInImplementationMovesDown;
var
  DB: TUnitExportsDatabase;
  R: TUsesClauseRefactorer;
  Placements: TArray<TUnitPlacement>;
  P: TUnitPlacement;
begin
  DB := ProviderDB;
  R := TUsesClauseRefactorer.Create( DB );
  try
    Placements := R.Analyze( Src( [
      'unit Subject;', 'interface', 'uses Provider;',
      'implementation',
      'procedure Local;', 'begin', '  ProviderRoutine;', 'end;',
      'end.' ] ) );
    try
      P := PlacementFor( Placements, 'Provider' );
      Assert.IsTrue( P.CurrentSection = usInterface, 'it is currently in the interface clause' );
      Assert.IsTrue( P.RecommendedSection = usImplementation,
        'used only below implementation, so it should be recommended for the implementation clause' );
      Assert.AreEqual( 'Only used in implementation section', P.Reason, False,
        'and the reason should say so' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestInterfaceUnitUsedInInterfaceStays;
var
  DB: TUnitExportsDatabase;
  R: TUsesClauseRefactorer;
  Placements: TArray<TUnitPlacement>;
  P: TUnitPlacement;
begin
  DB := ProviderDB;
  R := TUsesClauseRefactorer.Create( DB );
  try
    Placements := R.Analyze( Src( [
      'unit Subject;', 'interface', 'uses Provider;',
      'procedure Exposed;', 'begin', '  ProviderRoutine;', 'end;',
      'implementation', 'end.' ] ) );
    try
      P := PlacementFor( Placements, 'Provider' );
      Assert.IsTrue( P.RecommendedSection = usInterface,
        'its identifier is referenced in the interface, so it should stay there' );
      Assert.IsTrue( P.IdentifiersUsedInInterface.IndexOf( 'ProviderRoutine' ) >= 0,
        'and the identifier that justifies it should be reported' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestUnusedUnitIsFlaggedForReview;
var
  DB: TUnitExportsDatabase;
  R: TUsesClauseRefactorer;
  Placements: TArray<TUnitPlacement>;
  P: TUnitPlacement;
begin
  DB := ProviderDB;
  R := TUsesClauseRefactorer.Create( DB );
  try
    Placements := R.Analyze( Src( [
      'unit Subject;', 'interface', 'uses Provider;', 'implementation', 'end.' ] ) );
    try
      P := PlacementFor( Placements, 'Provider' );
      Assert.IsTrue( P.RecommendedSection = usInterface,
        'an apparently unused unit should be left where it is' );
      Assert.AreEqual( 'No direct usage detected - review manually', P.Reason, False,
        'and be flagged for manual review rather than moved' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestImplementationUnitUsedInInterfaceMovesUp;
var
  DB: TUnitExportsDatabase;
  R: TUsesClauseRefactorer;
  Placements: TArray<TUnitPlacement>;
  P: TUnitPlacement;
begin
  DB := ProviderDB;
  R := TUsesClauseRefactorer.Create( DB );
  try
    Placements := R.Analyze( Src( [
      'unit Subject;', 'interface',
      'procedure Exposed;', 'begin', '  ProviderRoutine;', 'end;',
      'implementation', 'uses Provider;', 'end.' ] ) );
    try
      P := PlacementFor( Placements, 'Provider' );
      Assert.IsTrue( P.CurrentSection = usImplementation, 'it is currently in the implementation clause' );
      Assert.IsTrue( P.RecommendedSection = usInterface,
        'its identifier is used in the interface, so it should be recommended for the interface clause' );
      Assert.AreEqual( 'Identifiers used in interface section', P.Reason, False,
        'and the reason should say so' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestGenerateRefactoredSourceRelocatesUnit;
var
  DB: TUnitExportsDatabase;
  R: TUsesClauseRefactorer;
  Placements: TArray<TUnitPlacement>;
  Rewritten: UTF8String;
  Check: TIdentifierUsageAnalyzer;
  U: TUsedUnitInfo;
  InInterface, InImplementation: Boolean;
begin
  DB := ProviderDB;
  R := TUsesClauseRefactorer.Create( DB );
  try
    Rewritten := '';
    Placements := R.Analyze( Src( [
      'unit Subject;', 'interface', 'uses Provider;',
      'implementation',
      'procedure Local;', 'begin', '  ProviderRoutine;', 'end;',
      'end.' ] ) );
    try
      Rewritten := R.GenerateRefactoredSource( Src( [
        'unit Subject;', 'interface', 'uses Provider;',
        'implementation',
        'procedure Local;', 'begin', '  ProviderRoutine;', 'end;',
        'end.' ] ), Placements );
    finally
      FreePlacements( Placements );
    end;

    Assert.IsTrue( Length( Rewritten ) > 0, 'the rewrite should produce source' );

    { Verify the outcome by re-reading the generated source rather than by matching text,
      so the test survives any change to layout or formatting. }
    Check := TIdentifierUsageAnalyzer.Create;
    try
      Check.Analyze( Rewritten );
      InInterface := False;
      InImplementation := False;
      for U in Check.InterfaceUsedUnits do
        if SameText( U.UnitName, 'Provider' ) then
          InInterface := True;
      for U in Check.ImplementationUsedUnits do
        if SameText( U.UnitName, 'Provider' ) then
          InImplementation := True;

      Assert.IsFalse( InInterface, 'Provider should no longer be in the interface uses clause' );
      Assert.IsTrue( InImplementation, 'Provider should now be in the implementation uses clause' );
    finally
      Check.Free;
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestSourceWithoutUsesClauseYieldsNoPlacements;
var
  DB: TUnitExportsDatabase;
  R: TUsesClauseRefactorer;
  Placements: TArray<TUnitPlacement>;
begin
  DB := ProviderDB;
  R := TUsesClauseRefactorer.Create( DB );
  try
    Placements := R.Analyze( Src( [
      'unit Subject;', 'interface', 'implementation', 'end.' ] ) );
    try
      Assert.AreEqual<Integer>( 0, Length( Placements ),
        'a unit with no uses clause has nothing to place' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestUnitExportsDatabase );
  TDUnitX.RegisterTestFixture( TTestIdentifierUsageAnalyzer );
  TDUnitX.RegisterTestFixture( TTestUsesClauseRefactorer );

end.
