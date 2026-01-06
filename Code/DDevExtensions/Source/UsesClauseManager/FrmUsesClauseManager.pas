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

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Menus, Clipbrd, Generics.Collections,
  Generics.Defaults, FrmBase, UsesClauseManager, ToolsAPI;

type
  TFormUsesClauseManager = class( TFormBase )
    pnlTop: TPanel;
    pnlBottom: TGridPanel;
    btnClose: TButton;
    btnAnalyze: TButton;
    btnApply: TButton;
    ListView: TListView;
    lblProgress: TLabel;
    PopupMenu: TPopupMenu;
    mnuMoveUnit: TMenuItem;
    N2: TMenuItem;
    mnuCopyToClipboard: TMenuItem;
    N1: TMenuItem;
    mnuOpenFile: TMenuItem;
    btnExport: TButton;
    SaveDialog: TSaveDialog;
    lblSummary: TLabel;
    pnlDetails: TPanel;
    Splitter: TSplitter;
    memoDetails: TMemo;
    lblDetails: TLabel;
    btnBuildDB: TButton;
    procedure btnCloseClick( Sender: TObject );
    procedure btnAnalyzeClick( Sender: TObject );
    procedure btnApplyClick( Sender: TObject );
    procedure btnBuildDBClick( Sender: TObject );
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    procedure FormCreate( Sender: TObject );
    procedure FormDestroy( Sender: TObject );
    procedure ListViewDblClick( Sender: TObject );
    procedure ListViewSelectItem( Sender: TObject; Item: TListItem; Selected: Boolean );
    procedure mnuCopyToClipboardClick( Sender: TObject );
    procedure mnuMoveUnitClick( Sender: TObject );
    procedure mnuOpenFileClick( Sender: TObject );
    procedure btnExportClick( Sender: TObject );
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
  private
    FPlacements: TArray<TUnitPlacement>;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    FCurrentFileName: string;
    procedure PopulateList;
    procedure DBProgress( Sender: TObject );
    procedure ShowDetails( const Placement: TUnitPlacement );
    procedure OpenSelectedFile;
  public
    class procedure Execute;
  end;

var
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

procedure TFormUsesClauseManager.FormClose( Sender: TObject; var Action: TCloseAction );
begin

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
var
  I: Integer;
begin
  // Free StringLists in placements
  for I := 0 to Length( FPlacements ) - 1 do
  begin
    FPlacements[ I ].IdentifiersUsedInInterface.Free;
    FPlacements[ I ].IdentifiersUsedInImplementation.Free;
  end;
end;

procedure TFormUsesClauseManager.DBProgress( Sender: TObject );
begin
  if Sender is TUnitExportsDatabase then
    lblProgress.Caption := 'Building database: ' + TUnitExportsDatabase( Sender ).ProgressFileName;
  Application.ProcessMessages;
end;

procedure TFormUsesClauseManager.btnCloseClick( Sender: TObject );
begin
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
  try
    lblProgress.Caption := 'Analyzing ' + ExtractFileName( FCurrentFileName ) + '...';
    lblProgress.Visible := True;
    lblSummary.Visible := False;
    Application.ProcessMessages;

    Source := GetEditorSource( SourceEditor );

    Refactorer := TUsesClauseRefactorer.Create( UsesClauseManagerPlugin.ExportsDB );
    try
      FPlacements := Refactorer.Analyze( Source );
    finally
      Refactorer.Free;
    end;

    PopulateList;

    lblProgress.Visible := False;
    lblSummary.Caption := Format( 'Found %d units to analyze', [ Length( FPlacements ) ] );
    lblSummary.Visible := True;
  finally
    btnAnalyze.Enabled := True;
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormUsesClauseManager.btnApplyClick( Sender: TObject );
var
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  I: Integer;
  Source, NewSource: UTF8String;
  Refactorer: TUsesClauseRefactorer;
  EditWriter: IOTAEditWriter;
  ChangedCount: Integer;
  Placement: TUnitPlacement;
begin
  if UsesClauseManagerPlugin = nil then
    Exit;

  if Length( FPlacements ) = 0 then
  begin
    ShowMessage( 'No analysis results. Please analyze a unit first.' );
    Exit;
  end;

  // Count how many units will be moved
  ChangedCount := 0;
  for Placement in FPlacements do
  begin
    if Placement.CurrentSection <> Placement.RecommendedSection then
      Inc( ChangedCount );
  end;

  if ChangedCount = 0 then
  begin
    ShowMessage( 'No changes needed - all units are already in their optimal sections.' );
    Exit;
  end;

  if MessageDlg( Format( 'This will move %d unit(s) between uses clauses.'#13#10#13#10 +
    'Do you want to continue?', [ ChangedCount ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

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

  Screen.Cursor := crHourGlass;
  btnApply.Enabled := False;
  try
    // Get current source
    Source := GetEditorSource( SourceEditor );

    // Generate refactored source
    Refactorer := TUsesClauseRefactorer.Create( UsesClauseManagerPlugin.ExportsDB );
    try
      NewSource := Refactorer.GenerateRefactoredSource( Source, FPlacements );
    finally
      Refactorer.Free;
    end;

    // Check if anything changed
    if NewSource = Source then
    begin
      ShowMessage( 'No changes were made to the source.' );
      Exit;
    end;

    // Write the new source back to the editor
    EditWriter := SourceEditor.CreateUndoableWriter;
    try
      EditWriter.DeleteTo( MaxInt );
      EditWriter.Insert( PAnsiChar( NewSource ) );
    finally
      EditWriter := nil;
    end;

    ShowMessage( Format( 'Successfully reorganized uses clauses. %d unit(s) moved.', [ ChangedCount ] ) );

    // Clear the analysis results since they're now stale
    for I := 0 to Length( FPlacements ) - 1 do
    begin
      FPlacements[ I ].IdentifiersUsedInInterface.Free;
      FPlacements[ I ].IdentifiersUsedInImplementation.Free;
    end;
    SetLength( FPlacements, 0 );
    ListView.Items.Clear;
    memoDetails.Lines.Clear;
    lblSummary.Caption := 'Changes applied. Re-analyze to see current state.';

  finally
    btnApply.Enabled := True;
    Screen.Cursor := crDefault;
  end;
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
var
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  I: Integer;
  Source, NewSource: UTF8String;
  Refactorer: TUsesClauseRefactorer;
  EditWriter: IOTAEditWriter;
  SelectedPlacements: TArray<TUnitPlacement>;
  Item: TListItem;
  SelectedUnits: TStringList;
  MoveCount: Integer;
begin
  if UsesClauseManagerPlugin = nil then
    Exit;

  if ListView.SelCount = 0 then
  begin
    ShowMessage( 'Please select one or more units to move.' );
    Exit;
  end;

  // Collect selected unit names that need moving
  SelectedUnits := TStringList.Create;
  try
    SelectedUnits.CaseSensitive := False;
    for Item in ListView.Items do
    begin
      if Item.Selected then
      begin
        // Check if this unit needs moving (Current <> Recommended)
        if SafeGetSubItem( Item, 0 ) <> SafeGetSubItem( Item, 1 ) then
          SelectedUnits.Add( Item.Caption );
      end;
    end;

    if SelectedUnits.Count = 0 then
    begin
      ShowMessage( 'Selected unit(s) are already in their recommended sections.' );
      Exit;
    end;

    // Create a modified placements array - only move selected units
    SetLength( SelectedPlacements, Length( FPlacements ) );
    for I := 0 to Length( FPlacements ) - 1 do
    begin
      SelectedPlacements[ I ] := FPlacements[ I ];
      // Create new TStringList instances to avoid double-free
      SelectedPlacements[ I ].IdentifiersUsedInInterface := TStringList.Create;
      SelectedPlacements[ I ].IdentifiersUsedInInterface.Assign( FPlacements[ I ].IdentifiersUsedInInterface );
      SelectedPlacements[ I ].IdentifiersUsedInImplementation := TStringList.Create;
      SelectedPlacements[ I ].IdentifiersUsedInImplementation.Assign( FPlacements[ I ].IdentifiersUsedInImplementation );

      // If not selected, set CurrentSection = RecommendedSection so it won't be moved
      if SelectedUnits.IndexOf( FPlacements[ I ].UnitName ) < 0 then
        SelectedPlacements[ I ].CurrentSection := SelectedPlacements[ I ].RecommendedSection;
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

    Screen.Cursor := crHourGlass;
    try
      Source := GetEditorSource( SourceEditor );

      Refactorer := TUsesClauseRefactorer.Create( UsesClauseManagerPlugin.ExportsDB );
      try
        NewSource := Refactorer.GenerateRefactoredSource( Source, SelectedPlacements );
      finally
        Refactorer.Free;
      end;

      if NewSource = Source then
      begin
        ShowMessage( 'No changes were made to the source.' );
        Exit;
      end;

      // Write the new source back
      EditWriter := SourceEditor.CreateUndoableWriter;
      try
        EditWriter.DeleteTo( MaxInt );
        EditWriter.Insert( PAnsiChar( NewSource ) );
      finally
        EditWriter := nil;
      end;

      MoveCount := SelectedUnits.Count;
      ShowMessage( Format( 'Moved %d unit(s) to recommended section.', [ MoveCount ] ) );

      // Clear results - they're now stale
      for I := 0 to Length( FPlacements ) - 1 do
      begin
        FPlacements[ I ].IdentifiersUsedInInterface.Free;
        FPlacements[ I ].IdentifiersUsedInImplementation.Free;
      end;
      SetLength( FPlacements, 0 );
      ListView.Items.Clear;
      memoDetails.Lines.Clear;
      lblSummary.Caption := 'Changes applied. Re-analyze to see current state.';

    finally
      // Free the temporary placements' string lists
      for I := 0 to Length( SelectedPlacements ) - 1 do
      begin
        SelectedPlacements[ I ].IdentifiersUsedInInterface.Free;
        SelectedPlacements[ I ].IdentifiersUsedInImplementation.Free;
      end;
      Screen.Cursor := crDefault;
    end;

  finally
    SelectedUnits.Free;
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
