program DebugRealWorld;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Math,
  gllDelphiDFMParser in '..\Shared\PascalParser\gllDelphiDFMParser.pas';

var
  Original, Serialized: string;
  Doc: TDfmDocument;
  i: Integer;
begin
  try
    WriteLn('Testing RealWorld_BackupDialog.dfm...');
    WriteLn;

    if not FileExists('TestData\RealWorld_BackupDialog.dfm') then
    begin
      WriteLn('ERROR: File not found');
      Exit;
    end;

    Original := TFile.ReadAllText('TestData\RealWorld_BackupDialog.dfm', TEncoding.UTF8);
    WriteLn('Original length: ' + IntToStr(Length(Original)));

    Doc := TDelphiDfmParser.Parse(Original);
    try
      WriteLn('Parsed successfully');
      WriteLn('Root: ' + Doc.Root.Name + ': ' + Doc.Root.TypeName);
      WriteLn('Root properties: ' + IntToStr(Doc.Root.Properties.Count));
      WriteLn('Root children: ' + IntToStr(Doc.Root.Children.Count));
      WriteLn;

      Serialized := TDelphiDfmParser.Serialize(Doc);
      WriteLn('Serialized length: ' + IntToStr(Length(Serialized)));
      WriteLn;

      if Original = Serialized then
        WriteLn('SUCCESS - Round-trip is lossless!')
      else
      begin
        WriteLn('FAILED - Round-trip lost data');
        WriteLn('Lost bytes: ' + IntToStr(Length(Original) - Length(Serialized)));
        WriteLn;

        // Find first difference
        for i := 1 to Min(Length(Original), Length(Serialized)) do
        begin
          if Original[i] <> Serialized[i] then
          begin
            WriteLn('First difference at position ' + IntToStr(i));
            WriteLn('Original char: #' + IntToStr(Ord(Original[i])) + ' ''' + Original[i] + '''');
            WriteLn('Serialized char: #' + IntToStr(Ord(Serialized[i])) + ' ''' + Serialized[i] + '''');
            WriteLn('Context (Original): ' + Copy(Original, Max(1, i-20), 40));
            WriteLn('Context (Serialized): ' + Copy(Serialized, Max(1, i-20), 40));
            Break;
          end;
        end;

        // Save both to files for comparison
        TFile.WriteAllText('TestData\Debug_Original.txt', Original, TEncoding.UTF8);
        TFile.WriteAllText('TestData\Debug_Serialized.txt', Serialized, TEncoding.UTF8);
        WriteLn;
        WriteLn('Saved to Debug_Original.txt and Debug_Serialized.txt for comparison');
      end;
    finally
      Doc.Free;
    end;

    WriteLn;
    WriteLn('Press Enter...');
    ReadLn;
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ' + E.ClassName + ': ' + E.Message);
      WriteLn('Press Enter...');
      ReadLn;
    end;
  end;
end.
