object FormMultiLine: TFormMultiLine
  Caption = 'Multi-Line Strings Test'
  ClientHeight = 400
  ClientWidth = 600
  object Memo1: TMemo
    Left = 10
    Top = 10
    Width = 580
    Height = 150
    Lines.Strings = (
      'This is line 1'
      'This is line 2 with '#39'quotes'#39
      'This is line 3'
      ''
      'Line 5 after blank line')
  end
  object ComboBox1: TComboBox
    Left = 10
    Top = 170
    Width = 200
    Height = 21
    Items.Strings = (
      'Option 1'
      'Option 2'
      'Option 3'
      'It'#39's OK'
      'Another "quoted" value')
  end
  object ListBox1: TListBox
    Left = 220
    Top = 170
    Width = 200
    Height = 150
    Items.Strings = (
      'Item A'
      'Item B'
      'Item C'
      'Item D')
  end
end
