{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmDeadCodeDetector;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Menus, Clipbrd, Generics.Collections,
  Generics.Defaults, FrmBase, DeadCodeDetector, ToolsAPI;

type
  TFormDeadCodeDetector = class( TFormBase )
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
    cboType: TComboBox;
    lblType: TLabel;
    cboScope: TComboBox;
    lblScope: TLabel;
    mnuAddToIgnoreList: TMenuItem;
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
    procedure cboTypeChange( Sender: TObject );
    procedure cboScopeChange( Sender: TObject );
    procedure mnuAddToIgnoreListClick( Sender: TObject );
  private
    FAnalyzer: TDeadCodeAnalyzer;
    FDeadCode: TArray<TDeadCodeItem>;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    procedure PopulateList;
    procedure AnalyzerProgress( Sender: TObject );
    procedure OpenSelectedFile;
    function PassesFilter( const Item: TDeadCodeItem ): Boolean;
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

class function TFormDeadCodeDetector.Execute: Boolean;
var
  Form: TFormDeadCodeDetector;
begin

  Form := TFormDeadCodeDetector.Create( Application );

  try
    Form.ShowModal;
    Result := True;
  finally
    Form.Free;
  end;

end;

procedure TFormDeadCodeDetector.FormCreate( Sender: TObject );
var
  I: Integer;
begin

  FAnalyzer      := TDeadCodeAnalyzer.Create;
  FSortColumn    := 0;
  FSortAscending := True;

  // Load ignore patterns from plugin
  if DeadCodeDetectorPlugin <> nil then
  begin
    for I := 0 to DeadCodeDetectorPlugin.IgnoreList.Count - 1 do
      FAnalyzer.AddIgnorePattern( DeadCodeDetectorPlugin.IgnoreList[ I ] );
  end;

  // Set up type filter
  cboType.Items.Add( '(All)' );
  cboType.Items.Add( 'Procedure' );
  cboType.Items.Add( 'Function' );
  cboType.Items.Add( 'Field' );
  cboType.ItemIndex := 0;

  // Set up scope filter
  cboScope.Items.Add( '(All)' );
  cboScope.Items.Add( 'private' );
  cboScope.Items.Add( 'protected' );
  cboScope.Items.Add( 'public' );
  cboScope.Items.Add( 'unit' );
  cboScope.ItemIndex := 0;

end;

procedure TFormDeadCodeDetector.FormDestroy( Sender: TObject );
begin

  FAnalyzer.Free;

end;

procedure TFormDeadCodeDetector.AnalyzerProgress( Sender: TObject );
begin

  if Sender is TDeadCodeAnalyzer then
    lblProgress.Caption := TDeadCodeAnalyzer( Sender ).ProgressFileName;

  Application.ProcessMessages;

end;

procedure TFormDeadCodeDetector.btnCloseClick( Sender: TObject );
begin

  Close;

end;

procedure TFormDeadCodeDetector.btnScanClick( Sender: TObject );
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
    lblProgress.Caption := 'Analysing project...';
    lblProgress.Visible := True;
    lblSummary.Visible  := False;
    Application.ProcessMessages;

    FAnalyzer.AnalyzeProject( Project, FDeadCode, AnalyzerProgress );
    PopulateList;

    lblProgress.Visible := False;
    lblSummary.Caption  := Format( 'Found %d potentially dead code items', [ Length( FDeadCode ) ] );
    lblSummary.Visible  := True;
  finally
    btnScan.Enabled := True;
    Screen.Cursor   := crDefault;
  end;

end;

function TFormDeadCodeDetector.PassesFilter( const Item: TDeadCodeItem ): Boolean;
var
  TypeFilter, ScopeFilter: string;
begin

  Result := True;

  // Check type filter
  if cboType.ItemIndex > 0 then
  begin
    TypeFilter := cboType.Items[ cboType.ItemIndex ];

    if not SameText( Item.ElementType, TypeFilter ) then
      Result := False;
  end;

  // Check scope filter
  if Result and ( cboScope.ItemIndex > 0 ) then
  begin
    ScopeFilter := cboScope.Items[ cboScope.ItemIndex ];

    if not SameText( Item.Scope, ScopeFilter ) then
      Result := False;
  end;

end;

procedure TFormDeadCodeDetector.PopulateList;
var
  DeadItem: TDeadCodeItem;
  Item: TListItem;
  Idx: Integer;
begin

  ListView.Items.BeginUpdate;

  try
    ListView.Items.Clear;
    Idx := 0;

    for DeadItem in FDeadCode do
    begin

      if PassesFilter( DeadItem ) then
      begin
        Item         := ListView.Items.Add;
        Item.Caption := DeadItem.UnitName;
        Item.SubItems.Add( DeadItem.ElementType );
        Item.SubItems.Add( DeadItem.ElementName );
        Item.SubItems.Add( DeadItem.Scope );
        Item.SubItems.Add( IntToStr( DeadItem.Line ) );
        Item.SubItems.Add( DeadItem.Reason );
        Item.Data := Pointer( NativeInt( Idx ) );
      end;

      Inc( Idx );
    end;
  finally
    ListView.Items.EndUpdate;
  end;

end;

procedure TFormDeadCodeDetector.cboTypeChange( Sender: TObject );
begin

  PopulateList;

end;

procedure TFormDeadCodeDetector.cboScopeChange( Sender: TObject );
begin

  PopulateList;

end;

procedure TFormDeadCodeDetector.ListViewColumnClick( Sender: TObject;
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

procedure TFormDeadCodeDetector.ListViewCompare( Sender: TObject; Item1,
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
  if FSortColumn = 4 then
    Compare := StrToIntDef( S1, 0 ) - StrToIntDef( S2, 0 )
  else
    Compare := CompareText( S1, S2 );

  if not FSortAscending then
    Compare := -Compare;

end;

procedure TFormDeadCodeDetector.ListViewDblClick( Sender: TObject );
begin

  OpenSelectedFile;

end;

procedure TFormDeadCodeDetector.OpenSelectedFile;
var
  Idx: Integer;
  DeadItem: TDeadCodeItem;
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  I: Integer;
begin

  if ListView.Selected = nil then
    Exit;

  Idx := NativeInt( ListView.Selected.Data );

  if ( Idx < 0 ) or ( Idx >= Length( FDeadCode ) ) then
    Exit;

  DeadItem := FDeadCode[ Idx ];

  if Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
  begin
    Module := ModuleServices.OpenModule( DeadItem.FileName );

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
            EditView.SetTopLeft( DeadItem.Line, 1 );
            EditView.Center( DeadItem.Line, 1 );
          end;

          Break;
        end;
      end;
    end;
  end;

end;

procedure TFormDeadCodeDetector.mnuOpenFileClick( Sender: TObject );
begin

  OpenSelectedFile;

end;

procedure TFormDeadCodeDetector.mnuAddToIgnoreListClick( Sender: TObject );
var
  Idx: Integer;
  DeadItem: TDeadCodeItem;
  NameToIgnore: string;
begin

  if ListView.Selected = nil then
    Exit;

  Idx := NativeInt( ListView.Selected.Data );

  if ( Idx < 0 ) or ( Idx >= Length( FDeadCode ) ) then
    Exit;

  DeadItem := FDeadCode[ Idx ];

  // Extract just the method/field name (without class prefix)
  NameToIgnore := DeadItem.ElementName;

  if Pos( '.', NameToIgnore ) > 0 then
    NameToIgnore := Copy( NameToIgnore, Pos( '.', NameToIgnore ) + 1, MaxInt );

  if DeadCodeDetectorPlugin <> nil then
  begin
    DeadCodeDetectorPlugin.IgnoreList.Add( NameToIgnore );
    DeadCodeDetectorPlugin.Save;
    ShowMessage( Format( '"%s" added to ignore list. Re-scan to update results.', [ NameToIgnore ] ) );
  end;

end;

procedure TFormDeadCodeDetector.mnuCopyToClipboardClick( Sender: TObject );
var
  SL: TStringList;
  Item: TListItem;
begin

  SL := TStringList.Create;

  try
    SL.Add( 'Unit'#9'Type'#9'Name'#9'Scope'#9'Line'#9'Reason' );

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

procedure TFormDeadCodeDetector.btnExportClick( Sender: TObject );
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
      SL.Add( 'Unit,Type,Name,Scope,Line,Reason' );

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
