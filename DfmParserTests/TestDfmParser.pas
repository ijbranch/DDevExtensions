unit TestDfmParser;

interface

procedure RunAllTests;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils,
  gllDelphiDFMParser;

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

procedure TestSimpleProperties;
var
  Doc: TDfmDocument;
  DfmText: string;
begin
  WriteLn('Test: Simple properties');

  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  Caption = ''My Form''' + #13#10 +
    '  Width = 800' + #13#10 +
    '  Visible = True' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Assert(Doc.Root.Name = 'Form1', 'Root name should be Form1');
    Assert(Doc.Root.TypeName = 'TForm1', 'Root type should be TForm1');
    Assert(Doc.Root.Properties.Count = 3, 'Should have 3 properties');
    Assert(Doc.Root.FindProperty('Caption') <> nil, 'Caption property should exist');
    Assert(Doc.Root.FindProperty('Width') <> nil, 'Width property should exist');
    Assert(Doc.Root.FindProperty('Visible') <> nil, 'Visible property should exist');
    Assert(Doc.LineEnding = #13#10, 'Line ending should be CRLF');

    WriteLn('  PASS');
  finally
    Doc.Free;
  end;
end;

procedure TestRoundTrip;
var
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  WriteLn('Test: Round-trip (parse then serialize)');

  Original :=
    'object FormTest: TFormTest' + #13#10 +
    '  Left = 0' + #13#10 +
    '  Top = 0' + #13#10 +
    '  Caption = ''Test Form''' + #13#10 +
    '  ClientHeight = 300' + #13#10 +
    '  ClientWidth = 400' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);

    Assert(Original = Serialized,
           'Round-trip failed' + #13#10 +
           'Original length: ' + IntToStr(Length(Original)) + #13#10 +
           'Serialized length: ' + IntToStr(Length(Serialized)));

    WriteLn('  PASS - Round-trip preserved exactly');
  finally
    Doc.Free;
  end;
end;

procedure TestNestedComponents;
var
  Doc: TDfmDocument;
  Panel: TDfmComponent;
  DfmText: string;
begin
  WriteLn('Test: Nested components');

  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  object Panel1: TPanel' + #13#10 +
    '    Align = alTop' + #13#10 +
    '    object Button1: TButton' + #13#10 +
    '      Caption = ''OK''' + #13#10 +
    '    end' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Assert(Doc.Root.Children.Count = 1, 'Form should have 1 child');
    Panel := Doc.Root.Children[0];
    Assert(Panel.Name = 'Panel1', 'Child should be Panel1');
    Assert(Panel.TypeName = 'TPanel', 'Child type should be TPanel');
    Assert(Panel.Children.Count = 1, 'Panel should have 1 child');
    Assert(Panel.Children[0].Name = 'Button1', 'Panel child should be Button1');
    Assert(Panel.Children[0].TypeName = 'TButton', 'Button type should be TButton');

    WriteLn('  PASS');
  finally
    Doc.Free;
  end;
end;

procedure TestInheritedKeyword;
var
  Doc: TDfmDocument;
  DfmText: string;
begin
  WriteLn('Test: Inherited keyword');

  DfmText :=
    'object Form2: TForm2' + #13#10 +
    '  inherited Panel1: TPanel' + #13#10 +
    '    Caption = ''Modified''' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Assert(Doc.Root.Children.Count = 1, 'Form should have 1 child');
    Assert(Doc.Root.Children[0].ObjectKind = dokInherited, 'Child should be inherited');
    Assert(Doc.Root.Children[0].Name = 'Panel1', 'Inherited component name should be Panel1');

    WriteLn('  PASS');
  finally
    Doc.Free;
  end;
end;

procedure TestPropertyModification;
var
  Doc: TDfmDocument;
  Original, Modified: string;
begin
  WriteLn('Test: Property modification');

  Original :=
    'object Form1: TForm1' + #13#10 +
    '  Caption = ''Original''' + #13#10 +
    '  Width = 800' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(Original);
  try
    // Modify property
    Doc.Root.SetProperty('Caption', '''Modified''');

    // Delete property
    Doc.Root.DeleteProperty('Width');

    // Add new property
    Doc.Root.SetProperty('Height', '600');

    Modified := TDelphiDfmParser.Serialize(Doc);

    Assert(Pos('Modified', Modified) > 0, 'Modified caption should be in output');
    Assert(Pos('Width', Modified) = 0, 'Width should be deleted');
    Assert(Pos('Height', Modified) > 0, 'Height should be added');

    WriteLn('  PASS');
  finally
    Doc.Free;
  end;
end;

procedure TestFileRoundTrip(const FileName: string);
var
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  WriteLn('Test file: ' + ExtractFileName(FileName));

  if not FileExists(FileName) then
  begin
    WriteLn('  SKIP - File not found');
    Exit;
  end;

  Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);

    Assert(Original = Serialized,
           'Round-trip failed for ' + FileName + #13#10 +
           'Original length: ' + IntToStr(Length(Original)) + #13#10 +
           'Serialized length: ' + IntToStr(Length(Serialized)));

    WriteLn('  PASS - Round-trip preserved exactly');
  finally
    Doc.Free;
  end;
end;

procedure RunAllTests;
begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn('Unit Tests:');
  WriteLn('-----------');
  TestSimpleProperties;
  TestRoundTrip;
  TestNestedComponents;
  TestInheritedKeyword;
  TestPropertyModification;

  WriteLn;
  WriteLn('Round-trip File Tests:');
  WriteLn('----------------------');

  if TDirectory.Exists('TestData') then
  begin
    var Files := TDirectory.GetFiles('TestData', '*.dfm');
    if Length(Files) = 0 then
      WriteLn('  No test files found in TestData folder')
    else
    begin
      for var FileName in Files do
        TestFileRoundTrip(FileName);
      WriteLn;
      WriteLn('Total files tested: ' + IntToStr(Length(Files)));
    end;
  end
  else
    WriteLn('  TestData directory not found - skipping file tests');

  WriteLn;
  WriteLn('Test Summary:');
  WriteLn('-------------');
  WriteLn('Passed: ' + IntToStr(TestsPassed));
  WriteLn('Failed: ' + IntToStr(TestsFailed));
end;

end.
