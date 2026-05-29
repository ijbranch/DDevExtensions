{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit CodeQualityAnalyzer;

/// <summary>
/// DDevExtensions plugin that lexes Pascal sources and detects common code-quality issues —
/// magic numbers, hardcoded strings, commented-out code, suspicious exception handlers, and
/// constructor calls without matching try/finally protection. Results are surfaced via a
/// dedicated form and persisted via <see cref="TPluginConfig"/>.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  SysUtils, Classes, Menus, ToolsAPI, PluginConfig, FrmTreePages,
  Generics.Collections;

type
  /// <summary>Category of code-quality issue produced by the analyser.</summary>
  TIssueCategory = (
    /// <summary>Numeric literal that should be a named constant.</summary>
    icMagicNumber,
    /// <summary>String literal that should be a resource or constant.</summary>
    icHardcodedString,
    /// <summary>Block of comment text that resembles real source code.</summary>
    icCommentedCode,
    /// <summary>Empty <c>except</c> block that silently swallows exceptions.</summary>
    icEmptyExcept,
    /// <summary>Generic <c>except</c> block with no <c>on E:</c> clause.</summary>
    icCatchAllException,
    /// <summary>Constructor call without try/finally protection.</summary>
    icMissingTryFinally,
    /// <summary>Suspected memory leak (reserved for future use).</summary>
    icMemoryLeak
  );

  /// <summary>Severity classification for a <see cref="TCodeQualityIssue"/>.</summary>
  TIssueSeverity = (
    /// <summary>Informational note.</summary>
    isInfo,
    /// <summary>Warning that should be addressed.</summary>
    isWarning,
    /// <summary>Error-level finding.</summary>
    isError
  );

  /// <summary>Detected issue with full source location and supporting metadata.</summary>
  TCodeQualityIssue = record
    /// <summary>Absolute path of the file containing the issue.</summary>
    FileName: string;
    /// <summary>Bare unit name for display.</summary>
    UnitName: string;
    /// <summary>One-based line number.</summary>
    Line: Integer;
    /// <summary>Column number reported by the lexer.</summary>
    Column: Integer;
    /// <summary>Issue category.</summary>
    Category: TIssueCategory;
    /// <summary>Issue severity.</summary>
    Severity: TIssueSeverity;
    /// <summary>Human-readable description of the issue.</summary>
    Description: string;
    /// <summary>Snippet from the source illustrating the issue.</summary>
    CodePreview: string;
  end;

  /// <summary>
  /// Plugin host integrating the Code Quality Analyzer into the DDevExtensions menu and storing
  /// its persistent configuration. Provides the static <see cref="AnalyzeUnit"/> entry point.
  /// </summary>
  TCodeQualityAnalyzerPlugin = class( TPluginConfig )
  private
    /// <summary>Menu item added to the DDevExtensions submenu.</summary>
    FMenuItem: TMenuItem;
    /// <summary>Master enable flag for the plugin.</summary>
    FEnabled: Boolean;

    // Magic Numbers
    /// <summary>Whether magic-number detection is active.</summary>
    FCheckMagicNumbers: Boolean;
    /// <summary>Comma-separated list of literal values exempt from the magic-number check.</summary>
    FMagicNumberWhitelist: string;
    /// <summary>When set, numeric literals used as array indices are exempt.</summary>
    FAllowMagicInArrayIndex: Boolean;

    // Hardcoded Strings
    /// <summary>Whether hardcoded-string detection is active.</summary>
    FCheckHardcodedStrings: Boolean;
    /// <summary>Minimum string length that triggers a finding.</summary>
    FMinStringLength: Integer;
    /// <summary>When set, format strings (containing <c>%s</c>, <c>%d</c>, ...) are exempt.</summary>
    FExcludeFormatStrings: Boolean;
    /// <summary>When set, strings containing SQL keywords are exempt.</summary>
    FExcludeSQLKeywords: Boolean;

    // Commented-Out Code
    /// <summary>Whether commented-out-code detection is active.</summary>
    FCheckCommentedCode: Boolean;
    /// <summary>Heuristic score threshold above which a comment is reported.</summary>
    FCommentCodeThreshold: Integer;

    // Exception Handling
    /// <summary>Whether empty-except detection is active.</summary>
    FCheckEmptyExcept: Boolean;
    /// <summary>Whether catch-all-exception detection is active.</summary>
    FCheckCatchAllException: Boolean;

    // Memory Management
    /// <summary>Whether constructor-without-try/finally detection is active.</summary>
    FCheckMissingTryFinally: Boolean;
    /// <summary>Whether memory-leak detection is active (reserved).</summary>
    FCheckMemoryLeaks: Boolean;
    /// <summary>Comma-separated patterns excluded from the memory-leak check.</summary>
    FMemoryLeakIgnorePatterns: string;

    /// <summary>Menu OnClick handler that launches the analyser form.</summary>
    procedure MenuItemClick( Sender: TObject );
  protected
    /// <summary>Returns the option page representing this plugin in the IDE options dialog.</summary>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises configuration to its built-in defaults.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the plugin and registers its menu item.</summary>
    constructor Create;
    /// <summary>Removes the menu item and releases the plugin.</summary>
    destructor Destroy; override;

    /// <summary>
    /// Tokenises <paramref name="Source"/> with the Delphi lexer and returns every issue detected
    /// according to the configuration in <paramref name="Plugin"/>.
    /// </summary>
    /// <param name="Source">UTF-8 source text to analyse.</param>
    /// <param name="FileName">Absolute path of the source file (used for report metadata).</param>
    /// <param name="Plugin">Configuration container that controls which checks run.</param>
    /// <returns>Array of <see cref="TCodeQualityIssue"/> values; empty when no issues are found.</returns>
    class function AnalyzeUnit( const Source: UTF8String; const FileName: string;
      Plugin: TCodeQualityAnalyzerPlugin ): TArray<TCodeQualityIssue>;

    /// <summary>Splits <see cref="MagicNumberWhitelist"/> into its individual values.</summary>
    function GetMagicNumberWhitelistArray: TArray<string>;
    /// <summary>Splits <see cref="MemoryLeakIgnorePatterns"/> into its individual values.</summary>
    function GetMemoryLeakIgnorePatternsArray: TArray<string>;
  published
    /// <summary>Persisted master enable flag.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;

    /// <summary>Persisted state of the magic-number check.</summary>
    property CheckMagicNumbers: Boolean read FCheckMagicNumbers write FCheckMagicNumbers;
    /// <summary>Persisted comma-separated whitelist of allowed literals.</summary>
    property MagicNumberWhitelist: string read FMagicNumberWhitelist write FMagicNumberWhitelist;
    /// <summary>Persisted toggle exempting array-index literals.</summary>
    property AllowMagicInArrayIndex: Boolean read FAllowMagicInArrayIndex write FAllowMagicInArrayIndex;

    /// <summary>Persisted state of the hardcoded-string check.</summary>
    property CheckHardcodedStrings: Boolean read FCheckHardcodedStrings write FCheckHardcodedStrings;
    /// <summary>Persisted minimum reportable string length.</summary>
    property MinStringLength: Integer read FMinStringLength write FMinStringLength;
    /// <summary>Persisted toggle exempting format strings.</summary>
    property ExcludeFormatStrings: Boolean read FExcludeFormatStrings write FExcludeFormatStrings;
    /// <summary>Persisted toggle exempting strings containing SQL keywords.</summary>
    property ExcludeSQLKeywords: Boolean read FExcludeSQLKeywords write FExcludeSQLKeywords;

    /// <summary>Persisted state of the commented-out-code check.</summary>
    property CheckCommentedCode: Boolean read FCheckCommentedCode write FCheckCommentedCode;
    /// <summary>Persisted heuristic threshold for commented-out-code detection.</summary>
    property CommentCodeThreshold: Integer read FCommentCodeThreshold write FCommentCodeThreshold;

    /// <summary>Persisted state of the empty-except check.</summary>
    property CheckEmptyExcept: Boolean read FCheckEmptyExcept write FCheckEmptyExcept;
    /// <summary>Persisted state of the catch-all-exception check.</summary>
    property CheckCatchAllException: Boolean read FCheckCatchAllException write FCheckCatchAllException;

    /// <summary>Persisted state of the missing-try/finally check.</summary>
    property CheckMissingTryFinally: Boolean read FCheckMissingTryFinally write FCheckMissingTryFinally;
    /// <summary>Persisted state of the memory-leak check.</summary>
    property CheckMemoryLeaks: Boolean read FCheckMemoryLeaks write FCheckMemoryLeaks;
    /// <summary>Persisted comma-separated patterns excluded from memory-leak detection.</summary>
    property MemoryLeakIgnorePatterns: string read FMemoryLeakIgnorePatterns write FMemoryLeakIgnorePatterns;
  end;

var
  /// <summary>Singleton plugin instance accessed by the result form and option page.</summary>
  CodeQualityAnalyzerPlugin: TCodeQualityAnalyzerPlugin;

/// <summary>Returns a human-readable label for the supplied <paramref name="Category"/>.</summary>
function IssueCategoryToString( Category: TIssueCategory ): string;
/// <summary>Returns a human-readable label for the supplied <paramref name="Severity"/>.</summary>
function IssueSeverityToString( Severity: TIssueSeverity ): string;

/// <summary>
/// Plugin lifecycle entry point — creates or releases <see cref="CodeQualityAnalyzerPlugin"/>.
/// </summary>
/// <param name="Unload"><c>True</c> to release the plugin, <c>False</c> to create it.</param>
procedure InitPlugin( Unload: Boolean );

implementation

uses
  Windows, Forms, Dialogs, Main, IDENotifiers, ToolsAPIHelpers, DelphiLexer,
  FrmCodeQualityAnalyzer, FrmeOptionPageCodeQuality;

function IssueCategoryToString( Category: TIssueCategory ): string;
begin
  case Category of
    icMagicNumber:       Result := 'Magic Number';
    icHardcodedString:   Result := 'Hardcoded String';
    icCommentedCode:     Result := 'Commented Code';
    icEmptyExcept:       Result := 'Empty Except';
    icCatchAllException: Result := 'Catch-All Exception';
    icMissingTryFinally: Result := 'Missing Try/Finally';
    icMemoryLeak:        Result := 'Memory Leak';
  else
    Result := 'Unknown';
  end;
end;

function IssueSeverityToString( Severity: TIssueSeverity ): string;
begin
  case Severity of
    isInfo:    Result := 'Info';
    isWarning: Result := 'Warning';
    isError:   Result := 'Error';
  else
    Result := 'Unknown';
  end;
end;

procedure InitPlugin( Unload: Boolean );
begin
  if not Unload then
    CodeQualityAnalyzerPlugin := TCodeQualityAnalyzerPlugin.Create
  else
    FreeAndNil( CodeQualityAnalyzerPlugin );
end;

{ TCodeQualityAnalyzerPlugin }

constructor TCodeQualityAnalyzerPlugin.Create;
begin
  inherited Create( AppDataDirectory + '\CodeQualityAnalyzer.xml', 'CodeQualityAnalyzer' );

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem := TMenuItem.Create( DDevExtensionsMenu );
    FMenuItem.Caption := 'Code &Quality Analyzer...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add( FMenuItem );
  end;
end;

destructor TCodeQualityAnalyzerPlugin.Destroy;
begin
  FreeAndNil( FMenuItem );
  inherited Destroy;
end;

function TCodeQualityAnalyzerPlugin.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create( 'Code Quality Analyzer', TFrameOptionPageCodeQuality, Self );
end;

procedure TCodeQualityAnalyzerPlugin.Init;
begin
  inherited Init;

  FEnabled := True;

  // Magic Numbers - defaults
  FCheckMagicNumbers := True;
  FMagicNumberWhitelist := '0,1,-1,2,10,100,1000';
  FAllowMagicInArrayIndex := True;

  // Hardcoded Strings - defaults
  FCheckHardcodedStrings := True;
  FMinStringLength := 3;
  FExcludeFormatStrings := True;
  FExcludeSQLKeywords := True;

  // Commented-Out Code - defaults
  FCheckCommentedCode := True;
  FCommentCodeThreshold := 3;

  // Exception Handling - defaults
  FCheckEmptyExcept := True;
  FCheckCatchAllException := True;

  // Memory Management - defaults
  FCheckMissingTryFinally := True;
  FCheckMemoryLeaks := True;
  FMemoryLeakIgnorePatterns := '';
end;

procedure TCodeQualityAnalyzerPlugin.MenuItemClick( Sender: TObject );
begin
  if not Enabled then
  begin
    ShowMessage( 'Code Quality Analyzer is disabled. Enable it in DDevExtensions options.' );
    Exit;
  end;

  TFormCodeQualityAnalyzer.Execute;
end;

function TCodeQualityAnalyzerPlugin.GetMagicNumberWhitelistArray: TArray<string>;
var
  SL: TStringList;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Delimiter := ',';
    SL.StrictDelimiter := True;
    SL.DelimitedText := FMagicNumberWhitelist;

    SetLength( Result, SL.Count );
    for I := 0 to SL.Count - 1 do
      Result[ I ] := Trim( SL[ I ] );
  finally
    SL.Free;
  end;
end;

function TCodeQualityAnalyzerPlugin.GetMemoryLeakIgnorePatternsArray: TArray<string>;
var
  SL: TStringList;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Delimiter := ',';
    SL.StrictDelimiter := True;
    SL.DelimitedText := FMemoryLeakIgnorePatterns;

    SetLength( Result, SL.Count );
    for I := 0 to SL.Count - 1 do
      Result[ I ] := Trim( SL[ I ] );
  finally
    SL.Free;
  end;
end;

type
  TQABlockKind = ( qabOther, qabTry );

  // One entry per open structural block (begin/case/record/class/asm/try...),
  // so each 'end' can be matched to the construct it actually closes.
  TQABlock = record
    Kind: TQABlockKind;
    HadExcept: Boolean;            // this try block has an 'except' section
    InExcept: Boolean;             // currently inside the except (not finally) section
    ExceptStartLine: Integer;
    ExceptHasStatements: Boolean;
    ExceptHasOnClause: Boolean;
  end;

class function TCodeQualityAnalyzerPlugin.AnalyzeUnit( const Source: UTF8String;
  const FileName: string; Plugin: TCodeQualityAnalyzerPlugin ): TArray<TCodeQualityIssue>;
var
  Lexer: TDelphiLexer;
  Token, PrevToken: TToken;
  Results: TList<TCodeQualityIssue>;
  Issue: TCodeQualityIssue;
  InImplementation: Boolean;
  InConstSection: Boolean;
  InResourceString: Boolean;
  Blocks: TArray<TQABlock>;       // structural block stack for matching 'end's
  BlockCount: Integer;            // number of open blocks on the stack
  OpenTryCount: Integer;          // how many of those open blocks are try blocks
  LastClosedBlock: TQABlock;      // the block most recently popped by an 'end'
  ClassObjPending: Boolean;       // a class/object opener awaiting body confirmation
  UnitName: string;
  Whitelist: TArray<string>;
  I: Integer;
  CommentBody: string;
  CodeScore: Integer;
  StringValue: string;

  // Pending Create calls waiting for try/finally
  PendingCreates: TList<TPair<string, Integer>>;  // VarName, Line
  LastAssignedVar: string;
  LastAssignedLine: Integer;

  function IsInWhitelist( const Value: string ): Boolean;
  var
    S: string;
  begin
    Result := False;
    for S in Whitelist do
    begin
      if SameText( Trim( Value ), Trim( S ) ) then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;

  function IsFormatString( const S: string ): Boolean;
  begin
    Result := ( Pos( '%s', S ) > 0 ) or ( Pos( '%d', S ) > 0 ) or
              ( Pos( '%f', S ) > 0 ) or ( Pos( '%g', S ) > 0 ) or
              ( Pos( '%n', S ) > 0 ) or ( Pos( '%x', S ) > 0 ) or
              ( Pos( '%e', S ) > 0 ) or ( Pos( '%.', S ) > 0 ) or
              ( Pos( '%0', S ) > 0 ) or ( Pos( '%1', S ) > 0 ) or
              ( Pos( '%2', S ) > 0 ) or ( Pos( '%3', S ) > 0 );
  end;

  function IsSQLKeyword( const S: string ): Boolean;
  var
    UpperS: string;
  begin
    UpperS := UpperCase( Trim( S ) );
    Result := ( Pos( 'SELECT ', UpperS ) > 0 ) or ( Pos( 'INSERT ', UpperS ) > 0 ) or
              ( Pos( 'UPDATE ', UpperS ) > 0 ) or ( Pos( 'DELETE ', UpperS ) > 0 ) or
              ( Pos( 'FROM ', UpperS ) > 0 ) or ( Pos( 'WHERE ', UpperS ) > 0 ) or
              ( Pos( 'CREATE ', UpperS ) > 0 ) or ( Pos( 'DROP ', UpperS ) > 0 ) or
              ( Pos( 'ALTER ', UpperS ) > 0 ) or ( Pos( 'ORDER BY', UpperS ) > 0 ) or
              ( Pos( 'GROUP BY', UpperS ) > 0 ) or ( Pos( 'INNER JOIN', UpperS ) > 0 ) or
              ( Pos( 'LEFT JOIN', UpperS ) > 0 ) or ( Pos( 'RIGHT JOIN', UpperS ) > 0 );
  end;

  function IsFilePath( const S: string ): Boolean;
  begin
    Result := ( Pos( ':\', S ) > 0 ) or ( Pos( '/', S ) = 1 ) or
              ( Pos( '.\', S ) = 1 ) or ( Pos( './', S ) = 1 ) or
              ( Pos( '\', S ) = 1 ) or ( Pos( '..', S ) > 0 );
  end;

  function CalculateCodeScore( const Comment: string ): Integer;
  var
    Lines: TStringList;
    Line: string;
    SemicolonLines: Integer;
  begin
    Result := 0;
    SemicolonLines := 0;

    // Assignment operator
    if Pos( ':=', Comment ) > 0 then
      Inc( Result, 3 );

    // Begin/end keywords
    if ( Pos( 'begin', LowerCase( Comment ) ) > 0 ) or
       ( Pos( 'end;', LowerCase( Comment ) ) > 0 ) then
      Inc( Result, 3 );

    // Control flow
    if ( Pos( 'if ', LowerCase( Comment ) ) > 0 ) and
       ( Pos( ' then', LowerCase( Comment ) ) > 0 ) then
      Inc( Result, 2 );

    // Procedure/function declarations
    if ( Pos( 'procedure ', LowerCase( Comment ) ) > 0 ) or
       ( Pos( 'function ', LowerCase( Comment ) ) > 0 ) then
      Inc( Result, 3 );

    // Count lines ending with semicolons
    Lines := TStringList.Create;
    try
      Lines.Text := Comment;
      for Line in Lines do
      begin
        if ( Length( Trim( Line ) ) > 0 ) and
           ( Trim( Line )[ Length( Trim( Line ) ) ] = ';' ) then
          Inc( SemicolonLines );
      end;
      Inc( Result, SemicolonLines );
    finally
      Lines.Free;
    end;

    // Variable declarations (Type: Name pattern)
    if Pos( ': T', Comment ) > 0 then
      Inc( Result, 2 );
  end;

  procedure PushBlock( AKind: TQABlockKind );
  begin

    // A nested construct opening inside an except section is itself content,
    // so the enclosing handler is not considered empty.
    if ( BlockCount > 0 ) and ( Blocks[ BlockCount - 1 ].Kind = qabTry ) and
       Blocks[ BlockCount - 1 ].InExcept then
      Blocks[ BlockCount - 1 ].ExceptHasStatements := True;

    if BlockCount >= Length( Blocks ) then
      SetLength( Blocks, BlockCount + 16 );

    Blocks[ BlockCount ] := Default( TQABlock );
    Blocks[ BlockCount ].Kind := AKind;
    Inc( BlockCount );

    if AKind = qabTry then
      Inc( OpenTryCount );

  end;

  procedure PopBlock;
  begin

    if BlockCount = 0 then
      Exit;

    Dec( BlockCount );
    LastClosedBlock := Blocks[ BlockCount ];

    if ( LastClosedBlock.Kind = qabTry ) and ( OpenTryCount > 0 ) then
      Dec( OpenTryCount );

  end;

begin
  Results := TList<TCodeQualityIssue>.Create;
  PendingCreates := TList<TPair<string, Integer>>.Create;
  try
    UnitName := ChangeFileExt( ExtractFileName( FileName ), '' );
    Whitelist := Plugin.GetMagicNumberWhitelistArray;

    Lexer := TDelphiLexer.Create( '', Source );
    try
      InImplementation := False;
      InConstSection := False;
      InResourceString := False;
      BlockCount := 0;
      OpenTryCount := 0;
      ClassObjPending := False;
      LastAssignedVar := '';
      LastAssignedLine := 0;

      PrevToken := nil;

      while Lexer.NextToken( Token ) do
      begin
        // Track implementation section
        if Token.Kind = tkI_implementation then
        begin
          InImplementation := True;
          InConstSection := False;
          InResourceString := False;
          // Reset the structural stack so any imbalance from interface-section
          // type declarations cannot leak into the implementation analysis.
          BlockCount := 0;
          OpenTryCount := 0;
          ClassObjPending := False;
          PrevToken := Token;
          Continue;
        end;

        // Track const/resourcestring sections
        if Token.Kind = tkI_const then
        begin
          InConstSection := True;
          InResourceString := False;
        end
        else if Token.Kind = tkI_resourcestring then
        begin
          InResourceString := True;
          InConstSection := False;
        end
        else if Token.Kind in [ tkI_var, tkI_type, tkI_procedure, tkI_function,
                                tkI_begin, tkI_implementation ] then
        begin
          InConstSection := False;
          InResourceString := False;
        end;

        // =====================================================================
        // Magic Number Detection
        // =====================================================================
        if Plugin.CheckMagicNumbers and InImplementation and
           ( Token.Kind in [ tkInt, tkFloat ] ) and
           not InConstSection then
        begin
          // Check if it's in the whitelist
          if not IsInWhitelist( string( Token.Value ) ) then
          begin
            // Check if it's an array index and we should allow it
            if not ( Plugin.AllowMagicInArrayIndex and ( PrevToken <> nil ) and ( PrevToken.Kind = tkLBracket ) ) then
            begin
              Issue := Default( TCodeQualityIssue );
              Issue.FileName := FileName;
              Issue.UnitName := UnitName;
              Issue.Line := Token.Line + 1;
              Issue.Column := Token.Column;
              Issue.Category := icMagicNumber;
              Issue.Severity := isWarning;
              Issue.Description := 'Magic number: ' + string( Token.Value ) + ' should be a named constant';
              Issue.CodePreview := string( Token.Value );
              Results.Add( Issue );
            end;
          end;
        end;

        // =====================================================================
        // Hardcoded String Detection
        // =====================================================================
        if Plugin.CheckHardcodedStrings and InImplementation and
           ( Token.Kind = tkString ) and
           not InConstSection and not InResourceString then
        begin
          StringValue := string( Token.Value );

          // Remove surrounding quotes if present
          if ( Length( StringValue ) >= 2 ) and
             ( StringValue[ 1 ] = '''' ) and
             ( StringValue[ Length( StringValue ) ] = '''' ) then
            StringValue := Copy( StringValue, 2, Length( StringValue ) - 2 );

          if Length( StringValue ) >= Plugin.MinStringLength then
          begin
            // Apply exclusions
            if not ( Plugin.ExcludeFormatStrings and IsFormatString( StringValue ) ) and
               not ( Plugin.ExcludeSQLKeywords and IsSQLKeyword( StringValue ) ) and
               not IsFilePath( StringValue ) then
            begin
              Issue := Default( TCodeQualityIssue );
              Issue.FileName := FileName;
              Issue.UnitName := UnitName;
              Issue.Line := Token.Line + 1;
              Issue.Column := Token.Column;
              Issue.Category := icHardcodedString;
              Issue.Severity := isInfo;
              if Length( StringValue ) > 30 then
                Issue.Description := 'Hardcoded string: ''' + Copy( StringValue, 1, 30 ) + '...'''
              else
                Issue.Description := 'Hardcoded string: ''' + StringValue + '''';
              Issue.CodePreview := string( Token.Value );
              Results.Add( Issue );
            end;
          end;
        end;

        // =====================================================================
        // Commented-Out Code Detection
        // =====================================================================
        if Plugin.CheckCommentedCode and ( Token.Kind = tkComment ) then
        begin
          CommentBody := string( Token.Value );

          // Remove comment delimiters
          if ( Length( CommentBody ) >= 2 ) and ( CommentBody[ 1 ] = '{' ) then
            CommentBody := Copy( CommentBody, 2, Length( CommentBody ) - 2 )
          else if ( Length( CommentBody ) >= 4 ) and ( Copy( CommentBody, 1, 2 ) = '(*' ) then
            CommentBody := Copy( CommentBody, 3, Length( CommentBody ) - 4 )
          else if ( Length( CommentBody ) >= 2 ) and ( Copy( CommentBody, 1, 2 ) = '//' ) then
            CommentBody := Copy( CommentBody, 3, Length( CommentBody ) - 2 );

          CodeScore := CalculateCodeScore( CommentBody );

          if CodeScore >= Plugin.CommentCodeThreshold then
          begin
            Issue := Default( TCodeQualityIssue );
            Issue.FileName := FileName;
            Issue.UnitName := UnitName;
            Issue.Line := Token.Line + 1;
            Issue.Column := Token.Column;
            Issue.Category := icCommentedCode;
            Issue.Severity := isInfo;
            Issue.Description := 'Possible commented-out code (score: ' + IntToStr( CodeScore ) + ')';
            if Length( CommentBody ) > 40 then
              Issue.CodePreview := Copy( CommentBody, 1, 40 ) + '...'
            else
              Issue.CodePreview := CommentBody;
            Results.Add( Issue );
          end;
        end;

        // =====================================================================
        // Exception Handler Analysis
        // =====================================================================
        if ClassObjPending then
        begin
          // A class/object opener was pushed speculatively on the previous
          // token. 'class of X' (metaclass) and a forward 'class;' open no body,
          // so undo that push when the following token proves it is not a body.
          if Token.Kind in [ tkI_of, tkSemicolon ] then
            PopBlock;
          ClassObjPending := False;
        end;

        if Token.Kind = tkI_try then
          PushBlock( qabTry )
        else if Token.Kind in [ tkI_begin, tkI_case, tkI_asm ] then
          PushBlock( qabOther )
        else if ( Token.Kind in [ tkI_record, tkI_class, tkI_object,
                                  tkI_interface, tkI_dispinterface ] ) and
                ( PrevToken <> nil ) and ( PrevToken.Kind in [ tkEqual, tkI_packed ] ) then
        begin
          // A type body: TFoo = class/record/object/interface ... end.
          PushBlock( qabOther );
          ClassObjPending := Token.Kind in [ tkI_class, tkI_object ];
        end
        else if Token.Kind = tkI_except then
        begin
          if ( BlockCount > 0 ) and ( Blocks[ BlockCount - 1 ].Kind = qabTry ) then
          begin
            Blocks[ BlockCount - 1 ].HadExcept := True;
            Blocks[ BlockCount - 1 ].InExcept := True;
            Blocks[ BlockCount - 1 ].ExceptStartLine := Token.Line + 1;
            Blocks[ BlockCount - 1 ].ExceptHasStatements := False;
            Blocks[ BlockCount - 1 ].ExceptHasOnClause := False;
          end;
        end
        else if Token.Kind = tkI_finally then
        begin
          if ( BlockCount > 0 ) and ( Blocks[ BlockCount - 1 ].Kind = qabTry ) then
            Blocks[ BlockCount - 1 ].InExcept := False;
        end
        else if Token.Kind = tkI_on then
        begin
          if ( BlockCount > 0 ) and ( Blocks[ BlockCount - 1 ].Kind = qabTry ) and
             Blocks[ BlockCount - 1 ].InExcept then
            Blocks[ BlockCount - 1 ].ExceptHasOnClause := True;
        end
        else if Token.Kind = tkI_end then
        begin
          if BlockCount > 0 then
          begin
            PopBlock;
            // Only a try..except that closed while still in its except section
            // (no trailing finally) is a candidate for the empty / catch-all
            // checks. A token-level scan now matches this 'end' to the exact
            // construct it closes, so try/finally no longer leaks the depth and
            // a record/class/case 'end' no longer corrupts the try state.
            if ( LastClosedBlock.Kind = qabTry ) and
               LastClosedBlock.HadExcept and LastClosedBlock.InExcept then
            begin
              if Plugin.CheckEmptyExcept and
                 not LastClosedBlock.ExceptHasStatements and
                 not LastClosedBlock.ExceptHasOnClause then
              begin
                Issue := Default( TCodeQualityIssue );
                Issue.FileName := FileName;
                Issue.UnitName := UnitName;
                Issue.Line := LastClosedBlock.ExceptStartLine;
                Issue.Column := 1;
                Issue.Category := icEmptyExcept;
                Issue.Severity := isWarning;
                Issue.Description := 'Empty except block - exceptions are silently swallowed';
                Issue.CodePreview := 'except ... end';
                Results.Add( Issue );
              end
              else if Plugin.CheckCatchAllException and
                      LastClosedBlock.ExceptHasStatements and
                      not LastClosedBlock.ExceptHasOnClause then
              begin
                Issue := Default( TCodeQualityIssue );
                Issue.FileName := FileName;
                Issue.UnitName := UnitName;
                Issue.Line := LastClosedBlock.ExceptStartLine;
                Issue.Column := 1;
                Issue.Category := icCatchAllException;
                Issue.Severity := isInfo;
                Issue.Description := 'Catch-all exception handler without specific "on E:" clause';
                Issue.CodePreview := 'except ... end';
                Results.Add( Issue );
              end;
            end;
          end;
        end
        else if ( BlockCount > 0 ) and ( Blocks[ BlockCount - 1 ].Kind = qabTry ) and
                Blocks[ BlockCount - 1 ].InExcept and
                ( Token.Kind >= tkIdent ) and
                not ( Token.Kind in [ tkI_end, tkI_on, tkI_else ] ) then
        begin
          // Any identifier or statement in the except section counts as content.
          Blocks[ BlockCount - 1 ].ExceptHasStatements := True;
        end;

        // =====================================================================
        // Try/Finally Pattern Detection (Create without try/finally)
        // =====================================================================
        if Plugin.CheckMissingTryFinally and InImplementation then
        begin
          // Track assignments: VarName := Something.Create
          if ( Token.Kind = tkAssign ) and ( PrevToken <> nil ) and ( PrevToken.Kind >= tkIdent ) then
          begin
            LastAssignedVar := string( PrevToken.Value );
            LastAssignedLine := Token.Line + 1;
          end
          // Detect .Create call
          else if ( Token.Kind >= tkIdent ) and
                  SameText( string( Token.Value ), 'Create' ) and
                  ( PrevToken <> nil ) and ( PrevToken.Kind = tkQualifier ) and
                  ( LastAssignedVar <> '' ) then
          begin
            // Check if we're already in a try block
            if OpenTryCount = 0 then
            begin
              PendingCreates.Add( TPair<string, Integer>.Create( LastAssignedVar, LastAssignedLine ) );
            end;
            LastAssignedVar := '';
          end
          // Check for try keyword - clears pending creates (they're protected)
          else if Token.Kind = tkI_try then
          begin
            PendingCreates.Clear;
          end
          // Check for method end - report unprotected creates. The block stack
          // is already updated for this 'end' above, so BlockCount = 0 means we
          // have returned to top level (end of the routine body).
          else if ( Token.Kind = tkI_end ) and ( BlockCount = 0 ) and
                  ( PendingCreates.Count > 0 ) then
          begin
            for I := 0 to PendingCreates.Count - 1 do
            begin
              Issue := Default( TCodeQualityIssue );
              Issue.FileName := FileName;
              Issue.UnitName := UnitName;
              Issue.Line := PendingCreates[ I ].Value;
              Issue.Column := 1;
              Issue.Category := icMissingTryFinally;
              Issue.Severity := isWarning;
              Issue.Description := PendingCreates[ I ].Key + '.Create without try/finally/Free protection';
              Issue.CodePreview := PendingCreates[ I ].Key + ' := ...Create';
              Results.Add( Issue );
            end;
            PendingCreates.Clear;
          end;
        end;

        PrevToken := Token;
      end;

    finally
      Lexer.Free;
    end;

    Result := Results.ToArray;
  finally
    Results.Free;
    PendingCreates.Free;
  end;
end;

end.
