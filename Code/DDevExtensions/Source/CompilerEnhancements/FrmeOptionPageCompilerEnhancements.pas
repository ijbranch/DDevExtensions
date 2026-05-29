{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageCompilerEnhancements;

/// <summary>
/// Implements the Compiler Enhancements feature: when active, registers as an
/// ICompileInterceptor so it can rewrite compiler messages, optionally promoting
/// warnings to errors ( with an opt-out list of warning codes ).
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, ToolsAPI, FrmTreePages, FrmOptions, PluginConfig, StdCtrls,
  ModuleData, InterceptIntf, FrmeBase, ExtCtrls;

type
  /// <summary>
  /// Plug-in configuration object that owns the Compiler Enhancements feature and acts as
  /// an ICompileInterceptor when active.
  /// </summary>
  TCompilerEnhancements = class(TPluginConfig, ICompileInterceptor)
  private
    /// <summary>Backing field for Active.</summary>
    FActive: Boolean;
    /// <summary>Backing field for TreatWarningsAsErrors.</summary>
    FTreatWarningsAsErrors: Boolean;
    /// <summary>Backing field for ExceptWarnings.</summary>
    FExceptWarnings: TStrings;
    /// <summary>Identifier returned by the compile-interceptor service registration.</summary>
    FCompileInterceptorId: Integer;
    /// <summary>Setter for ExceptWarnings; assigns the supplied list contents into the existing instance.</summary>
    procedure SetExceptWarnings(const Value: TStrings);
    /// <summary>Setter for Active; registers or unregisters the compile interceptor.</summary>
    procedure SetActive(const Value: Boolean);
  protected
    /// <summary>Returns the options-tree page used to edit this plug-in's settings.</summary>
    function GetOptionPages: TTreePage; override;
    /// <summary>Sets default values when the configuration is first created.</summary>
    procedure Init; override;
    /// <summary>Trims and de-quotes each entry in ExceptWarnings and re-sorts the list.</summary>
    procedure UpdateExceptWarnings;
  public
    /// <summary>Creates the configuration ( Active is set later by the loaded settings ).</summary>
    constructor Create;
    /// <summary>Unregisters the compile interceptor and frees the warning-exception list.</summary>
    destructor Destroy; override;

    /// <summary>ICompileInterceptor: optionally returns altered file content; this plug-in returns nil.</summary>
    function AlterFile(Filename: PAnsiChar; Content: PAnsiChar;
      FileDate: Integer; FileSize: Integer): IVirtualStream; stdcall;
    /// <summary>ICompileInterceptor: promotes warnings to errors when TreatWarningsAsErrors is True and the code is not on the exception list.</summary>
    /// <param name="IsCompilerMessage">True for compiler messages.</param>
    /// <param name="MsgKind">May be changed from mkWarning to mkError.</param>
    /// <param name="Code">Warning code being inspected.</param>
    /// <param name="Filename">File the message refers to.</param>
    /// <param name="Line">1-based line number.</param>
    /// <param name="Column">1-based column number.</param>
    /// <param name="Msg">Message text.</param>
    /// <returns>True when the message has been altered.</returns>
    function AlterMessage(IsCompilerMessage: Boolean; var MsgKind: TMsgKind;
      var Code: Integer; var Filename: string; Line: Integer; Column: Integer;
      var Msg: string): Boolean; stdcall;
    /// <summary>Returns the set of compile-interceptor features required by this plug-in.</summary>
    function GetOptions: TCompileInterceptOptions; stdcall;
    /// <summary>ICompileInterceptor: returns a virtual replacement for Filename, or nil for none.</summary>
    function GetVirtualFile(Filename: PAnsiChar): IVirtualStream; stdcall;
    /// <summary>ICompileInterceptor: file-open / file-close notification ( unused by this plug-in ).</summary>
    procedure InspectFilename(Filename: PAnsiChar; FileMode: TInspectFileMode); stdcall;
  published
    /// <summary>Master switch that enables or disables the compile interceptor.</summary>
    property Active: Boolean read FActive write SetActive;
    /// <summary>When True warnings are reported as errors ( subject to the ExceptWarnings list ).</summary>
    property TreatWarningsAsErrors: Boolean read FTreatWarningsAsErrors write FTreatWarningsAsErrors;
    /// <summary>List of warning codes ( e.g. "W1000" ) that should remain warnings.</summary>
    property ExceptWarnings: TStrings read FExceptWarnings write SetExceptWarnings;
  end;

  /// <summary>
  /// Frame implementing ITreePageComponent for the Compiler Enhancements options page.
  /// </summary>
  TFrameOptionPageCompilerEnhancements = class(TFrameBase, ITreePageComponent)
    /// <summary>Master enable check box.</summary>
    cbxActive: TCheckBox;
    /// <summary>Toggles promotion of warnings to errors.</summary>
    cbxTreatWarningsAsErrors: TCheckBox;
    /// <summary>Memo holding the comma- or line-separated list of warning codes to ignore.</summary>
    mnoExceptWarnings: TMemo;
    /// <summary>Caption label for mnoExceptWarnings.</summary>
    lblExceptWarningsCaption: TLabel;
    /// <summary>Updates the enabled state of dependent controls when cbxActive changes.</summary>
    procedure cbxActiveClick(Sender: TObject);
    /// <summary>Updates the enabled state of mnoExceptWarnings when cbxTreatWarningsAsErrors changes.</summary>
    procedure cbxTreatWarningsAsErrorsClick(Sender: TObject);
  private
    { Private-Deklarationen }
    /// <summary>Configuration instance bound to this frame.</summary>
    FCompilerEnhancements: TCompilerEnhancements;
  public
    { Public-Deklarationen }
    /// <summary>Receives the TCompilerEnhancements instance to edit.</summary>
    /// <param name="UserData">A TCompilerEnhancements instance.</param>
    procedure SetUserData(UserData: TObject);
    /// <summary>Loads configuration values into the visual controls.</summary>
    procedure LoadData;
    /// <summary>Persists values from the visual controls back into the configuration.</summary>
    procedure SaveData;
    /// <summary>Called when the page becomes the selected page.</summary>
    procedure Selected;
    /// <summary>Called when the page is no longer selected.</summary>
    procedure Unselected;
  end;

/// <summary>
/// Initialises or shuts down the Compiler Enhancements plug-in by creating or freeing
/// the global TCompilerEnhancements instance.
/// </summary>
/// <param name="Unload">False to load the plug-in, True to unload it.</param>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  Main, Utils, InterceptLoader;

{$R *.dfm}

var
  CompilerEnhancements: TCompilerEnhancements;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    CompilerEnhancements := TCompilerEnhancements.Create
  else
    FreeAndNil(CompilerEnhancements);
end;

{ TFrameOptionPageCompilerEnhancements }

procedure TFrameOptionPageCompilerEnhancements.cbxActiveClick(Sender: TObject);
begin
  cbxTreatWarningsAsErrors.Enabled := cbxActive.Checked;
  cbxTreatWarningsAsErrors.OnClick(cbxTreatWarningsAsErrors);
end;

procedure TFrameOptionPageCompilerEnhancements.SetUserData(UserData: TObject);
begin
  FCompilerEnhancements := UserData as TCompilerEnhancements;
end;

procedure TFrameOptionPageCompilerEnhancements.cbxTreatWarningsAsErrorsClick(
  Sender: TObject);
begin
  mnoExceptWarnings.Enabled := cbxTreatWarningsAsErrors.Checked and cbxTreatWarningsAsErrors.Enabled;
  lblExceptWarningsCaption.Enabled := mnoExceptWarnings.Enabled;
  if mnoExceptWarnings.Enabled then
    mnoExceptWarnings.Color := clWindow
  else
    mnoExceptWarnings.Color := clBtnFace;
end;

procedure TFrameOptionPageCompilerEnhancements.LoadData;
begin
  cbxActive.Checked := FCompilerEnhancements.Active;
  cbxTreatWarningsAsErrors.Checked := FCompilerEnhancements.TreatWarningsAsErrors;
  mnoExceptWarnings.Lines.Text := FCompilerEnhancements.ExceptWarnings.CommaText;

  cbxActiveClick(cbxActive);
end;

procedure TFrameOptionPageCompilerEnhancements.SaveData;
begin
  FCompilerEnhancements.TreatWarningsAsErrors := cbxTreatWarningsAsErrors.Checked;
  FCompilerEnhancements.ExceptWarnings.CommaText := mnoExceptWarnings.Lines.Text;
  FCompilerEnhancements.UpdateExceptWarnings;

  FCompilerEnhancements.Active := cbxActive.Checked;
  FCompilerEnhancements.Save;
end;

procedure TFrameOptionPageCompilerEnhancements.Selected;
begin
end;

procedure TFrameOptionPageCompilerEnhancements.Unselected;
begin
end;

{ TCompilerEnhancements }

constructor TCompilerEnhancements.Create;
begin
  inherited Create(AppDataDirectory + '\CompilerEnhancements.xml', 'CompilerEnhancements');

end;

destructor TCompilerEnhancements.Destroy;
begin
  Active := False;
  FExceptWarnings.Free;
  inherited Destroy;
end;

procedure TCompilerEnhancements.Init;
begin
  inherited Init;
  TreatWarningsAsErrors := False;
  FExceptWarnings := TStringList.Create;
  TStringList(FExceptWarnings).Sorted := True;
  FExceptWarnings.Clear;
  FExceptWarnings.Add('W1000'); // deprecated
  FExceptWarnings.Add('W1054'); // $MESSAGE WARNING
  Active := False;
end;

function TCompilerEnhancements.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('Compiler Enhancements', TFrameOptionPageCompilerEnhancements, Self);
end;

function TCompilerEnhancements.GetOptions: TCompileInterceptOptions;
begin
  Result := CIO_ALTERMESSAGES;
end;

function TCompilerEnhancements.AlterFile(Filename, Content: PAnsiChar; FileDate,
  FileSize: Integer): IVirtualStream;
begin
  Result := nil;
end;

procedure TCompilerEnhancements.InspectFilename(Filename: PAnsiChar;
  FileMode: TInspectFileMode);
begin
end;

procedure TCompilerEnhancements.SetActive(const Value: Boolean);
begin
  if Value = FActive then
    Exit;

  // GetCompileInterceptorServices raises when the interceptor DLL cannot be
  // loaded (missing, locked, or wrong bitness). Guard the (un)registration so
  // a load failure surfaces a friendly message instead of escaping into the
  // options dialog, and so FActive is only flipped once the call succeeds.
  try
    if Value then
      FCompileInterceptorId := GetCompileInterceptorServices.RegisterInterceptor(Self)
    else
      GetCompileInterceptorServices.UnregisterInterceptor(FCompileInterceptorId);

    FActive := Value;
  except
    on E: Exception do
    begin
      FActive := False;
      if Value then
        ShowMessage('Compiler Enhancements could not be enabled:'#13#10 + E.Message)
      else
        ShowMessage('Compiler Enhancements could not be disabled:'#13#10 + E.Message);
    end;
  end;
end;

procedure TCompilerEnhancements.SetExceptWarnings(const Value: TStrings);
begin
  if Value <> FExceptWarnings then
    FExceptWarnings.Assign(Value);
end;

procedure TCompilerEnhancements.UpdateExceptWarnings;
var
  i: Integer;
begin
  TStringList(ExceptWarnings).Sorted := False;
  for i := 0 to ExceptWarnings.Count - 1 do
    ExceptWarnings[i] := Trim(DequoteStr(ExceptWarnings[i]));
  TStringList(ExceptWarnings).Sorted := True;
end;

function TCompilerEnhancements.GetVirtualFile(Filename: PAnsiChar): IVirtualStream;
begin
  Result := nil;
end;

function TCompilerEnhancements.AlterMessage(IsCompilerMessage: Boolean;
  var MsgKind: TMsgKind; var Code: Integer; var Filename: string; Line,
  Column: Integer; var Msg: string): Boolean;
begin
  Result := False;
  if TreatWarningsAsErrors then
  begin
    // Promote every warning to an error EXCEPT those whose code is listed in
    // ExceptWarnings (the codes the user chose to keep as warnings). An empty
    // list yields IndexOf = -1 for every code, i.e. promote all.
    if (MsgKind = mkWarning) and
       (ExceptWarnings.IndexOf('W' + IntToStr(Code)) = -1) then
    begin
      MsgKind := mkError;
      Result := True;
    end;
  end;
end;

end.
