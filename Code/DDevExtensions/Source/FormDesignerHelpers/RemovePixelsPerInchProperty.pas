// * Copyright: ©2021 Fred Schetterer

unit RemovePixelsPerInchProperty;

/// <summary>
/// Replaces TDataModule.DefineProperties with a version that no longer writes the
/// PixelsPerInch property to the DFM, while still tolerating its presence on read so DFMs
/// produced by newer IDE versions can be opened in older versions. Toggle the redirect with
/// SetRemovePixelsPerInchPropertyActive.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, Vcl.Forms, Vcl.Controls, IDEHooks, Hooking;


/// <summary>
/// Activates or deactivates the TDataModule.DefineProperties redirection that suppresses
/// streaming of the PixelsPerInch property.
/// </summary>
/// <param name="Active">True to install the redirect, False to restore the original method.</param>
procedure SetRemovePixelsPerInchPropertyActive(Active: Boolean);

implementation

uses
  IDEUtils;

var
  HookTControl_DefineProperties: TRedirectCode;

type
  /// <summary>
  /// Class helper used to gain access to the private read/write callbacks declared on
  /// TDataModule (ReadHeight, WriteHeight, etc.) so the replacement DefineProperties body can
  /// register the same DFM properties without those callbacks being protected against external
  /// callers.
  /// </summary>
  TDataModuleHelper = class helper for TDataModule
    /// <summary>Replacement DefineProperties body installed by the hook.</summary>
    /// <param name="Filer">The DFM filer that the VCL passes during streaming.</param>
    procedure DefineProperties2(Filer: TFiler);
    {$IFNDEF COMPILER110_UP}
    // Delphi 10.2-10.4: TDataModule doesn't have these methods (added in Delphi 11)
    /// <summary>Reads and discards an identifier (used for OldCreateOrder on Delphi 10.x).</summary>
    procedure IgnoreIdent(Reader: TReader);
    /// <summary>Reads and discards an integer (used for PixelsPerInch on Delphi 10.x).</summary>
    procedure IgnoreInteger(Reader: TReader);
    {$ENDIF}
  end;

type
  /// <summary>Friend declaration giving the unit visibility of TDataModule's protected DefineProperties.</summary>
  TOpenDataModule = class(TDataModule);

var
  IsActive: Boolean;

{$IFNDEF COMPILER110_UP}
procedure TDataModuleHelper.IgnoreIdent(Reader: TReader);
begin
  Reader.ReadIdent;  // Read and discard the identifier
end;

procedure TDataModuleHelper.IgnoreInteger(Reader: TReader);
begin
  Reader.ReadInteger;  // Read and discard the value
end;
{$ENDIF}

procedure SetRemovePixelsPerInchPropertyActive(Active: Boolean);
begin
  if Active <> IsActive then
  begin
    IsActive := Active;
    if Active then
      CodeRedirect(@TOpenDataModule.DefineProperties, @TDataModule.DefineProperties2, HookTControl_DefineProperties)
    else
      UnhookFunction(HookTControl_DefineProperties);
  end;
end;

procedure TDataModuleHelper.DefineProperties2(Filer: TFiler);
var
  Ancestor: TDataModule;

  function DoWriteWidth: Boolean;
  begin
    Result := True;
    if Ancestor <> nil then
      Result := DesignSize.X <> Ancestor.DesignSize.X;
  end;

  function DoWriteHorizontalOffset: Boolean;
  begin
    if Ancestor <> nil then
      Result := DesignOffset.X <> Ancestor.DesignOffset.X else
      Result := DesignOffset.X <> 0;
  end;

  function DoWriteVerticalOffset: Boolean;
  begin
    if Ancestor <> nil then
      Result := DesignOffset.Y <> Ancestor.DesignOffset.Y else
      Result := DesignOffset.Y <> 0;
  end;

  function DoWriteHeight: Boolean;
  begin
    Result := True;
    if Ancestor <> nil then Result := DesignSize.Y <> Ancestor.DesignSize.Y;
  end;

begin
  Ancestor := TDataModule(Filer.Ancestor);
  with self do begin // access to private parts
    Filer.DefineProperty('Height', ReadHeight, WriteHeight, DoWriteHeight);
    Filer.DefineProperty('HorizontalOffset', ReadHorizontalOffset,
      WriteHorizontalOffset, DoWriteHorizontalOffset);
    Filer.DefineProperty('VerticalOffset', ReadVerticalOffset,
      WriteVerticalOffset, DoWriteVerticalOffset);
    Filer.DefineProperty('Width', ReadWidth, WriteWidth, DoWriteWidth);
    Filer.DefineProperty('OldCreateOrder', IgnoreIdent, nil, False);
{$IFDEF COMPILER110_UP}
    // We need to read if it exists else it Errors, but never write it..
    // ReadPixelsPerInch/WritePixelsPerInch were introduced in Delphi 11 Alexandria
    Filer.DefineProperty('PixelsPerInch', ReadPixelsPerInch, WritePixelsPerInch, (csReading in ComponentState));
{$ELSE}
    // Delphi 10.2-10.4: Read and discard PixelsPerInch if present (from DFMs created in Delphi 11+)
    // This allows 10.2-10.4 to open DFMs that contain PixelsPerInch without error
    Filer.DefineProperty('PixelsPerInch', IgnoreInteger, nil, False);
{$ENDIF}
  end;

{$IF CompilerVersion > 37}
  {$MESSAGE WARN 'Re-verify TDataModule.DefineProperties against the RTL for this compiler version'}
{$IFEND}
end;

end.
