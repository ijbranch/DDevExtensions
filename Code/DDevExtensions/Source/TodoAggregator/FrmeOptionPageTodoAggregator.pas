{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageTodoAggregator;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FrmeBase, FrmTreePages, TodoAggregator;

type
  TFrameOptionPageTodoAggregator = class( TFrameBase, ITreePageComponent )
    chkEnabled: TCheckBox;
    lblPatterns: TLabel;
    edtPatterns: TEdit;
    lblPatternsHint: TLabel;
  private
    FPlugin: TTodoAggregatorPlugin;
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

{ TFrameOptionPageTodoAggregator }

constructor TFrameOptionPageTodoAggregator.Create( AOwner: TComponent );
begin

  inherited Create( AOwner );

end;

procedure TFrameOptionPageTodoAggregator.SetUserData( UserData: TObject );
begin

  FPlugin := UserData as TTodoAggregatorPlugin;

end;

procedure TFrameOptionPageTodoAggregator.LoadData;
begin

  chkEnabled.Checked := FPlugin.Enabled;
  edtPatterns.Text   := FPlugin.Patterns;

end;

procedure TFrameOptionPageTodoAggregator.SaveData;
begin

  FPlugin.Enabled  := chkEnabled.Checked;
  FPlugin.Patterns := Trim( edtPatterns.Text );
  FPlugin.Save;

end;

procedure TFrameOptionPageTodoAggregator.Selected;
begin
end;

procedure TFrameOptionPageTodoAggregator.Unselected;
begin
end;

end.
