{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmCodeStyleChecker;

/// <summary>
/// Results window for the Code Style Checker. Triggers project-wide scans, displays the
/// violations in a sortable, filterable list view, and supports navigating to the offending
/// source line as well as copying or exporting the data.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Menus, Clipbrd, Generics.Collections,
  Generics.Defaults, FrmBase, CodeStyleChecker, ToolsAPI;

type
  /// <summary>Singleton results form for the Code Style Checker.</summary>
  TFormCodeStyleChecker = class( TFormBase )
    /// <summary>Top toolbar panel.</summary>
    pnlTop: TPanel;
    /// <summary>Bottom action-button panel.</summary>
    pnlBottom: TGridPanel;
    /// <summary>Closes the form.</summary>
    btnClose: TButton;
    /// <summary>Initiates a project-wide scan.</summary>
    btnScan: TButton;
    /// <summary>List view displaying violations.</summary>
    ListView: TListView;
    /// <summary>Status text shown while a scan is in progress.</summary>
    lblProgress: TLabel;
    /// <summary>Context menu attached to the list view.</summary>
    PopupMenu: TPopupMenu;
    /// <summary>Copies the selected (or all) violations to the clipboard as TSV.</summary>
    mnuCopyToClipboard: TMenuItem;
    /// <summary>Separator menu item.</summary>
    N1: TMenuItem;
    /// <summary>Navigates the IDE editor to the selected violation.</summary>
    mnuOpenFile: TMenuItem;
    /// <summary>Exports all visible violations to CSV.</summary>
    btnExport: TButton;
    /// <summary>File-save dialog used by <see cref="btnExport"/>.</summary>
    SaveDialog: TSaveDialog;
    /// <summary>Result summary text displayed after a scan completes.</summary>
    lblSummary: TLabel;
    /// <summary>Filter combo for the violation category.</summary>
    cboCategory: TComboBox;
    /// <summary>Label for <see cref="cboCategory"/>.</summary>
    lblCategory: TLabel;
    /// <summary>Filter combo for individual rules.</summary>
    cboRule: TComboBox;
    /// <summary>Label for <see cref="cboRule"/>.</summary>
    lblRule: TLabel;
    /// <summary>Filter combo for severity.</summary>
    cboSeverity: TComboBox;
    /// <summary>Label for <see cref="cboSeverity"/>.</summary>
    lblSeverity: TLabel;
    /// <summary>OnClick handler for <see cref="btnClose"/>.</summary>
    procedure btnCloseClick( Sender: TObject );
    /// <summary>OnClick handler for <see cref="btnScan"/> — runs a project scan.</summary>
    procedure btnScanClick( Sender: TObject );
    /// <summary>Releases the singleton instance when the form closes.</summary>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>Creates the checker engine and populates the filter combos.</summary>
    procedure FormCreate( Sender: TObject );
    /// <summary>Frees the checker engine.</summary>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Opens the file represented by the double-clicked row.</summary>
    procedure ListViewDblClick( Sender: TObject );
    /// <summary>Context-menu handler that copies violation data to the clipboard.</summary>
    procedure mnuCopyToClipboardClick( Sender: TObject );
    /// <summary>Context-menu handler that opens the source file at the violation line.</summary>
    procedure mnuOpenFileClick( Sender: TObject );
    /// <summary>Exports the visible violations to a CSV file.</summary>
    procedure btnExportClick( Sender: TObject );
    /// <summary>Cycles sort direction when a column header is clicked.</summary>
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    /// <summary>Custom comparator supporting numeric sort on the line-number column.</summary>
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    /// <summary>Re-applies filters when the category combo changes.</summary>
    procedure cboCategoryChange( Sender: TObject );
    /// <summary>Re-applies filters when the rule combo changes.</summary>
    procedure cboRuleChange( Sender: TObject );
    /// <summary>Re-applies filters when the severity combo changes.</summary>
    procedure cboSeverityChange( Sender: TObject );
  private
    /// <summary>Engine performing the analysis.</summary>
    FChecker: TStyleChecker;
    /// <summary>Latest scan results.</summary>
    FViolations: TArray<TStyleViolation>;
    /// <summary>Index of the column currently being sorted.</summary>
    FSortColumn: Integer;
    /// <summary>Sort direction flag.</summary>
    FSortAscending: Boolean;
    /// <summary>Rebuilds the list view from <see cref="FViolations"/>, applying current filters.</summary>
    procedure PopulateList;
    /// <summary>Progress callback invoked by <see cref="TStyleChecker"/> between files.</summary>
    procedure CheckerProgress( Sender: TObject );
    /// <summary>Opens the file/line of the currently selected list item in the IDE.</summary>
    procedure OpenSelectedFile;
    /// <summary>Returns <c>True</c> when the supplied violation matches all currently active filters.</summary>
    /// <param name="Item">Violation under test.</param>
    function PassesFilter( const Item: TStyleViolation ): Boolean;
  public
    /// <summary>Displays the singleton form, creating it if required.</summary>
    class procedure Execute;
  end;

var
  /// <summary>Singleton form reference; <c>nil</c> when the form is not visible.</summary>
  FormInstance: TFormCodeStyleChecker = nil;

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

class procedure TFormCodeStyleChecker.Execute;
begin

  // If already open, bring to front
  if FormInstance <> nil then
  begin
    FormInstance.Show;
    FormInstance.BringToFront;
    Exit;
  end;

  FormInstance := TFormCodeStyleChecker.Create( Application );
  FormInstance.Show;

end;

procedure TFormCodeStyleChecker.FormCreate( Sender: TObject );
begin

  FChecker       := TStyleChecker.Create;
  FSortColumn    := 0;
  FSortAscending := True;

  // Set up category filter
  cboCategory.Items.Add( '(All)' );
  cboCategory.Items.Add( 'NamingConvention' );
  cboCategory.Items.Add( 'AntiPattern' );
  cboCategory.ItemIndex := 0;

  // Set up rule filter - naming conventions
  cboRule.Items.Add( '(All)' );
  cboRule.Items.Add( 'TypePrefix' );
  cboRule.Items.Add( 'InterfacePrefix' );
  cboRule.Items.Add( 'FieldPrefix' );
  cboRule.Items.Add( 'FieldTypePrefix' );
  cboRule.Items.Add( 'ExceptionPrefix' );
  cboRule.Items.Add( 'PointerPrefix' );
  cboRule.Items.Add( 'ParameterPrefix' );
  cboRule.Items.Add( 'VariablePrefix' );
  cboRule.Items.Add( 'UnitScopePrefix' );
  // Anti-pattern rules
  cboRule.Items.Add( 'EmptyFinally' );
  cboRule.Items.Add( 'NestedWith' );
  cboRule.Items.Add( 'DeepNesting' );
  cboRule.Items.Add( 'LongMethod' );
  cboRule.Items.Add( 'LongParamList' );
  cboRule.ItemIndex := 0;

  // Set up severity filter
  cboSeverity.Items.Add( '(All)' );
  cboSeverity.Items.Add( 'Warning' );
  cboSeverity.Items.Add( 'Info' );
  cboSeverity.ItemIndex := 0;

end;

procedure TFormCodeStyleChecker.FormDestroy( Sender: TObject );
begin

  FChecker.Free;

end;

procedure TFormCodeStyleChecker.CheckerProgress( Sender: TObject );
begin

  if Sender is TStyleChecker then
    lblProgress.Caption := 'Checking: ' + TStyleChecker( Sender ).ProgressFileName;

  Application.ProcessMessages;

end;

procedure TFormCodeStyleChecker.btnCloseClick( Sender: TObject );
begin

  Close;

end;

procedure TFormCodeStyleChecker.FormClose( Sender: TObject; var Action: TCloseAction );
begin

  FormInstance := nil;
  Action       := caFree;

end;

procedure TFormCodeStyleChecker.btnScanClick( Sender: TObject );
var
  Project: IOTAProject;
begin

  Project := GetActiveProject;

  if Project = nil then
  begin
    ShowMessage( 'No active project.' );
    Exit;
  end;

  Screen.Cursor    := crHourGlass;
  btnScan.Enabled  := False;

  try
    lblProgress.Caption := 'Checking project...';
    lblProgress.Visible := True;
    lblSummary.Visible  := False;
    Application.ProcessMessages;

    FChecker.CheckProject( Project, FViolations, CheckerProgress );
    PopulateList;

    lblProgress.Visible := False;
    lblSummary.Caption  := Format( 'Found %d style violations', [ Length( FViolations ) ] );
    lblSummary.Visible  := True;
  finally
    btnScan.Enabled := True;
    Screen.Cursor   := crDefault;
  end;

end;

function TFormCodeStyleChecker.PassesFilter( const Item: TStyleViolation ): Boolean;
var
  CategoryFilter, RuleFilter, SeverityFilter: string;
begin

  Result := True;

  // Check category filter
  if cboCategory.ItemIndex > 0 then
  begin
    CategoryFilter := cboCategory.Items[ cboCategory.ItemIndex ];

    if not SameText( Item.Category, CategoryFilter ) then
      Result := False;
  end;

  // Check rule filter
  if Result and ( cboRule.ItemIndex > 0 ) then
  begin
    RuleFilter := cboRule.Items[ cboRule.ItemIndex ];

    if not SameText( Item.Rule, RuleFilter ) then
      Result := False;
  end;

  // Check severity filter
  if Result and ( cboSeverity.ItemIndex > 0 ) then
  begin
    SeverityFilter := cboSeverity.Items[ cboSeverity.ItemIndex ];

    if not SameText( Item.Severity, SeverityFilter ) then
      Result := False;
  end;

end;

procedure TFormCodeStyleChecker.PopulateList;
var
  Violation: TStyleViolation;
  Item: TListItem;
  Idx: Integer;
  Category: string;
begin

  ListView.Items.BeginUpdate;

  try
    ListView.Items.Clear;
    Idx := 0;

    for Violation in FViolations do
    begin

      if PassesFilter( Violation ) then
      begin
        Item         := ListView.Items.Add;
        Item.Caption := Violation.UnitName;
        // Use default category if not set
        Category := Violation.Category;
        if Category = '' then
          Category := 'NamingConvention';
        Item.SubItems.Add( Category );
        Item.SubItems.Add( Violation.Rule );
        Item.SubItems.Add( IntToStr( Violation.Line ) );
        Item.SubItems.Add( Violation.Expected );
        Item.SubItems.Add( Violation.Actual );
        Item.SubItems.Add( Violation.Severity );
        Item.Data := Pointer( NativeInt( Idx ) );
      end;

      Inc( Idx );
    end;
  finally
    ListView.Items.EndUpdate;
  end;

end;

procedure TFormCodeStyleChecker.cboCategoryChange( Sender: TObject );
begin

  PopulateList;

end;

procedure TFormCodeStyleChecker.cboRuleChange( Sender: TObject );
begin

  PopulateList;

end;

procedure TFormCodeStyleChecker.cboSeverityChange( Sender: TObject );
begin

  PopulateList;

end;

procedure TFormCodeStyleChecker.ListViewColumnClick( Sender: TObject;
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

procedure TFormCodeStyleChecker.ListViewCompare( Sender: TObject; Item1,
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

  // Try numeric comparison for line number column (now column 3)
  if FSortColumn = 3 then
    Compare := StrToIntDef( S1, 0 ) - StrToIntDef( S2, 0 )
  else
    Compare := CompareText( S1, S2 );

  if not FSortAscending then
    Compare := -Compare;

end;

procedure TFormCodeStyleChecker.ListViewDblClick( Sender: TObject );
begin

  OpenSelectedFile;

end;

procedure TFormCodeStyleChecker.OpenSelectedFile;
var
  Idx: Integer;
  Violation: TStyleViolation;
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  I: Integer;
begin

  if ListView.Selected = nil then
    Exit;

  Idx := NativeInt( ListView.Selected.Data );

  if ( Idx < 0 ) or ( Idx >= Length( FViolations ) ) then
    Exit;

  Violation := FViolations[ Idx ];

  if Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
  begin
    Module := ModuleServices.OpenModule( Violation.FileName );

    if Module <> nil then
    begin

      for I := 0 to Module.ModuleFileCount - 1 do
      begin

        if Supports( Module.ModuleFileEditors[ I ], IOTASourceEditor, SourceEditor ) then
        begin
          SourceEditor.Show;

          if SourceEditor.EditViewCount > 0 then
          begin
            EditView := SourceEditor.EditViews[ 0 ];
            EditView.SetTopLeft( Violation.Line, 1 );
            EditView.Center( Violation.Line, Violation.Column );
          end;

          Break;
        end;
      end;
    end;
  end;

end;

procedure TFormCodeStyleChecker.mnuOpenFileClick( Sender: TObject );
begin

  OpenSelectedFile;

end;

procedure TFormCodeStyleChecker.mnuCopyToClipboardClick( Sender: TObject );
var
  SL: TStringList;
  Item: TListItem;
begin

  SL := TStringList.Create;

  try
    SL.Add( 'Unit'#9'Category'#9'Rule'#9'Line'#9'Expected'#9'Actual'#9'Severity' );

    for Item in ListView.Items do
    begin

      if Item.Selected or ( ListView.SelCount = 0 ) then
        SL.Add( Format( '%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s', [
          Item.Caption,
          SafeGetSubItem( Item, 0 ),
          SafeGetSubItem( Item, 1 ),
          SafeGetSubItem( Item, 2 ),
          SafeGetSubItem( Item, 3 ),
          SafeGetSubItem( Item, 4 ),
          SafeGetSubItem( Item, 5 )
        ] ) );
    end;

    Clipboard.AsText := SL.Text;
  finally
    SL.Free;
  end;

end;

procedure TFormCodeStyleChecker.btnExportClick( Sender: TObject );
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
      SL.Add( 'Unit,Category,Rule,Line,Expected,Actual,Severity' );

      for Item in ListView.Items do
      begin
        SL.Add( Format( '"%s","%s","%s","%s","%s","%s","%s"', [
          Item.Caption,
          SafeGetSubItem( Item, 0 ),
          SafeGetSubItem( Item, 1 ),
          SafeGetSubItem( Item, 2 ),
          SafeGetSubItem( Item, 3 ),
          SafeGetSubItem( Item, 4 ),
          SafeGetSubItem( Item, 5 )
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
