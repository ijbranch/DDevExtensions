inherited FormEmptyEventHandlerDetector: TFormEmptyEventHandlerDetector
  Caption = 'Empty Event Handler Detector'
  ClientHeight = 450
  ClientWidth = 700
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 700
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblProgress: TLabel
      Left = 200
      Top = 12
      Width = 60
      Height = 13
      Caption = 'lblProgress'
      Visible = False
    end
    object lblSummary: TLabel
      Left = 200
      Top = 12
      Width = 56
      Height = 13
      Caption = 'lblSummary'
      Visible = False
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
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 409
    Width = 700
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object btnClose: TButton
      Left = 617
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
    Width = 700
    Height = 368
    Align = alClient
    Columns = <
      item
        Caption = 'Unit'
        Width = 150
      end
      item
        Caption = 'Method'
        Width = 250
      end
      item
        Caption = 'Line'
        Width = 60
      end
      item
        Caption = 'File'
        Width = 220
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
    Left = 344
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
    Title = 'Export Empty Event Handlers'
    Left = 408
    Top = 160
  end
end
