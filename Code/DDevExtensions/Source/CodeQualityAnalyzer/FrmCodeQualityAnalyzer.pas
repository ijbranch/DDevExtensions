{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit FrmCodeQualityAnalyzer;

/// <summary>
/// Singleton results window for the Code Quality Analyser plugin. Initiates project-wide scans,
/// shows the issues in a sortable list view with category and severity filters, and supports
/// navigation, clipboard copy, and CSV export.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Buttons, System.Generics.Collections,
  FrmBase, CodeQualityAnalyzer, ToolsAPI;

type
  /// <summary>Singleton results form for the Code Quality Analyser.</summary>
  TFormCodeQualityAnalyzer = class( TForm )
    /// <summary>Top toolbar panel.</summary>
    pnlTop: TPanel;
    /// <summary>Bottom action-button panel.</summary>
    pnlBottom: TGridPanel;
    /// <summary>Closes the form.</summary>
    btnClose: TBitBtn;
    /// <summary>Initiates a project-wide scan.</summary>
    btnScan: TBitBtn;
    /// <summary>Stops a running scan; shown only while one runs.</summary>
    btnCancelScan: TBitBtn;
    /// <summary>List view displaying issues.</summary>
    ListView: TListView;
    /// <summary>Status text shown while scanning.</summary>
    lblProgress: TLabel;
    /// <summary>Context menu for the list view.</summary>
    PopupMenu: TPopupMenu;
    /// <summary>Copies the selected (or all) issues to the clipboard as TSV.</summary>
    mnuCopyToClipboard: TMenuItem;
    /// <summary>Separator menu item.</summary>
    N1: TMenuItem;
    /// <summary>Navigates the IDE to the selected issue.</summary>
    mnuOpenFile: TMenuItem;
    /// <summary>Exports all visible issues to CSV.</summary>
    btnExport: TBitBtn;
    /// <summary>File-save dialog used by <see cref="btnExport"/>.</summary>
    SaveDialog: TSaveDialog;
    /// <summary>Result summary text.</summary>
    lblSummary: TLabel;
    /// <summary>Filter combo for the issue category.</summary>
    cboCategory: TComboBox;
    /// <summary>Label for <see cref="cboCategory"/>.</summary>
    lblCategory: TLabel;
    /// <summary>Filter combo for severity.</summary>
    cboSeverity: TComboBox;
    /// <summary>Label for <see cref="cboSeverity"/>.</summary>
    lblSeverity: TLabel;
    /// <summary>OnClick handler for <see cref="btnClose"/>.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnCloseClick( Sender: TObject );
    /// <summary>OnClick handler for <see cref="btnScan"/> — runs a project scan.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnScanClick( Sender: TObject );
    /// <summary>Asks the running scan to stop at the next unit.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnCancelScanClick( Sender: TObject );
    /// <summary>Initialises sort state and populates the filter combos.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure FormCreate( Sender: TObject );
    /// <summary>Clears the result set and hides labels when the form closes; refuses to close while
    /// a scan runs.</summary>
    /// <param name="Sender">The form.</param>
    /// <param name="Action">Set to caNone while a scan runs.</param>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>Clears the singleton reference when the form is destroyed.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Opens the file referenced by the double-clicked row.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure ListViewDblClick( Sender: TObject );
    /// <summary>Context-menu handler that copies issue data to the clipboard.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure mnuCopyToClipboardClick( Sender: TObject );
    /// <summary>Context-menu handler that opens the source file at the issue line.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure mnuOpenFileClick( Sender: TObject );
    /// <summary>Exports the visible issues to a CSV file.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnExportClick( Sender: TObject );
    /// <summary>Cycles the sort direction when a column header is clicked.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    /// <param name="Column">The column whose header was clicked.</param>
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    /// <summary>Custom comparator supporting numeric sort on the line-number column.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    /// <param name="Item1">The first item to compare.</param>
    /// <param name="Item2">The second item to compare.</param>
    /// <param name="Data">Sort data passed to AlphaSort; not used.</param>
    /// <param name="Compare">Receives a negative, zero or positive value as Item1 sorts before, with or after
    /// Item2 in the current sort column and direction.</param>
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    /// <summary>Re-applies filters when the category combo changes.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure cboCategoryChange( Sender: TObject );
    /// <summary>Re-applies filters when the severity combo changes.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure cboSeverityChange( Sender: TObject );
  private
    /// <summary>Latest scan results.</summary>
    FResults: TArray<TCodeQualityIssue>;
    /// <summary>Index of the column currently being sorted.</summary>
    FSortColumn: Integer;
    /// <summary>Sort direction flag.</summary>
    FSortAscending: Boolean;
    /// <summary>True while a scan runs; the scan pumps messages, so this vetoes closing the form.</summary>
    FScanning: Boolean;
    /// <summary>Set by Cancel Scan; the running scan stops at the next unit.</summary>
    FCancelRequested: Boolean;
    /// <summary>Rebuilds the list view, delegating to <see cref="ApplyFilters"/>.</summary>
    procedure PopulateList;
    /// <summary>Opens the file/line of the currently selected list item in the IDE.</summary>
    procedure OpenSelectedFile;
    /// <summary>Re-renders the list view from <see cref="FResults"/> using the active filters.</summary>
    procedure ApplyFilters;
  public
    /// <summary>Displays the singleton form, creating it if required.</summary>
    /// <returns><c>True</c> when the form was shown.</returns>
    class function Execute: Boolean;
    /// <summary>Frees the singleton form, if open, so it cannot outlive the plugin on unload.</summary>
    class procedure CloseInstance;
  end;

implementation

{$R *.dfm}

uses
  ToolsAPIHelpers, IdeUnitSource;

function SafeGetSubItem( Item: TListItem; Index: Integer ): string;
begin
  if ( Item <> nil ) and ( Index < Item.SubItems.Count ) then
    Result := Item.SubItems[ Index ]
  else
    Result := '';
end;

var
  FormCodeQualityAnalyzerInstance: TFormCodeQualityAnalyzer = nil;

class function TFormCodeQualityAnalyzer.Execute: Boolean;
begin
  // Use singleton pattern - create once, reuse on subsequent calls
  if FormCodeQualityAnalyzerInstance = nil then
    FormCodeQualityAnalyzerInstance := TFormCodeQualityAnalyzer.Create( Application );

  FormCodeQualityAnalyzerInstance.Show;
  FormCodeQualityAnalyzerInstance.BringToFront;
  Result := True;
end;

class procedure TFormCodeQualityAnalyzer.CloseInstance;
begin
  if ( FormCodeQualityAnalyzerInstance <> nil ) then
    FreeAndNil( FormCodeQualityAnalyzerInstance );
end;

procedure TFormCodeQualityAnalyzer.btnCancelScanClick( Sender: TObject );
begin
  FCancelRequested := True;
end;

procedure TFormCodeQualityAnalyzer.FormCreate( Sender: TObject );
begin
  FSortColumn := 0;
  FSortAscending := True;

  // Populate category filter
  cboCategory.Items.Clear;
  cboCategory.Items.Add( '(All)' );
  cboCategory.Items.Add( 'Magic Number' );
  cboCategory.Items.Add( 'Hardcoded String' );
  cboCategory.Items.Add( 'Commented Code' );
  cboCategory.Items.Add( 'Empty Except' );
  cboCategory.Items.Add( 'Catch-All Exception' );
  cboCategory.Items.Add( 'Missing Try/Finally' );
  cboCategory.Items.Add( 'Memory Leak' );
  cboCategory.ItemIndex := 0;

  // Populate severity filter
  cboSeverity.Items.Clear;
  cboSeverity.Items.Add( '(All)' );
  cboSeverity.Items.Add( 'Info' );
  cboSeverity.Items.Add( 'Warning' );
  cboSeverity.Items.Add( 'Error' );
  cboSeverity.ItemIndex := 0;
end;

procedure TFormCodeQualityAnalyzer.FormClose( Sender: TObject; var Action: TCloseAction );
begin
  // The scan pumps messages: closing now would clear the list under it.
  if FScanning then
  begin
    Action := caNone;
    Exit;
  end;
  // Clear results when dialog is closed
  ListView.Items.Clear;
  SetLength( FResults, 0 );
  lblSummary.Visible := False;
  lblProgress.Visible := False;
end;

procedure TFormCodeQualityAnalyzer.FormDestroy( Sender: TObject );
begin
  // Clear singleton reference when form is destroyed
  if FormCodeQualityAnalyzerInstance = Self then
    FormCodeQualityAnalyzerInstance := nil;
end;

procedure TFormCodeQualityAnalyzer.btnCloseClick( Sender: TObject );
begin
  Close;
end;

procedure TFormCodeQualityAnalyzer.btnScanClick( Sender: TObject );
var
  Project: IOTAProject;
  ModuleInfo: IOTAModuleInfo;
  I, J: Integer;
  Source: UTF8String;
  UnitResults: TArray<TCodeQualityIssue>;
  AllResults: TList<TCodeQualityIssue>;
  ProjectName: string;
  SkippedCount: Integer;
begin
  Project := GetActiveProject;
  if Project = nil then
  begin
    ShowMessage( 'No active project.' );
    Exit;
  end;

  if CodeQualityAnalyzerPlugin = nil then
  begin
    ShowMessage( 'Code Quality Analyser is not available.' );
    Exit;
  end;

  // Reset filters to show all results
  cboCategory.ItemIndex := 0;
  cboSeverity.ItemIndex := 0;

  ProjectName := ExtractFileName( Project.FileName );

  { The file list and the project's identity are taken now, before the first message pump: the
    project can change or close while the scan runs. }
  var Identity := ProjectIdentity( Project );
  var Files: TArray<string> := nil;
  for I := 0 to Project.GetModuleCount - 1 do
  begin
    ModuleInfo := Project.GetModule( I );
    if ( ModuleInfo <> nil ) and ( SameText( ExtractFileExt( ModuleInfo.FileName ), '.pas' ) or
       SameText( ExtractFileExt( ModuleInfo.FileName ), '.pp' ) ) then
      Files := Files + [ ModuleInfo.FileName ];
  end;

  AllResults := TList<TCodeQualityIssue>.Create;
  try
    Screen.Cursor         := crHourGlass;
    btnScan.Visible       := False;
    btnCancelScan.Visible := True;
    FCancelRequested      := False;
    FScanning             := True;
    try
      lblProgress.Caption := 'Scanning ' + ProjectName + '...';
      lblProgress.Visible := True;
      lblSummary.Visible := False;
      Application.ProcessMessages;

      SkippedCount := 0;
      for var sFile in Files do
      begin
        // Stop on Cancel Scan, when the IDE is closing ( the pump swallowed its WM_QUIT ), and when
        // the scanned project was closed or another made active.
        if FCancelRequested or Application.Terminated or ( not IsActiveProject( Identity ) ) then
        begin
          FResults := nil;
          PopulateList;
          lblProgress.Visible := False;
          lblSummary.Caption  := 'Scan cancelled.';
          lblSummary.Visible  := True;
          Exit;
        end;

        lblProgress.Caption := 'Scanning: ' + ExtractFileName( sFile );
        Application.ProcessMessages;

        Source := '';
        try
          // The editor buffer of an open unit, otherwise the file on disk ( decoded as the IDE
          // decodes it ); a scan never opens a module.
          if ( not ReadUnitSource( sFile, Source ) ) then
            Source := '';

          if Source <> '' then
          begin
            UnitResults := TCodeQualityAnalyzerPlugin.AnalyzeUnit( Source, sFile,
              CodeQualityAnalyzerPlugin );
            for J := 0 to Length( UnitResults ) - 1 do
              AllResults.Add( UnitResults[ J ] );
          end
          else
            Inc( SkippedCount );
        except
          // One unreadable or malformed unit must not abort the whole project
          // scan - record it and carry on so the rest of the project is scanned.
          on E: Exception do
            Inc( SkippedCount );
        end;
      end;

      FResults := AllResults.ToArray;
      PopulateList;

      lblProgress.Visible := False;
      if SkippedCount > 0 then
        lblSummary.Caption := Format( 'Found %d issue(s) in %s; %d file(s) could not be read',
          [ Length( FResults ), ProjectName, SkippedCount ] )
      else
        lblSummary.Caption := Format( 'Found %d issue(s) in %s',
          [ Length( FResults ), ProjectName ] );
      lblSummary.Visible := True;
    finally
      FScanning             := False;
      btnCancelScan.Visible := False;
      btnScan.Visible       := True;
      Screen.Cursor         := crDefault;
    end;
  finally
    AllResults.Free;
  end;
end;

procedure TFormCodeQualityAnalyzer.PopulateList;
begin
  ApplyFilters;
end;

procedure TFormCodeQualityAnalyzer.ApplyFilters;
var
  Issue: TCodeQualityIssue;
  Item: TListItem;
  CategoryFilter: string;
  SeverityFilter: string;
  ShowItem: Boolean;
  VisibleCount: Integer;
begin
  ListView.Items.BeginUpdate;
  try
    ListView.Items.Clear;

    CategoryFilter := cboCategory.Text;
    SeverityFilter := cboSeverity.Text;
    VisibleCount := 0;

    for Issue in FResults do
    begin
      ShowItem := True;

      // Apply category filter
      if ( CategoryFilter <> '(All)' ) and
         ( IssueCategoryToString( Issue.Category ) <> CategoryFilter ) then
        ShowItem := False;

      // Apply severity filter
      if ShowItem and ( SeverityFilter <> '(All)' ) and
         ( IssueSeverityToString( Issue.Severity ) <> SeverityFilter ) then
        ShowItem := False;

      if ShowItem then
      begin
        Item := ListView.Items.Add;
        Item.Caption := Issue.UnitName;
        Item.SubItems.Add( IntToStr( Issue.Line ) );
        Item.SubItems.Add( IssueCategoryToString( Issue.Category ) );
        Item.SubItems.Add( IssueSeverityToString( Issue.Severity ) );
        Item.SubItems.Add( Issue.Description );
        Item.SubItems.Add( Issue.FileName );
        Inc( VisibleCount );
      end;
    end;

    // Update summary with filter info
    if ( CategoryFilter <> '(All)' ) or ( SeverityFilter <> '(All)' ) then
      lblSummary.Caption := Format( 'Showing %d of %d issue(s)',
        [ VisibleCount, Length( FResults ) ] )
    else
      lblSummary.Caption := Format( 'Found %d issue(s)', [ Length( FResults ) ] );

  finally
    ListView.Items.EndUpdate;
  end;
end;

procedure TFormCodeQualityAnalyzer.cboCategoryChange( Sender: TObject );
begin
  ApplyFilters;
end;

procedure TFormCodeQualityAnalyzer.cboSeverityChange( Sender: TObject );
begin
  ApplyFilters;
end;

procedure TFormCodeQualityAnalyzer.ListViewColumnClick( Sender: TObject;
  Column: TListColumn );
begin
  if FSortColumn = Column.Index then
    FSortAscending := not FSortAscending
  else
  begin
    FSortColumn := Column.Index;
    FSortAscending := True;
  end;
  ListView.AlphaSort;
end;

procedure TFormCodeQualityAnalyzer.ListViewCompare( Sender: TObject; Item1,
  Item2: TListItem; Data: Integer; var Compare: Integer );
var
  S1, S2: string;
  SubIdx: Integer;
  N1, N2: Integer;
begin
  if FSortColumn = 0 then
  begin
    S1 := Item1.Caption;
    S2 := Item2.Caption;
    Compare := CompareText( S1, S2 );
  end
  else if FSortColumn = 1 then // Line number - numeric sort
  begin
    N1 := StrToIntDef( SafeGetSubItem( Item1, 0 ), 0 );
    N2 := StrToIntDef( SafeGetSubItem( Item2, 0 ), 0 );
    Compare := N1 - N2;
  end
  else
  begin
    SubIdx := FSortColumn - 1;
    S1 := SafeGetSubItem( Item1, SubIdx );
    S2 := SafeGetSubItem( Item2, SubIdx );
    Compare := CompareText( S1, S2 );
  end;

  if not FSortAscending then
    Compare := -Compare;
end;

procedure TFormCodeQualityAnalyzer.ListViewDblClick( Sender: TObject );
begin
  OpenSelectedFile;
end;

procedure TFormCodeQualityAnalyzer.OpenSelectedFile;
var
  Item: TListItem;
begin
  Item := ListView.Selected;
  if ( Item = nil ) then
    Exit;

  // File path is in SubItems[4], the line in SubItems[0].
  OpenFileAtLine( SafeGetSubItem( Item, 4 ), StrToIntDef( SafeGetSubItem( Item, 0 ), 1 ), 1 );
end;

procedure TFormCodeQualityAnalyzer.mnuOpenFileClick( Sender: TObject );
begin
  OpenSelectedFile;
end;

procedure TFormCodeQualityAnalyzer.mnuCopyToClipboardClick( Sender: TObject );
var
  SL: TStringList;
  Item: TListItem;
begin
  SL := TStringList.Create;
  try
    SL.Add( 'Unit'#9'Line'#9'Category'#9'Severity'#9'Description'#9'File' );

    for Item in ListView.Items do
    begin
      if Item.Selected or ( ListView.SelCount = 0 ) then
        SL.Add( Format( '%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s', [
          Item.Caption,
          SafeGetSubItem( Item, 0 ),
          SafeGetSubItem( Item, 1 ),
          SafeGetSubItem( Item, 2 ),
          SafeGetSubItem( Item, 3 ),
          SafeGetSubItem( Item, 4 )
        ] ) );
    end;

    CopyTextToClipboard( SL.Text );
  finally
    SL.Free;
  end;
end;

procedure TFormCodeQualityAnalyzer.btnExportClick( Sender: TObject );
var
  SL: TStringList;
  Item: TListItem;
begin
  if ListView.Items.Count = 0 then
  begin
    ShowMessage( 'No data to export.' );
    Exit;
  end;

  if SaveDialog.Execute then
  begin
    SL := TStringList.Create;
    try
      SL.Add( 'Unit,Line,Category,Severity,Description,File' );

      for Item in ListView.Items do
      begin
        // Double embedded quotes per RFC 4180 so descriptions / previews
        // containing quotes or commas cannot break the CSV column alignment.
        SL.Add( Format( '"%s","%s","%s","%s","%s","%s"', [
          StringReplace( Item.Caption, '"', '""', [ rfReplaceAll ] ),
          StringReplace( SafeGetSubItem( Item, 0 ), '"', '""', [ rfReplaceAll ] ),
          StringReplace( SafeGetSubItem( Item, 1 ), '"', '""', [ rfReplaceAll ] ),
          StringReplace( SafeGetSubItem( Item, 2 ), '"', '""', [ rfReplaceAll ] ),
          StringReplace( SafeGetSubItem( Item, 3 ), '"', '""', [ rfReplaceAll ] ),
          StringReplace( SafeGetSubItem( Item, 4 ), '"', '""', [ rfReplaceAll ] )
        ] ) );
      end;

      try
        // UTF-8: descriptions quote string literals, which are not limited to the ANSI code page.
        SL.SaveToFile( SaveDialog.FileName, TEncoding.UTF8 );
        ShowMessage( Format( 'Exported %d items to %s', [ ListView.Items.Count, SaveDialog.FileName ] ) );
      except
        on E: Exception do
          ShowMessage( 'Error saving file: ' + E.Message );
      end;
    finally
      SL.Free;
    end;
  end;
end;

end.
