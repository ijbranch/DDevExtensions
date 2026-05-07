{******************************************************************************}
{*                                                                            *}
{* CompileInterceptor IDE Plugin                                              *}
{*                                                                            *}
{* (C) 2006-2009 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}
{$A+,B-,C+,D+,E-,F-,G+,H+,I+,J-,K-,L+,M-,N-,O+,P+,Q-,R-,S-,T-,U-,V+,W-,X+,Y+,Z1}

unit FileStreams;

/// <summary>
/// Stream classes used by the CompileInterceptor to feed the Delphi compiler with file contents
/// while transparently injecting prologue text, decoding UTF/UCS BOMs and pooling write buffers
/// for large in-memory caches.
/// </summary>

interface

uses
  Windows, SysUtils, Classes, Contnrs;

const
  /// <summary>Maximum number of idle write buffers to keep cached in TBufferPool before freeing extras.</summary>
  MaxWriteAvgBufferCount = 5;
  /// <summary>Maximum number of idle read buffers to keep cached in TBufferPool before freeing extras.</summary>
  MaxReadAvgBufferCount = 3;
  /// <summary>Disk sector size used to align buffered writes for optimal I/O throughput.</summary>
  DISK_SECTOR_SIZE = 512;
  /// <summary>Size of each pooled write buffer, in bytes.</summary>
  MaxWritePoolBufferSize = DISK_SECTOR_SIZE * 256;
  /// <summary>Size of each pooled read buffer, in bytes.</summary>
  MaxReadPoolBufferSize = DISK_SECTOR_SIZE * 24;

type
  {$IFNDEF UNICODE}
  /// <summary>Pre-Unicode alias for AnsiString.</summary>
  RawByteString = AnsiString;
  /// <summary>Pre-Unicode alias for WideString.</summary>
  UnicodeString = WideString;
  {$ENDIF ~UNICODE}

  /// <summary>
  /// Pool of fixed-size virtual-memory buffers that amortises allocation cost across the many
  /// short-lived buffered streams created during a compile. Buffers are reused while the pool is
  /// short of MaxWriteAvgBufferCount/MaxReadAvgBufferCount idle entries; surplus buffers are
  /// returned to the OS via VirtualFree.
  /// </summary>
  TBufferPool = class(TObject)
  private
    /// <summary>Allocated write buffers (PByteArray) or nil for slots that have been freed.</summary>
    FWriteBuffers: TList;
    /// <summary>Per-write-buffer locked/unlocked flag (Pointer(1) = locked, nil = free).</summary>
    FWriteBufferState: TList;
    /// <summary>Allocated read buffers (PByteArray) or nil for slots that have been freed.</summary>
    FReadBuffers: TList;
    /// <summary>Per-read-buffer locked/unlocked flag.</summary>
    FReadBufferState: TList;
  public
    /// <summary>Initialises the empty pool.</summary>
    constructor Create;
    /// <summary>Frees all pooled buffers via VirtualFree.</summary>
    destructor Destroy; override;

    /// <summary>Acquires an idle write buffer, allocating a fresh one when the pool is empty.</summary>
    /// <returns>Pointer to a buffer of size MaxWritePoolBufferSize.</returns>
    function AllocWrite: PByteArray;
    /// <summary>Returns a write buffer to the pool, freeing it when the idle count exceeds the cap.</summary>
    /// <param name="P">Buffer obtained from AllocWrite.</param>
    procedure ReleaseWrite(P: PByteArray);
    /// <summary>Acquires an idle read buffer, allocating a fresh one when the pool is empty.</summary>
    /// <returns>Pointer to a buffer of size MaxReadPoolBufferSize.</returns>
    function AllocRead: PByteArray;
    /// <summary>Returns a read buffer to the pool, freeing it when the idle count exceeds the cap.</summary>
    /// <param name="P">Buffer obtained from AllocRead.</param>
    procedure ReleaseRead(P: PByteArray);
  end;

  /// <summary>Identifier for the byte-order mark detected at the start of a stream.</summary>
  TBOMType = (bomAnsi, bomUtf8, bomUcs2BE, bomUcs2LE, bomUcs4BE, bomUcs4LE);
  /// <summary>Buffer used to capture the first four bytes of a stream during BOM detection.</summary>
  TBOMArray = array[0..3] of Byte;

  /// <summary>Pointer to a TOrgStreamData record.</summary>
  POrgStreamData = ^TOrgStreamData;
  /// <summary>
  /// Set of function pointers exposed by the IDE's compiler that allow the interceptor to delegate
  /// file I/O back to the original implementation when wrapping handles in TOrgStream.
  /// </summary>
  TOrgStreamData = record
    /// <summary>Original file-open routine.</summary>
    Open: function(const Filename: PAnsiChar): THandle; pascal;
    /// <summary>Original seek routine.</summary>
    Seek: function(hFile: THandle; Offset, Origin: Integer): Integer; pascal;
    /// <summary>Original read routine.</summary>
    Read: function(hFile: THandle; Buffer: PByte; Size: Cardinal): Integer; pascal;
    /// <summary>Original write routine.</summary>
    Write: function(hFile: THandle; Buffer: PByte; Size: Cardinal): Integer; pascal;
    /// <summary>Original status routine returning the file's modification date and size.</summary>
    FileStatus: function(hFile: THandle; out FileDate: Integer; out FileSize: Integer): Integer; pascal;
  end;

  /// <summary>TStream wrapper around a Win32 file handle that optionally delegates to an original IDE routine set.</summary>
  TOrgStream = class(TStream)
  private
    /// <summary>Underlying Win32 file handle.</summary>
    FHandle: THandle;
    /// <summary>Optional pointer to original IDE I/O routines; nil routes to the default Delphi RTL helpers.</summary>
    FOrgStreamData: POrgStreamData;
  protected
    /// <summary>Truncates the stream to NewSize using either the IDE routines or SetEndOfFile.</summary>
    /// <param name="NewSize">Required size, in bytes.</param>
    procedure SetSize(NewSize: Longint); override;
    {$IFDEF COMPILER6_UP}
    /// <summary>Int64 overload of SetSize for Delphi 6+.</summary>
    /// <param name="NewSize">Required size, in bytes.</param>
    procedure SetSize(const NewSize: Int64); override;
    {$ENDIF COMPILER6_UP}
  public
    /// <summary>Wraps an existing handle. Ownership is not transferred.</summary>
    /// <param name="AHandle">Open file handle.</param>
    /// <param name="AOrgStreamData">Optional original-routine table.</param>
    constructor Create(AHandle: THandle; AOrgStreamData: POrgStreamData = nil);

    /// <summary>Reads up to Count bytes from the underlying handle.</summary>
    function Read(var Buffer; Count: Integer): Integer; override;
    /// <summary>Writes up to Count bytes to the underlying handle.</summary>
    function Write(const Buffer; Count: Integer): Integer; override;
    {$IFDEF COMPILER6_UP}
    /// <summary>Seeks within the underlying handle (Delphi 6+ Int64 overload).</summary>
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    {$ELSE}
    /// <summary>Seeks within the underlying handle (legacy Longint overload).</summary>
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    {$ENDIF COMPILER6_UP}

    /// <summary>Underlying file handle.</summary>
    property Handle: THandle read FHandle;
  end;

  /// <summary>
  /// Sector-aligned write buffer that batches small writes into MaxWritePoolBufferSize chunks
  /// before flushing to the wrapped stream. Designed to be the only writer for the wrapped stream.
  /// </summary>
  TBufferedWriteStream = class(TStream)
  private
    /// <summary>Number of bytes currently held in FBuffer.</summary>
    FBufSize: Cardinal;
    /// <summary>Pooled write buffer.</summary>
    FBuffer: PByteArray;
    /// <summary>Offset within FBuffer at which valid data starts (used for sector alignment).</summary>
    FBufStart: Cardinal;
    /// <summary>True when FBufStart needs recalculation from the wrapped stream's position.</summary>
    FCalcBufStart: Boolean;
    /// <summary>Wrapped destination stream.</summary>
    FStream: TStream;
    /// <summary>True when the wrapped stream is owned and freed by this instance.</summary>
    FOwnsStream: Boolean;
  protected
    /// <summary>Flushes pending writes and resizes the wrapped stream.</summary>
    procedure SetSize(NewSize: Longint); override;
    {$IFDEF COMPILER6_UP}
    /// <summary>Int64 overload of SetSize.</summary>
    procedure SetSize(const NewSize: Int64); override;
    {$ENDIF COMPILER6_UP}
  public
    /// <summary>Wraps a file handle behind a fresh TOrgStream.</summary>
    /// <param name="AHandle">Open file handle.</param>
    /// <param name="AOrgStreamData">Optional original-routine table.</param>
    constructor Create(AHandle: THandle; AOrgStreamData: POrgStreamData = nil); overload;
    /// <summary>Wraps an existing TStream.</summary>
    /// <param name="AStream">Destination stream.</param>
    /// <param name="AOwnsStream">When True, AStream is freed by this instance.</param>
    constructor Create(AStream: TStream; AOwnsStream: Boolean = True); overload;
    /// <summary>Flushes pending writes, releases the buffer and (optionally) frees the wrapped stream.</summary>
    destructor Destroy; override;
    /// <summary>Flushes the buffer and reads from the wrapped stream.</summary>
    function Read(var Buffer; Count: Longint): Longint; override;
    /// <summary>Buffers Count bytes; flushes automatically when the buffer fills up.</summary>
    function Write(const Buffer; Count: Longint): Longint; override;
    {$IFDEF COMPILER6_UP}
    /// <summary>Seeks within the wrapped stream, flushing the buffer as needed.</summary>
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    {$ELSE}
    /// <summary>Seeks within the wrapped stream (legacy overload).</summary>
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    {$ENDIF COMPILER6_UP}
    /// <summary>Writes any buffered bytes to the wrapped stream and resets the buffer.</summary>
    procedure Flush;

    /// <summary>Underlying destination stream.</summary>
    property Stream: TStream read FStream write FStream;
    /// <summary>Whether the wrapped stream is freed by this instance.</summary>
    property OwnsStream: Boolean read FOwnsStream write FOwnsStream;
  end;

  /// <summary>
  /// Stream that prepends an arbitrary block of bytes ("inject data") to the contents of a file
  /// handle. Detects the file's BOM, transcodes UCS2/UCS4 source to UTF-8 so the Delphi compiler
  /// can read it, and exposes the resulting view as a single read-only stream.
  /// </summary>
  TInjectStream = class(TOrgStream)
  private
    /// <summary>Bytes prepended to the file contents (after BOM normalisation).</summary>
    FInjectData: RawByteString;
    /// <summary>Logical position within the combined inject + file stream.</summary>
    FVirtualPosition: Int64;
    /// <summary>True while the constructor is reading the underlying file for BOM detection.</summary>
    FLoading: Boolean;
    /// <summary>Length of the UTF-8 conversion result when the source was transcoded; 0 otherwise.</summary>
    FUtfConversionSize: Integer;
    /// <summary>Length of the BOM detected at the start of the file.</summary>
    FBOMLen: Integer;
    /// <summary>Bytes captured during BOM detection.</summary>
    FBOM: TBOMArray;
    /// <summary>Detected BOM type.</summary>
    FBOMType: TBOMType;
  protected
    /// <summary>Always raises; injecting streams are read-only.</summary>
    procedure SetSize(NewSize: Longint); override;
    {$IFDEF COMPILER6_UP}
    /// <summary>Always raises; injecting streams are read-only.</summary>
    procedure SetSize(const NewSize: Int64); override;
    {$ENDIF COMPILER6_UP}
  public
    /// <summary>Creates the stream and decodes the BOM, transcoding the file payload when necessary.</summary>
    /// <param name="AHandle">Open file handle.</param>
    /// <param name="AInjectData">Bytes to prepend to the file contents.</param>
    /// <param name="AOrgStreamData">Optional original-routine table.</param>
    constructor Create(AHandle: THandle; const AInjectData: RawByteString; AOrgStreamData: POrgStreamData = nil);
    /// <summary>Reads from the inject buffer and then transparently from the underlying file.</summary>
    function Read(var Buffer; Count: Longint): Longint; override;
    /// <summary>Always raises EAbort; the stream is read-only.</summary>
    function Write(const Buffer; Count: Longint): Longint; override;
    {$IFDEF COMPILER6_UP}
    /// <summary>Seeks within the combined view of inject buffer and underlying file.</summary>
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    {$ELSE}
    /// <summary>Seeks within the combined view (legacy overload).</summary>
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    {$ENDIF COMPILER6_UP}

    /// <summary>Length of the UTF-8 conversion result when the source had a UCS2/UCS4 BOM.</summary>
    property UtfConversionSize: Integer read FUtfConversionSize;
    /// <summary>Bytes prepended to the file contents (after BOM normalisation).</summary>
    property InjectData: RawByteString read FInjectData;
  end;

  /// <summary>Forward declaration; defined below.</summary>
  TFileCache = class;

  /// <summary>Read-only stream view over a TFileCache that supports independent positions per reader.</summary>
  TFileCacheReaderStream = class(TStream)
  private
    /// <summary>Owning cache providing the backing buffer.</summary>
    FFileCache: TFileCache;
    /// <summary>Current read position within the cache.</summary>
    FPosition: Integer;
  protected
    /// <summary>Always raises; reader streams are read-only.</summary>
    procedure SetSize(NewSize: Longint); override;
    {$IFDEF COMPILER6_UP}
    /// <summary>Always raises; reader streams are read-only.</summary>
    procedure SetSize(const NewSize: Int64); override;
    {$ENDIF COMPILER6_UP}
  public
    /// <summary>Custom allocator that uses GetMem for direct instances to avoid GetMemoryManager overhead.</summary>
    class function NewInstance: TObject; override;
    /// <summary>Custom deallocator paired with NewInstance.</summary>
    procedure FreeInstance; override;
    /// <summary>Registers the reader with the file cache.</summary>
    /// <param name="AFileCache">Cache providing the data.</param>
    constructor Create(AFileCache: TFileCache);
    /// <summary>Removes the reader from the cache's reader list.</summary>
    destructor Destroy; override;
    /// <summary>Reads up to Count bytes from the cache.</summary>
    function Read(var Buffer; Count: Longint): Longint; override;
    /// <summary>Always raises EAbort; the stream is read-only.</summary>
    function Write(const Buffer; Count: Longint): Longint; override;
    {$IFDEF COMPILER6_UP}
    /// <summary>Adjusts the reader's position within the cache.</summary>
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    {$ELSE}
    /// <summary>Adjusts the reader's position within the cache (legacy overload).</summary>
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    {$ENDIF COMPILER6_UP}

    /// <summary>Owning cache.</summary>
    property FileCache: TFileCache read FFileCache;
  end;

  /// <summary>
  /// In-memory cache of an entire file or stream. Multiple TFileCacheReaderStream instances can
  /// then read concurrently from the same backing buffer, each maintaining its own position.
  /// </summary>
  TFileCache = class(TObject)
  private
    /// <summary>Heap-allocated buffer holding the cached contents.</summary>
    FBuffer: PByteArray;
    /// <summary>Length of FBuffer in bytes.</summary>
    FSize: Integer;
    /// <summary>List of currently registered TFileCacheReaderStream instances.</summary>
    FReaders: TObjectList;
    /// <summary>Returns the reader at the specified index.</summary>
    function GetReader(Index: Integer): TFileCacheReaderStream;
    /// <summary>Returns the number of currently registered readers.</summary>
    function GetReaderCount: Integer;
  public
    /// <summary>Custom allocator analogous to TFileCacheReaderStream.NewInstance.</summary>
    class function NewInstance: TObject; override;
    /// <summary>Custom deallocator paired with NewInstance.</summary>
    procedure FreeInstance; override;
    /// <summary>Loads the entire file into memory using a TInjectStream for BOM normalisation.</summary>
    /// <param name="hFile">Open file handle.</param>
    /// <param name="AOrgStreamData">Optional original-routine table.</param>
    constructor Create(hFile: THandle; AOrgStreamData: POrgStreamData = nil); overload;
    /// <summary>Loads ASize bytes from the file (use -1 to read all).</summary>
    /// <param name="hFile">Open file handle.</param>
    /// <param name="ASize">Number of bytes to load, or -1 to read until end-of-file.</param>
    /// <param name="AOrgStreamData">Optional original-routine table.</param>
    constructor Create(hFile: THandle; ASize: Integer; AOrgStreamData: POrgStreamData = nil); overload;
    /// <summary>Copies the entire contents of AStream into the cache.</summary>
    /// <param name="AStream">Source stream.</param>
    constructor Create(AStream: TStream); overload;
    /// <summary>Frees the buffer and registered reader list.</summary>
    destructor Destroy; override;

    /// <summary>Creates and registers a new reader stream over the cached contents.</summary>
    /// <returns>The newly-created reader.</returns>
    function NewReader: TFileCacheReaderStream;

    /// <summary>Length of the cached buffer in bytes.</summary>
    property Size: Integer read FSize;
    /// <summary>Pointer to the cached buffer.</summary>
    property Buffer: PByteArray read FBuffer;
    /// <summary>Number of currently registered readers.</summary>
    property ReaderCount: Integer read GetReaderCount;
    /// <summary>Indexed accessor for registered readers.</summary>
    property Readers[Index: Integer]: TFileCacheReaderStream read GetReader; default;
  end;

  /// <summary>Read-only stream view over a caller-supplied byte buffer (no ownership).</summary>
  TBufferStream = class(TStream)
  private
    /// <summary>Caller-supplied buffer.</summary>
    FBuffer: PByteArray;
    /// <summary>Length of FBuffer in bytes.</summary>
    FSize: Integer;
    /// <summary>Current read position.</summary>
    FPosition: Integer;
  protected
    /// <summary>Always raises; the stream is read-only.</summary>
    procedure SetSize(NewSize: Longint); override;
    /// <summary>Always raises; the stream is read-only.</summary>
    procedure SetSize(const NewSize: Int64); override;
  public
    /// <summary>Wraps a buffer for reading.</summary>
    /// <param name="ABuffer">Byte buffer.</param>
    /// <param name="ASize">Number of valid bytes in ABuffer.</param>
    constructor Create(ABuffer: PByteArray; ASize: Integer);
    /// <summary>Reads up to Count bytes from the buffer.</summary>
    function Read(var Buffer; Count: Longint): Longint; override;
    /// <summary>Always raises EAbort; the stream is read-only.</summary>
    function Write(const Buffer; Count: Longint): Longint; override;
    /// <summary>Repositions the read cursor within the buffer.</summary>
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

  /// <summary>TBufferStream that owns its underlying RawByteString contents for the lifetime of the stream.</summary>
  TRawByteStringStream = class(TBufferStream)
  private
    /// <summary>Owned source data.</summary>
    FData: RawByteString;
  public
    /// <summary>Wraps the supplied RawByteString.</summary>
    /// <param name="AData">Source bytes; copied into FData and exposed via the inherited buffer.</param>
    constructor Create(const AData: RawByteString);
  end;

  /// <summary>
  /// File stream with an internal MaxReadPoolBufferSize buffer for fast sequential reads. Inherits
  /// the underlying handle from TFileStream but bypasses TFileStream.Seek/Read for buffered I/O.
  /// </summary>
  TBufferedReadStream = class(TFileStream)
  private
    /// <summary>FBufSize: bytes valid in FBuffer; FBufPos: current position within FBuffer.</summary>
    FBufSize, FBufPos: Integer;
    /// <summary>Pooled read buffer.</summary>
    FBuffer: PByteArray;
    /// <summary>Logical file position.</summary>
    FPosition: Int64;
    /// <summary>Cached file size; -1 until first computed.</summary>
    FSize: Int64;
    /// <summary>True when the logical position has reached or passed end-of-file.</summary>
    function GetEof: Boolean;
  protected
    /// <summary>Always raises; the stream is read-only.</summary>
    procedure SetSize(NewSize: Longint); override;
    /// <summary>Always raises; the stream is read-only.</summary>
    procedure SetSize(const NewSize: Int64); override;
  public
    /// <summary>Opens Filename for shared reading.</summary>
    /// <param name="Filename">Path to open.</param>
    constructor Create(const Filename: string);
    /// <summary>Releases the pooled buffer and closes the underlying file.</summary>
    destructor Destroy; override;
    /// <summary>Reads up to Count bytes, refilling the internal buffer as needed.</summary>
    function Read(var Buffer; Count: Longint): Longint; override;
    /// <summary>Always raises EAbort; the stream is read-only.</summary>
    function Write(const Buffer; Count: Longint): Longint; override;
    /// <summary>Repositions the cursor; the buffer is invalidated unless the seek stays within it.</summary>
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    /// <summary>Always raises; the stream is read-only.</summary>
    procedure Flush;

    /// <summary>Current logical file position.</summary>
    property FilePos: Int64 read FPosition;
    /// <summary>True when the cursor is at end-of-file.</summary>
    property Eof: Boolean read GetEof;
  end;

var
  /// <summary>Process-wide buffer pool used by TBufferedWriteStream and TBufferedReadStream when assigned.</summary>
  BufferPool: TBufferPool;

/// <summary>Reads up to four bytes from Stream and identifies the byte-order mark, if any.</summary>
/// <param name="Stream">Source stream.</param>
/// <param name="BOMLen">Receives the number of BOM bytes consumed.</param>
/// <param name="BOM">Receives the captured bytes (always four entries).</param>
/// <returns>Detected BOM type (bomAnsi when no BOM was found).</returns>
function ReadBOM(Stream: TStream; out BOMLen: Integer; var BOM: TBOMArray): TBOMType;
/// <summary>Reads the remainder of Stream as UCS-2, swapping bytes when BOMType is big-endian, and prepends ExtraData.</summary>
/// <param name="Stream">Source stream positioned after the BOM.</param>
/// <param name="BOMType">BOM type returned from ReadBOM.</param>
/// <param name="ExtraData">Bytes to prepend to the result.</param>
/// <returns>Decoded text.</returns>
function ReadAllFileUcs2(Stream: TStream; BOMType: TBOMType; ExtraData: string): string;
/// <summary>Reads the remainder of Stream as UCS-4, swapping bytes when BOMType is big-endian.</summary>
/// <param name="Stream">Source stream positioned after the BOM.</param>
/// <param name="BOMType">BOM type returned from ReadBOM.</param>
/// <returns>Decoded UCS4 string.</returns>
function ReadAllFileUcs4(Stream: TStream; BOMType: TBOMType): UCS4String;

implementation

resourcestring
  RsNotSupported = 'Operation "%s" not supported';

{ TBufferPool }

constructor TBufferPool.Create;
begin
  inherited Create;
  FWriteBuffers := TList.Create;
  FWriteBufferState := TList.Create;
  FReadBuffers := TList.Create;
  FReadBufferState := TList.Create;
end;

destructor TBufferPool.Destroy;
var
  I: Integer;
begin
  for I := 0 to FWriteBuffers.Count - 1 do
    if FWriteBuffers[I] <> nil then
      VirtualFree(FWriteBuffers[I], MaxWritePoolBufferSize, MEM_FREE);
  FWriteBuffers.Free;
  FWriteBufferState.Free;
  for I := 0 to FReadBuffers.Count - 1 do
    if FReadBuffers[I] <> nil then
      VirtualFree(FReadBuffers[I], MaxReadPoolBufferSize, MEM_FREE);
  FReadBuffers.Free;
  FReadBufferState.Free;
  inherited Destroy;
end;

function TBufferPool.AllocWrite: PByteArray;
var
  I: Integer;
begin
  for I := 0 to FWriteBufferState.Count - 1 do
  begin
    if FWriteBufferState[I] = nil then // unlocked
    begin
      FWriteBufferState[I] := Pointer(1); // locked
      Result := FWriteBuffers[I];
      Exit;
    end;
  end;
  Result := VirtualAlloc(nil, MaxWritePoolBufferSize, MEM_COMMIT, PAGE_READWRITE);
  FWriteBufferState.Add(Pointer(1));
  FWriteBuffers.Add(Result);
end;

procedure TBufferPool.ReleaseWrite(P: PByteArray);
var
  I: Integer;
begin
  for I := 0 to FWriteBufferState.Count - 1 do
  begin
    if FWriteBuffers[I] = P then
    begin
      FWriteBufferState[I] := nil;
      Break;
    end;
  end;
  if FWriteBuffers.Count > MaxWriteAvgBufferCount then
  begin
    for I := FWriteBufferState.Count - 1 downto 0 do
    begin
      if FWriteBufferState[I] = nil then
      begin
        VirtualFree(FWriteBuffers[I], MaxWritePoolBufferSize, MEM_FREE);
        FWriteBuffers.Delete(I);
        FWriteBufferState.Delete(I);
        if FWriteBuffers.Count = MaxWriteAvgBufferCount then
          Break;
      end;
    end;
  end;
end;

function TBufferPool.AllocRead: PByteArray;
var
  I: Integer;
begin
  for I := 0 to FReadBufferState.Count - 1 do
  begin
    if FReadBufferState[I] = nil then // unlocked
    begin
      FReadBufferState[I] := Pointer(1); // locked
      Result := FReadBuffers[I];
      Exit;
    end;
  end;
  Result := VirtualAlloc(nil, MaxReadPoolBufferSize, MEM_COMMIT, PAGE_READWRITE);
  FReadBufferState.Add(Pointer(1));
  FReadBuffers.Add(Result);
end;

procedure TBufferPool.ReleaseRead(P: PByteArray);
var
  I: Integer;
begin
  for I := 0 to FReadBufferState.Count - 1 do
  begin
    if FReadBuffers[I] = P then
    begin
      FReadBufferState[I] := nil;
      Break;
    end;
  end;
  if FReadBuffers.Count > MaxReadAvgBufferCount then
  begin
    for I := FReadBufferState.Count - 1 downto 0 do
    begin
      if FReadBufferState[I] = nil then
      begin
        VirtualFree(FReadBuffers[I], MaxReadPoolBufferSize, MEM_FREE);
        FReadBuffers.Delete(I);
        FReadBufferState.Delete(I);
        if FReadBuffers.Count = MaxReadAvgBufferCount then
          Break;
      end;
    end;
  end;
end;

{ TBufferedWriteStream }

constructor TBufferedWriteStream.Create(AHandle: THandle; AOrgStreamData: POrgStreamData);
begin
  Create(TOrgStream.Create(AHandle, AOrgStreamData));
end;

constructor TBufferedWriteStream.Create(AStream: TStream; AOwnsStream: Boolean);
begin
  inherited Create;
  FStream := AStream;
  FOwnsStream := AOwnsStream;

  if BufferPool = nil then
    GetMem(FBuffer, MaxWritePoolBufferSize)
  else
    FBuffer := BufferPool.AllocWrite;
end;

destructor TBufferedWriteStream.Destroy;
begin
  Flush;
  if BufferPool = nil then
    FreeMem(FBuffer)
  else
    BufferPool.ReleaseWrite(FBuffer);
  if FOwnsStream then
    FStream.Free;
  inherited Destroy;
end;

procedure TBufferedWriteStream.Flush;
var
  Count: Cardinal;
begin
  Count := FBufSize - FBufStart;
  if Count > 0 then
    Stream.Write(FBuffer[FBufStart], Count);
  FBufSize := 0;
  FBufStart := 0;
  FCalcBufStart := False;
end;

function TBufferedWriteStream.Write(const Buffer; Count: Longint): Longint;
var
  P: PByte;
  Diff: Longint;
begin
  if FCalcBufStart then
  begin
    FCalcBufStart := False;
    FBufStart := Stream.Position and (DISK_SECTOR_SIZE - 1);
    FBufSize := FBufStart;
  end;

  P := @Buffer;
  Result := Count;
  if FBufSize + Cardinal(Count) > MaxWritePoolBufferSize then
  begin
    // Fill remaining Buffer bytes
    Diff := MaxWritePoolBufferSize - FBufSize;
    Move(P^, FBuffer[FBufSize], Diff);
    Dec(Count, Diff);
    Inc(P, Diff);
    FBufSize := MaxWritePoolBufferSize;
    Flush;
  end;

  if Count > MaxWritePoolBufferSize then
  begin
    // Buffer is too small, write as many blocks as possible
    Flush;

    Diff := Count mod MaxWritePoolBufferSize;
    Dec(Count, Diff);
    Stream.Write(P^, Count);
    Inc(P, Count);
    Count := Diff;
  end;

  if Count > 0 then
  begin
    // append data to Buffer
    Move(P^, FBuffer[FBufSize], Count);
    Inc(FBufSize, Count);
  end;
end;

function TBufferedWriteStream.Read(var Buffer; Count: Longint): Longint;
begin
  Flush;
  Result := Stream.Read(Buffer, Count);
  FCalcBufStart := True;
end;

{$IFDEF COMPILER6_UP}
function TBufferedWriteStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
{$ELSE}
function TBufferedWriteStream.Seek(Offset: Longint; Origin: Word): Longint;
{$ENDIF COMPILER6_UP}
var
  StreamPos: Int64;
begin
  StreamPos := Stream.Position;
  if (Origin = {$IFDEF COMPILER6_UP}soCurrent{$ELSE}soFromCurrent{$ENDIF}) and (Offset = 0) then
    Result := StreamPos + FBufSize
  else
  if (Origin = {$IFDEF COMPILER6_UP}soBeginning{$ELSE}soFromBeginning{$ENDIF}) and (Offset = StreamPos + FBufSize) then
    Result := StreamPos + FBufSize
  else
  begin
    Flush;
    Result := Stream.Seek(Offset, Origin);

    { Align to next block }
    FBufStart := Result and (DISK_SECTOR_SIZE - 1);
    FBufSize := FBufStart;
    FCalcBufStart := False;
  end;
end;

procedure TBufferedWriteStream.SetSize(NewSize: Longint);
begin
  Flush;
  FCalcBufStart := True;
  Stream.Size := NewSize;
end;

{$IFDEF COMPILER6_UP}
procedure TBufferedWriteStream.SetSize(const NewSize: Int64);
begin
  Flush;
  FCalcBufStart := True;
  Stream.Size := NewSize;
end;
{$ENDIF COMPILER6_UP}

{ TOrgStream }

constructor TOrgStream.Create(AHandle: THandle; AOrgStreamData: POrgStreamData);
begin
  inherited Create;
  FHandle := AHandle;
  FOrgStreamData := AOrgStreamData;
end;

procedure TOrgStream.SetSize(NewSize: Longint);
begin
  {$IFDEF COMPILER6_UP}
  SetSize(Int64(NewSize));
  {$ELSE}
  Seek(NewSize, soFromBeginning);
  if FOrgStreamData = nil then
    Win32Check(SetEndOfFile(FHandle));
  {$ENDIF COMPILER6_UP}
end;

{$IFDEF COMPILER6_UP}
procedure TOrgStream.SetSize(const NewSize: Int64);
begin
  Seek(NewSize, soBeginning);
  if FOrgStreamData = nil then
    {$WARNINGS OFF}
    Win32Check(SetEndOfFile(FHandle));
    {$WARNINGS ON}
end;
{$ENDIF COMPILER6_UP}

function TOrgStream.Read(var Buffer; Count: Integer): Integer;
begin
  if FHandle <> INVALID_HANDLE_VALUE then
  begin
    if FOrgStreamData = nil then
    begin
      Result := FileRead(FHandle, Buffer, Count);
      if Result = -1 then
        Result := 0;
    end
    else
      Result := FOrgStreamData.Read(FHandle, PByte(@Buffer), Count);
  end
  else
    Result := 0;
end;

function TOrgStream.Write(const Buffer; Count: Integer): Integer;
begin
  if FHandle <> INVALID_HANDLE_VALUE then
  begin
    if FOrgStreamData = nil then
    begin
      Result := FileWrite(FHandle, Buffer, Count);
      if Result = -1 then
        Result := 0;
    end
    else
      Result := FOrgStreamData.Write(FHandle, PByte(@Buffer), Count);
  end
  else
    Result := 0;
end;

{$IFDEF COMPILER6_UP}
function TOrgStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
{$ELSE}
function TOrgStream.Seek(Offset: Longint; Origin: Word): Longint;
{$ENDIF COMPILER6_UP}
begin
  if FHandle <> INVALID_HANDLE_VALUE then
  begin
    if FOrgStreamData = nil then
      Result := FileSeek(FHandle, Offset, Ord(Origin))
    else
      Result := FOrgStreamData.Seek(FHandle, Integer(Offset), Integer(Origin));
  end
  else
    Result := 0;
end;

function ReadBOM(Stream: TStream; out BOMLen: Integer; var BOM: TBOMArray): TBOMType;
begin
  // BOM detection
  BOM[2] := 0;
  BOM[3] := 0;
  Result := bomAnsi;
  BOMLen := Stream.Read(BOM, 2);
  if BOMLen = 2 then
  begin
    if (BOM[0] = $EF) and (BOM[1] = $BB) then
    begin
      Inc(BOMLen, Stream.Read(BOM[2], 1));
      if BOM[2] = $BF then
        Result := bomUtf8;
    end
    else if (BOM[0] = $FF) and (BOM[1] = $FE) then
    begin
      Inc(BOMLen, Stream.Read(BOM[2], 2));
      if (BOM[2] = 0) and (BOM[3] = 0) then
        Result := bomUcs4LE
      else
      begin
        Dec(BOMLen, 2);
        Stream.Seek(-2, soCurrent);
        Result := bomUcs2LE;
      end;
    end
    else if (BOM[0] = $FE) and (BOM[1] = $FF) then
    begin
      Result := bomUcs2BE;
    end
    else if (BOM[0] = 0) and (BOM[1] = 0) then
    begin
      Inc(BOMLen, Stream.Read(BOM[2], 2));
      if (BOM[2] = $FE) and (BOM[3] = $FF) then
        Result := bomUcs4BE;
    end;
  end;
end;

function ReadAllFileUcs2(Stream: TStream; BOMType: TBOMType; ExtraData: UnicodeString): UnicodeString;
const
  ReadCount = 64 * 1024;
var
  Len, Size: Integer;
  P: PWideChar;
begin
  Len := Length(ExtraData);
  SetLength(Result, ReadCount + Len);
  if Len > 0 then
    Move(ExtraData[1], Result[1], Len * SizeOf(WideChar));
  repeat
    Size := Stream.Read(PWideChar(PWideChar(Result) + Len)^, ReadCount * 2) div 2;
    Inc(Len, Size);
    SetLength(Result, Len);
  until Size <> ReadCount;

  if BOMType = bomUcs2BE then
  begin
    // swap bytes
    P := PWideChar(Result);
    while Len > 0 do
    begin
      P^ := WideChar((Word(P^) {and $00FF}) shl 8 or
                     (Word(P^) {and $FF00}) shr 8);
      Inc(P);
      Dec(Len);
    end;
  end;
end;

function ReadAllFileUcs4(Stream: TStream; BOMType: TBOMType): UCS4String;
const
  ReadCount = 64 * 1024;
var
  Len, Size: Integer;
  P: PUCS4Char;
begin
  SetLength(Result, ReadCount);
  Len := 0;
  repeat
    Size := Stream.Read(PAnsiChar(PAnsiChar(Result) + (Len * 4))^, ReadCount * 4) div 4;
    Inc(Len, Size);
    SetLength(Result, Len);
  until Size <> ReadCount;

  if BOMType = bomUcs4BE then
  begin
    // swap bytes
    P := PUCS4Chars(Result);
    while Len > 0 do
    begin
      P^ := UCS4Char((LongWord(P^) {and $000000FF}) shl 24 or
                     (LongWord(P^) and $0000FF00) shl 8 or
                     (LongWord(P^) and $00FF0000) shr 8 or
                     (LongWord(P^) {and $FF000000}) shr 24);
      Inc(P);
      Dec(Len);
    end;
  end;
end;

{ TInjectStream }

constructor TInjectStream.Create(AHandle: THandle; const AInjectData: RawByteString; AOrgStreamData: POrgStreamData);
var
  I: Integer;
  ExtraData: UnicodeString;
begin
  inherited Create(AHandle, AOrgStreamData);
  FInjectData := AInjectData;
  FLoading := True;

  // BOM detection
  ReadBOM(Self, FBOMLen, FBOM);

  // data conversion
  case FBOMType of
    bomAnsi:
      begin
        {$IFDEF UNICODE}
        SetCodePage(FInjectData, CP_ACP);
        {$ENDIF UNICODE}
        for I := 0 to FBOMLen - 1 do
          FInjectData := FInjectData + AnsiChar(FBOM[I]);
      end;
    bomUtf8:
      begin
        {$IFDEF UNICODE}
        SetCodePage(FInjectData, CP_UTF8);
        {$ELSE}
        FInjectData := AnsiToUtf8(FInjectData);
        {$ENDIF UNICODE}
        FInjectData := AnsiChar($EF) + AnsiChar($BB) + AnsiChar($BF) +
                       FInjectData;
      end;

    { The Compiler cannot handle these file types. So we convert them to UTF8 }
    bomUcs2BE, bomUcs2LE:
      begin
        {$IFDEF UNICODE}
        SetCodePage(FInjectData, CP_UTF8);
        {$ELSE}
        FInjectData := AnsiToUtf8(FInjectData);
        {$ENDIF UNICODE}
        FInjectData := AnsiChar($EF) + AnsiChar($BB) + AnsiChar($BF) +
                       FInjectData +
                       UTF8Encode(ReadAllFileUcs2(Self, FBOMType, ExtraData));
        FUtfConversionSize := Length(FInjectData);
      end;
    bomUcs4BE, bomUcs4LE:
      begin
        {$IFDEF UNICODE}
        SetCodePage(FInjectData, CP_UTF8);
        {$ELSE}
        FInjectData := AnsiToUtf8(FInjectData);
        {$ENDIF UNICODE}
        FInjectData := AnsiChar($EF) + AnsiChar($BB) + AnsiChar($BF) +
                       FInjectData +
                       UTF8Encode(
                         {$IFDEF UNICODE}
                         UCS4StringToUnicodeString
                         {$ELSE}
                         UCS4StringToWideString
                         {$ENDIF UNICODE}
                           (ReadAllFileUcs4(Self, FBOMType))
                       );
        FUtfConversionSize := Length(FInjectData);
      end;
  end;
  FLoading := False;
end;

function TInjectStream.Read(var Buffer; Count: Longint): Longint;
var
  P: PByte;
  Len: Integer;
begin
  if FLoading then
  begin
    Result := inherited Read(Buffer, Count);
    Exit;
  end;

  P := @Buffer;
  Result := 0;
  Len := Length(InjectData);

  if FVirtualPosition < Len then
  begin
    if FVirtualPosition + Count < Len then
    begin
      Move(InjectData[FVirtualPosition + 1], P^, Count);
      Result := Count;
    end
    else
    begin
      Move(InjectData[FVirtualPosition + 1], P^, Len - FVirtualPosition);
      Result := Len - FVirtualPosition;
    end;
    Inc(P, Result);
    Dec(Count, Result);
  end;

  if Count > 0 then
    Inc(Result, inherited Read(P^, Count));

  Inc(FVirtualPosition, Result);
end;

{$IFDEF COMPILER6_UP}
function TInjectStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
{$ELSE}
function TInjectStream.Seek(Offset: Longint; Origin: Word): Longint;
const
  soEnd = soFromEnd;
  soBeginning = soFromBeginning;
  soCurrent = soFromCurrent;
{$ENDIF COMPILER6_UP}
var
  RelPosition: Int64;
  Len: Integer;
begin
  if FLoading then
  begin
    Result := inherited Seek(Offset, Origin);
    Exit;
  end;

  Len := Length(InjectData);

  if Origin = soEnd then
  begin
    RelPosition := inherited Seek(Offset, soBeginning);
    FVirtualPosition := RelPosition + Len;
    Origin := soCurrent;
  end;

  RelPosition := Offset;
  case Origin of
    soBeginning:
      begin
        if RelPosition < 0 then
          RelPosition := 0
        else if RelPosition < Len then
          inherited Seek(0, soBeginning)
        else
        begin
          RelPosition := inherited Seek(Offset - Len, soBeginning);
          Inc(RelPosition, Len);
        end;
        FVirtualPosition := RelPosition;
      end;

    soCurrent:
      begin
        if FVirtualPosition + RelPosition < 0 then
          FVirtualPosition := 0
        else if FVirtualPosition + RelPosition < Len then
        begin
          inherited Seek(0, soBeginning);
          Inc(FVirtualPosition, RelPosition);
        end
        else
        begin
          RelPosition := inherited Seek(Offset, soCurrent);
          Inc(RelPosition, Len);
          FVirtualPosition := RelPosition;
        end;
      end;
  end;

  Result := FVirtualPosition;
end;

function TInjectStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise Exception.CreateFmt(RsNotSupported, ['Write']);
end;

procedure TInjectStream.SetSize(NewSize: Longint);
begin
  raise Exception.CreateFmt(RsNotSupported, ['SetSize']);
end;

{$IFDEF COMPILER6_UP}
procedure TInjectStream.SetSize(const NewSize: Int64);
begin
  raise Exception.CreateFmt(RsNotSupported, ['SetSize']);
end;
{$ENDIF COMPILER6_UP}

{ TFileCacheReaderStream }

class function TFileCacheReaderStream.NewInstance: TObject;
begin
  if Self = TFileCacheReaderStream then
  begin
    GetMem(Pointer(Result), InstanceSize);
    PInteger(Result)^ := Integer(Self);
  end
  else
    Result := inherited NewInstance;
end;

procedure TFileCacheReaderStream.FreeInstance;
begin
  if ClassType = TFileCacheReaderStream then
    FreeMem(Pointer(Self))
  else
    inherited FreeInstance;
end;

constructor TFileCacheReaderStream.Create(AFileCache: TFileCache);
begin
  FFileCache := AFileCache;
  FFileCache.FReaders.Add(Self);
  FPosition := 0;
end;

destructor TFileCacheReaderStream.Destroy;
begin
  FFileCache.FReaders.Extract(Self);
  inherited Destroy;
end;

function TFileCacheReaderStream.Read(var Buffer; Count: Longint): Longint;
begin
  if (FPosition >= 0) and (Count >= 0) then
  begin
    Result := FFileCache.Size - FPosition;
    if Result > 0 then
    begin
      if Result > Count then
        Result := Count;
      Move(FFileCache.FBuffer[FPosition], Buffer, Result);
      Inc(FPosition, Result);
      Exit;
    end;
  end;
  Result := 0;
end;

function TFileCacheReaderStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise Exception.CreateFmt(RsNotSupported, ['Write']);
end;

procedure TFileCacheReaderStream.SetSize(NewSize: Longint);
begin
  raise Exception.CreateFmt(RsNotSupported, ['SetSize']);
end;

{$IFDEF COMPILER6_UP}
procedure TFileCacheReaderStream.SetSize(const NewSize: Int64);
begin
  raise Exception.CreateFmt(RsNotSupported, ['SetSize']);
end;
{$ENDIF COMPILER6_UP}

{$IFDEF COMPILER6_UP}
function TFileCacheReaderStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
{$ELSE}
function TFileCacheReaderStream.Seek(Offset: Longint; Origin: Word): Longint;
const
  soEnd = soFromEnd;
  soBeginning = soFromBeginning;
  soCurrent = soFromCurrent;
{$ENDIF COMPILER6_UP}
begin
  case Origin of
    soBeginning:
      FPosition := Offset;
    soCurrent:
      Inc(FPosition, Offset);
    soEnd:
      FPosition := FFileCache.Size + Offset;
  end;
  if FPosition < 0 then
    FPosition := 0;
  if FPosition > FFileCache.Size then
    FPosition := FFileCache.Size;
  Result := FPosition;
end;

{ TFileCache }

class function TFileCache.NewInstance: TObject;
begin
  if Self = TFileCache then
  begin
    GetMem(Pointer(Result), InstanceSize);
    PInteger(Result)^ := Integer(Self);
  end
  else
    Result := inherited NewInstance;
end;

procedure TFileCache.FreeInstance;
begin
  if ClassType = TFileCache then
    FreeMem(Pointer(Self))
  else
    inherited FreeInstance;
end;

constructor TFileCache.Create(hFile: THandle; AOrgStreamData: POrgStreamData = nil);
begin
  Create(hFile, -1, AOrgStreamData);
end;

constructor TFileCache.Create(hFile: THandle; ASize: Integer; AOrgStreamData: POrgStreamData);
const
{$IFDEF CONSOLE}
  BufReadSize = 64 * 1024;
{$ELSE}
  // BCB 5, 6 abort with buffers larger than 16Kb if the file is opened in the editor
  BufReadSize = 15872; // The compiler uses this number of bytes for read operations.
{$ENDIF CONSOLE}
var
  n: Integer;
  Stream: TStream;
begin
  inherited Create;
  FSize := ASize;
  FReaders := TObjectList.Create;
  FReaders.Capacity := 10;

  if ASize = -1 then
  begin
    FBuffer := nil;
    Stream := TInjectStream.Create(hFile, '', AOrgStreamData); // UCS2 and UCS4 support
    try
      ASize := 0;
      repeat
        ReallocMem(FBuffer, ASize + BufReadSize);
        n := Stream.Read(FBuffer[ASize], BufReadSize);
        Inc(ASize, n);
        if ASize > 100 * 1024 * 1024 then // do not count on the IDE's FileRead implementation
        begin
          ASize := 0;
          Break;
        end;
      until n <> BufReadSize;
      ReallocMem(FBuffer, ASize);
    finally
      Stream.Free;
    end;
    FSize := ASize;
  end
  else
  begin
    Stream := TInjectStream.Create(hFile, '', AOrgStreamData); // UCS2 and UCS4 support
    try
      if TInjectStream(Stream).UtfConversionSize > 0 then
        FSize := TInjectStream(Stream).UtfConversionSize;
      if FSize > 0 then
      begin
        GetMem(FBuffer, FSize);
        Stream.Read(PByte(FBuffer)^, FSize);
      end;
    finally
      Stream.Free;
    end;
  end;
end;

constructor TFileCache.Create(AStream: TStream);
begin
  inherited Create;
  FReaders := TObjectList.Create;

  if AStream <> nil then
  begin
    FSize := AStream.Size;
    if FSize > 0 then
    begin
      GetMem(FBuffer, FSize);
      AStream.Read(FBuffer^, FSize);
    end;
  end;
end;

destructor TFileCache.Destroy;
begin
  if FBuffer <> nil then
    FreeMem(FBuffer);
  FReaders.Free;
  inherited Destroy;
end;

function TFileCache.GetReaderCount: Integer;
begin
  Result := FReaders.Count;
end;

function TFileCache.GetReader(Index: Integer): TFileCacheReaderStream;
begin
  Result := TFileCacheReaderStream(FReaders[Index]);
end;

function TFileCache.NewReader: TFileCacheReaderStream;
begin
  Result := TFileCacheReaderStream.Create(Self);
end;

{ TBufferStream }

constructor TBufferStream.Create(ABuffer: PByteArray; ASize: Integer);
begin
  inherited Create;
  FBuffer := ABuffer;
  FSize := ASize;
  FPosition := 0;
end;

function TBufferStream.Read(var Buffer; Count: Longint): Longint;
begin
  if (FPosition >= 0) and (Count >= 0) then
  begin
    Result := FSize - FPosition;
    if Result > 0 then
    begin
      if Result > Count then
        Result := Count;
      Move(FBuffer[FPosition], Buffer, Result);
      Inc(FPosition, Result);
      Exit;
    end;
  end;
  Result := 0;
end;

function TBufferStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise Exception.CreateFmt(RsNotSupported, ['Write']);
end;

procedure TBufferStream.SetSize(NewSize: Longint);
begin
  raise Exception.CreateFmt(RsNotSupported, ['SetSize']);
end;

procedure TBufferStream.SetSize(const NewSize: Int64);
begin
  raise Exception.CreateFmt(RsNotSupported, ['SetSize']);
end;

function TBufferStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:
      FPosition := Offset;
    soCurrent:
      Inc(FPosition, Offset);
    soEnd:
      FPosition := FSize + Offset;
  end;
  if FPosition < 0 then
    FPosition := 0;
  if FPosition > FSize then
    FPosition := FSize;
  Result := FPosition;
end;

{ TBufferedReadStream }

type
  PInt64 = ^TInt64;
  TInt64 = packed record
    Lo, Hi: Cardinal;
  end;

constructor TBufferedReadStream.Create(const Filename: string);
begin
  inherited Create(Filename, fmOpenRead or fmShareDenyWrite);
  FBuffer := BufferPool.AllocRead;
  FSize := -1;
  FBufPos := MaxReadPoolBufferSize;
  FBufSize := MaxReadPoolBufferSize;
end;

destructor TBufferedReadStream.Destroy;
begin
  BufferPool.ReleaseRead(FBuffer);
  inherited Destroy;
end;

procedure TBufferedReadStream.Flush;
begin
  raise Exception.CreateFmt(RsNotSupported, ['Flush']);
end;

function TBufferedReadStream.GetEof: Boolean;
begin
  if FSize = -1 then
    PInt64(@FSize).Lo := GetFileSize(FHandle, @TInt64(FSize).Hi);
  Result := FPosition >= FSize;
end;

function TBufferedReadStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise Exception.CreateFmt(RsNotSupported, ['Write']);
end;

function TBufferedReadStream.Read(var Buffer; Count: Longint): Longint;
type
  P3Bytes = ^T3Bytes;
  T3Bytes = packed record
    b: array[0..2] of Byte;
  end;
var
  FreeSize: Integer;
begin
  FreeSize := FBufSize - FBufPos;
  if FreeSize >= Count then
  begin
    Result := Count;
    case Count of
      0: Exit;
      1: PByteArray(@Buffer)[0] := FBuffer[FBufPos];
      2: PWordArray(@Buffer)[0] := PWordArray(@FBuffer[FBufPos])[0];
      4: PCardinal(@Buffer)^ := PCardinal(@FBuffer[FBufPos])^;
      8: PInt64(@Buffer)^ := PInt64(@FBuffer[FBufPos])^;
      3: P3Bytes(@Buffer)^ := P3Bytes(@FBuffer[FBufPos])^;
    else
      Move(FBuffer[FBufPos], Buffer, Count);
    end;
    Inc(FBufPos, Count);
    Inc(FPosition, Count);
    Exit;
  end;

  if FreeSize > 0 then
  begin
    Move(FBuffer[FBufPos], Buffer, FreeSize);
    Result := FreeSize;
    Inc(FPosition, FreeSize);
  end
  else
    Result := 0;

  if FBufSize < MaxReadPoolBufferSize then
    Exit; // Eof

  { Fill Buffer }
  FBufPos := 0;
  FBufSize := inherited Read(FBuffer[0], MaxReadPoolBufferSize);

  { Read remaining bytes }
  Inc(Result, Read(PByteArray(@Buffer)[Result], Count - Result));
end;

function TBufferedReadStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  if Origin = soCurrent then
  begin
    if (FBufPos + Offset >= 0) and (FBufPos + Offset < FBufSize) then
    begin
      Inc(FPosition, Offset);
      Inc(FBufPos, Offset);
      Result := FPosition;
    end
    else
    begin
      FBufPos := MaxReadPoolBufferSize;
      FBufSize := MaxReadPoolBufferSize; // discard buffer}
      Result := inherited Seek(FPosition + Offset, soBeginning);
      FPosition := Result;
    end;
  end
  else
  begin
    FBufPos := MaxReadPoolBufferSize;
    FBufSize := MaxReadPoolBufferSize; // discard buffer}
    Result := inherited Seek(Offset, Origin);
    FPosition := Result;
  end;
end;

procedure TBufferedReadStream.SetSize(NewSize: Longint);
begin
  raise Exception.CreateFmt(RsNotSupported, ['SetSize']);
end;

procedure TBufferedReadStream.SetSize(const NewSize: Int64);
begin
  raise Exception.CreateFmt(RsNotSupported, ['SetSize']);
end;

{ TRawByteStringStream }

constructor TRawByteStringStream.Create(const AData: RawByteString);
begin
  FData := AData;
  inherited Create(PByteArray(FData), Length(FData));
end;

end.
