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
/// close and reopen the group so the new order is read.
///
/// A <c>.groupproj</c> lists every project three times: once in the
/// <c>&lt;ItemGroup&gt;</c> (the membership), once as a trio of per-project
/// <c>&lt;Target&gt;</c> elements, and once in each of the <c>Build</c>,
/// <c>Clean</c> and <c>Make</c> <c>CallTarget</c> lists. The Project Manager
/// tree order follows the <c>&lt;Target&gt;</c>/<c>CallTarget</c> sections, so
/// <see cref="SortGroupProjectText"/> sorts <b>all three</b> consistently — a
/// previous attempt that sorted only the <c>&lt;ItemGroup&gt;</c> had no
/// visible effect.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

/// <summary>
/// Returns <paramref name="AText"/> (the verbatim contents of a
/// <c>.groupproj</c>) with its member projects sorted alphabetically by
/// project name across the <c>ItemGroup</c>, the per-project <c>Target</c>
/// blocks and the <c>Build</c>/<c>Clean</c>/<c>Make</c> <c>CallTarget</c>
/// lists. The header, <c>ProjectExtensions</c>, <c>Import</c> and any
/// per-project dependency content are preserved verbatim. CRLF line endings
/// are used in the result.
/// </summary>
/// <remarks>Pure function — no IDE state is touched, so it is unit-testable.</remarks>
function SortGroupProjectText(const AText: string): string;

/// <summary>
/// Plugin entry point that creates or frees the ProjectGroupSorter plugin
/// (its Tools-menu item).
/// </summary>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  System.SysUtils, System.StrUtils, System.UITypes, System.Classes, System.IOUtils,
  System.Generics.Collections, System.Generics.Defaults,
  Vcl.Menus, Vcl.Dialogs,
  ToolsAPI, ToolsAPIHelpers;

type
  /// <summary>One member project parsed from the <c>ItemGroup</c>.</summary>
  TProjEntry = record
    /// <summary>Project name without path or extension (e.g. "DBiAdmin").</summary>
    Name: string;
    /// <summary>The verbatim <c>Include</c> value (e.g. "DBiAdmin\DBiAdmin.dproj").</summary>
    Include: string;
    /// <summary>The full text of the <c>&lt;Projects&gt;...&lt;/Projects&gt;</c> block (preserves dependencies).</summary>
    Lines: TArray<string>;
  end;

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

{ Text-sorting helpers }

function LeafName(const AInclude: string): string;
begin
  // Strip directory and the .dproj extension: "DBiAdmin\DBiAdmin.dproj" -> "DBiAdmin"
  Result := TPath.GetFileNameWithoutExtension(StringReplace(AInclude, '\', PathDelim, [rfReplaceAll]));
end;

function LeadingSpaces(const S: string): Integer;
begin
  Result := 0;
  while (Result < Length(S)) and (S[Result + 1] = ' ') do
    Inc(Result);
end;

function SortGroupProjectText(const AText: string): string;
var
  InLines, OutLines: TStringList;
  Entries: TList<TProjEntry>;
  Entry: TProjEntry;
  BlockLines: TList<string>;
  I, P1, P2: Integer;
  Line, Trimmed, IncPath: string;
  BlockDone: Boolean;
  TargetIndent: Integer;
  BaseInd, ChildInd: string;
  Names, BuildList, CleanList, MakeList: string;
begin
  InLines := TStringList.Create;
  OutLines := TStringList.Create;
  Entries := TList<TProjEntry>.Create;
  try
    InLines.Text := AText;
    OutLines.LineBreak := #13#10;

    I := 0;

    // 1. Copy the header up to (not including) the first <Projects ...> element.
    while (I < InLines.Count) and
          not StartsText('<Projects Include="', TrimLeft(InLines[I])) do
    begin
      OutLines.Add(InLines[I]);
      Inc(I);
    end;

    // 2. Collect the consecutive <Projects>...</Projects> blocks.
    while (I < InLines.Count) and
          StartsText('<Projects Include="', TrimLeft(InLines[I])) do
    begin
      Line := InLines[I];
      Trimmed := TrimLeft(Line);
      P1 := Pos('Include="', Trimmed) + Length('Include="');
      P2 := PosEx('"', Trimmed, P1);
      IncPath := Copy(Trimmed, P1, P2 - P1);

      BlockLines := TList<string>.Create;
      try
        if EndsText('/>', TrimRight(Line)) then
        begin
          // Self-closing <Projects Include="x"/> — single line, no dependencies.
          BlockLines.Add(Line);
          Inc(I);
        end
        else
        begin
          // Multi-line block: copy through the matching </Projects>.
          while I < InLines.Count do
          begin
            BlockLines.Add(InLines[I]);
            BlockDone := SameText(TrimLeft(InLines[I]), '</Projects>');
            Inc(I);
            if BlockDone then
              Break;
          end;
        end;

        Entry.Name := LeafName(IncPath);
        Entry.Include := IncPath;
        Entry.Lines := BlockLines.ToArray;
        Entries.Add(Entry);
      finally
        BlockLines.Free;
      end;
    end;

    // 3. Sort the member projects by name (case-insensitive, ordinal).
    Entries.Sort(TComparer<TProjEntry>.Construct(
      function(const L, R: TProjEntry): Integer
      begin
        Result := CompareStr(LowerCase(L.Name), LowerCase(R.Name));
      end));

    // 4. Emit the sorted <Projects> blocks.
    for Entry in Entries do
      OutLines.AddStrings(Entry.Lines);

    // 5. Copy the middle (</ItemGroup>, ProjectExtensions, ...) until either the
    //    first per-project <Target ...> or the trailing <Import .../> / EOF.
    TargetIndent := 4;
    while (I < InLines.Count) and
          not StartsText('<Target Name="', TrimLeft(InLines[I])) and
          not StartsText('<Import ', TrimLeft(InLines[I])) do
    begin
      OutLines.Add(InLines[I]);
      Inc(I);
    end;

    // 6/7/8. Regenerate the <Target> + Build/Clean/Make sections from the sorted
    //        list — but only when the group actually had a <Target> section.
    if (I < InLines.Count) and StartsText('<Target Name="', TrimLeft(InLines[I])) then
    begin
      TargetIndent := LeadingSpaces(InLines[I]);

      // Skip the entire original <Target> region (up to the <Import>/EOF).
      while (I < InLines.Count) and not StartsText('<Import ', TrimLeft(InLines[I])) do
        Inc(I);

      BaseInd := StringOfChar(' ', TargetIndent);
      ChildInd := StringOfChar(' ', TargetIndent + 4);

      // Per-project targets.
      for Entry in Entries do
      begin
        OutLines.Add(BaseInd + '<Target Name="' + Entry.Name + '">');
        OutLines.Add(ChildInd + '<MSBuild Projects="' + Entry.Include + '"/>');
        OutLines.Add(BaseInd + '</Target>');
        OutLines.Add(BaseInd + '<Target Name="' + Entry.Name + ':Clean">');
        OutLines.Add(ChildInd + '<MSBuild Projects="' + Entry.Include + '" Targets="Clean"/>');
        OutLines.Add(BaseInd + '</Target>');
        OutLines.Add(BaseInd + '<Target Name="' + Entry.Name + ':Make">');
        OutLines.Add(ChildInd + '<MSBuild Projects="' + Entry.Include + '" Targets="Make"/>');
        OutLines.Add(BaseInd + '</Target>');
      end;

      // Aggregate Build/Clean/Make targets.
      Names := '';
      BuildList := '';
      CleanList := '';
      MakeList := '';
      for Entry in Entries do
      begin
        if BuildList <> '' then
        begin
          BuildList := BuildList + ';';
          CleanList := CleanList + ';';
          MakeList := MakeList + ';';
        end;
        BuildList := BuildList + Entry.Name;
        CleanList := CleanList + Entry.Name + ':Clean';
        MakeList := MakeList + Entry.Name + ':Make';
      end;

      OutLines.Add(BaseInd + '<Target Name="Build">');
      OutLines.Add(ChildInd + '<CallTarget Targets="' + BuildList + '"/>');
      OutLines.Add(BaseInd + '</Target>');
      OutLines.Add(BaseInd + '<Target Name="Clean">');
      OutLines.Add(ChildInd + '<CallTarget Targets="' + CleanList + '"/>');
      OutLines.Add(BaseInd + '</Target>');
      OutLines.Add(BaseInd + '<Target Name="Make">');
      OutLines.Add(ChildInd + '<CallTarget Targets="' + MakeList + '"/>');
      OutLines.Add(BaseInd + '</Target>');
    end;

    // 9. Copy the remainder (<Import .../>, </Project>, ...).
    while I < InLines.Count do
    begin
      OutLines.Add(InLines[I]);
      Inc(I);
    end;

    Result := OutLines.Text;
  finally
    Entries.Free;
    OutLines.Free;
    InLines.Free;
  end;
end;

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
