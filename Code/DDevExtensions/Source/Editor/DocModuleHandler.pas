unit DocModuleHandler;

/// <summary>
/// Re-declares enough of Delphi's internal Docmodul.pas / Delphimodule.pas types so plug-ins
/// can call their non-public APIs (TDocModule, TPascalCodeMgrModHandler, IRoot, etc.) by
/// resolving the relevant VMT slots and exported symbols at runtime. Used by FrmReloadFiles to
/// trigger reloads without going through the limited public ToolsAPI.
/// </summary>

interface

uses
  Windows, SysUtils, Classes, ToolsAPI, Dialogs, Hooking, IDEHooks, ToolsAPIHelpers;

type
  /// <summary>Opaque placeholder for the IDE's internal TVirtualStream type.</summary>
  TVirtualStream = class(TObject);

  /// <summary>
  /// Mirror of the IDE's TVirtualFileSystem class. Only the published surface that the
  /// extension needs is reproduced; everything is abstract because the real bodies live in
  /// coreide_bpl.
  /// </summary>
  TVirtualFileSystem = class
  private
    /// <summary>Backing storage for the Filter property.</summary>
    FFilter: IOTAFileFilter;
  public
    /// <summary>Returns a read or write stream onto the named virtual file.</summary>
    function GetFileStream(const FileName: string; Mode: Integer): TVirtualStream; virtual; abstract;
    /// <summary>Returns the modification timestamp of the file.</summary>
    function FileAge(const FileName: string): Longint; virtual; abstract;
    /// <summary>Renames a file inside the virtual file system.</summary>
    function RenameFile(const OldName, NewName: string): Boolean; virtual; abstract;
    /// <summary>True if the file is read-only.</summary>
    function IsReadonly(const FileName: string): Boolean; virtual; abstract;
    /// <summary>True if this file system is backed by real files on disk.</summary>
    function IsFileBased: Boolean; virtual; abstract;
    /// <summary>Removes the named file.</summary>
    function DeleteFile(const FileName: string): Boolean; virtual; abstract;
    /// <summary>True if the named file exists.</summary>
    function FileExists(const FileName: string): Boolean; virtual; abstract;
    /// <summary>Returns a unique temporary filename in the same logical location.</summary>
    function GetTempFileName(const FileName: string): string; virtual; abstract;
    /// <summary>Returns the conventional backup filename for the file.</summary>
    function GetBackupFileName(const FileName: string): string; virtual; abstract;
    /// <summary>Returns the unique IDString that identifies this file system.</summary>
    function GetIDString: string; virtual; abstract;
    /// <summary>Returns the IOTAFileFilter installed on this file system.</summary>
    function GetFilter: IOTAFileFilter; virtual; abstract;
    //procedure SetFilter(const AFilter: IOTAFileFilter);
    //property Filter: IOTAFileFilter read GetFilter write SetFilter;
    /// <summary>The active IOTAFileFilter for streaming through this file system.</summary>
    property Filter: IOTAFileFilter read FFilter;
  end;

  /// <summary>
  /// Mirror of Docmodul.TDocModule. The real class is implemented inside coreide_bpl; this
  /// surrogate exposes the methods we need by dispatching through the virtual method table at
  /// runtime (see DocModuleVirtMethods array).
  /// </summary>
  TDocModule = class(TObject)
  public
    /// <summary>True if the underlying module has been put dormant by the IDE.</summary>
    function IsDormant: Boolean;
  public
    /// <summary>Returns True if the file's date on disk differs from the loaded copy.</summary>
    function CheckFileDate: Boolean;
    /// <summary>Returns True if the IDE believes this module can safely be reloaded.</summary>
    function CanReloadFile: Boolean;
    /// <summary>Returns True if the in-memory copy is dirty.</summary>
    function GetModified: Boolean;
    /// <summary>Re-reads the module from disk via the IDE's standard reload mechanism.</summary>
    procedure ReloadFile;
    /// <summary>Returns the absolute file name backing the module.</summary>
    function GetFileName: string;
    /// <summary>Returns the IDE display name of the module.</summary>
    function GetModuleName: string;
    /// <summary>Returns the form name associated with the module, or empty for code-only units.</summary>
    function GetFormName: string;
    /// <summary>True if the module owns a form/datamodule.</summary>
    function HasForm: Boolean;
    /// <summary>Toggles between the source view and the form designer.</summary>
    function SwapSourceFormView: Boolean;
    /// <summary>True if the module satisfies the IDE's preconditions for being freed.</summary>
    function GetCanFree: Boolean;
    {$IF CompilerVersion >= 22.0} // XE+
    /// <summary>True if the module can be freed or sent dormant. Available from XE onward.</summary>
    /// <param name="DormantOk">True to accept "go dormant" as success.</param>
    function CanFreeOrGoDormant(const DormantOk: Boolean): Boolean;
    {$IFEND}
    /// <summary>Populates List with TDocModule instances that depend on this module.</summary>
    procedure GetDependentModules(List: TList);
    /// <summary>Populates List with TDocModule instances that this module depends on.</summary>
    procedure GetModuleDependencies(List: TList);
    /// <summary>Asks the IDE to put the module into a dormant state.</summary>
    function GoDormant: Boolean;
    /// <summary>Activates the source editor for the module.</summary>
    /// <param name="Activate">True to give the editor input focus.</param>
    procedure ShowEditor(Activate: Boolean);
    /// <summary>Activates the editor for the named auxiliary file in the module.</summary>
    procedure ShowEditorName(const FileName: string; Activate: Boolean);
    /// <summary>Activates the module, optionally treating it as opened by an external viewer.</summary>
    procedure Activate(IsExternalViewer: Boolean);
    /// <summary>Marks the module as modified.</summary>
    procedure Modified;
    /// <summary>Returns the virtual file system that hosts the module.</summary>
    function GetFileSystem: TVirtualFileSystem;
    /// <summary>Returns the IDE's internal "code IDocModule" interface implementation.</summary>
    function GetCodeIDocModule: TInterfacedObject;

    /// <summary>True if the in-memory copy is dirty.</summary>
    property IsModified: Boolean read GetModified;
    /// <summary>Absolute file name backing the module.</summary>
    property FileName: string read GetFileName;
    /// <summary>Virtual file system that owns this module.</summary>
    property FileSystem: TVirtualFileSystem read GetFileSystem;
    /// <summary>True when the IDE thinks the module can be freed.</summary>
    property CanFree: Boolean read GetCanFree;
  end;

  /// <summary>Untyped pointer alias the IDE uses for editor-view data blobs.</summary>
  TEditorViewDataArray = Pointer;
  /// <summary>Anonymous interface alias for the IDE's IFileAge interface (we only need the type).</summary>
  IFileAge = IInterface;
  /// <summary>Opaque placeholder for the IDE's internal TEditBuffer class.</summary>
  TEditBuffer = class(TObject);
  /// <summary>Anonymous interface alias for the IDE's IModuleUpdater.</summary>
  IModuleUpdater = IInterface;
  /// <summary>Anonymous interface alias for the IDE's IFormUpdater.</summary>
  IFormUpdater = IInterface;

  /// <summary>Stream interface used internally by the IDE for module persistence.</summary>
  IDocStream = interface
    ['{B7B8F53F-2A84-4CDD-97D9-B7D9CDAC33F8}']
    /// <summary>Reads up to Length bytes from the stream into Buffer.</summary>
    function Read(var Buffer; Length: Int64): Int64;
    /// <summary>Writes Length bytes from Buffer into the stream.</summary>
    function Write(var Buffer; Length: Int64): Int64;
    /// <summary>Repositions the stream pointer relative to Origin.</summary>
    function Seek(Offset: Int64; Origin: Integer): Int64;
    /// <summary>Truncates or extends the stream to Size bytes.</summary>
    procedure SetSize(Size: Int64);
  end;

  /// <summary>IDocStream specialisation that also exposes a modification timestamp.</summary>
  IDatedStream = interface(IDocStream)
    ['{A8613563-3389-4BA7-9A8A-5A8FF324F317}']
    /// <summary>Returns the modification time recorded on the stream.</summary>
    function GetModifyTime: Longint;
    /// <summary>Sets the modification time recorded on the stream.</summary>
    procedure SetModifyTime(Time: Longint);
  end;

  /// <summary>Mirror of the IDE's IFile interface for a single file handled by a module.</summary>
  IFile = interface
    ['{346E7BA0-D47E-11D3-BA96-0080C78ADCDB}']
    /// <summary>Opens the file as an IDocStream for streaming the form resource.</summary>
    function FormFileOpen: IDocStream;
    /// <summary>Returns the absolute file name.</summary>
    function GetFileName: string;
    /// <summary>Returns the file's modification time at the moment it was loaded.</summary>
    function GetTimeAtLoad: Longint;
    /// <summary>Returns the file's current modification time on disk.</summary>
    function GetModifyTime: Longint;
    /// <summary>Returns True if the file on disk has been modified since loading.</summary>
    function CheckFileDate: Boolean;
    /// <summary>Renames the file at the IDE level.</summary>
    procedure Rename(const NewFileName: string);
    /// <summary>Saves the file via the IDE's persistence mechanism.</summary>
    procedure Save;

    /// <summary>Absolute file name.</summary>
    property FileName: string read GetFileName;
    /// <summary>Modification time recorded at load time.</summary>
    property TimeAtLoad: Longint read GetTimeAtLoad;
    /// <summary>Current modification time on disk.</summary>
    property ModifyTime: Longint read GetModifyTime;
  end;

  /// <summary>Marker interface used to identify an IDE designer module instance.</summary>
  IDesignerModule = interface
    ['{7ED7BF27-E349-11D3-AB4A-00C04FB17A72}']
    // ...
  end;

  /// <summary>Marker interface for the IDE's IDesigner.</summary>
  IDesigner = interface
  end;

  /// <summary>Marker interface for an internal palette item descriptor.</summary>
  IInternalPaletteItem = interface
  end;

  /// <summary>Marker interface for the IDE's per-component palette information.</summary>
  ICompInfo = interface
  end;

  /// <summary>Callback used by IRoot.GetDependentRoots / GetDependencies to walk associated roots.</summary>
  TGetRootProc = procedure;

  /// <summary>Window state used by IRoot.ShowAs (normal, minimised or maximised).</summary>
  TShowState = (ssNormal, ssMinimized, ssMaximized);
  /// <summary>Combinations describing the visibility/iconified/zoomed state of a designer.</summary>
  TDesignerState = set of (dsVisible, dsIconic, dsZoomed);

  /// <summary>Mirror of the IDE's IRoot interface, the central object for an open form/datamodule.</summary>
  IRoot = interface(IFile)
    ['{76023428-77C4-4E10-B210-2DE6536C04E7}']
    /// <summary>Closes the root and discards any unsaved changes.</summary>
    procedure Close;
    /// <summary>Adds a new component from the supplied palette item at the default location.</summary>
    procedure CreateComponent(Item: IInternalPaletteItem);
    /// <summary>Adds a new component at design coordinates (X, Y).</summary>
    procedure CreateComponentPos(Item: IInternalPaletteItem; X, Y: Integer);
    /// <summary>Looks up the class name for a component by its design-time name.</summary>
    function FindCompClass(const CompName: string): string;
    {$IF CompilerVersion >= 23.0} // XE2+
    /// <summary>Freezes property updates until ThawProperties is called (XE2+).</summary>
    procedure FreezeProperties;
    {$IFEND}
    /// <summary>Returns the name of the form's ancestor class, if any.</summary>
    function GetAncestorName: string;
    /// <summary>Returns the number of components on the root.</summary>
    function GetCompCount: Integer;
    /// <summary>Walks every dependent root, calling Proc for each.</summary>
    procedure GetDependentRoots(Proc: TGetRootProc);
    /// <summary>Returns the design-time class name (e.g. TForm1).</summary>
    function GetDesignClassName: string;
    /// <summary>Walks every dependency root, calling Proc for each.</summary>
    procedure GetDependencies(Proc: TGetRootProc);
    /// <summary>Returns the IComponent info for the component at Index.</summary>
    function GetCompInfo(Index: Integer): ICompInfo;
    /// <summary>Returns the IDesignerModule that owns this root.</summary>
    function GetModule: IDesignerModule;
    /// <summary>Returns the design-time name of the component at Index.</summary>
    function GetCompName(Index: Integer): string;
    /// <summary>Returns the design-time class name of the component at Index.</summary>
    function GetCompType(Index: Integer): string;
    {$IF CompilerVersion >= 24.0} // XE3+
    /// <summary>Returns the form-family name (FMX vs VCL etc.) - XE3 onwards.</summary>
    function GetFormFamilyName: string;
    {$IFEND}
    /// <summary>Returns the file system identifier in use.</summary>
    function GetFileSystem: string;
    /// <summary>Returns the underlying TComponent representing the form's root.</summary>
    function GetRoot: TComponent;
    /// <summary>Returns the root's design-time name.</summary>
    function GetRootName: string;
    /// <summary>Walks every unit referenced by the form, invoking Proc for each.</summary>
    procedure GetUnits(Proc: TGetStrProc);
    /// <summary>Returns the current TDesignerState (visible/iconic/zoomed).</summary>
    function GetState: TDesignerState;
    /// <summary>Hides the form designer.</summary>
    procedure Hide;
    /// <summary>Asks the IDE to put the root dormant.</summary>
    procedure GoDormant;
    /// <summary>Renames a method on the root.</summary>
    procedure RenameRootMethod(const CurName, NewName: string);
    /// <summary>Renames the component CurName to NewName.</summary>
    function RenameComponent(const CurName, NewName: string): Boolean;
    /// <summary>Removes any links the root holds to dependent forms.</summary>
    procedure RemoveDependentLinks;
    /// <summary>Switches the root to the supplied IDE file system.</summary>
    procedure SetFileSystem(const FileSystem: string);
    /// <summary>Renames the root component.</summary>
    procedure SetRootName(const AName: string);
    /// <summary>Selects the named component in the designer.</summary>
    procedure SetSelection(const Name: string);
    /// <summary>Shows the form designer.</summary>
    procedure Show;
    /// <summary>Shows the form designer in the requested window state.</summary>
    procedure ShowAs(ShowState: TShowState);
    /// <summary>Opens the help topic for the currently selected component.</summary>
    procedure ShowComponentHelp;
    /// <summary>Returns help meta-data for a particular property/member.</summary>
    function SpecialPropertyHelp(const Member: string; out HelpFile, Context: string; out HelpType: THelpType): Boolean;
    {$IF CompilerVersion >= 23.0} // XE2+
    /// <summary>Re-enables property update notifications after FreezeProperties (XE2+).</summary>
    procedure ThawProperties;
    {$IFEND}
    /// <summary>Returns the IDesigner managing this root.</summary>
    function GetDesigner: IDesigner;
    /// <summary>Returns the IOTAFormEditor presenting this root in the IDE.</summary>
    function GetFormEditor: IOTAFormEditor;
    /// <summary>The underlying TComponent root (typically the form).</summary>
    property Root: TComponent read GetRoot;
    /// <summary>The IDesignerModule that hosts this root.</summary>
    property Module: IDesignerModule read GetModule;
  end;

  /// <summary>Mirror of the IDE's IBaseComponentDesigner factory interface.</summary>
  IBaseComponentDesigner = interface
    ['{6EBEF997-E986-41B3-8E70-3112112F1AB7}']
    /// <summary>Creates a new IRoot for AModule from the file at AFileName.</summary>
    function CreateRoot(const AModule: IDesignerModule; const AFileName: string;
      Existing: Boolean; const ARootName, AAncestor,
      AFileSystem: string): IRoot;
    {function CreateFromStream(const AModule: IDesignerModule; const AFileName,
      AFileSystem: string; const Stream: IDatedStream): IRoot;
    function CreateNewRoot(const AModule: IDesignerModule;
      const AFileName: string; const Creator: IUnknown): IRoot;
    function GetExtension: string;}
  end;

  /// <summary>Specialisation of TDocModule used by the IDE for ordinary source modules.</summary>
  TSourceModule = class(TDocModule)
  end;

  /// <summary>
  /// Mirror of Delphimodule.TPascalCodeMgrModHandler. Field layout must remain bit-identical
  /// to the IDE's class because the offsets are validated through RTTI in InitDocModuleHandler.
  /// </summary>
  TPascalCodeMgrModHandler = class(TNotifierObject, IDesignerModule)
  protected
    /// <summary>Index returned by AddModuleNotifier.</summary>
    FNotifierIndex: Integer;
    /// <summary>Cached form name for the source modules.</summary>
    FSourceModulesFormName: string;
    /// <summary>List of related ISourceModule instances.</summary>
    FSourceModules: IInterfaceList;
    /// <summary>Editor view data blob owned by the IDE.</summary>
    FEditorViewData: TEditorViewDataArray;
    /// <summary>Additional files data blob owned by the IDE.</summary>
    FAdditionalFilesData: TEditorViewDataArray;
    {$IF CompilerVersion >= 27.0} // XE6+
    /// <summary>Designer view streams blob (XE6+).</summary>
    FDesignerViewStreams: TEditorViewDataArray;
    {$IFEND}
    /// <summary>Temporary file age tracker.</summary>
    FTempFile: IFileAge;
    {$IF CompilerVersion >= 22.0} // XE+
    /// <summary>True while the IDE is in the middle of a reload (XE+).</summary>
    FReloadingFile: Boolean;
    /// <summary>Notifier for the ancestor module (XE+).</summary>
    FAncestorNotifier: TModuleNotifierObject;
    {$IFEND}
  protected
    /// <summary>Backing edit buffer.</summary>
    FEditBuffer: TEditBuffer;
    /// <summary>Component designer factory used by ResurrectForm.</summary>
    FDesigner: IBaseComponentDesigner;
    /// <summary>True once HasForm has been computed.</summary>
    FHasFormChecked: Boolean;
    /// <summary>Module updater interface used during module patching.</summary>
    FModuleUpdater: IModuleUpdater;
    /// <summary>True if the form has been modified since loading.</summary>
    FIsFormModified: Boolean;
    {$IF CompilerVersion >= 21.0} // Delphi 2010+
    /// <summary>True if the form was already modified by patches at the moment it loaded.</summary>
    FWasFormModifiedAtLoading: Boolean;
    {$IFEND}
    /// <summary>True when the form is currently the topmost designer window.</summary>
    FFormIsTopmost: Boolean;
    /// <summary>Reference to the ancestor source module.</summary>
    FAncestorModule: TSourceModule;
    /// <summary>Reference to the underlying source module.</summary>
    FSourceModule: TSourceModule;
    /// <summary>Old file name retained for recovery during rename.</summary>
    FOldFormFileName: string;
    /// <summary>Cached form name.</summary>
    FFormName: string;
    /// <summary>Cached form class name.</summary>
    FFormClassName: string;
    /// <summary>Cached ancestor class name.</summary>
    FAncestorClassName: string;
    /// <summary>Cached referenced unit names.</summary>
    FUnitNames: TStrings;
    /// <summary>Re-entrancy guard for QueryInterface.</summary>
    FInQI: Boolean;
    /// <summary>List of dependent modules.</summary>
    FDependList: TList;
    /// <summary>The IRoot representing the form designed by this handler.</summary>
    FForm: IRoot;
//    FFormUpdater: IFormUpdater;
//    FSaveFileName: string;
//    FSquelchModifiedNotification: Boolean;
//    FOldBaseFileName: string;
  public
    /// <summary>Restores a previously dormant form by re-creating its IRoot.</summary>
    procedure ResurrectForm;
    /// <summary>Reloads the source/form for this module from disk.</summary>
    procedure ReloadFile;
  end;

var
  /// <summary>Pointer to the IDE's global module list (Docmodul.ModuleList).</summary>
  ModuleListP: ^TList;

/// <summary>
/// Resolves the IDE export symbols and VMT offsets that this surrogate class layer needs.
/// Must be called once before any TDocModule member is invoked.
/// </summary>
/// <returns>True on success; False (with a message dialog) if a symbol or offset cannot be located.</returns>
function InitDocModuleHandler: Boolean;

/// <summary>Returns True if the IDE has its forms hosted as embedded designer panels.</summary>
function IsEmbeddedDesigner: Boolean;

implementation

{$IF CompilerVersion >= 21.0}
uses
  Rtti;
{$IFEND}

var
  DocModuleIsDormantOffset: Integer;

procedure Docmodul_ModuleListAddr;
  external coreide_bpl name '@Docmodul@ModuleList';

{$IF CompilerVersion >= 25.0} // XE4+
function IsEmbeddedDesigner: Boolean;
begin
  Result := True;
end;
{$ELSE}
procedure EnvironmentOptionsAddr;
  external coreide_bpl name '@Envoptions@EnvironmentOptions';

function IsEmbeddedDesigner: Boolean;
const
  sEmbeddedDesigner = 'EmbeddedDesigner';
var
  EmbeddedDesignerProp: TPropField;
begin
  EmbeddedDesignerProp := TPropField( (TObject(PPointer(GetActualAddr(@EnvironmentOptionsAddr))^) as TComponent).FindComponent(sEmbeddedDesigner));
  if EmbeddedDesignerProp <> nil then
    Result := EmbeddedDesignerProp.Value
  else
    Result := True;
end;
{$IFEND}

type
  TDocModuleVirtMethodType = (
    mCheckFileDate,
    mCanReloadFile,
    mGetModified,
    mReloadFile,
    mGetFileName,
    mGetModuleName,
    mHasForm,
    mGetFormName,
    mSwapSourceFormView,
    mGetDependentModules,
    mGetModuleDependencies,
    mGoDormant,
    mShowEditor,
    mShowEditorName,
    mGetFileSystem,
    mActivate,
    mModified
  );

  TDocModuleVirtMethodRec = record
  public
    Import: PAnsiChar;
    VmtOffset: Integer;
    Addr: Pointer;
    function CallBoolean(Instance: TDocModule): Boolean;
    function CallString(Instance: TDocModule): string;
    function CallObject(Instance: TDocModule): TObject;
    procedure Call(Instance: TDocModule);
    procedure Call1(Instance: TDocModule; P1: Pointer);
    procedure Call2(Instance: TDocModule; P1, P2: Pointer);
  end;

{$J+}
const
  DocModuleVirtMethods: array[TDocModuleVirtMethodType] of TDocModuleVirtMethodRec = (
    (Import: '@Docmodul@TDocModule@CheckFileDate$qqrv'),
    (Import: '@Docmodul@TDocModule@CanReloadFile$qqrv'),
    (Import: '@Docmodul@TDocModule@GetModified$qqrv'),
    (Import: '@Docmodul@TDocModule@ReloadFile$qqrv'),
    (Import: '@Docmodul@TDocModule@GetFileName$qqrv'),
    (Import: '@Docmodul@TDocModule@GetModuleName$qqrv'),
    (Import: '@Docmodul@TDocModule@HasForm$qqrv'),
    (Import: '@Docmodul@TDocModule@GetFormName$qqrv'),
    (Import: '@Docmodul@TDocModule@SwapSourceFormView$qqrv'),
    (Import: '@Docmodul@TDocModule@GetDependentModules$qqrp' + System_Classes_TList),
    (Import: '@Docmodul@TDocModule@GetModuleDependencies$qqrp' + System_Classes_TList),
    (Import: '@Docmodul@TDocModule@GoDormant$qqrv'),
    (Import: '@Docmodul@TDocModule@ShowEditor$qqro'),
    (Import: '@Docmodul@TDocModule@ShowEditorName$qqrx20System@UnicodeStringo'),
    (Import: '@Docmodul@TDocModule@GetFileSystem$qqrv'),
    (Import: '@Docmodul@TDocModule@Activate$qqro'),
    (Import: '@Docmodul@TDocModule@Modified$qqrv')
  );
{$J-}

{ TPascalCodeMgrModHandler }

procedure ClassTPascalCodeMgrModHandler;
  external delphicoreide_bpl name '@Delphimodule@TPascalCodeMgrModHandler@';

procedure TPascalCodeMgrModHandler.ResurrectForm;
  external delphicoreide_bpl name '@Delphimodule@TPascalCodeMgrModHandler@ResurrectForm$qqrv';

procedure TPascalCodeMgrModHandler.ReloadFile;
  external delphicoreide_bpl name '@Delphimodule@TPascalCodeMgrModHandler@ReloadFile$qqrv';

{ TDocModule }

procedure ClassTDocModule;
  external coreide_bpl name '@Docmodul@TDocModule@';

procedure TDocModule_GoDormant;
  external coreide_bpl name '@Docmodul@TDocModule@GoDormant$qqrv';

function TDocModule.GetCanFree: Boolean;
  external coreide_bpl name '@Docmodul@TDocModule@GetCanFree$qqrv';

{$IF CompilerVersion >= 22.0} // XE+
function TDocModule.CanFreeOrGoDormant(const DormantOk: Boolean): Boolean;
  external coreide_bpl name '@Docmodul@TDocModule@CanFreeOrGoDormant$qqrxo';
{$IFEND}

function TDocModule.GetCodeIDocModule: TInterfacedObject;
  external coreide_bpl name '@Docmodul@TDocModule@GetCodeIDocModule$qqrv';

function TDocModule.IsDormant: Boolean;
begin
  Result := PBoolean(PByte(Self) + DocModuleIsDormantOffset)^;
end;

function TDocModule.CanReloadFile: Boolean;
begin
  Result := DocModuleVirtMethods[mCanReloadFile].CallBoolean(Self);
end;

function TDocModule.CheckFileDate: Boolean;
begin
  Result := DocModuleVirtMethods[mCheckFileDate].CallBoolean(Self);
end;

function TDocModule.GetFileName: string;
begin
  Result := DocModuleVirtMethods[mGetFileName].CallString(Self);
end;

function TDocModule.GetFormName: string;
begin
  Result := DocModuleVirtMethods[mGetFormName].CallString(Self);
end;

function TDocModule.GetModified: Boolean;
begin
  Result := DocModuleVirtMethods[mGetModified].CallBoolean(Self);
end;

function TDocModule.GetModuleName: string;
begin
  Result := DocModuleVirtMethods[mGetModuleName].CallString(Self);
end;

function TDocModule.HasForm: Boolean;
begin
  Result := DocModuleVirtMethods[mHasForm].CallBoolean(Self);
end;

procedure TDocModule.ReloadFile;
begin
  DocModuleVirtMethods[mReloadFile].Call(Self);
end;

function TDocModule.SwapSourceFormView: Boolean;
begin
  Result := DocModuleVirtMethods[mSwapSourceFormView].CallBoolean(Self);
end;

procedure TDocModule.GetDependentModules(List: TList);
begin
  DocModuleVirtMethods[mGetDependentModules].Call1(Self, List);
end;

procedure TDocModule.GetModuleDependencies(List: TList);
begin
  DocModuleVirtMethods[mGetModuleDependencies].Call1(Self, List);
end;

function TDocModule.GoDormant: Boolean;
begin
  Result := DocModuleVirtMethods[mGoDormant].CallBoolean(Self);
end;

procedure TDocModule.ShowEditor(Activate: Boolean);
begin
  DocModuleVirtMethods[mShowEditor].Call1(Self, Pointer(Activate));
end;

procedure TDocModule.ShowEditorName(const FileName: string; Activate: Boolean);
begin
  DocModuleVirtMethods[mShowEditorName].Call2(Self, Pointer(FileName), Pointer(Activate));
end;

procedure TDocModule.Activate(IsExternalViewer: Boolean);
begin
  DocModuleVirtMethods[mActivate].Call1(Self, Pointer(IsExternalViewer));
end;

procedure TDocModule.Modified;
begin
  DocModuleVirtMethods[mModified].Call(Self);
end;

function TDocModule.GetFileSystem: TVirtualFileSystem;
begin
  Result := TVirtualFileSystem(DocModuleVirtMethods[mGetFileSystem].CallObject(Self));
end;

{ TDocModuleVirtMethodRec }

function TDocModuleVirtMethodRec.CallBoolean(Instance: TDocModule): Boolean;
asm
  jmp TDocModuleVirtMethodRec.Call
end;

function TDocModuleVirtMethodRec.CallString(Instance: TDocModule): string;
asm
  jmp TDocModuleVirtMethodRec.Call1 // String is passed as second parameter (EDX)
end;

function TDocModuleVirtMethodRec.CallObject(Instance: TDocModule): TObject;
asm
  jmp TDocModuleVirtMethodRec.Call
end;

procedure TDocModuleVirtMethodRec.Call(Instance: TDocModule);
asm
  xchg eax, edx
  mov edx, [edx].TDocModuleVirtMethodRec.&VmtOffset
  mov ecx, [eax]
  jmp [ecx+edx]
end;

procedure TDocModuleVirtMethodRec.Call1(Instance: TDocModule; P1: Pointer);
asm
  push ebx
  mov ebx, [edx]
  add ebx, [eax].TDocModuleVirtMethodRec.&VmtOffset

  mov eax, edx
  mov edx, ecx
  call [ebx]

  pop ebx
end;

procedure TDocModuleVirtMethodRec.Call2(Instance: TDocModule; P1, P2: Pointer);
asm
  push ebx
  mov ebx, [edx]
  add ebx, [eax].TDocModuleVirtMethodRec.&VmtOffset

  mov eax, edx
  mov edx, ecx
  mov ecx, [esp+$08]
  call [ebx]

  pop ebx
end;


function InitDocModuleHandler: Boolean;
const
  GoDormantBytes: array[0..12] of SmallInt = (
    $B3, $01,            // mov bl,$01                  //  0
    $80, $7E, -1, $00,   // cmp byte ptr [esi+$49],$00  //  2 // IsDormantOffset
    $75, -1,             // jnz $2084517a               //  6
    $8D, $55, $FC,       // lea edx,[ebp-$04]           //  8
    $8B, $C6             // mov eax,esi                 // 11
  );
var
  DocModuleClass: TClass;
  CoreIdeLib: THandle;
  MethTyp: TDocModuleVirtMethodType;
  VmtIndex: Integer;
  P: PByte;
  {$IF CompilerVersion >= 21.0}
  PascalCodeMgrModHandlerClass: TClass;
  Context: TRttiContext;
  Typ: TRttiType;
  Fld: TRttiField;
  {$IFEND}
begin
  Result := False;

  ModuleListP := GetActualAddr(@Docmodul_ModuleListAddr);
  DocModuleClass := TClass(GetActualAddr(@ClassTDocModule));

  {$IF CompilerVersion >= 21.0}
  PascalCodeMgrModHandlerClass := TClass(GetActualAddr(@ClassTPascalCodeMgrModHandler));
  // (Un)Fortunately there are no updates for older Delphi versions, only for the newest. So we
  // can assume that older versions without RichRTTI never change.
  Context := TRttiContext.Create;
  try
    Typ := Context.GetType(PascalCodeMgrModHandlerClass);
    Fld := nil;
    if Typ <> nil then
    begin
      {AllocConsole;
      for Fld in Typ.GetFields do
        WriteLn(Fld.ToString);}

      Fld := Typ.GetField('FForm');
      if (Fld <> nil) and (Fld.Offset <> NativeInt(@TPascalCodeMgrModHandler(nil).FForm)) then
        Fld := nil;
    end;
    if Fld = nil then
    begin
      MessageDlg('DDevExtensions: TPascalCodeMgrModHandler InstanceSize doesn''t match', mtError, [mbOk], 0);
      Exit;
    end;
  finally
    Context.Free;
  end;
  {$IFEND}

  CoreIdeLib := GetModuleHandle(coreide_bpl);
  for MethTyp := Low(DocModuleVirtMethods) to High(DocModuleVirtMethods) do
  begin
    DocModuleVirtMethods[MethTyp].Addr := GetProcAddress(CoreIdeLib, DocModuleVirtMethods[MethTyp].Import);
    if DocModuleVirtMethods[MethTyp].Addr = nil then
    begin
      MessageDlg(Format('DDevExtensions: Import symbol "%s" not found in "%s"', [AnsiString(DocModuleVirtMethods[MethTyp].Import), coreide_bpl]), mtError, [mbOk], 0);
      Exit;
    end;
  end;

  for VmtIndex := 0 to GetVirtualMethodCount(DocModuleClass) - 1 do
    for MethTyp := Low(DocModuleVirtMethods) to High(DocModuleVirtMethods) do
      if GetVirtualMethod(DocModuleClass, VmtIndex) = DocModuleVirtMethods[MethTyp].Addr then
        DocModuleVirtMethods[MethTyp].VmtOffset := VmtIndex * SizeOf(Pointer);

  for MethTyp := Low(DocModuleVirtMethods) to High(DocModuleVirtMethods) do
  begin
    if DocModuleVirtMethods[MethTyp].VmtOffset = 0 then
    begin
      MessageDlg('DDevExtensions: Error getting VMT offsets for TDocModule', mtError, [mbOk], 0);
      Exit;
    end;
  end;

  P := FindMethodPtr(THandle(GetActualAddr(@TDocModule_GoDormant)), GoDormantBytes, $40);
  if P = nil then
  begin
    MessageDlg('DDevExtensions: Error finding TDocModule.IsDormant', mtError, [mbOk], 0);
    Exit;
  end;
  DocModuleIsDormantOffset := P[4];


  Result := True;
end;

end.
