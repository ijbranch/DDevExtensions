unit CodeInsightHandling;

/// <summary>
/// Hooks TIDEPopupListBox.EditorKey so that pressing TAB inside a Code Insight pop-up
/// completes the suggestion in the same way ENTER does. Required IDE: Delphi 2009+.
/// </summary>

{
  IDE Version: 2009+

  Allows the TAB key to close the code insight window (like the ENTER key)
}

interface

/// <summary>
/// Plug-in entry point. Installs the TIDEPopupListBox.EditorKey redirect on initialisation
/// and restores the original method on shutdown.
/// </summary>
/// <param name="Unload">False during plug-in initialisation, True during plug-in shutdown.</param>
procedure InitPlugin(Unload: Boolean);

implementation

uses
  Windows, Hooking, IDEHooks;

procedure TIDEPopupListBox_EditorKey(Instance: TObject; Sender: TObject; var Key: Char);
  external coreide_bpl name '@Idepopuplistbox@TIDEPopupListBox@EditorKey$qqrp14System@TObjectrb' delayed;

var
  OrgIDEPopupListBox_EditorKey: procedure(Instance: TObject; Sender: TObject; var Key: Char);
  IDEPopupListBox_EditorKeyHooked: Boolean = False;

procedure HookedIDEPopupListBox_EditorKey(Instance: TObject; Sender: TObject; var Key: Char);
begin
  if Key = #9 then
    Key := #13;
  OrgIDEPopupListBox_EditorKey(Instance, Sender, Key);
end;

procedure InitPlugin(Unload: Boolean);
begin
  if not Unload then
  begin
    if not Assigned(OrgIDEPopupListBox_EditorKey) then
      @OrgIDEPopupListBox_EditorKey := RedirectOrgCall(@TIDEPopupListBox_EditorKey, @HookedIDEPopupListBox_EditorKey)
    else
      RedirectOrg(@TIDEPopupListBox_EditorKey, @HookedIDEPopupListBox_EditorKey);
  end
  else
    RestoreOrgCall(@TIDEPopupListBox_EditorKey, @OrgIDEPopupListBox_EditorKey);
end;


end.
