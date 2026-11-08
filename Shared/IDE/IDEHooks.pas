{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit IDEHooks;

/// <summary>
/// Central per-Delphi-version constants and runtime helpers used by every other unit that
/// performs IDE-level patching. Provides BPL/DLL filename mappings (coreide_bpl, designide_bpl,
/// dcc32_dll, ...), mangled RTL/VCL symbol names and runtime DCC-version comparison helpers.
/// </summary>

{$IF CompilerVersion >= 25.0} // XE4+
  {$LEGACYIFEND ON}
{$IFEND}

{.$I jedi\jedi.inc}
{$IFDEF VER130} {$DEFINE COMPILER5} {$ENDIF}  // Delphi 5
{$IFDEF VER140} {$DEFINE COMPILER6} {$ENDIF}  // Delphi 6
{$IFDEF VER150} {$DEFINE COMPILER7} {$ENDIF}  // Delphi 7
{$IFDEF VER170} {$DEFINE COMPILER9} {$ENDIF}  // Delphi 2005
{$IFDEF VER180} {$DEFINE COMPILER10} {$ENDIF} // Delphi 2006
{$IFDEF VER185} {$DEFINE COMPILER11} {$UNDEF COMPILER10} {$ENDIF} // Delphi 2007
{$IFDEF VER200} {$DEFINE COMPILER12} {$ENDIF} // Delphi 2009
// The other versions use the CompilerVersion constant because ErrorInsight can handle it

interface

uses
  Windows;

const
  {$IFDEF EMBT_DEBUG_EDITION}
  /// <summary>Debug-edition override: makes the XE3 ( 24.0 ) names below apply when EMBT_DEBUG_EDITION is defined.</summary>
  CompilerVersion = 24.0;
  {$ENDIF EMBT_DEBUG_EDITION}

{$IFNDEF CONDITIONALEXPRESSIONS}

{$IFDEF COMPILER5}
  /// <summary>File name of the C++Builder IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bcbide_bpl = 'bcbide50.bpl';
  /// <summary>File name of the Delphi IDE personality package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphide_bpl = 'dphide50.bpl';
  /// <summary>File name of the core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreide_bpl = 'coride50.bpl';
  /// <summary>File name of the RTL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  rtl_bpl = 'vcl50.bpl';
  /// <summary>File name of the VCL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vcl_bpl = 'vcl50.bpl';
  /// <summary>File name of the Delphi core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphicoreide_bpl = coreide_bpl;
  /// <summary>File name of the form-designer IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  designide_bpl = 'dsgnide50.bpl';
  /// <summary>File name of the VCL design-time IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vclide_bpl = 'vclide50.bpl';
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '5';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '50';
  /// <summary>File name of the Win32 compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcc32_dll = 'dcc50.dll';
{$ENDIF COMPIELR5}

{$ELSE}

{$IFDEF COMPILER6}
  /// <summary>File name of the C++Builder IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bcbide_bpl = 'bcbide60.bpl';
  /// <summary>File name of the Delphi IDE personality package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphide_bpl = 'delphide60.bpl';
  /// <summary>File name of the core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreide_bpl = 'coreide60.bpl';
  /// <summary>File name of the RTL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  rtl_bpl = 'rtl60.bpl';
  /// <summary>File name of the VCL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vcl_bpl = 'vcl60.bpl';
  /// <summary>File name of the Delphi core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphicoreide_bpl = coreide_bpl;
  /// <summary>File name of the VCL design-time IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vclide_bpl = 'vclide60.bpl';
  /// <summary>File name of the form-designer IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  designide_bpl = 'designide60.bpl';
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '6';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '60';
  /// <summary>File name of the Win32 compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcc32_dll = 'dcc60.dll';
{$ENDIF COMPIELR6}
{$IFDEF COMPILER7}
  /// <summary>File name of the C++Builder IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bcbide_bpl = 'bcbide70.bpl';
  /// <summary>File name of the Delphi IDE personality package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphide_bpl = 'delphide70.bpl';
  /// <summary>File name of the core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreide_bpl = 'coreide70.bpl';
  /// <summary>File name of the RTL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  rtl_bpl = 'rtl70.bpl';
  /// <summary>File name of the VCL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vcl_bpl = 'vcl70.bpl';
  /// <summary>File name of the Delphi core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphicoreide_bpl = coreide_bpl;
  /// <summary>File name of the VCL design-time IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vclide_bpl = 'vclide70.bpl';
  /// <summary>File name of the form-designer IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  designide_bpl = 'designide70.bpl';
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '7';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '70';
  /// <summary>File name of the Win32 compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcc32_dll = 'dcc70.dll';
{$ENDIF COMPIELR7}
{$IFDEF COMPILER9} // Delphi 2005
  /// <summary>File name of the C++Builder IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bcbide_bpl = 'bcbide90.bpl';
  /// <summary>File name of the Delphi IDE personality package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphide_bpl = 'delphide90.bpl';
  /// <summary>File name of the core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreide_bpl = 'coreide90.bpl';
  /// <summary>File name of the RTL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  rtl_bpl = 'rtl90.bpl';
  /// <summary>File name of the VCL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vcl_bpl = 'vcl90.bpl';
  /// <summary>File name of the Delphi core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphicoreide_bpl = 'delphicoreide90.bpl';
  /// <summary>File name of the VCL design-time IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vclide_bpl = 'vclide90.bpl';
  /// <summary>File name of the form-designer IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  designide_bpl = 'designide90.bpl';
  /// <summary>File name of the IDE controls package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  idectrls_bpl = 'idectrls90.bpl';
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '9';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '90';
  /// <summary>File name of the Win32 compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcc32_dll = 'dcc90.dll';
{$ENDIF COMPILER9}
{$IFDEF COMPILER10} // Delphi 2006
  /// <summary>File name of the C++Builder IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bcbide_bpl = 'bcbide100.bpl';
  /// <summary>File name of the Delphi IDE personality package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphide_bpl = 'delphide100.bpl';
  /// <summary>File name of the core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreide_bpl = 'coreide100.bpl';
  /// <summary>File name of the core IDE ( Professional ) package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreproide_bpl = 'coreproide100.bpl';
  /// <summary>File name of the RTL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  rtl_bpl = 'rtl100.bpl';
  /// <summary>File name of the VCL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vcl_bpl = 'vcl100.bpl';
  /// <summary>File name of the Delphi core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphicoreide_bpl = 'delphicoreide100.bpl';
  /// <summary>File name of the VCL design-time IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vclide_bpl = 'vclide100.bpl';
  /// <summary>File name of the form-designer IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  designide_bpl = 'designide100.bpl';
  /// <summary>File name of the debugger IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dbkdebugide_bpl = 'dbkdebugide100.bpl';
  /// <summary>File name of the Win32 debugger IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  win32debugide_bpl = 'win32debugide100.bpl';
  /// <summary>File name of the IDE controls package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  idectrls_bpl = 'idectrls100.bpl';
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '10';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '100';
  /// <summary>File name of the Win32 compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcc32_dll = 'dcc100.dll';
  /// <summary>File name of the C++ compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  comp32x_dll = 'comp32x.dll';
{$ENDIF COMPILER10}
{$IFDEF COMPILER11} // Delphi 2007 has the same BPL version that Delphi 2006 has
  /// <summary>File name of the C++Builder IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bcbide_bpl = 'bcbide100.bpl';
  /// <summary>File name of the Delphi IDE personality package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphide_bpl = 'delphide100.bpl';
  /// <summary>File name of the core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreide_bpl = 'coreide100.bpl';
  /// <summary>File name of the core IDE ( Professional ) package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreproide_bpl = 'coreproide100.bpl';
  /// <summary>File name of the RTL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  rtl_bpl = 'rtl100.bpl';
  /// <summary>File name of the VCL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vcl_bpl = 'vcl100.bpl';
  /// <summary>File name of the Delphi core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphicoreide_bpl = 'delphicoreide100.bpl';
  /// <summary>File name of the VCL design-time IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vclide_bpl = 'vclide100.bpl';
  /// <summary>File name of the form-designer IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  designide_bpl = 'designide100.bpl';
  /// <summary>File name of the debugger IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dbkdebugide_bpl = 'dbkdebugide100.bpl';
  /// <summary>File name of the Win32 debugger IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  win32debugide_bpl = 'win32debugide100.bpl';
  /// <summary>File name of the IDE controls package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  idectrls_bpl = 'idectrls100.bpl';
  /// <summary>File name of the native debugger kernel DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bordbkN_dll = 'bordbk105N.dll';
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '11';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '100'; // the "this is a non-breaking release" problem
  /// <summary>File name of the Win32 compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcc32_dll = 'dcc100.dll'; // compiler has same version number as Delphi 2006
  /// <summary>File name of the C++ compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  comp32x_dll = 'comp32x.dll';
{$ENDIF COMPIELR11}
{$IFDEF COMPILER12} // Delphi 2009
  /// <summary>File name of the C++Builder IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bcbide_bpl = 'bcbide120.bpl';
  /// <summary>File name of the Delphi IDE personality package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphide_bpl = 'delphide120.bpl';
  /// <summary>File name of the core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreide_bpl = 'coreide120.bpl';
  /// <summary>File name of the core IDE ( Professional ) package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreproide_bpl = 'coreproide120.bpl';
  /// <summary>File name of the RTL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  rtl_bpl = 'rtl120.bpl';
  /// <summary>File name of the VCL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vcl_bpl = 'vcl120.bpl';
  /// <summary>File name of the Delphi core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphicoreide_bpl = 'delphicoreide120.bpl';
  /// <summary>File name of the VCL design-time IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vclide_bpl = 'vclide120.bpl';
  /// <summary>File name of the form-designer IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  designide_bpl = 'designide120.bpl';
  /// <summary>File name of the debugger IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dbkdebugide_bpl = 'dbkdebugide120.bpl';
  /// <summary>File name of the Win32 debugger IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  win32debugide_bpl = 'win32debugide120.bpl';
  /// <summary>File name of the IDE controls package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  idectrls_bpl = 'idectrls120.bpl';
  /// <summary>File name of the native debugger kernel DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bordbkN_dll = 'bordbk120N.dll';
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '12';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '120';
  /// <summary>File name of the Win32 compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcc32_dll = 'dcc120.dll';
  /// <summary>File name of the C++ compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  comp32x_dll = 'comp32x.dll';
{$ENDIF COMPIELR12}
{$IF CompilerVersion = 21.0} // Delphi 2010
  /// <summary>File name of the C++Builder IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bcbide_bpl = 'bcbide140.bpl';
  /// <summary>File name of the Delphi IDE personality package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphide_bpl = 'delphide140.bpl';
  /// <summary>File name of the core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreide_bpl = 'coreide140.bpl';
  /// <summary>File name of the core IDE ( Professional ) package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreproide_bpl = 'coreproide140.bpl';
  /// <summary>File name of the RTL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  rtl_bpl = 'rtl140.bpl';
  /// <summary>File name of the VCL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vcl_bpl = 'vcl140.bpl';
  /// <summary>File name of the Delphi core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphicoreide_bpl = 'delphicoreide140.bpl';
  /// <summary>File name of the VCL design-time IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vclide_bpl = 'vclide140.bpl';
  /// <summary>File name of the form-designer IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  designide_bpl = 'designide140.bpl';
  /// <summary>File name of the debugger IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dbkdebugide_bpl = 'dbkdebugide140.bpl';
  /// <summary>File name of the Win32 debugger IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  win32debugide_bpl = 'win32debugide140.bpl';
  /// <summary>File name of the IDE controls package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  idectrls_bpl = 'idectrls140.bpl';
  /// <summary>File name of the native debugger kernel DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bordbkN_dll = 'bordbk140N.dll';
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '14';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '140';
  /// <summary>File name of the Win32 compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcc32_dll = 'dcc140.dll';
  /// <summary>File name of the C++ compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  comp32x_dll = 'comp32x.dll';
{$IFEND}
{$IF CompilerVersion = 22.0} // Delphi XE
  /// <summary>File name of the C++Builder IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bcbide_bpl = 'bcbide150.bpl';
  /// <summary>File name of the Delphi IDE personality package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphide_bpl = 'delphide150.bpl';
  /// <summary>File name of the core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreide_bpl = 'coreide150.bpl';
  /// <summary>File name of the core IDE ( Professional ) package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreproide_bpl = 'coreproide150.bpl';
  /// <summary>File name of the RTL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  rtl_bpl = 'rtl150.bpl';
  /// <summary>File name of the VCL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vcl_bpl = 'vcl150.bpl';
  /// <summary>File name of the Delphi core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphicoreide_bpl = 'delphicoreide150.bpl';
  /// <summary>File name of the VCL design-time IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vclide_bpl = 'vclide150.bpl';
  /// <summary>File name of the form-designer IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  designide_bpl = 'designide150.bpl';
  /// <summary>File name of the debugger IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dbkdebugide_bpl = 'dbkdebugide150.bpl';
  /// <summary>File name of the Win32 debugger IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  win32debugide_bpl = 'win32debugide150.bpl';
  /// <summary>File name of the IDE controls package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  idectrls_bpl = 'idectrls150.bpl';
  /// <summary>File name of the native debugger kernel DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bordbkN_dll = 'bordbk150N.dll';
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '15';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '150';
  /// <summary>File name of the Win32 compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcc32_dll = 'dcc150.dll';
  /// <summary>File name of the C++ compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  comp32x_dll = 'comp32x.dll';
{$IFEND}
{$IF CompilerVersion = 23.0} // Delphi XE2
  /// <summary>File name of the C++Builder IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bcbide_bpl = 'bcbide160.bpl';
  /// <summary>File name of the Delphi IDE personality package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphide_bpl = 'delphide160.bpl';
  /// <summary>File name of the core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreide_bpl = 'coreide160.bpl';
  /// <summary>File name of the core IDE ( Professional ) package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreproide_bpl = 'coreproide160.bpl';
  /// <summary>File name of the RTL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  rtl_bpl = 'rtl160.bpl';
  /// <summary>File name of the VCL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vcl_bpl = 'vcl160.bpl';
  /// <summary>File name of the Delphi core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphicoreide_bpl = 'delphicoreide160.bpl';
  /// <summary>File name of the VCL design-time IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vclide_bpl = 'vclide160.bpl';
  /// <summary>File name of the form-designer IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  designide_bpl = 'designide160.bpl';
  /// <summary>File name of the debugger IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dbkdebugide_bpl = 'dbkdebugide160.bpl';
  /// <summary>File name of the Win32 debugger IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  win32debugide_bpl = 'win32debugide160.bpl';
  /// <summary>File name of the IDE controls package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  idectrls_bpl = 'idectrls160.bpl';
  /// <summary>File name of the native debugger kernel DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bordbkN_dll = 'bordbk160N.dll';
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '16';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '160';
  /// <summary>File name of the Win32 compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcc32_dll = 'dcc32160.dll';
  /// <summary>File name of the Win64 compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcc64_dll = 'dcc64160.dll';
  /// <summary>File name of the macOS 32-bit compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dccosx32_dll = 'dccosx160.dll';
  /// <summary>File name of the C++ compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  comp32x_dll = 'comp32x.dll';
{$IFEND}
{$IF CompilerVersion = 24.0} // Delphi XE3
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '17';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '170';
{$IFEND}
{$IF CompilerVersion = 25.0} // Delphi XE4
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '18';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '180';
{$IFEND}
{$IF CompilerVersion = 26.0} // Delphi XE5
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '19';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '190';
{$IFEND}
{$IF CompilerVersion = 27.0} // Delphi XE6
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '20';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '200';
{$IFEND}
{$IF CompilerVersion = 28.0} // Delphi XE7
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '21';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '210';
{$IFEND}
{$IF CompilerVersion = 29.0} // Delphi XE8
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '22';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '220';
{$IFEND}
{$IF CompilerVersion = 30.0} // Delphi 10 Seattle
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '23';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '230';
{$IFEND}
{$IF CompilerVersion = 31.0} // Delphi 10.1 Berlin
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '24';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '240';
{$IFEND}
{$IF CompilerVersion = 32.0} // Delphi 10.2 Tokyo
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '25';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '250';
{$IFEND}
{$IF CompilerVersion = 33.0} // Delphi 10.3 Rio
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '26';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '260';
{$IFEND}
{$IF CompilerVersion = 34.0} // Delphi 10.4 Sydney
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '27';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '270';
{$IFEND}
{$IF CompilerVersion = 35.0} // Delphi 11.0 Alexandria
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '28';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '280';
{$IFEND}
{$IF CompilerVersion = 36.0} // Delphi 12.0 Athens
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '29';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '290';
{$IFEND}
{$IF CompilerVersion = 37.0} // Delphi 13.0 Florence
  /// <summary>Version number of the targeted Delphi release, as a string ( "37" for Delphi 13 ).</summary>
  DelphiVersion = '37';
  /// <summary>Suffix of the targeted IDE's package file names ( "370" for Delphi 13 ), from which the names below are built.</summary>
  BplVersion = '370';
{$IFEND}

{$IF CompilerVersion >= 24.0} // Delphi XE3+
  /// <summary>File name of the C++Builder IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bcbide_bpl = 'bcbide' + BplVersion + '.bpl';
  /// <summary>File name of the Delphi IDE personality package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphide_bpl = 'delphide' + BplVersion + '.bpl';
  /// <summary>File name of the core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreide_bpl = 'coreide' + BplVersion + '.bpl';
  /// <summary>File name of the core IDE ( Professional ) package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  coreproide_bpl = 'coreproide' + BplVersion + '.bpl';
  /// <summary>File name of the RTL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  rtl_bpl = 'rtl' + BplVersion + '.bpl';
  /// <summary>File name of the VCL runtime package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vcl_bpl = 'vcl' + BplVersion + '.bpl';
  /// <summary>File name of the Delphi core IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  delphicoreide_bpl = 'delphicoreide' + BplVersion + '.bpl';
  /// <summary>File name of the VCL design-time IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vclide_bpl = 'vclide' + BplVersion + '.bpl';
  /// <summary>File name of the form-designer IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  designide_bpl = 'designide' + BplVersion + '.bpl';
  /// <summary>File name of the debugger IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dbkdebugide_bpl = 'dbkdebugide' + BplVersion + '.bpl';
  /// <summary>File name of the Win32 debugger IDE package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  win32debugide_bpl = 'win32debugide' + BplVersion + '.bpl';
  /// <summary>File name of the IDE controls package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  idectrls_bpl = 'idectrls' + BplVersion + '.bpl';
  /// <summary>File name of the native debugger kernel DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  bordbkN_dll = 'bordbk' + BplVersion + 'N.dll';
  /// <summary>File name of the Win32 compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcc32_dll = 'dcc32' + BplVersion + '.dll';
  /// <summary>File name of the Win64 compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcc64_dll = 'dcc64' + BplVersion + '.dll';
  /// <summary>File name of the macOS 32-bit compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dccosx32_dll = 'dccosx' + BplVersion + '.dll';
  /// <summary>File name of the C++ compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  comp32x_dll = 'comp32x.dll';
  /// <summary>File name of the Clang-based C++ compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  compclang_dll = 'compclang.dll';

  /// <summary>File name of the debugger visualiser service package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  visualizationserviceside_bpl = 'VisualizationServiceIDE' + BplVersion + '.bpl';
  /// <summary>File name of the LiveBindings design-time package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dclbindcomp_bpl = 'dclbindcomp' + BplVersion + '.bpl';
{$IFEND}

  /// <summary>File name of the debugger IDE ( Professional ) package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dbkdebugproide_bpl = 'dbkdebugproide' + BplVersion + '.bpl';
  /// <summary>File name of the VCL form designer package for the targeted IDE version, used to locate the module and import its symbols.</summary>
  vcldesigner_bpl = 'vcldesigner' + BplVersion + '.bpl';
  /// <summary>File name of the IDE code-editor DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  boreditu_dll = 'boreditu.dll';

  /// <summary>File name of the iOS simulator compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dccios32_dll = 'dccios32' + BplVersion + '.dll';
  /// <summary>File name of the iOS ARM compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcciosarm_dll = 'dcciosarm' + BplVersion + '.dll';
{$IF CompilerVersion >= 26.0} // XE5+
  /// <summary>File name of the Android ARM compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dccaarm_dll = 'dccaarm' + BplVersion + '.dll';
{$IFEND}
{$IF CompilerVersion >= 29.0} // XE8+
  /// <summary>File name of the iOS 64-bit compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dccios64_dll = 'dccios64' + BplVersion + '.dll';
{$IFEND}
{$IF CompilerVersion >= 33.0} // 10.3 Rio+
  /// <summary>File name of the Linux 32-bit compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcclinux32_dll = 'dcclinux32' + BplVersion + '.dll';
  /// <summary>File name of the Linux 64-bit compiler DLL for the targeted IDE version, used to locate the module and import its symbols.</summary>
  dcclinux64_dll = 'dcclinux64' + BplVersion + '.dll';
{$IFEND}

{$IF defined(DCC64)}
  /// <summary>The compiler DLL GetDccHandle loads: the Win64 one when DCC64 is defined, the Android one when DCCAARM is, otherwise the Win32 one.</summary>
  dcc_dll = dcc64_dll;
  /// <summary>Pointer size, in bytes, of the code the compiler named by dcc_dll generates.</summary>
  DccPointerSize = 8;
{$ELSEIF defined(DCCAARM)}
  /// <summary>The compiler DLL GetDccHandle loads: the Win64 one when DCC64 is defined, the Android one when DCCAARM is, otherwise the Win32 one.</summary>
  dcc_dll = dccaarm_dll;
  /// <summary>Pointer size, in bytes, of the code the compiler named by dcc_dll generates.</summary>
  DccPointerSize = 4;
{$ELSE}
  /// <summary>The compiler DLL GetDccHandle loads: the Win64 one when DCC64 is defined, the Android one when DCCAARM is, otherwise the Win32 one.</summary>
  dcc_dll = dcc32_dll;
  /// <summary>Pointer size, in bytes, of the code the compiler named by dcc_dll generates.</summary>
  DccPointerSize = 4;
{$IFEND}


{$IF CompilerVersion >= 23.0} // XE2+
  /// <summary>Mangled name prefix of the SysUtils unit, used to build the symbol names imported from the IDE packages.</summary>
  Unit_System_SysUtils = '@System@Sysutils';
  /// <summary>Mangled name of TStream, used to build imported symbol names.</summary>
  System_Classes_TStream = '22System@Classes@TStream';
  /// <summary>Mangled name of TStrings, used to build imported symbol names.</summary>
  System_Classes_TStrings = '23System@Classes@TStrings';
  /// <summary>Mangled name of TList, used to build imported symbol names.</summary>
  System_Classes_TList = '20System@Classes@TList';
  /// <summary>Mangled name of TListNotification, used to build imported symbol names.</summary>
  System_Classes_TListNotification = '32System@Classes@TListNotification';
  /// <summary>Mangled name of TCustomIniFile, used to build imported symbol names.</summary>
  System_Inifiles_TCustomIniFile = '30System@Inifiles@TCustomIniFile';
{$ELSE}
  /// <summary>Mangled name prefix of the SysUtils unit, used to build the symbol names imported from the IDE packages.</summary>
  Unit_System_SysUtils = '@Sysutils';
  /// <summary>Mangled name of TStream, used to build imported symbol names.</summary>
  System_Classes_TStream = '15Classes@TStream';
  /// <summary>Mangled name of TStrings, used to build imported symbol names.</summary>
  System_Classes_TStrings = '16Classes@TStrings';
  /// <summary>Mangled name of TList, used to build imported symbol names.</summary>
  System_Classes_TList = '13Classes@TList';
  /// <summary>Mangled name of TListNotification, used to build imported symbol names.</summary>
  System_Classes_TListNotification = '25Classes@TListNotification';
  /// <summary>Mangled name of TCustomIniFile, used to build imported symbol names.</summary>
  System_Inifiles_TCustomIniFile = '23Inifiles@TCustomIniFile';
{$IFEND}

{$IFDEF UNICODE}
  /// <summary>Mangled name of the default string type, used to build imported symbol names.</summary>
  System_String = '20System@UnicodeString';
  /// <summary>Mangled name of the Unicode string type, used to build imported symbol names.</summary>
  System_UnicodeString = System_String;
{$ELSE}
  /// <summary>Mangled name of the default string type, used to build imported symbol names.</summary>
  System_String = '17System@AnsiString';
  /// <summary>Mangled name of the Unicode string type, used to build imported symbol names.</summary>
  System_UnicodeString = '17System@WideString';
{$ENDIF UNICODE}

{$IF CompilerVersion >= 24.0} // XE3+
  /// <summary>Fragment of mangled parameter lists whose letters swapped order in XE3 ( "xp" from XE3, "px" before ).</summary>
  _xp_ = 'xp';
{$ELSE}
  /// <summary>Fragment of mangled parameter lists whose letters swapped order in XE3 ( "xp" from XE3, "px" before ).</summary>
  _xp_ = 'px';
{$IFEND}

{$ENDIF ~CONDITIONALEXPRESSIONS}

/// <summary>Returns (and lazily loads) the module handle of the active dcc compiler DLL.</summary>
/// <returns>HMODULE for dcc32/dcc64/etc. depending on the build platform.</returns>
function GetDccHandle: HMODULE;
/// <summary>Wrapper around GetProcAddress that asserts the symbol exists when running under a debugger.</summary>
/// <param name="Handle">Module handle.</param>
/// <param name="Name">Mangled symbol name.</param>
/// <returns>Address of the resolved symbol, or nil on release builds.</returns>
function DbgStrictGetProcAddress(Handle: THandle; Name: PAnsiChar): Pointer;

const
  /// <summary>Packed Int64 representing Delphi 10.2 Tokyo RTM (major.minor.release.build).</summary>
  COMPILER_VERSION_10_2_RTM = (Int64(25) shl 48) or (Int64(0) shl 32) or (26309 shl 16) or (314);
  /// <summary>Packed Int64 representing Delphi 10.2 Tokyo Update 1.</summary>
  COMPILER_VERSION_10_2_UP1 = (Int64(25) shl 48) or (Int64(0) shl 32) or (27659 shl 16) or (1188);

/// <summary>True when the running DCC compiler exactly matches AVersion (build optionally ignored).</summary>
/// <param name="AVersion">Packed Int64 produced like COMPILER_VERSION_10_2_RTM.</param>
/// <param name="AIgnoreBuild">When True, only major/minor/release are compared.</param>
/// <returns>True when the running compiler's version equals AVersion.</returns>
function SameCompilerVersion(AVersion: Int64; AIgnoreBuild: Boolean = True): Boolean;
/// <summary>True when the running DCC compiler is at or above AVersion.</summary>
/// <param name="AVersion">Minimum required packed version.</param>
/// <param name="AIgnoreBuild">When True, only major/minor/release are compared.</param>
/// <returns>True when the running compiler's version is AVersion or later.</returns>
function CheckCompilerVersion(AVersion: Int64; AIgnoreBuild: Boolean = True): Boolean; overload;
/// <summary>Convenience overload that builds the version Int64 from individual components.</summary>
/// <param name="AMajor">Major version.</param>
/// <param name="AMinor">Minor version.</param>
/// <param name="ARelease">Release number, or -1 to ignore.</param>
/// <param name="ABuild">Build number, or -1 to ignore.</param>
/// <returns>True when the running compiler's version is the given version or later.</returns>
function CheckCompilerVersion(AMajor, AMinor, ARelease: Integer; ABuild: Integer = -1): Boolean; overload;

implementation

var
  LibDcc: HMODULE;

function GetDccHandle: HMODULE;
begin
  if LibDcc = 0 then
  {$IFDEF CMD_COMPILER}
    LibDcc := GetModuleHandle(nil);
  {$ELSE}
    LibDcc := LoadLibrary(dcc_dll);
  {$ENDIF CMD_COMPILER}
  Result := LibDcc;
end;

function DbgStrictGetProcAddress(Handle: THandle; Name: PAnsiChar): Pointer;
{$IFDEF DEBUG}
var
  FileName: array[0..MAX_PATH] of Char;
{$ENDIF DEBUG}
begin
  Result := GetProcAddress(Handle, Name);
  {$IFDEF DEBUG}
  {$WARNINGS OFF}
  if (Result = nil) and (DebugHook <> 0) then
  {$WARNINGS ON}
  begin
    FileName[GetModuleFileName(Handle, FileName, Length(FileName))] := #0;
    Assert(False, 'External Symbol "' + string(AnsiString(Name)) + '" not found in "' + FileName + '"');
  end;
  {$ENDIF DEBUG}
end;

type
  TDCCVersion = packed record
    case Integer of
      0: (Build, Release, Minor, Major: Word);
      1: (Value: UInt64);
      2: (LS, MS: Cardinal);
  end;

var
  DCCVersion: TDCCVersion;
  DCCVersionInitialized: Boolean = False;

procedure InitDCCVersion;
var
  FileName: array[0..MAX_PATH] of Char;
  H: DWORD;
  Size: DWORD;
  Version: PVSFixedFileInfo;
  Buffer: array of Byte;
begin
  DCCVersionInitialized := True;
  DCCVersion.Major := Trunc(CompilerVersion);
  DCCVersion.Minor := Trunc(Frac(CompilerVersion) * 10);
  DCCVersion.Release := 0;
  DCCVersion.Build := 0;

  GetModuleFileName(GetDccHandle, FileName, Length(FileName));

  Size := GetFileVersionInfoSize(FileName, H);
  if Size <> 0 then
  begin
    SetLength(Buffer, Size);
    if GetFileVersionInfo(FileName, H, Size, @Buffer[0]) then
    begin
      Size := SizeOf(Version);
      if VerQueryValue(@Buffer[0], '\', Pointer(Version), Size) then
      begin
        DCCVersion.MS := Version.dwFileVersionMS;
        DCCVersion.LS := Version.dwFileVersionLS;
      end;
    end;
  end;
end;

function SameCompilerVersion(AVersion: Int64; AIgnoreBuild: Boolean = True): Boolean;
var
  V, DCCV: TDCCVersion;
begin
  if not DCCVersionInitialized then
    InitDCCVersion;

  DCCV.Major := DCCVersion.Major;
  DCCV.Minor := DCCVersion.Minor;
  DCCV.Release := DCCVersion.Release;
  DCCV.Build := 0;

  V.Value := AVersion;
  if AIgnoreBuild then
    V.Build := 0
  else
    DCCV.Build := DCCVersion.Build;

  Result := V.Value = DCCV.Value;
end;

function CheckCompilerVersion(AVersion: Int64; AIgnoreBuild: Boolean = True): Boolean;
var
  V, DCCV: TDCCVersion;
begin
  if not DCCVersionInitialized then
    InitDCCVersion;

  DCCV.Major := DCCVersion.Major;
  DCCV.Minor := DCCVersion.Minor;
  DCCV.Release := DCCVersion.Release;
  DCCV.Build := 0;

  V.Value := AVersion;
  if AIgnoreBuild then
    V.Build := 0
  else
    DCCV.Build := DCCVersion.Build;

  Result := V.Value <= DCCV.Value;
end;

function CheckCompilerVersion(AMajor, AMinor, ARelease: Integer; ABuild: Integer = -1): Boolean;
var
  V, DCCV: TDCCVersion;
begin
  if not DCCVersionInitialized then
    InitDCCVersion;

  DCCV.Major := DCCVersion.Major;
  DCCV.Minor := DCCVersion.Minor;
  DCCV.Release := 0;
  DCCV.Build := 0;

  V.Major := AMajor;
  V.Minor := AMinor;
  V.Release := 0;
  V.Build := 0;

  if ARelease <> -1 then
  begin
    DCCV.Release := DCCVersion.Release;
    V.Release := ARelease;
    if ABuild <> -1 then
    begin
      DCCV.Build := DCCVersion.Build;
      V.Build := ABuild;
    end;
  end;

  Result := V.Value <= DCCV.Value;
end;

end.
