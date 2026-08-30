{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit PathCompactor;

/// <summary>
/// Implements the IDE Path Compactor plugin: owns the Tools-menu item, the
/// persisted settings, and the macro table that <c>PathCompactorCore</c> needs
/// in order to expand library-path entries the way the IDE does.
/// </summary>
/// <remarks>
/// The registry layer is deliberately not reimplemented — <c>TLibraryPathHandler</c>
/// from <c>LibraryPathSorter</c> reads and writes the per-platform values, and
/// <c>TLibraryPathBackupManager</c> provides the entire backup and rollback
/// story. This unit adds only what the compactor needs on top.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, Vcl.Menus, PluginConfig;

type
  /// <summary>Plugin entry point that owns the Tools-menu item and the settings.</summary>
  TPathCompactorPlugin = class( TPluginConfig )
  private
    /// <summary>Backing field for Enabled.</summary>
    FEnabled: Boolean;
    /// <summary>Tools-menu item that opens the compactor dialog.</summary>
    FMenuItem: TMenuItem;
    /// <summary>Stored length at which the summary grid warns. The IDE's own threshold is undocumented.</summary>
    FWarnStoredLength: Integer;
    /// <summary>Also define accepted variables in the Windows user environment.</summary>
    FWriteUserEnvironment: Boolean;
    /// <summary>Semicolon-separated names of variables this plugin has created.</summary>
    FCreatedVariables: string;
    /// <summary>Semicolon-separated Link=Source pairs for junctions this plugin has created.</summary>
    FCreatedJunctions: string;
    /// <summary>OnClick handler for the Tools-menu item.</summary>
    procedure MenuItemClick( Sender: TObject );
  protected
    /// <summary>Sets the default values on first creation.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the plugin and inserts the Tools-menu item beneath the Path Sorter.</summary>
    constructor Create;
    /// <summary>Removes the menu item.</summary>
    destructor Destroy; override;

    /// <summary>Opens the compactor dialog.</summary>
    procedure ShowCompactor;

    /// <summary>Records AName as a variable this plugin created, if not already recorded.</summary>
    procedure RecordCreatedVariable( const AName: string );
    /// <summary>Returns the names of variables this plugin has created.</summary>
    function CreatedVariableNames: TArray<string>;
    /// <summary>Records a junction this plugin created, so its health can be checked on load.</summary>
    procedure RecordCreatedJunction( const ALinkPath, ASourcePath: string );
    /// <summary>Verifies every recorded junction still resolves; returns those that do not.</summary>
    function BrokenJunctions: TArray<string>;
  published
    /// <summary>Persisted enable flag for the plugin.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
    /// <summary>Stored length at which the summary grid warns.</summary>
    property WarnStoredLength: Integer read FWarnStoredLength write FWarnStoredLength;
    /// <summary>Also define accepted variables in the Windows user environment.</summary>
    property WriteUserEnvironment: Boolean read FWriteUserEnvironment write FWriteUserEnvironment;
    /// <summary>Semicolon-separated names of variables this plugin has created.</summary>
    property CreatedVariables: string read FCreatedVariables write FCreatedVariables;
    /// <summary>Semicolon-separated Link=Source pairs for junctions this plugin has created.</summary>
    property CreatedJunctions: string read FCreatedJunctions write FCreatedJunctions;
  end;

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
/// built-ins plus every process environment variable.
/// </summary>
/// <remarks>
/// <c>IDEUtils.ExpandDirMacros</c> consults the process environment first, so
/// shadowing one of its names would break path resolution well beyond this
/// feature.
/// </remarks>
procedure BuildReservedNames( AList: TStrings );

/// <summary>Returns the IDE installation root — the value of <c>$(BDS)</c>.</summary>
function BdsRootDir: string;

/// <summary>Plugin entry point that creates or frees PathCompactorPlugin.</summary>
procedure InitPlugin( Unload: Boolean );

/// <summary>Singleton instance of the plugin (nil when not loaded).</summary>
var
  PathCompactorPlugin: TPathCompactorPlugin;

implementation

uses
  Winapi.Windows, System.IOUtils, System.StrUtils,
  Vcl.Forms,
  ToolsAPI, IDEUtils, ToolsAPIHelpers, Main,
  PathCompactorCore, PathCompactorEnvVars, PathCompactorJunctions,
  FrmPathCompactor;

function BdsRootDir: string;
begin
  Result := ExtractFileDir( AppDir );
end;

procedure BuildMacroTable( AList: TStrings; const ABaseRegistryKey, APlatformName: string );
var
  Overrides: TStringList;
  EnvBlock, Entry: PChar;
  I: Integer;
  Root, Common, UserDir, VersionDir: string;
begin
  AList.Clear;
  AList.NameValueSeparator := '=';

  // 1. This IDE's user overrides. Which key that is depends on the IDE's
  //    bitness — see PathCompactorEnvVars.EnvironmentVariablesKey.
  Overrides := TStringList.Create;
  try
    ReadIdeVariables( EnvironmentVariablesKey( ABaseRegistryKey ), Overrides );
    for I := 0 to Overrides.Count - 1 do
      if Overrides.Names[I] <> '' then
        AList.Add( Overrides[I] );
  finally
    Overrides.Free;
  end;

  // 2. IDE built-ins. Added after the overrides so a user redefinition wins,
  //    which is how the IDE itself resolves them.
  //    The version folder is taken from the tail of the base registry key
  //    (".. \BDS\37.0" -> "37.0") rather than from IDEHooks.DelphiVersion,
  //    which carries the product number ("14"), not the registry version.
  Root := BdsRootDir;
  VersionDir := ABaseRegistryKey;
  if LastDelimiter( '\', VersionDir ) > 0 then
    VersionDir := Copy( VersionDir, LastDelimiter( '\', VersionDir ) + 1, MaxInt );

  Common := GetEnvironmentVariable( 'PUBLIC' ) +
    '\Documents\Embarcadero\Studio\' + VersionDir;
  UserDir := GetEnvironmentVariable( 'USERPROFILE' ) +
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
  EnvBlock := GetEnvironmentStrings;
  if EnvBlock <> nil then
  try
    Entry := EnvBlock;
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

procedure BuildReservedNames( AList: TStrings );
var
  EnvBlock, Entry: PChar;
  Name: string;
  SepPos: Integer;
begin
  AList.Clear;

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

  EnvBlock := GetEnvironmentStrings;
  if EnvBlock <> nil then
  try
    Entry := EnvBlock;
    while Entry^ <> #0 do
    begin
      if Entry^ <> '=' then
      begin
        Name := string( Entry );
        SepPos := Pos( '=', Name );
        if SepPos > 1 then
          AList.Add( Copy( Name, 1, SepPos - 1 ) );
      end;
      Inc( Entry, StrLen( Entry ) + 1 );
    end;
  finally
    FreeEnvironmentStrings( EnvBlock );
  end;
end;

{ TPathCompactorPlugin }

procedure TPathCompactorPlugin.Init;
begin
  inherited Init;
  FEnabled := True;
  FWarnStoredLength := 2048;
  FWriteUserEnvironment := False;
end;

constructor TPathCompactorPlugin.Create;
var
  ToolsMenu: TMenuItem;
  I, InsertIndex: Integer;
begin
  inherited Create( AppDataDirectory + '\PathCompactor.xml', 'PathCompactor' );

  ToolsMenu := FindMenuItem( 'ToolsMenu' );
  if ToolsMenu <> nil then
  begin
    FMenuItem := TMenuItem.Create( ToolsMenu );
    FMenuItem.Caption := 'IDE Path &Compactor...';
    FMenuItem.OnClick := MenuItemClick;

    // Sit directly beneath the Path Sorter. Searching for the sorter's own
    // caption rather than copying its "first item containing Build" scan
    // matters: two plugins both inserting at the Build item land at the same
    // index, so the order would depend on registration order, not intent.
    InsertIndex := -1;
    for I := 0 to ToolsMenu.Count - 1 do
      if Pos( 'IDE Path &Sorter', ToolsMenu.Items[I].Caption ) > 0 then
      begin
        InsertIndex := I + 1;
        Break;
      end;

    // The sorter is skippable via DDevExtensions.DisabledFeatures, so fall
    // back to the Build item when it is not there.
    if InsertIndex < 0 then
      for I := 0 to ToolsMenu.Count - 1 do
        if Pos( 'Build', ToolsMenu.Items[I].Caption ) > 0 then
        begin
          InsertIndex := I + 1;
          Break;
        end;

    if InsertIndex > 0 then
      ToolsMenu.Insert( InsertIndex, FMenuItem )
    else
      ToolsMenu.Add( FMenuItem );
  end;
end;

destructor TPathCompactorPlugin.Destroy;
begin
  FreeAndNil( FMenuItem );
  inherited Destroy;
end;

procedure TPathCompactorPlugin.MenuItemClick( Sender: TObject );
begin
  ShowCompactor;
end;

procedure TPathCompactorPlugin.ShowCompactor;
begin
  TFormPathCompactor.Execute;
end;

function TPathCompactorPlugin.CreatedVariableNames: TArray<string>;
var
  List: TStringList;
begin
  List := TStringList.Create;
  try
    List.Delimiter := ';';
    List.StrictDelimiter := True;
    List.DelimitedText := FCreatedVariables;
    Result := List.ToStringArray;
  finally
    List.Free;
  end;
end;

procedure TPathCompactorPlugin.RecordCreatedVariable( const AName: string );
var
  List: TStringList;
begin
  List := TStringList.Create;
  try
    List.Delimiter := ';';
    List.StrictDelimiter := True;
    List.CaseSensitive := False;
    List.DelimitedText := FCreatedVariables;
    if List.IndexOf( AName ) < 0 then
      List.Add( AName );
    FCreatedVariables := List.DelimitedText;
  finally
    List.Free;
  end;
  Save;
end;

procedure TPathCompactorPlugin.RecordCreatedJunction( const ALinkPath, ASourcePath: string );
var
  List: TStringList;
begin
  List := TStringList.Create;
  try
    List.Delimiter := ';';
    List.StrictDelimiter := True;
    List.NameValueSeparator := '=';
    List.DelimitedText := FCreatedJunctions;
    if List.IndexOfName( ALinkPath ) < 0 then
      List.Add( ALinkPath + '=' + ASourcePath );
    FCreatedJunctions := List.DelimitedText;
  finally
    List.Free;
  end;
  Save;
end;

function TPathCompactorPlugin.BrokenJunctions: TArray<string>;
var
  List: TStringList;
  I: Integer;
begin
  SetLength( Result, 0 );
  List := TStringList.Create;
  try
    List.Delimiter := ';';
    List.StrictDelimiter := True;
    List.NameValueSeparator := '=';
    List.DelimitedText := FCreatedJunctions;

    // A deleted junction silently breaks every path that depends on it, and the
    // resulting compile errors give no clue why — so this is checked on load.
    for I := 0 to List.Count - 1 do
      if ( List.Names[I] <> '' ) and
         not IsJunctionTo( List.Names[I], List.ValueFromIndex[I] ) then
      begin
        SetLength( Result, Length( Result ) + 1 );
        Result[High( Result )] := List.Names[I];
      end;
  finally
    List.Free;
  end;
end;

procedure InitPlugin( Unload: Boolean );
begin
  if not Unload then
    PathCompactorPlugin := TPathCompactorPlugin.Create
  else
  begin
    PathCompactorPlugin.Free;
    PathCompactorPlugin := nil;
  end;
end;

end.
