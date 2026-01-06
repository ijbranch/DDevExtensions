{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2025 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmUnreachableCodeDetector;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Menus, Generics.Collections,
  FrmBase, UnreachableCodeDetector, ToolsAPI;

type
  TFormUnreachableCodeDetector = class( TFormBase )
    pnlTop: TPanel;
    pnlBottom: TGridPanel;
    btnClose: TButton;
    btnScan: TButton;
    ListView: TListView;
    lblProgress: TLabel;
    cmbFilter: TComboBox;
    lblFilter: TLabel;
    btnExport: TButton;
    lblCount: TLabel;
    lblProject: TLabel;
    procedure btnCloseClick( Sender: TObject );
    procedure btnScanClick( Sender: TObject );
    procedure FormCreate( Sender: TObject );
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    procedure FormDestroy( Sender: TObject );
    procedure ListViewDblClick( Sender: TObject );
    procedure cmbFilterChange( Sender: TObject );
    procedure btnExportClick( Sender: TObject );
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
  private
    FScanner: TUnreachableCodeScanner;
    FItems: TArray<TUnreachableCodeItem>;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    procedure PopulateList;
    procedure ScannerProgress( Sender: TObject );
    procedure OpenItem( const Item: TUnreachableCodeItem );
  public
    class function Execute: Boolean;
  end;

implementation

{$R *.dfm}

uses
  ToolsAPIHelpers, Clipbrd;

class function TFormUnreachableCodeDetector.Execute: Boolean;
var
  Form: TFormUnreachableCodeDetector;
begin

  Form := TFormUnreachableCodeDetector.Create( Application );
  Form.Show;  // Non-modal - allows working in Delphi while open
  Result := True;

end;

procedure TFormUnreachableCodeDetector.FormCreate( Sender: TObject );
begin

  FScanner            := TUnreachableCodeScanner.Create;
  FScanner.OnProgress := ScannerProgress;
  FSortColumn         := 0;
  FSortAscending      := True;

  cmbFilter.Items.Add( 'All' );
  cmbFilter.Items.Add( 'After Exit' );
  cmbFilter.Items.Add( 'After Raise' );
  cmbFilter.Items.Add( 'After Break' );
  cmbFilter.Items.Add( 'After Continue' );
  cmbFilter.Items.Add( 'After Halt' );
  cmbFilter.Items.Add( 'After Abort' );
  cmbFilter.ItemIndex := 0;

end;

procedure TFormUnreachableCodeDetector.FormClose( Sender: TObject; var Action: TCloseAction );
begin

  Action := caFree;  // Free the form when closed (non-modal)

end;

procedure TFormUnreachableCodeDetector.FormDestroy( Sender: TObject );
begin

  FScanner.Free;

end;

procedure TFormUnreachableCodeDetector.ScannerProgress( Sender: TObject );
begin

  lblProgress.Caption := 'Scanning: ' + FScanner.ProgressUnit;
  Application.ProcessMessages;

end;

procedure TFormUnreachableCodeDetector.btnCloseClick( Sender: TObject );
begin

  Close;

end;

procedure TFormUnreachableCodeDetector.btnScanClick( Sender: TObject );
var
  Project: IOTAProject;
  ProjectName: string;
begin

  Project := GetActiveProject;

  if Project = nil then
  begin
    ShowMessage( 'No active project.' );
    Exit;
  end;

  ProjectName := ChangeFileExt( ExtractFileName( Project.FileName ), '' );
  lblProject.Caption := 'Project: ' + ProjectName;

  Screen.Cursor := crHourGlass;

  try
    lblProgress.Caption := 'Scanning project...';
    lblProgress.Visible := True;
    Application.ProcessMessages;

    FScanner.ScanProject( Project );
    FItems := FScanner.GetItems;

    PopulateList;

    lblProgress.Caption := Format( 'Scan complete. Found %d unreachable code blocks.', [ Length( FItems ) ] );
  finally
    Screen.Cursor := crDefault;
  end;

end;

procedure TFormUnreachableCodeDetector.PopulateList;
var
  Item: TUnreachableCodeItem;
  ListItem: TListItem;
  FilterIdx: Integer;
  VisibleCount: Integer;
begin

  ListView.Items.BeginUpdate;

  try
    ListView.Items.Clear;
    FilterIdx    := cmbFilter.ItemIndex;
    VisibleCount := 0;

    for Item in FItems do
    begin
      // Apply filter
      if FilterIdx > 0 then
      begin

        if Ord( Item.Reason ) <> ( FilterIdx - 1 ) then
          Continue;
      end;

      ListItem         := ListView.Items.Add;
      ListItem.Caption := Item.UnitName;
      ListItem.SubItems.Add( IntToStr( Item.Line ) );
      ListItem.SubItems.Add( Item.ReasonText );
      ListItem.SubItems.Add( Item.CodePreview );
      ListItem.Data := Pointer( NativeInt( VisibleCount ) );

      Inc( VisibleCount );
    end;

    lblCount.Caption := Format( 'Showing %d of %d items', [ VisibleCount, Length( FItems ) ] );
  finally
    ListView.Items.EndUpdate;
  end;

end;

procedure TFormUnreachableCodeDetector.cmbFilterChange( Sender: TObject );
begin

  PopulateList;

end;

procedure TFormUnreachableCodeDetector.ListViewDblClick( Sender: TObject );
var
  FilterIdx: Integer;
  I, VisibleIdx: Integer;
begin

  if ListView.Selected = nil then
    Exit;

  // Find the actual item
  FilterIdx  := cmbFilter.ItemIndex;
  VisibleIdx := 0;

  for I := 0 to High( FItems ) do
  begin

    if FilterIdx > 0 then
    begin

      if Ord( FItems[ I ].Reason ) <> ( FilterIdx - 1 ) then
        Continue;
    end;

    if VisibleIdx = ListView.Selected.Index then
    begin
      OpenItem( FItems[ I ] );
      Exit;
    end;

    Inc( VisibleIdx );
  end;

end;

procedure TFormUnreachableCodeDetector.OpenItem( const Item: TUnreachableCodeItem );
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  I: Integer;
begin

  if not FileExists( Item.FileName ) then
    Exit;

  if Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
  begin
    Module := ModuleServices.OpenModule( Item.FileName );

    if Module <> nil then
    begin

      for I := 0 to Module.ModuleFileCount - 1 do
      begin

        if Supports( Module.ModuleFileEditors[ I ], IOTASourceEditor, SourceEditor ) then
        begin
          SourceEditor.Show;
          EditView := SourceEditor.EditViews[ 0 ];

          if EditView <> nil then
          begin
            EditView.Position.GotoLine( Item.Line );
            EditView.Center( Item.Line, 1 );
          end;

          Break;
        end;
      end;
    end;
  end;

end;

procedure TFormUnreachableCodeDetector.btnExportClick( Sender: TObject );
var
  SL: TStringList;
  I: Integer;
  Item: TUnreachableCodeItem;
  SaveDlg: TSaveDialog;
begin

  if Length( FItems ) = 0 then
  begin
    ShowMessage( 'No items to export.' );
    Exit;
  end;

  SaveDlg := TSaveDialog.Create( nil );

  try
    SaveDlg.Filter     := 'CSV Files (*.csv)|*.csv|All Files (*.*)|*.*';
    SaveDlg.DefaultExt := 'csv';
    SaveDlg.FileName   := 'UnreachableCode.csv';

    if SaveDlg.Execute then
    begin
      SL := TStringList.Create;

      try
        SL.Add( 'Unit,Line,Reason,Code Preview,File Path' );

        for I := 0 to High( FItems ) do
        begin
          Item := FItems[ I ];
          SL.Add( Format( '"%s",%d,"%s","%s","%s"',
            [ Item.UnitName, Item.Line, Item.ReasonText,
              StringReplace( Item.CodePreview, '"', '""', [ rfReplaceAll ] ),
              Item.FileName ] ) );
        end;

        SL.SaveToFile( SaveDlg.FileName );
        ShowMessage( Format( 'Exported %d items to %s', [ Length( FItems ), SaveDlg.FileName ] ) );
      finally
        SL.Free;
      end;
    end;
  finally
    SaveDlg.Free;
  end;

end;

procedure TFormUnreachableCodeDetector.ListViewColumnClick( Sender: TObject;
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

procedure TFormUnreachableCodeDetector.ListViewCompare( Sender: TObject;
  Item1, Item2: TListItem; Data: Integer; var Compare: Integer );
var
  S1, S2: string;
  N1, N2: Integer;
begin

  case FSortColumn of
    0: // Unit
      begin
        S1      := Item1.Caption;
        S2      := Item2.Caption;
        Compare := CompareText( S1, S2 );
      end;
    1: // Line
      begin
        N1      := StrToIntDef( Item1.SubItems[ 0 ], 0 );
        N2      := StrToIntDef( Item2.SubItems[ 0 ], 0 );
        Compare := N1 - N2;
      end;
    2: // Reason
      begin
        S1      := Item1.SubItems[ 1 ];
        S2      := Item2.SubItems[ 1 ];
        Compare := CompareText( S1, S2 );
      end;
    3: // Code Preview
      begin
        S1      := Item1.SubItems[ 2 ];
        S2      := Item2.SubItems[ 2 ];
        Compare := CompareText( S1, S2 );
      end;
  else
    Compare := 0;
  end;

  if not FSortAscending then
    Compare := -Compare;

end;

end.
