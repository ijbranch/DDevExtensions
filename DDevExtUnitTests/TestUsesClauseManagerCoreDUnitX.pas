unit TestUsesClauseManagerCoreDUnitX;

/// <summary>
/// DUnitX test fixtures for <c>UsesClauseManagerCore</c> — the RTL-only analysis behind the
/// Uses Clause Manager. Covers the exports database, the interface/implementation identifier
/// usage analyser, and the placement recommendations and source rewrite built on top of them.
/// </summary>
/// <remarks>
/// The core takes its source as text rather than as a file name, and its scan directories from
/// the caller, so every test here runs with no IDE, no project and nothing on disk.
///
/// <c>TUsesClauseRefactorer.Analyze</c> hands the caller two owned <c>TStringList</c> instances
/// per placement, so every test that calls it disposes of them through <c>FreePlacements</c>.
/// The FastMM5 leak gate in the runner turns a missed one into a failure.
/// </remarks>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising the unit exports database.</summary>
  [ TestFixture ]
  TTestUnitExportsDatabase = class
  public
    /// <summary>Constants declared in the interface are recorded as ekConst.</summary>
    [ Test ]
    procedure TestInterfaceConstIsExported;
    /// <summary>Procedures and functions are recorded with their own kinds.</summary>
    [ Test ]
    procedure TestRoutineKindsAreDistinguished;
    /// <summary>Declarations below the implementation keyword are not exported.</summary>
    [ Test ]
    procedure TestImplementationDeclarationsAreNotExported;
    /// <summary>A const or var PARAMETER must not be read as a section keyword, or the
    /// routine's return type is recorded as an export of the unit.</summary>
    [ Test ]
    procedure TestParameterModifiersDoNotLeakIntoSectionState;
    /// <summary>A unit that exports nothing is not added to the database.</summary>
    [ Test ]
    procedure TestUnitWithNoExportsIsNotStored;
    /// <summary>Unit lookup ignores the case of the supplied name.</summary>
    [ Test ]
    procedure TestGetExportsIsCaseInsensitive;
    /// <summary>The reverse lookup maps an identifier back to its declaring unit.</summary>
    [ Test ]
    procedure TestFindUnitsForIdentifier;
    /// <summary>An identifier nothing declares resolves to nil, not an empty list.</summary>
    [ Test ]
    procedure TestFindUnitsForUnknownIdentifierReturnsNil;
    /// <summary>With one candidate, that candidate is preferred.</summary>
    [ Test ]
    procedure TestGetPreferredUnitWithSingleCandidate;
    /// <summary>An RTL/VCL unit outranks a project unit declaring the same identifier.</summary>
    [ Test ]
    procedure TestGetPreferredUnitHonoursRTLPriority;
    /// <summary>An empty candidate list yields an empty result rather than raising.</summary>
    [ Test ]
    procedure TestGetPreferredUnitWithNoCandidates;
    /// <summary>Clear empties both the exports and the reverse lookup.</summary>
    [ Test ]
    procedure TestClearEmptiesDatabase;
    /// <summary>Scanning a path that does not exist is a no-op, not an exception.</summary>
    [ Test ]
    procedure TestScanUnitOfMissingFileIsSilent;
    /// <summary>A nil directory list is tolerated and simply clears the database.</summary>
    [ Test ]
    procedure TestBuildFromDirectoriesAcceptsNil;
    /// <summary>
    /// Proves a second unit of a name already scanned is skipped, not added: the first one found
    /// wins, as it does for the compiler.  It used to raise EListError out of Build Database.
    /// </summary>
    [ Test ]
    procedure TestDuplicateUnitNameFirstOneWins;
    /// <summary>
    /// Proves only declared type names are exported: field types, field and member names,
    /// parameter types and generic parameters inside a type body are not, and the scan resumes
    /// correctly after a forward class, a generic record and a procedural type.
    /// </summary>
    [ Test ]
    procedure TestFieldAndMemberNamesAreNotExported;
    /// <summary>Proves every name of a "A, B: Integer" var list is exported, and the type is not.</summary>
    [ Test ]
    procedure TestVarListNamesAreExported;
    /// <summary>
    /// Proves BuildFromDirectories resolves a relative entry against the base directory, scans a
    /// repeated directory once, and keeps the first unit of a name when two directories hold one.
    /// </summary>
    [ Test ]
    procedure TestBuildFromDirectoriesResolvesRelativeAndSkipsRepeats;
    /// <summary>Proves ResolveDirectory makes a relative entry absolute under the base and leaves an absolute one alone.</summary>
    [ Test ]
    procedure TestResolveDirectory;
    /// <summary>Proves the values of an enumerated type are exported ( fsBold, and one with an explicit ordinal ), not only the type.</summary>
    [ Test ]
    procedure TestEnumValuesAreExported;
  end;

  /// <summary>DUnitX test fixture exercising the identifier usage analyser.</summary>
  [ TestFixture ]
  TTestIdentifierUsageAnalyzer = class
  public
    /// <summary>Units listed in the interface uses clause are captured with that section.</summary>
    [ Test ]
    procedure TestInterfaceUsesAreCaptured;
    /// <summary>Units listed in the implementation uses clause are captured separately.</summary>
    [ Test ]
    procedure TestImplementationUsesAreCaptured;
    /// <summary>An identifier appearing in the interface is recorded against the interface.</summary>
    [ Test ]
    procedure TestInterfaceIdentifierIsRecorded;
    /// <summary>An identifier appearing only below implementation is recorded there.</summary>
    [ Test ]
    procedure TestImplementationIdentifierIsRecorded;
    /// <summary>A qualified Unit.Identifier reference records its qualifying unit.</summary>
    [ Test ]
    procedure TestQualifiedReferenceIsRecorded;
    /// <summary>Clear resets every collection so the analyser can be reused.</summary>
    [ Test ]
    procedure TestClearResetsAllCollections;
  end;

  /// <summary>DUnitX test fixture exercising placement recommendations and the rewrite.</summary>
  [ TestFixture ]
  TTestUsesClauseRefactorer = class
  public
    /// <summary>A unit in the interface clause used only below implementation should move down.</summary>
    [ Test ]
    procedure TestInterfaceUnitUsedOnlyInImplementationMovesDown;
    /// <summary>A unit genuinely used in the interface stays in the interface.</summary>
    [ Test ]
    procedure TestInterfaceUnitUsedInInterfaceStays;
    /// <summary>A unit with no detected usage is left alone and flagged for review.</summary>
    [ Test ]
    procedure TestUnusedUnitIsFlaggedForReview;
    /// <summary>A unit in the implementation clause whose identifiers appear in the interface moves up.</summary>
    [ Test ]
    procedure TestImplementationUnitUsedInInterfaceMovesUp;
    /// <summary>The rewritten source really does relocate the unit between the two clauses.</summary>
    [ Test ]
    procedure TestGenerateRefactoredSourceRelocatesUnit;
    /// <summary>Analysing a source with no uses clause at all yields no placements.</summary>
    [ Test ]
    procedure TestSourceWithoutUsesClauseYieldsNoPlacements;
    /// <summary>
    /// Proves a move edits only the moved entry: a {$IFDEF} block and a comment in the same clause
    /// survive byte for byte, and a missing implementation clause is created.
    /// </summary>
    [ Test ]
    procedure TestConditionalBlockAndCommentSurviveAMove;
    /// <summary>Proves a unit inside a {$IFDEF} block is refused, with the source unchanged and the reason given.</summary>
    [ Test ]
    procedure TestEntryInsideConditionalIsRefused;
    /// <summary>Proves an entry's "in '...'" path moves with it instead of being dropped.</summary>
    [ Test ]
    procedure TestInPathMovesWithItsEntry;
    /// <summary>Proves placements whose unit has since left the clause are refused, not applied blindly.</summary>
    [ Test ]
    procedure TestStalePlacementsAreRefused;
    /// <summary>Proves a unit added to the clause after the analysis survives the rewrite ( it used to be deleted ).</summary>
    [ Test ]
    procedure TestUnitAddedAfterAnalysisSurvives;
    /// <summary>
    /// Proves moving a unit up into an interface with no uses clause creates the clause, and the
    /// emptied implementation clause is removed ( the unit used to vanish from both ).
    /// </summary>
    [ Test ]
    procedure TestMoveUpCreatesInterfaceClause;
    /// <summary>Proves multi-byte UTF-8 text before the clauses does not shift the edits ( byte offsets ).</summary>
    [ Test ]
    procedure TestNonAsciiBeforeClausesKeepsOffsets;
    /// <summary>Proves a dotted unit name moves intact and is found in the database by its full name.</summary>
    [ Test ]
    procedure TestDottedNameMovesIntact;
    /// <summary>Proves an entry appended to a clause whose line would pass 160 characters starts a new line.</summary>
    [ Test ]
    procedure TestLongTargetClauseWraps;
    /// <summary>Proves a program source ( no interface or implementation ) is refused with a reason.</summary>
    [ Test ]
    procedure TestProgramSourceIsRefused;
    /// <summary>
    /// Proves an implementation unit is not recommended for the interface because one of its
    /// classes has an Integer field and the interface uses Integer ( the field type was exported ).
    /// </summary>
    [ Test ]
    procedure TestFieldTypeDoesNotPullUnitIntoInterface;
    /// <summary>
    /// Proves an implementation unit is not recommended for the interface when the interface
    /// reaches the identifier through another unit ( Other.TThing ).
    /// </summary>
    [ Test ]
    procedure TestQualifiedReferenceToAnotherUnitDoesNotCount;
    /// <summary>
    /// Proves a unit whose only interface use is an enumeration value ( [fsBold] ) stays in the
    /// interface clause; moving it down made the interface fail to compile ( E2003 ).
    /// </summary>
    [ Test ]
    procedure TestEnumValueKeepsUnitInInterface;
    /// <summary>
    /// Proves an "IFoo = interface" type in the implementation section does not switch the analyser
    /// back to the interface section.
    /// </summary>
    [ Test ]
    procedure TestInterfaceTypeInImplementationKeepsSection;
    /// <summary>Proves no uses clause is created after an include directive that may hold the section's clause.</summary>
    [ Test ]
    procedure TestIncludeBeforeSectionIsRefused;
    /// <summary>Proves text inserted into an LF-only buffer uses LF, not CRLF.</summary>
    [ Test ]
    procedure TestLineFeedBufferGetsLineFeeds;
    /// <summary>Proves a trailing "//" comment on a removed entry's own line goes with the entry.</summary>
    [ Test ]
    procedure TestTrailingLineCommentGoesWithItsEntry;
    /// <summary>Proves a trailing "//" comment that shares its line with more than the entry makes the move refuse.</summary>
    [ Test ]
    procedure TestTrailingLineCommentOnSharedLineIsRefused;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.IOUtils,
  UsesClauseManagerCore;

{ ---------------------------------------------------------------------------
  Helpers
  --------------------------------------------------------------------------- }

/// <summary>Joins the supplied lines with CRLF and returns them as UTF-8 source text.</summary>
function Src( const ALines: array of string ): UTF8String;
var
  sb                : TStringBuilder;
  I                 : Integer;
begin
  sb                := TStringBuilder.Create;
  try
    for I := Low( ALines ) to High( ALines ) do
      sb.Append( ALines[ I ] ).Append( sLineBreak );
    Result          := UTF8Encode( sb.ToString );
  finally
    sb.Free;
  end;
end;

/// <summary>Releases the two TStringList instances each placement hands to the caller.</summary>
procedure FreePlacements( const APlacements: TArray<TUnitPlacement> );
var
  P                 : TUnitPlacement;
begin
  for P in APlacements do
  begin
    P.IdentifiersUsedInInterface.Free;
    P.IdentifiersUsedInImplementation.Free;
  end;
end;

/// <summary>Finds the placement for a named unit; fails the test when it is absent.</summary>
function PlacementFor( const APlacements: TArray<TUnitPlacement>;
  const AUnitName: string ): TUnitPlacement;
var
  P                 : TUnitPlacement;
begin
  for P in APlacements do
    if SameText( P.UnitName, AUnitName ) then
      Exit( P );
  Assert.Fail( 'No placement returned for unit ' + AUnitName );
  Result            := Default( TUnitPlacement );
end;

/// <summary>True when the unit declares the identifier with the given kind.</summary>
function HasExport( ADB: TUnitExportsDatabase; const AUnitName, AIdentifier: string;
  AKind: TExportKind ): Boolean;
var
  L                 : TList<TUnitExport>;
  E                 : TUnitExport;
begin
  Result            := False;
  L                 := ADB.GetExports( AUnitName );
  if L = nil then
    Exit;
  for E in L do
    if SameText( E.Identifier, AIdentifier ) and ( E.Kind = AKind ) then
      Exit( True );
end;

{ TTestUnitExportsDatabase }

procedure TTestUnitExportsDatabase.TestInterfaceConstIsExported;
var
  DB                : TUnitExportsDatabase;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'AppConsts', 'AppConsts.pas', Src( [
          'unit AppConsts;', 'interface', 'const', '  APP_TITLE = 1;', 'implementation', 'end.' ] ) );
    Assert.IsTrue( HasExport( DB, 'AppConsts', 'APP_TITLE', ekConst ),
      'APP_TITLE should be recorded as a const export' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestRoutineKindsAreDistinguished;
var
  DB                : TUnitExportsDatabase;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Helpers', 'Helpers.pas', Src( [
          'unit Helpers;', 'interface',
          'procedure DoThing;',
          'function GetThing: Integer;',
          'implementation', 'end.' ] ) );
    Assert.IsTrue( HasExport( DB, 'Helpers', 'DoThing', ekProcedure ),
      'DoThing should be recorded as a procedure' );
    Assert.IsTrue( HasExport( DB, 'Helpers', 'GetThing', ekFunction ),
      'GetThing should be recorded as a function' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestImplementationDeclarationsAreNotExported;
var
  DB                : TUnitExportsDatabase;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Hidden', 'Hidden.pas', Src( [
          'unit Hidden;', 'interface',
          'const', '  PUBLIC_VALUE = 1;',
          'implementation',
          'const', '  PRIVATE_VALUE = 2;',
          'end.' ] ) );
    Assert.IsTrue( HasExport( DB, 'Hidden', 'PUBLIC_VALUE', ekConst ),
      'the interface constant should be exported' );
    Assert.IsFalse( HasExport( DB, 'Hidden', 'PRIVATE_VALUE', ekConst ),
      'an implementation-section constant must not be exported' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestParameterModifiersDoNotLeakIntoSectionState;
var
  DB                : TUnitExportsDatabase;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Parsing', 'Parsing.pas', Src( [
          'unit Parsing;', 'interface',
          'function ParseValue( const AName: string; var AValue: string ): Boolean;',
          'implementation', 'end.' ] ) );
    Assert.IsTrue( HasExport( DB, 'Parsing', 'ParseValue', ekFunction ),
      'the function itself is exported' );
    Assert.IsFalse( HasExport( DB, 'Parsing', 'Boolean', ekVar ),
      'the return type must NOT be recorded as a var export - the "var AValue" parameter'
      + ' must not put the scanner into a var section' );
    Assert.IsFalse( HasExport( DB, 'Parsing', 'Boolean', ekConst ),
      'nor as a const export, via the "const AName" parameter' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestUnitWithNoExportsIsNotStored;
var
  DB                : TUnitExportsDatabase;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Empty', 'Empty.pas', Src( [
          'unit Empty;', 'interface', 'implementation', 'end.' ] ) );
    Assert.AreEqual( 0, DB.UnitCount, 'a unit with no exports should not be stored' );
    Assert.IsNull( DB.GetExports( 'Empty' ), 'GetExports should return nil for it' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestGetExportsIsCaseInsensitive;
var
  DB                : TUnitExportsDatabase;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'MixedCase', 'MixedCase.pas', Src( [
          'unit MixedCase;', 'interface', 'const', '  VALUE = 1;', 'implementation', 'end.' ] ) );
    Assert.IsNotNull( DB.GetExports( 'MIXEDCASE' ), 'upper-case lookup should succeed' );
    Assert.IsNotNull( DB.GetExports( 'mixedcase' ), 'lower-case lookup should succeed' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestFindUnitsForIdentifier;
var
  DB                : TUnitExportsDatabase;
  Units             : TStringList;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Provider', 'Provider.pas', Src( [
          'unit Provider;', 'interface', 'procedure UniqueRoutine;', 'implementation', 'end.' ] ) );
    Units           := DB.FindUnitsForIdentifier( 'UniqueRoutine' );
    Assert.IsNotNull( Units, 'the identifier should be in the reverse lookup' );
    Assert.IsTrue( Units.IndexOf( 'Provider' ) >= 0, 'Provider should be listed as the declaring unit' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestFindUnitsForUnknownIdentifierReturnsNil;
var
  DB                : TUnitExportsDatabase;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    Assert.IsNull( DB.FindUnitsForIdentifier( 'NothingDeclaresThis' ),
      'an unknown identifier should resolve to nil' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestGetPreferredUnitWithSingleCandidate;
var
  DB                : TUnitExportsDatabase;
  Candidates        : TStringList;
begin
  DB                := TUnitExportsDatabase.Create;
  Candidates        := TStringList.Create;
  try
    Candidates.Add( 'OnlyOption' );
    Assert.AreEqual( 'OnlyOption', DB.GetPreferredUnit( 'Anything', Candidates ), False,
      'the sole candidate should be returned unchanged' );
  finally
    Candidates.Free;
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestGetPreferredUnitHonoursRTLPriority;
var
  DB                : TUnitExportsDatabase;
  Candidates        : TStringList;
begin
  DB                := TUnitExportsDatabase.Create;
  Candidates        := TStringList.Create;
  try
    Candidates.Add( 'MyOwnForms' );
    Candidates.Add( 'Forms' );
    Assert.AreEqual( 'Forms', DB.GetPreferredUnit( 'TForm', Candidates ), False,
      'the RTL/VCL priority list should outrank an unrelated project unit' );
  finally
    Candidates.Free;
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestGetPreferredUnitWithNoCandidates;
var
  DB                : TUnitExportsDatabase;
  Empty             : TStringList;
begin
  DB                := TUnitExportsDatabase.Create;
  Empty             := TStringList.Create;
  try
    Assert.AreEqual( '', DB.GetPreferredUnit( 'Anything', Empty ), False,
      'an empty candidate list should yield an empty result' );
    Assert.AreEqual( '', DB.GetPreferredUnit( 'Anything', nil ), False,
      'a nil candidate list should yield an empty result' );
  finally
    Empty.Free;
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestClearEmptiesDatabase;
var
  DB                : TUnitExportsDatabase;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Provider', 'Provider.pas', Src( [
          'unit Provider;', 'interface', 'procedure UniqueRoutine;', 'implementation', 'end.' ] ) );
    Assert.AreEqual( 1, DB.UnitCount, 'the unit should be stored before Clear' );

    DB.Clear;

    Assert.AreEqual( 0, DB.UnitCount, 'Clear should empty the exports' );
    Assert.IsNull( DB.FindUnitsForIdentifier( 'UniqueRoutine' ),
      'Clear should empty the reverse lookup too' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestScanUnitOfMissingFileIsSilent;
var
  DB                : TUnitExportsDatabase;
  Probe             : TProc;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    Probe           :=
      procedure
      begin
        DB.ScanUnit( 'X:\no\such\directory\NoSuchUnit.pas' );
      end;
    Assert.WillNotRaiseAny( Probe, 'scanning a missing file should be a silent no-op' );
    Assert.AreEqual( 0, DB.UnitCount, 'nothing should have been added' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestBuildFromDirectoriesAcceptsNil;
var
  DB                : TUnitExportsDatabase;
  Probe             : TProc;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Provider', 'Provider.pas', Src( [
          'unit Provider;', 'interface', 'procedure UniqueRoutine;', 'implementation', 'end.' ] ) );
    Probe           :=
      procedure
      begin
        DB.BuildFromDirectories( nil, nil );
      end;
    Assert.WillNotRaiseAny( Probe, 'a nil directory list should be tolerated' );
    Assert.AreEqual( 0, DB.UnitCount, 'it should still have cleared the database' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestDuplicateUnitNameFirstOneWins;
var
  DB                : TUnitExportsDatabase;
  Probe             : TProc;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Utils', 'A\Utils.pas', Src( [
          'unit Utils;', 'interface', 'procedure FromA;', 'implementation', 'end.' ] ) );
    Probe           :=
      procedure
      begin
        DB.ScanSource( 'Utils', 'B\Utils.pas', Src( [
              'unit Utils;', 'interface', 'procedure FromB;', 'implementation', 'end.' ] ) );
      end;
    Assert.WillNotRaiseAny( Probe, 'a second unit of the same name must not raise' );
    Assert.AreEqual( 1, DB.UnitCount, 'the name is stored once' );
    Assert.IsTrue( HasExport( DB, 'Utils', 'FromA', ekProcedure ), 'the first unit found is the one kept' );
    Assert.IsFalse( HasExport( DB, 'Utils', 'FromB', ekProcedure ), 'the second one is skipped' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestFieldAndMemberNamesAreNotExported;
var
  DB                : TUnitExportsDatabase;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Shapes', 'Shapes.pas', Src( [
          'unit Shapes;', 'interface', 'uses Classes;', 'type',
          '  TFoo = class( TObject )',
          '    FCount: Integer;',
          '    FList: TStringList;',
          '    procedure Run( A: Integer );',
          '    property Count: Integer read FCount;',
          '  end;',
          '  TFwd = class;',
          '  TBar<T> = record',
          '    Value: T;',
          '  end;',
          '  TProc = procedure( A: Integer ) of object;',
          '  TAfter = Integer;',
          'implementation', 'end.' ] ) );
    for var Name in [ 'TFoo', 'TFwd', 'TBar', 'TProc', 'TAfter' ] do
      Assert.IsTrue( HasExport( DB, 'Shapes', Name, ekType ), Name + ' is a declared type and must be exported' );
    for var Name in [ 'Integer', 'TStringList', 'TObject', 'FCount', 'FList', 'Run', 'Count', 'Value', 'T', 'A' ] do
      Assert.IsNull( DB.FindUnitsForIdentifier( Name ), Name + ' is not declared by Shapes and must not be exported' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestVarListNamesAreExported;
var
  DB                : TUnitExportsDatabase;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Globals', 'Globals.pas', Src( [
          'unit Globals;', 'interface', 'var', '  First, Second: Integer;', 'implementation', 'end.' ] ) );
    Assert.IsTrue( HasExport( DB, 'Globals', 'First', ekVar ), 'the first name of the list is exported' );
    Assert.IsTrue( HasExport( DB, 'Globals', 'Second', ekVar ), 'and so is the second' );
    Assert.IsNull( DB.FindUnitsForIdentifier( 'Integer' ), 'the type of the list is not' );
  finally
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestBuildFromDirectoriesResolvesRelativeAndSkipsRepeats;
var
  DB                : TUnitExportsDatabase;
  Base              : string;
  Dirs              : TStringList;
  Probe             : TProc;

  procedure WriteUnit( const ADir, AName, ARoutine: string );
  begin
    TDirectory.CreateDirectory( TPath.Combine( Base, ADir ) );
    TFile.WriteAllText( TPath.Combine( TPath.Combine( Base, ADir ), AName + '.pas' ),
      'unit ' + AName + ';'#13#10'interface'#13#10'procedure ' + ARoutine + ';'#13#10'implementation'#13#10'end.'#13#10,
      TEncoding.UTF8 );
  end;

begin
  Base              := TPath.Combine( TPath.GetTempPath, 'DDevExtUCM_' + TGUID.NewGuid.ToString.Substring( 1, 8 ) );
  DB                := TUnitExportsDatabase.Create;
  Dirs              := TStringList.Create;
  try
    WriteUnit( 'First', 'Utils', 'FromFirst' );
    WriteUnit( 'Second', 'Utils', 'FromSecond' );
    WriteUnit( 'Second', 'Extra', 'ExtraRoutine' );
    Dirs.Add( 'First' );
    Dirs.Add( '.\First\' );
    Dirs.Add( 'Second' );
    Probe           :=
      procedure
      begin
        DB.BuildFromDirectories( Dirs, nil, Base );
      end;
    Assert.WillNotRaiseAny( Probe, 'a repeated directory and a repeated unit name must not raise' );
    Assert.AreEqual( 2, DB.UnitCount, 'Utils once and Extra' );
    Assert.IsTrue( HasExport( DB, 'Utils', 'FromFirst', ekProcedure ),
      'relative entries resolve against the base, and the first Utils wins' );
    Assert.IsFalse( HasExport( DB, 'Utils', 'FromSecond', ekProcedure ), 'the second Utils is skipped' );
    Assert.IsTrue( HasExport( DB, 'Extra', 'ExtraRoutine', ekProcedure ), 'the rest of the second directory is still scanned' );
  finally
    Dirs.Free;
    DB.Free;
    if TDirectory.Exists( Base ) then
      TDirectory.Delete( Base, True );
  end;
end;

procedure TTestUnitExportsDatabase.TestResolveDirectory;
begin
  Assert.AreEqual( 'C:\Base\Sub', TUnitExportsDatabase.ResolveDirectory( ' Sub\ ', 'C:\Base' ), False,
    'a relative entry is resolved under the base directory' );
  Assert.AreEqual( 'C:\Base', TUnitExportsDatabase.ResolveDirectory( 'Sub\..', 'C:\Base' ), False,
    'and normalised' );
  Assert.AreEqual( 'D:\Lib', TUnitExportsDatabase.ResolveDirectory( 'D:\Lib', 'C:\Base' ), False,
    'an absolute entry is left alone' );
  Assert.AreEqual( '', TUnitExportsDatabase.ResolveDirectory( '   ', 'C:\Base' ), False,
    'a blank entry resolves to nothing' );
end;

{ TTestIdentifierUsageAnalyzer }

procedure TTestIdentifierUsageAnalyzer.TestInterfaceUsesAreCaptured;
var
  A                 : TIdentifierUsageAnalyzer;
  Found             : Boolean;
  U                 : TUsedUnitInfo;
begin
  A                 := TIdentifierUsageAnalyzer.Create;
  try
    A.Analyze( Src( [
          'unit Subject;', 'interface', 'uses SysUtils, Classes;', 'implementation', 'end.' ] ) );
    Found           := False;
    for U in A.InterfaceUsedUnits do
      if SameText( U.UnitName, 'Classes' ) then
      begin
        Found       := True;
        Assert.IsTrue( U.Section = usInterface, 'Classes should be marked as an interface use' );
      end;
    Assert.IsTrue( Found, 'Classes should appear in the interface uses list' );
  finally
    A.Free;
  end;
end;

procedure TTestIdentifierUsageAnalyzer.TestImplementationUsesAreCaptured;
var
  A                 : TIdentifierUsageAnalyzer;
  Found             : Boolean;
  U                 : TUsedUnitInfo;
begin
  A                 := TIdentifierUsageAnalyzer.Create;
  try
    A.Analyze( Src( [
          'unit Subject;', 'interface', 'uses Classes;',
          'implementation', 'uses Dialogs;', 'end.' ] ) );
    Found           := False;
    for U in A.ImplementationUsedUnits do
      if SameText( U.UnitName, 'Dialogs' ) then
        Found       := True;
    Assert.IsTrue( Found, 'Dialogs should appear in the implementation uses list' );

    for U in A.InterfaceUsedUnits do
      Assert.IsFalse( SameText( U.UnitName, 'Dialogs' ),
        'Dialogs must not also be listed as an interface use' );
  finally
    A.Free;
  end;
end;

procedure TTestIdentifierUsageAnalyzer.TestInterfaceIdentifierIsRecorded;
var
  A                 : TIdentifierUsageAnalyzer;
begin
  A                 := TIdentifierUsageAnalyzer.Create;
  try
    A.Analyze( Src( [
          'unit Subject;', 'interface', 'uses Classes;',
          'type', '  TThing = class( TComponent )', '  end;',
          'implementation', 'end.' ] ) );
    Assert.IsTrue( A.InterfaceIdentifiers.IndexOf( 'TComponent' ) >= 0,
      'TComponent is referenced in the interface and should be recorded there' );
  finally
    A.Free;
  end;
end;

procedure TTestIdentifierUsageAnalyzer.TestImplementationIdentifierIsRecorded;
var
  A                 : TIdentifierUsageAnalyzer;
begin
  A                 := TIdentifierUsageAnalyzer.Create;
  try
    A.Analyze( Src( [
          'unit Subject;', 'interface', 'uses Classes;',
          'implementation',
          'procedure Local;', 'var', '  L: TStringList;', 'begin', '  L := nil;', 'end;',
          'end.' ] ) );
    Assert.IsTrue( A.ImplementationIdentifiers.IndexOf( 'TStringList' ) >= 0,
      'TStringList appears only below implementation and should be recorded there' );
    Assert.IsTrue( A.InterfaceIdentifiers.IndexOf( 'TStringList' ) < 0,
      'and must not be recorded as an interface identifier' );
  finally
    A.Free;
  end;
end;

procedure TTestIdentifierUsageAnalyzer.TestQualifiedReferenceIsRecorded;
var
  A                 : TIdentifierUsageAnalyzer;
  Qualifier         : string;
begin
  A                 := TIdentifierUsageAnalyzer.Create;
  try
    A.Analyze( Src( [
          'unit Subject;', 'interface', 'implementation',
          'procedure Local;', 'begin', '  SysUtils.FreeAndNil( Obj );', 'end;',
          'end.' ] ) );
    Assert.IsTrue( A.QualifiedReferences.TryGetValue( 'freeandnil', Qualifier ),
      'the qualified reference should be recorded' );
    Assert.AreEqual( 'SysUtils', Qualifier, False, 'and should name its qualifying unit' );
  finally
    A.Free;
  end;
end;

procedure TTestIdentifierUsageAnalyzer.TestClearResetsAllCollections;
var
  A                 : TIdentifierUsageAnalyzer;
begin
  A                 := TIdentifierUsageAnalyzer.Create;
  try
    A.Analyze( Src( [
          'unit Subject;', 'interface', 'uses Classes;', 'implementation', 'end.' ] ) );
    Assert.IsTrue( A.InterfaceUsedUnits.Count > 0, 'there should be something to clear' );

    A.Clear;

    Assert.AreEqual<Integer>( 0, A.InterfaceUsedUnits.Count, 'interface uses should be cleared' );
    Assert.AreEqual<Integer>( 0, A.ImplementationUsedUnits.Count, 'implementation uses should be cleared' );
    Assert.AreEqual( 0, A.InterfaceIdentifiers.Count, 'interface identifiers should be cleared' );
    Assert.AreEqual( 0, A.ImplementationIdentifiers.Count, 'implementation identifiers should be cleared' );
    Assert.AreEqual<Integer>( 0, A.QualifiedReferences.Count, 'qualified references should be cleared' );
  finally
    A.Free;
  end;
end;

{ TTestUsesClauseRefactorer }

/// <summary>Builds a database holding one provider unit that exports a single routine.</summary>
function ProviderDB: TUnitExportsDatabase;
begin
  Result            := TUnitExportsDatabase.Create;
  Result.ScanSource( 'Provider', 'Provider.pas', Src( [
        'unit Provider;', 'interface', 'procedure ProviderRoutine;', 'implementation', 'end.' ] ) );
end;

procedure TTestUsesClauseRefactorer.TestInterfaceUnitUsedOnlyInImplementationMovesDown;
var
  DB                : TUnitExportsDatabase;
  R                 : TUsesClauseRefactorer;
  Placements        : TArray<TUnitPlacement>;
  P                 : TUnitPlacement;
begin
  DB                := ProviderDB;
  R                 := TUsesClauseRefactorer.Create( DB );
  try
    Placements      := R.Analyze( Src( [
          'unit Subject;', 'interface', 'uses Provider;',
          'implementation',
          'procedure Local;', 'begin', '  ProviderRoutine;', 'end;',
          'end.' ] ) );
    try
      P             := PlacementFor( Placements, 'Provider' );
      Assert.IsTrue( P.CurrentSection = usInterface, 'it is currently in the interface clause' );
      Assert.IsTrue( P.RecommendedSection = usImplementation,
        'used only below implementation, so it should be recommended for the implementation clause' );
      Assert.AreEqual( 'Only used in implementation section', P.Reason, False,
        'and the reason should say so' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestInterfaceUnitUsedInInterfaceStays;
var
  DB                : TUnitExportsDatabase;
  R                 : TUsesClauseRefactorer;
  Placements        : TArray<TUnitPlacement>;
  P                 : TUnitPlacement;
begin
  DB                := ProviderDB;
  R                 := TUsesClauseRefactorer.Create( DB );
  try
    Placements      := R.Analyze( Src( [
          'unit Subject;', 'interface', 'uses Provider;',
          'procedure Exposed;', 'begin', '  ProviderRoutine;', 'end;',
          'implementation', 'end.' ] ) );
    try
      P             := PlacementFor( Placements, 'Provider' );
      Assert.IsTrue( P.RecommendedSection = usInterface,
        'its identifier is referenced in the interface, so it should stay there' );
      Assert.IsTrue( P.IdentifiersUsedInInterface.IndexOf( 'ProviderRoutine' ) >= 0,
        'and the identifier that justifies it should be reported' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestUnusedUnitIsFlaggedForReview;
var
  DB                : TUnitExportsDatabase;
  R                 : TUsesClauseRefactorer;
  Placements        : TArray<TUnitPlacement>;
  P                 : TUnitPlacement;
begin
  DB                := ProviderDB;
  R                 := TUsesClauseRefactorer.Create( DB );
  try
    Placements      := R.Analyze( Src( [
          'unit Subject;', 'interface', 'uses Provider;', 'implementation', 'end.' ] ) );
    try
      P             := PlacementFor( Placements, 'Provider' );
      Assert.IsTrue( P.RecommendedSection = usInterface,
        'an apparently unused unit should be left where it is' );
      Assert.AreEqual( 'No direct usage detected - review manually', P.Reason, False,
        'and be flagged for manual review rather than moved' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestImplementationUnitUsedInInterfaceMovesUp;
var
  DB                : TUnitExportsDatabase;
  R                 : TUsesClauseRefactorer;
  Placements        : TArray<TUnitPlacement>;
  P                 : TUnitPlacement;
begin
  DB                := ProviderDB;
  R                 := TUsesClauseRefactorer.Create( DB );
  try
    Placements      := R.Analyze( Src( [
          'unit Subject;', 'interface',
          'procedure Exposed;', 'begin', '  ProviderRoutine;', 'end;',
          'implementation', 'uses Provider;', 'end.' ] ) );
    try
      P             := PlacementFor( Placements, 'Provider' );
      Assert.IsTrue( P.CurrentSection = usImplementation, 'it is currently in the implementation clause' );
      Assert.IsTrue( P.RecommendedSection = usInterface,
        'its identifier is used in the interface, so it should be recommended for the interface clause' );
      Assert.AreEqual( 'Identifiers used in interface section', P.Reason, False,
        'and the reason should say so' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestGenerateRefactoredSourceRelocatesUnit;
var
  DB                : TUnitExportsDatabase;
  R                 : TUsesClauseRefactorer;
  Placements        : TArray<TUnitPlacement>;
  Rewritten         : UTF8String;
  Check             : TIdentifierUsageAnalyzer;
  U                 : TUsedUnitInfo;
  InInterface, InImplementation: Boolean;
begin
  DB                := ProviderDB;
  R                 := TUsesClauseRefactorer.Create( DB );
  try
    Rewritten       := '';
    Placements      := R.Analyze( Src( [
          'unit Subject;', 'interface', 'uses Provider;',
          'implementation',
          'procedure Local;', 'begin', '  ProviderRoutine;', 'end;',
          'end.' ] ) );
    try
      Rewritten     := R.GenerateRefactoredSource( Src( [
            'unit Subject;', 'interface', 'uses Provider;',
            'implementation',
            'procedure Local;', 'begin', '  ProviderRoutine;', 'end;',
            'end.' ] ), Placements );
    finally
      FreePlacements( Placements );
    end;

    Assert.IsTrue( Length( Rewritten ) > 0, 'the rewrite should produce source' );

    { Verify the outcome by re-reading the generated source rather than by matching text,
      so the test survives any change to layout or formatting. }
    Check           := TIdentifierUsageAnalyzer.Create;
    try
      Check.Analyze( Rewritten );
      InInterface   := False;
      InImplementation := False;
      for U in Check.InterfaceUsedUnits do
        if SameText( U.UnitName, 'Provider' ) then
          InInterface := True;
      for U in Check.ImplementationUsedUnits do
        if SameText( U.UnitName, 'Provider' ) then
          InImplementation := True;

      Assert.IsFalse( InInterface, 'Provider should no longer be in the interface uses clause' );
      Assert.IsTrue( InImplementation, 'Provider should now be in the implementation uses clause' );
    finally
      Check.Free;
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestSourceWithoutUsesClauseYieldsNoPlacements;
var
  DB                : TUnitExportsDatabase;
  R                 : TUsesClauseRefactorer;
  Placements        : TArray<TUnitPlacement>;
begin
  DB                := ProviderDB;
  R                 := TUsesClauseRefactorer.Create( DB );
  try
    Placements      := R.Analyze( Src( [
          'unit Subject;', 'interface', 'implementation', 'end.' ] ) );
    try
      Assert.AreEqual<Integer>( 0, Length( Placements ),
        'a unit with no uses clause has nothing to place' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

/// <summary>Analyses ASource against ADB and returns the rewrite; AError receives any refusal reason.</summary>
function Rewrite( ADB: TUnitExportsDatabase; const ASource: UTF8String; out AError: string ): UTF8String;
var
  R                 : TUsesClauseRefactorer;
  Placements        : TArray<TUnitPlacement>;
begin
  R                 := TUsesClauseRefactorer.Create( ADB );
  try
    Placements      := R.Analyze( ASource );
    try
      Result        := R.GenerateRefactoredSource( ASource, Placements, AError );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
  end;
end;

/// <summary>Fails the test, showing both texts, when the rewrite differs from the expected source byte for byte.</summary>
procedure AssertSource( const AExpected, AActual: UTF8String; const AMessage: string );
begin
  Assert.AreEqual( UTF8ToString( AExpected ), UTF8ToString( AActual ), False, AMessage );
  Assert.IsTrue( AExpected = AActual, AMessage + ' ( byte comparison, case included )' );
end;

procedure TTestUsesClauseRefactorer.TestConditionalBlockAndCommentSurviveAMove;
var
  DB                : TUnitExportsDatabase;
  Error             : string;
begin
  DB                := ProviderDB;
  try
    AssertSource( Src( [
          'unit Subject;', 'interface', 'uses',
          '  {$IFDEF DEBUG} Cond, {$ENDIF} { keep } Classes;',
          'implementation', '', 'uses', '  Provider;',
          'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ),
      Rewrite( DB, Src( [
            'unit Subject;', 'interface', 'uses',
            '  Provider, {$IFDEF DEBUG} Cond, {$ENDIF} { keep } Classes;',
            'implementation',
            'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ), Error ),
      'only "Provider, " leaves the interface clause, and a new implementation clause receives it' );
    Assert.AreEqual( '', Error, 'and nothing was refused' );
  finally
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestEntryInsideConditionalIsRefused;
var
  DB                : TUnitExportsDatabase;
  Source            : UTF8String;
  Error             : string;
begin
  DB                := ProviderDB;
  try
    Source          := Src( [
        'unit Subject;', 'interface', 'uses {$IFDEF DEBUG} Provider, {$ENDIF} Classes;',
        'implementation',
        'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] );
    AssertSource( Source, Rewrite( DB, Source, Error ), 'a conditional entry must not be moved' );
    Assert.Contains( Error, 'conditional', 'and the refusal says why' );
  finally
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestInPathMovesWithItsEntry;
var
  DB                : TUnitExportsDatabase;
  Error             : string;
begin
  DB                := ProviderDB;
  try
    AssertSource( Src( [
          'unit Subject;', 'interface', 'uses Classes;',
          'implementation', '', 'uses', '  Provider in ''..\Provider.pas'';',
          'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ),
      Rewrite( DB, Src( [
            'unit Subject;', 'interface', 'uses Provider in ''..\Provider.pas'', Classes;',
            'implementation',
            'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ), Error ),
      'the entry moves with its in-path' );
  finally
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestStalePlacementsAreRefused;
var
  DB                : TUnitExportsDatabase;
  R                 : TUsesClauseRefactorer;
  Placements        : TArray<TUnitPlacement>;
  Edits             : TArray<TUsesEdit>;
  Error             : string;
begin
  DB                := ProviderDB;
  R                 := TUsesClauseRefactorer.Create( DB );
  try
    Placements      := R.Analyze( Src( [
          'unit Subject;', 'interface', 'uses Provider, Classes;', 'implementation',
          'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ) );
    try
      // The user has since removed Provider from the clause.
      Assert.IsFalse( R.PlanMoves( Src( [
              'unit Subject;', 'interface', 'uses Classes;', 'implementation',
              'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ), Placements, Edits, Error ),
        'placements older than the source must be refused' );
      Assert.Contains( Error, 'not in the interface uses clause any more', 'with a reason' );
      Assert.AreEqual<Integer>( 0, Length( Edits ), 'and no edits' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestUnitAddedAfterAnalysisSurvives;
var
  DB                : TUnitExportsDatabase;
  R                 : TUsesClauseRefactorer;
  Placements        : TArray<TUnitPlacement>;
  Rewritten         : UTF8String;
  Error             : string;
begin
  DB                := ProviderDB;
  R                 := TUsesClauseRefactorer.Create( DB );
  try
    Placements      := R.Analyze( Src( [
          'unit Subject;', 'interface', 'uses Provider;', 'implementation',
          'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ) );
    try
      // The user has since added Extra to the clause.
      Rewritten     := R.GenerateRefactoredSource( Src( [
            'unit Subject;', 'interface', 'uses Provider, Extra;', 'implementation',
            'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ), Placements, Error );
    finally
      FreePlacements( Placements );
    end;
    AssertSource( Src( [
          'unit Subject;', 'interface', 'uses Extra;', 'implementation', '', 'uses', '  Provider;',
          'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ), Rewritten,
      'Extra, added after the analysis, stays where the user put it' );
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestMoveUpCreatesInterfaceClause;
var
  DB                : TUnitExportsDatabase;
  Error             : string;
begin
  DB                := ProviderDB;
  try
    AssertSource( Src( [
          'unit Subject;', 'interface', '', 'uses', '  Provider;',
          'procedure Exposed;', 'begin', '  ProviderRoutine;', 'end;',
          'implementation', 'end.' ] ),
      Rewrite( DB, Src( [
            'unit Subject;', 'interface',
            'procedure Exposed;', 'begin', '  ProviderRoutine;', 'end;',
            'implementation', 'uses Provider;', 'end.' ] ), Error ),
      'an interface clause is created for Provider and the emptied implementation clause goes' );
  finally
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestNonAsciiBeforeClausesKeepsOffsets;
var
  DB                : TUnitExportsDatabase;
  Error             : string;
begin
  DB                := ProviderDB;
  try
    AssertSource( Src( [
          'unit Subject; // Grüße – ½ €',
          'interface', 'uses Classes;',
          'implementation', 'uses SysUtils, Provider;',
          'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ),
      Rewrite( DB, Src( [
            'unit Subject; // Grüße – ½ €',
            'interface', 'uses Provider, Classes;',
            'implementation', 'uses SysUtils;',
            'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ), Error ),
      'multi-byte characters before the clauses must not shift the edits' );
  finally
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestDottedNameMovesIntact;
var
  DB                : TUnitExportsDatabase;
  Error             : string;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Acme.Provider', 'Acme.Provider.pas', Src( [
          'unit Acme.Provider;', 'interface', 'procedure ProviderRoutine;', 'implementation', 'end.' ] ) );
    AssertSource( Src( [
          'unit Subject;', 'interface', 'uses Classes;',
          'implementation', 'uses SysUtils, Acme.Provider;',
          'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ),
      Rewrite( DB, Src( [
            'unit Subject;', 'interface', 'uses Acme.Provider, Classes;',
            'implementation', 'uses SysUtils;',
            'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ), Error ),
      'the dotted name is found by its full name and moves intact' );
  finally
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestLongTargetClauseWraps;
var
  DB                : TUnitExportsDatabase;
  Long              : string;
  Error             : string;
begin
  DB                := ProviderDB;
  try
    Long            := StringOfChar( 'L', 150 );
    AssertSource( Src( [
          'unit Subject;', 'interface', 'uses Classes;',
          'implementation', 'uses', '  ' + Long + ',', '  Provider;',
          'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ),
      Rewrite( DB, Src( [
            'unit Subject;', 'interface', 'uses Provider, Classes;',
            'implementation', 'uses', '  ' + Long + ';',
            'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ), Error ),
      'the appended entry starts a new line rather than pass 160 characters' );
  finally
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestProgramSourceIsRefused;
var
  DB                : TUnitExportsDatabase;
  R                 : TUsesClauseRefactorer;
  Placements        : TArray<TUnitPlacement>;
  Edits             : TArray<TUsesEdit>;
  Error             : string;
begin
  DB                := ProviderDB;
  R                 := TUsesClauseRefactorer.Create( DB );
  try
    SetLength( Placements, 1 );
    Placements[ 0 ].UnitName := 'Provider';
    Placements[ 0 ].CurrentSection := usInterface;
    Placements[ 0 ].RecommendedSection := usImplementation;
    Assert.IsFalse( R.PlanMoves( Src( [ 'program P;', 'uses Provider;', 'begin', 'end.' ] ), Placements, Edits, Error ),
      'a program has no sections to move between' );
    Assert.Contains( Error, 'no interface and implementation', 'and the refusal says so' );
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestFieldTypeDoesNotPullUnitIntoInterface;
var
  DB                : TUnitExportsDatabase;
  R                 : TUsesClauseRefactorer;
  Placements        : TArray<TUnitPlacement>;
begin
  DB                := TUnitExportsDatabase.Create;
  R                 := TUsesClauseRefactorer.Create( DB );
  try
    DB.ScanSource( 'Bar', 'Bar.pas', Src( [
          'unit Bar;', 'interface', 'type', '  TBar = class', '    FCount: Integer;', '  end;', 'implementation', 'end.' ] ) );
    Placements      := R.Analyze( Src( [
          'unit Subject;', 'interface', 'function Get: Integer;',
          'implementation', 'uses Bar;',
          'function Get: Integer;', 'begin', '  Result := TBar.InstanceSize;', 'end;', 'end.' ] ) );
    try
      Assert.IsTrue( PlacementFor( Placements, 'Bar' ).RecommendedSection = usImplementation,
        'Bar does not declare Integer, so the interface''s Integer must not pull it up' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestQualifiedReferenceToAnotherUnitDoesNotCount;
var
  DB                : TUnitExportsDatabase;
  R                 : TUsesClauseRefactorer;
  Placements        : TArray<TUnitPlacement>;
begin
  DB                := TUnitExportsDatabase.Create;
  R                 := TUsesClauseRefactorer.Create( DB );
  try
    DB.ScanSource( 'Bar', 'Bar.pas', Src( [
          'unit Bar;', 'interface', 'type', '  TThing = class', '  end;', 'implementation', 'end.' ] ) );
    Placements      := R.Analyze( Src( [
          'unit Subject;', 'interface', 'uses Other;', 'var', '  X: Other.TThing;',
          'implementation', 'uses Bar;',
          'procedure Local;', 'begin', '  TThing.Create;', 'end;', 'end.' ] ) );
    try
      Assert.IsTrue( PlacementFor( Placements, 'Bar' ).RecommendedSection = usImplementation,
        'the interface''s TThing is Other.TThing, so Bar must stay in the implementation clause' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUnitExportsDatabase.TestEnumValuesAreExported;
var
  DB                : TUnitExportsDatabase;
begin
  DB                := TUnitExportsDatabase.Create;
  try
    DB.ScanSource( 'Gfx', 'Gfx.pas', Src( [
          'unit Gfx;', 'interface', 'type', '  TFontStyle = ( fsBold, fsItalic = 4 );', '  TAfter = Integer;',
          'implementation', 'end.' ] ) );
    Assert.IsTrue( HasExport( DB, 'Gfx', 'TFontStyle', ekType ), 'the enumerated type is exported' );
    Assert.IsTrue( HasExport( DB, 'Gfx', 'fsBold', ekConst ), 'and so is its first value' );
    Assert.IsTrue( HasExport( DB, 'Gfx', 'fsItalic', ekConst ), 'and a value with an explicit ordinal' );
    Assert.IsTrue( HasExport( DB, 'Gfx', 'TAfter', ekType ), 'and the scan carries on after the enumeration' );
  finally
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestEnumValueKeepsUnitInInterface;
var
  DB                : TUnitExportsDatabase;
  R                 : TUsesClauseRefactorer;
  Placements        : TArray<TUnitPlacement>;
begin
  DB                := TUnitExportsDatabase.Create;
  R                 := TUsesClauseRefactorer.Create( DB );
  try
    DB.ScanSource( 'Gfx', 'Gfx.pas', Src( [
          'unit Gfx;', 'interface', 'type', '  TFontStyle = ( fsBold, fsItalic );', 'implementation', 'end.' ] ) );
    Placements      := R.Analyze( Src( [
          'unit Subject;', 'interface', 'uses Gfx;', 'const', '  DefaultStyle = [ fsBold ];',
          'implementation',
          'procedure Local;', 'var', '  S: TFontStyle;', 'begin', 'end;', 'end.' ] ) );
    try
      Assert.IsTrue( PlacementFor( Placements, 'Gfx' ).RecommendedSection = usInterface,
        'fsBold is used in the interface, so Gfx must stay in the interface clause' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestInterfaceTypeInImplementationKeepsSection;
var
  DB                : TUnitExportsDatabase;
  R                 : TUsesClauseRefactorer;
  Placements        : TArray<TUnitPlacement>;
begin
  DB                := ProviderDB;
  R                 := TUsesClauseRefactorer.Create( DB );
  try
    Placements      := R.Analyze( Src( [
          'unit Subject;', 'interface', 'uses Provider;',
          'implementation',
          'type', '  IFoo = interface', '  end;',
          'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ) );
    try
      Assert.IsTrue( PlacementFor( Placements, 'Provider' ).RecommendedSection = usImplementation,
        'ProviderRoutine is used below "IFoo = interface", which is still the implementation section' );
    finally
      FreePlacements( Placements );
    end;
  finally
    R.Free;
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestIncludeBeforeSectionIsRefused;
var
  DB                : TUnitExportsDatabase;
  Source            : UTF8String;
  Error             : string;
begin
  DB                := ProviderDB;
  try
    Source          := Src( [
        'unit Subject;', 'interface', '{$I SubjectUses.inc}',
        'procedure Exposed;', 'begin', '  ProviderRoutine;', 'end;',
        'implementation', 'uses Provider;', 'end.' ] );
    AssertSource( Source, Rewrite( DB, Source, Error ), 'no second interface clause may be created' );
    Assert.Contains( Error, 'include', 'and the refusal says why' );
  finally
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestLineFeedBufferGetsLineFeeds;
var
  DB                : TUnitExportsDatabase;
  Error             : string;

  function LfSrc( const ALines: array of string ): UTF8String;
  begin
    Result          := UTF8String( string.Join( #10, ALines ) + #10 );
  end;

begin
  DB                := ProviderDB;
  try
    AssertSource( LfSrc( [
          'unit Subject;', 'interface', 'uses Classes;',
          'implementation', '', 'uses', '  Provider;',
          'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ),
      Rewrite( DB, LfSrc( [
            'unit Subject;', 'interface', 'uses Provider, Classes;',
            'implementation',
            'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ), Error ),
      'the created clause uses the buffer''s LF line breaks' );
  finally
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestTrailingLineCommentGoesWithItsEntry;
var
  DB                : TUnitExportsDatabase;
  Error             : string;
begin
  DB                := ProviderDB;
  try
    AssertSource( Src( [
          'unit Subject;', 'interface', 'uses',
          '  Classes;',
          'implementation', '', 'uses', '  Provider;',
          'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ),
      Rewrite( DB, Src( [
            'unit Subject;', 'interface', 'uses',
            '  Provider, // the provider of ProviderRoutine',
            '  Classes;',
            'implementation',
            'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] ), Error ),
      'the entry''s line goes, comment and all' );
  finally
    DB.Free;
  end;
end;

procedure TTestUsesClauseRefactorer.TestTrailingLineCommentOnSharedLineIsRefused;
var
  DB                : TUnitExportsDatabase;
  Source            : UTF8String;
  Error             : string;
begin
  DB                := ProviderDB;
  try
    Source          := Src( [
        'unit Subject;', 'interface', 'uses Provider, // the provider of ProviderRoutine',
        '  Classes;',
        'implementation',
        'procedure Local;', 'begin', '  ProviderRoutine;', 'end;', 'end.' ] );
    AssertSource( Source, Rewrite( DB, Source, Error ), 'the comment cannot go with the entry, so nothing changes' );
    Assert.Contains( Error, '// comment', 'and the refusal says why' );
  finally
    DB.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestUnitExportsDatabase );
  TDUnitX.RegisterTestFixture( TTestIdentifierUsageAnalyzer );
  TDUnitX.RegisterTestFixture( TTestUsesClauseRefactorer );

end.

