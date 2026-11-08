{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit RegisterPlugins;

/// <summary>
/// Central registration point for every DDevExtensions feature. Calls the
/// <c>InitPlugin</c> entry point of each enabled feature unit during
/// <see cref="Main.InstallHooks"/>.
/// </summary>
/// <remarks>
/// Individual features can be disabled at run-time by listing their key in
/// the <c>DDevExtensions.DisabledFeatures</c> environment variable
/// (semicolon-separated). Compile-time feature gating is controlled by the
/// <c>INCLUDE_*</c> conditional defines in <c>DelphiExtension.inc</c>.
/// </remarks>

{$I DelphiExtension.inc}

interface

/// <summary>
/// Iterates over every supported feature unit and registers either an
/// expert loader (early) or late loader (after IDE main form is up).
/// Honours the <c>DDevExtensions.DisabledFeatures</c> environment variable.
/// </summary>
procedure RegisterIDEPlugins;

implementation

uses
  System.SysUtils, System.Classes, Main,
  {$IF CompilerVersion < 21.0} // Delphi 2009
  ProjectMgrShortCuts,
  {$IFEND}
  FrmeOptionPageFormDesigner,
  FrmProjectSettingsSetVersioninfo, FocusEditor, CompileProgress,
  IDEMenuHandler, FrmeOptionPageKeybindings,
  FrmeOptionPageFileCleaner, FrmeOptionPageCompileBackup,
  {$IFDEF INCLUDE_STARTPARAMETERTEAM}
  FrmeOptionPageStartParameterTeam, // XE2 made the parameter configuration-aware
  {$ENDIF INCLUDE_STARTPARAMETERTEAM}
  FrmeOptionPageUnitSelector, FrmeOptionPageDSUFeatures, ComponentSelector, StrucViewSearch,
  {$IF CompilerVersion <= 32.0} // 10.2 Tokyo-
  FrmeOptionPageOldPalette,
  {$IFEND}
  {$IFDEF INCLUDE_DEPENDENCYVIEWER}
  DependencyViewer,
  {$ENDIF INCLUDE_DEPENDENCYVIEWER}
  {$IFDEF INCLUDE_UNUSEDUNITDETECTOR}
  UnusedUnitDetector,
  {$ENDIF INCLUDE_UNUSEDUNITDETECTOR}
  {$IFDEF INCLUDE_TODOAGGREGATOR}
  TodoAggregator,
  {$ENDIF INCLUDE_TODOAGGREGATOR}
  {$IFDEF INCLUDE_CODESTYLECHECKER}
  CodeStyleChecker,
  {$ENDIF INCLUDE_CODESTYLECHECKER}
  {$IFDEF INCLUDE_DEADCODEDETECTOR}
  DeadCodeDetector,
  {$ENDIF INCLUDE_DEADCODEDETECTOR}
  {$IFDEF INCLUDE_UNREACHABLECODEDETECTOR}
  UnreachableCodeDetector,
  {$ENDIF INCLUDE_UNREACHABLECODEDETECTOR}
  {$IFDEF INCLUDE_USESCLAUSEMANAGER}
  UsesClauseManager,
  {$ENDIF INCLUDE_USESCLAUSEMANAGER}
  {$IFDEF INCLUDE_DECIRCULARISER}
  Decirculariser,
  {$ENDIF INCLUDE_DECIRCULARISER}
  {$IFDEF INCLUDE_EMPTYEVENTHANDLERDETECTOR}
  EmptyEventHandlerDetector,
  {$ENDIF INCLUDE_EMPTYEVENTHANDLERDETECTOR}
  {$IFDEF INCLUDE_DFMPASCONSISTENCY}
  DfmPasConsistency,
  {$ENDIF INCLUDE_DFMPASCONSISTENCY}
  {$IFDEF INCLUDE_CODEQUALITYANALYZER}
  CodeQualityAnalyzer,
  {$ENDIF INCLUDE_CODEQUALITYANALYZER}
  {$IFDEF INCLUDE_LIBRARYPATHSORTER}
  LibraryPathSorter,
  {$ENDIF INCLUDE_LIBRARYPATHSORTER}
  {$IFDEF INCLUDE_PATHCOMPACTOR}
  PathCompactor,
  {$ENDIF INCLUDE_PATHCOMPACTOR}
  {$IFDEF INCLUDE_PROJECTGROUPSORTER}
  ProjectGroupSorter,
  {$ENDIF INCLUDE_PROJECTGROUPSORTER}
  {$IFDEF INCLUDE_EXTERNALMODMONITOR}
  ExternalModMonitor,
  {$ENDIF INCLUDE_EXTERNALMODMONITOR}
  {$IFDEF INCLUDE_METHODSEPARATORS}
  MethodSeparators,
  {$ENDIF INCLUDE_METHODSEPARATORS}
  StartParameterManagerReg, FrmReloadFiles{, PrjDesktopState},
  CodeInsightHandling, FeatureSwitches, Winapi.Windows, System.IOUtils;

/// <summary>
/// Reports names in <c>DDevExtensions.DisabledFeatures</c> that match no feature of any DDevExtensions version: a
/// mistyped switch would otherwise leave the feature running while the tester believes it is off.  Always logged;
/// shown in a dialog once per distinct set of unknown names on this machine (remembered in the AppData folder),
/// so a stale value does not nag at every start.
/// </summary>
/// <param name="Switches">The parsed switches, after every feature has been asked about.</param>
procedure ReportUnknownFeatureNames(Switches: TFeatureSwitches);
begin
  var Unknown := Switches.UnknownNames;
  if Length( Unknown ) = 0 then
    Exit;
  var NameList := string.Join( ';', Unknown );
  var Text := 'DDevExtensions.DisabledFeatures names no feature called: ' + string.Join( ', ', Unknown ) +
    '.  Those entries have no effect.';
  OutputDebugString( PChar( Text ) );
  var Marker := AppDataDirectory + '\DisabledFeatures.warned';
  try
    if FileExists( Marker ) and SameText( TFile.ReadAllText( Marker ).Trim, NameList ) then
      Exit; // this exact set has been shown before
    TFile.WriteAllText( Marker, NameList );
  except
    on E: EInOutError do
      OutputDebugString( PChar( 'DDevExtensions: cannot use ' + Marker + ': ' + E.Message ) );
    on E: EFileStreamError do
      OutputDebugString( PChar( 'DDevExtensions: cannot use ' + Marker + ': ' + E.Message ) );
  end;
  MessageBox( 0, PChar( Text ), 'DDevExtensions', MB_OK or MB_ICONWARNING or MB_TASKMODAL );
end;

procedure RegisterIDEPlugins;
var
  DisabledPlugins: TFeatureSwitches;
begin
  DisabledPlugins := TFeatureSwitches.Create(GetEnvironmentVariable('DDevExtensions.DisabledFeatures'));
  try
    if not DisabledPlugins.IsDisabled('DSUFeatures') then
      RegisterLateLoader(FrmeOptionPageDSUFeatures.InitPlugin);

    {$IFDEF INCLUDE_FOCUSEDITOR}
    if not DisabledPlugins.IsDisabled('FocusEditor') then
      RegisterLateLoader(FocusEditor.InitPlugin); // Set focus to editor after debugging
    {$ENDIF}

//    if not DisabledPlugins.IsDisabled('ProjectDesktopState') then
//      RegisterLateLoader(PrjDesktopState.InitPlugin);

    {$IFDEF INCLUDE_IDEMENUHANDLER}
    if not DisabledPlugins.IsDisabled('IDEMenuHandler') then
      RegisterLateLoader(IDEMenuHandler.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_FORMDESIGNER}
    if not DisabledPlugins.IsDisabled('FormDesigner') then
      RegisterLateLoader(FrmeOptionPageFormDesigner.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_COMPONENTSELECTOR}
    if not DisabledPlugins.IsDisabled('ComponentSelector') then
      RegisterLateLoader(ComponentSelector.InitPlugin);
    {$ENDIF}

  {------------------------------------------------------------------------------}

    if not DisabledPlugins.IsDisabled('ProjectSettingsSetVersioninfo') then
      RegisterLateLoader(FrmProjectSettingsSetVersioninfo.InitPlugin);

    {$IFDEF INCLUDE_COMPILEPROGRESS}
    if not DisabledPlugins.IsDisabled('CompileProgress') then
      RegisterLateLoader(CompileProgress.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_UNITSELECTOR}
    if not DisabledPlugins.IsDisabled('UnitSelector') then
      RegisterLateLoader(FrmeOptionPageUnitSelector.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_FILECLEANER}
    if not DisabledPlugins.IsDisabled('FileCleaner') then
      RegisterLateLoader(FrmeOptionPageFileCleaner.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_COMPILEBACKUP}
    if not DisabledPlugins.IsDisabled('CompileBackup') then
      RegisterLateLoader(FrmeOptionPageCompileBackup.InitPlugin);
    {$ENDIF}

    {$IF CompilerVersion <= 32.0} // 10.2 Tokyo-
    {$IFDEF INCLUDE_OLDPALETTE}
    if not DisabledPlugins.IsDisabled('OldPalette') then
      RegisterLateLoader(FrmeOptionPageOldPalette.InitPlugin);
    {$ENDIF}
    {$IFEND}

    {$IFDEF INCLUDE_KEYBINDINGS}
    if not DisabledPlugins.IsDisabled('Keybindings') then
      RegisterLateLoader(FrmeOptionPageKeybindings.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_STARTPARAMETERTEAM}
    if not DisabledPlugins.IsDisabled('StartParameterTeam') then
      RegisterLateLoader(FrmeOptionPageStartParameterTeam.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_STRUCVIEWSEARCH}
    if not DisabledPlugins.IsDisabled('StrucViewSearch') then
      RegisterLateLoader(StrucViewSearch.InitPlugin);
    {$ENDIF}

    // Menu items appear in registration order - organised by workflow:
    // 1. Architecture overview (Dependency Viewer)
    // 2. Comprehensive quality check (Code Quality Analyser)
    // 3. Remove unused code (Unused Units, Dead Code, Unreachable, Empty Handlers)
    // 4. Organise (Uses Clause Manager, DFM/PAS Consistency)
    // 5. Style check (Code Style Checker)
    // 6. Review work items (TODO/FIXME Aggregator)

    {$IFDEF INCLUDE_DEPENDENCYVIEWER}
    if not DisabledPlugins.IsDisabled('DependencyViewer') then
      RegisterLateLoader(DependencyViewer.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_CODEQUALITYANALYZER}
    if not DisabledPlugins.IsDisabled('CodeQualityAnalyzer') then
      RegisterLateLoader(CodeQualityAnalyzer.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_UNUSEDUNITDETECTOR}
    if not DisabledPlugins.IsDisabled('UnusedUnitDetector') then
      RegisterLateLoader(UnusedUnitDetector.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_DEADCODEDETECTOR}
    if not DisabledPlugins.IsDisabled('DeadCodeDetector') then
      RegisterLateLoader(DeadCodeDetector.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_UNREACHABLECODEDETECTOR}
    if not DisabledPlugins.IsDisabled('UnreachableCodeDetector') then
      RegisterLateLoader(UnreachableCodeDetector.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_EMPTYEVENTHANDLERDETECTOR}
    if not DisabledPlugins.IsDisabled('EmptyEventHandlerDetector') then
      RegisterLateLoader(EmptyEventHandlerDetector.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_USESCLAUSEMANAGER}
    if not DisabledPlugins.IsDisabled('UsesClauseManager') then
      RegisterLateLoader(UsesClauseManager.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_DECIRCULARISER}
    if not DisabledPlugins.IsDisabled('Decirculariser') then
      RegisterLateLoader(Decirculariser.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_DFMPASCONSISTENCY}
    if not DisabledPlugins.IsDisabled('DfmPasConsistency') then
      RegisterLateLoader(DfmPasConsistency.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_CODESTYLECHECKER}
    if not DisabledPlugins.IsDisabled('CodeStyleChecker') then
      RegisterLateLoader(CodeStyleChecker.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_TODOAGGREGATOR}
    if not DisabledPlugins.IsDisabled('TodoAggregator') then
      RegisterLateLoader(TodoAggregator.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_LIBRARYPATHSORTER}
    if not DisabledPlugins.IsDisabled('LibraryPathSorter') then
      RegisterLateLoader(LibraryPathSorter.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_PATHCOMPACTOR}
    if not DisabledPlugins.IsDisabled('PathCompactor') then
      RegisterLateLoader(PathCompactor.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_PROJECTGROUPSORTER}
    if not DisabledPlugins.IsDisabled('ProjectGroupSorter') then
      RegisterLateLoader(ProjectGroupSorter.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_EXTERNALMODMONITOR}
    if not DisabledPlugins.IsDisabled('ExternalModMonitor') then
      RegisterLateLoader(ExternalModMonitor.InitPlugin);
    {$ENDIF}

    {$IFDEF INCLUDE_METHODSEPARATORS}
    if not DisabledPlugins.IsDisabled('MethodSeparators') then
      RegisterLateLoader(MethodSeparators.InitPlugin);
    {$ENDIF}

    {$IF CompilerVersion < 21.0}
    if not DisabledPlugins.IsDisabled('ProjectMgrShortCuts') then
      RegisterLateLoader(ProjectMgrShortCuts.InitPlugin);
    {$IFEND}

    if not DisabledPlugins.IsDisabled('StartParameter') then
      RegisterExpertLoader(StartParameterManagerReg.InitPlugin);

    if not DisabledPlugins.IsDisabled('ReloadFiles') then
      RegisterExpertLoader(FrmReloadFiles.InitPlugin);

    if not DisabledPlugins.IsDisabled('CodeInsightHandling') then
      RegisterLateLoader(CodeInsightHandling.InitPlugin);

    ReportUnknownFeatureNames(DisabledPlugins);
  finally
    DisabledPlugins.Free;
  end;
end;

end.
