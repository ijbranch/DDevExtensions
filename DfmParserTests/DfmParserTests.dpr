program DfmParserTests;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  gllDelphiDFMParser in '..\Shared\PascalParser\gllDelphiDFMParser.pas',
  TestDfmParser in 'TestDfmParser.pas';

begin
  try
    WriteLn('=======================================');
    WriteLn('DelphiDfmParser Test Suite');
    WriteLn('=======================================');
    WriteLn;

    RunAllTests;

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
