{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2024 Andreas Hausladen                                                 *}
{*                                                                            *}
{******************************************************************************}

unit FrmDependencyViewer;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, Menus, Generics.Collections,
  Generics.Defaults, FrmBase, DependencyViewer, ToolsAPI;

type
  TFormDependencyViewer = class(TFormBase)
    pnlTop: TPanel;
    pnlBottom: TPanel;
    btnClose: TButton;
    btnScanProject: TButton;
    TreeView: TTreeView;
    Splitter: TSplitter;
    pnlRight: TPanel;
    lblCircularRefs: TLabel;
    ListBoxCircular: TListBox;
    lblProgress: TLabel;
    procedure btnCloseClick(Sender: TObject);
    procedure btnScanProjectClick(Sender: TObject);
    procedure TreeViewExpanding(Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean);
    procedure ListBoxCircularClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FScanner: TDependencyScanner;
    procedure PopulateTree;
    procedure PopulateCircularRefs;
    procedure AddDependencyNodes(ParentNode: TTreeNode; UnitInfo: TUnitInfo);
    procedure ScannerProgress(Sender: TObject);
  public
    class function Execute: Boolean;
  end;

implementation

{$R *.dfm}

uses
  ToolsAPIHelpers;

class function TFormDependencyViewer.Execute: Boolean;
var
  Form: TFormDependencyViewer;
begin
  Form := TFormDependencyViewer.Create(Application);
  try
    Form.ShowModal;
    Result := True;
  finally
    Form.Free;
  end;
end;

procedure TFormDependencyViewer.FormCreate(Sender: TObject);
begin
  FScanner := TDependencyScanner.Create;
  FScanner.OnProgress := ScannerProgress;
end;

procedure TFormDependencyViewer.FormDestroy(Sender: TObject);
begin
  FScanner.Free;
end;

procedure TFormDependencyViewer.ScannerProgress(Sender: TObject);
begin
  lblProgress.Caption := 'Scanning: ' + FScanner.ProgressUnit;
  Application.ProcessMessages;
end;

procedure TFormDependencyViewer.btnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TFormDependencyViewer.btnScanProjectClick(Sender: TObject);
var
  Project: IOTAProject;
begin
  Project := GetActiveProject;
  if Project = nil then
  begin
    ShowMessage('No active project.');
    Exit;
  end;

  Screen.Cursor := crHourGlass;
  try
    lblProgress.Caption := 'Scanning project...';
    lblProgress.Visible := True;
    Application.ProcessMessages;

    FScanner.ScanProject(Project);
    PopulateTree;
    PopulateCircularRefs;

    lblProgress.Caption := Format('Scanned %d units.', [Length(FScanner.GetAllUnits)]);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFormDependencyViewer.PopulateTree;
var
  Units: TArray<TUnitInfo>;
  UnitInfo: TUnitInfo;
  Node: TTreeNode;
begin
  TreeView.Items.BeginUpdate;
  try
    TreeView.Items.Clear;
    Units := FScanner.GetAllUnits;

    // Sort units alphabetically
    TArray.Sort<TUnitInfo>(Units,
      TComparer<TUnitInfo>.Construct(
        function(const Left, Right: TUnitInfo): Integer
        begin
          Result := CompareText(Left.UnitName, Right.UnitName);
        end
      ));

    for UnitInfo in Units do
    begin
      Node := TreeView.Items.AddChild(nil, UnitInfo.UnitName);
      Node.Data := UnitInfo;
      // Add a dummy child if there are dependencies (for expand indicator)
      if UnitInfo.Dependencies.Count > 0 then
        TreeView.Items.AddChild(Node, '');
    end;
  finally
    TreeView.Items.EndUpdate;
  end;
end;

procedure TFormDependencyViewer.PopulateCircularRefs;
var
  CircRef: TCircularReference;
  I: Integer;
  S: string;
begin
  ListBoxCircular.Items.BeginUpdate;
  try
    ListBoxCircular.Items.Clear;
    for CircRef in FScanner.CircularReferences do
    begin
      S := '';
      for I := 0 to High(CircRef.Path) do
      begin
        if I > 0 then
          S := S + ' -> ';
        S := S + CircRef.Path[I];
      end;
      ListBoxCircular.Items.Add(S);
    end;

    if ListBoxCircular.Items.Count = 0 then
      lblCircularRefs.Caption := 'Circular References: None found'
    else
      lblCircularRefs.Caption := Format('Circular References: %d found', [ListBoxCircular.Items.Count]);
  finally
    ListBoxCircular.Items.EndUpdate;
  end;
end;

procedure TFormDependencyViewer.AddDependencyNodes(ParentNode: TTreeNode; UnitInfo: TUnitInfo);
var
  Dep: TUnitDependency;
  DepInfo: TUnitInfo;
  Node: TTreeNode;
  Caption: string;
begin
  for Dep in UnitInfo.Dependencies do
  begin
    Caption := Dep.UnitName;
    if Dep.IsInterface then
      Caption := Caption + ' [interface]'
    else
      Caption := Caption + ' [implementation]';

    Node := TreeView.Items.AddChild(ParentNode, Caption);

    DepInfo := FScanner.GetUnitInfo(Dep.UnitName);
    if DepInfo <> nil then
    begin
      Node.Data := DepInfo;
      // Add dummy child if dependencies exist
      if DepInfo.Dependencies.Count > 0 then
        TreeView.Items.AddChild(Node, '');
    end;
  end;
end;

procedure TFormDependencyViewer.TreeViewExpanding(Sender: TObject; Node: TTreeNode;
  var AllowExpansion: Boolean);
var
  UnitInfo: TUnitInfo;
begin
  // Check if we need to populate children
  if (Node.Count = 1) and (Node.Item[0].Text = '') then
  begin
    // Remove dummy child
    Node.Item[0].Delete;

    UnitInfo := TUnitInfo(Node.Data);
    if UnitInfo <> nil then
      AddDependencyNodes(Node, UnitInfo);
  end;
end;

procedure TFormDependencyViewer.ListBoxCircularClick(Sender: TObject);
var
  Idx: Integer;
  CircRef: TCircularReference;
  Node: TTreeNode;
begin
  Idx := ListBoxCircular.ItemIndex;
  if (Idx >= 0) and (Idx < FScanner.CircularReferences.Count) then
  begin
    CircRef := FScanner.CircularReferences[Idx];
    if Length(CircRef.Path) > 0 then
    begin
      // Find and select the first unit in the circular reference
      for Node in TreeView.Items do
      begin
        if (Node.Level = 0) and SameText(Node.Text, CircRef.Path[0]) then
        begin
          Node.Selected := True;
          Node.MakeVisible;
          Break;
        end;
      end;
    end;
  end;
end;

end.
