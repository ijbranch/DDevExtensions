{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit VersionInfoKeys;

/// <summary>
/// Parsing and editing of the IDE's <c>VerInfo_Keys</c> project option: a <c>;</c>-separated list
/// of <c>Name=Value</c> pairs.  Kept free of ToolsAPI so it can be unit-tested.  The RTL's
/// <c>ExtractStrings</c> must not be used for it: it treats <c>'</c> and <c>"</c> as quotes, so a
/// value such as <c>Ian's Company</c> swallowed every key after it.
/// </summary>

interface

uses
  System.Classes;

/// <summary>Splits a <c>VerInfo_Keys</c> string on <c>;</c> only, skipping empty segments.</summary>
/// <param name="AKeys">The option value, such as <c>CompanyName=Ian's Co;FileVersion=1.0.0.0</c>.</param>
/// <param name="AList">Receives one <c>Name=Value</c> line per key; it is cleared first.</param>
procedure SplitVersionInfoKeys( const AKeys: string; AList: TStrings );

/// <summary>Joins the lines of AList with <c>;</c> to form a <c>VerInfo_Keys</c> string.</summary>
/// <param name="AList">One <c>Name=Value</c> line per key.</param>
/// <returns>The joined option value.</returns>
function JoinVersionInfoKeys( AList: TStrings ): string;

/// <summary>
/// Sets the value of key AName in AList, replacing the first line with that name (compared
/// without regard to case) or appending a new line.  An empty AValue is stored as <c>Name=</c>;
/// unlike <c>TStrings.Values</c>, the key is never deleted.
/// </summary>
/// <param name="AList">One <c>Name=Value</c> line per key.</param>
/// <param name="AName">Key name.</param>
/// <param name="AValue">New value; may be empty.</param>
procedure SetVersionInfoKey( AList: TStrings; const AName, AValue: string );

/// <summary>Returns a copy of AKeys with key AName set to AValue (see SetVersionInfoKey).</summary>
/// <param name="AKeys">The original <c>VerInfo_Keys</c> value.</param>
/// <param name="AName">Key name.</param>
/// <param name="AValue">New value; may be empty.</param>
/// <returns>The updated option value.</returns>
function UpdateVersionInfoKey( const AKeys, AName, AValue: string ): string;

implementation

uses
  System.SysUtils;

procedure SplitVersionInfoKeys( const AKeys: string; AList: TStrings );
begin
  AList.BeginUpdate;
  try
    AList.Clear;
    for var sPart in AKeys.Split( [';'] ) do
      if ( sPart <> '' ) then
        AList.Add( sPart );
  finally
    AList.EndUpdate;
  end;
end;

function JoinVersionInfoKeys( AList: TStrings ): string;
begin
  Result := string.Join( ';', AList.ToStringArray );
end;

procedure SetVersionInfoKey( AList: TStrings; const AName, AValue: string );
begin
  var iIndex := AList.IndexOfName( AName );
  if ( iIndex >= 0 ) then
    AList[iIndex] := AList.Names[iIndex] + AList.NameValueSeparator + AValue
  else
    AList.Add( AName + AList.NameValueSeparator + AValue );
end;

function UpdateVersionInfoKey( const AKeys, AName, AValue: string ): string;
begin
  var oList := TStringList.Create;
  try
    SplitVersionInfoKeys( AKeys, oList );
    SetVersionInfoKey( oList, AName, AValue );
    Result := JoinVersionInfoKeys( oList );
  finally
    oList.Free;
  end;
end;

end.
