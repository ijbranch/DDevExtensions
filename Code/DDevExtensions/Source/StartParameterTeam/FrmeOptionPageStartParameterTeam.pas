{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmeOptionPageStartParameterTeam;

/// <summary>
/// Implements the "Local Start Parameters" team feature: when active, run parameters stored in the
/// project file are stripped on save (so they stay local to each developer) and re-applied on the
/// next open from the per-user project data store.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, ToolsAPI, FrmTreePages, FrmOptions, PluginConfig, Vcl.StdCtrls,
  ModuleData, IDENotifiers, FrmeBase, Vcl.ExtCtrls, IDEHooks, Hooking;

type
  /// <summary>
  /// Plugin configuration object that registers the IDE notifiers used to keep run parameters out
  /// of shared project files while preserving them locally per developer.
  /// </summary>
  TStartParameterTeam = class(TPluginConfig)
  private
    /// <summary>Notifier that hooks BeforeSave/AfterSave to capture and strip RunParams.</summary>
    FModuleNotifier: TModuleDataNotifier;
    /// <summary>Notifier that re-applies the saved RunParams when the project is reopened.</summary>
    FIDENotifier: TIDENotifier;
    /// <summary>Backing field for Active.</summary>
    FActive: Boolean;
  protected
    /// <summary>Returns the options-page descriptor for the IDE's options dialog.</summary>
    /// <returns>The page descriptor naming the frame class and this object as its user data.</returns>
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises Active to False.</summary>
    procedure Init; override;
    /// <summary>BeforeSave handler that captures the project's current RunParams to user storage.</summary>
    /// <param name="Data">The module data of the project about to be saved.</param>
    procedure DoModuleBeforeSave(Data: TModuleData);
    /// <summary>AfterSave handler that strips the RunParams XML element from the project file.</summary>
    /// <param name="Data">The module data of the saved project.</param>
    procedure DoModuleAfterSave(Data: TModuleData);
    /// <summary>Reserved hook for module rename (currently a no-op).</summary>
    /// <param name="NewName">The project's new file name.</param>
    /// <param name="Data">The module data of the renamed project.</param>
    procedure DoModuleRenamed(Data: TModuleData; const NewName: string);
    /// <summary>OnFileOpened handler that re-applies the saved RunParams to the project.</summary>
    /// <param name="Cancel">Set True to cancel the operation; left unchanged here.</param>
    /// <param name="FileName">The file the notification is about.</param>
    /// <param name="NotifyCode">The IDE file notification.</param>
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string;
      var Cancel: Boolean);
  public
    /// <summary>Creates the configuration object and registers the IDE notifiers.</summary>
    constructor Create;
    /// <summary>Frees the notifiers and disables the feature.</summary>
    destructor Destroy; override;

    /// <summary>
    /// Strips the content of every RunParams/Debugger_RunParams element from the project file,
    /// replacing the file atomically. A failure is reported in the Messages view.
    /// </summary>
    /// <param name="Project">The project just saved.</param>
    procedure RemoveRunParams(Project: IOTAProject);
    /// <summary>
    /// True when the feature can run in this IDE. False in the 64-bit IDE, where the
    /// file-open notification that restores the run parameters is never registered.
    /// </summary>
    /// <returns>True in the 32-bit IDE.</returns>
    class function IsAvailable: Boolean;
  published
    /// <summary>Enables or disables the team feature.</summary>
    property Active: Boolean read FActive write FActive;
  end;

  /// <summary>Frame for the IDE options page that lets the user toggle the team feature.</summary>
  TFrameOptionPageStartParameterTeam = class(TFrameBase, ITreePageComponent)
    /// <summary>Checkbox that mirrors TStartParameterTeam.Active.</summary>
    cbxActive: TCheckBox;
  private
    /// <summary>Backing reference to the configuration object whose state is edited.</summary>
    FStartParameterTeam: TStartParameterTeam;
  public
    /// <summary>Receives the configuration object from the host page.</summary>
    /// <param name="UserData">The TStartParameterTeam object to edit.</param>
    procedure SetUserData(UserData: TObject);
    /// <summary>Pushes the current Active value into the checkbox.</summary>
    procedure LoadData;
    /// <summary>Pulls the checkbox value into Active and persists the configuration.</summary>
    procedure SaveData;
    /// <summary>ITreePageComponent: called when the page becomes active (no-op).</summary>
    procedure Selected;
    /// <summary>ITreePageComponent: called when the page becomes inactive (no-op).</summary>
    procedure Unselected;
  end;

/// <summary>Plugin entry point that creates or frees the global TStartParameterTeam.</summary>
/// <param name="Unload">False to create the plugin object at start-up; True to free it at shutdown.</param>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  {$IF CompilerVersion >= 23.0} // XE2+
  CommonOptionStrs,
  {$IFEND}
  System.Variants, System.IOUtils, System.RegularExpressions, Main, ProjectData, IDEUtils;

{$R *.dfm}

var
  StartParameterTeam: TStartParameterTeam;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
    StartParameterTeam := TStartParameterTeam.Create
  else
    FreeAndNil(StartParameterTeam);
end;

{ TFrameOptionPageStartParameterTeam }

procedure TFrameOptionPageStartParameterTeam.SetUserData(UserData: TObject);
begin
  FStartParameterTeam := UserData as TStartParameterTeam;
end;

procedure TFrameOptionPageStartParameterTeam.LoadData;
begin
  cbxActive.Checked := FStartParameterTeam.Active;
  if not TStartParameterTeam.IsAvailable then
  begin
    // The restore half cannot run on the 64-bit IDE, so the feature is off there and
    // says so, rather than stripping run parameters that nothing puts back.
    cbxActive.Enabled := False;
    cbxActive.Hint := 'Not available on the 64-bit IDE';
    cbxActive.ShowHint := True;
  end;
end;

procedure TFrameOptionPageStartParameterTeam.SaveData;
begin
  // On the 64-bit IDE the setting is left as the 32-bit IDE has it (the file is shared).
  if not TStartParameterTeam.IsAvailable then
    Exit;
  FStartParameterTeam.Active := cbxActive.Checked;
  FStartParameterTeam.Save;
end;

procedure TFrameOptionPageStartParameterTeam.Selected;
begin
end;

procedure TFrameOptionPageStartParameterTeam.Unselected;
begin
end;

{ TStartParameterTeam }

constructor TStartParameterTeam.Create;
begin
  inherited Create(AppDataDirectory + '\StartParameterTeam.xml', 'StartParameterTeam');

  FModuleNotifier := TModuleDataNotifier.Create;
  FModuleNotifier.BeforeSave := DoModuleBeforeSave;
  FModuleNotifier.AfterSave := DoModuleAfterSave;

  FIDENotifier := TIDENotifier.Create;
  FIDENotifier.OnFileNotification := FileNotification;
end;

destructor TStartParameterTeam.Destroy;
begin
  // Disable first so any in-flight callback short-circuits, then free the
  // notifiers (which unregister from the IDE in their own destructors).
  Active := False;
  FIDENotifier.Free;
  FModuleNotifier.Free;
  inherited Destroy;
end;

procedure TStartParameterTeam.Init;
begin
  inherited Init;
  Active := False;
end;

const
  /// <summary>Prefix of the per-level keys in the project data store: "RunParams.&lt;config key&gt;[.&lt;platform&gt;]".</summary>
  RunParamsKeyPrefix = 'RunParams.';
  /// <summary>Marks a project whose run parameters were stored per configuration and platform.</summary>
  RunParamsFormatKey = 'RunParamsFormat';
  /// <summary>Prefix of a stored value that was set at that level (an empty stored value means "not set there").</summary>
  RunParamsSetMarker = 'V:';

/// <summary>
/// Calls AProc for every configuration of the project and every platform beneath it, with
/// the data-store key that level's run parameters are kept under.
/// </summary>
/// <param name="AOptionConfig">The project's configurations.</param>
/// <param name="AProc">Receives each configuration level and its key.</param>
procedure ForEachRunParamsLevel( const AOptionConfig: IOTAProjectOptionsConfigurations;
  const AProc: TProc<IOTABuildConfiguration, string> );
begin
  for var I := 0 to AOptionConfig.ConfigurationCount - 1 do
  begin
    var Config := AOptionConfig.Configurations[I];
    if ( Config = nil ) then
      Continue;
    AProc( Config, RunParamsKeyPrefix + Config.Key );
    for var PlatformName in Config.Platforms do
    begin
      var PlatformConfig := Config.PlatformConfiguration[PlatformName];
      if ( PlatformConfig <> nil ) then
        AProc( PlatformConfig, RunParamsKeyPrefix + Config.Key + '.' + PlatformName );
    end;
  end;
end;

/// <summary>Reports a failure in the IDE's Messages view, where it does not interrupt a save.</summary>
/// <param name="AText">The message.</param>
procedure ReportToMessages( const AText: string );
var
  MessageServices: IOTAMessageServices;
begin
  OutputDebugString( PChar( 'DDevExtensions: ' + AText ) );
  if Supports( BorlandIDEServices, IOTAMessageServices, MessageServices ) then
    MessageServices.AddTitleMessage( 'DDevExtensions: ' + AText );
end;

/// <summary>
/// Returns AText with the content of every <c>Debugger_RunParams</c> element, and of the
/// older <c>&lt;Parameters Name="RunParams"&gt;</c> element, removed. Everything else,
/// line breaks included, is untouched.
/// </summary>
/// <param name="AText">The project file text.</param>
/// <returns>The stripped text.</returns>
function StripRunParams( const AText: string ): string;
begin
  // XML escapes '<' inside a value, so "[^<]*" is exactly the element's content.
  Result := TRegEx.Replace( AText, '(<Debugger_RunParams>)[^<]*(</Debugger_RunParams>)', '$1$2' );
  Result := TRegEx.Replace( Result, '(<Parameters Name="RunParams">)[^<]*(</Parameters>)', '$1$2' );
end;

procedure TStartParameterTeam.RemoveRunParams(Project: IOTAProject);
begin
  { Remove RunParams from project file:
      Delphi 2005-2009: <Parameters Name="RunParams">text</Parameters>
      XE2+:             <Debugger_RunParams>text</Debugger_RunParams> }
  var Filename := Project.FileName;
  var Ext := LowerCase( ExtractFileExt( Filename ) );
  if not ( ( Ext = '.dproj' ) or ( Ext = '.cbproj' ) ) or not FileExists( Filename ) then
    Exit;

  var TempName := Filename + '.ddevext.tmp';
  try
    var Bytes := TFile.ReadAllBytes( Filename );

    // Keep the file's own encoding: a BOM if it had one, and UTF-8 unless the bytes are not UTF-8.
    var Encoding: TEncoding := nil;
    var PreambleSize := TEncoding.GetBufferEncoding( Bytes, Encoding, nil );
    var OwnsEncoding := False;
    if ( Encoding = nil ) then
    begin
      PreambleSize := 0;
      Encoding := TUTF8Encoding.Create( CP_UTF8, MB_ERR_INVALID_CHARS, 0 );
      OwnsEncoding := True;
    end;
    try
      var Text := '';
      try
        Text := Encoding.GetString( Bytes, PreambleSize, Length( Bytes ) - PreambleSize );
      except
        on EEncodingError do
        begin
          // Not UTF-8: an ANSI file round-trips through the ANSI code page unchanged.
          if OwnsEncoding then
            Encoding.Free;
          OwnsEncoding := False;
          Encoding := TEncoding.ANSI;
          Text := Encoding.GetString( Bytes, PreambleSize, Length( Bytes ) - PreambleSize );
        end;
      end;

      var Stripped := StripRunParams( Text );
      if ( Stripped = Text ) then
        Exit;

      var NewBytes := Encoding.GetBytes( Stripped );
      if ( PreambleSize > 0 ) then
        NewBytes := Copy( Bytes, 0, PreambleSize ) + NewBytes;

      // Atomic replacement: a failure part-way leaves the original untouched. The
      // write time is kept so the IDE does not offer to reload the file it just saved.
      var WriteTime := TFile.GetLastWriteTimeUtc( Filename );
      TFile.WriteAllBytes( TempName, NewBytes );
      TFile.SetLastWriteTimeUtc( TempName, WriteTime );
      if not MoveFileEx( PChar( TempName ), PChar( Filename ), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH ) then
        RaiseLastOSError;
    finally
      if OwnsEncoding then
        Encoding.Free;
    end;
  except
    on E: Exception do
    begin
      // A locked, read-only or network .dproj must not abort the IDE save pipeline,
      // but the user must know the run parameters are still in the shared file.
      System.SysUtils.DeleteFile( TempName );
      ReportToMessages( Format( 'Local Start Parameters could not remove the run parameters from "%s": %s',
        [Filename, E.Message] ) );
    end;
  end;
end;

function TStartParameterTeam.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('Local Start Parameters', TFrameOptionPageStartParameterTeam, Self);
end;

class function TStartParameterTeam.IsAvailable: Boolean;
begin
  // The restore half runs from a file-open notification, and TIDENotifier is never
  // registered on the 64-bit IDE. Stripping there would remove run parameters that
  // nothing puts back.
  {$IFDEF CPUX64}
  Result := False;
  {$ELSE}
  Result := True;
  {$ENDIF}
end;

procedure TStartParameterTeam.DoModuleBeforeSave(Data: TModuleData);
var
  Project: IOTAProject;
  OptionConfig: IOTAProjectOptionsConfigurations;
begin
  if not Active or not IsAvailable then
    Exit;
  if not Supports( Data.Module, IOTAProject, Project ) or Supports( Data.Module, IOTAProjectGroup ) then
    Exit;

  var ProjData := ProjectDataList[Project];
  if Supports( Project.ProjectOptions, IOTAProjectOptionsConfigurations, OptionConfig ) then
  begin
    // Every configuration and platform keeps its own run parameters: each level is
    // stored separately, "set here" being distinguished from "inherited".
    ForEachRunParamsLevel( OptionConfig,
      procedure( AConfig: IOTABuildConfiguration; AKey: string )
      begin
        if AConfig.PropertyExists( sDebugger_RunParams ) then
          ProjData.Values[AKey] := RunParamsSetMarker + AConfig.GetValue( sDebugger_RunParams, False )
        else
          ProjData.Values[AKey] := '';
      end );
    ProjData.Values[RunParamsFormatKey] := 2;

    // Also the single value older builds read and write, so rolling back to one, or an
    // older build in the other IDE, still finds the active configuration's parameters.
    var Active := OptionConfig.ActiveConfiguration;
    if ( Active = nil ) and ( OptionConfig.ConfigurationCount > 0 ) then
      Active := OptionConfig.Configurations[0];
    if ( Active <> nil ) then
      ProjData.Values['RunParams'] := Active.GetValue( sDebugger_RunParams );
  end
  else
    ProjData.Values['RunParams'] := Project.ProjectOptions.Values['RunParams'];
end;

procedure TStartParameterTeam.DoModuleAfterSave(Data: TModuleData);
var
  Project: IOTAProject;
begin
  if not Active or not IsAvailable then
    Exit;
  if Supports( Data.Module, IOTAProject, Project ) and not Supports( Data.Module, IOTAProjectGroup ) then
    RemoveRunParams( Project );
end;

procedure TStartParameterTeam.DoModuleRenamed(Data: TModuleData; const NewName: string);
begin
  // Reserved: the per-user store follows the project through ProjectDataList.
end;

procedure TStartParameterTeam.FileNotification(NotifyCode: TOTAFileNotification;
  const FileName: string; var Cancel: Boolean);
var
  Project: IOTAProject;
  OptionConfig: IOTAProjectOptionsConfigurations;
  ModuleSvc: IOTAModuleServices;
begin
  if ( NotifyCode <> ofnFileOpened ) or not Active or not IsAvailable then
    Exit;

  var Ext := AnsiLowerCase( ExtractFileExt( FileName ) );
  if not ( ( Ext = '.dpr' ) or ( Ext = '.dpk' ) or ( Ext = '.bpr' ) or ( Ext = '.bdsproj' ) or
     ( Ext = '.dproj' ) or ( Ext = '.cbproj' ) ) then
    Exit;
  if ( BorlandIDEServices = nil ) or not Supports( BorlandIDEServices, IOTAModuleServices, ModuleSvc ) or
     not Supports( ModuleSvc.FindModule( FileName ), IOTAProject, Project ) then
    Exit;

  var ProjData := ProjectDataList[Project];
  var WasModified := Project.ProjectOptions.ModifiedState;
  try
    if ProjData.HasValue( RunParamsFormatKey ) and
       Supports( Project.ProjectOptions, IOTAProjectOptionsConfigurations, OptionConfig ) then
    begin
      ForEachRunParamsLevel( OptionConfig,
        procedure( AConfig: IOTABuildConfiguration; AKey: string )
        begin
          if not ProjData.HasValue( AKey ) then
            Exit;
          var Stored := VarToStr( ProjData.Values[AKey] );
          if not Stored.StartsWith( RunParamsSetMarker ) then
            Exit;
          var Value := Copy( Stored, Length( RunParamsSetMarker ) + 1, MaxInt );
          if not AConfig.PropertyExists( sDebugger_RunParams ) or
             ( AConfig.GetValue( sDebugger_RunParams, False ) <> Value ) then
            AConfig.SetValue( sDebugger_RunParams, Value );
        end );

      // An older build stores and edits only the single value. If it differs from what the
      // per-level values give the active configuration, that build changed it since: it wins.
      if ProjData.HasValue( 'RunParams' ) then
      begin
        var Active := OptionConfig.ActiveConfiguration;
        if ( Active = nil ) and ( OptionConfig.ConfigurationCount > 0 ) then
          Active := OptionConfig.Configurations[0];
        var Legacy := VarToStr( ProjData.Values['RunParams'] );
        if ( Active <> nil ) and ( Active.GetValue( sDebugger_RunParams ) <> Legacy ) then
          Active.SetValue( sDebugger_RunParams, Legacy );
      end;
    end
    else if ProjData.HasValue( 'RunParams' ) then
    begin
      // Stored by an older build: one value, for the active configuration.
      if Supports( Project.ProjectOptions, IOTAProjectOptionsConfigurations, OptionConfig ) then
      begin
        var BuildConfig := OptionConfig.ActiveConfiguration;
        if ( BuildConfig = nil ) and ( OptionConfig.ConfigurationCount > 0 ) then
          BuildConfig := OptionConfig.Configurations[0];
        if ( BuildConfig <> nil ) and
           ( BuildConfig.GetValue( sDebugger_RunParams ) <> VarToStr( ProjData.Values['RunParams'] ) ) then
          BuildConfig.SetValue( sDebugger_RunParams, VarToStr( ProjData.Values['RunParams'] ) );
      end
      else if ( VarToStr( Project.ProjectOptions.Values['RunParams'] ) <> VarToStr( ProjData.Values['RunParams'] ) ) then
        Project.ProjectOptions.Values['RunParams'] := ProjData.Values['RunParams'];
    end;
  finally
    Project.ProjectOptions.ModifiedState := WasModified;
  end;
end;

end.
