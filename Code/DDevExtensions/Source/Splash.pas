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
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls,
  ToolsAPI,
  Vcl.ExtCtrls, AppConsts;

/// <summary>Registers the DDevExtensions name/bitmap with the IDE splash screen and starts the IDE-loaded poll timer.</summary>
procedure ShowOnSplashScreen;
/// <summary>Cancels the IDE-loaded poll timer (called during plug-in unload).</summary>
procedure DoneSplash;

implementation

uses
  Main;

{$R Splash.res}

var
  /// <summary>Id of the IDE-loaded poll timer; 0 when none is running (SetTimer never returns 0 for a timer).</summary>
  InitTimerId       : UINT_PTR = 0;

/// <summary>TIMERPROC polling for the IDE main form; calls <see cref="Main.IDELoaded"/> once it is visible.</summary>
/// <param name="wnd">Unused (thread timer).</param>
/// <param name="Msg">Always WM_TIMER.</param>
/// <param name="idEvent">The timer id (pointer-width, as the TIMERPROC declares it).</param>
/// <param name="time">Tick count; unused.</param>
procedure IsIDELoaded( wnd: HWND; Msg: UINT; idEvent: UINT_PTR; time: DWORD ); stdcall;
begin
  if ( Application = nil ) or Application.Terminated then
  begin
    KillTimer( 0, InitTimerId );
    InitTimerId     := 0;
  end
  else if ( Application.MainForm <> nil ) and Application.MainForm.Visible then
  begin
    KillTimer( 0, InitTimerId );
    InitTimerId     := 0;
    IDELoaded;
  end;
end;

procedure ShowOnSplashScreen;
var
  SplashScreenInit  : Boolean;
begin
  SplashScreenInit  := False;
  if ( BorlandIDEServices <> nil ) and Assigned( SplashScreenServices ) then
  begin
    SplashScreenServices.StatusMessage( sPluginName );
    SplashScreenServices.AddPluginBitmap( sPluginName, LoadBitmap( Hinstance, 'DDEVEXTENSIONSLOGO' ) );
  end;

  if InitTimerId <> 0 then
    KillTimer( 0, InitTimerId );
  InitTimerId       := 0;
  if not SplashScreenInit then
    InitTimerId     := SetTimer( 0, 0, 100, @IsIDELoaded );
end;

procedure DoneSplash;
begin
  if InitTimerId <> 0 then
    KillTimer( 0, InitTimerId );
  InitTimerId       := 0;
end;

end.

