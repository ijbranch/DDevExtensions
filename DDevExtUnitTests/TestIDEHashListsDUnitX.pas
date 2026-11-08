unit TestIDEHashListsDUnitX;

/// <summary>
/// DUnitX test fixture for <c>IDEHashLists</c>: the string hash, the string-keyed hash tables
/// File Selector relies on, and the pointer-keyed bucket lists.  Run on Win64 as well as Win32:
/// the original hash was x86 assembler that read the wrong registers on x64.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising <c>IDEHashLists</c>.</summary>
  [ TestFixture ]
  TTestIDEHashLists = class
  public
    /// <summary>
    /// Proves <c>HashString</c> returns the documented value (length plus the sum of the
    /// character codes, masked to the bucket range) on every platform.  The x86 assembler
    /// version ignored the Win64 parameter register and hashed whatever EAX held.
    /// </summary>
    [ Test ]
    procedure TestHashStringValue;
    /// <summary>Proves the hash of the empty string is 0 and every hash stays inside the bucket range.</summary>
    [ Test ]
    procedure TestHashStringRange;
    /// <summary>
    /// Proves <c>TStringIntegerHash</c> finds every key it was given after more keys than its
    /// preallocated cache holds, so both cache nodes and heap nodes are exercised, and that
    /// <c>Remove</c> and <c>Clear</c> release them without a heap error.
    /// </summary>
    [ Test ]
    procedure TestStringIntegerHashBeyondCache;
    /// <summary>Proves <c>TStringStringHash</c> round-trips values, including after <c>Remove</c>.</summary>
    [ Test ]
    procedure TestStringStringHash;
    /// <summary>
    /// Proves <c>TCustomBucketList.Assign</c> copies the source list's entries.  It used to
    /// iterate the (just cleared) target instead, so the copy was always empty.
    /// </summary>
    [ Test ]
    procedure TestBucketListAssign;
  end;

implementation

uses
  System.SysUtils, IDEHashLists;

procedure TTestIDEHashLists.TestHashStringValue;
begin
  Assert.AreEqual( ( 3 + Ord( 'a' ) + Ord( 'b' ) + Ord( 'c' ) ) and ( MaxBucketItems - 1 ), HashString( 'abc' ) );
  Assert.AreEqual( ( 5 + Ord( 'U' ) + Ord( 'n' ) + Ord( 'i' ) + Ord( 't' ) + Ord( '1' ) ) and ( MaxBucketItems - 1 ),
    HashString( 'Unit1' ) );
end;

procedure TTestIDEHashLists.TestHashStringRange;
begin
  Assert.AreEqual( 0, HashString( '' ) );
  for var iIndex: Integer := 0 to 999 do
  begin
    var iHash       := HashString( StringOfChar( 'Z', iIndex ) + IntToStr( iIndex ) );
    Assert.IsTrue( ( iHash >= 0 ) and ( iHash < MaxBucketItems ), 'Hash out of range at ' + IntToStr( iIndex ) );
  end;
end;

procedure TTestIDEHashLists.TestStringIntegerHashBeyondCache;
const
  cCount            = MaxCacheItems * 2 + 17;
begin
  var oHash         := TStringIntegerHash.Create;
  try
    for var iIndex: Integer := 0 to cCount - 1 do
      oHash.Add( 'KEY' + IntToStr( iIndex ), iIndex );
    Assert.AreEqual( cCount, oHash.Count );

    for var iIndex: Integer := 0 to cCount - 1 do
    begin
      var iValue: Integer;
      Assert.IsTrue( oHash.Find( 'KEY' + IntToStr( iIndex ), iValue ), 'Missing KEY' + IntToStr( iIndex ) );
      Assert.AreEqual( iIndex, iValue );
    end;

    Assert.AreEqual( 5, oHash.Remove( 'KEY5' ) );
    Assert.AreEqual( cCount - 1, oHash.Remove( 'KEY' + IntToStr( cCount - 1 ) ) );
    Assert.IsFalse( oHash.HasKey( 'KEY5' ) );
    Assert.AreEqual( cCount - 2, oHash.Count );

    oHash.Clear;
    Assert.AreEqual( 0, oHash.Count );
    Assert.IsFalse( oHash.HasKey( 'KEY1' ) );
  finally
    oHash.Free;
  end;
end;

procedure TTestIDEHashLists.TestStringStringHash;
begin
  var oHash         := TStringStringHash.Create;
  try
    oHash.Add( 'Alpha', 'One' );
    oHash.Add( 'Beta', 'Two' );
    var sValue: string;
    Assert.IsTrue( oHash.Find( 'Beta', sValue ) );
    Assert.AreEqual( 'Two', sValue );
    Assert.AreEqual( 'One', oHash.Remove( 'Alpha' ) );
    Assert.IsFalse( oHash.HasKey( 'Alpha' ) );
    Assert.AreEqual( 1, oHash.Count );
  finally
    oHash.Free;
  end;
end;

procedure TTestIDEHashLists.TestBucketListAssign;
begin
  var oSource       := TBucketList.Create;
  var oTarget       := TBucketList.Create;
  try
    oSource.Add( Pointer( 16 ), Pointer( 160 ) );
    oSource.Add( Pointer( 32 ), Pointer( 320 ) );
    oTarget.Add( Pointer( 48 ), Pointer( 480 ) );

    oTarget.Assign( oSource );

    var pData: Pointer;
    Assert.IsTrue( oTarget.Find( Pointer( 16 ), pData ) );
    Assert.AreEqual( NativeInt( 160 ), NativeInt( pData ) );
    Assert.IsTrue( oTarget.Find( Pointer( 32 ), pData ) );
    Assert.AreEqual( NativeInt( 320 ), NativeInt( pData ) );
    Assert.IsFalse( oTarget.Exists( Pointer( 48 ) ), 'Assign must replace the old contents' );
  finally
    oTarget.Free;
    oSource.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestIDEHashLists );

end.

