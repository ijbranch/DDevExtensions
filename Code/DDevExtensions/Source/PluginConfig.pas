{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit PluginConfig;

/// <summary>
/// XML-backed persistent configuration framework for DDevExtensions plug-ins.
/// Each plug-in derives a class from <see cref="TPluginConfig"/> whose
/// published properties are streamed automatically (via RTTI) into the shared
/// <see cref="TConfiguration"/> document, which lives at
/// <c>%APPDATA%\DDevExtensions\DDevExtensions{IDEVersion}.xml</c>.
/// </summary>
/// <remarks>
/// Use <see cref="TConfiguration.BeginUpdate"/>/<see cref="TConfiguration.EndUpdate"/>
/// to batch many <see cref="TConfiguration.Modified"/> calls into a single
/// disk write.
/// </remarks>

{$I DelphiExtension.inc}

interface

uses
  Variants, SysUtils, Classes, SimpleXmlIntf, SimpleXmlImport, FrmTreePages, TypInfo;

type
  /// <summary>
  /// Base class for plug-in configuration objects. Streams its published
  /// properties to and from an XML node and registers any option pages with
  /// <see cref="TFormDDevExtOptions"/>.
  /// </summary>
  TPluginConfig = class(TComponent)
  private
    /// <summary>Legacy stand-alone XML filename (used during one-off migration into the shared document).</summary>
    FFilename: string;
    /// <summary>Name of the root XML node under which this plug-in's settings are stored.</summary>
    FRootNodeName: string;
    /// <summary>True while <see cref="LoadFromXml"/> is running so setters can suppress side effects.</summary>
    FLoading: Boolean;
    /// <summary>Loads from a stand-alone XML file on disk (legacy migration path).</summary>
    procedure LoadFromFile(const Filename: string);
  protected
    /// <summary>
    /// Override to return the option-page tree for this plug-in. The default
    /// returns nil (no options page).
    /// </summary>
    function GetOptionPages: TTreePage; virtual;
    /// <summary>Override to perform construction-time initialisation before settings are loaded.</summary>
    procedure Init; virtual;
    /// <summary>Registers the result of <see cref="GetOptionPages"/> with the options dialog.</summary>
    procedure RegisterOptionPages; virtual;

    /// <summary>True while <see cref="LoadFromXml"/> is running.</summary>
    property Loading: Boolean read FLoading;
  public
    /// <summary>
    /// Creates the configuration, loads existing settings (XML node or legacy
    /// file) and registers option pages.
    /// </summary>
    /// <param name="AFilename">Legacy stand-alone XML filename (used for one-off migration).</param>
    /// <param name="ARootNodeName">Name of the XML root node used for this plug-in's settings.</param>
    constructor Create(const AFilename, ARootNodeName: string); reintroduce;

    /// <summary>Streams every supported published property of <c>Self</c> into <paramref name="Node"/>.</summary>
    procedure SaveToXml(Node: IXmlNode); virtual;
    /// <summary>Loads every supported published property of <c>Self</c> from <paramref name="Node"/>.</summary>
    procedure LoadFromXml(Node: IXmlNode); virtual;

    /// <summary>Persists current settings into the shared <see cref="TConfiguration"/> document.</summary>
    procedure Save;

    /// <summary>Name of the XML root node used for this plug-in's settings.</summary>
    property RootNodeName: string read FRootNodeName;
  end;

  /// <summary>
  /// Singleton XML document holding the merged settings of every DDevExtensions
  /// plug-in. Loaded on first access via <see cref="Configuration"/>.
  /// </summary>
  TConfiguration = class(TObject)
  private
    /// <summary>True when in-memory state differs from disk; triggers a save on <see cref="EndUpdate"/>.</summary>
    FModified: Boolean;
    /// <summary>Path of the on-disk XML file.</summary>
    FFilename: string;
    /// <summary>Nesting counter for <see cref="BeginUpdate"/>/<see cref="EndUpdate"/>.</summary>
    FUpdateLock: Integer;
    /// <summary>The underlying XML document.</summary>
    FXml: IXmlDocument;
  public
    /// <summary>Creates an empty in-memory document with a <c>DDevExtensions</c> root element.</summary>
    constructor Create;
    /// <summary>Releases the document.</summary>
    destructor Destroy; override;

    /// <summary>Returns True if a child node with the given name exists under the document root.</summary>
    function HasNode(const NodeName: string): Boolean;
    /// <summary>Returns the named child node under the document root, or nil if it does not exist.</summary>
    function FindNode(const NodeName: string): IXmlNode;
    /// <summary>Returns the named child node under the document root, creating it if needed.</summary>
    function GetNode(const NodeName: string): IXmlNode; overload;
    /// <summary>Returns the named child node under <paramref name="ParentNode"/>, creating it if needed.</summary>
    class function GetNode(ParentNode: IXmlNode; const NodeName: string): IXmlNode; overload;
    /// <summary>Marks the document dirty; saves immediately if no <see cref="BeginUpdate"/> is active.</summary>
    procedure Modified;

    /// <summary>Saves the document to a specific path without changing <see cref="Filename"/>.</summary>
    procedure SaveToFile(const AFilename: string);
    /// <summary>Loads the document from a file (creates an empty document if the file does not exist).</summary>
    procedure LoadFromFile(const AFilename: string);
    /// <summary>Saves the document to <see cref="Filename"/>.</summary>
    procedure Save;

    /// <summary>Begins a batch update; pairs with <see cref="EndUpdate"/> to defer writes.</summary>
    procedure BeginUpdate;
    /// <summary>Ends a batch update; saves if any changes were marked while batched.</summary>
    procedure EndUpdate;

    /// <summary>Path of the on-disk XML file backing the document.</summary>
    property Filename: string read FFilename;
  end;

/// <summary>Lazily creates and returns the global configuration singleton.</summary>
function Configuration: TConfiguration;

implementation

uses
  FrmDDevExtOptions, IDEUtils, IDEHooks, Main;

var
  GlobalConfiguration: TConfiguration;

function Configuration: TConfiguration;
begin
  if GlobalConfiguration = nil then
  begin
    if AppDataDirectory = '' then
      InitAppDataDirectory;
    
    GlobalConfiguration := TConfiguration.Create;
    GlobalConfiguration.LoadFromFile(AppDataDirectory + '\DDevExtensions' + DelphiVersion + '.xml');
  end;
  Result := GlobalConfiguration;
end;


{ TPluginConfig }

constructor TPluginConfig.Create(const AFilename, ARootNodeName: string);
begin
  inherited Create(nil);
  FFilename := ChangeFileExt(AFilename, '') + DelphiVersion + ExtractFileExt(AFilename);
  FRootNodeName := ARootNodeName;

  Init;

  if Configuration.HasNode(RootNodeName) then
    LoadFromXml(Configuration.GetNode(RootNodeName))
  else
  if FileExists(FFilename) then
  try
    LoadFromFile(FFilename);
    Save; // save to Configuration
    DeleteFile(FFilename);
  except
  end;

  RegisterOptionPages;
end;

function TPluginConfig.GetOptionPages: TTreePage;
begin
  Result := nil;
end;

procedure TPluginConfig.Init;
begin
end;

procedure TPluginConfig.LoadFromFile(const Filename: string);
var
  Doc: IXmlDocument;
begin
  Doc := LoadXmlDocument(Filename);
  LoadFromXml(Doc.DocumentElement);
end;

procedure TPluginConfig.RegisterOptionPages;
begin
  TFormDDevExtOptions.RegisterPages(GetOptionPages);
end;

procedure TPluginConfig.Save;
begin
  Configuration.GetNode(FRootNodeName).ChildNodes.Clear;
  SaveToXml(Configuration.GetNode(FRootNodeName));
  Configuration.Modified;
end;

procedure TPluginConfig.SaveToXml(Node: IXmlNode);
var
  i: Integer;
  PropList: PPropList;
  Info: PPropInfo;
  Count: Integer;
  HasActive: Boolean;
  Obj: TObject;
  PropName: string;
begin
  HasActive := False;
  Info := GetPropInfo(Self, 'Active', tkProperties);
  if (Info <> nil) and (Info.PropType^.Kind = tkEnumeration) then
  begin
    Node.Attributes['Active'] := GetEnumProp(Self, Info);
    HasActive := True;
  end;

  Count := GetPropList(ClassInfo, PropList);
  try
    for i := 0 to Count - 1 do
    begin
      PropName := string(PropList[i].Name);
      if ((AnsiCompareText(PropName, 'Active') <> 0) or not HasActive) and
         (AnsiCompareText(PropName, 'Tag') <> 0) and
         (AnsiCompareText(PropName, 'Name') <> 0) then
      begin
        Node.ChildNodes.DeleteNodes(PropName);;
        case PropList[i].PropType^.Kind of
          tkInteger:
            TConfiguration.GetNode(Node, PropName).Attributes['Value'] := GetOrdProp(Self, PropList[i]);
          tkString, tkUString, tkLString:
            TConfiguration.GetNode(Node, PropName).NodeValue := GetStrProp(Self, PropList[i]);
          tkWString:
            TConfiguration.GetNode(Node, PropName).NodeValue := GetWideStrProp(Self, PropList[i]);
          tkVariant:
            TConfiguration.GetNode(Node, PropName).NodeValue := GetVariantProp(Self, PropList[i]);
          tkFloat:
            TConfiguration.GetNode(Node, PropName).Attributes['Value'] := GetFloatProp(Self, PropList[i]);
          tkEnumeration:
            TConfiguration.GetNode(Node, PropName).Attributes['Value'] := GetEnumProp(Self, PropList[i]);
          tkClass:
            begin
              Obj := GetObjectProp(Self, PropList[i]);
              if Obj is TStrings then
                TConfiguration.GetNode(Node, PropName).NodeValue := TStrings(Obj).CommaText;
            end;
        end;
      end;
    end;
  finally
    if Assigned(PropList) then
      FreeMem(PropList);
  end;
end;

procedure TPluginConfig.LoadFromXml(Node: IXmlNode);
var
  i: Integer;
  PropList: PPropList;
  Info: PPropInfo;
  Count: Integer;
  HasActive: Boolean;
  Xml, N: IXmlNode;
  Obj: TObject;
  PropName: string;
begin
  FLoading := True;
  try
    if Node <> nil then
    begin
      Info := GetPropInfo(Self, 'Active', tkProperties);
      HasActive := (Info <> nil) and (Info.PropType^.Kind = tkEnumeration) and (Node.Attributes['Active'] <> Null);

      Count := GetPropList(ClassInfo, PropList);
      try
        for i := 0 to Count - 1 do
        begin
          PropName := string(PropList[i].Name);
          if ((AnsiCompareText(PropName, 'Active') <> 0) or not HasActive) and
             (AnsiCompareText(PropName, 'Tag') <> 0) and
             (AnsiCompareText(PropName, 'Name') <> 0) then
          begin
            Xml := Node.ChildNodes.FindNode(PropName);
            if (Xml <> nil) and ((PropList[i].PropType^.Kind in [tkString, tkUString, tkLString, tkWString, tkVariant]) or (Xml.Attributes['Value'] <> Null)) then
            begin
              case PropList[i].PropType^.Kind of
                tkInteger:
                  SetOrdProp(Self, PropList[i], Xml.Attributes['Value']);
                tkString, tkLString, tkUString:
                  SetStrProp(Self, PropList[i], VarToStr(Xml.NodeValue));
                tkWString:
                  SetWideStrProp(Self, PropList[i], VarToWideStr(Xml.NodeValue));
                tkVariant:
                  SetVariantProp(Self, PropList[i], Xml.NodeValue);
                tkFloat:
                  SetFloatProp(Self, PropList[i], Xml.Attributes['Value']);
                tkEnumeration:
                  if VarToStr(Xml.Attributes['Value']) <> '' then
                  begin
                    try
                      SetEnumProp(Self, PropList[i], VarToStr(Xml.Attributes['Value']));
                    except
                      // ignore exception if the enumeration item doesn't exist (anymore)
                    end;
                  end;
                tkClass:
                  begin
                    Obj := GetObjectProp(Self, PropList[i]);
                    if Obj is TStrings then
                    begin
                      N := Node.ChildNodes.FindNode(PropName);
                      if N <> nil then
                        TStrings(Obj).CommaText := N.NodeValue;
                    end;
                  end;
              end;
            end;
          end;
        end;
        if HasActive and (VarToStr(Node.Attributes['Active']) <> '') then
          SetEnumProp(Self, Info, VarToStr(Node.Attributes['Active']));
      finally
        if Assigned(PropList) then
          FreeMem(PropList);
      end;
    end;
  finally
    FLoading := False;
    Loaded;
  end;
end;

{ TConfiguration }

constructor TConfiguration.Create;
begin
  inherited Create;
  FXml := NewXmlDocument;
  FXml.DocumentElement := FXml.CreateElement('DDevExtensions', '');
end;

destructor TConfiguration.Destroy;
begin
  FXml := nil;
  inherited Destroy;
end;

procedure TConfiguration.BeginUpdate;
begin
  Inc(FUpdateLock);
end;

procedure TConfiguration.EndUpdate;
begin
  Assert(FUpdateLock > 0, 'Unpaired call of EndUpdate');
  Dec(FUpdateLock);
  if (FUpdateLock = 0) and FModified then
    Save;
end;

function TConfiguration.GetNode(const NodeName: string): IXMLNode;
begin
  Result := GetNode(FXml.DocumentElement, NodeName);
end;

class function TConfiguration.GetNode(ParentNode: IXmlNode; const NodeName: string): IXmlNode;
begin
  Result := ParentNode.ChildNodes.FindNode(NodeName);
  if Result = nil then
    Result := ParentNode.AddChild(NodeName);
end;

function TConfiguration.HasNode(const NodeName: string): Boolean;
begin
  Result := FXml.DocumentElement.ChildNodes.FindNode(NodeName) <> nil;
end;

function TConfiguration.FindNode(const NodeName: string): IXmlNode;
begin
  Result := FXml.DocumentElement.ChildNodes.FindNode(NodeName);
end;

procedure TConfiguration.LoadFromFile(const AFilename: string);
begin
  FFilename := AFilename;
  try
    if FileExists(Filename) then
      FXml := LoadXmlDocument(AFilename)
    else
    begin
      FXml := NewXmlDocument;
      FXml.DocumentElement := FXml.CreateElement('DDevExtensions', '');
    end;
    FXml.Options := FXml.Options + [doNodeAutoIndent];
  except
    if Assigned(ApplicationHandleException) then
      ApplicationHandleException(Self);
  end;
  FModified := False;
end;

procedure TConfiguration.Modified;
begin
  FModified := True;
  if (Filename <> '') and (FUpdateLock = 0) then
    Save;
end;

procedure TConfiguration.Save;
begin
  Assert(Filename <> '');

  ForceDirectories(ExtractFileDir(Filename));
  FXml.SaveToFile(Filename);
  FModified := False;
end;

procedure TConfiguration.SaveToFile(const AFilename: string);
begin
  FXml.SaveToFile(AFilename);
end;

initialization

finalization
  FreeAndNil(GlobalConfiguration);

end.
