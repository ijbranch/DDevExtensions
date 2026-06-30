# Unit-Test Coverage Plan

Living plan for extending automated, IDE-free unit tests across DDevExtensions. Tests live in `DDevExtUnitTests\` (renamed from `DfmParserTests`) and run as a console runner (`DDevExtUnitTests.dpr`, self-contained PASS/FAIL) plus a DUnitX variant (`DDevExtUnitTestsDUnitX.dpr`). Supersedes the earlier analyzer-only scoping note.

## Current coverage

| Suite | Unit under test | Tests | Status |
|-------|-----------------|-------|--------|
| `TestDfmParser` | `gllDelphiDFMParser` (parse/serialize round-trip) | 31 (20 in-memory + 11 file) | green |
| `TestDelphiLexer` | `DelphiLexer` (tokenisation + line/column contract) | 24 / 9 cases | green |
| `TestDelphiParserContainers` | `DelphiParserContainers` (hashtable/list/dictionary) | 24 / 5 cases | green |
| `TestDelphiExpr` | `DelphiExpr` (arithmetic/boolean nodes + parser) | 21 / 6 cases | green |
| `TestDelphiPreproc` | `DelphiPreproc` ($IFDEF/$IFNDEF/$ELSE/nested/$DEFINE) | 10 / 4 cases | green |
| `TestUnitMetrics` | `UnitMetrics` (LOC + cyclomatic complexity) | 4 / 4 cases | green |
| `TestProjectGroupSorter` (DUnitX) | `ProjectGroupSorterCore` (`.groupproj` sort: ItemGroup + Targets + CallTargets) | 11 cases | green |

**Tier 1 complete; Tier 2 = `UnitMetrics` only (114 assertions total).** The test project declares the same `COMPILERx_UP` (Delphi 10.2+) symbols as the main projects via a Base-config `DCC_Define`, so the Shared units compile their modern paths. The other Tier 2 candidates turned out to be IDE/VCL-entangled and were moved to Tier 3 (see below).

**Feature-core extraction (`ProjectGroupSorterCore`).** The "Sort Projects in Group" feature (v3.21.9) was authored with its pure `.groupproj` rewrite logic (`SortGroupProjectText`, `LeafName`) split into an RTL-only core unit from the start, leaving `ProjectGroupSorter` with only the menu/IDE orchestration. `TestProjectGroupSorter` (DUnitX, 11 cases) covers it — the first feature whose testable core was separated up front rather than retrofitted, the same seam the parked Tier 3 analyzer extractions still need.

The lexer tests also guard two v3.19.9 behaviours directly: bracket tokenisation (`tkLBracket`/`tkRBracket` around an index expression — the magic-number bracket-depth fix) and `Line` 0-based / `Column` 1-based (the analyzer navigation contract).

## Key insight - most value needs no refactor

Everything in `Shared\PascalParser\` is dependency-light (no ToolsAPI/VCL), proven by the DFM and lexer suites compiling standalone. The foundational parser tests are therefore **zero-refactor** - just add a `TestXxx.pas` to `DDevExtUnitTests` and wire it into the `.dpr`. The analyzer engines (Tier 3) are the ones that need extraction, because they share a unit with their IOTA plugin class.

## Tier 1 - foundational, zero-refactor (highest leverage)

Everything depends on these; a regression here silently corrupts every analyzer.

- DONE **`DelphiLexer`**.
- DONE **`DelphiExpr`** - literal/binary nodes, int/float coercion, unary minus, float div-by-zero error path, relational + boolean operators, and end-to-end `TExpressionParser.Parse` (precedence).
- DONE **`DelphiPreproc`** - `$IFDEF`/`$IFNDEF`/`$ELSE`/`$ENDIF`, nested blocks, in-source `$DEFINE`/`$UNDEF`, and `Define`/`Undefine` state (driven via the API; no event resolvers needed).
- DONE **`DelphiParserContainers`** - THashtable case-sensitivity + ownership-aware removal, TIntegerList round-trip, TStringDictionary, TStringCollection.

## Tier 2 - pure algorithmic logic, low/medium effort

- DONE **`CompileProgress\UnitMetrics` - `CalculateUnitMetrics`**: LOC + cyclomatic complexity; covered base/branch/case-label complexity and comment-line LOC exclusion (4 cases, via a temp-file fixture). `UnitMetrics` only `uses DelphiLexer`, so no refactor was needed.

The remaining four candidates were **attempted under Option A and found to need extraction** (they could not be console-unit-tested as-is), so they are folded into Tier 3:
- MOVED→T3 **`UsesClauseManager` `GenerateRefactoredSource`/`GetPreferredUnit`** - the unit `uses Main` + `FrmTreePages`; needs core extraction.
- MOVED→T3 **`DependencyViewer` cycle detection / `MatchesWildcard`** - same `uses Main`; helpers are private/nested.
- MOVED→T3 **`ProjectSettings\ProjectSettingsData` `Compare`/`CopyFrom`** - the unit `uses ToolsAPI` directly (for the `IOTAProject` overloads), so it will not compile in a console test. A `TProjectSetting.Compare`/`CopyFrom` test needs the pure preset model split from the ToolsAPI-coupled overloads. (A trial `AddOption` seam + console test were prototyped and reverted.)
- MOVED→T3 **`CtrlUtils.TListViewSort.Compare`** - `Compare` reads a real `TListItem`, and a `TListView` cannot add items without a parent window (`EInvalidOperation: has no parent window`) in a console runner. Needs the comparison logic extracted to operate on plain strings (e.g. `CompareValues(S1, S2; Kind)`), or a GUI test runner. Guards the v3.18.8 ragged-row fix.

## Tier 3 - analyzer cores (need core extraction first)

These expose pure `class function AnalyzeUnit(const Source...)` cores but share a unit with `ToolsAPI`/VCL/`Main`, so a test that references them drags the IDE in. Extract each pure core into a dependency-light `*Core.pas` (uses only `System.*` + `DelphiLexer`/`DelphiPreproc`), then test like the DFM parser:

- TODO `CodeQualityAnalyzer` -> `CodeQualityCore` - magic numbers incl. **bracket-depth array-index exemption** (v3.19.9), hardcoded strings, commented code, empty/catch-all except, missing try-finally. The unimplemented memory-leak check stays off.
- TODO `EmptyEventHandlerDetector` -> `EmptyHandlerCore` - empty-body detection, `Sender`-parameter requirement, **declaration line from the keyword token** (v3.19.9).
- TODO `UnreachableCodeDetector` -> `UnreachableCore` - after-`Exit`/`Raise`/`Break`, conditional terminator not flagged, case-branch awareness, triple-quoted strings, **preview truncation flag** (v3.19.9). (Drop its `uses Main`.)
- TODO `DfmPasConsistency` -> `DfmPasConsistencyCore` - Missing-in-PAS / Missing-in-DFM / Type-Mismatch (already takes both sources as strings - ideal).
- TODO `CodeStyleChecker` -> `CodeStyleCore` - expose `CheckSource`; formalise the existing throwaway `TestAntiPatterns.pas` fixture (it already documents expected counts) into real assertions.

## DRY + test opportunity

`EvaluateIfCondition` (the `$IF` define evaluator) is **duplicated** in `DependencyViewer.pas` and `UnreachableCodeDetector.pas`. Extract to one shared `ConditionalEvaluator.pas` and test once - removes a maintenance hazard and gives high-value coverage in a single place.

## Out of scope (not unit-testable)

`FileWatcher` (threads + `ReadDirectoryChangesW`), `Hooking`/`ImportHooking` (machine-code patching), `FileStreams` (Win32 handles), `SimpleXmlDoc` load/save (file IO), `ProjectData`/`ModuleData` (IOTA + IO), `StartParameterClasses` (XML file IO), and all forms / option-pages / IOTA wrappers / IDE-hook installation.

## Suggested sequencing

1. DONE `DelphiLexer`.
2. DONE rest of Tier 1: `DelphiExpr`, `DelphiPreproc`, `DelphiParserContainers`.
3. DONE Tier 2 `UnitMetrics`. The other Tier 2 items proved IDE/VCL-entangled and merged into Tier 3 extraction.
3. Tier 2 low-effort: `GenerateRefactoredSource`, `UnitMetrics`, `ProjectSettingsData.Compare`, `CtrlUtils` ragged-row sort.
4. Extract-then-test: the analyzer cores + the shared `ConditionalEvaluator`.

## How to add a test

1. Create `TestXxx.pas` in `DDevExtUnitTests\` with a `RunXxxTests` procedure, a local `Assert(Cond, Msg)` (raise on fail), and `WriteLn` PASS lines + a summary - mirror `TestDelphiLexer.pas`.
2. Add the unit-under-test and the test unit to `DDevExtUnitTests.dpr`'s `uses` (with the `in '..\path'` form) and call `RunXxxTests` from the `begin` block.
3. Build (`DDevExtUnitTests.dproj`, Win64/Win32 Release) and run the exe **from the `DDevExtUnitTests` folder** so any `TestData` file fixtures resolve.
4. Optionally add a matching DUnitX test class to `DDevExtUnitTestsDUnitX.dpr` for the framework-based suite.

> Note: run the console runner from its own directory - it locates `TestData` relative to the working directory, so launching from `\bin` skips file-based fixtures.
