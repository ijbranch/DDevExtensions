unit TestDfmParserDUnitX;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  gllDelphiDFMParser;

type
  [TestFixture]
  TTestDelphiDfmParser = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Basic parsing tests
    [Test]
    procedure TestSimpleProperties;
    [Test]
    procedure TestNestedComponents;
    [Test]
    procedure TestInheritedKeyword;
    [Test]
    procedure TestInlineKeyword;

    // Round-trip tests
    [Test]
    procedure TestRoundTripSimple;
    [Test]
    procedure TestRoundTripNested;

    // Property manipulation tests
    [Test]
    procedure TestPropertyModification;
    [Test]
    procedure TestPropertyDeletion;
    [Test]
    procedure TestPropertyAddition;

    // Advanced value type tests
    [Test]
    procedure TestBinaryData;
    [Test]
    procedure TestCollectionProperties;
    [Test]
    procedure TestMultiLineStrings;
    [Test]
    procedure TestSetProperties;
    [Test]
    procedure TestParenthesizedLists;

    // Edge case tests
    [Test]
    procedure TestEmptyDfm;
    [Test]
    procedure TestComponentWithNoProperties;
    [Test]
    procedure TestComponentWithNoChildren;
    [Test]
    procedure TestEscapedQuotes;
    [Test]
    procedure TestHexColorValues;
    [Test]
    procedure TestEmptySet;
    [Test]
    procedure TestNegativeNumbers;

    // File round-trip tests
    [Test]
    procedure TestFileRoundTrip_Simple;
    [Test]
    procedure TestFileRoundTrip_Nested;
    [Test]
    procedure TestFileRoundTrip_Binary;
    [Test]
    procedure TestFileRoundTrip_Collections;
    [Test]
    procedure TestFileRoundTrip_MultiLineStrings;
    [Test]
    procedure TestFileRoundTrip_Complex;

    // Real-world file tests from DBiWorkflow
    [Test]
    procedure TestFileRoundTrip_RealWorld_BackupDialog;
    [Test]
    procedure TestFileRoundTrip_RealWorld_DataModule;
    [Test]
    procedure TestFileRoundTrip_RealWorld_LoginDialog;
    [Test]
    procedure TestFileRoundTrip_RealWorld_PrintForm;
    [Test]
    procedure TestFileRoundTrip_RealWorld_StatusViewer;
  end;

implementation

procedure TTestDelphiDfmParser.Setup;
begin
  // Setup code (if needed)
end;

procedure TTestDelphiDfmParser.TearDown;
begin
  // Teardown code (if needed)
end;

{ Basic Parsing Tests }

procedure TTestDelphiDfmParser.TestSimpleProperties;
var
  Doc: TDfmDocument;
  DfmText: string;
begin
  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  Caption = ''My Form''' + #13#10 +
    '  Width = 800' + #13#10 +
    '  Visible = True' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Assert.AreEqual('Form1', Doc.Root.Name, 'Root name');
    Assert.AreEqual('TForm1', Doc.Root.TypeName, 'Root type');
    Assert.AreEqual<Integer>(3, Doc.Root.Properties.Count, 'Property count');
    Assert.IsNotNull(Doc.Root.FindProperty('Caption'), 'Caption property exists');
    Assert.IsNotNull(Doc.Root.FindProperty('Width'), 'Width property exists');
    Assert.IsNotNull(Doc.Root.FindProperty('Visible'), 'Visible property exists');
    Assert.AreEqual(#13#10, Doc.LineEnding, 'Line ending');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestNestedComponents;
var
  Doc: TDfmDocument;
  Panel: TDfmComponent;
  DfmText: string;
begin
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
    Assert.AreEqual<Integer>(1, Doc.Root.Children.Count, 'Form has 1 child');
    Panel := Doc.Root.Children[0];
    Assert.AreEqual('Panel1', Panel.Name, 'Panel name');
    Assert.AreEqual('TPanel', Panel.TypeName, 'Panel type');
    Assert.AreEqual<Integer>(1, Panel.Children.Count, 'Panel has 1 child');
    Assert.AreEqual('Button1', Panel.Children[0].Name, 'Button name');
    Assert.AreEqual('TButton', Panel.Children[0].TypeName, 'Button type');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestInheritedKeyword;
var
  Doc: TDfmDocument;
  DfmText: string;
begin
  DfmText :=
    'object Form2: TForm2' + #13#10 +
    '  inherited Panel1: TPanel' + #13#10 +
    '    Caption = ''Modified''' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Assert.AreEqual<Integer>(1, Doc.Root.Children.Count, 'Form has 1 child');
    Assert.IsTrue(Doc.Root.Children[0].ObjectKind = dokInherited, 'Child is inherited');
    Assert.AreEqual('Panel1', Doc.Root.Children[0].Name, 'Component name');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestInlineKeyword;
var
  Doc: TDfmDocument;
  DfmText: string;
begin
  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  inline Frame1: TFrame1' + #13#10 +
    '    Align = alClient' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Assert.AreEqual<Integer>(1, Doc.Root.Children.Count, 'Form has 1 child');
    Assert.IsTrue(Doc.Root.Children[0].ObjectKind = dokInline, 'Child is inline');
    Assert.AreEqual('Frame1', Doc.Root.Children[0].Name, 'Frame name');
  finally
    Doc.Free;
  end;
end;

{ Round-Trip Tests }

procedure TTestDelphiDfmParser.TestRoundTripSimple;
var
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
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
    Assert.AreEqual(Original, Serialized, 'Round-trip must be lossless');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestRoundTripNested;
var
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  Original :=
    'object Form1: TForm1' + #13#10 +
    '  Caption = ''Nested Test''' + #13#10 +
    '  object Panel1: TPanel' + #13#10 +
    '    Align = alTop' + #13#10 +
    '    Height = 50' + #13#10 +
    '    object Button1: TButton' + #13#10 +
    '      Caption = ''Click Me''' + #13#10 +
    '    end' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);
    Assert.AreEqual(Original, Serialized, 'Nested round-trip must be lossless');
  finally
    Doc.Free;
  end;
end;

{ Property Manipulation Tests }

procedure TTestDelphiDfmParser.TestPropertyModification;
var
  Doc: TDfmDocument;
  Prop: TDfmProperty;
  DfmText: string;
begin
  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  Caption = ''Original''' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Doc.Root.SetProperty('Caption', '''Modified''');
    Prop := Doc.Root.FindProperty('Caption');
    Assert.IsNotNull(Prop, 'Caption property exists');
    Assert.AreEqual('''Modified''', Prop.RawValue, 'Caption value modified');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestPropertyDeletion;
var
  Doc: TDfmDocument;
  DfmText: string;
begin
  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  Caption = ''Test''' + #13#10 +
    '  Width = 800' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Assert.AreEqual<Integer>(2, Doc.Root.Properties.Count, 'Initial property count');
    Doc.Root.DeleteProperty('Width');
    Assert.AreEqual<Integer>(1, Doc.Root.Properties.Count, 'Property count after deletion');
    Assert.IsNull(Doc.Root.FindProperty('Width'), 'Width property deleted');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestPropertyAddition;
var
  Doc: TDfmDocument;
  DfmText: string;
begin
  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  Caption = ''Test''' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Assert.AreEqual<Integer>(1, Doc.Root.Properties.Count, 'Initial property count');
    Doc.Root.SetProperty('Width', '800');
    Assert.AreEqual<Integer>(2, Doc.Root.Properties.Count, 'Property count after addition');
    Assert.IsNotNull(Doc.Root.FindProperty('Width'), 'Width property added');
  finally
    Doc.Free;
  end;
end;

{ Advanced Value Type Tests }

procedure TTestDelphiDfmParser.TestBinaryData;
var
  Doc: TDfmDocument;
  Prop: TDfmProperty;
  DfmText: string;
begin
  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  Bitmap.Data = {' + #13#10 +
    '    424D3E00000000000000360000002800000010000000100000000100' + #13#10 +
    '    180000000000080000000000000000000000000000000000000000FF}' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Prop := Doc.Root.FindProperty('Bitmap.Data');
    Assert.IsNotNull(Prop, 'Binary property exists');
    Assert.IsTrue(Prop.ValueKind = dvkBinary, 'Property is binary type');
    Assert.IsTrue(Pos('{', Prop.RawValue) > 0, 'Binary contains opening brace');
    Assert.IsTrue(Pos('}', Prop.RawValue) > 0, 'Binary contains closing brace');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestCollectionProperties;
var
  Doc: TDfmDocument;
  Prop: TDfmProperty;
  DfmText: string;
begin
  DfmText :=
    'object ListView1: TListView' + #13#10 +
    '  Columns = <' + #13#10 +
    '    item' + #13#10 +
    '      Caption = ''Name''' + #13#10 +
    '      Width = 150' + #13#10 +
    '    end' + #13#10 +
    '    item' + #13#10 +
    '      Caption = ''Value''' + #13#10 +
    '      Width = 200' + #13#10 +
    '    end>' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Prop := Doc.Root.FindProperty('Columns');
    Assert.IsNotNull(Prop, 'Columns property exists');
    Assert.IsTrue(Prop.ValueKind = dvkCollection, 'Property is collection type');
    Assert.IsTrue(Pos('<', Prop.RawValue) > 0, 'Collection contains opening angle');
    Assert.IsTrue(Pos('>', Prop.RawValue) > 0, 'Collection contains closing angle');
    Assert.IsTrue(Pos('item', Prop.RawValue) > 0, 'Collection contains item');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestMultiLineStrings;
var
  Doc: TDfmDocument;
  Prop: TDfmProperty;
  DfmText: string;
begin
  DfmText :=
    'object Memo1: TMemo' + #13#10 +
    '  Lines.Strings = (' + #13#10 +
    '    ''Line 1''' + #13#10 +
    '    ''Line 2 with ''''quotes''''' + #13#10 +
    '    ''Line 3'')' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Prop := Doc.Root.FindProperty('Lines.Strings');
    Assert.IsNotNull(Prop, 'Lines.Strings property exists');
    Assert.IsTrue(Prop.ValueKind = dvkParenList, 'Property is paren list type');
    Assert.IsTrue(Pos('Line 1', Prop.RawValue) > 0, 'Contains Line 1');
    Assert.IsTrue(Pos('Line 2', Prop.RawValue) > 0, 'Contains Line 2');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestSetProperties;
var
  Doc: TDfmDocument;
  Prop: TDfmProperty;
  DfmText: string;
begin
  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  Font.Style = [fsBold, fsItalic]' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Prop := Doc.Root.FindProperty('Font.Style');
    Assert.IsNotNull(Prop, 'Font.Style property exists');
    Assert.IsTrue(Prop.ValueKind = dvkSet, 'Property is set type');
    Assert.IsTrue(Pos('[', Prop.RawValue) > 0, 'Set contains opening bracket');
    Assert.IsTrue(Pos(']', Prop.RawValue) > 0, 'Set contains closing bracket');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestParenthesizedLists;
var
  Doc: TDfmDocument;
  Prop: TDfmProperty;
  DfmText: string;
begin
  DfmText :=
    'object ComboBox1: TComboBox' + #13#10 +
    '  Items.Strings = (' + #13#10 +
    '    ''Item 1''' + #13#10 +
    '    ''Item 2''' + #13#10 +
    '    ''Item 3'')' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Prop := Doc.Root.FindProperty('Items.Strings');
    Assert.IsNotNull(Prop, 'Items.Strings property exists');
    Assert.IsTrue(Prop.ValueKind = dvkParenList, 'Property is paren list type');
  finally
    Doc.Free;
  end;
end;

{ Edge Case Tests }

procedure TTestDelphiDfmParser.TestEmptyDfm;
var
  Doc: TDfmDocument;
  DfmText: string;
begin
  DfmText :=
    'object Form1: TForm1' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Assert.AreEqual('Form1', Doc.Root.Name, 'Root name');
    Assert.AreEqual<Integer>(0, Doc.Root.Properties.Count, 'No properties');
    Assert.AreEqual<Integer>(0, Doc.Root.Children.Count, 'No children');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestComponentWithNoProperties;
var
  Doc: TDfmDocument;
  DfmText: string;
begin
  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  object Panel1: TPanel' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Assert.AreEqual<Integer>(1, Doc.Root.Children.Count, 'Has 1 child');
    Assert.AreEqual<Integer>(0, Doc.Root.Children[0].Properties.Count, 'Child has no properties');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestComponentWithNoChildren;
var
  Doc: TDfmDocument;
  DfmText: string;
begin
  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  Caption = ''Test''' + #13#10 +
    '  Width = 800' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Assert.AreEqual<Integer>(2, Doc.Root.Properties.Count, 'Has properties');
    Assert.AreEqual<Integer>(0, Doc.Root.Children.Count, 'Has no children');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestEscapedQuotes;
var
  Doc: TDfmDocument;
  Prop: TDfmProperty;
  DfmText: string;
begin
  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  Caption = ''It''''s OK''' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Prop := Doc.Root.FindProperty('Caption');
    Assert.IsNotNull(Prop, 'Caption exists');
    Assert.IsTrue(Pos('''''', Prop.RawValue) > 0, 'Contains escaped quote');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestHexColorValues;
var
  Doc: TDfmDocument;
  Prop: TDfmProperty;
  DfmText: string;
begin
  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  Color = $00FF00FF' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Prop := Doc.Root.FindProperty('Color');
    Assert.IsNotNull(Prop, 'Color property exists');
    Assert.AreEqual('$00FF00FF', Prop.RawValue, 'Hex value preserved');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestEmptySet;
var
  Doc: TDfmDocument;
  Prop: TDfmProperty;
  DfmText: string;
begin
  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  Font.Style = []' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Prop := Doc.Root.FindProperty('Font.Style');
    Assert.IsNotNull(Prop, 'Font.Style exists');
    Assert.AreEqual('[]', Prop.RawValue, 'Empty set preserved');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestNegativeNumbers;
var
  Doc: TDfmDocument;
  Prop: TDfmProperty;
  DfmText: string;
begin
  DfmText :=
    'object Form1: TForm1' + #13#10 +
    '  Left = -100' + #13#10 +
    '  Top = -50' + #13#10 +
    'end' + #13#10;

  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    Prop := Doc.Root.FindProperty('Left');
    Assert.IsNotNull(Prop, 'Left exists');
    Assert.AreEqual('-100', Prop.RawValue, 'Negative number preserved');
  finally
    Doc.Free;
  end;
end;

{ File Round-Trip Tests }

procedure TTestDelphiDfmParser.TestFileRoundTrip_Simple;
var
  FileName: string;
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  FileName := 'TestData\Simple.dfm';
  if not FileExists(FileName) then
    Assert.Pass('Test file not found - skipped');

  Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);
    Assert.AreEqual(Original, Serialized, 'File round-trip must be lossless');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestFileRoundTrip_Nested;
var
  FileName: string;
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  FileName := 'TestData\Nested.dfm';
  if not FileExists(FileName) then
    Assert.Pass('Test file not found - skipped');

  Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);
    Assert.AreEqual(Original, Serialized, 'File round-trip must be lossless');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestFileRoundTrip_Binary;
var
  FileName: string;
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  FileName := 'TestData\Binary.dfm';
  if not FileExists(FileName) then
    Assert.Pass('Test file not found - skipped');

  Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);
    Assert.AreEqual(Original, Serialized, 'Binary file round-trip must be lossless');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestFileRoundTrip_Collections;
var
  FileName: string;
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  FileName := 'TestData\Collections.dfm';
  if not FileExists(FileName) then
    Assert.Pass('Test file not found - skipped');

  Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);
    Assert.AreEqual(Original, Serialized, 'Collections file round-trip must be lossless');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestFileRoundTrip_MultiLineStrings;
var
  FileName: string;
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  FileName := 'TestData\MultiLineStrings.dfm';
  if not FileExists(FileName) then
    Assert.Pass('Test file not found - skipped');

  Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);
    Assert.AreEqual(Original, Serialized, 'MultiLine strings file round-trip must be lossless');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestFileRoundTrip_Complex;
var
  FileName: string;
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  FileName := 'TestData\Complex.dfm';
  if not FileExists(FileName) then
    Assert.Pass('Test file not found - skipped');

  Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);
    Assert.AreEqual(Original, Serialized, 'Complex file round-trip must be lossless');
  finally
    Doc.Free;
  end;
end;

{ Real-World File Tests }

procedure TTestDelphiDfmParser.TestFileRoundTrip_RealWorld_BackupDialog;
var
  FileName: string;
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  FileName := 'TestData\RealWorld_BackupDialog.dfm';
  if not FileExists(FileName) then
    Assert.Pass('Real-world test file not found - run COPY-REAL-WORLD-TESTS.bat');

  Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);
    Assert.AreEqual(Original, Serialized, 'Real-world BackupDialog round-trip must be lossless');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestFileRoundTrip_RealWorld_DataModule;
var
  FileName: string;
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  FileName := 'TestData\RealWorld_DataModule.dfm';
  if not FileExists(FileName) then
    Assert.Pass('Real-world test file not found - run COPY-REAL-WORLD-TESTS.bat');

  Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);
    Assert.AreEqual(Original, Serialized, 'Real-world DataModule round-trip must be lossless');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestFileRoundTrip_RealWorld_LoginDialog;
var
  FileName: string;
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  FileName := 'TestData\RealWorld_LoginDialog.dfm';
  if not FileExists(FileName) then
    Assert.Pass('Real-world test file not found - run COPY-REAL-WORLD-TESTS.bat');

  Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);
    Assert.AreEqual(Original, Serialized, 'Real-world LoginDialog round-trip must be lossless');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestFileRoundTrip_RealWorld_PrintForm;
var
  FileName: string;
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  FileName := 'TestData\RealWorld_PrintForm.dfm';
  if not FileExists(FileName) then
    Assert.Pass('Real-world test file not found - run COPY-REAL-WORLD-TESTS.bat');

  Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);
    Assert.AreEqual(Original, Serialized, 'Real-world PrintForm round-trip must be lossless');
  finally
    Doc.Free;
  end;
end;

procedure TTestDelphiDfmParser.TestFileRoundTrip_RealWorld_StatusViewer;
var
  FileName: string;
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  FileName := 'TestData\RealWorld_StatusViewer.dfm';
  if not FileExists(FileName) then
    Assert.Pass('Real-world test file not found - run COPY-REAL-WORLD-TESTS.bat');

  Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);
    Assert.AreEqual(Original, Serialized, 'Real-world StatusViewer round-trip must be lossless');
  finally
    Doc.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDelphiDfmParser);

end.
