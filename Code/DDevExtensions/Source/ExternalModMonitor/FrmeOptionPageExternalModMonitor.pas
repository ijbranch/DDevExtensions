{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude Code                                           *}
{*                                                                            *}
{* Options page for External Mod Monitor                                       *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageExternalModMonitor;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FrmTreePages, FrmeBase;

type
  TFrameOptionPageExternalModMonitor = class( TFrameBase, ITreePageComponent )
    cbxActive: TCheckBox;
    lblDebounceMs: TLabel;
    edtDebounceMs: TEdit;
    lblExtensions: TLabel;
    edtExtensions: TEdit;
    cbxShowNotifications: TCheckBox;
    lblProjectLoadGraceMs: TLabel;
    edtProjectLoadGraceMs: TEdit;
    procedure cbxActiveClick( Sender: TObject );
  private
    FConfig: TObject; { TExternalModMonitorConfig - forward avoidance }
  public
    procedure SetUserData( UserData: TObject );
    procedure LoadData;
    procedure SaveData;
    procedure Selected;
    procedure Unselected;
  end;

implementation

uses
  ExternalModMonitor;

{$R *.dfm}

{ TFrameOptionPageExternalModMonitor }

procedure TFrameOptionPageExternalModMonitor.SetUserData( UserData: TObject );
begin

  FConfig := UserData;

end;

procedure TFrameOptionPageExternalModMonitor.LoadData;
begin

  cbxActive.Checked := ( FConfig as TExternalModMonitorConfig ).Active;
  edtDebounceMs.Text := IntToStr( ( FConfig as TExternalModMonitorConfig ).DebounceMs );
  edtExtensions.Text := ( FConfig as TExternalModMonitorConfig ).MonitoredExtensions;
  cbxShowNotifications.Checked := ( FConfig as TExternalModMonitorConfig ).ShowNotifications;
  edtProjectLoadGraceMs.Text := IntToStr( ( FConfig as TExternalModMonitorConfig ).ProjectLoadGraceMs );
  cbxActiveClick( cbxActive );

end;

procedure TFrameOptionPageExternalModMonitor.SaveData;
var
  Val: Integer;
begin

  ( FConfig as TExternalModMonitorConfig ).Active := cbxActive.Checked;

  if TryStrToInt( edtDebounceMs.Text, Val ) and ( Val >= 50 ) then
    ( FConfig as TExternalModMonitorConfig ).DebounceMs := Val
  else
    ( FConfig as TExternalModMonitorConfig ).DebounceMs := 200;

  ( FConfig as TExternalModMonitorConfig ).MonitoredExtensions := edtExtensions.Text;
  ( FConfig as TExternalModMonitorConfig ).ShowNotifications := cbxShowNotifications.Checked;

  if TryStrToInt( edtProjectLoadGraceMs.Text, Val ) and ( Val >= 500 ) then
    ( FConfig as TExternalModMonitorConfig ).ProjectLoadGraceMs := Val
  else
    ( FConfig as TExternalModMonitorConfig ).ProjectLoadGraceMs := 3000;

  ( FConfig as TExternalModMonitorConfig ).Save;

end;

procedure TFrameOptionPageExternalModMonitor.Selected;
begin
end;

procedure TFrameOptionPageExternalModMonitor.Unselected;
begin
end;

procedure TFrameOptionPageExternalModMonitor.cbxActiveClick( Sender: TObject );
begin

  edtDebounceMs.Enabled := cbxActive.Checked;
  edtExtensions.Enabled := cbxActive.Checked;
  lblDebounceMs.Enabled := cbxActive.Checked;
  lblExtensions.Enabled := cbxActive.Checked;
  cbxShowNotifications.Enabled := cbxActive.Checked;
  lblProjectLoadGraceMs.Enabled := cbxActive.Checked;
  edtProjectLoadGraceMs.Enabled := cbxActive.Checked;

end;

end.
