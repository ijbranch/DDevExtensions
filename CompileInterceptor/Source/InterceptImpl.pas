{******************************************************************************}
{*                                                                            *}
{* CompileInterceptor IDE Plugin                                              *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit InterceptImpl;

/// <summary>
/// In-DLL implementation of the CompileInterceptor host services. Maintains the list of
/// registered <see cref="ICompileInterceptor"/> plug-ins, fans out compiler callbacks to
/// each plug-in (in last-registered-first order), and exposes the
/// <c>GetCompileInterceptorServices</c> entry point used by client packages.
/// </summary>

{$I CompileInterceptor.inc}

interface

uses
  System.SysUtils, System.Classes, FileStreams, InterceptIntf, InterceptDispatch;

type
  /// <summary>
  /// Concrete <see cref="ICompileInterceptorServices"/> implementation. Keeps a list of
  /// registered plug-ins, caches their option flags for fast dispatch and dispatches
  /// compiler events to the plug-ins that opted into each event class.
  /// </summary>
  TCompileInterceptorServices = class(TComponent, ICompileInterceptorServices)
  private
    /// <summary>The registrations and the event dispatch (see <c>InterceptDispatch</c>).</summary>
    FRegistry: TInterceptorRegistry;
    /// <summary>Returns the count of registered interceptors.</summary>
    /// <returns>The count.</returns>
    function GetCount: Integer;
    /// <summary>Reads one <c>CIO_*</c> flag from the registry's option cache.</summary>
    /// <param name="Index">The flag.</param>
    /// <returns>True when any registered interceptor reports the flag.</returns>
    function GetHasOption(Index: Integer): Boolean;
  public
    /// <summary>Creates the service container.</summary>
    /// <param name="AOwner">Component owner (nil for the DLL's singleton).</param>
    constructor Create(AOwner: TComponent); override;
    /// <summary>Releases the registered plug-ins and the registry.</summary>
    destructor Destroy; override;
  public
    { ICompileInterceptorServices }
    /// <summary>Registers a plug-in and returns the ID to pass back to <see cref="UnregisterInterceptor"/>.</summary>
    /// <param name="Interceptor">The plug-in's interceptor.</param>
    /// <returns>The registration id, or -1 when nothing was registered.</returns>
    function RegisterInterceptor(Interceptor: ICompileInterceptor): Integer; stdcall;
    /// <summary>Unregisters the plug-in previously registered with the given <paramref name="Id"/>; an unknown id is ignored.</summary>
    /// <param name="Id">Registration id.</param>
    procedure UnregisterInterceptor(Id: Integer); stdcall;
    /// <summary>Returns a virtual stream over the editor or on-disk content of <paramref name="Filename"/>.</summary>
    /// <param name="Filename">The file.</param>
    /// <returns>The content, or nil when the file cannot be opened.</returns>
    function GetFileContent(Filename: PWideChar): IVirtualStream; stdcall;
  public
    /// <summary>Asks each registered plug-in (in reverse registration order) to open a virtual file.</summary>
    /// <param name="Filename">UTF-8 file name from the compiler.</param>
    /// <param name="Stream">The virtual content, or nil.</param>
    /// <returns>True when a plug-in answered.</returns>
    function OpenVirtualFile(Filename: PAnsiChar; out Stream: IVirtualStream): Boolean;
    /// <summary>Asks each registered plug-in to provide a virtual output stream for a file create.</summary>
    /// <param name="Filename">UTF-8 file name from the compiler.</param>
    /// <param name="Stream">The virtual output, or nil.</param>
    /// <returns>True when a plug-in answered.</returns>
    function CreateVirtualFile(Filename: PAnsiChar; out Stream: IVirtualOutStream): Boolean;
    /// <summary>Lets registered plug-ins alter the content of a file just opened by the compiler.</summary>
    /// <param name="Filename">UTF-8 file name from the compiler.</param>
    /// <param name="Content">The original content.</param>
    /// <param name="FileDate">The file's date stamp.</param>
    /// <param name="FileSize">Size of <paramref name="Content"/>.</param>
    /// <returns>The altered content, or nil.</returns>
    function AlterFile(Filename: PAnsiChar; Content: PByte; FileDate, FileSize: Integer): IVirtualStream;
    /// <summary>Notifies registered plug-ins that the compiler has opened or created <paramref name="Filename"/>.</summary>
    /// <param name="Filename">UTF-8 file name from the compiler.</param>
    /// <param name="FileMode">Opened or created.</param>
    procedure InspectFilename(Filename: PAnsiChar; FileMode: TInspectFileMode);
    /// <summary>Lets registered plug-ins alter a compiler/linker message before it is emitted.</summary>
    /// <param name="IsCompilerMessage">True for a multi-line compiler message.</param>
    /// <param name="MsgKind">Message kind.</param>
    /// <param name="Code">Message code.</param>
    /// <param name="Filename">File name, UTF-8.</param>
    /// <param name="Line">Line.</param>
    /// <param name="Column">Column.</param>
    /// <param name="Msg">Message text, UTF-8.</param>
    /// <returns><c>True</c> if any plug-in modified one of the in/out parameters.</returns>
    function AlterMessage(IsCompilerMessage: Boolean; var MsgKind: TMsgKind;
      var Code: Integer; var Filename: UTF8String; var Line, Column: Integer; var Msg: UTF8String): Boolean;
    /// <summary>Notifies plug-ins that a project compile is about to start; any plug-in may set <paramref name="Cancel"/>.</summary>
    /// <param name="ProjectFilename">The project file.</param>
    /// <param name="UnitPaths">Unit search path.</param>
    /// <param name="SourcePaths">Source search path.</param>
    /// <param name="DcuOutputDir">DCU output folder.</param>
    /// <param name="IsCodeInsight">True for a Code Insight compile.</param>
    /// <param name="Cancel">Set to cancel the compile.</param>
    procedure CompileProject(const ProjectFilename, UnitPaths, SourcePaths, DcuOutputDir: string;
      IsCodeInsight: Boolean; var Cancel: Boolean);
    /// <summary>Asks plug-ins to resolve the file timestamp for <paramref name="Filename"/>.</summary>
    /// <param name="Filename">UTF-8 file name from the compiler.</param>
    /// <param name="FileDate">The date stamp.</param>
    /// <returns>True when a plug-in answered.</returns>
    function FileNameDate(Filename: PAnsiChar; out FileDate: Integer): Boolean;

    /// <summary>Number of registered plug-ins.</summary>
    property Count: Integer read GetCount;

    /// <summary>True when at least one registered plug-in advertises <c>CIO_ALTERFILES</c>.</summary>
    property HasAlterFile: Boolean index CIO_ALTERFILES read GetHasOption;
    /// <summary>True when at least one registered plug-in advertises <c>CIO_VIRTUALFILES</c>.</summary>
    property HasVirtualFiles: Boolean index CIO_VIRTUALFILES read GetHasOption;
    /// <summary>True when at least one registered plug-in advertises <c>CIO_VIRTUALOUTFILES</c>.</summary>
    property HasVirtualOutFiles: Boolean index CIO_VIRTUALOUTFILES read GetHasOption;
    /// <summary>True when at least one registered plug-in advertises <c>CIO_INSPECTFILENAMES</c>.</summary>
    property HasInspectFilename: Boolean index CIO_INSPECTFILENAMES read GetHasOption;
    /// <summary>True when at least one registered plug-in advertises <c>CIO_ALTERMESSAGES</c>.</summary>
    property HasAlterMessage: Boolean index CIO_ALTERMESSAGES read GetHasOption;
    /// <summary>True when at least one registered plug-in advertises <c>CIO_COMPILEPROJECTS</c>.</summary>
    property HasCompileProjects: Boolean index CIO_COMPILEPROJECTS read GetHasOption;
    /// <summary>True when at least one registered plug-in advertises <c>CIO_FILENAMEDATES</c>.</summary>
    property HasFileNameDate: Boolean index CIO_FILENAMEDATES read GetHasOption;
  end;

  /// <summary>
  /// VCL <see cref="TStream"/> facade over an <see cref="IVirtualStream"/>, so virtual file
  /// content from a plug-in can be passed to APIs that expect a stream object. Writing is
  /// not supported.
  /// </summary>
  TVirtualStreamAdapter = class(TStream)
  private
    /// <summary>Underlying interceptor virtual stream.</summary>
    FVirtualStream: IVirtualStream;
  protected
    /// <summary>Routes 32-bit <c>SetSize</c> via <c>Seek</c>.</summary>
    /// <param name="NewSize">Position to seek to.</param>
    procedure SetSize(NewSize: Longint); override;
    {$IFDEF COMPILER6_UP}
    /// <summary>Routes 64-bit <c>SetSize</c> via <c>Seek</c>.</summary>
    /// <param name="NewSize">Position to seek to.</param>
    procedure SetSize(const NewSize: Int64); override;
    {$ENDIF COMPILER6_UP}
  public
    /// <summary>Creates an adapter that delegates to <paramref name="AVirtualStream"/>.</summary>
    /// <param name="AVirtualStream">Virtual stream to read from; the adapter keeps a reference to it.</param>
    constructor Create(AVirtualStream: IVirtualStream);

    /// <summary>Reads up to <paramref name="Count"/> bytes from the underlying virtual stream.</summary>
    /// <param name="Buffer">Receives the bytes read.</param>
    /// <param name="Count">Maximum number of bytes to read.</param>
    /// <returns>Number of bytes read.</returns>
    function Read(var Buffer; Count: Integer): Integer; override;
    /// <summary>Always fails (returns -1) - the underlying virtual stream is read-only.</summary>
    /// <param name="Buffer">Not used.</param>
    /// <param name="Count">Not used.</param>
    /// <returns>Always -1.</returns>
    function Write(const Buffer; Count: Integer): Integer; override;
    {$IFDEF COMPILER6_UP}
    /// <summary>Repositions the underlying virtual stream (64-bit overload).</summary>
    /// <param name="Offset">Distance to move, relative to <paramref name="Origin"/>.</param>
    /// <param name="Origin">Reference point: beginning, current position or end.</param>
    /// <returns>The new position reported by the virtual stream.</returns>
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    {$ELSE}
    /// <summary>Repositions the underlying virtual stream (legacy 32-bit overload).</summary>
    /// <param name="Offset">Distance to move, relative to <paramref name="Origin"/>.</param>
    /// <param name="Origin">Reference point: beginning, current position or end.</param>
    /// <returns>The new position reported by the virtual stream.</returns>
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    {$ENDIF COMPILER6_UP}
  end;

  /// <summary>
  /// Default <see cref="IVirtualStream"/> implementation that wraps an existing
  /// <see cref="TStream"/> and reports a caller-supplied file timestamp.
  /// </summary>
  TVirtualStream = class(TInterfacedObject, IVirtualStream)
  private
    /// <summary>When True, the wrapped stream is freed in <see cref="Destroy"/>.</summary>
    FAutoDelete: Boolean;
    /// <summary>Wrapped stream that supplies file content.</summary>
    FStream: TStream;
    /// <summary>File date stamp returned from <see cref="FileStatus"/>.</summary>
    FFileDate: Integer;
  public
    /// <summary>
    /// Creates a virtual stream over <paramref name="AStream"/>. When
    /// <paramref name="AAutoDelete"/> is True (default), the wrapped stream is freed when
    /// this instance is released.
    /// </summary>
    /// <param name="AStream">Stream that supplies the file content.</param>
    /// <param name="AFileDate">DOS-format file date reported by <see cref="FileStatus"/>.</param>
    /// <param name="AAutoDelete">True to free <paramref name="AStream"/> when this instance is destroyed.</param>
    constructor Create(AStream: TStream; AFileDate: Integer; AAutoDelete: Boolean = True);
    /// <summary>Frees the wrapped stream if <see cref="FAutoDelete"/> is set.</summary>
    destructor Destroy; override;

    /// <summary>Repositions the wrapped stream.</summary>
    /// <param name="Offset">Distance to move, relative to <paramref name="Origin"/>.</param>
    /// <param name="Origin"><c>soFromBeginning</c>, <c>soFromCurrent</c> or <c>soFromEnd</c>.</param>
    /// <returns>The new position in the wrapped stream.</returns>
    function Seek(Offset: Integer; Origin: Integer): Integer; stdcall;
    /// <summary>Reads up to <paramref name="Size"/> bytes from the wrapped stream.</summary>
    /// <param name="Buffer">Receives the bytes read.</param>
    /// <param name="Size">Maximum number of bytes to read.</param>
    /// <returns>Number of bytes read.</returns>
    function Read(var Buffer; Size: Integer): Integer; stdcall;
    /// <summary>Returns the wrapped stream's size and the cached file date.</summary>
    /// <param name="FileDate">Receives the file date passed to the constructor.</param>
    /// <param name="FileSize">Receives the wrapped stream's size in bytes.</param>
    procedure FileStatus(out FileDate: Integer; out FileSize: Integer); stdcall;
  end;

/// <summary>Singleton <see cref="TCompileInterceptorServices"/> instance for the loaded DLL.</summary>
var
  CompileInterceptorServices: TCompileInterceptorServices;

implementation

uses
  Winapi.Windows, CompilerHooks, IdeDllNames;

function GetCompileInterceptorServices: ICompileInterceptorServices; stdcall;
begin
  if not Assigned(CompileInterceptorServices) then
    InitCompileInterceptor;
  Result := CompileInterceptorServices;
end;

exports
  GetCompileInterceptorServices;


{ TVirtualStreamAdapter }

constructor TVirtualStreamAdapter.Create(AVirtualStream: IVirtualStream);
begin
  inherited Create;
  FVirtualStream := AVirtualStream;
end;

procedure TVirtualStreamAdapter.SetSize(NewSize: Longint);
begin
  {$IFDEF COMPILER6_UP}
  SetSize(Int64(NewSize));
  {$ELSE}
  Seek(NewSize, soFromBeginning);
  {$ENDIF COMPILER6_UP}
end;

{$IFDEF COMPILER6_UP}
procedure TVirtualStreamAdapter.SetSize(const NewSize: Int64);
begin
  Seek(NewSize, soBeginning);
end;
{$ENDIF COMPILER6_UP}

function TVirtualStreamAdapter.Read(var Buffer; Count: Integer): Integer;
begin
  Result := FVirtualStream.Read(Buffer, Count);
end;

function TVirtualStreamAdapter.Write(const Buffer; Count: Integer): Integer;
begin
//  Result := FVirtualStream.Write(Buffer, Count);
  Result := -1;
end;

{$IFDEF COMPILER6_UP}
function TVirtualStreamAdapter.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
{$ELSE}
function TVirtualStreamAdapter.Seek(Offset: Longint; Origin: Word): Longint;
{$ENDIF COMPILER6_UP}
begin
  Result := FVirtualStream.Seek(Integer(Offset), Integer(Origin));
end;


{ TVirtualStream }

constructor TVirtualStream.Create(AStream: TStream; AFileDate: Integer; AAutoDelete: Boolean);
begin
  inherited Create;
  FAutoDelete := AAutoDelete;
  FStream := AStream;
  FFileDate := AFileDate;
end;

destructor TVirtualStream.Destroy;
begin
  if FAutoDelete then
    FStream.Free;
  inherited Destroy;
end;

procedure TVirtualStream.FileStatus(out FileDate, FileSize: Integer);
begin
  FileSize := FStream.Size;
  FileDate := FFileDate;
end;

function TVirtualStream.Read(var Buffer; Size: Integer): Integer;
begin
  Result := FStream.Read(Buffer, Size);
end;

function TVirtualStream.Seek(Offset, Origin: Integer): Integer;
begin
  Result := FStream.Seek(Offset, Origin);
end;


{ TCompileInterceptorServices }

constructor TCompileInterceptorServices.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRegistry := TInterceptorRegistry.Create;
end;

destructor TCompileInterceptorServices.Destroy;
begin
  FRegistry.Free;
  inherited Destroy;
end;

function TCompileInterceptorServices.GetCount: Integer;
begin
  Result := FRegistry.Count;
end;

function TCompileInterceptorServices.GetHasOption(Index: Integer): Boolean;
begin
  Result := FRegistry.HasOption( TCompileInterceptOptions( Index ) );
end;

function TCompileInterceptorServices.GetFileContent(Filename: PWideChar): IVirtualStream;
var
  Stream: TStream;
begin
  Stream := ReadFileContent(Filename);
  if Stream <> nil then
    Result := TVirtualStream.Create(Stream, 0);
end;

function TCompileInterceptorServices.OpenVirtualFile(Filename: PAnsiChar; out Stream: IVirtualStream): Boolean;
begin
  Result := FRegistry.OpenVirtualFile( UTF8ToString( Filename ), Stream );
end;

function TCompileInterceptorServices.CreateVirtualFile(Filename: PAnsiChar; out Stream: IVirtualOutStream): Boolean;
begin
  Result := FRegistry.CreateVirtualFile( UTF8ToString( Filename ), Stream );
end;

function TCompileInterceptorServices.AlterFile(Filename: PAnsiChar; Content: PByte; FileDate, FileSize: Integer): IVirtualStream;
begin
  Result := FRegistry.AlterFile( UTF8ToString( Filename ), Content, FileDate, FileSize );
end;

procedure TCompileInterceptorServices.InspectFilename(Filename: PAnsiChar; FileMode: TInspectFileMode);
begin
  FRegistry.InspectFilename( UTF8ToString( Filename ), FileMode );
end;

function TCompileInterceptorServices.AlterMessage(IsCompilerMessage: Boolean;
  var MsgKind: TMsgKind; var Code: Integer; var Filename: UTF8String; var Line,
  Column: Integer; var Msg: UTF8String): Boolean;
begin
  Result := FRegistry.AlterMessage( IsCompilerMessage, MsgKind, Code, Filename, Line, Column, Msg );
end;

procedure TCompileInterceptorServices.CompileProject(const ProjectFilename, UnitPaths, SourcePaths,
  DcuOutputDir: string; IsCodeInsight: Boolean; var Cancel: Boolean);
begin
  FRegistry.CompileProject( ProjectFilename, UnitPaths, SourcePaths, DcuOutputDir, IsCodeInsight, Cancel );
end;

function TCompileInterceptorServices.FileNameDate(Filename: PAnsiChar; out FileDate: Integer): Boolean;
begin
  Result := FRegistry.FileNameDate( UTF8ToString( Filename ), FileDate );
end;

function TCompileInterceptorServices.RegisterInterceptor(Interceptor: ICompileInterceptor): Integer;
begin
  // No exception may leave this stdcall method: it is called across the DLL boundary, and this DLL has no
  // VCL Application to report one (ApplicationHandleException is nil here)
  try
    Result := FRegistry.Register( Interceptor );
  except
    // Bare except: an object raised by another module's RTL misses "on E: Exception"
    OutputDebugString( PChar( 'CompileInterceptor: RegisterInterceptor failed: ' + ExceptObjectText( ExceptObject ) ) );
    Result := -1;
  end;
end;

procedure TCompileInterceptorServices.UnregisterInterceptor(Id: Integer);
begin
  try
    FRegistry.Unregister( Id );
  except
    // Bare except: an object raised by another module's RTL misses "on E: Exception"
    OutputDebugString( PChar( 'CompileInterceptor: UnregisterInterceptor failed: ' + ExceptObjectText( ExceptObject ) ) );
  end;
end;

end.
