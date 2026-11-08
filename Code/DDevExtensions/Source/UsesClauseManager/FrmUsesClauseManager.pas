{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmUsesClauseManager;

/// <summary>
/// Non-modal main form of the Uses Clause Manager plugin. Lets the user build the
/// project-wide exports database, analyse the active editor's source, review per-unit
/// placement recommendations, and apply selected (or all) reorganisations.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Clipbrd, System.Generics.Collections,
  System.Generics.Defaults, FrmBase, UsesClauseManager, ToolsAPI;

type
  /// <summary>Main viewer form for the Uses Clause Manager plugin.</summary>
  TFormUsesClauseManager = class( TFormBase )
    /// <summary>Top toolbar panel.</summary>
    pnlTop: TPanel;
    /// <summary>Bottom grid panel hosting buttons and progress label.</summary>
    pnlBottom: TGridPanel;
    /// <summary>Closes the form.</summary>
    btnClose: TButton;
    /// <summary>Analyses the unit currently open in the editor.</summary>
    btnAnalyze: TButton;
    /// <summary>Applies all recommended moves to the open editor.</summary>
    btnApply: TButton;
    /// <summary>List of per-unit placement results.</summary>
    ListView: TListView;
    /// <summary>Progress / status label.</summary>
    lblProgress: TLabel;
    /// <summary>Context menu for the list view.</summary>
    PopupMenu: TPopupMenu;
    /// <summary>Menu item: move only the selected units to their recommended sections.</summary>
    mnuMoveUnit: TMenuItem;
    /// <summary>Separator menu item.</summary>
    N2: TMenuItem;
    /// <summary>Menu item: copy the displayed rows to the clipboard.</summary>
    mnuCopyToClipboard: TMenuItem;
    /// <summary>Separator menu item.</summary>
    N1: TMenuItem;
    /// <summary>Menu item: re-open the analysed source file in the editor.</summary>
    mnuOpenFile: TMenuItem;
    /// <summary>Exports the analysis result as CSV.</summary>
    btnExport: TButton;
    /// <summary>Save dialog used by the export button.</summary>
    SaveDialog: TSaveDialog;
    /// <summary>Summary line shown above or below the list.</summary>
    lblSummary: TLabel;
    /// <summary>Bottom panel hosting the details memo for the selected row.</summary>
    pnlDetails: TPanel;
    /// <summary>Splitter between the list and the details panel.</summary>
    Splitter: TSplitter;
    /// <summary>Detailed information for the currently selected placement.</summary>
    memoDetails: TMemo;
    /// <summary>Label for the details memo.</summary>
    lblDetails: TLabel;
    /// <summary>Builds (or rebuilds) the project-wide exports database.</summary>
    btnBuildDB: TButton;
    /// <summary>Closes the form.</summary>
    procedure btnCloseClick( Sender: TObject );
    /// <summary>Runs the analyser on the currently active editor source.</summary>
    /// <param name="Sender">The Analyze button.</param>
    procedure btnAnalyzeClick( Sender: TObject );
    /// <summary>Applies all recommended placement changes to the active editor.</summary>
    /// <param name="Sender">The Apply button.</param>
    procedure btnApplyClick( Sender: TObject );
    /// <summary>Builds the exports database from the active project's search path.</summary>
    procedure btnBuildDBClick( Sender: TObject );
    /// <summary>Frees per-placement string lists and releases the singleton form.</summary>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>Form OnCreate handler: initialises sort and current-file state.</summary>
    procedure FormCreate( Sender: TObject );
    /// <summary>Form OnDestroy handler: frees placement string lists.</summary>
    /// <param name="Sender">The form being destroyed.</param>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Re-opens the source file when a row is double-clicked.</summary>
    procedure ListViewDblClick( Sender: TObject );
    /// <summary>Updates the details memo when the selection changes.</summary>
    procedure ListViewSelectItem( Sender: TObject; Item: TListItem; Selected: Boolean );
    /// <summary>Copies selected rows (or all rows) to the clipboard as TSV.</summary>
    procedure mnuCopyToClipboardClick( Sender: TObject );
    /// <summary>Moves only the selected units to their recommended sections.</summary>
    /// <param name="Sender">The menu item that was clicked.</param>
    procedure mnuMoveUnitClick( Sender: TObject );
    /// <summary>Re-opens the source file in the editor.</summary>
    procedure mnuOpenFileClick( Sender: TObject );
    /// <summary>Exports the placement table to a CSV file.</summary>
    procedure btnExportClick( Sender: TObject );
    /// <summary>Toggles or switches the active sort column.</summary>
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    /// <summary>Custom-column comparer used by AlphaSort.</summary>
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
  private
    /// <summary>Most recent analysis result.</summary>
    FPlacements: TArray<TUnitPlacement>;
    /// <summary>Index of the currently active sort column.</summary>
    FSortColumn: Integer;
    /// <summary>Sort direction flag.</summary>
    FSortAscending: Boolean;
    /// <summary>Path of the file most recently analysed.</summary>
    FCurrentFileName: string;
    /// <summary>True while the exports-database build is running; used to veto closing the form mid-build (the build pumps the message queue via DBProgress).</summary>
    FBusy: Boolean;
    /// <summary>Refreshes the list view from <see cref="FPlacements"/>.</summary>
    procedure PopulateList;
    /// <summary>Database OnProgress callback that updates the progress label.</summary>
    procedure DBProgress( Sender: TObject );
    /// <summary>Renders the supplied placement's identifiers and reason into the details memo.</summary>
    procedure ShowDetails( const Placement: TUnitPlacement );
    /// <summary>Re-opens <see cref="FCurrentFileName"/> in the IDE editor.</summary>
    procedure OpenSelectedFile;
    /// <summary>Frees the string lists of <see cref="FPlacements"/> and empties it.</summary>
    procedure ClearPlacements;
    /// <summary>Returns the source editor of the current module, or nil after telling the user why.</summary>
    /// <param name="AAction">What the caller is about to do, for the messages ( "apply", "move" ).</param>
    /// <returns>The source editor of the analysed file, or nil when there is none, it is another file,
    /// or its buffer is read-only.</returns>
    function AnalysedSourceEditor( const AAction: string ): IOTASourceEditor;
    /// <summary>
    /// Re-analyses the editor's CURRENT text and moves units to their recommended clauses, one
    /// entry at a time, through a single undoable edit of the clause text only.
    /// </summary>
    /// <param name="ASelectedOnly">True to move only the units selected in the list; False to move
    /// every unit whose recommendation differs from its clause.</param>
    /// <remarks>When the re-analysis differs from what the list shows ( the unit was edited ), the
    /// list is refreshed and nothing is changed, so the user always confirms what is applied.</remarks>
    procedure MoveUnits( ASelectedOnly: Boolean );
  public
    /// <summary>Shows or focuses the singleton manager form.</summary>
    class procedure Execute;
    /// <summary>Frees the singleton form, if open; called when the plug-in unloads so no form whose
    /// code lives in the expert DLL outlives it.</summary>
    class procedure CloseInstance;
  end;

var
  /// <summary>Singleton manager form instance (nil when the form is not open).</summary>
  FormInstance: TFormUsesClauseManager = nil;

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

class procedure TFormUsesClauseManager.Execute;
begin

  if FormInstance <> nil then
  begin
    FormInstance.Show;
    FormInstance.BringToFront;
    Exit;
  end;

  FormInstance := TFormUsesClauseManager.Create( Application );
  FormInstance.Show;

end;

class procedure TFormUsesClauseManager.CloseInstance;
begin
  // FormClose clears FormInstance only on a user close; freeing here leaves nothing behind.
  if FormInstance <> nil then
    FreeAndNil( FormInstance );
end;

procedure TFormUsesClauseManager.FormClose( Sender: TObject; var Action: TCloseAction );
begin

  // The database build pumps the message queue (DBProgress), so the user can
  // trigger a close mid-build. Veto it while busy, otherwise the form is freed
  // while BuildFromSearchPath is still on the stack.
  if FBusy then
  begin
    Action := caNone;
    Exit;
  end;

  FormInstance := nil;
  Action       := caFree;

end;

procedure TFormUsesClauseManager.FormCreate( Sender: TObject );
begin
  FSortColumn := 0;
  FSortAscending := True;
  FCurrentFileName := '';
end;

procedure TFormUsesClauseManager.FormDestroy( Sender: TObject );
begin
  ClearPlacements;
  if FormInstance = Self then
    FormInstance := nil;
end;

procedure TFormUsesClauseManager.DBProgress( Sender: TObject );
begin
  if Sender is TUnitExportsDatabase then
    lblProgress.Caption := 'Building database: ' + TUnitExportsDatabase( Sender ).ProgressFileName;
  Application.ProcessMessages;
end;

procedure TFormUsesClauseManager.btnCloseClick( Sender: TObject );
begin
  if FBusy then
    Exit;
  Close;
end;

procedure TFormUsesClauseManager.btnBuildDBClick( Sender: TObject );
var
  Project: IOTAProject;
begin
  Project := GetActiveProject;
  if Project = nil then
  begin
    ShowMessage( 'No active project.' );
    Exit;
  end;

  if UsesClauseManagerPlugin = nil then
    Exit;

  Screen.Cursor := crHourGlass;
  btnBuildDB.Enabled := False;
  btnAnalyze.Enabled := False;
  FBusy := True;
  try
    lblProgress.Caption := 'Building exports database...';
    lblProgress.Visible := True;
    lblSummary.Visible := False;
    Application.ProcessMessages;

    UsesClauseManagerPlugin.ExportsDB.BuildFromSearchPath( Project, DBProgress );

    lblProgress.Visible := False;
    lblSummary.Caption := Format( 'Database built: %d units scanned. Ready to analyze.',
      [ UsesClauseManagerPlugin.ExportsDB.UnitCount ] );
    lblSummary.Visible := True;
  finally
    FBusy := False;
    btnBuildDB.Enabled := True;
    btnAnalyze.Enabled := True;
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormUsesClauseManager.btnAnalyzeClick( Sender: TObject );
var
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  I: Integer;
  Source: UTF8String;
  Refactorer: TUsesClauseRefactorer;
begin
  if UsesClauseManagerPlugin = nil then
    Exit;

  if UsesClauseManagerPlugin.ExportsDB.UnitCount = 0 then
  begin
    ShowMessage( 'Build the exports database first (Build Database). Without it every '
      + 'recommendation would be based on no data.' );
    Exit;
  end;

  // Get current editor
  Module := ( BorlandIDEServices as IOTAModuleServices ).CurrentModule;
  if Module = nil then
  begin
    ShowMessage( 'No file open in editor.' );
    Exit;
  end;

  SourceEditor := nil;
  for I := 0 to Module.ModuleFileCount - 1 do
  begin
    if Supports( Module.ModuleFileEditors[ I ], IOTASourceEditor, SourceEditor ) then
      Break;
  end;

  if SourceEditor = nil then
  begin
    ShowMessage( 'No source editor found.' );
    Exit;
  end;

  FCurrentFileName := SourceEditor.FileName;

  Screen.Cursor := crHourGlass;
  btnAnalyze.Enabled := False;
  FBusy := True;
  try
    lblProgress.Caption := 'Analyzing ' + ExtractFileName( FCurrentFileName ) + '...';
    lblProgress.Visible := True;
    lblSummary.Visible := False;
    Application.ProcessMessages;

    Source := GetEditorSource( SourceEditor );

    Refactorer := TUsesClauseRefactorer.Create( UsesClauseManagerPlugin.ExportsDB );
    try
      // The previous result's string lists are freed, not leaked, when a unit is analysed again.
      ClearPlacements;
      FPlacements := Refactorer.Analyze( Source );
    finally
      Refactorer.Free;
    end;

    PopulateList;

    lblProgress.Visible := False;
    lblSummary.Caption := Format( 'Found %d units to analyze', [ Length( FPlacements ) ] );
    lblSummary.Visible := True;
  finally
    FBusy := False;
    btnAnalyze.Enabled := True;
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormUsesClauseManager.btnApplyClick( Sender: TObject );
begin
  MoveUnits( False );
end;

procedure TFormUsesClauseManager.PopulateList;
var
  Placement: TUnitPlacement;
  Item: TListItem;

  function SectionToStr( Section: TUsesSection ): string;
  begin
    case Section of
      usInterface: Result := 'interface';
      usImplementation: Result := 'implementation';
    else
      Result := '?';
    end;
  end;

begin
  ListView.Items.BeginUpdate;
  try
    ListView.Items.Clear;

    for Placement in FPlacements do
    begin
      Item := ListView.Items.Add;
      Item.Caption := Placement.UnitName;
      Item.SubItems.Add( SectionToStr( Placement.CurrentSection ) );
      Item.SubItems.Add( SectionToStr( Placement.RecommendedSection ) );
      Item.SubItems.Add( Placement.Reason );
      Item.Data := Pointer( NativeInt( ListView.Items.Count - 1 ) );

      // Highlight units that should be moved
      if Placement.CurrentSection <> Placement.RecommendedSection then
        Item.SubItems.Objects[ 0 ] := TObject( 1 );  // Mark for highlighting
    end;
  finally
    ListView.Items.EndUpdate;
  end;
end;

procedure TFormUsesClauseManager.ShowDetails( const Placement: TUnitPlacement );
begin
  memoDetails.Lines.Clear;
  memoDetails.Lines.Add( 'Unit: ' + Placement.UnitName );
  memoDetails.Lines.Add( '' );

  memoDetails.Lines.Add( 'Identifiers used in INTERFACE section:' );
  if ( Placement.IdentifiersUsedInInterface <> nil ) and
     ( Placement.IdentifiersUsedInInterface.Count > 0 ) then
    memoDetails.Lines.Add( '  ' + Placement.IdentifiersUsedInInterface.CommaText )
  else
    memoDetails.Lines.Add( '  (none)' );

  memoDetails.Lines.Add( '' );
  memoDetails.Lines.Add( 'Identifiers used in IMPLEMENTATION section:' );
  if ( Placement.IdentifiersUsedInImplementation <> nil ) and
     ( Placement.IdentifiersUsedInImplementation.Count > 0 ) then
    memoDetails.Lines.Add( '  ' + Placement.IdentifiersUsedInImplementation.CommaText )
  else
    memoDetails.Lines.Add( '  (none)' );

  memoDetails.Lines.Add( '' );
  memoDetails.Lines.Add( 'Recommendation: ' + Placement.Reason );
end;

procedure TFormUsesClauseManager.ListViewSelectItem( Sender: TObject;
  Item: TListItem; Selected: Boolean );
var
  Idx: Integer;
begin
  if Selected and ( Item <> nil ) then
  begin
    Idx := NativeInt( Item.Data );
    if ( Idx >= 0 ) and ( Idx < Length( FPlacements ) ) then
      ShowDetails( FPlacements[ Idx ] );
  end;
end;

procedure TFormUsesClauseManager.ListViewColumnClick( Sender: TObject;
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

procedure TFormUsesClauseManager.ListViewCompare( Sender: TObject; Item1,
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
    S1 := SafeGetSubItem( Item1, SubIdx );
    S2 := SafeGetSubItem( Item2, SubIdx );
  end;

  Compare := CompareText( S1, S2 );

  if not FSortAscending then
    Compare := -Compare;
end;

procedure TFormUsesClauseManager.ListViewDblClick( Sender: TObject );
begin
  OpenSelectedFile;
end;

procedure TFormUsesClauseManager.OpenSelectedFile;
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  I: Integer;
begin
  if FCurrentFileName = '' then
    Exit;

  if Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
  begin
    Module := ModuleServices.OpenModule( FCurrentFileName );
    if Module <> nil then
    begin
      for I := 0 to Module.ModuleFileCount - 1 do
      begin
        if Supports( Module.ModuleFileEditors[ I ], IOTASourceEditor, SourceEditor ) then
        begin
          SourceEditor.Show;
          Break;
        end;
      end;
    end;
  end;
end;

procedure TFormUsesClauseManager.mnuOpenFileClick( Sender: TObject );
begin
  OpenSelectedFile;
end;

procedure TFormUsesClauseManager.mnuMoveUnitClick( Sender: TObject );
begin
  if ListView.SelCount = 0 then
  begin
    ShowMessage( 'Please select one or more units to move.' );
    Exit;
  end;
  MoveUnits( True );
end;

procedure TFormUsesClauseManager.ClearPlacements;
begin
  for var Placement in FPlacements do
  begin
    Placement.IdentifiersUsedInInterface.Free;
    Placement.IdentifiersUsedInImplementation.Free;
  end;
  FPlacements := nil;
end;

function TFormUsesClauseManager.AnalysedSourceEditor( const AAction: string ): IOTASourceEditor;
var
  Module: IOTAModule;
  Buffer: IOTAEditBuffer;
begin
  Result := nil;
  Module := ( BorlandIDEServices as IOTAModuleServices ).CurrentModule;
  if Module = nil then
  begin
    ShowMessage( 'No file open in editor.' );
    Exit;
  end;

  for var I := 0 to Module.ModuleFileCount - 1 do
    if Supports( Module.ModuleFileEditors[ I ], IOTASourceEditor, Result ) then
      Break;
  if Result = nil then
  begin
    ShowMessage( 'No source editor found.' );
    Exit;
  end;

  // Refuse to rewrite a file other than the one that was analysed.
  if ( FCurrentFileName <> '' ) and not SameText( Result.FileName, FCurrentFileName ) then
  begin
    ShowMessage( Format( 'The analysed file (%s) is no longer the active editor file (%s).'#13#10 +
      'Please analyse it again before you %s.', [ ExtractFileName( FCurrentFileName ), ExtractFileName( Result.FileName ), AAction ] ) );
    Exit( nil );
  end;

  if Supports( Result, IOTAEditBuffer, Buffer ) and Buffer.IsReadOnly then
  begin
    ShowMessage( Format( '%s is read-only; no changes were made.', [ ExtractFileName( Result.FileName ) ] ) );
    Exit( nil );
  end;
end;

procedure TFormUsesClauseManager.MoveUnits( ASelectedOnly: Boolean );
var
  SourceEditor: IOTASourceEditor;
  Source: UTF8String;
  Refactorer: TUsesClauseRefactorer;
  Fresh, Moves: TArray<TUnitPlacement>;
  Selected: TStringList;
  Edits: TArray<TUsesEdit>;
  ErrorMessage, MovedNames: string;
  Writer: IOTAEditWriter;
  Stale: Boolean;
  MoveCount: Integer;
begin
  if ( UsesClauseManagerPlugin = nil ) or FBusy then
    Exit;

  if Length( FPlacements ) = 0 then
  begin
    ShowMessage( 'No analysis results. Please analyse a unit first.' );
    Exit;
  end;

  if ASelectedOnly then
    SourceEditor := AnalysedSourceEditor( 'move units' )
  else
    SourceEditor := AnalysedSourceEditor( 'apply changes' );
  if SourceEditor = nil then
    Exit;

  Selected := TStringList.Create;
  Refactorer := TUsesClauseRefactorer.Create( UsesClauseManagerPlugin.ExportsDB );
  try
    Selected.CaseSensitive := False;
    if ASelectedOnly then
      for var Item in ListView.Items do
        if Item.Selected then
          Selected.Add( Item.Caption );

    { Re-analyse the buffer as it is NOW.  Edits made since the list was built ( a unit added to or
      removed from a clause ) would otherwise be undone by applying the old result. }
    Source := GetEditorSource( SourceEditor );
    Fresh := Refactorer.Analyze( Source );

    Stale := Length( Fresh ) <> Length( FPlacements );
    if not Stale then
      for var I := 0 to High( Fresh ) do
        if not SameText( Fresh[ I ].UnitName, FPlacements[ I ].UnitName ) or
           ( Fresh[ I ].CurrentSection <> FPlacements[ I ].CurrentSection ) or
           ( Fresh[ I ].RecommendedSection <> FPlacements[ I ].RecommendedSection ) then
          Stale := True;
    if Stale then
    begin
      ClearPlacements;
      FPlacements := Fresh;
      PopulateList;
      memoDetails.Lines.Clear;
      lblSummary.Caption := Format( 'Found %d units to analyse', [ Length( FPlacements ) ] );
      ShowMessage( 'The unit has changed since it was analysed.  The list now shows the current '
        + 'analysis; review it and try again.  No changes were made.' );
      Exit;
    end;

    try
      // The moves: never a unit the analyser could not classify, and, for "move selected", only
      // the selected units.  Moves shares Fresh's string lists; only Fresh frees them.
      Moves := Copy( Fresh );
      MoveCount := 0;
      MovedNames := '';
      for var I := 0 to High( Moves ) do
      begin
        if ( Pos( 'No direct usage', Moves[ I ].Reason ) > 0 ) or
           ( ASelectedOnly and ( Selected.IndexOf( Moves[ I ].UnitName ) < 0 ) ) then
          Moves[ I ].RecommendedSection := Moves[ I ].CurrentSection;
        if Moves[ I ].CurrentSection <> Moves[ I ].RecommendedSection then
        begin
          Inc( MoveCount );
          if MovedNames <> '' then
            MovedNames := MovedNames + ', ';
          MovedNames := MovedNames + Moves[ I ].UnitName;
        end;
      end;

      if MoveCount = 0 then
      begin
        if ASelectedOnly then
          ShowMessage( 'Selected unit(s) are already in their recommended sections.' )
        else
          ShowMessage( 'No changes needed - all units are already in their optimal sections.' );
        Exit;
      end;

      if not ASelectedOnly and ( MessageDlg( Format( 'This will move %d unit(s) between uses clauses:'#13#10#13#10 +
        '%s'#13#10#13#10 + 'Do you want to continue?', [ MoveCount, MovedNames ] ),
        mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes ) then
        Exit;

      // The buffer can change while the dialog is up ( the IDE reloading a file changed on disk ),
      // and the edits are byte offsets into the text read above: refuse unless it is unchanged.
      if GetEditorSource( SourceEditor ) <> Source then
      begin
        ShowMessage( 'The unit changed while the confirmation was open.  No changes were made; '
          + 'analyse it again.' );
        Exit;
      end;

      if not Refactorer.PlanMoves( Source, Moves, Edits, ErrorMessage ) then
      begin
        ShowMessage( 'No changes were made: ' + ErrorMessage );
        Exit;
      end;

      { One undoable writer, touching only the clause text: each edit copies up to its offset, then
        deletes and inserts.  Offsets are UTF-8 byte offsets of the buffer read above, which is the
        unit IOTAEditWriter works in. }
      Screen.Cursor := crHourGlass;
      try
        try
          Writer := SourceEditor.CreateUndoableWriter;
          for var Edit in Edits do
          begin
            Writer.CopyTo( Edit.Offset );
            if Edit.DeleteCount > 0 then
              Writer.DeleteTo( Edit.Offset + Edit.DeleteCount );
            if Edit.Text <> '' then
              Writer.Insert( PAnsiChar( Edit.Text ) );
          end;
          Writer := nil;
        except
          // Releasing the writer ends its undo group, so whatever was written is one Undo step.
          Writer := nil;
          ShowMessage( 'The uses-clause edit stopped part-way, so the unit may be only partly '
            + 'changed.  Use Undo ( Ctrl+Z ) to restore it.' );
          raise;
        end;
      finally
        Screen.Cursor := crDefault;
      end;
    finally
      for var Placement in Fresh do
      begin
        Placement.IdentifiersUsedInInterface.Free;
        Placement.IdentifiersUsedInImplementation.Free;
      end;
    end;

    ShowMessage( Format( 'Moved %d unit(s): %s.', [ MoveCount, MovedNames ] ) );

    // The results are now stale.
    ClearPlacements;
    ListView.Items.Clear;
    memoDetails.Lines.Clear;
    lblSummary.Caption := 'Changes applied. Analyse again to see the current state.';
  finally
    Refactorer.Free;
    Selected.Free;
  end;
end;

procedure TFormUsesClauseManager.mnuCopyToClipboardClick( Sender: TObject );
var
  SL: TStringList;
  Item: TListItem;
begin
  SL := TStringList.Create;
  try
    SL.Add( 'Unit'#9'Current'#9'Recommended'#9'Reason' );

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

procedure TFormUsesClauseManager.btnExportClick( Sender: TObject );
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
      SL.Add( 'Unit,Current,Recommended,Reason' );

      for Item in ListView.Items do
      begin
        SL.Add( Format( '"%s","%s","%s","%s"', [
          Item.Caption,
          SafeGetSubItem( Item, 0 ),
          SafeGetSubItem( Item, 1 ),
          SafeGetSubItem( Item, 2 )
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
