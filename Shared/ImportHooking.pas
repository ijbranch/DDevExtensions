unit ImportHooking;

/// <summary>
/// Reduced JCL-derived helpers for inspecting and patching the PE import table of a loaded
/// module. Provides TJclPeMapImgHooks for installing and undoing IAT redirections by name and
/// utility routines for walking import descriptors and section headers.
/// </summary>

interface

{**************************************************************************************************}
{                                                                                                  }
{ Project JEDI Code Library (JCL)                                                                  }
{                                                                                                  }
{ The contents of this file are subject to the Mozilla Public License Version 1.1 (the "License"); }
{ you may not use this file except in compliance with the License. You may obtain a copy of the    }
{ License at http://www.mozilla.org/MPL/                                                           }
{                                                                                                  }
{ Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF   }
{ ANY KIND, either express or implied. See the License for the specific language governing rights  }
{ and limitations under the License.                                                               }
{                                                                                                  }
{ The Original Code is JclPeImage.pas.                                                             }
{                                                                                                  }
{ The Initial Developer of the Original Code is Petr Vones. Portions created by Petr Vones are     }
{ Copyright (C) Petr Vones. All Rights Reserved.                                                   }
{                                                                                                  }
{ Contributor(s):                                                                                  }
{   Marcel van Brakel                                                                              }
{   Robert Marquardt (marquardt)                                                                   }
{   Uwe Schuster (uschuster)                                                                       }
{   Matthias Thoma (mthoma)                                                                        }
{   Petr Vones (pvones)                                                                            }
{   Hallvard Vassbotn                                                                              }
{                                                                                                  }
{**************************************************************************************************}
{                                                                                                  }
{ This unit contains various classes and support routines to read the contents of portable         }
{ executable (PE) files. You can use these classes to, for example examine the contents of the     }
{ imports section of an executable. In addition the unit contains support for Borland specific     }
{ structures and name unmangling.                                                                  }
{                                                                                                  }
{ Unit owner: Petr Vones                                                                           }
{                                                                                                  }
{**************************************************************************************************}
{                                                                                                  }
{ Reduced to the minimum for import hooks and extended by Andreas Hausladen (ahuser)               }
{                                                                                                  }
{**************************************************************************************************}

{.$I jedi\jedi.inc}

uses
  Winapi.Windows,
  {$IFDEF CMD_COMPILER}
  SimpleRtl.Containers,
  {$ELSE}
  System.Classes, System.Contnrs,
  System.IniFiles, // for TStringHash
  {$ENDIF CMD_COMPILER}
  System.SysUtils;

// API hooking classes
type
  {$IF not declared(SIZE_T)}
  /// <summary>Fallback SIZE_T declaration for older Windows.pas units.</summary>
  SIZE_T = DWORD;
  {$IFEND}
  /// <summary>Pointer to a Pointer (Delphi 5 compatibility).</summary>
  PPointer = ^Pointer; // Delphi 5

  /// <summary>
  /// Records a single installed import-table hook so it can be reversed later. Each item knows
  /// its base module, the imported DLL/function name and the original/new function pointers.
  /// </summary>
  TJclPeMapImgHookItem = class(TObject)
  private
    /// <summary>Module base address whose IAT was patched.</summary>
    FBaseAddress: Pointer;
    /// <summary>Name of the imported function.</summary>
    FFunctionName: string;
    /// <summary>Name of the imported DLL.</summary>
    FModuleName: string;
    /// <summary>New function pointer that the IAT now references.</summary>
    FNewAddress: Pointer;
    /// <summary>Original function pointer, used to restore the IAT entry.</summary>
    FOriginalAddress: Pointer;
    /// <summary>Owning collection.</summary>
    FList: TObjectList;
  protected
    /// <summary>Restores the IAT entry without removing the item from the parent list.</summary>
    /// <returns>True on success or when the PE image is no longer mapped.</returns>
    function InternalUnhook: Boolean;
  public
    /// <summary>Reverses the hook (when still applicable) and frees the item.</summary>
    destructor Destroy; override;
    /// <summary>Reverses the hook and removes this item from the owning list.</summary>
    /// <returns>True when the IAT entry was restored.</returns>
    function Unhook: Boolean;
    /// <summary>Module base address whose IAT was patched.</summary>
    property BaseAddress: Pointer read FBaseAddress;
    /// <summary>Name of the imported function.</summary>
    property FunctionName: string read FFunctionName;
    /// <summary>Name of the imported DLL.</summary>
    property ModuleName: string read FModuleName;
    /// <summary>Replacement function currently installed in the IAT.</summary>
    property NewAddress: Pointer read FNewAddress;
    /// <summary>Original function the IAT pointed at before hooking.</summary>
    property OriginalAddress: Pointer read FOriginalAddress;
  end;

  /// <summary>
  /// Callback used by EnumImports. Called twice per descriptor: first with FromProc=nil to ask
  /// whether the DLL should be processed, then once per imported function with the original
  /// pointer in FromProc and ToProc set on input/output to install a replacement.
  /// </summary>
  /// <param name="ModuleName">Imported DLL name (ANSI).</param>
  /// <param name="FromProc">Original imported function pointer, or nil during the DLL filter call.</param>
  /// <param name="ToProc">In/out: the replacement pointer to install.</param>
  /// <returns>True to process the DLL or to install ToProc for FromProc.</returns>
  TReplaceImportEvent = function(ModuleName: PAnsiChar; FromProc: Pointer; var ToProc: Pointer): Boolean;

  /// <summary>Owning collection of TJclPeMapImgHookItem instances providing high-level hook/unhook APIs.</summary>
  TJclPeMapImgHooks = class(TObjectList)
  private
    /// <summary>Strongly-typed indexer used by the Items default property.</summary>
    /// <param name="Index">Zero-based index.</param>
    /// <returns>The hook item at Index.</returns>
    function GetItems(Index: NativeInt): TJclPeMapImgHookItem;
    /// <summary>Finds an item by its original IAT entry on a specific module.</summary>
    /// <param name="BaseAddress">Module base.</param>
    /// <param name="OriginalAddress">Original imported function pointer.</param>
    /// <returns>Matching item, or nil.</returns>
    function GetItemFromOriginalAddress(BaseAddress, OriginalAddress: Pointer): TJclPeMapImgHookItem;
    /// <summary>Finds an item by its current replacement function pointer.</summary>
    /// <param name="NewAddress">Replacement function pointer.</param>
    /// <returns>Matching item, or nil.</returns>
    function GetItemFromNewAddress(NewAddress: Pointer): TJclPeMapImgHookItem;
  public
    /// <summary>Marks every tracked hook as no longer reversible without actually patching the IAT.</summary>
    procedure DiscardUnhookInfo;
    /// <summary>Hooks an imported function, reporting the original address back to the caller.</summary>
    /// <param name="Base">Module base whose IAT to patch.</param>
    /// <param name="ModuleName">DLL name to match.</param>
    /// <param name="FunctionName">Imported symbol to redirect.</param>
    /// <param name="NewAddress">Replacement function.</param>
    /// <param name="OriginalAddress">Receives the original function pointer.</param>
    /// <returns>True on success.</returns>
    function HookImport(Base: Pointer; const ModuleName, FunctionName: string;
      NewAddress: Pointer; var OriginalAddress: Pointer): Boolean; overload;
    /// <summary>Hooks an imported function without returning the original address.</summary>
    /// <param name="Base">Module base whose IAT to patch.</param>
    /// <param name="ModuleName">DLL name to match.</param>
    /// <param name="FunctionName">Imported symbol to redirect.</param>
    /// <param name="NewAddress">Replacement function.</param>
    /// <returns>True on success.</returns>
    function HookImport(Base: Pointer; const ModuleName, FunctionName: string;
      NewAddress: Pointer): Boolean; overload;
    /// <summary>Hooks an imported function using a pre-resolved module handle.</summary>
    /// <param name="Base">Module base whose IAT to patch.</param>
    /// <param name="ModuleHandle">Handle of the imported DLL (for GetProcAddress).</param>
    /// <param name="ModuleName">DLL name used to match descriptors.</param>
    /// <param name="FunctionName">Imported symbol to redirect.</param>
    /// <param name="NewAddress">Replacement function.</param>
    /// <param name="OriginalAddress">Receives the original function pointer.</param>
    /// <returns>True on success.</returns>
    function HookImport(Base: Pointer; ModuleHandle: THandle;
      const ModuleName, FunctionName: string; NewAddress: Pointer;
      var OriginalAddress: Pointer): Boolean; overload;
    /// <summary>Hooks an imported function using a pre-resolved module handle without returning the original address.</summary>
    /// <param name="Base">Module base whose IAT to patch.</param>
    /// <param name="ModuleHandle">Handle of the imported DLL.</param>
    /// <param name="ModuleName">DLL name used to match descriptors.</param>
    /// <param name="FunctionName">Imported symbol to redirect.</param>
    /// <param name="NewAddress">Replacement function.</param>
    /// <returns>True on success.</returns>
    function HookImport(Base: Pointer; ModuleHandle: THandle;
      const ModuleName, FunctionName: string; NewAddress: Pointer): Boolean; overload;
    //class function IsWin9xDebugThunk(P: Pointer): Boolean;
    /// <summary>Patches every IAT entry of Base/ModuleName referencing FromProc to point at ToProc.</summary>
    /// <param name="Base">Module base.</param>
    /// <param name="ModuleName">DLL name to match.</param>
    /// <param name="FromProc">Original imported function pointer.</param>
    /// <param name="ToProc">Replacement function pointer.</param>
    /// <returns>True when at least one entry was patched.</returns>
    class function ReplaceImport(Base: Pointer; const ModuleName: string; FromProc, ToProc: Pointer): Boolean;
    /// <summary>Walks every IAT entry of Base, invoking EvReplaceImport so the caller can install replacements.</summary>
    /// <param name="Base">Module base.</param>
    /// <param name="EvReplaceImport">Caller-supplied callback.</param>
    /// <returns>True when at least one replacement was installed.</returns>
    function EnumImports(Base: Pointer; EvReplaceImport: TReplaceImportEvent): Boolean;
    {class function SystemBase: Pointer;
    procedure UnhookAll;}
    /// <summary>Returns the address of the IAT slot inside Base that resolves to FromProc on the named module.</summary>
    /// <param name="Base">Module base.</param>
    /// <param name="ModuleName">DLL name to match.</param>
    /// <param name="FromProc">Imported function whose IAT slot to locate.</param>
    /// <returns>Pointer to the IAT slot, or nil when not found.</returns>
    class function GetImportEntryPtr(Base: Pointer; const ModuleName: string; FromProc: Pointer): PPointer;
    /// <summary>Reverses the hook whose replacement function pointer matches NewAddress.</summary>
    /// <param name="NewAddress">Replacement function pointer used as a look-up key.</param>
    /// <returns>True when an item was found and unhooked.</returns>
    function UnhookByNewAddress(NewAddress: Pointer): Boolean;
    /// <summary>Reverses every hook installed against the supplied module base.</summary>
    /// <param name="BaseAddress">Module base to scan.</param>
    procedure UnhookByBaseAddress(BaseAddress: Pointer);
    /// <summary>Default indexed accessor for hook items.</summary>
    property Items[Index: NativeInt]: TJclPeMapImgHookItem read GetItems; default;
    /// <summary>Indexed look-up by (module base, original function) pair.</summary>
    property ItemFromOriginalAddress[BaseAddress, OriginalAddress: Pointer]: TJclPeMapImgHookItem read GetItemFromOriginalAddress;
    /// <summary>Indexed look-up by replacement function pointer.</summary>
    property ItemFromNewAddress[NewAddress: Pointer]: TJclPeMapImgHookItem read GetItemFromNewAddress;
  end;

/// <summary>Returns True when the host operating system is Windows NT or later.</summary>
/// <returns>True when GetVersionEx reports a Windows NT platform; False when it fails or reports Windows 9x.</returns>
function IsWinNT: Boolean;
/// <summary>Returns the IMAGE_NT_HEADERS structure of a loaded PE image, or nil on failure.</summary>
/// <param name="BaseAddress">Module base address.</param>
/// <returns>The NT headers, or nil when BaseAddress is unreadable or carries no valid DOS/NT signature.</returns>
function PeMapImgNtHeaders(const BaseAddress: Pointer): PImageNtHeaders;
/// <summary>Returns a pointer to the first IMAGE_SECTION_HEADER following the optional header.</summary>
/// <param name="NtHeaders">NT headers pointer obtained from PeMapImgNtHeaders.</param>
/// <returns>The first section header, or nil when NtHeaders is nil.</returns>
function PeMapImgSections(NtHeaders: PImageNtHeaders): PImageSectionHeader;
/// <summary>Returns the section header whose name matches SectionName, or nil when not present.</summary>
/// <param name="NtHeaders">NT headers pointer.</param>
/// <param name="SectionName">Eight-character section name (such as ".text").</param>
/// <returns>The matching section header, or nil when there is none or NtHeaders is nil.</returns>
function PeMapImgFindSection(NtHeaders: PImageNtHeaders;
  const SectionName: string): PImageSectionHeader;
/// <summary>Builds a deduplicated TStringList containing the names of every imported DLL (regular and delay-loaded).</summary>
/// <param name="MappedAddress">Base address of the mapped PE image.</param>
/// <returns>Owned TStringList instance; the caller must free it.</returns>
function CreateImportLibraryList(MappedAddress: PAnsiChar): TStrings;

implementation

uses
  System.Types; // lets the inline TObjectList.Remove in TJclPeMapImgHookItem.Unhook expand

const
  CSTR_EQUAL = 2;
  IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT      = 13;  { Delay Load Import Descriptors }

type
  ULONGLONG = Int64;

  TIIDUnion = record
    case Integer of
      0: (Characteristics: DWORD);         // 0 for terminating null import descriptor
      1: (OriginalFirstThunk: DWORD);      // RVA to original unbound IAT (PIMAGE_THUNK_DATA)
  end;

  PIMAGE_IMPORT_DESCRIPTOR = ^IMAGE_IMPORT_DESCRIPTOR;
  _IMAGE_IMPORT_DESCRIPTOR = record
    Union: TIIDUnion;
    TimeDateStamp: DWORD;                  // 0 if not bound,
                                           // -1 if bound, and real date\time stamp
                                           //     in IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT (new BIND)
                                           // O.W. date/time stamp of DLL bound to (Old BIND)

    ForwarderChain: DWORD;                 // -1 if no forwarders
    Name: DWORD;
    FirstThunk: DWORD;                     // RVA to IAT (if bound this IAT has actual addresses)
  end;
  IMAGE_IMPORT_DESCRIPTOR = _IMAGE_IMPORT_DESCRIPTOR;
  TImageImportDescriptor = IMAGE_IMPORT_DESCRIPTOR;
  PImageImportDescriptor = PIMAGE_IMPORT_DESCRIPTOR;

  PIMAGE_TLS_DIRECTORY32 = ^IMAGE_TLS_DIRECTORY32;
  _IMAGE_TLS_DIRECTORY32 = record
    StartAddressOfRawData: DWORD;
    EndAddressOfRawData: DWORD;
    AddressOfIndex: DWORD;             // PDWORD
    AddressOfCallBacks: DWORD;         // PIMAGE_TLS_CALLBACK *
    SizeOfZeroFill: DWORD;
    Characteristics: DWORD;
  end;
  IMAGE_TLS_DIRECTORY32 = _IMAGE_TLS_DIRECTORY32;
  TImageTlsDirectory32 = IMAGE_TLS_DIRECTORY32;
  PImageTlsDirectory32 = PIMAGE_TLS_DIRECTORY32;

  PIMAGE_THUNK_DATA32 = ^IMAGE_THUNK_DATA32;
  _IMAGE_THUNK_DATA32 = record
    case Integer of
      0: (ForwarderString: DWORD);   // PBYTE
      1: (Function_: DWORD);         // PDWORD
      2: (Ordinal: DWORD);
      3: (AddressOfData: DWORD);     // PIMAGE_IMPORT_BY_NAME
  end;
  IMAGE_THUNK_DATA32 = _IMAGE_THUNK_DATA32;
  TImageThunkData32 = IMAGE_THUNK_DATA32;
  PImageThunkData32 = PIMAGE_THUNK_DATA32;

  { One import address table slot: IMAGE_THUNK_DATA32 in a 32-bit image, IMAGE_THUNK_DATA64 in a
    64-bit one.  Only loaded images of this process's own bitness are walked, so the slot is
    pointer-sized.  ( The 32-bit-only declaration used before walked a 64-bit table in 4-byte
    steps, compared half addresses and wrote truncated pointers. ) }
  PImageThunkData = ^TImageThunkData;
  TImageThunkData = record
    Function_: NativeUInt;
  end;

function IsWinNT: Boolean;
var
  OSVersionInfo: TOSVersionInfo;
begin
  OSVersionInfo.dwOSVersionInfoSize := SizeOf(OSVersionInfo);
  if GetVersionEx(OSVersionInfo) then
    Result := OSVersionInfo.dwPlatformId = VER_PLATFORM_WIN32_NT
  else
    Result := False;
end;

function PeMapImgNtHeaders(const BaseAddress: Pointer): PImageNtHeaders;
begin
  Result := nil;
  if IsBadReadPtr(BaseAddress, SizeOf(TImageDosHeader)) then
    Exit;
  if (PImageDosHeader(BaseAddress)^.e_magic <> IMAGE_DOS_SIGNATURE) or
    (PImageDosHeader(BaseAddress)^._lfanew = 0) then
    Exit;
  Result := PImageNtHeaders(PAnsiChar(BaseAddress) + DWORD(PImageDosHeader(BaseAddress)^._lfanew));
  if IsBadReadPtr(Result, SizeOf(TImageNtHeaders)) or
    (Result^.Signature <> IMAGE_NT_SIGNATURE) then
      Result := nil
end;

function PeMapImgSections(NtHeaders: PImageNtHeaders): PImageSectionHeader;
begin
  if NtHeaders = nil then
    Result := nil
  else
    Result := PImageSectionHeader(PAnsiChar(@NtHeaders^.OptionalHeader) +
      NtHeaders^.FileHeader.SizeOfOptionalHeader);
end;

function PeMapImgFindSection(NtHeaders: PImageNtHeaders;
  const SectionName: string): PImageSectionHeader;
var
  Header: PImageSectionHeader;
  I: Integer;
  P: PAnsiChar;
begin
  Result := nil;
  if NtHeaders <> nil then
  begin
    P := PAnsiChar({$IFDEF UNICODE}UTF8Encode{$ENDIF}(SectionName));
    Header := PeMapImgSections(NtHeaders);
    with NtHeaders^ do
      for I := 1 to FileHeader.NumberOfSections do
        {$WARNINGS OFF}
        if StrLComp(PAnsiChar(@Header^.Name), P, IMAGE_SIZEOF_SHORT_NAME) = 0 then
        {$WARNINGS ON}
        begin
          Result := Header;
          Break;
        end
        else
          Inc(Header);
  end;
end;

{ TJclPeMapImgHookItem }

destructor TJclPeMapImgHookItem.Destroy;
begin
  if FBaseAddress <> nil then
    InternalUnhook;
  inherited Destroy;
end;

function TJclPeMapImgHookItem.InternalUnhook: Boolean;
var
  Buf: TMemoryBasicInformation;
begin
  if (VirtualQuery(FBaseAddress, Buf, SizeOf(Buf)) = SizeOf(Buf)) and (Buf.State and MEM_FREE = 0) then
    Result := TJclPeMapImgHooks.ReplaceImport(FBaseAddress, ModuleName, NewAddress, OriginalAddress)
  else
    Result := True; // PE image is not available anymore (DLL got unloaded)
  if Result then
    FBaseAddress := nil
  else
    // The slot no longer holds our address (another hook replaced it): leave it alone, but say so,
    // because a chain that saved our address as its "original" would later call into freed code.
    OutputDebugString( PChar( Format( 'ImportHooking: could not restore the %s import of %s; the slot was ' +
      're-hooked by someone else', [ModuleName, FFunctionName] ) ) );
end;

function TJclPeMapImgHookItem.Unhook: Boolean;
begin
  Result := InternalUnhook;
  if Result then
    FList.Remove(Self);
end;

{ TJclPeMapImgHooks }

function TJclPeMapImgHooks.GetItems(Index: NativeInt): TJclPeMapImgHookItem;
begin
  Result := TJclPeMapImgHookItem(inherited Items[Index]);
end;

function TJclPeMapImgHooks.GetItemFromNewAddress(NewAddress: Pointer): TJclPeMapImgHookItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do
    if Items[I].NewAddress = NewAddress then
    begin
      Result := Items[I];
      Break;
    end;
end;

function TJclPeMapImgHooks.GetItemFromOriginalAddress(BaseAddress, OriginalAddress: Pointer): TJclPeMapImgHookItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do
    if (Items[I].BaseAddress = BaseAddress) and (Items[I].OriginalAddress = OriginalAddress) then
    begin
      Result := Items[I];
      Break;
    end;
end;

function TJclPeMapImgHooks.HookImport(Base: Pointer; const ModuleName, FunctionName: string;
  NewAddress: Pointer): Boolean;
var
  P: Pointer;
begin
  Result := HookImport(Base, ModuleName, FunctionName, NewAddress, P);
end;

function TJclPeMapImgHooks.HookImport(Base: Pointer; const ModuleName, FunctionName: string;
  NewAddress: Pointer; var OriginalAddress: Pointer): Boolean;
begin
  Result := HookImport(Base, GetModuleHandle(PChar(ModuleName)), ModuleName, FunctionName,
    NewAddress, OriginalAddress);
end;

function TJclPeMapImgHooks.HookImport(Base: Pointer; ModuleHandle: THandle;
  const ModuleName, FunctionName: string; NewAddress: Pointer): Boolean;
var
  P: Pointer;
begin
  Result := HookImport(Base, ModuleHandle, ModuleName, FunctionName, NewAddress, P);
end;

function TJclPeMapImgHooks.HookImport(Base: Pointer; ModuleHandle: THandle;
  const ModuleName, FunctionName: string; NewAddress: Pointer; var OriginalAddress: Pointer): Boolean;
var
  Item: TJclPeMapImgHookItem;
begin
  Result := (ModuleHandle <> 0);
  if not Result then
  begin
    SetLastError(ERROR_MOD_NOT_FOUND);
    Exit;
  end;
  OriginalAddress := GetProcAddress(ModuleHandle, PAnsiChar(AnsiString(FunctionName)));
  Result := (OriginalAddress <> nil);
  if not Result then
  begin
    SetLastError(ERROR_PROC_NOT_FOUND);
    Exit;
  end;
  Result := {(ItemFromOriginalAddress[Base, OriginalAddress] = nil) and} (NewAddress <> nil) and
    (OriginalAddress <> NewAddress);
  if not Result then
  begin
    SetLastError(ERROR_ALREADY_EXISTS);
    Exit;
  end;
  // Clear the last error so a failure below reports its own cause (a VirtualProtect error is kept).
  SetLastError( ERROR_SUCCESS );
  Result := ReplaceImport(Base, ModuleName, OriginalAddress, NewAddress);
  if Result then
  begin
    Item := TJclPeMapImgHookItem.Create;
    Item.FBaseAddress := Base;
    Item.FFunctionName := FunctionName;
    Item.FModuleName := ModuleName;
    Item.FOriginalAddress := OriginalAddress;
    Item.FNewAddress := NewAddress;
    Item.FList := Self;
    Add(Item);
  end
  else
  if ( GetLastError = ERROR_SUCCESS ) then
    SetLastError( ERROR_PROC_NOT_FOUND ); // no import slot held OriginalAddress
end;

/// <summary>
/// Points the import address table slot Slot at ToProc, making the page writable for the write.
/// </summary>
/// <param name="Slot">IAT slot to patch.</param>
/// <param name="ToProc">New target.</param>
/// <returns>True when the slot was written.</returns>
function WriteImportSlot(Slot: PImageThunkData; ToProc: Pointer): Boolean;
var
  LastProtect, Dummy: DWORD;
begin
  Result := VirtualProtect(@Slot^.Function_, SizeOf(Slot^.Function_), PAGE_READWRITE, @LastProtect);
  if Result then
  begin
    // One aligned pointer-sized store: a thread calling through the slot sees the old or the new
    // target, never a mix.
    Slot^.Function_ := NativeUInt(ToProc);
    // According to Platform SDK documentation, the last parameter has to be (point to) a valid variable
    VirtualProtect(@Slot^.Function_, SizeOf(Slot^.Function_), LastProtect, @Dummy);
  end;
end;

class function TJclPeMapImgHooks.ReplaceImport(Base: Pointer; const ModuleName: string;
  FromProc, ToProc: Pointer): Boolean;
var
  NtHeader: PImageNtHeaders;
  ImportDir: TImageDataDirectory;
  ImportDesc: PImageImportDescriptor;
  CurrName: PAnsiChar;
  RefName: AnsiString;
  ImportEntry: PImageThunkData;
begin
  Result := False;
  NtHeader := PeMapImgNtHeaders(Base);
  if (NtHeader = nil) or (FromProc = nil) then
    Exit;
  ImportDir := NtHeader.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
  if ImportDir.VirtualAddress = 0 then
    Exit;
  ImportDesc := PImageImportDescriptor(PAnsiChar(Base) + ImportDir.VirtualAddress);
  RefName := AnsiString(ModuleName);
  while ImportDesc^.Name <> 0 do
  begin
    CurrName := PAnsiChar(Base) + ImportDesc^.Name;
    if lstrcmpiA(CurrName, PAnsiChar(RefName)) = 0 then
    begin
      ImportEntry := PImageThunkData(PAnsiChar(Base) + ImportDesc^.FirstThunk);
      while ImportEntry^.Function_ <> 0 do
      begin
        if (Pointer(ImportEntry^.Function_) = FromProc) and WriteImportSlot(ImportEntry, ToProc) then
          Result := True;
        Inc(ImportEntry);
      end;
    end;
    Inc(ImportDesc);
  end;
end;

function TJclPeMapImgHooks.EnumImports(Base: Pointer; EvReplaceImport: TReplaceImportEvent): Boolean;
var
  NtHeader: PImageNtHeaders;
  ImportDir: TImageDataDirectory;
  ImportDesc: PImageImportDescriptor;
  CurrName: PAnsiChar;
  ImportEntry: PImageThunkData;
  FromProc, ToProc: Pointer;
  Item: TJclPeMapImgHookItem;
begin
  Result := False;
  NtHeader := PeMapImgNtHeaders(Base);
  if NtHeader = nil then
    Exit;
  ImportDir := NtHeader.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
  if ImportDir.VirtualAddress = 0 then
    Exit;
  ImportDesc := PImageImportDescriptor(PAnsiChar(Base) + ImportDir.VirtualAddress);
  while ImportDesc^.Name <> 0 do
  begin
    CurrName := PAnsiChar(Base) + ImportDesc^.Name;
    ToProc := nil;
    if EvReplaceImport(CurrName, nil, ToProc) then
    begin
      ImportEntry := PImageThunkData(PAnsiChar(Base) + ImportDesc^.FirstThunk);
      while ImportEntry^.Function_ <> 0 do
      begin
        FromProc := Pointer(ImportEntry^.Function_);
        ToProc := nil;
        if EvReplaceImport(CurrName, FromProc, ToProc) and Assigned(ToProc) and
           WriteImportSlot(ImportEntry, ToProc) then
        begin
          Item := TJclPeMapImgHookItem.Create;
          Item.FBaseAddress := Base;
          Item.FModuleName := string(AnsiString(CurrName));
          Item.FOriginalAddress := FromProc;
          Item.FNewAddress := ToProc;
          Item.FList := Self;
          Add(Item);
          Result := True;
        end;
        Inc(ImportEntry);
      end;
    end;
    Inc(ImportDesc);
  end;
end;

class function TJclPeMapImgHooks.GetImportEntryPtr(Base: Pointer; const ModuleName: string; FromProc: Pointer): PPointer;
var
  NtHeader: PImageNtHeaders;
  ImportDir: TImageDataDirectory;
  ImportDesc: PImageImportDescriptor;
  CurrName: PAnsiChar;
  RefName: AnsiString;
  ImportEntry: PImageThunkData;
begin
  Result := nil;
  NtHeader := PeMapImgNtHeaders(Base);
  if NtHeader = nil then
    Exit;
  ImportDir := NtHeader.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
  if ImportDir.VirtualAddress = 0 then
    Exit;
  ImportDesc := PImageImportDescriptor(PAnsiChar(Base) + ImportDir.VirtualAddress);
  RefName := AnsiString(ModuleName);
  while ImportDesc^.Name <> 0 do
  begin
    CurrName := PAnsiChar(Base) + ImportDesc^.Name;
    if lstrcmpiA(CurrName, PAnsiChar(RefName)) = 0 then
    begin
      ImportEntry := PImageThunkData(PAnsiChar(Base) + ImportDesc^.FirstThunk);
      while ImportEntry^.Function_ <> 0 do
      begin
        if Pointer(ImportEntry^.Function_) = FromProc then
        begin
          Result := PPointer(@ImportEntry^.Function_);
          Exit;
        end;
        Inc(ImportEntry);
      end;
    end;
    Inc(ImportDesc);
  end;
end;

function TJclPeMapImgHooks.UnhookByNewAddress(NewAddress: Pointer): Boolean;
var
  Item: TJclPeMapImgHookItem;
begin
  Item := ItemFromNewAddress[NewAddress];
  Result := (Item <> nil) and Item.Unhook;
end;

procedure TJclPeMapImgHooks.UnhookByBaseAddress(BaseAddress: Pointer);
var
  I: Integer;
begin
  for I := Count - 1 downto 0 do
    if Items[I].BaseAddress = BaseAddress then
      Items[I].Unhook;
end;

procedure TJclPeMapImgHooks.DiscardUnhookInfo;
var
  I: Integer;
  {$IF (CompilerVersion >= 23.0) or defined(CMD_COMPILER)}  // XE2+ or Simple.Containers
  L: TPointerList;
  {$ELSE}
  L: PPointerList;
  {$IFEND}
begin
  L := List;
  for I := Count downto 1 do
    TJclPeMapImgHookItem(L[I - 1]).FBaseAddress := nil;
    //Items[I - 1].FBaseAddress := nil;
end;

const
  ImageHlpLib = 'imagehlp.dll';
type
  USHORT = Word;

  { IMAGE_DELAYLOAD_DESCRIPTOR ( RVA form ): eight DWORDs on Win32 and Win64 alike.  The pointer
    and thunk fields declared before made the record larger on Win64, so stepping to the next
    descriptor landed in the wrong place. }
  ImgDelayDescr = packed record
    grAttrs: DWORD;                 // attributes
    szName: DWORD;                  // RVA of the DLL name
    phmod: DWORD;                   // RVA of the module handle
    pIAT: DWORD;                    // RVA of the IAT
    pINT: DWORD;                    // RVA of the INT
    pBoundIAT: DWORD;               // RVA of the optional bound IAT
    pUnloadIAT: DWORD;              // RVA of the optional copy of the original IAT
    dwTimeStamp: DWORD;             // 0 if not bound,
                                    // O.W. date/time stamp of DLL bound to (Old BIND)
  end;
  TImgDelayDescr = ImgDelayDescr;
  PImgDelayDescr = ^ImgDelayDescr;

  PIMAGE_BOUND_IMPORT_DESCRIPTOR = ^IMAGE_BOUND_IMPORT_DESCRIPTOR;
  _IMAGE_BOUND_IMPORT_DESCRIPTOR = record
    TimeDateStamp: DWORD;
    OffsetModuleName: Word;
    NumberOfModuleForwarderRefs: Word;
    // Array of zero or more IMAGE_BOUND_FORWARDER_REF follows
  end;
  IMAGE_BOUND_IMPORT_DESCRIPTOR = _IMAGE_BOUND_IMPORT_DESCRIPTOR;
  TImageBoundImportDescriptor = IMAGE_BOUND_IMPORT_DESCRIPTOR;
  PImageBoundImportDescriptor = PIMAGE_BOUND_IMPORT_DESCRIPTOR;


function ImageDirectoryEntryToData(Base: Pointer; MappedAsImage: ByteBool;
  DirectoryEntry: USHORT; var Size: ULONG): Pointer; stdcall;
  external ImageHlpLib name 'ImageDirectoryEntryToData';

function DirectoryEntryToData(MappedAddress: PAnsiChar; Directory: Word): Pointer;
var
  Size: DWORD;
begin
  Result := ImageDirectoryEntryToData(MappedAddress, True, Directory, Size);
end;

function RvaToVa(MappedAddress: PAnsiChar; Rva: DWORD): Pointer;
begin
  Result := MappedAddress + Rva;
end;

function RvaToVaEx(MappedAddress: PAnsiChar; Rva: DWORD): Pointer;
var
  NtHeaders: PImageNtHeaders;
begin
  NtHeaders := PeMapImgNtHeaders(MappedAddress);
  if NtHeaders <> nil then
  begin
    if (Rva > NtHeaders^.OptionalHeader.SizeOfImage) and (Rva > NtHeaders^.OptionalHeader.ImageBase) then
      Dec(Rva, NtHeaders^.OptionalHeader.ImageBase);
    Result := RvaToVa(MappedAddress, Rva);
  end
  else
    Result := nil;
end;

function CreateImportLibraryList(MappedAddress: PAnsiChar): TStrings;
var
  ImportDesc: PImageImportDescriptor;
  DelayImportDesc: PImgDelayDescr;
  S: string;
  HashTable: TStringHash;
begin
  HashTable := TStringHash.Create;
  Result := TStringList.Create;
  try
    ImportDesc := DirectoryEntryToData(MappedAddress, IMAGE_DIRECTORY_ENTRY_IMPORT);
    if ImportDesc <> nil then
      while ImportDesc^.Name <> 0 do
      begin
        S := {$IFDEF UNICODE}UTF8ToString{$ENDIF}(PAnsiChar(RvaToVa(MappedAddress, ImportDesc^.Name)));
        if (S <> '') then
        begin
          if HashTable.ValueOf(S) = -1 then
          begin
            HashTable.Add(S, 1);
            Result.Add(S);
          end;
        end;
        Inc(ImportDesc);
      end;
    DelayImportDesc := DirectoryEntryToData(MappedAddress, IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT);
    if DelayImportDesc <> nil then
    begin
      while DelayImportDesc^.szName <> 0 do
      begin
        S := {$IFDEF UNICODE}UTF8ToString{$ENDIF}(PAnsiChar(RvaToVaEx(MappedAddress, DelayImportDesc^.szName)));
        if (S <> '') then
        begin
          if HashTable.ValueOf(S) = -1 then
          begin
            HashTable.Add(S, 1);
            Result.Add(S);
          end;
        end;
        Inc(DelayImportDesc);
      end;
    end;
  except
    HashTable.Free;
    Result.Free;
    raise;
  end;
end;

end.

