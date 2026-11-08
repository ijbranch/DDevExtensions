unit TestImportHookingDUnitX;

/// <summary>
/// DUnitX test fixture for <c>ImportHooking</c>, which DSU Features uses to redirect coreide's
/// import of rtl's LoadPackage in both IDEs.  Hooks an import of this test executable itself
/// ( kernel32's GetTickCount ) and proves the call is redirected and then restored, on Win32 and
/// Win64.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising <c>TJclPeMapImgHooks</c> against this executable's import table.</summary>
  [TestFixture]
  TTestImportHooking = class
  public
    /// <summary>
    /// Proves HookImport redirects this executable's GetTickCount import and Unhook restores it.
    /// On Win64 the import table was walked as 32-bit entries and VirtualProtectEx was given a
    /// truncated process handle, so nothing was hooked and the failure was silent.
    /// </summary>
    [Test]
    procedure TestHookAndUnhookOwnImport;
    /// <summary>Proves freeing the hook list restores every import it still holds hooked.</summary>
    [Test]
    procedure TestFreeingListRestoresImport;
    /// <summary>Proves ReplaceImport reports failure ( False ) when the function is not imported from the named module.</summary>
    [Test]
    procedure TestReplaceImportReportsMissingImport;
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, ImportHooking;

const
  /// <summary>Value the replacement returns, so a redirected call is unmistakable.</summary>
  cFakeTicks = 424242;

/// <summary>Replacement for GetTickCount: returns cFakeTicks.</summary>
/// <returns>cFakeTicks.</returns>
function FakeGetTickCount: DWORD; stdcall;
begin
  Result := cFakeTicks;
end;

/// <summary>Calls GetTickCount through this executable's import table.</summary>
/// <returns>What the ( possibly redirected ) import returns.</returns>
function CallGetTickCount: DWORD;
begin
  Result := GetTickCount;
end;

procedure TTestImportHooking.TestHookAndUnhookOwnImport;
begin
  Assert.AreNotEqual( DWORD( cFakeTicks ), CallGetTickCount, 'Before the hook' );

  var oHooks := TJclPeMapImgHooks.Create;
  try
    Assert.IsTrue( oHooks.HookImport( Pointer( HInstance ), kernel32, 'GetTickCount', @FakeGetTickCount ), 'HookImport failed' );
    Assert.AreEqual( DWORD( cFakeTicks ), CallGetTickCount, 'While hooked' );

    Assert.IsTrue( oHooks[0].Unhook, 'Unhook failed' );
    Assert.AreNotEqual( DWORD( cFakeTicks ), CallGetTickCount, 'After Unhook' );
    Assert.AreEqual( 0, oHooks.Count );
  finally
    oHooks.Free;
  end;
end;

procedure TTestImportHooking.TestFreeingListRestoresImport;
begin
  var oHooks := TJclPeMapImgHooks.Create;
  try
    Assert.IsTrue( oHooks.HookImport( Pointer( HInstance ), kernel32, 'GetTickCount', @FakeGetTickCount ), 'HookImport failed' );
    Assert.AreEqual( DWORD( cFakeTicks ), CallGetTickCount, 'While hooked' );
  finally
    oHooks.Free;
  end;
  Assert.AreNotEqual( DWORD( cFakeTicks ), CallGetTickCount, 'After freeing the list' );
end;

procedure TTestImportHooking.TestReplaceImportReportsMissingImport;
begin
  // GetTickCount is imported from kernel32, never from user32.
  var pOriginal := GetProcAddress( GetModuleHandle( kernel32 ), 'GetTickCount' );
  Assert.IsFalse( TJclPeMapImgHooks.ReplaceImport( Pointer( HInstance ), user32, pOriginal, @FakeGetTickCount ) );
  Assert.AreNotEqual( DWORD( cFakeTicks ), CallGetTickCount );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestImportHooking );

end.
