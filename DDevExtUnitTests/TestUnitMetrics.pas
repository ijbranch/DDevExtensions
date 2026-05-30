unit TestUnitMetrics;

/// <summary>
/// Console-driven tests for <c>UnitMetrics.CalculateUnitMetrics</c> - the lines-of-code and
/// (approximate) cyclomatic-complexity calculation used by Build Statistics. Drives the
/// calculator with small known source fixtures (written to a temp file, since the public
/// API takes a file name) and asserts the LOC and complexity counts, including the
/// comment-line exclusion and the branch-token / case-label complexity heuristic.
/// Writes PASS lines + a summary; raises on first failure.
/// </summary>

interface

/// <summary>Runs every metrics test, writing PASS lines and a summary; raises on failure.</summary>
procedure RunUnitMetricsTests;

implementation

uses
  System.SysUtils, System.IOUtils,
  UnitMetrics;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Assert(Condition: Boolean; const Msg: string);
begin
  if not Condition then
  begin
    Inc(TestsFailed);
    raise Exception.Create('Assertion failed: ' + Msg);
  end;
  Inc(TestsPassed);
end;

/// <summary>Writes Source to a temp .pas file, runs CalculateUnitMetrics, deletes the file.</summary>
function MetricsOf(const Source: string): TUnitMetrics;
var
  FileName: string;
begin
  FileName := TPath.Combine(TPath.GetTempPath, 'ddevextunittest_metrics.pas');
  TFile.WriteAllText(FileName, Source, TEncoding.UTF8);
  try
    Result := CalculateUnitMetrics(FileName);
  finally
    if TFile.Exists(FileName) then
      TFile.Delete(FileName);
  end;
end;

procedure TestBaseComplexity;
var
  M: TUnitMetrics;
begin
  WriteLn('Test: base complexity of branch-free code is 1');
  M := MetricsOf('procedure P;'#13#10 + 'begin'#13#10 + '  X := 1;'#13#10 + 'end;'#13#10);
  Assert(M.CyclomaticComplexity = 1, 'no branches -> complexity 1 (got ' + IntToStr(M.CyclomaticComplexity) + ')');
  WriteLn('  PASS');
end;

procedure TestBranchComplexity;
var
  M: TUnitMetrics;
begin
  WriteLn('Test: if / while / for each add one to complexity');
  M := MetricsOf(
    'procedure P;'#13#10 +
    'begin'#13#10 +
    '  if A then B;'#13#10 +
    '  while C do D;'#13#10 +
    '  for I := 1 to 2 do E;'#13#10 +
    'end;'#13#10);
  // base 1 + if + while + for = 4
  Assert(M.CyclomaticComplexity = 4, 'if+while+for -> complexity 4 (got ' + IntToStr(M.CyclomaticComplexity) + ')');
  WriteLn('  PASS');
end;

procedure TestCaseLabelComplexity;
var
  M: TUnitMetrics;
begin
  WriteLn('Test: case labels and boolean and/or add to complexity');
  M := MetricsOf(
    'procedure P;'#13#10 +
    'begin'#13#10 +
    '  if A and B then'#13#10 +     // if +1, and +1
    '    case X of'#13#10 +         // case-statement
    '      1: Y;'#13#10 +           // case label +1
    '      2: Z;'#13#10 +           // case label +1
    '    end;'#13#10 +
    'end;'#13#10);
  // base 1 + if(1) + and(1) + 2 case labels = 5
  Assert(M.CyclomaticComplexity = 5, 'if+and+2 case labels -> complexity 5 (got ' + IntToStr(M.CyclomaticComplexity) + ')');
  WriteLn('  PASS');
end;

procedure TestLinesOfCodeExcludesComments;
var
  M: TUnitMetrics;
begin
  WriteLn('Test: LOC counts code lines and excludes comment-only lines');
  // Line 0 is comment-only (not counted); lines 1-4 hold code tokens.
  M := MetricsOf(
    '// a comment line'#13#10 +
    'procedure P;'#13#10 +
    'begin'#13#10 +
    '  X := 1;'#13#10 +
    'end;'#13#10);
  Assert(M.LinesOfCode = 4, 'four code lines, comment excluded (got ' + IntToStr(M.LinesOfCode) + ')');
  WriteLn('  PASS');
end;

procedure RunUnitMetricsTests;
begin
  WriteLn('UnitMetrics Tests:');
  WriteLn('------------------');
  TestBaseComplexity;
  TestBranchComplexity;
  TestCaseLabelComplexity;
  TestLinesOfCodeExcludesComments;
  WriteLn;
  WriteLn(Format('UnitMetrics Test Summary: Passed: %d  Failed: %d', [ TestsPassed, TestsFailed ]));
end;

end.
