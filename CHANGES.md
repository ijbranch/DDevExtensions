# CHANGES.md - DDevExtensions Project History

This file is the sole source and record of all project changes for DDevExtensions.

---

## 2026-03-23 - v3.12.3 - Add External Mod Monitor (real-time file change detection)

**Problem:** The Delphi IDE only detects external file modifications when it regains focus (Alt-Tab away and back). When using external tools (AI assistants, version control, other editors) that modify project files while the IDE is active, changes go undetected. The VSoft.ExternalModDetector plugin solves this but requires an external FileSystemMonitor dependency, which is undesirable for a public repository.

**Changes Made:**
1. `Shared/FileWatcher.pas`: New unit — self-contained `ReadDirectoryChangesW` wrapper using overlapped I/O. Background thread with reference-counted directory watches, main-thread notification via `TThread.Queue`. Zero external dependencies.
2. `Source/ExternalModMonitor/ExternalModMonitor.pas`: New feature plugin — `TExternalModMonitorConfig` (inherits `TPluginConfig`). Uses `TIDENotifier` for project open/close events and compile suppression. Debounced (200ms) silent auto-refresh via `IOTAModule.Refresh(False)`. Skips files with unsaved editor changes.
3. `Source/ExternalModMonitor/FrmeOptionPageExternalModMonitor.pas` + `.dfm`: New options page — Active checkbox, debounce interval (ms), monitored extensions field.
4. `Source/DelphiExtension.inc`: Added `{$DEFINE INCLUDE_EXTERNALMODMONITOR}`
5. `Source/RegisterPlugins.pas`: Added uses clause and `RegisterLateLoader` call for `ExternalModMonitor.InitPlugin`
6. `D_D130/DDevExtensions.dpr`: Added `FileWatcher`, `ExternalModMonitor`, `FrmeOptionPageExternalModMonitor` to uses clause
7. `D_D130/DDevExtensions.dproj`: Added three `DCCReference` entries for the new units

**Result:** Project directories are monitored in real-time. Externally modified files are silently refreshed within ~200ms. Monitoring is suppressed during compilation. Files with unsaved editor changes are never overwritten. Feature is enabled by default and can be toggled via Tools > DDevExtensions > Options > External Mod Monitor.

**Files Created:** Shared/FileWatcher.pas, Source/ExternalModMonitor/ExternalModMonitor.pas, Source/ExternalModMonitor/FrmeOptionPageExternalModMonitor.pas, Source/ExternalModMonitor/FrmeOptionPageExternalModMonitor.dfm
**Files Modified:** Source/DelphiExtension.inc, Source/RegisterPlugins.pas, D_D130/DDevExtensions.dpr, D_D130/DDevExtensions.dproj

---

## 2026-03-15 - Fix IDE Path Sorter cosmetic issues, persist panel sizes, add multi-select

**Problem:** The `>>` and `A-Z` buttons were children of `pnlMain` at fixed absolute positions (Left=444), causing them to overlap `lstWorking` content. The "Auto-backup before apply" checkbox text was truncated at Width=150. The main path panel and backup panel heights were not persisted between sessions. The working panel only supported single item selection.

**Changes Made:**
1. `FrmLibraryPathSorter.dfm`: Moved `btnCopyToWorking` and `btnSortAlpha` from `pnlMain` into `pnlWorkingButtons` panel, positioned below the existing navigation buttons (Top=130 and Top=164)
2. `FrmLibraryPathSorter.dfm`: Changed `btnSortAlpha` from `TButton` to `TSpeedButton` for visual consistency with other panel buttons
3. `FrmLibraryPathSorter.dfm`: Widened `chkAutoBackup` from Width=150 to Width=170 to prevent text truncation
4. `FrmLibraryPathSorter.pas` line 58: Changed `btnSortAlpha: TButton` to `btnSortAlpha: TSpeedButton`
5. `FrmLibraryPathSorter.pas` `LoadFormSettings`: Added restore of `MainHeight` and `BackupsHeight` from registry
6. `FrmLibraryPathSorter.pas` `SaveFormSettings`: Added save of `pnlMain.Height` and `pnlBackups.Height` to registry
7. `FrmLibraryPathSorter.pas` `FormCreate`: Enabled `MultiSelect` on `lstWorking` for Ctrl-Click/Shift-Click selection
8. `FrmLibraryPathSorter.pas` `mnuDeleteEntryClick`: Updated to delete all selected items with count-aware confirmation message
9. `FrmLibraryPathSorter.pas` `lstWorkingClick`: Updated to highlight matching original panel entries for all selected working items
10. `FrmLibraryPathSorter.pas` `UpdateButtonStates`: Delete menu enabled state now uses `SelCount > 0`
11. `FrmLibraryPathSorter.pas` `lstWorkingMouseDown`: Skip drag initiation when Ctrl/Shift held so multi-select is not overridden; removed explicit `ItemIndex` assignment that was clearing selections

**Result:** Buttons now sit neatly in the left button strip below the navigation buttons, checkbox text displays fully, all internal panel sizes are persisted between sessions, and users can Ctrl-Click/Shift-Click to select multiple working panel entries for bulk deletion.

**Files Modified:** FrmLibraryPathSorter.dfm, FrmLibraryPathSorter.pas

---

## 2026-03-15 - v3.11.3 - Rename Library Path Sorter to IDE Path Sorter

**Context:** The tool was named "Library Path Sorter" but it handles all IDE path types (Library Path, Browsing Path, Debug DCU Path, etc.), not just library paths. The dropdown also showed "Search Path" which is the registry key name, not the user-facing Delphi terminology ("Library Path").

**Changes Made:**
1. `LibraryPathSorter.pas` line 526: Menu caption `'Library Path &Sorter...'` → `'IDE Path &Sorter...'`
2. `FrmLibraryPathSorter.dfm` line 2: Form caption `'Library Path Sorter'` → `'IDE Path Sorter'`
3. `LibraryPathSorter.pas` line 130: Display name `'Search Path'` → `'Library Path'` (matches Delphi's terminology)
4. `version.inc`: Bumped `VersionNumber` from `'3.10.3'` to `'3.11.3'`
5. All `.dproj` files (D_D102–D_D130, Installer): Updated `VerInfo_MinorVer`, `FileVersion`, and `ProductVersion` to 3.11.3

**Result:** Tool name now accurately reflects its broader scope, and path type names match Delphi's UI terminology.

**Files Modified:** LibraryPathSorter.pas, FrmLibraryPathSorter.dfm, version.inc, version.h, all .dproj files, Changes.txt

---

## 2026-02-21 - v3.10.3 - Add About Dialog + Version Bump

**Context:** No About dialog existed in the DDevExtensions submenu. Version bumped from 3.9.3 to 3.10.3 to reflect the new feature.

**Changes Made:**
1. `Source\Main.pas`: Added `ShowAboutDialog` procedure — builds a programmatic modal dialog using native VCL components (`TForm`, `TLabel`, `TButton`) showing plugin name, version, copyright lines, and an OK button
2. `Source\Main.pas` line 52: Added `MenuItemAbout: TMenuItem` unit-level variable
3. `Source\Main.pas` `IDELoaded`: After all LateLoader callbacks complete, appends a separator and `&About...` menu item to the bottom of the DDevExtensions submenu
4. `Source\version.inc`: Bumped `VersionNumber` from `'3.9.3'` to `'3.10.3'` — single source of truth; About dialog, `sPluginName`, and `sPluginVersion` all update automatically at compile time
5. All `.dproj` files (D_D102–D_D130, Installer): Updated `VerInfo_MajorVer`, `VerInfo_MinorVer`, `VerInfo_Release`, `FileVersion`, and `ProductVersion` fields to `3.10.3`

**Result:** "About..." appears as the last item in the DDevExtensions submenu. Clicking it displays a centred dialog with version and copyright information. Closes on OK or Escape.

**Files Modified:** Source\Main.pas, Source\version.inc, D_D102\DDevExtensions.dproj, D_D103\DDevExtensions.dproj, D_D104\DDevExtensions.dproj, D_D110\DDevExtensions.dproj, D_D120\DDevExtensions.dproj, D_D130\DDevExtensions.dproj, Installer\DDevExtensionsReg.dproj

---

## 2026-02-21 - v3.9.3 - Fix Compile Progress Bar Position at Non-100% DPI Scaling

**Context:** User feedback (ertank, 2026-02-10) reported that the compilation progress bar position was broken at non-100% display scaling. Root cause: `SetMaxFiles` in `NativeProgressForm.pas` used `pnErrors` as the reference panel, but Delphi 12+ changed the compile progress dialog layout — the correct reference panel is `pnHints`. Additionally, DPI scaling (`ScaleForPPI`) and dynamic height (`TotalLines.Height div 2`) from v2.91 were missing.

**Changes Made:**
1. `Source\CompileProgress\NativeProgressForm.pas` line 493: Changed component lookup from `'pnErrors'` to `'pnHints'` to match Delphi 12+/13 IDE layout
2. `Source\CompileProgress\NativeProgressForm.pas` line 499: Added `FProgressBar.ScaleForPPI(Form.CurrentPPI)` for High DPI support; changed fixed height `7` to `TotalLines.Height div 2` for dynamic scaling

**Result:** Progress bar now positions and scales correctly at all DPI settings (100%, 125%, 150%, etc.) on Delphi 13. Build 728.

**Files Modified:** Source\CompileProgress\NativeProgressForm.pas

---

## 2026-02-14 - Library Path Sorter - Invalid Path Highlighting

**Context:** Library Path Sorter already highlighted duplicates (red) and missing paths (pink), but provided no filesystem validation. Users needed to identify paths that don't exist on disk to clean up invalid library path entries.

**Changes Made:**
1. FrmLibraryPathSorter.pas: Added filesystem validation with caching for performance
2. Added `FPathValidityCache: TDictionary<string, Boolean>` for caching validation results
3. Implemented `ExpandPathMacros()` - expands `$(PLATFORM)` using combo box selection, delegates to `IDEUtils.ExpandDirMacros` for other macros
4. Implemented `IsPathValid()` - validates paths with caching, handles empty paths and unexpanded macros, uses `DirectoryExists`
5. Implemented `InvalidatePathCache()` - clears cache on platform/path type changes
6. Cache invalidated when switching platforms, path types, or loading paths (macro expansion context changes)
7. Updated `lstWorkingDrawItem` - invalid paths shown in **bold blue**, takes priority over red duplicates
8. Updated `lstCurrentDrawItem` - invalid paths shown in **bold blue**, takes priority over maroon missing, pink background preserved for missing paths
9. Panel labels updated:
   - Original: "Pink = not in Working, Blue = invalid"
   - Working: "Red = duplicate, Blue = invalid"

**Colour Precedence:**
- Working panel: Invalid (blue) > Duplicate (red) > Normal
- Original panel: Invalid (blue) text > Missing (maroon) text, pink background preserved for missing paths
- Invalid paths always bold regardless of other conditions

**Result:** Users can now identify non-existent paths on disk at a glance. Invalid paths shown in bold blue on both panels. Validation respects macro expansion and caches results for performance.

**Files Modified:** FrmLibraryPathSorter.pas (line 18: added Generics.Collections; lines 97-101: added private members; lines 613-680: added validation methods; lines 146, 185: cache init/free; lines 237, 488, 492: cache invalidation; lines 541-591: updated lstWorkingDrawItem; lines 639-695: updated lstCurrentDrawItem; lines 617-620: updated labels)

---

## 2026-02-14 - Project Configuration - Win32-Only Platform

**Context:** DDevExtensions hooks into the Delphi IDE which is 32-bit only. Win64 platform support was incorrectly configured, causing build errors with x86 assembly code incompatible with x64.

**Changes Made:**
1. Set `<TargetedPlatforms>1</TargetedPlatforms>` (Win32-only) in all project files:
   - DDevExtensions.dproj (all 6 Delphi versions: D102, D103, D104, D110, D120, D130)
   - CompileInterceptorW.dproj
   - DDevExtensionsReg.dproj
2. Removed Win64 as a build target - IDE extensions must match IDE architecture (32-bit)
3. Projects now correctly show Win32-only in platform selector

**Result:** Projects properly configured as 32-bit-only IDE extensions. Win64 build errors eliminated. Cannot accidentally attempt x64 builds.

**Files Modified:**
- All DDevExtensions.dproj files (6 Delphi versions)
- CompileInterceptor/Source/CompileInterceptorW.dproj
- Code/DDevExtensions/Installer/DDevExtensionsReg.dproj

---

## 2026-02-08 - DFM Parser Unit Development

**Context:** Development of new DFM parser functionality to enhance form file analysis capabilities.

**Changes Made:**
- Created new DFMParser unit with comprehensive testing
- Parser successfully tested via DfmParserTests project
- Not yet integrated into main DDevExtensions codebase (pending)

**Result:** Working DFM parser unit ready for future integration into form analysis features.

**Files Modified:** DfmParserTests project files

---

## 2026-01-27 - Version 3.9.2 - Fix for Options Dialog

**Problem:** Options dialog had unspecified issues preventing proper operation.

**Changes Made:**
- Fixed critical bug in Options dialog
- Exact nature of fix not detailed in source records

**Result:** Options dialog now functions correctly.

**Files Modified:** FrmDDevExtOptions.pas (likely)

---

## 2026-01-14 - Version 3.9.1 - Library Path Sorter Critical Path Loss Fix

**Problem:** Library Path Sorter had a critical bug where paths could be lost during sorting operations. TStringList.Sort with CaseSensitive=False could lose paths under certain conditions.

**Changes Made:**
1. FrmLibraryPathSorter.pas: Rewrote SortPaths to use array-based QuickSort instead of TStringList.Sort
2. Added explicit path count validation before and after every sort operation
3. Sort Alphabetically button now restores from backup if paths are lost
4. LoadWorkingPaths falls back to unsorted copy if sort loses paths
5. Apply button shows CRITICAL WARNING if path count mismatch detected
6. Exception raised if sort produces incorrect path count (fail-safe)
7. Delete now requires confirmation to prevent accidental deletions
8. Path comparison now trims whitespace (fixes false "missing" detection)
9. Enhanced "Show Missing Paths" with close-match analysis
10. Diagnostic now shows count of unmatched paths
11. Panel labels explain colour coding (Pink = not in Working, Red = duplicate)

**Additional Fixes:**
- Paths appeared invalid (greyed out) in Delphi after saving - removed all path quoting logic to match Delphi's native registry format (semicolon-separated values without quotes)
- Added reminder to restart Delphi shown when closing after changes applied

**Result:** Path loss bug eliminated, safer sorting operations, better user feedback and diagnostics.

**Files Modified:** FrmLibraryPathSorter.pas

---

## 2026-01-14 - Version 3.9.0 - Library Path Sorter Enhanced Diagnostics

**Problem:** Users needed better visibility into path changes and potential losses during Library Path Sorter operations.

**Changes Made:**
1. Moved Library Path Sorter to Tools menu (below Build Statistics) for easier access
2. Path counts displayed in panel labels (e.g., "Original Paths: 73", "Working Panel: 73")
3. Deleted entry counter tracks manual deletions and compares against actual difference
4. Mismatch warning displayed if deleted count differs from expected difference
5. Visual highlighting of paths missing from working panel (pink background, maroon bold text)
6. "Show Missing Paths..." context menu option on original panel
7. Resizable Original Panel width via horizontal splitter between panels
8. Form position, size, and panel width preserved between sessions
9. Fixed potential issue where duplicate paths could be lost during sorting

**Result:** Enhanced diagnostics help users understand and verify path changes before applying them.

**Files Modified:** FrmLibraryPathSorter.pas, LibraryPathSorter.pas

---

## 2026-01-13 - Version 3.8.0 - Library Path Sorter Feature Added

**Problem:** Delphi's library path management in Options dialog is cumbersome - difficult to see full paths, no sorting capability, no duplicate detection, no backup/restore, and manual reordering is tedious.

**Changes Made:**
1. Created new Library Path Sorter tool with dual-panel interface
2. Left panel shows read-only original paths, right panel is editable working area
3. Support for all path types: Search Path, Browsing Path, Debug DCU Path, HPP Output Directory, Namespace Prefixes, Package DCP/DPL Output, Translated paths
4. Support for all platforms (Win32, Win64, etc.)
5. Sort paths alphabetically with one click
6. Manual reordering via Up/Down/Top/Bottom buttons or drag-and-drop
7. Delete entries via right-click context menu
8. Duplicate path detection with red bold highlighting
9. Cross-panel highlighting: click working entry to highlight matches in original
10. Automatic backup before applying changes (configurable)
11. Backup history with restore and delete capabilities
12. Access via Tools > DDevExtensions > Library Path Sorter...

**Result:** Powerful new tool for managing IDE library paths with safety features and backup capability.

**Files Modified:**
- Created: FrmLibraryPathSorter.pas/.dfm, LibraryPathSorter.pas
- Modified: Main.pas, RegisterPlugins.pas

---

## 2026-01-10 - Version 3.7.0 - Anti-Pattern Detection & Compiler Integration

**Problem:** Code Style Checker only detected naming convention violations. No detection of common anti-patterns like deep nesting, long methods, or empty finally blocks. Style issues only visible when manually running the checker.

**Changes Made:**

**Code Style Checker Anti-Pattern Detection:**
1. Empty Finally Blocks - detects `finally` blocks with no statements
2. Nested With Statements - detects `with` statements nested more than one level deep
3. Deep Nesting - detects control flow (if/for/while/try) exceeding configurable depth threshold (default: 4)
4. Long Methods - detects methods exceeding configurable line count (default: 100 lines)
5. Long Parameter Lists - detects methods with too many parameters (default: 6)
6. All anti-pattern checks individually configurable with customisable thresholds

**Compiler Progress Style Check Integration:**
7. New option to automatically run Code Style Checker after successful compilation
8. New "Style Issues" tab in Build Statistics dialog showing all style violations from last compile
9. Full sorting, filtering by category (Naming Convention vs Anti-Pattern), navigation, copy, and export functionality

**Result:** Comprehensive code quality analysis with automatic post-compile checking and integrated reporting.

**Files Modified:**
- CodeStyleChecker.pas, FrmCodeStyleChecker.pas/.dfm
- CompileProgress.pas, FrmBuildStatistics.pas/.dfm
- FrmeOptionPageCodeStyle.pas/.dfm

---

## 2026-01-09 - Version 3.6.2 - Dead Code Cleanup

**Problem:** RemovePixelsPerInchProperty.pas contained commented-out CodeSite logging code that was no longer needed.

**Changes Made:**
- Removed dead CodeSite logging code from RemovePixelsPerInchProperty.pas
- Removed commented-out uses clause entry
- Removed unused conditional compilation block

**Result:** Cleaner codebase with unnecessary code removed.

**Files Modified:** RemovePixelsPerInchProperty.pas

---

## 2026-01-08 - Version 3.6.1 - Delphi 10.2-10.4 Compilation Fix

**Problem:** Remove PixelsPerInch Property feature failed to compile in Delphi 10.2-10.4 because `ReadPixelsPerInch`/`WritePixelsPerInch` methods were introduced in Delphi 11.

**Changes Made:**
1. Added conditional compilation directives to RemovePixelsPerInchProperty.pas
2. Delphi 11+: Use native ReadPixelsPerInch/WritePixelsPerInch methods
3. Delphi 10.2-10.4: Implement custom property read/discard logic
4. Feature now reads and discards PixelsPerInch property from DFM files created in Delphi 11+

**Result:** Feature works in all supported Delphi versions (10.2-13), enabling cross-version DFM compatibility.

**Files Modified:** RemovePixelsPerInchProperty.pas

---

## 2026-01-07 - Version 3.6.0 - Code Quality Analyzer & Dependency Viewer Enhancements

**Problem:** Code Style Checker lacked variable type prefix rules and unit scope name checking. No unified tool for detecting common code quality issues. Dependency Viewer lacked export capability for circular references and architectural layer enforcement.

**Changes Made:**

**Code Style Checker Enhancements:**
1. Variable Type Prefix Rules - custom type-to-prefix mappings (e.g., String=s, Integer=i, Boolean=l)
2. Supports `array of X` syntax in type definitions
3. Conflict detection when rule patterns overlap
4. Unit Scope Names - flags uses clauses missing scope prefixes (e.g., `SysUtils` should be `System.SysUtils`)

**New Code Quality Analyzer:**
5. Unified tool detecting: magic numbers, hardcoded strings, commented-out code, empty except blocks, catch-all exception handlers, missing try/finally patterns, potential memory leaks
6. All detectors configurable with whitelists and thresholds
7. Full sorting, filtering, navigation, export capabilities

**Dependency Viewer Enhancements:**
8. Export Circular References - export circular reference analysis to CSV or TXT files
9. Layer Violation Detection - define architectural layers with pattern-based unit matching
10. Visual dependency matrix with checkbox rules
11. Detect forbidden cross-layer dependencies
12. Default configuration for typical Delphi architecture included

**Result:** Comprehensive code quality and architectural analysis tools.

**Files Modified:**
- CodeStyleChecker.pas, FrmCodeStyleChecker.pas/.dfm, FrmTypePrefixEditor.pas/.dfm
- Created: Code Quality Analyzer units (exact names not in source records)
- DependencyViewer.pas, FrmDependencyViewer.pas/.dfm, FrmLayerConfig.pas/.dfm

---

## 2026-01-06 - Version 3.5.2 - Code Style Checker Bug Fixes

**Problem:** Code Style Checker had multiple bugs: field detection not working due to look-ahead consuming tokens, method names/parameters incorrectly flagged as fields, return types/case labels incorrectly flagged as parameters, function names without parameters flagged as parameters, false positives for built-in types in default parameter values, and line number navigation off by one.

**Changes Made:**
1. Fixed: Field detection not working (look-ahead consuming tokens)
2. Fixed: Method names incorrectly flagged as fields (e.g., DoLogin)
3. Fixed: Method parameters incorrectly flagged as fields
4. Fixed: Return types incorrectly flagged as parameters (e.g., SmallInt, TSMTPEncryption)
5. Fixed: Case labels incorrectly flagged as parameters
6. Fixed: Function names without parameters flagged as parameters
7. Fixed: False positives for built-in types like Boolean in default parameter values
8. Fixed: Line number navigation off by one (0-based to 1-based conversion)
9. Changed: All feature dialogs are now non-modal and open at screen centre

**Result:** Code Style Checker now accurately detects naming violations without false positives. Improved user experience with non-modal dialogs.

**Files Modified:** CodeStyleChecker.pas, FrmCodeStyleChecker.pas, and all feature form units

---

## 2026-01-05 - Version 3.5.1 - Dead Code & Event Handler Detector Fixes

**Problem:** Dead Code Detector had field name parsing bug (showing ":" or "ClassName.:" instead of proper field names). Both Dead Code Detector and Code Style Checker incorrectly flagged VCL components. Empty Event Handler Detector had false positives for non-event methods.

**Changes Made:**
1. Fixed: Dead Code Detector - field name was being read from colon token instead of identifier token
2. Fixed: Dead Code Detector and Code Style Checker - both now correctly skip VCL components in implicit published section of forms, only check fields after explicit private/protected keyword
3. Fixed: Empty Event Handler Detector - event patterns now require suffix at END of name (e.g., "Button1Click" not "GetActionText")
4. Fixed: Empty Event Handler Detector - removed overly broad "action" pattern (action handlers end with Execute/Update)
5. Fixed: Empty Event Handler Detector - methods containing case/try statements now correctly detected as non-empty
6. Changed: DDevExtensions submenu items reordered by workflow (dependency/uses analysis → code quality → style/consistency)

**Result:** Accurate detection with fewer false positives. Improved menu organisation.

**Files Modified:**
- DeadCodeDetector.pas, FrmDeadCodeDetector.pas
- CodeStyleChecker.pas
- EmptyEventHandlerDetector.pas, FrmEmptyEventHandlerDetector.pas
- Main.pas (menu reordering)

---

## 2026-01-05 - Version 3.5 - Dependency Viewer Conditional Compilation Support

**Problem:** Dependency Viewer produced false positive circular references in multi-app codebases where units used conditional compilation to include/exclude dependencies based on project defines.

**Changes Made:**
1. DependencyViewer.pas: Added support for reading project defines from .dproj file
2. Implemented evaluation of {$IFDEF}, {$IFNDEF}, {$IF Defined(...)}, {$ELSE}, {$ELSEIF}, {$ENDIF} blocks
3. Support for compound expressions: Defined(X) or Defined(Y), Defined(X) and Defined(Y)
4. Excludes inactive code from dependency analysis
5. New "Respect conditional compilation" option (enabled by default)

**Result:** Eliminates false positive circular references in projects using conditional compilation. More accurate dependency analysis.

**Files Modified:** DependencyViewer.pas, FrmDependencyViewer.pas/.dfm, FrmeOptionPageDependencyViewer.pas/.dfm

---

## 2026-01-05 - Version 3.4.1 - Three New Code Quality Features

**Problem:** Developers needed quick interface/implementation navigation, detection of empty event handlers, and verification of DFM/PAS consistency.

**Changes Made:**

**Interface/Implementation Section Toggle:**
1. New Ctrl+Shift+Up/Down keyboard shortcut
2. Instantly jumps between interface and implementation sections
3. Integrated with existing enhanced keybindings

**Empty Event Handler Detector:**
4. Finds event handlers with empty bodies (just begin/end with no code)
5. Detects common event handler patterns (OnClick, OnChange, OnCreate, etc.)
6. Shows class name, method name, and line number
7. Double-click to navigate to source
8. Non-modal dialog with export/copy capabilities

**DFM/PAS Consistency Checker:**
9. Detects mismatches between DFM components and PAS field declarations
10. Missing in PAS: Component exists in DFM but no field declared
11. Missing in DFM: Field declared in PAS but no component (orphaned declaration)
12. Type Mismatch: Component exists in both but types differ
13. Filter by control type (Input vs Passive controls)
14. Double-click navigation to form designer or PAS declaration
15. Intelligent filtering excludes non-component types and state/activity types

**Result:** Enhanced developer productivity with quick navigation and automated consistency checking.

**Files Modified:**
- Keybindings units (exact name not in source records)
- Created: EmptyEventHandlerDetector.pas, FrmEmptyEventHandlerDetector.pas/.dfm, FrmeOptionPageEmptyHandler.pas/.dfm
- Created: DfmPasConsistency.pas, FrmDfmPasConsistency.pas/.dfm, FrmeOptionPageDfmPas.pas/.dfm
- Main.pas, RegisterPlugins.pas

---

## 2026-01-04 - Version 3.2.1 - TextHeight Option Bugfix

**Problem:** RemoveTextHeightProperty feature had unspecified bug preventing proper operation.

**Changes Made:**
- Fixed bug in TextHeight removal logic
- Exact nature of fix not detailed in source records

**Result:** TextHeight property removal now works correctly.

**Files Modified:** RemoveTextHeightProperty.pas (likely)

---

## 2026-01-03 - Version 3.4 - Smart Uses Clause Manager

**Problem:** Developers manually manage uses clause organisation, often placing units in interface when they're only used in implementation, increasing compilation dependencies unnecessarily.

**Changes Made:**
1. Created new Uses Clause Manager tool
2. Build exports database from project search paths
3. Analyse current unit's identifier usage in interface vs implementation sections
4. Recommend optimal uses clause placement for each unit
5. Show which identifiers from each unit are used and where
6. Apply changes with full undo support (Ctrl+Z)
7. Right-click "Move to Recommended Section" to move selected unit(s) individually
8. RTL/VCL priority for ambiguous identifiers (same identifier exported by multiple units)
9. Export results to CSV or copy to clipboard
10. Double-click to navigate to source

**Decision Logic:**
- Unit should be in interface uses clause if ANY identifiers appear in interface section
- Unit should be in implementation uses clause if ALL identifiers appear only in implementation section

**Result:** Automated uses clause optimisation reduces compilation dependencies and improves build times.

**Files Modified:**
- Created: UsesClauseManager.pas, FrmUsesClauseManager.pas/.dfm, FrmeOptionPageUsesClause.pas/.dfm
- Main.pas, RegisterPlugins.pas

---

## 2026-01-03 - Version 3.3.1 - Unreachable Code Detector

**Problem:** No tool to detect code that can never execute due to preceding Exit, Raise, Break, Continue, Halt, or Abort statements.

**Changes Made:**
1. Created new Unreachable Code Detector tool
2. Detects code after Exit, Raise, Break, Continue, Halt, and Abort calls
3. Smart detection: ignores conditional terminators (e.g., `if X then Exit;` - code after is reachable)
4. Case statement aware: recognises terminators inside case branches
5. Handles variables named after keywords (e.g., `Continue := False;` recognised as assignment)
6. Properly skips string literals including Delphi 12+ triple-quoted multi-line strings
7. Conditional compilation aware: reads project defines and handles {$IFDEF}, {$IFNDEF}, {$IF}, {$ELSE} blocks
8. Shows project name being scanned and reason why code is unreachable
9. Filter by reason type (After Exit, After Raise, After Break, etc.)
10. Only scans implementation section (interface section skipped)

**Known Limitations:**
- Complex {$IF} expressions (with and/or operators) cannot be fully evaluated
- Assembly blocks with embedded jumps not analysed

**Result:** Static analysis tool helps identify dead code paths. Results require manual verification.

**Files Modified:**
- Created: UnreachableCodeDetector.pas, FrmUnreachableCodeDetector.pas/.dfm, FrmeOptionPageUnreachableCode.pas/.dfm
- Main.pas, RegisterPlugins.pas

---

## 2026-01-03 - Version 3.3.0 - Dependency Viewer Major Enhancement

**Problem:** Dependency Viewer showed only forward dependencies ("uses"). No way to see reverse dependencies ("used by"), understand dependency depth, or assess impact of changes. Circular reference display lacked detail about which uses clause caused each link.

**Changes Made:**
1. Added "Uses" / "Used By" view modes toggle
2. Dependency depth indicator shows position in dependency chain (e.g., [0] = no project dependencies, [3] = depends on units at depth 2)
3. Units in any circular reference marked with (!) prefix (e.g., `(!) [1] ReportsFrm`)
4. Enhanced circular reference display shows which uses clause causes each link (-[I]-> for interface, -[impl]-> for implementation)
5. Colour-coded circular reference count (green=none, orange=10-99, red=100+)
6. Click a circular reference to mark those specific cycle members with `>>> <<<` in tree
7. Double-click a circular reference to open first unit in editor
8. Auto-sizing tree panel based on longest unit name
9. Impact Analysis panel - select any unit to see:
   - Direct dependents count (units that directly use the selected unit)
   - Transitive dependents count (all units affected, including indirect dependencies)
   - Risk level indicator (Safe/Low/Medium/High) with colour-coded visual

**Result:** Comprehensive dependency analysis with reverse view, impact assessment, and detailed circular reference information.

**Files Modified:** DependencyViewer.pas, FrmDependencyViewer.pas/.dfm

---

## 2026-01-03 - Version 3.2 - Form Designer DPI/Font Phantom Changes Prevention

**Problem:** Different DPI settings and font rendering across developer machines caused phantom changes to PixelsPerInch and TextHeight properties in DFM files, creating unnecessary version control noise and merge conflicts.

**Changes Made:**
1. Added "Remove PixelsPerInch property" option (default: off)
2. Prevents PixelsPerInch property from being saved to DFM files
3. Added "Remove TextHeight property" option (default: off)
4. Prevents TextHeight property from being saved to DFM files
5. Both features based on work from DelphiPraxis fork (acknowledged in README.md)

**Result:** Eliminates phantom DFM changes caused by different DPI settings and font rendering. Cleaner version control history.

**Files Modified:**
- Created: RemovePixelsPerInchProperty.pas, RemoveTextHeightProperty.pas
- FrmeOptionPageFormDesigner.pas/.dfm
- Main.pas

---

## 2026-01-03 - Version 3.1 - Five New Code Quality Tools

**Problem:** No built-in tools for tracking TODO comments, enforcing naming conventions, detecting unused code, or analysing code metrics during builds.

**Changes Made:**

**Build Statistics Enhancement:**
1. Added code metrics to Build Statistics: Lines of Code (LOC) and Cyclomatic Complexity per unit
2. Summary statistics show total units, total LOC, average complexity
3. UnitMetrics.pas created to calculate LOC and complexity based on decision points

**TODO/FIXME Aggregator:**
4. Scans project for TODO, FIXME, HACK, BUG, NOTE, XXX comment markers
5. Parses optional priority: TODO(high):, FIXME(low):
6. Filter by category and priority
7. Sortable columns, double-click navigation, export to CSV

**Code Style Checker:**
8. Checks Delphi naming convention compliance
9. Rules: Type names start with T, Interfaces with I, Fields with F, Exceptions with E, Pointers with P, optional Parameters with A
10. Filter by rule type and severity
11. Enable/disable individual rules via options

**Dead Code Detector:**
12. Detects procedures, functions, and fields never referenced in project
13. Automatically ignores: virtual/override methods, constructors/destructors, event handlers, published members
14. Wildcard ignore patterns (e.g., *Click, Get*)
15. Right-click "Add to Ignore List" for false positives

**All New Tools:**
16. Access via Tools → DDevExtensions submenu
17. All feature sortable columns, double-click navigation, export to CSV, copy to clipboard capabilities

**Result:** Comprehensive code quality toolset for maintaining large Delphi codebases.

**Files Modified:**
- CompileProgress/UnitMetrics.pas (created)
- CompileProgress/FrmBuildStatistics.pas/.dfm (enhanced)
- Created: TodoAggregator/, CodeStyleChecker/, DeadCodeDetector/ directories with full implementations
- Main.pas, RegisterPlugins.pas

---

## 2026-01-02 - Version 3.0 - Public Release (Ian Branch)

**Context:** Complete rewrite and modernisation of DDevExtensions for Delphi 10.2+. Version 3.0 marks the first public release of the Ian Branch, clearly breaking from Andreas Hausladen's version 2.88.

**Changes Made:**
1. Extensive rework for Delphi 10.2 through Delphi 12.0 (later extended to 13.0)
2. All identified issues from version 2.88 resolved
3. Codebase modernised with improved structure and documentation
4. Repository prepared for public release on GitHub
5. README.md created with comprehensive documentation
6. Help.md created with detailed feature descriptions
7. Acknowledgement of Andreas Hausladen and all contributors
8. Added DDevExtensions_Map.html - interactive project dependency map

**Result:** Modern, stable DDevExtensions for current Delphi versions with full documentation and public availability.

**Files Modified:** Extensive changes across entire codebase

---

## Pre-2026 - Version 2.88 - Delphi 11.0 Alexandria Support

**Changes Made:**
- Added: Support for Delphi 11.0 Alexandria

**Files Modified:** Project files for all Delphi versions, version detection logic

---

## Pre-2026 - Version 2.87 - Delphi 10.4 Sydney Support

**Changes Made:**
- Added: Support for Delphi 10.4 Sydney

**Files Modified:** Project files for all Delphi versions, version detection logic

---

## Pre-2026 - Version 2.86 - FindUnit Dialog Performance

**Changes Made:**
- Improved: The FindUnit/UnitSelector Dialog filter is significantly faster (workaround for TListView performance issue)

**Files Modified:** UnitSelector dialog units

---

## Pre-2026 - Version 2.85 - Delphi 10.3 Rio Support

**Changes Made:**
- Added: Support for Delphi 10.3 Rio
- Added: Use Unit dialog option "Every unit on a single line"
- Improved: UnitSelector Dialog in Delphi 2009 opens much faster
- Fixed: Structure-View search dropdown had a max height of 2 items

**Files Modified:** Project files, UnitSelector units, StrucViewSearch.pas

---

## Pre-2026 - Version 2.84 - Delphi 10.2 & 10.1 Support

**Changes Made:**
- Added: TAB key works like ENTER in the CodeInsight window
- Added: Support for Delphi 10.1 Berlin
- Added: Support for Delphi 10.2 Tokyo

**Files Modified:** Project files, CodeInsight handling units

---

## Pre-2026 - Version 2.83 - Delphi 10 Seattle Support

**Changes Made:**
- Added: Support for Delphi 10 Seattle

**Files Modified:** Project files for all Delphi versions

---

## Pre-2026 - Version 2.82 - Class Completion & XE6 Fix

**Changes Made:**
- Added: Disable Alpha-Sort Class Completion (Default off)
- Fixed: XE6 broke "Switch to module project" dialog

**Files Modified:** DisableAlphaSortClassCompletion.pas, FrmSwitchToModuleProject.pas

---

## Pre-2026 - Version 2.81 - XE6 Support

**Changes Made:**
- Added: XE6 support
- Fixed: Reload files dialog caused access violation in XE5. All "smart" logic removed.

**Files Modified:** Project files, FrmReloadFiles.pas

---

## Pre-2026 - Version 2.8 - XE5 Support

**Changes Made:**
- Added: XE5 support
- Fixed: Shift+Ctrl+Alt+Up/Down didn't work
- Fixed: Fonts used in DDevExtensions dialogs were a mixture of MS Sans Serif and Tahoma on a per Control base

**Files Modified:** Project files, keybinding handlers, all form files

---

## Pre-2026 - Version 2.7 - Major Feature Release

**Changes Made:**
- Added: Start Parameters ComboBox context menu to create and edit *.params files
- Added: Reload file dialog replacement with diff-tool binding (one dialog for all modified files)
- Added: Option to release compiler unit cache for all other projects when compiling
- Added: Compile progress shown in Taskbar (Win 7+) with error and warning state
- Added: Shift+Ctrl+Alt+Up/Down moves current line or block up/down
- Added: Ctrl+Alt+PgUp invokes "Find Declaration"
- Added: XE4 support
- Improved: "Set VersionInfo" dialog
- Improved: More greedy filename pattern matching for "Use Unit" dialog replacement
- Fixed: Use Unit replacement dialog didn't show units in paths with $(Platform)
- Fixed: Code Parser couldn't handle non-ASCII identifiers
- Fixed: All DDevExtensions versions 2009+ were debug builds instead of release builds (D2007: "Configuration=Release" vs. D2009+: "Config=Release")
- Fixed: "Open file at cursor" replacement path list didn't use XE2+'s current project's platform library and browsing paths

**Files Modified:** Extensive changes across StartParameterManager/, Editor/, CompileProgress/, FrmReloadFiles.pas, ProjectSettings/, keybinding units, PascalParser/

---

## Pre-2026 - Version 2.6 - Start Parameters Feature

**Changes Made:**
- Added: Start Parameters
- Added: Kill all Dexplore.exe when closing the IDE (default: active)
- Added: Ctrl+F1 asks before invoking context help if debugger is active (default: active)
- Added: UnitSelector/FileSelector saves last used directory filter
- Fixed: Replace "Open File At Cursor" opened correct file but with relative path that doesn't match current path
- Fixed: UnitSelector/FileSelector didn't load column widths correctly
- Fixed: UnitSelector/FileSelector preferred source files from reversed search path
- Fixed: Option "Allow single line indention" was ignored
- Improved: FileSelector performance
- Removed: "Last compile time" version info (doesn't work anymore starting with XE2)

**Files Modified:**
- Created: StartParameterManager/ directory
- Editor/, UnitSelector/, FileSelector/, DSUFeatures/

---

## Pre-2026 - Version 2.5 - XE2 Support

**Changes Made:**
- Added: Delphi XE2 support
- Added: Option to disable Debugger breaking in when spawned process is started
- Improved: ComponentSelector, OldPalette slowed down IDE start. Now if IDE Fix Pack is installed, they do not slow down IDE start anymore
- Fixed: LastCompile time format was not saved into DDevExtensions's config file

**Files Modified:** Project files, ComponentSelector/, OldPalette/, Debugger/

---

## Pre-2026 - Version 2.4 - Project Group Features

**Changes Made:**
- Added: "Package Add Unit" dialog replaced by "File Open" dialog (2007/2009)
- Added: Inheritable modules from packages in project group can be used in active project (Option: Show all inheritable modules)
- Added: Keybinding for Shift-F3 to reverse editor's search direction (2007/2009)
- Added: Replacement for "Open File At Cursor" algorithm allowing to open files from other projects in project group
- Improved: "Use/Search Unit" dialog now shows files from other projects in group as source file if they compile into directory in active project's search path
- Fixed: Compile ProgressBar only worked in Delphi 2010 and XE
- Fixed: StructureView search hotkey threw "Cannot focus invisible control" if structure view wasn't visible

**Files Modified:** Editor/, UnitSelector/, CompileProgress/, DSUFeatures/

---

## Pre-2026 - Version 2.3 - Use Unit Fixes

**Changes Made:**
- Fixed: Use Unit didn't work if file in editor had a dot in the name
- Fixed: Compile progress didn't work if you used projects dependencies

**Files Modified:** UnitSelector/, CompileProgress/

---

## Pre-2026 - Version 2.2.1 - Critical Use Units Fix

**Changes Made:**
- Fixed: "Use Units" dialog deleted chars from source file under certain circumstances if shift-key was used

**Files Modified:** UnitSelector/

---

## Pre-2026 - Version 2.2 - Use Units Enhancement

**Changes Made:**
- Added: "Use Units" dialog can move units from implementation to interface
- Improved: "Use/Search Units" dialog now underlines implementation-uses units in addition to bold weight
- Improved: "Use/Search Units" dialog is now significantly faster
- Fixed: Using SetVersionInfo after switching Build Configuration overwrote some project options (IDE bug)
- Fixed: Uses-parser could not handle unit names with dots like "Generics.Collections"
- Fixed: ComponentSelector dropdown had problems with multiple monitor setup with negative coordinates
- Fixed: StructureView Search didn't find sub components like TField

**Files Modified:** UnitSelector/, ProjectSettings/, ComponentSelector/, DSUFeatures/

---

## Pre-2026 - Version 2.1 - Delphi XE Support

**Changes Made:**
- Added: Embarcadero RAD Studio XE support
- Added: Set VersionInfo dialog can now change the main icon
- Fixed: Team Start parameters used ANSI instead of UTF8 encoding for dproj/cproj files
- Fixed: Access Violation when there is no active project even if there are projects (IDE bug?)
- Fixed: EListError in FileSelector

**Files Modified:** Project files, ProjectSettings/, StartParameterTeam/, FileSelector/

---

## Pre-2026 - Version 2.0 - Delphi 2010 Support

**Changes Made:**
- Added: Embarcadero RAD Studio 2010 support
- Added: Editor tab double click action (zoom, super-zoom)
- Added: Source Formatter hotkey (Ctrl+D) can be disabled
- Added: TAB key indention in single line didn't overwrite selection anymore
- Added: Shows "Switch Active Project" dialog if current editor file is not part of project that should be compiled
- Added: Structure View Search
- Added: Selected file in project manager shows project to which it belongs
- Added: Option for "Increment Build Number only when building the project"
- Added: Find Unit/Use Unit dialog has additional "selected list" for multi selection
- Improved: "Source code changed. Rebuild?" disabler is rewritten
- Removed: UnitSelector removed (superseded by RAD Studio 2010), "Find Unit" and "Use Unit" dialog still available

**Files Modified:** Project files, Editor/, DSUFeatures/, CompileProgress/, ProjectSettings/, UnitSelector/

---

## Pre-2026 - Version 1.93 - Compile Time Version Info

**Changes Made:**
- Changed: Start Parameter Team renamed to Local Start Parameters
- Changed: Renamed "Compiler Progress" option node to "Compilation"
- Fixed: Local Start Parameters weren't removed from project file
- Added: Background parser indication in caption of Structure View window
- Added: "Last Compile" time can be put into Version Info (format is configurable)
- Added: Macros for VersionInfo LegalCopyright field: $(CurrentYear), $(StartYear), $(Years)

**Files Modified:** StartParameterTeam/, CompileProgress/, ProjectSettings/, DSUFeatures/

---

## Pre-2026 - Version 1.92 - Find Unit Fixes

**Changes Made:**
- Fixed: Find Unit didn't work correctly for relative search/browsing paths
- Fixed: Use Unit dialog inserted selected unit at wrong position if there are multi-byte chars in editor

**Files Modified:** UnitSelector/

---

## Pre-2026 - Version 1.91 - Version Info Enhancement

**Changes Made:**
- Fixed: "Use unit" dialog: "Generics.Collections" was added to uses list as "Collections"
- Fixed: ProjectSettings feature is now removed completely
- Added: "Set Versioninfo" allows to change CompanyName and LegalCopyright
- Added: ComponentSelector is back but disabled by default

**Files Modified:** UnitSelector/, ProjectSettings/, ComponentSelector/

---

## Pre-2026 - Version 1.9 - Delphi 2009 Support

**Changes Made:**
- Added: Support for Delphi 2009
- Added: Compiler-Dialog: AutoSave after successful compile (default: off)
- Added: OldPalette: AlphaSort option for palette popup menu
- Added: OldPalette supports "Small Fonts" for tab font
- Added: "Close all and terminate" by keeping CTRL key pressed while closing IDE (from DelphiSpeedUp)
- Added: Disable package cache option (from DelphiSpeedUp)
- Added: Shows waiting cursor while loading designtime package (from DelphiSpeedUp)
- Added: Option to enable IDE's "User can cancel kibitzing" feature (CodeCompletion and HelpInsight can be aborted by ESC/mouse move)
- Added: "Add to implementation" checkbox in "Use Unit" Dialog can be switched by pressing SHIFT-key
- Re-enabled: Editor Focus bugfix (bug still exists)
- Removed: Delphi 5-2007 support
- Removed: ComponentSelector (superseded by Delphi's ToolPalette search edit)
- Removed: CompilerEnhancements (superseded by new project warning options)
- Removed: FormDesigner Alt key disables guide lines (superseded by Delphi 2009's implementation)

**Files Modified:** Project files, CompileProgress/, OldPalette/, DSUFeatures/, UnitSelector/, Editor/
**Removed:** CompilerEnhancements/ directory, Delphi 5-2007 project files

---

## Pre-2026 - Version 1.6 - Smart TABs & Fixes

**Changes Made:**
- Fixed: Smart TABs did not work
- Fixed: Unit Selection dialog now preselects opened file again
- Fixed: DDevExtensions failed to load correctly if some IDE packages were disabled (DelphiSettingManager)
- Fixed: If Team-Parameter feature was active, saving a ProjectGroups caused access violation
- Added: Extended Ctrl+Left/Right (VisualStudio compatible)

**Files Modified:** Keybindings/, UnitSelector/, StartParameterTeam/

---

## Pre-2026 - Version 1.5 - Extended Use Unit Dialog

**Changes Made:**
- Fixed: Keybinding options were not saved
- Fixed: TAB Key sometimes stopped working
- Added: Extended "Use Unit..." dialog
- Added: "Find Unit-File..." dialog in search menu (Delphi and Delphi.NET only)
- Added: Explicit* property remover (Delphi 2006 and newer)
- Added: Start Parameter Team: Start parameters are not saved to dof/dproj project file
- Added: Single line tab-indention is now optional and disabled by default

**Files Modified:** Keybindings/, UnitSelector/, FormDesignerHelpers/ (RemoveExplicitProperty.pas created), StartParameterTeam/ (created)

---

## Pre-2026 - Version 1.4 - RAD Studio 2007 Support

**Changes Made:**
- Added: Pressing ALT-key while moving controls around now disables VCL designer guide lines alignment (BDS 2006 or higher)
- Added: KeyBindings: TAB and Shift-TAB indent selected block. HOME jumps to first non-whitespace in line if current position is first column
- Added: TLabel.Margins.Bottom now defaults to zero allowing easier label placement
- Added: Compile progress dialog shows how long compilation took
- Added: RAD Studio 2007 support
- Changed: OldPalette is now a toolbar with multiline TabControl. Also builds component palette much faster
- Changed: ComponentSelector shows also registered components if Code-Editor is active (Delphi 5-7 only)
- Removed: Second TabBar is not available anymore
- Removed: UCS4 support for Delphi compiler
- Fixed: "(search component)" text was painted with opaque background
- Fixed: Renaming project file caused exception
- Fixed: Build-"Apply to all" button in version information editor overwrote build number with release number
- Fixed: Set Versioninfo's "Days between" button hadn't worked in evening
- Fixed: TLabel.Margins.Bottom was always written to DFM

**Files Modified:** Project files (added 2007), FormDesignerHelpers/ (LabelMarginHelper.pas), Keybindings/, CompileProgress/, OldPalette/, ComponentSelector/

---

## Pre-2026 - Version 1.3 - ComponentSelector & FileCleaner

**Changes Made:**

**Feature: Project Configurations**
- Fixed: In BDS C++ personality it was not possible to use "Set VersionInfo" dialog
- Fixed: Empty .dex files for projects are deleted when project is saved
- Fixed: Changing version info could cause access violations under Delphi/BCB 5, 6 and 7

**Feature: ComponentSelector**
- Added: When code editor is active, component list is replaced by "File/New" items and inheritable modules (also for Delphi/BCB 5, 6 and 7)
- Added: RETURN key now emulates double click on palette item

**Feature: FileCleaner**
- Fixed: Empty __history and Model directories were not always deleted

**Feature: UnitSelector**
- Fixed: Rewritten with much faster and cleaner code
- Added: Current unit/form is selected by default

**Feature: UCS4 support for Delphi source files**
- Added: New feature enables Delphi.Win32 IDE compiler to compile UCS4 files (moved from bcc32pch to DDevExtensions); default: off

**Feature: OldPalette (Delphi 2005/BDS 2006 only)**
- Added: This new feature brings old component palette back to BDS IDE

**Files Modified:** ProjectSettings/, ComponentSelector/, FileCleaner/, UnitSelector/, OldPalette/ (created)

---

## Pre-2026 - Version 1.2 - UnitSelector, CompileBackup, FileCleaner

**Changes Made:**

**General:**
- Added: "Tools/DDevExtensions Options..." menu item

**Feature: UnitSelector**
- Added: New feature UnitSelector replaces three dialogs "Use Units", "View Units" and "View Forms" by more advanced one that also has Excel export button

**Feature: CompileBackup**
- Added: New feature CompileBackup makes backup of all unsaved files when you compile a project. Backuped files are automatically deleted when you save files. When debugger crashes and kills IDE, you still have unsaved files. They have extra file extension .cbk

**Feature: FileCleaner**
- Added: New feature FileCleaner deletes .ddp files and empty __history and Model directories

**Feature: Project Configurations**
- Fixed: Delphi keeps second copy of version info and overwrites modified when "auto increment version number" is active
- Fixed: Removed debug code (console window)
- Added: "Build" number can be applied to all projects
- Added: "Days between" calculator that returns number of days since project file was created or user defined date
- Added: Increment Versioninfo page
- Added: "Set Versioninfo..." menu item, former way through "Manage configurations" is still available

**Feature: ComponentSelector**
- Added: Optional Hotkey
- Added: Height of popup list is now adjusted depending on number of listed components

**Files Modified:**
- Created: UnitSelector/, CompileBackup/, FileCleaner/
- Modified: Main.pas, ProjectSettings/, ComponentSelector/

---

## Pre-2026 - Version 1.1 - Project Configurations & CompilerProgress

**Changes Made:**

**General:**
- Added: Fixes the ALT+F12 form/text view bug
- Added: Fixes editor focus bug after desktop state change (Sets focus back to editor)

**Feature: ComponentSelector**
- Added: "Simple search" mode (AnsiStartsText)
- Added: Sort by palette name (default)
- Added: Prevention for multiple RegisterComponents() calls for one component
- Added: Delphi 2005 and BDS 2006 support for all personalities
- Added: Improved auto selection

**Feature: Project Configurations (Delphi, BCB and BDS Delphi/Delphi.NET personality)**
- Added: New feature Project Configurations manages different project configurations for project or set of projects. Also allows you to set version information for multiple projects

**Feature: CompilerProgress**
- Added: New feature CompileProgress shows progressbar during compilation of project and introduces "auto close after successful compile" checkbox for Delphi/BCB 5, 6 and 7

**Files Modified:**
- Created: ProjectSettings/, CompileProgress/
- Modified: Main.pas, ComponentSelector/, Editor/

---

## Pre-2026 - Version 1.0 - Initial Release (Andreas Hausladen)

**Context:** Split from DelphiSpeedUp 1.92 to create separate DDevExtensions package.

**Changes Made:**
- Split DelphiSpeedUp 1.92 into DelphiSpeedUp 1.95 and DDevExtensions 1.0
- Initial ComponentSelector feature for quick component search

**Result:** First release of DDevExtensions as standalone IDE extension package.

**Files Modified:** Initial project structure created

---

*This changelog consolidates information from Changes.txt (v1.0-3.9.1), README.md (detailed version descriptions), and git commit history. All versions from the project's inception through current development are documented above.*
