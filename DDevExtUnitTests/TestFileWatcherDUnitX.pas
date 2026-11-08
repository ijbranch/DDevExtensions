unit TestFileWatcherDUnitX;

/// <summary>
/// DUnitX test fixture for <c>FileWatcher</c>, the directory watcher behind External Mod Monitor.
/// Uses real folders under %TEMP% and pumps <c>CheckSynchronize</c>, because the change callback
/// is queued to the main thread.
/// </summary>

interface

uses
  System.SysUtils, DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising <c>TFileWatcher</c>.</summary>
  [ TestFixture ]
  TTestFileWatcher = class
  private
    /// <summary>Root scratch folder for the test, deleted in TearDown.</summary>
    FRoot: string;
    /// <summary>Full path of the last matching file reported by the watcher.</summary>
    FChanged: string;
    /// <summary>When set, only a report of this file is recorded in FChanged.</summary>
    FExpected: string;
    /// <summary>Records FileName as the last change reported.</summary>
    /// <param name="FileName">Full path of the modified file.</param>
    procedure HandleChange( const FileName: string );
    /// <summary>Pumps queued main-thread calls until a change is reported or ATimeoutMs passes.</summary>
    /// <param name="ATimeoutMs">Maximum wait in milliseconds.</param>
    /// <returns>True when a change was reported in time.</returns>
    function WaitForChange( ATimeoutMs: Cardinal ): Boolean;
    /// <summary>
    /// Repeats AAction until the watcher reports AExpected or ATimeoutMs passes.  Replaces a fixed
    /// start-up sleep: the worker issues its first read asynchronously, so a change made before
    /// that is not seen, and repeating the change is the only portable readiness test.
    /// </summary>
    /// <param name="AAction">Makes one change to the watched folder.</param>
    /// <param name="AExpected">Full path the watcher must report.</param>
    /// <param name="ATimeoutMs">Overall time limit in milliseconds.</param>
    /// <returns>True when AExpected was reported in time.</returns>
    function RepeatUntilReported( const AAction: TProc; const AExpected: string; ATimeoutMs: Cardinal ): Boolean;
  public
    /// <summary>Creates the scratch root folder.</summary>
    [ Setup ]
    procedure Setup;
    /// <summary>Deletes the scratch root folder and everything below it.</summary>
    [ TearDown ]
    procedure TearDown;
    /// <summary>Proves a modification in a single watched folder is reported with its full path.</summary>
    [ Test ]
    procedure TestReportsModification;
    /// <summary>
    /// Proves more than 62 watched folders still work: a change in the last folder is reported
    /// and ClearWatches returns promptly.  The old WaitForMultipleObjects loop failed past 64
    /// handles and reported nothing from any folder.
    /// </summary>
    [ Test ]
    procedure TestMoreThan62FoldersAndPromptStop;
    /// <summary>
    /// Proves a save made by renaming a temporary file over the original (delete, then rename) is
    /// reported under the original name.  Only in-place writes were reported before.
    /// </summary>
    [ Test ]
    procedure TestReportsRenameIntoPlace;
  end;

implementation

uses
  Winapi.Windows, System.Classes, System.IOUtils, FileWatcher;

procedure TTestFileWatcher.Setup;
begin
  FRoot             := TPath.Combine( TPath.GetTempPath, 'DDevExtWatchTest' + IntToStr( GetCurrentProcessId ) );
  TDirectory.CreateDirectory( FRoot );
  FChanged          := '';
end;

procedure TTestFileWatcher.TearDown;
begin
  TDirectory.Delete( FRoot, True );
end;

procedure TTestFileWatcher.HandleChange( const FileName: string );
begin
  if ( FExpected = '' ) or SameText( FileName, FExpected ) then
    FChanged        := FileName;
end;

function TTestFileWatcher.RepeatUntilReported( const AAction: TProc; const AExpected: string; ATimeoutMs: Cardinal ): Boolean;
begin
  FExpected         := AExpected;
  FChanged          := '';
  var iStart        := GetTickCount64;
  repeat
    AAction( );
    if WaitForChange( 500 ) then
      Exit( True );
  until GetTickCount64 - iStart >= ATimeoutMs;
  Result            := False;
end;

function TTestFileWatcher.WaitForChange( ATimeoutMs: Cardinal ): Boolean;
begin
  var iStart        := GetTickCount64;
  while ( FChanged = '' ) and ( GetTickCount64 - iStart < ATimeoutMs ) do
  begin
    CheckSynchronize( 20 );
    Sleep( 10 );
  end;
  Result            := FChanged <> '';
end;

/// <summary>Creates AFile with a little initial content, so a later append is a modification.</summary>
/// <param name="AFile">Full path of the file to create.</param>
procedure CreateFileQuietly( const AFile: string );
begin
  TFile.WriteAllText( AFile, 'one' );
end;

procedure TTestFileWatcher.TestReportsModification;
begin
  var sDir          := TPath.Combine( FRoot, 'single' );
  TDirectory.CreateDirectory( sDir );
  var sFile         := TPath.Combine( sDir, 'Unit1.pas' );
  CreateFileQuietly( sFile );

  var oWatcher      := TFileWatcher.Create;
  try
    oWatcher.OnFileChanged := HandleChange;
    oWatcher.AddWatch( sDir );
    Assert.IsTrue( RepeatUntilReported(
        procedure
        begin
          TFile.AppendAllText( sFile, 'two' );
        end, sFile, 10000 ), 'No change reported' );
    Assert.AreEqual( sFile, FChanged, True );
  finally
    oWatcher.Free;
  end;
end;

procedure TTestFileWatcher.TestMoreThan62FoldersAndPromptStop;
const
  cFolders          = 70;
begin
  var sLastFile     := '';
  var oWatcher      := TFileWatcher.Create;
  oWatcher.OnFileChanged := HandleChange;
  for var iIndex: Integer := 1 to cFolders do
  begin
    var sDir        := TPath.Combine( FRoot, 'D' + IntToStr( iIndex ) );
    TDirectory.CreateDirectory( sDir );
    sLastFile       := TPath.Combine( sDir, 'Unit1.pas' );
    CreateFileQuietly( sLastFile );
    oWatcher.AddWatch( sDir );
  end;

  var sTarget       := sLastFile;
  var bChanged      := RepeatUntilReported(
    procedure
    begin
      TFile.AppendAllText( sTarget, 'two' );
    end, sTarget, 10000 );

  var oStopper      := TThread.CreateAnonymousThread(
    procedure
    begin
      oWatcher.ClearWatches;
    end );
  oStopper.FreeOnTerminate := False;
  oStopper.Start;
  var bStopped      := WaitForSingleObject( oStopper.Handle, 5000 ) = WAIT_OBJECT_0;
  if bStopped then
  begin
    oStopper.Free;
    oWatcher.Free;
  end; // else both are leaked on purpose: freeing them would hang the test run

  Assert.IsTrue( bStopped, 'ClearWatches did not return within 5 s' );
  Assert.IsTrue( bChanged, 'No change reported from folder ' + IntToStr( cFolders ) );
  Assert.AreEqual( sLastFile, FChanged, True );
end;

procedure TTestFileWatcher.TestReportsRenameIntoPlace;
begin
  var sDir          := TPath.Combine( FRoot, 'rename' );
  TDirectory.CreateDirectory( sDir );
  var sFile         := TPath.Combine( sDir, 'Unit1.pas' );
  var sTemp         := TPath.Combine( sDir, 'Unit1.pas.tmp' );
  CreateFileQuietly( sFile );

  var oWatcher      := TFileWatcher.Create;
  try
    oWatcher.OnFileChanged := HandleChange;
    oWatcher.AddWatch( sDir );
    Assert.IsTrue( RepeatUntilReported(
        procedure
        begin
          CreateFileQuietly( sTemp );
          TFile.Delete( sFile );
          TFile.Move( sTemp, sFile );
        end, sFile, 10000 ), 'No change reported' );
    Assert.AreEqual( sFile, FChanged, True );
  finally
    oWatcher.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestFileWatcher );

end.

