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
    Violation.Line     := Line;
    Violation.Column   := Column;
    Violation.Rule     := RuleName;
    Violation.Expected := Prefix + '...';
    Violation.Actual   := Name;
    Violation.Severity := Severity;
    Result             := True;
  end;

end;

function TStyleChecker.CheckFile( const FileName: string;
  out Violations: TArray<TStyleViolation> ): Boolean;
var
  Content: UTF8String;
  Lexer: TDelphiLexer;
  Token, IdentToken: TToken;
  PrevTokenKind: TTokenKind;
  ViolationList: TList<TStyleViolation>;
  Violation: TStyleViolation;
  UnitName: string;
  InType, InClass: Boolean;
  InPrivate, InProtected: Boolean;
  InParameterList: Boolean;
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
  ParenDepth        := 0;

  try
    Lexer := TDelphiLexer.Create( FileName, Content );

    try
      PrevTokenKind := tkNone;

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
          InType := False;
          InClass := False;
        end;

        // Track class context
        if Token.Kind = tkI_class then
        begin
          InClass     := True;
          InPrivate   := True;  // Default visibility is private
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
          if PrevTokenKind in [ tkI_procedure, tkI_function, tkI_constructor, tkI_destructor ] then
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

        // Check type definitions
        if InType and ( Token.Kind = tkIdent ) then
        begin
          IdentToken := Token;

          // Look ahead for = to confirm it's a type definition
          if Lexer.NextToken( Token ) and ( Token.Kind = tkEqual ) then
          begin
            // Look for the type being defined
            if Lexer.NextToken( Token ) then
            begin
              // Skip "packed" if present
              if Token.Kind = tkI_packed then
                Lexer.NextToken( Token );

              // Check what kind of type it is
              if Token.Kind = tkI_class then
              begin
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
                  if CheckTypes then
                  begin
                    if CheckName( IdentToken.Value, 'TypePrefix', 'T', IdentToken.Line,
                       IdentToken.Column, FileName, UnitName, 'Info', Violation ) then
                      ViolationList.Add( Violation );
                  end;
                end;
              end;
            end;
          end;
        end;

        // Check field declarations in classes
        if InClass and ( InPrivate or InProtected ) and ( Token.Kind = tkIdent ) then
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
            if Token.Kind in [ tkColon, tkComma, tkSemicolon ] then
            begin
              if CheckName( IdentToken.Value, 'ParameterPrefix', 'A', IdentToken.Line,
                 IdentToken.Column, FileName, UnitName, 'Info', Violation ) then
                ViolationList.Add( Violation );
            end;
          end;
        end;

        PrevTokenKind := Token.Kind;
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
var
  ToolsMenu: TMenuItem;
begin

  inherited Create( AppDataDirectory + '\CodeStyleChecker.xml', 'CodeStyleChecker' );

  // Add menu item under Tools menu
  ToolsMenu := FindMenuItem( 'ToolsMenu' );

  if ToolsMenu <> nil then
  begin
    FMenuItem         := TMenuItem.Create( ToolsMenu );
    FMenuItem.Caption := 'Code &Style Checker...';
    FMenuItem.OnClick := MenuItemClick;
    ToolsMenu.Add( FMenuItem );
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
