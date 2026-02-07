program DfmParserTestsDUnitX;

{$STRONGLINKTYPES ON}

uses
  FastMM5,
  System.SysUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Themes,
  Vcl.Styles,
  DUnitX.TestFramework,
  DUnitX.Loggers.GUI.VCL,
  gllDelphiDFMParser in '..\Shared\PascalParser\gllDelphiDFMParser.pas',
  TestDfmParserDUnitX in 'TestDfmParserDUnitX.pas';

{$R *.res}

begin
  Application.Initialize;
  TStyleManager.TrySetStyle('Aqua Light Slate');
  Application.Title := 'DFM Parser Tests';
  Application.CreateForm(TGUIVCLTestRunner, GUIVCLTestRunner);

  // Adjust font size for better readability
  GUIVCLTestRunner.Font.Size := 10;

  Application.Run;
end.
