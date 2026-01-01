inherited FrameOptionPageUnusedUnitDetector: TFrameOptionPageUnusedUnitDetector
  Width = 400
  Height = 320
  ExplicitWidth = 400
  ExplicitHeight = 320
  object lblIgnoreList: TLabel
    Left = 16
    Top = 72
    Width = 90
    Height = 13
    Caption = 'Ignore List (one per line):'
  end
  object lblDescription: TLabel
    Left = 16
    Top = 40
    Width = 350
    Height = 26
    AutoSize = False
    Caption =
      'Detects unit references in uses clauses that may not be actuall' +
      'y used in the code.'
    WordWrap = True
  end
  object chkEnabled: TCheckBox
    Left = 16
    Top = 16
    Width = 200
    Height = 17
    Caption = 'Enable Unused Unit Detector'
    TabOrder = 0
  end
  object memoIgnoreList: TMemo
    Left = 16
    Top = 91
    Width = 360
    Height = 200
    ScrollBars = ssVertical
    TabOrder = 1
  end
end
