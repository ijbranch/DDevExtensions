inherited FrameOptionPageExternalModMonitor: TFrameOptionPageExternalModMonitor
  Width = 507
  Height = 241
  TabStop = True
  inherited pnlClient: TPanel
    Width = 507
    Height = 192
    object cbxActive: TCheckBox
      Left = 8
      Top = 8
      Width = 129
      Height = 17
      Caption = '&Active'
      TabOrder = 0
      OnClick = cbxActiveClick
    end
    object lblDebounceMs: TLabel
      Left = 24
      Top = 35
      Width = 112
      Height = 13
      Caption = 'Debounce interval (ms):'
    end
    object edtDebounceMs: TEdit
      Left = 152
      Top = 32
      Width = 57
      Height = 21
      TabOrder = 1
      Text = '200'
    end
    object lblProjectLoadGraceMs: TLabel
      Left = 24
      Top = 61
      Width = 130
      Height = 13
      Caption = 'Load grace period (ms):'
    end
    object edtProjectLoadGraceMs: TEdit
      Left = 152
      Top = 58
      Width = 57
      Height = 21
      TabOrder = 2
      Text = '3000'
    end
    object lblExtensions: TLabel
      Left = 24
      Top = 87
      Width = 109
      Height = 13
      Caption = 'Monitored extensions:'
    end
    object edtExtensions: TEdit
      Left = 152
      Top = 84
      Width = 337
      Height = 21
      TabOrder = 3
      Text = '.pas;.inc;.dfm;.dproj;.dpk'
    end
    object cbxShowNotifications: TCheckBox
      Left = 24
      Top = 114
      Width = 200
      Height = 17
      Caption = 'Show &notification on refresh'
      TabOrder = 4
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
        'Monitors project directories for external file changes and silently refreshes modified files in the IDE.'
    end
  end
end
