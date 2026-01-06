inherited FormDependencyViewer: TFormDependencyViewer
  Caption = 'Dependency Viewer'
  ClientHeight = 500
  ClientWidth = 800
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Splitter: TSplitter
    Left = 250
    Top = 33
    Height = 426
    Align = alRight
    ExplicitLeft = 250
    ExplicitTop = 33
    ExplicitHeight = 426
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 33
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnScanProject: TButton
      Left = 8
      Top = 4
      Width = 113
      Height = 25
      Caption = 'Scan Active Project'
      TabOrder = 0
      OnClick = btnScanProjectClick
    end
    object lblProgress: TLabel
      Left = 612
      Top = 10
      Width = 3
      Height = 13
      Visible = False
    end
    object rbUses: TRadioButton
      Left = 136
      Top = 8
      Width = 73
      Height = 17
      Caption = '&Uses'
      Checked = True
      TabOrder = 1
      TabStop = True
      OnClick = ViewModeChanged
    end
    object rbUsedBy: TRadioButton
      Left = 216
      Top = 8
      Width = 73
      Height = 17
      Caption = 'Used &By'
      TabOrder = 2
      OnClick = ViewModeChanged
    end
    object chkShowDepth: TCheckBox
      Left = 312
      Top = 8
      Width = 97
      Height = 17
      Caption = 'Show &Depth'
      Checked = True
      State = cbChecked
      TabOrder = 3
      OnClick = ViewModeChanged
    end
    object btnLayers: TButton
      Left = 424
      Top = 4
      Width = 75
      Height = 25
      Caption = 'Layers...'
      TabOrder = 4
      OnClick = btnLayersClick
    end
    object btnCheckLayers: TButton
      Left = 504
      Top = 4
      Width = 100
      Height = 25
      Caption = 'Check Layers'
      TabOrder = 5
      OnClick = btnCheckLayersClick
    end
  end
  object pnlBottom: TGridPanel
    Left = 0
    Top = 459
    Width = 800
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    ColumnCollection = <
      item
        Value = 50.000000000000000000
      end
      item
        Value = 50.000000000000000000
      end>
    ControlCollection = <
      item
        Column = 1
        Control = btnClose
        Row = 0
      end>
    RowCollection = <
      item
        Value = 100.000000000000000000
      end>
    TabOrder = 1
    object btnClose: TButton
      AlignWithMargins = True
      Left = 717
      Top = 8
      Width = 75
      Height = 25
      Cancel = True
      Caption = 'Close'
      Default = True
      ModalResult = 1
      TabOrder = 0
      OnClick = btnCloseClick
    end
  end
  object TreeView: TTreeView
    Left = 0
    Top = 33
    Width = 250
    Height = 426
    Align = alClient
    Indent = 19
    ReadOnly = True
    TabOrder = 2
    OnAdvancedCustomDrawItem = TreeViewAdvancedCustomDrawItem
    OnChange = TreeViewChange
    OnExpanding = TreeViewExpanding
  end
  object pnlRight: TPanel
    Left = 253
    Top = 33
    Width = 547
    Height = 426
    Align = alRight
    BevelOuter = bvNone
    TabOrder = 3
    object pnlImpact: TPanel
      Left = 0
      Top = 0
      Width = 547
      Height = 73
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object lblImpactHeader: TLabel
        Left = 8
        Top = 4
        Width = 80
        Height = 13
        Caption = 'Impact Analysis:'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object lblImpactUnit: TLabel
        Left = 24
        Top = 20
        Width = 25
        Height = 13
        Caption = 'Unit:'
      end
      object lblImpactDirect: TLabel
        Left = 24
        Top = 36
        Width = 90
        Height = 13
        Caption = 'Direct dependents:'
      end
      object lblImpactTransitive: TLabel
        Left = 24
        Top = 52
        Width = 103
        Height = 13
        Caption = 'Transitive dependents:'
      end
      object lblImpactRisk: TLabel
        Left = 200
        Top = 52
        Width = 23
        Height = 13
        Caption = 'Risk:'
      end
      object shpRiskIndicator: TShape
        Left = 176
        Top = 52
        Width = 16
        Height = 13
        Brush.Color = clGray
        Shape = stRoundRect
      end
    end
    object lblCircularRefs: TLabel
      Left = 8
      Top = 81
      Width = 100
      Height = 13
      Caption = 'Circular References:'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object btnExportCircular: TButton
      Left = 464
      Top = 76
      Width = 75
      Height = 21
      Anchors = [akTop, akRight]
      Caption = 'Export...'
      TabOrder = 2
      OnClick = btnExportCircularClick
    end
    object ListBoxCircular: TListBox
      Left = 0
      Top = 100
      Width = 547
      Height = 160
      Anchors = [akLeft, akTop, akRight]
      ItemHeight = 13
      TabOrder = 1
      OnClick = ListBoxCircularClick
      OnDblClick = ListBoxCircularDblClick
    end
    object lblLayerViolations: TLabel
      Left = 8
      Top = 268
      Width = 90
      Height = 13
      Caption = 'Layer Violations:'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object btnExportViolations: TButton
      Left = 464
      Top = 263
      Width = 75
      Height = 21
      Anchors = [akTop, akRight]
      Caption = 'Export...'
      TabOrder = 3
      OnClick = btnExportViolationsClick
    end
    object ListBoxViolations: TListBox
      Left = 0
      Top = 287
      Width = 547
      Height = 139
      Align = alBottom
      Anchors = [akLeft, akTop, akRight, akBottom]
      ItemHeight = 13
      TabOrder = 4
      OnDblClick = ListBoxViolationsDblClick
    end
  end
  object SaveDialogExport: TSaveDialog
    DefaultExt = 'csv'
    Filter = 'CSV Files (*.csv)|*.csv|Text Files (*.txt)|*.txt|All Files (*.*)|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Title = 'Export Circular References'
    Left = 400
    Top = 8
  end
end
