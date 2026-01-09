inherited FormBuildStatistics: TFormBuildStatistics
  Caption = 'Build Statistics'
  ClientHeight = 480
  ClientWidth = 850
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object pnlBottom: TPanel
    Left = 0
    Top = 414
    Width = 850
    Height = 66
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object lblTotalTime: TLabel
      Left = 8
      Top = 8
      Width = 56
      Height = 13
      Caption = 'Total time: '
    end
    object lblFilter: TLabel
      Left = 200
      Top = 8
      Width = 28
      Height = 13
      Caption = 'Filter:'
    end
    object lblUnitCount: TLabel
      Left = 350
      Top = 8
      Width = 450
      Height = 13
      AutoSize = False
      Caption = 'Units compiled: '
    end
    object cmbFilter: TComboBox
      Left = 235
      Top = 4
      Width = 100
      Height = 21
      Style = csDropDownList
      TabOrder = 3
      OnChange = cmbFilterChange
      Items.Strings = (
        'All'
        'Project'
        'External')
    end
    object btnCopyToClipboard: TButton
      Left = 560
      Top = 33
      Width = 105
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Copy to Clipboard'
      TabOrder = 1
      OnClick = btnCopyToClipboardClick
    end
    object btnExportCSV: TButton
      Left = 671
      Top = 33
      Width = 90
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Export CSV...'
      TabOrder = 2
      OnClick = btnExportCSVClick
    end
    object btnClose: TButton
      Left = 767
      Top = 33
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Close'
      Default = True
      ModalResult = 1
      TabOrder = 0
      OnClick = btnCloseClick
    end
  end
  object PageControl: TPageControl
    Left = 0
    Top = 0
    Width = 850
    Height = 414
    ActivePage = tabBuildStats
    Align = alClient
    TabOrder = 1
    OnChange = PageControlChange
    object tabBuildStats: TTabSheet
      Caption = 'Build Statistics'
      object ListView: TListView
        Left = 0
        Top = 0
        Width = 842
        Height = 386
        Align = alClient
        Columns = <
          item
            Caption = 'Unit Name'
            Width = 150
          end
          item
            Caption = 'Duration'
            Width = 80
          end
          item
            Caption = 'LOC'
            Width = 60
          end
          item
            Caption = 'Complexity'
            Width = 70
          end
          item
            Caption = 'File Path'
            Width = 450
          end>
        ColumnClick = True
        GridLines = True
        ReadOnly = True
        RowSelect = True
        PopupMenu = PopupMenu
        TabOrder = 0
        ViewStyle = vsReport
        OnColumnClick = ListViewColumnClick
        OnCompare = ListViewCompare
        OnDblClick = ListViewDblClick
      end
    end
    object tabStyleIssues: TTabSheet
      Caption = 'Style Issues'
      ImageIndex = 1
      object lvStyleIssues: TListView
        Left = 0
        Top = 0
        Width = 842
        Height = 386
        Align = alClient
        Columns = <
          item
            Caption = 'Unit'
            Width = 120
          end
          item
            Caption = 'Category'
            Width = 100
          end
          item
            Caption = 'Rule'
            Width = 100
          end
          item
            Caption = 'Line'
            Width = 50
          end
          item
            Caption = 'Expected'
            Width = 170
          end
          item
            Caption = 'Actual'
            Width = 150
          end
          item
            Caption = 'Severity'
            Width = 70
          end>
        ColumnClick = True
        GridLines = True
        ReadOnly = True
        RowSelect = True
        PopupMenu = PopupMenuStyle
        TabOrder = 0
        ViewStyle = vsReport
        OnColumnClick = lvStyleIssuesColumnClick
        OnCompare = lvStyleIssuesCompare
        OnDblClick = lvStyleIssuesDblClick
      end
    end
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
    object mnuSortByLOC: TMenuItem
      Caption = 'Sort by LOC (Most First)'
      OnClick = mnuSortByLOCClick
    end
    object mnuSortByComplexity: TMenuItem
      Caption = 'Sort by Complexity (Highest First)'
      OnClick = mnuSortByComplexityClick
    end
  end
  object PopupMenuStyle: TPopupMenu
    Left = 408
    Top = 160
    object mnuStyleCopyToClipboard: TMenuItem
      Caption = 'Copy to Clipboard'
      OnClick = mnuStyleCopyToClipboardClick
    end
    object mnuStyleExportCSV: TMenuItem
      Caption = 'Export CSV...'
      OnClick = mnuStyleExportCSVClick
    end
    object N2: TMenuItem
      Caption = '-'
    end
    object mnuStyleOpenFile: TMenuItem
      Caption = 'Open File'
      OnClick = mnuStyleOpenFileClick
    end
  end
end
