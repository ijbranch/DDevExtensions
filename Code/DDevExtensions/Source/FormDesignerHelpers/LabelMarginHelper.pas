{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2007 Andreas Hausladen                                                 *}
{*                                                                            *}
{******************************************************************************}

unit LabelMarginHelper;

/// <summary>
/// Patches TLabel so that, in the form designer, the default value for its bottom margin is zero
/// rather than the VCL default. This stops streaming the property out into DFMs unless explicitly
/// changed and keeps generated DFMs cleaner. Toggle the behaviour via SetLabelMarginActive.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, Vcl.Forms, Vcl.Controls, IDEHooks, Hooking, Vcl.StdCtrls;

/// <summary>
/// Activates or deactivates the TLabel margin override by replacing the VMT entry for
/// AfterConstruction with a hook that initialises Margins.Bottom to zero at design time.
/// </summary>
/// <param name="Active">True to install the hook, False to restore the original VMT entry.</param>
procedure SetLabelMarginActive(Active: Boolean);

implementation

type
  TLabelMargins = class(TMargins)
  protected
    class procedure InitDefaults(Margins: TMargins); override;
  published
    property Bottom default 0;
  end;

class procedure TLabelMargins.InitDefaults(Margins: TMargins);
begin
  inherited InitDefaults(Margins);
  Margins.Bottom := 0;
end;

procedure Label_AfterConstruction(Self: TLabel);
type
  TAfterConstructionProc = procedure(Self: TLabel);
var
  P: ^TMargins;
  ChangeEvent: TNotifyEvent;
begin
  if csDesigning in Self.ComponentState then
  begin
    P := @Self.Margins;
    ChangeEvent := Self.Margins.OnChange;
    P^.Free;
    P^ := TLabelMargins.Create(Self);
    P^.OnChange := ChangeEvent;
  end;
  TAfterConstructionProc(@TLabel.AfterConstruction)(Self);
end;

var
  IsActive: Boolean;

procedure SetLabelMarginActive(Active: Boolean);
begin
  if Active <> IsActive then
  begin
    IsActive := Active;
    if Active then
      ReplaceVmtField(TLabel, @TLabel.AfterConstruction, @Label_AfterConstruction)
    else
      ReplaceVmtField(TLabel, @Label_AfterConstruction, @TLabel.AfterConstruction);
  end;
end;

end.

