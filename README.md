# DDevExtensions

With full acknowledgement of Andreas Hausladen .  His Homepage: https://www.idefixpack.de/ddev

In addition, to anybody else who has contributed over the years.

DDevExtensions adds new features to RAD Studio.

This version has been extensively re-worked for Delphi 10.2 and up.  Any identified issues have been resolved.  A couple of new functions.options have been added.

This version is set as version 3.00 to clearly break from the old version 2.88, 

> **Note:** DDevExtensions only supports the 32-bit IDE (bds.exe).
>
> 

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

Open `Code\DDevExtensions\D_D130\DDevExtensions.dproj` in the Delphi 13 IDE and build.


## How to install

Simply start the DDevExtensionsReg.exe.

This will copy files to $(APPDATA)\DDevExtensions and it registers the expert DLLs
in the registry.


## How to uninstall

Start the InstallDDevExtensions.exe and press the <Uninstall> button.


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

**New - Build Time Statistics** (default: off)
Tracks how long each unit takes to compile and displays the results in a sortable list. Helps identify slow-compiling units and optimize build times. Features include:
- Per-unit compile time tracking in milliseconds
- Sortable columns (unit name, file path, duration)
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

**New - Dependency Viewer** (default: off)
Shows a visual tree of unit dependencies within your project. Helps developers understand code structure and identify potential issues. Features include:

- Tree view of all project units with their dependencies
- Separate display of interface and implementation uses clauses
- Circular reference detection with visual indicators
- Filter/search to find specific units
- Double-click to open unit in editor
- Expand/collapse all for quick navigation
Access via Tools menu → "Dependency Viewer..." when enabled.

**New - Unused Unit Detector** (default: off)
Scans your project for units in uses clauses that aren't actually referenced in code. Helps reduce compile times and clean up unnecessary dependencies. Features include:

- Detects unused units in both interface and implementation sections
- Shows source file, unused unit name, section, and line number
- Double-click to navigate directly to the uses clause
- Right-click → "Add to Ignore List" to exclude false positives (e.g., component registration units)
- Ignore list also configurable via DDevExtensions Options
- Export results to CSV or copy to clipboard
Access via Tools menu → "Unused Unit Detector..." when enabled.

### Debugger

**Don't break when starting spawned processes** (default: off)
Prevents the debugger from breaking into newly spawned child processes. Useful when debugging applications that launch other executables.

**Show confirmation dialog for Ctrl+F1 while debugging** (default: on)
Shows a confirmation prompt before opening context-sensitive help (Ctrl+F1) during a debug session. Prevents accidentally interrupting debugging to view help.

---

*Version: 1 – 2 January 2026 @ 1315*
