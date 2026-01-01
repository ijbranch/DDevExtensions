inherited FormDependencyViewer: TFormDependencyViewer
  Caption = 'Dependency Viewer'
  ClientHeight = 500
  ClientWidth = 800
  Position = poMainFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Splitter: TSplitter
    Left = 500
    Top = 33
    Height = 426
    Align = alRight
    ExplicitLeft = 504
    ExplicitTop = 128
    ExplicitHeight = 100
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 33
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnScanProject: TButton
      Left = 8
      Top = 4
      Width = 113
      Height = 25
      Caption = 'Scan Active Project'
      TabOrder = 0
      OnClick = btnScanProjectClick
    end
    object lblProgress: TLabel
      Left = 136
      Top = 10
      Width = 3
      Height = 13
      Visible = False
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 459
    Width = 800
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object btnClose: TButton
      Left = 717
      Top = 8
      Width = 75
      Height = 25
      Cancel = True
      Caption = 'Close'
      Default = True
      ModalResult = 1
      TabOrder = 0
      OnClick = btnCloseClick
    end
  end
  object TreeView: TTreeView
    Left = 0
    Top = 33
    Width = 500
    Height = 426
    Align = alClient
    Indent = 19
    ReadOnly = True
    TabOrder = 2
    OnExpanding = TreeViewExpanding
  end
  object pnlRight: TPanel
    Left = 503
    Top = 33
    Width = 297
    Height = 426
    Align = alRight
    BevelOuter = bvNone
    TabOrder = 3
    object lblCircularRefs: TLabel
      Left = 8
      Top = 8
      Width = 100
      Height = 13
      Caption = 'Circular References:'
    end
    object ListBoxCircular: TListBox
      Left = 0
      Top = 27
      Width = 297
      Height = 399
      Align = alBottom
      Anchors = [akLeft, akTop, akRight, akBottom]
      ItemHeight = 13
      TabOrder = 0
      OnClick = ListBoxCircularClick
    end
  end
end
