{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude Code                                           *}
{*                                                                            *}
{* Parallel Build All: process launching and the build co-ordinator           *}
{*                                                                            *}
{******************************************************************************}

unit ParallelBuildRunner;

/// <summary>
/// Runs a build plan: a co-ordinator thread starts one worker per project, as many at a time as the
/// schedule allows, and each worker runs MSBuild ( and EurekaLog's <c>ecc32</c> where it applies ) as a
/// child process with its output captured.
/// </summary>
/// <remarks>
/// RTL and Windows API only: no ToolsAPI and no VCL, so the co-ordinator and the process launcher are
/// unit-tested.  Every callback is made on the co-ordinator's thread; a caller that touches the UI
/// marshals it to the main thread itself.
/// </remarks>

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  ParallelBuildCore;

type
  /// <summary>Asked repeatedly while a process runs; returns True once the build has been cancelled.</summary>
  TCancelCheck = reference to function: Boolean;

  /// <summary>What became of one child process.</summary>
  TProcessResult = record
    /// <summary>True when the process was created.</summary>
    Started: Boolean;
    /// <summary>The Windows error when the process could not be created, otherwise 0.</summary>
    OSError: Cardinal;
    /// <summary>The process exit code; meaningful only when <c>Started</c>.</summary>
    ExitCode: Cardinal;
    /// <summary>True when the process was killed because the build was cancelled.</summary>
    Cancelled: Boolean;
    /// <summary>Everything the process wrote to standard output and standard error.</summary>
    Output: string;
  end;

  /// <summary>What became of one project's build.</summary>
  TProjectResult = record
    /// <summary>True when the project built ( and was post-processed, where that applies ) without error.</summary>
    Succeeded: Boolean;
    /// <summary>True when the build was cut short by a cancel.</summary>
    Cancelled: Boolean;
    /// <summary>How long the project took, in milliseconds.</summary>
    ElapsedMs: Int64;
    /// <summary>Everything MSBuild and <c>ecc32</c> printed.</summary>
    Output: string;
    /// <summary>The hints, warnings and errors read from the output.</summary>
    Diagnostics: TArray<TBuildDiagnostic>;
    /// <summary>Plain remarks for the message view: the EurekaLog outcome, or why the build could not run.</summary>
    Notes: TArray<string>;
  end;

  /// <summary>Builds one project and reports the outcome.  Runs on a worker thread; must not raise.</summary>
  TProjectBuildFunc = reference to function( const AProject: TParallelProject; const ACancelled: TCancelCheck ): TProjectResult;

  /// <summary>Called on the co-ordinator's thread when a project starts building.</summary>
  TProjectStartedEvent = reference to procedure( AIndex: Integer );

  /// <summary>
  /// Called on the co-ordinator's thread when a project reaches a final state: succeeded, failed or skipped.
  /// For a skipped project the result holds only a note giving the reason.
  /// </summary>
  TProjectFinishedEvent = reference to procedure( AIndex: Integer; AState: TProjectState; const AResult: TProjectResult );

  /// <summary>
  /// The build co-ordinator.  Create it, assign the events, <c>Start</c> it, and free it when it has
  /// finished; freeing it earlier cancels the build and waits for the running projects to stop.
  /// </summary>
  /// <example>
  ///   <code>
  ///     var oBuild := TParallelBuild.Create( saPlan, 8, MSBuildAction( rSettings ) );
  ///     oBuild.OnFinished := procedure( AIndex: Integer; AState: TProjectState; const AResult: TProjectResult )
  ///       begin
  ///         // on the co-ordinator's thread: queue to the main thread before touching the UI
  ///       end;
  ///     oBuild.Start;
  ///   </code>
  /// </example>
  TParallelBuild = class( TThread )
  private
    /// <summary>The plan to build.</summary>
    FPlan: TArray<TParallelProject>;
    /// <summary>The most projects built at once.</summary>
    FMaxWorkers: Integer;
    /// <summary>Builds one project.</summary>
    FBuild: TProjectBuildFunc;
    /// <summary>Set when a worker finishes or the build is cancelled, to wake the co-ordinator.</summary>
    FWake: TEvent;
    /// <summary>Guards <c>FFinishedIndexes</c> and <c>FResults</c>.</summary>
    FLock: TCriticalSection;
    /// <summary>Plan indexes of the workers that have finished and not yet been collected.</summary>
    FFinishedIndexes: TList<Integer>;
    /// <summary>Each project's result, by plan index, written by its worker under <c>FLock</c>.</summary>
    FResults: TArray<TProjectResult>;
    /// <summary>The running workers, by plan index.</summary>
    FWorkers: TDictionary<Integer, TThread>;
    /// <summary>1 once <see cref="Cancel"/> has been called.</summary>
    FCancelFlag: Integer;
    /// <summary>The largest number of projects that were building at the same moment.</summary>
    FPeakRunning: Integer;
    /// <summary>Each project's final state, by plan index; valid once the thread has finished.</summary>
    FFinalStates: TArray<TProjectState>;
    /// <summary>Backing field for OnStarted.</summary>
    FOnStarted: TProjectStartedEvent;
    /// <summary>Backing field for OnFinished.</summary>
    FOnFinished: TProjectFinishedEvent;
    /// <summary>Called by a worker, on its own thread, when its project is done.</summary>
    /// <param name="AIndex">The plan index.</param>
    /// <param name="AResult">The outcome.</param>
    procedure WorkerDone( AIndex: Integer; const AResult: TProjectResult );
    /// <summary>Starts the worker for one project.</summary>
    /// <param name="AIndex">The plan index.</param>
    procedure StartWorker( AIndex: Integer );
    /// <summary>Collects every finished worker, tells the schedule and raises OnFinished.</summary>
    /// <param name="ASchedule">The schedule to update.</param>
    procedure CollectFinished( ASchedule: TParallelSchedule );
    /// <summary>Raises OnFinished for each project the schedule has skipped since the last call.</summary>
    /// <param name="ASchedule">The schedule to read.</param>
    /// <param name="AReported">Which projects have been reported; updated.</param>
    procedure ReportSkipped( ASchedule: TParallelSchedule; var AReported: TArray<Boolean> );
    /// <summary>Reads a project's final state.</summary>
    /// <param name="AIndex">The plan index.</param>
    /// <returns>The state; <c>psWaiting</c> until the thread has finished.</returns>
    function GetFinalState( AIndex: Integer ): TProjectState;
  protected
    /// <summary>The co-ordinator loop.</summary>
    procedure Execute; override;
  public
    /// <summary>Creates the co-ordinator suspended; call <c>Start</c>.</summary>
    /// <param name="APlan">The plan, from <c>ParallelBuildCore.BuildPlan</c>.</param>
    /// <param name="AMaxWorkers">The most projects built at once.</param>
    /// <param name="ABuild">Builds one project; called on a worker thread.</param>
    constructor Create( const APlan: TArray<TParallelProject>; AMaxWorkers: Integer; const ABuild: TProjectBuildFunc );
    /// <summary>Cancels the build if it is still running, waits for it to stop, and frees it.</summary>
    destructor Destroy; override;
    /// <summary>Stops the build: nothing new starts, and running projects are told to stop.  Safe from any thread.</summary>
    procedure Cancel;
    /// <summary>True once <see cref="Cancel"/> has been called.  Safe from any thread.</summary>
    /// <returns>True when the build has been cancelled.</returns>
    function Cancelled: Boolean;
    /// <summary>The largest number of projects that were building at the same moment.</summary>
    property PeakRunning: Integer read FPeakRunning;
    /// <summary>Each project's final state, by plan index; valid once the thread has finished.</summary>
    property FinalStates[ AIndex: Integer ]: TProjectState read GetFinalState;
    /// <summary>Raised on the co-ordinator's thread when a project starts.  Assign before <c>Start</c>.</summary>
    property OnStarted: TProjectStartedEvent read FOnStarted write FOnStarted;
    /// <summary>Raised on the co-ordinator's thread when a project finishes or is skipped.  Assign before <c>Start</c>.</summary>
    property OnFinished: TProjectFinishedEvent read FOnFinished write FOnFinished;
  end;

  /// <summary>What <see cref="MSBuildAction"/> needs to build a project.</summary>
  TMSBuildSettings = record
    /// <summary>Full path of <c>MSBuild.exe</c>.</summary>
    MSBuildExe: string;
    /// <summary>The environment for the child processes, from <c>ParallelBuildCore.EnvironmentBlock</c>.</summary>
    EnvironmentBlock: string;
    /// <summary>The user's "run EurekaLog" setting.</summary>
    RunEurekaLog: Boolean;
    /// <summary>Full path of <c>ecc32.exe</c>; it need not exist.</summary>
    Ecc32Exe: string;
    /// <summary>The user's roaming application-data folder, to resolve a stub <c>.eof</c>.</summary>
    AppDataDir: string;
  end;

/// <summary>
/// Runs a process with no window, captures what it prints, and waits for it to end.  A cancel kills the
/// process and every process it started.
/// </summary>
/// <param name="ACommandLine">The full command line, program first.</param>
/// <param name="AWorkDir">The working folder; empty means the caller's.</param>
/// <param name="AEnvironmentBlock">The environment block; empty means the caller's environment.</param>
/// <param name="ACancelled">Polled while the process runs; may be nil.</param>
/// <param name="AUnicodeOutput">True when the process writes UTF-16 ( <c>cmd /u</c> ); otherwise the OEM code page is assumed.</param>
/// <returns>
/// The outcome.  When the process cannot be created, <c>Started</c> is False and <c>OSError</c> holds the
/// Windows error; nothing is raised.
/// </returns>
function RunCaptured( const ACommandLine, AWorkDir, AEnvironmentBlock: string; const ACancelled: TCancelCheck;
  AUnicodeOutput: Boolean = False ): TProcessResult;

/// <summary>Runs <c>rsvars.bat</c> and returns the environment it sets up, for the build's child processes.</summary>
/// <param name="ARsVarsBat">Full path of the IDE's <c>bin\rsvars.bat</c>.</param>
/// <param name="AVariables">Receives the environment as <c>NAME=VALUE</c> strings.</param>
/// <param name="AError">Receives the reason when the result is False.</param>
/// <returns>True when the environment was read and names <c>FrameworkDir</c>.</returns>
function CaptureEnvironment( const ARsVarsBat: string; out AVariables: TArray<string>; out AError: string ): Boolean;

/// <summary>
/// Returns the function that builds one project for real: MSBuild, then EurekaLog's <c>ecc32</c> on the
/// output when <c>ParallelBuildCore.ShouldRunEurekaLog</c> says so and <c>ecc32.exe</c> is installed.
/// </summary>
/// <param name="ASettings">Where MSBuild and <c>ecc32</c> are, and the environment to give them.</param>
/// <returns>A function for <see cref="TParallelBuild.Create"/>.  It never raises: a failure is reported in the result.</returns>
function MSBuildAction( const ASettings: TMSBuildSettings ): TProjectBuildFunc;

implementation

uses
  Winapi.Windows,
  System.IOUtils, System.Diagnostics, System.Math;

var
  /// <summary>
  /// Serialises process creation.  A child inherits every handle that is inheritable at the moment it is
  /// created; the pipe ends are made inheritable only inside this lock, so one build's child never inherits
  /// ( and holds open ) another build's pipe.
  /// </summary>
  CreateProcessLock: TCriticalSection;

type
  /// <summary>Builds one project on its own thread and hands the result to the co-ordinator.</summary>
  TProjectWorker = class( TThread )
  private
    /// <summary>The co-ordinator.</summary>
    FOwner: TParallelBuild;
    /// <summary>The plan index of the project.</summary>
    FIndex: Integer;
  protected
    /// <summary>Runs the build function and reports the result; an exception becomes a failed result.</summary>
    procedure Execute; override;
  public
    /// <summary>Creates the worker suspended.</summary>
    /// <param name="AOwner">The co-ordinator.</param>
    /// <param name="AIndex">The plan index of the project to build.</param>
    constructor Create( AOwner: TParallelBuild; AIndex: Integer );
  end;

{ Process launching }

/// <summary>Moves whatever is waiting in a pipe into a stream, without blocking.</summary>
/// <param name="APipe">The read end of the pipe.</param>
/// <param name="ATarget">Receives the bytes.</param>
procedure DrainPipe( APipe: THandle; ATarget: TStream );
var
  naBuffer          : array[ 0..8191 ] of Byte;
  iAvailable, iRead : DWORD;
begin

  while PeekNamedPipe( APipe, nil, 0, nil, @iAvailable, nil ) and ( iAvailable > 0 ) do
  begin
    if ( not ReadFile( APipe, naBuffer, Min( iAvailable, SizeOf( naBuffer ) ), iRead, nil ) ) or ( iRead = 0 ) then Break;
    ATarget.WriteBuffer( naBuffer, iRead );
  end;

end;

/// <summary>Decodes captured process output.</summary>
/// <param name="ABytes">The bytes captured.</param>
/// <param name="AUnicode">True for UTF-16, False for the OEM code page.</param>
/// <returns>The text.</returns>
function DecodeOutput( const ABytes: TBytes; AUnicode: Boolean ): string;
begin

  if AUnicode then Exit( TEncoding.Unicode.GetString( ABytes ) );

  var oEncoding := TEncoding.GetEncoding( GetOEMCP );
  try
    Result := oEncoding.GetString( ABytes );
  finally
    oEncoding.Free;
  end;

end;

function RunCaptured( const ACommandLine, AWorkDir, AEnvironmentBlock: string; const ACancelled: TCancelCheck;
  AUnicodeOutput: Boolean ): TProcessResult;
var
  rSecurity         : TSecurityAttributes;
  rStartup          : TStartupInfo;
  rProcess          : TProcessInformation;
  rLimits           : TJobObjectExtendedLimitInformation;
  hRead, hWrite, hNul, hJob: THandle;
  bCreated          : Boolean;
begin

  Result := Default( TProcessResult );

  rSecurity := Default( TSecurityAttributes );
  rSecurity.nLength := SizeOf( rSecurity );

  // A roomy buffer: the default 4 KB, drained once per wait, would hold a chatty compiler back.
  if not CreatePipe( hRead, hWrite, @rSecurity, 1024 * 1024 ) then
  begin
    Result.OSError := Winapi.Windows.GetLastError;
    Exit;
  end;

  hNul := CreateFile( 'NUL', GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, @rSecurity, OPEN_EXISTING, 0, 0 );

  var sCommandLine := ACommandLine;
  UniqueString( sCommandLine );   // CreateProcessW may write to the buffer
  var pEnvironment: Pointer := nil;
  var iFlags: DWORD := CREATE_NO_WINDOW or CREATE_SUSPENDED;

  if AEnvironmentBlock <> '' then
  begin
    pEnvironment := PChar( AEnvironmentBlock );
    iFlags := iFlags or CREATE_UNICODE_ENVIRONMENT;
  end;

  var pWorkDir: PChar := nil;

  if AWorkDir <> '' then pWorkDir := PChar( AWorkDir );

  rStartup := Default( TStartupInfo );
  rStartup.cb         := SizeOf( rStartup );
  rStartup.dwFlags    := STARTF_USESTDHANDLES;
  rStartup.hStdInput  := hNul;
  rStartup.hStdOutput := hWrite;
  rStartup.hStdError  := hWrite;

  CreateProcessLock.Enter;
  try
    SetHandleInformation( hWrite, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT );
    if hNul <> INVALID_HANDLE_VALUE then SetHandleInformation( hNul, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT );
    bCreated := CreateProcess( nil, PChar( sCommandLine ), nil, nil, True, iFlags, pEnvironment, pWorkDir, rStartup, rProcess );
    if not bCreated then Result.OSError := Winapi.Windows.GetLastError;
    SetHandleInformation( hWrite, HANDLE_FLAG_INHERIT, 0 );
    if hNul <> INVALID_HANDLE_VALUE then SetHandleInformation( hNul, HANDLE_FLAG_INHERIT, 0 );
  finally
    CreateProcessLock.Leave;
  end;

  // The child has its own copies; ours must go, or the pipe never empties.
  CloseHandle( hWrite );

  if hNul <> INVALID_HANDLE_VALUE then CloseHandle( hNul );

  if not bCreated then
  begin
    CloseHandle( hRead );
    Exit;
  end;

  Result.Started := True;

  // A job that kills its processes when closed: a cancel takes MSBuild's own children ( dcc ) with it.
  hJob := CreateJobObject( nil, nil );

  if hJob <> 0 then
  begin
    rLimits := Default( TJobObjectExtendedLimitInformation );
    rLimits.BasicLimitInformation.LimitFlags := JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    SetInformationJobObject( hJob, JobObjectExtendedLimitInformation, @rLimits, SizeOf( rLimits ) );
    if not AssignProcessToJobObject( hJob, rProcess.hProcess ) then
    begin
      CloseHandle( hJob );
      hJob := 0;
    end;
  end;

  var oCaptured := TBytesStream.Create;
  try
    ResumeThread( rProcess.hThread );

    while True do
    begin
      var iWait := WaitForSingleObject( rProcess.hProcess, 50 );
      DrainPipe( hRead, oCaptured );
      if iWait <> WAIT_TIMEOUT then Break;
      if ( not Result.Cancelled ) and Assigned( ACancelled ) and ACancelled() then
      begin
        Result.Cancelled := True;
        if hJob <> 0 then
          TerminateJobObject( hJob, 1 )
        else
          TerminateProcess( rProcess.hProcess, 1 );
      end;
    end;

    GetExitCodeProcess( rProcess.hProcess, Result.ExitCode );
    Result.Output := DecodeOutput( Copy( oCaptured.Bytes, 0, oCaptured.Size ), AUnicodeOutput );
  finally
    oCaptured.Free;
    if hJob <> 0 then CloseHandle( hJob );
    CloseHandle( rProcess.hThread );
    CloseHandle( rProcess.hProcess );
    CloseHandle( hRead );
  end;

end;

function CaptureEnvironment( const ARsVarsBat: string; out AVariables: TArray<string>; out AError: string ): Boolean;
begin

  AVariables := [];
  AError     := '';

  if not FileExists( ARsVarsBat ) then
  begin
    AError := 'rsvars.bat was not found at ' + ARsVarsBat;
    Exit( False );
  end;

  var sComSpec := GetEnvironmentVariable( 'ComSpec' );

  if sComSpec = '' then sComSpec := 'cmd.exe';

  // /u makes set print UTF-16, so no variable is damaged by the OEM code page; /s keeps the inner quotes.
  var rRun := RunCaptured( QuoteArgument( sComSpec ) + ' /d /u /s /c ""' + ARsVarsBat + '" && set"', '', '', nil, True );

  if not rRun.Started then
    AError := 'the command processor could not be started: ' + SysErrorMessage( rRun.OSError )
  else if rRun.ExitCode <> 0 then
    AError := Format( 'rsvars.bat ended with exit code %d', [ rRun.ExitCode ] )
  else
  begin
    AVariables := ParseSetOutput( rRun.Output );
    if EnvironmentValue( AVariables, 'FrameworkDir' ) = '' then
      AError := 'rsvars.bat did not set FrameworkDir, so MSBuild cannot be found';
  end;

  Result := AError = '';

end;

{ The real build action }

/// <summary>Runs <c>ecc32</c> on a project's output and records the outcome in the result.</summary>
/// <param name="ASettings">Where <c>ecc32</c> is, and the environment.</param>
/// <param name="AProject">The project just built.</param>
/// <param name="ADprojText">The text of its <c>.dproj</c>.</param>
/// <param name="ACancelled">The cancel check.</param>
/// <param name="AResult">The project's result; updated.</param>
procedure RunEurekaLogStep( const ASettings: TMSBuildSettings; const AProject: TParallelProject; const ADprojText: string;
  const ACancelled: TCancelCheck; var AResult: TProjectResult );
begin

  var sEofFile := ChangeFileExt( AProject.FileName, '.eof' );
  var sDprFile := ChangeFileExt( AProject.FileName, '.dpr' );
  var bRunner  := FileExists( sDprFile ) and IsDUnitXRunner( TFile.ReadAllText( sDprFile ) );

  if not ShouldRunEurekaLog( ASettings.RunEurekaLog, AProject.Config, AProject.Kind, FileExists( sEofFile ), bRunner ) then Exit;

  if not FileExists( ASettings.Ecc32Exe ) then
  begin
    // Not a failure: a project can carry a .eof on a machine that has no EurekaLog.
    AResult.Notes := AResult.Notes + [ 'EurekaLog: not post-processed, ecc32.exe was not found at ' + ASettings.Ecc32Exe ];
    Exit;
  end;

  var sOutputFile := ProjectOutputFile( AProject.FileName, ADprojText, AProject.Config, AProject.Platform, AProject.Kind );

  if not FileExists( sOutputFile ) then
  begin
    AResult.Succeeded := False;
    AResult.Notes     := AResult.Notes + [ 'EurekaLog: FAILED, the built file was not found at ' + sOutputFile ];
    Exit;
  end;

  var sProfile := EurekaLogProfilePath( TFile.ReadAllText( sEofFile ), sEofFile, ASettings.AppDataDir );
  var rRun     := RunCaptured( Ecc32CommandLine( ASettings.Ecc32Exe, AProject.FileName, sOutputFile, sProfile ),
    ExtractFileDir( AProject.FileName ), ASettings.EnvironmentBlock, ACancelled );

  AResult.Output    := AResult.Output + sLineBreak + rRun.Output;
  AResult.Cancelled := rRun.Cancelled;

  if not rRun.Started then
  begin
    AResult.Succeeded := False;
    AResult.Notes     := AResult.Notes + [ 'EurekaLog: FAILED, ecc32 could not be started: ' + SysErrorMessage( rRun.OSError ) ];
  end
  else if rRun.Cancelled or ( rRun.ExitCode <> 0 ) then
  begin
    AResult.Succeeded := False;
    AResult.Notes     := AResult.Notes + [ Format( 'EurekaLog: FAILED ( ecc32 exit code %d ) - do not deploy %s',
      [ rRun.ExitCode, ExtractFileName( sOutputFile ) ] ) ];
  end
  else
  begin
    // ecc32 leaves a .eldbg that switches EurekaLog on in a service even without injection: remove it.
    var saEldbg: TArray<string> := [ ChangeFileExt( sOutputFile, '.eldbg' ), ChangeFileExt( AProject.FileName, '.eldbg' ) ];
    for var sEldbg in saEldbg do
      if FileExists( sEldbg ) then System.SysUtils.DeleteFile( sEldbg );
    AResult.Notes := AResult.Notes + [ 'EurekaLog: post-processed' ];
  end;

end;

function MSBuildAction( const ASettings: TMSBuildSettings ): TProjectBuildFunc;
begin

  var rSettings := ASettings;

  Result :=
    function( const AProject: TParallelProject; const ACancelled: TCancelCheck ): TProjectResult
    begin
      Result := Default( TProjectResult );
      var oWatch := TStopwatch.StartNew;
      try
        var sDprojText := TFile.ReadAllText( AProject.FileName );
        var rRun := RunCaptured( MSBuildCommandLine( rSettings.MSBuildExe, AProject.FileName, AProject.Config, AProject.Platform ),
          ExtractFileDir( AProject.FileName ), rSettings.EnvironmentBlock, ACancelled );
        Result.Output      := rRun.Output;
        Result.Cancelled   := rRun.Cancelled;
        Result.Diagnostics := ParseBuildOutput( rRun.Output );
        if not rRun.Started then
          Result.Notes := [ 'MSBuild could not be started: ' + SysErrorMessage( rRun.OSError ) ]
        else if rRun.Cancelled then
          Result.Notes := [ 'cancelled' ]
        else
        begin
          Result.Succeeded := ( rRun.ExitCode = 0 ) and not HasErrors( Result.Diagnostics );
          if ( not Result.Succeeded ) and not HasErrors( Result.Diagnostics ) then
            Result.Notes := [ Format( 'MSBuild ended with exit code %d', [ rRun.ExitCode ] ) ];
        end;
        if Result.Succeeded and Assigned( ACancelled ) and ACancelled( ) then
        begin
          // Cancelled between the two steps: the file is built but not post-processed, so it is not a success.
          Result.Succeeded := False;
          Result.Cancelled := True;
          Result.Notes     := [ 'cancelled' ];
        end;
        // ecc32 rewrites the built file in place, so once started it is left to finish: no cancel check.
        if Result.Succeeded then RunEurekaLogStep( rSettings, AProject, sDprojText, nil, Result );
      except
        on E: Exception do
        begin
          Result.Succeeded := False;
          Result.Notes     := Result.Notes + [ E.ClassName + ': ' + E.Message ];
        end;
      end;
      Result.ElapsedMs := oWatch.ElapsedMilliseconds;
    end;

end;

{ TProjectWorker }

constructor TProjectWorker.Create( AOwner: TParallelBuild; AIndex: Integer );
begin

  inherited Create( True );

  FreeOnTerminate := False;   // the co-ordinator joins and frees it
  FOwner := AOwner;
  FIndex := AIndex;

end;

procedure TProjectWorker.Execute;
var
  rResult           : TProjectResult;
begin

  var oOwner := FOwner;

  try
    rResult := oOwner.FBuild( oOwner.FPlan[ FIndex ],
      function: Boolean
      begin
        Result := oOwner.Cancelled;
      end );
  except
    on E: Exception do
    begin
      rResult       := Default( TProjectResult );
      rResult.Notes := [ E.ClassName + ': ' + E.Message ];
    end;
  end;

  FOwner.WorkerDone( FIndex, rResult );

end;

{ TParallelBuild }

constructor TParallelBuild.Create( const APlan: TArray<TParallelProject>; AMaxWorkers: Integer; const ABuild: TProjectBuildFunc );
begin

  inherited Create( True );

  FreeOnTerminate  := False;
  FPlan            := APlan;
  FMaxWorkers      := AMaxWorkers;
  FBuild           := ABuild;
  FWake            := TEvent.Create( nil, False, False, '' );
  FLock            := TCriticalSection.Create;
  FFinishedIndexes := TList<Integer>.Create;
  FWorkers         := TDictionary<Integer, TThread>.Create;
  SetLength( FResults, Length( FPlan ) );
  SetLength( FFinalStates, Length( FPlan ) );

end;

destructor TParallelBuild.Destroy;
begin

  // Without this, freeing a running build would wait for every project to build to the end.
  Cancel;

  inherited Destroy;   // Terminate + WaitFor: Execute has joined every worker by the time it returns

  FWorkers.Free;
  FFinishedIndexes.Free;
  FLock.Free;
  FWake.Free;

end;

procedure TParallelBuild.Cancel;
begin

  TInterlocked.Exchange( FCancelFlag, 1 );

  if Assigned( FWake ) then FWake.SetEvent;

end;

function TParallelBuild.Cancelled: Boolean;
begin

  Result := TInterlocked.CompareExchange( FCancelFlag, 0, 0 ) = 1;

end;

function TParallelBuild.GetFinalState( AIndex: Integer ): TProjectState;
begin

  Result := FFinalStates[ AIndex ];

end;

procedure TParallelBuild.WorkerDone( AIndex: Integer; const AResult: TProjectResult );
begin

  FLock.Enter;
  try
    FResults[ AIndex ] := AResult;
    FFinishedIndexes.Add( AIndex );
  finally
    FLock.Leave;
  end;

  FWake.SetEvent;

end;

procedure TParallelBuild.StartWorker( AIndex: Integer );
begin

  var oWorker := TProjectWorker.Create( Self, AIndex );

  FWorkers.Add( AIndex, oWorker );
  FPeakRunning := Max( FPeakRunning, FWorkers.Count );

  if Assigned( FOnStarted ) then FOnStarted( AIndex );

  oWorker.Start;

end;

procedure TParallelBuild.CollectFinished( ASchedule: TParallelSchedule );
var
  naFinished        : TArray<Integer>;
begin

  FLock.Enter;
  try
    naFinished := FFinishedIndexes.ToArray;
    FFinishedIndexes.Clear;
  finally
    FLock.Leave;
  end;

  for var iIndex in naFinished do
  begin
    var oWorker := FWorkers[ iIndex ];
    oWorker.WaitFor;
    oWorker.Free;
    FWorkers.Remove( iIndex );

    // The worker has ended, so its result is no longer written to.
    var rResult := FResults[ iIndex ];
    ASchedule.Finished( iIndex, rResult.Succeeded );
    if Assigned( FOnFinished ) then FOnFinished( iIndex, ASchedule.States[ iIndex ], rResult );
  end;

end;

procedure TParallelBuild.ReportSkipped( ASchedule: TParallelSchedule; var AReported: TArray<Boolean> );
begin

  for var iI := 0 to High( FPlan ) do
    if ( ASchedule.States[ iI ] = psSkipped ) and ( not AReported[ iI ] ) then
    begin
      AReported[ iI ] := True;
      var rResult := Default( TProjectResult );
      rResult.Notes := [ ASchedule.SkipReasons[ iI ] ];
      if Assigned( FOnFinished ) then FOnFinished( iI, psSkipped, rResult );
    end;

end;

procedure TParallelBuild.Execute;
var
  baReported        : TArray<Boolean>;
begin

  NameThreadForDebugging( 'DDevExtensions parallel build' );
  SetLength( baReported, Length( FPlan ) );

  var oSchedule := TParallelSchedule.Create( FPlan, FMaxWorkers );
  try
    try
      while True do
      begin
        if Cancelled then oSchedule.CancelWaiting( 'not built: the build was cancelled' );

        var iNext := oSchedule.NextToStart;
        while iNext >= 0 do
        begin
          StartWorker( iNext );
          iNext := oSchedule.NextToStart;
        end;

        ReportSkipped( oSchedule, baReported );
        if oSchedule.Done then Break;

        FWake.WaitFor( INFINITE );
        CollectFinished( oSchedule );
      end;
    finally
      // Reached with workers still running only when something above raised: stop and join them.
      if FWorkers.Count > 0 then
      begin
        Cancel;
        for var oWorker in FWorkers.Values do
        begin
          oWorker.WaitFor;
          oWorker.Free;
        end;
        FWorkers.Clear;
      end;
      for var iI := 0 to High( FPlan ) do
        FFinalStates[ iI ] := oSchedule.States[ iI ];
    end;
  finally
    oSchedule.Free;
  end;

end;

initialization
  CreateProcessLock := TCriticalSection.Create;

finalization
  CreateProcessLock.Free;

end.
