inherited FormUnreachableCodeDetector: TFormUnreachableCodeDetector
  Caption = 'Unreachable Code Detector'
  ClientHeight = 450
  ClientWidth = 750
  Position = poMainFormCenter
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
  object pnlBottom: TPanel
    Left = 0
    Top = 409
    Width = 750
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object lblProgress: TLabel
      Left = 96
      Top = 14
      Width = 3
      Height = 13
    end
    object lblCount: TLabel
      Left = 450
      Top = 14
      Width = 3
      Height = 13
    end
    object btnClose: TButton
      Left = 667
      Top = 8
      Width = 75
      Height = 25
      Cancel = True
      Caption = 'Close'
      TabOrder = 0
      OnClick = btnCloseClick
    end
    object btnExport: TButton
      Left = 8
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Export CSV'
      TabOrder = 1
      OnClick = btnExportClick
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
