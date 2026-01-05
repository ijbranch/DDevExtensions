inherited FormDeadCodeDetector: TFormDeadCodeDetector
  Caption = 'Dead Code Detector'
  ClientHeight = 450
  ClientWidth = 800
  Position = poScreenCenter
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
    object lblType: TLabel
      Left = 380
      Top = 14
      Width = 28
      Height = 13
      Caption = 'Type:'
    end
    object lblScope: TLabel
      Left = 550
      Top = 14
      Width = 34
      Height = 13
      Caption = 'Scope:'
    end
    object btnScan: TButton
      Left = 8
      Top = 8
      Width = 90
      Height = 25
      Caption = '&Analyze Project'
      TabOrder = 0
      OnClick = btnScanClick
    end
    object cboType: TComboBox
      Left = 414
      Top = 10
      Width = 120
      Height = 21
      Style = csDropDownList
      TabOrder = 1
      OnChange = cboTypeChange
    end
    object cboScope: TComboBox
      Left = 590
      Top = 10
      Width = 100
      Height = 21
      Style = csDropDownList
      TabOrder = 2
      OnChange = cboScopeChange
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
      Left = 712
      Top = 8
      Width = 80
      Height = 25
      Caption = '&Close'
      TabOrder = 0
      OnClick = btnCloseClick
    end
    object btnExport: TButton
      Left = 8
      Top = 8
      Width = 90
      Height = 25
      Caption = '&Export CSV...'
      TabOrder = 1
      OnClick = btnExportClick
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
        Width = 130
      end
      item
        Caption = 'Type'
        Width = 70
      end
      item
        Caption = 'Name'
        Width = 200
      end
      item
        Caption = 'Scope'
        Width = 80
      end
      item
        Caption = 'Line'
        Width = 50
      end
      item
        Caption = 'Reason'
        Width = 120
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
    object mnuAddToIgnoreList: TMenuItem
      Caption = '&Add to Ignore List'
      OnClick = mnuAddToIgnoreListClick
    end
  end
  object SaveDialog: TSaveDialog
    DefaultExt = 'csv'
    Filter = 'CSV Files (*.csv)|*.csv|All Files (*.*)|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Title = 'Export Dead Code'
    Left = 392
    Top = 200
  end
end
