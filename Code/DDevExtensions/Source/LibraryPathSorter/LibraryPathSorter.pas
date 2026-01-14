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

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Menus, Registry, Generics.Collections, Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main, SimpleXmlIntf, SimpleXmlImport,
  IDEUtils, IDEHooks, ToolsAPIHelpers;

type
  TLibraryPathType = (
    lptSearchPath,
    lptBrowsingPath,
    lptDebugDCUPath,
    lptHPPOutputDirectory,
    lptNamespacePrefixes,
    lptPackageDCPOutput,
    lptPackageDPLOutput,
    lptTranslatedDebugLibraryPath,
    lptTranslatedLibraryPath,
    lptTranslatedResourcePath
  );

  TLibraryPathTypeHelper = record helper for TLibraryPathType
    function ToRegistryValueName: string;
    function ToDisplayName: string;
  end;

  TPathBackup = record
    PathType: TLibraryPathType;
    Platform: string;
    Timestamp: TDateTime;
    Paths: string;
    Description: string;
  end;

  TLibraryPathBackupManager = class
  private
    FBackupFilename: string;
    FBackups: TList<TPathBackup>;
    FMaxBackupsPerType: Integer;
    procedure LoadBackups;
    procedure SaveBackups;
  public
    constructor Create( const ABackupFilename: string );
    destructor Destroy; override;

    function CreateBackup( PathType: TLibraryPathType; const APlatform, APaths: string;
      const ADescription: string = '' ): Boolean;
    function GetBackups( PathType: TLibraryPathType; const APlatform: string ): TArray<TPathBackup>;
    function GetAllBackups: TArray<TPathBackup>;
    function RestoreBackup( const ABackup: TPathBackup ): Boolean;
    function DeleteBackup( const ABackup: TPathBackup ): Boolean;

    property MaxBackupsPerType: Integer read FMaxBackupsPerType write FMaxBackupsPerType;
    property BackupFilename: string read FBackupFilename;
  end;

  TLibraryPathHandler = class
  private
    FBaseRegistryKey: string;
    function GetLibraryKey( const APlatform: string ): string;
  public
    constructor Create;

    function GetAvailablePlatforms: TStringList;
    function ReadPaths( PathType: TLibraryPathType; const APlatform: string ): string;
    procedure WritePaths( PathType: TLibraryPathType; const APlatform, APaths: string );
    function SortPaths( const APaths: string; CaseInsensitive: Boolean = True ): string;

    property BaseRegistryKey: string read FBaseRegistryKey;
  end;

  TLibraryPathSorterPlugin = class( TPluginConfig )
  private
    FEnabled: Boolean;
    FMenuItem: TMenuItem;
    FBackupManager: TLibraryPathBackupManager;
    FPathHandler: TLibraryPathHandler;
    procedure MenuItemClick( Sender: TObject );
  protected
    procedure Init; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ShowSorter;
    property BackupManager: TLibraryPathBackupManager read FBackupManager;
    property PathHandler: TLibraryPathHandler read FPathHandler;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

procedure InitPlugin( Unload: Boolean );

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

  SaveBackups;
  Result := True;
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
    FMenuItem.Caption := 'Library Path &Sorter...';
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
