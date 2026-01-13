inherited FormLibraryPathSorter: TFormLibraryPathSorter
  Caption = 'Library Path Sorter'
  ClientHeight = 650
  ClientWidth = 950
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Splitter: TSplitter
    Left = 0
    Top = 349
    Width = 950
    Height = 5
    Cursor = crVSplit
    Align = alTop
  end
  object SplitterBackups: TSplitter
    Left = 0
    Top = 499
    Width = 950
    Height = 5
    Cursor = crVSplit
    Align = alBottom
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 950
    Height = 70
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblPathType: TLabel
      Left = 12
      Top = 16
      Width = 51
      Height = 13
      Caption = 'Path Type:'
    end
    object lblPlatform: TLabel
      Left = 280
      Top = 16
      Width = 45
      Height = 13
      Caption = 'Platform:'
    end
    object lblStatus: TLabel
      Left = 500
      Top = 16
      Width = 3
      Height = 13
    end
    object lblCaution: TLabel
      Left = 12
      Top = 44
      Width = 930
      Height = 13
      AutoSize = False
      Caption = 'CAUTION: Path order affects compilation. First matching unit wins. RTL/VCL paths should come first, then vendors, then custom paths.'
      Font.Color = clMaroon
      Font.Style = [fsBold]
      ParentFont = False
    end
    object cboPathType: TComboBox
      Left = 72
      Top = 13
      Width = 193
      Height = 21
      Style = csDropDownList
      TabOrder = 0
      OnChange = cboPathTypeChange
    end
    object cboPlatform: TComboBox
      Left = 336
      Top = 13
      Width = 100
      Height = 21
      Style = csDropDownList
      TabOrder = 1
      OnChange = cboPlatformChange
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 609
    Width = 950
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object chkAutoBackup: TCheckBox
      Left = 12
      Top = 12
      Width = 150
      Height = 17
      Caption = 'Auto-backup before apply'
      Checked = True
      State = cbChecked
      TabOrder = 0
    end
    object btnBackup: TButton
      Left = 180
      Top = 8
      Width = 90
      Height = 25
      Caption = 'Create &Backup'
      TabOrder = 1
      OnClick = btnBackupClick
    end
    object btnRestore: TButton
      Left = 550
      Top = 8
      Width = 100
      Height = 25
      Caption = '&Restore Selected'
      Enabled = False
      TabOrder = 2
      OnClick = btnRestoreClick
    end
    object btnDeleteBackup: TButton
      Left = 660
      Top = 8
      Width = 100
      Height = 25
      Caption = '&Delete Backup'
      Enabled = False
      TabOrder = 3
      OnClick = btnDeleteBackupClick
    end
    object btnClose: TButton
      Left = 862
      Top = 8
      Width = 80
      Height = 25
      Caption = '&Close'
      TabOrder = 4
      OnClick = btnCloseClick
    end
  end
  object pnlMain: TPanel
    Left = 0
    Top = 49
    Width = 950
    Height = 300
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 2
    object pnlCurrent: TPanel
      Left = 0
      Top = 0
      Width = 440
      Height = 300
      Align = alLeft
      BevelOuter = bvNone
      TabOrder = 0
      object lblCurrent: TLabel
        Left = 0
        Top = 0
        Width = 440
        Height = 20
        Align = alTop
        Caption = '  Original Paths (Read-Only - Current Registry Order):'
        Layout = tlCenter
      end
      object lstCurrent: TListBox
        Left = 0
        Top = 20
        Width = 440
        Height = 280
        Align = alClient
        ItemHeight = 13
        TabOrder = 0
      end
    end
    object pnlWorking: TPanel
      Left = 476
      Top = 0
      Width = 474
      Height = 300
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      object lblWorking: TLabel
        Left = 0
        Top = 0
        Width = 474
        Height = 20
        Align = alTop
        Caption = '  Working Panel (Editable - Arrange Then Apply):'
        Layout = tlCenter
      end
      object lstWorking: TListBox
        Left = 34
        Top = 20
        Width = 440
        Height = 235
        Align = alClient
        ItemHeight = 13
        PopupMenu = pmWorking
        TabOrder = 0
        OnClick = lstWorkingClick
        OnDragDrop = lstWorkingDragDrop
        OnDragOver = lstWorkingDragOver
        OnDrawItem = lstWorkingDrawItem
        OnMouseDown = lstWorkingMouseDown
      end
      object pnlWorkingButtons: TPanel
        Left = 0
        Top = 20
        Width = 34
        Height = 235
        Align = alLeft
        BevelOuter = bvNone
        TabOrder = 1
        object btnWorkingTop: TSpeedButton
          Left = 4
          Top = 4
          Width = 26
          Height = 26
          Hint = 'Move to Top'
          Caption = '|<'
          ParentShowHint = False
          ShowHint = True
          OnClick = btnWorkingTopClick
        end
        object btnWorkingUp: TSpeedButton
          Left = 4
          Top = 34
          Width = 26
          Height = 26
          Hint = 'Move Up'
          Caption = '^'
          ParentShowHint = False
          ShowHint = True
          OnClick = btnWorkingUpClick
        end
        object btnWorkingDown: TSpeedButton
          Left = 4
          Top = 64
          Width = 26
          Height = 26
          Hint = 'Move Down'
          Caption = 'v'
          ParentShowHint = False
          ShowHint = True
          OnClick = btnWorkingDownClick
        end
        object btnWorkingBottom: TSpeedButton
          Left = 4
          Top = 94
          Width = 26
          Height = 26
          Hint = 'Move to Bottom'
          Caption = '>|'
          ParentShowHint = False
          ShowHint = True
          OnClick = btnWorkingBottomClick
        end
      end
      object btnApply: TButton
        Left = 0
        Top = 255
        Width = 474
        Height = 45
        Align = alBottom
        Caption = 'Apply Working Panel to Registry'
        TabOrder = 2
        OnClick = btnApplyClick
      end
    end
    object btnCopyToWorking: TSpeedButton
      Left = 444
      Top = 80
      Width = 30
      Height = 50
      Hint = 'Copy Original to Working'
      Caption = '>>'
      ParentShowHint = False
      ShowHint = True
      OnClick = btnCopyToWorkingClick
    end
    object btnSortAlpha: TButton
      Left = 444
      Top = 140
      Width = 30
      Height = 50
      Hint = 'Sort Working Alphabetically'
      Caption = 'A-Z'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 3
      OnClick = btnSortAlphaClick
    end
  end
  object pnlBackups: TPanel
    Left = 0
    Top = 354
    Width = 950
    Height = 145
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 3
    object lblBackups: TLabel
      Left = 0
      Top = 0
      Width = 950
      Height = 20
      Align = alTop
      Caption = '  Backup History:'
      Layout = tlCenter
    end
    object lvBackups: TListView
      Left = 0
      Top = 20
      Width = 950
      Height = 125
      Align = alClient
      Columns = <
        item
          Caption = 'Date/Time'
          Width = 150
        end
        item
          Caption = 'Path Type'
          Width = 150
        end
        item
          Caption = 'Platform'
          Width = 80
        end
        item
          Caption = 'Description'
          Width = 400
        end>
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnSelectItem = lvBackupsSelectItem
    end
  end
  object pmWorking: TPopupMenu
    Left = 500
    Top = 200
    object mnuDeleteEntry: TMenuItem
      Caption = 'Delete Entry'
      OnClick = mnuDeleteEntryClick
    end
  end
end
