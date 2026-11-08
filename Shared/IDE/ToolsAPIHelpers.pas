{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}
{$A+,B-,C+,D+,E-,F-,G+,H+,I+,J-,K-,L+,M-,N-,O+,P+,Q-,R-,S-,T-,U-,V+,W-,X+,Y+,Z1}

unit ToolsAPIHelpers;

/// <summary>
/// Higher-level helpers built on top of the open ToolsAPI: locating the active project,
/// reading source out of edit buffers as UTF-8, querying the form-resource type of a unit,
/// creating new IDE toolbars, navigating the component palette and resolving env-option paths
/// for a particular platform/personality.
/// </summary>

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Contnrs, ToolsAPI, Vcl.Controls, Vcl.ActnList,
  Vcl.CategoryButtons, PaletteAPI,
  {$IF CompilerVersion >= 23.0} // XE2+
  PlatformAPI,
  {$IFEND}
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Forms, Vcl.ImgList, IDEHooks, System.TypInfo, Vcl.Menus;

type
  /// <summary>Identifies whether a unit owns a TForm, TFrame or TDataModule resource.</summary>
  TFormResourceType = (ftForm, ftFrame, ftDataModule);

/// <summary>Locates a TMenuItem on the IDE main form by component name.</summary>
/// <param name="Name">Component name of the menu item.</param>
/// <returns>The menu item, or nil when it does not exist or the IDE has no main form (start-up, shutdown).</returns>
function FindMenuItem(const Name: string): TMenuItem;
/// <summary>Makes a hidden IDE menu item (and its action) visible.</summary>
/// <param name="Name">Component name of the menu item.</param>
procedure ShowMenuItem(const Name: string);

/// <summary>Returns the currently active IOTAProjectGroup, or nil when none is loaded.</summary>
/// <returns>The project group, or nil when none is open.</returns>
function GetActiveProjectGroup: IOTAProjectGroup;
/// <summary>Returns the currently active IOTAProject (delegates to ToolsAPI.GetActiveProject).</summary>
/// <returns>The active project, or nil.</returns>
function GetActiveProject: IOTAProject;
/// <summary>Returns the IOTAModuleInfo entry of Project that matches Filename, or nil.</summary>
/// <param name="Project">Project to search.</param>
/// <param name="Filename">File name of the module.</param>
/// <returns>The module info, or nil.</returns>
function FindModuleInfo(Project: IOTAProject; const Filename: string): IOTAModuleInfo;

/// <summary>Reads the entire source from an IOTASourceEditor as UTF-8 bytes.</summary>
/// <param name="Editor">Source editor; nil gives an empty result.</param>
/// <returns>The editor text, UTF-8 encoded.</returns>
function GetEditorSource(Editor: IOTASourceEditor): UTF8String; overload;
/// <summary>Reads the entire source from an IOTAEditBuffer as UTF-8 bytes.</summary>
/// <param name="EditBuffer">Edit buffer; nil gives an empty result.</param>
/// <returns>The buffer text, UTF-8 encoded.</returns>
function GetEditorSource(EditBuffer: IOTAEditBuffer): UTF8String; overload;
/// <summary>Saves the editor source to Filename. A UTF-8 BOM is written for Delphi 2005 and later.</summary>
/// <param name="EditBuffer">Buffer to save; nil does nothing.</param>
/// <param name="Filename">Destination file; created or overwritten.</param>
procedure SaveEditorSourceTo(EditBuffer: IOTAEditBuffer; const Filename: string); overload; // UTF8 BOM is written for Delphi 2005+
/// <summary>Saves the editor source to OutStream. A UTF-8 BOM is written for Delphi 2005 and later.</summary>
/// <param name="EditBuffer">Buffer to save.</param>
/// <param name="OutStream">Destination stream; nil does nothing.</param>
procedure SaveEditorSourceTo(EditBuffer: IOTAEditBuffer; OutStream: TStream); overload; // UTF8 BOM is written for Delphi 2005+
/// <summary>Persists the .dfm form resource owned by FormEditor to a file.</summary>
/// <param name="FormEditor">Form editor; nil does nothing.</param>
/// <param name="Filename">Destination file; created or overwritten.</param>
procedure SaveFormResourceTo(FormEditor: IOTAFormEditor; const Filename: string); overload;
/// <summary>Persists the .dfm form resource owned by FormEditor to a stream.</summary>
/// <param name="FormEditor">Form editor; nil does nothing.</param>
/// <param name="OutStream">Destination stream; nil does nothing.</param>
procedure SaveFormResourceTo(FormEditor: IOTAFormEditor; OutStream: TStream); overload;

/// <summary>
/// Inspects a unit (.pas or .cpp/.h) for the class declaration matching FormName and returns
/// whether it inherits from TForm, TFrame or TDataModule. Falls back to disk read when the file
/// is not currently open in an editor.
/// </summary>
/// <param name="Filename">Path of the unit.</param>
/// <param name="FormName">Form/class name (without the leading "T").</param>
/// <param name="FormCaption">Reserved; reserved for future use.</param>
/// <returns>The detected resource type.</returns>
function GetFormResourceType(const Filename, FormName: string; out FormCaption: string): TFormResourceType;
/// <summary>Returns the qualified unit name declared inside a .pas file by lexing the first 4 KB of the source.</summary>
/// <param name="FileName">Unit file.</param>
/// <returns>The unit name from the source, or the file name without extension when it is not a .pas file or has no unit clause.</returns>
function GetUnitNameFromFile(const FileName: string): string;

/// <summary>Creates and returns a new IDE-style TToolBar parented to the IDE's main ControlBar.</summary>
/// <param name="AOwner">Component owner (typically Application.MainForm).</param>
/// <param name="Name">Component name.</param>
/// <param name="Caption">Toolbar caption.</param>
/// <param name="Visible">Initial visibility.</param>
/// <returns>The created toolbar.</returns>
/// <exception cref="Exception">Raised when the IDE has no ControlBar1 component.</exception>
function NewToolBar(AOwner: TComponent; const Name, Caption: string; Visible: Boolean = True): TToolBar;

/// <summary>True when Project (or the active project when nil) is a C++Builder project.</summary>
/// <param name="Project">Project to test; nil tests the active project.</param>
/// <returns>True for a C++Builder project.</returns>
function IsCppPersonality(Project: IOTAProject): Boolean;
/// <summary>True when Project (or the active project when nil) is a native Delphi project.</summary>
/// <param name="Project">Project to test; nil tests the active project.</param>
/// <returns>True for a Delphi project.</returns>
function IsDelphiPersonality(Project: IOTAProject): Boolean;
/// <summary>True when Project (or the active project when nil) is a Delphi.NET project.</summary>
/// <param name="Project">Project to test; nil tests the active project.</param>
/// <returns>True for a Delphi.NET project.</returns>
function IsDelphiNetPersonality(Project: IOTAProject): Boolean;


/// <summary>Returns the TCategoryButtons control hosting the IDE component palette, or nil when not present.</summary>
/// <returns>The palette control, or nil when the IDE has none.</returns>
function GetComponentPalette: TCategoryButtons;
/// <summary>Returns the Categories property of Palette using RTTI.</summary>
/// <param name="Palette">The component palette control.</param>
/// <returns>Its button categories.</returns>
function GetPaletteCategories(Palette: TCategoryButtons): TButtonCategories;

/// <summary>Returns the IOTAEditor for the currently focused module's current editor view.</summary>
/// <returns>The current editor, or nil when no module is open.</returns>
function GetCurrentEditor: IOTAEditor;
/// <summary>Programmatically clicks PalItem on the component palette and optionally triggers component creation.</summary>
/// <param name="PalItem">Palette item to focus, or nil to revert to the selector tool.</param>
/// <param name="ExecuteItem">When True, releases the selection so a click on the form designer drops the component.</param>
procedure SelectComponentPalette(PalItem: TButtonItem; ExecuteItem: Boolean);

/// <summary>Returns the value of an env-option path (such as Search Path or Browsing Path) for AProject's current platform.</summary>
/// <param name="AProject">Project whose platform and personality are used; nil means Win32 Delphi.</param>
/// <param name="AOptionName">Option name, such as "BrowsingPath".</param>
/// <returns>The option value; empty when unset.</returns>
function GetProjectEnvOptionPaths(const AProject: IOTAProject; const AOptionName: string): string;
/// <summary>Returns the value of an env-option path for the supplied platform/personality combination.</summary>
/// <param name="APlatformName">Platform name; empty uses the general environment options.</param>
/// <param name="APersonality">Personality name.</param>
/// <param name="AOptionName">Option name.</param>
/// <returns>The option value; empty when unset.</returns>
function GetPlatformEnvOptionPaths(const APlatformName, APersonality, AOptionName: string): string;

type
  /// <summary>Stand-in for vclide's TPropField that exposes its Variant Value via imported symbols.</summary>
  TPropField = class(TComponent)
  private
    /// <summary>Reads the field value via the IDE's TPropField.GetValue.</summary>
    /// <returns>The field value, read through the IDE's own accessor.</returns>
    function GetValue: Variant;
    /// <summary>Writes the field value via the IDE's TPropField.SetValue.</summary>
    /// <param name="Value">New field value.</param>
    procedure SetValue(const Value: Variant);
  public
    /// <summary>Variant value of the property field.</summary>
    property Value: Variant read GetValue write SetValue;
  end;

implementation

uses
  Winapi.Messages, System.IOUtils, IDEUtils, DelphiLexer;

{ TPropField }

function TPropField.GetValue: Variant;
  external vclide_bpl name '@Idepropset@TPropField@GetValue$qqrv' {$IFDEF WIN64} delayed {$ENDIF};

procedure TPropField.SetValue(const Value: Variant);
  external vclide_bpl name '@Idepropset@TPropField@SetValue$qqrrx14System@Variant' {$IFDEF WIN64} delayed {$ENDIF};

{------------------------------------------------------------------------------------------------------------}

function FindMenuItem(const Name: string): TMenuItem;
var
  Comp: TComponent;
begin
  // No main form yet (early start-up) or any more (shutdown): there is no menu to search.
  if ( Application = nil ) or ( Application.MainForm = nil ) then
    Exit( nil );
  Comp := Application.MainForm.FindComponent(Name);
  if (Comp <> nil) and (Comp is TMenuItem) then
    Result := TMenuItem(Comp)
  else
    Result := nil;
end;

procedure ShowMenuItem(const Name: string);
var
  Item: TMenuItem;
begin
  // Make a hidden menu item visible
  Item := FindMenuItem(Name);
  if Item <> nil then
  begin
    Item.Visible := True;
    if Item.Action <> nil then
      TAction(Item.Action).Visible := True;
  end;
end;

function GetActiveProjectGroup: IOTAProjectGroup;
var
  ModuleServices: IOTAModuleServices;
  i: Integer;
begin
  Result := nil;
  if Assigned(BorlandIDEServices) then
  begin
    ModuleServices := BorlandIDEServices as IOTAModuleServices;
    for i := 0 to ModuleServices.ModuleCount - 1 do
      if System.SysUtils.Supports(ModuleServices.Modules[i], IOTAProjectGroup, Result) then
        Break;
  end;
end;

function GetCustomCodeIProject(Project: IOTAProject): TObject;
begin
  Result := DelphiInterfaceToObject(Project);
end;

function GetActiveProject: IOTAProject;
begin
  Result := ToolsAPI.GetActiveProject;
end;

function FindModuleInfo(Project: IOTAProject; const Filename: string): IOTAModuleInfo;
begin
  Result := Project.FindModuleInfo(Filename);
end;

/// <summary>
/// Reads everything Reader holds as UTF-8.  The result grows geometrically and is trimmed once at
/// the end; growing it by one chunk per read copied the whole text again on every chunk
/// ( measured: 20 MB 31.3 ms before, 20.6 ms after; 5 MB 7.1 ms / 5.2 ms ).
/// </summary>
/// <param name="Reader">Editor reader, or nil.</param>
/// <returns>The buffer text, or an empty string when Reader is nil.</returns>
function ReadAllEditorText( const Reader: IOTAEditReader ): UTF8String;
const
  MaxBufSize = 15872; // The C++ compiler uses this number of bytes for read operations and the IDE requires this
var
  Buf: array[0..MaxBufSize] of AnsiChar;
begin
  Result := '';
  if ( Reader = nil ) then
    Exit;

  var iUsed := 0;
  var iRead: Integer;
  repeat
    iRead := Reader.GetText( iUsed, Buf, MaxBufSize );
    if ( iRead > 0 ) then
    begin
      if ( iUsed + iRead > Length( Result ) ) then
        SetLength( Result, ( iUsed + iRead ) * 2 );
      Move( Buf[0], Result[iUsed + 1], iRead );
      Inc( iUsed, iRead );
    end;
  until iRead < MaxBufSize;
  SetLength( Result, iUsed );
end;

function GetEditorSource(Editor: IOTASourceEditor): UTF8String;
begin
  if ( Editor = nil ) then
    Exit( '' );
  Result := ReadAllEditorText( Editor.CreateReader );
end;

function GetEditorSource(EditBuffer: IOTAEditBuffer): UTF8String;
begin
  if ( EditBuffer = nil ) then
    Exit( '' );
  Result := ReadAllEditorText( EditBuffer.CreateReader );
end;

procedure SaveEditorSourceTo(EditBuffer: IOTAEditBuffer; const Filename: string);
  // UTF8 BOM is written for Delphi 2005+
var
  FileStream: TFileStream;
begin
  if EditBuffer <> nil then
  begin
    FileStream := TFileStream.Create(Filename, fmCreate);
    try
      SaveEditorSourceTo(EditBuffer, FileStream);
    finally
      FileStream.Free;
    end;
  end;
end;

procedure SaveEditorSourceTo(EditBuffer: IOTAEditBuffer; OutStream: TStream);
  // UTF8 BOM is written for Delphi 2005+
const
  Utf8BOM: array[0..2] of Byte = ($EF, $BB, $BF);
var
  Data: UTF8String;
begin
  if OutStream <> nil then
  begin
    Data := GetEditorSource(EditBuffer);
    if Data <> '' then
    begin
      OutStream.Write(Utf8BOM, Length(Utf8BOM));
      OutStream.Write(Data[1], Length(Data));
    end;
  end;
end;

procedure SaveFormResourceTo(FormEditor: IOTAFormEditor; const Filename: string);
var
  FileStream: TFileStream;
begin
  if FormEditor <> nil then
  begin
    FileStream := TFileStream.Create(Filename, fmCreate);
    try
      SaveFormResourceTo(FormEditor, FileStream);
    finally
      FileStream.Free;
    end;
  end;
end;

procedure SaveFormResourceTo(FormEditor: IOTAFormEditor; OutStream: TStream);
begin
  if (FormEditor <> nil) and (OutStream <> nil) then
    FormEditor.GetFormResource(TStreamAdapter.Create(OutStream));
end;

/// <summary>
/// Reads a source file as text: by its BOM when it has one, otherwise as UTF-8 when the bytes are
/// valid UTF-8, otherwise as ANSI ( older units ).
/// </summary>
/// <param name="AFileName">File to read.</param>
/// <returns>The decoded text.</returns>
/// <exception cref="EFileStreamError">Raised when the file cannot be opened.</exception>
function ReadSourceText( const AFileName: string ): string;
begin
  var aBytes := TFile.ReadAllBytes( AFileName );
  var oEncoding: TEncoding := nil;
  var iPreamble := TEncoding.GetBufferEncoding( aBytes, oEncoding, nil );
  if ( oEncoding <> nil ) and ( iPreamble > 0 ) then
    Exit( oEncoding.GetString( aBytes, iPreamble, Length( aBytes ) - iPreamble ) );

  var oStrictUtf8 := TUTF8Encoding.Create( CP_UTF8, MB_ERR_INVALID_CHARS, 0 );
  try
    try
      Result := oStrictUtf8.GetString( aBytes );
    except
      on EEncodingError do
        Result := TEncoding.ANSI.GetString( aBytes );
    end;
  finally
    oStrictUtf8.Free;
  end;
end;

function GetFormResourceType(const Filename, FormName: string; out FormCaption: string): TFormResourceType;
var
  OpenFilename: string;
  SearchS: string;
  i, k, l: Integer;
  Modules: IOTAModuleServices;
  Editor: IOTAEditBuffer;
  Lines: TStrings;

  function CheckLine(const S: string; var Typ: TFormResourceType): Boolean;
  var
    ps: Integer;
  begin
    Result := False;
    ps := Pos(SearchS + 'TDataModule', S);
    if ps > 0 then
    begin
      Typ := ftDataModule;
      Result := True;
    end;
    ps := Pos(SearchS + 'TFrame', S);
    if ps > 0 then
    begin
      Typ := ftFrame;
      Result := True;
    end;
    if CompareText(Trim(S), 'implementation') = 0 then
      Result := True;
  end;

begin
  Result := ftForm;
  FormCaption := '';
  OpenFilename := Filename;

  if CompareText(ExtractFileExt(Filename), '.pas') = 0 then
    SearchS := 'T' + FormName + ' = class('
  else
  if CompareText(ExtractFileExt(Filename), '.cpp') = 0 then
  begin
    OpenFilename := ChangeFileExt(Filename, '.h');
    SearchS := 'class T' + FormName + ' : public ';
  end;

  Lines := TStringList.Create;
  try
    if Supports(BorlandIDEServices, IOTAModuleServices, Modules) then
    begin
      for i := 0 to Modules.ModuleCount - 1 do
      begin
        if AnsiCompareFileName(Modules.Modules[i].FileName, Filename) = 0 then
        begin
          for k := 0 to Modules.Modules[i].GetModuleFileCount - 1 do
          begin
            if (AnsiCompareText(Modules.Modules[i].GetModuleFileEditor(k).FileName, OpenFilename) = 0) and
                Supports(Modules.Modules[i].GetModuleFileEditor(k), IOTAEditBuffer, Editor) then
            begin
              // The buffer is UTF-8; UTF8ToString keeps every character ( Utf8ToAnsi dropped
              // those outside the ANSI code page, so Unicode class names never matched ).
              Lines.Text := UTF8ToString(GetEditorSource(Editor));
              for l := 0 to Lines.Count - 1 do
                if CheckLine(Lines[l], Result) then
                  Break;
              Exit;
            end;
          end;
          Exit;
        end;
      end;
    end;

    { The file is not open in the editor: read it from disk.  For C++ that is the header, where
      the class is declared ( the .cpp was read before ). }
    try
      Lines.Text := ReadSourceText( OpenFilename );
    except
      on EFileStreamError do
        Exit; // missing or locked: report the default, as before
      on EInOutError do
        Exit;
    end;
    for l := 0 to Lines.Count - 1 do
      if CheckLine(Lines[l], Result) then
        Break;
  finally
    Lines.Free;
  end;
end;

function GetUnitNameFromFile(const FileName: string): string;
var
  Lexer: TDelphiLexer;

  function Next: TToken;
  begin
    while Lexer.GetToken(Result) and (Result.Kind in [tkComment, tkDirective]) do
      ;
  end;

  function NextA: TToken;
  begin
    Result := Next;
    if Result = nil then
      Abort;
  end;

  function ParseQualifiedName(Look: TToken): string;
  begin
    Result := '';
    repeat
      if Look.Kind >= tkIdent then
        Result := Result + Look.Value
      else
        Break;
      Look := NextA;
      if Look.Kind <> tkDot then
        Break;
      Result := Result + '.';
      Look := NextA;
    until False;
  end;

var
  Token: TToken;
begin
  Result := ChangeFileExt(ExtractFileName(FileName), '');
  if SameText(ExtractFileExt(FileName), '.pas') then
  begin
    try
      Lexer := TDelphiLexer.Create(FileName, LoadTextFileToUtf8String(FileName, 4096));
      try
        Token := Next;
        if (Token <> nil) and (Token.Kind = tkI_unit) then
        begin
          Token := Next;
          if Token <> nil then
            Result := ParseQualifiedName(Token);
        end;
      finally
        Lexer.Free;
      end;
    except
      on E: EAbort do
        ;
    end;
  end;
end;

function NewToolBar(AOwner: TComponent; const Name, Caption: string; Visible: Boolean): TToolBar;
type
  TToolbarClass = class of TToolBar;
var
  ControlBar: TControlBar;
  ToolBarClass: TToolbarClass;
  Services: INTAServices;
begin
  ControlBar := TControlBar(Application.MainForm.FindComponent('ControlBar1'));
  if ControlBar <> nil then
  begin
    Supports(BorlandIDEServices, INTAServices, Services);

    ToolBarClass := TToolBarClass(Services.GetToolBar(sStandardToolBar).ClassType);
    if ToolBarClass = nil then
      ToolBarClass := TToolBar;

    Result := ToolBarClass.Create(Application.MainForm); // BDS: inserts the toolbar into the popupmenu and the dialog
    Result.Name := Name;
    Result.Caption := Caption;
    Result.EdgeBorders := [];
    Result.Left := MaxInt;
    Result.Flat := True;
    Result.AutoSize := True;
    Result.Visible := Visible;
    Result.Parent := ControlBar;
    Result.Images := Services.ImageList;
  end
  else
    raise Exception.Create('No ControlBar was found');
end;

function GetComponentPalette: TCategoryButtons;
var
  ToolForm: TForm;
begin
  ToolForm := TForm(Application.FindComponent('ToolForm'));
  if ToolForm <> nil then
    Result := TCategoryButtons(ToolForm.FindComponent('Palette'))
  else
    Result := nil;
end;

function FindPaletteItemByName(const APaletteName, AItemName: string): IOTABasePaletteItem;
var
  CompPal: TCategoryButtons;
  PaletteServices: IOTAPaletteServices;
  PalGroup: IOTAPaletteGroup;
begin
  CompPal := GetComponentPalette;
  if Assigned(CompPal) and Supports(BorlandIDEServices, IOTAPaletteServices, PaletteServices) then
  begin
    PalGroup := PaletteServices.BaseGroup.FindItemByName(APaletteName, False) as IOTAPaletteGroup;
    if PalGroup <> nil then
    begin
      Result := PalGroup.FindItemByName(AItemName, False);
      Exit;
    end;
  end;
  Result := nil;
end;

function FindPaletteItemById(const APaletteId, AItemId: string): IOTABasePaletteItem;
var
  CompPal: TCategoryButtons;
  PaletteServices: IOTAPaletteServices;
  PalGroup: IOTAPaletteGroup;
begin
  CompPal := GetComponentPalette;
  if Assigned(CompPal) and Supports(BorlandIDEServices, IOTAPaletteServices, PaletteServices) then
  begin
    PalGroup := PaletteServices.BaseGroup.FindItem(APaletteId, False) as IOTAPaletteGroup;
    if PalGroup <> nil then
    begin
      Result := PalGroup.FindItem(AItemId, False);
      Exit;
    end;
  end;
  Result := nil;
end;

function GetCurrentEditor: IOTAEditor;
var
  Module: IOTAModule;
begin
  Module := (BorlandIDEServices as IOTAModuleServices).CurrentModule;
  if Module <> nil then
    Result := Module.CurrentEditor
  else
    Result := nil;
end;

{--------------------------------------------------------------------------------------------------}

function GetPaletteCategories(Palette: TCategoryButtons): TButtonCategories;
begin
  Result := TButtonCategories(GetObjectProp(Palette, 'Categories', TCollection));
end;

type
  TOpenCategoryButtons = class(TCategoryButtons);

procedure SelectComponentPalette(PalItem: TButtonItem; ExecuteItem: Boolean);
var
  CurrentEditor: IOTAEditor;
  Palette: TCategoryButtons;
  SelectorButton: TToolButton;
begin
  Palette := GetComponentPalette;
  if Palette <> nil then
  begin
    if PalItem <> nil then
    begin
      Palette.SelectedItem := PalItem;
      Palette.FocusedItem := PalItem;
      TOpenCategoryButtons(Palette).DoItemClicked(PalItem);
      if ExecuteItem then
      begin
        Palette.SelectedItem := nil;

        // activate the editor
        CurrentEditor := GetCurrentEditor;
        if CurrentEditor <> nil then
          CurrentEditor.Show; // does not focus the form when in docked form designer mode
      end;
    end
    else
    begin
      SelectorButton := TToolButton(Palette.Owner.FindComponent('tbSelector'));
      if SelectorButton <> nil then
        SelectorButton.Click
      else
      begin
        Palette.SelectedItem := nil;
        Palette.FocusedItem := nil;
      end;
    end;
  end;
end;

function IsCppPersonality(Project: IOTAProject): Boolean;
begin
  if Project = nil then
    Project := GetActiveProject;
  Result := (Project <> nil) and (Project.Personality = sCBuilderPersonality);
end;

function IsDelphiPersonality(Project: IOTAProject): Boolean; // Win32
begin
  if Project = nil then
    Project := GetActiveProject;
  Result := (Project <> nil) and (Project.Personality = sDelphiPersonality);
end;

function IsDelphiNetPersonality(Project: IOTAProject): Boolean;
begin
  if Project = nil then
    Project := GetActiveProject;
  Result := (Project <> nil) and (Project.Personality = sDelphiDotNetPersonality);
end;

{$IF CompilerVersion >= 23.0} // XE2+
type
  PObject = ^TObject;

  TPlatformManager = class(TObject)
  public
    function GetEnvOptions(const APlatform, APersonality: string): PObject;
  end;

function PlatformManager: TPlatformManager;
  external coreide_bpl name '@Platforms@PlatformManager$qqrv' {$IFDEF WIN64} delayed {$ENDIF};
function TPlatformManager.GetEnvOptions(const APlatform: string; const APersonality: string): PObject;
  external coreide_bpl name '@Platforms@TPlatformManager@GetEnvOptions$qqrx20System@UnicodeStringt1' {$IFDEF WIN64} delayed {$ENDIF};
{$IFEND}

function GetProjectEnvOptionPaths(const AProject: IOTAProject; const AOptionName: string): string;
var
  PlatformName: string;
  Personality: string;
begin
  {$IF CompilerVersion >= 23.0} // XE2+
  if AProject = nil then
  begin
    PlatformName := cWin32Platform;
    Personality := sDelphiPersonality;
  end
  else
  begin
    PlatformName := AProject.CurrentPlatform;
    Personality := AProject.Personality;
  end;
  {$ELSE}
  PlatformName := '';
  Personality := '';
  {$IFEND}
  Result := GetPlatformEnvOptionPaths(PlatformName, Personality, AOptionName);
end;

function GetPlatformEnvOptionPaths(const APlatformName, APersonality, AOptionName: string): string;
var
  EnvOptions: IOTAEnvironmentOptions;
  {$IF CompilerVersion >= 23.0} // XE2+
  PlatformEnvOptionsPtr: PObject;
  PropFieldPtr: ^TPropField;
  {$IFEND}
begin
  {$IF CompilerVersion >= 23.0} // XE2+
  if APlatformName <> '' then
  begin
    PlatformEnvOptionsPtr := PlatformManager.GetEnvOptions(APlatformName, APersonality);
    if (PlatformEnvOptionsPtr <> nil) and (PlatformEnvOptionsPtr^ <> nil) and
       InheritsFromClassName(PlatformEnvOptionsPtr^, 'TAddInOptions') then
    begin
      PropFieldPtr := PlatformEnvOptionsPtr^.FieldAddress(AOptionName);
      if (PropFieldPtr <> nil) and (PropFieldPtr^ <> nil) and InheritsFromClassName(PropFieldPtr^, 'TPropField') then
      begin
        Result := VarToStrDef(PropFieldPtr^.Value, '');
        Exit;
      end;
    end;
  end;
  {$IFEND}
  EnvOptions := (BorlandIDEServices as IOTAServices).GetEnvironmentOptions;
  Result := VarToStrDef(EnvOptions.Values[AOptionName], '');
end;

end.

