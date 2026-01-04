inherited FormUsesClauseManager: TFormUsesClauseManager
  Caption = 'Uses Clause Manager'
  ClientHeight = 550
  ClientWidth = 800
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Splitter: TSplitter
    Left = 0
    Top = 369
    Width = 800
    Height = 5
    Cursor = crVSplit
    Align = alBottom
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblProgress: TLabel
      Left = 320
      Top = 14
      Width = 3
      Height = 13
      Visible = False
    end
    object lblSummary: TLabel
      Left = 320
      Top = 14
      Width = 3
      Height = 13
      Visible = False
    end
    object btnBuildDB: TButton
      Left = 8
      Top = 8
      Width = 100
      Height = 25
      Caption = '&Build Database'
      TabOrder = 0
      OnClick = btnBuildDBClick
    end
    object btnAnalyze: TButton
      Left = 114
      Top = 8
      Width = 100
      Height = 25
      Caption = '&Analyze Unit'
      TabOrder = 1
      OnClick = btnAnalyzeClick
    end
    object btnApply: TButton
      Left = 220
      Top = 8
      Width = 90
      Height = 25
      Caption = 'A&pply Changes'
      TabOrder = 2
      OnClick = btnApplyClick
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 509
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
    Height = 328
    Align = alClient
    Columns = <
      item
        Caption = 'Unit'
        Width = 180
      end
      item
        Caption = 'Current'
        Width = 100
      end
      item
        Caption = 'Recommended'
        Width = 100
      end
      item
        Caption = 'Reason'
        Width = 350
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
    OnSelectItem = ListViewSelectItem
  end
  object pnlDetails: TPanel
    Left = 0
    Top = 374
    Width = 800
    Height = 135
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 3
    object lblDetails: TLabel
      Left = 0
      Top = 0
      Width = 800
      Height = 20
      Align = alTop
      Caption = '  Unit Details:'
      Layout = tlCenter
    end
    object memoDetails: TMemo
      Left = 0
      Top = 20
      Width = 800
      Height = 115
      Align = alClient
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 0
    end
  end
  object PopupMenu: TPopupMenu
    Left = 400
    Top = 200
    object mnuMoveUnit: TMenuItem
      Caption = '&Move to Recommended Section'
      OnClick = mnuMoveUnitClick
    end
    object N2: TMenuItem
      Caption = '-'
    end
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
    Title = 'Export Uses Clause Analysis'
    Left = 472
    Top = 200
  end
end
