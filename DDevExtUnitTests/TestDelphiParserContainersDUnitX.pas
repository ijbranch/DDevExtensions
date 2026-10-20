unit TestDelphiParserContainersDUnitX;

/// <summary>
/// DUnitX test fixture for <c>DelphiParserContainers</c> - <c>THashtable</c>,
/// <c>TIntegerList</c>, <c>TStringDictionary</c> and <c>TStringCollection</c>, the
/// lightweight containers the lexer and preprocessor keep their symbol tables in.
/// Covers key lookup, case sensitivity, ownership-aware removal and the
/// integer/pointer round-trip.
/// </summary>
/// <remarks>
/// Converted from the retired console harness <c>TestDelphiParserContainers.pas</c>.
/// The owning <c>THashtable</c> frees the objects it holds, so the tests hand it new
/// instances and never free them themselves; FastMM5 would report a double free or a
/// leak if ownership were wrong.
/// </remarks>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising the parser's container classes.</summary>
  [TestFixture]
  TTestDelphiParserContainers = class
  public
    /// <summary>
    /// Proves a case-insensitive owning hashtable finds keys in any casing, returns the
    /// stored object for a key and nil for a missing one, and that Remove deletes the
    /// entry and drops the count.  The preprocessor's define table is built this way,
    /// so <c>{$IFDEF debug}</c> must find <c>DEBUG</c>.
    /// </summary>
    [Test]
    procedure TestHashtableCaseInsensitive;
    /// <summary>Proves a case-sensitive hashtable finds the exact casing and rejects a different one.</summary>
    [Test]
    procedure TestHashtableCaseSensitive;
    /// <summary>
    /// Proves TIntegerList returns sequential indices from Add and round-trips integers
    /// through its pointer storage on read and on assignment.
    /// </summary>
    [Test]
    procedure TestIntegerList;
    /// <summary>
    /// Proves TStringDictionary counts, finds and returns values by key through both
    /// Values and Find, and returns an empty string rather than raising for a missing key.
    /// </summary>
    [Test]
    procedure TestStringDictionary;
    /// <summary>Proves TStringCollection reports membership and that RemoveAt removes the entry and drops the count.</summary>
    [Test]
    procedure TestStringCollection;
  end;

implementation

uses
  System.SysUtils, System.Classes, DelphiParserContainers;

{ TTestDelphiParserContainers }

procedure TTestDelphiParserContainers.TestHashtableCaseInsensitive;
begin
  var oTable := THashtable.Create( False { CaseSensitive }, True { OwnsObjects } );
  try
    var oAlpha := TObject.Create;
    oTable.Add( 'alpha', oAlpha );
    oTable.Add( 'beta', TObject.Create );
    Assert.AreEqual<Integer>( 2, oTable.Count, 'count after two adds' );
    Assert.IsTrue( oTable.Contains( 'alpha' ), 'contains alpha' );
    Assert.IsTrue( oTable.Contains( 'ALPHA' ), 'case-insensitive: contains ALPHA' );
    Assert.AreSame( oAlpha, oTable.Values[ 'alpha' ], 'Values[ alpha ] is the stored object' );
    Assert.IsNull( oTable.Values[ 'missing' ], 'a missing key returns nil' );

    oTable.Remove( 'alpha' );
    Assert.IsFalse( oTable.Contains( 'alpha' ), 'alpha removed' );
    Assert.AreEqual<Integer>( 1, oTable.Count, 'count after remove' );
  finally
    oTable.Free;
  end;
end;

procedure TTestDelphiParserContainers.TestHashtableCaseSensitive;
begin
  var oTable := THashtable.Create( True { CaseSensitive }, True { OwnsObjects } );
  try
    oTable.Add( 'Key', TObject.Create );
    Assert.IsTrue( oTable.Contains( 'Key' ), 'contains the exact-case Key' );
    Assert.IsFalse( oTable.Contains( 'key' ), 'case-sensitive: does not contain key' );
  finally
    oTable.Free;
  end;
end;

procedure TTestDelphiParserContainers.TestIntegerList;
begin
  var oList := TIntegerList.Create;
  try
    Assert.AreEqual<Integer>( 0, oList.Add( 10 ), 'first Add returns index 0' );
    Assert.AreEqual<Integer>( 1, oList.Add( 20 ), 'second Add returns index 1' );
    Assert.AreEqual<Integer>( 2, oList.Count, 'count after two adds' );
    Assert.AreEqual<Integer>( 10, oList.Items[ 0 ], 'Items[ 0 ]' );
    Assert.AreEqual<Integer>( 20, oList.Items[ 1 ], 'Items[ 1 ]' );

    oList.Items[ 1 ] := 99;
    Assert.AreEqual<Integer>( 99, oList.Items[ 1 ], 'Items[ 1 ] after assignment' );
  finally
    oList.Free;
  end;
end;

procedure TTestDelphiParserContainers.TestStringDictionary;
begin
  var oDictionary := TStringDictionary.Create;
  try
    oDictionary.Add( 'k1', 'v1' );
    oDictionary.Add( 'k2', 'v2' );
    Assert.AreEqual<Integer>( 2, oDictionary.Count, 'count after two adds' );
    Assert.IsTrue( oDictionary.Contains( 'k1' ), 'contains k1' );
    Assert.AreEqual( 'v1', oDictionary.Values[ 'k1' ], 'Values[ k1 ]' );
    Assert.AreEqual( 'v2', oDictionary.Find( 'k2' ), 'Find( k2 )' );
    Assert.AreEqual( '', oDictionary.Values[ 'missing' ], 'a missing key returns an empty string' );
  finally
    oDictionary.Free;
  end;
end;

procedure TTestDelphiParserContainers.TestStringCollection;
begin
  var oCollection := TStringCollection.Create;
  try
    oCollection.Add( 'a' );
    oCollection.Add( 'b' );
    Assert.IsTrue( oCollection.Contains( 'a' ), 'contains a' );
    Assert.IsFalse( oCollection.Contains( 'z' ), 'does not contain z' );

    oCollection.RemoveAt( 0 );
    Assert.IsFalse( oCollection.Contains( 'a' ), 'a removed' );
    Assert.AreEqual<Integer>( 1, oCollection.Count, 'count after RemoveAt' );
  finally
    oCollection.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestDelphiParserContainers );

end.
