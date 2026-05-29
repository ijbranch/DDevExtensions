{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit LibraryPathSorter;

/// <summary>
/// Implements the IDE Path Sorter plugin: reads and writes the per-platform Library/Browsing/etc.
/// path values stored in the Delphi registry, sorts them, and keeps a versioned backup history so
/// any change can be rolled back.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Menus, Registry, Generics.Collections, Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main, SimpleXmlIntf, SimpleXmlImport,
  IDEUtils, IDEHooks, ToolsAPIHelpers;

type
  /// <summary>Identifies which Library-key value name a path operation targets.</summary>
  TLibraryPathType = (
    /// <summary>"Search Path" registry value (the Library Path).</summary>
    lptSearchPath,
    /// <summary>"Browsing Path" registry value.</summary>
    lptBrowsingPath,
    /// <summary>"Debug DCU Path" registry value.</summary>
    lptDebugDCUPath,
    /// <summary>"HPP Output Directory" registry value.</summary>
    lptHPPOutputDirectory,
    /// <summary>"Namespace Prefixes" registry value.</summary>
    lptNamespacePrefixes,
    /// <summary>"Package DCP Output" registry value.</summary>
    lptPackageDCPOutput,
    /// <summary>"Package DPL Output" registry value.</summary>
    lptPackageDPLOutput,
    /// <summary>"Translated Debug Library Path" registry value.</summary>
    lptTranslatedDebugLibraryPath,
    /// <summary>"Translated Library Path" registry value.</summary>
    lptTranslatedLibraryPath,
    /// <summary>"Translated Resource Path" registry value.</summary>
    lptTranslatedResourcePath
  );

  /// <summary>Helper that exposes the registry value name and display name of a path-type value.</summary>
  TLibraryPathTypeHelper = record helper for TLibraryPathType
    /// <summary>Returns the registry value name corresponding to the path type.</summary>
    function ToRegistryValueName: string;
    /// <summary>Returns a user-facing display name for the path type.</summary>
    function ToDisplayName: string;
  end;

  /// <summary>Snapshot of one path-type/platform value taken at a point in time.</summary>
  TPathBackup = record
    /// <summary>Path type the snapshot belongs to.</summary>
    PathType: TLibraryPathType;
    /// <summary>Platform name the snapshot belongs to (e.g. "Win32").</summary>
    Platform: string;
    /// <summary>Time the snapshot was taken.</summary>
    Timestamp: TDateTime;
    /// <summary>Semicolon-separated path string captured at Timestamp.</summary>
    Paths: string;
    /// <summary>Free-text description supplied by the user (or auto-generated).</summary>
    Description: string;
  end;

  /// <summary>Persists and restores TPathBackup snapshots in an XML history file.</summary>
  TLibraryPathBackupManager = class
  private
    /// <summary>Path of the XML file used to persist the history.</summary>
    FBackupFilename: string;
    /// <summary>In-memory list of loaded snapshots.</summary>
    FBackups: TList<TPathBackup>;
    /// <summary>Maximum snapshots retained per (PathType, Platform) combination.</summary>
    FMaxBackupsPerType: Integer;
    /// <summary>Loads the XML history file into FBackups (silent on errors).</summary>
    procedure LoadBackups;
    /// <summary>Writes FBackups back to the XML history file.</summary>
    procedure SaveBackups;
  public
    /// <summary>Creates the manager and loads the history from ABackupFilename.</summary>
    constructor Create( const ABackupFilename: string );
    /// <summary>Frees the in-memory list (does not delete the on-disk file).</summary>
    destructor Destroy; override;

    /// <summary>Adds a new snapshot to the history and trims older ones if the cap is exceeded.</summary>
    /// <returns>True if the snapshot was created (False when APaths is empty).</returns>
    function CreateBackup( PathType: TLibraryPathType; const APlatform, APaths: string;
      const ADescription: string = '' ): Boolean;
    /// <summary>Returns the snapshots for the supplied path type and platform.</summary>
    function GetBackups( PathType: TLibraryPathType; const APlatform: string ): TArray<TPathBackup>;
    /// <summary>Returns every snapshot in the history.</summary>
    function GetAllBackups: TArray<TPathBackup>;
    /// <summary>Writes the snapshot's Paths back to the registry.</summary>
    /// <returns>True on success.</returns>
    function RestoreBackup( const ABackup: TPathBackup ): Boolean;
    /// <summary>Removes the snapshot from the history (matched by PathType, Platform and Timestamp).</summary>
    function DeleteBackup( const ABackup: TPathBackup ): Boolean;

    /// <summary>Maximum snapshots retained per (PathType, Platform) combination.</summary>
    property MaxBackupsPerType: Integer read FMaxBackupsPerType write FMaxBackupsPerType;
    /// <summary>Path of the XML file used to persist the history.</summary>
    property BackupFilename: string read FBackupFilename;
  end;

  /// <summary>Reads, writes and sorts the path values stored under HKCU\<BaseRegistryKey>\Library.</summary>
  TLibraryPathHandler = class
  private
    /// <summary>BorlandIDEServices.GetBaseRegistryKey snapshot taken at construction.</summary>
    FBaseRegistryKey: string;
    /// <summary>Returns the registry sub-key for the Library values of the supplied platform.</summary>
    function GetLibraryKey( const APlatform: string ): string;
  public
    /// <summary>Creates the handler and snapshots BaseRegistryKey from BorlandIDEServices.</summary>
    constructor Create;

    /// <summary>Returns the platforms with installed Library sub-keys (Win32 is always present).</summary>
    function GetAvailablePlatforms: TStringList;
    /// <summary>Reads the named path value from the registry (returns empty if missing).</summary>
    function ReadPaths( PathType: TLibraryPathType; const APlatform: string ): string;
    /// <summary>Writes the supplied semicolon-separated paths to the named registry value.</summary>
    procedure WritePaths( PathType: TLibraryPathType; const APlatform, APaths: string );
    /// <summary>Returns APaths sorted (case-insensitively by default), preserving duplicates.</summary>
    function SortPaths( const APaths: string; CaseInsensitive: Boolean = True ): string;

    /// <summary>Base registry key under which the Library sub-key lives.</summary>
    property BaseRegistryKey: string read FBaseRegistryKey;
  end;

  /// <summary>Plugin entry point that owns the menu item, backup manager and path handler.</summary>
  TLibraryPathSorterPlugin = class( TPluginConfig )
  private
    /// <summary>Backing field for Enabled.</summary>
    FEnabled: Boolean;
    /// <summary>Tools-menu item that opens the sorter dialog.</summary>
    FMenuItem: TMenuItem;
    /// <summary>Owned backup history manager.</summary>
    FBackupManager: TLibraryPathBackupManager;
    /// <summary>Owned registry path handler.</summary>
    FPathHandler: TLibraryPathHandler;
    /// <summary>OnClick handler for the Tools-menu item.</summary>
    procedure MenuItemClick( Sender: TObject );
  protected
    /// <summary>Sets the default value for Enabled (True) on first creation.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the plugin and inserts the Tools-menu item near "Build Statistics".</summary>
    constructor Create;
    /// <summary>Destroys the menu item, backup manager and path handler.</summary>
    destructor Destroy; override;
    /// <summary>Opens the sorter dialog (TFormLibraryPathSorter).</summary>
    procedure ShowSorter;
    /// <summary>Owned backup history manager.</summary>
    property BackupManager: TLibraryPathBackupManager read FBackupManager;
    /// <summary>Owned registry path handler.</summary>
    property PathHandler: TLibraryPathHandler read FPathHandler;
  published
    /// <summary>Persisted enable flag for the plugin.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

/// <summary>Plugin entry point that creates or frees LibraryPathSorterPlugin.</summary>
procedure InitPlugin( Unload: Boolean );

/// <summary>Singleton instance of the plugin (nil when not loaded).</summary>
var
  LibraryPathSorterPlugin: TLibraryPathSorterPlugin;

implementation

uses
  Forms, Controls, FrmLibraryPathSorter;

const
  PathTypeRegistryNames: array[TLibraryPathType] of string = (
    'Search Path',
    'Browsing Path',
    'Debug DCU Path',
    'HPP Output Directory',
    'Namespace Prefixes',
    'Package DCP Output',
    'Package DPL Output',
    'Translated Debug Library Path',
    'Translated Library Path',
    'Translated Resource Path'
  );

  PathTypeDisplayNames: array[TLibraryPathType] of string = (
    'Library Path',
    'Browsing Path',
    'Debug DCU Path',
    'HPP Output Directory',
    'Namespace Prefixes',
    'Package DCP Output',
    'Package DPL Output',
    'Translated Debug Library Path',
    'Translated Library Path',
    'Translated Resource Path'
  );

{ TLibraryPathTypeHelper }

function TLibraryPathTypeHelper.ToRegistryValueName: string;
begin
  Result := PathTypeRegistryNames[Self];
end;

function TLibraryPathTypeHelper.ToDisplayName: string;
begin
  Result := PathTypeDisplayNames[Self];
end;

{ TLibraryPathBackupManager }

constructor TLibraryPathBackupManager.Create( const ABackupFilename: string );
begin
  inherited Create;
  FBackupFilename := ABackupFilename;
  FBackups := TList<TPathBackup>.Create;
  FMaxBackupsPerType := 10;
  LoadBackups;
end;

destructor TLibraryPathBackupManager.Destroy;
begin
  FBackups.Free;
  inherited Destroy;
end;

procedure TLibraryPathBackupManager.LoadBackups;
var
  Doc: IXmlDocument;
  Root, BackupNode: IXmlNode;
  I: Integer;
  Backup: TPathBackup;
  PathTypeStr: string;
  PathTypeIdx: TLibraryPathType;
begin
  FBackups.Clear;

  if not FileExists( FBackupFilename ) then
    Exit;

  try
    Doc := LoadXmlDocument( FBackupFilename );
    Root := Doc.DocumentElement;

    if Root = nil then
      Exit;

    for I := 0 to Root.ChildNodes.Count - 1 do
    begin
      BackupNode := Root.ChildNodes[I];
      if BackupNode.NodeName = 'Backup' then
      begin
        PathTypeStr := VarToStr( BackupNode.Attributes['PathType'] );

        // Find matching path type
        Backup.PathType := lptSearchPath; // Default
        for PathTypeIdx := Low( TLibraryPathType ) to High( TLibraryPathType ) do
        begin
          if SameText( PathTypeIdx.ToRegistryValueName, PathTypeStr ) then
          begin
            Backup.PathType := PathTypeIdx;
            Break;
          end;
        end;

        Backup.Platform := VarToStr( BackupNode.Attributes['Platform'] );
        try
          Backup.Timestamp := StrToDateTime( VarToStr( BackupNode.Attributes['Timestamp'] ) );
        except
          Backup.Timestamp := Now;
        end;
        Backup.Description := VarToStr( BackupNode.Attributes['Description'] );
        Backup.Paths := VarToStr( BackupNode.NodeValue );

        FBackups.Add( Backup );
      end;
    end;
  except
    // Ignore load errors - start fresh
  end;
end;

procedure TLibraryPathBackupManager.SaveBackups;
var
  Doc: IXmlDocument;
  Root, BackupNode: IXmlNode;
  Backup: TPathBackup;
begin
  ForceDirectories( ExtractFileDir( FBackupFilename ) );

  Doc := NewXmlDocument;
  Root := Doc.CreateElement( 'LibraryPathBackups', '' );
  Doc.DocumentElement := Root;

  for Backup in FBackups do
  begin
    BackupNode := Root.AddChild( 'Backup' );
    BackupNode.Attributes['PathType'] := Backup.PathType.ToRegistryValueName;
    BackupNode.Attributes['Platform'] := Backup.Platform;
    BackupNode.Attributes['Timestamp'] := DateTimeToStr( Backup.Timestamp );
    BackupNode.Attributes['Description'] := Backup.Description;
    BackupNode.NodeValue := Backup.Paths;
  end;

  Doc.Options := Doc.Options + [doNodeAutoIndent];
  Doc.SaveToFile( FBackupFilename );
end;

function TLibraryPathBackupManager.CreateBackup( PathType: TLibraryPathType;
  const APlatform, APaths, ADescription: string ): Boolean;
var
  Backup: TPathBackup;
  ExistingBackups: TArray<TPathBackup>;
  I, Count: Integer;
begin
  Result := False;

  if APaths = '' then
    Exit;

  Backup.PathType := PathType;
  Backup.Platform := APlatform;
  Backup.Timestamp := Now;
  Backup.Description := ADescription;
  Backup.Paths := APaths;

  FBackups.Add( Backup );

  // Limit backups per type/platform
  ExistingBackups := GetBackups( PathType, APlatform );
  Count := Length( ExistingBackups );

  if Count > FMaxBackupsPerType then
  begin
    // Remove oldest backups
    for I := 0 to Count - FMaxBackupsPerType - 1 do
      DeleteBackup( ExistingBackups[I] );
  end;

  try
    SaveBackups;
    Result := True;
  except
    // Persisting the backup failed (read-only %AppData%, disk full, locked
    // file). Convert to a False return so callers such as ApplyPaths can offer
    // "Failed to create backup. Continue anyway?" instead of letting the
    // exception escape, and reload from disk so the in-memory list matches what
    // was actually persisted.
    Result := False;
    LoadBackups;
  end;
end;

function TLibraryPathBackupManager.GetBackups( PathType: TLibraryPathType;
  const APlatform: string ): TArray<TPathBackup>;
var
  ResultList: TList<TPathBackup>;
  Backup: TPathBackup;
begin
  ResultList := TList<TPathBackup>.Create;
  try
    for Backup in FBackups do
    begin
      if ( Backup.PathType = PathType ) and SameText( Backup.Platform, APlatform ) then
        ResultList.Add( Backup );
    end;
    Result := ResultList.ToArray;
  finally
    ResultList.Free;
  end;
end;

function TLibraryPathBackupManager.GetAllBackups: TArray<TPathBackup>;
begin
  Result := FBackups.ToArray;
end;

function TLibraryPathBackupManager.RestoreBackup( const ABackup: TPathBackup ): Boolean;
begin
  Result := False;
  if LibraryPathSorterPlugin <> nil then
  begin
    LibraryPathSorterPlugin.PathHandler.WritePaths( ABackup.PathType, ABackup.Platform, ABackup.Paths );
    Result := True;
  end;
end;

function TLibraryPathBackupManager.DeleteBackup( const ABackup: TPathBackup ): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := FBackups.Count - 1 downto 0 do
  begin
    if ( FBackups[I].PathType = ABackup.PathType ) and
       ( FBackups[I].Platform = ABackup.Platform ) and
       ( FBackups[I].Timestamp = ABackup.Timestamp ) then
    begin
      FBackups.Delete( I );
      SaveBackups;
      Result := True;
      Break;
    end;
  end;
end;

{ TLibraryPathHandler }

constructor TLibraryPathHandler.Create;
begin
  inherited Create;
  if BorlandIDEServices <> nil then
    FBaseRegistryKey := ( BorlandIDEServices as IOTAServices ).GetBaseRegistryKey
  else
    FBaseRegistryKey := '';
end;

function TLibraryPathHandler.GetLibraryKey( const APlatform: string ): string;
begin
  Result := FBaseRegistryKey + '\Library';
  if APlatform <> '' then
    Result := Result + '\' + APlatform;
end;

function TLibraryPathHandler.GetAvailablePlatforms: TStringList;
var
  Reg: TRegistry;
begin
  Result := TStringList.Create;
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly( FBaseRegistryKey + '\Library' ) then
    begin
      Reg.GetKeyNames( Result );
      Reg.CloseKey;
    end;

    // Always ensure Win32 is available
    if Result.IndexOf( 'Win32' ) < 0 then
      Result.Insert( 0, 'Win32' );

    // Sort platforms
    Result.Sort;
  finally
    Reg.Free;
  end;
end;

function TLibraryPathHandler.ReadPaths( PathType: TLibraryPathType;
  const APlatform: string ): string;
begin
  Result := RegReadStringDef( HKEY_CURRENT_USER, GetLibraryKey( APlatform ),
    PathType.ToRegistryValueName, '' );
end;

procedure TLibraryPathHandler.WritePaths( PathType: TLibraryPathType;
  const APlatform, APaths: string );
begin
  RegWriteString( HKEY_CURRENT_USER, GetLibraryKey( APlatform ),
    PathType.ToRegistryValueName, APaths );
end;

procedure QuickSortPaths( var Arr: TArray<string>; Left, Right: Integer;
  CaseInsensitive: Boolean );
var
  I, J: Integer;
  Pivot, Temp: string;
begin
  if Left >= Right then
    Exit;

  // Choose middle element as pivot
  Pivot := Arr[( Left + Right ) div 2];
  I := Left;
  J := Right;

  while I <= J do
  begin
    if CaseInsensitive then
    begin
      while CompareText( Arr[I], Pivot ) < 0 do
        Inc( I );
      while CompareText( Arr[J], Pivot ) > 0 do
        Dec( J );
    end
    else
    begin
      while CompareStr( Arr[I], Pivot ) < 0 do
        Inc( I );
      while CompareStr( Arr[J], Pivot ) > 0 do
        Dec( J );
    end;

    if I <= J then
    begin
      // Swap
      Temp := Arr[I];
      Arr[I] := Arr[J];
      Arr[J] := Temp;
      Inc( I );
      Dec( J );
    end;
  end;

  // Recursively sort partitions
  if Left < J then
    QuickSortPaths( Arr, Left, J, CaseInsensitive );
  if I < Right then
    QuickSortPaths( Arr, I, Right, CaseInsensitive );
end;

function TLibraryPathHandler.SortPaths( const APaths: string;
  CaseInsensitive: Boolean ): string;
var
  PathList: TStringList;
  SortedArray: TArray<string>;
  I, EmptyCount, OriginalCount: Integer;
begin
  PathList := TStringList.Create;
  try
    // Split paths - do NOT delete duplicates (pass False)
    SplitPaths( PathList, APaths, False );
    OriginalCount := PathList.Count;

    // Count and remove empty entries
    EmptyCount := 0;
    for I := PathList.Count - 1 downto 0 do
    begin
      if Trim( PathList[I] ) = '' then
      begin
        PathList.Delete( I );
        Inc( EmptyCount );
      end;
    end;

    // Copy to array for safe sorting (avoids TStringList quirks)
    SetLength( SortedArray, PathList.Count );
    for I := 0 to PathList.Count - 1 do
      SortedArray[I] := PathList[I];

    // QuickSort - O(n log n) and safe with duplicates
    if Length( SortedArray ) > 1 then
      QuickSortPaths( SortedArray, 0, Length( SortedArray ) - 1, CaseInsensitive );

    // Rebuild the list from sorted array
    PathList.Clear;
    for I := 0 to Length( SortedArray ) - 1 do
      PathList.Add( SortedArray[I] );

    // Verify count is correct (original minus empties)
    if PathList.Count <> ( OriginalCount - EmptyCount ) then
    begin
      // Critical error - paths were lost during sort!
      raise Exception.CreateFmt(
        'Path count mismatch after sort: Expected %d, got %d',
        [OriginalCount - EmptyCount, PathList.Count] );
    end;

    // Concatenate paths - Delphi's native format does NOT use quotes
    Result := '';
    for I := 0 to PathList.Count - 1 do
    begin
      if I = 0 then
        Result := PathList[I]
      else
        Result := Result + ';' + PathList[I];
    end;
  finally
    PathList.Free;
  end;
end;

{ TLibraryPathSorterPlugin }

constructor TLibraryPathSorterPlugin.Create;
var
  ToolsMenu: TMenuItem;
  I, InsertIndex: Integer;
begin
  FPathHandler := TLibraryPathHandler.Create;
  FBackupManager := TLibraryPathBackupManager.Create(
    AppDataDirectory + '\LibraryPathBackups' + DelphiVersion + '.xml' );

  inherited Create( AppDataDirectory + '\LibraryPathSorter.xml', 'LibraryPathSorter' );

  // Add menu item to Tools menu, after Build Statistics
  ToolsMenu := FindMenuItem( 'ToolsMenu' );
  if ToolsMenu <> nil then
  begin
    FMenuItem := TMenuItem.Create( ToolsMenu );
    FMenuItem.Caption := 'IDE Path &Sorter...';
    FMenuItem.OnClick := MenuItemClick;

    // Find Build Statistics menu item and insert after it
    InsertIndex := -1;
    for I := 0 to ToolsMenu.Count - 1 do
    begin
      if Pos( 'Build', ToolsMenu.Items[I].Caption ) > 0 then
      begin
        InsertIndex := I + 1;
        Break;
      end;
    end;

    if InsertIndex > 0 then
      ToolsMenu.Insert( InsertIndex, FMenuItem )
    else
      ToolsMenu.Add( FMenuItem );
  end;
end;

destructor TLibraryPathSorterPlugin.Destroy;
begin
  FreeAndNil( FMenuItem );
  FreeAndNil( FBackupManager );
  FreeAndNil( FPathHandler );
  inherited Destroy;
end;

procedure TLibraryPathSorterPlugin.Init;
begin
  FEnabled := True;
end;

procedure TLibraryPathSorterPlugin.MenuItemClick( Sender: TObject );
begin
  ShowSorter;
end;

procedure TLibraryPathSorterPlugin.ShowSorter;
begin
  TFormLibraryPathSorter.Execute;
end;

procedure InitPlugin( Unload: Boolean );
begin
  if not Unload then
    LibraryPathSorterPlugin := TLibraryPathSorterPlugin.Create
  else
  begin
    LibraryPathSorterPlugin.Free;
    LibraryPathSorterPlugin := nil;
  end;
end;

end.
