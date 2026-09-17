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
  TestDecirculariserCoreDUnitX in 'TestDecirculariserCoreDUnitX.pas';

{$R *.res}

{$IF NOT ( DEFINED( TESTINSIGHT ) OR DEFINED( GUI_TEST_RUNNER ) )}
var
  Runner: ITestRunner;
  Results: IRunResults;
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
    Runner.AddLogger( TDUnitXXMLNUnitFileLogger.Create( TDUnitX.Options.XMLOutputFile ) );

    Results := Runner.Execute;

    Writeln( '' );
    Writeln( Format( 'TOTAL %d   PASSED %d   FAILED %d   ERRORS %d',
      [ Results.TestCount, Results.PassCount, Results.FailureCount, Results.ErrorCount ] ) );

    { A non-zero exit code is the whole point of the headless runner - without it a
      build server cannot tell a red suite from a green one. }
    if Results.AllPassed then
      ExitCode := 0
    else
      ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln( 'RUNNER EXCEPTION: ' + E.ClassName + ': ' + E.Message );
      ExitCode := 2;
    end;
  end;
{$IFEND}
end.
