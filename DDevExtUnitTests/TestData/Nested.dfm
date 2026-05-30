object FormNested: TFormNested
  Caption = 'Nested Components'
  ClientHeight = 300
  ClientWidth = 400
  object Panel1: TPanel
    Align = alTop
    Height = 41
    object Button1: TButton
      Left = 10
      Top = 10
      Width = 75
      Height = 25
      Caption = 'OK'
    end
    object Button2: TButton
      Left = 100
      Top = 10
      Width = 75
      Height = 25
      Caption = 'Cancel'
    end
  end
end
