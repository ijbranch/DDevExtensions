{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude Code                                           *}
{*                                                                            *}
{* FileWatcher - Lightweight ReadDirectoryChangesW wrapper                     *}
{* Zero external dependencies. Monitors directories for file modifications    *}
{* and notifies via callback on the main thread.                              *}
{*                                                                            *}
{* Inspired by VSoft.ExternalModDetector (Apache 2.0)                         *}
{*                                                                            *}
{******************************************************************************}

unit FileWatcher;

/// <summary>
/// Lightweight ReadDirectoryChangesW wrapper. Watches one or more directories for file
/// modifications and dispatches a callback on the main thread. Reference-counts each watched
/// directory so multiple subscribers can register the same path safely.
/// </summary>
/// <remarks>
/// The worker waits on an I/O completion port rather than WaitForMultipleObjects, so the number
/// of watched directories is not limited to the 64 handles one wait can take.  Stop and
/// "watch list changed" requests are posted to the same port as special completion keys.
/// </remarks>

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Generics.Collections, System.Generics.Defaults;

type
  /// <summary>Callback signature raised when a watched file is modified. FileName is the full path.</summary>
  TFileChangeEvent = procedure( const FileName: string ) of object;

  /// <summary>
  /// Manages a worker thread that monitors a set of directories using ReadDirectoryChangesW and
  /// marshals modification notifications back to the main thread via TThread.Queue.
  /// </summary>
  TFileWatcher = class( TObject )
  private
    /// <summary>Background thread that waits on the completion port.</summary>
    FWatchThread: TThread;
    /// <summary>Map of watched directory path to subscriber reference count.</summary>
    FDirectories: TDictionary<string, Integer>; // path -> ref count
    /// <summary>Callback invoked on the main thread when a watched file changes.</summary>
    FOnFileChanged: TFileChangeEvent;
    /// <summary>Critical section guarding FDirectories.</summary>
    FLock: TRTLCriticalSection;
    /// <summary>I/O completion port shared with the worker: directory reads complete here, and stop / update requests are posted here.</summary>
    FPort: THandle;
    /// <summary>Spawns the worker thread if it is not already running.</summary>
    procedure StartThread;
    /// <summary>Asks the worker thread to terminate and waits for it to finish.</summary>
    procedure StopThread;
    /// <summary>Tells a running worker that the watch list changed so it rebuilds its handles.</summary>
    procedure SignalUpdate;
    /// <summary>Returns a snapshot of currently watched directory paths under the lock.</summary>
    /// <returns>Array of directory paths.</returns>
    function GetWatchedDirectories: TArray<string>;
  public
    /// <summary>Initialises internal state and the completion port, but does not start watching.</summary>
    /// <exception cref="EOSError">Raised when the completion port cannot be created.</exception>
    constructor Create;
    /// <summary>Stops the worker thread and releases all resources.</summary>
    destructor Destroy; override;

    /// <summary>Adds a directory to the watch set, or increments its reference count if already watched.</summary>
    /// <param name="Directory">Directory path to monitor; the trailing separator is stripped.</param>
    procedure AddWatch( const Directory: string );
    /// <summary>Decrements the reference count for the directory and removes it when the count reaches zero.</summary>
    /// <param name="Directory">Previously added directory path.</param>
    procedure RemoveWatch( const Directory: string );
    /// <summary>Removes every watched directory and stops the worker thread.</summary>
    procedure ClearWatches;

    /// <summary>Event invoked on the main thread whenever a modification notification is received for a watched file.</summary>
    property OnFileChanged: TFileChangeEvent read FOnFileChanged write FOnFileChanged;
  end;

implementation

const
  FILE_ACTION_ADDED = $00000001;
  FILE_ACTION_MODIFIED = $00000003;
  FILE_ACTION_RENAMED_NEW_NAME = $00000005;
  /// <summary>Completion key posted by StopThread.  Real keys are PDirectoryWatch pointers, never this small.</summary>
  cStopKey = 1;
  /// <summary>Completion key posted when the watch list changes.</summary>
  cUpdateKey = 2;

type
  { Explicit declaration for portability across Delphi versions }
  TFileNotifyInformation = record
    NextEntryOffset: DWORD;
    Action: DWORD;
    FileNameLength: DWORD;
    FileName: array [0..0] of WChar;
  end;
  PFileNotifyInformation = ^TFileNotifyInformation;

  TDirectoryWatch = record
    Path: string;
    Handle: THandle;
    Overlapped: TOverlapped;
    /// <summary>Receives the notifications; ReadDirectoryChangesW requires it DWORD-aligned.</summary>
    Buffer: array [0..4095] of Byte;
    /// <summary>True from a successful ReadDirectoryChangesW until its completion packet has been dequeued.</summary>
    Pending: Boolean;
  end;
  PDirectoryWatch = ^TDirectoryWatch;

  TWatchThread = class( TThread )
  private
    FOwner: TFileWatcher;
    FPort: THandle;

    procedure SetupWatches( Watches: TList<PDirectoryWatch> );
    function CleanupWatches( Watches: TList<PDirectoryWatch> ): Boolean;
    procedure ProcessNotifications( Watch: PDirectoryWatch );
    procedure NotifyFileChanged( const FileName: string );

    function BeginRead( Watch: PDirectoryWatch ): Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create( AOwner: TFileWatcher; APort: THandle );
  end;

{ TFileWatcher }

constructor TFileWatcher.Create;
begin

  inherited Create;

  FDirectories := TDictionary<string, Integer>.Create( TIStringComparer.Ordinal );
  InitializeCriticalSection( FLock );
  FPort := CreateIoCompletionPort( INVALID_HANDLE_VALUE, 0, 0, 1 );
  if ( FPort = 0 ) then
    RaiseLastOSError;

end;

destructor TFileWatcher.Destroy;
begin

  StopThread;
  if ( FPort <> 0 ) then
    CloseHandle( FPort );
  DeleteCriticalSection( FLock );
  FDirectories.Free;

  inherited Destroy;

end;

procedure TFileWatcher.AddWatch( const Directory: string );
var
  Dir: string;
  RefCount: Integer;
  NeedStart: Boolean;
begin

  Dir := ExcludeTrailingPathDelimiter( Directory );
  NeedStart := False;

  EnterCriticalSection( FLock );
  try
    if FDirectories.TryGetValue( Dir, RefCount ) then
      FDirectories[Dir] := RefCount + 1
    else
    begin
      FDirectories.Add( Dir, 1 );
      NeedStart := FDirectories.Count = 1;
    end;
  finally
    LeaveCriticalSection( FLock );
  end;

  if NeedStart then
    StartThread
  else
    SignalUpdate;

end;

procedure TFileWatcher.RemoveWatch( const Directory: string );
var
  Dir: string;
  RefCount: Integer;
begin

  Dir := ExcludeTrailingPathDelimiter( Directory );

  EnterCriticalSection( FLock );
  try
    if FDirectories.TryGetValue( Dir, RefCount ) then
    begin
      if RefCount > 1 then
        FDirectories[Dir] := RefCount - 1
      else
        FDirectories.Remove( Dir );
    end;
  finally
    LeaveCriticalSection( FLock );
  end;

  SignalUpdate;

end;

procedure TFileWatcher.ClearWatches;
begin

  EnterCriticalSection( FLock );
  try
    FDirectories.Clear;
  finally
    LeaveCriticalSection( FLock );
  end;

  StopThread;

end;

function TFileWatcher.GetWatchedDirectories: TArray<string>;
begin

  EnterCriticalSection( FLock );
  try
    Result := FDirectories.Keys.ToArray;
  finally
    LeaveCriticalSection( FLock );
  end;

end;

procedure TFileWatcher.SignalUpdate;
begin

  // Only a running worker drains the port; without one a posted packet would linger.
  if ( FWatchThread <> nil ) then
    PostQueuedCompletionStatus( FPort, 0, cUpdateKey, nil );

end;

procedure TFileWatcher.StartThread;
begin

  if FWatchThread <> nil then
  begin
    SignalUpdate;
    Exit;
  end;

  FWatchThread := TWatchThread.Create( Self, FPort );

end;

procedure TFileWatcher.StopThread;
begin

  if FWatchThread = nil then
    Exit;

  FWatchThread.Terminate;
  PostQueuedCompletionStatus( FPort, 0, cStopKey, nil );
  FWatchThread.WaitFor;
  FreeAndNil( FWatchThread );

end;

{ TWatchThread }

constructor TWatchThread.Create( AOwner: TFileWatcher; APort: THandle );
begin

  FOwner := AOwner;
  FPort := APort;
  FreeOnTerminate := False;

  inherited Create( False );

end;

procedure TWatchThread.Execute;
var
  Watches: TList<PDirectoryWatch>;
  BytesTransferred: DWORD;
  Key: ULONG_PTR;
  Overlapped: POverlapped;
begin

  Watches := TList<PDirectoryWatch>.Create;
  try
    while not Terminated do
    begin
      SetupWatches( Watches );

      { Wait for a directory read to complete, or for an update / stop request. }
      while not Terminated do
      begin
        var bOk := GetQueuedCompletionStatus( FPort, BytesTransferred, Key, Overlapped, INFINITE );
        if ( not bOk ) and ( Overlapped = nil ) then
        begin
          { The port itself failed: nothing more can be received. }
          Terminate;
          Break;
        end;

        if ( Key = cStopKey ) then
        begin
          Terminate;
          Break;
        end;

        if ( Key = cUpdateKey ) then
          Break; { Directory list changed - rebuild watches }

        var Watch := PDirectoryWatch( Key );
        Watch.Pending := False;
        if bOk and ( BytesTransferred > 0 ) then
          ProcessNotifications( Watch );

        { Re-issue the read.  A read that failed ( the folder was deleted or became inaccessible )
          is not re-issued: it would fail again at once and spin; the next rebuild retries it. }
        if bOk and not Terminated then
          BeginRead( Watch );
      end;

      if not CleanupWatches( Watches ) then
        Terminate; { a stop request arrived while the old handles were being released }
    end;

    CleanupWatches( Watches );
  finally
    Watches.Free;
  end;

end;

procedure TWatchThread.SetupWatches( Watches: TList<PDirectoryWatch> );
var
  Dirs: TArray<string>;
  Dir: string;
  Watch: PDirectoryWatch;
begin

  Dirs := FOwner.GetWatchedDirectories;

  for Dir in Dirs do
  begin
    New( Watch );
    Watch.Pending := False;
    ZeroMemory( @Watch.Buffer, SizeOf( Watch.Buffer ) );
    ZeroMemory( @Watch.Overlapped, SizeOf( Watch.Overlapped ) );
    Watch.Path := IncludeTrailingPathDelimiter( Dir );
    { The event lets CleanupWatches wait for a cancelled read to finish before freeing its buffer. }
    Watch.Overlapped.hEvent := CreateEvent( nil, True, False, nil );
    Watch.Handle := CreateFile(
      PChar( Dir ),
      FILE_LIST_DIRECTORY,
      FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
      nil,
      OPEN_EXISTING,
      FILE_FLAG_BACKUP_SEMANTICS or FILE_FLAG_OVERLAPPED,
      0
    );

    if ( Watch.Handle = INVALID_HANDLE_VALUE ) or
       ( CreateIoCompletionPort( Watch.Handle, FPort, ULONG_PTR( Watch ), 0 ) = 0 ) then
    begin
      if ( Watch.Handle <> INVALID_HANDLE_VALUE ) then
        CloseHandle( Watch.Handle );
      CloseHandle( Watch.Overlapped.hEvent );
      Dispose( Watch );
      Continue;
    end;

    { Added even when the first read fails, so CleanupWatches closes the handle. }
    Watches.Add( Watch );
    BeginRead( Watch );
  end;

end;

function TWatchThread.CleanupWatches( Watches: TList<PDirectoryWatch> ): Boolean;
const
  cDrainTimeoutMs = 2000;
var
  I: Integer;
  Watch: PDirectoryWatch;
  BytesTransferred: DWORD;
  Key: ULONG_PTR;
  Overlapped: POverlapped;
begin

  { Cancel every outstanding read and wait for it to finish: the kernel writes into
    Watch.Buffer and Watch.Overlapped until then.  A read that had already completed still
    holds changes nobody has seen: report them now rather than lose them in the rebuild. }
  var iOutstanding := 0;
  for I := 0 to Watches.Count - 1 do
  begin
    Watch := Watches[I];
    if Watch.Pending then
    begin
      CancelIoEx( Watch.Handle, @Watch.Overlapped );
      if GetOverlappedResult( Watch.Handle, Watch.Overlapped, BytesTransferred, True ) and ( BytesTransferred > 0 ) then
        ProcessNotifications( Watch );
      Inc( iOutstanding ); { its completion packet is still to be dequeued }
    end;
    CloseHandle( Watch.Handle );
  end;

  { Dequeue exactly one packet per read cancelled above: each names a watch about to be freed.
    The wait is bounded; a stop request found here is reported to the caller instead of lost. }
  Result := True;
  var iDeadline := GetTickCount64 + cDrainTimeoutMs;
  while ( iOutstanding > 0 ) and ( GetTickCount64 < iDeadline ) do
  begin
    var bOk := GetQueuedCompletionStatus( FPort, BytesTransferred, Key, Overlapped, DWORD( iDeadline - GetTickCount64 ) );
    if ( not bOk ) and ( Overlapped = nil ) then
      Break; { timed out, or the port failed }
    if ( Overlapped = nil ) then
    begin
      if ( Key = cStopKey ) then
        Result := False; { posted requests carry no OVERLAPPED }
      Continue;
    end;
    PDirectoryWatch( Key ).Pending := False;
    Dec( iOutstanding );
  end;

  for I := Watches.Count - 1 downto 0 do
  begin
    Watch := Watches[I];
    if Watch.Pending then
      Continue; { its packet never arrived: leak the record rather than free memory the port may still name }
    CloseHandle( Watch.Overlapped.hEvent );
    Dispose( Watch );
  end;
  Watches.Clear;

end;

function TWatchThread.BeginRead( Watch: PDirectoryWatch ): Boolean;
begin

  ResetEvent( Watch.Overlapped.hEvent );
  ZeroMemory( @Watch.Buffer, SizeOf( Watch.Buffer ) );

  { With FILE_FLAG_OVERLAPPED the call returns at once: True, or False with ERROR_IO_PENDING;
    either way the completion arrives on the port. }
  Result := ReadDirectoryChangesW(
    Watch.Handle,
    @Watch.Buffer[0],
    SizeOf( Watch.Buffer ),
    False, { Do not watch subtree }
    { FILE_NAME as well as LAST_WRITE: editors, git and code tools often save by writing a
      temporary file and renaming it over the original, or by deleting and recreating it. }
    FILE_NOTIFY_CHANGE_LAST_WRITE or FILE_NOTIFY_CHANGE_FILE_NAME,
    nil,
    @Watch.Overlapped,
    nil
  );

  if not Result then
    Result := GetLastError = ERROR_IO_PENDING;
  Watch.Pending := Result;

end;

procedure TWatchThread.ProcessNotifications( Watch: PDirectoryWatch );
const
  // Offset of the FileName field within FILE_NOTIFY_INFORMATION
  // (NextEntryOffset + Action + FileNameLength, each a DWORD).
  cHeaderSize = 3 * SizeOf( DWORD );
var
  Info: PFileNotifyInformation;
  Offset: DWORD;
  FileName: string;
  FullPath: string;
begin

  Offset := 0;
  repeat
    // A busy directory can overflow the fixed buffer; ReadDirectoryChangesW then
    // truncates and a final record can claim a length running past the buffer
    // end. Validate every record stays in bounds before reading or Moving it.
    if Offset + cHeaderSize > SizeOf( Watch.Buffer ) then
      Break;

    Info := PFileNotifyInformation( @Watch.Buffer[Offset] );

    { A file written in place, created ( delete + recreate ), or renamed into place ( temporary
      file + rename ) all count as "changed".  Removals and the old name of a rename do not. }
    if ( ( Info.Action = FILE_ACTION_MODIFIED ) or ( Info.Action = FILE_ACTION_ADDED ) or
         ( Info.Action = FILE_ACTION_RENAMED_NEW_NAME ) ) and
       ( Offset + cHeaderSize + Info.FileNameLength <= SizeOf( Watch.Buffer ) ) then
    begin
      SetLength( FileName, Info.FileNameLength div SizeOf( WChar ) );
      Move( Info.FileName[0], FileName[1], Info.FileNameLength );
      FullPath := Watch.Path + FileName;

      NotifyFileChanged( FullPath );
    end;

    if Info.NextEntryOffset = 0 then
      Break;
    Inc( Offset, Info.NextEntryOffset );
  until False;

end;

procedure TWatchThread.NotifyFileChanged( const FileName: string );
var
  CapturedName: string;
  CapturedOwner: TFileWatcher;
begin

  CapturedName := FileName;
  CapturedOwner := FOwner;
  TThread.Queue( Self,
    procedure
    begin
      if Assigned( CapturedOwner.OnFileChanged ) then
        CapturedOwner.OnFileChanged( CapturedName );
    end
  );

end;

end.
