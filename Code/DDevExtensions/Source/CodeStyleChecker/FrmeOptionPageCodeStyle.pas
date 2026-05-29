{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageCodeStyle;

/// <summary>
/// Options-dialog frame embedded in the DDevExtensions tree page system. Exposes every
/// configurable Code Style Checker setting and writes the user's choices back to the plugin.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, System.Math, FrmeBase, FrmTreePages, CodeStyleChecker;

type
  /// <summary>Tree-page frame surfacing all Code Style Checker options to the user.</summary>
  TFrameOptionPageCodeStyle = class( TFrameBase, ITreePageComponent )
    /// <summary>Master enable for the plugin.</summary>
    chkEnabled: TCheckBox;
    /// <summary>Group containing the naming-convention rule check boxes.</summary>
    grpRules: TGroupBox;
    /// <summary>Toggles the type-prefix (T) rule.</summary>
    chkCheckTypes: TCheckBox;
    /// <summary>Toggles the interface-prefix (I) rule.</summary>
    chkCheckInterfaces: TCheckBox;
    /// <summary>Toggles the field-prefix (F) rule.</summary>
    chkCheckFields: TCheckBox;
    /// <summary>Toggles the exception-prefix (E) rule.</summary>
    chkCheckExceptions: TCheckBox;
    /// <summary>Toggles the pointer-prefix (P) rule.</summary>
    chkCheckPointers: TCheckBox;
    /// <summary>Toggles the parameter-prefix (A) rule.</summary>
    chkCheckParameters: TCheckBox;
    /// <summary>Group hosting the variable type-prefix configuration.</summary>
    grpTypePrefixes: TGroupBox;
    /// <summary>Enables variable-prefix checks against the editable rule list.</summary>
    chkCheckVariablePrefixes: TCheckBox;
    /// <summary>Summary label showing how many type-prefix rules are configured.</summary>
    lblRulesSummary: TLabel;
    /// <summary>Opens the <see cref="TFormTypePrefixEditor"/> dialog.</summary>
    btnEditRules: TButton;
    /// <summary>Group hosting the uses-clause options.</summary>
    grpUsesClause: TGroupBox;
    /// <summary>Toggles the unit-scope prefix check on uses clauses.</summary>
    chkCheckUnitScopeNames: TCheckBox;
    /// <summary>Group hosting all anti-pattern detection toggles.</summary>
    grpAntiPatterns: TGroupBox;
    /// <summary>Master toggle for anti-pattern detection.</summary>
    chkCheckAntiPatterns: TCheckBox;
    /// <summary>Toggles the empty-finally check.</summary>
    chkCheckEmptyFinally: TCheckBox;
    /// <summary>Toggles the nested-with check.</summary>
    chkCheckNestedWith: TCheckBox;
    /// <summary>Toggles the deep-nesting check.</summary>
    chkCheckDeepNesting: TCheckBox;
    /// <summary>Toggles the long-method check.</summary>
    chkCheckLongMethods: TCheckBox;
    /// <summary>Toggles the long-parameter-list check.</summary>
    chkCheckLongParamLists: TCheckBox;
    /// <summary>Label for <see cref="edtMaxNesting"/>.</summary>
    lblMaxNesting: TLabel;
    /// <summary>Editor for the maximum control-flow nesting depth.</summary>
    edtMaxNesting: TEdit;
    /// <summary>Label for <see cref="edtMaxLines"/>.</summary>
    lblMaxLines: TLabel;
    /// <summary>Editor for the maximum method length, in lines.</summary>
    edtMaxLines: TEdit;
    /// <summary>Label for <see cref="edtMaxParams"/>.</summary>
    lblMaxParams: TLabel;
    /// <summary>Editor for the maximum number of parameters per method.</summary>
    edtMaxParams: TEdit;
    /// <summary>Free-form information label describing the anti-pattern checks.</summary>
    lblAntiPatternInfo: TLabel;
    /// <summary>OnClick handler that opens the type-prefix rule editor.</summary>
    procedure btnEditRulesClick( Sender: TObject );
  private
    /// <summary>Plugin instance bound to this options frame.</summary>
    FPlugin: TCodeStyleCheckerPlugin;
    /// <summary>Refreshes <see cref="lblRulesSummary"/> with the current rule count and preview.</summary>
    procedure UpdateRulesSummary;
  public
    /// <summary>Standard frame constructor.</summary>
    constructor Create( AOwner: TComponent ); override;

    /// <summary>Loads control state from <see cref="FPlugin"/>.</summary>
    procedure LoadData;
    /// <summary>Writes current control state back to <see cref="FPlugin"/> and persists it.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes visible (no-op).</summary>
    procedure Selected;
    /// <summary>Called when the page is hidden (no-op).</summary>
    procedure Unselected;
    /// <summary>Captures the plugin instance passed in by the options dialog.</summary>
    /// <param name="UserData">The owning <see cref="TCodeStyleCheckerPlugin"/>.</param>
    procedure SetUserData( UserData: TObject );
  end;

implementation

{$R *.dfm}

uses
  FrmTypePrefixEditor;

{ TFrameOptionPageCodeStyle }

constructor TFrameOptionPageCodeStyle.Create( AOwner: TComponent );
begin

  inherited Create( AOwner );

end;

procedure TFrameOptionPageCodeStyle.SetUserData( UserData: TObject );
begin

  FPlugin := UserData as TCodeStyleCheckerPlugin;

end;

procedure TFrameOptionPageCodeStyle.LoadData;
begin

  chkEnabled.Checked               := FPlugin.Enabled;
  chkCheckTypes.Checked            := FPlugin.CheckTypes;
  chkCheckInterfaces.Checked       := FPlugin.CheckInterfaces;
  chkCheckFields.Checked           := FPlugin.CheckFields;
  chkCheckExceptions.Checked       := FPlugin.CheckExceptions;
  chkCheckPointers.Checked         := FPlugin.CheckPointers;
  chkCheckParameters.Checked       := FPlugin.CheckParameters;
  chkCheckVariablePrefixes.Checked := FPlugin.CheckVariablePrefixes;
  chkCheckUnitScopeNames.Checked   := FPlugin.CheckUnitScopeNames;

  // Anti-pattern options
  chkCheckAntiPatterns.Checked     := FPlugin.CheckAntiPatterns;
  chkCheckEmptyFinally.Checked     := FPlugin.CheckEmptyFinally;
  chkCheckNestedWith.Checked       := FPlugin.CheckNestedWith;
  chkCheckDeepNesting.Checked      := FPlugin.CheckDeepNesting;
  chkCheckLongMethods.Checked      := FPlugin.CheckLongMethods;
  chkCheckLongParamLists.Checked   := FPlugin.CheckLongParamLists;
  edtMaxNesting.Text               := IntToStr( FPlugin.MaxNestingDepth );
  edtMaxLines.Text                 := IntToStr( FPlugin.MaxMethodLines );
  edtMaxParams.Text                := IntToStr( FPlugin.MaxParameters );

  UpdateRulesSummary;

end;

procedure TFrameOptionPageCodeStyle.SaveData;
begin

  FPlugin.Enabled               := chkEnabled.Checked;
  FPlugin.CheckTypes            := chkCheckTypes.Checked;
  FPlugin.CheckInterfaces       := chkCheckInterfaces.Checked;
  FPlugin.CheckFields           := chkCheckFields.Checked;
  FPlugin.CheckExceptions       := chkCheckExceptions.Checked;
  FPlugin.CheckPointers         := chkCheckPointers.Checked;
  FPlugin.CheckParameters       := chkCheckParameters.Checked;
  FPlugin.CheckVariablePrefixes := chkCheckVariablePrefixes.Checked;
  FPlugin.CheckUnitScopeNames   := chkCheckUnitScopeNames.Checked;

  // Anti-pattern options
  FPlugin.CheckAntiPatterns     := chkCheckAntiPatterns.Checked;
  FPlugin.CheckEmptyFinally     := chkCheckEmptyFinally.Checked;
  FPlugin.CheckNestedWith       := chkCheckNestedWith.Checked;
  FPlugin.CheckDeepNesting      := chkCheckDeepNesting.Checked;
  FPlugin.CheckLongMethods      := chkCheckLongMethods.Checked;
  FPlugin.CheckLongParamLists   := chkCheckLongParamLists.Checked;
  FPlugin.MaxNestingDepth       := StrToIntDef( edtMaxNesting.Text, 4 );
  FPlugin.MaxMethodLines        := StrToIntDef( edtMaxLines.Text, 100 );
  FPlugin.MaxParameters         := StrToIntDef( edtMaxParams.Text, 6 );

  FPlugin.Save;

end;

procedure TFrameOptionPageCodeStyle.UpdateRulesSummary;
var
  Rules: TArray<TTypePrefixRule>;
  Summary: string;
  I: Integer;
begin

  Rules := FPlugin.TypePrefixRules;

  if Length( Rules ) = 0 then
    Summary := 'No rules configured'
  else
  begin
    Summary := IntToStr( Length( Rules ) ) + ' rules configured (';

    // Show first few rules as preview
    for I := 0 to Min( 2, High( Rules ) ) do
    begin
      if I > 0 then
        Summary := Summary + ', ';

      Summary := Summary + Rules[ I ].TypePattern + '=' + Rules[ I ].Prefix;
    end;

    if Length( Rules ) > 3 then
      Summary := Summary + ', ...';

    Summary := Summary + ')';
  end;

  lblRulesSummary.Caption := Summary;

end;

procedure TFrameOptionPageCodeStyle.btnEditRulesClick( Sender: TObject );
begin

  if TFormTypePrefixEditor.Execute( FPlugin ) then
  begin
    // Persist immediately so the saved CodeStyleChecker.xml matches the rules
    // the summary now reports, even if the user later cancels the options dialog.
    FPlugin.Save;
    UpdateRulesSummary;
  end;

end;

procedure TFrameOptionPageCodeStyle.Selected;
begin
end;

procedure TFrameOptionPageCodeStyle.Unselected;
begin
end;

end.
