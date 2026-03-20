inherited FrameOptionPageCodeStyle: TFrameOptionPageCodeStyle
  Width = 400
  Height = 680
  ExplicitWidth = 400
  ExplicitHeight = 680
  inherited pnlClient: TPanel
    Width = 400
    Height = 631
    ExplicitWidth = 400
    ExplicitHeight = 631
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
    object grpTypePrefixes: TGroupBox
      Left = 16
      Top = 248
      Width = 360
      Height = 100
      Caption = 'Variable Type Prefix Rules'
      TabOrder = 2
      object chkCheckVariablePrefixes: TCheckBox
        Left = 16
        Top = 20
        Width = 250
        Height = 17
        Caption = 'Check variable prefixes by type'
        TabOrder = 0
      end
      object lblRulesSummary: TLabel
        Left = 16
        Top = 44
        Width = 250
        Height = 13
        Caption = '9 rules configured (String=s, Integer=i, ...)'
      end
      object btnEditRules: TButton
        Left = 16
        Top = 66
        Width = 100
        Height = 25
        Caption = 'Edit Rules...'
        TabOrder = 1
        OnClick = btnEditRulesClick
      end
    end
    object grpUsesClause: TGroupBox
      Left = 16
      Top = 356
      Width = 360
      Height = 52
      Caption = 'Uses Clause Rules'
      TabOrder = 3
      object chkCheckUnitScopeNames: TCheckBox
        Left = 16
        Top = 20
        Width = 320
        Height = 17
        Caption = 'Check unit scope names (e.g., System.SysUtils)'
        TabOrder = 0
      end
    end
    object grpAntiPatterns: TGroupBox
      Left = 16
      Top = 416
      Width = 360
      Height = 200
      Caption = 'Anti-Pattern Detection'
      TabOrder = 4
      object chkCheckAntiPatterns: TCheckBox
        Left = 16
        Top = 20
        Width = 250
        Height = 17
        Caption = 'Enable anti-pattern detection'
        TabOrder = 0
      end
      object chkCheckEmptyFinally: TCheckBox
        Left = 32
        Top = 44
        Width = 200
        Height = 17
        Caption = 'Detect empty finally blocks'
        TabOrder = 1
      end
      object chkCheckNestedWith: TCheckBox
        Left = 32
        Top = 68
        Width = 200
        Height = 17
        Caption = 'Detect nested "with" statements'
        TabOrder = 2
      end
      object chkCheckDeepNesting: TCheckBox
        Left = 32
        Top = 92
        Width = 200
        Height = 17
        Caption = 'Detect deep nesting'
        TabOrder = 3
      end
      object chkCheckLongMethods: TCheckBox
        Left = 32
        Top = 116
        Width = 200
        Height = 17
        Caption = 'Detect long methods'
        TabOrder = 4
      end
      object chkCheckLongParamLists: TCheckBox
        Left = 32
        Top = 140
        Width = 200
        Height = 17
        Caption = 'Detect long parameter lists'
        TabOrder = 5
      end
      object lblMaxNesting: TLabel
        Left = 240
        Top = 92
        Width = 24
        Height = 13
        Caption = 'Max:'
      end
      object edtMaxNesting: TEdit
        Left = 270
        Top = 89
        Width = 40
        Height = 21
        TabOrder = 6
        Text = '4'
      end
      object lblMaxLines: TLabel
        Left = 240
        Top = 116
        Width = 24
        Height = 13
        Caption = 'Max:'
      end
      object edtMaxLines: TEdit
        Left = 270
        Top = 113
        Width = 40
        Height = 21
        TabOrder = 7
        Text = '100'
      end
      object lblMaxParams: TLabel
        Left = 240
        Top = 140
        Width = 24
        Height = 13
        Caption = 'Max:'
      end
      object edtMaxParams: TEdit
        Left = 270
        Top = 137
        Width = 40
        Height = 21
        TabOrder = 8
        Text = '6'
      end
      object lblAntiPatternInfo: TLabel
        Left = 16
        Top = 168
        Width = 320
        Height = 26
        AutoSize = False
        Caption = 
          'Anti-patterns help identify code that compiles but may indicate ' +
          'design issues.'
        WordWrap = True
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
        'Checks your code for Delphi naming conventions (T, I, F, E, P pr' +
        'efixes), custom variable prefixes, unit scope names, and anti-pa' +
        'tterns.'
    end
  end
end
