{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageCodeStyle;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Math, FrmeBase, FrmTreePages, CodeStyleChecker;

type
  TFrameOptionPageCodeStyle = class( TFrameBase, ITreePageComponent )
    chkEnabled: TCheckBox;
    grpRules: TGroupBox;
    chkCheckTypes: TCheckBox;
    chkCheckInterfaces: TCheckBox;
    chkCheckFields: TCheckBox;
    chkCheckExceptions: TCheckBox;
    chkCheckPointers: TCheckBox;
    chkCheckParameters: TCheckBox;
    grpTypePrefixes: TGroupBox;
    chkCheckVariablePrefixes: TCheckBox;
    lblRulesSummary: TLabel;
    btnEditRules: TButton;
    grpUsesClause: TGroupBox;
    chkCheckUnitScopeNames: TCheckBox;
    grpAntiPatterns: TGroupBox;
    chkCheckAntiPatterns: TCheckBox;
    chkCheckEmptyFinally: TCheckBox;
    chkCheckNestedWith: TCheckBox;
    chkCheckDeepNesting: TCheckBox;
    chkCheckLongMethods: TCheckBox;
    chkCheckLongParamLists: TCheckBox;
    lblMaxNesting: TLabel;
    edtMaxNesting: TEdit;
    lblMaxLines: TLabel;
    edtMaxLines: TEdit;
    lblMaxParams: TLabel;
    edtMaxParams: TEdit;
    lblAntiPatternInfo: TLabel;
    procedure btnEditRulesClick( Sender: TObject );
  private
    FPlugin: TCodeStyleCheckerPlugin;
    procedure UpdateRulesSummary;
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
    UpdateRulesSummary;

end;

procedure TFrameOptionPageCodeStyle.Selected;
begin
end;

procedure TFrameOptionPageCodeStyle.Unselected;
begin
end;

end.
