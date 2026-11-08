unit TestTodoAggregatorCoreDUnitX;

/// <summary>
/// DUnitX test fixture for <c>TodoAggregatorCore</c> - recognising a tagged comment ( TODO, FIXME,
/// BUG, NOTE ... ) and collecting every one in a unit's source.
/// </summary>
/// <remarks>
/// The core takes source text, never a file, so every test runs without the IDE.  The tagging rule
/// under test: a tag counts when it is a whole word AND it is written in capitals, or opens the
/// comment, or is followed by a colon or a priority; a word that merely appears in prose ( "a bug
/// in the parser" ) is not a tag.
/// </remarks>

interface

uses
  DUnitX.TestFramework, TodoAggregatorCore;

type
  /// <summary>DUnitX test fixture exercising the TODO scanner core.</summary>
  [ TestFixture ]
  TTestTodoAggregatorCore = class
  private
    /// <summary>Scanner with the default patterns, created per test.</summary>
    FScanner: TTodoScanner;
  public
    /// <summary>Creates the scanner.</summary>
    [ Setup ]
    procedure Setup;
    /// <summary>Frees the scanner.</summary>
    [ TearDown ]
    procedure TearDown;
    /// <summary>Proves a tag is still found when the same letters first appear inside a longer word
    /// ( "BUGFIX" before "BUG" ): every occurrence is tried, not only the first.</summary>
    [ Test ]
    procedure TestLaterWholeWordOccurrenceIsFound;
    /// <summary>Proves an ordinary word in prose ( "a bug in", "note that" ) is not reported as a tag.</summary>
    [ Test ]
    procedure TestProseWordIsNotATag;
    /// <summary>Proves the tag that comes FIRST in the comment wins, whatever the pattern order.</summary>
    [ Test ]
    procedure TestEarliestTagWins;
    /// <summary>Proves the common forms are still tags: a capitalised tag without a colon, a lower-case
    /// tag with a colon, and a tag opening the comment.</summary>
    [ Test ]
    procedure TestUsualFormsAreTags;
    /// <summary>Proves TODO(high) sets the priority and the text starts after the colon.</summary>
    [ Test ]
    procedure TestPriorityIsParsed;
    /// <summary>Proves the scanner reports 1-based lines and columns from the lexer.</summary>
    [ Test ]
    procedure TestScanSourceReportsOneBasedLines;
    /// <summary>Proves a lower-case tag after comment decoration or a date still opens the comment:
    /// "// @todo", "/// todo" ( body starts "/" ), "//- todo", "// 2026-11 fixme" - while a word of
    /// prose before the tag still makes it prose.</summary>
    [ Test ]
    procedure TestLeadInBeforeLowerCaseTag;
  end;

implementation

uses
  System.SysUtils;

procedure TTestTodoAggregatorCore.Setup;
begin
  FScanner          := TTodoScanner.Create;
end;

procedure TTestTodoAggregatorCore.TearDown;
begin
  FreeAndNil( FScanner );
end;

procedure TTestTodoAggregatorCore.TestLaterWholeWordOccurrenceIsFound;
var
  sCategory, sPriority, sText: string;
begin
  Assert.IsTrue( FScanner.ParseTodoComment( ' BUGFIX released; BUG: 12 is still open', sCategory, sPriority, sText ),
    'BUG after BUGFIX must be found' );
  Assert.AreEqual( 'BUG', sCategory );
  Assert.AreEqual( '12 is still open', sText );
end;

procedure TTestTodoAggregatorCore.TestProseWordIsNotATag;
var
  sCategory, sPriority, sText: string;
begin
  Assert.IsFalse( FScanner.ParseTodoComment( ' Works round a bug in the parser', sCategory, sPriority, sText ),
    '"a bug in" is prose' );
  Assert.IsFalse( FScanner.ParseTodoComment( ' Remember to note that the caller frees it', sCategory, sPriority, sText ),
    '"to note that" is prose' );
end;

procedure TTestTodoAggregatorCore.TestEarliestTagWins;
var
  sCategory, sPriority, sText: string;
begin
  Assert.IsTrue( FScanner.ParseTodoComment( ' NOTE: the TODO list is kept elsewhere', sCategory, sPriority, sText ) );
  Assert.AreEqual( 'NOTE', sCategory );
  Assert.AreEqual( 'the TODO list is kept elsewhere', sText );
end;

procedure TTestTodoAggregatorCore.TestUsualFormsAreTags;
var
  sCategory, sPriority, sText: string;
begin
  Assert.IsTrue( FScanner.ParseTodoComment( ' Later TODO fix the rounding', sCategory, sPriority, sText ), 'capitals' );
  Assert.AreEqual( 'TODO', sCategory );
  Assert.IsTrue( FScanner.ParseTodoComment( ' Rounding - fixme: halves go the wrong way', sCategory, sPriority, sText ),
    'lower case with a colon' );
  Assert.AreEqual( 'FIXME', sCategory );
  Assert.AreEqual( 'halves go the wrong way', sText );
  Assert.IsTrue( FScanner.ParseTodoComment( ' hack around the VCL focus bug', sCategory, sPriority, sText ),
    'a tag opening the comment' );
  Assert.AreEqual( 'HACK', sCategory );
end;

procedure TTestTodoAggregatorCore.TestPriorityIsParsed;
var
  sCategory, sPriority, sText: string;
begin
  Assert.IsTrue( FScanner.ParseTodoComment( ' TODO(high): ship it', sCategory, sPriority, sText ) );
  Assert.AreEqual( 'High', sPriority );
  Assert.AreEqual( 'ship it', sText );
end;

procedure TTestTodoAggregatorCore.TestScanSourceReportsOneBasedLines;
begin
  var Items         := FScanner.ScanSource( UTF8String( 'unit U;'#13#10'interface'#13#10'  // TODO: one'#13#10'end.' ),
    'C:\x\U.pas' );
  Assert.AreEqual( 1, Length( Items ) );
  Assert.AreEqual( 3, Items[ 0 ].Line );
  Assert.AreEqual( 3, Items[ 0 ].Column );
  Assert.AreEqual( 'U', Items[ 0 ].UnitName );
  Assert.AreEqual( 'one', Items[ 0 ].Text );
end;

procedure TTestTodoAggregatorCore.TestLeadInBeforeLowerCaseTag;
var
  sCategory, sPriority, sText: string;
begin
  Assert.IsTrue( FScanner.ParseTodoComment( ' @todo refactor', sCategory, sPriority, sText ), '@todo' );
  Assert.AreEqual( 'refactor', sText );
  Assert.IsTrue( FScanner.ParseTodoComment( '/ todo tidy', sCategory, sPriority, sText ), '/// todo' );
  Assert.AreEqual( 'tidy', sText );
  Assert.IsTrue( FScanner.ParseTodoComment( '- todo x', sCategory, sPriority, sText ), '//- todo' );
  Assert.IsTrue( FScanner.ParseTodoComment( ' 2026-11 fixme later', sCategory, sPriority, sText ), 'dated fixme' );
  Assert.AreEqual( 'FIXME', sCategory );
  Assert.IsTrue( FScanner.ParseTodoComment( ' see the notes: todo: call it', sCategory, sPriority, sText ),
    'a lower-case tag with a colon counts anywhere' );
  Assert.AreEqual( 'TODO', sCategory );
  Assert.IsFalse( FScanner.ParseTodoComment( ' - a bug in the parser', sCategory, sPriority, sText ),
    'prose after decoration is still prose' );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestTodoAggregatorCore );

end.

