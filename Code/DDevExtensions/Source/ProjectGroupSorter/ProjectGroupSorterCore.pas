{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit ProjectGroupSorterCore;

/// <summary>
/// Pure, RTL-only sorting logic for the "Sort Projects in Group" feature.
/// Separated from <c>ProjectGroupSorter</c> (which is IDE/ToolsAPI-coupled) so
/// the transformation is unit-testable by a standalone test executable.
/// </summary>
/// <remarks>
/// A <c>.groupproj</c> lists every project three times: once in the
/// <c>&lt;ItemGroup&gt;</c> (the membership), once as a trio of per-project
/// <c>&lt;Target&gt;</c> elements, and once in each of the <c>Build</c>,
/// <c>Clean</c> and <c>Make</c> <c>CallTarget</c> lists. The Project Manager
/// tree order follows the <c>&lt;Target&gt;</c>/<c>CallTarget</c> sections, so
/// <see cref="SortGroupProjectText"/> sorts <b>all three</b> consistently — a
/// previous attempt that sorted only the <c>&lt;ItemGroup&gt;</c> had no
/// visible effect.
/// </remarks>

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
function SortGroupProjectText(const AText: string): string;

/// <summary>
/// Returns the project name (no path, no extension) for an <c>Include</c>
/// value such as <c>"DBiAdmin\DBiAdmin.dproj"</c> → <c>"DBiAdmin"</c>.
/// </summary>
function LeafName(const AInclude: string): string;

implementation

uses
  System.SysUtils, System.StrUtils, System.Classes, System.IOUtils,
  System.Generics.Collections, System.Generics.Defaults;

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
  BuildList, CleanList, MakeList: string;
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

end.
