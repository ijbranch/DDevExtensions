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
  Winapi.Windows, System.SysUtils, InterceptIntf;

/// <summary>
/// Loads <c>CompileInterceptorW.dll</c> on demand and returns the host service interface
/// used to register compiler interceptors.
/// </summary>
/// <returns>
/// The <see cref="ICompileInterceptorServices"/> instance from the loaded DLL; once the DLL has shut its interceptor
/// down (IDE shutdown), a do-nothing stand-in, never nil, so a late unregister cannot fault.
/// </returns>
/// <exception cref="Exception">Raised when <c>CompileInterceptorW.dll</c> cannot be loaded or the export is missing.</exception>
function GetCompileInterceptorServices: ICompileInterceptorServices;
/// <summary>
/// Releases the cached function pointer and unloads the interceptor DLL.  Every interceptor must have been
/// unregistered first, and no interface obtained from the DLL may still be held.
/// </summary>
procedure UnloadCompilerInterceptorServices;

implementation

{function GetCompileInterceptorServices: ICompileInterceptorServices; stdcall;
  external 'CompileInterceptorW.dll' name 'GetCompileInterceptorServices';}

type
  /// <summary>Stand-in services returned after the interceptor DLL has shut down: registers nothing, ignores the rest.</summary>
  TShutDownInterceptorServices = class( TInterfacedObject, ICompileInterceptorServices )
  public
    /// <summary>Registers nothing.</summary>
    /// <param name="Interceptor">Ignored.</param>
    /// <returns>-1 (not registered).</returns>
    function RegisterInterceptor( Interceptor: ICompileInterceptor ): Integer; stdcall;
    /// <summary>Does nothing.</summary>
    /// <param name="Id">Ignored.</param>
    procedure UnregisterInterceptor( Id: Integer ); stdcall;
    /// <summary>Supplies no content.</summary>
    /// <param name="Filename">Ignored.</param>
    /// <returns>nil.</returns>
    function GetFileContent( Filename: PWideChar ): IVirtualStream; stdcall;
  end;

function TShutDownInterceptorServices.RegisterInterceptor( Interceptor: ICompileInterceptor ): Integer;
begin
  Result            := -1;
end;

procedure TShutDownInterceptorServices.UnregisterInterceptor( Id: Integer );
begin
end;

function TShutDownInterceptorServices.GetFileContent( Filename: PWideChar ): IVirtualStream;
begin
  Result            := nil;
end;

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
  if not Assigned( _GetCompileInterceptorServices ) then
  begin
    CompilerInterceptorLib := SafeLoadLibrary( PChar( ExtractFilePath( GetModuleName( HInstance ) ) + InterceptorDllName ) );
    if CompilerInterceptorLib = 0 then
      CompilerInterceptorLib := SafeLoadLibrary( InterceptorDllName ); // search all PATHs
    if CompilerInterceptorLib <> 0 then
      _GetCompileInterceptorServices := GetProcAddress( CompilerInterceptorLib, 'GetCompileInterceptorServices' );
  end;
  if Assigned( _GetCompileInterceptorServices ) then
  begin
    Result          := _GetCompileInterceptorServices( );
    // nil once the DLL has finalised its interceptor: hand back a stand-in that ignores every call
    if Result = nil then
      Result        := TShutDownInterceptorServices.Create;
  end
  else
    raise Exception.CreateFmt( 'Cannot find %s', [ InterceptorDllName ] );
end;

procedure UnloadCompilerInterceptorServices;
begin
  _GetCompileInterceptorServices := nil;
  if CompilerInterceptorLib <> 0 then
  begin
    // Free the handle before forgetting it (the handle was zeroed first, so FreeLibrary(0) unloaded nothing).
    // Safe now that the DLL's finalization puts the compiler's callbacks back before its code goes away.
    FreeLibrary( CompilerInterceptorLib );
    CompilerInterceptorLib := 0;
  end;
end;

end.

