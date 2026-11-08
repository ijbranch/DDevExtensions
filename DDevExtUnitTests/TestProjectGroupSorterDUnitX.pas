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
  [ TestFixture ]
  TTestProjectGroupSorter = class
  public
    /// <summary>An unsorted group is reordered to exactly the canonical sorted form.</summary>
    [ Test ]
    procedure TestUnsortedBecomesSorted;
    /// <summary>Sorting an already-sorted group returns byte-identical text (drives the no-op path).</summary>
    [ Test ]
    procedure TestAlreadySortedIsIdempotent;
    /// <summary>The per-project <c>Target</c> trio order matches the sorted membership.</summary>
    [ Test ]
    procedure TestTargetBlocksSorted;
    /// <summary>The <c>Build</c>/<c>Clean</c>/<c>Make</c> <c>CallTarget</c> lists are sorted with their suffixes.</summary>
    [ Test ]
    procedure TestCallTargetListsSorted;
    /// <summary>Sorting is case-insensitive and handles the tricky "Scrap/SCtoXX/Store" ordering.</summary>
    [ Test ]
    procedure TestCaseInsensitiveAndTrickyOrder;
    /// <summary>The header, <c>ProjectGuid</c>, <c>ProjectExtensions</c> and <c>Import</c> survive verbatim.</summary>
    [ Test ]
    procedure TestBoilerplatePreserved;
    /// <summary>Non-empty per-project <c>&lt;Dependencies&gt;</c> content is preserved on the moved block.</summary>
    [ Test ]
    procedure TestDependenciesPreserved;
    /// <summary>A group with no <c>&lt;Target&gt;</c> section still reorders the ItemGroup and adds no targets.</summary>
    [ Test ]
    procedure TestNoTargetsSectionReordersItemGroupOnly;
    /// <summary>Output uses CRLF line endings.</summary>
    [ Test ]
    procedure TestCrlfLineEndings;
    /// <summary>A single-project group is returned unchanged.</summary>
    [ Test ]
    procedure TestSingleProjectUnchanged;
    /// <summary><c>LeafName</c> strips the directory and the .dproj extension.</summary>
    [ Test ]
    procedure TestLeafName;
    /// <summary>
    /// The IDE's <c>DependsOnTargets</c> build dependencies survive the sort on all three
    /// per-project targets; the earlier rewrite regenerated bare targets and dropped them.
    /// </summary>
    [ Test ]
    procedure TestDependsOnTargetsPreserved;
    /// <summary>
    /// Target names the IDE sanitised (<c>Ann.dxe2.dproj</c> -> <c>Ann_dxe2</c>) are kept, and the
    /// CallTarget lists are reordered by them; the earlier rewrite renamed them to <c>Ann.dxe2</c>.
    /// </summary>
    [ Test ]
    procedure TestSanitisedTargetNamesKept;
    /// <summary>A tab-indented group keeps its tabs: only lines move, none is re-indented.</summary>
    [ Test ]
    procedure TestTabIndentationPreserved;
    /// <summary>A custom, non-project target survives verbatim and keeps its position.</summary>
    [ Test ]
    procedure TestCustomTargetPreserved;
    /// <summary>An unterminated <c>&lt;Target&gt;</c> raises instead of producing a truncated file.</summary>
    [ Test ]
    procedure TestUnterminatedTargetRaises;
    /// <summary>LF line breaks and a missing final line break are kept as found.</summary>
    [ Test ]
    procedure TestLineBreakStylePreserved;
  end;

implementation

uses
  System.SysUtils, System.Classes,
  ProjectGroupSorterCore;

const
  GUID              = '{2AFA66CF-218B-4744-8ECA-C0CA5303688D}';

/// <summary>
/// Builds a canonical IDE-format <c>.groupproj</c> for the given project names
/// (folder = name), in the supplied order. Matches the exact layout that
/// <c>SortGroupProjectText</c> emits, so sorting <c>Build(unsorted)</c> yields
/// <c>Build(sorted)</c> byte-for-byte.
/// </summary>
function BuildGroupProj( const ANames: array of string ): string;
var
  SL                : TStringList;
  N, BuildList, CleanList, MakeList: string;
begin
  SL                := TStringList.Create;
  try
    SL.LineBreak    := #13#10;
    SL.Add( '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' );
    SL.Add( '    <PropertyGroup>' );
    SL.Add( '        <ProjectGuid>' + GUID + '</ProjectGuid>' );
    SL.Add( '    </PropertyGroup>' );
    SL.Add( '    <ItemGroup>' );
    for N in ANames do
    begin
      SL.Add( '        <Projects Include="' + N + '\' + N + '.dproj">' );
      SL.Add( '            <Dependencies/>' );
      SL.Add( '        </Projects>' );
    end;
    SL.Add( '    </ItemGroup>' );
    SL.Add( '    <ProjectExtensions>' );
    SL.Add( '        <Borland.Personality>Default.Personality.12</Borland.Personality>' );
    SL.Add( '        <Borland.ProjectType/>' );
    SL.Add( '        <BorlandProject>' );
    SL.Add( '            <Default.Personality/>' );
    SL.Add( '        </BorlandProject>' );
    SL.Add( '    </ProjectExtensions>' );
    for N in ANames do
    begin
      SL.Add( '    <Target Name="' + N + '">' );
      SL.Add( '        <MSBuild Projects="' + N + '\' + N + '.dproj"/>' );
      SL.Add( '    </Target>' );
      SL.Add( '    <Target Name="' + N + ':Clean">' );
      SL.Add( '        <MSBuild Projects="' + N + '\' + N + '.dproj" Targets="Clean"/>' );
      SL.Add( '    </Target>' );
      SL.Add( '    <Target Name="' + N + ':Make">' );
      SL.Add( '        <MSBuild Projects="' + N + '\' + N + '.dproj" Targets="Make"/>' );
      SL.Add( '    </Target>' );
    end;
    BuildList       := '';
    CleanList       := '';
    MakeList        := '';
    for N in ANames do
    begin
      if BuildList <> '' then
      begin
        BuildList   := BuildList + ';';
        CleanList   := CleanList + ';';
        MakeList    := MakeList + ';';
      end;
      BuildList     := BuildList + N;
      CleanList     := CleanList + N + ':Clean';
      MakeList      := MakeList + N + ':Make';
    end;
    SL.Add( '    <Target Name="Build">' );
    SL.Add( '        <CallTarget Targets="' + BuildList + '"/>' );
    SL.Add( '    </Target>' );
    SL.Add( '    <Target Name="Clean">' );
    SL.Add( '        <CallTarget Targets="' + CleanList + '"/>' );
    SL.Add( '    </Target>' );
    SL.Add( '    <Target Name="Make">' );
    SL.Add( '        <CallTarget Targets="' + MakeList + '"/>' );
    SL.Add( '    </Target>' );
    SL.Add( '    <Import Project="$(BDS)\Bin\CodeGear.Group.Targets" Condition="Exists(' +
      QuotedStr( '$(BDS)\Bin\CodeGear.Group.Targets' ) + ')"/>' );
    SL.Add( '</Project>' );
    Result          := SL.Text;
  finally
    SL.Free;
  end;
end;

{ TTestProjectGroupSorter }

procedure TTestProjectGroupSorter.TestUnsortedBecomesSorted;
var
  Input, Expected   : string;
begin
  Input             := BuildGroupProj( [ 'Cherry', 'Apple', 'Banana' ] );
  Expected          := BuildGroupProj( [ 'Apple', 'Banana', 'Cherry' ] );
  Assert.AreEqual( Expected, SortGroupProjectText( Input ) );
end;

procedure TTestProjectGroupSorter.TestAlreadySortedIsIdempotent;
var
  Sorted            : string;
begin
  Sorted            := BuildGroupProj( [ 'Apple', 'Banana', 'Cherry' ] );
  Assert.AreEqual( Sorted, SortGroupProjectText( Sorted ),
    'Sorting an already-sorted group must return byte-identical text' );
end;

procedure TTestProjectGroupSorter.TestTargetBlocksSorted;
var
  Output            : string;
begin
  Output            := SortGroupProjectText( BuildGroupProj( [ 'Zebra', 'Alpha', 'Mike' ] ) );
  Assert.IsTrue(
    Pos( '<Target Name="Alpha">', Output ) <
    Pos( '<Target Name="Mike">', Output ),
    'Alpha target must precede Mike target' );
  Assert.IsTrue(
    Pos( '<Target Name="Mike">', Output ) <
    Pos( '<Target Name="Zebra">', Output ),
    'Mike target must precede Zebra target' );
end;

procedure TTestProjectGroupSorter.TestCallTargetListsSorted;
var
  Output            : string;
begin
  Output            := SortGroupProjectText( BuildGroupProj( [ 'Zebra', 'Alpha', 'Mike' ] ) );
  Assert.IsTrue( Pos( 'Targets="Alpha;Mike;Zebra"', Output ) > 0,
    'Build CallTarget list must be sorted' );
  Assert.IsTrue( Pos( 'Targets="Alpha:Clean;Mike:Clean;Zebra:Clean"', Output ) > 0,
    'Clean CallTarget list must be sorted with :Clean suffixes' );
  Assert.IsTrue( Pos( 'Targets="Alpha:Make;Mike:Make;Zebra:Make"', Output ) > 0,
    'Make CallTarget list must be sorted with :Make suffixes' );
end;

procedure TTestProjectGroupSorter.TestCaseInsensitiveAndTrickyOrder;
var
  Input, Expected   : string;
begin
  // Mixed case + the real-world S-cluster ordering that bit the manual edit.
  Input             := BuildGroupProj( [ 'DBiStore', 'DBiSCtoXX', 'DBiScrap',
      'DBiScheduledReports', 'DBiScheduledEvents', 'apple', 'Banana' ] );
  Expected          := BuildGroupProj( [ 'apple', 'Banana', 'DBiScheduledEvents',
      'DBiScheduledReports', 'DBiScrap', 'DBiSCtoXX', 'DBiStore' ] );
  Assert.AreEqual( Expected, SortGroupProjectText( Input ) );
end;

procedure TTestProjectGroupSorter.TestBoilerplatePreserved;
var
  Output            : string;
begin
  Output            := SortGroupProjectText( BuildGroupProj( [ 'Beta', 'Alpha' ] ) );
  Assert.IsTrue( Pos( '<ProjectGuid>' + GUID + '</ProjectGuid>', Output ) > 0, 'ProjectGuid lost' );
  Assert.IsTrue( Pos( '<Borland.Personality>Default.Personality.12</Borland.Personality>', Output ) > 0,
    'ProjectExtensions lost' );
  Assert.IsTrue( Pos( 'CodeGear.Group.Targets', Output ) > 0, 'Import element lost' );
end;

procedure TTestProjectGroupSorter.TestDependenciesPreserved;
var
  Input, Output     : string;
  PosBeta, PosDep, PosAlpha: Integer;
begin
  // Two projects; "Beta" (which sorts last) carries a non-empty Dependencies block.
  Input             :=
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

  Output            := SortGroupProjectText( Input );

  // The dependency content survives...
  PosDep            := Pos( '<Dependencies>Alpha\Alpha.dproj</Dependencies>', Output );
  Assert.IsTrue( PosDep > 0, 'Non-empty Dependencies content was lost' );

  // ...and Alpha now precedes Beta in the ItemGroup.
  PosAlpha          := Pos( '<Projects Include="Alpha\Alpha.dproj">', Output );
  PosBeta           := Pos( '<Projects Include="Beta\Beta.dproj">', Output );
  Assert.IsTrue( ( PosAlpha > 0 ) and ( PosAlpha < PosBeta ), 'Alpha must precede Beta after sort' );
end;

procedure TTestProjectGroupSorter.TestNoTargetsSectionReordersItemGroupOnly;
var
  Input, Output     : string;
begin
  Input             :=
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

  Output            := SortGroupProjectText( Input );

  Assert.IsTrue(
    Pos( '<Projects Include="Alpha\Alpha.dproj">', Output ) <
    Pos( '<Projects Include="Beta\Beta.dproj">', Output ),
    'ItemGroup must be reordered even without a Target section' );
  Assert.AreEqual( 0, Pos( '<Target', Output ), 'No <Target> elements must be invented' );
end;

procedure TTestProjectGroupSorter.TestCrlfLineEndings;
var
  Output            : string;
  K, LfCount, CrlfCount: Integer;
begin
  Output            := SortGroupProjectText( BuildGroupProj( [ 'Beta', 'Alpha' ] ) );
  Assert.IsTrue( Pos( #13#10, Output ) > 0, 'Output must contain CRLF' );
  // Every LF must be part of a CRLF pair — no bare LF line endings.
  LfCount           := 0;
  CrlfCount         := 0;
  for K := 1 to Length( Output ) do
    if Output[ K ] = #10 then
    begin
      Inc( LfCount );
      if ( K > 1 ) and ( Output[ K - 1 ] = #13 ) then
        Inc( CrlfCount );
    end;
  Assert.AreEqual( LfCount, CrlfCount, 'Every LF must be preceded by CR (CRLF only)' );
end;

procedure TTestProjectGroupSorter.TestSingleProjectUnchanged;
var
  Single            : string;
begin
  Single            := BuildGroupProj( [ 'Solo' ] );
  Assert.AreEqual( Single, SortGroupProjectText( Single ) );
end;

procedure TTestProjectGroupSorter.TestLeafName;
begin
  Assert.AreEqual( 'DBiAdmin', LeafName( 'DBiAdmin\DBiAdmin.dproj' ) );
  Assert.AreEqual( 'Solo', LeafName( 'Solo.dproj' ) );
end;

/// <summary>Builds a two-project group in which "Beta" depends on "Alpha" and is listed first.</summary>
/// <param name="AIndent">One level of indentation, e.g. four spaces or a tab.</param>
/// <returns>The <c>.groupproj</c> text, CRLF line breaks.</returns>
function BuildDependentGroup( const AIndent: string ): string;
var
  I1, I2, I3        : string;
begin
  I1                := AIndent;
  I2                := AIndent + AIndent;
  I3                := I2 + AIndent;
  Result            :=
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">'#13#10 +
    I1 + '<ItemGroup>'#13#10 +
    I2 + '<Projects Include="Beta\Beta.dproj">'#13#10 +
    I3 + '<Dependencies>Alpha\Alpha.dproj</Dependencies>'#13#10 +
    I2 + '</Projects>'#13#10 +
    I2 + '<Projects Include="Alpha\Alpha.dproj">'#13#10 +
    I3 + '<Dependencies/>'#13#10 +
    I2 + '</Projects>'#13#10 +
    I1 + '</ItemGroup>'#13#10 +
    I1 + '<Target Name="Beta" DependsOnTargets="Alpha">'#13#10 +
    I2 + '<MSBuild Projects="Beta\Beta.dproj"/>'#13#10 +
    I1 + '</Target>'#13#10 +
    I1 + '<Target Name="Beta:Clean" DependsOnTargets="Alpha:Clean">'#13#10 +
    I2 + '<MSBuild Projects="Beta\Beta.dproj" Targets="Clean"/>'#13#10 +
    I1 + '</Target>'#13#10 +
    I1 + '<Target Name="Beta:Make" DependsOnTargets="Alpha:Make">'#13#10 +
    I2 + '<MSBuild Projects="Beta\Beta.dproj" Targets="Make"/>'#13#10 +
    I1 + '</Target>'#13#10 +
    I1 + '<Target Name="Alpha">'#13#10 +
    I2 + '<MSBuild Projects="Alpha\Alpha.dproj"/>'#13#10 +
    I1 + '</Target>'#13#10 +
    I1 + '<Target Name="Alpha:Clean">'#13#10 +
    I2 + '<MSBuild Projects="Alpha\Alpha.dproj" Targets="Clean"/>'#13#10 +
    I1 + '</Target>'#13#10 +
    I1 + '<Target Name="Alpha:Make">'#13#10 +
    I2 + '<MSBuild Projects="Alpha\Alpha.dproj" Targets="Make"/>'#13#10 +
    I1 + '</Target>'#13#10 +
    I1 + '<Target Name="Build">'#13#10 +
    I2 + '<CallTarget Targets="Beta;Alpha"/>'#13#10 +
    I1 + '</Target>'#13#10 +
    I1 + '<Target Name="Clean">'#13#10 +
    I2 + '<CallTarget Targets="Beta:Clean;Alpha:Clean"/>'#13#10 +
    I1 + '</Target>'#13#10 +
    I1 + '<Target Name="Make">'#13#10 +
    I2 + '<CallTarget Targets="Beta:Make;Alpha:Make"/>'#13#10 +
    I1 + '</Target>'#13#10 +
    I1 + '<Import Project="x"/>'#13#10 +
    '</Project>'#13#10;
end;

procedure TTestProjectGroupSorter.TestDependsOnTargetsPreserved;
var
  Output            : string;
begin
  Output            := SortGroupProjectText( BuildDependentGroup( '    ' ) );
  Assert.IsTrue( Pos( '<Target Name="Beta" DependsOnTargets="Alpha">', Output ) > 0, 'Build dependency lost' );
  Assert.IsTrue( Pos( '<Target Name="Beta:Clean" DependsOnTargets="Alpha:Clean">', Output ) > 0,
    'Clean dependency lost' );
  Assert.IsTrue( Pos( '<Target Name="Beta:Make" DependsOnTargets="Alpha:Make">', Output ) > 0,
    'Make dependency lost' );
  Assert.IsTrue( Pos( '<Target Name="Alpha">', Output ) < Pos( '<Target Name="Beta" ', Output ),
    'Alpha targets must now precede Beta targets' );
  Assert.IsTrue( Pos( 'Targets="Alpha;Beta"', Output ) > 0, 'Build CallTarget list must be sorted' );
end;

procedure TTestProjectGroupSorter.TestSanitisedTargetNamesKept;
var
  Input, Output     : string;
begin
  Input             :=
    '<Project>'#13#10 +
    '    <ItemGroup>'#13#10 +
    '        <Projects Include="Zed\Zed.dxe2.dproj">'#13#10 +
    '            <Dependencies/>'#13#10 +
    '        </Projects>'#13#10 +
    '        <Projects Include="Ann\Ann.dxe2.dproj">'#13#10 +
    '            <Dependencies/>'#13#10 +
    '        </Projects>'#13#10 +
    '    </ItemGroup>'#13#10 +
    '    <Target Name="Zed_dxe2">'#13#10 +
    '        <MSBuild Projects="Zed\Zed.dxe2.dproj"/>'#13#10 +
    '    </Target>'#13#10 +
    '    <Target Name="Ann_dxe2">'#13#10 +
    '        <MSBuild Projects="Ann\Ann.dxe2.dproj"/>'#13#10 +
    '    </Target>'#13#10 +
    '    <Target Name="Build">'#13#10 +
    '        <CallTarget Targets="Zed_dxe2;Ann_dxe2"/>'#13#10 +
    '    </Target>'#13#10 +
    '    <Import Project="x"/>'#13#10 +
    '</Project>'#13#10;
  Output            := SortGroupProjectText( Input );
  Assert.AreEqual( 0, Pos( 'Name="Ann.dxe2', Output ), 'Target was renamed' );
  Assert.IsTrue( Pos( 'Targets="Ann_dxe2;Zed_dxe2"', Output ) > 0, 'CallTarget list must use the file''s own names' );
  Assert.IsTrue( Pos( '<Target Name="Ann_dxe2">', Output ) < Pos( '<Target Name="Zed_dxe2">', Output ),
    'Ann target must precede Zed target' );
end;

procedure TTestProjectGroupSorter.TestTabIndentationPreserved;
var
  Output            : string;
begin
  Output            := SortGroupProjectText( BuildDependentGroup( #9 ) );
  Assert.IsTrue( Pos( #9'<Target Name="Alpha">', Output ) > 0, 'Tab indentation was lost' );
  Assert.AreEqual( 0, Pos( #13#10'<Target', Output ), 'A target was moved to column 0' );
end;

procedure TTestProjectGroupSorter.TestCustomTargetPreserved;
var
  Input, Output     : string;
begin
  Input             := StringReplace( BuildDependentGroup( '    ' ), '    <Target Name="Build">',
    '    <Target Name="Deploy">'#13#10'        <Exec Command="deploy.cmd"/>'#13#10'    </Target>'#13#10 +
    '    <Target Name="Build">', [ ] );
  Output            := SortGroupProjectText( Input );
  Assert.IsTrue( Pos( '<Target Name="Deploy">'#13#10'        <Exec Command="deploy.cmd"/>', Output ) > 0,
    'Custom target lost or altered' );
  Assert.IsTrue( Pos( '<Target Name="Deploy">', Output ) < Pos( '<Target Name="Build">', Output ),
    'Custom target moved' );
end;

procedure TTestProjectGroupSorter.TestUnterminatedTargetRaises;
var
  Input             : string;
begin
  Input             := StringReplace( BuildDependentGroup( '    ' ), '    </Target>'#13#10'    <Import', '    <Import', [ ] );
  Assert.WillRaise(
    procedure
    begin
      SortGroupProjectText( Input );
    end, EGroupProjSortError );
end;

procedure TTestProjectGroupSorter.TestLineBreakStylePreserved;
var
  Input, Output     : string;
begin
  Input             := StringReplace( BuildGroupProj( [ 'Beta', 'Alpha' ] ), #13#10, #10, [ rfReplaceAll ] );
  SetLength( Input, Length( Input ) - 1 ); // no final line break
  Output            := SortGroupProjectText( Input );
  Assert.AreEqual( 0, Pos( #13, Output ), 'LF file was converted to CRLF' );
  Assert.AreNotEqual( string( #10 ), string( Output[ Length( Output ) ] ), 'A final line break was added' );
  Assert.IsTrue( Pos( '<Projects Include="Alpha', Output ) < Pos( '<Projects Include="Beta', Output ),
    'Not sorted' );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestProjectGroupSorter );

end.

