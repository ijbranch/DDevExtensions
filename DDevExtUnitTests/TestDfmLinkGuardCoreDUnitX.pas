unit TestDfmLinkGuardCoreDUnitX;

/// <summary>
/// DUnitX fixture for <c>DfmLinkGuardCore</c>, the decision behind the DFM Link Guard: each test
/// feeds the text of a form before and after a save and asserts exactly which links to another
/// module's components are reported as lost, so a missed loss and a false alarm both fail a test.
/// </summary>

interface

uses
  DUnitX.TestFramework, System.SysUtils, gllDfmCompare, DfmLinkGuardCore;

type
  /// <summary>Tests of <c>FindLostModuleLinks</c>, <c>DfmRootName</c>, <c>DfmDeclaresComponent</c> and the message.</summary>
  [ TestFixture ]
  TTestDfmLinkGuardCore = class
  public
    /// <summary>
    /// Proves the case the guard exists for: a grid's <c>DataSource = dmMain.dsCustomers</c> removed while the
    /// grid stays is reported once, with the grid's path, the property, the value and both halves of the name.
    /// </summary>
    [ Test ]
    procedure TestRemovedLinkIsReported;
    /// <summary>Proves the existence check is asked with the module and component names, and a False answer suppresses the report.</summary>
    [ Test ]
    procedure TestDeletedTargetIsNotReported;
    /// <summary>Proves a nil existence check reports every candidate rather than none.</summary>
    [ Test ]
    procedure TestNilTargetCheckReportsCandidate;
    /// <summary>Proves deleting the component that held the link is an edit, not a lost link.</summary>
    [ Test ]
    procedure TestDeletedHolderIsNotReported;
    /// <summary>
    /// Proves a link whose value still appears elsewhere in the new text ( a renamed property, or moved to
    /// another component ) is not reported.
    /// </summary>
    [ Test ]
    procedure TestMovedLinkIsNotReported;
    /// <summary>Proves a link changed to another target, and a removed link within the same form ( no dot ), are not reported.</summary>
    [ Test ]
    procedure TestChangedAndLocalLinksAreNotReported;
    /// <summary>Proves identical texts, and noise-only changes, report nothing and never ask the existence check.</summary>
    [ Test ]
    procedure TestNoiseOnlySaveReportsNothing;
    /// <summary>Proves the root name is read from the header, and a component is found at any depth but the root itself is not.</summary>
    [ Test ]
    procedure TestRootNameAndDeclaredComponents;
    /// <summary>Proves the warning names the component path, the property and the removed value.</summary>
    [ Test ]
    procedure TestMessageNamesTheLink;
    /// <summary>
    /// Proves a link lost from one grid is reported although a second grid still holds the same value: the
    /// value surviving elsewhere hides a loss only when it appears as often as before.
    /// </summary>
    [ Test ]
    procedure TestLossBesideSurvivingTwinIsReported;
    /// <summary>Proves a text with no root object raises <c>EDfmCompareError</c>, not an access violation.</summary>
    [ Test ]
    procedure TestTextWithoutRootRaises;
  end;

implementation

const
  /// <summary>A form whose grid is bound to a data module's data source.</summary>
  COld =
    'object frmMain: TfrmMain' + #13#10 +
    '  Caption = ''Main''' + #13#10 +
    '  object pnlTop: TPanel' + #13#10 +
    '    Left = 0' + #13#10 +
    '    object grdCustomers: TDBGrid' + #13#10 +
    '      Left = 8' + #13#10 +
    '      DataSource = dmMain.dsCustomers' + #13#10 +
    '      TabOrder = 0' + #13#10 +
    '    end' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;

  /// <summary><see cref="COld"/> after a save that dropped the grid's binding.</summary>
  CLost =
    'object frmMain: TfrmMain' + #13#10 +
    '  Caption = ''Main''' + #13#10 +
    '  object pnlTop: TPanel' + #13#10 +
    '    Left = 0' + #13#10 +
    '    object grdCustomers: TDBGrid' + #13#10 +
    '      Left = 8' + #13#10 +
    '      TabOrder = 0' + #13#10 +
    '    end' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;

/// <summary>An existence check that always answers yes.</summary>
/// <returns>A check returning True.</returns>
function AlwaysExists: TDfmLinkTargetExists;
begin
  Result            :=
    function( const ModuleName, ComponentName: string ): Boolean
    begin
      Result        := True;
    end;
end;

procedure TTestDfmLinkGuardCore.TestRemovedLinkIsReported;
begin
  var aLinks        := FindLostModuleLinks( COld, CLost, AlwaysExists() );
  Assert.AreEqual( 1, Integer( Length( aLinks ) ), 'one lost link' );
  Assert.AreEqual( 'frmMain.pnlTop.grdCustomers', aLinks[ 0 ].Path, False );
  Assert.AreEqual( 'DataSource', aLinks[ 0 ].PropName, False );
  Assert.AreEqual( 'dmMain.dsCustomers', aLinks[ 0 ].Value, False );
  Assert.AreEqual( 'dmMain', aLinks[ 0 ].ModuleName, False );
  Assert.AreEqual( 'dsCustomers', aLinks[ 0 ].ComponentName, False );
end;

procedure TTestDfmLinkGuardCore.TestLossBesideSurvivingTwinIsReported;
const
  CTwinsOld =
    'object frmMain: TfrmMain' + #13#10 +
    '  object grdA: TDBGrid' + #13#10 +
    '    DataSource = dmMain.dsCustomers' + #13#10 +
    '  end' + #13#10 +
    '  object grdB: TDBGrid' + #13#10 +
    '    DataSource = dmMain.dsCustomers' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;
  CTwinsNew =
    'object frmMain: TfrmMain' + #13#10 +
    '  object grdA: TDBGrid' + #13#10 +
    '  end' + #13#10 +
    '  object grdB: TDBGrid' + #13#10 +
    '    DataSource = dmMain.dsCustomers' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;
begin
  var aLinks        := FindLostModuleLinks( CTwinsOld, CTwinsNew, AlwaysExists() );
  Assert.AreEqual( 1, Integer( Length( aLinks ) ), 'grdA lost its link' );
  Assert.AreEqual( 'frmMain.grdA', aLinks[ 0 ].Path, False );
end;

procedure TTestDfmLinkGuardCore.TestTextWithoutRootRaises;
begin
  Assert.WillRaise(
    procedure
    begin
      FindLostModuleLinks( COld, '', AlwaysExists() );
    end, EDfmCompareError );
end;

procedure TTestDfmLinkGuardCore.TestDeletedTargetIsNotReported;
begin
  var sAsked        := '';
  var aLinks        := FindLostModuleLinks( COld, CLost,
    function( const ModuleName, ComponentName: string ): Boolean
    begin
      sAsked        := sAsked + ModuleName + '/' + ComponentName + ';';
      Result        := False;
    end );
  Assert.AreEqual( 0, Integer( Length( aLinks ) ), 'a deleted target is a deliberate edit' );
  Assert.IsTrue( sAsked = 'dmMain/dsCustomers;', 'asked once, with both names: ' + sAsked );
end;

procedure TTestDfmLinkGuardCore.TestNilTargetCheckReportsCandidate;
begin
  Assert.AreEqual( 1, Integer( Length( FindLostModuleLinks( COld, CLost, nil ) ) ) );
end;

procedure TTestDfmLinkGuardCore.TestDeletedHolderIsNotReported;
const
  CNoGrid =
    'object frmMain: TfrmMain' + #13#10 +
    '  Caption = ''Main''' + #13#10 +
    '  object pnlTop: TPanel' + #13#10 +
    '    Left = 0' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;
begin
  Assert.AreEqual( 0, Integer( Length( FindLostModuleLinks( COld, CNoGrid, AlwaysExists() ) ) ) );
end;

procedure TTestDfmLinkGuardCore.TestMovedLinkIsNotReported;
const
  CRenamedProp =
    'object frmMain: TfrmMain' + #13#10 +
    '  Caption = ''Main''' + #13#10 +
    '  object pnlTop: TPanel' + #13#10 +
    '    Left = 0' + #13#10 +
    '    object grdCustomers: TDBGrid' + #13#10 +
    '      Left = 8' + #13#10 +
    '      DataLink = dmMain.dsCustomers' + #13#10 +
    '      TabOrder = 0' + #13#10 +
    '    end' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;
  CMovedToPanel =
    'object frmMain: TfrmMain' + #13#10 +
    '  Caption = ''Main''' + #13#10 +
    '  object pnlTop: TPanel' + #13#10 +
    '    Left = 0' + #13#10 +
    '    DataSource = dmMain.dsCustomers' + #13#10 +
    '    object grdCustomers: TDBGrid' + #13#10 +
    '      Left = 8' + #13#10 +
    '      TabOrder = 0' + #13#10 +
    '    end' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;
begin
  Assert.AreEqual( 0, Integer( Length( FindLostModuleLinks( COld, CRenamedProp, AlwaysExists() ) ) ), 'renamed property' );
  Assert.AreEqual( 0, Integer( Length( FindLostModuleLinks( COld, CMovedToPanel, AlwaysExists() ) ) ), 'moved component' );
end;

procedure TTestDfmLinkGuardCore.TestChangedAndLocalLinksAreNotReported;
const
  CChanged =
    'object frmMain: TfrmMain' + #13#10 +
    '  Caption = ''Main''' + #13#10 +
    '  object pnlTop: TPanel' + #13#10 +
    '    Left = 0' + #13#10 +
    '    object grdCustomers: TDBGrid' + #13#10 +
    '      Left = 8' + #13#10 +
    '      DataSource = dmMain.dsOrders' + #13#10 +
    '      TabOrder = 0' + #13#10 +
    '    end' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;
  CLocalOld =
    'object frmMain: TfrmMain' + #13#10 +
    '  object grdCustomers: TDBGrid' + #13#10 +
    '    DataSource = dsLocal' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;
  CLocalNew =
    'object frmMain: TfrmMain' + #13#10 +
    '  object grdCustomers: TDBGrid' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;
begin
  Assert.AreEqual( 0, Integer( Length( FindLostModuleLinks( COld, CChanged, AlwaysExists() ) ) ), 'changed target' );
  Assert.AreEqual( 0, Integer( Length( FindLostModuleLinks( CLocalOld, CLocalNew, AlwaysExists() ) ) ), 'same-form link' );
end;

procedure TTestDfmLinkGuardCore.TestNoiseOnlySaveReportsNothing;
const
  CNoise =
    'object frmMain: TfrmMain' + #13#10 +
    '  Caption = ''Main''' + #13#10 +
    '  TextHeight = 15' + #13#10 +
    '  object pnlTop: TPanel' + #13#10 +
    '    Left = 0' + #13#10 +
    '    ExplicitWidth = 640' + #13#10 +
    '    object grdCustomers: TDBGrid' + #13#10 +
    '      Left = 8' + #13#10 +
    '      DataSource = dmMain.dsCustomers' + #13#10 +
    '      TabOrder = 0' + #13#10 +
    '    end' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;
begin
  var iAsked        := 0;
  var fnCount       : TDfmLinkTargetExists :=
    function( const ModuleName, ComponentName: string ): Boolean
    begin
      Inc( iAsked );
      Result        := True;
    end;
  Assert.AreEqual( 0, Integer( Length( FindLostModuleLinks( COld, COld, fnCount ) ) ), 'identical' );
  Assert.AreEqual( 0, Integer( Length( FindLostModuleLinks( COld, CNoise, fnCount ) ) ), 'noise only' );
  Assert.AreEqual( 0, iAsked, 'no candidate, so no existence check' );
end;

procedure TTestDfmLinkGuardCore.TestRootNameAndDeclaredComponents;
const
  CModule =
    'object dmMain: TdmMain' + #13#10 +
    '  OldCreateOrder = False' + #13#10 +
    '  object qryCustomers: TFDQuery' + #13#10 +
    '    object qryCustomersName: TStringField' + #13#10 +
    '      FieldName = ''Name''' + #13#10 +
    '    end' + #13#10 +
    '  end' + #13#10 +
    '  object dsCustomers: TDataSource' + #13#10 +
    '    DataSet = qryCustomers' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;
begin
  Assert.IsTrue( DfmRootName( CModule ) = 'dmMain', 'root name: ' + DfmRootName( CModule ) );
  Assert.IsTrue( DfmDeclaresComponent( CModule, 'dsCustomers' ), 'top-level child' );
  Assert.IsTrue( DfmDeclaresComponent( CModule, 'QRYCUSTOMERSNAME' ), 'nested, any case' );
  Assert.IsFalse( DfmDeclaresComponent( CModule, 'dsOrders' ), 'absent' );
  Assert.IsFalse( DfmDeclaresComponent( CModule, 'dmMain' ), 'the root is the module, not a component of it' );
end;

procedure TTestDfmLinkGuardCore.TestMessageNamesTheLink;
begin
  var aLinks        := FindLostModuleLinks( COld, CLost, AlwaysExists() );
  Assert.AreEqual( 1, Integer( Length( aLinks ) ) );
  var sMessage      := FormatLostLinkMessage( aLinks[ 0 ] );
  Assert.Contains( sMessage, 'frmMain.pnlTop.grdCustomers.DataSource', False );
  Assert.Contains( sMessage, 'dmMain.dsCustomers', False );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestDfmLinkGuardCore );

end.
