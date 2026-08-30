{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit PathCompactorJunctions;

/// <summary>
/// Directory-junction detection and creation for the IDE Path Compactor.
/// </summary>
/// <remarks>
/// A junction is the only measure that shortens the <b>expanded</b> path — the
/// one that constrains the <c>dcc32</c>/<c>dcc64</c> command line. Macro
/// substitution shortens only the stored string.
///
/// It is also the only permanent, machine-global side effect the compactor has,
/// which is why <see cref="IsJunctionCandidate"/> refuses the IDE's own
/// installation tree and the system directories outright. Junctioning
/// <c>...\Embarcadero\Studio\37.0</c> would not be a path-shortening trick; it
/// would relocate RAD Studio behind the back of GetIt, the installer and every
/// repair operation.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes;

const
  /// <summary>Shortest expanded prefix worth a junction.</summary>
  MinJunctionPrefixLength = 40;

  /// <summary>Fewest uses before a junction is offered.</summary>
  /// <remarks>
  /// Deliberately higher than the macro rule's MinOccurrences: an unused
  /// variable is clutter, but an unused junction is a permanent change to the
  /// file system.
  /// </remarks>
  MinJunctionOccurrences = 3;

/// <summary>
/// True when APrefix is a legitimate junction target: long enough, under the
/// user profile or Program Files, and not part of the IDE's own installation
/// or a Windows system directory.
/// </summary>
/// <param name="APrefix">Expanded directory prefix, no trailing separator.</param>
/// <param name="AOccurrences">How many entries share the prefix.</param>
/// <param name="ABdsRootDir">The IDE installation root, i.e. the value of <c>$(BDS)</c>.</param>
function IsJunctionCandidate( const APrefix: string; AOccurrences: Integer;
  const ABdsRootDir: string ): Boolean;

/// <summary>True when ALinkPath is a reparse point resolving to ASourcePath.</summary>
function IsJunctionTo( const ALinkPath, ASourcePath: string ): Boolean;

/// <summary>
/// Creates a directory junction at ALinkPath pointing at ASourcePath, trying
/// unelevated first and escalating only if that fails.
/// </summary>
/// <returns>
/// True when the junction exists and points where it should. False sets AError;
/// a cancelled UAC prompt reports "cancelled" rather than an error.
/// </returns>
function CreateJunction( const ALinkPath, ASourcePath: string;
  out AError: string ): Boolean;

implementation

uses
  System.IOUtils, System.StrUtils, Winapi.ShellAPI;

function IsUnderDirectory( const APath, ARoot: string ): Boolean;
begin
  Result := False;
  if ( ARoot = '' ) or ( Length( APath ) < Length( ARoot ) ) then
    Exit;
  if not SameText( Copy( APath, 1, Length( ARoot ) ), ARoot ) then
    Exit;
  Result := ( Length( APath ) = Length( ARoot ) ) or
            ( APath[Length( ARoot ) + 1] = PathDelim );
end;

function IsJunctionCandidate( const APrefix: string; AOccurrences: Integer;
  const ABdsRootDir: string ): Boolean;
var
  ProgFiles, ProgFilesX86, UserProfile, WinDir: string;
begin
  Result := False;

  if ( Length( APrefix ) <= MinJunctionPrefixLength ) or
     ( AOccurrences < MinJunctionOccurrences ) then
    Exit;

  ProgFiles := GetEnvironmentVariable( 'ProgramW6432' );
  if ProgFiles = '' then
    ProgFiles := GetEnvironmentVariable( 'ProgramFiles' );
  ProgFilesX86 := GetEnvironmentVariable( 'ProgramFiles(x86)' );
  UserProfile := GetEnvironmentVariable( 'USERPROFILE' );
  WinDir := GetEnvironmentVariable( 'SystemRoot' );

  // Never the IDE's own tree. This is the exclusion that matters: on a real
  // machine the IDE installation is by far the most-used long prefix, so
  // without this the tool's top suggestion would be to junction RAD Studio.
  if ( ABdsRootDir <> '' ) and IsUnderDirectory( APrefix, ExcludeTrailingPathDelimiter( ABdsRootDir ) ) then
    Exit;

  // Never a Windows system directory.
  if ( WinDir <> '' ) and IsUnderDirectory( APrefix, ExcludeTrailingPathDelimiter( WinDir ) ) then
    Exit;

  // Never the Program Files roots themselves — only trees inside them.
  if SameText( APrefix, ExcludeTrailingPathDelimiter( ProgFiles ) ) or
     SameText( APrefix, ExcludeTrailingPathDelimiter( ProgFilesX86 ) ) or
     SameText( APrefix, ExcludeTrailingPathDelimiter( UserProfile ) ) then
    Exit;

  // Must actually live somewhere a junction would help.
  Result := IsUnderDirectory( APrefix, ExcludeTrailingPathDelimiter( ProgFiles ) ) or
            IsUnderDirectory( APrefix, ExcludeTrailingPathDelimiter( ProgFilesX86 ) ) or
            IsUnderDirectory( APrefix, ExcludeTrailingPathDelimiter( UserProfile ) );
end;

function IsJunctionTo( const ALinkPath, ASourcePath: string ): Boolean;
var
  Attrs: DWORD;
  Handle: THandle;
  Buffer: array[0..1023] of Char;
  Len: DWORD;
  Final: string;
begin
  Result := False;

  Attrs := GetFileAttributes( PChar( ALinkPath ) );
  if ( Attrs = INVALID_FILE_ATTRIBUTES ) or
     ( Attrs and FILE_ATTRIBUTE_REPARSE_POINT = 0 ) then
    Exit;

  // FILE_FLAG_BACKUP_SEMANTICS is required to open a directory handle.
  Handle := CreateFile( PChar( ALinkPath ), 0,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil,
    OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, 0 );
  if Handle = INVALID_HANDLE_VALUE then
    Exit;
  try
    Len := GetFinalPathNameByHandle( Handle, Buffer, Length( Buffer ), 0 );
    if ( Len = 0 ) or ( Len >= DWORD( Length( Buffer ) ) ) then
      Exit;

    Final := Copy( string( Buffer ), 1, Len );
    // GetFinalPathNameByHandle returns the \\?\ prefixed form.
    if StartsText( '\\?\', Final ) then
      Final := Copy( Final, 5, MaxInt );

    Result := SameText( ExcludeTrailingPathDelimiter( Final ),
                        ExcludeTrailingPathDelimiter( ASourcePath ) );
  finally
    CloseHandle( Handle );
  end;
end;

/// <summary>Runs <c>cmd.exe /c mklink /J</c>, optionally elevated, and waits for it.</summary>
function RunMkLink( const ALinkPath, ASourcePath: string; AElevated: Boolean;
  out AError: string ): Boolean;
var
  Params: string;
  StartInfo: TStartupInfo;
  ProcInfo: TProcessInformation;
  ExecInfo: TShellExecuteInfo;
  ExitCode: DWORD;
  CmdLine: string;
begin
  Result := False;
  AError := '';
  Params := Format( '/c mklink /J "%s" "%s"',
    [ExcludeTrailingPathDelimiter( ALinkPath ), ExcludeTrailingPathDelimiter( ASourcePath )] );

  if not AElevated then
  begin
    CmdLine := 'cmd.exe ' + Params;
    FillChar( StartInfo, SizeOf( StartInfo ), 0 );
    StartInfo.cb := SizeOf( StartInfo );
    StartInfo.dwFlags := STARTF_USESHOWWINDOW;
    StartInfo.wShowWindow := SW_HIDE;
    FillChar( ProcInfo, SizeOf( ProcInfo ), 0 );

    if not CreateProcess( nil, PChar( CmdLine ), nil, nil, False,
         CREATE_NO_WINDOW, nil, nil, StartInfo, ProcInfo ) then
    begin
      AError := SysErrorMessage( GetLastError );
      Exit;
    end;

    try
      WaitForSingleObject( ProcInfo.hProcess, INFINITE );
      ExitCode := 1;
      GetExitCodeProcess( ProcInfo.hProcess, ExitCode );
      Result := ExitCode = 0;
      if not Result then
        AError := 'mklink failed (exit code ' + IntToStr( ExitCode ) + ').';
    finally
      CloseHandle( ProcInfo.hThread );
      CloseHandle( ProcInfo.hProcess );
    end;
    Exit;
  end;

  FillChar( ExecInfo, SizeOf( ExecInfo ), 0 );
  ExecInfo.cbSize := SizeOf( ExecInfo );
  ExecInfo.fMask := SEE_MASK_NOCLOSEPROCESS or SEE_MASK_FLAG_NO_UI;
  ExecInfo.lpVerb := 'runas';
  ExecInfo.lpFile := 'cmd.exe';
  ExecInfo.lpParameters := PChar( Params );
  ExecInfo.nShow := SW_HIDE;

  if not ShellExecuteEx( @ExecInfo ) then
  begin
    // A cancelled UAC prompt is a user decision, not a failure to report as one.
    if GetLastError = ERROR_CANCELLED then
      AError := 'Elevation was cancelled.'
    else
      AError := SysErrorMessage( GetLastError );
    Exit;
  end;

  try
    WaitForSingleObject( ExecInfo.hProcess, INFINITE );
    ExitCode := 1;
    GetExitCodeProcess( ExecInfo.hProcess, ExitCode );
    Result := ExitCode = 0;
    if not Result then
      AError := 'mklink failed when run elevated (exit code ' + IntToStr( ExitCode ) + ').';
  finally
    CloseHandle( ExecInfo.hProcess );
  end;
end;

function CreateJunction( const ALinkPath, ASourcePath: string;
  out AError: string ): Boolean;
begin
  AError := '';

  if not TDirectory.Exists( ASourcePath ) then
  begin
    AError := 'Source directory does not exist: ' + ASourcePath;
    Exit( False );
  end;

  if TDirectory.Exists( ALinkPath ) then
  begin
    Result := IsJunctionTo( ALinkPath, ASourcePath );
    if not Result then
      AError := 'A directory already exists at ' + ALinkPath +
                ' and is not a junction to the expected target.';
    Exit;
  end;

  // A junction needs no administrator right in itself, but write access to the
  // parent does — and C:\ normally does not grant it. Try unelevated first so
  // the user is not prompted unnecessarily.
  Result := RunMkLink( ALinkPath, ASourcePath, False, AError );
  if not Result then
    Result := RunMkLink( ALinkPath, ASourcePath, True, AError );

  if Result then
    Result := IsJunctionTo( ALinkPath, ASourcePath );
end;

end.
