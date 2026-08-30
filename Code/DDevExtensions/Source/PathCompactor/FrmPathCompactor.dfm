inherited FormPathCompactor: TFormPathCompactor
  Caption = 'IDE Path Compactor'
  ClientHeight = 720
  ClientWidth = 1000
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object pnlScope: TPanel
    Left = 0
    Top = 0
    Width = 1000
    Height = 164
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblPlatforms: TLabel
      Left = 8
      Top = 6
      Width = 52
      Height = 13
      Caption = 'Platforms:'
    end
    object lblPathTypes: TLabel
      Left = 200
      Top = 6
      Width = 57
      Height = 13
      Caption = 'Path types:'
    end
    object clbPlatforms: TCheckListBox
      Left = 8
      Top = 22
      Width = 180
      Height = 108
      ItemHeight = 13
      TabOrder = 0
    end
    object clbPathTypes: TCheckListBox
      Left = 200
      Top = 22
      Width = 250
      Height = 108
      ItemHeight = 13
      TabOrder = 1
    end
    object gbHygiene: TGroupBox
      Left = 464
      Top = 8
      Width = 340
      Height = 146
      Caption = ' Hygiene and scope '
      TabOrder = 2
      object chkRemoveDuplicates: TCheckBox
        Left = 12
        Top = 24
        Width = 296
        Height = 17
        Caption = 'Remove duplicate entries'
        TabOrder = 0
      end
      object chkRemoveMissing: TCheckBox
        Left = 12
        Top = 48
        Width = 316
        Height = 17
        Caption = 'Remove entries whose directory is missing'
        TabOrder = 1
      end
      object chkRemoveUndefined: TCheckBox
        Left = 12
        Top = 72
        Width = 316
        Height = 17
        Caption = 'Remove entries whose macro is undefined (dead)'
        TabOrder = 3
      end
      object chkWriteUserEnv: TCheckBox
        Left = 12
        Top = 94
        Width = 316
        Height = 33
        Caption =
          'Also define as Windows user environment variables (for hand-edite' +
          'd .dproj files)'
        TabOrder = 2
        WordWrap = True
      end
    end
    object btnAnalyse: TButton
      Left = 820
      Top = 22
      Width = 110
      Height = 28
      Caption = '&Analyse'
      TabOrder = 3
      OnClick = btnAnalyseClick
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 664
    Width = 1000
    Height = 56
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object lblStatus: TLabel
      Left = 8
      Top = 8
      Width = 245
      Height = 13
      Caption = 'Press Analyse. Nothing is written until you press Apply.'
    end
    object lblHint: TLabel
      Left = 8
      Top = 30
      Width = 456
      Height = 13
      Caption =
        'Rollback lives in the IDE Path Sorter'#39's backup history '#8212' this too' +
        'l shares the same history file.'
    end
    object btnApply: TButton
      Left = 780
      Top = 14
      Width = 90
      Height = 28
      Caption = 'A&pply'
      Enabled = False
      TabOrder = 0
      OnClick = btnApplyClick
    end
    object btnClose: TButton
      Left = 880
      Top = 14
      Width = 90
      Height = 28
      Cancel = True
      Caption = '&Close'
      TabOrder = 1
      OnClick = btnCloseClick
    end
  end
  object pgcResults: TPageControl
    Left = 0
    Top = 164
    Width = 1000
    Height = 500
    ActivePage = tabSummary
    Align = alClient
    TabOrder = 1
    object tabSummary: TTabSheet
      Caption = 'Summary'
      object sgSummary: TStringGrid
        Left = 0
        Top = 0
        Width = 992
        Height = 496
        Align = alClient
        ColCount = 7
        DefaultRowHeight = 18
        FixedCols = 0
        RowCount = 2
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goColSizing]
        TabOrder = 0
      end
    end
    object tabVariables: TTabSheet
      Caption = 'Proposed variables'
      ImageIndex = 1
      object lvVariables: TListView
        Left = 0
        Top = 0
        Width = 992
        Height = 496
        Align = alClient
        Checkboxes = True
        Columns = <
          item
            Caption = 'Variable'
            Width = 150
          end
          item
            Caption = 'Expands to'
            Width = 460
          end
          item
            Alignment = taRightJustify
            Caption = 'Uses'
            Width = 60
          end
          item
            Alignment = taRightJustify
            Caption = 'Chars saved'
            Width = 90
          end
          item
            Caption = 'Note'
            Width = 180
          end>
        GridLines = True
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
        OnItemChecked = lvVariablesItemChecked
      end
    end
    object tabJunctions: TTabSheet
      Caption = 'Junction opportunities'
      ImageIndex = 2
      object lvJunctions: TListView
        Left = 0
        Top = 0
        Width = 992
        Height = 496
        Align = alClient
        Checkboxes = True
        Columns = <
          item
            Caption = 'Source directory'
            Width = 520
          end
          item
            Caption = 'Link'
            Width = 140
          end
          item
            Alignment = taRightJustify
            Caption = 'Uses'
            Width = 60
          end
          item
            Alignment = taRightJustify
            Caption = 'Expanded chars saved'
            Width = 150
          end>
        GridLines = True
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
      end
    end
    object tabPreview: TTabSheet
      Caption = 'Preview'
      ImageIndex = 3
      object splPreview: TSplitter
        Left = 489
        Top = 32
        Width = 5
        Height = 464
      end
      object pnlPreviewTop: TPanel
        Left = 0
        Top = 0
        Width = 992
        Height = 32
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object lblPreviewSet: TLabel
          Left = 8
          Top = 9
          Width = 43
          Height = 13
          Caption = 'Path set:'
        end
        object cboPreviewSet: TComboBox
          Left = 60
          Top = 5
          Width = 400
          Height = 21
          Style = csDropDownList
          TabOrder = 0
          OnChange = cboPreviewSetChange
        end
      end
      object memBefore: TMemo
        Left = 0
        Top = 32
        Width = 489
        Height = 464
        Align = alLeft
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssBoth
        TabOrder = 1
        WordWrap = False
      end
      object memAfter: TMemo
        Left = 494
        Top = 32
        Width = 498
        Height = 464
        Align = alClient
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssBoth
        TabOrder = 2
        WordWrap = False
      end
    end
  end
end
