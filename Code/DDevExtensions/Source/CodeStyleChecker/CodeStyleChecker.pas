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

  TTypePrefixRule = record
    TypePattern: string;   // e.g., 'String', 'Integer', 'TStringList'
    Prefix: string;        // e.g., 's', 'i', 'l'
    Enabled: Boolean;
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
    FCheckVariablePrefixes: Boolean;
    FCheckUnitScopeNames: Boolean;
    FTypePrefixRules: TArray<TTypePrefixRule>;
    FMenuItem: TMenuItem;
    procedure MenuItemClick( Sender: TObject );
    function GetTypePrefixRulesAsString: string;
    procedure SetTypePrefixRulesFromString( const Value: string );
  protected
    function GetOptionPages: TTreePage; override;
    procedure Init; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ShowChecker;
    procedure InitDefaultTypePrefixRules;
    property TypePrefixRules: TArray<TTypePrefixRule> read FTypePrefixRules write FTypePrefixRules;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
    property CheckTypes: Boolean read FCheckTypes write FCheckTypes;
    property CheckInterfaces: Boolean read FCheckInterfaces write FCheckInterfaces;
    property CheckFields: Boolean read FCheckFields write FCheckFields;
    property CheckExceptions: Boolean read FCheckExceptions write FCheckExceptions;
    property CheckPointers: Boolean read FCheckPointers write FCheckPointers;
    property CheckParameters: Boolean read FCheckParameters write FCheckParameters;
    property CheckVariablePrefixes: Boolean read FCheckVariablePrefixes write FCheckVariablePrefixes;
    property CheckUnitScopeNames: Boolean read FCheckUnitScopeNames write FCheckUnitScopeNames;
    property TypePrefixRulesData: string read GetTypePrefixRulesAsString write SetTypePrefixRulesFromString;
  end;

procedure InitPlugin( Unload: Boolean );

var
  CodeStyleCheckerPlugin: TCodeStyleCheckerPlugin;

implementation

uses
  Forms, Controls, StrUtils, ToolsAPIHelpers, AppConsts, DelphiLexer,
  FrmCodeStyleChecker, FrmeOptionPageCodeStyle;

type
  TUnitScopeMapping = record
    UnitName: string;
    QualifiedName: string;
  end;

const
  // Common unit scope name mappings (XE2+)
  // This covers the most commonly used units that should use unit scope prefixes
  UnitScopeMappings: array[ 0..96 ] of TUnitScopeMapping = (
    // System units
    ( UnitName: 'SysUtils';        QualifiedName: 'System.SysUtils' ),
    ( UnitName: 'Classes';         QualifiedName: 'System.Classes' ),
    ( UnitName: 'Types';           QualifiedName: 'System.Types' ),
    ( UnitName: 'TypInfo';         QualifiedName: 'System.TypInfo' ),
    ( UnitName: 'Variants';        QualifiedName: 'System.Variants' ),
    ( UnitName: 'VarUtils';        QualifiedName: 'System.VarUtils' ),
    ( UnitName: 'StrUtils';        QualifiedName: 'System.StrUtils' ),
    ( UnitName: 'DateUtils';       QualifiedName: 'System.DateUtils' ),
    ( UnitName: 'Math';            QualifiedName: 'System.Math' ),
    ( UnitName: 'IOUtils';         QualifiedName: 'System.IOUtils' ),
    ( UnitName: 'IniFiles';        QualifiedName: 'System.IniFiles' ),
    ( UnitName: 'Registry';        QualifiedName: 'System.Registry' ),
    ( UnitName: 'RegularExpressions'; QualifiedName: 'System.RegularExpressions' ),
    ( UnitName: 'SyncObjs';        QualifiedName: 'System.SyncObjs' ),
    ( UnitName: 'Contnrs';         QualifiedName: 'System.Contnrs' ),
    ( UnitName: 'Actions';         QualifiedName: 'System.Actions' ),
    ( UnitName: 'ImageList';       QualifiedName: 'System.ImageList' ),
    ( UnitName: 'UITypes';         QualifiedName: 'System.UITypes' ),
    ( UnitName: 'Rtti';            QualifiedName: 'System.Rtti' ),
    ( UnitName: 'Masks';           QualifiedName: 'System.Masks' ),
    ( UnitName: 'AnsiStrings';     QualifiedName: 'System.AnsiStrings' ),
    ( UnitName: 'Character';       QualifiedName: 'System.Character' ),
    ( UnitName: 'NetEncoding';     QualifiedName: 'System.NetEncoding' ),
    ( UnitName: 'Hash';            QualifiedName: 'System.Hash' ),
    ( UnitName: 'JSON';            QualifiedName: 'System.JSON' ),
    ( UnitName: 'Zip';             QualifiedName: 'System.Zip' ),
    ( UnitName: 'Zlib';            QualifiedName: 'System.Zlib' ),
    ( UnitName: 'ZLibConst';       QualifiedName: 'System.ZLibConst' ),
    ( UnitName: 'TimeSpan';        QualifiedName: 'System.TimeSpan' ),
    ( UnitName: 'Generics.Collections'; QualifiedName: 'System.Generics.Collections' ),
    ( UnitName: 'Generics.Defaults'; QualifiedName: 'System.Generics.Defaults' ),
    // Vcl units
    ( UnitName: 'Forms';           QualifiedName: 'Vcl.Forms' ),
    ( UnitName: 'Controls';        QualifiedName: 'Vcl.Controls' ),
    ( UnitName: 'StdCtrls';        QualifiedName: 'Vcl.StdCtrls' ),
    ( UnitName: 'ExtCtrls';        QualifiedName: 'Vcl.ExtCtrls' ),
    ( UnitName: 'Dialogs';         QualifiedName: 'Vcl.Dialogs' ),
    ( UnitName: 'Graphics';        QualifiedName: 'Vcl.Graphics' ),
    ( UnitName: 'Menus';           QualifiedName: 'Vcl.Menus' ),
    ( UnitName: 'ComCtrls';        QualifiedName: 'Vcl.ComCtrls' ),
    ( UnitName: 'Buttons';         QualifiedName: 'Vcl.Buttons' ),
    ( UnitName: 'ActnList';        QualifiedName: 'Vcl.ActnList' ),
    ( UnitName: 'ImgList';         QualifiedName: 'Vcl.ImgList' ),
    ( UnitName: 'Grids';           QualifiedName: 'Vcl.Grids' ),
    ( UnitName: 'ValEdit';         QualifiedName: 'Vcl.ValEdit' ),
    ( UnitName: 'DBGrids';         QualifiedName: 'Vcl.DBGrids' ),
    ( UnitName: 'DBCtrls';         QualifiedName: 'Vcl.DBCtrls' ),
    ( UnitName: 'Clipbrd';         QualifiedName: 'Vcl.Clipbrd' ),
    ( UnitName: 'Printers';        QualifiedName: 'Vcl.Printers' ),
    ( UnitName: 'Themes';          QualifiedName: 'Vcl.Themes' ),
    ( UnitName: 'Styles';          QualifiedName: 'Vcl.Styles' ),
    ( UnitName: 'Mask';            QualifiedName: 'Vcl.Mask' ),
    ( UnitName: 'CheckLst';        QualifiedName: 'Vcl.CheckLst' ),
    ( UnitName: 'FileCtrl';        QualifiedName: 'Vcl.FileCtrl' ),
    ( UnitName: 'CategoryButtons'; QualifiedName: 'Vcl.CategoryButtons' ),
    ( UnitName: 'ButtonGroup';     QualifiedName: 'Vcl.ButtonGroup' ),
    ( UnitName: 'ExtDlgs';         QualifiedName: 'Vcl.ExtDlgs' ),
    ( UnitName: 'ToolWin';         QualifiedName: 'Vcl.ToolWin' ),
    ( UnitName: 'AppEvnts';        QualifiedName: 'Vcl.AppEvnts' ),
    ( UnitName: 'OleCtrls';        QualifiedName: 'Vcl.OleCtrls' ),
    ( UnitName: 'StdActns';        QualifiedName: 'Vcl.StdActns' ),
    ( UnitName: 'Samples';         QualifiedName: 'Vcl.Samples' ),
    // Winapi units
    ( UnitName: 'Windows';         QualifiedName: 'Winapi.Windows' ),
    ( UnitName: 'Messages';        QualifiedName: 'Winapi.Messages' ),
    ( UnitName: 'ShellAPI';        QualifiedName: 'Winapi.ShellAPI' ),
    ( UnitName: 'ShlObj';          QualifiedName: 'Winapi.ShlObj' ),
    ( UnitName: 'CommCtrl';        QualifiedName: 'Winapi.CommCtrl' ),
    ( UnitName: 'CommDlg';         QualifiedName: 'Winapi.CommDlg' ),
    ( UnitName: 'ActiveX';         QualifiedName: 'Winapi.ActiveX' ),
    ( UnitName: 'WinSock';         QualifiedName: 'Winapi.WinSock' ),
    ( UnitName: 'WinSock2';        QualifiedName: 'Winapi.WinSock2' ),
    ( UnitName: 'WinInet';         QualifiedName: 'Winapi.WinInet' ),
    ( UnitName: 'TlHelp32';        QualifiedName: 'Winapi.TlHelp32' ),
    ( UnitName: 'PsAPI';           QualifiedName: 'Winapi.PsAPI' ),
    ( UnitName: 'MMSystem';        QualifiedName: 'Winapi.MMSystem' ),
    ( UnitName: 'RichEdit';        QualifiedName: 'Winapi.RichEdit' ),
    ( UnitName: 'UxTheme';         QualifiedName: 'Winapi.UxTheme' ),
    ( UnitName: 'DwmApi';          QualifiedName: 'Winapi.DwmApi' ),
    ( UnitName: 'GDIPAPI';         QualifiedName: 'Winapi.GDIPAPI' ),
    ( UnitName: 'GDIPOBJ';         QualifiedName: 'Winapi.GDIPOBJ' ),
    ( UnitName: 'Winsvc';          QualifiedName: 'Winapi.Winsvc' ),
    ( UnitName: 'ImageHlp';        QualifiedName: 'Winapi.ImageHlp' ),
    // Data units
    ( UnitName: 'DB';              QualifiedName: 'Data.DB' ),
    ( UnitName: 'DBCommon';        QualifiedName: 'Data.DBCommon' ),
    ( UnitName: 'FMTBcd';          QualifiedName: 'Data.FMTBcd' ),
    ( UnitName: 'SqlExpr';         QualifiedName: 'Data.SqlExpr' ),
    ( UnitName: 'SqlTimSt';        QualifiedName: 'Data.SqlTimSt' ),
    // Datasnap units
    ( UnitName: 'DBClient';        QualifiedName: 'Datasnap.DBClient' ),
    ( UnitName: 'Provider';        QualifiedName: 'Datasnap.Provider' ),
    // XML units
    ( UnitName: 'XMLIntf';         QualifiedName: 'Xml.XMLIntf' ),
    ( UnitName: 'XMLDoc';          QualifiedName: 'Xml.XMLDoc' ),
    ( UnitName: 'XMLDom';          QualifiedName: 'Xml.XMLDom' ),
    ( UnitName: 'OmniXML';         QualifiedName: 'Xml.OmniXML' ),
    // Internet units
    ( UnitName: 'Web.HTTPApp';     QualifiedName: 'Web.HTTPApp' ),
    // Soap units
    ( UnitName: 'InvokeRegistry';  QualifiedName: 'Soap.InvokeRegistry' ),
    ( UnitName: 'XSBuiltIns';      QualifiedName: 'Soap.XSBuiltIns' ),
    // REST units
    ( UnitName: 'REST.Client';     QualifiedName: 'REST.Client' ),
    ( UnitName: 'REST.Types';      QualifiedName: 'REST.Types' )
  );

function GetQualifiedUnitName( const UnitName: string ): string;
var
  I: Integer;
begin

  Result := '';

  for I := Low( UnitScopeMappings ) to High( UnitScopeMappings ) do
  begin
    if SameText( UnitScopeMappings[ I ].UnitName, UnitName ) then
    begin
      Result := UnitScopeMappings[ I ].QualifiedName;
      Exit;
    end;
  end;

end;

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

function MatchesTypePattern( const TypeName, Pattern: string ): Boolean;
begin

  // Case-insensitive match - pattern matches if type name starts with pattern
  Result := SameText( TypeName, Pattern ) or
            ( Pos( UpperCase( Pattern ), UpperCase( TypeName ) ) = 1 );

end;

function FindMoreSpecificRule( const TypeName: string; MatchedIndex: Integer ): string;
var
  J: Integer;
  MatchedPattern: string;
begin

  // Check if there's a more specific rule (longer pattern) that also matches
  // Returns the pattern name if found, empty string if not
  Result := '';

  if CodeStyleCheckerPlugin = nil then
    Exit;

  MatchedPattern := CodeStyleCheckerPlugin.TypePrefixRules[ MatchedIndex ].TypePattern;

  for J := 0 to High( CodeStyleCheckerPlugin.TypePrefixRules ) do
  begin
    if J = MatchedIndex then
      Continue;

    if not CodeStyleCheckerPlugin.TypePrefixRules[ J ].Enabled then
      Continue;

    // Check if this rule's pattern is more specific (longer) and also matches
    if ( Length( CodeStyleCheckerPlugin.TypePrefixRules[ J ].TypePattern ) >
         Length( MatchedPattern ) ) and
       MatchesTypePattern( TypeName, CodeStyleCheckerPlugin.TypePrefixRules[ J ].TypePattern ) then
    begin
      Result := CodeStyleCheckerPlugin.TypePrefixRules[ J ].TypePattern;
      Exit;  // Return first more specific match found
    end;
  end;

end;

function TStyleChecker.CheckFile( const FileName: string;
  out Violations: TArray<TStyleViolation> ): Boolean;
var
  Content: UTF8String;
  Lexer: TDelphiLexer;
  Token, IdentToken, TypeToken: TToken;
  ViolationList: TList<TStyleViolation>;
  Violation: TStyleViolation;
  UnitName, TypeName, QualifiedName: string;
  InType, InClass: Boolean;
  InPrivate, InProtected: Boolean;
  InParameterList, InMethodDeclaration: Boolean;
  InVarSection, InUsesClause: Boolean;
  ParenDepth: Integer;
  CheckTypes, CheckInterfaces, CheckFields: Boolean;
  CheckExceptions, CheckPointers, CheckParameters: Boolean;
  CheckVariablePrefixes, CheckUnitScopeNames: Boolean;
  I: Integer;
begin

  Result := False;
  SetLength( Violations, 0 );

  if not FileExists( FileName ) then
    Exit;

  // Get enabled checks from plugin
  if CodeStyleCheckerPlugin <> nil then
  begin
    CheckTypes           := CodeStyleCheckerPlugin.CheckTypes;
    CheckInterfaces      := CodeStyleCheckerPlugin.CheckInterfaces;
    CheckFields          := CodeStyleCheckerPlugin.CheckFields;
    CheckExceptions      := CodeStyleCheckerPlugin.CheckExceptions;
    CheckPointers        := CodeStyleCheckerPlugin.CheckPointers;
    CheckParameters      := CodeStyleCheckerPlugin.CheckParameters;
    CheckVariablePrefixes := CodeStyleCheckerPlugin.CheckVariablePrefixes;
    CheckUnitScopeNames  := CodeStyleCheckerPlugin.CheckUnitScopeNames;
  end
  else
  begin
    CheckTypes           := True;
    CheckInterfaces      := True;
    CheckFields          := True;
    CheckExceptions      := True;
    CheckPointers        := True;
    CheckParameters      := False;
    CheckVariablePrefixes := False;
    CheckUnitScopeNames  := False;
  end;

  try
    Content := LoadTextFileToUtf8String( FileName );
  except
    Exit;
  end;

  UnitName            := ChangeFileExt( ExtractFileName( FileName ), '' );
  ViolationList       := TList<TStyleViolation>.Create;
  InType              := False;
  InClass             := False;
  InPrivate           := False;
  InProtected         := False;
  InParameterList     := False;
  InMethodDeclaration := False;
  InVarSection        := False;
  InUsesClause        := False;
  ParenDepth          := 0;

  try
    Lexer := TDelphiLexer.Create( FileName, Content );

    try
      while Lexer.NextToken( Token ) do
      begin
        // Track uses clause
        if Token.Kind = tkI_uses then
        begin
          InUsesClause := True;
        end
        else if InUsesClause and ( Token.Kind = tkSemicolon ) then
        begin
          InUsesClause := False;
        end;

        // Check unit names in uses clause for missing scope prefix
        if InUsesClause and ( Token.Kind = tkIdent ) and CheckUnitScopeNames then
        begin
          // Only check identifiers that are not already qualified
          // (if the next token is a dot, it's a scope prefix, so skip)
          IdentToken := Token;

          // Peek at the next token to see if this is already qualified
          if Lexer.NextToken( Token ) then
          begin
            if Token.Kind <> tkQualifier then
            begin
              // Not qualified - check if it should be
              QualifiedName := GetQualifiedUnitName( IdentToken.Value );

              if QualifiedName <> '' then
              begin
                Violation.FileName := FileName;
                Violation.UnitName := UnitName;
                Violation.Line     := IdentToken.Line + 1;
                Violation.Column   := IdentToken.Column;
                Violation.Rule     := 'UnitScopePrefix';
                Violation.Expected := QualifiedName;
                Violation.Actual   := IdentToken.Value;
                Violation.Severity := 'Warning';
                ViolationList.Add( Violation );
              end;
            end;
            // Note: Token was consumed by peek, continue with it in the loop
            // We need to handle this token, so continue with current token checks
          end;
        end;

        // Track type section
        if Token.Kind = tkI_type then
        begin
          InType       := True;
          InClass      := False;
          InVarSection := False;
        end
        else if Token.Kind = tkI_var then
        begin
          // Enter var section (but not inside a class - those are fields)
          if not InClass then
          begin
            InType       := False;
            InVarSection := True;
          end;
        end
        else if Token.Kind in [ tkI_const, tkI_implementation,
                                tkI_procedure, tkI_function, tkI_constructor,
                                tkI_destructor, tkI_begin ] then
        begin
          // End var section on other keywords
          InVarSection := False;

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
              // It's a field declaration inside a class
              // Get the field's type to check for variable prefix rules
              TypeName := '';
              if Lexer.NextToken( TypeToken ) then
              begin
                if TypeToken.Kind = tkIdent then
                  TypeName := TypeToken.Value;
              end;

              // If variable prefix rules are enabled and the type matches a rule,
              // check against that rule instead of the F prefix rule
              if CheckVariablePrefixes and ( TypeName <> '' ) and ( CodeStyleCheckerPlugin <> nil ) then
              begin
                for I := 0 to High( CodeStyleCheckerPlugin.TypePrefixRules ) do
                begin
                  if not CodeStyleCheckerPlugin.TypePrefixRules[ I ].Enabled then
                    Continue;

                  if MatchesTypePattern( TypeName, CodeStyleCheckerPlugin.TypePrefixRules[ I ].TypePattern ) then
                  begin
                    // Type matches a rule - check against type prefix, not F prefix
                    if CheckName( IdentToken.Value, 'FieldTypePrefix',
                       CodeStyleCheckerPlugin.TypePrefixRules[ I ].Prefix, IdentToken.Line,
                       IdentToken.Column, FileName, UnitName, 'Warning', Violation ) then
                    begin
                      Violation.Expected := CodeStyleCheckerPlugin.TypePrefixRules[ I ].Prefix +
                                            '... (for ' + CodeStyleCheckerPlugin.TypePrefixRules[ I ].TypePattern + ')';

                      // Check for more specific rule that also matches
                      QualifiedName := FindMoreSpecificRule( TypeName, I );
                      if QualifiedName <> '' then
                        Violation.Expected := Violation.Expected + ' [Note: also matches ' + QualifiedName + ' rule]';

                      ViolationList.Add( Violation );
                    end;
                    TypeName := '';  // Mark as handled
                    Break;
                  end;
                end;
              end;

              // If no type prefix rule matched, check for standard F prefix
              if ( TypeName <> '' ) and CheckFields then
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
              // Get the field's type to check for variable prefix rules
              TypeName := '';
              if Lexer.NextToken( TypeToken ) then
              begin
                if TypeToken.Kind = tkIdent then
                  TypeName := TypeToken.Value;
              end;

              // If variable prefix rules are enabled and the type matches a rule,
              // check against that rule instead of the F prefix rule
              if CheckVariablePrefixes and ( TypeName <> '' ) and ( CodeStyleCheckerPlugin <> nil ) then
              begin
                for I := 0 to High( CodeStyleCheckerPlugin.TypePrefixRules ) do
                begin
                  if not CodeStyleCheckerPlugin.TypePrefixRules[ I ].Enabled then
                    Continue;

                  if MatchesTypePattern( TypeName, CodeStyleCheckerPlugin.TypePrefixRules[ I ].TypePattern ) then
                  begin
                    // Type matches a rule - check against type prefix, not F prefix
                    if CheckName( IdentToken.Value, 'FieldTypePrefix',
                       CodeStyleCheckerPlugin.TypePrefixRules[ I ].Prefix, IdentToken.Line,
                       IdentToken.Column, FileName, UnitName, 'Warning', Violation ) then
                    begin
                      Violation.Expected := CodeStyleCheckerPlugin.TypePrefixRules[ I ].Prefix +
                                            '... (for ' + CodeStyleCheckerPlugin.TypePrefixRules[ I ].TypePattern + ')';

                      // Check for more specific rule that also matches
                      QualifiedName := FindMoreSpecificRule( TypeName, I );
                      if QualifiedName <> '' then
                        Violation.Expected := Violation.Expected + ' [Note: also matches ' + QualifiedName + ' rule]';

                      ViolationList.Add( Violation );
                    end;
                    TypeName := '';  // Mark as handled
                    Break;
                  end;
                end;
              end;

              // If no type prefix rule matched, check for standard F prefix
              if ( TypeName <> '' ) and CheckFields then
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

        // Check variable declarations in var section
        if InVarSection and ( Token.Kind = tkIdent ) and CheckVariablePrefixes and
           ( CodeStyleCheckerPlugin <> nil ) and not InClass then
        begin
          IdentToken := Token;

          // Look ahead for : to confirm it's a variable declaration
          if Lexer.NextToken( Token ) then
          begin
            if Token.Kind = tkColon then
            begin
              // Get the type name
              if Lexer.NextToken( TypeToken ) then
              begin
                TypeName := '';

                // Handle identifier types (String, Integer, TMyClass, etc.)
                if TypeToken.Kind = tkIdent then
                  TypeName := TypeToken.Value
                // Handle array of X types
                else if TypeToken.Kind = tkI_array then
                begin
                  // Look for 'of' keyword
                  if Lexer.NextToken( Token ) and ( Token.Kind = tkI_of ) then
                  begin
                    // Get the element type
                    if Lexer.NextToken( Token ) and ( Token.Kind = tkIdent ) then
                      TypeName := 'array of ' + Token.Value;
                  end;
                end;

                // Check against type prefix rules if we have a type name
                if TypeName <> '' then
                begin
                  for I := 0 to High( CodeStyleCheckerPlugin.TypePrefixRules ) do
                  begin
                    if not CodeStyleCheckerPlugin.TypePrefixRules[ I ].Enabled then
                      Continue;

                    if MatchesTypePattern( TypeName, CodeStyleCheckerPlugin.TypePrefixRules[ I ].TypePattern ) then
                    begin
                      if CheckName( IdentToken.Value, 'VariablePrefix',
                         CodeStyleCheckerPlugin.TypePrefixRules[ I ].Prefix, IdentToken.Line,
                         IdentToken.Column, FileName, UnitName, 'Warning', Violation ) then
                      begin
                        Violation.Expected := CodeStyleCheckerPlugin.TypePrefixRules[ I ].Prefix +
                                              '... (for ' + CodeStyleCheckerPlugin.TypePrefixRules[ I ].TypePattern + ')';

                        // Check for more specific rule that also matches
                        QualifiedName := FindMoreSpecificRule( TypeName, I );
                        if QualifiedName <> '' then
                          Violation.Expected := Violation.Expected + ' [Note: also matches ' + QualifiedName + ' rule]';

                        ViolationList.Add( Violation );
                      end;

                      Break;  // First matching rule wins
                    end;
                  end;
                end;
              end;
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

  FEnabled              := True;
  FCheckTypes           := True;
  FCheckInterfaces      := True;
  FCheckFields          := True;
  FCheckExceptions      := True;
  FCheckPointers        := True;
  FCheckParameters      := False;
  FCheckVariablePrefixes := False;  // Off by default - user must enable
  FCheckUnitScopeNames  := False;   // Off by default - user must enable
  InitDefaultTypePrefixRules;

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

function TCodeStyleCheckerPlugin.GetTypePrefixRulesAsString: string;
var
  I: Integer;
  SB: TStringBuilder;
begin

  // Format: TypePattern|Prefix|Enabled;TypePattern|Prefix|Enabled;...
  SB := TStringBuilder.Create;

  try
    for I := 0 to High( FTypePrefixRules ) do
    begin
      if I > 0 then
        SB.Append( ';' );

      SB.Append( FTypePrefixRules[ I ].TypePattern );
      SB.Append( '|' );
      SB.Append( FTypePrefixRules[ I ].Prefix );
      SB.Append( '|' );
      SB.Append( IfThen( FTypePrefixRules[ I ].Enabled, '1', '0' ) );
    end;

    Result := SB.ToString;
  finally
    SB.Free;
  end;

end;

procedure TCodeStyleCheckerPlugin.SetTypePrefixRulesFromString( const Value: string );
var
  Rules: TArray<string>;
  Parts: TArray<string>;
  I: Integer;
begin

  if Value = '' then
  begin
    InitDefaultTypePrefixRules;
    Exit;
  end;

  Rules := Value.Split( [ ';' ] );
  SetLength( FTypePrefixRules, Length( Rules ) );

  for I := 0 to High( Rules ) do
  begin
    Parts := Rules[ I ].Split( [ '|' ] );

    if Length( Parts ) >= 2 then
    begin
      FTypePrefixRules[ I ].TypePattern := Parts[ 0 ];
      FTypePrefixRules[ I ].Prefix      := Parts[ 1 ];
      FTypePrefixRules[ I ].Enabled     := ( Length( Parts ) < 3 ) or ( Parts[ 2 ] = '1' );
    end;
  end;

end;

procedure TCodeStyleCheckerPlugin.InitDefaultTypePrefixRules;
begin

  SetLength( FTypePrefixRules, 13 );

  // Simple types
  FTypePrefixRules[ 0 ].TypePattern := 'String';
  FTypePrefixRules[ 0 ].Prefix      := 's';
  FTypePrefixRules[ 0 ].Enabled     := True;

  FTypePrefixRules[ 1 ].TypePattern := 'Integer';
  FTypePrefixRules[ 1 ].Prefix      := 'i';
  FTypePrefixRules[ 1 ].Enabled     := True;

  FTypePrefixRules[ 2 ].TypePattern := 'Boolean';
  FTypePrefixRules[ 2 ].Prefix      := 'l';
  FTypePrefixRules[ 2 ].Enabled     := True;

  FTypePrefixRules[ 3 ].TypePattern := 'Real';
  FTypePrefixRules[ 3 ].Prefix      := 'r';
  FTypePrefixRules[ 3 ].Enabled     := True;

  FTypePrefixRules[ 4 ].TypePattern := 'Double';
  FTypePrefixRules[ 4 ].Prefix      := 'f';
  FTypePrefixRules[ 4 ].Enabled     := True;

  FTypePrefixRules[ 5 ].TypePattern := 'Single';
  FTypePrefixRules[ 5 ].Prefix      := 'f';
  FTypePrefixRules[ 5 ].Enabled     := True;

  FTypePrefixRules[ 6 ].TypePattern := 'Variant';
  FTypePrefixRules[ 6 ].Prefix      := 'v';
  FTypePrefixRules[ 6 ].Enabled     := True;

  FTypePrefixRules[ 7 ].TypePattern := 'Char';
  FTypePrefixRules[ 7 ].Prefix      := 'c';
  FTypePrefixRules[ 7 ].Enabled     := True;

  FTypePrefixRules[ 8 ].TypePattern := 'Currency';
  FTypePrefixRules[ 8 ].Prefix      := 'r';
  FTypePrefixRules[ 8 ].Enabled     := True;

  // Array types
  FTypePrefixRules[ 9 ].TypePattern  := 'array of String';
  FTypePrefixRules[ 9 ].Prefix       := 'sa';
  FTypePrefixRules[ 9 ].Enabled      := True;

  FTypePrefixRules[ 10 ].TypePattern := 'array of Integer';
  FTypePrefixRules[ 10 ].Prefix      := 'na';
  FTypePrefixRules[ 10 ].Enabled     := True;

  FTypePrefixRules[ 11 ].TypePattern := 'array of Double';
  FTypePrefixRules[ 11 ].Prefix      := 'na';
  FTypePrefixRules[ 11 ].Enabled     := True;

  FTypePrefixRules[ 12 ].TypePattern := 'array of Byte';
  FTypePrefixRules[ 12 ].Prefix      := 'na';
  FTypePrefixRules[ 12 ].Enabled     := True;

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
