{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit PathCompactorEnvVars;

/// <summary>
/// Reads and writes the IDE's user-defined macro overrides, and optionally the
/// Windows user environment, for the IDE Path Compactor.
/// </summary>
/// <remarks>
/// RAD Studio keeps <b>two independent</b> user-variable lists —
/// <c>Environment Variables</c> is read by the 32-bit IDE (<c>bin\bds.exe</c>)
/// and <c>Environment Variables x64</c> by the 64-bit IDE
/// (<c>bin64\bds.exe</c>) — while the <c>Library\&lt;Platform&gt;</c> path keys
/// they resolve are <b>not</b> split and are shared by both. A variable written
/// to only one list therefore resolves in one IDE and silently breaks the other.
/// Everything in this unit writes both lists for that reason.
///
/// <c>BorlandIDEServices.GetBaseRegistryKey</c> returns the same value in both
/// IDEs, so <c>BaseRegistryKey + '\Environment Variables'</c> names the 32-bit
/// list even when running inside the 64-bit IDE — see
/// <see cref="EnvironmentVariablesKey"/>.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes;

type
  /// <summary>Describes a variable that is not defined identically in both IDE lists.</summary>
  TEnvVarDivergence = record
    /// <summary>Variable name.</summary>
    Name: string;
    /// <summary>Value held by the 32-bit IDE's list, or empty when absent.</summary>
    Value32: string;
    /// <summary>Value held by the 64-bit IDE's list, or empty when absent.</summary>
    Value64: string;
    /// <summary>True when the variable is missing from one list altogether.</summary>
    MissingFromOne: Boolean;
  end;

/// <summary>Registry sub-key holding the IDE macro overrides for THIS IDE's bitness.</summary>
function EnvironmentVariablesKey( const ABaseRegistryKey: string ): string;

/// <summary>Registry sub-key holding the 32-bit IDE's macro overrides.</summary>
function EnvironmentVariablesKey32( const ABaseRegistryKey: string ): string;

/// <summary>Registry sub-key holding the 64-bit IDE's macro overrides.</summary>
function EnvironmentVariablesKey64( const ABaseRegistryKey: string ): string;

/// <summary>
/// Reads one IDE macro-override list into AList as <c>Name=Value</c> pairs.
/// </summary>
procedure ReadIdeVariables( const AKey: string; AList: TStrings );

/// <summary>
/// Compares the two IDE lists and returns every variable that is absent from
/// one of them or holds a different value in each.
/// </summary>
/// <remarks>
/// A divergence means any shared library-path entry using that macro resolves
/// in one IDE only. The compactor reports these; it never repairs them silently.
/// </remarks>
function FindDivergences( const ABaseRegistryKey: string ): TArray<TEnvVarDivergence>;

/// <summary>
/// Writes AName=AValue to <b>both</b> IDE macro-override lists, and — only when
/// AWriteUserEnvironment is True — to <c>HKCU\Environment</c> as well.
/// </summary>
/// <param name="ABaseRegistryKey">The IDE's base registry key.</param>
/// <param name="AName">Variable name, without the surrounding <c>$(</c> and <c>)</c>.</param>
/// <param name="AValue">Literal absolute path to store.</param>
/// <param name="AWriteUserEnvironment">
/// When True, also define the variable in the Windows user environment. Off by
/// default in the dialog: command-line MSBuild does not read the IDE library
/// path, so this only helps a hand-edited <c>.dproj</c>.
/// </param>
procedure WriteVariable( const ABaseRegistryKey, AName, AValue: string;
  AWriteUserEnvironment: Boolean );

/// <summary>Removes AName from both IDE lists and from the Windows user environment.</summary>
procedure DeleteVariable( const ABaseRegistryKey, AName: string );

/// <summary>
/// Broadcasts WM_SETTINGCHANGE so Explorer and newly launched processes pick up
/// user-environment changes. The running IDE will not see it — its environment
/// block was captured at launch — which is one reason Apply requires a restart.
/// </summary>
procedure BroadcastEnvironmentChange;

implementation

uses
  System.Win.Registry, IDEUtils;

function EnvironmentVariablesKey32( const ABaseRegistryKey: string ): string;
begin
  Result := ABaseRegistryKey + '\Environment Variables';
end;

function EnvironmentVariablesKey64( const ABaseRegistryKey: string ): string;
begin
  Result := ABaseRegistryKey + '\Environment Variables x64';
end;

function EnvironmentVariablesKey( const ABaseRegistryKey: string ): string;
begin
  {$IFDEF CPUX64}
  Result := EnvironmentVariablesKey64( ABaseRegistryKey );
  {$ELSE}
  Result := EnvironmentVariablesKey32( ABaseRegistryKey );
  {$ENDIF}
end;

procedure ReadIdeVariables( const AKey: string; AList: TStrings );
var
  Reg: TRegistry;
  Names: TStringList;
  I: Integer;
begin
  AList.Clear;
  Reg := TRegistry.Create( KEY_READ );
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if not Reg.OpenKeyReadOnly( AKey ) then
      Exit;

    Names := TStringList.Create;
    try
      Reg.GetValueNames( Names );
      for I := 0 to Names.Count - 1 do
        AList.Add( Names[I] + '=' + Reg.ReadString( Names[I] ) );
    finally
      Names.Free;
    end;
  finally
    Reg.Free;
  end;
end;

function FindDivergences( const ABaseRegistryKey: string ): TArray<TEnvVarDivergence>;
var
  List32, List64, AllNames: TStringList;
  I, Index32, Index64: Integer;
  Item: TEnvVarDivergence;
begin
  SetLength( Result, 0 );

  List32 := TStringList.Create;
  List64 := TStringList.Create;
  AllNames := TStringList.Create;
  try
    List32.CaseSensitive := False;
    List64.CaseSensitive := False;
    AllNames.CaseSensitive := False;
    AllNames.Duplicates := dupIgnore;
    AllNames.Sorted := True;

    ReadIdeVariables( EnvironmentVariablesKey32( ABaseRegistryKey ), List32 );
    ReadIdeVariables( EnvironmentVariablesKey64( ABaseRegistryKey ), List64 );

    for I := 0 to List32.Count - 1 do
      if List32.Names[I] <> '' then
        AllNames.Add( List32.Names[I] );
    for I := 0 to List64.Count - 1 do
      if List64.Names[I] <> '' then
        AllNames.Add( List64.Names[I] );

    for I := 0 to AllNames.Count - 1 do
    begin
      Index32 := List32.IndexOfName( AllNames[I] );
      Index64 := List64.IndexOfName( AllNames[I] );

      Item.Name := AllNames[I];
      if Index32 >= 0 then
        Item.Value32 := List32.ValueFromIndex[Index32]
      else
        Item.Value32 := '';
      if Index64 >= 0 then
        Item.Value64 := List64.ValueFromIndex[Index64]
      else
        Item.Value64 := '';

      Item.MissingFromOne := ( Index32 < 0 ) or ( Index64 < 0 );
      if Item.MissingFromOne or not SameText( Item.Value32, Item.Value64 ) then
      begin
        SetLength( Result, Length( Result ) + 1 );
        Result[High( Result )] := Item;
      end;
    end;
  finally
    AllNames.Free;
    List64.Free;
    List32.Free;
  end;
end;

procedure WriteVariable( const ABaseRegistryKey, AName, AValue: string;
  AWriteUserEnvironment: Boolean );
begin
  // Both IDE lists, always — the path they resolve is shared between the two
  // IDEs, so defining the variable in only one guarantees a silent break.
  RegWriteString( HKEY_CURRENT_USER, EnvironmentVariablesKey32( ABaseRegistryKey ),
    AName, AValue );
  RegWriteString( HKEY_CURRENT_USER, EnvironmentVariablesKey64( ABaseRegistryKey ),
    AName, AValue );

  if AWriteUserEnvironment then
    RegWriteString( HKEY_CURRENT_USER, 'Environment', AName, AValue );
end;

procedure DeleteVariable( const ABaseRegistryKey, AName: string );

  procedure DeleteFrom( const AKey: string );
  var
    Reg: TRegistry;
  begin
    Reg := TRegistry.Create( KEY_READ or KEY_WRITE );
    try
      Reg.RootKey := HKEY_CURRENT_USER;
      if Reg.OpenKey( AKey, False ) and Reg.ValueExists( AName ) then
        Reg.DeleteValue( AName );
    finally
      Reg.Free;
    end;
  end;

begin
  DeleteFrom( EnvironmentVariablesKey32( ABaseRegistryKey ) );
  DeleteFrom( EnvironmentVariablesKey64( ABaseRegistryKey ) );
  DeleteFrom( 'Environment' );
end;

procedure BroadcastEnvironmentChange;
var
  Res: DWORD_PTR;
begin
  Res := 0;
  SendMessageTimeout( HWND_BROADCAST, WM_SETTINGCHANGE, 0,
    LPARAM( PChar( 'Environment' ) ), SMTO_ABORTIFHUNG, 5000, @Res );
end;

end.
