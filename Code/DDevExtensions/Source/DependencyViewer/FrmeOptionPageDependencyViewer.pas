{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageDependencyViewer;

/// <summary>
/// IDE Tools options page frame for the Dependency Viewer plugin. Provides editing
/// of the Enabled and RespectConditionals settings and persists them via the plugin.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, FrmeBase, StdCtrls, ExtCtrls,
  Dialogs, FrmTreePages, DependencyViewer;

type
  /// <summary>
  /// Options page frame shown inside the IDE Tools dialog for the Dependency Viewer plugin.
  /// </summary>
  TFrameOptionPageDependencyViewer = class( TFrameBase, ITreePageComponent )
    /// <summary>Toggles whether the plugin is enabled.</summary>
    chkEnabled: TCheckBox;
    /// <summary>Toggles whether $IFDEF/$IF directives are honoured during scanning.</summary>
    chkRespectConditionals: TCheckBox;
  private
    /// <summary>The plugin instance whose settings are being edited.</summary>
    FPlugin: TDependencyViewerPlugin;
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
    /// <param name="UserData">The associated <see cref="TDependencyViewerPlugin"/> instance.</param>
    procedure SetUserData( UserData: TObject );
  end;

implementation

{$R *.dfm}

{ TFrameOptionPageDependencyViewer }

constructor TFrameOptionPageDependencyViewer.Create( AOwner: TComponent );
begin

  inherited Create( AOwner );

end;

procedure TFrameOptionPageDependencyViewer.SetUserData( UserData: TObject );
begin

  FPlugin := UserData as TDependencyViewerPlugin;

end;

procedure TFrameOptionPageDependencyViewer.LoadData;
begin

  chkEnabled.Checked             := FPlugin.Enabled;
  chkRespectConditionals.Checked := FPlugin.RespectConditionals;

end;

procedure TFrameOptionPageDependencyViewer.SaveData;
begin

  FPlugin.Enabled             := chkEnabled.Checked;
  FPlugin.RespectConditionals := chkRespectConditionals.Checked;
  FPlugin.Save;

end;

procedure TFrameOptionPageDependencyViewer.Selected;
begin
end;

procedure TFrameOptionPageDependencyViewer.Unselected;
begin
end;

end.
