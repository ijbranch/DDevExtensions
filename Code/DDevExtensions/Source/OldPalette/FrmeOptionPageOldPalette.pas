{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageOldPalette;

/// <summary>
/// Hosts the Old Palette feature configuration: persistent options, lifecycle of the
/// in-IDE <see cref="TFrameOldPalette"/> band, and the matching IDE options page frame.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, FrmTreePages, PluginConfig, Vcl.ExtCtrls, Vcl.ComCtrls,
  SimpleXmlIntf, FrmeBase;

type
  /// <summary>
  /// Persistent configuration for the Old Palette feature, including band geometry,
  /// tab style, font and behavioural toggles. Owns the lifecycle of the in-IDE band.
  /// </summary>
  TOldPaletteConfig = class(TPluginConfig)
  private
    /// <summary>Whether the Old Palette band is currently shown in the IDE.</summary>
    FActive: Boolean;
    /// <summary>Original ControlBar OnBandMove handler, restored when the feature is disabled.</summary>
    FOrgBandMove: TBandMoveEvent;
    /// <summary>True while the configuration is being loaded from XML.</summary>
    FLoading: Boolean;
    /// <summary>Saved Y coordinate of the band within the ControlBar.</summary>
    FTop: Integer;
    /// <summary>Saved X coordinate of the band within the ControlBar.</summary>
    FLeft: Integer;
    /// <summary>True when the tab control wraps tabs across multiple lines.</summary>
    FMultiLine: Boolean;
    /// <summary>True to allow the last tab row to be uneven.</summary>
    FRaggedRight: Boolean;
    /// <summary>Tab style of the palette tab control.</summary>
    FStyle: TTabStyle;
    /// <summary>True to alphabetise palette pages in the popup menu.</summary>
    FAlphaSortPopupMenu: Boolean;
    /// <summary>True to render tab labels using the legacy "Small Fonts" face.</summary>
    FSmallFonts: Boolean;
    /// <summary>Setter that creates or destroys the in-IDE palette band.</summary>
    procedure SetActive(const Value: Boolean);
    /// <summary>Setter that rebuilds the palette popup menu when the sort option toggles.</summary>
    procedure SetAlphaSortPopupMenu(const Value: Boolean);
  protected
    /// <summary>Hooked OnBandMove constraining the Old Palette band to full ControlBar width.</summary>
    procedure DoBandMove(Sender: TObject; Control: TControl; var ARect: TRect);
    /// <summary>Returns the option page tree node registered for this feature.</summary>
    function GetOptionPages: TTreePage; override;
    /// <summary>Sets default values when no configuration file exists.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the configuration, loading from the standard XML file.</summary>
    constructor Create;
    /// <summary>Disables the band and frees the configuration.</summary>
    destructor Destroy; override;
    /// <summary>Loads values from XML and re-applies the active flag after loading completes.</summary>
    /// <param name="Node">The XML node containing the persisted state.</param>
    procedure LoadFromXml(Node: IXmlNode); override;
  published
    /// <summary>Whether the Old Palette band is shown in the IDE.</summary>
    property Active: Boolean read FActive write SetActive;
    /// <summary>Saved X coordinate of the band.</summary>
    property Left: Integer read FLeft write FLeft;
    /// <summary>Saved Y coordinate of the band.</summary>
    property Top: Integer read FTop write FTop;

    /// <summary>True when the tab control wraps tabs across multiple lines.</summary>
    property MultiLine: Boolean read FMultiLine write FMultiLine;
    /// <summary>True to allow the last tab row to be uneven.</summary>
    property RaggedRight: Boolean read FRaggedRight write FRaggedRight;
    /// <summary>True to alphabetise palette pages in the popup menu.</summary>
    property AlphaSortPopupMenu: Boolean read FAlphaSortPopupMenu write SetAlphaSortPopupMenu;
    /// <summary>True to render tab labels using the legacy "Small Fonts" face.</summary>
    property SmallFonts: Boolean read FSmallFonts write FSmallFonts;
    /// <summary>Tab style of the palette tab control.</summary>
    property Style: TTabStyle read FStyle write FStyle;
  end;

  /// <summary>
  /// IDE options page frame for configuring the Old Palette feature.
  /// </summary>
  TFrameOptionPageOldPalette = class(TFrameBase, ITreePageComponent)
    /// <summary>Toggles the Old Palette feature on or off.</summary>
    cbxActive: TCheckBox;
    /// <summary>Toggles multi-line tabs.</summary>
    cbxMultiline: TCheckBox;
    /// <summary>Toggles ragged-right tab layout.</summary>
    cbxRaggedRight: TCheckBox;
    /// <summary>Selects the tab style (tabs, buttons, flat).</summary>
    cbxStyle: TComboBox;
    /// <summary>Caption for the tab style combo.</summary>
    lblStyleCaption: TLabel;
    /// <summary>Toggles alphabetic sorting of the palette popup.</summary>
    chkAlphaSortPopupMenu: TCheckBox;
    /// <summary>Toggles the legacy "Small Fonts" face for tab labels.</summary>
    chkSmallFonts: TCheckBox;
    /// <summary>Enables or disables dependent controls when the active state changes.</summary>
    /// <param name="Sender">The active checkbox.</param>
    procedure cbxActiveClick(Sender: TObject);
  private
    { Private-Deklarationen }
    /// <summary>Configuration object the page edits.</summary>
    FOldPaletteConfig: TOldPaletteConfig;
  public
    { Public-Deklarationen }
    /// <summary>Receives the <see cref="TOldPaletteConfig"/> instance edited by this page.</summary>
    /// <param name="UserData">The configuration cast to TObject.</param>
    procedure SetUserData(UserData: TObject);
    /// <summary>Populates the controls from the configuration's current values.</summary>
    procedure LoadData;
    /// <summary>Writes the control values back to the configuration and persists them.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes active in the options dialog.</summary>
    procedure Selected;
    /// <summary>Called when the page is deactivated in the options dialog.</summary>
    procedure Unselected;
  end;

/// <summary>Plugin entry point; creates or destroys the singleton configuration.</summary>
/// <param name="Unload">When true, the configuration is freed; otherwise it is created.</param>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  OldPalette, Main, ToolsAPIHelpers;

{$R *.dfm}

var
  OldPaletteConfig: TOldPaletteConfig;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    OldPaletteConfig := TOldPaletteConfig.Create
  else
    FreeAndNil(OldPaletteConfig);
end;

{ TFrameOptionPageOldPalette }

procedure TFrameOptionPageOldPalette.SetUserData(UserData: TObject);
begin
  FOldPaletteConfig := UserData as TOldPaletteConfig;
end;

procedure TFrameOptionPageOldPalette.cbxActiveClick(Sender: TObject);
begin
  inherited;
  cbxMultiline.Enabled := cbxActive.Checked;
  cbxRaggedRight.Enabled := cbxActive.Checked;
  lblStyleCaption.Enabled := cbxActive.Checked;
  chkAlphaSortPopupMenu.Enabled := cbxActive.Checked;
  chkSmallFonts.Enabled := cbxActive.Checked;
  cbxStyle.Enabled := cbxActive.Checked;
end;

procedure TFrameOptionPageOldPalette.LoadData;
begin
  cbxActive.Checked := FOldPaletteConfig.Active;
  cbxMultiline.Checked := FOldPaletteConfig.MultiLine;
  cbxRaggedRight.Checked := FOldPaletteConfig.RaggedRight;
  chkAlphaSortPopupMenu.Checked := FOldPaletteConfig.AlphaSortPopupMenu;
  chkSmallFonts.Checked := FOldPaletteConfig.SmallFonts;
  cbxStyle.ItemIndex := Integer(FOldPaletteConfig.Style);

  cbxActiveClick(cbxActive);
end;

procedure TFrameOptionPageOldPalette.SaveData;
begin
  FOldPaletteConfig.Active := cbxActive.Checked;
  FOldPaletteConfig.MultiLine := cbxMultiline.Checked;
  FOldPaletteConfig.RaggedRight := cbxRaggedRight.Checked;
  FOldPaletteConfig.AlphaSortPopupMenu := chkAlphaSortPopupMenu.Checked;
  FOldPaletteConfig.SmallFonts := chkSmallFonts.Checked;
  if cbxStyle.ItemIndex <> -1 then
    FOldPaletteConfig.Style := TTabStyle(cbxStyle.ItemIndex);
  FOldPaletteConfig.Save;

  if FrameOldPalette <> nil then
    FrameOldPalette.InitTabControl(FOldPaletteConfig);
end;

procedure TFrameOptionPageOldPalette.Selected;
begin
end;

procedure TFrameOptionPageOldPalette.Unselected;
begin
end;

{ TOldPaletteConfig }

constructor TOldPaletteConfig.Create;
begin
  inherited Create(AppDataDirectory + '\OldPalette.xml', 'OldPalette');
end;

destructor TOldPaletteConfig.Destroy;
begin
  Active := False;
  inherited Destroy;
end;

procedure TOldPaletteConfig.DoBandMove(Sender: TObject; Control: TControl; var ARect: TRect);
begin
  if Control = FrameOldPalette then
  begin
    ARect.Right := TControl(Sender).ClientWidth;
    if ARect.Left >= ARect.Right - 10 then
      ARect.Left := ARect.Right - 10;
  end;
  if Assigned(FOrgBandMove) then
    FOrgBandMove(Sender, Control, ARect);
end;

function TOldPaletteConfig.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('Old Palette', TFrameOptionPageOldPalette, Self);
end;

procedure TOldPaletteConfig.Init;
begin
  inherited Init;
  FActive := False;
  FLeft := 0;
  FTop := -1;
  FMultiLine := False;
  FRaggedRight := True;
  FStyle := tsTabs;
  FSmallFonts := False;
end;

procedure TOldPaletteConfig.LoadFromXml(Node: IXmlNode);
begin
  FLoading := True;
  inherited LoadFromXml(Node);
  FLoading := False;
  if Active then
  begin
    FActive := False;
    SetActive(True);
  end;
end;

procedure TOldPaletteConfig.SetActive(const Value: Boolean);
var
  ControlBar: TControlBar;
begin
  if Value <> FActive then
  begin
    FActive := Value;
    if FLoading then
      Exit;
    if Application.MainForm <> nil then
      ControlBar := TControlBar(Application.MainForm.FindComponent('ControlBar1'))
    else
      ControlBar := nil;
    if not Active then
    begin
      if ControlBar <> nil then
        ControlBar.OnBandMove := FOrgBandMove;
      FrameOldPalette.Free;
    end
    else
    begin
      if ControlBar <> nil then
      begin
        FOrgBandMove := ControlBar.OnBandMove;
        ControlBar.OnBandMove := DoBandMove;
        if not Assigned(FrameOldPalette) then
          FrameOldPalette := TFrameOldPalette.Create(Self);
        FrameOldPalette.Left := FLeft;
        if FTop = -1 then
          FTop := ControlBar.RowSize * 3;
        FrameOldPalette.Top := FTop;
        FrameOldPalette.Parent := ControlBar;
        FrameOldPalette.Init(Self);
      end;
    end;
  end;
end;

procedure TOldPaletteConfig.SetAlphaSortPopupMenu(const Value: Boolean);
begin
  if Value <> FAlphaSortPopupMenu then
  begin
    FAlphaSortPopupMenu := Value;
    if FrameOldPalette <> nil then
      FrameOldPalette.RebuildPaletteMenu;
  end;
end;

end.

