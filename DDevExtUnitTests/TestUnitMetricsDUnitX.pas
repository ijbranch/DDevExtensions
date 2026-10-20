unit TestUnitMetricsDUnitX;

/// <summary>
/// DUnitX test fixture for <c>UnitMetrics.CalculateUnitMetrics</c> - the lines-of-code
/// and approximate cyclomatic-complexity figures shown by Build Statistics.  Drives the
/// calculator with small known sources and asserts the counts, including comment-line
/// exclusion and the branch-token / case-label complexity heuristic.
/// </summary>
/// <remarks>
/// Converted from the retired console harness <c>TestUnitMetrics.pas</c>.  The public
/// API takes a file name, so each source is written to a temporary <c>.pas</c> file
/// that is deleted again before the assertion runs.
/// </remarks>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising the unit metrics calculator.</summary>
  [TestFixture]
  TTestUnitMetrics = class
  public
    /// <summary>
    /// Proves branch-free code scores the base complexity of 1, so the heuristic counts
    /// nothing that is not a branch (begin, end, assignment).
    /// </summary>
    [Test]
    procedure TestBaseComplexity;
    /// <summary>Proves if, while and for each add exactly one to the base complexity (1 + 3 = 4).</summary>
    [Test]
    procedure TestBranchComplexity;
    /// <summary>
    /// Proves each case label and each boolean <c>and</c> adds one, while the
    /// <c>case</c> keyword and the case's closing <c>end</c> add nothing (1 + if + and +
    /// two labels = 5).
    /// </summary>
    [Test]
    procedure TestCaseLabelComplexity;
    /// <summary>Proves lines of code count only lines holding code tokens: a comment-only line is excluded.</summary>
    [Test]
    procedure TestLinesOfCodeExcludesComments;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, UnitMetrics;

/// <summary>Writes ASource to a temporary .pas file, measures it and deletes the file.</summary>
/// <param name="ASource">Object Pascal source text to measure.</param>
/// <returns>The metrics CalculateUnitMetrics reports for ASource.</returns>
function MetricsOf( const ASource: string ): TUnitMetrics;
begin
  var sFileName := TPath.Combine( TPath.GetTempPath, 'ddevextunittest_metrics.pas' );
  TFile.WriteAllText( sFileName, ASource, TEncoding.UTF8 );
  try
    Result := CalculateUnitMetrics( sFileName );
  finally
    if TFile.Exists( sFileName ) then TFile.Delete( sFileName );
  end;
end;

{ TTestUnitMetrics }

procedure TTestUnitMetrics.TestBaseComplexity;
begin
  var rMetrics := MetricsOf(
    'procedure P;'#13#10 +
    'begin'#13#10 +
    '  X := 1;'#13#10 +
    'end;'#13#10 );
  Assert.AreEqual<Integer>( 1, rMetrics.CyclomaticComplexity, 'no branches gives complexity 1' );
end;

procedure TTestUnitMetrics.TestBranchComplexity;
begin
  var rMetrics := MetricsOf(
    'procedure P;'#13#10 +
    'begin'#13#10 +
    '  if A then B;'#13#10 +
    '  while C do D;'#13#10 +
    '  for I := 1 to 2 do E;'#13#10 +
    'end;'#13#10 );
  Assert.AreEqual<Integer>( 4, rMetrics.CyclomaticComplexity, 'if + while + for gives complexity 4' );
end;

procedure TTestUnitMetrics.TestCaseLabelComplexity;
begin
  var rMetrics := MetricsOf(
    'procedure P;'#13#10 +
    'begin'#13#10 +
    '  if A and B then'#13#10 +    // if +1, and +1
    '    case X of'#13#10 +        // the case statement itself adds nothing
    '      1: Y;'#13#10 +          // case label +1
    '      2: Z;'#13#10 +          // case label +1
    '    end;'#13#10 +
    'end;'#13#10 );
  Assert.AreEqual<Integer>( 5, rMetrics.CyclomaticComplexity, 'if + and + two case labels gives complexity 5' );
end;

procedure TTestUnitMetrics.TestLinesOfCodeExcludesComments;
begin
  var rMetrics := MetricsOf(
    '// a comment line'#13#10 +
    'procedure P;'#13#10 +
    'begin'#13#10 +
    '  X := 1;'#13#10 +
    'end;'#13#10 );
  Assert.AreEqual<Integer>( 4, rMetrics.LinesOfCode, 'four code lines, the comment line excluded' );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestUnitMetrics );

end.
