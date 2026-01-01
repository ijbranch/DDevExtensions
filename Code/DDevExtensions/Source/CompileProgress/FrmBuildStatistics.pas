{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2024 Andreas Hausladen                                                 *}
{*                                                                            *}
{******************************************************************************}

unit FrmBuildStatistics;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Clipbrd, Menus,
  FrmBase, CompileProgress;

type
  TFormBuildStatistics = class( TFormBase )
    pnlBottom: TPanel;
    btnClose: TButton;
    btnCopyToClipboard: TButton;
    btnExportCSV: TButton;
    ListView: TListView;
    lblTotalTime: TLabel;
    lblUnitCount: TLabel;
    SaveDialog: TSaveDialog;
    PopupMenu: TPopupMenu;
    mnuCopyToClipboard: TMenuItem;
    mnuExportCSV: TMenuItem;
    N1: TMenuItem;
    mnuSortByName: TMenuItem;
    mnuSortByTime: TMenuItem;
    procedure btnCloseClick( Sender: TObject );
    procedure btnCopyToClipboardClick( Sender: TObject );
    procedure btnExportCSVClick( Sender: TObject );
    procedure ListViewColumnClick( Sender: TObject; Column: TListColumn );
    procedure ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer );
    procedure mnuSortByNameClick( Sender: TObject );
    procedure mnuSortByTimeClick( Sender: TObject );
  private
    FBuildStatistics: TBuildStatistics;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    procedure PopulateList;
    function FormatDuration( Ms: Int64 ): string;
  public
    class function Execute( ABuildStatistics: TBuildStatistics ): Boolean;
  end;

implementation

{$R *.dfm}

class function TFormBuildStatistics.Execute( ABuildStatistics: TBuildStatistics ): Boolean;
var
  Form: TFormBuildStatistics;
begin

  Result := False;

  if ABuildStatistics = nil then
    Exit;

  Form := TFormBuildStatistics.Create( Application );

  try
    Form.FBuildStatistics := ABuildStatistics;
    Form.FSortColumn      := 1; // Default sort by duration
    Form.FSortAscending   := False; // Descending (slowest first)
    Form.PopulateList;
    Form.ShowModal;
    Result := True;
  finally
    Form.Free;
  end;

end;

function TFormBuildStatistics.FormatDuration( Ms: Int64 ): string;
var
  Seconds: Double;
begin

  if Ms < 1000 then
    Result := Format( '%d ms', [ Ms ] )
  else
  begin
    Seconds := Ms / 1000;

    if Seconds < 60 then
      Result := Format( '%.2f s', [ Seconds ] )
    else
      Result := Format( '%.1f min', [ Seconds / 60 ] );
  end;

end;

procedure TFormBuildStatistics.PopulateList;
var
  Units: TArray<TBuildUnitInfo>;
  I: Integer;
  Item: TListItem;
  TotalMs: Int64;
begin

  ListView.Items.BeginUpdate;

  try
    ListView.Items.Clear;
    Units   := FBuildStatistics.GetUnits;
    TotalMs := 0;

    for I := 0 to Length( Units ) - 1 do
    begin
      Item         := ListView.Items.Add;
      Item.Caption := Units[ I ].UnitName;
      Item.SubItems.Add( FormatDuration( Units[ I ].DurationMs ) );
      Item.SubItems.Add( Units[ I ].FileName );
      Item.Data := Pointer( Units[ I ].DurationMs );
      TotalMs   := TotalMs + Units[ I ].DurationMs;
    end;

    // Apply current sort
    ListView.CustomSort( nil, 0 );

    lblUnitCount.Caption := Format( 'Units compiled: %d', [ Length( Units ) ] );
    lblTotalTime.Caption := Format( 'Total time: %s', [ FormatDuration( TotalMs ) ] );
  finally
    ListView.Items.EndUpdate;
  end;

end;

procedure TFormBuildStatistics.btnCloseClick( Sender: TObject );
begin

  Close;

end;

procedure TFormBuildStatistics.btnCopyToClipboardClick( Sender: TObject );
var
  SL: TStringList;
  I: Integer;
  Item: TListItem;
begin

  SL := TStringList.Create;

  try
    SL.Add( 'Unit Name'#9'Duration'#9'File Path' );

    for I := 0 to ListView.Items.Count - 1 do
    begin
      Item := ListView.Items[ I ];

      if Item.SubItems.Count >= 2 then
        SL.Add( Format( '%s'#9'%s'#9'%s', [ Item.Caption, Item.SubItems[ 0 ], Item.SubItems[ 1 ] ] ) );
    end;

    Clipboard.AsText := SL.Text;
  finally
    SL.Free;
  end;

end;

procedure TFormBuildStatistics.btnExportCSVClick( Sender: TObject );
var
  SL: TStringList;
  I: Integer;
  Item: TListItem;
begin

  if SaveDialog.Execute then
  begin
    SL := TStringList.Create;

    try
      SL.Add( '"Unit Name","Duration (ms)","File Path"' );

      for I := 0 to ListView.Items.Count - 1 do
      begin
        Item := ListView.Items[ I ];

        if Item.SubItems.Count >= 2 then
          SL.Add( Format( '"%s",%d,"%s"', [ Item.Caption, Int64( Item.Data ), Item.SubItems[ 1 ] ] ) );
      end;

      try
        SL.SaveToFile( SaveDialog.FileName );
      except
        on E: Exception do
          ShowMessage( 'Error saving file: ' + E.Message );
      end;
    finally
      SL.Free;
    end;
  end;

end;

procedure TFormBuildStatistics.ListViewColumnClick( Sender: TObject; Column: TListColumn );
begin

  if FSortColumn = Column.Index then
    FSortAscending := not FSortAscending
  else
  begin
    FSortColumn    := Column.Index;
    FSortAscending := ( FSortColumn = 0 ); // Ascending for name, descending for duration
  end;

  ListView.CustomSort( nil, 0 );

end;

procedure TFormBuildStatistics.ListViewCompare( Sender: TObject; Item1, Item2: TListItem;
  Data: Integer; var Compare: Integer );
var
  Ms1, Ms2: Int64;
begin

  case FSortColumn of
    0: // Unit Name
      Compare := CompareText( Item1.Caption, Item2.Caption );
    1: // Duration
      begin
        Ms1 := Int64( Item1.Data );
        Ms2 := Int64( Item2.Data );

        if Ms1 < Ms2 then
          Compare := -1
        else if Ms1 > Ms2 then
          Compare := 1
        else
          Compare := 0;
      end;
    2: // File Path
      Compare := CompareText( Item1.SubItems[ 1 ], Item2.SubItems[ 1 ] );
  else
    Compare := 0;
  end;

  if ( not FSortAscending ) then
    Compare := -Compare;

end;

procedure TFormBuildStatistics.mnuSortByNameClick( Sender: TObject );
begin

  FSortColumn    := 0;
  FSortAscending := True;
  ListView.CustomSort( nil, 0 );

end;

procedure TFormBuildStatistics.mnuSortByTimeClick( Sender: TObject );
begin

  FSortColumn    := 1;
  FSortAscending := False;
  ListView.CustomSort( nil, 0 );

end;

end.
