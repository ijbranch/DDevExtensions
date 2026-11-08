unit TestExcelExportDUnitX;

/// <summary>
/// DUnitX test fixture for <c>FrmExcelExport.ExcelCellText</c> - the text the Excel export
/// hands to Excel for each cell.  Excel evaluates a value that starts with '=', '+', '-' or
/// '@' as a formula, so such list-view text must reach the sheet with Excel's text prefix
/// (an apostrophe) and every other value must pass through unchanged.
/// </summary>

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>DUnitX test fixture exercising the Excel export's cell-text escaping.</summary>
  [ TestFixture ]
  TTestExcelExport = class
  public
    /// <summary>
    /// Proves each of the four characters Excel treats as a formula start ( '=', '+', '-', '@' )
    /// gets the apostrophe text prefix, so a unit caption such as "=Foo" is exported as text
    /// instead of being evaluated (or rejected) as a formula.
    /// </summary>
    /// <param name="AText">Cell text starting with a formula character.</param>
    [ Test ]
    [ NamedTestCase( 'Equals', '=SUM(A1)' ) ]
    [ NamedTestCase( 'Plus', '+A1' ) ]
    [ NamedTestCase( 'Minus', '-x' ) ]
    [ NamedTestCase( 'MinusExpression', '-1+2' ) ]
    [ NamedTestCase( 'At', '@Unit' ) ]
    procedure TestFormulaStartIsPrefixed( const AText: string );
    /// <summary>
    /// Proves ordinary text, text containing a formula character later on, and the empty
    /// string pass through unchanged, so the escaping never alters normal names and paths.
    /// </summary>
    /// <param name="AText">Cell text that Excel would not evaluate.</param>
    [ Test ]
    [ NamedTestCase( 'Name', 'UnitMain' ) ]
    [ NamedTestCase( 'Path', 'C:\Src\a=b.pas' ) ]
    [ NamedTestCase( 'Number', '123' ) ]
    [ NamedTestCase( 'Empty', '' ) ]
    procedure TestOrdinaryTextIsUnchanged( const AText: string );
    /// <summary>
    /// Proves a signed number ( "-5", "-0.3", "+1" ) is not given the text prefix although it
    /// starts with '-' or '+', so numeric columns such as a negative value stay numeric in Excel.
    /// </summary>
    /// <param name="AText">Signed number as shown in the list view.</param>
    [ Test ]
    [ NamedTestCase( 'NegativeInteger', '-5' ) ]
    [ NamedTestCase( 'NegativeFraction', '-0.3' ) ]
    [ NamedTestCase( 'PositiveInteger', '+1' ) ]
    procedure TestSignedNumberStaysNumeric( const AText: string );
  end;

implementation

uses
  FrmExcelExport;

procedure TTestExcelExport.TestFormulaStartIsPrefixed( const AText: string );
begin
  Assert.AreEqual( '''' + AText, ExcelCellText( AText ), 'a formula-start character must get the text prefix' );
end;

procedure TTestExcelExport.TestOrdinaryTextIsUnchanged( const AText: string );
begin
  Assert.AreEqual( AText, ExcelCellText( AText ), 'text Excel would not evaluate must pass through unchanged' );
end;

procedure TTestExcelExport.TestSignedNumberStaysNumeric( const AText: string );
begin
  Assert.AreEqual( AText, ExcelCellText( AText ), 'a signed number must not get the text prefix' );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestExcelExport );

end.

