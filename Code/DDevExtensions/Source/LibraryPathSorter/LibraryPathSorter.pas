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
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Menus, System.Win.Registry, System.Generics.Collections, System.Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main, SimpleXmlIntf, SimpleXmlImport,
  IDEUtils, IDEHooks, ToolsAPIHelpers,
  PathCompactorCore, LibraryPathBackups;

type
  /// <summary>
  /// Identifies which Library-key value name a path operation targets.
  /// Canonically declared in <c>PathCompactorCore</c> (which is RTL-only, so the
  /// compactor's testable core can use it without pulling in ToolsAPI); aliased
  /// here so existing callers keep compiling.
  /// </summary>
  TLibraryPathType = PathCompactorCore.TLibraryPathType;

  /// <summary>
  /// Registry-value-name and display-name helper for <see cref="TLibraryPathType"/>.
  /// Aliased from <c>PathCompactorCore</c> — a second helper declared for the same
  /// type would not merge with the first, it would silently shadow it.
  /// </summary>
  TLibraryPathTypeHelper = PathCompactorCore.TLibraryPathTypeHelper;

  /// <summary>Snapshot of one path-type/platform value; declared in <c>LibraryPathBackups</c>.</summary>
  TPathBackup = LibraryPathBackups.TPathBackup;

  /// <summary>The shared backup history; declared in the RTL-only, unit-tested <c>LibraryPathBackups</c>.</summary>
  TLibraryPathBackupManager = LibraryPathBackups.TLibraryPathBackupManager;

  /// <summary>Raised when a library-path value cannot be written, or reads back differently.</summary>
  ELibraryPathError = class( Exception );

  /// <summary>Reads, writes and sorts the path values stored under HKCU\<BaseRegistryKey>\Library.</summary>
  TLibraryPathHandler = class
  private
    /// <summary>BorlandIDEServices.GetBaseRegistryKey snapshot taken at construction.</summary>
    FBaseRegistryKey: string;
    /// <summary>Returns the registry sub-key for the Library values of the supplied platform.</summary>
    /// <param name="APlatform">The platform name; empty gives the Library key itself.</param>
    /// <returns>The registry key path relative to HKEY_CURRENT_USER.</returns>
    function GetLibraryKey( const APlatform: string ): string;
  public
    /// <summary>Creates the handler and snapshots BaseRegistryKey from BorlandIDEServices.</summary>
    constructor Create;

    /// <summary>Returns the platforms with installed Library sub-keys (Win32 is always present).</summary>
    /// <returns>A new sorted list of platform names that the caller must free.</returns>
    function GetAvailablePlatforms: TStringList;
    /// <summary>Reads the named path value from the registry (returns empty if missing).</summary>
    /// <param name="PathType">The path value to read.</param>
    /// <param name="APlatform">The platform sub-key.</param>
    /// <returns>The stored value, or an empty string when it is missing.</returns>
    function ReadPaths( PathType: TLibraryPathType; const APlatform: string ): string;
    /// <summary>Writes the supplied semicolon-separated paths to the named registry value and verifies them by read-back.</summary>
    /// <param name="PathType">The value to write.</param>
    /// <param name="APlatform">The platform sub-key.</param>
    /// <param name="APaths">The new value.</param>
    /// <exception cref="ELibraryPathError">The key could not be opened, or the value did not read back as written.</exception>
    procedure WritePaths( PathType: TLibraryPathType; const APlatform, APaths: string );
    /// <summary>Returns APaths sorted (case-insensitively by default), preserving duplicates.</summary>
    /// <param name="APaths">The semicolon-separated paths.</param>
    /// <param name="CaseInsensitive">True (the default) to sort ignoring case.</param>
    /// <returns>The sorted paths joined with semicolons; empty entries are dropped.</returns>
    /// <exception cref="Exception">The sorted list does not hold the same number of entries as the input (a path would be lost).</exception>
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
    /// <param name="Sender">The Tools-menu item.</param>
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
/// <param name="Unload">False to create the plugin object at start-up; True to free it at shutdown.</param>
procedure InitPlugin( Unload: Boolean );

/// <summary>Singleton instance of the plugin (nil when not loaded).</summary>
var
  LibraryPathSorterPlugin: TLibraryPathSorterPlugin;

implementation

uses
  Vcl.Forms, Vcl.Controls, FrmLibraryPathSorter;

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
  Result            := FBaseRegistryKey + '\Library';
  if APlatform <> '' then
    Result          := Result + '\' + APlatform;
end;

function TLibraryPathHandler.GetAvailablePlatforms: TStringList;
var
  Reg               : TRegistry;
begin
  Result            := TStringList.Create;
  Reg               := TRegistry.Create;
  try
    Reg.RootKey     := HKEY_CURRENT_USER;
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
  Result            := RegReadStringDef( HKEY_CURRENT_USER, GetLibraryKey( APlatform ),
    PathType.ToRegistryValueName, '' );
end;

procedure TLibraryPathHandler.WritePaths( PathType: TLibraryPathType;
  const APlatform, APaths: string );
begin
  var Reg           := TRegistry.Create( KEY_READ or KEY_WRITE );
  try
    Reg.RootKey     := HKEY_CURRENT_USER;
    if not Reg.OpenKey( GetLibraryKey( APlatform ), True ) then
      raise ELibraryPathError.CreateFmt( 'The registry key "%s" could not be opened for writing.',
        [ GetLibraryKey( APlatform ) ] );
    Reg.WriteString( PathType.ToRegistryValueName, APaths );
  finally
    Reg.Free;
  end;

  // A write is only done when it reads back as written.
  if ( ReadPaths( PathType, APlatform ) <> APaths ) then
    raise ELibraryPathError.CreateFmt( 'The %s value for %s did not read back as written.',
      [ PathType.ToDisplayName, APlatform ] );
end;

procedure QuickSortPaths( var Arr: TArray<string>; Left, Right: Integer;
  CaseInsensitive: Boolean );
var
  I, J              : Integer;
  Pivot, Temp       : string;
begin
  if Left >= Right then
    Exit;

  // Choose middle element as pivot
  Pivot             := Arr[ ( Left + Right ) div 2 ];
  I                 := Left;
  J                 := Right;

  while I <= J do
  begin
    if CaseInsensitive then
    begin
      while CompareText( Arr[ I ], Pivot ) < 0 do
        Inc( I );
      while CompareText( Arr[ J ], Pivot ) > 0 do
        Dec( J );
    end
    else
    begin
      while CompareStr( Arr[ I ], Pivot ) < 0 do
        Inc( I );
      while CompareStr( Arr[ J ], Pivot ) > 0 do
        Dec( J );
    end;

    if I <= J then
    begin
      // Swap
      Temp          := Arr[ I ];
      Arr[ I ]      := Arr[ J ];
      Arr[ J ]      := Temp;
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
  PathList          : TStringList;
  SortedArray       : TArray<string>;
  I, EmptyCount, OriginalCount: Integer;
begin
  PathList          := TStringList.Create;
  try
    // Split paths - do NOT delete duplicates (pass False)
    SplitPaths( PathList, APaths, False );
    OriginalCount   := PathList.Count;

    // Count and remove empty entries
    EmptyCount      := 0;
    for I := PathList.Count - 1 downto 0 do
    begin
      if Trim( PathList[ I ] ) = '' then
      begin
        PathList.Delete( I );
        Inc( EmptyCount );
      end;
    end;

    // Copy to array for safe sorting (avoids TStringList quirks)
    SetLength( SortedArray, PathList.Count );
    for I := 0 to PathList.Count - 1 do
      SortedArray[ I ] := PathList[ I ];

    // QuickSort - O(n log n) and safe with duplicates
    if Length( SortedArray ) > 1 then
      QuickSortPaths( SortedArray, 0, Length( SortedArray ) - 1, CaseInsensitive );

    // Rebuild the list from sorted array
    PathList.Clear;
    for I := 0 to Length( SortedArray ) - 1 do
      PathList.Add( SortedArray[ I ] );

    // Verify count is correct (original minus empties)
    if PathList.Count <> ( OriginalCount - EmptyCount ) then
    begin
      // Critical error - paths were lost during sort!
      raise Exception.CreateFmt(
        'Path count mismatch after sort: Expected %d, got %d',
        [ OriginalCount - EmptyCount, PathList.Count ] );
    end;

    // Concatenate paths - Delphi's native format does NOT use quotes
    Result          := '';
    for I := 0 to PathList.Count - 1 do
    begin
      if I = 0 then
        Result      := PathList[ I ]
      else
        Result      := Result + ';' + PathList[ I ];
    end;
  finally
    PathList.Free;
  end;
end;

{ TLibraryPathSorterPlugin }

constructor TLibraryPathSorterPlugin.Create;
var
  ToolsMenu         : TMenuItem;
  I, InsertIndex    : Integer;
begin
  FPathHandler      := TLibraryPathHandler.Create;
  FBackupManager    := TLibraryPathBackupManager.Create(
    AppDataDirectory + '\LibraryPathBackups' + DelphiVersion + '.v2.xml',
    AppDataDirectory + '\LibraryPathBackups' + DelphiVersion + '.xml' );

  inherited Create( AppDataDirectory + '\LibraryPathSorter.xml', 'LibraryPathSorter' );

  // Add menu item to Tools menu, after Build Statistics
  ToolsMenu         := FindMenuItem( 'ToolsMenu' );
  if ToolsMenu <> nil then
  begin
    FMenuItem       := TMenuItem.Create( ToolsMenu );
    FMenuItem.Caption := 'IDE Path &Sorter...';
    FMenuItem.OnClick := MenuItemClick;

    // Find Build Statistics menu item and insert after it
    InsertIndex     := -1;
    for I := 0 to ToolsMenu.Count - 1 do
    begin
      if Pos( 'Build', ToolsMenu.Items[ I ].Caption ) > 0 then
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
  FEnabled          := True;
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
    // Close the dialog BEFORE freeing the plugin. It is modeless and owned by
    // Application, so it outlives us; and it reaches back through
    // LibraryPathSorterPlugin.PathHandler, which is about to become nil.
    TFormLibraryPathSorter.CloseInstance;
    LibraryPathSorterPlugin.Free;
    LibraryPathSorterPlugin := nil;
  end;
end;

end.

