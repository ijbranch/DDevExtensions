{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit CodeStyleChecker;

/// <summary>
/// DDevExtensions plugin that scans Pascal sources in the active project for naming-convention
/// violations (T/I/F/E/P prefixes, parameter and variable prefix rules, missing unit-scope prefixes)
/// and a configurable set of anti-patterns (empty finally, nested with, deep nesting, long methods,
/// long parameter lists). Reports violations through a dockable results form.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Generics.Collections, Menus, Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main;

type
  /// <summary>
  /// Single style or anti-pattern violation discovered while analysing a Pascal source unit.
  /// </summary>
  TStyleViolation = record
    /// <summary>Absolute path of the file containing the violation.</summary>
    FileName: string;
    /// <summary>Bare unit name (without extension) for display.</summary>
    UnitName: string;
    /// <summary>One-based line number of the violation.</summary>
    Line: Integer;
    /// <summary>Column number reported by the lexer.</summary>
    Column: Integer;
    /// <summary>Identifier of the rule that was violated (e.g. <c>TypePrefix</c>).</summary>
    Rule: string;
    /// <summary>Description of what the analyser expected to see.</summary>
    Expected: string;
    /// <summary>The offending value as found in the source.</summary>
    Actual: string;
    /// <summary>Severity classification: <c>Warning</c> or <c>Info</c>.</summary>
    Severity: string;
    /// <summary>Top-level category — <c>NamingConvention</c> or <c>AntiPattern</c>.</summary>
    Category: string;
  end;

  /// <summary>
  /// User-defined mapping that associates a type-name pattern with a required identifier prefix
  /// (for example <c>String</c> -&gt; <c>s</c>, <c>TStringList</c> -&gt; <c>l</c>).
  /// </summary>
  TTypePrefixRule = record
    /// <summary>Type pattern such as <c>String</c>, <c>Integer</c>, or <c>TStringList</c>.</summary>
    TypePattern: string;
    /// <summary>Required identifier prefix (e.g. <c>s</c>, <c>i</c>, <c>l</c>).</summary>
    Prefix: string;
    /// <summary>Whether the rule participates in checking.</summary>
    Enabled: Boolean;
  end;

  /// <summary>
  /// Built-in style rule describing one naming-convention check (e.g. types must start with T).
  /// </summary>
  TStyleRule = class
  public
    /// <summary>Short identifier of the rule.</summary>
    Name: string;
    /// <summary>Human-readable description shown to the user.</summary>
    Description: string;
    /// <summary>Required prefix for matching identifiers.</summary>
    Prefix: string;
    /// <summary>Construct category the rule applies to (Types, Interfaces, Fields, ...).</summary>
    AppliesTo: string;
    /// <summary>Whether this rule is currently enabled.</summary>
    Enabled: Boolean;
    /// <summary>Severity reported when the rule is violated.</summary>
    Severity: string;
  end;

  /// <summary>
  /// Engine that lexes Pascal source files and accumulates <see cref="TStyleViolation"/> entries
  /// according to the configured naming and anti-pattern rules.
  /// </summary>
  TStyleChecker = class
  private
    /// <summary>Built-in default rule set (independent of the user's prefix map).</summary>
    FRules: TObjectList<TStyleRule>;
    /// <summary>File currently being analysed; surfaced via <see cref="ProgressFileName"/>.</summary>
    FProgressFileName: string;
    /// <summary>Populates <see cref="FRules"/> with the standard naming-convention rules.</summary>
    procedure InitDefaultRules;
    /// <summary>
    /// Tests <paramref name="Name"/> against the required <paramref name="Prefix"/> and, when it
    /// fails, fills <paramref name="Violation"/> with the source location and rule metadata.
    /// </summary>
    /// <param name="Name">Identifier under inspection.</param>
    /// <param name="RuleName">Identifier of the rule being applied.</param>
    /// <param name="Prefix">Required leading characters.</param>
    /// <param name="Line">Zero-based line reported by the lexer (converted to 1-based).</param>
    /// <param name="Column">Column reported by the lexer.</param>
    /// <param name="FileName">Absolute path of the source file.</param>
    /// <param name="UnitName">Bare unit name for display.</param>
    /// <param name="Severity">Severity tag stored on the violation.</param>
    /// <param name="Violation">Populated when the function returns <c>True</c>.</param>
    /// <returns><c>True</c> when the identifier is non-empty and lacks the required prefix.</returns>
    function CheckName( const Name, RuleName, Prefix: string; Line, Column: Integer;
      const FileName, UnitName, Severity: string;
      var Violation: TStyleViolation ): Boolean;
  public
    /// <summary>Creates the checker and initialises the default rule set.</summary>
    constructor Create;
    /// <summary>Releases the internal rule list.</summary>
    destructor Destroy; override;
    /// <summary>
    /// Analyses a single Pascal file and returns all violations encountered.
    /// </summary>
    /// <param name="FileName">Absolute path of the source file.</param>
    /// <param name="Violations">Receives the array of detected violations.</param>
    /// <returns><c>True</c> when the file was readable and processed.</returns>
    function CheckFile( const FileName: string; out Violations: TArray<TStyleViolation> ): Boolean;
    /// <summary>
    /// Iterates every <c>.pas</c> module in the supplied IDE project and aggregates the violations.
    /// </summary>
    /// <param name="Project">Active OTA project to scan.</param>
    /// <param name="AllViolations">Receives the combined violation list.</param>
    /// <param name="OnProgress">Optional callback invoked between files (use <see cref="ProgressFileName"/>).</param>
    /// <returns><c>True</c> when scanning completed.</returns>
    function CheckProject( const Project: IOTAProject; out AllViolations: TArray<TStyleViolation>;
      OnProgress: TNotifyEvent ): Boolean;
    /// <summary>Built-in style rules.</summary>
    property Rules: TObjectList<TStyleRule> read FRules;
    /// <summary>Name of the file currently being analysed (for progress reporting).</summary>
    property ProgressFileName: string read FProgressFileName;
  end;

  /// <summary>
  /// Plugin host integrating the Code Style Checker into the DDevExtensions menu and persisting
  /// its configuration via <see cref="TPluginConfig"/>.
  /// </summary>
  TCodeStyleCheckerPlugin = class( TPluginConfig )
  private
    /// <summary>Master enable flag for the entire plugin.</summary>
    FEnabled: Boolean;
    /// <summary>Whether type-name (T) prefix checks are active.</summary>
    FCheckTypes: Boolean;
    /// <summary>Whether interface-name (I) prefix checks are active.</summary>
    FCheckInterfaces: Boolean;
    /// <summary>Whether class field (F) prefix checks are active.</summary>
    FCheckFields: Boolean;
    /// <summary>Whether exception-class (E) prefix checks are active.</summary>
    FCheckExceptions: Boolean;
    /// <summary>Whether pointer-type (P) prefix checks are active.</summary>
    FCheckPointers: Boolean;
    /// <summary>Whether parameter-name (A) prefix checks are active.</summary>
    FCheckParameters: Boolean;
    /// <summary>Whether variable-prefix rules from the type-prefix map are applied.</summary>
    FCheckVariablePrefixes: Boolean;
    /// <summary>Whether identifiers in the uses clause are required to use the unit-scope prefix.</summary>
    FCheckUnitScopeNames: Boolean;
    /// <summary>User-defined type-prefix rules used for variable and field checks.</summary>
    FTypePrefixRules: TArray<TTypePrefixRule>;
    /// <summary>Menu item added to the DDevExtensions submenu.</summary>
    FMenuItem: TMenuItem;
    // Anti-pattern detection options
    /// <summary>Master enable flag for anti-pattern detection.</summary>
    FCheckAntiPatterns: Boolean;
    /// <summary>Detect <c>finally</c> blocks containing no statements.</summary>
    FCheckEmptyFinally: Boolean;
    /// <summary>Detect <c>with</c> statements nested within other <c>with</c> blocks.</summary>
    FCheckNestedWith: Boolean;
    /// <summary>Detect control-flow nesting beyond <see cref="FMaxNestingDepth"/>.</summary>
    FCheckDeepNesting: Boolean;
    /// <summary>Detect methods exceeding <see cref="FMaxMethodLines"/> lines.</summary>
    FCheckLongMethods: Boolean;
    /// <summary>Detect parameter lists longer than <see cref="FMaxParameters"/>.</summary>
    FCheckLongParamLists: Boolean;
    /// <summary>Threshold used by the deep-nesting check.</summary>
    FMaxNestingDepth: Integer;
    /// <summary>Threshold used by the long-method check.</summary>
    FMaxMethodLines: Integer;
    /// <summary>Threshold used by the long-parameter-list check.</summary>
    FMaxParameters: Integer;
    /// <summary>Menu OnClick handler that opens the checker form.</summary>
    procedure MenuItemClick( Sender: TObject );
    /// <summary>Serialises the type-prefix rules to a single delimited string for persistence.</summary>
    function GetTypePrefixRulesAsString: string;
    /// <summary>Restores the type-prefix rules from the delimited string written by the getter.</summary>
    procedure SetTypePrefixRulesFromString( const Value: string );
  protected
    /// <summary>Returns the option page used in the DDevExtensions options dialog.</summary>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises configuration to its built-in defaults.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the plugin, loads its configuration, and registers the menu item.</summary>
    constructor Create;
    /// <summary>Removes the menu item and releases the plugin.</summary>
    destructor Destroy; override;
    /// <summary>Opens the Code Style Checker results form.</summary>
    procedure ShowChecker;
    /// <summary>
    /// Resets <see cref="TypePrefixRules"/> to the built-in defaults (s/i/l/r/f/v/c/r and array variants).
    /// </summary>
    procedure InitDefaultTypePrefixRules;
    /// <summary>User-defined type-prefix rules consulted when checking variables and fields.</summary>
    property TypePrefixRules: TArray<TTypePrefixRule> read FTypePrefixRules write FTypePrefixRules;
  published
    /// <summary>Master enable flag persisted in the configuration file.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
    /// <summary>Persisted state of the type-prefix check.</summary>
    property CheckTypes: Boolean read FCheckTypes write FCheckTypes;
    /// <summary>Persisted state of the interface-prefix check.</summary>
    property CheckInterfaces: Boolean read FCheckInterfaces write FCheckInterfaces;
    /// <summary>Persisted state of the field-prefix check.</summary>
    property CheckFields: Boolean read FCheckFields write FCheckFields;
    /// <summary>Persisted state of the exception-prefix check.</summary>
    property CheckExceptions: Boolean read FCheckExceptions write FCheckExceptions;
    /// <summary>Persisted state of the pointer-prefix check.</summary>
    property CheckPointers: Boolean read FCheckPointers write FCheckPointers;
    /// <summary>Persisted state of the parameter-prefix check.</summary>
    property CheckParameters: Boolean read FCheckParameters write FCheckParameters;
    /// <summary>Persisted state of the variable-prefix check.</summary>
    property CheckVariablePrefixes: Boolean read FCheckVariablePrefixes write FCheckVariablePrefixes;
    /// <summary>Persisted state of the unit-scope check.</summary>
    property CheckUnitScopeNames: Boolean read FCheckUnitScopeNames write FCheckUnitScopeNames;
    /// <summary>Serialised representation of <see cref="TypePrefixRules"/> for persistence.</summary>
    property TypePrefixRulesData: string read GetTypePrefixRulesAsString write SetTypePrefixRulesFromString;
    // Anti-pattern detection options
    /// <summary>Persisted master enable for anti-pattern detection.</summary>
    property CheckAntiPatterns: Boolean read FCheckAntiPatterns write FCheckAntiPatterns;
    /// <summary>Persisted state of the empty-finally check.</summary>
    property CheckEmptyFinally: Boolean read FCheckEmptyFinally write FCheckEmptyFinally;
    /// <summary>Persisted state of the nested-with check.</summary>
    property CheckNestedWith: Boolean read FCheckNestedWith write FCheckNestedWith;
    /// <summary>Persisted state of the deep-nesting check.</summary>
    property CheckDeepNesting: Boolean read FCheckDeepNesting write FCheckDeepNesting;
    /// <summary>Persisted state of the long-method check.</summary>
    property CheckLongMethods: Boolean read FCheckLongMethods write FCheckLongMethods;
    /// <summary>Persisted state of the long-parameter-list check.</summary>
    property CheckLongParamLists: Boolean read FCheckLongParamLists write FCheckLongParamLists;
    /// <summary>Persisted maximum control-flow nesting depth.</summary>
    property MaxNestingDepth: Integer read FMaxNestingDepth write FMaxNestingDepth;
    /// <summary>Persisted maximum method length, in lines.</summary>
    property MaxMethodLines: Integer read FMaxMethodLines write FMaxMethodLines;
    /// <summary>Persisted maximum number of parameters per method.</summary>
    property MaxParameters: Integer read FMaxParameters write FMaxParameters;
  end;

/// <summary>
/// Plugin lifecycle entry point — creates or releases <see cref="CodeStyleCheckerPlugin"/>.
/// </summary>
/// <param name="Unload"><c>True</c> to release the plugin, <c>False</c> to create it.</param>
procedure InitPlugin( Unload: Boolean );

var
  /// <summary>Singleton plugin instance accessed from elsewhere in the package.</summary>
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
    Violation.Category := 'NamingConvention';
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
  // Anti-pattern detection variables
  CheckAntiPatterns, CheckEmptyFinally, CheckNestedWith: Boolean;
  CheckDeepNesting, CheckLongMethods, CheckLongParamLists: Boolean;
  MaxNestingDepth, MaxMethodLines, MaxParameters: Integer;
  WithDepth: Integer;
  NestingDepth: Integer;
  MethodStartLine: Integer;
  MethodName: string;
  CurrentParamCount: Integer;
  InFinally: Boolean;
  FinallyLine: Integer;
  FinallyHasContent: Boolean;
  BeginEndDepth: Integer;
  InMethodBody: Boolean;
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
    // Anti-pattern detection settings
    CheckAntiPatterns    := CodeStyleCheckerPlugin.CheckAntiPatterns;
    CheckEmptyFinally    := CodeStyleCheckerPlugin.CheckEmptyFinally;
    CheckNestedWith      := CodeStyleCheckerPlugin.CheckNestedWith;
    CheckDeepNesting     := CodeStyleCheckerPlugin.CheckDeepNesting;
    CheckLongMethods     := CodeStyleCheckerPlugin.CheckLongMethods;
    CheckLongParamLists  := CodeStyleCheckerPlugin.CheckLongParamLists;
    MaxNestingDepth      := CodeStyleCheckerPlugin.MaxNestingDepth;
    MaxMethodLines       := CodeStyleCheckerPlugin.MaxMethodLines;
    MaxParameters        := CodeStyleCheckerPlugin.MaxParameters;
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
    CheckAntiPatterns    := False;
    CheckEmptyFinally    := True;
    CheckNestedWith      := True;
    CheckDeepNesting     := True;
    CheckLongMethods     := True;
    CheckLongParamLists  := True;
    MaxNestingDepth      := 4;
    MaxMethodLines       := 100;
    MaxParameters        := 6;
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
  // Anti-pattern state initialization
  WithDepth           := 0;
  NestingDepth        := 0;
  MethodStartLine     := 0;
  MethodName          := '';
  CurrentParamCount   := 0;
  InFinally           := False;
  FinallyLine         := 0;
  FinallyHasContent   := False;
  BeginEndDepth       := 0;
  InMethodBody        := False;

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

        // =================================================================
        // Anti-pattern detection
        // =================================================================
        if CheckAntiPatterns then
        begin
          // Track method start/end for long method detection
          if Token.Kind in [ tkI_procedure, tkI_function, tkI_constructor, tkI_destructor ] then
          begin
            if not InClass then  // Implementation section method
            begin
              MethodStartLine := Token.Line;
              MethodName := '';
              // Get method name (next identifier token)
              if Lexer.NextToken( Token ) and ( Token.Kind = tkIdent ) then
                MethodName := Token.Value;
            end;
          end;

          // Track with statement depth
          if Token.Kind = tkI_with then
          begin
            Inc( WithDepth );
            // Check for nested with (depth > 1)
            if CheckNestedWith and ( WithDepth > 1 ) then
            begin
              Violation.FileName := FileName;
              Violation.UnitName := UnitName;
              Violation.Line     := Token.Line + 1;
              Violation.Column   := Token.Column;
              Violation.Rule     := 'NestedWith';
              Violation.Expected := 'Avoid nested "with" statements';
              Violation.Actual   := 'Nested "with" at depth ' + IntToStr( WithDepth );
              Violation.Severity := 'Warning';
              Violation.Category := 'AntiPattern';
              ViolationList.Add( Violation );
            end;
          end;

          // Track begin/end blocks for nesting and method body detection
          if Token.Kind = tkI_begin then
          begin
            Inc( BeginEndDepth );
            if not InMethodBody then
            begin
              InMethodBody := True;
              MethodStartLine := Token.Line;
            end;
          end
          else if Token.Kind = tkI_end then
          begin
            Dec( BeginEndDepth );
            // Reset with depth when leaving a begin/end block
            if WithDepth > 0 then
              Dec( WithDepth );
            // Check for long method when we exit the outermost begin/end
            if ( BeginEndDepth = 0 ) and InMethodBody and CheckLongMethods then
            begin
              if ( Token.Line - MethodStartLine + 1 ) > MaxMethodLines then
              begin
                Violation.FileName := FileName;
                Violation.UnitName := UnitName;
                Violation.Line     := MethodStartLine + 1;
                Violation.Column   := 0;
                Violation.Rule     := 'LongMethod';
                Violation.Expected := 'Method should be < ' + IntToStr( MaxMethodLines ) + ' lines';
                Violation.Actual   := MethodName + ' is ' + IntToStr( Token.Line - MethodStartLine + 1 ) + ' lines';
                Violation.Severity := 'Warning';
                Violation.Category := 'AntiPattern';
                ViolationList.Add( Violation );
              end;
              InMethodBody := False;
              MethodName := '';
            end;
          end;

          // Track control flow nesting depth
          if Token.Kind in [ tkI_if, tkI_for, tkI_while, tkI_repeat, tkI_case ] then
          begin
            Inc( NestingDepth );
            // Check for deep nesting
            if CheckDeepNesting and ( NestingDepth > MaxNestingDepth ) then
            begin
              Violation.FileName := FileName;
              Violation.UnitName := UnitName;
              Violation.Line     := Token.Line + 1;
              Violation.Column   := Token.Column;
              Violation.Rule     := 'DeepNesting';
              Violation.Expected := 'Nesting depth should be <= ' + IntToStr( MaxNestingDepth );
              Violation.Actual   := 'Nesting depth is ' + IntToStr( NestingDepth );
              Violation.Severity := 'Warning';
              Violation.Category := 'AntiPattern';
              ViolationList.Add( Violation );
            end;
          end;

          // Track try/finally/except for empty finally detection
          if Token.Kind = tkI_finally then
          begin
            InFinally := True;
            FinallyLine := Token.Line;
            FinallyHasContent := False;
          end
          else if Token.Kind = tkI_except then
          begin
            InFinally := False;  // except ends finally
          end
          else if InFinally then
          begin
            // Check if finally block has content (any token except 'end')
            if Token.Kind = tkI_end then
            begin
              // Check if finally was empty
              if CheckEmptyFinally and not FinallyHasContent then
              begin
                Violation.FileName := FileName;
                Violation.UnitName := UnitName;
                Violation.Line     := FinallyLine + 1;
                Violation.Column   := 0;
                Violation.Rule     := 'EmptyFinally';
                Violation.Expected := 'Finally block should contain cleanup code';
                Violation.Actual   := 'Empty finally block';
                Violation.Severity := 'Warning';
                Violation.Category := 'AntiPattern';
                ViolationList.Add( Violation );
              end;
              InFinally := False;
            end
            else if not ( Token.Kind in [ tkComment, tkDirective ] ) then
              FinallyHasContent := True;
          end;

          // Decrease nesting depth when exiting control structures
          if Token.Kind in [ tkI_then, tkI_do ] then
          begin
            // These are continuations, don't change depth
          end
          else if ( Token.Kind = tkI_end ) and ( NestingDepth > 0 ) then
          begin
            Dec( NestingDepth );
          end
          else if ( Token.Kind = tkI_until ) and ( NestingDepth > 0 ) then
          begin
            Dec( NestingDepth );  // repeat..until
          end;

          // Track parameter count for long parameter list detection
          if InMethodDeclaration and ( ParenDepth = 1 ) then
          begin
            if Token.Kind = tkColon then
            begin
              Inc( CurrentParamCount );
            end
            else if Token.Kind = tkRParan then
            begin
              // End of parameter list - check count
              if CheckLongParamLists and ( CurrentParamCount > MaxParameters ) then
              begin
                Violation.FileName := FileName;
                Violation.UnitName := UnitName;
                Violation.Line     := Token.Line + 1;
                Violation.Column   := Token.Column;
                Violation.Rule     := 'LongParamList';
                Violation.Expected := 'Parameter count should be <= ' + IntToStr( MaxParameters );
                Violation.Actual   := IntToStr( CurrentParamCount ) + ' parameters';
                Violation.Severity := 'Info';
                Violation.Category := 'AntiPattern';
                ViolationList.Add( Violation );
              end;
              CurrentParamCount := 0;
            end;
          end
          else if Token.Kind = tkLParan then
          begin
            // Reset param count at start of new parameter list
            if InMethodDeclaration and ( ParenDepth = 0 ) then
              CurrentParamCount := 0;
          end;
        end;
        // End anti-pattern detection
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

  // Anti-pattern detection defaults
  FCheckAntiPatterns   := False;  // Off by default - user must enable
  FCheckEmptyFinally   := True;
  FCheckNestedWith     := True;
  FCheckDeepNesting    := True;
  FCheckLongMethods    := True;
  FCheckLongParamLists := True;
  FMaxNestingDepth     := 4;
  FMaxMethodLines      := 100;
  FMaxParameters       := 6;

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
