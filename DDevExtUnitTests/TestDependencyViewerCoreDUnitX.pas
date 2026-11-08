unit TestDependencyViewerCoreDUnitX;

/// <summary>
/// DUnitX test fixture for <c>DependencyViewerCore</c> - the uses-clause parser with conditional
/// compilation, cycle detection, and the layer rules.
/// </summary>
/// <remarks>
/// Units are fed as text through <c>ScanSource</c>, and include files through <c>OnReadSource</c>,
/// so nothing touches the disk or the IDE.
/// </remarks>

interface

uses
  DUnitX.TestFramework, System.SysUtils, System.Classes, DependencyViewerCore;

type
  /// <summary>DUnitX test fixture exercising the dependency viewer core.</summary>
  [TestFixture]
  TTestDependencyViewerCore = class
  private
    /// <summary>Scanner created per test.</summary>
    FScanner: TDependencyScanner;
    /// <summary>True when the named unit depends on the other.</summary>
    /// <param name="AFrom">The using unit.</param>
    /// <param name="ATo">The used unit.</param>
    /// <returns>True when AFrom's dependencies list ATo.</returns>
    function DependsOn( const AFrom, ATo: string ): Boolean;
  public
    /// <summary>Creates the scanner.</summary>
    [Setup]
    procedure Setup;
    /// <summary>Frees the scanner.</summary>
    [TearDown]
    procedure TearDown;
    /// <summary>Proves the compiler's own symbols count: a unit used under {$IFDEF MSWINDOWS} is a
    /// dependency for Win64, and the {$ELSE} branch is not.</summary>
    [Test]
    procedure TestPredefinedSymbolsAreDefined;
    /// <summary>Proves {$DEFINE} and {$UNDEF} inside the unit change what follows.</summary>
    [Test]
    procedure TestDefineAndUndefInTheUnitCount;
    /// <summary>Proves a {$DEFINE} in an {$I} include file counts.</summary>
    [Test]
    procedure TestIncludeFileDefinesCount;
    /// <summary>Proves {$IFOPT} ... {$ENDIF} does not close the enclosing {$IFDEF}.</summary>
    [Test]
    procedure TestIfOptKeepsTheConditionalStack;
    /// <summary>Proves a directive written in (*$ ... *) form is honoured like {$ ... }.</summary>
    [Test]
    procedure TestParenStarDirectiveIsHonoured;
    /// <summary>Proves two units using each other are ONE circular reference, not one per member.</summary>
    [Test]
    procedure TestEachCycleIsReportedOnce;
    /// <summary>Proves a group of three entangled units is one reference listing all three members.</summary>
    [Test]
    procedure TestGroupListsEveryMember;
    /// <summary>Proves a rule line matches its layer whatever the case it is written in.</summary>
    [Test]
    procedure TestRulesAreCaseInsensitive;
    /// <summary>Proves showing the rules in the Layers dialog and pressing OK keeps "no rules = allow
    /// all" for a layer that had no rule line.</summary>
    [Test]
    procedure TestRulesMatrixRoundTripKeepsAllowAll;
    /// <summary>Proves NOT binds to its own term: "not Defined(A) and Defined(B)" is (not A) and B.</summary>
    [Test]
    procedure TestNotBindsToItsTerm;
    /// <summary>Proves a comparison without spaces ( CompilerVersion>=36 ) is unknown and included,
    /// in $IF and in $ELSEIF alike, and is never taken for a define name.</summary>
    [Test]
    procedure TestComparisonIsUnknownAndIncluded;
    /// <summary>Proves both branches of $IFOPT count, the $ELSE as well as the $IFOPT.</summary>
    [Test]
    procedure TestIfOptElseBranchCounts;
    /// <summary>Proves a fully ticked row is stored as no rule line, and a rule line for a layer the
    /// file never defined survives the dialog.</summary>
    [Test]
    procedure TestAllTickedRowAndUnknownLayerRule;
  end;

implementation

uses
  System.Generics.Collections;

procedure TTestDependencyViewerCore.Setup;
begin
  FScanner := TDependencyScanner.Create;
end;

procedure TTestDependencyViewerCore.TearDown;
begin
  FreeAndNil( FScanner );
end;

function TTestDependencyViewerCore.DependsOn( const AFrom, ATo: string ): Boolean;
begin
  Result := False;
  var Info := FScanner.GetUnitInfo( AFrom );
  if ( Info = nil ) then
    Exit;
  for var Dep in Info.Dependencies do
    if SameText( Dep.UnitName, ATo ) then
      Exit( True );
end;

procedure TTestDependencyViewerCore.TestPredefinedSymbolsAreDefined;
begin
  for var sSymbol in PredefinedSymbols( 'Win64' ) do
    FScanner.AddDefine( sSymbol );
  FScanner.ScanSource( 'A', '', 'unit A; interface uses {$IFDEF MSWINDOWS} WinOnly {$ELSE} PosixOnly {$ENDIF}; ' +
    'implementation {$IF DEFINED(WIN64)} uses Wide; {$IFEND} end.' );
  Assert.IsTrue( DependsOn( 'A', 'WinOnly' ), 'MSWINDOWS is predefined' );
  Assert.IsFalse( DependsOn( 'A', 'PosixOnly' ), 'the ELSE branch is out' );
  Assert.IsTrue( DependsOn( 'A', 'Wide' ), 'WIN64 is predefined for Win64' );
end;

procedure TTestDependencyViewerCore.TestDefineAndUndefInTheUnitCount;
begin
  FScanner.AddDefine( 'OLD' );
  FScanner.ScanSource( 'A', '', 'unit A; {$DEFINE NEWER} {$UNDEF OLD} interface uses ' +
    '{$IFDEF NEWER} Newer, {$ENDIF} {$IFDEF OLD} Older, {$ENDIF} Always; implementation end.' );
  Assert.IsTrue( DependsOn( 'A', 'Newer' ), '$DEFINE took effect' );
  Assert.IsFalse( DependsOn( 'A', 'Older' ), '$UNDEF took effect' );
  Assert.IsTrue( DependsOn( 'A', 'Always' ) );
end;

procedure TTestDependencyViewerCore.TestIncludeFileDefinesCount;
begin
  FScanner.OnReadSource :=
    function( const AFileName: string; out AContent: string ): Boolean
    begin
      Result := SameText( ExtractFileName( AFileName ), 'Settings.inc' );
      if Result then
        AContent := '{$DEFINE USE_EXTRA}';
    end;
  FScanner.ScanSource( 'A', 'C:\Proj\A.pas', 'unit A; {$I Settings.inc} interface uses ' +
    '{$IFDEF USE_EXTRA} Extra, {$ENDIF} Base; implementation end.' );
  Assert.IsTrue( DependsOn( 'A', 'Extra' ), 'the include file defined USE_EXTRA' );
  Assert.IsTrue( DependsOn( 'A', 'Base' ) );
end;

procedure TTestDependencyViewerCore.TestIfOptKeepsTheConditionalStack;
begin
  FScanner.ScanSource( 'A', '', 'unit A; interface uses Base {$IFDEF NOT_SET} {$IFOPT R+} {$ENDIF} , Hidden ' +
    '{$ENDIF}; implementation end.' );
  Assert.IsTrue( DependsOn( 'A', 'Base' ) );
  Assert.IsFalse( DependsOn( 'A', 'Hidden' ), 'still inside IFDEF NOT_SET after the IFOPT block' );
end;

procedure TTestDependencyViewerCore.TestParenStarDirectiveIsHonoured;
begin
  FScanner.ScanSource( 'A', '', 'unit A; interface uses Base (*$IFDEF NOT_SET*) , Hidden (*$ENDIF*); ' +
    'implementation end.' );
  Assert.IsTrue( DependsOn( 'A', 'Base' ) );
  Assert.IsFalse( DependsOn( 'A', 'Hidden' ), '(*$IFDEF*) is a directive, not a comment' );
end;

procedure TTestDependencyViewerCore.TestEachCycleIsReportedOnce;
begin
  FScanner.ScanSource( 'A', '', 'unit A; interface implementation uses B; end.' );
  FScanner.ScanSource( 'B', '', 'unit B; interface implementation uses A; end.' );
  FScanner.Analyse;
  Assert.AreEqual( 1, FScanner.CircularReferences.Count, 'A<->B is one circular reference' );
end;

procedure TTestDependencyViewerCore.TestGroupListsEveryMember;
begin
  FScanner.ScanSource( 'A', '', 'unit A; interface uses B; implementation end.' );
  FScanner.ScanSource( 'B', '', 'unit B; interface uses C; implementation uses A; end.' );
  FScanner.ScanSource( 'C', '', 'unit C; interface implementation uses A, B; end.' );
  FScanner.Analyse;
  Assert.AreEqual( 1, FScanner.CircularReferences.Count, 'one entangled group' );
  var Ref := FScanner.CircularReferences[ 0 ];
  Assert.AreEqual( 3, Length( Ref.Members ) );
  Assert.AreEqual( 'A', Ref.Members[ 0 ] );
  Assert.AreEqual( 'C', Ref.Members[ 2 ] );
  Assert.IsTrue( SameText( Ref.Steps[ 0 ].UnitName, Ref.Steps[ High( Ref.Steps ) ].UnitName ), 'the chain closes' );
end;

procedure TTestDependencyViewerCore.TestRulesAreCaseInsensitive;
begin
  var Config := TLayerConfig.Create( '' );
  var Lines  := TStringList.Create;
  try
    Lines.Text := '[Layers]'#13#10'UI=Frm*'#13#10'Core=*Utils'#13#10'Business=*Logic'#13#10 +
      '[Rules]'#13#10'ui=Core';
    Config.LoadFromStrings( Lines );
    Assert.IsTrue( Config.IsDependencyAllowed( 'UI', 'Core' ) );
    Assert.IsFalse( Config.IsDependencyAllowed( 'UI', 'Business' ), 'the "ui" rule applies to layer UI' );
  finally
    Lines.Free;
    Config.Free;
  end;
end;

procedure TTestDependencyViewerCore.TestRulesMatrixRoundTripKeepsAllowAll;
begin
  var Config := TLayerConfig.Create( '' );
  var Lines  := TStringList.Create;
  try
    Lines.Text := '[Layers]'#13#10'UI=Frm*'#13#10'Core=*Utils'#13#10'[Rules]'#13#10'Core=';
    Config.LoadFromStrings( Lines );
    Assert.IsTrue( Config.IsDependencyAllowed( 'UI', 'Core' ), 'no rule line for UI: all allowed' );

    var Names: TArray<string> := [ 'UI', 'Core' ];
    var Matrix := LayerRulesMatrix( Config, Names );
    ApplyLayerRulesMatrix( Config, Names, Matrix );
    Assert.IsTrue( Config.IsDependencyAllowed( 'UI', 'Core' ), 'unchanged dialog, unchanged meaning' );
    Assert.IsFalse( Config.IsDependencyAllowed( 'Core', 'UI' ), 'an explicit empty rule stays empty' );
  finally
    Lines.Free;
    Config.Free;
  end;
end;

procedure TTestDependencyViewerCore.TestNotBindsToItsTerm;
begin
  FScanner.AddDefine( 'B' );
  FScanner.ScanSource( 'X', '', 'unit X; interface uses {$IF not Defined(A) and Defined(B)} Yes, {$IFEND} ' +
    '{$IF not Defined(B) and Defined(A)} No, {$IFEND} Base; implementation end.' );
  Assert.IsTrue( DependsOn( 'X', 'Yes' ), '(not A) and B is true' );
  Assert.IsFalse( DependsOn( 'X', 'No' ), '(not B) and A is false' );
end;

procedure TTestDependencyViewerCore.TestComparisonIsUnknownAndIncluded;
begin
  FScanner.ScanSource( 'X', '', 'unit X; interface uses {$IF CompilerVersion>=36} Newer, {$IFEND} ' +
    '{$IF Defined(NOT_SET)} Never, {$ELSEIF RTLVersion>=36} ViaElseIf, {$IFEND} Base; implementation end.' );
  Assert.IsTrue( DependsOn( 'X', 'Newer' ), 'a comparison is unknown, so included' );
  Assert.IsFalse( DependsOn( 'X', 'Never' ) );
  Assert.IsTrue( DependsOn( 'X', 'ViaElseIf' ), 'unknown in $ELSEIF is included as in $IF' );
end;

procedure TTestDependencyViewerCore.TestIfOptElseBranchCounts;
begin
  FScanner.ScanSource( 'X', '', 'unit X; interface uses {$IFOPT R+} Checked, {$ELSE} Unchecked, {$ENDIF} Base; ' +
    'implementation end.' );
  Assert.IsTrue( DependsOn( 'X', 'Checked' ) );
  Assert.IsTrue( DependsOn( 'X', 'Unchecked' ), 'the switch is unknown: both branches count' );
end;

procedure TTestDependencyViewerCore.TestAllTickedRowAndUnknownLayerRule;
begin
  var Config := TLayerConfig.Create( '' );
  var Lines  := TStringList.Create;
  try
    Lines.Text := '[Layers]'#13#10'UI=Frm*'#13#10'Core=*Utils'#13#10'[Rules]'#13#10'UI=Core'#13#10 +
      'Core='#13#10'Ghost=Core';
    Config.LoadFromStrings( Lines );

    // What the Layers dialog does on OK: redefine the layers, then store the ticks.
    var Names: TArray<string> := [ 'UI', 'Core' ];
    var Matrix := LayerRulesMatrix( Config, Names );
    Config.ClearLayers;
    Config.AddLayer( 'UI', [ 'Frm*' ] );
    Config.AddLayer( 'Core', [ '*Utils' ] );
    ApplyLayerRulesMatrix( Config, Names, Matrix );

    Config.SaveToStrings( Lines );
    var iRules := Lines.IndexOf( '[Rules]' );
    Assert.IsTrue( iRules > 0 );
    for var I := iRules + 1 to Lines.Count - 1 do
      Assert.IsFalse( Lines[ I ].StartsWith( 'UI=' ), 'every box ticked: no rule line' );
    Assert.IsTrue( Config.IsDependencyAllowed( 'UI', 'Core' ) );
    Assert.AreEqual( 'Core', Lines.Values[ 'Ghost' ], 'a rule for an undefined layer is kept' );
    Assert.IsFalse( Config.IsDependencyAllowed( 'Core', 'UI' ), 'the explicit empty rule stays' );
  finally
    Lines.Free;
    Config.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestDependencyViewerCore );

end.
