{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2024 Andreas Hausladen                                                 *}
{*                                                                            *}
{******************************************************************************}

unit UnusedUnitDetector;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Generics.Collections, Menus, Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main;

type
  TUsedUnitInfo = record
    UnitName: string;
    FileName: string;
    IsInterface: Boolean;
    LineNumber: Integer;
  end;

  TUnusedUnitInfo = record
    SourceUnit: string;
    SourceFileName: string;
    UnusedUnit: string;
    IsInterface: Boolean;
    LineNumber: Integer;
  end;

  TUnitAnalyzer = class
  private
    FSearchPaths: TStringList;
    FKnownIdentifiers: TDictionary<string, TStringList>; // UnitName -> List of known identifiers
    FProgressFileName: string;
    procedure LoadKnownIdentifiers;
    function ExtractUsedUnits( const Content: string; out InterfaceUnits, ImplUnits: TList<TUsedUnitInfo> ): Boolean;
    function IsUnitReferenced( const UnitName, Content: string; InterfaceEndPos: Integer; IsInterfaceUnit: Boolean ): Boolean;
    function GetUnitExports( const UnitName: string ): TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddSearchPath( const Path: string );
    procedure ClearSearchPaths;
    function AnalyzeUnit( const FileName: string; out UnusedUnits: TArray<TUnusedUnitInfo> ): Boolean;
    function AnalyzeProject( const Project: IOTAProject; out AllUnusedUnits: TArray<TUnusedUnitInfo>;
      OnProgress: TNotifyEvent ): Boolean;
    property ProgressFileName: string read FProgressFileName;
  end;

  TUnusedUnitDetectorPlugin = class( TPluginConfig )
  private
    FEnabled: Boolean;
    FIgnoreList: TStringList;
    FMenuItem: TMenuItem;
    procedure MenuItemClick( Sender: TObject );
    procedure SetIgnoreListText( const Value: string );
    function GetIgnoreListText: string;
  protected
    function GetOptionPages: TTreePage; override;
    procedure Init; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ShowDetector;
    property IgnoreList: TStringList read FIgnoreList;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
    property IgnoreListText: string read GetIgnoreListText write SetIgnoreListText;
  end;

procedure InitPlugin( Unload: Boolean );

var
  UnusedUnitDetectorPlugin: TUnusedUnitDetectorPlugin;

implementation

uses
  Forms, Controls, ToolsAPIHelpers, AppConsts,
  FrmUnusedUnitDetector, FrmeOptionPageUnusedUnitDetector;

{ TUnitAnalyzer }

constructor TUnitAnalyzer.Create;
begin

  inherited Create;
  FSearchPaths                := TStringList.Create;
  FSearchPaths.CaseSensitive  := False;
  FSearchPaths.Duplicates     := dupIgnore;
  FKnownIdentifiers           := TDictionary<string, TStringList>.Create;
  LoadKnownIdentifiers;

end;

destructor TUnitAnalyzer.Destroy;
var
  Pair: TPair<string, TStringList>;
begin

  for Pair in FKnownIdentifiers do
    Pair.Value.Free;

  FKnownIdentifiers.Free;
  FSearchPaths.Free;
  inherited Destroy;

end;

procedure TUnitAnalyzer.LoadKnownIdentifiers;

  procedure AddUnit( const UnitName: string; const Identifiers: array of string );
  var
    List: TStringList;
    I: Integer;
  begin

    List                 := TStringList.Create;
    List.CaseSensitive   := False;

    for I := Low( Identifiers ) to High( Identifiers ) do
      List.Add( Identifiers[ I ] );

    FKnownIdentifiers.Add( LowerCase( UnitName ), List );

  end;

begin

  // Common RTL/VCL units and their commonly used identifiers
  AddUnit( 'SysUtils', [ 'Exception', 'Format', 'IntToStr', 'StrToInt', 'Trim', 'UpperCase',
    'LowerCase', 'CompareText', 'SameText', 'FileExists', 'DirectoryExists', 'ExtractFileName',
    'ExtractFilePath', 'ExtractFileExt', 'ChangeFileExt', 'IncludeTrailingPathDelimiter',
    'ExcludeTrailingPathDelimiter', 'ForceDirectories', 'DeleteFile', 'RenameFile',
    'Now', 'Date', 'Time', 'DateToStr', 'TimeToStr', 'StrToDate', 'StrToTime',
    'FormatDateTime', 'EncodeDate', 'DecodeDate', 'FreeAndNil', 'Supports',
    'TStringHelper', 'TEncoding', 'EAbort', 'EArgumentException' ] );
  AddUnit( 'Classes', [ 'TList', 'TStringList', 'TStrings', 'TStream', 'TMemoryStream',
    'TFileStream', 'TComponent', 'TNotifyEvent', 'TThread', 'TInterfacedObject',
    'TCollectionItem', 'TCollection', 'TPersistent', 'TReader', 'TWriter',
    'RegisterClass', 'FindClass', 'GetClass' ] );
  AddUnit( 'Windows', [ 'HWND', 'HDC', 'HINSTANCE', 'THandle', 'DWORD', 'BOOL',
    'GetTickCount', 'Sleep', 'MessageBox', 'GetLastError', 'SetLastError',
    'CreateFile', 'CloseHandle', 'ReadFile', 'WriteFile', 'GetModuleFileName',
    'LoadLibrary', 'FreeLibrary', 'GetProcAddress', 'OutputDebugString',
    'PostMessage', 'SendMessage', 'PChar', 'PWideChar', 'WPARAM', 'LPARAM' ] );
  AddUnit( 'Forms', [ 'TForm', 'TApplication', 'Application', 'Screen', 'TScreen',
    'TCustomForm', 'TFormClass', 'ShowMessage', 'ShowMessageFmt', 'MessageDlg',
    'InputBox', 'InputQuery', 'mrOk', 'mrCancel', 'mrYes', 'mrNo' ] );
  AddUnit( 'Controls', [ 'TControl', 'TWinControl', 'TGraphicControl', 'TMouse',
    'TDragObject', 'TCursor', 'crDefault', 'crHourGlass', 'TAlign', 'alClient',
    'alTop', 'alBottom', 'alLeft', 'alRight', 'alNone' ] );
  AddUnit( 'Graphics', [ 'TCanvas', 'TBitmap', 'TIcon', 'TGraphic', 'TPicture',
    'TColor', 'TFont', 'TPen', 'TBrush', 'clNone', 'clBlack', 'clWhite', 'clRed',
    'clGreen', 'clBlue', 'clYellow', 'clWindow', 'clBtnFace' ] );
  AddUnit( 'Dialogs', [ 'TOpenDialog', 'TSaveDialog', 'TFontDialog', 'TColorDialog',
    'TPrintDialog', 'TFindDialog', 'TReplaceDialog', 'MessageDlg', 'ShowMessage',
    'InputBox', 'InputQuery', 'mtWarning', 'mtError', 'mtInformation', 'mtConfirmation' ] );
  AddUnit( 'StdCtrls', [ 'TButton', 'TLabel', 'TEdit', 'TMemo', 'TListBox', 'TComboBox',
    'TCheckBox', 'TRadioButton', 'TGroupBox', 'TPanel', 'TScrollBar', 'TStaticText' ] );
  AddUnit( 'ExtCtrls', [ 'TPanel', 'TImage', 'TShape', 'TBevel', 'TTimer', 'TSplitter',
    'TNotebook', 'THeader', 'TRadioGroup', 'TCheckGroup' ] );
  AddUnit( 'ComCtrls', [ 'TTreeView', 'TListView', 'TTreeNode', 'TListItem', 'TStatusBar',
    'TToolBar', 'TProgressBar', 'TPageControl', 'TTabSheet', 'TRichEdit',
    'TDateTimePicker', 'TMonthCalendar', 'THeaderControl', 'TTrackBar' ] );
  AddUnit( 'Menus', [ 'TMainMenu', 'TPopupMenu', 'TMenuItem', 'TMenu' ] );
  AddUnit( 'ActnList', [ 'TAction', 'TActionList', 'TCustomAction' ] );
  AddUnit( 'Generics.Collections', [ 'TList', 'TDictionary', 'TObjectList', 'TObjectDictionary',
    'TQueue', 'TStack', 'TPair', 'TArray' ] );
  AddUnit( 'Generics.Defaults', [ 'TComparer', 'TEqualityComparer', 'IComparer', 'IEqualityComparer' ] );
  AddUnit( 'System.IOUtils', [ 'TFile', 'TDirectory', 'TPath' ] );
  AddUnit( 'System.JSON', [ 'TJSONObject', 'TJSONArray', 'TJSONValue', 'TJSONPair' ] );
  AddUnit( 'System.RegularExpressions', [ 'TRegEx', 'TMatch', 'TGroup' ] );
  AddUnit( 'Vcl.Themes', [ 'TStyleManager', 'TCustomStyle', 'TCustomStyleServices' ] );
  AddUnit( 'ToolsAPI', [ 'IOTAProject', 'IOTAModule', 'IOTAEditor', 'IOTASourceEditor',
    'IOTAModuleServices', 'IOTAActionServices', 'BorlandIDEServices', 'INTAServices',
    'IOTAServices', 'IOTAMessageServices', 'IOTAWizard', 'IOTANotifier' ] );

end;

procedure TUnitAnalyzer.AddSearchPath( const Path: string );
var
  ExpandedPath: string;
begin

  ExpandedPath := ExcludeTrailingPathDelimiter( Path );

  if ( ExpandedPath <> '' ) and DirectoryExists( ExpandedPath ) then
    FSearchPaths.Add( ExpandedPath );

end;

procedure TUnitAnalyzer.ClearSearchPaths;
begin

  FSearchPaths.Clear;

end;

function TUnitAnalyzer.GetUnitExports( const UnitName: string ): TStringList;
var
  LowerName: string;
begin

  LowerName := LowerCase( UnitName );

  if FKnownIdentifiers.TryGetValue( LowerName, Result ) then
    Exit;

  // For unknown units, return nil - we'll use heuristic matching
  Result := nil;

end;

function TUnitAnalyzer.ExtractUsedUnits( const Content: string;
  out InterfaceUnits, ImplUnits: TList<TUsedUnitInfo> ): Boolean;
var
  I, Len: Integer;
  InInterface, InImplementation: Boolean;
  InUses, InString, InComment, InLineComment: Boolean;
  BraceDepth: Integer;
  Token: string;
  Ch: Char;
  UnitInfo: TUsedUnitInfo;
  CurrentLineStart: Integer;

  function CountLines( const S: string; FromPos, ToPos: Integer ): Integer;
  var
    J: Integer;
  begin

    Result := 1;

    for J := FromPos to ToPos - 1 do
    begin

      if S[ J ] = #10 then
        Inc( Result );
    end;

  end;

  procedure AddToken;
  begin

    if Token <> '' then
    begin

      if SameText( Token, 'interface' ) and ( not InImplementation ) then
      begin
        InInterface      := True;
        InImplementation := False;
      end
      else if SameText( Token, 'implementation' ) then
      begin
        InInterface      := False;
        InImplementation := True;
        InUses           := False;
      end
      else if SameText( Token, 'uses' ) then
      begin
        InUses           := True;
        CurrentLineStart := I;
      end
      else if InUses and ( not SameText( Token, 'in' ) ) then
      begin
        UnitInfo.UnitName    := Token;
        UnitInfo.FileName    := '';
        UnitInfo.IsInterface := InInterface and ( not InImplementation );
        UnitInfo.LineNumber  := CountLines( Content, 1, CurrentLineStart );

        if InInterface and ( not InImplementation ) then
          InterfaceUnits.Add( UnitInfo )
        else if InImplementation then
          ImplUnits.Add( UnitInfo );
      end;

      Token := '';
    end;

  end;

begin

  InterfaceUnits := TList<TUsedUnitInfo>.Create;
  ImplUnits      := TList<TUsedUnitInfo>.Create;

  I                := 1;
  Len              := Length( Content );
  InInterface      := False;
  InImplementation := False;
  InUses           := False;
  InString         := False;
  InComment        := False;
  InLineComment    := False;
  BraceDepth       := 0;
  Token            := '';
  CurrentLineStart := 1;

  while I <= Len do
  begin
    Ch := Content[ I ];

    // Handle line comments
    if InLineComment then
    begin

      if ( Ch = #13 ) or ( Ch = #10 ) then
        InLineComment := False;

      Inc( I );
      Continue;
    end;

    // Handle block comments
    if InComment then
    begin

      if ( Ch = '*' ) and ( I < Len ) and ( Content[ I + 1 ] = ')' ) then
      begin
        InComment := False;
        Inc( I );
      end
      else if ( Ch = '}' ) and ( BraceDepth > 0 ) then
        Dec( BraceDepth );

      Inc( I );
      Continue;
    end;

    if BraceDepth > 0 then
    begin

      if Ch = '}' then
        Dec( BraceDepth );

      Inc( I );
      Continue;
    end;

    // Handle strings
    if InString then
    begin

      if Ch = '''' then
        InString := False;

      Inc( I );
      Continue;
    end;

    // Check for comment start
    if ( Ch = '/' ) and ( I < Len ) and ( Content[ I + 1 ] = '/' ) then
    begin
      AddToken;
      InLineComment := True;
      Inc( I, 2 );
      Continue;
    end;

    if ( Ch = '(' ) and ( I < Len ) and ( Content[ I + 1 ] = '*' ) then
    begin
      AddToken;
      InComment := True;
      Inc( I, 2 );
      Continue;
    end;

    if Ch = '{' then
    begin
      AddToken;
      Inc( BraceDepth );
      Inc( I );
      Continue;
    end;

    if Ch = '''' then
    begin
      AddToken;
      InString := True;
      Inc( I );
      Continue;
    end;

    // Parse tokens
    if CharInSet( Ch, [ 'A'..'Z', 'a'..'z', '_', '0'..'9', '.' ] ) then
      Token := Token + Ch
    else
    begin
      AddToken;

      if InUses and ( Ch = ';' ) then
        InUses := False;
    end;

    Inc( I );
  end;

  AddToken;
  Result := True;

end;

function TUnitAnalyzer.IsUnitReferenced( const UnitName, Content: string;
  InterfaceEndPos: Integer; IsInterfaceUnit: Boolean ): Boolean;
var
  SearchContent: string;
  UnitPrefix: string;
  KnownIds: TStringList;
  I: Integer;
  Id: string;
  Pos1: Integer;
  LowerSearchContent: string;
  LowerUnitName: string;
  SearchOffset: Integer;
begin

  Result := False;

  // Get the content to search (skip uses clause area)
  if IsInterfaceUnit then
    SearchContent := Content  // Search whole file for interface units
  else
    SearchContent := Copy( Content, InterfaceEndPos, MaxInt );  // Only implementation for impl units

  // Check for qualified references (UnitName.Something)
  UnitPrefix := UnitName + '.';

  if Pos( LowerCase( UnitPrefix ), LowerCase( SearchContent ) ) > 0 then
    Exit( True );

  // Check for known identifiers from this unit
  KnownIds := GetUnitExports( UnitName );

  if KnownIds <> nil then
  begin

    for I := 0 to KnownIds.Count - 1 do
    begin
      Id   := KnownIds[ I ];
      // Look for the identifier as a whole word
      Pos1 := Pos( LowerCase( Id ), LowerCase( SearchContent ) );

      if Pos1 > 0 then
      begin
        // Verify it's a whole word (not part of another identifier)
        if ( Pos1 = 1 ) or ( not CharInSet( SearchContent[ Pos1 - 1 ], [ 'A'..'Z', 'a'..'z', '_', '0'..'9' ] ) ) then
        begin

          if ( Pos1 + Length( Id ) > Length( SearchContent ) ) or
             ( not CharInSet( SearchContent[ Pos1 + Length( Id ) ], [ 'A'..'Z', 'a'..'z', '_', '0'..'9' ] ) ) then
            Exit( True );
        end;
      end;
    end;
  end;

  // Heuristic: if unit name appears anywhere as identifier, consider it used
  // This catches cases like type names matching unit names
  LowerSearchContent := LowerCase( SearchContent );
  LowerUnitName      := LowerCase( UnitName );
  Pos1               := Pos( LowerUnitName, LowerSearchContent );

  while Pos1 > 0 do
  begin
    // Check if it's a whole word
    if ( Pos1 = 1 ) or ( not CharInSet( SearchContent[ Pos1 - 1 ], [ 'A'..'Z', 'a'..'z', '_', '0'..'9' ] ) ) then
    begin

      if ( Pos1 + Length( UnitName ) > Length( SearchContent ) ) or
         ( not CharInSet( SearchContent[ Pos1 + Length( UnitName ) ], [ 'A'..'Z', 'a'..'z', '_', '0'..'9' ] ) ) then
        Exit( True );
    end;

    // Search for next occurrence after current match
    SearchOffset := Pos1 + 1;

    if SearchOffset > Length( LowerSearchContent ) then
      Break;

    Pos1 := Pos( LowerUnitName, Copy( LowerSearchContent, SearchOffset, MaxInt ) );

    if Pos1 > 0 then
      Pos1 := Pos1 + SearchOffset - 1;  // Adjust to absolute position
  end;

end;

function TUnitAnalyzer.AnalyzeUnit( const FileName: string;
  out UnusedUnits: TArray<TUnusedUnitInfo> ): Boolean;
var
  Content: string;
  SL: TStringList;
  InterfaceUnits, ImplUnits: TList<TUsedUnitInfo>;
  UsedUnit: TUsedUnitInfo;
  UnusedInfo: TUnusedUnitInfo;
  UnusedList: TList<TUnusedUnitInfo>;
  ImplPos: Integer;
  SourceUnitName: string;
begin

  Result := False;
  SetLength( UnusedUnits, 0 );

  if ( not FileExists( FileName ) ) then
    Exit;

  SL := TStringList.Create;

  try
    SL.LoadFromFile( FileName );
    Content := SL.Text;
  finally
    SL.Free;
  end;

  SourceUnitName := ChangeFileExt( ExtractFileName( FileName ), '' );
  ImplPos        := Pos( 'implementation', LowerCase( Content ) );

  if ImplPos = 0 then
    ImplPos := Length( Content );

  InterfaceUnits := nil;
  ImplUnits      := nil;
  UnusedList     := TList<TUnusedUnitInfo>.Create;

  try

    if ( not ExtractUsedUnits( Content, InterfaceUnits, ImplUnits ) ) then
      Exit;

    // Check interface uses
    for UsedUnit in InterfaceUnits do
    begin
      // Skip ignored units
      if ( UnusedUnitDetectorPlugin <> nil ) and
         ( UnusedUnitDetectorPlugin.IgnoreList.IndexOf( UsedUnit.UnitName ) >= 0 ) then
        Continue;

      if ( not IsUnitReferenced( UsedUnit.UnitName, Content, ImplPos, True ) ) then
      begin
        UnusedInfo.SourceUnit     := SourceUnitName;
        UnusedInfo.SourceFileName := FileName;
        UnusedInfo.UnusedUnit     := UsedUnit.UnitName;
        UnusedInfo.IsInterface    := True;
        UnusedInfo.LineNumber     := UsedUnit.LineNumber;
        UnusedList.Add( UnusedInfo );
      end;
    end;

    // Check implementation uses
    for UsedUnit in ImplUnits do
    begin
      // Skip ignored units
      if ( UnusedUnitDetectorPlugin <> nil ) and
         ( UnusedUnitDetectorPlugin.IgnoreList.IndexOf( UsedUnit.UnitName ) >= 0 ) then
        Continue;

      if ( not IsUnitReferenced( UsedUnit.UnitName, Content, ImplPos, False ) ) then
      begin
        UnusedInfo.SourceUnit     := SourceUnitName;
        UnusedInfo.SourceFileName := FileName;
        UnusedInfo.UnusedUnit     := UsedUnit.UnitName;
        UnusedInfo.IsInterface    := False;
        UnusedInfo.LineNumber     := UsedUnit.LineNumber;
        UnusedList.Add( UnusedInfo );
      end;
    end;

    UnusedUnits := UnusedList.ToArray;
    Result      := True;
  finally
    UnusedList.Free;
    InterfaceUnits.Free;
    ImplUnits.Free;
  end;

end;

function TUnitAnalyzer.AnalyzeProject( const Project: IOTAProject;
  out AllUnusedUnits: TArray<TUnusedUnitInfo>; OnProgress: TNotifyEvent ): Boolean;
var
  I: Integer;
  ModuleInfo: IOTAModuleInfo;
  FileName: string;
  Options: IOTAProjectOptions;
  SearchPath: string;
  SL: TStringList;
  UnusedUnits: TArray<TUnusedUnitInfo>;
  AllUnused: TList<TUnusedUnitInfo>;
  UnusedInfo: TUnusedUnitInfo;
begin

  Result := False;
  SetLength( AllUnusedUnits, 0 );

  if Project = nil then
    Exit;

  ClearSearchPaths;

  // Add project directory as search path
  AddSearchPath( ExtractFileDir( Project.FileName ) );

  // Get search paths from project options
  Options := Project.ProjectOptions;

  if Options <> nil then
  begin
    SearchPath := VarToStr( Options.Values[ 'UnitDir' ] );
    SL         := TStringList.Create;

    try
      SL.Delimiter       := ';';
      SL.StrictDelimiter := True;
      SL.DelimitedText   := SearchPath;

      for I := 0 to SL.Count - 1 do
        AddSearchPath( ExpandFileName( SL[ I ] ) );
    finally
      SL.Free;
    end;
  end;

  AllUnused := TList<TUnusedUnitInfo>.Create;

  try
    // Analyse all units in the project
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

        if AnalyzeUnit( FileName, UnusedUnits ) then
        begin

          for UnusedInfo in UnusedUnits do
            AllUnused.Add( UnusedInfo );
        end;
      end;
    end;

    AllUnusedUnits := AllUnused.ToArray;
    Result         := True;
  finally
    AllUnused.Free;
  end;

end;

{ TUnusedUnitDetectorPlugin }

constructor TUnusedUnitDetectorPlugin.Create;
var
  ToolsMenu: TMenuItem;
begin

  // Create FIgnoreList before inherited, because inherited calls Init and loads config
  FIgnoreList                := TStringList.Create;
  FIgnoreList.CaseSensitive  := False;
  FIgnoreList.Sorted         := True;
  FIgnoreList.Duplicates     := dupIgnore;

  inherited Create( AppDataDirectory + '\UnusedUnitDetector.xml', 'UnusedUnitDetector' );

  // Add menu item under Tools menu
  ToolsMenu := FindMenuItem( 'ToolsMenu' );

  if ToolsMenu <> nil then
  begin
    FMenuItem         := TMenuItem.Create( ToolsMenu );
    FMenuItem.Caption := 'Unused &Unit Detector...';
    FMenuItem.OnClick := MenuItemClick;
    ToolsMenu.Add( FMenuItem );
  end;

end;

destructor TUnusedUnitDetectorPlugin.Destroy;
begin

  FreeAndNil( FMenuItem );
  FreeAndNil( FIgnoreList );
  inherited Destroy;

end;

procedure TUnusedUnitDetectorPlugin.Init;
begin

  FEnabled := True;
  // Default ignore list - commonly used units that are often required but hard to detect
  FIgnoreList.Add( 'Windows' );
  FIgnoreList.Add( 'Messages' );
  FIgnoreList.Add( 'System' );
  FIgnoreList.Add( 'SysInit' );

end;

function TUnusedUnitDetectorPlugin.GetIgnoreListText: string;
begin

  Result := FIgnoreList.CommaText;

end;

procedure TUnusedUnitDetectorPlugin.SetIgnoreListText( const Value: string );
begin

  FIgnoreList.CommaText := Value;

end;

function TUnusedUnitDetectorPlugin.GetOptionPages: TTreePage;
begin

  Result := TTreePage.Create( 'Unused Unit Detector', TFrameOptionPageUnusedUnitDetector, Self );

end;

procedure TUnusedUnitDetectorPlugin.MenuItemClick( Sender: TObject );
begin

  ShowDetector;

end;

procedure TUnusedUnitDetectorPlugin.ShowDetector;
begin

  TFormUnusedUnitDetector.Execute;

end;

procedure InitPlugin( Unload: Boolean );
begin

  if ( not Unload ) then
    UnusedUnitDetectorPlugin := TUnusedUnitDetectorPlugin.Create
  else
  begin
    UnusedUnitDetectorPlugin.Free;
    UnusedUnitDetectorPlugin := nil;
  end;

end;

end.
