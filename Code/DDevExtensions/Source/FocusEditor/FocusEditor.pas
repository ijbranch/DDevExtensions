{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FocusEditor;

/// <summary>
/// Hooks TDesktopStates.LoadDesktop so that, after a desktop layout change, focus is moved
/// back to the editor control inside the first visible TEditWindow. Without this, the IDE
/// often leaves focus on the project manager or message pane.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

{
  Sets the focus to the editor window when the desktop settings were changed.
}

uses
  System.SysUtils, System.Classes, Vcl.Forms, Vcl.Controls, IDEHooks, Hooking;

/// <summary>
/// Plug-in entry point. Installs the LoadDesktop hook on initialisation and removes it on
/// shutdown.
/// </summary>
/// <param name="Unload">False during plug-in initialisation, True during plug-in shutdown.</param>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  Winapi.Windows, IDEUtils;

var
  LoadDesktopHook: TRedirectCode;

procedure Hook_LoadDesktop(Instance: TObject; Desktop: TObject);
type
  TLoadDesktopProc = procedure(Instance: TObject; Desktop: TObject);
var
  I: Integer;
  Editor: TComponent;
begin
  UnhookFunction(LoadDesktopHook);
  try
    try
      // RealProc is nil when the prologue was never patched (a failed or no-op
      // install, e.g. on Win64); calling through it would AV.
      if Assigned(LoadDesktopHook.RealProc) then
        TLoadDesktopProc(LoadDesktopHook.RealProc)(Instance, Desktop);
    finally
      for I := 0 to Screen.FormCount - 1 do
      begin
        if (Screen.Forms[I].ClassName = 'TEditWindow') and
           Screen.Forms[I].Visible and Screen.Forms[I].Enabled and
           Screen.Forms[I].CanFocus then
        begin
          Editor := Screen.Forms[I].FindComponent('Editor');
          if (Editor is TWinControl) and TWinControl(Editor).CanFocus then
            TWinControl(Editor).SetFocus;
          Break;
        end;
      end;
    end;
  finally
    RehookFunction(@Hook_LoadDesktop, LoadDesktopHook);
  end;
end;

procedure InitPlugin(Unload: Boolean);
begin
  {$IFNDEF CPUX64}
  if not Unload then
  begin
    HookFunction(coreide_bpl, '@Desktop@TDesktopStates@LoadDesktop$qqrp21Desktop@TDesktopState',
      @Hook_LoadDesktop, LoadDesktopHook);
    // If the mangled symbol no longer resolves in a future IDE build, RealProc
    // is left nil and the feature silently dies; surface that during testing.
    if not Assigned(LoadDesktopHook.RealProc) then
      OutputDebugString('FocusEditor: LoadDesktop hook not installed (symbol unresolved or BPL not loaded).');
  end
  else
    UnhookFunction(LoadDesktopHook);
  {$ELSE}
  // The focus-editor hook relies on Hooking.HookFunction/CodeRedirect, which is a
  // no-op on Win64; the feature is intentionally inactive on the 64-bit IDE.
  {$ENDIF}
end;

end.

