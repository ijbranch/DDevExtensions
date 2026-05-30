unit TestDelphiParserContainers;

/// <summary>
/// Console-driven tests for <c>DelphiParserContainers</c> (THashtable, TIntegerList,
/// TStringDictionary, TStringCollection) - the lightweight containers the lexer/parser
/// rely on. Verifies key lookup, case sensitivity, ownership-aware removal and the
/// integer/pointer round-trip. Writes PASS lines + a summary; raises on first failure.
/// </summary>

interface

/// <summary>Runs every container test, writing PASS lines and a summary; raises on failure.</summary>
procedure RunContainerTests;

implementation

uses
  System.SysUtils,
  DelphiParserContainers;

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

procedure TestHashtableCaseInsensitive;
var
  H: THashtable;
  Obj1, Obj2: TObject;
begin
  WriteLn('Test: THashtable (case-insensitive, owns objects)');
  H := THashtable.Create(False { CaseSensitive }, True { OwnsObjects });
  try
    Obj1 := TObject.Create;
    Obj2 := TObject.Create;
    H.Add('alpha', Obj1);
    H.Add('beta', Obj2);
    Assert(H.Count = 2, 'count should be 2');
    Assert(H.Contains('alpha'), 'should contain alpha');
    Assert(H.Contains('ALPHA'), 'case-insensitive: should contain ALPHA');
    Assert(H.Values['alpha'] = Obj1, 'Values[alpha] should be Obj1');
    Assert(H.Values['missing'] = nil, 'missing key returns nil');
    H.Remove('alpha'); // frees Obj1 (owns objects)
    Assert(not H.Contains('alpha'), 'alpha removed');
    Assert(H.Count = 1, 'count should be 1 after remove');
  finally
    H.Free; // frees Obj2
  end;
  WriteLn('  PASS');
end;

procedure TestHashtableCaseSensitive;
var
  H: THashtable;
begin
  WriteLn('Test: THashtable (case-sensitive)');
  H := THashtable.Create(True { CaseSensitive }, True);
  try
    H.Add('Key', TObject.Create);
    Assert(H.Contains('Key'), 'should contain exact-case Key');
    Assert(not H.Contains('key'), 'case-sensitive: should not contain key');
  finally
    H.Free;
  end;
  WriteLn('  PASS');
end;

procedure TestIntegerList;
var
  L: TIntegerList;
begin
  WriteLn('Test: TIntegerList (integer/pointer round-trip)');
  L := TIntegerList.Create;
  try
    Assert(L.Add(10) = 0, 'first Add returns index 0');
    Assert(L.Add(20) = 1, 'second Add returns index 1');
    Assert(L.Count = 2, 'count should be 2');
    Assert(L.Items[0] = 10, 'Items[0] should be 10');
    Assert(L.Items[1] = 20, 'Items[1] should be 20');
    L.Items[1] := 99;
    Assert(L.Items[1] = 99, 'Items[1] should be 99 after assignment');
  finally
    L.Free;
  end;
  WriteLn('  PASS');
end;

procedure TestStringDictionary;
var
  D: TStringDictionary;
begin
  WriteLn('Test: TStringDictionary');
  D := TStringDictionary.Create;
  try
    D.Add('k1', 'v1');
    D.Add('k2', 'v2');
    Assert(D.Count = 2, 'count should be 2');
    Assert(D.Contains('k1'), 'should contain k1');
    Assert(D.Values['k1'] = 'v1', 'Values[k1] should be v1');
    Assert(D.Find('k2') = 'v2', 'Find(k2) should be v2');
    Assert(D.Values['missing'] = '', 'missing key returns empty string');
  finally
    D.Free;
  end;
  WriteLn('  PASS');
end;

procedure TestStringCollection;
var
  C: TStringCollection;
begin
  WriteLn('Test: TStringCollection');
  C := TStringCollection.Create;
  try
    C.Add('a');
    C.Add('b');
    Assert(C.Contains('a'), 'should contain a');
    Assert(not C.Contains('z'), 'should not contain z');
    C.RemoveAt(0);
    Assert(not C.Contains('a'), 'a removed');
    Assert(C.Count = 1, 'count should be 1 after RemoveAt');
  finally
    C.Free;
  end;
  WriteLn('  PASS');
end;

procedure RunContainerTests;
begin
  WriteLn('DelphiParserContainers Tests:');
  WriteLn('-----------------------------');
  TestHashtableCaseInsensitive;
  TestHashtableCaseSensitive;
  TestIntegerList;
  TestStringDictionary;
  TestStringCollection;
  WriteLn;
  WriteLn(Format('Container Test Summary: Passed: %d  Failed: %d', [ TestsPassed, TestsFailed ]));
end;

end.
