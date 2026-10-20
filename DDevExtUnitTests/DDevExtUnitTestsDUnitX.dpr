program DDevExtUnitTestsDUnitX;

{ Three runners, chosen by conditional define:

    TESTINSIGHT       - the IDE's TestInsight host. Defined per-configuration in the
                        .dproj Debug config, never here, so that the Release build can
                        run headless. This is the one to use while writing tests.
    GUI_TEST_RUNNER   - the DUnitX VCL GUI runner. Opt-in.
    (neither)         - console runner with an NUnit XML report and a meaningful exit
                        code. This is what Release builds and what CI should call. }

{$IF DEFINED( TESTINSIGHT ) AND DEFINED( GUI_TEST_RUNNER )}
  {$MESSAGE FATAL 'Define TESTINSIGHT or GUI_TEST_RUNNER, not both.'}
{$IFEND}

{$IF DEFINED( TESTINSIGHT ) OR DEFINED( GUI_TEST_RUNNER )}
  {$APPTYPE GUI}
{$ELSE}
  {$APPTYPE CONSOLE}
{$IFEND}
{$STRONGLINKTYPES ON}

uses
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
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ENDIF}
  {$IFDEF GUI_TEST_RUNNER}
  DUnitX.Loggers.GUI.VCL,
  {$ENDIF}
  {$IF NOT ( DEFINED( TESTINSIGHT ) OR DEFINED( GUI_TEST_RUNNER ) )}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.Exceptions,
  {$IFEND}
  DUnitX.TestFramework,
  gllDelphiDFMParser in '..\Shared\PascalParser\gllDelphiDFMParser.pas',
  TestDfmParserDUnitX in 'TestDfmParserDUnitX.pas',
  ProjectGroupSorterCore in '..\Code\DDevExtensions\Source\ProjectGroupSorter\ProjectGroupSorterCore.pas',
  TestProjectGroupSorterDUnitX in 'TestProjectGroupSorterDUnitX.pas',
  PathCompactorCore in '..\Code\DDevExtensions\Source\PathCompactor\PathCompactorCore.pas',
  TestPathCompactorDUnitX in 'TestPathCompactorDUnitX.pas',
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
  UnitMetrics in '..\Code\DDevExtensions\Source\CompileProgress\UnitMetrics.pas',
  TestUnitMetricsDUnitX in 'TestUnitMetricsDUnitX.pas';

{$R *.res}

{$IF NOT ( DEFINED( TESTINSIGHT ) OR DEFINED( GUI_TEST_RUNNER ) )}
var
  Runner: ITestRunner;
  Results: IRunResults;
  XmlFile: string;
{$IFEND}

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ENDIF}

{$IFDEF GUI_TEST_RUNNER}
  Application.Initialize;
  TStyleManager.TrySetStyle( 'Aqua Light Slate' );
  Application.Title := 'DDevExtensions Unit Tests';
  Application.CreateForm( TGUIVCLTestRunner, GUIVCLTestRunner );

  // Adjust font size for better readability
  GUIVCLTestRunner.Font.Size := 10;

  Application.Run;
{$ENDIF}

{$IF NOT ( DEFINED( TESTINSIGHT ) OR DEFINED( GUI_TEST_RUNNER ) )}
  { Honour DUnitX's own command line: the result-XML path test_run passes, and --run:<names>
    to run one fixture.  An unknown option exits 251 rather than silently running the whole
    suite. }
  try
    TDUnitX.CheckCommandLine;
  except
    on E: ECommandLineError do
    begin
      Writeln( 'Command-line error: ' + E.Message );
      ExitCode := 251;
      Exit;
    end;
  end;

  try
    { Our gllDUnitX fork defaults Assert.AreEqual( string, string ) to IGNORE CASE, and
      nothing at the call site reveals it - a test whose subject is the casing cannot
      fail. Strict by construction here; a test that genuinely does not care about
      case must now pass True explicitly. }
    Assert.IgnoreCaseDefault := False;

    { Every fixture registers itself in its unit's initialization section, so RTTI
      discovery is switched off - leaving it on collects each fixture a second time
      and every test runs twice. }
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := False;
    Runner.AddLogger( TDUnitXConsoleLogger.Create( True ) );
    { The estate runner reads <exeDir>\<exeBaseName>-results.xml when it names no file. }
    XmlFile := TDUnitX.Options.XMLOutputFile;
    if ( XmlFile = '' ) or SameText( ExtractFileName( XmlFile ), 'dunitx-results.xml' ) then
      XmlFile := ChangeFileExt( ParamStr( 0 ), '' ) + '-results.xml';
    Runner.AddLogger( TDUnitXXMLNUnitFileLogger.Create( XmlFile ) );

    Results := Runner.Execute;

    Writeln( '' );
    Writeln( Format( 'TOTAL %d   PASSED %d   FAILED %d   ERRORS %d',
      [ Results.TestCount, Results.PassCount, Results.FailureCount, Results.ErrorCount ] ) );

    { The estate exit-code contract: 0 green, failures + errors clamped at 249, 250 when no
      test ran ( a filter matching nothing must never read as green ), 251 when the runner
      itself raised. }
    if Results.TestCount = 0 then
      ExitCode := 250
    else if Results.AllPassed then
      ExitCode := 0
    else if Results.FailureCount + Results.ErrorCount > 249 then
      ExitCode := 249
    else
      ExitCode := Results.FailureCount + Results.ErrorCount;
  except
    on E: Exception do
    begin
      Writeln( 'RUNNER EXCEPTION: ' + E.ClassName + ': ' + E.Message );
      ExitCode := 251;
    end;
  end;
{$IFEND}
end.
