unit TestInterceptDispatchDUnitX;

/// <summary>
/// DUnitX tests for <c>InterceptDispatch</c>: the compile-interceptor registry and event dispatch that
/// <c>CompileInterceptorW.dll</c> runs inside the IDE's compiler callbacks.
/// </summary>
/// <remarks>
/// Fake interceptors stand in for plug-ins, so no IDE or compiler is needed.
/// </remarks>

interface

uses
  System.SysUtils, DUnitX.TestFramework, InterceptIntf, InterceptDispatch;

type
  /// <summary>An in-memory <c>IVirtualStream</c> over a byte array.</summary>
  TBytesVirtualStream = class(TInterfacedObject, IVirtualStream)
  private
    /// <summary>The content.</summary>
    FBytes: TBytes;
    /// <summary>Current read position.</summary>
    FPosition: Integer;
  public
    /// <summary>Creates a stream over a copy of <paramref name="ABytes"/>.</summary>
    /// <param name="ABytes">The content.</param>
    constructor Create(const ABytes: TBytes);
    /// <summary>Moves the read position.</summary>
    /// <param name="Offset">Offset from <paramref name="Origin"/>.</param>
    /// <param name="Origin">0 = start, 1 = current, 2 = end.</param>
    /// <returns>The new position.</returns>
    function Seek(Offset: Integer; Origin: Integer): Integer; stdcall;
    /// <summary>Reads up to <paramref name="Size"/> bytes.</summary>
    /// <param name="Buffer">Destination.</param>
    /// <param name="Size">Bytes wanted.</param>
    /// <returns>Bytes read.</returns>
    function Read(var Buffer; Size: Integer): Integer; stdcall;
    /// <summary>Reports the size; the date is always 0.</summary>
    /// <param name="FileDate">Always 0.</param>
    /// <param name="FileSize">Content size.</param>
    procedure FileStatus(out FileDate: Integer; out FileSize: Integer); stdcall;
  end;

  /// <summary>A configurable fake plug-in interceptor that records what it was asked.</summary>
  TFakeInterceptor = class(TInterfacedObject, ICompileInterceptor, ICompileInterceptor20)
  public
    /// <summary>Options reported to the registry.</summary>
    Options: TCompileInterceptOptions;
    /// <summary>When True every event method raises.</summary>
    RaiseOnEvent: Boolean;
    /// <summary>
    /// When True every event method raises an object that is not an <c>Exception</c>, standing in for an exception
    /// raised by another module's RTL (which this module's <c>on E: Exception</c> does not match).
    /// </summary>
    RaiseForeign: Boolean;
    /// <summary>Number of InspectFilename calls received.</summary>
    InspectCount: Integer;
    /// <summary>Text AlterMessage puts into the message (empty: leave the message alone).</summary>
    NewMessage: string;
    /// <summary>Content AlterFile returns (nil: no change).</summary>
    AlterTo: TBytes;
    /// <summary>The content AlterFile last received.</summary>
    SeenContent: TBytes;
    /// <summary>Answer for OpenVirtualFile (nil: not answered).</summary>
    VirtualContent: TBytes;
    /// <summary>Creates a fake with the given options.</summary>
    /// <param name="AOptions">The <c>CIO_*</c> options to report.</param>
    constructor Create(AOptions: TCompileInterceptOptions);
    /// <summary>Returns <see cref="Options"/>.</summary>
    /// <returns>The options.</returns>
    /// <exception cref="Exception">Raised when the fake is set to fail in GetOptions.</exception>
    function GetOptions: TCompileInterceptOptions; stdcall;
    /// <summary>Legacy virtual-file call; unused (the fake supports the 2.0 interface).</summary>
    /// <param name="Filename">Unused.</param>
    /// <returns>nil.</returns>
    function GetVirtualFile(Filename: PWideChar): IVirtualStream; stdcall;
    /// <summary>Records the content and returns <see cref="AlterTo"/>.</summary>
    /// <param name="Filename">Unused.</param>
    /// <param name="Content">The content received.</param>
    /// <param name="FileDate">Unused.</param>
    /// <param name="FileSize">Size of <paramref name="Content"/>.</param>
    /// <returns>A stream over <see cref="AlterTo"/>, or nil.</returns>
    /// <exception cref="Exception">Raised when the fake is set to fail.</exception>
    function AlterFile(Filename: PWideChar; Content: PByte; FileDate, FileSize: Integer): IVirtualStream; stdcall;
    /// <summary>Counts the call.</summary>
    /// <param name="Filename">Unused.</param>
    /// <param name="FileMode">Unused.</param>
    /// <exception cref="Exception">Raised when the fake is set to fail.</exception>
    /// <exception cref="TForeignRaised">Raised when the fake is set to raise a non-native exception.</exception>
    procedure InspectFilename(Filename: PWideChar; FileMode: TInspectFileMode); stdcall;
    /// <summary>Replaces the message with <see cref="NewMessage"/> when it is not empty.</summary>
    /// <param name="IsCompilerMessage">Unused.</param>
    /// <param name="MsgKind">Unused.</param>
    /// <param name="Code">Unused.</param>
    /// <param name="Filename">Left alone.</param>
    /// <param name="Line">Unused.</param>
    /// <param name="Column">Unused.</param>
    /// <param name="Msg">Replaced.</param>
    /// <returns>True when the message was replaced.</returns>
    /// <exception cref="Exception">Raised when the fake is set to fail.</exception>
    function AlterMessage(IsCompilerMessage: Boolean; var MsgKind: TMsgKind; var Code: Integer;
      const Filename: IUnicodeString; var Line, Column: Integer; const Msg: IUnicodeString): Boolean; stdcall;
    /// <summary>Does nothing (or raises).</summary>
    /// <param name="ProjectFilename">Unused.</param>
    /// <param name="UnitPaths">Unused.</param>
    /// <param name="SourcePaths">Unused.</param>
    /// <param name="DcuOutputDir">Unused.</param>
    /// <param name="IsCodeInsight">Unused.</param>
    /// <param name="Cancel">Unused.</param>
    /// <exception cref="Exception">Raised when the fake is set to fail.</exception>
    procedure CompileProject(ProjectFilename, UnitPaths, SourcePaths, DcuOutputDir: PWideChar;
      IsCodeInsight: Boolean; var Cancel: Boolean); stdcall;
    /// <summary>Not supported.</summary>
    /// <param name="Filename">Unused.</param>
    /// <param name="Stream">nil.</param>
    /// <returns>False.</returns>
    function CreateVirtualFile(Filename: PWideChar; out Stream: IVirtualOutStream): Boolean; stdcall;
    /// <summary>Answers with <see cref="VirtualContent"/> when it is assigned.</summary>
    /// <param name="Filename">Unused.</param>
    /// <param name="Stream">The virtual content.</param>
    /// <returns>True when <see cref="VirtualContent"/> is assigned.</returns>
    function OpenVirtualFile(Filename: PWideChar; out Stream: IVirtualStream): Boolean; stdcall;
    /// <summary>Not supported.</summary>
    /// <param name="Filename">Unused.</param>
    /// <param name="AFileDate">0.</param>
    /// <returns>False.</returns>
    function FileNameDate(Filename: PWideChar; out AFileDate: Integer): Boolean; stdcall;
  end;

  /// <summary>Fixture for the interceptor registry, its dispatch and <c>CombineSearchPaths</c>.</summary>
  [TestFixture]
  TTestInterceptDispatch = class
  public
    /// <summary>
    /// An interceptor that raises is removed completely: its id no longer unregisters anything, and the other
    /// interceptor still receives events.  The old code removed it from one of three parallel lists, so the
    /// next unregister removed the wrong interceptor (or raised on an empty list).
    /// </summary>
    [Test]
    procedure TestRaisingInterceptorIsRemovedCompletely;
    /// <summary>
    /// An interceptor in another module raises that module's Exception class, which is not this module's Exception:
    /// it must still be caught and the interceptor removed, not escape into the compiler's callback.
    /// </summary>
    [Test]
    procedure TestNonNativeExceptionIsCaughtAndInterceptorRemoved;
    /// <summary>Removing a raising interceptor also drops its options from the cache.</summary>
    [Test]
    procedure TestRemovalUpdatesOptionCache;
    /// <summary>The option cache covers every flag, including virtual out-files and file-name dates, both ways.</summary>
    [Test]
    procedure TestOptionCacheCoversAllFlags;
    /// <summary>An altered message comes back with the new text, not the file name (the old code copied the file name into it).</summary>
    [Test]
    procedure TestAlterMessageReturnsAlteredText;
    /// <summary>
    /// The second interceptor sees all of the first one's altered content, even when the altered content is
    /// larger than the original.  The old code sized the buffer to the original file and wrote past it.
    /// </summary>
    [Test]
    procedure TestAlterFileChainSeesWholeAlteredContent;
    /// <summary>The newest registration is asked first, and its answer ends the search.</summary>
    [Test]
    procedure TestNewestInterceptorAnswersFirst;
    /// <summary>A nil interceptor, and one whose GetOptions raises, are refused with -1 and leave nothing behind.</summary>
    [Test]
    procedure TestRegisterRefusesNilAndBroken;
    /// <summary>Unregistering an unknown id is harmless and reports False.</summary>
    [Test]
    procedure TestUnregisterUnknownIdIsHarmless;
    /// <summary>
    /// Project and global paths join with no empty entry at either end.  The old trimming removed the
    /// character before a trailing semicolon, corrupting the last path.
    /// </summary>
    /// <param name="Expected">The combined path the routine must return.</param>
    /// <param name="ProjectPaths">The project's search path.</param>
    /// <param name="GlobalPaths">The IDE's global library path.</param>
    [Test]
    [NamedTestCase( 'ProjectOnly', 'C:\a,,C:\a' )]
    [NamedTestCase( 'GlobalOnly', ',C:\g,C:\g' )]
    [NamedTestCase( 'Both', 'C:\a,C:\g,C:\a;C:\g' )]
    [NamedTestCase( 'TrailingSemicolons', 'C:\a;,C:\g;,C:\a;C:\g' )]
    [NamedTestCase( 'Neither', ',,' )]
    procedure TestCombineSearchPaths(const ProjectPaths, GlobalPaths, Expected: string);
  end;

implementation

function BytesOf(const S: string): TBytes;
begin
  Result := TEncoding.UTF8.GetBytes( S );
end;

type
  /// <summary>A raised object that is not this module's <c>Exception</c>, as a foreign RTL's exception appears here.</summary>
  TForeignRaised = class(TObject);

{ TBytesVirtualStream }

constructor TBytesVirtualStream.Create(const ABytes: TBytes);
begin
  inherited Create;
  FBytes := Copy( ABytes );
end;

function TBytesVirtualStream.Seek(Offset, Origin: Integer): Integer;
begin
  case Origin of
    1: FPosition := FPosition + Offset;
    2: FPosition := Length( FBytes ) + Offset;
  else
    FPosition := Offset;
  end;
  Result := FPosition;
end;

function TBytesVirtualStream.Read(var Buffer; Size: Integer): Integer;
begin
  Result := Length( FBytes ) - FPosition;
  if Result > Size then
    Result := Size;
  if Result > 0 then
  begin
    Move( FBytes[ FPosition ], Buffer, Result );
    Inc( FPosition, Result );
  end
  else
    Result := 0;
end;

procedure TBytesVirtualStream.FileStatus(out FileDate, FileSize: Integer);
begin
  FileDate := 0;
  FileSize := Length( FBytes );
end;

{ TFakeInterceptor }

constructor TFakeInterceptor.Create(AOptions: TCompileInterceptOptions);
begin
  inherited Create;
  Options := AOptions;
end;

function TFakeInterceptor.GetOptions: TCompileInterceptOptions;
begin
  if RaiseOnEvent and ( Options = 0 ) then
    raise Exception.Create( 'GetOptions failed' );
  Result := Options;
end;

function TFakeInterceptor.GetVirtualFile(Filename: PWideChar): IVirtualStream;
begin
  Result := nil;
end;

function TFakeInterceptor.AlterFile(Filename: PWideChar; Content: PByte; FileDate, FileSize: Integer): IVirtualStream;
begin
  if RaiseOnEvent then
    raise Exception.Create( 'AlterFile failed' );
  SetLength( SeenContent, FileSize );
  if FileSize > 0 then
    Move( Content^, SeenContent[ 0 ], FileSize );
  if AlterTo <> nil then
    Result := TBytesVirtualStream.Create( AlterTo )
  else
    Result := nil;
end;

procedure TFakeInterceptor.InspectFilename(Filename: PWideChar; FileMode: TInspectFileMode);
begin
  if RaiseForeign then
    raise TForeignRaised.Create;
  if RaiseOnEvent then
    raise Exception.Create( 'InspectFilename failed' );
  Inc( InspectCount );
end;

function TFakeInterceptor.AlterMessage(IsCompilerMessage: Boolean; var MsgKind: TMsgKind; var Code: Integer;
  const Filename: IUnicodeString; var Line, Column: Integer; const Msg: IUnicodeString): Boolean;
begin
  if RaiseOnEvent then
    raise Exception.Create( 'AlterMessage failed' );
  Result := NewMessage <> '';
  if Result then
    Msg.Value := PWideChar( NewMessage );
end;

procedure TFakeInterceptor.CompileProject(ProjectFilename, UnitPaths, SourcePaths, DcuOutputDir: PWideChar;
  IsCodeInsight: Boolean; var Cancel: Boolean);
begin
  if RaiseOnEvent then
    raise Exception.Create( 'CompileProject failed' );
end;

function TFakeInterceptor.CreateVirtualFile(Filename: PWideChar; out Stream: IVirtualOutStream): Boolean;
begin
  Stream := nil;
  Result := False;
end;

function TFakeInterceptor.OpenVirtualFile(Filename: PWideChar; out Stream: IVirtualStream): Boolean;
begin
  Result := VirtualContent <> nil;
  if Result then
    Stream := TBytesVirtualStream.Create( VirtualContent )
  else
    Stream := nil;
end;

function TFakeInterceptor.FileNameDate(Filename: PWideChar; out AFileDate: Integer): Boolean;
begin
  AFileDate := 0;
  Result := False;
end;

{ TTestInterceptDispatch }

procedure TTestInterceptDispatch.TestRaisingInterceptorIsRemovedCompletely;
begin
  var Registry := TInterceptorRegistry.Create;
  try
    var Broken := TFakeInterceptor.Create( CIO_INSPECTFILENAMES );
    var BrokenIntf: ICompileInterceptor := Broken;
    var Healthy := TFakeInterceptor.Create( CIO_INSPECTFILENAMES );
    var HealthyIntf: ICompileInterceptor := Healthy;
    var HealthyId := Registry.Register( HealthyIntf );
    var BrokenId := Registry.Register( BrokenIntf );
    Broken.RaiseOnEvent := True;

    Registry.InspectFilename( 'Unit1.pas', ifmOpen );
    Assert.AreEqual( 1, Registry.Count, 'the raising interceptor is removed' );
    Assert.IsFalse( Registry.Unregister( BrokenId ), 'its id must no longer match anything' );

    Registry.InspectFilename( 'Unit2.pas', ifmOpen );
    Assert.AreEqual( 2, Healthy.InspectCount, 'the healthy interceptor still gets every event' );
    Assert.IsTrue( Registry.Unregister( HealthyId ) );
    Assert.AreEqual( 0, Registry.Count );
  finally
    Registry.Free;
  end;
end;

procedure TTestInterceptDispatch.TestNonNativeExceptionIsCaughtAndInterceptorRemoved;
begin
  var Registry := TInterceptorRegistry.Create;
  try
    var Foreign := TFakeInterceptor.Create( CIO_INSPECTFILENAMES );
    var ForeignIntf: ICompileInterceptor := Foreign;
    var Healthy := TFakeInterceptor.Create( CIO_INSPECTFILENAMES );
    var HealthyIntf: ICompileInterceptor := Healthy;
    Registry.Register( HealthyIntf );
    Registry.Register( ForeignIntf );
    Foreign.RaiseForeign := True;

    Assert.WillNotRaiseAny(
      procedure
      begin
        Registry.InspectFilename( 'Unit1.pas', ifmOpen );
      end );
    Assert.AreEqual( 1, Registry.Count, 'the interceptor that raised is removed' );
    Assert.AreEqual( 1, Healthy.InspectCount, 'the other interceptor still got the event' );
  finally
    Registry.Free;
  end;
end;

procedure TTestInterceptDispatch.TestRemovalUpdatesOptionCache;
begin
  var Registry := TInterceptorRegistry.Create;
  try
    var Broken := TFakeInterceptor.Create( CIO_ALTERMESSAGES );
    var BrokenIntf: ICompileInterceptor := Broken;
    var Other: ICompileInterceptor := TFakeInterceptor.Create( CIO_INSPECTFILENAMES );
    Registry.Register( Other );
    Registry.Register( BrokenIntf );
    Broken.RaiseOnEvent := True;
    Assert.IsTrue( Registry.HasOption( CIO_ALTERMESSAGES ) );

    var Kind := mkWarning;
    var Code := 1;
    var Line := 1;
    var Column := 1;
    var FileName: UTF8String := 'Unit1.pas';
    var Msg: UTF8String := 'W1000';
    Registry.AlterMessage( False, Kind, Code, FileName, Line, Column, Msg );

    Assert.IsFalse( Registry.HasOption( CIO_ALTERMESSAGES ), 'the removed interceptor''s option is gone' );
    Assert.IsTrue( Registry.HasOption( CIO_INSPECTFILENAMES ), 'the remaining interceptor''s option stays' );
  finally
    Registry.Free;
  end;
end;

procedure TTestInterceptDispatch.TestOptionCacheCoversAllFlags;
begin
  var Registry := TInterceptorRegistry.Create;
  try
    var OutFiles: ICompileInterceptor := TFakeInterceptor.Create( CIO_VIRTUALOUTFILES );
    var Dates: ICompileInterceptor := TFakeInterceptor.Create( CIO_FILENAMEDATES );
    var OutId := Registry.Register( OutFiles );
    var DatesId := Registry.Register( Dates );
    Assert.IsTrue( Registry.HasOption( CIO_VIRTUALOUTFILES ), 'virtual out-files are cached on register' );
    Assert.IsTrue( Registry.HasOption( CIO_FILENAMEDATES ), 'file-name dates are cached on register' );
    Registry.Unregister( OutId );
    Registry.Unregister( DatesId );
    Assert.IsFalse( Registry.HasOption( CIO_VIRTUALOUTFILES ), 'virtual out-files are cleared on unregister' );
    Assert.IsFalse( Registry.HasOption( CIO_FILENAMEDATES ), 'file-name dates are cleared on unregister' );
  finally
    Registry.Free;
  end;
end;

procedure TTestInterceptDispatch.TestAlterMessageReturnsAlteredText;
begin
  var Registry := TInterceptorRegistry.Create;
  try
    var Fake := TFakeInterceptor.Create( CIO_ALTERMESSAGES );
    var FakeIntf: ICompileInterceptor := Fake;
    Fake.NewMessage := 'Altered text';
    Registry.Register( FakeIntf );

    var Kind := mkHint;
    var Code := 2;
    var Line := 3;
    var Column := 4;
    var FileName: UTF8String := 'C:\Src\Unit1.pas';
    var Msg: UTF8String := 'H2077 original';
    Assert.IsTrue( Registry.AlterMessage( True, Kind, Code, FileName, Line, Column, Msg ) );
    Assert.AreEqual( 'Altered text', UTF8ToString( Msg ) );
    Assert.AreEqual( 'C:\Src\Unit1.pas', UTF8ToString( FileName ) );
  finally
    Registry.Free;
  end;
end;

procedure TTestInterceptDispatch.TestAlterFileChainSeesWholeAlteredContent;
begin
  var Registry := TInterceptorRegistry.Create;
  try
    // Registered first = asked last
    var Second := TFakeInterceptor.Create( CIO_ALTERFILES );
    var SecondIntf: ICompileInterceptor := Second;
    var First := TFakeInterceptor.Create( CIO_ALTERFILES );
    var FirstIntf: ICompileInterceptor := First;
    First.AlterTo := BytesOf( 'unit Generated; interface implementation end.' );
    Registry.Register( SecondIntf );
    Registry.Register( FirstIntf );

    // The original file is empty, so any buffer sized to it has no room for the altered content
    var Altered := Registry.AlterFile( 'Generated.pas', nil, 0, 0 );
    Assert.IsNotNull( Altered );
    Assert.AreEqual( 'unit Generated; interface implementation end.', TEncoding.UTF8.GetString( Second.SeenContent ) );
  finally
    Registry.Free;
  end;
end;

procedure TTestInterceptDispatch.TestNewestInterceptorAnswersFirst;
begin
  var Registry := TInterceptorRegistry.Create;
  try
    var Older := TFakeInterceptor.Create( CIO_VIRTUALFILES );
    var OlderIntf: ICompileInterceptor := Older;
    Older.VirtualContent := BytesOf( 'older' );
    var Newer := TFakeInterceptor.Create( CIO_VIRTUALFILES );
    var NewerIntf: ICompileInterceptor := Newer;
    Newer.VirtualContent := BytesOf( 'newer' );
    Registry.Register( OlderIntf );
    Registry.Register( NewerIntf );

    var Stream: IVirtualStream;
    Assert.IsTrue( Registry.OpenVirtualFile( 'Unit1.pas', Stream ) );
    var Buf: TBytes;
    SetLength( Buf, 5 );
    Assert.AreEqual( 5, Stream.Read( Buf[ 0 ], 5 ) );
    Assert.AreEqual( 'newer', TEncoding.UTF8.GetString( Buf ) );
  finally
    Registry.Free;
  end;
end;

procedure TTestInterceptDispatch.TestRegisterRefusesNilAndBroken;
begin
  var Registry := TInterceptorRegistry.Create;
  try
    Assert.AreEqual( -1, Registry.Register( nil ) );
    var Broken := TFakeInterceptor.Create( 0 );
    var BrokenIntf: ICompileInterceptor := Broken;
    Broken.RaiseOnEvent := True; // with Options = 0, GetOptions raises
    Assert.AreEqual( -1, Registry.Register( BrokenIntf ) );
    Assert.AreEqual( 0, Registry.Count );
  finally
    Registry.Free;
  end;
end;

procedure TTestInterceptDispatch.TestUnregisterUnknownIdIsHarmless;
begin
  var Registry := TInterceptorRegistry.Create;
  try
    var Fake: ICompileInterceptor := TFakeInterceptor.Create( CIO_INSPECTFILENAMES );
    Registry.Register( Fake );
    Assert.IsFalse( Registry.Unregister( 999 ) );
    Assert.IsFalse( Registry.Unregister( 0 ) );
    Assert.AreEqual( 1, Registry.Count );
  finally
    Registry.Free;
  end;
end;

procedure TTestInterceptDispatch.TestCombineSearchPaths(const ProjectPaths, GlobalPaths, Expected: string);
begin
  Assert.AreEqual( Expected, CombineSearchPaths( ProjectPaths, GlobalPaths ) );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestInterceptDispatch );

end.
