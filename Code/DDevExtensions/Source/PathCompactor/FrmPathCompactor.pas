{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmPathCompactor;

/// <summary>
/// Hosts the IDE Path Compactor dialog: analyses the selected platform ×
/// path-type registry values, proposes <c>$(NAME)</c> macro substitutions for
/// repeated directory prefixes, reports duplicate, missing and undefined-macro
/// entries, and applies the result behind a backup.
/// </summary>
/// <remarks>
/// Nothing is written until Apply, and Apply is refused while the IDE's own
/// Tools ▸ Options dialog is open — that page holds its own in-memory copy of
/// the library path and would write it straight back over anything applied
/// while it was showing.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.CheckLst, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Grids,
  FrmBase, PathCompactorCore, LibraryPathSorter;

type
  /// <summary>
  /// Modeless dialog that analyses the IDE's per-platform library path values and
  /// proposes ways to shorten them: <c>$(NAME)</c> macro substitutions for repeated
  /// directory prefixes, and removal of duplicate, dead-macro and
  /// missing-directory entries.
  /// </summary>
  /// <remarks>
  /// Analysis is read-only and safe to run at any time; nothing is written until
  /// Apply. Every removal is re-verified immediately before it happens and listed
  /// for confirmation, and rollback uses the IDE Path Sorter's backup history.
  /// </remarks>
  TFormPathCompactor = class( TFormBase )
    /// <summary>Top strip hosting the scope pickers, hygiene options and Analyse.</summary>
    pnlScope: TPanel;
    /// <summary>Caption label for clbPlatforms.</summary>
    lblPlatforms: TLabel;
    /// <summary>Platform checklist defining the analysis scope (all ticked by default).</summary>
    clbPlatforms: TCheckListBox;
    /// <summary>Caption label for clbPathTypes.</summary>
    lblPathTypes: TLabel;
    /// <summary>Path-type checklist; Namespace Prefixes is deliberately absent.</summary>
    clbPathTypes: TCheckListBox;
    /// <summary>Group box holding the three cleanup options and the environment-variable option.</summary>
    gbHygiene: TGroupBox;
    /// <summary>Remove entries duplicated within a path set. Opt-in, unticked by default.</summary>
    chkRemoveDuplicates: TCheckBox;
    /// <summary>Remove entries whose directory is absent. Opt-in, unticked by default.</summary>
    chkRemoveMissing: TCheckBox;
    /// <summary>
    /// Remove entries whose macro resolves nowhere. Opt-in, unticked by default.
    /// Never removes a divergent macro, which still resolves in the other IDE bitness.
    /// </summary>
    chkRemoveUndefined: TCheckBox;
    /// <summary>Also define accepted variables in the Windows user environment. Off by default.</summary>
    chkWriteUserEnv: TCheckBox;
    /// <summary>Runs the (read-only) analysis over the selected scope.</summary>
    btnAnalyse: TButton;
    /// <summary>Tab container for the four result views.</summary>
    pgcResults: TPageControl;
    /// <summary>Tab hosting the per-path-set length summary.</summary>
    tabSummary: TTabSheet;
    /// <summary>Stored and expanded lengths before/after, one row per platform and path type.</summary>
    sgSummary: TStringGrid;
    /// <summary>Tab hosting the proposed macro variables.</summary>
    tabVariables: TTabSheet;
    /// <summary>Proposed variables, each tickable; shows name, value, uses and characters saved.</summary>
    lvVariables: TListView;
    /// <summary>Tab hosting the before/after preview.</summary>
    tabPreview: TTabSheet;
    /// <summary>Strip holding the preview path-set selector.</summary>
    pnlPreviewTop: TPanel;
    /// <summary>Selects which platform/path-type pair the preview shows.</summary>
    cboPreviewSet: TComboBox;
    /// <summary>Caption label for cboPreviewSet.</summary>
    lblPreviewSet: TLabel;
    /// <summary>Splitter between the before and after preview panes.</summary>
    splPreview: TSplitter;
    /// <summary>The selected path set exactly as stored now, one entry per line.</summary>
    memBefore: TMemo;
    /// <summary>The same set as it would be written, with removals marked.</summary>
    memAfter: TMemo;
    /// <summary>Bottom strip hosting the status line, hint and buttons.</summary>
    pnlBottom: TPanel;
    /// <summary>Static hint pointing at the shared backup history for rollback.</summary>
    lblHint: TLabel;
    /// <summary>Writes the analysed changes, behind a backup and a confirmation.</summary>
    btnApply: TButton;
    /// <summary>Closes the dialog without writing anything.</summary>
    btnClose: TButton;
    /// <summary>Counts line: sets, characters saved, and each hygiene category.</summary>
    lblStatus: TLabel;
    /// <summary>Creates the registry handler and backup manager, and fills the scope lists.</summary>
    procedure FormCreate( Sender: TObject );
    /// <summary>Frees the analysis, macro table, backup manager and path handler.</summary>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Clears the singleton and frees the form.</summary>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>Runs the analysis over the ticked platforms and path types.</summary>
    procedure btnAnalyseClick( Sender: TObject );
    /// <summary>Re-verifies removals, confirms, then backs up and writes the changes.</summary>
    procedure btnApplyClick( Sender: TObject );
    /// <summary>Closes the dialog.</summary>
    procedure btnCloseClick( Sender: TObject );
    /// <summary>Refreshes the preview panes for the newly selected path set.</summary>
    procedure cboPreviewSetChange( Sender: TObject );
    /// <summary>Refreshes the status line when a proposed variable is ticked or unticked.</summary>
    procedure lvVariablesItemChecked( Sender: TObject; Item: TListItem );
  private
    /// <summary>Registry reader/writer, reused from the Path Sorter.</summary>
    FPathHandler: TLibraryPathHandler;
    /// <summary>Backup history, sharing the Path Sorter's file so one Restore list covers both tools.</summary>
    FBackupManager: TLibraryPathBackupManager;
    /// <summary>The current analysis, or nil before the first Analyse.</summary>
    FAnalysis: TPathCompactorAnalysis;
    /// <summary>Macro table used for the current analysis.</summary>
    FMacros: TStringList;
    /// <summary>True once Apply has written something, so the close hint can mention a restart.</summary>
    FChangesApplied: Boolean;

    /// <summary>Fills the platform and path-type check lists.</summary>
    procedure PopulateScope;
    /// <summary>Path types offered in the dialog. Namespace Prefixes is deliberately absent.</summary>
    function OfferedPathTypes: TArray<TLibraryPathType>;
    /// <summary>Returns the platforms the user has ticked.</summary>
    function SelectedPlatforms: TArray<string>;
    /// <summary>Returns the path types the user has ticked.</summary>
    function SelectedPathTypes: TArray<TLibraryPathType>;

    /// <summary>Rebuilds the summary grid from the current analysis.</summary>
    procedure FillSummary;
    /// <summary>Rebuilds the proposed-variables list from the current analysis.</summary>
    procedure FillVariables;
    /// <summary>Rebuilds the preview set selector.</summary>
    procedure FillPreviewSets;
    /// <summary>Shows the before/after text for the selected preview set.</summary>
    procedure ShowPreview;
    /// <summary>Updates the status line and the enabled state of Apply.</summary>
    procedure UpdateStatus;

    /// <summary>Total expanded length of a set, before rewriting.</summary>
    function ExpandedLengthBefore( APathSet: TPathSet ): Integer;
    /// <summary>Total expanded length of a set, after rewriting.</summary>
    function ExpandedLengthAfter( APathSet: TPathSet ): Integer;
    /// <summary>True when the IDE's own options dialog is currently showing.</summary>
    function IdeOptionsDialogIsOpen: Boolean;
    /// <summary>
    /// Returns the macro names the OTHER IDE bitness defines but this one does
    /// not, so an entry using one is reported as divergent rather than dead and
    /// is never removed by cleanup.
    /// </summary>
    procedure BuildDivergentNames( AList: TStrings );
  public
    /// <summary>Shows the dialog modelessly, reusing the existing instance if there is one.</summary>
    class procedure Execute;
    /// <summary>
    /// Destroys the open dialog, if any. Called when the design-time package is
    /// unloaded: the form is modeless and owned by Application, so it outlives
    /// the plugin, and leaving it standing means its code is unloaded from under
    /// a live window.
    /// </summary>
    class procedure CloseInstance;
  end;

var
  /// <summary>Auto-created singleton declared by the .dfm; not used directly.</summary>
  FormPathCompactor: TFormPathCompactor;

implementation

{$R *.dfm}

uses
  System.StrUtils, System.Math, System.UITypes, System.IOUtils,
  IDEHooks, Main,
  PathCompactor, PathCompactorEnvVars;

const
  /// <summary>Most removals listed individually in the Apply confirmation.</summary>
  MaxDropsListed = 25;

var
  /// <summary>The live dialog instance, or nil when it is not showing.</summary>
  FormPathCompactorInstance: TFormPathCompactor;

class procedure TFormPathCompactor.Execute;
begin
  if FormPathCompactorInstance <> nil then
  begin
    FormPathCompactorInstance.Show;
    FormPathCompactorInstance.BringToFront;
    Exit;
  end;

  // Create into a local first: FormCreate reads the registry and can raise, and
  // the VCL frees the form on a constructor exception — assigning the global
  // only after success avoids leaving a dangling non-nil pointer behind.
  var Instance := TFormPathCompactor.Create( Application );
  FormPathCompactorInstance := Instance;
  FormPathCompactorInstance.Show;
end;

class procedure TFormPathCompactor.CloseInstance;
var
  Instance: TFormPathCompactor;
begin
  // Clear the singleton first: FormClose would otherwise try to clear it again
  // while the form is already being destroyed.
  Instance := FormPathCompactorInstance;
  FormPathCompactorInstance := nil;
  Instance.Free;
end;

procedure TFormPathCompactor.FormCreate( Sender: TObject );
begin
  FPathHandler := TLibraryPathHandler.Create;
  FBackupManager := TLibraryPathBackupManager.Create(
    AppDataDirectory + '\LibraryPathBackups' + DelphiVersion + '.xml' );
  FMacros := TStringList.Create;
  FChangesApplied := False;

  sgSummary.ColCount := 7;
  sgSummary.RowCount := 2;
  sgSummary.FixedRows := 1;
  sgSummary.Cells[0, 0] := 'Platform';
  sgSummary.Cells[1, 0] := 'Path type';
  sgSummary.Cells[2, 0] := 'Stored before';
  sgSummary.Cells[3, 0] := 'Stored after';
  sgSummary.Cells[4, 0] := 'Expanded before';
  sgSummary.Cells[5, 0] := 'Expanded after';
  sgSummary.Cells[6, 0] := 'Saved';
  sgSummary.ColWidths[0] := 90;
  sgSummary.ColWidths[1] := 190;
  sgSummary.ColWidths[2] := 90;
  sgSummary.ColWidths[3] := 90;
  sgSummary.ColWidths[4] := 100;
  sgSummary.ColWidths[5] := 100;
  sgSummary.ColWidths[6] := 70;

  PopulateScope;

  if PathCompactorPlugin <> nil then
    chkWriteUserEnv.Checked := PathCompactorPlugin.WriteUserEnvironment;

  UpdateStatus;
end;

procedure TFormPathCompactor.FormDestroy( Sender: TObject );
begin
  FreeAndNil( FAnalysis );
  FreeAndNil( FMacros );
  FreeAndNil( FBackupManager );
  FreeAndNil( FPathHandler );
end;

procedure TFormPathCompactor.FormClose( Sender: TObject; var Action: TCloseAction );
begin
  FormPathCompactorInstance := nil;
  Action := caFree;
end;

procedure TFormPathCompactor.btnCloseClick( Sender: TObject );
begin
  Close;
end;

function TFormPathCompactor.OfferedPathTypes: TArray<TLibraryPathType>;
begin
  // lptNamespacePrefixes is absent by design: it is a list of unit-scope
  // prefixes, not directories. The core refuses it as well, since the dialog is
  // not its only caller.
  Result := [
    lptSearchPath,
    lptBrowsingPath,
    lptDebugDCUPath,
    lptPackageDCPOutput,
    lptPackageDPLOutput,
    lptHPPOutputDirectory,
    lptTranslatedDebugLibraryPath,
    lptTranslatedLibraryPath,
    lptTranslatedResourcePath
  ];
end;

procedure TFormPathCompactor.PopulateScope;
var
  Platforms: TStringList;
  Types: TArray<TLibraryPathType>;
  I: Integer;
begin
  Platforms := FPathHandler.GetAvailablePlatforms;
  try
    clbPlatforms.Items.Assign( Platforms );
  finally
    Platforms.Free;
  end;

  for I := 0 to clbPlatforms.Items.Count - 1 do
    clbPlatforms.Checked[I] := True;

  Types := OfferedPathTypes;
  clbPathTypes.Items.Clear;
  for I := Low( Types ) to High( Types ) do
  begin
    clbPathTypes.Items.AddObject( Types[I].ToDisplayName, TObject( Ord( Types[I] ) ) );
    // Default to the three that actually feed the compiler.
    clbPathTypes.Checked[I] :=
      Types[I] in [lptSearchPath, lptBrowsingPath, lptDebugDCUPath];
  end;
end;

function TFormPathCompactor.SelectedPlatforms: TArray<string>;
var
  I: Integer;
begin
  SetLength( Result, 0 );
  for I := 0 to clbPlatforms.Items.Count - 1 do
    if clbPlatforms.Checked[I] then
    begin
      SetLength( Result, Length( Result ) + 1 );
      Result[High( Result )] := clbPlatforms.Items[I];
    end;
end;

function TFormPathCompactor.SelectedPathTypes: TArray<TLibraryPathType>;
var
  I: Integer;
begin
  SetLength( Result, 0 );
  for I := 0 to clbPathTypes.Items.Count - 1 do
    if clbPathTypes.Checked[I] then
    begin
      SetLength( Result, Length( Result ) + 1 );
      Result[High( Result )] := TLibraryPathType( Integer( clbPathTypes.Items.Objects[I] ) );
    end;
end;

procedure TFormPathCompactor.BuildDivergentNames( AList: TStrings );
var
  Mine, Theirs: TStringList;
  I: Integer;
begin
  AList.Clear;
  Mine := TStringList.Create;
  Theirs := TStringList.Create;
  try
    Mine.CaseSensitive := False;
    Theirs.CaseSensitive := False;

    // "Mine" is the list this IDE bitness actually reads; "Theirs" is the other.
    {$IFDEF CPUX64}
    ReadIdeVariables( EnvironmentVariablesKey64( FPathHandler.BaseRegistryKey ), Mine );
    ReadIdeVariables( EnvironmentVariablesKey32( FPathHandler.BaseRegistryKey ), Theirs );
    {$ELSE}
    ReadIdeVariables( EnvironmentVariablesKey32( FPathHandler.BaseRegistryKey ), Mine );
    ReadIdeVariables( EnvironmentVariablesKey64( FPathHandler.BaseRegistryKey ), Theirs );
    {$ENDIF}

    for I := 0 to Theirs.Count - 1 do
      if ( Theirs.Names[I] <> '' ) and ( Mine.IndexOfName( Theirs.Names[I] ) < 0 ) then
        AList.Add( Theirs.Names[I] );
  finally
    Theirs.Free;
    Mine.Free;
  end;
end;

procedure TFormPathCompactor.btnAnalyseClick( Sender: TObject );
var
  Platforms: TArray<string>;
  Types: TArray<TLibraryPathType>;
  Reserved: TStringList;
  P, T: Integer;
  Value: string;
begin
  Platforms := SelectedPlatforms;
  Types := SelectedPathTypes;

  if ( Length( Platforms ) = 0 ) or ( Length( Types ) = 0 ) then
  begin
    MessageDlg( 'Select at least one platform and one path type.',
      mtInformation, [mbOK], 0 );
    Exit;
  end;

  Screen.Cursor := crHourGlass;
  try
    FreeAndNil( FAnalysis );
    FAnalysis := TPathCompactorAnalysis.Create;

    // The macro table is built without PLATFORM: entries containing
    // $(Platform) are opaque while BakePlatformMacro is off, so one table
    // serves every platform in scope.
    BuildMacroTable( FMacros, FPathHandler.BaseRegistryKey, '' );
    FAnalysis.SetMacros( FMacros );

    Reserved := TStringList.Create;
    try
      BuildReservedNames( Reserved );
      FAnalysis.SetReservedNames( Reserved );
    finally
      Reserved.Free;
    end;

    Reserved := TStringList.Create;
    try
      BuildDivergentNames( Reserved );
      FAnalysis.SetDivergentNames( Reserved );
    finally
      Reserved.Free;
    end;

    FAnalysis.RemoveDuplicates := chkRemoveDuplicates.Checked;
    FAnalysis.RemoveMissing := chkRemoveMissing.Checked;
    FAnalysis.RemoveUndefinedMacros := chkRemoveUndefined.Checked;

    for P := Low( Platforms ) to High( Platforms ) do
      for T := Low( Types ) to High( Types ) do
      begin
        Value := FPathHandler.ReadPaths( Types[T], Platforms[P] );
        if Trim( Value ) <> '' then
          FAnalysis.AddPathSet( Platforms[P], Types[T], Value );
      end;

    FAnalysis.Analyse;

    FillSummary;
    FillVariables;
    FillPreviewSets;
    ShowPreview;
    UpdateStatus;
  finally
    Screen.Cursor := crDefault;
  end;
end;

function TFormPathCompactor.ExpandedLengthBefore( APathSet: TPathSet ): Integer;
var
  Entries: TArray<TPathEntry>;
  I: Integer;
begin
  Result := 0;
  Entries := APathSet.Entries;
  for I := Low( Entries ) to High( Entries ) do
  begin
    if Entries[I].Expanded <> '' then
      Inc( Result, Length( Entries[I].Expanded ) )
    else
      Inc( Result, Length( Entries[I].Raw ) );
    Inc( Result ); // the separating semicolon
  end;
  if Result > 0 then
    Dec( Result );
end;

function TFormPathCompactor.ExpandedLengthAfter( APathSet: TPathSet ): Integer;
var
  Entries: TArray<TPathEntry>;
  I, J: Integer;
  Expanded: string;
begin
  Result := 0;
  Entries := APathSet.Entries;
  for I := Low( Entries ) to High( Entries ) do
  begin
    if Entries[I].Drop then
      Continue;

    Inc( Result, Length( Expanded ) + 1 );
  end;
  if Result > 0 then
    Dec( Result );
end;

procedure TFormPathCompactor.FillSummary;
var
  I, Row: Integer;
  PathSet: TPathSet;
  Before, After: Integer;
begin
  sgSummary.RowCount := Max( 2, FAnalysis.Sets.Count + 1 );
  for I := 1 to sgSummary.RowCount - 1 do
    for Row := 0 to sgSummary.ColCount - 1 do
      sgSummary.Cells[Row, I] := '';

  for I := 0 to FAnalysis.Sets.Count - 1 do
  begin
    PathSet := FAnalysis.Sets[I];
    Row := I + 1;
    Before := PathSet.OriginalLength;
    After := PathSet.ResultLength;

    sgSummary.Cells[0, Row] := PathSet.PlatformName;
    sgSummary.Cells[1, Row] := PathSet.PathType.ToDisplayName;
    sgSummary.Cells[2, Row] := IntToStr( Before );
    sgSummary.Cells[3, Row] := IntToStr( After );
    sgSummary.Cells[4, Row] := IntToStr( ExpandedLengthBefore( PathSet ) );
    sgSummary.Cells[5, Row] := IntToStr( ExpandedLengthAfter( PathSet ) );
    if Before > 0 then
      sgSummary.Cells[6, Row] := Format( '%.0f%%', [( Before - After ) / Before * 100] )
    else
      sgSummary.Cells[6, Row] := '';
  end;
end;

procedure TFormPathCompactor.FillVariables;
var
  Vars: TArray<TVarCandidate>;
  I: Integer;
  Item: TListItem;
begin
  lvVariables.Items.BeginUpdate;
  try
    lvVariables.Items.Clear;
    Vars := FAnalysis.AcceptedVariables;
    for I := Low( Vars ) to High( Vars ) do
    begin
      Item := lvVariables.Items.Add;
      Item.Caption := '$(' + Vars[I].Name + ')';
      Item.SubItems.Add( Vars[I].Prefix );
      Item.SubItems.Add( IntToStr( Vars[I].Occurrences ) );
      Item.SubItems.Add( IntToStr( Vars[I].NetSaving ) );
      if Vars[I].PreExisting then
        Item.SubItems.Add( 'reuses existing macro' )
      else
        Item.SubItems.Add( 'new variable' );
      Item.Checked := True;
    end;
  finally
    lvVariables.Items.EndUpdate;
  end;
end;

procedure TFormPathCompactor.FillPreviewSets;
var
  I: Integer;
begin
  cboPreviewSet.Items.BeginUpdate;
  try
    cboPreviewSet.Items.Clear;
    for I := 0 to FAnalysis.Sets.Count - 1 do
      cboPreviewSet.Items.Add( FAnalysis.Sets[I].PlatformName + '  /  ' +
        FAnalysis.Sets[I].PathType.ToDisplayName );
  finally
    cboPreviewSet.Items.EndUpdate;
  end;

  if cboPreviewSet.Items.Count > 0 then
    cboPreviewSet.ItemIndex := 0;
end;

procedure TFormPathCompactor.ShowPreview;
var
  PathSet: TPathSet;
  Entries: TArray<TPathEntry>;
  I: Integer;
begin
  memBefore.Lines.BeginUpdate;
  memAfter.Lines.BeginUpdate;
  try
    memBefore.Lines.Clear;
    memAfter.Lines.Clear;

    if ( FAnalysis = nil ) or ( cboPreviewSet.ItemIndex < 0 ) or
       ( cboPreviewSet.ItemIndex >= FAnalysis.Sets.Count ) then
      Exit;

    PathSet := FAnalysis.Sets[cboPreviewSet.ItemIndex];
    Entries := PathSet.Entries;

    for I := Low( Entries ) to High( Entries ) do
    begin
      memBefore.Lines.Add( Entries[I].Raw );

      if Entries[I].Drop then
        memAfter.Lines.Add( '(removed)' )
      else if Entries[I].NewRaw <> '' then
        memAfter.Lines.Add( Entries[I].NewRaw )
      else
        memAfter.Lines.Add( Entries[I].Raw );
    end;
  finally
    memAfter.Lines.EndUpdate;
    memBefore.Lines.EndUpdate;
  end;
end;

procedure TFormPathCompactor.cboPreviewSetChange( Sender: TObject );
begin
  ShowPreview;
end;

procedure TFormPathCompactor.lvVariablesItemChecked( Sender: TObject; Item: TListItem );
begin
  UpdateStatus;
end;

procedure TFormPathCompactor.UpdateStatus;
var
  Saved: Integer;
begin
  if FAnalysis = nil then
  begin
    lblStatus.Caption := 'Press Analyse. Nothing is written until you press Apply.';
    btnApply.Enabled := False;
    Exit;
  end;

  Saved := FAnalysis.TotalStoredBefore - FAnalysis.TotalStoredAfter;
  lblStatus.Caption := Format(
    '%d path sets  ·  %d stored characters saved  ·  %d duplicates  ·  ' +
    '%d missing directories  ·  %d dead macros  ·  %d divergent macros  ·  %d to remove',
    [FAnalysis.Sets.Count, Saved, FAnalysis.DuplicateCount, FAnalysis.MissingCount,
     FAnalysis.UndefinedMacroCount, FAnalysis.DivergentMacroCount, FAnalysis.DropCount] );

  btnApply.Enabled := ( FAnalysis.Sets.Count > 0 ) and
    ( ( Saved > 0 ) or ( FAnalysis.DropCount > 0 ) );
end;

function TFormPathCompactor.IdeOptionsDialogIsOpen: Boolean;
var
  I: Integer;
begin
  Result := False;
  // The options page holds its own in-memory copy of the library path, so
  // committing it would write that copy straight over anything applied here.
  for I := 0 to Screen.FormCount - 1 do
    if Screen.Forms[I].Visible and
       ( ContainsText( Screen.Forms[I].ClassName, 'OptionsDialog' ) or
         ContainsText( Screen.Forms[I].Caption, 'Options' ) ) and
       ( Screen.Forms[I] <> Self ) then
      Exit( True );
end;

procedure TFormPathCompactor.btnApplyClick( Sender: TObject );
var
  I: Integer;
  Vars: TArray<TVarCandidate>;
  PathSet: TPathSet;
  Description, Error, DropList, Generic: string;
  Rescued, SetCount: Integer;
  Drops: TArray<string>;
begin
  if FAnalysis = nil then
    Exit;

  if IdeOptionsDialogIsOpen then
  begin
    MessageDlg(
      'The IDE''s Options dialog appears to be open. Close it before applying — ' +
      'it holds its own copy of the library path and would overwrite these ' +
      'changes when committed.', mtWarning, [mbOK], 0 );
    Exit;
  end;

  // Double-check every intended removal against reality as it stands NOW. The
  // analysis may be minutes old; a share can reconnect or an installer finish in
  // between, and nothing should be deleted on the strength of a stale probe.
  Rescued := FAnalysis.RevalidateDrops;
  if Rescued > 0 then
  begin
    FillSummary;
    ShowPreview;
    UpdateStatus;
    MessageDlg( Format(
      '%d entry(s) marked for removal have been re-checked and are now valid ' +
      '- their directory exists, or their macro resolves. They will be KEPT.' +
      #13#10#13#10 +
      'The remaining counts have been updated.', [Rescued] ),
      mtInformation, [mbOK], 0 );
  end;

  // Names that are fine inside the IDE's own variable list can be a poor idea
  // once every process on the machine inherits them.
  if chkWriteUserEnv.Checked then
  begin
    Generic := '';
    Vars := FAnalysis.AcceptedVariables;
    for I := Low( Vars ) to High( Vars ) do
      if not Vars[I].PreExisting and IsGenericVariableName( Vars[I].Name ) then
        Generic := Generic + #13#10 + '    ' + Vars[I].Name + '  =  ' + Vars[I].Prefix;

    if Generic <> '' then
      if MessageDlg(
           'These variables have very common names, and you have asked for them to be ' +
           'defined as Windows user environment variables:' + #13#10 + Generic +
           #13#10#13#10 +
           'Every process you launch would inherit them, so a name like SRC or COMMON ' +
           'can collide with build scripts, makefiles and installers - and such a ' +
           'collision is hard to trace back here.' + #13#10#13#10 +
           'They are harmless inside the IDE''s own variable list, which is written ' +
           'either way. Continue and write them to the Windows environment as well?',
           mtWarning, [mbYes, mbNo], 0 ) <> mrYes then
      begin
        chkWriteUserEnv.Checked := False;
        MessageDlg( 'The Windows environment option has been unticked. The IDE ' +
          'variables are unaffected; press Apply again to continue.',
          mtInformation, [mbOK], 0 );
        Exit;
      end;
  end;

  // Show exactly what will be deleted, in full, before deleting any of it.
  Drops := FAnalysis.DropSummary;
  if Length( Drops ) > 0 then
  begin
    DropList := '';
    for I := Low( Drops ) to High( Drops ) do
    begin
      if I = MaxDropsListed then
      begin
        DropList := DropList + #13#10 + Format( '... and %d more',
          [Length( Drops ) - MaxDropsListed] );
        Break;
      end;
      DropList := DropList + #13#10 + Drops[I];
    end;

    if MessageDlg( Format(
         'These %d entry(s) will be REMOVED from the library path:' + #13#10 +
         '%s' + #13#10#13#10 + 'Remove them?',
         [Length( Drops ), DropList] ), mtWarning, [mbYes, mbNo], 0 ) <> mrYes then
      Exit;
  end;

  if MessageDlg( Format(
       'Apply the compaction to %d path sets?'#13#10#13#10 +
       'Every affected value is backed up first, and the backup history is ' +
       'shared with the IDE Path Sorter. An IDE restart is required afterwards.',
       [FAnalysis.Sets.Count] ), mtConfirmation, [mbYes, mbNo], 0 ) <> mrYes then
    Exit;

  Screen.Cursor := crHourGlass;
  try
    // 1. Back up every value the compaction touches, before anything is written.
    Description := 'Before compaction ' + FormatDateTime( 'yyyy-mm-dd hh:nn', Now );
    for I := 0 to FAnalysis.Sets.Count - 1 do
    begin
      PathSet := FAnalysis.Sets[I];
      FBackupManager.CreateBackup( PathSet.PathType, PathSet.PlatformName,
        PathSet.Original, Description );
    end;

    // 3. Variables, into BOTH IDE lists (the path they resolve is shared).
    Vars := FAnalysis.AcceptedVariables;
    for I := Low( Vars ) to High( Vars ) do
    begin
      if Vars[I].PreExisting then
        Continue; // reuses an existing macro; nothing to define

      if ( I < lvVariables.Items.Count ) and not lvVariables.Items[I].Checked then
        Continue;

      WriteVariable( FPathHandler.BaseRegistryKey, Vars[I].Name, Vars[I].Prefix,
        chkWriteUserEnv.Checked );

      if PathCompactorPlugin <> nil then
        PathCompactorPlugin.RecordCreatedVariable( Vars[I].Name );
    end;

    // 4. The paths themselves.
    for I := 0 to FAnalysis.Sets.Count - 1 do
    begin
      PathSet := FAnalysis.Sets[I];
      FPathHandler.WritePaths( PathSet.PathType, PathSet.PlatformName,
        PathSet.BuildResult );
    end;

    if chkWriteUserEnv.Checked then
      BroadcastEnvironmentChange;

    if PathCompactorPlugin <> nil then
    begin
      PathCompactorPlugin.WriteUserEnvironment := chkWriteUserEnv.Checked;
      PathCompactorPlugin.Save;
    end;

    FChangesApplied := True;
  finally
    Screen.Cursor := crDefault;
  end;

  SetCount := FAnalysis.Sets.Count;

  MessageDlg( Format(
    'Compaction applied.'#13#10#13#10 +
    '%d path sets rewritten.'#13#10#13#10 +
    'Restart the IDE for the new library paths and variables to take effect.'#13#10#13#10 +
    'The results below have been refreshed against the registry as it now ' +
    'stands, so they no longer describe the change you just applied.',
    [SetCount] ), mtInformation, [mbOK], 0 );

  // Re-analyse rather than just disabling Apply. Leaving the pre-Apply figures
  // on screen invites the reader to believe they still describe the registry,
  // and makes the greyed-out Apply look like a fault rather than a completed
  // action. A fresh pass shows what (if anything) is still worth doing.
  btnAnalyseClick( Sender );
end;

end.
