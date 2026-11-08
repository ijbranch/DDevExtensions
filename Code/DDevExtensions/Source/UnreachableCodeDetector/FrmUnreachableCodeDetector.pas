{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2025 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmUnreachableCodeDetector;

/// <summary>
/// Non-modal main form of the Unreachable Code Detector plugin. Scans the active
/// project, lists every detected unreachable code block, and supports filtering by
/// terminator type, sorting, opening the source location and CSV export.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Menus, System.Generics.Collections,
  FrmBase, UnreachableCodeDetector, UnreachableCodeCore, ToolsAPI, Vcl.Buttons;

type
  /// <summary>Main detector form for the Unreachable Code Detector plugin.</summary>
  TFormUnreachableCodeDetector = class( TFormBase )
    /// <summary>Top toolbar panel.</summary>
    pnlTop: TPanel;
    /// <summary>Bottom grid panel hosting buttons and labels.</summary>
    pnlBottom: TGridPanel;
    /// <summary>Closes the form.</summary>
    btnClose: TBitBtn;
    /// <summary>Scans the active project and populates the list.</summary>
    btnScan: TBitBtn;
    /// <summary>Lists detected unreachable code blocks (filtered by <see cref="cmbFilter"/>).</summary>
    ListView: TListView;
    /// <summary>Progress / status label.</summary>
    lblProgress: TLabel;
    /// <summary>Filter combo restricting the visible items by terminator reason.</summary>
    cmbFilter: TComboBox;
    /// <summary>Label for the filter combo.</summary>
    lblFilter: TLabel;
    /// <summary>Exports all detected items to a CSV file.</summary>
    btnExport: TBitBtn;
    /// <summary>Shows "Showing X of Y items".</summary>
    lblCount: TLabel;
    /// <summary>Shows the project name being analysed.</summary>
    lblProject: TLabel;
    /// <summary>Closes the form.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure btnCloseClick( Sender: TObject );
    /// <summary>Runs the scanner against the active project; while a scan runs, the button reads Cancel and stops it.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure btnScanClick( Sender: TObject );
    /// <summary>Form OnCreate handler: creates the scanner, fills the filter items and remembers the Scan caption.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure FormCreate( Sender: TObject );
    /// <summary>Frees the form and releases the singleton on close; vetoes the close while a scan is running.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    /// <param name="Action">Set to caNone to veto the close while a scan runs; otherwise caFree, so the form is freed.</param>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>Form OnDestroy handler: releases the singleton if it is this form, and frees the scanner.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Opens the source file at the offending line when a row is double-clicked.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ListViewDblClick( Sender: TObject );
    /// <summary>Re-applies the filter when the combo selection changes.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure cmbFilterChange( Sender: TObject );
    /// <summary>Exports all detected items to a CSV file.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure btnExportClick( Sender: TObject );
    /// <summary>Custom-column comparer used by AlphaSort.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    /// <param name="Item1">The first list item being compared.</param>
    /// <param name="Item2">The second list item being compared.</param>
    /// <param name="Data">Sort data passed by AlphaSort (unused).</param>
    /// <param name="Compare">Receives a negative, zero or positive value as Item1 sorts before, level with or after Item2.</param>
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    /// <summary>Toggles or switches the active sort column.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    /// <param name="Column">The column whose header was clicked.</param>
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
  private
    /// <summary>Owned scanner used to perform the analysis.</summary>
    FScanner: TUnreachableCodeScanner;
    /// <summary>True while a project scan is running; used to veto closing the form mid-scan to prevent a use-after-free.</summary>
    FScanning: Boolean;
    /// <summary>Set by the Scan button (which reads "Cancel" during a scan) or by <see cref="CloseInstance"/> to stop the running scan.</summary>
    FCancelRequested: Boolean;
    /// <summary>Caption of the Scan button, restored when a scan ends.</summary>
    FScanCaption: string;
    /// <summary>Most recent scan result.</summary>
    FItems: TArray<TUnreachableCodeItem>;
    /// <summary>Index of the currently active sort column.</summary>
    FSortColumn: Integer;
    /// <summary>Sort direction flag.</summary>
    FSortAscending: Boolean;
    /// <summary>Refreshes the list view from <see cref="FItems"/>, applying the current filter.</summary>
    procedure PopulateList;
    /// <summary>Scan progress callback: updates the progress label, pumps messages and reports a requested cancel.</summary>
    /// <param name="Step">Text describing the current step.</param>
    /// <param name="Cancel">Set to True when the user cancelled the scan.</param>
    procedure ScannerProgress( const Step: string; var Cancel: Boolean );
    /// <summary>Opens the source file for the supplied item and centres the view on its line.</summary>
    /// <param name="Item">The item whose source line is shown.</param>
    procedure OpenItem( const Item: TUnreachableCodeItem );
  public
    /// <summary>Shows or focuses the singleton (non-modal) detector form.</summary>
    /// <returns>Always True.</returns>
    class function Execute: Boolean;
    /// <summary>
    /// Frees the singleton form, if open, so it cannot outlive the plugin on unload.
    /// It covers an unload outside a scan.  An unload reached through a running scan's own message
    /// pump cannot be made safe here: the scan is cancelled and the form hidden, and the form is
    /// released when the scan unwinds - safe only while the plug-in's code is still loaded.
    /// </summary>
    class procedure CloseInstance;
  end;

implementation

{$R *.dfm}

uses
  ToolsAPIHelpers, Vcl.Clipbrd, ProjectSources;

var
  /// <summary>Singleton detector form instance (nil when the form is not open).</summary>
  FormInstance: TFormUnreachableCodeDetector = nil;

class function TFormUnreachableCodeDetector.Execute: Boolean;
begin

  // One form only: each extra instance would be one more window to leave behind on unload.
  if FormInstance = nil then
    FormInstance := TFormUnreachableCodeDetector.Create( Application );

  FormInstance.Show;  // Non-modal - allows working in Delphi while open
  FormInstance.BringToFront;
  Result := True;

end;

class procedure TFormUnreachableCodeDetector.CloseInstance;
begin
  if FormInstance = nil then
    Exit;

  var oForm := FormInstance;
  FormInstance := nil;

  if oForm.FScanning then
  begin
    // The scan is still on the stack (this call arrived through its message pump): freeing the
    // form now would free FScanner under it.  Stop the scan and let btnScanClick release the form.  That
    // is safe only if the plug-in's code is still loaded when the scan unwinds; an unload cannot be
    // refused or postponed from here.
    oForm.FCancelRequested := True;
    oForm.Hide;
  end
  else
    oForm.Free;
end;

procedure TFormUnreachableCodeDetector.FormCreate( Sender: TObject );
begin

  FScanner            := TUnreachableCodeScanner.Create;
  FSortColumn         := 0;
  FSortAscending      := True;
  FScanCaption        := btnScan.Caption;

  cmbFilter.Items.Add( 'All' );
  cmbFilter.Items.Add( 'After Exit' );
  cmbFilter.Items.Add( 'After Raise' );
  cmbFilter.Items.Add( 'After Break' );
  cmbFilter.Items.Add( 'After Continue' );
  cmbFilter.Items.Add( 'After Halt' );
  cmbFilter.Items.Add( 'After Abort' );
  cmbFilter.ItemIndex := 0;

end;

procedure TFormUnreachableCodeDetector.FormClose( Sender: TObject; var Action: TCloseAction );
begin

  // ScannerProgress pumps the message queue, so the user can close the form
  // mid-scan. Veto it while scanning, otherwise the form and FScanner are freed
  // while ScanProject is still on the stack (use-after-free).
  if FScanning then
  begin
    Action := caNone;
    Exit;
  end;

  if FormInstance = Self then
    FormInstance := nil;
  Action := caFree;  // Free the form when closed (non-modal)

end;

procedure TFormUnreachableCodeDetector.FormDestroy( Sender: TObject );
begin

  if FormInstance = Self then
    FormInstance := nil;
  FScanner.Free;

end;

procedure TFormUnreachableCodeDetector.ScannerProgress( const Step: string; var Cancel: Boolean );
begin
  lblProgress.Caption := Step;
  Application.ProcessMessages;
  Cancel := FCancelRequested;
end;

procedure TFormUnreachableCodeDetector.btnCloseClick( Sender: TObject );
begin

  Close;

end;

procedure TFormUnreachableCodeDetector.btnScanClick( Sender: TObject );
begin

  // During a scan the button reads "Cancel".
  if FScanning then
  begin
    FCancelRequested := True;
    Exit;
  end;

  var oProject := GetActiveProject;

  if oProject = nil then
  begin
    ShowMessage( 'No active project.' );
    Exit;
  end;

  lblProject.Caption := 'Project: ' + ChangeFileExt( ExtractFileName( oProject.FileName ), '' );

  Screen.Cursor    := crHourGlass;
  FScanning        := True;
  FCancelRequested := False;
  btnScan.Caption  := '&Cancel';

  try
    lblProgress.Caption := 'Scanning project...';
    lblProgress.Visible := True;
    Application.ProcessMessages;

    var iSkipped: Integer;
    var bCompleted := ScanProject( FScanner, oProject, ScannerProgress, iSkipped );
    FItems := FScanner.GetItems;

    PopulateList;

    if not bCompleted then
      lblProgress.Caption := 'Scan cancelled.'
    else if iSkipped > 0 then
      lblProgress.Caption := Format( 'Scan complete. Found %d unreachable code blocks (%d unreadable units skipped).',
        [ Length( FItems ), iSkipped ] )
    else
      lblProgress.Caption := Format( 'Scan complete. Found %d unreachable code blocks.', [ Length( FItems ) ] );
  finally
    FScanning       := False;
    btnScan.Caption := FScanCaption;
    Screen.Cursor   := crDefault;
  end;

  // CloseInstance arrived during the scan: the form is no longer the singleton and must go.
  if FormInstance <> Self then
    Release;

end;

procedure TFormUnreachableCodeDetector.PopulateList;
var
  Item: TUnreachableCodeItem;
  ListItem: TListItem;
  FilterIdx: Integer;
  VisibleCount: Integer;
  OrigIdx: Integer;
begin

  ListView.Items.BeginUpdate;

  try
    ListView.Items.Clear;
    FilterIdx    := cmbFilter.ItemIndex;
    VisibleCount := 0;

    for OrigIdx := 0 to High( FItems ) do
    begin
      Item := FItems[ OrigIdx ];
      // Apply filter
      if FilterIdx > 0 then
      begin

        if Ord( Item.Reason ) <> ( FilterIdx - 1 ) then
          Continue;
      end;

      ListItem         := ListView.Items.Add;
      ListItem.Caption := Item.UnitName;
      ListItem.SubItems.Add( IntToStr( Item.Line ) );
      ListItem.SubItems.Add( Item.ReasonText );
      ListItem.SubItems.Add( Item.CodePreview );
      // Store the original FItems index so double-click resolves the correct
      // item regardless of column sorting (ListViewColumnClick calls AlphaSort,
      // which reorders the visual rows).
      ListItem.Data := Pointer( NativeInt( OrigIdx ) );

      Inc( VisibleCount );
    end;

    lblCount.Caption := Format( 'Showing %d of %d items', [ VisibleCount, Length( FItems ) ] );
  finally
    ListView.Items.EndUpdate;
  end;

end;

procedure TFormUnreachableCodeDetector.cmbFilterChange( Sender: TObject );
begin

  PopulateList;

end;

procedure TFormUnreachableCodeDetector.ListViewDblClick( Sender: TObject );
var
  OrigIdx: NativeInt;
begin

  if ListView.Selected = nil then
    Exit;

  // PopulateList stores the original FItems index in the item's Data. Resolve
  // through it rather than the visual row position, which no longer matches the
  // scan order once the user has sorted a column (AlphaSort).
  OrigIdx := NativeInt( ListView.Selected.Data );

  if ( OrigIdx >= 0 ) and ( OrigIdx <= High( FItems ) ) then
    OpenItem( FItems[ OrigIdx ] );

end;

procedure TFormUnreachableCodeDetector.OpenItem( const Item: TUnreachableCodeItem );
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  I: Integer;
begin

  if not FileExists( Item.FileName ) then
  begin
    ShowMessage( 'Source file not found: ' + Item.FileName );
    Exit;
  end;

  if Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
  begin
    try
      Module := ModuleServices.OpenModule( Item.FileName );
    except
      on E: Exception do
      begin
        ShowMessage( Format( 'Could not open %s'#13#10'%s', [ Item.FileName, E.Message ] ) );
        Exit;
      end;
    end;

    if Module = nil then
    begin
      ShowMessage( 'Could not open ' + Item.FileName );
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

          if EditView <> nil then
          begin
            EditView.Position.GotoLine( Item.Line );
            EditView.Center( Item.Line, 1 );
          end;
        end;

        Break;
      end;
    end;

    if SourceEditor = nil then
      ShowMessage( 'No source editor available for ' + ExtractFileName( Item.FileName ) );
  end;

end;

procedure TFormUnreachableCodeDetector.btnExportClick( Sender: TObject );
var
  SL: TStringList;
  I: Integer;
  Item: TUnreachableCodeItem;
  SaveDlg: TSaveDialog;
begin

  if Length( FItems ) = 0 then
  begin
    ShowMessage( 'No items to export.' );
    Exit;
  end;

  SaveDlg := TSaveDialog.Create( nil );

  try
    SaveDlg.Filter     := 'CSV Files (*.csv)|*.csv|All Files (*.*)|*.*';
    SaveDlg.DefaultExt := 'csv';
    SaveDlg.FileName   := 'UnreachableCode.csv';

    if SaveDlg.Execute then
    begin
      SL := TStringList.Create;

      try
        SL.Add( 'Unit,Line,Reason,Code Preview,File Path' );

        for I := 0 to High( FItems ) do
        begin
          Item := FItems[ I ];
          SL.Add( Format( '"%s",%d,"%s","%s","%s"',
            [ Item.UnitName, Item.Line, Item.ReasonText,
              StringReplace( Item.CodePreview, '"', '""', [ rfReplaceAll ] ),
              Item.FileName ] ) );
        end;

        try
          SL.SaveToFile( SaveDlg.FileName );
          ShowMessage( Format( 'Exported %d items to %s', [ Length( FItems ), SaveDlg.FileName ] ) );
        except
          on E: Exception do
            ShowMessage( 'Could not write file: ' + E.Message );
        end;
      finally
        SL.Free;
      end;
    end;
  finally
    SaveDlg.Free;
  end;

end;

procedure TFormUnreachableCodeDetector.ListViewColumnClick( Sender: TObject;
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

procedure TFormUnreachableCodeDetector.ListViewCompare( Sender: TObject;
  Item1, Item2: TListItem; Data: Integer; var Compare: Integer );
var
  S1, S2: string;
  N1, N2: Integer;
begin

  case FSortColumn of
    0: // Unit
      begin
        S1      := Item1.Caption;
        S2      := Item2.Caption;
        Compare := CompareText( S1, S2 );
      end;
    1: // Line
      begin
        N1      := StrToIntDef( Item1.SubItems[ 0 ], 0 );
        N2      := StrToIntDef( Item2.SubItems[ 0 ], 0 );
        Compare := N1 - N2;
      end;
    2: // Reason
      begin
        S1      := Item1.SubItems[ 1 ];
        S2      := Item2.SubItems[ 1 ];
        Compare := CompareText( S1, S2 );
      end;
    3: // Code Preview
      begin
        S1      := Item1.SubItems[ 2 ];
        S2      := Item2.SubItems[ 2 ];
        Compare := CompareText( S1, S2 );
      end;
  else
    Compare := 0;
  end;

  if not FSortAscending then
    Compare := -Compare;

end;

end.
