object POPrintForm: TPOPrintForm
  Left = 444
  Top = 350
  BorderIcons = []
  BorderStyle = bsDialog
  Caption = 'Purchase Order Print..'
  ClientHeight = 92
  ClientWidth = 326
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  OnClose = FormClose
  OnShow = FormShow
  TextHeight = 13
  object pnlFooter: TPanel
    Left = 0
    Top = 0
    Width = 326
    Height = 92
    Align = alClient
    TabOrder = 0
    object Label1: TLabel
      Left = 20
      Top = 20
      Width = 130
      Height = 17
      Alignment = taRightJustify
      Caption = 'Enter Parts Order # : '
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Transparent = True
    end
    object btnClose: TLMDButton
      Left = 206
      Top = 55
      Width = 110
      Height = 30
      ButtonLayout.Spacing = 4
      ButtonStyle = ubsDelphi
      Color = clSkyBlue
      ImageList = SVGVIL
      ParentColor = False
      Caption = '&Close'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 2
      OnClick = btnCloseClick
    end
    object btnPrintPO: TLMDButton
      Left = 16
      Top = 55
      Width = 184
      Height = 30
      ButtonLayout.Spacing = 4
      ButtonStyle = ubsDelphi
      Color = clSkyBlue
      ImageList = SVGVIL
      ImageIndex = 1
      ParentColor = False
      Visible = False
      Caption = '&Print Purchase Order'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 1
      OnClick = btnPrintPOClick
    end
    object edtPartsOrderNo: TRzEdit
      Left = 156
      Top = 17
      Width = 160
      Height = 25
      Text = ''
      CharCase = ecUpperCase
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      MaxLength = 16
      ParentFont = False
      TabOrder = 0
      OnChange = edtPartsOrderNoChange
    end
  end
  object BackOrders: TnlhTable
    Filter = ''
    Filtered = False
    DatabaseName = 'DBiStore'
    SessionName = 'DBSStore'
    IndexName = 'ORDERNO'
    TableName = 'BackOrders'
    Left = 284
  end
  object SVGVIL: TSVGIconVirtualImageList
    Images = <
      item
        CollectionIndex = 0
        CollectionName = 'Close Form'
        Name = 'Close Form'
      end
      item
        CollectionIndex = 7
        CollectionName = 'Invoice-Print_h'
        Name = 'Invoice-Print_h'
      end>
    ImageCollection = dmI.SVGIC
    PreserveItems = True
    Width = 20
    Height = 20
    Size = 20
    Left = 2
    Top = 8
  end
end
