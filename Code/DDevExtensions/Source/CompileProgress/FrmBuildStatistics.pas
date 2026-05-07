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

/// <summary>
/// Non-modal dialog that presents the per-unit build timings, lines-of-code and complexity
/// metrics gathered during the most recent compile, together with any style-check
/// violations. Supports filtering, sorting, copying to clipboard, exporting to CSV and
/// double-click navigation to source files in the IDE.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Clipbrd, Menus, Math,
  ToolsAPI, FrmBase, CompileProgress, UnitMetrics;

type
  /// <summary>
  /// Filter used to restrict the units displayed in the build statistics list.
  /// </summary>
  TFileFilter = ( ffAll, ffProject, ffExternal );

  /// <summary>
  /// Singleton form that displays build statistics and code-style violations after a
  /// project compile. Use Execute to show or refresh the form.
  /// </summary>
  TFormBuildStatistics = class( TFormBase )
    /// <summary>Bottom panel hosting the action buttons and summary labels.</summary>
    pnlBottom: TPanel;
    /// <summary>Closes the dialog.</summary>
    btnClose: TButton;
    /// <summary>Copies the visible build-statistics rows to the clipboard as tab-separated text.</summary>
    btnCopyToClipboard: TButton;
    /// <summary>Exports the visible build-statistics rows to a CSV file.</summary>
    btnExportCSV: TButton;
    /// <summary>List view showing per-unit timings and metrics.</summary>
    ListView: TListView;
    /// <summary>Displays the total build time ( or style-issue count when the style tab is active ).</summary>
    lblTotalTime: TLabel;
    /// <summary>Displays the count of units, total lines of code and average complexity.</summary>
    lblUnitCount: TLabel;
    /// <summary>Caption label for the file filter combo box.</summary>
    lblFilter: TLabel;
    /// <summary>Filter selector ( All, Project, External ) for the build-statistics list.</summary>
    cmbFilter: TComboBox;
    /// <summary>Save dialog used by the CSV export actions.</summary>
    SaveDialog: TSaveDialog;
    /// <summary>Context menu attached to the build-statistics list view.</summary>
    PopupMenu: TPopupMenu;
    /// <summary>Pop-up menu item: copy build-statistics to clipboard.</summary>
    mnuCopyToClipboard: TMenuItem;
    /// <summary>Pop-up menu item: export build-statistics to CSV.</summary>
    mnuExportCSV: TMenuItem;
    /// <summary>Visual separator in the build-statistics pop-up menu.</summary>
    N1: TMenuItem;
    /// <summary>Pop-up menu item: sort build-statistics by unit name.</summary>
    mnuSortByName: TMenuItem;
    /// <summary>Pop-up menu item: sort build-statistics by compile duration.</summary>
    mnuSortByTime: TMenuItem;
    /// <summary>Pop-up menu item: sort build-statistics by lines of code.</summary>
    mnuSortByLOC: TMenuItem;
    /// <summary>Pop-up menu item: sort build-statistics by cyclomatic complexity.</summary>
    mnuSortByComplexity: TMenuItem;
    /// <summary>Hosts the Build Statistics and Style Issues tabs.</summary>
    PageControl: TPageControl;
    /// <summary>Tab containing the per-unit build statistics.</summary>
    tabBuildStats: TTabSheet;
    /// <summary>Tab containing the code-style violations.</summary>
    tabStyleIssues: TTabSheet;
    /// <summary>List view showing detected style violations.</summary>
    lvStyleIssues: TListView;
    /// <summary>Context menu attached to the style-issues list view.</summary>
    PopupMenuStyle: TPopupMenu;
    /// <summary>Pop-up menu item: copy style violations to clipboard.</summary>
    mnuStyleCopyToClipboard: TMenuItem;
    /// <summary>Pop-up menu item: export style violations to CSV.</summary>
    mnuStyleExportCSV: TMenuItem;
    /// <summary>Visual separator in the style-issues pop-up menu.</summary>
    N2: TMenuItem;
    /// <summary>Pop-up menu item: open the source file at the offending location.</summary>
    mnuStyleOpenFile: TMenuItem;
    /// <summary>Click handler for btnClose.</summary>
    procedure btnCloseClick( Sender: TObject );
    /// <summary>Click handler for btnCopyToClipboard.</summary>
    procedure btnCopyToClipboardClick( Sender: TObject );
    /// <summary>Click handler for btnExportCSV.</summary>
    procedure btnExportCSVClick( Sender: TObject );
    /// <summary>Closes the form by setting Action to caFree and clearing the singleton reference.</summary>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>Initialises default sort and filter state when the form is created.</summary>
    procedure FormCreate( Sender: TObject );
    /// <summary>Toggles or sets the sort column when a build-statistics column header is clicked.</summary>
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    /// <summary>Custom comparison callback for sorting build-statistics list items.</summary>
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    /// <summary>Sorts the build-statistics list ascending by unit name.</summary>
    procedure mnuSortByNameClick( Sender: TObject );
    /// <summary>Sorts the build-statistics list descending by compile time.</summary>
    procedure mnuSortByTimeClick( Sender: TObject );
    /// <summary>Sorts the build-statistics list descending by lines of code.</summary>
    procedure mnuSortByLOCClick( Sender: TObject );
    /// <summary>Sorts the build-statistics list descending by cyclomatic complexity.</summary>
    procedure mnuSortByComplexityClick( Sender: TObject );
    /// <summary>Updates FFileFilter and re-populates the list when the filter combo changes.</summary>
    procedure cmbFilterChange( Sender: TObject );
    /// <summary>Opens the source file for the selected unit in the IDE.</summary>
    procedure ListViewDblClick( Sender: TObject );
    /// <summary>Updates the bottom-panel summary labels when the active tab changes.</summary>
    procedure PageControlChange( Sender: TObject );
    /// <summary>Toggles or sets the sort column for the style-issues list.</summary>
    procedure lvStyleIssuesColumnClick( Sender: TObject; Column: TListColumn );
    /// <summary>Custom comparison callback for sorting style-issue list items.</summary>
    procedure lvStyleIssuesCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    /// <summary>Opens the source file at the violation location when a style row is double-clicked.</summary>
    procedure lvStyleIssuesDblClick( Sender: TObject );
    /// <summary>Click handler for the style-issues "Copy to Clipboard" pop-up menu item.</summary>
    procedure mnuStyleCopyToClipboardClick( Sender: TObject );
    /// <summary>Click handler for the style-issues "Export CSV" pop-up menu item.</summary>
    procedure mnuStyleExportCSVClick( Sender: TObject );
    /// <summary>Click handler for the "Open File" style-issues pop-up menu item; delegates to lvStyleIssuesDblClick.</summary>
    procedure mnuStyleOpenFileClick( Sender: TObject );
  private
    /// <summary>Source of build statistics data displayed by the form.</summary>
    FBuildStatistics: TBuildStatistics;
    /// <summary>Currently selected sort column index for the build-statistics list.</summary>
    FSortColumn: Integer;
    /// <summary>True when the build-statistics sort is ascending.</summary>
    FSortAscending: Boolean;
    /// <summary>Current file filter applied to the build-statistics list.</summary>
    FFileFilter: TFileFilter;
    /// <summary>Cached snapshot of style violations displayed on the Style Issues tab.</summary>
    FStyleViolations: TArray<TStyleViolation>;
    /// <summary>Currently selected sort column index for the style-issues list.</summary>
    FStyleSortColumn: Integer;
    /// <summary>True when the style-issues sort is ascending.</summary>
    FStyleSortAscending: Boolean;
    /// <summary>Rebuilds the build-statistics list view from FBuildStatistics, applying the current filter.</summary>
    procedure PopulateList;
    /// <summary>Rebuilds the style-issues list view from FStyleViolations and updates the tab caption.</summary>
    procedure PopulateStyleList;
    /// <summary>Formats a duration in milliseconds as ms, seconds or minutes.</summary>
    /// <param name="Ms">Duration in milliseconds.</param>
    /// <returns>Human-readable string such as "523 ms", "3.21 s" or "1.5 min".</returns>
    function FormatDuration( Ms: Int64 ): string;
    /// <summary>Returns True when the supplied file belongs to the currently compiled project.</summary>
    /// <param name="FileName">Source file name to test.</param>
    function IsProjectFile( const FileName: string ): Boolean;
    /// <summary>Opens the source file referenced by Violation in the IDE editor and centres on the violation line.</summary>
    /// <param name="Violation">Style violation describing the file and location to navigate to.</param>
    procedure OpenStyleFile( const Violation: TStyleViolation );
  public
    /// <summary>Shows the build-statistics dialog ( or refreshes it if already visible ).</summary>
    /// <param name="ABuildStatistics">Build-statistics object whose data will be displayed; ignored when nil.</param>
    class procedure Execute( ABuildStatistics: TBuildStatistics );
  end;

var
  /// <summary>Singleton instance reference; nil when the form is not currently shown.</summary>
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
