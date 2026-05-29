{************************************************}
{                                                }
{               EurekaLog v 7.x                  }
{                                                }
{      FastMM5 Support - EFastMM5Support         }
{                                                }
{  Copyright (c) 2001 - 2024 by Fabio Dell'Aria  }
{                                                }
{************************************************}
unit EFastMM5Support;

{$I ELDefines.inc}

interface

uses
  FastMM5,
  EMemLeaks,
  EResLeaks,
  ETypes;

var
  ForceUseRAWTracing: Boolean = True; // FastMM defaults to RAW stack tracing

procedure FastMM_GetStackTrace_EurekaLog(APReturnAddresses: PNativeUInt; AMaxDepth, ASkipFrames: Cardinal);
procedure FastMM_GetStackTrace_EurekaLog_Frames(APReturnAddresses: PNativeUInt; AMaxDepth, ASkipFrames: Cardinal);
procedure FastMM_GetStackTrace_EurekaLog_RAW(APReturnAddresses: PNativeUInt; AMaxDepth, ASkipFrames: Cardinal);
function  FastMM_ConvertStackTraceToText_EurekaLog(APReturnAddresses: PNativeUInt; AMaxDepth: Cardinal; APBuffer, APBufferEnd: PWideChar): PWideChar;

implementation

uses
  {$IFDEF Windows}WinAPI.Windows,{$ENDIF}
  System.SysUtils,

  ELowLevel,
  ELogging,
  EDisAsm,
  EDebugInfo,
  EBase,
  EClasses,
  EStackTracing,
  ECallStack,
  EInfoFormat;

type
  PStackTrace = ^TStackTrace;
  TStackTrace = record
    ReturnAddresses: PPtrUInt;
    MaxDepth: Cardinal;
    SkipFrames: Cardinal;
    Count: Integer;
    FirstAddr: Pointer;
  end;

function _AddToStack(const AStack, AReturnAddress: Pointer; const ATrace, ATag: Pointer): Boolean;
var
  Trace: PStackTrace;
begin
  if not AssignedEx(AReturnAddress) then
  begin
    Result := False;
    Exit;
  end;

  Trace := PStackTrace(ATrace);

  if Assigned(Trace.FirstAddr) then
  begin
    if PtrUInt(Trace.FirstAddr) >= PtrUInt(AStack) then
    begin
      Result := True;
      Exit;
    end;
  end;

  Inc(Trace.Count);
  if Trace.Count > 0 then
  begin
    PPointer(Trace.ReturnAddresses)^ := AReturnAddress;
    Inc(Trace.ReturnAddresses);
  end;

  Result := (Trace.Count < Integer(Trace.MaxDepth));
end;

procedure FastMM_GetStackTrace_EurekaLog_Frames(APReturnAddresses: PNativeUInt; AMaxDepth, ASkipFrames: Cardinal);
var
  Trace: TStackTrace;
  StackFrame, TopOfStack: Pointer;
begin
  StackFrame := GetStackFrame;
  TopOfStack := GetTopOfStack;

  if not Assigned(Tracers[TracerLeaksFrame]) then
    Exit;

  FillChar(Trace, SizeOf(Trace), 0);
  Trace.ReturnAddresses := Pointer(APReturnAddresses);
  Trace.MaxDepth := AMaxDepth;
  Trace.SkipFrames := ASkipFrames;
  Trace.Count := -Integer(Trace.SkipFrames);
  Trace.FirstAddr := StackFrame;

  TraceStack(TracerLeaksFrame, nil, StackFrame, TopOfStack, nil, 0, @Trace, _AddToStack,
    False { enabling logging will cause Context to be logged, which means allocating memory - leading to infinite loop});
end;

procedure FastMM_GetStackTrace_EurekaLog_RAW(APReturnAddresses: PNativeUInt; AMaxDepth, ASkipFrames: Cardinal);
var
  Trace: TStackTrace;
  {$IFDEF CPUX86}StackFrame,{$ENDIF}
  {$IFDEF CPUX64}StackPointer,{$ENDIF}
  TopOfStack: Pointer;
begin
  {$IFDEF CPUX86}
  StackFrame := GetStackFrame;
  {$ENDIF}
  {$IFDEF CPUX64}
  StackPointer := GetStackPointer;
  {$ENDIF}
  TopOfStack := GetTopOfStack;

  if not Assigned(Tracers[TracerLeaksRAW]) then
    Exit;

  FillChar(Trace, SizeOf(Trace), 0);
  Trace.ReturnAddresses := Pointer(APReturnAddresses);
  Trace.MaxDepth := AMaxDepth;
  Trace.SkipFrames := ASkipFrames;
  Trace.Count := -Integer(Trace.SkipFrames);
  Trace.FirstAddr := {$IFDEF CPUX86}StackFrame{$ENDIF}{$IFDEF CPUX64}StackPointer{$ENDIF};

  TraceStack(TracerLeaksRAW, nil,
    {$IFDEF CPUX86}StackFrame,{$ENDIF}
    {$IFDEF CPUX64}StackPointer,{$ENDIF}
    TopOfStack, nil, 0, @Trace, _AddToStack,
    False { enabling logging will cause Context to be logged, which means allocating memory - leading to infinite loop});
end;

procedure FastMM_GetStackTrace_EurekaLog(APReturnAddresses: PNativeUInt; AMaxDepth, ASkipFrames: Cardinal);
begin
  if ForceUseRAWTracing or (loRAWStackTrace in MemLeaksOptions) then
    FastMM_GetStackTrace_EurekaLog_RAW(APReturnAddresses, AMaxDepth, ASkipFrames + 1 { exclude FastMM_GetStackTrace_EurekaLog })
  else
    FastMM_GetStackTrace_EurekaLog_Frames(APReturnAddresses, AMaxDepth, ASkipFrames + 1 { exclude FastMM_GetStackTrace_EurekaLog });
end;

function  FastMM_ConvertStackTraceToText_EurekaLog(APReturnAddresses: PNativeUInt; AMaxDepth: Cardinal; APBuffer, APBufferEnd: PWideChar): PWideChar;

  function IsOKDebugInfo(const ALocation: TELLocationInfo): Boolean;
  begin
    // Which entries to show
    Result := ALocation.DebugDetail in [ddModule, ddUnit, ddProcedure, ddSourceCode];
  end;

var
  InternalBuffer: String;
  BufferSize: Integer;

  procedure Add(const AStr: String);
  begin
    InternalBuffer := InternalBuffer + AStr;
  end;

  function BufferToResult(const ABuffer: PWideChar): PWideChar;
  var
    LNumChars: Integer;
    WBuf: UnicodeString;
  begin
    WBuf := InternalBuffer;
    if ABuffer = nil then
    begin
      Result := AllocMem(Length(WBuf) + 1);
      if WBuf <> '' then
        Move(Pointer(WBuf)^, Pointer(Result)^, Length(WBuf) * SizeOf(WideChar));
    end
    else
    begin
      LNumChars := Length(WBuf);
      if LNumChars > BufferSize then
        LNumChars := BufferSize;
      Move(Pointer(WBuf)^, Pointer(ABuffer)^, LNumChars * SizeOf(WideChar));
      Result := ABuffer + LNumChars;
    end;
  end;

var
  ReturnAddresses: PPointerArray;
  I: Cardinal;
  Addr: Pointer;
  Location: TELLocationInfo;
begin
  ReturnAddresses := Pointer(APReturnAddresses);
  BufferSize := (PtrUInt(APBufferEnd) - PtrUInt(APBuffer)) div SizeOf(WideChar);
  for I := 0 to AMaxDepth - 1 do
  begin
    Addr := ReturnAddresses[I];
    if Addr = nil then
      Break;

    if not IsValidBlockAddr(Addr, 1) then
      Continue;

    if IsValidBlockAddr(PAddress(Addr) - 15, 15) then
      Addr := GetAddrByRetAddr(Addr);

    if not GetLocationInfo(Addr, Location) then
      Continue;

    if not IsOKDebugInfo(Location) then
      Continue;

    Add(sLineBreak + LocationToStr(Location,
      False,   // IncludeModuleName
      False,   // IncludeAddressOffset
      False,   // IncludeStartProcLineOffset
      False,   // IncludeVAddr
      True,    // IncludePointer
      True));  // IncludeLine
  end;

  Result := BufferToResult(APBuffer);
end;

initialization
  FastMM5.FastMM_GetStackTrace           := FastMM_GetStackTrace_EurekaLog;
  FastMM5.FastMM_ConvertStackTraceToText := FastMM_ConvertStackTraceToText_EurekaLog;
end.
