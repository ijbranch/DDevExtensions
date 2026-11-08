{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit DeadCodeDetector;

/// <summary>
/// Implements the Dead Code Detector DDevExtensions plugin: the menu item, the persisted options
/// and the project scan that feeds every unit of the active project to the analysis core
/// (<c>DeadCodeCore</c>).
/// </summary>
/// <remarks>
/// Detection is heuristic. Published members, virtual / override / abstract methods,
/// constructors / destructors and event-handler-shaped methods are ignored, as are
/// symbols matching user-supplied wildcard patterns.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Generics.Collections, Vcl.Menus, System.Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main, DeadCodeCore, ProjectSources;

type
  /// <summary>
  /// Plugin host: registers the menu item and owns the persistent options including
  /// the user-editable ignore list of name patterns.
  /// </summary>
  TDeadCodeDetectorPlugin = class( TPluginConfig )
  private
    /// <summary>Backing field for <see cref="Enabled"/>.</summary>
    FEnabled: Boolean;
    /// <summary>Backing field for <see cref="CheckProcedures"/>.</summary>
    FCheckProcedures: Boolean;
    /// <summary>Backing field for <see cref="CheckFields"/>.</summary>
    FCheckFields: Boolean;
    /// <summary>Wildcard ignore patterns, applied to symbol names.</summary>
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
    /// <summary>Opens (or focuses) the Dead Code Detector form.</summary>
    procedure ShowDetector;
    /// <summary>Copies the current options (checks and ignore patterns) into Analyzer.</summary>
    /// <param name="Analyzer">The analyser to configure; its previous patterns are replaced.</param>
    procedure ConfigureAnalyzer( Analyzer: TDeadCodeAnalyzer );
    /// <summary>Read-only access to the ignore list.</summary>
    property IgnoreList: TStringList read FIgnoreList;
  published
    /// <summary>Whether the plugin's features are enabled.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
    /// <summary>Whether the analyser inspects procedures, functions and methods.</summary>
    property CheckProcedures: Boolean read FCheckProcedures write FCheckProcedures;
    /// <summary>Whether the analyser inspects private and protected fields.</summary>
    property CheckFields: Boolean read FCheckFields write FCheckFields;
    /// <summary>Comma-text serialisation of the ignore list (used by the configuration storage).</summary>
    property IgnoreListText: string read GetIgnoreListText write SetIgnoreListText;
  end;

/// <summary>
/// Runs the two-pass analysis over every .pas unit of Project: each unit's text is read once (the
/// open editor buffer when there is one, else the file), symbols are collected from all of them,
/// then references are scanned in the units, the files they include and the project file.
/// </summary>
/// <param name="Analyzer">The configured analyser; its previous symbols are discarded.</param>
/// <param name="Project">The project to analyse.</param>
/// <param name="OnProgress">Optional progress callback; it can cancel the scan.</param>
/// <param name="DeadCode">
/// Receives the unreferenced symbols; empty when the scan was cancelled.  When any text could not
/// be read, only private and unit-local symbols are included (the unread text may use the others).
/// </param>
/// <param name="SkippedFiles">Receives the number of units, include files and project files that could not be read.</param>
/// <returns>True when the scan ran to the end; False when there was no project or it was cancelled.</returns>
function AnalyzeProject( Analyzer: TDeadCodeAnalyzer; const Project: IOTAProject; OnProgress: TSourceScanProgressEvent;
  out DeadCode: TArray<TDeadCodeItem>; out SkippedFiles: Integer ): Boolean;

/// <summary>Plugin entry point invoked by the IDE host to load or unload the plugin singleton.</summary>
/// <param name="Unload">When True the plugin is unloaded; otherwise it is loaded.</param>
procedure InitPlugin( Unload: Boolean );

var
  /// <summary>Singleton instance of the Dead Code Detector plugin.</summary>
  DeadCodeDetectorPlugin: TDeadCodeDetectorPlugin;

implementation

uses
  Vcl.Forms, Vcl.Controls, Vcl.Dialogs, ToolsAPIHelpers, AppConsts,
  FrmDeadCodeDetector, FrmeOptionPageDeadCode;

function AnalyzeProject( Analyzer: TDeadCodeAnalyzer; const Project: IOTAProject; OnProgress: TSourceScanProgressEvent;
  out DeadCode: TArray<TDeadCodeItem>; out SkippedFiles: Integer ): Boolean;
begin
  Result            := False;
  DeadCode          := nil;
  SkippedFiles      := 0;

  if Project = nil then
    Exit;

  Analyzer.ClearSymbols;

  var aFiles        := GetProjectSourceFiles( Project, [ '.pas' ] );
  var oContents     := TDictionary<string, UTF8String>.Create;
  try
    // Pass 1: read each unit once and collect its symbols
    for var sFileName in aFiles do
    begin
      if ScanShouldStop( OnProgress, 'Collecting: ' + ExtractFileName( sFileName ) ) then
        Exit;

      if oContents.ContainsKey( sFileName ) then
        Continue;

      try
        var sContent := ReadModuleSource( sFileName );
        oContents.Add( sFileName, sContent );
        Analyzer.CollectSymbols( sFileName, sContent );
      except
        on E: EStreamError do
          Inc( SkippedFiles ); // locked / unreadable unit: skip it, the rest of the scan still runs
        on E: EOSError do
          Inc( SkippedFiles );
      end;
    end;

    // Pass 2: scan every unit for references, with the files it includes
    for var oPair in oContents do
    begin
      if ScanShouldStop( OnProgress, 'Scanning: ' + ExtractFileName( oPair.Key ) ) then
        Exit;

      Analyzer.ScanForReferences( oPair.Key, oPair.Value );

      for var sInclude in ExtractIncludeFileNames( oPair.Value ) do
      begin
        var sIncludeFile := sInclude;
        if ExtractFileDrive( sIncludeFile ) = '' then
          sIncludeFile := ExpandFileName( IncludeTrailingPathDelimiter( ExtractFilePath( oPair.Key ) ) + sIncludeFile );
        try
          if not FileExists( sIncludeFile ) then
            Inc( SkippedFiles ) // its references are unknown
          else
            Analyzer.ScanForReferences( sIncludeFile, ReadModuleSource( sIncludeFile ), oPair.Key );
        except
          on E: EStreamError do
            Inc( SkippedFiles );
          on E: EOSError do
            Inc( SkippedFiles );
        end;
      end;
    end;

    // The project file (.dpr / .dpk) calls into the units too
    var sProjectSource := '';
    for var sExt in [ '.dpr', '.dpk' ] do
      if ( sProjectSource = '' ) and FileExists( ChangeFileExt( Project.FileName, sExt ) ) then
        sProjectSource := ChangeFileExt( Project.FileName, sExt );
    if sProjectSource <> '' then
      try
        Analyzer.ScanForReferences( sProjectSource, ReadModuleSource( sProjectSource ) );
      except
        on E: EStreamError do
          Inc( SkippedFiles );
        on E: EOSError do
          Inc( SkippedFiles );
      end;

    // Text that could not be read may use anything other units can see: then only private and
    // unit-local symbols are judged.
    DeadCode        := Analyzer.GetDeadCode( SkippedFiles > 0 );
    Result          := True;
  finally
    oContents.Free;
  end;
end;

{ TDeadCodeDetectorPlugin }

constructor TDeadCodeDetectorPlugin.Create;
begin

  FIgnoreList       := TStringList.Create;
  FIgnoreList.CaseSensitive := False;

  inherited Create( AppDataDirectory + '\DeadCodeDetector.xml', 'DeadCodeDetector' );

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem       := TMenuItem.Create( DDevExtensionsMenu );
    FMenuItem.Caption := '&Dead Code Detector...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add( FMenuItem );
  end;

end;

destructor TDeadCodeDetectorPlugin.Destroy;
begin

  // Remove the item from its parent menu before freeing it, otherwise (when the
  // plugin is torn down before the menu) the menu is left holding a reference to
  // a freed item and double-frees it at its own destruction.
  if FMenuItem <> nil then
  begin
    if DDevExtensionsMenu <> nil then
      DDevExtensionsMenu.Remove( FMenuItem );
    FreeAndNil( FMenuItem );
  end;
  FreeAndNil( FIgnoreList );
  inherited Destroy;

end;

procedure TDeadCodeDetectorPlugin.Init;
begin

  FEnabled          := True;
  FCheckProcedures  := True;
  FCheckFields      := True;

  // Default ignore patterns
  FIgnoreList.Clear;
  FIgnoreList.Add( 'Create' );
  FIgnoreList.Add( 'Destroy' );
  FIgnoreList.Add( 'Initialize' );
  FIgnoreList.Add( 'Finalize' );
  FIgnoreList.Add( '*Click' );
  FIgnoreList.Add( '*Changed' );
  FIgnoreList.Add( '*Execute' );
  FIgnoreList.Add( '*Update' );

end;

function TDeadCodeDetectorPlugin.GetIgnoreListText: string;
begin

  Result            := FIgnoreList.CommaText;

end;

procedure TDeadCodeDetectorPlugin.SetIgnoreListText( const Value: string );
begin

  FIgnoreList.CommaText := Value;

end;

procedure TDeadCodeDetectorPlugin.ConfigureAnalyzer( Analyzer: TDeadCodeAnalyzer );
begin
  Analyzer.CheckProcedures := FCheckProcedures;
  Analyzer.CheckFields := FCheckFields;

  Analyzer.ClearIgnorePatterns;
  for var sPattern in FIgnoreList do
    Analyzer.AddIgnorePattern( sPattern );
end;

function TDeadCodeDetectorPlugin.GetOptionPages: TTreePage;
begin

  Result            := TTreePage.Create( 'Dead Code Detector', TFrameOptionPageDeadCode, Self );

end;

procedure TDeadCodeDetectorPlugin.MenuItemClick( Sender: TObject );
begin
  if not FEnabled then
  begin
    ShowMessage( 'The Dead Code Detector is disabled. Enable it in the DDevExtensions options.' );
    Exit;
  end;

  ShowDetector;
end;

procedure TDeadCodeDetectorPlugin.ShowDetector;
begin

  TFormDeadCodeDetector.Execute;

end;

procedure InitPlugin( Unload: Boolean );
begin

  if not Unload then
    DeadCodeDetectorPlugin := TDeadCodeDetectorPlugin.Create
  else
  begin
    // Close the form first: it is owned by the IDE's Application and would otherwise outlive the
    // plugin (and, on package unload, its own code).
    TFormDeadCodeDetector.CloseInstance;
    FreeAndNil( DeadCodeDetectorPlugin );
  end;

end;

end.

