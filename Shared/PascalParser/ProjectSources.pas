{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit ProjectSources;

/// <summary>
/// IDE-side source access shared by the code-analysis detectors (Dead Code, Unreachable Code,
/// Unused Unit, Empty Event Handler): a snapshot of a project's Pascal files, and the text of a
/// unit taken from its open editor buffer when it has one, else from disk.
/// </summary>
/// <remarks>
/// Never opens a module.  Opening every unit of a project to read it (as the Empty Event Handler
/// scan once did) loads each form designer, leaves hundreds of modules open, and can raise
/// "Class not found" dialogs mid-scan.  A candidate for <c>ToolsAPIHelpers</c>; kept here so the
/// detectors share one implementation.
/// </remarks>

interface

uses
  System.SysUtils, System.Classes, ToolsAPI;

type
  /// <summary>Progress callback of a project scan; set Cancel to stop the scan after the current file.</summary>
  /// <param name="Step">Text describing the current step, such as "Scanning: Foo.pas".</param>
  /// <param name="Cancel">Set to True to stop the scan.</param>
  TSourceScanProgressEvent = procedure( const Step: string; var Cancel: Boolean ) of object;

/// <summary>
/// Returns the full paths of the project's modules whose extension is in Extensions, taken once
/// up front so a scan that pumps messages never indexes a module list that has since changed.
/// </summary>
/// <param name="Project">The project; nil gives an empty result.</param>
/// <param name="Extensions">Accepted extensions with the dot, such as [ '.pas' ].</param>
/// <returns>The matching file names in project order; modules with no file name are skipped.</returns>
function GetProjectSourceFiles( const Project: IOTAProject; const Extensions: array of string ): TArray<string>;

/// <summary>
/// Returns the text of FileName as UTF-8 without a BOM: the open editor buffer when the module is
/// open in the IDE (so unsaved edits are seen), otherwise the file on disk.
/// </summary>
/// <param name="FileName">Full path of the unit.</param>
/// <returns>The source text; empty when the module is not open and the file does not exist.</returns>
/// <exception cref="EFOpenError">Raised when the file exists but cannot be opened (locked, no access).</exception>
function ReadModuleSource( const FileName: string ): UTF8String;

/// <summary>
/// Returns True when the scan should stop: the IDE is shutting down, or a progress handler
/// asked to cancel.
/// </summary>
/// <param name="OnProgress">The progress handler to consult; may be nil.</param>
/// <param name="Step">Text describing the current step.</param>
/// <returns>True to stop the scan.</returns>
function ScanShouldStop( OnProgress: TSourceScanProgressEvent; const Step: string ): Boolean;

implementation

uses
  Vcl.Forms, ToolsAPIHelpers, DelphiLexer;

function GetProjectSourceFiles( const Project: IOTAProject; const Extensions: array of string ): TArray<string>;
begin
  Result := nil;
  if Project = nil then
    Exit;

  var oList := TStringList.Create;
  try
    for var i := 0 to Project.GetModuleCount - 1 do
    begin
      var oModuleInfo := Project.GetModule( i );
      if oModuleInfo = nil then
        Continue;

      var sFileName := oModuleInfo.FileName;
      if sFileName = '' then
        Continue;

      for var sExt in Extensions do
        if SameText( ExtractFileExt( sFileName ), sExt ) then
        begin
          oList.Add( sFileName );
          Break;
        end;
    end;

    Result := oList.ToStringArray;
  finally
    oList.Free;
  end;
end;

function ReadModuleSource( const FileName: string ): UTF8String;
begin
  Result := '';

  var oModuleServices: IOTAModuleServices;
  if Supports( BorlandIDEServices, IOTAModuleServices, oModuleServices ) then
  begin
    var oModule := oModuleServices.FindModule( FileName );
    if oModule <> nil then
      for var i := 0 to oModule.ModuleFileCount - 1 do
      begin
        var oEditor: IOTASourceEditor;
        if Supports( oModule.ModuleFileEditors[ i ], IOTASourceEditor, oEditor ) and
           SameText( oEditor.FileName, FileName ) then
          Exit( GetEditorSource( oEditor ) );
      end;
  end;

  if FileExists( FileName ) then
    Result := LoadTextFileToUtf8String( FileName );
end;

function ScanShouldStop( OnProgress: TSourceScanProgressEvent; const Step: string ): Boolean;
begin
  Result := Application.Terminated;
  if Result or not Assigned( OnProgress ) then
    Exit;

  OnProgress( Step, Result );
  Result := Result or Application.Terminated;
end;

end.
