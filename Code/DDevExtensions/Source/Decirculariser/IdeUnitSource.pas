{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit IdeUnitSource;

/// <summary>
/// One rule, one implementation, for every project scanner ( Code Quality, Code Style, TODO,
/// DFM/PAS Consistency, Dependency Viewer, Decirculariser ): where a unit's text comes from, and
/// how a result is opened in the editor.
/// </summary>
/// <remarks>
/// The rule: a unit that is OPEN in the IDE is read from its editor buffer, so a scan sees what the
/// user sees, unsaved changes included; any other unit is read from disk, decoded as the IDE
/// decodes it ( UTF-8 without a BOM is UTF-8 ).  A scan never opens a module: opening every unit of
/// a project loads every form designer, freezes the IDE and can raise "Class not found" prompts
/// whose Ignore later drops components from the .dfm.  A form and its unit are always read from
/// the same place, so the two halves cannot disagree.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, ToolsAPI;

/// <summary>A source file's text as UTF-8 without a BOM ( see <c>DecodeSourceBytes</c> ).</summary>
/// <param name="AFileName">The file to read.</param>
/// <returns>The decoded text.</returns>
/// <exception cref="EFOpenError">Raised when the file cannot be opened.</exception>
function ReadSourceFile( const AFileName: string ): UTF8String;

/// <summary>The source editor of a unit, or nil.</summary>
/// <param name="AFileName">The unit's file.</param>
/// <param name="AOpen">True to open the unit when it is not open; False to find an open one only.</param>
/// <returns>The editor whose file is <paramref name="AFileName"/>, or nil.</returns>
function FindSourceEditor( const AFileName: string; AOpen: Boolean ): IOTASourceEditor;

/// <summary>A unit's text: the editor buffer when the unit is open, otherwise the file on disk.</summary>
/// <param name="AFileName">The unit's file.</param>
/// <param name="ASource">Receives the text as UTF-8 without a BOM.</param>
/// <returns>False when the unit is neither open nor on disk.</returns>
/// <exception cref="EFOpenError">Raised when the file exists but cannot be opened.</exception>
function ReadUnitSource( const AFileName: string; out ASource: UTF8String ): Boolean;

/// <summary>
/// A form unit and its form resource, both from the same place: when the unit is open with its form
/// loaded, the editor buffer and the designer's resource; otherwise the .pas and .dfm on disk.
/// </summary>
/// <param name="APasFileName">The form's unit.</param>
/// <param name="APasSource">Receives the unit's text as UTF-8 without a BOM.</param>
/// <param name="ADfmBytes">Receives the form resource as stored: text, binary ( TPF0 ) or a
/// resource stream; <c>DfmBytesToText</c> turns any of them into text.</param>
/// <returns>False when there is no form resource ( no open form and no .dfm on disk ).</returns>
/// <exception cref="EFOpenError">Raised when a file exists but cannot be opened.</exception>
function ReadFormUnit( const APasFileName: string; out APasSource: UTF8String; out ADfmBytes: TBytes ): Boolean;

/// <summary>
/// Opens a file in the editor and puts the caret on a line, telling the user why when it cannot.
/// </summary>
/// <param name="AFileName">The file to open.</param>
/// <param name="ALine">1-based line; 0 or less only opens the file.  A line past the end of the
/// file goes to the last line.</param>
/// <param name="AColumn">1-based column; below 1 is taken as 1.</param>
procedure OpenFileAtLine( const AFileName: string; ALine, AColumn: Integer );

/// <summary>The .pas files of a project, taken once before a scan: a scan pumps messages, and the
/// project can gain or lose modules, or close, while it runs.</summary>
/// <param name="AProject">The project; nil gives none.</param>
/// <returns>The full file names of its .pas modules, in project order.</returns>
function ProjectPascalFiles( const AProject: IOTAProject ): TArray<string>;

/// <summary>The identity of a project, to compare after a message pump without calling into a project
/// that may have been closed meanwhile.</summary>
/// <param name="AProject">The project being scanned.</param>
/// <returns>Its IInterface identity; nil for nil.</returns>
function ProjectIdentity( const AProject: IOTAProject ): IInterface;

/// <summary>Stops a scan when the project it scans is no longer the active one ( closed, or another
/// project made active ) - call it after every message pump.</summary>
/// <param name="AIdentity">The scanned project's <see cref="ProjectIdentity"/>.</param>
/// <exception cref="EAbort">Raised when the active project is not the scanned one.</exception>
procedure CheckProjectUnchanged( const AIdentity: IInterface );

/// <summary>True while the project of <paramref name="AIdentity"/> is still the active one.</summary>
/// <param name="AIdentity">The scanned project's <see cref="ProjectIdentity"/>.</param>
/// <returns>False when the project was closed or another one made active.</returns>
function IsActiveProject( const AIdentity: IInterface ): Boolean;

/// <summary>Puts text on the clipboard, reporting a clipboard held by another process instead of
/// raising.</summary>
/// <param name="AText">The text to copy.</param>
procedure CopyTextToClipboard( const AText: string );

implementation

uses
  System.IOUtils, System.Math, Vcl.Clipbrd, Vcl.Dialogs, ToolsAPIHelpers, DecirculariserCore,
  DfmPasConsistencyCore;

function ReadSourceFile( const AFileName: string ): UTF8String;
begin
  Result            := DecodeSourceBytes( TFile.ReadAllBytes( AFileName ) );
end;

function FindSourceEditor( const AFileName: string; AOpen: Boolean ): IOTASourceEditor;
var
  ModuleServices    : IOTAModuleServices;
  Module            : IOTAModule;
begin
  Result            := nil;
  if ( not Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) ) then
    Exit;

  Module            := ModuleServices.FindModule( AFileName );
  if ( Module = nil ) and AOpen then
    Module          := ModuleServices.OpenModule( AFileName );
  if ( Module = nil ) then
    Exit;

  for var I := 0 to Module.ModuleFileCount - 1 do
    if Supports( Module.ModuleFileEditors[ I ], IOTASourceEditor, Result ) and
      SameText( Result.FileName, AFileName ) then
      Exit;
  Result            := nil;
end;

function ReadUnitSource( const AFileName: string; out ASource: UTF8String ): Boolean;
begin
  ASource           := '';
  var Editor        := FindSourceEditor( AFileName, False );
  if ( Editor <> nil ) then
  begin
    ASource         := GetEditorSource( Editor );
    Exit( True );
  end;

  Result            := FileExists( AFileName );
  if Result then
    ASource         := ReadSourceFile( AFileName );
end;

/// <summary>The form editor of an open module, or nil.</summary>
/// <param name="APasFileName">The form's unit.</param>
/// <param name="AEditor">Receives the unit's source editor when the form editor is found.</param>
/// <returns>The form editor, or nil when the unit is not open or its form is not loaded.</returns>
function FindOpenFormEditor( const APasFileName: string; out AEditor: IOTASourceEditor ): IOTAFormEditor;
var
  ModuleServices    : IOTAModuleServices;
  Module            : IOTAModule;
  FormEditor        : IOTAFormEditor;
  SourceEditor      : IOTASourceEditor;
begin
  Result            := nil;
  AEditor           := nil;
  if ( not Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) ) then
    Exit;
  Module            := ModuleServices.FindModule( APasFileName );
  if ( Module = nil ) then
    Exit;

  for var I := 0 to Module.ModuleFileCount - 1 do
    if Supports( Module.ModuleFileEditors[ I ], IOTAFormEditor, FormEditor ) then
      Result        := FormEditor
    else if Supports( Module.ModuleFileEditors[ I ], IOTASourceEditor, SourceEditor ) and
      SameText( SourceEditor.FileName, APasFileName ) then
      AEditor       := SourceEditor;

  if ( AEditor = nil ) then
    Result          := nil;
end;

/// <summary>True when a form resource, converted to text, declares a root object - the designer can
/// hand out an empty or unexpected stream, and then the .dfm on disk is the one to read.</summary>
/// <param name="ADfmBytes">The resource as the designer gave it.</param>
/// <returns>True when an object, inherited or inline line is present.</returns>
function HasFormObject( const ADfmBytes: TBytes ): Boolean;
var
  sText             : string;
begin
  Result            := False;
  if ( Length( ADfmBytes ) = 0 ) then
    Exit;
  try
    sText           := DfmBytesToText( ADfmBytes );
  except
    // A stream the RTL cannot convert: read the file on disk instead.
    on EParserError do
      Exit;
    on EReadError do
      Exit;
  end;
  for var sLine in sText.Split( [ #10 ] ) do
  begin
    var sTrim       := LowerCase( Trim( sLine ) );
    if sTrim.StartsWith( 'object ' ) or sTrim.StartsWith( 'inherited ' ) or sTrim.StartsWith( 'inline ' ) then
      Exit( True );
  end;
end;

function ReadFormUnit( const APasFileName: string; out APasSource: UTF8String; out ADfmBytes: TBytes ): Boolean;
var
  SourceEditor      : IOTASourceEditor;
begin
  APasSource        := '';
  ADfmBytes         := nil;

  var FormEditor    := FindOpenFormEditor( APasFileName, SourceEditor );
  if ( FormEditor <> nil ) then
  begin
    var Stream      := TBytesStream.Create;
    try
      SaveFormResourceTo( FormEditor, Stream );
      ADfmBytes     := Copy( Stream.Bytes, 0, Stream.Size );
    finally
      Stream.Free;
    end;
    if HasFormObject( ADfmBytes ) then
    begin
      APasSource    := GetEditorSource( SourceEditor );
      Exit( True );
    end;
  end;

  { Not open, or the designer gave nothing: both halves from disk. }
  var sDfmFile      := ChangeFileExt( APasFileName, '.dfm' );
  Result            := FileExists( sDfmFile ) and FileExists( APasFileName );
  if Result then
  begin
    ADfmBytes       := TFile.ReadAllBytes( sDfmFile );
    APasSource      := ReadSourceFile( APasFileName );
  end;
end;

procedure OpenFileAtLine( const AFileName: string; ALine, AColumn: Integer );
var
  ModuleServices    : IOTAModuleServices;
  Module            : IOTAModule;
  SourceEditor      : IOTASourceEditor;
begin
  if ( AFileName = '' ) then
  begin
    ShowMessage( 'No source file is associated with this entry.' );
    Exit;
  end;
  if ( not FileExists( AFileName ) ) then
  begin
    ShowMessage( 'File not found: ' + AFileName );
    Exit;
  end;
  if ( not Supports( BorlandIDEServices, IOTAModuleServices, ModuleServices ) ) then
    Exit;

  try
    Module          := ModuleServices.OpenModule( AFileName );
  except
    on E: Exception do
    begin
      ShowMessage( Format( 'Could not open %s'#13#10'%s', [ AFileName, E.Message ] ) );
      Exit;
    end;
  end;
  if ( Module = nil ) then
  begin
    ShowMessage( 'Could not open ' + AFileName );
    Exit;
  end;

  SourceEditor      := nil;
  for var I := 0 to Module.ModuleFileCount - 1 do
    if Supports( Module.ModuleFileEditors[ I ], IOTASourceEditor, SourceEditor ) and
      SameText( SourceEditor.FileName, AFileName ) then
      Break
    else
      SourceEditor  := nil;

  if ( SourceEditor = nil ) then
  begin
    ShowMessage( 'No source editor available for ' + ExtractFileName( AFileName ) );
    Exit;
  end;

  SourceEditor.Show;
  if ( ALine <= 0 ) or ( SourceEditor.EditViewCount = 0 ) then
    Exit;

  var EditView      := SourceEditor.EditViews[ 0 ];
  if ( EditView = nil ) then
    Exit;

  { A result can be older than the buffer: a line past the end goes to the last line. }
  var iLine         := Min( ALine, Max( 1, SourceEditor.GetLinesInBuffer ) );
  EditView.Position.Move( iLine, Max( 1, AColumn ) );
  EditView.MoveViewToCursor;
  EditView.Paint;
end;

function ProjectPascalFiles( const AProject: IOTAProject ): TArray<string>;
begin
  Result            := nil;
  if ( AProject = nil ) then
    Exit;
  for var I := 0 to AProject.GetModuleCount - 1 do
  begin
    var ModuleInfo  := AProject.GetModule( I );
    if ( ModuleInfo <> nil ) and SameText( ExtractFileExt( ModuleInfo.FileName ), '.pas' ) then
      Result        := Result + [ ModuleInfo.FileName ];
  end;
end;

function ProjectIdentity( const AProject: IOTAProject ): IInterface;
begin
  if ( AProject = nil ) then
    Exit( nil );
  Result            := AProject as IInterface;
end;

function IsActiveProject( const AIdentity: IInterface ): Boolean;
begin
  { Only the ACTIVE project is asked for its identity: the scanned one may be gone. }
  var Active        := GetActiveProject;
  Result            := ( Active <> nil ) and ( ( Active as IInterface ) = AIdentity );
end;

procedure CheckProjectUnchanged( const AIdentity: IInterface );
begin
  if ( not IsActiveProject( AIdentity ) ) then
    Abort;
end;

procedure CopyTextToClipboard( const AText: string );
begin
  try
    Clipboard.AsText := AText;
  except
    { Another process can hold the clipboard open for a moment; that is not our defect. }
    on E: EClipboardException do
      ShowMessage( 'Could not copy to the clipboard:'#13#10 + E.Message );
  end;
end;

end.

