{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit LibraryPathBackups;

/// <summary>
/// The library-path backup history shared by the IDE Path Sorter and the IDE Path
/// Compactor. RTL and XML only, so it is unit-tested outside the IDE.
/// </summary>
/// <remarks>
/// Several writers share one history file: the Sorter, the Compactor, and the
/// 32-bit and 64-bit IDEs when both are running. Every change therefore reloads the
/// file, applies itself and saves, all under a named mutex, so no writer can save a
/// stale in-memory copy over another's backups. The file is replaced atomically
/// (temporary file, then <c>MoveFileEx</c>); a file that cannot be read is moved aside
/// to a <c>.corrupt-*</c> copy and reported, never silently overwritten.
/// </remarks>

interface

uses
  System.SysUtils, System.Generics.Collections,
  PathCompactorCore;

type
  /// <summary>Raised when the backup history cannot be read, locked or written.</summary>
  ELibraryPathBackupError = class( Exception );

  /// <summary>Snapshot of one path-type/platform value taken at a point in time.</summary>
  TPathBackup = record
    /// <summary>Stable identifier: a GUID, or a hash of the content for entries written before identifiers existed.</summary>
    Id: string;
    /// <summary>Path type the snapshot belongs to.</summary>
    PathType: TLibraryPathType;
    /// <summary>Platform name the snapshot belongs to (e.g. "Win32").</summary>
    Platform: string;
    /// <summary>Time the snapshot was taken; zero when an old entry's time is not in ISO 8601 (see TimestampText).</summary>
    Timestamp: TDateTime;
    /// <summary>
    /// The timestamp exactly as an older build wrote it (in that machine's locale) when it is not
    /// ISO 8601; empty otherwise. It is never guessed at (day and month could swap) and is written
    /// back unchanged, so no save ever loses it.
    /// </summary>
    TimestampText: string;
    /// <summary>Semicolon-separated path string captured at Timestamp.</summary>
    Paths: string;
    /// <summary>Free-text description supplied by the user (or auto-generated).</summary>
    Description: string;
    /// <summary>True for a backup that is never trimmed automatically (the one taken before a compaction).</summary>
    Pinned: Boolean;
    /// <summary>The time for display: local date and time, or an older entry's text as written.</summary>
    /// <returns>The text to show.</returns>
    function DisplayTime: string;
  end;

  /// <summary>Persists library-path snapshots in an XML history file shared by every writer.</summary>
  TLibraryPathBackupManager = class
  private
    /// <summary>Path of the XML file used to persist the history.</summary>
    FBackupFilename: string;
    /// <summary>History file of older builds, imported (read-only) while FBackupFilename does not yet exist.</summary>
    FLegacyFilename: string;
    /// <summary>Maximum unpinned snapshots retained per (PathType, Platform) combination.</summary>
    FMaxBackupsPerType: Integer;
    /// <summary>Message of the last failure, for the caller to show.</summary>
    FLastError: string;
    /// <summary>Notice about a history file that was unreadable and has been set aside; cleared by TakeNotice.</summary>
    FNotice: string;
    /// <summary>Opens (creating if need be) the named mutex that serialises access to the file.</summary>
    /// <returns>The mutex handle, owned by the caller.</returns>
    /// <exception cref="ELibraryPathBackupError">The mutex could not be created or acquired within ten seconds.</exception>
    function AcquireLock: THandle;
    /// <summary>Releases and closes a handle returned by AcquireLock.</summary>
    /// <param name="AMutex">The mutex handle.</param>
    procedure ReleaseLock( AMutex: THandle );
    /// <summary>
    /// Reads the history file; an unreadable file is set aside and noted, giving an empty list.
    /// While the history file does not exist yet, the older builds' file is imported instead
    /// (read only: it is never written, renamed or set aside).
    /// </summary>
    /// <param name="AList">Receives the backups in file order (oldest first).</param>
    /// <exception cref="ELibraryPathBackupError">Raised when the history lock cannot be taken, or the file can be neither read nor set aside.</exception>
    procedure LoadInto( AList: TList<TPathBackup> );
    /// <summary>Writes the list to a temporary file and moves it over the history file.</summary>
    /// <param name="AList">The backups to persist.</param>
    /// <exception cref="ELibraryPathBackupError">The file could not be written or moved into place.</exception>
    procedure SaveFrom( AList: TList<TPathBackup> );
    /// <summary>Removes the oldest unpinned backups of one set beyond MaxBackupsPerType.</summary>
    /// <param name="AList">The full history.</param>
    /// <param name="APathType">Path type of the set.</param>
    /// <param name="APlatform">Platform of the set.</param>
    procedure TrimSet( AList: TList<TPathBackup>; APathType: TLibraryPathType; const APlatform: string );
  public
    /// <summary>Creates the manager for ABackupFilename; nothing is read until it is needed.</summary>
    /// <param name="ABackupFilename">The XML history file this build reads and writes.</param>
    /// <param name="ALegacyFilename">
    /// The history file older builds use, or empty. Its entries are imported until
    /// ABackupFilename exists; it is never written, so an older build running beside this
    /// one cannot damage this history, nor this one that build's.
    /// </param>
    constructor Create( const ABackupFilename: string; const ALegacyFilename: string = '' );

    /// <summary>Adds a snapshot to the history and trims the set's oldest unpinned ones beyond the cap.</summary>
    /// <param name="PathType">Path type of the snapshot.</param>
    /// <param name="APlatform">Platform of the snapshot.</param>
    /// <param name="APaths">The value to keep.</param>
    /// <param name="ADescription">Free text shown in the Restore list.</param>
    /// <param name="APinned">True to exempt the snapshot from automatic trimming.</param>
    /// <returns>True when the snapshot was saved; False when APaths is empty or saving failed (see LastError).</returns>
    function CreateBackup( PathType: TLibraryPathType; const APlatform, APaths: string;
      const ADescription: string = ''; APinned: Boolean = False ): Boolean;
    /// <summary>Returns the snapshots for the supplied path type and platform, read fresh from the file.</summary>
    /// <param name="PathType">Path type to filter on.</param>
    /// <param name="APlatform">Platform to filter on.</param>
    /// <returns>The matching snapshots, oldest first.</returns>
    /// <exception cref="ELibraryPathBackupError">The history is locked by another IDE, or unreadable and could not be set aside.</exception>
    function GetBackups( PathType: TLibraryPathType; const APlatform: string ): TArray<TPathBackup>;
    /// <summary>Returns every snapshot in the history, read fresh from the file.</summary>
    /// <returns>All snapshots, oldest first.</returns>
    /// <exception cref="ELibraryPathBackupError">The history is locked by another IDE, or unreadable and could not be set aside.</exception>
    function GetAllBackups: TArray<TPathBackup>;
    /// <summary>Removes the snapshot with the given identifier from the history.</summary>
    /// <param name="AId">The snapshot's Id.</param>
    /// <returns>True when it was found and the history saved; False otherwise (see LastError).</returns>
    function DeleteBackup( const AId: string ): Boolean;
    /// <summary>Returns, and clears, a notice about a history file that could not be read and was set aside.</summary>
    /// <returns>The notice text, or empty.</returns>
    function TakeNotice: string;

    /// <summary>Maximum unpinned snapshots retained per (PathType, Platform) combination.</summary>
    property MaxBackupsPerType: Integer read FMaxBackupsPerType write FMaxBackupsPerType;
    /// <summary>Path of the XML file used to persist the history.</summary>
    property BackupFilename: string read FBackupFilename;
    /// <summary>Message of the last failed operation.</summary>
    property LastError: string read FLastError;
  end;

const
  /// <summary>Description prefix of the backups taken before a compaction; such entries are pinned.</summary>
  CompactionBackupPrefix = 'Before compaction';

implementation

uses
  Winapi.Windows, System.Classes, System.DateUtils, System.Hash, System.Variants,
  SimpleXmlIntf, SimpleXmlImport;

{ TPathBackup }

function TPathBackup.DisplayTime: string;
begin
  if ( TimestampText <> '' ) then
    Result := TimestampText
  else if ( Timestamp = 0 ) then
    Result := '(unknown)'
  else
    Result := DateTimeToStr( Timestamp );
end;

{ TLibraryPathBackupManager }

constructor TLibraryPathBackupManager.Create( const ABackupFilename, ALegacyFilename: string );
begin
  inherited Create;
  FBackupFilename := ABackupFilename;
  FLegacyFilename := ALegacyFilename;
  FMaxBackupsPerType := 10;
end;

function TLibraryPathBackupManager.AcquireLock: THandle;
begin
  // One mutex per history file, visible to every IDE in this session (32-bit and 64-bit).
  var Name := 'Local\DDevExtensions.LibraryPathBackups.' +
    THashMD5.GetHashString( AnsiLowerCase( ExpandFileName( FBackupFilename ) ) );
  Result := CreateMutex( nil, False, PChar( Name ) );
  if ( Result = 0 ) then
    raise ELibraryPathBackupError.CreateFmt( 'Cannot create the backup-history lock: %s',
      [SysErrorMessage( GetLastError )] );
  case WaitForSingleObject( Result, 10000 ) of
    WAIT_OBJECT_0, WAIT_ABANDONED:
      ;
  else
    CloseHandle( Result );
    raise ELibraryPathBackupError.Create( 'The backup history is locked by another IDE; try again.' );
  end;
end;

procedure TLibraryPathBackupManager.ReleaseLock( AMutex: THandle );
begin
  ReleaseMutex( AMutex );
  CloseHandle( AMutex );
end;

/// <summary>Reads every Backup element of one history file into AList.</summary>
/// <param name="AFileName">The file to read.</param>
/// <param name="AList">Receives the backups in file order.</param>
/// <exception cref="ELibraryPathBackupError">The file has no root element.</exception>
/// <exception cref="Exception">The file is not well-formed XML.</exception>
procedure ReadHistoryFile( const AFileName: string; AList: TList<TPathBackup> );
begin
  var Doc := LoadXmlDocument( AFileName );
  var Root := Doc.DocumentElement;
  if ( Root = nil ) then
    raise ELibraryPathBackupError.Create( 'The file has no root element.' );

  for var I := 0 to Root.ChildNodes.Count - 1 do
  begin
    var Node := Root.ChildNodes[I];
    if ( Node.NodeName <> 'Backup' ) then
      Continue;

    var Backup := Default( TPathBackup );
    var PathTypeStr := VarToStr( Node.Attributes['PathType'] );
    Backup.PathType := lptSearchPath;
    for var PathType := Low( TLibraryPathType ) to High( TLibraryPathType ) do
      if SameText( PathType.ToRegistryValueName, PathTypeStr ) then
      begin
        Backup.PathType := PathType;
        Break;
      end;
    Backup.Platform := VarToStr( Node.Attributes['Platform'] );
    var TimeText := VarToStr( Node.Attributes['Timestamp'] );
    // Only ISO 8601 is interpreted. Text an older build wrote in its locale is kept as it
    // is: parsing it in today's locale could swap day and month without any sign.
    if not TryISO8601ToDate( TimeText, Backup.Timestamp, False ) then
    begin
      Backup.Timestamp := 0;
      Backup.TimestampText := TimeText;
    end;
    Backup.Description := VarToStr( Node.Attributes['Description'] );
    Backup.Paths := VarToStr( Node.NodeValue );
    Backup.Pinned := SameText( VarToStr( Node.Attributes['Pinned'] ), 'true' ) or
      Backup.Description.StartsWith( CompactionBackupPrefix, True );
    Backup.Id := VarToStr( Node.Attributes['Id'] );
    if ( Backup.Id = '' ) then
      // An entry from before identifiers existed: derive a stable one, so it can be
      // found again after the file is re-read.
      Backup.Id := 'legacy-' + THashMD5.GetHashString( PathTypeStr + '|' + Backup.Platform + '|' + TimeText + '|' +
        Backup.Description + '|' + Backup.Paths );
    AList.Add( Backup );
  end;
end;

procedure TLibraryPathBackupManager.LoadInto( AList: TList<TPathBackup> );
begin
  AList.Clear;

  if not FileExists( FBackupFilename ) then
  begin
    // First use by this build: start from the older builds' history, read only.
    if ( FLegacyFilename <> '' ) and FileExists( FLegacyFilename ) then
    try
      ReadHistoryFile( FLegacyFilename, AList );
    except
      on E: Exception do
      begin
        AList.Clear;
        FNotice := Format( 'The older library-path backup history "%s" could not be read (%s), so it was not ' +
          'imported. The file has been left as it is.', [FLegacyFilename, E.Message] );
      end;
    end;
    Exit;
  end;

  try
    ReadHistoryFile( FBackupFilename, AList );
  except
    on E: Exception do
    begin
      // Never overwrite a history we cannot read: set it aside and say so.
      var Aside := FBackupFilename + '.corrupt-' + FormatDateTime( 'yyyymmdd-hhnnss', Now );
      if RenameFile( FBackupFilename, Aside ) then
        FNotice := Format( 'The library-path backup history could not be read (%s). It has been moved to "%s" ' +
          'and a new history started.', [E.Message, Aside] )
      else
        raise ELibraryPathBackupError.CreateFmt( 'The library-path backup history "%s" could not be read (%s) ' +
          'and could not be set aside.', [FBackupFilename, E.Message] );
      AList.Clear;
    end;
  end;
end;

procedure TLibraryPathBackupManager.SaveFrom( AList: TList<TPathBackup> );
begin
  ForceDirectories( ExtractFileDir( FBackupFilename ) );

  var Doc := NewXmlDocument;
  var Root := Doc.CreateElement( 'LibraryPathBackups', '' );
  Doc.DocumentElement := Root;
  for var Backup in AList do
  begin
    var Node := Root.AddChild( 'Backup' );
    Node.Attributes['Id'] := Backup.Id;
    Node.Attributes['PathType'] := Backup.PathType.ToRegistryValueName;
    Node.Attributes['Platform'] := Backup.Platform;
    if ( Backup.TimestampText <> '' ) then
      Node.Attributes['Timestamp'] := Backup.TimestampText // an older entry's time, kept exactly as written
    else if ( Backup.Timestamp <> 0 ) then
      Node.Attributes['Timestamp'] := DateToISO8601( Backup.Timestamp, False );
    Node.Attributes['Description'] := Backup.Description;
    if Backup.Pinned then
      Node.Attributes['Pinned'] := 'true';
    Node.NodeValue := Backup.Paths;
  end;
  Doc.Options := Doc.Options + [doNodeAutoIndent];

  var TempName := FBackupFilename + '.tmp';
  try
    Doc.SaveToFile( TempName );
  except
    on E: Exception do
      raise ELibraryPathBackupError.CreateFmt( 'The backup history could not be written: %s', [E.Message] );
  end;
  if not MoveFileEx( PChar( TempName ), PChar( FBackupFilename ), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH ) then
  begin
    var Error := GetLastError;
    System.SysUtils.DeleteFile( TempName );
    raise ELibraryPathBackupError.CreateFmt( 'The backup history could not be replaced: %s', [SysErrorMessage( Error )] );
  end;
end;

procedure TLibraryPathBackupManager.TrimSet( AList: TList<TPathBackup>; APathType: TLibraryPathType;
  const APlatform: string );
begin
  var Unpinned := 0;
  for var Backup in AList do
    if ( Backup.PathType = APathType ) and SameText( Backup.Platform, APlatform ) and not Backup.Pinned then
      Inc( Unpinned );

  // Oldest first: the list is in file order, which is creation order.
  var I := 0;
  while ( Unpinned > FMaxBackupsPerType ) and ( I < AList.Count ) do
    if ( AList[I].PathType = APathType ) and SameText( AList[I].Platform, APlatform ) and not AList[I].Pinned then
    begin
      AList.Delete( I );
      Dec( Unpinned );
    end
    else
      Inc( I );
end;

function TLibraryPathBackupManager.CreateBackup( PathType: TLibraryPathType; const APlatform, APaths: string;
  const ADescription: string; APinned: Boolean ): Boolean;
begin
  Result := False;
  FLastError := '';
  if ( APaths = '' ) then
  begin
    FLastError := 'There is nothing to back up.';
    Exit;
  end;

  try
    var Mutex := AcquireLock;
    try
      var List := TList<TPathBackup>.Create;
      try
        LoadInto( List );
        var Backup := Default( TPathBackup );
        Backup.Id := TGUID.NewGuid.ToString;
        Backup.PathType := PathType;
        Backup.Platform := APlatform;
        Backup.Timestamp := Now;
        Backup.Description := ADescription;
        Backup.Paths := APaths;
        Backup.Pinned := APinned or ADescription.StartsWith( CompactionBackupPrefix, True );
        List.Add( Backup );
        TrimSet( List, PathType, APlatform );
        SaveFrom( List );
        Result := True;
      finally
        List.Free;
      end;
    finally
      ReleaseLock( Mutex );
    end;
  except
    on E: Exception do
      FLastError := E.Message;
  end;
end;

function TLibraryPathBackupManager.GetAllBackups: TArray<TPathBackup>;
begin
  var List := TList<TPathBackup>.Create;
  try
    var Mutex := AcquireLock;
    try
      LoadInto( List );
    finally
      ReleaseLock( Mutex );
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TLibraryPathBackupManager.GetBackups( PathType: TLibraryPathType; const APlatform: string ): TArray<TPathBackup>;
begin
  var List := TList<TPathBackup>.Create;
  try
    for var Backup in GetAllBackups do
      if ( Backup.PathType = PathType ) and SameText( Backup.Platform, APlatform ) then
        List.Add( Backup );
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TLibraryPathBackupManager.DeleteBackup( const AId: string ): Boolean;
begin
  Result := False;
  FLastError := '';
  try
    var Mutex := AcquireLock;
    try
      var List := TList<TPathBackup>.Create;
      try
        LoadInto( List );
        for var I := 0 to List.Count - 1 do
          if ( List[I].Id = AId ) then
          begin
            List.Delete( I );
            SaveFrom( List );
            Exit( True );
          end;
        FLastError := 'The backup no longer exists.';
      finally
        List.Free;
      end;
    finally
      ReleaseLock( Mutex );
    end;
  except
    on E: Exception do
      FLastError := E.Message;
  end;
end;

function TLibraryPathBackupManager.TakeNotice: string;
begin
  Result := FNotice;
  FNotice := '';
end;

end.
