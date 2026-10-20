{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmDecirculariser;

/// <summary>
/// Non-modal main form of the Decirculariser plugin.  Scans the active project and lists its
/// entangled unit groups, most dangerous first; for the selected group it lists the edges
/// that could be cut, cheapest first, with what holds each one in place, and deletes the dead
/// ones on request.
/// </summary>
/// <remarks>
/// Only a dead entry to a unit without start-up code ( <c>CanAutoRemove</c> ) is ever deleted,
/// and only after a fresh analysis of the current editor buffers confirms it is still dead.
/// Every other verdict is advice: those are design decisions, not edits a tool should make.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls,
  Vcl.Menus, Vcl.Clipbrd, FrmBase, DecirculariserCore;

type
  /// <summary>Main form of the Decirculariser plugin.</summary>
  TFormDecirculariser = class( TFormBase )
    /// <summary>Top toolbar panel.</summary>
    pnlTop: TPanel;
    /// <summary>Scans the active project.</summary>
    btnScan: TButton;
    /// <summary>Progress during a scan, then the summary of its result.</summary>
    lblSummary: TLabel;
    /// <summary>The entangled groups, most dangerous first.</summary>
    lvGroups: TListView;
    /// <summary>Resizes the group list against the edge list.</summary>
    Splitter: TSplitter;
    /// <summary>The cuttable edges of the selected group, cheapest first.</summary>
    lvCandidates: TListView;
    /// <summary>Advice and crossing identifiers for the selected edge.</summary>
    memoDetails: TMemo;
    /// <summary>Bottom button panel.</summary>
    pnlBottom: TPanel;
    /// <summary>Deletes the selected dead entries.</summary>
    btnRemove: TButton;
    /// <summary>Copies the plain-text report to the clipboard.</summary>
    btnCopyReport: TButton;
    /// <summary>Closes the form.</summary>
    btnClose: TButton;
    /// <summary>Context menu for the edge list.</summary>
    PopupMenu: TPopupMenu;
    /// <summary>Menu item: open the source file at the uses entry.</summary>
    mnuOpenFile: TMenuItem;
    /// <summary>Separator menu item.</summary>
    N1: TMenuItem;
    /// <summary>Menu item: copy the selected (or all) edges to the clipboard as TSV.</summary>
    mnuCopyToClipboard: TMenuItem;
    /// <summary>Scans the active project and lists the result.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnScanClick( Sender: TObject );
    /// <summary>Deletes the selected dead entries after confirming them against a fresh analysis.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnRemoveClick( Sender: TObject );
    /// <summary>Copies the plain-text report to the clipboard.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnCopyReportClick( Sender: TObject );
    /// <summary>Closes the form.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnCloseClick( Sender: TObject );
    /// <summary>Releases the singleton instance and frees the form, unless a scan is running.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    /// <param name="Action">Set to caNone while a scan runs, otherwise caFree.</param>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>Creates the file map.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure FormCreate( Sender: TObject );
    /// <summary>Frees the analyser and the file map.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Lists the edges of the newly selected group.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    /// <param name="Item">The row whose selection changed.</param>
    /// <param name="Selected">True when the row became selected.</param>
    procedure lvGroupsSelectItem( Sender: TObject; Item: TListItem; Selected: Boolean );
    /// <summary>Shows the details of the selected edge and updates the Remove button.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    /// <param name="Item">The row whose selection changed.</param>
    /// <param name="Selected">True when the row became selected.</param>
    procedure lvCandidatesSelectItem( Sender: TObject; Item: TListItem; Selected: Boolean );
    /// <summary>Opens the source file at the uses entry of the double-clicked edge.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure lvCandidatesDblClick( Sender: TObject );
    /// <summary>Opens the source file at the uses entry of the selected edge.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure mnuOpenFileClick( Sender: TObject );
    /// <summary>Copies the selected (or all) edges to the clipboard as TSV.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure mnuCopyToClipboardClick( Sender: TObject );
  private
    /// <summary>Result of the last scan; nil before the first.</summary>
    FAnalyser: TDecirculariser;
    /// <summary>Each analysed unit's file, keyed by lower-case unit name.</summary>
    FFiles: TDictionary<string, string>;
    /// <summary>True while a scan runs; vetoes closing the form, since the scan pumps messages.</summary>
    FScanning: Boolean;
    /// <summary>Index into the analyser's groups of the group whose edges are listed; -1 for none.</summary>
    FGroupIndex: Integer;
    /// <summary>Analyses the active project afresh and lists the result.</summary>
    /// <returns>False when there is no active project.</returns>
    function RunScan: Boolean;
    /// <summary>Fills the group list from the analyser and selects the first group.</summary>
    procedure PopulateGroups;
    /// <summary>Fills the edge list from the selected group.</summary>
    procedure PopulateCandidates;
    /// <summary>The edge an edge-list row stands for, checked against the current analysis.</summary>
    /// <param name="AItem">A row of the edge list; nil is allowed.</param>
    /// <param name="ACandidate">The edge, from the group currently listed.</param>
    /// <returns>False when the row does not belong to the current analysis ( mid-scan, or nil ).</returns>
    function TryCandidateOf( AItem: TListItem; out ACandidate: TDcBreakCandidate ): Boolean;
    /// <summary>Shows the details of the selected edge.</summary>
    procedure ShowDetails;
    /// <summary>Enables Remove when a selected edge may be deleted automatically.</summary>
    procedure UpdateButtons;
    /// <summary>Opens the selected edge's source file at its uses entry.</summary>
    procedure OpenSelectedFile;
  public
    /// <summary>Shows or focuses the singleton form.</summary>
    class procedure Execute;
    /// <summary>Force-closes the singleton form, if open, so it cannot outlive the plugin on unload.</summary>
    class procedure CloseInstance;
  end;

var
  /// <summary>Singleton form instance (nil when the form is not open).</summary>
  FormInstance: TFormDecirculariser = nil;

implementation

{$R *.dfm}

uses
  ToolsAPI, ToolsAPIHelpers, Decirculariser;

class procedure TFormDecirculariser.Execute;
begin
  if FormInstance <> nil then
  begin
    FormInstance.Show;
    FormInstance.BringToFront;
    Exit;
  end;

  FormInstance := TFormDecirculariser.Create( Application );
  FormInstance.Show;
end;

class procedure TFormDecirculariser.CloseInstance;
begin
  if FormInstance <> nil then
    FreeAndNil( FormInstance );
end;

procedure TFormDecirculariser.FormClose( Sender: TObject; var Action: TCloseAction );
begin
  { The scan pumps the message queue, so a close can arrive mid-scan; freeing the form then
    would free FAnalyser under the running scan. }
  if FScanning then
  begin
    Action := caNone;
    Exit;
  end;

  FormInstance := nil;
  Action       := caFree;
end;

procedure TFormDecirculariser.FormCreate( Sender: TObject );
begin
  FFiles      := TDictionary<string, string>.Create;
  FGroupIndex := -1;
  UpdateButtons;
end;

procedure TFormDecirculariser.FormDestroy( Sender: TObject );
begin
  FAnalyser.Free;
  FFiles.Free;
end;

function TFormDecirculariser.RunScan: Boolean;
var
  Project: IOTAProject;
  iUnits: Integer;
  iFragile: Integer;
  Group: TDcGroup;
begin
  Project := GetActiveProject;
  Result  := Project <> nil;
  if not Result then
    Exit;

  Screen.Cursor   := crHourGlass;
  btnScan.Enabled := False;
  FScanning       := True;
  try
    { The rows index into the analyser about to be freed: drop them first. }
    FGroupIndex := -1;
    lvCandidates.Items.Clear;
    lvGroups.Items.Clear;
    memoDetails.Lines.Clear;
    FreeAndNil( FAnalyser );
    FFiles.Clear;
    FAnalyser := TDecirculariser.Create;
    if DecirculariserPlugin <> nil then
      FAnalyser.FewSymbolsLimit := DecirculariserPlugin.FewSymbolsLimit;

    iUnits := AddProjectUnits( Project, FAnalyser, FFiles,
      procedure( AFileName: string )
      begin
        lblSummary.Caption := 'Reading: ' + ExtractFileName( AFileName );
        Application.ProcessMessages;
      end );

    lblSummary.Caption := 'Analysing...';
    Application.ProcessMessages;
    FAnalyser.Analyse;
    PopulateGroups;

    iFragile := 0;
    for Group in FAnalyser.Groups do
      if Group.Kind = dcgFragile then
        Inc( iFragile );
    lblSummary.Caption := Format( '%d units, %d entangled group(s), %d FRAGILE',
      [ iUnits, Length( FAnalyser.Groups ), iFragile ] );
  finally
    FScanning       := False;
    btnScan.Enabled := True;
    Screen.Cursor   := crDefault;
  end;
end;

procedure TFormDecirculariser.btnScanClick( Sender: TObject );
begin
  if not RunScan then
    ShowMessage( 'No active project.' );
end;

procedure TFormDecirculariser.PopulateGroups;
var
  I: Integer;
  Group: TDcGroup;
  Item: TListItem;
begin
  FGroupIndex := -1;
  lvGroups.Items.BeginUpdate;
  try
    lvGroups.Items.Clear;
    for I := 0 to High( FAnalyser.Groups ) do
    begin
      Group        := FAnalyser.Groups[ I ];
      Item         := lvGroups.Items.Add;
      Item.Caption := DcGroupKindToStr( Group.Kind );
      Item.SubItems.Add( IntToStr( Length( Group.Units ) ) );
      Item.SubItems.Add( IntToStr( Group.InterfaceEdgeCount ) );
      Item.SubItems.Add( IntToStr( Group.ImplementationEdgeCount ) );
      Item.SubItems.Add( string.Join( ', ', Group.Units ) );
      Item.Data := Pointer( NativeInt( I ) );
    end;
  finally
    lvGroups.Items.EndUpdate;
  end;

  if lvGroups.Items.Count > 0 then
    lvGroups.Items[ 0 ].Selected := True
  else
    PopulateCandidates;
end;

procedure TFormDecirculariser.lvGroupsSelectItem( Sender: TObject; Item: TListItem; Selected: Boolean );
begin
  if Selected and ( Item <> nil ) then
  begin
    FGroupIndex := NativeInt( Item.Data );
    PopulateCandidates;
  end;
end;

procedure TFormDecirculariser.PopulateCandidates;
var
  I: Integer;
  Candidate: TDcBreakCandidate;
  Item: TListItem;
  sFix: string;
begin
  lvCandidates.Items.BeginUpdate;
  try
    lvCandidates.Items.Clear;
    if ( FAnalyser <> nil ) and ( FGroupIndex >= 0 ) and ( FGroupIndex <= High( FAnalyser.Groups ) ) then
      for I := 0 to High( FAnalyser.Groups[ FGroupIndex ].Candidates ) do
      begin
        Candidate    := FAnalyser.Groups[ FGroupIndex ].Candidates[ I ];
        Item         := lvCandidates.Items.Add;
        Item.Caption := Candidate.Edge.FromUnit;
        Item.SubItems.Add( Candidate.Edge.ToUnit );
        Item.SubItems.Add( IntToStr( Candidate.Edge.LineNumber ) );
        Item.SubItems.Add( DcVerdictToStr( Candidate.Verdict ) );
        Item.SubItems.Add( IntToStr( Length( Candidate.CrossingSymbols ) ) );
        if Candidate.CanAutoRemove then
          sFix := 'auto'
        else if Candidate.Verdict = dcvUnusedEdge then
          sFix := 'by hand (start-up code)'
        else
          sFix := 'by hand';
        Item.SubItems.Add( sFix );
        Item.Data := Pointer( NativeInt( I ) );
      end;
  finally
    lvCandidates.Items.EndUpdate;
  end;
  ShowDetails;
  UpdateButtons;
end;

function TFormDecirculariser.TryCandidateOf( AItem: TListItem; out ACandidate: TDcBreakCandidate ): Boolean;
var
  iIndex: NativeInt;
begin
  ACandidate := Default( TDcBreakCandidate );
  Result     := ( AItem <> nil ) and ( FAnalyser <> nil ) and ( FGroupIndex >= 0 ) and
    ( FGroupIndex <= High( FAnalyser.Groups ) );
  if not Result then
    Exit;
  iIndex := NativeInt( AItem.Data );
  Result := ( iIndex >= 0 ) and ( iIndex <= High( FAnalyser.Groups[ FGroupIndex ].Candidates ) );
  if Result then
    ACandidate := FAnalyser.Groups[ FGroupIndex ].Candidates[ iIndex ];
end;

procedure TFormDecirculariser.lvCandidatesSelectItem( Sender: TObject; Item: TListItem; Selected: Boolean );
begin
  ShowDetails;
  UpdateButtons;
end;

procedure TFormDecirculariser.ShowDetails;
var
  Candidate: TDcBreakCandidate;
begin
  memoDetails.Lines.BeginUpdate;
  try
    memoDetails.Lines.Clear;
    if not TryCandidateOf( lvCandidates.Selected, Candidate ) then
      Exit;

    memoDetails.Lines.Add( Format( '%s -> %s, implementation uses clause, line %d',
      [ Candidate.Edge.FromUnit, Candidate.Edge.ToUnit, Candidate.Edge.LineNumber ] ) );
    memoDetails.Lines.Add( Candidate.Advice );
    if Length( Candidate.CrossingSymbols ) > 0 then
      memoDetails.Lines.Add( 'Crossing: ' + string.Join( ', ', Candidate.CrossingSymbols ) );
    if Candidate.AmbiguousSymbolCount > 0 then
      memoDetails.Lines.Add( Format( 'Also used: %d identifier(s) that several units declare, ' +
        'so no evidence for this edge.', [ Candidate.AmbiguousSymbolCount ] ) );
  finally
    memoDetails.Lines.EndUpdate;
  end;
end;

procedure TFormDecirculariser.UpdateButtons;
var
  Item: TListItem;
  Candidate: TDcBreakCandidate;
  bAny: Boolean;
begin
  bAny := False;
  for Item in lvCandidates.Items do
    if Item.Selected and TryCandidateOf( Item, Candidate ) and Candidate.CanAutoRemove then
    begin
      bAny := True;
      Break;
    end;
  btnRemove.Enabled     := bAny;
  btnCopyReport.Enabled := FAnalyser <> nil;
end;

procedure TFormDecirculariser.btnRemoveClick( Sender: TObject );
type
  /// <summary>One edge chosen for removal, by name, so it survives the re-analysis.</summary>
  TEdgeRef = record
    FromUnit, ToUnit: string;
  end;
var
  Wanted: TList<TEdgeRef>;
  Ref: TEdgeRef;
  ByFile: TObjectDictionary<string, TStringList>;
  Names: TStringList;
  Failures: TStringList;
  Item: TListItem;
  Group: TDcGroup;
  Candidate: TDcBreakCandidate;
  sList, sFile, sMsg: string;
  bStillDead: Boolean;
  iRemoved: Integer;
  FilePair: TPair<string, TStringList>;
begin
  Wanted   := TList<TEdgeRef>.Create;
  ByFile   := TObjectDictionary<string, TStringList>.Create( [ doOwnsValues ] );
  Failures := TStringList.Create;
  try
    sList := '';
    for Item in lvCandidates.Items do
      if Item.Selected and TryCandidateOf( Item, Candidate ) and Candidate.CanAutoRemove then
      begin
        Ref.FromUnit := Candidate.Edge.FromUnit;
        Ref.ToUnit   := Candidate.Edge.ToUnit;
        Wanted.Add( Ref );
        sList := sList + Format( '  %s: remove %s'#13#10, [ Ref.FromUnit, Ref.ToUnit ] );
      end;
    if Wanted.Count = 0 then
      Exit;

    if MessageDlg( Format( 'Remove %d dead uses entry(ies)?'#13#10#13#10'%s'#13#10 +
      'The units are changed in the editor and not saved: compile, then save or undo (Ctrl+Z).',
      [ Wanted.Count, sList ] ), mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
      Exit;

    { The list may be stale: re-analyse what is in the editors now and delete only what is still dead. }
    if not RunScan then
    begin
      ShowMessage( 'No active project.' );
      Exit;
    end;

    for Ref in Wanted do
    begin
      bStillDead := False;
      for Group in FAnalyser.Groups do
        for Candidate in Group.Candidates do
          if SameText( Candidate.Edge.FromUnit, Ref.FromUnit ) and
             SameText( Candidate.Edge.ToUnit, Ref.ToUnit ) and Candidate.CanAutoRemove then
            bStillDead := True;

      if not bStillDead or not FFiles.TryGetValue( LowerCase( Ref.FromUnit ), sFile ) then
      begin
        Failures.Add( Format( '%s in %s: no longer a dead entry, skipped', [ Ref.ToUnit, Ref.FromUnit ] ) );
        Continue;
      end;

      if not ByFile.TryGetValue( sFile, Names ) then
      begin
        Names := TStringList.Create;
        ByFile.Add( sFile, Names );
      end;
      Names.Add( Ref.ToUnit );
    end;

    iRemoved := 0;
    for FilePair in ByFile do
      Inc( iRemoved, RemoveDeadEntries( FilePair.Key, FilePair.Value.ToStringArray, Failures ) );

    RunScan;

    sMsg := Format( '%d entry(ies) removed. The changed units are modified in the editor, not saved: ' +
      'compile to confirm, then save them, or undo with Ctrl+Z.', [ iRemoved ] );
    if Failures.Count > 0 then
      sMsg := sMsg + #13#10#13#10'Not removed:'#13#10 + Failures.Text;
    ShowMessage( sMsg );
  finally
    Failures.Free;
    ByFile.Free;
    Wanted.Free;
  end;
end;

procedure TFormDecirculariser.btnCopyReportClick( Sender: TObject );
begin
  if FAnalyser <> nil then
    Clipboard.AsText := FAnalyser.Report;
end;

procedure TFormDecirculariser.btnCloseClick( Sender: TObject );
begin
  Close;
end;

procedure TFormDecirculariser.OpenSelectedFile;
var
  Candidate: TDcBreakCandidate;
  sFile: string;
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  I: Integer;
begin
  if not TryCandidateOf( lvCandidates.Selected, Candidate ) then
    Exit;
  if not FFiles.TryGetValue( LowerCase( Candidate.Edge.FromUnit ), sFile ) then
    Exit;
  if not Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
    Exit;

  Module := ModuleServices.OpenModule( sFile );
  if Module = nil then
    Exit;
  for I := 0 to Module.ModuleFileCount - 1 do
    if Supports( Module.ModuleFileEditors[ I ], IOTASourceEditor, SourceEditor ) then
    begin
      SourceEditor.Show;
      if SourceEditor.EditViewCount > 0 then
      begin
        EditView := SourceEditor.EditViews[ 0 ];
        EditView.SetTopLeft( Candidate.Edge.LineNumber, 1 );
        EditView.Center( Candidate.Edge.LineNumber, 1 );
      end;
      Break;
    end;
end;

procedure TFormDecirculariser.lvCandidatesDblClick( Sender: TObject );
begin
  OpenSelectedFile;
end;

procedure TFormDecirculariser.mnuOpenFileClick( Sender: TObject );
begin
  OpenSelectedFile;
end;

procedure TFormDecirculariser.mnuCopyToClipboardClick( Sender: TObject );
var
  SL: TStringList;
  Item: TListItem;
  I: Integer;
  sLine: string;
begin
  SL := TStringList.Create;
  try
    SL.Add( 'From'#9'To'#9'Line'#9'Verdict'#9'Crossing'#9'Fix' );
    for Item in lvCandidates.Items do
      if Item.Selected or ( lvCandidates.SelCount = 0 ) then
      begin
        sLine := Item.Caption;
        for I := 0 to Item.SubItems.Count - 1 do
          sLine := sLine + #9 + Item.SubItems[ I ];
        SL.Add( sLine );
      end;
    Clipboard.AsText := SL.Text;
  finally
    SL.Free;
  end;
end;

end.
