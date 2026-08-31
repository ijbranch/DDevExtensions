# Changelog - DDevExtensions Project History

This file is the sole source and record of all project changes for DDevExtensions.

---

## 2026-08-31 - v3.22.11 - IDE Path Compactor

### Added

- **New Tools > IDE Path Compactor dialog that shortens the IDE's library path strings.** Analyses every
  selected platform x path-type, proposes `$(NAME)` macro substitutions for repeated directory prefixes,
  offers directory junctions for over-long third-party prefixes, and reports duplicate, dead and
  undefined-macro entries. Reports stored *and* expanded lengths before/after, because only the expanded
  length constrains the compiler command line while only the stored length triggers the IDE's "path too
  long" warning - macros shorten the first, junctions the second. Backup and rollback reuse the existing
  `TLibraryPathBackupManager` history, so one Restore list covers the Sorter and the Compactor alike.
  Nothing is written until Apply. (2026-08-31) - `Source/PathCompactor/PathCompactorCore.pas`,
  `Source/PathCompactor/PathCompactor.pas`, `Source/PathCompactor/PathCompactorEnvVars.pas`,
  `Source/PathCompactor/PathCompactorJunctions.pas`, `Source/PathCompactor/FrmPathCompactor.pas`,
  `Source/PathCompactor/FrmPathCompactor.dfm`, `Source/RegisterPlugins.pas`,
  `Source/DelphiExtension.inc`, `D_D102`...`D_D130/DDevExtensions.dpr`

- **Saving is scored in STORED space, not expanded space.** Candidates must be generated from expanded
  ancestors so a prefix can be matched across entries written in different forms, but the gain is measured
  against the raw registry text each entry actually holds. **Why:** measured on the development machine,
  `C:\Program Files (x86)\Embarcadero\Studio\37.0` is an ancestor of 104 of 363 entries and an
  expanded-space score ranks it first at about 3,640 characters saved - yet all 104 are already stored as
  `$(BDS)\...`, so accepting it would rewrite `$(BDS)\source\rtl` (24 stored characters) into
  `$(STUDIO37)\source\rtl` (29), lengthening every one while reporting a four-figure win. Where a
  candidate equals an existing macro's value the existing name is reused rather than a redundant one
  invented. (2026-08-31) - `Source/PathCompactor/PathCompactorCore.pas`

- **Variables are written to BOTH IDE macro-override keys.** RAD Studio reads `Environment Variables` in the
  32-bit IDE and `Environment Variables x64` in the 64-bit IDE, but the `Library\<Platform>` keys those
  macros resolve are shared between them and are not split. **Why:** defining a variable in one list only
  makes every shared path entry using it resolve in one IDE and break silently in the other.
  `GetBaseRegistryKey` returns the same value in both, so the naive `BaseRegistryKey + '\Environment
  Variables'` names the 32-bit list even from the 64-bit IDE. Divergences already present are reported, not
  silently inherited. (2026-08-31) - `Source/PathCompactor/PathCompactorEnvVars.pas`

- **DUnitX fixture `TTestPathCompactor` (24 tests) covering the compactor core.** Includes the regression
  test for the stored-space scoring defect, the platform/config-token naming guard, the core-level refusal
  of `lptNamespacePrefixes`, and two invariants asserted on every fixture: stored length never increases,
  and analyse-rewrite-expand reproduces the original expanded path set minus intentional drops. Wired into
  `DDevExtUnitTestsDUnitX.dpr`; 18/18 green via a standalone `dcc64` console runner. (2026-08-31) -
  `DDevExtUnitTests/TestPathCompactorDUnitX.pas`, `DDevExtUnitTests/DDevExtUnitTestsDUnitX.dpr`

- **Cleanup can now remove dead macro references, and every intended removal is re-verified before it
  happens.** Three removals are offered, each opt-in and unticked by default: duplicate entries, entries
  whose directory is missing, and entries whose macro resolves nowhere. Immediately before writing, the
  Compactor re-tests every entry it is about to delete - re-probing the file system and re-resolving the
  macro - and keeps any that now passes, reporting how many were rescued. **Why:** an analysis may be
  minutes old by the time Apply runs; a disconnected share can reconnect or an installer finish in between,
  and nothing should be deleted on the strength of a stale probe. It then lists every entry it is about to
  remove, with the reason, and asks for confirmation. (2026-08-31) -
  `Source/PathCompactor/PathCompactorCore.pas`, `Source/PathCompactor/FrmPathCompactor.pas`,
  `Source/PathCompactor/FrmPathCompactor.dfm`

- **A macro that this IDE cannot resolve but the other IDE bitness can is reported as *divergent*, never as
  dead, and is never removed.** **Why:** the two IDE variable lists have diverged on the development
  machine, so `$(DUNITX)`, `$(DELPHIMOCKS)` and `$(GOOGLEMAPSDIR)` resolve in the 32-bit IDE but not the
  64-bit one. Treating those as dead and deleting them from the shared library path would silently break
  the IDE where they still work; the correct repair is to define the variable in both lists. The dialog
  counts the two classes separately. (2026-08-31) - `Source/PathCompactor/PathCompactorCore.pas`,
  `Source/PathCompactor/FrmPathCompactor.pas`

### Changed

- **`TLibraryPathType` and its record helper moved to the RTL-only `PathCompactorCore`,** with
  `LibraryPathSorter` aliasing both. **Why:** the compactor's testable core must not pull in ToolsAPI, and a
  second helper declared for the same type would not merge with the first - it would silently shadow it.
  Note that a type alias re-exports neither the enumeration's members nor the helper, so
  `FrmLibraryPathSorter` now uses `PathCompactorCore` directly. (2026-08-31) -
  `Source/LibraryPathSorter/LibraryPathSorter.pas`, `Source/LibraryPathSorter/FrmLibraryPathSorter.pas`

- **Junction detection refuses the IDE's own installation tree, the Windows directory and the Program Files
  roots.** **Why:** the brief assumed the prime target would be the GetIt `CatalogRepository`, but measured
  on the development machine that prefix appears zero times, and the highest-scoring junction candidate is
  `...\Embarcadero\Studio\37.0` itself at 104 uses. Junctioning it would relocate RAD Studio behind the
  back of GetIt, the installer and every repair operation. Third-party trees under Program Files are still
  offered. (2026-08-31) - `Source/PathCompactor/PathCompactorJunctions.pas`

- **Duplicate removal is opt-in; duplicate detection is always on.** **Why:** a survey of the whole Library
  key - 13 platforms, 96 populated path sets, 917 entries - found zero duplicates by either a raw or an
  expanded-and-normalised test, so defaulting a destructive mutation on would take a risk against a problem
  that does not occur. Detection is nearly free once the analysis exists and is strictly stronger than the
  Sorter's own raw `SameText` check, which cannot see `$(BDS)\source` and the equivalent literal as one
  directory. (2026-08-31) - `Source/PathCompactor/PathCompactorCore.pas`

- **`$(LangDir)` is treated as a build-time macro, like `$(Config)`.** **Why:** it resolves per translation
  language and appears only in the three Translated* path types; without this, 30 entries on the development
  machine would be reported as dead macro references. (2026-08-31) -
  `Source/PathCompactor/PathCompactorCore.pas`

- Version bumped 3.21.10 -> 3.22.11 across all indicators: `Source/version.inc`, `version.h`, all six
  `D_Dxxx/DDevExtensions.dproj` and `Installer/DDevExtensionsReg.dproj` (`VerInfo_MinorVer` 21->22,
  `VerInfo_Release` 10->11, `FileVersion` -> `3.22.11.*`, `ProductVersion` -> 3.22), **and
  `Version.res` regenerated from `Version.rc`**. **Why:** the DLL takes its version resource from
  `{$R ..\Version.res}`, a committed binary built from `version.h` - editing `version.h` alone
  leaves the shipped DLL still reporting the previous version, which is what it did until the resource was
  rebuilt (`brcc32 Version.rc -foVersion.res`; `cgrc` cannot be used from `bin` because its `resinator.exe`
  helper lives in `bin64`). Verified: the built DLL now reports 3.22.11. (2026-08-31) -
  `Source/version.inc`, `version.h`, `Version.res`, `D_D102`...`D_D130/DDevExtensions.dproj`,
  `Installer/DDevExtensionsReg.dproj`

- **Build numbers now auto-increment.** `VerInfo_AutoIncVersion` was absent from every project, so the
  build number only ever moved when someone edited it by hand - which is why D_D102-D_D120 and the
  installer had all been sitting at build 575 while D_D130 had reached 795: the number recorded who had
  been edited, not what had been built. **Note the property name** - it is `VerInfo_AutoIncVersion`, not
  `VerInfo_AutoIncBuild`; MSBuild's `AutoIncBuildNumber` target (in `CodeGear.Common.Targets`, wired into
  `BuildDependsOn`) tests only the former, so the plausible-looking wrong name is silently inert. Verified
  incrementing on successive command-line Win64 builds. Two side effects worth knowing: the task rewrites
  the `.dproj` on every successful build (re-indenting it, so expect whitespace churn in diffs), and it
  creates a per-configuration version block the first time a configuration is built. (2026-08-31) -
  `D_D102`...`D_D130/DDevExtensions.dproj`, `Installer/DDevExtensionsReg.dproj`

### Fixed

- **`OldPalette` resource/object/include search-path entries had never resolved.** All six IDE projects
  carried the bare relative path `OldPalette` in `DCC_ResourcePath`, `DCC_ObjPath` and `DCC_IncludePath`,
  which resolves against the `.dproj`'s own folder - `D_Dxxx\OldPalette` - and no such directory has
  ever existed; the real one is `..\Source\OldPalette`. Every build emitted
  `H2675 Directory not found: OldPalette`. Corrected in all six projects (6 entries each). (2026-08-31) -
  `D_D102`...`D_D130/DDevExtensions.dproj`

- **The junction exclusion tested only one direction, and offered the IDE's own installation tree.**
  `IsJunctionCandidate` refused anything *under* `$(BDS)` but nothing *above* it, so
  `...\Embarcadero\Studio` - the parent of `...\Studio\37.0` - sailed through, and on the development
  machine it was the **top-ranked candidate at 458 uses**. Accepting it would have junctioned every
  installed version of RAD Studio at once and rewritten 458 entries to point through the link.
  `...\Embarcadero` escaped too, and only by accident: at 34 characters it fell below the 40-character
  floor. The exclusion now tests both directions, for the IDE root and for the Windows directory.
  **Why it went unnoticed:** the guard was written and verified against the case it was designed for
  - a directory *inside* the IDE tree - and the symmetric case was never considered. Covered by a
  mutation-checked test. Never fired in practice; no junction was ever created. (2026-08-31) -
  `Source/PathCompactor/PathCompactorJunctions.pas`

- **Junction offers were nested, cryptically named and not editable.** The parent `EurekaLog 7` was
  offered alongside its `Source`, `Lib` and `Packages` children, inviting four links where one will
  do; link paths were two letters taken from the leaf, so `Source` and `Studio` both proposed
  `C:\SO` / `C:\ST` - a keystroke apart, and two sources sharing an initial pair would have collided
  on the same link. Overlapping offers are now collapsed to whichever saves more, link names use a
  longer stem made unique against the other offers and against existing directories, and the Link
  column can be edited by double-clicking it, as the brief always specified. (2026-08-31) -
  `Source/PathCompactor/FrmPathCompactor.pas`, `Source/PathCompactor/FrmPathCompactor.dfm`

- **Apply now warns when junction opportunities exist but none is selected.** The junction list lives
  on its own tab, so it is easy to apply without ever looking at it - which is exactly what happened
  in practice. The prompt names how many offers there are and roughly how many expanded characters
  they would save, and switching to that tab is one click from declining. **Why it matters:** a
  junction is the only measure that shortens the expanded path, the one that constrains the compiler
  command line; macro substitution cannot help there at all. (2026-08-31) -
  `Source/PathCompactor/FrmPathCompactor.pas`

- **A bare version folder became a meaningless variable name, and identical path tails collided into
  `_2`.** `...\Delphi 13 Florence\37.0` yielded `$(V37_0)` - the sanitiser prefixing `V` because the name
  could not start with a digit - and a second library ending in the same `...\Florence\37.0` tail took
  `$(V37_0_2)`, which says nothing about which library it is. Version-like segments (digits and separators
  only) now trigger the same widening as platform and config tokens, and a name collision is resolved by
  folding in another parent segment before any numeric suffix is considered. Measured on the development
  machine, the next pass now proposes `$(TMS_VCL_UIPACK)`, `$(RBUILDER_LIB)` and `$(EUREKALOG_7_SOURCE)`
  where it previously offered `$(LIB)`, `$(LIB_2)` and `$(SOURCE_3)`. Widened names may run to 28
  characters rather than 16, since a meaningful long name beats a short meaningless one. (2026-08-31) -
  `Source/PathCompactor/PathCompactorCore.pas`

- **The dialog left pre-Apply figures on screen after a successful Apply.** The grid still showed the
  before/after of a change that had already been made, while Apply greyed itself out - which reads as a
  fault rather than a completed action. Apply now re-runs the analysis against the registry as it then
  stands, and says so. (2026-08-31) - `Source/PathCompactor/FrmPathCompactor.pas`

- **Entries queued for removal were still voting for macro variables.** `Analyse` ran hygiene *after*
  candidate generation and selection, so an entry about to be deleted still counted toward a prefix's
  occurrence tally and its saving. **Why it matters:** a variable could be defined whose every user then
  disappeared - leaving an orphan in both IDE variable lists - and the reported saving counted characters
  that were never going to be written. Hygiene now runs before candidate generation, and dropped entries
  are excluded from the tally, from match records, from incremental scoring and from rewriting. Covered by
  a test that fails if the ordering is put back. (2026-08-31) -
  `Source/PathCompactor/PathCompactorCore.pas`

- **The most-used prefix was being given the suffixed variable name.** Names were assigned while candidates
  were generated, in dictionary order, so on the development machine the 499-use prefix became
  `$(SOURCE_4)` while a 50-use one took `$(SOURCE)`. Names are now assigned at acceptance, in descending
  order of value. Fixing that exposed a second defect: `UniqueVariableName` compared each candidate against
  *every* candidate's provisional name - including its own - so every accepted variable picked up a
  needless `_2`. It now compares only against already-accepted variables. (2026-08-31) -
  `Source/PathCompactor/PathCompactorCore.pas`

- **The dialog's hint label rendered as mojibake** (`Sorter's backup history a<euro>" this tool...`). The
  `.dfm` carried a raw UTF-8 em-dash, and DFMs have no BOM, so it was read as ANSI. Escaped as `#8212`;
  the file is now pure ASCII. **Why it matters generally:** text DFMs in this repo must stay ASCII-safe -
  non-ASCII belongs in `#nnnn` escapes. (2026-08-31) - `Source/PathCompactor/FrmPathCompactor.dfm`

- **`H2077 Value assigned to 'Failed' never used`** in the Compactor's Apply handler - the junction-failure
  counter was incremented but never read, each failure already reporting itself in its own dialog. Removed.
  (2026-08-31) - `Source/PathCompactor/FrmPathCompactor.pas`

### Known

- `IDEUtils.ExpandDirMacros` reads neither IDE `Environment Variables` override key and lacks
  `BDSCATALOGREPOSITORY`/`BDSCOMMONDIR`/`BDSUSERDIR`; worse, it *deletes* a macro it cannot resolve instead
  of leaving it intact. The compactor therefore carries its own expander. Consequence for the existing
  Sorter: a `$(BDSCatalogRepository)` entry expands to a bare `\...` remainder, fails `DirectoryExists` and
  is wrongly flagged **invalid** - the `IsPathValid` "unexpanded macro, treat as valid" branch is
  unreachable for it. Tracked separately.

- **Resolved on first live use (2026-08-31):** the IDE does **not** rewrite the Library key on shutdown.
  A compaction was applied, the IDE closed and reopened, and the rewritten paths and both variable lists
  survived intact; project builds succeeded against them. No deferred applier is needed. First live run
  over 25 path sets: 31,428 -> 22,413 stored characters (28.7%), 952 -> 873 entries (the 79 removed being
  exactly the missing-directory references), 12 variables created in both IDE lists, none orphaned, none
  modified, and nothing written to the Windows user environment.

- ~~Whether the IDE rewrites the Library key on shutdown is still unestablished.~~ Answered above. The
  Compactor writes directly, as the Sorter already does, and still refuses to Apply while the IDE's own
  Options dialog is open - that page holds its own copy of the path and would commit it over any change.

- The two IDE user-variable lists have already diverged on the development machine: `$(DUNITX)`,
  `$(DELPHIMOCKS)` and `$(GOOGLEMAPSDIR)` exist only in the 32-bit list, so four shared library-path entries
  do not resolve in the 64-bit IDE. The Compactor reports these; it does not repair them automatically.

---

## 2026-07-13 - v3.21.10 - Fix 64-bit IDE editor AV / dead keyboard in Keybindings next-binding probe

### Fixed

- **Keybindings crashed the 64-bit IDE while editing (`Access violation in coreide370.bpl` at `Kbclient.TKeyboardServices.FillBindingRec`, read of a sign-extended 32-bit address) and left the keyboard unresponsive.** `DoKeyBinding`'s unhandled-key path probed for a follow-on binding via `Context.GetKeyBindingRec` + `KeyboardServices.GetNextBindingRec`, but that legacy ToolsAPI round-trips an x64 binding-list pointer through the 32-bit `TKeyBindingRec.Next: Integer` field — in the 64-bit IDE the truncated/sign-extended pointer AVs inside `Kbclient.FillBindingRec`, and the exception unwinding out of `ProcessKeyStroke` wedged all subsequent keystroke processing until IDE restart. Common keys hit the path constantly (plain `Home` mid-line, `Tab` with no block selected). The probe is now gated `{$IFNDEF CPUX64}` (matching the existing Move-Line/Block Win64 gate): on Win64 unhandled keys always use the built-in HOME/TAB fallback instead of `krNextProc`, so another plugin partially bound to the same key is no longer chained on Win64 — a deliberate trade against IDE crashes. Underlying `Kbclient` defect is the 64-bit IDE's — reported to Embarcadero (2026-07-13). (2026-07-13) — `Source/Keybindings/FrmeOptionPageKeybindings.pas`

### Changed

- Version bumped 3.21.9 → 3.21.10 across ALL indicators, including the lagging ones: `Source/version.inc`, `version.h` (was stale at 3.19.9), all six `D_Dxxx/DDevExtensions.dproj` and `Installer/DDevExtensionsReg.dproj` (D_D102–D_D120 and the installer were stale at 3.19.9 — `VerInfo_MinorVer` 19→21, `FileVersion` → `3.21.10.*`, `ProductVersion` → 3.21; build numbers preserved). (2026-07-13)

---

## 2026-06-30 - Unit tests for "Sort Projects in Group" (+ testable core extraction)

### Added

- **DUnitX fixture `TTestProjectGroupSorter` (11 tests) covering the project-group sorter.** Verifies that an unsorted group becomes exactly the canonical sorted form across all three sections, that sorting is idempotent (drives the no-op path), case-insensitive (including the real-world "Scrap / SCtoXX / Store" ordering that bit the manual edit), that per-project `<Dependencies>` and the header/`ProjectExtensions`/`Import` boilerplate survive verbatim, that a group with no `<Target>` section reorders the `<ItemGroup>` without inventing targets, plus CRLF endings, single-project no-op and `LeafName`. Wired into `DDevExtUnitTestsDUnitX.dpr`; links clean in the suite and runtime-verified green (9 logic checks via a standalone `dcc64` console harness, exit 0). (2026-06-30) — `DDevExtUnitTests/TestProjectGroupSorterDUnitX.pas`, `DDevExtUnitTests/DDevExtUnitTestsDUnitX.dpr`

### Changed

- **Extracted the pure `.groupproj` rewrite logic into a new RTL-only unit `ProjectGroupSorterCore` (`SortGroupProjectText`, `LeafName`).** Behaviour-preserving split so the transform is unit-testable by a standalone executable without pulling in ToolsAPI/VCL. `ProjectGroupSorter` now `uses ProjectGroupSorterCore` and keeps only the menu item and IDE orchestration; the core is registered in all six D_D1xx DPRs. Also cleared a dcc64 H2077 hint (removed a dead `TargetIndent` default). Builds clean Win32 + Win64 (D130). (2026-06-30) — `Source/ProjectGroupSorter/ProjectGroupSorterCore.pas`, `Source/ProjectGroupSorter/ProjectGroupSorter.pas`, `D_D102/`…`D_D130/DDevExtensions.dpr`

---

## 2026-06-30 - v3.21.9 - Add "Sort Projects in Group"

### Added

- **New "Sort Projects in Group" Tools-menu command (`ProjectGroupSorter`).** Alphabetises the member projects of the **currently open project group** so they list in name order in the Project Manager. It saves the group, rewrites the `.groupproj` on disk with the projects sorted, then closes and reopens the group so the IDE reloads the new order; the previously active project is reselected and a `.bak` of the group file is written first. A confirmation prompt warns that the group will be reloaded, and it no-ops with a message when the projects are already sorted or the group has fewer than two members. (2026-06-30) — `Source/ProjectGroupSorter/ProjectGroupSorter.pas`, `Source/RegisterPlugins.pas`, `Source/DelphiExtension.inc`, `D_D102/`…`D_D130/DDevExtensions.dpr`, `Source/version.inc`, `D_D130/DDevExtensions.dproj`
  - **Why this approach:** ToolsAPI offers no way to reorder a project group's members — `IOTAProjectGroup` exposes only `RemoveProject` plus the interactive add dialogs — and the IDE reads the member order from the `.groupproj` only when the group is opened. Rewriting the file and forcing a reopen is therefore the only mechanism.
  - **Why all three sections are sorted:** a `.groupproj` lists every project three times — in the `<ItemGroup>`, as a trio of per-project `<Target>` elements, and in each of the `Build`/`Clean`/`Make` `CallTarget` lists. The Project Manager tree order follows the `<Target>`/`CallTarget` sections, so sorting only the `<ItemGroup>` has **no visible effect**; `SortGroupProjectText` sorts all three consistently while preserving the header, `ProjectExtensions`, `Import` and any per-project dependency content verbatim.
  - Modelled on `LibraryPathSorter` (Tools-menu item, no new IDE notifier), keeping it clear of the Win64 ToolsAPI teardown fragility. Registration is gated by `INCLUDE_PROJECTGROUPSORTER` and the `DDevExtensions.DisabledFeatures` env var (`ProjectGroupSorter`).

---

## 2026-06-24 - Code hygiene: clear three dcc64 compiler hints

### Fixed

- **Removed the dead `PrevTokenKind` local from `TDeadCodeAnalyzer.ScanForReferences`** (H2077, ×2). It was assigned but never read in that method — the genuine `PrevTokenKind` reads belong to a different method (`ExtractSymbols`) that has its own local of the same name. Pure dead code; no behaviour change. (2026-06-24) — `Source/DeadCodeDetector/DeadCodeDetector.pas`
- **Gated `TCompileProgress.FCompileInterceptorId` behind `{$IFNDEF CPUX64}`** (H2219, private symbol declared but never used). The field is only assigned (`Create`) and read (`Destroy`) inside `{$IFNDEF CPUX64}` blocks — on Win64 the compile interceptor is deliberately a no-op, so the field was unreferenced there. The declaration now matches its usage, with the Win32-only rationale noted in its doc comment. (2026-06-24) — `Source/CompileProgress/CompileProgress.pas`

Builds clean Win64 (D_D130, Release) with no diagnostics.

---

## 2026-06-02 - v3.20.9 - Restore the three DFM cleaners on the 64-bit IDE

### Added

- **New x64-safe full-replacement hook primitive `InstallFullReplaceHook` / `RemoveFullReplaceHook` (record `TFullReplaceHook`).** On Win32 it delegates to the classic `CodeRedirect`; on Win64 it overwrites the target's first 14 bytes with an absolute indirect jump (`FF 25 00000000` + 8-byte target). **Why:** the general `CodeRedirect` is a deliberate no-op on Win64 (5-byte `JMP rel32` has ±2 GB reach and corrupts x64 prologue/unwind info). The new primitive is safe *only* for hooks whose replacement never chains back into the original — control transfers with `JMP` not `CALL`, so the patched function never appears on a call stack and its unwind metadata is irrelevant, and no prologue is relocated or re-run. The global `CodeRedirect` is left untouched so the ~15 chain-back hooks elsewhere stay neutered on Win64. (2026-06-02) — `Shared/Hooking.pas`

### Fixed

- **The three "Do not store … into the DFM" options now work on the 64-bit IDE.** *Do not store the Explicit\* properties*, *…the PixelsPerInch property* and *…the TextHeight property* were greyed out under Options → Form Designer on the Win64 IDE because their `CodeRedirect` install was inert there (reported by a user who upgraded specifically for these). All three are full-replacement hooks (their replacement `DefineProperties` never calls the original), so they were switched to `InstallFullReplaceHook`/`RemoveFullReplaceHook` and the controls re-enabled on x64. Verified live on the Win64 D13 IDE: Explicit\* and TextHeight strip on save; PixelsPerInch shares the identical hook path. Builds clean Win32 + Win64 (D_D130, Release). (2026-06-02) — `Source/FormDesignerHelpers/RemoveExplicitProperty.pas`, `Source/FormDesignerHelpers/RemovePixelsPerInchProperty.pas`, `Source/FormDesignerHelpers/RemoveTextHeightProperty.pas`, `Source/FormDesignerHelpers/FrmeOptionPageFormDesigner.pas`, `Shared/Hooking.pas`, `Source/version.inc`

### Documentation

- **Documented that *Remove PixelsPerInch* is only observable at non-96 DPI.** Delphi streams `PixelsPerInch` only when the design DPI differs from 96 (`PixelsPerInch <> USER_DEFAULT_SCREEN_DPI` in `TDataModule`/`TCustomForm.DefineProperties`), so at 100% scaling the IDE never emits it and the option has no visible effect — it only does work on a scaled/high-DPI design display. **Why:** prevents the false "the option is broken" conclusion when no `PixelsPerInch` line appears at 96 DPI. (2026-06-02) — `Help.md`

---

## 2026-06-01 - Repository hygiene: stop versioning auto-generated `.res`

### Removed

- **Auto-generated project `.res` files are no longer version-controlled.** Untracked (kept on disk) the six IDE-regenerated resources that the compiler rewrites on every build: `DDevExtensions.res` (D_D130), `DDevExtensionsReg.res`, `ExampleCompileInterceptor.res`, `CompileInterceptorW.res`, `DDevExtUnitTests.res`, `DDevExtUnitTestsDUnitX.res`. **Why:** binary `.res` cannot be diff/merged, so each rebuild produced spurious changes that caused sync conflicts for contributors (reported by Achim Kalwa). They regenerate locally on build, so nothing is lost. (2026-06-01) — `D_D130/DDevExtensions.res`, `Installer/DDevExtensionsReg.res`, `Example/ExampleCompileInterceptor.res`, `Source/CompileInterceptorW.res`, `DDevExtUnitTests.res`, `DDevExtUnitTestsDUnitX.res`

### Changed

- **`.gitignore` now ignores build output `*.res`, with negation exceptions** for the three hand-built static-asset resources that have no regenerable source and are referenced by explicit `{$R name.res}` directives — keeping them tracked so a fresh clone still builds: `Version.res` (from the tracked `Version.rc`), `Splash.res` (splash image), `ComponentPanel.res` (old-palette bitmaps). `*.exe`, `*.dll`, `*.bpl`, `*.dcu` ignore rules were already present. (2026-06-01) — `.gitignore`

---

## 2026-05-30 - v3.19.9 - UI workflow audit: Low-severity fixes

Addresses the 96 Low-severity findings from the UI workflow audit across the
feature modules. Builds clean on Win32 and Win64 (D_D130, Release). Same
priorities throughout: integrity (no wrong results / corrupt state), reliability
(no unhandled exceptions, use-after-free or silent failures), performance
(scanning stays single-pass). Substantive items were fixed; cosmetic items, or
ones already resolved by earlier refactors, or where a fix would be a large
speculative rewrite, are recorded as documented notes at the end.

### Fixed - reliability (crashes / exceptions / lifetime)

- **Option-page frames no longer trust the framework blindly.** `SetUserData` now validates the cast (`is` test, nil on mismatch) and `LoadData`/`SaveData` early-exit when the config is not assigned, in Compile Backup, Compiler Enhancements and File Cleaner — a wrong/nil `UserData` can no longer AV or raise `EInvalidCast` during page setup. (2026-05-30) — `FrmeOptionPageCompileBackup.pas`, `FrmeOptionPageCompilerEnhancements.pas`, `FrmeOptionPageFileCleaner.pas`
- **`AfterCompile` style-check wrapped in try/except** so a checker/parse failure can no longer escape into the IDE's post-compile notifier pipeline. (2026-05-30) — `CompileProgress.pas`
- **Native progress label** no longer dereferences a nil `FProgressBar` when `SetMaxFiles` left it unset (`FMaxFiles <= 0`). (2026-05-30) — `NativeProgressForm.pas`
- **Debugger step-into-skip** validates the dcc32 module handle and both exports, uses `GetModuleHandle` instead of leaking a `LoadLibrary` handle, and only installs the `FindSourceLine` redirect once the byte-signature match and dependency thunks resolved (otherwise the hook could call nil). (2026-05-30) — `DbgStepIntoSkip.pas`
- **Dependency Viewer close-during-scan** guarded with an `FScanning` re-entrancy/close veto (`ScannerProgress` pumps the message queue). (2026-05-30) — `FrmDependencyViewer.pas`
- **Keybindings `SetActive`** uses `Supports(BorlandIDEServices, IOTAKeyboardServices)` instead of a hard `as` cast, so the destructor-time disable cannot raise `EIntfCastError` during (Win64) shutdown. (2026-05-30) — `FrmeOptionPageKeybindings.pas`
- **IDE Path Sorter** singleton creates into a local and only assigns the global after a successful constructor (a `FormCreate` exception no longer leaves a dangling non-nil instance), and `Create Backup` uses `InputQuery` so Cancel no longer creates a backup. (2026-05-30) — `FrmLibraryPathSorter.pas`
- **Project Settings**: `Set Versioninfo` enable test guards `GetActiveProject <> nil` before `GetPersonality`; the settings submenu guards `Items[Count-1]`; the Versioninfo dialog wraps `LoadFromIconFile` in try/except and replaces an `Assert`-only control lookup with a release-safe runtime guard. (2026-05-30) — `ProjectSettings.pas`, `FrmProjectSettingsSetVersioninfo.pas`
- **Unused Unit Detector** unload closes any open detector form (new `CloseInstance`) and frees the plugin under an `Assigned` guard, so a stale form cannot reference freed plugin state. (2026-05-30) — `UnusedUnitDetector.pas`, `FrmUnusedUnitDetector.pas`
- **External Mod Monitor**: toggling `Active` in the options page now syncs the live watch set (`ApplyActiveState` — clears watches + tray icon on disable, scans open projects on enable) instead of only flipping the flag; the project-group branch now watches each member project; `ProcessNotifications` validates every `FILE_NOTIFY_INFORMATION` record stays within the 4 KB buffer before `Move` (truncated final record can no longer read out of bounds). (2026-05-30) — `ExternalModMonitor.pas`, `FrmeOptionPageExternalModMonitor.pas`, `FileWatcher.pas`
- **TODO Aggregator** clipboard copy wrapped in try/except (transient clipboard lock no longer surfaces a raw `EClipboardException`). (2026-05-30) — `FrmTodoAggregator.pas`
- **`Application.MainForm` nil-guarded** before `FindComponent('mnuFormatSource')` in the DSU source-formatter-hotkey setter. (2026-05-30) — `FrmeOptionPageDSUFeatures.pas`
- **Core**: `TPluginConfig` legacy-migration and `ComponentSelector` registry load/save no longer swallow exceptions silently (logged via `OutputDebugString`; the registry paths never re-raise out of `Destroy`); `InitAppDataDirectory` checks `ForceDirectories` and falls back beside the executable; `DeletePackageComponents` asserts list-count parity after `Pack`. (2026-05-30) — `PluginConfig.pas`, `ComponentSelector.pas`, `Main.pas`, `ComponentManager.pas`
- **`StartParameterUpdate`** guards the dead `FActionCustomize` dereference so re-wiring the (currently commented-out) action cannot AV. (2026-05-30) — `StartParameterManagerReg.pas`

### Fixed - correctness (wrong results)

- **Code Quality Analyzer**: the `AllowMagicInArrayIndex` exemption now tracks bracket-nesting depth, so any literal inside `[ ... ]` (e.g. `A[ I + 5 ]`) is treated as an array index, not just the token directly after `[`. The unimplemented memory-leak check defaults off and its option-page controls are disabled so it cannot advertise a check that does nothing. Line/Column base documented. (2026-05-30) — `CodeQualityAnalyzer.pas`, `FrmeOptionPageCodeQuality.pas`
- **Code Style navigation** clamps the caret column to a minimum of 1 (`Max(1, Column)`) so synthetic `Column 0` violations still position sensibly. (2026-05-30) — `FrmCodeStyleChecker.pas`
- **Component Selector** best-fit selection uses the **absolute** length difference, so it no longer always biases toward the shortest entry. (2026-05-30) — `ComponentSelector.pas`
- **Dependency Viewer** reports a consistent cycle "unit count" (distinct units = `Length(Steps) - 1`) across the listbox, CSV and TXT exports, and the `dot.exe` PATH search skips empty entries and strips surrounding quotes. (2026-05-30) — `FrmDependencyViewer.pas`
- **Empty Event Handler Detector** records the declaration line from the `procedure`/`function` keyword token, so navigation lands on the declaration's first line even when the name wraps. (2026-05-30) — `EmptyEventHandlerDetector.pas`
- **Unreachable Code** preview ellipsis is now driven by a real truncation flag (50-char cap hit with more non-EOL content) rather than the post-trim length. (2026-05-30) — `UnreachableCodeDetector.pas`
- **TODO Aggregator** priority sort maps High/Normal/Low to integer ranks (unknown values rank last) and compares numerically; the `Column` field doc corrected to 1-based. (2026-05-30) — `FrmTodoAggregator.pas`, `TodoAggregator.pas`
- **Old Palette** only calls `LoadComponentBitmap` when `GetClass(Item.Name) <> nil`, otherwise goes straight to the default-image path. (2026-05-30) — `OldPalette.pas`
- **File Cleaner** uses Unicode-safe `LowerCase` for the saved-file extension instead of the legacy `AnsiLowerCase` round-trip; the destructor stops processing (`Active := False`) before freeing the notifier (`FreeAndNil`). (2026-05-30) — `FrmeOptionPageFileCleaner.pas`
- **File Selector** default filter-field index uses an intention-revealing constant instead of an unrelated image-list constant; stray double semicolon removed. (2026-05-30) — `FrmFileSelector.pas`
- **Uses Clause Manager** Apply/Move verify the active editor's `FileName` still equals the analysed file before rewriting, and `ScanUnit` logs (rather than silently swallows) a file-load failure. (2026-05-30) — `FrmUsesClauseManager.pas`, `UsesClauseManager.pas`
- **Focus Editor** (Editor variant) keeps scanning the remaining `TEditWindow` forms when an edit window has no focusable `Editor` child, only stopping after a successful `SetFocus`. (2026-05-30) — `Editor\FocusEditor.pas`
- **Excel export** progress uses `Int64(i) * 100` to avoid integer overflow on very large lists. (2026-05-30) — `FrmExcelExport.pas`
- **CSV exports** now RFC 4180-escape embedded double-quotes (Code Quality, Dead Code, DFM/PAS Consistency, Empty Event Handler, Unused Unit). (2026-05-30) — `FrmCodeQualityAnalyzer.pas`, `FrmDeadCodeDetector.pas`, `FrmDfmPasConsistency.pas`, `FrmEmptyEventHandlerDetector.pas`, `FrmUnusedUnitDetector.pas`

### Fixed - diagnosability / standards

- **Silently-failing hooks now log** when an install fails: Focus Editor (LoadDesktop symbol unresolved), Form Designer `ReplaceVmtField`, and the DSU structure-view `SetFocus` empty `except`. (2026-05-30) — `FocusEditor\FocusEditor.pas`, `LabelMarginHelper.pas`, `StrucViewSearch.pas`
- **Reload-hook exception** passes the actual exception object (and logs) instead of `nil` to the application handler. (2026-05-30) — `FrmReloadFiles.pas`
- **IDE menu handler** re-resolves the Project menu each `ActionUpdate` tick rather than trusting a cached `TMenuItem` that the IDE may have freed during a personality switch. (2026-05-30) — `IDEMenuHandler.pas`
- **Options URL label** shows a message when the link cannot be opened instead of silently greying itself out. (2026-05-30) — `Shared\IDE\Options\FrmOptions.pas`
- **Stray debug `Write;`** removed from the Project-Settings `CopyTo` option loop; `UpdateExceptWarnings` uses an inline `for var iI` loop counter per GITLAK. (2026-05-30) — `ProjectSettingsData.pas`, `FrmeOptionPageCompilerEnhancements.pas`
- **IDE Path Sorter** dead `Item.Data` tag removed (Restore/Delete resolve by index). (2026-05-30) — `FrmLibraryPathSorter.pas`

### Fixed - build / release

- **Extension DLL version resource corrected to 3.19.9.** `DDevExtensionsD130.dll` / `…x64.dll` had reported FileVersion/ProductVersion `2.87` because the `.dpr` links a pre-compiled `{$R ..\Version.res}` that Delphi does not regenerate from `Version.rc` during a normal `.dproj` build — so every prior `version.h`/`.dproj` bump bypassed the DLL's own version resource (the user-facing splash was always correct, sourced from `version.inc`). Recompiled `Version.res` with `brcc32` (`Version.rc` `#include`s `version.h` = 3.19.9) and rebuilt; the DLLs now report FileVersion 3.19.9. **Note for future releases:** `brcc32 Version.rc` must be part of the version-bump routine, otherwise the DLL resource silently lags. (2026-05-30) — `Code/DDevExtensions/Version.res`, `Code/DDevExtensions/version.h`, `Code/DDevExtensions/Version.rc`

### Changed - test suite

- **Renamed the test project `DfmParserTests` → `DDevExtUnitTests`** (folder, both `.dpr`/`.dproj` variants — the plain console runner and the DUnitX suite — `.res`/`.ini`/`.eof`, program declarations and all internal project references). The product-level name reflects that this is the umbrella unit-test suite; individual test units keep their feature names (`TestDfmParser`, `TestDfmParserDUnitX`), so future analyzer tests slot in as `TestCodeQuality`, etc. Untracked the rebuilt `.exe` artifacts and added a scoped `.gitignore` (`*.exe`). Both projects build clean (Win64, Release) and the suite still passes 31/31. **Why:** the DFM-specific name would mislead once analyzer coverage is added (see `UnitTestCoverage-Plan.md`). (2026-05-30) — `DDevExtUnitTests/` (was `DfmParserTests/`), `.claude/settings.local.json`
- **Added `DelphiLexer` unit tests** (`TestDelphiLexer.pas`, 9 cases / 24 assertions) covering token classification (keywords vs identifiers, int/float/hex/string literals, multi-char operators, brackets, comments, directives) and the `Line` 0-based / `Column` 1-based contract. Guards two v3.19.9 behaviours: bracket tokenisation behind the magic-number bracket-depth fix, and the analyzer navigation line/column base. The lexer underpins every analyzer and the DFM parser, so this is the highest-leverage coverage. Suite now passes 55 (31 DFM + 24 lexer). Build artifacts (`.exe`/`.dll`/`.dcu`…) are no longer tracked — repo `.gitignore` enforces it. The coverage roadmap was expanded and renamed `AnalyzerTestCoverage-Plan.md` → `UnitTestCoverage-Plan.md`. (2026-05-30) — `DDevExtUnitTests/TestDelphiLexer.pas`, `DDevExtUnitTests/DDevExtUnitTests.dpr`, `UnitTestCoverage-Plan.md`, `.gitignore`
- **Completed Tier 1 unit-test coverage** — added `TestDelphiExpr.pas` (6 cases / 21 assertions: literal/binary nodes, int↔float coercion, unary minus, float div-by-zero error path, relational/boolean operators, end-to-end `TExpressionParser.Parse` precedence), `TestDelphiParserContainers.pas` (5 cases / 24 assertions: THashtable case-sensitivity + ownership-aware removal, TIntegerList, TStringDictionary, TStringCollection) and `TestDelphiPreproc.pas` (4 cases / 10 assertions: `$IFDEF`/`$IFNDEF`/`$ELSE`/nested blocks, in-source `$DEFINE`/`$UNDEF`, `Define`/`Undefine` state). The test project now declares the same Delphi-10.2+ `COMPILERx_UP` symbols as the main projects (Base-config `DCC_Define`) so the Shared units compile their modern paths. Suite passes 110 assertions (31 DFM + 24 lexer + 24 containers + 21 expr + 10 preproc) on Win32 and Win64. (2026-05-30) — `DDevExtUnitTests/TestDelphiExpr.pas`, `DDevExtUnitTests/TestDelphiParserContainers.pas`, `DDevExtUnitTests/TestDelphiPreproc.pas`, `DDevExtUnitTests/DDevExtUnitTests.dpr`, `DDevExtUnitTests/DDevExtUnitTests.dproj`, `UnitTestCoverage-Plan.md`
- **Added Tier 2 `UnitMetrics` tests** (`TestUnitMetrics.pas`, 4 cases) covering base/branch (`if`/`while`/`for`)/case-label cyclomatic complexity and LOC with comment-line exclusion (via a temp-file fixture, since the public API takes a file name). Suite now passes 114 assertions. The other Tier 2 candidates (`ProjectSettingsData`, `CtrlUtils`, `UsesClauseManager`, `DependencyViewer`) were attempted and found to need core extraction to be console-testable — `ProjectSettingsData` `uses ToolsAPI` directly and `CtrlUtils.TListViewSort.Compare` needs a windowed `TListView` — so they were folded into the Tier 3 extraction roadmap (no production change; trial seams were reverted). (2026-05-30) — `DDevExtUnitTests/TestUnitMetrics.pas`, `DDevExtUnitTests/DDevExtUnitTests.dpr`, `DDevExtUnitTests/DDevExtUnitTests.dproj`, `UnitTestCoverage-Plan.md`

### Documented (no code change)

The following Low findings were left as-is with a rationale rather than changed,
because the behaviour is acceptable, already mitigated, or a fix would be a large
speculative rewrite: Code Style / Empty-Event-Handler / DFM-Consistency popup
`OnPopup` enable-state and export-honours-selection (minor UX); UnitMetrics `+100`
over-allocation and `SetAskCompileFromDiffProject` field-only setter
(Compile Progress); Component Selector `with`-over-`TListBox` and packed-record
registry persistence; DFM/PAS sort-column magic indices, dead `ExtractFormClassName`
and substring collection-depth heuristic; Editor `btnDiff` index-vs-module race
(modal, low likelihood); Focus Editor / Old Palette hardcoded IDE child names;
File Cleaner DFM `Visible=False` legacy compiler gate; IDE-menu dead build-config
stub; Keybindings `Ctrl+Left/Right` ASCII-identifier assumption; Library Path
Sorter `'Build'` caption-substring menu insertion; Old Palette / Uses Clause
Manager `NativeInt` tag round-trips (correct on Win64) and the unused highlight
marker; Unit Selector `IsDelphiNetPersonality` dead branch; Unreachable Code
`Pos('implementation')` whole-word edge and per-config/implicit project defines;
Start Parameter Manager `TProjectParameters` dual lifetime; Start-Parameter-Team
`DoModuleRenamed` dead hook; and the intentional Win64 `UninstallHooks` swallow
(attribution tracked by its existing TODO). The Start-Parameter-Team `StrLComp`
length bug and the Form-Designer master-checkbox gating noted in the audit were
already resolved by earlier refactors.

## 2026-05-30 - v3.18.8 - UI workflow audit: Medium-severity fixes

Addresses the 145 Medium-severity findings from the UI workflow audit across 32
feature modules. Builds clean on Win32 and Win64 (D_D130, Release). Priorities
throughout: integrity (no wrong results / corrupt state), reliability (no
unhandled exceptions, use-after-free or silent failures), performance (scanning
remains single-pass). A small number of findings were deliberately scoped to a
documented note rather than a code change (see end) where a fix would have been a
large speculative rewrite or the issue was already mitigated by existing gating.

### Fixed - reliability (crashes / exceptions / lifetime)

- **Project scans no longer abort on one bad file.** The per-module loops in the Code Quality, Code Style, Empty-Event-Handler, Dead Code, DFM/PAS Consistency, Dependency Viewer and Unused Unit scanners now isolate each module in try/except (and the engines guard `LoadFromFile`), so a single locked/unreadable/malformed unit is skipped instead of aborting the whole project scan. Code Quality also surfaces a skipped-file count. (2026-05-30) — `CodeQualityAnalyzer.pas`, `FrmCodeQualityAnalyzer.pas`, `CodeStyleChecker.pas`, `FrmEmptyEventHandlerDetector.pas`, `DeadCodeDetector.pas`, `DfmPasConsistency`/`FrmDfmPasConsistency.pas`, `DependencyViewer.pas`, `UnusedUnitDetector.pas`
- **`EditViews[0]` / `OpenModule` navigation hardened.** Open-file/double-click handlers across Code Quality, Code Style, Dead Code, Unreachable Code and Build Statistics now check `FileExists`, wrap `OpenModule` in try/except, guard `EditViewCount > 0`, and report "could not open" / "no source editor" instead of doing nothing or AV-ing. (2026-05-30) — `FrmCodeQualityAnalyzer.pas`, `FrmCodeStyleChecker.pas`, `FrmDeadCodeDetector.pas`, `FrmUnreachableCodeDetector.pas`, `FrmBuildStatistics.pas`
- **Close-during-scan use-after-free** guarded in Dead Code and Unreachable Code (re-entrancy/`FScanning` veto), matching the v3.17.7 fix to the other scanners. (2026-05-30) — `FrmDeadCodeDetector.pas`, `FrmUnreachableCodeDetector.pas`
- **CSV/file exports guarded.** Export handlers (Code Style, Unreachable Code, Dependency Viewer circular/violations) wrap `SaveToFile` in try/except; Code Style now escapes CSV fields (RFC 4180). (2026-05-30) — `FrmCodeStyleChecker.pas`, `FrmUnreachableCodeDetector.pas`, `FrmDependencyViewer.pas`
- **Excel export rewritten** to wrap all OLE automation in try/except, address cells by numeric `Cells[r,c]` (fixes >26-column corruption), and never orphan a hidden Excel process on failure. (2026-05-30) — `FrmExcelExport.pas`
- **Unguarded file IO surfaced** with friendly messages instead of raw exceptions: Compiler-Backup save, Start Parameter `.params` create/open, Start-Parameter-Team `.dproj` rewrite, IDE Path Sorter registry write (with resync), File Cleaner deletions (isolated from the IDE save pipeline). (2026-05-30) — `FrmeOptionPageCompileBackup.pas`, `StartParameterCtrl.pas`, `FrmeOptionPageStartParameterTeam.pas`, `FrmLibraryPathSorter.pas`, `FrmeOptionPageFileCleaner.pas`
- **ToolsAPI / nil dereferences guarded** per the GITLAK nil-check rule: Splash services, Component Selector construction/hotkey/click, Old Palette (`MainForm`/`GetComponentPalette`), DSU structure-view action and project-tree `OnGetText`, Editor reload, Reload "Show in Explorer", Project Settings `ProjectDestroying`/`ActionExecute`, Start Parameter `GetActiveParams`/`DoPopup`, Start-Parameter-Team `FileNotification`, External Mod Monitor config casts and per-editor inspection, Keybindings `EditPosition`. (2026-05-30) — multiple units
- **Win64 teardown safety:** Build-Statistics, Dead Code and IDE-menu-handler menu items are detached from their parent before being freed (avoids double-free during IDE teardown); Compile-Active project-restore moved into a `finally`; Start-Parameter-Team destructor disables before freeing notifiers. (2026-05-30) — `CompileProgress.pas`, `DeadCodeDetector.pas`, `IDEMenuHandler.pas`, `FrmeOptionPageStartParameterTeam.pas`
- **Silently-swallowed exceptions now logged** (`OutputDebugString`) rather than discarded: Component Manager registration, Compile-Backup write, DSU background-parsing probe, Reload `CanReloadFile`, Project-Settings option capture, TODO/External-Mod-Monitor file handling, IDE-Path-Sorter owner-draw, Start-Parameter `WMSetFocus` bare except removed. (2026-05-30) — multiple units

### Fixed - correctness (wrong results)

- **Code Quality Analyzer**: `const` parameter modifiers no longer mistaken for a const section (paren-depth tracking); hardcoded-string detection decodes `''`/skips `#nn` tokens; nil-Plugin guard; the nested-`except` mis-analysis was already resolved by the v3.17.7 block-stack rewrite. (2026-05-30) — `CodeQualityAnalyzer.pas`
- **Dead Code Detector**: reference matching now scopes unit/private/protected symbols to their own file (the previous identical if/else branches marked any same-named identifier as a use, masking dead code). (2026-05-30) — `DeadCodeDetector.pas`
- **Empty Event Handler Detector**: requires a `Sender` parameter (cuts false positives on methods merely ending in a common word) and counts statements at any nesting depth (no longer reports handlers whose work is in a nested block). (2026-05-30) — `EmptyEventHandlerDetector.pas`
- **Uses Clause Manager**: priority match compares unqualified leaf names (dotted vs bare), and Apply never auto-moves units the analyser could not classify. (2026-05-30) — `UsesClauseManager.pas`, `FrmUsesClauseManager.pas`
- **CtrlUtils list sort**: ragged rows (items with fewer subitems) treat a missing subitem as empty rather than returning "equal" and corrupting the order. (2026-05-30) — `CtrlUtils.pas`
- **Keybindings**: the Section-Toggle Up/Down shortcuts now go to interface / implementation respectively (were identical); target row clamped to the buffer. (2026-05-30) — `FrmeOptionPageKeybindings.pas`
- **Dependency Viewer**: cycle highlighting no longer mutates node captions (relies on custom draw), per-layer pattern lists freed on dialog close, layer-name input trimmed and `=`/`,` rejected (protects the config round-trip), and the shared export dialog title is reset. (2026-05-30) — `FrmDependencyViewer.pas`, `FrmLayerConfig.pas`
- **DFM/PAS Consistency**: replaced a dangling-`PChar`-in-`Item.Data` with a hidden subitem, restored the summary on returning to the "All" filter, and guard empty filename / unknown line on navigate. (2026-05-30) — `FrmDfmPasConsistency.pas`, `DfmPasConsistency.pas`
- **Unreachable Code / Old Palette / Compile-Progress** logic tidy-ups (sort-safe selection clear, dead editor-context branch removed, `Boolean(Variant)` replaced with a value comparison, switch-project combo ordering). (2026-05-30) — `FrmDeadCodeDetector.pas`, `OldPalette.pas`, `CompileProgress.pas`, `FrmSwitchToModuleProject.pas`
- **IDE Path Sorter** Apply verification compares actual path content element-by-element (was semicolon-count only). (2026-05-30) — `FrmLibraryPathSorter.pas`

### Fixed - Win64 / fragility / standards

- Win64-inert features now disable their controls or are explicitly gated with a comment: Compile Backup option page, DSU editor-double-click zoom signature, IDE-internal parser-thread offset, Focus Editor hook. (2026-05-30) — `FrmeOptionPageCompileBackup.pas`, `FrmeOptionPageDSUFeatures.pas`, `FocusEditor.pas`
- The experimental, unreferenced `DbgStepIntoSkip` debugger unit gated `{$IFNDEF CPUX64}` and documented as unsupported/inactive. (2026-05-30) — `DbgStepIntoSkip.pas`
- A bare English sentence inside an active-able `{$IF CompilerVersion > 37}` block (a compile time-bomb on the next compiler) replaced with `{$MESSAGE WARN}`; German placeholder exception text replaced with English. (2026-05-30) — `RemovePixelsPerInchProperty.pas`, `FrmProjectSettingsSetVersioninfo.pas`
- `with TForm.Create do try..finally Free` rewritten to a named local; `Utf8Encode(...)`→`PAnsiChar` temporary captured in a named local for Win64 safety; Code-Style rule edits and Form-Designer dependent-checkbox states persisted/synchronised correctly. (2026-05-30) — `FrmSwitchToModuleProject.pas`, `FrmFileSelector.pas`, `FrmeOptionPageCodeStyle.pas`, `FrmeOptionPageFormDesigner.pas`
- File Selector: `FParser` leak freed in the destructor; single-remaining-unit uses-clause removal no longer indexes out of bounds. (2026-05-30) — `FrmFileSelector.pas`

### Changed

- Version bumped 3.17.7 → 3.18.8 (`MinorVer` 17→18, `Release` 7→8, `FileVersion` `3.18.8.x`, `ProductVersion` 3.18) across `version.inc`, `version.h`, all six `D_Dxxx/DDevExtensions.dproj` and `Installer/DDevExtensionsReg.dproj`. (2026-05-30)
- **Fully-qualified all RTL/VCL unit-scope names in uses clauses** across every `.pas` under `Code/DDevExtensions/Source` (93 files, 921 entries): `Windows`→`Winapi.Windows`, `Classes`→`System.Classes`, `Forms`→`Vcl.Forms`, `Registry`→`System.Win.Registry`, `XMLDoc`→`Xml.XMLDoc`, etc. Project, IDE/ToolsAPI and third-party (JVCL) units are left unprefixed. Short unit qualifiers used in code were then reviewed: redundant ones were dropped to bare names (`LoadBitmap`, `FinalizePackage`), while genuine disambiguations were kept fully qualified (`Vcl.ComCtrls.dsGradient`/`Vcl.ExtCtrls.dsGradient`, `Vcl.ComCtrls.TListView`, `Winapi.Windows.SetFocus`/`FindClose`, `System.AnsiStrings.StrLIComp`, `System.TypInfo.GetPropInfo`). Builds clean on Win32 and Win64. (2026-05-30) — all Source units
- DocInsight XML documentation updated for the members changed in this work: the new `FScanning` / `FBusy` fields are documented, and `TKeybindings.ToggleSection` (new `GoToImplementation` param) and `TKeybindings.FindDeclaration` (now a `Boolean` function) have updated `<param>`/`<returns>`. (2026-05-30) — `FrmCodeStyleChecker.pas`, `FrmDeadCodeDetector.pas`, `FrmTodoAggregator.pas`, `FrmUnreachableCodeDetector.pas`, `FrmUnusedUnitDetector.pas`, `FrmUsesClauseManager.pas`, `FrmeOptionPageKeybindings.pas`

### Notes (findings scoped to documentation rather than a code change)

- VirtTreeHandler `@NotSupported` accessors on Win64: already unreachable because the tree handler is creation-gated `{$IFNDEF CPUX64}`.
- External Mod Monitor: option changes still take effect on next IDE restart, and auto-refresh during a compile is unguarded on Win64 (the IDE notifier is gated off there) — both documented.
- IDE Path Sorter restore-by-list-index and construction double-load, Reload-Files window-proc restore, Project-Settings default-preset auto-assign, and the TODO multi-keyword-per-comment limit: left as-is (correct for current usage) and noted.

---

## 2026-05-30 - v3.17.7 - UI workflow audit: remaining High-severity fixes

Resolves the 18 confirmed High-severity findings from the UI workflow audit (the
two Project Settings pointer-truncation issues shipped in v3.17.6). All changes
build clean on both Win32 and Win64 (D_D130, Release). Priorities throughout:
integrity (no corrupt state or wrong results), reliability (no unhandled
exceptions or use-after-free), and performance (single-pass scanning preserved).

### Fixed

- **Code Quality Analyzer try/finally detector silently disarmed; non-try `end`s corrupted state.** A single `TryDepth` counter plus an `InExceptBlock` flag drove every `end`. `try/finally` never decremented the counter (so after the first one the missing-try/finally check stopped working and treated all later `Create`s as protected), and any `end` from a record/class/case/begin was mis-counted as a try-end, drifting the except state. Replaced with a structural block stack that matches each `end` to the construct it closes, tracks per-try except/finally sections, and resets at `implementation`. (2026-05-30) — `Code/DDevExtensions/Source/CodeQualityAnalyzer/CodeQualityAnalyzer.pas`
- **Code Style Checker reported a flood of bogus UnitScopePrefix violations.** The unit-scope lookahead consumed the terminating semicolon of a uses clause, which was never re-tested, so `InUsesClause` never cleared and every later identifier was checked as if still in the uses list. Re-apply the termination test to the peeked token. (2026-05-30) — `Code/DDevExtensions/Source/CodeStyleChecker/CodeStyleChecker.pas`
- **Compiler Enhancements promoted exactly the wrong warnings to errors.** The ExceptWarnings membership test was inverted (`IndexOf <> -1`), so only the codes the user listed to keep as warnings were promoted, and a special-case made an empty list promote everything. Now promotes every warning except those listed. (2026-05-30) — `Code/DDevExtensions/Source/CompilerEnhancements/FrmeOptionPageCompilerEnhancements.pas`
- **Editor "Select modified / unmodified files" menu items were labelled with each other's caption.** Swapped the two resource-string assignments in `FormCreate`. (2026-05-30) — `Code/DDevExtensions/Source/Editor/FrmReloadFiles.pas`
- **Unused Unit Detector: every unit reported the line of the `uses` keyword, and used units could be reported as unused.** Track each unit token's own start position for its line number, and scan every occurrence of a known identifier (not just the first) when deciding whether a unit is referenced. (2026-05-30) — `Code/DDevExtensions/Source/UnusedUnitDetector/UnusedUnitDetector.pas`
- **Unreachable Code Detector opened the wrong source location after sorting.** Double-click resolved the row by re-walking the items in scan order, but column sort (`AlphaSort`) reorders the rows. Resolve through the original index stored in the item's `Data` instead. (2026-05-30) — `Code/DDevExtensions/Source/UnreachableCodeDetector/FrmUnreachableCodeDetector.pas`
- **Uses Clause Manager recorded reserved words as identifiers.** `Token.Kind >= tkIdent` swept in every keyword (begin, class, if, ...), polluting the interface-vs-implementation placement analysis. Changed all six predicates to `Token.Kind = tkIdent`. (2026-05-30) — `Code/DDevExtensions/Source/UsesClauseManager/UsesClauseManager.pas`

### Fixed — error handling / lifetime

- **Use-after-free when closing Code Style Checker, TODO Aggregator or Unused Unit Detector during a scan.** Each scan pumps the message queue, so the user could close the form while the scanner was still on the stack, freeing the form and its worker. Added an `FScanning` guard that vetoes the close (`Action := caNone`) while a scan is running. (2026-05-30) — `Code/DDevExtensions/Source/CodeStyleChecker/FrmCodeStyleChecker.pas`, `Code/DDevExtensions/Source/TodoAggregator/FrmTodoAggregator.pas`, `Code/DDevExtensions/Source/UnusedUnitDetector/FrmUnusedUnitDetector.pas`
- **Enabling Compiler Enhancements with a missing interceptor DLL threw a raw exception into the options dialog and left `FActive` inconsistent.** Wrapped (un)registration in try/except, roll `FActive` back on failure, and show a friendly message. (2026-05-30) — `Code/DDevExtensions/Source/CompilerEnhancements/FrmeOptionPageCompilerEnhancements.pas`
- **DSU Features: `FPrjMgrTree.Invalidate` dereferenced a nil tree** when the project manager form was not found (common at IDE-load when the setter first runs). Guarded with a nil check. (2026-05-30) — `Code/DDevExtensions/Source/DSUFeatures/FrmeOptionPageDSUFeatures.pas`
- **DSU Features: package-load hook blanked or AV'd the main-form caption** in its `finally` when `MainForm` was nil/hidden during early startup. Only restore the caption when it was actually changed. (2026-05-30) — `Code/DDevExtensions/Source/DSUFeatures/DSUFeatures.pas`
- **IDE Path Sorter: a failed backup save raised instead of returning False,** so the "Failed to create backup. Continue anyway?" path was unreachable. `CreateBackup` now traps the save failure, returns False, and reloads from disk to stay consistent. (2026-05-30) — `Code/DDevExtensions/Source/LibraryPathSorter/LibraryPathSorter.pas`

### Fixed — Win64 platform safety

- **Keybindings Move-Line/Block corrupted memory on Win64.** It hand-cast `IOTAEditWriter` to a replica record with fixed 32-bit field offsets and poked IDE-internal structures. Gated the struct manipulation behind `{$IFNDEF CPUX64}`; the block move now uses only the documented `IOTAEditWriter` API on Win64 (undo grouping / persistent-block restoration degraded but safe). (2026-05-30) — `Code/DDevExtensions/Source/Keybindings/FrmeOptionPageKeybindings.pas`
- **Form Designer DFM cleaners were inert on Win64 but presented as active.** RemoveExplicit/PixelsPerInch/TextHeight install via `CodeRedirect`, a no-op on Win64. The three check boxes are now disabled with a "Not available on the 64-bit IDE" hint, and the hook installs are gated so the intent is explicit. LabelMargin (ReplaceVmtField) still works and stays enabled. (2026-05-30) — `Code/DDevExtensions/Source/FormDesignerHelpers/FrmeOptionPageFormDesigner.pas`

### Changed

- Version bumped 3.17.6 → 3.17.7 (`Release` 6→7, `FileVersion` `3.17.7.x`; `MinorVer`/`ProductVersion` unchanged). (2026-05-30) — `Code/DDevExtensions/Source/version.inc`, `Code/DDevExtensions/version.h`, `Code/DDevExtensions/D_D102/DDevExtensions.dproj`, `Code/DDevExtensions/D_D103/DDevExtensions.dproj`, `Code/DDevExtensions/D_D104/DDevExtensions.dproj`, `Code/DDevExtensions/D_D110/DDevExtensions.dproj`, `Code/DDevExtensions/D_D120/DDevExtensions.dproj`, `Code/DDevExtensions/D_D130/DDevExtensions.dproj`, `Code/DDevExtensions/Installer/DDevExtensionsReg.dproj`
- Added the missing `<VerInfo_Release>` element (=7) to the older project files and the Installer, which previously carried the release digit only in the `FileVersion` string. Their discrete `MajorVer`/`MinorVer`/`Release` fields now match `D_D130`. **Why:** version-info consistency across all personalities; these projects target Delphi 10.2–12 and are not built in the current Delphi 13 environment. (2026-05-30) — `Code/DDevExtensions/D_D102/DDevExtensions.dproj`, `Code/DDevExtensions/D_D103/DDevExtensions.dproj`, `Code/DDevExtensions/D_D104/DDevExtensions.dproj`, `Code/DDevExtensions/D_D110/DDevExtensions.dproj`, `Code/DDevExtensions/D_D120/DDevExtensions.dproj`, `Code/DDevExtensions/Installer/DDevExtensionsReg.dproj`

---

## 2026-05-30 - v3.17.6 - Win64 pointer-truncation fixes (Project Settings)

### Fixed

- **Project Settings preset menu corrupted/AV on Win64 (64-bit pointer truncation).** The dynamic **Project → Project Settings** preset submenu stored each `TProjectSetting` object pointer into `TMenuItem.Tag` via `Integer(...)`, which truncates a 64-bit address to 32 bits on the Win64 IDE host. Clicking a preset then reconstructed a corrupted pointer in `DoAssignSettingClick`, dereferenced by `Options.CopyTo` / `FGlobalSettings.IndexOf` → access violation or garbage settings applied to the active project. Changed the store-side casts to `NativeInt(...)` (`TMenuItem.Tag` is `NativeInt`); the read-side casts already read the full 64-bit `Tag`. (2026-05-30) — `Code/DDevExtensions/Source/ProjectSettings/ProjectSettings.pas`
- **Manage Configurations in-place rename corrupted/AV on Win64 (same root cause).** `DoExecute` stored the `TProjectSettingList` working lists into `lvwLocal.Tag` / `lvwGlobal.Tag` via `Integer(...)`; on Win64 the truncated pointer never matched `FSettings`, so `lvwGlobalEdited` (F2 rename) chose the wrong `Local:`/`Global:` prefix and ran the duplicate-name check (`List.FindByName`) against a bad pointer. Changed both store-side casts to `NativeInt(...)`. (2026-05-30) — `Code/DDevExtensions/Source/ProjectSettings/FrmProjectSettingManageSettings.pas`

### Changed

- Version bumped 3.16.5 → 3.17.6 across all version-info locations: `MinorVer` 16→17, `Release` 5→6, `FileVersion` `3.16.5.x`→`3.17.6.x`, `ProductVersion` 3.16→3.17 (build numbers preserved; stale legacy `2.5.0.584` blocks left untouched). (2026-05-30) — `Code/DDevExtensions/Source/version.inc`, `Code/DDevExtensions/version.h`, `Code/DDevExtensions/D_D102/DDevExtensions.dproj`, `Code/DDevExtensions/D_D103/DDevExtensions.dproj`, `Code/DDevExtensions/D_D104/DDevExtensions.dproj`, `Code/DDevExtensions/D_D110/DDevExtensions.dproj`, `Code/DDevExtensions/D_D120/DDevExtensions.dproj`, `Code/DDevExtensions/D_D130/DDevExtensions.dproj`, `Code/DDevExtensions/Installer/DDevExtensionsReg.dproj`

---

## 2026-05-13 - v3.16.5 - Delphi 13.1 Win64 IDE Build Support

**Note:** Built and tested only in the Delphi 13.1 64-bit RAD Studio personality (`bin64\bds.exe`). Earlier Delphi releases do not ship a 64-bit IDE host. The 32-bit IDE build is unchanged and remains the primary target.

**Problem:** Delphi 13.1 introduced a 64-bit RAD Studio IDE host (`bin64\bds.exe`), but DDevExtensions was a 32-bit-only DLL. Building the same source for Win64 surfaced two classes of problems: x86 asm and 32-bit-specific hooking primitives that don't compile on Win64, and a deterministic AV at `rtl370.bpl + 0x19AC54` during "Checking project dependencies..." whenever the plug-in's multi-interface IDE notifier was registered with the 64-bit IDE.

**Root cause of the rtl370 AV:** `TIDENotifier` exposes `IOTAIDENotifier`, `IOTAIDENotifier50` and `IOTAIDENotifier80` with overloaded `BeforeCompile` / `AfterCompile` signatures. The Win64 ABI mishandles dispatch through this multi-interface vtable layout once registered via `(BorlandIDEServices as IOTAServices).AddNotifier`. The AV is deterministic, reads `$FFFFFFFFFFFFFFFF`, and reproduces regardless of whether any handlers are attached.

**Central fix:** Gated `AddNotifier` / `RemoveNotifier` inside `TIDENotifier.Create` and `TIDENotifier.Destroy` with `{$IFNDEF CPUX64}`. The notifier object is still constructed on Win64 so call-sites holding typed fields don't get nil derefs; it simply never receives compile / file callbacks. This single change neutralises every TIDENotifier descendant for Win64 in one place.

**Changes Made:**
1. `Shared/IDE/IDENotifiers.pas`: Gated the `AddNotifier` / `RemoveNotifier` calls in `TIDENotifier.Create` and `TIDENotifier.Destroy` with `{$IFNDEF CPUX64}`. Constructor/destructor are still entered; only the IDE-side registration is skipped. DocInsight remarks explain the AV bisection and offset for future maintainers.
2. `Code/DDevExtensions/D_D130/DDevExtensions.dpr`: Added `{$IFDEF WIN64} {$LIBSUFFIX 'D130x64'} {$ELSE} {$LIBSUFFIX 'D130'} {$ENDIF}` so the same `.dpr` produces `DDevExtensionsD130.dll` for Win32 and `DDevExtensionsD130x64.dll` for Win64. Wrapped the `DoneWizard` exception-path `MessageBox` call in `{$IFNDEF CPUX64}` so a dependent-BPL teardown AV (e.g. ElevateDB's `edbrun240rsdelphiwin6413.bpl`) bubbling up to our outer try/except doesn't surface as a misleading "DDevExtensions - EAccessViolation" dialog at Win64 IDE shutdown — the IDE is exiting anyway and its native JIT handler still gets to show its own dialog if it wants to.
3. `Code/DDevExtensions/D_D130/DDevExtensions.dproj`: Added a `Cfg_1_Win64` PropertyGroup so the project builds for the Win64 platform. Debug-info settings were intentionally NOT added — earlier experiments enabling `DCC_DebugInformation`, `DCC_LocalDebugSymbols`, `DCC_SymbolReferenceInfo`, `DCC_MapFile`, `DCC_GenerateStackFrames` in the Win64 config triggered a catastrophic startup dialog cascade and were reverted.
4. **`{$IFDEF WIN64} delayed {$ENDIF}` on ~40 BPL imports** across 14 files. Win64 IDE BPLs export a different subset of debugger / project-process symbols than Win32 (e.g. `@Debug@TProcess@stopOnFirstAddr`, `@Debug@TDebugger@Run`), so static binding crashes the DLL with "Entry Point Not Found" before any of our code runs. The `delayed` modifier on Win64 only — not on Win32 — was the lesson learned from v3.16.4: carpet-bombing `delayed` on every platform breaks the Win32 RAD Studio personality. Files touched include the editor, structure pane, compile interceptor, debugger integration and project-manager helpers.
5. `Shared/Hooking.pas`: Split `RedirectOrgCall` into separate `{$IFDEF CPUX64}` / `{$IFDEF CPUX86}` function bodies so Win64 returns `nil` silently instead of raising "not supported in x64 mode, yet" during InitWizard. `CodeRedirect` similarly gated as a Win64 no-op. 5-byte JMP-rel32 hook installation is not portable to x64 and the features that need it are stubbed out on Win64 anyway.
6. `Code/DDevExtensions/Source/CompileProgress/CompileProgress.pas`: `HookedProjectGroupCompileActive` split into a CPUX86 asm version and a Pascal Win64 fallback.
7. `Code/DDevExtensions/Source/Editor/DocModuleHandler.pas`: Entire implementation gated CPUX86; Win64 receives empty stubs for all interface methods.
8. `Code/DDevExtensions/Source/DSUFeatures/DisableAlphaSortClassCompletion.pas`: Entire implementation gated CPUX86; Win64 no-op stub.
9. `Code/DDevExtensions/Source/DSUFeatures/FrmeOptionPageDSUFeatures.pas`: `SetShowFileProjectInPrjMgr` body gated `{$IFNDEF CPUX64}`.
10. `Code/DDevExtensions/Source/DSUFeatures/StrucViewSearch.pas`: `TIDEVirtualTreeHandler` creation gated `{$IFNDEF CPUX64}` together with its `LTree` var.
11. `Code/DDevExtensions/Source/VirtTreeHandler.pas`: `InitMethods` no longer raises on TreeImport failure on Win64; "FTextGetter." Not Supported errors no longer fire when loading a project in the Win64 IDE.
12. `CompileInterceptor/Source/CompilerHooks.pas`: `InitCompileInterceptor` early-exits on Win64 before the pointer-arithmetic `SetPascalComInOut` patch.
13. `CompileInterceptor/Source/InterceptLoader.pas`: Bitness-aware DLL name — loads `CompileInterceptorWx64.dll` on Win64, `CompileInterceptorW.dll` on Win32.
14. `Code/DDevExtensions/Installer/Main.pas`: Added `ekDelphi130x64` enum, extended `TEnvData` with `ExpertsSubKey` (`'Experts'` vs `'Experts x64'`), `HostExeRelPath` (`bin\bds.exe` vs `bin64\bds.exe`) and `CompInterceptorDll` (per-bitness DLL name). Detection logic locates both 32-bit and 64-bit IDE hosts under the shared `Embarcadero\BDS\37.0` registry root. Full DocInsight XML documentation applied (unit had zero coverage previously).
15. `Shared/ImportHooking.pas`, `Shared/PascalParser/DelphiParserContainers.pas`, `Code/DDevExtensions/Source/FileSelector/FrmFileSelector.pas`: `Items[Index: Integer]` accessors widened to `NativeInt` to silence W1075 on Win64.
16. `Code/DDevExtensions/Source/CompileProgress/CompilerClearOtherStates.pas`: `MemCounters` var wrapped `{$IFNDEF CPUX64}`.
17. Version bumped: `Source/version.inc`, `version.h`, all six `D_Dxxx/DDevExtensions.dproj` files, and `Installer/DDevExtensionsReg.dproj` → 3.16.5.

**Win64 shutdown stability (cascade of "Delphi 13 (64-bit)" AV dialogs):**

After the build-time AV was fixed, the 64-bit IDE produced a cascade of identical "Delphi 13 (64-bit)" Access Violation dialogs at shutdown — one per per-feature unloader, plus a "Runtime error 231" finaliser failure. Bisection via the diagnostic log (item 18 below) identified two root causes in the `CompileProgress` teardown chain:

- **`TCompileProgress.Create` registered the compile-interceptor service inside `{$IFNDEF CPUX64}` but `TCompileProgress.Destroy` called `UnregisterInterceptor` unconditionally.** On Win64 `FCompileInterceptorId` was therefore the default `0`, and `GetCompileInterceptorServices.UnregisterInterceptor(0)` walked a non-existent registration slot → deterministic AV in `rtl370.bpl + 0x1C1DFE` reading `$FFFFFFFFFFFFFFFF`. Gated symmetrically with the register call so both ends are Win64-skipped.
- **`TNativeProgressForm.Destroy` called three property setters (`StatusOverwrite := ''`, `FilesCompiled := 0`, `MaxFiles := 0`) that all route through `GetForm` → `ProgressFormP^`, a dereferenced Pascal pointer to coreide_bpl's `@Comprgrs@ProgressForm` global.** On Win64 shutdown coreide_bpl is being torn down so the dereferenced TForm pointer is dead, and `Form.FindComponent` AVs at the same `rtl370.bpl + 0x1C1DFE` offset. The setters only existed to tidy the IDE's progress UI; on shutdown there is no UI to tidy. Skipped on Win64.

Per-step `try/except` wrappers were also added around the remaining cleanup operations in both destructors as defensive belt-and-braces (any future BPL-teardown race in Win64 shutdown will be caught, logged and swallowed individually rather than aborting the whole destructor).

**Changes Made (continued):**

18. `Code/DDevExtensions/Source/Main.pas`: Added a Win64-only diagnostic infrastructure: `WriteWin64ShutdownLine` writes to `%APPDATA%\DDevExtensions\Win64Shutdown.log` and emits via `OutputDebugString`; public helpers `LogWin64UnloadFailure(LoaderKind, Index, E)` and `LogWin64UnloadStep(StepName, E)` let `UninstallHooks` and individual feature destructors attribute teardown failures. `UninstallHooks`' `LateLoader` / `ExpertLoader` unload loops swap `Application.HandleException(Application)` for `LogWin64UnloadFailure` on Win64 so failures log silently instead of spawning one IDE-owned AV dialog per loop iteration. Every operation in the diagnostic path is itself wrapped in `try/except` because we are already on the exception path during process teardown.
19. `Code/DDevExtensions/Source/CompileProgress/CompileProgress.pas`: `TCompileProgress.Destroy` gates `UnregisterInterceptor` on `{$IFNDEF CPUX64}` to match the register call in `Create`. On Win64 the destructor body is replaced by per-step `try/except` blocks that log via `LogWin64UnloadStep` so any future teardown fault is attributed precisely without aborting the rest of the destructor.
20. `Code/DDevExtensions/Source/CompileProgress/NativeProgressForm.pas`: `TNativeProgressForm.Destroy` skips the three `GetForm`-routing setters on Win64 (`StatusOverwrite`, `FilesCompiled`, `MaxFiles`) and wraps the remaining steps in per-step `try/except` with `LogWin64UnloadStep` diagnostics. `Main` added to the implementation `uses` clause on Win64 for the logger.

**Features inactive on the Win64 IDE host:** Compile Progress hook, Document Module handler, Disable Alphasort Class Completion, Show File Project In Project Manager, Structure View Search filter, all compile / file-notification subscribers (since `TIDENotifier` no longer registers), Compile Interceptor's input-handle redirect, and any callers that depended on `RedirectOrgCall` / `CodeRedirect`. The 32-bit IDE keeps the full feature set unchanged.

**Diagnostic log:** On Win64 only, any uncaught exception during plug-in teardown is appended as a single line to `%APPDATA%\DDevExtensions\Win64Shutdown.log` (and emitted via `OutputDebugString` for live capture in DebugView / DebugView++). A clean shutdown leaves the log unchanged. Format: `<timestamp>  DDevExtensions[Win64]: <kind>[<idx>] unload threw <ExceptionClass>: <Message>` or `<timestamp>  DDevExtensions[Win64]: step <StepName> threw <ExceptionClass>: <Message>`.

**Files Modified:** `Shared/IDE/IDENotifiers.pas`, `Shared/Hooking.pas`, `Shared/ImportHooking.pas`, `Shared/PascalParser/DelphiParserContainers.pas`, `Code/DDevExtensions/D_D130/DDevExtensions.dpr`, `Code/DDevExtensions/D_D130/DDevExtensions.dproj`, `Code/DDevExtensions/Source/Main.pas`, `Code/DDevExtensions/Source/CompileProgress/CompileProgress.pas`, `Code/DDevExtensions/Source/CompileProgress/NativeProgressForm.pas`, `Code/DDevExtensions/Source/CompileProgress/CompilerClearOtherStates.pas`, `Code/DDevExtensions/Source/Editor/DocModuleHandler.pas`, `Code/DDevExtensions/Source/DSUFeatures/DisableAlphaSortClassCompletion.pas`, `Code/DDevExtensions/Source/DSUFeatures/FrmeOptionPageDSUFeatures.pas`, `Code/DDevExtensions/Source/DSUFeatures/StrucViewSearch.pas`, `Code/DDevExtensions/Source/VirtTreeHandler.pas`, `Code/DDevExtensions/Source/FileSelector/FrmFileSelector.pas`, `CompileInterceptor/Source/CompilerHooks.pas`, `CompileInterceptor/Source/InterceptLoader.pas`, `Code/DDevExtensions/Installer/Main.pas`, `Code/DDevExtensions/Source/version.inc`, `Code/DDevExtensions/version.h`, all six `Code/DDevExtensions/D_Dxxx/DDevExtensions.dproj`, `Code/DDevExtensions/Installer/DDevExtensionsReg.dproj`, ~14 additional source files for `delayed` BPL imports, `README.md`, `Help.md`

---

## 2026-04-23 - v3.15.5 - Key Bindings: User-Configurable Section Toggle and Move Line/Block Shortcuts

**Problem:** The "Interface/Implementation Section Toggle" feature (added in v3.4.1) bound itself to **Ctrl+Shift+Up / Ctrl+Shift+Down** with the default state set to on. Those chords are Delphi's long-standing native shortcut for jumping between a routine's declaration and its implementation body, so installing DDevExtensions silently shadowed a core IDE shortcut. A user reported muscle-memory breakage after installing v3.14.5. "Move line/block up/down" similarly hard-coded Ctrl+Shift+Alt+Up/Down, which collides with GExperts.

**Changes Made:**
1. `Source/Keybindings/FrmeOptionPageKeybindings.pas`: Added four `TShortCut` published properties on `TKeybindings` — `SectionToggleUpKey`, `SectionToggleDownKey`, `MoveLineBlockUpKey`, `MoveLineBlockDownKey` — persisted via the existing XML config layer. `BindKeyboard` now registers the user's chosen shortcuts (skipping `scNone`) instead of hard-coded `ShortCut(VK_UP, ...)` constants. `DoKeyBinding` compares `KeyCode` against the property values rather than literals.
2. `Init` defaults changed: `SectionToggle` defaults to **False** (was True); `SectionToggleUpKey`/`DownKey` default to `scNone`. `MoveLineBlockUpKey`/`DownKey` default to the traditional Ctrl+Shift+Alt+Up/Down so existing muscle memory is preserved for the line-mover.
3. `Source/Keybindings/FrmeOptionPageKeybindings.dfm`: Added four `THotKey` editors with labels under the corresponding toggle checkboxes. Neutralised the checkbox captions ("Section toggle on Ctrl+Shift+Up/Down" → "Toggle interface/implementation section"; "Shift+Ctrl+Alt+Up/Down move line/block" → "Move line/block up/down") since the keys are now customisable. Frame grew from 290 to 395 high.
4. Added `chkMoveLineBlockClick` and `chkSectionToggleClick` handlers so the hotkey editors enable/disable in step with their parent checkbox. `cbxActiveClick` also cascades to those rows.
5. Added `ComCtrls` to the uses clause for `THotKey`.
6. Version bumped: `Source/version.inc`, `version.h`, all six `D_Dxxx/DDevExtensions.dproj` files, and `Installer/DDevExtensionsReg.dproj` → 3.15.5 (`VerInfo_MinorVer` 14 → 15, `FileVersion=3.15.5.*`, `ProductVersion=3.15`).

**Migration impact:**
- **New installs:** SectionToggle off by default → no collision with native Ctrl+Shift+Up/Down.
- **Existing installs that had the default SectionToggle=True in XML:** feature stays enabled, but the new `SectionToggleUpKey/DownKey` properties absent from old XML fall back to `Init`'s `scNone`, so no bindings are registered and the native IDE shortcut is restored. Users re-assign in Options if they still want the feature.
- **MoveLineBlock users:** no behaviour change — defaults preserve Ctrl+Shift+Alt+Up/Down.

**Files Modified:** `Code/DDevExtensions/Source/Keybindings/FrmeOptionPageKeybindings.pas`, `Code/DDevExtensions/Source/Keybindings/FrmeOptionPageKeybindings.dfm`, `Code/DDevExtensions/Source/version.inc`, `Code/DDevExtensions/version.h`, `Code/DDevExtensions/D_D102/DDevExtensions.dproj`, `Code/DDevExtensions/D_D103/DDevExtensions.dproj`, `Code/DDevExtensions/D_D104/DDevExtensions.dproj`, `Code/DDevExtensions/D_D110/DDevExtensions.dproj`, `Code/DDevExtensions/D_D120/DDevExtensions.dproj`, `Code/DDevExtensions/D_D130/DDevExtensions.dproj`, `Code/DDevExtensions/Installer/DDevExtensionsReg.dproj`, `README.md`, `Help.md`

---

## 2026-03-27 - Build Config: Map File and EXE Output Standardisation

**Changes Made:** Added `DCC_ExeOutput=..\bin` and `DCC_MapFile=3` to DfmParserTests.dproj (had neither). Added `DCC_ExeOutput=..\bin` to DfmParserTestsDUnitX.dproj (had MapFile but no output path). All 10 .dproj files now consistently have both settings.

**Files Modified:** `DfmParserTests/DfmParserTests.dproj`, `DfmParserTests/DfmParserTestsDUnitX.dproj`

## 2026-03-25 - v3.14.5 - Dependency Viewer: Graphviz DOT Export

**Problem:** The Dependency Viewer provided interactive tree-based exploration and CSV/TXT exports for circular references and layer violations, but had no way to produce a visual graph diagram showing the full dependency structure at a glance.

**Changes Made:**
1. `FrmDependencyViewer.pas`: Added `btnExportGraphClick` handler, `ExportToDOT` method (generates Graphviz DOT format with colour-coded nodes and edges), and `FindGraphvizDot` helper (searches PATH and common install locations for dot.exe).
2. `FrmDependencyViewer.dfm`: Added `btnExportGraph` button (anchored bottom-left in right panel) and `SaveDialogGraph` component for DOT file save.

**Features:**
- "Export Graph..." button only visible when Graphviz `dot.exe` is detected (common install paths and system PATH)
- Project units shown as light green nodes, external/RTL units as light blue
- Interface uses rendered as solid blue edges, implementation uses as dashed green edges
- Units involved in circular references highlighted with red border
- Auto-invokes Graphviz `dot.exe` to render PNG, then opens the image
- Includes a legend subgraph explaining the visual conventions

**Prerequisite:** Graphviz must be installed — download from https://graphviz.org/download/

**Result:** Users can now export a complete visual dependency graph from the Dependency Viewer as a PNG image.

**Files Modified:** Source/DependencyViewer/FrmDependencyViewer.pas, Source/DependencyViewer/FrmDependencyViewer.dfm

---

## 2026-03-25 - v3.13.5 - External Mod Monitor: Project Load Grace Period

**Problem:** When a project group is loaded in RAD Studio, the IDE normalises/rewrites .dproj files. The External Mod Monitor detected these IDE-initiated writes and showed spurious "Files Refreshed" balloon notifications.

**Changes Made:**
1. `ExternalModMonitor.pas`: Added `FProjectLoadGraceMs` (default 3000ms) and `FGraceUntilTick` fields. `StartWatchingProject` bumps the grace deadline on every project open. `HandleFileChanged` and `HandleDebounceTimer` discard events arriving within the grace period.
2. `FrmeOptionPageExternalModMonitor.pas`: Added load/save/enable logic for the new "Load grace period (ms):" setting (minimum 500ms).
3. `FrmeOptionPageExternalModMonitor.dfm`: Added label and edit for the grace period; shifted extensions and notification controls down.

**Result:** File change events arriving within the configurable grace period after project load are silently discarded, eliminating spurious notifications during project group loading.

**Files Modified:** Source/ExternalModMonitor/ExternalModMonitor.pas, Source/ExternalModMonitor/FrmeOptionPageExternalModMonitor.pas, Source/ExternalModMonitor/FrmeOptionPageExternalModMonitor.dfm

---

## 2026-03-24 - v3.13.4 - External Mod Monitor: Windows Balloon Notifications

**Problem:** When the External Mod Monitor silently refreshed externally modified files, there was no visual feedback to the user about which files had been updated.

**Changes Made:**
1. `Source/ExternalModMonitor/ExternalModMonitor.pas`:
   - Added `ShowNotifications` published property (default: True)
   - Added `ShowBalloonNotification()` — uses `Shell_NotifyIcon` with `NIF_INFO` to display a Windows balloon tip listing refreshed filenames (max 5, then "... and N more")
   - Added `HandleNotifyCleanup()` — timer-based cleanup removes the tray icon after 8 seconds
   - Updated `HandleDebounceTimer()` to track successfully refreshed files and trigger notification
   - Added `ShellAPI` and `Forms` to uses clauses
2. `Source/ExternalModMonitor/FrmeOptionPageExternalModMonitor.pas`: Added load/save/enable logic for the new checkbox
3. `Source/ExternalModMonitor/FrmeOptionPageExternalModMonitor.dfm`: Added "Show notification on refresh" checkbox

**Result:** A Windows balloon notification now appears listing each refreshed filename when external changes are detected and applied. Configurable via the Options page.

**Files Modified:** Source/ExternalModMonitor/ExternalModMonitor.pas, Source/ExternalModMonitor/FrmeOptionPageExternalModMonitor.pas, Source/ExternalModMonitor/FrmeOptionPageExternalModMonitor.dfm

---

## 2026-03-24 - v3.13.4 - IDE Path Sorter: Platform Category Filter Checkboxes

**Problem:** When many platforms are installed (Win32, Win64, Android, iOS, macOS, ARM, Linux, etc.), the Platform dropdown in the IDE Path Sorter shows all of them in a flat list, making it harder to find the desired platform.

**Changes Made:**
1. `Source/LibraryPathSorter/FrmLibraryPathSorter.dfm`: Added `pnlPlatformFilter` panel and `lblPlatformFilter` label to `pnlTop`; increased panel height from 70 to 95; moved caution label down to accommodate filter row
2. `Source/LibraryPathSorter/FrmLibraryPathSorter.pas`:
   - Added `FAllPlatforms`, `FPlatformCategories`, `FPlatformCheckboxes` fields
   - Added `CategorizePlatform()` — maps platform names to categories (Windows, Android, iOS, macOS, ARM, Linux, Other) by prefix/content matching
   - Added `BuildPlatformCategories()` — groups installed platforms into categories
   - Added `CreatePlatformCheckboxes()` — dynamically creates checkboxes for each category that has installed platforms; loads saved checked state from registry
   - Added `FilterPlatformDropdown()` — rebuilds the Platform dropdown showing only platforms from checked categories; falls back to all platforms if none checked
   - Added `PlatformCheckboxClick()` — triggers dropdown filtering on checkbox change
   - Updated `SaveFormSettings()` to persist checkbox states as `PlatformFilter_<Category>` registry values
   - Updated `FormCreate()` / `FormClose()` to initialise/free new objects

**Result:** Only categories with installed platforms appear as checkboxes. Unchecking a category hides its platforms from the dropdown. Checkbox states persist across sessions via the registry. Safety fallback shows all platforms if no checkboxes are checked.

**Files Modified:** Source/LibraryPathSorter/FrmLibraryPathSorter.pas, Source/LibraryPathSorter/FrmLibraryPathSorter.dfm

---

## 2026-03-23 - v3.12.4 - Fix External Mod Monitor not detecting .dpr file changes

**Problem:** The External Mod Monitor did not refresh `.dpr` files when modified externally. The `.dpr` extension was missing from the default `MonitoredExtensions` list, so file changes were detected by the watcher but silently discarded by the extension filter. Additionally, `FileWatcher.pas` stored directory keys as `UpperCase(...)`, which mangled the path case flowing through to `IOTAModuleServices.FindModule` — an unnecessary risk even though Windows paths are case-insensitive.

**Changes Made:**
1. `Source/ExternalModMonitor/ExternalModMonitor.pas` line 143: Added `.dpr` to default `MonitoredExtensions` (`.pas;.inc;.dfm;.dpr;.dproj;.dpk`)
2. `Shared/FileWatcher.pas` constructor: Changed dictionary to use `TIStringComparer.Ordinal` for case-insensitive key matching
3. `Shared/FileWatcher.pas` AddWatch/RemoveWatch: Removed `UpperCase()` calls — directory paths now preserve their original case

**Result:** `.dpr` files are now monitored and auto-refreshed like other project files. Directory paths passed to `FindOpenModule` retain their original case, eliminating any risk of OTA lookup mismatches.

**Files Modified:** Source/ExternalModMonitor/ExternalModMonitor.pas, Shared/FileWatcher.pas, Source/version.inc, all .dproj files (D_D102–D_D130 + Installer)

---

## 2026-03-23 - v3.12.4 - Add External Mod Monitor (real-time file change detection)

**Problem:** The Delphi IDE only detects external file modifications when it regains focus (Alt-Tab away and back). When using external tools (AI assistants, version control, other editors) that modify project files while the IDE is active, changes go undetected. The VSoft.ExternalModDetector plugin solves this but requires an external FileSystemMonitor dependency, which is undesirable for a public repository.

**Changes Made:**
1. `Shared/FileWatcher.pas`: New unit — self-contained `ReadDirectoryChangesW` wrapper using overlapped I/O. Background thread with reference-counted directory watches, main-thread notification via `TThread.Queue`. Zero external dependencies.
2. `Source/ExternalModMonitor/ExternalModMonitor.pas`: New feature plugin — `TExternalModMonitorConfig` (inherits `TPluginConfig`). Uses `TIDENotifier` for project open/close events and compile suppression. Debounced (200ms) silent auto-refresh via `IOTAModule.Refresh(False)`. Skips files with unsaved editor changes.
3. `Source/ExternalModMonitor/FrmeOptionPageExternalModMonitor.pas` + `.dfm`: New options page — Active checkbox, debounce interval (ms), monitored extensions field.
4. `Source/DelphiExtension.inc`: Added `{$DEFINE INCLUDE_EXTERNALMODMONITOR}`
5. `Source/RegisterPlugins.pas`: Added uses clause and `RegisterLateLoader` call for `ExternalModMonitor.InitPlugin`
6. All version-specific `.dpr` files (D_D102–D_D130): Added `FileWatcher`, `ExternalModMonitor`, `FrmeOptionPageExternalModMonitor` to uses clause
7. All version-specific `.dproj` files (D_D102–D_D130) + Installer: Added three `DCCReference` entries for the new units; updated `VerInfo_MinorVer`, `FileVersion`, and `ProductVersion` to 3.12.3

**Result:** Project directories are monitored in real-time. Externally modified files are silently refreshed within ~200ms. Monitoring is suppressed during compilation. Files with unsaved editor changes are never overwritten. Feature is enabled by default and can be toggled via Tools > DDevExtensions > Options > External Mod Monitor.

**Files Created:** Shared/FileWatcher.pas, Source/ExternalModMonitor/ExternalModMonitor.pas, Source/ExternalModMonitor/FrmeOptionPageExternalModMonitor.pas, Source/ExternalModMonitor/FrmeOptionPageExternalModMonitor.dfm
**Files Modified:** Source/DelphiExtension.inc, Source/RegisterPlugins.pas, Source/version.inc, D_D102–D_D130/DDevExtensions.dpr, D_D102–D_D130/DDevExtensions.dproj, Installer/DDevExtensionsReg.dproj

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


## [Unreleased]

### Added
- `.gitattributes` — pin CRLF checkout for all text file types, independent of each clone's `core.autocrlf`; binaries marked explicitly, Pascal linguist hints included. (2026-07-28) — `.gitattributes`
