{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageDfmPas;

/// <summary>
/// Tree-page options frame for the DFM/PAS Consistency plugin. Presents a single enable toggle
/// and persists it via the underlying plugin.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, FrmTreePages, FrmeBase, Vcl.ExtCtrls;

type
  /// <summary>Options frame for the DFM/PAS Consistency plugin.</summary>
  TFrameOptionPageDfmPas = class(TFrameBase, ITreePageComponent)
    /// <summary>Enable toggle for the plugin.</summary>
    chkEnabled: TCheckBox;
    /// <summary>Informational label describing the consistency check.</summary>
    lblInfo: TLabel;
  private
    /// <summary>Generic reference to the plugin instance (typed at runtime).</summary>
    FPlugin: TObject;
  public
    /// <summary>Captures the plugin instance passed in by the options dialog.</summary>
    /// <param name="UserData">The owning <c>TDfmPasConsistencyPlugin</c>.</param>
    procedure SetUserData(UserData: TObject);
    /// <summary>Loads control state from the plugin.</summary>
    procedure LoadData;
    /// <summary>Writes control state back to the plugin and persists it.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes visible (no-op).</summary>
    procedure Selected;
    /// <summary>Called when the page is hidden (no-op).</summary>
    procedure Unselected;
  end;

implementation

{$R *.dfm}

uses
  DfmPasConsistency;

{ TFrameOptionPageDfmPas }

procedure TFrameOptionPageDfmPas.SetUserData(UserData: TObject);
begin
  FPlugin := UserData;
end;

procedure TFrameOptionPageDfmPas.LoadData;
begin
  if FPlugin is TDfmPasConsistencyPlugin then
    chkEnabled.Checked := TDfmPasConsistencyPlugin(FPlugin).Enabled;
end;

procedure TFrameOptionPageDfmPas.SaveData;
begin
  if FPlugin is TDfmPasConsistencyPlugin then
  begin
    TDfmPasConsistencyPlugin(FPlugin).Enabled := chkEnabled.Checked;
    TDfmPasConsistencyPlugin(FPlugin).Save;
  end;
end;

procedure TFrameOptionPageDfmPas.Selected;
begin
end;

procedure TFrameOptionPageDfmPas.Unselected;
begin
end;

end.
