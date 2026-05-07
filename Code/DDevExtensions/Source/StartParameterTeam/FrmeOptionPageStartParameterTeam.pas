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
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, ToolsAPI, FrmTreePages, FrmOptions, PluginConfig, StdCtrls,
  ModuleData, IDENotifiers, FrmeBase, ExtCtrls, IDEHooks, Hooking;

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
    function GetOptionPages: TTreePage; override;
    /// <summary>Initialises Active to False.</summary>
    procedure Init; override;
    /// <summary>BeforeSave handler that captures the project's current RunParams to user storage.</summary>
    procedure DoModuleBeforeSave(Data: TModuleData);
    /// <summary>AfterSave handler that strips the RunParams XML element from the project file.</summary>
    procedure DoModuleAfterSave(Data: TModuleData);
    /// <summary>Reserved hook for module rename (currently a no-op).</summary>
    procedure DoModuleRenamed(Data: TModuleData; const NewName: string);
    /// <summary>OnFileOpened handler that re-applies the saved RunParams to the project.</summary>
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string;
      var Cancel: Boolean);
  public
    /// <summary>Creates the configuration object and registers the IDE notifiers.</summary>
    constructor Create;
    /// <summary>Frees the notifiers and disables the feature.</summary>
    destructor Destroy; override;

    /// <summary>Strips the RunParams/Debugger_RunParams XML element from the project file in place.</summary>
    procedure RemoveRunParams(Project: IOTAProject);
  published
    /// <summary>Enables or disables the team feature.</summary>
    property Active: Boolean read FActive write FActive;
  end;

  /// <summary>Frame for the IDE options page that lets the user toggle the team feature.</summary>
  TFrameOptionPageStartParameterTeam = class(TFrameBase, ITreePageComponent)
    /// <summary>Checkbox that mirrors TStartParameterTeam.Active.</summary>
    cbxActive: TCheckBox;
  private
    { Private-Deklarationen }
    /// <summary>Backing reference to the configuration object whose state is edited.</summary>
    FStartParameterTeam: TStartParameterTeam;
  public
    { Public-Deklarationen }
    /// <summary>Receives the configuration object from the host page.</summary>
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
procedure InitPlugin(Unload: Boolean);

implementation

uses
  {$IF CompilerVersion >= 23.0} // XE2+
  CommonOptionStrs,
  {$IFEND}
  Variants, Main, ProjectData, IDEUtils;

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
end;

procedure TFrameOptionPageStartParameterTeam.SaveData;
begin
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
  FIDENotifier.Free;
  FModuleNotifier.Free;
  Active := False;
  inherited Destroy;
end;

procedure TStartParameterTeam.Init;
begin
  inherited Init;
  Active := False;
end;

procedure TStartParameterTeam.RemoveRunParams(Project: IOTAProject);
var
  Ext, S: string;
  StartPos, EndPos, Len: Integer;
  BOM: TBytes;
  Encoding: TEncoding;
  Stream: TFileStream;
  Filename: string;
  Lines: TStrings;
  I: Integer;
  Modified: Boolean;
  LastWriteTime: TFileTime;
begin
  { Remove RunParams from project file }

  {
     Delphi 2005-2009:
       bdsproj, dproj: <Parameters Name="RunParams">text</Parameters>
  }

  Encoding := nil;
  Modified := False;
  Lines := TStringList.Create;
  Stream := nil;
  try
    Filename := Project.FileName;
    Ext := LowerCase(ExtractFileExt(Filename));
    if ((Ext = '.dproj') or (Ext = '.cbproj')) and FileExists(Filename) then
    begin
      Stream := TFileStream.Create(Filename, fmOpenReadWrite or fmShareDenyRead);
      SetLength(BOM, 4);
      Stream.Read(BOM[0], 4);
      TEncoding.GetBufferEncoding(BOM, Encoding);
      Stream.Position := 0;
      Lines.LoadFromStream(Stream);
      for I := 0 to Lines.Count - 1 do
      begin
        S := Lines[I];
        StartPos := Pos('<Parameters Name="RunParams">', S);
        if StartPos > 0 then
        begin
          Inc(StartPos, Length('<Parameters Name="RunParams">'));
          Len := Length(S);
          EndPos := StartPos;
          while EndPos < Len do
          begin
            if (S[EndPos] = '<') and (S[EndPos + 1] = '/') and (StrLComp('</Parameters>', PChar(S) + EndPos - 1, 13) = 0) then
              Break;
            Inc(EndPos);
          end;
          if StartPos <> EndPos then
          begin
            S := Copy(S, 1, StartPos - 1) + Copy(S, EndPos, MaxInt);
            Lines[I] := S;
            Modified := True;
          end;
          Break;
        end;

        // XE2+
        StartPos := Pos('<Debugger_RunParams>', S);
        if StartPos <> 0 then
        begin
          Inc(StartPos, Length('<Debugger_RunParams>'));
          Len := Length(S);
          EndPos := StartPos;
          while EndPos < Len do
          begin
            if (S[EndPos] = '<') and (S[EndPos + 1] = '/') and (StrLComp('</Debugger_RunParams>', PChar(S) + EndPos - 1, 13) = 0) then
              Break;
            Inc(EndPos);
          end;
          if StartPos <> EndPos then
          begin
            S := Copy(S, 1, StartPos - 1) + Copy(S, EndPos, MaxInt);
            Lines[I] := S;
            Modified := True;
          end;
        end;
      end;
    end;

    if Modified then
    begin
      GetFileTime(Stream.Handle, nil, nil, @LastWriteTime);
      Stream.Position := 0;
      Lines.SaveToStream(Stream, Encoding);
      Stream.Size := Stream.Position;
      SetFileTime(Stream.Handle, nil, nil, @LastWriteTime);
    end;
  finally
    Lines.Free;
    Stream.Free;
  end;
end;

function TStartParameterTeam.GetOptionPages: TTreePage;
begin
  Result := TTreePage.Create('Local Start Parameters', TFrameOptionPageStartParameterTeam, Self);
end;

procedure TStartParameterTeam.DoModuleBeforeSave(Data: TModuleData);
var
  Project: IOTAProject;
  {$IF CompilerVersion >= 23.0} // XE2+
  OptionConfig: IOTAProjectOptionsConfigurations;
  BuildConfig: IOTABuildConfiguration;
  {$IFEND}
begin
  if Active then
  begin
    if Supports(Data.Module, IOTAProject, Project) and
       not Supports(Data.Module, IOTAProjectGroup) then
    begin
      {$IF CompilerVersion >= 23.0} // XE2+
      // XE2 Update 4 requires this
      if Supports(Project.ProjectOptions, IOTAProjectOptionsConfigurations, OptionConfig) then
      begin
        BuildConfig := OptionConfig.ActiveConfiguration;
        if (BuildConfig = nil) and (OptionConfig.ConfigurationCount > 0) then
          BuildConfig := OptionConfig.Configurations[0];

        if BuildConfig <> nil then
          ProjectDataList[Project].Values['RunParams'] := BuildConfig.GetValue(CommonOptionStrs.sDebugger_RunParams);
      end
      else
      {$IFEND}
        ProjectDataList[Project].Values['RunParams'] := Project.ProjectOptions.Values['RunParams'];
    end;
  end;
end;

procedure TStartParameterTeam.DoModuleAfterSave(Data: TModuleData);
var
  Project: IOTAProject;
begin
  if Active then
  begin
    if Supports(Data.Module, IOTAProject, Project) and
       not Supports(Data.Module, IOTAProjectGroup) then
    begin
      RemoveRunParams(Project);
    end;
  end;
end;

procedure TStartParameterTeam.DoModuleRenamed(Data: TModuleData; const NewName: string);
{var
  Project: IOTAProject;}
begin
{  if Active then
  begin
    if Supports(Data.Module, IOTAProject, Project) and
       not Supports(Data.Module, IOTAProjectGroup) then
    begin
      if FileExists(Project.FileName + '.localoptions') then
        RenameFile(Project.FileName + '.localoptions', NewName + '.localoptions');
    end;
  end;}
end;

procedure TStartParameterTeam.FileNotification(NotifyCode: TOTAFileNotification;
  const FileName: string; var Cancel: Boolean);
var
  Project: IOTAProject;
  {$IF CompilerVersion >= 23.0} // XE2+
  OptionConfig: IOTAProjectOptionsConfigurations;
  BuildConfig: IOTABuildConfiguration;
  {$IFEND}
  WasModified: Boolean;
  Ext: string;
begin
  if (NotifyCode = ofnFileOpened) and Active then
  begin
    Ext := AnsiLowerCase(ExtractFileExt(FileName));
    if (Ext = '.dpr') or (Ext = '.dpk') or (Ext = '.bpr') or
       (Ext = '.bdsproj') or
       (Ext = '.dproj') or (Ext = '.cbproj') then
    begin
      if Supports((BorlandIDEServices as IOTAModuleServices).FindModule(FileName), IOTAProject, Project) then
      begin
        if ProjectDataList[Project].HasValue('RunParams') then
        begin
          {$IF CompilerVersion >= 23.0} // XE2+
          // XE2 Update 4 requires this
          if Supports(Project.ProjectOptions, IOTAProjectOptionsConfigurations, OptionConfig) then
          begin
            BuildConfig := OptionConfig.ActiveConfiguration;
            if (BuildConfig = nil) and (OptionConfig.ConfigurationCount > 0) then
              BuildConfig := OptionConfig.Configurations[0];

            if BuildConfig <> nil then
            begin
              if BuildConfig.GetValue(CommonOptionStrs.sDebugger_RunParams) <> ProjectDataList[Project].Values['RunParams'] then
              begin
                WasModified := Project.ProjectOptions.ModifiedState;
                BuildConfig.SetValue(CommonOptionStrs.sDebugger_RunParams, ProjectDataList[Project].Values['RunParams']);
                Project.ProjectOptions.ModifiedState := WasModified;
              end;
            end;
          end
          else
          {$IFEND}
          begin
            if VarToStr(Project.ProjectOptions.Values['RunParams']) <> VarToStr(ProjectDataList[Project].Values['RunParams']) then
            begin
              WasModified := Project.ProjectOptions.ModifiedState;
              Project.ProjectOptions.Values['RunParams'] := ProjectDataList[Project].Values['RunParams'];
              Project.ProjectOptions.ModifiedState := WasModified;
            end;
          end;
        end;
      end;
    end;
  end;
end;

end.

