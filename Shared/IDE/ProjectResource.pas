{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit ProjectResource;

/// <summary>
/// Read/write access to a project's icon and version-info resources. On XE2+ the version data
/// lives in IOTABuildConfiguration options; on earlier versions the data is patched directly in
/// the IDE's TResFile structure via imported coreide bpl symbols.
/// </summary>

interface

uses
  Windows, SysUtils, Classes, Contnrs, ToolsAPI, TypInfo;

type
  /// <summary>Decoded metadata for a single image inside an icon resource.</summary>
  TIconResourceItem = record
    /// <summary>Image width and height in pixels (zero in the directory means 256).</summary>
    Width, Height: Integer;
    /// <summary>Number of colours in the palette (0 means truecolour).</summary>
    Colors: Integer;
    /// <summary>Bitplane count.</summary>
    Planes: Integer;
    /// <summary>Bits per pixel.</summary>
    BitCount: Integer;
    /// <summary>True when the image payload is PNG/MNG rather than DIB.</summary>
    IsPng: Boolean;
    /// <summary>Size in bytes of the image payload.</summary>
    ImageDataSize: LongInt;
    /// <summary>Pointer into the icon stream where the image payload begins.</summary>
    ImageData: Pointer;
  end;

  /// <summary>
  /// In-memory representation of a Win32 icon group resource (.ico file). Supports loading from
  /// disk or from a project's MAINICON resource and saving back via SaveToProjectResource.
  /// </summary>
  TIconResource = class(TObject)
  private
    /// <summary>Owned TMemoryStream holding the raw .ico bytes.</summary>
    FStream: TStream;
    /// <summary>Cached HICON returned by GetPaintIcon; freed lazily.</summary>
    FPaintIcon: HICON;
    /// <summary>Image index that FPaintIcon was created for; -1 when invalid.</summary>
    FPaintIconIndex: Integer;
    /// <summary>Last loaded source filename (used by SaveToProjectResource on XE2+).</summary>
    FFileName: string;
    /// <summary>Returns the number of images in the icon directory.</summary>
    function GetCount: Integer;
    /// <summary>Returns the start pointer of the underlying memory buffer.</summary>
    function GetData: Pointer; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
    /// <summary>Decodes the icon directory entry at Index.</summary>
    function GetImage(Index: Integer): TIconResourceItem;
    /// <summary>Releases the cached HICON and resets FPaintIconIndex to -1.</summary>
    procedure DestroyPaintIcon;
  protected
    /// <summary>Direct access to the underlying memory buffer.</summary>
    property Data: Pointer read GetData;
  public
    /// <summary>Initialises an empty icon resource.</summary>
    constructor Create;
    /// <summary>Releases the cached HICON and the backing stream.</summary>
    destructor Destroy; override;

    /// <summary>Returns (and caches) an HICON for the image at Index.</summary>
    /// <param name="Index">Image index within the icon directory.</param>
    function GetPaintIcon(Index: Integer): HICON;

    //procedure LoadFromMemory(P: PByte; Size: Integer);
    /// <summary>Replaces the contents with the bytes of an .ico file on disk.</summary>
    procedure LoadFromIconFile(const FileName: string);
    /// <summary>Loads the project's MAINICON resource into this object.</summary>
    procedure LoadFromProjectResource(AProject: IOTAProject);
    /// <summary>Writes this icon back into the project as MAINICON, updating IDE settings as needed.</summary>
    procedure SaveToProjectResource(AProject: IOTAProject);
    /// <summary>Empties the buffer and releases the cached HICON.</summary>
    procedure Clear;

    /// <summary>Number of images in the icon directory.</summary>
    property Count: Integer read GetCount;
    /// <summary>Indexed accessor for decoded image metadata.</summary>
    property Images[Index: Integer]: TIconResourceItem read GetImage;
    /// <summary>Underlying memory stream containing the .ico bytes.</summary>
    property Stream: TStream read FStream;
  end;

type
  /// <summary>Four-component VS_VERSION_INFO file/product version.</summary>
  TVersion = record
    /// <summary>Major.Minor.Release.Build version components.</summary>
    Major, Minor, Release, Build: Word;
  end;

  /// <summary>
  /// Snapshot of a project's version-info block. Valid is False when the project does not include
  /// version information; populate it via GetProjectVersion and persist via SetProjectVersion.
  /// </summary>
  TProjectVersion = record
    /// <summary>True when the data was successfully read from the project.</summary>
    Valid: Boolean;

    //ProductVersion: TVersion;
    /// <summary>File version components.</summary>
    FileVersion: TVersion;
    /// <summary>FileVersion as a free-form string (typically "Major.Minor.Release.Build").</summary>
    FileVersionStr: string;
    /// <summary>ProductVersion as a free-form string.</summary>
    ProductVersionStr: string;
    /// <summary>StringFileInfo ProductName field.</summary>
    ProductName: string;
    /// <summary>StringFileInfo CompanyName field.</summary>
    CompanyName: string;
    /// <summary>StringFileInfo FileDescription field.</summary>
    FileDescription: string;
    /// <summary>StringFileInfo LegalCopyright field.</summary>
    LegalCopyright: string;
    /// <summary>StringFileInfo LegalTrademarks field.</summary>
    LegalTrademarks: string;
    /// <summary>StringFileInfo InternalName field.</summary>
    InternalName: string;
    /// <summary>StringFileInfo OriginalFilename field.</summary>
    OriginalFilename: string;
    /// <summary>StringFileInfo Comments field.</summary>
    Comments: string;
  end;

/// <summary>Reads the version-info block from Project's options or .res file (depending on Delphi version).</summary>
function GetProjectVersion(Project: IOTAProject): TProjectVersion;
/// <summary>Writes Version back into Project; pass UpdateAllPlatforms=True to mirror across every platform/configuration.</summary>
/// <returns>True when at least one configuration was updated.</returns>
function SetProjectVersion(Project: IOTAProject; const Version: TProjectVersion; UpdateAllPlatforms: Boolean): Boolean;
/// <summary>Increments the build number of Project's file version and writes it back to all platforms.</summary>
procedure IncrementBuildVersion(Project: IOTAProject);
/// <summary>Adds or updates an extra StringFileInfo key (such as a custom field) across every configuration.</summary>
/// <returns>True when at least one configuration accepted the change.</returns>
function SetVersionInfoExtraKey(AProject: IOTAProject; const AKey, AValue: string): Boolean;

implementation

uses
  Variants, CommonOptionStrs, Consts, RTLConsts, IDEUtils, IDEHooks;

procedure IncrementBuildVersion(Project: IOTAProject);
var
  Version: TProjectVersion;
begin
  if Project <> nil then
  begin
    Version := GetProjectVersion(Project);
    if Version.Valid then
    begin
      Version.FileVersion.Build := Version.FileVersion.Build + 1;
      with Version.FileVersion do
        Version.FileVersionStr := Format('%d.%d.%d.%d', [Major, Minor, Release, Build]);
      SetProjectVersion(Project, Version, True);
    end;
  end;
end;

function GetAllConfigurations(Project: IOTAProject): TArray<IOTABuildConfiguration>;

  procedure AddChildren(var A: TArray<IOTABuildConfiguration>; var Index: Integer);
  var
    I: Integer;
    Config: IOTABuildConfiguration;
    Platforms: TArray<string>;
  begin
    Config := A[Index - 1];
    Platforms := Config.Platforms;

    SetLength(A, Length(A) + Config.ChildCount + Length(Platforms));
    for I := 0 to Config.ChildCount - 1 do
    begin
      A[Index] := Config.Children[I];
      Inc(Index);
      AddChildren(A, Index);
    end;

    for I := 0 to High(Platforms) do
    begin
      A[Index] := Config.PlatformConfiguration[Platforms[I]];
      Inc(Index);
      AddChildren(A, Index);
    end;
  end;

var
  Configurations: IOTAProjectOptionsConfigurations;
  I, Index: Integer;
begin
  Result := nil;
  if Supports(Project.ProjectOptions, IOTAProjectOptionsConfigurations, Configurations) then
  begin
    SetLength(Result, Configurations.ConfigurationCount);
    Index := 0;
    for I := 0 to Configurations.ConfigurationCount - 1 do
    begin
      Result[Index] := Configurations.Configurations[I];
      Inc(Index);
      AddChildren(Result, Index);
    end;
  end;
end;

function GetProjectVersion(Project: IOTAProject): TProjectVersion;
var
  Configurations: IOTAProjectOptionsConfigurations;
  BuildConfig: IOTABuildConfiguration;
  VerInfoKeys: TStrings;
begin
  Result.Valid := False;

  if Supports(Project.ProjectOptions, IOTAProjectOptionsConfigurations, Configurations) then
  begin
    if Configurations.BaseConfiguration.AsBoolean[sVerInfo_IncludeVerInfo] and (Length(Configurations.BaseConfiguration.Value[sVerInfo_Keys]) > Length(Configurations.ActiveConfiguration.Value[sVerInfo_Keys])) then
      BuildConfig := Configurations.BaseConfiguration // this happens when a project was migrated
    else
      BuildConfig := Configurations.ActiveConfiguration;
    if (BuildConfig <> nil) and BuildConfig.AsBoolean[sVerInfo_IncludeVerInfo] then
    begin
      Result.Valid := True;
      Result.FileVersion.Major := BuildConfig.AsInteger[sVerInfo_MajorVer];
      Result.FileVersion.Minor := BuildConfig.AsInteger[sVerInfo_MinorVer];
      Result.FileVersion.Release := BuildConfig.AsInteger[sVerInfo_Release];
      Result.FileVersion.Build := BuildConfig.AsInteger[sVerInfo_Build];

      VerInfoKeys := TStringList.Create;
      try
        ExtractStrings([';'], [], PChar(BuildConfig.Value[sVerInfo_Keys]), VerInfoKeys);
        Result.FileVersionStr := VerInfoKeys.Values['FileVersion'];
        Result.ProductVersionStr := VerInfoKeys.Values['ProductVersion'];
        Result.ProductName := VerInfoKeys.Values['ProductName'];
        Result.CompanyName := VerInfoKeys.Values['CompanyName'];
        Result.FileDescription := VerInfoKeys.Values['FileDescription'];
        Result.LegalCopyright := VerInfoKeys.Values['LegalCopyright'];
        Result.LegalTrademarks := VerInfoKeys.Values['LegalTrademarks'];
        Result.InternalName := VerInfoKeys.Values['InternalName'];
        Result.OriginalFilename := VerInfoKeys.Values['OriginalFilename'];
        Result.Comments := VerInfoKeys.Values['Comments'];
      finally
        VerInfoKeys.Free;
      end;
    end;
  end;
end;

function SetProjectVersion(Project: IOTAProject; const Version: TProjectVersion; UpdateAllPlatforms: Boolean): Boolean;
var
  Configurations: IOTAProjectOptionsConfigurations;
  BuildConfig: IOTABuildConfiguration;
  KeysIndex: Integer;
  VerInfoKeys: TStrings;
  OrgKeys, Keys: string;
  Modified: Boolean;

  procedure SetBuildConfigInt(const Option: string; Value: Integer);
  begin
    if BuildConfig.AsInteger[Option] <> Value then
    begin
      BuildConfig.AsInteger[Option] := Value;
      Modified := True;
    end;
  end;

begin
  Result := False;
  if Version.Valid and Supports(Project.ProjectOptions, IOTAProjectOptionsConfigurations, Configurations) then
  begin
    // Write it to all BuildConfigurations that have VersionInfos
    Modified := False;
    for BuildConfig in GetAllConfigurations(Project) do
    begin
      if BuildConfig.AsBoolean[sVerInfo_IncludeVerInfo]
        {and BuildConfig.PropertyExists(sVerInfo_Keys)} then // XE3: Exists(sVerInfo_Keys)=False but, Value[sVerInfo_Keys] returns value
      begin
        if UpdateAllPlatforms or SameText(BuildConfig.Platform, Configurations.ActivePlatformName) then
        begin
          SetBuildConfigInt(sVerInfo_MajorVer, Version.FileVersion.Major);
          SetBuildConfigInt(sVerInfo_MinorVer, Version.FileVersion.Minor);
          SetBuildConfigInt(sVerInfo_Release, Version.FileVersion.Release);
          SetBuildConfigInt(sVerInfo_Build, Version.FileVersion.Build);

          VerInfoKeys := TStringList.Create;
          try
            OrgKeys := BuildConfig.Value[sVerInfo_Keys];
            ExtractStrings([';'], [], PChar(OrgKeys), VerInfoKeys);

            VerInfoKeys.Values['FileVersion'] := Version.FileVersionStr;
            VerInfoKeys.Values['ProductVersion'] := Version.ProductVersionStr;
            VerInfoKeys.Values['ProductName'] := Version.ProductName;
            VerInfoKeys.Values['CompanyName'] := Version.CompanyName;
            VerInfoKeys.Values['FileDescription'] := Version.FileDescription;
            VerInfoKeys.Values['LegalCopyright'] := Version.LegalCopyright;
            VerInfoKeys.Values['LegalTrademarks'] := Version.LegalTrademarks;
            VerInfoKeys.Values['InternalName'] := Version.InternalName;
            VerInfoKeys.Values['OriginalFilename'] := Version.OriginalFilename;
            VerInfoKeys.Values['Comments'] := Version.Comments;

            Keys := '';
            for KeysIndex := 0 to VerInfoKeys.Count - 1 do
            begin
              if Keys = '' then
                Keys := VerInfoKeys[KeysIndex]
              else
                Keys := Keys + ';' + VerInfoKeys[KeysIndex];
            end;

            if Keys <> OrgKeys then
            begin
              BuildConfig.Value[sVerInfo_Keys] := Keys;
              Modified := True;
            end;
          finally
            VerInfoKeys.Free;
          end;
        end;
        Result := True;
      end;
    end;
    if Modified then
      Project.MarkModified;
  end;
end;

function SetVersionInfoExtraKey(AProject: IOTAProject; const AKey, AValue: string): Boolean;
var
  BuildConfig: IOTABuildConfiguration;
  KeysIndex: Integer;
  VerInfoKeys: TStrings;
  OrgKeys, Keys: string;
  Modified: Boolean;
begin
  Result := False;
  Modified := False;
  for BuildConfig in GetAllConfigurations(AProject) do
  begin
    if BuildConfig.AsBoolean[sVerInfo_IncludeVerInfo]
      {and BuildConfig.PropertyExists(sVerInfo_Keys)} then // XE3: Exists(sVerInfo_Keys)=False but, Value[sVerInfo_Keys] returns value
    begin
      VerInfoKeys := TStringList.Create;
      try
        OrgKeys := BuildConfig.Value[sVerInfo_Keys];
        ExtractStrings([';'], [], PChar(OrgKeys), VerInfoKeys);

        VerInfoKeys.Values[AKey] := AValue;

        Keys := '';
        for KeysIndex := 0 to VerInfoKeys.Count - 1 do
        begin
          if Keys = '' then
            Keys := VerInfoKeys[KeysIndex]
          else
            Keys := Keys + ';' + VerInfoKeys[KeysIndex];
        end;
        if Keys <> OrgKeys then
        begin
          BuildConfig.Value[sVerInfo_Keys] := Keys;
          Modified := True;
        end;
      finally
        VerInfoKeys.Free;
      end;
      Result := True;
    end;
  end;
  if Modified then
    AProject.MarkModified;
end;

type
{$ALIGN 2}
  PIconHeader = ^TIconHeader;
  TIconHeader = record
    wReserved: Word;
    wType: Word;
    cwCount: Word;
  end;

  PIconResDirectory = ^TIconResDirectory;
  TIconResDirectory = packed record
    bWidth: Byte;
    bHeight: Byte;
    bColorCount: Byte;
    bReserved: Byte;
    wPlanes: Word;
    wBitCount: Word;
    lBytesInRes: LongInt;
    wNameOrdinal: Word;
  end;

  PIconDirectory = ^TIconDirectory;
  TIconDirectory = record
    bWidth: Byte;
    bHeight: Byte;
    wColors: Word;
    lReserved: LongInt;
    lDIBSize: LongInt;
    lDIBOffset: LongInt;
  end;
{$ALIGN 8}

{ TIconResource }

constructor TIconResource.Create;
begin
  inherited Create;
  FStream := TMemoryStream.Create;
end;

destructor TIconResource.Destroy;
begin
  DestroyPaintIcon;
  FStream.Free;
  inherited Destroy;
end;

procedure TIconResource.DestroyPaintIcon;
begin
  if FPaintIcon <> 0 then
    DestroyIcon(FPaintIcon);
  FPaintIconIndex := -1;
  FPaintIcon := 0;
end;

procedure TIconResource.Clear;
begin
  DestroyPaintIcon;
  Stream.Size := 0;
  FFileName := '';
end;

function TIconResource.GetCount: Integer;
begin
  if (Data = nil) or (Stream.Size < SizeOf(TIconHeader)) then
    Result := 0
  else
    Result := PIconHeader(Data).cwCount;
end;

function TIconResource.GetData: Pointer;
begin
  if Stream.Size = 0 then
    Result := nil
  else
    Result := TMemoryStream(Stream).Memory;
end;

function TIconResource.GetImage(Index: Integer): TIconResourceItem;
type
  PInt64 = ^Int64;
  TPngHeader = array[0..7] of AnsiChar;
const
  PNGHeader: TPngHeader = #137'PNG'#13#10#26#10;
  MNGHeader: TPngHeader = #138'MNG'#13#10#26#10;
var
  Directory: PIconHeader;
  P: PIconDirectory;
begin
  if (Data <> nil) and (Index >= 0) and (Index < Count) then
  begin
    Directory := Data;
    Inc(Directory);
    P := PIconDirectory(Directory);
    Inc(P, Index);

    Result.Width := P.bWidth;
    if Result.Width = 0 then
      Result.Width := 256;
    Result.Height := P.bHeight;
    if Result.Height = 0 then
      Result.Height := 256;

    Result.Colors := P.wColors;
    Result.ImageDataSize := P.lDIBSize;
    Result.ImageData := PAnsiChar(Data) + P.lDIBOffset;

    { Handle BMP and PNG icons }
    Result.IsPng := (Result.ImageDataSize > SizeOf(Int64)) and
                    ((PInt64(Result.ImageData)^ = PInt64(@PngHeader)^) or
                     (PInt64(Result.ImageData)^ = PInt64(@MngHeader)^));
    if Result.IsPng then
    begin
      Result.Planes := 1;
      Result.BitCount := 32;
    end
    else
    begin
      Result.Planes := PBitmapInfoHeader(Result.ImageData).biPlanes;
      Result.BitCount := PBitmapInfoHeader(Result.ImageData).biBitCount;
    end;
  end
  else
    raise EListError.CreateFmt(SListIndexError, [Index]);
end;

function TIconResource.GetPaintIcon(Index: Integer): HICON;
var
  Item: TIconResourceItem;
begin
  if FPaintIconIndex <> Index then
  begin
    DestroyPaintIcon;
    Item := Images[Index];
    FPaintIcon := CreateIconFromResourceEx(Item.ImageData, Item.ImageDataSize, True, $00030000,
      Item.Width, Item.Height, 0);
    FPaintIconIndex := Index;
  end;
  Result := FPaintIcon;
end;

procedure TIconResource.LoadFromIconFile(const FileName: string);
begin
  Clear;
  FFileName := FileName;
  TMemoryStream(Stream).LoadFromFile(FileName);
end;

{procedure TIconResource.LoadFromMemory(P: PByte; Size: Integer);
begin
  Clear;
  if (P <> nil) and (Size > 0) then
  begin
    Stream.Write(P^, Size);
    Stream.Position := 0;
  end;
end;}

function ExpandRootMacro(const InString: string; const AdditionalVars: TObject = nil): string;
  external coreide_bpl name '@Uiutils@ExpandRootMacro$qqrx20System@UnicodeString' + _xp_ + '22Codemgr@TNameValueHash' {$IFDEF WIN64} delayed {$ENDIF};

procedure TIconResource.LoadFromProjectResource(AProject: IOTAProject);
var
  Configurations: IOTAProjectOptionsConfigurations;
  BuildConfig: IOTABuildConfiguration;
  IconFileName, Dir: string;
begin
  Clear;
  if Supports(AProject.ProjectOptions, IOTAProjectOptionsConfigurations, Configurations) then
  begin
    IconFileName := '';
    BuildConfig := Configurations.BaseConfiguration;
    if (BuildConfig <> nil) and (BuildConfig.Value[sIcon_MainIcon] <> '') then
      IconFileName := BuildConfig.Value[sIcon_MainIcon]
    else
    begin
      BuildConfig := Configurations.ActiveConfiguration;
      if (BuildConfig <> nil) and (BuildConfig.Value[sIcon_MainIcon] <> '') then
        IconFileName := BuildConfig.Value[sIcon_MainIcon]
    end;
    if IconFileName <> '' then
    begin
      IconFileName := ExpandRootMacro(IconFileName);
      Dir := GetCurrentDir;
      try
        SetCurrentDir(ExtractFilePath(AProject.FileName));
        LoadFromIconFile(IconFileName);
      finally
        SetCurrentDir(Dir);
      end;
    end;
  end;
end;

procedure TIconResource.SaveToProjectResource(AProject: IOTAProject);
var
  Configurations: IOTAProjectOptionsConfigurations;
  BuildConfig: IOTABuildConfiguration;
  IconFileName: string;
  Modified: Boolean;
begin
  if Supports(AProject.ProjectOptions, IOTAProjectOptionsConfigurations, Configurations) then
  begin
    Modified := False;
    BuildConfig := Configurations.BaseConfiguration;
    if (BuildConfig <> nil) {and (BuildConfig.Value[sIcon_MainIcon] <> '')} then
    begin
      if FFileName = '' then
        IconFileName := ''
      else if AnsiSameText(ExtractFilePath(FFileName), (BorlandIDEServices as IOTAServices).GetBinDirectory) then
        IconFileName := '$(BDS)\bin\' + ExtractFileName(FFileName)
      else
        IconFileName := ExtractRelativePath(ExtractFileDir(AProject.FileName), FFileName);

      if (Configurations.ActiveConfiguration <> BuildConfig) and (Configurations.ActiveConfiguration.Value[sIcon_MainIcon] <> '') then
      begin
        Configurations.ActiveConfiguration.Value[sIcon_MainIcon] := '';
        Modified := True;
      end;
      if BuildConfig.Value[sIcon_MainIcon] <> IconFileName then
      begin
        BuildConfig.Value[sIcon_MainIcon] := IconFileName;
        Modified := True;
      end;
      if Modified then
        AProject.MarkModified;
    end;
  end;
end;

end.

