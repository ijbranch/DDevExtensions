unit TestLibraryPathBackupsDUnitX;

/// <summary>
/// DUnitX fixture for <c>LibraryPathBackups.TLibraryPathBackupManager</c>, the backup
/// history the IDE Path Sorter and IDE Path Compactor share. Each test works on its own
/// history file in a fresh temporary folder.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Tests that the shared backup history never loses, mis-dates or silently discards a backup.</summary>
  [TestFixture]
  TTestLibraryPathBackups = class
  private
    /// <summary>Temporary folder holding this test's history file.</summary>
    FFolder: string;
    /// <summary>The history file under test.</summary>
    FFileName: string;
  public
    /// <summary>Initialises COM for MSXML and creates the temporary folder.</summary>
    [Setup]
    procedure Setup;
    /// <summary>Deletes the temporary folder and releases COM.</summary>
    [TearDown]
    procedure TearDown;

    /// <summary>
    /// Two managers on one file (the Sorter's and the Compactor's, or two IDEs) never erase each
    /// other's backups: each change reloads the file first. The earlier manager saved its stale
    /// in-memory list over the file and lost the other's entries (audit E3).
    /// </summary>
    [Test]
    procedure TestTwoManagersKeepEachOthersBackups;
    /// <summary>
    /// A pinned ("Before compaction") backup survives any number of later backups of the same set;
    /// only unpinned ones are trimmed to the cap (audit E24).
    /// </summary>
    [Test]
    procedure TestPinnedBackupNeverTrimmed;
    /// <summary>
    /// Timestamps are written in ISO 8601 and read back to the second, whatever the locale
    /// (audit E25).
    /// </summary>
    [Test]
    procedure TestTimestampRoundTripsAsIso8601;
    /// <summary>
    /// A history written by an older build (no Id, locale timestamp) still loads, gets an Id that is
    /// the same on every read and across a save, and can be deleted by it. Its locale timestamp is
    /// never interpreted (day and month could swap) and survives a save unchanged (audit E25).
    /// </summary>
    [Test]
    procedure TestLegacyEntryHasStableIdAndCanBeDeleted;
    /// <summary>
    /// The older builds' history file is imported while the new file does not exist, is never
    /// written, and stops feeding the new history once that exists, so a build of either age cannot
    /// damage the other's history.
    /// </summary>
    [Test]
    procedure TestOlderBuildsFileImportedReadOnly;
    /// <summary>
    /// An unreadable history is moved aside to a <c>.corrupt-*</c> file and reported, never silently
    /// replaced by the next backup (audit E17).
    /// </summary>
    [Test]
    procedure TestCorruptHistoryIsSetAsideAndReported;
  end;

implementation

uses
  Winapi.Windows, Winapi.ActiveX, System.SysUtils, System.IOUtils, System.DateUtils,
  PathCompactorCore, LibraryPathBackups;

procedure TTestLibraryPathBackups.Setup;
begin
  CoInitializeEx( nil, COINIT_APARTMENTTHREADED );
  FFolder := TPath.Combine( TPath.GetTempPath, 'DDevExtBackupTest-' + TGUID.NewGuid.ToString );
  TDirectory.CreateDirectory( FFolder );
  FFileName := TPath.Combine( FFolder, 'LibraryPathBackups37.xml' );
end;

procedure TTestLibraryPathBackups.TearDown;
begin
  if TDirectory.Exists( FFolder ) then
    TDirectory.Delete( FFolder, True );
  CoUninitialize;
end;

procedure TTestLibraryPathBackups.TestTwoManagersKeepEachOthersBackups;
begin
  var Sorter := TLibraryPathBackupManager.Create( FFileName );
  var Compactor := TLibraryPathBackupManager.Create( FFileName );
  try
    // The Sorter's manager has seen the (empty) file before the Compactor writes.
    Assert.AreEqual( 0, Integer( Length( Sorter.GetAllBackups ) ) );
    Assert.IsTrue( Compactor.CreateBackup( lptSearchPath, 'Win64', 'C:\A', CompactionBackupPrefix + ' x' ),
      Compactor.LastError );
    Assert.IsTrue( Sorter.CreateBackup( lptSearchPath, 'Win64', 'C:\B', 'Before apply' ), Sorter.LastError );

    var All := Compactor.GetAllBackups;
    Assert.AreEqual( 2, Integer( Length( All ) ), 'one manager erased the other''s backup' );
    Assert.AreEqual( 'C:\A', All[0].Paths );
    Assert.AreEqual( 'C:\B', All[1].Paths );
  finally
    Compactor.Free;
    Sorter.Free;
  end;
end;

procedure TTestLibraryPathBackups.TestPinnedBackupNeverTrimmed;
begin
  var Manager := TLibraryPathBackupManager.Create( FFileName );
  try
    Manager.MaxBackupsPerType := 2;
    Assert.IsTrue( Manager.CreateBackup( lptSearchPath, 'Win64', 'C:\Pinned', 'Before compaction 2026-11-09', True ) );
    for var I := 1 to 5 do
      Assert.IsTrue( Manager.CreateBackup( lptSearchPath, 'Win64', 'C:\U' + IntToStr( I ), 'Before apply' ) );

    var All := Manager.GetBackups( lptSearchPath, 'Win64' );
    Assert.AreEqual( 3, Integer( Length( All ) ), 'cap of 2 unpinned plus the pinned one' );
    Assert.AreEqual( 'C:\Pinned', All[0].Paths, 'the pinned backup was trimmed' );
    Assert.IsTrue( All[0].Pinned );
    Assert.AreEqual( 'C:\U4', All[1].Paths, 'the oldest unpinned ones go first' );
    Assert.AreEqual( 'C:\U5', All[2].Paths );
  finally
    Manager.Free;
  end;
end;

procedure TTestLibraryPathBackups.TestTimestampRoundTripsAsIso8601;
begin
  var Manager := TLibraryPathBackupManager.Create( FFileName );
  try
    var Before := RecodeMilliSecond( Now, 0 );
    Assert.IsTrue( Manager.CreateBackup( lptBrowsingPath, 'Win32', 'C:\X', 'Manual' ) );
    var Backup := Manager.GetAllBackups[0];
    Assert.IsTrue( Abs( SecondsBetween( Before, Backup.Timestamp ) ) <= 2, 'timestamp lost or mis-parsed' );
    var Text := TFile.ReadAllText( FFileName );
    Assert.IsTrue( Pos( 'Timestamp="' + FormatDateTime( 'yyyy"-"mm"-"dd"T"', Backup.Timestamp ), Text ) > 0,
      'the timestamp is not stored in ISO 8601' );
  finally
    Manager.Free;
  end;
end;

procedure TTestLibraryPathBackups.TestLegacyEntryHasStableIdAndCanBeDeleted;
const
  // As an older build wrote it: no Id, timestamps in that machine's locale. Both are
  // ambiguous or unreadable in some locale, so neither may be interpreted.
  LegacyTimeA = '03/04/2026 13:03:51';
  LegacyTimeB = '31/08/2026 10:09:21';
begin
  TFile.WriteAllText( FFileName,
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<LibraryPathBackups>' +
    '<Backup PathType="Search Path" Platform="Win64" Timestamp="' + LegacyTimeA +
    '" Description="Before apply">C:\Old</Backup>' +
    '<Backup PathType="Search Path" Platform="Win64" Timestamp="' + LegacyTimeB + '" ' +
    'Description="Before compaction 2026-08-31 10:09">C:\Compacted</Backup>' +
    '</LibraryPathBackups>', TEncoding.UTF8 );

  var Manager := TLibraryPathBackupManager.Create( FFileName );
  try
    var First := Manager.GetAllBackups;
    var Second := Manager.GetAllBackups;
    Assert.AreEqual( 2, Integer( Length( First ) ) );
    Assert.AreEqual( First[0].Id, Second[0].Id, 'a legacy entry''s Id changed between reads' );
    Assert.AreNotEqual( First[0].Id, First[1].Id );
    Assert.AreEqual( 'C:\Old', First[0].Paths );
    Assert.IsTrue( First[1].Pinned, 'a legacy "Before compaction" entry must be treated as pinned' );

    // The locale timestamp is kept as written, never guessed at (day and month could swap).
    Assert.IsTrue( First[0].Timestamp = 0, 'a locale timestamp was interpreted' );
    Assert.AreEqual( LegacyTimeA, First[0].TimestampText );
    Assert.AreEqual( LegacyTimeA, First[0].DisplayTime );

    // A save (here, a new backup) must write it back unchanged, not drop it.
    Assert.IsTrue( Manager.CreateBackup( lptBrowsingPath, 'Win32', 'C:\New', 'Manual' ), Manager.LastError );
    var AfterSave := Manager.GetAllBackups;
    Assert.AreEqual( 3, Integer( Length( AfterSave ) ) );
    Assert.AreEqual( LegacyTimeA, AfterSave[0].TimestampText, 'a save lost the legacy timestamp' );
    Assert.AreEqual( LegacyTimeB, AfterSave[1].TimestampText, 'a save lost the legacy timestamp' );
    Assert.AreEqual( First[0].Id, AfterSave[0].Id, 'the legacy Id changed across a save' );

    Assert.IsTrue( Manager.DeleteBackup( First[0].Id ), Manager.LastError );
    var Remaining := Manager.GetAllBackups;
    Assert.AreEqual( 2, Integer( Length( Remaining ) ) );
    Assert.AreEqual( 'C:\Compacted', Remaining[0].Paths, 'the wrong backup was deleted' );
  finally
    Manager.Free;
  end;
end;

procedure TTestLibraryPathBackups.TestOlderBuildsFileImportedReadOnly;
begin
  var LegacyName := TPath.Combine( FFolder, 'LibraryPathBackups37.old.xml' );
  TFile.WriteAllText( LegacyName,
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<LibraryPathBackups>' +
    '<Backup PathType="Search Path" Platform="Win64" Timestamp="15/03/2026 13:03:51" ' +
    'Description="Before apply">C:\Old</Backup>' +
    '</LibraryPathBackups>', TEncoding.UTF8 );
  var LegacyBytes := TFile.ReadAllBytes( LegacyName );

  var Manager := TLibraryPathBackupManager.Create( FFileName, LegacyName );
  try
    var Imported := Manager.GetAllBackups;
    Assert.AreEqual( 1, Integer( Length( Imported ) ), 'the older history was not imported' );
    Assert.AreEqual( 'C:\Old', Imported[0].Paths );

    Assert.IsTrue( Manager.CreateBackup( lptSearchPath, 'Win64', 'C:\New', 'Manual' ), Manager.LastError );
    Assert.IsTrue( TFile.Exists( FFileName ), 'the new history file was not created' );
    var All := Manager.GetAllBackups;
    Assert.AreEqual( 2, Integer( Length( All ) ), 'the imported entry was lost on the first save' );

    var After := TFile.ReadAllBytes( LegacyName );
    Assert.IsTrue( ( Length( After ) = Length( LegacyBytes ) ) and
      CompareMem( Pointer( After ), Pointer( LegacyBytes ), Length( After ) ), 'the older history file was written' );

    // Once the new file exists, a change by an older build to its own file cannot reach it.
    TFile.WriteAllText( LegacyName, '<LibraryPathBackups/>', TEncoding.UTF8 );
    Assert.AreEqual( 2, Integer( Length( Manager.GetAllBackups ) ), 'the older file still feeds the new history' );
  finally
    Manager.Free;
  end;
end;


procedure TTestLibraryPathBackups.TestCorruptHistoryIsSetAsideAndReported;
begin
  TFile.WriteAllText( FFileName, '<LibraryPathBackups><Backup PathType="Search', TEncoding.UTF8 );

  var Manager := TLibraryPathBackupManager.Create( FFileName );
  try
    Assert.IsTrue( Manager.CreateBackup( lptSearchPath, 'Win64', 'C:\New', 'Manual' ), Manager.LastError );
    Assert.IsTrue( Manager.TakeNotice <> '', 'the user was not told the history was unreadable' );
    Assert.AreEqual( 1, Integer( Length( TDirectory.GetFiles( FFolder, '*.corrupt-*' ) ) ),
      'the unreadable history was not kept aside' );
    Assert.AreEqual( 1, Integer( Length( Manager.GetAllBackups ) ) );
  finally
    Manager.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestLibraryPathBackups );

end.
