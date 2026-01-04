inherited FrameOptionPageUnreachableCode: TFrameOptionPageUnreachableCode
  Width = 400
  Height = 300
  ExplicitWidth = 400
  ExplicitHeight = 300
  inherited pnlClient: TPanel
    Width = 400
    Height = 251
    ExplicitWidth = 400
    ExplicitHeight = 251
    object chkEnabled: TCheckBox
      Left = 16
      Top = 12
      Width = 250
      Height = 17
      Caption = 'Enable Unreachable Code Detector'
      TabOrder = 0
    end
    object grpDetection: TGroupBox
      Left = 16
      Top = 40
      Width = 361
      Height = 145
      Caption = 'Detection Rules'
      TabOrder = 1
      object lblDetects: TLabel
        Left = 16
        Top = 24
        Width = 329
        Height = 105
        AutoSize = False
        Caption =
          'The detector finds code immediately after:'#13#10#13#10'  - Exit or Exit(v' +
          'alue)'#13#10'  - Raise Exception'#13#10'  - Break'#13#10'  - Continue'#13#10'  - Halt o' +
          'r Halt(code)'#13#10'  - Abort'
      end
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
        'Detects code that can never be executed because it appears afte' +
        'r control flow statements like Exit, Raise, Break, Continue, Ha' +
        'lt, or Abort.'
    end
  end
end
