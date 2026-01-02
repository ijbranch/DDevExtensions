{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2008 Andreas Hausladen                                                 *}
{*                                                                            *}
{******************************************************************************}

unit RemoveTextHeightProperty;

{$I ..\DelphiExtension.inc}

interface

procedure SetRemoveTextHeightPropertyActive(Active: Boolean);

implementation

uses
  SysUtils, Classes, Forms, IDEHooks, Hooking;

var
  HookTForm_DefineProperties: TRedirectCode;

type
  TOpenForm = class(TCustomForm);

  TFormEx = class(TCustomForm)
  protected
    procedure IgnoreInteger(Reader: TReader);
    procedure DefineProperties(Filer: TFiler); override;
  end;

procedure TFormEx.IgnoreInteger(Reader: TReader);
begin
  Reader.ReadInteger;
end;

procedure TFormEx.DefineProperties(Filer: TFiler);
begin
  inherited DefineProperties(Filer);
  // Override TextHeight to be read but never written
  if csDesigning in ComponentState then
    Filer.DefineProperty('TextHeight', IgnoreInteger, nil, False);
end;

var
  IsActive: Boolean;

procedure SetRemoveTextHeightPropertyActive(Active: Boolean);
begin
  if Active <> IsActive then
  begin
    IsActive := Active;
    if Active then
      CodeRedirect(@TOpenForm.DefineProperties, @TFormEx.DefineProperties, HookTForm_DefineProperties)
    else
      UnhookFunction(HookTForm_DefineProperties);
  end;
end;

end.
