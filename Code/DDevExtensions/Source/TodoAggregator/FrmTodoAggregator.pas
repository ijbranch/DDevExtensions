{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmTodoAggregator;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Menus, Clipbrd, Generics.Collections,
  Generics.Defaults, FrmBase, TodoAggregator, ToolsAPI;

type
  TFormTodoAggregator = class( TFormBase )
    pnlTop: TPanel;
    pnlBottom: TPanel;
    btnClose: TButton;
    btnScan: TButton;
    ListView: TListView;
    lblProgress: TLabel;
    PopupMenu: TPopupMenu;
    mnuCopyToClipboard: TMenuItem;
    N1: TMenuItem;
    mnuOpenFile: TMenuItem;
    btnExport: TButton;
    SaveDialog: TSaveDialog;
    lblSummary: TLabel;
    cboCategory: TComboBox;
    lblCategory: TLabel;
    cboPriority: TComboBox;
    lblPriority: TLabel;
    procedure btnCloseClick( Sender: TObject );
    procedure btnScanClick( Sender: TObject );
    procedure FormCreate( Sender: TObject );
    procedure FormDestroy( Sender: TObject );
    procedure ListViewDblClick( Sender: TObject );
    procedure mnuCopyToClipboardClick( Sender: TObject );
    procedure mnuOpenFileClick( Sender: TObject );
    procedure btnExportClick( Sender: TObject );
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    procedure cboCategoryChange( Sender: TObject );
    procedure cboPriorityChange( Sender: TObject );
  private
    FScanner: TTodoScanner;
    FTodoItems: TArray<TTodoItem>;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    procedure PopulateList;
    procedure ScannerProgress( Sender: TObject );
    procedure OpenSelectedFile;
    function PassesFilter( const Item: TTodoItem ): Boolean;
  public
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

class function TFormTodoAggregator.Execute: Boolean;
var
  Form: TFormTodoAggregator;
begin

  Form := TFormTodoAggregator.Create( Application );

  try
    Form.ShowModal;
    Result := True;
  finally
    Form.Free;
  end;

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
