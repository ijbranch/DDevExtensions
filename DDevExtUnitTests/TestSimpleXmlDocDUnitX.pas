unit TestSimpleXmlDocDUnitX;

/// <summary>
/// DUnitX test fixture for <c>SimpleXmlDoc</c> ( MSXML backend ), which loads and saves every
/// plug-in settings file and the <c>.projdata</c> side-cars.  Proves loading never rewrites the
/// file on disk and saving replaces the target in one step.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising <c>SimpleXmlDoc.TXmlDocument</c> load and save.</summary>
  [TestFixture]
  TTestSimpleXmlDoc = class
  private
    /// <summary>Per-test scratch folder, deleted in TearDown.</summary>
    FDir: string;
  public
    /// <summary>Initialises COM for MSXML and creates the scratch folder.</summary>
    [Setup]
    procedure Setup;
    /// <summary>Deletes the scratch folder and uninitialises COM.</summary>
    [TearDown]
    procedure TearDown;
    /// <summary>
    /// Proves a malformed single-line document is left byte-for-byte unchanged when loading
    /// fails.  The old repair replaced line 1 with a fresh declaration and saved it, which
    /// destroyed a single-line document entirely.
    /// </summary>
    [Test]
    procedure TestMalformedFileIsNotRewritten;
    /// <summary>
    /// Proves a JclSimpleXml-style declaration ( encoding before version ) still loads, and that
    /// the repair happens in memory: the file keeps its original bytes.
    /// </summary>
    [Test]
    procedure TestJclDeclarationLoadsWithoutRewrite;
    /// <summary>Proves SaveToFile replaces an existing file with the new content and leaves no temporary file behind.</summary>
    [Test]
    procedure TestSaveReplacesFileAndLeavesNoTemp;
    /// <summary>Proves a failed save to a read-only target raises and leaves the original file intact.</summary>
    [Test]
    procedure TestSaveToReadOnlyKeepsOriginal;
  end;

implementation

uses
  Winapi.Windows, Winapi.ActiveX, System.SysUtils, System.IOUtils, SimpleXmlIntf, SimpleXmlDoc;

procedure TTestSimpleXmlDoc.Setup;
begin
  CoInitializeEx( nil, COINIT_APARTMENTTHREADED );
  FDir := TPath.Combine( TPath.GetTempPath, 'DDevExtXmlTest' + IntToStr( GetCurrentProcessId ) );
  TDirectory.CreateDirectory( FDir );
end;

procedure TTestSimpleXmlDoc.TearDown;
begin
  for var sFile in TDirectory.GetFiles( FDir ) do
  begin
    SetFileAttributes( PChar( sFile ), FILE_ATTRIBUTE_NORMAL );
    TFile.Delete( sFile );
  end;
  TDirectory.Delete( FDir );
  CoUninitialize;
end;

procedure TTestSimpleXmlDoc.TestMalformedFileIsNotRewritten;
const
  cText = '<?xml version="1.0" encoding="UTF-8"?><Project><Options><A Value="1"/></Options>';
begin
  var sFile := TPath.Combine( FDir, 'broken.xml' );
  TFile.WriteAllText( sFile, cText, TEncoding.ASCII );
  var aBefore := TFile.ReadAllBytes( sFile );

  Assert.WillRaiseAny(
    procedure
    begin
      LoadXmlDocument( sFile );
    end );

  var aAfter := TFile.ReadAllBytes( sFile );
  Assert.AreEqual( Length( aBefore ), Length( aAfter ), 'File length changed' );
  Assert.IsTrue( CompareMem( @aBefore[0], @aAfter[0], Length( aBefore ) ), 'File content changed' );
end;

procedure TTestSimpleXmlDoc.TestJclDeclarationLoadsWithoutRewrite;
const
  cText = '<?xml encoding="UTF-8" version="1.0"?>' + #13#10 + '<Project><Options><A Value="1"/></Options></Project>';
begin
  var sFile := TPath.Combine( FDir, 'jcl.xml' );
  TFile.WriteAllText( sFile, cText, TEncoding.ASCII );
  var aBefore := TFile.ReadAllBytes( sFile );

  var oDoc := LoadXmlDocument( sFile );
  var oNode := oDoc.DocumentElement.ChildNodes.FindNode( 'Options' );
  Assert.IsNotNull( oNode );
  Assert.AreEqual( '1', string( oNode.ChildNodes[0].Attributes['Value'] ) );

  var aAfter := TFile.ReadAllBytes( sFile );
  Assert.AreEqual( Length( aBefore ), Length( aAfter ), 'File length changed' );
  Assert.IsTrue( CompareMem( @aBefore[0], @aAfter[0], Length( aBefore ) ), 'File content changed' );
end;

procedure TTestSimpleXmlDoc.TestSaveReplacesFileAndLeavesNoTemp;
begin
  var sFile := TPath.Combine( FDir, 'save.xml' );
  TFile.WriteAllText( sFile, 'old content that is not XML', TEncoding.ASCII );

  var oDoc := NewXmlDocument;
  oDoc.DocumentElement := oDoc.CreateElement( 'Project', '' );
  oDoc.DocumentElement.AddChild( 'Options' ).Attributes['Value'] := 'New';
  oDoc.SaveToFile( sFile );

  Assert.AreEqual( 1, Length( TDirectory.GetFiles( FDir ) ), 'A temporary file was left behind' );
  var oReloaded := LoadXmlDocument( sFile );
  Assert.AreEqual( 'New', string( oReloaded.DocumentElement.ChildNodes.FindNode( 'Options' ).Attributes['Value'] ) );
end;

procedure TTestSimpleXmlDoc.TestSaveToReadOnlyKeepsOriginal;
const
  cOriginal = 'original';
begin
  var sFile := TPath.Combine( FDir, 'readonly.xml' );
  TFile.WriteAllText( sFile, cOriginal, TEncoding.ASCII );
  SetFileAttributes( PChar( sFile ), FILE_ATTRIBUTE_READONLY );

  var oDoc := NewXmlDocument;
  oDoc.DocumentElement := oDoc.CreateElement( 'Project', '' );
  Assert.WillRaiseAny(
    procedure
    begin
      oDoc.SaveToFile( sFile );
    end );

  Assert.AreEqual( cOriginal, TFile.ReadAllText( sFile, TEncoding.ASCII ) );
  Assert.AreEqual( 1, Length( TDirectory.GetFiles( FDir ) ), 'A temporary file was left behind' );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestSimpleXmlDoc );

end.
