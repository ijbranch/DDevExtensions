{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmExcelExport;

/// <summary>
/// Modal progress form and helper routine for exporting the contents of a TListView to a
/// new Excel workbook through OLE Automation. The form simply shows a progress bar while
/// the export runs; the underlying ExportListViewToExcel procedure can also be called
/// directly without showing the form.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  System.Variants, Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, System.Win.ComObj;

const
  /// <summary>Posted to the progress form once it is shown, to start the export outside any paint handler.</summary>
  WM_START_EXPORT = WM_USER + 1;

type
  /// <summary>
  /// Progress form shown while ExportListViewToExcel runs. Created via the
  /// ExportListView class method.
  /// </summary>
  TFormExcelExport = class(TForm)
    /// <summary>Label displayed above the progress bar.</summary>
    LblExportText: TLabel;
    /// <summary>Progress bar updated during the export.</summary>
    ProgressBar: TProgressBar;
    /// <summary>Prevents the user from cancelling the dialog before the export completes.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    /// <param name="CanClose">Set False while ModalResult is mrCancel, so the dialog cannot be cancelled.</param>
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    /// <summary>Sheet name passed to Excel.</summary>
    FName: string;
    /// <summary>List view to export.</summary>
    FListView: TListView;
    /// <summary>Optional output filename; empty leaves the workbook open in Excel.</summary>
    FFilename: string;
    /// <summary>True once the start message has been posted, so a second show does not export twice.</summary>
    FExportPosted: Boolean;
    /// <summary>Runs the export, then closes the dialog.</summary>
    /// <param name="Msg">The WM_START_EXPORT message.</param>
    procedure WMStartExport(var Msg: TMessage); message WM_START_EXPORT;
    { Private-Deklarationen }
  protected
    /// <summary>
    /// Posts WM_START_EXPORT when the dialog is first shown, so the export runs from the
    /// message loop once the dialog is visible rather than from inside a paint handler.
    /// </summary>
    procedure DoShow; override;
  public
    { Public-Deklarationen }
    /// <summary>Shows the progress form and exports a list view to Excel.</summary>
    /// <param name="AName">Sheet name to use in the new workbook.</param>
    /// <param name="AListView">List view whose contents should be exported.</param>
    /// <param name="AFilename">Optional output file; when empty the workbook is shown in Excel instead of saved.</param>
    class procedure ExportListView(const AName: string; AListView: TListView;
      const AFilename: string = '');
  end;

/// <summary>
/// Returns the text to hand to Excel so that it is stored literally.  Excel treats a value
/// starting with '=', '+', '-' or '@' as a formula; such text gets a leading apostrophe
/// (Excel's text prefix, which it does not display).  A signed number ( "-5", "+1", "-0.3"
/// in invariant or current-locale notation ) is left as it is, so it stays numeric.
/// </summary>
/// <param name="AText">Cell text from the list view.</param>
/// <returns>AText, prefixed with an apostrophe when Excel would otherwise evaluate it.</returns>
function ExcelCellText( const AText: string ): string;

/// <summary>
/// Exports the rows and columns of a list view to a fresh Excel workbook via OLE.  All cells
/// are transferred in one variant-array assignment, not one OLE call per cell.
/// </summary>
/// <param name="Name">Sheet name to assign to the new sheet.</param>
/// <param name="ListView">List view to export.</param>
/// <param name="Filename">Optional output file; empty makes Excel visible instead.</param>
/// <param name="ProgressBar">Optional progress bar, advanced at each stage of the export.</param>
procedure ExportListViewToExcel(const Name: string; ListView: TListView;
  const Filename: string = ''; ProgressBar: TProgressBar = nil);

implementation

{$R *.dfm}

function ExcelCellText( const AText: string ): string;
var
  LNumber: Double;
begin
  Result := AText;
  if ( AText = '' ) or ( not CharInSet( AText[ 1 ], [ '=', '+', '-', '@' ] ) ) then
    Exit;
  // A signed number ( "-5", "+1", "-0.3" ) is a number, not a formula: leave it numeric.
  if ( CharInSet( AText[ 1 ], [ '+', '-' ] ) ) and
     ( TryStrToFloat( AText, LNumber, TFormatSettings.Invariant ) or TryStrToFloat( AText, LNumber, FormatSettings ) ) then
    Exit;
  Result := '''' + AText;
end;

procedure ExportListViewToExcel(const Name: string; ListView: TListView;
  const Filename: string = ''; ProgressBar: TProgressBar = nil);

  procedure SetProgress( APercent: Integer );
  begin
    if ( Assigned( ProgressBar ) ) then
    begin
      ProgressBar.Position := APercent;
      ProgressBar.Update;
    end;
  end;

var
  ExcelApp: Variant;
  Workbook: Variant;
  Sheet: Variant;
begin
  if Assigned(ProgressBar) then
  begin
    ProgressBar.Position := 0;
    ProgressBar.Max := 100;
  end;

  var LColCount := ListView.Columns.Count;
  var LRowCount := ListView.Items.Count;
  if ( LColCount = 0 ) then
    Exit;

  // Build every cell (header row + data rows) locally first: one OLE round trip for the
  // whole block instead of one per cell.
  var LData := VarArrayCreate( [ 1, LRowCount + 1, 1, LColCount ], varVariant );
  for var LCol := 0 to LColCount - 1 do
    LData[ 1, LCol + 1 ] := ExcelCellText( ListView.Columns[ LCol ].Caption );
  for var LRow := 0 to LRowCount - 1 do
  begin
    var LItem := ListView.Items[ LRow ];
    LData[ LRow + 2, 1 ] := ExcelCellText( LItem.Caption );
    for var LCol := 1 to LColCount - 1 do
    begin
      // An item may carry fewer sub-items than there are columns.
      if ( LCol - 1 < LItem.SubItems.Count ) then
        LData[ LRow + 2, LCol + 1 ] := ExcelCellText( LItem.SubItems[ LCol - 1 ] )
      else
        LData[ LRow + 2, LCol + 1 ] := '';
    end;
  end;
  SetProgress( 25 );

  try
    ExcelApp := CreateOleObject('Excel.Application');
  except
    on E: Exception do
    begin
      ShowMessage('Microsoft Excel is not installed or could not be started:'#13#10 + E.Message);
      Exit;
    end;
  end;

  Workbook := Unassigned;
  Sheet := Unassigned;
  try
    ExcelApp.ScreenUpdating := False;
    Workbook := ExcelApp.Workbooks.Add;
    Sheet := Workbook.Sheets.Add;
    Sheet.Name := Name;
    SetProgress( 40 );

    Sheet.Range[ Sheet.Cells[ 1, 1 ], Sheet.Cells[ LRowCount + 1, LColCount ] ].Value := LData;
    Sheet.Range[ Sheet.Cells[ 1, 1 ], Sheet.Cells[ 1, LColCount ] ].Font.Bold := True;
    for var LCol := 0 to LColCount - 1 do
      Sheet.Columns[ LCol + 1 ].ColumnWidth := ListView.Columns[ LCol ].Width / 6;
    SetProgress( 90 );

    if Filename <> '' then
      Workbook.SaveAs(Filename);
    SetProgress( 100 );
  except
    on E: Exception do
      ShowMessage('Excel export failed:'#13#10 + E.Message);
  end;

  // Best-effort cleanup: restore the UI and either quit (headless save) or show
  // Excel. Wrapped so a cleanup failure cannot orphan a hidden Excel process.
  try
    ExcelApp.ScreenUpdating := True;
    if Filename <> '' then
      ExcelApp.Quit
    else
      ExcelApp.Visible := True;
  except
    // ignore - best effort
  end;

  Sheet := Unassigned;
  Workbook := Unassigned;
  ExcelApp := Unassigned;
end;


class procedure TFormExcelExport.ExportListView(const AName: string;
  AListView: TListView; const AFilename: string);
begin
  with TFormExcelExport.Create(Application) do
  try
    FName := AName;
    FListView := AListView;
    FFilename := AFilename;
    ProgressBar.Position := 0;
    ProgressBar.Max := 100;
    ShowModal;
  finally
    Free;
  end;
end;

procedure TFormExcelExport.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  CanClose := ModalResult <> mrCancel;
end;

procedure TFormExcelExport.DoShow;
begin
  inherited DoShow;
  if ( not FExportPosted ) then
  begin
    FExportPosted := True;
    PostMessage( Handle, WM_START_EXPORT, 0, 0 );
  end;
end;

procedure TFormExcelExport.WMStartExport(var Msg: TMessage);
begin
  // Let the dialog finish painting before the (blocking) OLE work starts.
  Update;
  try
    ExportListViewToExcel(FName, FListView, FFilename, ProgressBar);
  finally
    ModalResult := mrOk;
  end;
end;

end.
