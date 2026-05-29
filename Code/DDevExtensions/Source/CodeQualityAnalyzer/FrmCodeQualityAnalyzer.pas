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
/// Singleton results window for the Code Quality Analyzer plugin. Initiates project-wide scans,
/// shows the issues in a sortable list view with category and severity filters, and supports
/// navigation, clipboard copy, and CSV export.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Clipbrd, System.Generics.Collections,
  FrmBase, CodeQualityAnalyzer, ToolsAPI;

type
  /// <summary>Singleton results form for the Code Quality Analyzer.</summary>
  TFormCodeQualityAnalyzer = class( TForm )
    /// <summary>Top toolbar panel.</summary>
    pnlTop: TPanel;
    /// <summary>Bottom action-button panel.</summary>
    pnlBottom: TGridPanel;
    /// <summary>Closes the form.</summary>
    btnClose: TButton;
    /// <summary>Initiates a project-wide scan.</summary>
    btnScan: TButton;
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
    btnExport: TButton;
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
    procedure btnCloseClick( Sender: TObject );
    /// <summary>OnClick handler for <see cref="btnScan"/> — runs a project scan.</summary>
    procedure btnScanClick( Sender: TObject );
    /// <summary>Initialises sort state and populates the filter combos.</summary>
    procedure FormCreate( Sender: TObject );
    /// <summary>Clears the result set and hides labels when the form closes.</summary>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>Clears the singleton reference when the form is destroyed.</summary>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Opens the file referenced by the double-clicked row.</summary>
    procedure ListViewDblClick( Sender: TObject );
    /// <summary>Context-menu handler that copies issue data to the clipboard.</summary>
    procedure mnuCopyToClipboardClick( Sender: TObject );
    /// <summary>Context-menu handler that opens the source file at the issue line.</summary>
    procedure mnuOpenFileClick( Sender: TObject );
    /// <summary>Exports the visible issues to a CSV file.</summary>
    procedure btnExportClick( Sender: TObject );
    /// <summary>Cycles the sort direction when a column header is clicked.</summary>
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    /// <summary>Custom comparator supporting numeric sort on the line-number column.</summary>
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    /// <summary>Re-applies filters when the category combo changes.</summary>
    procedure cboCategoryChange( Sender: TObject );
    /// <summary>Re-applies filters when the severity combo changes.</summary>
    procedure cboSeverityChange( Sender: TObject );
  private
    /// <summary>Latest scan results.</summary>
    FResults: TArray<TCodeQualityIssue>;
    /// <summary>Index of the column currently being sorted.</summary>
    FSortColumn: Integer;
    /// <summary>Sort direction flag.</summary>
    FSortAscending: Boolean;
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
  end;

implementation

{$R *.dfm}

uses
  ToolsAPIHelpers;

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
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
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
    ShowMessage( 'Code Quality Analyzer is not available.' );
    Exit;
  end;

  // Reset filters to show all results
  cboCategory.ItemIndex := 0;
  cboSeverity.ItemIndex := 0;

  ProjectName := ExtractFileName( Project.FileName );

  AllResults := TList<TCodeQualityIssue>.Create;
  try
    Screen.Cursor := crHourGlass;
    btnScan.Enabled := False;
    try
      lblProgress.Caption := 'Scanning ' + ProjectName + '...';
      lblProgress.Visible := True;
      lblSummary.Visible := False;
      Application.ProcessMessages;

      SkippedCount := 0;
      for I := 0 to Project.GetModuleCount - 1 do
      begin
        ModuleInfo := Project.GetModule( I );
        if ModuleInfo = nil then
          Continue;

        // Only scan Pascal files
        if not ( SameText( ExtractFileExt( ModuleInfo.FileName ), '.pas' ) or
                 SameText( ExtractFileExt( ModuleInfo.FileName ), '.pp' ) ) then
          Continue;

        lblProgress.Caption := 'Scanning: ' + ExtractFileName( ModuleInfo.FileName );
        Application.ProcessMessages;

        Source := '';
        try
          // Try to get source from open editor first
          Module := ModuleInfo.OpenModule;
          if Module <> nil then
          begin
            SourceEditor := nil;
            for J := 0 to Module.ModuleFileCount - 1 do
            begin
              if Supports( Module.ModuleFileEditors[ J ], IOTASourceEditor, SourceEditor ) then
                Break;
            end;

            if SourceEditor <> nil then
              Source := GetEditorSource( SourceEditor );
          end;

          // If no editor source, try to read from file
          if ( Source = '' ) and FileExists( ModuleInfo.FileName ) then
          begin
            var Sl := TStringList.Create;
            try
              Sl.LoadFromFile( ModuleInfo.FileName );
              Source := UTF8String( Sl.Text );
            finally
              Sl.Free;
            end;
          end;

          if Source <> '' then
          begin
            UnitResults := TCodeQualityAnalyzerPlugin.AnalyzeUnit( Source, ModuleInfo.FileName,
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
      btnScan.Enabled := True;
      Screen.Cursor := crDefault;
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
  FileName: string;
  LineNum: Integer;
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  I: Integer;
begin
  Item := ListView.Selected;
  if Item = nil then
    Exit;

  FileName := SafeGetSubItem( Item, 4 );  // File path is in SubItems[4]
  LineNum := StrToIntDef( SafeGetSubItem( Item, 0 ), 1 );

  if not FileExists( FileName ) then
  begin
    ShowMessage( 'File not found: ' + FileName );
    Exit;
  end;

  if Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
  begin
    Module := ModuleServices.OpenModule( FileName );
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
            if EditView <> nil then
            begin
              EditView.Position.Move( LineNum, 1 );
              EditView.MoveViewToCursor;
              EditView.Paint;
            end;
          end;
          Break;
        end;
      end;
    end;
  end;
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

    Clipboard.AsText := SL.Text;
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
        SL.SaveToFile( SaveDialog.FileName );
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
