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
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Menus, Clipbrd, Generics.Collections,
  Generics.Defaults, FrmBase, TodoAggregator, ToolsAPI;

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
    procedure btnCloseClick( Sender: TObject );
    /// <summary>OnClick handler for the Scan button; runs the project scanner and refreshes the list.</summary>
    procedure btnScanClick( Sender: TObject );
    /// <summary>OnClose handler that releases the singleton instance.</summary>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>OnCreate handler that initialises the scanner and filter combo boxes.</summary>
    procedure FormCreate( Sender: TObject );
    /// <summary>OnDestroy handler that frees the scanner.</summary>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Double-click handler that opens the selected file in the IDE editor.</summary>
    procedure ListViewDblClick( Sender: TObject );
    /// <summary>OnClick handler for the copy-to-clipboard menu item.</summary>
    procedure mnuCopyToClipboardClick( Sender: TObject );
    /// <summary>OnClick handler for the open-file menu item.</summary>
    procedure mnuOpenFileClick( Sender: TObject );
    /// <summary>OnClick handler for the Export button.</summary>
    procedure btnExportClick( Sender: TObject );
    /// <summary>Toggles ascending/descending order on column header clicks.</summary>
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    /// <summary>Custom-sort comparator honouring numeric and priority columns.</summary>
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    /// <summary>Refreshes the visible list when the category filter changes.</summary>
    procedure cboCategoryChange( Sender: TObject );
    /// <summary>Refreshes the visible list when the priority filter changes.</summary>
    procedure cboPriorityChange( Sender: TObject );
  private
    /// <summary>Owned scanner that performs the TODO extraction.</summary>
    FScanner: TTodoScanner;
    FScanning: Boolean;
    /// <summary>Cached results from the last scan.</summary>
    FTodoItems: TArray<TTodoItem>;
    /// <summary>Index of the column the list is currently sorted by.</summary>
    FSortColumn: Integer;
    /// <summary>True for ascending sort, False for descending.</summary>
    FSortAscending: Boolean;
    /// <summary>Rebuilds the list view from FTodoItems applying the active filters.</summary>
    procedure PopulateList;
    /// <summary>Scanner progress callback that updates the status label.</summary>
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
  end;

var
  /// <summary>Singleton form instance; nil when the form is closed.</summary>
  FormInstance: TFormTodoAggregator = nil;

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

  Screen.Cursor    := crHourGlass;
  btnScan.Enabled  := False;
  FScanning        := True;

  try
    lblProgress.Caption := 'Scanning project...';
    lblProgress.Visible := True;
    lblSummary.Visible  := False;
    Application.ProcessMessages;

    FScanner.ScanProject( Project, FTodoItems, ScannerProgress );
    PopulateList;

    lblProgress.Visible := False;
    lblSummary.Caption  := Format( 'Found %d TODO items', [ Length( FTodoItems ) ] );
    lblSummary.Visible  := True;
  finally
    FScanning       := False;
    btnScan.Enabled := True;
    Screen.Cursor   := crDefault;
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
  begin
    // Priority sorting: High > Normal > Low
    if SameText( S1, 'High' ) then S1 := '1'
    else if SameText( S1, 'Normal' ) then S1 := '2'
    else if SameText( S1, 'Low' ) then S1 := '3';

    if SameText( S2, 'High' ) then S2 := '1'
    else if SameText( S2, 'Normal' ) then S2 := '2'
    else if SameText( S2, 'Low' ) then S2 := '3';

    Compare := CompareText( S1, S2 );
  end
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
  TodoItem: TTodoItem;
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  I: Integer;
begin

  if ListView.Selected = nil then
    Exit;

  Idx := NativeInt( ListView.Selected.Data );

  if ( Idx < 0 ) or ( Idx >= Length( FTodoItems ) ) then
    Exit;

  TodoItem := FTodoItems[ Idx ];

  if Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
  begin
    Module := ModuleServices.OpenModule( TodoItem.FileName );

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
            EditView.SetTopLeft( TodoItem.Line, 1 );
            EditView.Center( TodoItem.Line, TodoItem.Column );
          end;

          Break;
        end;
      end;
    end;
  end;

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
          SafeGetSubItem( Item, 3 )
        ] ) );
    end;

    Clipboard.AsText := SL.Text;
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
          Item.Caption,
          SafeGetSubItem( Item, 0 ),
          SafeGetSubItem( Item, 1 ),
          SafeGetSubItem( Item, 2 ),
          StringReplace( SafeGetSubItem( Item, 3 ), '"', '""', [ rfReplaceAll ] )
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
