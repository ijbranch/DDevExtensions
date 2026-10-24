# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

> The change record of the `DDevExtUnitTestsDUnitX` test suite (`DDevExtUnitTests`).  Kept beside the suite since
> 2026-10-25 (Ian: "every test suite should have its own change log"); test-only entries recorded before that in the
> repository's `CHANGELOG.md` were moved here the same day.  Product changes, including those that change a product
> unit together with its tests, stay in the repository's `CHANGELOG.md`.

## [Unreleased]

### Added

- (2026-10-25) **This change log** — `CHANGELOG.md`.  The suite's own record, per the estate rule that every test
  suite has one; test-only history moved in from `..\CHANGELOG.md` ( 9 entries ).

## [3.23.15] - 2026-10-21

### Added

- (2026-10-21) **24 unit tests for the separator scan, colour rules and paint throttle.** -
  `DDevExtUnitTests/TestMethodSeparatorsCoreDUnitX.pas` (new), `DDevExtUnitTests/DDevExtUnitTestsDUnitX.dpr`
  Mutation-proved: disabling the comment climb, the generic `record`-constraint check, the `{$ELSE}`
  alternative-header merge and the throttle's boundary each turned exactly the test written for it red.
- (2026-10-19) **22 tests, 138 in the suite; mutation-proved.** - `DDevExtUnitTests/TestDecirculariserCoreDUnitX.pas`,
  `DDevExtUnitTests/README.md`
  Start-up-code detection, `CanAutoRemove`, 13 `RemoveUsesEntry` cases asserting the exact resulting text,
  dotted names and 1-based lines.  Six mutants, one per safety rule (start-up code ignored, the
  `TA = class` / `constructor` false positive, the emptied line left behind, 0-based lines, last-part-only
  name resolution, a swallowed comment), each failed at least one test; the source was restored
  byte-for-byte.

### Changed

- (2026-10-21) **The hand-rolled console suite is now five DUnitX fixtures, and its runner is gone.**  Every check
  in `TestDelphiLexer`, `TestDelphiParserContainers`, `TestDelphiExpr`, `TestDelphiPreproc` and
  `TestUnitMetrics` is a DUnitX assertion that can fail (9, 5, 5, 4 and 4 tests), each fixture
  mutation-proved against its product unit.  `TestDfmParser`'s two checks the DUnitX DFM fixture
  lacked became `TestPropertyEditsReachSerialisedOutput` and `TestFileRoundTrip_EveryTestDataFile`.
  The suite is 191 tests.  - `DDevExtUnitTests/TestDelphiLexerDUnitX.pas`,
  `TestDelphiParserContainersDUnitX.pas`, `TestDelphiExprDUnitX.pas`, `TestDelphiPreprocDUnitX.pas`,
  `TestUnitMetricsDUnitX.pas`, `TestDfmParserDUnitX.pas`, `DDevExtUnitTestsDUnitX.dpr`
- (2026-10-21) **The DFM file round-trip tests passed from `bin` without running.**  They opened a bare relative
  `TestData\` path and `Assert.Pass`ed when it was missing, and the runner is built into `bin`, where it
  is missing.  `TestDataDir` now falls back to `..\DDevExtUnitTests\TestData` beside the exe; a
  serialiser mutation now fails all 12 file tests.  - `DDevExtUnitTests/TestDfmParserDUnitX.pas`

## [3.22.15] - 2026-09-17

### Added

- (2026-09-17) **The DUnitX suite can now run headless, and does.** `DDevExtUnitTestsDUnitX.dpr` hardcoded
  `{$DEFINE TESTINSIGHT}` on line 1 and otherwise built a VCL GUI runner, so there was no way to run
  the tests without the IDE and no exit code for a build server to read. The define is now taken from
  the `.dproj` per configuration, and the `.dpr` selects between three runners:

  | Define | Runner |
  |---|---|
  | `TESTINSIGHT` (Debug config) | TestInsight host - use this while writing tests |
  | `GUI_TEST_RUNNER` | the DUnitX VCL GUI runner, opt-in |
  | neither (Release) | console runner, NUnit XML report, meaningful exit code |

  `TESTINSIGHT` had actually been defined **three** times over - in the `.dpr` and in both the Debug
  and Release `DCC_Define` lists - which is why removing it from one place had no effect. Release now
  carries `RELEASE` only, and `{$MESSAGE FATAL}` catches an attempt to define two runners at once.

  First full headless run: **94 tests found, 94 passed, exit code 0** - DFM parser 32, PathCompactor
  25, ProjectGroupSorter 11, UsesClauseManagerCore 26.

  — `DDevExtUnitTests/DDevExtUnitTestsDUnitX.dpr`, `DDevExtUnitTests/DDevExtUnitTestsDUnitX.dproj`
- (2026-09-17) **`Assert.IgnoreCaseDefault := False` in the runner mainline.** Our `gllDUnitX` fork defaults a
  two-argument string comparison to ignore case, and nothing at the call site reveals it - so a test
  whose subject *is* the casing cannot fail. Checked rather than assumed before adopting it: all 94
  tests still pass with it set, so the weak default was costing this suite nothing today. It is set
  now so that a future test cannot inherit it.

  — `DDevExtUnitTests/DDevExtUnitTestsDUnitX.dpr`
- (2026-09-17) **26 DUnitX tests for `UsesClauseManagerCore`** - the first tests this feature has ever had. They
  cover the exports database (export kinds, interface-only scope, case-insensitive lookup, the reverse
  lookup, RTL/VCL priority tie-breaking, `Clear`), the usage analyser (both uses clauses, interface vs
  implementation identifiers, qualified references) and the refactorer (all four placement outcomes,
  and that the rewritten source really does relocate the unit).

  Mutation-proved rather than assumed: inverting the "only used in implementation" recommendation in
  the core turns exactly two tests red, each on its own assertion.

  — `DDevExtUnitTests/TestUsesClauseManagerCoreDUnitX.pas` (new),
  `DDevExtUnitTests/DDevExtUnitTestsDUnitX.dpr`

## [3.22.11] - 2026-08-31

### Added

- (2026-08-31) **DUnitX fixture `TTestPathCompactor` (25 tests) covering the compactor core.** Includes the regression
  test for the stored-space scoring defect, the platform/config-token naming guard, the core-level refusal
  of `lptNamespacePrefixes`, and two invariants asserted on every fixture: stored length never increases,
  and analyse-rewrite-expand reproduces the original expanded path set minus intentional drops. Wired into
  `DDevExtUnitTestsDUnitX.dpr`; 18/18 green via a standalone `dcc64` console runner. -
  `DDevExtUnitTests/TestPathCompactorDUnitX.pas`, `DDevExtUnitTests/DDevExtUnitTestsDUnitX.dpr`

## [3.21.10] - 2026-07-13

### Added

- (2026-06-30) **DUnitX fixture `TTestProjectGroupSorter` (11 tests) covering the project-group sorter.** Verifies that an unsorted group becomes exactly the canonical sorted form across all three sections, that sorting is idempotent (drives the no-op path), case-insensitive (including the real-world "Scrap / SCtoXX / Store" ordering that bit the manual edit), that per-project `<Dependencies>` and the header/`ProjectExtensions`/`Import` boilerplate survive verbatim, that a group with no `<Target>` section reorders the `<ItemGroup>` without inventing targets, plus CRLF endings, single-project no-op and `LeafName`. Wired into `DDevExtUnitTestsDUnitX.dpr`; links clean in the suite and runtime-verified green (9 logic checks via a standalone `dcc64` console harness, exit 0). — `DDevExtUnitTests/TestProjectGroupSorterDUnitX.pas`, `DDevExtUnitTests/DDevExtUnitTestsDUnitX.dpr`
