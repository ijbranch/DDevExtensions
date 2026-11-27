unit TestDfmNoiseMeasureCoreDUnitX;

/// <summary>
/// DUnitX fixture for <c>DfmNoiseMeasure.Core</c>, the comparison behind the DFM noise
/// measurement: each test feeds two hand-written DFM texts and asserts the exact changes and the
/// category each is counted under, so the tool's report is proved, not assumed.
/// </summary>

interface

uses
  DUnitX.TestFramework, System.SysUtils, DfmNoiseMeasure.Core;

type
  /// <summary>Tests of <c>CompareDfmText</c>, <c>ClassifyChange</c> and <c>RoundTripsExactly</c>.</summary>
  [ TestFixture ]
  TTestDfmNoiseMeasureCore = class
  public
    /// <summary>Proves two identical texts give no change at all, so an unchanged save is not counted.</summary>
    [ Test ]
    procedure TestIdenticalTextsGiveNoChanges;
    /// <summary>
    /// Proves an added <c>ExplicitWidth</c>, <c>TextHeight</c> and <c>PixelsPerInch</c> are each found with the
    /// nested component's dotted path and counted as known IDE noise.
    /// </summary>
    [ Test ]
    procedure TestKnownNoiseIsFoundAndClassified;
    /// <summary>
    /// Proves a removed <c>DataSource = dmX.dsY</c> counts as an other-module link removed, while a removed
    /// link to a component of the same form ( no dot ) and a removed <c>ImageIndex</c> do not.
    /// </summary>
    [ Test ]
    procedure TestOtherModuleLinkRemoved;
    /// <summary>
    /// Proves swapped children are one children-reordered change and swapped properties one
    /// properties-reordered change, with no added or removed entries.
    /// </summary>
    [ Test ]
    procedure TestReorderingIsOneChangeEach;
    /// <summary>
    /// Proves a shifted <c>[n]</c> index is an index change, while an added and a removed component are
    /// component changes and not noise.
    /// </summary>
    [ Test ]
    procedure TestOrderIndexAndComponentChanges;
    /// <summary>
    /// Proves the byte round trip catches a one-byte difference: the bytes of an ANSI character
    /// above 127 come back unchanged, and a file without its final line break is reported, not passed.
    /// </summary>
    [ Test ]
    procedure TestRoundTripIsByteExact;
  end;

implementation

const
  CBase =
    'object Form1: TForm1' + #13#10 +
    '  Caption = ''Main''' + #13#10 +
    '  object Panel1: TPanel' + #13#10 +
    '    Left = 8' + #13#10 +
    '    object Button1: TButton' + #13#10 +
    '      Left = 4' + #13#10 +
    '      DataSource = dmX.dsY' + #13#10 +
    '      PopupMenu = PopupMenu1' + #13#10 +
    '      ImageIndex = 3' + #13#10 +
    '    end' + #13#10 +
    '    object Button2: TButton' + #13#10 +
    '      Left = 90' + #13#10 +
    '    end' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;

procedure TTestDfmNoiseMeasureCore.TestIdenticalTextsGiveNoChanges;
begin
  Assert.AreEqual<Integer>( 0, Length( CompareDfmText( CBase, CBase ) ) );
end;

procedure TTestDfmNoiseMeasureCore.TestKnownNoiseIsFoundAndClassified;
begin
  var sNew          := StringReplace( CBase, '      Left = 4' + #13#10, '      Left = 4' + #13#10 + '      ExplicitWidth = 75' + #13#10, [] );
  sNew              := StringReplace( sNew, '  Caption = ''Main''' + #13#10,
    '  Caption = ''Main''' + #13#10 + '  TextHeight = 15' + #13#10 + '  PixelsPerInch = 96' + #13#10, [] );

  var aChanges      := CompareDfmText( CBase, sNew );
  Assert.AreEqual<Integer>( 3, Length( aChanges ), 'three added properties' );
  for var rChange in aChanges do
  begin
    Assert.IsTrue( rChange.Kind = dckPropertyAdded, rChange.PropName + ' is added' );
    Assert.IsTrue( IsKnownIdeNoise( rChange.Category ), rChange.PropName + ' is known noise' );
    if rChange.PropName = 'ExplicitWidth' then
    begin
      Assert.AreEqual( 'Form1.Panel1.Button1', rChange.Path, False );
      Assert.IsTrue( rChange.Category = ncExplicit, 'ExplicitWidth category' );
    end
    else if rChange.PropName = 'TextHeight' then
      Assert.IsTrue( rChange.Category = ncTextHeight, 'TextHeight category' )
    else
    begin
      Assert.AreEqual( 'PixelsPerInch', rChange.PropName, False );
      Assert.IsTrue( rChange.Category = ncPixelsPerInch, 'PixelsPerInch category' );
    end;
  end;
end;

procedure TTestDfmNoiseMeasureCore.TestOtherModuleLinkRemoved;
begin
  var sNew          := StringReplace( CBase, '      DataSource = dmX.dsY' + #13#10, '', [] );
  sNew              := StringReplace( sNew, '      PopupMenu = PopupMenu1' + #13#10, '', [] );
  sNew              := StringReplace( sNew, '      ImageIndex = 3' + #13#10, '', [] );

  var aChanges      := CompareDfmText( CBase, sNew );
  Assert.AreEqual<Integer>( 3, Length( aChanges ), 'three removed properties' );
  Assert.AreEqual( 'DataSource', aChanges[ 0 ].PropName, False );
  Assert.IsTrue( aChanges[ 0 ].Category = ncModuleLinkLost, 'a dotted link is another module''s' );
  Assert.AreEqual( 'dmX.dsY', aChanges[ 0 ].OldValue, False );
  Assert.AreEqual( 'PopupMenu', aChanges[ 1 ].PropName, False );
  Assert.IsTrue( aChanges[ 1 ].Category = ncOther, 'a link inside the form is not another module''s' );
  Assert.AreEqual( 'ImageIndex', aChanges[ 2 ].PropName, False );
  Assert.IsTrue( aChanges[ 2 ].Category = ncImageLinkLost, 'ImageIndex removed' );
  Assert.IsFalse( IsKnownIdeNoise( ncModuleLinkLost ), 'a lost link is not counted as harmless noise' );
end;

procedure TTestDfmNoiseMeasureCore.TestReorderingIsOneChangeEach;
begin
  var sButton1      :=
    '    object Button1: TButton' + #13#10 +
    '      Left = 4' + #13#10 +
    '      DataSource = dmX.dsY' + #13#10 +
    '      PopupMenu = PopupMenu1' + #13#10 +
    '      ImageIndex = 3' + #13#10 +
    '    end' + #13#10;
  var sButton2      :=
    '    object Button2: TButton' + #13#10 +
    '      Left = 90' + #13#10 +
    '    end' + #13#10;
  var sSwapped      := StringReplace( CBase, sButton1 + sButton2, sButton2 + sButton1, [] );
  sSwapped          := StringReplace( sSwapped, '      Left = 4' + #13#10 + '      DataSource = dmX.dsY' + #13#10,
    '      DataSource = dmX.dsY' + #13#10 + '      Left = 4' + #13#10, [] );
  Assert.AreNotEqual( CBase, sSwapped, 'the test text was rearranged' );

  var aChanges      := CompareDfmText( CBase, sSwapped );
  Assert.AreEqual<Integer>( 2, Length( aChanges ), 'one reorder of each kind' );
  Assert.IsTrue( aChanges[ 0 ].Kind = dckPropertiesReordered, 'Button1 properties reordered' );
  Assert.AreEqual( 'Form1.Panel1.Button1', aChanges[ 0 ].Path, False );
  Assert.IsTrue( aChanges[ 0 ].Category = ncPropertyOrder, 'property order category' );
  Assert.IsTrue( aChanges[ 1 ].Kind = dckChildrenReordered, 'Panel1 children reordered' );
  Assert.AreEqual( 'Form1.Panel1', aChanges[ 1 ].Path, False );
  Assert.IsTrue( aChanges[ 1 ].Category = ncChildOrder, 'child order category' );
end;

procedure TTestDfmNoiseMeasureCore.TestOrderIndexAndComponentChanges;
begin
  var sOld          :=
    'inherited Form2: TForm2' + #13#10 +
    '  inherited Panel1: TPanel [1]' + #13#10 +
    '  end' + #13#10 +
    '  object Old1: TLabel' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;
  var sNew          :=
    'inherited Form2: TForm2' + #13#10 +
    '  inherited Panel1: TPanel [2]' + #13#10 +
    '  end' + #13#10 +
    '  object New1: TEdit' + #13#10 +
    '  end' + #13#10 +
    'end' + #13#10;

  var aChanges      := CompareDfmText( sOld, sNew );
  Assert.AreEqual<Integer>( 3, Length( aChanges ), 'index change, removal, addition' );
  Assert.IsTrue( aChanges[ 0 ].Kind = dckOrderIndexChanged, 'index changed' );
  Assert.AreEqual( '1', aChanges[ 0 ].OldValue, False );
  Assert.AreEqual( '2', aChanges[ 0 ].NewValue, False );
  Assert.IsTrue( aChanges[ 0 ].Category = ncOrderIndex, 'index category' );
  Assert.IsTrue( aChanges[ 1 ].Kind = dckComponentRemoved, 'Old1 removed' );
  Assert.AreEqual( 'Form2.Old1', aChanges[ 1 ].Path, False );
  Assert.IsTrue( aChanges[ 2 ].Kind = dckComponentAdded, 'New1 added' );
  Assert.AreEqual( 'TEdit', aChanges[ 2 ].NewValue, False );
  Assert.IsFalse( IsKnownIdeNoise( aChanges[ 2 ].Category ), 'an added component is an edit' );
end;

procedure TTestDfmNoiseMeasureCore.TestRoundTripIsByteExact;
var
  sDifference       : string;
begin
  var aBytes        := TEncoding.ANSI.GetBytes( 'object Form1: TForm1' + #13#10 + '  Caption = ''Caf'#233'''' + #13#10 + 'end' + #13#10 );
  Assert.IsTrue( RoundTripsExactly( aBytes, sDifference ), 'ANSI text comes back unchanged: ' + sDifference );
  Assert.AreEqual( '', sDifference, False );
  Assert.IsFalse( IsBinaryDfm( aBytes ), 'text is not binary' );

  var aNoFinalBreak := TEncoding.ANSI.GetBytes( 'object Form1: TForm1' + #13#10 + 'end' );
  Assert.IsFalse( RoundTripsExactly( aNoFinalBreak, sDifference ), 'a missing final line break is a difference' );
  Assert.AreNotEqual( '', sDifference, 'the difference is described' );

  Assert.IsTrue( IsBinaryDfm( TBytes.Create( Ord( 'T' ), Ord( 'P' ), Ord( 'F' ), Ord( '0' ), 0 ) ), 'TPF0 is binary' );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestDfmNoiseMeasureCore );

end.
