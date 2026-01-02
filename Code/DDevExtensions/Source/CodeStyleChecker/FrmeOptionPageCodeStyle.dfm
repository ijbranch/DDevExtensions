inherited FrameOptionPageCodeStyle: TFrameOptionPageCodeStyle
  Width = 400
  Height = 320
  ExplicitWidth = 400
  ExplicitHeight = 320
  inherited pnlClient: TPanel
    Width = 400
    Height = 271
    ExplicitWidth = 400
    ExplicitHeight = 271
    object chkEnabled: TCheckBox
      Left = 16
      Top = 12
      Width = 200
      Height = 17
      Caption = 'Enable Code Style Checker'
      TabOrder = 0
    end
    object grpRules: TGroupBox
      Left = 16
      Top = 40
      Width = 360
      Height = 200
      Caption = 'Naming Convention Rules'
      TabOrder = 1
      object chkCheckTypes: TCheckBox
        Left = 16
        Top = 24
        Width = 320
        Height = 17
        Caption = 'Check type names start with "T" (e.g., TMyClass)'
        TabOrder = 0
      end
      object chkCheckInterfaces: TCheckBox
        Left = 16
        Top = 52
        Width = 320
        Height = 17
        Caption = 'Check interface names start with "I" (e.g., IMyInterface)'
        TabOrder = 1
      end
      object chkCheckFields: TCheckBox
        Left = 16
        Top = 80
        Width = 320
        Height = 17
        Caption = 'Check field names start with "F" (e.g., FMyField)'
        TabOrder = 2
      end
      object chkCheckExceptions: TCheckBox
        Left = 16
        Top = 108
        Width = 320
        Height = 17
        Caption = 'Check exception names start with "E" (e.g., EMyError)'
        TabOrder = 3
      end
      object chkCheckPointers: TCheckBox
        Left = 16
        Top = 136
        Width = 320
        Height = 17
        Caption = 'Check pointer type names start with "P" (e.g., PMyRecord)'
        TabOrder = 4
      end
      object chkCheckParameters: TCheckBox
        Left = 16
        Top = 164
        Width = 320
        Height = 17
        Caption = 'Check parameter names start with "A" (e.g., AValue)'
        TabOrder = 5
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
        'Checks your code for Delphi naming convention compliance (T, I,' +
        ' F, E, P prefixes).'
    end
  end
end
