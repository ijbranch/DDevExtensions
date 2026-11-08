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
  System.SysUtils, System.Classes, Vcl.Menus, PluginConfig, PathCompactorEnvVars;

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
    /// <summary>Semicolon-separated names of variables this plugin has written to the Windows user environment.</summary>
    FCreatedEnvironmentVariables: string;
    /// <summary>
    /// Where each created variable was written, as <c>NAME=locations</c> lines, the locations
    /// being the ordinal bitmask of TVariableLocations. Only these places are ever cleaned up.
    /// </summary>
    FCreatedVariableLocations: string;
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

    /// <summary>Records AName as a variable this plugin created, if not already recorded, and saves the settings.</summary>
    /// <param name="AName">The variable name.</param>
    /// <param name="ALocations">The places this plugin created it (not those where it already existed).</param>
    procedure RecordCreatedVariable( const AName: string; ALocations: TVariableLocations );
    /// <summary>Forgets AName as a created variable (after it has been removed) and saves the settings.</summary>
    /// <param name="AName">The variable name.</param>
    procedure ForgetCreatedVariable( const AName: string );
    /// <summary>Returns the names of variables this plugin has created.</summary>
    /// <returns>The names, in the order they were recorded.</returns>
    function CreatedVariableNames: TArray<string>;
    /// <summary>The places this plugin created AName, and so the only places it may remove it from.</summary>
    /// <remarks>
    /// A variable recorded by an older build, without locations, is taken to be in both IDE lists, and
    /// in the Windows user environment only if it was recorded as written there.
    /// </remarks>
    /// <param name="AName">The variable name.</param>
    /// <returns>The recorded locations.</returns>
    function CreatedLocations( const AName: string ): TVariableLocations;
  published
    /// <summary>Persisted enable flag for the plugin.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
    /// <summary>Stored length at which the summary grid warns.</summary>
    property WarnStoredLength: Integer read FWarnStoredLength write FWarnStoredLength;
    /// <summary>Also define accepted variables in the Windows user environment.</summary>
    property WriteUserEnvironment: Boolean read FWriteUserEnvironment write FWriteUserEnvironment;
    /// <summary>Semicolon-separated names of variables this plugin has created.</summary>
    property CreatedVariables: string read FCreatedVariables write FCreatedVariables;
    /// <summary>Semicolon-separated names of variables this plugin has written to the Windows user environment.</summary>
    property CreatedEnvironmentVariables: string read FCreatedEnvironmentVariables write FCreatedEnvironmentVariables;
    /// <summary>Where each created variable was written; see CreatedLocations.</summary>
    property CreatedVariableLocations: string read FCreatedVariableLocations write FCreatedVariableLocations;
  end;

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
  PathCompactorCore,
  FrmPathCompactor;

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

/// <summary>Adds or removes AName in a semicolon-separated name list.</summary>
/// <param name="AList">The list text.</param>
/// <param name="AName">The name.</param>
/// <param name="APresent">True to add it, False to remove it.</param>
/// <returns>The updated list text.</returns>
function UpdateNameList( const AList, AName: string; APresent: Boolean ): string;
begin
  var List := TStringList.Create;
  try
    List.Delimiter := ';';
    List.StrictDelimiter := True;
    List.CaseSensitive := False;
    List.DelimitedText := AList;
    var Index := List.IndexOf( AName );
    if APresent and ( Index < 0 ) then
      List.Add( AName )
    else if not APresent and ( Index >= 0 ) then
      List.Delete( Index );
    Result := List.DelimitedText;
  finally
    List.Free;
  end;
end;

/// <summary>Converts a location set to and from the integer stored in the settings.</summary>
/// <param name="ALocations">The set.</param>
/// <returns>Its bitmask.</returns>
function LocationsToMask( ALocations: TVariableLocations ): Integer;
begin
  Result := 0;
  for var Location in ALocations do
    Result := Result or ( 1 shl Ord( Location ) );
end;

/// <summary>Converts a stored bitmask back to a location set.</summary>
/// <param name="AMask">The bitmask.</param>
/// <returns>The set.</returns>
function MaskToLocations( AMask: Integer ): TVariableLocations;
begin
  Result := [];
  for var Location := Low( TVariableLocation ) to High( TVariableLocation ) do
    if ( AMask and ( 1 shl Ord( Location ) ) ) <> 0 then
      Include( Result, Location );
end;

/// <summary>Returns ALines with the NAME=VALUE line for AName replaced, added or (AValue empty) removed.</summary>
/// <param name="ALines">The lines, separated by semicolons.</param>
/// <param name="AName">The name.</param>
/// <param name="AValue">The new value, or empty to remove the line.</param>
/// <returns>The updated text.</returns>
function UpdateValueList( const ALines, AName, AValue: string ): string;
begin
  var List := TStringList.Create;
  try
    List.Delimiter := ';';
    List.StrictDelimiter := True;
    List.CaseSensitive := False;
    List.DelimitedText := ALines;
    var Index := List.IndexOfName( AName );
    if ( Index >= 0 ) then
      List.Delete( Index );
    if ( AValue <> '' ) then
      List.Add( AName + '=' + AValue );
    Result := List.DelimitedText;
  finally
    List.Free;
  end;
end;

procedure TPathCompactorPlugin.RecordCreatedVariable( const AName: string; ALocations: TVariableLocations );
begin
  FCreatedVariables := UpdateNameList( FCreatedVariables, AName, True );
  if ( vlUserEnvironment in ALocations ) then
    FCreatedEnvironmentVariables := UpdateNameList( FCreatedEnvironmentVariables, AName, True );
  // Merge with any earlier record: a later run may have created it in more places.
  FCreatedVariableLocations := UpdateValueList( FCreatedVariableLocations, AName,
    IntToStr( LocationsToMask( CreatedLocations( AName ) + ALocations ) ) );
  Save;
end;

procedure TPathCompactorPlugin.ForgetCreatedVariable( const AName: string );
begin
  FCreatedVariables := UpdateNameList( FCreatedVariables, AName, False );
  FCreatedEnvironmentVariables := UpdateNameList( FCreatedEnvironmentVariables, AName, False );
  FCreatedVariableLocations := UpdateValueList( FCreatedVariableLocations, AName, '' );
  Save;
end;

function TPathCompactorPlugin.CreatedLocations( const AName: string ): TVariableLocations;
begin
  Result := [];
  var List := TStringList.Create;
  try
    List.Delimiter := ';';
    List.StrictDelimiter := True;
    List.CaseSensitive := False;

    List.DelimitedText := FCreatedVariableLocations;
    var Index := List.IndexOfName( AName );
    if ( Index >= 0 ) then
      Exit( MaskToLocations( StrToIntDef( List.ValueFromIndex[Index], 0 ) ) );

    // Recorded by an older build, which did not keep the locations.
    List.DelimitedText := FCreatedVariables;
    if ( List.IndexOf( AName ) < 0 ) then
      Exit;
    Result := [vlIde32, vlIde64];
    List.DelimitedText := FCreatedEnvironmentVariables;
    if ( List.IndexOf( AName ) >= 0 ) then
      Include( Result, vlUserEnvironment );
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
    // Close the dialog BEFORE freeing the plugin. It is modeless and owned by
    // Application, so it outlives us; unloading the package with the window
    // still up would leave a live window running unloaded code.
    TFormPathCompactor.CloseInstance;
    PathCompactorPlugin.Free;
    PathCompactorPlugin := nil;
  end;
end;

end.
