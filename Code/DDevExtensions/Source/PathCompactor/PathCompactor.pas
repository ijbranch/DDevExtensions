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
