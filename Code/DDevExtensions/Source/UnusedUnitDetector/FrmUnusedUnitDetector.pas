{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmUnusedUnitDetector;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Menus, Clipbrd, Generics.Collections,
  Generics.Defaults, FrmBase, UnusedUnitDetector, ToolsAPI;

type
  TFormUnusedUnitDetector = class( TFormBase )
    pnlTop: TPanel;
    pnlBottom: TGridPanel;
    btnClose: TButton;
    btnScan: TButton;
    ListView: TListView;
    lblProgress: TLabel;
    PopupMenu: TPopupMenu;
    mnuCopyToClipboard: TMenuItem;
    mnuAddToIgnoreList: TMenuItem;
    N1: TMenuItem;
    mnuOpenFile: TMenuItem;
    btnExport: TButton;
    SaveDialog: TSaveDialog;
    lblSummary: TLabel;
    procedure btnCloseClick( Sender: TObject );
    procedure btnScanClick( Sender: TObject );
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    procedure FormCreate( Sender: TObject );
    procedure FormDestroy( Sender: TObject );
    procedure ListViewDblClick( Sender: TObject );
    procedure mnuCopyToClipboardClick( Sender: TObject );
    procedure mnuAddToIgnoreListClick( Sender: TObject );
    procedure mnuOpenFileClick( Sender: TObject );
    procedure btnExportClick( Sender: TObject );
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
  private
    FAnalyzer: TUnitAnalyzer;
    FUnusedUnits: TArray<TUnusedUnitInfo>;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    procedure PopulateList;
    procedure AnalyzerProgress( Sender: TObject );
    procedure OpenSelectedFile;
  public
    class procedure Execute;
  end;

var
  FormInstance: TFormUnusedUnitDetector = nil;

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

class procedure TFormUnusedUnitDetector.Execute;
begin

  if FormInstance <> nil then
  begin
    FormInstance.Show;
    FormInstance.BringToFront;
    Exit;
  end;

  FormInstance := TFormUnusedUnitDetector.Create( Application );
  FormInstance.Show;

end;

procedure TFormUnusedUnitDetector.FormClose( Sender: TObject; var Action: TCloseAction );
begin

  FormInstance := nil;
  Action       := caFree;

end;

procedure TFormUnusedUnitDetector.FormCreate( Sender: TObject );
begin

  FAnalyzer      := TUnitAnalyzer.Create;
  FSortColumn    := 0;
  FSortAscending := True;

end;

procedure TFormUnusedUnitDetector.FormDestroy( Sender: TObject );
begin

  FAnalyzer.Free;

end;

procedure TFormUnusedUnitDetector.AnalyzerProgress( Sender: TObject );
begin

  if Sender is TUnitAnalyzer then
    lblProgress.Caption := 'Analysing: ' + TUnitAnalyzer( Sender ).ProgressFileName;

  Application.ProcessMessages;

end;

procedure TFormUnusedUnitDetector.btnCloseClick( Sender: TObject );
begin

  Close;

end;

procedure TFormUnusedUnitDetector.btnScanClick( Sender: TObject );
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
    lblProgress.Caption := 'Scanning project...';
    lblProgress.Visible := True;
    lblSummary.Visible  := False;
    Application.ProcessMessages;

    FAnalyzer.AnalyzeProject( Project, FUnusedUnits, AnalyzerProgress );
    PopulateList;

    lblProgress.Visible := False;
    lblSummary.Caption  := Format( 'Found %d potentially unused unit references', [ Length( FUnusedUnits ) ] );
    lblSummary.Visible  := True;
  finally
    btnScan.Enabled := True;
    Screen.Cursor   := crDefault;
  end;

end;

procedure TFormUnusedUnitDetector.PopulateList;
var
  UnusedInfo: TUnusedUnitInfo;
  Item: TListItem;
begin

  ListView.Items.BeginUpdate;

  try
    ListView.Items.Clear;

    for UnusedInfo in FUnusedUnits do
    begin
      Item         := ListView.Items.Add;
      Item.Caption := UnusedInfo.SourceUnit;
      Item.SubItems.Add( UnusedInfo.UnusedUnit );

      if UnusedInfo.IsInterface then
        Item.SubItems.Add( 'interface' )
      else
        Item.SubItems.Add( 'implementation' );

      Item.SubItems.Add( IntToStr( UnusedInfo.LineNumber ) );
      Item.Data := Pointer( NativeInt( ListView.Items.Count - 1 ) );
    end;
  finally
    ListView.Items.EndUpdate;
  end;

end;

procedure TFormUnusedUnitDetector.ListViewColumnClick( Sender: TObject;
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

procedure TFormUnusedUnitDetector.ListViewCompare( Sender: TObject; Item1,
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
  if FSortColumn = 3 then
    Compare := StrToIntDef( S1, 0 ) - StrToIntDef( S2, 0 )
  else
    Compare := CompareText( S1, S2 );

  if ( not FSortAscending ) then
    Compare := -Compare;

end;

procedure TFormUnusedUnitDetector.ListViewDblClick( Sender: TObject );
begin

  OpenSelectedFile;

end;

procedure TFormUnusedUnitDetector.OpenSelectedFile;
var
  Idx: Integer;
  UnusedInfo: TUnusedUnitInfo;
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  I: Integer;
begin

  if ListView.Selected = nil then
    Exit;

  Idx := NativeInt( ListView.Selected.Data );

  if ( Idx < 0 ) or ( Idx >= Length( FUnusedUnits ) ) then
    Exit;

  UnusedInfo := FUnusedUnits[ Idx ];

  if Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
  begin
    Module := ModuleServices.OpenModule( UnusedInfo.SourceFileName );

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
            EditView.SetTopLeft( UnusedInfo.LineNumber, 1 );
            EditView.Center( UnusedInfo.LineNumber, 1 );
          end;

          Break;
        end;
      end;
    end;
  end;

end;

procedure TFormUnusedUnitDetector.mnuOpenFileClick( Sender: TObject );
begin

  OpenSelectedFile;

end;

procedure TFormUnusedUnitDetector.mnuCopyToClipboardClick( Sender: TObject );
var
  SL: TStringList;
  Item: TListItem;
begin

  SL := TStringList.Create;

  try
    SL.Add( 'Source Unit'#9'Unused Unit'#9'Section'#9'Line' );

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

procedure TFormUnusedUnitDetector.mnuAddToIgnoreListClick( Sender: TObject );
var
  Idx: Integer;
  UnusedInfo: TUnusedUnitInfo;
begin

  if ListView.Selected = nil then
    Exit;

  Idx := NativeInt( ListView.Selected.Data );

  if ( Idx < 0 ) or ( Idx >= Length( FUnusedUnits ) ) then
    Exit;

  UnusedInfo := FUnusedUnits[ Idx ];

  if UnusedUnitDetectorPlugin <> nil then
  begin
    UnusedUnitDetectorPlugin.IgnoreList.Add( UnusedInfo.UnusedUnit );
    UnusedUnitDetectorPlugin.Save;
    ShowMessage( Format( '"%s" added to ignore list. Re-scan to update results.', [ UnusedInfo.UnusedUnit ] ) );
  end;

end;

procedure TFormUnusedUnitDetector.btnExportClick( Sender: TObject );
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
      SL.Add( 'Source Unit,Unused Unit,Section,Line' );

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
