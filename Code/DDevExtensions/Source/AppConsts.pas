{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2014 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit AppConsts;

/// <summary>
/// Centralised string constants and localisation helpers for DDevExtensions.
/// Holds the plug-in version/copyright literals and the per-language captions
/// (English, German, French) used throughout the extension's UI.
/// </summary>
/// <remarks>
/// Language selection is driven by the <c>LANGDIR</c> environment variable
/// (resolved by <see cref="GetLang"/>). Each user-facing caption has an
/// accessor function (e.g. <c>sMenuItemDDevExtensionsOptions</c>) that picks
/// the localised variant at run-time.
/// </remarks>

interface

const
  {$I Version.inc}

  /// <summary>Plug-in version number sourced from <c>Version.inc</c>.</summary>
  sPluginVersion = VersionNumber;
  /// <summary>Full plug-in name (name + version) shown in About dialogs and the splash screen.</summary>
  sPluginName = 'DDevExtensions ' + sPluginVersion;
  /// <summary>Short copyright line displayed on the About dialog.</summary>
  sPluginSmallCopyright = '(C) 2006-2020 Andreas Hausladen';
  /// <summary>Full copyright string ("Copyright " + small copyright).</summary>
  sPluginCopyright = 'Copyright ' + sPluginSmallCopyright;

resourcestring
  /// <summary>"All columns" filter caption used by the column filter combo.</summary>
  RsFilterAllFields = 'All columns';
  /// <summary>Format string for the count of modules ("%d modules").</summary>
  RsNumberOfModules = '%d modules';
  /// <summary>"All directories" filter caption used by directory filters.</summary>
  RsFilterAllDirectories = 'All directories';

  /// <summary>Caption for the "Active Build Configuration" project menu entry.</summary>
  RsSetActiveBuildConfiguration = 'Active Build Configuration';
  
const
  /// <summary>English text returned by <see cref="sSearchComponent"/> when <see cref="GetLang"/> selects English.</summary>
  sSearchComponent_Eng = '(search component)';
  /// <summary>English text returned by <see cref="sFilesCompiled"/> when <see cref="GetLang"/> selects English.</summary>
  sFilesCompiled_Eng = '%d files compiled';
  /// <summary>English text returned by <see cref="sAutoCloseCaption"/> when <see cref="GetLang"/> selects English.</summary>
  sAutoCloseCaption_Eng = '&Automatically close on successful compile';
  /// <summary>English text returned by <see cref="sMenuItemManageProjectSettings"/> when <see cref="GetLang"/> selects English.</summary>
  sMenuItemManageProjectSettings_Eng = 'Manage Configurations...';
  /// <summary>English text returned by <see cref="sMenuItemProjectSettings"/> when <see cref="GetLang"/> selects English.</summary>
  sMenuItemProjectSettings_Eng = 'Project Configurations';
  /// <summary>English text returned by <see cref="sMenuItemSetVersionInfo"/> when <see cref="GetLang"/> selects English.</summary>
  sMenuItemSetVersionInfo_Eng = 'Set Versioninfo...';
  /// <summary>English text returned by <see cref="sMenuItemDDevExtensionsOptions"/> when <see cref="GetLang"/> selects English.</summary>
  sMenuItemDDevExtensionsOptions_Eng = 'DDevExtensions options...';
  /// <summary>English text returned by <see cref="sMenuItemDDevExtensionsFileSelector"/> when <see cref="GetLang"/> selects English.</summary>
  sMenuItemDDevExtensionsFileSelector_Eng = 'Find Unit-File...';
  /// <summary>English text returned by <see cref="sParseErrorUsesLocationNotFound"/> when <see cref="GetLang"/> selects English.</summary>
  sParseErrorUsesLocationNotFound_Eng = 'Parser Error: Failed to find the position for "uses"';

  /// <summary>English text returned by <see cref="sCapSwitchToModuleProject"/> when <see cref="GetLang"/> selects English.</summary>
  sCapSwitchToModuleProject_Eng = 'Compile/Build - Switch Active Project';
  /// <summary>English text returned by <see cref="sLblSwitchCurrentModuleProject"/> when <see cref="GetLang"/> selects English.</summary>
  sLblSwitchCurrentModuleProject_Eng = 'The module is neither part of the active project nor is it in a direct or indirect dependent project.';
  /// <summary>English text returned by <see cref="sLblSwitchToModuleProjectQuestion"/> when <see cref="GetLang"/> selects English.</summary>
  sLblSwitchToModuleProjectQuestion_Eng = 'Do you want to &switch to the module''s project?';
  /// <summary>English text returned by <see cref="sLblDontShowAgain"/> when <see cref="GetLang"/> selects English.</summary>
  sLblDontShowAgain_Eng = '&Don''t show again';
  /// <summary>English text returned by <see cref="sLblTemporarySwitch"/> when <see cref="GetLang"/> selects English.</summary>
  sLblTemporarySwitch_Eng = 'Switch &temporary [Shift-Key]';
  /// <summary>English text returned by <see cref="sLblActiveProject"/> when <see cref="GetLang"/> selects English.</summary>
  sLblActiveProject_Eng = 'Active Project:';
  /// <summary>English text returned by <see cref="sLblActiveModule"/> when <see cref="GetLang"/> selects English.</summary>
  sLblActiveModule_Eng = 'Active Module:';

  /// <summary>English text returned by <see cref="sDoYouWantToInvokeTheContextHelp"/> when <see cref="GetLang"/> selects English.</summary>
  sDoYouWantToInvokeTheContextHelp_Eng = 'Do you want to invoke the context help?';

  /// <summary>English text returned by <see cref="sCannotUnloadModuleForm"/> when <see cref="GetLang"/> selects English.</summary>
  sCannotUnloadModuleForm_Eng = 'Cannot unload form ''%s''';
  /// <summary>English text returned by <see cref="sLVGroup_ProjectFiles"/> when <see cref="GetLang"/> selects English.</summary>
  sLVGroup_ProjectFiles_Eng = 'Project files';
  /// <summary>English text returned by <see cref="sLVGroup_UnitFiles"/> when <see cref="GetLang"/> selects English.</summary>
  sLVGroup_UnitFiles_Eng = 'Units/Files';
  /// <summary>English text returned by <see cref="sLVGroup_Forms"/> when <see cref="GetLang"/> selects English.</summary>
  sLVGroup_Forms_Eng = 'Forms/Frames/DataModules';
  /// <summary>English text returned by <see cref="sReloadButton"/> when <see cref="GetLang"/> selects English.</summary>
  sReloadButton_Eng = '&Reload';
  /// <summary>English text returned by <see cref="sReloadChangedFilesCaption"/> when <see cref="GetLang"/> selects English.</summary>
  sReloadChangedFilesCaption_Eng = 'Reload changed files';
  /// <summary>English text returned by <see cref="sLVColumn_File"/> when <see cref="GetLang"/> selects English.</summary>
  sLVColumn_File_Eng = 'File';
  /// <summary>English text returned by <see cref="sLVColumn_Path"/> when <see cref="GetLang"/> selects English.</summary>
  sLVColumn_Path_Eng = 'Path';

  /// <summary>English text returned by <see cref="sReloadSelectOnlyUnmodifiedField"/> when <see cref="GetLang"/> selects English.</summary>
  sReloadSelectOnlyUnmodifiedField_Eng = 'Select &unmodified buffers';
  /// <summary>English text returned by <see cref="sReloadSelectOnlyModifiedFiles"/> when <see cref="GetLang"/> selects English.</summary>
  sReloadSelectOnlyModifiedFiles_Eng = 'Select &modified buffers';
  /// <summary>English text returned by <see cref="sReloadSelectAll"/> when <see cref="GetLang"/> selects English.</summary>
  sReloadSelectAll_Eng = 'Select &all';
  /// <summary>English text returned by <see cref="sReloadDeselectAll"/> when <see cref="GetLang"/> selects English.</summary>
  sReloadDeselectAll_Eng = '&Deselect all';
  /// <summary>English text returned by <see cref="sReloadInvertSelection"/> when <see cref="GetLang"/> selects English.</summary>
  sReloadInvertSelection_Eng = '&Invert selection';
  /// <summary>English text returned by <see cref="sReloadShowInExplorer"/> when <see cref="GetLang"/> selects English.</summary>
  sReloadShowInExplorer_Eng = 'Show in &Explorer';

  /// <summary>German text returned by <see cref="sSearchComponent"/> when <see cref="GetLang"/> selects German.</summary>
  sSearchComponent_Ger = '(Komponente suchen)';
  /// <summary>German text returned by <see cref="sFilesCompiled"/> when <see cref="GetLang"/> selects German.</summary>
  sFilesCompiled_Ger = '%d Dateien compiliert';
  /// <summary>German text returned by <see cref="sAutoCloseCaption"/> when <see cref="GetLang"/> selects German.</summary>
  sAutoCloseCaption_Ger = '&Nach erfolgreicher Compilierung automatisch schließen';
  /// <summary>German text returned by <see cref="sMenuItemManageProjectSettings"/> when <see cref="GetLang"/> selects German.</summary>
  sMenuItemManageProjectSettings_Ger = 'Einstellungen...';
  /// <summary>German text returned by <see cref="sMenuItemProjectSettings"/> when <see cref="GetLang"/> selects German.</summary>
  sMenuItemProjectSettings_Ger = 'Projekt Konfigurationen';
  /// <summary>German text returned by <see cref="sMenuItemSetVersionInfo"/> when <see cref="GetLang"/> selects German.</summary>
  sMenuItemSetVersionInfo_Ger = 'Versionsinfo setzen...';
  /// <summary>German text returned by <see cref="sMenuItemDDevExtensionsOptions"/> when <see cref="GetLang"/> selects German.</summary>
  sMenuItemDDevExtensionsOptions_Ger = 'DDevExtensions Optionen...';
  /// <summary>German text returned by <see cref="sMenuItemDDevExtensionsFileSelector"/> when <see cref="GetLang"/> selects German.</summary>
  sMenuItemDDevExtensionsFileSelector_Ger = 'Unit-Datei suchen...';
  /// <summary>German text returned by <see cref="sParseErrorUsesLocationNotFound"/> when <see cref="GetLang"/> selects German.</summary>
  sParseErrorUsesLocationNotFound_Ger = 'Parser Fehler: Position zum Einfügen des "uses" konnte nicht ermittelt werden';

  /// <summary>German text returned by <see cref="sCapSwitchToModuleProject"/> when <see cref="GetLang"/> selects German.</summary>
  sCapSwitchToModuleProject_Ger = 'Compilieren/Erzeugen - Aktives Projekt wechseln';
  /// <summary>German text returned by <see cref="sLblSwitchCurrentModuleProject"/> when <see cref="GetLang"/> selects German.</summary>
  sLblSwitchCurrentModuleProject_Ger = 'Die Datei gehört weder zum aktiven Projekt noch zu einem direkt oder indirekt abhängigen Projekt.';
  /// <summary>German text returned by <see cref="sLblSwitchToModuleProjectQuestion"/> when <see cref="GetLang"/> selects German.</summary>
  sLblSwitchToModuleProjectQuestion_Ger = '&Soll zum Projekt der Datei gewechselt werden?';
  /// <summary>German text returned by <see cref="sLblDontShowAgain"/> when <see cref="GetLang"/> selects German.</summary>
  sLblDontShowAgain_Ger = '&Nicht mehr anzeigen';
  /// <summary>German text returned by <see cref="sLblTemporarySwitch"/> when <see cref="GetLang"/> selects German.</summary>
  sLblTemporarySwitch_Ger = '&Temporär wechseln [Umschalt-Taste]';
  /// <summary>German text returned by <see cref="sLblActiveProject"/> when <see cref="GetLang"/> selects German.</summary>
  sLblActiveProject_Ger = 'Aktives Projekt:';
  /// <summary>German text returned by <see cref="sLblActiveModule"/> when <see cref="GetLang"/> selects German.</summary>
  sLblActiveModule_Ger = 'Aktive Datei:';

  /// <summary>German text returned by <see cref="sDoYouWantToInvokeTheContextHelp"/> when <see cref="GetLang"/> selects German.</summary>
  sDoYouWantToInvokeTheContextHelp_Ger = 'Soll die Kontexthilfe aufgerufen werden?';

  /// <summary>German text returned by <see cref="sCannotUnloadModuleForm"/> when <see cref="GetLang"/> selects German.</summary>
  sCannotUnloadModuleForm_Ger = 'Formular kann nicht entladen werden: %s';
  /// <summary>German text returned by <see cref="sLVGroup_ProjectFiles"/> when <see cref="GetLang"/> selects German.</summary>
  sLVGroup_ProjectFiles_Ger = 'Projektdateien';
  /// <summary>German text returned by <see cref="sLVGroup_UnitFiles"/> when <see cref="GetLang"/> selects German.</summary>
  sLVGroup_UnitFiles_Ger = 'Units/Dateien';
  /// <summary>German text returned by <see cref="sLVGroup_Forms"/> when <see cref="GetLang"/> selects German.</summary>
  sLVGroup_Forms_Ger = 'Formulare/Frames/Datenmodule';
  /// <summary>German text returned by <see cref="sReloadButton"/> when <see cref="GetLang"/> selects German.</summary>
  sReloadButton_Ger = '&Neuladen';
  /// <summary>German text returned by <see cref="sReloadChangedFilesCaption"/> when <see cref="GetLang"/> selects German.</summary>
  sReloadChangedFilesCaption_Ger = 'Veränderte Dateien neuladen';
  /// <summary>German text returned by <see cref="sLVColumn_File"/> when <see cref="GetLang"/> selects German.</summary>
  sLVColumn_File_Ger = 'Datei';
  /// <summary>German text returned by <see cref="sLVColumn_Path"/> when <see cref="GetLang"/> selects German.</summary>
  sLVColumn_Path_Ger = 'Pfad';

  /// <summary>German text returned by <see cref="sReloadSelectOnlyUnmodifiedField"/> when <see cref="GetLang"/> selects German.</summary>
  sReloadSelectOnlyUnmodifiedField_Ger = 'Unveränderte Puffer auswählen';
  /// <summary>German text returned by <see cref="sReloadSelectOnlyModifiedFiles"/> when <see cref="GetLang"/> selects German.</summary>
  sReloadSelectOnlyModifiedFiles_Ger = '&Veränderte Puffer auswählen';
  /// <summary>German text returned by <see cref="sReloadSelectAll"/> when <see cref="GetLang"/> selects German.</summary>
  sReloadSelectAll_Ger = '&Alle auswählen';
  /// <summary>German text returned by <see cref="sReloadDeselectAll"/> when <see cref="GetLang"/> selects German.</summary>
  sReloadDeselectAll_Ger = 'A&uswahl aufheben';
  /// <summary>German text returned by <see cref="sReloadInvertSelection"/> when <see cref="GetLang"/> selects German.</summary>
  sReloadInvertSelection_Ger = 'Auswahl um&kehren';
  /// <summary>German text returned by <see cref="sReloadShowInExplorer"/> when <see cref="GetLang"/> selects German.</summary>
  sReloadShowInExplorer_Ger = 'Im &Explorer anzeigen';

  /// <summary>French text returned by <see cref="sSearchComponent"/> when <see cref="GetLang"/> selects French.</summary>
  sSearchComponent_Fra = '(chercher un composant)';
  /// <summary>French text returned by <see cref="sFilesCompiled"/> when <see cref="GetLang"/> selects French.</summary>
  sFilesCompiled_Fra = '%d fichiers compilés';
  /// <summary>French text returned by <see cref="sAutoCloseCaption"/> when <see cref="GetLang"/> selects French.</summary>
  sAutoCloseCaption_Fra = 'Fermer &Automatiquement à la réussite de la compilation';
  /// <summary>French text returned by <see cref="sMenuItemManageProjectSettings"/> when <see cref="GetLang"/> selects French.</summary>
  sMenuItemManageProjectSettings_Fra = 'Gérer les configurations...';
  /// <summary>French text returned by <see cref="sMenuItemProjectSettings"/> when <see cref="GetLang"/> selects French.</summary>
  sMenuItemProjectSettings_Fra = 'Configurations du projet';
  /// <summary>French text returned by <see cref="sMenuItemSetVersionInfo"/> when <see cref="GetLang"/> selects French.</summary>
  sMenuItemSetVersionInfo_Fra = 'Affecter les infos de version...';
  /// <summary>French text returned by <see cref="sMenuItemDDevExtensionsOptions"/> when <see cref="GetLang"/> selects French.</summary>
  sMenuItemDDevExtensionsOptions_Fra = 'Options DDevExtensions...';
  /// <summary>French text returned by <see cref="sMenuItemDDevExtensionsFileSelector"/> when <see cref="GetLang"/> selects French.</summary>
  sMenuItemDDevExtensionsFileSelector_Fra = 'Trouver le fichier unité...';
  /// <summary>French text returned by <see cref="sParseErrorUsesLocationNotFound"/> when <see cref="GetLang"/> selects French.</summary>
  sParseErrorUsesLocationNotFound_Fra = 'Erreur du Parser : Impossible de trouver la position de "uses"';

  /// <summary>French text returned by <see cref="sCapSwitchToModuleProject"/> when <see cref="GetLang"/> selects French.</summary>
  sCapSwitchToModuleProject_Fra = 'Compiler/Construire - Changer de projet actif';
  /// <summary>French text returned by <see cref="sLblSwitchCurrentModuleProject"/> when <see cref="GetLang"/> selects French.</summary>
  sLblSwitchCurrentModuleProject_Fra = 'Le module ne fait partie ni du projet actif ni d''un projet dépendant directement ou indirectement';
  /// <summary>French text returned by <see cref="sLblSwitchToModuleProjectQuestion"/> when <see cref="GetLang"/> selects French.</summary>
  sLblSwitchToModuleProjectQuestion_Fra = 'Voulez-vous pa&sser sur le projet de ce module?';
  /// <summary>French text returned by <see cref="sLblDontShowAgain"/> when <see cref="GetLang"/> selects French.</summary>
  sLblDontShowAgain_Fra = '&Ne plus afficher';
  /// <summary>French text returned by <see cref="sLblTemporarySwitch"/> when <see cref="GetLang"/> selects French.</summary>
  sLblTemporarySwitch_Fra = 'Changer &temporairement [Touche Maj]';
  /// <summary>French text returned by <see cref="sLblActiveProject"/> when <see cref="GetLang"/> selects French.</summary>
  sLblActiveProject_Fra = 'Projet actif:';
  /// <summary>French text returned by <see cref="sLblActiveModule"/> when <see cref="GetLang"/> selects French.</summary>
  sLblActiveModule_Fra = 'Module actif:';

  /// <summary>French text returned by <see cref="sDoYouWantToInvokeTheContextHelp"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sDoYouWantToInvokeTheContextHelp_Fra = sDoYouWantToInvokeTheContextHelp_Eng;

  /// <summary>French text returned by <see cref="sCannotUnloadModuleForm"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sCannotUnloadModuleForm_Fra = sCannotUnloadModuleForm_Eng;
  /// <summary>French text returned by <see cref="sLVGroup_ProjectFiles"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sLVGroup_ProjectFiles_Fra = sLVGroup_ProjectFiles_Eng;
  /// <summary>French text returned by <see cref="sLVGroup_UnitFiles"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sLVGroup_UnitFiles_Fra = sLVGroup_UnitFiles_Eng;
  /// <summary>French text returned by <see cref="sLVGroup_Forms"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sLVGroup_Forms_Fra = sLVGroup_Forms_Eng;
  /// <summary>French text returned by <see cref="sReloadButton"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sReloadButton_Fra = sReloadButton_Eng;
  /// <summary>French text returned by <see cref="sReloadChangedFilesCaption"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sReloadChangedFilesCaption_Fra = sReloadChangedFilesCaption_Eng;
  /// <summary>French text returned by <see cref="sLVColumn_File"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sLVColumn_File_Fra = sLVColumn_File_Eng;
  /// <summary>French text returned by <see cref="sLVColumn_Path"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sLVColumn_Path_Fra = sLVColumn_Path_Eng;

  /// <summary>French text returned by <see cref="sReloadSelectOnlyUnmodifiedField"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sReloadSelectOnlyUnmodifiedField_Fra = sReloadSelectOnlyUnmodifiedField_Eng;
  /// <summary>French text returned by <see cref="sReloadSelectOnlyModifiedFiles"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sReloadSelectOnlyModifiedFiles_Fra = sReloadSelectOnlyModifiedFiles_Eng;
  /// <summary>French text returned by <see cref="sReloadSelectAll"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sReloadSelectAll_Fra = sReloadSelectAll_Eng;
  /// <summary>French text returned by <see cref="sReloadDeselectAll"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sReloadDeselectAll_Fra = sReloadDeselectAll_Eng;
  /// <summary>French text returned by <see cref="sReloadInvertSelection"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sReloadInvertSelection_Fra = sReloadInvertSelection_Eng;
  /// <summary>French text returned by <see cref="sReloadShowInExplorer"/> when <see cref="GetLang"/> selects French.
  /// No French translation exists, so it reuses the English text.</summary>
  sReloadShowInExplorer_Fra = sReloadShowInExplorer_Eng;


/// <summary>Returns the localised "(search component)" placeholder caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sSearchComponent: string;
/// <summary>Returns the localised "%d files compiled" status text.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sFilesCompiled: string;
/// <summary>Returns the localised "&amp;Automatically close on successful compile" check-box caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sAutoCloseCaption: string;
/// <summary>Returns the localised "Manage Configurations..." menu caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sMenuItemManageProjectSettings: string;
/// <summary>Returns the localised "Project Configurations" menu caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sMenuItemProjectSettings: string;
/// <summary>Returns the localised "Set Versioninfo..." menu caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sMenuItemSetVersionInfo: string;
/// <summary>Returns the localised "DDevExtensions options..." menu caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sMenuItemDDevExtensionsOptions: string;
/// <summary>Returns the localised "Find Unit-File..." menu caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sMenuItemDDevExtensionsFileSelector: string;
/// <summary>Returns the localised parser error message reported when the position to insert "uses" cannot be found.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sParseErrorUsesLocationNotFound: string;

/// <summary>Returns the localised caption for the "Compile/Build - Switch Active Project" dialog.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sCapSwitchToModuleProject: string;
/// <summary>Returns the localised explanatory text shown when the active module is not in the active project.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sLblSwitchCurrentModuleProject: string;
/// <summary>Returns the localised "Do you want to switch to the module's project?" prompt.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sLblSwitchToModuleProjectQuestion: string;
/// <summary>Returns the localised "Don't show again" check-box caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sLblDontShowAgain: string;
/// <summary>Returns the localised "Switch temporary [Shift-Key]" caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sLblTemporarySwitch: string;
/// <summary>Returns the localised "Active Project:" label caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sLblActiveProject: string;
/// <summary>Returns the localised "Active Module:" label caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sLblActiveModule: string;

/// <summary>Returns the localised "Do you want to invoke the context help?" prompt.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sDoYouWantToInvokeTheContextHelp: string;

// ReloadFiles
/// <summary>Returns the localised "Cannot unload form '%s'" error message.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sCannotUnloadModuleForm: string;
/// <summary>Returns the localised "Project files" list-view group caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sLVGroup_ProjectFiles: string;
/// <summary>Returns the localised "Units/Files" list-view group caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sLVGroup_UnitFiles: string;
/// <summary>Returns the localised "Forms/Frames/DataModules" list-view group caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sLVGroup_Forms: string;
/// <summary>Returns the localised "Reload" button caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sReloadButton: string;
/// <summary>Returns the localised caption for the Reload-Changed-Files dialog.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sReloadChangedFilesCaption: string;
/// <summary>Returns the localised "File" list-view column caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sLVColumn_File: string;
/// <summary>Returns the localised "Path" list-view column caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sLVColumn_Path: string;

/// <summary>Returns the localised "Select unmodified buffers" menu caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sReloadSelectOnlyUnmodifiedField: string;
/// <summary>Returns the localised "Select modified buffers" menu caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sReloadSelectOnlyModifiedFiles: string;
/// <summary>Returns the localised "Select all" menu caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sReloadSelectAll: string;
/// <summary>Returns the localised "Deselect all" menu caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sReloadDeselectAll: string;
/// <summary>Returns the localised "Invert selection" menu caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sReloadInvertSelection: string;
/// <summary>Returns the localised "Show in Explorer" menu caption.</summary>
/// <returns>The text in the UI language chosen by <see cref="GetLang"/>.</returns>
function sReloadShowInExplorer: string;



/// <summary>
/// Returns the active UI language constant (<c>LANG_ENGLISH</c>, <c>LANG_GERMAN</c> or <c>LANG_FRENCH</c>).
/// </summary>
/// <remarks>
/// The language is determined once from the <c>LANGDIR</c> environment variable
/// and cached. Falls back to <c>LANG_ENGLISH</c>.
/// </remarks>
/// <returns><c>LANG_GERMAN</c>, <c>LANG_FRENCH</c> or <c>LANG_ENGLISH</c>.</returns>
function GetLang: Cardinal;
/// <summary>
/// Translation placeholder mirroring the dxgettext signature; currently returns the input string unchanged.
/// </summary>
/// <param name="S">Source string to be translated.</param>
/// <returns>The unaltered <paramref name="S"/> value.</returns>
function _(const S: WideString): string;

implementation

uses
  Winapi.Windows, System.SysUtils;

var
  Lang: Cardinal = Cardinal(-1);

function _(const S: WideString): string;
begin
  // placeholder for dxgettext
  Result := S;
end;

/// <returns><c>LANG_GERMAN</c>, <c>LANG_FRENCH</c> or <c>LANG_ENGLISH</c>.</returns>
function GetLang: Cardinal;
var
  App: string;
begin
  if Lang = Cardinal(-1) then
  begin
    App := GetEnvironmentVariable('LANGDIR');
    if SameText(App, 'de') then
      Lang := LANG_GERMAN
    else if SameText(App, 'fr') or SameText(App, 'fra') then
      Lang := LANG_FRENCH
    else
      Lang := LANG_ENGLISH;
    {App := ChangeFileExt(ParamStr(0), '');
    case SysLocale.PriLangID of
      LANG_GERMAN:
        if GetFileAttributes(PChar(App + '.de')) and FILE_ATTRIBUTE_DIRECTORY = 0 then
          Lang := LANG_GERMAN;
      LANG_FRENCH:
        if GetFileAttributes(PChar(App + '.fra')) and FILE_ATTRIBUTE_DIRECTORY = 0 then
          Lang := LANG_FRENCH;
        else
        if GetFileAttributes(PChar(App + '.fr')) and FILE_ATTRIBUTE_DIRECTORY = 0 then
          Lang := LANG_FRENCH;
    end;}
  end;
  Result := Lang;
end;

function FromLang(const Eng, Ger, Fra: string): string;
begin
  case GetLang of
    LANG_GERMAN: Result := Ger;
    LANG_FRENCH: Result := Fra;
  else
    Result := Eng;
  end;
end;


function sSearchComponent: string;
begin
  Result := FromLang(sSearchComponent_Eng,
                     sSearchComponent_Ger,
                     sSearchComponent_Fra);
end;

function sFilesCompiled: string;
begin
  Result := FromLang(sFilesCompiled_Eng,
                     sFilesCompiled_Ger,
                     sFilesCompiled_Fra);
end;

function sAutoCloseCaption: string;
begin
  Result := FromLang(sAutoCloseCaption_Eng,
                     sAutoCloseCaption_Ger,
                     sAutoCloseCaption_Fra);
end;

function sMenuItemManageProjectSettings: string;
begin
  Result := FromLang(sMenuItemManageProjectSettings_Eng,
                     sMenuItemManageProjectSettings_Ger,
                     sMenuItemManageProjectSettings_Fra);
end;

function sMenuItemProjectSettings: string;
begin
  Result := FromLang(sMenuItemProjectSettings_Eng,
                     sMenuItemProjectSettings_Ger,
                     sMenuItemProjectSettings_Fra);
end;

function sMenuItemSetVersionInfo: string;
begin
  Result := FromLang(sMenuItemSetVersionInfo_Eng,
                     sMenuItemSetVersionInfo_Ger,
                     sMenuItemSetVersionInfo_Fra);
end;

function sMenuItemDDevExtensionsOptions: string;
begin
  Result := FromLang(sMenuItemDDevExtensionsOptions_Eng,
                     sMenuItemDDevExtensionsOptions_Ger,
                     sMenuItemDDevExtensionsOptions_Fra);
end;

function sMenuItemDDevExtensionsFileSelector: string;
begin
  Result := FromLang(sMenuItemDDevExtensionsFileSelector_Eng,
                     sMenuItemDDevExtensionsFileSelector_Ger,
                     sMenuItemDDevExtensionsFileSelector_Fra);
end;

function sParseErrorUsesLocationNotFound: string;
begin
  Result := FromLang(sParseErrorUsesLocationNotFound_Eng,
                     sParseErrorUsesLocationNotFound_Ger,
                     sParseErrorUsesLocationNotFound_Fra);
end;

function sCapSwitchToModuleProject: string;
begin
  Result := FromLang(sCapSwitchToModuleProject_Eng,
                     sCapSwitchToModuleProject_Ger,
                     sCapSwitchToModuleProject_Fra);
end;

function sLblSwitchCurrentModuleProject: string;
begin
  Result := FromLang(sLblSwitchCurrentModuleProject_Eng,
                     sLblSwitchCurrentModuleProject_Ger,
                     sLblSwitchCurrentModuleProject_Fra);
end;

function sLblSwitchToModuleProjectQuestion: string;
begin
  Result := FromLang(sLblSwitchToModuleProjectQuestion_Eng,
                     sLblSwitchToModuleProjectQuestion_Ger,
                     sLblSwitchToModuleProjectQuestion_Fra);
end;

function sLblDontShowAgain: string;
begin
  Result := FromLang(sLblDontShowAgain_Eng,
                     sLblDontShowAgain_Ger,
                     sLblDontShowAgain_Fra);
end;

function sLblActiveProject: string;
begin
  Result := FromLang(sLblActiveProject_Eng,
                     sLblActiveProject_Ger,
                     sLblActiveProject_Fra);
end;

function sLblActiveModule: string;
begin
  Result := FromLang(sLblActiveModule_Eng,
                     sLblActiveModule_Ger,
                     sLblActiveModule_Fra);
end;

function sLblTemporarySwitch: string;
begin
  Result := FromLang(sLblTemporarySwitch_Eng,
                     sLblTemporarySwitch_Ger,
                     sLblTemporarySwitch_Fra);
end;

function sDoYouWantToInvokeTheContextHelp: string;
begin
  Result := FromLang(sDoYouWantToInvokeTheContextHelp_Eng,
                     sDoYouWantToInvokeTheContextHelp_Ger,
                     sDoYouWantToInvokeTheContextHelp_Fra);
end;

function sCannotUnloadModuleForm: string;
begin
  Result := FromLang(sCannotUnloadModuleForm_Eng,
                     sCannotUnloadModuleForm_Ger,
                     sCannotUnloadModuleForm_Fra);
end;

function sLVGroup_ProjectFiles: string;
begin
  Result := FromLang(sLVGroup_ProjectFiles_Eng,
                     sLVGroup_ProjectFiles_Ger,
                     sLVGroup_ProjectFiles_Fra);
end;

function sLVGroup_UnitFiles: string;
begin
  Result := FromLang(sLVGroup_UnitFiles_Eng,
                     sLVGroup_UnitFiles_Ger,
                     sLVGroup_UnitFiles_Fra);
end;

function sLVGroup_Forms: string;
begin
  Result := FromLang(sLVGroup_Forms_Eng,
                     sLVGroup_Forms_Ger,
                     sLVGroup_Forms_Fra);
end;

function sReloadButton: string;
begin
  Result := FromLang(sReloadButton_Eng,
                     sReloadButton_Ger,
                     sReloadButton_Fra);
end;

function sReloadChangedFilesCaption: string;
begin
  Result := FromLang(sReloadChangedFilesCaption_Eng,
                     sReloadChangedFilesCaption_Ger,
                     sReloadChangedFilesCaption_Fra);
end;

function sLVColumn_File: string;
begin
  Result := FromLang(sLVColumn_File_Eng,
                     sLVColumn_File_Ger,
                     sLVColumn_File_Fra);
end;

function sLVColumn_Path: string;
begin
  Result := FromLang(sLVColumn_Path_Eng,
                     sLVColumn_Path_Ger,
                     sLVColumn_Path_Fra);
end;

function sReloadSelectOnlyUnmodifiedField: string;
begin
  Result := FromLang(sReloadSelectOnlyUnmodifiedField_Eng,
                     sReloadSelectOnlyUnmodifiedField_Ger,
                     sReloadSelectOnlyUnmodifiedField_Fra);
end;

function sReloadSelectOnlyModifiedFiles: string;
begin
  Result := FromLang(sReloadSelectOnlyModifiedFiles_Eng,
                     sReloadSelectOnlyModifiedFiles_Ger,
                     sReloadSelectOnlyModifiedFiles_Fra);
end;

function sReloadSelectAll: string;
begin
  Result := FromLang(sReloadSelectAll_Eng,
                     sReloadSelectAll_Ger,
                     sReloadSelectAll_Fra);
end;

function sReloadDeselectAll: string;
begin
  Result := FromLang(sReloadDeselectAll_Eng,
                     sReloadDeselectAll_Ger,
                     sReloadDeselectAll_Fra);
end;

function sReloadInvertSelection: string;
begin
  Result := FromLang(sReloadInvertSelection_Eng,
                     sReloadInvertSelection_Ger,
                     sReloadInvertSelection_Fra);
end;

function sReloadShowInExplorer: string;
begin
  Result := FromLang(sReloadShowInExplorer_Eng,
                     sReloadShowInExplorer_Ger,
                     sReloadShowInExplorer_Fra);
end;


end.
