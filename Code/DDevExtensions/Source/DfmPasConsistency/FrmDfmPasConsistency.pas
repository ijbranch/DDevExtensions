{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit FrmDfmPasConsistency;

/// <summary>
/// Singleton results form for the DFM/PAS Consistency plugin. Initiates project-wide scans,
/// presents inconsistencies in a sortable, filterable list view, and supports navigation,
/// clipboard copy, and CSV export.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Clipbrd, System.Generics.Collections,
  FrmBase, DfmPasConsistency, ToolsAPI;

type
  /// <summary>Filter applied to the displayed inconsistency list.</summary>
  TFilterMode = (
    /// <summary>Show every inconsistency.</summary>
    fmAll,
    /// <summary>Show only input controls that typically need PAS declarations.</summary>
    fmInputControls,
    /// <summary>Show only non-input/passive controls.</summary>
    fmPassiveControls
  );

  /// <summary>Singleton results form for the DFM/PAS Consistency plugin.</summary>
  TFormDfmPasConsistency = class(TFormBase)
    /// <summary>Top toolbar panel.</summary>
    pnlTop: TPanel;
    /// <summary>Bottom action-button panel.</summary>
    pnlBottom: TGridPanel;
    /// <summary>Closes the form.</summary>
    btnClose: TButton;
    /// <summary>Initiates a project-wide scan.</summary>
    btnScan: TButton;
    /// <summary>List view displaying inconsistencies.</summary>
    ListView: TListView;
    /// <summary>Status text shown while scanning.</summary>
    lblProgress: TLabel;
    /// <summary>Context menu attached to the list view.</summary>
    PopupMenu: TPopupMenu;
    /// <summary>Copies the selected (or all) results to the clipboard as TSV.</summary>
    mnuCopyToClipboard: TMenuItem;
    /// <summary>Separator menu item.</summary>
    N1: TMenuItem;
    /// <summary>Navigates the IDE to the selected inconsistency.</summary>
    mnuOpenFile: TMenuItem;
    /// <summary>Exports the visible results to CSV.</summary>
    btnExport: TButton;
    /// <summary>File-save dialog used by <see cref="btnExport"/>.</summary>
    SaveDialog: TSaveDialog;
    /// <summary>Result summary text.</summary>
    lblSummary: TLabel;
    /// <summary>Label for <see cref="cboFilter"/>.</summary>
    lblFilter: TLabel;
    /// <summary>Combo controlling the active <see cref="TFilterMode"/>.</summary>
    cboFilter: TComboBox;
    /// <summary>OnClick handler for <see cref="btnClose"/>.</summary>
    procedure btnCloseClick(Sender: TObject);
    /// <summary>OnClick handler for <see cref="btnScan"/> — runs a project scan.</summary>
    procedure btnScanClick(Sender: TObject);
    /// <summary>Initialises sort state and the default filter mode.</summary>
    procedure FormCreate(Sender: TObject);
    /// <summary>Clears the result set when the form closes.</summary>
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    /// <summary>Clears the singleton reference when the form is destroyed.</summary>
    procedure FormDestroy(Sender: TObject);
    /// <summary>Opens the file referenced by the double-clicked row.</summary>
    procedure ListViewDblClick(Sender: TObject);
    /// <summary>Context-menu handler that copies result data to the clipboard.</summary>
    procedure mnuCopyToClipboardClick(Sender: TObject);
    /// <summary>Context-menu handler that opens the source file at the relevant line.</summary>
    procedure mnuOpenFileClick(Sender: TObject);
    /// <summary>Exports the visible results to a CSV file.</summary>
    procedure btnExportClick(Sender: TObject);
    /// <summary>Cycles sort direction when a column header is clicked.</summary>
    procedure ListViewColumnClick(Sender: TObject; Column: TListColumn);
    /// <summary>Custom comparator with numeric sort support for the line-number columns.</summary>
    procedure ListViewCompare(Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer);
    /// <summary>Updates <see cref="FFilterMode"/> and refreshes the list.</summary>
    procedure cboFilterChange(Sender: TObject);
  private
    /// <summary>Latest scan results.</summary>
    FResults: TArray<TInconsistencyInfo>;
    /// <summary>Index of the column currently being sorted.</summary>
    FSortColumn: Integer;
    /// <summary>Sort direction flag.</summary>
    FSortAscending: Boolean;
    /// <summary>Currently active filter mode.</summary>
    FFilterMode: TFilterMode;
    /// <summary>Returns <c>True</c> when <paramref name="TypeName"/> looks like a user-input control.</summary>
    /// <param name="TypeName">Component type name to classify.</param>
    function IsInputControl(const TypeName: string): Boolean;
    /// <summary>Rebuilds the list view from <see cref="FResults"/> using <see cref="FFilterMode"/>.</summary>
    procedure PopulateList;
    /// <summary>
    /// Opens the file/line of the currently selected list item. For "missing in PAS" entries,
    /// attempts to launch the form designer and select the offending component.
    /// </summary>
    procedure OpenSelectedFile;
  public
    /// <summary>Displays the singleton form, creating it if required.</summary>
    /// <returns><c>True</c> when the form was shown.</returns>
    class function Execute: Boolean;
  end;

implementation

{$R *.dfm}

uses
  ToolsAPIHelpers, DesignIntf;

function SafeGetSubItem(Item: TListItem; Index: Integer): string;
begin
  if (Item <> nil) and (Index < Item.SubItems.Count) then
    Result := Item.SubItems[Index]
  else
    Result := '';
end;

/// <summary>Escapes a value for an RFC 4180 quoted CSV field by doubling any embedded double-quotes.</summary>
function CsvField(const Value: string): string;
begin
  Result := System.SysUtils.StringReplace(Value, '"', '""', [rfReplaceAll]);
end;

function InconsistencyTypeToStr(IT: TInconsistencyType): string;
begin
  case IT of
    itMissingInPas: Result := 'Missing in PAS';
    itMissingInDfm: Result := 'Missing in DFM';
    itTypeMismatch: Result := 'Type mismatch';
  else
    Result := 'Unknown';
  end;
end;

var
  FormDfmPasConsistencyInstance: TFormDfmPasConsistency = nil;

class function TFormDfmPasConsistency.Execute: Boolean;
begin
  // Use singleton pattern - create once, reuse on subsequent calls
  if FormDfmPasConsistencyInstance = nil then
    FormDfmPasConsistencyInstance := TFormDfmPasConsistency.Create(Application);

  FormDfmPasConsistencyInstance.Show;
  FormDfmPasConsistencyInstance.BringToFront;
  Result := True;
end;

procedure TFormDfmPasConsistency.FormCreate(Sender: TObject);
begin
  FSortColumn := 0;
  FSortAscending := True;
  FFilterMode := fmAll;
end;

procedure TFormDfmPasConsistency.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  // Clear results when dialog is closed
  ListView.Items.Clear;
  SetLength(FResults, 0);
  lblSummary.Visible := False;
  lblProgress.Visible := False;
end;

procedure TFormDfmPasConsistency.FormDestroy(Sender: TObject);
begin
  // Clear singleton reference when form is destroyed
  if FormDfmPasConsistencyInstance = Self then
    FormDfmPasConsistencyInstance := nil;
end;

function TFormDfmPasConsistency.IsInputControl(const TypeName: string): Boolean;
var
  UpperType: string;
begin
  // Input controls - components that typically need PAS declarations
  // because code usually reads/writes their values
  UpperType := UpperCase(TypeName);

  Result :=
    // Standard VCL input controls
    (Pos('TEDIT', UpperType) > 0) or
    (Pos('TMEMO', UpperType) > 0) or
    (Pos('TRICHEDIT', UpperType) > 0) or
    (Pos('TMASKEDIT', UpperType) > 0) or
    (Pos('TCOMBOBOX', UpperType) > 0) or
    (Pos('TLISTBOX', UpperType) > 0) or
    (Pos('TCHECKBOX', UpperType) > 0) or
    (Pos('TRADIOBUTTON', UpperType) > 0) or
    (Pos('TRADIOGROUP', UpperType) > 0) or
    (Pos('TCHECKLISTBOX', UpperType) > 0) or
    (Pos('TDATETIMEPICKER', UpperType) > 0) or
    (Pos('TMONTHCALENDAR', UpperType) > 0) or
    (Pos('TSPINEDIT', UpperType) > 0) or
    (Pos('TUPDOWN', UpperType) > 0) or
    (Pos('TTRACKBAR', UpperType) > 0) or
    (Pos('TSCROLLBAR', UpperType) > 0) or
    (Pos('TLISTVIEW', UpperType) > 0) or
    (Pos('TTREEVIEW', UpperType) > 0) or
    (Pos('TSTRINGGRID', UpperType) > 0) or
    (Pos('TDRAWGRID', UpperType) > 0) or
    (Pos('TVALUELIST', UpperType) > 0) or
    // Buttons (often need code access)
    (Pos('TBUTTON', UpperType) > 0) or
    (Pos('TBITBTN', UpperType) > 0) or
    (Pos('TSPEEDBUTTON', UpperType) > 0) or
    // Third-party common patterns
    (Pos('LABELED', UpperType) > 0) or  // TLMDLabeledEdit, etc.
    (Pos('TCX', UpperType) = 1) or       // DevExpress cxEditors
    (Pos('TDB', UpperType) = 1);         // Data-aware controls
end;

procedure TFormDfmPasConsistency.cboFilterChange(Sender: TObject);
begin
  case cboFilter.ItemIndex of
    0: FFilterMode := fmAll;
    1: FFilterMode := fmInputControls;
    2: FFilterMode := fmPassiveControls;
  else
    FFilterMode := fmAll;
  end;
  PopulateList;
end;

procedure TFormDfmPasConsistency.btnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TFormDfmPasConsistency.btnScanClick(Sender: TObject);
var
  Project: IOTAProject;
  ModuleInfo: IOTAModuleInfo;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  I, J: Integer;
  PasSource, DfmSource: UTF8String;
  UnitResults: TArray<TInconsistencyInfo>;
  AllResults: TList<TInconsistencyInfo>;
  ProjectName: string;
  DfmFileName: string;
begin
  Project := GetActiveProject;
  if Project = nil then
  begin
    ShowMessage('No active project.');
    Exit;
  end;

  ProjectName := ExtractFileName(Project.FileName);

  AllResults := TList<TInconsistencyInfo>.Create;
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

        // Only scan form units (PAS files with corresponding DFM)
        if not SameText(ExtractFileExt(ModuleInfo.FileName), '.pas') then
          Continue;

        DfmFileName := ChangeFileExt(ModuleInfo.FileName, '.dfm');
        if not FileExists(DfmFileName) then
          Continue;

        lblProgress.Caption := 'Scanning: ' + ExtractFileName(ModuleInfo.FileName);
        Application.ProcessMessages;

        try
        // Get PAS source
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
            PasSource := GetEditorSource(SourceEditor)
          else
            PasSource := '';
        end
        else
          PasSource := '';

        // If no editor source, try to read from file
        if (PasSource = '') and FileExists(ModuleInfo.FileName) then
        begin
          with TStringList.Create do
          try
            LoadFromFile(ModuleInfo.FileName);
            PasSource := UTF8String(Text);
          finally
            Free;
          end;
        end;

        // Read DFM source
        DfmSource := '';
        if FileExists(DfmFileName) then
        begin
          with TStringList.Create do
          try
            LoadFromFile(DfmFileName);
            DfmSource := UTF8String(Text);
          finally
            Free;
          end;
        end;

        if (PasSource <> '') and (DfmSource <> '') then
        begin
          UnitResults := TDfmPasConsistencyPlugin.AnalyzeUnit(PasSource, DfmSource, ModuleInfo.FileName);
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
      lblSummary.Caption := Format('Found %d inconsistency(ies) in %s',
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

procedure TFormDfmPasConsistency.PopulateList;
var
  Info: TInconsistencyInfo;
  Item: TListItem;
  DfmLine, PasLine: string;
  IsInput: Boolean;
  DisplayCount: Integer;
begin
  ListView.Items.BeginUpdate;
  try
    ListView.Items.Clear;
    DisplayCount := 0;

    for Info in FResults do
    begin
      // Apply filter - use DfmType if available, otherwise PasType
      if Info.DfmType <> '' then
        IsInput := IsInputControl(Info.DfmType)
      else
        IsInput := IsInputControl(Info.PasType);
      case FFilterMode of
        fmInputControls:
          if not IsInput then
            Continue;
        fmPassiveControls:
          if IsInput then
            Continue;
      end;

      Inc(DisplayCount);
      Item := ListView.Items.Add;
      Item.Caption := Info.UnitName;
      Item.SubItems.Add(Info.ComponentName);
      Item.SubItems.Add(InconsistencyTypeToStr(Info.InconsistencyType));
      // PAS Type
      Item.SubItems.Add(Info.PasType);
      // PAS Line (immediately after PAS Type)
      if Info.PasLineNumber > 0 then
        PasLine := IntToStr(Info.PasLineNumber)
      else
        PasLine := '-';
      Item.SubItems.Add(PasLine);
      // DFM Type
      Item.SubItems.Add(Info.DfmType);
      // DFM Line
      if Info.DfmLineNumber > 0 then
        DfmLine := IntToStr(Info.DfmLineNumber)
      else
        DfmLine := '-';
      Item.SubItems.Add(DfmLine);
      // Store DFM filename for navigation (DFM is primary for Missing in PAS)
      Item.SubItems.Add(Info.DfmFileName);
      // Store PAS filename as a hidden subitem (index 7). Previously a PChar into
      // the managed string held by FResults was stashed in Item.Data, which
      // dangles if FResults is ever reassigned - store the value instead.
      Item.SubItems.Add(Info.PasFileName);
    end;
  finally
    ListView.Items.EndUpdate;
  end;

  // Update summary to show the filtered count, restoring the full count for 'All'.
  if FFilterMode <> fmAll then
    lblSummary.Caption := Format('Showing %d of %d inconsistency(ies)',
      [DisplayCount, Length(FResults)])
  else
    lblSummary.Caption := Format('Found %d inconsistency(ies)', [Length(FResults)]);
end;

procedure TFormDfmPasConsistency.ListViewColumnClick(Sender: TObject;
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

procedure TFormDfmPasConsistency.ListViewCompare(Sender: TObject; Item1,
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
  else if FSortColumn in [4, 6] then // PAS Line or DFM Line - numeric sort
  begin
    SubIdx := FSortColumn - 1;
    N1 := StrToIntDef(SafeGetSubItem(Item1, SubIdx), 0);
    N2 := StrToIntDef(SafeGetSubItem(Item2, SubIdx), 0);
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

procedure TFormDfmPasConsistency.ListViewDblClick(Sender: TObject);
begin
  OpenSelectedFile;
end;

procedure TFormDfmPasConsistency.OpenSelectedFile;
var
  Item: TListItem;
  FileName: string;
  DfmFileName: string;
  LineNum: Integer;
  PasLine: string;
  ComponentName: string;
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  FormEditor: IOTAFormEditor;
  NTAFormEditor: INTAFormEditor;
  Designer: IDesigner;
  OTAComponent: IOTAComponent;
  Component: TComponent;
  EditView: IOTAEditView;
  I: Integer;
  FormSelected: Boolean;
begin
  Item := ListView.Selected;
  if Item = nil then
    Exit;

  // SubItems: 0=Component, 1=Issue, 2=PasType, 3=PasLine, 4=DfmType, 5=DfmLine, 6=DfmFileName, 7=PasFileName
  PasLine := SafeGetSubItem(Item, 3);
  ComponentName := SafeGetSubItem(Item, 0);
  DfmFileName := SafeGetSubItem(Item, 6);

  // If PAS line exists, open PAS file at that line
  if (PasLine <> '') and (PasLine <> '-') then
  begin
    FileName := SafeGetSubItem(Item, 7);
    LineNum := StrToIntDef(PasLine, 0);
    FormSelected := False;
  end
  else
  begin
    // For "Missing in PAS" - try to open form designer and select component
    FileName := SafeGetSubItem(Item, 7); // PAS file to load form
    LineNum := StrToIntDef(SafeGetSubItem(Item, 5), 0);
    FormSelected := False;

    try
      if FileExists(FileName) and Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then
      begin
        Module := ModuleServices.OpenModule(FileName);
        if Module <> nil then
        begin
          // Try to get form editor and select the component
          for I := 0 to Module.ModuleFileCount - 1 do
          begin
            if Supports(Module.ModuleFileEditors[I], IOTAFormEditor, FormEditor) then
            begin
              // Find the component by name
              OTAComponent := FormEditor.FindComponent(ComponentName);
              if OTAComponent <> nil then
              begin
                // Get the actual TComponent
                Component := TComponent(OTAComponent.GetComponentHandle);
                if Component <> nil then
                begin
                  // Get the designer to select the component
                  if Supports(FormEditor, INTAFormEditor, NTAFormEditor) then
                  begin
                    Designer := NTAFormEditor.FormDesigner;
                    if Designer <> nil then
                    begin
                      FormEditor.Show;
                      Designer.SelectComponent(Component);
                      FormSelected := True;
                    end;
                  end;
                end;
              end;
              Break;
            end;
          end;
        end;
      end;
    except
      // If form designer selection fails, fall back to DFM text
      FormSelected := False;
    end;

    // If form selection failed, use DFM file for text navigation
    if not FormSelected then
      FileName := DfmFileName;
  end;

  // If we already selected in form designer, we're done
  if FormSelected then
    Exit;

  // Fall back to opening file as text
  if FileName = '' then
  begin
    ShowMessage('No source file is associated with this entry.');
    Exit;
  end;

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
          if SourceEditor.EditViewCount > 0 then
          begin
            EditView := SourceEditor.EditViews[0];
            if EditView <> nil then
            begin
              // Only move the caret when a real source line is known; otherwise
              // just open the file rather than jumping to a misleading line 1.
              if LineNum > 0 then
              begin
                EditView.Position.Move(LineNum, 1);
                EditView.MoveViewToCursor;
              end;
              EditView.Paint;
            end;
          end;
          Break;
        end;
      end;
    end;
  end;
end;

procedure TFormDfmPasConsistency.mnuOpenFileClick(Sender: TObject);
begin
  OpenSelectedFile;
end;

procedure TFormDfmPasConsistency.mnuCopyToClipboardClick(Sender: TObject);
var
  SL: TStringList;
  Item: TListItem;
begin
  SL := TStringList.Create;
  try
    SL.Add('Unit'#9'Component'#9'Issue'#9'PAS Type'#9'PAS Line'#9'DFM Type'#9'DFM Line'#9'File');

    for Item in ListView.Items do
    begin
      if Item.Selected or (ListView.SelCount = 0) then
        SL.Add(Format('%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s', [
          Item.Caption,
          SafeGetSubItem(Item, 0),
          SafeGetSubItem(Item, 1),
          SafeGetSubItem(Item, 2),
          SafeGetSubItem(Item, 3),
          SafeGetSubItem(Item, 4),
          SafeGetSubItem(Item, 5),
          SafeGetSubItem(Item, 6)
        ]));
    end;

    Clipboard.AsText := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure TFormDfmPasConsistency.btnExportClick(Sender: TObject);
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
      SL.Add('Unit,Component,Issue,PAS Type,PAS Line,DFM Type,DFM Line,File');

      for Item in ListView.Items do
      begin
        SL.Add(Format('"%s","%s","%s","%s","%s","%s","%s","%s"', [
          CsvField(Item.Caption),
          CsvField(SafeGetSubItem(Item, 0)),
          CsvField(SafeGetSubItem(Item, 1)),
          CsvField(SafeGetSubItem(Item, 2)),
          CsvField(SafeGetSubItem(Item, 3)),
          CsvField(SafeGetSubItem(Item, 4)),
          CsvField(SafeGetSubItem(Item, 5)),
          CsvField(SafeGetSubItem(Item, 6))
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
