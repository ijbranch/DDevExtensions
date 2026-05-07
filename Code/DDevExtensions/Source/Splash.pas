{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2005-2013 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit Splash;

/// <summary>
/// Adds DDevExtensions to the Delphi splash screen and About box, and polls
/// for the IDE main form becoming visible so <see cref="Main.IDELoaded"/>
/// can be invoked at the right moment.
/// </summary>
/// <remarks>
/// The IDE-loaded detection uses a <c>SetTimer</c> poll because there is no
/// reliable ToolsAPI notification for "main form is now visible".
/// </remarks>

{$I DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, Graphics, StdCtrls,
  ToolsAPI,
  ExtCtrls, AppConsts;

/// <summary>Registers the DDevExtensions name/bitmap with the IDE splash screen and starts the IDE-loaded poll timer.</summary>
procedure ShowOnSplashScreen;
/// <summary>Updates the (legacy) progress label shown during plug-in initialisation.</summary>
procedure SetSplashProgress(const Text: string);
/// <summary>Cancels the IDE-loaded poll timer (called during plug-in unload).</summary>
procedure DoneSplash;

implementation

uses
  Main;

{$R Splash.res}

var
  LblProgress: TLabel;

type
  TSplashScreen = class(TComponent)
  public
    destructor Destroy; override;
  end;

destructor TSplashScreen.Destroy;
begin
  LblProgress := nil;
  IDELoaded;
  if Supports(BorlandIDEServices, IOTAAboutBoxServices) then
    (BorlandIDEServices as IOTAAboutBoxServices).AddPluginInfo(sPluginName, 'DDevExtensions - Extensions for the IDE' +
       sLineBreak + sLineBreak + sPluginSmallCopyright, 0);
  inherited Destroy;
end;

procedure SetSplashProgress(const Text: string);
begin
  if Assigned(LblProgress) then
    LblProgress.Caption := Text;
end;

var
  InitTimerId: Integer = -1;

procedure IsIDELoaded(wnd: HWND; Msg: Cardinal; idEvent: Cardinal; time: LongWord); stdcall;
begin
  if (Application = nil) or Application.Terminated then
  begin
    KillTimer(0, InitTimerId);
    InitTimerId := -1;
  end
  else
  if (Application.MainForm <> nil) and Application.MainForm.Visible then
  begin
    KillTimer(0, InitTimerId);
    InitTimerId := -1;
    IDELoaded;
  end;
end;

procedure ShowOnSplashScreen;
var
  SplashScreenInit: Boolean;
begin
  SplashScreenInit := False;
  if BorlandIDEServices <> nil then
  begin
    SplashScreenServices.StatusMessage(sPluginName);
    SplashScreenServices.AddPluginBitmap(sPluginName, LoadBitmap(Hinstance, 'DDEVEXTENSIONSLOGO'));
  end;

  if InitTimerId <> -1 then
    KillTimer(0, InitTimerId);
  InitTimerId := -1;
  if not SplashScreenInit then
    InitTimerId := SetTimer(0, 0, 100, @IsIDELoaded);
end;

procedure DoneSplash;
begin
  if InitTimerId <> -1 then
    KillTimer(0, InitTimerId);
end;

end.
