# DfmNoiseMeasure

A console tool that measures the noise the IDE leaves in saved `.dfm` files: what changes between two versions of
a form, sorted into categories.  Run by hand; nothing calls it.  Built 2026-11-28 to measure before deciding whether DDevExtensions needs more than
its three DFM cleaners ( after a review of Cesar Romero's
[delphi-dfm-noise-filter](https://github.com/cesarliws/delphi-dfm-noise-filter) ).  Results: `Findings-2026-11-28.md`.

## Build

`DfmNoiseMeasure.dproj`, a console application ( Win64 Release; Win32 declared ).  It uses
`..\..\Shared\PascalParser\gllDelphiDFMParser.pas` and `gllDfmCompare.pas` ( the comparison, shared with the
DFM Link Guard in the DDevExtensions DLL ) and links GITLAKRTL first.  Output: `bin\$(Platform)\$(Config)`.

## Commands

```
DfmNoiseMeasure identity <folder> [<folder>...]
DfmNoiseMeasure compare <pairs.tsv> [<detail.csv>]
```

- **identity** parses and re-serialises every text `.dfm` under the folders ( recursively ) and lists any that do not
  come back byte for byte, with the first line that differs.  Binary DFMs are counted and skipped.  Files are read one
  byte per character ( ISO-8859-1 ), so ANSI and UTF-8 files both round-trip exactly.
- **compare** reads a tab-separated list of old/new file pairs ( columns `repo`, `commit`, `date`, `path`, `old`,
  `new`; the file paths relative to the list ), compares each pair component by component and prints a table of
  changes by category and kind, the number of pairs whose ONLY changes are known IDE noise, and the 30 most frequent
  "Other" changes.  The optional CSV gets one row per change.

Exit code: 0 done, 1 bad command line, 2 a file failed to round-trip or to parse.

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
