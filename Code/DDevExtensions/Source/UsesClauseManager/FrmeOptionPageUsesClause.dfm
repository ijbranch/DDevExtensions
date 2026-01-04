inherited FrameOptionPageUsesClause: TFrameOptionPageUsesClause
  Width = 400
  Height = 320
  inherited pnlClient: TPanel
    Width = 400
    Height = 271
    object chkEnabled: TCheckBox
      Left = 16
      Top = 8
      Width = 200
      Height = 17
      Caption = 'Enable Uses Clause Manager'
      TabOrder = 0
    end
    object lblInfo: TLabel
      Left = 16
      Top = 40
      Width = 360
      Height = 65
      AutoSize = False
      Caption =
        'The Uses Clause Manager analyzes your code to determine which u' +
        'nits should be in the interface uses clause vs the implementati' +
        'on uses clause. Units are moved to implementation if their symb' +
        'ols are only used in the implementation section.'
      WordWrap = True
    end
  end
  inherited pnlDescription: TPanel
    Width = 400
    inherited bvlSplitter: TBevel
      Width = 400
    end
    inherited lblDescription: TLabel
      Width = 368
      Caption =
        'Automatically organize uses clauses by moving units to the appr' +
        'opriate section.'
    end
  end
end
