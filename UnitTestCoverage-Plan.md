# Unit-Test Coverage Plan

Living plan for extending automated, IDE-free unit tests across DDevExtensions. Tests live in `DDevExtUnitTests\` (renamed from `DfmParserTests`) and run under the DUnitX runner `DDevExtUnitTestsDUnitX.dpr` (the hand-rolled console runner `DDevExtUnitTests.dpr` was retired on 2026-10-21, its checks ported test-for-test into DUnitX fixtures). Supersedes the earlier analyzer-only scoping note.

## Current coverage

| Suite | Unit under test | Tests | Status |
|-------|-----------------|-------|--------|
| `TestDfmParser` (DUnitX) | `gllDelphiDFMParser` (parse/serialize round-trip, edits reach the serialised text, every `TestData` file) | 34 cases | green |
| `TestDelphiLexer` (DUnitX) | `DelphiLexer` (tokenisation + line/column contract, Delphi 12 multi-line strings, `&` identifiers, binary literals, digit separators) | 15 cases | green |
| `TestDelphiParserContainers` (DUnitX) | `DelphiParserContainers` (hashtable/list/dictionary) | 5 cases | all pass (`TestHashtableCaseSensitive` found the defect below) |
| `TestDelphiExpr` (DUnitX) | `DelphiExpr` (arithmetic/boolean nodes + parser, integer/float comparison) | 6 cases | green |
| `TestDelphiPreproc` (DUnitX) | `DelphiPreproc` ($IFDEF/$IFNDEF/$ELSE/$ELSEIF/$IFOPT/nested/$DEFINE) | 9 cases | green |
| `TestDelphiDesignerParser` (DUnitX) | `DelphiDesignerParser` (`ParseError` on a bad `{$IF}` or locked include) | 3 cases | green |
| `TestUnitMetrics` (DUnitX) | `UnitMetrics` (LOC + cyclomatic complexity) | 4 cases | green |
| `TestProjectGroupSorter` (DUnitX) | `ProjectGroupSorterCore` (`.groupproj` sort: ItemGroup + Targets + CallTargets, `DependsOnTargets`, sanitised names, line breaks) | 17 cases | green |
| `TestPathCompactor` (DUnitX) | `PathCompactorCore` (macro expansion, stored-space scoring, naming, hygiene, unticked variables, divergent names, relative entries) | 30 cases | green |
| `TestLibraryPathBackups` (DUnitX) | `LibraryPathBackups` (two writers, pinned backups, timestamps, quarantine, legacy import) | 6 cases | green |
| `TestUsesClauseManagerCore` (DUnitX) | `UsesClauseManagerCore` (exports DB, identifier usage, placement + entry-by-entry rewrite) | 50 cases | green |
| `TestDecirculariserCore` (DUnitX) | `DecirculariserCore` (SCC detection, fragile/benign classification, edge symbol attribution, start-up code, `RemoveUsesEntry`) | 43 cases | green |
| `TestMethodSeparatorsCore` (DUnitX) | `MethodSeparatorsCore` (separator scan, colour rules, paint throttle) | 25 cases | green |
| `TestDeadCodeCore` (DUnitX) | `DeadCodeCore` (cross-unit references, methods, RTTI members) | 11 cases | green |
| `TestUnreachableCodeCore` (DUnitX) | `UnreachableCodeCore` (conditional terminators, directives, predefined symbols) | 14 cases | green |
| `TestUnusedUnitCore` (DUnitX) | `UnusedUnitCore` (errs on "used": start-up code, helpers, conditionals) | 15 cases | green |
| `TestTodoAggregatorCore` (DUnitX) | `TodoAggregatorCore` (tag recognition) | 7 cases | green |
| `TestDfmPasConsistencyCore` (DUnitX) | `DfmPasConsistencyCore` (root class only, inherited forms, binary/UTF-16 DFMs) | 9 cases | green |
| `TestDependencyViewerCore` (DUnitX) | `DependencyViewerCore` (conditionals, cycles once per group, layer rules) | 13 cases | green |
| `TestExcelExport` (DUnitX) | `FrmExcelExport.ExcelCellText` (formula escaping) | 12 cases | green |
| `TestVirtTreeHandler` (DUnitX) | `VirtTreeHandler` (Win64 property-accessor decoding) | 5 cases (4 on Win32) | green |
| `TestInterceptDispatch` (DUnitX) | `InterceptDispatch` (interceptor registry and dispatch, non-native exceptions) | 14 cases | green |
| `TestPluginConfigCore` (DUnitX) | `PluginConfigCore` (load retry, locked/damaged classification, unique temporary names) | 11 cases | green |
| `TestFeatureSwitches` (DUnitX) | `FeatureSwitches` (`DisabledFeatures` parsing, other IDE versions' names) | 5 cases | green |
| `TestIDEHashLists` (DUnitX) | `IDEHashLists` (Win64 string hashing, `Assign`) | 5 cases | green |
| `TestVersionInfoKeys` (DUnitX) | `VersionInfoKeys` (`;`-only split, empty values kept) | 5 cases | green |
| `TestSimpleXmlDoc` (DUnitX) | `SimpleXmlDoc` (load/save) | 4 cases | green |
| `TestFileWatcher` (DUnitX) | `FileWatcher` (more than 62 folders, rename saves) | 3 cases | green |
| `TestHooking` (DUnitX) | `Hooking` (ModRM/SIB lengths, `CodeRestore` guard, full-replace install/remove, patch bytes) | 6 cases | green |
| `TestImportHooking` (DUnitX) | `ImportHooking` (redirect, restore by `Unhook` and by freeing the list, failure reporting) | 3 cases | green |

**Suite total (2026-11-09): 389 tests on Win64, 388 on Win32**, all passing (`bin\DDevExtUnitTestsDUnitX-results.xml`, 389 run, 0 failed).

**Tier 1 complete; Tier 2 = `UnitMetrics` only** (Tier 3 partly done on 2026-11-09, see below).  **Defect found and fixed (2026-10-21):** the Shared parser units tested `COMPILER6_UP` / `COMPILER10_UP` / `COMPILER12_UP`, but `Shared/PascalParser/DelphiParser.inc` is empty and neither the product `.dproj` nor `DDevExtUnitTestsDUnitX.dproj` defines them (the `.dpr`'s `{$I DelphiExtension.inc}` does not reach separately compiled units).  The retired console project defined them at Base level, which hid this: its claim to match the main projects was wrong.  So `THashtable.Create( True, ... )` raises its Delphi-5 assertion and ignores `CaseSensitive`, and `DelphiLexer`'s UTF-8/UTF-16/UCS-4 BOM decoding is compiled out.  Fixed the same day by resolving the conditionals to their modern branches ( see `CHANGELOG.md` ); the test is green. The other Tier 2 candidates turned out to be IDE/VCL-entangled and were moved to Tier 3 (see below).

**Feature-core extraction (`ProjectGroupSorterCore`).** The "Sort Projects in Group" feature (v3.21.9) was authored with its pure `.groupproj` rewrite logic (`SortGroupProjectText`, `LeafName`) split into an RTL-only core unit from the start, leaving `ProjectGroupSorter` with only the menu/IDE orchestration. `TestProjectGroupSorter` (DUnitX, 11 cases) covers it — the first feature whose testable core was separated up front rather than retrofitted. `PathCompactorCore` (v3.22.11) followed the same pattern.

**Retrofitted core extraction (`UsesClauseManagerCore`, v3.22.15).** The first time the seam was cut into an *existing* feature rather than designed in, and the worked precedent for the remaining Tier 3 items below. `TUnitExportsDatabase`, `TIdentifierUsageAnalyzer` and `TUsesClauseRefactorer` moved verbatim into an RTL + `DelphiLexer` unit; `UsesClauseManager` kept the plugin host and re-exports the moved types, so its published interface and every call site were unchanged. The two IDE couplings were dealt with rather than worked around: `BuildFromSearchPath( IOTAProject )` became `BuildFromDirectories( TStrings )` with the ToolsAPI half left behind as a class helper, and `ScanUnit` gained a `ScanSource( UnitName, UnitPath, Source )` sibling so tests need no file on disk. That pair — *let the caller supply what only the IDE knows, and take source as text* — is the whole technique.

The lexer tests also guard two v3.19.9 behaviours directly: bracket tokenisation (`tkLBracket`/`tkRBracket` around an index expression — the magic-number bracket-depth fix) and `Line` 0-based / `Column` 1-based (the analyzer navigation contract).

## Key insight - most value needs no refactor

Everything in `Shared\PascalParser\` is dependency-light (no ToolsAPI/VCL), proven by the DFM and lexer suites compiling standalone. The foundational parser tests are therefore **zero-refactor** - just add a `TestXxxDUnitX.pas` fixture to `DDevExtUnitTests` and wire it into `DDevExtUnitTestsDUnitX.dpr`. The analyzer engines (Tier 3) are the ones that need extraction, because they share a unit with their IOTA plugin class.

## Tier 1 - foundational, zero-refactor (highest leverage)

Everything depends on these; a regression here silently corrupts every analyzer.

- DONE **`DelphiLexer`**.
- DONE **`DelphiExpr`** - literal/binary nodes, int/float coercion, unary minus, float div-by-zero error path, relational + boolean operators, and end-to-end `TExpressionParser.Parse` (precedence).
- DONE **`DelphiPreproc`** - `$IFDEF`/`$IFNDEF`/`$ELSE`/`$ENDIF`, nested blocks, in-source `$DEFINE`/`$UNDEF`, and `Define`/`Undefine` state (driven via the API; no event resolvers needed).
- DONE **`DelphiParserContainers`** - THashtable case-sensitivity + ownership-aware removal, TIntegerList round-trip, TStringDictionary, TStringCollection.

## Tier 2 - pure algorithmic logic, low/medium effort

- DONE **`CompileProgress\UnitMetrics` - `CalculateUnitMetrics`**: LOC + cyclomatic complexity; covered base/branch/case-label complexity and comment-line LOC exclusion (4 cases, via a temp-file fixture). `UnitMetrics` only `uses DelphiLexer`, so no refactor was needed.

The remaining four candidates were **attempted under Option A and found to need extraction** (they could not be console-unit-tested as-is), so they are folded into Tier 3:
- DONE (v3.22.15) **`UsesClauseManager` `GenerateRefactoredSource`/`GetPreferredUnit`** - the extraction that was needed here is done: both now live in `UsesClauseManagerCore` and are covered by `TestUsesClauseManagerCoreDUnitX` (26 cases). See "Retrofitted core extraction" above for the technique.
- PARTLY SUPERSEDED (v3.22.15) **`DependencyViewer` cycle detection** - `DecirculariserCore` now does RTL-only cycle detection, risk classification and per-edge symbol attribution with 21 tests, so the cycle half of this item no longer needs the DependencyViewer extraction. The layer rules and `MatchesWildcard` still do.
- DONE (2026-11-09: `DependencyViewerCore`, `TestDependencyViewerCoreDUnitX`) **`DependencyViewer` layer rules / `MatchesWildcard`** - the unit `uses Main`, and the helpers are private/nested; needs the same core extraction `UsesClauseManagerCore` has now had.
- DROPPED (2026-11-09: `ProjectSettingsData` was deleted with the Project Settings manager, which no project compiled) **`ProjectSettings\ProjectSettingsData` `Compare`/`CopyFrom`** - the unit `uses ToolsAPI` directly (for the `IOTAProject` overloads), so it will not compile in a console test. A `TProjectSetting.Compare`/`CopyFrom` test needs the pure preset model split from the ToolsAPI-coupled overloads. (A trial `AddOption` seam + console test were prototyped and reverted.)
- MOVED→T3 **`CtrlUtils.TListViewSort.Compare`** - `Compare` reads a real `TListItem`, and a `TListView` cannot add items without a parent window (`EInvalidOperation: has no parent window`) in a console runner. Needs the comparison logic extracted to operate on plain strings (e.g. `CompareValues(S1, S2; Kind)`), or a GUI test runner. Guards the v3.18.8 ragged-row fix.

## Tier 3 - analyzer cores (need core extraction first)

These expose pure `class function AnalyzeUnit(const Source...)` cores but share a unit with `ToolsAPI`/VCL/`Main`, so a test that references them drags the IDE in. Extract each pure core into a dependency-light `*Core.pas` (uses only `System.*` + `DelphiLexer`/`DelphiPreproc`), then test like the DFM parser:

- TODO `CodeQualityAnalyzer` -> `CodeQualityCore` - magic numbers incl. **bracket-depth array-index exemption** (v3.19.9), hardcoded strings, commented code, empty/catch-all except, missing try-finally. The unimplemented memory-leak check stays off.
- TODO `EmptyEventHandlerDetector` -> `EmptyHandlerCore` - empty-body detection, `Sender`-parameter requirement, **declaration line from the keyword token** (v3.19.9).
- DONE (2026-11-09, as `UnreachableCodeCore`, 14 cases) `UnreachableCodeDetector` -> `UnreachableCore` - after-`Exit`/`Raise`/`Break`, conditional terminator not flagged, case-branch awareness, triple-quoted strings, **preview truncation flag** (v3.19.9). (Drop its `uses Main`.)
- DONE (2026-11-09, 9 cases) `DfmPasConsistency` -> `DfmPasConsistencyCore` - Missing-in-PAS / Missing-in-DFM / Type-Mismatch (already takes both sources as strings - ideal).
- TODO `CodeStyleChecker` -> `CodeStyleCore` - expose `CheckSource`; formalise the existing throwaway `TestAntiPatterns.pas` fixture (it already documents expected counts) into real assertions.

Also extracted and tested on 2026-11-09, outside this list: `DeadCodeCore` (11), `UnusedUnitCore` (15), `TodoAggregatorCore` (7), `DependencyViewerCore` (13), and the DLL-core seams `PluginConfigCore`, `FeatureSwitches`, `IDEHashLists`, `VersionInfoKeys`, `LibraryPathBackups` and CompileInterceptor's `InterceptDispatch`.

## DRY + test opportunity

`EvaluateIfCondition` (the `$IF` define evaluator) is **duplicated** in `DependencyViewer.pas` and `UnreachableCodeDetector.pas` (since 2026-11-09 in their cores, `DependencyViewerCore.pas` and `UnreachableCodeCore.pas`). Extract to one shared `ConditionalEvaluator.pas` and test once - removes a maintenance hazard and gives high-value coverage in a single place.

## Out of scope (not unit-testable)

`FileStreams` (Win32 handles), `ProjectData`/`ModuleData` (IOTA + IO), `StartParameterClasses` (XML file IO), and all forms / option-pages / IOTA wrappers / IDE-hook installation.

## Suggested sequencing

1. DONE `DelphiLexer`.
2. DONE rest of Tier 1: `DelphiExpr`, `DelphiPreproc`, `DelphiParserContainers`.
3. DONE Tier 2 `UnitMetrics`. The other Tier 2 items proved IDE/VCL-entangled and merged into Tier 3 extraction.
3. Tier 2 low-effort: `GenerateRefactoredSource`, `UnitMetrics`, `ProjectSettingsData.Compare`, `CtrlUtils` ragged-row sort.
4. Extract-then-test: the analyzer cores + the shared `ConditionalEvaluator`.

## How to add a test

1. Create `TestXxxDUnitX.pas` in `DDevExtUnitTests/` with a `[TestFixture]` class, one `[Test]` per behaviour with a `<summary>` saying what it proves, and `TDUnitX.RegisterTestFixture` in `initialization` - mirror `TestDelphiLexerDUnitX.pas`.
2. Add the unit under test (if not already listed) and the test unit to `DDevExtUnitTestsDUnitX.dpr`'s `uses` with the `in '<path>'` form.
3. Build `DDevExtUnitTestsDUnitX.dproj` Release Win64 (Debug defines `TESTINSIGHT`) and run `bin/DDevExtUnitTestsDUnitX.exe --exitbehavior:Continue`.  The runner sets `Assert.IgnoreCaseDefault := False`, so string comparisons are case-sensitive.

> Note: `TestDfmParserDUnitX` resolves `TestData` from the working directory or, failing that, `../DDevExtUnitTests/TestData` relative to the exe, so the file fixtures run from `bin` too (before 2026-10-21 they passed there by skipping).
