{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageDeadCode;

/// <summary>
/// IDE Tools options page frame for the Dead Code Detector plugin. Exposes the
/// Enabled flag, the procedure/field checks, and an editable ignore-pattern list.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, FrmeBase, FrmTreePages, DeadCodeDetector;

type
  /// <summary>Options page frame shown inside the IDE Tools dialog for the Dead Code Detector plugin.</summary>
  TFrameOptionPageDeadCode = class( TFrameBase, ITreePageComponent )
    /// <summary>Toggles whether the plugin is enabled.</summary>
    chkEnabled: TCheckBox;
    /// <summary>Toggles whether procedures and functions are inspected.</summary>
    chkCheckProcedures: TCheckBox;
    /// <summary>Toggles whether private/protected fields are inspected.</summary>
    chkCheckFields: TCheckBox;
    /// <summary>Label for the ignore-pattern memo.</summary>
    lblIgnoreList: TLabel;
    /// <summary>Multi-line editor for ignore patterns (one per line; * wildcards supported).</summary>
    memoIgnoreList: TMemo;
    /// <summary>Hint label describing wildcard syntax.</summary>
    lblIgnoreHint: TLabel;
  private
    /// <summary>The plugin instance whose settings are being edited.</summary>
    FPlugin: TDeadCodeDetectorPlugin;
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
    /// <param name="UserData">The associated <see cref="TDeadCodeDetectorPlugin"/> instance.</param>
    procedure SetUserData( UserData: TObject );
  end;

implementation

{$R *.dfm}

{ TFrameOptionPageDeadCode }

constructor TFrameOptionPageDeadCode.Create( AOwner: TComponent );
begin

  inherited Create( AOwner );

end;

procedure TFrameOptionPageDeadCode.SetUserData( UserData: TObject );
begin

  FPlugin := UserData as TDeadCodeDetectorPlugin;

end;

procedure TFrameOptionPageDeadCode.LoadData;
begin

  chkEnabled.Checked         := FPlugin.Enabled;
  chkCheckProcedures.Checked := FPlugin.CheckProcedures;
  chkCheckFields.Checked     := FPlugin.CheckFields;
  memoIgnoreList.Lines.Assign( FPlugin.IgnoreList );

end;

procedure TFrameOptionPageDeadCode.SaveData;
var
  I: Integer;
begin

  FPlugin.Enabled         := chkEnabled.Checked;
  FPlugin.CheckProcedures := chkCheckProcedures.Checked;
  FPlugin.CheckFields     := chkCheckFields.Checked;

  FPlugin.IgnoreList.Clear;

  for I := 0 to memoIgnoreList.Lines.Count - 1 do
  begin
    if Trim( memoIgnoreList.Lines[ I ] ) <> '' then
      FPlugin.IgnoreList.Add( Trim( memoIgnoreList.Lines[ I ] ) );
  end;

  FPlugin.Save;

end;

procedure TFrameOptionPageDeadCode.Selected;
begin
end;

procedure TFrameOptionPageDeadCode.Unselected;
begin
end;

end.
