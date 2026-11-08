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

  /// <summary>Raised when a variable cannot be written, would replace a different value, or reads back differently.</summary>
  EPathVariableError = class( Exception );

  /// <summary>A place a variable is defined: either IDE list, or the Windows user environment.</summary>
  TVariableLocation = ( vlIde32, vlIde64, vlUserEnvironment );
  /// <summary>A set of variable locations.</summary>
  TVariableLocations = set of TVariableLocation;

/// <summary>Registry sub-key holding the IDE macro overrides for THIS IDE's bitness.</summary>
/// <param name="ABaseRegistryKey">The IDE's base registry key.</param>
/// <returns>The 64-bit IDE's key in a Win64 build, otherwise the 32-bit IDE's key.</returns>
function EnvironmentVariablesKey( const ABaseRegistryKey: string ): string;

/// <summary>Registry sub-key holding the 32-bit IDE's macro overrides.</summary>
/// <param name="ABaseRegistryKey">The IDE's base registry key.</param>
/// <returns>ABaseRegistryKey\Environment Variables.</returns>
function EnvironmentVariablesKey32( const ABaseRegistryKey: string ): string;

/// <summary>Registry sub-key holding the 64-bit IDE's macro overrides.</summary>
/// <param name="ABaseRegistryKey">The IDE's base registry key.</param>
/// <returns>ABaseRegistryKey\Environment Variables x64.</returns>
function EnvironmentVariablesKey64( const ABaseRegistryKey: string ): string;

/// <summary>
/// Reads one IDE macro-override list into AList as <c>Name=Value</c> pairs.
/// </summary>
/// <param name="AKey">The registry key under HKEY_CURRENT_USER.</param>
/// <param name="AList">Receives the pairs; cleared first, and left empty when the key does not exist.</param>
procedure ReadIdeVariables( const AKey: string; AList: TStrings );

/// <summary>
/// Compares the two IDE lists and returns every variable that is absent from
/// one of them or holds a different value in each.
/// </summary>
/// <remarks>
/// A divergence means any shared library-path entry using that macro resolves
/// in one IDE only. The compactor reports these; it never repairs them silently.
/// </remarks>
/// <param name="ABaseRegistryKey">The IDE's base registry key.</param>
/// <returns>The divergent variables; empty when the lists agree.</returns>
function FindDivergences( const ABaseRegistryKey: string ): TArray<TEnvVarDivergence>;

/// <summary>
/// Writes AName=AValue to <b>both</b> IDE macro-override lists, and — only when
/// AWriteUserEnvironment is True — to <c>HKCU\Environment</c> as well. Every write is
/// verified by reading it back. A location that already holds a DIFFERENT value is never
/// overwritten; one already holding this value is left alone.
/// </summary>
/// <returns>The locations this call created, i.e. those to delete to undo it.</returns>
/// <exception cref="EPathVariableError">
/// A location holds a different value, a key could not be opened, or a value did not read
/// back as written. Locations created by this call before the failure are removed again.
/// </exception>
/// <param name="ABaseRegistryKey">The IDE's base registry key.</param>
/// <param name="AName">Variable name, without the surrounding <c>$(</c> and <c>)</c>.</param>
/// <param name="AValue">Literal absolute path to store.</param>
/// <param name="AWriteUserEnvironment">
/// When True, also define the variable in the Windows user environment. Off by
/// default in the dialog: command-line MSBuild does not read the IDE library
/// path, so this only helps a hand-edited <c>.dproj</c>.
/// </param>
function WriteVariable( const ABaseRegistryKey, AName, AValue: string;
  AWriteUserEnvironment: Boolean ): TVariableLocations;

/// <summary>Removes AName from the given locations only.</summary>
/// <param name="ABaseRegistryKey">The IDE's base registry key.</param>
/// <param name="AName">Variable name.</param>
/// <param name="ALocations">
/// Where to remove it from. Pass only locations this tool wrote: a same-named
/// Windows variable the user owns is never touched otherwise.
/// </param>
procedure DeleteVariable( const ABaseRegistryKey, AName: string; ALocations: TVariableLocations );

/// <summary>
/// Builds the names of macros that may safely be REUSED for a library-path prefix: those
/// that resolve to the same value in both IDE bitnesses and in every future session.
/// </summary>
/// <remarks>
/// A name defined in either IDE list qualifies only when both lists define it with the
/// same value. Otherwise it qualifies when it is an IDE built-in, a persisted Windows
/// variable (<c>HKCU\Environment</c>, the machine environment) or a stable system
/// variable such as <c>USERPROFILE</c>. A variable present only in this process's
/// environment (set by whatever launched the IDE) never qualifies, and neither does
/// <c>ProgramFiles</c>, which differs between the 32-bit and 64-bit IDE.
/// </remarks>
/// <param name="AList">Receives the names; cleared first.</param>
/// <param name="ABaseRegistryKey">The IDE's base registry key.</param>
procedure BuildReusableNames( AList: TStrings; const ABaseRegistryKey: string );

/// <summary>
/// Builds the macro table for <c>PathCompactorCore</c>, in the documented
/// precedence order: this IDE's user overrides, then the IDE built-ins, then
/// the process environment, then <c>PLATFORM</c> for the key being read.
/// </summary>
/// <param name="AList">Receives <c>Name=Value</c> pairs; cleared first.</param>
/// <param name="ABaseRegistryKey">The IDE's base registry key.</param>
/// <param name="APlatformName">
/// The platform of the registry key being examined — deliberately NOT the
/// active project's platform, which is what makes <c>IDEUtils.ExpandDirMacros</c>
/// unusable here.
/// </param>
procedure BuildMacroTable( AList: TStrings; const ABaseRegistryKey, APlatformName: string );

/// <summary>
/// Builds the list of names that must never be used for a new variable: the IDE
/// built-ins, every process environment variable, and every persisted Windows
/// variable (including ones added after the IDE started).
/// </summary>
/// <param name="AList">Receives the names; cleared first.</param>
/// <remarks>
/// <c>IDEUtils.ExpandDirMacros</c> consults the process environment first, so
/// shadowing one of its names would break path resolution well beyond this
/// feature.
/// </remarks>
procedure BuildReservedNames( AList: TStrings );

/// <summary>Returns the IDE installation root — the value of <c>$(BDS)</c>.</summary>
/// <returns>The parent folder of the IDE's bin folder.</returns>
function BdsRootDir: string;

/// <summary>
/// Broadcasts WM_SETTINGCHANGE so Explorer and newly launched processes pick up
/// user-environment changes. The running IDE will not see it — its environment
/// block was captured at launch — which is one reason Apply requires a restart.
/// </summary>
procedure BroadcastEnvironmentChange;

implementation

uses
  System.Win.Registry, System.StrUtils, System.RegularExpressions, IDEUtils;

function BdsRootDir: string;
begin
  Result            := ExtractFileDir( AppDir );
end;

procedure BuildMacroTable( AList: TStrings; const ABaseRegistryKey, APlatformName: string );
var
  Overrides         : TStringList;
  EnvBlock, Entry   : PChar;
  I                 : Integer;
  Root, Common, UserDir, VersionDir: string;
begin
  AList.Clear;
  AList.NameValueSeparator := '=';

  // 1. This IDE's user overrides. Which key that is depends on the IDE's
  //    bitness — see PathCompactorEnvVars.EnvironmentVariablesKey.
  Overrides         := TStringList.Create;
  try
    ReadIdeVariables( EnvironmentVariablesKey( ABaseRegistryKey ), Overrides );
    for I := 0 to Overrides.Count - 1 do
      if Overrides.Names[ I ] <> '' then
        AList.Add( Overrides[ I ] );
  finally
    Overrides.Free;
  end;

  // 2. IDE built-ins. Added after the overrides so a user redefinition wins,
  //    which is how the IDE itself resolves them.
  //    The version folder is taken from the tail of the base registry key
  //    (".. \BDS\37.0" -> "37.0") rather than from IDEHooks.DelphiVersion,
  //    which carries the product number ("14"), not the registry version.
  Root              := BdsRootDir;
  VersionDir        := ABaseRegistryKey;
  if LastDelimiter( '\', VersionDir ) > 0 then
    VersionDir      := Copy( VersionDir, LastDelimiter( '\', VersionDir ) + 1, MaxInt );

  Common            := GetEnvironmentVariable( 'PUBLIC' ) +
    '\Documents\Embarcadero\Studio\' + VersionDir;
  UserDir           := GetEnvironmentVariable( 'USERPROFILE' ) +
    '\Documents\Embarcadero\Studio\' + VersionDir;

  AList.Add( 'BDS=' + Root );
  AList.Add( 'BCB=' + Root );
  AList.Add( 'DELPHI=' + Root );
  AList.Add( 'BDSINCLUDE=' + Root + '\include' );
  AList.Add( 'BDSLIB=' + Root + '\lib' );
  AList.Add( 'BDSCOMMONDIR=' + Common );
  AList.Add( 'BDSUSERDIR=' + UserDir );
  AList.Add( 'BDSCATALOGREPOSITORY=' + UserDir + '\CatalogRepository' );
  AList.Add( 'BDSCATALOGREPOSITORYALLUSERS=' + Common + '\CatalogRepository' );
  AList.Add( 'BDSPROJECTSDIR=' + GetBDSProjectsDir );

  // 3. The process environment.
  EnvBlock          := GetEnvironmentStrings;
  if EnvBlock <> nil then
    try
      Entry         := EnvBlock;
      while Entry^ <> #0 do
      begin
        // Skip the "=C:=..." drive-current-directory pseudo-variables.
        if Entry^ <> '=' then
          AList.Add( string( Entry ) );
        Inc( Entry, StrLen( Entry ) + 1 );
      end;
    finally
      FreeEnvironmentStrings( EnvBlock );
    end;

  // 4. PLATFORM is the platform of the key being read, never the active
  //    project's. Added last so an explicit override still wins.
  if APlatformName <> '' then
    AList.Add( 'PLATFORM=' + APlatformName );
end;

const
  /// <summary>The IDE's built-in macros.</summary>
  BuiltInNames      : array[ 0..9 ] of string = ( 'BDS', 'BCB', 'DELPHI', 'BDSINCLUDE', 'BDSLIB', 'BDSCOMMONDIR',
    'BDSUSERDIR', 'BDSCATALOGREPOSITORY', 'BDSCATALOGREPOSITORYALLUSERS', 'BDSPROJECTSDIR' );
  /// <summary>System variables Windows sets for every process, with the same value whatever the bitness.</summary>
  StableSystemNames : array[ 0..13 ] of string = ( 'USERPROFILE', 'PUBLIC', 'APPDATA', 'LOCALAPPDATA', 'ProgramData',
    'ALLUSERSPROFILE', 'SystemRoot', 'SystemDrive', 'windir', 'ProgramFiles(x86)', 'ProgramW6432',
    'CommonProgramFiles(x86)', 'CommonProgramW6432', 'HOMEDRIVE' );
  /// <summary>The machine-wide environment key under HKEY_LOCAL_MACHINE.</summary>
  MachineEnvironmentKey = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';

/// <summary>Adds the value names of a registry key to AList.</summary>
/// <param name="ARoot">HKEY_CURRENT_USER or HKEY_LOCAL_MACHINE.</param>
/// <param name="AKey">The key path.</param>
/// <param name="AList">Receives the names.</param>
procedure AddValueNames( ARoot: HKEY; const AKey: string; AList: TStrings );
begin
  var Reg           := TRegistry.Create( KEY_READ );
  try
    Reg.RootKey     := ARoot;
    if Reg.OpenKeyReadOnly( AKey ) then
    begin
      var Names     := TStringList.Create;
      try
        Reg.GetValueNames( Names );
        AList.AddStrings( Names );
      finally
        Names.Free;
      end;
    end;
  finally
    Reg.Free;
  end;
end;

/// <summary>
/// Adds the names of the persisted variables under a key whose stored value expands the same in
/// the 32-bit and the 64-bit IDE. A value built from <c>%ProgramFiles%</c>, <c>%CommonProgramFiles%</c>,
/// <c>%ProgramW6432%</c> or a <c>%PROCESSOR_*%</c> variable expands differently by bitness, so it
/// is left out.
/// </summary>
/// <param name="ARoot">HKEY_CURRENT_USER or HKEY_LOCAL_MACHINE.</param>
/// <param name="AKey">The environment key.</param>
/// <param name="AList">Receives the names.</param>
procedure AddBitnessNeutralNames( ARoot: HKEY; const AKey: string; AList: TStrings );
begin
  var Reg           := TRegistry.Create( KEY_READ );
  try
    Reg.RootKey     := ARoot;
    if not Reg.OpenKeyReadOnly( AKey ) then
      Exit;
    var Names       := TStringList.Create;
    try
      Reg.GetValueNames( Names );
      for var Name in Names do
      begin
        // ReadString returns REG_EXPAND_SZ data unexpanded, which is what is tested here.
        var Raw := '';
        if ( Reg.GetDataType( Name ) in [ rdString, rdExpandString ] ) then
          Raw       := Reg.ReadString( Name );
        if not TRegEx.IsMatch( Raw, '%(ProgramFiles(\(x86\))?|CommonProgramFiles[^%]*|ProgramW6432|PROCESSOR_[^%]*)%',
          [ roIgnoreCase ] ) then
          AList.Add( Name );
      end;
    finally
      Names.Free;
    end;
  finally
    Reg.Free;
  end;
end;

procedure BuildReusableNames( AList: TStrings; const ABaseRegistryKey: string );
begin
  AList.Clear;
  var List32        := TStringList.Create;
  var List64        := TStringList.Create;
  var Persisted     := TStringList.Create;
  var Names         := TStringList.Create;
  try
    List32.CaseSensitive := False;
    List64.CaseSensitive := False;
    Persisted.CaseSensitive := False;
    Names.CaseSensitive := False;
    Names.Sorted    := True;
    Names.Duplicates := dupIgnore;

    ReadIdeVariables( EnvironmentVariablesKey32( ABaseRegistryKey ), List32 );
    ReadIdeVariables( EnvironmentVariablesKey64( ABaseRegistryKey ), List64 );
    AddBitnessNeutralNames( HKEY_CURRENT_USER, 'Environment', Persisted );
    AddBitnessNeutralNames( HKEY_LOCAL_MACHINE, MachineEnvironmentKey, Persisted );

    for var Name in BuiltInNames do
      Names.Add( Name );
    for var Name in StableSystemNames do
      Names.Add( Name );
    for var I := 0 to List32.Count - 1 do
      Names.Add( List32.Names[ I ] );
    for var I := 0 to List64.Count - 1 do
      Names.Add( List64.Names[ I ] );
    Names.AddStrings( Persisted );

    for var I := 0 to Names.Count - 1 do
    begin
      var Name      := Names[ I ];
      if ( Name = '' ) then
        Continue;
      var Index32   := List32.IndexOfName( Name );
      var Index64   := List64.IndexOfName( Name );
      if ( Index32 >= 0 ) or ( Index64 >= 0 ) then
      begin
        // An IDE override decides the value: it must be the same in both IDEs.
        if ( Index32 >= 0 ) and ( Index64 >= 0 ) and
          SameText( List32.ValueFromIndex[ Index32 ], List64.ValueFromIndex[ Index64 ] ) then
          AList.Add( Name );
      end
      else
        AList.Add( Name ); // a built-in, a persisted Windows variable or a stable system one
    end;
  finally
    Names.Free;
    Persisted.Free;
    List64.Free;
    List32.Free;
  end;
end;

procedure BuildReservedNames( AList: TStrings );
var
  EnvBlock, Entry   : PChar;
  Name              : string;
  SepPos            : Integer;
begin
  AList.Clear;

  // Persisted Windows variables, including any added since this IDE started: its own
  // environment block was captured at launch and does not show them.
  AddValueNames( HKEY_CURRENT_USER, 'Environment', AList );
  AddValueNames( HKEY_LOCAL_MACHINE, MachineEnvironmentKey, AList );

  AList.Add( 'BDS' );
  AList.Add( 'BCB' );
  AList.Add( 'DELPHI' );
  AList.Add( 'BDSINCLUDE' );
  AList.Add( 'BDSLIB' );
  AList.Add( 'BDSCOMMONDIR' );
  AList.Add( 'BDSUSERDIR' );
  AList.Add( 'BDSCATALOGREPOSITORY' );
  AList.Add( 'BDSCATALOGREPOSITORYALLUSERS' );
  AList.Add( 'BDSPROJECTSDIR' );
  AList.Add( 'PLATFORM' );
  AList.Add( 'CONFIG' );
  AList.Add( 'LANGDIR' );

  EnvBlock          := GetEnvironmentStrings;
  if EnvBlock <> nil then
    try
      Entry         := EnvBlock;
      while Entry^ <> #0 do
      begin
        if Entry^ <> '=' then
        begin
          Name      := string( Entry );
          SepPos    := Pos( '=', Name );
          if SepPos > 1 then
            AList.Add( Copy( Name, 1, SepPos - 1 ) );
        end;
        Inc( Entry, StrLen( Entry ) + 1 );
      end;
    finally
      FreeEnvironmentStrings( EnvBlock );
    end;
end;

function EnvironmentVariablesKey32( const ABaseRegistryKey: string ): string;
begin
  Result            := ABaseRegistryKey + '\Environment Variables';
end;

function EnvironmentVariablesKey64( const ABaseRegistryKey: string ): string;
begin
  Result            := ABaseRegistryKey + '\Environment Variables x64';
end;

function EnvironmentVariablesKey( const ABaseRegistryKey: string ): string;
begin
{$IFDEF CPUX64}
  Result            := EnvironmentVariablesKey64( ABaseRegistryKey );
{$ELSE}
  Result            := EnvironmentVariablesKey32( ABaseRegistryKey );
{$ENDIF}
end;

procedure ReadIdeVariables( const AKey: string; AList: TStrings );
var
  Reg               : TRegistry;
  Names             : TStringList;
  I                 : Integer;
begin
  AList.Clear;
  Reg               := TRegistry.Create( KEY_READ );
  try
    Reg.RootKey     := HKEY_CURRENT_USER;
    if not Reg.OpenKeyReadOnly( AKey ) then
      Exit;

    Names           := TStringList.Create;
    try
      Reg.GetValueNames( Names );
      for I := 0 to Names.Count - 1 do
        AList.Add( Names[ I ] + '=' + Reg.ReadString( Names[ I ] ) );
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
  Item              : TEnvVarDivergence;
begin
  SetLength( Result, 0 );

  List32            := TStringList.Create;
  List64            := TStringList.Create;
  AllNames          := TStringList.Create;
  try
    List32.CaseSensitive := False;
    List64.CaseSensitive := False;
    AllNames.CaseSensitive := False;
    AllNames.Duplicates := dupIgnore;
    AllNames.Sorted := True;

    ReadIdeVariables( EnvironmentVariablesKey32( ABaseRegistryKey ), List32 );
    ReadIdeVariables( EnvironmentVariablesKey64( ABaseRegistryKey ), List64 );

    for I := 0 to List32.Count - 1 do
      if List32.Names[ I ] <> '' then
        AllNames.Add( List32.Names[ I ] );
    for I := 0 to List64.Count - 1 do
      if List64.Names[ I ] <> '' then
        AllNames.Add( List64.Names[ I ] );

    for I := 0 to AllNames.Count - 1 do
    begin
      Index32       := List32.IndexOfName( AllNames[ I ] );
      Index64       := List64.IndexOfName( AllNames[ I ] );

      Item.Name     := AllNames[ I ];
      if Index32 >= 0 then
        Item.Value32 := List32.ValueFromIndex[ Index32 ]
      else
        Item.Value32 := '';
      if Index64 >= 0 then
        Item.Value64 := List64.ValueFromIndex[ Index64 ]
      else
        Item.Value64 := '';

      Item.MissingFromOne := ( Index32 < 0 ) or ( Index64 < 0 );
      if Item.MissingFromOne or not SameText( Item.Value32, Item.Value64 ) then
      begin
        SetLength( Result, Length( Result ) + 1 );
        Result[ High( Result ) ] := Item;
      end;
    end;
  finally
    AllNames.Free;
    List64.Free;
    List32.Free;
  end;
end;

/// <summary>Returns the HKCU key that holds a variable location.</summary>
/// <param name="ABaseRegistryKey">The IDE's base registry key.</param>
/// <param name="ALocation">The location.</param>
/// <returns>The key path under HKEY_CURRENT_USER.</returns>
function LocationKey( const ABaseRegistryKey: string; ALocation: TVariableLocation ): string;
begin
  case ALocation of
    vlIde32:
      Result        := EnvironmentVariablesKey32( ABaseRegistryKey );
    vlIde64:
      Result        := EnvironmentVariablesKey64( ABaseRegistryKey );
  else
    Result          := 'Environment';
  end;
end;

/// <summary>Writes one value unless it is already there, and verifies it by read-back.</summary>
/// <param name="AKey">Key under HKEY_CURRENT_USER.</param>
/// <param name="AName">Value name.</param>
/// <param name="AValue">Value data.</param>
/// <returns>True when the value was created; False when it already held AValue.</returns>
/// <exception cref="EPathVariableError">The value exists with other data, the key cannot be opened, or the read-back differs.</exception>
function WriteOne( const AKey, AName, AValue: string ): Boolean;
begin
  var Reg           := TRegistry.Create( KEY_READ or KEY_WRITE );
  try
    Reg.RootKey     := HKEY_CURRENT_USER;
    if not Reg.OpenKey( AKey, True ) then
      raise EPathVariableError.CreateFmt( 'The registry key "HKCU\%s" could not be opened for writing.', [ AKey ] );

    if Reg.ValueExists( AName ) then
    begin
      var Existing  := '';
      if ( Reg.GetDataType( AName ) in [ rdString, rdExpandString ] ) then
        Existing    := Reg.ReadString( AName );
      if SameText( Existing, AValue ) then
        Exit( False );
      raise EPathVariableError.CreateFmt( '"%s" is already defined in HKCU\%s with a different value (%s); ' +
        'it was not replaced.', [ AName, AKey, Existing ] );
    end;

    Reg.WriteString( AName, AValue );
    if not Reg.ValueExists( AName ) or ( Reg.ReadString( AName ) <> AValue ) then
      raise EPathVariableError.CreateFmt( '"%s" did not read back as written in HKCU\%s.', [ AName, AKey ] );
    Result          := True;
  finally
    Reg.Free;
  end;
end;

function WriteVariable( const ABaseRegistryKey, AName, AValue: string;
  AWriteUserEnvironment: Boolean ): TVariableLocations;
begin
  Result            := [ ];
  try
    // Both IDE lists, always — the path they resolve is shared between the two
    // IDEs, so defining the variable in only one guarantees a silent break.
    if WriteOne( LocationKey( ABaseRegistryKey, vlIde32 ), AName, AValue ) then
      Include( Result, vlIde32 );
    if WriteOne( LocationKey( ABaseRegistryKey, vlIde64 ), AName, AValue ) then
      Include( Result, vlIde64 );
    if AWriteUserEnvironment and WriteOne( LocationKey( ABaseRegistryKey, vlUserEnvironment ), AName, AValue ) then
      Include( Result, vlUserEnvironment );
  except
    // Leave nothing half-defined.
    DeleteVariable( ABaseRegistryKey, AName, Result );
    raise;
  end;
end;

procedure DeleteVariable( const ABaseRegistryKey, AName: string; ALocations: TVariableLocations );
begin
  for var Location in ALocations do
  begin
    var Reg := TRegistry.Create( KEY_READ or KEY_WRITE );
    try
      Reg.RootKey   := HKEY_CURRENT_USER;
      if Reg.OpenKey( LocationKey( ABaseRegistryKey, Location ), False ) and Reg.ValueExists( AName ) then
        Reg.DeleteValue( AName );
    finally
      Reg.Free;
    end;
  end;
end;

procedure BroadcastEnvironmentChange;
var
  Res               : DWORD_PTR;
begin
  Res               := 0;
  SendMessageTimeout( HWND_BROADCAST, WM_SETTINGCHANGE, 0,
    LPARAM( PChar( 'Environment' ) ), SMTO_ABORTIFHUNG, 5000, @Res );
end;

end.

