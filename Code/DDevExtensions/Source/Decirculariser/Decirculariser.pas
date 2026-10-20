{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit Decirculariser;

/// <summary>
/// Plugin host for the Decirculariser: the DDevExtensions menu item, the persisted options and
/// the IDE side of the analysis - reading the active project's units ( from the editor buffer
/// when a unit is open, so unsaved changes count ) and deleting a dead uses entry through an
/// undoable editor write.
/// </summary>
/// <remarks>
/// The analysis and the text edit themselves are <c>DecirculariserCore</c>, which is tested
/// outside the IDE. This unit only moves source between the IDE and that core.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Vcl.Menus,
  ToolsAPI, FrmTreePages, PluginConfig, Main, DecirculariserCore;

type
  /// <summary>
  /// Plugin host: registers the menu item, owns the persisted options and exposes the entry
  /// point for displaying the Decirculariser form.
  /// </summary>
  TDecirculariserPlugin = class( TPluginConfig )
  private
    /// <summary>Backing field for <see cref="Enabled"/>.</summary>
    FEnabled: Boolean;
    /// <summary>Backing field for <see cref="FewSymbolsLimit"/>.</summary>
    FFewSymbolsLimit: Integer;
    /// <summary>Owned menu item under the DDevExtensions submenu.</summary>
    FMenuItem: TMenuItem;
    /// <summary>Menu click handler that opens the Decirculariser form.</summary>
    /// <param name="Sender">The control that raised the event.</param>
    procedure MenuItemClick( Sender: TObject );
  protected
    /// <summary>Returns the IDE Tools options page for this plugin.</summary>
    /// <returns>The Decirculariser page, created for the options dialog to own.</returns>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises default option values.</summary>
    procedure Init; override;
  public
    /// <summary>Creates the plugin, loads its options and adds the menu item.</summary>
    constructor Create;
    /// <summary>Releases the menu item.</summary>
    destructor Destroy; override;
    /// <summary>Opens (or focuses) the Decirculariser form.</summary>
    procedure ShowDecirculariser;
  published
    /// <summary>Whether the plugin's features are enabled.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
    /// <summary>At and below this many crossing identifiers an edge is reported as
    /// extractable rather than as collaboration ( <see cref="TDecirculariser.FewSymbolsLimit"/> ).</summary>
    property FewSymbolsLimit: Integer read FFewSymbolsLimit write FFewSymbolsLimit;
  end;

/// <summary>
/// Adds every .pas unit of the project to the analyser, reading each from its editor buffer
/// when it is open and from disk otherwise.
/// </summary>
/// <param name="AProject">The project whose units are analysed.</param>
/// <param name="AAnalyser">The analyser the units are added to.</param>
/// <param name="AFiles">Receives each added unit's file, keyed by lower-case unit name.</param>
/// <param name="AOnProgress">Called with each file name before it is read; nil for none.</param>
/// <returns>The number of units added.  A file that cannot be read is skipped.</returns>
function AddProjectUnits( const AProject: IOTAProject; AAnalyser: TDecirculariser;
  AFiles: TDictionary<string, string>; AOnProgress: TProc<string> ): Integer;

/// <summary>
/// Deletes uses entries from one unit's implementation uses clause through an undoable editor
/// write, opening the file in the editor if it is not open.  Nothing is saved: the unit is left
/// modified for the user to compile, review and save, or undo.
/// </summary>
/// <param name="AFileName">The unit to edit.</param>
/// <param name="AUnitNames">The entries to delete from its implementation uses clause.</param>
/// <param name="AFailures">Receives one line per entry that was not deleted, with the reason.</param>
/// <returns>The number of entries deleted.</returns>
function RemoveDeadEntries( const AFileName: string; const AUnitNames: TArray<string>;
  AFailures: TStrings ): Integer;

/// <summary>Plugin entry point invoked by the IDE host to load or unload the plugin singleton.</summary>
/// <param name="Unload">When True the plugin is unloaded; otherwise it is loaded.</param>
procedure InitPlugin( Unload: Boolean );

var
  /// <summary>Singleton instance of the Decirculariser plugin.</summary>
  DecirculariserPlugin: TDecirculariserPlugin;

implementation

uses
  Winapi.Windows, System.IOUtils, UsesClauseManagerCore, ToolsAPIHelpers,
  FrmDecirculariser, FrmeOptionPageDecirculariser;

/// <summary>The open source editor of AFileName, or nil when the file is not open.</summary>
function FindSourceEditor( const AFileName: string; AOpen: Boolean ): IOTASourceEditor;
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  I: Integer;
begin
  Result := nil;
  if not Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) then
    Exit;

  Module := ModuleServices.FindModule( AFileName );
  if ( Module = nil ) and AOpen then
    Module := ModuleServices.OpenModule( AFileName );
  if Module = nil then
    Exit;

  for I := 0 to Module.ModuleFileCount - 1 do
    if Supports( Module.ModuleFileEditors[ I ], IOTASourceEditor, Result ) and
       SameText( Result.FileName, AFileName ) then
      Exit;
  Result := nil;
end;

/// <summary>A file's text as UTF-8 without a BOM; a file that is not valid UTF-8 is read as ANSI.</summary>
function ReadSourceFile( const AFileName: string ): UTF8String;
var
  Bytes: TBytes;
  iStart: Integer;
begin
  Bytes  := TFile.ReadAllBytes( AFileName );
  iStart := 0;
  if ( Length( Bytes ) >= 3 ) and ( Bytes[ 0 ] = $EF ) and ( Bytes[ 1 ] = $BB ) and ( Bytes[ 2 ] = $BF ) then
    iStart := 3;
  if Length( Bytes ) <= iStart then
    Exit( '' );

  if ( MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS,
    PAnsiChar( @Bytes[ iStart ] ), Length( Bytes ) - iStart, nil, 0 ) = 0 ) then
    Exit( UTF8Encode( TEncoding.ANSI.GetString( Bytes, iStart, Length( Bytes ) - iStart ) ) );

  SetString( Result, PAnsiChar( @Bytes[ iStart ] ), Length( Bytes ) - iStart );
end;

function AddProjectUnits( const AProject: IOTAProject; AAnalyser: TDecirculariser;
  AFiles: TDictionary<string, string>; AOnProgress: TProc<string> ): Integer;
var
  I: Integer;
  sFile: string;
  sUnit: string;
  Editor: IOTASourceEditor;
  Source: UTF8String;
begin
  Result := 0;
  if AProject = nil then
    Exit;

  for I := 0 to AProject.GetModuleCount - 1 do
  begin
    sFile := AProject.GetModule( I ).FileName;
    if not SameText( ExtractFileExt( sFile ), '.pas' ) then
      Continue;

    if Assigned( AOnProgress ) then
      AOnProgress( sFile );

    { An open unit is read from the editor, so the analysis sees what the user sees. }
    Editor := FindSourceEditor( sFile, False );
    try
      if Editor <> nil then
        Source := GetEditorSource( Editor )
      else if FileExists( sFile ) then
        Source := ReadSourceFile( sFile )
      else
        Continue;
    except
      { One unreadable unit should not cost the whole analysis. }
      Continue;
    end;

    sUnit := ChangeFileExt( ExtractFileName( sFile ), '' );
    AAnalyser.AddUnit( sUnit, Source );
    AFiles.AddOrSetValue( LowerCase( sUnit ), sFile );
    Inc( Result );
  end;
end;

function RemoveDeadEntries( const AFileName: string; const AUnitNames: TArray<string>;
  AFailures: TStrings ): Integer;
var
  Editor: IOTASourceEditor;
  Source, NewSource: UTF8String;
  sReason: string;
  sUnit: string;
  Writer: IOTAEditWriter;
begin
  Result := 0;
  Editor := FindSourceEditor( AFileName, True );
  if Editor = nil then
  begin
    for sUnit in AUnitNames do
      AFailures.Add( Format( '%s in %s: the file could not be opened in the editor',
        [ sUnit, ExtractFileName( AFileName ) ] ) );
    Exit;
  end;

  Source := GetEditorSource( Editor );
  for sUnit in AUnitNames do
    if RemoveUsesEntry( Source, sUnit, usImplementation, NewSource, sReason ) then
    begin
      Source := NewSource;
      Inc( Result );
    end
    else
      AFailures.Add( Format( '%s in %s: %s', [ sUnit, ExtractFileName( AFileName ), sReason ] ) );

  if Result = 0 then
    Exit;

  { One undoable write of the whole buffer, as the Uses Clause Manager does: Ctrl+Z restores it. }
  Writer := Editor.CreateUndoableWriter;
  try
    Writer.DeleteTo( MaxInt );
    Writer.Insert( PAnsiChar( Source ) );
  finally
    Writer := nil;
  end;
end;

{ TDecirculariserPlugin }

constructor TDecirculariserPlugin.Create;
begin
  inherited Create( AppDataDirectory + '\Decirculariser.xml', 'Decirculariser' );

  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem         := TMenuItem.Create( DDevExtensionsMenu );
    FMenuItem.Caption := 'De&circulariser...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add( FMenuItem );
  end;
end;

destructor TDecirculariserPlugin.Destroy;
begin
  FreeAndNil( FMenuItem );
  inherited Destroy;
end;

procedure TDecirculariserPlugin.Init;
begin
  FEnabled         := True;
  FFewSymbolsLimit := 3;
end;

function TDecirculariserPlugin.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create( 'Decirculariser', TFrameOptionPageDecirculariser, Self );
end;

procedure TDecirculariserPlugin.MenuItemClick( Sender: TObject );
begin
  ShowDecirculariser;
end;

procedure TDecirculariserPlugin.ShowDecirculariser;
begin
  TFormDecirculariser.Execute;
end;

procedure InitPlugin( Unload: Boolean );
begin
  if not Unload then
    DecirculariserPlugin := TDecirculariserPlugin.Create
  else
  begin
    { Close the form first so it cannot reference freed plugin state. }
    TFormDecirculariser.CloseInstance;
    FreeAndNil( DecirculariserPlugin );
  end;
end;

end.
