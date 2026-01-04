{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit DfmPasConsistency;

{$I ..\DelphiExtension.inc}

interface

uses
  SysUtils, Classes, Menus, ToolsAPI, PluginConfig, FrmTreePages,
  FrmeOptionPageDfmPas, Generics.Collections;

type
  TInconsistencyType = (
    itMissingInPas,      // Component in DFM but not declared in PAS
    itMissingInDfm,      // Declared in PAS but not in DFM
    itTypeMismatch       // Component exists but type differs
  );

  TInconsistencyInfo = record
    UnitName: string;
    ComponentName: string;
    DfmType: string;
    PasType: string;
    InconsistencyType: TInconsistencyType;
    FileName: string;
    LineNumber: Integer;
  end;

  TDfmPasConsistencyPlugin = class(TPluginConfig)
  private
    FMenuItem: TMenuItem;
    FEnabled: Boolean;
    procedure MenuItemClick(Sender: TObject);
  protected
    function GetOptionPages: TTreePage; override;
    procedure Init; override;
  public
    constructor Create;
    destructor Destroy; override;

    class function AnalyzeUnit(const PasSource, DfmSource: UTF8String;
      const FileName: string): TArray<TInconsistencyInfo>;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

var
  DfmPasConsistencyPlugin: TDfmPasConsistencyPlugin;

procedure InitPlugin(Unload: Boolean);

implementation

uses
  Windows, Forms, Dialogs, Main, IDENotifiers, ToolsAPIHelpers, DelphiLexer,
  FrmDfmPasConsistency;

type
  TComponentInfo = record
    Name: string;
    TypeName: string;
    LineNumber: Integer;
  end;

function FindMenuItem(const Name: string): TMenuItem;
var
  NTAServices: INTAServices;
begin
  Result := nil;
  if Supports(BorlandIDEServices, INTAServices, NTAServices) then
    Result := NTAServices.MainMenu.Items.Find(Name);
end;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    DfmPasConsistencyPlugin := TDfmPasConsistencyPlugin.Create
  else
    FreeAndNil(DfmPasConsistencyPlugin);
end;

{ TDfmPasConsistencyPlugin }

constructor TDfmPasConsistencyPlugin.Create;
var
  ToolsMenu: TMenuItem;
begin
  inherited Create(AppDataDirectory + '\DfmPasConsistency.xml', 'DfmPasConsistency');

  // Add menu item under Tools menu
  ToolsMenu := FindMenuItem('ToolsMenu');

  if ToolsMenu <> nil then
  begin
    FMenuItem := TMenuItem.Create(ToolsMenu);
    FMenuItem.Caption := 'DFM/PAS &Consistency...';
    FMenuItem.OnClick := MenuItemClick;
    ToolsMenu.Add(FMenuItem);
  end;
end;

destructor TDfmPasConsistencyPlugin.Destroy;
begin
  FreeAndNil(FMenuItem);
  inherited Destroy;
end;

function TDfmPasConsistencyPlugin.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('DFM/PAS Consistency', TFrameOptionPageDfmPas, Self);
end;

procedure TDfmPasConsistencyPlugin.Init;
begin
  inherited Init;
  FEnabled := True;
end;

procedure TDfmPasConsistencyPlugin.MenuItemClick(Sender: TObject);
begin
  if not Enabled then
  begin
    ShowMessage('DFM/PAS Consistency Checker is disabled. Enable it in DDevExtensions options.');
    Exit;
  end;

  TFormDfmPasConsistency.Execute;
end;

class function TDfmPasConsistencyPlugin.AnalyzeUnit(const PasSource, DfmSource: UTF8String;
  const FileName: string): TArray<TInconsistencyInfo>;
var
  DfmComponents: TDictionary<string, TComponentInfo>;
  PasComponents: TDictionary<string, TComponentInfo>;
  Results: TList<TInconsistencyInfo>;
  Info: TInconsistencyInfo;
  Lexer: TDelphiLexer;
  Token: TToken;
  InType: Boolean;
  InFormClass: Boolean;
  CurrentFieldName: string;
  CurrentFieldType: string;
  Key: string;
  DfmInfo, PasInfo: TComponentInfo;

  function ExtractFormClassName(const Source: UTF8String): string;
  var
    L: TDelphiLexer;
    T: TToken;
    InTypeSection: Boolean;
  begin
    Result := '';
    L := TDelphiLexer.Create('', Source);
    try
      InTypeSection := False;
      while L.NextToken(T) do
      begin
        if T.Kind = tkI_type then
          InTypeSection := True
        else if T.Kind in [tkI_var, tkI_const, tkI_procedure, tkI_function, tkI_implementation] then
          InTypeSection := False
        else if InTypeSection and (T.Kind >= tkIdent) then
        begin
          // Look for TFormXxx = class(TForm)
          if L.NextToken(T) and (T.Kind = tkEqual) then
          begin
            if L.NextToken(T) and (T.Kind = tkI_class) then
            begin
              // Found a class declaration - check if it inherits from TForm/TFrame/TDataModule
              if L.NextToken(T) and (T.Kind = tkLParan) then
              begin
                if L.NextToken(T) and (T.Kind >= tkIdent) then
                begin
                  if (Pos('FORM', UpperCase(string(T.Value))) > 0) or
                     (Pos('FRAME', UpperCase(string(T.Value))) > 0) or
                     (Pos('DATAMODULE', UpperCase(string(T.Value))) > 0) then
                  begin
                    // Go back to get the class name
                    Result := string(T.Value);
                    Exit;
                  end;
                end;
              end;
            end;
          end;
        end;
      end;
    finally
      L.Free;
    end;
  end;

  procedure ParseDfmComponents;
  var
    Lines: TStringList;
    I: Integer;
    TrimmedLine: string;
    CompInfo: TComponentInfo;
    ColonPos: Integer;
    ObjectDepth: Integer;
  begin
    Lines := TStringList.Create;
    try
      Lines.Text := string(DfmSource);
      ObjectDepth := 0;

      for I := 0 to Lines.Count - 1 do
      begin
        TrimmedLine := Trim(Lines[I]);

        // Look for "object ComponentName: ComponentType"
        if (Pos('object ', LowerCase(TrimmedLine)) = 1) or
           (Pos('inherited ', LowerCase(TrimmedLine)) = 1) or
           (Pos('inline ', LowerCase(TrimmedLine)) = 1) then
        begin
          Inc(ObjectDepth);

          // Only process top-level components (direct children of the form)
          if ObjectDepth = 1 then
            Continue; // This is the form itself

          // Parse "object Name: Type"
          if Pos('object ', LowerCase(TrimmedLine)) = 1 then
            TrimmedLine := Trim(Copy(TrimmedLine, 8, MaxInt))
          else if Pos('inherited ', LowerCase(TrimmedLine)) = 1 then
            TrimmedLine := Trim(Copy(TrimmedLine, 11, MaxInt))
          else if Pos('inline ', LowerCase(TrimmedLine)) = 1 then
            TrimmedLine := Trim(Copy(TrimmedLine, 8, MaxInt));

          ColonPos := Pos(':', TrimmedLine);
          if ColonPos > 0 then
          begin
            CompInfo.Name := Trim(Copy(TrimmedLine, 1, ColonPos - 1));
            CompInfo.TypeName := Trim(Copy(TrimmedLine, ColonPos + 1, MaxInt));
            CompInfo.LineNumber := I + 1;

            DfmComponents.AddOrSetValue(UpperCase(CompInfo.Name), CompInfo);
          end;
        end
        else if TrimmedLine = 'end' then
        begin
          if ObjectDepth > 0 then
            Dec(ObjectDepth);
        end;
      end;
    finally
      Lines.Free;
    end;
  end;

  procedure ParsePasComponents;
  var
    InPrivate, InPublic, InPublished, InProtected: Boolean;
    ExpectingType: Boolean;
  begin
    Lexer := TDelphiLexer.Create('', PasSource);
    try
      InType := False;
      InFormClass := False;
      InPrivate := False;
      InPublic := False;
      InPublished := False;
      InProtected := False;
      ExpectingType := False;
      CurrentFieldName := '';

      while Lexer.NextToken(Token) do
      begin
        case Token.Kind of
          tkI_type:
            InType := True;

          tkI_implementation:
            Break; // Stop at implementation

          tkI_class:
            if InType then
            begin
              // Check if this is a form class
              InFormClass := True;
              InPublished := True; // Fields before any visibility are published by default
            end;

          tkI_private:
            begin
              InPrivate := True;
              InPublic := False;
              InPublished := False;
              InProtected := False;
            end;

          tkI_public:
            begin
              InPrivate := False;
              InPublic := True;
              InPublished := False;
              InProtected := False;
            end;

          tkI_published:
            begin
              InPrivate := False;
              InPublic := False;
              InPublished := True;
              InProtected := False;
            end;

          tkI_protected:
            begin
              InPrivate := False;
              InPublic := False;
              InPublished := False;
              InProtected := True;
            end;

          tkI_procedure, tkI_function, tkI_constructor, tkI_destructor, tkI_property:
            begin
              // Skip to end of declaration
              while Lexer.NextToken(Token) and (Token.Kind <> tkSemicolon) do ;
            end;

          tkI_end:
            begin
              if InFormClass then
              begin
                InFormClass := False;
                InType := False;
              end;
            end;
        else
          if Token.Kind >= tkIdent then
          begin
            if InFormClass and (InPublished or (not InPrivate and not InPublic and not InProtected)) then
            begin
              if ExpectingType then
              begin
                // This is the type
                CurrentFieldType := string(Token.Value);
                if CurrentFieldName <> '' then
                begin
                  PasInfo.Name := CurrentFieldName;
                  PasInfo.TypeName := CurrentFieldType;
                  PasInfo.LineNumber := Token.Line;
                  PasComponents.AddOrSetValue(UpperCase(CurrentFieldName), PasInfo);
                end;
                CurrentFieldName := '';
                ExpectingType := False;
              end
              else
              begin
                // This might be a field name
                CurrentFieldName := string(Token.Value);
              end;
            end;
          end
          else if Token.Kind = tkColon then
          begin
            if InFormClass and (CurrentFieldName <> '') then
              ExpectingType := True;
          end
          else if Token.Kind = tkSemicolon then
          begin
            ExpectingType := False;
            CurrentFieldName := '';
          end;
        end;
      end;
    finally
      Lexer.Free;
    end;
  end;

begin
  DfmComponents := TDictionary<string, TComponentInfo>.Create;
  PasComponents := TDictionary<string, TComponentInfo>.Create;
  Results := TList<TInconsistencyInfo>.Create;
  try
    // Parse DFM for component definitions
    ParseDfmComponents;

    // Parse PAS for field declarations
    ParsePasComponents;

    // Compare: Find components in DFM but not in PAS
    for Key in DfmComponents.Keys do
    begin
      DfmInfo := DfmComponents[Key];
      if not PasComponents.TryGetValue(Key, PasInfo) then
      begin
        Info.UnitName := ChangeFileExt(ExtractFileName(FileName), '');
        Info.ComponentName := DfmInfo.Name;
        Info.DfmType := DfmInfo.TypeName;
        Info.PasType := '';
        Info.InconsistencyType := itMissingInPas;
        Info.FileName := FileName;
        Info.LineNumber := DfmInfo.LineNumber;
        Results.Add(Info);
      end
      else
      begin
        // Check type mismatch
        if not SameText(DfmInfo.TypeName, PasInfo.TypeName) then
        begin
          Info.UnitName := ChangeFileExt(ExtractFileName(FileName), '');
          Info.ComponentName := DfmInfo.Name;
          Info.DfmType := DfmInfo.TypeName;
          Info.PasType := PasInfo.TypeName;
          Info.InconsistencyType := itTypeMismatch;
          Info.FileName := FileName;
          Info.LineNumber := PasInfo.LineNumber;
          Results.Add(Info);
        end;
      end;
    end;

    // Compare: Find fields in PAS but not in DFM (only component types)
    for Key in PasComponents.Keys do
    begin
      PasInfo := PasComponents[Key];
      // Only check if it looks like a component type (starts with T)
      if (Length(PasInfo.TypeName) > 1) and (PasInfo.TypeName[1] = 'T') and
         not DfmComponents.ContainsKey(Key) then
      begin
        // This might be a component that should be in DFM
        // but we'll skip this to avoid false positives from non-visual fields
      end;
    end;

    Result := Results.ToArray;
  finally
    DfmComponents.Free;
    PasComponents.Free;
    Results.Free;
  end;
end;

end.
