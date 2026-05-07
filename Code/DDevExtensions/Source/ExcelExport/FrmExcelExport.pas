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
  Variants, Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls, ComObj;

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
  Cell: string;
  k: Integer;
begin
  if Assigned(ProgressBar) then
  begin
    ProgressBar.Position := 0;
    ProgressBar.Max := 100;
  end;

  if Filename <> '' then
    ExcelApp := CreateOleObject('Excel.Application')
  else
  begin
    ExcelApp := CreateOleObject('Excel.Application');
{    try
      ExcelApp := GetActiveOleObject('Excel.Application');
    except
      ExcelApp := CreateOleObject('Excel.Application');
    end;}
  end;
  ExcelApp.ScreenUpdating := False;
  try
    Workbook := ExcelApp.Workbooks.Add;
    Sheet := Workbook.Sheets.Add;
    Sheet.Name := Name;

    with ListView do
    begin
      for i := 0 to Columns.Count - 1 do
      begin
        Cell := Char(Ord('A') + i) + '1';
        Sheet.Range[Cell + ':' + Cell].Formula := Columns[i].Caption;
        Sheet.Range[Cell + ':' + Cell].Font.Bold := True;
        Sheet.Range[Cell + ':' + Cell].ColumnWidth := Columns[i].Width / 6;
      end;
      for i := 0 to Items.Count - 1 do
      begin
        for k := 0 to Columns.Count - 1 do
        begin
          Cell := Char(Ord('A') + k) + IntToStr(1 + i + 1);
          if k = 0 then
            Sheet.Range[Cell + ':' + Cell].Formula := Items[i].Caption
          else
            Sheet.Range[Cell + ':' + Cell].Formula := Items[i].SubItems[k - 1];
        end;
        if Assigned(ProgressBar) and (i mod 25 = 0) then
        begin
          ProgressBar.Position := i * 100 div Items.Count;
          Application.ProcessMessages;
        end;
      end;
    end;
    if Assigned(ProgressBar) then
      ProgressBar.Position := ProgressBar.Max;
  finally
    ExcelApp.ScreenUpdating := True;
    if Filename <> '' then
    begin
      Workbook.SaveAs(Filename);
      ExcelApp.Quit;
    end
    else
      ExcelApp.Visible := True;

    Sheet := Unassigned;
    Workbook := Unassigned;
    ExcelApp := Unassigned;
  end;
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
