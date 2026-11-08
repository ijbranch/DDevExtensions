unit TestDfmPasConsistencyCoreDUnitX;

/// <summary>
/// DUnitX test fixture for <c>DfmPasConsistencyCore</c> - the comparison of a form resource's
/// components with its unit's fields.
/// </summary>
/// <remarks>
/// Every test builds the two halves in memory.  The cases are the ones a real project throws at the
/// check: inherited forms ( the ancestor declares the overridden components ), frames ( the frame
/// declares its own components ), class methods in the middle of a private section, and binary
/// form resources, plus a genuine difference that must still be reported.
/// </remarks>

interface

uses
  DUnitX.TestFramework, System.SysUtils, DfmPasConsistencyCore;

type
  /// <summary>DUnitX test fixture exercising the DFM/PAS comparison.</summary>
  [ TestFixture ]
  TTestDfmPasConsistencyCore = class
  public
    /// <summary>Proves an `inherited` component of a descendant form, declared by the ancestor class,
    /// is not reported as missing from the descendant's unit.</summary>
    [ Test ]
    procedure TestInheritedComponentIsNotMissing;
    /// <summary>Proves the components inside an `inline` frame belong to the frame, not to the form,
    /// and are not reported as missing from the form's unit.</summary>
    [ Test ]
    procedure TestFrameChildrenAreNotMissing;
    /// <summary>Proves a class method inside a private section does not turn the private fields after
    /// it into published components.</summary>
    [ Test ]
    procedure TestClassMethodKeepsVisibility;
    /// <summary>Proves a binary ( TPF0 ) form resource is read: a consistent form reports nothing.</summary>
    [ Test ]
    procedure TestBinaryDfmIsRead;
    /// <summary>Proves a form resource in resource-stream format ( as the designer hands it out ) is read.</summary>
    [ Test ]
    procedure TestResourceStreamDfmIsRead;
    /// <summary>Proves a real difference is still reported: a published field with no component.</summary>
    [ Test ]
    procedure TestGenuineMissingComponentIsReported;
    /// <summary>Proves a UTF-16 text DFM ( FF FE BOM ) is read as text, not as a resource stream.</summary>
    [ Test ]
    procedure TestUtf16TextDfmIsRead;
    /// <summary>Proves only the class the DFM's root names is compared: a forward declaration, a
    /// class reference and another class's fields are not the form's.</summary>
    [ Test ]
    procedure TestOnlyTheFormClassIsCompared;
    /// <summary>Proves every name of "Button1, Edit1: ..." is a field, not only the last.</summary>
    [ Test ]
    procedure TestCommaListDeclaresEveryName;
  end;

implementation

uses
  System.Classes;

const
  /// <summary>A form unit declaring Button1 and Edit1.</summary>
  PAS_FORM1         =
    'unit Unit1;'#13#10 +
    'interface'#13#10 +
    'uses Vcl.Forms, Vcl.StdCtrls;'#13#10 +
    'type'#13#10 +
    '  TForm1 = class(TForm)'#13#10 +
    '    Button1: TButton;'#13#10 +
    '    Edit1: TEdit;'#13#10 +
    '  end;'#13#10 +
    'implementation'#13#10 +
    'end.';

  /// <summary>The text form resource matching <see cref="PAS_FORM1"/>.</summary>
  DFM_FORM1         =
    'object Form1: TForm1'#13#10 +
    '  Left = 0'#13#10 +
    '  Top = 0'#13#10 +
    '  object Button1: TButton'#13#10 +
    '    Left = 8'#13#10 +
    '  end'#13#10 +
    '  object Edit1: TEdit'#13#10 +
    '    Left = 8'#13#10 +
    '  end'#13#10 +
    'end'#13#10;

/// <summary>The bytes of a string as UTF-8.</summary>
/// <param name="AText">The text.</param>
/// <returns>Its UTF-8 bytes.</returns>
function Utf8Bytes( const AText: string ): TBytes;
begin
  Result            := TEncoding.UTF8.GetBytes( AText );
end;

/// <summary>A text form resource converted to binary ( TPF0 ) or resource-stream form.</summary>
/// <param name="AText">The text form resource.</param>
/// <param name="AResource">True for a resource stream, False for plain TPF0.</param>
/// <returns>The converted bytes.</returns>
function ConvertedDfm( const AText: string; AResource: Boolean ): TBytes;
var
  Input, Output     : TMemoryStream;
begin
  Input             := TMemoryStream.Create;
  Output            := TMemoryStream.Create;
  try
    var Bytes       := Utf8Bytes( AText );
    Input.WriteBuffer( Bytes[ 0 ], Length( Bytes ) );
    Input.Position  := 0;
    if AResource then
      ObjectTextToResource( Input, Output )
    else
      ObjectTextToBinary( Input, Output );
    SetLength( Result, Output.Size );
    Move( Output.Memory^, Result[ 0 ], Output.Size );
  finally
    Output.Free;
    Input.Free;
  end;
end;

procedure TTestDfmPasConsistencyCore.TestInheritedComponentIsNotMissing;
const
  PAS               =
    'unit Unit2;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TForm2 = class(TForm1)'#13#10 +
    '    Memo1: TMemo;'#13#10 +
    '  end;'#13#10 +
    'implementation'#13#10 +
    'end.';
  DFM               =
    'inherited Form2: TForm2'#13#10 +
    '  Caption = ''Two'''#13#10 +
    '  inherited Button1: TButton'#13#10 +
    '    Caption = ''Changed'''#13#10 +
    '  end'#13#10 +
    '  object Memo1: TMemo'#13#10 +
    '  end'#13#10 +
    'end'#13#10;
begin
  var Results       := AnalyseFormUnit( UTF8String( PAS ), Utf8Bytes( DFM ), 'C:\x\Unit2.pas' );
  Assert.AreEqual( 0, Length( Results ), 'Button1 is declared by TForm1, not TForm2' );
end;

procedure TTestDfmPasConsistencyCore.TestFrameChildrenAreNotMissing;
const
  PAS               =
    'unit Unit3;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TForm3 = class(TForm)'#13#10 +
    '    Frame11: TFrame1;'#13#10 +
    '  end;'#13#10 +
    'implementation'#13#10 +
    'end.';
  DFM               =
    'object Form3: TForm3'#13#10 +
    '  inline Frame11: TFrame1'#13#10 +
    '    Left = 8'#13#10 +
    '    inherited Label1: TLabel'#13#10 +
    '    end'#13#10 +
    '    inherited Panel1: TPanel'#13#10 +
    '      object Button9: TButton'#13#10 +
    '      end'#13#10 +
    '    end'#13#10 +
    '  end'#13#10 +
    'end'#13#10;
begin
  var Results       := AnalyseFormUnit( UTF8String( PAS ), Utf8Bytes( DFM ), 'C:\x\Unit3.pas' );
  Assert.AreEqual( 0, Length( Results ), 'Label1, Panel1 and Button9 belong to the frame' );
end;

procedure TTestDfmPasConsistencyCore.TestClassMethodKeepsVisibility;
const
  PAS               =
    'unit Unit1;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TForm1 = class(TForm)'#13#10 +
    '    Button1: TButton;'#13#10 +
    '    Edit1: TEdit;'#13#10 +
    '  private'#13#10 +
    '    class function Instance: TForm1;'#13#10 +
    '    FTimer: TTimer;'#13#10 +
    '  end;'#13#10 +
    'implementation'#13#10 +
    'end.';
begin
  var Results       := AnalyseFormUnit( UTF8String( PAS ), Utf8Bytes( DFM_FORM1 ), 'C:\x\Unit1.pas' );
  Assert.AreEqual( 0, Length( Results ), 'FTimer is a private field, not a component' );
end;

procedure TTestDfmPasConsistencyCore.TestBinaryDfmIsRead;
begin
  var Results       := AnalyseFormUnit( UTF8String( PAS_FORM1 ), ConvertedDfm( DFM_FORM1, False ), 'C:\x\Unit1.pas' );
  Assert.AreEqual( 0, Length( Results ), 'a consistent binary form reports nothing' );
end;

procedure TTestDfmPasConsistencyCore.TestResourceStreamDfmIsRead;
begin
  var Results       := AnalyseFormUnit( UTF8String( PAS_FORM1 ), ConvertedDfm( DFM_FORM1, True ), 'C:\x\Unit1.pas' );
  Assert.AreEqual( 0, Length( Results ), 'a consistent resource-stream form reports nothing' );
end;

procedure TTestDfmPasConsistencyCore.TestGenuineMissingComponentIsReported;
const
  DFM               =
    'object Form1: TForm1'#13#10 +
    '  object Button1: TButton'#13#10 +
    '  end'#13#10 +
    'end'#13#10;
begin
  var Results       := AnalyseFormUnit( UTF8String( PAS_FORM1 ), Utf8Bytes( DFM ), 'C:\x\Unit1.pas' );
  Assert.AreEqual( 1, Length( Results ) );
  Assert.AreEqual( 'Edit1', Results[ 0 ].ComponentName );
  Assert.IsTrue( Results[ 0 ].InconsistencyType = itMissingInDfm, 'Edit1 has no component' );
end;

procedure TTestDfmPasConsistencyCore.TestUtf16TextDfmIsRead;
begin
  var Bytes         := TEncoding.Unicode.GetPreamble + TEncoding.Unicode.GetBytes( DFM_FORM1 );
  var Results       := AnalyseFormUnit( UTF8String( PAS_FORM1 ), Bytes, 'C:\x\Unit1.pas' );
  Assert.AreEqual( 0, Length( Results ), 'a consistent UTF-16 form reports nothing' );
end;

procedure TTestDfmPasConsistencyCore.TestOnlyTheFormClassIsCompared;
const
  PAS               =
    'unit Unit1;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TForm1 = class;'#13#10 +
    '  TForm1Class = class of TForm1;'#13#10 +
    '  THelper = class(TObject)'#13#10 +
    '    Timer: TTimer;'#13#10 +
    '  end;'#13#10 +
    '  TForm1 = class(TForm)'#13#10 +
    '    Button1: TButton;'#13#10 +
    '    Edit1: TEdit;'#13#10 +
    '  end;'#13#10 +
    '  TOther = class(TForm)'#13#10 +
    '    Memo9: TMemo;'#13#10 +
    '  end;'#13#10 +
    'implementation'#13#10 +
    'end.';
begin
  var Results       := AnalyseFormUnit( UTF8String( PAS ), Utf8Bytes( DFM_FORM1 ), 'C:\x\Unit1.pas' );
  Assert.AreEqual( 0, Length( Results ), 'Timer and Memo9 belong to other classes' );
end;

procedure TTestDfmPasConsistencyCore.TestCommaListDeclaresEveryName;
const
  PAS               =
    'unit Unit1;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TForm1 = class(TForm)'#13#10 +
    '    Button1, Edit1: TButton;'#13#10 +
    '  end;'#13#10 +
    'implementation'#13#10 +
    'end.';
begin
  var Results       := AnalyseFormUnit( UTF8String( PAS ), Utf8Bytes( DFM_FORM1 ), 'C:\x\Unit1.pas' );
  // Button1 matches; Edit1 is declared, but as TButton - a type mismatch, not "missing".
  Assert.AreEqual( 1, Length( Results ) );
  Assert.AreEqual( 'Edit1', Results[ 0 ].ComponentName );
  Assert.IsTrue( Results[ 0 ].InconsistencyType = itTypeMismatch, 'Edit1 was recorded from the list' );
end;

initialization
  TDUnitX.RegisterTestFixture( TTestDfmPasConsistencyCore );

end.

