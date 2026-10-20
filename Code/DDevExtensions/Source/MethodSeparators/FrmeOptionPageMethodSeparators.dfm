inherited FrameOptionPageMethodSeparators: TFrameOptionPageMethodSeparators
  Width = 507
  Height = 261
  TabStop = True
  inherited pnlClient: TPanel
    Width = 507
    Height = 212
    object cbxActive: TCheckBox
      Left = 8
      Top = 8
      Width = 225
      Height = 17
      Caption = '&Active'
      TabOrder = 0
      OnClick = cbxActiveClick
    end
    object cbxShowTypes: TCheckBox
      Left = 24
      Top = 32
      Width = 400
      Height = 17
      Caption = 'Separate &class, record and interface declarations'
      TabOrder = 1
    end
    object cbxShowSections: TCheckBox
      Left = 24
      Top = 55
      Width = 400
      Height = 17
      Caption = 'Separate i&nitialization, finalization and main program block'
      TabOrder = 2
    end
    object cbxShowInterface: TCheckBox
      Left = 24
      Top = 78
      Width = 400
      Height = 17
      Caption = 'Also separate declarations in the &interface section'
      TabOrder = 3
    end
    object lblLineStyle: TLabel
      Left = 24
      Top = 107
      Width = 52
      Height = 13
      Caption = 'Line st&yle:'
      FocusControl = cboLineStyle
    end
    object cboLineStyle: TComboBox
      Left = 152
      Top = 104
      Width = 121
      Height = 21
      Style = csDropDownList
      TabOrder = 4
      Items.Strings = (
        'Dotted'
        'Dashed'
        'Solid')
    end
    object cbxUseCustomColor: TCheckBox
      Left = 24
      Top = 134
      Width = 120
      Height = 17
      Caption = 'C&ustom colour:'
      TabOrder = 5
      OnClick = cbxActiveClick
    end
    object clbCustomColor: TColorBox
      Left = 152
      Top = 132
      Width = 145
      Height = 22
      Style = [cbStandardColors, cbExtendedColors, cbCustomColor, cbPrettyNames]
      TabOrder = 6
    end
    object lblColorNote: TLabel
      Left = 152
      Top = 160
      Width = 337
      Height = 13
      Caption = 'A colour too close to the editor background is replaced automatically.'
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
        'Draws a faint line in the code editor above each method, type declaration and unit section. Colour follows the editor theme unless a custom colour is chosen. Idea from Tulip Method Separators by Samer Assil.'
    end
  end
end
