unit TestDelphiDesignerParserDUnitX;

/// <summary>
/// DUnitX fixture for <c>DelphiDesignerParser</c>'s <c>ParseUsesOnly</c>, which the File Selector's
/// "Use Unit" relies on before it inserts a uses entry into the editor buffer.  A parse that stops
/// early leaves the uses lists partial; Use Unit then cannot tell a unit is already used.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture for the designer parser's uses-clause parse.</summary>
  [TestFixture]
  TTestDelphiDesignerParser = class
  public
    /// <summary>
    /// Proves a unit using <c>{$IF ...}</c> closed by <c>{$ENDIF}</c> - inside the interface uses
    /// clause and again before <c>implementation</c> - parses both uses clauses completely and
    /// reports no parse error.  The preprocessor used to raise "$IFEND expected", which the parser
    /// swallowed, leaving the lists partial.
    /// </summary>
    [Test]
    procedure TestIfEndifDoesNotTruncateUses;
    /// <summary>
    /// Proves a genuine preprocessor error (an <c>{$ENDIF}</c> with no open block) is reported
    /// through <c>ParseError</c> instead of passing silently as a short parse.
    /// </summary>
    [Test]
    procedure TestPreprocessorErrorSetsParseError;
    /// <summary>
    /// Proves an include file that exists but cannot be opened (held exclusively by another handle)
    /// is reported through <c>ParseError</c> instead of raising out of <c>ParseUsesOnly</c>.
    /// </summary>
    [Test]
    procedure TestLockedIncludeSetsParseError;
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, DelphiDesignerParser;

const
  CRLF = #13#10;

{ TTestDelphiDesignerParser }

procedure TTestDelphiDesignerParser.TestIfEndifDoesNotTruncateUses;
begin
  var sSource :=
    'unit Sample;' + CRLF +
    'interface' + CRLF +
    'uses' + CRLF +
    '  System.SysUtils,' + CRLF +
    '  {$IF CompilerVersion >= 20}' + CRLF +
    '  System.Classes,' + CRLF +
    '  {$ENDIF}' + CRLF +
    '  System.Types;' + CRLF +
    '{$IF Defined( MSWINDOWS )}' + CRLF +
    'const X = 1;' + CRLF +
    '{$ENDIF}' + CRLF +
    'implementation' + CRLF +
    'uses System.Math;' + CRLF +
    'end.';

  var oParser := TDesignerParser.Create( 'C:\p\Sample.pas', UTF8String( sSource ) );
  try
    oParser.ParseUsesOnly;
    Assert.IsFalse( oParser.ParseError, 'no parse error' );
    Assert.AreEqual<Integer>( 3, oParser.InterfaceUses.Count, 'all three interface uses entries' );
    Assert.AreEqual<Integer>( 1, oParser.ImplUses.Count, 'the implementation uses entry' );
    Assert.IsNotNull( oParser.ImplUses.FindUses( 'System.Math' ), 'System.Math is in the implementation uses' );
  finally
    oParser.Free;
  end;
end;

procedure TTestDelphiDesignerParser.TestPreprocessorErrorSetsParseError;
begin
  var sSource :=
    'unit Broken;' + CRLF +
    'interface' + CRLF +
    'uses System.SysUtils;' + CRLF +
    '{$ENDIF}' + CRLF +
    'implementation' + CRLF +
    'end.';

  var oParser := TDesignerParser.Create( 'C:\p\Broken.pas', UTF8String( sSource ) );
  try
    oParser.ParseUsesOnly;
    Assert.IsTrue( oParser.ParseError, 'the stray $ENDIF is reported as a parse error' );
  finally
    oParser.Free;
  end;
end;

procedure TTestDelphiDesignerParser.TestLockedIncludeSetsParseError;
begin
  var sDir := IncludeTrailingPathDelimiter( TPath.GetTempPath ) + 'DDevExtParserTest' + IntToStr( GetCurrentProcessId );
  ForceDirectories( sDir );
  try
    TFile.WriteAllText( sDir + '\Locked.inc', '{ nothing }' );

    var sSource :=
      'unit Sample;' + CRLF +
      'interface' + CRLF +
      '{$I Locked.inc}' + CRLF +
      'uses System.SysUtils;' + CRLF +
      'implementation' + CRLF +
      'end.';

    var oLock := TFileStream.Create( sDir + '\Locked.inc', fmOpenRead or fmShareExclusive );
    try
      var oParser := TDesignerParser.Create( sDir + '\Sample.pas', UTF8String( sSource ) );
      try
        oParser.ParseUsesOnly;   // an EFOpenError escaping here errors the test
        Assert.IsTrue( oParser.ParseError, 'the unreadable include is reported as a parse error' );
      finally
        oParser.Free;
      end;
    finally
      oLock.Free;
    end;
  finally
    TDirectory.Delete( sDir, True );
  end;
end;

initialization
  TDUnitX.RegisterTestFixture( TTestDelphiDesignerParser );

end.
