{******************************************************************************}
{*                                                                            *}
{* (C) 2005,2006 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}
{$A+,B-,C+,D+,E-,F-,G+,H+,I+,J-,K-,L+,M-,N-,O+,P+,Q-,R-,S-,T-,U-,V+,W-,X+,Y+,Z1}

unit SimpleXmlIntf;

/// <summary>
/// Compact XML interface contract used by SimpleXmlImport / SimpleXmlDoc. Provides a thin
/// IXmlDocument / IXmlNode / IXmlChildNodes / IXmlAttributes hierarchy modelled on Delphi's
/// XMLIntf so the same client code works against either MSXML or the JCL simple XML backend.
/// </summary>

interface

type
  /// <summary>DOM node-type discriminator (mirrors the W3C DOM enumeration).</summary>
  TNodeType = (ntReserved, ntElement, ntAttribute, ntText, ntCData,
    ntEntityRef, ntEntity, ntProcessingInstr, ntComment, ntDocument,
    ntDocType, ntDocFragment, ntNotation);

  /// <summary>Document-wide behavioural option for IXmlDocument implementations.</summary>
  TXmlDocOption = (doNodeAutoCreate, doNodeAutoIndent, doAttrNull,
    doAutoPrefix, doNamespaceDecl, doAutoSave);
  /// <summary>Set of TXmlDocOption flags.</summary>
  TXmlDocOptions = set of TXmlDocOption;

  /// <summary>Forward declaration of the node interface.</summary>
  IXmlNode = interface;

  /// <summary>Indexed collection of child nodes belonging to a parent IXmlNode.</summary>
  IXmlChildNodes = interface
    ['{AEC5C57C-75E1-4143-BFD6-5C91C48178D6}']
    /// <summary>Returns the number of child nodes.</summary>
    function GetCount: Integer;
    /// <summary>Returns the child at Index.</summary>
    function GetNode(Index: Integer): IXmlNode;
    /// <summary>Returns the first child whose NodeName matches NodeName, or nil.</summary>
    function FindNode(const NodeName: string): IXmlNode;

    /// <summary>Appends Node to the collection.</summary>
    procedure Add(Node: IXmlNode);
    /// <summary>Removes every child node.</summary>
    procedure Clear;
    /// <summary>Removes every child whose NodeName matches NodeName.</summary>
    procedure DeleteNodes(const NodeName: string);

    /// <summary>Number of child nodes.</summary>
    property Count: Integer read GetCount;
    /// <summary>Default indexed accessor for child nodes.</summary>
    property Nodes[Index: Integer]: IXmlNode read GetNode; default;
  end;

  /// <summary>Indexed accessor for the attribute dictionary on an IXmlNode.</summary>
  IXmlAttributes = interface
    ['{3EDE3B74-F849-4169-B245-28447BCF8AFB}']
    /// <summary>Sets the attribute value (stringified internally) for Index.</summary>
    procedure SetAttribute(const Index: string; const Value: Variant);
    /// <summary>Reads the attribute value for Index; returns Null when missing.</summary>
    function GetAttribute(const Index: string): Variant;
    /// <summary>Default indexed accessor by attribute name.</summary>
    property Attributes[const Index: string]: Variant read GetAttribute write SetAttribute; default;
  end;

  /// <summary>Compact XML node abstraction; carries its name, value, attributes and child nodes.</summary>
  IXmlNode = interface
    ['{550EAFEC-429D-4C37-8F7C-B552E2071D59}']
    /// <summary>Returns the element name.</summary>
    function GetNodeName: string;
    /// <summary>Returns the typed (Variant) node value.</summary>
    function GetNodeValue: Variant;
    /// <summary>Returns the child-node collection.</summary>
    function GetChildNodes: IXmlChildNodes;
    /// <summary>Returns the attribute collection.</summary>
    function GetAttributes: IXmlAttributes;
    /// <summary>Returns the inner text content.</summary>
    function GetText: string;
    /// <summary>Replaces the inner text content.</summary>
    procedure SetText(const Value: string);
    //procedure SetNodeName(const Value: string);
    /// <summary>Stores Value as the typed (Variant) node value.</summary>
    procedure SetNodeValue(const Value: Variant);

    /// <summary>Creates and appends a child element with the given name.</summary>
    /// <returns>The newly created child node.</returns>
    function AddChild(const NodeName: string): IXmlNode;

    /// <summary>Element name.</summary>
    property NodeName: string read GetNodeName {write SetNodeName};
    /// <summary>Typed (Variant) node value.</summary>
    property NodeValue: Variant read GetNodeValue write SetNodeValue;
    /// <summary>Inner text content.</summary>
    property Text: string read GetText write SetText;
    /// <summary>Child-node collection.</summary>
    property ChildNodes: IXmlChildNodes read GetChildNodes;
    /// <summary>Attribute collection.</summary>
    property Attributes: IXmlAttributes read GetAttributes;
  end;

  /// <summary>Top-level XML document supporting load, save, element creation and document-level options.</summary>
  IXmlDocument = interface
    ['{6C02535D-924E-48A9-83C3-5A79897A54B5}']
    /// <summary>Returns whether the document is currently parsed/active.</summary>
    function GetActive: Boolean;
    /// <summary>Activates or deactivates the document.</summary>
    procedure SetActive(Value: Boolean);
    /// <summary>Returns the XML version string from the prolog.</summary>
    function GetVersion: string;
    /// <summary>Sets the XML version string in the prolog.</summary>
    procedure SetVersion(const Value: string);
    /// <summary>Returns the root element.</summary>
    function GetDocumentElement: IXMLNode;
    /// <summary>Replaces the root element.</summary>
    procedure SetDocumentElement(Value: IXMLNode);
    /// <summary>Returns the synthetic root node that wraps the document element.</summary>
    function GetRoot: IXmlNode;
    /// <summary>Returns the active document options.</summary>
    function GetOptions: TXmlDocOptions;
    /// <summary>Sets the active document options.</summary>
    procedure SetOptions(const Value: TXmlDocOptions);
    /// <summary>Returns the document's child-node collection.</summary>
    function GetChildNodes: IXmlChildNodes;

    /// <summary>Creates a new element with the supplied tag and namespace URI.</summary>
    function CreateElement(const Tag, NamespaceURI: string): IXmlNode;
    /// <summary>Creates a new node of the requested type, with optional additional data (such as comment text).</summary>
    function CreateNode(const Name: string; NodeType: TNodeType = ntElement;
      const AddlData: string = ''): IXmlNode;

    /// <summary>Loads the document from Filename.</summary>
    procedure LoadFromFile(const Filename: string);
    /// <summary>Saves the document to Filename.</summary>
    procedure SaveToFile(const Filename: string);

    /// <summary>Whether the document is parsed and ready for use.</summary>
    property Active: Boolean read GetActive write SetActive;
    /// <summary>Synthetic root node wrapping the document element.</summary>
    property Root: IXmlNode read GetRoot;
    /// <summary>Document element (the top-level XML element).</summary>
    property DocumentElement: IXMLNode read GetDocumentElement write SetDocumentElement;
    /// <summary>XML version string.</summary>
    property Version: string read GetVersion write SetVersion;
    /// <summary>Document behaviour flags.</summary>
    property Options: TXmlDocOptions read GetOptions write SetOptions;
    /// <summary>Child-node collection of the document.</summary>
    property ChildNodes: IXmlChildNodes read GetChildNodes;
  end;

implementation

end.
