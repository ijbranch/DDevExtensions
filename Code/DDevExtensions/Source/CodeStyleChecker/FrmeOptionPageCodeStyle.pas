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
  Dialogs, StdCtrls, FrmeBase, FrmTreePages, CodeStyleChecker;

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
  private
    FPlugin: TCodeStyleCheckerPlugin;
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

  chkEnabled.Checked         := FPlugin.Enabled;
  chkCheckTypes.Checked      := FPlugin.CheckTypes;
  chkCheckInterfaces.Checked := FPlugin.CheckInterfaces;
  chkCheckFields.Checked     := FPlugin.CheckFields;
  chkCheckExceptions.Checked := FPlugin.CheckExceptions;
  chkCheckPointers.Checked   := FPlugin.CheckPointers;
  chkCheckParameters.Checked := FPlugin.CheckParameters;

end;

procedure TFrameOptionPageCodeStyle.SaveData;
begin

  FPlugin.Enabled         := chkEnabled.Checked;
  FPlugin.CheckTypes      := chkCheckTypes.Checked;
  FPlugin.CheckInterfaces := chkCheckInterfaces.Checked;
  FPlugin.CheckFields     := chkCheckFields.Checked;
  FPlugin.CheckExceptions := chkCheckExceptions.Checked;
  FPlugin.CheckPointers   := chkCheckPointers.Checked;
  FPlugin.CheckParameters := chkCheckParameters.Checked;
  FPlugin.Save;

end;

procedure TFrameOptionPageCodeStyle.Selected;
begin
end;

procedure TFrameOptionPageCodeStyle.Unselected;
begin
end;

end.
