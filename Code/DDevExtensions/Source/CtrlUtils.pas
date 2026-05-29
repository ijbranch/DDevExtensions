{******************************************************************************}
{*                                                                            *}
{* (C) 2005,2006 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit CtrlUtils;

/// <summary>
/// Small VCL helpers shared across DDevExtensions: list-view sorting,
/// list-view selection/flicker fixes, control enable/disable colouring,
/// and one-line wrappers around <c>MessageDlg</c>.
/// </summary>

{$I DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Controls, Vcl.Graphics, Vcl.ComCtrls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Hooking;

type
  /// <summary>
  /// Public contract of <see cref="TListViewSort"/>; lets consumers drive
  /// sorting via interface dispatch instead of a concrete reference.
  /// </summary>
  IListViewSort = interface
    ['{3EB61BB0-EAD6-4E9D-BA1C-86618B715592}']
    /// <summary>Sorts the list view by the given column index.</summary>
    procedure Sort(AColumn: Integer);
    /// <summary>Re-applies the current sort, optionally on a new column.</summary>
    /// <param name="NewColumn">New column to sort on, or -1 to keep the current one.</param>
    procedure Resort(NewColumn: Integer = -1);

    /// <summary>Returns the index of the column currently used for sorting.</summary>
    function GetColumn: Integer;
    /// <summary>Returns the underlying <c>TListView</c>.</summary>
    function GetListView: TListView;
    /// <summary>Returns whether the current sort is ascending.</summary>
    function GetSortAsc: Boolean;
    /// <summary>Sets the ascending/descending sort direction.</summary>
    procedure SetSortAsc(Value: Boolean);

    /// <summary>Active sort column. Assigning re-sorts the list view.</summary>
    property Column: Integer read GetColumn write Sort;
    /// <summary>True when the sort direction is ascending.</summary>
    property SortAsc: Boolean read GetSortAsc write SetSortAsc;
    /// <summary>The list view that this sorter operates on.</summary>
    property ListView: TListView read GetListView;
  end;

  TListViewSort = class;

  /// <summary>Comparison kinds understood by <see cref="TListViewSort"/>.</summary>
  TSortKind = (skText, skNumeric, skFloat, skDate, skPercentage, skDirectory);
  /// <summary>
  /// Event raised before <see cref="TListViewSort.Compare"/> compares a column,
  /// allowing the host to override the default text comparison.
  /// </summary>
  /// <param name="Sender">Sorter raising the event.</param>
  /// <param name="Column">Column being sorted.</param>
  /// <param name="SortKind">In: default kind (<c>skText</c>); out: kind to use.</param>
  TSortKindEvent = procedure(Sender: TListViewSort; Column: Integer; var SortKind: TSortKind) of object;

  /// <summary>
  /// Reusable sorter for a <c>TListView</c> in report mode. Toggles
  /// ascending/descending on repeated clicks of the same column and supports
  /// numeric, float, date, percentage and directory comparison via
  /// <see cref="OnSortKind"/>.
  /// </summary>
  TListViewSort = class(TComponent, IListViewSort)
  private
    /// <summary>Current sort direction (True = ascending).</summary>
    FSortAsc: Boolean;
    /// <summary>Index of the column currently used for sorting.</summary>
    FColumn: Integer;
    /// <summary>List view being sorted.</summary>
    FListView: TListView;
    /// <summary>User-supplied callback that overrides the comparison kind per column.</summary>
    FOnSortKind: TSortKindEvent;
  protected
    { The function calling Compare will invert the result automatically if necessary. }
    /// <summary>
    /// Compares two list items according to the current column and the kind
    /// supplied by <see cref="OnSortKind"/>.
    /// </summary>
    /// <remarks>The wrapping callback inverts the result automatically when descending.</remarks>
    function Compare(Item1, Item2: TListItem): Integer; virtual;

    /// <summary>Returns the active sort column.</summary>
    function GetColumn: Integer;
    /// <summary>Returns the wrapped list view.</summary>
    function GetListView: TListView;
  public
    /// <summary>Creates a sorter owned by and attached to <paramref name="AListView"/>.</summary>
    constructor Create(AListView: TListView); reintroduce;

    /// <summary>Sorts on <paramref name="AColumn"/>; clicking the same column again toggles direction.</summary>
    procedure Sort(AColumn: Integer);
    /// <summary>Re-applies the current sort, optionally on a new column.</summary>
    procedure Resort(NewColumn: Integer = -1);
    /// <summary>Returns the current sort direction.</summary>
    function GetSortAsc: Boolean;
    /// <summary>Sets the sort direction and re-sorts.</summary>
    procedure SetSortAsc(Value: Boolean);

    /// <summary>The list view being sorted.</summary>
    property ListView: TListView read FListView;
    /// <summary>Current sort column index.</summary>
    property Column: Integer read FColumn;
    /// <summary>Current sort direction (True = ascending).</summary>
    property SortAsc: Boolean read FSortAsc write SetSortAsc;

    /// <summary>Per-column sort-kind override callback.</summary>
    property OnSortKind: TSortKindEvent read FOnSortKind write FOnSortKind;
  end;

/// <summary>
/// Generic <c>TListView.OnMouseDown</c> handler that ensures an item is
/// always selected, falling back to the nearest item, then
/// <paramref name="DefaultItem"/>, then the last item.
/// </summary>
procedure ListViewMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer; DefaultItem: TListItem);
/// <summary>Clears <paramref name="ListView"/> inside a Begin/EndUpdate pair.</summary>
procedure ListViewClear(ListView: TListView);

/// <summary>Enables or disables a windowed control and recolours it (<c>clWindow</c>/<c>clBtnFace</c>) accordingly.</summary>
procedure EnableWinCtrl(Ctrl: TWinControl; Enable: Boolean);

/// <summary>Shows a Yes/No confirmation dialog and returns True for Yes.</summary>
/// <param name="Text">Message body.</param>
/// <param name="DefBtn">Default button (<c>mbYes</c> or <c>mbNo</c>).</param>
function ConfirmDlg2(const Text: string; DefBtn: TMsgDlgBtn = mbYes): Boolean; overload;
/// <summary>Format-string overload of <see cref="ConfirmDlg2"/>.</summary>
function ConfirmDlg2(const Fmt: string; const Args: array of const;
  DefBtn: TMsgDlgBtn = mbYes): Boolean; overload;

/// <summary>Shows an information dialog with an OK button.</summary>
procedure InformDlg(const Text: string); overload;
/// <summary>Format-string overload of <see cref="InformDlg"/>.</summary>
procedure InformDlg(const Fmt: string; const Args: array of const); overload;

/// <summary>Shows an error dialog with an OK button.</summary>
procedure ErrorDlg(const Text: string); overload;
/// <summary>Format-string overload of <see cref="ErrorDlg"/>.</summary>
procedure ErrorDlg(const Fmt: string; const Args: array of const); overload;

/// <summary>Shows a warning dialog with an OK button.</summary>
procedure WarningDlg(const Text: string); overload;
/// <summary>Format-string overload of <see cref="WarningDlg"/>.</summary>
procedure WarningDlg(const Fmt: string; const Args: array of const); overload;

/// <summary>Enables double-buffering on a list view to reduce flicker.</summary>
procedure FixListViewFlicker(ListView: TListView);

implementation

type
  TWinControlProtected = class(TWinControl);

procedure FixListViewFlicker(ListView: TListView);
begin
  ListView.DoubleBuffered := True;
end;

procedure EnableWinCtrl(Ctrl: TWinControl; Enable: Boolean);
begin
  Ctrl.Enabled := Enable;
  if Enable then
    TWinControlProtected(Ctrl).Color := clWindow
  else
    TWinControlProtected(Ctrl).Color := clBtnFace;
end;

function ConfirmDlg2(const Text: string; DefBtn: TMsgDlgBtn = mbYes): Boolean;
var
  Msg: TForm;
begin
  Msg := CreateMessageDialog(Text, mtConfirmation, [mbYes, mbNo]);
  try
    if DefBtn = mbNo then
      Msg.ActiveControl := Msg.FindComponent('No') as TButton;
    Result := Msg.ShowModal = mrYes;
  finally
    Msg.Free;
  end;
end;

function ConfirmDlg2(const Fmt: string; const Args: array of const;
  DefBtn: TMsgDlgBtn = mbYes): Boolean;
begin
  Result := ConfirmDlg2(Format(Fmt, Args), DefBtn);
end;

procedure InformDlg(const Text: string);
begin
  MessageDlg(Text, mtInformation, [mbOk], 0);
end;

procedure InformDlg(const Fmt: string; const Args: array of const);
begin
  InformDlg(Format(Fmt, Args));
end;

procedure ErrorDlg(const Text: string);
begin
  MessageDlg(Text, mtError, [mbOk], 0);
end;

procedure ErrorDlg(const Fmt: string; const Args: array of const);
begin
  ErrorDlg(Format(Fmt, Args));
end;

procedure WarningDlg(const Text: string);
begin
  MessageDlg(Text, mtWarning, [mbOk], 0);
end;

procedure WarningDlg(const Fmt: string; const Args: array of const);
begin
  WarningDlg(Format(Fmt, Args));
end;


procedure ListViewMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer; DefaultItem: TListItem);
var
  Item: TListItem;
  LV: TListView;
begin
  LV := TListView(Sender);
  { There must be always a selected item }
  Item := LV.GetItemAt(X, Y);
  if Item = nil then
    Item := LV.GetNearestItem(Point(X, Y), sdAbove)
  else
    Exit;
  if (Item = nil) and (DefaultItem <> nil) then
    Item := DefaultItem;
  if (Item = nil) and (LV.Items.Count > 0) then
    Item := LV.Items[LV.Items.Count - 1];
  if Item <> nil then
    if not Item.Selected then
      Item.Selected := True;
end;

procedure ListViewClear(ListView: TListView);
begin
  ListView.Items.BeginUpdate;
  try
    ListView.Items.Clear;
  finally
    ListView.Items.EndUpdate;
  end;
end;

{ TListViewSort }

function _SortListView(Item1, Item2: TListItem; LVSort: TListViewSort): Integer stdcall;
begin
  Result := LVSort.Compare(Item1, Item2);

  if Result < -1 then
    Result := -1
  else if Result > 1 then
    Result := 1;

  if LVSort.FSortAsc then
    Result := -1 * Result;
end;

function CompareFloat(f1, f2: Double): Integer;
begin
  if f1 < f2 then
    Result := -1
  else
  if f1 > f2 then
    Result := 1
  else
    Result := 0;
end;

function StrToFloatDef(const S: string; Default: Double): Double;
begin
  try
    Result := StrToFloat(S);
  except
    on EConvertError do
      Result := Default;
  end;
end;

function TListViewSort.Compare(Item1, Item2: TListItem): Integer;
var
  Kind: TSortKind;
  S1, S2: string;
begin
  Result := 0;
  Kind := skText;
  if Assigned(FOnSortKind) then
    FOnSortKind(Self, Column, Kind);

  if Column = 0 then
  begin
    S1 := Item1.Caption;
    S2 := Item2.Caption;
  end
  else
  begin
    // Treat a missing subitem as an empty string so ragged rows (items with
    // fewer subitems) sort stably, instead of Exiting with Result = 0 (equal)
    // which silently corrupts the order.
    if Column - 1 < Item1.SubItems.Count then
      S1 := Item1.SubItems[Column - 1]
    else
      S1 := '';
    if Column - 1 < Item2.SubItems.Count then
      S2 := Item2.SubItems[Column - 1]
    else
      S2 := '';
  end;

  case Kind of
    skText:
      Result := AnsiCompareText(S1, S2);
    skNumeric:
      Result := StrToIntDef(S2, 0) - StrToIntDef(S1 , 0);
    skFloat:
      Result := CompareFloat(StrToFloatDef(S2, 0), StrToFloatDef(S1, 0));
    skPercentage:
      begin
        S1 := Trim(Copy(S1, 1, Pos('%', S1) - 1));
        S2 := Trim(Copy(S2, 1, Pos('%', S2) - 1));
        Result := CompareFloat(StrToFloatDef(S2, 0), StrToFloatDef(S1, 0));
      end;
    skDate:
      Result := CompareFloat(StrToFloatDef(S1, 0), StrToFloatDef(S2, 0));
    skDirectory:
      begin
        {$IFDEF MSWINDOWS}
        Result := AnsiCompareText(ExtractFileDir(S1), ExtractFileDir(S2));
        if Result = 0 then
          Result := AnsiCompareText(S1, S2);
        {$ELSE}
        Result := AnsiCompareStr(ExtractFileDir(S1), ExtractFileDir(S2));
        if Result = 0 then
          Result := AnsiCompareStr(S1, S2);
        {$ENDIF MSWINDOWS}
      end;
  end;
end;

constructor TListViewSort.Create(AListView: TListView);
begin
  inherited Create(AListView);
  FListView := AListView;
  FSortAsc := True;
end;

function TListViewSort.GetColumn: Integer;
begin
  Result := FColumn;
end;

function TListViewSort.GetListView: TListView;
begin
  Result := FListView;
end;

function TListViewSort.GetSortAsc: Boolean;
begin
  Result := FSortAsc;
end;

procedure TListViewSort.Resort(NewColumn: Integer);
begin
  if NewColumn <= -1 then
    NewColumn := FColumn;
  FColumn := -1;
  Sort(NewColumn);
end;

procedure TListViewSort.SetSortAsc(Value: Boolean);
begin
  FSortAsc := Value;
  Resort;
end;

procedure TListViewSort.Sort(AColumn: Integer);
begin
  AColumn := Abs(AColumn);
  if FColumn = AColumn then
    FSortAsc := not FSortAsc;
  FColumn := AColumn;
  if Cardinal(FColumn) >= Cardinal(ListView.Columns.Count) then
    Exit;

  ListView.CustomSort(@_SortListView, NativeInt(Self));
  if ListView.Selected <> nil then
    ListView.Selected.MakeVisible(False);
end;

end.

