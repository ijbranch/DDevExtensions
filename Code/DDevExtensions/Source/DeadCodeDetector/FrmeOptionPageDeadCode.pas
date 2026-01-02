{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageDeadCode;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FrmeBase, FrmTreePages, DeadCodeDetector;

type
  TFrameOptionPageDeadCode = class( TFrameBase, ITreePageComponent )
    chkEnabled: TCheckBox;
    chkCheckProcedures: TCheckBox;
    chkCheckFields: TCheckBox;
    lblIgnoreList: TLabel;
    memoIgnoreList: TMemo;
    lblIgnoreHint: TLabel;
  private
    FPlugin: TDeadCodeDetectorPlugin;
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

{ TFrameOptionPageDeadCode }

constructor TFrameOptionPageDeadCode.Create( AOwner: TComponent );
begin

  inherited Create( AOwner );

end;

procedure TFrameOptionPageDeadCode.SetUserData( UserData: TObject );
begin

  FPlugin := UserData as TDeadCodeDetectorPlugin;

end;

procedure TFrameOptionPageDeadCode.LoadData;
begin

  chkEnabled.Checked         := FPlugin.Enabled;
  chkCheckProcedures.Checked := FPlugin.CheckProcedures;
  chkCheckFields.Checked     := FPlugin.CheckFields;
  memoIgnoreList.Lines.Assign( FPlugin.IgnoreList );

end;

procedure TFrameOptionPageDeadCode.SaveData;
var
  I: Integer;
begin

  FPlugin.Enabled         := chkEnabled.Checked;
  FPlugin.CheckProcedures := chkCheckProcedures.Checked;
  FPlugin.CheckFields     := chkCheckFields.Checked;

  FPlugin.IgnoreList.Clear;

  for I := 0 to memoIgnoreList.Lines.Count - 1 do
  begin
    if Trim( memoIgnoreList.Lines[ I ] ) <> '' then
      FPlugin.IgnoreList.Add( Trim( memoIgnoreList.Lines[ I ] ) );
  end;

  FPlugin.Save;

end;

procedure TFrameOptionPageDeadCode.Selected;
begin
end;

procedure TFrameOptionPageDeadCode.Unselected;
begin
end;

end.
