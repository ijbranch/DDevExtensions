inherited FormTodoAggregator: TFormTodoAggregator
  Caption = 'TODO/FIXME Aggregator'
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
    object lblProgress: TLabel
      Left = 104
      Top = 14
      Width = 3
      Height = 13
      Visible = False
    end
    object lblSummary: TLabel
      Left = 104
      Top = 14
      Width = 3
      Height = 13
      Visible = False
    end
    object lblCategory: TLabel
      Left = 330
      Top = 14
      Width = 46
      Height = 13
      Caption = 'Category:'
    end
    object lblPriority: TLabel
      Left = 502
      Top = 14
      Width = 38
      Height = 13
      Caption = 'Priority:'
    end
    object btnScan: TButton
      Left = 8
      Top = 8
      Width = 90
      Height = 25
      Caption = '&Scan Project'
      TabOrder = 0
      OnClick = btnScanClick
    end
    object cboCategory: TComboBox
      Left = 382
      Top = 10
      Width = 110
      Height = 21
      Style = csDropDownList
      TabOrder = 1
      OnChange = cboCategoryChange
    end
    object cboPriority: TComboBox
      Left = 546
      Top = 10
      Width = 90
      Height = 21
      Style = csDropDownList
      TabOrder = 2
      OnChange = cboPriorityChange
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
      Caption = '&Export CSV...'
      TabOrder = 0
      OnClick = btnExportClick
    end
    object btnClose: TButton
      AlignWithMargins = True
      Left = 662
      Top = 8
      Width = 80
      Height = 25
      Caption = '&Close'
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
        Width = 140
      end
      item
        Caption = 'Category'
        Width = 70
      end
      item
        Caption = 'Priority'
        Width = 60
      end
      item
        Caption = 'Line'
        Width = 50
      end
      item
        Caption = 'Text'
        Width = 400
      end>
    MultiSelect = True
    ReadOnly = True
    RowSelect = True
    PopupMenu = PopupMenu
    TabOrder = 2
    ViewStyle = vsReport
    OnColumnClick = ListViewColumnClick
    OnCompare = ListViewCompare
    OnDblClick = ListViewDblClick
  end
  object PopupMenu: TPopupMenu
    Left = 320
    Top = 200
    object mnuOpenFile: TMenuItem
      Caption = '&Open File'
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
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Title = 'Export TODO Items'
    Left = 392
    Top = 200
  end
end
