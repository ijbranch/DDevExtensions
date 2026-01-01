{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2024 Andreas Hausladen                                                 *}
{*                                                                            *}
{******************************************************************************}

unit DependencyViewer;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Generics.Collections, Menus, Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main;

type
  TUnitDependency = record
    UnitName: string;
    FileName: string;
    IsInterface: Boolean; // True if in interface uses, False if in implementation uses
  end;

  TUnitInfo = class
  private
    FUnitName: string;
    FFileName: string;
    FDependencies: TList<TUnitDependency>;
    FParsed: Boolean;
  public
    constructor Create(const AUnitName, AFileName: string);
    destructor Destroy; override;
    property UnitName: string read FUnitName;
    property FileName: string read FFileName;
    property Dependencies: TList<TUnitDependency> read FDependencies;
    property Parsed: Boolean read FParsed write FParsed;
  end;

  TCircularReference = record
    Path: TArray<string>;
  end;

  TDependencyScanner = class
  private
    FUnits: TObjectDictionary<string, TUnitInfo>;
    FSearchPaths: TStringList;
    FCircularRefs: TList<TCircularReference>;
    FOnProgress: TNotifyEvent;
    FProgressUnit: string;
    procedure ParseUsesClause(const Content: string; UnitInfo: TUnitInfo);
    procedure ScanUnit(const UnitName, FileName: string);
    procedure DetectCircularReferences;
    function CheckCircular(const UnitName: string; const Path: TList<string>;
      var Visited: TDictionary<string, Boolean>): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure AddSearchPath(const Path: string);
    procedure ScanProject(const Project: IOTAProject);
    procedure ScanFile(const FileName: string);
    function GetUnitInfo(const UnitName: string): TUnitInfo;
    function GetAllUnits: TArray<TUnitInfo>;
    property CircularReferences: TList<TCircularReference> read FCircularRefs;
    property OnProgress: TNotifyEvent read FOnProgress write FOnProgress;
    property ProgressUnit: string read FProgressUnit;
  end;

  TDependencyViewerPlugin = class(TPluginConfig)
  private
    FEnabled: Boolean;
    FMenuItem: TMenuItem;
    procedure MenuItemClick(Sender: TObject);
  protected
    function GetOptionPages: TTreePage; override;
    procedure Init; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ShowDependencyViewer;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

procedure InitPlugin(Unload: Boolean);

var
  DependencyViewerPlugin: TDependencyViewerPlugin;

implementation

uses
  Forms, Controls, ToolsAPIHelpers, AppConsts,
  FrmDependencyViewer, FrmeOptionPageDependencyViewer;

{ TUnitInfo }

constructor TUnitInfo.Create(const AUnitName, AFileName: string);
begin
  inherited Create;
  FUnitName := AUnitName;
  FFileName := AFileName;
  FDependencies := TList<TUnitDependency>.Create;
  FParsed := False;
end;

destructor TUnitInfo.Destroy;
begin
  FDependencies.Free;
  inherited Destroy;
end;

{ TDependencyScanner }

constructor TDependencyScanner.Create;
begin
  inherited Create;
  FUnits := TObjectDictionary<string, TUnitInfo>.Create([doOwnsValues]);
  FSearchPaths := TStringList.Create;
  FSearchPaths.CaseSensitive := False;
  FSearchPaths.Duplicates := dupIgnore;
  FCircularRefs := TList<TCircularReference>.Create;
end;

destructor TDependencyScanner.Destroy;
begin
  FCircularRefs.Free;
  FSearchPaths.Free;
  FUnits.Free;
  inherited Destroy;
end;

procedure TDependencyScanner.Clear;
begin
  FUnits.Clear;
  FSearchPaths.Clear;
  FCircularRefs.Clear;
end;

procedure TDependencyScanner.AddSearchPath(const Path: string);
var
  ExpandedPath: string;
begin
  ExpandedPath := ExcludeTrailingPathDelimiter(Path);
  if (ExpandedPath <> '') and DirectoryExists(ExpandedPath) then
    FSearchPaths.Add(ExpandedPath);
end;

procedure TDependencyScanner.ParseUsesClause(const Content: string; UnitInfo: TUnitInfo);
var
  I, Len: Integer;
  InInterface, InImplementation: Boolean;
  InUses, InString, InComment, InLineComment: Boolean;
  BraceDepth: Integer;
  Token: string;
  Ch: Char;
  Dep: TUnitDependency;

  procedure AddToken;
  begin
    if Token <> '' then
    begin
      if SameText(Token, 'interface') then
      begin
        InInterface := True;
        InImplementation := False;
      end
      else if SameText(Token, 'implementation') then
      begin
        InInterface := False;
        InImplementation := True;
        InUses := False;
      end
      else if SameText(Token, 'uses') then
        InUses := True
      else if InUses and not SameText(Token, 'in') then
      begin
        Dep.UnitName := Token;
        Dep.FileName := '';
        Dep.IsInterface := InInterface;
        UnitInfo.Dependencies.Add(Dep);
      end;
      Token := '';
    end;
  end;

begin
  I := 1;
  Len := Length(Content);
  InInterface := False;
  InImplementation := False;
  InUses := False;
  InString := False;
  InComment := False;
  InLineComment := False;
  BraceDepth := 0;
  Token := '';

  while I <= Len do
  begin
    Ch := Content[I];

    // Handle line comments
    if InLineComment then
    begin
      if (Ch = #13) or (Ch = #10) then
        InLineComment := False;
      Inc(I);
      Continue;
    end;

    // Handle block comments
    if InComment then
    begin
      if (Ch = '*') and (I < Len) and (Content[I + 1] = ')') then
      begin
        InComment := False;
        Inc(I);
      end
      else if (Ch = '}') and (BraceDepth > 0) then
        Dec(BraceDepth);
      Inc(I);
      Continue;
    end;

    if BraceDepth > 0 then
    begin
      if Ch = '}' then
        Dec(BraceDepth);
      Inc(I);
      Continue;
    end;

    // Handle strings
    if InString then
    begin
      if Ch = '''' then
        InString := False;
      Inc(I);
      Continue;
    end;

    // Check for comment start
    if (Ch = '/') and (I < Len) and (Content[I + 1] = '/') then
    begin
      AddToken;
      InLineComment := True;
      Inc(I, 2);
      Continue;
    end;

    if (Ch = '(') and (I < Len) and (Content[I + 1] = '*') then
    begin
      AddToken;
      InComment := True;
      Inc(I, 2);
      Continue;
    end;

    if Ch = '{' then
    begin
      AddToken;
      Inc(BraceDepth);
      Inc(I);
      Continue;
    end;

    if Ch = '''' then
    begin
      AddToken;
      InString := True;
      Inc(I);
      Continue;
    end;

    // Parse tokens
    if CharInSet(Ch, ['A'..'Z', 'a'..'z', '_', '0'..'9', '.']) then
      Token := Token + Ch
    else
    begin
      AddToken;
      if InUses and (Ch = ';') then
        InUses := False;
    end;

    Inc(I);
  end;

  AddToken;
end;

procedure TDependencyScanner.ScanUnit(const UnitName, FileName: string);
var
  UnitInfo: TUnitInfo;
  Content: string;
  SL: TStringList;
  LowerName: string;
begin
  LowerName := LowerCase(UnitName);

  if FUnits.ContainsKey(LowerName) then
  begin
    UnitInfo := FUnits[LowerName];
    if UnitInfo.Parsed then
      Exit;
  end
  else
  begin
    UnitInfo := TUnitInfo.Create(UnitName, FileName);
    FUnits.Add(LowerName, UnitInfo);
  end;

  FProgressUnit := UnitName;
  if Assigned(FOnProgress) then
    FOnProgress(Self);

  if (FileName <> '') and FileExists(FileName) then
  begin
    SL := TStringList.Create;
    try
      SL.LoadFromFile(FileName);
      Content := SL.Text;
    finally
      SL.Free;
    end;

    ParseUsesClause(Content, UnitInfo);
    UnitInfo.Parsed := True;

    // Recursively scan dependencies
    // (Disabled for performance - only scan on demand)
  end;
end;

procedure TDependencyScanner.ScanProject(const Project: IOTAProject);
var
  I: Integer;
  ModuleInfo: IOTAModuleInfo;
  FileName, UnitName: string;
  Options: IOTAProjectOptions;
  SearchPath, OutputDir: string;
  SL: TStringList;
begin
  if Project = nil then
    Exit;

  Clear;

  // Add project directory as search path
  AddSearchPath(ExtractFileDir(Project.FileName));

  // Get search paths from project options
  Options := Project.ProjectOptions;
  if Options <> nil then
  begin
    SearchPath := VarToStr(Options.Values['UnitDir']);
    SL := TStringList.Create;
    try
      SL.Delimiter := ';';
      SL.StrictDelimiter := True;
      SL.DelimitedText := SearchPath;
      for I := 0 to SL.Count - 1 do
        AddSearchPath(ExpandFileName(SL[I]));
    finally
      SL.Free;
    end;

    OutputDir := VarToStr(Options.Values['UnitOutputDir']);
    if OutputDir <> '' then
      AddSearchPath(ExpandFileName(OutputDir));
  end;

  // Scan all units in the project
  for I := 0 to Project.GetModuleCount - 1 do
  begin
    ModuleInfo := Project.GetModule(I);
    FileName := ModuleInfo.FileName;
    if SameText(ExtractFileExt(FileName), '.pas') then
    begin
      UnitName := ChangeFileExt(ExtractFileName(FileName), '');
      ScanUnit(UnitName, FileName);
    end;
  end;

  DetectCircularReferences;
end;

procedure TDependencyScanner.ScanFile(const FileName: string);
var
  UnitName: string;
begin
  if FileExists(FileName) and SameText(ExtractFileExt(FileName), '.pas') then
  begin
    UnitName := ChangeFileExt(ExtractFileName(FileName), '');
    AddSearchPath(ExtractFileDir(FileName));
    ScanUnit(UnitName, FileName);
  end;
end;

function TDependencyScanner.GetUnitInfo(const UnitName: string): TUnitInfo;
begin
  if not FUnits.TryGetValue(LowerCase(UnitName), Result) then
    Result := nil;
end;

function TDependencyScanner.GetAllUnits: TArray<TUnitInfo>;
var
  List: TList<TUnitInfo>;
  Pair: TPair<string, TUnitInfo>;
begin
  List := TList<TUnitInfo>.Create;
  try
    for Pair in FUnits do
      List.Add(Pair.Value);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TDependencyScanner.DetectCircularReferences;
var
  Visited: TDictionary<string, Boolean>;
  Path: TList<string>;
  Pair: TPair<string, TUnitInfo>;
begin
  FCircularRefs.Clear;
  Visited := TDictionary<string, Boolean>.Create;
  Path := TList<string>.Create;
  try
    for Pair in FUnits do
    begin
      Visited.Clear;
      Path.Clear;
      CheckCircular(Pair.Key, Path, Visited);
    end;
  finally
    Path.Free;
    Visited.Free;
  end;
end;

function TDependencyScanner.CheckCircular(const UnitName: string;
  const Path: TList<string>; var Visited: TDictionary<string, Boolean>): Boolean;
var
  UnitInfo: TUnitInfo;
  Dep: TUnitDependency;
  CircRef: TCircularReference;
  I, J, StartIdx: Integer;
  IsVisited: Boolean;
  LowerName: string;
begin
  Result := False;
  LowerName := LowerCase(UnitName);

  // Check if we've found a cycle
  for I := 0 to Path.Count - 1 do
  begin
    if SameText(Path[I], UnitName) then
    begin
      // Found a cycle - record it
      StartIdx := I;
      SetLength(CircRef.Path, Path.Count - StartIdx + 1);
      for J := StartIdx to Path.Count - 1 do
        CircRef.Path[J - StartIdx] := Path[J];
      CircRef.Path[High(CircRef.Path)] := UnitName;
      FCircularRefs.Add(CircRef);
      Result := True;
      Exit;
    end;
  end;

  if Visited.TryGetValue(LowerName, IsVisited) and IsVisited then
    Exit;

  Visited.AddOrSetValue(LowerName, True);
  Path.Add(UnitName);
  try
    if FUnits.TryGetValue(LowerName, UnitInfo) then
    begin
      for Dep in UnitInfo.Dependencies do
        CheckCircular(Dep.UnitName, Path, Visited);
    end;
  finally
    Path.Delete(Path.Count - 1);
  end;
end;

{ TDependencyViewerPlugin }

constructor TDependencyViewerPlugin.Create;
var
  ViewMenu: TMenuItem;
begin
  inherited Create(AppDataDirectory + '\DependencyViewer.xml', 'DependencyViewer');

  // Add menu item under View menu
  ViewMenu := FindMenuItem('ViewMenu');
  if ViewMenu <> nil then
  begin
    FMenuItem := TMenuItem.Create(ViewMenu);
    FMenuItem.Caption := '&Dependency Viewer...';
    FMenuItem.OnClick := MenuItemClick;
    ViewMenu.Add(FMenuItem);
  end;
end;

destructor TDependencyViewerPlugin.Destroy;
begin
  FMenuItem.Free;
  inherited Destroy;
end;

procedure TDependencyViewerPlugin.Init;
begin
  FEnabled := True;
end;

function TDependencyViewerPlugin.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('Dependency Viewer', TFrameOptionPageDependencyViewer, Self);
end;

procedure TDependencyViewerPlugin.MenuItemClick(Sender: TObject);
begin
  ShowDependencyViewer;
end;

procedure TDependencyViewerPlugin.ShowDependencyViewer;
begin
  TFormDependencyViewer.Execute;
end;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    DependencyViewerPlugin := TDependencyViewerPlugin.Create
  else
  begin
    DependencyViewerPlugin.Free;
    DependencyViewerPlugin := nil;
  end;
end;

end.
