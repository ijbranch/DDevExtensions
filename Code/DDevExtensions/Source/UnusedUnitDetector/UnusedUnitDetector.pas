{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit UnusedUnitDetector;

/// <summary>
/// Implements the Unused Unit Detector DDevExtensions plugin: analyses each unit's
/// uses clauses against its source code to identify uses entries whose identifiers
/// do not appear to be referenced.
/// </summary>
/// <remarks>
/// Detection is heuristic. The analyser uses a built-in table of well-known identifiers
/// for common RTL/VCL units and a substring whole-word search for everything else.
/// False positives are filtered through a user-configurable ignore list.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Generics.Collections, Vcl.Menus, System.Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main, UnusedUnitCore, ProjectSources;

type
  /// <summary>
  /// Plugin host: registers the menu item, owns the persisted ignore list and exposes
  /// the entry point for displaying the detector form.
  /// </summary>
  TUnusedUnitDetectorPlugin = class( TPluginConfig )
  private
    /// <summary>Backing field for <see cref="Enabled"/>.</summary>
    FEnabled: Boolean;
    /// <summary>List of unit names to skip during analysis (e.g. Windows, Messages).</summary>
    FIgnoreList: TStringList;
    /// <summary>Owned menu item under the DDevExtensions submenu.</summary>
    FMenuItem: TMenuItem;
    /// <summary>Menu click handler that opens the detector form, unless the plugin is disabled.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure MenuItemClick( Sender: TObject );
    /// <summary>Property setter for the comma-text serialised ignore list.</summary>
    /// <param name="Value">The comma-text form of the ignore list.</param>
    procedure SetIgnoreListText( const Value: string );
    /// <summary>Property getter for the comma-text serialised ignore list.</summary>
    /// <returns>The ignore list as comma text.</returns>
    function GetIgnoreListText: string;
  protected
    /// <summary>Returns the IDE Tools options page for this plugin.</summary>
    /// <returns>The page shown under this plugin in the DDevExtensions options.</returns>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises default option values and seeds the ignore list.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the plugin, the ignore list and the menu item.</summary>
    constructor Create;
    /// <summary>Releases the menu item and the ignore list.</summary>
    destructor Destroy; override;
    /// <summary>Opens (or focuses) the Unused Unit Detector form.</summary>
    procedure ShowDetector;
    /// <summary>Read-only access to the ignore list.</summary>
    property IgnoreList: TStringList read FIgnoreList;
  published
    /// <summary>Whether the plugin's features are enabled.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
    /// <summary>Comma-text serialisation of the ignore list (used by the configuration storage).</summary>
    property IgnoreListText: string read GetIgnoreListText write SetIgnoreListText;
  end;

/// <summary>
/// Analyses every .pas unit of Project.  Used units are resolved to their source through the
/// project's own modules first, then the project directory and its search path; a used unit
/// whose source cannot be found is never reported.  Each unit is read from its open editor buffer
/// when it has one, else from disk, and its form file (.dfm) is read when present.
/// </summary>
/// <param name="Analyzer">The analyser; its ignore list should already be set.</param>
/// <param name="Project">The project to analyse.</param>
/// <param name="OnProgress">Optional progress callback; it can cancel the scan.</param>
/// <param name="AllUnusedUnits">Receives the suspected unused uses entries.</param>
/// <param name="SkippedFiles">Receives the number of units that could not be read.</param>
/// <returns>True when the scan ran to the end; False when there was no project or it was cancelled.</returns>
function AnalyzeProject( Analyzer: TUnitAnalyzer; const Project: IOTAProject; OnProgress: TSourceScanProgressEvent;
  out AllUnusedUnits: TArray<TUnusedUnitInfo>; out SkippedFiles: Integer ): Boolean;

const
  /// <summary>The limit the detector cannot see past, shown with its results and on its options page.</summary>
  UnusedUnitInlineNote =
    'A unit can be needed only so that an inline routine from another unit can expand there; nothing ' +
    'names it, so it cannot be detected and may be listed here.  Removing it then gives hint H2443 ' +
    '(inline function not expanded) - rebuild after removing a unit, and put it back if that hint appears.';

/// <summary>Plugin entry point invoked by the IDE host to load or unload the plugin singleton.</summary>
/// <param name="Unload">When True the plugin is unloaded; otherwise it is loaded.</param>
procedure InitPlugin( Unload: Boolean );

var
  /// <summary>Singleton instance of the Unused Unit Detector plugin.</summary>
  UnusedUnitDetectorPlugin: TUnusedUnitDetectorPlugin;

implementation

uses
  Vcl.Forms, Vcl.Controls, Vcl.Dialogs, ToolsAPIHelpers, AppConsts,
  FrmUnusedUnitDetector, FrmeOptionPageUnusedUnitDetector;

/// <summary>Reads a form file as text; a binary .dfm is converted to its text form.</summary>
/// <param name="FileName">Full path of the .dfm.</param>
/// <param name="FormText">Receives the form text; empty when there is no form file.</param>
/// <returns>
/// False when the form file exists but cannot be converted: its streamed classes are then unknown,
/// so the unit must not be analysed (a unit used only by its form would look unused).
/// </returns>
/// <exception cref="EStreamError">Raised when the form file exists but cannot be opened.</exception>
function ReadFormText( const FileName: string; out FormText: string ): Boolean;
begin
  FormText          := '';
  Result            := True;
  if not FileExists( FileName ) then
    Exit;

  var oInput        := TFileStream.Create( FileName, fmOpenRead or fmShareDenyWrite );
  try
    var oText       := TStringStream.Create( '', TEncoding.UTF8 );
    try
      try
        if TestStreamFormat( oInput ) = sofBinary then
          ObjectResourceToText( oInput, oText )
        else
          oText.CopyFrom( oInput, 0 );
        FormText    := oText.DataString;
      except
        on E: EParserError do
          Result    := False;
      end;
    finally
      oText.Free;
    end;
  finally
    oInput.Free;
  end;
end;

function AnalyzeProject( Analyzer: TUnitAnalyzer; const Project: IOTAProject; OnProgress: TSourceScanProgressEvent;
  out AllUnusedUnits: TArray<TUnusedUnitInfo>; out SkippedFiles: Integer ): Boolean;
begin
  Result            := False;
  AllUnusedUnits    := nil;
  SkippedFiles      := 0;

  if Project = nil then
    Exit;

  var aFiles        := GetProjectSourceFiles( Project, [ '.pas' ] );

  // Unit name -> file: the project's own units first, then the project directory and search path.
  var oUnitFiles    := TDictionary<string, string>.Create;
  var oSearchDirs   := TStringList.Create;
  var oAll          := TList<TUnusedUnitInfo>.Create;
  try
    for var sFileName in aFiles do
      oUnitFiles.AddOrSetValue( UpperCase( ChangeFileExt( ExtractFileName( sFileName ), '' ) ), sFileName );

    oSearchDirs.Add( ExtractFileDir( Project.FileName ) );
    var oOptions    := Project.ProjectOptions;
    if oOptions <> nil then
      for var sDir in VarToStr( oOptions.Values[ 'UnitDir' ] ).Split( [ ';' ] ) do
        if ( Trim( sDir ) <> '' ) and ( Pos( '$(', sDir ) = 0 ) then
          oSearchDirs.Add( ExpandFileName( Trim( sDir ) ) );

    Analyzer.OnResolveUnit :=
      function( const UnitName: string; out Source: string ): Boolean
      begin
        Source      := '';
        var sFile: string;
        if not oUnitFiles.TryGetValue( UpperCase( UnitName ), sFile ) then
        begin
          sFile     := '';
          for var sDir in oSearchDirs do
            if FileExists( IncludeTrailingPathDelimiter( sDir ) + UnitName + '.pas' ) then
            begin
              sFile := IncludeTrailingPathDelimiter( sDir ) + UnitName + '.pas';
              Break;
            end;
          oUnitFiles.Add( UpperCase( UnitName ), sFile ); // cache misses too
        end;

        Result      := sFile <> '';
        if Result then
          try
            Source  := UTF8ToString( ReadModuleSource( sFile ) );
          except
            on E: EStreamError do
              Result := False; // unreadable: unknown, so never reported
          end;
      end;

    try
      for var sFileName in aFiles do
      begin
        if ScanShouldStop( OnProgress, 'Analysing: ' + ExtractFileName( sFileName ) ) then
          Exit;

        try
          var sFormText: string;
          if not ReadFormText( ChangeFileExt( sFileName, '.dfm' ), sFormText ) then
          begin
            Inc( SkippedFiles );
            Continue;
          end;

          var sContent := UTF8ToString( ReadModuleSource( sFileName ) );
          var aUnused: TArray<TUnusedUnitInfo>;
          if Analyzer.AnalyseSource( sFileName, sContent, sFormText, aUnused ) then
            oAll.AddRange( aUnused )
          else
            Inc( SkippedFiles ); // not judged (an include file after "interface")
        except
          on E: EStreamError do
            Inc( SkippedFiles ); // locked / unreadable unit: skip it, the rest of the scan still runs
          on E: EOSError do
            Inc( SkippedFiles );
        end;
      end;
    finally
      Analyzer.OnResolveUnit := nil; // drop the captured lookups before they are freed
    end;

    AllUnusedUnits  := oAll.ToArray;
    Result          := True;
  finally
    oAll.Free;
    oSearchDirs.Free;
    oUnitFiles.Free;
  end;
end;

{ TUnusedUnitDetectorPlugin }

constructor TUnusedUnitDetectorPlugin.Create;
begin

  // Create FIgnoreList before inherited, because inherited calls Init and loads config
  FIgnoreList       := TStringList.Create;
  FIgnoreList.CaseSensitive := False;
  FIgnoreList.Sorted := True;
  FIgnoreList.Duplicates := dupIgnore;

  inherited Create( AppDataDirectory + '\UnusedUnitDetector.xml', 'UnusedUnitDetector' );

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem       := TMenuItem.Create( DDevExtensionsMenu );
    FMenuItem.Caption := 'Unused &Unit Detector...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add( FMenuItem );
  end;

end;

destructor TUnusedUnitDetectorPlugin.Destroy;
begin

  FreeAndNil( FMenuItem );
  FreeAndNil( FIgnoreList );
  inherited Destroy;

end;

procedure TUnusedUnitDetectorPlugin.Init;
begin

  FEnabled          := True;
  // Default ignore list - commonly used units that are often required but hard to detect
  FIgnoreList.Add( 'Windows' );
  FIgnoreList.Add( 'Messages' );
  FIgnoreList.Add( 'System' );
  FIgnoreList.Add( 'SysInit' );

end;

function TUnusedUnitDetectorPlugin.GetIgnoreListText: string;
begin

  Result            := FIgnoreList.CommaText;

end;

procedure TUnusedUnitDetectorPlugin.SetIgnoreListText( const Value: string );
begin

  FIgnoreList.CommaText := Value;

end;

function TUnusedUnitDetectorPlugin.GetOptionPages: TTreePage;
begin

  Result            := TTreePage.Create( 'Unused Unit Detector', TFrameOptionPageUnusedUnitDetector, Self );

end;

procedure TUnusedUnitDetectorPlugin.MenuItemClick( Sender: TObject );
begin
  if not FEnabled then
  begin
    ShowMessage( 'The Unused Unit Detector is disabled. Enable it in the DDevExtensions options.' );
    Exit;
  end;

  ShowDetector;
end;

procedure TUnusedUnitDetectorPlugin.ShowDetector;
begin

  TFormUnusedUnitDetector.Execute;

end;

procedure InitPlugin( Unload: Boolean );
begin

  if ( not Unload ) then
    UnusedUnitDetectorPlugin := TUnusedUnitDetectorPlugin.Create
  else
  begin
    // Close any open detector form first so it cannot reference freed plugin
    // state, then free the plugin defensively (Assigned guards a failed load).
    TFormUnusedUnitDetector.CloseInstance;

    if Assigned( UnusedUnitDetectorPlugin ) then
      FreeAndNil( UnusedUnitDetectorPlugin );
  end;

end;

end.

