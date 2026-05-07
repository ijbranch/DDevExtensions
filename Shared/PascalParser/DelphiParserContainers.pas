{******************************************************************************}
{*                                                                            *}
{* Container classes                                                          *}
{*                                                                            *}
{* (C) 2005 Andreas Hausladen                                                 *}
{*                                                                            *}
{******************************************************************************}

unit DelphiParserContainers;

/// <summary>
/// Lightweight container helpers used by the Pascal lexer/parser units. Wraps TStringList to
/// provide hash-table semantics (THashtable, TStringDictionary), an integer-typed TList
/// (TIntegerList) and a TStringCollection convenience subclass.
/// </summary>

{$DEFINE D9}

interface

uses
  SysUtils, Classes;

type
  /// <summary>Sorted TStringList that overrides CompareStrings to honour CaseSensitive without locale folding.</summary>
  THashtableStringList = class(TStringList)
  protected
    /// <summary>Compares S1 and S2 using CompareStr or CompareText depending on CaseSensitive.</summary>
    function CompareStrings(const S1: string; const S2: string): Integer; override;
  end;

  /// <summary>Sorted hash-table mapping case-sensitive (or insensitive) string keys to TObject values.</summary>
  THashtable = class(TObject)
  private
    /// <summary>Backing sorted string list holding the keys.</summary>
    FItems: THashtableStringList;
    /// <summary>When True the table frees stored values on Remove/Destroy.</summary>
    FOwnsObjects: Boolean;
    /// <summary>Returns the number of stored entries.</summary>
    function GetCount: Integer; {$IFDEF D9}inline;{$ENDIF}
    /// <summary>Default-property getter that returns nil for missing keys.</summary>
    function GetValue(const AKey: string): TObject; {$IFDEF D9}inline;{$ENDIF}
    /// <summary>Indexed getter for sequential iteration in storage order.</summary>
    function GetItem(Index: Integer): TObject; {$IFDEF D9}inline;{$ENDIF}
  public
    /// <summary>Initialises an empty hash-table.</summary>
    /// <param name="CaseSensitive">Whether keys are compared case-sensitively.</param>
    /// <param name="AOwnsObjects">When True, stored values are freed automatically.</param>
    constructor Create(CaseSensitive: Boolean; AOwnsObjects: Boolean = True);
    /// <summary>Frees stored values (when ownership is enabled) and the backing list.</summary>
    destructor Destroy; override;
    /// <summary>Empties the table without freeing values.</summary>
    procedure Clear;

    /// <summary>Removes and (optionally) frees the entry for AKey.</summary>
    procedure Remove(const AKey: string);
    /// <summary>Inserts (AKey, AValue); raises when AKey already exists.</summary>
    procedure Add(const AKey: string; AValue: TObject); {$IFDEF D9}inline;{$ENDIF}
    /// <summary>True when AKey is present in the table.</summary>
    function Contains(const AKey: string): Boolean; {$IFDEF D9}inline;{$ENDIF}

    /// <summary>Default indexed accessor by key; returns nil for missing entries.</summary>
    property Values[const AKey: string]: TObject read GetValue; default;
    /// <summary>Sequential accessor for iteration in storage order.</summary>
    property Items[Index: Integer]: TObject read GetItem;
    /// <summary>Number of stored entries.</summary>
    property Count: Integer read GetCount;
  end;

  /// <summary>TList descendant that exposes its slots as Integers via casts to/from Pointer.</summary>
  TIntegerList = class(TList)
  private
    /// <summary>Returns the integer stored at Index.</summary>
    function GetItem(Index: Integer): Integer; {$IFDEF D9}inline;{$ENDIF}
    /// <summary>Stores an integer at Index.</summary>
    procedure SetItem(Index: Integer; const Value: Integer);{$IFDEF D9}inline;{$ENDIF}
  public
    /// <summary>Appends Value and returns its index.</summary>
    function Add(Value: Integer): Integer; {$IFDEF D9}inline;{$ENDIF}
    /// <summary>Indexed accessor for the integer slots.</summary>
    property Items[Index: Integer]: Integer read GetItem write SetItem; default;
  end;

  /// <summary>Sorted string-to-string dictionary backed by a key list and a separate value pool.</summary>
  TStringDictionary = class(TObject)
  private
    /// <summary>Sorted key list; each Object stores the index into FValues.</summary>
    FItems: THashtableStringList;
    /// <summary>Value pool referenced by FItems.</summary>
    FValues: TStringList;
    /// <summary>Returns the number of stored entries.</summary>
    function GetCount: Integer;
    /// <summary>Default-property getter; returns '' for missing keys.</summary>
    function GetValue(const AKey: string): string;
  public
    /// <summary>Initialises an empty dictionary.</summary>
    constructor Create;
    /// <summary>Releases internal storage.</summary>
    destructor Destroy; override;

    /// <summary>Inserts (AKey, AValue); raises when AKey already exists.</summary>
    procedure Add(const AKey: string; const AValue: string);
    /// <summary>True when AKey is present.</summary>
    function Contains(const AKey: string): Boolean;
    /// <summary>Returns the value for AKey, or '' when missing.</summary>
    function Find(const AKey: string): string;

    /// <summary>Default indexed accessor by key.</summary>
    property Values[const AKey: string]: string read GetValue; default;
    /// <summary>Number of stored entries.</summary>
    property Count: Integer read GetCount;
  end;

  /// <summary>TStringList descendant exposing Contains and RemoveAt convenience methods.</summary>
  TStringCollection = class(TStringList)
  public
    /// <summary>True when Value is present in the list.</summary>
    function Contains(const Value: string): Boolean;
    /// <summary>Removes the entry at Index (alias for Delete).</summary>
    procedure RemoveAt(Index: Integer);
  end;

implementation

{ THashtable }

constructor THashtable.Create(CaseSensitive: Boolean; AOwnsObjects: Boolean);
begin
  inherited Create;
  FOwnsObjects := AOwnsObjects;
  FItems := THashtableStringList.Create;
  FItems.Sorted := True;
  FItems.Duplicates := dupError;
  {$IFDEF COMPILER6_UP}
  FItems.CaseSensitive := CaseSensitive;
  {$ELSE}
  Assert(CaseSensitive = False, 'TStringList has no CaseSensitive property in Delphi 5');
  {$ENDIF COMPILER6_UP}
end;

destructor THashtable.Destroy;
var
  i: Integer;
begin
  if FOwnsObjects then
    for i := 0 to Count - 1 do
      FItems.Objects[i].Free;
  FItems.Free;
  inherited Destroy;
end;

function THashtable.Contains(const AKey: string): Boolean;
begin
  Result := FItems.IndexOf(AKey) >= 0;
end;

function THashtable.GetCount: Integer;
begin
  Result := FItems.Count;
end;

procedure THashtable.Add(const AKey: string; AValue: TObject);
begin
  FItems.AddObject(AKey, AValue);
end;

function THashtable.GetValue(const AKey: string): TObject;
var
  Index: Integer;
begin
  if FItems.Find(AKey, Index) then
    Result := FItems.Objects[Index]
  else
    Result := nil;
end;

procedure THashtable.Remove(const AKey: string);
var
  Index: Integer;
begin
  if FItems.Find(AKey, Index) then
  begin
    if FOwnsObjects then
      FItems.Objects[Index].Free;
    FItems.Delete(Index);
  end;
end;

procedure THashtable.Clear;
begin
  FItems.Clear;
end;

function THashtable.GetItem(Index: Integer): TObject;
begin
  Result := FItems.Objects[Index];
end;

{ TIntegerList }

function TIntegerList.GetItem(Index: Integer): Integer;
begin
  Result := Integer(inherited Items[Index]);
end;

function TIntegerList.Add(Value: Integer): Integer;
begin
  Result := inherited Add(Pointer(Value));
end;

procedure TIntegerList.SetItem(Index: Integer; const Value: Integer);
begin
  inherited Items[Index] := Pointer(Value);
end;

{ TStringCollection }

function TStringCollection.Contains(const Value: string): Boolean;
begin
  Result := IndexOf(Value) >= 0;
end;

procedure TStringCollection.RemoveAt(Index: Integer);
begin
  Delete(Index);
end;

{ TStringDictionary }

constructor TStringDictionary.Create;
begin
  inherited Create;
  FItems := THashtableStringList.Create;
  FValues := TStringList.Create;
  FItems.Sorted := True;
  FItems.Duplicates := dupError;
end;

destructor TStringDictionary.Destroy;
begin
  FItems.Free;
  FValues.Free;
  inherited Destroy;
end;

function TStringDictionary.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TStringDictionary.GetValue(const AKey: string): string;
var
  Index: Integer;
begin
  Result := '';
  if FItems.Find(AKey, Index) then
    if Integer(FItems.Objects[Index]) >= 0 then
      Result := FValues[Integer(FItems.Objects[Index])];
end;

procedure TStringDictionary.Add(const AKey: string; const AValue: string);
begin
  FItems.AddObject(AKey, Pointer(FValues.Add(AValue)));
end;

function TStringDictionary.Contains(const AKey: string): Boolean;
var
  Index: Integer;
begin
  Result := FItems.Find(AKey, Index);
end;

function TStringDictionary.Find(const AKey: string): string;
begin
  Result := Values[AKey];
end;

{ THashtableStringList }

function THashtableStringList.CompareStrings(const S1, S2: string): Integer;
begin
  if CaseSensitive then
    Result := CompareStr(S1, S2)
  else
    Result := CompareText(S1, S2);
end;

end.
