{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2024 Andreas Hausladen                                                 *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageDependencyViewer;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, FrmeBase, StdCtrls, ExtCtrls,
  Dialogs, FrmTreePages, DependencyViewer;

type
  TFrameOptionPageDependencyViewer = class(TFrameBase, ITreePageComponent)
    chkEnabled: TCheckBox;
  private
    FPlugin: TDependencyViewerPlugin;
  public
    constructor Create(AOwner: TComponent); override;

    procedure LoadData;
    procedure SaveData;
    procedure Selected;
    procedure Unselected;
    procedure SetUserData(UserData: TObject);
  end;

implementation

{$R *.dfm}

{ TFrameOptionPageDependencyViewer }

constructor TFrameOptionPageDependencyViewer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

procedure TFrameOptionPageDependencyViewer.SetUserData(UserData: TObject);
begin
  FPlugin := UserData as TDependencyViewerPlugin;
end;

procedure TFrameOptionPageDependencyViewer.LoadData;
begin
  chkEnabled.Checked := FPlugin.Enabled;
end;

procedure TFrameOptionPageDependencyViewer.SaveData;
begin
  FPlugin.Enabled := chkEnabled.Checked;
  FPlugin.Save;
end;

procedure TFrameOptionPageDependencyViewer.Selected;
begin
end;

procedure TFrameOptionPageDependencyViewer.Unselected;
begin
end;

end.
