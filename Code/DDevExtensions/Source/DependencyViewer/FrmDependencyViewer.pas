{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
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
  TViewMode = ( vmUses, vmUsedBy );

  TFormDependencyViewer = class( TFormBase )
    pnlTop: TPanel;
    pnlBottom: TGridPanel;
    btnClose: TButton;
    btnScanProject: TButton;
    TreeView: TTreeView;
    Splitter: TSplitter;
    pnlRight: TPanel;
    pnlImpact: TPanel;
    lblImpactHeader: TLabel;
    lblImpactUnit: TLabel;
    lblImpactDirect: TLabel;
    lblImpactTransitive: TLabel;
    lblImpactRisk: TLabel;
    shpRiskIndicator: TShape;
    lblCircularRefs: TLabel;
    btnExportCircular: TButton;
    ListBoxCircular: TListBox;
    SaveDialogExport: TSaveDialog;
    lblProgress: TLabel;
    rbUses: TRadioButton;
    rbUsedBy: TRadioButton;
    chkShowDepth: TCheckBox;
    btnLayers: TButton;
    btnCheckLayers: TButton;
    lblLayerViolations: TLabel;
    btnExportViolations: TButton;
    ListBoxViolations: TListBox;
    btnExportGraph: TButton;
    SaveDialogGraph: TSaveDialog;
    procedure btnCloseClick( Sender: TObject );
    procedure btnScanProjectClick( Sender: TObject );
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    procedure TreeViewExpanding( Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean );
    procedure ListBoxCircularClick( Sender: TObject );
    procedure ListBoxCircularDblClick( Sender: TObject );
    procedure btnExportCircularClick( Sender: TObject );
    procedure FormCreate( Sender: TObject );
    procedure FormDestroy( Sender: TObject );
    procedure ViewModeChanged( Sender: TObject );
    procedure TreeViewAdvancedCustomDrawItem( Sender: TCustomTreeView; Node: TTreeNode;
      State: TCustomDrawState; Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean );
    procedure TreeViewChange( Sender: TObject; Node: TTreeNode );
    procedure btnLayersClick( Sender: TObject );
    procedure btnCheckLayersClick( Sender: TObject );
    procedure btnExportViolationsClick( Sender: TObject );
    procedure ListBoxViolationsDblClick( Sender: TObject );
    procedure btnExportGraphClick( Sender: TObject );
  private
    FScanner: TDependencyScanner;
    FLayerConfig: TLayerConfig;
    FLayerViolations: TArray<TLayerViolation>;
    FViewMode: TViewMode;
    FShowDepth: Boolean;
    FHighlightedUnits: TStringList;
    FUnitsInAnyCycle: TStringList;
    procedure PopulateTree;
    procedure PopulateCircularRefs;
    procedure BuildUnitsInAnyCycleList;
    procedure AutoSizeTreePanel;
    procedure AddDependencyNodes( ParentNode: TTreeNode; UnitInfo: TUnitInfo );
    procedure AddReverseDependencyNodes( ParentNode: TTreeNode; const UnitName: string );
    procedure ScannerProgress( Sender: TObject );
    function FormatNodeCaption( const UnitName: string; Depth: Integer ): string;
    procedure HighlightCycleMembers( const CircRef: TCircularReference );
    procedure ClearHighlights;
    procedure OpenUnitFile( const UnitName: string );
    procedure UpdateImpactSummary( const UnitName: string );
    procedure ClearImpactSummary;
    procedure ExportCircularRefsToCSV( const FileName: string );
    procedure ExportCircularRefsToTXT( const FileName: string );
    procedure PopulateLayerViolations;
    procedure ExportViolationsToCSV( const FileName: string );
    procedure ExportViolationsToTXT( const FileName: string );
    procedure ExportToDOT( const FileName: string );
    function FindGraphvizDot: string;
  public
    class procedure Execute;
  end;

var
  FormInstance: TFormDependencyViewer = nil;

implementation

{$R *.dfm}

uses
  ToolsAPIHelpers, Main, FrmLayerConfig, ShellAPI;

class procedure TFormDependencyViewer.Execute;
begin

  if FormInstance <> nil then
  begin
    FormInstance.Show;
    FormInstance.BringToFront;
    Exit;
  end;

  FormInstance := TFormDependencyViewer.Create( Application );
  FormInstance.Show;

end;

procedure TFormDependencyViewer.FormClose( Sender: TObject; var Action: TCloseAction );
begin

  FormInstance := nil;
  Action       := caFree;

end;

procedure TFormDependencyViewer.FormCreate( Sender: TObject );
begin

  FScanner            := TDependencyScanner.Create;
  FScanner.OnProgress := ScannerProgress;
  FLayerConfig        := TLayerConfig.Create( AppDataDirectory + '\LayerConfig.txt' );
  FLayerConfig.LoadFromFile;
  FViewMode           := vmUses;
  FShowDepth          := True;
  FHighlightedUnits   := TStringList.Create;
  FHighlightedUnits.CaseSensitive := False;
  FHighlightedUnits.Sorted := True;
  FHighlightedUnits.Duplicates := dupIgnore;
  FUnitsInAnyCycle    := TStringList.Create;
  FUnitsInAnyCycle.CaseSensitive := False;
  FUnitsInAnyCycle.Sorted := True;
  FUnitsInAnyCycle.Duplicates := dupIgnore;
  SetLength( FLayerViolations, 0 );

  ClearImpactSummary;
  lblLayerViolations.Caption := 'Layer Violations: (run Check Layers)';
  btnExportGraph.Visible := FindGraphvizDot <> '';

end;

procedure TFormDependencyViewer.FormDestroy( Sender: TObject );
begin

  FUnitsInAnyCycle.Free;
  FHighlightedUnits.Free;
  FLayerConfig.Free;
  FScanner.Free;

end;

procedure TFormDependencyViewer.ScannerProgress( Sender: TObject );
begin

  lblProgress.Caption := 'Scanning: ' + FScanner.ProgressUnit;
  Application.ProcessMessages;

end;

procedure TFormDependencyViewer.btnCloseClick( Sender: TObject );
begin

  Close;

end;

procedure TFormDependencyViewer.btnScanProjectClick( Sender: TObject );
var
  Project: IOTAProject;
begin

  Project := GetActiveProject;

  if Project = nil then
  begin
    ShowMessage( 'No active project.' );
    Exit;
  end;

  Screen.Cursor := crHourGlass;

  try
    lblProgress.Caption := 'Scanning project...';
    lblProgress.Visible := True;
    Application.ProcessMessages;

    FScanner.RespectConditionals := DependencyViewerPlugin.RespectConditionals;
    FScanner.ScanProject( Project );
    BuildUnitsInAnyCycleList;
    PopulateTree;
    AutoSizeTreePanel;
    PopulateCircularRefs;

    lblProgress.Caption := Format( 'Scanned %d units.', [ Length( FScanner.GetAllUnits ) ] );
  finally
    Screen.Cursor := crDefault;
  end;

end;

procedure TFormDependencyViewer.PopulateTree;
var
  Units: TArray<TUnitInfo>;
  UnitInfo: TUnitInfo;
  Node: TTreeNode;
  Caption: string;
  Depth: Integer;
  HasChildren: Boolean;
  RevDeps: TStringList;
begin

  TreeView.Items.BeginUpdate;

  try
    TreeView.Items.Clear;
    Units := FScanner.GetAllUnits;

    // Sort units alphabetically
    TArray.Sort<TUnitInfo>( Units,
      TComparer<TUnitInfo>.Construct(
        function( const Left, Right: TUnitInfo ): Integer
        begin
          Result := CompareText( Left.UnitName, Right.UnitName );
        end
      ) );

    for UnitInfo in Units do
    begin
      Depth   := FScanner.GetUnitDepth( UnitInfo.UnitName );
      Caption := FormatNodeCaption( UnitInfo.UnitName, Depth );

      Node      := TreeView.Items.AddChild( nil, Caption );
      Node.Data := UnitInfo;

      // Determine if node has children based on view mode
      if FViewMode = vmUses then
        HasChildren := UnitInfo.Dependencies.Count > 0
      else
      begin
        RevDeps     := FScanner.GetReverseDependencies( UnitInfo.UnitName );
        HasChildren := ( RevDeps <> nil ) and ( RevDeps.Count > 0 );
      end;

      // Add a dummy child if there are dependencies (for expand indicator)
      if HasChildren then
        TreeView.Items.AddChild( Node, '' );
    end;
  finally
    TreeView.Items.EndUpdate;
  end;

end;

procedure TFormDependencyViewer.BuildUnitsInAnyCycleList;
var
  CircRef: TCircularReference;
  I: Integer;
begin

  FUnitsInAnyCycle.Clear;

  for CircRef in FScanner.CircularReferences do
  begin
    // Add all units in this cycle (except the last which duplicates the first)
    for I := 0 to High( CircRef.Steps ) - 1 do
      FUnitsInAnyCycle.Add( CircRef.Steps[ I ].UnitName );
  end;

end;

procedure TFormDependencyViewer.AutoSizeTreePanel;
var
  Node: TTreeNode;
  MaxWidth, TextWidth, NodeWidth: Integer;
  Padding: Integer;
begin

  MaxWidth := 150; // Minimum width
  Padding  := 40;  // Space for expand buttons, margins, scrollbar

  TreeView.Canvas.Font := TreeView.Font;

  for Node in TreeView.Items do
  begin
    if Node.Level = 0 then
    begin
      TextWidth := TreeView.Canvas.TextWidth( Node.Text );
      NodeWidth := TextWidth + Padding;

      if NodeWidth > MaxWidth then
        MaxWidth := NodeWidth;
    end;
  end;

  // Cap at reasonable maximum (half of form width)
  if MaxWidth > ClientWidth div 2 then
    MaxWidth := ClientWidth div 2;

  // Adjust the right panel width (which determines tree width since tree is alClient)
  pnlRight.Width := ClientWidth - MaxWidth - Splitter.Width;

end;

procedure TFormDependencyViewer.PopulateCircularRefs;
var
  CircRef: TCircularReference;
  I: Integer;
  S, UsesType: string;
begin

  ListBoxCircular.Items.BeginUpdate;

  try
    ListBoxCircular.Items.Clear;

    for CircRef in FScanner.CircularReferences do
    begin
      S := '';

      for I := 0 to High( CircRef.Steps ) do
      begin

        if I > 0 then
        begin
          // Show uses clause type for the link
          if CircRef.Steps[ I ].IsInterface then
            UsesType := 'I'
          else
            UsesType := 'impl';

          S := S + ' -[' + UsesType + ']-> ';
        end;

        S := S + CircRef.Steps[ I ].UnitName;
      end;

      ListBoxCircular.Items.Add( S );
    end;

    if ListBoxCircular.Items.Count = 0 then
    begin
      lblCircularRefs.Caption    := 'Circular References: None found';
      lblCircularRefs.Font.Color := clGreen;
    end
    else
    begin
      lblCircularRefs.Caption := Format( 'Circular References: %d found', [ ListBoxCircular.Items.Count ] );

      // Color code based on severity
      if ListBoxCircular.Items.Count >= 100 then
        lblCircularRefs.Font.Color := clRed
      else if ListBoxCircular.Items.Count >= 10 then
        lblCircularRefs.Font.Color := $000080FF  // Orange
      else
        lblCircularRefs.Font.Color := clWindowText;
    end;
  finally
    ListBoxCircular.Items.EndUpdate;
  end;

end;

procedure TFormDependencyViewer.AddDependencyNodes( ParentNode: TTreeNode; UnitInfo: TUnitInfo );
var
  Dep: TUnitDependency;
  DepInfo: TUnitInfo;
  Node: TTreeNode;
  Caption: string;
  Depth: Integer;
begin

  for Dep in UnitInfo.Dependencies do
  begin
    Depth   := FScanner.GetUnitDepth( Dep.UnitName );
    Caption := FormatNodeCaption( Dep.UnitName, Depth );

    if Dep.IsInterface then
      Caption := Caption + ' [interface]'
    else
      Caption := Caption + ' [implementation]';

    Node    := TreeView.Items.AddChild( ParentNode, Caption );
    DepInfo := FScanner.GetUnitInfo( Dep.UnitName );

    if DepInfo <> nil then
    begin
      Node.Data := DepInfo;

      // Add dummy child if dependencies exist
      if DepInfo.Dependencies.Count > 0 then
        TreeView.Items.AddChild( Node, '' );
    end;
  end;

end;

procedure TFormDependencyViewer.TreeViewExpanding( Sender: TObject; Node: TTreeNode;
  var AllowExpansion: Boolean );
var
  UnitInfo: TUnitInfo;
begin

  // Check if we need to populate children
  if ( Node.Count = 1 ) and ( Node.Item[ 0 ].Text = '' ) then
  begin
    // Remove dummy child
    Node.Item[ 0 ].Delete;

    UnitInfo := TUnitInfo( Node.Data );

    if UnitInfo <> nil then
    begin

      if FViewMode = vmUses then
        AddDependencyNodes( Node, UnitInfo )
      else
        AddReverseDependencyNodes( Node, UnitInfo.UnitName );
    end;
  end;

end;

procedure TFormDependencyViewer.ListBoxCircularClick( Sender: TObject );
var
  Idx: Integer;
  CircRef: TCircularReference;
  Node: TTreeNode;
  UnitInfo: TUnitInfo;
begin

  Idx := ListBoxCircular.ItemIndex;

  if ( Idx >= 0 ) and ( Idx < FScanner.CircularReferences.Count ) then
  begin
    CircRef := FScanner.CircularReferences[ Idx ];

    // Highlight all units in the cycle
    HighlightCycleMembers( CircRef );

    if Length( CircRef.Steps ) > 0 then
    begin
      // Find and select the first unit in the circular reference
      for Node in TreeView.Items do
      begin

        if Node.Level = 0 then
        begin
          UnitInfo := TUnitInfo( Node.Data );

          if ( UnitInfo <> nil ) and SameText( UnitInfo.UnitName, CircRef.Steps[ 0 ].UnitName ) then
          begin
            Node.Selected := True;
            Node.MakeVisible;
            Break;
          end;
        end;
      end;
    end;
  end
  else
    ClearHighlights;

end;

procedure TFormDependencyViewer.ListBoxCircularDblClick( Sender: TObject );
var
  Idx: Integer;
  CircRef: TCircularReference;
begin

  Idx := ListBoxCircular.ItemIndex;

  if ( Idx >= 0 ) and ( Idx < FScanner.CircularReferences.Count ) then
  begin
    CircRef := FScanner.CircularReferences[ Idx ];

    if Length( CircRef.Steps ) > 0 then
      OpenUnitFile( CircRef.Steps[ 0 ].UnitName );
  end;

end;

procedure TFormDependencyViewer.AddReverseDependencyNodes( ParentNode: TTreeNode;
  const UnitName: string );
var
  RevDeps: TStringList;
  I: Integer;
  DepName: string;
  DepInfo: TUnitInfo;
  Node: TTreeNode;
  Caption: string;
  Depth: Integer;
  ChildRevDeps: TStringList;
begin

  RevDeps := FScanner.GetReverseDependencies( UnitName );

  if RevDeps = nil then
    Exit;

  for I := 0 to RevDeps.Count - 1 do
  begin
    DepName := RevDeps[ I ];
    DepInfo := FScanner.GetUnitInfo( DepName );
    Depth   := FScanner.GetUnitDepth( DepName );
    Caption := FormatNodeCaption( DepName, Depth );

    Node := TreeView.Items.AddChild( ParentNode, Caption );

    if DepInfo <> nil then
    begin
      Node.Data := DepInfo;

      // Add dummy child if this unit is also used by others
      ChildRevDeps := FScanner.GetReverseDependencies( DepName );

      if ( ChildRevDeps <> nil ) and ( ChildRevDeps.Count > 0 ) then
        TreeView.Items.AddChild( Node, '' );
    end;
  end;

end;

function TFormDependencyViewer.FormatNodeCaption( const UnitName: string;
  Depth: Integer ): string;
var
  CycleMarker: string;
begin

  // Mark units that are part of any circular reference
  if FUnitsInAnyCycle.IndexOf( UnitName ) >= 0 then
    CycleMarker := '(!) '
  else
    CycleMarker := '';

  if FShowDepth then
    Result := Format( '%s[%d] %s', [ CycleMarker, Depth, UnitName ] )
  else
    Result := CycleMarker + UnitName;

end;

procedure TFormDependencyViewer.ViewModeChanged( Sender: TObject );
begin

  if rbUses.Checked then
    FViewMode := vmUses
  else
    FViewMode := vmUsedBy;

  FShowDepth := chkShowDepth.Checked;

  // Re-scan project if we have previously scanned
  if Length( FScanner.GetAllUnits ) > 0 then
    btnScanProjectClick( Sender );

end;

procedure TFormDependencyViewer.HighlightCycleMembers( const CircRef: TCircularReference );
var
  I: Integer;
  Node: TTreeNode;
  UnitInfo: TUnitInfo;
begin

  // First, clear any previous highlights by removing markers
  ClearHighlights;

  FHighlightedUnits.Clear;

  // Don't include the last step as it's the same as the first (closing the cycle)
  for I := 0 to High( CircRef.Steps ) - 1 do
    FHighlightedUnits.Add( CircRef.Steps[ I ].UnitName );

  // Add visual marker to highlighted nodes (works regardless of themes)
  for Node in TreeView.Items do
  begin
    if Node.Level = 0 then
    begin
      UnitInfo := TUnitInfo( Node.Data );

      if ( UnitInfo <> nil ) and ( FHighlightedUnits.IndexOf( UnitInfo.UnitName ) >= 0 ) then
      begin
        if Pos( '>>> ', Node.Text ) = 0 then
          Node.Text := '>>> ' + Node.Text + ' <<<';
      end;
    end;
  end;

  TreeView.Invalidate;

end;

procedure TFormDependencyViewer.ClearHighlights;
var
  Node: TTreeNode;
  Text: string;
begin

  // Remove visual markers from node text
  for Node in TreeView.Items do
  begin
    if Node.Level = 0 then
    begin
      Text := Node.Text;

      if Pos( '>>> ', Text ) = 1 then
      begin
        // Remove '>>> ' prefix and ' <<<' suffix
        Delete( Text, 1, 4 );

        if Copy( Text, Length( Text ) - 3, 4 ) = ' <<<' then
          Delete( Text, Length( Text ) - 3, 4 );

        Node.Text := Text;
      end;
    end;
  end;

  FHighlightedUnits.Clear;
  TreeView.Invalidate;

end;

procedure TFormDependencyViewer.TreeViewAdvancedCustomDrawItem( Sender: TCustomTreeView;
  Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage;
  var PaintImages, DefaultDraw: Boolean );
var
  UnitInfo: TUnitInfo;
  NodeRect: TRect;
begin

  DefaultDraw := True;
  PaintImages := True;

  // Only handle pre-paint stage
  if Stage <> cdPrePaint then
    Exit;

  if FHighlightedUnits.Count = 0 then
    Exit;

  UnitInfo := TUnitInfo( Node.Data );

  if UnitInfo = nil then
    Exit;

  if FHighlightedUnits.IndexOf( UnitInfo.UnitName ) >= 0 then
  begin
    // Highlight cycle members - use both background and font for visibility
    if not ( cdsSelected in State ) then
    begin
      NodeRect := Node.DisplayRect( True );
      Sender.Canvas.Brush.Color := $CCCCFF;  // Light red/pink background
      Sender.Canvas.FillRect( NodeRect );
    end;

    Sender.Canvas.Font.Color := clRed;
    Sender.Canvas.Font.Style := [ fsBold ];
  end;

end;

procedure TFormDependencyViewer.OpenUnitFile( const UnitName: string );
var
  UnitInfo: TUnitInfo;
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  SourceEditor: IOTASourceEditor;
  I: Integer;
begin

  UnitInfo := FScanner.GetUnitInfo( UnitName );

  if ( UnitInfo = nil ) or ( UnitInfo.FileName = '' ) then
    Exit;

  if not FileExists( UnitInfo.FileName ) then
    Exit;

  if Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
  begin
    Module := ModuleServices.OpenModule( UnitInfo.FileName );

    if Module <> nil then
    begin

      for I := 0 to Module.ModuleFileCount - 1 do
      begin

        if Supports( Module.ModuleFileEditors[ I ], IOTASourceEditor, SourceEditor ) then
        begin
          SourceEditor.Show;
          Break;
        end;
      end;
    end;
  end;

end;

procedure TFormDependencyViewer.TreeViewChange( Sender: TObject; Node: TTreeNode );
var
  UnitInfo: TUnitInfo;
begin

  if Node = nil then
  begin
    ClearImpactSummary;
    Exit;
  end;

  UnitInfo := TUnitInfo( Node.Data );

  if UnitInfo <> nil then
    UpdateImpactSummary( UnitInfo.UnitName )
  else
    ClearImpactSummary;

end;

procedure TFormDependencyViewer.UpdateImpactSummary( const UnitName: string );
var
  Impact: TImpactAnalysis;
begin

  Impact := FScanner.AnalyzeImpact( UnitName );

  lblImpactUnit.Caption       := 'Unit: ' + UnitName;
  lblImpactDirect.Caption     := Format( 'Direct dependents: %d', [ Impact.DirectCount ] );
  lblImpactTransitive.Caption := Format( 'Total affected: %d units', [ Impact.TransitiveCount ] );
  lblImpactRisk.Caption       := 'Risk: ' + Impact.RiskLevelText;

  // Set risk indicator color
  case Impact.RiskLevel of
    0: shpRiskIndicator.Brush.Color := clGreen;   // Safe
    1: shpRiskIndicator.Brush.Color := $0080FF80; // Light green - Low
    2: shpRiskIndicator.Brush.Color := $0000A5FF; // Orange - Medium
    3: shpRiskIndicator.Brush.Color := clRed;     // High
  else
    shpRiskIndicator.Brush.Color := clGray;
  end;

end;

procedure TFormDependencyViewer.ClearImpactSummary;
begin

  lblImpactUnit.Caption       := 'Unit: (select a unit)';
  lblImpactDirect.Caption     := 'Direct dependents: -';
  lblImpactTransitive.Caption := 'Total affected: -';
  lblImpactRisk.Caption       := 'Risk: -';
  shpRiskIndicator.Brush.Color := clGray;

end;

procedure TFormDependencyViewer.btnExportCircularClick( Sender: TObject );
var
  Ext: string;
begin

  if FScanner.CircularReferences.Count = 0 then
  begin
    ShowMessage( 'No circular references to export.' );
    Exit;
  end;

  if SaveDialogExport.Execute then
  begin
    Ext := LowerCase( ExtractFileExt( SaveDialogExport.FileName ) );

    if Ext = '.csv' then
      ExportCircularRefsToCSV( SaveDialogExport.FileName )
    else
      ExportCircularRefsToTXT( SaveDialogExport.FileName );

    ShowMessage( Format( 'Exported %d circular references to %s',
      [ FScanner.CircularReferences.Count, SaveDialogExport.FileName ] ) );
  end;

end;

procedure TFormDependencyViewer.ExportCircularRefsToCSV( const FileName: string );
var
  SL: TStringList;
  CircRef: TCircularReference;
  I: Integer;
  Line, UsesType: string;
  MaxSteps, StepCount: Integer;
begin

  SL := TStringList.Create;

  try
    // Determine maximum steps for header
    MaxSteps := 0;

    for CircRef in FScanner.CircularReferences do
    begin

      if Length( CircRef.Steps ) > MaxSteps then
        MaxSteps := Length( CircRef.Steps );
    end;

    // Build header row
    Line := 'Index,StepCount';

    for I := 1 to MaxSteps do
      Line := Line + Format( ',Unit%d,UsesType%d', [ I, I ] );

    SL.Add( Line );

    // Add data rows
    StepCount := 0;

    for CircRef in FScanner.CircularReferences do
    begin
      Inc( StepCount );
      Line := Format( '%d,%d', [ StepCount, Length( CircRef.Steps ) ] );

      for I := 0 to High( CircRef.Steps ) do
      begin

        if CircRef.Steps[ I ].IsInterface then
          UsesType := 'interface'
        else
          UsesType := 'implementation';

        // Escape any commas in unit names (unlikely but safe)
        Line := Line + ',"' + CircRef.Steps[ I ].UnitName + '","' + UsesType + '"';
      end;

      // Pad remaining columns if needed
      for I := Length( CircRef.Steps ) to MaxSteps - 1 do
        Line := Line + ',,';

      SL.Add( Line );
    end;

    SL.SaveToFile( FileName );
  finally
    SL.Free;
  end;

end;

procedure TFormDependencyViewer.ExportCircularRefsToTXT( const FileName: string );
var
  SL: TStringList;
  CircRef: TCircularReference;
  I, RefNum: Integer;
  Line, UsesType: string;
begin

  SL := TStringList.Create;

  try
    SL.Add( 'Circular References Report' );
    SL.Add( '==========================' );
    SL.Add( '' );
    SL.Add( Format( 'Total circular references found: %d', [ FScanner.CircularReferences.Count ] ) );
    SL.Add( '' );

    RefNum := 0;

    for CircRef in FScanner.CircularReferences do
    begin
      Inc( RefNum );
      SL.Add( Format( '--- Circular Reference #%d (%d units) ---', [ RefNum, Length( CircRef.Steps ) - 1 ] ) );
      SL.Add( '' );

      // Build the chain representation
      Line := '';

      for I := 0 to High( CircRef.Steps ) do
      begin

        if I > 0 then
        begin

          if CircRef.Steps[ I ].IsInterface then
            UsesType := 'interface'
          else
            UsesType := 'implementation';

          Line := Line + ' -[' + UsesType + ']-> ';
        end;

        Line := Line + CircRef.Steps[ I ].UnitName;
      end;

      SL.Add( '  Chain: ' + Line );
      SL.Add( '' );

      // List each step with details
      SL.Add( '  Steps:' );

      for I := 0 to High( CircRef.Steps ) - 1 do
      begin

        if CircRef.Steps[ I + 1 ].IsInterface then
          UsesType := 'interface'
        else
          UsesType := 'implementation';

        SL.Add( Format( '    %d. %s uses %s (%s uses clause)',
          [ I + 1, CircRef.Steps[ I ].UnitName, CircRef.Steps[ I + 1 ].UnitName, UsesType ] ) );
      end;

      SL.Add( '' );
    end;

    SL.SaveToFile( FileName );
  finally
    SL.Free;
  end;

end;

procedure TFormDependencyViewer.btnLayersClick( Sender: TObject );
begin

  if TFormLayerConfig.Execute( FLayerConfig ) then
  begin
    // Re-check violations if we have scan results
    if Length( FScanner.GetAllUnits ) > 0 then
      btnCheckLayersClick( Sender );
  end;

end;

procedure TFormDependencyViewer.btnCheckLayersClick( Sender: TObject );
begin

  if Length( FScanner.GetAllUnits ) = 0 then
  begin
    ShowMessage( 'Please scan a project first.' );
    Exit;
  end;

  Screen.Cursor := crHourGlass;

  try
    FLayerViolations := FScanner.DetectLayerViolations( FLayerConfig );
    PopulateLayerViolations;
  finally
    Screen.Cursor := crDefault;
  end;

end;

procedure TFormDependencyViewer.PopulateLayerViolations;
var
  Violation: TLayerViolation;
  S, UsesType: string;
begin

  ListBoxViolations.Items.BeginUpdate;

  try
    ListBoxViolations.Items.Clear;

    for Violation in FLayerViolations do
    begin

      if Violation.IsInterface then
        UsesType := 'interface'
      else
        UsesType := 'implementation';

      S := Format( '%s (%s) -> %s (%s) [%s]',
        [ Violation.SourceUnit, Violation.SourceLayer,
          Violation.TargetUnit, Violation.TargetLayer, UsesType ] );

      ListBoxViolations.Items.Add( S );
    end;

    if Length( FLayerViolations ) = 0 then
    begin
      lblLayerViolations.Caption := 'Layer Violations: None found';
      lblLayerViolations.Font.Color := clGreen;
    end
    else
    begin
      lblLayerViolations.Caption := Format( 'Layer Violations: %d found', [ Length( FLayerViolations ) ] );

      // Color code based on severity
      if Length( FLayerViolations ) >= 50 then
        lblLayerViolations.Font.Color := clRed
      else if Length( FLayerViolations ) >= 10 then
        lblLayerViolations.Font.Color := $000080FF  // Orange
      else
        lblLayerViolations.Font.Color := clWindowText;
    end;
  finally
    ListBoxViolations.Items.EndUpdate;
  end;

end;

procedure TFormDependencyViewer.ListBoxViolationsDblClick( Sender: TObject );
var
  Idx: Integer;
begin

  Idx := ListBoxViolations.ItemIndex;

  if ( Idx >= 0 ) and ( Idx < Length( FLayerViolations ) ) then
    OpenUnitFile( FLayerViolations[ Idx ].SourceUnit );

end;

procedure TFormDependencyViewer.btnExportViolationsClick( Sender: TObject );
var
  Ext: string;
begin

  if Length( FLayerViolations ) = 0 then
  begin
    ShowMessage( 'No layer violations to export.' );
    Exit;
  end;

  SaveDialogExport.Title := 'Export Layer Violations';

  if SaveDialogExport.Execute then
  begin
    Ext := LowerCase( ExtractFileExt( SaveDialogExport.FileName ) );

    if Ext = '.csv' then
      ExportViolationsToCSV( SaveDialogExport.FileName )
    else
      ExportViolationsToTXT( SaveDialogExport.FileName );

    ShowMessage( Format( 'Exported %d layer violations to %s',
      [ Length( FLayerViolations ), SaveDialogExport.FileName ] ) );
  end;

end;

procedure TFormDependencyViewer.btnExportGraphClick( Sender: TObject );
var
  Units: TArray<TUnitInfo>;
  DotExe, PngFile: string;
  ExitCode: DWORD;
  SI: TStartupInfo;
  PI: TProcessInformation;
  CmdLine: string;
begin

  Units := FScanner.GetAllUnits;

  if Length( Units ) = 0 then
  begin
    ShowMessage( 'No scan results to export. Please scan a project first.' );
    Exit;
  end;

  DotExe := FindGraphvizDot;

  if DotExe = '' then
  begin
    ShowMessage( 'Graphviz dot.exe not found.' );
    Exit;
  end;

  if SaveDialogGraph.Execute then
  begin
    ExportToDOT( SaveDialogGraph.FileName );

    PngFile := ChangeFileExt( SaveDialogGraph.FileName, '.png' );
    CmdLine := '"' + DotExe + '" -Tpng "' + SaveDialogGraph.FileName + '" -o "' + PngFile + '"';

    ZeroMemory( @SI, SizeOf( SI ) );
    SI.cb := SizeOf( SI );
    SI.dwFlags := STARTF_USESHOWWINDOW;
    SI.wShowWindow := SW_HIDE;
    ZeroMemory( @PI, SizeOf( PI ) );

    if CreateProcess( nil, PChar( CmdLine ), nil, nil, False, CREATE_NO_WINDOW, nil, nil, SI, PI ) then
    begin

      try
        WaitForSingleObject( PI.hProcess, 30000 );
        GetExitCodeProcess( PI.hProcess, ExitCode );
      finally
        CloseHandle( PI.hProcess );
        CloseHandle( PI.hThread );
      end;

      if ( ExitCode = 0 ) and FileExists( PngFile ) then
      begin
        ShellExecute( 0, 'open', PChar( PngFile ), nil, nil, SW_SHOWNORMAL );
        ShowMessage( Format( 'Exported dependency graph to:%s%s%s%s',
          [ sLineBreak, SaveDialogGraph.FileName, sLineBreak, PngFile ] ) );
      end
      else
        ShowMessage( Format( 'DOT file saved to %s but Graphviz rendering failed (exit code %d).',
          [ SaveDialogGraph.FileName, ExitCode ] ) );
    end
    else
      ShowMessage( Format( 'DOT file saved to %s but failed to launch Graphviz.',
        [ SaveDialogGraph.FileName ] ) );
  end;

end;

function TFormDependencyViewer.FindGraphvizDot: string;
var
  PathEnv, Dir: string;
  Dirs: TArray<string>;
  Candidate: string;
begin

  Result := '';

  // Check common Graphviz installation paths first
  Candidate := 'C:\Program Files\Graphviz\bin\dot.exe';

  if FileExists( Candidate ) then
  begin
    Result := Candidate;
    Exit;
  end;

  Candidate := 'C:\Program Files (x86)\Graphviz\bin\dot.exe';

  if FileExists( Candidate ) then
  begin
    Result := Candidate;
    Exit;
  end;

  // Search PATH
  PathEnv := GetEnvironmentVariable( 'PATH' );
  Dirs    := PathEnv.Split( [ ';' ] );

  for Dir in Dirs do
  begin
    Candidate := IncludeTrailingPathDelimiter( Dir ) + 'dot.exe';

    if FileExists( Candidate ) then
    begin
      Result := Candidate;
      Exit;
    end;
  end;

end;

procedure TFormDependencyViewer.ExportToDOT( const FileName: string );
var
  SL: TStringList;
  Units: TArray<TUnitInfo>;
  UnitInfo: TUnitInfo;
  Dep: TUnitDependency;
  NodeName, FillColour, EdgeStyle, EdgeColour: string;
  CycleUnits: TStringList;
  CircRef: TCircularReference;
  I: Integer;
begin

  SL := TStringList.Create;

  try
    // Build set of units involved in circular references
    CycleUnits := TStringList.Create;

    try
      CycleUnits.CaseSensitive := False;
      CycleUnits.Sorted := True;
      CycleUnits.Duplicates := dupIgnore;

      for CircRef in FScanner.CircularReferences do
      begin

        for I := 0 to High( CircRef.Steps ) - 1 do
          CycleUnits.Add( CircRef.Steps[ I ].UnitName );
      end;

      SL.Add( 'digraph Dependencies {' );
      SL.Add( '  rankdir=LR;' );
      SL.Add( '  node [shape=box, style=filled, fontname="Segoe UI", fontsize=10];' );
      SL.Add( '  edge [fontname="Segoe UI", fontsize=8];' );
      SL.Add( '' );

      Units := FScanner.GetAllUnits;

      // Emit nodes
      for UnitInfo in Units do
      begin
        NodeName := StringReplace( UnitInfo.UnitName, '.', '_', [ rfReplaceAll ] );

        // Project units (have a source file) = light green; external/RTL = light blue
        if UnitInfo.FileName <> '' then
          FillColour := 'lightgreen'
        else
          FillColour := 'lightblue';

        if CycleUnits.IndexOf( UnitInfo.UnitName ) >= 0 then
          SL.Add( Format( '  %s [label="%s", fillcolor=%s, color=red, penwidth=2];',
            [ NodeName, UnitInfo.UnitName, FillColour ] ) )
        else
          SL.Add( Format( '  %s [label="%s", fillcolor=%s];',
            [ NodeName, UnitInfo.UnitName, FillColour ] ) );
      end;

      SL.Add( '' );

      // Emit edges
      for UnitInfo in Units do
      begin
        NodeName := StringReplace( UnitInfo.UnitName, '.', '_', [ rfReplaceAll ] );

        for Dep in UnitInfo.Dependencies do
        begin

          // Only emit edges to units that are in our graph
          if FScanner.GetUnitInfo( Dep.UnitName ) <> nil then
          begin

            if Dep.IsInterface then
            begin
              EdgeStyle  := 'solid';
              EdgeColour := 'blue';
            end
            else
            begin
              EdgeStyle  := 'dashed';
              EdgeColour := 'forestgreen';
            end;

            SL.Add( Format( '  %s -> %s [style=%s, color=%s];',
              [ NodeName, StringReplace( Dep.UnitName, '.', '_', [ rfReplaceAll ] ),
                EdgeStyle, EdgeColour ] ) );
          end;
        end;
      end;

      SL.Add( '' );
      SL.Add( '  // Legend' );
      SL.Add( '  subgraph cluster_legend {' );
      SL.Add( '    label="Legend";' );
      SL.Add( '    style=dashed;' );
      SL.Add( '    fontname="Segoe UI";' );
      SL.Add( '    fontsize=10;' );
      SL.Add( '    leg_proj [label="Project Unit", fillcolor=lightgreen, shape=box, style=filled];' );
      SL.Add( '    leg_ext [label="External/RTL Unit", fillcolor=lightblue, shape=box, style=filled];' );
      SL.Add( '    leg_cycle [label="In Circular Ref", fillcolor=lightgreen, color=red, penwidth=2, shape=box, style=filled];' );
      SL.Add( '    leg_iface [label="", shape=point, width=0];' );
      SL.Add( '    leg_impl [label="", shape=point, width=0];' );
      SL.Add( '    leg_proj -> leg_iface [label="interface uses", style=solid, color=blue];' );
      SL.Add( '    leg_ext -> leg_impl [label="implementation uses", style=dashed, color=forestgreen];' );
      SL.Add( '  }' );
      SL.Add( '}' );

      SL.SaveToFile( FileName );
    finally
      CycleUnits.Free;
    end;
  finally
    SL.Free;
  end;

end;

procedure TFormDependencyViewer.ExportViolationsToCSV( const FileName: string );
var
  SL: TStringList;
  Violation: TLayerViolation;
  UsesType: string;
begin

  SL := TStringList.Create;

  try
    SL.Add( 'SourceUnit,SourceLayer,TargetUnit,TargetLayer,UsesClause' );

    for Violation in FLayerViolations do
    begin

      if Violation.IsInterface then
        UsesType := 'interface'
      else
        UsesType := 'implementation';

      SL.Add( Format( '"%s","%s","%s","%s","%s"',
        [ Violation.SourceUnit, Violation.SourceLayer,
          Violation.TargetUnit, Violation.TargetLayer, UsesType ] ) );
    end;

    SL.SaveToFile( FileName );
  finally
    SL.Free;
  end;

end;

procedure TFormDependencyViewer.ExportViolationsToTXT( const FileName: string );
var
  SL: TStringList;
  Violation: TLayerViolation;
  I: Integer;
  UsesType: string;
begin

  SL := TStringList.Create;

  try
    SL.Add( 'Layer Violations Report' );
    SL.Add( '=======================' );
    SL.Add( '' );
    SL.Add( Format( 'Total violations found: %d', [ Length( FLayerViolations ) ] ) );
    SL.Add( '' );

    I := 0;

    for Violation in FLayerViolations do
    begin
      Inc( I );

      if Violation.IsInterface then
        UsesType := 'interface'
      else
        UsesType := 'implementation';

      SL.Add( Format( '%d. %s (%s layer) uses %s (%s layer)',
        [ I, Violation.SourceUnit, Violation.SourceLayer,
          Violation.TargetUnit, Violation.TargetLayer ] ) );
      SL.Add( Format( '   Uses clause: %s', [ UsesType ] ) );
      SL.Add( Format( '   VIOLATION: %s layer should not depend on %s layer',
        [ Violation.SourceLayer, Violation.TargetLayer ] ) );
      SL.Add( '' );
    end;

    SL.SaveToFile( FileName );
  finally
    SL.Free;
  end;

end;

end.
