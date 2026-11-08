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
/// <see cref="SortGroupProjectText"/> reorders <b>all three</b> consistently — a
/// previous attempt that sorted only the <c>&lt;ItemGroup&gt;</c> had no
/// visible effect.
///
/// Every element is MOVED, never regenerated: the per-project <c>&lt;Target&gt;</c>
/// blocks keep their own text (the IDE's <c>DependsOnTargets</c> build
/// dependencies, its sanitised target names such as <c>Demo_dxe2</c>, and the
/// file's own indentation), and only the order of the names inside the three
/// <c>CallTarget</c> lists is rewritten. The result is checked to be a
/// permutation of the input lines before it is returned.
/// </remarks>

interface

uses
  System.SysUtils;

type
  /// <summary>Raised when a <c>.groupproj</c> cannot be sorted without risking its content.</summary>
  EGroupProjSortError = class( Exception );

/// <summary>
/// Returns <paramref name="AText"/> (the verbatim contents of a
/// <c>.groupproj</c>) with its member projects sorted alphabetically by
/// project name across the <c>ItemGroup</c>, the per-project <c>Target</c>
/// blocks and the <c>Build</c>/<c>Clean</c>/<c>Make</c> <c>CallTarget</c>
/// lists.
/// </summary>
/// <remarks>
/// Everything other than the order of whole blocks and of the names in the
/// <c>CallTarget</c> lists is preserved verbatim, including <c>DependsOnTargets</c>,
/// target names, indentation and any custom targets. The input's line break
/// (CRLF or LF) and the presence or absence of a final line break are kept.
/// </remarks>
/// <param name="AText">The complete text of the <c>.groupproj</c>.</param>
/// <returns>The sorted text; identical to <paramref name="AText"/> when it is already sorted.</returns>
/// <exception cref="EGroupProjSortError">
/// The file is malformed (an unterminated <c>&lt;Target&gt;</c> or <c>&lt;Projects&gt;</c>
/// element), or the result would not be a pure reordering of the input.
/// </exception>
function SortGroupProjectText( const AText: string ): string;

/// <summary>
/// Returns the project name (no path, no extension) for an <c>Include</c>
/// value such as <c>"DBiAdmin\DBiAdmin.dproj"</c> → <c>"DBiAdmin"</c>.
/// </summary>
/// <param name="AInclude">The <c>Include</c> attribute value of a <c>&lt;Projects&gt;</c> element.</param>
/// <returns>The file name without directory or extension.</returns>
function LeafName( const AInclude: string ): string;

implementation

uses
  System.StrUtils, System.Classes, System.IOUtils,
  System.Generics.Collections, System.Generics.Defaults;

type
  /// <summary>One member project parsed from the <c>ItemGroup</c>.</summary>
  TProjEntry = record
    /// <summary>Project name without path or extension (e.g. "DBiAdmin"); the sort key.</summary>
    Name: string;
    /// <summary>The verbatim <c>Include</c> value (e.g. "DBiAdmin\DBiAdmin.dproj").</summary>
    Include: string;
    /// <summary>Position in the original file; the tie-breaker that keeps the sort stable.</summary>
    Index: Integer;
    /// <summary>The full text of the <c>&lt;Projects&gt;...&lt;/Projects&gt;</c> block (preserves dependencies).</summary>
    Lines: TArray<string>;
    /// <summary>The base name of this project's own targets as the file spells it (e.g. "Demo_dxe2"), or empty.</summary>
    TargetName: string;
  end;

  /// <summary>One <c>&lt;Target&gt;</c> element of the target region, with any blank or comment lines that precede it.</summary>
  TTargetBlock = record
    /// <summary>The verbatim lines, leading non-target lines included.</summary>
    Lines: TArray<string>;
    /// <summary>The <c>Name</c> attribute.</summary>
    Name: string;
    /// <summary>The <c>Projects</c> attribute of the block's <c>&lt;MSBuild&gt;</c> element, or empty.</summary>
    ProjectInclude: string;
    /// <summary>Index into the entry list of the project that owns the block, or -1.</summary>
    Owner: Integer;
  end;

function LeafName( const AInclude: string ): string;
begin
  // Strip directory and the .dproj extension: "DBiAdmin\DBiAdmin.dproj" -> "DBiAdmin"
  Result            := TPath.GetFileNameWithoutExtension( StringReplace( AInclude, '\', PathDelim, [ rfReplaceAll ] ) );
end;

/// <summary>Returns the value of attribute AName in ALine, or empty when it is absent.</summary>
/// <param name="ALine">One line of XML text.</param>
/// <param name="AName">The attribute name, without the equals sign.</param>
/// <returns>The text between the quotes, or empty.</returns>
function AttributeValue( const ALine, AName: string ): string;
begin
  Result            := '';
  var Start         := Pos( AName + '="', ALine );
  if ( Start = 0 ) then
    Exit;
  Inc( Start, Length( AName ) + 2 );
  var Stop          := PosEx( '"', ALine, Start );
  if ( Stop > 0 ) then
    Result          := Copy( ALine, Start, Stop - Start );
end;

/// <summary>Strips a <c>:Clean</c> / <c>:Make</c> style suffix from a target name.</summary>
/// <param name="ATarget">A target name such as "Demo_dxe2:Clean".</param>
/// <returns>The part before the first colon.</returns>
function BaseTargetName( const ATarget: string ): string;
begin
  var Colon         := Pos( ':', ATarget );
  if ( Colon > 0 ) then
    Result          := Copy( ATarget, 1, Colon - 1 )
  else
    Result          := ATarget;
end;

/// <summary>True when the two lists hold the same lines, ignoring order, apart from CallTarget lines.</summary>
/// <param name="AInput">The lines of the original file.</param>
/// <param name="AOutput">The lines of the sorted file.</param>
/// <returns>True when AOutput is a reordering of AInput.</returns>
function IsPermutation( AInput, AOutput: TStrings ): Boolean;

  procedure Collect( ASource: TStrings; ATarget: TStringList; var ACallTargets: Integer );
  begin
    for var I := 0 to ASource.Count - 1 do
      if ( Pos( '<CallTarget ', ASource[ I ] ) > 0 ) then
        Inc( ACallTargets )
      else
        ATarget.Add( ASource[ I ] );
  end;

begin
  var InSorted      := TStringList.Create;
  var OutSorted     := TStringList.Create;
  try
    var InCalls     := 0;
    var OutCalls    := 0;
    Collect( AInput, InSorted, InCalls );
    Collect( AOutput, OutSorted, OutCalls );
    InSorted.CaseSensitive := True;
    OutSorted.CaseSensitive := True;
    InSorted.Sort;
    OutSorted.Sort;
    Result          := ( InCalls = OutCalls ) and ( InSorted.Count = OutSorted.Count );
    if Result then
      for var I := 0 to InSorted.Count - 1 do
        if ( InSorted[ I ] <> OutSorted[ I ] ) then
          Exit( False );
  finally
    OutSorted.Free;
    InSorted.Free;
  end;
end;

/// <summary>
/// Reorders the names in a <c>&lt;CallTarget Targets="..."/&gt;</c> line to follow the
/// sorted project order, leaving the rest of the line untouched.
/// </summary>
/// <param name="ALine">The line holding the <c>CallTarget</c> element.</param>
/// <param name="AEntries">The member projects, already in sorted order.</param>
/// <returns>
/// The line with its names reordered. Names that belong to no member project keep
/// their relative order after the project names.
/// </returns>
function ReorderCallTargets( const ALine: string; AEntries: TList<TProjEntry> ): string;
type
  TToken = record
    Text: string;
    Rank: Integer;
    Index: Integer;
  end;
begin
  Result            := ALine;
  var Value         := AttributeValue( ALine, 'Targets' );
  if ( Value = '' ) then
    Exit;

  var Parts         := Value.Split( [ ';' ] );
  var Tokens        := TList<TToken>.Create;
  try
    for var P := Low( Parts ) to High( Parts ) do
    begin
      var Token     := Default( TToken );
      Token.Text    := Parts[ P ];
      Token.Index   := P;
      Token.Rank    := MaxInt;
      for var E := 0 to AEntries.Count - 1 do
        if ( AEntries[ E ].TargetName <> '' ) and SameText( AEntries[ E ].TargetName, BaseTargetName( Parts[ P ] ) ) then
        begin
          Token.Rank := E;
          Break;
        end;
      Tokens.Add( Token );
    end;

    Tokens.Sort( TComparer<TToken>.Construct(
        function( const L, R: TToken ): Integer
        begin
          if ( L.Rank < R.Rank ) then
            Result  := -1
          else if ( L.Rank > R.Rank ) then
            Result  := 1
          else
            Result  := L.Index - R.Index;
        end ) );

    var NewValue    := '';
    for var T := 0 to Tokens.Count - 1 do
    begin
      if ( T > 0 ) then
        NewValue    := NewValue + ';';
      NewValue      := NewValue + Tokens[ T ].Text;
    end;

    var Start       := Pos( 'Targets="', ALine ) + Length( 'Targets="' );
    Result          := Copy( ALine, 1, Start - 1 ) + NewValue + Copy( ALine, Start + Length( Value ), MaxInt );
  finally
    Tokens.Free;
  end;
end;

function SortGroupProjectText( const AText: string ): string;
var
  InLines, OutLines : TStringList;
  Entries           : TList<TProjEntry>;
  Blocks            : TList<TTargetBlock>;
  Pending           : TList<string>;
  Entry             : TProjEntry;
  Block             : TTargetBlock;
  I                 : Integer;
begin
  InLines           := TStringList.Create;
  OutLines          := TStringList.Create;
  Entries           := TList<TProjEntry>.Create;
  Blocks            := TList<TTargetBlock>.Create;
  Pending           := TList<string>.Create;
  try
    InLines.Text    := AText;
    // Keep the file's own line break: the IDE writes CRLF, hand-edited files may not.
    if ( Pos( #13#10, AText ) > 0 ) or ( Pos( #10, AText ) = 0 ) then
      OutLines.LineBreak := #13#10
    else
      OutLines.LineBreak := #10;

    I               := 0;

    // 1. Copy the header up to (not including) the first <Projects ...> element.
    while ( I < InLines.Count ) and not StartsText( '<Projects Include="', TrimLeft( InLines[ I ] ) ) do
    begin
      OutLines.Add( InLines[ I ] );
      Inc( I );
    end;

    // 2. Collect the consecutive <Projects>...</Projects> blocks.
    while ( I < InLines.Count ) and StartsText( '<Projects Include="', TrimLeft( InLines[ I ] ) ) do
    begin
      var Line      := InLines[ I ];
      var BlockLines := TList<string>.Create;
      try
        if EndsText( '/>', TrimRight( Line ) ) then
        begin
          // Self-closing <Projects Include="x"/> — single line, no dependencies.
          BlockLines.Add( Line );
          Inc( I );
        end
        else
        begin
          // Multi-line block: copy through the matching </Projects>.
          var Closed := False;
          while ( I < InLines.Count ) and not Closed do
          begin
            BlockLines.Add( InLines[ I ] );
            Closed  := SameText( Trim( InLines[ I ] ), '</Projects>' );
            Inc( I );
          end;
          if not Closed then
            raise EGroupProjSortError.Create( 'A <Projects> element is not closed.' );
        end;

        Entry       := Default( TProjEntry );
        Entry.Include := AttributeValue( Line, 'Include' );
        Entry.Name  := LeafName( Entry.Include );
        Entry.Index := Entries.Count;
        Entry.Lines := BlockLines.ToArray;
        Entries.Add( Entry );
      finally
        BlockLines.Free;
      end;
    end;

    // 3. Copy the middle (</ItemGroup>, ProjectExtensions, ...) until either the
    //    first <Target ...> or the trailing <Import .../> / EOF.
    var Middle      := TList<string>.Create;
    try
      while ( I < InLines.Count ) and not StartsText( '<Target Name="', TrimLeft( InLines[ I ] ) ) and
        not StartsText( '<Import ', TrimLeft( InLines[ I ] ) ) do
      begin
        Middle.Add( InLines[ I ] );
        Inc( I );
      end;

      // 4. Parse the target region into blocks, up to the <Import> / EOF.
      while ( I < InLines.Count ) and not StartsText( '<Import ', TrimLeft( InLines[ I ] ) ) do
      begin
        var Line    := InLines[ I ];
        if not StartsText( '<Target Name="', TrimLeft( Line ) ) then
        begin
          // Blank lines and comments travel with the target that follows them.
          Pending.Add( Line );
          Inc( I );
          Continue;
        end;

        Block       := Default( TTargetBlock );
        Block.Name  := AttributeValue( Line, 'Name' );
        Block.Owner := -1;
        var BlockLines := TList<string>.Create;
        try
          BlockLines.AddRange( Pending );
          Pending.Clear;
          var Closed := EndsText( '/>', TrimRight( Line ) );
          BlockLines.Add( Line );
          Inc( I );
          while ( I < InLines.Count ) and not Closed do
          begin
            BlockLines.Add( InLines[ I ] );
            if ( Block.ProjectInclude = '' ) and ( Pos( '<MSBuild ', InLines[ I ] ) > 0 ) then
              Block.ProjectInclude := AttributeValue( InLines[ I ], 'Projects' );
            Closed  := SameText( Trim( InLines[ I ] ), '</Target>' );
            Inc( I );
          end;
          if not Closed then
            raise EGroupProjSortError.CreateFmt( 'The <Target Name="%s"> element is not closed.', [ Block.Name ] );
          Block.Lines := BlockLines.ToArray;
        finally
          BlockLines.Free;
        end;
        Blocks.Add( Block );
      end;

      // 5. Assign each per-project target block to its project, by the project path it builds.
      for var B := 0 to Blocks.Count - 1 do
      begin
        Block       := Blocks[ B ];
        if ( Block.ProjectInclude = '' ) then
          Continue;
        for var E := 0 to Entries.Count - 1 do
          if SameText( Entries[ E ].Include, Block.ProjectInclude ) then
          begin
            Block.Owner := E;
            Blocks[ B ] := Block;
            Entry   := Entries[ E ];
            if ( Entry.TargetName = '' ) then
            begin
              Entry.TargetName := BaseTargetName( Block.Name );
              Entries[ E ] := Entry;
            end;
            Break;
          end;
      end;

      // 6. Sort the member projects by name (case-insensitive, ordinal, stable).
      Entries.Sort( TComparer<TProjEntry>.Construct(
          function( const L, R: TProjEntry ): Integer
          begin
            Result  := CompareStr( LowerCase( L.Name ), LowerCase( R.Name ) );
            if ( Result = 0 ) then
              Result := L.Index - R.Index;
          end ) );

      // 7. Emit the sorted <Projects> blocks and the middle.
      for Entry in Entries do
        OutLines.AddStrings( Entry.Lines );
      OutLines.AddStrings( Middle.ToArray );
    finally
      Middle.Free;
    end;

    // 8. Emit the target region: the project-owned blocks, moved as a group in the
    //    sorted order at the position of the first one; every other block verbatim
    //    where it stood, with only the CallTarget name lists reordered.
    var ProjectBlocksEmitted := False;
    for var B := 0 to Blocks.Count - 1 do
    begin
      Block         := Blocks[ B ];
      if ( Block.Owner >= 0 ) then
      begin
        if ProjectBlocksEmitted then
          Continue;
        ProjectBlocksEmitted := True;
        for Entry in Entries do
          for var K := 0 to Blocks.Count - 1 do
            if ( Blocks[ K ].Owner = Entry.Index ) then
              OutLines.AddStrings( Blocks[ K ].Lines );
        Continue;
      end;

      for var Line in Block.Lines do
        if ( Pos( '<CallTarget ', Line ) > 0 ) then
          OutLines.Add( ReorderCallTargets( Line, Entries ) )
        else
          OutLines.Add( Line );
    end;
    OutLines.AddStrings( Pending.ToArray );

    // 9. Copy the remainder (<Import .../>, </Project>, ...).
    while ( I < InLines.Count ) do
    begin
      OutLines.Add( InLines[ I ] );
      Inc( I );
    end;

    // A sort moves lines; it never adds, drops or edits one (CallTarget lists apart).
    if not IsPermutation( InLines, OutLines ) then
      raise EGroupProjSortError.Create(
        'The sorted project group would not contain exactly the original lines; nothing was changed.' );

    Result          := OutLines.Text;
    if ( AText <> '' ) and not CharInSet( AText[ Length( AText ) ], [ #10, #13 ] ) then
      SetLength( Result, Length( Result ) - Length( OutLines.LineBreak ) );
  finally
    Pending.Free;
    Blocks.Free;
    Entries.Free;
    OutLines.Free;
    InLines.Free;
  end;
end;

end.

