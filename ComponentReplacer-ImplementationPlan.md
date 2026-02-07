# Component Replacer Feature - Implementation Plan

## Context

GExperts' Replace Components expert has been broken since Delphi XE3 due to `IOTAFormEditor.CreateComponent` crashing on components with sub-components (RSP-25645). This feature adds a reliable component replacement capability to DDevExtensions using a **hybrid approach**: OTA for reading/introspection, text-based DFM and PAS manipulation for writing. This avoids the broken OTA code path entirely.

Original spec document: `C:\Users\Ian\Desktop\DDevExtV3-ComponentReplacer-Spec.md`

---

## Unit Naming

The spec uses dotted names (`DDevExt.CompReplace.*.pas`). Per decision, we use **flat PascalCase** names matching the existing codebase convention. All new units go under `Source\ComponentReplacer\` except the DFM parser which goes in `Shared\PascalParser\`.

| Spec Name | Actual Name | Location |
|-----------|-------------|----------|
| `DDevExt.CompReplace.Types.pas` | `CompReplaceTypes.pas` | `Source\ComponentReplacer\` |
| `DDevExt.CompReplace.DfmParser.pas` | `gllDelphiDFMParser.pas` | `Shared\PascalParser\` |
| `DDevExt.CompReplace.OTAHelper.pas` | `CompReplaceOTAHelper.pas` | `Source\ComponentReplacer\` |
| `DDevExt.CompReplace.Engine.pas` | `CompReplaceEngine.pas` | `Source\ComponentReplacer\` |
| `DDevExt.CompReplace.MappingStore.pas` | `CompReplaceMappingStore.pas` | `Source\ComponentReplacer\` |
| `DDevExt.CompReplace.UI.pas` | `FrmComponentReplacer.pas` | `Source\ComponentReplacer\` |
| `DDevExt.CompReplace.Registration.pas` | `ComponentReplacer.pas` | `Source\ComponentReplacer\` |
| *(additional)* | `FrmeOptionPageComponentReplacer.pas` | `Source\ComponentReplacer\` |

---

## Existing Infrastructure to Reuse

| Component | File | Purpose |
|-----------|------|---------|
| `TDelphiLexer` | `Shared\PascalParser\DelphiLexer.pas` | PAS token manipulation: `ReplaceToken`, `InsertTextAfter`, `DeleteToken` |
| `TDesignerParser` | `Shared\PascalParser\DelphiDesignerParser.pas` | PAS class/field/uses-clause parsing |
| `LoadTextFileToUtf8String` | `Shared\PascalParser\DelphiLexer.pas` | File reading with encoding detection |
| SimpleXml | `Shared\Xml\SimpleXmlIntf.pas`, `SimpleXmlDoc.pas`, `SimpleXmlImport.pas` | XML persistence |
| `TPluginConfig` | `Source\PluginConfig.pas` | Base config class with RTTI auto-serialisation |
| `TFormBase` | `Shared\IDE\FrmBase.pas` | Base form for IDE tool dialogs |
| `TFrameBase` | `Source\FrmeBase.pas` | Base frame for options pages |
| `ITreePageComponent` | `Shared\IDE\Options\FrmTreePages.pas` | Options page interface |
| `ToolsAPIHelpers` | `Shared\IDE\ToolsAPIHelpers.pas` | `GetActiveProject`, `GetEditorSource`, `SaveFormResourceTo`, etc. |
| `TRegisteredComponents` | `Source\ComponentManager.pas` | IDE component type registry |
| `DDevExtensionsMenu` | `Source\Main.pas` (line 38) | Global menu variable for adding items |
| `AppDataDirectory` | `Source\Main.pas` | Config file storage path |

**Reference plugin (closest pattern):** `DfmPasConsistency` in `Source\DfmPasConsistency\` — follow its structure for plugin registration, menu integration, options page, and UI form.

---

## Implementation Steps

### Step 1: CompReplaceTypes.pas — Type Definitions

Pure record types, no dependencies. Define:
- `TPropertyAction` enum: `paCopy, paMap, paDelete, paTransform`
- `TPropertyMapping` record: `SourceProperty`, `DestProperty`, `Action`, `TransformExpr`
- `TComponentMapping` record: `SourceType`, `DestType`, `SourceUses`, `DestUses`, `PropertyMappings: TArray<TPropertyMapping>`, `Notes`
- `TReplacementResult` record: `FormFile`, `ComponentName`, `SourceType`, `DestType`, `Success`, `ErrorMessage`, `PropsChanged`, `PropsDeleted`, `PropsUnmapped: TArray<String>`
- `TReplaceScope` enum: `rsCurrentForm, rsSelectedForms, rsEntireProject`

### Step 2: gllDelphiDFMParser.pas — DFM Text Parser ✅ **COMPLETE**

**Location:** `D:\DDevExtensions\Shared\PascalParser\gllDelphiDFMParser.pas`
**Tests:** `D:\DDevExtensions\DfmParserTests\DfmParserTestsDUnitX.exe` (32/32 passing)
**Status:** Production-ready, validated against 11 test files including 5 real-world production DFMs

Standalone, reusable DFM parser. **Lossless** — `Serialize(Parse(text)) = text` ✅ verified.

**Implemented Classes:**
- `TDfmProperty` — Stores `Name`, `RawValue`, `Indent`, `ValueKind`
- `TDfmComponent` — Stores `Name`, `TypeName`, `ObjectKind`, `Properties`, `Children`, `Indent`, `EndIndent`
  - Methods: `FindProperty`, `DeleteProperty`, `SetProperty`, `FindChild`
- `TDfmDocument` — Stores `Root`, `LineEnding`, `Header`, `Trailer`
  - `class function Parse(const DfmText: string): TDfmDocument`
  - `class function Serialize(Doc: TDfmDocument): string`

**Validated Features:**
- ✅ Binary data `{ }` with depth tracking
- ✅ Collections `< >` with depth tracking
- ✅ Parenthesized lists `( )` with depth tracking
- ✅ Multi-line string concatenation with `+`
- ✅ Set properties `[ ]`
- ✅ Empty property values (value starts on next line)
- ✅ `object`, `inherited`, `inline` keywords
- ✅ Whitespace and line ending preservation
- ✅ Nested components (arbitrary depth)

**See:** `DelphiDfmParser-StandaloneProject.md` for full implementation details.

### Step 3: CompReplaceOTAHelper.pas — OTA Reading & RTTI

**Dependencies:** `ToolsAPI`, `ToolsAPIHelpers`, `CompReplaceTypes`

**Reuses:** `GetActiveProject`, `GetEditorSource`, `SaveFormResourceTo` from `ToolsAPIHelpers.pas`

**Key functions:**
- `GetProjectFormModules: TArray<TModuleFileInfo>` — Iterate `IOTAProject.GetModuleCount`, find modules with DFM resources
- `ReadDfmSource / ReadPasSource` — From editor buffer if open (via `GetEditorSource`), else from disk (via `LoadTextFileToUtf8String` from `DelphiLexer.pas`)
- `CreateBackups` — Copy `.pas` and `.dfm` to `.pas.bak` / `.dfm.bak`
- `ReloadModule` — Close module via `IOTAModuleServices`, write to disk, reopen via `OpenFile`
- `GetPublishedProperties(const aClassName: String): TArray<TPropertyInfo>` — Use `System.TypInfo.GetPropList` on design-time registered class (via `GetClass`)
- `BuildAutoMapping(const aSourceType, aDestType: String): TComponentMapping` — Compare published properties of both types: matching names+compatible types -> `paCopy`, matching names+incompatible types -> flagged, source-only -> `paDelete`, dest-only -> noted
- `GetRegisteredComponentTypes: TArray<String>` — For combo box population. Can use `TRegisteredComponents` from `ComponentManager.pas`

**Note on RTTI availability:** The DPR has `{$WEAKLINKRTTI ON}` which suppresses RTTI for DDevExtensions' own units. This does NOT affect installed component classes in other BPLs — their RTTI is fully available via `GetClass` and `GetPropList`.

### Step 4: CompReplaceEngine.pas — Core Replacement Logic

**Dependencies:** `CompReplaceTypes`, `gllDelphiDFMParser`, `CompReplaceOTAHelper`, `DelphiLexer`, `DelphiDesignerParser`

**Reuses existing parsers** for PAS modification:
- `TDelphiLexer` — `ReplaceToken` (line 1144), `InsertTextAfter` (line 1134), `DeleteToken` (line 1050)
- `TDesignerParser` — Class/field/uses-clause location

**DFM processing algorithm:**
1. Parse DFM via `TDfmDocument.ParseFromText`
2. Walk all `TDfmComponent` nodes recursively
3. For each matching `TypeName`:
   - Change `TypeName` to `DestType`
   - Apply property mappings: rename (`paMap`), keep (`paCopy`), remove (`paDelete`), transform value (`paTransform`)
   - Record result
4. Serialise back via `SerialiseToText`

**PAS processing algorithm (using existing TDelphiLexer):**
1. Parse with `TDesignerParser` to locate the form class and its fields
2. Create `TDelphiLexer` for token-level modification
3. For each replaced component: find field declaration token `ComponentName: TOldType`, use `ReplaceToken` to change `TOldType` -> `TNewType`
4. Process replacements from end-to-start (highest offset first) to preserve token positions
5. Uses clause: find via `TDesignerParser.InterfaceUses`, use `InsertTextAfter` to add `DestUses`, optionally `DeleteTokens` to remove `SourceUses`
6. Return modified source via `Lexer.Text`

**Key methods:**
- `ProcessDfm(aDocument: TDfmDocument; const aMapping: TComponentMapping): TArray<TReplacementResult>`
- `ProcessPasSource(const aPasText: UTF8String; const aMapping: TComponentMapping; const aReplacedComponents: TArray<TReplacementResult>): UTF8String`
- `ProcessFormPair(const aDfmPath, aPasPath: String; const aMapping: TComponentMapping): TArray<TReplacementResult>`
- `ProcessProject(const aMapping: TComponentMapping): TArray<TReplacementResult>`
- `ScanFormPair(const aDfmPath: String; const aMapping: TComponentMapping): TArray<TReplacementResult>` — Preview only, no writes

**File handling for open forms:**
1. Save module if modified
2. Close module via OTA
3. Write modified DFM/PAS to disk
4. Reopen module

### Step 5: CompReplaceMappingStore.pas — XML Persistence

**Dependencies:** `CompReplaceTypes`, `SimpleXmlIntf`, `SimpleXmlImport`

**Reuses:** SimpleXml library — same pattern as `PluginConfig.pas`

**Key methods:**
- `SaveMapping(const aMapping: TComponentMapping; const aFileName: String)`
- `LoadMapping(const aFileName: String): TComponentMapping`
- `SaveToXmlNode / LoadFromXmlNode` — For embedding in the plugin config XML

Mapping files stored in `AppDataDirectory + '\ComponentReplacerMappings\'` (one XML file per mapping).

### Step 6: FrmComponentReplacer.pas + .dfm — Main UI Form

**Inherits from:** `TFormBase`

**Pattern:** Follow `FrmDfmPasConsistency.pas` — singleton `class function Execute`, modeless form with `Show`/`BringToFront`

**Layout:**
- **Top panel**: Source/Dest type combo boxes (populated from `GetRegisteredComponentTypes`), Source/Dest unit edit fields
- **Centre**: Property mappings `TStringGrid` — columns: Source Property, Action (combo), Dest Property, Transform
- **Mapping buttons**: Auto-Map, Add Row, Delete Row
- **Scope**: Radio group — Current Form / Entire Project
- **Action buttons**: Scan (preview), Replace (execute), Load Mapping, Save Mapping, Close
- **Bottom**: Results memo/list for logging

**Auto-Map button:** Calls `CompReplaceOTAHelper.BuildAutoMapping` using RTTI on both component types. Populates the grid with auto-generated mappings. Graceful fallback if types not registered (show warning, allow manual entry).

### Step 7: FrmeOptionPageComponentReplacer.pas + .dfm — Options Page

**Inherits from:** `TFrameBase`, implements `ITreePageComponent`

**Pattern:** Follow `FrmeOptionPageDfmPas.pas` exactly:
- `chkEnabled` checkbox
- `SetUserData` stores plugin reference
- `LoadData` / `SaveData` read/write `Enabled` property

### Step 8: ComponentReplacer.pas — Plugin Registration

**Pattern:** Follow `DfmPasConsistency.pas` exactly:

```
TComponentReplacerPlugin = class(TPluginConfig)
  - FMenuItem: TMenuItem
  - FEnabled: Boolean (published, auto-serialised)
  - Constructor: inherited Create(AppDataDirectory + '\ComponentReplacer.xml', 'ComponentReplacer')
    then add menu item to DDevExtensionsMenu with caption 'Component &Replacer...'
  - MenuItemClick: calls FrmComponentReplacer.TFormComponentReplacer.Execute
  - GetOptionPages: returns TTreePage.Create('Component Replacer', TFrameOptionPageComponentReplacer, Self)
  - Init: FEnabled := True

var ComponentReplacerPlugin: TComponentReplacerPlugin;

procedure InitPlugin(Unload: Boolean);
  if not Unload then Create else FreeAndNil
```

---

## Files to Modify

### `DelphiExtension.inc` (line 62)
Add after `{$DEFINE INCLUDE_LIBRARYPATHSORTER}`:
```pascal
{$DEFINE INCLUDE_COMPONENTREPLACER}
```

### `RegisterPlugins.pas`
**Uses clause** — Add before `StartParameterManagerReg` (line 68):
```pascal
{$IFDEF INCLUDE_COMPONENTREPLACER}
ComponentReplacer,
{$ENDIF INCLUDE_COMPONENTREPLACER}
```

**RegisterIDEPlugins body** — Add after LibraryPathSorter block (after line 222), fitting under the "Organise" category in the menu ordering:
```pascal
{$IFDEF INCLUDE_COMPONENTREPLACER}
if DisabledPlugins.IndexOf('ComponentReplacer') = -1 then
  RegisterLateLoader(ComponentReplacer.InitPlugin);
{$ENDIF INCLUDE_COMPONENTREPLACER}
```

### `DDevExtensions.dpr` (D_D130, line 137)
Change `{FormLibraryPathSorter};` to `{FormLibraryPathSorter},` and add:
```pascal
  gllDelphiDFMParser in '..\..\..\Shared\PascalParser\gllDelphiDFMParser.pas',
  CompReplaceTypes in '..\Source\ComponentReplacer\CompReplaceTypes.pas',
  CompReplaceOTAHelper in '..\Source\ComponentReplacer\CompReplaceOTAHelper.pas',
  CompReplaceEngine in '..\Source\ComponentReplacer\CompReplaceEngine.pas',
  CompReplaceMappingStore in '..\Source\ComponentReplacer\CompReplaceMappingStore.pas',
  ComponentReplacer in '..\Source\ComponentReplacer\ComponentReplacer.pas',
  FrmComponentReplacer in '..\Source\ComponentReplacer\FrmComponentReplacer.pas' {FormComponentReplacer},
  FrmeOptionPageComponentReplacer in '..\Source\ComponentReplacer\FrmeOptionPageComponentReplacer.pas' {FrameOptionPageComponentReplacer: TFrame};
```

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| **Binary DFM files** | Detect `TPF0` magic bytes, refuse with clear error. Modern Delphi uses text DFMs. |
| **Visual form inheritance** (`inherited` keyword) | Only modify properties overridden in descendant. Warn user that ancestor forms need separate processing. |
| **Open form state** | Close module via OTA before writing, then reopen. Sequence: save -> close -> write -> reopen. |
| **RTTI unavailable** (component type not installed) | Auto-map is optional. Allow fully manual property mapping entry. Show warning if `GetClass` returns nil. |
| **PAS token offset invalidation** | Process replacements from end-to-start (highest offset first), matching existing pattern in codebase. |
| **Encoding preservation** | Use `LoadTextFileToUtf8String` (captures encoding), write back with matching encoding. |

---

## Verification

1. **DFM parser round-trip test**: Parse real DFM files from the Delphi installation, serialise back, compare byte-for-byte
2. **DFM modification test**: Create test DFMs with known components, run engine, verify type names and properties changed correctly
3. **PAS modification test**: Create sample form units, run engine, verify field declarations and uses clauses updated
4. **IDE integration test**: Build DDevExtensions, install in Delphi 13, open Tools > DDevExtensions > Component Replacer, verify:
   - Source/Dest combo boxes populate
   - Auto-Map generates sensible mappings for installed component types
   - Scan previews matches without changing files
   - Replace modifies DFM+PAS correctly and IDE reloads the form
   - Backup files created before modification
   - Options page appears in DDevExtensions settings
5. **Batch test**: Create multi-form test project, run with "Entire Project" scope, verify all forms processed

---

## Summary

**8 new files** to create + **3 existing files** to modify. Build order follows dependency chain: Types -> DFM Parser -> OTA Helper -> Engine -> Mapping Store -> UI -> Options Page -> Registration. The DFM parser (Step 2) is the critical path — invest time getting lossless round-tripping right before building the engine on top.
