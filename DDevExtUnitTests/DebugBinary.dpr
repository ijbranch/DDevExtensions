program DebugBinary;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  gllDelphiDFMParser in '..\Shared\PascalParser\gllDelphiDFMParser.pas';

var
  Original, Serialized: string;
  Doc: TDfmDocument;
  Prop: TDfmProperty;
begin
  try
    WriteLn('Testing binary property parsing...');
    WriteLn;

    Original :=
      'object Image1: TImage' + #13#10 +
      '  Picture.Data = {' + #13#10 +
      '    0754426974' + #13#10 +
      '    1234567890' + #13#10 +
      '    ABCDEF}' + #13#10 +
      'end' + #13#10;

    WriteLn('Original:');
    WriteLn(Original);
    WriteLn('Length: ' + IntToStr(Length(Original)));
    WriteLn;

    Doc := TDelphiDfmParser.Parse(Original);
    try
      WriteLn('Parsed successfully');
      WriteLn('Component: ' + Doc.Root.Name + ': ' + Doc.Root.TypeName);
      WriteLn('Properties: ' + IntToStr(Doc.Root.Properties.Count));

      if Doc.Root.Properties.Count > 0 then
      begin
        Prop := Doc.Root.Properties[0];
        WriteLn('Property: ' + Prop.Name);
        WriteLn('ValueKind: ' + IntToStr(Ord(Prop.ValueKind)));
        WriteLn('RawValue:');
        WriteLn(Prop.RawValue);
        WriteLn('RawValue Length: ' + IntToStr(Length(Prop.RawValue)));
      end;

      WriteLn;
      Serialized := TDelphiDfmParser.Serialize(Doc);

      WriteLn('Serialized:');
      WriteLn(Serialized);
      WriteLn('Length: ' + IntToStr(Length(Serialized)));
      WriteLn;

      if Original = Serialized then
        WriteLn('SUCCESS - Round-trip is lossless!')
      else
      begin
        WriteLn('FAILED - Round-trip lost data');
        WriteLn('Lost bytes: ' + IntToStr(Length(Original) - Length(Serialized)));
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
