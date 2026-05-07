{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageCompilerProgress;

/// <summary>
/// Options page frame that exposes the user-configurable settings of the CompileProgress
/// plug-in ( progress bar, build statistics, style checks, compiler unit-cache release,
/// auto-save, etc. ) inside the DDevExtensions options dialog.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, FrmeBase, StdCtrls, ExtCtrls,
  Dialogs, FrmTreePages, CompileProgress;

type
  /// <summary>
  /// Frame implementing ITreePageComponent for the "Compilation" page in the options tree.
  /// Loads and saves settings against the associated TCompileProgress instance.
  /// </summary>
  TFrameOptionPageCompilerProgress = class(TFrameBase, ITreePageComponent)
    /// <summary>Disables the IDE "Rebuild required" dialog ( pre-XE only ).</summary>
    cbxDisableRebuildDlg: TCheckBox;
    /// <summary>Saves all modified files automatically after a successful compile.</summary>
    chkAutoSaveAfterSuccessfulCompile: TCheckBox;
    /// <summary>Writes a "Last Compile" version-info entry on each compile ( pre-XE2 only ).</summary>
    chkLastCompileVersionInfo: TCheckBox;
    /// <summary>Date/time format string used for the Last Compile entry.</summary>
    edtLastCompileVersionInfoFormat: TEdit;
    /// <summary>Asks the user before compiling a file owned by a project other than the active one.</summary>
    chkAskBeforeCompilingFileFromDiffernetProject: TCheckBox;
    /// <summary>Releases the compiler unit cache of other projects to recover memory.</summary>
    chkReleaseCompilerUnitCache: TCheckBox;
    /// <summary>Limits cache release to high-memory situations only.</summary>
    chkReleaseCompilerUnitCacheHigh: TCheckBox;
    /// <summary>Enables the per-unit build statistics tracker.</summary>
    chkEnableBuildStatistics: TCheckBox;
    /// <summary>Shows the build statistics dialog automatically after each compile.</summary>
    chkShowBuildStatisticsAfterCompile: TCheckBox;
    /// <summary>Runs the code-style checker after each successful compile.</summary>
    chkRunStyleCheckAfterCompile: TCheckBox;
    /// <summary>Enables or disables the version-info format edit based on the check-box state.</summary>
    procedure chkLastCompileVersionInfoClick(Sender: TObject);
    /// <summary>Enables or disables the high-memory-only check box based on the parent option.</summary>
    procedure chkReleaseCompilerUnitCacheClick(Sender: TObject);
    /// <summary>Enables or disables build-statistics related options based on the parent option.</summary>
    procedure chkEnableBuildStatisticsClick(Sender: TObject);
  private
    { Private-Deklarationen }
    /// <summary>Plug-in configuration object whose properties are bound to this frame.</summary>
    FCompileProgress: TCompileProgress;
  public
    { Public-Deklarationen }
    /// <summary>Creates the frame and adjusts the layout for compiler versions that hide certain options.</summary>
    /// <param name="AOwner">Owning component for the frame.</param>
    constructor Create(AOwner: TComponent); override;

    /// <summary>Loads the plug-in settings into the visual controls.</summary>
    procedure LoadData;
    /// <summary>Persists the values from the visual controls back into the plug-in configuration.</summary>
    procedure SaveData;
    /// <summary>Called when this options page becomes the selected page.</summary>
    procedure Selected;
    /// <summary>Called when this options page is no longer selected.</summary>
    procedure Unselected;
    /// <summary>Receives the TCompileProgress instance that this page edits.</summary>
    /// <param name="UserData">A TCompileProgress instance.</param>
    procedure SetUserData(UserData: TObject);
  end;

implementation

{$R *.dfm}

{ TFrameOptionPageCompilerProgress }

procedure TFrameOptionPageCompilerProgress.SetUserData(UserData: TObject);
begin
  FCompileProgress := UserData as TCompileProgress;
end;

procedure TFrameOptionPageCompilerProgress.chkLastCompileVersionInfoClick(Sender: TObject);
begin
  inherited;
  edtLastCompileVersionInfoFormat.Enabled := chkLastCompileVersionInfo.Checked;
  if edtLastCompileVersionInfoFormat.Enabled then
    edtLastCompileVersionInfoFormat.Color := clWindow
  else
    edtLastCompileVersionInfoFormat.Color := clBtnFace;
end;

procedure TFrameOptionPageCompilerProgress.chkReleaseCompilerUnitCacheClick(Sender: TObject);
begin
  inherited;
  chkReleaseCompilerUnitCacheHigh.Enabled := chkReleaseCompilerUnitCache.Checked;
end;

procedure TFrameOptionPageCompilerProgress.chkEnableBuildStatisticsClick(Sender: TObject);
begin
  inherited;
  chkShowBuildStatisticsAfterCompile.Enabled := chkEnableBuildStatistics.Checked;
  chkRunStyleCheckAfterCompile.Enabled := chkEnableBuildStatistics.Checked;
end;

constructor TFrameOptionPageCompilerProgress.Create(AOwner: TComponent);
{$IF CompilerVersion >= 22.0} // XE has its own option
var
  Diff: Integer;
{$IFEND}
begin
  inherited Create(AOwner);
  {$IF CompilerVersion >= 22.0} // XE has its own option
  Diff := chkAutoSaveAfterSuccessfulCompile.Top - cbxDisableRebuildDlg.Top;
  cbxDisableRebuildDlg.Free;

  chkAutoSaveAfterSuccessfulCompile.Top := chkAutoSaveAfterSuccessfulCompile.Top - Diff;
  chkAskBeforeCompilingFileFromDiffernetProject.Top := chkAskBeforeCompilingFileFromDiffernetProject.Top - Diff;
  chkLastCompileVersionInfo.Top := chkLastCompileVersionInfo.Top - Diff;
  edtLastCompileVersionInfoFormat.Top := edtLastCompileVersionInfoFormat.Top - Diff;
  {$IFEND}
  {$IF CompilerVersion >= 23.0} // XE2+ changed how version info is written
  chkLastCompileVersionInfo.Visible := False;
  edtLastCompileVersionInfoFormat.Visible := False;
  {$IFEND}
end;

procedure TFrameOptionPageCompilerProgress.LoadData;
begin
  chkReleaseCompilerUnitCache.Checked := FCompileProgress.ReleaseCompilerUnitCache;
  chkReleaseCompilerUnitCacheHigh.Checked := FCompileProgress.ReleaseCompilerUnitCacheHigh;
  chkReleaseCompilerUnitCacheHigh.Enabled := chkReleaseCompilerUnitCache.Checked;

  {$IF CompilerVersion < 22.0} // XE has its own option
  cbxDisableRebuildDlg.Checked := FCompileProgress.DisableRebuildDlg;
  {$IFEND}
  chkAutoSaveAfterSuccessfulCompile.Checked := FCompileProgress.AutoSaveAfterSuccessfulCompile;
  {$IF CompilerVersion < 23.0} // XE2+ changed how version info works
  chkLastCompileVersionInfo.Checked := FCompileProgress.LastCompileVersionInfo;
  edtLastCompileVersionInfoFormat.Text := FCompileProgress.LastCompileVersionInfoFormat;
  {$IFEND}
  chkAskBeforeCompilingFileFromDiffernetProject.Checked := FCompileProgress.AskCompileFromDiffProject;

  chkEnableBuildStatistics.Checked := FCompileProgress.EnableBuildStatistics;
  chkShowBuildStatisticsAfterCompile.Checked := FCompileProgress.ShowBuildStatisticsAfterCompile;
  chkShowBuildStatisticsAfterCompile.Enabled := chkEnableBuildStatistics.Checked;
  chkRunStyleCheckAfterCompile.Checked := FCompileProgress.RunStyleCheckAfterCompile;
  chkRunStyleCheckAfterCompile.Enabled := chkEnableBuildStatistics.Checked;

  chkLastCompileVersionInfoClick(chkLastCompileVersionInfo);
end;

procedure TFrameOptionPageCompilerProgress.SaveData;
begin
  FCompileProgress.ReleaseCompilerUnitCache := chkReleaseCompilerUnitCache.Checked;
  FCompileProgress.ReleaseCompilerUnitCacheHigh := chkReleaseCompilerUnitCacheHigh.Checked;
  {$IF CompilerVersion < 22.0} // XE has its own option
  FCompileProgress.DisableRebuildDlg := cbxDisableRebuildDlg.Checked;
  {$IFEND}
  FCompileProgress.AutoSaveAfterSuccessfulCompile := chkAutoSaveAfterSuccessfulCompile.Checked;
  {$IF CompilerVersion < 23.0} // XE2+ changed how version info works
  FCompileProgress.LastCompileVersionInfo := chkLastCompileVersionInfo.Checked;
  FCompileProgress.LastCompileVersionInfoFormat := edtLastCompileVersionInfoFormat.Text;
  {$IFEND}
  FCompileProgress.AskCompileFromDiffProject := chkAskBeforeCompilingFileFromDiffernetProject.Checked;
  FCompileProgress.EnableBuildStatistics := chkEnableBuildStatistics.Checked;
  FCompileProgress.ShowBuildStatisticsAfterCompile := chkShowBuildStatisticsAfterCompile.Checked;
  FCompileProgress.RunStyleCheckAfterCompile := chkRunStyleCheckAfterCompile.Checked;
  FCompileProgress.Save;
end;

procedure TFrameOptionPageCompilerProgress.Selected;
begin
end;

procedure TFrameOptionPageCompilerProgress.Unselected;
begin
end;

end.
