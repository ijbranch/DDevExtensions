object FormTypePrefixEditor: TFormTypePrefixEditor
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Edit Variable Type Prefix Rules'
  ClientHeight = 380
  ClientWidth = 350
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poMainFormCenter
  OnCreate = FormCreate
  TextHeight = 13
  object lblInstructions: TLabel
    Left = 16
    Top = 16
    Width = 318
    Height = 26
    Caption =
      'Enter one rule per line in the format: Type=Prefix'#13#10'Example: St' +
      'ring=s, Integer=i, Boolean=l'
  end
  object lblWarning: TLabel
    Left = 16
    Top = 288
    Width = 318
    Height = 40
    AutoSize = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clMaroon
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
    WordWrap = True
  end
  object memRules: TMemo
    Left = 16
    Top = 52
    Width = 318
    Height = 230
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssVertical
    TabOrder = 0
    OnChange = memRulesChange
  end
  object btnOK: TButton
    Left = 178
    Top = 336
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 1
  end
  object btnCancel: TButton
    Left = 259
    Top = 336
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 2
  end
  object btnResetDefaults: TButton
    Left = 16
    Top = 336
    Width = 110
    Height = 25
    Caption = 'Reset to Defaults'
    TabOrder = 3
    OnClick = btnResetDefaultsClick
  end
end
