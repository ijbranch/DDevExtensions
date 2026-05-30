object FormCollections: TFormCollections
  Caption = 'Collections Test'
  ClientHeight = 400
  ClientWidth = 600
  object ListView1: TListView
    Left = 0
    Top = 0
    Width = 600
    Height = 300
    Align = alClient
    Columns = <
      item
        Caption = 'Name'
        Width = 150
      end
      item
        Caption = 'Type'
        Width = 100
      end
      item
        Caption = 'Size'
        Width = 100
      end
      item
        Caption = 'Modified'
        Width = 150
      end>
    ViewStyle = vsReport
  end
  object ActionList1: TActionList
    Left = 520
    Top = 320
    object Action1: TAction
      Caption = 'Open'
      ShortCut = 16463
    end
    object Action2: TAction
      Caption = 'Save'
      ShortCut = 16467
    end
    object Action3: TAction
      Caption = 'Close'
      ShortCut = 16471
    end
  end
end
