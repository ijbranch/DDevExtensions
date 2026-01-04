{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageDfmPas;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FrmTreePages, FrmeBase, ExtCtrls;

type
  TFrameOptionPageDfmPas = class(TFrameBase, ITreePageComponent)
    chkEnabled: TCheckBox;
    lblInfo: TLabel;
  private
    FPlugin: TObject;
  public
    procedure SetUserData(UserData: TObject);
    procedure LoadData;
    procedure SaveData;
    procedure Selected;
    procedure Unselected;
  end;

implementation

{$R *.dfm}

uses
  DfmPasConsistency;

{ TFrameOptionPageDfmPas }

procedure TFrameOptionPageDfmPas.SetUserData(UserData: TObject);
begin
  FPlugin := UserData;
end;

procedure TFrameOptionPageDfmPas.LoadData;
begin
  if FPlugin is TDfmPasConsistencyPlugin then
    chkEnabled.Checked := TDfmPasConsistencyPlugin(FPlugin).Enabled;
end;

procedure TFrameOptionPageDfmPas.SaveData;
begin
  if FPlugin is TDfmPasConsistencyPlugin then
  begin
    TDfmPasConsistencyPlugin(FPlugin).Enabled := chkEnabled.Checked;
    TDfmPasConsistencyPlugin(FPlugin).Save;
  end;
end;

procedure TFrameOptionPageDfmPas.Selected;
begin
end;

procedure TFrameOptionPageDfmPas.Unselected;
begin
end;

end.
