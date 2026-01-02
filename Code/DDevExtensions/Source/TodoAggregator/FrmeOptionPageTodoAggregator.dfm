inherited FrameOptionPageTodoAggregator: TFrameOptionPageTodoAggregator
  Width = 400
  Height = 320
  ExplicitWidth = 400
  ExplicitHeight = 320
  inherited pnlClient: TPanel
    Width = 400
    Height = 271
    ExplicitWidth = 400
    ExplicitHeight = 271
    object lblPatterns: TLabel
      Left = 16
      Top = 40
      Width = 120
      Height = 13
      Caption = 'Patterns (comma-separated):'
    end
    object lblPatternsHint: TLabel
      Left = 16
      Top = 84
      Width = 260
      Height = 13
      Caption = 'Example: TODO,FIXME,HACK,BUG,NOTE,XXX'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGray
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = []
      ParentFont = False
    end
    object chkEnabled: TCheckBox
      Left = 16
      Top = 12
      Width = 200
      Height = 17
      Caption = 'Enable TODO/FIXME Aggregator'
      TabOrder = 0
    end
    object edtPatterns: TEdit
      Left = 16
      Top = 57
      Width = 360
      Height = 21
      TabOrder = 1
    end
  end
  inherited pnlDescription: TPanel
    Width = 400
    ExplicitWidth = 400
    inherited bvlSplitter: TBevel
      Width = 400
    end
    inherited lblDescription: TLabel
      Width = 368
      Caption =
        'Scans project files for TODO, FIXME, and other comment markers ' +
        'and displays them in a list.'
    end
  end
end
