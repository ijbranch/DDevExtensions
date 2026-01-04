{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2025 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageUnreachableCode;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FrmeBase, FrmTreePages, UnreachableCodeDetector;

type
  TFrameOptionPageUnreachableCode = class( TFrameBase, ITreePageComponent )
    chkEnabled: TCheckBox;
    grpDetection: TGroupBox;
    lblDetects: TLabel;
  private
    FPlugin: TUnreachableCodeDetectorPlugin;
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

{ TFrameOptionPageUnreachableCode }

constructor TFrameOptionPageUnreachableCode.Create( AOwner: TComponent );
begin

  inherited Create( AOwner );

end;

procedure TFrameOptionPageUnreachableCode.SetUserData( UserData: TObject );
begin

  FPlugin := UserData as TUnreachableCodeDetectorPlugin;

end;

procedure TFrameOptionPageUnreachableCode.LoadData;
begin

  chkEnabled.Checked := FPlugin.Enabled;

end;

procedure TFrameOptionPageUnreachableCode.SaveData;
begin

  FPlugin.Enabled := chkEnabled.Checked;
  FPlugin.Save;

end;

procedure TFrameOptionPageUnreachableCode.Selected;
begin
end;

procedure TFrameOptionPageUnreachableCode.Unselected;
begin
end;

end.
