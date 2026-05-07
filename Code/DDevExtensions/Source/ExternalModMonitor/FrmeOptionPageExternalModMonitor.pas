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

/// <summary>
/// Options page frame that exposes the user-configurable settings of the External Mod
/// Monitor plug-in ( active flag, debounce window, monitored extensions, notifications
/// and project-load grace period ) inside the DDevExtensions options dialog.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FrmTreePages, FrmeBase;

type
  /// <summary>
  /// Frame implementing ITreePageComponent for the External Mod Monitor options page.
  /// </summary>
  TFrameOptionPageExternalModMonitor = class( TFrameBase, ITreePageComponent )
    /// <summary>Master enable check box bound to TExternalModMonitorConfig.Active.</summary>
    cbxActive: TCheckBox;
    /// <summary>Caption label for edtDebounceMs.</summary>
    lblDebounceMs: TLabel;
    /// <summary>Edit holding the debounce window in milliseconds ( minimum 50 ).</summary>
    edtDebounceMs: TEdit;
    /// <summary>Caption label for edtExtensions.</summary>
    lblExtensions: TLabel;
    /// <summary>Edit holding the semicolon-separated list of monitored file extensions.</summary>
    edtExtensions: TEdit;
    /// <summary>Bound to TExternalModMonitorConfig.ShowNotifications.</summary>
    cbxShowNotifications: TCheckBox;
    /// <summary>Caption label for edtProjectLoadGraceMs.</summary>
    lblProjectLoadGraceMs: TLabel;
    /// <summary>Edit holding the project-load grace period in milliseconds ( minimum 500 ).</summary>
    edtProjectLoadGraceMs: TEdit;
    /// <summary>Enables or disables dependent controls when the master switch changes.</summary>
    procedure cbxActiveClick( Sender: TObject );
  private
    /// <summary>Configuration instance bound to this frame ( typed as TObject to avoid a circular unit reference ).</summary>
    FConfig: TObject; { TExternalModMonitorConfig - forward avoidance }
  public
    /// <summary>Receives the TExternalModMonitorConfig instance to edit.</summary>
    /// <param name="UserData">A TExternalModMonitorConfig instance.</param>
    procedure SetUserData( UserData: TObject );
    /// <summary>Loads configuration values into the visual controls.</summary>
    procedure LoadData;
    /// <summary>Persists values from the visual controls back into the configuration; falls back to defaults for invalid input.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes the selected page.</summary>
    procedure Selected;
    /// <summary>Called when the page is no longer selected.</summary>
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
