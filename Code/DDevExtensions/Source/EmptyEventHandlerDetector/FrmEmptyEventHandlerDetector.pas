{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit FrmEmptyEventHandlerDetector;

/// <summary>
/// Singleton results form for the Empty Event Handler Detector. Initiates project-wide scans and
/// presents the empty handlers in a sortable list view with copy-to-clipboard, CSV export, and
/// double-click navigation to the offending source line.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Clipbrd, System.Generics.Collections,
  FrmBase, EmptyEventHandlerDetector, ToolsAPI, Vcl.Buttons;

type
  /// <summary>Singleton results form for the Empty Event Handler Detector.</summary>
  TFormEmptyEventHandlerDetector = class( TFormBase )
    /// <summary>Top toolbar panel.</summary>
    pnlTop: TPanel;
    /// <summary>Bottom action-button panel.</summary>
    pnlBottom: TGridPanel;
    /// <summary>Closes the form.</summary>
    btnClose: TBitBtn;
    /// <summary>Initiates a project-wide scan.</summary>
    btnScan: TBitBtn;
    /// <summary>List view displaying the empty handlers.</summary>
    ListView: TListView;
    /// <summary>Status text shown while scanning.</summary>
    lblProgress: TLabel;
    /// <summary>Context menu attached to the list view.</summary>
    PopupMenu: TPopupMenu;
    /// <summary>Copies the selected (or all) results to the clipboard as TSV.</summary>
    mnuCopyToClipboard: TMenuItem;
    /// <summary>Separator menu item.</summary>
    N1: TMenuItem;
    /// <summary>Opens the source file at the selected handler's line.</summary>
    mnuOpenFile: TMenuItem;
    /// <summary>Exports the visible results to CSV.</summary>
    btnExport: TBitBtn;
    /// <summary>File-save dialog used by <see cref="btnExport"/>.</summary>
    SaveDialog: TSaveDialog;
    /// <summary>Result summary text.</summary>
    lblSummary: TLabel;
    /// <summary>Closes the form.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure btnCloseClick( Sender: TObject );
    /// <summary>Scans the active project for empty event handlers; while a scan runs, the button reads Cancel and stops it.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure btnScanClick( Sender: TObject );
    /// <summary>Sets the initial sort state and remembers the Scan caption.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure FormCreate( Sender: TObject );
    /// <summary>Frees the form and releases the singleton on close; vetoes the close while a scan is running.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    /// <param name="Action">Set to caNone to veto the close while a scan runs; otherwise caFree, so the form is freed.</param>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>Clears the singleton reference when the form is destroyed.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Opens the file referenced by the double-clicked row.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ListViewDblClick( Sender: TObject );
    /// <summary>Context-menu handler that copies result data to the clipboard.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure mnuCopyToClipboardClick( Sender: TObject );
    /// <summary>Context-menu handler that opens the source file at the handler's line.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure mnuOpenFileClick( Sender: TObject );
    /// <summary>Exports the visible results to a CSV file.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure btnExportClick( Sender: TObject );
    /// <summary>Cycles sort direction when a column header is clicked.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    /// <param name="Column">The column whose header was clicked.</param>
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    /// <summary>Custom comparator supporting numeric sort on the line-number column.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    /// <param name="Item1">The first list item being compared.</param>
    /// <param name="Item2">The second list item being compared.</param>
    /// <param name="Data">Sort data passed by AlphaSort (unused).</param>
    /// <param name="Compare">Receives a negative, zero or positive value as Item1 sorts before, level with or after Item2.</param>
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
  private
    /// <summary>True while a project scan is running; used to veto closing the form mid-scan to prevent a use-after-free.</summary>
    FScanning: Boolean;
    /// <summary>Set by the Scan button (which reads "Cancel" during a scan) or by <see cref="CloseInstance"/> to stop the running scan.</summary>
    FCancelRequested: Boolean;
    /// <summary>Caption of the Scan button, restored when a scan ends.</summary>
    FScanCaption: string;
    /// <summary>Latest scan results.</summary>
    FResults: TArray<TEmptyHandlerInfo>;
    /// <summary>Index of the column currently being sorted.</summary>
    FSortColumn: Integer;
    /// <summary>Sort direction flag.</summary>
    FSortAscending: Boolean;
    /// <summary>Rebuilds the list view from <see cref="FResults"/>.</summary>
    procedure PopulateList;
    /// <summary>Opens the file/line of the currently selected list item in the IDE.</summary>
    procedure OpenSelectedFile;
    /// <summary>Scan progress callback: updates the progress label, pumps messages and reports a requested cancel.</summary>
    /// <param name="Step">Text describing the current step.</param>
    /// <param name="Cancel">Set to True when the user cancelled the scan.</param>
    procedure ScanProgress( const Step: string; var Cancel: Boolean );
  public
    /// <summary>Displays the singleton form, creating it if required.</summary>
    /// <returns><c>True</c> when the form was shown.</returns>
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
  ToolsAPIHelpers, ProjectSources;

function SafeGetSubItem( Item: TListItem; Index: Integer ): string;
begin
  if ( Item <> nil ) and ( Index < Item.SubItems.Count ) then
    Result          := Item.SubItems[ Index ]
  else
    Result          := '';
end;

/// <summary>Escapes a value for an RFC 4180 quoted CSV field by doubling any embedded double-quotes.</summary>
function CsvField( const Value: string ): string;
begin
  Result            := System.SysUtils.StringReplace( Value, '"', '""', [ rfReplaceAll ] );
end;

var
  FormEmptyEventHandlerDetectorInstance: TFormEmptyEventHandlerDetector = nil;

class function TFormEmptyEventHandlerDetector.Execute: Boolean;
begin
  // Use singleton pattern - create once, reuse on subsequent calls
  if FormEmptyEventHandlerDetectorInstance = nil then
    FormEmptyEventHandlerDetectorInstance := TFormEmptyEventHandlerDetector.Create( Application );

  FormEmptyEventHandlerDetectorInstance.Show;
  FormEmptyEventHandlerDetectorInstance.BringToFront;
  Result            := True;
end;

class procedure TFormEmptyEventHandlerDetector.CloseInstance;
begin
  if FormEmptyEventHandlerDetectorInstance = nil then
    Exit;

  var oForm         := FormEmptyEventHandlerDetectorInstance;
  FormEmptyEventHandlerDetectorInstance := nil;

  if oForm.FScanning then
  begin
    // The scan is still on the stack (this call arrived through its message pump): freeing the
    // form now would free it under the scan.  Stop the scan and let btnScanClick release the form.  That
    // is safe only if the plug-in's code is still loaded when the scan unwinds; an unload cannot be
    // refused or postponed from here.
    oForm.FCancelRequested := True;
    oForm.Hide;
  end
  else
    oForm.Free;
end;

procedure TFormEmptyEventHandlerDetector.FormCreate( Sender: TObject );
begin
  FSortColumn       := 0;
  FSortAscending    := True;
  FScanCaption      := btnScan.Caption;
end;

procedure TFormEmptyEventHandlerDetector.FormClose( Sender: TObject; var Action: TCloseAction );
begin
  // ScanProgress pumps the message queue, so a close can arrive mid-scan: veto it, the scan is
  // still on the stack.
  if FScanning then
  begin
    Action          := caNone;
    Exit;
  end;

  // Free the form on close (it used to be hidden and kept for the whole IDE session, so it was
  // still alive - owned by the IDE's Application - when the plugin unloaded).
  if FormEmptyEventHandlerDetectorInstance = Self then
    FormEmptyEventHandlerDetectorInstance := nil;
  Action            := caFree;
end;

procedure TFormEmptyEventHandlerDetector.FormDestroy( Sender: TObject );
begin
  // Clear singleton reference when form is destroyed
  if FormEmptyEventHandlerDetectorInstance = Self then
    FormEmptyEventHandlerDetectorInstance := nil;
end;

procedure TFormEmptyEventHandlerDetector.btnCloseClick( Sender: TObject );
begin
  Close;
end;

procedure TFormEmptyEventHandlerDetector.ScanProgress( const Step: string; var Cancel: Boolean );
begin
  lblProgress.Caption := Step;
  Application.ProcessMessages;
  Cancel            := FCancelRequested;
end;

procedure TFormEmptyEventHandlerDetector.btnScanClick( Sender: TObject );
begin
  // During a scan the button reads "Cancel".
  if FScanning then
  begin
    FCancelRequested := True;
    Exit;
  end;

  var oProject      := GetActiveProject;
  if oProject = nil then
  begin
    ShowMessage( 'No active project.' );
    Exit;
  end;

  var sProjectName  := ExtractFileName( oProject.FileName );

  // Snapshot the file list now: the scan pumps messages, so the project may change under it.
  var aFiles        := GetProjectSourceFiles( oProject, [ '.pas', '.pp' ] );

  var oAllResults   := TList<TEmptyHandlerInfo>.Create;
  try
    Screen.Cursor   := crHourGlass;
    FScanning       := True;
    FCancelRequested := False;
    btnScan.Caption := '&Cancel';
    try
      lblProgress.Caption := 'Scanning ' + sProjectName + '...';
      lblProgress.Visible := True;
      lblSummary.Visible := False;
      Application.ProcessMessages;

      var bCancelled := False;
      var iSkipped  := 0;
      for var sFileName in aFiles do
      begin
        if ScanShouldStop( ScanProgress, 'Scanning: ' + ExtractFileName( sFileName ) ) then
        begin
          bCancelled := True;
          Break;
        end;

        // The open editor buffer when the unit is open, else the file: never open a module just to
        // read it (that loaded every form designer of the project and left them all open).
        try
          var sSource := ReadModuleSource( sFileName );
          if sSource <> '' then
            oAllResults.AddRange( TEmptyEventHandlerDetectorPlugin.AnalyzeUnit( sSource, sFileName ) );
        except
          on E: EStreamError do
            Inc( iSkipped ); // locked / unreadable unit: skip it, the rest of the scan still runs
          on E: EOSError do
            Inc( iSkipped );
        end;
      end;

      FResults      := oAllResults.ToArray;
      PopulateList;

      lblProgress.Visible := False;
      if bCancelled then
        lblSummary.Caption := 'Scan cancelled.'
      else if iSkipped > 0 then
        lblSummary.Caption := Format( 'Found %d empty event handler(s) in %s (%d unreadable units skipped)',
          [ Length( FResults ), sProjectName, iSkipped ] )
      else
        lblSummary.Caption := Format( 'Found %d empty event handler(s) in %s', [ Length( FResults ), sProjectName ] );
      lblSummary.Visible := True;
    finally
      FScanning     := False;
      btnScan.Caption := FScanCaption;
      Screen.Cursor := crDefault;
    end;
  finally
    oAllResults.Free;
  end;

  // CloseInstance arrived during the scan: the form is no longer the singleton and must go.
  if FormEmptyEventHandlerDetectorInstance <> Self then
    Release;
end;

procedure TFormEmptyEventHandlerDetector.PopulateList;
var
  Info              : TEmptyHandlerInfo;
  Item              : TListItem;
  FullMethodName    : string;
begin
  ListView.Items.BeginUpdate;
  try
    ListView.Items.Clear;

    for Info in FResults do
    begin
      Item := ListView.Items.Add;
      Item.Caption  := Info.UnitName;

      if Info.ClassName <> '' then
        FullMethodName := Info.ClassName + '.' + Info.MethodName
      else
        FullMethodName := Info.MethodName;

      Item.SubItems.Add( FullMethodName );
      Item.SubItems.Add( IntToStr( Info.LineNumber ) );
      Item.SubItems.Add( Info.FileName );
    end;
  finally
    ListView.Items.EndUpdate;
  end;
end;

procedure TFormEmptyEventHandlerDetector.ListViewColumnClick( Sender: TObject;
  Column: TListColumn );
begin
  if FSortColumn = Column.Index then
    FSortAscending  := not FSortAscending
  else
  begin
    FSortColumn     := Column.Index;
    FSortAscending  := True;
  end;
  ListView.AlphaSort;
end;

procedure TFormEmptyEventHandlerDetector.ListViewCompare( Sender: TObject; Item1,
  Item2: TListItem; Data: Integer; var Compare: Integer );
var
  S1, S2            : string;
  SubIdx            : Integer;
  N1, N2            : Integer;
begin
  if FSortColumn = 0 then
  begin
    S1              := Item1.Caption;
    S2              := Item2.Caption;
    Compare         := CompareText( S1, S2 );
  end
  else if FSortColumn = 2 then // Line number - numeric sort
  begin
    N1              := StrToIntDef( SafeGetSubItem( Item1, 1 ), 0 );
    N2              := StrToIntDef( SafeGetSubItem( Item2, 1 ), 0 );
    Compare         := N1 - N2;
  end
  else
  begin
    SubIdx          := FSortColumn - 1;
    S1              := SafeGetSubItem( Item1, SubIdx );
    S2              := SafeGetSubItem( Item2, SubIdx );
    Compare         := CompareText( S1, S2 );
  end;

  if not FSortAscending then
    Compare         := -Compare;
end;

procedure TFormEmptyEventHandlerDetector.ListViewDblClick( Sender: TObject );
begin
  OpenSelectedFile;
end;

procedure TFormEmptyEventHandlerDetector.OpenSelectedFile;
var
  Item              : TListItem;
  FileName          : string;
  LineNum           : Integer;
  ModuleServices    : IOTAModuleServices;
  Module            : IOTAModule;
  SourceEditor      : IOTASourceEditor;
  EditView          : IOTAEditView;
  I                 : Integer;
begin
  Item              := ListView.Selected;
  if Item = nil then
    Exit;

  FileName          := SafeGetSubItem( Item, 2 ); // File path is in SubItems[2]
  LineNum           := StrToIntDef( SafeGetSubItem( Item, 1 ), 1 );

  if not FileExists( FileName ) then
  begin
    ShowMessage( 'File not found: ' + FileName );
    Exit;
  end;

  if Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
  begin
    Module          := ModuleServices.OpenModule( FileName );
    if Module <> nil then
    begin
      for I := 0 to Module.ModuleFileCount - 1 do
      begin
        if Supports( Module.ModuleFileEditors[ I ], IOTASourceEditor, SourceEditor ) then
        begin
          SourceEditor.Show;
          // A freshly opened editor can momentarily report zero edit views;
          // guard the index rather than risk an out-of-range access.
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

procedure TFormEmptyEventHandlerDetector.mnuOpenFileClick( Sender: TObject );
begin
  OpenSelectedFile;
end;

procedure TFormEmptyEventHandlerDetector.mnuCopyToClipboardClick( Sender: TObject );
var
  SL                : TStringList;
  Item              : TListItem;
begin
  SL                := TStringList.Create;
  try
    SL.Add( 'Unit'#9'Method'#9'Line'#9'File' );

    for Item in ListView.Items do
    begin
      if Item.Selected or ( ListView.SelCount = 0 ) then
        SL.Add( Format( '%s'#9'%s'#9'%s'#9'%s', [
              Item.Caption,
              SafeGetSubItem( Item, 0 ),
              SafeGetSubItem( Item, 1 ),
              SafeGetSubItem( Item, 2 )
              ] ) );
    end;

    Clipboard.AsText := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure TFormEmptyEventHandlerDetector.btnExportClick( Sender: TObject );
var
  SL                : TStringList;
  Item              : TListItem;
begin
  if ListView.Items.Count = 0 then
  begin
    ShowMessage( 'No data to export.' );
    Exit;
  end;

  if SaveDialog.Execute then
  begin
    SL              := TStringList.Create;
    try
      SL.Add( 'Unit,Method,Line,File' );

      for Item in ListView.Items do
      begin
        SL.Add( Format( '"%s","%s","%s","%s"', [
              CsvField( Item.Caption ),
              CsvField( SafeGetSubItem( Item, 0 ) ),
              CsvField( SafeGetSubItem( Item, 1 ) ),
              CsvField( SafeGetSubItem( Item, 2 ) )
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

