inherited FormUnusedUnitDetector: TFormUnusedUnitDetector
  Caption = 'Unused Unit Detector'
  ClientHeight = 450
  ClientWidth = 700
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  ExplicitWidth = 716
  ExplicitHeight = 489
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
    object btnScan: TButton
      Left = 8
      Top = 8
      Width = 90
      Height = 25
      Caption = '&Scan Project'
      TabOrder = 0
      OnClick = btnScanClick
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
      Left = 612
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
    Width = 700
    Height = 368
    Align = alClient
    Columns = <
      item
        Caption = 'Source Unit'
        Width = 180
      end
      item
        Caption = 'Unused Unit'
        Width = 180
      end
      item
        Caption = 'Section'
        Width = 100
      end
      item
        Caption = 'Line'
        Width = 60
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
    Title = 'Export Unused Units'
    Left = 392
    Top = 200
  end
end
