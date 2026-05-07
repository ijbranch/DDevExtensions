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

/// <summary>
/// Bridges FastMM5's leak-tracking stack-trace hooks to EurekaLog's tracer/debug-info
/// infrastructure. Replacing FastMM's <c>FastMM_GetStackTrace</c> and
/// <c>FastMM_ConvertStackTraceToText</c> in the unit's initialisation section makes
/// FastMM-reported leaks include EurekaLog-quality call stacks with unit/procedure/line
/// information.
/// </summary>

{$I ELDefines.inc}

interface

uses
  FastMM5,
  EMemLeaks,
  EResLeaks,
  ETypes;

var
  /// <summary>
  /// When True (the default), all FastMM stack traces are captured via raw-stack scanning;
  /// when False, frame-pointer-based tracing is used unless <c>loRAWStackTrace</c> is set
  /// in <c>MemLeaksOptions</c>. FastMM itself defaults to RAW tracing.
  /// </summary>
  ForceUseRAWTracing: Boolean = True; // FastMM defaults to RAW stack tracing

/// <summary>
/// FastMM5-compatible stack-trace capture entry point. Dispatches to the RAW or frame
/// tracer according to <see cref="ForceUseRAWTracing"/> and <c>MemLeaksOptions</c>.
/// </summary>
/// <param name="APReturnAddresses">Caller-supplied buffer that receives the captured return addresses.</param>
/// <param name="AMaxDepth">Maximum number of return addresses to capture.</param>
/// <param name="ASkipFrames">Number of leading frames to skip before recording.</param>
procedure FastMM_GetStackTrace_EurekaLog(APReturnAddresses: PNativeUInt; AMaxDepth, ASkipFrames: Cardinal);
/// <summary>
/// Frame-pointer-based stack-trace capture used when raw tracing is disabled. Walks the
/// stack via EurekaLog's <c>TracerLeaksFrame</c> tracer.
/// </summary>
/// <param name="APReturnAddresses">Buffer that receives the captured return addresses.</param>
/// <param name="AMaxDepth">Maximum number of return addresses to capture.</param>
/// <param name="ASkipFrames">Number of leading frames to skip.</param>
procedure FastMM_GetStackTrace_EurekaLog_Frames(APReturnAddresses: PNativeUInt; AMaxDepth, ASkipFrames: Cardinal);
/// <summary>
/// Raw-stack-scanning capture used when frame pointers are unavailable or RAW tracing is
/// requested. Walks the stack via EurekaLog's <c>TracerLeaksRAW</c> tracer.
/// </summary>
/// <param name="APReturnAddresses">Buffer that receives the captured return addresses.</param>
/// <param name="AMaxDepth">Maximum number of return addresses to capture.</param>
/// <param name="ASkipFrames">Number of leading frames to skip.</param>
procedure FastMM_GetStackTrace_EurekaLog_RAW(APReturnAddresses: PNativeUInt; AMaxDepth, ASkipFrames: Cardinal);
/// <summary>
/// Converts a previously captured FastMM5 stack trace into human-readable text with
/// pointer, line and source location information from EurekaLog's debug-info layer.
/// </summary>
/// <param name="APReturnAddresses">Buffer of captured return addresses.</param>
/// <param name="AMaxDepth">Number of valid entries in <paramref name="APReturnAddresses"/>.</param>
/// <param name="APBuffer">Optional caller-supplied destination buffer; pass <c>nil</c> to allocate one.</param>
/// <param name="APBufferEnd">One past the end of <paramref name="APBuffer"/>; ignored when <paramref name="APBuffer"/> is <c>nil</c>.</param>
/// <returns>Pointer to the next free position in the destination buffer, or to a freshly allocated buffer when <paramref name="APBuffer"/> is <c>nil</c>.</returns>
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
