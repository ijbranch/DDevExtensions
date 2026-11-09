{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude Code                                           *}
{*                                                                            *}
{* Options page for Parallel Build All                                        *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageParallelBuild;

/// <summary>
/// Options page frame that exposes the Parallel Build All settings ( the enable check box, the number of
/// projects built at once and the EurekaLog step ) inside the DDevExtensions options dialog.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, FrmTreePages, FrmeBase;

type
  /// <summary>
  /// Frame implementing ITreePageComponent for the Parallel Build All options page.
  /// </summary>
  TFrameOptionPageParallelBuild = class( TFrameBase, ITreePageComponent )
    /// <summary>Enables or disables the feature; bound to TParallelBuildConfig.Active.</summary>
    cbxActive: TCheckBox;
    /// <summary>Caption label for edtMaxWorkers.</summary>
    lblMaxWorkers: TLabel;
    /// <summary>The most projects built at once; bound to TParallelBuildConfig.MaxWorkers ( 0 = automatic ).</summary>
    edtMaxWorkers: TEdit;
    /// <summary>Explains the automatic worker count.</summary>
    lblMaxWorkersNote: TLabel;
    /// <summary>Bound to TParallelBuildConfig.RunEurekaLog.</summary>
    cbxRunEurekaLog: TCheckBox;
    /// <summary>Caption label for edtEcc32Path.</summary>
    lblEcc32Path: TLabel;
    /// <summary>Path of ecc32.exe; bound to TParallelBuildConfig.Ecc32Path ( empty = EurekaLog's default ).</summary>
    edtEcc32Path: TEdit;
    /// <summary>Shows the path used when edtEcc32Path is empty, and whether ecc32.exe is there.</summary>
    lblEcc32Note: TLabel;
    /// <summary>Enables or disables dependent controls when a check box changes.</summary>
    /// <param name="Sender">The check box clicked.</param>
    procedure cbxActiveClick( Sender: TObject );
  private
    /// <summary>Configuration instance bound to this frame ( typed as TObject to avoid a circular unit reference ).</summary>
    FConfig: TObject;
  public
    /// <summary>Receives the TParallelBuildConfig instance to edit.</summary>
    /// <param name="UserData">A TParallelBuildConfig instance.</param>
    procedure SetUserData( UserData: TObject );
    /// <summary>Loads configuration values into the visual controls.</summary>
    procedure LoadData;
    /// <summary>Persists values from the visual controls into the configuration; they apply to the next Build All.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes the selected page.</summary>
    procedure Selected;
    /// <summary>Called when the page is no longer selected.</summary>
    procedure Unselected;
  end;

implementation

uses
  ParallelBuild, ParallelBuildCore;

{$R *.dfm}

{ TFrameOptionPageParallelBuild }

procedure TFrameOptionPageParallelBuild.SetUserData( UserData: TObject );
begin

  FConfig := UserData;

end;

procedure TFrameOptionPageParallelBuild.LoadData;
begin

  if not ( FConfig is TParallelBuildConfig ) then Exit;

  var oConfig := TParallelBuildConfig( FConfig );

  cbxActive.Checked       := oConfig.Active;
  edtMaxWorkers.Text      := IntToStr( oConfig.MaxWorkers );
  cbxRunEurekaLog.Checked := oConfig.RunEurekaLog;
  edtEcc32Path.Text       := oConfig.Ecc32Path;

  var sDefault := oConfig.EffectiveEcc32Path;

  if FileExists( sDefault ) then
    lblEcc32Note.Caption := 'In use: ' + sDefault
  else
    lblEcc32Note.Caption := 'Not found ( the step is skipped ): ' + sDefault;

  cbxActiveClick( cbxActive );

end;

procedure TFrameOptionPageParallelBuild.SaveData;
begin

  if not ( FConfig is TParallelBuildConfig ) then Exit;

  var oConfig := TParallelBuildConfig( FConfig );

  oConfig.Active       := cbxActive.Checked;
  // Anything that is not a number from 0 to the limit means automatic.
  var iWorkers         := StrToIntDef( Trim( edtMaxWorkers.Text ), 0 );

  if ( iWorkers < 0 ) or ( iWorkers > WORKER_LIMIT ) then iWorkers := 0;

  oConfig.MaxWorkers   := iWorkers;
  oConfig.RunEurekaLog := cbxRunEurekaLog.Checked;
  oConfig.Ecc32Path    := Trim( edtEcc32Path.Text );
  oConfig.Save;

end;

procedure TFrameOptionPageParallelBuild.Selected;
begin
end;

procedure TFrameOptionPageParallelBuild.Unselected;
begin
end;

procedure TFrameOptionPageParallelBuild.cbxActiveClick( Sender: TObject );
begin

  var bActive := cbxActive.Checked;

  lblMaxWorkers.Enabled     := bActive;
  edtMaxWorkers.Enabled     := bActive;
  lblMaxWorkersNote.Enabled := bActive;
  cbxRunEurekaLog.Enabled   := bActive;
  lblEcc32Path.Enabled      := bActive and cbxRunEurekaLog.Checked;
  edtEcc32Path.Enabled      := bActive and cbxRunEurekaLog.Checked;
  lblEcc32Note.Enabled      := bActive and cbxRunEurekaLog.Checked;

end;

end.
