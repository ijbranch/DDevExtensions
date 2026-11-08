{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit ProjectGroupSorter;

/// <summary>
/// Implements the "Sort Projects in Group" plugin: alphabetises the member
/// projects of the active project group so they list in name order in the
/// Project Manager.
/// </summary>
/// <remarks>
/// The IDE has no ToolsAPI for reordering a project group's members
/// (<c>IOTAProjectGroup</c> only exposes <c>RemoveProject</c> plus the
/// interactive add dialogs), and it reads the member order from the
/// <c>.groupproj</c> only when the group is first opened. Sorting therefore
/// works by rewriting the <c>.groupproj</c> on disk and forcing the IDE to
/// close and reopen the group so the new order is read. The pure rewrite logic
/// lives in <see cref="ProjectGroupSorterCore.SortGroupProjectText"/> (RTL-only
/// and unit-tested); this unit owns the menu item and the IDE orchestration.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

/// <summary>
/// Plugin entry point that creates or frees the ProjectGroupSorter plugin
/// (its Tools-menu item).
/// </summary>
/// <param name="Unload">False to create the plugin object at start-up; True to free it at shutdown.</param>
procedure InitPlugin( Unload: Boolean );

implementation

uses
  Winapi.Windows, System.SysUtils, System.UITypes, System.IOUtils,
  Vcl.Menus, Vcl.Dialogs,
  ToolsAPI, ToolsAPIHelpers,
  ProjectGroupSorterCore;

type
  /// <summary>Owns the Tools-menu item that triggers the sort.</summary>
  TProjectGroupSorterPlugin = class
  private
    /// <summary>Tools-menu item that performs the sort on click.</summary>
    FMenuItem: TMenuItem;
    /// <summary>OnClick handler for the menu item.</summary>
    procedure MenuItemClick( Sender: TObject );
  public
    /// <summary>Creates the plugin and inserts the Tools-menu item.</summary>
    constructor Create;
    /// <summary>Removes the menu item.</summary>
    destructor Destroy; override;
  end;

  /// <summary>The decoded text of a <c>.groupproj</c> and how it was encoded on disk.</summary>
  TGroupFileText = record
    /// <summary>The file content as text.</summary>
    Text: string;
    /// <summary>True when the file began with a UTF-8 byte-order mark.</summary>
    HasBom: Boolean;
    /// <summary>The raw bytes as read, used to detect a change made behind our back.</summary>
    Bytes: TBytes;
  end;

var
  ProjectGroupSorterPlugin: TProjectGroupSorterPlugin;

{ File / IDE helpers }

/// <summary>Reads a <c>.groupproj</c> as strict UTF-8, remembering whether it carried a BOM.</summary>
/// <param name="AFileName">The file to read.</param>
/// <returns>The decoded text, the BOM flag and the raw bytes.</returns>
/// <exception cref="EEncodingError">The file is not valid UTF-8; decoding it would corrupt its paths.</exception>
function ReadGroupFile( const AFileName: string ): TGroupFileText;
begin
  Result.Bytes      := TFile.ReadAllBytes( AFileName );
  Result.HasBom     := ( Length( Result.Bytes ) >= 3 ) and ( Result.Bytes[ 0 ] = $EF ) and ( Result.Bytes[ 1 ] = $BB ) and
    ( Result.Bytes[ 2 ] = $BF );
  // Strict decoding: an invalid byte must stop the sort, not turn into U+FFFD in a path.
  var Strict        := TUTF8Encoding.Create( CP_UTF8, MB_ERR_INVALID_CHARS, 0 );
  try
    if Result.HasBom then
      Result.Text   := Strict.GetString( Result.Bytes, 3, Length( Result.Bytes ) - 3 )
    else
      Result.Text   := Strict.GetString( Result.Bytes );
  finally
    Strict.Free;
  end;
end;

/// <summary>
/// Replaces <paramref name="AFileName"/> atomically: the text is written to a temporary
/// file beside it, which is then moved over the original in one step.
/// </summary>
/// <param name="AFileName">The file to replace.</param>
/// <param name="AText">The new content.</param>
/// <param name="AWithBom">Write a UTF-8 byte-order mark, as the original had one.</param>
/// <exception cref="EOSError">The temporary file could not be written or moved into place; the original is untouched.</exception>
procedure ReplaceGroupFile( const AFileName, AText: string; AWithBom: Boolean );
begin
  var Bytes         := TEncoding.UTF8.GetBytes( AText );
  if AWithBom then
    Bytes           := TEncoding.UTF8.GetPreamble + Bytes;
  var TempName      := AFileName + '.sorting.tmp';
  TFile.WriteAllBytes( TempName, Bytes );
  if not MoveFileEx( PChar( TempName ), PChar( AFileName ), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH ) then
  begin
    var Error       := GetLastError;
    System.SysUtils.DeleteFile( TempName );
    RaiseLastOSError( Error );
  end;
end;

/// <summary>Reopens a project group in the IDE and makes the previously active project active again.</summary>
/// <param name="AGroupFile">The group to open.</param>
/// <param name="AActiveProjFile">The project that was active before, or empty.</param>
procedure ReopenGroup( const AGroupFile, AActiveProjFile: string );
var
  ActionSvc         : IOTAActionServices;
begin
  if not Supports( BorlandIDEServices, IOTAActionServices, ActionSvc ) then
    Exit;
  ActionSvc.OpenProject( AGroupFile, True );

  if ( AActiveProjFile = '' ) then
    Exit;
  var NewGroup      := GetActiveProjectGroup;
  if ( NewGroup <> nil ) then
    for var I := 0 to NewGroup.ProjectCount - 1 do
      if SameText( NewGroup.Projects[ I ].FileName, AActiveProjFile ) then
      begin
        NewGroup.SetActiveProject( NewGroup.Projects[ I ] );
        Break;
      end;
end;

/// <summary>
/// Sorts the members of the active project group. Every step that can fail runs before the
/// group is closed; the file is replaced atomically, and the group is always reopened.
/// </summary>
procedure SortActiveProjectGroup;
var
  Group             : IOTAProjectGroup;
  GroupFile, ActiveProjFile, Sorted: string;
  Original, Current : TGroupFileText;
  ProjCount         : Integer;
begin
  Group             := GetActiveProjectGroup;
  if ( Group = nil ) then
  begin
    MessageDlg( 'No project group is open.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  GroupFile         := Group.FileName;
  if ( GroupFile = '' ) or not FileExists( GroupFile ) then
  begin
    MessageDlg( 'Please save the project group to disk before sorting its projects.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  ProjCount         := Group.ProjectCount;
  if ( ProjCount < 2 ) then
  begin
    MessageDlg( 'The project group has fewer than two projects, so there is nothing to sort.', mtInformation,
      [ mbOK ], 0 );
    Exit;
  end;

  if ( MessageDlg( Format(
        'Sort the %d projects in "%s" alphabetically?'#13#10#13#10 +
        'The project group will be saved, then closed and reopened so the IDE ' +
        'reloads the new order. Any open files will be re-read.'#13#10#13#10 +
        'Build All will then build in the new order. Declared project ' +
        'dependencies still apply, but a group that relies on its current order ' +
        'without declaring them may build in the wrong order.',
        [ ProjCount, ExtractFileName( GroupFile ) ] ),
      mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes ) then
    Exit;

  // Flush the current membership to disk so the file we sort is authoritative.
  Group.Save( False, True );

  // Everything that can fail happens while the group is still open.
  try
    Original        := ReadGroupFile( GroupFile );
    Sorted          := SortGroupProjectText( Original.Text );
  except
    on E: Exception do
    begin
      MessageDlg( 'The project group could not be sorted, and nothing was changed:'#13#10#13#10 + E.Message,
        mtError, [ mbOK ], 0 );
      Exit;
    end;
  end;

  if ( Sorted = Original.Text ) then
  begin
    MessageDlg( 'The projects are already in alphabetical order.', mtInformation, [ mbOK ], 0 );
    Exit;
  end;

  // The backup is the only way back, so its failure stops the sort. Each sort keeps its
  // own, time-stamped copy: an earlier backup is never overwritten.
  var BackupFile    := GroupFile + '.' + FormatDateTime( 'yyyymmdd-hhnnss', Now ) + '.bak';
  if not CopyFile( PChar( GroupFile ), PChar( BackupFile ), True ) then
  begin
    MessageDlg( Format( 'The backup "%s" could not be written (%s), so the project group was not sorted.',
        [ BackupFile, SysErrorMessage( GetLastError ) ] ), mtError, [ mbOK ], 0 );
    Exit;
  end;

  // Remember the active project so its selection can be restored after reload.
  ActiveProjFile    := '';
  if ( Group.ActiveProject <> nil ) then
    ActiveProjFile  := Group.ActiveProject.FileName;

  // Drop the in-memory group: the IDE only re-reads the member order on open.
  if not Group.Close then
    Exit; // the user cancelled a save prompt; leave everything as it was
  Group             := nil;

  try
    try
      // Closing must not have changed the file; if it did, what we sorted is stale.
      Current       := ReadGroupFile( GroupFile );
      if ( Length( Current.Bytes ) <> Length( Original.Bytes ) ) or
        not CompareMem( Pointer( Current.Bytes ), Pointer( Original.Bytes ), Length( Original.Bytes ) ) then
        raise EGroupProjSortError.Create( 'The project group file changed while it was being closed.' );

      ReplaceGroupFile( GroupFile, Sorted, Original.HasBom );
    except
      on E: Exception do
        MessageDlg( Format( 'The project group could not be rewritten, and has been reopened unchanged:'#13#10#13#10 +
            '%s'#13#10#13#10'A backup is at "%s".', [ E.Message, BackupFile ] ), mtError, [ mbOK ], 0 );
    end;
  finally
    // Always reopen, sorted or not: leaving the user with no group open is never right.
    ReopenGroup( GroupFile, ActiveProjFile );
  end;
end;

{ TProjectGroupSorterPlugin }

constructor TProjectGroupSorterPlugin.Create;
var
  ToolsMenu         : TMenuItem;
  I, InsertIndex    : Integer;
begin
  inherited Create;

  ToolsMenu         := FindMenuItem( 'ToolsMenu' );
  if ToolsMenu <> nil then
  begin
    FMenuItem       := TMenuItem.Create( ToolsMenu );
    FMenuItem.Caption := '&Sort Projects in Group...';
    FMenuItem.OnClick := MenuItemClick;

    // Place it just after the "IDE Path &Sorter..." item, else after the first "Build" item.  The caption is
    // compared without its "&" accelerator: the literal 'Path Sorter' never matched "IDE Path &Sorter...",
    // so the item always landed after the first "Build" item instead.
    InsertIndex     := -1;
    for I := 0 to ToolsMenu.Count - 1 do
      if ( Pos( 'Path Sorter', StripHotkey( ToolsMenu.Items[ I ].Caption ) ) > 0 ) then
      begin
        InsertIndex := I + 1;
        Break;
      end;
    if ( InsertIndex < 0 ) then
      for I := 0 to ToolsMenu.Count - 1 do
        if ( Pos( 'Build', ToolsMenu.Items[ I ].Caption ) > 0 ) then
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

destructor TProjectGroupSorterPlugin.Destroy;
begin
  FreeAndNil( FMenuItem );
  inherited Destroy;
end;

procedure TProjectGroupSorterPlugin.MenuItemClick( Sender: TObject );
begin
  SortActiveProjectGroup;
end;

procedure InitPlugin( Unload: Boolean );
begin
  if not Unload then
    ProjectGroupSorterPlugin := TProjectGroupSorterPlugin.Create
  else
  begin
    ProjectGroupSorterPlugin.Free;
    ProjectGroupSorterPlugin := nil;
  end;
end;

end.

