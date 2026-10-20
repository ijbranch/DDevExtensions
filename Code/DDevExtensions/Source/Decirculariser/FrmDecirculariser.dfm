inherited FormDecirculariser: TFormDecirculariser
  Caption = 'Decirculariser - circular unit references'
  ClientHeight = 560
  ClientWidth = 820
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  ExplicitWidth = 836
  ExplicitHeight = 599
  PixelsPerInch = 96
  TextHeight = 13
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 820
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblSummary: TLabel
      Left = 104
      Top = 14
      Width = 3
      Height = 13
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
  object lvGroups: TListView
    Left = 0
    Top = 41
    Width = 820
    Height = 150
    Align = alTop
    Columns = <
      item
        Caption = 'Risk'
        Width = 100
      end
      item
        Caption = 'Units'
        Width = 50
      end
      item
        Caption = 'Interface edges'
        Width = 95
      end
      item
        Caption = 'Implementation edges'
        Width = 125
      end
      item
        Caption = 'Members'
        Width = 430
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnSelectItem = lvGroupsSelectItem
  end
  object Splitter: TSplitter
    Left = 0
    Top = 191
    Width = 820
    Height = 4
    Cursor = crVSplit
    Align = alTop
  end
  object lvCandidates: TListView
    Left = 0
    Top = 195
    Width = 820
    Height = 239
    Align = alClient
    Columns = <
      item
        Caption = 'From'
        Width = 170
      end
      item
        Caption = 'To'
        Width = 170
      end
      item
        Caption = 'Line'
        Width = 50
      end
      item
        Caption = 'Verdict'
        Width = 110
      end
      item
        Caption = 'Crossing'
        Width = 65
      end
      item
        Caption = 'Fix'
        Width = 150
      end>
    HideSelection = False
    MultiSelect = True
    ReadOnly = True
    RowSelect = True
    PopupMenu = PopupMenu
    TabOrder = 2
    ViewStyle = vsReport
    OnDblClick = lvCandidatesDblClick
    OnSelectItem = lvCandidatesSelectItem
  end
  object memoDetails: TMemo
    Left = 0
    Top = 434
    Width = 820
    Height = 85
    Align = alBottom
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 3
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 519
    Width = 820
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 4
    object btnRemove: TButton
      Left = 8
      Top = 8
      Width = 150
      Height = 25
      Caption = '&Remove dead entries...'
      TabOrder = 0
      OnClick = btnRemoveClick
    end
    object btnCopyReport: TButton
      Left = 166
      Top = 8
      Width = 110
      Height = 25
      Caption = 'Copy &report'
      TabOrder = 1
      OnClick = btnCopyReportClick
    end
    object btnClose: TButton
      Left = 732
      Top = 8
      Width = 80
      Height = 25
      Anchors = [akTop, akRight]
      Caption = '&Close'
      TabOrder = 2
      OnClick = btnCloseClick
    end
  end
  object PopupMenu: TPopupMenu
    Left = 400
    Top = 280
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
end
