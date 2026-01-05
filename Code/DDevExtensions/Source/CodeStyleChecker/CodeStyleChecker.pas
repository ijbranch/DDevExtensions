{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit CodeStyleChecker;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Generics.Collections, Menus, Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main;

type
  TStyleViolation = record
    FileName: string;
    UnitName: string;
    Line: Integer;
    Column: Integer;
    Rule: string;
    Expected: string;
    Actual: string;
    Severity: string;
  end;

  TStyleRule = class
  public
    Name: string;
    Description: string;
    Prefix: string;
    AppliesTo: string;
    Enabled: Boolean;
    Severity: string;
  end;

  TStyleChecker = class
  private
    FRules: TObjectList<TStyleRule>;
    FProgressFileName: string;
    procedure InitDefaultRules;
    function CheckName( const Name, RuleName, Prefix: string; Line, Column: Integer;
      const FileName, UnitName, Severity: string;
      var Violation: TStyleViolation ): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function CheckFile( const FileName: string; out Violations: TArray<TStyleViolation> ): Boolean;
    function CheckProject( const Project: IOTAProject; out AllViolations: TArray<TStyleViolation>;
      OnProgress: TNotifyEvent ): Boolean;
    property Rules: TObjectList<TStyleRule> read FRules;
    property ProgressFileName: string read FProgressFileName;
  end;

  TCodeStyleCheckerPlugin = class( TPluginConfig )
  private
    FEnabled: Boolean;
    FCheckTypes: Boolean;
    FCheckInterfaces: Boolean;
    FCheckFields: Boolean;
    FCheckExceptions: Boolean;
    FCheckPointers: Boolean;
    FCheckParameters: Boolean;
    FMenuItem: TMenuItem;
    procedure MenuItemClick( Sender: TObject );
  protected
    function GetOptionPages: TTreePage; override;
    procedure Init; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ShowChecker;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
    property CheckTypes: Boolean read FCheckTypes write FCheckTypes;
    property CheckInterfaces: Boolean read FCheckInterfaces write FCheckInterfaces;
    property CheckFields: Boolean read FCheckFields write FCheckFields;
    property CheckExceptions: Boolean read FCheckExceptions write FCheckExceptions;
    property CheckPointers: Boolean read FCheckPointers write FCheckPointers;
    property CheckParameters: Boolean read FCheckParameters write FCheckParameters;
  end;

procedure InitPlugin( Unload: Boolean );

var
  CodeStyleCheckerPlugin: TCodeStyleCheckerPlugin;

implementation

uses
  Forms, Controls, ToolsAPIHelpers, AppConsts, DelphiLexer,
  FrmCodeStyleChecker, FrmeOptionPageCodeStyle;

{ TStyleChecker }

constructor TStyleChecker.Create;
begin

  inherited Create;
  FRules := TObjectList<TStyleRule>.Create( True );
  InitDefaultRules;

end;

destructor TStyleChecker.Destroy;
begin

  FRules.Free;
  inherited Destroy;

end;

procedure TStyleChecker.InitDefaultRules;
var
  Rule: TStyleRule;
begin

  FRules.Clear;

  // Type names must start with T
  Rule             := TStyleRule.Create;
  Rule.Name        := 'TypePrefix';
  Rule.Description := 'Type names should start with T';
  Rule.Prefix      := 'T';
  Rule.AppliesTo   := 'Types';
  Rule.Enabled     := True;
  Rule.Severity    := 'Warning';
  FRules.Add( Rule );

  // Interface names must start with I
  Rule             := TStyleRule.Create;
  Rule.Name        := 'InterfacePrefix';
  Rule.Description := 'Interface names should start with I';
  Rule.Prefix      := 'I';
  Rule.AppliesTo   := 'Interfaces';
  Rule.Enabled     := True;
  Rule.Severity    := 'Warning';
  FRules.Add( Rule );

  // Field names must start with F
  Rule             := TStyleRule.Create;
  Rule.Name        := 'FieldPrefix';
  Rule.Description := 'Field names should start with F';
  Rule.Prefix      := 'F';
  Rule.AppliesTo   := 'Fields';
  Rule.Enabled     := True;
  Rule.Severity    := 'Warning';
  FRules.Add( Rule );

  // Exception types must start with E
  Rule             := TStyleRule.Create;
  Rule.Name        := 'ExceptionPrefix';
  Rule.Description := 'Exception type names should start with E';
  Rule.Prefix      := 'E';
  Rule.AppliesTo   := 'Exceptions';
  Rule.Enabled     := True;
  Rule.Severity    := 'Warning';
  FRules.Add( Rule );

  // Pointer types must start with P
  Rule             := TStyleRule.Create;
  Rule.Name        := 'PointerPrefix';
  Rule.Description := 'Pointer type names should start with P';
  Rule.Prefix      := 'P';
  Rule.AppliesTo   := 'Pointers';
  Rule.Enabled     := True;
  Rule.Severity    := 'Info';
  FRules.Add( Rule );

  // Parameter names should start with A
  Rule             := TStyleRule.Create;
  Rule.Name        := 'ParameterPrefix';
  Rule.Description := 'Parameter names should start with A';
  Rule.Prefix      := 'A';
  Rule.AppliesTo   := 'Parameters';
  Rule.Enabled     := False;  // Off by default - not universally followed
  Rule.Severity    := 'Info';
  FRules.Add( Rule );

end;

function TStyleChecker.CheckName( const Name, RuleName, Prefix: string;
  Line, Column: Integer; const FileName, UnitName, Severity: string;
  var Violation: TStyleViolation ): Boolean;
begin

  Result := False;

  if ( Length( Name ) > 0 ) and ( not SameText( Copy( Name, 1, Length( Prefix ) ), Prefix ) ) then
  begin
    Violation.FileName := FileName;
    Violation.UnitName := UnitName;
    Violation.Line     := Line + 1;  // Convert from 0-based (lexer) to 1-based (IDE)
    Violation.Column   := Column;
    Violation.Rule     := RuleName;
    Violation.Expected := Prefix + '...';
    Violation.Actual   := Name;
    Violation.Severity := Severity;
    Result             := True;
  end;

end;

function IsBuiltInType( const Name: string ): Boolean;
var
  UpperName: string;
begin

  UpperName := UpperCase( Name );
  Result    := ( UpperName = 'BOOLEAN' ) or
               ( UpperName = 'INTEGER' ) or
               ( UpperName = 'CARDINAL' ) or
               ( UpperName = 'INT64' ) or
               ( UpperName = 'UINT64' ) or
               ( UpperName = 'BYTE' ) or
               ( UpperName = 'WORD' ) or
               ( UpperName = 'LONGWORD' ) or
               ( UpperName = 'SHORTINT' ) or
               ( UpperName = 'SMALLINT' ) or
               ( UpperName = 'LONGINT' ) or
               ( UpperName = 'NATIVEINT' ) or
               ( UpperName = 'NATIVEUINT' ) or
               ( UpperName = 'SINGLE' ) or
               ( UpperName = 'DOUBLE' ) or
               ( UpperName = 'EXTENDED' ) or
               ( UpperName = 'REAL' ) or
               ( UpperName = 'CURRENCY' ) or
               ( UpperName = 'COMP' ) or
               ( UpperName = 'STRING' ) or
               ( UpperName = 'ANSISTRING' ) or
               ( UpperName = 'WIDESTRING' ) or
               ( UpperName = 'UNICODESTRING' ) or
               ( UpperName = 'SHORTSTRING' ) or
               ( UpperName = 'CHAR' ) or
               ( UpperName = 'ANSICHAR' ) or
               ( UpperName = 'WIDECHAR' ) or
               ( UpperName = 'PCHAR' ) or
               ( UpperName = 'PANSICHAR' ) or
               ( UpperName = 'PWIDECHAR' ) or
               ( UpperName = 'POINTER' ) or
               ( UpperName = 'VARIANT' ) or
               ( UpperName = 'OLEVARIANT' ) or
               ( UpperName = 'TDATETIME' ) or
               ( UpperName = 'TDATE' ) or
               ( UpperName = 'TTIME' );

end;

function TStyleChecker.CheckFile( const FileName: string;
  out Violations: TArray<TStyleViolation> ): Boolean;
var
  Content: UTF8String;
  Lexer: TDelphiLexer;
  Token, IdentToken: TToken;
  ViolationList: TList<TStyleViolation>;
  Violation: TStyleViolation;
  UnitName: string;
  InType, InClass: Boolean;
  InPrivate, InProtected: Boolean;
  InParameterList, InMethodDeclaration: Boolean;
  ParenDepth: Integer;
  CheckTypes, CheckInterfaces, CheckFields: Boolean;
  CheckExceptions, CheckPointers, CheckParameters: Boolean;
begin

  Result := False;
  SetLength( Violations, 0 );

  if not FileExists( FileName ) then
    Exit;

  // Get enabled checks from plugin
  if CodeStyleCheckerPlugin <> nil then
  begin
    CheckTypes      := CodeStyleCheckerPlugin.CheckTypes;
    CheckInterfaces := CodeStyleCheckerPlugin.CheckInterfaces;
    CheckFields     := CodeStyleCheckerPlugin.CheckFields;
    CheckExceptions := CodeStyleCheckerPlugin.CheckExceptions;
    CheckPointers   := CodeStyleCheckerPlugin.CheckPointers;
    CheckParameters := CodeStyleCheckerPlugin.CheckParameters;
  end
  else
  begin
    CheckTypes      := True;
    CheckInterfaces := True;
    CheckFields     := True;
    CheckExceptions := True;
    CheckPointers   := True;
    CheckParameters := False;
  end;

  try
    Content := LoadTextFileToUtf8String( FileName );
  except
    Exit;
  end;

  UnitName          := ChangeFileExt( ExtractFileName( FileName ), '' );
  ViolationList     := TList<TStyleViolation>.Create;
  InType            := False;
  InClass           := False;
  InPrivate         := False;
  InProtected       := False;
  InParameterList   := False;
  InMethodDeclaration := False;
  ParenDepth        := 0;

  try
    Lexer := TDelphiLexer.Create( FileName, Content );

    try
      while Lexer.NextToken( Token ) do
      begin
        // Track type section
        if Token.Kind = tkI_type then
        begin
          InType := True;
          InClass := False;
        end
        else if Token.Kind in [ tkI_var, tkI_const, tkI_implementation,
                                tkI_procedure, tkI_function, tkI_constructor,
                                tkI_destructor, tkI_begin ] then
        begin
          // Only end type/class context if we're NOT inside a class declaration
          // Method declarations inside a class shouldn't reset InClass
          if not InClass then
          begin
            InType := False;
            InClass := False;
          end
          else
          begin
            // Inside a class - this is a method declaration
            if Token.Kind in [ tkI_procedure, tkI_function, tkI_constructor, tkI_destructor ] then
              InMethodDeclaration := True;
          end;
        end;

        // End method declaration on semicolon (when not in nested parentheses)
        if ( Token.Kind = tkSemicolon ) and ( ParenDepth = 0 ) then
          InMethodDeclaration := False;

        // Track class context
        if Token.Kind = tkI_class then
        begin
          InClass     := True;
          // Don't assume private - the implicit section before any visibility
          // keyword is "published" for forms (VCL components). Only check fields
          // after an explicit private/protected keyword.
          InPrivate   := False;
          InProtected := False;
        end
        else if Token.Kind = tkI_end then
        begin
          InClass     := False;
          InPrivate   := False;
          InProtected := False;
        end;

        // Track visibility
        if InClass then
        begin
          if Token.Kind = tkI_private then
          begin
            InPrivate   := True;
            InProtected := False;
          end
          else if Token.Kind = tkI_protected then
          begin
            InPrivate   := False;
            InProtected := True;
          end
          else if Token.Kind in [ tkI_public, tkI_published ] then
          begin
            InPrivate   := False;
            InProtected := False;
          end;
        end;

        // Track parameter lists
        if Token.Kind = tkLParan then
        begin
          // When in a method declaration, the first ( starts the parameter list
          if InMethodDeclaration and ( ParenDepth = 0 ) then
            InParameterList := True;
          Inc( ParenDepth );
        end
        else if Token.Kind = tkRParan then
        begin
          Dec( ParenDepth );
          if ParenDepth <= 0 then
          begin
            InParameterList := False;
            ParenDepth := 0;
          end;
        end;

        // Check type definitions and field declarations
        // Note: Both checks are combined because look-ahead consumes the next token
        // Skip when inside parentheses (e.g., default parameter values like "Boolean = True")
        if InType and ( Token.Kind = tkIdent ) and ( ParenDepth = 0 ) then
        begin
          IdentToken := Token;

          // Look ahead to determine if this is a type definition (=) or field (:)
          if Lexer.NextToken( Token ) then
          begin
            // Update ParenDepth for tokens consumed via look-ahead
            if Token.Kind = tkLParan then
              Inc( ParenDepth )
            else if Token.Kind = tkRParan then
              Dec( ParenDepth );

            if Token.Kind = tkEqual then
            begin
              // It's a type definition - look for the type being defined
              if Lexer.NextToken( Token ) then
              begin
                // Skip "packed" if present
                if Token.Kind = tkI_packed then
                  Lexer.NextToken( Token );

                // Check what kind of type it is
                if Token.Kind = tkI_class then
                begin
                  // We consumed the 'class' keyword via look-ahead, so set InClass here
                  InClass     := True;
                  InPrivate   := False;
                  InProtected := False;

                  // Check for T prefix
                  if CheckTypes then
                  begin
                    if CheckName( IdentToken.Value, 'TypePrefix', 'T', IdentToken.Line,
                       IdentToken.Column, FileName, UnitName, 'Warning', Violation ) then
                      ViolationList.Add( Violation );
                  end;
                end
                else if Token.Kind = tkI_interface then
                begin
                  // Check for I prefix
                  if CheckInterfaces then
                  begin
                    if CheckName( IdentToken.Value, 'InterfacePrefix', 'I', IdentToken.Line,
                       IdentToken.Column, FileName, UnitName, 'Warning', Violation ) then
                      ViolationList.Add( Violation );
                  end;
                end
                else if Token.Kind = tkI_record then
                begin
                  // Check for T prefix
                  if CheckTypes then
                  begin
                    if CheckName( IdentToken.Value, 'TypePrefix', 'T', IdentToken.Line,
                       IdentToken.Column, FileName, UnitName, 'Warning', Violation ) then
                      ViolationList.Add( Violation );
                  end;
                end
                else if Token.Kind = tkPointer then
                begin
                  // Pointer type (^Something)
                  if CheckPointers then
                  begin
                    if CheckName( IdentToken.Value, 'PointerPrefix', 'P', IdentToken.Line,
                       IdentToken.Column, FileName, UnitName, 'Info', Violation ) then
                      ViolationList.Add( Violation );
                  end;
                end
                else if ( Token.Kind = tkI_type ) or ( Token.Kind = tkIdent ) then
                begin
                  // Type alias or enumeration - check if it's Exception-derived
                  if SameText( Token.Value, 'Exception' ) or
                     ( Pos( 'EXCEPTION', UpperCase( Token.Value ) ) > 0 ) then
                  begin
                    if CheckExceptions then
                    begin
                      if CheckName( IdentToken.Value, 'ExceptionPrefix', 'E', IdentToken.Line,
                         IdentToken.Column, FileName, UnitName, 'Warning', Violation ) then
                        ViolationList.Add( Violation );
                    end;
                  end
                  else
                  begin
                    // Generic type alias - check for T prefix
                    // Skip built-in types (Boolean, Integer, etc.) - these are valid type aliases
                    // and also appear in default parameter values like "Boolean = True"
                    if CheckTypes and not IsBuiltInType( IdentToken.Value ) then
                    begin
                      if CheckName( IdentToken.Value, 'TypePrefix', 'T', IdentToken.Line,
                         IdentToken.Column, FileName, UnitName, 'Info', Violation ) then
                        ViolationList.Add( Violation );
                    end;
                  end;
                end;
              end;
            end
            else if ( Token.Kind = tkColon ) and InClass and ( InPrivate or InProtected )
                    and not InMethodDeclaration then
            begin
              // It's a field declaration inside a class - check for F prefix
              if CheckFields then
              begin
                if CheckName( IdentToken.Value, 'FieldPrefix', 'F', IdentToken.Line,
                   IdentToken.Column, FileName, UnitName, 'Warning', Violation ) then
                  ViolationList.Add( Violation );
              end;
            end;
          end;
        end
        // Check field declarations in classes (when not in type section or method declaration)
        else if InClass and ( InPrivate or InProtected ) and ( Token.Kind = tkIdent )
                and not InMethodDeclaration then
        begin
          IdentToken := Token;

          // Look ahead for : to confirm it's a field declaration
          if Lexer.NextToken( Token ) then
          begin
            if Token.Kind = tkColon then
            begin
              // It's a field declaration
              if CheckFields then
              begin
                if CheckName( IdentToken.Value, 'FieldPrefix', 'F', IdentToken.Line,
                   IdentToken.Column, FileName, UnitName, 'Warning', Violation ) then
                  ViolationList.Add( Violation );
              end;
            end;
          end;
        end;

        // Check parameter names
        if InParameterList and ( Token.Kind = tkIdent ) and CheckParameters then
        begin
          IdentToken := Token;

          // Look ahead for : or , or ; to confirm it's a parameter name
          if Lexer.NextToken( Token ) then
          begin
            // Update state for consumed token (look-ahead consumes tokens)
            if Token.Kind = tkRParan then
            begin
              Dec( ParenDepth );
              if ParenDepth <= 0 then
              begin
                InParameterList := False;
                ParenDepth := 0;
              end;
            end
            else if Token.Kind = tkLParan then
              Inc( ParenDepth );

            if Token.Kind in [ tkColon, tkComma, tkSemicolon ] then
            begin
              if CheckName( IdentToken.Value, 'ParameterPrefix', 'A', IdentToken.Line,
                 IdentToken.Column, FileName, UnitName, 'Info', Violation ) then
                ViolationList.Add( Violation );
            end;
          end;
        end;
      end;

      Violations := ViolationList.ToArray;
      Result     := True;
    finally
      Lexer.Free;
    end;
  finally
    ViolationList.Free;
  end;

end;

function TStyleChecker.CheckProject( const Project: IOTAProject;
  out AllViolations: TArray<TStyleViolation>; OnProgress: TNotifyEvent ): Boolean;
var
  I: Integer;
  ModuleInfo: IOTAModuleInfo;
  FileName: string;
  Violations: TArray<TStyleViolation>;
  AllViolationList: TList<TStyleViolation>;
  Violation: TStyleViolation;
begin

  Result := False;
  SetLength( AllViolations, 0 );

  if Project = nil then
    Exit;

  AllViolationList := TList<TStyleViolation>.Create;

  try
    for I := 0 to Project.GetModuleCount - 1 do
    begin
      ModuleInfo := Project.GetModule( I );
      FileName   := ModuleInfo.FileName;

      if SameText( ExtractFileExt( FileName ), '.pas' ) then
      begin

        if Assigned( OnProgress ) then
        begin
          FProgressFileName := ExtractFileName( FileName );
          OnProgress( Self );
        end;

        if CheckFile( FileName, Violations ) then
        begin

          for Violation in Violations do
            AllViolationList.Add( Violation );
        end;
      end;
    end;

    AllViolations := AllViolationList.ToArray;
    Result        := True;
  finally
    AllViolationList.Free;
  end;

end;

{ TCodeStyleCheckerPlugin }

constructor TCodeStyleCheckerPlugin.Create;
begin

  inherited Create( AppDataDirectory + '\CodeStyleChecker.xml', 'CodeStyleChecker' );

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem         := TMenuItem.Create( DDevExtensionsMenu );
    FMenuItem.Caption := 'Code &Style Checker...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add( FMenuItem );
  end;

end;

destructor TCodeStyleCheckerPlugin.Destroy;
begin

  FreeAndNil( FMenuItem );
  inherited Destroy;

end;

procedure TCodeStyleCheckerPlugin.Init;
begin

  FEnabled         := True;
  FCheckTypes      := True;
  FCheckInterfaces := True;
  FCheckFields     := True;
  FCheckExceptions := True;
  FCheckPointers   := True;
  FCheckParameters := False;

end;

function TCodeStyleCheckerPlugin.GetOptionPages: TTreePage;
begin

  Result := TTreePage.Create( 'Code Style Checker', TFrameOptionPageCodeStyle, Self );

end;

procedure TCodeStyleCheckerPlugin.MenuItemClick( Sender: TObject );
begin

  ShowChecker;

end;

procedure TCodeStyleCheckerPlugin.ShowChecker;
begin

  TFormCodeStyleChecker.Execute;

end;

procedure InitPlugin( Unload: Boolean );
begin

  if not Unload then
    CodeStyleCheckerPlugin := TCodeStyleCheckerPlugin.Create
  else
  begin
    CodeStyleCheckerPlugin.Free;
    CodeStyleCheckerPlugin := nil;
  end;

end;

end.
