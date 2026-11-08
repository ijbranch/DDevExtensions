unit TestVirtTreeHandlerDUnitX;

/// <summary>
/// DUnitX tests for <c>VirtTreeHandler.ResolvePropAccessorCode</c>: decoding a published property's
/// <c>SetProc</c> into a callable code address on Win32 and Win64.
/// </summary>
/// <remarks>
/// The IDE's Virtual Tree is driven through these decoded accessors (Structure View search assigns
/// <c>FocusedNode</c> through one), so a wrong decode calls a garbage address inside the IDE.
/// </remarks>

interface

uses
  System.Classes, DUnitX.TestFramework;

type
  /// <summary>Probe class: one property per accessor kind (static method, virtual method, field).</summary>
  TAccessorProbe = class(TPersistent)
  private
    /// <summary>Backing field of <see cref="StaticValue"/>.</summary>
    FStaticValue: Integer;
    /// <summary>Backing field of <see cref="VirtualValue"/>.</summary>
    FVirtualValue: Integer;
    /// <summary>Backing field of <see cref="FieldValue"/>, written directly by the property.</summary>
    FFieldValue: Integer;
    /// <summary>Static setter of <see cref="StaticValue"/>.</summary>
    /// <param name="Value">New value.</param>
    procedure SetStaticValue( Value: Integer );
  protected
    /// <summary>Virtual setter of <see cref="VirtualValue"/>, overridden by <see cref="TAccessorProbeChild"/>.</summary>
    /// <param name="Value">New value.</param>
    procedure SetVirtualValue( Value: Integer ); virtual;
  published
    /// <summary>Property with a static-method setter.</summary>
    property StaticValue: Integer read FStaticValue write SetStaticValue;
    /// <summary>Property with a virtual-method setter.</summary>
    property VirtualValue: Integer read FVirtualValue write SetVirtualValue;
    /// <summary>Property whose setter is the field itself.</summary>
    property FieldValue: Integer read FFieldValue write FFieldValue;
  end;

  /// <summary>Descendant that overrides the virtual setter, so a correct decode must find the override.</summary>
  TAccessorProbeChild = class(TAccessorProbe)
  protected
    /// <summary>Override of the virtual setter.</summary>
    /// <param name="Value">New value.</param>
    procedure SetVirtualValue( Value: Integer ); override;
  end;

  /// <summary>Fixture for <c>ResolvePropAccessorCode</c>.</summary>
  [TestFixture]
  TTestVirtTreeHandler = class
  public
    /// <summary>A static setter decodes to that method's own code address.</summary>
    [Test]
    procedure TestStaticSetterDecodesToMethod;
    /// <summary>
    /// A virtual setter decodes through the instance's VMT to the descendant's override.  Proves the
    /// pointer-width slot mask: with the Win32 mask the Win64 slot marker was read as a code address.
    /// </summary>
    [Test]
    procedure TestVirtualSetterDecodesToOverride;
    /// <summary>A field accessor has no code to call, so it decodes to nil instead of a field offset posing as code.</summary>
    [Test]
    procedure TestFieldAccessorDecodesToNil;
    {$IFDEF CPUX64}
    /// <summary>
    /// Win64: a static code address whose bits 24..31 happen to be $FE is still static.  The Win32 mask
    /// mistook it for a virtual slot and read a garbage address out of the VMT.
    /// </summary>
    [Test]
    procedure TestWin64StaticAddressWithFEByteStaysStatic;
    {$ENDIF CPUX64}
    /// <summary>A nil instance or nil accessor decodes to nil.</summary>
    [Test]
    procedure TestNilInputsDecodeToNil;
  end;

implementation

uses
  System.TypInfo, VirtTreeHandler;

{ TAccessorProbe }

procedure TAccessorProbe.SetStaticValue( Value: Integer );
begin
  FStaticValue := Value;
end;

procedure TAccessorProbe.SetVirtualValue( Value: Integer );
begin
  FVirtualValue := Value;
end;

{ TAccessorProbeChild }

procedure TAccessorProbeChild.SetVirtualValue( Value: Integer );
begin
  inherited SetVirtualValue( Value + 1 );
end;

{ TTestVirtTreeHandler }

procedure TTestVirtTreeHandler.TestStaticSetterDecodesToMethod;
begin
  var Probe := TAccessorProbeChild.Create;
  try
    var Info := GetPropInfo( Probe, 'StaticValue' );
    Assert.AreEqual( Pointer( @TAccessorProbe.SetStaticValue ), ResolvePropAccessorCode( Probe, Info.SetProc ) );
  finally
    Probe.Free;
  end;
end;

procedure TTestVirtTreeHandler.TestVirtualSetterDecodesToOverride;
begin
  var Probe := TAccessorProbeChild.Create;
  try
    var Info := GetPropInfo( Probe, 'VirtualValue' );
    Assert.AreEqual( Pointer( @TAccessorProbeChild.SetVirtualValue ), ResolvePropAccessorCode( Probe, Info.SetProc ) );
  finally
    Probe.Free;
  end;
end;

procedure TTestVirtTreeHandler.TestFieldAccessorDecodesToNil;
begin
  var Probe := TAccessorProbeChild.Create;
  try
    var Info := GetPropInfo( Probe, 'FieldValue' );
    Assert.IsNull( ResolvePropAccessorCode( Probe, Info.SetProc ) );
  finally
    Probe.Free;
  end;
end;

{$IFDEF CPUX64}
procedure TTestVirtTreeHandler.TestWin64StaticAddressWithFEByteStaysStatic;
const
  SyntheticCode = $00007FFF12FE3456; // bits 24..31 = $12; bits 16..23 = $FE
  SyntheticCodeFE = $00007FFFFE123456; // bits 24..31 = $FE
begin
  var Probe := TAccessorProbeChild.Create;
  try
    Assert.AreEqual( Pointer( SyntheticCode ), ResolvePropAccessorCode( Probe, Pointer( SyntheticCode ) ) );
    Assert.AreEqual( Pointer( SyntheticCodeFE ), ResolvePropAccessorCode( Probe, Pointer( SyntheticCodeFE ) ) );
  finally
    Probe.Free;
  end;
end;
{$ENDIF CPUX64}

procedure TTestVirtTreeHandler.TestNilInputsDecodeToNil;
begin
  var Probe := TAccessorProbeChild.Create;
  try
    var Info := GetPropInfo( Probe, 'StaticValue' );
    Assert.IsNull( ResolvePropAccessorCode( nil, Info.SetProc ) );
    Assert.IsNull( ResolvePropAccessorCode( Probe, nil ) );
  finally
    Probe.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestVirtTreeHandler );

end.
