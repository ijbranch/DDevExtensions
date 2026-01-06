inherited FormLayerConfig: TFormLayerConfig
  Caption = 'Layer Configuration'
  ClientHeight = 450
  ClientWidth = 600
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 600
    Height = 200
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblLayers: TLabel
      Left = 8
      Top = 4
      Width = 35
      Height = 13
      Caption = 'Layers:'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblPatterns: TLabel
      Left = 200
      Top = 4
      Width = 124
      Height = 13
      Caption = 'Patterns (one per line):'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object ListBoxLayers: TListBox
      Left = 8
      Top = 20
      Width = 180
      Height = 140
      ItemHeight = 13
      TabOrder = 0
      OnClick = ListBoxLayersClick
    end
    object MemoPatterns: TMemo
      Left = 200
      Top = 20
      Width = 392
      Height = 140
      Anchors = [akLeft, akTop, akRight]
      ScrollBars = ssVertical
      TabOrder = 1
      OnChange = MemoPatternsChange
    end
    object btnAddLayer: TButton
      Left = 8
      Top = 166
      Width = 75
      Height = 25
      Caption = 'Add...'
      TabOrder = 2
      OnClick = btnAddLayerClick
    end
    object btnDeleteLayer: TButton
      Left = 89
      Top = 166
      Width = 75
      Height = 25
      Caption = 'Delete'
      TabOrder = 3
      OnClick = btnDeleteLayerClick
    end
  end
  object pnlMiddle: TPanel
    Left = 0
    Top = 200
    Width = 600
    Height = 200
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object lblRules: TLabel
      Left = 8
      Top = 8
      Width = 180
      Height = 13
      Caption = 'Allowed Dependencies (matrix):'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblRulesHelp: TLabel
      Left = 200
      Top = 8
      Width = 280
      Height = 13
      Caption = 'Check boxes to allow a layer to depend on another layer'
      Font.Color = clGray
    end
    object StringGridRules: TStringGrid
      Left = 8
      Top = 28
      Width = 584
      Height = 160
      Anchors = [akLeft, akTop, akRight, akBottom]
      ColCount = 2
      DefaultColWidth = 100
      DefaultRowHeight = 20
      FixedCols = 1
      RowCount = 2
      Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine]
      TabOrder = 0
      OnDrawCell = StringGridRulesDrawCell
      OnSelectCell = StringGridRulesSelectCell
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 400
    Width = 600
    Height = 50
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object btnOK: TButton
      Left = 432
      Top = 12
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 516
      Top = 12
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
    object btnDefaults: TButton
      Left = 8
      Top = 12
      Width = 100
      Height = 25
      Caption = 'Load Defaults'
      TabOrder = 2
      OnClick = btnDefaultsClick
    end
  end
end
