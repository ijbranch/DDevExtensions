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

interface

uses
  Windows, SysUtils, Classes, Generics.Collections, Generics.Defaults;

type
  TFileChangeEvent = procedure( const FileName: string ) of object;

  TFileWatcher = class( TObject )
  private
    FWatchThread: TThread;
    FDirectories: TDictionary<string, Integer>; // path -> ref count
    FOnFileChanged: TFileChangeEvent;
    FLock: TRTLCriticalSection;
    FStopEvent: THandle;
    FUpdateEvent: THandle;
    procedure StartThread;
    procedure StopThread;
    function GetWatchedDirectories: TArray<string>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddWatch( const Directory: string );
    procedure RemoveWatch( const Directory: string );
    procedure ClearWatches;

    property OnFileChanged: TFileChangeEvent read FOnFileChanged write FOnFileChanged;
  end;

implementation

const
  FILE_ACTION_MODIFIED = $00000003;

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
    Buffer: array [0..4095] of Byte;
  end;
  PDirectoryWatch = ^TDirectoryWatch;

  TWatchThread = class( TThread )
  private
    FOwner: TFileWatcher;
    FStopEvent: THandle;
    FUpdateEvent: THandle;

    procedure SetupWatches( var Watches: TList<PDirectoryWatch> );
    procedure CleanupWatches( var Watches: TList<PDirectoryWatch> );
    procedure ProcessNotifications( Watch: PDirectoryWatch );
    procedure NotifyFileChanged( const FileName: string );

    function BeginRead( Watch: PDirectoryWatch ): Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create( AOwner: TFileWatcher; AStopEvent, AUpdateEvent: THandle );
  end;

{ TFileWatcher }

constructor TFileWatcher.Create;
begin

  inherited Create;

  FDirectories := TDictionary<string, Integer>.Create( TIStringComparer.Ordinal );
  InitializeCriticalSection( FLock );
  FStopEvent := CreateEvent( nil, True, False, nil );
  FUpdateEvent := CreateEvent( nil, False, False, nil );

end;

destructor TFileWatcher.Destroy;
begin

  StopThread;
  CloseHandle( FStopEvent );
  CloseHandle( FUpdateEvent );
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
    SetEvent( FUpdateEvent );

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

  SetEvent( FUpdateEvent );

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

procedure TFileWatcher.StartThread;
begin

  if FWatchThread <> nil then
  begin
    SetEvent( FUpdateEvent );
    Exit;
  end;

  ResetEvent( FStopEvent );
  FWatchThread := TWatchThread.Create( Self, FStopEvent, FUpdateEvent );

end;

procedure TFileWatcher.StopThread;
begin

  if FWatchThread = nil then
    Exit;

  SetEvent( FStopEvent );
  FWatchThread.WaitFor;
  FreeAndNil( FWatchThread );

end;

{ TWatchThread }

constructor TWatchThread.Create( AOwner: TFileWatcher; AStopEvent, AUpdateEvent: THandle );
begin

  FOwner := AOwner;
  FStopEvent := AStopEvent;
  FUpdateEvent := AUpdateEvent;
  FreeOnTerminate := False;

  inherited Create( False );

end;

procedure TWatchThread.Execute;
var
  Watches: TList<PDirectoryWatch>;
  Events: array of THandle;
  I, WaitIdx: Integer;
  WaitResult: DWORD;
  BytesTransferred: DWORD;
begin

  Watches := TList<PDirectoryWatch>.Create;
  try
    while not Terminated do
    begin
      CleanupWatches( Watches );
      SetupWatches( Watches );

      if Watches.Count = 0 then
      begin
        { No directories to watch - wait for update or stop }
        SetLength( Events, 2 );
        Events[0] := FStopEvent;
        Events[1] := FUpdateEvent;

        WaitResult := WaitForMultipleObjects( 2, @Events[0], False, INFINITE );
        if WaitResult = WAIT_OBJECT_0 then
          Break;
        Continue;
      end;

      { Build wait array: stop event, update event, then overlapped events }
      SetLength( Events, 2 + Watches.Count );
      Events[0] := FStopEvent;
      Events[1] := FUpdateEvent;
      for I := 0 to Watches.Count - 1 do
        Events[2 + I] := Watches[I].Overlapped.hEvent;

      WaitResult := WaitForMultipleObjects( Length( Events ), @Events[0], False, INFINITE );

      if WaitResult = WAIT_OBJECT_0 then
        Break; { Stop requested }

      if WaitResult = WAIT_OBJECT_0 + 1 then
        Continue; { Directory list changed - rebuild watches }

      WaitIdx := Integer( WaitResult ) - Integer( WAIT_OBJECT_0 ) - 2;
      if ( WaitIdx >= 0 ) and ( WaitIdx < Watches.Count ) then
      begin
        if GetOverlappedResult( Watches[WaitIdx].Handle, Watches[WaitIdx].Overlapped, BytesTransferred, False ) then
        begin
          if BytesTransferred > 0 then
            ProcessNotifications( Watches[WaitIdx] );
        end;

        { Re-issue the read }
        if not BeginRead( Watches[WaitIdx] ) then
        begin
          { Handle became invalid - trigger rebuild }
          SetEvent( FUpdateEvent );
        end;
      end;
    end;

    CleanupWatches( Watches );
  finally
    Watches.Free;
  end;

end;

procedure TWatchThread.SetupWatches( var Watches: TList<PDirectoryWatch> );
var
  Dirs: TArray<string>;
  Dir: string;
  Watch: PDirectoryWatch;
begin

  Dirs := FOwner.GetWatchedDirectories;

  for Dir in Dirs do
  begin
    New( Watch );
    ZeroMemory( @Watch.Buffer, SizeOf( Watch.Buffer ) );
    ZeroMemory( @Watch.Overlapped, SizeOf( Watch.Overlapped ) );
    Watch.Path := IncludeTrailingPathDelimiter( Dir );
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

    if Watch.Handle = INVALID_HANDLE_VALUE then
    begin
      CloseHandle( Watch.Overlapped.hEvent );
      Dispose( Watch );
      Continue;
    end;

    if not BeginRead( Watch ) then
    begin
      CloseHandle( Watch.Handle );
      CloseHandle( Watch.Overlapped.hEvent );
      Dispose( Watch );
      Continue;
    end;

    Watches.Add( Watch );
  end;

end;

procedure TWatchThread.CleanupWatches( var Watches: TList<PDirectoryWatch> );
var
  I: Integer;
  Watch: PDirectoryWatch;
begin

  for I := Watches.Count - 1 downto 0 do
  begin
    Watch := Watches[I];
    CancelIo( Watch.Handle );
    CloseHandle( Watch.Handle );
    CloseHandle( Watch.Overlapped.hEvent );
    Dispose( Watch );
  end;
  Watches.Clear;

end;

function TWatchThread.BeginRead( Watch: PDirectoryWatch ): Boolean;
var
  BytesReturned: DWORD;
begin

  ResetEvent( Watch.Overlapped.hEvent );
  ZeroMemory( @Watch.Buffer, SizeOf( Watch.Buffer ) );

  Result := ReadDirectoryChangesW(
    Watch.Handle,
    @Watch.Buffer[0],
    SizeOf( Watch.Buffer ),
    False, { Do not watch subtree }
    FILE_NOTIFY_CHANGE_LAST_WRITE,
    @BytesReturned,
    @Watch.Overlapped,
    nil
  );

  { ERROR_IO_PENDING is expected for overlapped I/O }
  if not Result then
    Result := GetLastError = ERROR_IO_PENDING;

end;

procedure TWatchThread.ProcessNotifications( Watch: PDirectoryWatch );
var
  Info: PFileNotifyInformation;
  Offset: DWORD;
  FileName: string;
  FullPath: string;
begin

  Offset := 0;
  repeat
    Info := PFileNotifyInformation( @Watch.Buffer[Offset] );

    if Info.Action = FILE_ACTION_MODIFIED then
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
