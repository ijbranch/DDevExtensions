{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmDeadCodeDetector;

/// <summary>
/// Non-modal main form of the Dead Code Detector plugin. Runs the analyser against
/// the active project and lists symbols that appear to be unreferenced, with type
/// and scope filters, sortable columns, source navigation, clipboard copy and
/// CSV export.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Clipbrd, System.Generics.Collections,
  System.Generics.Defaults, FrmBase, DeadCodeDetector, ToolsAPI;

type
  /// <summary>Main detector form for the Dead Code Detector plugin.</summary>
  TFormDeadCodeDetector = class( TFormBase )
    /// <summary>Top toolbar panel.</summary>
    pnlTop: TPanel;
    /// <summary>Bottom grid panel hosting buttons and labels.</summary>
    pnlBottom: TGridPanel;
    /// <summary>Closes the form.</summary>
    btnClose: TButton;
    /// <summary>Scans the active project and populates the list.</summary>
    btnScan: TButton;
    /// <summary>Lists detected dead-code items, filtered by <see cref="cboType"/> and <see cref="cboScope"/>.</summary>
    ListView: TListView;
    /// <summary>Progress / status label.</summary>
    lblProgress: TLabel;
    /// <summary>Context menu for the list view.</summary>
    PopupMenu: TPopupMenu;
    /// <summary>Menu item: copy selected (or all) rows to the clipboard as TSV.</summary>
    mnuCopyToClipboard: TMenuItem;
    /// <summary>Separator menu item.</summary>
    N1: TMenuItem;
    /// <summary>Menu item: open the source file at the declaration line.</summary>
    mnuOpenFile: TMenuItem;
    /// <summary>Exports the result list to a CSV file.</summary>
    btnExport: TButton;
    /// <summary>Save dialog used by the export button.</summary>
    SaveDialog: TSaveDialog;
    /// <summary>Summary line shown after a scan completes.</summary>
    lblSummary: TLabel;
    /// <summary>Filter combo restricting visible items by element type.</summary>
    cboType: TComboBox;
    /// <summary>Label for <see cref="cboType"/>.</summary>
    lblType: TLabel;
    /// <summary>Filter combo restricting visible items by scope.</summary>
    cboScope: TComboBox;
    /// <summary>Label for <see cref="cboScope"/>.</summary>
    lblScope: TLabel;
    /// <summary>Menu item: add the selected symbol's name to the persistent ignore list.</summary>
    mnuAddToIgnoreList: TMenuItem;
    /// <summary>Closes the form.</summary>
    procedure btnCloseClick( Sender: TObject );
    /// <summary>Runs the analyser against the active project.</summary>
    procedure btnScanClick( Sender: TObject );
    /// <summary>Releases the singleton form instance and frees the form on close.</summary>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>Form OnCreate handler: initialises analyser, sort state and filter combos.</summary>
    procedure FormCreate( Sender: TObject );
    /// <summary>Form OnDestroy handler: frees the analyser.</summary>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Opens the source file at the declaration line when a row is double-clicked.</summary>
    procedure ListViewDblClick( Sender: TObject );
    /// <summary>Copies selected (or all) rows to the clipboard as TSV.</summary>
    procedure mnuCopyToClipboardClick( Sender: TObject );
    /// <summary>Opens the source file at the declaration line.</summary>
    procedure mnuOpenFileClick( Sender: TObject );
    /// <summary>Exports the result list to a CSV file.</summary>
    procedure btnExportClick( Sender: TObject );
    /// <summary>Toggles or switches the active sort column.</summary>
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    /// <summary>Custom-column comparer used by AlphaSort.</summary>
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    /// <summary>Re-applies the type filter when the combo selection changes.</summary>
    procedure cboTypeChange( Sender: TObject );
    /// <summary>Re-applies the scope filter when the combo selection changes.</summary>
    procedure cboScopeChange( Sender: TObject );
    /// <summary>Adds the selected symbol's bare name to the persistent ignore list.</summary>
    procedure mnuAddToIgnoreListClick( Sender: TObject );
  private
    /// <summary>Owned analyser used to perform the analysis.</summary>
    FAnalyzer: TDeadCodeAnalyzer;
    /// <summary>True while a project scan is running; used to veto closing the form mid-scan to prevent a use-after-free.</summary>
    FScanning: Boolean;
    /// <summary>Most recent analysis result.</summary>
    FDeadCode: TArray<TDeadCodeItem>;
    /// <summary>Index of the currently active sort column.</summary>
    FSortColumn: Integer;
    /// <summary>Sort direction flag.</summary>
    FSortAscending: Boolean;
    /// <summary>Refreshes the list view from <see cref="FDeadCode"/>, applying the current filters.</summary>
    procedure PopulateList;
    /// <summary>Analyser OnProgress callback that updates the progress label.</summary>
    procedure AnalyzerProgress( Sender: TObject );
    /// <summary>Opens the source file for the selected row at its declaration line.</summary>
    procedure OpenSelectedFile;
    /// <summary>Returns True when the supplied item passes both the type and scope filters.</summary>
    function PassesFilter( const Item: TDeadCodeItem ): Boolean;
  public
    /// <summary>Shows or focuses the singleton detector form.</summary>
    class procedure Execute;
  end;

var
  /// <summary>Singleton detector form instance (nil when the form is not open).</summary>
  FormInstance: TFormDeadCodeDetector = nil;

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

class procedure TFormDeadCodeDetector.Execute;
begin

  if FormInstance <> nil then
  begin
    FormInstance.Show;
    FormInstance.BringToFront;
    Exit;
  end;

  FormInstance := TFormDeadCodeDetector.Create( Application );
  FormInstance.Show;

end;

procedure TFormDeadCodeDetector.FormClose( Sender: TObject; var Action: TCloseAction );
begin

  // AnalyzerProgress pumps the message queue, so the user can trigger a close
  // mid-scan. Veto it while scanning, otherwise the form and FAnalyzer are freed
  // while AnalyzeProject is still on the stack (use-after-free).
  if FScanning then
  begin
    Action := caNone;
    Exit;
  end;

  FormInstance := nil;
  Action       := caFree;

end;

procedure TFormDeadCodeDetector.FormCreate( Sender: TObject );
var
  I: Integer;
begin

  FAnalyzer      := TDeadCodeAnalyzer.Create;
  FSortColumn    := 0;
  FSortAscending := True;

  // Load ignore patterns from plugin
  if DeadCodeDetectorPlugin <> nil then
  begin
    for I := 0 to DeadCodeDetectorPlugin.IgnoreList.Count - 1 do
      FAnalyzer.AddIgnorePattern( DeadCodeDetectorPlugin.IgnoreList[ I ] );
  end;

  // Set up type filter
  cboType.Items.Add( '(All)' );
  cboType.Items.Add( 'Procedure' );
  cboType.Items.Add( 'Function' );
  cboType.Items.Add( 'Field' );
  cboType.ItemIndex := 0;

  // Set up scope filter
  cboScope.Items.Add( '(All)' );
  cboScope.Items.Add( 'private' );
  cboScope.Items.Add( 'protected' );
  cboScope.Items.Add( 'public' );
  cboScope.Items.Add( 'unit' );
  cboScope.ItemIndex := 0;

end;

procedure TFormDeadCodeDetector.FormDestroy( Sender: TObject );
begin

  FAnalyzer.Free;

end;

procedure TFormDeadCodeDetector.AnalyzerProgress( Sender: TObject );
begin

  if Sender is TDeadCodeAnalyzer then
    lblProgress.Caption := TDeadCodeAnalyzer( Sender ).ProgressFileName;

  Application.ProcessMessages;

end;

procedure TFormDeadCodeDetector.btnCloseClick( Sender: TObject );
begin

  Close;

end;

procedure TFormDeadCodeDetector.btnScanClick( Sender: TObject );
var
  Project: IOTAProject;
begin

  Project := GetActiveProject;

  if Project = nil then
  begin
    ShowMessage( 'No active project.' );
    Exit;
  end;

  Screen.Cursor     := crHourGlass;
  btnScan.Enabled   := False;
  FScanning         := True;
  ListView.Selected := nil;   // drop any stale selection before re-scan

  try
    lblProgress.Caption := 'Analysing project...';
    lblProgress.Visible := True;
    lblSummary.Visible  := False;
    Application.ProcessMessages;

    FAnalyzer.AnalyzeProject( Project, FDeadCode, AnalyzerProgress );
    PopulateList;

    lblProgress.Visible := False;
    lblSummary.Caption  := Format( 'Found %d potentially dead code items', [ Length( FDeadCode ) ] );
    lblSummary.Visible  := True;
  finally
    FScanning       := False;
    btnScan.Enabled := True;
    Screen.Cursor   := crDefault;
  end;

end;

function TFormDeadCodeDetector.PassesFilter( const Item: TDeadCodeItem ): Boolean;
var
  TypeFilter, ScopeFilter: string;
begin

  Result := True;

  // Check type filter
  if cboType.ItemIndex > 0 then
  begin
    TypeFilter := cboType.Items[ cboType.ItemIndex ];

    if not SameText( Item.ElementType, TypeFilter ) then
      Result := False;
  end;

  // Check scope filter
  if Result and ( cboScope.ItemIndex > 0 ) then
  begin
    ScopeFilter := cboScope.Items[ cboScope.ItemIndex ];

    if not SameText( Item.Scope, ScopeFilter ) then
      Result := False;
  end;

end;

procedure TFormDeadCodeDetector.PopulateList;
var
  DeadItem: TDeadCodeItem;
  Item: TListItem;
  Idx: Integer;
begin

  ListView.Items.BeginUpdate;

  try
    ListView.Items.Clear;
    Idx := 0;

    for DeadItem in FDeadCode do
    begin

      if PassesFilter( DeadItem ) then
      begin
        Item         := ListView.Items.Add;
        Item.Caption := DeadItem.UnitName;
        Item.SubItems.Add( DeadItem.ElementType );
        Item.SubItems.Add( DeadItem.ElementName );
        Item.SubItems.Add( DeadItem.Scope );
        Item.SubItems.Add( IntToStr( DeadItem.Line ) );
        Item.SubItems.Add( DeadItem.Reason );
        Item.Data := Pointer( NativeInt( Idx ) );
      end;

      Inc( Idx );
    end;
  finally
    ListView.Items.EndUpdate;
  end;

end;

procedure TFormDeadCodeDetector.cboTypeChange( Sender: TObject );
begin

  PopulateList;

end;

procedure TFormDeadCodeDetector.cboScopeChange( Sender: TObject );
begin

  PopulateList;

end;

procedure TFormDeadCodeDetector.ListViewColumnClick( Sender: TObject;
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

procedure TFormDeadCodeDetector.ListViewCompare( Sender: TObject; Item1,
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
  if FSortColumn = 4 then
    Compare := StrToIntDef( S1, 0 ) - StrToIntDef( S2, 0 )
  else
    Compare := CompareText( S1, S2 );

  if not FSortAscending then
    Compare := -Compare;

end;

procedure TFormDeadCodeDetector.ListViewDblClick( Sender: TObject );
begin

  OpenSelectedFile;

end;

procedure TFormDeadCodeDetector.OpenSelectedFile;
var
  Idx: Integer;
  DeadItem: TDeadCodeItem;
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  I: Integer;
begin

  if ListView.Selected = nil then
    Exit;

  Idx := NativeInt( ListView.Selected.Data );

  if ( Idx < 0 ) or ( Idx >= Length( FDeadCode ) ) then
    Exit;

  DeadItem := FDeadCode[ Idx ];

  if not FileExists( DeadItem.FileName ) then
  begin
    ShowMessage( 'Source file not found: ' + DeadItem.FileName );
    Exit;
  end;

  if Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
  begin
    try
      Module := ModuleServices.OpenModule( DeadItem.FileName );
    except
      on E: Exception do
      begin
        ShowMessage( Format( 'Could not open %s'#13#10'%s', [ DeadItem.FileName, E.Message ] ) );
        Exit;
      end;
    end;

    if Module = nil then
    begin
      ShowMessage( 'Could not open ' + DeadItem.FileName );
      Exit;
    end;

    SourceEditor := nil;

    for I := 0 to Module.ModuleFileCount - 1 do
    begin

      if Supports( Module.ModuleFileEditors[ I ], IOTASourceEditor, SourceEditor ) then
      begin
        SourceEditor.Show;

        if SourceEditor.EditViewCount > 0 then
        begin
          EditView := SourceEditor.EditViews[ 0 ];
          EditView.SetTopLeft( DeadItem.Line, 1 );
          EditView.Center( DeadItem.Line, 1 );
        end;

        Break;
      end;
    end;

    if SourceEditor = nil then
      ShowMessage( 'No source editor available for ' + ExtractFileName( DeadItem.FileName ) );
  end;

end;

procedure TFormDeadCodeDetector.mnuOpenFileClick( Sender: TObject );
begin

  OpenSelectedFile;

end;

procedure TFormDeadCodeDetector.mnuAddToIgnoreListClick( Sender: TObject );
var
  Idx: Integer;
  DeadItem: TDeadCodeItem;
  NameToIgnore: string;
begin

  if ListView.Selected = nil then
    Exit;

  Idx := NativeInt( ListView.Selected.Data );

  if ( Idx < 0 ) or ( Idx >= Length( FDeadCode ) ) then
    Exit;

  DeadItem := FDeadCode[ Idx ];

  // Extract just the method/field name (without class prefix)
  NameToIgnore := DeadItem.ElementName;

  if Pos( '.', NameToIgnore ) > 0 then
    NameToIgnore := Copy( NameToIgnore, Pos( '.', NameToIgnore ) + 1, MaxInt );

  if DeadCodeDetectorPlugin <> nil then
  begin
    DeadCodeDetectorPlugin.IgnoreList.Add( NameToIgnore );
    DeadCodeDetectorPlugin.Save;
    ShowMessage( Format( '"%s" added to ignore list. Re-scan to update results.', [ NameToIgnore ] ) );
  end;

end;

procedure TFormDeadCodeDetector.mnuCopyToClipboardClick( Sender: TObject );
var
  SL: TStringList;
  Item: TListItem;
begin

  SL := TStringList.Create;

  try
    SL.Add( 'Unit'#9'Type'#9'Name'#9'Scope'#9'Line'#9'Reason' );

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

procedure TFormDeadCodeDetector.btnExportClick( Sender: TObject );
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
      SL.Add( 'Unit,Type,Name,Scope,Line,Reason' );

      for Item in ListView.Items do
      begin
        SL.Add( Format( '"%s","%s","%s","%s","%s","%s"', [
          Item.Caption,
          SafeGetSubItem( Item, 0 ),
          SafeGetSubItem( Item, 1 ),
          SafeGetSubItem( Item, 2 ),
          SafeGetSubItem( Item, 3 ),
          SafeGetSubItem( Item, 4 )
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
