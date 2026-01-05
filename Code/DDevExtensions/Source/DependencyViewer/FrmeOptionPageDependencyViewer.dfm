inherited FrameOptionPageDependencyViewer: TFrameOptionPageDependencyViewer
  Width = 403
  Height = 150
  TabStop = True
  inherited pnlClient: TPanel
    Width = 403
    Height = 101
    object chkEnabled: TCheckBox
      Left = 8
      Top = 8
      Width = 361
      Height = 19
      Caption = '&Enable Dependency Viewer'
      TabOrder = 0
    end
    object chkRespectConditionals: TCheckBox
      Left = 8
      Top = 33
      Width = 361
      Height = 19
      Caption = '&Respect conditional compilation ({$IFDEF}, {$IF}, etc.)'
      TabOrder = 1
    end
  end
  inherited pnlDescription: TPanel
    Width = 403
    inherited bvlSplitter: TBevel
      Width = 403
    end
    inherited lblDescription: TLabel
      Width = 250
      Caption = 'Configure the Dependency Viewer feature.'
      ExplicitWidth = 250
    end
  end
end
