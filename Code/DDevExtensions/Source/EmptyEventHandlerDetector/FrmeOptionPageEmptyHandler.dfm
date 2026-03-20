inherited FrameOptionPageEmptyHandler: TFrameOptionPageEmptyHandler
  Width = 350
  Height = 200
  inherited pnlClient: TPanel
    Width = 350
    Height = 151
    object chkEnabled: TCheckBox
      Left = 8
      Top = 8
      Width = 300
      Height = 17
      Caption = 'Enable Empty Event Handler Detector'
      TabOrder = 0
    end
    object lblInfo: TLabel
      Left = 8
      Top = 40
      Width = 330
      Height = 65
      AutoSize = False
      Caption = 
        'Scans your project for event handlers that have empty bodies (ju' +
        'st begin/end with no code). These are typically left over from d' +
        'esign-time component configuration.'
      WordWrap = True
    end
  end
  inherited pnlDescription: TPanel
    Top = 151
    Width = 350
    inherited bvlSplitter: TBevel
      Width = 350
    end
    inherited lblDescription: TLabel
      Width = 200
      Caption = 'Configure the Empty Event Handler Detector.'
    end
  end
end
