{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmLibraryPathSorter;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Types, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Menus, Buttons, FrmBase, LibraryPathSorter;

type
  TFormLibraryPathSorter = class( TFormBase )
    pnlTop: TPanel;
    pnlBottom: TPanel;
    pnlMain: TPanel;
    Splitter: TSplitter;
    pnlCurrent: TPanel;
    SplitterPanels: TSplitter;
    pnlWorking: TPanel;
    lblPathType: TLabel;
    cboPathType: TComboBox;
    lblPlatform: TLabel;
    cboPlatform: TComboBox;
    lblCurrent: TLabel;
    lstCurrent: TListBox;
    lblWorking: TLabel;
    lstWorking: TListBox;
    btnClose: TButton;
    btnApply: TButton;
    btnRestore: TButton;
    btnBackup: TButton;
    pnlBackups: TPanel;
    lblBackups: TLabel;
    lvBackups: TListView;
    SplitterBackups: TSplitter;
    btnDeleteBackup: TButton;
    lblStatus: TLabel;
    lblDeleted: TLabel;
    lblCaution: TLabel;
    chkAutoBackup: TCheckBox;
    pnlWorkingButtons: TPanel;
    btnWorkingUp: TSpeedButton;
    btnWorkingDown: TSpeedButton;
    btnWorkingTop: TSpeedButton;
    btnWorkingBottom: TSpeedButton;
    btnCopyToWorking: TSpeedButton;
    btnSortAlpha: TButton;
    pmWorking: TPopupMenu;
    mnuDeleteEntry: TMenuItem;
    pmCurrent: TPopupMenu;
    mnuShowMissing: TMenuItem;
    procedure btnCloseClick( Sender: TObject );
    procedure mnuShowMissingClick( Sender: TObject );
    procedure mnuDeleteEntryClick( Sender: TObject );
    procedure btnApplyClick( Sender: TObject );
    procedure btnRestoreClick( Sender: TObject );
    procedure btnBackupClick( Sender: TObject );
    procedure btnDeleteBackupClick( Sender: TObject );
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    procedure FormCreate( Sender: TObject );
    procedure cboPathTypeChange( Sender: TObject );
    procedure cboPlatformChange( Sender: TObject );
    procedure lvBackupsSelectItem( Sender: TObject; Item: TListItem; Selected: Boolean );
    procedure btnWorkingUpClick( Sender: TObject );
    procedure btnWorkingDownClick( Sender: TObject );
    procedure btnWorkingTopClick( Sender: TObject );
    procedure btnWorkingBottomClick( Sender: TObject );
    procedure btnCopyToWorkingClick( Sender: TObject );
    procedure btnSortAlphaClick( Sender: TObject );
    procedure lstWorkingClick( Sender: TObject );
    procedure lstWorkingDragOver( Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean );
    procedure lstWorkingDragDrop( Sender, Source: TObject; X, Y: Integer );
    procedure lstWorkingMouseDown( Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer );
    procedure lstWorkingDrawItem( Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState );
    procedure lstCurrentDrawItem( Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState );
  private
    FDragIndex: Integer;
    FOriginalPaths: string;
    FDeletedCount: Integer;
    function IsDuplicatePath( AListBox: TListBox; Index: Integer ): Boolean;
    function IsPathInWorkingPanel( const APath: string ): Boolean;
    procedure UpdatePanelLabels;
    procedure LoadPlatforms;
    procedure LoadPathTypes;
    procedure LoadCurrentPaths;
    procedure LoadWorkingPaths;
    procedure LoadBackupHistory;
    procedure UpdateStatus( const AMessage: string );
    procedure UpdateButtonStates;
    function GetSelectedPathType: TLibraryPathType;
    function GetSelectedPlatform: string;
    procedure MoveListItem( AListBox: TListBox; Delta: Integer );
    procedure MoveListItemToEnd( AListBox: TListBox; ToTop: Boolean );
    function GetPathsFromListBox( AListBox: TListBox ): string;
    procedure ApplyPaths( const APaths: string );
    procedure LoadFormSettings;
    procedure SaveFormSettings;
  public
    class procedure Execute;
  end;

var
  FormLibraryPathSorterInstance: TFormLibraryPathSorter = nil;

implementation

{$R *.dfm}

uses
  Registry, IDEUtils, Main;

class procedure TFormLibraryPathSorter.Execute;
begin
  if FormLibraryPathSorterInstance <> nil then
  begin
    FormLibraryPathSorterInstance.Show;
    FormLibraryPathSorterInstance.BringToFront;
    Exit;
  end;

  FormLibraryPathSorterInstance := TFormLibraryPathSorter.Create( Application );
  FormLibraryPathSorterInstance.Show;
end;

procedure TFormLibraryPathSorter.FormCreate( Sender: TObject );
begin
  FDragIndex := -1;
  FDeletedCount := 0;

  // Load saved form position and size
  LoadFormSettings;

  // Enable owner-draw for duplicate highlighting and missing path detection
  lstWorking.Style := lbOwnerDrawFixed;
  lstCurrent.Style := lbOwnerDrawFixed;

  // Enable multi-select on original panel to highlight matching entries
  lstCurrent.MultiSelect := True;

  LoadPathTypes;
  LoadPlatforms;

  if cboPathType.Items.Count > 0 then
    cboPathType.ItemIndex := 0;
  if cboPlatform.Items.Count > 0 then
    cboPlatform.ItemIndex := 0;

  chkAutoBackup.Checked := True;

  LoadCurrentPaths;
  LoadBackupHistory;
  UpdateButtonStates;
end;

procedure TFormLibraryPathSorter.FormClose( Sender: TObject; var Action: TCloseAction );
begin
  // Save form position, size, and panel width
  SaveFormSettings;

  FormLibraryPathSorterInstance := nil;
  Action := caFree;
end;

procedure TFormLibraryPathSorter.LoadPathTypes;
var
  PathType: TLibraryPathType;
begin
  cboPathType.Items.Clear;
  for PathType := Low( TLibraryPathType ) to High( TLibraryPathType ) do
    cboPathType.Items.Add( PathType.ToDisplayName );
end;

procedure TFormLibraryPathSorter.LoadPlatforms;
var
  Platforms: TStringList;
begin
  cboPlatform.Items.Clear;

  if LibraryPathSorterPlugin = nil then
    Exit;

  Platforms := LibraryPathSorterPlugin.PathHandler.GetAvailablePlatforms;
  try
    cboPlatform.Items.Assign( Platforms );
  finally
    Platforms.Free;
  end;
end;

function TFormLibraryPathSorter.GetSelectedPathType: TLibraryPathType;
begin
  if ( cboPathType.ItemIndex >= 0 ) and
     ( cboPathType.ItemIndex <= Ord( High( TLibraryPathType ) ) ) then
    Result := TLibraryPathType( cboPathType.ItemIndex )
  else
    Result := lptSearchPath;
end;

function TFormLibraryPathSorter.GetSelectedPlatform: string;
begin
  if cboPlatform.ItemIndex >= 0 then
    Result := cboPlatform.Items[cboPlatform.ItemIndex]
  else
    Result := 'Win32';
end;

procedure TFormLibraryPathSorter.LoadCurrentPaths;
var
  PathList: TStringList;
begin
  lstCurrent.Items.Clear;
  lstWorking.Items.Clear;
  FOriginalPaths := '';
  FDeletedCount := 0;

  if LibraryPathSorterPlugin = nil then
    Exit;

  FOriginalPaths := LibraryPathSorterPlugin.PathHandler.ReadPaths(
    GetSelectedPathType, GetSelectedPlatform );

  PathList := TStringList.Create;
  try
    SplitPaths( PathList, FOriginalPaths, False );
    lstCurrent.Items.Assign( PathList );
  finally
    PathList.Free;
  end;

  UpdateStatus( Format( '%d paths loaded', [lstCurrent.Items.Count] ) );
  LoadWorkingPaths;
  UpdatePanelLabels;
  UpdateButtonStates;
end;

procedure TFormLibraryPathSorter.LoadWorkingPaths;
var
  SortedPaths: string;
  PathList: TStringList;
begin
  lstWorking.Items.Clear;

  if ( LibraryPathSorterPlugin = nil ) or ( FOriginalPaths = '' ) then
    Exit;

  // Start with alphabetically sorted paths in the working panel
  SortedPaths := LibraryPathSorterPlugin.PathHandler.SortPaths( FOriginalPaths, True );

  PathList := TStringList.Create;
  try
    SplitPaths( PathList, SortedPaths, False );
    lstWorking.Items.Assign( PathList );
  finally
    PathList.Free;
  end;

  // Refresh original panel to update missing path highlighting
  lstCurrent.Invalidate;

  // Check for count mismatch
  if lstWorking.Items.Count <> lstCurrent.Items.Count then
    UpdateStatus( Format( 'WARNING: Original has %d paths, Working has %d!',
      [lstCurrent.Items.Count, lstWorking.Items.Count] ) );
end;

procedure TFormLibraryPathSorter.LoadBackupHistory;
var
  Backups: TArray<TPathBackup>;
  Backup: TPathBackup;
  Item: TListItem;
begin
  lvBackups.Items.Clear;

  if LibraryPathSorterPlugin = nil then
    Exit;

  Backups := LibraryPathSorterPlugin.BackupManager.GetAllBackups;

  for Backup in Backups do
  begin
    Item := lvBackups.Items.Add;
    Item.Caption := DateTimeToStr( Backup.Timestamp );
    Item.SubItems.Add( Backup.PathType.ToDisplayName );
    Item.SubItems.Add( Backup.Platform );
    Item.SubItems.Add( Backup.Description );
    Item.Data := Pointer( NativeInt( Ord( Backup.PathType ) ) );
  end;

  btnRestore.Enabled := False;
  btnDeleteBackup.Enabled := False;
end;

procedure TFormLibraryPathSorter.UpdateStatus( const AMessage: string );
begin
  lblStatus.Caption := AMessage;
end;

procedure TFormLibraryPathSorter.UpdateButtonStates;
var
  WorkingIdx: Integer;
begin
  WorkingIdx := lstWorking.ItemIndex;

  // Working list buttons
  btnWorkingUp.Enabled := WorkingIdx > 0;
  btnWorkingDown.Enabled := ( WorkingIdx >= 0 ) and ( WorkingIdx < lstWorking.Items.Count - 1 );
  btnWorkingTop.Enabled := WorkingIdx > 0;
  btnWorkingBottom.Enabled := ( WorkingIdx >= 0 ) and ( WorkingIdx < lstWorking.Items.Count - 1 );
  mnuDeleteEntry.Enabled := WorkingIdx >= 0;

  // Copy and sort buttons
  btnCopyToWorking.Enabled := lstCurrent.Items.Count > 0;
  btnSortAlpha.Enabled := lstWorking.Items.Count > 0;
  btnApply.Enabled := lstWorking.Items.Count > 0;
end;

procedure TFormLibraryPathSorter.MoveListItem( AListBox: TListBox; Delta: Integer );
var
  Idx, NewIdx: Integer;
begin
  Idx := AListBox.ItemIndex;
  if Idx < 0 then
    Exit;

  NewIdx := Idx + Delta;
  if ( NewIdx < 0 ) or ( NewIdx >= AListBox.Items.Count ) then
    Exit;

  AListBox.Items.Exchange( Idx, NewIdx );
  AListBox.ItemIndex := NewIdx;
  UpdateButtonStates;
end;

procedure TFormLibraryPathSorter.MoveListItemToEnd( AListBox: TListBox; ToTop: Boolean );
var
  Idx, NewIdx: Integer;
  Item: string;
begin
  Idx := AListBox.ItemIndex;
  if Idx < 0 then
    Exit;

  Item := AListBox.Items[Idx];
  AListBox.Items.Delete( Idx );

  if ToTop then
    NewIdx := 0
  else
    NewIdx := AListBox.Items.Count;

  AListBox.Items.Insert( NewIdx, Item );
  AListBox.ItemIndex := NewIdx;
  UpdateButtonStates;
end;

function TFormLibraryPathSorter.GetPathsFromListBox( AListBox: TListBox ): string;
begin
  Result := ConcatPaths( AListBox.Items, ';' );
end;

procedure TFormLibraryPathSorter.ApplyPaths( const APaths: string );
begin
  if LibraryPathSorterPlugin = nil then
    Exit;

  // Create backup if auto-backup is enabled
  if chkAutoBackup.Checked and ( FOriginalPaths <> '' ) then
  begin
    if not LibraryPathSorterPlugin.BackupManager.CreateBackup(
         GetSelectedPathType, GetSelectedPlatform, FOriginalPaths, 'Before apply' ) then
    begin
      if MessageDlg( 'Failed to create backup. Continue anyway?', mtWarning, [mbYes, mbNo], 0 ) <> mrYes then
        Exit;
    end;
  end;

  // Apply the paths
  LibraryPathSorterPlugin.PathHandler.WritePaths(
    GetSelectedPathType, GetSelectedPlatform, APaths );

  // Reload
  LoadCurrentPaths;
  LoadBackupHistory;

  UpdateStatus( 'Paths saved successfully' );
end;

procedure TFormLibraryPathSorter.cboPathTypeChange( Sender: TObject );
begin
  LoadCurrentPaths;
end;

procedure TFormLibraryPathSorter.cboPlatformChange( Sender: TObject );
begin
  LoadCurrentPaths;
end;

procedure TFormLibraryPathSorter.lstWorkingClick( Sender: TObject );
var
  SelectedPath: string;
  I: Integer;
begin
  UpdateButtonStates;

  // Clear previous selections in original panel
  lstCurrent.ClearSelection;

  // If an item is selected, highlight matching entries in original panel
  if lstWorking.ItemIndex >= 0 then
  begin
    SelectedPath := lstWorking.Items[lstWorking.ItemIndex];

    for I := 0 to lstCurrent.Items.Count - 1 do
    begin
      if SameText( lstCurrent.Items[I], SelectedPath ) then
        lstCurrent.Selected[I] := True;
    end;
  end;
end;

function TFormLibraryPathSorter.IsDuplicatePath( AListBox: TListBox; Index: Integer ): Boolean;
var
  I: Integer;
  CurrentPath: string;
begin
  Result := False;
  if ( Index < 0 ) or ( Index >= AListBox.Items.Count ) then
    Exit;

  CurrentPath := AListBox.Items[Index];

  // Check if this path appears elsewhere in the list
  for I := 0 to AListBox.Items.Count - 1 do
  begin
    if ( I <> Index ) and SameText( AListBox.Items[I], CurrentPath ) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TFormLibraryPathSorter.lstWorkingDrawItem( Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState );
var
  ListBox: TListBox;
  ItemText: string;
  IsDuplicate: Boolean;
begin
  ListBox := Control as TListBox;

  if ( Index < 0 ) or ( Index >= ListBox.Items.Count ) then
    Exit;

  ItemText := ListBox.Items[Index];
  IsDuplicate := IsDuplicatePath( ListBox, Index );

  // Set background
  if odSelected in State then
    ListBox.Canvas.Brush.Color := clHighlight
  else
    ListBox.Canvas.Brush.Color := clWindow;

  ListBox.Canvas.FillRect( Rect );

  // Set text color
  if odSelected in State then
    ListBox.Canvas.Font.Color := clHighlightText
  else if IsDuplicate then
    ListBox.Canvas.Font.Color := clRed
  else
    ListBox.Canvas.Font.Color := clWindowText;

  // Make duplicates bold
  if IsDuplicate then
    ListBox.Canvas.Font.Style := [fsBold]
  else
    ListBox.Canvas.Font.Style := [];

  // Draw the text
  ListBox.Canvas.TextOut( Rect.Left + 2, Rect.Top + 1, ItemText );

  // Draw focus rectangle if focused
  if odFocused in State then
    ListBox.Canvas.DrawFocusRect( Rect );
end;

function TFormLibraryPathSorter.IsPathInWorkingPanel( const APath: string ): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to lstWorking.Items.Count - 1 do
  begin
    if SameText( lstWorking.Items[I], APath ) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TFormLibraryPathSorter.UpdatePanelLabels;
var
  Difference: Integer;
begin
  lblCurrent.Caption := Format( '  Original Paths (Read-Only - Current Registry Order): %d',
    [lstCurrent.Items.Count] );
  lblWorking.Caption := Format( '  Working Panel (Editable - Arrange Then Apply): %d',
    [lstWorking.Items.Count] );

  // Update deleted count label and compare with actual difference
  Difference := lstCurrent.Items.Count - lstWorking.Items.Count;

  if ( FDeletedCount > 0 ) or ( Difference > 0 ) then
  begin
    if FDeletedCount = Difference then
      // Counts match - normal display
      lblDeleted.Caption := Format( 'Deleted: %d', [FDeletedCount] )
    else
      // Mismatch - flag it! Paths were lost/added unexpectedly
      lblDeleted.Caption := Format( 'Deleted: %d (Expected: %d) WARNING!', [FDeletedCount, Difference] );
  end
  else
    lblDeleted.Caption := '';
end;

procedure TFormLibraryPathSorter.lstCurrentDrawItem( Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState );
var
  ListBox: TListBox;
  ItemText: string;
  IsMissing: Boolean;
begin
  ListBox := Control as TListBox;

  if ( Index < 0 ) or ( Index >= ListBox.Items.Count ) then
    Exit;

  ItemText := ListBox.Items[Index];
  IsMissing := not IsPathInWorkingPanel( ItemText );

  // Set background
  if odSelected in State then
    ListBox.Canvas.Brush.Color := clHighlight
  else if IsMissing then
    ListBox.Canvas.Brush.Color := $CCCCFF  // Light red/pink background for missing
  else
    ListBox.Canvas.Brush.Color := clWindow;

  ListBox.Canvas.FillRect( Rect );

  // Set text color
  if odSelected in State then
    ListBox.Canvas.Font.Color := clHighlightText
  else if IsMissing then
    ListBox.Canvas.Font.Color := clMaroon
  else
    ListBox.Canvas.Font.Color := clWindowText;

  // Make missing items bold
  if IsMissing then
    ListBox.Canvas.Font.Style := [fsBold]
  else
    ListBox.Canvas.Font.Style := [];

  // Draw the text
  ListBox.Canvas.TextOut( Rect.Left + 2, Rect.Top + 1, ItemText );

  // Draw focus rectangle if focused
  if odFocused in State then
    ListBox.Canvas.DrawFocusRect( Rect );
end;

procedure TFormLibraryPathSorter.lstWorkingMouseDown( Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer );
var
  Idx: Integer;
begin
  if Button = mbLeft then
  begin
    Idx := lstWorking.ItemAtPos( Point( X, Y ), True );
    if Idx >= 0 then
    begin
      FDragIndex := Idx;
      lstWorking.ItemIndex := Idx;
      lstWorking.BeginDrag( False, 5 ); // Start drag after 5 pixel movement
    end;
  end;
end;

procedure TFormLibraryPathSorter.lstWorkingDragOver( Sender, Source: TObject;
  X, Y: Integer; State: TDragState; var Accept: Boolean );
begin
  Accept := ( Source = lstWorking ) and ( FDragIndex >= 0 );
end;

procedure TFormLibraryPathSorter.lstWorkingDragDrop( Sender, Source: TObject;
  X, Y: Integer );
var
  DropIdx: Integer;
  Item: string;
begin
  if Source <> lstWorking then
    Exit;

  DropIdx := lstWorking.ItemAtPos( Point( X, Y ), False );

  // If dropped below the last item, move to end
  if DropIdx < 0 then
    DropIdx := lstWorking.Items.Count - 1;

  // Don't do anything if dropping on same position
  if DropIdx = FDragIndex then
    Exit;

  // Move the item
  Item := lstWorking.Items[FDragIndex];
  lstWorking.Items.Delete( FDragIndex );

  // Adjust index if we deleted before the drop position
  if FDragIndex < DropIdx then
    Dec( DropIdx );

  lstWorking.Items.Insert( DropIdx, Item );
  lstWorking.ItemIndex := DropIdx;

  FDragIndex := -1;
  lstCurrent.Invalidate;  // Refresh to update missing path highlighting
  UpdateButtonStates;
end;

procedure TFormLibraryPathSorter.btnWorkingUpClick( Sender: TObject );
begin
  MoveListItem( lstWorking, -1 );
end;

procedure TFormLibraryPathSorter.btnWorkingDownClick( Sender: TObject );
begin
  MoveListItem( lstWorking, 1 );
end;

procedure TFormLibraryPathSorter.btnWorkingTopClick( Sender: TObject );
begin
  MoveListItemToEnd( lstWorking, True );
end;

procedure TFormLibraryPathSorter.btnWorkingBottomClick( Sender: TObject );
begin
  MoveListItemToEnd( lstWorking, False );
end;

procedure TFormLibraryPathSorter.btnCopyToWorkingClick( Sender: TObject );
begin
  lstWorking.Items.Assign( lstCurrent.Items );
  FDeletedCount := 0;  // Reset deleted count
  lstCurrent.Invalidate;  // Refresh to update missing path highlighting
  UpdatePanelLabels;
  UpdateButtonStates;
  UpdateStatus( 'Copied original order to working panel' );
end;

procedure TFormLibraryPathSorter.btnSortAlphaClick( Sender: TObject );
var
  SortedPaths: string;
  PathList: TStringList;
  OriginalCount: Integer;
begin
  if lstWorking.Items.Count = 0 then
    Exit;

  OriginalCount := lstWorking.Items.Count;

  SortedPaths := LibraryPathSorterPlugin.PathHandler.SortPaths(
    GetPathsFromListBox( lstWorking ), True );

  PathList := TStringList.Create;
  try
    SplitPaths( PathList, SortedPaths, False );
    lstWorking.Items.Assign( PathList );
  finally
    PathList.Free;
  end;

  lstCurrent.Invalidate;  // Refresh to update missing path highlighting
  UpdatePanelLabels;
  UpdateButtonStates;

  // Check if any paths were lost during sort
  if lstWorking.Items.Count <> OriginalCount then
    UpdateStatus( Format( 'WARNING: Sort changed count from %d to %d!',
      [OriginalCount, lstWorking.Items.Count] ) )
  else
    UpdateStatus( 'Working panel sorted alphabetically' );
end;

procedure TFormLibraryPathSorter.btnCloseClick( Sender: TObject );
begin
  Close;
end;

procedure TFormLibraryPathSorter.mnuDeleteEntryClick( Sender: TObject );
begin
  if lstWorking.ItemIndex >= 0 then
  begin
    lstWorking.Items.Delete( lstWorking.ItemIndex );
    Inc( FDeletedCount );
    lstCurrent.Invalidate;  // Refresh to update missing path highlighting
    UpdatePanelLabels;
    UpdateButtonStates;
    UpdateStatus( 'Entry deleted from working panel' );
  end;
end;

procedure TFormLibraryPathSorter.mnuShowMissingClick( Sender: TObject );
var
  I: Integer;
  MissingPaths: TStringList;
  Msg: string;
begin
  MissingPaths := TStringList.Create;
  try
    for I := 0 to lstCurrent.Items.Count - 1 do
    begin
      if not IsPathInWorkingPanel( lstCurrent.Items[I] ) then
        MissingPaths.Add( lstCurrent.Items[I] );
    end;

    if MissingPaths.Count = 0 then
      ShowMessage( 'No paths are missing from the working panel.' )
    else
    begin
      Msg := Format( '%d path(s) missing from working panel:'#13#10#13#10, [MissingPaths.Count] );
      for I := 0 to MissingPaths.Count - 1 do
      begin
        Msg := Msg + MissingPaths[I] + #13#10;
        if I >= 19 then  // Limit display to 20 items
        begin
          Msg := Msg + Format( '... and %d more', [MissingPaths.Count - 20] );
          Break;
        end;
      end;
      ShowMessage( Msg );
    end;
  finally
    MissingPaths.Free;
  end;
end;

procedure TFormLibraryPathSorter.btnBackupClick( Sender: TObject );
var
  Description: string;
begin
  if LibraryPathSorterPlugin = nil then
    Exit;

  if FOriginalPaths = '' then
  begin
    ShowMessage( 'No paths to backup.' );
    Exit;
  end;

  Description := InputBox( 'Backup Description', 'Enter a description for this backup:', 'Manual backup' );

  if LibraryPathSorterPlugin.BackupManager.CreateBackup(
       GetSelectedPathType, GetSelectedPlatform, FOriginalPaths, Description ) then
  begin
    LoadBackupHistory;
    UpdateStatus( 'Backup created successfully' );
  end
  else
    ShowMessage( 'Failed to create backup.' );
end;

procedure TFormLibraryPathSorter.btnApplyClick( Sender: TObject );
var
  NewPaths: string;
begin
  if LibraryPathSorterPlugin = nil then
    Exit;

  if lstWorking.Items.Count = 0 then
  begin
    ShowMessage( 'No paths to apply.' );
    Exit;
  end;

  NewPaths := GetPathsFromListBox( lstWorking );

  if NewPaths = FOriginalPaths then
  begin
    ShowMessage( 'No changes detected.' );
    Exit;
  end;

  if MessageDlg(
       'Apply the working panel arrangement to the registry?' + #13#10 + #13#10 +
       'WARNING: Path order affects unit resolution.' + #13#10 +
       'The first matching unit found wins.' + #13#10 + #13#10 +
       'A backup will be created first.',
       mtConfirmation, [mbYes, mbNo], 0 ) <> mrYes then
    Exit;

  ApplyPaths( NewPaths );
  ShowMessage( 'Library paths have been updated.' );
end;

procedure TFormLibraryPathSorter.btnRestoreClick( Sender: TObject );
var
  Backup: TPathBackup;
  Backups: TArray<TPathBackup>;
  BackupIndex: Integer;
begin
  if LibraryPathSorterPlugin = nil then
    Exit;

  if lvBackups.Selected = nil then
  begin
    ShowMessage( 'Please select a backup to restore.' );
    Exit;
  end;

  Backups := LibraryPathSorterPlugin.BackupManager.GetAllBackups;
  BackupIndex := lvBackups.Selected.Index;

  if ( BackupIndex < 0 ) or ( BackupIndex >= Length( Backups ) ) then
  begin
    ShowMessage( 'Invalid backup selection.' );
    Exit;
  end;

  Backup := Backups[BackupIndex];

  if MessageDlg(
       Format( 'Restore backup from %s?' + #13#10 +
               'Path Type: %s' + #13#10 +
               'Platform: %s' + #13#10 +
               'Description: %s',
               [DateTimeToStr( Backup.Timestamp ),
                Backup.PathType.ToDisplayName,
                Backup.Platform,
                Backup.Description] ),
       mtConfirmation, [mbYes, mbNo], 0 ) <> mrYes then
    Exit;

  if LibraryPathSorterPlugin.BackupManager.RestoreBackup( Backup ) then
  begin
    // Update UI to show the restored path type/platform
    cboPathType.ItemIndex := Ord( Backup.PathType );
    cboPlatform.ItemIndex := cboPlatform.Items.IndexOf( Backup.Platform );

    LoadCurrentPaths;
    UpdateStatus( 'Backup restored successfully' );
    ShowMessage( 'Library paths have been restored from backup.' );
  end
  else
    ShowMessage( 'Failed to restore backup.' );
end;

procedure TFormLibraryPathSorter.btnDeleteBackupClick( Sender: TObject );
var
  Backup: TPathBackup;
  Backups: TArray<TPathBackup>;
  BackupIndex: Integer;
begin
  if LibraryPathSorterPlugin = nil then
    Exit;

  if lvBackups.Selected = nil then
  begin
    ShowMessage( 'Please select a backup to delete.' );
    Exit;
  end;

  Backups := LibraryPathSorterPlugin.BackupManager.GetAllBackups;
  BackupIndex := lvBackups.Selected.Index;

  if ( BackupIndex < 0 ) or ( BackupIndex >= Length( Backups ) ) then
  begin
    ShowMessage( 'Invalid backup selection.' );
    Exit;
  end;

  Backup := Backups[BackupIndex];

  if MessageDlg(
       Format( 'Delete backup from %s?', [DateTimeToStr( Backup.Timestamp )] ),
       mtConfirmation, [mbYes, mbNo], 0 ) <> mrYes then
    Exit;

  if LibraryPathSorterPlugin.BackupManager.DeleteBackup( Backup ) then
  begin
    LoadBackupHistory;
    UpdateStatus( 'Backup deleted' );
  end
  else
    ShowMessage( 'Failed to delete backup.' );
end;

procedure TFormLibraryPathSorter.lvBackupsSelectItem( Sender: TObject;
  Item: TListItem; Selected: Boolean );
begin
  btnRestore.Enabled := ( lvBackups.Selected <> nil );
  btnDeleteBackup.Enabled := ( lvBackups.Selected <> nil );
end;

procedure TFormLibraryPathSorter.LoadFormSettings;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;

    if Reg.OpenKeyReadOnly( 'Software\DDevExtensions\LibraryPathSorter' ) then
    begin
      try
        if Reg.ValueExists( 'Left' ) then
          Left := Reg.ReadInteger( 'Left' );
        if Reg.ValueExists( 'Top' ) then
          Top := Reg.ReadInteger( 'Top' );
        if Reg.ValueExists( 'Width' ) then
          Width := Reg.ReadInteger( 'Width' );
        if Reg.ValueExists( 'Height' ) then
          Height := Reg.ReadInteger( 'Height' );
        if Reg.ValueExists( 'PanelWidth' ) then
          pnlCurrent.Width := Reg.ReadInteger( 'PanelWidth' );

        // Ensure form is visible on screen
        if Left < 0 then Left := 0;
        if Top < 0 then Top := 0;
        if Left + Width > Screen.Width then
          Left := Screen.Width - Width;
        if Top + Height > Screen.Height then
          Top := Screen.Height - Height;

        // Set position to default if we loaded settings
        Position := poDesigned;
      finally
        Reg.CloseKey;
      end;
    end;
  finally
    Reg.Free;
  end;
end;

procedure TFormLibraryPathSorter.SaveFormSettings;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;

    if Reg.OpenKey( 'Software\DDevExtensions\LibraryPathSorter', True ) then
    begin
      try
        Reg.WriteInteger( 'Left', Left );
        Reg.WriteInteger( 'Top', Top );
        Reg.WriteInteger( 'Width', Width );
        Reg.WriteInteger( 'Height', Height );
        Reg.WriteInteger( 'PanelWidth', pnlCurrent.Width );
      finally
        Reg.CloseKey;
      end;
    end;
  finally
    Reg.Free;
  end;
end;

end.
