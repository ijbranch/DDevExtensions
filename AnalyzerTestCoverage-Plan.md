# Analyzer Unit-Test Coverage — Scoping (audit option 2)

Status: **proposal / scoping only** — no code changed. Written 2026-05-30 after the v3.19.9 audit remediation. The existing `DfmParserTests` DUnitX suite passes 31/31; this plan extends automated coverage to the *analyzer* engines, which currently have none.

## 1. Goal

Give the code-analysis engines (Code Quality, Code Style, Unreachable Code, Empty-Event-Handler, DFM/PAS Consistency, Dead Code, Unused Unit, Uses Clause) regression tests that run **without the IDE**, the same way `gllDelphiDFMParser` is tested today — so behaviour changes like the v3.19.9 fixes are guarded.

## 2. Current state

| Engine | Core entry point | Purity of the core | Coupling that blocks testing today |
|--------|------------------|--------------------|-------------------------------------|
| CodeQualityAnalyzer | `class function AnalyzeUnit(const Source: UTF8String; FileName; UnitName; Results)` | **Pure** (uses `DelphiLexer` only) | Co-located with IOTA plugin class; unit `uses ToolsAPI, Vcl.Menus, PluginConfig, FrmTreePages` |
| EmptyEventHandlerDetector | `class function AnalyzeUnit(const Source: UTF8String; FileName): TArray<…>` | **Pure** | Same co-location |
| DfmPasConsistency | `class function AnalyzeUnit(const PasSource, DfmSource: UTF8String; …)` | **Pure** (both inputs are strings — ideal) | Same co-location |
| UnreachableCodeDetector | `procedure ScanSource(const Source, FileName, UnitName)` (fills an internal list) | **Pure parsing**, but the unit `uses Main` | `uses Main` drags the whole plugin (hooks install at init) |
| CodeStyleChecker | per-file `Content := LoadTextFileToUtf8String(...)` then analyse | Core exists but is reached via a file path, not a public string entry | Needs a `CheckSource(content)` seam exposed |
| DeadCodeDetector | `AnalyzeProject(const Project: IOTAProject; …)` | Project-wide; reads each file via `LoadTextFileToUtf8String` | Cross-file; needs an in-memory multi-unit input to test |
| UnusedUnitDetector | project-wide | Project-wide | Same |
| UsesClauseManager | builds an exports DB across search paths | Project-wide | Same |

**Conclusion:** four engines (CodeQuality, EmptyEventHandler, DfmPasConsistency, UnreachableCode) already expose a pure string→findings core — the only obstacle is that the core shares a unit with IOTA/VCL/Main dependencies. The remaining four are project-wide and need a small input-shape refactor to be testable.

## 3. Approach — extract dependency-light cores

For each engine, move the **types + the pure `AnalyzeUnit`/`ScanSource` logic** into a new core unit that `uses` only `System.*`, `System.Generics.Collections`, and `Shared\PascalParser\DelphiLexer` (plus `DelphiPreproc` for Unreachable). The existing plugin unit then `uses` the core and keeps all ToolsAPI/VCL/menu/option-page glue. This is a **mechanical move with no logic change**, mirroring how `gllDelphiDFMParser` is already a standalone, testable unit.

```
CodeQualityAnalyzer.pas   -> CodeQualityCore.pas      (TCodeQualityIssue + AnalyzeUnit)  + thin plugin
EmptyEventHandlerDetector -> EmptyHandlerCore.pas      (TEmptyHandlerInfo + AnalyzeUnit)
DfmPasConsistency.pas     -> DfmPasConsistencyCore.pas (TInconsistency + AnalyzeUnit)
UnreachableCodeDetector   -> UnreachableCore.pas       (scanner + define eval; drop `uses Main`)
CodeStyleChecker.pas      -> CodeStyleCore.pas          (expose CheckSource(content))
```

Test project: new **`AnalyzerTests\AnalyzerTestsDUnitX.dproj`** modelled on `DfmParserTestsDUnitX.dproj` — references the `*Core.pas` units + `DelphiLexer.pas` (+ `DelphiPreproc.pas`) + fixtures only. Win32 + Win64, output to `..\bin`.

## 4. Priority fixtures (guard the v3.19.9 fixes first)

- **CodeQualityCore — magic numbers / bracket depth:** assert `A[ I + 5 ]` and `A[ Count - 1 ]` are **not** flagged when `AllowMagicInArrayIndex` is on (the v3.19.9 fix); `X := 5` **is** flagged; `const C = 5` is not; `Foo(const X: …)` does not trip the const-section tracking.
- **EmptyHandlerCore — declaration line:** a handler whose name wraps onto the line after `procedure` reports the **keyword** line (v3.19.9 fix), and a method without a `Sender` parameter is not reported.
- **UnreachableCore — preview truncation:** a >50-char unreachable line gets the `…` suffix; a short line does not (v3.19.9 fix); code after `Exit`/`Raise`/`Break` is flagged; `if X then Exit;` (conditional) is **not**; case-branch terminators handled; triple-quoted strings skipped.
- **DfmPasConsistencyCore:** Missing-in-PAS / Missing-in-DFM / Type-Mismatch on small fixtures; a known-limitation test documenting the substring collection-depth edge.
- **CodeStyleCore:** formalise the existing `TestAntiPatterns.pas` fixture (it already documents expected counts: 2 EmptyFinally, 1 NestedWith, 1 DeepNesting, 1 LongMethod, 2 LongParamList) into real assertions, plus naming-convention cases.

## 5. Phasing & effort

- **Phase 1 (high value, low risk, ~½–1 day):** extract `CodeQualityCore`, `EmptyHandlerCore`, `DfmPasConsistencyCore` (already pure class functions — extraction is moving the type + function and pointing the plugin at it). Stand up `AnalyzerTestsDUnitX` with the Phase-1 fixtures above. Directly guards three of the v3.19.9 fixes.
- **Phase 2 (~1 day):** `UnreachableCore` (untangle `uses Main` — confirm what it actually needs from Main, likely nothing in the scanner path) and `CodeStyleCore` (expose `CheckSource`, formalise `TestAntiPatterns.pas`).
- **Phase 3 (optional, ~1–2 days):** refactor the project-wide engines (Dead Code, Unused Unit, Uses Clause) to accept an in-memory set of `(unitName, source)` pairs so cross-file resolution is testable; lower priority since v3.19.9 changed none of their core logic (CSV escaping and a logging line only).

## 6. Risks / notes

- Each core extraction touches the plugin unit's `uses` **and** the `DCCReference` lists in all six `D_Dxxx/DDevExtensions.dproj` files, the `.dpr`, and (if applicable) the `.dpk`. Build-verify Win32 + Win64 after each extraction.
- Keep extractions **pure moves** — no behaviour change — so the existing manual workflow is unaffected.
- The test project should run from its own directory (or set `TestData` via a relative path), per the CWD quirk seen in `DfmParserTests` (file round-trips skip when run from `\bin`).
- `TestAntiPatterns.pas` at the repo root is currently a throwaway fixture marked "DELETE AFTER TESTING"; Phase 2 would relocate it under `AnalyzerTests\TestData\` and turn it into asserted coverage rather than deleting it.

## 7. Recommendation

Do **Phase 1 only** first: it is low-risk, needs no logic changes, and directly locks in three of the v3.19.9 analyzer fixes. Decide on Phases 2–3 after seeing Phase 1 land green.
