inherited FormBuildStatistics: TFormBuildStatistics
  Caption = 'Build Statistics'
  ClientHeight = 400
  ClientWidth = 600
  Position = poMainFormCenter
  OnCreate = nil
  PixelsPerInch = 96
  TextHeight = 13
  object pnlBottom: TPanel
    Left = 0
    Top = 359
    Width = 600
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object lblTotalTime: TLabel
      Left = 8
      Top = 12
      Width = 56
      Height = 13
      Caption = 'Total time: '
    end
    object lblUnitCount: TLabel
      Left = 200
      Top = 12
      Width = 76
      Height = 13
      Caption = 'Units compiled: '
    end
    object btnClose: TButton
      Left = 517
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
    object btnCopyToClipboard: TButton
      Left = 332
      Top = 8
      Width = 89
      Height = 25
      Caption = 'Copy to Clipboard'
      TabOrder = 1
      OnClick = btnCopyToClipboardClick
    end
    object btnExportCSV: TButton
      Left = 427
      Top = 8
      Width = 84
      Height = 25
      Caption = 'Export CSV...'
      TabOrder = 2
      OnClick = btnExportCSVClick
    end
  end
  object ListView: TListView
    Left = 0
    Top = 0
    Width = 600
    Height = 359
    Align = alClient
    Columns = <
      item
        Caption = 'Unit Name'
        Width = 200
      end
      item
        Caption = 'Duration'
        Width = 100
      end
      item
        Caption = 'File Path'
        Width = 280
      end>
    ColumnClick = True
    GridLines = True
    ReadOnly = True
    RowSelect = True
    PopupMenu = PopupMenu
    TabOrder = 1
    ViewStyle = vsReport
    OnColumnClick = ListViewColumnClick
    OnCompare = ListViewCompare
  end
  object SaveDialog: TSaveDialog
    DefaultExt = 'csv'
    Filter = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Title = 'Export Build Statistics'
    Left = 280
    Top = 160
  end
  object PopupMenu: TPopupMenu
    Left = 344
    Top = 160
    object mnuCopyToClipboard: TMenuItem
      Caption = 'Copy to Clipboard'
      OnClick = btnCopyToClipboardClick
    end
    object mnuExportCSV: TMenuItem
      Caption = 'Export CSV...'
      OnClick = btnExportCSVClick
    end
    object N1: TMenuItem
      Caption = '-'
    end
    object mnuSortByName: TMenuItem
      Caption = 'Sort by Name'
      OnClick = mnuSortByNameClick
    end
    object mnuSortByTime: TMenuItem
      Caption = 'Sort by Time (Slowest First)'
      OnClick = mnuSortByTimeClick
    end
  end
end
