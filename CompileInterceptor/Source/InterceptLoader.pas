{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2009 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit InterceptLoader;

/// <summary>
/// Lazy loader for <c>CompileInterceptorW.dll</c>. Resolves the
/// <c>GetCompileInterceptorServices</c> export on first use so that DDevExtensions
/// can degrade gracefully when the interceptor DLL is missing.
/// </summary>

interface

uses
  Windows, SysUtils, InterceptIntf;

/// <summary>
/// Loads <c>CompileInterceptorW.dll</c> on demand and returns the host service interface
/// used to register compiler interceptors.
/// </summary>
/// <returns>The <see cref="ICompileInterceptorServices"/> instance from the loaded DLL.</returns>
/// <exception cref="Exception">Raised when <c>CompileInterceptorW.dll</c> cannot be loaded or the export is missing.</exception>
function GetCompileInterceptorServices: ICompileInterceptorServices;
/// <summary>Releases the cached function pointer and unloads the interceptor DLL.</summary>
procedure UnloadCompilerInterceptorServices;

implementation

{function GetCompileInterceptorServices: ICompileInterceptorServices; stdcall;
  external 'CompileInterceptorW.dll' name 'GetCompileInterceptorServices';}

var
  _GetCompileInterceptorServices: function: ICompileInterceptorServices; stdcall;
  CompilerInterceptorLib: THandle;

function GetCompileInterceptorServices: ICompileInterceptorServices;
const
  {$IFDEF WIN64}
  InterceptorDllName = 'CompileInterceptorWx64.dll';
  {$ELSE}
  InterceptorDllName = 'CompileInterceptorW.dll';
  {$ENDIF}
begin
  if not Assigned(_GetCompileInterceptorServices) then
  begin
    CompilerInterceptorLib := SafeLoadLibrary(PChar(ExtractFilePath(GetModuleName(HInstance)) + InterceptorDllName));
    if CompilerInterceptorLib = 0 then
      CompilerInterceptorLib := SafeLoadLibrary(InterceptorDllName); // search all PATHs
    if CompilerInterceptorLib <> 0 then
      _GetCompileInterceptorServices := GetProcAddress(CompilerInterceptorLib, 'GetCompileInterceptorServices');
  end;
  if Assigned(_GetCompileInterceptorServices) then
    Result := _GetCompileInterceptorServices()
  else
    raise Exception.CreateFmt('Cannot find %s', [InterceptorDllName]);
end;

procedure UnloadCompilerInterceptorServices;
begin
  _GetCompileInterceptorServices := nil;
  if CompilerInterceptorLib <> 0 then
  begin
    CompilerInterceptorLib := 0;
    FreeLibrary(CompilerInterceptorLib);
  end;
end;


end.
