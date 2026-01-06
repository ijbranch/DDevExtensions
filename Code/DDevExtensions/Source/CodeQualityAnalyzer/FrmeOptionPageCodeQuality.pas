{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageCodeQuality;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, FrmeBase, FrmTreePages, StdCtrls, ExtCtrls, ComCtrls,
  CodeQualityAnalyzer;

type
  TFrameOptionPageCodeQuality = class( TFrameBase, ITreePageComponent )
    chkEnabled: TCheckBox;
    pcCategories: TPageControl;
    tsMagicNumbers: TTabSheet;
    tsStrings: TTabSheet;
    tsComments: TTabSheet;
    tsExceptions: TTabSheet;
    tsMemory: TTabSheet;
    chkMagicNumbers: TCheckBox;
    lblWhitelist: TLabel;
    edtWhitelist: TEdit;
    chkAllowArrayIndex: TCheckBox;
    chkHardcodedStrings: TCheckBox;
    lblMinLength: TLabel;
    edtMinLength: TEdit;
    chkExcludeFormat: TCheckBox;
    chkExcludeSQL: TCheckBox;
    chkCommentedCode: TCheckBox;
    lblThreshold: TLabel;
    edtThreshold: TEdit;
    chkEmptyExcept: TCheckBox;
    chkCatchAll: TCheckBox;
    chkMissingTryFinally: TCheckBox;
    chkMemoryLeaks: TCheckBox;
    lblIgnorePatterns: TLabel;
    edtIgnorePatterns: TEdit;
  private
    FPlugin: TCodeQualityAnalyzerPlugin;
  public
    constructor Create( AOwner: TComponent ); override;

    procedure LoadData;
    procedure SaveData;
    procedure Selected;
    procedure Unselected;
    procedure SetUserData( UserData: TObject );
  end;

implementation

{$R *.dfm}

{ TFrameOptionPageCodeQuality }

constructor TFrameOptionPageCodeQuality.Create( AOwner: TComponent );
begin
  inherited Create( AOwner );
end;

procedure TFrameOptionPageCodeQuality.SetUserData( UserData: TObject );
begin
  FPlugin := UserData as TCodeQualityAnalyzerPlugin;
end;

procedure TFrameOptionPageCodeQuality.LoadData;
begin
  if FPlugin = nil then
    Exit;

  chkEnabled.Checked := FPlugin.Enabled;

  // Magic Numbers
  chkMagicNumbers.Checked := FPlugin.CheckMagicNumbers;
  edtWhitelist.Text := FPlugin.MagicNumberWhitelist;
  chkAllowArrayIndex.Checked := FPlugin.AllowMagicInArrayIndex;

  // Hardcoded Strings
  chkHardcodedStrings.Checked := FPlugin.CheckHardcodedStrings;
  edtMinLength.Text := IntToStr( FPlugin.MinStringLength );
  chkExcludeFormat.Checked := FPlugin.ExcludeFormatStrings;
  chkExcludeSQL.Checked := FPlugin.ExcludeSQLKeywords;

  // Commented-Out Code
  chkCommentedCode.Checked := FPlugin.CheckCommentedCode;
  edtThreshold.Text := IntToStr( FPlugin.CommentCodeThreshold );

  // Exception Handling
  chkEmptyExcept.Checked := FPlugin.CheckEmptyExcept;
  chkCatchAll.Checked := FPlugin.CheckCatchAllException;

  // Memory Management
  chkMissingTryFinally.Checked := FPlugin.CheckMissingTryFinally;
  chkMemoryLeaks.Checked := FPlugin.CheckMemoryLeaks;
  edtIgnorePatterns.Text := FPlugin.MemoryLeakIgnorePatterns;
end;

procedure TFrameOptionPageCodeQuality.SaveData;
begin
  if FPlugin = nil then
    Exit;

  FPlugin.Enabled := chkEnabled.Checked;

  // Magic Numbers
  FPlugin.CheckMagicNumbers := chkMagicNumbers.Checked;
  FPlugin.MagicNumberWhitelist := edtWhitelist.Text;
  FPlugin.AllowMagicInArrayIndex := chkAllowArrayIndex.Checked;

  // Hardcoded Strings
  FPlugin.CheckHardcodedStrings := chkHardcodedStrings.Checked;
  FPlugin.MinStringLength := StrToIntDef( edtMinLength.Text, 3 );
  FPlugin.ExcludeFormatStrings := chkExcludeFormat.Checked;
  FPlugin.ExcludeSQLKeywords := chkExcludeSQL.Checked;

  // Commented-Out Code
  FPlugin.CheckCommentedCode := chkCommentedCode.Checked;
  FPlugin.CommentCodeThreshold := StrToIntDef( edtThreshold.Text, 3 );

  // Exception Handling
  FPlugin.CheckEmptyExcept := chkEmptyExcept.Checked;
  FPlugin.CheckCatchAllException := chkCatchAll.Checked;

  // Memory Management
  FPlugin.CheckMissingTryFinally := chkMissingTryFinally.Checked;
  FPlugin.CheckMemoryLeaks := chkMemoryLeaks.Checked;
  FPlugin.MemoryLeakIgnorePatterns := edtIgnorePatterns.Text;

  FPlugin.Save;
end;

procedure TFrameOptionPageCodeQuality.Selected;
begin
end;

procedure TFrameOptionPageCodeQuality.Unselected;
begin
end;

end.
