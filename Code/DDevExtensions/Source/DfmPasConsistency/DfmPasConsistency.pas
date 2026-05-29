{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit DfmPasConsistency;

/// <summary>
/// DDevExtensions plugin that compares each form's <c>.dfm</c> file with its companion <c>.pas</c>
/// unit, looking for components that appear in one file but not the other, or whose declared type
/// does not match. Helps surface stale designer state and orphaned field declarations.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, Vcl.Menus, ToolsAPI, PluginConfig, FrmTreePages,
  FrmeOptionPageDfmPas, System.Generics.Collections;

type
  /// <summary>Classification of a DFM/PAS inconsistency.</summary>
  TInconsistencyType = (
    /// <summary>Component appears in the DFM but is not declared in the PAS.</summary>
    itMissingInPas,
    /// <summary>Field is declared in the PAS but no component exists in the DFM.</summary>
    itMissingInDfm,
    /// <summary>Component exists in both files but the declared types differ.</summary>
    itTypeMismatch
  );

  /// <summary>Detailed description of one inconsistency between a DFM and its PAS unit.</summary>
  TInconsistencyInfo = record
    /// <summary>Bare unit name for display.</summary>
    UnitName: string;
    /// <summary>Component identifier as it appears in the source.</summary>
    ComponentName: string;
    /// <summary>Component type as declared in the DFM (or empty when missing).</summary>
    DfmType: string;
    /// <summary>Field type as declared in the PAS (or empty when missing).</summary>
    PasType: string;
    /// <summary>Classification of the inconsistency.</summary>
    InconsistencyType: TInconsistencyType;
    /// <summary>Absolute path of the DFM file.</summary>
    DfmFileName: string;
    /// <summary>Absolute path of the PAS file.</summary>
    PasFileName: string;
    /// <summary>Line number in the DFM file (0 when not applicable).</summary>
    DfmLineNumber: Integer;
    /// <summary>Line number in the PAS file (0 when not applicable).</summary>
    PasLineNumber: Integer;
  end;

  /// <summary>
  /// Plugin host integrating the DFM/PAS consistency check into DDevExtensions. Provides the
  /// static <see cref="AnalyzeUnit"/> entry point used by the result form.
  /// </summary>
  TDfmPasConsistencyPlugin = class(TPluginConfig)
  private
    /// <summary>Menu item added to the DDevExtensions submenu.</summary>
    FMenuItem: TMenuItem;
    /// <summary>Master enable flag for the plugin.</summary>
    FEnabled: Boolean;
    /// <summary>Menu OnClick handler that opens the result form.</summary>
    procedure MenuItemClick(Sender: TObject);
  protected
    /// <summary>Returns the option page used in the IDE options dialog.</summary>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises configuration to its built-in defaults.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the plugin and registers its menu item.</summary>
    constructor Create;
    /// <summary>Removes the menu item and releases the plugin.</summary>
    destructor Destroy; override;

    /// <summary>
    /// Analyses one form unit by comparing the components declared in <paramref name="DfmSource"/>
    /// with the field declarations in <paramref name="PasSource"/>.
    /// </summary>
    /// <param name="PasSource">UTF-8 text of the Pascal unit.</param>
    /// <param name="DfmSource">UTF-8 text of the companion DFM file.</param>
    /// <param name="FileName">Absolute path of the PAS file (used for report metadata).</param>
    /// <returns>Array of <see cref="TInconsistencyInfo"/> values describing the differences.</returns>
    class function AnalyzeUnit(const PasSource, DfmSource: UTF8String;
      const FileName: string): TArray<TInconsistencyInfo>;
  published
    /// <summary>Persisted master enable flag.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

var
  /// <summary>Singleton plugin instance.</summary>
  DfmPasConsistencyPlugin: TDfmPasConsistencyPlugin;

/// <summary>
/// Plugin lifecycle entry point — creates or releases <see cref="DfmPasConsistencyPlugin"/>.
/// </summary>
/// <param name="Unload"><c>True</c> to release the plugin, <c>False</c> to create it.</param>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  Winapi.Windows, Vcl.Forms, Vcl.Dialogs, Main, IDENotifiers, ToolsAPIHelpers, DelphiLexer,
  FrmDfmPasConsistency;

type
  TComponentInfo = record
    Name: string;
    TypeName: string;
    LineNumber: Integer;
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
begin
  inherited Create(AppDataDirectory + '\DfmPasConsistency.xml', 'DfmPasConsistency');

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem := TMenuItem.Create(DDevExtensionsMenu);
    FMenuItem.Caption := 'DFM/PAS &Consistency...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add(FMenuItem);
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

  function IsDatasetFieldType(const TypeName: string): Boolean;
  var
    UpperType: string;
  begin
    // Dataset field types (TField descendants) don't need explicit PAS declarations
    // They are auto-generated persistent fields accessed via FieldByName or dataset
    UpperType := UpperCase(TypeName);
    Result := (Length(UpperType) > 5) and
              (UpperType[1] = 'T') and
              (Copy(UpperType, Length(UpperType) - 4, 5) = 'FIELD');
  end;

  function IsNonComponentType(const TypeName: string): Boolean;
  var
    UpperType: string;
  begin
    if TypeName = '' then
      Exit(False);

    // Filter out common non-component types that are often declared as form fields
    // but are not visual/non-visual components placed on forms
    UpperType := UpperCase(TypeName);
    Result :=
      // Collection types
      (Pos('TLIST', UpperType) > 0) or
      (Pos('DICTIONARY', UpperType) > 0) or
      (Pos('TSTACK', UpperType) > 0) or
      (Pos('TQUEUE', UpperType) > 0) or
      (Pos('THASH', UpperType) > 0) or
      (UpperType = 'TSTRINGLIST') or
      (UpperType = 'TSTRINGS') or
      // Thread types
      (Pos('TTHREAD', UpperType) > 0) or
      // Stream types
      (Pos('TSTREAM', UpperType) > 0) or
      // Graphics objects (not components, usually owned by other components)
      (UpperType = 'TBITMAP') or
      (UpperType = 'TICON') or
      (UpperType = 'TPICTURE') or
      (UpperType = 'TBRUSH') or
      (UpperType = 'TPEN') or
      (UpperType = 'TFONT') or
      (UpperType = 'TCANVAS') or
      // Other common non-component types
      (UpperType = 'TINIFILE') or
      (UpperType = 'TREGISTRY') or
      (UpperType = 'TXMLNODE') or
      (UpperType = 'TXMLDOCUMENT') or
      (UpperType = 'TJSONVALUE') or
      (UpperType = 'TJSONOBJECT') or
      (UpperType = 'TJSONARRAY') or
      // Value types and records
      (UpperType = 'TPOINT') or
      (UpperType = 'TRECT') or
      (UpperType = 'TSIZE') or
      (UpperType = 'TSHIFTSTATE') or
      (UpperType = 'TGUID') or
      // Action/event types (often from method parameters)
      (UpperType = 'TCLOSEACTION') or
      (UpperType = 'TDATAACTION') or
      (UpperType = 'TCUSTOMFORM') or
      // State types (used in event handlers)
      (Pos('STATE', UpperType) > 0) or  // TGridDrawState, TOwnerDrawState, etc.
      (Pos('ACTIVITY', UpperType) > 0) or  // TMouseActivity, etc.
      // Abstract base classes often used as variable types, not placed components
      (UpperType = 'TDATASET') or
      (UpperType = 'TFIELD') or
      (UpperType = 'TCOMPONENT') or
      (UpperType = 'TCONTROL') or
      (UpperType = 'TWINCONTROL') or
      // Interface types (start with I, not T, but check anyway)
      (TypeName[1] = 'I');
  end;

  procedure ParseDfmComponents;
  var
    Lines: TStringList;
    I: Integer;
    TrimmedLine: string;
    CompInfo: TComponentInfo;
    ColonPos: Integer;
    ObjectDepth: Integer;
    CollectionDepth: Integer;  // Track < > collection blocks
  begin
    Lines := TStringList.Create;
    try
      Lines.Text := string(DfmSource);
      ObjectDepth := 0;
      CollectionDepth := 0;

      for I := 0 to Lines.Count - 1 do
      begin
        TrimmedLine := Trim(Lines[I]);

        // Track collection blocks (< >) - these contain item/end pairs we must ignore
        // Collection properties look like: Items = < ... > (potentially multi-line)
        if Pos('= <', TrimmedLine) > 0 then
        begin
          // Check if it's a single-line empty collection: = <>
          if Pos('>', TrimmedLine) = 0 then
            Inc(CollectionDepth);  // Multi-line collection starts
          // else: Single-line collection like = <>, no depth change needed
        end
        else if (CollectionDepth > 0) and
                ((TrimmedLine = '>') or
                 (Copy(TrimmedLine, Length(TrimmedLine), 1) = '>')) then
          Dec(CollectionDepth);

        // Skip processing if we're inside a collection block
        if CollectionDepth > 0 then
          Continue;

        // Look for "object ComponentName: ComponentType"
        if (Pos('object ', LowerCase(TrimmedLine)) = 1) or
           (Pos('inherited ', LowerCase(TrimmedLine)) = 1) or
           (Pos('inline ', LowerCase(TrimmedLine)) = 1) then
        begin
          Inc(ObjectDepth);

          // Only process components (ObjectDepth >= 2), skip the form itself (ObjectDepth = 1)
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

            // Skip dataset field types - they don't need PAS declarations
            if not IsDatasetFieldType(CompInfo.TypeName) then
              DfmComponents.AddOrSetValue(UpperCase(CompInfo.Name), CompInfo);
          end;
        end
        else if SameText(TrimmedLine, 'end') then
        begin
          // Only decrement object depth for 'end' outside collection blocks
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
    Done: Boolean;
    CurrentFieldLine: Integer;
    ParenDepth: Integer;
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
      CurrentFieldLine := 0;
      Done := False;

      while (not Done) and Lexer.NextToken(Token) do
      begin
        case Token.Kind of
          tkI_type:
            InType := True;

          tkI_implementation:
            Done := True; // Stop at implementation - Break only exits case, not while

          tkI_class:
            if InType then
            begin
              // Entering a class - reset visibility for this class
              InFormClass := True;
              InPublished := True; // Fields before any visibility are published by default
              InPrivate := False;
              InPublic := False;
              InProtected := False;
              CurrentFieldName := '';
              ExpectingType := False;
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
              // Skip to end of declaration - must handle parentheses for parameters
              // e.g., procedure Foo(Sender: TObject; var Action: TCloseAction);
              // The semicolon inside () separates parameters, not the end of declaration
              ParenDepth := 0;
              while Lexer.NextToken(Token) do
              begin
                if Token.Kind = tkLParan then
                  Inc(ParenDepth)
                else if Token.Kind = tkRParan then
                  Dec(ParenDepth)
                else if (Token.Kind = tkSemicolon) and (ParenDepth = 0) then
                  Break;
              end;
            end;

          tkI_end:
            begin
              // End of current class, but stay in type section for potential next class
              if InFormClass then
                InFormClass := False;
              // Don't reset InType - there might be more classes in the type section
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
                  PasInfo.LineNumber := CurrentFieldLine;  // Use line from field name, not type
                  PasComponents.AddOrSetValue(UpperCase(CurrentFieldName), PasInfo);
                end;
                CurrentFieldName := '';
                CurrentFieldLine := 0;
                ExpectingType := False;
              end
              else
              begin
                // This might be a field name - save its line number
                // Token.Line is 0-based, convert to 1-based for display
                CurrentFieldName := string(Token.Value);
                CurrentFieldLine := Token.Line + 1;
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
            CurrentFieldLine := 0;
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
        Info.DfmFileName := ChangeFileExt(FileName, '.dfm');
        Info.PasFileName := FileName;
        Info.DfmLineNumber := DfmInfo.LineNumber;
        Info.PasLineNumber := 0; // Not in PAS
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
          Info.DfmFileName := ChangeFileExt(FileName, '.dfm');
          Info.PasFileName := FileName;
          Info.DfmLineNumber := DfmInfo.LineNumber;
          Info.PasLineNumber := PasInfo.LineNumber;
          Results.Add(Info);
        end;
      end;
    end;

    // Compare: Find fields in PAS but not in DFM (only likely component types)
    for Key in PasComponents.Keys do
    begin
      PasInfo := PasComponents[Key];
      // Only check if it looks like a component type (starts with T)
      // and is not a common non-component type or dataset field type
      if (Length(PasInfo.TypeName) > 1) and (PasInfo.TypeName[1] = 'T') and
         not DfmComponents.ContainsKey(Key) and
         not IsNonComponentType(PasInfo.TypeName) and
         not IsDatasetFieldType(PasInfo.TypeName) then
      begin
        Info.UnitName := ChangeFileExt(ExtractFileName(FileName), '');
        Info.ComponentName := PasInfo.Name;
        Info.DfmType := '';
        Info.PasType := PasInfo.TypeName;
        Info.InconsistencyType := itMissingInDfm;
        Info.DfmFileName := ChangeFileExt(FileName, '.dfm');
        Info.PasFileName := FileName;
        Info.DfmLineNumber := 0; // Not in DFM
        Info.PasLineNumber := PasInfo.LineNumber;
        Results.Add(Info);
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
