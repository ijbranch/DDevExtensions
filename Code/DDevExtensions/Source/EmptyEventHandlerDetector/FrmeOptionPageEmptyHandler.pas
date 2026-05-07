{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch                                                        *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageEmptyHandler;

/// <summary>
/// Tree-page options frame for the Empty Event Handler Detector. Presents a single enable toggle
/// and persists it via the underlying plugin.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FrmTreePages, FrmeBase, ExtCtrls;

type
  /// <summary>Options frame for the Empty Event Handler Detector plugin.</summary>
  TFrameOptionPageEmptyHandler = class(TFrameBase, ITreePageComponent)
    /// <summary>Enable toggle for the plugin.</summary>
    chkEnabled: TCheckBox;
    /// <summary>Informational label describing the detector.</summary>
    lblInfo: TLabel;
  private
    /// <summary>Generic reference to the plugin instance (typed at runtime).</summary>
    FPlugin: TObject;
  public
    /// <summary>Captures the plugin instance passed in by the options dialog.</summary>
    /// <param name="UserData">The owning <c>TEmptyEventHandlerDetectorPlugin</c>.</param>
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
  EmptyEventHandlerDetector;

{ TFrameOptionPageEmptyHandler }

procedure TFrameOptionPageEmptyHandler.SetUserData(UserData: TObject);
begin
  FPlugin := UserData;
end;

procedure TFrameOptionPageEmptyHandler.LoadData;
begin
  if FPlugin is TEmptyEventHandlerDetectorPlugin then
    chkEnabled.Checked := TEmptyEventHandlerDetectorPlugin(FPlugin).Enabled;
end;

procedure TFrameOptionPageEmptyHandler.SaveData;
begin
  if FPlugin is TEmptyEventHandlerDetectorPlugin then
  begin
    TEmptyEventHandlerDetectorPlugin(FPlugin).Enabled := chkEnabled.Checked;
    TEmptyEventHandlerDetectorPlugin(FPlugin).Save;
  end;
end;

procedure TFrameOptionPageEmptyHandler.Selected;
begin
end;

procedure TFrameOptionPageEmptyHandler.Unselected;
begin
end;

end.
