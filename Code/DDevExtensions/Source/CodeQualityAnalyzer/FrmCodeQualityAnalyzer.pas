{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit FrmCodeQualityAnalyzer;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Menus, Clipbrd, Generics.Collections,
  FrmBase, CodeQualityAnalyzer, ToolsAPI;

type
  TFormCodeQualityAnalyzer = class( TForm )
    pnlTop: TPanel;
    pnlBottom: TGridPanel;
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
    cboCategory: TComboBox;
    lblCategory: TLabel;
    cboSeverity: TComboBox;
    lblSeverity: TLabel;
    procedure btnCloseClick( Sender: TObject );
    procedure btnScanClick( Sender: TObject );
    procedure FormCreate( Sender: TObject );
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    procedure FormDestroy( Sender: TObject );
    procedure ListViewDblClick( Sender: TObject );
    procedure mnuCopyToClipboardClick( Sender: TObject );
    procedure mnuOpenFileClick( Sender: TObject );
    procedure btnExportClick( Sender: TObject );
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    procedure cboCategoryChange( Sender: TObject );
    procedure cboSeverityChange( Sender: TObject );
  private
    FResults: TArray<TCodeQualityIssue>;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    procedure PopulateList;
    procedure OpenSelectedFile;
    procedure ApplyFilters;
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

var
  FormCodeQualityAnalyzerInstance: TFormCodeQualityAnalyzer = nil;

class function TFormCodeQualityAnalyzer.Execute: Boolean;
begin
  // Use singleton pattern - create once, reuse on subsequent calls
  if FormCodeQualityAnalyzerInstance = nil then
    FormCodeQualityAnalyzerInstance := TFormCodeQualityAnalyzer.Create( Application );

  FormCodeQualityAnalyzerInstance.Show;
  FormCodeQualityAnalyzerInstance.BringToFront;
  Result := True;
end;

procedure TFormCodeQualityAnalyzer.FormCreate( Sender: TObject );
begin
  FSortColumn := 0;
  FSortAscending := True;

  // Populate category filter
  cboCategory.Items.Clear;
  cboCategory.Items.Add( '(All)' );
  cboCategory.Items.Add( 'Magic Number' );
  cboCategory.Items.Add( 'Hardcoded String' );
  cboCategory.Items.Add( 'Commented Code' );
  cboCategory.Items.Add( 'Empty Except' );
  cboCategory.Items.Add( 'Catch-All Exception' );
  cboCategory.Items.Add( 'Missing Try/Finally' );
  cboCategory.Items.Add( 'Memory Leak' );
  cboCategory.ItemIndex := 0;

  // Populate severity filter
  cboSeverity.Items.Clear;
  cboSeverity.Items.Add( '(All)' );
  cboSeverity.Items.Add( 'Info' );
  cboSeverity.Items.Add( 'Warning' );
  cboSeverity.Items.Add( 'Error' );
  cboSeverity.ItemIndex := 0;
end;

procedure TFormCodeQualityAnalyzer.FormClose( Sender: TObject; var Action: TCloseAction );
begin
  // Clear results when dialog is closed
  ListView.Items.Clear;
  SetLength( FResults, 0 );
  lblSummary.Visible := False;
  lblProgress.Visible := False;
end;

procedure TFormCodeQualityAnalyzer.FormDestroy( Sender: TObject );
begin
  // Clear singleton reference when form is destroyed
  if FormCodeQualityAnalyzerInstance = Self then
    FormCodeQualityAnalyzerInstance := nil;
end;

procedure TFormCodeQualityAnalyzer.btnCloseClick( Sender: TObject );
begin
  Close;
end;

procedure TFormCodeQualityAnalyzer.btnScanClick( Sender: TObject );
var
  Project: IOTAProject;
  ModuleInfo: IOTAModuleInfo;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  I, J: Integer;
  Source: UTF8String;
  UnitResults: TArray<TCodeQualityIssue>;
  AllResults: TList<TCodeQualityIssue>;
  ProjectName: string;
begin
  Project := GetActiveProject;
  if Project = nil then
  begin
    ShowMessage( 'No active project.' );
    Exit;
  end;

  // Reset filters to show all results
  cboCategory.ItemIndex := 0;
  cboSeverity.ItemIndex := 0;

  ProjectName := ExtractFileName( Project.FileName );

  AllResults := TList<TCodeQualityIssue>.Create;
  try
    Screen.Cursor := crHourGlass;
    btnScan.Enabled := False;
    try
      lblProgress.Caption := 'Scanning ' + ProjectName + '...';
      lblProgress.Visible := True;
      lblSummary.Visible := False;
      Application.ProcessMessages;

      for I := 0 to Project.GetModuleCount - 1 do
      begin
        ModuleInfo := Project.GetModule( I );
        if ModuleInfo = nil then
          Continue;

        // Only scan Pascal files
        if not ( SameText( ExtractFileExt( ModuleInfo.FileName ), '.pas' ) or
                 SameText( ExtractFileExt( ModuleInfo.FileName ), '.pp' ) ) then
          Continue;

        lblProgress.Caption := 'Scanning: ' + ExtractFileName( ModuleInfo.FileName );
        Application.ProcessMessages;

        // Try to get source from open editor first
        Module := ModuleInfo.OpenModule;
        if Module <> nil then
        begin
          SourceEditor := nil;
          for J := 0 to Module.ModuleFileCount - 1 do
          begin
            if Supports( Module.ModuleFileEditors[ J ], IOTASourceEditor, SourceEditor ) then
              Break;
          end;

          if SourceEditor <> nil then
            Source := GetEditorSource( SourceEditor )
          else
            Source := '';
        end
        else
          Source := '';

        // If no editor source, try to read from file
        if ( Source = '' ) and FileExists( ModuleInfo.FileName ) then
        begin
          with TStringList.Create do
          try
            LoadFromFile( ModuleInfo.FileName );
            Source := UTF8String( Text );
          finally
            Free;
          end;
        end;

        if Source <> '' then
        begin
          UnitResults := TCodeQualityAnalyzerPlugin.AnalyzeUnit( Source, ModuleInfo.FileName,
            CodeQualityAnalyzerPlugin );
          for J := 0 to Length( UnitResults ) - 1 do
            AllResults.Add( UnitResults[ J ] );
        end;
      end;

      FResults := AllResults.ToArray;
      PopulateList;

      lblProgress.Visible := False;
      lblSummary.Caption := Format( 'Found %d issue(s) in %s',
        [ Length( FResults ), ProjectName ] );
      lblSummary.Visible := True;
    finally
      btnScan.Enabled := True;
      Screen.Cursor := crDefault;
    end;
  finally
    AllResults.Free;
  end;
end;

procedure TFormCodeQualityAnalyzer.PopulateList;
begin
  ApplyFilters;
end;

procedure TFormCodeQualityAnalyzer.ApplyFilters;
var
  Issue: TCodeQualityIssue;
  Item: TListItem;
  CategoryFilter: string;
  SeverityFilter: string;
  ShowItem: Boolean;
  VisibleCount: Integer;
begin
  ListView.Items.BeginUpdate;
  try
    ListView.Items.Clear;

    CategoryFilter := cboCategory.Text;
    SeverityFilter := cboSeverity.Text;
    VisibleCount := 0;

    for Issue in FResults do
    begin
      ShowItem := True;

      // Apply category filter
      if ( CategoryFilter <> '(All)' ) and
         ( IssueCategoryToString( Issue.Category ) <> CategoryFilter ) then
        ShowItem := False;

      // Apply severity filter
      if ShowItem and ( SeverityFilter <> '(All)' ) and
         ( IssueSeverityToString( Issue.Severity ) <> SeverityFilter ) then
        ShowItem := False;

      if ShowItem then
      begin
        Item := ListView.Items.Add;
        Item.Caption := Issue.UnitName;
        Item.SubItems.Add( IntToStr( Issue.Line ) );
        Item.SubItems.Add( IssueCategoryToString( Issue.Category ) );
        Item.SubItems.Add( IssueSeverityToString( Issue.Severity ) );
        Item.SubItems.Add( Issue.Description );
        Item.SubItems.Add( Issue.FileName );
        Inc( VisibleCount );
      end;
    end;

    // Update summary with filter info
    if ( CategoryFilter <> '(All)' ) or ( SeverityFilter <> '(All)' ) then
      lblSummary.Caption := Format( 'Showing %d of %d issue(s)',
        [ VisibleCount, Length( FResults ) ] )
    else
      lblSummary.Caption := Format( 'Found %d issue(s)', [ Length( FResults ) ] );

  finally
    ListView.Items.EndUpdate;
  end;
end;

procedure TFormCodeQualityAnalyzer.cboCategoryChange( Sender: TObject );
begin
  ApplyFilters;
end;

procedure TFormCodeQualityAnalyzer.cboSeverityChange( Sender: TObject );
begin
  ApplyFilters;
end;

procedure TFormCodeQualityAnalyzer.ListViewColumnClick( Sender: TObject;
  Column: TListColumn );
begin
  if FSortColumn = Column.Index then
    FSortAscending := not FSortAscending
  else
  begin
    FSortColumn := Column.Index;
    FSortAscending := True;
  end;
  ListView.AlphaSort;
end;

procedure TFormCodeQualityAnalyzer.ListViewCompare( Sender: TObject; Item1,
  Item2: TListItem; Data: Integer; var Compare: Integer );
var
  S1, S2: string;
  SubIdx: Integer;
  N1, N2: Integer;
begin
  if FSortColumn = 0 then
  begin
    S1 := Item1.Caption;
    S2 := Item2.Caption;
    Compare := CompareText( S1, S2 );
  end
  else if FSortColumn = 1 then // Line number - numeric sort
  begin
    N1 := StrToIntDef( SafeGetSubItem( Item1, 0 ), 0 );
    N2 := StrToIntDef( SafeGetSubItem( Item2, 0 ), 0 );
    Compare := N1 - N2;
  end
  else
  begin
    SubIdx := FSortColumn - 1;
    S1 := SafeGetSubItem( Item1, SubIdx );
    S2 := SafeGetSubItem( Item2, SubIdx );
    Compare := CompareText( S1, S2 );
  end;

  if not FSortAscending then
    Compare := -Compare;
end;

procedure TFormCodeQualityAnalyzer.ListViewDblClick( Sender: TObject );
begin
  OpenSelectedFile;
end;

procedure TFormCodeQualityAnalyzer.OpenSelectedFile;
var
  Item: TListItem;
  FileName: string;
  LineNum: Integer;
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  I: Integer;
begin
  Item := ListView.Selected;
  if Item = nil then
    Exit;

  FileName := SafeGetSubItem( Item, 4 );  // File path is in SubItems[4]
  LineNum := StrToIntDef( SafeGetSubItem( Item, 0 ), 1 );

  if not FileExists( FileName ) then
  begin
    ShowMessage( 'File not found: ' + FileName );
    Exit;
  end;

  if Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
  begin
    Module := ModuleServices.OpenModule( FileName );
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
            EditView.Position.Move( LineNum, 1 );
            EditView.MoveViewToCursor;
            EditView.Paint;
          end;
          Break;
        end;
      end;
    end;
  end;
end;

procedure TFormCodeQualityAnalyzer.mnuOpenFileClick( Sender: TObject );
begin
  OpenSelectedFile;
end;

procedure TFormCodeQualityAnalyzer.mnuCopyToClipboardClick( Sender: TObject );
var
  SL: TStringList;
  Item: TListItem;
begin
  SL := TStringList.Create;
  try
    SL.Add( 'Unit'#9'Line'#9'Category'#9'Severity'#9'Description'#9'File' );

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

procedure TFormCodeQualityAnalyzer.btnExportClick( Sender: TObject );
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
      SL.Add( 'Unit,Line,Category,Severity,Description,File' );

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
