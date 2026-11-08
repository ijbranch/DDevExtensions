{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmTodoAggregator;

/// <summary>
/// Modeless form that displays the aggregated TODO/FIXME results for the active project.
/// Provides category and priority filters, a sortable list view, double-click navigation
/// into the source editor, copy-to-clipboard and CSV export.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Buttons, System.Generics.Collections,
  System.Generics.Defaults, FrmBase, TodoAggregator, TodoAggregatorCore, ToolsAPI;

type
  /// <summary>
  /// Singleton aggregator form created by TTodoAggregatorPlugin.ShowAggregator.
  /// </summary>
  TFormTodoAggregator = class( TFormBase )
    /// <summary>Top toolbar panel containing the scan button and filters.</summary>
    pnlTop: TPanel;
    /// <summary>Bottom grid panel hosting Close and Export buttons.</summary>
    pnlBottom: TGridPanel;
    /// <summary>Closes the form.</summary>
    btnClose: TButton;
    /// <summary>Scans the active project for TODO comments.</summary>
    btnScan: TButton;
    /// <summary>Stops a running scan; shown only while one runs.</summary>
    btnCancelScan: TBitBtn;
    /// <summary>List view that presents matched TODO items.</summary>
    ListView: TListView;
    /// <summary>Status label showing the file currently being scanned.</summary>
    lblProgress: TLabel;
    /// <summary>Popup menu attached to the list view.</summary>
    PopupMenu: TPopupMenu;
    /// <summary>Menu item that copies selected (or all) rows to the clipboard as TSV.</summary>
    mnuCopyToClipboard: TMenuItem;
    /// <summary>Menu separator.</summary>
    N1: TMenuItem;
    /// <summary>Menu item that opens the selected source file at the TODO location.</summary>
    mnuOpenFile: TMenuItem;
    /// <summary>Exports the visible rows to a CSV file.</summary>
    btnExport: TButton;
    /// <summary>Save dialog used by the export action.</summary>
    SaveDialog: TSaveDialog;
    /// <summary>Summary label showing the total number of matches.</summary>
    lblSummary: TLabel;
    /// <summary>Combo box filtering by category (TODO, FIXME, ...).</summary>
    cboCategory: TComboBox;
    /// <summary>Label for the category combo box.</summary>
    lblCategory: TLabel;
    /// <summary>Combo box filtering by priority (High, Normal, Low).</summary>
    cboPriority: TComboBox;
    /// <summary>Label for the priority combo box.</summary>
    lblPriority: TLabel;
    /// <summary>OnClick handler for the Close button.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnCloseClick( Sender: TObject );
    /// <summary>OnClick handler for the Scan button; runs the project scanner and refreshes the list.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnScanClick( Sender: TObject );
    /// <summary>Asks the running scan to stop at the next unit.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnCancelScanClick( Sender: TObject );
    /// <summary>OnClose handler that releases the singleton instance.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    /// <param name="Action">Set to caNone while a scan runs, which keeps the form open; otherwise caFree.</param>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>OnCreate handler that initialises the scanner and filter combo boxes.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure FormCreate( Sender: TObject );
    /// <summary>OnDestroy handler that frees the scanner.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Double-click handler that opens the selected file in the IDE editor.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure ListViewDblClick( Sender: TObject );
    /// <summary>OnClick handler for the copy-to-clipboard menu item.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure mnuCopyToClipboardClick( Sender: TObject );
    /// <summary>OnClick handler for the open-file menu item.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure mnuOpenFileClick( Sender: TObject );
    /// <summary>OnClick handler for the Export button.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnExportClick( Sender: TObject );
    /// <summary>Toggles ascending/descending order on column header clicks.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    /// <param name="Column">The column whose header was clicked.</param>
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    /// <summary>Custom-sort comparator honouring numeric and priority columns.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    /// <param name="Item1">The first item to compare.</param>
    /// <param name="Item2">The second item to compare.</param>
    /// <param name="Data">Sort data passed to AlphaSort; not used.</param>
    /// <param name="Compare">Receives a negative, zero or positive value as Item1 sorts before, with or after
    /// Item2 in the current sort column and direction.</param>
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    /// <summary>Refreshes the visible list when the category filter changes.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure cboCategoryChange( Sender: TObject );
    /// <summary>Refreshes the visible list when the priority filter changes.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure cboPriorityChange( Sender: TObject );
  private
    /// <summary>Owned scanner that performs the TODO extraction.</summary>
    FScanner: TTodoScanner;
    /// <summary>True while a project scan is running; used to veto closing the form mid-scan to prevent a use-after-free.</summary>
    FScanning: Boolean;
    /// <summary>Set by Cancel Scan; the running scan stops at the next unit.</summary>
    FCancelRequested: Boolean;
    /// <summary>Cached results from the last scan.</summary>
    FTodoItems: TArray<TTodoItem>;
    /// <summary>Index of the column the list is currently sorted by.</summary>
    FSortColumn: Integer;
    /// <summary>True for ascending sort, False for descending.</summary>
    FSortAscending: Boolean;
    /// <summary>Rebuilds the list view from FTodoItems applying the active filters.</summary>
    procedure PopulateList;
    /// <summary>Scanner progress callback that updates the status label.</summary>
    /// <param name="Sender">The TTodoScanner; its ProgressFileName names the file about to be scanned.</param>
    procedure ScannerProgress( Sender: TObject );
    /// <summary>Opens the source file referenced by the currently selected list row.</summary>
    procedure OpenSelectedFile;
    /// <summary>Returns True when an item satisfies both category and priority filters.</summary>
    /// <param name="Item">TODO item to test.</param>
    /// <returns>True when the item should be displayed.</returns>
    function PassesFilter( const Item: TTodoItem ): Boolean;
  public
    /// <summary>Shows the singleton aggregator form, creating it if necessary.</summary>
    class procedure Execute;
    /// <summary>Frees the singleton form, if open, so it cannot outlive the plugin on unload.</summary>
    class procedure CloseInstance;
  end;

var
  /// <summary>Singleton form instance; nil when the form is closed.</summary>
  FormInstance: TFormTodoAggregator = nil;

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

class procedure TFormTodoAggregator.Execute;
begin

  if FormInstance <> nil then
  begin
    FormInstance.Show;
    FormInstance.BringToFront;
    Exit;
  end;

  FormInstance := TFormTodoAggregator.Create( Application );
  FormInstance.Show;

end;

class procedure TFormTodoAggregator.CloseInstance;
begin

  if ( FormInstance <> nil ) then
    FreeAndNil( FormInstance );

end;

procedure TFormTodoAggregator.FormClose( Sender: TObject; var Action: TCloseAction );
begin

  // ScannerProgress pumps the message queue, so the user can trigger a close
  // mid-scan. Veto it while scanning, otherwise the form and FScanner are freed
  // while ScanProject is still on the stack (use-after-free).
  if FScanning then
  begin
    Action := caNone;
    Exit;
  end;

  FormInstance := nil;
  Action       := caFree;

end;

procedure TFormTodoAggregator.FormCreate( Sender: TObject );
begin

  FScanner       := TTodoScanner.Create;
  FSortColumn    := 0;
  FSortAscending := True;

  // Set up category filter
  cboCategory.Items.Add( '(All)' );
  cboCategory.Items.Add( 'TODO' );
  cboCategory.Items.Add( 'FIXME' );
  cboCategory.Items.Add( 'HACK' );
  cboCategory.Items.Add( 'BUG' );
  cboCategory.Items.Add( 'NOTE' );
  cboCategory.Items.Add( 'XXX' );
  cboCategory.ItemIndex := 0;

  // Set up priority filter
  cboPriority.Items.Add( '(All)' );
  cboPriority.Items.Add( 'High' );
  cboPriority.Items.Add( 'Normal' );
  cboPriority.Items.Add( 'Low' );
  cboPriority.ItemIndex := 0;

  // Load patterns from plugin config
  if TodoAggregatorPlugin <> nil then
    FScanner.SetPatterns( TodoAggregatorPlugin.Patterns );

end;

procedure TFormTodoAggregator.FormDestroy( Sender: TObject );
begin

  FScanner.Free;

end;

procedure TFormTodoAggregator.ScannerProgress( Sender: TObject );
begin

  if Sender is TTodoScanner then
    lblProgress.Caption := 'Scanning: ' + TTodoScanner( Sender ).ProgressFileName;

  Application.ProcessMessages;

  // Stop on Cancel Scan, and when the IDE is closing: the pump above swallowed its WM_QUIT.
  if FCancelRequested or Application.Terminated then
    Abort;

end;

procedure TFormTodoAggregator.btnCancelScanClick( Sender: TObject );
begin

  FCancelRequested := True;

end;

procedure TFormTodoAggregator.btnCloseClick( Sender: TObject );
begin

  Close;

end;

procedure TFormTodoAggregator.btnScanClick( Sender: TObject );
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
  btnScan.Enabled       := False;
  btnScan.Visible       := False;
  btnCancelScan.Visible := True;
  FCancelRequested      := False;
  FScanning             := True;

  try
    lblProgress.Caption := 'Scanning project...';
    lblProgress.Visible := True;
    lblSummary.Visible  := False;
    Application.ProcessMessages;

    // Re-apply patterns here, not just in FormCreate: this is a persistent
    // singleton, so Options edits made while it stays open must take effect.
    if ( TodoAggregatorPlugin <> nil ) then
      FScanner.SetPatterns( TodoAggregatorPlugin.Patterns );
    try
      FTodoItems := ScanProjectTodos( FScanner, Project, ScannerProgress );
    except
      on EAbort do
      begin
        FTodoItems := nil;
        PopulateList;
        lblProgress.Visible := False;
        lblSummary.Caption  := 'Scan cancelled.';
        lblSummary.Visible  := True;
        Exit;
      end;
    end;
    PopulateList;

    lblProgress.Visible := False;
    lblSummary.Caption  := Format( 'Found %d TODO items', [ Length( FTodoItems ) ] );
    lblSummary.Visible  := True;
  finally
    FScanning             := False;
    btnCancelScan.Visible := False;
    btnScan.Visible       := True;
    btnScan.Enabled       := True;
    Screen.Cursor         := crDefault;
  end;

end;

function TFormTodoAggregator.PassesFilter( const Item: TTodoItem ): Boolean;
var
  CategoryFilter, PriorityFilter: string;
begin

  Result := True;

  // Check category filter
  if cboCategory.ItemIndex > 0 then
  begin
    CategoryFilter := cboCategory.Items[ cboCategory.ItemIndex ];

    if not SameText( Item.Category, CategoryFilter ) then
      Result := False;
  end;

  // Check priority filter
  if Result and ( cboPriority.ItemIndex > 0 ) then
  begin
    PriorityFilter := cboPriority.Items[ cboPriority.ItemIndex ];

    if not SameText( Item.Priority, PriorityFilter ) then
      Result := False;
  end;

end;

procedure TFormTodoAggregator.PopulateList;
var
  TodoItem: TTodoItem;
  Item: TListItem;
  Idx: Integer;
begin

  ListView.Items.BeginUpdate;

  try
    ListView.Items.Clear;
    Idx := 0;

    for TodoItem in FTodoItems do
    begin

      if PassesFilter( TodoItem ) then
      begin
        Item         := ListView.Items.Add;
        Item.Caption := TodoItem.UnitName;
        Item.SubItems.Add( TodoItem.Category );
        Item.SubItems.Add( TodoItem.Priority );
        Item.SubItems.Add( IntToStr( TodoItem.Line ) );
        Item.SubItems.Add( TodoItem.Text );
        Item.Data := Pointer( NativeInt( Idx ) );
      end;

      Inc( Idx );
    end;
  finally
    ListView.Items.EndUpdate;
  end;

end;

procedure TFormTodoAggregator.cboCategoryChange( Sender: TObject );
begin

  PopulateList;

end;

procedure TFormTodoAggregator.cboPriorityChange( Sender: TObject );
begin

  PopulateList;

end;

procedure TFormTodoAggregator.ListViewColumnClick( Sender: TObject;
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

/// <summary>Maps a priority string (High/Normal/Low) to a sortable rank; unknown values rank last.</summary>
function PriorityRank( const Priority: string ): Integer;
begin

  if SameText( Priority, 'High' ) then
    Result := 1
  else if SameText( Priority, 'Normal' ) then
    Result := 2
  else if SameText( Priority, 'Low' ) then
    Result := 3
  else
    Result := High( Integer );

end;

procedure TFormTodoAggregator.ListViewCompare( Sender: TObject; Item1,
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

  // Try numeric comparison for line number column
  if FSortColumn = 3 then
    Compare := StrToIntDef( S1, 0 ) - StrToIntDef( S2, 0 )
  else if FSortColumn = 2 then
    // Priority sorting: High > Normal > Low; map to integer ranks and compare
    // numerically so any unexpected priority string sorts deterministically last.
    Compare := PriorityRank( S1 ) - PriorityRank( S2 )
  else
    Compare := CompareText( S1, S2 );

  if not FSortAscending then
    Compare := -Compare;

end;

procedure TFormTodoAggregator.ListViewDblClick( Sender: TObject );
begin

  OpenSelectedFile;

end;

procedure TFormTodoAggregator.OpenSelectedFile;
var
  Idx: Integer;
begin

  if ( ListView.Selected = nil ) then
    Exit;

  Idx := NativeInt( ListView.Selected.Data );

  if ( Idx < 0 ) or ( Idx >= Length( FTodoItems ) ) then
    Exit;

  OpenFileAtLine( FTodoItems[ Idx ].FileName, FTodoItems[ Idx ].Line, FTodoItems[ Idx ].Column );

end;

procedure TFormTodoAggregator.mnuOpenFileClick( Sender: TObject );
begin

  OpenSelectedFile;

end;

procedure TFormTodoAggregator.mnuCopyToClipboardClick( Sender: TObject );
var
  SL: TStringList;
  Item: TListItem;
begin

  SL := TStringList.Create;

  try
    SL.Add( 'Unit'#9'Category'#9'Priority'#9'Line'#9'Text' );

    for Item in ListView.Items do
    begin

      if Item.Selected or ( ListView.SelCount = 0 ) then
        SL.Add( Format( '%s'#9'%s'#9'%s'#9'%s'#9'%s', [
          Item.Caption,
          SafeGetSubItem( Item, 0 ),
          SafeGetSubItem( Item, 1 ),
          SafeGetSubItem( Item, 2 ),
          // A block comment's text can span lines; keep one row per item in the TSV.
          StringReplace( StringReplace( SafeGetSubItem( Item, 3 ), #13#10, ' ', [ rfReplaceAll ] ),
            #9, ' ', [ rfReplaceAll ] )
        ] ) );
    end;

    CopyTextToClipboard( SL.Text );
  finally
    SL.Free;
  end;

end;

procedure TFormTodoAggregator.btnExportClick( Sender: TObject );
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
      SL.Add( 'Unit,Category,Priority,Line,Text' );

      for Item in ListView.Items do
      begin
        SL.Add( Format( '"%s","%s","%s","%s","%s"', [
          StringReplace( Item.Caption, '"', '""', [ rfReplaceAll ] ),
          StringReplace( SafeGetSubItem( Item, 0 ), '"', '""', [ rfReplaceAll ] ),
          StringReplace( SafeGetSubItem( Item, 1 ), '"', '""', [ rfReplaceAll ] ),
          SafeGetSubItem( Item, 2 ),
          StringReplace( SafeGetSubItem( Item, 3 ), '"', '""', [ rfReplaceAll ] )
        ] ) );
      end;

      try
        // UTF-8: a TODO's text is not limited to the ANSI code page.
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
