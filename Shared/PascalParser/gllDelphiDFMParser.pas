{******************************************************************************}
{*                                                                            *}
{* DelphiDfmParser - Lossless DFM Text Parser                                *}
{*                                                                            *}
{* Purpose: Parse and serialize Delphi .dfm files with exact fidelity        *}
{* Design goal: Parse(text) then Serialize() = identical text                *}
{*                                                                            *}
{* Part of DDevExtensions                                                     *}
{* https://github.com/MasterpieceDeveloper/DDevExtensions                     *}
{*                                                                            *}
{******************************************************************************}

unit gllDelphiDFMParser;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  /// <summary>DFM property value types</summary>
  TDfmValueKind = (
    dvkSimple,       // Name = Value
    dvkString,       // Name = 'string'
    dvkMultiLine,    // Name = 'line1' + #13#10 + 'line2'
    dvkSet,          // Name = [item1, item2]
    dvkBinary,       // Name = { hex bytes }
    dvkCollection,   // Name = < ... >
    dvkParenList     // Name = ( item1 item2 )
  );

  /// <summary>Represents a single property in a DFM component</summary>
  TDfmProperty = class
  private
    FName: string;
    FValueKind: TDfmValueKind;
    FRawValue: string;
    FIndent: string;
  public
    /// <summary>Property name</summary>
    property Name: string read FName write FName;
    /// <summary>Type of property value</summary>
    property ValueKind: TDfmValueKind read FValueKind write FValueKind;
    /// <summary>Raw text of the value after '=' preserving exact formatting</summary>
    property RawValue: string read FRawValue write FRawValue;
    /// <summary>Leading whitespace before the property name</summary>
    property Indent: string read FIndent write FIndent;
  end;

  /// <summary>DFM object declaration types</summary>
  TDfmObjectKind = (dokObject, dokInherited, dokInline);

  /// <summary>Represents a component (object) in a DFM file</summary>
  TDfmComponent = class
  private
    FName: string;
    FTypeName: string;
    FObjectKind: TDfmObjectKind;
    FProperties: TObjectList<TDfmProperty>;
    FChildren: TObjectList<TDfmComponent>;
    FIndent: string;
    FEndIndent: string;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Find a property by name (case-insensitive)</summary>
    function FindProperty(const PropName: string): TDfmProperty;
    /// <summary>Find a child component by name (case-insensitive)</summary>
    function FindChild(const ChildName: string): TDfmComponent;
    /// <summary>Delete a property by name</summary>
    procedure DeleteProperty(const PropName: string);
    /// <summary>Set a simple property value (creates if not exists)</summary>
    procedure SetProperty(const PropName, Value: string);

    /// <summary>Component name (e.g. 'Button1')</summary>
    property Name: string read FName write FName;
    /// <summary>Component type (e.g. 'TButton')</summary>
    property TypeName: string read FTypeName write FTypeName;
    /// <summary>Object declaration keyword used</summary>
    property ObjectKind: TDfmObjectKind read FObjectKind write FObjectKind;
    /// <summary>Properties of this component</summary>
    property Properties: TObjectList<TDfmProperty> read FProperties;
    /// <summary>Child components (nested objects)</summary>
    property Children: TObjectList<TDfmComponent> read FChildren;
    /// <summary>Leading whitespace of 'object' line</summary>
    property Indent: string read FIndent write FIndent;
    /// <summary>Leading whitespace of 'end' line</summary>
    property EndIndent: string read FEndIndent write FEndIndent;
  end;

  /// <summary>Represents a complete DFM document</summary>
  TDfmDocument = class
  private
    FRoot: TDfmComponent;
    FLineEnding: string;
    FHeader: string;
    FTrailer: string;
  public
    constructor Create;
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

  /// <summary>DFM parser and serializer</summary>
  TDelphiDfmParser = class
  public
    /// <summary>Parse DFM text into a document structure</summary>
    class function Parse(const DfmText: string): TDfmDocument;
    /// <summary>Serialize a document structure back to DFM text</summary>
    class function Serialize(Doc: TDfmDocument): string;
  end;

implementation

{ TDfmComponent }

constructor TDfmComponent.Create;
begin
  inherited;
  FProperties := TObjectList<TDfmProperty>.Create(True);
  FChildren := TObjectList<TDfmComponent>.Create(True);
  FObjectKind := dokObject;
end;

destructor TDfmComponent.Destroy;
begin
  FProperties.Free;
  FChildren.Free;
  inherited;
end;

function TDfmComponent.FindProperty(const PropName: string): TDfmProperty;
var
  Prop: TDfmProperty;
begin
  for Prop in FProperties do
    if SameText(Prop.Name, PropName) then
      Exit(Prop);
  Result := nil;
end;

function TDfmComponent.FindChild(const ChildName: string): TDfmComponent;
var
  Child: TDfmComponent;
begin
  for Child in FChildren do
    if SameText(Child.Name, ChildName) then
      Exit(Child);
  Result := nil;
end;

procedure TDfmComponent.DeleteProperty(const PropName: string);
var
  Prop: TDfmProperty;
begin
  Prop := FindProperty(PropName);
  if Prop <> nil then
    FProperties.Remove(Prop);
end;

procedure TDfmComponent.SetProperty(const PropName, Value: string);
var
  Prop: TDfmProperty;
begin
  Prop := FindProperty(PropName);
  if Prop = nil then
  begin
    Prop := TDfmProperty.Create;
    Prop.Name := PropName;
    Prop.ValueKind := dvkSimple;
    Prop.Indent := '  ';
    FProperties.Add(Prop);
  end;
  Prop.RawValue := Value;
end;

{ TDfmDocument }

constructor TDfmDocument.Create;
begin
  inherited;
  FRoot := TDfmComponent.Create;
  FLineEnding := #13#10; // Default to CRLF
end;

destructor TDfmDocument.Destroy;
begin
  FRoot.Free;
  inherited;
end;

{ TDelphiDfmParser }

class function TDelphiDfmParser.Parse(const DfmText: string): TDfmDocument;
var
  Lines: TStringList;
  LineIndex: Integer;
  Line, TrimmedLine, Indent: string;
  Stack: TStack<TDfmComponent>;
  CurrentComponent: TDfmComponent;
  CurrentProperty: TDfmProperty;
  InBinary: Boolean;
  InCollection: Boolean;
  InParenList: Boolean;
  AngleDepth: Integer;
  BraceDepth: Integer;
  ParenDepth: Integer;

  function DetectLineEnding: string;
  begin
    if Pos(#13#10, DfmText) > 0 then
      Result := #13#10
    else if Pos(#10, DfmText) > 0 then
      Result := #10
    else
      Result := #13#10; // Default
  end;

  function ExtractIndent(const S: string): string;
  var
    I: Integer;
  begin
    Result := '';
    for I := 1 to Length(S) do
      if CharInSet(S[I], [' ', #9]) then
        Result := Result + S[I]
      else
        Break;
  end;

  function StartsWithText(const S, Prefix: string): Boolean;
  begin
    Result := Copy(S, 1, Length(Prefix)) = Prefix;
  end;

  function EndsWithPlus(const S: string): Boolean;
  var
    Trimmed: string;
  begin
    Trimmed := TrimRight(S);
    Result := (Length(Trimmed) > 0) and (Trimmed[Length(Trimmed)] = '+');
  end;

  function ParseObjectDeclaration(const S: string; const AIndent: string): TDfmComponent;
  var
    Rest, ObjName, ObjType: string;
    ColonPos: Integer;
  begin
    Result := TDfmComponent.Create;
    Result.Indent := AIndent;

    // Extract keyword (object/inherited/inline)
    if StartsWithText(S, 'object ') then
    begin
      Result.ObjectKind := dokObject;
      Rest := Copy(S, 8, MaxInt);
    end
    else if StartsWithText(S, 'inherited ') then
    begin
      Result.ObjectKind := dokInherited;
      Rest := Copy(S, 11, MaxInt);
    end
    else if StartsWithText(S, 'inline ') then
    begin
      Result.ObjectKind := dokInline;
      Rest := Copy(S, 8, MaxInt);
    end
    else
      Rest := S;

    // Parse "Name: Type"
    ColonPos := Pos(':', Rest);
    if ColonPos > 0 then
    begin
      ObjName := Trim(Copy(Rest, 1, ColonPos - 1));
      ObjType := Trim(Copy(Rest, ColonPos + 1, MaxInt));
      Result.Name := ObjName;
      Result.TypeName := ObjType;
    end;
  end;

begin
  Result := TDfmDocument.Create;
  Result.FLineEnding := DetectLineEnding;

  Lines := TStringList.Create;
  Stack := TStack<TDfmComponent>.Create;
  try
    Lines.Text := DfmText;

    CurrentProperty := nil;
    InBinary := False;
    InCollection := False;
    InParenList := False;
    AngleDepth := 0;
    BraceDepth := 0;
    ParenDepth := 0;

    for LineIndex := 0 to Lines.Count - 1 do
    begin
      Line := Lines[LineIndex];
      TrimmedLine := TrimLeft(Line);
      Indent := ExtractIndent(Line);

      // Skip empty lines while not in multi-line property
      if (TrimmedLine = '') and (CurrentProperty = nil) then
        Continue;

      // Handle multi-line property continuation
      if CurrentProperty <> nil then
      begin
        // Append line to current property
        CurrentProperty.RawValue := CurrentProperty.RawValue + Result.LineEnding + Line;

        // Track brace/angle depth
        if Pos('{', Line) > 0 then
        begin
          InBinary := True;
          Inc(BraceDepth);
        end;
        if Pos('}', Line) > 0 then
        begin
          Dec(BraceDepth);
          if BraceDepth <= 0 then
            InBinary := False;
        end;
        if Pos('<', TrimmedLine) > 0 then
        begin
          InCollection := True;
          Inc(AngleDepth);
        end;
        if Pos('>', TrimmedLine) > 0 then
        begin
          Dec(AngleDepth);
          if AngleDepth <= 0 then
            InCollection := False;
        end;
        if Pos('(', Line) > 0 then
        begin
          InParenList := True;
          Inc(ParenDepth);
        end;
        if Pos(')', Line) > 0 then
        begin
          Dec(ParenDepth);
          if ParenDepth <= 0 then
            InParenList := False;
        end;

        // Check if property is complete
        // Continue if: binary data, collection, paren list, or line ends with +
        if not InBinary and not InCollection and not InParenList and not EndsWithPlus(Line) then
          CurrentProperty := nil;

        Continue;
      end;

      // Object/inherited/inline declaration
      if StartsWithText(TrimmedLine, 'object ') or
         StartsWithText(TrimmedLine, 'inherited ') or
         StartsWithText(TrimmedLine, 'inline ') then
      begin
        CurrentComponent := ParseObjectDeclaration(TrimmedLine, Indent);

        if Stack.Count = 0 then
        begin
          // Root component
          Result.FRoot.Free;
          Result.FRoot := CurrentComponent;
        end
        else
        begin
          // Child component
          Stack.Peek.Children.Add(CurrentComponent);
        end;

        Stack.Push(CurrentComponent);
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
      if Pos('=', TrimmedLine) > 0 then
      begin
        CurrentProperty := TDfmProperty.Create;
        CurrentProperty.Indent := Indent;

        // Extract property name and value
        var EqPos: Integer;
        EqPos := Pos('=', Line);
        CurrentProperty.Name := Trim(Copy(Line, 1, EqPos - 1));
        CurrentProperty.RawValue := Copy(Line, EqPos + 2, MaxInt); // Skip '= '

        // Detect value kind
        if StartsWithText(TrimmedLine, '{') or (Pos('{', CurrentProperty.RawValue) > 0) then
        begin
          CurrentProperty.ValueKind := dvkBinary;
          InBinary := True;
          BraceDepth := 1;
        end
        else if StartsWithText(TrimmedLine, '<') or (Pos('<', CurrentProperty.RawValue) > 0) then
        begin
          CurrentProperty.ValueKind := dvkCollection;
          InCollection := True;
          AngleDepth := 1;
        end
        else if StartsWithText(TrimmedLine, '(') or (Pos('(', CurrentProperty.RawValue) > 0) then
        begin
          CurrentProperty.ValueKind := dvkParenList;
          InParenList := True;
          ParenDepth := 1;
        end
        else if StartsWithText(Trim(CurrentProperty.RawValue), '[') then
          CurrentProperty.ValueKind := dvkSet
        else if StartsWithText(Trim(CurrentProperty.RawValue), '''') then
          CurrentProperty.ValueKind := dvkString
        else
          CurrentProperty.ValueKind := dvkSimple;

        if Stack.Count > 0 then
          Stack.Peek.Properties.Add(CurrentProperty);

        // Check if property ends on same line
        // Continue if: binary data, collection, paren list, line ends with +, or value is empty/whitespace
        if not InBinary and not InCollection and not InParenList and
           not EndsWithPlus(Line) and (Trim(CurrentProperty.RawValue) <> '') then
          CurrentProperty := nil;
      end;
    end;

  finally
    Stack.Free;
    Lines.Free;
  end;
end;

class function TDelphiDfmParser.Serialize(Doc: TDfmDocument): string;
var
  Lines: TStringList;

  procedure SerializeComponent(Component: TDfmComponent);
  var
    Keyword: string;
    Prop: TDfmProperty;
    Child: TDfmComponent;
  begin
    // Object declaration
    case Component.ObjectKind of
      dokObject: Keyword := 'object';
      dokInherited: Keyword := 'inherited';
      dokInline: Keyword := 'inline';
    end;

    Lines.Add(Component.Indent + Keyword + ' ' + Component.Name + ': ' + Component.TypeName);

    // Properties
    for Prop in Component.Properties do
      Lines.Add(Prop.Indent + Prop.Name + ' = ' + Prop.RawValue);

    // Children (recursive)
    for Child in Component.Children do
      SerializeComponent(Child);

    // End
    Lines.Add(Component.EndIndent + 'end');
  end;

begin
  Lines := TStringList.Create;
  try
    Lines.LineBreak := Doc.LineEnding;

    if Doc.Header <> '' then
      Lines.Add(Doc.Header);

    SerializeComponent(Doc.Root);

    if Doc.Trailer <> '' then
      Lines.Add(Doc.Trailer);

    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

end.
