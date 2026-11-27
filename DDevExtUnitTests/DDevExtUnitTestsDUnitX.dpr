program DDevExtUnitTestsDUnitX;

{ Two runners, chosen by conditional define:

    GUI_TEST_RUNNER   - the DUnitX VCL GUI runner, for interactive use.  Opt-in.
    (not defined)     - the console runner: GllDUnitX.SuiteRunner with a per-test FastMM5 leak check, an NUnit XML
                        report and the estate exit code.  Every configuration builds it; it is what test_run and CI
                        call.

  The TestInsight runner is gone ( 2026-11-19 ): TestInsight was removed from the IDE deliberately, and its host exits
  SILENTLY with code 0 when no TestInsight server is listening, a fake green the Debug configuration produced. }

{$IFDEF GUI_TEST_RUNNER}
  {$APPTYPE GUI}
{$ELSE}
  {$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}
// No EurekaLog in this test runner ( Ian, 2026-11-19, as in GITLAKLibTests ): it raises a modal dialog for every
// exception, even the ones DUnitX handles, which blocks an unattended run.  The .dproj defines EUREKALOG; these undo it.
{$UNDEF EurekaLog}
{$UNDEF EUREKALOG}
{$UNDEF EUREKALOG_VER7}

uses
  // FastMM5 FIRST, as the memory manager the per-test leak check measures ( GllDUnitX.SuiteRunner )
  FastMM5,
  {$IFDEF EurekaLog}
  EMemLeaks,
  EResLeaks,
  EFastMM5Support,
  EResourceStrings,
  EDebugJCL,
  EDebugExports,
  EFixSafeCallException,
  EMapWin32,
  EAppVCL,
  EDialogWinAPIMSClassic,
  EDialogWinAPIEurekaLogDetailed,
  EDialogWinAPIStepsToReproduce,
  EBase,
  EExtraExceptionInfo,
  ExceptionLog7,
  {$ENDIF EurekaLog}
  System.SysUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Themes,
  Vcl.Styles,
  {$IFDEF GUI_TEST_RUNNER}
  DUnitX.Loggers.GUI.VCL,
  {$ENDIF}
  {$IFNDEF GUI_TEST_RUNNER}
  GllDUnitX.SuiteRunner,
  {$ENDIF}
  DUnitX.TestFramework,
  gllDelphiDFMParser in '..\Shared\PascalParser\gllDelphiDFMParser.pas',
  TestDfmParserDUnitX in 'TestDfmParserDUnitX.pas',
  gllDfmCompare in '..\Shared\PascalParser\gllDfmCompare.pas',
  TestDfmCompareDUnitX in 'TestDfmCompareDUnitX.pas',
  DfmLinkGuardCore in '..\Code\DDevExtensions\Source\DfmLinkGuard\DfmLinkGuardCore.pas',
  TestDfmLinkGuardCoreDUnitX in 'TestDfmLinkGuardCoreDUnitX.pas',
  ProjectGroupSorterCore in '..\Code\DDevExtensions\Source\ProjectGroupSorter\ProjectGroupSorterCore.pas',
  TestProjectGroupSorterDUnitX in 'TestProjectGroupSorterDUnitX.pas',
  ParallelBuildCore in '..\Code\DDevExtensions\Source\ParallelBuild\ParallelBuildCore.pas',
  ParallelBuildRunner in '..\Code\DDevExtensions\Source\ParallelBuild\ParallelBuildRunner.pas',
  TestParallelBuildCoreDUnitX in 'TestParallelBuildCoreDUnitX.pas',
  TestParallelBuildRunnerDUnitX in 'TestParallelBuildRunnerDUnitX.pas',
  PathCompactorCore in '..\Code\DDevExtensions\Source\PathCompactor\PathCompactorCore.pas',
  TestPathCompactorDUnitX in 'TestPathCompactorDUnitX.pas',
  SimpleXmlIntf in '..\Shared\Xml\SimpleXmlIntf.pas',
  SimpleXmlDoc in '..\Shared\Xml\SimpleXmlDoc.pas',
  SimpleXmlImport in '..\Shared\Xml\SimpleXmlImport.pas',
  LibraryPathBackups in '..\Code\DDevExtensions\Source\LibraryPathSorter\LibraryPathBackups.pas',
  TestLibraryPathBackupsDUnitX in 'TestLibraryPathBackupsDUnitX.pas',
  UsesClauseManagerCore in '..\Code\DDevExtensions\Source\UsesClauseManager\UsesClauseManagerCore.pas',
  DelphiLexer in '..\Shared\PascalParser\DelphiLexer.pas',
  TestUsesClauseManagerCoreDUnitX in 'TestUsesClauseManagerCoreDUnitX.pas',
  DecirculariserCore in '..\Code\DDevExtensions\Source\Decirculariser\DecirculariserCore.pas',
  TestDecirculariserCoreDUnitX in 'TestDecirculariserCoreDUnitX.pas',
  MethodSeparatorsCore in '..\Code\DDevExtensions\Source\MethodSeparators\MethodSeparatorsCore.pas',
  TestMethodSeparatorsCoreDUnitX in 'TestMethodSeparatorsCoreDUnitX.pas',
  TestDelphiLexerDUnitX in 'TestDelphiLexerDUnitX.pas',
  DelphiParserContainers in '..\Shared\PascalParser\DelphiParserContainers.pas',
  TestDelphiParserContainersDUnitX in 'TestDelphiParserContainersDUnitX.pas',
  DelphiExpr in '..\Shared\PascalParser\DelphiExpr.pas',
  TestDelphiExprDUnitX in 'TestDelphiExprDUnitX.pas',
  DelphiPreproc in '..\Shared\PascalParser\DelphiPreproc.pas',
  TestDelphiPreprocDUnitX in 'TestDelphiPreprocDUnitX.pas',
  DelphiDesignerParser in '..\Shared\PascalParser\DelphiDesignerParser.pas',
  TestDelphiDesignerParserDUnitX in 'TestDelphiDesignerParserDUnitX.pas',
  DeadCodeCore in '..\Code\DDevExtensions\Source\DeadCodeDetector\DeadCodeCore.pas',
  TestDeadCodeCoreDUnitX in 'TestDeadCodeCoreDUnitX.pas',
  UnreachableCodeCore in '..\Code\DDevExtensions\Source\UnreachableCodeDetector\UnreachableCodeCore.pas',
  TestUnreachableCodeCoreDUnitX in 'TestUnreachableCodeCoreDUnitX.pas',
  UnusedUnitCore in '..\Code\DDevExtensions\Source\UnusedUnitDetector\UnusedUnitCore.pas',
  TestUnusedUnitCoreDUnitX in 'TestUnusedUnitCoreDUnitX.pas',
  UnitMetrics in '..\Code\DDevExtensions\Source\CompileProgress\UnitMetrics.pas',
  TestUnitMetricsDUnitX in 'TestUnitMetricsDUnitX.pas',
  FrmExcelExport in '..\Code\DDevExtensions\Source\ExcelExport\FrmExcelExport.pas' {FormExcelExport},
  TestExcelExportDUnitX in 'TestExcelExportDUnitX.pas',
  IDEHooks in '..\Shared\IDE\IDEHooks.pas',
  VirtTreeHandler in '..\Code\DDevExtensions\Source\VirtTreeHandler.pas',
  TestVirtTreeHandlerDUnitX in 'TestVirtTreeHandlerDUnitX.pas',
  InterceptIntf in '..\CompileInterceptor\Source\InterceptIntf.pas',
  InterceptDispatch in '..\CompileInterceptor\Source\InterceptDispatch.pas',
  TestInterceptDispatchDUnitX in 'TestInterceptDispatchDUnitX.pas',
  PluginConfigCore in '..\Code\DDevExtensions\Source\PluginConfigCore.pas',
  TestPluginConfigCoreDUnitX in 'TestPluginConfigCoreDUnitX.pas',
  FeatureSwitches in '..\Code\DDevExtensions\Source\FeatureSwitches.pas',
  TestFeatureSwitchesDUnitX in 'TestFeatureSwitchesDUnitX.pas',
  IDEHashLists in '..\Shared\IDE\IDEHashLists.pas',
  TestIDEHashListsDUnitX in 'TestIDEHashListsDUnitX.pas',
  VersionInfoKeys in '..\Shared\IDE\VersionInfoKeys.pas',
  TestVersionInfoKeysDUnitX in 'TestVersionInfoKeysDUnitX.pas',
  TestSimpleXmlDocDUnitX in 'TestSimpleXmlDocDUnitX.pas',
  FileWatcher in '..\Shared\FileWatcher.pas',
  TestFileWatcherDUnitX in 'TestFileWatcherDUnitX.pas',
  Hooking in '..\Shared\Hooking.pas',
  TestHookingDUnitX in 'TestHookingDUnitX.pas',
  TodoAggregatorCore in '..\Code\DDevExtensions\Source\TodoAggregator\TodoAggregatorCore.pas',
  TestTodoAggregatorCoreDUnitX in 'TestTodoAggregatorCoreDUnitX.pas',
  DfmPasConsistencyCore in '..\Code\DDevExtensions\Source\DfmPasConsistency\DfmPasConsistencyCore.pas',
  TestDfmPasConsistencyCoreDUnitX in 'TestDfmPasConsistencyCoreDUnitX.pas',
  DependencyViewerCore in '..\Code\DDevExtensions\Source\DependencyViewer\DependencyViewerCore.pas',
  TestDependencyViewerCoreDUnitX in 'TestDependencyViewerCoreDUnitX.pas',
  ImportHooking in '..\Shared\ImportHooking.pas',
  TestImportHookingDUnitX in 'TestImportHookingDUnitX.pas';

{$R *.res}

{$IFNDEF GUI_TEST_RUNNER}
/// <summary>
///   Switches RTTI discovery off: every fixture registers itself in its unit's initialization section, and leaving it
///   on collects each fixture a second time, so every test runs twice.  Passed as <c>TGllSuiteOptions.ConfigureRunner</c>,
///   which <c>RunGllSuite</c> calls for every runner it creates ( warm-up, measured pass, leak re-runs ).
/// </summary>
/// <param name="ARunner">The runner just created.</param>
procedure RegisteredFixturesOnly( ARunner: ITestRunner );
begin
  ARunner.UseRTTI := False;
end;
{$ENDIF}

begin
{$IFDEF GUI_TEST_RUNNER}
  Application.Initialize;
  TStyleManager.TrySetStyle( 'Windows Modern MountainMist' );
  Application.Title := 'DDevExtensions Unit Tests';
  Application.CreateForm( TGUIVCLTestRunner, GUIVCLTestRunner );

  // Adjust font size for better readability
  GUIVCLTestRunner.Font.Size := 10;

  Application.Run;
{$ELSE}
  { Every test is checked for memory leaks by GllDUnitX.SuiteRunner ( 2026-11-19 ): a warm-up pass, the measured pass
    under FastMM5, then a re-run of each flagged test; only a leak that repeats counts.  It also honours DUnitX's
    command line ( the result-XML path test_run passes, --run:<names> ), and sets the estate exit code: 0 green;
    failures + errors ( warm-up failures and confirmed leaks included ) clamped at 249; 250 when no test ran; 251 when
    the runner itself raised or an option is unknown. }
  try
    { Our gllDUnitX fork defaults Assert.AreEqual( string, string ) to IGNORE CASE, and
      nothing at the call site reveals it - a test whose subject is the casing cannot
      fail. Strict by construction here; a test that genuinely does not care about
      case must now pass True explicitly. }
    Assert.IgnoreCaseDefault := False;

    var lOptions := TGllSuiteOptions.Defaults;
    lOptions.ConfigureRunner := RegisteredFixturesOnly;
    RunGllSuite( lOptions );
  except
    on E: Exception do
    begin
      Writeln( 'RUNNER EXCEPTION: ' + E.ClassName + ': ' + E.Message );
      ExitCode := 251;
    end;
  end;
{$ENDIF}
end.
