{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit RemoveTextHeightProperty;

/// <summary>
/// Replaces TCustomForm.DefineProperties so that the TextHeight, IgnoreFontProperty and
/// OldCreateOrder DFM properties are read but not written. Available only on Delphi 11 (DELPHI28_UP)
/// and later, where TextHeight was introduced.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

{$IFDEF DELPHI28_UP}

uses
  System.SysUtils, System.Classes, Vcl.Forms, Vcl.Controls, IDEHooks, Hooking;

/// <summary>
/// Activates or deactivates the TCustomForm.DefineProperties redirection that suppresses
/// streaming of the TextHeight property.
/// </summary>
/// <param name="Active">True to install the redirect, False to restore the original method.</param>
procedure SetRemoveTextHeightPropertyActive(Active: Boolean);

{$ENDIF DELPHI28_UP}

implementation

{$IFDEF DELPHI28_UP}

uses
  IDEUtils;

var
  HookTForm_DefineProperties: TRedirectCode;

type
  TFormEx = class(TCustomForm)
    procedure IgnoreInteger(Reader: TReader);
    procedure ReadIgnoreFontProperty(Reader: TReader);
    procedure IgnoreIdent(Reader: TReader);
    procedure DefineProperties(Filer: TFiler); override;
  end;

  TOpenForm = class(TCustomForm);

procedure TFormEx.IgnoreInteger(Reader: TReader);
begin
  Reader.ReadInteger;
end;

procedure TFormEx.ReadIgnoreFontProperty(Reader: TReader);
begin   // reroute BCB IgnoreFontProperty to use VCL locale font solution
  if Reader.ReadBoolean then
    ParentFont := True;
end;

procedure TFormEx.IgnoreIdent(Reader: TReader);
begin
  Reader.ReadIdent;
end;

type
  TDefinePropertiesProc = procedure(Filer: TFiler) of object;

procedure TFormEx.DefineProperties(Filer: TFiler);
begin
  // Call grandparent TScrollingWinControl.DefineProperties directly
  // to avoid infinite recursion (TCustomForm.DefineProperties is hooked)
  var DefinePropertiesProc: TDefinePropertiesProc;
  TMethod(DefinePropertiesProc).Code := @TScrollingWinControl.DefineProperties;
  TMethod(DefinePropertiesProc).Data := Self;
  DefinePropertiesProc(Filer);

  Filer.DefineProperty('TextHeight', IgnoreInteger, nil, False);
  Filer.DefineProperty('IgnoreFontProperty', ReadIgnoreFontProperty, nil, False);
  Filer.DefineProperty('OldCreateOrder', IgnoreIdent, nil, False);
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

{$ENDIF DELPHI28_UP}

end.
