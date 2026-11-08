{******************************************************************************}
{*                                                                            *}
{* (C) 2005,2006 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit SimpleXmlDoc;

/// <summary>
/// Default implementation of the SimpleXmlIntf contract. Compiled either against the JEDI
/// SimpleXML library (when JEDI_XML is defined) or against Delphi's MSXML-backed XMLDoc unit;
/// callers see the same IXmlDocument interface either way. Provides LoadXmlDocument /
/// NewXmlDocument factory functions used by SimpleXmlImport.
/// </summary>

interface

uses
{$IFDEF JEDI_XML}
  JclSimpleXml, JclStreams,
{$ELSE}
  Xml.XMLIntf, Xml.XMLDoc, Xml.xmldom,
{$ENDIF JEDI_XML}
  SimpleXmlIntf,
  System.Classes;

type
{$IFDEF COMPILER5}
  /// <summary>Pre-Delphi-6 alias; later compilers ship IInterface directly.</summary>
  IInterface = IUnknown;
{$ENDIF COMPILER5}

  /// <summary>Concrete IXmlDocument implementation; reference-counted via the supplied _AddRef/_Release.</summary>
  TXmlDocument = class( TComponent, IInterface, IXmlDocument )
  private
{$IFDEF JEDI_XML}
    /// <summary>Underlying JEDI SimpleXML document.</summary>
    FXml: TJclSimpleXML;
    /// <summary>Whether the JEDI document is considered active.</summary>
    FActive: Boolean;
{$ELSE}
    /// <summary>Underlying MSXML document accessed via XMLIntf.</summary>
    FXml: Xml.XMLIntf.IXMLDocument;
{$ENDIF JEDI_XML}
    /// <summary>Manual reference count maintained by _AddRef / _Release.</summary>
    FRefCount: Integer;
  protected
    /// <summary>IInterface AddRef using a manual InterlockedIncrement on FRefCount.</summary>
    /// <returns>The new reference count.</returns>
    function _AddRef: Integer; stdcall;
    /// <summary>IInterface Release; frees the instance when FRefCount drops to zero.</summary>
    /// <returns>The new reference count; the instance is destroyed when it reaches 0 and the document has no owner.</returns>
    function _Release: Integer; stdcall;
  public
    /// <summary>Creates the wrapper and the underlying backend document.</summary>
    /// <param name="AOwner">Owner component; when set, reference counting never frees the document.</param>
    constructor Create( AOwner: TComponent ); override;
    /// <summary>Releases the underlying backend document.</summary>
    destructor Destroy; override;

    /// <summary>IXmlDocument: returns whether the backend document is active.</summary>
    /// <returns>True when the document is active.</returns>
    function GetActive: Boolean;
    /// <summary>IXmlDocument: activates or deactivates the backend document.</summary>
    /// <param name="Value">True to activate, False to deactivate.</param>
    procedure SetActive( Value: Boolean );
    /// <summary>IXmlDocument: returns the XML version string.</summary>
    /// <returns>The XML version string.</returns>
    function GetVersion: string;
    /// <summary>IXmlDocument: sets the XML version string.</summary>
    /// <param name="Value">New XML version string.</param>
    procedure SetVersion( const Value: string );
    /// <summary>IXmlDocument: returns the document element.</summary>
    /// <returns>A wrapper for the root element.</returns>
    function GetDocumentElement: IXmlNode;
    /// <summary>IXmlDocument: replaces the document element.</summary>
    /// <param name="Value">New root element; nil removes it.</param>
    procedure SetDocumentElement( Value: IXmlNode );
    /// <summary>IXmlDocument: returns the synthetic root node.</summary>
    /// <returns>A wrapper for the document element.</returns>
    function GetRoot: IXmlNode;
    /// <summary>IXmlDocument: returns the active document options.</summary>
    /// <returns>Always an empty set.</returns>
    function GetOptions: TXmlDocOptions;
    /// <summary>IXmlDocument: sets the active document options.</summary>
    /// <param name="Value">New document options.</param>
    procedure SetOptions( const Value: TXmlDocOptions );
    /// <summary>IXmlDocument: returns the document's child-node collection.</summary>
    /// <returns>The child nodes of the root element.</returns>
    function GetChildNodes: IXmlChildNodes;

    /// <summary>IXmlDocument: creates a new element with the supplied tag and namespace URI.</summary>
    /// <param name="Tag">Element name.</param>
    /// <param name="NamespaceURI">Namespace URI; may be empty.</param>
    /// <returns>The new, unattached element.</returns>
    function CreateElement( const Tag, NamespaceURI: string ): IXmlNode;
    /// <summary>IXmlDocument: not implemented; ignores its arguments and returns the root node.</summary>
    /// <param name="Name">Ignored.</param>
    /// <param name="NodeType">Ignored.</param>
    /// <param name="AddlData">Ignored.</param>
    /// <returns>The root node.</returns>
    function CreateNode( const Name: string; NodeType: TNodeType = ntElement;
      const AddlData: string = '' ): IXmlNode;

    /// <summary>
    /// Loads the document from Filename via the backend.  A JclSimpleXml-style declaration
    /// ( encoding before version ) is repaired in memory; the file itself is never modified.
    /// </summary>
    /// <param name="Filename">XML file to load.</param>
    /// <exception cref="EDOMParseError">Raised when the file is not well-formed XML (MSXML backend).</exception>
    procedure LoadFromFile( const Filename: string );
    /// <summary>
    /// Saves the document to Filename via the backend, writing a uniquely named sibling <c>.saving</c> file first
    /// and then replacing Filename with it, so the target is never left half-written.
    /// </summary>
    /// <param name="Filename">Destination file.</param>
    /// <exception cref="EInOutError">Raised when the finished file cannot replace Filename (for example, it is read-only).</exception>
    procedure SaveToFile( const Filename: string );

    /// <summary>Whether the document is parsed and ready for use.</summary>
    property Active: Boolean read GetActive write SetActive;
    /// <summary>Synthetic root node wrapping the document element.</summary>
    property Root: IXmlNode read GetRoot;
    /// <summary>Top-level document element.</summary>
    property DocumentElement: IXmlNode read GetDocumentElement write SetDocumentElement;
    /// <summary>XML version string.</summary>
    property Version: string read GetVersion write SetVersion;
    /// <summary>Document behaviour flags.</summary>
    property Options: TXmlDocOptions read GetOptions write SetOptions;
    /// <summary>Document child-node collection.</summary>
    property ChildNodes: IXmlChildNodes read GetChildNodes;
  end;

/// <summary>Loads an XML file from disk and returns it as an IXmlDocument.</summary>
/// <param name="Filename">XML file to load.</param>
/// <returns>The loaded, active document.</returns>
function LoadXmlDocument( const Filename: string ): IXmlDocument;
/// <summary>Creates an empty IXmlDocument with the supplied (optional) XML version string.</summary>
/// <param name="Version">XML version string; empty keeps the default.</param>
/// <returns>The new, active document.</returns>
function NewXmlDocument( const Version: string = '' ): IXmlDocument;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF MSWINDOWS}
{$IFDEF LINUX}
  Libc,
{$ENDIF LINUX}
  System.SysUtils, System.Contnrs, System.IOUtils;

{$IFDEF COMPILER5}
function InterlockedIncrement( var Addend: Integer ): Integer; stdcall;
  external 'kernel32.dll' name 'InterlockedIncrement';

function InterlockedDecrement( var Addend: Integer ): Integer; stdcall;
  external 'kernel32.dll' name 'InterlockedDecrement';
{$ENDIF COMPILER5}

{$IFDEF JEDI_XML}
type
  IInternalXmlNode = interface
    [ '{0757223F-94C9-4FE6-AB72-E8E88494195E}' ]
    function GetNode: TJclSimpleXMLElem;
  end;

  TXmlAttributes = class( TInterfacedObject, IXmlAttributes )
  private
    FNode: TJclSimpleXMLElem;
  public
    constructor Create( ANode: TJclSimpleXMLElem );

    procedure SetAttribute( const Index: string; const Value: Variant );
    function GetAttribute( const Index: string ): Variant;
    property Attributes[ const Index: string ]: Variant read GetAttribute write SetAttribute; default;
  end;

  TXmlChildNodes = class( TInterfacedObject, IXmlChildNodes )
  private
    FNodes: TJclSimpleXMLElems;
  public
    constructor Create( ANodes: TJclSimpleXMLElems );

    function GetCount: Integer;
    function GetNode( Index: Integer ): IXmlNode;
    function FindNode( const NodeName: string ): IXmlNode;

    procedure Add( Node: IXmlNode );
    procedure Clear;
    procedure DeleteNodes( const NodeName: string );

    property Count: Integer read GetCount;
    property Nodes[ Index: Integer ]: IXmlNode read GetNode; default;
  end;

  TXmlNode = class( TInterfacedObject, IXmlNode, IInternalXmlNode )
  private
    FChilds: IXmlChildNodes;
    FAttributes: IXmlAttributes;
    FNode: TJclSimpleXMLElem;
  protected
    function GetNode: TJclSimpleXMLElem;
  public
    constructor Create( ANode: TJclSimpleXMLElem );
    destructor Destroy; override;

    function GetNodeName: string;
    function GetNodeValue: Variant;
    function GetChildNodes: IXmlChildNodes;
    function GetAttributes: IXmlAttributes;
    function GetText: string;
    procedure SetText( const Value: string );
    //procedure SetNodeName(const Value: string);
    procedure SetNodeValue( const Value: Variant );

    function AddChild( const NodeName: string ): IXmlNode;

    property NodeName: string read GetNodeName {write SetNodeName};
    property NodeValue: Variant read GetNodeValue write SetNodeValue;
    property ChildNodes: IXmlChildNodes read GetChildNodes;
    property Attributes: IXmlAttributes read GetAttributes;
    property Text: string read GetText write SetText;
  end;

function LoadXmlDocument( const Filename: string ): IXmlDocument;
begin
  Result            := TXmlDocument.Create( nil );
  Result.LoadFromFile( Filename );
  Result.Active     := True;
end;

function NewXmlDocument( const Version: string ): IXmlDocument;
begin
  Result            := TXmlDocument.Create( nil );
  Result.Active     := True;
  if Version <> '' then
    Result.Version  := Version;
end;

{ TXmlDocument }

constructor TXmlDocument.Create( AOwner: TComponent );
begin
  inherited Create( AOwner );
  FXml              := TJclSimpleXML.Create;
  FXml.Prolog.Encoding := 'UTF-8';
end;

function TXmlDocument.CreateElement( const Tag, NamespaceURI: string ): IXmlNode;
var
  JvNode            : TJclSimpleXMLElemClassic;
begin
  JvNode            := TJclSimpleXMLElemClassic.Create( FXml.Root );
  JvNode.NameSpace  := NamespaceURI;
  JvNode.Name       := Tag;
  Result            := TXmlNode.Create( JvNode );
end;

function TXmlDocument.CreateNode( const Name: string; NodeType: TNodeType;
  const AddlData: string ): IXmlNode;
begin
  Result            := Root; // trick to ignore it
end;

destructor TXmlDocument.Destroy;
begin
  FXml.Free;
  inherited Destroy;
end;

function TXmlDocument.GetActive: Boolean;
begin
  Result            := FActive;
end;

function TXmlDocument.GetChildNodes: IXmlChildNodes;
begin
  Result            := Root.ChildNodes;
end;

function TXmlDocument.GetDocumentElement: IXMLNode;
begin
  Result            := Root;
end;

function TXmlDocument.GetOptions: TXmlDocOptions;
begin
  Result            := [ ];
end;

function TXmlDocument.GetRoot: IXmlNode;
begin
  Result            := TXmlNode.Create( FXml.Root );
end;

function TXmlDocument.GetVersion: string;
begin
  Result            := FXml.Prolog.Version;
end;

procedure TXmlDocument.LoadFromFile( const Filename: string );
begin
  FXml.LoadFromFile( Filename );
end;

procedure TXmlDocument.SaveToFile( const Filename: string );
begin
  FXml.SaveToFile( Filename, seUTF8 );
end;

procedure TXmlDocument.SetActive( Value: Boolean );
begin
  FActive           := Value;
end;

procedure TXmlDocument.SetDocumentElement( Value: IXMLNode );
begin
  if Value <> nil then
    FXml.Root       := ( Value as IInternalXmlNode ).GetNode as TJclSimpleXMLElemClassic
  else
    FXml.Root       := nil;
end;

procedure TXmlDocument.SetOptions( const Value: TXmlDocOptions );
begin
end;

procedure TXmlDocument.SetVersion( const Value: string );
begin
  FXml.Prolog.Version := Value;
end;

function TXmlDocument._AddRef: Integer;
begin
  Result            := InterlockedIncrement( FRefCount )
end;

function TXmlDocument._Release: Integer;
begin
  Result            := InterlockedDecrement( FRefCount );
  if ( Result = 0 ) and ( Owner = nil ) then
    Destroy;
end;

{ TXmlAttributes }

constructor TXmlAttributes.Create( ANode: TJclSimpleXMLElem );
begin
  inherited Create;
  FNode             := ANode;
end;

function TXmlAttributes.GetAttribute( const Index: string ): Variant;
var
  Prop              : TJclSimpleXMLProp;
begin
  Prop              := FNode.Properties.ItemNamed[ Index ];
  if Prop <> nil then
    Result          := Prop.Value
  else
    Result          := '';
end;

procedure TXmlAttributes.SetAttribute( const Index: string; const Value: Variant );
var
  Prop              : TJclSimpleXMLProp;
begin
  Prop              := FNode.Properties.ItemNamed[ Index ];
  if Prop = nil then
    Prop            := FNode.Properties.Add( Index, '' );
  Prop.Value        := Value
end;

{ TXmlNode }

constructor TXmlNode.Create( ANode: TJclSimpleXMLElem );
begin
  inherited Create;
  FNode             := ANode;
  FChilds           := TXmlChildNodes.Create( ANode.Items );
  FAttributes       := TXmlAttributes.Create( ANode );
end;

destructor TXmlNode.Destroy;
begin
  FAttributes       := nil;
  FChilds           := nil;
  inherited Destroy;
end;

function TXmlNode.AddChild( const NodeName: string ): IXmlNode;
begin
  Result            := TXmlNode.Create( FNode.Items.Add( NodeName ) );
end;

function TXmlNode.GetAttributes: IXmlAttributes;
begin
  Result            := FAttributes;
end;

function TXmlNode.GetChildNodes: IXmlChildNodes;
begin
  Result            := FChilds;
end;

function TXmlNode.GetNode: TJclSimpleXMLElem;
begin
  Result            := FNode;
end;

function TXmlNode.GetNodeName: string;
begin
  Result            := FNode.Name;
end;

function TXmlNode.GetNodeValue: Variant;
begin
  Result            := FNode.Value;
end;

function TXmlNode.GetText: string;
begin
  Result            := FNode.Value
end;

{procedure TXmlNode.SetNodeName(const Value: string);
begin
  FNode.Name := Value;
end;}

procedure TXmlNode.SetNodeValue( const Value: Variant );
begin
  FNode.Value       := Value;
end;

procedure TXmlNode.SetText( const Value: string );
begin
  FNode.Value       := Value;
end;

{ TXmlChildNodes }

procedure TXmlChildNodes.Add( Node: IXmlNode );
begin
  if Node <> nil then
    FNodes.Add( ( Node as IInternalXmlNode ).GetNode );
end;

constructor TXmlChildNodes.Create( ANodes: TJclSimpleXMLElems );
begin
  inherited Create;
  FNodes            := ANodes;
end;

procedure TXmlChildNodes.DeleteNodes( const NodeName: string );
var
  I                 : Integer;
begin
  for I := FNodes.Count - 1 downto 0 do
    if AnsiSameText( FNodes[ I ].Name, NodeName ) then
      FNodes.Delete( I );
end;

function TXmlChildNodes.GetCount: Integer;
begin
  Result            := FNodes.Count;
end;

function TXmlChildNodes.GetNode( Index: Integer ): IXmlNode;
begin
  Result            := TXmlNode.Create( FNodes[ Index ] );
end;

function TXmlChildNodes.FindNode( const NodeName: string ): IXmlNode;
var
  i                 : Integer;
begin
  for i := 0 to FNodes.Count - 1 do
    if CompareText( NodeName, FNodes[ i ].Name ) = 0 then
    begin
      Result        := Nodes[ i ];
      Exit;
    end;
  Result            := nil;
end;

procedure TXmlChildNodes.Clear;
begin
  FNodes.Clear;
end;

{$ELSE ~JEDI_XML}

type
  IInternalXmlNode = interface
    [ '{0757223F-94C9-4FE6-AB72-E8E88494195E}' ]
    function GetNode: Xml.XMLIntf.IXMLNode;
  end;

  TXmlAttributes = class( TInterfacedObject, IXmlAttributes )
  private
    FNode: Xml.XMLIntf.IXMLNode;
  public
    constructor Create( ANode: Xml.XMLIntf.IXMLNode );

    procedure SetAttribute( const Index: string; const Value: Variant );
    function GetAttribute( const Index: string ): Variant;
    property Attributes[ const Index: string ]: Variant read GetAttribute write SetAttribute; default;
  end;

  TXmlChildNodes = class( TInterfacedObject, IXmlChildNodes )
  private
    FNodes: Xml.XMLIntf.IXMLNodeList;
  public
    constructor Create( ANodes: Xml.XMLIntf.IXMLNodeList );

    function GetCount: Integer;
    function GetNode( Index: Integer ): IXmlNode;
    function FindNode( const NodeName: string ): IXmlNode;

    procedure Add( Node: IXmlNode );
    procedure Clear;
    procedure DeleteNodes( const NodeName: string );

    property Count: Integer read GetCount;
    property Nodes[ Index: Integer ]: IXmlNode read GetNode; default;
  end;

  TXmlNode = class( TInterfacedObject, IXmlNode, IInternalXmlNode )
  private
    FChilds: IXmlChildNodes;
    FAttributes: IXmlAttributes;
    FNode: Xml.XMLIntf.IXMLNode;
  protected
    function GetNode: Xml.XMLIntf.IXMLNode;
  public
    constructor Create( ANode: Xml.XMLIntf.IXMLNode );
    destructor Destroy; override;

    function GetNodeName: string;
    function GetNodeValue: Variant;
    function GetChildNodes: IXmlChildNodes;
    function GetAttributes: IXmlAttributes;
    function GetText: string;
    procedure SetText( const Value: string );
    //procedure SetNodeName(const Value: string);
    procedure SetNodeValue( const Value: Variant );

    function AddChild( const NodeName: string ): IXmlNode;

    property NodeName: string read GetNodeName {write SetNodeName};
    property NodeValue: Variant read GetNodeValue write SetNodeValue;
    property ChildNodes: IXmlChildNodes read GetChildNodes;
    property Attributes: IXmlAttributes read GetAttributes;
    property Text: string read GetText write SetText;
  end;

function LoadXmlDocument( const Filename: string ): IXmlDocument;
begin
  Result            := TXmlDocument.Create( nil );
  Result.LoadFromFile( Filename );
  Result.Active     := True;
end;

function NewXmlDocument( const Version: string ): IXmlDocument;
begin
  Result            := TXmlDocument.Create( nil );
  Result.Active     := True;
  if Version <> '' then
    Result.Version  := Version;
end;

{ TXmlDocument }

constructor TXmlDocument.Create( AOwner: TComponent );
begin
  inherited Create( AOwner );
  FXml              := Xml.XMLDoc.NewXMLDocument( );
  FXml.Encoding     := 'UTF-8';
end;

function TXmlDocument.CreateElement( const Tag, NamespaceURI: string ): IXmlNode;
begin
  Result            := TXmlNode.Create( FXml.CreateElement( Tag, NamespaceURI ) );
end;

function TXmlDocument.CreateNode( const Name: string; NodeType: TNodeType;
  const AddlData: string ): IXmlNode;
begin
  Result            := Root; // trick to ignore it
end;

destructor TXmlDocument.Destroy;
begin
  FXml              := nil;
  inherited Destroy;
end;

function TXmlDocument.GetActive: Boolean;
begin
  Result            := FXml.Active;
end;

function TXmlDocument.GetChildNodes: IXmlChildNodes;
begin
  Result            := Root.ChildNodes;
end;

function TXmlDocument.GetDocumentElement: IXMLNode;
begin
  Result            := Root;
end;

function TXmlDocument.GetOptions: TXmlDocOptions;
begin
  Result            := [ ];
end;

function TXmlDocument.GetRoot: IXmlNode;
begin
  Result            := TXmlNode.Create( FXml.DocumentElement );
end;

function TXmlDocument.GetVersion: string;
begin
  Result            := FXml.Version;
end;

/// <summary>
/// Repairs the XML declaration written by JclSimpleXml ( <c>&lt;?xml encoding="UTF-8" version="1.0"?&gt;</c> ),
/// which MSXML rejects because <c>version</c> must come first.
/// </summary>
/// <param name="AText">Whole document text.</param>
/// <param name="AFixed">Receives the text with the declaration replaced by a standard one.</param>
/// <returns>True when AText starts with an XML declaration whose first attribute is not
/// <c>version</c>, so AFixed differs from AText.</returns>
function RepairXmlDeclaration( const AText: string; out AFixed: string ): Boolean;
begin
  Result            := False;
  AFixed            := AText;
  var sTrimmed      := AText.TrimLeft;
  if not sTrimmed.StartsWith( '<?xml', True ) then
    Exit;
  var iEnd          := sTrimmed.IndexOf( '?>' );
  if ( iEnd < 0 ) then
    Exit;
  var sDeclaration  := sTrimmed.Substring( 0, iEnd + 2 );
  if sDeclaration.Substring( 5 ).TrimLeft.StartsWith( 'version', True ) then
    Exit; // a well-formed declaration: the parse error lies elsewhere
  AFixed            := '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' + sTrimmed.Substring( iEnd + 2 );
  Result            := True;
end;

procedure TXmlDocument.LoadFromFile( const Filename: string );
begin
  try
    FXml.LoadFromFile( Filename );
  except
    on EDOMParseError do
    begin
      // The JclSimpleXml writes '<?xml encoding="UTF-8" version="1.0" ...' but that isn't valid
      // XML, because it must be '<?xml version="1.0" encoding="UTF-8" ...' according to MSXML.
      // The repair is made in memory only: the file on disk is never rewritten while loading.
      var sFixed: string;
      if not RepairXmlDeclaration( TFile.ReadAllText( Filename, TEncoding.UTF8 ), sFixed ) then
        raise;
      FXml.LoadFromXML( sFixed );
    end;
  end;
end;

procedure TXmlDocument.SaveToFile( const Filename: string );
begin
  // Write a sibling file and swap it in, so a crash or a full disk mid-write cannot leave the
  // settings file truncated.
  // Unique per process and call: both IDEs ( 32- and 64-bit ) can save the same settings file.
  var sTempName     := Format( '%s.%d.%x.saving', [ Filename, GetCurrentProcessId, GetTickCount64 ] );
  try
    FXml.SaveToFile( sTempName );
  except
    System.SysUtils.DeleteFile( sTempName );
    raise;
  end;
  if not MoveFileEx( PChar( sTempName ), PChar( Filename ), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH ) then
  begin
    var iError      := GetLastError;
    System.SysUtils.DeleteFile( sTempName );
    raise EInOutError.CreateFmt( 'Cannot replace "%s": %s', [ Filename, SysErrorMessage( iError ) ] );
  end;
end;

procedure TXmlDocument.SetActive( Value: Boolean );
begin
  FXml.Active       := Value;
end;

procedure TXmlDocument.SetDocumentElement( Value: IXMLNode );
begin
  if Value <> nil then
    FXml.DocumentElement := ( Value as IInternalXmlNode ).GetNode
  else
    FXml.DocumentElement := nil;
end;

procedure TXmlDocument.SetOptions( const Value: TXmlDocOptions );
begin
  FXml.Options      := Xml.XMLIntf.TXMLDocOptions( Value );
end;

procedure TXmlDocument.SetVersion( const Value: string );
begin
  FXml.Version      := Value;
end;

function TXmlDocument._AddRef: Integer;
begin
  Result            := InterlockedIncrement( FRefCount )
end;

function TXmlDocument._Release: Integer;
begin
  Result            := InterlockedDecrement( FRefCount );
  if ( Result = 0 ) and ( Owner = nil ) then
    Destroy;
end;

{ TXmlAttributes }

constructor TXmlAttributes.Create( ANode: Xml.XMLIntf.IXmlNode );
begin
  inherited Create;
  FNode             := ANode;
end;

function TXmlAttributes.GetAttribute( const Index: string ): Variant;
begin
  if FNode.HasAttribute( Index ) then
    Result          := FNode.Attributes[ Index ]
  else
    Result          := '';
end;

procedure TXmlAttributes.SetAttribute( const Index: string; const Value: Variant );
begin
  FNode.Attributes[ Index ] := Value;
end;

{ TXmlNode }

constructor TXmlNode.Create( ANode: Xml.XMLIntf.IXmlNode );
begin
  inherited Create;
  FNode             := ANode;
  FChilds           := TXmlChildNodes.Create( ANode.ChildNodes );
  FAttributes       := TXmlAttributes.Create( ANode );
end;

destructor TXmlNode.Destroy;
begin
  FAttributes       := nil;
  FChilds           := nil;
  inherited Destroy;
end;

function TXmlNode.AddChild( const NodeName: string ): IXmlNode;
begin
  Result            := TXmlNode.Create( FNode.AddChild( NodeName ) );
end;

function TXmlNode.GetAttributes: IXmlAttributes;
begin
  Result            := FAttributes;
end;

function TXmlNode.GetChildNodes: IXmlChildNodes;
begin
  Result            := FChilds;
end;

function TXmlNode.GetNode: Xml.XMLIntf.IXmlNode;
begin
  Result            := FNode;
end;

function TXmlNode.GetNodeName: string;
begin
  Result            := FNode.NodeName;
end;

function TXmlNode.GetNodeValue: Variant;
begin
  Result            := FNode.NodeValue;
end;

function TXmlNode.GetText: string;
begin
  Result            := FNode.Text
end;

{procedure TXmlNode.SetNodeName(const Value: string);
begin
  FNode.NodeName := Value;
end;}

procedure TXmlNode.SetNodeValue( const Value: Variant );
begin
  FNode.NodeValue   := Value;
end;

procedure TXmlNode.SetText( const Value: string );
begin
  FNode.Text        := Value;
end;

{ TXmlChildNodes }

procedure TXmlChildNodes.Add( Node: IXmlNode );
begin
  if Node <> nil then
    FNodes.Add( ( Node as IInternalXmlNode ).GetNode );
end;

constructor TXmlChildNodes.Create( ANodes: Xml.XMLIntf.IXMLNodeList );
begin
  inherited Create;
  FNodes            := ANodes;
end;

procedure TXmlChildNodes.DeleteNodes( const NodeName: string );
var
  I                 : Integer;
begin
  for I := FNodes.Count - 1 downto 0 do
    if AnsiSameText( FNodes[ I ].NodeName, NodeName ) then
      FNodes.Delete( I );
end;

function TXmlChildNodes.GetCount: Integer;
begin
  Result            := FNodes.Count;
end;

function TXmlChildNodes.GetNode( Index: Integer ): IXmlNode;
begin
  Result            := TXmlNode.Create( FNodes[ Index ] );
end;

function TXmlChildNodes.FindNode( const NodeName: string ): IXmlNode;
var
  i                 : Integer;
begin
  for i := 0 to FNodes.Count - 1 do
    if CompareText( NodeName, FNodes[ i ].NodeName ) = 0 then
    begin
      Result        := Nodes[ i ];
      Exit;
    end;
  Result            := nil;
end;

procedure TXmlChildNodes.Clear;
begin
  FNodes.Clear;
end;

{$ENDIF JEDI_XML}

end.

