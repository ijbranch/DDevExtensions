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
  [ TestFixture ]
  TTestDelphiPreproc = class
  public
    /// <summary>
    /// Proves <c>$IFDEF</c> keeps only the first branch when the symbol is defined and
    /// only the <c>$ELSE</c> branch when it is not; the analysers would otherwise see
    /// code the compiler never compiles.
    /// </summary>
    [ Test ]
    procedure TestIfdef;
    /// <summary>Proves <c>$IFNDEF</c> selects the branches the opposite way round to <c>$IFDEF</c>.</summary>
    [ Test ]
    procedure TestIfndef;
    /// <summary>
    /// Proves a nested <c>$IFDEF</c> with an undefined symbol is skipped inside a live
    /// outer block, and that a dead outer block skips everything it contains.
    /// </summary>
    [ Test ]
    procedure TestNestedIfdef;
    /// <summary>
    /// Proves an in-source <c>$DEFINE</c> takes effect for later conditions, a following
    /// <c>$UNDEF</c> reverses it, and the <c>Define</c> / <c>Undefine</c> API is reflected
    /// in the <c>Defines</c> table.
    /// </summary>
    [ Test ]
    procedure TestDefineUndef;
    /// <summary>
    /// Proves <c>{$IF ...}</c> may be closed by <c>{$ENDIF}</c> (legal since XE4 and common in
    /// our code): it used to raise "$IFEND expected", which aborted the File Selector's parse.
    /// </summary>
    [ Test ]
    procedure TestIfClosedByEndif;
    /// <summary>
    /// Proves the predefined-symbol table matches the target platform: Win64 gets WIN64, CPUX64 and
    /// MSWINDOWS but not WIN32; Win32 gets WIN32 and CPUX86 but not WIN64.
    /// </summary>
    [ Test ]
    procedure TestPredefinedSymbols;
    /// <summary>
    /// Proves <c>CompareFileName</c> tells different file names apart; it compared two
    /// uninitialised locals and so called every pair of names equal.
    /// </summary>
    [ Test ]
    procedure TestCompareFileName;
    /// <summary>
    /// Proves exactly one branch of an <c>$IF</c> / <c>$ELSEIF</c> / <c>$ELSE</c> chain survives: a
    /// taken <c>$IF</c> skips the <c>$ELSEIF</c> branch (it used to keep it), and a false
    /// <c>$ELSEIF</c> after a false <c>$IF</c> is skipped (it used to be taken without being evaluated).
    /// </summary>
    [ Test ]
    procedure TestElseIfTakesOneBranch;
    /// <summary>
    /// Proves both branches of <c>$IFOPT</c> survive: option states are not tracked, so neither
    /// branch can be dropped (it used to pick one by whether the option letter named a directive).
    /// </summary>
    [ Test ]
    procedure TestIfoptKeepsBothBranches;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.StrUtils, DelphiLexer, DelphiParserContainers, DelphiPreproc;

/// <summary>Preprocesses ASource and returns the identifiers that survive, space-separated.</summary>
/// <param name="ASource">Source text containing conditional directives.</param>
/// <param name="ADefineName">Symbol to define before preprocessing; empty for none.</param>
/// <returns>The surviving <c>tkIdent</c> token values in source order, joined with a space.</returns>
function SurvivingIdents( const ASource: string; const ADefineName: string ): string;
begin
  Result            := '';

  var oPreprocessor := TDelphiPreprocessor.Create( 'test.pas', UTF8String( ASource ) );
  try
    if ADefineName <> '' then oPreprocessor.Define( ADefineName );

    var iGuard      := 0;
    repeat
    var
      oToken := oPreprocessor.GetToken( False );
      if oToken = nil then Break;

      if oToken.Kind = tkIdent then
      begin
        if Result <> '' then
          Result    := Result + ' ';
        Result      := Result + oToken.Value;
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
  var sSource       :=
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
  var sSource       :=
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
  var sSource       :=
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

procedure TTestDelphiPreproc.TestIfClosedByEndif;
begin
  var sSource       :=
    '{$IF Defined( FOO )}'#13#10 +
    '  Alpha'#13#10 +
    '{$ELSE}'#13#10 +
    '  Beta'#13#10 +
    '{$ENDIF}'#13#10 +
    'After'#13#10;
  Assert.AreEqual( 'Alpha After', SurvivingIdents( sSource, 'FOO' ), '$IF closed by $ENDIF, FOO defined' );
  Assert.AreEqual( 'Beta After', SurvivingIdents( sSource, '' ), '$IF closed by $ENDIF, FOO undefined' );
end;

procedure TTestDelphiPreproc.TestPredefinedSymbols;
begin
  var aWin64        := PredefinedSymbols( 'Win64' );
  Assert.IsTrue( MatchText( 'WIN64', aWin64 ), 'Win64 defines WIN64' );
  Assert.IsTrue( MatchText( 'CPUX64', aWin64 ), 'Win64 defines CPUX64' );
  Assert.IsTrue( MatchText( 'MSWINDOWS', aWin64 ), 'Win64 defines MSWINDOWS' );
  Assert.IsTrue( MatchText( 'UNICODE', aWin64 ), 'Win64 defines UNICODE' );
  Assert.IsTrue( MatchText( 'VER' + IntToStr( Trunc( CompilerVersion * 10 ) ), aWin64 ), 'the compiler''s VERnnn is defined' );
  Assert.IsFalse( MatchText( 'WIN32', aWin64 ), 'Win64 does not define WIN32' );

  var aWin32        := PredefinedSymbols( 'Win32' );
  Assert.IsTrue( MatchText( 'WIN32', aWin32 ), 'Win32 defines WIN32' );
  Assert.IsTrue( MatchText( 'CPUX86', aWin32 ), 'Win32 defines CPUX86' );
  Assert.IsFalse( MatchText( 'WIN64', aWin32 ), 'Win32 does not define WIN64' );
end;

procedure TTestDelphiPreproc.TestCompareFileName;
begin
  Assert.IsTrue( CompareFileName( 'C:\a\Unit1.pas', 'c:\A\UNIT1.PAS' ), 'same name, different case' );
  Assert.IsFalse( CompareFileName( 'C:\a\Unit1.pas', 'C:\a\Unit2.pas' ), 'different names' );
end;

procedure TTestDelphiPreproc.TestElseIfTakesOneBranch;
begin
  var sChain        :=
    '{$IF Defined( %s )}A' +
    '{$ELSEIF Defined( %s )}B' +
    '{$ELSE}C' +
    '{$ENDIF}D';
  Assert.AreEqual( 'A D', SurvivingIdents( Format( sChain, [ 'FOO', 'FOO' ] ), 'FOO' ), '$IF taken: $ELSEIF and $ELSE skipped' );
  Assert.AreEqual( 'B D', SurvivingIdents( Format( sChain, [ 'BAR', 'FOO' ] ), 'FOO' ), '$IF false, $ELSEIF true' );
  Assert.AreEqual( 'C D', SurvivingIdents( Format( sChain, [ 'BAR', 'BAZ' ] ), 'FOO' ), 'both false: the $ELSE branch' );
end;

procedure TTestDelphiPreproc.TestIfoptKeepsBothBranches;
begin
  Assert.AreEqual( 'A B C', SurvivingIdents( '{$IFOPT R+}A{$ELSE}B{$ENDIF}C', '' ), '$IFOPT R+ keeps both branches' );
  Assert.AreEqual( 'A B C', SurvivingIdents( '{$IFOPT I+}A{$ELSE}B{$ENDIF}C', '' ), '$IFOPT I+ keeps both branches' );
  Assert.AreEqual( 'A D', SurvivingIdents( '{$IFDEF NOPE}{$IFOPT R+}X{$ELSE}Y{$ENDIF}{$ELSE}A{$ENDIF}D', '' ),
    'an $IFOPT inside a skipped block stays skipped' );
end;

initialization

  TDUnitX.RegisterTestFixture( TTestDelphiPreproc );

end.

