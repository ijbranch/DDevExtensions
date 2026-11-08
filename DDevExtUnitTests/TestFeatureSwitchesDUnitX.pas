unit TestFeatureSwitchesDUnitX;

/// <summary>
/// DUnitX tests for <c>FeatureSwitches</c>: parsing <c>DDevExtensions.DisabledFeatures</c>, the switch used to
/// turn features off one at a time when an IDE fault is being bisected.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Fixture for <c>TFeatureSwitches</c>.</summary>
  [ TestFixture ]
  TTestFeatureSwitches = class
  public
    /// <summary>Names are split on semicolons, trimmed, and matched without regard to case.</summary>
    [ Test ]
    procedure TestParsesTrimsAndIgnoresCase;
    /// <summary>
    /// A name that matches no feature is reported, so a mistyped switch does not silently leave the feature
    /// running while the tester believes it is off.
    /// </summary>
    [ Test ]
    procedure TestReportsNamesMatchingNoFeature;
    /// <summary>An empty or separator-only value disables nothing and reports nothing.</summary>
    [ Test ]
    procedure TestEmptyValueDisablesNothing;
    /// <summary>
    /// A space separates names, as it always has, so existing values keep working; double quotes group a name
    /// that contains one.
    /// </summary>
    [ Test ]
    procedure TestSpaceSeparatesAndQuotesGroup;
    /// <summary>
    /// A real feature that this build leaves out ( Old Palette on Delphi 13 ) is not reported as a typo: the variable
    /// is shared by every installed IDE version.
    /// </summary>
    [ Test ]
    procedure TestFeatureOfAnotherIdeVersionIsNotReported;
  end;

implementation

uses
  FeatureSwitches;

procedure TTestFeatureSwitches.TestParsesTrimsAndIgnoresCase;
begin
  var Switches      := TFeatureSwitches.Create( ' keybindings ;PathCompactor;;' );
  try
    Assert.IsTrue( Switches.IsDisabled( 'Keybindings' ) );
    Assert.IsTrue( Switches.IsDisabled( 'PathCompactor' ) );
    Assert.IsFalse( Switches.IsDisabled( 'MethodSeparators' ) );
  finally
    Switches.Free;
  end;
end;

procedure TTestFeatureSwitches.TestReportsNamesMatchingNoFeature;
begin
  var Switches      := TFeatureSwitches.Create( 'Keybindings;KeyBindigns;RegisterPlugins.pas' );
  try
    Switches.IsDisabled( 'Keybindings' );
    Switches.IsDisabled( 'MethodSeparators' );
    var Unknown     := Switches.UnknownNames;
    Assert.AreEqual( 2, Length( Unknown ) );
    Assert.AreEqual( 'KeyBindigns', Unknown[ 0 ] );
    Assert.AreEqual( 'RegisterPlugins.pas', Unknown[ 1 ] );
  finally
    Switches.Free;
  end;
end;

procedure TTestFeatureSwitches.TestEmptyValueDisablesNothing;
begin
  var Switches      := TFeatureSwitches.Create( ' ; ;' );
  try
    Assert.IsFalse( Switches.IsDisabled( 'Keybindings' ) );
    Assert.AreEqual( 0, Length( Switches.UnknownNames ) );
  finally
    Switches.Free;
  end;
end;

procedure TTestFeatureSwitches.TestSpaceSeparatesAndQuotesGroup;
begin
  var Switches      := TFeatureSwitches.Create( 'Keybindings PathCompactor;"Odd Name"' );
  try
    Assert.IsTrue( Switches.IsDisabled( 'Keybindings' ) );
    Assert.IsTrue( Switches.IsDisabled( 'PathCompactor' ) );
    Assert.IsTrue( Switches.IsDisabled( 'Odd Name' ) );
    Assert.IsFalse( Switches.IsDisabled( 'Odd' ) );
  finally
    Switches.Free;
  end;
end;

procedure TTestFeatureSwitches.TestFeatureOfAnotherIdeVersionIsNotReported;
begin
  var Switches      := TFeatureSwitches.Create( 'OldPalette;StartParameterTeam;ProjectMgrShortCuts;Editor;Typo' );
  try
    Switches.IsDisabled( 'Keybindings' ); // this build asks only about its own features
    var Unknown     := Switches.UnknownNames;
    Assert.AreEqual( 1, Length( Unknown ) );
    Assert.AreEqual( 'Typo', Unknown[ 0 ] );
  finally
    Switches.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestFeatureSwitches );

end.

