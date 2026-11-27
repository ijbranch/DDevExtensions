# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [In-Service]

### Added

- (2026-11-28) **DfmNoiseMeasure 1.0.0: measures the IDE noise in saved DFMs** — `DfmNoiseMeasure.dpr`, `DfmNoiseMeasure.dproj`, `DfmNoiseMeasure.Core.pas`, `Export-DfmHistory.py`, `Help.md`, `Findings-2026-11-28.md`.  `identity` proves the parser round-trips every text DFM under some folders byte for byte; `compare` sorts the differences between old/new pairs ( exported from git history by `Export-DfmHistory.py` ) into categories, known IDE noise apart.  **Why:** measure before deciding whether DDevExtensions needs a snapshot-and-merge filter like Cesar Romero's delphi-dfm-noise-filter.  First run over 3,179 DBiWorkflow pairs: 1% of DFM commits are noise-only, but one silent loss of 11 data-module bindings ( DBiPV, 2025-10-16 ) went unrepaired for a year ( `Findings-2026-11-28.md` ).  The core is tested by `TestDfmNoiseMeasureCoreDUnitX` in the DDevExtensions suite.
