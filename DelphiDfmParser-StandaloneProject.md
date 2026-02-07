# DelphiDfmParser - Standalone Implementation Plan

## ✅ STATUS: COMPLETE (2025-02-08)

**All objectives achieved. Parser is production-ready.**

- ✅ 32 comprehensive tests passing (DUnitX VCL GUI)
- ✅ Lossless round-trip verified on 11 test files (6 synthetic + 5 real-world)
- ✅ Handles all DFM features: binary, collections, sets, parenthesized lists, multi-line strings
- ✅ Real-world validation: 5 production DFM files from DBiWorkflow (67 KB total)
- ✅ Zero memory leaks, zero failures

**Location:** `D:\DDevExtensions\Shared\PascalParser\gllDelphiDFMParser.pas`
**Tests:** `D:\DDevExtensions\DfmParserTests\DfmParserTestsDUnitX.exe`

---

## Project Goal

Build a **lossless DFM parser** as a standalone, reusable unit with comprehensive testing before integrating into DDevExtensions. The parser must guarantee `Serialize(Parse(text)) = text` for all valid DFM files.

---

## Project Structure

```
D:\DDevExtensions\
  Shared\PascalParser\
    gllDelphiDFMParser.pas        # Main parser unit
  DfmParserTests\                 # NEW - Standalone test project
    DfmParserTests.dpr            # Test console application
    TestDfmParser.pas             # Test cases
    TestData\                     # Test DFM files
      Simple.dfm                  # Basic form with simple properties
      Nested.dfm                  # Nested components (panels, buttons)
      MultiLine.dfm               # Multi-line string properties
      Binary.dfm                  # Binary data (bitmaps, icons)
      Collections.dfm             # Collection properties (columns, items)
      Inherited.dfm               # Visual form inheritance
      Complex.dfm                 # Real-world complex form
      AllValueTypes.dfm           # Every DFM value type
```

---

## Implementation Phases

### Phase 1: Core Parser Structure (Foundation)

**File:** `D:\DDevExtensions\Shared\PascalParser\gllDelphiDFMParser.pas`

**No dependencies** - Pure RTL (SysUtils, Classes, Generics.Collections)

#### Classes to implement:

```pascal
type
  TDfmValueKind = (
    dvkSimple,       // Name = Value
    dvkString,       // Name = 'string'
    dvkMultiLine,    // Name = 'line1' + #13#10 + 'line2'
    dvkSet,          // Name = [item1, item2]
    dvkBinary,       // Name = { hex bytes }
    dvkCollection,   // Name = < ... >
    dvkParenList     // Name = ( item1 item2 )
  );

  TDfmProperty = class
  private
    FName:       string;
    FValueKind:  TDfmValueKind;
    FRawValue:   string;    // Everything after '=' preserving exact formatting
    FIndent:     string;    // Leading whitespace before property name
  public
    property Name:      string read FName write FName;
    property ValueKind: TDfmValueKind read FValueKind write FValueKind;
    property RawValue:  string read FRawValue write FRawValue;
    property Indent:    string read FIndent write FIndent;
  end;

  TDfmObjectKind = ( dokObject, dokInherited, dokInline );

  TDfmComponent = class
  private
    FName:         string;
    FTypeName:     string;
    FObjectKind:   TDfmObjectKind;
    FProperties:   TObjectList<TDfmProperty>;
    FChildren:     TObjectList<TDfmComponent>;
    FIndent:       string;       // Leading whitespace of 'object' line
    FEndIndent:    string;       // Leading whitespace of 'end' line
  public
    constructor Create;
    destructor Destroy; override;

    function FindProperty( const PropName: string ): TDfmProperty;
    function FindChild( const ChildName: string ): TDfmComponent;
    procedure DeleteProperty( const PropName: string );
    procedure SetProperty( const PropName, Value: string );

    property Name:       string read FName write FName;
    property TypeName:   string read FTypeName write FTypeName;
    property ObjectKind: TDfmObjectKind read FObjectKind write FObjectKind;
    property Properties: TObjectList<TDfmProperty> read FProperties;
    property Children:   TObjectList<TDfmComponent> read FChildren;
    property Indent:     string read FIndent write FIndent;
    property EndIndent:  string read FEndIndent write FEndIndent;
  end;

  TDfmDocument = class
  private
    FRoot:         TDfmComponent;
    FLineEnding:   string;   // Detected CRLF or LF
    FHeader:       string;   // Any text before first 'object' (rare)
    FTrailer:      string;   // Any text after final 'end' (rare)
  public
    constructor Create;
    destructor Destroy; override;

    property Root:        TDfmComponent read FRoot;
    property LineEnding:  string read FLineEnding;
  end;

  TDelphiDfmParser = class
  public
    class function Parse( const DfmText: string ): TDfmDocument;
    class function Serialize( Doc: TDfmDocument ): string;
  end;
```

#### Key implementation details:

**Line ending detection:**
```pascal
// In Parse, detect first
if Pos(#13#10, DfmText) > 0 then
  FLineEnding := #13#10
else if Pos(#10, DfmText) > 0 then
  FLineEnding := #10
else
  FLineEnding := #13#10;  // Default
```

**Parsing state machine:**
```pascal
// Simplified algorithm
Lines := TStringList.Create;
Lines.Text := DfmText;

Stack: TStack<TDfmComponent>;  // Component nesting
CurrentProperty: TDfmProperty := nil;
InBinary := False;    // Inside { }
InCollection := False; // Inside < >
BraceDepth := 0;
AngleDepth := 0;

for each Line do
begin
  TrimmedLine := TrimLeft(Line);
  Indent := Copy(Line, 1, Length(Line) - Length(TrimmedLine));

  // Object/inherited/inline detection
  if StartsWithKeyword(TrimmedLine, 'object', 'inherited', 'inline') then
  begin
    Component := ParseComponentDeclaration(TrimmedLine, Indent);
    Stack.Push(Component);
    continue;
  end;

  // End detection
  if TrimmedLine = 'end' then
  begin
    Stack.Top.EndIndent := Indent;
    Stack.Pop;
    continue;
  end;

  // Property detection (contains '=')
  if (Pos('=', TrimmedLine) > 0) and (CurrentProperty = nil) then
  begin
    CurrentProperty := ParsePropertyStart(Line, Indent);
    Stack.Top.Properties.Add(CurrentProperty);

    // Check for multi-line continuations
    if Contains(Line, '{') then InBinary := True;
    if Contains(Line, '<') then InCollection := True;
    // etc.
  end
  else if CurrentProperty <> nil then
  begin
    // Continuation line - append to RawValue
    CurrentProperty.RawValue := CurrentProperty.RawValue + LineEnding + Line;

    // Check for termination
    if InBinary and Contains(Line, '}') then InBinary := False;
    if InCollection and Contains(Line, '>') then InCollection := False;

    if not InBinary and not InCollection then
      CurrentProperty := nil;  // Done with this property
  end;
end;
```

**Serialization algorithm:**
```pascal
procedure SerializeComponent(Component: TDfmComponent; Lines: TStringList);
begin
  // Object declaration
  Lines.Add(Component.Indent + KeywordToString(Component.ObjectKind) +
            ' ' + Component.Name + ': ' + Component.TypeName);

  // Properties
  for Prop in Component.Properties do
    Lines.Add(Prop.Indent + Prop.Name + ' = ' + Prop.RawValue);

  // Children (recursive)
  for Child in Component.Children do
    SerializeComponent(Child, Lines);

  // End
  Lines.Add(Component.EndIndent + 'end');
end;
```

---

### Phase 2: Test Infrastructure

**File:** `D:\DDevExtensions\DfmParserTests\DfmParserTests.dpr`

Console test runner using simple assertions:

```pascal
program DfmParserTests;

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  DelphiDfmParser in '..\Shared\PascalParser\DelphiDfmParser.pas',
  TestDfmParser in 'TestDfmParser.pas';

begin
  try
    WriteLn('DelphiDfmParser Test Suite');
    WriteLn('===========================');
    WriteLn;

    RunAllTests;

    WriteLn;
    WriteLn('All tests passed!');
  except
    on E: Exception do
    begin
      WriteLn('FAILED: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
```

**File:** `D:\DDevExtensions\DfmParserTests\TestDfmParser.pas`

```pascal
unit TestDfmParser;

interface

procedure RunAllTests;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils,
  DelphiDfmParser;

procedure Assert(Condition: Boolean; const Msg: string);
begin
  if not Condition then
    raise Exception.Create('Assertion failed: ' + Msg);
end;

procedure TestRoundTrip(const FileName: string);
var
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  WriteLn('Testing: ' + FileName);

  Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);

    Assert(Original = Serialized,
           'Round-trip failed for ' + FileName + #13#10 +
           'Length: ' + IntToStr(Length(Original)) + ' vs ' + IntToStr(Length(Serialized)));

    WriteLn('  PASS - Round-trip preserved exactly');
  finally
    Doc.Free;
  end;
end;

procedure TestSimpleProperties;
var
  Doc: TDfmDocument;
begin
  WriteLn('Testing: Simple properties');

  Doc := TDelphiDfmParser.Parse(
    'object Form1: TForm1' + #13#10 +
    '  Caption = ''My Form''' + #13#10 +
    '  Width = 800' + #13#10 +
    '  Visible = True' + #13#10 +
    'end' + #13#10);
  try
    Assert(Doc.Root.Name = 'Form1', 'Root name');
    Assert(Doc.Root.TypeName = 'TForm1', 'Root type');
    Assert(Doc.Root.Properties.Count = 3, 'Property count');
    Assert(Doc.Root.FindProperty('Caption') <> nil, 'Caption property');
    Assert(Doc.Root.FindProperty('Width') <> nil, 'Width property');
    Assert(Doc.Root.LineEnding = #13#10, 'Line ending');

    WriteLn('  PASS - Simple properties parsed correctly');
  finally
    Doc.Free;
  end;
end;

procedure TestNestedComponents;
var
  Doc: TDfmDocument;
  Panel: TDfmComponent;
begin
  WriteLn('Testing: Nested components');

  Doc := TDelphiDfmParser.Parse(
    'object Form1: TForm1' + #13#10 +
    '  object Panel1: TPanel' + #13#10 +
    '    Align = alTop' + #13#10 +
    '    object Button1: TButton' + #13#10 +
    '      Caption = ''OK''' + #13#10 +
    '    end' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10);
  try
    Assert(Doc.Root.Children.Count = 1, 'Form has 1 child');
    Panel := Doc.Root.Children[0];
    Assert(Panel.Name = 'Panel1', 'Panel name');
    Assert(Panel.Children.Count = 1, 'Panel has 1 child');
    Assert(Panel.Children[0].Name = 'Button1', 'Button name');

    WriteLn('  PASS - Nested components parsed correctly');
  finally
    Doc.Free;
  end;
end;

procedure TestBinaryData;
var
  Doc: TDfmDocument;
  Prop: TDfmProperty;
begin
  WriteLn('Testing: Binary data');

  Doc := TDelphiDfmParser.Parse(
    'object Form1: TForm1' + #13#10 +
    '  Bitmap = {' + #13#10 +
    '    424D3E00000000000000360000002800000010000000100000000100' + #13#10 +
    '    180000000000080000000000000000000000000000000000000000FF' + #13#10 +
    '  }' + #13#10 +
    'end' + #13#10);
  try
    Prop := Doc.Root.FindProperty('Bitmap');
    Assert(Prop <> nil, 'Bitmap property exists');
    Assert(Prop.ValueKind = dvkBinary, 'Bitmap is binary');
    Assert(Pos('{', Prop.RawValue) > 0, 'Binary contains brace');
    Assert(Pos('}', Prop.RawValue) > 0, 'Binary contains closing brace');

    WriteLn('  PASS - Binary data parsed correctly');
  finally
    Doc.Free;
  end;
end;

procedure TestCollections;
var
  Doc: TDfmDocument;
  Prop: TDfmProperty;
begin
  WriteLn('Testing: Collections');

  Doc := TDelphiDfmParser.Parse(
    'object ListView1: TListView' + #13#10 +
    '  Columns = <' + #13#10 +
    '    item' + #13#10 +
    '      Caption = ''Name''' + #13#10 +
    '      Width = 150' + #13#10 +
    '    end' + #13#10 +
    '    item' + #13#10 +
    '      Caption = ''Value''' + #13#10 +
    '    end>' + #13#10 +
    'end' + #13#10);
  try
    Prop := Doc.Root.FindProperty('Columns');
    Assert(Prop <> nil, 'Columns property exists');
    Assert(Prop.ValueKind = dvkCollection, 'Columns is collection');
    Assert(Pos('<', Prop.RawValue) > 0, 'Collection contains angle bracket');

    WriteLn('  PASS - Collections parsed correctly');
  finally
    Doc.Free;
  end;
end;

procedure TestInheritedKeyword;
var
  Doc: TDfmDocument;
begin
  WriteLn('Testing: Inherited keyword');

  Doc := TDelphiDfmParser.Parse(
    'object Form2: TForm2' + #13#10 +
    '  inherited Panel1: TPanel' + #13#10 +
    '    Caption = ''Modified''' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10);
  try
    Assert(Doc.Root.Children.Count = 1, 'Form has 1 child');
    Assert(Doc.Root.Children[0].ObjectKind = dokInherited, 'Child is inherited');
    Assert(Doc.Root.Children[0].Name = 'Panel1', 'Inherited component name');

    WriteLn('  PASS - Inherited keyword handled correctly');
  finally
    Doc.Free;
  end;
end;

procedure RunAllTests;
begin
  // Unit tests
  TestSimpleProperties;
  TestNestedComponents;
  TestBinaryData;
  TestCollections;
  TestInheritedKeyword;

  WriteLn;
  WriteLn('Round-trip tests:');

  // Round-trip tests with real DFM files
  if TDirectory.Exists('TestData') then
  begin
    for var FileName in TDirectory.GetFiles('TestData', '*.dfm') do
      TestRoundTrip(FileName);
  end
  else
    WriteLn('  SKIPPED - TestData directory not found');
end;

end.
```

---

### Phase 3: Test Data Creation

Create test DFM files covering all cases:

**TestData\Simple.dfm:**
```delphi
object FormSimple: TFormSimple
  Left = 0
  Top = 0
  Caption = 'Simple Form'
  ClientHeight = 300
  ClientWidth = 400
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
end
```

**TestData\Nested.dfm:**
```delphi
object FormNested: TFormNested
  Caption = 'Nested'
  object Panel1: TPanel
    Align = alTop
    Height = 41
    object Button1: TButton
      Left = 10
      Top = 10
      Caption = 'OK'
    end
    object Button2: TButton
      Left = 100
      Top = 10
      Caption = 'Cancel'
    end
  end
end
```

**TestData\MultiLine.dfm:**
```delphi
object FormMultiLine: TFormMultiLine
  Caption = 'Multi-line test'
  object Memo1: TMemo
    Lines.Strings = (
      'Line 1'
      'Line 2 with ''quotes'''
      'Line 3')
  end
end
```

*(Additional test files for binary, collections, inherited, complex forms)*

---

### Phase 4: Edge Cases & Refinement

Test and handle:

1. **Empty DFMs** - Just `object Form1: TForm1 end`
2. **No properties** - Component with children but no properties
3. **Property-only components** - No children
4. **Mixed line endings** - CRLF + LF in same file (normalize on read)
5. **Whitespace variations** - Tabs vs spaces, inconsistent indentation
6. **String escaping** - Single quotes in strings (`''`)
7. **Numeric formats** - Integers, floats, hex ($FF), negative values
8. **Set notation** - `[fsUnderline, fsBold]`, `[]` (empty set)
9. **Multi-line strings with concatenation** - `'Line1' + #13#10 + 'Line2'`
10. **Inline keyword** - `inline Frame1: TFrame1`
11. **Comments in DFM** - Are they allowed? (No in standard DFMs)
12. **Unicode strings** - UTF-8 encoded property values

---

### Phase 5: Documentation

**README in DfmParserTests folder:**
```markdown
# DelphiDfmParser - Lossless DFM Text Parser

## Purpose
Parse and serialize Delphi .dfm (form) files with exact fidelity - round-trip guarantee.

## Usage
```pascal
uses gllDelphiDFMParser;

var
  DfmText: string;
  Doc: TDfmDocument;
begin
  DfmText := TFile.ReadAllText('MyForm.dfm');
  Doc := TDelphiDfmParser.Parse(DfmText);
  try
    // Navigate structure
    ShowMessage(Doc.Root.Name);                    // 'Form1'
    ShowMessage(Doc.Root.TypeName);                // 'TForm1'
    ShowMessage(Doc.Root.Properties.Count);        // '15'

    // Find properties
    var Prop := Doc.Root.FindProperty('Caption');
    ShowMessage(Prop.RawValue);                    // '''My Form'''

    // Modify
    Doc.Root.TypeName := 'TNewFormClass';
    Prop.RawValue := '''New Caption''';

    // Serialize back
    var Modified := TDelphiDfmParser.Serialize(Doc);
    TFile.WriteAllText('MyForm.dfm', Modified);
  finally
    Doc.Free;
  end;
end;
```

## Running Tests
```
cd DfmParserTests
dcc32 DfmParserTests.dpr
DfmParserTests.exe
```

## Design Goals
- **Lossless** - Parse then serialize = exact original
- **No dependencies** - Pure RTL
- **Standalone** - Usable outside DDevExtensions
- **Well-tested** - Comprehensive test suite
```

---

## Development Order

1. **Create test project structure** - DfmParserTests folder, .dpr, TestData folder
2. **Write minimal parser** - Just parse `object Name: Type ... end` structure
3. **Write minimal serializer** - Output what was parsed
4. **Test round-trip with simplest DFM** - Fix until it works
5. **Add property parsing** - Simple properties first
6. **Test round-trip again** - Iterate
7. **Add multi-line property handling** - Binary, collections, strings
8. **Add nested component handling** - Recursion
9. **Add inherited/inline keywords**
10. **Test with real-world DFM files** - From existing Delphi projects
11. **Document and polish**

---

## Success Criteria

- [x] **All unit tests pass** - 32/32 tests passing in DUnitX VCL GUI
- [x] **Round-trip test passes for 10+ real DFM files** - 11 files tested (6 synthetic + 5 production)
- [x] **Zero crashes on malformed input** - Graceful error handling implemented
- [x] **Parser handles all Delphi 10.2+ DFM features** - Binary, collections, sets, strings, parenthesized lists
- [x] **Code is documented** - XML doc comments on all public classes/methods
- [x] **README explains usage clearly** - Comprehensive documentation in DfmParserTests\README.md
- [x] **Ready for integration** - Fully tested and production-ready

---

## Integration Status

✅ **COMPLETED**

1. ✅ `gllDelphiDFMParser.pas` already in `Shared\PascalParser\`
2. ✅ Available for use in DDevExtensions features
3. ✅ Test project in `DfmParserTests\` with DUnitX VCL GUI runner
4. ✅ Ready for Component Replacer integration (see `ComponentReplacer-ImplementationPlan.md`)
