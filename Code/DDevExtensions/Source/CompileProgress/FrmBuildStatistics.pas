{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmBuildStatistics;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Clipbrd, Menus, Math,
  ToolsAPI, FrmBase, CompileProgress, UnitMetrics;

type
  TFileFilter = ( ffAll, ffProject, ffExternal );

  TFormBuildStatistics = class( TFormBase )
    pnlBottom: TPanel;
    btnClose: TButton;
    btnCopyToClipboard: TButton;
    btnExportCSV: TButton;
    ListView: TListView;
    lblTotalTime: TLabel;
    lblUnitCount: TLabel;
    lblFilter: TLabel;
    cmbFilter: TComboBox;
    SaveDialog: TSaveDialog;
    PopupMenu: TPopupMenu;
    mnuCopyToClipboard: TMenuItem;
    mnuExportCSV: TMenuItem;
    N1: TMenuItem;
    mnuSortByName: TMenuItem;
    mnuSortByTime: TMenuItem;
    mnuSortByLOC: TMenuItem;
    mnuSortByComplexity: TMenuItem;
    PageControl: TPageControl;
    tabBuildStats: TTabSheet;
    tabStyleIssues: TTabSheet;
    lvStyleIssues: TListView;
    PopupMenuStyle: TPopupMenu;
    mnuStyleCopyToClipboard: TMenuItem;
    mnuStyleExportCSV: TMenuItem;
    N2: TMenuItem;
    mnuStyleOpenFile: TMenuItem;
    procedure btnCloseClick( Sender: TObject );
    procedure btnCopyToClipboardClick( Sender: TObject );
    procedure btnExportCSVClick( Sender: TObject );
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    procedure FormCreate( Sender: TObject );
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    procedure mnuSortByNameClick( Sender: TObject );
    procedure mnuSortByTimeClick( Sender: TObject );
    procedure mnuSortByLOCClick( Sender: TObject );
    procedure mnuSortByComplexityClick( Sender: TObject );
    procedure cmbFilterChange( Sender: TObject );
    procedure ListViewDblClick( Sender: TObject );
    procedure PageControlChange( Sender: TObject );
    procedure lvStyleIssuesColumnClick( Sender: TObject; Column: TListColumn );
    procedure lvStyleIssuesCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    procedure lvStyleIssuesDblClick( Sender: TObject );
    procedure mnuStyleCopyToClipboardClick( Sender: TObject );
    procedure mnuStyleExportCSVClick( Sender: TObject );
    procedure mnuStyleOpenFileClick( Sender: TObject );
  private
    FBuildStatistics: TBuildStatistics;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    FFileFilter: TFileFilter;
    FStyleViolations: TArray<TStyleViolation>;
    FStyleSortColumn: Integer;
    FStyleSortAscending: Boolean;
    procedure PopulateList;
    procedure PopulateStyleList;
    function FormatDuration( Ms: Int64 ): string;
    function IsProjectFile( const FileName: string ): Boolean;
    procedure OpenStyleFile( const Violation: TStyleViolation );
  public
    class procedure Execute( ABuildStatistics: TBuildStatistics );
  end;

var
  FormInstance: TFormBuildStatistics = nil;

implementation

{$R *.dfm}

class procedure TFormBuildStatistics.Execute( ABuildStatistics: TBuildStatistics );
begin

  if ABuildStatistics = nil then
    Exit;

  // If already open, bring to front and update data
  if FormInstance <> nil then
  begin
    FormInstance.FBuildStatistics := ABuildStatistics;
    FormInstance.FStyleViolations := ABuildStatistics.GetStyleViolations;
    FormInstance.PopulateList;
    FormInstance.PopulateStyleList;
    FormInstance.Show;
    FormInstance.BringToFront;
    Exit;
  end;

  FormInstance := TFormBuildStatistics.Create( Application );
  FormInstance.FBuildStatistics := ABuildStatistics;
  FormInstance.FStyleViolations := ABuildStatistics.GetStyleViolations;
  FormInstance.PopulateList;
  FormInstance.PopulateStyleList;
  FormInstance.Show;

end;

procedure TFormBuildStatistics.FormCreate( Sender: TObject );
begin

  FSortColumn      := 1;     // Default sort by duration
  FSortAscending   := False; // Descending (slowest first)
  FFileFilter      := ffProject;
  cmbFilter.ItemIndex := 1;  // Project

  // Style issues sort defaults
  FStyleSortColumn   := 0;   // Sort by unit name
  FStyleSortAscending := True;

end;

procedure TFormBuildStatistics.FormClose( Sender: TObject; var Action: TCloseAction );
begin

  FormInstance := nil;
  Action       := caFree;

end;

function TFormBuildStatistics.FormatDuration( Ms: Int64 ): string;
var
  Seconds: Double;
begin

  if Ms < 1000 then
    Result := Format( '%d ms', [ Ms ] )
  else
  begin
    Seconds := Ms / 1000;

    if Seconds < 60 then
      Result := Format( '%.2f s', [ Seconds ] )
    else
      Result := Format( '%.1f min', [ Seconds / 60 ] );
  end;

end;

procedure TFormBuildStatistics.PopulateList;
var
  Units: TArray<TBuildUnitInfo>;
  I: Integer;
  Item: TListItem;
  TotalMs: Int64;
  TotalLOC: Integer;
  TotalComplexity: Integer;
  Metrics: TUnitMetrics;
  DisplayCount: Integer;
  IsProject: Boolean;
  FullPath: string;
  ProjectPath: string;
begin

  ListView.Items.BeginUpdate;
  ProjectPath := FBuildStatistics.ProjectPath;

  try
    ListView.Items.Clear;
    Units           := FBuildStatistics.GetUnits;
    TotalMs         := 0;
    TotalLOC        := 0;
    TotalComplexity := 0;
    DisplayCount    := 0;

    for I := 0 to Length( Units ) - 1 do
    begin
      // Apply filter
      IsProject := IsProjectFile( Units[ I ].FileName );

      case FFileFilter of
        ffProject:
          if not IsProject then
            Continue;
        ffExternal:
          if IsProject then
            Continue;
      end;

      Item         := ListView.Items.Add;
      Item.Caption := Units[ I ].UnitName;
      Item.SubItems.Add( FormatDuration( Units[ I ].DurationMs ) );

      // Resolve relative paths using project path
      FullPath := Units[ I ].FileName;
      if ( ProjectPath <> '' ) and not FileExists( FullPath ) then
        FullPath := ExpandFileName( ProjectPath + Units[ I ].FileName );

      // Calculate metrics for this unit
      if FileExists( FullPath ) then
      begin
        Metrics := CalculateUnitMetrics( FullPath );
        Item.SubItems.Add( IntToStr( Metrics.LinesOfCode ) );
        Item.SubItems.Add( IntToStr( Metrics.CyclomaticComplexity ) );
        TotalLOC        := TotalLOC + Metrics.LinesOfCode;
        TotalComplexity := TotalComplexity + Metrics.CyclomaticComplexity;
      end
      else
      begin
        Item.SubItems.Add( '-' );
        Item.SubItems.Add( '-' );
      end;

      Item.SubItems.Add( Units[ I ].FileName );
      Item.Data := Pointer( Units[ I ].DurationMs );
      TotalMs   := TotalMs + Units[ I ].DurationMs;
      Inc( DisplayCount );
    end;

    // Apply current sort
    ListView.CustomSort( nil, 0 );

    lblUnitCount.Caption := Format( 'Units: %d  |  Total LOC: %d  |  Avg Complexity: %.1f',
      [ DisplayCount, TotalLOC,
        IfThen( DisplayCount > 0, TotalComplexity / DisplayCount, 0 ) ] );
    lblTotalTime.Caption := Format( 'Total time: %s', [ FormatDuration( TotalMs ) ] );
  finally
    ListView.Items.EndUpdate;
  end;

end;

procedure TFormBuildStatistics.btnCloseClick( Sender: TObject );
begin

  Close;

end;

procedure TFormBuildStatistics.btnCopyToClipboardClick( Sender: TObject );
var
  SL: TStringList;
  I: Integer;
  Item: TListItem;
begin

  SL := TStringList.Create;

  try
    SL.Add( 'Unit Name'#9'Duration'#9'LOC'#9'Complexity'#9'File Path' );

    for I := 0 to ListView.Items.Count - 1 do
    begin
      Item := ListView.Items[ I ];

      if Item.SubItems.Count >= 4 then
        SL.Add( Format( '%s'#9'%s'#9'%s'#9'%s'#9'%s',
          [ Item.Caption, Item.SubItems[ 0 ], Item.SubItems[ 1 ],
            Item.SubItems[ 2 ], Item.SubItems[ 3 ] ] ) );
    end;

    Clipboard.AsText := SL.Text;
  finally
    SL.Free;
  end;

end;

procedure TFormBuildStatistics.btnExportCSVClick( Sender: TObject );
var
  SL: TStringList;
  I: Integer;
  Item: TListItem;
begin

  if SaveDialog.Execute then
  begin
    SL := TStringList.Create;

    try
      SL.Add( '"Unit Name","Duration (ms)","Lines of Code","Cyclomatic Complexity","File Path"' );

      for I := 0 to ListView.Items.Count - 1 do
      begin
        Item := ListView.Items[ I ];

        if Item.SubItems.Count >= 4 then
          SL.Add( Format( '"%s",%d,%s,%s,"%s"',
            [ Item.Caption, Int64( Item.Data ), Item.SubItems[ 1 ],
              Item.SubItems[ 2 ], Item.SubItems[ 3 ] ] ) );
      end;

      try
        SL.SaveToFile( SaveDialog.FileName );
      except
        on E: Exception do
          ShowMessage( 'Error saving file: ' + E.Message );
      end;
    finally
      SL.Free;
    end;
  end;

end;

procedure TFormBuildStatistics.ListViewColumnClick( Sender: TObject; Column: TListColumn );
begin

  if FSortColumn = Column.Index then
    FSortAscending := not FSortAscending
  else
  begin
    FSortColumn    := Column.Index;
    FSortAscending := ( FSortColumn = 0 ); // Ascending for name, descending for duration
  end;

  ListView.CustomSort( nil, 0 );

end;

procedure TFormBuildStatistics.ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
  Data: Integer; var Compare: Integer );
var
  Ms1, Ms2: Int64;
  Val1, Val2: Integer;
begin

  case FSortColumn of
    0: // Unit Name
      Compare := CompareText( Item1.Caption, Item2.Caption );
    1: // Duration
      begin
        Ms1 := Int64( Item1.Data );
        Ms2 := Int64( Item2.Data );

        if Ms1 < Ms2 then
          Compare := -1
        else if Ms1 > Ms2 then
          Compare := 1
        else
          Compare := 0;
      end;
    2: // LOC
      begin
        Val1 := StrToIntDef( Item1.SubItems[ 1 ], 0 );
        Val2 := StrToIntDef( Item2.SubItems[ 1 ], 0 );

        if Val1 < Val2 then
          Compare := -1
        else if Val1 > Val2 then
          Compare := 1
        else
          Compare := 0;
      end;
    3: // Complexity
      begin
        Val1 := StrToIntDef( Item1.SubItems[ 2 ], 0 );
        Val2 := StrToIntDef( Item2.SubItems[ 2 ], 0 );

        if Val1 < Val2 then
          Compare := -1
        else if Val1 > Val2 then
          Compare := 1
        else
          Compare := 0;
      end;
    4: // File Path
      Compare := CompareText( Item1.SubItems[ 3 ], Item2.SubItems[ 3 ] );
  else
    Compare := 0;
  end;

  if ( not FSortAscending ) then
    Compare := -Compare;

end;

procedure TFormBuildStatistics.mnuSortByNameClick( Sender: TObject );
begin

  FSortColumn    := 0;
  FSortAscending := True;
  ListView.CustomSort( nil, 0 );

end;

procedure TFormBuildStatistics.mnuSortByTimeClick( Sender: TObject );
begin

  FSortColumn    := 1;
  FSortAscending := False;
  ListView.CustomSort( nil, 0 );

end;

procedure TFormBuildStatistics.mnuSortByLOCClick( Sender: TObject );
begin

  FSortColumn    := 2;
  FSortAscending := False;
  ListView.CustomSort( nil, 0 );

end;

procedure TFormBuildStatistics.mnuSortByComplexityClick( Sender: TObject );
begin

  FSortColumn    := 3;
  FSortAscending := False;
  ListView.CustomSort( nil, 0 );

end;

procedure TFormBuildStatistics.cmbFilterChange( Sender: TObject );
begin

  case cmbFilter.ItemIndex of
    0: FFileFilter := ffAll;
    1: FFileFilter := ffProject;
    2: FFileFilter := ffExternal;
  else
    FFileFilter := ffAll;
  end;

  PopulateList;

end;

procedure TFormBuildStatistics.ListViewDblClick( Sender: TObject );
var
  Item: TListItem;
  FileName: string;
  FullPath: string;
  ProjectPath: string;
  ActionServices: IOTAActionServices;
begin

  Item := ListView.Selected;

  if Item = nil then
    Exit;

  if Item.SubItems.Count < 4 then
    Exit;

  FileName := Item.SubItems[ 3 ]; // File Path column

  // Only allow opening files where source was found (has metrics)
  if Item.SubItems[ 1 ] = '-' then
    Exit;

  ProjectPath := FBuildStatistics.ProjectPath;

  // Resolve relative paths
  FullPath := FileName;
  if ( ProjectPath <> '' ) and not FileExists( FullPath ) then
    FullPath := ExpandFileName( ProjectPath + FileName );

  if FileExists( FullPath ) and Supports( BorlandIDEServices, IOTAActionServices, ActionServices ) then
  begin
    ActionServices.OpenFile( FullPath );
    Close;
  end;

end;

function TFormBuildStatistics.IsProjectFile( const FileName: string ): Boolean;
begin

  Result := FBuildStatistics.IsProjectFile( FileName );

end;

procedure TFormBuildStatistics.PopulateStyleList;
var
  Violation: TStyleViolation;
  Item: TListItem;
  Category: string;
  Idx: Integer;
begin

  lvStyleIssues.Items.BeginUpdate;

  try
    lvStyleIssues.Items.Clear;
    Idx := 0;

    for Violation in FStyleViolations do
    begin
      Item := lvStyleIssues.Items.Add;
      Item.Caption := Violation.UnitName;
      // Use default category if not set
      Category := Violation.Category;
      if Category = '' then
        Category := 'NamingConvention';
      Item.SubItems.Add( Category );
      Item.SubItems.Add( Violation.Rule );
      Item.SubItems.Add( IntToStr( Violation.Line ) );
      Item.SubItems.Add( Violation.Expected );
      Item.SubItems.Add( Violation.Actual );
      Item.SubItems.Add( Violation.Severity );
      Item.Data := Pointer( NativeInt( Idx ) );
      Inc( Idx );
    end;

    // Update tab caption to show count
    if Length( FStyleViolations ) > 0 then
      tabStyleIssues.Caption := Format( 'Style Issues (%d)', [ Length( FStyleViolations ) ] )
    else
      tabStyleIssues.Caption := 'Style Issues';

    lvStyleIssues.CustomSort( nil, 0 );
  finally
    lvStyleIssues.Items.EndUpdate;
  end;

end;

procedure TFormBuildStatistics.PageControlChange( Sender: TObject );
begin
  // Update bottom panel labels based on current tab
  if PageControl.ActivePage = tabStyleIssues then
  begin
    lblTotalTime.Caption := Format( 'Style issues: %d', [ Length( FStyleViolations ) ] );
    lblFilter.Visible := False;
    cmbFilter.Visible := False;
    lblUnitCount.Caption := '';
  end
  else
  begin
    lblFilter.Visible := True;
    cmbFilter.Visible := True;
    PopulateList; // Refresh to update labels
  end;
end;

procedure TFormBuildStatistics.lvStyleIssuesColumnClick( Sender: TObject; Column: TListColumn );
begin

  if FStyleSortColumn = Column.Index then
    FStyleSortAscending := not FStyleSortAscending
  else
  begin
    FStyleSortColumn := Column.Index;
    FStyleSortAscending := ( FStyleSortColumn = 0 ); // Ascending for name
  end;

  lvStyleIssues.CustomSort( nil, 0 );

end;

procedure TFormBuildStatistics.lvStyleIssuesCompare( Sender: TObject; Item1, Item2: TListItem;
  Data: Integer; var Compare: Integer );
var
  S1, S2: string;
  SubIdx: Integer;
begin

  if FStyleSortColumn = 0 then
  begin
    S1 := Item1.Caption;
    S2 := Item2.Caption;
  end
  else
  begin
    SubIdx := FStyleSortColumn - 1;

    if SubIdx < Item1.SubItems.Count then
      S1 := Item1.SubItems[ SubIdx ]
    else
      S1 := '';

    if SubIdx < Item2.SubItems.Count then
      S2 := Item2.SubItems[ SubIdx ]
    else
      S2 := '';
  end;

  // Try numeric comparison for line number column (column 3)
  if FStyleSortColumn = 3 then
    Compare := StrToIntDef( S1, 0 ) - StrToIntDef( S2, 0 )
  else
    Compare := CompareText( S1, S2 );

  if not FStyleSortAscending then
    Compare := -Compare;

end;

procedure TFormBuildStatistics.lvStyleIssuesDblClick( Sender: TObject );
var
  Idx: Integer;
begin

  if lvStyleIssues.Selected = nil then
    Exit;

  Idx := NativeInt( lvStyleIssues.Selected.Data );

  if ( Idx >= 0 ) and ( Idx < Length( FStyleViolations ) ) then
    OpenStyleFile( FStyleViolations[ Idx ] );

end;

procedure TFormBuildStatistics.OpenStyleFile( const Violation: TStyleViolation );
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  I: Integer;
begin

  if Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
  begin
    Module := ModuleServices.OpenModule( Violation.FileName );

    if Module <> nil then
    begin

      for I := 0 to Module.ModuleFileCount - 1 do
      begin

        if Supports( Module.ModuleFileEditors[ I ], IOTASourceEditor, SourceEditor ) then
        begin
          SourceEditor.Show;

          if SourceEditor.EditViewCount > 0 then
          begin
            EditView := SourceEditor.EditViews[ 0 ];
            EditView.SetTopLeft( Violation.Line, 1 );
            EditView.Center( Violation.Line, Violation.Column );
          end;

          Break;
        end;
      end;
    end;
  end;

end;

procedure TFormBuildStatistics.mnuStyleCopyToClipboardClick( Sender: TObject );
var
  SL: TStringList;
  I: Integer;
  Item: TListItem;
begin

  SL := TStringList.Create;

  try
    SL.Add( 'Unit'#9'Category'#9'Rule'#9'Line'#9'Expected'#9'Actual'#9'Severity' );

    for I := 0 to lvStyleIssues.Items.Count - 1 do
    begin
      Item := lvStyleIssues.Items[ I ];

      if Item.SubItems.Count >= 6 then
        SL.Add( Format( '%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s',
          [ Item.Caption, Item.SubItems[ 0 ], Item.SubItems[ 1 ],
            Item.SubItems[ 2 ], Item.SubItems[ 3 ], Item.SubItems[ 4 ],
            Item.SubItems[ 5 ] ] ) );
    end;

    Clipboard.AsText := SL.Text;
  finally
    SL.Free;
  end;

end;

procedure TFormBuildStatistics.mnuStyleExportCSVClick( Sender: TObject );
var
  SL: TStringList;
  I: Integer;
  Item: TListItem;
begin

  if lvStyleIssues.Items.Count = 0 then
  begin
    ShowMessage( 'No style issues to export.' );
    Exit;
  end;

  SaveDialog.Title := 'Export Style Issues';

  if SaveDialog.Execute then
  begin
    SL := TStringList.Create;

    try
      SL.Add( '"Unit","Category","Rule","Line","Expected","Actual","Severity"' );

      for I := 0 to lvStyleIssues.Items.Count - 1 do
      begin
        Item := lvStyleIssues.Items[ I ];

        if Item.SubItems.Count >= 6 then
          SL.Add( Format( '"%s","%s","%s","%s","%s","%s","%s"',
            [ Item.Caption, Item.SubItems[ 0 ], Item.SubItems[ 1 ],
              Item.SubItems[ 2 ], Item.SubItems[ 3 ], Item.SubItems[ 4 ],
              Item.SubItems[ 5 ] ] ) );
      end;

      try
        SL.SaveToFile( SaveDialog.FileName );
      except
        on E: Exception do
          ShowMessage( 'Error saving file: ' + E.Message );
      end;
    finally
      SL.Free;
    end;
  end;

end;

procedure TFormBuildStatistics.mnuStyleOpenFileClick( Sender: TObject );
begin

  lvStyleIssuesDblClick( Sender );

end;

end.
