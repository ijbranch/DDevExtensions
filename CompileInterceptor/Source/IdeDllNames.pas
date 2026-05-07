{******************************************************************************}
{*                                                                            *}
{* CompileInterceptor IDE Plugin                                              *}
{*                                                                            *}
{* (C) 2006-2013 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit IdeDllNames;

/// <summary>
/// Detects the running Delphi/RAD Studio IDE version and exposes the version-specific
/// names of the IDE's core BPL packages (coreide, bcbide, rtl, vcl, delphicoreide,
/// designide). The unit probes loaded modules at startup to identify which IDE host
/// is in process, so the rest of CompileInterceptor can resolve the correct exports.
/// </summary>

interface

uses
  Windows, SysUtils;

/// <summary>Highest IDE version (e.g. 370 = RAD Studio 13 / 37.0) that this build is known to support.</summary>
/// <remarks>Adjust ToolsAPIIntf.pas if increasing this value.</remarks>
const
  LastSupportedIDEVersion = 370; // adjust ToolsAPIIntf.pas if necessary

var
  /// <summary>Resolved name of the C++Builder IDE BPL (e.g. <c>bcbide370.bpl</c>) for the running IDE.</summary>
  bcbide_bpl: PChar;
  /// <summary>Resolved name of the IDE core BPL (e.g. <c>coreide370.bpl</c>) for the running IDE.</summary>
  coreide_bpl: PChar;
  /// <summary>Resolved name of the IDE RTL BPL for the running IDE.</summary>
  rtl_bpl: PChar;
  /// <summary>Resolved name of the IDE VCL BPL for the running IDE.</summary>
  vcl_bpl: PChar;
  /// <summary>Resolved name of the Delphi compiler core BPL (e.g. <c>delphicoreide370.bpl</c>) for the running IDE.</summary>
  delphicoreide_bpl: PChar;
  /// <summary>Resolved name of the Design IDE BPL (e.g. <c>designide370.bpl</c>) for the running IDE.</summary>
  designide_bpl: PChar;
  /// <summary>Detected Delphi version as a string (e.g. <c>"37"</c>, <c>"5"</c>, <c>"7"</c>).</summary>
  DelphiVersion: string;
  /// <summary>Detected Delphi version as an integer (e.g. 37 for Delphi 13 / RAD Studio 13).</summary>
  DelphiVer: Integer;

const
  /// <summary>Delphi 5 C++Builder IDE BPL filename.</summary>
  bcbide5_bpl = 'bcbide50.bpl';
  /// <summary>Delphi 5 IDE core BPL filename.</summary>
  coreide5_bpl = 'coride50.bpl';
  /// <summary>Delphi 5 RTL BPL filename.</summary>
  rtl5_bpl = 'vcl50.bpl';
  /// <summary>Delphi 5 VCL BPL filename.</summary>
  vcl5_bpl = 'vcl50.bpl';
  /// <summary>Delphi 5 Pascal compiler core BPL filename (aliased to coreide5).</summary>
  delphicoreide5_bpl = coreide5_bpl;
  /// <summary>Delphi 5 Design IDE BPL filename.</summary>
  designide5_bpl = 'dsnide50.bpl';

  /// <summary>Delphi 6 C++Builder IDE BPL filename.</summary>
  bcbide6_bpl = 'bcbide60.bpl';
  /// <summary>Delphi 6 IDE core BPL filename.</summary>
  coreide6_bpl = 'coreide60.bpl';
  /// <summary>Delphi 6 RTL BPL filename.</summary>
  rtl6_bpl = 'rtl60.bpl';
  /// <summary>Delphi 6 VCL BPL filename.</summary>
  vcl6_bpl = 'vcl60.bpl';
  /// <summary>Delphi 6 Pascal compiler core BPL filename (aliased to coreide6).</summary>
  delphicoreide6_bpl = coreide6_bpl;
  /// <summary>Delphi 6 Design IDE BPL filename.</summary>
  designide6_bpl = 'designide60.bpl';

  /// <summary>Delphi 7 C++Builder IDE BPL filename.</summary>
  bcbide7_bpl = 'bcbide70.bpl';
  /// <summary>Delphi 7 IDE core BPL filename.</summary>
  coreide7_bpl = 'coreide70.bpl';
  /// <summary>Delphi 7 RTL BPL filename.</summary>
  rtl7_bpl = 'rtl70.bpl';
  /// <summary>Delphi 7 VCL BPL filename.</summary>
  vcl7_bpl = 'vcl70.bpl';
  /// <summary>Delphi 7 Pascal compiler core BPL filename (aliased to coreide7).</summary>
  delphicoreide7_bpl = coreide7_bpl;
  /// <summary>Delphi 7 Design IDE BPL filename.</summary>
  designide7_bpl = 'designide70.bpl';

  // Galileo IDE:
  /// <summary>Base C++Builder IDE BPL name (Galileo IDE, Delphi 9+); a version suffix is appended at runtime.</summary>
  bcbide_base_bpl = 'bcbide.bpl';
  /// <summary>Base IDE core BPL name (Galileo IDE, Delphi 9+); a version suffix is appended at runtime.</summary>
  coreide_base_bpl = 'coreide.bpl';
  /// <summary>Base RTL BPL name (Galileo IDE); a version suffix is appended at runtime.</summary>
  rtl_base_bpl = 'rtl.bpl';
  /// <summary>Base VCL BPL name (Galileo IDE); a version suffix is appended at runtime.</summary>
  vcl_base_bpl = 'vcl.bpl';
  /// <summary>Base Pascal compiler core BPL name (Galileo IDE); a version suffix is appended at runtime.</summary>
  delphicoreide_base_bpl = 'delphicoreide.bpl';
  /// <summary>Base VCL IDE designer BPL name (Galileo IDE); a version suffix is appended at runtime.</summary>
  vclide_base_bpl = 'vclide.bpl';
  /// <summary>Base Design IDE BPL name (Galileo IDE); a version suffix is appended at runtime.</summary>
  designide_base_bpl = 'designide.bpl';

implementation

var
  StrMemAllocated: Boolean = False;

procedure MakeVersionDll(var Name: PChar; const DllName, VersionStr: string);
begin
  if Name <> nil then
    StrDispose(Name);
  Name := StrNew(PChar(ChangeFileExt(DllName, VersionStr + ExtractFileExt(DllName))));
end;

procedure FreeStrMem;
begin
  StrDispose(coreide_bpl);
  StrDispose(bcbide_bpl);
  StrDispose(rtl_bpl);
  StrDispose(vcl_bpl);
  StrDispose(delphicoreide_bpl);
  StrDispose(designide_bpl);
  StrMemAllocated := False;
end;

function InitVersion: Boolean;
var
  Version: Integer;
  VersionStr: string;
begin
  Version := 90;
  while Version <= LastSupportedIDEVersion do
  begin
    VersionStr := IntToStr(Version);
    MakeVersionDll(coreide_bpl, coreide_base_bpl, VersionStr);
    if GetModuleHandle(coreide_bpl) <> 0 then
    begin
      MakeVersionDll(bcbide_bpl, bcbide_base_bpl, VersionStr);
      MakeVersionDll(rtl_bpl, rtl_base_bpl, VersionStr);
      MakeVersionDll(vcl_bpl, vcl_base_bpl, VersionStr);
      MakeVersionDll(delphicoreide_bpl, delphicoreide_base_bpl, VersionStr);
      MakeVersionDll(designide_bpl, designide_base_bpl, VersionStr);

      DelphiVer := Version div 10;
      DelphiVersion := IntToStr(DelphiVer);

      StrMemAllocated := True;
      Result := True;
      Exit;
    end;
    Inc(Version, 10);
  end;
  StrDispose(coreide_bpl);
  coreide_bpl := nil;
  Result := False;
end;

initialization
  if not InitVersion then
  begin
    if GetModuleHandle(coreide7_bpl) <> 0 then
    begin
      bcbide_bpl := bcbide7_bpl;
      coreide_bpl := coreide7_bpl;
      rtl_bpl := rtl7_bpl;
      vcl_bpl := vcl7_bpl;
      delphicoreide_bpl := delphicoreide7_bpl;
      designide_bpl := designide7_bpl;
      DelphiVersion := '7';
      DelphiVer := 7
    end
    else
    if GetModuleHandle(coreide6_bpl) <> 0 then
    begin
      bcbide_bpl := bcbide6_bpl;
      coreide_bpl := coreide6_bpl;
      rtl_bpl := rtl6_bpl;
      vcl_bpl := vcl6_bpl;
      delphicoreide_bpl := delphicoreide6_bpl;
      designide_bpl := designide6_bpl;
      DelphiVersion := '6';
      DelphiVer := 6
    end
    else
    if GetModuleHandle(coreide5_bpl) <> 0 then
    begin
      bcbide_bpl := bcbide5_bpl;
      coreide_bpl := coreide5_bpl;
      rtl_bpl := rtl5_bpl;
      vcl_bpl := vcl5_bpl;
      delphicoreide_bpl := delphicoreide5_bpl;
      designide_bpl := designide5_bpl;
      DelphiVersion := '5';
      DelphiVer := 5
    end
    else
      MessageBox(0, 'No compatible Delphi version loaded', 'CompileInterceptor', MB_OK or MB_ICONERROR);
  end;

finalization
  if StrMemAllocated then
    FreeStrMem;

end.

