object FormCodeQualityAnalyzer: TFormCodeQualityAnalyzer
  Left = 0
  Top = 0
  Caption = 'Code Quality Analyzer'
  ClientHeight = 450
  ClientWidth = 750
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poMainFormCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 13
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 750
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblProgress: TLabel
      Left = 120
      Top = 14
      Width = 60
      Height = 13
      Caption = 'lblProgress'
      Visible = False
    end
    object lblSummary: TLabel
      Left = 120
      Top = 14
      Width = 55
      Height = 13
      Caption = 'lblSummary'
      Visible = False
    end
    object lblCategory: TLabel
      Left = 400
      Top = 14
      Width = 49
      Height = 13
      Caption = 'Category:'
    end
    object lblSeverity: TLabel
      Left = 580
      Top = 14
      Width = 44
      Height = 13
      Caption = 'Severity:'
    end
    object btnScan: TButton
      Left = 8
      Top = 8
      Width = 100
      Height = 25
      Caption = 'Check Project'
      TabOrder = 0
      OnClick = btnScanClick
    end
    object cboCategory: TComboBox
      Left = 455
      Top = 10
      Width = 110
      Height = 21
      Style = csDropDownList
      TabOrder = 1
      OnChange = cboCategoryChange
    end
    object cboSeverity: TComboBox
      Left = 630
      Top = 10
      Width = 100
      Height = 21
      Style = csDropDownList
      TabOrder = 2
      OnChange = cboSeverityChange
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
        Value = 50.000000000000000000
      end
      item
        Value = 50.000000000000000000
      end>
    ControlCollection = <
      item
        Column = 0
        Control = btnExport
        Row = 0
      end
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
    object btnExport: TButton
      AlignWithMargins = True
      Left = 4
      Top = 8
      Width = 90
      Height = 25
      Caption = 'Export CSV...'
      TabOrder = 0
      OnClick = btnExportClick
    end
    object btnClose: TButton
      AlignWithMargins = True
      Left = 660
      Top = 8
      Width = 75
      Height = 25
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
        Width = 120
      end
      item
        Alignment = taCenter
        Caption = 'Line'
        Width = 50
      end
      item
        Caption = 'Category'
        Width = 110
      end
      item
        Caption = 'Severity'
        Width = 60
      end
      item
        Caption = 'Description'
        Width = 300
      end
      item
        Caption = 'File'
        Width = 100
      end>
    DoubleBuffered = True
    HideSelection = False
    MultiSelect = True
    ReadOnly = True
    RowSelect = True
    ParentDoubleBuffered = False
    PopupMenu = PopupMenu
    TabOrder = 2
    ViewStyle = vsReport
    OnColumnClick = ListViewColumnClick
    OnCompare = ListViewCompare
    OnDblClick = ListViewDblClick
  end
  object PopupMenu: TPopupMenu
    Left = 344
    Top = 200
    object mnuOpenFile: TMenuItem
      Caption = '&Open File'
      Default = True
      OnClick = mnuOpenFileClick
    end
    object N1: TMenuItem
      Caption = '-'
    end
    object mnuCopyToClipboard: TMenuItem
      Caption = '&Copy to Clipboard'
      OnClick = mnuCopyToClipboardClick
    end
  end
  object SaveDialog: TSaveDialog
    DefaultExt = 'csv'
    Filter = 'CSV Files (*.csv)|*.csv|All Files (*.*)|*.*'
    Title = 'Export to CSV'
    Left = 408
    Top = 200
  end
end
