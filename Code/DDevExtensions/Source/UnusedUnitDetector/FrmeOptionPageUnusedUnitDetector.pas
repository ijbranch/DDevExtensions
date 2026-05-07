{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageUnusedUnitDetector;

/// <summary>
/// IDE Tools options page frame for the Unused Unit Detector plugin. Exposes the
/// Enabled flag and an editable ignore list (one unit name per line).
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FrmeBase, FrmTreePages, UnusedUnitDetector;

type
  /// <summary>Options page frame shown inside the IDE Tools dialog for the Unused Unit Detector plugin.</summary>
  TFrameOptionPageUnusedUnitDetector = class( TFrameBase, ITreePageComponent )
    /// <summary>Toggles whether the plugin is enabled.</summary>
    chkEnabled: TCheckBox;
    /// <summary>Label for the ignore-list memo.</summary>
    lblIgnoreList: TLabel;
    /// <summary>Multi-line editor for the ignore list (one unit name per line).</summary>
    memoIgnoreList: TMemo;
  private
    /// <summary>The plugin instance whose settings are being edited.</summary>
    FPlugin: TUnusedUnitDetectorPlugin;
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
    /// <param name="UserData">The associated <see cref="TUnusedUnitDetectorPlugin"/> instance.</param>
    procedure SetUserData( UserData: TObject );
  end;

implementation

{$R *.dfm}

{ TFrameOptionPageUnusedUnitDetector }

constructor TFrameOptionPageUnusedUnitDetector.Create( AOwner: TComponent );
begin

  inherited Create( AOwner );

end;

procedure TFrameOptionPageUnusedUnitDetector.SetUserData( UserData: TObject );
begin

  FPlugin := UserData as TUnusedUnitDetectorPlugin;

end;

procedure TFrameOptionPageUnusedUnitDetector.LoadData;
begin

  chkEnabled.Checked := FPlugin.Enabled;
  memoIgnoreList.Lines.Assign( FPlugin.IgnoreList );

end;

procedure TFrameOptionPageUnusedUnitDetector.SaveData;
var
  I: Integer;
begin

  FPlugin.Enabled := chkEnabled.Checked;
  FPlugin.IgnoreList.Clear;

  for I := 0 to memoIgnoreList.Lines.Count - 1 do
  begin
    if Trim( memoIgnoreList.Lines[ I ] ) <> '' then
      FPlugin.IgnoreList.Add( Trim( memoIgnoreList.Lines[ I ] ) );
  end;

  FPlugin.Save;

end;

procedure TFrameOptionPageUnusedUnitDetector.Selected;
begin
end;

procedure TFrameOptionPageUnusedUnitDetector.Unselected;
begin
end;

end.
