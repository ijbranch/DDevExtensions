{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude Code                                           *}
{*                                                                            *}
{* Options page for Method Separators                                         *}
{*                                                                            *}
{* Idea credit: Tulip Method Separators by Samer Assil (MIT licence),         *}
{* https://github.com/SamerAssil/Tulip_Method_Separators                      *}
{* This is an independent implementation; no Tulip source is included.        *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageMethodSeparators;

/// <summary>
/// Options page frame that exposes the Method Separators settings ( the enable check
/// box, which blocks are separated, line style and colour ) inside the DDevExtensions
/// options dialog.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, FrmTreePages, FrmeBase;

type
  /// <summary>
  /// Frame implementing ITreePageComponent for the Method Separators options page.
  /// </summary>
  TFrameOptionPageMethodSeparators = class( TFrameBase, ITreePageComponent )
    /// <summary>Enables or disables the feature; bound to TMethodSeparatorsConfig.Active.</summary>
    cbxActive: TCheckBox;
    /// <summary>Bound to TMethodSeparatorsConfig.ShowTypes.</summary>
    cbxShowTypes: TCheckBox;
    /// <summary>Bound to TMethodSeparatorsConfig.ShowSections.</summary>
    cbxShowSections: TCheckBox;
    /// <summary>Bound to TMethodSeparatorsConfig.ShowInterface.</summary>
    cbxShowInterface: TCheckBox;
    /// <summary>Caption label for cboLineStyle.</summary>
    lblLineStyle: TLabel;
    /// <summary>Line style; item order matches TSeparatorLineStyle.</summary>
    cboLineStyle: TComboBox;
    /// <summary>Bound to TMethodSeparatorsConfig.UseCustomColor.</summary>
    cbxUseCustomColor: TCheckBox;
    /// <summary>Custom separator colour; bound to TMethodSeparatorsConfig.CustomColor.</summary>
    clbCustomColor: TColorBox;
    /// <summary>Explains that an invisible custom colour is replaced by the automatic one.</summary>
    lblColorNote: TLabel;
    /// <summary>Enables or disables dependent controls when a check box changes.</summary>
    /// <param name="Sender">The check box clicked.</param>
    procedure cbxActiveClick( Sender: TObject );
  private
    /// <summary>Configuration instance bound to this frame ( typed as TObject to avoid a circular unit reference ).</summary>
    FConfig: TObject;
  public
    /// <summary>Receives the TMethodSeparatorsConfig instance to edit.</summary>
    /// <param name="UserData">A TMethodSeparatorsConfig instance.</param>
    procedure SetUserData( UserData: TObject );
    /// <summary>Loads configuration values into the visual controls.</summary>
    procedure LoadData;
    /// <summary>Persists values from the visual controls into the configuration and applies them immediately.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes the selected page.</summary>
    procedure Selected;
    /// <summary>Called when the page is no longer selected.</summary>
    procedure Unselected;
  end;

implementation

uses
  MethodSeparators;

{$R *.dfm}

{ TFrameOptionPageMethodSeparators }

procedure TFrameOptionPageMethodSeparators.SetUserData( UserData: TObject );
begin

  FConfig := UserData;

end;

procedure TFrameOptionPageMethodSeparators.LoadData;
var
  Config: TMethodSeparatorsConfig;
begin

  if not ( FConfig is TMethodSeparatorsConfig ) then
    Exit;

  Config := FConfig as TMethodSeparatorsConfig;
  cbxActive.Checked := Config.Active;
  cbxShowTypes.Checked := Config.ShowTypes;
  cbxShowSections.Checked := Config.ShowSections;
  cbxShowInterface.Checked := Config.ShowInterface;
  cboLineStyle.ItemIndex := Ord( Config.LineStyle );
  cbxUseCustomColor.Checked := Config.UseCustomColor;
  clbCustomColor.Selected := Config.CustomColor;
  cbxActiveClick( cbxActive );

end;

procedure TFrameOptionPageMethodSeparators.SaveData;
var
  Config: TMethodSeparatorsConfig;
begin

  if not ( FConfig is TMethodSeparatorsConfig ) then
    Exit;

  Config := FConfig as TMethodSeparatorsConfig;
  Config.Active := cbxActive.Checked;
  Config.ShowTypes := cbxShowTypes.Checked;
  Config.ShowSections := cbxShowSections.Checked;
  Config.ShowInterface := cbxShowInterface.Checked;
  if cboLineStyle.ItemIndex in [Ord( Low( TSeparatorLineStyle ) )..Ord( High( TSeparatorLineStyle ) )] then
    Config.LineStyle := TSeparatorLineStyle( cboLineStyle.ItemIndex );
  Config.UseCustomColor := cbxUseCustomColor.Checked;
  Config.CustomColor := clbCustomColor.Selected;
  Config.Save;
  Config.ApplySettings;

end;

procedure TFrameOptionPageMethodSeparators.Selected;
begin
end;

procedure TFrameOptionPageMethodSeparators.Unselected;
begin
end;

procedure TFrameOptionPageMethodSeparators.cbxActiveClick( Sender: TObject );
begin

  cbxShowTypes.Enabled := cbxActive.Checked;
  cbxShowSections.Enabled := cbxActive.Checked;
  cbxShowInterface.Enabled := cbxActive.Checked;
  lblLineStyle.Enabled := cbxActive.Checked;
  cboLineStyle.Enabled := cbxActive.Checked;
  cbxUseCustomColor.Enabled := cbxActive.Checked;
  clbCustomColor.Enabled := cbxActive.Checked and cbxUseCustomColor.Checked;
  lblColorNote.Enabled := clbCustomColor.Enabled;

end;

end.
