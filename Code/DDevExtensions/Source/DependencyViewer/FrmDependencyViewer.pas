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

/// <summary>
/// Non-modal main form of the Dependency Viewer plugin. Hosts the dependency tree,
/// circular-reference list, impact-analysis summary, layer-violation list and the
/// Graphviz export action.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Buttons, System.Generics.Collections,
  System.Generics.Defaults, System.Math, FrmBase, DependencyViewer, DependencyViewerCore, ToolsAPI;

type
  /// <summary>Direction in which the tree displays dependencies: outgoing (vmUses) or incoming (vmUsedBy).</summary>
  TViewMode = ( vmUses, vmUsedBy );

  /// <summary>
  /// Main viewer form. Owns its own <see cref="TDependencyScanner"/> and <see cref="TLayerConfig"/>
  /// instances so that scan results survive across user interactions.
  /// </summary>
  TFormDependencyViewer = class( TFormBase )
    /// <summary>Top toolbar panel.</summary>
    pnlTop: TPanel;
    /// <summary>Bottom grid panel hosting the buttons and progress label.</summary>
    pnlBottom: TGridPanel;
    /// <summary>Closes the form.</summary>
    btnClose: TBitBtn;
    /// <summary>Scans the active IDE project.</summary>
    btnScanProject: TBitBtn;
    /// <summary>Stops a running scan or Graphviz render; shown only while one runs.</summary>
    btnCancelScan: TBitBtn;
    /// <summary>Tree of units and their dependencies (or dependents) for the chosen view mode.</summary>
    TreeView: TTreeView;
    /// <summary>Splitter between the tree and the right-hand details panel.</summary>
    Splitter: TSplitter;
    /// <summary>Right-hand panel hosting the impact, circular-references and violations sections.</summary>
    pnlRight: TPanel;
    /// <summary>Container panel for the impact-analysis summary.</summary>
    pnlImpact: TPanel;
    /// <summary>"Impact analysis" header label.</summary>
    lblImpactHeader: TLabel;
    /// <summary>Shows the currently selected unit name.</summary>
    lblImpactUnit: TLabel;
    /// <summary>Shows the count of direct dependents.</summary>
    lblImpactDirect: TLabel;
    /// <summary>Shows the count of all transitively affected units.</summary>
    lblImpactTransitive: TLabel;
    /// <summary>Shows the textual risk level.</summary>
    lblImpactRisk: TLabel;
    /// <summary>Coloured shape that visually indicates the risk level.</summary>
    shpRiskIndicator: TShape;
    /// <summary>Header label for the circular-references list.</summary>
    lblCircularRefs: TLabel;
    /// <summary>Exports the circular references to CSV or TXT.</summary>
    btnExportCircular: TBitBtn;
    /// <summary>Lists detected circular reference chains.</summary>
    ListBoxCircular: TListBox;
    /// <summary>Save dialog used by the export buttons.</summary>
    SaveDialogExport: TSaveDialog;
    /// <summary>Progress / status label during scanning.</summary>
    lblProgress: TLabel;
    /// <summary>Selects the "Uses" tree view mode.</summary>
    rbUses: TRadioButton;
    /// <summary>Selects the "Used By" tree view mode.</summary>
    rbUsedBy: TRadioButton;
    /// <summary>Toggles inclusion of the depth indicator in node captions.</summary>
    chkShowDepth: TCheckBox;
    /// <summary>Opens the layer configuration dialog.</summary>
    btnLayers: TBitBtn;
    /// <summary>Re-runs the layer-violation check using the current rules.</summary>
    btnCheckLayers: TBitBtn;
    /// <summary>Header label for the layer violations list.</summary>
    lblLayerViolations: TLabel;
    /// <summary>Exports the layer violations to CSV or TXT.</summary>
    btnExportViolations: TBitBtn;
    /// <summary>Lists detected layer-rule violations.</summary>
    ListBoxViolations: TListBox;
    /// <summary>Exports the dependency graph as a Graphviz DOT file (and renders to PNG when possible).</summary>
    btnExportGraph: TBitBtn;
    /// <summary>Save dialog used by the DOT/Graphviz export.</summary>
    SaveDialogGraph: TSaveDialog;
    /// <summary>Closes the form.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnCloseClick( Sender: TObject );
    /// <summary>Scans the active project and populates the views.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnScanProjectClick( Sender: TObject );
    /// <summary>Asks the running scan or render to stop.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnCancelScanClick( Sender: TObject );
    /// <summary>Releases the singleton form instance and frees the form on close.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    /// <param name="Action">Set to caNone while a scan runs, which keeps the form open; otherwise caFree.</param>
    procedure FormClose( Sender: TObject; var Action: TCloseAction );
    /// <summary>Lazily populates a node's children when the user expands it.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    /// <param name="Node">The node about to expand; its placeholder child is replaced by the real ones.</param>
    /// <param name="AllowExpansion">Left True: the node may always expand.</param>
    procedure TreeViewExpanding( Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean );
    /// <summary>Highlights the cycle members for the selected circular reference.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure ListBoxCircularClick( Sender: TObject );
    /// <summary>Opens the source file of the first unit in the selected circular reference.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure ListBoxCircularDblClick( Sender: TObject );
    /// <summary>Exports the detected circular references to a chosen file.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnExportCircularClick( Sender: TObject );
    /// <summary>Form OnCreate handler: initialises owned resources.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure FormCreate( Sender: TObject );
    /// <summary>Form OnDestroy handler: releases owned resources.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Updates view-mode and depth-display flags then re-populates the tree.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure ViewModeChanged( Sender: TObject );
    /// <summary>Custom-draws cycle-member nodes with a highlight background and bold red text.</summary>
    /// <param name="Sender">The tree view.</param>
    /// <param name="Node">The node being painted.</param>
    /// <param name="State">The node's draw state; a selected node keeps the selection colours.</param>
    /// <param name="Stage">The paint stage; only cdPrePaint is handled.</param>
    /// <param name="PaintImages">Set True: the node images are painted as usual.</param>
    /// <param name="DefaultDraw">Set True: the tree still draws the node text, in the colours set here.</param>
    procedure TreeViewAdvancedCustomDrawItem( Sender: TCustomTreeView; Node: TTreeNode;
      State: TCustomDrawState; Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean );
    /// <summary>Updates the impact summary panel for the newly selected node.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    /// <param name="Node">The newly selected node, or nil.</param>
    procedure TreeViewChange( Sender: TObject; Node: TTreeNode );
    /// <summary>Opens the layer configuration dialog and re-checks violations.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnLayersClick( Sender: TObject );
    /// <summary>Detects layer violations using the current configuration and displays them.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnCheckLayersClick( Sender: TObject );
    /// <summary>Exports the layer violations to a chosen file.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnExportViolationsClick( Sender: TObject );
    /// <summary>Opens the source file of the source unit of the double-clicked violation.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure ListBoxViolationsDblClick( Sender: TObject );
    /// <summary>Exports the dependency graph to DOT and renders it via Graphviz when available.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnExportGraphClick( Sender: TObject );
  private
    /// <summary>Scanner that holds the current project's dependency graph.</summary>
    FScanner: TDependencyScanner;
    /// <summary>Layer configuration loaded from / saved to the user's app data directory.</summary>
    FLayerConfig: TLayerConfig;
    /// <summary>Most recently detected layer violations.</summary>
    FLayerViolations: TArray<TLayerViolation>;
    /// <summary>Currently selected tree view mode.</summary>
    FViewMode: TViewMode;
    /// <summary>Whether to show the [depth] prefix in node captions.</summary>
    FShowDepth: Boolean;
    /// <summary>Names of units currently highlighted (members of the selected cycle).</summary>
    FHighlightedUnits: TStringList;
    /// <summary>All units that participate in any detected cycle (used to mark "(!)" in captions).</summary>
    FUnitsInAnyCycle: TStringList;
    /// <summary>True while a scan or a Graphviz render runs; guards against a second scan and vetoes closing the form,
    /// since both pump messages ( ScanProgress, RenderDot ).</summary>
    FScanning: Boolean;
    /// <summary>Set by Cancel; the running scan or render stops.</summary>
    FCancelRequested: Boolean;
    /// <summary>Empties every view that holds pointers into the scanner's units, before they are freed.</summary>
    procedure ClearResults;
    /// <summary>Shows Cancel in place of Scan Project while a scan or render runs, and back.</summary>
    /// <param name="ABusy">True while the work runs.</param>
    /// <param name="ACancelCaption">Caption of the Cancel button while it is shown.</param>
    procedure SetBusy( ABusy: Boolean; const ACancelCaption: string );
    /// <summary>Runs Graphviz on a DOT file, pumping messages so the IDE stays responsive.</summary>
    /// <param name="ADotExe">Path of dot.exe.</param>
    /// <param name="ADotFile">The DOT file to render.</param>
    /// <param name="APngFile">The PNG file to write.</param>
    /// <param name="AMessage">Receives why rendering did not succeed; empty on success.</param>
    /// <returns>True when dot.exe finished with exit code 0.</returns>
    function RenderDot( const ADotExe, ADotFile, APngFile: string; out AMessage: string ): Boolean;
    /// <summary>Builds the top-level tree and adds dummy children for lazy expansion.</summary>
    procedure PopulateTree;
    /// <summary>Populates the circular-references list box and updates its header colour.</summary>
    procedure PopulateCircularRefs;
    /// <summary>Builds <see cref="FUnitsInAnyCycle"/> from the scanner's circular references.</summary>
    procedure BuildUnitsInAnyCycleList;
    /// <summary>Auto-sizes the tree panel based on the longest top-level node caption.</summary>
    procedure AutoSizeTreePanel;
    /// <summary>Adds outgoing-dependency child nodes for a unit (vmUses mode).</summary>
    /// <param name="ParentNode">The node the children are added under.</param>
    /// <param name="UnitInfo">The unit whose dependencies are listed.</param>
    procedure AddDependencyNodes( ParentNode: TTreeNode; UnitInfo: TUnitInfo );
    /// <summary>Adds reverse-dependency child nodes for a unit (vmUsedBy mode).</summary>
    /// <param name="ParentNode">The node the children are added under.</param>
    /// <param name="UnitName">The unit whose dependents are listed.</param>
    procedure AddReverseDependencyNodes( ParentNode: TTreeNode; const UnitName: string );
    /// <summary>Scan progress: shows the unit, pumps messages and stops on Cancel or IDE close.</summary>
    /// <param name="AUnitName">The unit about to be read.</param>
    /// <exception cref="EAbort">Raised to stop the scan.</exception>
    procedure ScanProgress( const AUnitName: string );
    /// <summary>Formats a tree node caption with optional cycle marker and depth indicator.</summary>
    /// <param name="UnitName">The unit name, without path or extension.</param>
    /// <param name="Depth">The unit's dependency depth, shown as "[n]" when depth display is on.</param>
    /// <returns>The caption, with "(!) " in front for a unit in a circular reference.</returns>
    function FormatNodeCaption( const UnitName: string; Depth: Integer ): string;
    /// <summary>Highlights all units that participate in the supplied circular reference.</summary>
    /// <param name="CircRef">The circular reference whose group members are highlighted.</param>
    procedure HighlightCycleMembers( const CircRef: TCircularReference );
    /// <summary>Removes any cycle highlight markers from the tree.</summary>
    procedure ClearHighlights;
    /// <summary>Opens the source file for the named unit in the IDE editor.</summary>
    /// <param name="UnitName">The unit to open; a unit outside the scanned project is ignored.</param>
    procedure OpenUnitFile( const UnitName: string );
    /// <summary>Recalculates and displays the impact summary for the selected unit.</summary>
    /// <param name="UnitName">The unit whose dependents are counted.</param>
    procedure UpdateImpactSummary( const UnitName: string );
    /// <summary>Resets the impact summary panel to its empty state.</summary>
    procedure ClearImpactSummary;
    /// <summary>Writes the circular references to a CSV file.</summary>
    /// <param name="FileName">The file to write.</param>
    procedure ExportCircularRefsToCSV( const FileName: string );
    /// <summary>Writes the circular references to a human-readable text file.</summary>
    /// <param name="FileName">The file to write.</param>
    procedure ExportCircularRefsToTXT( const FileName: string );
    /// <summary>Populates the layer violations list and updates its header.</summary>
    procedure PopulateLayerViolations;
    /// <summary>Writes layer violations to a CSV file.</summary>
    /// <param name="FileName">The file to write.</param>
    procedure ExportViolationsToCSV( const FileName: string );
    /// <summary>Writes layer violations to a human-readable text file.</summary>
    /// <param name="FileName">The file to write.</param>
    procedure ExportViolationsToTXT( const FileName: string );
    /// <summary>Writes the dependency graph as a Graphviz DOT file (with a legend).</summary>
    /// <param name="FileName">The file to write.</param>
    procedure ExportToDOT( const FileName: string );
    /// <summary>Locates the Graphviz dot.exe executable, returning an empty string if not found.</summary>
    /// <returns>The full path of dot.exe; empty when it is not found.</returns>
    function FindGraphvizDot: string;
  public
    /// <summary>Shows or focuses the singleton viewer form.</summary>
    class procedure Execute;
    /// <summary>Frees the singleton form, if open, so it cannot outlive the plugin on unload.</summary>
    class procedure CloseInstance;
  end;

var
  /// <summary>Singleton viewer form instance (nil when the form is not open).</summary>
  FormInstance      : TFormDependencyViewer = nil;

implementation

{$R *.dfm}

uses
  System.IOUtils, ToolsAPIHelpers, Main, FrmLayerConfig, Winapi.ShellAPI, IdeUnitSource;

class procedure TFormDependencyViewer.Execute;
begin

  if FormInstance <> nil then
  begin
    // Re-evaluate Graphviz availability: it may have been installed since the
    // singleton form was first created.
    FormInstance.btnExportGraph.Visible := FormInstance.FindGraphvizDot <> '';
    FormInstance.Show;
    FormInstance.BringToFront;
    Exit;
  end;

  FormInstance      := TFormDependencyViewer.Create( Application );
  FormInstance.Show;

end;

class procedure TFormDependencyViewer.CloseInstance;
begin

  if ( FormInstance <> nil ) then
    FreeAndNil( FormInstance );

end;

procedure TFormDependencyViewer.btnCancelScanClick( Sender: TObject );
begin

  FCancelRequested  := True;

end;

procedure TFormDependencyViewer.SetBusy( ABusy: Boolean; const ACancelCaption: string );
begin

  FScanning         := ABusy;
  btnCancelScan.Caption := ACancelCaption;
  btnCancelScan.Visible := ABusy;
  btnScanProject.Visible := not ABusy;
  btnExportGraph.Enabled := not ABusy;
  btnCheckLayers.Enabled := not ABusy;
  btnLayers.Enabled := not ABusy;
  if ABusy then
    Screen.Cursor   := crHourGlass
  else
    Screen.Cursor   := crDefault;

end;

procedure TFormDependencyViewer.ClearResults;
begin

  // The tree nodes, highlights and impact panel point into TUnitInfo objects the next scan frees;
  // a message pumped during that scan must find nothing left to paint, click or expand.
  TreeView.Items.Clear;
  FHighlightedUnits.Clear;
  FUnitsInAnyCycle.Clear;
  ListBoxCircular.Items.Clear;
  lblCircularRefs.Caption := 'Circular References:';
  ClearImpactSummary;
  FLayerViolations  := nil;
  ListBoxViolations.Items.Clear;
  lblLayerViolations.Caption := 'Layer Violations: (run Check Layers)';

end;

procedure TFormDependencyViewer.FormClose( Sender: TObject; var Action: TCloseAction );
begin

  // Veto the close while a scan is on the stack (ScannerProgress pumps messages),
  // otherwise FScanner is freed while ScanProject is still running.
  if FScanning then
  begin
    Action          := caNone;
    Exit;
  end;

  FormInstance      := nil;
  Action            := caFree;

end;

procedure TFormDependencyViewer.FormCreate( Sender: TObject );
begin

  FScanner          := TDependencyScanner.Create;
  FLayerConfig      := TLayerConfig.Create( AppDataDirectory + '\LayerConfig.txt' );
  FLayerConfig.LoadFromFile;
  FViewMode         := vmUses;
  FShowDepth        := True;
  FHighlightedUnits := TStringList.Create;
  FHighlightedUnits.CaseSensitive := False;
  FHighlightedUnits.Sorted := True;
  FHighlightedUnits.Duplicates := dupIgnore;
  FUnitsInAnyCycle  := TStringList.Create;
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

procedure TFormDependencyViewer.ScanProgress( const AUnitName: string );
begin

  lblProgress.Caption := 'Scanning: ' + AUnitName;
  Application.ProcessMessages;

  // Stop on Cancel Scan, and when the IDE is closing: the pump above swallowed its WM_QUIT.
  if FCancelRequested or Application.Terminated then
    Abort;

end;

procedure TFormDependencyViewer.btnCloseClick( Sender: TObject );
begin

  Close;

end;

procedure TFormDependencyViewer.btnScanProjectClick( Sender: TObject );
var
  Project           : IOTAProject;
begin

  // ScannerProgress pumps the message queue, so the user could click Scan again
  // (clearing the scanner mid-scan) or close the form (freeing FScanner) while
  // ScanProject is still on the stack. Refuse re-entry while a scan runs.
  if FScanning then
    Exit;

  Project           := GetActiveProject;

  if Project = nil then
  begin
    ShowMessage( 'No active project.' );
    Exit;
  end;

  FCancelRequested  := False;
  SetBusy( True, '&Cancel Scan' );

  try
    ClearResults;
    lblProgress.Caption := 'Scanning project...';
    lblProgress.Visible := True;
    Application.ProcessMessages;

    if ( DependencyViewerPlugin <> nil ) then
      FScanner.RespectConditionals := DependencyViewerPlugin.RespectConditionals;
    try
      ScanDependencyProject( FScanner, Project,
        procedure( AUnitName: string )
        begin
          ScanProgress( AUnitName );
        end );
    except
      on EAbort do
      begin
        FScanner.Clear;
        lblProgress.Caption := 'Scan cancelled.';
        Exit;
      end;
    end;
    BuildUnitsInAnyCycleList;
    PopulateTree;
    AutoSizeTreePanel;
    PopulateCircularRefs;

    lblProgress.Caption := Format( 'Scanned %d units.', [ Length( FScanner.GetAllUnits ) ] );
  finally
    SetBusy( False, '' );
  end;

end;

procedure TFormDependencyViewer.PopulateTree;
var
  Units             : TArray<TUnitInfo>;
  UnitInfo          : TUnitInfo;
  Node              : TTreeNode;
  Caption           : string;
  Depth             : Integer;
  HasChildren       : Boolean;
  RevDeps           : TStringList;
begin

  TreeView.Items.BeginUpdate;

  try
    TreeView.Items.Clear;
    Units           := FScanner.GetAllUnits;

    // Sort units alphabetically
    TArray.Sort<TUnitInfo>( Units,
      TComparer<TUnitInfo>.Construct(
        function( const Left, Right: TUnitInfo ): Integer
        begin
          Result    := CompareText( Left.UnitName, Right.UnitName );
        end
        ) );

    for UnitInfo in Units do
    begin
      Depth := FScanner.GetUnitDepth( UnitInfo.UnitName );
      Caption       := FormatNodeCaption( UnitInfo.UnitName, Depth );

      Node          := TreeView.Items.AddChild( nil, Caption );
      Node.Data     := UnitInfo;

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
  CircRef           : TCircularReference;
  I                 : Integer;
begin

  FUnitsInAnyCycle.Clear;

  // Every member of every entangled group, not only those on its representative cycle.
  for CircRef in FScanner.CircularReferences do
    for I := 0 to High( CircRef.Members ) do
      FUnitsInAnyCycle.Add( CircRef.Members[ I ] );

end;

procedure TFormDependencyViewer.AutoSizeTreePanel;
var
  Node              : TTreeNode;
  MaxWidth, TextWidth, NodeWidth: Integer;
  Padding           : Integer;
begin

  MaxWidth          := 150; // Minimum width
  Padding           := 40; // Space for expand buttons, margins, scrollbar

  TreeView.Canvas.Font := TreeView.Font;

  for Node in TreeView.Items do
  begin
    if Node.Level = 0 then
    begin
      TextWidth     := TreeView.Canvas.TextWidth( Node.Text );
      NodeWidth     := TextWidth + Padding;

      if NodeWidth > MaxWidth then
        MaxWidth    := NodeWidth;
    end;
  end;

  // Cap at reasonable maximum (half of form width)
  if MaxWidth > ClientWidth div 2 then
    MaxWidth        := ClientWidth div 2;

  // Adjust the right panel width (which determines tree width since tree is alClient)
  pnlRight.Width    := ClientWidth - MaxWidth - Splitter.Width;

end;

procedure TFormDependencyViewer.PopulateCircularRefs;
var
  CircRef           : TCircularReference;
  I                 : Integer;
  S, UsesType       : string;
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

          S         := S + ' -[' + UsesType + ']-> ';
        end;

        S           := S + CircRef.Steps[ I ].UnitName;
      end;

      // The chain is the shortest cycle through the group; say when the group is larger.
      if ( Length( CircRef.Members ) > Max( 0, Length( CircRef.Steps ) - 1 ) ) then
        S           := S + Format( '   (group of %d units)', [ Length( CircRef.Members ) ] );

      ListBoxCircular.Items.Add( S );
    end;

    if ListBoxCircular.Items.Count = 0 then
    begin
      lblCircularRefs.Caption := 'Circular References: None found';
      lblCircularRefs.Font.Color := clGreen;
    end
    else
    begin
      lblCircularRefs.Caption := Format( 'Circular References: %d found', [ ListBoxCircular.Items.Count ] );

      // Colour code based on severity
      if ListBoxCircular.Items.Count >= 100 then
        lblCircularRefs.Font.Color := clRed
      else if ListBoxCircular.Items.Count >= 10 then
        lblCircularRefs.Font.Color := $000080FF // Orange
      else
        lblCircularRefs.Font.Color := clWindowText;
    end;
  finally
    ListBoxCircular.Items.EndUpdate;
  end;

end;

procedure TFormDependencyViewer.AddDependencyNodes( ParentNode: TTreeNode; UnitInfo: TUnitInfo );
var
  Dep               : TUnitDependency;
  DepInfo           : TUnitInfo;
  Node              : TTreeNode;
  Caption           : string;
  Depth             : Integer;
begin

  for Dep in UnitInfo.Dependencies do
  begin
    Depth := FScanner.GetUnitDepth( Dep.UnitName );
    Caption         := FormatNodeCaption( Dep.UnitName, Depth );

    if Dep.IsInterface then
      Caption       := Caption + ' [interface]'
    else
      Caption       := Caption + ' [implementation]';

    Node            := TreeView.Items.AddChild( ParentNode, Caption );
    DepInfo         := FScanner.GetUnitInfo( Dep.UnitName );

    if DepInfo <> nil then
    begin
      Node.Data     := DepInfo;

      // Add dummy child if dependencies exist
      if DepInfo.Dependencies.Count > 0 then
        TreeView.Items.AddChild( Node, '' );
    end;
  end;

end;

procedure TFormDependencyViewer.TreeViewExpanding( Sender: TObject; Node: TTreeNode;
  var AllowExpansion: Boolean );
var
  UnitInfo          : TUnitInfo;
begin

  // Check if we need to populate children
  if ( Node.Count = 1 ) and ( Node.Item[ 0 ].Text = '' ) then
  begin
    // Remove dummy child
    Node.Item[ 0 ].Delete;

    UnitInfo        := TUnitInfo( Node.Data );

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
  Idx               : Integer;
  CircRef           : TCircularReference;
  Node              : TTreeNode;
  UnitInfo          : TUnitInfo;
begin

  Idx               := ListBoxCircular.ItemIndex;

  if ( Idx >= 0 ) and ( Idx < FScanner.CircularReferences.Count ) then
  begin
    CircRef         := FScanner.CircularReferences[ Idx ];

    // Highlight all units in the cycle
    HighlightCycleMembers( CircRef );

    if Length( CircRef.Steps ) > 0 then
    begin
      // Find and select the first unit in the circular reference
      for Node in TreeView.Items do
      begin

        if Node.Level = 0 then
        begin
          UnitInfo  := TUnitInfo( Node.Data );

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
  Idx               : Integer;
  CircRef           : TCircularReference;
begin

  Idx               := ListBoxCircular.ItemIndex;

  if ( Idx >= 0 ) and ( Idx < FScanner.CircularReferences.Count ) then
  begin
    CircRef         := FScanner.CircularReferences[ Idx ];

    if Length( CircRef.Steps ) > 0 then
      OpenUnitFile( CircRef.Steps[ 0 ].UnitName );
  end;

end;

procedure TFormDependencyViewer.AddReverseDependencyNodes( ParentNode: TTreeNode;
  const UnitName: string );
var
  RevDeps           : TStringList;
  I                 : Integer;
  DepName           : string;
  DepInfo           : TUnitInfo;
  Node              : TTreeNode;
  Caption           : string;
  Depth             : Integer;
  ChildRevDeps      : TStringList;
begin

  RevDeps           := FScanner.GetReverseDependencies( UnitName );

  if RevDeps = nil then
    Exit;

  for I := 0 to RevDeps.Count - 1 do
  begin
    DepName         := RevDeps[ I ];
    DepInfo         := FScanner.GetUnitInfo( DepName );
    Depth           := FScanner.GetUnitDepth( DepName );
    Caption         := FormatNodeCaption( DepName, Depth );

    Node            := TreeView.Items.AddChild( ParentNode, Caption );

    if DepInfo <> nil then
    begin
      Node.Data     := DepInfo;

      // Add dummy child if this unit is also used by others
      ChildRevDeps  := FScanner.GetReverseDependencies( DepName );

      if ( ChildRevDeps <> nil ) and ( ChildRevDeps.Count > 0 ) then
        TreeView.Items.AddChild( Node, '' );
    end;
  end;

end;

function TFormDependencyViewer.FormatNodeCaption( const UnitName: string;
  Depth: Integer ): string;
var
  CycleMarker       : string;
begin

  // Mark units that are part of any circular reference
  if FUnitsInAnyCycle.IndexOf( UnitName ) >= 0 then
    CycleMarker     := '(!) '
  else
    CycleMarker     := '';

  if FShowDepth then
    Result          := Format( '%s[%d] %s', [ CycleMarker, Depth, UnitName ] )
  else
    Result          := CycleMarker + UnitName;

end;

procedure TFormDependencyViewer.ViewModeChanged( Sender: TObject );
begin

  if rbUses.Checked then
    FViewMode       := vmUses
  else
    FViewMode       := vmUsedBy;

  FShowDepth        := chkShowDepth.Checked;

  // The scan result does not depend on the view: redraw the tree, do not read the project again.
  if ( not FScanning ) and ( Length( FScanner.GetAllUnits ) > 0 ) then
  begin
    ClearHighlights;
    PopulateTree;
    AutoSizeTreePanel;
  end;

end;

procedure TFormDependencyViewer.HighlightCycleMembers( const CircRef: TCircularReference );
var
  I                 : Integer;
begin

  // First, clear any previous highlights
  ClearHighlights;

  FHighlightedUnits.Clear;

  // Every member of the group, including any not on its representative cycle.
  for I := 0 to High( CircRef.Members ) do
    FHighlightedUnits.Add( CircRef.Members[ I ] );

  // Highlighting is rendered by TreeViewAdvancedCustomDrawItem from
  // FHighlightedUnits. Do NOT mutate Node.Text with '>>>'/'<<<' markers - that
  // corrupted captions and made AutoSize measure the decorated text.
  TreeView.Invalidate;

end;

procedure TFormDependencyViewer.ClearHighlights;
var
  Node              : TTreeNode;
  Text              : string;
begin

  // Remove visual markers from node text
  for Node in TreeView.Items do
  begin
    if Node.Level = 0 then
    begin
      Text          := Node.Text;

      if Pos( '>>> ', Text ) = 1 then
      begin
        // Remove '>>> ' prefix and ' <<<' suffix
        Delete( Text, 1, 4 );

        if Copy( Text, Length( Text ) - 3, 4 ) = ' <<<' then
          Delete( Text, Length( Text ) - 3, 4 );

        Node.Text   := Text;
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
  UnitInfo          : TUnitInfo;
  NodeRect          : TRect;
begin

  DefaultDraw       := True;
  PaintImages       := True;

  // Only handle pre-paint stage
  if Stage <> cdPrePaint then
    Exit;

  if FHighlightedUnits.Count = 0 then
    Exit;

  UnitInfo          := TUnitInfo( Node.Data );

  if UnitInfo = nil then
    Exit;

  if FHighlightedUnits.IndexOf( UnitInfo.UnitName ) >= 0 then
  begin
    // Highlight cycle members - use both background and font for visibility
    if not ( cdsSelected in State ) then
    begin
      NodeRect      := Node.DisplayRect( True );
      Sender.Canvas.Brush.Color := $CCCCFF; // Light red/pink background
      Sender.Canvas.FillRect( NodeRect );
    end;

    Sender.Canvas.Font.Color := clRed;
    Sender.Canvas.Font.Style := [ fsBold ];
  end;

end;

procedure TFormDependencyViewer.OpenUnitFile( const UnitName: string );
var
  UnitInfo          : TUnitInfo;
begin

  UnitInfo          := FScanner.GetUnitInfo( UnitName );

  if ( UnitInfo = nil ) or ( UnitInfo.FileName = '' ) then
    Exit;

  OpenFileAtLine( UnitInfo.FileName, 0, 1 );

end;

procedure TFormDependencyViewer.TreeViewChange( Sender: TObject; Node: TTreeNode );
var
  UnitInfo          : TUnitInfo;
begin

  if Node = nil then
  begin
    ClearImpactSummary;
    Exit;
  end;

  UnitInfo          := TUnitInfo( Node.Data );

  if UnitInfo <> nil then
    UpdateImpactSummary( UnitInfo.UnitName )
  else
    ClearImpactSummary;

end;

procedure TFormDependencyViewer.UpdateImpactSummary( const UnitName: string );
var
  Impact            : TImpactAnalysis;
begin

  Impact            := FScanner.AnalyzeImpact( UnitName );

  lblImpactUnit.Caption := 'Unit: ' + UnitName;
  lblImpactDirect.Caption := Format( 'Direct dependents: %d', [ Impact.DirectCount ] );
  lblImpactTransitive.Caption := Format( 'Total affected: %d units', [ Impact.TransitiveCount ] );
  lblImpactRisk.Caption := 'Risk: ' + Impact.RiskLevelText;

  // Set risk indicator colour
  case Impact.RiskLevel of
    0: shpRiskIndicator.Brush.Color := clGreen; // Safe
    1: shpRiskIndicator.Brush.Color := $0080FF80; // Light green - Low
    2: shpRiskIndicator.Brush.Color := $0000A5FF; // Orange - Medium
    3: shpRiskIndicator.Brush.Color := clRed; // High
  else
    shpRiskIndicator.Brush.Color := clGray;
  end;

end;

procedure TFormDependencyViewer.ClearImpactSummary;
begin

  lblImpactUnit.Caption := 'Unit: (select a unit)';
  lblImpactDirect.Caption := 'Direct dependents: -';
  lblImpactTransitive.Caption := 'Total affected: -';
  lblImpactRisk.Caption := 'Risk: -';
  shpRiskIndicator.Brush.Color := clGray;

end;

procedure TFormDependencyViewer.btnExportCircularClick( Sender: TObject );
var
  Ext               : string;
begin

  if FScanner.CircularReferences.Count = 0 then
  begin
    ShowMessage( 'No circular references to export.' );
    Exit;
  end;

  // Set the title explicitly: the dialog is shared and btnExportViolationsClick
  // changes it, so it must be reset here too or it shows the wrong caption.
  SaveDialogExport.Title := 'Export Circular References';
  if SaveDialogExport.Execute then
  begin
    Ext             := LowerCase( ExtractFileExt( SaveDialogExport.FileName ) );

    try
      if Ext = '.csv' then
        ExportCircularRefsToCSV( SaveDialogExport.FileName )
      else
        ExportCircularRefsToTXT( SaveDialogExport.FileName );

      ShowMessage( Format( 'Exported %d circular references to %s',
          [ FScanner.CircularReferences.Count, SaveDialogExport.FileName ] ) );
    except
      on E: Exception do
        ShowMessage( 'Could not write file:'#13#10 + E.Message );
    end;
  end;

end;

procedure TFormDependencyViewer.ExportCircularRefsToCSV( const FileName: string );
var
  SL                : TStringList;
  CircRef           : TCircularReference;
  I                 : Integer;
  Line, UsesType    : string;
  MaxSteps, StepCount: Integer;
begin

  SL                := TStringList.Create;

  try
    // Determine maximum steps for header
    MaxSteps        := 0;

    for CircRef in FScanner.CircularReferences do
    begin

      if Length( CircRef.Steps ) > MaxSteps then
        MaxSteps    := Length( CircRef.Steps );
    end;

    // Build header row. UnitCount is the number of distinct units in the cycle
    // (Steps closes back on the first unit, so distinct units = Length - 1),
    // matching the count reported by the TXT export and avoiding two exports
    // disagreeing on the same data.
    Line            := 'Index,GroupUnitCount';

    for I := 1 to MaxSteps do
      Line          := Line + Format( ',Unit%d,UsesType%d', [ I, I ] );

    SL.Add( Line );

    // Add data rows
    StepCount       := 0;

    for CircRef in FScanner.CircularReferences do
    begin
      Inc( StepCount );
      Line          := Format( '%d,%d', [ StepCount, Length( CircRef.Members ) ] );

      for I := 0 to High( CircRef.Steps ) do
      begin

        if CircRef.Steps[ I ].IsInterface then
          UsesType  := 'interface'
        else
          UsesType  := 'implementation';

        // Escape any commas in unit names (unlikely but safe)
        Line        := Line + ',"' + CircRef.Steps[ I ].UnitName + '","' + UsesType + '"';
      end;

      // Pad remaining columns if needed
      for I := Length( CircRef.Steps ) to MaxSteps - 1 do
        Line        := Line + ',,';

      SL.Add( Line );
    end;

    SL.SaveToFile( FileName, TEncoding.UTF8 );
  finally
    SL.Free;
  end;

end;

procedure TFormDependencyViewer.ExportCircularRefsToTXT( const FileName: string );
var
  SL                : TStringList;
  CircRef           : TCircularReference;
  I, RefNum         : Integer;
  Line, UsesType    : string;
begin

  SL                := TStringList.Create;

  try
    SL.Add( 'Circular References Report' );
    SL.Add( '==========================' );
    SL.Add( '' );
    SL.Add( Format( 'Total circular references found: %d', [ FScanner.CircularReferences.Count ] ) );
    SL.Add( '' );

    RefNum          := 0;

    for CircRef in FScanner.CircularReferences do
    begin
      Inc( RefNum );
      SL.Add( Format( '--- Circular Reference #%d (%d units) ---', [ RefNum, Length( CircRef.Members ) ] ) );
      SL.Add( '' );
      SL.Add( '  Group: ' + string.Join( ', ', CircRef.Members ) );

      // Build the chain representation
      Line          := '';

      for I := 0 to High( CircRef.Steps ) do
      begin

        if I > 0 then
        begin

          if CircRef.Steps[ I ].IsInterface then
            UsesType := 'interface'
          else
            UsesType := 'implementation';

          Line      := Line + ' -[' + UsesType + ']-> ';
        end;

        Line        := Line + CircRef.Steps[ I ].UnitName;
      end;

      SL.Add( '  Chain: ' + Line );
      SL.Add( '' );

      // List each step with details
      SL.Add( '  Steps:' );

      for I := 0 to High( CircRef.Steps ) - 1 do
      begin

        if CircRef.Steps[ I + 1 ].IsInterface then
          UsesType  := 'interface'
        else
          UsesType  := 'implementation';

        SL.Add( Format( '    %d. %s uses %s (%s uses clause)',
            [ I + 1, CircRef.Steps[ I ].UnitName, CircRef.Steps[ I + 1 ].UnitName, UsesType ] ) );
      end;

      SL.Add( '' );
    end;

    SL.SaveToFile( FileName, TEncoding.UTF8 );
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

  Screen.Cursor     := crHourGlass;

  try
    FLayerViolations := FScanner.DetectLayerViolations( FLayerConfig );
    PopulateLayerViolations;
  finally
    Screen.Cursor   := crDefault;
  end;

end;

procedure TFormDependencyViewer.PopulateLayerViolations;
var
  Violation         : TLayerViolation;
  S, UsesType       : string;
begin

  ListBoxViolations.Items.BeginUpdate;

  try
    ListBoxViolations.Items.Clear;

    for Violation in FLayerViolations do
    begin

      if Violation.IsInterface then
        UsesType := 'interface'
      else
        UsesType    := 'implementation';

      S             := Format( '%s (%s) -> %s (%s) [%s]',
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

      // Colour code based on severity
      if Length( FLayerViolations ) >= 50 then
        lblLayerViolations.Font.Color := clRed
      else if Length( FLayerViolations ) >= 10 then
        lblLayerViolations.Font.Color := $000080FF // Orange
      else
        lblLayerViolations.Font.Color := clWindowText;
    end;
  finally
    ListBoxViolations.Items.EndUpdate;
  end;

end;

procedure TFormDependencyViewer.ListBoxViolationsDblClick( Sender: TObject );
var
  Idx               : Integer;
begin

  Idx               := ListBoxViolations.ItemIndex;

  if ( Idx >= 0 ) and ( Idx < Length( FLayerViolations ) ) then
    OpenUnitFile( FLayerViolations[ Idx ].SourceUnit );

end;

procedure TFormDependencyViewer.btnExportViolationsClick( Sender: TObject );
var
  Ext               : string;
begin

  if Length( FLayerViolations ) = 0 then
  begin
    ShowMessage( 'No layer violations to export.' );
    Exit;
  end;

  SaveDialogExport.Title := 'Export Layer Violations';

  if SaveDialogExport.Execute then
  begin
    Ext             := LowerCase( ExtractFileExt( SaveDialogExport.FileName ) );

    try
      if Ext = '.csv' then
        ExportViolationsToCSV( SaveDialogExport.FileName )
      else
        ExportViolationsToTXT( SaveDialogExport.FileName );

      ShowMessage( Format( 'Exported %d layer violations to %s',
          [ Length( FLayerViolations ), SaveDialogExport.FileName ] ) );
    except
      on E: Exception do
        ShowMessage( 'Could not write file:'#13#10 + E.Message );
    end;
  end;

end;

procedure TFormDependencyViewer.btnExportGraphClick( Sender: TObject );
var
  DotExe, PngFile, sMessage: string;
begin

  if ( Length( FScanner.GetAllUnits ) = 0 ) then
  begin
    ShowMessage( 'No scan results to export. Please scan a project first.' );
    Exit;
  end;

  DotExe            := FindGraphvizDot;

  if ( DotExe = '' ) then
  begin
    ShowMessage( 'Graphviz dot.exe not found.' );
    Exit;
  end;

  if ( not SaveDialogGraph.Execute ) then
    Exit;

  // The dialog asked about the .dot; the .png beside it is overwritten too, so ask about that.
  PngFile           := ChangeFileExt( SaveDialogGraph.FileName, '.png' );
  if FileExists( PngFile ) and ( MessageDlg( Format( '%s already exists.'#13#10'Replace it?', [ PngFile ] ),
      mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes ) then
    Exit;

  try
    ExportToDOT( SaveDialogGraph.FileName );
  except
    on E: EFCreateError do
    begin
      ShowMessage( 'Could not write file:'#13#10 + E.Message );
      Exit;
    end;
    on E: EInOutError do
    begin
      ShowMessage( 'Could not write file:'#13#10 + E.Message );
      Exit;
    end;
  end;

  if RenderDot( DotExe, SaveDialogGraph.FileName, PngFile, sMessage ) then
  begin
    ShellExecute( 0, 'open', PChar( PngFile ), nil, nil, SW_SHOWNORMAL );
    ShowMessage( Format( 'Exported dependency graph to:%s%s%s%s',
        [ sLineBreak, SaveDialogGraph.FileName, sLineBreak, PngFile ] ) );
  end
  else
    ShowMessage( Format( 'DOT file saved to %s, but %s', [ SaveDialogGraph.FileName, sMessage ] ) );

end;

function TFormDependencyViewer.RenderDot( const ADotExe, ADotFile, APngFile: string; out AMessage: string ): Boolean;
const
  /// <summary>How long a render may run before it is stopped, in milliseconds.</summary>
  RENDER_TIMEOUT_MS = 120000;
var
  SI                : TStartupInfo;
  PI                : TProcessInformation;
  ExitCode          : DWORD;
  CmdLine           : string;
begin

  Result            := False;
  AMessage          := '';
  CmdLine           := '"' + ADotExe + '" -Tpng "' + ADotFile + '" -o "' + APngFile + '"';
  UniqueString( CmdLine ); // CreateProcessW may write to the command-line buffer

  ZeroMemory( @SI, SizeOf( SI ) );
  SI.cb             := SizeOf( SI );
  SI.dwFlags        := STARTF_USESHOWWINDOW;
  SI.wShowWindow    := SW_HIDE;
  ZeroMemory( @PI, SizeOf( PI ) );

  if ( not CreateProcess( nil, PChar( CmdLine ), nil, nil, False, CREATE_NO_WINDOW, nil, nil, SI, PI ) ) then
  begin
    AMessage        := 'Graphviz could not be started: ' + SysErrorMessage( Winapi.Windows.GetLastError );
    Exit;
  end;

  FCancelRequested  := False;
  SetBusy( True, '&Cancel Render' );
  try
    lblProgress.Caption := 'Rendering the graph with Graphviz...';
    var iStart      := GetTickCount64;
    // Wait without blocking the IDE: wake for the process or for any message, and pump.
    while ( MsgWaitForMultipleObjects( 1, PI.hProcess, False, 200, QS_ALLINPUT ) <> WAIT_OBJECT_0 ) do
    begin
      Application.ProcessMessages;
      if FCancelRequested or Application.Terminated or ( GetTickCount64 - iStart > RENDER_TIMEOUT_MS ) then
      begin
        // Do not leave dot.exe running to write the PNG behind the user's back.
        TerminateProcess( PI.hProcess, 1 );
        WaitForSingleObject( PI.hProcess, 5000 );
        if FCancelRequested or Application.Terminated then
          AMessage  := 'rendering was cancelled.'
        else
          AMessage  := Format( 'Graphviz did not finish within %d seconds and was stopped.', [ RENDER_TIMEOUT_MS div 1000 ] );
        Exit;
      end;
    end;

    if ( not GetExitCodeProcess( PI.hProcess, ExitCode ) ) then
      ExitCode      := DWORD( -1 );
    Result          := ( ExitCode = 0 ) and FileExists( APngFile );
    if ( not Result ) then
      AMessage      := Format( 'Graphviz rendering failed (exit code %d).', [ ExitCode ] );
  finally
    CloseHandle( PI.hProcess );
    CloseHandle( PI.hThread );
    lblProgress.Caption := '';
    SetBusy( False, '' );
  end;

end;

function TFormDependencyViewer.FindGraphvizDot: string;
var
  PathEnv, Dir      : string;
  Dirs              : TArray<string>;
  Candidate         : string;
begin

  Result            := '';

  // Check common Graphviz installation paths first
  Candidate         := 'C:\Program Files\Graphviz\bin\dot.exe';

  if FileExists( Candidate ) then
  begin
    Result          := Candidate;
    Exit;
  end;

  Candidate         := 'C:\Program Files (x86)\Graphviz\bin\dot.exe';

  if FileExists( Candidate ) then
  begin
    Result          := Candidate;
    Exit;
  end;

  // Search PATH
  PathEnv           := GetEnvironmentVariable( 'PATH' );
  Dirs              := PathEnv.Split( [ ';' ] );

  for Dir in Dirs do
  begin
    // Skip empty entries (consecutive/trailing ';') and strip surrounding
    // quotes, otherwise IncludeTrailingPathDelimiter('') probes '\dot.exe' at
    // the drive root and quoted entries build invalid paths.
    var CleanDir := AnsiDequotedStr( Trim( Dir ), '"' );

    if CleanDir = '' then
      Continue;

    Candidate       := IncludeTrailingPathDelimiter( CleanDir ) + 'dot.exe';

    if FileExists( Candidate ) then
    begin
      Result        := Candidate;
      Exit;
    end;
  end;

end;

/// <summary>A unit name as a quoted Graphviz ID: never a DOT keyword, and unique per name.</summary>
/// <param name="AName">The unit name.</param>
/// <returns>The name in double quotes, with any backslash or quote escaped.</returns>
function DotId( const AName: string ): string;
begin

  Result            := '"' + StringReplace( StringReplace( AName, '\', '\\', [ rfReplaceAll ] ), '"', '\"',
    [ rfReplaceAll ] ) + '"';

end;

procedure TFormDependencyViewer.ExportToDOT( const FileName: string );
var
  SL                : TStringList;
  Units             : TArray<TUnitInfo>;
  UnitInfo          : TUnitInfo;
  Dep               : TUnitDependency;
  NodeName, FillColour, EdgeStyle, EdgeColour: string;
  CycleUnits        : TStringList;
  CircRef           : TCircularReference;
  I                 : Integer;
begin

  SL                := TStringList.Create;

  try
    // Build set of units involved in circular references
    CycleUnits      := TStringList.Create;

    try
      CycleUnits.CaseSensitive := False;
      CycleUnits.Sorted := True;
      CycleUnits.Duplicates := dupIgnore;

      for CircRef in FScanner.CircularReferences do
        for I := 0 to High( CircRef.Members ) do
          CycleUnits.Add( CircRef.Members[ I ] );

      SL.Add( 'digraph Dependencies {' );
      SL.Add( '  rankdir=LR;' );
      SL.Add( '  node [shape=box, style=filled, fontname="Segoe UI", fontsize=10];' );
      SL.Add( '  edge [fontname="Segoe UI", fontsize=8];' );
      SL.Add( '' );

      Units         := FScanner.GetAllUnits;

      // Emit nodes. IDs are quoted: unquoted, a unit named Graph, Node, Edge or Strict is a DOT
      // keyword, and replacing '.' would make A.B and A_B the same node.
      for UnitInfo in Units do
      begin
        NodeName := DotId( UnitInfo.UnitName );

        // Project units (have a source file) = light green; external/RTL = light blue
        if UnitInfo.FileName <> '' then
          FillColour := 'lightgreen'
        else
          FillColour := 'lightblue';

        if CycleUnits.IndexOf( UnitInfo.UnitName ) >= 0 then
          SL.Add( Format( '  %s [label=%s, fillcolor=%s, color=red, penwidth=2];',
              [ NodeName, NodeName, FillColour ] ) )
        else
          SL.Add( Format( '  %s [label=%s, fillcolor=%s];',
              [ NodeName, NodeName, FillColour ] ) );
      end;

      SL.Add( '' );

      // Emit edges
      for UnitInfo in Units do
      begin
        NodeName := DotId( UnitInfo.UnitName );

        for Dep in UnitInfo.Dependencies do
        begin

          // Only emit edges to units that are in our graph
          if FScanner.GetUnitInfo( Dep.UnitName ) <> nil then
          begin

            if Dep.IsInterface then
            begin
              EdgeStyle := 'solid';
              EdgeColour := 'blue';
            end
            else
            begin
              EdgeStyle := 'dashed';
              EdgeColour := 'forestgreen';
            end;

            // The target's ID is its node's: the unit's own spelling, not the uses entry's.
            SL.Add( Format( '  %s -> %s [style=%s, color=%s];',
                [ NodeName, DotId( FScanner.GetUnitInfo( Dep.UnitName ).UnitName ),
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

      // UTF-8 without a BOM: Graphviz reads UTF-8 by default and does not expect a BOM.
      SL.WriteBOM   := False;
      SL.SaveToFile( FileName, TEncoding.UTF8 );
    finally
      CycleUnits.Free;
    end;
  finally
    SL.Free;
  end;

end;

procedure TFormDependencyViewer.ExportViolationsToCSV( const FileName: string );
var
  SL                : TStringList;
  Violation         : TLayerViolation;
  UsesType          : string;
begin

  SL                := TStringList.Create;

  try
    SL.Add( 'SourceUnit,SourceLayer,TargetUnit,TargetLayer,UsesClause' );

    for Violation in FLayerViolations do
    begin

      if Violation.IsInterface then
        UsesType := 'interface'
      else
        UsesType    := 'implementation';

      SL.Add( Format( '"%s","%s","%s","%s","%s"',
          [ Violation.SourceUnit, Violation.SourceLayer,
            Violation.TargetUnit, Violation.TargetLayer, UsesType ] ) );
    end;

    SL.SaveToFile( FileName, TEncoding.UTF8 );
  finally
    SL.Free;
  end;

end;

procedure TFormDependencyViewer.ExportViolationsToTXT( const FileName: string );
var
  SL                : TStringList;
  Violation         : TLayerViolation;
  I                 : Integer;
  UsesType          : string;
begin

  SL                := TStringList.Create;

  try
    SL.Add( 'Layer Violations Report' );
    SL.Add( '=======================' );
    SL.Add( '' );
    SL.Add( Format( 'Total violations found: %d', [ Length( FLayerViolations ) ] ) );
    SL.Add( '' );

    I               := 0;

    for Violation in FLayerViolations do
    begin
      Inc( I );

      if Violation.IsInterface then
        UsesType    := 'interface'
      else
        UsesType    := 'implementation';

      SL.Add( Format( '%d. %s (%s layer) uses %s (%s layer)',
          [ I, Violation.SourceUnit, Violation.SourceLayer,
            Violation.TargetUnit, Violation.TargetLayer ] ) );
      SL.Add( Format( '   Uses clause: %s', [ UsesType ] ) );
      SL.Add( Format( '   VIOLATION: %s layer should not depend on %s layer',
          [ Violation.SourceLayer, Violation.TargetLayer ] ) );
      SL.Add( '' );
    end;

    SL.SaveToFile( FileName, TEncoding.UTF8 );
  finally
    SL.Free;
  end;

end;

end.

