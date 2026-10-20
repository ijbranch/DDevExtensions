inherited FrameOptionPageDecirculariser: TFrameOptionPageDecirculariser
  Width = 400
  Height = 320
  ExplicitWidth = 400
  ExplicitHeight = 320
  inherited pnlClient: TPanel
    Width = 400
    Height = 271
    ExplicitWidth = 400
    ExplicitHeight = 271
    object lblFewSymbols: TLabel
      Left = 16
      Top = 44
      Width = 280
      Height = 13
      Caption = 'An edge is extractable at or below this many identifiers:'
    end
    object chkEnabled: TCheckBox
      Left = 16
      Top = 12
      Width = 250
      Height = 17
      Caption = 'Enable Decirculariser'
      TabOrder = 0
    end
    object edtFewSymbols: TEdit
      Left = 16
      Top = 63
      Width = 60
      Height = 21
      NumbersOnly = True
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
        'Finds groups of units that depend on each other, ranks them by ri' +
        'sk and says what it would take to break each edge.'
    end
  end
end
