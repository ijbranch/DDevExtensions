{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit PluginConfigCore;

/// <summary>
/// IDE-free helpers behind <c>PluginConfig</c>: crash-safe replacement of the settings file, quarantine of a
/// settings file that cannot be read, and the test for "this XML attribute carries a value".
/// </summary>

interface

uses
  System.SysUtils, System.Variants;

type
  /// <summary>Outcome of <see cref="LoadSettingsWithRetry"/>.</summary>
  TSettingsLoadOutcome = (
    /// <summary>The file was opened and parsed.</summary>
    sloLoaded,
    /// <summary>
    /// The file opened but its content could not be parsed (or it was empty) on every attempt: it is damaged,
    /// and may be moved aside.
    /// </summary>
    sloUnreadable,
    /// <summary>
    /// The file could not be opened on any attempt (locked by another process, access denied): its content is
    /// unknown and may be perfectly good, so it must be left where it is.
    /// </summary>
    sloLocked);

/// <summary>
/// True when an XML attribute or node value read through <c>SimpleXmlIntf</c> carries a value.  The wrapper
/// returns <c>''</c> (not <c>Null</c>) for a missing attribute, so <c>Value &lt;&gt; Null</c> is no test.
/// </summary>
/// <param name="Value">The value read.</param>
/// <returns>False for Null, Unassigned and the empty string; True otherwise.</returns>
function XmlValuePresent(const Value: Variant): Boolean;

/// <summary>The name a settings file is moved to when it cannot be read: <c>&lt;file&gt;.corrupt-yyyymmdd-hhnnss</c>.</summary>
/// <param name="FileName">The settings file.</param>
/// <param name="Stamp">The time to put in the name.</param>
/// <returns>The quarantine name (not checked for existence).</returns>
function QuarantineFileName(const FileName: string; Stamp: TDateTime): string;

/// <summary>
/// Moves an unreadable settings file aside, so the next save cannot overwrite it.  A name already taken gets
/// a <c>-1</c>, <c>-2</c>, ... suffix.
/// </summary>
/// <param name="FileName">The settings file.</param>
/// <param name="Stamp">The time to put in the name.</param>
/// <param name="NewName">Where the file now is (empty on failure).</param>
/// <returns>True when the file was moved; False when it could not be (it is then left where it was).</returns>
function QuarantineFile(const FileName: string; Stamp: TDateTime; out NewName: string): Boolean;

/// <summary>
/// A unique temporary file, beside the settings file, for a save to write before it replaces the real file.
/// Unique per call, because the 32-bit and 64-bit IDE share one settings file and may save at the same time.
/// </summary>
/// <param name="FileName">The settings file.</param>
/// <returns><paramref name="FileName"/> followed by <c>.&lt;GUID&gt;.tmp</c>.</returns>
function TempFileNameFor(const FileName: string): string;

/// <summary>
/// Opens and parses a settings file, retrying briefly (the other-bitness IDE may be saving it at that moment), and
/// tells a file that could not be opened apart from one that opened but would not parse.
/// </summary>
/// <param name="FileName">The settings file (it must exist).</param>
/// <param name="Parse">Parses the file; raises when the content is not valid.  Called only once the file has
/// been opened for reading and found not empty.</param>
/// <param name="Attempts">How many times to try (at least 1).</param>
/// <param name="DelayMs">Pause between attempts, in milliseconds.</param>
/// <param name="LastError">Why the last attempt failed (empty on success).</param>
/// <returns>The outcome of the last attempt.</returns>
function LoadSettingsWithRetry(const FileName: string; const Parse: TProc<string>; Attempts: Integer;
  DelayMs: Cardinal; out LastError: string): TSettingsLoadOutcome;

/// <summary>
/// Replaces <paramref name="FileName"/> with the fully written <paramref name="TempName"/> in one step
/// (<c>MoveFileEx</c> with <c>MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH</c>), so a crash leaves
/// either the old file or the new one, never a truncated one.
/// </summary>
/// <param name="TempName">The newly written content.</param>
/// <param name="FileName">The file to replace (it need not exist yet).</param>
/// <exception cref="EInOutError">The replacement failed; <paramref name="FileName"/> is unchanged and
/// <paramref name="TempName"/> has been deleted.</exception>
procedure ReplaceFileAtomically(const TempName, FileName: string);

implementation

uses
  Winapi.Windows, System.Classes;

function XmlValuePresent(const Value: Variant): Boolean;
begin
  Result := not ( VarIsNull( Value ) or VarIsEmpty( Value ) ) and ( VarToStr( Value ) <> '' );
end;

function QuarantineFileName(const FileName: string; Stamp: TDateTime): string;
begin
  Result := FileName + '.corrupt-' + FormatDateTime( 'yyyymmdd"-"hhnnss', Stamp );
end;

function QuarantineFile(const FileName: string; Stamp: TDateTime; out NewName: string): Boolean;
begin
  NewName := '';
  var Base := QuarantineFileName( FileName, Stamp );
  var Candidate := Base;
  var Suffix := 0;
  while FileExists( Candidate ) or DirectoryExists( Candidate ) do
  begin
    Inc( Suffix );
    Candidate := Base + '-' + IntToStr( Suffix );
  end;
  Result := MoveFileEx( PChar( FileName ), PChar( Candidate ), MOVEFILE_WRITE_THROUGH );
  if Result then
    NewName := Candidate;
end;

function TempFileNameFor(const FileName: string): string;
begin
  Result := FileName + '.' + TGUID.NewGuid.ToString.Trim( [ '{', '}' ] ) + '.tmp';
end;

function LoadSettingsWithRetry(const FileName: string; const Parse: TProc<string>; Attempts: Integer;
  DelayMs: Cardinal; out LastError: string): TSettingsLoadOutcome;
begin
  Result := sloLocked;
  LastError := '';
  if Attempts < 1 then
    Attempts := 1;
  for var Attempt := 1 to Attempts do
  begin
    if Attempt > 1 then
      Sleep( DelayMs );
    var Size: Int64;
    try
      var Probe := TFileStream.Create( FileName, fmOpenRead or fmShareDenyNone );
      try
        Size := Probe.Size;
      finally
        Probe.Free;
      end;
    except
      on E: Exception do
      begin
        // Could not open it at all: locked or denied, content unknown
        Result := sloLocked;
        LastError := E.ClassName + ': ' + E.Message;
        Continue;
      end;
    end;
    if Size = 0 then
    begin
      Result := sloUnreadable;
      LastError := 'The file is empty';
      Continue;
    end;
    try
      Parse( FileName );
      LastError := '';
      Exit( sloLoaded );
    except
      on E: Exception do
      begin
        Result := sloUnreadable;
        LastError := E.ClassName + ': ' + E.Message;
      end;
    end;
  end;
end;

procedure ReplaceFileAtomically(const TempName, FileName: string);
begin
  if not MoveFileEx( PChar( TempName ), PChar( FileName ), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH ) then
  begin
    var LastError := Winapi.Windows.GetLastError;
    System.SysUtils.DeleteFile( TempName );
    raise EInOutError.CreateFmt( 'Cannot replace "%s": %s', [ FileName, SysErrorMessage( LastError ) ] );
  end;
end;

end.
