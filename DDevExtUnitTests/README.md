# DDevExtensions Unit Tests

DUnitX test suites for the DDevExtensions cores - the units deliberately kept free of ToolsAPI,
VCL and the IDE so they can be tested outside it.

| Test unit | Unit under test | Tests |
|-----------|-----------------|-------|
| `TestDfmParserDUnitX.pas` | `gllDelphiDFMParser` - lossless DFM parse/serialise | 34 |
| `TestPathCompactorDUnitX.pas` | `PathCompactorCore` - library-path macro compaction | 25 |
| `TestProjectGroupSorterDUnitX.pas` | `ProjectGroupSorterCore` - `.groupproj` sorting | 11 |
| `TestUsesClauseManagerCoreDUnitX.pas` | `UsesClauseManagerCore` - uses-clause placement | 27 |
| `TestDecirculariserCoreDUnitX.pas` | `DecirculariserCore` - circular reference analysis, start-up code, `RemoveUsesEntry` | 43 |
| `TestMethodSeparatorsCoreDUnitX.pas` | `MethodSeparatorsCore` - method separator scan and colours | 24 |
| `TestDelphiLexerDUnitX.pas` | `DelphiLexer` - token kinds, line/column contract | 9 |
| `TestDelphiParserContainersDUnitX.pas` | `DelphiParserContainers` - hashtable, lists, dictionary | 5 |
| `TestDelphiExprDUnitX.pas` | `DelphiExpr` - `$IF` expression nodes and parser | 5 |
| `TestDelphiPreprocDUnitX.pas` | `DelphiPreproc` - conditional branch selection | 4 |
| `TestUnitMetricsDUnitX.pas` | `UnitMetrics` - LOC and cyclomatic complexity | 4 |
| | **Total** | **191** |

The hand-rolled console runner `DDevExtUnitTests.dpr` was retired on 2026-10-21; its checks live on in the
DUnitX fixtures above.  All 191 pass; `TestDelphiParserContainersDUnitX.TestHashtableCaseSensitive`, red
when first converted, exposed the missing `COMPILERx_UP` defines, since resolved (see `../UnitTestCoverage-Plan.md`).

The rest of this document describes the DFM parser suite specifically.

## Test Application

**Headless (Release):** `DDevExtUnitTestsDUnitX.exe` - console output, an NUnit XML report
(`bin\DDevExtUnitTestsDUnitX-results.xml`, or the file `--xmlfile:` names) and the estate exit code:
0 green, failures + errors capped at 249, 250 when no test ran, 251 when the runner itself failed
(an unknown option included).  This is what CI should call, and what `test_run` runs as target
`DDevExtUnitTestsDUnitX`.  `--run:Unit.TFixture[.Test]` runs one fixture or test.
**TestInsight (Debug):** the Debug configuration defines `TESTINSIGHT` and runs under the IDE.
**VCL GUI:** build with `GUI_TEST_RUNNER` defined for the DUnitX GUI runner.
**Project:** `DDevExtUnitTestsDUnitX.dpr`
**Test Units:** every `Test*DUnitX.pas` in the table above

## Running Tests

### VCL GUI (Recommended)

**Double-click** `DDevExtUnitTestsDUnitX.exe` to launch the VCL GUI test runner.

Or from RAD Studio IDE:
1. Open `DDevExtUnitTestsDUnitX.dpr`
2. Press **F9** to compile and run
3. Click **Run All** in the GUI

### Console Mode

```bash
bin/DDevExtUnitTestsDUnitX.exe --exitbehavior:Continue
```
Runs the Release build headless: console output, `DDevExtUnitTestsDUnitX-results.xml` beside the
exe, non-zero exit code on red.  One fixture:
`bin/DDevExtUnitTestsDUnitX.exe --run:TestDelphiExprDUnitX.TTestDelphiExpr`.

## DFM Parser Coverage - 34 Tests (All Passing ✅)

### Basic Parsing (4 tests)
- ✓ Simple properties
- ✓ Nested components
- ✓ Inherited keyword
- ✓ Inline keyword

### Round-Trip Verification (2 tests)
- ✓ Simple round-trip (parse → serialize = identical)
- ✓ Nested round-trip

### Property Manipulation (3 tests)
- ✓ Property modification
- ✓ Property deletion
- ✓ Property addition
- ✓ Modify, delete and add all reach the serialised text

### Advanced Value Types (5 tests)
- ✓ Binary data (hex blobs in `{ }`)
- ✓ Collection properties (`< item ... end >`)
- ✓ Multi-line strings (parenthesized lists)
- ✓ Set properties (`[item1, item2]`)
- ✓ Parenthesized lists (`( 'string' 'string' )`)

### Edge Cases (7 tests)
- ✓ Empty DFM files
- ✓ Components with no properties
- ✓ Components with no children
- ✓ Escaped quotes (`''`)
- ✓ Hex color values (`$00FF00FF`)
- ✓ Empty sets (`[]`)
- ✓ Negative numbers

### File Round-Trips (12 tests)

One test per file below, plus a sweep that round-trips every `.dfm` in `TestData`.

**Synthetic Test Files (6):**
- `Simple.dfm` - Basic form with properties
- `Nested.dfm` - Nested components
- `Binary.dfm` - TImage with PNG binary data
- `Collections.dfm` - TListView columns, TActionList actions
- `MultiLineStrings.dfm` - TMemo, TComboBox with multi-line strings
- `Complex.dfm` - PageControl, GroupBox, StringGrid (real-world complexity)

**Real-World Production Files from DBiWorkflow (5):**
- `RealWorld_BackupDialog.dfm` (35 KB) - Multi-line string concatenation with `+`
- `RealWorld_DataModule.dfm` (12 KB) - SVG icon collection with embedded XML
- `RealWorld_LoginDialog.dfm` (7 KB) - PageControl, TabSheets, GroupBoxes
- `RealWorld_PrintForm.dfm` (3 KB) - Print/report components
- `RealWorld_StatusViewer.dfm` (10 KB) - 371 lines, complex layout

## Real-World Test Files

To populate the real-world test files:

```bash
COPY-REAL-WORLD-TESTS.bat
```

This copies 5 production DFM files from `E:\DBiWorkflow Development` to `TestData\`.

## Parser Features Validated

✅ **Lossless Round-Trip**: Parse(text) → Serialize() = identical text (byte-for-byte)
✅ **Line Ending Preservation**: CRLF vs LF detection and preservation
✅ **Whitespace Preservation**: Exact indentation maintained
✅ **Binary Data**: Multi-line hex data in `{ }` with depth tracking
✅ **Collections**: Multi-line collection items in `< >` with depth tracking
✅ **Parenthesized Lists**: String lists in `( )` with depth tracking
✅ **String Concatenation**: Multi-line strings with `+` operator
✅ **Empty Property Values**: Properties where value starts on next line
✅ **Set Properties**: Enum sets in `[ ]`
✅ **Object Keywords**: `object`, `inherited`, `inline`
✅ **Nested Components**: Arbitrary depth component hierarchy

## Parser Implementation

**Location:** `D:\DDevExtensions\Shared\PascalParser\gllDelphiDFMParser.pas`

**Key Classes:**
- `TDfmDocument` - Root document (line ending, header/trailer)
- `TDfmComponent` - Component (name, type, properties, children)
- `TDfmProperty` - Property (name, raw value, indent, value kind)
- `TDelphiDfmParser` - Static parser (`Parse()` and `Serialize()`)

**Design Philosophy:**
- **Raw value storage** - Values stored as exact character sequences
- **No interpretation** - Parser never interprets values
- **Exact fidelity** - Round-trip produces byte-for-byte identical output

## Test Results

**✅ All 34 DFM-parser tests passing** (191 tests across the whole suite, 1 red - see above):
- Synthetic test cases covering all DFM features
- Real-world production DFM files from DBiWorkflow (5 files, 67 KB total)

## Next Steps

This parser is production-ready for integration into the **Component Replacer** feature.

---

*Part of DDevExtensions - Delphi IDE Enhancement Suite*
