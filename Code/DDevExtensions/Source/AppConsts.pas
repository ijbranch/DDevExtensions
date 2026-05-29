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
  /// <summary>English-language caption literals. Each constant has matching <c>_Ger</c> and <c>_Fra</c> siblings selected at run-time by <see cref="FromLang"/>.</summary>
  // English
  sSearchComponent_Eng = '(search component)';
  sFilesCompiled_Eng = '%d files compiled';
  sAutoCloseCaption_Eng = '&Automatically close on successful compile';
  sMenuItemManageProjectSettings_Eng = 'Manage Configurations...';
  sMenuItemProjectSettings_Eng = 'Project Configurations';
  sMenuItemSetVersionInfo_Eng = 'Set Versioninfo...';
  sMenuItemDDevExtensionsOptions_Eng = 'DDevExtensions options...';
  sMenuItemDDevExtensionsFileSelector_Eng = 'Find Unit-File...';
  sParseErrorUsesLocationNotFound_Eng = 'Parser Error: Failed to find the position for "uses"';

  sCapSwitchToModuleProject_Eng = 'Compile/Build - Switch Active Project';
  sLblSwitchCurrentModuleProject_Eng = 'The module is neither part of the active project nor is it in a direct or indirect dependent project.';
  sLblSwitchToModuleProjectQuestion_Eng = 'Do you want to &switch to the module''s project?';
  sLblDontShowAgain_Eng = '&Don''t show again';
  sLblTemporarySwitch_Eng = 'Switch &temporary [Shift-Key]';
  sLblActiveProject_Eng = 'Active Project:';
  sLblActiveModule_Eng = 'Active Module:';

  sDoYouWantToInvokeTheContextHelp_Eng = 'Do you want to invoke the context help?';

  sCannotUnloadModuleForm_Eng = 'Cannot unload form ''%s''';
  sLVGroup_ProjectFiles_Eng = 'Project files';
  sLVGroup_UnitFiles_Eng = 'Units/Files';
  sLVGroup_Forms_Eng = 'Forms/Frames/DataModules';
  sReloadButton_Eng = '&Reload';
  sReloadChangedFilesCaption_Eng = 'Reload changed files';
  sLVColumn_File_Eng = 'File';
  sLVColumn_Path_Eng = 'Path';

  sReloadSelectOnlyUnmodifiedField_Eng = 'Select &unmodified buffers';
  sReloadSelectOnlyModifiedFiles_Eng = 'Select &modified buffers';
  sReloadSelectAll_Eng = 'Select &all';
  sReloadDeselectAll_Eng = '&Deselect all';
  sReloadInvertSelection_Eng = '&Invert selection';
  sReloadShowInExplorer_Eng = 'Show in &Explorer';

  // German
  sSearchComponent_Ger = '(Komponente suchen)';
  sFilesCompiled_Ger = '%d Dateien compiliert';
  sAutoCloseCaption_Ger = '&Nach erfolgreicher Compilierung automatisch schließen';
  sMenuItemManageProjectSettings_Ger = 'Einstellungen...';
  sMenuItemProjectSettings_Ger = 'Projekt Konfigurationen';
  sMenuItemSetVersionInfo_Ger = 'Versionsinfo setzen...';
  sMenuItemDDevExtensionsOptions_Ger = 'DDevExtensions Optionen...';
  sMenuItemDDevExtensionsFileSelector_Ger = 'Unit-Datei suchen...';
  sParseErrorUsesLocationNotFound_Ger = 'Parser Fehler: Position zum Einfügen des "uses" konnte nicht ermittelt werden';

  sCapSwitchToModuleProject_Ger = 'Compilieren/Erzeugen - Aktives Projekt wechseln';
  sLblSwitchCurrentModuleProject_Ger = 'Die Datei gehört weder zum aktiven Projekt noch zu einem direkt oder indirekt abhängigen Projekt.';
  sLblSwitchToModuleProjectQuestion_Ger = '&Soll zum Projekt der Datei gewechselt werden?';
  sLblDontShowAgain_Ger = '&Nicht mehr anzeigen';
  sLblTemporarySwitch_Ger = '&Temporär wechseln [Umschalt-Taste]';
  sLblActiveProject_Ger = 'Aktives Projekt:';
  sLblActiveModule_Ger = 'Aktive Datei:';

  sDoYouWantToInvokeTheContextHelp_Ger = 'Soll die Kontexthilfe aufgerufen werden?';

  sCannotUnloadModuleForm_Ger = 'Formular kann nicht entladen werden: %s';
  sLVGroup_ProjectFiles_Ger = 'Projektdateien';
  sLVGroup_UnitFiles_Ger = 'Units/Dateien';
  sLVGroup_Forms_Ger = 'Formulare/Frames/Datenmodule';
  sReloadButton_Ger = '&Neuladen';
  sReloadChangedFilesCaption_Ger = 'Veränderte Dateien neuladen';
  sLVColumn_File_Ger = 'Datei';
  sLVColumn_Path_Ger = 'Pfad';

  sReloadSelectOnlyUnmodifiedField_Ger = 'Unveränderte Puffer auswählen';
  sReloadSelectOnlyModifiedFiles_Ger = '&Veränderte Puffer auswählen';
  sReloadSelectAll_Ger = '&Alle auswählen';
  sReloadDeselectAll_Ger = 'A&uswahl aufheben';
  sReloadInvertSelection_Ger = 'Auswahl um&kehren';
  sReloadShowInExplorer_Ger = 'Im &Explorer anzeigen';

  // French
  sSearchComponent_Fra = '(chercher un composant)';
  sFilesCompiled_Fra = '%d fichiers compilés';
  sAutoCloseCaption_Fra = 'Fermer &Automatiquement à la réussite de la compilation';
  sMenuItemManageProjectSettings_Fra = 'Gérer les configurations...';
  sMenuItemProjectSettings_Fra = 'Configurations du projet';
  sMenuItemSetVersionInfo_Fra = 'Affecter les infos de version...';
  sMenuItemDDevExtensionsOptions_Fra = 'Options DDevExtensions...';
  sMenuItemDDevExtensionsFileSelector_Fra = 'Trouver le fichier unité...';
  sParseErrorUsesLocationNotFound_Fra = 'Erreur du Parser : Impossible de trouver la position de "uses"';

  sCapSwitchToModuleProject_Fra = 'Compiler/Construire - Changer de projet actif';
  sLblSwitchCurrentModuleProject_Fra = 'Le module ne fait partie ni du projet actif ni d''un projet dépendant directement ou indirectement';
  sLblSwitchToModuleProjectQuestion_Fra = 'Voulez-vous pa&sser sur le projet de ce module?';
  sLblDontShowAgain_Fra = '&Ne plus afficher';
  sLblTemporarySwitch_Fra = 'Changer &temporairement [Touche Maj]';
  sLblActiveProject_Fra = 'Projet actif:';
  sLblActiveModule_Fra = 'Module actif:';

  sDoYouWantToInvokeTheContextHelp_Fra = sDoYouWantToInvokeTheContextHelp_Eng;

  sCannotUnloadModuleForm_Fra = sCannotUnloadModuleForm_Eng;
  sLVGroup_ProjectFiles_Fra = sLVGroup_ProjectFiles_Eng;
  sLVGroup_UnitFiles_Fra = sLVGroup_UnitFiles_Eng;
  sLVGroup_Forms_Fra = sLVGroup_Forms_Eng;
  sReloadButton_Fra = sReloadButton_Eng;
  sReloadChangedFilesCaption_Fra = sReloadChangedFilesCaption_Eng;
  sLVColumn_File_Fra = sLVColumn_File_Eng;
  sLVColumn_Path_Fra = sLVColumn_Path_Eng;

  sReloadSelectOnlyUnmodifiedField_Fra = sReloadSelectOnlyUnmodifiedField_Eng;
  sReloadSelectOnlyModifiedFiles_Fra = sReloadSelectOnlyModifiedFiles_Eng;
  sReloadSelectAll_Fra = sReloadSelectAll_Eng;
  sReloadDeselectAll_Fra = sReloadDeselectAll_Eng;
  sReloadInvertSelection_Fra = sReloadInvertSelection_Eng;
  sReloadShowInExplorer_Fra = sReloadShowInExplorer_Eng;


/// <summary>Returns the localised "(search component)" placeholder caption.</summary>
function sSearchComponent: string;
/// <summary>Returns the localised "%d files compiled" status text.</summary>
function sFilesCompiled: string;
/// <summary>Returns the localised "&amp;Automatically close on successful compile" check-box caption.</summary>
function sAutoCloseCaption: string;
/// <summary>Returns the localised "Manage Configurations..." menu caption.</summary>
function sMenuItemManageProjectSettings: string;
/// <summary>Returns the localised "Project Configurations" menu caption.</summary>
function sMenuItemProjectSettings: string;
/// <summary>Returns the localised "Set Versioninfo..." menu caption.</summary>
function sMenuItemSetVersionInfo: string;
/// <summary>Returns the localised "DDevExtensions options..." menu caption.</summary>
function sMenuItemDDevExtensionsOptions: string;
/// <summary>Returns the localised "Find Unit-File..." menu caption.</summary>
function sMenuItemDDevExtensionsFileSelector: string;
/// <summary>Returns the localised parser error message reported when the position to insert "uses" cannot be found.</summary>
function sParseErrorUsesLocationNotFound: string;

/// <summary>Returns the localised caption for the "Compile/Build - Switch Active Project" dialog.</summary>
function sCapSwitchToModuleProject: string;
/// <summary>Returns the localised explanatory text shown when the active module is not in the active project.</summary>
function sLblSwitchCurrentModuleProject: string;
/// <summary>Returns the localised "Do you want to switch to the module's project?" prompt.</summary>
function sLblSwitchToModuleProjectQuestion: string;
/// <summary>Returns the localised "Don't show again" check-box caption.</summary>
function sLblDontShowAgain: string;
/// <summary>Returns the localised "Switch temporary [Shift-Key]" caption.</summary>
function sLblTemporarySwitch: string;
/// <summary>Returns the localised "Active Project:" label caption.</summary>
function sLblActiveProject: string;
/// <summary>Returns the localised "Active Module:" label caption.</summary>
function sLblActiveModule: string;

/// <summary>Returns the localised "Do you want to invoke the context help?" prompt.</summary>
function sDoYouWantToInvokeTheContextHelp: string;

// ReloadFiles
/// <summary>Returns the localised "Cannot unload form '%s'" error message.</summary>
function sCannotUnloadModuleForm: string;
/// <summary>Returns the localised "Project files" list-view group caption.</summary>
function sLVGroup_ProjectFiles: string;
/// <summary>Returns the localised "Units/Files" list-view group caption.</summary>
function sLVGroup_UnitFiles: string;
/// <summary>Returns the localised "Forms/Frames/DataModules" list-view group caption.</summary>
function sLVGroup_Forms: string;
/// <summary>Returns the localised "Reload" button caption.</summary>
function sReloadButton: string;
/// <summary>Returns the localised caption for the Reload-Changed-Files dialog.</summary>
function sReloadChangedFilesCaption: string;
/// <summary>Returns the localised "File" list-view column caption.</summary>
function sLVColumn_File: string;
/// <summary>Returns the localised "Path" list-view column caption.</summary>
function sLVColumn_Path: string;

/// <summary>Returns the localised "Select unmodified buffers" menu caption.</summary>
function sReloadSelectOnlyUnmodifiedField: string;
/// <summary>Returns the localised "Select modified buffers" menu caption.</summary>
function sReloadSelectOnlyModifiedFiles: string;
/// <summary>Returns the localised "Select all" menu caption.</summary>
function sReloadSelectAll: string;
/// <summary>Returns the localised "Deselect all" menu caption.</summary>
function sReloadDeselectAll: string;
/// <summary>Returns the localised "Invert selection" menu caption.</summary>
function sReloadInvertSelection: string;
/// <summary>Returns the localised "Show in Explorer" menu caption.</summary>
function sReloadShowInExplorer: string;



/// <summary>
/// Returns the active UI language constant (<c>LANG_ENGLISH</c>, <c>LANG_GERMAN</c> or <c>LANG_FRENCH</c>).
/// </summary>
/// <remarks>
/// The language is determined once from the <c>LANGDIR</c> environment variable
/// and cached. Falls back to <c>LANG_ENGLISH</c>.
/// </remarks>
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
