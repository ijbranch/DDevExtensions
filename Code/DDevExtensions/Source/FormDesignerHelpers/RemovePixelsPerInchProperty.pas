{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2008 Andreas Hausladen                                                 *}
{*                                                                            *}
{******************************************************************************}

unit RemovePixelsPerInchProperty;

{$I ..\DelphiExtension.inc}

interface

procedure SetRemovePixelsPerInchPropertyActive(Active: Boolean);

implementation

uses
  SysUtils, Classes, Forms, IDEHooks, Hooking;

var
  HookTDataModule_DefineProperties: TRedirectCode;

type
  TOpenDataModule = class(TDataModule);

  TDataModuleEx = class(TDataModule)
  private
    procedure IgnoreInteger(Reader: TReader);
    procedure ReadWidth(Reader: TReader);
    procedure WriteWidth(Writer: TWriter);
    procedure ReadHeight(Reader: TReader);
    procedure WriteHeight(Writer: TWriter);
    procedure ReadHorizontalOffset(Reader: TReader);
    procedure WriteHorizontalOffset(Writer: TWriter);
    procedure ReadVerticalOffset(Reader: TReader);
    procedure WriteVerticalOffset(Writer: TWriter);
  protected
    procedure DefineProperties(Filer: TFiler); override;
  end;

procedure TDataModuleEx.IgnoreInteger(Reader: TReader);
begin
  Reader.ReadInteger;
end;

procedure TDataModuleEx.ReadWidth(Reader: TReader);
begin
  DesignSize := Point(Reader.ReadInteger, DesignSize.Y);
end;

procedure TDataModuleEx.WriteWidth(Writer: TWriter);
begin
  Writer.WriteInteger(DesignSize.X);
end;

procedure TDataModuleEx.ReadHeight(Reader: TReader);
begin
  DesignSize := Point(DesignSize.X, Reader.ReadInteger);
end;

procedure TDataModuleEx.WriteHeight(Writer: TWriter);
begin
  Writer.WriteInteger(DesignSize.Y);
end;

procedure TDataModuleEx.ReadHorizontalOffset(Reader: TReader);
begin
  DesignOffset := Point(Reader.ReadInteger, DesignOffset.Y);
end;

procedure TDataModuleEx.WriteHorizontalOffset(Writer: TWriter);
begin
  Writer.WriteInteger(DesignOffset.X);
end;

procedure TDataModuleEx.ReadVerticalOffset(Reader: TReader);
begin
  DesignOffset := Point(DesignOffset.X, Reader.ReadInteger);
end;

procedure TDataModuleEx.WriteVerticalOffset(Writer: TWriter);
begin
  Writer.WriteInteger(DesignOffset.Y);
end;

procedure TDataModuleEx.DefineProperties(Filer: TFiler);

  function DoWriteWidth: Boolean;
  begin
    Result := (Filer.Ancestor = nil) or
              (TDataModule(Filer.Ancestor).DesignSize.X <> DesignSize.X);
  end;

  function DoWriteHeight: Boolean;
  begin
    Result := (Filer.Ancestor = nil) or
              (TDataModule(Filer.Ancestor).DesignSize.Y <> DesignSize.Y);
  end;

  function DoWriteHorizontalOffset: Boolean;
  begin
    Result := (Filer.Ancestor <> nil) and
              (TDataModule(Filer.Ancestor).DesignOffset.X <> DesignOffset.X);
  end;

  function DoWriteVerticalOffset: Boolean;
  begin
    Result := (Filer.Ancestor <> nil) and
              (TDataModule(Filer.Ancestor).DesignOffset.Y <> DesignOffset.Y);
  end;

begin
  // Redefine all properties - PixelsPerInch reads but never writes
  Filer.DefineProperty('Height', ReadHeight, WriteHeight,
    not (csReading in ComponentState) and DoWriteHeight);
  Filer.DefineProperty('HorizontalOffset', ReadHorizontalOffset, WriteHorizontalOffset,
    not (csReading in ComponentState) and DoWriteHorizontalOffset);
  Filer.DefineProperty('VerticalOffset', ReadVerticalOffset, WriteVerticalOffset,
    not (csReading in ComponentState) and DoWriteVerticalOffset);
  Filer.DefineProperty('Width', ReadWidth, WriteWidth,
    not (csReading in ComponentState) and DoWriteWidth);

  // PixelsPerInch: read if present, but never write
  if csDesigning in ComponentState then
    Filer.DefineProperty('PixelsPerInch', IgnoreInteger, nil, False);
end;

var
  IsActive: Boolean;

procedure SetRemovePixelsPerInchPropertyActive(Active: Boolean);
begin
  if Active <> IsActive then
  begin
    IsActive := Active;
    if Active then
      CodeRedirect(@TOpenDataModule.DefineProperties, @TDataModuleEx.DefineProperties, HookTDataModule_DefineProperties)
    else
      UnhookFunction(HookTDataModule_DefineProperties);
  end;
end;

end.
