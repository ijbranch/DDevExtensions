inherited FrameOptionPageDeadCode: TFrameOptionPageDeadCode
  Width = 400
  Height = 320
  ExplicitWidth = 400
  ExplicitHeight = 320
  inherited pnlClient: TPanel
    Width = 400
    Height = 271
    ExplicitWidth = 400
    ExplicitHeight = 271
    object lblIgnoreList: TLabel
      Left = 16
      Top = 80
      Width = 112
      Height = 13
      Caption = 'Ignore List (one per line):'
    end
    object lblIgnoreHint: TLabel
      Left = 16
      Top = 248
      Width = 200
      Height = 13
      Caption = 'Use * for wildcards (e.g., *Click, Get*)'
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
      Caption = 'Enable Dead Code Detector'
      TabOrder = 0
    end
    object chkCheckProcedures: TCheckBox
      Left = 16
      Top = 36
      Width = 200
      Height = 17
      Caption = 'Check for unused procedures/functions'
      TabOrder = 1
    end
    object chkCheckFields: TCheckBox
      Left = 16
      Top = 56
      Width = 200
      Height = 17
      Caption = 'Check for unused private fields'
      TabOrder = 2
    end
    object memoIgnoreList: TMemo
      Left = 16
      Top = 99
      Width = 360
      Height = 140
      ScrollBars = ssVertical
      TabOrder = 3
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
        'Detects procedures, functions, and fields that are never referen' +
        'ced in your project.'
    end
  end
end
