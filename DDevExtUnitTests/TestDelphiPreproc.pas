unit TestDelphiPreproc;

/// <summary>
/// Console-driven tests for <c>DelphiPreproc</c>, the conditional-compilation preprocessor
/// layered on the lexer. Drives $IFDEF/$IFNDEF/$ELSE/$ENDIF, nested blocks and in-source
/// $DEFINE/$UNDEF via the Define/Undefine API (no event resolvers needed), asserting which
/// branch's tokens survive. Writes PASS lines + a summary; raises on first failure.
/// </summary>

interface

/// <summary>Runs every preprocessor test, writing PASS lines and a summary; raises on failure.</summary>
procedure RunPreprocTests;

implementation

uses
  System.SysUtils, System.Classes,
  DelphiLexer, DelphiPreproc, DelphiParserContainers;

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

/// <summary>Collects the surviving identifier tokens (space-separated) after preprocessing.</summary>
function SurvivingIdents(const Src: string; const DefineName: string): string;
var
  Pre: TDelphiPreprocessor;
  Tok: TToken;
  Guard: Integer;
begin
  Result := '';
  Pre := TDelphiPreprocessor.Create('test.pas', UTF8String(Src));
  try
    if DefineName <> '' then
      Pre.Define(DefineName);
    Guard := 0;
    repeat
      Tok := Pre.GetToken(False);
      if Tok = nil then
        Break;
      if Tok.Kind = tkIdent then
      begin
        if Result <> '' then
          Result := Result + ' ';
        Result := Result + string(Tok.Value);
      end;
      Inc(Guard);
    until Guard > 10000;
  finally
    Pre.Free;
  end;
end;

procedure TestIfdef;
var
  Src: string;
begin
  WriteLn('Test: $IFDEF / $ELSE branch selection');
  Src := '{$IFDEF FOO}'#13#10 +
         '  Alpha;'#13#10 +
         '{$ELSE}'#13#10 +
         '  Beta;'#13#10 +
         '{$ENDIF}'#13#10;
  Assert(SurvivingIdents(Src, 'FOO') = 'Alpha', 'FOO defined -> Alpha branch');
  Assert(SurvivingIdents(Src, '') = 'Beta', 'FOO undefined -> Beta branch');
  WriteLn('  PASS');
end;

procedure TestIfndef;
var
  Src: string;
begin
  WriteLn('Test: $IFNDEF branch selection');
  Src := '{$IFNDEF BAR}'#13#10 +
         '  NoBar;'#13#10 +
         '{$ELSE}'#13#10 +
         '  HasBar;'#13#10 +
         '{$ENDIF}'#13#10;
  Assert(SurvivingIdents(Src, '') = 'NoBar', 'BAR undefined -> NoBar branch');
  Assert(SurvivingIdents(Src, 'BAR') = 'HasBar', 'BAR defined -> HasBar branch');
  WriteLn('  PASS');
end;

procedure TestNestedIfdef;
var
  Src: string;
begin
  WriteLn('Test: nested $IFDEF (outer defined, inner not)');
  // OUTER defined but INNER not -> only Outer survives (Inner is skipped).
  Src := '{$IFDEF OUTER}'#13#10 +
         '  Outer;'#13#10 +
         '  {$IFDEF INNER}'#13#10 +
         '    Inner;'#13#10 +
         '  {$ENDIF}'#13#10 +
         '{$ENDIF}'#13#10;
  Assert(SurvivingIdents(Src, 'OUTER') = 'Outer', 'outer-only define keeps Outer, skips Inner');
  Assert(SurvivingIdents(Src, '') = '', 'outer undefined -> whole block skipped');
  WriteLn('  PASS');
end;

procedure TestDefineUndef;
var
  Pre: TDelphiPreprocessor;
begin
  WriteLn('Test: in-source $DEFINE / $UNDEF and Defines state');
  // In-source $DEFINE then $IFDEF
  Assert(SurvivingIdents('{$DEFINE LOCALDEF}{$IFDEF LOCALDEF}Yes{$ENDIF}', '') = 'Yes',
    'in-source $DEFINE enables the block');
  // $DEFINE then $UNDEF -> else branch
  Assert(SurvivingIdents('{$DEFINE D}{$UNDEF D}{$IFDEF D}Yes{$ELSE}No{$ENDIF}', '') = 'No',
    '$UNDEF after $DEFINE selects the else branch');

  // Define() API reflected in the Defines table
  Pre := TDelphiPreprocessor.Create('test.pas', UTF8String(''));
  try
    Pre.Define('XYZ');
    Assert(Pre.Defines.Contains('XYZ'), 'Define(XYZ) is reflected in Defines');
    Pre.Undefine('XYZ');
    Assert(not Pre.Defines.Contains('XYZ'), 'Undefine(XYZ) removes it from Defines');
  finally
    Pre.Free;
  end;
  WriteLn('  PASS');
end;

procedure RunPreprocTests;
begin
  WriteLn('DelphiPreproc Tests:');
  WriteLn('--------------------');
  TestIfdef;
  TestIfndef;
  TestNestedIfdef;
  TestDefineUndef;
  WriteLn;
  WriteLn(Format('Preproc Test Summary: Passed: %d  Failed: %d', [ TestsPassed, TestsFailed ]));
end;

end.
