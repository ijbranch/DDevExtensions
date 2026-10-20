unit TestDelphiPreprocDUnitX;

/// <summary>
/// DUnitX test fixture for <c>DelphiPreproc</c>, the conditional-compilation
/// preprocessor layered on the lexer.  Drives <c>$IFDEF</c>, <c>$IFNDEF</c>,
/// <c>$ELSE</c>, <c>$ENDIF</c>, nested blocks and in-source <c>$DEFINE</c> /
/// <c>$UNDEF</c>, plus the <c>Define</c> / <c>Undefine</c> API, asserting which
/// branch's tokens survive.
/// </summary>
/// <remarks>
/// Converted from the retired console harness <c>TestDelphiPreproc.pas</c>.  No
/// include-file or $IF resolver events are needed: every case uses plain symbols.
/// </remarks>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising the preprocessor's conditional branch selection.</summary>
  [TestFixture]
  TTestDelphiPreproc = class
  public
    /// <summary>
    /// Proves <c>$IFDEF</c> keeps only the first branch when the symbol is defined and
    /// only the <c>$ELSE</c> branch when it is not; the analysers would otherwise see
    /// code the compiler never compiles.
    /// </summary>
    [Test]
    procedure TestIfdef;
    /// <summary>Proves <c>$IFNDEF</c> selects the branches the opposite way round to <c>$IFDEF</c>.</summary>
    [Test]
    procedure TestIfndef;
    /// <summary>
    /// Proves a nested <c>$IFDEF</c> with an undefined symbol is skipped inside a live
    /// outer block, and that a dead outer block skips everything it contains.
    /// </summary>
    [Test]
    procedure TestNestedIfdef;
    /// <summary>
    /// Proves an in-source <c>$DEFINE</c> takes effect for later conditions, a following
    /// <c>$UNDEF</c> reverses it, and the <c>Define</c> / <c>Undefine</c> API is reflected
    /// in the <c>Defines</c> table.
    /// </summary>
    [Test]
    procedure TestDefineUndef;
  end;

implementation

uses
  System.SysUtils, System.Classes, DelphiLexer, DelphiParserContainers, DelphiPreproc;

/// <summary>Preprocesses ASource and returns the identifiers that survive, space-separated.</summary>
/// <param name="ASource">Source text containing conditional directives.</param>
/// <param name="ADefineName">Symbol to define before preprocessing; empty for none.</param>
/// <returns>The surviving <c>tkIdent</c> token values in source order, joined with a space.</returns>
function SurvivingIdents( const ASource: string; const ADefineName: string ): string;
begin
  Result := '';

  var oPreprocessor := TDelphiPreprocessor.Create( 'test.pas', UTF8String( ASource ) );
  try
    if ADefineName <> '' then oPreprocessor.Define( ADefineName );

    var iGuard := 0;
    repeat
      var oToken := oPreprocessor.GetToken( False );
      if oToken = nil then Break;

      if oToken.Kind = tkIdent then
      begin
        if Result <> '' then
          Result := Result + ' ';
        Result := Result + oToken.Value;
      end;

      Inc( iGuard );
    until iGuard > 10000;
  finally
    oPreprocessor.Free;
  end;
end;

{ TTestDelphiPreproc }

procedure TTestDelphiPreproc.TestIfdef;
begin
  var sSource :=
    '{$IFDEF FOO}'#13#10 +
    '  Alpha;'#13#10 +
    '{$ELSE}'#13#10 +
    '  Beta;'#13#10 +
    '{$ENDIF}'#13#10;
  Assert.AreEqual( 'Alpha', SurvivingIdents( sSource, 'FOO' ), 'FOO defined selects the Alpha branch' );
  Assert.AreEqual( 'Beta', SurvivingIdents( sSource, '' ), 'FOO undefined selects the Beta branch' );
end;

procedure TTestDelphiPreproc.TestIfndef;
begin
  var sSource :=
    '{$IFNDEF BAR}'#13#10 +
    '  NoBar;'#13#10 +
    '{$ELSE}'#13#10 +
    '  HasBar;'#13#10 +
    '{$ENDIF}'#13#10;
  Assert.AreEqual( 'NoBar', SurvivingIdents( sSource, '' ), 'BAR undefined selects the NoBar branch' );
  Assert.AreEqual( 'HasBar', SurvivingIdents( sSource, 'BAR' ), 'BAR defined selects the HasBar branch' );
end;

procedure TTestDelphiPreproc.TestNestedIfdef;
begin
  var sSource :=
    '{$IFDEF OUTER}'#13#10 +
    '  Outer;'#13#10 +
    '  {$IFDEF INNER}'#13#10 +
    '    Inner;'#13#10 +
    '  {$ENDIF}'#13#10 +
    '{$ENDIF}'#13#10;
  Assert.AreEqual( 'Outer', SurvivingIdents( sSource, 'OUTER' ), 'outer-only define keeps Outer and skips Inner' );
  Assert.AreEqual( '', SurvivingIdents( sSource, '' ), 'outer undefined skips the whole block' );
end;

procedure TTestDelphiPreproc.TestDefineUndef;
begin
  Assert.AreEqual( 'Yes', SurvivingIdents( '{$DEFINE LOCALDEF}{$IFDEF LOCALDEF}Yes{$ENDIF}', '' ),
    'in-source $DEFINE enables the block' );
  Assert.AreEqual( 'No', SurvivingIdents( '{$DEFINE D}{$UNDEF D}{$IFDEF D}Yes{$ELSE}No{$ENDIF}', '' ),
    '$UNDEF after $DEFINE selects the else branch' );

  var oPreprocessor := TDelphiPreprocessor.Create( 'test.pas', UTF8String( '' ) );
  try
    oPreprocessor.Define( 'XYZ' );
    Assert.IsTrue( oPreprocessor.Defines.Contains( 'XYZ' ), 'Define( XYZ ) is reflected in Defines' );

    oPreprocessor.Undefine( 'XYZ' );
    Assert.IsFalse( oPreprocessor.Defines.Contains( 'XYZ' ), 'Undefine( XYZ ) removes it from Defines' );
  finally
    oPreprocessor.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestDelphiPreproc );

end.
