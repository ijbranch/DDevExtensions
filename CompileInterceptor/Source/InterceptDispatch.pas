{******************************************************************************}
{*                                                                            *}
{* CompileInterceptor IDE Plugin                                              *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit InterceptDispatch;

/// <summary>
/// The interceptor registry and event dispatch behind <c>TCompileInterceptorServices</c>, free of any IDE
/// dependency so it can be unit-tested.
/// </summary>
/// <remarks>
/// <para>Each registration is one record (interface, id, options), so a removal can never leave the three
/// out of step.  An interceptor that raises is removed by its id, logged, and the event carries on.</para>
/// <para>Thread safety: the compiler calls the dispatchers on its own thread (background compilation) while
/// plug-ins register and unregister on the main thread.  Every dispatcher works on a snapshot taken under a
/// read lock and calls the interceptors with no lock held, so an interceptor may synchronise with the main
/// thread without deadlocking it.</para>
/// </remarks>

interface

uses
  System.SysUtils, System.SyncObjs, InterceptIntf;

type
  /// <summary>One registered interceptor.</summary>
  TInterceptorEntry = record
    /// <summary>Registration id handed back to the plug-in.</summary>
    Id: Integer;
    /// <summary>The plug-in's interceptor.</summary>
    Interceptor: ICompileInterceptor;
    /// <summary>The <c>CIO_*</c> options the interceptor reported at registration.</summary>
    Options: TCompileInterceptOptions;
  end;

  /// <summary>Registry of compile interceptors and the dispatch of compiler events to them.</summary>
  TInterceptorRegistry = class( TObject )
  private
    /// <summary>Guards <see cref="FEntries"/> and <see cref="FLastId"/>.</summary>
    FLock: TLightweightMREW;
    /// <summary>Registered interceptors in registration order; the last one is asked first.</summary>
    FEntries: TArray<TInterceptorEntry>;
    /// <summary>Last id handed out.</summary>
    FLastId: Integer;
    /// <summary>OR of every registered interceptor's options; read without the lock (an aligned 32-bit value).</summary>
    FOptionsUnion: TCompileInterceptOptions;
    /// <summary>Recomputes <see cref="FOptionsUnion"/>; the caller holds the write lock.</summary>
    procedure RecomputeOptions;
    /// <summary>Returns a copy of the registrations, taken under the read lock.</summary>
    /// <returns>The registrations at the time of the call.</returns>
    function Snapshot: TArray<TInterceptorEntry>;
    /// <summary>Removes an interceptor that raised during dispatch, and logs why.</summary>
    /// <param name="Id">Registration id of the interceptor.</param>
    /// <param name="ExceptObj">
    /// The raised object (<c>ExceptObject</c>).  An interceptor living in another module with its own RTL (DDevExtensions
    /// uses rtl370.bpl, this DLL links its own) raises an object of that module's <c>Exception</c> class, which is not
    /// this module's <c>Exception</c>; it is logged by class name only.
    /// </param>
    /// <param name="EventName">Name of the event being dispatched, for the log line.</param>
    procedure RemoveBroken( Id: Integer; ExceptObj: TObject; const EventName: string );
  public
    /// <summary>Registers an interceptor.</summary>
    /// <param name="Interceptor">The interceptor; nil is refused.</param>
    /// <returns>The registration id (1 or more), or -1 when nothing was registered.</returns>
    function Register( const Interceptor: ICompileInterceptor ): Integer;
    /// <summary>Removes the registration with the given id.</summary>
    /// <param name="Id">Registration id from <see cref="Register"/>.</param>
    /// <returns>True when a registration was removed; False for an unknown or already removed id.</returns>
    function Unregister( Id: Integer ): Boolean;
    /// <summary>Number of registered interceptors.</summary>
    /// <returns>The count.</returns>
    function Count: Integer;
    /// <summary>True when at least one registered interceptor reports any of the given options.</summary>
    /// <param name="Mask">One or more <c>CIO_*</c> flags.</param>
    /// <returns>True when any registered interceptor has one of the flags.</returns>
    function HasOption( Mask: TCompileInterceptOptions ): Boolean;

    /// <summary>Asks the interceptors (newest first) to supply a virtual file for <paramref name="Filename"/>.</summary>
    /// <param name="Filename">The file the compiler is opening.</param>
    /// <param name="Stream">The virtual content, or nil.</param>
    /// <returns>True when an interceptor answered; with a nil <paramref name="Stream"/> the file is hidden.</returns>
    function OpenVirtualFile( const Filename: string; out Stream: IVirtualStream ): Boolean;
    /// <summary>Asks the interceptors (newest first) to supply a virtual output stream for <paramref name="Filename"/>.</summary>
    /// <param name="Filename">The file the compiler is creating.</param>
    /// <param name="Stream">The virtual output, or nil.</param>
    /// <returns>True when an interceptor answered.</returns>
    function CreateVirtualFile( const Filename: string; out Stream: IVirtualOutStream ): Boolean;
    /// <summary>Lets each interceptor (newest first) alter the content; each one sees the previous one's result.</summary>
    /// <param name="Filename">The file the compiler opened.</param>
    /// <param name="Content">The original content.</param>
    /// <param name="FileDate">The file's date stamp.</param>
    /// <param name="FileSize">Size of <paramref name="Content"/> in bytes.</param>
    /// <returns>The last altered content, or nil when no interceptor altered it.</returns>
    function AlterFile( const Filename: string; Content: PByte; FileDate, FileSize: Integer ): IVirtualStream;
    /// <summary>Tells every interested interceptor that the compiler opened or created a file.</summary>
    /// <param name="Filename">The file.</param>
    /// <param name="FileMode">Whether it was opened or created.</param>
    procedure InspectFilename( const Filename: string; FileMode: TInspectFileMode );
    /// <summary>Lets each interested interceptor alter a compiler or linker message.</summary>
    /// <param name="IsCompilerMessage">True for a multi-line compiler message.</param>
    /// <param name="MsgKind">Message kind; may be changed.</param>
    /// <param name="Code">Message code; may be changed.</param>
    /// <param name="Filename">File name, UTF-8; replaced when an interceptor altered the message.</param>
    /// <param name="Line">Line; may be changed.</param>
    /// <param name="Column">Column; may be changed.</param>
    /// <param name="Msg">Message text, UTF-8; replaced when an interceptor altered the message.</param>
    /// <returns>True when any interceptor reported a change.</returns>
    function AlterMessage( IsCompilerMessage: Boolean; var MsgKind: TMsgKind; var Code: Integer;
      var Filename: UTF8String; var Line, Column: Integer; var Msg: UTF8String ): Boolean;
    /// <summary>Tells every interested interceptor that a project compile is starting.</summary>
    /// <param name="ProjectFilename">The project file.</param>
    /// <param name="UnitPaths">Unit search path.</param>
    /// <param name="SourcePaths">Source search path.</param>
    /// <param name="DcuOutputDir">DCU output folder.</param>
    /// <param name="IsCodeInsight">True for a Code Insight compile.</param>
    /// <param name="Cancel">Set by an interceptor to cancel the compile.</param>
    procedure CompileProject( const ProjectFilename, UnitPaths, SourcePaths, DcuOutputDir: string;
      IsCodeInsight: Boolean; var Cancel: Boolean );
    /// <summary>Asks the interceptors (newest first) for the date stamp of <paramref name="Filename"/>.</summary>
    /// <param name="Filename">The file.</param>
    /// <param name="FileDate">The date stamp (-1 is reported as 0).</param>
    /// <returns>True when an interceptor answered.</returns>
    function FileNameDate( const Filename: string; out FileDate: Integer ): Boolean;
  end;

/// <summary>
/// Joins a project's unit path and the IDE's global library path into one <c>;</c>-separated list with no
/// empty entries at either end.
/// </summary>
/// <param name="ProjectPaths">The project's unit search path (may be empty).</param>
/// <param name="GlobalPaths">The IDE's library path (may be empty).</param>
/// <returns>The combined list.</returns>
function CombineSearchPaths( const ProjectPaths, GlobalPaths: string ): string;

/// <summary>
/// Describes a raised object for a log line.  Handlers in this DLL catch everything (a bare <c>except</c>) because
/// an object raised by another module's RTL is not this module's <c>Exception</c> and slips past
/// <c>on E: Exception</c>; this names such an object by class only.
/// </summary>
/// <param name="ExceptObj">The raised object (<c>ExceptObject</c>); may be nil.</param>
/// <returns>"Class: message" for a native exception, the class and "non-native exception" otherwise.</returns>
function ExceptObjectText( ExceptObj: TObject ): string;

implementation

uses
  Winapi.Windows;

const
  /// <summary><c>IVirtualStream.Seek</c> origin: from the start of the stream.</summary>
  SeekFromBeginning = 0;

function ExceptObjectText( ExceptObj: TObject ): string;
begin
  if ExceptObj is Exception then
    Result          := ExceptObj.ClassName + ': ' + Exception( ExceptObj ).Message
  else if ExceptObj <> nil then
    Result          := ExceptObj.ClassName + ' (non-native exception: raised by another module''s RTL)'
  else
    Result          := 'unknown exception';
end;

function CombineSearchPaths( const ProjectPaths, GlobalPaths: string ): string;
begin
  var Project       := ProjectPaths.Trim( [ ';' ] );
  var Global        := GlobalPaths.Trim( [ ';' ] );
  if Project = '' then
    Result          := Global
  else if Global = '' then
    Result          := Project
  else
    Result          := Project + ';' + Global;
end;

{ TInterceptorRegistry }

procedure TInterceptorRegistry.RecomputeOptions;
begin
  var Union: TCompileInterceptOptions := 0;
  for var Entry in FEntries do
    Union := Union or Entry.Options;
  FOptionsUnion     := Union;
end;

function TInterceptorRegistry.Snapshot: TArray<TInterceptorEntry>;
begin
  FLock.BeginRead;
  try
    Result          := Copy( FEntries );
  finally
    FLock.EndRead;
  end;
end;

procedure TInterceptorRegistry.RemoveBroken( Id: Integer; ExceptObj: TObject; const EventName: string );
begin
  Unregister( Id );
  OutputDebugString( PChar( Format( 'CompileInterceptor: interceptor %d raised %s in %s and was removed',
        [ Id, ExceptObjectText( ExceptObj ), EventName ] ) ) );
end;

function TInterceptorRegistry.Register( const Interceptor: ICompileInterceptor ): Integer;
begin
  Result            := -1;
  if Interceptor = nil then
    Exit;
  var Entry: TInterceptorEntry;
  Entry.Interceptor := Interceptor;
  try
    Entry.Options   := Interceptor.GetOptions;
  except
    // Catch everything: an interceptor from another module raises that module's Exception class, which an
    // "on E: Exception" handler here does not match
    OutputDebugString( PChar( 'CompileInterceptor: GetOptions raised ' + ExceptObject.ClassName +
        '; the interceptor was not registered' ) );
    Exit;
  end;
  FLock.BeginWrite;
  try
    Inc( FLastId );
    Entry.Id        := FLastId;
    FEntries        := FEntries + [ Entry ];
    RecomputeOptions;
    Result          := Entry.Id;
  finally
    FLock.EndWrite;
  end;
end;

function TInterceptorRegistry.Unregister( Id: Integer ): Boolean;
begin
  Result            := False;
  FLock.BeginWrite;
  try
    for var I := High( FEntries ) downto 0 do
      if FEntries[ I ].Id = Id then
      begin
        Delete( FEntries, I, 1 );
        RecomputeOptions;
        Result      := True;
        Break;
      end;
  finally
    FLock.EndWrite;
  end;
end;

function TInterceptorRegistry.Count: Integer;
begin
  FLock.BeginRead;
  try
    Result          := Length( FEntries );
  finally
    FLock.EndRead;
  end;
end;

function TInterceptorRegistry.HasOption( Mask: TCompileInterceptOptions ): Boolean;
begin
  Result            := ( FOptionsUnion and Mask ) <> 0;
end;

function TInterceptorRegistry.OpenVirtualFile( const Filename: string; out Stream: IVirtualStream ): Boolean;
begin
  Stream            := nil;
  Result            := False;
  var Entries       := Snapshot;
  for var I := High( Entries ) downto 0 do // the newest registration is asked first
  begin
    if Entries[ I ].Options and CIO_VIRTUALFILES = 0 then
      Continue;
    try
      var Intf20: ICompileInterceptor20;
      if Supports( Entries[ I ].Interceptor, ICompileInterceptor20, Intf20 ) then
        Result      := Intf20.OpenVirtualFile( PWideChar( Filename ), Stream )
      else
      begin
        Stream      := Entries[ I ].Interceptor.GetVirtualFile( PWideChar( Filename ) );
        Result      := Stream <> nil;
      end;
    except
      // Bare except on purpose: a foreign module's exception class misses "on E: Exception"
      Stream        := nil;
      Result        := False;
      RemoveBroken( Entries[ I ].Id, ExceptObject, 'OpenVirtualFile' );
    end;
    if Result then
      Exit;
  end;
end;

function TInterceptorRegistry.CreateVirtualFile( const Filename: string; out Stream: IVirtualOutStream ): Boolean;
begin
  Stream            := nil;
  Result            := False;
  var Entries       := Snapshot;
  for var I := High( Entries ) downto 0 do
  begin
    var Intf20: ICompileInterceptor20;
    if ( Entries[ I ].Options and CIO_VIRTUALOUTFILES = 0 ) or
      not Supports( Entries[ I ].Interceptor, ICompileInterceptor20, Intf20 ) then
      Continue;
    try
      Result        := Intf20.CreateVirtualFile( PWideChar( Filename ), Stream );
    except
      // Bare except on purpose: a foreign module's exception class misses "on E: Exception"
      Stream        := nil;
      Result        := False;
      RemoveBroken( Entries[ I ].Id, ExceptObject, 'CreateVirtualFile' );
    end;
    if Result then
      Exit;
  end;
end;

function TInterceptorRegistry.AlterFile( const Filename: string; Content: PByte; FileDate,
  FileSize: Integer ): IVirtualStream;
begin
  Result            := nil;
  var Buf: TBytes   := nil;
  var Entries       := Snapshot;
  for var I := High( Entries ) downto 0 do
  begin
    if Entries[ I ].Options and CIO_ALTERFILES = 0 then
      Continue;
    if Result <> nil then
    begin
      // The content is already altered: the next interceptor works on the altered bytes, so the buffer is
      // sized to the altered stream, not to the original file
      var StreamDate, StreamSize: Integer;
      Result.FileStatus( StreamDate, StreamSize );
      Result.Seek( 0, SeekFromBeginning );
      Content       := nil;
      FileSize      := 0;
      if StreamSize > 0 then
      begin
        SetLength( Buf, StreamSize );
        FileSize    := Result.Read( Buf[ 0 ], StreamSize );
        Result.Seek( 0, SeekFromBeginning );
        if FileSize > 0 then
          Content   := @Buf[ 0 ];
      end;
    end;
    try
      var Altered   := Entries[ I ].Interceptor.AlterFile( PWideChar( Filename ), Content, FileDate, FileSize );
      if Altered <> nil then
        Result      := Altered;
    except
      // Bare except on purpose: a foreign module's exception class misses "on E: Exception"
      RemoveBroken( Entries[ I ].Id, ExceptObject, 'AlterFile' );
    end;
  end;
end;

procedure TInterceptorRegistry.InspectFilename( const Filename: string; FileMode: TInspectFileMode );
begin
  var Entries       := Snapshot;
  for var I := High( Entries ) downto 0 do
  begin
    if Entries[ I ].Options and CIO_INSPECTFILENAMES = 0 then
      Continue;
    try
      Entries[ I ].Interceptor.InspectFilename( PWideChar( Filename ), FileMode );
    except
      // Bare except on purpose: a foreign module's exception class misses "on E: Exception"
      RemoveBroken( Entries[ I ].Id, ExceptObject, 'InspectFilename' );
    end;
  end;
end;

function TInterceptorRegistry.AlterMessage( IsCompilerMessage: Boolean; var MsgKind: TMsgKind;
  var Code: Integer; var Filename: UTF8String; var Line, Column: Integer; var Msg: UTF8String ): Boolean;
begin
  Result            := False;
  var Entries       := Snapshot;
  if Entries = nil then
    Exit;
  var FilenameStr: IUnicodeString := TUnicodeStringAdapter.Create( UTF8ToString( Filename ) );
  var MsgStr: IUnicodeString := TUnicodeStringAdapter.Create( UTF8ToString( Msg ) );
  for var I := High( Entries ) downto 0 do
  begin
    if Entries[ I ].Options and CIO_ALTERMESSAGES = 0 then
      Continue;
    try
      if Entries[ I ].Interceptor.AlterMessage( IsCompilerMessage, MsgKind, Code, FilenameStr, Line, Column,
        MsgStr ) then
        Result      := True;
    except
      // Bare except on purpose: a foreign module's exception class misses "on E: Exception"
      RemoveBroken( Entries[ I ].Id, ExceptObject, 'AlterMessage' );
    end;
  end;
  if Result then
  begin
    Filename        := UTF8String( string( FilenameStr.Value ) );
    Msg             := UTF8String( string( MsgStr.Value ) );
  end;
end;

procedure TInterceptorRegistry.CompileProject( const ProjectFilename, UnitPaths, SourcePaths,
  DcuOutputDir: string; IsCodeInsight: Boolean; var Cancel: Boolean );
begin
  var Entries       := Snapshot;
  for var I := High( Entries ) downto 0 do
  begin
    if Entries[ I ].Options and CIO_COMPILEPROJECTS = 0 then
      Continue;
    try
      Entries[ I ].Interceptor.CompileProject( PWideChar( ProjectFilename ), PWideChar( UnitPaths ),
        PWideChar( SourcePaths ), PWideChar( DcuOutputDir ), IsCodeInsight, Cancel );
    except
      // Bare except on purpose: a foreign module's exception class misses "on E: Exception"
      RemoveBroken( Entries[ I ].Id, ExceptObject, 'CompileProject' );
    end;
  end;
end;

function TInterceptorRegistry.FileNameDate( const Filename: string; out FileDate: Integer ): Boolean;
begin
  FileDate          := 0;
  Result            := False;
  var Entries       := Snapshot;
  for var I := High( Entries ) downto 0 do
  begin
    var Intf20: ICompileInterceptor20;
    if ( Entries[ I ].Options and CIO_FILENAMEDATES = 0 ) or
      not Supports( Entries[ I ].Interceptor, ICompileInterceptor20, Intf20 ) then
      Continue;
    try
      Result        := Intf20.FileNameDate( PWideChar( Filename ), FileDate );
    except
      // Bare except on purpose: a foreign module's exception class misses "on E: Exception"
      Result        := False;
      RemoveBroken( Entries[ I ].Id, ExceptObject, 'FileNameDate' );
    end;
    if Result then
    begin
      if FileDate = -1 then
        FileDate    := 0;
      Exit;
    end;
  end;
end;

end.

