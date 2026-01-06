{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit CodeQualityAnalyzer;

{$I ..\DelphiExtension.inc}

interface

uses
  SysUtils, Classes, Menus, ToolsAPI, PluginConfig, FrmTreePages,
  Generics.Collections;

type
  TIssueCategory = (
    icMagicNumber,
    icHardcodedString,
    icCommentedCode,
    icEmptyExcept,
    icCatchAllException,
    icMissingTryFinally,
    icMemoryLeak
  );

  TIssueSeverity = ( isInfo, isWarning, isError );

  TCodeQualityIssue = record
    FileName: string;
    UnitName: string;
    Line: Integer;
    Column: Integer;
    Category: TIssueCategory;
    Severity: TIssueSeverity;
    Description: string;
    CodePreview: string;
  end;

  TCodeQualityAnalyzerPlugin = class( TPluginConfig )
  private
    FMenuItem: TMenuItem;
    FEnabled: Boolean;

    // Magic Numbers
    FCheckMagicNumbers: Boolean;
    FMagicNumberWhitelist: string;
    FAllowMagicInArrayIndex: Boolean;

    // Hardcoded Strings
    FCheckHardcodedStrings: Boolean;
    FMinStringLength: Integer;
    FExcludeFormatStrings: Boolean;
    FExcludeSQLKeywords: Boolean;

    // Commented-Out Code
    FCheckCommentedCode: Boolean;
    FCommentCodeThreshold: Integer;

    // Exception Handling
    FCheckEmptyExcept: Boolean;
    FCheckCatchAllException: Boolean;

    // Memory Management
    FCheckMissingTryFinally: Boolean;
    FCheckMemoryLeaks: Boolean;
    FMemoryLeakIgnorePatterns: string;

    procedure MenuItemClick( Sender: TObject );
  protected
    function GetOptionPages: TTreePage; override;
    procedure Init; override;
  public
    constructor Create;
    destructor Destroy; override;

    class function AnalyzeUnit( const Source: UTF8String; const FileName: string;
      Plugin: TCodeQualityAnalyzerPlugin ): TArray<TCodeQualityIssue>;

    function GetMagicNumberWhitelistArray: TArray<string>;
    function GetMemoryLeakIgnorePatternsArray: TArray<string>;
  published
    property Enabled: Boolean read FEnabled write FEnabled;

    property CheckMagicNumbers: Boolean read FCheckMagicNumbers write FCheckMagicNumbers;
    property MagicNumberWhitelist: string read FMagicNumberWhitelist write FMagicNumberWhitelist;
    property AllowMagicInArrayIndex: Boolean read FAllowMagicInArrayIndex write FAllowMagicInArrayIndex;

    property CheckHardcodedStrings: Boolean read FCheckHardcodedStrings write FCheckHardcodedStrings;
    property MinStringLength: Integer read FMinStringLength write FMinStringLength;
    property ExcludeFormatStrings: Boolean read FExcludeFormatStrings write FExcludeFormatStrings;
    property ExcludeSQLKeywords: Boolean read FExcludeSQLKeywords write FExcludeSQLKeywords;

    property CheckCommentedCode: Boolean read FCheckCommentedCode write FCheckCommentedCode;
    property CommentCodeThreshold: Integer read FCommentCodeThreshold write FCommentCodeThreshold;

    property CheckEmptyExcept: Boolean read FCheckEmptyExcept write FCheckEmptyExcept;
    property CheckCatchAllException: Boolean read FCheckCatchAllException write FCheckCatchAllException;

    property CheckMissingTryFinally: Boolean read FCheckMissingTryFinally write FCheckMissingTryFinally;
    property CheckMemoryLeaks: Boolean read FCheckMemoryLeaks write FCheckMemoryLeaks;
    property MemoryLeakIgnorePatterns: string read FMemoryLeakIgnorePatterns write FMemoryLeakIgnorePatterns;
  end;

var
  CodeQualityAnalyzerPlugin: TCodeQualityAnalyzerPlugin;

function IssueCategoryToString( Category: TIssueCategory ): string;
function IssueSeverityToString( Severity: TIssueSeverity ): string;

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
  InTryBlock: Boolean;
  InExceptBlock: Boolean;
  TryDepth: Integer;
  ExceptStartLine: Integer;
  ExceptHasStatements: Boolean;
  ExceptHasOnClause: Boolean;
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
      InTryBlock := False;
      InExceptBlock := False;
      TryDepth := 0;
      ExceptStartLine := 0;
      ExceptHasStatements := False;
      ExceptHasOnClause := False;
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
        if Token.Kind = tkI_try then
        begin
          Inc( TryDepth );
          InTryBlock := True;
        end
        else if Token.Kind = tkI_except then
        begin
          InExceptBlock := True;
          ExceptStartLine := Token.Line + 1;
          ExceptHasStatements := False;
          ExceptHasOnClause := False;
        end
        else if Token.Kind = tkI_finally then
        begin
          InExceptBlock := False;
        end
        else if Token.Kind = tkI_on then
        begin
          if InExceptBlock then
            ExceptHasOnClause := True;
        end
        else if ( Token.Kind = tkI_end ) and InExceptBlock then
        begin
          // Check for empty except block
          if Plugin.CheckEmptyExcept and not ExceptHasStatements and not ExceptHasOnClause then
          begin
            Issue := Default( TCodeQualityIssue );
            Issue.FileName := FileName;
            Issue.UnitName := UnitName;
            Issue.Line := ExceptStartLine;
            Issue.Column := 1;
            Issue.Category := icEmptyExcept;
            Issue.Severity := isWarning;
            Issue.Description := 'Empty except block - exceptions are silently swallowed';
            Issue.CodePreview := 'except ... end';
            Results.Add( Issue );
          end
          // Check for catch-all without specific handler
          else if Plugin.CheckCatchAllException and ExceptHasStatements and not ExceptHasOnClause then
          begin
            Issue := Default( TCodeQualityIssue );
            Issue.FileName := FileName;
            Issue.UnitName := UnitName;
            Issue.Line := ExceptStartLine;
            Issue.Column := 1;
            Issue.Category := icCatchAllException;
            Issue.Severity := isInfo;
            Issue.Description := 'Catch-all exception handler without specific "on E:" clause';
            Issue.CodePreview := 'except ... end';
            Results.Add( Issue );
          end;

          InExceptBlock := False;
          Dec( TryDepth );
          if TryDepth <= 0 then
          begin
            InTryBlock := False;
            TryDepth := 0;
          end;
        end
        else if InExceptBlock and ( Token.Kind >= tkIdent ) and
                not ( Token.Kind in [ tkI_end, tkI_on, tkI_else ] ) then
        begin
          // Any identifier or statement in except block counts as having statements
          ExceptHasStatements := True;
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
            if not InTryBlock then
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
          // Check for method end - report unprotected creates
          else if ( Token.Kind = tkI_end ) and ( TryDepth = 0 ) and
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
