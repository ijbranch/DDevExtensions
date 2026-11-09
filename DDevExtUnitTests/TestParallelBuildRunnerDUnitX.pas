unit TestParallelBuildRunnerDUnitX;

/// <summary>
/// DUnitX test fixture for <c>ParallelBuildRunner</c>: the part of "Parallel Build All" that starts
/// processes and threads.  It proves what <c>RunCaptured</c> reports at each failure layer ( the process
/// cannot be created, it ends with an error, it is cancelled ), that the co-ordinator really builds
/// several projects at once and never more than it was told, and what <c>MSBuildAction</c> reports for
/// MSBuild and EurekaLog outcomes.  MSBuild and <c>ecc32</c> are stood in for by small command files, so
/// the working folder must be one whose path has no space ( the user's temporary folder ).
/// The fixture is registered in this unit's initialization section.
/// </summary>

interface

uses
  System.Classes, System.SyncObjs, System.Generics.Collections,
  DUnitX.TestFramework,
  ParallelBuildCore, ParallelBuildRunner;

type
  /// <summary>DUnitX test fixture exercising process capture, the build co-ordinator and the real build action.</summary>
  [ TestFixture ]
  TTestParallelBuildRunner = class
  private
    /// <summary>A folder of its own for each test, removed afterwards.</summary>
    FDir: string;
    /// <summary>Full path of the command processor.</summary>
    FComSpec: string;
    /// <summary>Guards the fields the stand-in build functions write from worker threads.</summary>
    FLock: TCriticalSection;
    /// <summary>Names of the projects the stand-in build function was called for.</summary>
    FCalls: TList<string>;
    /// <summary>How many stand-in builds are running now.</summary>
    FRunning: Integer;
    /// <summary>The most stand-in builds seen running at once.</summary>
    FMaxRunning: Integer;
    /// <summary>How many stand-in builds gave up waiting for a second one to run beside them.</summary>
    FAlone: Integer;
    /// <summary>Set once two stand-in builds are running at the same moment.</summary>
    FTwoRunning: TEvent;
    /// <summary>Set when a stand-in build has started.</summary>
    FStarted: TEvent;
    /// <summary>One line per OnFinished call: index, state number and first note.</summary>
    FFinished: TList<string>;
    /// <summary>Plan indexes in the order OnStarted reported them.</summary>
    FStartedIndexes: TList<Integer>;
    /// <summary>Thread ids the events were raised on.</summary>
    FEventThreads: TList<TThreadID>;
    /// <summary>Records a stand-in build call.</summary>
    /// <param name="AProject">The project being built.</param>
    procedure NoteCall( const AProject: TParallelProject );
    /// <summary>Writes a text file into the test folder.</summary>
    /// <param name="AName">The file name, without folder.</param>
    /// <param name="AText">The text.</param>
    /// <returns>The full path.</returns>
    function WriteFile( const AName, AText: string ): string;
    /// <summary>Writes a command file that prints one line and ends with an exit code.</summary>
    /// <param name="AName">The file name, without folder.</param>
    /// <param name="ALine">The line to print; empty prints nothing.</param>
    /// <param name="AExitCode">The exit code.</param>
    /// <returns>The full path.</returns>
    function WriteCommandFile( const AName, ALine: string; AExitCode: Integer ): string;
    /// <summary>Writes <c>App.dproj</c> into the test folder and returns its plan entry.</summary>
    /// <param name="AConfig">The configuration to build.</param>
    /// <returns>The entry, for an application on Win64.</returns>
    function AppProject( const AConfig: string ): TParallelProject;
    /// <summary>A stand-in build that succeeds at once.</summary>
    /// <returns>The build function.</returns>
    function QuickBuild: TProjectBuildFunc;
    /// <summary>A stand-in build that runs until it is cancelled.</summary>
    /// <returns>The build function.</returns>
    function BuildUntilCancelled: TProjectBuildFunc;
    /// <summary>Attaches recording handlers to a build's events.</summary>
    /// <param name="ABuild">The build.</param>
    procedure RecordEvents( ABuild: TParallelBuild );
  public
    /// <summary>Creates the test folder and the recording fields.</summary>
    [ Setup ]
    procedure Setup;
    /// <summary>Removes the test folder and frees the recording fields.</summary>
    [ TearDown ]
    procedure TearDown;
    /// <summary>Proves standard output is captured and a clean exit reports exit code 0.</summary>
    [ Test ]
    procedure TestRunCapturedOutput;
    /// <summary>Proves standard error is captured too, since the compiler's errors must not be lost.</summary>
    [ Test ]
    procedure TestRunCapturedStandardError;
    /// <summary>Proves the process's own exit code is reported, not a fixed value.</summary>
    [ Test ]
    procedure TestRunCapturedExitCode;
    /// <summary>Proves a program that does not exist gives <c>Started</c> False and the Windows error, without raising.</summary>
    [ Test ]
    procedure TestRunCapturedMissingProgram;
    /// <summary>Proves the working folder is the one asked for.</summary>
    [ Test ]
    procedure TestRunCapturedWorkingFolder;
    /// <summary>Proves the child sees the environment block it was given.</summary>
    [ Test ]
    procedure TestRunCapturedEnvironment;
    /// <summary>Proves UTF-16 output is decoded as such, so a character outside the OEM code page survives.</summary>
    [ Test ]
    procedure TestRunCapturedUnicodeOutput;
    /// <summary>Proves a cancel ends a long-running process and its child promptly, and reports it as cancelled.</summary>
    [ Test ]
    procedure TestRunCapturedCancel;
    /// <summary>Proves a missing <c>rsvars.bat</c> is reported by name before anything is run.</summary>
    [ Test ]
    procedure TestCaptureEnvironmentMissingFile;
    /// <summary>Proves a failing <c>rsvars.bat</c> is reported with its exit code.</summary>
    [ Test ]
    procedure TestCaptureEnvironmentFailingFile;
    /// <summary>Proves an environment without <c>FrameworkDir</c> is refused, since MSBuild could not be found.</summary>
    [ Test ]
    procedure TestCaptureEnvironmentWithoutFrameworkDir;
    /// <summary>Proves the variables a command file sets are returned, from a folder whose name has a space.</summary>
    [ Test ]
    procedure TestCaptureEnvironmentSuccess;
    /// <summary>Proves two projects really build at the same moment, and never more than the worker count.</summary>
    [ Test ]
    procedure TestBuildRunsProjectsTogether;
    /// <summary>Proves each project is reported started and finished once, on one thread that is not the caller's.</summary>
    [ Test ]
    procedure TestBuildRaisesEvents;
    /// <summary>Proves a failed project's dependent is not built and is reported skipped with the reason.</summary>
    [ Test ]
    procedure TestBuildSkipsDependentsOfFailure;
    /// <summary>Proves a build function that raises fails its own project only, with the exception as the note.</summary>
    /// <exception cref="EArgumentException">Raised inside the stand-in build function, on a worker thread; it never leaves the build.</exception>
    [ Test ]
    procedure TestBuildSurvivesRaisingBuildFunction;
    /// <summary>Proves a cancel tells the running project to stop and starts none of the waiting ones.</summary>
    [ Test ]
    procedure TestBuildCancel;
    /// <summary>Proves freeing a build that is still running cancels it and waits, rather than hanging or leaking a worker.</summary>
    [ Test ]
    procedure TestBuildFreeWhileRunning;
    /// <summary>Proves a compiler error fails the project and is returned as a diagnostic.</summary>
    [ Test ]
    procedure TestActionCompilerError;
    /// <summary>Proves a hint does not fail the project and is still returned.</summary>
    [ Test ]
    procedure TestActionHintStillSucceeds;
    /// <summary>Proves a non-zero exit code with no error line fails the project and says so.</summary>
    [ Test ]
    procedure TestActionExitCodeWithoutError;
    /// <summary>Proves an MSBuild that cannot be started fails the project with the reason.</summary>
    [ Test ]
    procedure TestActionMSBuildMissing;
    /// <summary>Proves an unreadable project fails with a note rather than an exception on the worker thread.</summary>
    [ Test ]
    procedure TestActionProjectFileMissing;
    /// <summary>Proves a project with a <c>.eof</c> still succeeds, with a note, where EurekaLog is not installed.</summary>
    [ Test ]
    procedure TestActionEurekaLogNotInstalled;
    /// <summary>Proves a successful <c>ecc32</c> run is noted and the <c>.eldbg</c> it leaves is deleted.</summary>
    [ Test ]
    procedure TestActionEurekaLogPostProcessed;
    /// <summary>Proves a failed <c>ecc32</c> run fails the project and warns against deploying the file.</summary>
    [ Test ]
    procedure TestActionEurekaLogFailure;
    /// <summary>Proves a missing built file is a failure when EurekaLog was due to process it.</summary>
    [ Test ]
    procedure TestActionEurekaLogOutputMissing;
    /// <summary>Proves <c>ecc32</c> is not run for a Debug build or when the setting is off.</summary>
    [ Test ]
    procedure TestActionEurekaLogNotDue;
    /// <summary>Proves a cancel that lands once MSBuild has finished does not start <c>ecc32</c>, and the project is not a success.</summary>
    [ Test ]
    procedure TestActionCancelBeforeEurekaLog;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.Diagnostics;

const
  /// <summary>A minimal application .dproj with no output folders, so the exe lands beside it.</summary>
  APP_DPROJ = '<Project><PropertyGroup><AppType>Application</AppType></PropertyGroup></Project>';
  /// <summary>Long enough for a slow machine, short enough that a hang is noticed.</summary>
  WAIT_MS = 10000;

/// <summary>Builds a plan entry by hand.</summary>
/// <param name="AName">The project name.</param>
/// <param name="ADependsOn">The plan indexes it waits for.</param>
/// <returns>The entry, with a DCU key of its own.</returns>
function ProjectOf( const AName: string; const ADependsOn: array of Integer ): TParallelProject;
begin

  Result := Default( TParallelProject );
  Result.FileName := 'C:\G\' + AName + '\' + AName + '.dproj';
  Result.Config   := 'Release';
  Result.Platform := 'Win64';
  Result.LockKey  := 'C:\G\' + UpperCase( AName );

  SetLength( Result.DependsOn, Length( ADependsOn ) );

  for var iI := 0 to High( ADependsOn ) do
    Result.DependsOn[ iI ] := ADependsOn[ iI ];

end;

{ TTestParallelBuildRunner }

procedure TTestParallelBuildRunner.Setup;
begin

  FDir := TPath.Combine( ExcludeTrailingPathDelimiter( TPath.GetTempPath ), 'DDevExtPB_' + TPath.GetGUIDFileName );
  TDirectory.CreateDirectory( FDir );

  FComSpec := GetEnvironmentVariable( 'ComSpec' );

  FLock           := TCriticalSection.Create;
  FCalls          := TList<string>.Create;
  FFinished       := TList<string>.Create;
  FStartedIndexes := TList<Integer>.Create;
  FEventThreads   := TList<TThreadID>.Create;
  FTwoRunning     := TEvent.Create( nil, True, False, '' );
  FStarted        := TEvent.Create( nil, True, False, '' );
  FRunning        := 0;
  FMaxRunning     := 0;
  FAlone          := 0;

end;

procedure TTestParallelBuildRunner.TearDown;
begin

  FStarted.Free;
  FTwoRunning.Free;
  FEventThreads.Free;
  FStartedIndexes.Free;
  FFinished.Free;
  FCalls.Free;
  FLock.Free;

  if TDirectory.Exists( FDir ) then TDirectory.Delete( FDir, True );

end;

procedure TTestParallelBuildRunner.NoteCall( const AProject: TParallelProject );
begin

  FLock.Enter;
  try
    FCalls.Add( ChangeFileExt( ExtractFileName( AProject.FileName ), '' ) );
  finally
    FLock.Leave;
  end;

end;

function TTestParallelBuildRunner.WriteFile( const AName, AText: string ): string;
begin

  Result := TPath.Combine( FDir, AName );
  TFile.WriteAllText( Result, AText, TEncoding.ANSI );

end;

function TTestParallelBuildRunner.WriteCommandFile( const AName, ALine: string; AExitCode: Integer ): string;
begin

  var sText := '@echo off'#13#10;

  if ALine <> '' then sText := sText + 'echo ' + ALine + #13#10;

  Result := WriteFile( AName, sText + 'exit ' + IntToStr( AExitCode ) + #13#10 );

end;

function TTestParallelBuildRunner.AppProject( const AConfig: string ): TParallelProject;
begin

  Result := Default( TParallelProject );
  Result.FileName := WriteFile( 'App.dproj', APP_DPROJ );
  Result.Config   := AConfig;
  Result.Platform := 'Win64';
  Result.Kind     := pkApplication;
  Result.LockKey  := UpperCase( FDir );

end;

function TTestParallelBuildRunner.QuickBuild: TProjectBuildFunc;
begin

  Result :=
    function( const AProject: TParallelProject; const ACancelled: TCancelCheck ): TProjectResult
    begin
      Result := Default( TProjectResult );
      NoteCall( AProject );
      Result.Succeeded := True;
    end;

end;

function TTestParallelBuildRunner.BuildUntilCancelled: TProjectBuildFunc;
begin

  Result :=
    function( const AProject: TParallelProject; const ACancelled: TCancelCheck ): TProjectResult
    begin
      Result := Default( TProjectResult );
      NoteCall( AProject );
      FStarted.SetEvent;
      var oWatch := TStopwatch.StartNew;
      while ( not ACancelled( ) ) and ( oWatch.ElapsedMilliseconds < WAIT_MS ) do
        Sleep( 5 );
      Result.Cancelled := ACancelled( );
      Result.Notes     := [ 'cancelled' ];
    end;

end;

procedure TTestParallelBuildRunner.RecordEvents( ABuild: TParallelBuild );
begin

  // Both events are raised on the co-ordinator's thread only, so the lists need no lock.
  ABuild.OnStarted :=
    procedure( AIndex: Integer )
    begin
      FStartedIndexes.Add( AIndex );
      if not FEventThreads.Contains( TThread.CurrentThread.ThreadID ) then FEventThreads.Add( TThread.CurrentThread.ThreadID );
    end;
  ABuild.OnFinished :=
    procedure( AIndex: Integer; AState: TProjectState; const AResult: TProjectResult )
    begin
      var sNote := '';
      if Length( AResult.Notes ) > 0 then sNote := AResult.Notes[ 0 ];
      FFinished.Add( Format( '%d:%d:%s', [ AIndex, Ord( AState ), sNote ] ) );
      if not FEventThreads.Contains( TThread.CurrentThread.ThreadID ) then FEventThreads.Add( TThread.CurrentThread.ThreadID );
    end;

end;

procedure TTestParallelBuildRunner.TestRunCapturedOutput;
begin

  var rRun := RunCaptured( FComSpec + ' /d /c echo hello from the child', '', '', nil );

  Assert.IsTrue( rRun.Started );
  Assert.AreEqual<Cardinal>( 0, rRun.OSError );
  Assert.AreEqual<Cardinal>( 0, rRun.ExitCode );
  Assert.IsFalse( rRun.Cancelled );
  Assert.AreEqual( 'hello from the child', Trim( rRun.Output ), False );

end;

procedure TTestParallelBuildRunner.TestRunCapturedStandardError;
begin

  var rRun := RunCaptured( FComSpec + ' /d /c echo to stderr 1>&2', '', '', nil );

  Assert.IsTrue( rRun.Started );
  Assert.AreEqual( 'to stderr', Trim( rRun.Output ), False );

end;

procedure TTestParallelBuildRunner.TestRunCapturedExitCode;
begin

  var rRun := RunCaptured( FComSpec + ' /d /c exit 7', '', '', nil );

  Assert.IsTrue( rRun.Started );
  Assert.AreEqual<Cardinal>( 7, rRun.ExitCode );
  Assert.IsFalse( rRun.Cancelled );

end;

procedure TTestParallelBuildRunner.TestRunCapturedMissingProgram;
begin

  var rRun := RunCaptured( TPath.Combine( FDir, 'no_such_program.exe' ) + ' /x', '', '', nil );

  Assert.IsFalse( rRun.Started );
  // ERROR_FILE_NOT_FOUND: the folder exists, the program does not.
  Assert.AreEqual<Cardinal>( 2, rRun.OSError );
  Assert.IsFalse( rRun.Cancelled );
  Assert.AreEqual( '', rRun.Output, False );

end;

procedure TTestParallelBuildRunner.TestRunCapturedWorkingFolder;
begin

  var rRun := RunCaptured( FComSpec + ' /d /c cd', FDir, '', nil );

  Assert.IsTrue( rRun.Started );
  Assert.AreEqual( FDir, Trim( rRun.Output ), True );

end;

procedure TTestParallelBuildRunner.TestRunCapturedEnvironment;
begin

  var sBlock := EnvironmentBlock( [ 'PB_TEST_VALUE=from the block', 'SystemRoot=' + GetEnvironmentVariable( 'SystemRoot' ) ] );
  var rRun   := RunCaptured( FComSpec + ' /d /c echo %PB_TEST_VALUE%', '', sBlock, nil );

  Assert.IsTrue( rRun.Started );
  Assert.AreEqual( 'from the block', Trim( rRun.Output ), False );

end;

procedure TTestParallelBuildRunner.TestRunCapturedUnicodeOutput;
begin

  // The euro sign is not in the OEM code page 437 or 850, so it survives only as UTF-16.
  var sText := 'cost ' + #$20AC + '5';
  var rRun  := RunCaptured( FComSpec + ' /d /u /c echo ' + sText, '', '', nil, True );

  Assert.IsTrue( rRun.Started );
  Assert.AreEqual( sText, Trim( rRun.Output ), False );

end;

procedure TTestParallelBuildRunner.TestRunCapturedCancel;
begin

  // ping runs as a child of cmd for about a minute; both must die.
  var oWatch := TStopwatch.StartNew;
  var rRun   := RunCaptured( FComSpec + ' /d /c ping -n 60 127.0.0.1', '', '',
    function: Boolean
    begin
      Result := oWatch.ElapsedMilliseconds > 300;
    end );

  Assert.IsTrue( rRun.Started );
  Assert.IsTrue( rRun.Cancelled, 'the run was not reported as cancelled' );
  Assert.IsTrue( oWatch.ElapsedMilliseconds < WAIT_MS, 'the cancel did not end the process promptly' );

end;

procedure TTestParallelBuildRunner.TestCaptureEnvironmentMissingFile;
var
  saVariables       : TArray<string>;
  sError            : string;
begin

  var sFile := TPath.Combine( FDir, 'rsvars.bat' );

  Assert.IsFalse( CaptureEnvironment( sFile, saVariables, sError ) );
  Assert.AreEqual( 'rsvars.bat was not found at ' + sFile, sError, False );

end;

procedure TTestParallelBuildRunner.TestCaptureEnvironmentFailingFile;
var
  saVariables       : TArray<string>;
  sError            : string;
begin

  Assert.IsFalse( CaptureEnvironment( WriteCommandFile( 'rsvars.bat', '', 3 ), saVariables, sError ) );
  Assert.AreEqual( 'rsvars.bat ended with exit code 3', sError, False );

end;

procedure TTestParallelBuildRunner.TestCaptureEnvironmentWithoutFrameworkDir;
var
  saVariables       : TArray<string>;
  sError            : string;
begin

  // Cleared explicitly, in case the test runner was itself started from an RAD Studio command prompt.
  Assert.IsFalse( CaptureEnvironment( WriteFile( 'rsvars.bat', '@set FrameworkDir='#13#10'@set PB_OTHER=1'#13#10 ), saVariables, sError ) );
  Assert.AreEqual( 'rsvars.bat did not set FrameworkDir, so MSBuild cannot be found', sError, False );

end;

procedure TTestParallelBuildRunner.TestCaptureEnvironmentSuccess;
var
  saVariables       : TArray<string>;
  sError            : string;
begin

  TDirectory.CreateDirectory( TPath.Combine( FDir, 'bin dir' ) );

  var sFile := WriteFile( 'bin dir\rsvars.bat', '@set FrameworkDir=C:\Fw\v4.0'#13#10'@set PB_OTHER=a b=c'#13#10 );

  Assert.IsTrue( CaptureEnvironment( sFile, saVariables, sError ), sError );
  Assert.AreEqual( '', sError, False );
  Assert.AreEqual( 'C:\Fw\v4.0', EnvironmentValue( saVariables, 'FrameworkDir' ), False );
  Assert.AreEqual( 'a b=c', EnvironmentValue( saVariables, 'PB_OTHER' ), False );
  // The caller's own environment comes through as well; MSBuild needs it.
  Assert.AreNotEqual( '', EnvironmentValue( saVariables, 'SystemRoot' ), False );

end;

procedure TTestParallelBuildRunner.TestBuildRunsProjectsTogether;
begin

  var oBuild := TParallelBuild.Create( [ ProjectOf( 'A', [ ] ), ProjectOf( 'B', [ ] ), ProjectOf( 'C', [ ] ), ProjectOf( 'D', [ ] ) ], 2,
    function( const AProject: TParallelProject; const ACancelled: TCancelCheck ): TProjectResult
    begin
      Result := Default( TProjectResult );
      NoteCall( AProject );
      FLock.Enter;
      try
        Inc( FRunning );
        if FRunning > FMaxRunning then FMaxRunning := FRunning;
        if FRunning >= 2 then FTwoRunning.SetEvent;
      finally
        FLock.Leave;
      end;
      // Each build stays until two have been seen running together, so a one-at-a-time co-ordinator is caught.
      if FTwoRunning.WaitFor( WAIT_MS ) <> wrSignaled then TInterlocked.Increment( FAlone );
      FLock.Enter;
      try
        Dec( FRunning );
      finally
        FLock.Leave;
      end;
      Result.Succeeded := True;
    end );
  try
    oBuild.Start;
    oBuild.WaitFor;

    Assert.AreEqual( 0, FAlone, 'a project never had another building beside it' );
    Assert.AreEqual( 2, FMaxRunning, 'the worker count was not honoured' );
    Assert.AreEqual( 2, oBuild.PeakRunning );
    Assert.AreEqual( 4, FCalls.Count );

    for var iI := 0 to 3 do
      Assert.AreEqual( psSucceeded, oBuild.FinalStates[ iI ] );
  finally
    oBuild.Free;
  end;

end;

procedure TTestParallelBuildRunner.TestBuildRaisesEvents;
begin

  var oBuild := TParallelBuild.Create( [ ProjectOf( 'A', [ ] ), ProjectOf( 'B', [ 0 ] ) ], 4, QuickBuild( ) );
  try
    RecordEvents( oBuild );
    oBuild.Start;
    oBuild.WaitFor;

    Assert.AreEqual( 2, FStartedIndexes.Count );
    Assert.AreEqual( 0, FStartedIndexes[ 0 ] );
    Assert.AreEqual( 1, FStartedIndexes[ 1 ] );
    Assert.AreEqual( 2, FFinished.Count );
    Assert.AreEqual( Format( '0:%d:', [ Ord( psSucceeded ) ] ), FFinished[ 0 ], False );
    Assert.AreEqual( Format( '1:%d:', [ Ord( psSucceeded ) ] ), FFinished[ 1 ], False );
    Assert.AreEqual( 1, FEventThreads.Count, 'the events came from more than one thread' );
    Assert.AreNotEqual<TThreadID>( TThread.CurrentThread.ThreadID, FEventThreads[ 0 ] );
    Assert.IsFalse( oBuild.Cancelled );
  finally
    oBuild.Free;
  end;

end;

procedure TTestParallelBuildRunner.TestBuildSkipsDependentsOfFailure;
begin

  var oBuild := TParallelBuild.Create( [ ProjectOf( 'A', [ ] ), ProjectOf( 'B', [ 0 ] ), ProjectOf( 'C', [ ] ) ], 1,
    function( const AProject: TParallelProject; const ACancelled: TCancelCheck ): TProjectResult
    begin
      Result := Default( TProjectResult );
      NoteCall( AProject );
      Result.Succeeded := not AProject.FileName.EndsWith( 'A.dproj' );
    end );
  try
    RecordEvents( oBuild );
    oBuild.Start;
    oBuild.WaitFor;

    Assert.AreEqual( psFailed, oBuild.FinalStates[ 0 ] );
    Assert.AreEqual( psSkipped, oBuild.FinalStates[ 1 ] );
    Assert.AreEqual( psSucceeded, oBuild.FinalStates[ 2 ] );
    Assert.IsFalse( FCalls.Contains( 'B' ), 'the dependent of a failed project was built' );
    Assert.IsTrue( FCalls.Contains( 'C' ), 'an unrelated project was not built' );
    Assert.IsTrue( FFinished.Contains( Format( '1:%d:not built: A did not build', [ Ord( psSkipped ) ] ) ), 'no skip report for B' );
    Assert.AreEqual( 3, FFinished.Count );
  finally
    oBuild.Free;
  end;

end;

procedure TTestParallelBuildRunner.TestBuildSurvivesRaisingBuildFunction;
begin

  var oBuild := TParallelBuild.Create( [ ProjectOf( 'A', [ ] ), ProjectOf( 'B', [ ] ) ], 1,
    function( const AProject: TParallelProject; const ACancelled: TCancelCheck ): TProjectResult
    begin
      Result := Default( TProjectResult );
      if AProject.FileName.EndsWith( 'A.dproj' ) then raise EArgumentException.Create( 'boom' );
      Result.Succeeded := True;
    end );
  try
    RecordEvents( oBuild );
    oBuild.Start;
    oBuild.WaitFor;

    Assert.AreEqual( psFailed, oBuild.FinalStates[ 0 ] );
    Assert.AreEqual( psSucceeded, oBuild.FinalStates[ 1 ] );
    Assert.AreEqual( Format( '0:%d:EArgumentException: boom', [ Ord( psFailed ) ] ), FFinished[ 0 ], False );
  finally
    oBuild.Free;
  end;

end;

procedure TTestParallelBuildRunner.TestBuildCancel;
begin

  var oBuild := TParallelBuild.Create( [ ProjectOf( 'A', [ ] ), ProjectOf( 'B', [ ] ), ProjectOf( 'C', [ ] ) ], 1, BuildUntilCancelled( ) );
  try
    RecordEvents( oBuild );
    oBuild.Start;
    Assert.AreEqual( wrSignaled, FStarted.WaitFor( WAIT_MS ), 'no project started' );

    var oWatch := TStopwatch.StartNew;
    oBuild.Cancel;
    oBuild.WaitFor;

    Assert.IsTrue( oWatch.ElapsedMilliseconds < WAIT_MS div 2, 'the running project was not told to stop' );
    Assert.IsTrue( oBuild.Cancelled );
    Assert.AreEqual( 1, FCalls.Count, 'a project started after the cancel' );
    Assert.AreEqual( psFailed, oBuild.FinalStates[ 0 ] );
    Assert.AreEqual( psSkipped, oBuild.FinalStates[ 1 ] );
    Assert.AreEqual( psSkipped, oBuild.FinalStates[ 2 ] );
    Assert.IsTrue( FFinished.Contains( Format( '2:%d:not built: the build was cancelled', [ Ord( psSkipped ) ] ) ), 'no skip report for C' );
  finally
    oBuild.Free;
  end;

end;

procedure TTestParallelBuildRunner.TestBuildFreeWhileRunning;
begin

  var oBuild := TParallelBuild.Create( [ ProjectOf( 'A', [ ] ), ProjectOf( 'B', [ ] ) ], 1, BuildUntilCancelled( ) );
  var oWatch := TStopwatch.StartNew;
  try
    RecordEvents( oBuild );
    oBuild.Start;
    Assert.AreEqual( wrSignaled, FStarted.WaitFor( WAIT_MS ), 'no project started' );
    oWatch := TStopwatch.StartNew;
  finally
    oBuild.Free;
  end;

  Assert.IsTrue( oWatch.ElapsedMilliseconds < WAIT_MS div 2, 'freeing the build waited for the project to time out' );
  Assert.AreEqual( 1, FCalls.Count );
  // The co-ordinator ran to its end: both projects were reported before Free returned.
  Assert.AreEqual( 2, FFinished.Count );

end;

procedure TTestParallelBuildRunner.TestActionCompilerError;
var
  rSettings         : TMSBuildSettings;
begin

  rSettings := Default( TMSBuildSettings );
  rSettings.MSBuildExe := WriteCommandFile( 'fakebuild.cmd', 'U.pas(5): error E2003: Undeclared identifier: ''x''', 1 );

  var rResult := MSBuildAction( rSettings )( AppProject( 'Release' ), nil );

  Assert.IsFalse( rResult.Succeeded );
  Assert.IsFalse( rResult.Cancelled );
  Assert.AreEqual( 1, Length( rResult.Diagnostics ) );
  Assert.AreEqual( dkError, rResult.Diagnostics[ 0 ].Kind );
  Assert.AreEqual( 'E2003', rResult.Diagnostics[ 0 ].Code, False );
  Assert.AreEqual( 0, Length( rResult.Notes ), 'the error line already says why' );

end;

procedure TTestParallelBuildRunner.TestActionHintStillSucceeds;
var
  rSettings         : TMSBuildSettings;
begin

  rSettings := Default( TMSBuildSettings );
  rSettings.MSBuildExe := WriteCommandFile( 'fakebuild.cmd', 'U.pas(9): Hint warning H2164: Variable ''i'' is declared but never used', 0 );

  var rResult := MSBuildAction( rSettings )( AppProject( 'Release' ), nil );

  Assert.IsTrue( rResult.Succeeded );
  Assert.AreEqual( 1, Length( rResult.Diagnostics ) );
  Assert.AreEqual( dkHint, rResult.Diagnostics[ 0 ].Kind );
  Assert.AreEqual( 0, Length( rResult.Notes ) );

end;

procedure TTestParallelBuildRunner.TestActionExitCodeWithoutError;
var
  rSettings         : TMSBuildSettings;
begin

  rSettings := Default( TMSBuildSettings );
  rSettings.MSBuildExe := WriteCommandFile( 'fakebuild.cmd', 'something went wrong', 2 );

  var rResult := MSBuildAction( rSettings )( AppProject( 'Release' ), nil );

  Assert.IsFalse( rResult.Succeeded );
  Assert.AreEqual( 1, Length( rResult.Notes ) );
  Assert.AreEqual( 'MSBuild ended with exit code 2', rResult.Notes[ 0 ], False );
  Assert.AreEqual( 'something went wrong', Trim( rResult.Output ), False );

end;

procedure TTestParallelBuildRunner.TestActionMSBuildMissing;
var
  rSettings         : TMSBuildSettings;
begin

  rSettings := Default( TMSBuildSettings );
  rSettings.MSBuildExe := TPath.Combine( FDir, 'NoMSBuild.exe' );

  var rResult := MSBuildAction( rSettings )( AppProject( 'Release' ), nil );

  Assert.IsFalse( rResult.Succeeded );
  Assert.AreEqual( 1, Length( rResult.Notes ) );
  Assert.AreEqual( 'MSBuild could not be started: ' + SysErrorMessage( 2 ), rResult.Notes[ 0 ], False );

end;

procedure TTestParallelBuildRunner.TestActionProjectFileMissing;
var
  rSettings         : TMSBuildSettings;
  rResult           : TProjectResult;
begin

  rSettings := Default( TMSBuildSettings );
  rSettings.MSBuildExe := WriteCommandFile( 'fakebuild.cmd', '', 0 );

  var rProject := AppProject( 'Release' );
  rProject.FileName := TPath.Combine( FDir, 'Gone.dproj' );

  Assert.WillNotRaiseAny(
    procedure
    begin
      rResult := MSBuildAction( rSettings )( rProject, nil );
    end );
  Assert.IsFalse( rResult.Succeeded );
  Assert.AreEqual( 1, Length( rResult.Notes ) );
  Assert.StartsWith( 'EFileNotFoundException: ', rResult.Notes[ 0 ], False );

end;

procedure TTestParallelBuildRunner.TestActionEurekaLogNotInstalled;
var
  rSettings         : TMSBuildSettings;
begin

  rSettings := Default( TMSBuildSettings );
  rSettings.MSBuildExe   := WriteCommandFile( 'fakebuild.cmd', '', 0 );
  rSettings.RunEurekaLog := True;
  rSettings.Ecc32Exe     := TPath.Combine( FDir, 'ecc32.exe' );
  WriteFile( 'App.eof', '[Exception Log]'#13#10 );

  var rResult := MSBuildAction( rSettings )( AppProject( 'Release' ), nil );

  Assert.IsTrue( rResult.Succeeded, 'a missing EurekaLog must not fail the build' );
  Assert.AreEqual( 1, Length( rResult.Notes ) );
  Assert.AreEqual( 'EurekaLog: not post-processed, ecc32.exe was not found at ' + rSettings.Ecc32Exe, rResult.Notes[ 0 ], False );

end;

procedure TTestParallelBuildRunner.TestActionEurekaLogPostProcessed;
var
  rSettings         : TMSBuildSettings;
begin

  rSettings := Default( TMSBuildSettings );
  rSettings.MSBuildExe   := WriteCommandFile( 'fakebuild.cmd', '', 0 );
  rSettings.RunEurekaLog := True;
  rSettings.Ecc32Exe     := WriteCommandFile( 'fakeecc.cmd', 'ecc ran', 0 );
  WriteFile( 'App.eof', '[Exception Log]'#13#10 );
  WriteFile( 'App.exe', 'not really' );

  var sEldbg  := WriteFile( 'App.eldbg', 'debug' );
  var rResult := MSBuildAction( rSettings )( AppProject( 'Release' ), nil );

  Assert.IsTrue( rResult.Succeeded );
  Assert.AreEqual( 1, Length( rResult.Notes ) );
  Assert.AreEqual( 'EurekaLog: post-processed', rResult.Notes[ 0 ], False );
  Assert.Contains( rResult.Output, 'ecc ran', False );
  Assert.IsFalse( TFile.Exists( sEldbg ), 'the .eldbg was left behind' );

end;

procedure TTestParallelBuildRunner.TestActionEurekaLogFailure;
var
  rSettings         : TMSBuildSettings;
begin

  rSettings := Default( TMSBuildSettings );
  rSettings.MSBuildExe   := WriteCommandFile( 'fakebuild.cmd', '', 0 );
  rSettings.RunEurekaLog := True;
  rSettings.Ecc32Exe     := WriteCommandFile( 'fakeecc.cmd', 'ecc failed', 5 );
  WriteFile( 'App.eof', '[Exception Log]'#13#10 );
  WriteFile( 'App.exe', 'not really' );

  var sEldbg  := WriteFile( 'App.eldbg', 'debug' );
  var rResult := MSBuildAction( rSettings )( AppProject( 'Release' ), nil );

  Assert.IsFalse( rResult.Succeeded, 'a failed injection must fail the project' );
  Assert.AreEqual( 1, Length( rResult.Notes ) );
  Assert.AreEqual( 'EurekaLog: FAILED ( ecc32 exit code 5 ) - do not deploy App.exe', rResult.Notes[ 0 ], False );
  Assert.IsTrue( TFile.Exists( sEldbg ), 'nothing is tidied after a failure' );

end;

procedure TTestParallelBuildRunner.TestActionEurekaLogOutputMissing;
var
  rSettings         : TMSBuildSettings;
begin

  rSettings := Default( TMSBuildSettings );
  rSettings.MSBuildExe   := WriteCommandFile( 'fakebuild.cmd', '', 0 );
  rSettings.RunEurekaLog := True;
  rSettings.Ecc32Exe     := WriteCommandFile( 'fakeecc.cmd', 'ecc ran', 0 );
  WriteFile( 'App.eof', '[Exception Log]'#13#10 );

  var rResult := MSBuildAction( rSettings )( AppProject( 'Release' ), nil );

  Assert.IsFalse( rResult.Succeeded );
  Assert.AreEqual( 1, Length( rResult.Notes ) );
  Assert.AreEqual( 'EurekaLog: FAILED, the built file was not found at ' + TPath.Combine( FDir, 'App.exe' ), rResult.Notes[ 0 ], False );

end;

procedure TTestParallelBuildRunner.TestActionEurekaLogNotDue;
var
  rSettings         : TMSBuildSettings;
begin

  rSettings := Default( TMSBuildSettings );
  rSettings.MSBuildExe   := WriteCommandFile( 'fakebuild.cmd', '', 0 );
  rSettings.RunEurekaLog := True;
  // Would fail the project if it ran.
  rSettings.Ecc32Exe     := WriteCommandFile( 'fakeecc.cmd', 'ecc ran', 5 );
  WriteFile( 'App.eof', '[Exception Log]'#13#10 );
  WriteFile( 'App.exe', 'not really' );

  var rResult := MSBuildAction( rSettings )( AppProject( 'Debug' ), nil );

  Assert.IsTrue( rResult.Succeeded, 'ecc32 ran for a Debug build' );
  Assert.AreEqual( 0, Length( rResult.Notes ) );

  rSettings.RunEurekaLog := False;
  rResult := MSBuildAction( rSettings )( AppProject( 'Release' ), nil );

  Assert.IsTrue( rResult.Succeeded, 'ecc32 ran with the setting off' );
  Assert.AreEqual( 0, Length( rResult.Notes ) );

end;

procedure TTestParallelBuildRunner.TestActionCancelBeforeEurekaLog;
var
  rSettings         : TMSBuildSettings;
begin

  // The stand-in MSBuild leaves a marker as its last act, and the cancel check turns True once the marker is there.
  var sBuilt  := TPath.Combine( FDir, 'built.marker' );
  var sEccRan := TPath.Combine( FDir, 'ecc.marker' );

  rSettings := Default( TMSBuildSettings );
  rSettings.MSBuildExe   := WriteFile( 'fakebuild.cmd', '@echo off'#13#10'echo x> ' + sBuilt + #13#10'exit 0'#13#10 );
  rSettings.RunEurekaLog := True;
  rSettings.Ecc32Exe     := WriteFile( 'fakeecc.cmd', '@echo off'#13#10'echo x> ' + sEccRan + #13#10'exit 0'#13#10 );
  WriteFile( 'App.eof', '[Exception Log]'#13#10 );
  WriteFile( 'App.exe', 'not really' );

  var rResult := MSBuildAction( rSettings )( AppProject( 'Release' ),
    function: Boolean
    begin
      Result := TFile.Exists( sBuilt );
    end );

  Assert.IsTrue( TFile.Exists( sBuilt ), 'the stand-in MSBuild did not run' );
  Assert.IsFalse( TFile.Exists( sEccRan ), 'ecc32 was started after the cancel' );
  Assert.IsFalse( rResult.Succeeded, 'a built but not post-processed file was reported as a success' );
  Assert.IsTrue( rResult.Cancelled );
  Assert.AreEqual( 1, Length( rResult.Notes ) );
  Assert.AreEqual( 'cancelled', rResult.Notes[ 0 ], False );

end;

initialization
  TDUnitX.RegisterTestFixture( TTestParallelBuildRunner );

end.
