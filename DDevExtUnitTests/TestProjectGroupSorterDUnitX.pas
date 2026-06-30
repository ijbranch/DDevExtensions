unit TestProjectGroupSorterDUnitX;

/// <summary>
/// DUnitX test fixture for <c>ProjectGroupSorterCore.SortGroupProjectText</c> —
/// the pure <c>.groupproj</c> re-ordering used by the "Sort Projects in Group"
/// feature. Verifies that the member projects are sorted alphabetically across
/// all three sections (<c>ItemGroup</c>, per-project <c>Target</c> blocks and
/// the <c>Build</c>/<c>Clean</c>/<c>Make</c> <c>CallTarget</c> lists), that the
/// boilerplate and per-project dependencies are preserved, and that the
/// transform is idempotent. The fixture is registered in this unit's
/// initialization section.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising the project-group sorter core.</summary>
  [TestFixture]
  TTestProjectGroupSorter = class
  public
    /// <summary>An unsorted group is reordered to exactly the canonical sorted form.</summary>
    [Test]
    procedure TestUnsortedBecomesSorted;
    /// <summary>Sorting an already-sorted group returns byte-identical text (drives the no-op path).</summary>
    [Test]
    procedure TestAlreadySortedIsIdempotent;
    /// <summary>The per-project <c>Target</c> trio order matches the sorted membership.</summary>
    [Test]
    procedure TestTargetBlocksSorted;
    /// <summary>The <c>Build</c>/<c>Clean</c>/<c>Make</c> <c>CallTarget</c> lists are sorted with their suffixes.</summary>
    [Test]
    procedure TestCallTargetListsSorted;
    /// <summary>Sorting is case-insensitive and handles the tricky "Scrap/SCtoXX/Store" ordering.</summary>
    [Test]
    procedure TestCaseInsensitiveAndTrickyOrder;
    /// <summary>The header, <c>ProjectGuid</c>, <c>ProjectExtensions</c> and <c>Import</c> survive verbatim.</summary>
    [Test]
    procedure TestBoilerplatePreserved;
    /// <summary>Non-empty per-project <c>&lt;Dependencies&gt;</c> content is preserved on the moved block.</summary>
    [Test]
    procedure TestDependenciesPreserved;
    /// <summary>A group with no <c>&lt;Target&gt;</c> section still reorders the ItemGroup and adds no targets.</summary>
    [Test]
    procedure TestNoTargetsSectionReordersItemGroupOnly;
    /// <summary>Output uses CRLF line endings.</summary>
    [Test]
    procedure TestCrlfLineEndings;
    /// <summary>A single-project group is returned unchanged.</summary>
    [Test]
    procedure TestSingleProjectUnchanged;
    /// <summary><c>LeafName</c> strips the directory and the .dproj extension.</summary>
    [Test]
    procedure TestLeafName;
  end;

implementation

uses
  System.SysUtils, System.Classes,
  ProjectGroupSorterCore;

const
  GUID = '{2AFA66CF-218B-4744-8ECA-C0CA5303688D}';

/// <summary>
/// Builds a canonical IDE-format <c>.groupproj</c> for the given project names
/// (folder = name), in the supplied order. Matches the exact layout that
/// <c>SortGroupProjectText</c> emits, so sorting <c>Build(unsorted)</c> yields
/// <c>Build(sorted)</c> byte-for-byte.
/// </summary>
function BuildGroupProj(const ANames: array of string): string;
var
  SL: TStringList;
  N, BuildList, CleanList, MakeList: string;
begin
  SL := TStringList.Create;
  try
    SL.LineBreak := #13#10;
    SL.Add('<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">');
    SL.Add('    <PropertyGroup>');
    SL.Add('        <ProjectGuid>' + GUID + '</ProjectGuid>');
    SL.Add('    </PropertyGroup>');
    SL.Add('    <ItemGroup>');
    for N in ANames do
    begin
      SL.Add('        <Projects Include="' + N + '\' + N + '.dproj">');
      SL.Add('            <Dependencies/>');
      SL.Add('        </Projects>');
    end;
    SL.Add('    </ItemGroup>');
    SL.Add('    <ProjectExtensions>');
    SL.Add('        <Borland.Personality>Default.Personality.12</Borland.Personality>');
    SL.Add('        <Borland.ProjectType/>');
    SL.Add('        <BorlandProject>');
    SL.Add('            <Default.Personality/>');
    SL.Add('        </BorlandProject>');
    SL.Add('    </ProjectExtensions>');
    for N in ANames do
    begin
      SL.Add('    <Target Name="' + N + '">');
      SL.Add('        <MSBuild Projects="' + N + '\' + N + '.dproj"/>');
      SL.Add('    </Target>');
      SL.Add('    <Target Name="' + N + ':Clean">');
      SL.Add('        <MSBuild Projects="' + N + '\' + N + '.dproj" Targets="Clean"/>');
      SL.Add('    </Target>');
      SL.Add('    <Target Name="' + N + ':Make">');
      SL.Add('        <MSBuild Projects="' + N + '\' + N + '.dproj" Targets="Make"/>');
      SL.Add('    </Target>');
    end;
    BuildList := '';
    CleanList := '';
    MakeList := '';
    for N in ANames do
    begin
      if BuildList <> '' then
      begin
        BuildList := BuildList + ';';
        CleanList := CleanList + ';';
        MakeList := MakeList + ';';
      end;
      BuildList := BuildList + N;
      CleanList := CleanList + N + ':Clean';
      MakeList := MakeList + N + ':Make';
    end;
    SL.Add('    <Target Name="Build">');
    SL.Add('        <CallTarget Targets="' + BuildList + '"/>');
    SL.Add('    </Target>');
    SL.Add('    <Target Name="Clean">');
    SL.Add('        <CallTarget Targets="' + CleanList + '"/>');
    SL.Add('    </Target>');
    SL.Add('    <Target Name="Make">');
    SL.Add('        <CallTarget Targets="' + MakeList + '"/>');
    SL.Add('    </Target>');
    SL.Add('    <Import Project="$(BDS)\Bin\CodeGear.Group.Targets" Condition="Exists(' +
      QuotedStr('$(BDS)\Bin\CodeGear.Group.Targets') + ')"/>');
    SL.Add('</Project>');
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

{ TTestProjectGroupSorter }

procedure TTestProjectGroupSorter.TestUnsortedBecomesSorted;
var
  Input, Expected: string;
begin
  Input := BuildGroupProj(['Cherry', 'Apple', 'Banana']);
  Expected := BuildGroupProj(['Apple', 'Banana', 'Cherry']);
  Assert.AreEqual(Expected, SortGroupProjectText(Input));
end;

procedure TTestProjectGroupSorter.TestAlreadySortedIsIdempotent;
var
  Sorted: string;
begin
  Sorted := BuildGroupProj(['Apple', 'Banana', 'Cherry']);
  Assert.AreEqual(Sorted, SortGroupProjectText(Sorted),
    'Sorting an already-sorted group must return byte-identical text');
end;

procedure TTestProjectGroupSorter.TestTargetBlocksSorted;
var
  Output: string;
begin
  Output := SortGroupProjectText(BuildGroupProj(['Zebra', 'Alpha', 'Mike']));
  Assert.IsTrue(
    Pos('<Target Name="Alpha">', Output) <
    Pos('<Target Name="Mike">', Output),
    'Alpha target must precede Mike target');
  Assert.IsTrue(
    Pos('<Target Name="Mike">', Output) <
    Pos('<Target Name="Zebra">', Output),
    'Mike target must precede Zebra target');
end;

procedure TTestProjectGroupSorter.TestCallTargetListsSorted;
var
  Output: string;
begin
  Output := SortGroupProjectText(BuildGroupProj(['Zebra', 'Alpha', 'Mike']));
  Assert.IsTrue(Pos('Targets="Alpha;Mike;Zebra"', Output) > 0,
    'Build CallTarget list must be sorted');
  Assert.IsTrue(Pos('Targets="Alpha:Clean;Mike:Clean;Zebra:Clean"', Output) > 0,
    'Clean CallTarget list must be sorted with :Clean suffixes');
  Assert.IsTrue(Pos('Targets="Alpha:Make;Mike:Make;Zebra:Make"', Output) > 0,
    'Make CallTarget list must be sorted with :Make suffixes');
end;

procedure TTestProjectGroupSorter.TestCaseInsensitiveAndTrickyOrder;
var
  Input, Expected: string;
begin
  // Mixed case + the real-world S-cluster ordering that bit the manual edit.
  Input := BuildGroupProj(['DBiStore', 'DBiSCtoXX', 'DBiScrap',
    'DBiScheduledReports', 'DBiScheduledEvents', 'apple', 'Banana']);
  Expected := BuildGroupProj(['apple', 'Banana', 'DBiScheduledEvents',
    'DBiScheduledReports', 'DBiScrap', 'DBiSCtoXX', 'DBiStore']);
  Assert.AreEqual(Expected, SortGroupProjectText(Input));
end;

procedure TTestProjectGroupSorter.TestBoilerplatePreserved;
var
  Output: string;
begin
  Output := SortGroupProjectText(BuildGroupProj(['Beta', 'Alpha']));
  Assert.IsTrue(Pos('<ProjectGuid>' + GUID + '</ProjectGuid>', Output) > 0, 'ProjectGuid lost');
  Assert.IsTrue(Pos('<Borland.Personality>Default.Personality.12</Borland.Personality>', Output) > 0,
    'ProjectExtensions lost');
  Assert.IsTrue(Pos('CodeGear.Group.Targets', Output) > 0, 'Import element lost');
end;

procedure TTestProjectGroupSorter.TestDependenciesPreserved;
var
  Input, Output: string;
  PosBeta, PosDep, PosAlpha: Integer;
begin
  // Two projects; "Beta" (which sorts last) carries a non-empty Dependencies block.
  Input :=
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">'#13#10 +
    '    <PropertyGroup>'#13#10 +
    '        <ProjectGuid>' + GUID + '</ProjectGuid>'#13#10 +
    '    </PropertyGroup>'#13#10 +
    '    <ItemGroup>'#13#10 +
    '        <Projects Include="Beta\Beta.dproj">'#13#10 +
    '            <Dependencies>Alpha\Alpha.dproj</Dependencies>'#13#10 +
    '        </Projects>'#13#10 +
    '        <Projects Include="Alpha\Alpha.dproj">'#13#10 +
    '            <Dependencies/>'#13#10 +
    '        </Projects>'#13#10 +
    '    </ItemGroup>'#13#10 +
    '    <Import Project="x"/>'#13#10 +
    '</Project>'#13#10;

  Output := SortGroupProjectText(Input);

  // The dependency content survives...
  PosDep := Pos('<Dependencies>Alpha\Alpha.dproj</Dependencies>', Output);
  Assert.IsTrue(PosDep > 0, 'Non-empty Dependencies content was lost');

  // ...and Alpha now precedes Beta in the ItemGroup.
  PosAlpha := Pos('<Projects Include="Alpha\Alpha.dproj">', Output);
  PosBeta := Pos('<Projects Include="Beta\Beta.dproj">', Output);
  Assert.IsTrue((PosAlpha > 0) and (PosAlpha < PosBeta), 'Alpha must precede Beta after sort');
end;

procedure TTestProjectGroupSorter.TestNoTargetsSectionReordersItemGroupOnly;
var
  Input, Output: string;
begin
  Input :=
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">'#13#10 +
    '    <PropertyGroup>'#13#10 +
    '        <ProjectGuid>' + GUID + '</ProjectGuid>'#13#10 +
    '    </PropertyGroup>'#13#10 +
    '    <ItemGroup>'#13#10 +
    '        <Projects Include="Beta\Beta.dproj">'#13#10 +
    '            <Dependencies/>'#13#10 +
    '        </Projects>'#13#10 +
    '        <Projects Include="Alpha\Alpha.dproj">'#13#10 +
    '            <Dependencies/>'#13#10 +
    '        </Projects>'#13#10 +
    '    </ItemGroup>'#13#10 +
    '    <Import Project="x"/>'#13#10 +
    '</Project>'#13#10;

  Output := SortGroupProjectText(Input);

  Assert.IsTrue(
    Pos('<Projects Include="Alpha\Alpha.dproj">', Output) <
    Pos('<Projects Include="Beta\Beta.dproj">', Output),
    'ItemGroup must be reordered even without a Target section');
  Assert.AreEqual(0, Pos('<Target', Output), 'No <Target> elements must be invented');
end;

procedure TTestProjectGroupSorter.TestCrlfLineEndings;
var
  Output: string;
  K, LfCount, CrlfCount: Integer;
begin
  Output := SortGroupProjectText(BuildGroupProj(['Beta', 'Alpha']));
  Assert.IsTrue(Pos(#13#10, Output) > 0, 'Output must contain CRLF');
  // Every LF must be part of a CRLF pair — no bare LF line endings.
  LfCount := 0;
  CrlfCount := 0;
  for K := 1 to Length(Output) do
    if Output[K] = #10 then
    begin
      Inc(LfCount);
      if (K > 1) and (Output[K - 1] = #13) then
        Inc(CrlfCount);
    end;
  Assert.AreEqual(LfCount, CrlfCount, 'Every LF must be preceded by CR (CRLF only)');
end;

procedure TTestProjectGroupSorter.TestSingleProjectUnchanged;
var
  Single: string;
begin
  Single := BuildGroupProj(['Solo']);
  Assert.AreEqual(Single, SortGroupProjectText(Single));
end;

procedure TTestProjectGroupSorter.TestLeafName;
begin
  Assert.AreEqual('DBiAdmin', LeafName('DBiAdmin\DBiAdmin.dproj'));
  Assert.AreEqual('Solo', LeafName('Solo.dproj'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestProjectGroupSorter);

end.
