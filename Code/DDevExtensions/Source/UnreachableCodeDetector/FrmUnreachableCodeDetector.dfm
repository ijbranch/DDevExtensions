inherited FormUnreachableCodeDetector: TFormUnreachableCodeDetector
  Caption = 'Unreachable Code Detector'
  ClientHeight = 450
  ClientWidth = 750
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 750
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblFilter: TLabel
      Left = 136
      Top = 14
      Width = 28
      Height = 13
      Caption = 'Filter:'
    end
    object lblProject: TLabel
      Left = 312
      Top = 14
      Width = 3
      Height = 13
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clNavy
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object btnScan: TButton
      Left = 8
      Top = 8
      Width = 113
      Height = 25
      Caption = 'Scan Project'
      TabOrder = 0
      OnClick = btnScanClick
    end
    object cmbFilter: TComboBox
      Left = 170
      Top = 10
      Width = 130
      Height = 21
      Style = csDropDownList
      TabOrder = 1
      OnChange = cmbFilterChange
    end
  end
  object pnlBottom: TGridPanel
    Left = 0
    Top = 409
    Width = 750
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    ColumnCollection = <
      item
        Value = 33.333333333333330000
      end
      item
        Value = 33.333333333333330000
      end
      item
        Value = 33.333333333333330000
      end>
    ControlCollection = <
      item
        Column = 0
        Control = btnExport
        Row = 0
      end
      item
        Column = 1
        Control = lblProgress
        Row = 0
      end
      item
        Column = 1
        Control = lblCount
        Row = 0
      end
      item
        Column = 2
        Control = btnClose
        Row = 0
      end>
    RowCollection = <
      item
        Value = 100.000000000000000000
      end>
    TabOrder = 1
    object lblProgress: TLabel
      AlignWithMargins = True
      Left = 254
      Top = 14
      Width = 3
      Height = 13
    end
    object lblCount: TLabel
      AlignWithMargins = True
      Left = 263
      Top = 14
      Width = 3
      Height = 13
    end
    object btnExport: TButton
      AlignWithMargins = True
      Left = 4
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Export CSV'
      TabOrder = 0
      OnClick = btnExportClick
    end
    object btnClose: TButton
      AlignWithMargins = True
      Left = 667
      Top = 8
      Width = 75
      Height = 25
      Cancel = True
      Caption = 'Close'
      TabOrder = 1
      OnClick = btnCloseClick
    end
  end
  object ListView: TListView
    Left = 0
    Top = 41
    Width = 750
    Height = 368
    Align = alClient
    Columns = <
      item
        Caption = 'Unit'
        Width = 150
      end
      item
        Caption = 'Line'
        Width = 60
      end
      item
        Caption = 'Reason'
        Width = 100
      end
      item
        Caption = 'Code Preview'
        Width = 400
      end>
    GridLines = True
    ReadOnly = True
    RowSelect = True
    TabOrder = 2
    ViewStyle = vsReport
    OnColumnClick = ListViewColumnClick
    OnCompare = ListViewCompare
    OnDblClick = ListViewDblClick
  end
end
