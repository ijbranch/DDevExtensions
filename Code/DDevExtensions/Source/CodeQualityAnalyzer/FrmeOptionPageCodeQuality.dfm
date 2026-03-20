inherited FrameOptionPageCodeQuality: TFrameOptionPageCodeQuality
  Width = 450
  Height = 420
  inherited pnlClient: TPanel
    Width = 450
    Height = 371
    object chkEnabled: TCheckBox
      Left = 8
      Top = 8
      Width = 300
      Height = 17
      Caption = 'Enable Code Quality Analyzer'
      TabOrder = 0
    end
    object pcCategories: TPageControl
      Left = 8
      Top = 36
      Width = 430
      Height = 325
      ActivePage = tsMagicNumbers
      TabOrder = 1
      object tsMagicNumbers: TTabSheet
        Caption = 'Magic Numbers'
        object lblWhitelist: TLabel
          Left = 16
          Top = 50
          Width = 44
          Height = 13
          Caption = 'Whitelist:'
        end
        object chkMagicNumbers: TCheckBox
          Left = 16
          Top = 16
          Width = 200
          Height = 17
          Caption = 'Check for magic numbers'
          TabOrder = 0
        end
        object edtWhitelist: TEdit
          Left = 16
          Top = 68
          Width = 380
          Height = 21
          TabOrder = 1
        end
        object chkAllowArrayIndex: TCheckBox
          Left = 16
          Top = 100
          Width = 250
          Height = 17
          Caption = 'Allow magic numbers in array indices'
          TabOrder = 2
        end
      end
      object tsStrings: TTabSheet
        Caption = 'Strings'
        ImageIndex = 1
        object lblMinLength: TLabel
          Left = 16
          Top = 50
          Width = 126
          Height = 13
          Caption = 'Minimum string length:'
        end
        object chkHardcodedStrings: TCheckBox
          Left = 16
          Top = 16
          Width = 200
          Height = 17
          Caption = 'Check for hardcoded strings'
          TabOrder = 0
        end
        object edtMinLength: TEdit
          Left = 150
          Top = 47
          Width = 40
          Height = 21
          TabOrder = 1
        end
        object chkExcludeFormat: TCheckBox
          Left = 16
          Top = 82
          Width = 250
          Height = 17
          Caption = 'Exclude format strings (%s, %d, etc.)'
          TabOrder = 2
        end
        object chkExcludeSQL: TCheckBox
          Left = 16
          Top = 108
          Width = 250
          Height = 17
          Caption = 'Exclude SQL keywords'
          TabOrder = 3
        end
      end
      object tsComments: TTabSheet
        Caption = 'Comments'
        ImageIndex = 2
        object lblThreshold: TLabel
          Left = 16
          Top = 50
          Width = 99
          Height = 13
          Caption = 'Detection threshold:'
        end
        object chkCommentedCode: TCheckBox
          Left = 16
          Top = 16
          Width = 250
          Height = 17
          Caption = 'Check for commented-out code'
          TabOrder = 0
        end
        object edtThreshold: TEdit
          Left = 130
          Top = 47
          Width = 40
          Height = 21
          TabOrder = 1
        end
      end
      object tsExceptions: TTabSheet
        Caption = 'Exceptions'
        ImageIndex = 3
        object chkEmptyExcept: TCheckBox
          Left = 16
          Top = 16
          Width = 250
          Height = 17
          Caption = 'Check for empty except blocks'
          TabOrder = 0
        end
        object chkCatchAll: TCheckBox
          Left = 16
          Top = 46
          Width = 300
          Height = 17
          Caption = 'Check for catch-all handlers without "on E:" clause'
          TabOrder = 1
        end
      end
      object tsMemory: TTabSheet
        Caption = 'Memory'
        ImageIndex = 4
        object lblIgnorePatterns: TLabel
          Left = 16
          Top = 82
          Width = 77
          Height = 13
          Caption = 'Ignore patterns:'
        end
        object chkMissingTryFinally: TCheckBox
          Left = 16
          Top = 16
          Width = 300
          Height = 17
          Caption = 'Check for Create without try/finally/Free'
          TabOrder = 0
        end
        object chkMemoryLeaks: TCheckBox
          Left = 16
          Top = 46
          Width = 250
          Height = 17
          Caption = 'Check for potential memory leaks'
          TabOrder = 1
        end
        object edtIgnorePatterns: TEdit
          Left = 16
          Top = 100
          Width = 380
          Height = 21
          TabOrder = 2
        end
      end
    end
  end
  inherited pnlDescription: TPanel
    Top = 371
    Width = 450
    inherited bvlSplitter: TBevel
      Width = 450
    end
    inherited lblDescription: TLabel
      Width = 418
      Caption = 
        'Configure the Code Quality Analyzer to detect common code issues' +
        '.'
    end
  end
end
