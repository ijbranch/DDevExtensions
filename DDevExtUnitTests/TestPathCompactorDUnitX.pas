unit TestPathCompactorDUnitX;

/// <summary>
/// DUnitX test fixture for <c>PathCompactorCore</c> — the RTL-only analysis
/// behind the IDE Path Compactor. Covers macro expansion, segment-boundary
/// matching, candidate scoring in stored space, variable naming, hygiene
/// detection and the two whole-fixture invariants (stored length never grows,
/// and the expanded path set round-trips).
/// </summary>
/// <remarks>
/// The core takes its macro table from the caller and never touches the
/// registry, so every test here runs against a plain <c>TStringList</c> with no
/// IDE present. Existence probing is switched off throughout — these fixtures
/// describe directory layouts that do not exist on the test machine.
/// </remarks>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising the path compactor core.</summary>
  [TestFixture]
  TTestPathCompactor = class
  public
    /// <summary>An unknown macro is left intact and terminates the pass.</summary>
    [Test]
    procedure TestUnknownMacroLeftIntact;
    /// <summary>A self-referential macro hits the depth cap instead of hanging.</summary>
    [Test]
    procedure TestSelfReferentialMacroTerminates;
    /// <summary>A prefix only matches at a directory-separator boundary.</summary>
    [Test]
    procedure TestSegmentBoundaryMatching;
    /// <summary>Nested prefixes: the rewrite applies the longest accepted prefix.</summary>
    [Test]
    procedure TestNestedPrefixesUseLongestAccepted;
    /// <summary>An entry containing $(Config) survives byte-for-byte and is never deduplicated.</summary>
    [Test]
    procedure TestOpaqueEntrySurvivesUnchanged;
    /// <summary>Duplicate detection is case-insensitive and ignores a trailing separator.</summary>
    [Test]
    procedure TestDuplicateDetectionNormalises;
    /// <summary>A name colliding with an existing variable of a different value gains a suffix.</summary>
    [Test]
    procedure TestNameCollisionWithExistingVariable;
    /// <summary>An existing variable equal to the candidate prefix is reused, not redefined.</summary>
    [Test]
    procedure TestExistingVariableReused;
    /// <summary>A derived name colliding with a reserved built-in is renamed.</summary>
    [Test]
    procedure TestReservedNameIsNeverEmitted;
    /// <summary>Output entry count equals input count minus intentional drops.</summary>
    [Test]
    procedure TestEntryCountPreserved;
    /// <summary>A platform or config token never becomes a variable name on its own.</summary>
    [Test]
    procedure TestPlatformTokenNaming;
    /// <summary>An entry already stored as a macro is not re-expressed under a new one.</summary>
    [Test]
    procedure TestAlreadyMacroisedEntryNotLengthened;
    /// <summary>A candidate equal to a built-in's value is emitted as that built-in.</summary>
    [Test]
    procedure TestBuiltInMacroPreferredOverNewVariable;
    /// <summary>Namespace Prefixes is refused by the core, not merely hidden by the dialog.</summary>
    [Test]
    procedure TestNamespacePrefixesRefused;
    /// <summary>The supplied macro table is never modified.</summary>
    [Test]
    procedure TestMacroTableNotModified;
    /// <summary>Stored length never increases, on a fixture designed to tempt it.</summary>
    [Test]
    procedure TestStoredLengthNeverIncreases;
    /// <summary>Duplicate removal is off by default: reported, but nothing dropped.</summary>
    [Test]
    procedure TestDuplicateRemovalIsOptIn;
    /// <summary>A dead macro reference is removable; a divergent one never is.</summary>
    [Test]
    procedure TestDeadMacroRemovableButDivergentIsNot;
    /// <summary>Revalidation rescues an entry whose macro resolves by the time Apply runs.</summary>
    [Test]
    procedure TestRevalidateRescuesResolvedMacro;
    /// <summary>An entry that will be removed does not vote for a macro variable.</summary>
    [Test]
    procedure TestDroppedEntriesDoNotVoteForVariables;
    /// <summary>Analyse then rewrite then expand yields the original expanded set.</summary>
    [Test]
    procedure TestRoundTripInvariant;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.StrUtils,
  PathCompactorCore;

const
  BdsDir = 'C:\Program Files (x86)\Embarcadero\Studio\37.0';

/// <summary>Builds a macro table holding just the entries the fixtures need.</summary>
function MakeMacros( const APairs: array of string ): TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  Result.NameValueSeparator := '=';
  for I := Low( APairs ) to High( APairs ) do
    Result.Add( APairs[I] );
end;

/// <summary>Creates an analysis wired to AMacros with existence probing off.</summary>
function MakeAnalysis( AMacros: TStrings ): TPathCompactorAnalysis;
begin
  Result := TPathCompactorAnalysis.Create;
  Result.SetMacros( AMacros );
  Result.CheckExistence := False;
end;

/// <summary>
/// Returns the expansion the analysis recorded from the ORIGINAL raw text, one
/// surviving entry per line. Never derived from NewRaw, or the round-trip test
/// would be comparing the rewrite against itself.
/// </summary>
function OriginalExpandedOf( APathSet: TPathSet ): string;
var
  Entries: TArray<TPathEntry>;
  I: Integer;
  Text: string;
begin
  Text := '';
  Entries := APathSet.Entries;
  for I := Low( Entries ) to High( Entries ) do
  begin
    if Entries[I].Drop then
      Continue;
    if Text <> '' then
      Text := Text + sLineBreak;
    if Entries[I].Expanded <> '' then
      Text := Text + Entries[I].Expanded
    else
      Text := Text + Entries[I].Raw;
  end;
  Result := Text;
end;

/// <summary>Expands the entries as they would be WRITTEN, one surviving entry per line.</summary>
function RewrittenExpandedOf( APathSet: TPathSet; AMacros: TStrings ): string;
var
  Entries: TArray<TPathEntry>;
  I: Integer;
  Text, Effective, Expanded: string;
begin
  Text := '';
  Entries := APathSet.Entries;
  for I := Low( Entries ) to High( Entries ) do
  begin
    if Entries[I].Drop then
      Continue;
    if Text <> '' then
      Text := Text + sLineBreak;

    if Entries[I].NewRaw <> '' then
      Effective := Entries[I].NewRaw
    else
      Effective := Entries[I].Raw;

    Expanded := NormalisePath( ExpandLibraryMacros( Effective, AMacros ) );
    if Expanded <> '' then
      Text := Text + Expanded
    else
      Text := Text + Effective;
  end;
  Result := Text;
end;

/// <summary>
/// Returns AMacros plus every variable the analysis accepted. After Apply those
/// variables exist in the IDE, so the round-trip must resolve them — expanding
/// with the original table alone would leave a newly created macro unresolved
/// and report a false failure.
/// </summary>
function MacrosWithAccepted( AAnalysis: TPathCompactorAnalysis; AMacros: TStrings ): TStringList;
var
  Vars: TArray<TVarCandidate>;
  I: Integer;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  Result.NameValueSeparator := '=';
  Result.Assign( AMacros );

  Vars := AAnalysis.AcceptedVariables;
  for I := Low( Vars ) to High( Vars ) do
    if Result.IndexOfName( Vars[I].Name ) < 0 then
      Result.Add( Vars[I].Name + '=' + Vars[I].Prefix );
end;

/// <summary>Asserts the two invariants every fixture must satisfy.</summary>
procedure AssertInvariants( AAnalysis: TPathCompactorAnalysis; AMacros: TStrings;
  const AOriginalExpanded: array of string );
var
  I: Integer;
  Effective: TStringList;
begin
  // Stored length must never grow. A rewrite that lengthens the registry string
  // is a failure however sound its round-trip.
  Assert.IsTrue( AAnalysis.TotalStoredAfter <= AAnalysis.TotalStoredBefore,
    Format( 'stored length grew: %d -> %d',
      [AAnalysis.TotalStoredBefore, AAnalysis.TotalStoredAfter] ) );

  // The expanded path set must be unchanged, minus intentional drops.
  Effective := MacrosWithAccepted( AAnalysis, AMacros );
  try
    for I := 0 to AAnalysis.Sets.Count - 1 do
      Assert.AreEqual( AOriginalExpanded[I],
        RewrittenExpandedOf( AAnalysis.Sets[I], Effective ),
        'round-trip changed the expanded path set' );
  finally
    Effective.Free;
  end;
end;

{ TTestPathCompactor }

procedure TTestPathCompactor.TestUnknownMacroLeftIntact;
var
  Macros: TStringList;
begin
  Macros := MakeMacros( ['BDS=' + BdsDir] );
  try
    // Deliberately unlike IDEUtils.ExpandDirMacros, which DELETES the macro and
    // silently produces a bare "\x".
    Assert.AreEqual( '$(NOPE)\x', ExpandLibraryMacros( '$(NOPE)\x', Macros ) );
  finally
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestSelfReferentialMacroTerminates;
var
  Macros: TStringList;
  Value: string;
begin
  Macros := MakeMacros( ['A=$(A)\x'] );
  try
    // The point of this test is that it returns at all.
    Value := ExpandLibraryMacros( '$(A)', Macros, 8 );
    Assert.IsTrue( Pos( '$(', Value ) > 0,
      'the depth cap should leave the cycle unresolved rather than hang' );
  finally
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestSegmentBoundaryMatching;
begin
  Assert.IsFalse( StartsWithSegment( 'D:\Library\Foo', 'D:\Lib' ),
    'D:\Lib must not match D:\Library\Foo' );
  Assert.IsTrue( StartsWithSegment( 'D:\Lib\Foo', 'D:\Lib' ) );
  Assert.IsTrue( StartsWithSegment( 'D:\Lib', 'D:\Lib' ) );
end;

procedure TTestPathCompactor.TestNestedPrefixesUseLongestAccepted;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
  Entries: TArray<TPathEntry>;
  I: Integer;
  Found: Boolean;
begin
  Macros := MakeMacros( [] );
  Analysis := MakeAnalysis( Macros );
  try
    // A low threshold so both nesting levels are taken: the outer prefix first
    // (it covers every entry), then the inner one on its incremental gain.
    Analysis.MinNetSaving := 5;
    Analysis.AddPathSet( 'Win64', lptSearchPath,
      'D:\Vendor\Framework\Core\Alpha;D:\Vendor\Framework\Core\Beta;' +
      'D:\Vendor\Framework\Core\Gamma;D:\Vendor\Framework\Core\Delta;' +
      'D:\Vendor\Framework\Core\Epsilon;D:\Vendor\Framework\Core\Zeta;' +
      'D:\Vendor\Framework\Extras\One;D:\Vendor\Framework\Extras\Two;' +
      'D:\Vendor\Framework\Extras\Three;D:\Vendor\Framework\Extras\Four' );
    Analysis.Analyse;

    // An entry must be rewritten under the LONGEST accepted prefix that matches
    // it, never a shorter ancestor — so a Core entry becomes $(CORE)\Alpha and
    // not $(FRAMEWORK)\Core\Alpha.
    Entries := Analysis.Sets[0].Entries;
    Found := False;
    for I := Low( Entries ) to High( Entries ) do
      if SameText( Entries[I].Raw, 'D:\Vendor\Framework\Core\Alpha' ) then
      begin
        Found := True;
        Assert.AreEqual( '$(CORE)\Alpha', Entries[I].NewRaw,
          'the longest accepted prefix should have absorbed the Core segment' );
      end;

    Assert.IsTrue( Found, 'expected the Core\Alpha entry to be present' );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestOpaqueEntrySurvivesUnchanged;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
  Entries: TArray<TPathEntry>;
begin
  Macros := MakeMacros( [] );
  Analysis := MakeAnalysis( Macros );
  try
    Analysis.RemoveDuplicates := True;
    Analysis.AddPathSet( 'Win64', lptSearchPath,
      'D:\Vendor\Suite\Lib\$(Config);D:\Vendor\Suite\Lib\$(Config);' +
      'D:\Vendor\Suite\Lib\Alpha;D:\Vendor\Suite\Lib\Beta' );
    Analysis.Analyse;

    Entries := Analysis.Sets[0].Entries;
    Assert.IsTrue( Entries[0].Opaque, '$(Config) entry must be opaque' );
    Assert.AreEqual( '', Entries[0].NewRaw, 'an opaque entry must not be rewritten' );
    Assert.IsFalse( Entries[1].Duplicate,
      'opaque entries must never be deduplicated — they can differ at build time' );
    Assert.IsFalse( Entries[1].Drop );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestDuplicateDetectionNormalises;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
begin
  Macros := MakeMacros( [] );
  Analysis := MakeAnalysis( Macros );
  try
    Analysis.AddPathSet( 'Win64', lptSearchPath, 'D:\Shared\Units;d:\shared\units\;D:\Other' );
    Analysis.Analyse;

    Assert.AreEqual( 1, Analysis.DuplicateCount,
      'case and a trailing separator must not hide a duplicate' );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestNameCollisionWithExistingVariable;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
  Vars: TArray<TVarCandidate>;
  I: Integer;
begin
  // An existing variable named LIB holding a DIFFERENT value.
  Macros := MakeMacros( ['LIB=D:\Somewhere\Unrelated'] );
  Analysis := MakeAnalysis( Macros );
  try
    Analysis.MinNetSaving := 10;
    Analysis.AddPathSet( 'Win64', lptSearchPath,
      'D:\Vendor\ComponentSuite\Delphi13\Lib\Alpha;' +
      'D:\Vendor\ComponentSuite\Delphi13\Lib\Beta;' +
      'D:\Vendor\ComponentSuite\Delphi13\Lib\Gamma' );
    Analysis.Analyse;

    Vars := Analysis.AcceptedVariables;
    Assert.IsTrue( Length( Vars ) > 0, 'expected a variable to be proposed' );
    for I := Low( Vars ) to High( Vars ) do
      Assert.AreNotEqual( 'LIB', Vars[I].Name,
        'must not reuse the name of an existing variable holding a different value' );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestExistingVariableReused;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
  Vars: TArray<TVarCandidate>;
  I: Integer;
  Reused: Boolean;
begin
  Macros := MakeMacros( ['SUITE=D:\Vendor\ComponentSuite\Delphi13\Lib'] );
  Analysis := MakeAnalysis( Macros );
  try
    Analysis.MinNetSaving := 10;
    Analysis.AddPathSet( 'Win64', lptSearchPath,
      'D:\Vendor\ComponentSuite\Delphi13\Lib\Alpha;' +
      'D:\Vendor\ComponentSuite\Delphi13\Lib\Beta;' +
      'D:\Vendor\ComponentSuite\Delphi13\Lib\Gamma' );
    Analysis.Analyse;

    Vars := Analysis.AcceptedVariables;
    Reused := False;
    for I := Low( Vars ) to High( Vars ) do
      if SameText( Vars[I].Name, 'SUITE' ) then
      begin
        Reused := True;
        Assert.IsTrue( Vars[I].PreExisting,
          'an existing variable of the same value must be flagged PreExisting' );
      end;

    Assert.IsTrue( Reused, 'the existing SUITE variable should have been reused' );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestReservedNameIsNeverEmitted;
var
  Macros, Reserved: TStringList;
  Analysis: TPathCompactorAnalysis;
  Vars: TArray<TVarCandidate>;
  I: Integer;
begin
  Macros := MakeMacros( [] );
  Analysis := MakeAnalysis( Macros );
  Reserved := TStringList.Create;
  try
    Reserved.Add( 'BDS' );
    Analysis.SetReservedNames( Reserved );
    Analysis.MinNetSaving := 10;

    // The trailing segment derives the name "BDS", which is reserved.
    Analysis.AddPathSet( 'Win64', lptSearchPath,
      'D:\Vendor\Tooling\Bds\Alpha;D:\Vendor\Tooling\Bds\Beta;D:\Vendor\Tooling\Bds\Gamma' );
    Analysis.Analyse;

    Vars := Analysis.AcceptedVariables;
    for I := Low( Vars ) to High( Vars ) do
      Assert.AreNotEqual( 'BDS', Vars[I].Name,
        'shadowing an IDE built-in would break path resolution IDE-wide' );
  finally
    Reserved.Free;
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestEntryCountPreserved;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
  Value: string;
  Parts: TArray<string>;
begin
  Macros := MakeMacros( [] );
  Analysis := MakeAnalysis( Macros );
  try
    Analysis.AddPathSet( 'Win64', lptSearchPath,
      'D:\Vendor\Suite\Lib\Alpha;D:\Vendor\Suite\Lib\Beta;D:\Vendor\Suite\Lib\Gamma' );
    Analysis.Analyse;

    Value := Analysis.Sets[0].BuildResult;
    Parts := Value.Split( [';'] );
    Assert.AreEqual( 3, Integer( Length( Parts ) ), 'no entry may be lost while rebuilding' );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestPlatformTokenNaming;
begin
  // The last-segment rule alone would produce the misleading WIN32 / RELEASE.
  Assert.AreEqual( 'DCP_WIN32', DeriveVariableName( 'D:\Build\Output\Dcp\Win32' ) );
  Assert.AreEqual( 'BPL_WIN64', DeriveVariableName( 'D:\Build\Output\Bpl\Win64' ) );
  // Recurses while the newly leading segment is itself a token.
  Assert.AreEqual( 'OUT_WIN64_RELEAS', DeriveVariableName( 'D:\Build\Out\Win64\Release' ) );
end;

procedure TTestPathCompactor.TestAlreadyMacroisedEntryNotLengthened;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
  Entries: TArray<TPathEntry>;
  I: Integer;
begin
  Macros := MakeMacros( ['BDS=' + BdsDir] );
  Analysis := MakeAnalysis( Macros );
  try
    // Every entry is already stored as $(BDS)\... — scoring in EXPANDED space
    // would rank the Studio directory top and rewrite all of them LONGER while
    // reporting a large saving. This is the regression test for that defect.
    Analysis.AddPathSet( 'Win64', lptSearchPath,
      '$(BDS)\source\rtl;$(BDS)\source\vcl;$(BDS)\source\fmx;$(BDS)\source\soap;' +
      '$(BDS)\source\databinding;$(BDS)\source\Indy10' );
    Analysis.Analyse;

    Assert.IsTrue( Analysis.TotalStoredAfter <= Analysis.TotalStoredBefore,
      'already-macroised entries must never be made longer' );

    Entries := Analysis.Sets[0].Entries;
    for I := Low( Entries ) to High( Entries ) do
      if Entries[I].NewRaw <> '' then
        Assert.IsTrue( Length( Entries[I].NewRaw ) < Length( Entries[I].Raw ),
          'a rewrite must be shorter than what it replaces: ' + Entries[I].Raw +
          ' -> ' + Entries[I].NewRaw );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestBuiltInMacroPreferredOverNewVariable;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
  Vars: TArray<TVarCandidate>;
  I: Integer;
  UsedBds: Boolean;
begin
  Macros := MakeMacros( ['BDS=' + BdsDir] );
  Analysis := MakeAnalysis( Macros );
  try
    Analysis.MinNetSaving := 10;
    // Stored as literals directly under the Studio directory, with no common
    // sub-directory below it — so $(BDS) is the only viable prefix and the win
    // is to reuse the built-in rather than invent a second name for it.
    Analysis.AddPathSet( 'Win64', lptSearchPath,
      BdsDir + '\source;' + BdsDir + '\lib;' + BdsDir + '\include;' + BdsDir + '\bin' );
    Analysis.Analyse;

    Vars := Analysis.AcceptedVariables;
    UsedBds := False;
    for I := Low( Vars ) to High( Vars ) do
      if SameText( Vars[I].Name, 'BDS' ) then
      begin
        UsedBds := True;
        Assert.IsTrue( Vars[I].PreExisting, 'a built-in must be flagged PreExisting' );
      end;

    Assert.IsTrue( UsedBds, 'the existing $(BDS) built-in should have been used' );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestNamespacePrefixesRefused;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
  Raised: Boolean;
begin
  Macros := MakeMacros( [] );
  Analysis := MakeAnalysis( Macros );
  try
    // Enforced in the core, not just omitted from the dialog: a stale config
    // must not be able to reach the compactor with this path type.
    Raised := False;
    try
      Analysis.AddPathSet( 'Win64', lptNamespacePrefixes, 'Vcl;System;Winapi' );
    except
      on E: EPathCompactorError do
        Raised := True;
    end;
    Assert.IsTrue( Raised,
      'the core must refuse Namespace Prefixes, not merely have the dialog hide it' );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestMacroTableNotModified;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
  Before: string;
begin
  Macros := MakeMacros( ['BDS=' + BdsDir, 'SUITE=D:\Vendor\Suite'] );
  Analysis := MakeAnalysis( Macros );
  try
    Before := Macros.Text;
    Analysis.MinNetSaving := 10;
    Analysis.AddPathSet( 'Win64', lptSearchPath,
      'D:\Vendor\Suite\Alpha;D:\Vendor\Suite\Beta;D:\Vendor\Suite\Gamma' );
    Analysis.Analyse;

    // The compactor only ever ADDS names; it never edits an existing variable's
    // value. That is what makes "remove created variables" safe.
    Assert.AreEqual( Before, Macros.Text, 'the supplied macro table must not be modified' );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestStoredLengthNeverIncreases;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
  Original: TArray<string>;
  I: Integer;
begin
  Macros := MakeMacros( ['BDS=' + BdsDir] );
  Analysis := MakeAnalysis( Macros );
  try
    Analysis.MinNetSaving := 10;
    // A deliberately mixed fixture: already-macroised entries alongside long
    // literals, which is the shape that tempts the wrong scoring.
    Analysis.AddPathSet( 'Win64', lptSearchPath,
      '$(BDS)\source\rtl;$(BDS)\source\vcl;' +
      'D:\Vendor\ComponentSuite\Delphi13\Lib\Alpha;' +
      'D:\Vendor\ComponentSuite\Delphi13\Lib\Beta;' +
      'D:\Vendor\ComponentSuite\Delphi13\Lib\Gamma' );
    Analysis.AddPathSet( 'Win32', lptBrowsingPath,
      'D:\Vendor\ComponentSuite\Delphi13\Lib\Delta;$(BDS)\source\fmx' );
    Analysis.Analyse;

    SetLength( Original, Analysis.Sets.Count );
    for I := 0 to Analysis.Sets.Count - 1 do
      Original[I] := OriginalExpandedOf( Analysis.Sets[I] );

    AssertInvariants( Analysis, Macros, Original );
    Assert.IsTrue( Analysis.TotalStoredAfter < Analysis.TotalStoredBefore,
      'this fixture should genuinely compact' );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestDuplicateRemovalIsOptIn;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
  Parts: TArray<string>;
begin
  Macros := MakeMacros( [] );
  Analysis := MakeAnalysis( Macros );
  try
    // RemoveDuplicates defaults to False: detection is always on, removal is not.
    Assert.IsFalse( Analysis.RemoveDuplicates, 'duplicate removal must default to off' );

    Analysis.AddPathSet( 'Win64', lptSearchPath, 'D:\Shared\Units;D:\Shared\Units;D:\Other' );
    Analysis.Analyse;

    Assert.AreEqual( 1, Analysis.DuplicateCount, 'the duplicate must still be reported' );

    Parts := Analysis.Sets[0].BuildResult.Split( [';'] );
    Assert.AreEqual( 3, Integer( Length( Parts ) ),
      'nothing may be dropped while removal is off' );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestDeadMacroRemovableButDivergentIsNot;
var
  Macros, Divergent: TStringList;
  Analysis: TPathCompactorAnalysis;
  Entries: TArray<TPathEntry>;
begin
  Macros := MakeMacros( [] );
  Analysis := MakeAnalysis( Macros );
  Divergent := TStringList.Create;
  try
    // DUNITX is defined in the OTHER IDE bitness only, so the entry is live
    // there; NOPE is defined nowhere at all.
    Divergent.Add( 'DUNITX' );
    Analysis.SetDivergentNames( Divergent );
    Analysis.RemoveUndefinedMacros := True;

    Analysis.AddPathSet( 'Win64', lptSearchPath, '$(DUNITX);$(NOPE)\Lib;D:\Real\Path' );
    Analysis.Analyse;

    Entries := Analysis.Sets[0].Entries;

    Assert.IsTrue( Entries[0].DivergentMacro, '$(DUNITX) should be divergent' );
    Assert.IsFalse( Entries[0].UndefinedMacro, 'a divergent macro is not dead' );
    Assert.IsFalse( Entries[0].Drop,
      'a divergent entry must never be removed - it resolves in the other IDE' );

    Assert.IsTrue( Entries[1].UndefinedMacro, '$(NOPE) resolves nowhere' );
    Assert.IsTrue( Entries[1].Drop, 'a dead macro reference should be removable' );

    Assert.AreEqual( 1, Analysis.DivergentMacroCount );
    Assert.AreEqual( 1, Analysis.UndefinedMacroCount );
    Assert.AreEqual( 1, Analysis.DropCount );
  finally
    Divergent.Free;
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestRevalidateRescuesResolvedMacro;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
  Rescued: Integer;
begin
  Macros := MakeMacros( [] );
  Analysis := MakeAnalysis( Macros );
  try
    Analysis.RemoveUndefinedMacros := True;
    Analysis.AddPathSet( 'Win64', lptSearchPath, '$(LATER)\Lib;D:\Real\Path' );
    Analysis.Analyse;
    Assert.AreEqual( 1, Analysis.DropCount, 'the dead entry should be marked' );

    // The variable comes into existence between Analyse and Apply - a share
    // reconnects, an installer finishes. Nothing may be deleted on a stale probe.
    Macros.Add( 'LATER=D:\Now\Defined' );
    Analysis.SetMacros( Macros );

    Rescued := Analysis.RevalidateDrops;
    Assert.AreEqual( 1, Rescued, 'the entry should have been rescued' );
    Assert.AreEqual( 0, Analysis.DropCount, 'nothing should remain marked' );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestDroppedEntriesDoNotVoteForVariables;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
  Vars: TArray<TVarCandidate>;
  I: Integer;
begin
  Macros := MakeMacros( [] );
  Analysis := MakeAnalysis( Macros );
  try
    // Only ONE surviving entry sits under this prefix; the other two are exact
    // duplicates that hygiene will drop. Before hygiene ran ahead of candidate
    // selection, the prefix scored three uses and won a variable whose users
    // then vanished - an orphaned variable and an overstated saving.
    Analysis.RemoveDuplicates := True;
    Analysis.MinOccurrences := 2;
    Analysis.MinNetSaving := 5;
    Analysis.AddPathSet( 'Win64', lptSearchPath,
      'D:\Vendor\ComponentSuite\Delphi13\Lib\Alpha;' +
      'D:\Vendor\ComponentSuite\Delphi13\Lib\Alpha;' +
      'D:\Vendor\ComponentSuite\Delphi13\Lib\Alpha;' +
      'D:\Elsewhere\Thing' );
    Analysis.Analyse;

    Assert.AreEqual( 2, Analysis.DropCount, 'the two duplicates should be dropped' );

    Vars := Analysis.AcceptedVariables;
    for I := Low( Vars ) to High( Vars ) do
      Assert.IsFalse( ContainsText( Vars[I].Prefix, 'ComponentSuite' ),
        'a prefix used by only one surviving entry must not become a variable' );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

procedure TTestPathCompactor.TestRoundTripInvariant;
var
  Macros: TStringList;
  Analysis: TPathCompactorAnalysis;
  Original: TArray<string>;
  I: Integer;
begin
  Macros := MakeMacros( ['BDS=' + BdsDir, 'SUITE=D:\Vendor\ComponentSuite\Delphi13\Lib'] );
  Analysis := MakeAnalysis( Macros );
  try
    Analysis.MinNetSaving := 10;
    Analysis.AddPathSet( 'Win64', lptSearchPath,
      '$(BDS)\source\rtl;D:\Vendor\ComponentSuite\Delphi13\Lib\Alpha;' +
      'D:\Vendor\ComponentSuite\Delphi13\Lib\Beta;D:\Vendor\Other\Thing;' +
      'D:\Vendor\Suite\Lib\$(Config)' );
    Analysis.Analyse;

    SetLength( Original, Analysis.Sets.Count );
    for I := 0 to Analysis.Sets.Count - 1 do
      Original[I] := OriginalExpandedOf( Analysis.Sets[I] );

    AssertInvariants( Analysis, Macros, Original );
  finally
    Analysis.Free;
    Macros.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestPathCompactor );

end.
