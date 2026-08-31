# DDevExtensions — Library Path Compactor

**Implementation brief for Claude Code**
Repo: `D:\DDevExtensions` · Feature root: `Code\DDevExtensions\Source\PathCompactor\`
Written against the actual fork as at 2026-08-30. File and line references below are real — check them before designing anything.

**Revised 2026-08-31** after verification against the working tree: corrected the `ExpandDirMacros` failure
mode in §4, added the platform/config-token naming guard in §6.5 (plus test 11), added the mandatory IDE
bitness handling in §8.1, defaulted the `HKCU\Environment` write off in §8.2, resolved open question §13.2,
and added the options-page commit case to §9. Also moved the `TLibraryPathTypeHelper` requirement into §6.1
and recorded in §11 that `D_D102` cannot compile, so the six-DPR registration implies no language constraint.

**Verified against the live machine 2026-08-31.** Every file, line number and registry claim in this
document was checked against the working tree and against `HKCU\Software\Embarcadero\BDS\37.0`.
That pass corrected §6.4 (the saving was being scored in expanded space, which on this machine would
have *lengthened* 104 already-macro'd entries while reporting a 3,640-character win), falsified §7.1's
`CatalogRepository` premise and added the junction exclusion list, added the §2.1 menu-insertion
ordering fix, §9's junction/Apply sequencing, the reference-checked variable removal, the core-level
refusal of `lptNamespacePrefixes`, the undefined-macro hygiene category, and the §5 path-root note.
Measured baseline: 13 platforms, 96 non-empty path sets, 917 entries, 0 duplicates, 19 missing
directories, 17 unresolved macros. On that evidence §6.7's duplicate *removal* was demoted to opt-in
while its *detection* was widened to every path set.

---

## 1. Goal

Shorten RAD Studio's per-platform library path strings by:

1. Substituting `$(NAME)` macros for repeated directory prefixes.
2. Optionally replacing over-long physical prefixes (the GetIt catalogue above all) with directory junctions.
3. Removing duplicate and dead entries.

Variables are written to the IDE's macro-override keys — **both** `Environment Variables` and `Environment Variables x64`, because the library path is shared between the two IDE bitnesses while those lists are not (§8.1). Writing them to `HKCU\Environment` as well is an optional extra, **off by default**: command-line MSBuild does not read the IDE library path at all (§8.2, §13.2).

---

## 2. What already exists in this fork — read before writing anything

The fork already contains most of the plumbing. **Reuse it; do not build a parallel stack.**

| Asset | Location | Reuse as |
|---|---|---|
| `TLibraryPathHandler` — read/write per-platform path values, platform enumeration | `Source\LibraryPathSorter\LibraryPathSorter.pas` | The registry layer. Do not write a new one. |
| `TLibraryPathBackupManager` — versioned XML snapshots per (PathType, Platform), max 10, restore/delete | same unit | The entire backup/undo story. **No `.reg` export is needed.** |
| `TLibraryPathType` — 10 path-value kinds with `ToRegistryValueName` / `ToDisplayName` helpers | same unit | The path-kind enum. Do not redefine. |
| `TFormLibraryPathSorter` — Original/Working two-pane editor, platform + path-type pickers, backup history, Apply with verification | `Source\LibraryPathSorter\FrmLibraryPathSorter.pas` (1,828 lines) | Sibling dialog and UI precedent. |
| `TPluginConfig` + `InitPlugin( Unload: Boolean )` + `RegisterLateLoader` | `Source\PluginConfig.pas`, `Source\RegisterPlugins.pas` | The registration pattern. |
| `ProjectGroupSorterCore` — RTL-only core extracted for testability, with a DUnitX fixture | `Source\ProjectGroupSorter\` + `DDevExtUnitTests\TestProjectGroupSorterDUnitX.pas` | **The precedent to copy**: pure core unit + IDE shell + DUnitX fixture. |
| `SplitPaths`, `RegReadStringDef`, `RegWriteString`, `ExpandDirMacros` | `Shared\IDE\IDEUtils.pas` | Helpers — but see the defect in §4. |

### 2.1 Revision to an earlier decision

The feature was originally scoped as "a new page in the DDevExtensions options dialog". **Recommend changing this to a Tools-menu dialog**, for two reasons grounded in the code:

- Compaction analysis is inherently **cross-scope** — it has to see every platform × path-type at once to find shared prefixes. The `FrmeOptionPage*` frames are settings pages; the sorter dialog is the established home for library-path work, and it already owns platform/path-type selection, backups and Apply.
- It gives the user a natural pairing: **Tools ▸ IDE Path Sorter…** (reorder, dedupe, validate) and **Tools ▸ IDE Path Compactor…** (shorten). Same backup history, same handler.

Proposed menu insertion: immediately after `IDE Path &Sorter...`. If Ian prefers the options page after all, only §9 changes.

**Do not copy the sorter's insertion code verbatim — it will place the compactor in the wrong position.** `TLibraryPathSorterPlugin.Create` scans the Tools menu for the first caption containing `'Build'` and inserts at that index + 1. A second plugin doing the same thing inserts at the *same* index, so whichever `RegisterLateLoader` runs last ends up **above** the other, and the resulting order depends on registration order rather than intent. Search for the sorter's own caption first and fall back to the `'Build'` scan only when it is absent — it legitimately can be, since the sorter is skippable through `DDevExtensions.DisabledFeatures`:

```pascal
// Prefer to sit directly beneath the sorter; fall back to the Build item when the sorter is disabled.
InsertIndex := -1;
for I := 0 to ToolsMenu.Count - 1 do
  if Pos( 'IDE Path &Sorter', ToolsMenu.Items[I].Caption ) > 0 then
  begin
    InsertIndex := I + 1;
    Break;
  end;
if InsertIndex < 0 then
  for I := 0 to ToolsMenu.Count - 1 do
    if Pos( 'Build', ToolsMenu.Items[I].Caption ) > 0 then
    begin
      InsertIndex := I + 1;
      Break;
    end;
```

### 2.2 Code style — important correction

This codebase does **not** follow the GITLAK variable-prefix convention. It uses Hausladen-era naming (`Reg`, `PathList`, `I`, `Backup`, `Result`) with XMLDoc `/// <summary>` on every public member. Newer Ian/Claude additions use `( content )` bracket spacing but keep that naming. **Match the surrounding files, not the GITLAK standard** — a `PathCompactor` written with `oList`/`sPath`/`bDrop` prefixes would be the only unit in the project that looks like that.

---

## 3. Two different limits — why the UI reports two numbers

| Limit | Measured on | Macros help? | Junctions help? |
|---|---|---|---|
| **Stored length** — the IDE's "path too long" warning, GetIt installer complaints | the raw registry string, macros unexpanded | **Yes** | Yes |
| **Expanded length** — the `dcc32`/`dcc64` command line, shared with every other argument | the fully expanded string | **No** | **Yes** |

A user hitting the second limit gains nothing from substitution alone. Report both, before and after, per platform × path-type, so the diagnosis is visible rather than guessed.

The IDE's warning threshold is undocumented. Do not hard-code a guess — expose `WarnStoredLength` in the plugin config (default 2048) so Ian can set it to whatever length his IDE actually complained at.

---

## 4. Blocking defect: `ExpandDirMacros` is not fit for this purpose

`IDEUtils.ExpandDirMacros` (`Shared\IDE\IDEUtils.pas:1874`) cannot be relied on. Inspect it and confirm:

1. **It does not read the IDE's `Environment Variables` override key at all — and an unknown macro is *deleted*, not left intact.** `NewS` stays empty and the closing `Delete`/`Insert` pair substitutes nothing, so `$(BDSCatalogRepository)\Foo` comes back as `\Foo`. Every user-defined IDE variable — including every variable this feature creates — is silently erased from the path rather than surviving as an unresolved macro.
2. **Missing built-ins.** It handles `BDS`/`BCB`/`DELPHI`, `BDSPROJECTSDIR`, `PLATFORM`, `CONFIG` only. `BDSCOMMONDIR` is present but **commented out** (line ~1922); `BDSCATALOGREPOSITORY`, `BDSUSERDIR`, `BDSLIB` and `BDSINCLUDE` are absent. The GetIt catalogue macro — the single most important prefix for this feature — does not resolve.
3. **Process environment wins over built-ins.** `GetEnvironmentVariable( S )` is consulted *first*. A user environment variable named `BDS` would silently shadow the IDE's own. This constrains §7.
4. **`$(PLATFORM)` resolves from the active project**, not from the registry key being examined — wrong for library-path analysis. `TFormLibraryPathSorter.ExpandPathMacros` (line ~806) already works around this by substituting the combo-box platform before delegating.

**Consequence for the existing sorter, worth mentioning in the PR.** Because unknown macros are deleted rather than preserved, the `Pos( '$(', ExpandedPath ) > 0` guard in `IsPathValid` (`FrmLibraryPathSorter.pas:845`) never fires for them. `$(BDSCatalogRepository)\Foo` reaches `DirectoryExists` as `\Foo`, which fails — so those entries are flagged **invalid (blue)** in both panes today. The defect is a false *invalid*, not a silent pass: the sorter is over-reporting, not under-reporting. Verified 2026-08-31 against `IDEUtils.pas:1874` and `FrmLibraryPathSorter.pas:823`.

**Decision:** implement a self-contained expander in the new pure core unit, taking a caller-supplied macro table. Do not modify `ExpandDirMacros` in this change — it is shared by several features and altering its precedence is a separate, riskier commit. Raise it as a follow-up.

---

## 5. Unit plan

Paths below use **three different roots**, which the original brief did not distinguish and which
will misdirect an implementer. `Source` and `Installer` are relative to `Code\DDevExtensions`;
`Shared\IDE` and `DDevExtUnitTests` are relative to the **repository root** `D:\DDevExtensions`.
Verified 2026-08-31.

```
Code\DDevExtensions\Source\PathCompactor\
  PathCompactorCore.pas        RTL-only. Expander, candidate analysis, rewrite, hygiene. No ToolsAPI, no VCL, no Registry.
  PathCompactor.pas            TPluginConfig descendant, Tools menu item, InitPlugin. Owns the macro-table builder.
  PathCompactorJunctions.pas   Junction detection/creation with elevation fallback. Winapi only.
  PathCompactorEnvVars.pas     IDE override key + HKCU\Environment + WM_SETTINGCHANGE.
  FrmPathCompactor.pas/.dfm    The dialog (TFormBase descendant, mirroring FrmLibraryPathSorter).
DDevExtUnitTests\                (repository root, not Code\DDevExtensions)
  TestPathCompactorDUnitX.pas  Fixture against PathCompactorCore.
```

`PathCompactorCore` must compile in a standalone console `dcc64` harness with no IDE present — that is what makes the interesting logic testable, exactly as `ProjectGroupSorterCore` does.

---

## 6. Core (`PathCompactorCore.pas`)

### 6.1 Types

```pascal
type
  /// <summary>One entry from a semicolon-separated path value, with its analysis state.</summary>
  TPathEntry = record
    /// <summary>Exactly as stored in the registry, macros intact.</summary>
    Raw: string;
    /// <summary>Fully expanded and normalised: absolute, no trailing separator.</summary>
    Expanded: string;
    /// <summary>Contains a build-time macro; never rewritten, never deduplicated.</summary>
    Opaque: Boolean;
    /// <summary>Directory present on disc. False also when existence cannot be determined.</summary>
    Exists: Boolean;
    /// <summary>An earlier entry in the same set expands to the same path.</summary>
    Duplicate: Boolean;
    /// <summary>Proposed replacement for Raw; empty means unchanged.</summary>
    NewRaw: string;
    /// <summary>Proposed for removal (duplicate or missing).</summary>
    Drop: Boolean;
  end;

  /// <summary>A candidate directory prefix that could be replaced by a $(NAME) macro.</summary>
  TVarCandidate = record
    Name: string;           // without the $( )
    Prefix: string;         // expanded prefix, no trailing separator
    Occurrences: Integer;
    NetSaving: Integer;     // characters removed from stored length across the whole scope
    Accepted: Boolean;
    PreExisting: Boolean;   // an IDE variable of this name already holds exactly this value
  end;
```

`TLibraryPathType` and the registry value names come from `LibraryPathSorter.pas` — but the core must not `uses` that unit (it pulls in ToolsAPI). Pass the path-type as a plain string label, or move the enum into the core and have `LibraryPathSorter` alias it. **Prefer the alias**: it removes a duplicate definition rather than adding one.

**Move the record helper with the enum — do not leave it behind.** `TLibraryPathTypeHelper` is a `record helper for TLibraryPathType` declared in `LibraryPathSorter.pas`, and it carries `ToRegistryValueName` / `ToDisplayName`. Two consequences, both silent if missed:

- If the enum moves to the core and the helper does not, the core cannot call `ToRegistryValueName` — it would have to re-derive the value names, reintroducing exactly the duplication the alias was meant to remove.
- Declaring a *second* helper in the core for the same type does not merge with the first. Delphi resolves only **one** helper per type, the last one in scope, so whichever unit is later in the `uses` clause silently wins and the other's methods vanish with no error. That is a genuinely hard bug to see.

So: move `TLibraryPathType` **and** `TLibraryPathTypeHelper` into `PathCompactorCore`, and in `LibraryPathSorter` alias both —

```pascal
type
  /// <summary>Alias of the canonical declaration in PathCompactorCore; kept for source compatibility.</summary>
  TLibraryPathType = PathCompactorCore.TLibraryPathType;
  TLibraryPathTypeHelper = PathCompactorCore.TLibraryPathTypeHelper;
```

— then confirm `lptSearchPath.ToRegistryValueName` still resolves from `FrmLibraryPathSorter`, which is the unit that would break first. Neither the enum nor the helper has any ToolsAPI dependency, so both are core-clean.

**Exclude `lptNamespacePrefixes` from every code path.** It is a list of unit-scope prefixes, not directories; feeding it to the compactor would corrupt it. Enforce this in the **core**, by raising, not merely by omitting it from the dialog (§10). The dialog is not the only caller: §7.3 and §9 both persist configuration that could name a path type, and a stale or hand-edited config must not be able to reach the compactor with this value. Covered by test 14.

### 6.2 Expander

Signature keeps the core pure — the IDE shell builds the table:

```pascal
/// <summary>
/// Expands $(NAME) macros in APath using AMacros (Name=Value, case-insensitive).
/// Unknown macros are left intact and terminate the pass. Cycles are broken by MaxDepth.
/// </summary>
function ExpandLibraryMacros( const APath: string; AMacros: TStrings; AMaxDepth: Integer = 16 ): string;
```

Table precedence, built by `PathCompactor.pas` and passed in — first wins:

1. The IDE's user overrides — `<BaseRegistryKey>\Environment Variables` **or** `<BaseRegistryKey>\Environment Variables x64`, selected by the bitness of the host IDE. See §8.1; this is not optional.
2. IDE built-ins: `BDS`, `BDSINCLUDE`, `BDSLIB`, `BDSCOMMONDIR`, `BDSUSERDIR`, `BDSCatalogRepository`, `BDSCatalogRepositoryAllUsers`, `BDSPROJECTSDIR`, `ProgramFiles`, `ProgramFiles(x86)`.
3. The process environment.
4. `PLATFORM` → **the platform of the registry key being read**, not the active project.

`CONFIG` is deliberately absent from the table. Any entry whose raw text contains `$(Config)` — or `$(Platform)` unless `BakePlatformMacro` is on (default **off**) — is marked `Opaque`: passed through byte-for-byte, excluded from candidate generation and from duplicate detection.

Normalise after expansion with `TPath.GetFullPath` to resolve `..`, then strip a trailing separator — but never from a bare drive root (`D:\`).

### 6.3 Candidate generation

For every non-opaque entry, walk its **ancestor directories only** (not the entry itself — a prefix used once saves nothing worth a variable) and tally occurrences across every path set in scope. Reject candidates that are a bare drive root or shorter than 8 characters.

Walking ancestors gives segment-boundary alignment for free, which is what stops `D:\Lib` from matching `D:\Library\Foo`. Apply the same boundary rule at rewrite time.

### 6.4 Scoring and selection

A variable costs `Length( Name ) + 3` characters per use; defining it costs nothing in the path string.

**Score against the STORED form, never the expanded one.** This is the single easiest way to get this feature exactly backwards, and the naive formula —

```
NetSaving = Occurrences * ( Length( Prefix ) - ( Length( Name ) + 3 ) )   // WRONG
```

— does get it backwards, because `Prefix` here is the *expanded* prefix while the limit being optimised is the *stored* string (§3). Candidates are necessarily generated from expanded ancestors (§6.3), so that a prefix can be matched across entries written in different forms; but an entry that is **already stored as a macro** has a stored prefix only a few characters long, and re-expressing it under a new variable makes it **longer**.

Measured on the target machine 2026-08-31, this is not hypothetical — it is the dominant case. `C:\Program Files (x86)\Embarcadero\Studio\37.0` is an ancestor of **104** of the 363 entries, and the naive formula ranks it first with a reported saving of about 3,640 characters. But **all 104 of those entries are already stored as `$(BDS)\…`**. Accepting that candidate would rewrite `$(BDS)\source\rtl\common` (24 stored characters) into `$(STUDIO37)\source\rtl\common` (29), *adding* five characters per entry while the UI reported a four-figure win. The tool would make the problem worse and say it had fixed it.

Score per matching entry, in stored space:

```
NetSaving = Σ over matched entries i of ( StoredPrefixLen( i ) − ( Length( Name ) + 3 ) )
```

where `StoredPrefixLen( i )` is the length of the **raw text in entry i** that the accepted prefix would replace — 6 for an entry stored as `$(BDS)\…`, 46 for one stored as a literal absolute path. A candidate matching only already-macro'd entries therefore scores negative and is correctly rejected. `IncrementalSaving` applies the same rule against the state so far.

**Corollary — prefer an existing macro to a new one.** Where a candidate prefix equals the value of an IDE **built-in** (`$(BDS)`, `$(BDSCOMMONDIR)`, `$(BDSCatalogRepository)`, …), rewrite literal entries to that built-in rather than defining a new variable. §6.5's `PreExisting` reuse rule currently covers only variables in the `Environment Variables` key; extend it to the built-in table, which is where the genuine wins on a real machine come from.

Ranking once and taking the top N is **wrong**, because prefixes nest — accepting `D:\Libs` changes what `D:\Libs\TMS` is still worth. Recompute after each acceptance and score the *incremental* gain against the state so far:

```pascal
procedure TPathCompactorAnalysis.SelectVariables;
var
  Best, BestGain, Gain, I: Integer;
begin
  while Length( FAccepted ) < MaxVariables do
  begin
    Best := -1;
    BestGain := 0;

    for I := 0 to High( FCandidates ) do
    begin
      Gain := IncrementalSaving( FCandidates[I] );
      if Gain > BestGain then
      begin
        BestGain := Gain;
        Best := I;
      end;
    end;

    if ( Best < 0 ) or ( BestGain < MinNetSaving ) then
      Break;

    AcceptCandidate( Best );
  end;
end;
```

`IncrementalSaving` walks every entry the candidate matches, determines which accepted prefix (if any) currently applies to that entry, and counts the gain only where the candidate is **longer** than the prefix already applying. Already-accepted candidates return zero. Defaults: `MaxVariables = 12`, `MinOccurrences = 2`, `MinNetSaving = 40`.

### 6.5 Naming

Derive from the prefix's last segment: uppercase, non-alphanumerics to `_`, ensure a leading letter, cap at 16 characters. Suffix `_2`, `_3`… on collision with an already-accepted candidate, an IDE built-in name, or an existing IDE variable holding a *different* value.

**Platform and config tokens must never become variable names.** The library path on a real machine is full of platform-split output folders — `…\Dcp\Win32`, `…\Bpl\Win64`, `…\Win64\Release` — and the last-segment rule would derive `WIN32`, `WIN64`, `RELEASE` or `DEBUG` from them. None of those collides with an IDE built-in, and none need exist in the process environment, so no rule above rejects them; yet `$(WIN32)` sitting beside `$(Platform)` in a library path is actively misleading and invites exactly the confusion the `Opaque` rule exists to prevent. When the last segment case-insensitively matches a platform token (`Win32`, `Win64`, `Win64x`, `WinArm64EC`, `Android32`, `Android64`, `iOSDevice64`, `iOSSimARM64`, `iOSSimulator`, `Linux64`, `OSX64`, `OSXARM64`) or a config token (`Debug`, `Release`), derive from the last **two** segments instead — `DCP_WIN32`, `BPL_WIN64`. Recurse while the newly-leading segment is itself a token.

Where an existing IDE variable already holds exactly the candidate prefix, reuse it and set `PreExisting := True` — offer the substitution without redefining anything.

**Hard refusal:** never propose a name that collides with an IDE built-in or with an existing process environment variable. Per §4.3, `ExpandDirMacros` consults the process environment first, so shadowing `BDS` would break path resolution across the whole IDE.

### 6.6 Rewrite and joining

Apply the **longest accepted prefix first**, so `$(GITLAKTHIRD)` is not pre-empted by `$(GITLAK)`. Compare case-insensitively and require the match to end at a segment boundary.

Build the rewritten entry from the *expanded* path with the prefix replaced. This normalises the remainder — intentional, and visible in the preview pane. Opaque entries are exempt.

**Join with a plain `;` and no quoting.** Follow `TLibraryPathHandler.SortPaths`, which does exactly this and carries the comment *"Delphi's native format does NOT use quotes"*. Do **not** use `IDEUtils.ConcatPaths` — it adds quotes where it thinks they are necessary, which the IDE does not want here. `SplitPaths` (which strips quotes) is fine for the read side.

Copy `SortPaths`' count-verification guard: assert the output entry count equals input minus intentional drops, and raise if not. Losing a library path silently is the worst failure mode this feature has.

### 6.7 Hygiene

- **Duplicates — detect always, remove only on request.** Compare expanded, normalised paths case-insensitively, **within one path set only**. Keep the first, flag the rest. Never deduplicate opaque entries. **Removal is opt-in and unticked by default**, exactly as for missing directories below.

  *This supersedes the sorter's own check, which is strictly weaker.* `TFormLibraryPathSorter.IsDuplicatePath` (`FrmLibraryPathSorter.pas:705`) does a raw `SameText` on the trimmed entry, so it cannot see `$(BDS)\source` and the equivalent literal path as one directory, nor `D:\X` and `D:\X\`, nor anything reached through `..`. It colours duplicates red in the Working pane and offers no way to remove them — the unit header's claim that the dialog can "deduplicate" is aspirational. The compactor's check is a genuine improvement; its *cleaner* is the part that needs justifying.

  *Why report-only is the right default.* Measured across the entire Library key on 2026-08-31 — **13 platforms, 96 non-empty path sets, 917 entries** — there are **zero** duplicates by either the raw test or the expanded-and-normalised one, independently sanity-checked. Defaulting a destructive mutation ON, to fix something that does not occur, inverts the risk balance the missing-directories rule below already gets right. Duplicates *do* arise in practice — GetIt reinstalls and component-pack installers append without checking — so the **detection** earns a permanent place as a standing report; the **removal** does not earn a default.

  *Scope the two halves differently.* Detection is one dictionary pass over data the analysis has already expanded and normalised, so run it across **all** non-empty path sets on every analyse, not merely the path types selected in §10 — that is what catches a regression the day it appears. Removal stays confined to the platforms and path types the user actually selected.
- **Missing directories**: flag but default to *not* removing. Platform-conditional folders are legitimately absent, and a folder on a disconnected share is not dead. Removal is a separately ticked action.
- **Undefined macro references**: a third category the original brief did not have. An entry whose macro resolves in *neither* IDE variable list, the built-in table, nor the process environment is dead in a way `Opaque` does not describe — it is not "deferred to build time", it simply does not exist. Measured on the target machine, `$(RVMediaVCL)` is referenced by four entries and is defined nowhere. Report these prominently; never auto-remove them, because the variable may belong to a component pack that is merely uninstalled at the moment.

---

## 7. Junctions (`PathCompactorJunctions.pas`)

### 7.1 Detection

Offer a junction where an expanded prefix exceeds 40 characters, occurs at least 3 times, and sits under the user profile or Program Files. Default link `C:\CR`, user-editable.

**The stated premise does not hold — check before building the detection around it.** The brief originally assumed the target would nearly always be `…\Documents\Embarcadero\Studio\<ver>\CatalogRepository`. Measured on the target machine 2026-08-31, the per-user `CatalogRepository` appears **zero** times across all six Win32/Win64 path sets, and `$(BDSCatalogRepositoryAllUsers)` appears once, already macro'd. Applying §7.1's thresholds to the real data returns a completely different top hit: `C:\Program Files (x86)\Embarcadero\Studio\37.0` (104 uses) and its `\source` subtree (96 uses), followed by `C:\Program Files (x86)\Neos Eureka S.r.l\EurekaLog 7` (12 uses).

That makes an exclusion list mandatory, because the rule as written would propose junctioning **the IDE's own installation directory**:

- **Never offer** the IDE installation root or anything beneath it (`$(BDS)`), any Windows system directory, or the root of `Program Files` / `Program Files (x86)` themselves. A junction there is not a path-shortening trick; it is a machine-wide change to where RAD Studio lives, and GetIt, the installer and every repair operation write through the original path.
- **Do offer** third-party library trees under `Program Files` that the IDE does not own — the EurekaLog case above is the genuine candidate here.
- Rank junction candidates by **expanded** characters saved, since that is the only limit they address (§3). Unlike §6.4's macro scoring, expanded length *is* the right measure for a junction.

Note the asymmetry with §6.4's `MinOccurrences = 2`: junctions use a higher bar (3) because each one is a permanent, machine-global side effect, where an unused variable is merely clutter. Keep the two thresholds separate and say so in the dialog.

### 7.2 Creation

A directory junction needs no administrator right in itself, but write access to the parent does — and `C:\` normally does not grant it. Attempt unelevated first, escalate only on failure:

```pascal
function CreateJunction( const ALinkPath, ASourcePath: string; out AError: string ): Boolean;
begin
  AError := '';

  if not TDirectory.Exists( ASourcePath ) then
  begin
    AError := 'Source directory does not exist: ' + ASourcePath;
    Exit( False );
  end;

  if TDirectory.Exists( ALinkPath ) then
  begin
    Result := IsJunctionTo( ALinkPath, ASourcePath );
    if not Result then
      AError := 'A directory already exists at ' + ALinkPath + ' and is not a junction to the expected target.';
    Exit;
  end;

  Result := RunMkLink( ALinkPath, ASourcePath, False, AError );
  if not Result then
    Result := RunMkLink( ALinkPath, ASourcePath, True, AError );   // retry elevated
end;
```

`RunMkLink` builds `cmd.exe /c mklink /J "<link>" "<source>"`. Unelevated: `CreateProcess`, `SW_HIDE`, wait, check exit code. Elevated: `ShellExecuteEx` with `lpVerb = 'runas'`, wait on `hProcess`. A cancelled UAC prompt returns `ERROR_CANCELLED` (1223) — report that as "cancelled", not as an error.

`IsJunctionTo` checks `FILE_ATTRIBUTE_REPARSE_POINT`, then opens with `FILE_FLAG_BACKUP_SEMANTICS` and compares `GetFinalPathNameByHandle` against the source.

**64-bit cleanliness**: this unit must compile for both design-time targets. Use `NativeUInt`/`LPARAM`, no `Integer(Pointer)` casts.

### 7.3 Health check

Record every junction created in the plugin's config XML. Verify each on plugin load; if one has gone, show a non-modal warning. A deleted junction silently breaks every path depending on it, and the resulting compile errors give no clue why.

---

## 8. Environment variables (`PathCompactorEnvVars.pas`)

For each accepted, non-pre-existing variable, write the IDE override keys. Writing `HKCU\Environment` as well is a **separate, opt-in action — default off** (see §8.2):

```pascal
// Both IDE lists, always - the path they resolve is shared between the two IDEs (see 8.1).
RegWriteString( HKEY_CURRENT_USER, BaseRegistryKey + '\Environment Variables',     Name, Prefix );
RegWriteString( HKEY_CURRENT_USER, BaseRegistryKey + '\Environment Variables x64', Name, Prefix );

// Only when the user ticked the opt-in box (see 8.2).
if AWriteUserEnvironment then
  RegWriteString( HKEY_CURRENT_USER, 'Environment', Name, Prefix );
...
SendMessageTimeout( HWND_BROADCAST, WM_SETTINGCHANGE, 0, LPARAM( PChar( 'Environment' ) ), SMTO_ABORTIFHUNG, 5000, @Res );
```

`RegWriteString` from `IDEUtils` writes `REG_SZ`, which is correct for a literal absolute path.

The broadcast updates Explorer and newly launched processes. **The running IDE will not see it** — its environment block was captured at launch. That is one of the two reasons an IDE restart is required after Apply.

### 8.1 IDE bitness — the override key is split, the library path is not

**This is a hard requirement, not a refinement.** RAD Studio 37.0 keeps *two* independent user-variable lists:

```
HKCU\Software\Embarcadero\BDS\37.0\Environment Variables        <- read by bin\bds.exe   (32-bit IDE)
HKCU\Software\Embarcadero\BDS\37.0\Environment Variables x64    <- read by bin64\bds.exe (64-bit IDE)
```

The **library path keys are not split** — there is one `Library\Win32`, one `Library\Win64`, and no
`Library … x64` variant. So a path string is shared by both IDEs while the variables that resolve it are
per-IDE. Write `$(DUNITX)` into a shared path but define `DUNITX` in only one list, and the path resolves
in one IDE and silently breaks in the other. That is the worst outcome this feature can produce, and it is
the *default* outcome if the split is ignored.

`BorlandIDEServices.GetBaseRegistryKey` returns the same value in both IDEs, so
`BaseRegistryKey + '\Environment Variables'` is **wrong in the 64-bit IDE** — it names the 32-bit list.
Select the suffix from the host process bitness:

```pascal
/// <summary>Registry sub-key holding the IDE's user-defined macro overrides for THIS IDE's bitness.</summary>
function EnvironmentVariablesKey( const ABaseRegistryKey: string ): string;
begin
  {$IFDEF CPUX64}
  Result := ABaseRegistryKey + '\Environment Variables x64';
  {$ELSE}
  Result := ABaseRegistryKey + '\Environment Variables';
  {$ENDIF}
end;
```

Measured on the target machine 2026-08-31, the two lists **have already diverged**: the 32-bit list holds
`DUNITX`, `DELPHIMOCKS`, `GOOGLEMAPSDIR`, `DEMOSDIR`, `InterBase` and `IB_PROTOCOL`, none of which exist in
the x64 list. Any shared library-path entry using those macros already fails to resolve in the 64-bit IDE.
This is a pre-existing defect that the compactor will surface.

Required behaviour:

- **Read** both lists when building the macro table for analysis, and flag a variable that is defined in
  only one list, or defined differently in the two, as a **divergence warning** in the dialog. Expansion
  for analysis uses the host IDE's own list.
- **Write** every accepted variable to **both** lists, because the rewritten path is shared. Offer no
  option to write only one.
- **Refuse to rewrite** any entry whose macros do not resolve identically under both lists, and say why.
  Report pre-existing divergences as a hygiene finding rather than silently inheriting them.
- **Report** in the summary grid which IDE bitness the analysis was performed under.

### 8.2 `HKCU\Environment` is belt-and-braces — default it off

Command-line MSBuild does **not** read the IDE's `Library\<Platform>\Search Path`; `dcc` takes its search
path from the project's own `DCC_UnitSearchPath` plus the `$(BDSLIB)`-rooted defaults in the shipped
targets files. So writing the variables to `HKCU\Environment` only pays off where a `.dproj` itself
references one of the newly created macros — which will not happen unless the user hand-edits that `.dproj`.

Against that thin benefit it is the most invasive write the tool performs: user-global, permanent, visible
to every process on the machine, and populated with names derived from directory leaf names. Make it a
**separate checkbox, unticked by default**, worded as "Also define these as Windows user environment
variables (for hand-edited `.dproj` files)". The IDE override keys of §8.1 remain the primary,
always-on target.

---

## 9. Apply, backup and the IDE cache problem

Backup is solved: call `TLibraryPathBackupManager.CreateBackup` for every (PathType, Platform) pair the compaction touches, with a description like `Before compaction 2026-08-30 14:22`, before any write. Undo is the existing backup-history list — no new mechanism, no `.reg` files. The one gap: `RestoreBackup` restores paths but does not remove variables the compactor created, so record created variable names in the config and offer "Remove created variables" alongside a restore.

**Removing a created variable must be reference-checked, not blind.** The tool is explicitly re-runnable (§13.3), so a second run may reuse a variable a first run created. Restoring the first run's backup and then deleting "its" variables would orphan every path the second run wrote. Before deleting any variable, scan **all** platform × path-type values as they currently stand and skip any variable still referenced; report what was kept and why. The same check applies to a junction before offering to remove it.

**Invariant: the compactor never modifies an existing variable's value.** §6.5 already renames on collision and reuses on exact match, so this follows — but state it explicitly, because it is what makes "remove created variables" safe: the tool only ever adds names, so removal can never restore a wrong previous value.

**The open risk:** the IDE holds library paths in memory and may rewrite the key when its options are committed. `TFormLibraryPathSorter` already writes to these keys while the IDE runs, so either this is not a problem in practice or the existing sorter shares the bug.

**Establish this empirically before Apply is written**, and record the result in the PR:

1. With the IDE open, append `;C:\ZZTEST` to `HKCU\<BaseRegistryKey>\Library\Win64\Search Path` in regedit.
2. Close the IDE normally; re-read the value.
3. If `C:\ZZTEST` has gone, the IDE rewrites on shutdown.
4. Repeat, but first open Tools ▸ Options ▸ Library and press Cancel, to see whether the rewrite is triggered by shutdown or only by committing that dialog.
5. **Repeat once more and press OK, not Cancel.** This is the case that matters and the one steps 1-4 do not cover: the options page holds its own in-memory copy of the path, so committing it writes that copy straight over anything the compactor applied while the page was open. Expect a clobber here even if steps 3 and 4 come back clean.

Whatever the outcome, the dialog must **check whether Tools ▸ Options is open before applying** and refuse with an explanatory message if it is. That guard is cheap, is correct under every result above, and closes the only window in which a user can lose a compaction without being told.

If step 3 shows a rewrite, add a deferred applier: serialise the plan to `AppDataDirectory\PathCompactorPending.xml`, launch a small helper that waits on the IDE process handle and then applies. If it does not, write directly as the sorter does and simply prompt for a restart. **Do not build the helper speculatively** — check first.

Junction creation is the exception either way: do it at Apply time while the user is present for the UAC prompt. It does not disturb the IDE's cached paths.

**Ordering within Apply is load-bearing.** Create and verify every accepted junction *before* writing any path value, because a path rewritten to `C:\CR\…` against a junction that was never created points at nothing. If a junction fails or the UAC prompt is cancelled, **drop only the rewrites that depend on that junction** and apply the rest — do not abort the whole Apply, and do not apply the dependent rewrites anyway. Report exactly which rewrites were dropped and why. Sequence: back up → create junctions → verify junctions → write variables → write paths.

---

## 10. Dialog (`FrmPathCompactor`)

Descend from `TFormBase`, mirroring `TFormLibraryPathSorter`'s layout idiom.

- **Scope strip** — platform checklist (default all, reusing `GetAvailablePlatforms`), path-type checklist (default Library, Browsing, Debug DCU; `lptNamespacePrefixes` absent entirely).
- **`Analyse` button.** Analysis is read-only and safe to run at any time.
- **Summary grid** — one row per platform × type: stored length before → after, expanded length before → after, % saved. Amber the stored cell above `WarnStoredLength`.
- **Proposed variables grid** — Accept ✓ | Variable (editable) | Expands to | Uses | Chars saved.
- **Junction opportunities** — Accept ✓ | Source | Link (editable) | Uses | Chars saved (expanded).
- **Hygiene** — "Remove N duplicate entries" (default **off** — see §6.7), "Remove N missing directories" (default **off**), "Report N entries referencing an undefined macro" (report only, never auto-remove), each with a details link. The duplicate and undefined-macro *counts* are reported across every non-empty path set, not just the selected scope; removal only ever touches the selection. Baseline at time of writing: 917 entries over 96 sets, 0 duplicates — so a non-zero duplicate count is itself the news.
- **Divergence warnings** — any macro defined in only one of the two IDE variable lists, or defined differently in them (§8.1). Read-only; entries depending on such a macro are shown as not-rewritable.
- **"Also define these as Windows user environment variables"** — one checkbox, **unticked by default** (§8.2). Not per-variable; it is all or nothing.
- **Preview pane** — platform + type selector showing before/after raw strings. Nothing is applied unseen.
- **Buttons** — `Apply`, `Close`. Restore lives in the existing sorter's backup history; add a hint label saying so rather than duplicating the list.

Nothing is written until `Apply`.

---

## 11. Wiring checklist

1. `Source\DelphiExtension.inc` — add `{$DEFINE INCLUDE_PATHCOMPACTOR}` near line 62, beside `INCLUDE_LIBRARYPATHSORTER`.
2. `Source\RegisterPlugins.pas` — add the unit to the `uses` clause under `{$IFDEF INCLUDE_PATHCOMPACTOR}`, and register with `RegisterLateLoader( PathCompactor.InitPlugin )` immediately after the `LibraryPathSorter` block, honouring the `DisabledPlugins.IndexOf( 'PathCompactor' )` guard.
3. **All six** `D_D102 … D_D130\DDevExtensions.dpr` — add all five units, following the `LibraryPathSorter` entries at lines ~140-142, with the `{FormPathCompactor}` form comment on the frame unit. This matches how `ProjectGroupSorterCore` was registered, but see the note below: it is bookkeeping, not a portability constraint.
4. `DDevExtUnitTests\DDevExtUnitTestsDUnitX.dpr` — add `TestPathCompactorDUnitX`.
5. Build clean Win32 **and** Win64 on D130 before claiming completion. Both platforms are enabled in `D_D130\DDevExtensions.dproj`, and both matter: the design-time DLL is loaded by `bin\bds.exe` and `bin64\bds.exe` respectively, which is also what makes §8.1's bitness handling testable.

**Do not infer a pre-10.3 language constraint from step 3.** Registering the units in all six DPRs is house convention, not evidence that the older projects build. `D_D102` targets Delphi 10.2 Tokyo (`CompilerVersion` 32) yet already registers, unconditionally, units that use **inline variables** — a 10.3 Rio feature:

- `..\Source\CompileProgress\FrmSwitchToModuleProject.pas:91` — `var Dlg := TFormSwitchToModuleProject.Create(nil);`
- `..\Source\CodeQualityAnalyzer\FrmCodeQualityAnalyzer.pas:263` — `var Sl := TStringList.Create;`

Neither unit contains a single `CompilerVersion` conditional, both DPR entries are unguarded, and `DelphiExtension.inc`'s only version limitation is the XE2 `INCLUDE_STARTPARAMETERTEAM` undef. `D_D102` therefore cannot compile as it stands, and has not been able to for some time. Verified 2026-08-31.

The practical rule: write `PathCompactorCore` in whatever Delphi 13 supports — inline variables, type inference, `TArray<T>` — exactly as the rest of `Source\` already does. Register the units in all six DPRs to keep the convention, build D130, and do not spend effort making the core compile under 10.2. If the older targets are ever revived that is a separate piece of work, and it starts with the two units above, not with this feature.
6. Version bump across every indicator: `Source\version.inc`, `version.h`, all six `D_Dxxx\DDevExtensions.dproj`, `Installer\DDevExtensionsReg.dproj`. The changelog shows these have drifted stale before — check each one.

---

## 12. Tests (`TestPathCompactorDUnitX.pas`)

`PathCompactorCore` has no registry or ToolsAPI dependency, so test it directly with a `TStringList` macro table.

1. Unknown macro `$(NOPE)\x` is left intact and terminates in one pass.
2. Self-referential `A=$(A)\x` hits the depth cap and returns, rather than hanging.
3. `D:\Lib` does **not** match `D:\Library\Foo` (segment-boundary rule).
4. Nested prefixes: selection prefers the greater incremental saving; rewrite applies the longest accepted prefix.
5. An entry containing `$(Config)` survives round-trip byte-for-byte and is excluded from duplicate detection.
6. Duplicate detection is case-insensitive and treats `D:\X` and `D:\X\` as equal.
7. Name collision with an existing IDE variable of a different value yields `NAME_2`.
8. An existing IDE variable equal to the candidate prefix is reused with no redefinition emitted.
9. A candidate whose derived name collides with an IDE built-in is renamed, never emitted as-is.
10. Output entry count equals input minus intentional drops (the `SortPaths` guard).
11. A prefix ending in a platform or config token (`…\Dcp\Win32`, `…\Bpl\Win64\Release`) never yields `WIN32`/`WIN64`/`RELEASE`; the two-segment rule produces `DCP_WIN32`, and recurses where the next segment is also a token.
12. An entry already stored as `$(BDS)\source\rtl` is **not** rewritten under a newly invented variable for the same directory; the candidate scores negative in stored space and is rejected (§6.4). This is the regression test for the defect that formula originally had.
13. A candidate prefix equal to an IDE built-in's value is emitted as that built-in, not as a new variable (§6.4 corollary).
14. Passing `lptNamespacePrefixes` to the analyser raises rather than compacting it (§6.1).
15. An existing IDE variable's value is never modified — every fixture asserts the macro table it was given is unchanged on exit.
16. **Stored-length invariant — assert on every fixture:** for every path set, total stored length after ≤ total stored length before. A rewrite that lengthens the string is a failure however sound its round-trip.
17. With duplicate removal left at its default (off), a set containing duplicates is *reported* but the output entry count equals the input count — detection and removal are independently switchable (§6.7).
18. **Round-trip invariant — assert on every fixture:** analyse → rewrite → expand yields the same expanded path set as the original, minus intentionally dropped entries.

---

## 13. Open questions for the implementer

1. **Does the IDE rewrite the Library key on shutdown?** §9. Resolve before choosing the Apply strategy.
2. ~~**Does command-line MSBuild consume the IDE's registry library path at all?**~~ **Resolved (2026-08-31): it does not.** `dcc` takes its search path from the project's `DCC_UnitSearchPath` plus the shipped `$(BDSLIB)`-rooted defaults; the IDE's `Library\<Platform>` key is IDE-only. The `HKCU\Environment` write is therefore belt-and-braces and is defaulted off — see §8.2. Confirm once with a trivial project built via `msbuild` after `rsvars.bat` before relying on it.
3. **`$(BDSCatalogRepository)` after junctioning.** Prefer rewriting affected entries to the junction path over redefining the built-in macro — redefining a built-in will confuse GetIt, which writes new entries using the original. The tool must be re-runnable to mop those up; say so in the dialog.
4. **Non-Windows platform keys** (Android, iOS, Linux) hold SDK macros and forward slashes. Include them in scope but be conservative: if an expanded entry does not look like a Windows path, mark it `Opaque`.
5. **Design-time package unload/reload** — no dangling menu items or leaked process handles from the junction helper.

---

## 14. Changelog entry

Match the house format in `CHANGELOG.md` (dated heading, bold lead sentence, trailing date and file list):

```markdown
## 2026-XX-XX - vX.Y.Z - Library Path Compactor

### Added

- **New Tools ▸ IDE Path Compactor dialog that shortens the IDE's library path strings.** Analyses every
  selected platform × path-type, proposes `$(NAME)` macro substitutions for repeated directory prefixes
  (scored by incremental character saving measured in STORED space, longest-prefix-first at rewrite), offers
  directory junctions for over-long third-party prefixes, and reports duplicate, dead and undefined-macro
  entries — removal of any of them is opt-in, since a survey of all 96 populated path sets found 0 duplicates.
  Reports stored *and* expanded lengths before/after, since only the expanded length constrains the compiler
  command line. Accepted variables are written to **both** IDE macro-override keys — `Environment Variables`
  and `Environment Variables x64` — because the library path itself is shared between the 32- and 64-bit
  IDEs while those variable lists are not; a variable defined in only one list is reported as a divergence
  and its entries are left unrewritten. Optionally (off by default) the variables are also written to
  `HKCU\Environment`. Backup and rollback reuse the existing `TLibraryPathBackupManager` history. Pure
  analysis logic lives in RTL-only `PathCompactorCore` with a
  18-test DUnitX fixture. (2026-XX-XX) — `Source/PathCompactor/*`, `Source/RegisterPlugins.pas`,
  `Source/DelphiExtension.inc`, `D_D102`…`D_D130/DDevExtensions.dpr`,
  `DDevExtUnitTests/TestPathCompactorDUnitX.pas`

### Known

- `IDEUtils.ExpandDirMacros` reads neither IDE `Environment Variables` override key and lacks
  `BDSCATALOGREPOSITORY`/`BDSCOMMONDIR`/`BDSUSERDIR`; worse, it *deletes* a macro it cannot resolve instead
  of leaving it intact. The compactor therefore carries its own expander. Consequence for the existing
  sorter: a `$(BDSCatalogRepository)` entry expands to a bare `\...` remainder, fails `DirectoryExists` and
  is wrongly flagged **invalid** — the `IsPathValid` "unexpanded macro, treat as valid" branch is
  unreachable for it. Tracked separately.
- The IDE's two user-variable lists (`Environment Variables` / `Environment Variables x64`) have already
  diverged on the development machine, so some existing shared library-path entries resolve in the 32-bit
  IDE only. The compactor reports these; it does not repair them automatically.
```

---

## 16. Implementation outcome (2026-08-31, shipped as v3.22.11)

Built and shipped. Six new files under `Code\DDevExtensions\Source\PathCompactor\`
(`PathCompactorCore.pas`, `PathCompactor.pas`, `PathCompactorEnvVars.pas`,
`PathCompactorJunctions.pas`, `FrmPathCompactor.pas/.dfm`) plus
`DDevExtUnitTests\TestPathCompactorDUnitX.pas`. Registered in `DelphiExtension.inc`,
`RegisterPlugins.pas`, all six `D_Dxxx\DDevExtensions.dpr` and the DUnitX project.
`LibraryPathSorter` aliases `TLibraryPathType` and its helper from the core.

**20/20 tests green.** Both plugin DLLs build clean, x86 and x64, v3.22.11.

### What changed against the plan

- **§6.1's helper warning proved exact, and then some.** Aliasing the enum was not
  enough: a type alias re-exports neither the enumeration's members nor the record
  helper, so `FrmLibraryPathSorter` had to `uses PathCompactorCore` directly.

- **§6.5 naming needed a second fix beyond the platform/config-token guard.** Names
  were being assigned during candidate *generation*, in dictionary order, so on the
  live machine the 499-use prefix became `$(SOURCE_4)` while a 50-use one took
  `$(SOURCE)`. Names are now assigned at *acceptance*, in descending order of value,
  and `UniqueVariableName` compares only against already-accepted variables — it had
  been comparing against every candidate's provisional name, including the
  candidate's own, so everything picked up a needless `_2`.

- **`$(LangDir)` had to join the build-time macro set.** It resolves per translation
  language and appears only in the three Translated* path types; without it, 30
  entries on the live machine were reported as dead macro references.

- **Cleanup gained a third category and two safeguards** (not in the original brief).
  Dead macro references are now removable alongside duplicates and missing
  directories, all three opt-in. Every intended removal is re-verified immediately
  before writing — `RevalidateDrops` re-probes the file system and re-resolves each
  macro, keeping anything that now passes — and the full removal list is shown for
  confirmation first. An analysis can be minutes old by the time Apply runs.

- **Divergent macros are a distinct class from dead ones.** A macro this IDE cannot
  resolve but the other bitness can is live in that other IDE; deleting it from the
  shared library path would break it. Reported, never removed. On the live machine
  this is the difference between deleting four working entries and deleting none.

### Measured on the development machine

96 populated path sets, 13 platforms, 917 entries. Stored 30,268 → 23,003
(**24.0% saved**). 0 duplicates, 79 missing-directory references over 24 unique
directories, **0 dead macros, 4 divergent** (`$(DUNITX)`, `$(DELPHIMOCKS)`,
`$(GOOGLEMAPSDIR)` ×2 — all defined in the 32-bit list only). With cleanup fully
enabled the tool would remove **nothing**, which is the correct answer.

### First live run (2026-08-31)

Applied on the development machine, then the IDE was closed and reopened and project
builds run against the result.

| | |
|---|---|
| Path sets changed | 25 |
| Stored characters | 31,428 → 22,413 (**28.7% saved**) |
| Entries | 952 → 873 (−79) |
| Variables created | 12, in **both** IDE lists |
| Variables modified or deleted | 0 |
| Windows user environment | untouched (opt-in left off) |

The 79 removed entries were exactly the missing-directory references — a re-analysis
afterwards reports 0 duplicates, 0 missing, 0 dead macros, 0 to remove. All 12 created
variables are referenced; none was orphaned. One removed entry, `$(BDS)\\source\\rtl\\linux`,
had been stored with **doubled backslashes** and could never have resolved.

**§13.1 is answered: the IDE does NOT rewrite the Library key on shutdown.** The
rewritten paths and both variable lists survived a normal close and reopen intact, and
compiled. The direct write is correct and the deferred applier described in §9 is not
needed — do not build it.

**One defect the run exposed.** `Analyse` ran hygiene *after* candidate selection, so an
entry queued for removal still voted for a variable and still counted toward its saving.
Nothing was actually orphaned in this run, but the ordering made it possible and the
reported saving counted characters that were never going to be written. Hygiene now runs
before candidate generation and dropped entries are excluded from tallying, matching,
scoring and rewriting; a mutation-checked test covers it.

### Second pass (2026-08-31)

Applied with all three cleanup options ticked. Result: **0 to remove** - the first pass
had already taken the 79 missing directories, and the four remaining unresolvable macros
are divergent, so protected. Cumulative across both passes: **31,428 -> 20,635 stored
characters (34.3% saved)**, 24 variables in both IDE lists, none modified, none deleted.

The run also had the *Windows user environment* box ticked, which wrote 12 variables to
`HKCU\Environment`. Those were subsequently removed by hand: they achieve nothing
(command-line MSBuild does not read the IDE library path) and several of the generated
names - `CODE`, `COMMON`, `SRC`, `SOAP`, `CONTRIB`, `INDY` - are far too generic to sit in a
user-global environment where every process inherits them. The option remains available but
should stay off unless a `.dproj` is being hand-edited to use one of these macros.
**Worth considering:** warn in the dialog when a proposed name is a common generic token
and that option is ticked.

### Still open

- **§13.5** — design-time package unload/reload cleanliness is untested.
- The two IDE variable lists remain diverged on the development machine; the tool
  reports it (4 entries, all divergent rather than dead) but does not repair it.
- Variable names can still run long where a collision forces widening
  (`$(EUREKALOG_7_SOURCE)`, `$(INFOPOWER4KFLORENCE_LIB)`). That is the intended trade -
  a meaningful long name beats a short meaningless one - but a smarter rule might drop
  noise segments such as `packages` or `lib` when folding in a parent.