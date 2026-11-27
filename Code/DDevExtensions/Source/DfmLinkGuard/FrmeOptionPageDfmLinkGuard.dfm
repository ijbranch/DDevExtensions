inherited FrameOptionPageDfmLinkGuard: TFrameOptionPageDfmLinkGuard
  Width = 350
  Height = 200
  inherited pnlClient: TPanel
    Width = 350
    Height = 151
    object chkActive: TCheckBox
      Left = 8
      Top = 8
      Width = 300
      Height = 17
      Caption = 'Warn when a save drops a link to another module'
      TabOrder = 0
    end
    object lblInfo: TLabel
      Left = 8
      Top = 40
      Width = 330
      Height = 100
      AutoSize = False
      Caption =
        'After every save of a form or data module, compares its .dfm wi' +
        'th the file before the save.  When the save removed a link to a ' +
        'component of another module ( DataSource = dmMain.dsCustomers )' +
        ' that still exists, a warning appears on the "DFM Link Guard" ta' +
        'b of the Messages pane.  The IDE drops such links when the other' +
        ' module is not loaded.  Measuring tool and findings: Tools\DfmNo' +
        'iseMeasure.'
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
      Caption = 'Configure the DFM Link Guard.'
    end
  end
end
