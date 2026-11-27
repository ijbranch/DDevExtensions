# DfmNoiseMeasure

A console tool that measures the noise the IDE leaves in saved `.dfm` files: what changes between two versions of
a form, sorted into categories.  Since 1.1.0 it also checks the links between modules ( `links`, below ).  Run by
hand; nothing calls it.  Built 2026-11-28 to measure before deciding whether DDevExtensions needs more than
its three DFM cleaners ( after a review of Cesar Romero's
[delphi-dfm-noise-filter](https://github.com/cesarliws/delphi-dfm-noise-filter) ).  Results: `Findings-2026-11-28.md`.

## Build

`DfmNoiseMeasure.dproj`, a console application ( Win64 Release; Win32 declared ).  It uses
`..\..\Shared\PascalParser\gllDelphiDFMParser.pas` and `gllDfmCompare.pas` ( the comparison, shared with the
DFM Link Guard in the DDevExtensions DLL ), the guard's own rule in
`..\..\Code\DDevExtensions\Source\DfmLinkGuard\DfmLinkGuardCore.pas`, and `DfmLinkCheck.pas` ( the `links`
decisions, tested by `TestDfmLinkCheckDUnitX` in the DDevExtensions suite ).  It links GITLAKRTL first.  Output:
`bin\$(Platform)\$(Config)`.

## Commands

```
DfmNoiseMeasure identity <folder> [<folder>...]
DfmNoiseMeasure compare <pairs.tsv> [<detail.csv>]
DfmNoiseMeasure links <root> [<pairs.tsv>] [--out <folder>] [--files <list.txt>]
```

- **identity** parses and re-serialises every text `.dfm` under the folders ( recursively ) and lists any that do not
  come back byte for byte, with the first line that differs.  Binary DFMs are counted and skipped.  Files are read one
  byte per character ( ISO-8859-1 ), so ANSI and UTF-8 files both round-trip exactly.
- **compare** reads a tab-separated list of old/new file pairs ( columns `repo`, `commit`, `date`, `path`, `old`,
  `new`; the file paths relative to the list ), compares each pair component by component and prints a table of
  changes by category and kind, the number of pairs whose ONLY changes are known IDE noise, and the 30 most frequent
  "Other" changes.  The optional CSV gets one row per change.
- **links** checks the links between modules ( a value `Module.Component`, such as `DataSource = dmMain.dsCustomers` ).
  `<root>` is one repository, or a folder whose first-level folders are repositories.  Normally run through
  `Check-DfmLinks.ps1` ( next section ).
  - **Today:** every link in every text `.dfm` must name a component that a `.dfm` with that root declares.  The
    module is looked for in the link's own repository first ( several applications each have a `MainForm` ), then in
    every repository ( a shared data module ).  Each failure is printed as `COMPONENT MISSING` or `MODULE NOT FOUND`.
    A dotted value naming the form's own root is checked within the form; one naming another of its components
    ( an embedded frame ) is not a link.
  - **History**, with `<pairs.tsv>`: the DFM Link Guard's own rule ( `FindLostModuleLinks` ) on every past save,
    with the target looked up in today's files, and each loss classified by today's file: restored, value elsewhere in
    file ( exactly that value on another property ), component gone, file gone, or `STILL LOST` ( printed ).
  - `--out` writes `links-today.csv` and `links-history.csv`; `--files` checks only the listed `.dfm` files ( one full
    path per line ) instead of every one under the root.

Exit code: 0 done, 1 bad command line or nothing to check, 2 a file failed to round-trip or to parse, 3 ( `links` ) a link without a target
or a loss still lost.  A past save that cannot be read is listed but does not set the exit code: history cannot change.

## Checking links: `Check-DfmLinks.ps1`

One command for the whole check ( PowerShell 7; read-only on the repositories ):

```
pwsh -File Check-DfmLinks.ps1                                  # the DBiWorkflow repositories
pwsh -File Check-DfmLinks.ps1 -Root D:\GITLAKLib               # one repository
pwsh -File Check-DfmLinks.ps1 -Since 2026-01-01 -Out D:\Temp\Links
```

It exports the history with `Export-DfmHistory.py`, lists the `.dfm` files git knows ( tracked, or new and not
ignored ), and runs `links`.  Only files git knows are checked: GITLAKLib's build leaves copies of its forms beside its
DCUs ( `37.0\<platform>\<config>` ), and a stale copy could still declare a component deleted from the real form, which
would hide a broken link.  Build `DfmNoiseMeasure.dproj` ( Win64 Release ) first.

Two limits, both seen in the 2026-11-28 scan of every repository on D: and E::

- **Check together what is used together.**  A DBiWorkflow application checked on its own reports every link to a
  data module in `DBiCommonFiles` as `MODULE NOT FOUND`: that module is in another repository.  Point `-Root` at the
  folder holding all of them ( the default does ).
- **Any `Name.Name` value counts as a link.**  A value that only looks like one, such as gllIndy10's
  `CategoryComponent = NoCategoryComponent.Owner` in its Bubbles tests, is reported as `MODULE NOT FOUND`.  Read the
  value before acting on it.  Results on 2026-11-28: DBiWorkflow
788 links in 235 forms, all resolve; 13 past losses, none still lost ( one deliberate removal among them ); GITLAKLib 8
forms, no links between modules; GITLAKDB 57 forms, 18 links, all resolve; gllSpell 8 and WinTrak 4 forms, no links
between modules.  None of the last three lost a link in its history.  WinTrak is at
`-Root 'E:\Amateur Radio Projects\WinTrak Development'`.

## Pairs from git history

`Export-DfmHistory.py` writes the pairs for every commit that MODIFIED a `.dfm` ( additions, deletions and renames
are not pairs ).  It only runs `git log` and `git cat-file`.

```
python Export-DfmHistory.py <out-folder> <repo> [<repo>...] [--since YYYY-MM-DD]
DfmNoiseMeasure compare <out-folder>\pairs.tsv <out-folder>\detail.csv
```

## Categories

Components are matched by name under their parent ( an unnamed one by class and position ); the root is matched
whatever its name.  `gllDfmCompare.ClassifyChange` decides, in this order:

| Category | What | Known IDE noise |
|---|---|---|
| Component added/removed/retyped | a component only on one side, or its class or keyword changed | no |
| `[n]` index shift | the creation-order index of an inherited component changed | yes |
| Child order / Property order | the same children or properties, in another order ( one change per component ) | yes |
| Explicit\*, PixelsPerInch, TextHeight, DesignSize | those properties, added, removed or changed | yes |
| Other-module link removed | a removed property whose value is `Module.Component` | no |
| Image link removed | a removed `...Images`, `...ImageIndex` or `...ImageName` | no |
| Font | any `Font.*` property | no |
| Geometry | `Left`, `Top`, `Width`, `Height`, `ClientWidth`, `ClientHeight` changed | no |
| Other | everything else | no |

"Known IDE noise" means the IDE writes it without a user's edit.  Geometry and Font can be either ( DPI scaling, or
a move ), so they are reported apart and never counted as noise.

## Limits

- A history pair is one commit, which may hold several saves and deliberate edits: the counts are of what reached
  the repository, not of single saves.
- A removed link is only a candidate loss: check whether the target component still exists and whether the link
  came back ( `Findings-2026-11-28.md` shows how ).
- A text DFM without a final line break does not round-trip ( the serialiser always ends with one ); the IDE always
  writes one, and none of the 324 files measured lacked it.  Hand-made spacing around `=`, before `[n]` and blank
  lines are normalised too; the IDE writes none of them.
- A renamed component counts as one removed and one added.  An unnamed component is matched by class and position,
  so inserting one before it shows as removed and added.
- `Export-DfmHistory.py` skips merge commits ( `--diff-filter=M` without `-m` ) and reads the blobs git stored, so
  with line-ending normalisation the history pairs may differ in line endings from the working files ( both sides
  alike, so the comparison is unaffected ).
