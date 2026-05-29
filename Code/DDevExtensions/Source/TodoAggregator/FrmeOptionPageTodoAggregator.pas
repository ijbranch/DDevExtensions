{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageTodoAggregator;

/// <summary>
/// Options-page frame for the TODO/FIXME Aggregator plugin. Lets the user toggle the
/// feature on or off and edit the comma-separated list of comment keywords to scan for.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, FrmeBase, FrmTreePages, TodoAggregator;

type
  /// <summary>
  /// VCL frame hosting the TODO Aggregator options shown in the IDE Options tree.
  /// </summary>
  TFrameOptionPageTodoAggregator = class( TFrameBase, ITreePageComponent )
    /// <summary>Check box bound to TTodoAggregatorPlugin.Enabled.</summary>
    chkEnabled: TCheckBox;
    /// <summary>Label introducing the patterns edit.</summary>
    lblPatterns: TLabel;
    /// <summary>Edit bound to TTodoAggregatorPlugin.Patterns (comma-separated keyword list).</summary>
    edtPatterns: TEdit;
    /// <summary>Hint label describing the patterns edit format.</summary>
    lblPatternsHint: TLabel;
  private
    /// <summary>Plugin object whose configuration this frame edits.</summary>
    FPlugin: TTodoAggregatorPlugin;
  public
    /// <summary>Creates the frame.</summary>
    /// <param name="AOwner">Owning component.</param>
    constructor Create( AOwner: TComponent ); override;

    /// <summary>Copies plugin values into the frame controls.</summary>
    procedure LoadData;
    /// <summary>Reads frame controls back into the plugin and persists.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes visible; no-op.</summary>
    procedure Selected;
    /// <summary>Called when the page is hidden; no-op.</summary>
    procedure Unselected;
    /// <summary>Stores the plugin reference supplied by the framework.</summary>
    /// <param name="UserData">Configuration object (TTodoAggregatorPlugin instance).</param>
    procedure SetUserData( UserData: TObject );
  end;

implementation

{$R *.dfm}

{ TFrameOptionPageTodoAggregator }

constructor TFrameOptionPageTodoAggregator.Create( AOwner: TComponent );
begin

  inherited Create( AOwner );

end;

procedure TFrameOptionPageTodoAggregator.SetUserData( UserData: TObject );
begin

  FPlugin := UserData as TTodoAggregatorPlugin;

end;

procedure TFrameOptionPageTodoAggregator.LoadData;
begin

  chkEnabled.Checked := FPlugin.Enabled;
  edtPatterns.Text   := FPlugin.Patterns;

end;

procedure TFrameOptionPageTodoAggregator.SaveData;
begin

  FPlugin.Enabled  := chkEnabled.Checked;
  FPlugin.Patterns := Trim( edtPatterns.Text );
  FPlugin.Save;

end;

procedure TFrameOptionPageTodoAggregator.Selected;
begin
end;

procedure TFrameOptionPageTodoAggregator.Unselected;
begin
end;

end.
