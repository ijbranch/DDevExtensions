{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageUsesClause;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FrmeBase, FrmTreePages, UsesClauseManager;

type
  TFrameOptionPageUsesClause = class( TFrameBase, ITreePageComponent )
    chkEnabled: TCheckBox;
    lblInfo: TLabel;
  private
    FPlugin: TUsesClauseManagerPlugin;
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

{ TFrameOptionPageUsesClause }

constructor TFrameOptionPageUsesClause.Create( AOwner: TComponent );
begin
  inherited Create( AOwner );
end;

procedure TFrameOptionPageUsesClause.SetUserData( UserData: TObject );
begin
  FPlugin := UserData as TUsesClauseManagerPlugin;
end;

procedure TFrameOptionPageUsesClause.LoadData;
begin
  chkEnabled.Checked := FPlugin.Enabled;
end;

procedure TFrameOptionPageUsesClause.SaveData;
begin
  FPlugin.Enabled := chkEnabled.Checked;
  FPlugin.Save;
end;

procedure TFrameOptionPageUsesClause.Selected;
begin
end;

procedure TFrameOptionPageUsesClause.Unselected;
begin
end;

end.
