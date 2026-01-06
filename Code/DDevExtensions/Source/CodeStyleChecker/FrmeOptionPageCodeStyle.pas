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
