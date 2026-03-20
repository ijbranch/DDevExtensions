inherited FrameOptionPageUnusedUnitDetector: TFrameOptionPageUnusedUnitDetector
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
      Top = 8
      Width = 112
      Height = 13
      Caption = 'Ignore List (one per line):'
    end
    object chkEnabled: TCheckBox
      Left = 256
      Top = 6
      Width = 200
      Height = 17
      Caption = 'Enable Unused Unit Detector'
      TabOrder = 0
    end
    object memoIgnoreList: TMemo
      Left = 16
      Top = 27
      Width = 360
      Height = 230
      ScrollBars = ssVertical
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
        'Detects unit references in uses clauses that may not be actually' +
        ' used in the code.'
    end
  end
end
