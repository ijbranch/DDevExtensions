{******************************************************************************}
{*                                                                            *}
{* DDevExtensions unit tests - DfmLinkCheck ( DfmNoiseMeasure links )         *}
{*                                                                            *}
{******************************************************************************}

unit TestDfmLinkCheckDUnitX;

/// <summary>
/// Tests the decisions of <c>DfmNoiseMeasure links</c>: the module index, the links in today's file without a
/// target, and the state today of a link a past save lost.
/// </summary>

interface

uses
  DUnitX.TestFramework, System.SysUtils, DfmLinkGuardCore, DfmLinkCheck;

type
  /// <summary>Tests of <c>DfmLinkCheck</c>.</summary>
  [TestFixture]
  TTestDfmLinkCheck = class
  private
    /// <summary>The index the tests share: dmMain ( repo A, dsCustomers ), dmMain ( repo B, dsOrders ), dmShared ( repo S, dsCommon ).</summary>
    FIndex: TDfmModuleIndex;
  public
    /// <summary>Builds the shared index.</summary>
    [Setup]
    procedure Setup;
    /// <summary>Frees the shared index.</summary>
    [TearDown]
    procedure TearDown;
    /// <summary>
    /// Proves a target is looked for in the link's own repository first: repo A's dmMain has dsCustomers but not
    /// dsOrders, even though repo B's dmMain has dsOrders; a module only another repository has ( dmShared ) is
    /// still found.  Without the same-repository rule every application's MainForm would answer for every other's.
    /// </summary>
    [Test]
    procedure TestTargetLookedForInOwnRepoFirst;
    /// <summary>Proves the index knows each root name once, ignores a text with no root, and answers IsKnownModule.</summary>
    [Test]
    procedure TestIndexKnowsRootsAndIgnoresRootlessText;
    /// <summary>
    /// Proves a form's links are counted and only those without a target returned, each with its kind: a missing
    /// component in a known module, and a module no text has.
    /// </summary>
    [Test]
    procedure TestDanglingLinksFoundWithKind;
    /// <summary>
    /// Proves a dotted value that is not a link to another module is not counted: one naming the form's own root,
    /// one naming a component of the form ( an embedded frame's button ), and a number.
    /// </summary>
    [Test]
    procedure TestLocalDottedValuesAreNotLinks;
    /// <summary>
    /// Proves a value naming the form's own root is checked, not counted as a link to another module: a component
    /// the form does not declare is reported missing ( review finding: such values were never checked ).
    /// </summary>
    [Test]
    procedure TestOwnRootLinkIsChecked;
    /// <summary>
    /// Proves a text with no object header has no links and does not fail: the parser gives it an empty root
    /// ( a review claimed a nil root would crash the run ).
    /// </summary>
    [Test]
    procedure TestRootlessTextHasNoLinks;
    /// <summary>Proves each state today of a lost link: restored, value elsewhere, component gone, file gone, still lost.</summary>
    [Test]
    procedure TestLossTodayStates;
    /// <summary>
    /// Proves "value elsewhere" means another property holds exactly that link: the link text inside a caption, or
    /// as the start of a longer name, leaves the loss still lost ( review finding: any text match hid it ).
    /// </summary>
    [Test]
    procedure TestValueElsewhereNeedsTheSameValue;
    /// <summary>Proves the CSV names: each state and kind has its own, non-empty name.</summary>
    [Test]
    procedure TestNames;
  end;

implementation

const
  CNL               = #13#10;

/// <summary>A data module text declaring the given components.</summary>
/// <param name="Root">Its root name.</param>
/// <param name="Components">The data sources it declares.</param>
/// <returns>The text.</returns>
function DataModule( const Root: string; const Components: array of string ): string;
begin
  Result            := 'object ' + Root + ': T' + Root + CNL;
  for var sName in Components do
    Result          := Result + '  object ' + sName + ': TDataSource' + CNL + '  end' + CNL;
  Result            := Result + 'end' + CNL;
end;

/// <summary>A lost link as FindLostModuleLinks reports it: frmMain.grdA.DataSource = dmMain.dsCustomers.</summary>
/// <returns>The link.</returns>
function LostLink: TDfmLostLink;
begin
  Result.Path       := 'frmMain.grdA';
  Result.PropName   := 'DataSource';
  Result.Value      := 'dmMain.dsCustomers';
  Result.ModuleName := 'dmMain';
  Result.ComponentName := 'dsCustomers';
end;

procedure TTestDfmLinkCheck.Setup;
begin
  FIndex            := TDfmModuleIndex.Create;
  FIndex.Add( 'A', DataModule( 'dmMain', [ 'dsCustomers' ] ) );
  FIndex.Add( 'B', DataModule( 'dmMain', [ 'dsOrders' ] ) );
  FIndex.Add( 'S', DataModule( 'dmShared', [ 'dsCommon' ] ) );
end;

procedure TTestDfmLinkCheck.TearDown;
begin
  FreeAndNil( FIndex );
end;

procedure TTestDfmLinkCheck.TestTargetLookedForInOwnRepoFirst;
begin
  Assert.IsTrue( FIndex.TargetExists( 'A', 'dmMain', 'dsCustomers' ), 'own repo has it' );
  Assert.IsFalse( FIndex.TargetExists( 'A', 'dmMain', 'dsOrders' ), 'only another repo''s dmMain has it' );
  Assert.IsTrue( FIndex.TargetExists( 'B', 'DMMAIN', 'DSORDERS' ), 'case-insensitive' );
  Assert.IsTrue( FIndex.TargetExists( 'C', 'dmMain', 'dsOrders' ), 'no dmMain in repo C: any repo''s answers' );
  Assert.IsTrue( FIndex.TargetExists( 'A', 'dmShared', 'dsCommon' ), 'shared module' );
  Assert.IsFalse( FIndex.TargetExists( 'A', 'dmShared', 'dsGone' ), 'shared module without it' );
  Assert.IsFalse( FIndex.TargetExists( 'A', 'dmNone', 'dsCommon' ), 'unknown module' );
end;

procedure TTestDfmLinkCheck.TestIndexKnowsRootsAndIgnoresRootlessText;
begin
  FIndex.Add( 'A', 'not a dfm at all' );
  FIndex.Add( 'A', '' );
  Assert.AreEqual( 2, FIndex.ModuleCount, 'dmMain once, dmShared' );
  Assert.IsTrue( FIndex.IsKnownModule( 'DMSHARED' ) );
  Assert.IsFalse( FIndex.IsKnownModule( 'dmNone' ) );
end;

procedure TTestDfmLinkCheck.TestDanglingLinksFoundWithKind;
const
  CForm             = 'object frmMain: TfrmMain' + CNL +
                      '  object grdA: TDBGrid' + CNL +
                      '    DataSource = dmMain.dsCustomers' + CNL +
                      '  end' + CNL +
                      '  object grdB: TDBGrid' + CNL +
                      '    DataSource = dmMain.dsGone' + CNL +
                      '  end' + CNL +
                      '  object grdC: TDBGrid' + CNL +
                      '    DataSource = dmRenamed.dsCustomers' + CNL +
                      '  end' + CNL +
                      'end' + CNL;
begin
  var iLinks        : Integer;
  var aLinks        := FindDanglingLinks( FIndex, 'A', CForm, iLinks );
  Assert.AreEqual( 3, iLinks, 'links counted' );
  Assert.AreEqual( 2, Integer( Length( aLinks ) ), 'without a target' );
  Assert.AreEqual( 'frmMain.grdB', aLinks[ 0 ].Path, False );
  Assert.AreEqual( 'DataSource', aLinks[ 0 ].PropName, False );
  Assert.AreEqual( 'dmMain.dsGone', aLinks[ 0 ].Value, False );
  Assert.AreEqual( Ord( dkComponentMissing ), Ord( aLinks[ 0 ].Kind ) );
  Assert.AreEqual( 'frmMain.grdC', aLinks[ 1 ].Path, False );
  Assert.AreEqual( Ord( dkModuleNotFound ), Ord( aLinks[ 1 ].Kind ) );
end;

procedure TTestDfmLinkCheck.TestLocalDottedValuesAreNotLinks;
const
  CForm             = 'object frmMain: TfrmMain' + CNL +
                      '  ActiveControl = frmMain.grdA' + CNL +
                      '  object Frame1: TFrame1' + CNL +
                      '    object btnGo: TButton' + CNL +
                      '    end' + CNL +
                      '  end' + CNL +
                      '  object grdA: TDBGrid' + CNL +
                      '    PopupMenu = Frame1.pmGrid' + CNL +
                      '    Scale = 1.5' + CNL +
                      '  end' + CNL +
                      'end' + CNL;
begin
  var iLinks        : Integer;
  var aLinks        := FindDanglingLinks( FIndex, 'A', CForm, iLinks );
  Assert.AreEqual( 0, iLinks, 'no link to another module' );
  Assert.AreEqual( 0, Integer( Length( aLinks ) ) );
end;

procedure TTestDfmLinkCheck.TestOwnRootLinkIsChecked;
const
  CForm             = 'object frmMain: TfrmMain' + CNL +
                      '  ActiveControl = frmMain.grdGone' + CNL +
                      '  object grdA: TDBGrid' + CNL +
                      '  end' + CNL +
                      'end' + CNL;
begin
  var iLinks        : Integer;
  var aLinks        := FindDanglingLinks( FIndex, 'A', CForm, iLinks );
  Assert.AreEqual( 0, iLinks, 'not a link to another module' );
  Assert.AreEqual( 1, Integer( Length( aLinks ) ), 'but its component is missing' );
  Assert.AreEqual( 'frmMain.grdGone', aLinks[ 0 ].Value, False );
  Assert.AreEqual( Ord( dkComponentMissing ), Ord( aLinks[ 0 ].Kind ) );
end;

procedure TTestDfmLinkCheck.TestRootlessTextHasNoLinks;
begin
  var iLinks        : Integer;
  Assert.AreEqual( 0, Integer( Length( FindDanglingLinks( FIndex, 'A', 'not a dfm = dmMain.dsGone', iLinks ) ) ) );
  Assert.AreEqual( 0, iLinks );
end;

procedure TTestDfmLinkCheck.TestValueElsewhereNeedsTheSameValue;
const
  CHead             = 'object frmMain: TfrmMain' + CNL + '  object grdA: TDBGrid' + CNL + '  end' + CNL;
  CTail             = 'end' + CNL;
begin
  Assert.AreEqual( Ord( ltStillLost ), Ord( LossToday( LostLink, CHead + '  Caption = ''Uses dmMain.dsCustomers''' + CNL + CTail ) ),
    'inside a caption' );
  Assert.AreEqual( Ord( ltStillLost ), Ord( LossToday( LostLink, CHead + '  object grdB: TDBGrid' + CNL +
    '    DataSource = dmMain.dsCustomersOld' + CNL + '  end' + CNL + CTail ) ), 'start of a longer name' );
  Assert.AreEqual( Ord( ltValueElsewhere ), Ord( LossToday( LostLink, CHead + '  object grdB: TDBGrid' + CNL +
    '    DataSource = DMMAIN.DSCUSTOMERS' + CNL + '  end' + CNL + CTail ) ), 'held by another component, any case' );
end;

procedure TTestDfmLinkCheck.TestLossTodayStates;
const
  CHead             = 'object frmMain: TfrmMain' + CNL + '  object grdA: TDBGrid' + CNL;
  CTail             = '  end' + CNL + 'end' + CNL;
begin
  Assert.AreEqual( Ord( ltRestored ), Ord( LossToday( LostLink, CHead + '    DataSource = DMMAIN.dsCustomers' + CNL + CTail ) ), 'restored' );
  Assert.AreEqual( Ord( ltValueElsewhere ), Ord( LossToday( LostLink, CHead + '  end' + CNL +
    '  object grdB: TDBGrid' + CNL + '    DataSource = dmMain.dsCustomers' + CNL + CTail ) ), 'held by another component' );
  Assert.AreEqual( Ord( ltComponentGone ), Ord( LossToday( LostLink, 'object frmMain: TfrmMain' + CNL + 'end' + CNL ) ), 'component gone' );
  Assert.AreEqual( Ord( ltFileGone ), Ord( LossToday( LostLink, '' ) ), 'file gone' );
  Assert.AreEqual( Ord( ltStillLost ), Ord( LossToday( LostLink, CHead + '    DataSource = dsLocal' + CNL + CTail ) ), 'still lost' );
end;

procedure TTestDfmLinkCheck.TestNames;
begin
  var sSeen: string := '|';
  for var eState := Low( TDfmLossToday ) to High( TDfmLossToday ) do
  begin
    var sName       := LossTodayName( eState );
    Assert.IsNotEmpty( sName );
    Assert.IsFalse( sSeen.Contains( '|' + sName + '|' ), 'unique: ' + sName );
    sSeen           := sSeen + sName + '|';
  end;
  for var eKind := Low( TDfmDanglingKind ) to High( TDfmDanglingKind ) do
  begin
    var sName       := DanglingKindName( eKind );
    Assert.IsNotEmpty( sName );
    Assert.IsFalse( sSeen.Contains( '|' + sName + '|' ), 'unique: ' + sName );
    sSeen           := sSeen + sName + '|';
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestDfmLinkCheck );

end.
