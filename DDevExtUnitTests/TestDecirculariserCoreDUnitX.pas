unit TestDecirculariserCoreDUnitX;

/// <summary>
/// DUnitX test fixtures for <c>DecirculariserCore</c> - the RTL-only analysis behind the
/// Decirculariser. Covers graph construction, the fragile/benign classification that is the
/// point of the tool, per-edge symbol attribution, candidate ranking and the report.
/// </summary>
/// <remarks>
/// Every fixture feeds the analyser source text directly, so the tests need no project, no
/// IDE and nothing on disk.
///
/// The fixtures use <c>procedure</c> and <c>const</c> declarations rather than types when the
/// exact set of exported identifiers matters. The exports scanner records every identifier
/// token inside a <c>type</c> block - including ancestors and member names - which is fine for
/// its own purpose but makes a test's expected set hard to state precisely.
/// </remarks>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Graph construction: which references become edges, and what is entangled.</summary>
  [TestFixture]
  TTestDecirculariserGraph = class
  public
    /// <summary>A set with no cycle yields no groups.</summary>
    [Test]
    procedure TestAcyclicSetHasNoGroups;
    /// <summary>Two units referring to each other form one group.</summary>
    [Test]
    procedure TestMutualPairIsOneGroup;
    /// <summary>The group names both participants.</summary>
    [Test]
    procedure TestGroupNamesItsMembers;
    /// <summary>A reference to a unit outside the analysed set is not an edge.</summary>
    [Test]
    procedure TestReferenceOutsideTheSetIsIgnored;
    /// <summary>Three units in a ring form a single group of three.</summary>
    [Test]
    procedure TestThreeUnitRingIsOneGroupOfThree;
    /// <summary>Two unrelated cycles are reported as two groups.</summary>
    [Test]
    procedure TestTwoSeparateCyclesAreTwoGroups;
    /// <summary>A unit added twice does not become two nodes.</summary>
    [Test]
    procedure TestAddingSameUnitTwiceReplacesIt;
  end;

  /// <summary>The risk classification - the reason this tool exists.</summary>
  [TestFixture]
  TTestDecirculariserClassification = class
  public
    /// <summary>Both directions in the implementation section is benign: legal and free.</summary>
    [Test]
    procedure TestTwoImplementationEdgesIsBenign;
    /// <summary>One interface edge plus one implementation edge is FRAGILE - one promotion from E2004.</summary>
    [Test]
    procedure TestSingleImplementationEdgeIsFragile;
    /// <summary>The edge counts are split by section.</summary>
    [Test]
    procedure TestEdgeCountsAreSplitBySection;
    /// <summary>A fragile group outranks a larger benign one in the ordering.</summary>
    [Test]
    procedure TestFragileGroupSortsAboveBenign;
  end;

  /// <summary>Per-edge symbol attribution, ranking and advice.</summary>
  [TestFixture]
  TTestDecirculariserCandidates = class
  public
    /// <summary>An edge nothing crosses is reported as a dead uses entry.</summary>
    [Test]
    procedure TestEdgeWithNoCrossingSymbolsIsUnused;
    /// <summary>An edge carrying one identifier is extractable, and names it.</summary>
    [Test]
    procedure TestEdgeWithOneSymbolIsExtractable;
    /// <summary>Above the threshold an edge is genuine collaboration, not a refactoring.</summary>
    [Test]
    procedure TestEdgeAboveThresholdIsCollaboration;
    /// <summary>Candidates are ordered cheapest first.</summary>
    [Test]
    procedure TestCandidatesAreRankedCheapestFirst;
    /// <summary>Interface edges are never offered as something to cut.</summary>
    [Test]
    procedure TestInterfaceEdgesAreNeverCandidates;
    /// <summary>Every candidate carries advice naming both ends.</summary>
    [Test]
    procedure TestCandidateAdviceNamesBothUnits;
    /// <summary>An identifier several units declare is no evidence for one edge, and is
    /// excluded and counted rather than silently dropped.</summary>
    [Test]
    procedure TestAmbiguousSymbolsAreExcludedAndCounted;
  end;

  /// <summary>The rendered report.</summary>
  [TestFixture]
  TTestDecirculariserReport = class
  public
    /// <summary>A clean set says so rather than printing an empty list.</summary>
    [Test]
    procedure TestCleanSetReportsNoGroups;
    /// <summary>A fragile group is called out, with the explanation of why it matters.</summary>
    [Test]
    procedure TestFragileIsCalledOutInTheReport;
    /// <summary>The report states how much was analysed.</summary>
    [Test]
    procedure TestReportStatesTheScope;
  end;

implementation

uses
  System.SysUtils, System.Classes,
  UsesClauseManagerCore, DecirculariserCore;

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

/// <summary>Returns the group containing the named unit; fails the test when there is none.</summary>
function GroupWith( const AGroups: TArray<TDcGroup>; const AUnitName: string ): TDcGroup;
var
  G: TDcGroup;
  S: string;
begin
  for G in AGroups do
    for S in G.Units do
      if SameText( S, AUnitName ) then
        Exit( G );
  Assert.Fail( 'No entangled group contains ' + AUnitName );
  Result := Default( TDcGroup );
end;

/// <summary>Returns the candidate for a specific edge; fails the test when it is absent.</summary>
function CandidateFor( const AGroup: TDcGroup; const AFrom, ATo: string ): TDcBreakCandidate;
var
  C: TDcBreakCandidate;
begin
  for C in AGroup.Candidates do
    if SameText( C.Edge.FromUnit, AFrom ) and SameText( C.Edge.ToUnit, ATo ) then
      Exit( C );
  Assert.Fail( Format( 'No break candidate for %s -> %s', [ AFrom, ATo ] ) );
  Result := Default( TDcBreakCandidate );
end;

{ TTestDecirculariserGraph }

procedure TTestDecirculariserGraph.TestAcyclicSetHasNoGroups;
var
  D: TDecirculariser;
begin
  D := TDecirculariser.Create;
  try
    D.AddUnit( 'Leaf', Src( [
      'unit Leaf;', 'interface', 'procedure LeafThing;', 'implementation', 'end.' ] ) );
    D.AddUnit( 'Trunk', Src( [
      'unit Trunk;', 'interface', 'implementation', 'uses Leaf;',
      'procedure Go;', 'begin', '  LeafThing;', 'end;', 'end.' ] ) );
    D.Analyse;
    Assert.AreEqual<Integer>( 0, Length( D.Groups ),
      'a one-way dependency is not an entanglement' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserGraph.TestMutualPairIsOneGroup;
var
  D: TDecirculariser;
begin
  D := TDecirculariser.Create;
  try
    D.AddUnit( 'Alpha', Src( [
      'unit Alpha;', 'interface', 'procedure AlphaThing;',
      'implementation', 'uses Beta;', 'end.' ] ) );
    D.AddUnit( 'Beta', Src( [
      'unit Beta;', 'interface', 'procedure BetaThing;',
      'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    Assert.AreEqual<Integer>( 1, Length( D.Groups ), 'the pair should be one entangled group' );
    Assert.AreEqual<Integer>( 2, Length( D.Groups[ 0 ].Units ), 'containing both units' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserGraph.TestGroupNamesItsMembers;
var
  D: TDecirculariser;
  G: TDcGroup;
begin
  D := TDecirculariser.Create;
  try
    D.AddUnit( 'Alpha', Src( [ 'unit Alpha;', 'interface', 'implementation', 'uses Beta;', 'end.' ] ) );
    D.AddUnit( 'Beta',  Src( [ 'unit Beta;',  'interface', 'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    G := GroupWith( D.Groups, 'Alpha' );
    Assert.AreEqual( 'Alpha', G.Units[ 0 ], False, 'members are listed alphabetically' );
    Assert.AreEqual( 'Beta',  G.Units[ 1 ], False, 'and both are present' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserGraph.TestReferenceOutsideTheSetIsIgnored;
var
  D: TDecirculariser;
begin
  D := TDecirculariser.Create;
  try
    { Both units also use System.Classes, which is not in the analysed set. }
    D.AddUnit( 'Alpha', Src( [
      'unit Alpha;', 'interface', 'uses System.Classes;', 'implementation', 'end.' ] ) );
    D.AddUnit( 'Beta', Src( [
      'unit Beta;', 'interface', 'uses System.Classes;', 'implementation', 'end.' ] ) );
    D.Analyse;
    Assert.AreEqual<Integer>( 0, Length( D.Groups ),
      'a shared RTL dependency does not entangle two units' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserGraph.TestThreeUnitRingIsOneGroupOfThree;
var
  D: TDecirculariser;
begin
  D := TDecirculariser.Create;
  try
    D.AddUnit( 'One',   Src( [ 'unit One;',   'interface', 'implementation', 'uses Two;',   'end.' ] ) );
    D.AddUnit( 'Two',   Src( [ 'unit Two;',   'interface', 'implementation', 'uses Three;', 'end.' ] ) );
    D.AddUnit( 'Three', Src( [ 'unit Three;', 'interface', 'implementation', 'uses One;',   'end.' ] ) );
    D.Analyse;
    Assert.AreEqual<Integer>( 1, Length( D.Groups ), 'a ring is a single group' );
    Assert.AreEqual<Integer>( 3, Length( D.Groups[ 0 ].Units ), 'of all three units' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserGraph.TestTwoSeparateCyclesAreTwoGroups;
var
  D: TDecirculariser;
begin
  D := TDecirculariser.Create;
  try
    D.AddUnit( 'Alpha', Src( [ 'unit Alpha;', 'interface', 'implementation', 'uses Beta;',  'end.' ] ) );
    D.AddUnit( 'Beta',  Src( [ 'unit Beta;',  'interface', 'implementation', 'uses Alpha;', 'end.' ] ) );
    D.AddUnit( 'Gamma', Src( [ 'unit Gamma;', 'interface', 'implementation', 'uses Delta;', 'end.' ] ) );
    D.AddUnit( 'Delta', Src( [ 'unit Delta;', 'interface', 'implementation', 'uses Gamma;', 'end.' ] ) );
    D.Analyse;
    Assert.AreEqual<Integer>( 2, Length( D.Groups ), 'unrelated cycles stay separate groups' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserGraph.TestAddingSameUnitTwiceReplacesIt;
var
  D: TDecirculariser;
begin
  D := TDecirculariser.Create;
  try
    D.AddUnit( 'Alpha', Src( [ 'unit Alpha;', 'interface', 'implementation', 'end.' ] ) );
    D.AddUnit( 'Alpha', Src( [ 'unit Alpha;', 'interface', 'implementation', 'uses Beta;', 'end.' ] ) );
    D.AddUnit( 'Beta',  Src( [ 'unit Beta;',  'interface', 'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    Assert.AreEqual<Integer>( 2, D.UnitCount, 'the second Alpha replaces the first' );
    Assert.AreEqual<Integer>( 1, Length( D.Groups ), 'and it is the later source that is analysed' );
  finally
    D.Free;
  end;
end;

{ TTestDecirculariserClassification }

procedure TTestDecirculariserClassification.TestTwoImplementationEdgesIsBenign;
var
  D: TDecirculariser;
begin
  D := TDecirculariser.Create;
  try
    D.AddUnit( 'Alpha', Src( [ 'unit Alpha;', 'interface', 'implementation', 'uses Beta;',  'end.' ] ) );
    D.AddUnit( 'Beta',  Src( [ 'unit Beta;',  'interface', 'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    Assert.IsTrue( D.Groups[ 0 ].Kind = dcgBenign,
      'both directions in the implementation section is legal Delphi and costs nothing' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserClassification.TestSingleImplementationEdgeIsFragile;
var
  D: TDecirculariser;
begin
  D := TDecirculariser.Create;
  try
    { Beta is used by Alpha in the INTERFACE; Alpha is used by Beta only in the
      implementation. One promotion of that second clause and the build stops. }
    D.AddUnit( 'Alpha', Src( [
      'unit Alpha;', 'interface', 'uses Beta;', 'implementation', 'end.' ] ) );
    D.AddUnit( 'Beta', Src( [
      'unit Beta;', 'interface', 'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    Assert.AreEqual<Integer>( 1, Length( D.Groups ), 'the pair is entangled' );
    Assert.IsTrue( D.Groups[ 0 ].Kind = dcgFragile,
      'a group held by a single implementation edge is one promotion away from E2004' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserClassification.TestEdgeCountsAreSplitBySection;
var
  D: TDecirculariser;
  G: TDcGroup;
begin
  D := TDecirculariser.Create;
  try
    D.AddUnit( 'Alpha', Src( [
      'unit Alpha;', 'interface', 'uses Beta;', 'implementation', 'end.' ] ) );
    D.AddUnit( 'Beta', Src( [
      'unit Beta;', 'interface', 'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    G := D.Groups[ 0 ];
    Assert.AreEqual<Integer>( 1, G.InterfaceEdgeCount, 'one interface edge' );
    Assert.AreEqual<Integer>( 1, G.ImplementationEdgeCount, 'and one implementation edge' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserClassification.TestFragileGroupSortsAboveBenign;
var
  D: TDecirculariser;
begin
  D := TDecirculariser.Create;
  try
    { A three-unit benign mesh, and a two-unit fragile pair. The small dangerous one
      must come first however impressive the large one looks. }
    D.AddUnit( 'One',   Src( [ 'unit One;',   'interface', 'implementation', 'uses Two;',   'end.' ] ) );
    D.AddUnit( 'Two',   Src( [ 'unit Two;',   'interface', 'implementation', 'uses Three;', 'end.' ] ) );
    D.AddUnit( 'Three', Src( [ 'unit Three;', 'interface', 'implementation', 'uses One;',   'end.' ] ) );
    D.AddUnit( 'Alpha', Src( [ 'unit Alpha;', 'interface', 'uses Beta;', 'implementation', 'end.' ] ) );
    D.AddUnit( 'Beta',  Src( [ 'unit Beta;',  'interface', 'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    Assert.AreEqual<Integer>( 2, Length( D.Groups ), 'two groups' );
    Assert.IsTrue( D.Groups[ 0 ].Kind = dcgFragile,
      'the fragile pair must be reported before the larger benign mesh' );
    Assert.AreEqual<Integer>( 3, Length( D.Groups[ 1 ].Units ), 'the mesh comes second' );
  finally
    D.Free;
  end;
end;

{ TTestDecirculariserCandidates }

procedure TTestDecirculariserCandidates.TestEdgeWithNoCrossingSymbolsIsUnused;
var
  D: TDecirculariser;
  C: TDcBreakCandidate;
begin
  D := TDecirculariser.Create;
  try
    { Alpha uses Beta but never mentions anything Beta exports. }
    D.AddUnit( 'Alpha', Src( [
      'unit Alpha;', 'interface', 'procedure AlphaThing;',
      'implementation', 'uses Beta;', 'end.' ] ) );
    D.AddUnit( 'Beta', Src( [
      'unit Beta;', 'interface', 'procedure BetaThing;',
      'implementation', 'uses Alpha;',
      'procedure Go;', 'begin', '  AlphaThing;', 'end;', 'end.' ] ) );
    D.Analyse;
    C := CandidateFor( D.Groups[ 0 ], 'Alpha', 'Beta' );
    Assert.IsTrue( C.Verdict = dcvUnusedEdge,
      'nothing of Beta is referenced by Alpha, so the uses entry is dead' );
    Assert.AreEqual<Integer>( 0, Length( C.CrossingSymbols ), 'and no symbol crosses it' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserCandidates.TestEdgeWithOneSymbolIsExtractable;
var
  D: TDecirculariser;
  C: TDcBreakCandidate;
begin
  D := TDecirculariser.Create;
  try
    D.AddUnit( 'Alpha', Src( [
      'unit Alpha;', 'interface', 'procedure AlphaThing;',
      'implementation', 'uses Beta;',
      'procedure AlphaThing;', 'begin', '  BetaThing;', 'end;', 'end.' ] ) );
    D.AddUnit( 'Beta', Src( [
      'unit Beta;', 'interface', 'procedure BetaThing;',
      'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    C := CandidateFor( D.Groups[ 0 ], 'Alpha', 'Beta' );
    Assert.IsTrue( C.Verdict = dcvFewSymbols, 'one identifier crossing is an extraction job' );
    Assert.AreEqual<Integer>( 1, Length( C.CrossingSymbols ), 'exactly one symbol crosses' );
    Assert.AreEqual( 'BetaThing', C.CrossingSymbols[ 0 ], False, 'and it is named' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserCandidates.TestEdgeAboveThresholdIsCollaboration;
var
  D: TDecirculariser;
  C: TDcBreakCandidate;
begin
  D := TDecirculariser.Create;
  try
    D.FewSymbolsLimit := 1;
    D.AddUnit( 'Alpha', Src( [
      'unit Alpha;', 'interface', 'procedure AlphaThing;',
      'implementation', 'uses Beta;',
      'procedure AlphaThing;', 'begin', '  BetaOne;', '  BetaTwo;', 'end;', 'end.' ] ) );
    D.AddUnit( 'Beta', Src( [
      'unit Beta;', 'interface', 'procedure BetaOne;', 'procedure BetaTwo;',
      'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    C := CandidateFor( D.Groups[ 0 ], 'Alpha', 'Beta' );
    Assert.AreEqual<Integer>( 2, Length( C.CrossingSymbols ), 'two symbols cross' );
    Assert.IsTrue( C.Verdict = dcvManySymbols,
      'above the configured threshold this is collaboration, not a refactoring' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserCandidates.TestCandidatesAreRankedCheapestFirst;
var
  D: TDecirculariser;
  G: TDcGroup;
begin
  D := TDecirculariser.Create;
  try
    { Alpha -> Beta carries one symbol; Beta -> Alpha carries none. The dead one first. }
    D.AddUnit( 'Alpha', Src( [
      'unit Alpha;', 'interface', 'procedure AlphaThing;',
      'implementation', 'uses Beta;',
      'procedure AlphaThing;', 'begin', '  BetaThing;', 'end;', 'end.' ] ) );
    D.AddUnit( 'Beta', Src( [
      'unit Beta;', 'interface', 'procedure BetaThing;',
      'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    G := D.Groups[ 0 ];
    Assert.AreEqual<Integer>( 2, Length( G.Candidates ), 'both implementation edges are candidates' );
    Assert.IsTrue( G.Candidates[ 0 ].Verdict = dcvUnusedEdge,
      'the edge that costs nothing to remove is offered first' );
    Assert.AreEqual( 'Beta', G.Candidates[ 0 ].Edge.FromUnit, False,
      'and that is the Beta -> Alpha edge' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserCandidates.TestInterfaceEdgesAreNeverCandidates;
var
  D: TDecirculariser;
  C: TDcBreakCandidate;
begin
  D := TDecirculariser.Create;
  try
    D.AddUnit( 'Alpha', Src( [
      'unit Alpha;', 'interface', 'uses Beta;', 'implementation', 'end.' ] ) );
    D.AddUnit( 'Beta', Src( [
      'unit Beta;', 'interface', 'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    for C in D.Groups[ 0 ].Candidates do
      Assert.IsTrue( C.Edge.Section = usImplementation,
        'only implementation edges can be moved, so only they are offered' );
    Assert.AreEqual<Integer>( 1, Length( D.Groups[ 0 ].Candidates ),
      'the single implementation edge is the only candidate' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserCandidates.TestCandidateAdviceNamesBothUnits;
var
  D: TDecirculariser;
  C: TDcBreakCandidate;
begin
  D := TDecirculariser.Create;
  try
    D.AddUnit( 'Alpha', Src( [
      'unit Alpha;', 'interface', 'procedure AlphaThing;',
      'implementation', 'uses Beta;', 'end.' ] ) );
    D.AddUnit( 'Beta', Src( [
      'unit Beta;', 'interface', 'procedure BetaThing;',
      'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    C := CandidateFor( D.Groups[ 0 ], 'Alpha', 'Beta' );
    Assert.IsTrue( Pos( 'Alpha', C.Advice ) > 0, 'the advice names the unit to edit' );
    Assert.IsTrue( Pos( 'Beta', C.Advice ) > 0, 'and the unit to stop using' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserCandidates.TestAmbiguousSymbolsAreExcludedAndCounted;
var
  D: TDecirculariser;
  C: TDcBreakCandidate;
begin
  D := TDecirculariser.Create;
  try
    { Both units declare FormCreate - the shape every VCL form has. Alpha referencing
      "FormCreate" is its OWN, and is no reason for it to use Beta. }
    D.AddUnit( 'Alpha', Src( [
      'unit Alpha;', 'interface', 'procedure FormCreate;',
      'implementation', 'uses Beta;',
      'procedure FormCreate;', 'begin', 'end;', 'end.' ] ) );
    D.AddUnit( 'Beta', Src( [
      'unit Beta;', 'interface', 'procedure FormCreate;',
      'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    C := CandidateFor( D.Groups[ 0 ], 'Alpha', 'Beta' );
    Assert.AreEqual<Integer>( 0, Length( C.CrossingSymbols ),
      'an identifier both units declare must not be counted as crossing the edge' );
    Assert.IsTrue( C.AmbiguousSymbolCount > 0,
      'but it is counted, so the exclusion is visible rather than silent' );
    Assert.IsTrue( C.Verdict = dcvAmbiguous,
      'and the edge is reported as UNDECIDABLE rather than confidently dead - advising a '
      + 'deletion on this evidence would be advising a guess' );
    Assert.IsTrue( Pos( 'Cannot tell', C.Advice ) > 0,
      'the advice says plainly that it cannot tell' );
  finally
    D.Free;
  end;
end;

{ TTestDecirculariserReport }

procedure TTestDecirculariserReport.TestCleanSetReportsNoGroups;
var
  D: TDecirculariser;
  S: string;
begin
  D := TDecirculariser.Create;
  try
    D.AddUnit( 'Leaf',  Src( [ 'unit Leaf;',  'interface', 'implementation', 'end.' ] ) );
    D.AddUnit( 'Trunk', Src( [ 'unit Trunk;', 'interface', 'implementation', 'uses Leaf;', 'end.' ] ) );
    D.Analyse;
    S := D.Report;
    Assert.IsTrue( Pos( 'No entangled groups', S ) > 0,
      'a clean set should say so rather than print an empty list' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserReport.TestFragileIsCalledOutInTheReport;
var
  D: TDecirculariser;
  S: string;
begin
  D := TDecirculariser.Create;
  try
    D.AddUnit( 'Alpha', Src( [ 'unit Alpha;', 'interface', 'uses Beta;', 'implementation', 'end.' ] ) );
    D.AddUnit( 'Beta',  Src( [ 'unit Beta;',  'interface', 'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    S := D.Report;
    Assert.IsTrue( Pos( 'FRAGILE', S ) > 0, 'the fragile group is labelled' );
    Assert.IsTrue( Pos( 'E2004', S ) > 0, 'and the report says what will actually happen' );
  finally
    D.Free;
  end;
end;

procedure TTestDecirculariserReport.TestReportStatesTheScope;
var
  D: TDecirculariser;
  S: string;
begin
  D := TDecirculariser.Create;
  try
    D.AddUnit( 'Alpha', Src( [ 'unit Alpha;', 'interface', 'implementation', 'uses Beta;',  'end.' ] ) );
    D.AddUnit( 'Beta',  Src( [ 'unit Beta;',  'interface', 'implementation', 'uses Alpha;', 'end.' ] ) );
    D.Analyse;
    S := D.Report;
    Assert.IsTrue( Pos( 'Units analysed: 2', S ) > 0,
      'the report states how much was looked at, so a partial set is visible' );
  finally
    D.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestDecirculariserGraph );
  TDUnitX.RegisterTestFixture( TTestDecirculariserClassification );
  TDUnitX.RegisterTestFixture( TTestDecirculariserCandidates );
  TDUnitX.RegisterTestFixture( TTestDecirculariserReport );

end.
