{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit DeadCodeDetector;

/// <summary>
/// Implements the Dead Code Detector DDevExtensions plugin: collects all declared
/// procedures, functions and class fields across a project, then scans every unit's
/// implementation section for references and reports symbols that appear to be unused.
/// </summary>
/// <remarks>
/// Detection is heuristic. Published members, virtual / override / abstract methods,
/// constructors / destructors and event-handler-shaped methods are ignored, as are
/// symbols matching user-supplied wildcard patterns.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Generics.Collections, Menus, Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main;

type
  /// <summary>One reported dead-code finding.</summary>
  TDeadCodeItem = record
    /// <summary>Full path of the file containing the symbol.</summary>
    FileName: string;
    /// <summary>Unit name (without extension).</summary>
    UnitName: string;
    /// <summary>Source line of the declaration.</summary>
    Line: Integer;
    /// <summary>Kind of symbol: "Procedure", "Function", "Constructor", "Destructor" or "Field".</summary>
    ElementType: string;
    /// <summary>Name of the symbol (qualified with the class name when applicable).</summary>
    ElementName: string;
    /// <summary>Visibility / placement: "private", "protected", "public", "published", "unit" or "interface".</summary>
    Scope: string;
    /// <summary>Reason for reporting (currently always "Never referenced").</summary>
    Reason: string;
  end;

  /// <summary>
  /// Mutable record describing a single declared symbol gathered during phase 1
  /// and updated during the reference-scanning phase.
  /// </summary>
  TSymbolInfo = class
  public
    /// <summary>Identifier name as declared in the source.</summary>
    Name: string;
    /// <summary>Full path of the declaring file.</summary>
    FileName: string;
    /// <summary>Unit name (without extension).</summary>
    UnitName: string;
    /// <summary>Source line of the declaration.</summary>
    Line: Integer;
    /// <summary>Kind of symbol (see <see cref="TDeadCodeItem.ElementType"/>).</summary>
    ElementType: string;
    /// <summary>Visibility / placement (see <see cref="TDeadCodeItem.Scope"/>).</summary>
    Scope: string;
    /// <summary>Set during the reference-scanning phase when at least one reference is found.</summary>
    IsReferenced: Boolean;
    /// <summary>True when the method has the virtual directive.</summary>
    IsVirtual: Boolean;
    /// <summary>True when the method has the override directive.</summary>
    IsOverride: Boolean;
    /// <summary>True when the method has the abstract directive.</summary>
    IsAbstract: Boolean;
    /// <summary>True when the symbol is in a published section (used by RTTI/DFM streaming).</summary>
    IsPublished: Boolean;
    /// <summary>True when the symbol is a constructor.</summary>
    IsConstructor: Boolean;
    /// <summary>True when the symbol is a destructor.</summary>
    IsDestructor: Boolean;
    /// <summary>True when the parameter list resembles a VCL event handler (has Sender: TObject).</summary>
    IsEventHandler: Boolean;
    /// <summary>For methods, the name of the owning class.</summary>
    ClassName: string;
  end;

  /// <summary>
  /// Two-pass project analyser that collects symbols, then scans for references and
  /// reports unreferenced (and non-ignored) ones as dead code.
  /// </summary>
  TDeadCodeAnalyzer = class
  private
    /// <summary>All symbols collected during phase 1 (owned).</summary>
    FSymbols: TObjectList<TSymbolInfo>;
    /// <summary>Backing field for <see cref="ProgressFileName"/>.</summary>
    FProgressFileName: string;
    /// <summary>User-supplied wildcard ignore patterns.</summary>
    FIgnorePatterns: TStringList;
    /// <summary>Lexes the file and adds every declared procedure, function and qualifying field to <see cref="FSymbols"/>.</summary>
    procedure CollectSymbols( const FileName: string; const Content: UTF8String );
    /// <summary>Lexes the file's implementation section and marks any matching symbols as referenced.</summary>
    procedure ScanForReferences( const FileName: string; const Content: UTF8String );
    /// <summary>Returns True when the symbol should be excluded from the report (published, polymorphic, ignored pattern, ...).</summary>
    function ShouldIgnore( const Symbol: TSymbolInfo ): Boolean;
    /// <summary>Returns True when the parameter text contains "Sender" and "TObject" - a heuristic for VCL event handlers.</summary>
    function IsEventHandlerSignature( const Params: string ): Boolean;
  public
    /// <summary>Creates a new analyser with empty state.</summary>
    constructor Create;
    /// <summary>Releases all owned resources.</summary>
    destructor Destroy; override;
    /// <summary>Discards all collected symbols.</summary>
    procedure ClearSymbols;
    /// <summary>Adds an ignore pattern. Patterns may use a leading or trailing '*' wildcard.</summary>
    procedure AddIgnorePattern( const Pattern: string );
    /// <summary>Runs the full two-pass analysis on a project.</summary>
    /// <param name="Project">The active project to analyse.</param>
    /// <param name="DeadCode">Receives the list of unreferenced symbols.</param>
    /// <param name="OnProgress">Optional progress callback (read <see cref="ProgressFileName"/> for the current step).</param>
    /// <returns>True on success.</returns>
    function AnalyzeProject( const Project: IOTAProject; out DeadCode: TArray<TDeadCodeItem>;
      OnProgress: TNotifyEvent ): Boolean;
    /// <summary>Description of the current step (e.g. "Collecting: Foo.pas").</summary>
    property ProgressFileName: string read FProgressFileName;
  end;

  /// <summary>
  /// Plugin host: registers the menu item and owns the persistent options including
  /// the user-editable ignore list of name patterns.
  /// </summary>
  TDeadCodeDetectorPlugin = class( TPluginConfig )
  private
    /// <summary>Backing field for <see cref="Enabled"/>.</summary>
    FEnabled: Boolean;
    /// <summary>Backing field for <see cref="CheckProcedures"/>.</summary>
    FCheckProcedures: Boolean;
    /// <summary>Backing field for <see cref="CheckFields"/>.</summary>
    FCheckFields: Boolean;
    /// <summary>Wildcard ignore patterns, applied to symbol names.</summary>
    FIgnoreList: TStringList;
    /// <summary>Owned menu item under the DDevExtensions submenu.</summary>
    FMenuItem: TMenuItem;
    /// <summary>Menu click handler that opens the detector form.</summary>
    procedure MenuItemClick( Sender: TObject );
    /// <summary>Property setter for the comma-text serialised ignore list.</summary>
    procedure SetIgnoreListText( const Value: string );
    /// <summary>Property getter for the comma-text serialised ignore list.</summary>
    function GetIgnoreListText: string;
  protected
    /// <summary>Returns the IDE Tools options page for this plugin.</summary>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises default option values and seeds the ignore list.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the plugin, the ignore list and the menu item.</summary>
    constructor Create;
    /// <summary>Releases the menu item and the ignore list.</summary>
    destructor Destroy; override;
    /// <summary>Opens (or focuses) the Dead Code Detector form.</summary>
    procedure ShowDetector;
    /// <summary>Read-only access to the ignore list.</summary>
    property IgnoreList: TStringList read FIgnoreList;
  published
    /// <summary>Whether the plugin's features are enabled.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
    /// <summary>Whether the analyser inspects procedures, functions and methods.</summary>
    property CheckProcedures: Boolean read FCheckProcedures write FCheckProcedures;
    /// <summary>Whether the analyser inspects private and protected fields.</summary>
    property CheckFields: Boolean read FCheckFields write FCheckFields;
    /// <summary>Comma-text serialisation of the ignore list (used by the configuration storage).</summary>
    property IgnoreListText: string read GetIgnoreListText write SetIgnoreListText;
  end;

/// <summary>Plugin entry point invoked by the IDE host to load or unload the plugin singleton.</summary>
/// <param name="Unload">When True the plugin is unloaded; otherwise it is loaded.</param>
procedure InitPlugin( Unload: Boolean );

var
  /// <summary>Singleton instance of the Dead Code Detector plugin.</summary>
  DeadCodeDetectorPlugin: TDeadCodeDetectorPlugin;

implementation

uses
  Forms, Controls, ToolsAPIHelpers, AppConsts, DelphiLexer,
  FrmDeadCodeDetector, FrmeOptionPageDeadCode;

{ TDeadCodeAnalyzer }

constructor TDeadCodeAnalyzer.Create;
begin

  inherited Create;
  FSymbols        := TObjectList<TSymbolInfo>.Create( True );
  FIgnorePatterns := TStringList.Create;
  FIgnorePatterns.CaseSensitive := False;

end;

destructor TDeadCodeAnalyzer.Destroy;
begin

  FIgnorePatterns.Free;
  FSymbols.Free;
  inherited Destroy;

end;

procedure TDeadCodeAnalyzer.ClearSymbols;
begin

  FSymbols.Clear;

end;

procedure TDeadCodeAnalyzer.AddIgnorePattern( const Pattern: string );
begin

  if Trim( Pattern ) <> '' then
    FIgnorePatterns.Add( Trim( Pattern ) );

end;

function TDeadCodeAnalyzer.IsEventHandlerSignature( const Params: string ): Boolean;
begin

  // Common event handler patterns
  Result := ( Pos( 'SENDER', UpperCase( Params ) ) > 0 ) and
            ( Pos( 'TOBJECT', UpperCase( Params ) ) > 0 );

end;

function TDeadCodeAnalyzer.ShouldIgnore( const Symbol: TSymbolInfo ): Boolean;
var
  I: Integer;
  Pattern: string;
begin

  Result := False;

  // Published members are used by RTTI
  if Symbol.IsPublished then
    Exit( True );

  // Virtual/override/abstract methods may be called polymorphically
  if Symbol.IsVirtual or Symbol.IsOverride or Symbol.IsAbstract then
    Exit( True );

  // Constructors and destructors are special
  if Symbol.IsConstructor or Symbol.IsDestructor then
    Exit( True );

  // Event handlers are typically assigned at design time
  if Symbol.IsEventHandler then
    Exit( True );

  // Check user-defined ignore patterns
  for I := 0 to FIgnorePatterns.Count - 1 do
  begin
    Pattern := FIgnorePatterns[ I ];

    // Simple wildcard matching
    if ( Pattern <> '' ) then
    begin
      if Pattern[ 1 ] = '*' then
      begin
        // *suffix matching
        if SameText( Copy( Symbol.Name, Length( Symbol.Name ) - Length( Pattern ) + 2, MaxInt ),
                     Copy( Pattern, 2, MaxInt ) ) then
          Exit( True );
      end
      else if Pattern[ Length( Pattern ) ] = '*' then
      begin
        // prefix* matching
        if SameText( Copy( Symbol.Name, 1, Length( Pattern ) - 1 ),
                     Copy( Pattern, 1, Length( Pattern ) - 1 ) ) then
          Exit( True );
      end
      else
      begin
        // Exact match
        if SameText( Symbol.Name, Pattern ) then
          Exit( True );
      end;
    end;
  end;

end;

procedure TDeadCodeAnalyzer.CollectSymbols( const FileName: string; const Content: UTF8String );
var
  Lexer: TDelphiLexer;
  Token: TToken;
  PrevTokenKind: TTokenKind;
  Symbol: TSymbolInfo;
  UnitName: string;
  InImplementation: Boolean;
  InType, InClass, InRecord: Boolean;
  InPrivate, InProtected, InPublic, InPublished: Boolean;
  CurrentClassName: string;
  ParenDepth: Integer;
  ParamText: string;
  IsFunction: Boolean;
  CheckProcedures, CheckFields: Boolean;
  FieldName: string;
  FieldLine: Integer;
begin

  // Get settings from plugin
  if DeadCodeDetectorPlugin <> nil then
  begin
    CheckProcedures := DeadCodeDetectorPlugin.CheckProcedures;
    CheckFields     := DeadCodeDetectorPlugin.CheckFields;
  end
  else
  begin
    CheckProcedures := True;
    CheckFields     := True;
  end;

  UnitName         := ChangeFileExt( ExtractFileName( FileName ), '' );
  InImplementation := False;
  InType           := False;
  InClass          := False;
  InRecord         := False;
  InPrivate        := False;
  InProtected      := False;
  InPublic         := False;
  InPublished      := False;
  CurrentClassName := '';

  Lexer := TDelphiLexer.Create( FileName, Content );

  try
    PrevTokenKind := tkNone;

    while Lexer.NextToken( Token ) do
    begin
      // Track section
      if Token.Kind = tkI_implementation then
      begin
        InImplementation := True;
        InType           := False;
        InClass          := False;
        InRecord         := False;
      end;

      // Track type section
      if Token.Kind = tkI_type then
      begin
        InType   := True;
        InClass  := False;
        InRecord := False;
      end
      else if Token.Kind in [ tkI_var, tkI_const, tkI_begin ] then
      begin
        if not InClass and not InRecord then
          InType := False;
      end;

      // Track class/record
      if Token.Kind = tkI_class then
      begin
        if InType and ( PrevTokenKind = tkEqual ) then
        begin
          InClass     := True;
          InRecord    := False;
          // Don't assume private - the implicit section before any visibility
          // keyword is "published" for forms/components (used by DFM streaming).
          // Only collect fields after an explicit private/protected keyword.
          InPrivate   := False;
          InProtected := False;
          InPublic    := False;
          InPublished := False;
        end;
      end
      else if Token.Kind = tkI_record then
      begin
        if InType and ( PrevTokenKind = tkEqual ) then
        begin
          InRecord := True;
          InClass  := False;
        end;
      end
      else if Token.Kind = tkI_end then
      begin
        if InClass or InRecord then
        begin
          InClass     := False;
          InRecord    := False;
          InPrivate   := False;
          InProtected := False;
          InPublic    := False;
          InPublished := False;
        end;
      end;

      // Track class name - only when NOT already inside a class
      // (prevents type names like Boolean from overwriting the class name)
      if InType and not InClass and ( Token.Kind = tkIdent ) and ( PrevTokenKind in [ tkNone, tkSemicolon, tkI_type ] ) then
      begin
        CurrentClassName := Token.Value;
      end;

      // Track visibility
      if InClass then
      begin
        if Token.Kind = tkI_private then
        begin
          InPrivate := True; InProtected := False; InPublic := False; InPublished := False;
        end
        else if Token.Kind = tkI_protected then
        begin
          InPrivate := False; InProtected := True; InPublic := False; InPublished := False;
        end
        else if Token.Kind = tkI_public then
        begin
          InPrivate := False; InProtected := False; InPublic := True; InPublished := False;
        end
        else if Token.Kind = tkI_published then
        begin
          InPrivate := False; InProtected := False; InPublic := False; InPublished := True;
        end;
      end;

      // Collect private/protected fields in classes
      if CheckFields and InClass and ( InPrivate or InProtected ) and ( Token.Kind = tkIdent ) then
      begin
        // Save the field name and line BEFORE advancing to check for colon
        FieldName := Token.Value;
        FieldLine := Token.Line;

        // Check if this is a field declaration (followed by :)
        if Lexer.NextToken( Token ) and ( Token.Kind = tkColon ) then
        begin
          Symbol                := TSymbolInfo.Create;
          Symbol.Name           := FieldName;
          Symbol.FileName       := FileName;
          Symbol.UnitName       := UnitName;
          Symbol.Line           := FieldLine;
          Symbol.ElementType    := 'Field';
          Symbol.ClassName      := CurrentClassName;
          Symbol.IsReferenced   := False;
          Symbol.IsPublished    := InPublished;

          if InPrivate then
            Symbol.Scope := 'private'
          else if InProtected then
            Symbol.Scope := 'protected'
          else if InPublic then
            Symbol.Scope := 'public'
          else
            Symbol.Scope := 'private';

          FSymbols.Add( Symbol );
        end;

        // Continue with next token
        Continue;
      end;

      // Collect procedures/functions
      if CheckProcedures and ( Token.Kind in [ tkI_procedure, tkI_function, tkI_constructor, tkI_destructor ] ) then
      begin
        IsFunction := Token.Kind = tkI_function;

        // Get the method/procedure name
        if Lexer.NextToken( Token ) and ( Token.Kind = tkIdent ) then
        begin
          Symbol              := TSymbolInfo.Create;
          Symbol.Name         := Token.Value;
          Symbol.FileName     := FileName;
          Symbol.UnitName     := UnitName;
          Symbol.Line         := Token.Line;
          Symbol.ClassName    := '';
          Symbol.IsReferenced := False;
          Symbol.IsVirtual    := False;
          Symbol.IsOverride   := False;
          Symbol.IsAbstract   := False;
          Symbol.IsPublished  := InPublished;
          Symbol.IsConstructor := PrevTokenKind = tkI_constructor;
          Symbol.IsDestructor  := PrevTokenKind = tkI_destructor;

          if IsFunction then
            Symbol.ElementType := 'Function'
          else if Symbol.IsConstructor then
            Symbol.ElementType := 'Constructor'
          else if Symbol.IsDestructor then
            Symbol.ElementType := 'Destructor'
          else
            Symbol.ElementType := 'Procedure';

          // Check for class method (ClassName.MethodName)
          if Lexer.NextToken( Token ) and ( Token.Kind = tkQualifier ) then
          begin
            // This is an implementation of a class method - skip it for now
            Symbol.Free;
            Continue;
          end;

          // Determine scope
          if InImplementation then
            Symbol.Scope := 'unit'
          else if InClass then
          begin
            if InPrivate then
              Symbol.Scope := 'private'
            else if InProtected then
              Symbol.Scope := 'protected'
            else if InPublic then
              Symbol.Scope := 'public'
            else if InPublished then
              Symbol.Scope := 'published'
            else
              Symbol.Scope := 'private';

            Symbol.ClassName := CurrentClassName;
          end
          else
            Symbol.Scope := 'interface';

          // Collect parameters to check for event handler signature
          ParamText := '';

          if Token.Kind = tkLParan then
          begin
            ParenDepth := 1;

            while Lexer.NextToken( Token ) and ( ParenDepth > 0 ) do
            begin
              if Token.Kind = tkLParan then
                Inc( ParenDepth )
              else if Token.Kind = tkRParan then
                Dec( ParenDepth );

              ParamText := ParamText + Token.Value + ' ';
            end;
          end;

          Symbol.IsEventHandler := IsEventHandlerSignature( ParamText );

          // Look for virtual/override/abstract directives
          while Lexer.NextToken( Token ) and ( Token.Kind <> tkSemicolon ) do
          begin
            if Token.Kind = tkI_virtual then
              Symbol.IsVirtual := True
            else if Token.Kind = tkI_override then
              Symbol.IsOverride := True
            else if Token.Kind = tkI_abstract then
              Symbol.IsAbstract := True;
          end;

          FSymbols.Add( Symbol );
        end;
      end;

      PrevTokenKind := Token.Kind;
    end;
  finally
    Lexer.Free;
  end;

end;

procedure TDeadCodeAnalyzer.ScanForReferences( const FileName: string; const Content: UTF8String );
var
  Lexer: TDelphiLexer;
  Token: TToken;
  PrevTokenKind: TTokenKind;
  I: Integer;
  Symbol: TSymbolInfo;
  InImplementation: Boolean;
  TokenValue: string;
begin

  InImplementation := False;

  Lexer := TDelphiLexer.Create( FileName, Content );

  try
    PrevTokenKind := tkNone;

    while Lexer.NextToken( Token ) do
    begin
      if Token.Kind = tkI_implementation then
        InImplementation := True;

      // Only look at identifiers in implementation section
      if InImplementation and ( Token.Kind = tkIdent ) then
      begin
        TokenValue := Token.Value;

        // Check against all symbols
        for I := 0 to FSymbols.Count - 1 do
        begin
          Symbol := FSymbols[ I ];

          if not Symbol.IsReferenced and SameText( Symbol.Name, TokenValue ) then
          begin
            // Don't count the declaration itself
            if ( Symbol.FileName <> FileName ) or ( Symbol.Line <> Token.Line ) then
            begin
              // Check for qualified reference (ClassName.MethodName or Self.FieldName)
              if ( PrevTokenKind = tkQualifier ) or
                 ( ( Symbol.ElementType <> 'Field' ) and ( Symbol.Scope = 'unit' ) ) then
              begin
                Symbol.IsReferenced := True;
              end
              else if Symbol.ElementType = 'Field' then
              begin
                // For fields, we're more lenient - any matching identifier counts
                Symbol.IsReferenced := True;
              end
              else
              begin
                // For procedures/functions in interface, they must be called
                Symbol.IsReferenced := True;
              end;
            end;
          end;
        end;
      end;

      PrevTokenKind := Token.Kind;
    end;
  finally
    Lexer.Free;
  end;

end;

function TDeadCodeAnalyzer.AnalyzeProject( const Project: IOTAProject;
  out DeadCode: TArray<TDeadCodeItem>; OnProgress: TNotifyEvent ): Boolean;
var
  I: Integer;
  ModuleInfo: IOTAModuleInfo;
  FileName: string;
  Content: UTF8String;
  FileContents: TDictionary<string, UTF8String>;
  Symbol: TSymbolInfo;
  DeadCodeList: TList<TDeadCodeItem>;
  Item: TDeadCodeItem;
begin

  Result := False;
  SetLength( DeadCode, 0 );

  if Project = nil then
    Exit;

  ClearSymbols;
  FileContents := TDictionary<string, UTF8String>.Create;

  try
    // Phase 1: Load all files and collect symbols
    for I := 0 to Project.GetModuleCount - 1 do
    begin
      ModuleInfo := Project.GetModule( I );
      FileName   := ModuleInfo.FileName;

      if SameText( ExtractFileExt( FileName ), '.pas' ) then
      begin

        if Assigned( OnProgress ) then
        begin
          FProgressFileName := 'Collecting: ' + ExtractFileName( FileName );
          OnProgress( Self );
        end;

        try
          Content := LoadTextFileToUtf8String( FileName );
          FileContents.Add( FileName, Content );
          CollectSymbols( FileName, Content );
        except
          // Skip files that can't be read
        end;
      end;
    end;

    // Phase 2: Scan for references in all files
    for I := 0 to Project.GetModuleCount - 1 do
    begin
      ModuleInfo := Project.GetModule( I );
      FileName   := ModuleInfo.FileName;

      if FileContents.TryGetValue( FileName, Content ) then
      begin

        if Assigned( OnProgress ) then
        begin
          FProgressFileName := 'Scanning: ' + ExtractFileName( FileName );
          OnProgress( Self );
        end;

        ScanForReferences( FileName, Content );
      end;
    end;

    // Phase 3: Report unreferenced symbols
    DeadCodeList := TList<TDeadCodeItem>.Create;

    try

      for Symbol in FSymbols do
      begin
        if not Symbol.IsReferenced and not ShouldIgnore( Symbol ) then
        begin
          Item.FileName    := Symbol.FileName;
          Item.UnitName    := Symbol.UnitName;
          Item.Line        := Symbol.Line;
          Item.ElementType := Symbol.ElementType;
          Item.ElementName := Symbol.Name;
          Item.Scope       := Symbol.Scope;
          Item.Reason      := 'Never referenced';

          if Symbol.ClassName <> '' then
            Item.ElementName := Symbol.ClassName + '.' + Symbol.Name;

          DeadCodeList.Add( Item );
        end;
      end;

      DeadCode := DeadCodeList.ToArray;
      Result   := True;
    finally
      DeadCodeList.Free;
    end;
  finally
    FileContents.Free;
  end;

end;

{ TDeadCodeDetectorPlugin }

constructor TDeadCodeDetectorPlugin.Create;
begin

  FIgnoreList                := TStringList.Create;
  FIgnoreList.CaseSensitive  := False;

  inherited Create( AppDataDirectory + '\DeadCodeDetector.xml', 'DeadCodeDetector' );

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem         := TMenuItem.Create( DDevExtensionsMenu );
    FMenuItem.Caption := '&Dead Code Detector...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add( FMenuItem );
  end;

end;

destructor TDeadCodeDetectorPlugin.Destroy;
begin

  FreeAndNil( FMenuItem );
  FreeAndNil( FIgnoreList );
  inherited Destroy;

end;

procedure TDeadCodeDetectorPlugin.Init;
begin

  FEnabled         := True;
  FCheckProcedures := True;
  FCheckFields     := True;

  // Default ignore patterns
  FIgnoreList.Add( 'Create' );
  FIgnoreList.Add( 'Destroy' );
  FIgnoreList.Add( 'Initialize' );
  FIgnoreList.Add( 'Finalize' );
  FIgnoreList.Add( '*Click' );
  FIgnoreList.Add( '*Changed' );
  FIgnoreList.Add( '*Execute' );
  FIgnoreList.Add( '*Update' );

end;

function TDeadCodeDetectorPlugin.GetIgnoreListText: string;
begin

  Result := FIgnoreList.CommaText;

end;

procedure TDeadCodeDetectorPlugin.SetIgnoreListText( const Value: string );
begin

  FIgnoreList.CommaText := Value;

end;

function TDeadCodeDetectorPlugin.GetOptionPages: TTreePage;
begin

  Result := TTreePage.Create( 'Dead Code Detector', TFrameOptionPageDeadCode, Self );

end;

procedure TDeadCodeDetectorPlugin.MenuItemClick( Sender: TObject );
begin

  ShowDetector;

end;

procedure TDeadCodeDetectorPlugin.ShowDetector;
begin

  TFormDeadCodeDetector.Execute;

end;

procedure InitPlugin( Unload: Boolean );
begin

  if not Unload then
    DeadCodeDetectorPlugin := TDeadCodeDetectorPlugin.Create
  else
  begin
    DeadCodeDetectorPlugin.Free;
    DeadCodeDetectorPlugin := nil;
  end;

end;

end.
