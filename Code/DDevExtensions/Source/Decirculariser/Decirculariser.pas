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
/// <param name="AFiles">Receives each added unit's file, keyed by lower-case unit name; an empty
/// file marks a name that two project units share.</param>
/// <param name="AOnProgress">Called with each file name before it is read; nil for none.  It may
/// raise <c>EAbort</c> to stop the scan.</param>
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
/// <returns>The number of entries deleted; none when the buffer is read-only.</returns>
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
  UsesClauseManagerCore, ToolsAPIHelpers, IdeUnitSource,
  FrmDecirculariser, FrmeOptionPageDecirculariser;

function AddProjectUnits( const AProject: IOTAProject; AAnalyser: TDecirculariser;
  AFiles: TDictionary<string, string>; AOnProgress: TProc<string> ): Integer;
var
  sUnit: string;
  Source: UTF8String;
begin
  Result := 0;
  if ( AProject = nil ) then
    Exit;

  { The file list is taken once: the progress callback pumps messages, and the project can change
    or close meanwhile - after each pump the scan stops if it is no longer the active project. }
  var Identity := ProjectIdentity( AProject );
  for var sFile in ProjectPascalFiles( AProject ) do
  begin
    if Assigned( AOnProgress ) then
    begin
      AOnProgress( sFile );
      CheckProjectUnchanged( Identity );
    end;

    { An open unit is read from the editor, so the analysis sees what the user sees. }
    try
      if ( not ReadUnitSource( sFile, Source ) ) then
        Continue;
    except
      { One unreadable unit should not cost the whole analysis: a locked or vanished file. }
      on EFOpenError do
        Continue;
      on EInOutError do
        Continue;
    end;

    sUnit := ChangeFileExt( ExtractFileName( sFile ), '' );
    AAnalyser.AddUnit( sUnit, Source );
    { Two project units of one name ( in different folders ) cannot both be the edge's file: an
      empty entry marks the name ambiguous, so nothing navigates to or edits the wrong one. }
    var sKnown: string;
    if AFiles.TryGetValue( LowerCase( sUnit ), sKnown ) and ( not SameText( sKnown, sFile ) ) then
      AFiles[ LowerCase( sUnit ) ] := ''
    else
      AFiles.AddOrSetValue( LowerCase( sUnit ), sFile );
    Inc( Result );
  end;
end;

function RemoveDeadEntries( const AFileName: string; const AUnitNames: TArray<string>;
  AFailures: TStrings ): Integer;
var
  Editor: IOTASourceEditor;
  Buffer: IOTAEditBuffer;
  Source, NewSource: UTF8String;
  sReason: string;
  sUnit: string;
  Writer: IOTAEditWriter;
begin
  Result := 0;
  Editor := FindSourceEditor( AFileName, True );
  if ( Editor = nil ) then
  begin
    for sUnit in AUnitNames do
      AFailures.Add( Format( '%s in %s: the file could not be opened in the editor',
        [ sUnit, ExtractFileName( AFileName ) ] ) );
    Exit;
  end;

  { A read-only buffer ( read-only file, version-control lock ) refuses the write: say so up front
    rather than letting the writer raise in the middle of a multi-file removal. }
  if Supports( Editor, IOTAEditBuffer, Buffer ) and Buffer.IsReadOnly then
  begin
    for sUnit in AUnitNames do
      AFailures.Add( Format( '%s in %s: the file is read-only in the editor',
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

  if ( Result = 0 ) then
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
