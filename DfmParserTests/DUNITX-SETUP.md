# DUnitX Setup Instructions

## What is DUnitX?

DUnitX is a modern unit testing framework for Delphi. It provides:
- Clean test fixture syntax with attributes
- VCL GUI test runner
- Console test runner
- XML output for CI/CD integration

## Installation

### Option 1: Via GetIt Package Manager (Recommended for RAD Studio 10.2+)
1. In Delphi IDE, go to **Tools → GetIt Package Manager**
2. Search for "DUnitX"
3. Click **Install**
4. Restart Delphi

### Option 2: Manual Installation from GitHub
1. Clone the repository:
   ```
   git clone https://github.com/VSoftTechnologies/DUnitX.git
   ```
2. Add the library path in Delphi:
   - **Tools → Options → Language → Delphi → Library**
   - Add to Library Path:
     - `C:\path\to\DUnitX\Source`
     - `C:\path\to\DUnitX\Source\Loggers`

### Option 3: Use Existing DUnitX in RAD Studio
DUnitX may already be included with your RAD Studio installation:
- Check: `C:\Program Files (x86)\Embarcadero\Studio\37.0\source\DUnitX\`
- If present, just add to Library Path

## Compiling the Tests

```batch
cd D:\DDevExtensions\DfmParserTests
dcc32 DfmParserTestsDUnitX.dpr
```

## Running the Tests

### GUI Mode (Default)
```batch
DfmParserTestsDUnitX.exe
```

This opens the VCL GUI showing:
- Test tree on the left
- Progress bar
- Pass/Fail status
- Detailed failure messages
- Execution time per test

### Console Mode
```batch
DfmParserTestsDUnitX.exe -console
```

### XML Output (for CI/CD)
```batch
DfmParserTestsDUnitX.exe -xml:results.xml
```

## Test Attributes Reference

Common DUnitX attributes used in `TestDfmParserDUnitX.pas`:

- `[TestFixture]` - Marks a class as a test fixture
- `[Setup]` - Runs before each test
- `[TearDown]` - Runs after each test
- `[Test]` - Marks a method as a test case
- `[Ignore('reason')]` - Skip this test
- `[Category('CategoryName')]` - Organize tests by category

## Assertions Reference

```delphi
Assert.AreEqual(expected, actual, 'message');
Assert.AreNotEqual(expected, actual, 'message');
Assert.IsTrue(condition, 'message');
Assert.IsFalse(condition, 'message');
Assert.IsNotNull(value, 'message');
Assert.IsNull(value, 'message');
Assert.Pass('message');           // Mark test as passed
Assert.Fail('message');           // Force test failure
Assert.WillRaise(proc, ExceptionClass);  // Expect exception
```

## Troubleshooting

### "Unit DUnitX.TestFramework not found"
- DUnitX is not installed or not in library path
- Follow installation instructions above

### "Access violation" on test run
- Usually means a test is accessing freed memory
- Check that all `Doc.Free` calls are in `try..finally` blocks

### Tests show as "Ignored"
- Check for `[Ignore]` attribute
- Check TestData folder exists and contains .dfm files for file tests

## Further Reading

- DUnitX GitHub: https://github.com/VSoftTechnologies/DUnitX
- Documentation: https://github.com/VSoftTechnologies/DUnitX/wiki
