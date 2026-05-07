{ The contents of this file are subject to the Mozilla Public License
  Version 1.1 (the "License"); you may not use this file except in
  compliance with the License. You may obtain a copy of the License
  at http://www.mozilla.org/MPL/

  Software distributed under the License is distributed on an "AS IS"
  basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
  the License for the specific language governing rights and limitations
  under the License.

  The Original Code is unitVersionInfo.pas

  The Initial Developer of the Original Code is Miha Remec
    http://www.MihaRemec.com/mrExperts/

  Contributor(s) (in order of appearance):
    Collin Wilson
    Primoz Gabrijelcic
    Khaled Shagrouni
    Eric Pascual
    Larry Steeger
}

unit UnitVersionInfo;

/// <summary>
/// Reads and modifies the VS_VERSION_INFO resource of a loaded module or raw resource buffer.
/// Originally by Miha Remec; provides indexed access to StringFileInfo entries plus the fixed
/// file info structure, and can stream the (modified) resource back to disk.
/// </summary>

interface

uses
  Windows, Classes, SysUtils;

type
  /// <summary>Wraps a VS_VERSION_INFO resource and exposes its StringFileInfo entries via indexed properties.</summary>
  TVersionInfo = class
    /// <summary>Source module handle when constructed from a loaded executable; 0 when constructed from a raw buffer.</summary>
    fModule : THandle;
    /// <summary>Pointer to the start of the VS_VERSION_INFO block.</summary>
    fVersionInfo : PAnsiChar;
    /// <summary>Pointer to the version header (currently unused beyond construction).</summary>
    fVersionHeader : PAnsiChar;
    /// <summary>StringFileInfo entries: each Object is a TVersionStringValue.</summary>
    fChildStrings : TStringList;
    /// <summary>VarFileInfo translation list (DWORD packed lang/codepage values).</summary>
    fTranslations : TList;
    /// <summary>Cached pointer to the fixed file info structure embedded in the resource.</summary>
    fFixedInfo : PVSFixedFileInfo;
    /// <summary>Resource handle used to release the resource on destruction.</summary>
    fVersionResHandle : THandle;

  private
    /// <summary>Lazily parses the resource buffer; returns False on parse failure.</summary>
    function GetInfo : boolean;
    /// <summary>Returns the number of StringFileInfo entries.</summary>
    function GetKeyCount: Integer;
    /// <summary>Returns the key name at the supplied StringFileInfo index.</summary>
    function GetKeyName(idx: Integer): string;
    /// <summary>Returns the value associated with the supplied StringFileInfo key.</summary>
    /// <exception cref="Exception">Raised when the key cannot be found.</exception>
    function GetKeyValue(const idx: string): string;
    /// <summary>Sets or appends a StringFileInfo entry.</summary>
    procedure SetKeyValue(const idx, Value: string);
    /// <summary>Returns the fixed file info pointer or nil when the resource cannot be parsed.</summary>
    function GetFixedInfo: PVSFixedFileInfo;
  public
    /// <summary>Loads the VS_VERSION_INFO resource from the supplied module handle.</summary>
    /// <param name="AModule">Module handle whose resource to load.</param>
    /// <exception cref="Exception">Raised when the module has no version resource.</exception>
    constructor Create (AModule : THandle); overload;
    /// <summary>Wraps a raw VS_VERSION_INFO buffer.</summary>
    /// <param name="AVersionInfo">Pointer to a VS_VERSION_INFO block.</param>
    /// <exception cref="Exception">Raised when AVersionInfo is nil.</exception>
    constructor Create (AVersionInfo : PAnsiChar); overload;
    /// <summary>Releases the parsed strings and the resource handle (when applicable).</summary>
    destructor Destroy; override;
    /// <summary>Serialises the (possibly modified) VS_VERSION_INFO resource to strm.</summary>
    /// <param name="strm">Destination stream.</param>
    /// <exception cref="Exception">Raised when the resource cannot be parsed.</exception>
    procedure SaveToStream (strm : TStream);

    /// <summary>Pointer to the fixed file info structure, or nil when unavailable.</summary>
    property FixedFileInfo: PVSFixedFileInfo read GetFixedInfo; // ah

    /// <summary>Number of StringFileInfo entries in the resource.</summary>
    property KeyCount : Integer read GetKeyCount;
    /// <summary>Indexed StringFileInfo key names.</summary>
    property KeyName [idx : Integer] : string read GetKeyName;
    /// <summary>Indexed StringFileInfo key values; assigning a missing key appends a new entry.</summary>
    property KeyValue [const idx : string] : string read GetKeyValue write SetKeyValue;
  end;

implementation

{ TVersionInfo }

type
  TVersionStringValue = class
    fValue : string;
    fLangID, fCodePage : Integer;

    constructor Create (const AValue : string; ALangID, ACodePage : Integer);
  end;

{procedure DisplayMessage (const msg : string);
begin
  MessageBox (0, PChar (msg), '', MB_ICONINFORMATION)
end;}

constructor TVersionInfo.Create(AModule: THandle);
var
  resHandle : THandle;
begin
  fModule := AModule;
  fChildStrings := TStringList.Create;
  fTranslations := TList.Create;
  resHandle := FindResource (fModule, pointer (1), RT_VERSION);
  if resHandle <> 0 then
  begin
    fVersionResHandle := LoadResource (fModule, resHandle);
    if fVersionResHandle <> 0 then
      fVersionInfo := LockResource (fVersionResHandle)
  end;

  if not Assigned (fVersionInfo) then
    raise Exception.Create ('Unable to load version info resource');
end;

constructor TVersionInfo.Create(AVersionInfo: PAnsiChar);
begin
  fChildStrings := TStringList.Create;
  fTranslations := TList.Create;
  fVersionInfo := AVersionInfo;

  if not Assigned (fVersionInfo) then
    raise Exception.Create ('Unable to load version info resource');
end;

destructor TVersionInfo.Destroy;
var
  i : Integer;
begin
  for i := 0 to fChildStrings.Count - 1 do
    fChildStrings.Objects [i].Free;

  fChildStrings.Free;
  fTranslations.Free;
  if fVersionResHandle <> 0 then
    FreeResource (fVersionResHandle);
  inherited;
end;

function TVersionInfo.GetFixedInfo: PVSFixedFileInfo;
begin
  if GetInfo then
    Result := fFixedInfo
  else
    Result := nil;
end;

function TVersionInfo.GetInfo : boolean;
var
  p : PAnsiChar;
  t, wLength, wValueLength, wType : word;
  key : string;

  varwLength, varwValueLength, varwType : word;
  varKey : string;

  function GetVersionHeader (var p : PAnsiChar; var wLength, wValueLength, wType : word; var key : string) : Integer;
  var
    szKey : PWideChar;
    baseP : PAnsiChar;
  begin
    baseP := p;
    wLength := PWord (p)^;
    Inc (p, sizeof (word));
    wValueLength := PWord (p)^;
    Inc (p, sizeof (word));
    wType := PWord (p)^;
    Inc (p, sizeof (word));
    szKey := PWideChar (p);
    Inc (p, (lstrlenw (szKey) + 1) * sizeof (WideChar));
    while Integer (p) mod 4 <> 0 do
      Inc (p);
    result := p - baseP;
    key := szKey;
  end;

  procedure GetStringChildren (var base : PAnsiChar; len : word);
  var
    p, strBase : PAnsiChar;
    t, wLength, wValueLength, wType, wStrLength, wStrValueLength, wStrType : word;
    key, value : string;
    i, langID, codePage : Integer;

  begin
    p := base;
    while (p - base) < len do
    begin
      t := GetVersionHeader (p, wLength, wValueLength, wType, key);
      Dec (wLength, t);

      langID := StrToInt ('$' + Copy (key, 1, 4));
      codePage := StrToInt ('$' + Copy (key, 5, 4));

      strBase := p;
      for i := 0 to fChildStrings.Count - 1 do
        fChildStrings.Objects [i].Free;
      fChildStrings.Clear;

      while (p - strBase) < wLength do
      begin
        t := GetVersionHeader (p, wStrLength, wStrValueLength, wStrType, key);
        Dec (wStrLength, t);

        if wStrValueLength = 0 then
          value := ''
        else
          value := PWideChar (p);
        Inc (p, wStrLength);
        while Integer (p) mod 4 <> 0 do
          Inc (p);

        fChildStrings.AddObject (key, TVersionStringValue.Create (value, langID, codePage))
      end
    end;
    base := p
  end;

  procedure GetVarChildren (var base : PAnsiChar; len : word);
  var
    p, strBase : PAnsiChar;
    t, wLength, wValueLength, wType: word;
    key : string;
    v : DWORD;

  begin
    p := base;
    while (p - base) < len do
    begin
      t := GetVersionHeader (p, wLength, wValueLength, wType, key);
      Dec (wLength, t);

      strBase := p;
      fTranslations.Clear;

      while (p - strBase) < wLength do
      begin
        v := PDWORD (p)^;
        Inc (p, sizeof (DWORD));
        fTranslations.Add (pointer (v));
      end
    end;
    base := p
  end;

begin
  result := False;
  if not Assigned (fFixedInfo) then
  try
    p := fVersionInfo;
    GetVersionHeader (p, wLength, wValueLength, wType, key);

    if wValueLength <> 0 then
    begin
      fFixedInfo := PVSFixedFileInfo (p);
      if fFixedInfo^.dwSignature <> $feef04bd then
        raise Exception.Create ('Invalid version resource');

      Inc (p, wValueLength);
      while Integer (p) mod 4 <> 0 do
        Inc (p);
    end
    else
      fFixedInfo := Nil;

    while wLength > (p - fVersionInfo) do
    begin
      t := GetVersionHeader (p, varwLength, varwValueLength, varwType, varKey);
      Dec (varwLength, t);

      if varKey = 'StringFileInfo' then
        GetStringChildren (p, varwLength)
      else
        if varKey = 'VarFileInfo' then
          GetVarChildren (p, varwLength)
        else
          break;
    end;

    result := True;
  except
  end
  else
    result := True
end;

function TVersionInfo.GetKeyCount: Integer;
begin
  if GetInfo then
    result := fChildStrings.Count
  else
    result := 0;
end;

function TVersionInfo.GetKeyName(idx: Integer): string;
begin
  if idx >= KeyCount then
    raise ERangeError.Create ('Index out of range')
  else
    result := fChildStrings [idx];
end;

function TVersionInfo.GetKeyValue(const idx: string): string;
var
  i : Integer;
begin
  if GetInfo then
  begin
    i := fChildStrings.IndexOf (idx);
    if i <> -1 then
      result := TVersionStringValue (fChildStrings.Objects [i]).fValue
    else
      raise Exception.Create ('Key not found')
  end
  else
    raise Exception.Create ('Key not found')
end;

procedure TVersionInfo.SaveToStream(strm: TStream);
var
  zeros, v : DWORD;
  wSize : WORD;
  stringInfoStream : TMemoryStream;
  strg : TVersionStringValue;
  i, p, p1 : Integer;
  wValue : UnicodeString;

  procedure PadStream (strm : TStream);
  begin
    if strm.Position mod 4 <> 0 then
      strm.Write (zeros, 4 - (strm.Position mod 4))
  end;

  procedure SaveVersionHeader (strm : TStream; wLength, wValueLength, wType : word; const key : string; const value);
  var
    wKey : UnicodeString;
    valueLen : word;
    keyLen : word;
  begin
    wKey := key;
    strm.Write (wLength, sizeof (wLength));

    strm.Write (wValueLength, sizeof (wValueLength));
    strm.Write (wType, sizeof (wType));
    keyLen := (Length (wKey) + 1) * sizeof (WideChar);
    strm.Write (wKey [1], keyLen);

    PadStream (strm);

    if wValueLength > 0 then
    begin
      valueLen := wValueLength;
      if wType = 1 then
        valueLen := valueLen * sizeof (WideChar);
      strm.Write (value, valueLen)
    end;
  end;

begin { SaveToStream }
  if GetInfo then
  begin
    zeros := 0;

    SaveVersionHeader (strm, 0, sizeof (fFixedInfo^), 0, 'VS_VERSION_INFO', fFixedInfo^);

    if fChildStrings.Count > 0 then
    begin
      stringInfoStream := TMemoryStream.Create;
      try
        strg := TVersionStringValue (fChildStrings.Objects [0]);

        SaveVersionHeader (stringInfoStream, 0, 0, 0, IntToHex (strg.fLangID, 4) + IntToHex (strg.fCodePage, 4), zeros);

        for i := 0 to fChildStrings.Count - 1 do
        begin
          PadStream (stringInfoStream);

          p := stringInfoStream.Position;
          strg := TVersionStringValue (fChildStrings.Objects [i]);
          wValue := strg.fValue;
          if Length(wValue) > 0 then
            SaveVersionHeader (stringInfoStream, 0, Length (strg.fValue) + 1, 1, fChildStrings [i], wValue [1])
          else
            SaveVersionHeader (stringInfoStream, 0, Length (strg.fValue) + 1, 0, fChildStrings [i], PChar(wValue)^);
          wSize := stringInfoStream.Size - p;
          stringInfoStream.Seek (p, soFromBeginning);
          stringInfoStream.Write (wSize, sizeof (wSize));
          stringInfoStream.Seek (0, soFromEnd);

        end;

        stringInfoStream.Seek (0, soFromBeginning);
        wSize := stringInfoStream.Size;
        stringInfoStream.Write (wSize, sizeof (wSize));

        PadStream (strm);
        p := strm.Position;
        SaveVersionHeader (strm, 0, 0, 0, 'StringFileInfo', zeros);
        strm.Write (stringInfoStream.Memory^, stringInfoStream.size);
        wSize := strm.Size - p;
      finally
        stringInfoStream.Free
      end;
      strm.Seek (p, soFromBeginning);
      strm.Write (wSize, sizeof (wSize));
      strm.Seek (0, soFromEnd)
    end;

    if fTranslations.Count > 0 then
    begin
      PadStream (strm);
      p := strm.Position;
      SaveVersionHeader (strm, 0, 0, 0, 'VarFileInfo', zeros);
      PadStream (strm);

      p1 := strm.Position;
      SaveVersionHeader (strm, 0, 0, 0, 'Translation', zeros);

      for i := 0 to fTranslations.Count - 1 do
      begin
        v := Integer (fTranslations [i]);
        strm.Write (v, sizeof (v))
      end;

      wSize := strm.Size - p1;
      strm.Seek (p1, soFromBeginning);
      strm.Write (wSize, sizeof (wSize));
      wSize := sizeof (Integer) * fTranslations.Count;
      strm.Write (wSize, sizeof (wSize));

      wSize := strm.Size - p;
      strm.Seek (p, soFromBeginning);
      strm.Write (wSize, sizeof (wSize));
    end;

    strm.Seek (0, soFromBeginning);
    wSize := strm.Size;
    strm.Write (wSize, sizeof (wSize));
    strm.Seek (0, soFromEnd);
  end
  else
    raise Exception.Create ('Invalid version resource');
end;

procedure TVersionInfo.SetKeyValue(const idx, Value: string);
var
  i : Integer;
begin
  if GetInfo then
  begin
    i := fChildStrings.IndexOf (idx);
    if i = -1 then
      i := fChildStrings.AddObject (idx, TVersionStringValue.Create (idx, 0, 0));

    TVersionStringValue (fChildStrings.Objects [i]).fValue := Value
  end
  else
    raise Exception.Create ('Invalid version resource');
end;

{ TVersionStringValue }

constructor TVersionStringValue.Create(const AValue: string; ALangID,
  ACodePage: Integer);
begin
  fValue := AValue;
  fCodePage := ACodePage;
  fLangID := ALangID;
end;

end.
