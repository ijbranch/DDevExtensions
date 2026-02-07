object JTStatusViewForm: TJTStatusViewForm
  Left = 0
  Top = 0
  Caption = 'Job Ticket Status Change History View..'
  ClientHeight = 504
  ClientWidth = 784
  Color = clBtnFace
  Constraints.MaxWidth = 800
  Constraints.MinWidth = 800
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnResize = FormResize
  OnShow = FormShow
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 445
    Width = 784
    Height = 40
    Align = alBottom
    TabOrder = 2
    object btnClose: TLMDButton
      Left = 336
      Top = 6
      Width = 110
      Height = 30
      ButtonLayout.Spacing = 4
      ButtonStyle = ubsDelphi
      Color = clSkyBlue
      ImageList = SVGVIL
      ParentColor = False
      Caption = '&Close'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 0
      OnClick = btnCloseClick
    end
  end
  object DBGrid1: TwwDBGrid
    Left = 0
    Top = 0
    Width = 784
    Height = 420
    Hint = 'Double click on Changes field to open..'
    ParentCustomHint = False
    ControlType.Strings = (
      'Action;CustomEdit;Action;F')
    Selected.Strings = (
      'DateTime'#9'21'#9'DateTime'#9#9
      'UserID'#9'8'#9'User ID'
      'Application'#9'20'#9'Application'#9'F'#9
      'Action'#9'10'#9'Action'#9#9
      'TableName'#9'15'#9'TableName'#9#9
      'Changes'#9'50'#9'Changes'#9#9)
    MemoAttributes = [mSizeable, mWordWrap, mGridShow, mViewOnly]
    IniAttributes.Delimiter = ';;'
    IniAttributes.UnicodeIniFile = False
    TitleColor = clBtnFace
    FixedCols = 0
    ShowHorzScrollBar = True
    Align = alClient
    DataSource = dsJTStatusView
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = []
    Options = [dgTitles, dgIndicator, dgColLines, dgRowLines, dgTabs, dgCancelOnExit, dgWordWrap, dgRowResize]
    ParentFont = False
    ParentShowHint = False
    ReadOnly = True
    ShowHint = True
    TabOrder = 0
    TitleAlignment = taCenter
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -13
    TitleFont.Name = 'Segoe UI'
    TitleFont.Style = [fsBold]
    TitleLines = 1
    TitleButtons = False
    TitleMenuAttributes.Options = [sfoFilter, sfoGrouping, sfoUseCurrentValueForFilter, sfoAllowNullFilters]
    TitleMenuAttributes.MenuEnabled = True
    object Action: TwwDBComboBox
      Left = 241
      Top = 191
      Width = 80
      Height = 22
      BiDiMode = bdLeftToRight
      ParentBiDiMode = False
      ShowButton = False
      Style = csSimple
      MapList = True
      AllowClearKey = False
      AutoFillDate = False
      AutoSelect = False
      AutoSize = False
      DataField = 'Action'
      DataSource = dsJTStatusView
      DropDownCount = 0
      DropDownWidth = 100
      Enabled = False
      ItemHeight = 0
      Items.Strings = (
        'Add'#9'0'
        'Edit'#9'1'
        'Delete'#9'2')
      ParentColor = True
      ParentShowHint = False
      ReadOnly = True
      ShowHint = False
      Sorted = False
      TabOrder = 0
      UnboundDataType = wwDefault
      UsePictureMask = False
      UnboundAlignment = taCenter
    end
  end
  object wwDBNavigator1: TwwDBNavigator
    Left = 0
    Top = 420
    Width = 784
    Height = 25
    AutosizeStyle = asSizeNavButtons
    DataSource = dsJTStatusView
    ShowHint = True
    RepeatInterval.InitialDelay = 500
    RepeatInterval.Interval = 100
    BackgroundOptions.IndentX = 0
    BackgroundOptions.IndentY = 0
    Align = alBottom
    ParentShowHint = False
    object wwDBNavigator1First: TwwNavButton
      Left = 0
      Top = 0
      Width = 112
      Height = 25
      Hint = 'Move to first record'
      ImageIndex = -1
      NumGlyphs = 2
      Spacing = 4
      Transparent = False
      Caption = 'wwDBNavigator1First'
      Enabled = False
      DisabledTextColors.ShadeColor = clGray
      DisabledTextColors.HighlightColor = clBtnHighlight
      Index = 0
      Style = nbsFirst
    end
    object wwDBNavigator1PriorPage: TwwNavButton
      Left = 112
      Top = 0
      Width = 112
      Height = 25
      Hint = 'Move backward 10 records'
      ImageIndex = -1
      NumGlyphs = 2
      Spacing = 4
      Transparent = False
      Caption = 'wwDBNavigator1PriorPage'
      Enabled = False
      DisabledTextColors.ShadeColor = clGray
      DisabledTextColors.HighlightColor = clBtnHighlight
      Index = 1
      Style = nbsPriorPage
    end
    object wwDBNavigator1Prior: TwwNavButton
      Left = 224
      Top = 0
      Width = 112
      Height = 25
      Hint = 'Move to prior record'
      ImageIndex = -1
      NumGlyphs = 2
      Spacing = 4
      Transparent = False
      Caption = 'wwDBNavigator1Prior'
      Enabled = False
      DisabledTextColors.ShadeColor = clGray
      DisabledTextColors.HighlightColor = clBtnHighlight
      Index = 2
      Style = nbsPrior
    end
    object wwDBNavigator1Next: TwwNavButton
      Left = 336
      Top = 0
      Width = 112
      Height = 25
      Hint = 'Move to next record'
      ImageIndex = -1
      NumGlyphs = 2
      Spacing = 4
      Transparent = False
      Caption = 'wwDBNavigator1Next'
      Enabled = False
      DisabledTextColors.ShadeColor = clGray
      DisabledTextColors.HighlightColor = clBtnHighlight
      Index = 3
      Style = nbsNext
    end
    object wwDBNavigator1NextPage: TwwNavButton
      Left = 448
      Top = 0
      Width = 112
      Height = 25
      Hint = 'Move forward 10 records'
      ImageIndex = -1
      NumGlyphs = 2
      Spacing = 4
      Transparent = False
      Caption = 'wwDBNavigator1NextPage'
      Enabled = False
      DisabledTextColors.ShadeColor = clGray
      DisabledTextColors.HighlightColor = clBtnHighlight
      Index = 4
      Style = nbsNextPage
    end
    object wwDBNavigator1Last: TwwNavButton
      Left = 560
      Top = 0
      Width = 112
      Height = 25
      Hint = 'Move to last record'
      ImageIndex = -1
      NumGlyphs = 2
      Spacing = 4
      Transparent = False
      Caption = 'wwDBNavigator1Last'
      Enabled = False
      DisabledTextColors.ShadeColor = clGray
      DisabledTextColors.HighlightColor = clBtnHighlight
      Index = 5
      Style = nbsLast
    end
    object wwDBNavigator1Refresh: TwwNavButton
      Left = 672
      Top = 0
      Width = 112
      Height = 25
      Hint = 'Refresh the contents of the dataset'
      ImageIndex = -1
      NumGlyphs = 2
      Spacing = 4
      Transparent = False
      Caption = 'wwDBNavigator1Refresh'
      Enabled = False
      DisabledTextColors.ShadeColor = clGray
      DisabledTextColors.HighlightColor = clBtnHighlight
      Index = 6
      Style = nbsRefresh
    end
  end
  object RzStatusBar1: TRzStatusBar
    Left = 0
    Top = 485
    Width = 784
    Height = 19
    ShowSizeGrip = False
    BorderInner = fsNone
    BorderOuter = fsNone
    BorderSides = [sdLeft, sdTop, sdRight, sdBottom]
    BorderWidth = 0
    Color = 14079702
    TabOrder = 3
    object RzClockStatus1: TRzClockStatus
      Left = 0
      Top = 0
      Width = 140
      Height = 19
      Align = alLeft
      Alignment = taCenter
    end
    object RzKeyStatus1: TRzKeyStatus
      Left = 140
      Top = 0
      Height = 19
      Align = alLeft
      Alignment = taCenter
    end
    object RzKeyStatus2: TRzKeyStatus
      Left = 185
      Top = 0
      Height = 19
      Align = alLeft
      Key = tkNumLock
      Alignment = taCenter
    end
    object RzDBStateStatus1: TRzDBStateStatus
      Left = 230
      Top = 0
      Height = 19
      Align = alLeft
      DataSource = dsJTStatusView
    end
  end
  object JTStatusView: TnlhTable
    AutoCalcFields = False
    Filter = 
      '(TableName = '#39'JobTickets'#39') and (Trim(both '#39' '#39' from KeyValue) = '#39 +
      '174'#39')'
    Filtered = True
    ReadOnly = True
    DatabaseName = 'DBiCurrent'
    SessionName = 'DBSWorkflow'
    IndexName = 'LOGDATETIME'
    TableName = 'ChangesLog'
    Left = 284
    Top = 40
    object JTStatusViewDateTime: TDateTimeField
      DisplayWidth = 21
      FieldName = 'DateTime'
    end
    object JTStatusViewUserID: TStringField
      Alignment = taCenter
      DisplayLabel = 'User ID'
      DisplayWidth = 8
      FieldName = 'UserID'
      Size = 6
    end
    object JTStatusViewApplication: TStringField
      DisplayWidth = 20
      FieldName = 'Application'
    end
    object JTStatusViewAction: TSmallintField
      Alignment = taCenter
      DisplayWidth = 10
      FieldName = 'Action'
    end
    object JTStatusViewTableName: TStringField
      Alignment = taCenter
      DisplayWidth = 15
      FieldName = 'TableName'
    end
    object JTStatusViewChanges: TMemoField
      DisplayWidth = 50
      FieldName = 'Changes'
      BlobType = ftMemo
    end
  end
  object dsJTStatusView: TDataSource
    AutoEdit = False
    DataSet = JTStatusView
    Left = 284
    Top = 92
  end
  object SVGVIL: TSVGIconVirtualImageList
    Images = <
      item
        CollectionIndex = 0
        CollectionName = 'Close Form'
        Name = 'Close Form'
      end>
    ImageCollection = dmI.SVGIC
    PreserveItems = True
    Width = 20
    Height = 20
    Size = 20
    Left = 25
    Top = 40
  end
end
