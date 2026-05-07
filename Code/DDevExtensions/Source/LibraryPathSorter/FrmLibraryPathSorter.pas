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

/// <summary>
/// Hosts the IDE Path Sorter dialog: lets the user view, reorder, deduplicate, sort, validate and
/// apply Library/Browsing/etc. paths per platform, with platform-category filtering and an
/// integrated backup history view.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Types, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Menus, Buttons, Generics.Collections,
  FrmBase, LibraryPathSorter;

type
  /// <summary>
  /// Modeless dialog with two side-by-side panels (Original vs Working) that lets the user safely
  /// edit the IDE's library paths for any installed platform and roll back via the backup history.
  /// </summary>
  TFormLibraryPathSorter = class( TFormBase )
    /// <summary>Top container panel hosting the path-type and platform pickers.</summary>
    pnlTop: TPanel;
    /// <summary>Bottom strip panel hosting Apply/Close/status.</summary>
    pnlBottom: TPanel;
    /// <summary>Main panel hosting the Original/Working split.</summary>
    pnlMain: TPanel;
    /// <summary>Splitter between the main panel and the backups panel.</summary>
    Splitter: TSplitter;
    /// <summary>Container panel for the Original (read-only) paths list.</summary>
    pnlCurrent: TPanel;
    /// <summary>Splitter between the Original and Working panels.</summary>
    SplitterPanels: TSplitter;
    /// <summary>Container panel for the editable Working paths list and its action bar.</summary>
    pnlWorking: TPanel;
    /// <summary>Caption label for cboPathType.</summary>
    lblPathType: TLabel;
    /// <summary>Path-type picker (Library, Browsing, Debug DCU, ...).</summary>
    cboPathType: TComboBox;
    /// <summary>Caption label for cboPlatform.</summary>
    lblPlatform: TLabel;
    /// <summary>Platform picker, filtered by the platform-category checkboxes.</summary>
    cboPlatform: TComboBox;
    /// <summary>Caption label for lstCurrent (updated with item count and legend).</summary>
    lblCurrent: TLabel;
    /// <summary>Read-only list of paths currently stored in the registry.</summary>
    lstCurrent: TListBox;
    /// <summary>Caption label for lstWorking (updated with item count and legend).</summary>
    lblWorking: TLabel;
    /// <summary>Editable working list of paths (drag-and-drop reorderable).</summary>
    lstWorking: TListBox;
    /// <summary>Closes the dialog (warning the user when changes were applied).</summary>
    btnClose: TButton;
    /// <summary>Writes the working list back to the registry (with verification and backup).</summary>
    btnApply: TButton;
    /// <summary>Restores the selected backup snapshot into the registry.</summary>
    btnRestore: TButton;
    /// <summary>Manually creates a backup snapshot of the current registry value.</summary>
    btnBackup: TButton;
    /// <summary>Container panel for the backups history list.</summary>
    pnlBackups: TPanel;
    /// <summary>Caption label for lvBackups.</summary>
    lblBackups: TLabel;
    /// <summary>List view of available backup snapshots.</summary>
    lvBackups: TListView;
    /// <summary>Splitter between the backups list and the panels above.</summary>
    SplitterBackups: TSplitter;
    /// <summary>Deletes the selected backup snapshot.</summary>
    btnDeleteBackup: TButton;
    /// <summary>Status label updated with operation outcomes.</summary>
    lblStatus: TLabel;
    /// <summary>Label that surfaces the count of paths deleted from the working list.</summary>
    lblDeleted: TLabel;
    /// <summary>Static caution label warning the user about path-order side effects.</summary>
    lblCaution: TLabel;
    /// <summary>If checked, an automatic backup is created before each Apply.</summary>
    chkAutoBackup: TCheckBox;
    /// <summary>Strip hosting the working-list reorder/sort/copy speed buttons.</summary>
    pnlWorkingButtons: TPanel;
    /// <summary>Moves the selected working item up by one.</summary>
    btnWorkingUp: TSpeedButton;
    /// <summary>Moves the selected working item down by one.</summary>
    btnWorkingDown: TSpeedButton;
    /// <summary>Moves the selected working item to the top.</summary>
    btnWorkingTop: TSpeedButton;
    /// <summary>Moves the selected working item to the bottom.</summary>
    btnWorkingBottom: TSpeedButton;
    /// <summary>Copies the Original list into the Working list (resetting deletions).</summary>
    btnCopyToWorking: TSpeedButton;
    /// <summary>Alphabetises the Working list (case-insensitive, duplicates preserved).</summary>
    btnSortAlpha: TSpeedButton;
    /// <summary>Popup menu shown for the Working list.</summary>
    pmWorking: TPopupMenu;
    /// <summary>Deletes the selected working list entries (multi-select).</summary>
    mnuDeleteEntry: TMenuItem;
    /// <summary>Popup menu shown for the Original list.</summary>
    pmCurrent: TPopupMenu;
    /// <summary>Reports paths in Original that are not in Working with diff hints.</summary>
    mnuShowMissing: TMenuItem;
    /// <summary>Reports raw vs parsed counts and other diagnostics about the registry value.</summary>
    mnuShowDiagnostic: TMenuItem;
    /// <summary>Strip panel hosting the dynamically created platform-category checkboxes.</summary>
    pnlPlatformFilter: TPanel;
    /// <summary>Caption label for the platform-category filter strip.</summary>
    lblPlatformFilter: TLabel;
    /// <summary>Closes the dialog.</summary>
    procedure btnCloseClick( Sender: TObject );
    /// <summary>Shows raw vs parsed registry counts and other diagnostics.</summary>
    procedure mnuShowDiagnosticClick( Sender: TObject );
    /// <summary>Shows paths from Original that are missing in Working (with diff hints).</summary>
    procedure mnuShowMissingClick( Sender: TObject );
    /// <summary>Deletes the selected working entries after confirmation.</summary>
    procedure mnuDeleteEntryClick( Sender: TObject );
    /// <summary>Validates the working list and writes it back to the registry.</summary>
    procedure btnApplyClick( Sender: TObject );
    /// <summary>Restores the selected backup snapshot into the registry.</summary>
    procedure btnRestoreClick( Sender: TObject );
    /// <summary>Creates a manual backup snapshot of the current registry value.</summary>
    procedure btnBackupClick( Sender: TObject );
    /// <summary>Deletes the selected backup snapshot from the history.</summary>
    procedure btnDeleteBackupClick( Sender: TObject );
    /// <summary>Saves the form layout and frees per-form data when the dialog closes.</summary>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>Initialises form fields, populates the pickers and loads paths.</summary>
    procedure FormCreate( Sender: TObject );
    /// <summary>Reloads the path lists when the path type changes.</summary>
    procedure cboPathTypeChange( Sender: TObject );
    /// <summary>Reloads the path lists when the platform changes.</summary>
    procedure cboPlatformChange( Sender: TObject );
    /// <summary>Updates Restore/Delete button states for the selected backup.</summary>
    procedure lvBackupsSelectItem( Sender: TObject; Item: TListItem; Selected: Boolean );
    /// <summary>Moves the selected working entry up by one position.</summary>
    procedure btnWorkingUpClick( Sender: TObject );
    /// <summary>Moves the selected working entry down by one position.</summary>
    procedure btnWorkingDownClick( Sender: TObject );
    /// <summary>Moves the selected working entry to the top of the list.</summary>
    procedure btnWorkingTopClick( Sender: TObject );
    /// <summary>Moves the selected working entry to the bottom of the list.</summary>
    procedure btnWorkingBottomClick( Sender: TObject );
    /// <summary>Resets the working list to a copy of the original list.</summary>
    procedure btnCopyToWorkingClick( Sender: TObject );
    /// <summary>Alphabetises the working list with safety checks against path loss.</summary>
    procedure btnSortAlphaClick( Sender: TObject );
    /// <summary>Highlights matching items in the original list when working items are selected.</summary>
    procedure lstWorkingClick( Sender: TObject );
    /// <summary>Drag-over handler: only accepts drags originating in the working list.</summary>
    procedure lstWorkingDragOver( Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean );
    /// <summary>Drag-drop handler that reorders the working list to the drop position.</summary>
    procedure lstWorkingDragDrop( Sender, Source: TObject; X, Y: Integer );
    /// <summary>Initiates an internal drag on plain left-click in the working list.</summary>
    procedure lstWorkingMouseDown( Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer );
    /// <summary>Owner-draws working items, colouring duplicates red and invalid paths blue.</summary>
    procedure lstWorkingDrawItem( Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState );
    /// <summary>Owner-draws original items, marking missing-in-working pink and invalid blue.</summary>
    procedure lstCurrentDrawItem( Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState );
  private
    /// <summary>Index of the working item currently being dragged (-1 when idle).</summary>
    FDragIndex: Integer;
    /// <summary>Snapshot of the original registry value used for diffing and backup.</summary>
    FOriginalPaths: string;
    /// <summary>Number of entries explicitly deleted by the user from the working list.</summary>
    FDeletedCount: Integer;
    /// <summary>True once a successful Apply has occurred (drives the close-time prompt).</summary>
    FChangesApplied: Boolean;
    /// <summary>Cache of (lower-cased path) -&gt; validity to keep owner-draw fast.</summary>
    FPathValidityCache: TDictionary<string, Boolean>;
    /// <summary>Full list of installed platforms (used to refill cboPlatform after filtering).</summary>
    FAllPlatforms: TStringList;
    /// <summary>Maps platform category -&gt; list of platforms in that category.</summary>
    FPlatformCategories: TDictionary<string, TStringList>;
    /// <summary>Dynamically created platform-category checkboxes (excluding the "All" one).</summary>
    FPlatformCheckboxes: TList<TCheckBox>;
    /// <summary>Dynamically created "All" checkbox above the category checkboxes.</summary>
    FChkAll: TCheckBox;
    /// <summary>Returns True if the path at Index appears elsewhere in the listbox (case-insensitive).</summary>
    function IsDuplicatePath( AListBox: TListBox; Index: Integer ): Boolean;
    /// <summary>Returns True if APath also appears in the working listbox (trimmed compare).</summary>
    function IsPathInWorkingPanel( const APath: string ): Boolean;
    /// <summary>Returns True if APath resolves to an existing directory (results are cached).</summary>
    function IsPathValid( const APath: string ): Boolean;
    /// <summary>Clears FPathValidityCache (called on platform/path-type change).</summary>
    procedure InvalidatePathCache;
    /// <summary>Expands $(PLATFORM) and $(BDS)-style macros in APath for validity checking.</summary>
    function ExpandPathMacros( const APath: string ): string;
    /// <summary>Updates the panel-header captions with current counts and warning markers.</summary>
    procedure UpdatePanelLabels;
    /// <summary>Populates cboPlatform from the path handler.</summary>
    procedure LoadPlatforms;
    /// <summary>Populates cboPathType with the user-friendly path-type display names.</summary>
    procedure LoadPathTypes;
    /// <summary>Reads the current path value from the registry into both the original and working lists.</summary>
    procedure LoadCurrentPaths;
    /// <summary>Initialises the working list with a sorted copy of the original paths.</summary>
    procedure LoadWorkingPaths;
    /// <summary>Refreshes lvBackups from the backup manager.</summary>
    procedure LoadBackupHistory;
    /// <summary>Sets lblStatus.Caption.</summary>
    procedure UpdateStatus( const AMessage: string );
    /// <summary>Recomputes the enabled state of the working-list and Apply buttons.</summary>
    procedure UpdateButtonStates;
    /// <summary>Returns the path type currently selected in cboPathType.</summary>
    function GetSelectedPathType: TLibraryPathType;
    /// <summary>Returns the platform currently selected in cboPlatform.</summary>
    function GetSelectedPlatform: string;
    /// <summary>Moves the selected listbox item by Delta positions, clamped to the list.</summary>
    procedure MoveListItem( AListBox: TListBox; Delta: Integer );
    /// <summary>Moves the selected listbox item to the top or the bottom.</summary>
    procedure MoveListItemToEnd( AListBox: TListBox; ToTop: Boolean );
    /// <summary>Joins listbox items with semicolons (no quoting; matches Delphi's native format).</summary>
    function GetPathsFromListBox( AListBox: TListBox ): string;
    /// <summary>Writes APaths to the registry, performs a read-back verification and reloads.</summary>
    procedure ApplyPaths( const APaths: string );
    /// <summary>Restores the form geometry and split-pane sizes from the registry.</summary>
    procedure LoadFormSettings;
    /// <summary>Persists the form geometry, split-pane sizes and category-checkbox states.</summary>
    procedure SaveFormSettings;
    /// <summary>Returns the high-level category of APlatform (Windows, Android, iOS, ...).</summary>
    function CategorizePlatform( const APlatform: string ): string;
    /// <summary>(Re)builds the FPlatformCategories dictionary from FAllPlatforms.</summary>
    procedure BuildPlatformCategories;
    /// <summary>Creates the dynamic platform-category checkboxes on pnlPlatformFilter.</summary>
    procedure CreatePlatformCheckboxes;
    /// <summary>OnClick for an individual category checkbox; refilters the platform dropdown.</summary>
    procedure PlatformCheckboxClick( Sender: TObject );
    /// <summary>OnClick for the "All" checkbox; toggles the category checkboxes' enabled state.</summary>
    procedure AllCheckboxClick( Sender: TObject );
    /// <summary>Synchronises the category checkboxes with the "All" checkbox state.</summary>
    procedure UpdateCategoryCheckboxes;
    /// <summary>Refilters cboPlatform to only contain platforms in the checked categories.</summary>
    procedure FilterPlatformDropdown;
  public
    /// <summary>Shows (or activates) the singleton sorter dialog.</summary>
    class procedure Execute;
  end;

/// <summary>Singleton instance of the sorter dialog (nil while not shown).</summary>
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
  FAllPlatforms := TStringList.Create;
  FPlatformCategories := TDictionary<string, TStringList>.Create;
  FPlatformCheckboxes := TList<TCheckBox>.Create;

  // Load saved form position and size
  LoadFormSettings;

  // Enable owner-draw for duplicate highlighting and missing path detection
  lstWorking.Style := lbOwnerDrawFixed;
  lstCurrent.Style := lbOwnerDrawFixed;

  // Enable multi-select on both panels
  lstCurrent.MultiSelect := True;
  lstWorking.MultiSelect := True;

  LoadPathTypes;
  LoadPlatforms;

  // Build platform category checkboxes and apply filter
  BuildPlatformCategories;
  CreatePlatformCheckboxes;
  FilterPlatformDropdown;

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
  FPlatformCheckboxes.Free;

  for var CatList in FPlatformCategories.Values do
    CatList.Free;
  FPlatformCategories.Free;

  FAllPlatforms.Free;
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
  FAllPlatforms.Clear;

  if LibraryPathSorterPlugin = nil then
    Exit;

  Platforms := LibraryPathSorterPlugin.PathHandler.GetAvailablePlatforms;
  try
    FAllPlatforms.Assign( Platforms );
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
  mnuDeleteEntry.Enabled := lstWorking.SelCount > 0;

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
  I, J: Integer;
begin

  UpdateButtonStates;

  // Clear previous selections in original panel
  lstCurrent.ClearSelection;

  // Highlight matching entries in original panel for all selected working items
  for I := 0 to lstWorking.Items.Count - 1 do
  begin
    if lstWorking.Selected[I] then
    begin
      SelectedPath := lstWorking.Items[I];

      for J := 0 to lstCurrent.Items.Count - 1 do
      begin
        if SameText( lstCurrent.Items[J], SelectedPath ) then
          lstCurrent.Selected[J] := True;
      end;
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
    // Only start drag on plain left click; Ctrl/Shift are for multi-select
    if not ( ( ssCtrl in Shift ) or ( ssShift in Shift ) ) then
    begin
      Idx := lstWorking.ItemAtPos( Point( X, Y ), True );
      if Idx >= 0 then
      begin
        FDragIndex := Idx;
        lstWorking.BeginDrag( False, 5 ); // Start drag after 5 pixel movement
      end;
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
  I, DeleteCount: Integer;
  Msg: string;
begin

  if lstWorking.SelCount = 0 then
    Exit;

  if lstWorking.SelCount = 1 then
    Msg := 'Delete this path from working panel?' + #13#10 + #13#10 +
           lstWorking.Items[lstWorking.ItemIndex]
  else
    Msg := Format( 'Delete %d selected paths from working panel?', [lstWorking.SelCount] );

  if MessageDlg( Msg, mtConfirmation, [mbYes, mbNo], 0 ) <> mrYes then
    Exit;

  DeleteCount := 0;
  for I := lstWorking.Items.Count - 1 downto 0 do
  begin
    if lstWorking.Selected[I] then
    begin
      lstWorking.Items.Delete( I );
      Inc( DeleteCount );
    end;
  end;

  Inc( FDeletedCount, DeleteCount );
  lstCurrent.Invalidate;  // Refresh to update missing path highlighting
  UpdatePanelLabels;
  UpdateButtonStates;

  if DeleteCount = 1 then
    UpdateStatus( '1 entry deleted from working panel' )
  else
    UpdateStatus( Format( '%d entries deleted from working panel', [DeleteCount] ) );

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

function TFormLibraryPathSorter.CategorizePlatform( const APlatform: string ): string;
var
  UpperPlatform: string;
begin

  UpperPlatform := AnsiUpperCase( APlatform );

  // ARM check first — catches WinArm64C, OSXARM64, etc.
  if Pos( 'ARM', UpperPlatform ) > 0 then
    Result := 'ARM'
  else if Copy( UpperPlatform, 1, 3 ) = 'WIN' then
    Result := 'Windows'
  else if Copy( UpperPlatform, 1, 7 ) = 'ANDROID' then
    Result := 'Android'
  else if Copy( UpperPlatform, 1, 3 ) = 'IOS' then
    Result := 'iOS'
  else if Copy( UpperPlatform, 1, 3 ) = 'OSX' then
    Result := 'macOS'
  else if Copy( UpperPlatform, 1, 5 ) = 'LINUX' then
    Result := 'Linux'
  else
    Result := 'Other';

end;

procedure TFormLibraryPathSorter.BuildPlatformCategories;
var
  I: Integer;
  Category: string;
  CatList: TStringList;
begin

  // Clear existing categories
  for CatList in FPlatformCategories.Values do
    CatList.Free;
  FPlatformCategories.Clear;

  // Categorise each installed platform
  for I := 0 to FAllPlatforms.Count - 1 do
  begin
    Category := CategorizePlatform( FAllPlatforms[I] );

    if not FPlatformCategories.TryGetValue( Category, CatList ) then
    begin
      CatList := TStringList.Create;
      FPlatformCategories.Add( Category, CatList );
    end;

    CatList.Add( FAllPlatforms[I] );
  end;

end;

procedure TFormLibraryPathSorter.CreatePlatformCheckboxes;
var
  Categories: TStringList;
  Category: string;
  ChkBox: TCheckBox;
  XPos: Integer;
  Reg: TRegistry;
  ValueName: string;
begin

  // Remove any existing dynamic checkboxes
  FreeAndNil( FChkAll );
  for ChkBox in FPlatformCheckboxes do
    ChkBox.Free;
  FPlatformCheckboxes.Clear;

  // Collect and sort category names, with Windows first
  Categories := TStringList.Create;
  try
    for Category in FPlatformCategories.Keys do
    begin
      if Category <> 'Windows' then
        Categories.Add( Category );
    end;
    Categories.Sort;
    if FPlatformCategories.ContainsKey( 'Windows' ) then
      Categories.Insert( 0, 'Windows' );

    // Load saved filter states from registry
    Reg := TRegistry.Create;
    try
      Reg.RootKey := HKEY_CURRENT_USER;
      Reg.OpenKeyReadOnly( 'Software\DDevExtensions\LibraryPathSorter' );

      // Create the "All" checkbox first
      FChkAll := TCheckBox.Create( Self );
      FChkAll.Parent := pnlPlatformFilter;
      FChkAll.Left := 4;
      FChkAll.Top := 3;
      FChkAll.Width := 50;
      FChkAll.Height := 17;
      FChkAll.Caption := 'All';
      FChkAll.Font.Style := [fsBold];

      // Load saved state; default to unchecked
      if ( Reg.CurrentKey <> 0 ) and Reg.ValueExists( 'PlatformFilter_All' ) then
        FChkAll.Checked := ( Reg.ReadInteger( 'PlatformFilter_All' ) <> 0 )
      else
        FChkAll.Checked := False;

      FChkAll.OnClick := AllCheckboxClick;

      // Create category checkboxes after "All"
      XPos := 60;
      for Category in Categories do
      begin
        ChkBox := TCheckBox.Create( Self );
        ChkBox.Parent := pnlPlatformFilter;
        ChkBox.Left := XPos;
        ChkBox.Top := 3;
        ChkBox.Width := 90;
        ChkBox.Height := 17;
        ChkBox.Caption := Category;

        // Load saved state; default to unchecked
        ValueName := 'PlatformFilter_' + Category;
        if ( Reg.CurrentKey <> 0 ) and Reg.ValueExists( ValueName ) then
          ChkBox.Checked := ( Reg.ReadInteger( ValueName ) <> 0 )
        else
          ChkBox.Checked := False;

        ChkBox.OnClick := PlatformCheckboxClick;
        FPlatformCheckboxes.Add( ChkBox );
        XPos := XPos + 100;
      end;

      // If "All" is checked, enable all category checkboxes visually
      UpdateCategoryCheckboxes;

      if Reg.CurrentKey <> 0 then
        Reg.CloseKey;
    finally
      Reg.Free;
    end;
  finally
    Categories.Free;
  end;

end;

procedure TFormLibraryPathSorter.AllCheckboxClick( Sender: TObject );
begin

  UpdateCategoryCheckboxes;
  FilterPlatformDropdown;

end;

procedure TFormLibraryPathSorter.PlatformCheckboxClick( Sender: TObject );
begin

  FilterPlatformDropdown;

end;

procedure TFormLibraryPathSorter.UpdateCategoryCheckboxes;
var
  ChkBox: TCheckBox;
begin

  // When "All" is checked, check and disable all individual checkboxes
  // When "All" is unchecked, enable individual checkboxes for selective filtering
  if FChkAll.Checked then
  begin
    for ChkBox in FPlatformCheckboxes do
    begin
      ChkBox.Checked := True;
      ChkBox.Enabled := False;
    end;
  end
  else
  begin
    for ChkBox in FPlatformCheckboxes do
      ChkBox.Enabled := True;
  end;

end;

procedure TFormLibraryPathSorter.FilterPlatformDropdown;
var
  I: Integer;
  Category, PreviousSelection: string;
  AnyChecked: Boolean;
  ChkBox: TCheckBox;
  CheckedCategories: TStringList;
begin

  // Remember current selection
  PreviousSelection := GetSelectedPlatform;

  // If "All" is checked, show all platforms
  if FChkAll.Checked then
  begin
    cboPlatform.Items.BeginUpdate;
    try
      cboPlatform.Items.Clear;
      for I := 0 to FAllPlatforms.Count - 1 do
        cboPlatform.Items.Add( FAllPlatforms[I] );
    finally
      cboPlatform.Items.EndUpdate;
    end;
  end
  else
  begin
    // Determine which categories are checked
    CheckedCategories := TStringList.Create;
    try
      AnyChecked := False;
      for ChkBox in FPlatformCheckboxes do
      begin
        if ChkBox.Checked then
        begin
          CheckedCategories.Add( ChkBox.Caption );
          AnyChecked := True;
        end;
      end;

      // Rebuild the dropdown
      cboPlatform.Items.BeginUpdate;
      try
        cboPlatform.Items.Clear;

        for I := 0 to FAllPlatforms.Count - 1 do
        begin
          Category := CategorizePlatform( FAllPlatforms[I] );

          // If no checkboxes checked, show all (safety fallback)
          if ( not AnyChecked ) or ( CheckedCategories.IndexOf( Category ) >= 0 ) then
            cboPlatform.Items.Add( FAllPlatforms[I] );
        end;
      finally
        cboPlatform.Items.EndUpdate;
      end;
    finally
      CheckedCategories.Free;
    end;
  end;

  // Try to restore previous selection
  cboPlatform.ItemIndex := cboPlatform.Items.IndexOf( PreviousSelection );
  if ( cboPlatform.ItemIndex < 0 ) and ( cboPlatform.Items.Count > 0 ) then
    cboPlatform.ItemIndex := 0;

  // Reload paths for the (possibly changed) platform selection
  InvalidatePathCache;
  LoadCurrentPaths;

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
        if Reg.ValueExists( 'MainHeight' ) then
          pnlMain.Height := Reg.ReadInteger( 'MainHeight' );
        if Reg.ValueExists( 'BackupsHeight' ) then
          pnlBackups.Height := Reg.ReadInteger( 'BackupsHeight' );

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
  ChkBox: TCheckBox;
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
        Reg.WriteInteger( 'MainHeight', pnlMain.Height );
        Reg.WriteInteger( 'BackupsHeight', pnlBackups.Height );

        // Save platform filter checkbox states
        if FChkAll <> nil then
          Reg.WriteInteger( 'PlatformFilter_All', Ord( FChkAll.Checked ) );
        for ChkBox in FPlatformCheckboxes do
          Reg.WriteInteger( 'PlatformFilter_' + ChkBox.Caption, Ord( ChkBox.Checked ) );
      finally
        Reg.CloseKey;
      end;
    end;
  finally
    Reg.Free;
  end;

end;

end.
