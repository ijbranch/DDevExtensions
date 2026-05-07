{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2025 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageUnreachableCode;

/// <summary>
/// IDE Tools options page frame for the Unreachable Code Detector plugin. Exposes
/// the Enabled flag and a static description of what the detector identifies.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FrmeBase, FrmTreePages, UnreachableCodeDetector;

type
  /// <summary>Options page frame shown inside the IDE Tools dialog for the Unreachable Code Detector plugin.</summary>
  TFrameOptionPageUnreachableCode = class( TFrameBase, ITreePageComponent )
    /// <summary>Toggles whether the plugin is enabled.</summary>
    chkEnabled: TCheckBox;
    /// <summary>Group box framing the description of what the detector identifies.</summary>
    grpDetection: TGroupBox;
    /// <summary>Static description label inside the group box.</summary>
    lblDetects: TLabel;
  private
    /// <summary>The plugin instance whose settings are being edited.</summary>
    FPlugin: TUnreachableCodeDetectorPlugin;
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
    /// <param name="UserData">The associated <see cref="TUnreachableCodeDetectorPlugin"/> instance.</param>
    procedure SetUserData( UserData: TObject );
  end;

implementation

{$R *.dfm}

{ TFrameOptionPageUnreachableCode }

constructor TFrameOptionPageUnreachableCode.Create( AOwner: TComponent );
begin

  inherited Create( AOwner );

end;

procedure TFrameOptionPageUnreachableCode.SetUserData( UserData: TObject );
begin

  FPlugin := UserData as TUnreachableCodeDetectorPlugin;

end;

procedure TFrameOptionPageUnreachableCode.LoadData;
begin

  chkEnabled.Checked := FPlugin.Enabled;

end;

procedure TFrameOptionPageUnreachableCode.SaveData;
begin

  FPlugin.Enabled := chkEnabled.Checked;
  FPlugin.Save;

end;

procedure TFrameOptionPageUnreachableCode.Selected;
begin
end;

procedure TFrameOptionPageUnreachableCode.Unselected;
begin
end;

end.
