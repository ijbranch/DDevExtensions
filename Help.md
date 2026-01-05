# DDevExtensions Help Guide

Version 3.5.2 | Comprehensive Feature Reference

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Getting Started](#getting-started)
3. [Recommended Usage Sequence](#recommended-usage-sequence)
4. [Feature Reference (A-Z)](#feature-reference-a-z)
5. [Troubleshooting](#troubleshooting)

---

## Quick Reference

| Feature | Default | Access Method |
|---------|---------|---------------|
| Auto-save After Compile | OFF | Options |
| Build Statistics | OFF | DDevExtensions submenu |
| Code Style Checker | ON | DDevExtensions submenu |
| Compile Backup | ON | Automatic |
| Compile Progress | ON | Automatic |
| Component Selector | OFF | Configurable hotkey |
| Confirm Ctrl+F1 While Debugging | ON | Automatic |
| Dead Code Detector | ON | DDevExtensions submenu |
| DFM/PAS Consistency Checker | ON | DDevExtensions submenu |
| Dependency Viewer | OFF | DDevExtensions submenu |
| Disable Package Cache | OFF | Options |
| Disable Source Formatter Hotkey | OFF | Options |
| Don't Break on Spawned Processes | OFF | Options |
| Editor Tab Double-Click | Zoom | Double-click tab |
| Empty Event Handler Detector | ON | DDevExtensions submenu |
| Enhanced Key Bindings | ON | Automatic |
| File Cleaner | ON | Automatic |
| Find Unit Replacement | ON | Ctrl+Shift+A |
| Kill dexplore.exe on Exit | ON | Automatic |
| Release Compiler Cache | OFF | Options |
| Remove Explicit* Properties | OFF | Options |
| Remove PixelsPerInch Property | OFF | Options |
| Remove TextHeight Property | OFF | Options |
| Replace Open File At Cursor | OFF | Options |
| Section Toggle (Interface/Implementation) | ON | Ctrl+Shift+Up/Down |
| Show All Inheritable Modules | OFF | Options |
| Show Project for Active File | ON | Automatic |
| Structure View Search | OFF | Configurable hotkey |
| Switch Project for File | ON | Automatic |
| TLabel.Margins.Bottom to Zero | ON | Automatic |
| TODO/FIXME Aggregator | ON | DDevExtensions submenu |
| Unreachable Code Detector | ON | DDevExtensions submenu |
| Unused Unit Detector | OFF | DDevExtensions submenu |
| Uses Clause Manager | ON | DDevExtensions submenu |

---

## Getting Started

### Accessing DDevExtensions Options

1. Open RAD Studio/Delphi IDE
2. Go to **Tools** > **DDevExtensions** > **Options...**
3. In the Options dialog, look for **DDevExtensions** in the left tree
4. Expand to see all feature categories

### DDevExtensions Menu Structure

All DDevExtensions tools are organized under a single submenu, ordered by workflow:

```
Tools
  └── DDevExtensions
        ├── Options...
        ├── ─────────────
        ├── Dependency Viewer...
        ├── Unused Unit Detector...
        ├── Uses Clause Manager...
        ├── Dead Code Detector...
        ├── Unreachable Code Detector...
        ├── TODO/FIXME Aggregator...
        ├── Code Style Checker...
        ├── Empty Event Handler Detector...
        └── DFM/PAS Consistency...
```

### Configuration Files

DDevExtensions stores settings in:
```
%APPDATA%\DDevExtensions\
```

Each feature has its own XML configuration file (e.g., `KeyBindings.xml`, `CompileProgress.xml`).

---

## Recommended Usage Sequence

While all features are independent and can be enabled/disabled individually, the following sequence provides a logical workflow for getting the most out of DDevExtensions.

### 1. Foundation Features (Enable First)

Start with these core enhancements that improve everyday IDE interaction:

| Feature | Why First |
|---------|-----------|
| **DSUFeatures** | Extended IDE settings provide the base configuration |
| **Editor Enhancements** | Core editing improvements you'll use constantly |
| **Enhanced Key Bindings** | Keyboard shortcuts for efficient navigation |

### 2. Navigation & Development

Once the foundation is set, enable features that speed up navigation and component work:

| Feature | Purpose |
|---------|---------|
| **UnitSelector** | Find/Use unit dialogs with fuzzy matching |
| **ComponentSelector** | Quick component search in form designer |
| **StrucViewSearch** | Filter Structure View to find methods quickly |
| **Section Toggle** | Jump between interface/implementation sections |

### 3. Build & Project Management

Add features that improve the compile and project workflow:

| Feature | Purpose |
|---------|---------|
| **CompileProgress** | Visual build progress and taskbar integration |
| **Build Statistics** | Track compile times and code metrics |
| **CompileBackup** | Pre-compile backup for safety |
| **FileCleaner** | Automatic cleanup of unnecessary files |
| **StartParameterTeam** | Shared start parameters across team |

### 4. Code Analysis Tools (Use After Codebase Established)

These tools analyze existing code patterns and dependencies. They're most valuable once your project structure is established:  This is the suggested usage sequence for these features:

| Feature | When to Use |
|---------|-------------|
| **DependencyViewer** | Understanding unit relationships and finding circular references |
| **UnusedUnitDetector** | Cleaning up uses clauses |
| **UsesClauseManager** | Optimizing uses clause organization |
| **DeadCodeDetector** | Finding unused procedures and fields |
| **UnreachableCodeDetector** | Finding code that never executes |
| **TodoAggregator** | Tracking TODO/FIXME comments across project |
| **CodeStyleChecker** | Enforcing naming conventions |
| **EmptyEventHandlerDetector** | Finding accidental empty handlers |
| **DfmPasConsistency** | Detecting DFM/PAS synchronization issues |

### Suggested Workflow

1. **New Project**: Start with Groups 1-3 enabled
2. **Code Review Phase**: Run Group 4 tools to identify issues
3. **Before Release**: Run all analysis tools for a final cleanup pass
4. **Maintenance**: Periodically run DependencyViewer and UsesClauseManager to keep architecture clean

### Key Notes

- All features can be disabled via environment variable: `DDevExtensions.DisabledFeatures` (semicolon-separated list)
- Each feature stores settings independently in `%APPDATA%\DDevExtensions\`
- No feature depends on another being enabled - use what works for your workflow

---

## Feature Reference (A-Z)

### Auto-save After Compile

**Purpose:** Automatically saves all modified editor files after a successful compilation.

**Default:** OFF

**Location:** Options > DDevExtensions > Compile Progress

---

### Build Statistics

**Purpose:** Tracks compilation time for each unit and displays code metrics.

**Default:** OFF

**Location:** Options > DDevExtensions > Compile Progress

**Access:** Tools > DDevExtensions > Build Statistics...

#### Features

- Per-unit compile time in milliseconds
- Lines of Code (LOC) per unit
- Cyclomatic Complexity per unit
- Sortable columns
- Filter: All / Project / External files
- Export to CSV
- Copy to clipboard
- Double-click to open unit (if source available)

#### How to Enable

1. Go to Options > DDevExtensions > Compile Progress
2. Check "Enable Build Statistics"
3. Optionally check "Show after compile" for automatic display

#### Understanding the Metrics

| Column | Description |
|--------|-------------|
| Unit Name | The unit being compiled |
| Duration | Compile time in ms, seconds, or minutes |
| LOC | Lines of Code (non-blank, non-comment) |
| Complexity | Cyclomatic complexity score |
| File Path | Full or relative path to source |

**Cyclomatic Complexity** measures the number of independent paths through code:
- 1-10: Simple, low risk
- 11-20: Moderate complexity
- 21-50: High complexity, consider refactoring
- 50+: Very high risk, should be simplified

#### Filter Options

- **All**: Shows all units compiled (project + external)
- **Project**: Only units that are part of your project
- **External**: RTL/VCL and third-party units

**Note:** Metrics (LOC, Complexity) only display when source code is available. External units without source show "-".

---

### Code Style Checker

**Purpose:** Checks code against Delphi naming conventions.

**Default:** ON

**Location:** Options > DDevExtensions > Code Style Checker

**Access:** Tools > DDevExtensions > Code Style Checker...

#### Rules

| Rule | Convention | Example |
|------|------------|---------|
| Types | Prefix with T | `TMyClass` |
| Interfaces | Prefix with I | `IMyInterface` |
| Fields | Prefix with F | `FMyField` |
| Exceptions | Prefix with E | `EMyError` |
| Pointers | Prefix with P | `PMyRecord` |
| Parameters | Prefix with A | `AValue` (optional) |

#### Configuration Options

Enable/disable individual rules:
- **Check Types**: T prefix for types
- **Check Interfaces**: I prefix for interfaces
- **Check Fields**: F prefix for fields
- **Check Exceptions**: E prefix for exceptions
- **Check Pointers**: P prefix for pointer types
- **Check Parameters**: A prefix for parameters (off by default)

#### How to Interpret Results

| Column | Description |
|--------|-------------|
| Unit | Source file name |
| Rule | Which naming rule was violated |
| Line | Line number |
| Identifier | The non-compliant name |
| Expected | What the name should start with |

---

### Compile Backup

**Purpose:** Creates backup copies of files before compilation.

**Default:** ON

**Location:** Options > DDevExtensions > Compile Backup

---

### Compile Progress

**Purpose:** Adds a progress bar to the compile dialog and shows compilation progress in the Windows taskbar.

**Default:** ON

**Location:** Options > DDevExtensions > Compile Progress

---

### Component Selector

**Purpose:** Provides a searchable popup dialog for quickly finding and selecting components.

**Default:** OFF (no hotkey assigned)

**Location:** Options > DDevExtensions > Component Selector

#### How to Use

1. Enable and assign a hotkey (e.g., Ctrl+Shift+C)
2. In the form designer, press the hotkey
3. Type to search for a component
4. Press Enter to select and place the component

---

### Confirm Ctrl+F1 While Debugging

**Purpose:** Shows a confirmation dialog before opening help during debug sessions.

**Default:** ON

**Location:** Options > DDevExtensions > Extended IDE Settings

**Why:** Prevents accidentally interrupting debugging to view help documentation.

---

### Dead Code Detector

**Purpose:** Finds procedures, functions, and fields that are never referenced.

**Default:** ON

**Location:** Options > DDevExtensions > Dead Code Detector

**Access:** Tools > DDevExtensions > Dead Code Detector...

#### What It Detects

- Unused procedures and functions
- Unused private fields
- Unused protected fields

#### What It Ignores (Automatically)

- Virtual/override methods (may be called polymorphically)
- Abstract methods
- Constructors and destructors
- Event handlers (OnClick, etc.)
- Published members (used by RTTI)
- Interface implementations

#### Configuration Options

- **Enabled**: Master switch
- **Check Procedures**: Detect unused procedures/functions
- **Check Fields**: Detect unused fields
- **Ignore List**: Patterns to skip (supports wildcards)

#### Ignore List Patterns

Use wildcards to ignore common patterns:
```
*Click
*Change
*Execute
Get*
Set*
```

#### How to Interpret Results

| Column | Description |
|--------|-------------|
| Unit | Source file name |
| Type | Procedure, Function, or Field |
| Name | The unused element |
| Scope | Private, Protected, Public |
| Line | Line number |

---

### DFM/PAS Consistency Checker (New in 3.4.1)

**Purpose:** Detects inconsistencies between DFM files and their corresponding PAS file field declarations.

**Default:** ON

**Location:** Options > DDevExtensions > DFM/PAS Consistency

**Access:** Tools > DDevExtensions > DFM/PAS Consistency...

#### Why Use This Tool?

When you rename or delete components in the form designer, sometimes the DFM and PAS files can get out of sync:

- A component is deleted from the DFM but the field declaration remains in the PAS (Missing in DFM)
- A component exists in the DFM but no field declaration in PAS (Missing in PAS)
- A field is renamed in the PAS but not updated in the DFM
- A component type is changed but the field type doesn't match (Type Mismatch)

These inconsistencies can cause runtime errors, access violations, or unexpected behavior.

#### What It Detects

| Issue Type | Description |
|------------|-------------|
| Missing in PAS | Component exists in DFM but field is not declared in the form class |
| Missing in DFM | Field declared in PAS but no corresponding component in DFM (orphaned declaration) |
| Type Mismatch | Component exists in both but types differ |

**Note:** "Missing in DFM" detection intelligently filters out false positives:
- Collection types: TStringList, TList, TDictionary, TStack, TQueue
- Graphics objects: TBitmap, TIcon, TPicture, TBrush, TPen, TFont
- Stream types: TStream and descendants
- Thread types: TThread and descendants
- Utility types: TIniFile, TRegistry, JSON types, XML types
- State/activity types: TGridDrawState, TCloseAction, TShiftState, etc.
- Abstract base classes: TDataSet, TField, TComponent, TControl, TWinControl
- Method parameters: Correctly skips procedure/function parameter declarations

#### How to Use

1. Open the tool via Tools > DDevExtensions > DFM/PAS Consistency...
2. Click "Scan Project" to analyze all forms in the project
3. Review the results showing any inconsistencies
4. Double-click an item to navigate:
   - **Missing in PAS**: Opens the form designer and selects the component
   - **Missing in DFM**: Opens the PAS file at the field declaration line
   - **Type Mismatch**: Opens the PAS file at the field declaration line
5. Fix the issues manually in either the DFM or PAS file

#### How to Interpret Results

| Column | Description |
|--------|-------------|
| Unit | The form/data module name |
| Component | Name of the component/field |
| Issue | Type of inconsistency (Missing in PAS, Missing in DFM, Type Mismatch) |
| PAS Type | Field type as declared in the PAS file (empty for Missing in PAS) |
| PAS Line | Line number in the PAS file where the field is declared ("-" if not in PAS) |
| DFM Type | Component type as declared in the DFM file (empty for Missing in DFM) |
| DFM Line | Line number in the DFM file where the component is defined ("-" if not in DFM) |
| File | Path to the DFM file |

**Note:** The PAS Line and DFM Line columns are centered for easier reading.

#### Understanding "Missing in PAS" Results

**Important:** Not all "Missing in PAS" findings indicate a problem. Components can be categorized as:

**Input Controls (Review Required):**
These components typically need PAS declarations because code usually reads/writes their values:
- TEdit, TMemo, TRichEdit, TMaskEdit
- TComboBox, TListBox, TCheckBox, TRadioButton
- TDateTimePicker, TSpinEdit, TTrackBar
- Third-party input controls (TLMDLabeledEdit, TcxTextEdit, etc.)

If an input control is missing from PAS, investigate how the code accesses its value - it may use `FindComponent()`, data binding, or it could be a bug.

**Passive Controls (Usually Safe to Ignore):**
These components often don't need PAS declarations as they're purely visual:
- TLabel, TStaticText - Display static text
- TPanel, TGroupBox, TScrollBox - Layout containers
- TBevel, TShape, TImage, TSplitter - Decorative/structural
- TToolBar, TStatusBar, TMainMenu - UI framework

**Note:** Event handlers still work without PAS declarations. A button's OnClick will fire even without a `Button1: TButton` field - the event is wired in the DFM. However, you cannot reference `Button1.Caption` in code without the declaration.

#### Understanding "Missing in DFM" Results

"Missing in DFM" means a field is declared in the PAS file but there's no corresponding component in the DFM. This typically indicates:

**Orphaned Declarations (Should Fix):**
- A component was deleted from the form but the field declaration wasn't removed
- A component was renamed in the form but the old declaration remains
- Copy/paste errors left stale declarations

**What to Do:**
1. Double-click to navigate to the declaration in the PAS file
2. Verify the component doesn't exist in the form
3. Delete the orphaned field declaration from the class

**Note:** The detector automatically filters out common non-component types (TStringList, TBitmap, TThread, etc.) that are legitimately declared as fields without being DFM components.

#### Filtering Results

Use the **Filter** dropdown to focus on specific component types:
- **All**: Show all inconsistencies
- **Input Controls**: Show only input controls (TEdit, TComboBox, etc.) - items that likely need attention
- **Passive Controls**: Show only passive controls (TLabel, TPanel, etc.) - items usually safe to ignore

#### Example Issues

**Missing in PAS:**
```
Unit: Form1
Component: Button1
Issue: Missing in PAS
PAS Type: (empty)
DFM Type: TButton
```
The DFM contains `object Button1: TButton` but the form class doesn't declare a `Button1` field.

**Missing in DFM:**
```
Unit: Form1
Component: edtUserName1
Issue: Missing in DFM
PAS Type: TRzDBEdit
DFM Type: (empty)
```
The PAS file declares `edtUserName1: TRzDBEdit` but there's no corresponding component in the DFM. This is likely an orphaned declaration from a deleted component.

**Type Mismatch:**
```
Unit: Form1
Component: Panel1
Issue: Type Mismatch
PAS Type: TGroupBox
DFM Type: TPanel
```
The DFM has `object Panel1: TPanel` but the PAS declares `Panel1: TGroupBox`.

#### Dialog Behavior

- **Non-modal**: The dialog stays open while you work in the IDE, allowing you to double-click items to navigate and fix issues without closing the checker
- **Clears on close**: Results are cleared when the dialog is closed; re-scan when you open it again
- **Singleton**: Clicking the menu item while the dialog is open brings it to front

#### Configuration Options

- **Enabled**: Master switch for the feature

---

### Empty Event Handler Detector (New in 3.4.1)

**Purpose:** Finds event handlers that have empty bodies (just begin/end with no code).

**Default:** ON

**Location:** Options > DDevExtensions > Empty Event Handler

**Access:** Tools > DDevExtensions > Empty Event Handler Detector...

#### Why Use This Tool?

Empty event handlers are often created accidentally when double-clicking components in the form designer. They:

- Clutter your code with unnecessary methods
- Increase the compiled executable size slightly
- Make code harder to read and maintain
- May indicate forgotten implementation

#### What It Detects

Event handlers with empty bodies - methods that only contain:
```pascal
procedure TForm1.Button1Click(Sender: TObject);
begin
  // Nothing here - just begin/end
end;
```

The detector recognizes common event handler naming patterns:
- `*Click` - Button clicks, menu clicks
- `*Change` - Edit changes, combobox changes
- `*Create` - Form/frame creation
- `*Destroy` - Form/frame destruction
- `*Enter`, `*Exit` - Focus events
- `*KeyDown`, `*KeyUp`, `*KeyPress` - Keyboard events
- `*MouseDown`, `*MouseUp`, `*MouseMove` - Mouse events
- And many more...

#### How to Use

1. Open the tool via Tools > DDevExtensions > Empty Event Handler Detector...
2. Click "Scan Project" to analyze all units in the project
3. Review the results showing empty event handlers
4. Double-click an item to navigate to the source
5. Delete the empty methods and their declarations

#### How to Interpret Results

| Column | Description |
|--------|-------------|
| Unit | Source file name |
| Class | The form/frame class containing the method |
| Method | Name of the empty event handler |
| Line | Line number where the method is defined |

#### Deleting Empty Event Handlers

To properly remove an empty event handler:

1. In the form designer, select the component
2. In Object Inspector, find the event property
3. Clear the event name (select and delete)
4. Delete the method body from the source code

Or manually:
1. Delete the method implementation from the implementation section
2. Delete the method declaration from the class definition
3. If the event is still linked in the DFM, clear it via Object Inspector

#### Dialog Behavior

- **Non-modal**: The dialog stays open while you work in the IDE, allowing you to double-click items to navigate and fix issues without closing the detector
- **Clears on close**: Results are cleared when the dialog is closed; re-scan when you open it again
- **Singleton**: Clicking the menu item while the dialog is open brings it to front

#### Configuration Options

- **Enabled**: Master switch for the feature

#### False Positives

Some empty event handlers are intentional:
- Event handlers that deliberately do nothing to prevent default behavior
- Placeholder handlers for future implementation
- Handlers used with visual inheritance

Review each result before deleting.

---

### Dependency Viewer

**Purpose:** Visualizes unit dependencies within your project.

**Default:** OFF

**Location:** Options > DDevExtensions > Dependency Viewer

**Access:** Tools > DDevExtensions > Dependency Viewer...

#### Features

- Tree view of all project units
- Shows interface and implementation uses clauses
- **Uses / Used By view modes** - toggle between forward and reverse dependencies
- **Dependency depth indicator** - shows each unit's position in the dependency chain
- **Impact Analysis panel** - shows direct/transitive dependents and risk level for selected unit
- **Respect conditional compilation** - optionally reads project defines and evaluates `{$IFDEF}`, `{$IFNDEF}`, `{$IF Defined(...)}` blocks to exclude code that wouldn't compile for the current project
- Circular reference detection with enhanced display
- Double-click to open unit

#### How to Use

1. Enable in Options
2. Open via Tools > DDevExtensions > Dependency Viewer...
3. Click "Scan Project" to analyze dependencies
4. Use the radio buttons to switch between "Uses" and "Used By" views
5. Toggle "Show Depth" to display dependency depth numbers

#### View Modes

| Mode | Description |
|------|-------------|
| Uses | Shows what units each unit depends on (forward dependencies) |
| Used By | Shows what units depend on each unit (reverse dependencies) |

The "Used By" view answers the question "What would break if I changed this unit?"

#### Understanding Dependency Depth

When "Show Depth" is enabled, each unit displays a depth number:

```
[0] SysUtils        <- No project dependencies (only RTL/VCL)
[0] Classes         <- No project dependencies
[1] MyUtils         <- Depends only on depth-0 units
[2] DataModule      <- Depends on MyUtils (depth 1)
[3] MainForm        <- Depends on DataModule (depth 2)
```

**Use cases for depth:**
- Identify units that pull in long dependency chains
- Find natural architectural layers
- Spot potential circular dependency risks (units at same depth referencing each other)

#### Understanding the Tree Display

Units involved in any circular reference are marked with `(!)`:

```
(!) [1] ReportsFrm      <- In at least one cycle
(!) [3] MainFrm         <- In at least one cycle
[0] CompanyData         <- Not in any cycle
[0] dmImages            <- Not in any cycle
```

When expanded, child nodes show `[interface]` or `[implementation]`:

```
(!) [2] MyUnit
+-- [1] SysUtils [interface]
+-- [1] Classes [interface]
+-- [0] MyOtherUnit [implementation]
```

#### Circular Reference Detection

Circular references are displayed in the right panel with enhanced information:

```
UnitA -[I]-> UnitB -[impl]-> UnitC -[I]-> UnitA
```

| Marker | Meaning |
|--------|---------|
| `-[I]->` | Dependency via interface uses clause |
| `-[impl]->` | Dependency via implementation uses clause |

The "Circular References" label is color-coded by severity:

| Count | Color | Meaning |
|-------|-------|---------|
| 0 | Green | No circular references - healthy codebase |
| 1-9 | Normal | Few cycles - manageable |
| 10-99 | Orange | Moderate cycles - attention needed |
| 100+ | Red | Many cycles - significant architectural issue |

This helps identify how to break the cycle - moving a reference from interface to implementation often resolves circular dependencies.

#### Circular Reference Interaction

- **Initial view**: Units in any cycle show `(!)` prefix automatically
- **Click** a circular reference to mark those specific cycle members with `>>> <<<` markers:
  ```
  >>> [1] ReportsFrm <<<
  ```
- **Double-click** a circular reference to open the first unit in the IDE editor
- Click a different circular reference to update the markers
- Markers clear when you click elsewhere in the list

#### Auto-sizing

The tree panel automatically sizes to fit the longest unit name after scanning. The splitter remains draggable for manual adjustment.

#### Impact Analysis Panel

**Purpose:** Answers the question "What breaks if I change this unit?"

When you click any unit in the tree, the Impact Analysis panel (top-right) shows how risky it would be to modify that unit.

**What the fields mean:**

| Field | What It Tells You |
|-------|-------------------|
| **Unit** | The unit you selected |
| **Direct dependents** | How many units have `uses ThisUnit` in their code |
| **Total affected** | All units that might need retesting if you change this unit |
| **Risk** | How careful you need to be (color-coded) |

**Why is "Total affected" sometimes higher than "Direct dependents"?**

This is the **ripple effect**. If you change UnitA:
- Units that directly use UnitA need retesting (direct dependents)
- But units that use *those* units might also be affected (transitive)

Example: You change `dmData`. Forms that use `dmData` might behave differently. And forms that use *those* forms might also be affected.

**Risk Levels:**

| Level | Color | Count | What To Do |
|-------|-------|-------|------------|
| Safe | Green | 0 | Change freely - nothing uses this unit |
| Low | Light Green | 1-3 | Low risk - minor testing needed |
| Medium | Orange | 4-10 | Be careful - test affected areas |
| High | Red | 11+ | High risk - thorough testing required |

**Example:**

```
Impact Analysis:
  Unit: dmCurrent
  Direct dependents: 37
  Total affected: 38 units    [Red] Risk: High
```

This tells you:
- 37 units have `uses dmCurrent` in their code
- 38 units total could be affected (37 direct + 1 that uses one of those 37)
- **Risk is High** - be very careful modifying this unit, test thoroughly

**Compare to a safe unit:**

```
Impact Analysis:
  Unit: MyHelperUtils
  Direct dependents: 0
  Total affected: 0 units    [Green] Risk: Safe
```

This unit can be changed freely - nothing depends on it.

**When to use Impact Analysis:**

1. **Before modifying a unit** - Check the risk level first
2. **Before refactoring** - Identify which units are safe to change
3. **Architecture review** - Units with very high impact may be too central (tight coupling)
4. **Planning testing** - Know which areas need testing after a change

#### Why Circular References Matter

Circular references can cause:
- **Compilation order issues** - the compiler may fail or produce unexpected results
- **Initialization order problems** - unit initialization sections may run in wrong order
- **Tight coupling** - makes code harder to maintain, test, and refactor
- **Memory/resource issues** - can prevent proper cleanup in finalization sections

#### How to Analyze a Cycle

1. **Click on a circular reference** to see which units are involved
2. **Look at the arrows** to understand the dependency direction:
   ```
   UnitA -[impl]-> UnitB -[I]-> UnitA
   ```
   This means: UnitA uses UnitB in implementation, UnitB uses UnitA in interface

3. **Interface cycles are worse** than implementation cycles:
   - `-[I]->` (interface) = tight coupling, harder to break
   - `-[impl]->` (implementation) = looser coupling, often acceptable

#### Strategies to Fix Circular References

**1. Move uses to implementation section**
```pascal
// Before: UnitA interface uses UnitB
interface
uses UnitB;  // Creates tight coupling

// After: Move to implementation if possible
implementation
uses UnitB;  // Looser coupling, may break the cycle
```

**2. Extract shared types to a common unit**
```
Before:  UnitA <-> UnitB (both need TSharedType)
After:   UnitA -> SharedTypes <- UnitB (no cycle)
```

**3. Use interfaces instead of concrete classes**
```pascal
// Before: UnitA uses UnitB for TConcreteClass
// After: UnitA uses IMyInterface from a separate unit
//        UnitB implements IMyInterface
```

**4. Pass dependencies as parameters**
```pascal
// Before: UnitB uses UnitA to access GlobalObject
// After: Pass the object as a parameter to UnitB's procedures
```

**5. Use events or callbacks**
```pascal
// Before: UnitB directly calls UnitA.DoSomething
// After: UnitB raises an event, UnitA subscribes to it
```

#### Prioritizing Fixes

1. **Start with interface cycles** (`-[I]->`) - these are the most problematic
2. **Focus on units with many cycles** - look for units appearing in multiple circular references
3. **Implementation-only cycles** (`-[impl]->`) are often acceptable and can be left alone
4. **Short cycles** (2 units) are usually easier to fix than long chains

#### Configuration Options

- **Enabled**: Master switch for the feature
- **Respect conditional compilation**: When enabled, the scanner reads the project's conditional defines and evaluates `{$IFDEF}`, `{$IFNDEF}`, `{$IF}`, `{$ELSE}`, `{$ELSEIF}`, and `{$ENDIF}` blocks. Uses clauses inside inactive conditional blocks are excluded from the dependency analysis.

#### Conditional Compilation Support

When "Respect conditional compilation" is enabled (default), the Dependency Viewer:

1. **Reads project defines** from the `.dproj` file (e.g., `DEBUG`, `RELEASE`, `DBiAdmin`)
2. **Evaluates conditional directives** in the uses clauses:
   - `{$IFDEF X}` - includes if X is defined
   - `{$IFNDEF X}` - includes if X is NOT defined
   - `{$IF Defined(X)}` - includes if X is defined
   - `{$IF Defined(X) or Defined(Y)}` - includes if X OR Y is defined
   - `{$IF Defined(X) and Defined(Y)}` - includes if X AND Y are defined
   - `{$ELSE}`, `{$ELSEIF}`, `{$ENDIF}` - handled correctly

3. **Excludes inactive code** from dependency analysis

**Example:**
```pascal
uses
  SysUtils,
  {$IFDEF DBiAdmin}
  AdminModule,    // Only included when analyzing DBiAdmin project
  {$ENDIF}
  {$IFDEF DBiWorkflow}
  WorkflowModule, // Only included when analyzing DBiWorkflow project
  {$ENDIF}
  CommonUnit;
```

When analyzing the DBiAdmin project (which defines `DBiAdmin`), only `SysUtils`, `AdminModule`, and `CommonUnit` are included. `WorkflowModule` is excluded because `DBiWorkflow` is not defined.

**Benefits:**
- Eliminates false positive circular references caused by conditional code for other applications
- Shows accurate dependencies for the specific project being analyzed
- Useful for codebases with shared units used across multiple applications

**When to Disable:**
- If you want to see ALL possible dependencies regardless of current project defines
- If the project doesn't use conditional compilation in uses clauses

---

### Disable Package Cache

**Purpose:** Disables the IDE's package caching mechanism.

**Default:** OFF

**Location:** Options > DDevExtensions > Extended IDE Settings

**Use Case:** Resolves issues where packages aren't reloaded after changes.

---

### Disable Source Formatter Hotkey

**Purpose:** Prevents accidental triggering of the IDE's built-in source formatter (Ctrl+D by default).

**Default:** OFF

**Location:** Options > DDevExtensions > Extended IDE Settings

**Note:** Only affects the hotkey. You can still format via the menu.

---

### Don't Break on Spawned Processes

**Purpose:** Prevents the debugger from breaking into child processes started by your application.

**Default:** OFF

**Location:** Options > DDevExtensions > Extended IDE Settings

**Use Case:** When debugging applications that launch other executables.

---

### Editor Tab Double-Click Action

**Purpose:** Configures the behavior when double-clicking an editor tab.

**Default:** Zoom

**Location:** Options > DDevExtensions > Extended IDE Settings

#### Options

| Setting | Behavior |
|---------|----------|
| None | No action |
| Zoom | Maximize editor, hide other panels |
| Super Zoom | Maximum editor space, minimal UI |

**Usage:** Double-click any editor tab to toggle zoom. Double-click again to restore.

---

### Enhanced Key Bindings

**Purpose:** Provides additional keyboard shortcuts and improved cursor navigation for more efficient code editing.

**Default:** ON

**Location:** Options > DDevExtensions > Key Bindings

#### Available Bindings

| Shortcut | Action | Option |
|----------|--------|--------|
| Tab | Indent selected lines | Tab Indent |
| Shift+Tab | Unindent selected lines | Tab Indent |
| Home | Toggle between line start and first non-whitespace | Extended Home |
| Ctrl+Left/Right | Improved word navigation | Extended Ctrl+Left/Right |
| Ctrl+Alt+Shift+Up | Move line/block up | Move Line/Block |
| Ctrl+Alt+Shift+Down | Move line/block down | Move Line/Block |
| Ctrl+Alt+PgUp | Find declaration at cursor | Find Declaration on Caret |
| Ctrl+Shift+Up | Jump to interface section | Section Toggle |
| Ctrl+Shift+Down | Jump to implementation section | Section Toggle |

#### Configuration Options

- **Active**: Master switch for all key bindings
- **Tab Indent**: Enable Tab/Shift+Tab to indent/unindent selected code
- **Indent Single Line**: Also indent when only one line is selected
- **Extended Home**: Toggle between BOL and first non-whitespace
- **Switched Extended Home**: Reverse the Extended Home behavior
- **Extended Ctrl+Left/Right**: Smarter word boundary detection
- **Move Line/Block**: Enable Ctrl+Alt+Shift+Up/Down to move code
- **Find Declaration on Caret**: Enable Ctrl+Alt+PgUp to find declaration
- **Section Toggle**: Enable Ctrl+Shift+Up/Down to jump between interface and implementation sections

#### Usage Tips

1. **Tab Indentation**: Select multiple lines, then press Tab to indent or Shift+Tab to unindent. Works with block selections.

2. **Extended Home**: Press Home once to go to first non-whitespace character. Press again to go to column 1.

3. **Move Line/Block**: Place cursor on a line (or select multiple lines), then use Ctrl+Alt+Shift+Up/Down to move the entire block without cut/paste.

4. **Section Toggle**: Press Ctrl+Shift+Up to jump to the `interface` keyword, or Ctrl+Shift+Down to jump to the `implementation` keyword. Works from anywhere in the unit.

---

### File Cleaner

**Purpose:** Automatically removes unnecessary files after saving.

**Default:** ON

**Location:** Options > DDevExtensions > File Cleaner

#### Files Removed

- `.ddp` files
- Empty `Model` folders
- Empty `History` folders

---

### Find Unit / Use Unit Replacement Dialog

**Purpose:** Replaces standard Find Unit and Use Unit dialogs with enhanced versions.

**Default:** ON

**Access:** File > Use Unit (Ctrl+Shift+A)

#### Enhancements

- Faster search
- Better filtering
- Preview of unit contents
- Fuzzy matching

---

### Kill dexplore.exe on IDE Exit

**Purpose:** Terminates Document Explorer processes when closing the IDE.

**Default:** ON

**Location:** Options > DDevExtensions > Extended IDE Settings

---

### Release Compiler Unit Cache

**Purpose:** Clears the compiler's internal unit cache before each build.

**Default:** OFF

**Location:** Options > DDevExtensions > Compile Progress

#### Options

- **Standard**: Releases basic cache
- **High**: More aggressive cache release

**Use Case:** Helps resolve rare caching issues where the compiler uses stale unit information.

---

### Remove Explicit* Properties

**Purpose:** Prevents ExplicitLeft, ExplicitTop, ExplicitWidth, and ExplicitHeight properties from being saved to DFM files.

**Default:** OFF

**Location:** Options > DDevExtensions > Form Designer

#### Benefits

- Reduces DFM file size
- Eliminates meaningless changes in version control
- Cleaner form files

#### Caution

These properties are used by the IDE for anchor calculations. Only enable if you understand the implications.

---

### Remove PixelsPerInch Property (New in 3.2)

**Purpose:** Prevents the PixelsPerInch property from being saved to DFM files.

**Default:** OFF

**Location:** Options > DDevExtensions > Form Designer

#### Benefits

- Eliminates DPI-related phantom changes in version control
- Developers with different monitor DPI settings won't cause unwanted DFM modifications
- Forms opened on 4K monitors won't conflict with forms saved on standard monitors

#### How It Works

When enabled, the PixelsPerInch property is read from existing DFM files (for backward compatibility) but never written when saving. The IDE recalculates scaling at runtime based on the current display settings.

#### When to Enable

- Teams with developers using different DPI/monitor configurations
- Projects experiencing frequent PixelsPerInch merge conflicts
- When using High DPI scaling features (Delphi 10.3+)

---

### Remove TextHeight Property (New in 3.2)

**Purpose:** Prevents the TextHeight property from being saved to DFM files.

**Default:** OFF

**Location:** Options > DDevExtensions > Form Designer

#### Benefits

- Eliminates font-rendering related phantom changes
- Different machines with different font configurations won't cause unwanted DFM modifications
- Cleaner version control diffs

#### How It Works

When enabled, the TextHeight property is read from existing DFM files but never written when saving. TextHeight is purely informational and is recalculated at runtime based on the form's font.

#### When to Enable

- Teams experiencing frequent TextHeight changes in version control
- When DFM files show modifications after simply opening a form
- Projects where TextHeight changes cause merge conflicts

---

### Replace Open File At Cursor

**Purpose:** Enhances the "Open File At Cursor" feature with better file resolution and namespace support.

**Default:** OFF

**Location:** Options > DDevExtensions > Extended IDE Settings

#### Improvements

- Searches project paths, library paths, and browsing paths
- Supports XE2+ unit namespaces (e.g., `System.SysUtils`)
- Searches across all projects in the project group
- Falls back to standard file dialog if not found

---

### Show All Inheritable Modules

**Purpose:** Shows forms and data modules from all loaded packages in inheritance dialogs.

**Default:** OFF

**Location:** Options > DDevExtensions > Extended IDE Settings

---

### Show Project for Active File

**Purpose:** Highlights and expands the project containing the currently active file in Project Manager.

**Default:** ON

**Location:** Options > DDevExtensions > Extended IDE Settings

---

### Structure View Search

**Purpose:** Adds a search/filter box to the Structure View panel for quickly finding methods, properties, and other elements.

**Default:** OFF (no hotkey assigned)

**Location:** Options > DDevExtensions > Extended IDE Settings

#### How to Use

1. Assign a hotkey in Options (e.g., Ctrl+Shift+S)
2. With Structure View visible, press the hotkey
3. Type to filter the structure tree
4. Press Enter to navigate to the selected item

---

### Switch Project for File

**Purpose:** When compiling a file that belongs to a different project, prompts to switch to that project.

**Default:** ON

**Location:** Options > DDevExtensions > Compile Progress

---

### TLabel.Margins.Bottom to Zero

**Purpose:** Automatically sets the bottom margin of TLabel components to zero when created in the form designer.

**Default:** ON

**Location:** Options > DDevExtensions > Form Designer

**Why:** Prevents unexpected spacing issues in form layouts when using alignment features.

---

### TODO/FIXME Aggregator

**Purpose:** Scans your project for TODO, FIXME, and other comment markers.

**Default:** ON

**Location:** Options > DDevExtensions > TODO Aggregator

**Access:** Tools > DDevExtensions > TODO/FIXME Aggregator...

#### Detected Patterns

| Pattern | Typical Use |
|---------|-------------|
| TODO | Task to be completed |
| FIXME | Known bug to fix |
| HACK | Temporary workaround |
| BUG | Documented bug |
| NOTE | Important information |
| XXX | Attention needed |

#### Priority Syntax

Add priority in parentheses:
```pascal
// TODO(high): Implement error handling
// FIXME(low): Cosmetic issue
// HACK(medium): Temporary workaround
```

#### Features

- Filter by category (TODO, FIXME, etc.)
- Filter by priority (High, Medium, Low)
- Sortable columns
- Double-click to navigate to source
- Export to CSV

#### Configuration Options

- **Enabled**: Master switch
- **Patterns**: Comma-separated list of patterns to detect

Default patterns: `TODO,FIXME,HACK,BUG,NOTE,XXX`

#### How to Interpret Results

| Column | Description |
|--------|-------------|
| Unit | Source file name |
| Category | TODO, FIXME, HACK, etc. |
| Priority | High, Medium, Low, or (none) |
| Line | Line number in source |
| Text | The comment text |

---

### Unreachable Code Detector

**Purpose:** Finds code that can never execute because it follows a statement that always exits the current scope.

**Default:** ON

**Location:** Options > DDevExtensions > Unreachable Code Detector

**Access:** Tools > DDevExtensions > Unreachable Code Detector...

#### Features

- Scans all Pascal units in the active project
- Displays the project name being analyzed
- Smart detection that ignores conditional terminators
- Filter results by reason type
- Double-click to navigate to source
- Export to CSV

#### What It Detects

Code that appears after these **unconditional** control flow statements:

| Statement | Description |
|-----------|-------------|
| Exit | Returns from the current procedure/function |
| Raise | Throws an exception |
| Break | Exits the current loop |
| Continue | Skips to next loop iteration |
| Halt | Terminates the program |
| Abort | Raises a silent exception |

#### Examples of Unreachable Code

```pascal
procedure Example1;
begin
  Exit;
  ShowMessage('Never shown');  // Unreachable - after Exit
end;

procedure Example2;
begin
  raise Exception.Create('Error');
  CleanupResources;  // Unreachable - after Raise
end;

procedure Example3;
var
  I: Integer;
begin
  for I := 1 to 10 do
  begin
    if I = 5 then
      Break;
      DoSomething;  // Unreachable - after Break (missing begin/end)
  end;
end;
```

#### Smart Conditional Detection

The detector is smart enough to recognize **conditional terminators** and will NOT flag code after them as unreachable:

```pascal
// These are CONDITIONAL - the code after IS reachable:
if X > 10 then Exit;           // Exit only if X > 10
ShowMessage('Still runs');     // This is reachable - NOT flagged

if Error then raise Exception.Create('Oops');
DoCleanup;                     // This is reachable - NOT flagged

for I := 1 to 10 do
begin
  if Found then Break;         // Break only if Found
  ProcessItem(I);              // This is reachable - NOT flagged
end;
```

The detector only flags code after **unconditional** terminators:

```pascal
// These are UNCONDITIONAL - the code after is NOT reachable:
Exit;
ShowMessage('Never runs');     // FLAGGED - truly unreachable

raise Exception.Create('Error');
DoCleanup;                     // FLAGGED - truly unreachable
```

#### How to Interpret Results

| Column | Description |
|--------|-------------|
| Unit | Source file name |
| Line | Line number of the unreachable code |
| Reason | Why the code is unreachable (After Exit, After Raise, etc.) |
| Code | The unreachable statement |

#### Configuration Options

- **Enabled**: Master switch
- **Check After Exit**: Detect code after Exit statements
- **Check After Raise**: Detect code after Raise statements
- **Check After Break**: Detect code after Break statements
- **Check After Continue**: Detect code after Continue statements
- **Check After Halt**: Detect code after Halt calls
- **Check After Abort**: Detect code after Abort calls

#### Common Causes

1. **Forgotten code** - Old code left behind after refactoring
2. **Missing begin/end** - Incorrect block structure makes code appear to follow a control statement
3. **Debug code** - Temporary Exit/Break added during debugging and not removed
4. **Copy/paste errors** - Code duplicated incorrectly

#### Smart Detection Features

The detector includes several smart features to minimize false positives:

1. **Conditional terminators**: Code after `if X then Exit;` is correctly recognized as reachable
2. **Case statement branches**: Terminators inside case branches (e.g., `0: Exit;`) don't flag subsequent case labels as unreachable
3. **Variables named after keywords**: Assignments like `Continue := False;` are recognized as variable assignments, not control flow
4. **Parameter declarations**: `var Continue: Boolean` in procedure parameters is recognized as a parameter name
5. **String literals**: Keywords inside strings (including Delphi 12+ triple-quoted multi-line strings) are properly skipped
6. **Comments**: Keywords inside comments are ignored
7. **Interface section**: Only the implementation section is scanned (no executable code in interface)
8. **Conditional compilation**: Reads project defines and correctly evaluates `{$IFDEF}`, `{$IFNDEF}`, and simple `{$IF Defined(X)}` blocks

#### Conditional Compilation Handling

The detector reads the project's conditional defines and intelligently handles conditional compilation:

| Directive | Behavior |
|-----------|----------|
| `{$IFDEF X}` | If X is defined in project, scan the block; otherwise skip to `{$ELSE}` or `{$ENDIF}` |
| `{$IFNDEF X}` | If X is NOT defined, scan the block; otherwise skip |
| `{$IF Defined(X)}` | Evaluates simple conditions; scans if true, skips if false |
| `{$IF NOT Defined(X)}` | Evaluates negated conditions correctly |
| `{$ELSE}` | Switches between scanning and skipping appropriately |
| `{$ENDIF}` | Ends the conditional block |

**Example:** If your project defines `DBiUsers`, then code inside `{$IFDEF DBiUsers}` will be scanned, while code inside `{$IFNDEF DBiUsers}` will be skipped.

#### Known Limitations

The detector has the following limitations:

| Limitation | Description |
|------------|-------------|
| **Complex `{$IF}` expressions** | Expressions with `and`/`or` operators (e.g., `{$IF Defined(A) or Defined(B)}`) cannot be fully evaluated; the block is skipped to avoid false positives. |
| **Assembly blocks** | Inline assembly with JMP or other branch instructions is not analyzed. |
| **Complex conditionals** | Only simple `if X then Terminator;` patterns are detected. Multi-statement conditionals may not be recognized. |

#### False Positives

If you encounter false positives:

1. **Complex `{$IF}` expressions**: Code in blocks with complex boolean expressions is skipped rather than potentially flagging incorrectly
2. **Intentional unreachable code**: Sometimes unreachable code is left for defensive programming or future use
3. **Complex control flow**: Nested conditions or unusual patterns may confuse the detector

These are typically few in number and can be noted and ignored.

#### Important Note

This is a static analysis tool and is not perfect. It may not catch all cases of unreachable code, and in rare situations may report false positives. **Always manually verify results before making code changes.** Use it as a guide to identify potential issues, not as an authoritative source.

---

### Unused Unit Detector

**Purpose:** Finds units in uses clauses that aren't actually referenced in code.

**Default:** OFF

**Location:** Options > DDevExtensions > Unused Unit Detector

**Access:** Tools > DDevExtensions > Unused Unit Detector...

#### Features

- Scans interface and implementation uses clauses
- Shows file, unit name, section, and line number
- Double-click to navigate to the uses clause
- Right-click to add to ignore list
- Export to CSV

#### Configuration Options

- **Enabled**: Master switch
- **Ignore List**: Units to skip (one per line)

Common units to ignore:
```
System
SysUtils
Classes
Windows
```

#### How to Interpret Results

| Column | Description |
|--------|-------------|
| Source File | The file containing the unused unit |
| Unused Unit | Name of the potentially unused unit |
| Section | Interface or Implementation |
| Line | Line number of the uses clause |

#### False Positives

Some units may appear unused but are required:
- Component registration units
- Units that register classes for streaming
- Units included for side effects (initialization sections)

Use "Add to Ignore List" for these cases.

---

### Uses Clause Manager (New in 3.4)

**Purpose:** Automatically analyzes which symbols from each unit are used in the interface vs implementation sections, then recommends moving units to their optimal uses clause location.

**Default:** ON

**Location:** Options > DDevExtensions > Uses Clause Manager

**Access:** Tools > DDevExtensions > Uses Clause Manager...

#### Why Use This Tool?

Proper uses clause organization provides several benefits:

1. **Faster compilation** - Units in the implementation section don't need to be compiled when only the interface changes
2. **Better encapsulation** - Reduces coupling by only exposing necessary dependencies in the interface
3. **Cleaner architecture** - Makes unit dependencies clearer and easier to understand
4. **Smaller interface sections** - Interface section stays focused on the public API

#### How It Works

The Uses Clause Manager works in three steps:

**Step 1: Build Exports Database**
- Scans all units in the project's search paths
- Parses each unit's interface section to extract exported identifiers
- Builds a database mapping identifiers to their source units
- This only needs to be done once (or when search paths change)

**Step 2: Analyze Current Unit**
- Parses the current unit with the Delphi lexer
- Tracks all identifiers used in the interface section
- Tracks all identifiers used in the implementation section
- Matches identifiers to their source units using the exports database

**Step 3: Generate Recommendations**
- For each unit in the uses clauses:
  - If ANY identifier from that unit appears in the interface section → recommend **interface**
  - If ALL identifiers appear only in implementation → recommend **implementation**
- Shows clear reasoning for each recommendation

#### Using the Tool

1. **Open a Pascal unit** in the editor
2. **Open Uses Clause Manager** via Tools menu
3. **Click "Build Database"** (first time only)
   - Shows progress as it scans units
   - Shows summary when complete (e.g., "Database built: 450 units scanned")
   - Database is cached for subsequent analyses
4. **Click "Analyze Unit"**
   - Analyzes the current file
   - Populates the list with recommendations
5. **Review recommendations**
   - Select a unit to see which identifiers are used where
   - Units marked for change have different current/recommended sections
6. **Apply changes** using one of two methods:
   - **"Apply Changes" button** - applies all recommendations at once
   - **Right-click → "Move to Recommended Section"** - moves only selected unit(s)
   - Both methods support undo (Ctrl+Z)

#### Understanding the Results

| Column | Description |
|--------|-------------|
| Unit | Name of the used unit |
| Current | Where the unit is currently (interface/implementation) |
| Recommended | Where the unit should be |
| Reason | Why the recommendation was made |

#### Reason Messages and Suggested Actions

| Reason | Current | Recommended | Action |
|--------|---------|-------------|--------|
| **OK - used in both sections** | interface | interface | No action needed. Unit is correctly placed. |
| **OK - used in interface section** | interface | interface | No action needed. Unit is correctly placed. |
| **OK - only used in implementation** | implementation | implementation | No action needed. Unit is correctly placed. |
| **Only used in implementation section** | interface | implementation | **Move to implementation.** Right-click → Move to Recommended Section. |
| **Identifiers used in interface section** | implementation | interface | **Move to interface.** This unit provides types/constants used in class declarations or function signatures. |
| **No direct usage detected - review manually** | interface | implementation | **Review carefully.** The unit may be unused, or it may be used implicitly (e.g., component registration, initialization side effects). Check before removing. |

**Color Guide:**
- Rows where Current = Recommended need no action
- Rows where Current ≠ Recommended should be reviewed and potentially moved

#### Details Panel

When you select a unit in the list, the details panel shows:

```
Unit: SysUtils

Identifiers used in INTERFACE section:
  TStringList, TNotifyEvent

Identifiers used in IMPLEMENTATION section:
  Format, IntToStr, FileExists

Recommendation: Keep in interface (types used in interface)
```

This helps you understand why each recommendation is made.

#### Decision Logic

The tool uses the following logic:

| Scenario | Recommendation |
|----------|---------------|
| Any identifier in interface | Keep in interface uses |
| All identifiers in implementation only | Move to implementation uses |
| No identifiers found | Move to implementation (may be unused) |

#### Handling Ambiguous Identifiers

When the same identifier is exported by multiple units (e.g., `Format` from both `SysUtils` and a custom unit), the tool uses priority:

1. **RTL/VCL units take priority** - System, SysUtils, Classes, etc.
2. **Closer units second** - Units in the same directory
3. **Others last** - Third-party and distant units

This matches how Delphi resolves identifiers at compile time.

#### RTL/VCL Priority List

These units are automatically prioritized for ambiguous identifiers:

```
System, SysUtils, Classes, Types, TypInfo,
Windows, Messages,
Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
Vcl.Dialogs, Vcl.Menus, Vcl.ComCtrls, Vcl.Grids,
Data.DB,
Generics.Collections, Generics.Defaults
```

#### Export and Copy

- **Export**: Save results to CSV for documentation or further analysis
- **Copy to Clipboard**: Copy selected items in tab-separated format

#### Configuration Options

- **Enabled**: Master switch for the feature

#### Known Limitations

| Limitation | Description |
|------------|-------------|
| **Ambiguous identifiers** | Same identifier exported by multiple units may not resolve correctly without type information |
| **Implicit uses** | System unit is implicitly used and not analyzed |
| **Generic types** | `TList<T>` and similar generic instantiations require full type analysis |
| **First scan is slow** | Building the exports database requires parsing many files (subsequent analyses are fast) |
| **Cross-project** | Only analyzes the current project's search path |

#### Tips for Best Results

1. **Build database after opening project** - Ensures all search paths are included
2. **Rebuild database when search paths change** - Click Build Database again
3. **Review before applying** - Check that recommendations make sense for your code
4. **Use undo if needed** - Ctrl+Z reverts the changes immediately
5. **Re-analyze after applying** - Verify the new state

#### Common Scenarios

**Scenario 1: Form with data module**
```
Before:
  interface uses DataModule;  // Only used in implementation

After:
  implementation uses DataModule;  // Moved - cleaner interface
```

**Scenario 2: Type used in interface**
```
Before:
  implementation uses MyTypes;  // TMyRecord used in interface

After:
  interface uses MyTypes;  // Moved - required for compilation
```

**Scenario 3: Mixed usage**
```
Unit SysUtils:
  - TStringList used in interface (type declaration)
  - Format used in implementation (code)

Recommendation: Keep in interface (interface usage takes priority)
```

---

## Troubleshooting

### Features Not Appearing

1. Ensure DDevExtensions is properly installed
2. Check if the feature is enabled in Options
3. Restart the IDE after changing settings

### DDevExtensions Menu Items Missing

Features accessed via the Tools > DDevExtensions submenu must be enabled in Options first:
- Build Statistics
- Code Style Checker
- Dead Code Detector
- DFM/PAS Consistency Checker
- Dependency Viewer
- Empty Event Handler Detector
- TODO/FIXME Aggregator
- Unreachable Code Detector
- Unused Unit Detector
- Uses Clause Manager

### Hotkeys Not Working

1. Check that the feature is enabled
2. Verify the hotkey isn't conflicting with another binding
3. Some hotkeys only work in specific contexts (editor, form designer)

### Analysis Tools Show No Results

1. Ensure a project is open and active
2. Click the "Scan" or "Analyze" button
3. Check filter settings aren't hiding results

### Build Statistics Shows "-" for Metrics

This indicates the source file wasn't found. Causes:
- External/RTL units without source
- Incorrect library paths
- Source files moved or deleted

### Performance Issues

If the IDE becomes slow:
1. Disable features you don't use
2. For large projects, disable auto-show for Build Statistics
3. Use filters in analysis tools to limit scope

---

*DDevExtensions - Enhancing RAD Studio since Delphi 2007*

*Original author: Andreas Hausladen*
*Website: https://www.idefixpack.de/ddev*
