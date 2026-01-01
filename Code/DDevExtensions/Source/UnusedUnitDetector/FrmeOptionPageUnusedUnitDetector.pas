{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2024 Andreas Hausladen                                                 *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageUnusedUnitDetector;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FrmeBase, FrmTreePages, UnusedUnitDetector;

type
  TFrameOptionPageUnusedUnitDetector = class( TFrameBase, ITreePageComponent )
    chkEnabled: TCheckBox;
    lblIgnoreList: TLabel;
    memoIgnoreList: TMemo;
    lblDescription: TLabel;
  private
    FPlugin: TUnusedUnitDetectorPlugin;
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

{ TFrameOptionPageUnusedUnitDetector }

constructor TFrameOptionPageUnusedUnitDetector.Create( AOwner: TComponent );
begin

  inherited Create( AOwner );

end;

procedure TFrameOptionPageUnusedUnitDetector.SetUserData( UserData: TObject );
begin

  FPlugin := UserData as TUnusedUnitDetectorPlugin;

end;

procedure TFrameOptionPageUnusedUnitDetector.LoadData;
begin

  chkEnabled.Checked := FPlugin.Enabled;
  memoIgnoreList.Lines.Assign( FPlugin.IgnoreList );

end;

procedure TFrameOptionPageUnusedUnitDetector.SaveData;
var
  I: Integer;
begin

  FPlugin.Enabled := chkEnabled.Checked;
  FPlugin.IgnoreList.Clear;

  for I := 0 to memoIgnoreList.Lines.Count - 1 do
  begin
    if Trim( memoIgnoreList.Lines[ I ] ) <> '' then
      FPlugin.IgnoreList.Add( Trim( memoIgnoreList.Lines[ I ] ) );
  end;

  FPlugin.Save;

end;

procedure TFrameOptionPageUnusedUnitDetector.Selected;
begin
end;

procedure TFrameOptionPageUnusedUnitDetector.Unselected;
begin
end;

end.
