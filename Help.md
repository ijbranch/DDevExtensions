# DDevExtensions Help Guide

Version 3.2 | Comprehensive Feature Reference

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Getting Started](#getting-started)
3. [Feature Reference (A-Z)](#feature-reference-a-z)
4. [Troubleshooting](#troubleshooting)

---

## Quick Reference

| Feature | Default | Access Method |
|---------|---------|---------------|
| Auto-save After Compile | OFF | Options |
| Build Statistics | OFF | Tools menu |
| Code Style Checker | ON | Tools menu |
| Compile Backup | ON | Automatic |
| Compile Progress | ON | Automatic |
| Component Selector | OFF | Configurable hotkey |
| Confirm Ctrl+F1 While Debugging | ON | Automatic |
| Dead Code Detector | ON | Tools menu |
| Dependency Viewer | OFF | Tools menu |
| Disable Package Cache | OFF | Options |
| Disable Source Formatter Hotkey | OFF | Options |
| Don't Break on Spawned Processes | OFF | Options |
| Editor Tab Double-Click | Zoom | Double-click tab |
| Enhanced Key Bindings | ON | Automatic |
| File Cleaner | ON | Automatic |
| Find Unit Replacement | ON | Ctrl+Shift+A |
| Kill dexplore.exe on Exit | ON | Automatic |
| Release Compiler Cache | OFF | Options |
| Remove Explicit* Properties | OFF | Options |
| Remove PixelsPerInch Property | OFF | Options |
| Remove TextHeight Property | OFF | Options |
| Replace Open File At Cursor | OFF | Options |
| Show All Inheritable Modules | OFF | Options |
| Show Project for Active File | ON | Automatic |
| Structure View Search | OFF | Configurable hotkey |
| Switch Project for File | ON | Automatic |
| TLabel.Margins.Bottom to Zero | ON | Automatic |
| TODO/FIXME Aggregator | ON | Tools menu |
| Unused Unit Detector | OFF | Tools menu |

---

## Getting Started

### Accessing DDevExtensions Options

1. Open RAD Studio/Delphi IDE
2. Go to **Tools** > **Options**
3. In the Options dialog, look for **DDevExtensions** in the left tree
4. Expand to see all feature categories

### Configuration Files

DDevExtensions stores settings in:
```
%APPDATA%\DDevExtensions\
```

Each feature has its own XML configuration file (e.g., `KeyBindings.xml`, `CompileProgress.xml`).

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

**Access:** Tools > Build Statistics...

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

**Access:** Tools > Code Style Checker...

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

**Access:** Tools > Dead Code Detector...

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

### Dependency Viewer

**Purpose:** Visualizes unit dependencies within your project.

**Default:** OFF

**Location:** Options > DDevExtensions > Dependency Viewer

**Access:** Tools > Dependency Viewer...

#### Features

- Tree view of all project units
- Shows interface and implementation uses clauses
- Circular reference detection
- Filter/search functionality
- Double-click to open unit

#### How to Use

1. Enable in Options
2. Open via Tools > Dependency Viewer...
3. Click "Scan Project" to analyze dependencies

#### Understanding the Display

```
MyUnit.pas
+-- [Interface Uses]
|   +-- SysUtils
|   +-- Classes
|   +-- MyOtherUnit (!) <- Circular reference indicator
+-- [Implementation Uses]
    +-- Forms
```

The `(!)` marker indicates a circular dependency, which can cause compilation issues.

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

#### Configuration Options

- **Active**: Master switch for all key bindings
- **Tab Indent**: Enable Tab/Shift+Tab to indent/unindent selected code
- **Indent Single Line**: Also indent when only one line is selected
- **Extended Home**: Toggle between BOL and first non-whitespace
- **Switched Extended Home**: Reverse the Extended Home behavior
- **Extended Ctrl+Left/Right**: Smarter word boundary detection
- **Move Line/Block**: Enable Ctrl+Alt+Shift+Up/Down to move code
- **Find Declaration on Caret**: Enable Ctrl+Alt+PgUp to find declaration

#### Usage Tips

1. **Tab Indentation**: Select multiple lines, then press Tab to indent or Shift+Tab to unindent. Works with block selections.

2. **Extended Home**: Press Home once to go to first non-whitespace character. Press again to go to column 1.

3. **Move Line/Block**: Place cursor on a line (or select multiple lines), then use Ctrl+Alt+Shift+Up/Down to move the entire block without cut/paste.

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

**Access:** Tools > TODO/FIXME Aggregator...

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

### Unused Unit Detector

**Purpose:** Finds units in uses clauses that aren't actually referenced in code.

**Default:** OFF

**Location:** Options > DDevExtensions > Unused Unit Detector

**Access:** Tools > Unused Unit Detector...

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

## Troubleshooting

### Features Not Appearing

1. Ensure DDevExtensions is properly installed
2. Check if the feature is enabled in Options
3. Restart the IDE after changing settings

### Tools Menu Items Missing

Features accessed via the Tools menu must be enabled in Options first:
- Build Statistics
- Code Style Checker
- Dead Code Detector
- Dependency Viewer
- TODO/FIXME Aggregator
- Unused Unit Detector

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

## Support

For issues or feature requests:
- GitHub: https://github.com/user/ddevextensions/issues

---

*DDevExtensions - Enhancing RAD Studio since Delphi 2007*

*Original author: Andreas Hausladen*
*Website: https://www.idefixpack.de/ddev*
