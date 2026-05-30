program DDevExtUnitTests;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  gllDelphiDFMParser in '..\Shared\PascalParser\gllDelphiDFMParser.pas',
  TestDfmParser in 'TestDfmParser.pas',
  DelphiLexer in '..\Shared\PascalParser\DelphiLexer.pas',
  TestDelphiLexer in 'TestDelphiLexer.pas',
  DelphiParserContainers in '..\Shared\PascalParser\DelphiParserContainers.pas',
  TestDelphiParserContainers in 'TestDelphiParserContainers.pas',
  DelphiExpr in '..\Shared\PascalParser\DelphiExpr.pas',
  TestDelphiExpr in 'TestDelphiExpr.pas',
  DelphiPreproc in '..\Shared\PascalParser\DelphiPreproc.pas',
  TestDelphiPreproc in 'TestDelphiPreproc.pas',
  UnitMetrics in '..\Code\DDevExtensions\Source\CompileProgress\UnitMetrics.pas',
  TestUnitMetrics in 'TestUnitMetrics.pas';

begin
  try
    WriteLn('=======================================');
    WriteLn('DDevExtensions Unit Test Suite');
    WriteLn('=======================================');
    WriteLn;

    RunAllTests;

    WriteLn;
    RunLexerTests;

    WriteLn;
    RunContainerTests;

    WriteLn;
    RunExprTests;

    WriteLn;
    RunPreprocTests;

    WriteLn;
    RunUnitMetricsTests;

    WriteLn;
    WriteLn('=======================================');
    WriteLn('All tests passed!');
    WriteLn('=======================================');
    ReadLn; // Pause before closing
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('FAILED: ' + E.ClassName + ': ' + E.Message);
      WriteLn;
      WriteLn('Press Enter to exit...');
      ReadLn;
      ExitCode := 1;
    end;
  end;
end.
