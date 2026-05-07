unit StartParameterClasses;

/// <summary>
/// Defines the data model for the Start Parameter Manager: an XML-backed list of named parameters,
/// macros and includes resolved on demand for the currently active project. Supports built-in macros,
/// environment-variable fallback, conditional include/macro/param tags and recursive include files.
/// </summary>

{
Project.dproj
  Project.params
  Project.params.local

Predefined Macros:
  $(ParamFileName)      Full Filename of the *.params file
  $(ParamFilePath)      Direcory of the *.params file
  $(Year)               Current year
  $(Month)              Current month
  $(Day)                Current day
  $(MonthShortName)     Short name (3 charaters) of the current month (local settings)
  $(MonthName)          Full name of the current month (local settings)
  $(LastMonthShortName) Short name (3 charaters) of the last month (local settings)
  $(LastMonthName)      Full name of the last month (local settings)
  $(LastYear)           Last year

  $(ParamFileName)      => projectpath\project.param
  $(ParamFilePath)      => projectpath\
  $(Year)               => 2011
  $(Month)              => 12
  $(Day)                => 19
  $(MonthShortName)     => Dec
  $(MonthName)          => December
  $(LastMonthShortName) => Nov
  $(LastMonthName)      => November
  $(LastYear)           => 2010

Project.params/.local:
<?xml version="1.0" encoding="utf-8"?>
<StartParameters>
  <Include File="$(ParamFilePath)\..\..\GlobalParams.params" Force="true"/>
  <Macro Name="DB">MeineDB</Macro>
  <Macro Name="PASSWORD" FromFile="C:\Somewhere\Password.txt" Line="4" RegEx="&quot;[A-Z]*;quot;"/>

  <Param Name="My Param">-x -y -z</Param>
  <Param Name="User@MeineDB">-a $(DB) -u USER -p $(PASSWORD)</Param>

  <Include File="$(ParamFileName).local" />
</StartParameters>

Include, Macro and Param can have a "Condition" attribute:
  <Macro Name="DB" Condition=" exists('$(ParamFileName).local') and true ">value</Macro>
  <Macro Name="DB" Condition=" '$(DB)' == '' ">value</Macro>
Available condition functions:
  Exists('filename')   returns true if the file exists

Include-Tag attributes:
  File:        File that should be included
  [Force]:     true : Shows an error message if the file doesn't exist.
               false: Ignore missing files
  [Condition]: Include the file only if the condition evaluates to true

  <Include File="$(ParamFileName).local" />

Macro-Tag attributes (value):
  Name:        Name of the macro that is used in $(name)
  [Condition]: Set macro only if the condition evaluates to true

  <Macro Name="MacroName" Condition=" '$(MacroName)' == '' ">Default</Macro>

Macro-Tag attributes (load from file):
  Name:        Name of the macro that is used in $(name)
  FromFile:    File that contains or is the macro value
  [Line]:      Line number of the line that should be the macro value (1..LineCount).
               A line number less than 1 means the whole file is the value
  [RegEx]:     Regular expression that is applied to the content of the file or line.
  [Condition]: Set macro only if the condition evaluates to true

  <Macro Name="PASSWORD" FromFile="$(ParamFilePath)\Passwords.txt" Line="4" RegEx="&quot;[A-Z]*;quot;"/>
}

interface

uses
  SysUtils, Classes, Contnrs, XMLDoc, XMLIntf;

type
  /// <summary>Exception class raised by the Start Parameter loader/parser.</summary>
  EStartParameterError = class(Exception);

  TStartParamList = class;

  /// <summary>Abstract base class for Include, Macro and Param items in a TStartParamList.</summary>
  TStartParamBase = class(TObject)
  private
    /// <summary>Owning parameter list (also gives access to FileName/macros).</summary>
    FOwner: TStartParamList;
    /// <summary>Backing XML node (when loaded from / saved to disk).</summary>
    FNode: IXMLNode;
    /// <summary>Optional condition expression that must evaluate to True for the item to apply.</summary>
    FCondition: string;
    /// <summary>Cached condition result (-1 means not yet evaluated).</summary>
    FConditionEvalValue: Integer;
    /// <summary>Setter for Condition; resets the cached result and marks the list modified.</summary>
    procedure SetCondition(const AValue: string);
  protected
    /// <summary>Marks the owning list as modified (and invalidates condition caches).</summary>
    procedure MarkModified;
  public
    /// <summary>Creates an item belonging to AOwner.</summary>
    constructor Create(AOwner: TStartParamList);
    /// <summary>Removes the item from its owner and deletes its XML node.</summary>
    destructor Destroy; override;

    /// <summary>Synonym for Free, used to remove the item.</summary>
    procedure Delete;
    /// <summary>Restores common state (FNode, Condition) from an XML node; subclasses extend.</summary>
    procedure LoadFromXml(ANode: IXMLNode; AErrors: TStrings); virtual;
    /// <summary>Persists common state (Condition) into an XML node; subclasses extend.</summary>
    procedure SaveToXml(ANode: IXmlNode); virtual;

    /// <summary>Evaluates Condition (resolving macros first); empty Condition is treated as True.</summary>
    function EvalCondition: Boolean;

    /// <summary>Optional condition expression that must evaluate to True for the item to apply.</summary>
    property Condition: string read FCondition write SetCondition;

    /// <summary>Owning parameter list.</summary>
    property Owner: TStartParamList read FOwner;
  end;

  /// <summary>"Include" item that links to another .params file whose contents are merged in.</summary>
  TStartParamInclude = class(TStartParamBase)
  private
    /// <summary>Raw (possibly macro-bearing) include file name.</summary>
    FFileName: string;
    /// <summary>Owned parameter list loaded from the include file.</summary>
    FStartParamList: TStartParamList;
    /// <summary>If True, missing include files raise an error; otherwise they are silently skipped.</summary>
    FForce: Boolean;
    /// <summary>Returns the include file name with macros and relative paths resolved.</summary>
    function GetResolvedFileName: string;
    /// <summary>Setter for FileName; marks the list modified on change.</summary>
    procedure SetFileName(const AValue: string);
    /// <summary>Setter for Force; marks the list modified on change.</summary>
    procedure SetForce(const AValue: Boolean);
  public
    /// <summary>Creates an Include item and its owned child TStartParamList.</summary>
    constructor Create(AOwner: TStartParamList);
    /// <summary>Frees the owned child TStartParamList.</summary>
    destructor Destroy; override;
    /// <summary>Restores File, Force and Condition attributes from XML.</summary>
    procedure LoadFromXml(ANode: IXMLNode; AErrors: TStrings); override;
    /// <summary>Persists File, Force and Condition attributes to XML.</summary>
    procedure SaveToXml(ANode: IxmlNode); override;

    /// <summary>If True, missing include files raise an error.</summary>
    property Force: Boolean read FForce write SetForce;
    /// <summary>Raw (possibly macro-bearing) include file name.</summary>
    property FileName: string read FFileName write SetFileName;
    /// <summary>Include file name with macros and relative paths resolved.</summary>
    property ResolvedFileName: string read GetResolvedFileName;

    /// <summary>Owned parameter list loaded from the include file.</summary>
    property StartParamList: TStartParamList read FStartParamList;
  end;

  /// <summary>Distinguishes value-defined macros from file-defined macros.</summary>
  TStartParamMacroKind = (mkValue, mkFile);

  /// <summary>"Macro" item providing a name/value pair (or a name backed by a file's contents).</summary>
  TStartParamMacro = class(TStartParamBase)
  private
    /// <summary>Source file name (mkFile) or empty (mkValue).</summary>
    FFileName: string;
    /// <summary>Macro name (used as $(Name) elsewhere).</summary>
    FName: string;
    /// <summary>Optional regular expression filter applied to file contents (mkFile).</summary>
    FRegEx: string;
    /// <summary>Macro kind: value or file-backed.</summary>
    FKind: TStartParamMacroKind;
    /// <summary>Literal value (mkValue).</summary>
    FValue: string;
    /// <summary>1-based line index inside the source file (mkFile); 0 means whole file.</summary>
    FLine: string;
    /// <summary>Computes the macro's resolved value (recursively resolving nested macros).</summary>
    function GetResolvedValue: string;
    /// <summary>Setter for FileName; marks the list modified on change.</summary>
    procedure SetFileName(const AValue: string);
    /// <summary>Setter for Kind; marks the list modified on change.</summary>
    procedure SetKind(const AValue: TStartParamMacroKind);
    /// <summary>Setter for Line; marks the list modified on change.</summary>
    procedure SetLine(const AValue: string);
    /// <summary>Setter for RegEx; marks the list modified on change.</summary>
    procedure SetRegEx(const AValue: string);
    /// <summary>Setter for Value; marks the list modified on change.</summary>
    procedure SetValue(const AValue: string);
    /// <summary>Setter for Name; marks the list modified on change.</summary>
    procedure SetName(const AValue: string);
    /// <summary>Returns the macro's source file name with macros and relative paths resolved.</summary>
    function GetResolvedFileName: string;
  public
    /// <summary>Restores Name, Value, FromFile, Line, RegEx and Condition attributes from XML.</summary>
    procedure LoadFromXml(ANode: IXMLNode; AErrors: TStrings); override;
    /// <summary>Persists Name, Value, FromFile, Line, RegEx and Condition attributes to XML.</summary>
    procedure SaveToXml(ANode: IxmlNode); override;

    /// <summary>Macro kind: value or file-backed.</summary>
    property Kind: TStartParamMacroKind read FKind write SetKind;
    /// <summary>Macro name (used as $(Name) elsewhere).</summary>
    property Name: string read FName write SetName;

    // mkValue
    /// <summary>Literal macro value (mkValue).</summary>
    property Value: string read FValue write SetValue;

    // mkFile
    /// <summary>Source file name (mkFile).</summary>
    property FileName: string read FFileName write SetFileName;
    /// <summary>Optional regex applied to the file contents (mkFile).</summary>
    property RegEx: string read FRegEx write SetRegEx;
    /// <summary>1-based line index (mkFile); 0/empty means whole file.</summary>
    property Line: string read FLine write SetLine;

    /// <summary>Source file name with macros and relative paths resolved.</summary>
    property ResolvedFileName: string read GetResolvedFileName;
    /// <summary>Computed macro value (with nested macros resolved).</summary>
    property ResolvedValue: string read GetResolvedValue;
  end;

  /// <summary>"Param" item that contributes a named command-line parameter set.</summary>
  TStartParam = class(TStartParamBase)
  private
    /// <summary>Display name of the parameter (shown in the toolbar dropdown).</summary>
    FName: string;
    /// <summary>Raw parameter value (may contain macros).</summary>
    FValue: string;

    /// <summary>True once the parameter value has been resolved into FResolvedValue.</summary>
    FResolved: Boolean;
    /// <summary>Cached resolved parameter value.</summary>
    FResolvedValue: string;
    /// <summary>Computes (and caches) the parameter value with macros resolved.</summary>
    function GetResolvedValue: string;
    /// <summary>Setter for Value; marks the list modified on change.</summary>
    procedure SetValue(const AValue: string);
    /// <summary>Setter for Name; marks the list modified on change.</summary>
    procedure SetName(const Value: string);
  public
    /// <summary>Restores Name, Value and Condition attributes from XML.</summary>
    procedure LoadFromXml(ANode: IXMLNode; AErrors: TStrings); override;
    /// <summary>Persists Name, Value and Condition attributes to XML.</summary>
    procedure SaveToXml(ANode: IxmlNode); override;

    /// <summary>Display name of the parameter.</summary>
    property Name: string read FName write SetName;
    /// <summary>Raw parameter value (may contain macros).</summary>
    property Value: string read FValue write SetValue;
    /// <summary>Parameter value with macros resolved.</summary>
    property ResolvedValue: string read GetResolvedValue;
  end;

  /// <summary>Lightweight enumerator over the TStartParam items of a TList.</summary>
  TStartParamListEnumerator = record
  private
    /// <summary>Underlying list to enumerate.</summary>
    FList: TList;
    /// <summary>Current zero-based index (-1 before MoveNext is called).</summary>
    FIndex: Integer;
  public
    /// <summary>Initialises the enumerator over AList.</summary>
    constructor Create(AList: TList);
    /// <summary>Advances to the next element; returns False at end.</summary>
    function MoveNext: Boolean;
    /// <summary>Returns the element at the current index.</summary>
    function GetCurrent: TStartParam;
    /// <summary>Element at the current index.</summary>
    property Current: TStartParam read GetCurrent;
  end;

  /// <summary>Owns a TList of TStartParam objects and provides a "for in" enumerator.</summary>
  TStartParamListEnumeration = class(TObject)
  private
    /// <summary>Owned underlying list.</summary>
    FList: TList;
  public
    /// <summary>Takes ownership of AList.</summary>
    constructor Create(AList: TList);
    /// <summary>Frees the underlying list.</summary>
    destructor Destroy; override;
    /// <summary>Returns an enumerator over the list.</summary>
    function GetEnumerator: TStartParamListEnumerator;
  end;

  /// <summary>Top-level container for the items (Include, Macro, Param) of a .params file.</summary>
  TStartParamList = class(TObject)
  private
    /// <summary>Parent Include item (nil for the root list).</summary>
    FParent: TStartParamInclude;
    /// <summary>Backing XML document.</summary>
    FXmlDoc: IXMLDocument;
    /// <summary>Owned items (TStartParamInclude, TStartParamMacro, TStartParam).</summary>
    FItems: TObjectList;
    /// <summary>True after a structural or value change requires a save.</summary>
    FModified: Boolean;
    /// <summary>Persisted name of the active parameter (root list only).</summary>
    FActiveParamName: string;
    /// <summary>Source file name of the loaded .params file.</summary>
    FFileName: string;
    /// <summary>Last-modified time of the loaded source file (for change detection).</summary>
    FFileTime: TDateTime;
    /// <summary>Returns the number of items in the list.</summary>
    function GetCount: Integer;
    /// <summary>Returns the item at the given index.</summary>
    function GetItem(Index: Integer): TStartParamBase;
    /// <summary>Loads an &lt;Include&gt; XML node into the list (recursively loading the included file).</summary>
    procedure LoadIncludeNode(ANode: IXMLNode; AErrors: TStrings; ARecursionCount: Integer);
    /// <summary>Returns ActiveParamName, clearing it if the parameter no longer exists.</summary>
    function GetActiveParamName: string;
    /// <summary>Recursively appends every available TStartParam (respecting Condition) to AList.</summary>
    procedure CollectParams(AList: TList; AIgnoreCondition: Boolean);
    /// <summary>Setter for ActiveParamName; marks the list modified on change.</summary>
    procedure SetActiveParamName(const AValue: string);
    /// <summary>Internal recursive loader that enforces the include depth limit.</summary>
    procedure InternLoadFromFile(const AFileName: string; ARecursionCount: Integer);
    /// <summary>Removes the supplied XML node and surrounding indentation whitespace.</summary>
    procedure DeleteNode(Node: IXMLNode);
    /// <summary>Lazily creates the backing IXmlDocument with auto-indent enabled.</summary>
    procedure RequireXmlDoc;
  protected
    /// <summary>Marks this list modified and invalidates every item's cached condition result.</summary>
    procedure MarkModified;
    /// <summary>Recursively expands $(Macro) and built-in tokens inside AValue, stopping before AStopItem.</summary>
    function ResolveValue(AStopItem: TStartParamBase; const AValue: string): string;
    /// <summary>Locates the last matching macro by name, recursing into includes and the parent list.</summary>
    function FindMacro(AStopItem: TStartParamBase; const AMacroName: string): TStartParamMacro;
  public
    /// <summary>Creates the list (with optional parent Include item).</summary>
    constructor Create(AParent: TStartParamInclude);
    /// <summary>Frees the owned items.</summary>
    destructor Destroy; override;
    /// <summary>Removes every item from the list and clears the XML document.</summary>
    procedure Clear;
    /// <summary>Loads the list from the supplied .params file.</summary>
    procedure LoadFromFile(const AFileName: string);
    /// <summary>Saves the list to the supplied .params file.</summary>
    procedure SaveToFile(const AFileName: string);
    /// <summary>Saves the list to its currently associated file (or the parent's resolved file).</summary>
    procedure Save;
    /// <summary>Re-reads the file if its modification time changed; recurses into includes.</summary>
    /// <returns>True if any list (this or an included one) was actually reloaded.</returns>
    function Reload: Boolean;
    /// <summary>Returns the last param matching AParamName whose Condition holds (recursing into includes).</summary>
    function FindParam(const AParamName: string): TStartParam;
    /// <summary>Returns the child include list whose unresolved file name matches AIncludeFileName, or nil.</summary>
    function FindIncludeParamList(const AIncludeFileName: string): TStartParamList;
    /// <summary>Returns an enumerable of the available parameters, respecting Condition by default.</summary>
    function AvailableParams(AIgnoreCondition: Boolean = False): TStartParamListEnumeration;

    /// <summary>Adds AItem to the list and returns it.</summary>
    function Add(AItem: TStartParamBase): TStartParamBase;
    /// <summary>Returns an existing matching include or creates a new one for AIncludeFileName.</summary>
    function AddInclude(const AIncludeFileName: string; AForceInclude: Boolean): TStartParamInclude;

    /// <summary>Number of items in the list.</summary>
    property Count: Integer read GetCount;
    /// <summary>Default indexer over the items.</summary>
    property Items[Index: Integer]: TStartParamBase read GetItem; default;
    /// <summary>Currently active parameter (persisted on the root list only).</summary>
    property ActiveParamName: string read GetActiveParamName write SetActiveParamName;

    /// <summary>Source .params file name.</summary>
    property FileName: string read FFileName;
    /// <summary>Last-modified time of the source file at load.</summary>
    property FileTime: TDateTime read FFileTime;
    /// <summary>True after a structural or value change requires a save.</summary>
    property Modified: Boolean read FModified;
    /// <summary>Parent Include item (nil for the root list).</summary>
    property Parent: TStartParamInclude read FParent;
  end;

implementation

uses
  StrUtils, RegularExpressions, Variants, DateUtils, DelphiLexer, DelphiExpr;

resourcestring
  RsNotAValidParamFile = 'Not a valid Start Parameters file: %s';
  RsLoadError = 'Error loading Start Parameters from %s'#10#10'%s';
  RsMissingFileAttribute = 'Start Parameter: Include-Tag is missing the "File" attribute';
  RsFileNotFound = 'Start Parameter: File not found: %s';
  RsInvalidIncludeAttributes = 'Start Parameter: Invalid Include-Tag attributes';
  RsInvalidMacroAttributes = 'Start Parameter: Invalid Macro-Tag attributes';
  RsInvalidParamAttributes = 'Start Parameter: Invalid Param-Tag attributes';
  RsMissingMacroName = 'Start Parameter: Macro-Tag is missing the "Name" attribute';
  RsMissingParamName = 'Start Parameter: Param-Tag is missing the "Name" attribute';
  RsNoFileNameSet = 'No file name set for the Start Parameter List';
  RsMaxIncludeRecursionReached = 'Start Parameters: Maximum include file recursion reached.';

type
  TMacroResolveMethod = reference to function(const AMacroName: string): string;

function ResolveRelativePath(const BaseDir, RelFileName: string): string;
begin
  // base dir
  if RelFileName = '' then
  begin
    Result := BaseDir;
    Exit;
  end;

  // absolute path
  if StartsStr('\\', RelFileName) or ((Length(RelFileName) > 1) and (RelFileName[2] = ':')) then
  begin
    Result := RelFileName;
    Exit;
  end;

  // drive relative path
  if (RelFileName[1] = '\') or (RelFileName[1] = '/') then
  begin
    Result := ExtractFileDrive(BaseDir) + RelFileName;
    Exit;
  end;

  Result := IncludeTrailingPathDelimiter(BaseDir) + RelFileName;
end;

type
  TConditionParser = class(TExpressionParser)
  protected
    function IsBoolFunction(const Name: string): Boolean; override;
    function EvalBoolFunction(IdentToken: TToken; const Args: TDynTokenArray): Boolean; override;
    class function FixCRelations(const S: string): string; static;
  public
    class function EvalBoolExpression(const Expression: string): Boolean; static;
  end;

{ TConditionParser }

function TConditionParser.EvalBoolFunction(IdentToken: TToken; const Args: TDynTokenArray): Boolean;
begin
  if SameText(IdentToken.Value, 'exists') then
  begin
    if Length(Args) <> 1 then
      Error('Invalid exists() syntax. Usage: exists(''filename'')')
    else if Args[0].Kind <> tkString then
      Error(Format('exists(): string expected but "%s" found', [Args[0].Value]));
    Result := FileExists(AnsiDequotedStr(Args[0].Value, ''''));
  end
  else
    Result := inherited EvalBoolFunction(IdentToken, Args);
end;

class function TConditionParser.FixCRelations(const S: string): string;
var
  P: PChar;
  InStr: Boolean;
begin
  // convert " == " => " =  " and " != " => " <> "
  Result := S;
  UniqueString(Result);
  P := PChar(Result);
  InStr := False;
  while P[0] <> #0 do
  begin
    case P[0] of
      '''': InStr := not InStr;
      '=':
        if not InStr then
          if P[1] = '=' then P[1] := ' ';
      '!':
        if not InStr then
          if P[1] = '=' then
          begin
            P[0] := '<';
            P[1] := '>';
          end;
    end;
    Inc(P);
  end;
end;

function TConditionParser.IsBoolFunction(const Name: string): Boolean;
begin
  Result := SameText(Name, 'exists');
end;

class function TConditionParser.EvalBoolExpression(const Expression: string): Boolean;
var
  Lexer: TDelphiLexer;
  Parser: TConditionParser;
begin
  if Expression = '' then
    Result := True
  else
  begin
    // all macros are already resolved
    Lexer := TDelphiLexer.Create('', UTF8Encode(TConditionParser.FixCRelations(Expression)));
    try
      Parser := TConditionParser.Create(Lexer);
      try
        Result := Parser.Parse;
      finally
        Parser.Free;
      end;
    finally
      Lexer.Free;
    end;
  end;
end;

{ TStartParamBase }

constructor TStartParamBase.Create(AOwner: TStartParamList);
begin
  inherited Create;
  FOwner := AOwner;
  FConditionEvalValue := -1;
end;

destructor TStartParamBase.Destroy;
begin
  FOwner.FItems.Extract(Self);
  if FNode <> nil then
    FOwner.DeleteNode(FNode);
  inherited Destroy;
end;

function TStartParamBase.EvalCondition: Boolean;
begin
  if FConditionEvalValue = -1 then
    FConditionEvalValue := Ord(TConditionParser.EvalBoolExpression(FOwner.ResolveValue(Self, Condition)));
  Result := Boolean(FConditionEvalValue);
end;

procedure TStartParamBase.Delete;
begin
  Free;
end;

procedure TStartParamBase.LoadFromXml(ANode: IXMLNode; AErrors: TStrings);
begin
  FNode := ANode;
  if ANode.HasAttribute('Condition') then
    FCondition := ANode.Attributes['Condition']
  else
    FCondition := '';
end;

procedure TStartParamBase.SaveToXml(ANode: IXmlNode);
begin
  FNode := ANode;
  if FCondition <> '' then
    ANode.Attributes['Condition'] := FCondition
  else
    ANode.Attributes['Condition'] := Null;
end;

procedure TStartParamBase.SetCondition(const AValue: string);
begin
  if AValue <> FCondition then
  begin
    FCondition := AValue;
    FConditionEvalValue := -1;
    MarkModified;
  end;
end;

procedure TStartParamBase.MarkModified;
begin
  if FOwner <> nil then
    FOwner.MarkModified;
end;

{ TStartParamInclude }

constructor TStartParamInclude.Create(AOwner: TStartParamList);
begin
  inherited Create(AOwner);
  FStartParamList := TStartParamList.Create(Self);
end;

destructor TStartParamInclude.Destroy;
begin
  FStartParamList.Free;
  inherited Destroy;
end;

function TStartParamInclude.GetResolvedFileName: string;
begin
  Result := ResolveRelativePath(ExtractFileDir(FOwner.FileName), FOwner.ResolveValue(Self, FileName));
end;

procedure TStartParamInclude.LoadFromXml(ANode: IXMLNode; AErrors: TStrings);
var
  NodeCount: Integer;
begin
  inherited LoadFromXml(ANode, AErrors);

  if not ANode.HasAttribute('File') then
    AErrors.Add(RsMissingFileAttribute)
  else
  begin
    NodeCount := ANode.AttributeNodes.Count;
    if NodeCount > 2 then
    begin
      if ANode.HasAttribute('Condition') then
      begin
        if NodeCount > 3 then
          AErrors.Add(RsInvalidIncludeAttributes);
      end
      else
        AErrors.Add(RsInvalidIncludeAttributes);
    end;

    FForce := ANode.HasAttribute('Force') and SameText(ANode.Attributes['Force'], 'true');
    FFileName := ANode.Attributes['File'];
  end;
end;

procedure TStartParamInclude.SaveToXml(ANode: IXmlNode);
begin
  inherited SaveToXml(ANode);

  ANode.Attributes['File'] := FileName;
  if ANode.HasAttribute('Force') and not Force then
    ANode.Attributes['Force'] := Null;
  if Force then
    ANode.Attributes['Force'] := 'true';
end;

procedure TStartParamInclude.SetFileName(const AValue: string);
begin
  if AValue <> FFileName then
  begin
    FFileName := AValue;
    MarkModified;
  end;
end;

procedure TStartParamInclude.SetForce(const AValue: Boolean);
begin
  if AValue <> FForce then
  begin
    FForce := AValue;
    MarkModified;
  end;
end;

{ TStartParamMacro }

function TStartParamMacro.GetResolvedFileName: string;
begin
  Result := ResolveRelativePath(ExtractFileDir(FOwner.FileName), FOwner.ResolveValue(Self, FileName));
end;

function TStartParamMacro.GetResolvedValue: string;
var
  LFileName: string;
  Lines: TStrings;
  Match: TMatch;
  LLine: Integer;
begin
  case Kind of
    mkValue:
      Result := FOwner.ResolveValue(Self, Value);
    mkFile:
      begin
        LFileName := ResolvedFileName;
        if not FileExists(LFileName) then
          Result := ''
        else
        begin
          Lines := TStringList.Create;
          try
            Lines.LoadFromFile(LFileName);
            LLine := 0;
            if Line <> '' then
              LLine := StrToIntDef(FOwner.ResolveValue(Self, Line), -1);
            if LLine > 0 then
            begin
              if LLine - 1 < Lines.Count then
                Result := Lines[LLine - 1]
              else
                Result := '';
            end
            else
              Result := Lines.Text;
          finally
            Lines.Free;
          end;

          if RegEx <> '' then
          begin
            Match := TRegEx.Match(Result, FOwner.ResolveValue(Self, RegEx));
            if Match.Success then
              Result := Match.Value
            else
              Result := '';
          end;
        end;
      end;
  end;
end;

procedure TStartParamMacro.LoadFromXml(ANode: IXMLNode; AErrors: TStrings);
begin
  inherited LoadFromXml(ANode, AErrors);

  if not ANode.HasAttribute('Name') then
  begin
    AErrors.Add(RsMissingMacroName);
    Exit;
  end;

  FName := ANode.Attributes['Name'];
  FValue := ANode.Text;

  if ANode.HasAttribute('FromFile') then
  begin
    FFileName := ANode.Attributes['FromFile'];
    FKind := mkFile;
    if ANode.HasAttribute('Line') then
      FLine := Trim(ANode.Attributes['Line']);
    if ANode.HasAttribute('RegEx') then
      FRegEx := ANode.Attributes['RegEx'];
  end
  else
  begin
    FKind := mkValue;
    if ANode.AttributeNodes.Count > 1 then
    begin
      if ANode.AttributeNodes.Count = 2 then
      begin
        if not ANode.HasAttribute('Condition') then
          AErrors.Add(RsInvalidMacroAttributes);
      end
      else
        AErrors.Add(RsInvalidMacroAttributes);
    end;
  end;
end;

procedure TStartParamMacro.SaveToXml(ANode: IXmlNode);
begin
  inherited SaveToXml(ANode);
  ANode.Attributes['Name'] := Name;
  if FileName <> '' then
  begin
    ANode.Text := '';
    ANode.Attributes['FormFile'] := FileName;

    if FLine <> '' then
      ANode.Attributes['Line'] := Line
    else
      ANode.Attributes['Line'] := Null;

    if RegEx <> '' then
      ANode.Attributes['RegEx'] := RegEx
    else
      ANode.Attributes['RegEx'] := Null;
  end
  else
  begin
    if ANode.HasAttribute('FromFile') then
    begin
      ANode.Attributes['FormFile'] := Null;
      ANode.Attributes['Line'] := Null;
      ANode.Attributes['RegEx'] := Null;
    end;
    ANode.Text := Value;
  end;
end;

procedure TStartParamMacro.SetFileName(const AValue: string);
begin
  if AValue <> FFileName then
  begin
    FFileName := AValue;
    MarkModified;
  end;
end;

procedure TStartParamMacro.SetKind(const AValue: TStartParamMacroKind);
begin
  if AValue <> FKind then
  begin
    FKind := AValue;
    MarkModified;
  end;
end;

procedure TStartParamMacro.SetLine(const AValue: string);
begin
  if AValue <> FLine then
  begin
    FLine := AValue;
    MarkModified;
  end;
end;

procedure TStartParamMacro.SetName(const AValue: string);
begin
  if Value <> FName then
  begin
    FName := AValue;
    MarkModified;
  end;
end;

procedure TStartParamMacro.SetRegEx(const AValue: string);
begin
  if AValue <> FRegEx then
  begin
    FRegEx := AValue;
    MarkModified;
  end;
end;

procedure TStartParamMacro.SetValue(const AValue: string);
begin
  if AValue <> FValue then
  begin
    FValue := AValue;
    MarkModified;
  end;
end;

{ TStartParam }

function TStartParam.GetResolvedValue: string;
begin
  if not FResolved then
  begin
    FResolved := True;
    FResolvedValue := FOwner.ResolveValue(Self, Value);
  end;
  Result := FResolvedValue
end;

procedure TStartParam.LoadFromXml(ANode: IXMLNode; AErrors: TStrings);
begin
  inherited LoadFromXml(ANode, AErrors);

  if not ANode.HasAttribute('Name') then
  begin
    AErrors.Add(RsMissingParamName);
    Exit;
  end;
  if ANode.AttributeNodes.Count > 1 then
  begin
    if ANode.AttributeNodes.Count = 2 then
    begin
      if not ANode.HasAttribute('Condition') then
        AErrors.Add(RsInvalidParamAttributes);
    end
    else
      AErrors.Add(RsInvalidParamAttributes);
  end;

  FName := ANode.Attributes['Name'];
  FValue := ANode.Text;
end;

procedure TStartParam.SaveToXml(ANode: IXmlNode);
begin
  inherited SaveToXml(ANode);

  ANode.Attributes['Name'] := Name;
  ANode.Text := Value;
end;

procedure TStartParam.SetName(const Value: string);
begin
  if Value <> FName then
  begin
    FName := Value;
    MarkModified;
  end;
end;

procedure TStartParam.SetValue(const AValue: string);
begin
  if AValue <> FValue then
  begin
    FValue := AValue;
    MarkModified;
  end;
end;


{ TStartParamListEnumeration }

constructor TStartParamListEnumeration.Create(AList: TList);
begin
  inherited Create;
  FList := AList;
end;

destructor TStartParamListEnumeration.Destroy;
begin
  FList.Free;
  inherited Destroy;
end;

function TStartParamListEnumeration.GetEnumerator: TStartParamListEnumerator;
begin
  Result := TStartParamListEnumerator.Create(FList);
end;

{ TStartParamListEnumerator }

constructor TStartParamListEnumerator.Create(AList: TList);
begin
  FList := AList;
  FIndex := -1;
end;

function TStartParamListEnumerator.GetCurrent: TStartParam;
begin
  Result := FList[FIndex];
end;

function TStartParamListEnumerator.MoveNext: Boolean;
begin
  Result := FIndex < FList.Count - 1;
  if Result then
    Inc(FIndex);
end;

{ TStartParamList }

constructor TStartParamList.Create(AParent: TStartParamInclude);
begin
  inherited Create;
  FParent := AParent;
  FItems := TObjectList.Create;
end;

destructor TStartParamList.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

procedure TStartParamList.Clear;
begin
  FFileTime := 0;
  FActiveParamName := '';
  if FXmlDoc <> nil then
    FXmlDoc.DocumentElement.ChildNodes.Clear;
  FItems.Clear;
  MarkModified;
end;

procedure TStartParamList.RequireXmlDoc;
begin
  FXmlDoc := NewXMLDocument;
  FXmlDoc.Options := FXmlDoc.Options + [doNodeAutoIndent];
  FXmlDoc.DocumentElement := FXmlDoc.CreateNode('StartParameters');
end;

function TStartParamList.GetActiveParamName: string;
var
  P: TStartParamInclude;
  List: TStartParamList;
begin
  if FActiveParamName <> '' then
  begin
    // Find the parameter in all available lists (the local param list saves the ActiveParamName)
    List := Self;
    P := Parent;
    if P <> nil then
    begin
      while P.Owner.Parent <> nil do
        P := P.Owner.Parent;
      List := P.Owner;
    end;
    if List.FindParam(FActiveParamName) = nil then
      FActiveParamName := '';
  end;
  Result := FActiveParamName;
end;

function TStartParamList.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TStartParamList.GetItem(Index: Integer): TStartParamBase;
begin
  Result := TStartParamBase(FItems[Index]);
end;

procedure TStartParamList.MarkModified;
var
  I: Integer;
begin
  FModified := True;
  for I := 0 to Count - 1 do
    Items[I].FConditionEvalValue := -1;
end;

procedure TStartParamList.CollectParams(AList: TList; AIgnoreCondition: Boolean);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
  begin
    if Items[I] is TStartParam then
    begin
      if TStartParam(Items[I]).Name <> '' then
        if AIgnoreCondition or Items[I].EvalCondition then
          AList.Add(Items[I])
    end
    else if Items[I] is TStartParamInclude then
      if AIgnoreCondition or Items[I].EvalCondition then
        TStartParamInclude(Items[I]).StartParamList.CollectParams(AList, AIgnoreCondition);
  end;
end;

function TStartParamList.AvailableParams(AIgnoreCondition: Boolean = False): TStartParamListEnumeration;
var
  List: TList;
begin
  List := TList.Create;
  try
    CollectParams(List, AIgnoreCondition);
  except
    List.Free;
    raise;
  end;
  Result := TStartParamListEnumeration.Create(List);
end;

function TStartParamList.FindParam(const AParamName: string): TStartParam;
var
  I: Integer;
begin
  for I := Count - 1 downto 0 do // last declaration succeeds
  begin
    if Items[I] is TStartParam then
    begin
      if AnsiSameText(TStartParam(Items[I]).Name, AParamName) then
      begin
        if Items[I].EvalCondition then
        begin
          Result := TStartParam(Items[I]);
          Exit;
        end;
      end;
    end
    else if Items[I] is TStartParamInclude then
    begin
      if Items[I].EvalCondition then
      begin
        Result := TStartParamInclude(Items[I]).StartParamList.FindParam(AParamName);
        if Result <> nil then
          Exit;
      end;
    end;
  end;
  Result := nil;
end;

function TStartParamList.FindIncludeParamList(const AIncludeFileName: string): TStartParamList;
var
  I: Integer;
  Item: TStartParamInclude;
begin
  for I := 0 to Count - 1 do
  begin
    if Items[I] is TStartParamInclude then
    begin
      Item := TStartParamInclude(Items[I]);
      if AnsiSameText(Item.FileName, AIncludeFileName) then
      begin
        Result := Item.StartParamList;
        Exit;
      end;
    end;
  end;
  Result := nil;
end;

function TStartParamList.FindMacro(AStopItem: TStartParamBase; const AMacroName: string): TStartParamMacro;
var
  I: Integer;
  Item: TStartParamBase;
begin
  Result := nil;
  // Find the last matching macro
  for I := 0 to Count - 1 do
  begin
    Item := Items[I];
    if Item = AStopItem then // don't allow self-referencing
      Break;

    if Item is TStartParamMacro then
    begin
      if AnsiSameText(TStartParamMacro(Item).Name, AMacroName) then
        if Item.EvalCondition then
          Result := TStartParamMacro(Item);
    end
    else if Item is TStartParamInclude then
    begin
      Item := TStartParamInclude(Item).StartParamList.FindMacro(nil, AMacroName);
      if Item <> nil then
        Result := TStartParamMacro(Item);
    end;
  end;

  // We want the last matching macro, so it is safe to search in the parent only if nothing was
  // found in this object.
  if (Result = nil) and (Parent <> nil) then
    Result := Parent.Owner.FindMacro(Parent, AMacroName);
end;

function TStartParamList.Reload: Boolean;
var
  NewFileDate: TDateTime;
  I: Integer;
begin
  if FileName <> '' then
  begin
    Result := FileAge(FileName, NewFileDate) and (NewFileDate <> FFileTime);
    if Result then
      LoadFromFile(FFileName)
    else
    begin
      for I := 0 to Count - 1 do
        if Items[I] is TStartParamInclude then
          Result := TStartParamInclude(Items[I]).StartParamList.Reload or Result;
    end;
  end
  else
    Result := False;
end;

function TStartParamList.ResolveValue(AStopItem: TStartParamBase; const AValue: string): string;
// Resolved macros, including built-in and environment variables
var
  I: Integer;
  Start, Len: Integer;
  NewS, S: string;
  Macro: TStartParamMacro;
begin
  Result := AValue;
  Len := Length(Result);
  I := Pos('$', Result);
  if I > 0 then
  begin
    while I <= Len do
    begin
      if (Result[I] = '$') and (I < Len - 1) and (Result[I + 1] = '(') then
      begin
        Start := I;
        while (I <= Len) and (Result[I] <> ')') do
          Inc(I);
        if I <= Len then
        begin
          S := AnsiUpperCase(Copy(Result, Start + 2, I - Start - 2));
          if SameText(S, 'ParamFileName') then
            NewS := FileName
          else if SameText(S, 'ParamFilePath') then
            NewS := ExtractFilePath(FileName)
          else if SameText(S, 'Year') then
            NewS := IntToStr(YearOf(Date))
          else if SameText(S, 'Month') then
            NewS := IntToStr(MonthOf(Date))
          else if SameText(S, 'Day') then
            NewS := IntToStr(DayOf(Date))
          else if SameText(S, 'MonthShortName') then
            NewS := FormatDateTime('mmm', Date)
          else if SameText(S, 'MonthName') then
            NewS := FormatDateTime('mmmm', Date)
          else if SameText(S, 'LastMonthShortName') then
            NewS := FormatDateTime('mmm', IncMonth(Date))
          else if SameText(S, 'LastMonthName') then
            NewS := FormatDateTime('mmmm', IncMonth(Date))
          else if SameText(S, 'LastYear') then
            NewS := IntToStr(YearOf(Date) - 1)
          else
          begin
            Macro := FindMacro(AStopItem, S);
            if Macro <> nil then
              NewS := Macro.ResolvedValue
            else
              NewS := GetEnvironmentVariable(S);
          end;
          Delete(Result, Start, I - Start + 1);
          Insert(NewS, Result, Start);
          Dec(I, Length(S) + 3);
          Inc(I, Length(NewS));
          Len := Length(Result);
        end;
      end;
      Inc(I);
    end;
  end;
end;

procedure TStartParamList.LoadIncludeNode(ANode: IXMLNode; AErrors: TStrings; ARecursionCount: Integer);
var
  LFileName: string;
  IncludeParam: TStartParamInclude;
begin
  IncludeParam := Add(TStartParamInclude.Create(Self)) as TStartParamInclude;
  IncludeParam.LoadFromXml(ANode, AErrors);
  if IncludeParam.FileName <> '' then
  begin
    LFileName := IncludeParam.ResolvedFileName;
    if not FileExists(LFileName) then
    begin
      if IncludeParam.Force then
        AErrors.Add(Format(RsFileNotFound, [LFileName]));
    end
    else
      IncludeParam.StartParamList.InternLoadFromFile(LFileName, ARecursionCount + 1);
  end;
end;

procedure TStartParamList.LoadFromFile(const AFileName: string);
begin
  InternLoadFromFile(AFileName, 0);
end;

procedure TStartParamList.InternLoadFromFile(const AFileName: string; ARecursionCount: Integer);
var
  RootNode, Node: IXMLNode;
  I: Integer;
  NodeName: string;
  Errors: TStrings;
begin
  if ARecursionCount > 30 then
    raise EStartParameterError.CreateRes(@RsMaxIncludeRecursionReached);

  FFileName := '';
  FItems.Clear;
  if FXmlDoc = nil then
    RequireXmlDoc;
  FXmlDoc.Active := False;
  FXmlDoc.LoadFromFile(AFileName);
  FileAge(AFileName, FFileTime);

  RootNode := FXmlDoc.DocumentElement;
  if not SameText(RootNode.NodeName, 'StartParameters') then
  begin
    FXmlDoc.Active := False;
    raise EStartParameterError.CreateResFmt(@RsNotAValidParamFile, [AFileName]);
  end;

  FFileName := ExpandFileName(AFileName);
  FActiveParamName := '';
  if RootNode.HasAttribute('ActiveParam') then
    FActiveParamName := RootNode.Attributes['ActiveParam'];

  Errors := TStringList.Create;
  try
    for I := 0 to RootNode.ChildNodes.Count - 1 do
    begin
      Node := RootNode.ChildNodes[I];
      if Node.NodeType = ntElement then
      begin
        NodeName := Node.NodeName;
        if SameText(NodeName, 'Include') then
          LoadIncludeNode(Node, Errors, ARecursionCount)
        else if SameText(NodeName, 'Macro') then
          Add(TStartParamMacro.Create(Self)).LoadFromXml(Node, Errors)
        else if SameText(NodeName, 'Param') then
          Add(TStartParam.Create(Self)).LoadFromXml(Node, Errors);
      end;
    end;
    if Errors.Count > 0 then
      raise EStartParameterError.CreateResFmt(@RsLoadError, [FileName, Trim(Errors.Text)]);
  finally
    Errors.Free;
  end;

  FModified := False;
end;

procedure TStartParamList.Save;
begin
  if FFileName = '' then
  begin
    if Parent <> nil then
      SaveToFile(Parent.ResolvedFileName)
    else
      raise EStartParameterError.CreateRes(@RsNoFileNameSet);
  end
  else
    SaveToFile(FFileName);
end;

procedure TStartParamList.SaveToFile(const AFileName: string);
var
  NodeIndex: Integer;

  function GetItemNode(RootNode: IXMLNode; Item: TStartParamBase; const NodeName: string): IXMLNode;
  begin
    Result := Item.FNode;
    if Result = nil then
    begin
      Result := FXmlDoc.CreateNode('Include');
      RootNode.ChildNodes.Insert(NodeIndex, Result);
      Inc(NodeIndex);
    end
    else
      NodeIndex := RootNode.ChildNodes.IndexOf(Result) + 1;
  end;

var
  I: Integer;
  Item: TStartParamBase;
  RootNode: IXMLNode;
begin
  if (FXmlDoc = nil) or not FXmlDoc.Active then
  begin
    FXmlDoc := nil;
    RequireXmlDoc;
  end;
  RootNode := FXmlDoc.DocumentElement;

  if FActiveParamName <> '' then
    RootNode.Attributes['ActiveParam'] := FActiveParamName
  else
    RootNode.Attributes['ActiveParam'] := Null;

  NodeIndex := 0;
  for I := 0 to Count - 1 do
  begin
    Item := Items[I];
    if Item is TStartParamInclude then
      Item.SaveToXml(GetItemNode(RootNode, Item, 'Include'))
    else if Item is TStartParamMacro then
      Item.SaveToXml(GetItemNode(RootNode, Item, 'Macro'))
    else if Item is TStartParam then
      Item.SaveToXml(GetItemNode(RootNode, Item, 'Param'));
  end;
  FXmlDoc.SaveToFile(AFileName);
  FileAge(AFileName, FFileTime);
  FModified := False;
end;

procedure TStartParamList.DeleteNode(Node: IXMLNode);

  function IsBlankString(const S: string): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    for I := 1 to Length(S) do
      if S[I] > #32 then
        Exit;
    Result := True;
  end;

var
  ParentNode: IXMLNode;
  Index: Integer;
begin
  ParentNode := Node.ParentNode;
  Index := ParentNode.ChildNodes.IndexOf(Node);
  if Index <> -1 then
  begin
    ParentNode.ChildNodes.Delete(Index);

    // delete the indention
    if Index - 1 >= 0 then
      if (ParentNode.ChildNodes.Get(Index - 1).NodeType = ntText) and
         IsBlankString(ParentNode.ChildNodes.Get(Index - 1).Text) then
        ParentNode.ChildNodes.Delete(Index - 1);

    // delete the line break and parent indention
    if Index - 2 >= 0 then
      if (ParentNode.ChildNodes.Get(Index - 2).NodeType = ntText) and
         IsBlankString(ParentNode.ChildNodes.Get(Index - 2).Text) then
        ParentNode.ChildNodes.Delete(Index - 2);
    // if the section is empty we still have a linebreak + parent indention
    if (ParentNode.ChildNodes.Count = 1) and (ParentNode.ChildNodes.Get(0).NodeType = ntText) and
       IsBlankString(ParentNode.ChildNodes.Get(0).Text) then
      ParentNode.ChildNodes.Clear;
  end;
end;

procedure TStartParamList.SetActiveParamName(const AValue: string);
begin
  if AValue <> FActiveParamName then
  begin
    FActiveParamName := AValue;
    MarkModified;
  end;
end;

function TStartParamList.Add(AItem: TStartParamBase): TStartParamBase;
begin
  Result := AItem;
  FItems.Add(Result);
end;

function TStartParamList.AddInclude(const AIncludeFileName: string;
  AForceInclude: Boolean): TStartParamInclude;
var
  ParamList: TStartParamList;
begin
  ParamList := FindIncludeParamList(AIncludeFileName);
  Result := nil;
  if ParamList <> nil then
    Result := ParamList.Parent;
  if Result = nil then
    Result := Add(TStartParamInclude.Create(Self)) as TStartParamInclude;
  Result.FileName := AIncludeFileName;
  Result.Force := AForceInclude;
end;

end.

