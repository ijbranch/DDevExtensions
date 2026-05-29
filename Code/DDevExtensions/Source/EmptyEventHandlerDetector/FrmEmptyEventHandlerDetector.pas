{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit FrmEmptyEventHandlerDetector;

/// <summary>
/// Singleton results form for the Empty Event Handler Detector. Initiates project-wide scans and
/// presents the empty handlers in a sortable list view with copy-to-clipboard, CSV export, and
/// double-click navigation to the offending source line.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Clipbrd, System.Generics.Collections,
  FrmBase, EmptyEventHandlerDetector, ToolsAPI;

type
  /// <summary>Singleton results form for the Empty Event Handler Detector.</summary>
  TFormEmptyEventHandlerDetector = class(TFormBase)
    /// <summary>Top toolbar panel.</summary>
    pnlTop: TPanel;
    /// <summary>Bottom action-button panel.</summary>
    pnlBottom: TGridPanel;
    /// <summary>Closes the form.</summary>
    btnClose: TButton;
    /// <summary>Initiates a project-wide scan.</summary>
    btnScan: TButton;
    /// <summary>List view displaying the empty handlers.</summary>
    ListView: TListView;
    /// <summary>Status text shown while scanning.</summary>
    lblProgress: TLabel;
    /// <summary>Context menu attached to the list view.</summary>
    PopupMenu: TPopupMenu;
    /// <summary>Copies the selected (or all) results to the clipboard as TSV.</summary>
    mnuCopyToClipboard: TMenuItem;
    /// <summary>Separator menu item.</summary>
    N1: TMenuItem;
    /// <summary>Opens the source file at the selected handler's line.</summary>
    mnuOpenFile: TMenuItem;
    /// <summary>Exports the visible results to CSV.</summary>
    btnExport: TButton;
    /// <summary>File-save dialog used by <see cref="btnExport"/>.</summary>
    SaveDialog: TSaveDialog;
    /// <summary>Result summary text.</summary>
    lblSummary: TLabel;
    /// <summary>OnClick handler for <see cref="btnClose"/>.</summary>
    procedure btnCloseClick(Sender: TObject);
    /// <summary>OnClick handler for <see cref="btnScan"/> — runs a project scan.</summary>
    procedure btnScanClick(Sender: TObject);
    /// <summary>Initialises sort state.</summary>
    procedure FormCreate(Sender: TObject);
    /// <summary>Clears the result set when the form closes.</summary>
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    /// <summary>Clears the singleton reference when the form is destroyed.</summary>
    procedure FormDestroy(Sender: TObject);
    /// <summary>Opens the file referenced by the double-clicked row.</summary>
    procedure ListViewDblClick(Sender: TObject);
    /// <summary>Context-menu handler that copies result data to the clipboard.</summary>
    procedure mnuCopyToClipboardClick(Sender: TObject);
    /// <summary>Context-menu handler that opens the source file at the handler's line.</summary>
    procedure mnuOpenFileClick(Sender: TObject);
    /// <summary>Exports the visible results to a CSV file.</summary>
    procedure btnExportClick(Sender: TObject);
    /// <summary>Cycles sort direction when a column header is clicked.</summary>
    procedure ListViewColumnClick(Sender: TObject; Column: TListColumn);
    /// <summary>Custom comparator supporting numeric sort on the line-number column.</summary>
    procedure ListViewCompare(Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer);
  private
    /// <summary>Latest scan results.</summary>
    FResults: TArray<TEmptyHandlerInfo>;
    /// <summary>Index of the column currently being sorted.</summary>
    FSortColumn: Integer;
    /// <summary>Sort direction flag.</summary>
    FSortAscending: Boolean;
    /// <summary>Rebuilds the list view from <see cref="FResults"/>.</summary>
    procedure PopulateList;
    /// <summary>Opens the file/line of the currently selected list item in the IDE.</summary>
    procedure OpenSelectedFile;
  public
    /// <summary>Displays the singleton form, creating it if required.</summary>
    /// <returns><c>True</c> when the form was shown.</returns>
    class function Execute: Boolean;
  end;

implementation

{$R *.dfm}

uses
  ToolsAPIHelpers;

function SafeGetSubItem(Item: TListItem; Index: Integer): string;
begin
  if (Item <> nil) and (Index < Item.SubItems.Count) then
    Result := Item.SubItems[Index]
  else
    Result := '';
end;

var
  FormEmptyEventHandlerDetectorInstance: TFormEmptyEventHandlerDetector = nil;

class function TFormEmptyEventHandlerDetector.Execute: Boolean;
begin
  // Use singleton pattern - create once, reuse on subsequent calls
  if FormEmptyEventHandlerDetectorInstance = nil then
    FormEmptyEventHandlerDetectorInstance := TFormEmptyEventHandlerDetector.Create(Application);

  FormEmptyEventHandlerDetectorInstance.Show;
  FormEmptyEventHandlerDetectorInstance.BringToFront;
  Result := True;
end;

procedure TFormEmptyEventHandlerDetector.FormCreate(Sender: TObject);
begin
  FSortColumn := 0;
  FSortAscending := True;
end;

procedure TFormEmptyEventHandlerDetector.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  // Clear results when dialog is closed
  ListView.Items.Clear;
  SetLength(FResults, 0);
  lblSummary.Visible := False;
  lblProgress.Visible := False;
end;

procedure TFormEmptyEventHandlerDetector.FormDestroy(Sender: TObject);
begin
  // Clear singleton reference when form is destroyed
  if FormEmptyEventHandlerDetectorInstance = Self then
    FormEmptyEventHandlerDetectorInstance := nil;
end;

procedure TFormEmptyEventHandlerDetector.btnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TFormEmptyEventHandlerDetector.btnScanClick(Sender: TObject);
var
  Project: IOTAProject;
  ModuleInfo: IOTAModuleInfo;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  I, J: Integer;
  Source: UTF8String;
  UnitResults: TArray<TEmptyHandlerInfo>;
  AllResults: TList<TEmptyHandlerInfo>;
  ProjectName: string;
begin
  Project := GetActiveProject;
  if Project = nil then
  begin
    ShowMessage('No active project.');
    Exit;
  end;

  ProjectName := ExtractFileName(Project.FileName);

  AllResults := TList<TEmptyHandlerInfo>.Create;
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
        ModuleInfo := Project.GetModule(I);
        if ModuleInfo = nil then
          Continue;

        // Only scan Pascal files
        if not (SameText(ExtractFileExt(ModuleInfo.FileName), '.pas') or
                SameText(ExtractFileExt(ModuleInfo.FileName), '.pp')) then
          Continue;

        lblProgress.Caption := 'Scanning: ' + ExtractFileName(ModuleInfo.FileName);
        Application.ProcessMessages;

        Source := '';
        try
          // Try to get source from open editor first
          Module := ModuleInfo.OpenModule;
          if Module <> nil then
          begin
            SourceEditor := nil;
            for J := 0 to Module.ModuleFileCount - 1 do
            begin
              if Supports(Module.ModuleFileEditors[J], IOTASourceEditor, SourceEditor) then
                Break;
            end;

            if SourceEditor <> nil then
              Source := GetEditorSource(SourceEditor);
          end;

          // If no editor source, try to read from file
          if (Source = '') and FileExists(ModuleInfo.FileName) then
          begin
            with TStringList.Create do
            try
              LoadFromFile(ModuleInfo.FileName);
              Source := UTF8String(Text);
            finally
              Free;
            end;
          end;

          if Source <> '' then
          begin
            UnitResults := TEmptyEventHandlerDetectorPlugin.AnalyzeUnit(Source, ModuleInfo.FileName);
            for J := 0 to Length(UnitResults) - 1 do
              AllResults.Add(UnitResults[J]);
          end;
        except
          // One unreadable or malformed module must not abort the whole scan.
          on E: Exception do
            Continue;
        end;
      end;

      FResults := AllResults.ToArray;
      PopulateList;

      lblProgress.Visible := False;
      lblSummary.Caption := Format('Found %d empty event handler(s) in %s',
        [Length(FResults), ProjectName]);
      lblSummary.Visible := True;
    finally
      btnScan.Enabled := True;
      Screen.Cursor := crDefault;
    end;
  finally
    AllResults.Free;
  end;
end;

procedure TFormEmptyEventHandlerDetector.PopulateList;
var
  Info: TEmptyHandlerInfo;
  Item: TListItem;
  FullMethodName: string;
begin
  ListView.Items.BeginUpdate;
  try
    ListView.Items.Clear;

    for Info in FResults do
    begin
      Item := ListView.Items.Add;
      Item.Caption := Info.UnitName;

      if Info.ClassName <> '' then
        FullMethodName := Info.ClassName + '.' + Info.MethodName
      else
        FullMethodName := Info.MethodName;

      Item.SubItems.Add(FullMethodName);
      Item.SubItems.Add(IntToStr(Info.LineNumber));
      Item.SubItems.Add(Info.FileName);
    end;
  finally
    ListView.Items.EndUpdate;
  end;
end;

procedure TFormEmptyEventHandlerDetector.ListViewColumnClick(Sender: TObject;
  Column: TListColumn);
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

procedure TFormEmptyEventHandlerDetector.ListViewCompare(Sender: TObject; Item1,
  Item2: TListItem; Data: Integer; var Compare: Integer);
var
  S1, S2: string;
  SubIdx: Integer;
  N1, N2: Integer;
begin
  if FSortColumn = 0 then
  begin
    S1 := Item1.Caption;
    S2 := Item2.Caption;
    Compare := CompareText(S1, S2);
  end
  else if FSortColumn = 2 then // Line number - numeric sort
  begin
    N1 := StrToIntDef(SafeGetSubItem(Item1, 1), 0);
    N2 := StrToIntDef(SafeGetSubItem(Item2, 1), 0);
    Compare := N1 - N2;
  end
  else
  begin
    SubIdx := FSortColumn - 1;
    S1 := SafeGetSubItem(Item1, SubIdx);
    S2 := SafeGetSubItem(Item2, SubIdx);
    Compare := CompareText(S1, S2);
  end;

  if not FSortAscending then
    Compare := -Compare;
end;

procedure TFormEmptyEventHandlerDetector.ListViewDblClick(Sender: TObject);
begin
  OpenSelectedFile;
end;

procedure TFormEmptyEventHandlerDetector.OpenSelectedFile;
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

  FileName := SafeGetSubItem(Item, 2); // File path is in SubItems[2]
  LineNum := StrToIntDef(SafeGetSubItem(Item, 1), 1);

  if not FileExists(FileName) then
  begin
    ShowMessage('File not found: ' + FileName);
    Exit;
  end;

  if Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then
  begin
    Module := ModuleServices.OpenModule(FileName);
    if Module <> nil then
    begin
      for I := 0 to Module.ModuleFileCount - 1 do
      begin
        if Supports(Module.ModuleFileEditors[I], IOTASourceEditor, SourceEditor) then
        begin
          SourceEditor.Show;
          EditView := SourceEditor.EditViews[0];
          if EditView <> nil then
          begin
            EditView.Position.Move(LineNum, 1);
            EditView.MoveViewToCursor;
            EditView.Paint;
          end;
          Break;
        end;
      end;
    end;
  end;
end;

procedure TFormEmptyEventHandlerDetector.mnuOpenFileClick(Sender: TObject);
begin
  OpenSelectedFile;
end;

procedure TFormEmptyEventHandlerDetector.mnuCopyToClipboardClick(Sender: TObject);
var
  SL: TStringList;
  Item: TListItem;
begin
  SL := TStringList.Create;
  try
    SL.Add('Unit'#9'Method'#9'Line'#9'File');

    for Item in ListView.Items do
    begin
      if Item.Selected or (ListView.SelCount = 0) then
        SL.Add(Format('%s'#9'%s'#9'%s'#9'%s', [
          Item.Caption,
          SafeGetSubItem(Item, 0),
          SafeGetSubItem(Item, 1),
          SafeGetSubItem(Item, 2)
        ]));
    end;

    Clipboard.AsText := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure TFormEmptyEventHandlerDetector.btnExportClick(Sender: TObject);
var
  SL: TStringList;
  Item: TListItem;
begin
  if ListView.Items.Count = 0 then
  begin
    ShowMessage('No data to export.');
    Exit;
  end;

  if SaveDialog.Execute then
  begin
    SL := TStringList.Create;
    try
      SL.Add('Unit,Method,Line,File');

      for Item in ListView.Items do
      begin
        SL.Add(Format('"%s","%s","%s","%s"', [
          Item.Caption,
          SafeGetSubItem(Item, 0),
          SafeGetSubItem(Item, 1),
          SafeGetSubItem(Item, 2)
        ]));
      end;

      try
        SL.SaveToFile(SaveDialog.FileName);
        ShowMessage(Format('Exported %d items to %s', [ListView.Items.Count, SaveDialog.FileName]));
      except
        on E: Exception do
          ShowMessage('Error saving file: ' + E.Message);
      end;
    finally
      SL.Free;
    end;
  end;
end;

end.
