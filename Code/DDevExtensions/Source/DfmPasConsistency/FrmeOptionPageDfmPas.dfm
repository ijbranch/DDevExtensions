inherited FrameOptionPageDfmPas: TFrameOptionPageDfmPas
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
      Caption = 'Enable DFM/PAS Consistency Checker'
      TabOrder = 0
    end
    object lblInfo: TLabel
      Left = 8
      Top = 40
      Width = 330
      Height = 80
      AutoSize = False
      Caption =
        'Scans your project for inconsistencies between DFM and PAS file' +
        's. Detects components in DFM that are not declared in PAS, and ' +
        'type mismatches where a component exists in both but with diffe' +
        'rent types. Common after refactoring or manual edits.'
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
      Width = 230
      Caption = 'Configure the DFM/PAS Consistency Checker.'
    end
  end
end
