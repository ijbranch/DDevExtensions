{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageCodeQuality;

/// <summary>
/// Tree-page options frame for the Code Quality Analyzer plugin. Renders one tab sheet per
/// detection category and binds the controls to the persistent settings on
/// <see cref="TCodeQualityAnalyzerPlugin"/>.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, FrmeBase, FrmTreePages, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  CodeQualityAnalyzer;

type
  /// <summary>Options frame surfacing every Code Quality Analyzer setting.</summary>
  TFrameOptionPageCodeQuality = class( TFrameBase, ITreePageComponent )
    /// <summary>Master enable for the plugin.</summary>
    chkEnabled: TCheckBox;
    /// <summary>Page control hosting one tab per detection category.</summary>
    pcCategories: TPageControl;
    /// <summary>Tab containing magic-number settings.</summary>
    tsMagicNumbers: TTabSheet;
    /// <summary>Tab containing hardcoded-string settings.</summary>
    tsStrings: TTabSheet;
    /// <summary>Tab containing commented-out-code settings.</summary>
    tsComments: TTabSheet;
    /// <summary>Tab containing exception-handling settings.</summary>
    tsExceptions: TTabSheet;
    /// <summary>Tab containing memory-management settings.</summary>
    tsMemory: TTabSheet;
    /// <summary>Toggles magic-number detection.</summary>
    chkMagicNumbers: TCheckBox;
    /// <summary>Label for <see cref="edtWhitelist"/>.</summary>
    lblWhitelist: TLabel;
    /// <summary>Editor for the magic-number whitelist.</summary>
    edtWhitelist: TEdit;
    /// <summary>Toggles the array-index exemption for magic-number detection.</summary>
    chkAllowArrayIndex: TCheckBox;
    /// <summary>Toggles hardcoded-string detection.</summary>
    chkHardcodedStrings: TCheckBox;
    /// <summary>Label for <see cref="edtMinLength"/>.</summary>
    lblMinLength: TLabel;
    /// <summary>Editor for the minimum reportable string length.</summary>
    edtMinLength: TEdit;
    /// <summary>Toggles the format-string exemption.</summary>
    chkExcludeFormat: TCheckBox;
    /// <summary>Toggles the SQL-keyword exemption.</summary>
    chkExcludeSQL: TCheckBox;
    /// <summary>Toggles commented-out-code detection.</summary>
    chkCommentedCode: TCheckBox;
    /// <summary>Label for <see cref="edtThreshold"/>.</summary>
    lblThreshold: TLabel;
    /// <summary>Editor for the commented-out-code score threshold.</summary>
    edtThreshold: TEdit;
    /// <summary>Toggles empty-except detection.</summary>
    chkEmptyExcept: TCheckBox;
    /// <summary>Toggles catch-all-exception detection.</summary>
    chkCatchAll: TCheckBox;
    /// <summary>Toggles missing-try/finally detection.</summary>
    chkMissingTryFinally: TCheckBox;
    /// <summary>Toggles memory-leak detection (reserved).</summary>
    chkMemoryLeaks: TCheckBox;
    /// <summary>Label for <see cref="edtIgnorePatterns"/>.</summary>
    lblIgnorePatterns: TLabel;
    /// <summary>Editor for memory-leak ignore patterns.</summary>
    edtIgnorePatterns: TEdit;
  private
    /// <summary>Plugin instance bound to this options frame.</summary>
    FPlugin: TCodeQualityAnalyzerPlugin;
  public
    /// <summary>Standard frame constructor.</summary>
    constructor Create( AOwner: TComponent ); override;

    /// <summary>Loads control state from <see cref="FPlugin"/>.</summary>
    procedure LoadData;
    /// <summary>Writes the control state back to <see cref="FPlugin"/> and persists it.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes visible (no-op).</summary>
    procedure Selected;
    /// <summary>Called when the page is hidden (no-op).</summary>
    procedure Unselected;
    /// <summary>Captures the plugin instance passed in by the options dialog.</summary>
    /// <param name="UserData">The owning <see cref="TCodeQualityAnalyzerPlugin"/>.</param>
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
