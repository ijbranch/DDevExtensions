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
procedure InitPlugin(Unload: Boolean);

implementation

uses
  System.SysUtils, System.UITypes, System.IOUtils,
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
    procedure MenuItemClick(Sender: TObject);
  public
    /// <summary>Creates the plugin and inserts the Tools-menu item.</summary>
    constructor Create;
    /// <summary>Removes the menu item.</summary>
    destructor Destroy; override;
  end;

var
  ProjectGroupSorterPlugin: TProjectGroupSorterPlugin;

{ File / IDE helpers }

function ReadFileUtf8NoBom(const AFileName: string): string;
var
  Bytes: TBytes;
begin
  Bytes := TFile.ReadAllBytes(AFileName);
  // Strip a UTF-8 BOM if present, then decode as UTF-8.
  if (Length(Bytes) >= 3) and (Bytes[0] = $EF) and (Bytes[1] = $BB) and (Bytes[2] = $BF) then
    Result := TEncoding.UTF8.GetString(Bytes, 3, Length(Bytes) - 3)
  else
    Result := TEncoding.UTF8.GetString(Bytes);
end;

procedure WriteFileUtf8NoBom(const AFileName, AText: string);
begin
  // GetBytes does not emit a preamble, so this writes UTF-8 without a BOM.
  TFile.WriteAllBytes(AFileName, TEncoding.UTF8.GetBytes(AText));
end;

/// <summary>
/// Reads <paramref name="AGroupFile"/>, writes a single <c>.bak</c> backup
/// beside it, then rewrites it with the projects sorted. Returns False (and
/// leaves the file untouched) when the order is already alphabetical.
/// </summary>
function BackupAndSortGroupFile(const AGroupFile: string): Boolean;
var
  Original, Sorted: string;
begin
  Original := ReadFileUtf8NoBom(AGroupFile);
  Sorted := SortGroupProjectText(Original);
  Result := Sorted <> Original;
  if not Result then
    Exit;
  try
    TFile.Copy(AGroupFile, AGroupFile + '.bak', True);
  except
    // A failed backup is non-fatal — the IDE regenerates this file on every save.
  end;
  WriteFileUtf8NoBom(AGroupFile, Sorted);
end;

procedure SortActiveProjectGroup;
var
  Group, NewGroup: IOTAProjectGroup;
  ActionSvc: IOTAActionServices;
  GroupFile, ActiveProjFile: string;
  ProjCount, I: Integer;
begin
  Group := GetActiveProjectGroup;
  if Group = nil then
  begin
    MessageDlg('No project group is open.', mtInformation, [mbOK], 0);
    Exit;
  end;

  GroupFile := Group.FileName;
  if (GroupFile = '') or not FileExists(GroupFile) then
  begin
    MessageDlg('Please save the project group to disk before sorting its projects.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  ProjCount := Group.ProjectCount;
  if ProjCount < 2 then
  begin
    MessageDlg('The project group has fewer than two projects — nothing to sort.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  if MessageDlg(Format(
       'Sort the %d projects in "%s" alphabetically?'#13#10#13#10 +
       'The project group will be saved, then closed and reopened so the IDE ' +
       'reloads the new order. Any open files will be re-read.',
       [ProjCount, ExtractFileName(GroupFile)]),
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  // Remember the active project so its selection can be restored after reload.
  ActiveProjFile := '';
  if Group.ActiveProject <> nil then
    ActiveProjFile := Group.ActiveProject.FileName;

  // Flush the current membership to disk so the file we sort is authoritative,
  // then drop the in-memory group (the IDE only re-reads the order on open).
  Group.Save(False, True);
  if not Group.Close then
    Exit; // user cancelled a save prompt — leave everything as-is
  Group := nil;

  if not BackupAndSortGroupFile(GroupFile) then
  begin
    // Already sorted: reopen the group we just closed and stop.
    if Supports(BorlandIDEServices, IOTAActionServices, ActionSvc) then
      ActionSvc.OpenProject(GroupFile, True);
    MessageDlg('The projects are already in alphabetical order.', mtInformation, [mbOK], 0);
    Exit;
  end;

  // Reopen — this is a fresh read of the now-sorted file.
  if Supports(BorlandIDEServices, IOTAActionServices, ActionSvc) then
    ActionSvc.OpenProject(GroupFile, True);

  // Restore the previously active project.
  if ActiveProjFile <> '' then
  begin
    NewGroup := GetActiveProjectGroup;
    if NewGroup <> nil then
      for I := 0 to NewGroup.ProjectCount - 1 do
        if SameText(NewGroup.Projects[I].FileName, ActiveProjFile) then
        begin
          NewGroup.SetActiveProject(NewGroup.Projects[I]);
          Break;
        end;
  end;
end;

{ TProjectGroupSorterPlugin }

constructor TProjectGroupSorterPlugin.Create;
var
  ToolsMenu: TMenuItem;
  I, InsertIndex: Integer;
begin
  inherited Create;

  ToolsMenu := FindMenuItem('ToolsMenu');
  if ToolsMenu <> nil then
  begin
    FMenuItem := TMenuItem.Create(ToolsMenu);
    FMenuItem.Caption := '&Sort Projects in Group...';
    FMenuItem.OnClick := MenuItemClick;

    // Place it just after the "IDE Path Sorter" item (or Build Statistics).
    InsertIndex := -1;
    for I := 0 to ToolsMenu.Count - 1 do
      if (Pos('Path Sorter', ToolsMenu.Items[I].Caption) > 0) or
         (Pos('Build', ToolsMenu.Items[I].Caption) > 0) then
      begin
        InsertIndex := I + 1;
        Break;
      end;

    if InsertIndex > 0 then
      ToolsMenu.Insert(InsertIndex, FMenuItem)
    else
      ToolsMenu.Add(FMenuItem);
  end;
end;

destructor TProjectGroupSorterPlugin.Destroy;
begin
  FreeAndNil(FMenuItem);
  inherited Destroy;
end;

procedure TProjectGroupSorterPlugin.MenuItemClick(Sender: TObject);
begin
  SortActiveProjectGroup;
end;

procedure InitPlugin(Unload: Boolean);
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
