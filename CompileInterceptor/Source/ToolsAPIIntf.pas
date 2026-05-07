{******************************************************************************}
{*                                                                            *}
{* CompileInterceptor IDE Plugin                                              *}
{*                                                                            *}
{* (C) 2006-2013 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

// WARNING: IOTAModule must be adjusted as well as IOTAProject because IOTAProject40 derives from it.
//          So much for the "backward compatible" OpenTools API.

unit ToolsAPIIntf;

/// <summary>
/// Hand-written subset of the Delphi Open Tools API (ToolsAPI / IOTAxxx) interfaces and
/// helpers used by CompileInterceptor. Mirrors the official ToolsAPI just enough for the
/// hooks unit to query the active project, walk options and add IDE notifiers - without
/// taking a build dependency on a specific Delphi version's <c>ToolsAPI.pas</c>.
/// </summary>

interface

uses
  Windows, SysUtils, TypInfo, Classes, ActiveX;

{ Possible values for TOTAModuleType }
/// <summary>Module type: a VCL form (<c>.dfm</c>).</summary>
const
  omtForm          = 0;
  /// <summary>Module type: a data module.</summary>
  omtDataModule    = 1;
  /// <summary>Module type: the project source file (<c>.dpr</c>/<c>.dpk</c>).</summary>
  omtProjUnit      = 2;
  /// <summary>Module type: a regular Pascal unit.</summary>
  omtUnit          = 3;
  /// <summary>Module type: a resource script (<c>.rc</c>).</summary>
  omtRc            = 4;
  /// <summary>Module type: an assembly source file.</summary>
  omtAsm           = 5;
  /// <summary>Module type: a module-definition file.</summary>
  omtDef           = 6;
  /// <summary>Module type: an object file (<c>.obj</c>).</summary>
  omtObj           = 7;
  /// <summary>Module type: a compiled resource file (<c>.res</c>).</summary>
  omtRes           = 8;
  /// <summary>Module type: a library.</summary>
  omtLib           = 9;
  /// <summary>Module type: a type library.</summary>
  omtTypeLib       = 10;
  /// <summary>Module type: an imported package.</summary>
  omtPackageImport = 11;
  /// <summary>Module type: a form resource.</summary>
  omtFormResource  = 12;
  /// <summary>Module type: a custom (designer-defined) module.</summary>
  omtCustom        = 13;
  /// <summary>Module type: an IDL file.</summary>
  omtIDL           = 14;

  /// <summary>Default personality identifier used for unclassified file types.</summary>
  sDefaultPersonality = 'Default.Personality';
  /// <summary>Borland-defined personality identifier for the Delphi Win32/Win64 compiler.</summary>
  sDelphiPersonality = 'Delphi.Personality';
  /// <summary>Borland-defined personality identifier for the legacy Delphi.NET compiler.</summary>
  sDelphiDotNetPersonality = 'DelphiDotNet.Personality';
  /// <summary>Borland-defined personality identifier for C++Builder.</summary>
  sCBuilderPersonality = 'CPlusPlusBuilder.Personality';
  /// <summary>Borland-defined personality identifier for the C# personality.</summary>
  sCSharpPersonality = 'CSharp.Personality';
  /// <summary>Borland-defined personality identifier for the Visual Basic personality.</summary>
  sVBPersonality = 'VB.Personality';
  /// <summary>Borland-defined personality identifier for the design-time personality.</summary>
  sDesignPersonality = 'Design.Personality';
  /// <summary>Borland-defined personality identifier for generic (language-agnostic) modules.</summary>
  sGenericPersonality = 'Generic.Personality';

type
  /// <summary>Forward declaration so <see cref="IOTAEditor"/> can refer to <c>IOTAModule</c>.</summary>
  IOTAModule = interface;
  /// <summary>Forward declaration so <see cref="IOTAModule40"/> can refer to <c>IOTAProject</c>.</summary>
  IOTAProject = interface;

  {$IF CompilerVersion >= 21.0}
  /// <summary>Generic string array alias used for ToolsAPI signatures (Delphi 2010+).</summary>
  TArrayOfString = TArray<string>;
  {$ELSE}
  /// <summary>Open string array alias used for ToolsAPI signatures (pre-Delphi 2010).</summary>
  TArrayOfString = array of string;
  {$IFEND}

  /// <summary>Base notifier interface implemented by all ToolsAPI notifier callbacks.</summary>
  IOTANotifier = interface(IUnknown)
    ['{F17A7BCF-E07D-11D1-AB0B-00C04FB16FB3}']
    /// <summary>Called after the observed object has been saved.</summary>
    procedure AfterSave;
    /// <summary>Called before the observed object is saved.</summary>
    procedure BeforeSave;
    /// <summary>Called when the observed object has been destroyed.</summary>
    procedure Destroyed;
    /// <summary>Called when the observed object is marked modified.</summary>
    procedure Modified;
  end;

  /// <summary>Describes a single project/environment option's name and Variant type kind.</summary>
  TOTAOptionName = record
    /// <summary>Option key.</summary>
    Name: string;
    /// <summary>Variant type kind of the option's value.</summary>
    Kind: TTypeKind;
  end;

  /// <summary>Open array of option name/kind descriptors.</summary>
  TOTAOptionNameArray = array of TOTAOptionName;
  /// <summary>How the IDE should build a project: make, full build, syntax check, or single unit make.</summary>
  TOTACompileMode = (cmOTAMake, cmOTABuild, cmOTACheck, cmOTAMakeUnit);
  /// <summary>Module type integer using the <c>omt*</c> constants above.</summary>
  TOTAModuleType = type Integer;

  /// <summary>Generic options bag (project or environment) with Variant-typed values.</summary>
  IOTAOptions = interface(IUnknown)
    ['{9C0E91FC-FA5A-11D1-AB28-00C04FB16FB3}']
    /// <summary>Shows the IDE editor for these options.</summary>
    procedure EditOptions;
    /// <summary>Returns the current value of the named option.</summary>
    function GetOptionValue(const ValueName: string): Variant;
    /// <summary>Sets the named option's value.</summary>
    procedure SetOptionValue(const ValueName: string; const Value: Variant);
    /// <summary>Returns the full set of option names and kinds exposed by this bag.</summary>
    function GetOptionNames: TOTAOptionNameArray;
    /// <summary>Indexed access to options by name.</summary>
    property Values[const ValueName: string]: Variant read GetOptionValue write SetOptionValue;
  end;

  /// <summary>IDE-wide environment options.</summary>
  IOTAEnvironmentOptions = interface(IOTAOptions)
    ['{9C0E91FB-FA5A-11D1-AB28-00C04FB16FB3}']
  end;

  /// <summary>Per-project options interface (Delphi 4 baseline).</summary>
  IOTAProjectOptions40 = interface(IOTAOptions)
    ['{F17A7BD4-E07D-11D1-AB0B-00C04FB16FB3}']
  end;

  /// <summary>Per-project options interface (Delphi 7 baseline) adding modified-state tracking.</summary>
  IOTAProjectOptions70 = interface(IOTAProjectOptions40)
    ['{F899EBC6-E6E2-11D2-AA90-00C04FA370E9}']
    /// <summary>Sets the project options' modified flag.</summary>
    procedure SetModifiedState(State: Boolean);
    /// <summary>Returns whether the project options have been modified since loading.</summary>
    function GetModifiedState: Boolean;

    /// <summary>Modified flag for project options.</summary>
    property ModifiedState: Boolean read GetModifiedState write SetModifiedState;
  end;

  /// <summary>Per-project options exposing the resolved binary target name.</summary>
  IOTAProjectOptions = interface(IOTAProjectOptions70)
    ['{2888E741-E7FB-4BBC-A093-4B0903D9D990}']
    /// <summary>Returns the resolved output binary file name for the project.</summary>
    function GetTargetName: string;

    /// <summary>Resolved output binary file name for the project.</summary>
    property TargetName: string read GetTargetName;
  end;

  /// <summary>Project builder interface (Delphi 4 baseline).</summary>
  IOTAProjectBuilder40 = interface(IUnknown)
    ['{F17A7BD5-E07D-11D1-AB0B-00C04FB16FB3}']
    /// <summary>Returns whether the project's source has changed since the last build.</summary>
    function GetShouldBuild: Boolean;
    /// <summary>Builds the project; <paramref name="Wait"/> blocks until completion.</summary>
    function BuildProject(CompileMode: TOTACompileMode; Wait: Boolean): Boolean;

    /// <summary>True when the project must be (re)built.</summary>
    property ShouldBuild: Boolean read GetShouldBuild;
  end;

  /// <summary>Project builder interface adding the option to clear the IDE message pane.</summary>
  IOTAProjectBuilder = interface(IOTAProjectBuilder40)
    ['{08A5B1F5-FCDA-11D2-AC82-00C04FB173DC}']
    /// <summary>Builds the project; <paramref name="ClearMessages"/> clears the message pane first.</summary>
    function BuildProject(CompileMode: TOTACompileMode; Wait, ClearMessages: Boolean): Boolean; overload;
  end;

  /// <summary>Notifier for module life-cycle events such as overwrite checks and renames.</summary>
  IOTAModuleNotifier = interface(IOTANotifier)
    ['{F17A7BCE-E07D-11D1-AB0B-00C04FB16FB3}']
    /// <summary>Returns whether the module is allowed to be overwritten on disk.</summary>
    function CheckOverwrite: Boolean;
    /// <summary>Called when the module has been renamed in the IDE.</summary>
    procedure ModuleRenamed(const NewName: string);
  end;

  /// <summary>Editor for one of the files belonging to a module (e.g. <c>.pas</c>, <c>.dfm</c>).</summary>
  IOTAEditor = interface(IUnknown)
    ['{F17A7BD0-E07D-11D1-AB0B-00C04FB16FB3}']
    /// <summary>Adds an editor notifier and returns its registration index.</summary>
    function AddNotifier(const ANotifier: IOTANotifier): Integer;
    /// <summary>Returns the file name backing this editor.</summary>
    function GetFileName: string;
    /// <summary>Returns whether the editor's content has been modified since the last save.</summary>
    function GetModified: Boolean;
    /// <summary>Returns the module that owns this editor.</summary>
    function GetModule: IOTAModule;
    /// <summary>Marks the editor's content as modified; returns whether the state actually changed.</summary>
    function MarkModified: Boolean;
    /// <summary>Removes a previously added editor notifier.</summary>
    procedure RemoveNotifier(Index: Integer);
    /// <summary>Brings this editor to the foreground in the IDE.</summary>
    procedure Show;

    /// <summary>File name backing this editor.</summary>
    property FileName: string read GetFileName;
    /// <summary>True when the editor's content has unsaved changes.</summary>
    property Modified: Boolean read GetModified;
    /// <summary>Module that owns this editor.</summary>
    property Module: IOTAModule read GetModule;
  end;

  /// <summary>Module interface (Delphi 4 baseline) representing one open module/file in the IDE.</summary>
  IOTAModule40 = interface(IUnknown)
    ['{F17A7BCC-E07D-11D1-AB0B-00C04FB16FB3}']
    /// <summary>Adds a module notifier and returns its registration index.</summary>
    function AddNotifier(const ANotifier: IOTAModuleNotifier): Integer;
    /// <summary>Adds the module to the project's interface (i.e. project source uses clause).</summary>
    procedure AddToInterface;
    /// <summary>Closes the module, prompting to save if needed; returns whether the close succeeded.</summary>
    function Close: Boolean;
    /// <summary>Returns the module's primary file name.</summary>
    function GetFileName: string;
    /// <summary>Returns the file system identifier the module is read through.</summary>
    function GetFileSystem: string;
    /// <summary>Returns the number of editors associated with the module.</summary>
    function GetModuleFileCount: Integer;
    /// <summary>Returns the editor at <paramref name="Index"/>.</summary>
    function GetModuleFileEditor(Index: Integer): IOTAEditor;
    /// <summary>Returns the owner-project count (deprecated; use <see cref="IOTAModule70.GetOwnerModuleCount"/>).</summary>
    function GetOwnerCount: Integer; //deprecated;
    /// <summary>Returns the owner project at <paramref name="Index"/> (deprecated).</summary>
    function GetOwner(Index: Integer): IOTAProject; //deprecated;
    /// <summary>Returns whether the module declares COM coclasses.</summary>
    function HasCoClasses: Boolean;
    /// <summary>Removes a previously added module notifier.</summary>
    procedure RemoveNotifier(Index: Integer);
    /// <summary>Saves the module, optionally prompting for a new name and forcing the write.</summary>
    function Save(ChangeName, ForceSave: Boolean): Boolean;
    /// <summary>Sets the module's primary file name.</summary>
    procedure SetFileName(const AFileName: string);
    /// <summary>Sets the file system identifier the module is read through.</summary>
    procedure SetFileSystem(const AFileSystem: string);

    /// <summary>Owner project count (deprecated).</summary>
    property OwnerCount: Integer read GetOwnerCount;
    /// <summary>Owner projects (deprecated).</summary>
    property Owners[Index: Integer]: IOTAProject read GetOwner;
    /// <summary>Primary file name of the module.</summary>
    property FileName: string read GetFileName write SetFileName;
    /// <summary>File system identifier through which the module is loaded.</summary>
    property FileSystem: string read GetFileSystem write SetFileSystem;
  end;

  /// <summary>Module interface (Delphi 5 baseline) adding forced-close support.</summary>
  IOTAModule50 = interface(IOTAModule40)
    ['{15D3FB81-EF27-488E-B2B4-26B59CA89D9D}']
    /// <summary>Closes the module, optionally without prompting the user.</summary>
    function CloseModule(ForceClosed: Boolean): Boolean;
    /// <summary>Number of editors associated with the module.</summary>
    property ModuleFileCount: Integer read GetModuleFileCount;
    /// <summary>Indexed access to the module's editors.</summary>
    property ModuleFileEditors[Index: Integer]: IOTAEditor read GetModuleFileEditor;
  end;

  /// <summary>Module interface (Delphi 7 baseline) adding owner-module access.</summary>
  IOTAModule70 = interface(IOTAModule50)
    ['{2438BFB8-C742-48CD-8F50-DE6C7F764A55}']
    /// <summary>Returns the active editor for this module.</summary>
    function GetCurrentEditor: IOTAEditor;
    /// <summary>Returns the number of modules that own this module.</summary>
    function GetOwnerModuleCount: Integer;
    /// <summary>Returns the owner module at <paramref name="Index"/>.</summary>
    function GetOwnerModule(Index: Integer): IOTAModule;
    /// <summary>Marks the module as modified.</summary>
    procedure MarkModified;

    /// <summary>The editor currently in focus for this module.</summary>
    property CurrentEditor: IOTAEditor read GetCurrentEditor;
    /// <summary>Number of owner modules.</summary>
    property OwnerModuleCount: Integer read GetOwnerModuleCount;
    /// <summary>Indexed access to owner modules.</summary>
    property OwnerModules[Index: Integer]: IOTAModule read GetOwnerModule;
  end;

  /// <summary>Module interface (Delphi 14 baseline) adding helpers to surface a specific filename.</summary>
  IOTAModule140 = interface(IOTAModule70)
    ['{7FF96161-E610-4414-B8B1-D1ECA76FEAFB}']
    /// <summary>Brings the module to the foreground.</summary>
    procedure Show;
    /// <summary>Brings the module to the foreground showing the editor for <paramref name="FileName"/>.</summary>
    procedure ShowFilename(const FileName: string);
  end;

  /// <summary>Latest module interface adding refresh and associated-file enumeration.</summary>
  IOTAModule = interface(IOTAModule140)
    ['{C0D4CBA8-54A3-48EA-BE63-98CE3D9F0F43}']
    /// <summary>Refreshes the module from disk; <paramref name="ForceRefresh"/> bypasses change checks.</summary>
    procedure Refresh(ForceRefresh: Boolean);
    /// <summary>Populates <paramref name="FileList"/> with the file names associated with this module.</summary>
    procedure GetAssociatedFilesFromModule(FileList: TStrings);
  end;

  /// <summary>Lightweight module descriptor used in project module lists (Delphi 5 baseline).</summary>
  IOTAModuleInfo50 = interface(IUnknown)
    ['{F17A7BD6-E07D-11D1-AB0B-00C04FB16FB3}']
    /// <summary>Returns the module's <c>omt*</c> type.</summary>
    function GetModuleType: TOTAModuleType;
    /// <summary>Returns the module's symbolic name.</summary>
    function GetName: string;
    /// <summary>Returns the module's primary file name.</summary>
    function GetFileName: string;
    /// <summary>Returns the design-time form name (empty for non-form modules).</summary>
    function GetFormName: string;
    /// <summary>Returns the design class associated with the module.</summary>
    function GetDesignClass: string;
    /// <summary>Populates <paramref name="CoClasses"/> with COM coclass names declared in the module.</summary>
    procedure GetCoClasses(CoClasses: TStrings);
    /// <summary>Opens the module in the IDE and returns its <see cref="IOTAModule"/>.</summary>
    function OpenModule: IOTAModule;

    /// <summary>The module's <c>omt*</c> type.</summary>
    property ModuleType: TOTAModuleType read GetModuleType;
    /// <summary>The module's symbolic name.</summary>
    property Name: string read GetName;
    /// <summary>The module's primary file name.</summary>
    property FileName: string read GetFileName;
    /// <summary>The form name for form modules; empty otherwise.</summary>
    property FormName: string read GetFormName;
    /// <summary>The design class name associated with the module.</summary>
    property DesignClass: string read GetDesignClass;
  end;

  /// <summary>Module info (Delphi 16 baseline) adding custom IDs and additional file lists.</summary>
  IOTAModuleInfo160 = interface(IOTAModuleInfo50)
    ['{B3EEB4D2-ECDD-4CDC-B96E-B5C8F6D050A8}']
    /// <summary>Returns the module's custom identifier (used by some designers).</summary>
    function GetCustomId: string;
    /// <summary>Populates <paramref name="Files"/> with extra files associated with the module.</summary>
    procedure GetAdditionalFiles(Files: TStrings);

    /// <summary>The module's custom identifier.</summary>
    property CustomId: string read GetCustomId;
  end;

  /// <summary>Latest module info adding device target and per-module build action.</summary>
  IOTAModuleInfo = interface(IOTAModuleInfo160)
    ['{006DD7BE-55FD-4707-8C7E-3602C9721810}']
    /// <summary>Sets the target device name for the module.</summary>
    procedure SetDeviceName(const Value: string);
    /// <summary>Returns the target device name for the module.</summary>
    function GetDevicename: string;
    /// <summary>Sets the per-module build action (e.g. compile, copy, none).</summary>
    procedure SetBuildAction(const Value: string);
    /// <summary>Returns the per-module build action.</summary>
    function GetBuildAction: string;

    /// <summary>The target device name for the module.</summary>
    property DeviceName: string read GetDeviceName write SetDevicename;
    /// <summary>The per-module build action identifier.</summary>
    property BuildAction: string read GetBuildAction write SetBuildAction;
  end;

  /// <summary>Project interface (Delphi 4 baseline) - a project module exposing build/options access.</summary>
  IOTAProject40 = interface(IOTAModule)
    ['{F17A7BCA-E07D-11D1-AB0B-00C04FB16FB3}']
    /// <summary>Returns the number of source modules in the project.</summary>
    function GetModuleCount: Integer;
    /// <summary>Returns the module info at <paramref name="Index"/>.</summary>
    function GetModule(Index: Integer): IOTAModuleInfo;
    /// <summary>Returns the project's options bag.</summary>
    function GetProjectOptions: IOTAProjectOptions;
    /// <summary>Returns the project's builder.</summary>
    function GetProjectBuilder: IOTAProjectBuilder;

    /// <summary>Project options bag.</summary>
    property ProjectOptions: IOTAProjectOptions read GetProjectOptions;
    /// <summary>Project builder.</summary>
    property ProjectBuilder: IOTAProjectBuilder read GetProjectBuilder;
  end;

  /// <summary>Project interface (Delphi 7 baseline) adding file add/remove operations.</summary>
  IOTAProject70 = interface(IOTAProject40)
    ['{06C88136-F367-4D47-B8B4-CCACB3D7439A}']
    /// <summary>Adds <paramref name="AFileName"/> to the project; <paramref name="IsUnitOrForm"/> distinguishes source from arbitrary file.</summary>
    procedure AddFile(const AFileName: string; IsUnitOrForm: Boolean);
    /// <summary>Removes <paramref name="AFileName"/> from the project.</summary>
    procedure RemoveFile(const AFileName: string);
  end;

  /// <summary>Project interface (Delphi 9 baseline) adding parent-module file linkage and personality info.</summary>
  IOTAProject90 = interface(IOTAProject70)
    ['{BBBE4CC6-36DE-4986-BD9E-9DF0F06FC8F1}']
    /// <summary>Adds a file as a child of <paramref name="Parent"/>.</summary>
    procedure AddFileWithParent(const AFileName: string; IsUnitOrForm: Boolean;
      const Parent: string);
    /// <summary>Returns the project's persistent GUID.</summary>
    function GetProjectGUID: TGUID;
    /// <summary>Returns the project personality identifier (e.g. <c>Delphi.Personality</c>).</summary>
    function GetPersonality: string;
    /// <summary>Locates the module info matching <paramref name="FileName"/>, or returns <c>nil</c>.</summary>
    function FindModuleInfo(const FileName: string): IOTAModuleInfo;

    /// <summary>Persistent project GUID.</summary>
    property ProjectGUID: TGUID read GetProjectGUID;
    /// <summary>Project personality identifier.</summary>
    property Personality: string read GetPersonality;
  end;

  /// <summary>Project interface (Delphi 10 / 2006 baseline) adding rename support.</summary>
  IOTAProject100 = interface(IOTAProject90)
    ['{D0090018-D879-41FC-8F83-AA4F40098ACF}']
    /// <summary>Renames a file within the project; returns whether the rename succeeded.</summary>
    function Rename(const OldFileName, NewFileName: string): Boolean;
  end;

  /// <summary>Project interface (Delphi 12 / 2009 baseline) adding project type query.</summary>
  IOTAProject120 = interface(IOTAProject100)
    ['{3D7E07CB-392D-4EFB-841D-A6C6E338CF13}']
    /// <summary>Returns the project type identifier (e.g. application, package, library).</summary>
    function GetProjectType: string;

    /// <summary>Project type identifier.</summary>
    property ProjectType: string read GetProjectType;
  end;

  /// <summary>Project interface (Delphi 14 / XE baseline) adding file enumeration and transactions.</summary>
  IOTAProject140 = interface(IOTAProject120)
    ['{6B1A57F9-34A3-4824-96F0-750A63328C4E}']
    /// <summary>Populates <paramref name="FileList"/> with the complete set of files in the project.</summary>
    procedure GetCompleteFileList(FileList: TStrings);
    /// <summary>Populates <paramref name="FileList"/> with files associated with <paramref name="FileName"/>.</summary>
    procedure GetAssociatedFiles(const FileName: string; FileList: TStrings);
    /// <summary>Returns the in-progress rename transaction, if any, for <paramref name="FileName"/>.</summary>
    function GetFileTransaction(const FileName: string; var InitialName,
      CurrentName: string): Boolean;
  end;

  /// <summary>Project interface (Delphi 15 / XE2 baseline) adding batched file transaction support.</summary>
  // WARNING: IOTAModule must be adjusted as well because IOTAProject40 derives from it
  IOTAProject150 = interface(IOTAProject140)
    ['{A6287B50-DA09-44EF-AA80-9D1CAFDE7857}']
    /// <summary>Begins a batched file transaction.</summary>
    procedure BeginFileTransactionUpdate;
    /// <summary>Ends a batched file transaction; <paramref name="CommitUpdate"/> commits or rolls back.</summary>
    procedure EndFileTransactionUpdate(CommitUpdate: Boolean);
    /// <summary>Populates <paramref name="FileList"/> with files added or deleted within the current transaction.</summary>
    procedure GetAddedDeletedFiles(const FileList: IInterfaceList);
    /// <summary>Populates <paramref name="FileList"/> with the rename history of <paramref name="FileName"/>.</summary>
    function GetFileTransactionList(const FileName: string; FileList: IInterfaceList): Boolean;
  end;

  /// <summary>Project interface (Delphi 16 / XE2 multi-platform) adding configuration and platform.</summary>
  IOTAProject160 = interface(IOTAProject150)
    ['{F5EA2A72-485D-49E8-B60A-B0E7C7B80A27}']
    /// <summary>Returns the current build configuration name.</summary>
    function GetConfiguration: string;
    /// <summary>Returns the framework type (e.g. <c>VCL</c>, <c>FMX</c>).</summary>
    function GetFrameworkType: string;
    /// <summary>Returns the current target platform identifier.</summary>
    function GetPlatform: string;
    /// <summary>Sets the current build configuration name.</summary>
    procedure SetConfiguration(const Value: string);
    /// <summary>Sets the current target platform identifier.</summary>
    procedure SetPlatform(const Value: string);
    /// <summary>Returns the supported target platform identifiers for this project.</summary>
    function GetSupportedPlatforms: TArrayOfString;

    /// <summary>Current build configuration.</summary>
    property CurrentConfiguration: string read GetConfiguration write SetConfiguration;
    /// <summary>Current target platform.</summary>
    property CurrentPlatform: string read GetPlatform write SetPlatform;
    /// <summary>Framework type identifier.</summary>
    property FrameworkType: string read GetFrameworkType;
    /// <summary>Supported target platform identifiers.</summary>
    property SupportedPlatforms: TArrayOfString read GetSupportedPlatforms;
  end;

  /// <summary>Latest project interface adding application type query.</summary>
  IOTAProject = interface(IOTAProject160)
    ['{0E4BFB1D-2F3B-4CD6-A9A2-4903713B59E0}']
    /// <summary>Returns the application type identifier (e.g. console, GUI).</summary>
    function GetApplicationType: string;

    /// <summary>Application type identifier.</summary>
    property ApplicationType: string read GetApplicationType;
  end;

  /// <summary>IDE file/notification kinds reported through <see cref="IOTAIDENotifier.FileNotification"/>.</summary>
  TOTAFileNotification = (ofnFileOpening, ofnFileOpened, ofnFileClosing,
    ofnDefaultDesktopLoad, ofnDefaultDesktopSave, ofnProjectDesktopLoad,
    ofnProjectDesktopSave, ofnPackageInstalled, ofnPackageUninstalled,
    ofnActiveProjectChanged
    {XE8:, ofnProjectOpenedFromTemplate});

  /// <summary>IDE-level notifier covering file events and (the legacy) compile events.</summary>
  IOTAIDENotifier = interface(IOTANotifier)
    ['{E052204F-ECE9-11D1-AB19-00C04FB16FB3}']
    /// <summary>Called for IDE file/desktop/package notifications.</summary>
    procedure FileNotification(NotifyCode: TOTAFileNotification;
      const FileName: string; var Cancel: Boolean);
    /// <summary>Legacy hook called before a project is compiled.</summary>
    procedure BeforeCompile(const Project: IInterface; var Cancel: Boolean); overload;
    /// <summary>Legacy hook called after a project compile completes.</summary>
    procedure AfterCompile(Succeeded: Boolean); overload;
  end;

  /// <summary>IDE notifier (Delphi 5 baseline) adding code-insight aware overloads.</summary>
  IOTAIDENotifier50 = interface(IOTAIDENotifier)
    ['{AC7D29F1-D9A9-11D2-A8C1-00C04FA32F53}']
    /// <summary>Called before a compile, distinguishing real builds from code-insight passes.</summary>
    procedure BeforeCompile(const Project: IInterface; IsCodeInsight: Boolean;
      var Cancel: Boolean); overload;
    /// <summary>Called after a compile, distinguishing real builds from code-insight passes.</summary>
    procedure AfterCompile(Succeeded: Boolean; IsCodeInsight: Boolean); overload;
  end;

  /// <summary>Top-level IDE services interface (Delphi 5 baseline).</summary>
  IOTAServices50 = interface(IUnknown)
    ['{7FD1CE91-E053-11D1-AB0B-00C04FB16FB3}']
    /// <summary>Adds an IDE notifier and returns its registration index.</summary>
    function AddNotifier(const Notifier: IOTAIDENotifier): Integer;
    /// <summary>Removes a previously added IDE notifier.</summary>
    procedure RemoveNotifier(Index: Integer);
    /// <summary>Returns the IDE's base registry key (e.g. <c>Software\Embarcadero\BDS\37.0</c>).</summary>
    function GetBaseRegistryKey: string;
    /// <summary>Returns a friendly product identifier string.</summary>
    function GetProductIdentifier: string;
    /// <summary>Returns the IDE main window handle for parenting custom dialogs.</summary>
    function GetParentHandle: HWND;
    /// <summary>Returns the environment options bag.</summary>
    function GetEnvironmentOptions: IOTAEnvironmentOptions;
  end;

  /// <summary>IDE services (Delphi 6 baseline) adding active designer type query.</summary>
  IOTAServices60 = interface(IOTAServices50)
    ['{577ECE00-59EE-4F21-8190-9FD8A45FE550}']
    /// <summary>Returns the type identifier of the currently active designer.</summary>
    function GetActiveDesignerType: string;
  end;

  /// <summary>IDE services (Delphi 7 baseline) exposing IDE installation directories.</summary>
  IOTAServices70 = interface(IOTAServices60)
    ['{0044BB24-425D-D611-9CF1-00C04FA06AFC}']
    /// <summary>Returns the IDE root installation directory.</summary>
    function GetRootDirectory: string;
    /// <summary>Returns the IDE bin directory.</summary>
    function GetBinDirectory: string;
    /// <summary>Returns the IDE template directory.</summary>
    function GetTemplateDirectory: string;
  end;

  /// <summary>IDE services (Delphi 10 / 2006 baseline) adding application data directory.</summary>
  IOTAServices100 = interface(IOTAServices70)
    ['{33B33186-3CEC-4624-970E-417A8FE14089}']
    /// <summary>Returns the per-user roaming application data directory for the IDE.</summary>
    function GetApplicationDataDirectory: string;
  end;

  /// <summary>IDE services adding local (non-roaming) application data directory.</summary>
  IOTAServices110 = interface(IOTAServices100)
    ['{17A48937-2C9C-4543-AB6D-2CF13BAE544B}']
    /// <summary>Returns the per-user local (non-roaming) application data directory for the IDE.</summary>
    function GetLocalApplicationDataDirectory: string;
  end;

  /// <summary>IDE services (Delphi 14 / XE baseline) exposing the preferred UI language list.</summary>
  IOTAServices140 = interface(IOTAServices110)
    ['{80E56DFA-82B2-425A-921E-8E5ED6164A11}']
    /// <summary>Returns the IDE's preferred UI languages as a delimited string.</summary>
    function GetIDEPreferredUILanguages: string;
  end;

  /// <summary>IDE services adding startup directory and project-file probing.</summary>
  IOTAServices160 = interface(IOTAServices140)
    ['{86602DE0-50BF-4AE5-BAF4-D9438BD33218}']
    /// <summary>Returns the directory the IDE was started from.</summary>
    function GetStartupDirectory: string;
    /// <summary>Returns whether <paramref name="FileName"/> is a project file recognised by the IDE.</summary>
    function IsProject(const FileName: string): Boolean;
    /// <summary>Returns whether <paramref name="FileName"/> is a project group file.</summary>
    function IsProjectGroup(const FileName: string): Boolean;
    /// <summary>Persists <paramref name="Stream"/> to a temporary location and returns the file name.</summary>
    function SaveStream(const Stream: IStream): string;
  end;

  /// <summary>Latest IDE services adding root-macro expansion.</summary>
  IOTAServices = interface(IOTAServices160)
    ['{D1358CFB-9B5C-4E6C-BC4B-C6D06C6689C1}']
    /// <summary>Expands <c>$(BDS)</c>-style macros in <paramref name="S"/>.</summary>
    function ExpandRootMacro(const S: string): string;
  end;

  /// <summary>Marker interface for the IDE's service-provider singleton.</summary>
  IBorlandIDEServices = interface(IInterface)
    ['{7FD1CE92-E053-11D1-AB0B-00C04FB16FB3}']
  end;

  {------------------------------------------------------------------------}

  { Corrected Interfaces for Delphi 9 to 2010 }

  /// <summary>
  /// <see cref="IOTAProject40"/> rebound to <see cref="IOTAModule140"/> for Delphi 9 to 2010,
  /// because the official ToolsAPI inheritance chain in those versions diverges from the
  /// hierarchy used at the latest baseline. CompileInterceptor uses these "_140" aliases to
  /// resolve the project options without crashing on those IDE versions.
  /// </summary>
  IOTAProject40_140 = interface(IOTAModule140)
    ['{F17A7BCA-E07D-11D1-AB0B-00C04FB16FB3}']
    /// <summary>Returns the number of source modules in the project.</summary>
    function GetModuleCount: Integer;
    /// <summary>Returns the module info at <paramref name="Index"/>.</summary>
    function GetModule(Index: Integer): IOTAModuleInfo;
    /// <summary>Returns the project's options bag.</summary>
    function GetProjectOptions: IOTAProjectOptions;
    /// <summary>Returns the project's builder.</summary>
    function GetProjectBuilder: IOTAProjectBuilder;

    /// <summary>Project options bag.</summary>
    property ProjectOptions: IOTAProjectOptions read GetProjectOptions;
    /// <summary>Project builder.</summary>
    property ProjectBuilder: IOTAProjectBuilder read GetProjectBuilder;
  end;

  /// <summary>Delphi 9-2010 corrected variant of <see cref="IOTAProject70"/>.</summary>
  IOTAProject70_140 = interface(IOTAProject40_140)
    ['{06C88136-F367-4D47-B8B4-CCACB3D7439A}']
    /// <summary>Adds <paramref name="AFileName"/> to the project.</summary>
    procedure AddFile(const AFileName: string; IsUnitOrForm: Boolean);
    /// <summary>Removes <paramref name="AFileName"/> from the project.</summary>
    procedure RemoveFile(const AFileName: string);
  end;

  /// <summary>Delphi 9-2010 corrected variant of <see cref="IOTAProject90"/> exposing personality info.</summary>
  IOTAProject90_140 = interface(IOTAProject70_140)
    ['{BBBE4CC6-36DE-4986-BD9E-9DF0F06FC8F1}']
    /// <summary>Adds a file as a child of <paramref name="Parent"/>.</summary>
    procedure AddFileWithParent(const AFileName: string; IsUnitOrForm: Boolean;
      const Parent: string);
    /// <summary>Returns the project's persistent GUID.</summary>
    function GetProjectGUID: TGUID;
    /// <summary>Returns the project personality identifier.</summary>
    function GetPersonality: string;
    /// <summary>Locates the module info matching <paramref name="FileName"/>.</summary>
    function FindModuleInfo(const FileName: string): IOTAModuleInfo;

    /// <summary>Persistent project GUID.</summary>
    property ProjectGUID: TGUID read GetProjectGUID;
    /// <summary>Project personality identifier.</summary>
    property Personality: string read GetPersonality;
  end;

  {------------------------------------------------------------------------}

  { Correct Interfaces for Delphi 6 and 7 }

  /// <summary>Delphi 6-7 corrected variant of <see cref="IOTAProject40"/> rebound to <see cref="IOTAModule70"/>.</summary>
  IOTAProject40_70 = interface(IOTAModule70)
    ['{F17A7BCA-E07D-11D1-AB0B-00C04FB16FB3}']
    /// <summary>Returns the number of source modules in the project.</summary>
    function GetModuleCount: Integer;
    /// <summary>Returns the module info at <paramref name="Index"/>.</summary>
    function GetModule(Index: Integer): IOTAModuleInfo;
    /// <summary>Returns the project's options bag.</summary>
    function GetProjectOptions: IOTAProjectOptions;
    /// <summary>Returns the project's builder.</summary>
    function GetProjectBuilder: IOTAProjectBuilder;

    /// <summary>Project options bag.</summary>
    property ProjectOptions: IOTAProjectOptions read GetProjectOptions;
    /// <summary>Project builder.</summary>
    property ProjectBuilder: IOTAProjectBuilder read GetProjectBuilder;
  end;

  /// <summary>Delphi 7 corrected variant of <see cref="IOTAProject70"/>.</summary>
  IOTAProject_70 = interface(IOTAProject40_70)
    ['{06C88136-F367-4D47-B8B4-CCACB3D7439A}']
    /// <summary>Adds <paramref name="AFileName"/> to the project.</summary>
    procedure AddFile(const AFileName: string; IsUnitOrForm: Boolean);
    /// <summary>Removes <paramref name="AFileName"/> from the project.</summary>
    procedure RemoveFile(const AFileName: string);
  end;

  /// <summary>Alias - Delphi 6 uses the same project interface layout as Delphi 7.</summary>
  IOTAProject40_60 = IOTAProject40_70;
  /// <summary>Alias - Delphi 6 uses the same project interface layout as Delphi 7.</summary>
  IOTAProject_60 = IOTAProject_70;

  {------------------------------------------------------------------------}

  { Correct Interfaces for Delphi 5 }

  /// <summary>Delphi 5 corrected variant of <see cref="IOTAProject40"/> rebound to <see cref="IOTAModule50"/>.</summary>
  IOTAProject40_50 = interface(IOTAModule50)
    ['{F17A7BCA-E07D-11D1-AB0B-00C04FB16FB3}']
    /// <summary>Returns the number of source modules in the project.</summary>
    function GetModuleCount: Integer;
    /// <summary>Returns the module info at <paramref name="Index"/>.</summary>
    function GetModule(Index: Integer): IOTAModuleInfo;
    /// <summary>Returns the project's options bag.</summary>
    function GetProjectOptions: IOTAProjectOptions;
    /// <summary>Returns the project's builder.</summary>
    function GetProjectBuilder: IOTAProjectBuilder;

    /// <summary>Project options bag.</summary>
    property ProjectOptions: IOTAProjectOptions read GetProjectOptions;
    /// <summary>Project builder.</summary>
    property ProjectBuilder: IOTAProjectBuilder read GetProjectBuilder;
  end;

  /// <summary>Delphi 5 corrected variant of <see cref="IOTAProject_70"/>.</summary>
  IOTAProject_50 = interface(IOTAProject40_70)
    ['{06C88136-F367-4D47-B8B4-CCACB3D7439A}']
    /// <summary>Adds <paramref name="AFileName"/> to the project.</summary>
    procedure AddFile(const AFileName: string; IsUnitOrForm: Boolean);
    /// <summary>Removes <paramref name="AFileName"/> from the project.</summary>
    procedure RemoveFile(const AFileName: string);
  end;

//function BorlandIDEServices: IBorlandIDEServices;
/// <summary>
/// Returns the highest-versioned <see cref="IOTAServices50"/>-compatible interface that
/// the running IDE supports, by querying <c>BorlandIDEServices</c> from newest to oldest.
/// </summary>
/// <returns><c>True</c> when an IDE services interface was resolved; <c>False</c> when none is available.</returns>
function SupportsIDEServices(out Intf: IOTAServices50): Boolean;

implementation

uses
  IdeDllNames;

var
  _BorlandIDEServices: PPointer;

procedure InitializeToolsAPI;
var
  h: THandle;
begin
  h := GetModuleHandle(designide_bpl);
  _BorlandIDEServices := GetProcAddress(h, '@Toolsapi@BorlandIDEServices');
end;

function BorlandIDEServices: IBorlandIDEServices;
begin
  if _BorlandIDEServices = nil then
    InitializeToolsAPI;
  if _BorlandIDEServices <> nil then
    Result := IBorlandIDEServices(_BorlandIDEServices^)
  else
    Result := nil;
end;

function SupportsIDEServices(out Intf: IOTAServices50): Boolean;
begin
  Intf := nil;
  if not Supports(BorlandIDEServices, IOTAServices, Intf) then
    if not Supports(BorlandIDEServices, IOTAServices160, Intf) then
      if not Supports(BorlandIDEServices, IOTAServices140, Intf) then
        if not Supports(BorlandIDEServices, IOTAServices110, Intf) then
          if not Supports(BorlandIDEServices, IOTAServices100, Intf) then
            if not Supports(BorlandIDEServices, IOTAServices70, Intf) then
              if not Supports(BorlandIDEServices, IOTAServices60, Intf) then
                if not Supports(BorlandIDEServices, IOTAServices50, Intf) then
                  Intf := nil;
  Result := Intf <> nil;
end;

end.
