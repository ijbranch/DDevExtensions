unit TestHookingDUnitX;

/// <summary>
/// DUnitX test fixture for <c>Hooking</c>: the instruction-length decoder that sizes Win32
/// trampolines, the redirection ref-count, and the full-replacement hook used by the three DFM
/// cleaners on both IDEs.  The hook tests patch functions inside this test executable.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising <c>Hooking</c>.</summary>
  [ TestFixture ]
  TTestHooking = class
  public
    /// <summary>
    /// Proves instructions with a SIB byte whose base is not EBP are measured in full: 2, 3 or
    /// 6 bytes of ModRM/SIB/displacement by Mod.  The decoder returned 1 for all three, so a
    /// trampoline built over such a prologue split an instruction.
    /// </summary>
    [ Test ]
    procedure TestModRmSibLengths;
    /// <summary>Proves the SIB forms the decoder already handled (base EBP) keep their lengths.</summary>
    [ Test ]
    procedure TestModRmSibEbpBaseUnchanged;
    /// <summary>
    /// Proves CodeRestore on a record that was never redirected leaves Count at 0.  It used to
    /// drop to -1, after which the next CodeRedirect only incremented it and installed nothing.
    /// </summary>
    [ Test ]
    procedure TestCodeRestoreWithoutRedirectKeepsCountZero;
    /// <summary>Proves InstallFullReplaceHook redirects the target and RemoveFullReplaceHook restores it.</summary>
    [ Test ]
    procedure TestFullReplaceHookInstallAndRemove;
    /// <summary>
    /// Proves a second InstallFullReplaceHook on a hook that is still installed is ignored, so
    /// one RemoveFullReplaceHook restores the original.  On Win64 the second install used to
    /// capture the jump itself as the "original" bytes, so the jump survived the removal.
    /// </summary>
    [ Test ]
    procedure TestFullReplaceHookDoubleInstall;
    /// <summary>
    /// Proves the bytes the full-replacement hook writes are exactly the documented patch - on
    /// Win64 the 14-byte <c>FF 25 00000000 &lt;abs64&gt;</c>, on Win32 the 5-byte <c>E9 rel32</c> - and
    /// that removal restores the original bytes verbatim.  Guards the self-loop write sequence,
    /// which changes only the order of the writes, never the result.
    /// </summary>
    [ Test ]
    procedure TestFullReplaceHookBytes;
  end;

implementation

uses
  System.SysUtils, Hooking;

{$O-} // keep the hook targets as real, separate functions of comfortable length

/// <summary>Hook target: returns 1 + A * 3 through a short loop, so its body is well over 14 bytes.</summary>
/// <param name="A">Input value.</param>
/// <returns>1 + A * 3.</returns>
function TargetFunction( A: Integer ): Integer;
begin
  Result            := 1;
  for var iIndex: Integer := 1 to 3 do
    Result          := Result + A;
end;

/// <summary>Replacement for TargetFunction: returns -A, so a redirected call is obvious.</summary>
/// <param name="A">Input value.</param>
/// <returns>-A.</returns>
function ReplacementFunction( A: Integer ): Integer;
begin
  Result            := -A;
end;

{$O+}

type
  /// <summary>Signature of TargetFunction, called through a variable so the call is not inlined.</summary>
  TIntFunction = function( A: Integer ): Integer;

/// <summary>Calls TargetFunction through a procedure variable.</summary>
/// <param name="A">Input value.</param>
/// <returns>Whatever the (possibly redirected) target returns.</returns>
function CallTarget( A: Integer ): Integer;
begin
  var fTarget: TIntFunction := TargetFunction;
  Result            := fTarget( A );
end;

/// <summary>Returns GetStartCodeSize( Bytes, 1 ): the length of the first instruction in Bytes.</summary>
/// <param name="Bytes">Machine code, padded with RET.</param>
/// <returns>Length of the first instruction.</returns>
function FirstInstructionLength( const Bytes: array of Byte ): Integer;
begin
  var aCode: TBytes;
  SetLength( aCode, Length( Bytes ) + 16 );
  FillChar( aCode[ 0 ], Length( aCode ), $C3 );
  Move( Bytes[ 0 ], aCode[ 0 ], Length( Bytes ) );
  Result            := GetStartCodeSize( @aCode[ 0 ], 1 );
end;

procedure TTestHooking.TestModRmSibLengths;
begin
  Assert.AreEqual( 4, FirstInstructionLength( [ $0F, $B6, $04, $24 ] ), 'movzx eax, byte ptr [esp]' );
  Assert.AreEqual( 5, FirstInstructionLength( [ $0F, $B6, $44, $24, $04 ] ), 'movzx eax, byte ptr [esp+4]' );
  Assert.AreEqual( 8, FirstInstructionLength( [ $0F, $B7, $84, $24, $10, $00, $00, $00 ] ), 'movzx eax, word ptr [esp+$10]' );
end;

procedure TTestHooking.TestModRmSibEbpBaseUnchanged;
begin
  Assert.AreEqual( 8, FirstInstructionLength( [ $0F, $B6, $04, $25, $00, $10, $00, $00 ] ), 'movzx eax, byte ptr [$1000] via SIB' );
  Assert.AreEqual( 4, FirstInstructionLength( [ $0F, $B6, $45, $08 ] ), 'movzx eax, byte ptr [ebp+8] (no SIB)' );
end;

procedure TTestHooking.TestCodeRestoreWithoutRedirectKeepsCountZero;
begin
  var rData: TRedirectCode;
  FillChar( rData, SizeOf( rData ), 0 );
  CodeRestore( rData );
  Assert.AreEqual( 0, rData.Count );
end;

procedure TTestHooking.TestFullReplaceHookInstallAndRemove;
begin
  Assert.AreEqual( 7, CallTarget( 2 ), 'Before the hook' );

  var rHook: TFullReplaceHook;
  FillChar( rHook, SizeOf( rHook ), 0 );
  InstallFullReplaceHook( @TargetFunction, @ReplacementFunction, rHook );
  try
    Assert.AreEqual( -2, CallTarget( 2 ), 'While hooked' );
  finally
    RemoveFullReplaceHook( rHook );
  end;
  Assert.AreEqual( 7, CallTarget( 2 ), 'After removal' );
end;

procedure TTestHooking.TestFullReplaceHookDoubleInstall;
begin
  var rHook: TFullReplaceHook;
  FillChar( rHook, SizeOf( rHook ), 0 );
  InstallFullReplaceHook( @TargetFunction, @ReplacementFunction, rHook );
  InstallFullReplaceHook( @TargetFunction, @ReplacementFunction, rHook );
  try
    Assert.AreEqual( -2, CallTarget( 2 ), 'While hooked' );
  finally
    RemoveFullReplaceHook( rHook );
  end;
  Assert.AreEqual( 7, CallTarget( 2 ), 'One removal must restore the original after a repeated install' );
end;

procedure TTestHooking.TestFullReplaceHookBytes;
const
{$IFDEF CPUX64}
  cPatchSize        = 14;
{$ELSE}
  cPatchSize        = 5;
{$ENDIF CPUX64}
begin
  var aOriginal: array[ 0..cPatchSize - 1 ] of Byte;
  Move( PByte( @TargetFunction )^, aOriginal[ 0 ], cPatchSize );

  var aExpected: array[ 0..cPatchSize - 1 ] of Byte;
{$IFDEF CPUX64}
  aExpected[ 0 ]    := $FF;
  aExpected[ 1 ]    := $25;
  PInteger( @aExpected[ 2 ] )^ := 0;
  PPointer( @aExpected[ 6 ] )^ := @ReplacementFunction;
{$ELSE}
  aExpected[ 0 ]    := $E9;
  PInteger( @aExpected[ 1 ] )^ := PByte( @ReplacementFunction ) - ( PByte( @TargetFunction ) + 5 );
{$ENDIF CPUX64}

  var rHook: TFullReplaceHook;
  FillChar( rHook, SizeOf( rHook ), 0 );
  InstallFullReplaceHook( @TargetFunction, @ReplacementFunction, rHook );
  try
    Assert.IsTrue( CompareMem( @TargetFunction, @aExpected[ 0 ], cPatchSize ), 'Installed bytes differ from the documented patch' );
  finally
    RemoveFullReplaceHook( rHook );
  end;
  Assert.IsTrue( CompareMem( @TargetFunction, @aOriginal[ 0 ], cPatchSize ), 'Removal did not restore the original bytes' );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestHooking );

end.

