inherited FormDfmPasConsistency: TFormDfmPasConsistency
  Caption = 'DFM/PAS Consistency Checker'
  ClientHeight = 450
  ClientWidth = 800
  Position = poMainFormCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblProgress: TLabel
      Left = 380
      Top = 12
      Width = 60
      Height = 13
      Caption = 'lblProgress'
      Visible = False
    end
    object lblSummary: TLabel
      Left = 380
      Top = 12
      Width = 56
      Height = 13
      Caption = 'lblSummary'
      Visible = False
    end
    object lblFilter: TLabel
      Left = 190
      Top = 12
      Width = 28
      Height = 13
      Caption = 'Filter:'
    end
    object btnScan: TButton
      Left = 8
      Top = 8
      Width = 89
      Height = 25
      Caption = 'Scan Project'
      TabOrder = 0
      OnClick = btnScanClick
    end
    object btnExport: TButton
      Left = 103
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Export...'
      TabOrder = 1
      OnClick = btnExportClick
    end
    object cboFilter: TComboBox
      Left = 224
      Top = 9
      Width = 145
      Height = 21
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 2
      Text = 'All'
      OnChange = cboFilterChange
      Items.Strings = (
        'All'
        'Input Controls'
        'Passive Controls')
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 409
    Width = 800
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object btnClose: TButton
      Left = 717
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Close'
      TabOrder = 0
      OnClick = btnCloseClick
    end
  end
  object ListView: TListView
    Left = 0
    Top = 41
    Width = 800
    Height = 368
    Align = alClient
    Columns = <
      item
        Caption = 'Unit'
        Width = 100
      end
      item
        Caption = 'Component'
        Width = 120
      end
      item
        Caption = 'Issue'
        Width = 100
      end
      item
        Caption = 'PAS Type'
        Width = 110
      end
      item
        Alignment = taCenter
        Caption = 'PAS Line'
        Width = 70
      end
      item
        Caption = 'DFM Type'
        Width = 110
      end
      item
        Alignment = taCenter
        Caption = 'DFM Line'
        Width = 70
      end
      item
        Caption = 'File'
        Width = 130
      end>
    GridLines = True
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
    Left = 400
    Top = 160
    object mnuOpenFile: TMenuItem
      Caption = 'Open File'
      OnClick = mnuOpenFileClick
    end
    object N1: TMenuItem
      Caption = '-'
    end
    object mnuCopyToClipboard: TMenuItem
      Caption = 'Copy to Clipboard'
      OnClick = mnuCopyToClipboardClick
    end
  end
  object SaveDialog: TSaveDialog
    DefaultExt = 'csv'
    Filter = 'CSV Files (*.csv)|*.csv|All Files (*.*)|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Title = 'Export DFM/PAS Consistency Results'
    Left = 464
    Top = 160
  end
end
