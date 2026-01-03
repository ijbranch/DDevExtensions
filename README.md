# DDevExtensions

With full acknowledgement of Andreas Hausladen .  His Homepage: https://www.idefixpack.de/ddev

In addition, to anybody else who has contributed over the years.

The Remove PixelsPerInch and Remove TextHeight features (v3.2) are based on work from the DelphiPraxis fork: https://github.com/DelphiPraxis/DDevExtensions

DDevExtensions adds new features to RAD Studio.

This version has been extensively re-worked for Delphi 10.2 and up.  Any identified issues have been resolved.  New features have been added.

Version 3.0 was set to clearly break from the old version 2.88. 

Version 3.1 adds code metrics (LOC and Cyclomatic Complexity) to the Build Statistics feature, plus three new code quality tools: TODO/FIXME Aggregator, Code Style Checker, and Dead Code Detector.

Version 3.2 adds two Form Designer options to prevent PixelsPerInch and TextHeight properties from being saved to DFM files, eliminating phantom changes caused by different DPI settings and font rendering across developer machines.

> **Note:** DDevExtensions only supports the 32-bit IDE (bds.exe).
>
> A 64-bit version was attempted but proved too daunting for Claude and myself.

## Supported Delphi Versions

- Delphi 10.2 Tokyo
- Delphi 10.3 Rio
- Delphi 10.4 Sydney
- Delphi 11.0 Alexandria
- Delphi 12.0 Athens
- Delphi 13.0 Florence

For older Delphi versions (2009-10.1), see the original repository or DelphiPraxis fork.

## Releases

### Delphi 2009-10.2

Releases are available at https://www.idefixpack.de/ddev


## Compile

Open the appropriate `Code\DDevExtensions\D_Dxxx\DDevExtensions.groupproj` for your Delphi version and build all projects.

The project group includes:
1. **CompileInterceptorW** - Compiler interceptor library (built first automatically)
2. **DDevExtensions** - Main extension DLL
3. **DDevExtensionsReg** - Installer application


## How to install

Simply start the DDevExtensionsReg.exe.

This will copy files to $(APPDATA)\DDevExtensions and it registers the expert DLLs
in the registry.


## How to uninstall

Start the InstallDDevExtensions.exe and press the <Uninstall> button.


## Source Structure

```
DDevExtensions/
├── README.md                      # This file
├── LICENSE                        # License file
├── Help.md                        # Help documentation
│
├── Code/DDevExtensions/           # Main extension project
│   ├── build.bat                  # Build script
│   ├── clean.bat                  # Clean script
│   ├── version.bat                # Version script
│   ├── Version.rc/.res            # Version resource
│   │
│   ├── Bin/                       # Build output
│   │   ├── DDevExtensionsD130.dll # Extension DLL
│   │   ├── DDevExtensionsReg.exe  # Installer
│   │   └── CompileInterceptorW.dll
│   │
│   ├── D_D102/                    # Delphi 10.2 Tokyo project
│   ├── D_D103/                    # Delphi 10.3 Rio project
│   ├── D_D104/                    # Delphi 10.4 Sydney project
│   ├── D_D110/                    # Delphi 11.0 Alexandria project
│   ├── D_D120/                    # Delphi 12.0 Athens project
│   ├── D_D130/                    # Delphi 13.0 Florence project
│   │   ├── DDevExtensions.dpr
│   │   ├── DDevExtensions.dproj
│   │   ├── DDevExtensions.groupproj
│   │   └── lib/                   # Compiled DCU files
│   │
│   ├── Doc/                       # Documentation
│   │   ├── Features.docx
│   │   └── StartParameters.txt
│   │
│   ├── Installer/                 # Installer project
│   │   ├── DDevExtensionsReg.dpr
│   │   ├── DDevExtensionsReg.dproj
│   │   └── Main.pas/.dfm
│   │
│   └── Source/                    # Main source code
│       ├── Main.pas               # Main plugin registration
│       ├── RegisterPlugins.pas    # Plugin registration
│       ├── PluginConfig.pas       # Configuration base class
│       ├── AppConsts.pas          # Application constants
│       ├── ComponentManager.pas   # Component management
│       ├── CtrlUtils.pas          # Control utilities
│       ├── EditPopupCtrl.pas      # Edit popup control
│       ├── TaskbarIntf.pas        # Windows taskbar interface
│       ├── VirtTreeHandler.pas    # Virtual tree handler
│       ├── Splash.pas             # Splash screen
│       ├── DtmImages.pas/.dfm     # Image data module
│       ├── FrmDDevExtOptions.pas  # Options dialog
│       ├── FrmeBase.pas/.dfm      # Base frame
│       ├── DelphiExtension.inc    # Compiler directives
│       ├── version.inc            # Version include
│       │
│       ├── CodeStyleChecker/      # Naming convention checker
│       │   ├── CodeStyleChecker.pas
│       │   ├── FrmCodeStyleChecker.pas/.dfm
│       │   └── FrmeOptionPageCodeStyle.pas/.dfm
│       │
│       ├── CompileBackup/         # Pre-compile file backup
│       │   └── FrmeOptionPageCompileBackup.pas/.dfm
│       │
│       ├── CompileProgress/       # Compile progress & Build Statistics
│       │   ├── CompileProgress.pas
│       │   ├── CompilerClearOtherStates.pas
│       │   ├── NativeProgressForm.pas
│       │   ├── UnitMetrics.pas    # LOC and complexity calculation
│       │   ├── FrmBuildStatistics.pas/.dfm
│       │   ├── FrmSwitchToModuleProject.pas/.dfm
│       │   └── FrmeOptionPageCompilerProgress.pas/.dfm
│       │
│       ├── CompilerEnhancements/  # Compiler enhancements
│       │   └── FrmeOptionPageCompilerEnhancements.pas/.dfm
│       │
│       ├── ComponentSelector/     # Quick component search
│       │   ├── ComponentSelector.pas
│       │   └── FrmeOptionPageComponentSelector.pas/.dfm
│       │
│       ├── DeadCodeDetector/      # Unused code detection
│       │   ├── DeadCodeDetector.pas
│       │   ├── FrmDeadCodeDetector.pas/.dfm
│       │   └── FrmeOptionPageDeadCode.pas/.dfm
│       │
│       ├── Debugger/              # Debugger features
│       │   └── StepIntoSkip/
│       │       └── DbgStepIntoSkip.pas
│       │
│       ├── DependencyViewer/      # Unit dependency visualization
│       │   ├── DependencyViewer.pas
│       │   ├── FrmDependencyViewer.pas/.dfm
│       │   └── FrmeOptionPageDependencyViewer.pas/.dfm
│       │
│       ├── DSUFeatures/           # Extended IDE settings
│       │   ├── DSUFeatures.pas
│       │   ├── DisableAlphaSortClassCompletion.pas
│       │   ├── StrucViewSearch.pas
│       │   └── FrmeOptionPageDSUFeatures.pas/.dfm
│       │
│       ├── Editor/                # Editor enhancements
│       │   ├── CodeInsightHandling.pas
│       │   ├── DocModuleHandler.pas
│       │   ├── FocusEditor.pas
│       │   └── FrmReloadFiles.pas/.dfm
│       │
│       ├── ExcelExport/           # Excel export functionality
│       │   └── FrmExcelExport.pas/.dfm
│       │
│       ├── FileCleaner/           # Auto-remove unnecessary files
│       │   └── FrmeOptionPageFileCleaner.pas/.dfm
│       │
│       ├── FileSelector/          # File selector dialog
│       │   └── FrmFileSelector.pas/.dfm
│       │
│       ├── FocusEditor/           # Editor focus handling
│       │   └── FocusEditor.pas
│       │
│       ├── FormDesignerHelpers/   # Form designer enhancements
│       │   ├── LabelMarginHelper.pas
│       │   ├── RemoveExplicitProperty.pas
│       │   ├── RemovePixelsPerInchProperty.pas
│       │   ├── RemoveTextHeightProperty.pas
│       │   └── FrmeOptionPageFormDesigner.pas/.dfm
│       │
│       ├── IDEMenuHandler/        # IDE menu handling
│       │   └── IDEMenuHandler.pas
│       │
│       ├── Images/                # Image resources
│       │   ├── DDevExtensionsLogo.bmp/.svg
│       │   └── (other icons and images)
│       │
│       ├── Keybindings/           # Enhanced keyboard shortcuts
│       │   └── FrmeOptionPageKeybindings.pas/.dfm
│       │
│       ├── OldPalette/            # Old-style component palette
│       │   ├── ComponentPanel.pas/.res
│       │   ├── OldPalette.pas/.dfm
│       │   └── FrmeOptionPageOldPalette.pas/.dfm
│       │
│       ├── ProjectSettings/       # Project settings management
│       │   ├── ProjectSettings.pas
│       │   ├── ProjectSettingsData.pas
│       │   ├── FrmProjectSettingManageSettings.pas/.dfm
│       │   ├── FrmProjectSettingsEditOptions.pas/.dfm
│       │   └── FrmProjectSettingsSetVersioninfo.pas/.dfm
│       │
│       ├── StartParameterManager/ # Start parameter management
│       │   ├── StartParameterClasses.pas
│       │   ├── StartParameterCtrl.pas
│       │   └── StartParameterManagerReg.pas
│       │
│       ├── StartParameterTeam/    # Team start parameters
│       │   └── FrmeOptionPageStartParameterTeam.pas/.dfm
│       │
│       ├── TodoAggregator/        # TODO/FIXME comment scanner
│       │   ├── TodoAggregator.pas
│       │   ├── FrmTodoAggregator.pas/.dfm
│       │   └── FrmeOptionPageTodoAggregator.pas/.dfm
│       │
│       ├── UnitSelector/          # Find Unit / Use Unit dialog
│       │   └── FrmeOptionPageUnitSelector.pas/.dfm
│       │
│       └── UnusedUnitDetector/    # Unused unit detection
│           ├── UnusedUnitDetector.pas
│           ├── FrmUnusedUnitDetector.pas/.dfm
│           └── FrmeOptionPageUnusedUnitDetector.pas/.dfm
│
├── CompileInterceptor/            # Compiler interceptor library
│   ├── build.bat
│   ├── buildAnsi.bat
│   ├── Bin/                       # Build output
│   │   ├── CompileInterceptor.dll
│   │   └── CompileInterceptorW.dll
│   ├── Example/                   # Example project
│   │   └── ExampleCompileInterceptor.dpr
│   ├── lib/                       # Compiled DCU files
│   └── Source/
│       ├── CompileInterceptorW.dpr/.dproj
│       ├── CompilerHooks.pas
│       ├── FileStreams.pas
│       ├── IdeDllNames.pas
│       ├── InterceptImpl.pas
│       ├── InterceptIntf.pas
│       ├── InterceptLoader.pas
│       └── ToolsAPIIntf.pas
│
├── Shared/                        # Shared utilities
│   ├── FileStreams.pas
│   ├── Hooking.pas
│   ├── ImportHooking.pas
│   │
│   ├── IDE/                       # IDE utilities
│   │   ├── FrmBase.pas/.dfm
│   │   ├── HtHint.pas
│   │   ├── IDEHooks.pas
│   │   ├── IDENotifiers.pas
│   │   ├── IDEUtils.pas
│   │   ├── ModuleData.pas
│   │   ├── ProjectData.pas
│   │   ├── ProjectResource.pas
│   │   ├── ToolsAPIHelpers.pas
│   │   ├── UnitVersionInfo.pas
│   │   └── Options/
│   │       ├── FrmOptions.pas/.dfm
│   │       └── FrmTreePages.pas/.dfm
│   │
│   ├── PascalParser/              # Pascal lexer/parser
│   │   ├── DelphiDesignerParser.pas
│   │   ├── DelphiExpr.pas
│   │   ├── DelphiLexer.pas
│   │   ├── DelphiParser.inc
│   │   ├── DelphiParserContainers.pas
│   │   └── DelphiPreproc.pas
│   │
│   └── Xml/                       # XML utilities
│       ├── SimpleXmlDoc.pas
│       ├── SimpleXmlImport.pas
│       └── SimpleXmlIntf.pas
│
└── Tools/                         # Additional tools
    └── LinkMapFile/
        └── ReadMe.md
```

### Key Files

| File | Purpose |
|------|---------|
| `Code/.../Source/Main.pas` | Registers all plugins with the IDE |
| `Code/.../Source/PluginConfig.pas` | Base class for plugin settings (XML storage) |
| `Code/.../Source/RegisterPlugins.pas` | Plugin registration logic |
| `Shared/PascalParser/DelphiLexer.pas` | Tokenizes Pascal source code |
| `Shared/PascalParser/DelphiDesignerParser.pas` | Extracts class/method structure |
| `Code/.../Source/CompileProgress/UnitMetrics.pas` | Calculates LOC and cyclomatic complexity |
| `Shared/IDE/ToolsAPIHelpers.pas` | Tools API helper functions |
| `Shared/IDE/Options/FrmTreePages.pas` | Options dialog framework |

### Adding a New Feature

1. Create a new folder under `Source/`
2. Create the plugin unit (use existing plugins as templates)
3. Create form/options page if needed
4. Register in `Main.pas` via `RegisterLateLoader`
5. Add units to all D_Dxxx project files


## Features

### Editor

**Disable Source Formatter hotkey** (default: off)
Prevents the IDE's source formatter from being triggered accidentally. Useful if you prefer manual formatting or use a different formatting tool.

**Editor tab double click action** (default: zoom)
Configures what happens when you double-click an editor tab. Options include zooming the editor to full screen or super-zoom mode for distraction-free coding.

**Structure View Search** (default: no hotkey)
Adds a search box to the Structure View panel, allowing you to quickly filter and find methods, properties, and other elements in large units. Assign a hotkey for quick access.

**Enhanced Key Bindings** (default: on)
Provides additional keyboard shortcuts and improved cursor navigation:
- Tab key indents selected lines
- Extended Home key behavior (toggle between start of text and start of line)
- Improved Ctrl+Left/Right word navigation
- Alt+Up/Down to move lines or blocks of code
- Ctrl+Click on identifier to find declaration

**Replace Open File At Cursor** (default: off)
Replaces the default "Open File At Cursor" behavior with an enhanced version that provides better file resolution and search capabilities.

### Form Designer

**Set TLabel.Margins.Bottom to zero** (default: on)
Automatically sets the bottom margin of TLabel components to zero when created in the form designer. Prevents unwanted spacing issues in form layouts.

**Remove Explicit\* properties** (default: off)
Prevents ExplicitLeft, ExplicitTop, ExplicitWidth, and ExplicitHeight properties from being saved to DFM files. Reduces form file clutter and avoids merge conflicts in version control.

**New in 3.2 - Remove PixelsPerInch property** (default: off)
Prevents the PixelsPerInch property from being saved to DFM files. Eliminates DPI-related phantom changes when developers with different monitor configurations open the same form.

**New in 3.2 - Remove TextHeight property** (default: off)
Prevents the TextHeight property from being saved to DFM files. Eliminates font-rendering related phantom changes across different machines.

### Component Palette

**Component Selector** (default: off, no hotkey)
Provides a searchable popup dialog for quickly finding and selecting components. Faster than scrolling through the component palette, especially when you know the component name.

### Compiler/Build

**Auto-save editor files after successful compile** (default: off)
Automatically saves all modified editor files after a successful compilation. Ensures your source files are always saved when the build succeeds.

**Switch project to current file's project** (default: on)
When compiling a file that belongs to a different project than the active one, prompts you to switch to that project first. Prevents accidentally compiling with wrong project settings.

**Compile Progress improvements**
Adds a progress bar to the compile dialog and shows compilation progress in the Windows taskbar. Provides visual feedback during long compilations.

**Release compiler unit cache before compiling** (default: off)
Clears the compiler's internal unit cache before each build. Can help resolve rare caching issues at the cost of slightly longer compile times. A "High" option releases even more aggressively.

**File Cleaner** (default: on)
Automatically removes unnecessary files after saving, such as .ddp files and empty Model/History folders. Keeps your project directories clean.

**Compile Backup** (default: on)
Creates backup copies of files before compilation. Provides a safety net in case compilation modifies files unexpectedly.

**New in 3.0 - Build Time Statistics** (default: off)
Tracks how long each unit takes to compile and displays the results in a sortable list. Helps identify slow-compiling units and optimize build times. Features include:
- Per-unit compile time tracking in milliseconds
- **New in 3.1** - Lines of Code (LOC) per unit
- **New in 3.1** - Cyclomatic Complexity per unit (measures code complexity based on decision points)
- Sortable columns (unit name, duration, LOC, complexity, file path)
- Summary statistics: total units, total LOC, average complexity
- Double-click to open unit in editor
- Export to CSV for further analysis
- Copy selected entries to clipboard
Access via Tools menu → "Build Statistics..." when enabled. Can also auto-show after each compile.

### Project Manager

**Show project for active file in Project Manager** (default: on)
Highlights and expands the project node in Project Manager that contains the currently active editor file. Makes it easier to locate files in large project groups.

**Set Project Versioninfo dialog**
Provides a dialog to set version information across multiple projects in a project group simultaneously. Useful for coordinating version numbers across related projects.

**Project Start Parameters** (default: off)
Allows you to define and manage multiple sets of command-line parameters for running your application. Quickly switch between different debug configurations.

### IDE

**Disable Package Cache** (default: off)
Disables the IDE's package caching mechanism. Can help resolve issues with packages not being reloaded properly after changes.

**Find Unit/Use Unit replacement dialog** (default: on)
Replaces the standard Find Unit and Use Unit dialogs with an enhanced version featuring better search, filtering, and file preview capabilities.

**Improved reload changed files dialog**
Enhances the dialog that appears when external file changes are detected. Provides better information and more control over how changed files are handled.

**Show all inheritable modules** (default: off)
Shows all available forms and data modules in the inheritance dialog, not just those from the current project. Useful when inheriting from forms in packages.

**Kill all dexplore.exe when closing the IDE** (default: on)
Automatically terminates any running instances of the Document Explorer (dexplore.exe) when the IDE closes. Prevents orphaned help viewer processes.

**New in 3.0 - Dependency Viewer** (default: off)
Shows a visual tree of unit dependencies within your project. Helps developers understand code structure and identify potential issues. Features include:

- Tree view of all project units with their dependencies
- Separate display of interface and implementation uses clauses
- Circular reference detection with visual indicators
- Filter/search to find specific units
- Double-click to open unit in editor
- Expand/collapse all for quick navigation
Access via Tools menu → "Dependency Viewer..." when enabled.

**New in 3.0 - Unused Unit Detector** (default: off)
Scans your project for units in uses clauses that aren't actually referenced in code. Helps reduce compile times and clean up unnecessary dependencies. Features include:

- Detects unused units in both interface and implementation sections
- Shows source file, unused unit name, section, and line number
- Double-click to navigate directly to the uses clause
- Right-click → "Add to Ignore List" to exclude false positives (e.g., component registration units)
- Ignore list also configurable via DDevExtensions Options
- Export results to CSV or copy to clipboard
Access via Tools menu → "Unused Unit Detector..." when enabled.

**New in 3.1 - TODO/FIXME Aggregator** (default: on)
Scans your project for TODO, FIXME, HACK, BUG, NOTE, and other comment markers and displays them in a centralized list. Features include:

- Detects common patterns: TODO, FIXME, HACK, BUG, NOTE, XXX
- Parses optional priority: TODO(high):, FIXME(low):
- Filter by category and priority
- Sortable columns (unit, category, priority, line, text)
- Double-click to navigate to source line
- Export to CSV or copy to clipboard
- Configurable patterns via DDevExtensions Options
Access via Tools menu → "TODO/FIXME Aggregator..." when enabled.

**New in 3.1 - Code Style Checker** (default: on)
Checks your code for Delphi naming convention compliance. Features include:

- Type names should start with T (e.g., TMyClass)
- Interface names should start with I (e.g., IMyInterface)
- Field names should start with F (e.g., FMyField)
- Exception types should start with E (e.g., EMyError)
- Pointer types should start with P (e.g., PMyRecord)
- Parameter names should start with A (optional, off by default)
- Filter by rule type and severity
- Double-click to navigate to source
- Export to CSV or copy to clipboard
- Enable/disable individual rules via DDevExtensions Options
Access via Tools menu → "Code Style Checker..." when enabled.

**New in 3.1 - Dead Code Detector** (default: on)
Detects procedures, functions, and fields that are never referenced in your project. Features include:

- Detects unused procedures and functions
- Detects unused private and protected fields
- Automatically ignores: virtual/override methods, constructors/destructors, event handlers, published members
- Filter by element type (Procedure, Function, Field) and scope
- Wildcard ignore patterns (e.g., *Click, Get*)
- Double-click to navigate to source
- Right-click → "Add to Ignore List" for false positives
- Export to CSV or copy to clipboard
Access via Tools menu → "Dead Code Detector..." when enabled.

### Debugger

**Don't break when starting spawned processes** (default: off)
Prevents the debugger from breaking into newly spawned child processes. Useful when debugging applications that launch other executables.

**Show confirmation dialog for Ctrl+F1 while debugging** (default: on)
Shows a confirmation prompt before opening context-sensitive help (Ctrl+F1) during a debug session. Prevents accidentally interrupting debugging to view help.

---

*Version: 3.2.1 – 4 January 2026*
