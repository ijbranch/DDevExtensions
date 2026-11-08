{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2005,2006 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit IDEHashLists;

/// <summary>
/// String-keyed hash tables and pointer-keyed bucket lists used by the plug-in, kept free of
/// ToolsAPI and VCL so they can be unit-tested outside the IDE.  Moved out of <c>IDEUtils</c>,
/// which re-exports every type and <c>HashString</c> for its existing callers.
/// </summary>

interface

uses
  Winapi.Windows, System.SysUtils;

const
  /// <summary>Number of preallocated cache slots used by the string hash tables.</summary>
  MaxCacheItems     = $1000;

type
  /// <summary>Strongly-typed Cardinal used as a hash bucket index.</summary>
  THashValue = type Cardinal;

  { The hash tables cannot be used with Key='' }
  /// <summary>Pointer to a TStringIntegerItem.</summary>
  PStringIntegerItem = ^TStringIntegerItem;
  /// <summary>Bucket entry storing a string key and Integer value plus a chain pointer.</summary>
  TStringIntegerItem = record
    /// <summary>String key (must not be empty).</summary>
    Key: string;
    /// <summary>Integer value associated with Key.</summary>
    Value: Integer;
    /// <summary>Next entry in the same bucket chain.</summary>
    Next: PStringIntegerItem;
  end;

  /// <summary>Open-addressing string-to-Integer hash with a static $1000-bucket table and a preallocated cache pool.</summary>
  TStringIntegerHash = class( TObject )
  private
    /// <summary>Bucket array.</summary>
    FItems: array[ 0..$1000 - 1 ] of PStringIntegerItem;
    /// <summary>Total number of stored entries.</summary>
    FCount: Integer;
    /// <summary>Preallocated entry pool to avoid GetMem on every Add.</summary>
    FCacheItems: array[ 0..MaxCacheItems ] of TStringIntegerItem;
    /// <summary>Index of the next free entry in FCacheItems.</summary>
    FCacheIndex: Integer;
  public
    /// <summary>Frees every chained entry that was allocated from the heap.</summary>
    destructor Destroy; override;
    /// <summary>Empties the table.</summary>
    procedure Clear; virtual;

    /// <summary>Looks up AItem and returns its value via Value.</summary>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <param name="Value">Receives the stored value; 0 when the key is missing.</param>
    /// <returns>True when the key is present.</returns>
    function Find( const AItem: string; out Value: Integer ): Boolean; overload;
    /// <summary>True when AItem is present in the table.</summary>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <returns>True when the key is present.</returns>
    function HasKey( const AItem: string ): Boolean; overload;

    /// <summary>Find overload that accepts a precomputed hash to avoid recomputation.</summary>
    /// <param name="AHash">Precomputed HashString( AItem ).</param>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <param name="Value">Receives the stored value; 0 when the key is missing.</param>
    /// <returns>True when the key is present.</returns>
    function Find( AHash: Integer; const AItem: string; out Value: Integer ): Boolean; overload;
    /// <summary>HasKey overload that accepts a precomputed hash.</summary>
    /// <param name="AHash">Precomputed HashString( AItem ).</param>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <returns>True when the key is present.</returns>
    function HasKey( AHash: Integer; const AItem: string ): Boolean; overload;

    /// <summary>Adds (AItem, AData) without checking for duplicates.</summary>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <param name="AData">Value to store.</param>
    /// <returns>AData.</returns>
    function Add( const AItem: string; AData: Integer ): Integer; overload;
    /// <summary>Add overload that accepts a precomputed hash.</summary>
    /// <param name="AHash">Precomputed HashString( AItem ).</param>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <param name="AData">Value to store.</param>
    /// <returns>AData.</returns>
    function Add( AHash: Integer; const AItem: string; AData: Integer ): Integer; overload;
    /// <summary>Removes the entry for AItem, returning its previous value (0 when absent).</summary>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <returns>The removed value; 0 when the key was missing.</returns>
    function Remove( const AItem: string ): Integer;
    /// <summary>Updates AItem's value, adding it when not already present.</summary>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <param name="AData">New value.</param>
    procedure SetValue( const AItem: string; AData: Integer ); overload;
    /// <summary>SetValue overload accepting a precomputed hash.</summary>
    /// <param name="AHash">Precomputed HashString( AItem ).</param>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <param name="AData">New value.</param>
    procedure SetValue( AHash: Integer; const AItem: string; AData: Integer ); overload;

    /// <summary>Number of stored entries.</summary>
    property Count: Integer read FCount;
  end;

type
  /// <summary>Pointer to a TStringStringItem.</summary>
  PStringStringItem = ^TStringStringItem;
  /// <summary>Bucket entry storing a string key and string value plus a chain pointer.</summary>
  TStringStringItem = record
    /// <summary>String key (must not be empty).</summary>
    Key: string;
    /// <summary>String value associated with Key.</summary>
    Value: string;
    /// <summary>Next entry in the same bucket chain.</summary>
    Next: PStringStringItem;
  end;

  /// <summary>String-to-string variant of TStringIntegerHash.</summary>
  TStringStringHash = class( TObject )
  private
    /// <summary>Bucket array.</summary>
    FItems: array[ 0..$1000 - 1 ] of PStringStringItem;
    /// <summary>Total number of stored entries.</summary>
    FCount: Integer;
    /// <summary>Preallocated entry pool.</summary>
    FCacheItems: array[ 0..MaxCacheItems ] of TStringStringItem;
    /// <summary>Index of the next free entry in FCacheItems.</summary>
    FCacheIndex: Integer;
  public
    /// <summary>Frees every chained entry that was allocated from the heap.</summary>
    destructor Destroy; override;
    /// <summary>Empties the table.</summary>
    procedure Clear; virtual;

    /// <summary>Looks up AItem and returns its value via Value.</summary>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <param name="Value">Receives the stored value; empty when the key is missing.</param>
    /// <returns>True when the key is present.</returns>
    function Find( const AItem: string; out Value: string ): Boolean; overload;
    /// <summary>True when AItem is present in the table.</summary>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <returns>True when the key is present.</returns>
    function HasKey( const AItem: string ): Boolean; overload;

    /// <summary>Find overload accepting a precomputed hash.</summary>
    /// <param name="AHash">Precomputed HashString( AItem ).</param>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <param name="Value">Receives the stored value; empty when the key is missing.</param>
    /// <returns>True when the key is present.</returns>
    function Find( AHash: Integer; const AItem: string; out Value: string ): Boolean; overload;
    /// <summary>HasKey overload accepting a precomputed hash.</summary>
    /// <param name="AHash">Precomputed HashString( AItem ).</param>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <returns>True when the key is present.</returns>
    function HasKey( AHash: Integer; const AItem: string ): Boolean; overload;

    /// <summary>Adds (AItem, AData) without checking for duplicates.</summary>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <param name="AData">Value to store.</param>
    /// <returns>AData.</returns>
    function Add( const AItem: string; const AData: string ): string; overload;
    /// <summary>Add overload accepting a precomputed hash.</summary>
    /// <param name="AHash">Precomputed HashString( AItem ).</param>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <param name="AData">Value to store.</param>
    /// <returns>AData.</returns>
    function Add( AHash: Integer; const AItem: string; const AData: string ): string; overload;
    /// <summary>Removes the entry for AItem and returns its previous value (empty when absent).</summary>
    /// <param name="AItem">Key; must not be empty.</param>
    /// <returns>The removed value; empty when the key was missing.</returns>
    function Remove( const AItem: string ): string;

    /// <summary>Number of stored entries.</summary>
    property Count: Integer read FCount;
  end;

/// <summary>Computes a fast hash of AItem in the range 0..MaxBucketItems-1.</summary>
/// <param name="AItem">String to hash.</param>
/// <returns>Bucket index in 0..MaxBucketItems-1; 0 for the empty string.</returns>
function HashString( const AItem: string ): Integer;

const
  /// <summary>Number of buckets used by TCustomBucketList.</summary>
  MaxBucketItems    = $1000;

type
  { The hash tables cannot be used with Key='' }
  /// <summary>Pointer to a TBucketListItem.</summary>
  PBucketListItem = ^TBucketListItem;
  /// <summary>Bucket entry mapping a Pointer key to a Pointer value with a chain link.</summary>
  TBucketListItem = record
    /// <summary>Pointer-typed key.</summary>
    Key: Pointer;
    /// <summary>Pointer-typed value.</summary>
    Value: Pointer;
    /// <summary>Next entry in the same bucket chain.</summary>
    Next: PBucketListItem;
  end;

  /// <summary>Callback used by TCustomBucketList.ForEach. Set AContinue to False to stop the iteration.</summary>
  TBucketProc = procedure( AInfo, AItem, AData: Pointer; out AContinue: Boolean );

  /// <summary>Pointer-to-Pointer hash list with $1000 buckets.</summary>
  TCustomBucketList = class( TObject )
  private
    /// <summary>Bucket array.</summary>
    FItems: array[ 0..MaxBucketItems - 1 ] of PBucketListItem;
    /// <summary>Total number of stored entries.</summary>
    FCount: Integer;
    /// <summary>Indexed-property getter; raises when AItem is absent.</summary>
    /// <param name="AItem">Key.</param>
    /// <returns>The stored value.</returns>
    /// <exception cref="EOSError">Raised (ERROR_INVALID_PARAMETER) when AItem is not in the list.</exception>
    function GetData( AItem: Pointer ): Pointer;
    /// <summary>Indexed-property setter; raises when AItem is absent.</summary>
    /// <param name="AItem">Key.</param>
    /// <param name="Value">New value.</param>
    /// <exception cref="EOSError">Raised (ERROR_INVALID_PARAMETER) when AItem is not in the list.</exception>
    procedure SetData( AItem: Pointer; const Value: Pointer );
  protected
    /// <summary>Returns the bucket index for AItem (overridable for custom hashing).</summary>
    /// <param name="AItem">Key.</param>
    /// <returns>Bucket index in 0..MaxBucketItems-1.</returns>
    function BucketFor( AItem: Pointer ): THashValue; virtual;
  public
    /// <summary>Frees every chained entry.</summary>
    destructor Destroy; override;
    /// <summary>Empties the list.</summary>
    procedure Clear; virtual;

    /// <summary>Adds (AItem, AData); duplicates are not detected.</summary>
    /// <param name="AItem">Key.</param>
    /// <param name="AData">Value to store.</param>
    /// <returns>AData.</returns>
    function Add( AItem, AData: Pointer ): Pointer;
    /// <summary>Removes the entry whose key matches AItem and returns the associated value.</summary>
    /// <param name="AItem">Key.</param>
    /// <returns>The removed value, or nil when the key was missing.</returns>
    function Remove( AItem: Pointer ): Pointer;

    /// <summary>Iterates over every entry calling AProc; iteration stops when AProc sets AContinue to False.</summary>
    /// <param name="AProc">Callback invoked for each entry.</param>
    /// <param name="AInfo">Passed through to AProc.</param>
    /// <returns>False when AProc stopped the iteration (or the list is empty); True when every entry was visited.</returns>
    function ForEach( AProc: TBucketProc; AInfo: Pointer = nil ): Boolean;
    /// <summary>Replaces this list's contents with a copy of AList.</summary>
    /// <param name="AList">Source list; nil or Self leaves this list empty.</param>
    procedure Assign( AList: TCustomBucketList );

    /// <summary>True when the list contains AItem.</summary>
    /// <param name="AItem">Key.</param>
    /// <returns>True when the key is present.</returns>
    function Exists( AItem: Pointer ): Boolean;
    /// <summary>Looks up AItem and returns its value via AData.</summary>
    /// <param name="AItem">Key.</param>
    /// <param name="AData">Receives the stored value; nil when the key is missing.</param>
    /// <returns>True when the key is present.</returns>
    function Find( AItem: Pointer; out AData: Pointer ): Boolean;
    /// <summary>Indexed accessor by key.</summary>
    property Data[ AItem: Pointer ]: Pointer read GetData write SetData; default;
  end;

  /// <summary>Bucket-size selector accepted by TBucketList.Create (currently informational only).</summary>
  TBucketListSizes = ( bl2, bl4, bl8, bl16, bl32, bl64, bl128, bl256 );

  /// <summary>TCustomBucketList descendant exposing the standard "buckets" constructor signature.</summary>
  TBucketList = class( TCustomBucketList )
  public
    /// <summary>Initialises the list. ABuckets is currently informational.</summary>
    /// <param name="ABuckets">Ignored; kept for source compatibility with Contnrs.TBucketList.</param>
    constructor Create( ABuckets: TBucketListSizes = bl16 );
  end;

  /// <summary>TBucketList variant whose hash function is tuned for module-handle keys.</summary>
  TModuleBucketList = class( TBucketList )
  protected
    /// <summary>Hashes AItem by shifting away the low 16 bits typical of HMODULE addresses.</summary>
    /// <param name="AItem">Module handle used as the key.</param>
    /// <returns>Bucket index in 0..MaxBucketItems-1.</returns>
    function BucketFor( AItem: Pointer ): THashValue; override;
  end;

implementation

/// <summary>
/// Hashes AItem as the original x86 assembler did - the string length plus the sum of the
/// character codes, masked to the bucket range - in Pascal, so it reads its parameter correctly
/// on Win64 as well as Win32.
/// </summary>
/// <param name="AItem">String to hash.</param>
/// <returns>Bucket index in 0..MaxBucketItems-1; 0 for the empty string.</returns>
function HashString( const AItem: string ): Integer;
begin
  if ( AItem = '' ) then
    Exit( 0 );

  var iSum: Cardinal := Cardinal( Length( AItem ) );
  for var cChar in AItem do
    iSum := iSum + Ord( cChar );

  Result            := Integer( iSum and ( MaxBucketItems - 1 ) );
end;

/// <summary>
/// Tests whether P points into the preallocated cache array that runs from AFirst to ALast, by
/// comparing full-width addresses (a 32-bit comparison misjudges it on Win64).
/// </summary>
/// <param name="P">Node address to test.</param>
/// <param name="AFirst">Address of the first cache element.</param>
/// <param name="ALast">Address of the last cache element.</param>
/// <returns>True when P is one of the cache elements, so it must not be disposed.</returns>
function IsCacheNode( P, AFirst, ALast: Pointer ): Boolean;
begin
  Result            := ( NativeUInt( P ) >= NativeUInt( AFirst ) ) and ( NativeUInt( P ) <= NativeUInt( ALast ) );
end;

{ TStringIntegerHash }

destructor TStringIntegerHash.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TStringIntegerHash.Clear;
var
  P, N              : PStringIntegerItem;
  i                 : Integer;
begin
  if FCount > 0 then
  begin
    for i := 0 to High( FItems ) do
    begin
      P             := FItems[ i ];
      while P <> nil do
      begin
        N           := P.Next;
        if not IsCacheNode( P, @FCacheItems[ 0 ], @FCacheItems[ High( FCacheItems ) ] ) then
          Dispose( P );
        P           := N;
        Dec( FCount );
      end;
      FItems[ i ]   := nil;
      if FCount = 0 then
        Break;
    end;
  end;
  FCount            := 0;
  FCacheIndex       := 0;
end;

function TStringIntegerHash.Add( const AItem: string; AData: Integer ): Integer;
begin
  Result            := Add( HashString( AItem ), AItem, AData );
end;

function TStringIntegerHash.Add( AHash: Integer; const AItem: string; AData: Integer ): Integer;
var
  N                 : PStringIntegerItem;
begin
  if FCacheIndex < Length( FCacheItems ) then
  begin
    N               := @FCacheItems[ FCacheIndex ];
    Inc( FCacheIndex );
  end
  else
    New( N );
  N.Next            := FItems[ AHash ];
  FItems[ AHash ]   := N;
  Inc( FCount );
  N.Key             := AItem;
  N.Value           := AData;
  Result            := AData;
end;

function TStringIntegerHash.Remove( const AItem: string ): Integer;
var
  Index             : Integer;
  P, N              : PStringIntegerItem;
begin
  Index             := HashString( AItem );
  N                 := FItems[ Index ];
  if N <> nil then
  begin
    if N.Key = AItem then
    begin
      Result        := N.Value;
      P             := N.Next;
      if not IsCacheNode( N, @FCacheItems[ 0 ], @FCacheItems[ High( FCacheItems ) ] ) then
        Dispose( N );
      FItems[ Index ] := P;
      Dec( FCount );
      Exit;
    end
    else
    begin
      P             := N;
      N             := N.Next;
      while N <> nil do
      begin
        if N.Key = AItem then
        begin
          Result    := N.Value;
          P.Next    := N.Next;
          if not IsCacheNode( N, @FCacheItems[ 0 ], @FCacheItems[ High( FCacheItems ) ] ) then
            Dispose( N );
          Dec( FCount );
          Exit;
        end;
        P           := N;
        N           := N.Next;
      end;
    end;
  end;
  Result            := 0;
end;

function TStringIntegerHash.Find( const AItem: string; out Value: Integer ): Boolean;
begin
  Result            := Find( HashString( AItem ), AItem, Value );
end;

function TStringIntegerHash.Find( AHash: Integer; const AItem: string; out Value: Integer ): Boolean;
var
  N                 : PStringIntegerItem;
begin
  Value             := 0;
  N                 := FItems[ AHash ];
  while N <> nil do
  begin
    if N.Key = AItem then
    begin
      Value         := N.Value;
      Result        := True;
      Exit;
    end;
    N               := N.Next;
  end;
  Result            := False;
end;

function TStringIntegerHash.HasKey( const AItem: string ): Boolean;
var
  Value             : Integer;
begin
  Result            := Find( HashString( AItem ), AItem, Value );
end;

function TStringIntegerHash.HasKey( AHash: Integer; const AItem: string ): Boolean;
var
  N                 : PStringIntegerItem;
begin
  N                 := FItems[ AHash ];
  while N <> nil do
  begin
    if N.Key = AItem then
    begin
      Result        := True;
      Exit;
    end;
    N               := N.Next;
  end;
  Result            := False;
end;

procedure TStringIntegerHash.SetValue( const AItem: string; AData: Integer );
begin
  SetValue( HashString( AItem ), AItem, AData );
end;

procedure TStringIntegerHash.SetValue( AHash: Integer; const AItem: string; AData: Integer );
var
  N                 : PStringIntegerItem;
begin
  N                 := FItems[ AHash ];
  while N <> nil do
  begin
    if N.Key = AItem then
    begin
      N.Value       := AData;
      Exit;
    end;
    N               := N.Next;
  end;
  Add( AHash, AItem, AData );
end;

{ TStringStringHash }

destructor TStringStringHash.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TStringStringHash.Clear;
var
  P, N              : PStringStringItem;
  i                 : Integer;
begin
  if FCount > 0 then
  begin
    for i := 0 to High( FItems ) do
    begin
      P             := FItems[ i ];
      while P <> nil do
      begin
        N           := P.Next;
        if not IsCacheNode( P, @FCacheItems[ 0 ], @FCacheItems[ High( FCacheItems ) ] ) then
          Dispose( P );
        P           := N;
        Dec( FCount );
      end;
      FItems[ i ]   := nil;
      if FCount = 0 then
        Break;
    end;
  end;
  FCount            := 0;
end;

function TStringStringHash.Add( const AItem: string; const AData: string ): string;
begin
  Result            := Add( HashString( AItem ), AItem, AData );
end;

function TStringStringHash.Add( AHash: Integer; const AItem: string; const AData: string ): string;
var
  N                 : PStringStringItem;
begin
  if FCacheIndex < Length( FCacheItems ) then
  begin
    N               := @FCacheItems[ FCacheIndex ];
    Inc( FCacheIndex );
  end
  else
    New( N );
  N.Next            := FItems[ AHash ];
  FItems[ AHash ]   := N;
  Inc( FCount );
  N.Key             := AItem;
  N.Value           := AData;
  Result            := AData;
end;

function TStringStringHash.Remove( const AItem: string ): string;
var
  Index             : Integer;
  P, N              : PStringStringItem;
begin
  Index             := HashString( AItem );
  N                 := FItems[ Index ];
  if N <> nil then
  begin
    if N.Key = AItem then
    begin
      Result        := N.Value;
      P             := N.Next;
      if not IsCacheNode( N, @FCacheItems[ 0 ], @FCacheItems[ High( FCacheItems ) ] ) then
        Dispose( N );
      FItems[ Index ] := P;
      Dec( FCount );
      Exit;
    end
    else
    begin
      P             := N;
      N             := N.Next;
      while N <> nil do
      begin
        if N.Key = AItem then
        begin
          Result    := N.Value;
          P.Next    := N.Next;
          if not IsCacheNode( N, @FCacheItems[ 0 ], @FCacheItems[ High( FCacheItems ) ] ) then
            Dispose( N );
          Dec( FCount );
          Exit;
        end;
        P           := N;
        N           := N.Next;
      end;
    end;
  end;
  Result            := '';
end;

function TStringStringHash.Find( const AItem: string; out Value: string ): Boolean;
begin
  Result            := Find( HashString( AItem ), AItem, Value );
end;

function TStringStringHash.Find( AHash: Integer; const AItem: string; out Value: string ): Boolean;
var
  N                 : PStringStringItem;
begin
  Value             := '';
  N                 := FItems[ AHash ];
  while N <> nil do
  begin
    if N.Key = AItem then
    begin
      Value         := N.Value;
      Result        := True;
      Exit;
    end;
    N               := N.Next;
  end;
  Result            := False;
end;

function TStringStringHash.HasKey( const AItem: string ): Boolean;
var
  Value             : string;
begin
  Result            := Find( HashString( AItem ), AItem, Value );
end;

function TStringStringHash.HasKey( AHash: Integer; const AItem: string ): Boolean;
var
  N                 : PStringStringItem;
begin
  N                 := FItems[ AHash ];
  while N <> nil do
  begin
    if N.Key = AItem then
    begin
      Result        := True;
      Exit;
    end;
    N               := N.Next;
  end;
  Result            := False;
end;

{ TCustomBucketList }

destructor TCustomBucketList.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TCustomBucketList.Add( AItem, AData: Pointer ): Pointer;
var
  N                 : PBucketListItem;
  Hash              : THashValue;
begin
  New( N );
  Hash              := BucketFor( AItem );
  N.Next            := FItems[ Hash ];
  FItems[ Hash ]    := N;
  Inc( FCount );
  N.Key             := AItem;
  N.Value           := AData;
  Result            := AData;
end;

procedure AssignProc( AInfo: Pointer; AItem, AData: Pointer; out AContinue: Boolean );
begin
  AContinue         := True;
  TCustomBucketList( AInfo ).Add( AItem, AData );
end;

procedure TCustomBucketList.Assign( AList: TCustomBucketList );
begin
  Clear;
  if ( AList <> nil ) and ( AList <> Self ) then
    AList.ForEach( AssignProc, Self );
end;

procedure TCustomBucketList.Clear;
var
  P, N              : PBucketListItem;
  i                 : Integer;
begin
  if FCount > 0 then
  begin
    for i := 0 to High( FItems ) do
    begin
      P             := FItems[ i ];
      while P <> nil do
      begin
        N           := P.Next;
        Dispose( P );
        P           := N;
        Dec( FCount );
      end;
      FItems[ i ]   := nil;
      if FCount = 0 then
        Break;
    end;
  end;
  FCount            := 0;
end;

function TCustomBucketList.Exists( AItem: Pointer ): Boolean;
var
  Data              : Pointer;
begin
  Result            := Find( AItem, Data );
end;

function TCustomBucketList.Find( AItem: Pointer; out AData: Pointer ): Boolean;
var
  N                 : PBucketListItem;
begin
  AData             := nil;
  N                 := FItems[ BucketFor( AItem ) ];
  while N <> nil do
  begin
    if N.Key = AItem then
    begin
      AData         := N.Value;
      Result        := True;
      Exit;
    end;
    N               := N.Next;
  end;
  Result            := False;
end;

function TCustomBucketList.ForEach( AProc: TBucketProc; AInfo: Pointer ): Boolean;
var
  P, N              : PBucketListItem;
  i                 : Integer;
begin
  Result            := False;
  if FCount > 0 then
  begin
    for i := 0 to High( FItems ) do
    begin
      P             := FItems[ i ];
      while P <> nil do
      begin
        N           := P.Next;
        AProc( AInfo, P.Key, P.Value, Result );
        if not Result then
          Exit;
        P           := N;
      end;
    end;
  end;
end;

function TCustomBucketList.GetData( AItem: Pointer ): Pointer;
begin
  if not Find( AItem, Result ) then
  begin
    SetLastError( ERROR_INVALID_PARAMETER );
    RaiseLastOSError;
  end;
end;

function TCustomBucketList.Remove( AItem: Pointer ): Pointer;
var
  Index             : THashValue;
  P, N              : PBucketListItem;
begin
  Index             := BucketFor( AItem );
  N                 := FItems[ Index ];
  if N <> nil then
  begin
    if N.Key = AItem then
    begin
      Result        := N.Value;
      P             := N.Next;
      Dispose( N );
      FItems[ Index ] := P;
      Dec( FCount );
      Exit;
    end
    else
    begin
      P             := N;
      N             := N.Next;
      while N <> nil do
      begin
        if N.Key = AItem then
        begin
          Result    := N.Value;
          P.Next    := N.Next;
          Dispose( N );
          Dec( FCount );
          Exit;
        end;
        P           := N;
        N           := N.Next;
      end;
    end;
  end;
  Result            := nil;
end;

procedure TCustomBucketList.SetData( AItem: Pointer; const Value: Pointer );
var
  N                 : PBucketListItem;
begin
  N                 := FItems[ BucketFor( AItem ) ];
  while N <> nil do
  begin
    if N.Key = AItem then
    begin
      N.Value       := Value;
      Exit;
    end;
    N               := N.Next;
  end;
  SetLastError( ERROR_INVALID_PARAMETER );
  RaiseLastOSError;
end;

function TCustomBucketList.BucketFor( AItem: Pointer ): THashValue;
begin
  Result            := THashValue( NativeUInt( AItem ) mod MaxBucketItems );
end;

{ TBucketList }

constructor TBucketList.Create( ABuckets: TBucketListSizes );
begin
  inherited Create;
end;

{ TModuleBucketList }

function TModuleBucketList.BucketFor( AItem: Pointer ): THashValue;
begin
  Result            := THashValue( ( NativeUInt( AItem ) shr 16 ) mod MaxBucketItems );
end;

end.

