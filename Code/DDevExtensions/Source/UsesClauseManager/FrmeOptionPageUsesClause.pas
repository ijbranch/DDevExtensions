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

/// <summary>
/// IDE Tools options page frame for the Uses Clause Manager plugin. Exposes the
/// Enabled flag and a brief description label.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, FrmeBase, FrmTreePages, UsesClauseManager;

type
  /// <summary>Options page frame shown inside the IDE Tools dialog for the Uses Clause Manager plugin.</summary>
  TFrameOptionPageUsesClause = class( TFrameBase, ITreePageComponent )
    /// <summary>Toggles whether the plugin is enabled.</summary>
    chkEnabled: TCheckBox;
    /// <summary>Static informational label.</summary>
    lblInfo: TLabel;
  private
    /// <summary>The plugin instance whose settings are being edited.</summary>
    FPlugin: TUsesClauseManagerPlugin;
  public
    /// <summary>Creates the frame; required override of the base constructor.</summary>
    constructor Create( AOwner: TComponent ); override;

    /// <summary>Loads current plugin settings into the frame's controls.</summary>
    procedure LoadData;
    /// <summary>Writes the controls' values back to the plugin and persists them.</summary>
    procedure SaveData;
    /// <summary>Called when this options page becomes visible (no-op).</summary>
    procedure Selected;
    /// <summary>Called when this options page becomes hidden (no-op).</summary>
    procedure Unselected;
    /// <summary>Receives the plugin instance from the options host.</summary>
    /// <param name="UserData">The associated <see cref="TUsesClauseManagerPlugin"/> instance.</param>
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
