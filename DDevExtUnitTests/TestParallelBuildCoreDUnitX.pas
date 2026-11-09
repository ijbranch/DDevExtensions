unit TestParallelBuildCoreDUnitX;

/// <summary>
/// DUnitX test fixture for <c>ParallelBuildCore</c>: the pure rules behind "Parallel Build All".  It proves
/// what is read from a <c>.dproj</c> and a <c>.groupproj</c>, which projects a plan makes wait for which,
/// what the schedule lets run together, the exact command lines, and how compiler output is classified.
/// The fixture is registered in this unit's initialization section.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising the Parallel Build All core rules.</summary>
  [ TestFixture ]
  TTestParallelBuildCore = class
  public
    /// <summary>Proves <c>AppType</c> maps to a kind, and that a console or unknown type builds as an application.</summary>
    [ Test ]
    procedure TestProjectKind;
    /// <summary>Proves a property set only in Base is found, with <c>$(Platform)</c> and <c>$(Config)</c> replaced.</summary>
    [ Test ]
    procedure TestResolvePropertyFromBase;
    /// <summary>Proves a configuration's own value overrides Base, so Debug and Release can differ.</summary>
    [ Test ]
    procedure TestResolvePropertyConfigOverridesBase;
    /// <summary>Proves a platform-specific group applies only to its platform.</summary>
    [ Test ]
    procedure TestResolvePropertyPlatformGroup;
    /// <summary>Proves a configuration inherits from its parent configuration, not only from Base.</summary>
    [ Test ]
    procedure TestResolvePropertyParentChain;
    /// <summary>Proves an unset property resolves to an empty string rather than a neighbour's value.</summary>
    [ Test ]
    procedure TestResolvePropertyMissing;
    /// <summary>Proves the DCU key is the absolute folder, upper-cased, so two spellings of one folder collide.</summary>
    [ Test ]
    procedure TestDcuLockKeyResolvesRelativeFolder;
    /// <summary>Proves a project with no DCU folder set is keyed by its own folder, where its DCUs then go.</summary>
    [ Test ]
    procedure TestDcuLockKeyDefaultsToProjectFolder;
    /// <summary>Proves two projects in one folder with the same relative DCU folder get the same key.</summary>
    [ Test ]
    procedure TestDcuLockKeySharedFolderCollides;
    /// <summary>Proves the required packages are read from <c>.dcp</c> references, without path or extension.</summary>
    [ Test ]
    procedure TestRequiredPackages;
    /// <summary>Proves group members and their declared dependencies are read, including an empty element.</summary>
    [ Test ]
    procedure TestParseGroupProjects;
    /// <summary>Proves a dependency declared in the group makes the dependent project wait.</summary>
    [ Test ]
    procedure TestPlanHonoursGroupDependencies;
    /// <summary>Proves a package waits for the group's packages it requires and for no other package.</summary>
    [ Test ]
    procedure TestPlanPackageRequires;
    /// <summary>Proves every application waits for every package in the group.</summary>
    [ Test ]
    procedure TestPlanApplicationsWaitForPackages;
    /// <summary>Proves independent applications wait for nothing, which is what lets them build together.</summary>
    [ Test ]
    procedure TestPlanIndependentApplications;
    /// <summary>Proves no more projects run at once than the worker count.</summary>
    [ Test ]
    procedure TestScheduleRespectsWorkerLimit;
    /// <summary>Proves two projects that share a DCU folder never run together, and the second runs once the first ends.</summary>
    [ Test ]
    procedure TestScheduleSerialisesSharedDcuFolder;
    /// <summary>Proves a project starts only after the project it depends on has succeeded.</summary>
    [ Test ]
    procedure TestScheduleWaitsForDependency;
    /// <summary>Proves a failure skips every project that depends on it, directly or through another, and says why.</summary>
    [ Test ]
    procedure TestScheduleFailureSkipsDependents;
    /// <summary>Proves a failure does not stop projects that do not depend on it.</summary>
    [ Test ]
    procedure TestScheduleFailureLeavesIndependentProjects;
    /// <summary>Proves projects that depend on each other in a circle are skipped, so the build ends rather than hangs.</summary>
    [ Test ]
    procedure TestScheduleCircularDependenciesSkipped;
    /// <summary>Proves a cancel skips what has not started and leaves a running project to finish.</summary>
    [ Test ]
    procedure TestScheduleCancelWaiting;
    /// <summary>Proves reporting a project that is not running as finished is refused.</summary>
    [ Test ]
    procedure TestScheduleFinishedNeedsRunningProject;
    /// <summary>Proves the worker count for every case: automatic, capped at eight, a setting, and the upper limit.</summary>
    [ Test ]
    procedure TestEffectiveWorkerCount;
    /// <summary>Proves arguments are quoted only when needed and by the rules <c>CommandLineToArgvW</c> reverses.</summary>
    [ Test ]
    procedure TestQuoteArgument;
    /// <summary>Proves the exact MSBuild command line, including a project path with a space.</summary>
    [ Test ]
    procedure TestMSBuildCommandLine;
    /// <summary>Proves the exact <c>ecc32</c> command line.</summary>
    [ Test ]
    procedure TestEcc32CommandLine;
    /// <summary>Proves <c>set</c> output becomes name/value entries and lines without a name are dropped.</summary>
    [ Test ]
    procedure TestParseSetOutput;
    /// <summary>Proves a variable is found whatever its case, and a longer name with the same start is not mistaken for it.</summary>
    [ Test ]
    procedure TestEnvironmentValue;
    /// <summary>Proves the environment block is the entries each ended by #0.</summary>
    [ Test ]
    procedure TestEnvironmentBlock;
    /// <summary>Proves MSBuild is looked for in <c>FrameworkDir</c>, and is not invented when that is unset.</summary>
    [ Test ]
    procedure TestMSBuildExeFromEnvironment;
    /// <summary>Proves a compiler error line gives file, line, code and message, without the project suffix.</summary>
    [ Test ]
    procedure TestParseErrorLine;
    /// <summary>Proves a hint, which MSBuild prints as "Hint warning", is classified as a hint and not dropped.</summary>
    [ Test ]
    procedure TestParseHintLine;
    /// <summary>Proves warnings and fatal errors are classified by their code letter.</summary>
    [ Test ]
    procedure TestParseWarningAndFatalLines;
    /// <summary>Proves MSBuild's own errors and warnings, with and without a position, are recognised.</summary>
    [ Test ]
    procedure TestParseMSBuildLines;
    /// <summary>Proves ordinary build chatter that mentions "error" or "warning" is not a diagnostic.</summary>
    [ Test ]
    procedure TestParseIgnoresChatter;
    /// <summary>Proves a line printed twice is reported once, and that errors are detected in a list.</summary>
    [ Test ]
    procedure TestParseBuildOutput;
    /// <summary>Proves a DUnitX runner is recognised from its uses clause.</summary>
    [ Test ]
    procedure TestIsDUnitXRunner;
    /// <summary>Proves EurekaLog runs only when every condition holds; each condition is switched off in turn.</summary>
    [ Test ]
    procedure TestShouldRunEurekaLog;
    /// <summary>Proves a stub profile's <c>ExternalConfig</c> is followed with APPDATA expanded, and a full profile is itself.</summary>
    [ Test ]
    procedure TestEurekaLogProfilePath;
    /// <summary>Proves the built file is found from the exe output folder, as an exe or a DLL.</summary>
    [ Test ]
    procedure TestProjectOutputFile;
    /// <summary>Proves the default <c>ecc32</c> path is EurekaLog's package folder for the given IDE.</summary>
    [ Test ]
    procedure TestDefaultEcc32Path;
  end;

implementation

uses
  System.SysUtils,
  ParallelBuildCore;

const
  /// <summary>A minimal .dproj with Base, Debug, Release and a Beta configuration whose parent is Release.</summary>
  SAMPLE_DPROJ =
    '<Project>'#13#10 +
    '  <PropertyGroup>'#13#10 +
    '    <AppType>Application</AppType>'#13#10 +
    '  </PropertyGroup>'#13#10 +
    '  <PropertyGroup Condition="''$(Config)''==''Base'' or ''$(Base)''!=''''">'#13#10 +
    '    <Base>true</Base>'#13#10 +
    '  </PropertyGroup>'#13#10 +
    '  <PropertyGroup Condition="''$(Base)''!=''''">'#13#10 +
    '    <DCC_DcuOutput>.\$(Platform)\$(Config)</DCC_DcuOutput>'#13#10 +
    '    <DCC_ExeOutput>..\bin</DCC_ExeOutput>'#13#10 +
    '  </PropertyGroup>'#13#10 +
    '  <PropertyGroup Condition="''$(Base_Win32)''!=''''">'#13#10 +
    '    <DCC_Define>ONLY32</DCC_Define>'#13#10 +
    '  </PropertyGroup>'#13#10 +
    '  <PropertyGroup Condition="''$(Cfg_1)''!=''''">'#13#10 +
    '    <DCC_ExeOutput>dbg</DCC_ExeOutput>'#13#10 +
    '  </PropertyGroup>'#13#10 +
    '  <PropertyGroup Condition="''$(Cfg_2_Win64)''!=''''">'#13#10 +
    '    <DCC_ExeOutput>rel64</DCC_ExeOutput>'#13#10 +
    '  </PropertyGroup>'#13#10 +
    '  <ItemGroup>'#13#10 +
    '    <BuildConfiguration Include="Base"><Key>Base</Key></BuildConfiguration>'#13#10 +
    '    <BuildConfiguration Include="Debug"><Key>Cfg_1</Key><CfgParent>Base</CfgParent></BuildConfiguration>'#13#10 +
    '    <BuildConfiguration Include="Release"><Key>Cfg_2</Key><CfgParent>Base</CfgParent></BuildConfiguration>'#13#10 +
    '    <BuildConfiguration Include="Beta"><Key>Cfg_3</Key><CfgParent>Cfg_2</CfgParent></BuildConfiguration>'#13#10 +
    '  </ItemGroup>'#13#10 +
    '</Project>';

/// <summary>Returns a .dproj text with the given AppType and, optionally, .dcp references.</summary>
/// <param name="AAppType">The AppType value.</param>
/// <param name="ADcpReferences">Package names to reference as <c>.dcp</c>.</param>
/// <returns>The text.</returns>
function DprojOf( const AAppType: string; const ADcpReferences: array of string ): string;
begin

  Result := '<Project><PropertyGroup><AppType>' + AAppType + '</AppType></PropertyGroup><ItemGroup>';

  for var sName in ADcpReferences do
    Result := Result + '<DCCReference Include="' + sName + '.dcp"/>';

  Result := Result + '</ItemGroup></Project>';

end;

/// <summary>Builds one plan input.</summary>
/// <param name="AFileName">The .dproj path.</param>
/// <param name="ADprojText">The .dproj text.</param>
/// <returns>The input, for Release and Win64.</returns>
function InputOf( const AFileName, ADprojText: string ): TPlanInput;
begin

  Result.FileName  := AFileName;
  Result.DprojText := ADprojText;
  Result.Config    := 'Release';
  Result.Platform  := 'Win64';

end;

/// <summary>Builds a plan entry by hand, for the schedule tests.</summary>
/// <param name="AName">The project name.</param>
/// <param name="ADependsOn">The plan indexes it waits for.</param>
/// <param name="ALockKey">Its DCU key; empty gives it a key of its own.</param>
/// <returns>The entry.</returns>
function ProjectOf( const AName: string; const ADependsOn: array of Integer; const ALockKey: string = '' ): TParallelProject;
begin

  Result := Default( TParallelProject );
  Result.FileName := 'C:\G\' + AName + '\' + AName + '.dproj';
  Result.Config   := 'Release';
  Result.Platform := 'Win64';
  Result.LockKey  := ALockKey;

  if ALockKey = '' then Result.LockKey := 'C:\G\' + UpperCase( AName );

  SetLength( Result.DependsOn, Length( ADependsOn ) );

  for var iI := 0 to High( ADependsOn ) do
    Result.DependsOn[ iI ] := ADependsOn[ iI ];

end;

/// <summary>True when an integer array holds a value.</summary>
/// <param name="AValues">The array.</param>
/// <param name="AValue">The value.</param>
/// <returns>True when it is there.</returns>
function Holds( const AValues: TArray<Integer>; AValue: Integer ): Boolean;
begin

  Result := False;

  for var iValue in AValues do
    if iValue = AValue then Exit( True );

end;

{ TTestParallelBuildCore }

procedure TTestParallelBuildCore.TestProjectKind;
begin

  Assert.AreEqual( pkPackage, ProjectKindFromDproj( DprojOf( 'Package', [ ] ) ) );
  Assert.AreEqual( pkLibrary, ProjectKindFromDproj( DprojOf( 'Library', [ ] ) ) );
  Assert.AreEqual( pkApplication, ProjectKindFromDproj( DprojOf( 'Application', [ ] ) ) );
  Assert.AreEqual( pkApplication, ProjectKindFromDproj( DprojOf( 'Console', [ ] ) ) );
  Assert.AreEqual( pkApplication, ProjectKindFromDproj( '<Project/>' ) );

end;

procedure TTestParallelBuildCore.TestResolvePropertyFromBase;
begin

  Assert.AreEqual( '.\Win32\Debug', ResolveDprojProperty( SAMPLE_DPROJ, 'DCC_DcuOutput', 'Debug', 'Win32' ), False );
  Assert.AreEqual( '.\Win64\Release', ResolveDprojProperty( SAMPLE_DPROJ, 'DCC_DcuOutput', 'Release', 'Win64' ), False );

end;

procedure TTestParallelBuildCore.TestResolvePropertyConfigOverridesBase;
begin

  Assert.AreEqual( 'dbg', ResolveDprojProperty( SAMPLE_DPROJ, 'DCC_ExeOutput', 'Debug', 'Win64' ), False );
  // Release has a value for Win64 only, so Win32 still takes Base's.
  Assert.AreEqual( '..\bin', ResolveDprojProperty( SAMPLE_DPROJ, 'DCC_ExeOutput', 'Release', 'Win32' ), False );

end;

procedure TTestParallelBuildCore.TestResolvePropertyPlatformGroup;
begin

  Assert.AreEqual( 'rel64', ResolveDprojProperty( SAMPLE_DPROJ, 'DCC_ExeOutput', 'Release', 'Win64' ), False );
  Assert.AreEqual( 'ONLY32', ResolveDprojProperty( SAMPLE_DPROJ, 'DCC_Define', 'Release', 'Win32' ), False );
  Assert.AreEqual( '', ResolveDprojProperty( SAMPLE_DPROJ, 'DCC_Define', 'Release', 'Win64' ), False );

end;

procedure TTestParallelBuildCore.TestResolvePropertyParentChain;
begin

  // Beta sets nothing itself; its parent is Release, whose Win64 group sets the folder.
  Assert.AreEqual( 'rel64', ResolveDprojProperty( SAMPLE_DPROJ, 'DCC_ExeOutput', 'Beta', 'Win64' ), False );
  Assert.AreEqual( '.\Win64\Beta', ResolveDprojProperty( SAMPLE_DPROJ, 'DCC_DcuOutput', 'Beta', 'Win64' ), False );

end;

procedure TTestParallelBuildCore.TestResolvePropertyMissing;
begin

  Assert.AreEqual( '', ResolveDprojProperty( SAMPLE_DPROJ, 'DCC_BplOutput', 'Release', 'Win64' ), False );
  // A longer name that starts the same must not match.
  Assert.AreEqual( '', ResolveDprojProperty( SAMPLE_DPROJ, 'DCC_Dcu', 'Release', 'Win64' ), False );

end;

procedure TTestParallelBuildCore.TestDcuLockKeyResolvesRelativeFolder;
begin

  Assert.AreEqual( 'C:\SRC\APP\WIN64\RELEASE', DcuLockKey( 'C:\Src\App\App.dproj', SAMPLE_DPROJ, 'Release', 'Win64' ), False );
  Assert.AreEqual( 'C:\SRC\APP\WIN64\DEBUG', DcuLockKey( 'C:\Src\App\App.dproj', SAMPLE_DPROJ, 'Debug', 'Win64' ), False );

end;

procedure TTestParallelBuildCore.TestDcuLockKeyDefaultsToProjectFolder;
begin

  Assert.AreEqual( 'C:\SRC\APP', DcuLockKey( 'C:\Src\App\App.dproj', DprojOf( 'Application', [ ] ), 'Release', 'Win64' ), False );

end;

procedure TTestParallelBuildCore.TestDcuLockKeySharedFolderCollides;
begin

  var sFirst  := DcuLockKey( 'C:\Src\Tools\Open.dproj', SAMPLE_DPROJ, 'Release', 'Win64' );
  var sSecond := DcuLockKey( 'c:\src\TOOLS\Stop.dproj', SAMPLE_DPROJ, 'Release', 'Win64' );
  var sOther  := DcuLockKey( 'C:\Src\Other\Stop.dproj', SAMPLE_DPROJ, 'Release', 'Win64' );

  Assert.AreEqual( sFirst, sSecond, False );
  Assert.AreNotEqual( sFirst, sOther, False );

end;

procedure TTestParallelBuildCore.TestRequiredPackages;
begin

  var saPackages := RequiredPackages(
    '<ItemGroup><DCCReference Include="rtl.dcp"/><DCCReference Include="..\Lib\MyBase.DCP"/>' +
    '<DCCReference Include="Unit1.pas"/></ItemGroup>' );

  Assert.AreEqual( 2, Length( saPackages ) );
  Assert.AreEqual( 'rtl', saPackages[ 0 ], False );
  Assert.AreEqual( 'MyBase', saPackages[ 1 ], False );

end;

procedure TTestParallelBuildCore.TestParseGroupProjects;
var
  saProjects        : TArray<string>;
  saDependencies    : TArray<TArray<string>>;
begin

  ParseGroupProjects(
    '<Project><ItemGroup>'#13#10 +
    '<Projects Include="Lib\Base.dproj"><Dependencies/></Projects>'#13#10 +
    '<Projects Include="App\App.dproj">'#13#10'  <Dependencies>Lib\Base.dproj;Lib\Extra.dproj</Dependencies>'#13#10'</Projects>'#13#10 +
    '<Projects Include="Lib\Extra.dproj"/>'#13#10 +
    '</ItemGroup></Project>', saProjects, saDependencies );

  Assert.AreEqual( 3, Length( saProjects ) );
  Assert.AreEqual( 'Lib\Base.dproj', saProjects[ 0 ], False );
  Assert.AreEqual( 'App\App.dproj', saProjects[ 1 ], False );
  Assert.AreEqual( 'Lib\Extra.dproj', saProjects[ 2 ], False );
  Assert.AreEqual( 0, Length( saDependencies[ 0 ] ) );
  Assert.AreEqual( 2, Length( saDependencies[ 1 ] ) );
  Assert.AreEqual( 'Lib\Base.dproj', saDependencies[ 1 ][ 0 ], False );
  Assert.AreEqual( 'Lib\Extra.dproj', saDependencies[ 1 ][ 1 ], False );
  Assert.AreEqual( 0, Length( saDependencies[ 2 ] ) );

end;

procedure TTestParallelBuildCore.TestPlanHonoursGroupDependencies;
begin

  var sGroup :=
    '<Project><ItemGroup>' +
    '<Projects Include="A\A.dproj"><Dependencies/></Projects>' +
    '<Projects Include="B\B.dproj"><Dependencies>A\A.dproj</Dependencies></Projects>' +
    '</ItemGroup></Project>';
  var raPlan := BuildPlan( 'C:\G\All.groupproj', sGroup, [ InputOf( 'C:\G\A\A.dproj', DprojOf( 'Application', [ ] ) ),
    InputOf( 'C:\G\B\B.dproj', DprojOf( 'Application', [ ] ) ) ] );

  Assert.AreEqual( 2, Length( raPlan ) );
  Assert.AreEqual( 0, Length( raPlan[ 0 ].DependsOn ) );
  Assert.AreEqual( 1, Length( raPlan[ 1 ].DependsOn ) );
  Assert.AreEqual( 0, raPlan[ 1 ].DependsOn[ 0 ] );

end;

procedure TTestParallelBuildCore.TestPlanPackageRequires;
begin

  // 0 Base, 1 Extra ( requires Base and the RTL ), 2 Alone ( requires only the RTL ).
  var raPlan := BuildPlan( 'C:\G\All.groupproj', '', [ InputOf( 'C:\G\Base\Base.dproj', DprojOf( 'Package', [ 'rtl' ] ) ),
    InputOf( 'C:\G\Extra\Extra.dproj', DprojOf( 'Package', [ 'rtl', 'base' ] ) ),
    InputOf( 'C:\G\Alone\Alone.dproj', DprojOf( 'Package', [ 'rtl' ] ) ) ] );

  Assert.AreEqual( pkPackage, raPlan[ 1 ].Kind );
  Assert.AreEqual( 0, Length( raPlan[ 0 ].DependsOn ) );
  Assert.AreEqual( 1, Length( raPlan[ 1 ].DependsOn ) );
  Assert.AreEqual( 0, raPlan[ 1 ].DependsOn[ 0 ] );
  Assert.AreEqual( 0, Length( raPlan[ 2 ].DependsOn ) );

end;

procedure TTestParallelBuildCore.TestPlanApplicationsWaitForPackages;
begin

  // The application comes first in the group and still waits for both packages.
  var raPlan := BuildPlan( 'C:\G\All.groupproj', '', [ InputOf( 'C:\G\App\App.dproj', DprojOf( 'Application', [ ] ) ),
    InputOf( 'C:\G\Base\Base.dproj', DprojOf( 'Package', [ ] ) ), InputOf( 'C:\G\Dll\Dll.dproj', DprojOf( 'Library', [ ] ) ),
    InputOf( 'C:\G\Extra\Extra.dproj', DprojOf( 'Package', [ ] ) ) ] );

  Assert.AreEqual( 2, Length( raPlan[ 0 ].DependsOn ) );
  Assert.IsTrue( Holds( raPlan[ 0 ].DependsOn, 1 ) and Holds( raPlan[ 0 ].DependsOn, 3 ) );
  Assert.AreEqual( 2, Length( raPlan[ 2 ].DependsOn ) );
  Assert.IsTrue( Holds( raPlan[ 2 ].DependsOn, 1 ) and Holds( raPlan[ 2 ].DependsOn, 3 ) );
  Assert.AreEqual( 0, Length( raPlan[ 1 ].DependsOn ) );
  Assert.AreEqual( 0, Length( raPlan[ 3 ].DependsOn ) );

end;

procedure TTestParallelBuildCore.TestPlanIndependentApplications;
begin

  var raPlan := BuildPlan( 'C:\G\All.groupproj', '', [ InputOf( 'C:\G\A\A.dproj', SAMPLE_DPROJ ),
    InputOf( 'C:\G\B\B.dproj', SAMPLE_DPROJ ) ] );

  Assert.AreEqual( 0, Length( raPlan[ 0 ].DependsOn ) );
  Assert.AreEqual( 0, Length( raPlan[ 1 ].DependsOn ) );
  Assert.AreEqual( 'C:\G\A\WIN64\RELEASE', raPlan[ 0 ].LockKey, False );
  Assert.AreEqual( 'C:\G\B\WIN64\RELEASE', raPlan[ 1 ].LockKey, False );
  Assert.AreEqual( 'Release', raPlan[ 0 ].Config, False );
  Assert.AreEqual( 'Win64', raPlan[ 0 ].Platform, False );

end;

procedure TTestParallelBuildCore.TestScheduleRespectsWorkerLimit;
begin

  var oSchedule := TParallelSchedule.Create( [ ProjectOf( 'A', [ ] ), ProjectOf( 'B', [ ] ), ProjectOf( 'C', [ ] ) ], 2 );
  try
    Assert.AreEqual( 0, oSchedule.NextToStart );
    Assert.AreEqual( 1, oSchedule.NextToStart );
    Assert.AreEqual( -1, oSchedule.NextToStart, 'a third project started with two workers' );
    Assert.AreEqual( 2, oSchedule.RunningCount );
    Assert.IsFalse( oSchedule.Done );
    oSchedule.Finished( 0, True );
    Assert.AreEqual( 2, oSchedule.NextToStart );
    oSchedule.Finished( 1, True );
    oSchedule.Finished( 2, True );
    Assert.AreEqual( -1, oSchedule.NextToStart );
    Assert.IsTrue( oSchedule.Done );
    Assert.AreEqual( 3, oSchedule.CountOf( psSucceeded ) );
  finally
    oSchedule.Free;
  end;

end;

procedure TTestParallelBuildCore.TestScheduleSerialisesSharedDcuFolder;
begin

  var oSchedule := TParallelSchedule.Create( [ ProjectOf( 'A', [ ], 'C:\G\TOOLS\WIN64\RELEASE' ),
    ProjectOf( 'B', [ ], 'C:\G\TOOLS\WIN64\RELEASE' ), ProjectOf( 'C', [ ] ) ], 8 );
  try
    Assert.AreEqual( 0, oSchedule.NextToStart );
    // B shares A's DCU folder, so C starts and B does not.
    Assert.AreEqual( 2, oSchedule.NextToStart );
    Assert.AreEqual( -1, oSchedule.NextToStart );
    oSchedule.Finished( 0, True );
    Assert.AreEqual( 1, oSchedule.NextToStart );
  finally
    oSchedule.Free;
  end;

end;

procedure TTestParallelBuildCore.TestScheduleWaitsForDependency;
begin

  var oSchedule := TParallelSchedule.Create( [ ProjectOf( 'App', [ 1 ] ), ProjectOf( 'Pkg', [ ] ) ], 8 );
  try
    Assert.AreEqual( 1, oSchedule.NextToStart );
    Assert.AreEqual( -1, oSchedule.NextToStart, 'the application started before its package finished' );
    oSchedule.Finished( 1, True );
    Assert.AreEqual( 0, oSchedule.NextToStart );
  finally
    oSchedule.Free;
  end;

end;

procedure TTestParallelBuildCore.TestScheduleFailureSkipsDependents;
begin

  // C waits for B, which waits for A.
  var oSchedule := TParallelSchedule.Create( [ ProjectOf( 'A', [ ] ), ProjectOf( 'B', [ 0 ] ), ProjectOf( 'C', [ 1 ] ) ], 8 );
  try
    Assert.AreEqual( 0, oSchedule.NextToStart );
    oSchedule.Finished( 0, False );
    Assert.AreEqual( -1, oSchedule.NextToStart );
    Assert.AreEqual( psFailed, oSchedule.States[ 0 ] );
    Assert.AreEqual( psSkipped, oSchedule.States[ 1 ] );
    Assert.AreEqual( psSkipped, oSchedule.States[ 2 ] );
    Assert.AreEqual( 'not built: A did not build', oSchedule.SkipReasons[ 1 ], False );
    Assert.AreEqual( 'not built: B did not build', oSchedule.SkipReasons[ 2 ], False );
    Assert.IsTrue( oSchedule.Done );
  finally
    oSchedule.Free;
  end;

end;

procedure TTestParallelBuildCore.TestScheduleFailureLeavesIndependentProjects;
begin

  var oSchedule := TParallelSchedule.Create( [ ProjectOf( 'A', [ ] ), ProjectOf( 'B', [ ] ) ], 1 );
  try
    Assert.AreEqual( 0, oSchedule.NextToStart );
    oSchedule.Finished( 0, False );
    Assert.AreEqual( 1, oSchedule.NextToStart, 'an unrelated project was not built after a failure' );
    oSchedule.Finished( 1, True );
    Assert.AreEqual( psSucceeded, oSchedule.States[ 1 ] );
    Assert.AreEqual( '', oSchedule.SkipReasons[ 1 ], False );
  finally
    oSchedule.Free;
  end;

end;

procedure TTestParallelBuildCore.TestScheduleCircularDependenciesSkipped;
begin

  var oSchedule := TParallelSchedule.Create( [ ProjectOf( 'A', [ 1 ] ), ProjectOf( 'B', [ 0 ] ), ProjectOf( 'C', [ ] ) ], 8 );
  try
    Assert.AreEqual( 2, oSchedule.NextToStart );
    Assert.AreEqual( -1, oSchedule.NextToStart );
    Assert.IsFalse( oSchedule.Done, 'C is still running' );
    oSchedule.Finished( 2, True );
    Assert.AreEqual( -1, oSchedule.NextToStart );
    Assert.AreEqual( psSkipped, oSchedule.States[ 0 ] );
    Assert.AreEqual( psSkipped, oSchedule.States[ 1 ] );
    Assert.AreEqual( 'not built: its dependencies form a circle', oSchedule.SkipReasons[ 0 ], False );
    Assert.IsTrue( oSchedule.Done );
  finally
    oSchedule.Free;
  end;

end;

procedure TTestParallelBuildCore.TestScheduleCancelWaiting;
begin

  var oSchedule := TParallelSchedule.Create( [ ProjectOf( 'A', [ ] ), ProjectOf( 'B', [ ] ), ProjectOf( 'C', [ ] ) ], 1 );
  try
    Assert.AreEqual( 0, oSchedule.NextToStart );
    oSchedule.CancelWaiting( 'stopped' );
    Assert.AreEqual( psRunning, oSchedule.States[ 0 ] );
    Assert.AreEqual( psSkipped, oSchedule.States[ 1 ] );
    Assert.AreEqual( 'stopped', oSchedule.SkipReasons[ 2 ], False );
    Assert.IsFalse( oSchedule.Done, 'the running project has not finished' );
    oSchedule.Finished( 0, True );
    Assert.AreEqual( -1, oSchedule.NextToStart );
    Assert.IsTrue( oSchedule.Done );
  finally
    oSchedule.Free;
  end;

end;

procedure TTestParallelBuildCore.TestScheduleFinishedNeedsRunningProject;
begin

  var oSchedule := TParallelSchedule.Create( [ ProjectOf( 'A', [ ] ) ], 1 );
  try
    Assert.WillRaise(
      procedure
      begin
        oSchedule.Finished( 0, True );
      end, EInvalidOpException );
  finally
    oSchedule.Free;
  end;

end;

procedure TTestParallelBuildCore.TestEffectiveWorkerCount;
begin

  Assert.AreEqual( 8, EffectiveWorkerCount( 0, 12 ), 'automatic is capped at eight' );
  Assert.AreEqual( 8, EffectiveWorkerCount( 0, 8 ) );
  Assert.AreEqual( 4, EffectiveWorkerCount( 0, 4 ), 'automatic is one per CPU' );
  Assert.AreEqual( 1, EffectiveWorkerCount( 0, 0 ), 'never fewer than one' );
  Assert.AreEqual( 2, EffectiveWorkerCount( -1, 2 ), 'a negative setting is automatic' );
  Assert.AreEqual( 3, EffectiveWorkerCount( 3, 12 ), 'a setting wins' );
  Assert.AreEqual( 12, EffectiveWorkerCount( 12, 4 ), 'a setting may exceed the CPU count' );
  Assert.AreEqual( 32, EffectiveWorkerCount( 99, 12 ), 'a setting is capped at the limit' );
  Assert.AreEqual( 32, EffectiveWorkerCount( 32, 12 ) );

end;

procedure TTestParallelBuildCore.TestQuoteArgument;
begin

  Assert.AreEqual( '/t:Build', QuoteArgument( '/t:Build' ), False );
  Assert.AreEqual( '"C:\My Projects\App.dproj"', QuoteArgument( 'C:\My Projects\App.dproj' ), False );
  Assert.AreEqual( '""', QuoteArgument( '' ), False );
  Assert.AreEqual( '"say \"hi\""', QuoteArgument( 'say "hi"' ), False );
  // A trailing backslash would otherwise escape the closing quote.
  Assert.AreEqual( '"C:\My Dir\\"', QuoteArgument( 'C:\My Dir\' ), False );
  Assert.AreEqual( '"a\\\"b c"', QuoteArgument( 'a\"b c' ), False );
  Assert.AreEqual( 'C:\NoSpace\', QuoteArgument( 'C:\NoSpace\' ), False );

end;

procedure TTestParallelBuildCore.TestMSBuildCommandLine;
begin

  Assert.AreEqual(
    'C:\Fw\MSBuild.exe "C:\My Projects\App.dproj" /t:Build /p:Config=Release /p:Platform=Win64 /nologo /v:minimal /nr:false',
    MSBuildCommandLine( 'C:\Fw\MSBuild.exe', 'C:\My Projects\App.dproj', 'Release', 'Win64' ), False );
  Assert.AreEqual(
    '"C:\Net Fw\MSBuild.exe" C:\P\App.dproj /t:Build "/p:Config=My Config" /p:Platform=Win32 /nologo /v:minimal /nr:false',
    MSBuildCommandLine( 'C:\Net Fw\MSBuild.exe', 'C:\P\App.dproj', 'My Config', 'Win32' ), False );

end;

procedure TTestParallelBuildCore.TestEcc32CommandLine;
begin

  Assert.AreEqual(
    '"C:\EL 7\ecc32.exe" "--el_alter_exe=C:\P\App.dproj;C:\Out Dir\App.exe" "--el_config=C:\Profiles\App.eof"',
    Ecc32CommandLine( 'C:\EL 7\ecc32.exe', 'C:\P\App.dproj', 'C:\Out Dir\App.exe', 'C:\Profiles\App.eof' ), False );

end;

procedure TTestParallelBuildCore.TestParseSetOutput;
begin

  var saVariables := ParseSetOutput( 'BDS=C:\Studio\37.0'#13#10'PATH=C:\A;C:\B'#13#10#13#10'=C:=C:\Hidden'#13#10'NoEquals'#13#10'X=1=2' );

  Assert.AreEqual( 3, Length( saVariables ) );
  Assert.AreEqual( 'BDS=C:\Studio\37.0', saVariables[ 0 ], False );
  Assert.AreEqual( 'PATH=C:\A;C:\B', saVariables[ 1 ], False );
  Assert.AreEqual( 'X=1=2', saVariables[ 2 ], False );

end;

procedure TTestParallelBuildCore.TestEnvironmentValue;
begin

  var saVariables: TArray<string> := [ 'FrameworkDirOld=C:\Old', 'FrameworkDir=C:\Fw', 'Empty=' ];

  Assert.AreEqual( 'C:\Fw', EnvironmentValue( saVariables, 'FRAMEWORKDIR' ), False );
  Assert.AreEqual( 'C:\Old', EnvironmentValue( saVariables, 'FrameworkDirOld' ), False );
  Assert.AreEqual( '', EnvironmentValue( saVariables, 'Empty' ), False );
  Assert.AreEqual( '', EnvironmentValue( saVariables, 'Framework' ), False );

end;

procedure TTestParallelBuildCore.TestEnvironmentBlock;
begin

  Assert.AreEqual( 'A=1'#0'B=2'#0, EnvironmentBlock( [ 'A=1', 'B=2' ] ), False );
  Assert.AreEqual( '', EnvironmentBlock( [ ] ), False );

end;

procedure TTestParallelBuildCore.TestMSBuildExeFromEnvironment;
begin

  Assert.AreEqual( 'C:\Fw\v4\MSBuild.exe', MSBuildExeFromEnvironment( [ 'FrameworkDir=C:\Fw\v4' ] ), False );
  Assert.AreEqual( 'C:\Fw\v4\MSBuild.exe', MSBuildExeFromEnvironment( [ 'FrameworkDir=C:\Fw\v4\' ] ), False );
  Assert.AreEqual( '', MSBuildExeFromEnvironment( [ 'BDS=C:\Studio' ] ), False );

end;

procedure TTestParallelBuildCore.TestParseErrorLine;
var
  rDiagnostic       : TBuildDiagnostic;
begin

  Assert.IsTrue( ParseBuildLine(
    'C:\P\Unit1.pas(42): error E2003: Undeclared identifier: ''Foo'' [C:\P\App.dproj]', rDiagnostic ) );
  Assert.AreEqual( dkError, rDiagnostic.Kind );
  Assert.AreEqual( 'C:\P\Unit1.pas', rDiagnostic.FileName, False );
  Assert.AreEqual( 42, rDiagnostic.Line );
  Assert.AreEqual( 'E2003', rDiagnostic.Code, False );
  Assert.AreEqual( 'Undeclared identifier: ''Foo''', rDiagnostic.Text, False );

  // A line and column position.
  Assert.IsTrue( ParseBuildLine( 'Unit2.pas(7,15): error E2029: '';'' expected but ''END'' found', rDiagnostic ) );
  Assert.AreEqual( 'Unit2.pas', rDiagnostic.FileName, False );
  Assert.AreEqual( 7, rDiagnostic.Line );

end;

procedure TTestParallelBuildCore.TestParseHintLine;
var
  rDiagnostic       : TBuildDiagnostic;
begin

  Assert.IsTrue( ParseBuildLine(
    'C:\P\Unit1.pas(10): Hint warning H2077: Value assigned to ''X'' never used [C:\P\App.dproj]', rDiagnostic ) );
  Assert.AreEqual( dkHint, rDiagnostic.Kind );
  Assert.AreEqual( 'H2077', rDiagnostic.Code, False );
  Assert.AreEqual( 10, rDiagnostic.Line );
  Assert.AreEqual( 'Value assigned to ''X'' never used', rDiagnostic.Text, False );

end;

procedure TTestParallelBuildCore.TestParseWarningAndFatalLines;
var
  rDiagnostic       : TBuildDiagnostic;
begin

  Assert.IsTrue( ParseBuildLine( 'C:\P\Unit1.pas(3): warning W1000: Symbol ''Old'' is deprecated [C:\P\App.dproj]', rDiagnostic ) );
  Assert.AreEqual( dkWarning, rDiagnostic.Kind );
  Assert.AreEqual( 'W1000', rDiagnostic.Code, False );

  Assert.IsTrue( ParseBuildLine( 'C:\P\App.dpr(9): error F2063: Could not compile used unit ''Unit1.pas'' [C:\P\App.dproj]',
    rDiagnostic ) );
  Assert.AreEqual( dkFatal, rDiagnostic.Kind );
  Assert.AreEqual( 'F2063', rDiagnostic.Code, False );

  // A fatal error with no position.
  Assert.IsTrue( ParseBuildLine( 'App.dpr : fatal error F1026: File not found: ''Missing.dpr''', rDiagnostic ) );
  Assert.AreEqual( dkFatal, rDiagnostic.Kind );
  Assert.AreEqual( 'F1026', rDiagnostic.Code, False );
  Assert.AreEqual( 0, rDiagnostic.Line );

end;

procedure TTestParallelBuildCore.TestParseMSBuildLines;
var
  rDiagnostic       : TBuildDiagnostic;
begin

  Assert.IsTrue( ParseBuildLine(
    'C:\Studio\Bin\CodeGear.Delphi.Targets(429,5): error MSB3073: The command "x" exited with code 1. [C:\P\App.dproj]',
    rDiagnostic ) );
  Assert.AreEqual( dkError, rDiagnostic.Kind );
  Assert.AreEqual( 'MSB3073', rDiagnostic.Code, False );
  Assert.AreEqual( 'The command "x" exited with code 1.', rDiagnostic.Text, False );

  Assert.IsTrue( ParseBuildLine( 'C:\Fw\Microsoft.Common.targets(2123,5): warning MSB3277: Found conflicts', rDiagnostic ) );
  Assert.AreEqual( dkWarning, rDiagnostic.Kind );

  Assert.IsTrue( ParseBuildLine( 'MSBUILD : error MSB1009: Project file does not exist.', rDiagnostic ) );
  Assert.AreEqual( dkError, rDiagnostic.Kind );
  Assert.AreEqual( 'MSB1009', rDiagnostic.Code, False );
  Assert.AreEqual( '', rDiagnostic.FileName, False );

  Assert.IsTrue( ParseBuildLine( 'App.dproj : warning MSB4011: imported twice', rDiagnostic ) );
  Assert.AreEqual( dkWarning, rDiagnostic.Kind );
  Assert.AreEqual( 'MSB4011', rDiagnostic.Code, False );

end;

procedure TTestParallelBuildCore.TestParseIgnoresChatter;
var
  rDiagnostic       : TBuildDiagnostic;
begin

  Assert.IsFalse( ParseBuildLine( '42 lines, 0.05 seconds, 12345 bytes code, 100 bytes data.', rDiagnostic ) );
  Assert.IsFalse( ParseBuildLine( 'Build succeeded with 0 error(s) and 0 warning(s)', rDiagnostic ) );
  Assert.IsFalse( ParseBuildLine( 'warning: this is just a remark', rDiagnostic ) );
  Assert.IsFalse( ParseBuildLine( '', rDiagnostic ) );
  Assert.IsFalse( ParseBuildLine( 'Embarcadero Delphi for Win64 compiler version 37.0', rDiagnostic ) );

end;

procedure TTestParallelBuildCore.TestParseBuildOutput;
begin

  var raDiagnostics := ParseBuildOutput(
    'Compiling'#13#10 +
    'U.pas(1): Hint warning H2164: Variable ''i'' is declared but never used [P.dproj]'#13#10 +
    'U.pas(2): warning W1036: Variable ''s'' might not have been initialized [P.dproj]'#13#10 +
    'U.pas(1): Hint warning H2164: Variable ''i'' is declared but never used [P.dproj]'#13#10 +
    'Done'#13#10 );

  Assert.AreEqual( 2, Length( raDiagnostics ) );
  Assert.AreEqual( dkHint, raDiagnostics[ 0 ].Kind );
  Assert.AreEqual( dkWarning, raDiagnostics[ 1 ].Kind );
  Assert.IsFalse( HasErrors( raDiagnostics ), 'hints and warnings are not errors' );

  raDiagnostics := ParseBuildOutput( 'U.pas(5): error E2003: Undeclared identifier: ''x'''#10'U.pas(9): warning W1000: old' );

  Assert.AreEqual( 2, Length( raDiagnostics ) );
  Assert.IsTrue( HasErrors( raDiagnostics ) );
  Assert.IsTrue( HasErrors( ParseBuildOutput( 'P.dpr(3): error F2063: Could not compile used unit ''U.pas''' ) ), 'a fatal error is an error' );
  Assert.AreEqual( 0, Length( ParseBuildOutput( '' ) ) );

end;

procedure TTestParallelBuildCore.TestIsDUnitXRunner;
begin

  Assert.IsTrue( IsDUnitXRunner( 'program T; uses System.SysUtils, DUnitX.TestFramework, Tests; begin end.' ) );
  Assert.IsFalse( IsDUnitXRunner( 'program App; uses Vcl.Forms, MainUnit; begin end.' ) );
  Assert.IsFalse( IsDUnitXRunner( 'program App; uses MyDUnitX.TestFrameworkHelper; begin end.' ) );

end;

procedure TTestParallelBuildCore.TestShouldRunEurekaLog;
begin

  Assert.IsTrue( ShouldRunEurekaLog( True, 'Release', pkApplication, True, False ) );
  Assert.IsTrue( ShouldRunEurekaLog( True, 'RELEASE', pkLibrary, True, False ), 'a DLL is post-processed too' );
  Assert.IsFalse( ShouldRunEurekaLog( False, 'Release', pkApplication, True, False ), 'the setting is off' );
  Assert.IsFalse( ShouldRunEurekaLog( True, 'Debug', pkApplication, True, False ), 'a Debug build' );
  Assert.IsFalse( ShouldRunEurekaLog( True, 'Release', pkPackage, True, False ), 'a package' );
  Assert.IsFalse( ShouldRunEurekaLog( True, 'Release', pkApplication, False, False ), 'no .eof' );
  Assert.IsFalse( ShouldRunEurekaLog( True, 'Release', pkApplication, True, True ), 'a DUnitX runner' );

end;

procedure TTestParallelBuildCore.TestEurekaLogProfilePath;
begin

  Assert.AreEqual( 'C:\Users\Me\AppData\Roaming\Neos\Profiles\Suite.eof',
    EurekaLogProfilePath( '[Exception Log]'#13#10'EurekaLog Version=8000'#13#10'ExternalConfig=%%APPDATA%%\Neos\Profiles\Suite.eof'#13#10,
    'C:\P\App.eof', 'C:\Users\Me\AppData\Roaming\' ), False );
  Assert.AreEqual( 'C:\Users\Me\AppData\Roaming\X.eof',
    EurekaLogProfilePath( 'ExternalConfig = %APPDATA%\X.eof', 'C:\P\App.eof', 'C:\Users\Me\AppData\Roaming' ), False );
  // A relative ExternalConfig is relative to the stub.
  Assert.AreEqual( 'C:\P\Shared\Team.eof', EurekaLogProfilePath( 'ExternalConfig=Shared\Team.eof', 'C:\P\App.eof', 'C:\A' ), False );
  // A full profile is its own.
  Assert.AreEqual( 'C:\P\App.eof', EurekaLogProfilePath( '[Exception Log]'#13#10'Activate=1'#13#10, 'C:\P\App.eof', 'C:\A' ), False );

end;

procedure TTestParallelBuildCore.TestProjectOutputFile;
begin

  Assert.AreEqual( 'C:\Src\App\rel64\App.exe',
    ProjectOutputFile( 'C:\Src\App\App.dproj', SAMPLE_DPROJ, 'Release', 'Win64', pkApplication ), False );
  Assert.AreEqual( 'C:\Src\bin\App.exe',
    ProjectOutputFile( 'C:\Src\App\App.dproj', SAMPLE_DPROJ, 'Release', 'Win32', pkApplication ), False );
  Assert.AreEqual( 'C:\Src\App\dbg\Helper.dll',
    ProjectOutputFile( 'C:\Src\App\Helper.dproj', SAMPLE_DPROJ, 'Debug', 'Win64', pkLibrary ), False );
  Assert.AreEqual( 'C:\Src\App\App.exe',
    ProjectOutputFile( 'C:\Src\App\App.dproj', DprojOf( 'Application', [ ] ), 'Release', 'Win64', pkApplication ), False );
  Assert.AreEqual( 'E:\Deploy\App.exe', ProjectOutputFile( 'C:\Src\App\App.dproj',
    '<PropertyGroup Condition="''$(Base)''!=''''"><DCC_ExeOutput>E:\Deploy\</DCC_ExeOutput></PropertyGroup>', 'Release', 'Win64',
    pkApplication ), False );

end;

procedure TTestParallelBuildCore.TestDefaultEcc32Path;
begin

  Assert.AreEqual( 'C:\Program Files (x86)\Neos Eureka S.r.l\EurekaLog 7\Packages\Studio37\ecc32.exe',
    DefaultEcc32Path( 'C:\Program Files (x86)', 'Studio37' ), False );
  Assert.AreEqual( 'D:\PF\Neos Eureka S.r.l\EurekaLog 7\Packages\Studio29\ecc32.exe', DefaultEcc32Path( 'D:\PF\', 'Studio29' ), False );

end;

initialization
  TDUnitX.RegisterTestFixture( TTestParallelBuildCore );

end.
