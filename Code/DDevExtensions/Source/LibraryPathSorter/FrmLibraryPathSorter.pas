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
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Menus, Buttons, Generics.Collections,
  FrmBase, LibraryPathSorter;

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
    mnuShowDiagnostic: TMenuItem;
    procedure btnCloseClick( Sender: TObject );
    procedure mnuShowDiagnosticClick( Sender: TObject );
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
    FChangesApplied: Boolean;
    FPathValidityCache: TDictionary<string, Boolean>;
    function IsDuplicatePath( AListBox: TListBox; Index: Integer ): Boolean;
    function IsPathInWorkingPanel( const APath: string ): Boolean;
    function IsPathValid( const APath: string ): Boolean;
    procedure InvalidatePathCache;
    function ExpandPathMacros( const APath: string ): string;
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
  FChangesApplied := False;
  FPathValidityCache := TDictionary<string, Boolean>.Create;

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

  // Remind user to restart Delphi if changes were applied
  if FChangesApplied then
    ShowMessage( 'Library paths have been updated.' + #13#10 + #13#10 +
      'For the changes to take effect, you must close and reopen Delphi.' );

  FPathValidityCache.Free;
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
  InvalidatePathCache;

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
  OriginalCount: Integer;
begin
  lstWorking.Items.Clear;

  if ( LibraryPathSorterPlugin = nil ) or ( FOriginalPaths = '' ) then
    Exit;

  OriginalCount := lstCurrent.Items.Count;

  try
    // Start with alphabetically sorted paths in the working panel
    SortedPaths := LibraryPathSorterPlugin.PathHandler.SortPaths( FOriginalPaths, True );

    PathList := TStringList.Create;
    try
      SplitPaths( PathList, SortedPaths, False );

      // Verify no paths were lost during sort
      if PathList.Count <> OriginalCount then
      begin
        // Sort lost paths - fall back to unsorted copy
        UpdateStatus( Format( 'WARNING: Sort lost paths (%d -> %d). Using unsorted copy.',
          [OriginalCount, PathList.Count] ) );
        lstWorking.Items.Assign( lstCurrent.Items );
      end
      else
      begin
        lstWorking.Items.Assign( PathList );
      end;
    finally
      PathList.Free;
    end;
  except
    on E: Exception do
    begin
      // On any error, fall back to unsorted copy
      UpdateStatus( 'Error sorting paths: ' + E.Message );
      lstWorking.Items.Assign( lstCurrent.Items );
    end;
  end;

  // Refresh original panel to update missing path highlighting
  lstCurrent.Invalidate;

  // Final check for count mismatch (should not happen now)
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
var
  I: Integer;
begin
  // Delphi's native format does NOT use quotes - just semicolon-separated paths
  Result := '';
  for I := 0 to AListBox.Items.Count - 1 do
  begin
    if I = 0 then
      Result := AListBox.Items[I]
    else
      Result := Result + ';' + AListBox.Items[I];
  end;
end;

procedure TFormLibraryPathSorter.ApplyPaths( const APaths: string );
var
  VerifyPaths: string;
  OriginalSemicolons, NewSemicolons, VerifySemicolons, I: Integer;
begin
  if LibraryPathSorterPlugin = nil then
    Exit;

  // Count semicolons in what we're about to write
  NewSemicolons := 0;
  for I := 1 to Length( APaths ) do
    if APaths[I] = ';' then
      Inc( NewSemicolons );

  // Count semicolons in original
  OriginalSemicolons := 0;
  for I := 1 to Length( FOriginalPaths ) do
    if FOriginalPaths[I] = ';' then
      Inc( OriginalSemicolons );

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

  // VERIFY: Read back and compare
  VerifyPaths := LibraryPathSorterPlugin.PathHandler.ReadPaths(
    GetSelectedPathType, GetSelectedPlatform );

  VerifySemicolons := 0;
  for I := 1 to Length( VerifyPaths ) do
    if VerifyPaths[I] = ';' then
      Inc( VerifySemicolons );

  // Check for data loss
  if VerifySemicolons <> NewSemicolons then
  begin
    ShowMessage( Format(
      'WARNING: Registry verification failed!' + #13#10#13#10 +
      'Original paths: %d (semicolons: %d)' + #13#10 +
      'Attempted to write: %d paths (semicolons: %d)' + #13#10 +
      'Registry now contains: %d paths (semicolons: %d)' + #13#10#13#10 +
      'DATA MAY HAVE BEEN LOST! Check your backup.',
      [OriginalSemicolons + 1, OriginalSemicolons,
       NewSemicolons + 1, NewSemicolons,
       VerifySemicolons + 1, VerifySemicolons] ) );
  end;

  // Reload
  LoadCurrentPaths;
  LoadBackupHistory;

  FChangesApplied := True;
  UpdateStatus( 'Paths saved successfully' );
end;

procedure TFormLibraryPathSorter.cboPathTypeChange( Sender: TObject );
begin
  InvalidatePathCache;
  LoadCurrentPaths;
end;

procedure TFormLibraryPathSorter.cboPlatformChange( Sender: TObject );
begin
  InvalidatePathCache;
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

  CurrentPath := Trim( AListBox.Items[Index] );

  // Check if this path appears elsewhere in the list (case-insensitive, trimmed)
  for I := 0 to AListBox.Items.Count - 1 do
  begin
    if ( I <> Index ) and SameText( Trim( AListBox.Items[I] ), CurrentPath ) then
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
  IsDuplicate, IsInvalid: Boolean;
begin
  if not ( Control is TListBox ) then
    Exit;

  ListBox := TListBox( Control );

  // Safety checks
  if ( Index < 0 ) or ( Index >= ListBox.Items.Count ) then
    Exit;
  if not ListBox.HandleAllocated then
    Exit;

  try
    ItemText := ListBox.Items[Index];
    IsDuplicate := IsDuplicatePath( ListBox, Index );
    IsInvalid := not IsPathValid( ItemText );

    // Set background
    if odSelected in State then
      ListBox.Canvas.Brush.Color := clHighlight
    else
      ListBox.Canvas.Brush.Color := clWindow;

    ListBox.Canvas.FillRect( Rect );

    // Set text color (Invalid takes priority)
    if odSelected in State then
      ListBox.Canvas.Font.Color := clHighlightText
    else if IsInvalid then
      ListBox.Canvas.Font.Color := clBlue
    else if IsDuplicate then
      ListBox.Canvas.Font.Color := clRed
    else
      ListBox.Canvas.Font.Color := clWindowText;

    // Make duplicates or invalid paths bold
    if IsDuplicate or IsInvalid then
      ListBox.Canvas.Font.Style := [fsBold]
    else
      ListBox.Canvas.Font.Style := [];

    // Draw the text
    ListBox.Canvas.TextOut( Rect.Left + 2, Rect.Top + 1, ItemText );

    // Draw focus rectangle if focused
    if odFocused in State then
      ListBox.Canvas.DrawFocusRect( Rect );
  except
    // Silently ignore drawing errors to prevent cascading failures
  end;
end;

function TFormLibraryPathSorter.IsPathInWorkingPanel( const APath: string ): Boolean;
var
  I: Integer;
  TrimmedPath: string;
begin
  Result := False;
  TrimmedPath := Trim( APath );

  for I := 0 to lstWorking.Items.Count - 1 do
  begin
    // Compare trimmed versions to handle any whitespace differences
    if SameText( Trim( lstWorking.Items[I] ), TrimmedPath ) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TFormLibraryPathSorter.ExpandPathMacros( const APath: string ): string;
var
  SelectedPlatform: string;
begin
  Result := APath;

  // Expand $(PLATFORM) using the combo box selection
  if cboPlatform.ItemIndex >= 0 then
  begin
    SelectedPlatform := cboPlatform.Items[cboPlatform.ItemIndex];
    Result := StringReplace( Result, '$(PLATFORM)', SelectedPlatform, [rfReplaceAll, rfIgnoreCase] );
  end;

  // Delegate to IDEUtils for all other macros ($(BDS), $(BDSCOMMONDIR), env vars, etc.)
  Result := IDEUtils.ExpandDirMacros( Result );
end;

function TFormLibraryPathSorter.IsPathValid( const APath: string ): Boolean;
var
  TrimmedPath, LowerPath, ExpandedPath: string;
begin
  TrimmedPath := Trim( APath );

  // Empty paths are invalid
  if TrimmedPath = '' then
  begin
    Result := False;
    Exit;
  end;

  // Check cache (case-insensitive key)
  LowerPath := AnsiLowerCase( TrimmedPath );
  if FPathValidityCache.TryGetValue( LowerPath, Result ) then
    Exit;

  // Expand macros
  ExpandedPath := ExpandPathMacros( TrimmedPath );

  // If unexpanded macros remain, treat as valid (can't verify)
  if Pos( '$(', ExpandedPath ) > 0 then
  begin
    Result := True;
    FPathValidityCache.Add( LowerPath, Result );
    Exit;
  end;

  // Check if directory exists
  Result := DirectoryExists( ExpandedPath );

  // Cache the result
  FPathValidityCache.Add( LowerPath, Result );
end;

procedure TFormLibraryPathSorter.InvalidatePathCache;
begin
  FPathValidityCache.Clear;
end;

procedure TFormLibraryPathSorter.UpdatePanelLabels;
var
  Difference: Integer;
begin
  lblCurrent.Caption := Format( '  Original Paths (Pink = not in Working, Blue = invalid): %d',
    [lstCurrent.Items.Count] );
  lblWorking.Caption := Format( '  Working Panel (Red = duplicate, Blue = invalid): %d',
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
  IsMissing, IsInvalid: Boolean;
begin
  if not ( Control is TListBox ) then
    Exit;

  ListBox := TListBox( Control );

  // Safety checks
  if ( Index < 0 ) or ( Index >= ListBox.Items.Count ) then
    Exit;
  if not ListBox.HandleAllocated then
    Exit;

  try
    ItemText := ListBox.Items[Index];
    IsMissing := not IsPathInWorkingPanel( ItemText );
    IsInvalid := not IsPathValid( ItemText );

    // Set background (pink preserved for missing regardless of validity)
    if odSelected in State then
      ListBox.Canvas.Brush.Color := clHighlight
    else if IsMissing then
      ListBox.Canvas.Brush.Color := $CCCCFF  // Light red/pink background for missing
    else
      ListBox.Canvas.Brush.Color := clWindow;

    ListBox.Canvas.FillRect( Rect );

    // Set text color (Invalid takes priority)
    if odSelected in State then
      ListBox.Canvas.Font.Color := clHighlightText
    else if IsInvalid then
      ListBox.Canvas.Font.Color := clBlue
    else if IsMissing then
      ListBox.Canvas.Font.Color := clMaroon
    else
      ListBox.Canvas.Font.Color := clWindowText;

    // Make missing or invalid items bold
    if IsMissing or IsInvalid then
      ListBox.Canvas.Font.Style := [fsBold]
    else
      ListBox.Canvas.Font.Style := [];

    // Draw the text
    ListBox.Canvas.TextOut( Rect.Left + 2, Rect.Top + 1, ItemText );

    // Draw focus rectangle if focused
    if odFocused in State then
      ListBox.Canvas.DrawFocusRect( Rect );
  except
    // Silently ignore drawing errors to prevent cascading failures
  end;
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
  BackupItems: TStringList;
begin
  if lstWorking.Items.Count = 0 then
    Exit;

  OriginalCount := lstWorking.Items.Count;

  // Keep a backup of items in case sort fails
  BackupItems := TStringList.Create;
  try
    BackupItems.Assign( lstWorking.Items );

    try
      SortedPaths := LibraryPathSorterPlugin.PathHandler.SortPaths(
        GetPathsFromListBox( lstWorking ), True );

      PathList := TStringList.Create;
      try
        SplitPaths( PathList, SortedPaths, False );

        // Verify no paths were lost
        if PathList.Count <> OriginalCount then
        begin
          // Restore from backup and show error
          lstWorking.Items.Assign( BackupItems );
          ShowMessage( Format(
            'ERROR: Sort would have lost %d paths!' + #13#10 +
            'Original: %d, After sort: %d' + #13#10 + #13#10 +
            'Sort has been cancelled and working panel restored.',
            [OriginalCount - PathList.Count, OriginalCount, PathList.Count] ) );
          Exit;
        end;

        lstWorking.Items.Assign( PathList );
      finally
        PathList.Free;
      end;
    except
      on E: Exception do
      begin
        // Restore from backup on any error
        lstWorking.Items.Assign( BackupItems );
        ShowMessage( 'Error during sort: ' + E.Message + #13#10 +
          'Working panel has been restored.' );
        Exit;
      end;
    end;
  finally
    BackupItems.Free;
  end;

  lstCurrent.Invalidate;  // Refresh to update missing path highlighting
  UpdatePanelLabels;
  UpdateButtonStates;
  UpdateStatus( 'Working panel sorted alphabetically' );
end;

procedure TFormLibraryPathSorter.btnCloseClick( Sender: TObject );
begin
  Close;
end;

procedure TFormLibraryPathSorter.mnuDeleteEntryClick( Sender: TObject );
var
  PathToDelete: string;
begin
  if lstWorking.ItemIndex >= 0 then
  begin
    PathToDelete := lstWorking.Items[lstWorking.ItemIndex];

    if MessageDlg(
         'Delete this path from working panel?' + #13#10 + #13#10 +
         PathToDelete,
         mtConfirmation, [mbYes, mbNo], 0 ) <> mrYes then
      Exit;

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
  I, J: Integer;
  MissingPaths: TStringList;
  OrigPath, WorkPath: string;
  Msg, DetailMsg: string;
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
        OrigPath := MissingPaths[I];
        Msg := Msg + OrigPath + #13#10;

        // Try to find a close match to explain why it doesn't match
        for J := 0 to lstWorking.Items.Count - 1 do
        begin
          WorkPath := lstWorking.Items[J];
          // Check if paths differ only by whitespace
          if SameText( Trim( OrigPath ), Trim( WorkPath ) ) and
             not SameText( OrigPath, WorkPath ) then
          begin
            Msg := Msg + '  ^ Has whitespace difference with: ' + WorkPath + #13#10;
            Break;
          end;
          // Check if paths differ only in length (possible truncation)
          if ( Length( OrigPath ) > 5 ) and ( Length( WorkPath ) > 5 ) and
             ( Copy( OrigPath, 1, Length( WorkPath ) ) = WorkPath ) then
          begin
            Msg := Msg + '  ^ Partial match (truncated?): ' + WorkPath + #13#10;
            Break;
          end;
        end;

        if I >= 9 then  // Limit display to 10 items with details
        begin
          Msg := Msg + Format( '... and %d more', [MissingPaths.Count - 10] );
          Break;
        end;
      end;

      // Add summary information
      DetailMsg := #13#10#13#10 + 'DEBUG INFO:' + #13#10 +
        Format( 'Original panel: %d items', [lstCurrent.Items.Count] ) + #13#10 +
        Format( 'Working panel: %d items', [lstWorking.Items.Count] ) + #13#10 +
        Format( 'Missing count: %d', [MissingPaths.Count] );

      ShowMessage( Msg + DetailMsg );
    end;
  finally
    MissingPaths.Free;
  end;
end;

procedure TFormLibraryPathSorter.mnuShowDiagnosticClick( Sender: TObject );
var
  RawPaths: string;
  ParsedList: TStringList;
  SemicolonCount, I, MissingCount: Integer;
  Msg: string;
begin
  if LibraryPathSorterPlugin = nil then
    Exit;

  // Read raw registry value
  RawPaths := LibraryPathSorterPlugin.PathHandler.ReadPaths(
    GetSelectedPathType, GetSelectedPlatform );

  // Count semicolons in raw string
  SemicolonCount := 0;
  for I := 1 to Length( RawPaths ) do
    if RawPaths[I] = ';' then
      Inc( SemicolonCount );

  // Count missing paths
  MissingCount := 0;
  for I := 0 to lstCurrent.Items.Count - 1 do
    if not IsPathInWorkingPanel( lstCurrent.Items[I] ) then
      Inc( MissingCount );

  // Parse paths
  ParsedList := TStringList.Create;
  try
    SplitPaths( ParsedList, RawPaths, False );

    Msg := 'DIAGNOSTIC INFO' + #13#10 +
           '===============' + #13#10#13#10 +
           Format( 'Raw registry string length: %d chars', [Length( RawPaths )] ) + #13#10 +
           Format( 'Semicolons in raw string: %d', [SemicolonCount] ) + #13#10 +
           Format( 'Expected path count: %d', [SemicolonCount + 1] ) + #13#10 +
           Format( 'Parsed path count: %d', [ParsedList.Count] ) + #13#10 +
           Format( 'Original panel count: %d', [lstCurrent.Items.Count] ) + #13#10 +
           Format( 'Working panel count: %d', [lstWorking.Items.Count] ) + #13#10 +
           Format( 'Paths in Original not in Working: %d', [MissingCount] ) + #13#10#13#10;

    if ParsedList.Count <> lstCurrent.Items.Count then
      Msg := Msg + 'WARNING: Parsed count differs from Original panel!' + #13#10;

    if lstWorking.Items.Count <> lstCurrent.Items.Count then
      Msg := Msg + Format( 'WARNING: Working panel has %d fewer paths!',
        [lstCurrent.Items.Count - lstWorking.Items.Count] ) + #13#10;

    if MissingCount > 0 then
      Msg := Msg + Format( 'WARNING: %d paths in Original are not matched in Working!', [MissingCount] ) + #13#10 +
             '(Use "Show Missing Paths" for details)' + #13#10;

    // Show first few and last few chars of raw string
    Msg := Msg + #13#10 + 'Raw string preview:' + #13#10;
    if Length( RawPaths ) > 200 then
      Msg := Msg + Copy( RawPaths, 1, 100 ) + #13#10 + '...' + #13#10 +
             Copy( RawPaths, Length( RawPaths ) - 99, 100 )
    else
      Msg := Msg + RawPaths;

    ShowMessage( Msg );
  finally
    ParsedList.Free;
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
  OriginalCount, WorkingCount, Difference: Integer;
  WarningMsg: string;
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

  // Safety check: verify path counts
  OriginalCount := lstCurrent.Items.Count;
  WorkingCount := lstWorking.Items.Count;
  Difference := OriginalCount - WorkingCount;

  WarningMsg := 'Apply the working panel arrangement to the registry?' + #13#10 + #13#10 +
       'WARNING: Path order affects unit resolution.' + #13#10 +
       'The first matching unit found wins.' + #13#10 + #13#10 +
       'A backup will be created first.';

  // Add extra warning if paths are being lost
  if Difference > 0 then
  begin
    if Difference <> FDeletedCount then
    begin
      // Paths disappeared without being explicitly deleted - this is dangerous!
      if MessageDlg(
           Format( 'CRITICAL WARNING!' + #13#10 + #13#10 +
                   'The working panel has %d fewer paths than the original.' + #13#10 +
                   'Only %d paths were explicitly deleted.' + #13#10 +
                   '%d paths may have been LOST!' + #13#10 + #13#10 +
                   'It is STRONGLY recommended to click "Copy from Original" ' +
                   'to restore all paths before applying.' + #13#10 + #13#10 +
                   'Do you REALLY want to continue anyway?',
                   [Difference, FDeletedCount, Difference - FDeletedCount] ),
           mtError, [mbYes, mbNo], 0 ) <> mrYes then
        Exit;
    end
    else
    begin
      // User explicitly deleted these paths
      WarningMsg := Format( 'Apply the working panel arrangement to the registry?' + #13#10 + #13#10 +
           'You have deleted %d path(s).' + #13#10 +
           'Original: %d paths, Working: %d paths' + #13#10 + #13#10 +
           'WARNING: Path order affects unit resolution.' + #13#10 +
           'The first matching unit found wins.' + #13#10 + #13#10 +
           'A backup will be created first.',
           [Difference, OriginalCount, WorkingCount] );
    end;
  end;

  if MessageDlg( WarningMsg, mtConfirmation, [mbYes, mbNo], 0 ) <> mrYes then
    Exit;

  // Show what we're about to write
  ShowMessage( Format(
    'About to write %d paths to registry.' + #13#10 +
    'String length: %d characters' + #13#10#13#10 +
    'Click OK to proceed.',
    [lstWorking.Items.Count, Length( NewPaths )] ) );

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
