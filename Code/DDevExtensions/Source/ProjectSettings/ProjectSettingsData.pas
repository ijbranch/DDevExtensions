{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit ProjectSettingsData;

/// <summary>
/// Defines the data model for reusable project setting presets: a single named option
/// (TSettingsOption), a named bag of options (TProjectSetting) and a list of presets
/// (TProjectSettingList) with XML persistence and copy-to/from-IOTAProject support.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Variants, Windows, SysUtils, Classes, Contnrs, ToolsAPI, SimpleXmlImport, SimpleXmlIntf,
  TypInfo, Utils;

type
  /// <summary>Controls how option values are copied between a TProjectSetting and an IOTAProject.</summary>
  /// <remarks>
  /// scCopyDefault honours the global "exclude" list (paths and version info), scCopyAll copies
  /// every option regardless, and scAssign only writes options whose Active flag is set.
  /// </remarks>
  TSettingCopyMode = (scCopyDefault, scCopyAll, scAssign);

  /// <summary>A single named project option together with its value and an Active flag.</summary>
  TSettingsOption = class(TObject)
  private
    /// <summary>Backing field for the immutable Name property.</summary>
    FName: string;
    /// <summary>Backing field for Value.</summary>
    FValue: Variant;
    /// <summary>Backing field for Active.</summary>
    FActive: Boolean;
  public
    /// <summary>Creates an option with the supplied name and value (Active defaults to True).</summary>
    constructor Create(const AName: string; const AValue: Variant);
    /// <summary>Returns a deep copy of the option.</summary>
    function Clone: TSettingsOption; virtual;

    /// <summary>Read-only name of the option.</summary>
    property Name: string read FName;
    /// <summary>Variant value of the option.</summary>
    property Value: Variant read FValue write FValue;
    /// <summary>If True, the option will be applied when the parent preset is assigned.</summary>
    property Active: Boolean read FActive write FActive;
  end;

  /// <summary>A named preset that holds a list of TSettingsOption values for a project.</summary>
  TProjectSetting = class(TPersistent)
  private
    /// <summary>Owned list of TSettingsOption items.</summary>
    FOptions: TObjectList;
    /// <summary>Display name of the preset.</summary>
    FName: string;
    /// <summary>Returns the variant value of the option named Name, or Null if absent.</summary>
    function GetOption(const Name: string): Variant;
    /// <summary>Updates the value of the option named Name (no-op if absent).</summary>
    procedure SetOption(const Name: string; const Value: Variant);
    /// <summary>Returns the number of options in the preset.</summary>
    function GetCount: Integer;
    /// <summary>Returns the option at the given index.</summary>
    function GetItem(Index: Integer): TSettingsOption;
  public
    /// <summary>Creates an empty preset.</summary>
    constructor Create;
    /// <summary>Frees the owned option list.</summary>
    destructor Destroy; override;

    /// <summary>Serialises the preset (and its options) into the supplied XML node.</summary>
    procedure SaveToXml(Xml: IXmlNode);
    /// <summary>Restores the preset (and its options) from the supplied XML node.</summary>
    procedure LoadFromXml(Xml: IXmlNode);

    /// <summary>Copies the name and options from another TProjectSetting (delegates to CopyFrom).</summary>
    procedure Assign(Source: TPersistent); override;
    /// <summary>Returns True if every active option in this preset matches the corresponding option of Setting.</summary>
    function Compare(Setting: TProjectSetting): Boolean;

    /// <summary>Replaces the option list with a clone of Source's options.</summary>
    procedure CopyFrom(Source: TProjectSetting); overload;
    /// <summary>Replaces the option list with a clone of Source's options, skipping the named exclusions.</summary>
    procedure CopyFrom(Source: TProjectSetting; const ExceptList: array of string); overload; virtual;
    /// <summary>Replaces the option list with the project's current option values (respecting CopyMode).</summary>
    procedure CopyFrom(Project: IOTAProject; CopyMode: TSettingCopyMode = scCopyDefault); overload;
    /// <summary>Replaces the option list with the project's current option values, skipping the named exclusions.</summary>
    procedure CopyFrom(Project: IOTAProject; const ExceptList: array of string; CopyMode: TSettingCopyMode = scCopyDefault); overload;
    /// <summary>Writes the preset's option values into the supplied project (respecting CopyMode).</summary>
    procedure CopyTo(Project: IOTAProject; CopyMode: TSettingCopyMode = scCopyDefault); overload;
    /// <summary>Writes the preset's option values into the supplied project, skipping the named exclusions.</summary>
    procedure CopyTo(Project: IOTAProject; const ExceptList: array of string;
      CopyMode: TSettingCopyMode = scCopyDefault); overload;

    /// <summary>Returns the index of the option named AName, or -1 if absent.</summary>
    function IndexOf(const AName: string): Integer;

    /// <summary>Display name of the preset.</summary>
    property Name: string read FName write FName;
    /// <summary>Default indexer that gets/sets an option's value by its name.</summary>
    property Options[const Name: string]: Variant read GetOption write SetOption; default;
    /// <summary>Number of options in the preset.</summary>
    property Count: Integer read GetCount;
    /// <summary>Indexed access to the option items.</summary>
    property Items[Index: Integer]: TSettingsOption read GetItem;
  end;

  /// <summary>Owned list of TProjectSetting presets with file/XML persistence and lookup helpers.</summary>
  TProjectSettingList = class(TPersistent)
  private
    /// <summary>Owned list of TProjectSetting items.</summary>
    FItems: TObjectList;
    /// <summary>Cached compiler-option names (populated lazily by FillOptionNames).</summary>
    FCompilerOptions: TStrings;
    /// <summary>Cached version-info option names (currently unused).</summary>
    FVersionInfoOptions: TStrings;
    /// <summary>Cached linker-option names (populated lazily by FillOptionNames).</summary>
    FLinkerOptions: TStrings;

    /// <summary>Returns the number of presets in the list.</summary>
    function GetCount: Integer;
    /// <summary>Returns the preset at the given index.</summary>
    function GetItem(Index: Integer): TProjectSetting;
  protected
    /// <summary>Initialises the global compiler/linker option-name caches with their built-in defaults.</summary>
    class procedure InitOptions; virtual;
  public
    /// <summary>Creates an empty preset list.</summary>
    constructor Create;
    /// <summary>Frees the owned preset list.</summary>
    destructor Destroy; override;

    /// <summary>Removes the preset at the given index.</summary>
    procedure Delete(Index: Integer);
    /// <summary>Removes the supplied preset from the list (no-op if absent).</summary>
    procedure Remove(Setting: TProjectSetting);
    /// <summary>Creates a new empty preset, adds it to the list, and returns it.</summary>
    function Add: TProjectSetting;
    /// <summary>Clears all presets.</summary>
    procedure Clear;

    /// <summary>Populates List with all known option names (lazily initialising the caches).</summary>
    class procedure FillOptionNames(List: TStrings);

    /// <summary>Returns the first preset whose options match Setting (TProjectSetting.Compare), or nil.</summary>
    function FindEqual(Setting: TProjectSetting): TProjectSetting;

    /// <summary>Serialises the list to the named XML file (creating the directory if needed).</summary>
    procedure SaveToFile(const Filename: string);
    /// <summary>Loads the list from the named XML file.</summary>
    procedure LoadFromFile(const Filename: string);
    /// <summary>Serialises the list as &lt;ProjectSetting&gt; children of Xml.</summary>
    procedure SaveToXml(Xml: IXmlNode);
    /// <summary>Restores the list from the &lt;ProjectSetting&gt; children of Xml.</summary>
    procedure LoadFromXml(Xml: IXmlNode);

    /// <summary>Replaces this list with a deep copy of Source (or clears if Source is nil).</summary>
    procedure Assign(Source: TPersistent); override;
    /// <summary>Returns the index of Setting in the list, or -1 if absent.</summary>
    function IndexOf(Setting: TProjectSetting): Integer;
    /// <summary>Returns the first preset with the supplied name, or nil if absent.</summary>
    function FindByName(const AName: string): TProjectSetting;

    /// <summary>Sorts the presets alphabetically by Name.</summary>
    procedure Sort;

    /// <summary>Cached list of compiler-option names (read-only).</summary>
    property CompilerOptions: TStrings read FCompilerOptions;
    /// <summary>Cached list of linker-option names (read-only).</summary>
    property LinkerOptions: TStrings read FLinkerOptions;
    /// <summary>Cached list of version-info option names (read-only).</summary>
    property VersionInfoOptions: TStrings read FVersionInfoOptions;

    /// <summary>Number of presets in the list.</summary>
    property Count: Integer read GetCount;
    /// <summary>Default indexer over the presets.</summary>
    property Items[Index: Integer]: TProjectSetting read GetItem; default;
  end;

/// <summary>Frees the cached compiler/linker option-name lists; call once on plugin shutdown.</summary>
procedure FinializeCachedSettingData;

implementation

var
  GlobalCompilerOptions: TStrings;
  GlobalLinkerOptions: TStrings;

procedure FinializeCachedSettingData;
begin
  FreeAndNil(GlobalCompilerOptions);
  FreeAndNil(GlobalLinkerOptions);
end;

{ TSettingsOption }

constructor TSettingsOption.Create(const AName: string; const AValue: Variant);
begin
  inherited Create;
  FName := AName;
  FValue := AValue;
  FActive := True;
end;

function TSettingsOption.Clone: TSettingsOption;
begin
  Result := TSettingsOption.Create(Name, Value);
  Result.Active := FActive;
end;

{ TProjectSetting }

constructor TProjectSetting.Create;
begin
  inherited Create;
  FOptions := TObjectList.Create;
end;

destructor TProjectSetting.Destroy;
begin
  FOptions.Free;
  inherited Destroy;
end;

procedure TProjectSetting.Assign(Source: TPersistent);
begin
  if Source is TProjectSetting then
  begin
    FName := TProjectSetting(Source).Name;
    CopyFrom(TProjectSetting(Source));
  end
  else
    inherited Assign(Source);
end;

procedure TProjectSetting.CopyFrom(Source: TProjectSetting; const ExceptList: array of string);
var
  i, k: Integer;
  Ignore: Boolean;
begin
  FOptions.Clear;
  if Source <> nil then
  begin
    for i := 0 to Source.Count - 1 do
    begin
      Ignore := False;
      for k := 0 to High(ExceptList) do
      begin
        if AnsiCompareText(Source.Items[i].Name, ExceptList[k]) = 0 then
        begin
          Ignore := True;
          Break;
        end;
      end;
      if not Ignore then
        FOptions.Add(Source.Items[i].Clone);
    end;
  end;
end;

procedure TProjectSetting.CopyFrom(Source: TProjectSetting);
begin
  CopyFrom(Source, []);
end;

procedure TProjectSetting.CopyFrom(Project: IOTAProject; CopyMode: TSettingCopyMode);
begin
  CopyFrom(Project, [], CopyMode);
end;

procedure TProjectSetting.CopyFrom(Project: IOTAProject; const ExceptList: array of string;
  CopyMode: TSettingCopyMode);
var
  i, k, ListIndex: Integer;
  Ignore: Boolean;
  Names: TOTAOptionNameArray;
  List: TStrings;
  OldOptions: TObjectList;
  Item: TSettingsOption;
begin
  Names := nil;
  OldOptions := TObjectList.Create;
  {$IFDEF COMPILER5}
  for i := 0 to FOptions.Count - 1 do
    OldOptions.Add(FOptions[i]);
  {$ELSE}
  OldOptions.Assign(FOptions);
  {$ENDIF COMPILER5}
  try
    FOptions.OwnsObjects := False;
    FOptions.Clear;
    FOptions.OwnsObjects := True;
    if Project <> nil then
    begin
      Names := Project.ProjectOptions.GetOptionNames;
      List := TStringList.Create;
      try
        TProjectSettingList.FillOptionNames(List);
        for i := 0 to High(Names) do
        begin
          if Names[i].Kind in [tkClass, tkInterface, tkArray, tkRecord, tkDynArray] then
            Continue;

          Ignore := False;
          for k := 0 to High(ExceptList) do
          begin
            if AnsiCompareText(Names[i].Name, ExceptList[k]) = 0 then
            begin
              Ignore := True;
              Break;
            end;
          end;
          ListIndex := List.IndexOf(Names[i].Name);
          if not Ignore and (CopyMode <> scCopyAll) then
            Ignore := (ListIndex <> -1) and (List.Objects[ListIndex] = Pointer(2));
          if not Ignore and
             // these are Pointers:
             (Names[i].Name <> 'SysVars') and
             (Names[i].Name <> 'EnvVars') and
             (Names[i].Name <> 'Keys') then
          begin
            Item := nil;
            try
              for k := 0 to OldOptions.Count - 1 do
              begin
                if AnsiCompareText(TSettingsOption(OldOptions[k]).Name, Names[i].Name) = 0 then
                begin
                  Item := TSettingsOption(OldOptions[k]);
                  OldOptions.Extract(Item);
                  Break;
                end;
              end;
              if Item = nil then
              begin
                Item := TSettingsOption.Create(Names[i].Name, Project.ProjectOptions.Values[Names[i].Name]);
                if ListIndex <> -1 then
                  Item.Active := List.Objects[ListIndex] = nil;
              end
              else
                Item.Value := Project.ProjectOptions.Values[Names[i].Name];
            except
              Item.Free;
              Item := nil;
            end;

            if Item <> nil then
              FOptions.Add(Item);
          end;
        end;
      finally
        List.Free;
      end;
    end;
  finally
    OldOptions.Free;
  end;
end;

procedure TProjectSetting.CopyTo(Project: IOTAProject; CopyMode: TSettingCopyMode);
begin
  CopyTo(Project, [], CopyMode);
end;

procedure TProjectSetting.CopyTo(Project: IOTAProject; const ExceptList: array of string;
  CopyMode: TSettingCopyMode);
var
  i, k: Integer;
  Ignore: Boolean;
  Names: TOTAOptionNameArray;
  Index: Integer;
  List: TStrings;
  ListIndex: Integer;
begin
  Names := nil;
  if Project <> nil then
  begin
    Names := Project.ProjectOptions.GetOptionNames;
    List := TStringList.Create;
    try
      TProjectSettingList.FillOptionNames(List);
      for i := 0 to High(Names) do
      begin
        if Names[i].Name = 'Defines' then
          Write;
        if Names[i].Kind in [tkClass, tkInterface, tkArray, tkRecord, tkDynArray] then
          Continue;

        Ignore := False;
        for k := 0 to High(ExceptList) do
        begin
          if AnsiCompareText(Names[i].Name, ExceptList[k]) = 0 then
          begin
            Ignore := True;
            Break;
          end;
        end;
        ListIndex := List.IndexOf(Names[i].Name);
        if not Ignore and (CopyMode <> scCopyAll) then
          Ignore := (ListIndex <> -1) and (List.Objects[ListIndex] = Pointer(2));
        if not Ignore and
           // these are Pointers:
           (Names[i].Name <> 'SysVars') and
           (Names[i].Name <> 'EnvVars') and
           (Names[i].Name <> 'Keys') then
        begin
          Index := IndexOf(Names[i].Name);
          if (Index <> -1) and ((CopyMode <> scAssign) or Items[Index].Active) then
            Project.ProjectOptions.Values[Names[i].Name] := Items[Index].Value;
        end;
      end;
    finally
      List.Free;
    end;
  end;
end;

function TProjectSetting.GetCount: Integer;
begin
  Result := FOptions.Count;
end;

function TProjectSetting.GetItem(Index: Integer): TSettingsOption;
begin
  Result := TSettingsOption(FOptions[Index]);
end;

function TProjectSetting.GetOption(const Name: string): Variant;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
  begin
    if AnsiCompareText(Items[i].Name, Name) = 0 then
    begin
      Result := Items[i].Value;
      Exit;
    end;
  end;
  Result := Null;
end;

procedure TProjectSetting.SetOption(const Name: string; const Value: Variant);
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
  begin
    if AnsiCompareText(Items[i].Name, Name) = 0 then
    begin
      Items[i].Value := Value;
      Exit;
    end;
  end;
end;

function TProjectSetting.IndexOf(const AName: string): Integer;
begin
  for Result := 0 to Count - 1 do
    if AnsiCompareText(Items[Result].Name, AName) = 0 then
      Exit;
  Result := -1;
end;

function TProjectSetting.Compare(Setting: TProjectSetting): Boolean;
var
  i: Integer;
begin
  Result := Setting <> nil;
  if Result then
  begin
    Result := False;
    for i := 0 to Count - 1 do
      if Items[i].Active and (Setting.Options[Items[i].Name] <> Items[i].Value) then
        Exit;
    Result := True;
  end;
end;

procedure TProjectSetting.LoadFromXml(Xml: IXmlNode);
var
  i: Integer;
  Item: TSettingsOption;
  Node: IXmlNode;
begin
  FName := Xml.Attributes['Name'];
  FOptions.Clear;
  for i := 0 to Xml.ChildNodes.Count - 1 do
  begin
    Node := Xml.ChildNodes[i];
    Item := TSettingsOption.Create(Node.NodeName, Node.Attributes['Value']);
    if (Node.Attributes['Active'] <> Null) and (Node.Attributes['Active'] <> '') then
      Item.Active := Node.Attributes['Active'];
    FOptions.Add(Item);
  end;
end;

procedure TProjectSetting.SaveToXml(Xml: IXmlNode);
var
  i: Integer;
  Node: IXmlNode;
begin
  Xml.Attributes['Name'] := FName;
  for i := 0 to Count - 1 do
  begin
    Node := Xml.AddChild(Items[i].Name);
    if Items[i].Value <> Null then
      Node.Attributes['Value'] := Items[i].Value;
    Node.Attributes['Active'] := Items[i].Active;
  end;
end;

{ TProjectSettingList }

constructor TProjectSettingList.Create;
begin
  inherited Create;
  FItems := TObjectList.Create;
end;

destructor TProjectSettingList.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TProjectSettingList.Add: TProjectSetting;
begin
  Result := TProjectSetting.Create;
  FItems.Add(Result);
end;

procedure TProjectSettingList.Assign(Source: TPersistent);
var
  i: Integer;
begin
  if (Source is TProjectSettingList) or (Source = nil) then
  begin
    FItems.Clear;
    if Source <> nil then
      for i := 0 to TProjectSettingList(Source).Count - 1 do
        Add.Assign(TProjectSettingList(Source).Items[i]);
  end;
end;

procedure TProjectSettingList.Delete(Index: Integer);
begin
  FItems.Delete(Index);
end;

function TProjectSettingList.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TProjectSettingList.GetItem(Index: Integer): TProjectSetting;
begin
  Result := TProjectSetting(FItems[Index]);
end;

procedure TProjectSettingList.Clear;
begin
  FItems.Clear;
end;

function TProjectSettingList.IndexOf(Setting: TProjectSetting): Integer;
begin
  Result := FItems.IndexOf(Setting);
end;

class procedure TProjectSettingList.InitOptions;
begin
  with GlobalCompilerOptions do
  begin
    // Delphi
{    Add('Align');
    Add('BoolEval');
    Add('Assertions');
    Add('UnitDebugInfo');
    Add('ImportedData');
    Add('LongStrings');
    Add('IOChecks');
    Add('WriteableConst');
    Add('LocalSymbols');
    Add('TypeInfo');
    Add('Optimization');
    Add('OpenStrings');
    Add('OverflowChecks');
    Add('RangeChecks');
    Add('StackChecks');
    Add('TypedAddress');
    Add('SafeDivide');
    Add('VarStringChecks');
    Add('StackFrames');
    Add('ExtendedSyntax');
    Add('ReferenceInfo');
    Add('MinEnumSize');
    Add('OutputObj');
    Add('HintFlag');
    Add('WarnFlag');
    Add('UnitAliases');
    Add('Defines');
    Add('SysDefines');
    Add('NamespacePrefix');

    Add('WarnSymbolDeprecated');
    Add('WarnSymbolLibrary');
    Add('WarnSymbolPlatform');
    Add('WarnUnitLibrary');
    Add('WarnUnitPlatform');
    Add('WarnUnitDeprecated');
    Add('WarnHresultCompat');
    Add('WarnHidingMember');
    Add('WarnHiddenVirtual');
    Add('WarnGarbage');
    Add('WarnBoundsError');
    Add('WarnZeroNilCompat');
    Add('WarnStringConstTrunced');
    Add('WarnForLoopVarVarpar');
    Add('WarnTypedConstVarpar');
    Add('WarnAsgToTypedConst');
    Add('WarnCaseLabelRange');
    Add('WarnForVariable');
    Add('WarnConstructingAbstract');
    Add('WarnComparisonFalse');
    Add('WarnComparisonTrue');
    Add('WarnComparingSignedUnsigned');
    Add('WarnCombiningSignedUnsigned');
    Add('WarnUnsupportedConstruct');
    Add('WarnFileOpen');
    Add('WarnFileOpenUnitsrc');
    Add('WarnBadGlobalSymbol');
    Add('WarnDuplicateCtorDtor');
    Add('WarnInvalidDirective');
    Add('WarnPackageNoLink');
    Add('WarnPackagedThreadvar');
    Add('WarnImplicitImport');
    Add('WarnHppemitIgnored');
    Add('WarnNoRetval');
    Add('WarnUseBeforeDef');
    Add('WarnForLoopVarUndef');
    Add('WarnUnitNameMismatch');
    Add('WarnNoCfgFileFound');
    Add('WarnMessageDirective');
    Add('WarnImplicitVariants');
    Add('WarnUnicodeToLocale');
    Add('WarnLocaleToUnicode');
    Add('WarnImagebaseMultiple');
    Add('WarnSuspiciousTypecast');
    Add('WarnPrivatePropaccessor');
    Add('WarnUnsafeType');
    Add('WarnUnsafeCode');
    Add('WarnUnsafeCast');}

    AddObject('OutputDir', Pointer(1));
    AddObject('UnitOutputDir', Pointer(1));
    AddObject('UnitDir', Pointer(1));
    AddObject('ObjDir', Pointer(1));
    AddObject('SrcDir', Pointer(1));
    AddObject('ResDir', Pointer(1));
    AddObject('PkgDllDir', Pointer(1));
    AddObject('PkgDcpDir', Pointer(1));

    // C++
{    Add('CppDebugInfo');
    Add('LineNumbers');
    Add('AutoRegVars');
    Add('MergeDupStrs');
    Add('EnableInLines');
    Add('ShowWarnings');
    Add('StdStackFrame');
    Add('TreatEnumsAsInts');
    Add('PCH');
    Add('ShowInfoMsgs');
    Add('ShowExtendedMsgs');
    Add('InstructionSet');     
    Add('Alignment');
    Add('CallingConvention');
    Add('RegisterVars');
    Add('Ansi');
    Add('AutoDep');
    Add('Underscore');
    Add('PICCodeGen');
    Add('FastFloat');
    Add('PentiumFloat');
    Add('NestedComments');
    Add('MFCCompat');
    Add('IdentLen');
    Add('MemberPrecision');
    Add('ForLoops');
    Add('TwoChar');
    Add('CodeModifiers');
    Add('EnableRTTI');
    Add('EnableExceptions');
    Add('EHLocalInfo');
    Add('EHDtor');
    Add('EHPrologs');
    Add('ZeroBaseClass');
    Add('ZeroClassFunction');
    Add('ForceCppCompile');
    Add('MemberPointer');
    Add('VTables');
    Add('Templates');
    Add('PchPath');
    Add('PchStopAfter');
    Add('ATLMultiUse');
    Add('ATLDebugQI');
    Add('ATLCoinitMultiThreaded');
    Add('ATLAutoRegisterInproc');
    Add('ATLDebugRefCount');
    Add('ATLDebug');
    Add('ATLThreading');
    Add('CodeOpt');
    Add('FloatSupport');
    Add('TasmViaCppOpts');
    Add('TasmCrossReference');
    Add('TasmSymbolTables');
    Add('TasmGenerateListing');
    Add('TasmIncludeConditionals');
    Add('TasmIncludeErrors');
    Add('TasmExpanded');
    Add('TasmCaseCheckingOn');
    Add('TasmAllCase');
    Add('TasmDebugOn');
    Add('TasmFullDebug');
    Add('TasmWarningsOn');
    Add('TasmWarningsLevel1');
    Add('TasmHashTable');
    Add('TasmPasses');
    Add('TasmSymbolLength');
    Add('TasmDirective');
    Add('CGGlobalStackAccesses');
    Add('CGThisPointer');
    Add('CGInlinePointer');
    Add('CGLinkCGLib');}
  end;

  with GlobalLinkerOptions do
  begin
    AddObject('HostApplication', Pointer(1));
    AddObject('RunParams', Pointer(1));
    AddObject('Launcher', Pointer(1));
    AddObject('UseLauncher', Pointer(1));
    AddObject('DebugCWD', Pointer(1));
    AddObject('RemoteHost', Pointer(1));
    AddObject('RemotePath', Pointer(1));
    AddObject('RemoteLauncher', Pointer(1));
    AddObject('RemoteCWD', Pointer(1));
    AddObject('RemoteDebug', Pointer(1));

    // Delphi
{    Add('StackSize');
    Add('MaxStackSize');
    Add('MapFile');
    Add('DebugInfo');
    Add('RemoteSymbols');
    Add('ImageDebugInfo');
    Add('GenDRC');
    Add('GenDUI');
    Add('HeapSize');
    Add('MaxHeapSize');}

    AddObject('SOName', Pointer(1));
    AddObject('SOPrefix', Pointer(1));
    AddObject('SOPrefixDefined', Pointer(1));
    AddObject('SOSuffix', Pointer(1));
    AddObject('SOVersion', Pointer(1));
    AddObject('UsePackages', Pointer(1));
    AddObject('Packages', Pointer(1));
    AddObject('ExeDescription', Pointer(1));
    AddObject('ImplicitBuild', Pointer(1));
    AddObject('RuntimeOnly', Pointer(1));
    AddObject('DesigntimeOnly', Pointer(1));
    AddObject('DebugSourcePath', Pointer(1));

    AddObject('AutoIncBuildNum', Pointer(2));
    AddObject('Build', Pointer(2));
    AddObject('CodePage', Pointer(2));
    AddObject('IncludeVersionInfo', Pointer(2));
    AddObject('Locale', Pointer(2));
    AddObject('MajorVersion', Pointer(2));
    AddObject('MinorVersion', Pointer(2));
    AddObject('ModuleAttribs', Pointer(2));
    AddObject('Release', Pointer(2));

    // C++ ilink32
{    Add('LinkMaxErrors');
    Add('LinkShowMangle');
    Add('LinkGenImportLib');
    Add('LinkGenLib');
    Add('LinkNoStateFiles');
    Add('LinkSubsysMajor');
    Add('LinkSubsysMinor');
    Add('LinkCaseSensitiveLink');
    Add('LinkCalculateChecksum');
    Add('LinkFastTLS');
    Add('LinkReplaceResources');
    Add('LinkUserMajor');
    Add('LinkUserMinor');
    Add('LinkImageComment');
    Add('LinkDelayLoad');
    Add('ShowLinkerWarnings');
    Add('LinkDebugVcl');
    Add('UseDynamicRtl');
    Add('MultiThreaded');}

    AddObject('IncludePath', Pointer(1));
    AddObject('LibPath', Pointer(1));
    AddObject('DebugPath', Pointer(1));
    AddObject('ReleasePath', Pointer(1));
    AddObject('LibraryList', Pointer(1));

    // C++ tlib
{    Add('CaseSensitive');
    Add('ExtendedDictionary');
    Add('PurgeComment');
    Add('PageSize');}
    AddObject('ListFile', Pointer(1));
  end;
end;

class procedure TProjectSettingList.FillOptionNames(List: TStrings);
begin
  if not Assigned(GlobalCompilerOptions) then
  begin
    GlobalCompilerOptions := TStringList.Create;
    GlobalLinkerOptions := TStringList.Create;
    InitOptions;
  end;
  List.Clear;
  List.AddStrings(GlobalCompilerOptions);
  List.AddStrings(GlobalLinkerOptions);
end;

function TProjectSettingList.FindByName(const AName: string): TProjectSetting;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
  begin
    Result := Items[i];
    if AnsiCompareText(Result.Name, AName) = 0 then
      Exit;
  end;
  Result := nil;
end;

procedure TProjectSettingList.Remove(Setting: TProjectSetting);
begin
  FItems.Remove(Setting);
end;

function TProjectSettingList.FindEqual(Setting: TProjectSetting): TProjectSetting;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
  begin
    Result := Items[i];
    if Result.Compare(Setting) then
      Exit;
  end;
  Result := nil;
end;

procedure TProjectSettingList.LoadFromFile(const Filename: string);
begin
  LoadFromXml(LoadXmlDocument(Filename).Root);
end;

procedure TProjectSettingList.SaveToFile(const Filename: string);
var
  Doc: IXmlDocument;
begin
  Doc := NewXMLDocument;
  Doc.DocumentElement := Doc.CreateElement('ProjectSettings', '');
  SaveToXml(Doc.DocumentElement);

  ForceDirectories(ExtractFileDir(Filename));
  Doc.SaveToFile(Filename);
end;

procedure TProjectSettingList.LoadFromXml(Xml: IXmlNode);
var
  i: Integer;
begin
  Clear;
  for i := 0 to Xml.ChildNodes.Count - 1 do
    if AnsiCompareText(Xml.ChildNodes[i].NodeName, 'ProjectSetting') = 0 then
      Add.LoadFromXml(Xml.ChildNodes[i]);
end;

procedure TProjectSettingList.SaveToXml(Xml: IXmlNode);
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    Items[i].SaveToXml(Xml.AddChild('ProjectSetting'));
end;

function SortSettings(Item1, Item2: Pointer): Integer;
begin
  Result := AnsiCompareText(TProjectSetting(Item1).Name, TProjectSetting(Item2).Name);
end;

procedure TProjectSettingList.Sort;
begin
  FItems.Sort(SortSettings);
end;

end.
