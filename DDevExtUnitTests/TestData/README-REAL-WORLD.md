# Real-World DFM Test Files

## Purpose
These are actual production DFM files from the DBiWorkflow project. They test the parser against real-world complexity instead of synthetic examples.

## Test Files

### RealWorld_DataModule.dfm
**Source:** `DBiAdmin\dmImages.dfm`
**Size:** ~169 lines, ~12KB
**Features:**
- Data module (not a form)
- `TSVGIconImageCollection` with collection items
- **Multi-line string concatenation** with `+` operator
- **Embedded XML/SVG** as string literals
- `#10` line feed characters in strings
- Very long concatenated strings (stress test)

**Why Important:** Tests the most complex multi-line string handling - SVG XML embedded in DFM with line breaks and special characters.

### RealWorld_LoginDialog.dfm
**Source:** `DBManager\logindlg.dfm`
**Size:** ~167 lines, ~7KB
**Features:**
- Standard dialog form
- `TPageControl` with `TTabSheet` components
- `TGroupBox` nested containers
- Typical VCL controls (TEdit, TButton, TLabel, TCheckBox)
- Standard property types (integers, strings, booleans)

**Why Important:** Representative of 80% of Delphi forms - dialogs with standard VCL controls.

### RealWorld_StatusViewer.dfm
**Source:** `DBiWorkflow\JTStatusViewFrm.dfm`
**Size:** ~371 lines, ~10KB
**Features:**
- Larger form (371 lines)
- Likely has TListView or TStringGrid
- Multiple nested panels/containers
- Action lists
- More complex layout

**Why Important:** Tests parser performance and nested component handling on larger forms.

### RealWorld_PrintForm.dfm
**Source:** `DBiStore\POPrintFrm.dfm`
**Size:** ~131 lines, ~3KB
**Features:**
- Report/print-related components
- Possibly QuickReport or FastReport components
- Dataset connections

**Why Important:** Tests third-party component support if present.

### RealWorld_BackupDialog.dfm
**Source:** `DBManager\backupdlg.dfm`
**Size:** Smaller, simpler dialog
**Features:**
- Simple utility dialog
- Basic VCL controls
- Fewer nested components

**Why Important:** Baseline for simple forms - should always pass if parser works at all.

## Expected Test Outcomes

### If Parser is Solid:
- ✅ All 5 files parse without errors
- ✅ All 5 files round-trip losslessly (Parse → Serialize = original)
- ✅ DataModule file tests complex multi-line string concatenation
- ✅ StatusViewer tests performance on larger forms

### If Parser Needs Work:
- ⚠️ DataModule file may fail on multi-line SVG strings with `+` concatenation
- ⚠️ Forms with collections may fail if collection parsing incomplete
- ✅ Simpler dialogs (Login, Backup) should still pass

## Using These Files

### In DUnitX Tests:
```delphi
[Test]
procedure TestFileRoundTrip_RealWorld_DataModule;
var
  FileName: string;
  Original, Serialized: string;
  Doc: TDfmDocument;
begin
  FileName := 'TestData\RealWorld_DataModule.dfm';
  if not FileExists(FileName) then
    Assert.Pass('Test file not found - run COPY-REAL-WORLD-TESTS.bat');

  Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Doc := TDelphiDfmParser.Parse(Original);
  try
    Serialized := TDelphiDfmParser.Serialize(Doc);
    Assert.AreEqual(Original, Serialized, 'Real-world DataModule round-trip must be lossless');
  finally
    Doc.Free;
  end;
end;
```

### Manual Testing:
1. Run `COPY-REAL-WORLD-TESTS.bat` to copy files
2. Run DUnitX test suite
3. Check which real-world files pass/fail
4. Debug against failing files

## Benefits of Real-World Testing

1. **Authentic complexity** - Not synthetic test data
2. **Edge cases we didn't think of** - Real code has surprises
3. **Performance validation** - Real forms can be large
4. **Component diversity** - Tests SVG collections, PageControls, data modules
5. **Confidence** - If it parses production DFMs, it's production-ready

## Notes

- Files are **copies** - originals in DBiWorkflow are never modified
- Files are **read-only** in tests - no writes, completely safe
- Files can be **updated** anytime by re-running the batch file
- Add more files by editing `COPY-REAL-WORLD-TESTS.bat`
