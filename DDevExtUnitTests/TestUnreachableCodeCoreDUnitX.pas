unit TestUnreachableCodeCoreDUnitX;

/// <summary>
/// DUnitX fixture for <c>UnreachableCodeCore</c>, the scanner behind the Unreachable Code Detector.
/// A false report invites the user to delete live code, so most cases are reachable code that must
/// NOT be reported; the rest prove genuinely unreachable code is still found where the scanner
/// used to lose its place.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture for the Unreachable Code Detector's scanner.</summary>
  [ TestFixture ]
  TTestUnreachableCodeCore = class
  public
    /// <summary>Proves a terminator in an else branch (<c>if A then X else Exit;</c>) does not make the next statement unreachable.</summary>
    [ Test ]
    procedure TestElseBranchTerminatorIsConditional;
    /// <summary>Proves <c>on E: EAbort do Exit;</c> does not make the next exception handler unreachable.</summary>
    [ Test ]
    procedure TestOnHandlerTerminatorIsConditional;
    /// <summary>
    /// Proves a terminating case branch does not make the next label unreachable when that label is
    /// a list (<c>B, C:</c>), a range (<c>'a'..'z':</c>) or a qualified name (<c>TKind.B:</c>).
    /// </summary>
    [ Test ]
    procedure TestCaseLabelListsRangesAndQualifiedNames;
    /// <summary>
    /// Proves a terminator just before <c>{$ENDIF}</c> or <c>{$ELSE}</c> does not report the code
    /// after the directive: it is reachable in the configurations that leave the terminator out.
    /// </summary>
    [ Test ]
    procedure TestTerminatorBeforeConditionalDirective;
    /// <summary>Proves method calls named like terminators (<c>Printer.Abort</c>, <c>LoopState.Break</c>) are not terminators.</summary>
    [ Test ]
    procedure TestQualifiedCallsAreNotTerminators;
    /// <summary>
    /// Proves the compiler's predefined symbols are honoured: on Win64 a
    /// <c>{$IFNDEF MSWINDOWS}</c> block is inactive, so its raise does not report the Windows code after it.
    /// </summary>
    [ Test ]
    procedure TestPredefinedPlatformSymbols;
    /// <summary>
    /// Proves the quote-character literal <c>''''</c> is not taken for a multi-line string opener:
    /// the scanner used to skip everything up to the next <c>'''</c> and miss the real finding.
    /// </summary>
    [ Test ]
    procedure TestQuoteLiteralIsNotMultilineString;
    /// <summary>Proves a real Delphi 12 multi-line string is still skipped, so text inside it is not scanned as code.</summary>
    [ Test ]
    procedure TestMultilineStringIsSkipped;
    /// <summary>
    /// Proves <c>{$IFEND}</c> inside an inactive block closes its <c>{$IF}</c>: it used to count as
    /// a new nested IF, so the block never closed and the rest of the unit was skipped.
    /// </summary>
    [ Test ]
    procedure TestIfendInsideInactiveBlock;
    /// <summary>Proves an inactive <c>{$ELSEIF}</c> branch is skipped instead of being scanned as if it were <c>{$ELSE}</c>.</summary>
    [ Test ]
    procedure TestInactiveElseIfBranchIsSkipped;
    /// <summary>
    /// Proves the scan starts at the real <c>implementation</c> keyword, not at the word in a
    /// comment, where an apostrophe in the prose used to open a string that ran to the end of the file.
    /// </summary>
    [ Test ]
    procedure TestImplementationWordInCommentIsIgnored;
    /// <summary>Proves a line comment after <c>then</c> (<c>then // bail out</c>, the Exit on the next line) does not hide the condition.</summary>
    [ Test ]
    procedure TestLineCommentAfterThen;
    /// <summary>Proves an unqualified <c>Abort;</c> / <c>Halt;</c> is not a terminator when the unit declares its own routine or method of that name.</summary>
    [ Test ]
    procedure TestOwnRoutineNamedLikeTerminator;
    /// <summary>
    /// Proves a directive between the terminator and the code before it ends the backward walk as
    /// conditional: the text behind it may belong to another configuration.
    /// </summary>
    [ Test ]
    procedure TestDirectiveBeforeTerminator;
  end;

implementation

uses
  System.SysUtils, System.Classes, UnreachableCodeCore;

const
  CRLF              = #13#10;

/// <summary>Scans ABody wrapped in a minimal unit and returns the 1-based lines reported, comma-separated.</summary>
/// <param name="ABody">Statements placed inside <c>procedure P; begin ... end;</c> in the implementation.</param>
/// <param name="AProjectDefines">The project's defines, semicolon-separated.</param>
/// <returns>The reported lines, comma-separated; empty when nothing is reported.</returns>
/// <remarks>The unit header is 4 lines, so the first body line is line 5.</remarks>
function ReportedLines( const ABody: string; const AProjectDefines: string = '' ): string;
begin
  var sSource       :=
    'unit T;' + CRLF + // 1
    'interface' + CRLF + // 2
    'implementation' + CRLF + // 3
    'procedure P; begin' + CRLF + // 4
    ABody + CRLF +
    'end;' + CRLF +
    'end.';

  var oScanner      := TUnreachableCodeScanner.Create;
  try
    oScanner.SetTarget( 'Win64', AProjectDefines );
    oScanner.ScanSource( sSource, 'C:\p\T.pas', 'T' );

    Result          := '';
    for var rItem in oScanner.GetItems do
    begin
      if Result <> '' then
        Result      := Result + ',';
      Result        := Result + IntToStr( rItem.Line );
    end;
  finally
    oScanner.Free;
  end;
end;

{ TTestUnreachableCodeCore }

procedure TTestUnreachableCodeCore.TestElseBranchTerminatorIsConditional;
begin
  Assert.AreEqual( '', ReportedLines(
      '  if A then DoX else Exit;' + CRLF +
      '  DoY;' ), 'DoY runs whenever A is true' );
  Assert.AreEqual( '', ReportedLines(
      '  if A then DoX else raise EAbort.Create( '''' );' + CRLF +
      '  DoY;' ), 'DoY runs whenever A is true (raise)' );
end;

procedure TTestUnreachableCodeCore.TestOnHandlerTerminatorIsConditional;
begin
  Assert.AreEqual( '', ReportedLines(
      '  try' + CRLF +
      '    DoX;' + CRLF +
      '  except' + CRLF +
      '    on E: EAbort do Exit;' + CRLF +
      '    on E: Exception do Log( E );' + CRLF +
      '  end;' ), 'the second handler runs for any other exception' );
end;

procedure TTestUnreachableCodeCore.TestCaseLabelListsRangesAndQualifiedNames;
begin
  Assert.AreEqual( '', ReportedLines(
      '  case K of' + CRLF +
      '    tkA: Exit;' + CRLF +
      '    tkB, tkC: Foo;' + CRLF +
      '  end;' ), 'label list after a terminating branch' );
  Assert.AreEqual( '', ReportedLines(
      '  case C of' + CRLF +
      '    ''0''..''9'': Exit;' + CRLF +
      '    ''a''..''z'': Foo;' + CRLF +
      '  end;' ), 'character range label after a terminating branch' );
  Assert.AreEqual( '', ReportedLines(
      '  case K of' + CRLF +
      '    TKind.A: Exit;' + CRLF +
      '    TKind.B: Foo;' + CRLF +
      '  end;' ), 'scoped-enum label after a terminating branch' );
end;

procedure TTestUnreachableCodeCore.TestTerminatorBeforeConditionalDirective;
begin
  Assert.AreEqual( '', ReportedLines(
      '  {$IFDEF TRIAL}' + CRLF +
      '  Exit;' + CRLF +
      '  {$ENDIF}' + CRLF +
      '  DoFullVersion;', 'TRIAL' ), 'DoFullVersion runs in every configuration without TRIAL' );
  Assert.AreEqual( '', ReportedLines(
      '  {$IFDEF TRIAL}' + CRLF +
      '  Exit;' + CRLF +
      '  {$ELSE}' + CRLF +
      '  DoFullVersion;' + CRLF +
      '  {$ENDIF}', 'TRIAL' ), 'the ELSE branch is another configuration, not code after the Exit' );
end;

procedure TTestUnreachableCodeCore.TestQualifiedCallsAreNotTerminators;
begin
  Assert.AreEqual( '', ReportedLines(
      '  Printer.Abort;' + CRLF +
      '  ShowMessage( ''Cancelled'' );' ), 'Printer.Abort is a method call' );
  Assert.AreEqual( '', ReportedLines(
      '  LoopState.Break;' + CRLF +
      '  Inc( Count );' ), 'LoopState.Break is a method call' );
end;

procedure TTestUnreachableCodeCore.TestPredefinedPlatformSymbols;
begin
  Assert.AreEqual( '', ReportedLines(
      '  {$IFNDEF MSWINDOWS}' + CRLF +
      '  raise ENotSupportedException.Create( ''Windows only'' );' + CRLF +
      '  {$ENDIF}' + CRLF +
      '  DoWindowsThing;' ), 'MSWINDOWS is predefined for Win64, so the raise is not compiled' );
end;

procedure TTestUnreachableCodeCore.TestQuoteLiteralIsNotMultilineString;
begin
  // Lines: 5 = S := ''''..., 6 = Exit, 7 = Foo (unreachable), 8 = T := ''''.
  Assert.AreEqual( '7', ReportedLines(
      '  S := '''''''' + X;' + CRLF +
      '  Exit;' + CRLF +
      '  Foo;' + CRLF +
      '  T := '''''''';' ), 'Foo after the unconditional Exit is found' );
end;

procedure TTestUnreachableCodeCore.TestMultilineStringIsSkipped;
begin
  Assert.AreEqual( '', ReportedLines(
      '  S := ''''''' + CRLF +
      '    Exit;' + CRLF +
      '    Foo;' + CRLF +
      '    '''''';' + CRLF +
      '  DoIt;' ), 'the Exit inside the multi-line string is text, not code' );
end;

procedure TTestUnreachableCodeCore.TestIfendInsideInactiveBlock;
begin
  // Lines: 5-9 inactive block, 10 = DoA, 11 = Exit, 12 = Foo (unreachable).  (DoA keeps the
  // directive out of the walk back from Exit, which would otherwise call the Exit conditional.)
  Assert.AreEqual( '12', ReportedLines(
      '  {$IFDEF NOT_DEFINED}' + CRLF +
      '  {$IF CompilerVersion > 1}' + CRLF +
      '  DoOld;' + CRLF +
      '  {$IFEND}' + CRLF +
      '  {$ENDIF}' + CRLF +
      '  DoA;' + CRLF +
      '  Exit;' + CRLF +
      '  Foo;' ), 'the scan resumes after the inactive block and finds Foo' );
end;

procedure TTestUnreachableCodeCore.TestInactiveElseIfBranchIsSkipped;
begin
  Assert.AreEqual( '', ReportedLines(
      '  {$IF Defined( NOT_DEFINED )}' + CRLF +
      '  DoA;' + CRLF +
      '  {$ELSEIF Defined( ALSO_NOT_DEFINED )}' + CRLF +
      '  Exit;' + CRLF +
      '  Foo;' + CRLF +
      '  {$ENDIF}' ), 'neither branch is compiled, so nothing in them is reported' );
end;

procedure TTestUnreachableCodeCore.TestImplementationWordInCommentIsIgnored;
begin
  var sSource       :=
    'unit T;' + CRLF + // 1
    '{ implementation note: it''s simple }' + CRLF + // 2
    'interface' + CRLF + // 3
    'implementation' + CRLF + // 4
    'procedure P; begin' + CRLF + // 5
    '  Exit;' + CRLF + // 6
    '  Foo;' + CRLF + // 7
    'end;' + CRLF +
    'end.';

  var oScanner      := TUnreachableCodeScanner.Create;
  try
    oScanner.SetTarget( 'Win64', '' );
    oScanner.ScanSource( sSource, 'C:\p\T.pas', 'T' );
    var aItems      := oScanner.GetItems;
    Assert.AreEqual<Integer>( 1, Length( aItems ), 'exactly one finding' );
    Assert.AreEqual<Integer>( 7, aItems[ 0 ].Line, 'Foo on line 7 is the finding' );
  finally
    oScanner.Free;
  end;
end;

procedure TTestUnreachableCodeCore.TestLineCommentAfterThen;
begin
  Assert.AreEqual( '', ReportedLines(
      '  if not Assigned( X ) then // bail out early' + CRLF +
      '    Exit;' + CRLF +
      '  DoWork;' ), 'DoWork runs whenever X is assigned' );
end;

procedure TTestUnreachableCodeCore.TestOwnRoutineNamedLikeTerminator;
begin
  var sSource       :=
    'unit T;' + CRLF +
    'interface' + CRLF +
    'implementation' + CRLF +
    'type TJob = class procedure Abort; end;' + CRLF +
    'procedure TJob.Abort; begin end;' + CRLF +
    'procedure Halt; begin end;' + CRLF +
    'procedure TJob_Run( J: TJob ); begin' + CRLF +
    '  Abort;' + CRLF +
    '  Halt;' + CRLF +
    '  DoMore;' + CRLF +
    'end;' + CRLF +
    'end.';

  var oScanner      := TUnreachableCodeScanner.Create;
  try
    oScanner.ScanSource( sSource, 'C:\p\T.pas', 'T' );
    Assert.AreEqual<Integer>( 0, Length( oScanner.GetItems ), 'the unit''s own Abort and Halt return' );
  finally
    oScanner.Free;
  end;
end;

procedure TTestUnreachableCodeCore.TestDirectiveBeforeTerminator;
begin
  // LOGGING is not defined, so the compiled code is "if A then Exit;" - the walk back from Exit
  // used to read the inactive "Log;" and call the Exit unconditional.
  Assert.AreEqual( '', ReportedLines(
      '  if A then' + CRLF +
      '  {$IFDEF LOGGING}' + CRLF +
      '    Log;' + CRLF +
      '  {$ENDIF}' + CRLF +
      '    Exit;' + CRLF +
      '  DoWork;' ), 'DoWork runs whenever A is false' );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestUnreachableCodeCore );

end.

