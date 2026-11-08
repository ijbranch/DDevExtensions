{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmCodeStyleChecker;

/// <summary>
/// Results window for the Code Style Checker. Triggers project-wide scans, displays the
/// violations in a sortable, filterable list view, and supports navigating to the offending
/// source line as well as copying or exporting the data.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Buttons, System.Generics.Collections,
  System.Generics.Defaults, FrmBase, CodeStyleChecker, ToolsAPI;

type
  /// <summary>Singleton results form for the Code Style Checker.</summary>
  TFormCodeStyleChecker = class( TFormBase )
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
    /// <summary>List view displaying violations.</summary>
    ListView: TListView;
    /// <summary>Status text shown while a scan is in progress.</summary>
    lblProgress: TLabel;
    /// <summary>Context menu attached to the list view.</summary>
    PopupMenu: TPopupMenu;
    /// <summary>Copies the selected (or all) violations to the clipboard as TSV.</summary>
    mnuCopyToClipboard: TMenuItem;
    /// <summary>Separator menu item.</summary>
    N1: TMenuItem;
    /// <summary>Navigates the IDE editor to the selected violation.</summary>
    mnuOpenFile: TMenuItem;
    /// <summary>Exports all visible violations to CSV.</summary>
    btnExport: TBitBtn;
    /// <summary>File-save dialog used by <see cref="btnExport"/>.</summary>
    SaveDialog: TSaveDialog;
    /// <summary>Result summary text displayed after a scan completes.</summary>
    lblSummary: TLabel;
    /// <summary>Filter combo for the violation category.</summary>
    cboCategory: TComboBox;
    /// <summary>Label for <see cref="cboCategory"/>.</summary>
    lblCategory: TLabel;
    /// <summary>Filter combo for individual rules.</summary>
    cboRule: TComboBox;
    /// <summary>Label for <see cref="cboRule"/>.</summary>
    lblRule: TLabel;
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
    /// <summary>Releases the singleton instance when the form closes.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    /// <param name="Action">Set to caNone while a scan runs, which keeps the form open; otherwise caFree.</param>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>Creates the checker engine and populates the filter combos.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure FormCreate( Sender: TObject );
    /// <summary>Frees the checker engine.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Opens the file represented by the double-clicked row.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure ListViewDblClick( Sender: TObject );
    /// <summary>Context-menu handler that copies violation data to the clipboard.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure mnuCopyToClipboardClick( Sender: TObject );
    /// <summary>Context-menu handler that opens the source file at the violation line.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure mnuOpenFileClick( Sender: TObject );
    /// <summary>Exports the visible violations to a CSV file.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnExportClick( Sender: TObject );
    /// <summary>Cycles sort direction when a column header is clicked.</summary>
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
    /// <summary>Re-applies filters when the rule combo changes.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure cboRuleChange( Sender: TObject );
    /// <summary>Re-applies filters when the severity combo changes.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure cboSeverityChange( Sender: TObject );
  private
    /// <summary>Engine performing the analysis.</summary>
    FChecker: TStyleChecker;
    /// <summary>True while a project scan is running; used to veto closing the form mid-scan (the scan pumps the
    /// message queue, so an unguarded close would free the form and FChecker underneath it).</summary>
    FScanning: Boolean;
    /// <summary>Set by Cancel Scan; the running scan stops at the next unit.</summary>
    FCancelRequested: Boolean;
    /// <summary>Latest scan results.</summary>
    FViolations: TArray<TStyleViolation>;
    /// <summary>Index of the column currently being sorted.</summary>
    FSortColumn: Integer;
    /// <summary>Sort direction flag.</summary>
    FSortAscending: Boolean;
    /// <summary>Rebuilds the list view from <see cref="FViolations"/>, applying current filters.</summary>
    procedure PopulateList;
    /// <summary>Progress callback invoked by <see cref="TStyleChecker"/> between files.</summary>
    /// <param name="Sender">The TStyleChecker; its ProgressFileName names the file about to be checked.</param>
    procedure CheckerProgress( Sender: TObject );
    /// <summary>Opens the file/line of the currently selected list item in the IDE.</summary>
    procedure OpenSelectedFile;
    /// <summary>Returns <c>True</c> when the supplied violation matches all currently active filters.</summary>
    /// <param name="Item">Violation under test.</param>
    /// <returns>True when the violation should be listed.</returns>
    function PassesFilter( const Item: TStyleViolation ): Boolean;
  public
    /// <summary>Displays the singleton form, creating it if required.</summary>
    class procedure Execute;
    /// <summary>Frees the singleton form, if open, so it cannot outlive the plugin on unload.</summary>
    class procedure CloseInstance;
  end;

var
  /// <summary>Singleton form reference; <c>nil</c> when the form is not visible.</summary>
  FormInstance: TFormCodeStyleChecker = nil;

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

class procedure TFormCodeStyleChecker.Execute;
begin

  // If already open, bring to front
  if FormInstance <> nil then
  begin
    FormInstance.Show;
    FormInstance.BringToFront;
    Exit;
  end;

  FormInstance := TFormCodeStyleChecker.Create( Application );
  FormInstance.Show;

end;

class procedure TFormCodeStyleChecker.CloseInstance;
begin

  if ( FormInstance <> nil ) then
    FreeAndNil( FormInstance );

end;

procedure TFormCodeStyleChecker.btnCancelScanClick( Sender: TObject );
begin

  FCancelRequested := True;

end;

procedure TFormCodeStyleChecker.FormCreate( Sender: TObject );
begin

  FChecker       := TStyleChecker.Create;
  FSortColumn    := 0;
  FSortAscending := True;

  // Set up category filter
  cboCategory.Items.Add( '(All)' );
  cboCategory.Items.Add( 'NamingConvention' );
  cboCategory.Items.Add( 'AntiPattern' );
  cboCategory.ItemIndex := 0;

  // Set up rule filter - naming conventions
  cboRule.Items.Add( '(All)' );
  cboRule.Items.Add( 'TypePrefix' );
  cboRule.Items.Add( 'InterfacePrefix' );
  cboRule.Items.Add( 'FieldPrefix' );
  cboRule.Items.Add( 'FieldTypePrefix' );
  cboRule.Items.Add( 'ExceptionPrefix' );
  cboRule.Items.Add( 'PointerPrefix' );
  cboRule.Items.Add( 'ParameterPrefix' );
  cboRule.Items.Add( 'VariablePrefix' );
  cboRule.Items.Add( 'UnitScopePrefix' );
  // Anti-pattern rules
  cboRule.Items.Add( 'EmptyFinally' );
  cboRule.Items.Add( 'NestedWith' );
  cboRule.Items.Add( 'DeepNesting' );
  cboRule.Items.Add( 'LongMethod' );
  cboRule.Items.Add( 'LongParamList' );
  cboRule.ItemIndex := 0;

  // Set up severity filter
  cboSeverity.Items.Add( '(All)' );
  cboSeverity.Items.Add( 'Warning' );
  cboSeverity.Items.Add( 'Info' );
  cboSeverity.ItemIndex := 0;

end;

procedure TFormCodeStyleChecker.FormDestroy( Sender: TObject );
begin

  FChecker.Free;

end;

procedure TFormCodeStyleChecker.CheckerProgress( Sender: TObject );
begin

  if Sender is TStyleChecker then
    lblProgress.Caption := 'Checking: ' + TStyleChecker( Sender ).ProgressFileName;

  Application.ProcessMessages;

  // Stop on Cancel Scan, and when the IDE is closing: the pump above swallowed its WM_QUIT.
  if FCancelRequested or Application.Terminated then
    Abort;

end;

procedure TFormCodeStyleChecker.btnCloseClick( Sender: TObject );
begin

  Close;

end;

procedure TFormCodeStyleChecker.FormClose( Sender: TObject; var Action: TCloseAction );
begin

  // A scan pumps the message queue (ProcessMessages in CheckerProgress), so the
  // user can trigger a close mid-scan. Veto it while scanning, otherwise the
  // form and FChecker are freed while CheckProject is still on the stack.
  if FScanning then
  begin
    Action := caNone;
    Exit;
  end;

  FormInstance := nil;
  Action       := caFree;

end;

procedure TFormCodeStyleChecker.btnScanClick( Sender: TObject );
var
  Project: IOTAProject;
begin

  Project := GetActiveProject;

  if Project = nil then
  begin
    ShowMessage( 'No active project.' );
    Exit;
  end;

  Screen.Cursor         := crHourGlass;
  btnScan.Visible       := False;
  btnCancelScan.Visible := True;
  FCancelRequested      := False;
  FScanning             := True;

  try
    lblProgress.Caption := 'Checking project...';
    lblProgress.Visible := True;
    lblSummary.Visible  := False;
    Application.ProcessMessages;

    try
      FChecker.CheckProject( Project, FViolations, CheckerProgress );
    except
      on EAbort do
      begin
        FViolations := nil;
        PopulateList;
        lblProgress.Visible := False;
        lblSummary.Caption  := 'Scan cancelled.';
        lblSummary.Visible  := True;
        Exit;
      end;
    end;
    PopulateList;

    lblProgress.Visible := False;
    lblSummary.Caption  := Format( 'Found %d style violations', [ Length( FViolations ) ] );
    lblSummary.Visible  := True;
  finally
    FScanning             := False;
    btnCancelScan.Visible := False;
    btnScan.Visible       := True;
    Screen.Cursor         := crDefault;
  end;

end;

function TFormCodeStyleChecker.PassesFilter( const Item: TStyleViolation ): Boolean;
var
  CategoryFilter, RuleFilter, SeverityFilter: string;
begin

  Result := True;

  // Check category filter
  if cboCategory.ItemIndex > 0 then
  begin
    CategoryFilter := cboCategory.Items[ cboCategory.ItemIndex ];

    if not SameText( Item.Category, CategoryFilter ) then
      Result := False;
  end;

  // Check rule filter
  if Result and ( cboRule.ItemIndex > 0 ) then
  begin
    RuleFilter := cboRule.Items[ cboRule.ItemIndex ];

    if not SameText( Item.Rule, RuleFilter ) then
      Result := False;
  end;

  // Check severity filter
  if Result and ( cboSeverity.ItemIndex > 0 ) then
  begin
    SeverityFilter := cboSeverity.Items[ cboSeverity.ItemIndex ];

    if not SameText( Item.Severity, SeverityFilter ) then
      Result := False;
  end;

end;

procedure TFormCodeStyleChecker.PopulateList;
var
  Violation: TStyleViolation;
  Item: TListItem;
  Idx: Integer;
  Category: string;
begin

  ListView.Items.BeginUpdate;

  try
    ListView.Items.Clear;
    Idx := 0;

    for Violation in FViolations do
    begin

      if PassesFilter( Violation ) then
      begin
        Item         := ListView.Items.Add;
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
      end;

      Inc( Idx );
    end;
  finally
    ListView.Items.EndUpdate;
  end;

end;

procedure TFormCodeStyleChecker.cboCategoryChange( Sender: TObject );
begin

  PopulateList;

end;

procedure TFormCodeStyleChecker.cboRuleChange( Sender: TObject );
begin

  PopulateList;

end;

procedure TFormCodeStyleChecker.cboSeverityChange( Sender: TObject );
begin

  PopulateList;

end;

procedure TFormCodeStyleChecker.ListViewColumnClick( Sender: TObject;
  Column: TListColumn );
begin

  if FSortColumn = Column.Index then
    FSortAscending := not FSortAscending
  else
  begin
    FSortColumn    := Column.Index;
    FSortAscending := True;
  end;

  ListView.AlphaSort;

end;

procedure TFormCodeStyleChecker.ListViewCompare( Sender: TObject; Item1,
  Item2: TListItem; Data: Integer; var Compare: Integer );
var
  S1, S2: string;
  SubIdx: Integer;
begin

  if FSortColumn = 0 then
  begin
    S1 := Item1.Caption;
    S2 := Item2.Caption;
  end
  else
  begin
    SubIdx := FSortColumn - 1;

    if SubIdx < Item1.SubItems.Count then
      S1 := Item1.SubItems[ SubIdx ]
    else
      S1 := '';

    if SubIdx < Item2.SubItems.Count then
      S2 := Item2.SubItems[ SubIdx ]
    else
      S2 := '';
  end;

  // Try numeric comparison for line number column (now column 3)
  if FSortColumn = 3 then
    Compare := StrToIntDef( S1, 0 ) - StrToIntDef( S2, 0 )
  else
    Compare := CompareText( S1, S2 );

  if not FSortAscending then
    Compare := -Compare;

end;

procedure TFormCodeStyleChecker.ListViewDblClick( Sender: TObject );
begin

  OpenSelectedFile;

end;

procedure TFormCodeStyleChecker.OpenSelectedFile;
var
  Idx: Integer;
  Violation: TStyleViolation;
begin

  if ListView.Selected = nil then
    Exit;

  Idx := NativeInt( ListView.Selected.Data );

  if ( Idx < 0 ) or ( Idx >= Length( FViolations ) ) then
    Exit;

  Violation := FViolations[ Idx ];

  // Synthetic violations (LongMethod, EmptyFinally) carry Column 0; OpenFileAtLine clamps it to 1.
  OpenFileAtLine( Violation.FileName, Violation.Line, Violation.Column );

end;

procedure TFormCodeStyleChecker.mnuOpenFileClick( Sender: TObject );
begin

  OpenSelectedFile;

end;

procedure TFormCodeStyleChecker.mnuCopyToClipboardClick( Sender: TObject );
var
  SL: TStringList;
  Item: TListItem;
begin

  SL := TStringList.Create;

  try
    SL.Add( 'Unit'#9'Category'#9'Rule'#9'Line'#9'Expected'#9'Actual'#9'Severity' );

    for Item in ListView.Items do
    begin

      if Item.Selected or ( ListView.SelCount = 0 ) then
        SL.Add( Format( '%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s', [
          Item.Caption,
          SafeGetSubItem( Item, 0 ),
          SafeGetSubItem( Item, 1 ),
          SafeGetSubItem( Item, 2 ),
          SafeGetSubItem( Item, 3 ),
          SafeGetSubItem( Item, 4 ),
          SafeGetSubItem( Item, 5 )
        ] ) );
    end;

    CopyTextToClipboard( SL.Text );
  finally
    SL.Free;
  end;

end;

procedure TFormCodeStyleChecker.btnExportClick( Sender: TObject );

  function CsvField( const S: string ): string;
  begin
    // RFC 4180: wrap in quotes and double any embedded quote so commas,
    // parentheses and quotes in the rule text cannot corrupt the CSV.
    Result := '"' + StringReplace( S, '"', '""', [ rfReplaceAll ] ) + '"';
  end;

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
      SL.Add( 'Unit,Category,Rule,Line,Expected,Actual,Severity' );

      for Item in ListView.Items do
      begin
        SL.Add(
          CsvField( Item.Caption ) + ',' +
          CsvField( SafeGetSubItem( Item, 0 ) ) + ',' +
          CsvField( SafeGetSubItem( Item, 1 ) ) + ',' +
          CsvField( SafeGetSubItem( Item, 2 ) ) + ',' +
          CsvField( SafeGetSubItem( Item, 3 ) ) + ',' +
          CsvField( SafeGetSubItem( Item, 4 ) ) + ',' +
          CsvField( SafeGetSubItem( Item, 5 ) ) );
      end;

      try
        // UTF-8: identifiers and paths are not limited to the ANSI code page.
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
