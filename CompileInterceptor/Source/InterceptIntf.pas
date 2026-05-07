{******************************************************************************}
{*                                                                            *}
{* CompileInterceptor IDE Plugin                                              *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}
{$A+,B-,C+,D+,E-,F-,G+,H+,I+,J-,K-,L+,M-,N-,O+,P+,Q-,R-,S-,T-,U-,V+,W-,X+,Y+,Z1}

unit InterceptIntf;

/// <summary>
/// Public interfaces and option flags for the CompileInterceptor plug-in API. Plug-ins
/// implement <see cref="ICompileInterceptor"/> (or <see cref="ICompileInterceptor20"/>)
/// and register with <see cref="ICompileInterceptorServices"/> to participate in the
/// Delphi compiler's file I/O, message handling, and pre-compile project hooks.
/// </summary>

{$IFDEF UNICODE}
  {$STRINGCHECKS OFF}
{$ENDIF UNICODE}

interface

type
  /// <summary>Bitmask of <c>CIO_*</c> flags advertising which interceptor methods a plug-in implements.</summary>
  TCompileInterceptOptions = type Cardinal;

const
  /// <summary>Interceptor supports the <c>AlterFile()</c> method.</summary>
  CIO_ALTERFILES       = $0001;  // The interceptor supports the AlterFile() method
  /// <summary>Interceptor supports the <c>GetVirtualFile()</c> / <c>OpenVirtualFile()</c> methods.</summary>
  CIO_VIRTUALFILES     = $0002;  // The interceptor supports the VirtrualFile() method
  /// <summary>Interceptor supports the <c>InspectFilename()</c> method.</summary>
  CIO_INSPECTFILENAMES = $0004;  // The interceptor supports the InspectFilename() method
  /// <summary>Interceptor supports the <c>AlterMessage()</c> method.</summary>
  CIO_ALTERMESSAGES    = $0008;  // The interceptor supports the AlterMessage() method
  /// <summary>Interceptor supports the <c>CompileProject()</c> method.</summary>
  CIO_COMPILEPROJECTS  = $0010;  // The interceptor supports the CompileProject() method
  // Version 2.0
  /// <summary>Interceptor supports the <c>CreateVirtualFile()</c> method (interceptor 2.0).</summary>
  CIO_VIRTUALOUTFILES  = $0020;  // The interceptor supports the CreateVirtualFile() method
  /// <summary>Interceptor supports the <c>FileNameDate()</c> method (interceptor 2.0).</summary>
  CIO_FILENAMEDATES    = $0040;  // The interceptor supports the FileNameDate() method

type
  /// <summary>Compiler message severity classification used by <c>BMessage</c> / <c>MultiLineMessage</c>.</summary>
  TMsgKind = (mkHint, mkWarning, mkError, mkFatal, mkInfo);

  /// <summary>Pointer to a UTF-8 encoded null-terminated character buffer.</summary>
  PUtf8Char = PAnsiChar;

  /// <summary>Distinguishes whether <see cref="ICompileInterceptor.InspectFilename"/> is being notified about an open or a create operation.</summary>
  TInspectFileMode = (ifmOpen, ifmCreate);

  /// <summary>
  /// COM-friendly wrapper for a Unicode string passed to/from interceptor plug-ins.
  /// Allows the host and a plug-in compiled in different versions of Delphi to exchange
  /// string data without ABI mismatches.
  /// </summary>
  IUnicodeString = interface
    ['{3B33C7A5-63F4-4700-A6D5-4072D707536C}']
    /// <summary>Returns a pointer to the wrapped string's character data.</summary>
    function GetValue: PWideChar;
    /// <summary>Sets the wrapped string from a null-terminated wide string.</summary>
    procedure SetValue(P: PWideChar);
    /// <summary>Sets the wrapped string from a wide buffer with explicit length.</summary>
    procedure SetString(P: PWideChar; Len: Integer);
    /// <summary>Returns the wrapped string's length in characters.</summary>
    function GetLength: Integer;

    /// <summary>Read/write access to the wrapped wide string.</summary>
    property Value: PWideChar read GetValue write SetValue;
  end;

  /// <summary>Backwards-compatible alias for <see cref="IUnicodeString"/>.</summary>
  IWideString = IUnicodeString;

  /// <summary>
  /// Read-only stream interface used to feed substituted file content to the Delphi compiler.
  /// </summary>
  IVirtualStream = interface
    ['{6BBD7B93-9402-4534-ADD3-A3D287FD70E9}']
    /// <summary>Repositions the stream pointer.</summary>
    function Seek(Offset: Integer; Origin: Integer): Integer; stdcall;
    /// <summary>Reads up to <paramref name="Size"/> bytes into <paramref name="Buffer"/>.</summary>
    function Read(var Buffer; Size: Integer): Integer; stdcall;
    /// <summary>Returns the virtual file's date stamp and size in bytes.</summary>
    procedure FileStatus(out FileDate: Integer; out FileSize: Integer); stdcall;
  end;

  /// <summary>
  /// Writable stream interface used to capture output that the compiler would have
  /// written to a real file (e.g. to redirect DCU output to memory).
  /// </summary>
  IVirtualOutStream = interface(IVirtualStream)
    ['{9715EB14-952D-42B6-B0BF-4B949337CD8A}']
    /// <summary>Writes <paramref name="Size"/> bytes from <paramref name="Buffer"/> to the virtual stream.</summary>
    function Write(const Buffer; Size: Integer): Integer; stdcall;
  end;

  /// <summary>
  /// Implemented by a CompileInterceptor plug-in to participate in the Delphi compiler's
  /// file I/O, message and pre-compile pipeline. Each method is invoked according to the
  /// flags returned by <see cref="GetOptions"/>.
  /// </summary>
  ICompileInterceptor = interface
    ['{186D90CD-598B-4162-8E03-0BF8298A0826}']
    /// <summary>Returns the bitmask of <c>CIO_*</c> flags advertising which interceptor methods are supported.</summary>
    function GetOptions: TCompileInterceptOptions; stdcall;

    /// <summary>
    /// Called when the compiler wants to open a file. Returning a non-nil
    /// <see cref="IVirtualStream"/> diverts reading to that stream and prevents
    /// <see cref="AlterFile"/> being called. Requires <c>CIO_VIRTUALFILES</c>.
    /// </summary>
    /// <remarks>Not called when the plug-in implements <see cref="ICompileInterceptor20"/>.</remarks>
    /// <seealso cref="ICompileInterceptor20.OpenVirtualFile"/>
    function GetVirtualFile(Filename: PWideChar): IVirtualStream; stdcall; // deprecated 'implement OpenVirtualFile'

    /// <summary>
    /// Called when a file is not handled as virtual and <c>CIO_ALTERFILES</c> is set, giving the
    /// plug-in a chance to substitute the file content. <paramref name="FileDate"/> is obsolete and always 0.
    /// </summary>
    function AlterFile(Filename: PWideChar; Content: PByte; FileDate, FileSize: Integer): IVirtualStream; stdcall;

    /// <summary>
    /// Called when a file is being opened or created and <c>CIO_INSPECTFILENAMES</c> is set.
    /// Lets the plug-in observe (but not alter) which files the compiler is touching.
    /// </summary>
    procedure InspectFilename(Filename: PWideChar; FileMode: TInspectFileMode); stdcall;

    /// <summary>
    /// Called when the compiler is about to emit a message and <c>CIO_ALTERMESSAGES</c> is set.
    /// </summary>
    /// <returns><c>True</c> if any of the in/out parameters were modified.</returns>
    function AlterMessage(IsCompilerMessage: Boolean; var MsgKind: TMsgKind; var Code: Integer;
      const Filename: IUnicodeString; var Line, Column: Integer; const Msg: IUnicodeString): Boolean; stdcall;

    /// <summary>Called immediately before a project is compiled when <c>CIO_COMPILEPROJECTS</c> is set.</summary>
    procedure CompileProject(ProjectFilename, UnitPaths, SourcePaths, DcuOutputDir: PWideChar;
      IsCodeInsight: Boolean; var Cancel: Boolean); stdcall;
  end;

  /// <summary>
  /// Version 2.0 extension to <see cref="ICompileInterceptor"/>. Adds output redirection,
  /// a richer open-virtual-file API, and a hook for file timestamp resolution.
  /// </summary>
  ICompileInterceptor20 = interface(ICompileInterceptor)
    ['{02B49BD8-69F4-4105-8592-E37408788840}']

    /// <summary>
    /// Called when a file is being created and <c>CIO_VIRTUALOUTFILES</c> is set. Returning
    /// <c>False</c> falls back to the default create. Returning <c>True</c> with a non-nil
    /// stream redirects compiler output into that stream instead of creating a file.
    /// </summary>
    function CreateVirtualFile(Filename: PWideChar; out Stream: IVirtualOutStream): Boolean; stdcall;

    /// <summary>
    /// Called when the compiler opens a file. Returning <c>True</c> with a non-nil stream
    /// supplies the file content and skips <see cref="AlterFile"/>. Returning <c>True</c>
    /// with <c>nil</c> causes a "file not found" failure. Returning <c>False</c> defers
    /// to the next handler (and ultimately to <see cref="AlterFile"/> if <c>CIO_ALTERFILES</c> is set).
    /// Requires <c>CIO_VIRTUALFILES</c>.
    /// </summary>
    function OpenVirtualFile(Filename: PWideChar; out Stream: IVirtualStream): Boolean; stdcall;

    /// <summary>
    /// Called when the compiler asks for the file timestamp of <paramref name="Filename"/>.
    /// Requires <c>CIO_FILENAMEDATES</c>.
    /// </summary>
    /// <returns><c>True</c> if the plug-in handled the request and <paramref name="AFileDate"/> is valid.</returns>
    function FileNameDate(Filename: PWideChar; out AFileDate: Integer): Boolean; stdcall;
  end;

  /// <summary>
  /// Host-side service interface published by the CompileInterceptor DLL through
  /// <c>GetCompileInterceptorServices</c>. Plug-ins use it to register and unregister
  /// themselves and to peek at editor content.
  /// </summary>
  ICompileInterceptorServices = interface
    ['{CA696A1B-77EF-4EEB-9F22-9EE6E53B2B76}']
    /// <summary>Registers a compile interceptor and returns an opaque ID for later unregistration.</summary>
    function RegisterInterceptor(Interceptor: ICompileInterceptor): Integer; stdcall;
    /// <summary>Removes the compile interceptor that was registered under the supplied <paramref name="Id"/>.</summary>
    procedure UnregisterInterceptor(Id: Integer); stdcall;

    /// <summary>
    /// Returns the content of <paramref name="Filename"/>. If the file is open in the editor,
    /// the editor's in-memory content is returned, otherwise the on-disk content is read.
    /// </summary>
    function GetFileContent(Filename: PWideChar): IVirtualStream; stdcall;
  end;

  /// <summary>Reference implementation of <see cref="IUnicodeString"/> backed by a Delphi <c>string</c>.</summary>
  TUnicodeStringAdapter = class(TInterfacedObject, IUnicodeString)
  private
    /// <summary>Backing storage for the wrapped Unicode string.</summary>
    FValue: string;
  protected
    { IUnicodeString }
    /// <summary>Returns the wrapped string's length in characters.</summary>
    function GetLength: Integer;
    /// <summary>Returns a pointer to the wrapped string's character data.</summary>
    function GetValue: PWideChar;
    /// <summary>Sets the wrapped string from a wide buffer with explicit length.</summary>
    procedure SetString(P: PWideChar; Len: Integer);
    /// <summary>Sets the wrapped string from a null-terminated wide string.</summary>
    procedure SetValue(P: PWideChar);
  public
    /// <summary>Creates an adapter wrapping <paramref name="AValue"/>.</summary>
    constructor Create(const AValue: string);
  end;

  /// <summary>Backwards-compatible alias for <see cref="TUnicodeStringAdapter"/>.</summary>
  TWideStringAdapter = TUnicodeStringAdapter;

  /// <summary>
  /// Function signature exported from <c>CompileInterceptorW.dll</c> as
  /// <c>GetCompileInterceptorServices</c>; returns the host service interface.
  /// </summary>
  TGetCompileInterceptorServices = function: ICompileInterceptorServices; stdcall;
    { external 'CompileInterceptorW.dll' name 'GetCompileInterceptorServices'; }

//const
//  CompileInterceptorEntryPoint = 'CompileInterceptorEntry';
//
//type
//  TDoneProc = procedure; stdcall;
//  TCompileInterceptorEntryPoint = procedure(const CompileInterceptorServices: ICompileInterceptorServices; var DoneProc: TDoneProc); stdcall;

implementation

{ TUnicodeStringAdapter }

constructor TUnicodeStringAdapter.Create(const AValue: string);
begin
  inherited Create;
  FValue := AValue;
end;

function TUnicodeStringAdapter.GetLength: Integer;
begin
  Result := Length(FValue);
end;

function TUnicodeStringAdapter.GetValue: PWideChar;
begin
  Result := PWideChar(FValue);
end;

procedure TUnicodeStringAdapter.SetString(P: PWideChar; Len: Integer);
begin
  System.SetString(FValue, P, Len);
end;

procedure TUnicodeStringAdapter.SetValue(P: PWideChar);
begin
  FValue := P;
end;

end.
