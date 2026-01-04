{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageEmptyHandler;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FrmTreePages, FrmeBase, ExtCtrls;

type
  TFrameOptionPageEmptyHandler = class(TFrameBase, ITreePageComponent)
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
  EmptyEventHandlerDetector;

{ TFrameOptionPageEmptyHandler }

procedure TFrameOptionPageEmptyHandler.SetUserData(UserData: TObject);
begin
  FPlugin := UserData;
end;

procedure TFrameOptionPageEmptyHandler.LoadData;
begin
  if FPlugin is TEmptyEventHandlerDetectorPlugin then
    chkEnabled.Checked := TEmptyEventHandlerDetectorPlugin(FPlugin).Enabled;
end;

procedure TFrameOptionPageEmptyHandler.SaveData;
begin
  if FPlugin is TEmptyEventHandlerDetectorPlugin then
  begin
    TEmptyEventHandlerDetectorPlugin(FPlugin).Enabled := chkEnabled.Checked;
    TEmptyEventHandlerDetectorPlugin(FPlugin).Save;
  end;
end;

procedure TFrameOptionPageEmptyHandler.Selected;
begin
end;

procedure TFrameOptionPageEmptyHandler.Unselected;
begin
end;

end.
