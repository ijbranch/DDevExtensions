{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageDecirculariser;

/// <summary>
/// IDE Tools options page frame for the Decirculariser plugin: the Enabled flag and the
/// number of crossing identifiers at and below which an edge counts as extractable.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, FrmeBase, FrmTreePages, Decirculariser;

type
  /// <summary>Options page frame shown inside the IDE Tools dialog for the Decirculariser plugin.</summary>
  TFrameOptionPageDecirculariser = class( TFrameBase, ITreePageComponent )
    /// <summary>Toggles whether the plugin is enabled.</summary>
    chkEnabled: TCheckBox;
    /// <summary>Label for the threshold edit.</summary>
    lblFewSymbols: TLabel;
    /// <summary>The extractable threshold, a whole number from 1.</summary>
    edtFewSymbols: TEdit;
  private
    /// <summary>The plugin instance whose settings are being edited.</summary>
    FPlugin: TDecirculariserPlugin;
  public
    /// <summary>Loads current plugin settings into the frame's controls.</summary>
    procedure LoadData;
    /// <summary>Writes the controls' values back to the plugin and persists them.</summary>
    procedure SaveData;
    /// <summary>Called when this options page becomes visible (no-op).</summary>
    procedure Selected;
    /// <summary>Called when this options page becomes hidden (no-op).</summary>
    procedure Unselected;
    /// <summary>Receives the plugin instance from the options host.</summary>
    /// <param name="UserData">The associated <see cref="TDecirculariserPlugin"/> instance.</param>
    procedure SetUserData( UserData: TObject );
  end;

implementation

{$R *.dfm}

{ TFrameOptionPageDecirculariser }

procedure TFrameOptionPageDecirculariser.SetUserData( UserData: TObject );
begin
  FPlugin := UserData as TDecirculariserPlugin;
end;

procedure TFrameOptionPageDecirculariser.LoadData;
begin
  chkEnabled.Checked := FPlugin.Enabled;
  edtFewSymbols.Text := IntToStr( FPlugin.FewSymbolsLimit );
end;

procedure TFrameOptionPageDecirculariser.SaveData;
var
  iLimit: Integer;
begin
  FPlugin.Enabled := chkEnabled.Checked;
  { A threshold below 1 would call every edge carrying anything collaboration; keep the old value. }
  if TryStrToInt( Trim( edtFewSymbols.Text ), iLimit ) and ( iLimit >= 1 ) then
    FPlugin.FewSymbolsLimit := iLimit;
  FPlugin.Save;
end;

procedure TFrameOptionPageDecirculariser.Selected;
begin
end;

procedure TFrameOptionPageDecirculariser.Unselected;
begin
end;

end.
