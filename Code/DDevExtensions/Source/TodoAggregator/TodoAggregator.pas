{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit TodoAggregator;

/// <summary>
/// Plugin that scans the current project's Pascal sources for TODO/FIXME-style comments
/// and presents them in a sortable, filterable list. Provides a configurable comma-
/// separated pattern list, optional priority parsing such as TODO(high), and integrates
/// into the IDE through a DDevExtensions submenu entry.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Generics.Collections, Vcl.Menus, System.Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main, TodoAggregatorCore;

type
  /// <summary>
  /// Persistent plugin configuration that owns the menu entry and exposes Enabled/Patterns
  /// as published settings (stored in TodoAggregator.xml).
  /// </summary>
  TTodoAggregatorPlugin = class( TPluginConfig )
  private
    /// <summary>Backing field for the Enabled property.</summary>
    FEnabled: Boolean;
    /// <summary>Backing field for the Patterns property (comma-separated).</summary>
    FPatterns: string;
    /// <summary>Menu item added under the DDevExtensions submenu.</summary>
    FMenuItem: TMenuItem;
    /// <summary>OnClick handler that opens the aggregator window.</summary>
    /// <param name="Sender">The menu item clicked.</param>
    procedure MenuItemClick( Sender: TObject );
  protected
    /// <summary>Returns the configuration page shown in the IDE Options dialog.</summary>
    /// <returns>A TTreePage describing the TODO/FIXME Aggregator settings.</returns>
    function GetOptionPages: TTreePage; override;
    /// <summary>Sets default Enabled and Patterns values.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the configuration object and adds the IDE menu item.</summary>
    constructor Create;
    /// <summary>Removes the menu item.</summary>
    destructor Destroy; override;
    /// <summary>Shows the TODO aggregator form (singleton).</summary>
    procedure ShowAggregator;
  published
    /// <summary>True when the aggregator menu/feature is active (currently informational).</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
    /// <summary>Comma-separated list of category keywords used by the scanner.</summary>
    property Patterns: string read FPatterns write FPatterns;
  end;

/// <summary>
/// Collects the tagged comments of every .pas unit of a project, reading each open unit from its
/// editor buffer and any other from disk.  A file that cannot be opened is skipped.
/// </summary>
/// <param name="AScanner">The scanner, with its patterns set.</param>
/// <param name="AProject">The project to scan; nil gives no items.</param>
/// <param name="AOnProgress">Called with the scanner before each unit; it may raise
/// <c>EAbort</c> to stop the scan.</param>
/// <returns>Every item found, unit by unit.</returns>
function ScanProjectTodos( AScanner: TTodoScanner; const AProject: IOTAProject;
  AOnProgress: TNotifyEvent ): TArray<TTodoItem>;

/// <summary>
/// Creates or destroys the singleton TodoAggregator plugin instance.
/// </summary>
/// <param name="Unload">True to shut down, False to start up.</param>
procedure InitPlugin( Unload: Boolean );

var
  /// <summary>Singleton plugin instance accessed by the form and option page.</summary>
  TodoAggregatorPlugin: TTodoAggregatorPlugin;

implementation

uses
  Vcl.Forms, Vcl.Controls, ToolsAPIHelpers, AppConsts, IdeUnitSource,
  FrmTodoAggregator, FrmeOptionPageTodoAggregator;

function ScanProjectTodos( AScanner: TTodoScanner; const AProject: IOTAProject;
  AOnProgress: TNotifyEvent ): TArray<TTodoItem>;
var
  AllTodos          : TList<TTodoItem>;
  Content           : UTF8String;
begin
  Result            := nil;
  if ( AProject = nil ) then
    Exit;

  AllTodos          := TList<TTodoItem>.Create;
  try
    { The file list is taken once: the progress callback pumps messages, and the project can change
      or close meanwhile - after each pump the scan stops if it is no longer the active project. }
    var Identity    := ProjectIdentity( AProject );
    for var sFileName in ProjectPascalFiles( AProject ) do
    begin
      AScanner.ProgressFileName := ExtractFileName( sFileName );
      if Assigned( AOnProgress ) then
      begin
        AOnProgress( AScanner );
        CheckProjectUnchanged( Identity );
      end;

      { Open units are read from the editor, so unsaved TODOs count and lines match the buffer. }
      try
        if ( not ReadUnitSource( sFileName, Content ) ) then
          Continue;
      except
        { A locked or vanished file is skipped; the rest of the project is still scanned. }
        on E: EFOpenError do
        begin
          OutputDebugString( PChar( 'DDevExtensions TodoAggregator: ' + sFileName + ' - ' + E.Message ) );
          Continue;
        end;
      end;

      AllTodos.AddRange( AScanner.ScanSource( Content, sFileName ) );
    end;
    Result          := AllTodos.ToArray;
  finally
    AllTodos.Free;
  end;
end;

{ TTodoAggregatorPlugin }

constructor TTodoAggregatorPlugin.Create;
begin

  inherited Create( AppDataDirectory + '\TodoAggregator.xml', 'TodoAggregator' );

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem       := TMenuItem.Create( DDevExtensionsMenu );
    FMenuItem.Caption := 'TODO/FIXME &Aggregator...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add( FMenuItem );
  end;

end;

destructor TTodoAggregatorPlugin.Destroy;
begin

  FreeAndNil( FMenuItem );
  inherited Destroy;

end;

procedure TTodoAggregatorPlugin.Init;
begin

  FEnabled          := True;
  FPatterns         := 'TODO,FIXME,HACK,BUG,NOTE,XXX';

end;

function TTodoAggregatorPlugin.GetOptionPages: TTreePage;
begin

  Result            := TTreePage.Create( 'TODO/FIXME Aggregator', TFrameOptionPageTodoAggregator, Self );

end;

procedure TTodoAggregatorPlugin.MenuItemClick( Sender: TObject );
begin

  ShowAggregator;

end;

procedure TTodoAggregatorPlugin.ShowAggregator;
begin

  TFormTodoAggregator.Execute;

end;

procedure InitPlugin( Unload: Boolean );
begin

  if not Unload then
    TodoAggregatorPlugin := TTodoAggregatorPlugin.Create
  else
  begin
    { Close the form first: it is modeless and owned by the IDE's Application, so it would
      otherwise outlive the code that implements it. }
    TFormTodoAggregator.CloseInstance;
    FreeAndNil( TodoAggregatorPlugin );
  end;

end;

end.

