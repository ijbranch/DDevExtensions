{******************************************************************************}
{*                                                                            *}
{* DelphiDfmParser - Lossless DFM Text Parser                                *}
{*                                                                            *}
{* Purpose: Parse and serialise Delphi .dfm files with exact fidelity        *}
{* Design goal: Parse(text) then Serialize() = identical text                *}
{*                                                                            *}
{* Part of DDevExtensions                                                     *}
{* https://github.com/MasterpieceDeveloper/DDevExtensions                     *}
{*                                                                            *}
{******************************************************************************}

unit gllDelphiDFMParser;

/// <summary>
/// Lossless DFM (Delphi Form Module) text parser and serialiser. The contract is that
/// Serialize(Parse(Text)) produces the original text byte-for-byte: indentation, line endings
/// and the exact value strings are preserved so the parser can be used by tooling that round-
/// trips DFM files without disturbing unrelated formatting.  The contract holds for text as the
/// IDE writes it ( 324 of 324 real files, 2026-11-28 ); hand-made spacing around "=" or before
/// an inherited component's "[n]", blank lines, and a missing final line break are normalised.
/// </summary>

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  /// <summary>DFM property value types</summary>
  TDfmValueKind = (
    dvkSimple, // Name = Value
    dvkString, // Name = 'string'
    dvkMultiLine, // Name = 'line1' + #13#10 + 'line2'
    dvkSet, // Name = [item1, item2]
    dvkBinary, // Name = { hex bytes }
    dvkCollection, // Name = < ... >
    dvkParenList // Name = ( item1 item2 )
    );

  /// <summary>Represents a single property in a DFM component.</summary>
  TDfmProperty = class
  private
    /// <summary>Property name (left of "=").</summary>
    FName: string;
    /// <summary>Discriminator describing how the value is formatted in the DFM.</summary>
    FValueKind: TDfmValueKind;
    /// <summary>Exact text of the value after "=" so round-tripping preserves formatting.</summary>
    FRawValue: string;
    /// <summary>Leading whitespace before the property name.</summary>
    FIndent: string;
    /// <summary>Whether a space follows the "=" ( False for a bare <c>Name =</c> whose value starts on the next line ).</summary>
    FSpaceAfterEquals: Boolean;
  public
    /// <summary>Creates a property written as <c>Name = Value</c> ( a space after the "=" ).</summary>
    constructor Create;
    /// <summary>Property name</summary>
    property Name: string read FName write FName;
    /// <summary>Type of property value</summary>
    property ValueKind: TDfmValueKind read FValueKind write FValueKind;
    /// <summary>Raw text of the value after '=' preserving exact formatting</summary>
    property RawValue: string read FRawValue write FRawValue;
    /// <summary>Leading whitespace before the property name</summary>
    property Indent: string read FIndent write FIndent;
    /// <summary>
    /// Whether a space follows the "=".  The IDE writes a bare <c>Name =</c> when a long value
    /// starts on the next line; serialising keeps that line byte-exact.  True by default.
    /// </summary>
    property SpaceAfterEquals: Boolean read FSpaceAfterEquals write FSpaceAfterEquals;
  end;

  /// <summary>DFM object declaration types</summary>
  TDfmObjectKind = ( dokObject, dokInherited, dokInline );

  /// <summary>Represents a component (object) in a DFM file: type, name, properties and child components.</summary>
  TDfmComponent = class
  private
    /// <summary>Component name (right of object/inherited/inline keyword, left of ":").</summary>
    FName: string;
    /// <summary>Component class name (right of ":").</summary>
    FTypeName: string;
    /// <summary>Which keyword introduced this component (object/inherited/inline).</summary>
    FObjectKind: TDfmObjectKind;
    /// <summary>Creation-order index of an inherited component ( the <c>[n]</c> after the class name ), without brackets.</summary>
    FOrderIndex: string;
    /// <summary>Owned list of properties belonging to this component.</summary>
    FProperties: TObjectList<TDfmProperty>;
    /// <summary>Owned list of child components.</summary>
    FChildren: TObjectList<TDfmComponent>;
    /// <summary>Leading whitespace before the object/inherited/inline keyword.</summary>
    FIndent: string;
    /// <summary>Leading whitespace before the matching "end" keyword.</summary>
    FEndIndent: string;
  public
    /// <summary>Initialises empty property and child lists; the default ObjectKind is dokObject.</summary>
    constructor Create;
    /// <summary>Frees the property and child lists (and their entries).</summary>
    destructor Destroy; override;

    /// <summary>Finds a property of this component by name ( case-insensitive ).</summary>
    /// <param name="PropName">Name of the property to find.</param>
    /// <returns>The matching property, or nil when the component has none of that name.</returns>
    function FindProperty( const PropName: string ): TDfmProperty;
    /// <summary>Finds a direct child component by name ( case-insensitive ).</summary>
    /// <param name="ChildName">Name of the child component to find.</param>
    /// <returns>The matching child component, or nil when there is none of that name.</returns>
    function FindChild( const ChildName: string ): TDfmComponent;
    /// <summary>Removes and frees a property by name; does nothing when the property is absent.</summary>
    /// <param name="PropName">Name of the property to delete ( case-insensitive ).</param>
    procedure DeleteProperty( const PropName: string );
    /// <summary>Sets the raw value of a property, adding it as a simple property ( two-space indent ) when it does not exist.</summary>
    /// <param name="PropName">Name of the property to set ( matched case-insensitively ).</param>
    /// <param name="Value">Raw DFM text of the value, written after the '=' as is.</param>
    procedure SetProperty( const PropName, Value: string );

    /// <summary>Component name (e.g. 'Button1')</summary>
    property Name: string read FName write FName;
    /// <summary>Component type (e.g. 'TButton')</summary>
    property TypeName: string read FTypeName write FTypeName;
    /// <summary>Object declaration keyword used</summary>
    property ObjectKind: TDfmObjectKind read FObjectKind write FObjectKind;
    /// <summary>
    /// Creation-order index written after the class name of an inherited component ( <c>3</c> for
    /// <c>inherited Panel1: TPanel [3]</c> ), without brackets; empty when the header has none.
    /// </summary>
    property OrderIndex: string read FOrderIndex write FOrderIndex;
    /// <summary>Properties of this component</summary>
    property Properties: TObjectList<TDfmProperty> read FProperties;
    /// <summary>Child components (nested objects)</summary>
    property Children: TObjectList<TDfmComponent> read FChildren;
    /// <summary>Leading whitespace of 'object' line</summary>
    property Indent: string read FIndent write FIndent;
    /// <summary>Leading whitespace of 'end' line</summary>
    property EndIndent: string read FEndIndent write FEndIndent;
  end;

  /// <summary>Represents a complete DFM document: a root component plus optional surrounding text.</summary>
  TDfmDocument = class
  private
    /// <summary>Root component (typically the form, frame or data module).</summary>
    FRoot: TDfmComponent;
    /// <summary>Detected line ending sequence (CRLF or LF) used during serialisation.</summary>
    FLineEnding: string;
    /// <summary>Free-form text preceding the root object declaration.</summary>
    FHeader: string;
    /// <summary>Free-form text following the final end.</summary>
    FTrailer: string;
  public
    /// <summary>Initialises a fresh document with an empty root component and CRLF line endings.</summary>
    constructor Create;
    /// <summary>Frees the root component.</summary>
    destructor Destroy; override;

    /// <summary>Root component (the form/frame/datamodule)</summary>
    property Root: TDfmComponent read FRoot;
    /// <summary>Detected line ending style (CRLF or LF)</summary>
    property LineEnding: string read FLineEnding;
    /// <summary>Any text before the first object declaration</summary>
    property Header: string read FHeader write FHeader;
    /// <summary>Any text after the final end</summary>
    property Trailer: string read FTrailer write FTrailer;
  end;

  /// <summary>DFM parser and serialiser</summary>
  TDelphiDfmParser = class
  public
    /// <summary>Parses text-format DFM into a document structure, keeping indentation and line endings for round-tripping.</summary>
    /// <param name="DfmText">The text DFM content to parse.</param>
    /// <returns>A new document owned by the caller, who must free it.</returns>
    class function Parse( const DfmText: string ): TDfmDocument;
    /// <summary>Serialises a document structure back to text DFM, using the document's line ending.</summary>
    /// <param name="Doc">The document to serialise.</param>
    /// <returns>The DFM text.</returns>
    class function Serialize( Doc: TDfmDocument ): string;
  end;

implementation

type
  /// <summary>
  /// Decides where a property value ends: counts brackets ( <c>( [ &lt; {</c> and their partners )
  /// only OUTSIDE string literals, so a bracket inside a caption or SQL text cannot open or close
  /// a list.  A DFM string never spans lines, and a doubled quote inside one simply toggles twice.
  /// </summary>
  /// <remarks>The idea is that of <c>TValueScanner</c> in Cesar Romero's MIT-licensed delphi-dfm-noise-filter ( <c>DfmText.pas</c> ).</remarks>
  TDfmValueScanner = record
    /// <summary>Open brackets not yet closed.</summary>
    Depth: Integer;
    /// <summary>True between an opening quote and its closing quote; always False after <c>Scan</c> returns.</summary>
    InString: Boolean;
    /// <summary>True once any value text other than spaces and <c>+</c> has been seen.</summary>
    HasValue: Boolean;
    /// <summary>True when the last non-blank character scanned was a <c>+</c> outside a string.</summary>
    EndsWithPlus: Boolean;
    /// <summary>Clears the scanner for a new property.</summary>
    procedure Init;
    /// <summary>Scans one line, or the value part of the property's first line.</summary>
    /// <param name="S">The line text.</param>
    /// <param name="StartIndex">1-based index of the first character to scan.</param>
    procedure Scan( const S: string; StartIndex: Integer );
    /// <summary>Whether the value scanned so far is complete.</summary>
    /// <returns>True when a value was seen, every bracket is closed and the last line did not end with <c>+</c>.</returns>
    function Complete: Boolean;
  end;

procedure TDfmValueScanner.Init;
begin
  Depth             := 0;
  InString          := False;
  HasValue          := False;
  EndsWithPlus      := False;
end;

procedure TDfmValueScanner.Scan( const S: string; StartIndex: Integer );
begin
  EndsWithPlus      := False;
  for var I := StartIndex to Length( S ) do
  begin
    var C           := S[ I ];
    if InString then
    begin
      if C = '''' then InString := False;
      Continue;
    end;
    case C of
      '''':
        begin
          InString  := True;
          HasValue  := True;
          EndsWithPlus := False;
        end;
      '(', '[', '<', '{':
        begin
          Inc( Depth );
          HasValue  := True;
          EndsWithPlus := False;
        end;
      ')', ']', '>', '}':
        begin
          Dec( Depth );
          HasValue  := True; // a stray closer on a malformed line still ends the value
          EndsWithPlus := False;
        end;
      '+': EndsWithPlus := True;
      ' ', #9: ;
    else
      HasValue      := True;
      EndsWithPlus  := False;
    end;
  end;
  // A DFM string never spans lines: an unterminated quote is malformed text, and closing it here
  // keeps one bad line from swallowing the rest of the file.
  InString          := False;
end;

function TDfmValueScanner.Complete: Boolean;
begin
  Result            := HasValue and ( Depth <= 0 ) and ( not EndsWithPlus );
end;

{ TDfmProperty }

constructor TDfmProperty.Create;
begin
  inherited Create;
  FSpaceAfterEquals := True;
end;

{ TDfmComponent }

constructor TDfmComponent.Create;
begin
  inherited;
  FProperties       := TObjectList<TDfmProperty>.Create( True );
  FChildren         := TObjectList<TDfmComponent>.Create( True );
  FObjectKind       := dokObject;
end;

destructor TDfmComponent.Destroy;
begin
  FProperties.Free;
  FChildren.Free;
  inherited;
end;

function TDfmComponent.FindProperty( const PropName: string ): TDfmProperty;
var
  Prop              : TDfmProperty;
begin
  for Prop in FProperties do
    if SameText( Prop.Name, PropName ) then
      Exit( Prop );
  Result            := nil;
end;

function TDfmComponent.FindChild( const ChildName: string ): TDfmComponent;
var
  Child             : TDfmComponent;
begin
  for Child in FChildren do
    if SameText( Child.Name, ChildName ) then
      Exit( Child );
  Result            := nil;
end;

procedure TDfmComponent.DeleteProperty( const PropName: string );
var
  Prop              : TDfmProperty;
begin
  Prop              := FindProperty( PropName );
  if Prop <> nil then
    FProperties.Remove( Prop );
end;

procedure TDfmComponent.SetProperty( const PropName, Value: string );
var
  Prop              : TDfmProperty;
begin
  Prop              := FindProperty( PropName );
  if Prop = nil then
  begin
    Prop            := TDfmProperty.Create;
    Prop.Name       := PropName;
    Prop.ValueKind  := dvkSimple;
    Prop.Indent     := '  ';
    FProperties.Add( Prop );
  end;
  Prop.RawValue     := Value;
end;

{ TDfmDocument }

constructor TDfmDocument.Create;
begin
  inherited;
  FRoot             := TDfmComponent.Create;
  FLineEnding       := #13#10; // Default to CRLF
end;

destructor TDfmDocument.Destroy;
begin
  FRoot.Free;
  inherited;
end;

{ TDelphiDfmParser }

class function TDelphiDfmParser.Parse( const DfmText: string ): TDfmDocument;
var
  Lines             : TStringList;
  LineIndex         : Integer;
  Line, TrimmedLine, Indent: string;
  Stack             : TStack<TDfmComponent>;
  CurrentComponent  : TDfmComponent;
  CurrentProperty   : TDfmProperty;
  Scanner           : TDfmValueScanner;

  function DetectLineEnding: string;
  begin
    if Pos( #13#10, DfmText ) > 0 then
      Result        := #13#10
    else if Pos( #10, DfmText ) > 0 then
      Result        := #10
    else
      Result        := #13#10; // Default
  end;

  function ExtractIndent( const S: string ): string;
  var
    I               : Integer;
  begin
    Result          := '';
    for I := 1 to Length( S ) do
      if CharInSet( S[ I ], [ ' ', #9 ] ) then
        Result      := Result + S[ I ]
      else
        Break;
  end;

  function StartsWithText( const S, Prefix: string ): Boolean;
  begin
    Result          := Copy( S, 1, Length( Prefix ) ) = Prefix;
  end;

  function ParseObjectDeclaration( const S: string; const AIndent: string ): TDfmComponent;
  var
    Rest, ObjName, ObjType: string;
    ColonPos        : Integer;
  begin
    Result          := TDfmComponent.Create;
    Result.Indent   := AIndent;

    // Extract keyword (object/inherited/inline)
    if StartsWithText( S, 'object ' ) then
    begin
      Result.ObjectKind := dokObject;
      Rest          := Copy( S, 8, MaxInt );
    end
    else if StartsWithText( S, 'inherited ' ) then
    begin
      Result.ObjectKind := dokInherited;
      Rest          := Copy( S, 11, MaxInt );
    end
    else if StartsWithText( S, 'inline ' ) then
    begin
      Result.ObjectKind := dokInline;
      Rest          := Copy( S, 8, MaxInt );
    end
    else
      Rest          := S;

    // Parse "Name: Type [n]", or "Type" for an unnamed object
    ColonPos        := Pos( ':', Rest );
    if ColonPos > 0 then
    begin
      ObjName       := Trim( Copy( Rest, 1, ColonPos - 1 ) );
      ObjType       := Trim( Copy( Rest, ColonPos + 1, MaxInt ) );
    end
    else
    begin
      ObjName       := '';
      ObjType       := Trim( Rest );
    end;

    // Split the creation-order index of an inherited component from the class name
    var BracketPos  := Pos( '[', ObjType );
    if BracketPos > 0 then
    begin
      var CloseBracketPos := Pos( ']', ObjType, BracketPos );
      if CloseBracketPos = 0 then CloseBracketPos := Length( ObjType ) + 1;
      Result.OrderIndex := Trim( Copy( ObjType, BracketPos + 1, CloseBracketPos - BracketPos - 1 ) );
      ObjType       := Trim( Copy( ObjType, 1, BracketPos - 1 ) );
    end;

    Result.Name     := ObjName;
    Result.TypeName := ObjType;
  end;

begin
  Result            := TDfmDocument.Create;
  Result.FLineEnding := DetectLineEnding;

  Lines             := TStringList.Create;
  Stack             := TStack<TDfmComponent>.Create;
  try
    Lines.Text      := DfmText;

    CurrentProperty := nil;
    Scanner.Init;

    for LineIndex := 0 to Lines.Count - 1 do
    begin
      Line          := Lines[ LineIndex ];
      TrimmedLine   := TrimLeft( Line );
      Indent        := ExtractIndent( Line );

      // Skip empty lines while not in multi-line property
      if ( TrimmedLine = '' ) and ( CurrentProperty = nil ) then
        Continue;

      // Handle multi-line property continuation
      if CurrentProperty <> nil then
      begin
        // Append line to current property
        CurrentProperty.RawValue := CurrentProperty.RawValue + Result.LineEnding + Line;

        // The value continues while a bracket is open ( outside strings ) or the line ends with +
        Scanner.Scan( Line, 1 );
        if Scanner.Complete then CurrentProperty := nil;

        Continue;
      end;

      // Object/inherited/inline declaration
      if StartsWithText( TrimmedLine, 'object ' ) or
        StartsWithText( TrimmedLine, 'inherited ' ) or
        StartsWithText( TrimmedLine, 'inline ' ) then
      begin
        CurrentComponent := ParseObjectDeclaration( TrimmedLine, Indent );

        if Stack.Count = 0 then
        begin
          // Root component
          Result.FRoot.Free;
          Result.FRoot := CurrentComponent;
        end
        else
        begin
          // Child component
          Stack.Peek.Children.Add( CurrentComponent );
        end;

        Stack.Push( CurrentComponent );
        Continue;
      end;

      // End keyword
      if TrimmedLine = 'end' then
      begin
        if Stack.Count > 0 then
        begin
          Stack.Peek.EndIndent := Indent;
          Stack.Pop;
        end;
        Continue;
      end;

      // Property declaration (contains '=')
      if Pos( '=', TrimmedLine ) > 0 then
      begin
        CurrentProperty := TDfmProperty.Create;
        CurrentProperty.Indent := Indent;

        // Extract property name and value
        var EqPos: Integer;
        EqPos       := Pos( '=', Line );
        CurrentProperty.Name := Trim( Copy( Line, 1, EqPos - 1 ) );
        CurrentProperty.SpaceAfterEquals := ( EqPos < Length( Line ) ) and ( Line[ EqPos + 1 ] = ' ' );
        if CurrentProperty.SpaceAfterEquals then
          CurrentProperty.RawValue := Copy( Line, EqPos + 2, MaxInt ) // Skip '= '
        else
          CurrentProperty.RawValue := Copy( Line, EqPos + 1, MaxInt ); // Skip '='

        // Detect value kind from the value's first character: a bracket inside a string is text
        var FirstValue := Trim( CurrentProperty.RawValue );
        if StartsWithText( FirstValue, '{' ) then
          CurrentProperty.ValueKind := dvkBinary
        else if StartsWithText( FirstValue, '<' ) then
          CurrentProperty.ValueKind := dvkCollection
        else if StartsWithText( FirstValue, '(' ) then
          CurrentProperty.ValueKind := dvkParenList
        else if StartsWithText( FirstValue, '[' ) then
          CurrentProperty.ValueKind := dvkSet
        else if StartsWithText( FirstValue, '''' ) or StartsWithText( FirstValue, '#' ) then
          CurrentProperty.ValueKind := dvkString
        else
          CurrentProperty.ValueKind := dvkSimple;

        if Stack.Count > 0 then
          Stack.Peek.Properties.Add( CurrentProperty )
        else
          FreeAndNil( CurrentProperty ); // a property outside any object: malformed text, not kept

        // The value continues on the next lines while a bracket is open ( outside strings ), the
        // line ends with +, or no value has been seen yet
        Scanner.Init;
        Scanner.Scan( Line, EqPos + 1 );
        if Scanner.Complete then CurrentProperty := nil;
      end;
    end;

  finally
    Stack.Free;
    Lines.Free;
  end;
end;

class function TDelphiDfmParser.Serialize( Doc: TDfmDocument ): string;
var
  Lines             : TStringList;

  procedure SerializeComponent( Component: TDfmComponent );
  var
    Keyword         : string;
    Prop            : TDfmProperty;
    Child           : TDfmComponent;
  begin
    // Object declaration
    case Component.ObjectKind of
      dokObject: Keyword := 'object';
      dokInherited: Keyword := 'inherited';
      dokInline: Keyword := 'inline';
    end;

    var Header      := Component.Indent + Keyword + ' ';
    if Component.Name <> '' then Header := Header + Component.Name + ': ';
    Header          := Header + Component.TypeName;
    if Component.OrderIndex <> '' then Header := Header + ' [' + Component.OrderIndex + ']';
    Lines.Add( Header );

    // Properties
    for Prop in Component.Properties do
      if Prop.SpaceAfterEquals then
        Lines.Add( Prop.Indent + Prop.Name + ' = ' + Prop.RawValue )
      else
        Lines.Add( Prop.Indent + Prop.Name + ' =' + Prop.RawValue );

    // Children (recursive)
    for Child in Component.Children do
      SerializeComponent( Child );

    // End
    Lines.Add( Component.EndIndent + 'end' );
  end;

begin
  Lines             := TStringList.Create;
  try
    Lines.LineBreak := Doc.LineEnding;

    if Doc.Header <> '' then
      Lines.Add( Doc.Header );

    SerializeComponent( Doc.Root );

    if Doc.Trailer <> '' then
      Lines.Add( Doc.Trailer );

    Result          := Lines.Text;
  finally
    Lines.Free;
  end;
end;

end.

