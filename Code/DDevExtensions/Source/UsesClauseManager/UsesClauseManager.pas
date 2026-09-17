{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit UsesClauseManager;

/// <summary>
/// Implements the Uses Clause Manager DDevExtensions plugin: scans the search path to
/// build an identifier-export database, analyses a unit to determine the optimal
/// interface vs implementation placement of each used unit, and rewrites the source.
/// </summary>
/// <remarks>
/// The plugin host (<see cref="TUsesClauseManagerPlugin"/>) owns a project-wide
/// <see cref="TUnitExportsDatabase"/>; the form in FrmUsesClauseManager drives the
/// analyse/apply workflow.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Variants, System.Generics.Collections, Vcl.Menus,
  ToolsAPI, FrmTreePages, PluginConfig, Main, UsesClauseManagerCore;

type
  { The analysis types live in UsesClauseManagerCore, which is RTL-only and therefore testable
    outside the IDE. They are re-exported here so that this unit's published interface is
    unchanged by the extraction and existing consumers need no edit. }

  /// <summary>Identifies which uses-clause section a unit appears in.</summary>
  TUsesSection = UsesClauseManagerCore.TUsesSection;
  /// <summary>Categorises an identifier exported from a unit's interface section.</summary>
  TExportKind = UsesClauseManagerCore.TExportKind;
  /// <summary>One identifier exported from a unit's interface section.</summary>
  TUnitExport = UsesClauseManagerCore.TUnitExport;
  /// <summary>Result for a single used unit: where it currently lives, where it should live and why.</summary>
  TUnitPlacement = UsesClauseManagerCore.TUnitPlacement;
  /// <summary>One reference to a unit appearing in a uses clause, along with its line number.</summary>
  TUsedUnitInfo = UsesClauseManagerCore.TUsedUnitInfo;
  /// <summary>Database of what identifiers each unit exports.</summary>
  TUnitExportsDatabase = UsesClauseManagerCore.TUnitExportsDatabase;
  /// <summary>Records which identifiers a unit uses in its interface vs implementation sections.</summary>
  TIdentifierUsageAnalyzer = UsesClauseManagerCore.TIdentifierUsageAnalyzer;
  /// <summary>Computes placement recommendations and rewrites the uses clauses.</summary>
  TUsesClauseRefactorer = UsesClauseManagerCore.TUsesClauseRefactorer;

const
  { An enumerated type alias does not bring its values into scope, so the values are
    re-exported as constants alongside it. }
  usInterface = UsesClauseManagerCore.usInterface;
  usImplementation = UsesClauseManagerCore.usImplementation;
  ekType = UsesClauseManagerCore.ekType;
  ekProcedure = UsesClauseManagerCore.ekProcedure;
  ekFunction = UsesClauseManagerCore.ekFunction;
  ekConst = UsesClauseManagerCore.ekConst;
  ekVar = UsesClauseManagerCore.ekVar;

type

  /// <summary>
  /// Adds the IDE-facing entry point to the RTL-only <see cref="TUnitExportsDatabase"/>: derives the
  /// directories to scan from an open project and delegates to <c>BuildFromDirectories</c>.
  /// </summary>
  /// <remarks>This is the only part of the Uses Clause Manager analysis that needs ToolsAPI, which is
  /// why it is a helper here rather than a method on the core class.</remarks>
  TUnitExportsDatabaseIDEHelper = class helper for TUnitExportsDatabase
  public
    /// <summary>Builds the database by scanning every .pas file in the project's search paths.</summary>
    /// <param name="Project">The project whose options provide the search path.</param>
    /// <param name="OnProgress">Optional callback fired per file (read <c>ProgressFileName</c> for the current file).</param>
    procedure BuildFromSearchPath( Project: IOTAProject; OnProgress: TNotifyEvent );
  end;

  /// <summary>
  /// Plugin host: registers the menu item, owns the persistent options and the shared
  /// <see cref="TUnitExportsDatabase"/> used across analysis runs.
  /// </summary>
  TUsesClauseManagerPlugin = class( TPluginConfig )
  private
    /// <summary>Backing field for <see cref="Enabled"/>.</summary>
    FEnabled: Boolean;
    /// <summary>Owned menu item under the DDevExtensions submenu.</summary>
    FMenuItem: TMenuItem;
    /// <summary>Project-wide exports database, built on demand and cached.</summary>
    FExportsDB: TUnitExportsDatabase;
    /// <summary>Menu click handler that opens the manager form.</summary>
    procedure MenuItemClick( Sender: TObject );
  protected
    /// <summary>Returns the IDE Tools options page for this plugin.</summary>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises default option values.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the plugin, the exports database and the menu item.</summary>
    constructor Create;
    /// <summary>Releases the menu item and the exports database.</summary>
    destructor Destroy; override;
    /// <summary>Opens (or focuses) the Uses Clause Manager form.</summary>
    procedure ShowManager;
    /// <summary>Read-only access to the shared exports database.</summary>
    property ExportsDB: TUnitExportsDatabase read FExportsDB;
  published
    /// <summary>Whether the plugin's features are enabled.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

/// <summary>
/// Plugin entry point invoked by the IDE host to load or unload the plugin singleton.
/// </summary>
/// <param name="Unload">When True the plugin is unloaded; otherwise it is loaded.</param>
procedure InitPlugin( Unload: Boolean );

var
  /// <summary>Singleton instance of the Uses Clause Manager plugin.</summary>
  UsesClauseManagerPlugin: TUsesClauseManagerPlugin;
implementation

uses
  FrmUsesClauseManager, FrmeOptionPageUsesClause;

{ TUnitExportsDatabaseIDEHelper }

procedure TUnitExportsDatabaseIDEHelper.BuildFromSearchPath( Project: IOTAProject;
  OnProgress: TNotifyEvent );
var
  Options: IOTAProjectOptions;
  SearchPath: string;
  Paths: TStringList;
begin
  Clear;

  if Project = nil then
    Exit;

  Paths := TStringList.Create;
  try
    // Add project directory
    Paths.Add( ExtractFileDir( Project.FileName ) );

    // Get search paths from project options.
    // NOTE: assigning DelimitedText REPLACES the list, so the project directory added above is
    // discarded whenever the project has options. That is the behaviour this extraction preserves
    // deliberately - changing it is a separate, now-testable decision.
    Options := Project.ProjectOptions;
    if Options <> nil then
    begin
      SearchPath := VarToStr( Options.Values[ 'UnitDir' ] );
      Paths.Delimiter := ';';
      Paths.StrictDelimiter := True;
      Paths.DelimitedText := SearchPath;
    end;

    BuildFromDirectories( Paths, OnProgress );
  finally
    Paths.Free;
  end;
end;

{ TUsesClauseManagerPlugin }

constructor TUsesClauseManagerPlugin.Create;
begin
  FExportsDB := TUnitExportsDatabase.Create;

  inherited Create( AppDataDirectory + '\UsesClauseManager.xml', 'UsesClauseManager' );

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem := TMenuItem.Create( DDevExtensionsMenu );
    FMenuItem.Caption := 'Uses Clause &Manager...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add( FMenuItem );
  end;
end;

destructor TUsesClauseManagerPlugin.Destroy;
begin
  FreeAndNil( FMenuItem );
  FreeAndNil( FExportsDB );
  inherited Destroy;
end;

procedure TUsesClauseManagerPlugin.Init;
begin
  FEnabled := True;
end;

function TUsesClauseManagerPlugin.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create( 'Uses Clause Manager', TFrameOptionPageUsesClause, Self );
end;

procedure TUsesClauseManagerPlugin.MenuItemClick( Sender: TObject );
begin
  ShowManager;
end;

procedure TUsesClauseManagerPlugin.ShowManager;
begin
  TFormUsesClauseManager.Execute;
end;

procedure InitPlugin( Unload: Boolean );
begin
  if not Unload then
    UsesClauseManagerPlugin := TUsesClauseManagerPlugin.Create
  else
  begin
    UsesClauseManagerPlugin.Free;
    UsesClauseManagerPlugin := nil;
  end;
end;

end.
