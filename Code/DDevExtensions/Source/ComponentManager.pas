{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit ComponentManager;

/// <summary>
/// Tracks every component registered with the IDE component palette so that
/// DDevExtensions features (Component Selector, search, palette restoration)
/// can enumerate, look up and unload them.
/// </summary>
/// <remarks>
/// The unit hooks <c>Classes.RegisterComponents</c> via <c>CodeRedirect</c>
/// so all design-package registrations flow through
/// <see cref="TRegisteredComponents.RegisterComponents"/>. The hook is
/// installed by <see cref="InitComponentManager"/> and removed by
/// <see cref="FiniComponentManager"/>.
/// </remarks>

{$I DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Contnrs, Controls, IDEHooks, ToolsAPI,
  {$IFDEF COMPILER5}
  Consts,
  {$ELSE}
  RTLConsts,
  {$ENDIF COMPILER5}
  Hooking;

type
  {$IFDEF COMPILER5}
  /// <summary>Pointer to <c>Boolean</c> shim for compilers without a built-in declaration.</summary>
  PBoolean = ^Boolean;
  {$ENDIF COMPILER5}

  /// <summary>
  /// Notification callback interface implemented by features that need to
  /// react when the registered-component set changes (e.g. a design package
  /// is loaded or unloaded).
  /// </summary>
  IComponentChangeNotifier = interface
    ['{CFB82019-0197-4551-9E63-D5C9C5D62B19}']
    /// <summary>Called by <see cref="TRegisteredComponents"/> after any change to the registered-component set.</summary>
    procedure ComponentsChanged;
  end;

  /// <summary>
  /// Singleton store of every component class registered with the IDE
  /// palette, keyed by palette name and owning module (BPL).
  /// </summary>
  /// <remarks>
  /// Access via the global <see cref="RegisteredComponents"/> function.
  /// Notifies subscribed <see cref="IComponentChangeNotifier"/> instances
  /// whenever the set is modified.
  /// </remarks>
  TRegisteredComponents = class(TObject)
  private
    /// <summary>List of palette names; each <c>Objects[i]</c> is a <c>TStringList</c> of component names with module handles in <c>Objects[]</c>.</summary>
    FPalettes: TStrings;
    /// <summary>Flat list of every registered component class, parallel to <see cref="FComponents"/>.</summary>
    FComponentClasses: TClassList;
    /// <summary>Flat list of every registered component name; <c>Objects[i]</c> holds the owning <c>HMODULE</c>.</summary>
    FComponents: TStrings;
    /// <summary>Subscribed change-notification listeners.</summary>
    FComponentNotifiers: TInterfaceList;
    /// <summary>Increment counter advanced on every change; used by external code to detect cache invalidation.</summary>
    FLastModifyCount: Cardinal;
    /// <summary>Returns the palette name at the given index.</summary>
    function GetPalette(Index: Integer): string;
    /// <summary>Returns the number of distinct palette categories.</summary>
    function GetPaletteCount: Integer;
    /// <summary>Returns the registered component class at the given flat index.</summary>
    function GetComponentClass(Index: Integer): TComponentClass;
    /// <summary>Returns the total number of registered components across all palettes.</summary>
    function GetComponentCount: Integer;
    /// <summary>Returns the owning BPL module handle for the component at the given flat index.</summary>
    function GetComponentModule(Index: Integer): HMODULE;
  protected
    /// <summary>Bumps <see cref="FLastModifyCount"/> and notifies every subscribed change listener.</summary>
    procedure ComponentsChanged; virtual;
  public
    /// <summary>Creates the singleton and its backing collections.</summary>
    constructor Create;
    /// <summary>Frees collections and detaches notifiers.</summary>
    destructor Destroy; override;
    /// <summary>Removes every registered component while keeping notifiers attached.</summary>
    procedure Clear;

    /// <summary>
    /// Registers an array of component classes under the supplied palette name.
    /// </summary>
    /// <param name="Palette">Palette page name (e.g. "Standard", "Win32").</param>
    /// <param name="AComponentClasses">Component classes contributed by the calling design package.</param>
    /// <remarks>The owning module is inferred from the caller's return address.</remarks>
    procedure RegisterComponents(const Palette: string; const AComponentClasses: array of TComponentClass);
    /// <summary>Removes every component contributed by the given module (used when a design package unloads).</summary>
    /// <param name="Module">Handle of the design package that is unloading.</param>
    procedure DeletePackageComponents(Module: HMODULE);

    /// <summary>
    /// Returns true if <paramref name="ComponentClass"/> belongs to the active
    /// designer's class group (e.g. VCL vs FMX).
    /// </summary>
    /// <param name="ComponentClass">Component class to test.</param>
    class function IsInActiveControlGroup(ComponentClass: TComponentClass): Boolean;

    /// <summary>Returns a freshly allocated, owned <c>TStringList</c> of the component names registered on the given palette.</summary>
    /// <param name="PaletteIndex">Zero-based palette index.</param>
    /// <returns>Caller-owned list; the caller must free it.</returns>
    function CreateComponentByNameList(PaletteIndex: Integer): TStrings;
    /// <summary>Returns the palette index that contains the given component class, or -1 if not found.</summary>
    function PaletteOf(ComponentClass: TComponentClass): Integer; overload;
    /// <summary>Returns the palette index that contains the named component, or -1 if not found.</summary>
    function PaletteOf(const ComponentName: string): Integer; overload;
    /// <summary>Returns the BPL module that registered <paramref name="ComponentClass"/>, or 0 if unknown.</summary>
    function FindModule(ComponentClass: TComponentClass): HMODULE;
    /// <summary>Returns the registered component class whose name matches <paramref name="ComponentName"/>, or nil.</summary>
    function FindComponentClass(const ComponentName: string): TComponentClass;

    /// <summary>Number of distinct palette pages.</summary>
    property PaletteCount: Integer read GetPaletteCount;
    /// <summary>Palette name at the given index.</summary>
    property Palettes[Index: Integer]: string read GetPalette;

    /// <summary>Total number of registered components across all palettes.</summary>
    property ComponentCount: Integer read GetComponentCount;
    /// <summary>Component class at the given flat index.</summary>
    property ComponentClasses[Index: Integer]: TComponentClass read GetComponentClass;
    /// <summary>Owning BPL module handle for the component at the given flat index.</summary>
    property ComponentModules[Index: Integer]: HMODULE read GetComponentModule;

    /// <summary>Subscribes a change-notification listener (idempotent).</summary>
    procedure AddNotifier(Notifier: IComponentChangeNotifier);
    /// <summary>Removes a previously subscribed change-notification listener.</summary>
    procedure RemoveNotifier(Notifier: IComponentChangeNotifier);

    /// <summary>Counter that is incremented on every change; useful for cache invalidation.</summary>
    property LastModifyCount: Cardinal read FLastModifyCount;
  end;

/// <summary>Lazily creates and returns the global registered-components singleton.</summary>
function RegisteredComponents: TRegisteredComponents;
/// <summary>
/// Loads the palette bitmap for the given component class, walking up the
/// class hierarchy and falling back to the IDE's <c>DEFAULT</c> bitmap.
/// </summary>
/// <param name="ComponentClass">Component class whose bitmap is needed.</param>
/// <param name="IsDefault">If non-nil, set to True when the default bitmap had to be used.</param>
/// <returns>A bitmap handle owned by the caller.</returns>
function LoadComponentBitmap(ComponentClass: TComponentClass; IsDefault: PBoolean = nil): HBitmap;

/// <summary>Installs the <c>Classes.RegisterComponents</c> hook (called once at plug-in start-up).</summary>
procedure InitComponentManager;
/// <summary>Uninstalls the <c>Classes.RegisterComponents</c> hook (called once at plug-in shutdown).</summary>
procedure FiniComponentManager;

implementation

uses
  Main, IDEUtils;

var
  GlobalRegisteredComponents: TRegisteredComponents;

function RegisteredComponents: TRegisteredComponents;
begin
  if not Assigned(GlobalRegisteredComponents) then
    GlobalRegisteredComponents := TRegisteredComponents.Create;
  Result := GlobalRegisteredComponents;
end;


function LoadComponentBitmap(ComponentClass: TComponentClass; IsDefault: PBoolean): HBitmap;
var
  c: TClass;
  ClsName: string;
begin
  c := ComponentClass;
  Result := 0;
  while (Result = 0) and (c <> nil) and (c <> TComponent) and (c <> TControl) do
  begin
    ClsName := string(c.ClassName);
    Result := Windows.LoadBitmap(RegisteredComponents.FindModule(TComponentClass(c)), PChar(ClsName));
    if Result = 0 then
      Result := Windows.LoadBitmap(ModuleFromAddr(c.ClassInfo), PChar(ClsName));

    c := c.ClassParent;
  end;
  if Result = 0 then
  begin
    Result := Windows.LoadBitmap(GetModuleHandle(delphicoreide_bpl), 'DEFAULT');
    if IsDefault <> nil then
      IsDefault^ := True;
  end
  else
  if IsDefault <> nil then
    IsDefault^ := False;
end;

{ TRegisteredComponents }

constructor TRegisteredComponents.Create;
begin
  inherited Create;
  FPalettes := TStringList.Create;
  FComponents := TStringList.Create;
  FComponentClasses := TClassList.Create;
  FComponentNotifiers := TInterfaceList.Create;
end;

destructor TRegisteredComponents.Destroy;
begin
  FComponentNotifiers.Clear;
  Clear;
  FPalettes.Free;
  FComponents.Free;
  FComponentClasses.Free;
  FComponentNotifiers.Free;
  inherited Destroy;
end;

function TRegisteredComponents.GetPalette(Index: Integer): string;
begin
  Result := FPalettes[Index];
end;

function TRegisteredComponents.GetPaletteCount: Integer;
begin
  Result := FPalettes.Count;
end;

{$IFDEF COMPILER6_UP}
class function TRegisteredComponents.IsInActiveControlGroup(
  ComponentClass: TComponentClass): Boolean;
var
  Group: TPersistentClass;
begin
  if ComponentClass <> nil then
  begin
    Result := True;
    Group := ClassGroupOf(ComponentClass);
    if (Group <> nil) and Group.ClassNameIs('TControl'){Group.ClassType = TControl} then
    begin
      if (BorlandIDEServices as IOTAServices).GetActiveDesignerType = dVCL then
      begin
        if Group <> ClassGroupOf(TControl) then
          Result := False;
      end
      else
        if Group = ClassGroupOf(TControl) then
          Result := False;
    end;
  end
  else
    Result := False;
end;
{$ELSE}
class function TRegisteredComponents.IsInActiveControlGroup(
  ComponentClass: TComponentClass): Boolean;
begin
  Result := True;
end;
{$ENDIF COMPILER6_UP}

function TRegisteredComponents.GetComponentClass(Index: Integer): TComponentClass;
begin
  Result := TComponentClass(FComponentClasses[Index]);
end;

function TRegisteredComponents.GetComponentCount: Integer;
begin
  Result := FComponents.Count;
end;

function TRegisteredComponents.CreateComponentByNameList(PaletteIndex: Integer): TStrings;
begin
  Result := TStringList.Create;
  try
    Result.Assign(TStrings(FPalettes.Objects[PaletteIndex]));
  except
    Result.Free;
    raise;
  end;
end;

procedure TRegisteredComponents.DeletePackageComponents(Module: HMODULE);
var
  i, k: Integer;
  CompList: TStrings;
begin
  for i := FPalettes.Count - 1 downto 0 do
  begin
    CompList := TStrings(FPalettes.Objects[i]);
    for k := CompList.Count - 1 downto 0 do
      if CompList.Objects[k] = Pointer(Module) then
        CompList.Delete(k);
    if CompList.Count = 0 then
      FPalettes.Delete(i);
  end;
  for i := FComponents.Count - 1 downto 0 do
  begin
    if FComponents.Objects[i] = Pointer(Module) then
    begin
      FComponents.Delete(i);
      FComponentClasses[i] := nil;
    end;
  end;
  FComponentClasses.Pack;
  ComponentsChanged;
end;

procedure TRegisteredComponents.RegisterComponents(const Palette: string;
  const AComponentClasses: array of TComponentClass);
var
  PaletteIndex: Integer;
  CompList: TStrings;
  i: Integer;
  Module: HMODULE;
  ClsName: string;
begin
  if Length(AComponentClasses) > 0 then
  begin
    PaletteIndex := FPalettes.IndexOf(Palette);
    if PaletteIndex = -1 then
      PaletteIndex := FPalettes.AddObject(Palette, TStringList.Create);
    CompList := TStrings(FPalettes.Objects[PaletteIndex]);

    Module := ModuleFromAddr(Caller(2));
    for i := 0 to High(AComponentClasses) do
    begin
      if (AComponentClasses[i] <> nil) and (FComponentClasses.IndexOf(AComponentClasses[i]) = -1) then
      begin
        ClsName := AComponentClasses[i].ClassName;
        CompList.AddObject(ClsName, Pointer(Module));
        FComponents.AddObject(ClsName, Pointer(Module));
        FComponentClasses.Add(AComponentClasses[i]);
      end;
    end;
    ComponentsChanged;
  end;
end;

procedure TRegisteredComponents.AddNotifier(Notifier: IComponentChangeNotifier);
begin
  if FComponentNotifiers.IndexOf(Notifier) = -1 then
    FComponentNotifiers.Add(Notifier);
end;

procedure TRegisteredComponents.RemoveNotifier(Notifier: IComponentChangeNotifier);
begin
  FComponentNotifiers.Remove(Notifier);
end;

procedure TRegisteredComponents.Clear;
var
  i: Integer;
begin
  for i := 0 to FPalettes.Count - 1 do
    FPalettes.Objects[i].Free;
  FComponents.Clear;
  FComponentClasses.Clear;
  ComponentsChanged;
end;

procedure TRegisteredComponents.ComponentsChanged;
var
  i: Integer;
begin
  Inc(FLastModifyCount);
  for i := 0 to FComponentNotifiers.Count - 1 do
    IComponentChangeNotifier(FComponentNotifiers[i]).ComponentsChanged;
end;

function TRegisteredComponents.PaletteOf(ComponentClass: TComponentClass): Integer;
var
  Index, k: Integer;
  HInstance: HINST;
  S: string;
  CompList: TStrings;
begin
  Index := FComponentClasses.IndexOf(ComponentClass);
  if Index <> -1 then
  begin
    HInstance := HINST(FComponents.Objects[Index]);
    //S := ComponentClass.ClassName;
    S := FComponents[Index];

    for Result := 0 to FPalettes.Count - 1 do
    begin
      CompList := TStrings(FPalettes.Objects[Result]);
      for k := 0 to CompList.Count - 1 do
        if SameText(CompList[k], S) and (CompList.Objects[k] = Pointer(HInstance)) then
          Exit;
    end;
  end;
  Result := -1;
end;

function TRegisteredComponents.PaletteOf(const ComponentName: string): Integer;
begin
  for Result := 0 to FPalettes.Count - 1 do
    if TStrings(FPalettes.Objects[Result]).IndexOf(ComponentName) <> -1 then
      Exit;
  Result := -1;
end;

function TRegisteredComponents.GetComponentModule(Index: Integer): HMODULE;
begin
  Result := HMODULE(FComponents.Objects[Index]);
end;

function TRegisteredComponents.FindModule(ComponentClass: TComponentClass): HMODULE;
var
  Index: Integer;
begin
  Index := FComponentClasses.IndexOf(ComponentClass);
  if Index <> -1 then
    Result := ComponentModules[Index]
  else
    Result := 0;
end;

function TRegisteredComponents.FindComponentClass(const ComponentName: string): TComponentClass;
var
  i: Integer;
begin
  for i := 0 to ComponentCount - 1 do
  begin
    if ComponentClasses[i].ClassNameIs(ComponentName) then
    begin
      Result := ComponentClasses[i];
      Exit;
    end;
  end;
  Result := nil;
end;

{------------------------------------------------------------------------------}

{$IFDEF NEED_COMPONENTMANAGER}
var
  HookRegisterComponents: TRedirectCode;
{$ENDIF NEED_COMPONENTMANAGER}

procedure HookedRegisterComponents(const Page: string;
  const ComponentClasses: array of TComponentClass);
begin
  try
    RegisteredComponents.RegisterComponents(Page, ComponentClasses);
  except
  end;
  if Assigned(RegisterComponentsProc) then
    RegisterComponentsProc(Page, ComponentClasses)
  else
    raise EComponentError.CreateRes(@SRegisterError);
end;

{------------------------------------------------------------------------------}

procedure InitComponentManager;
begin
  {$IFDEF NEED_COMPONENTMANAGER}
  CodeRedirect(@RegisterComponents, @HookedRegisterComponents, HookRegisterComponents);
  {$ENDIF NEED_COMPONENTMANAGER}
end;

procedure FiniComponentManager;
begin
  {$IFDEF NEED_COMPONENTMANAGER}
  CodeRestore(HookRegisterComponents);
  {$ENDIF NEED_COMPONENTMANAGER}
end;

end.
