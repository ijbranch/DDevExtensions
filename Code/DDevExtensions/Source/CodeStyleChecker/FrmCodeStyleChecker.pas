{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmCodeStyleChecker;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Menus, Clipbrd, Generics.Collections,
  Generics.Defaults, FrmBase, CodeStyleChecker, ToolsAPI;

type
  TFormCodeStyleChecker = class( TFormBase )
    pnlTop: TPanel;
    pnlBottom: TPanel;
    btnClose: TButton;
    btnScan: TButton;
    ListView: TListView;
    lblProgress: TLabel;
    PopupMenu: TPopupMenu;
    mnuCopyToClipboard: TMenuItem;
    N1: TMenuItem;
    mnuOpenFile: TMenuItem;
    btnExport: TButton;
    SaveDialog: TSaveDialog;
    lblSummary: TLabel;
    cboRule: TComboBox;
    lblRule: TLabel;
    cboSeverity: TComboBox;
    lblSeverity: TLabel;
    procedure btnCloseClick( Sender: TObject );
    procedure btnScanClick( Sender: TObject );
    procedure FormCreate( Sender: TObject );
    procedure FormDestroy( Sender: TObject );
    procedure ListViewDblClick( Sender: TObject );
    procedure mnuCopyToClipboardClick( Sender: TObject );
    procedure mnuOpenFileClick( Sender: TObject );
    procedure btnExportClick( Sender: TObject );
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    procedure cboRuleChange( Sender: TObject );
    procedure cboSeverityChange( Sender: TObject );
  private
    FChecker: TStyleChecker;
    FViolations: TArray<TStyleViolation>;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    procedure PopulateList;
    procedure CheckerProgress( Sender: TObject );
    procedure OpenSelectedFile;
    function PassesFilter( const Item: TStyleViolation ): Boolean;
  public
    class function Execute: Boolean;
  end;

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

class function TFormCodeStyleChecker.Execute: Boolean;
var
  Form: TFormCodeStyleChecker;
begin

  Form := TFormCodeStyleChecker.Create( Application );

  try
    Form.ShowModal;
    Result := True;
  finally
    Form.Free;
  end;

end;

procedure TFormCodeStyleChecker.FormCreate( Sender: TObject );
begin

  FChecker       := TStyleChecker.Create;
  FSortColumn    := 0;
  FSortAscending := True;

  // Set up rule filter
  cboRule.Items.Add( '(All)' );
  cboRule.Items.Add( 'TypePrefix' );
  cboRule.Items.Add( 'InterfacePrefix' );
  cboRule.Items.Add( 'FieldPrefix' );
  cboRule.Items.Add( 'ExceptionPrefix' );
  cboRule.Items.Add( 'PointerPrefix' );
  cboRule.Items.Add( 'ParameterPrefix' );
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
  RuleFilter, SeverityFilter: string;
begin

  Result := True;

  // Check rule filter
  if cboRule.ItemIndex > 0 then
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

  // Try numeric comparison for line number column
  if FSortColumn = 2 then
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
    SL.Add( 'Unit'#9'Rule'#9'Line'#9'Expected'#9'Actual'#9'Severity' );

    for Item in ListView.Items do
    begin

      if Item.Selected or ( ListView.SelCount = 0 ) then
        SL.Add( Format( '%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s', [
          Item.Caption,
          SafeGetSubItem( Item, 0 ),
          SafeGetSubItem( Item, 1 ),
          SafeGetSubItem( Item, 2 ),
          SafeGetSubItem( Item, 3 ),
          SafeGetSubItem( Item, 4 )
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
      SL.Add( 'Unit,Rule,Line,Expected,Actual,Severity' );

      for Item in ListView.Items do
      begin
        SL.Add( Format( '"%s","%s","%s","%s","%s","%s"', [
          Item.Caption,
          SafeGetSubItem( Item, 0 ),
          SafeGetSubItem( Item, 1 ),
          SafeGetSubItem( Item, 2 ),
          SafeGetSubItem( Item, 3 ),
          SafeGetSubItem( Item, 4 )
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
