{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit NativeProgressForm;

/// <summary>
/// Wraps the IDE's native compile-progress dialog ( TProgressForm in coreide ) and adds a
/// real progress bar plus Windows 7+ taskbar progress integration. Exposes the dialog's
/// labels via strongly typed properties so other plug-in code can read or update them
/// without touching the IDE internals directly.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, TaskbarIntf;

type
  /// <summary>
  /// Companion component for the IDE's native compile-progress form. Owns the injected
  /// progress bar and keeps the Windows taskbar progress state in sync with the build.
  /// </summary>
  TNativeProgressForm = class(TComponent)
  private
    /// <summary>Maximum number of files expected to be compiled.</summary>
    FMaxFiles: Integer;
    /// <summary>Files compiled so far for the current project; -1 indicates "use FilesCompiled instead".</summary>
    FProjectFilesCompiled: Integer;
    /// <summary>Cached state of the auto-close check box.</summary>
    FCachedAutoClose: Boolean;
    /// <summary>Last percentage written to the progress bar; used to skip redundant updates.</summary>
    FLastPercentage: Integer;
    /// <summary>Injected progress bar control parented onto the IDE progress form.</summary>
    FProgressBar: TProgressBar;
    /// <summary>Windows shell taskbar interface ( base ).</summary>
    FTaskbarList: ITaskbarList;
    /// <summary>Windows 7+ taskbar interface used for progress notifications.</summary>
    FTaskbarList3: ITaskbarList3;
    /// <summary>Reads the "current file" label on the IDE progress form.</summary>
    function GetCurrFile: string;
    /// <summary>Reads the "current lines" label on the IDE progress form.</summary>
    function GetCurrLines: LongWord;
    /// <summary>Reads the "hint count" label on the IDE progress form.</summary>
    function GetHintCount: Integer;
    /// <summary>Reads the "main file" label on the IDE progress form.</summary>
    function GetMainFile: string;
    /// <summary>Reads the "status" label on the IDE progress form.</summary>
    function GetStatus: string;
    /// <summary>Reads the "total lines" label on the IDE progress form.</summary>
    function GetTotalLines: LongWord;
    /// <summary>Reads the "error count" label on the IDE progress form.</summary>
    function GetErrorCount: Integer;
    /// <summary>Reads the "warning count" label on the IDE progress form.</summary>
    function GetWarningCount: Integer;
    /// <summary>Writes the "current file" label.</summary>
    procedure SetCurrFile(const Value: string);
    /// <summary>Writes the "current lines" label.</summary>
    procedure SetCurrLines(const Value: LongWord);
    /// <summary>Writes the "error count" label.</summary>
    procedure SetErrorCount(const Value: Integer);
    /// <summary>Writes the "hint count" label.</summary>
    procedure SetHintCount(const Value: Integer);
    /// <summary>Writes the "main file" label.</summary>
    procedure SetMainFile(const Value: string);
    /// <summary>Writes the "status" label.</summary>
    procedure SetStatus(const Value: string);
    /// <summary>Writes the "total lines" label.</summary>
    procedure SetTotalLines(const Value: LongWord);
    /// <summary>Writes the "warning count" label.</summary>
    procedure SetWarningCount(const Value: Integer);
    /// <summary>Adds or removes an overlay panel that overrides the status text on the IDE progress form.</summary>
    procedure SetStatusOverwrite(const Value: string);
    /// <summary>Reads the value of the injected files-compiled label.</summary>
    function GetFilesCompiled: Integer;
    /// <summary>Updates the injected files-compiled label and refreshes the progress bar.</summary>
    procedure SetFilesCompiled(const Value: Integer);
    /// <summary>Sets the maximum file count and creates / repositions the progress bar.</summary>
    procedure SetMaxFiles(const Value: Integer);
    /// <summary>Sets the count of project files compiled and refreshes the progress bar.</summary>
    procedure SetProjectFilesCompiled(const Value: Integer);
  protected
    /// <summary>Returns the window handle to use for taskbar progress notifications.</summary>
    function GetTaskbarFormHandle: HWND;
    /// <summary>Pushes the current progress and state to the Windows taskbar.</summary>
    procedure UpdateTaskbarProgress;

    /// <summary>Returns the IDE's compile progress form, or nil when it is not available.</summary>
    function GetForm: TCustomForm;
    /// <summary>Looks up a TLabel control on the IDE progress form by component name.</summary>
    /// <param name="Name">Component name.</param>
    function GetLabel(const Name: string): TLabel;
    /// <summary>Looks up a TCheckBox control on the IDE progress form by component name.</summary>
    /// <param name="Name">Component name.</param>
    function GetCheckBox(const Name: string): TCheckBox;
    /// <summary>Sets a label caption by component name.</summary>
    procedure SetString(const Name, Value: string);
    /// <summary>Sets a label caption to the textual form of an integer.</summary>
    procedure SetInteger(const Name: string; Value: Integer);
    /// <summary>Sets a label caption to the textual form of an unsigned long.</summary>
    procedure SetLongWord(const Name: string; Value: LongWord);

    /// <summary>Returns a label caption by component name, or empty string when not found.</summary>
    function GetString(const Name: string): string;
    /// <summary>Reads a label caption and converts it to an integer ( 0 on failure ).</summary>
    function GetInteger(const Name: string): Integer;
    /// <summary>Reads a label caption and converts it to a LongWord ( 0 on failure ).</summary>
    function GetLongWord(const Name: string): LongWord;

    /// <summary>Click handler for the auto-close check box on the IDE progress form.</summary>
    procedure DoAutoCloseClick(Sender: TObject);
    /// <summary>Detects when the injected progress bar is being destroyed.</summary>
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    /// <summary>Creates the wrapper and probes for Windows 7+ taskbar support.</summary>
    constructor Create; reintroduce;
    /// <summary>Releases the progress bar and clears taskbar progress state.</summary>
    destructor Destroy; override;
    /// <summary>Forces the IDE message loop to process pending paints.</summary>
    procedure UpdateForm;
    /// <summary>Clicks the Cancel button on the IDE progress form, if present.</summary>
    procedure Cancel;
    /// <summary>Shows or hides the injected progress bar.</summary>
    /// <param name="AShow">True to show, False to hide.</param>
    procedure ShowProgressBar(AShow: Boolean);

    /// <summary>The underlying IDE progress form ( may be nil ).</summary>
    property Form: TCustomForm read GetForm;
    /// <summary>Write-only accessor for the status overwrite panel.</summary>
    property StatusOverwrite: string write SetStatusOverwrite;
    /// <summary>Number of files compiled so far ( injected label ).</summary>
    property FilesCompiled: Integer read GetFilesCompiled write SetFilesCompiled;
    /// <summary>Number of project files compiled so far for the current project.</summary>
    property ProjectFilesCompiled: Integer read FProjectFilesCompiled write SetProjectFilesCompiled;
    /// <summary>Total number of files expected to be compiled.</summary>
    property MaxFiles: Integer read FMaxFiles write SetMaxFiles;

    /// <summary>"Status" label on the IDE progress form.</summary>
    property Status: string read GetStatus write SetStatus;
    /// <summary>"Main file" label on the IDE progress form.</summary>
    property MainFile: string read GetMainFile write SetMainFile;
    /// <summary>"Current file" label on the IDE progress form.</summary>
    property CurrFile: string read GetCurrFile write SetCurrFile;
    /// <summary>"Current lines" label on the IDE progress form.</summary>
    property CurrLines: LongWord read GetCurrLines write SetCurrLines;
    /// <summary>"Total lines" label on the IDE progress form.</summary>
    property TotalLines: LongWord read GetTotalLines write SetTotalLines;
    /// <summary>"Hint count" label on the IDE progress form.</summary>
    property HintCount: Integer read GetHintCount write SetHintCount;
    /// <summary>"Warning count" label on the IDE progress form.</summary>
    property WarningCount: Integer read GetWarningCount write SetWarningCount;
    /// <summary>"Error count" label on the IDE progress form.</summary>
    property ErrorCount: Integer read GetErrorCount write SetErrorCount;
  end;

var
  /// <summary>Global wrapper instance owned by the CompileProgress plug-in.</summary>
  FormNativeProgress: TNativeProgressForm;

implementation

uses
  Vcl.Themes, AppConsts, Hooking, IDEHooks
  {$IFDEF CPUX64}, Main {$ENDIF};

const
  {$IF CompilerVersion >= 21.0} // Delphi 2010+
  sCurrFileLabelName = 'FileName';
  {$ELSE}
  sCurrFileLabelName = 'CurrFile';
  {$IFEND}

procedure ProgressFormPtr;
  external coreide_bpl name '@Comprgrs@ProgressForm' {$IFDEF WIN64} delayed {$ENDIF};

var
  ProgressFormP: ^TForm;

{ TNativeProgressForm }

constructor TNativeProgressForm.Create;
begin
  inherited Create(nil);
  FProjectFilesCompiled := -1;

  if CheckWin32Version(6, 1) then
  begin
    try
      FTaskbarList := CreateTaskbarList;
      if not Supports(FTaskbarList, IID_ITaskbarList3, FTaskbarList3) then
        FTaskbarList3 := nil;
    except
      FTaskbarList := nil;
      FTaskbarList3 := nil;
    end;
  end;
end;

destructor TNativeProgressForm.Destroy;
begin
  {$IFDEF CPUX64}
  // Win64 shutdown: each step is independently swallowed + logged so that one
  // failure (typically a partially-torn-down coreide_bpl dereference) doesn't
  // abort the rest of the destructor.
  //
  // The first three setters (StatusOverwrite, FilesCompiled, MaxFiles) all
  // route through GetForm/ProgressFormP^ which dereferences a stale coreide_bpl
  // global on shutdown — they're skipped entirely below since "tidying" the
  // IDE's UI while the IDE is exiting is pointless.
  try FreeAndNil(FProgressBar);   except on E: Exception do LogWin64UnloadStep('TNativeProgressForm.FProgressBar.Free', E); end;
  try UpdateTaskbarProgress;      except on E: Exception do LogWin64UnloadStep('TNativeProgressForm.UpdateTaskbarProgress', E); end;
  try FTaskbarList3 := nil;       except on E: Exception do LogWin64UnloadStep('TNativeProgressForm.FTaskbarList3:=nil', E); end;
  try FTaskbarList := nil;        except on E: Exception do LogWin64UnloadStep('TNativeProgressForm.FTaskbarList:=nil', E); end;
  try inherited Destroy;          except on E: Exception do LogWin64UnloadStep('TNativeProgressForm.inherited Destroy', E); end;
  {$ELSE}
  StatusOverwrite := '';
  FilesCompiled := 0;
  MaxFiles := 0;
  FreeAndNil(FProgressBar);
  UpdateTaskbarProgress;
  FTaskbarList3 := nil;
  FTaskbarList := nil;
  inherited Destroy;
  {$ENDIF}
end;

function TNativeProgressForm.GetForm: TCustomForm;
begin
  if ProgressFormP = nil then
    ProgressFormP := GetActualAddr(@ProgressFormPtr);
  Result := ProgressFormP^;
end;

procedure TNativeProgressForm.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FProgressBar then
    begin
      FProgressBar := nil;
      UpdateTaskbarProgress;
    end;
  end;
end;

procedure TNativeProgressForm.Cancel;
var
  Form: TCustomForm;
  Btn: TButton;
begin
  Form := GetForm;
  if Form <> nil then
  begin
    Btn := TButton(Form.FindComponent('CancelButton'));
    if TComponent(Btn) is TButton then
      Btn.Click;
  end;
end;

function TNativeProgressForm.GetLabel(const Name: string): TLabel;
var
  Form: TCustomForm;
begin
  Result := nil;
  Form := GetForm;
  if Form <> nil then
  begin
    Result := TLabel(Form.FindComponent(Name));
    if not (TComponent(Result) is TLabel) then
      Result := nil;
  end;
end;

function TNativeProgressForm.GetCheckBox(const Name: string): TCheckBox;
var
  Form: TCustomForm;
begin
  Result := nil;
  Form := GetForm;
  if Form <> nil then
  begin
    Result := TCheckBox(Form.FindComponent(Name));
    if not (TComponent(Result) is TCheckBox) then
      Result := nil;
  end;
end;

procedure TNativeProgressForm.SetString(const Name, Value: string);
var
  Lbl: TLabel;
begin
  Lbl := GetLabel(Name);
  if Assigned(Lbl) then
    Lbl.Caption := Value;
end;

procedure TNativeProgressForm.SetInteger(const Name: string; Value: Integer);
begin
  SetString(Name, IntToStr(Value));
end;

procedure TNativeProgressForm.SetLongWord(const Name: string; Value: LongWord);
begin
  SetString(Name, IntToStr(Value));
end;

function TNativeProgressForm.GetString(const Name: string): string;
var
  Lbl: TLabel;
begin
  Lbl := GetLabel(Name);
  if Assigned(Lbl) then
    Result := Lbl.Caption
  else
    Result := '';
end;

function TNativeProgressForm.GetInteger(const Name: string): Integer;
var
  Code: Integer;
begin
  Val(GetString(Name), Result, Code);
  if Code <> 0 then
    Result := 0;
end;

function TNativeProgressForm.GetLongWord(const Name: string): LongWord;
var
  Code: Integer;
begin
  Val(GetString(Name), Result, Code);
  if Code <> 0 then
    Result := 0;
end;

function TNativeProgressForm.GetCurrFile: string;
begin
  Result := GetString(sCurrFileLabelName);
end;

function TNativeProgressForm.GetCurrLines: LongWord;
begin
  Result := GetLongWord('CurrLines');
end;

function TNativeProgressForm.GetErrorCount: Integer;
begin
  Result := GetInteger('ErrorCount');
end;

function TNativeProgressForm.GetHintCount: Integer;
begin
  Result := GetInteger('HintCount');
end;

function TNativeProgressForm.GetMainFile: string;
begin
  Result := GetString('MainFile');
end;

function TNativeProgressForm.GetStatus: string;
begin
  Result := GetString('Status');
end;

function TNativeProgressForm.GetTotalLines: LongWord;
begin
  Result := GetLongWord('TotalLines');
end;

function TNativeProgressForm.GetWarningCount: Integer;
begin
  Result := GetInteger('WarningCount');
end;

procedure TNativeProgressForm.SetCurrFile(const Value: string);
begin
  SetString(sCurrFileLabelName, Value);
end;

procedure TNativeProgressForm.SetCurrLines(const Value: LongWord);
begin
  SetLongWord('CurrLines', Value);
end;

procedure TNativeProgressForm.SetErrorCount(const Value: Integer);
begin
  SetInteger('ErrorCount', Value);
end;

procedure TNativeProgressForm.SetHintCount(const Value: Integer);
begin
  SetInteger('HintCount', Value);
end;

procedure TNativeProgressForm.SetMainFile(const Value: string);
begin
  SetString('MainFile', Value);
end;

procedure TNativeProgressForm.SetStatus(const Value: string);
begin
  SetString('Status', Value);
end;

procedure TNativeProgressForm.SetTotalLines(const Value: LongWord);
begin
  SetLongWord('TotalLines', Value);
end;

procedure TNativeProgressForm.SetWarningCount(const Value: Integer);
begin
  SetInteger('WarningCount', Value);
end;

procedure TNativeProgressForm.ShowProgressBar(AShow: Boolean);
begin
  if FProgressBar <> nil then
  begin
    if AShow <> FProgressBar.Visible then
      FProgressBar.Visible := AShow;
    UpdateTaskbarProgress;
  end;
end;

procedure TNativeProgressForm.UpdateForm;
begin
  Application.ProcessMessages;
end;

procedure TNativeProgressForm.SetStatusOverwrite(const Value: string);
var
  Form: TCustomForm;
  Panel: TPanel;
  LblCurrFile, LblStatus: TLabel;
begin
  Form := GetForm;
  if Form <> nil then
  begin
    Panel := Form.FindComponent('bcc32pch_StatusOverwrite') as TPanel;
    if (Value = '') then
    begin
      if Assigned(Panel) then
        Panel.Free;
    end
    else
    begin
      if not Assigned(Panel) then
      begin
        LblCurrFile := GetLabel(sCurrFileLabelName);
        LblStatus := GetLabel('Status');
        if not Assigned(LblCurrFile) or not Assigned(LblStatus) then
          Exit;
        Panel := TPanel.Create(Form);
        Panel.Name := 'bcc32pch_StatusOverwrite';
        Panel.BevelInner := bvNone;
        Panel.BevelOuter := bvNOne;

        Panel.BoundsRect := LblCurrFile.BoundsRect;
        Panel.Alignment := taLeftJustify;

        //Panel.BoundsRect := Rect(LblStatus.Left, LblStatus.Top, LblCurrFile.BoundsRect.Right, LblCurrFile.BoundsRect.Bottom);

        Panel.Font.Style := [fsBold];
        Panel.Caption := Value;
        Panel.Parent := Form;
      end
      else
        Panel.Caption := Value;
    end;
  end;
end;

function TNativeProgressForm.GetFilesCompiled: Integer;
var
  Lbl: TLabel;
begin
  Lbl := GetLabel('bcc32pch_FilesCompiled');
  if Assigned(Lbl) then
    Result := Lbl.Tag
  else
    Result := 0;
end;

procedure TNativeProgressForm.SetFilesCompiled(const Value: Integer);
var
  Lbl: TLabel;
  Form: TCustomForm;
begin
  Form := GetForm;
  if Form = nil then
    Exit;

  Lbl := GetLabel('bcc32pch_FilesCompiled');
  if Value <= 0 then
  begin
    if Assigned(Lbl) then
      Lbl.Free;
    Exit;
  end;

  if not Assigned(Lbl) then
  begin
    Lbl := TLabel.Create(Form);
    Lbl.Name := 'bcc32pch_FilesCompiled';
    Lbl.Alignment := taRightJustify;
    Lbl.Caption := '';
    Lbl.Left := Form.ClientWidth - 8 - Lbl.Width;
    SetMaxFiles(FMaxFiles);
    // SetMaxFiles leaves FProgressBar nil when FMaxFiles <= 0; fall back to the
    // label's current top rather than dereferencing a nil progress bar.
    if Assigned(FProgressBar) then
      Lbl.Top := FProgressBar.BoundsRect.Bottom + 4;
    Lbl.Parent := Form;
  end;

  if Assigned(Lbl) then
  begin
    Lbl.Tag := Value;
    Lbl.Caption := Format(sFilesCompiled, [Value]);
    SetMaxFiles(FMaxFiles); // update progress bar
  end;
end;

procedure TNativeProgressForm.SetProjectFilesCompiled(const Value: Integer);
begin
  FProjectFilesCompiled := Value;
  SetMaxFiles(FMaxFiles); // update progress bar
end;

procedure TNativeProgressForm.SetMaxFiles(const Value: Integer);
var
  Form: TCustomForm;
  NewPercentage: Integer;
  {$IF CompilerVersion >= 33.0}
  //I: Integer;
  pnErrors: TControl;
  TotalLines: TLabel;
  X, Y: Integer;
  {$IFEND}
begin
  FMaxFiles := Value;
  Form := GetForm;
  if Form = nil then
    Exit;

  if Value <= 0 then
  begin
    FreeAndNil(FProgressBar);
    Exit;
  end;

  if FMaxFiles = 0 then
    NewPercentage := 0
  else
  begin
    if FProjectFilesCompiled <> -1 then
      NewPercentage := FProjectFilesCompiled * 100 div FMaxFiles
    else
      NewPercentage := FilesCompiled * 100 div FMaxFiles;
  end;

  if FProgressBar = nil then
  begin
    FLastPercentage := NewPercentage;
    FProgressBar := TProgressBar.Create(Form);
    FProgressBar.FreeNotification(Self);
    FProgressBar.Name := 'DDevExtensions_ProgressBar';
    FProgressBar.Max := 100;
    FProgressBar.Position := NewPercentage;
    {$IF CompilerVersion >= 33.0}
    // New Progress-Dialog

//    AllocConsole;
//    for I := 0 to Form.ComponentCount - 1 do
//      WriteLn(Form.Components[I].Name + ': ' + Form.Components[I].ClassName);

    pnErrors := Form.FindComponent('pnHints') as TControl;
    TotalLines := GetLabel('TotalLines');
    if (pnErrors is TPanel) and (TotalLines <> nil) then
    begin
      X := Form.ScreenToClient(pnErrors.ClientToScreen(Point(0, 0))).X;
      Y := Form.ScreenToClient(TotalLines.ClientToScreen(Point(TotalLines.Top, 0))).Y;
      FProgressBar.ScaleForPPI(Form.CurrentPPI);
      FProgressBar.SetBounds(X, Y + 2, pnErrors.Width, TotalLines.Height div 2);
    end
    else // Fallback
      FProgressBar.SetBounds(384, 187 + 2, 162, 7);
    {$ELSE}
    FProgressBar.Width := {$IFDEF IDE50_UP}120{$ELSE}80{$ENDIF};
    FProgressBar.Height := 7;
    FProgressBar.Left := Form.ClientWidth - FProgressBar.Width - 8;
    FProgressBar.Top := Form.ClientHeight - 4 - 7 - 25 {$IFDEF COMPILER10_UP}- 20{$ENDIF};
    {$IFEND}
    {$IF CompilerVersion >= 23.0}
    if StyleServices.Available and StyleServices.Enabled then
    {$ELSE}
    if ThemeServices.ThemesAvailable and ThemeServices.ThemesEnabled then
    {$IFEND}
      FProgressBar.Height := 12;
    FProgressBar.Parent := Form;
    UpdateTaskbarProgress;
  end
  else
  begin
    if NewPercentage <> FLastPercentage then
    begin
      FLastPercentage := NewPercentage;
      if FProgressBar <> nil then
        FProgressBar.Position := NewPercentage;
      //Progress.Max := 100;
      UpdateTaskbarProgress;
    end;
  end;
end;

function TNativeProgressForm.GetTaskbarFormHandle: HWND;
begin
  if Application.MainFormOnTaskBar then
    Result := Application.MainFormHandle
  else
    Result := Application.Handle;
end;

procedure TNativeProgressForm.UpdateTaskbarProgress;
var
  State: Integer;
  TaskbarFormHandle: HWND;
begin
  if CheckWin32Version(6, 1) and (FTaskbarList3 <> nil) then
  begin
    TaskbarFormHandle := GetTaskbarFormHandle;
    if TaskbarFormHandle <> 0 then
    begin
      if FProgressBar <> nil then
      begin
        FTaskbarList3.SetProgressValue(TaskbarFormHandle, FProgressBar.Position, FProgressBar.Max);
        State := TBPF_NORMAL;
        if ErrorCount > 0 then
          State := TBPF_ERROR
        else if WarningCount > 0 then
          State := TBPF_PAUSED
        else if FProgressBar.Position = 0 then
          State := TBPF_NOPROGRESS;
      end
      else
        State := TBPF_NOPROGRESS;
      FTaskbarList3.SetProgressState(TaskbarFormHandle, State);
    end;
  end;
end;

procedure TNativeProgressForm.DoAutoCloseClick(Sender: TObject);
begin
  FCachedAutoClose := TCheckBox(Sender).Checked;
end;


end.
