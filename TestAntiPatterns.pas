unit TestAntiPatterns;

{------------------------------------------------------------------------------
  Test unit for DDevExtensions v3.7.0 Anti-Pattern Detection

  This file intentionally contains code anti-patterns to test the
  Code Style Checker's new detection features.

  Expected detections:
  - EmptyFinally: 2 instances
  - NestedWith: 1 instance
  - DeepNesting: 1 instance (5 levels deep)
  - LongMethod: 1 instance (LongMethod procedure)
  - LongParamList: 2 instances (7+ parameters)

  DELETE THIS FILE AFTER TESTING
------------------------------------------------------------------------------}

interface

type
  TAntiPatternTest = class
  private
    FValue: Integer;
    FName: string;
  public
    constructor Create;

    // LongParamList: 7 parameters (exceeds default threshold of 6)
    procedure ProcessData(Param1: Integer; Param2: Integer; Param3: string;
      Param4: Boolean; Param5: Double; Param6: Integer; Param7: string);

    // LongParamList: 8 parameters
    function CalculateResult(A, B, C, D, E, F, G, H: Integer): Integer;

    procedure TestEmptyFinally;
    procedure TestNestedWith;
    procedure TestDeepNesting;
  end;

implementation

uses
  SysUtils, Classes;

constructor TAntiPatternTest.Create;
begin
  inherited Create;
  FValue := 0;
  FName := '';
end;

procedure TAntiPatternTest.ProcessData(Param1: Integer; Param2: Integer;
  Param3: string; Param4: Boolean; Param5: Double; Param6: Integer;
  Param7: string);
begin
  // Just a stub for testing long parameter list detection
  FValue := Param1 + Param2;
end;

function TAntiPatternTest.CalculateResult(A, B, C, D, E, F, G, H: Integer): Integer;
begin
  // Another long parameter list test
  Result := A + B + C + D + E + F + G + H;
end;

procedure TAntiPatternTest.TestEmptyFinally;
var
  Stream: TStringList;
begin
  // EmptyFinally #1: This finally block is empty
  Stream := TStringList.Create;
  try
    Stream.Add('Test');
  finally
    // Empty - should be flagged!
  end;

  // EmptyFinally #2: Another empty finally
  try
    FValue := 42;
  finally
    // Also empty - should be flagged!
  end;
end;

procedure TAntiPatternTest.TestNestedWith;
var
  List1: TStringList;
  List2: TStringList;
begin
  List1 := TStringList.Create;
  List2 := TStringList.Create;
  try
    // NestedWith: with statements nested more than 1 level deep
    with List1 do
    begin
      Add('Item 1');
      with List2 do  // Nested with - should be flagged!
      begin
        Add('Item 2');
        Clear;
      end;
    end;
  finally
    List2.Free;
    List1.Free;
  end;
end;

procedure TAntiPatternTest.TestDeepNesting;
var
  I, J, K: Integer;
  Done: Boolean;
begin
  Done := False;

  // DeepNesting: 5 levels of control flow nesting (exceeds default of 4)
  for I := 0 to 10 do                    // Level 1
  begin
    if I > 2 then                        // Level 2
    begin
      for J := 0 to 5 do                 // Level 3
      begin
        if J > 1 then                    // Level 4
        begin
          try                            // Level 5 - should be flagged!
            K := I * J;
            if K > 20 then
              Done := True;
          except
            on E: Exception do
              Done := False;
          end;
        end;
      end;
    end;
  end;

  if Done then
    FValue := 1;
end;

// LongMethod: This procedure exceeds 100 lines (default threshold)
procedure LongMethod;
var
  A, B, C, D, E: Integer;
  S: string;
begin
  // Line 1-10
  A := 1;
  B := 2;
  C := 3;
  D := 4;
  E := 5;
  S := 'Test';
  A := A + 1;
  B := B + 1;
  C := C + 1;
  D := D + 1;

  // Line 11-20
  E := E + 1;
  A := A * 2;
  B := B * 2;
  C := C * 2;
  D := D * 2;
  E := E * 2;
  S := S + '1';
  S := S + '2';
  S := S + '3';
  S := S + '4';

  // Line 21-30
  A := 10;
  B := 20;
  C := 30;
  D := 40;
  E := 50;
  S := 'Line 26';
  S := 'Line 27';
  S := 'Line 28';
  S := 'Line 29';
  S := 'Line 30';

  // Line 31-40
  A := 11;
  B := 21;
  C := 31;
  D := 41;
  E := 51;
  S := 'Line 36';
  S := 'Line 37';
  S := 'Line 38';
  S := 'Line 39';
  S := 'Line 40';

  // Line 41-50
  A := 12;
  B := 22;
  C := 32;
  D := 42;
  E := 52;
  S := 'Line 46';
  S := 'Line 47';
  S := 'Line 48';
  S := 'Line 49';
  S := 'Line 50';

  // Line 51-60
  A := 13;
  B := 23;
  C := 33;
  D := 43;
  E := 53;
  S := 'Line 56';
  S := 'Line 57';
  S := 'Line 58';
  S := 'Line 59';
  S := 'Line 60';

  // Line 61-70
  A := 14;
  B := 24;
  C := 34;
  D := 44;
  E := 54;
  S := 'Line 66';
  S := 'Line 67';
  S := 'Line 68';
  S := 'Line 69';
  S := 'Line 70';

  // Line 71-80
  A := 15;
  B := 25;
  C := 35;
  D := 45;
  E := 55;
  S := 'Line 76';
  S := 'Line 77';
  S := 'Line 78';
  S := 'Line 79';
  S := 'Line 80';

  // Line 81-90
  A := 16;
  B := 26;
  C := 36;
  D := 46;
  E := 56;
  S := 'Line 86';
  S := 'Line 87';
  S := 'Line 88';
  S := 'Line 89';
  S := 'Line 90';

  // Line 91-100
  A := 17;
  B := 27;
  C := 37;
  D := 47;
  E := 57;
  S := 'Line 96';
  S := 'Line 97';
  S := 'Line 98';
  S := 'Line 99';
  S := 'Line 100';

  // Line 101-105 - exceeds 100 line threshold
  A := 18;
  B := 28;
  C := 38;
  D := 48;
  E := 58;
end;

end.
