{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude Code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageDfmLinkGuard;

/// <summary>Options page of the DFM Link Guard: one switch and what the guard does.</summary>

{$I ..\DelphiExtension.inc}

interface

uses
  System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, FrmTreePages, FrmeBase;

type
  /// <summary>Options frame of the DFM Link Guard.</summary>
  TFrameOptionPageDfmLinkGuard = class( TFrameBase, ITreePageComponent )
    /// <summary>Turns the guard on or off.</summary>
    chkActive: TCheckBox;
    /// <summary>What the guard checks and where its warnings appear.</summary>
    lblInfo: TLabel;
  private
    /// <summary>The <c>TDfmLinkGuardPlugin</c> passed in by the options dialog.</summary>
    FPlugin: TObject;
  public
    /// <summary>Keeps the plug-in the options dialog passes in.</summary>
    /// <param name="UserData">The owning <c>TDfmLinkGuardPlugin</c>.</param>
    procedure SetUserData( UserData: TObject );
    /// <summary>Shows the plug-in's setting.</summary>
    procedure LoadData;
    /// <summary>Writes the setting back to the plug-in and saves it.</summary>
    procedure SaveData;
    /// <summary>Called when the page is shown; nothing to do.</summary>
    procedure Selected;
    /// <summary>Called when the page is hidden; nothing to do.</summary>
    procedure Unselected;
  end;

implementation

{$R *.dfm}

uses
  DfmLinkGuard;

procedure TFrameOptionPageDfmLinkGuard.SetUserData( UserData: TObject );
begin
  FPlugin           := UserData;
end;

procedure TFrameOptionPageDfmLinkGuard.LoadData;
begin
  if FPlugin is TDfmLinkGuardPlugin then
    chkActive.Checked := TDfmLinkGuardPlugin( FPlugin ).Active;
end;

procedure TFrameOptionPageDfmLinkGuard.SaveData;
begin
  if FPlugin is TDfmLinkGuardPlugin then
  begin
    TDfmLinkGuardPlugin( FPlugin ).Active := chkActive.Checked;
    TDfmLinkGuardPlugin( FPlugin ).Save;
  end;
end;

procedure TFrameOptionPageDfmLinkGuard.Selected;
begin
end;

procedure TFrameOptionPageDfmLinkGuard.Unselected;
begin
end;

end.
