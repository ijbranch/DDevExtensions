object FormComplex: TFormComplex
  Left = 0
  Top = 0
  Caption = 'Complex Form Test'
  ClientHeight = 600
  ClientWidth = 800
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poScreenCenter
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 50
    Align = alTop
    Caption = 'Panel1'
    TabOrder = 0
    object Label1: TLabel
      Left = 10
      Top = 15
      Width = 100
      Height = 13
      Caption = 'Complex Test Form'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object Button1: TButton
      Left = 700
      Top = 10
      Width = 75
      Height = 25
      Caption = 'Close'
      TabOrder = 0
    end
  end
  object PageControl1: TPageControl
    Left = 0
    Top = 50
    Width = 800
    Height = 550
    ActivePage = TabSheet1
    Align = alClient
    TabOrder = 1
    object TabSheet1: TTabSheet
      Caption = 'General'
      object GroupBox1: TGroupBox
        Left = 10
        Top = 10
        Width = 300
        Height = 150
        Caption = 'Options'
        TabOrder = 0
        object CheckBox1: TCheckBox
          Left = 10
          Top = 20
          Width = 97
          Height = 17
          Caption = 'Enable Feature'
          Checked = True
          State = cbChecked
        end
        object CheckBox2: TCheckBox
          Left = 10
          Top = 43
          Width = 97
          Height = 17
          Caption = 'Auto Save'
        end
        object RadioButton1: TRadioButton
          Left = 10
          Top = 70
          Width = 113
          Height = 17
          Caption = 'Option A'
          Checked = True
          TabOrder = 0
          TabStop = True
        end
        object RadioButton2: TRadioButton
          Left = 10
          Top = 93
          Width = 113
          Height = 17
          Caption = 'Option B'
          TabOrder = 1
        end
      end
      object StringGrid1: TStringGrid
        Left = 320
        Top = 10
        Width = 450
        Height = 400
        ColCount = 3
        RowCount = 10
        FixedCols = 1
        TabOrder = 1
      end
    end
    object TabSheet2: TTabSheet
      Caption = 'Advanced'
      ImageIndex = 1
      object Memo2: TMemo
        Left = 10
        Top = 10
        Width = 760
        Height = 500
        Lines.Strings = (
          'Advanced settings'
          'Line 2'
          'Line 3 with '#39'quotes'#39
          ''
          'Final line')
        ScrollBars = ssBoth
      end
    end
  end
end
