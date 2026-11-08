{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmLayerConfig;

/// <summary>
/// Modal dialog for editing the Dependency Viewer's <see cref="TLayerConfig"/>: lets the
/// user define layers (with wildcard patterns) and the matrix of allowed inter-layer
/// dependencies used to detect violations.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Grids, FrmBase, DependencyViewerCore, Vcl.Buttons;

type
  /// <summary>Two-dimensional boolean matrix used to represent the allowed-dependency rules.</summary>
  TBoolMatrix = TArray<TArray<Boolean>>;

  /// <summary>
  /// Modal form for editing layer definitions and dependency rules.
  /// </summary>
  TFormLayerConfig = class( TFormBase )
    /// <summary>Top panel hosting the layer list and pattern editor.</summary>
    pnlTop: TPanel;
    /// <summary>Middle panel hosting the rules grid.</summary>
    pnlMiddle: TPanel;
    /// <summary>Bottom panel hosting the OK/Cancel/Defaults buttons.</summary>
    pnlBottom: TPanel;
    /// <summary>Label for the layers list.</summary>
    lblLayers: TLabel;
    /// <summary>Label for the patterns memo.</summary>
    lblPatterns: TLabel;
    /// <summary>List of defined layers; each item's Object holds its TStringList of patterns.</summary>
    ListBoxLayers: TListBox;
    /// <summary>Multi-line editor for the selected layer's patterns (one per line).</summary>
    MemoPatterns: TMemo;
    /// <summary>Adds a new layer to the list.</summary>
    btnAddLayer: TBitBtn;
    /// <summary>Deletes the selected layer (after confirmation).</summary>
    btnDeleteLayer: TBitBtn;
    /// <summary>Label for the rules grid.</summary>
    lblRules: TLabel;
    /// <summary>Help text describing how to read the rules matrix.</summary>
    lblRulesHelp: TLabel;
    /// <summary>Custom-drawn checkbox grid showing which "from -&gt; to" dependencies are allowed.</summary>
    StringGridRules: TStringGrid;
    /// <summary>Confirms changes and closes the dialog.</summary>
    btnOK: TBitBtn;
    /// <summary>Discards changes and closes the dialog.</summary>
    btnCancel: TBitBtn;
    /// <summary>Resets layers and rules to the built-in defaults.</summary>
    btnDefaults: TBitBtn;
    /// <summary>Form OnCreate handler: initialises internal state.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure FormCreate( Sender: TObject );
    /// <summary>Form OnDestroy handler: releases the rules matrix.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Loads the selected layer's patterns into the memo.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure ListBoxLayersClick( Sender: TObject );
    /// <summary>Persists the memo's lines back into the selected layer's stored patterns.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure MemoPatternsChange( Sender: TObject );
    /// <summary>Prompts for a layer name and adds it to the list.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnAddLayerClick( Sender: TObject );
    /// <summary>Removes the selected layer and shrinks the rules matrix.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnDeleteLayerClick( Sender: TObject );
    /// <summary>Persists pending pattern edits before the dialog closes with OK.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnOKClick( Sender: TObject );
    /// <summary>Asks the user to confirm, then reloads the default configuration.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure btnDefaultsClick( Sender: TObject );
    /// <summary>Custom-draws each cell of the rules grid as a checkbox.</summary>
    /// <param name="Sender">The rules grid.</param>
    /// <param name="ACol">Grid column of the cell; 0 is the header column.</param>
    /// <param name="ARow">Grid row of the cell; 0 is the header row.</param>
    /// <param name="Rect">The cell's bounds on the grid canvas.</param>
    /// <param name="State">The cell's draw state; a focused cell gets a focus rectangle.</param>
    procedure StringGridRulesDrawCell( Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState );
    /// <summary>Lets the focus move to a data cell; moving the focus no longer toggles it.</summary>
    /// <param name="Sender">The grid.</param>
    /// <param name="ACol">Column about to be selected.</param>
    /// <param name="ARow">Row about to be selected.</param>
    /// <param name="CanSelect">False for the headers and the diagonal.</param>
    procedure StringGridRulesSelectCell( Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean );
    /// <summary>Toggles the rule under the mouse when a data cell is clicked.</summary>
    /// <param name="Sender">The grid.</param>
    /// <param name="Button">The mouse button released.</param>
    /// <param name="Shift">Modifier keys.</param>
    /// <param name="X">Horizontal position in the grid.</param>
    /// <param name="Y">Vertical position in the grid.</param>
    procedure StringGridRulesMouseUp( Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer );
    /// <summary>Toggles the focused rule when Space is pressed.</summary>
    /// <param name="Sender">The grid.</param>
    /// <param name="Key">The key pressed; cleared when it is Space.</param>
    procedure StringGridRulesKeyPress( Sender: TObject; var Key: Char );
  private
    /// <summary>The layer configuration being edited (owned externally).</summary>
    FLayerConfig: TLayerConfig;
    /// <summary>Matrix backing the allowed-dependency rules grid.</summary>
    FRulesMatrix: TBoolMatrix;
    /// <summary>Re-entrancy guard while loading data into controls.</summary>
    FUpdating: Boolean;
    /// <summary>Loads layers, patterns and rules into the UI.</summary>
    /// <param name="AConfig">The configuration to show: the one being edited, or a set of defaults
    /// that only OK will store.</param>
    procedure LoadFromConfig( AConfig: TLayerConfig );
    /// <summary>Flips one rule of the matrix, if the cell is a data cell off the diagonal.</summary>
    /// <param name="ACol">Grid column ( the To layer + 1 ).</param>
    /// <param name="ARow">Grid row ( the From layer + 1 ).</param>
    procedure ToggleRule( ACol, ARow: Integer );
    /// <summary>Writes the current UI state back to <see cref="FLayerConfig"/> and saves it.</summary>
    procedure SaveToConfig;
    /// <summary>Refreshes the delete button's enabled state based on selection.</summary>
    procedure RefreshLayerList;
    /// <summary>Recalculates and repaints the rules grid from the current layers.</summary>
    procedure RefreshRulesGrid;
    /// <summary>Persists the patterns memo back into the selected layer's pattern list.</summary>
    procedure SaveCurrentPatterns;
  public
    /// <summary>Shows the dialog modally and persists the changes when the user confirms.</summary>
    /// <param name="LayerConfig">The configuration to edit; updated in place if the user clicks OK.</param>
    /// <returns>True when the user clicked OK; False on Cancel, which leaves the configuration exactly
    /// as it was.</returns>
    class function Execute( LayerConfig: TLayerConfig ): Boolean;
  end;

implementation

{$R *.dfm}

class function TFormLayerConfig.Execute( LayerConfig: TLayerConfig ): Boolean;
var
  Form: TFormLayerConfig;
begin

  Form := TFormLayerConfig.Create( Application );

  try
    Form.FLayerConfig := LayerConfig;
    Form.LoadFromConfig( LayerConfig );
    Result := Form.ShowModal = mrOK;

    if Result then
      Form.SaveToConfig;
  finally
    Form.Free;
  end;

end;

procedure TFormLayerConfig.FormCreate( Sender: TObject );
begin

  FUpdating := False;

end;

procedure TFormLayerConfig.FormDestroy( Sender: TObject );
var
  I: Integer;
begin

  // Free the per-layer pattern lists stored in Items.Objects[] (otherwise only
  // freed on delete/defaults), so they are released on every dialog close.
  for I := 0 to ListBoxLayers.Items.Count - 1 do
    if ListBoxLayers.Items.Objects[ I ] <> nil then
      TStringList( ListBoxLayers.Items.Objects[ I ] ).Free;

  SetLength( FRulesMatrix, 0 );

end;

procedure TFormLayerConfig.LoadFromConfig( AConfig: TLayerConfig );
var
  Layers: TArray<TLayerDefinition>;
  Names: TArray<string>;
  I, J: Integer;
  SL: TStringList;
begin

  FUpdating := True;

  try
    Layers := AConfig.GetLayers;

    // Populate layer list with patterns attached as Objects
    ListBoxLayers.Items.Clear;

    for I := 0 to High( Layers ) do
    begin
      // Create TStringList to hold patterns for this layer
      SL := TStringList.Create;

      for J := 0 to High( Layers[ I ].Patterns ) do
        SL.Add( Layers[ I ].Patterns[ J ] );

      ListBoxLayers.Items.AddObject( Layers[ I ].Name, SL );
    end;

    // The rules as ticks; a layer with no rule line ( "may use every layer" ) shows every box
    // ticked, so OK on an untouched dialog does not change what the rules mean.
    SetLength( Names, Length( Layers ) );
    for I := 0 to High( Layers ) do
      Names[ I ] := Layers[ I ].Name;
    FRulesMatrix := LayerRulesMatrix( AConfig, Names );

    RefreshLayerList;
    RefreshRulesGrid;

    // Select first layer and populate patterns memo directly
    // (can't use ListBoxLayersClick here because FUpdating is True)
    if ListBoxLayers.Items.Count > 0 then
    begin
      ListBoxLayers.ItemIndex := 0;
      MemoPatterns.Enabled := True;

      if ListBoxLayers.Items.Objects[ 0 ] <> nil then
        MemoPatterns.Lines.Assign( TStringList( ListBoxLayers.Items.Objects[ 0 ] ) )
      else
        MemoPatterns.Clear;
    end;
  finally
    FUpdating := False;
  end;

end;

procedure TFormLayerConfig.SaveToConfig;
var
  I: Integer;
  Patterns: TArray<string>;
  Names: TArray<string>;
begin

  // A layer deleted here loses its rule line; a rule line for a layer the file never defined is
  // not this dialog's to drop, so every other rule is kept as it was.
  for var OldLayer in FLayerConfig.GetLayers do
    if ( ListBoxLayers.Items.IndexOf( OldLayer.Name ) < 0 ) then
      FLayerConfig.RemoveRules( OldLayer.Name );
  FLayerConfig.ClearLayers;

  // Save layers with patterns
  for I := 0 to ListBoxLayers.Items.Count - 1 do
  begin
    // Get patterns from stored object
    if ListBoxLayers.Items.Objects[ I ] <> nil then
    begin
      Patterns := TArray<string>( TStringList( ListBoxLayers.Items.Objects[ I ] ).ToStringArray );
      FLayerConfig.AddLayer( ListBoxLayers.Items[ I ], Patterns );
    end
    else
      FLayerConfig.AddLayer( ListBoxLayers.Items[ I ], [ ] );
  end;

  // Save rules
  Names := ListBoxLayers.Items.ToStringArray;
  ApplyLayerRulesMatrix( FLayerConfig, Names, FRulesMatrix );

  try
    FLayerConfig.SaveToFile;
  except
    // A locked or read-only folder: the rules apply for this session, and the user is told.
    on E: EFCreateError do
      ShowMessage( 'The layer rules apply for this session but could not be saved:'#13#10 + E.Message );
  end;

end;

procedure TFormLayerConfig.RefreshLayerList;
begin

  btnDeleteLayer.Enabled := ListBoxLayers.ItemIndex >= 0;

end;

procedure TFormLayerConfig.RefreshRulesGrid;
var
  I: Integer;
begin

  if ListBoxLayers.Items.Count = 0 then
  begin
    StringGridRules.ColCount := 2;
    StringGridRules.RowCount := 2;
    StringGridRules.Cells[ 0, 0 ] := '';
    StringGridRules.Cells[ 1, 0 ] := '';
    StringGridRules.Cells[ 0, 1 ] := '';
    StringGridRules.Cells[ 1, 1 ] := '';
    Exit;
  end;

  StringGridRules.ColCount := ListBoxLayers.Items.Count + 1;
  StringGridRules.RowCount := ListBoxLayers.Items.Count + 1;

  // Set headers
  StringGridRules.Cells[ 0, 0 ] := 'From \ To';

  for I := 0 to ListBoxLayers.Items.Count - 1 do
  begin
    StringGridRules.Cells[ I + 1, 0 ] := ListBoxLayers.Items[ I ];
    StringGridRules.Cells[ 0, I + 1 ] := ListBoxLayers.Items[ I ];
  end;

  // Clear data cells (they will be drawn with checkboxes)
  for I := 1 to StringGridRules.RowCount - 1 do
    StringGridRules.Cells[ I, I ] := '';

  StringGridRules.Invalidate;

end;

procedure TFormLayerConfig.ListBoxLayersClick( Sender: TObject );
var
  Idx: Integer;
  SL: TStringList;
  Layers: TArray<TLayerDefinition>;
  I, J: Integer;
begin

  if FUpdating then
    Exit;

  Idx := ListBoxLayers.ItemIndex;
  RefreshLayerList;

  if Idx < 0 then
  begin
    MemoPatterns.Clear;
    MemoPatterns.Enabled := False;
    Exit;
  end;

  MemoPatterns.Enabled := True;
  FUpdating := True;

  try
    // Load patterns from stored TStringList or from config
    if ListBoxLayers.Items.Objects[ Idx ] <> nil then
    begin
      SL := TStringList( ListBoxLayers.Items.Objects[ Idx ] );
      MemoPatterns.Lines.Assign( SL );
    end
    else
    begin
      // Get from config
      Layers := FLayerConfig.GetLayers;

      for I := 0 to High( Layers ) do
      begin

        if SameText( Layers[ I ].Name, ListBoxLayers.Items[ Idx ] ) then
        begin
          MemoPatterns.Lines.Clear;

          for J := 0 to High( Layers[ I ].Patterns ) do
            MemoPatterns.Lines.Add( Layers[ I ].Patterns[ J ] );

          // Store for future use
          SL := TStringList.Create;
          SL.Assign( MemoPatterns.Lines );
          ListBoxLayers.Items.Objects[ Idx ] := SL;
          Break;
        end;
      end;
    end;
  finally
    FUpdating := False;
  end;

end;

procedure TFormLayerConfig.MemoPatternsChange( Sender: TObject );
begin

  SaveCurrentPatterns;

end;

procedure TFormLayerConfig.SaveCurrentPatterns;
var
  Idx: Integer;
  SL: TStringList;
begin

  if FUpdating then
    Exit;

  Idx := ListBoxLayers.ItemIndex;

  if Idx < 0 then
    Exit;

  // Store patterns in the Objects property
  if ListBoxLayers.Items.Objects[ Idx ] = nil then
    ListBoxLayers.Items.Objects[ Idx ] := TStringList.Create;

  SL := TStringList( ListBoxLayers.Items.Objects[ Idx ] );
  SL.Assign( MemoPatterns.Lines );

end;

procedure TFormLayerConfig.btnAddLayerClick( Sender: TObject );
var
  LayerName: string;
  I, J, OldCount: Integer;
  NewMatrix: TBoolMatrix;
begin

  LayerName := Trim( InputBox( 'Add Layer', 'Enter layer name:', '' ) );

  if LayerName = '' then
    Exit;

  // '=' and ',' are the LayerConfig.txt field delimiters; a name containing them
  // cannot round-trip through Save/LoadFromFile, so reject it at input.
  if ( Pos( '=', LayerName ) > 0 ) or ( Pos( ',', LayerName ) > 0 ) then
  begin
    ShowMessage( 'A layer name cannot contain "=" or "," characters.' );
    Exit;
  end;

  // Check for duplicate
  for I := 0 to ListBoxLayers.Items.Count - 1 do
  begin

    if SameText( ListBoxLayers.Items[ I ], LayerName ) then
    begin
      ShowMessage( 'A layer with this name already exists.' );
      Exit;
    end;
  end;

  OldCount := ListBoxLayers.Items.Count;

  // Resize rules matrix
  SetLength( NewMatrix, OldCount + 1, OldCount + 1 );

  // Copy old matrix
  for I := 0 to OldCount - 1 do
  begin

    for J := 0 to OldCount - 1 do
      NewMatrix[ I, J ] := FRulesMatrix[ I, J ];
  end;

  // Initialise new row/column to false
  for I := 0 to OldCount do
  begin
    NewMatrix[ I, OldCount ] := False;
    NewMatrix[ OldCount, I ] := False;
  end;

  FRulesMatrix := NewMatrix;

  // Add layer
  ListBoxLayers.Items.AddObject( LayerName, TStringList.Create );
  ListBoxLayers.ItemIndex := ListBoxLayers.Items.Count - 1;
  ListBoxLayersClick( nil );
  RefreshRulesGrid;

end;

procedure TFormLayerConfig.btnDeleteLayerClick( Sender: TObject );
var
  Idx, I, J: Integer;
  NewMatrix: TBoolMatrix;
  OldCount: Integer;
  SrcI, SrcJ: Integer;
begin

  Idx := ListBoxLayers.ItemIndex;

  if Idx < 0 then
    Exit;

  if MessageDlg( Format( 'Delete layer "%s"?', [ ListBoxLayers.Items[ Idx ] ] ),
    mtConfirmation, [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  OldCount := ListBoxLayers.Items.Count;

  // Resize rules matrix (remove row and column at Idx)
  if OldCount > 1 then
  begin
    SetLength( NewMatrix, OldCount - 1, OldCount - 1 );

    SrcI := 0;

    for I := 0 to OldCount - 2 do
    begin

      if SrcI = Idx then
        Inc( SrcI );

      SrcJ := 0;

      for J := 0 to OldCount - 2 do
      begin

        if SrcJ = Idx then
          Inc( SrcJ );

        NewMatrix[ I, J ] := FRulesMatrix[ SrcI, SrcJ ];
        Inc( SrcJ );
      end;

      Inc( SrcI );
    end;

    FRulesMatrix := NewMatrix;
  end
  else
    SetLength( FRulesMatrix, 0 );

  // Free stored patterns
  if ListBoxLayers.Items.Objects[ Idx ] <> nil then
    TStringList( ListBoxLayers.Items.Objects[ Idx ] ).Free;

  ListBoxLayers.Items.Delete( Idx );

  if ListBoxLayers.Items.Count > 0 then
  begin

    if Idx >= ListBoxLayers.Items.Count then
      ListBoxLayers.ItemIndex := ListBoxLayers.Items.Count - 1
    else
      ListBoxLayers.ItemIndex := Idx;

    ListBoxLayersClick( nil );
  end
  else
  begin
    MemoPatterns.Clear;
    MemoPatterns.Enabled := False;
  end;

  RefreshRulesGrid;

end;

procedure TFormLayerConfig.btnOKClick( Sender: TObject );
begin

  SaveCurrentPatterns;

end;

procedure TFormLayerConfig.btnDefaultsClick( Sender: TObject );
var
  I: Integer;
begin

  if MessageDlg( 'Reset to default layer configuration?', mtConfirmation,
    [ mbYes, mbNo ], 0 ) <> mrYes then
    Exit;

  // Free stored pattern lists
  for I := 0 to ListBoxLayers.Items.Count - 1 do
  begin

    if ListBoxLayers.Items.Objects[ I ] <> nil then
      TStringList( ListBoxLayers.Items.Objects[ I ] ).Free;
  end;
  ListBoxLayers.Items.Clear;

  // Show the defaults without touching the configuration being edited: only OK stores them,
  // and Cancel leaves the viewer's rules as they were.
  var Defaults := TLayerConfig.Create( '' );
  try
    Defaults.LoadDefaults;
    LoadFromConfig( Defaults );
  finally
    Defaults.Free;
  end;

end;

procedure TFormLayerConfig.StringGridRulesDrawCell( Sender: TObject;
  ACol, ARow: Integer; Rect: TRect; State: TGridDrawState );
var
  CheckRect: TRect;
  IsChecked: Boolean;
  CheckSize: Integer;
begin

  // Draw header cells normally
  if ( ACol = 0 ) or ( ARow = 0 ) then
    Exit;

  // Don't allow same-layer dependencies (diagonal)
  if ACol = ARow then
  begin
    StringGridRules.Canvas.Brush.Color := clBtnFace;
    StringGridRules.Canvas.FillRect( Rect );
    Exit;
  end;

  // Draw checkbox
  StringGridRules.Canvas.Brush.Color := clWindow;
  StringGridRules.Canvas.FillRect( Rect );

  CheckSize := 13;
  CheckRect.Left   := Rect.Left + ( Rect.Right - Rect.Left - CheckSize ) div 2;
  CheckRect.Top    := Rect.Top + ( Rect.Bottom - Rect.Top - CheckSize ) div 2;
  CheckRect.Right  := CheckRect.Left + CheckSize;
  CheckRect.Bottom := CheckRect.Top + CheckSize;

  // Get checked state from matrix (ARow-1 is "From", ACol-1 is "To")
  if ( ARow - 1 < Length( FRulesMatrix ) ) and ( ACol - 1 < Length( FRulesMatrix ) ) then
    IsChecked := FRulesMatrix[ ARow - 1, ACol - 1 ]
  else
    IsChecked := False;

  // Draw checkbox frame
  DrawFrameControl( StringGridRules.Canvas.Handle, CheckRect, DFC_BUTTON,
    DFCS_BUTTONCHECK or ( DFCS_CHECKED * Ord( IsChecked ) ) );

  // Show where Space will act.
  if ( gdFocused in State ) then
    StringGridRules.Canvas.DrawFocusRect( Rect );

end;

procedure TFormLayerConfig.ToggleRule( ACol, ARow: Integer );
begin

  if ( ACol > 0 ) and ( ARow > 0 ) and ( ACol <> ARow ) and
     ( ARow - 1 < Length( FRulesMatrix ) ) and ( ACol - 1 < Length( FRulesMatrix ) ) then
  begin
    FRulesMatrix[ ARow - 1, ACol - 1 ] := not FRulesMatrix[ ARow - 1, ACol - 1 ];
    StringGridRules.Invalidate;
  end;

end;

procedure TFormLayerConfig.StringGridRulesMouseUp( Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer );
var
  iCol, iRow: Integer;
begin

  if ( Button <> mbLeft ) then
    Exit;
  StringGridRules.MouseToCell( X, Y, iCol, iRow );
  ToggleRule( iCol, iRow );

end;

procedure TFormLayerConfig.StringGridRulesKeyPress( Sender: TObject; var Key: Char );
begin

  if ( Key = ' ' ) then
  begin
    ToggleRule( StringGridRules.Col, StringGridRules.Row );
    Key := #0;
  end;

end;

procedure TFormLayerConfig.StringGridRulesSelectCell( Sender: TObject;
  ACol, ARow: Integer; var CanSelect: Boolean );
begin

  // Selecting a cell only moves the focus: arrow keys used to flip every rule they passed.
  CanSelect := ( ACol > 0 ) and ( ARow > 0 ) and ( ACol <> ARow );

end;

end.
