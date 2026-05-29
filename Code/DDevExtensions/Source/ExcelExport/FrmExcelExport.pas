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
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    /// <summary>Performs the export from OnPaint so it runs immediately after the dialog appears.</summary>
    procedure FormPaint(Sender: TObject);
  private
    /// <summary>Sheet name passed to Excel.</summary>
    FName: string;
    /// <summary>List view to export.</summary>
    FListView: TListView;
    /// <summary>Optional output filename; empty leaves the workbook open in Excel.</summary>
    FFilename: string;
    { Private-Deklarationen }
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
/// Exports the rows and columns of a list view to a fresh Excel workbook via OLE.
/// </summary>
/// <param name="Name">Sheet name to assign to the new sheet.</param>
/// <param name="ListView">List view to export.</param>
/// <param name="Filename">Optional output file; empty makes Excel visible instead.</param>
/// <param name="ProgressBar">Optional progress bar updated every 25 rows.</param>
procedure ExportListViewToExcel(const Name: string; ListView: TListView;
  const Filename: string = ''; ProgressBar: TProgressBar = nil);

implementation

{$R *.dfm}

procedure ExportListViewToExcel(const Name: string; ListView: TListView;
  const Filename: string = ''; ProgressBar: TProgressBar = nil);
var
  ExcelApp: Variant;
  Workbook: Variant;
  Sheet: Variant;
  i: Integer;
  k: Integer;
begin
  if Assigned(ProgressBar) then
  begin
    ProgressBar.Position := 0;
    ProgressBar.Max := 100;
  end;

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

    with ListView do
    begin
      // Address cells by numeric (row, col) so any number of columns works;
      // letter arithmetic ( Char( Ord( 'A' ) + i ) ) breaks past column Z.
      for i := 0 to Columns.Count - 1 do
      begin
        Sheet.Cells[1, i + 1].Formula := Columns[i].Caption;
        Sheet.Cells[1, i + 1].Font.Bold := True;
        Sheet.Cells[1, i + 1].ColumnWidth := Columns[i].Width / 6;
      end;
      for i := 0 to Items.Count - 1 do
      begin
        for k := 0 to Columns.Count - 1 do
        begin
          if k = 0 then
            Sheet.Cells[2 + i, k + 1].Formula := Items[i].Caption
          else
            Sheet.Cells[2 + i, k + 1].Formula := Items[i].SubItems[k - 1];
        end;
        if Assigned(ProgressBar) and (Items.Count > 0) and (i mod 25 = 0) then
        begin
          ProgressBar.Position := i * 100 div Items.Count;
          Application.ProcessMessages;
        end;
      end;
    end;
    if Assigned(ProgressBar) then
      ProgressBar.Position := ProgressBar.Max;

    if Filename <> '' then
      Workbook.SaveAs(Filename);
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

procedure TFormExcelExport.FormPaint(Sender: TObject);
begin
  OnPaint := nil;
  Repaint;
  try
    ExportListViewToExcel(FName, FListView, FFilename, ProgressBar);
  finally
    ModalResult := mrOk;
  end;
end;

end.
