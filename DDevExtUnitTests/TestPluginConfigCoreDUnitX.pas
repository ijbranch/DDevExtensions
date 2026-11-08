unit TestPluginConfigCoreDUnitX;

/// <summary>
/// DUnitX tests for <c>PluginConfigCore</c>: how DDevExtensions keeps its one settings file (every feature's
/// options) from being truncated by a crash or overwritten after a failed read.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Fixture for the settings-file safety helpers.</summary>
  [TestFixture]
  TTestPluginConfigCore = class
  private
    /// <summary>A fresh folder for one test, under the temp folder.</summary>
    FFolder: string;
    /// <summary>Writes <paramref name="Text"/> to <paramref name="FileName"/> as UTF-8.</summary>
    /// <param name="FileName">Target file.</param>
    /// <param name="Text">Content.</param>
    procedure WriteText(const FileName, Text: string);
    /// <summary>Reads a UTF-8 file written by <see cref="WriteText"/>.</summary>
    /// <param name="FileName">Source file.</param>
    /// <returns>Its content.</returns>
    function ReadText(const FileName: string): string;
  public
    /// <summary>Creates the per-test folder.</summary>
    [Setup]
    procedure Setup;
    /// <summary>Deletes the per-test folder.</summary>
    [TearDown]
    procedure TearDown;
    /// <summary>
    /// A missing attribute (the XML wrapper returns '' for it), Null and Unassigned carry no value; real values
    /// do.  The old test <c>Value &lt;&gt; Null</c> took '' for a value, and SetOrdProp('') raised.
    /// </summary>
    [Test]
    procedure TestXmlValuePresent;
    /// <summary>The quarantine name keeps the original name and appends the date and time.</summary>
    [Test]
    procedure TestQuarantineFileName;
    /// <summary>An unreadable settings file is moved aside with its bytes intact, so a later save cannot overwrite it.</summary>
    [Test]
    procedure TestQuarantineMovesFileIntact;
    /// <summary>A second quarantine in the same second does not overwrite the first one.</summary>
    [Test]
    procedure TestQuarantineNeverOverwritesEarlierQuarantine;
    /// <summary>The atomic replace swaps in the new content and leaves no temporary file behind.</summary>
    [Test]
    procedure TestReplaceFileAtomicallySwapsContent;
    /// <summary>A failed replace raises EInOutError, keeps the original content and removes the temporary file.</summary>
    [Test]
    procedure TestReplaceFileAtomicallyFailureKeepsOriginal;
    /// <summary>
    /// Every save gets its own temporary file beside the settings file: the 32-bit and 64-bit IDE share the settings
    /// file, and a fixed temporary name let one IDE's save replace the other's half-written one.
    /// </summary>
    [Test]
    procedure TestTempFileNamesAreUniqueAndBesideTheFile;
    /// <summary>
    /// A file that cannot be opened ( held exclusively by another process ) is reported as locked, not damaged, and
    /// the parser is never run, so the file is left alone instead of being moved aside.
    /// </summary>
    [Test]
    procedure TestLockedFileIsReportedLockedNotUnreadable;
    /// <summary>Content that never parses is reported unreadable after every attempt has been made.</summary>
    /// <exception cref="EParserError">Raised by the test's loader on purpose to simulate damaged content; the routine under test absorbs it.</exception>
    [Test]
    procedure TestBadContentIsUnreadableAfterAllAttempts;
    /// <summary>A file caught mid-write on the first attempt loads on a retry.</summary>
    /// <exception cref="EParserError">Raised by the test's loader on purpose to simulate a transient parse failure; the routine under test absorbs it.</exception>
    [Test]
    procedure TestRetryLoadsAfterTransientFailure;
    /// <summary>An empty file is unreadable, and the parser is not run on it.</summary>
    [Test]
    procedure TestEmptyFileIsUnreadable;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Variants, System.DateUtils, PluginConfigCore;

procedure TTestPluginConfigCore.Setup;
begin
  FFolder := TPath.Combine( TPath.GetTempPath, 'DDevExtTest-' + TGUID.NewGuid.ToString );
  ForceDirectories( FFolder );
end;

procedure TTestPluginConfigCore.TearDown;
begin
  if DirectoryExists( FFolder ) then
    TDirectory.Delete( FFolder, True );
end;

procedure TTestPluginConfigCore.WriteText(const FileName, Text: string);
begin
  TFile.WriteAllText( FileName, Text, TEncoding.UTF8 );
end;

function TTestPluginConfigCore.ReadText(const FileName: string): string;
begin
  Result := TFile.ReadAllText( FileName, TEncoding.UTF8 );
end;

procedure TTestPluginConfigCore.TestXmlValuePresent;
begin
  Assert.IsFalse( XmlValuePresent( '' ), 'a missing attribute reads as an empty string' );
  Assert.IsFalse( XmlValuePresent( Null ) );
  Assert.IsFalse( XmlValuePresent( Unassigned ) );
  Assert.IsTrue( XmlValuePresent( '0' ) );
  Assert.IsTrue( XmlValuePresent( 5 ) );
  Assert.IsTrue( XmlValuePresent( 'True' ) );
end;

procedure TTestPluginConfigCore.TestQuarantineFileName;
begin
  var Stamp := EncodeDateTime( 2026, 11, 9, 7, 5, 3, 0 );
  Assert.AreEqual( 'C:\Cfg\DDevExtensionsD130.xml.corrupt-20261109-070503',
    QuarantineFileName( 'C:\Cfg\DDevExtensionsD130.xml', Stamp ) );
end;

procedure TTestPluginConfigCore.TestQuarantineMovesFileIntact;
begin
  var FileName := TPath.Combine( FFolder, 'Settings.xml' );
  WriteText( FileName, '<DDevExtensions><Trunc' );
  var NewName: string;
  Assert.IsTrue( QuarantineFile( FileName, Now, NewName ) );
  Assert.IsFalse( FileExists( FileName ), 'the original name is free for a fresh file' );
  Assert.IsTrue( FileExists( NewName ) );
  Assert.AreEqual( '<DDevExtensions><Trunc', ReadText( NewName ) );
end;

procedure TTestPluginConfigCore.TestQuarantineNeverOverwritesEarlierQuarantine;
begin
  var FileName := TPath.Combine( FFolder, 'Settings.xml' );
  var Stamp := EncodeDateTime( 2026, 11, 9, 7, 5, 3, 0 );
  WriteText( FileName, 'first' );
  var First: string;
  Assert.IsTrue( QuarantineFile( FileName, Stamp, First ) );
  WriteText( FileName, 'second' );
  var Second: string;
  Assert.IsTrue( QuarantineFile( FileName, Stamp, Second ) );
  Assert.AreNotEqual( First, Second );
  Assert.AreEqual( 'first', ReadText( First ) );
  Assert.AreEqual( 'second', ReadText( Second ) );
end;

procedure TTestPluginConfigCore.TestReplaceFileAtomicallySwapsContent;
begin
  var FileName := TPath.Combine( FFolder, 'Settings.xml' );
  WriteText( FileName, 'old settings' );
  var TempName := TempFileNameFor( FileName );
  WriteText( TempName, 'new settings' );
  ReplaceFileAtomically( TempName, FileName );
  Assert.AreEqual( 'new settings', ReadText( FileName ) );
  Assert.IsFalse( FileExists( TempName ), 'no temporary file is left behind' );
end;

procedure TTestPluginConfigCore.TestReplaceFileAtomicallyFailureKeepsOriginal;
begin
  var FileName := TPath.Combine( FFolder, 'Settings.xml' );
  WriteText( FileName, 'old settings' );
  var TempName := TempFileNameFor( FileName );
  WriteText( TempName, 'new settings' );
  // An open handle that denies delete makes the replace fail, as an antivirus scanner or backup tool can
  var Lock := TFileStream.Create( FileName, fmOpenRead or fmShareDenyNone );
  try
    Assert.WillRaise(
      procedure
      begin
        ReplaceFileAtomically( TempName, FileName );
      end, EInOutError );
  finally
    Lock.Free;
  end;
  Assert.AreEqual( 'old settings', ReadText( FileName ) );
  Assert.IsFalse( FileExists( TempName ), 'the temporary file is cleaned up' );
end;

procedure TTestPluginConfigCore.TestTempFileNamesAreUniqueAndBesideTheFile;
begin
  var FileName := TPath.Combine( FFolder, 'Settings.xml' );
  var First := TempFileNameFor( FileName );
  var Second := TempFileNameFor( FileName );
  Assert.AreNotEqual( First, Second );
  Assert.AreEqual( FFolder, ExtractFileDir( First ), 'beside the settings file, so the replace stays on one volume' );
  Assert.IsTrue( First.EndsWith( '.tmp' ) );
end;

procedure TTestPluginConfigCore.TestLockedFileIsReportedLockedNotUnreadable;
begin
  var FileName := TPath.Combine( FFolder, 'Settings.xml' );
  WriteText( FileName, '<DDevExtensions/>' );
  var Parsed := 0;
  var Lock := TFileStream.Create( FileName, fmOpenReadWrite or fmShareExclusive );
  try
    var Reason: string;
    var Outcome := LoadSettingsWithRetry( FileName,
      procedure(Name: string)
      begin
        Inc( Parsed );
      end, 3, 1, Reason );
    Assert.AreEqual( Ord( sloLocked ), Ord( Outcome ) );
    Assert.AreEqual( 0, Parsed, 'nothing is parsed from a file that could not be opened' );
    Assert.IsNotEmpty( Reason );
  finally
    Lock.Free;
  end;
end;

procedure TTestPluginConfigCore.TestBadContentIsUnreadableAfterAllAttempts;
begin
  var FileName := TPath.Combine( FFolder, 'Settings.xml' );
  WriteText( FileName, '<DDevExtensions><Trunc' );
  var Parsed := 0;
  var Reason: string;
  var Outcome := LoadSettingsWithRetry( FileName,
    procedure(Name: string)
    begin
      Inc( Parsed );
      raise EParserError.Create( 'unexpected end of file' );
    end, 3, 1, Reason );
  Assert.AreEqual( Ord( sloUnreadable ), Ord( Outcome ) );
  Assert.AreEqual( 3, Parsed );
  Assert.Contains( Reason, 'unexpected end of file' );
end;

procedure TTestPluginConfigCore.TestRetryLoadsAfterTransientFailure;
begin
  var FileName := TPath.Combine( FFolder, 'Settings.xml' );
  WriteText( FileName, '<DDevExtensions/>' );
  var Parsed := 0;
  var Reason: string;
  var Outcome := LoadSettingsWithRetry( FileName,
    procedure(Name: string)
    begin
      Inc( Parsed );
      if Parsed = 1 then
        raise EParserError.Create( 'caught mid-write' );
    end, 4, 1, Reason );
  Assert.AreEqual( Ord( sloLoaded ), Ord( Outcome ) );
  Assert.AreEqual( 2, Parsed );
  Assert.IsEmpty( Reason );
end;

procedure TTestPluginConfigCore.TestEmptyFileIsUnreadable;
begin
  var FileName := TPath.Combine( FFolder, 'Settings.xml' );
  TFile.WriteAllBytes( FileName, [] );
  var Parsed := 0;
  var Reason: string;
  var Outcome := LoadSettingsWithRetry( FileName,
    procedure(Name: string)
    begin
      Inc( Parsed );
    end, 2, 1, Reason );
  Assert.AreEqual( Ord( sloUnreadable ), Ord( Outcome ) );
  Assert.AreEqual( 0, Parsed );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestPluginConfigCore );

end.
