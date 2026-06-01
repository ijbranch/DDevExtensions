{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2007 Andreas Hausladen                                                 *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageFormDesigner;

/// <summary>
/// Configuration class and options-page frame for the Form Designer plug-in. Persists user
/// preferences for the various designer hooks (label margin, ExplicitLeft/Top/Width/Height
/// suppression, PixelsPerInch suppression, TextHeight suppression) and (un)installs the hooks
/// when settings change.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, ToolsAPI, FrmTreePages, PluginConfig, Vcl.StdCtrls,
  ModuleData, FrmeBase, Vcl.ExtCtrls;

type
  /// <summary>
  /// Persistent configuration for the Form Designer hooks. Wraps the boolean flags that
  /// determine which DFM-streaming patches are installed at any moment.
  /// </summary>
  TFormDesigner = class(TPluginConfig)
  private
    /// <summary>Master on/off switch for the entire Form Designer feature set.</summary>
    FActive: Boolean;
    /// <summary>True to default TLabel.Margins.Bottom to zero in the designer.</summary>
    FLabelMargin: Boolean;
    /// <summary>True to suppress streaming of ExplicitLeft/Top/Width/Height to the DFM.</summary>
    FRemoveExplicitProperty: Boolean;
    /// <summary>True to suppress streaming of TDataModule.PixelsPerInch.</summary>
    FRemovePixelsPerInchProperty: Boolean;
    /// <summary>True to suppress streaming of TCustomForm.TextHeight (Delphi 11+).</summary>
    FRemoveTextHeightProperty: Boolean;
    /// <summary>Updates FActive and refreshes the installed hooks.</summary>
    procedure SetActive(const Value: Boolean);
    /// <summary>Updates FLabelMargin and refreshes hooks if the feature is active.</summary>
    procedure SetLabelMargin(const Value: Boolean);
    /// <summary>Updates FRemoveExplicitProperty and refreshes hooks if the feature is active.</summary>
    procedure SetRemoveExplicitProperty(const Value: Boolean);
    /// <summary>Updates FRemovePixelsPerInchProperty and refreshes hooks if the feature is active.</summary>
    procedure SetRemovePixelsPerInchProperty(const Value: Boolean);
    /// <summary>Updates FRemoveTextHeightProperty and refreshes hooks if the feature is active.</summary>
    procedure SetRemoveTextHeightProperty(const Value: Boolean);
  protected
    /// <summary>Returns the option-page descriptor that the IDE should display for this plug-in.</summary>
    /// <returns>A new TTreePage owned by the caller.</returns>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises the configuration values to their factory defaults.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the configuration and loads it from FormDesigner.xml in the app data directory.</summary>
    constructor Create;
    /// <summary>Deactivates the feature (removes hooks) and frees the instance.</summary>
    destructor Destroy; override;
    /// <summary>Installs or removes each individual designer hook to match the current settings.</summary>
    procedure UpdateHooks;
  published
    /// <summary>Master on/off switch that gates every other Form Designer option.</summary>
    property Active: Boolean read FActive write SetActive;
    /// <summary>Enables the TLabel bottom-margin override.</summary>
    property LabelMargin: Boolean read FLabelMargin write SetLabelMargin;
    /// <summary>Enables suppression of the ExplicitLeft/Top/Width/Height DFM properties.</summary>
    property RemoveExplicitProperty: Boolean read FRemoveExplicitProperty write SetRemoveExplicitProperty;
    /// <summary>Enables suppression of TDataModule.PixelsPerInch in the DFM.</summary>
    property RemovePixelsPerInchProperty: Boolean read FRemovePixelsPerInchProperty write SetRemovePixelsPerInchProperty;
    /// <summary>Enables suppression of TCustomForm.TextHeight in the DFM (Delphi 11+).</summary>
    property RemoveTextHeightProperty: Boolean read FRemoveTextHeightProperty write SetRemoveTextHeightProperty;
  end;

  /// <summary>
  /// Designer frame providing the user interface for the Form Designer options page hosted in
  /// the IDE's Tools > Options dialog.
  /// </summary>
  TFrameOptionPageFormDesigner = class(TFrameBase, ITreePageComponent)
    /// <summary>Master on/off check box.</summary>
    cbxActive: TCheckBox;
    /// <summary>Toggle for the TLabel margin override.</summary>
    cbxLabelMargin: TCheckBox;
    /// <summary>Toggle for the ExplicitLeft/Top/Width/Height removal.</summary>
    chkRemoveExplicitProperties: TCheckBox;
    /// <summary>Toggle for the PixelsPerInch removal.</summary>
    chkRemovePixelsPerInchProperty: TCheckBox;
    /// <summary>Toggle for the TextHeight removal (Delphi 11+).</summary>
    chkRemoveTextHeightProperty: TCheckBox;
    /// <summary>Re-evaluates the enabled state of dependent check boxes when Active changes.</summary>
    procedure cbxActiveClick(Sender: TObject);
  private
    { Private-Deklarationen }
    /// <summary>Configuration object passed in via SetUserData.</summary>
    FFormDesigner: TFormDesigner;
  public
    { Public-Deklarationen }
    /// <summary>Constructs the frame and disables version-restricted check boxes.</summary>
    constructor Create(AOwner: TComponent); override;
    /// <summary>Receives the TFormDesigner configuration object that backs this page.</summary>
    /// <param name="UserData">Must be a TFormDesigner instance.</param>
    procedure SetUserData(UserData: TObject);
    /// <summary>Copies current configuration values into the controls.</summary>
    procedure LoadData;
    /// <summary>Persists control values back into the configuration object and saves to disk.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes visible. No-op.</summary>
    procedure Selected;
    /// <summary>Called when the page is hidden. No-op.</summary>
    procedure Unselected;
  end;

{$IFDEF INCLUDE_FORMDESIGNER}

/// <summary>
/// Plug-in entry point. Creates the global TFormDesigner instance on load and frees it on unload.
/// </summary>
/// <param name="Unload">False during initialisation, True during plug-in shutdown.</param>
procedure InitPlugin(Unload: Boolean);

{$ENDIF INCLUDE_FORMDESIGNER}

implementation

uses
  Main, LabelMarginHelper,
{$IFDEF COMPILER110_UP}
  RemovePixelsPerInchProperty,
{$ENDIF COMPILER110_UP}
  RemoveExplicitProperty,
  RemoveTextHeightProperty;

{$R *.dfm}

{$IFDEF INCLUDE_FORMDESIGNER}

var
  FormDesigner: TFormDesigner;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    FormDesigner := TFormDesigner.Create
  else
    FreeAndNil(FormDesigner);
end;

{$ENDIF INCLUDE_FORMDESIGNER}

{ TFrameOptionPageFormDesigner }

constructor TFrameOptionPageFormDesigner.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  {$IFNDEF DELPHI28_UP}
  chkRemoveTextHeightProperty.Enabled := False;
  {$ENDIF}
  // The three DFM cleaners now install via InstallFullReplaceHook, which uses an
  // x64-safe 14-byte absolute-jump redirect (see Shared\Hooking.pas), so they
  // function on both the 32- and 64-bit IDE and the controls stay enabled.
end;

procedure TFrameOptionPageFormDesigner.cbxActiveClick(Sender: TObject);
begin
  cbxLabelMargin.Enabled := cbxActive.Checked;
  // Every dependent box's Enabled state follows Active (and its compiler-version
  // availability). The x64-safe redirect means this is identical on Win32 and Win64.
  {$IFDEF COMPILER110_UP}
  chkRemoveExplicitProperties.Enabled := cbxActive.Checked;
  chkRemovePixelsPerInchProperty.Enabled := cbxActive.Checked;
  {$ELSE}
  chkRemoveExplicitProperties.Enabled := False;
  chkRemovePixelsPerInchProperty.Enabled := False;
  {$ENDIF COMPILER110_UP}
  {$IFDEF DELPHI28_UP}
  chkRemoveTextHeightProperty.Enabled := cbxActive.Checked;
  {$ELSE}
  chkRemoveTextHeightProperty.Enabled := False;
  {$ENDIF}
end;

procedure TFrameOptionPageFormDesigner.SetUserData(UserData: TObject);
begin
  FFormDesigner := UserData as TFormDesigner;
end;

procedure TFrameOptionPageFormDesigner.LoadData;
begin
  cbxActive.Checked := FFormDesigner.Active;
  cbxLabelMargin.Checked := FFormDesigner.LabelMargin;
  chkRemoveExplicitProperties.Checked := FFormDesigner.RemoveExplicitProperty;
  chkRemovePixelsPerInchProperty.Checked := FFormDesigner.RemovePixelsPerInchProperty;
  chkRemoveTextHeightProperty.Checked := FFormDesigner.RemoveTextHeightProperty;
  // cbxActiveClick synchronises every dependent check box's Enabled state.
  cbxActiveClick(cbxActive);
end;

procedure TFrameOptionPageFormDesigner.SaveData;
begin
  FFormDesigner.LabelMargin := cbxLabelMargin.Checked;
  FFormDesigner.RemoveExplicitProperty := chkRemoveExplicitProperties.Checked;
  FFormDesigner.RemovePixelsPerInchProperty := chkRemovePixelsPerInchProperty.Checked;
  FFormDesigner.RemoveTextHeightProperty := chkRemoveTextHeightProperty.Checked;

  FFormDesigner.Active := cbxActive.Checked;
  FFormDesigner.Save;
end;

procedure TFrameOptionPageFormDesigner.Selected;
begin
end;

procedure TFrameOptionPageFormDesigner.Unselected;
begin
end;

{ TFormDesigner }

constructor TFormDesigner.Create;
begin
  inherited Create(AppDataDirectory + '\FormDesigner.xml', 'FormDesigner');
end;

destructor TFormDesigner.Destroy;
begin
  Active := False;
  inherited Destroy;
end;

procedure TFormDesigner.Init;
begin
  inherited Init;
  LabelMargin := True;
  RemoveExplicitProperty := False;
  RemovePixelsPerInchProperty := False;
  RemoveTextHeightProperty := False;
  Active := True;
end;

procedure TFormDesigner.SetActive(const Value: Boolean);
begin
  if Value <> FActive then
  begin
    FActive := Value;
    UpdateHooks;
  end;
end;

procedure TFormDesigner.SetLabelMargin(const Value: Boolean);
begin
  if Value <> FLabelMargin then
  begin
    FLabelMargin := Value;
    if Active then
      UpdateHooks;
  end;
end;

procedure TFormDesigner.SetRemoveExplicitProperty(const Value: Boolean);
begin
  if Value <> FRemoveExplicitProperty then
  begin
    FRemoveExplicitProperty := Value;
    if Active then
      UpdateHooks;
  end;
end;

procedure TFormDesigner.SetRemovePixelsPerInchProperty(const Value: Boolean);
begin
  if Value <> FRemovePixelsPerInchProperty then
  begin
    FRemovePixelsPerInchProperty := Value;
    if Active then
      UpdateHooks;
  end;
end;

procedure TFormDesigner.SetRemoveTextHeightProperty(const Value: Boolean);
begin
  if Value <> FRemoveTextHeightProperty then
  begin
    FRemoveTextHeightProperty := Value;
    if Active then
      UpdateHooks;
  end;
end;

procedure TFormDesigner.UpdateHooks;
begin
  {$IFDEF INCLUDE_FORMDESIGNER}
  SetLabelMarginActive(Active and LabelMargin);
  // RemoveExplicit / PixelsPerInch / TextHeight install via InstallFullReplaceHook,
  // which redirects with an x64-safe absolute jump, so they apply on both Win32 and Win64.
  SetRemoveExplicitPropertyActive(Active and RemoveExplicitProperty);
  {$IFDEF COMPILER110_UP}
  SetRemovePixelsPerInchPropertyActive(Active and RemovePixelsPerInchProperty);
  {$ENDIF COMPILER110_UP}
  {$IFDEF DELPHI28_UP}
  SetRemoveTextHeightPropertyActive(Active and RemoveTextHeightProperty);
  {$ENDIF}
  {$ENDIF INCLUDE_FORMDESIGNER}
end;

function TFormDesigner.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('Form Designer', TFrameOptionPageFormDesigner, Self);
end;

end.
