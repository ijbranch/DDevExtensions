inherited FrameOptionPageParallelBuild: TFrameOptionPageParallelBuild
  Width = 507
  Height = 261
  TabStop = True
  inherited pnlClient: TPanel
    Width = 507
    Height = 212
    object cbxActive: TCheckBox
      Left = 8
      Top = 8
      Width = 480
      Height = 17
      Caption = '&Active ( Build All Projects builds the project group in parallel )'
      TabOrder = 0
      OnClick = cbxActiveClick
    end
    object lblMaxWorkers: TLabel
      Left = 24
      Top = 37
      Width = 150
      Height = 13
      Caption = '&Projects built at the same time:'
      FocusControl = edtMaxWorkers
    end
    object edtMaxWorkers: TEdit
      Left = 200
      Top = 34
      Width = 49
      Height = 21
      MaxLength = 2
      NumbersOnly = True
      TabOrder = 1
    end
    object lblMaxWorkersNote: TLabel
      Left = 260
      Top = 37
      Width = 230
      Height = 13
      Caption = '0 = automatic ( one per logical CPU, up to 8 )'
    end
    object cbxRunEurekaLog: TCheckBox
      Left = 24
      Top = 66
      Width = 464
      Height = 17
      Caption = 'Run &EurekaLog ( ecc32 ) on a Release build of a project that has a .eof'
      TabOrder = 2
      OnClick = cbxActiveClick
    end
    object lblEcc32Path: TLabel
      Left = 40
      Top = 93
      Width = 54
      Height = 13
      Caption = 'ecc&32.exe:'
      FocusControl = edtEcc32Path
    end
    object edtEcc32Path: TEdit
      Left = 104
      Top = 90
      Width = 384
      Height = 21
      TabOrder = 3
      TextHint = 'empty = EurekaLog'#39's own folder for this IDE'
    end
    object lblEcc32Note: TLabel
      Left = 104
      Top = 116
      Width = 384
      Height = 39
      AutoSize = False
      WordWrap = True
    end
  end
  inherited pnlDescription: TPanel
    Width = 507
    inherited bvlSplitter: TBevel
      Width = 507
    end
    inherited lblDescription: TLabel
      Width = 480
      Caption =
        'Build All Projects builds a project group several projects at a time.'
    end
  end
end
