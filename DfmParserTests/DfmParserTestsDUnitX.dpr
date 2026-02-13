program DfmParserTestsDUnitX;

{$IFNDEF TESTINSIGHT}
{$APPTYPE GUI}
{$ENDIF}
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
  ExceptionLog7,
  {$ENDIF EurekaLog}
  System.SysUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Themes,
  Vcl.Styles,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.GUI.VCL,
  {$ENDIF}
  DUnitX.TestFramework,
  gllDelphiDFMParser in '..\Shared\PascalParser\gllDelphiDFMParser.pas',
  TestDfmParserDUnitX in 'TestDfmParserDUnitX.pas';

{$R *.res}

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  Application.Initialize;
  TStyleManager.TrySetStyle('Aqua Light Slate');
  Application.Title := 'DFM Parser Tests';
  Application.CreateForm(TGUIVCLTestRunner, GUIVCLTestRunner);

  // Adjust font size for better readability
  GUIVCLTestRunner.Font.Size := 10;

  Application.Run;
{$ENDIF}
end.

