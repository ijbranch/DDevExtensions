unit TestVersionInfoKeysDUnitX;

/// <summary>
/// DUnitX test fixture for <c>VersionInfoKeys</c>, the <c>VerInfo_Keys</c> parser behind the Set
/// Version Info dialog and the "Last Compile" stamp written after every compile.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising <c>VersionInfoKeys</c>.</summary>
  [ TestFixture ]
  TTestVersionInfoKeys = class
  public
    /// <summary>
    /// Proves an apostrophe in a value does not merge the keys after it.  The RTL
    /// <c>ExtractStrings</c> used before treated <c>'</c> as a quote and returned one item for
    /// everything from <c>Ian's</c> to the end, so FileVersion read back blank.
    /// </summary>
    [ Test ]
    procedure TestApostropheDoesNotMergeKeys;
    /// <summary>Proves a double quote inside a value is kept verbatim and does not merge keys either.</summary>
    [ Test ]
    procedure TestDoubleQuoteKept;
    /// <summary>
    /// Proves setting a key to an empty value keeps it as <c>Name=</c>.  <c>TStrings.Values</c>
    /// deletes the line instead, which stripped the IDE's blank keys from the project.
    /// </summary>
    [ Test ]
    procedure TestEmptyValueKeepsKey;
    /// <summary>
    /// Proves updating the same key repeatedly replaces it rather than appending: with the old
    /// parser "Last Compile" was appended once per compile when an earlier value held an apostrophe.
    /// </summary>
    [ Test ]
    procedure TestRepeatedUpdateDoesNotGrow;
    /// <summary>Proves an unchanged update round-trips the original string byte for byte.</summary>
    [ Test ]
    procedure TestRoundTripUnchanged;
  end;

implementation

uses
  System.SysUtils, System.Classes, VersionInfoKeys;

const
  cKeys             = 'CompanyName=Ian''s Co;FileDescription=Tool;FileVersion=1.2.3.4;LegalTrademarks=;Comments=';

procedure TTestVersionInfoKeys.TestApostropheDoesNotMergeKeys;
begin
  var oList         := TStringList.Create;
  try
    SplitVersionInfoKeys( cKeys, oList );
    Assert.AreEqual( 5, oList.Count );
    Assert.AreEqual( 'Ian''s Co', oList.Values[ 'CompanyName' ] );
    Assert.AreEqual( '1.2.3.4', oList.Values[ 'FileVersion' ] );
  finally
    oList.Free;
  end;
end;

procedure TTestVersionInfoKeys.TestDoubleQuoteKept;
begin
  var oList         := TStringList.Create;
  try
    SplitVersionInfoKeys( 'FileDescription=The "Pro" tool;ProductName=X', oList );
    Assert.AreEqual( 2, oList.Count );
    Assert.AreEqual( 'The "Pro" tool', oList.Values[ 'FileDescription' ] );
    Assert.AreEqual( 'X', oList.Values[ 'ProductName' ] );
  finally
    oList.Free;
  end;
end;

procedure TTestVersionInfoKeys.TestEmptyValueKeepsKey;
begin
  var sKeys         := UpdateVersionInfoKey( cKeys, 'FileDescription', '' );
  Assert.AreEqual( 'CompanyName=Ian''s Co;FileDescription=;FileVersion=1.2.3.4;LegalTrademarks=;Comments=', sKeys );
end;

procedure TTestVersionInfoKeys.TestRepeatedUpdateDoesNotGrow;
begin
  var sKeys         := cKeys;
  for var iIndex: Integer := 1 to 3 do
    sKeys           := UpdateVersionInfoKey( sKeys, 'Last Compile', IntToStr( iIndex ) );
  Assert.AreEqual( cKeys + ';Last Compile=3', sKeys );
end;

procedure TTestVersionInfoKeys.TestRoundTripUnchanged;
begin
  Assert.AreEqual( cKeys, UpdateVersionInfoKey( cKeys, 'FileVersion', '1.2.3.4' ) );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestVersionInfoKeys );

end.

