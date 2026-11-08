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
  System.Variants, System.SysUtils, System.Classes, SimpleXmlIntf, SimpleXmlImport, FrmTreePages, System.TypInfo,
  PluginConfigCore;

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
    /// <param name="Filename">Path of the legacy XML file; its document element is passed to <see cref="LoadFromXml"/>.</param>
    procedure LoadFromFile(const Filename: string);
  protected
    /// <summary>
    /// Override to return the option-page tree for this plug-in. The default
    /// returns nil (no options page).
    /// </summary>
    /// <returns>The root page of this plug-in's option-page tree, or nil.</returns>
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
    /// <summary>Withdraws this configuration's option pages, so the Options dialog never calls into a freed object.</summary>
    destructor Destroy; override;

    /// <summary>Streams every supported published property of <c>Self</c> into <paramref name="Node"/>.</summary>
    /// <param name="Node">The XML node that receives this plug-in's settings.</param>
    procedure SaveToXml(Node: IXmlNode); virtual;
    /// <summary>Loads every supported published property of <c>Self</c> from <paramref name="Node"/>.</summary>
    /// <param name="Node">The XML node holding this plug-in's settings.</param>
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
    /// <summary>
    /// True when the settings file could not be read and could not be moved aside either: saving would then
    /// overwrite the user's only copy, so <see cref="Save"/> does nothing for the rest of the session.
    /// </summary>
    FSaveBlocked: Boolean;
    /// <summary>Starts a new, empty document with a <c>DDevExtensions</c> root element.</summary>
    procedure NewDocument;
    /// <summary>
    /// Handles a settings file that failed to load.  A damaged file (opened, but would not parse) is moved aside;
    /// a file that could not be opened is left alone and saving is blocked for the session.  Warns once.
    /// </summary>
    /// <param name="Outcome">Why the load failed: <c>sloUnreadable</c> or <c>sloLocked</c>.</param>
    /// <param name="Reason">The last load error, for the warning.</param>
    procedure HandleLoadFailure(Outcome: TSettingsLoadOutcome; const Reason: string);
  public
    /// <summary>Creates an empty in-memory document with a <c>DDevExtensions</c> root element.</summary>
    constructor Create;
    /// <summary>Releases the document.</summary>
    destructor Destroy; override;

    /// <summary>Returns True if a child node with the given name exists under the document root.</summary>
    /// <param name="NodeName">Name of the child element to look for.</param>
    /// <returns>True when the document root has a child element of that name.</returns>
    function HasNode(const NodeName: string): Boolean;
    /// <summary>Returns the named child node under the document root, or nil if it does not exist.</summary>
    /// <param name="NodeName">Name of the child element to look for.</param>
    /// <returns>The child node, or nil when it does not exist.</returns>
    function FindNode(const NodeName: string): IXmlNode;
    /// <summary>Returns the named child node under the document root, creating it if needed.</summary>
    /// <param name="NodeName">Name of the child element to find or add.</param>
    /// <returns>The existing or newly added child node.</returns>
    function GetNode(const NodeName: string): IXmlNode; overload;
    /// <summary>Returns the named child node under <paramref name="ParentNode"/>, creating it if needed.</summary>
    /// <param name="ParentNode">Node to search under and add to.</param>
    /// <param name="NodeName">Name of the child element to find or add.</param>
    /// <returns>The existing or newly added child node.</returns>
    class function GetNode(ParentNode: IXmlNode; const NodeName: string): IXmlNode; overload;
    /// <summary>Marks the document dirty; saves immediately if no <see cref="BeginUpdate"/> is active.</summary>
    procedure Modified;

    /// <summary>Saves the document to a specific path without changing <see cref="Filename"/>.</summary>
    /// <param name="AFilename">Path of the file to write.</param>
    procedure SaveToFile(const AFilename: string);
    /// <summary>Loads the document from a file (creates an empty document if the file does not exist).</summary>
    /// <exception cref="EInOutError">Raised and handled internally to classify a document with no root element; it never reaches the caller.</exception>
    /// <param name="AFilename">The settings file to load.</param>
    procedure LoadFromFile(const AFilename: string);
    /// <summary>
    /// Saves the document to <see cref="Filename"/> through a temporary file that then replaces it in one step,
    /// so a crash mid-save cannot truncate the settings.  Does nothing while saving is blocked after a failed load.
    /// </summary>
    /// <exception cref="EInOutError">The finished temporary file could not replace the settings file.</exception>
    procedure Save;

    /// <summary>Begins a batch update; pairs with <see cref="EndUpdate"/> to defer writes.</summary>
    procedure BeginUpdate;
    /// <summary>Ends a batch update; saves if any changes were marked while batched.</summary>
    procedure EndUpdate;

    /// <summary>Path of the on-disk XML file backing the document.</summary>
    property Filename: string read FFilename;
  end;

/// <summary>Lazily creates and returns the global configuration singleton.</summary>
/// <returns>The shared <see cref="TConfiguration"/> instance, created on first call.</returns>
function Configuration: TConfiguration;

implementation

uses
  Winapi.Windows, FrmDDevExtOptions, IDEUtils, IDEHooks, Main;

const
  /// <summary>How many times <see cref="TConfiguration.LoadFromFile"/> tries to open and parse the settings file.</summary>
  SettingsLoadAttempts = 4;
  /// <summary>Pause between those attempts; 3 pauses of 150 ms keep the total under a second.</summary>
  SettingsLoadRetryDelayMs = 150;

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
    System.SysUtils.DeleteFile(FFilename);
  except
    on E: Exception do
      // Do not swallow silently: a corrupt legacy file leaves migration half-done
      // and the stale file undeleted on every start, so record why.
      OutputDebugString(PChar('PluginConfig: legacy settings migration failed for ' +
        FFilename + ' - ' + E.ClassName + ': ' + E.Message));
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

destructor TPluginConfig.Destroy;
begin
  TFormDDevExtOptions.UnregisterPages( GetOptionPages );
  inherited Destroy;
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
            // The XML wrapper returns '' for a missing attribute, so test for a real value: an integer or float
            // property given '' raised EVariantTypeCastError and took the whole feature down with it
            if (Xml <> nil) and ((PropList[i].PropType^.Kind in [tkString, tkUString, tkLString, tkWString, tkVariant, tkClass]) or
               XmlValuePresent(Xml.Attributes['Value'])) then
            try
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
                        TStrings(Obj).CommaText := VarToStr(N.NodeValue); // an empty list's node has a Null value
                    end;
                  end;
              end;
            except
              on E: EVariantError do
                // Keep the default for this one property; the others still load
                OutputDebugString(PChar('PluginConfig: ' + RootNodeName + '.' + PropName + ' ignored - ' + E.Message));
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
  NewDocument;
end;

procedure TConfiguration.NewDocument;
begin
  FXml := NewXmlDocument;
  FXml.DocumentElement := FXml.CreateElement('DDevExtensions', '');
end;

procedure TConfiguration.HandleLoadFailure(Outcome: TSettingsLoadOutcome; const Reason: string);
begin
  // Start from defaults, but never let the next save overwrite the file: it is the user's only copy of every
  // feature's settings
  NewDocument;
  var Text := Format( 'DDevExtensions could not read its settings file:' + sLineBreak + '%s' + sLineBreak + sLineBreak +
    '%s' + sLineBreak + sLineBreak, [ Filename, Reason ] );
  var Moved: string;
  if ( Outcome = sloUnreadable ) and QuarantineFile( Filename, Now, Moved ) then
    // Damaged content: move it aside, so a fresh file can be written and the old one recovered by hand
    Text := Text + 'The file has been moved to:' + sLineBreak + Moved + sLineBreak + sLineBreak +
      'Default settings are in use; a new settings file will be written when an option is changed.'
  else
  begin
    // Could not be opened ( another IDE may hold it ), or could not be moved: its content may be good, so leave
    // it exactly where it is and save nothing this session
    FSaveBlocked := True;
    Text := Text + 'The file has been left as it is, and settings will not be saved this session.  Default ' +
      'settings are in use; restart the IDE to try again.';
  end;
  OutputDebugString( PChar( Text ) );
  MessageBox( 0, PChar( Text ), 'DDevExtensions', MB_OK or MB_ICONWARNING or MB_TASKMODAL );
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
  FSaveBlocked := False;
  if FileExists(Filename) then
  begin
    // A few short retries ( under a second in all ): the other-bitness IDE may be saving the file right now
    var Reason: string;
    var Outcome := LoadSettingsWithRetry( Filename,
      procedure(Name: string)
      begin
        FXml := LoadXmlDocument( Name );
        if FXml.DocumentElement = nil then
          raise EInOutError.Create( 'The file has no root element' );
      end, SettingsLoadAttempts, SettingsLoadRetryDelayMs, Reason );
    if Outcome <> sloLoaded then
      HandleLoadFailure( Outcome, Reason );
  end
  else
    NewDocument;
  FXml.Options := FXml.Options + [doNodeAutoIndent];
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
  if FSaveBlocked then
    Exit;

  ForceDirectories(ExtractFileDir(Filename));
  var TempName := TempFileNameFor( Filename );
  try
    FXml.SaveToFile( TempName );
  except
    System.SysUtils.DeleteFile( TempName );
    raise;
  end;
  ReplaceFileAtomically( TempName, Filename );
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
