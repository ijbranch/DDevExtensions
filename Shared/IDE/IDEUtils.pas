{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2005,2006 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit IDEUtils;

/// <summary>
/// Grab-bag of utility routines used throughout the DDevExtensions IDE plugin: file/registry
/// helpers, string-to-integer/string-to-string hash tables, a reusable bucket list, low-level
/// VMT and IInterface tricks, environment macro expansion ($ ( BDS ), $ ( PLATFORM ), ...) and
/// IDE-event subscription helpers (TIDEEvent, MainFormShown/Created/Destroyed).
/// </summary>

//{$I jedi\jedi.inc}
{$IFDEF VER170} {$DEFINE COMPILER9} {$ENDIF}  // Delphi 2005
{$IFDEF VER180} {$DEFINE COMPILER10} {$ENDIF} // Delphi 2006
{$IFDEF VER185} {$DEFINE COMPILER11} {$UNDEF COMPILER10} {$ENDIF} // Delphi 2007
{$IFDEF VER200} {$DEFINE COMPILER12} {$ENDIF} // Delphi 2009
{$IFDEF VER210} {$DEFINE COMPILER14} {$ENDIF} // Delphi 2010
{$IFDEF VER220} {$DEFINE COMPILER15} {$ENDIF} // Delphi XE

{$IF CompilerVersion >= 170} {$DEFINE COMPILER9_UP} {$IFEND}
{$IF CompilerVersion >= 180} {$DEFINE COMPILER10_UP} {$IFEND}
{$IF CompilerVersion >= 185} {$DEFINE COMPILER11_UP} {$IFEND}
{$IF CompilerVersion >= 200} {$DEFINE COMPILER12_UP} {$IFEND}
{$IF CompilerVersion >= 210} {$DEFINE COMPILER14_UP} {$IFEND}
{$IF CompilerVersion >= 220} {$DEFINE COMPILER15_UP} {$IFEND}

interface

uses
  Winapi.Windows, Winapi.ShlObj, System.SysUtils, System.Contnrs, System.Classes,
  System.Variants, System.StrUtils, Vcl.Graphics,
  {$IF CompilerVersion >= 23.0} // XE2+
  PlatformAPI,
  {$IFEND}
  ToolsAPI,
  Vcl.Forms, IDEHashLists;

{$IFNDEF COMPILER11_UP}
type
  /// <summary>Pointer-sized signed integer alias for pre-D2007 compilers.</summary>
  INT_PTR = Integer;
  /// <summary>Pointer-sized unsigned integer alias for pre-D2007 compilers.</summary>
  DWORD_PTR = DWORD;
{$ENDIF ~COMPILER11_UP}

/// <summary>Convenience wrapper around Supports that returns False for nil instances without raising.</summary>
/// <param name="Instance">Object to query.</param>
/// <param name="IID">Interface GUID.</param>
/// <param name="Intf">Receives the interface reference on success.</param>
/// <returns>True when Instance implements IID.</returns>
function SupportsEx(const Instance: TObject; const IID: TGUID; out Intf): Boolean;

/// <summary>Faster alternative to SysUtils.FileExists that excludes directories and avoids exception cost.</summary>
/// <param name="Filename">Path to test; empty gives False.</param>
/// <returns>True when Filename exists and is not a directory.</returns>
function FastFileExists(const Filename: string): Boolean;
/// <summary>Returns Dir with a trailing path delimiter appended when missing.</summary>
/// <param name="Dir">Directory path; may be empty.</param>
/// <returns>Dir ending in a path delimiter, or empty when Dir is empty.</returns>
function IncludeTrailingPathDelimiter(const Dir: string): string;
/// <summary>Returns Dir with any trailing path delimiter removed (preserving "C:\").</summary>
/// <param name="Dir">Directory path.</param>
/// <returns>Dir without a trailing delimiter; a bare drive keeps its "\".</returns>
function ExcludeTrailingPathDelimiter(const Dir: string): string;
/// <summary>Returns the DOS-format last-write timestamp of Filename, or -1 when the file is missing.</summary>
/// <param name="Filename">File to query.</param>
/// <returns>The local last-write time as a DOS date/time, or -1 when the file is missing.</returns>
function FileAgeFindFile(const Filename: string): Integer;
/// <summary>Returns the size in bytes of Filename without opening it.</summary>
/// <param name="Filename">File to query.</param>
/// <returns>The low 32 bits of the file size, or 0 when the file is missing.</returns>
function GetFileSize(const Filename: string): Cardinal;
/// <summary>Generates a unique temporary filename in the user temp directory using Base as the prefix.</summary>
/// <exception cref="EOSError">Raised when GetTempFileName fails.</exception>
/// <param name="Base">Prefix for the temporary file name.</param>
/// <returns>Full path of the new, empty temporary file.</returns>
function GetTempName(const Base: string): string;

/// <summary>Case-insensitive AnsiStartsText wrapper.</summary>
/// <param name="SubStr">Prefix to look for.</param>
/// <param name="S">String to test.</param>
/// <returns>True when S starts with SubStr, ignoring case.</returns>
function StartsText(const SubStr, S: string): Boolean;
/// <summary>Case-insensitive AnsiEndsText wrapper.</summary>
/// <param name="SubStr">Suffix to look for.</param>
/// <param name="S">String to test.</param>
/// <returns>True when S ends with SubStr, ignoring case.</returns>
function EndsText(const SubStr, S: string): Boolean;

/// <summary>True when Value matches any element of Values (case-insensitive).</summary>
/// <param name="Value">String to look for.</param>
/// <param name="Values">Candidates.</param>
/// <returns>True when Value equals one of Values, ignoring case.</returns>
function InArray(const Value: string; const Values: array of string): Boolean;
/// <summary>Strips matching surrounding double-quote characters from S.</summary>
/// <param name="S">String to dequote.</param>
/// <returns>S without its surrounding double quotes, or S unchanged.</returns>
function DequoteStr(const S: string): string;

/// <summary>Reads a Boolean option from the IDE's Globals registry key.</summary>
/// <param name="ValueName">Name of the registry value.</param>
/// <param name="DefaultValue">Returned when the key is missing.</param>
/// <returns>The option, or DefaultValue when the IDE services, the key or the value are missing.</returns>
function ReadGlobalRegOption(const ValueName: string; DefaultValue: Boolean = False): Boolean;
/// <summary>Reads a string registry value, accepting integer/expand_string variants and returning DefaultValue when absent.</summary>
/// <param name="RootKey">Registry root, such as HKEY_CURRENT_USER.</param>
/// <param name="Key">Key path below RootKey.</param>
/// <param name="ValueName">Name of the value.</param>
/// <param name="DefaultValue">Returned when the key or value is missing, empty or of another type.</param>
/// <returns>The value as a string.</returns>
function RegReadStringDef(RootKey: HKEY; const Key, ValueName, DefaultValue: string): string;
/// <summary>Reads a Boolean registry value, accepting string/integer variants and returning DefaultValue when absent.</summary>
/// <param name="RootKey">Registry root, such as HKEY_CURRENT_USER.</param>
/// <param name="Key">Key path below RootKey.</param>
/// <param name="ValueName">Name of the value.</param>
/// <param name="DefaultValue">Returned when the key or value is missing, empty or of another type.</param>
/// <returns>The value; a string value is True unless it is "0".</returns>
function RegReadBoolDef(RootKey: HKEY; const Key, ValueName: string; DefaultValue: Boolean): Boolean;
/// <summary>Writes Value as a string registry value at Key/ValueName, creating the key when needed.</summary>
/// <param name="RootKey">Registry root, such as HKEY_CURRENT_USER.</param>
/// <param name="Key">Key path below RootKey.</param>
/// <param name="ValueName">Name of the value to write.</param>
/// <param name="Value">String data to store.</param>
/// <returns>True when the key could be opened (or created) and the value was written; never raises.</returns>
function TryRegWriteString(RootKey: HKEY; const Key, ValueName, Value: string): Boolean;
/// <summary>Writes Value as a string registry value at Key/ValueName, creating the key when needed.</summary>
/// <param name="RootKey">Registry root, such as HKEY_CURRENT_USER.</param>
/// <param name="Key">Key path below RootKey.</param>
/// <param name="ValueName">Name of the value to write.</param>
/// <param name="Value">String data to store.</param>
/// <remarks>Never raises: a failure is reported with OutputDebugString only.  Use TryRegWriteString to detect it.</remarks>
procedure RegWriteString(RootKey: HKEY; const Key, ValueName, Value: string);
/// <summary>Deletes the registry value at Key/ValueName when it exists.</summary>
/// <param name="RootKey">Registry root, such as HKEY_CURRENT_USER.</param>
/// <param name="Key">Key path below RootKey.</param>
/// <param name="ValueName">Name of the value.</param>
procedure RegDeleteEntry(RootKey: HKEY; const Key, ValueName: string);

/// <summary>Locates a TCustomForm by name and/or class name. Pass empty strings to match any.</summary>
/// <param name="AFormName">Form Name to match, ignoring case; empty matches any.</param>
/// <param name="AFormClassName">Class name to match; empty matches any.</param>
/// <returns>The first matching form, or nil.</returns>
function FindForm(const AFormName, AFormClassName: string): TCustomForm;
/// <summary>True when AObject's class hierarchy contains a class whose name matches AClassName.</summary>
/// <param name="AObject">Object to test; nil gives False.</param>
/// <param name="AClassName">Class name to look for.</param>
/// <returns>True when the class of AObject, or one of its ancestors, has that name.</returns>
function InheritsFromClassName(AObject: TObject; const AClassName: string): Boolean;

const
  /// <summary>Number of preallocated cache slots used by the string hash tables (see IDEHashLists).</summary>
  MaxCacheItems = IDEHashLists.MaxCacheItems;
  /// <summary>Number of buckets used by TCustomBucketList (see IDEHashLists).</summary>
  MaxBucketItems = IDEHashLists.MaxBucketItems;
  /// <summary>Re-export of IDEHashLists.bl2.</summary>
  bl2 = IDEHashLists.bl2;
  /// <summary>Re-export of IDEHashLists.bl4.</summary>
  bl4 = IDEHashLists.bl4;
  /// <summary>Re-export of IDEHashLists.bl8.</summary>
  bl8 = IDEHashLists.bl8;
  /// <summary>Re-export of IDEHashLists.bl16.</summary>
  bl16 = IDEHashLists.bl16;
  /// <summary>Re-export of IDEHashLists.bl32.</summary>
  bl32 = IDEHashLists.bl32;
  /// <summary>Re-export of IDEHashLists.bl64.</summary>
  bl64 = IDEHashLists.bl64;
  /// <summary>Re-export of IDEHashLists.bl128.</summary>
  bl128 = IDEHashLists.bl128;
  /// <summary>Re-export of IDEHashLists.bl256.</summary>
  bl256 = IDEHashLists.bl256;

type
  /// <summary>Re-export of IDEHashLists.THashValue.</summary>
  THashValue = IDEHashLists.THashValue;
  /// <summary>Re-export of IDEHashLists.PStringIntegerItem.</summary>
  PStringIntegerItem = IDEHashLists.PStringIntegerItem;
  /// <summary>Re-export of IDEHashLists.TStringIntegerItem.</summary>
  TStringIntegerItem = IDEHashLists.TStringIntegerItem;
  /// <summary>Re-export of IDEHashLists.TStringIntegerHash.</summary>
  TStringIntegerHash = IDEHashLists.TStringIntegerHash;
  /// <summary>Re-export of IDEHashLists.PStringStringItem.</summary>
  PStringStringItem = IDEHashLists.PStringStringItem;
  /// <summary>Re-export of IDEHashLists.TStringStringItem.</summary>
  TStringStringItem = IDEHashLists.TStringStringItem;
  /// <summary>Re-export of IDEHashLists.TStringStringHash.</summary>
  TStringStringHash = IDEHashLists.TStringStringHash;
  /// <summary>Re-export of IDEHashLists.PBucketListItem.</summary>
  PBucketListItem = IDEHashLists.PBucketListItem;
  /// <summary>Re-export of IDEHashLists.TBucketListItem.</summary>
  TBucketListItem = IDEHashLists.TBucketListItem;
  /// <summary>Re-export of IDEHashLists.TBucketProc.</summary>
  TBucketProc = IDEHashLists.TBucketProc;
  /// <summary>Re-export of IDEHashLists.TCustomBucketList.</summary>
  TCustomBucketList = IDEHashLists.TCustomBucketList;
  /// <summary>Re-export of IDEHashLists.TBucketListSizes.</summary>
  TBucketListSizes = IDEHashLists.TBucketListSizes;
  /// <summary>Re-export of IDEHashLists.TBucketList.</summary>
  TBucketList = IDEHashLists.TBucketList;
  /// <summary>Re-export of IDEHashLists.TModuleBucketList.</summary>
  TModuleBucketList = IDEHashLists.TModuleBucketList;

/// <summary>Computes a hash of AItem in the range 0..MaxBucketItems-1 (delegates to IDEHashLists.HashString).</summary>
/// <param name="AItem">String to hash.</param>
/// <returns>Bucket index in 0..MaxBucketItems-1.</returns>
function HashString(const AItem: string): Integer;

/// <summary>Performs a colour-keyed StretchBlt by composing the foreground onto the destination through a mask.</summary>
/// <param name="DstDC">Destination device context.</param>
/// <param name="DstX">Destination left.</param>
/// <param name="DstY">Destination top.</param>
/// <param name="DstW">Destination width.</param>
/// <param name="DstH">Destination height.</param>
/// <param name="SrcDC">Source device context; its map mode is set to the destination's.</param>
/// <param name="SrcX">Source left.</param>
/// <param name="SrcY">Source top.</param>
/// <param name="SrcW">Source width.</param>
/// <param name="SrcH">Source height.</param>
/// <param name="Palette">Palette to realise, or 0 for none.</param>
/// <param name="TransparentColor">Source colour drawn as transparent.</param>
procedure StretchBltTransparent(DstDC: HDC; DstX, DstY, DstW, DstH: Integer;
  SrcDC: HDC; SrcX, SrcY, SrcW, SrcH: Integer; Palette: HPALETTE;
  TransparentColor: TColorRef);

/// <summary>Returns the module handle that owns the specified code address.</summary>
/// <param name="Addr">Code or data address.</param>
/// <returns>Handle of the module containing Addr, or 0 when Addr is nil or in no module.</returns>
function ModuleFromAddr(const Addr: Pointer): HMODULE;
/// <summary>Walks the call stack and returns the address of the caller at the requested level.</summary>
/// <param name="Level">0 returns the immediate caller; positive values look further up.</param>
/// <returns>The return address at that level minus 1, or nil when the stack is shallower or cannot be walked.</returns>
function Caller(Level: Integer): Pointer;
/// <summary>Builds a TNotifyEvent value from raw Data and Code pointers.</summary>
/// <param name="Data">Instance pointer ( Self ).</param>
/// <param name="Code">Method address.</param>
/// <returns>The combined method pointer.</returns>
function MakeNotifyEvent(Data, Code: Pointer): TNotifyEvent;

/// <summary>
/// Recovers the underlying Delphi TObject from an interface reference by inspecting the
/// thunk that QueryInterface uses to compute Self.
/// </summary>
/// <param name="Intf">Interface reference; may be nil.</param>
/// <returns>The implementing object, or nil when Intf is nil or not implemented by a Delphi object.</returns>
function DelphiInterfaceToObject(const Intf: IInterface): TObject;
/// <summary>Returns the address of the QueryInterface implementation referenced by Intf's vtable.</summary>
/// <param name="Intf">Interface reference.</param>
/// <returns>The QueryInterface implementation, or nil when the thunk is not recognised (x86 thunks only).</returns>
function GetQueryInterfaceImplFromDelphiInterface(const Intf: IInterface): Pointer;
/// <summary>Returns the address of the method at VmtOffset in the vtable referenced by Intf.</summary>
/// <param name="Intf">Interface reference.</param>
/// <param name="VmtOffset">Byte offset of the method in the interface table.</param>
/// <returns>The method implementation, or nil when the thunk is not recognised (x86 thunks only).</returns>
function GetMethodImplFromDelphiInterface(const Intf: IInterface; VmtOffset: Integer): Pointer;
/// <summary>Scans Obj's fields and returns the first (or last) one whose object's class hierarchy contains AClassName.</summary>
/// <exception cref="Exception">Raised when no matching field is found.</exception>
/// <param name="Obj">Object whose fields are scanned.</param>
/// <param name="AClassName">Class name the field's object must have or inherit.</param>
/// <param name="FindLast">True to scan from the last field backwards.</param>
/// <returns>The object held in the matching field.</returns>
/// <exception cref="Exception">Raised when no field holds such an object.</exception>
function FindObjectField(Obj: TObject; const AClassName: string; FindLast: Boolean = False): TObject;
/// <summary>Returns the byte offset within Obj of a field whose object inherits from AClassName, or 0 when not found.</summary>
/// <param name="Obj">Object whose fields are scanned; nil gives 0.</param>
/// <param name="AClassName">Class name the field's object must have or inherit.</param>
/// <param name="FindLast">True to scan from the last field backwards.</param>
/// <returns>Byte offset of the matching field, or 0 when none matches.</returns>
function FindObjectFieldOffset(Obj: TObject; const AClassName: string; FindLast: Boolean): Cardinal; // Result=0 => not found

/// <summary>Variant-to-Integer conversion that returns Default on null/empty/invalid values.</summary>
/// <param name="V">Value to convert.</param>
/// <param name="Default">Returned for empty, null, empty-string or unconvertible values.</param>
/// <returns>The converted value.</returns>
function VarToIntDef(const V: Variant; Default: Integer): Integer;
/// <summary>Variant-to-Boolean conversion that returns Default on null/empty/invalid values.</summary>
/// <param name="V">Value to convert.</param>
/// <param name="Default">Returned for empty, null, empty-string or unconvertible values.</param>
/// <returns>The converted value.</returns>
function VarToBoolDef(const V: Variant; Default: Boolean): Boolean;
/// <summary>Variant-to-string conversion that returns Default on null/empty/invalid values.</summary>
/// <param name="V">Value to convert.</param>
/// <param name="Default">Returned for empty, null or unconvertible values.</param>
/// <returns>The converted value.</returns>
function VarToStrDef(const V: Variant; const Default: string): string;

/// <summary>Wraps Filename in double quotes when it contains spaces, dashes or pluses.</summary>
/// <param name="Filename">File name to quote.</param>
/// <returns>Filename in double quotes when it needs them and is not already quoted; otherwise unchanged.</returns>
function QuoteFilename(const Filename: string): string;
/// <summary>Strips matching surrounding double quotes from S.</summary>
/// <param name="S">String to dequote.</param>
/// <returns>S without its surrounding double quotes, or S unchanged.</returns>
function Dequote(const S: string): string;

/// <summary>Splits a semicolon-delimited path list into List, optionally skipping duplicates and stripping quotes.</summary>
/// <param name="List">Receives the paths; existing lines are kept.</param>
/// <param name="Paths">Semicolon-separated path list.</param>
/// <param name="DeleteDuplicates">True to skip a path already in List.</param>
procedure SplitPaths(List: TStrings; const Paths: string; DeleteDuplicates: Boolean = False); // removes quotes
/// <summary>Joins List using Delim, quoting individual paths that contain spaces.</summary>
/// <param name="List">Paths to join.</param>
/// <param name="Delim">Separator.</param>
/// <returns>The joined list.</returns>
function ConcatPaths(List: TStrings; const Delim: string): string; // add quotes where necessary
/// <summary>Convenience helper that splits Paths and re-joins it with Separator while removing duplicates.</summary>
/// <param name="Paths">Semicolon-separated path list.</param>
/// <param name="Separator">Separator for the result.</param>
/// <returns>The de-duplicated, re-joined list.</returns>
function SplitAndConcatPaths(const Paths, Separator: string): string;
/// <summary>Joins List using Delim without quoting any of the entries.</summary>
/// <param name="List">Items to join.</param>
/// <param name="Delim">Separator.</param>
/// <returns>The joined list.</returns>
function ConcatList(List: TStrings; const Delim: string): string;
/// <summary>Convenience helper that splits Paths and re-joins it with Separator (no quoting, duplicates removed).</summary>
/// <param name="Paths">Semicolon-separated path list.</param>
/// <param name="Separator">Separator for the result.</param>
/// <returns>The de-duplicated, re-joined list.</returns>
function SplitAndConcatList(const Paths, Separator: string): string;

/// <summary>Returns the BDS Projects directory, honouring the BDSPROJECTSDIR environment variable when set.</summary>
/// <returns>The projects directory; empty when the Documents folder cannot be found.</returns>
function GetBDSProjectsDir: string;
/// <summary>Expands $(NAME) macros (BDS, PLATFORM, CONFIG, BDSPROJECTSDIR, environment variables) inside Path.</summary>
/// <param name="Path">Source path containing $(NAME) tokens.</param>
/// <param name="Project">Optional project used to resolve PLATFORM/CONFIG; defaults to the active project.</param>
/// <returns>Path with every macro replaced; an unknown macro becomes an empty string.</returns>
function ExpandDirMacros(const Path: string; Project: IOTAProject = nil): string;
/// <summary>Expands $(NAME) macros inside Expression using the supplied name/value array.</summary>
/// <param name="Expression">Source expression.</param>
/// <param name="MacroNameValue">Flat array of alternating name/value pairs.</param>
/// <returns>Expression with every listed macro replaced; unlisted macros are left as they are.</returns>
function ExpandMacros(const Expression: string; const MacroNameValue: array of string): string;

type
  /// <summary>
  /// Strongly-typed wrapper around the IDE's internal multicast event objects exposed by coreide
  /// and designide. Provides Add / ForceAdd / Remove operations imported by linker symbol name.
  /// </summary>
  TIDEEvent = class(TObject)
  public
    /// <summary>Adds AHandler to the event subscriber list.</summary>
    /// <param name="AHandler">Event handler (method pointer).</param>
    procedure Add(AHandler: TNotifyEvent);
    /// <summary>Adds AHandler even when the event is currently being raised.</summary>
    /// <param name="AHandler">Event handler (method pointer).</param>
    procedure ForceAdd(AHandler: TNotifyEvent);
    /// <summary>Removes AHandler from the event subscriber list.</summary>
    /// <param name="AHandler">Event handler (method pointer).</param>
    procedure Remove(AHandler: TNotifyEvent);
  end;

/// <summary>Returns the IDE's MainFormShown event object (raised once after the IDE main form first appears).</summary>
/// <returns>The IDE's MainFormShown event object.</returns>
function MainFormShown: TIDEEvent;
/// <summary>Returns the IDE's MainFormCreated event object (raised when the IDE main form is constructed).</summary>
/// <returns>The IDE's MainFormCreated event object.</returns>
function MainFormCreated: TIDEEvent;
/// <summary>Returns the IDE's MainFormDestroyed event object (raised when the IDE main form is destroyed).</summary>
/// <returns>The IDE's MainFormDestroyed event object.</returns>
function MainFormDestroyed: TIDEEvent;

var
  /// <summary>Application directory (folder containing the running executable). Initialised at unit start.</summary>
  AppDir: string;
  /// <summary>True when the host IDE is Delphi 2007 (detected via product version).</summary>
  IsDelphi2007: Boolean = False;

implementation

uses
  System.Win.Registry, IDEHooks;

function ReadGlobalRegOption(const ValueName: string; DefaultValue: Boolean): Boolean;
var
  KeyName: string;
  Reg: TRegistry;
  DataInfo: TRegDataInfo;
begin
  Result := DefaultValue;
  if BorlandIDEServices <> nil then
  begin
    KeyName := (BorlandIDEServices as IOTAServices).GetBaseRegistryKey + '\Globals';
    if KeyName[1] = '\' then
      KeyName := Copy(KeyName, 2, MaxInt);

    Reg := TRegistry.Create;
    try
      Reg.RootKey := HKEY_CURRENT_USER;
      if Reg.OpenKeyReadOnly(KeyName) then
      begin
        if Reg.GetDataInfo(ValueName, DataInfo) then
        begin
          case DataInfo.RegData of
            rdString, rdExpandString:
              Result := StrToIntDef(Reg.ReadString(ValueName), Ord(DefaultValue)) <> 0;
            rdInteger:
              Result := Reg.ReadBool(ValueName);
            rdBinary:
              if ( DataInfo.DataSize > 0 ) then
              begin
                var aData: TBytes;
                SetLength( aData, DataInfo.DataSize );
                Reg.ReadBinaryData( ValueName, aData[0], DataInfo.DataSize );
                Result := aData[0] <> 0;
              end;
          end;
        end;
      end;
    finally
      Reg.Free;
    end;
  end;
end;

function RegReadStringDef(RootKey: HKEY; const Key, ValueName, DefaultValue: string): string;
var
  Reg: TRegistry;
  Info: TRegDataInfo;
begin
  Result := DefaultValue;
  Reg := TRegistry.Create;
  try
    Reg.RootKey := RootKey;
    if Reg.KeyExists(Key) then
      if Reg.OpenKeyReadOnly(Key) then
      begin
        if Reg.GetDataInfo(ValueName, Info) and (Info.DataSize > 0) then
        begin
          case Info.RegData of
            rdString, rdExpandString:
              Result := Reg.ReadString(ValueName);
            rdInteger:
              Result := IntToStr(Reg.ReadInteger(ValueName));
            //rdBinary, rdUnknown:
          end;
        end;
      end;
  finally
    Reg.Free;
  end;
end;

function RegReadBoolDef(RootKey: HKEY; const Key, ValueName: string; DefaultValue: Boolean): Boolean;
var
  Reg: TRegistry;
  Info: TRegDataInfo;
begin
  Result := DefaultValue;
  Reg := TRegistry.Create;
  try
    Reg.RootKey := RootKey;
    if Reg.KeyExists(Key) then
      if Reg.OpenKeyReadOnly(Key) then
      begin
        if Reg.GetDataInfo(ValueName, Info) and (Info.DataSize > 0) then
        begin
          case Info.RegData of
            rdString, rdExpandString:
              Result := Reg.ReadString(ValueName) <> '0';
            rdInteger:
              Result := Reg.ReadBool(ValueName);
            //rdBinary, rdUnknown:
          end;
        end;
      end;
  finally
    Reg.Free;
  end;
end;

/// <summary>Writes a string registry value and reports why it failed.</summary>
/// <param name="RootKey">Registry root.</param>
/// <param name="Key">Key path below RootKey.</param>
/// <param name="ValueName">Name of the value to write.</param>
/// <param name="Value">String data to store.</param>
/// <param name="AError">Receives the reason on failure: TRegistry's own error text ( TRegistry does
/// not set GetLastError ) or the message of the exception WriteString raised.</param>
/// <returns>True when the value was written.</returns>
function WriteRegString( RootKey: HKEY; const Key, ValueName, Value: string; out AError: string ): Boolean;
begin
  Result := False;
  AError := '';
  var oReg := TRegistry.Create;
  try
    oReg.RootKey := RootKey;
    if not oReg.OpenKey( Key, True ) then
    begin
      AError := oReg.LastErrorMsg;
      Exit;
    end;
    try
      oReg.WriteString( ValueName, Value );
      Result := True;
    except
      on E: ERegistryException do
        AError := E.Message;
    end;
  finally
    oReg.Free;
  end;
end;

function TryRegWriteString(RootKey: HKEY; const Key, ValueName, Value: string): Boolean;
begin
  var sError: string;
  Result := WriteRegString( RootKey, Key, ValueName, Value, sError );
end;

procedure RegWriteString(RootKey: HKEY; const Key, ValueName, Value: string);
begin
  // Callers run on IDE paths without a guard, so a failure is logged, never raised.
  var sError: string;
  if not WriteRegString( RootKey, Key, ValueName, Value, sError ) then
    OutputDebugString( PChar( Format( 'DDevExtensions: cannot write registry value "%s" under "%s": %s',
      [ValueName, Key, sError] ) ) );
end;

procedure RegDeleteEntry(RootKey: HKEY; const Key, ValueName: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := RootKey;
    if Reg.KeyExists(Key) then
      if Reg.OpenKey(Key, False) then
        if Reg.ValueExists(ValueName) then
          Reg.DeleteValue(ValueName);
  finally
    Reg.Free;
  end;
end;

function FindForm(const AFormName, AFormClassName: string): TCustomForm;
var
  I: Integer;
begin
  for I := 0 to Screen.FormCount - 1 do
  begin
    Result := Screen.Forms[I];
    if (AFormName = '') or SameText(Result.Name, AFormName) then
      if (AFormClassName = '') or Result.ClassNameIs(AFormClassName) then
        Exit;
  end;
  Result := nil;
end;

function InheritsFromClassName(AObject: TObject; const AClassName: string): Boolean;
var
  Cls: TClass;
begin
  if AObject <> nil then
  begin
    Cls := AObject.ClassType;
    Result := True;
    while Cls <> nil do
    begin
      if Cls.ClassNameIs(AClassName) then
        Exit;
      Cls := Cls.ClassParent;
    end;
  end;
  Result := False;
end;

function GetMethodImplFromDelphiInterface(const Intf: IInterface; VmtOffset: Integer): Pointer;
type
  PEntry = ^TEntry;
  TEntry = packed record
    case Byte of
      // stdcall, safecall, cdecl, pascal:
      0: ( // add dword ptr [esp+$04], -i8
        AddArgShort: LongWord; // $83 $44 $24 $04
        ArgShortOffset: Shortint; // -i8
        ShortJmp: Byte;
        ShortJmpOffset: Integer;
      );
      1: ( // add [esp+$04], -i32
        AddArgLong: LongWord; // $81 $44 $24 $04
        ArgLongOffset: Longint; // -i32
        LongJmp: Byte;
        LongJmpOffset: Integer;
      );
      // register:
      2: ( // add eax, -i8
        RegAddArgShort: Word; // $83 $C0
        RegArgShortOffset: Shortint; // -i8
        RegShortJmp: Byte;
        RegShortJmpOffset: Integer;
      );
      3: ( // add eax, -i32
        RegAddArgLong: Byte; // $05
        RegArgLongOffset: Longint; // -i32
        RegLongJmp: Byte;
        RegLongJmpOffset: Integer;
      );
  end;

var
  P: PEntry;
begin
  Result := nil;
  if Intf <> nil then
  begin
    P := PEntry(Pointer(PByte(Pointer(Intf)^) + VmtOffset)^);
    if P <> nil then
    begin
      // stdcall, safecall, cdecl, pascal:
      if P^.AddArgShort = $04244483 then
        Result := PByte(@P^.ShortJmpOffset) + SizeOf(Integer) + P^.ShortJmpOffset
      else if P^.AddArgLong = $04244481 then
        Result := PByte(@P^.LongJmpOffset) + SizeOf(Integer) + P^.LongJmpOffset

      // register:
      else if P^.RegAddArgShort = $C083 then
        Result := PByte(@P^.RegShortJmpOffset) + SizeOf(Integer) + P^.RegShortJmpOffset
      else if P^.RegAddArgLong = $05 then
        Result := PByte(@P^.RegLongJmpOffset) + SizeOf(Integer) + P^.RegLongJmpOffset
      ;
    end;
  end;
end;

function GetQueryInterfaceImplFromDelphiInterface(const Intf: IInterface): Pointer;
begin
  Result := GetMethodImplFromDelphiInterface(Intf, 0);
end;

const
  /// <summary>The RTL's object-cast interface ID; System.ObjCastGUID is implementation-private.</summary>
  cObjCastGUID: TGUID = '{CEDF24DE-80A4-447D-8C75-EB871DC121FD}';

function DelphiInterfaceToObject(const Intf: IInterface): TObject;
{$IFDEF CPUX86}
//{$IFDEF COMPILER14_UP}
//begin
//  Result := Intf as TObject;    uses QueryInterface which is slow and goes through all supported interfaces before matching with ObjCastGUID
//end;
//{$ELSE}
type
  PEntry = ^TEntry;
  TEntry = packed record
    case Byte of
      // register:
      0: ( // add eax, -i8
        AddEAXShort: Word; // $83 $C0
        ShortOffset: Shortint; // -i8
      );
      1: ( // add eax, -i32
        AddEAXLong: Byte; // $05
        LongOffset: Longint; // -i32
      );
      // stdcall, safecall, cdecl, pascal:
      2: ( // add dword ptr [esp+$04], -i8
        AddArgShort: LongWord; // $83 $44 $24 $04
        ArgShortOffset: Shortint; // -i8
      );
      3: ( // add [esp+$04], -i32
        AddArgLong: LongWord; // $81 $44 $24 $04
        ArgLongOffset: Longint; // -i32
      );
      // abstract class
      4: ( // push ebp; mov ebp, esp
        PushEbp: Byte; // $55
        MovEbpEsp: Word; // $8B $EC
      );
  end;

var
  P: PEntry;
{$ENDIF CPUX86}
begin
  Result := nil;
  if ( Intf = nil ) then
    Exit;

  {$IFDEF CPUX86}
  // Fast path on Win32: decode the x86 interface thunk that adjusts Self.
  P := PEntry(Pointer(Pointer(Intf)^)^);
  if P <> nil then
  begin
    // stdcall, safecall, cdecl, pascal:
    if P^.AddArgShort = $04244483 then
      Result := TObject(PAnsiChar(Intf) + P^.ArgShortOffset)
    else if P^.AddArgLong = $04244481 then
      Result := TObject(PAnsiChar(Intf) + P^.ArgLongOffset)

    // register:
    else if P^.AddEAXShort = $C083 then
      Result := TObject(PAnsiChar(Intf) + P^.ShortOffset)
    else if P^.AddEAXLong = $05 then
      Result := TObject(PAnsiChar(Intf) + P^.LongOffset)

    // abstract class (mostly a C++ class)
    else if (P^.PushEbp = $55) and (p^.MovEbpEsp = $EC8B) then
      Result := TObject(Intf);
  end;
  if ( Result <> nil ) then
    Exit;
  {$ENDIF CPUX86}

  // Every Delphi object answers the RTL cast GUID; this is the only path on Win64, whose
  // interface thunks ( add rcx, ... ) the x86 decoder above does not recognise.
  var oObject: TObject := nil;
  if ( Intf.QueryInterface( cObjCastGUID, oObject ) = S_OK ) then
    Result := oObject;
end;

/// <summary>
/// Tests whether Address points at a Delphi object, by checking that the VMT pointer it starts
/// with points back at itself through <c>vmtSelfPtr</c>.  Full-width pointer arithmetic, so it is
/// correct on Win64 as well as Win32.
/// </summary>
/// <param name="Address">Candidate object address; the caller has checked it is readable.</param>
/// <returns>True when Address looks like a Delphi object.</returns>
function IsObject(Address: Pointer): Boolean;
begin
  var pVmt: Pointer := PPointer( Address )^;
  Result := ( pVmt <> nil ) and ( PPointer( PByte( pVmt ) + vmtSelfPtr )^ = pVmt );
end;

function ClassIsOfClass(AClass: TClass; const AClassName: string): Boolean;
begin
  if AClass <> nil then
    Result := AClass.ClassNameIs(AClassName) or ClassIsOfClass(AClass.ClassParent, AClassName)
  else
    Result := False;
end;

/// <summary>
/// Tests whether the pointer-sized field at Offset inside Obj holds an object whose class (or an
/// ancestor) is named AClassName.  Every pointer is validated before it is dereferenced.
/// </summary>
/// <param name="Obj">Object whose fields are probed.</param>
/// <param name="Offset">Byte offset of the field inside Obj.</param>
/// <param name="AClassName">Class name to look for.</param>
/// <returns>True when the field holds a matching object.</returns>
function FieldHoldsClass( Obj: TObject; Offset: Cardinal; const AClassName: string ): Boolean;
begin
  Result := False;
  var oField := TObject( PPointer( PByte( Obj ) + Offset )^ );
  if ( NativeUInt( oField ) < $00010000 ) or IsBadReadPtr( oField, SizeOf( Pointer ) ) then
    Exit;
  var pVmt: Pointer := PPointer( oField )^;
  if ( pVmt = nil ) or IsBadReadPtr( PByte( pVmt ) + vmtSelfPtr, SizeOf( Pointer ) ) then
    Exit;
  Result := IsObject( oField ) and ClassIsOfClass( oField.ClassType, AClassName );
end;

function FindObjectFieldOffset(Obj: TObject; const AClassName: string; FindLast: Boolean): Cardinal;
begin
  if ( Obj <> nil ) then
  begin
    var iInstSize: Cardinal := Cardinal( Obj.InstanceSize );
    if FindLast then
    begin
      Result := iInstSize - SizeOf( Pointer );
      while ( Result >= SizeOf( Pointer ) ) do // omit the VMT pointer at offset 0
      begin
        if FieldHoldsClass( Obj, Result, AClassName ) then
          Exit;
        Dec( Result, SizeOf( Pointer ) );
      end;
    end
    else
    begin
      Result := SizeOf( Pointer ); // start after the VMT pointer
      while ( Result + SizeOf( Pointer ) <= iInstSize ) do
      begin
        if FieldHoldsClass( Obj, Result, AClassName ) then
          Exit;
        Inc( Result, SizeOf( Pointer ) );
      end;
    end;
  end;
  Result := 0;
end;

function FindObjectField(Obj: TObject; const AClassName: string; FindLast: Boolean): TObject;
begin
  var iOffset := FindObjectFieldOffset( Obj, AClassName, FindLast );
  if ( iOffset = 0 ) then
    raise Exception.CreateFmt( '%s object field not found', [AClassName] );
  Result := TObject( PPointer( PByte( Obj ) + iOffset )^ );
end;

function MakeNotifyEvent(Data, Code: Pointer): TNotifyEvent;
begin
  TMethod(Result).Data := Data;
  TMethod(Result).Code := Code;
end;

function VarToIntDef(const V: Variant; Default: Integer): Integer;
begin
  Result := Default;
  if not VarIsEmpty(V) and not VarIsNull(V) and not (VarIsStr(V) and (VarToStr(V) = '')) then
  begin
    try
      Result := V;
    except
      on EConvertError do
        Result := Default;
      on EVariantInvalidArgError do
        Result := Default;
    end;
  end;
end;

function VarToBoolDef(const V: Variant; Default: Boolean): Boolean;
begin
  Result := Default;
  if not VarIsEmpty(V) and not VarIsNull(V) and not (VarIsStr(V) and (VarToStr(V) = '')) then
  begin
    try
      Result := V;
    except
      on EConvertError do
        Result := Default;
      on EVariantInvalidArgError do
        Result := Default;
    end;
  end;
end;

function VarToStrDef(const V: Variant; const Default: string): string;
begin
  if VarIsEmpty(V) or VarIsNull(V) then
    Result := Default
  else
  begin
    try
      Result := V;
    except
      on EConvertError do
        Result := Default;
      on EVariantInvalidArgError do
        Result := Default;
    end;
  end;
end;

function HashString(const AItem: string): Integer;
begin
  Result := IDEHashLists.HashString( AItem );
end;

{------------------------------------------------------------------------------}

function FastFileExists(const Filename: string): Boolean;
begin
  if Filename <> '' then
    Result := (GetFileAttributes(Pointer(Filename)) and FILE_ATTRIBUTE_DIRECTORY = 0)
  else
    Result := False;
end;

function IncludeTrailingPathDelimiter(const Dir: string): string;
begin
  if (Dir <> '') and not (Dir[Length(Dir)] in ['/', '\']) then
    Result := Dir + PathDelim
  else
    Result := Dir;
end;

function ExcludeTrailingPathDelimiter(const Dir: string): string;
begin
  if (Dir <> '') and (Dir[Length(Dir)] in ['/', '\']) then
    Result := Copy(Dir, 1, Length(Dir) - 1)
  else
    Result := Dir;
  if (Result <> '') and (Result[Length(Result)] = ':') then
    Result  := Result + '\';
end;

function FileAgeFindFile(const Filename: string): Integer;
var
  Handle: THandle;
  FindData: TWin32FindData;
  LocalFileTime: TFileTime;
begin
  Handle := FindFirstFile(Pointer(FileName), FindData);
  if Handle <> INVALID_HANDLE_VALUE then
  begin
    Winapi.Windows.FindClose(Handle);
//    if (FindData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) = 0 then
    begin
      FileTimeToLocalFileTime(FindData.ftLastWriteTime, LocalFileTime);
      if FileTimeToDosDateTime(LocalFileTime, LongRec(Result).Hi, LongRec(Result).Lo) then
        Exit;
    end;
  end;
  Result := -1;
end;

function GetFileSize(const Filename: string): Cardinal;
var
  Handle: THandle;
  FindData: TWin32FindData;
begin
  Handle := FindFirstFile(Pointer(FileName), FindData);
  if Handle <> INVALID_HANDLE_VALUE then
  begin
    Winapi.Windows.FindClose(Handle);
    Result := FindData.nFileSizeLow;
  end
  else
    Result := 0;
end;

function GetTempName(const Base: string): string;
var
  BufSize: Cardinal;
  Dir: string;
  Buffer: array[0..MAX_PATH] of Char;
begin
  BufSize := GetTempPath(0, nil);
  SetLength(Dir, BufSize);
  GetTempPath(BufSize, PChar(Dir));
  Result := PChar(Dir); // truncate at #0
  if GetTempFileName(PChar(Dir), PChar(Base), 0, PChar(@Buffer[0])) <> 0 then
    Result := Buffer
  else
    RaiseLastOSError;
end;

function StartsText(const SubStr, S: string): Boolean;
begin
  Result := AnsiStartsText(SubStr, S);
end;

function EndsText(const SubStr, S: string): Boolean;
begin
  Result := AnsiEndsText(SubStr, S);
end;

procedure StretchBltTransparent(DstDC: HDC; DstX, DstY, DstW, DstH: Integer;
  SrcDC: HDC; SrcX, SrcY, SrcW, SrcH: Integer; Palette: HPALETTE;
  TransparentColor: TColorRef);
var
  Color: TColorRef;
  bmAndBack, bmAndObject, bmAndMem, bmSave: HBITMAP;
  bmBackOld, bmObjectOld, bmMemOld, bmSaveOld: HBITMAP;
  MemDC, BackDC, ObjectDC, SaveDC: HDC;
  palDst, palMem, palSave, palObj: HPALETTE;
begin
  BackDC := CreateCompatibleDC(DstDC);
  ObjectDC := CreateCompatibleDC(DstDC);
  MemDC := CreateCompatibleDC(DstDC);
  SaveDC := CreateCompatibleDC(DstDC);

  bmAndObject := CreateBitmap(SrcW, SrcH, 1, 1, nil);
  bmAndBack := CreateBitmap(SrcW, SrcH, 1, 1, nil);
  bmAndMem := CreateCompatibleBitmap(DstDC, DstW, DstH);
  bmSave := CreateCompatibleBitmap(DstDC, SrcW, SrcH);

  bmBackOld := SelectObject(BackDC, bmAndBack);
  bmObjectOld := SelectObject(ObjectDC, bmAndObject);
  bmMemOld := SelectObject(MemDC, bmAndMem);
  bmSaveOld := SelectObject(SaveDC, bmSave);

  palDst := 0;
  palMem := 0;
  palSave := 0;
  palObj := 0;
  if Palette <> 0 then
  begin
    palDst := SelectPalette(DstDC, Palette, True);
    RealizePalette(DstDC);
    palSave := SelectPalette(SaveDC, Palette, False);
    RealizePalette(SaveDC);
    palObj := SelectPalette(ObjectDC, Palette, False);
    RealizePalette(ObjectDC);
    palMem := SelectPalette(MemDC, Palette, True);
    RealizePalette(MemDC);
  end;

  SetMapMode(SrcDC, GetMapMode(DstDC));
  SetMapMode(SaveDC, GetMapMode(DstDC));

  BitBlt(SaveDC, 0, 0, SrcW, SrcH, SrcDC, SrcX, SrcY, SRCCOPY);

  Color := SetBkColor(SaveDC, TransparentColor);
  BitBlt(ObjectDC, 0, 0, SrcW, SrcH, SaveDC, 0, 0, SRCCOPY);

  SetBkColor(SaveDC, Color);
  BitBlt(BackDC, 0, 0, SrcW, SrcH, ObjectDC, 0, 0, NOTSRCCOPY);
  BitBlt(MemDC, 0, 0, DstW, DstH, DstDC, DstX, DstY, SRCCOPY);
  StretchBlt(MemDC, 0, 0, DstW, DstH, ObjectDC, 0, 0, SrcW, SrcH, SRCAND);
  BitBlt(SaveDC, 0, 0, SrcW, SrcH, BackDC, 0, 0, SRCAND);
  StretchBlt(MemDC, 0, 0, DstW, DstH, SaveDC, 0, 0, SrcW, SrcH, SRCPAINT);
  BitBlt(DstDC, DstX, DstY, DstW, DstH, MemDC, 0, 0, SRCCOPY);

  if Palette <> 0 then
  begin
    SelectPalette(MemDC, palMem, False);
    SelectPalette(ObjectDC, palObj, False);
    SelectPalette(SaveDC, palSave, False);
    SelectPalette(DstDC, palDst, True);
  end;
  DeleteObject(SelectObject(BackDC, bmBackOld));
  DeleteObject(SelectObject(ObjectDC, bmObjectOld));
  DeleteObject(SelectObject(MemDC, bmMemOld));
  DeleteObject(SelectObject(SaveDC, bmSaveOld));

  DeleteDC(MemDC);
  DeleteDC(BackDC);
  DeleteDC(ObjectDC);
  DeleteDC(SaveDC);
end;

function ModuleFromAddr(const Addr: Pointer): HMODULE;
begin
  if Addr = nil then
    Result := 0
  else
    Result := HMODULE(FindHInstance(Addr)); // optimized by IDE Fix Pack
end;

{$IFDEF CPUX64}
/// <summary>Captures return addresses of the current thread's call stack (kernel32).</summary>
/// <param name="FramesToSkip">Number of frames to skip, counted from the caller of this routine.</param>
/// <param name="FramesToCapture">Maximum number of addresses to store.</param>
/// <param name="BackTrace">Receives the return addresses.</param>
/// <param name="BackTraceHash">Optional hash of the trace; nil when not wanted.</param>
/// <returns>Number of addresses stored.</returns>
function CaptureStackBackTrace( FramesToSkip, FramesToCapture: Cardinal; BackTrace: Pointer;
  BackTraceHash: PCardinal ): Word; stdcall; external kernel32 name 'RtlCaptureStackBackTrace';

function Caller(Level: Integer): Pointer;
begin
  Result := nil;
  if ( Level < 0 ) then
    Exit;

  // Frame 0 is the return address into Caller itself; frame 1 lies in Caller's caller, which is
  // what Level 0 returns on Win32.
  var pAddress: Pointer := nil;
  if ( CaptureStackBackTrace( Cardinal( Level ) + 1, 1, @pAddress, nil ) = 1 ) and ( pAddress <> nil ) then
    Result := PByte( pAddress ) - 1;
end;
{$ELSE}
{$STACKFRAMES ON}

type
  PStackFrame = ^TStackFrame;
  TStackFrame = record
    CallersEBP: DWORD;
    CallerAdr: DWORD;
  end;

function GetEBP: Pointer;
asm
  mov eax, ebp
end;

function GetStackTop: DWORD;
asm
  mov eax, fs:[4]
end;

function Caller(Level: Integer): Pointer;
var
  TopOfStack: Cardinal;
  BaseOfStack: Cardinal;
  StackFrame: PStackFrame;
begin
  Result := nil;
  try
    StackFrame := GetEBP;
    BaseOfStack := Cardinal(StackFrame) - 1;
    TopOfStack := GetStackTop;
    while (BaseOfStack < Cardinal(StackFrame)) and (Cardinal(StackFrame) < TopOfStack) do
    begin
      if Level = 0 then
      begin
        Result := Pointer(StackFrame^.CallerAdr - 1);
        Break;
      end;
      StackFrame := PStackFrame(StackFrame^.CallersEBP);
      Dec(Level);
    end;
  except
    Result := nil;
  end;
end;
{$ENDIF CPUX64}

function SupportsEx(const Instance: TObject; const IID: TGUID; out Intf): Boolean;
begin
  Result := Supports(Instance, IID, Intf);
end;

function InArray(const Value: string; const Values: array of string): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to High(Values) do
    if AnsiCompareText(Value, Values[i]) = 0 then
      Exit;
  Result := False;
end;

function DequoteStr(const S: string): string;
begin
  if (Length(S) > 1) and (S[1] = '"') and (S[Length(S)] = '"') then
    Result := Copy(S, 2, Length(S) - 2)
  else
    Result := S;
end;

{$IFDEF COMPILER10}

// Version Info extracting
procedure VersionExtractFileInfo(const FixedInfo: TVSFixedFileInfo; var Major, Minor, Build, Revision: Word);
begin
  Major := HiWord(FixedInfo.dwFileVersionMS);
  Minor := LoWord(FixedInfo.dwFileVersionMS);
  Build := HiWord(FixedInfo.dwFileVersionLS);
  Revision := LoWord(FixedInfo.dwFileVersionLS);
end;

procedure VersionExtractProductInfo(const FixedInfo: TVSFixedFileInfo; var Major, Minor, Build, Revision: Word);
begin
  Major := HiWord(FixedInfo.dwProductVersionMS);
  Minor := LoWord(FixedInfo.dwProductVersionMS);
  Build := HiWord(FixedInfo.dwProductVersionLS);
  Revision := LoWord(FixedInfo.dwProductVersionLS);
end;

// Fixed Version Info routines
function VersionFixedFileInfo(const FileName: string; var FixedInfo: TVSFixedFileInfo): Boolean;
var
  Size, FixInfoLen: DWORD;
  Handle: THandle;
  Buffer: string;
  FixInfoBuf: PVSFixedFileInfo;
begin
  Result := False;
  Size := GetFileVersionInfoSize(PChar(FileName), Handle);
  if Size > 0 then
  begin
    SetLength(Buffer, Size);
    if GetFileVersionInfo(PChar(FileName), Handle, Size, Pointer(Buffer)) and
      VerQueryValue(Pointer(Buffer), '\', Pointer(FixInfoBuf), FixInfoLen) and
      (FixInfoLen = SizeOf(TVSFixedFileInfo)) then
    begin
      Result := True;
      FixedInfo := FixInfoBuf^;
    end;
  end;
end;

function CheckProductVersion(const FileName: string; Major, Minor: Word; ExactMatch: Boolean): Boolean;
var
  Info: TVSFixedFileInfo;
  LMajor, LMinor, LBuild, LRevision: Word;
begin
  if VersionFixedFileInfo(FileName, Info) then
  begin
    VersionExtractProductInfo(Info, LMajor, LMinor, LBuild, LRevision);
    if ExactMatch then
      Result := (LMajor = Major) and (LMinor = Minor)
    else
      Result := (LMajor >= Major) and (LMinor >= Minor);
  end
  else
    Result := False;
end;

{$ENDIF COMPILER10}

function QuoteFilename(const Filename: string): string;
begin
  if (Pos(' ', Filename) > 0) or (Pos('-', Filename) > 0) or (Pos('+', Filename) > 0) then
  begin
    if Filename[1] <> '"' then
      Result := '"' + Filename + '"'
    else
      Result := Filename;
  end
  else
    Result := Filename;
end;

function Dequote(const S: string): string;
begin
  if (Length(S) > 1) and (S[1] = '"') and (S[Length(S)] = '"') then
    Result := Copy(S, 2, Length(S) - 2)
  else
    Result := S;
end;

procedure SplitPaths(List: TStrings; const Paths: string; DeleteDuplicates: Boolean);
var
  Start, i: Integer;
  Dir: string;
begin
  Start := 1;
  for i := 1 to Length(Paths) do
  begin
    if Paths[i] = ';' then
    begin
      Dir := Copy(Paths, Start, i - Start);
      if Dir <> '' then
      begin
        if Dir[1] = '"' then
          Dir := Dequote(Dir);
        if not DeleteDuplicates or (List.IndexOf(Dir) = -1) then
          List.Add(Dir);
      end;
      Start := i + 1;
    end;
  end;
  if Start <= Length(Paths) then
  begin
    Dir := Copy(Paths, Start, MaxInt);
    if Dir <> '' then
    begin
      if Dir[1] = '"' then
        Dir := Dequote(Dir);
      if not DeleteDuplicates or (List.IndexOf(Dir) = -1) then
        List.Add(Dir);
    end;
  end;
end;

function ConcatPaths(List: TStrings; const Delim: string): string;
var
  i: Integer;
begin
  Result := '';
  if List.Count > 0 then
  begin
    Result := QuoteFilename(List[0]);
    for i := 1 to List.Count - 1 do
      Result := Result + Delim + QuoteFilename(List[i]);
  end;
end;

function SplitAndConcatPaths(const Paths, Separator: string): string;
var
  List: TStrings;
begin
  List := TStringList.Create;
  try
    SplitPaths(List, Paths, True);
    Result := ConcatPaths(List, Separator);
  finally
    List.Free;
  end;
end;

function ConcatList(List: TStrings; const Delim: string): string;
var
  i, Len, DelimLen: Integer;
  S: string;
  P: PChar;
begin
  DelimLen := Length(Delim);
  Len := 0;
  if List.Count > 0 then
  begin
    Inc(Len, Length(List[0]));
    for i := 1 to List.Count - 1 do
      Inc(Len, DelimLen + Length(List[i]));
  end;
  SetLength(Result, Len);
  P := Pointer(Result);
  for i := 0 to List.Count - 1 do
  begin
    if (i > 0) and (DelimLen > 0) then
    begin
      Move(Pointer(Delim)^, P^, DelimLen * SizeOf(Char));
      Inc(P, DelimLen);
    end;
    S := List[i];
    Len := Length(S);
    if Len > 0 then
    begin
      Move(Pointer(S)^, P^, Len * SizeOf(Char));
      Inc(P, Len);
    end;
  end;
end;

function SplitAndConcatList(const Paths, Separator: string): string;
var
  List: TStrings;
begin
  List := TStringList.Create;
  try
    SplitPaths(List, Paths, True);
    Result := ConcatList(List, Separator);
  finally
    List.Free;
  end;
end;

{$IFDEF COMPILER9_UP}
var
  GlobalBDSProjectsDir: string;

  {$IFNDEF UNICODE}
  _SHGetSpecialFolderPathA: function(hwndOwner: HWND; lpszPath: PAnsiChar;
    nFolder: Integer; fCreate: BOOL): BOOL; stdcall;
  {$ENDIF UNICODE}

function GetBDSProjectsDir: string;
{$IFDEF COMPILER9}
const
  CIV = '90';
  ProjectDirResId = 64431;
{$ENDIF COMPILER9}
{$IFDEF COMPILER10}
const
  CIV = '100';
  ProjectDirResId = 64719;
{$ENDIF COMPILER10}
var
  {$IFNDEF COMPILER11_UP}
  LocaleName: array[0..4] of Char;
  RootDir: string;
  Filename: string;
  h: HMODULE;
  {$ENDIF ~COMPILER11_UP}
  PersDir: string;
begin
  GlobalBDSProjectsDir := ExcludeTrailingPathDelimiter(GetEnvironmentVariable('BDSPROJECTSDIR'));
  if GlobalBDSProjectsDir = '' then
  begin
    GlobalBDSProjectsDir := 'Borland Studio Projects'; // do not localize
    {$IFNDEF COMPILER11_UP}
    FillChar(LocaleName, SizeOf(LocaleName[0]), 0);
    GetLocaleInfo(GetThreadLocale, LOCALE_SABBREVLANGNAME, LocaleName, SizeOf(LocaleName));
    if LocaleName[0] <> #0 then
    begin
      RootDir := AppDir;
      Filename := RootDir + PathDelim + 'coreide' + CIV + '.';
      if FastFileExists(Filename + LocaleName) then
        Filename := Filename + LocaleName
      else
      begin
        LocaleName[2] := #0;
        if FastFileExists(Filename + LocaleName) then
          Filename := Filename + LocaleName
        else
          Filename := '';
      end;

      if Filename <> '' then
      begin
        h := LoadLibraryEx(PChar(Filename), 0, LOAD_LIBRARY_AS_DATAFILE or DONT_RESOLVE_DLL_REFERENCES);
        if h <> 0 then
        begin
          SetLength(GlobalBDSProjectsDir, 4096);
          SetLength(GlobalBDSProjectsDir, LoadString(h, ProjectDirResId, PChar(GlobalBDSProjectsDir), Length(GlobalBDSProjectsDir) - 1));
          FreeLibrary(h);
        end;
      end;
    end;
    {$ENDIF ~COMPILER11_UP}

    {$IFDEF UNICODE}
    SetLength(PersDir, MAX_PATH);
    if SHGetSpecialFolderPath(0, PChar(PersDir), CSIDL_PERSONAL, False) then
    {$ELSE}
    if not Assigned(_SHGetSpecialFolderPathA) then
      _SHGetSpecialFolderPathA := GetProcAddress(GetModuleHandle('shell32.dll'), PAnsiChar('SHGetSpecialFolderPathA'));
    SetLength(PersDir, MAX_PATH);
    if Assigned(_SHGetSpecialFolderPathA) and
       _SHGetSpecialFolderPathA(0, PChar(PersDir), CSIDL_PERSONAL, False) then
    {$ENDIF UNICODE}
    begin
      SetLength(PersDir, StrLen(PChar(PersDir)));
      GlobalBDSProjectsDir := ExcludeTrailingPathDelimiter(PersDir) + PathDelim + GlobalBDSProjectsDir;
    end
    else
      GlobalBDSProjectsDir := '';
  end;
  Result := GlobalBDSProjectsDir;
end;
{$ELSE}
function GetBDSProjectsDir: string;
begin
  Result := ExtractFilePath(AppDir) + 'Projects';
end;
{$ENDIF COMPILER9_UP}

function ExpandDirMacros(const Path: string; Project: IOTAProject): string;
var
  I: Integer;
  Start, Len: Integer;
  NewS, S: string;
begin
  if Project = nil then
    Project := GetActiveProject;

  Result := Path;
  Len := Length(Result);
  I := 1;
  while I <= Len do
  begin
    if (Result[I] = '$') and (I < Len - 1) and (Result[I + 1] = '(') then
    begin
      Start := I;
      while (I <= Len) and (Result[I] <> ')') do
        Inc(I);
      if I <= Len then
      begin
        S := AnsiUpperCase(Copy(Result, Start + 2, I - Start - 2));

        NewS := GetEnvironmentVariable(S);
        if NewS = '' then
        begin
          if (S = 'BDS') or (S = 'BCB') or (S = 'DELPHI') then
            NewS := ExtractFileDir(AppDir)
          else if S = 'BDSPROJECTSDIR' then
            NewS := GetBDSProjectsDir
          else if S = 'PLATFORM' then
          begin
           {$IF CompilerVersion >= 23.0} // XE2+
           if Project <> nil then
             NewS := Project.CurrentPlatform
           else
             NewS := cWin32Platform;
           {$IFEND}
          end
          else if S = 'CONFIG' then
          begin
            {$IF CompilerVersion >= 23.0} // XE2+
            if Project <> nil then
              NewS := Project.CurrentConfiguration
            else
              NewS := 'Debug';
            {$IFEND}
          end;
          //else if S = 'BDSCOMMONDIR' then
        end;

        Delete(Result, Start, I - Start + 1);
        Insert(NewS, Result, Start);
        Dec(I, Length(S) + 3);
        Inc(I, Length(NewS));
        Len := Length(Result);
      end;
    end;
    Inc(I);
  end;
end;

function ExpandMacros(const Expression: string; const MacroNameValue: array of string): string;
var
  I, K: Integer;
  Start, Len: Integer;
  NewS, S: string;
begin
  Result := Expression;
  Len := Length(Result);
  I := 1;
  while I <= Len do
  begin
    if (Result[I] = '$') and (I < Len - 1) and (Result[I + 1] = '(') then
    begin
      Start := I;
      while (I <= Len) and (Result[I] <> ')') do
        Inc(I);
      if I <= Len then
      begin
        S := AnsiUpperCase(Copy(Result, Start + 2, I - Start - 2));
        NewS := '';
        for K := 0 to Length(MacroNameValue) div 2 - 1 do
        begin
          if SameText(S, MacroNameValue[K * 2]) then
          begin
            NewS := MacroNameValue[K * 2 + 1];

            Delete(Result, Start, I - Start + 1);
            Insert(NewS, Result, Start);
            Dec(I, Length(S) + 3);
            Inc(I, Length(NewS));
            Len := Length(Result);
            Break;
          end;
        end;
      end;
    end;
    Inc(I);
  end;
end;

{ TIDEEvent }

procedure TIDEEvent.Add(AHandler: TNotifyEvent);
  external designide_bpl name '@Events@TEvent@Add$qqrynpqqrp14System@TObject$v' {$IFDEF WIN64} delayed {$ENDIF};
procedure TIDEEvent.ForceAdd(AHandler: TNotifyEvent);
  external designide_bpl name '@Events@TEvent@ForceAdd$qqrynpqqrp14System@TObject$v' {$IFDEF WIN64} delayed {$ENDIF};
procedure TIDEEvent.Remove(AHandler: TNotifyEvent);
  external designide_bpl name '@Events@TEvent@Remove$qqrynpqqrp14System@TObject$v' {$IFDEF WIN64} delayed {$ENDIF};

function MainFormShown: TIDEEvent;
  external coreide_bpl name '@Ideintf@MainFormShown$qqrv' {$IFDEF WIN64} delayed {$ENDIF};
function MainFormCreated: TIDEEvent;
  external coreide_bpl name '@Ideintf@MainFormCreated$qqrv' {$IFDEF WIN64} delayed {$ENDIF};
function MainFormDestroyed: TIDEEvent;
  external coreide_bpl name '@Ideintf@MainFormDestroyed$qqrv' {$IFDEF WIN64} delayed {$ENDIF};

procedure Init;
var
  MainModuleName: string;
begin
  MainModuleName := GetModuleName(0);
  {$IFDEF COMPILER10}
  IsDelphi2007 := CheckProductVersion(MainModuleName, 11, 0, True);
  {$ENDIF COMPILER10}
  AppDir := ExtractFileDir(MainModuleName);
end;

initialization
  Init;

end.
