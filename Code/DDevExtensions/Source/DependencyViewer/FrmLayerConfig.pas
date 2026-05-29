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
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Grids, FrmBase, DependencyViewer;

type
  /// <summary>Two-dimensional boolean matrix used to represent the allowed-dependency rules.</summary>
  TBoolMatrix = array of array of Boolean;

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
    btnAddLayer: TButton;
    /// <summary>Deletes the selected layer (after confirmation).</summary>
    btnDeleteLayer: TButton;
    /// <summary>Label for the rules grid.</summary>
    lblRules: TLabel;
    /// <summary>Help text describing how to read the rules matrix.</summary>
    lblRulesHelp: TLabel;
    /// <summary>Custom-drawn checkbox grid showing which "from -&gt; to" dependencies are allowed.</summary>
    StringGridRules: TStringGrid;
    /// <summary>Confirms changes and closes the dialog.</summary>
    btnOK: TButton;
    /// <summary>Discards changes and closes the dialog.</summary>
    btnCancel: TButton;
    /// <summary>Resets layers and rules to the built-in defaults.</summary>
    btnDefaults: TButton;
    /// <summary>Form OnCreate handler: initialises internal state.</summary>
    procedure FormCreate( Sender: TObject );
    /// <summary>Form OnDestroy handler: releases the rules matrix.</summary>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Loads the selected layer's patterns into the memo.</summary>
    procedure ListBoxLayersClick( Sender: TObject );
    /// <summary>Persists the memo's lines back into the selected layer's stored patterns.</summary>
    procedure MemoPatternsChange( Sender: TObject );
    /// <summary>Prompts for a layer name and adds it to the list.</summary>
    procedure btnAddLayerClick( Sender: TObject );
    /// <summary>Removes the selected layer and shrinks the rules matrix.</summary>
    procedure btnDeleteLayerClick( Sender: TObject );
    /// <summary>Persists pending pattern edits before the dialog closes with OK.</summary>
    procedure btnOKClick( Sender: TObject );
    /// <summary>Asks the user to confirm, then reloads the default configuration.</summary>
    procedure btnDefaultsClick( Sender: TObject );
    /// <summary>Custom-draws each cell of the rules grid as a checkbox.</summary>
    procedure StringGridRulesDrawCell( Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState );
    /// <summary>Toggles the boolean cell when the user clicks a non-diagonal data cell.</summary>
    procedure StringGridRulesSelectCell( Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean );
  private
    /// <summary>The layer configuration being edited (owned externally).</summary>
    FLayerConfig: TLayerConfig;
    /// <summary>Matrix backing the allowed-dependency rules grid.</summary>
    FRulesMatrix: TBoolMatrix;
    /// <summary>Re-entrancy guard while loading data into controls.</summary>
    FUpdating: Boolean;
    /// <summary>Loads layers, patterns and rules from <see cref="FLayerConfig"/> into the UI.</summary>
    procedure LoadFromConfig;
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
    /// <returns>True when the user clicked OK and changes were saved; False on Cancel.</returns>
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
    Form.LoadFromConfig;
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

procedure TFormLayerConfig.LoadFromConfig;
var
  Layers: TArray<TLayerDefinition>;
  I, J, K: Integer;
  Allowed: TArray<string>;
  SL: TStringList;
begin

  FUpdating := True;

  try
    Layers := FLayerConfig.GetLayers;

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

    // Initialize rules matrix
    SetLength( FRulesMatrix, Length( Layers ), Length( Layers ) );

    for I := 0 to High( Layers ) do
    begin

      for J := 0 to High( Layers ) do
        FRulesMatrix[ I, J ] := False;
    end;

    // Load allowed dependencies into matrix
    for I := 0 to High( Layers ) do
    begin
      Allowed := FLayerConfig.GetAllowedDependencies( Layers[ I ].Name );

      // Find index of each allowed target layer
      for K := 0 to High( Allowed ) do
      begin

        for J := 0 to High( Layers ) do
        begin

          if SameText( Layers[ J ].Name, Allowed[ K ] ) then
          begin
            FRulesMatrix[ I, J ] := True;
            Break;
          end;
        end;
      end;
    end;

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
  I, J, K: Integer;
  Patterns: TArray<string>;
  Allowed: TArray<string>;
  AllowedCount: Integer;
begin

  FLayerConfig.Clear;

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
  for I := 0 to ListBoxLayers.Items.Count - 1 do
  begin
    AllowedCount := 0;

    // Count allowed dependencies
    for J := 0 to ListBoxLayers.Items.Count - 1 do
    begin

      if ( I <> J ) and FRulesMatrix[ I, J ] then
        Inc( AllowedCount );
    end;

    // Build allowed array
    SetLength( Allowed, AllowedCount );
    K := 0;

    for J := 0 to ListBoxLayers.Items.Count - 1 do
    begin

      if ( I <> J ) and FRulesMatrix[ I, J ] then
      begin
        Allowed[ K ] := ListBoxLayers.Items[ J ];
        Inc( K );
      end;
    end;

    FLayerConfig.SetAllowedDependencies( ListBoxLayers.Items[ I ], Allowed );
  end;

  FLayerConfig.SaveToFile;

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

  // Initialize new row/column to false
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

  FLayerConfig.LoadDefaults;
  LoadFromConfig;

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

end;

procedure TFormLayerConfig.StringGridRulesSelectCell( Sender: TObject;
  ACol, ARow: Integer; var CanSelect: Boolean );
begin

  // Toggle checkbox on click
  if ( ACol > 0 ) and ( ARow > 0 ) and ( ACol <> ARow ) then
  begin

    if ( ARow - 1 < Length( FRulesMatrix ) ) and ( ACol - 1 < Length( FRulesMatrix ) ) then
    begin
      FRulesMatrix[ ARow - 1, ACol - 1 ] := not FRulesMatrix[ ARow - 1, ACol - 1 ];
      StringGridRules.Invalidate;
    end;
  end;

  CanSelect := False;

end;

end.
