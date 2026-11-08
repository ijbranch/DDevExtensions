{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit DfmPasConsistencyCore;

/// <summary>
/// Pure core of the DFM/PAS Consistency check: compares the components a form resource declares
/// with the fields its unit declares.  No ToolsAPI and no VCL, so it is unit-testable outside the
/// IDE; the plugin decides where the two halves come from.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  /// <summary>Classification of a DFM/PAS inconsistency.</summary>
  TInconsistencyType = (
    /// <summary>Component appears in the DFM but is not declared in the PAS.</summary>
    itMissingInPas,
    /// <summary>Field is declared in the PAS but no component exists in the DFM.</summary>
    itMissingInDfm,
    /// <summary>Component exists in both files but the declared types differ.</summary>
    itTypeMismatch
    );

  /// <summary>Detailed description of one inconsistency between a DFM and its PAS unit.</summary>
  TInconsistencyInfo = record
    /// <summary>Bare unit name for display.</summary>
    UnitName: string;
    /// <summary>Component identifier as it appears in the source.</summary>
    ComponentName: string;
    /// <summary>Component type as declared in the DFM (or empty when missing).</summary>
    DfmType: string;
    /// <summary>Field type as declared in the PAS (or empty when missing).</summary>
    PasType: string;
    /// <summary>Classification of the inconsistency.</summary>
    InconsistencyType: TInconsistencyType;
    /// <summary>Absolute path of the DFM file.</summary>
    DfmFileName: string;
    /// <summary>Absolute path of the PAS file.</summary>
    PasFileName: string;
    /// <summary>Line number in the DFM file (0 when not applicable).</summary>
    DfmLineNumber: Integer;
    /// <summary>Line number in the PAS file (0 when not applicable).</summary>
    PasLineNumber: Integer;
  end;

/// <summary>
/// Analyses one form unit by comparing the components declared in its form resource with the
/// field declarations of its unit.
/// </summary>
/// <param name="PasSource">UTF-8 text of the Pascal unit, without a BOM.</param>
/// <param name="DfmBytes">The form resource as stored: text, binary ( TPF0 ) or a resource stream.</param>
/// <param name="FileName">Absolute path of the PAS file ( used for report metadata ).</param>
/// <returns>The differences found.</returns>
function AnalyseFormUnit( const PasSource: UTF8String; const DfmBytes: TBytes;
  const FileName: string ): TArray<TInconsistencyInfo>;

/// <summary>A form resource as text, whatever form it is stored in.</summary>
/// <param name="DfmBytes">Text ( UTF-8 or ANSI ), binary ( TPF0 ) or a resource stream ( $FF header ).</param>
/// <returns>The text form of the resource; empty for no bytes.</returns>
/// <exception cref="EParserError">Raised when a binary resource is malformed.</exception>
function DfmBytesToText( const DfmBytes: TBytes ): string;

implementation

uses
  DelphiLexer, DecirculariserCore;

type
  /// <summary>One component or field: its name, type and 1-based line.</summary>
  TComponentInfo = record
    /// <summary>Component or field name.</summary>
    Name: string;
    /// <summary>Declared type.</summary>
    TypeName: string;
    /// <summary>1-based line of the declaration.</summary>
    LineNumber: Integer;
  end;

/// <summary>Compares a form's text resource with its unit.</summary>
/// <param name="PasSource">UTF-8 text of the unit.</param>
/// <param name="DfmSource">Text form of the form resource.</param>
/// <param name="FileName">Absolute path of the PAS file.</param>
/// <returns>The differences found.</returns>
function AnalyseFormUnitText( const PasSource: UTF8String; const DfmSource: string;
  const FileName: string ): TArray<TInconsistencyInfo>;
var
  DfmComponents     : TDictionary<string, TComponentInfo>;
  PasComponents     : TDictionary<string, TComponentInfo>;
  Results           : TList<TInconsistencyInfo>;
  Info              : TInconsistencyInfo;
  Lexer             : TDelphiLexer;
  Token             : TToken;
  InType            : Boolean;
  InFormClass       : Boolean;
  CurrentFieldType  : string;
  { The class the DFM's root object names ( "object Form1: TForm1" ): the only class compared. }
  RootType          : string;
  Key               : string;
  DfmInfo, PasInfo  : TComponentInfo;

  function IsDatasetFieldType( const TypeName: string ): Boolean;
  var
    UpperType       : string;
  begin
    // Dataset field types (TField descendants) don't need explicit PAS declarations
    // They are auto-generated persistent fields accessed via FieldByName or dataset
    UpperType       := UpperCase( TypeName );
    Result          := ( Length( UpperType ) > 5 ) and
      ( UpperType[ 1 ] = 'T' ) and
      ( Copy( UpperType, Length( UpperType ) - 4, 5 ) = 'FIELD' );
  end;

  function IsNonComponentType( const TypeName: string ): Boolean;
  var
    UpperType       : string;
  begin
    if TypeName = '' then
      Exit( False );

    // Filter out common non-component types that are often declared as form fields
    // but are not visual/non-visual components placed on forms
    UpperType       := UpperCase( TypeName );
    Result          :=
      // Collection types
      ( Pos( 'TLIST', UpperType ) > 0 ) or
      ( Pos( 'DICTIONARY', UpperType ) > 0 ) or
      ( Pos( 'TSTACK', UpperType ) > 0 ) or
      ( Pos( 'TQUEUE', UpperType ) > 0 ) or
      ( Pos( 'THASH', UpperType ) > 0 ) or
      ( UpperType = 'TSTRINGLIST' ) or
      ( UpperType = 'TSTRINGS' ) or
      // Thread types
      ( Pos( 'TTHREAD', UpperType ) > 0 ) or
      // Stream types
      ( Pos( 'TSTREAM', UpperType ) > 0 ) or
      // Graphics objects (not components, usually owned by other components)
      ( UpperType = 'TBITMAP' ) or
      ( UpperType = 'TICON' ) or
      ( UpperType = 'TPICTURE' ) or
      ( UpperType = 'TBRUSH' ) or
      ( UpperType = 'TPEN' ) or
      ( UpperType = 'TFONT' ) or
      ( UpperType = 'TCANVAS' ) or
      // Other common non-component types
      ( UpperType = 'TINIFILE' ) or
      ( UpperType = 'TREGISTRY' ) or
      ( UpperType = 'TXMLNODE' ) or
      ( UpperType = 'TXMLDOCUMENT' ) or
      ( UpperType = 'TJSONVALUE' ) or
      ( UpperType = 'TJSONOBJECT' ) or
      ( UpperType = 'TJSONARRAY' ) or
      // Value types and records
      ( UpperType = 'TPOINT' ) or
      ( UpperType = 'TRECT' ) or
      ( UpperType = 'TSIZE' ) or
      ( UpperType = 'TSHIFTSTATE' ) or
      ( UpperType = 'TGUID' ) or
      // Action/event types (often from method parameters)
      ( UpperType = 'TCLOSEACTION' ) or
      ( UpperType = 'TDATAACTION' ) or
      ( UpperType = 'TCUSTOMFORM' ) or
      // State types (used in event handlers)
      ( Pos( 'STATE', UpperType ) > 0 ) or // TGridDrawState, TOwnerDrawState, etc.
      ( Pos( 'ACTIVITY', UpperType ) > 0 ) or // TMouseActivity, etc.
      // Abstract base classes often used as variable types, not placed components
      ( UpperType = 'TDATASET' ) or
      ( UpperType = 'TFIELD' ) or
      ( UpperType = 'TCOMPONENT' ) or
      ( UpperType = 'TCONTROL' ) or
      ( UpperType = 'TWINCONTROL' ) or
      // Interface types (start with I, not T, but check anyway)
      ( TypeName[ 1 ] = 'I' );
  end;

  procedure ParseDfmComponents;
  var
    Lines           : TStringList;
    I               : Integer;
    TrimmedLine, LowerLine, Keyword: string;
    CompInfo        : TComponentInfo;
    ColonPos        : Integer;
    CollectionDepth : Integer; // Track < > collection blocks
    { One entry per open object: True when it lies inside an "inline" frame. }
    InFrame         : TStack<Boolean>;
  begin
    Lines           := TStringList.Create;
    InFrame         := TStack<Boolean>.Create;
    try
      Lines.Text    := DfmSource;
      CollectionDepth := 0;

      for I := 0 to Lines.Count - 1 do
      begin
        TrimmedLine := Trim( Lines[ I ] );

        // Track collection blocks (< >) - these contain item/end pairs we must ignore
        // Collection properties look like: Items = < ... > (potentially multi-line)
        if Pos( '= <', TrimmedLine ) > 0 then
        begin
          // Check if it's a single-line empty collection: = <>
          if Pos( '>', TrimmedLine ) = 0 then
            Inc( CollectionDepth ); // Multi-line collection starts
          // else: Single-line collection like = <>, no depth change needed
        end
        else if ( CollectionDepth > 0 ) and
          ( ( TrimmedLine = '>' ) or
          ( Copy( TrimmedLine, Length( TrimmedLine ), 1 ) = '>' ) ) then
          Dec( CollectionDepth );

        // Skip processing if we're inside a collection block
        if CollectionDepth > 0 then
          Continue;

        LowerLine   := LowerCase( TrimmedLine );
        if LowerLine.StartsWith( 'object ' ) then
          Keyword   := 'object'
        else if LowerLine.StartsWith( 'inherited ' ) then
          Keyword   := 'inherited'
        else if LowerLine.StartsWith( 'inline ' ) then
          Keyword   := 'inline'
        else
          Keyword   := '';

        if ( Keyword <> '' ) then
        begin
          var bParentInFrame := ( InFrame.Count > 0 ) and InFrame.Peek;
          var bIsRoot := ( InFrame.Count = 0 );
          InFrame.Push( bParentInFrame or ( Keyword = 'inline' ) );

          if bIsRoot and ( RootType = '' ) and ( Pos( ':', TrimmedLine ) > 0 ) then
          begin
            RootType := Trim( Copy( TrimmedLine, Pos( ':', TrimmedLine ) + 1, MaxInt ) );
            if ( Pos( ' ', RootType ) > 0 ) then
              RootType := Copy( RootType, 1, Pos( ' ', RootType ) - 1 );
          end;

          { The form itself is not a field.  Neither is anything inside an inline frame ( the frame
            declares it ), nor an "inherited" component ( its ancestor class declares it ). }
          if bIsRoot or bParentInFrame or ( Keyword = 'inherited' ) then
            Continue;

          TrimmedLine := Trim( Copy( TrimmedLine, Length( Keyword ) + 2, MaxInt ) );
          ColonPos  := Pos( ':', TrimmedLine );
          if ColonPos > 0 then
          begin
            CompInfo.Name := Trim( Copy( TrimmedLine, 1, ColonPos - 1 ) );
            CompInfo.TypeName := Trim( Copy( TrimmedLine, ColonPos + 1, MaxInt ) );
            // An "[n]" child-order suffix ( "object X: TButton [0]" ) is not part of the type.
            if ( Pos( ' ', CompInfo.TypeName ) > 0 ) then
              CompInfo.TypeName := Copy( CompInfo.TypeName, 1, Pos( ' ', CompInfo.TypeName ) - 1 );
            CompInfo.LineNumber := I + 1;

            // Skip dataset field types - they don't need PAS declarations
            if not IsDatasetFieldType( CompInfo.TypeName ) then
              DfmComponents.AddOrSetValue( UpperCase( CompInfo.Name ), CompInfo );
          end;
        end
        else if SameText( TrimmedLine, 'end' ) then
        begin
          if ( InFrame.Count > 0 ) then
            InFrame.Pop;
        end;
      end;
    finally
      InFrame.Free;
      Lines.Free;
    end;
  end;

  procedure ParsePasComponents;
  var
    InPrivate, InPublic, InPublished, InProtected: Boolean;
    ExpectingType   : Boolean;
    Done            : Boolean;
    ParenDepth      : Integer;
    PrevKind        : TTokenKind;
    { Name before the last "=", and the class it opened, waiting to see whether it is a real class
      body or only "TForm1 = class;" / "TFormClass = class of TForm1;". }
    LastIdent       : string;
    bPending        : Boolean;
    { Nesting inside the form class: 1 in its body, more inside a nested record or class. }
    ClassDepth      : Integer;
    { The names of the field declaration being read ( "Button1, Button2: TButton;" ). }
    FieldNames      : TList<TPair<string, Integer>>;

    procedure OpenFormClass;
    begin
      InFormClass   := True;
      ClassDepth    := 1;
      InPublished   := True; // Fields before any visibility are published by default
      InPrivate     := False;
      InPublic      := False;
      InProtected   := False;
      ExpectingType := False;
      FieldNames.Clear;
    end;

    procedure SkipDeclaration;
    begin
      // Skip to end of declaration - must handle parentheses for parameters
      // e.g., procedure Foo(Sender: TObject; var Action: TCloseAction);
      // The semicolon inside () separates parameters, not the end of declaration
      ParenDepth    := 0;
      while Lexer.NextToken( Token ) do
      begin
        if Token.Kind = tkLParan then
          Inc( ParenDepth )
        else if Token.Kind = tkRParan then
          Dec( ParenDepth )
        else if ( Token.Kind = tkSemicolon ) and ( ParenDepth = 0 ) then
          Break;
      end;
    end;

  begin
    FieldNames      := TList<TPair<string, Integer>>.Create;
    Lexer           := TDelphiLexer.Create( '', PasSource );
    try
      InType        := False;
      InFormClass   := False;
      InPrivate     := False;
      InPublic      := False;
      InPublished   := False;
      InProtected   := False;
      ExpectingType := False;
      Done          := False;
      PrevKind      := tkComment;
      LastIdent     := '';

      bPending      := False;
      ClassDepth    := 0;

      while ( not Done ) and Lexer.NextToken( Token ) do
      begin
        if ( Token.Kind = tkComment ) then
          Continue;

        // The token after "= class" decides: ";" is a forward declaration, "of" a class reference.
        if bPending then
        begin
          bPending  := False;
          if ( not ( Token.Kind in [ tkSemicolon, tkI_of ] ) ) then
          begin
            OpenFormClass;
            if ( Token.Kind = tkLParan ) then
            begin
              // The heritage list "( TForm, IFoo )" holds no fields.
              ParenDepth := 1;
              while ( ParenDepth > 0 ) and Lexer.NextToken( Token ) do
                if Token.Kind = tkLParan then
                  Inc( ParenDepth )
                else if Token.Kind = tkRParan then
                  Dec( ParenDepth );
              PrevKind := tkRParan;
              Continue;
            end;
          end;
        end;

        case Token.Kind of
          tkI_type:
            InType  := True;

          tkI_implementation:
            Done    := True; // Stop at implementation - Break only exits case, not while

          tkI_class, tkI_record:
            if InFormClass then
            begin
              // A nested type has its own "end"; "class function" / "class var" is a modifier.
              if ( PrevKind = tkEqual ) or ( Token.Kind = tkI_record ) then
                Inc( ClassDepth );
            end
              // Only "TName = class" can open the form's class, and only the class the DFM's root
              // object names: other classes in the unit are not the form ( no root known: any class ).
            else if InType and ( PrevKind = tkEqual ) and ( ( RootType = '' ) or SameText( LastIdent, RootType ) ) then
            begin
              bPending := True;
            end;

          tkI_private:
            begin
              InPrivate := True;
              InPublic := False;
              InPublished := False;
              InProtected := False;
            end;

          tkI_public:
            begin
              InPrivate := False;
              InPublic := True;
              InPublished := False;
              InProtected := False;
            end;

          tkI_published:
            begin
              InPrivate := False;
              InPublic := False;
              InPublished := True;
              InProtected := False;
            end;

          tkI_protected:
            begin
              InPrivate := False;
              InPublic := False;
              InPublished := False;
              InProtected := True;
            end;

          tkI_procedure, tkI_function, tkI_constructor, tkI_destructor, tkI_property:
            begin
              SkipDeclaration;
              FieldNames.Clear;
              ExpectingType := False;
            end;

          tkI_end:
            if InFormClass then
            begin
              Dec( ClassDepth );
              if ( ClassDepth <= 0 ) then
              begin
                InFormClass := False;
                // The form class is the one wanted; nothing after it matters.
                if ( RootType <> '' ) then
                  Done := True;
              end;
            end;
        else
          if Token.Kind >= tkIdent then
          begin
            if ( not InFormClass ) then
              LastIdent := string( Token.Value )
            else if ( ClassDepth = 1 ) and ( InPublished or ( not InPrivate and not InPublic and not InProtected ) ) then
            begin
              if ExpectingType then
              begin
                // This is the type: every name of the list gets it.
                CurrentFieldType := string( Token.Value );
                for var Field in FieldNames do
                begin
                  PasInfo.Name := Field.Key;
                  PasInfo.TypeName := CurrentFieldType;
                  PasInfo.LineNumber := Field.Value; // Use line from field name, not type
                  PasComponents.AddOrSetValue( UpperCase( Field.Key ), PasInfo );
                end;
                FieldNames.Clear;
                ExpectingType := False;
              end
              else
              begin
                // A field name; after a comma it joins the list ( "Button1, Button2: TButton" ).
                // Token.Line is 0-based, convert to 1-based for display
                if ( PrevKind <> tkComma ) then
                  FieldNames.Clear;
                FieldNames.Add( TPair<string, Integer>.Create( string( Token.Value ), Token.Line + 1 ) );
              end;
            end;
          end
          else if Token.Kind = tkColon then
          begin
            if InFormClass and ( FieldNames.Count > 0 ) then
              ExpectingType := True;
          end
          else if Token.Kind = tkSemicolon then
          begin
            ExpectingType := False;
            FieldNames.Clear;
          end;
        end;
        PrevKind    := Token.Kind;
      end;
    finally
      Lexer.Free;
      FieldNames.Free;
    end;
  end;

begin
  RootType          := '';
  DfmComponents     := TDictionary<string, TComponentInfo>.Create;
  PasComponents     := TDictionary<string, TComponentInfo>.Create;
  Results           := TList<TInconsistencyInfo>.Create;
  try
    // Parse DFM for component definitions
    ParseDfmComponents;

    // Parse PAS for field declarations
    ParsePasComponents;

    // Compare: Find components in DFM but not in PAS
    for Key in DfmComponents.Keys do
    begin
      DfmInfo := DfmComponents[ Key ];
      if not PasComponents.TryGetValue( Key, PasInfo ) then
      begin
        Info.UnitName := ChangeFileExt( ExtractFileName( FileName ), '' );
        Info.ComponentName := DfmInfo.Name;
        Info.DfmType := DfmInfo.TypeName;
        Info.PasType := '';
        Info.InconsistencyType := itMissingInPas;
        Info.DfmFileName := ChangeFileExt( FileName, '.dfm' );
        Info.PasFileName := FileName;
        Info.DfmLineNumber := DfmInfo.LineNumber;
        Info.PasLineNumber := 0; // Not in PAS
        Results.Add( Info );
      end
      else
      begin
        // Check type mismatch
        if not SameText( DfmInfo.TypeName, PasInfo.TypeName ) then
        begin
          Info.UnitName := ChangeFileExt( ExtractFileName( FileName ), '' );
          Info.ComponentName := DfmInfo.Name;
          Info.DfmType := DfmInfo.TypeName;
          Info.PasType := PasInfo.TypeName;
          Info.InconsistencyType := itTypeMismatch;
          Info.DfmFileName := ChangeFileExt( FileName, '.dfm' );
          Info.PasFileName := FileName;
          Info.DfmLineNumber := DfmInfo.LineNumber;
          Info.PasLineNumber := PasInfo.LineNumber;
          Results.Add( Info );
        end;
      end;
    end;

    // Compare: Find fields in PAS but not in DFM (only likely component types)
    for Key in PasComponents.Keys do
    begin
      PasInfo := PasComponents[ Key ];
      // Only check if it looks like a component type (starts with T)
      // and is not a common non-component type or dataset field type
      if ( Length( PasInfo.TypeName ) > 1 ) and ( PasInfo.TypeName[ 1 ] = 'T' ) and
        not DfmComponents.ContainsKey( Key ) and
        not IsNonComponentType( PasInfo.TypeName ) and
        not IsDatasetFieldType( PasInfo.TypeName ) then
      begin
        Info.UnitName := ChangeFileExt( ExtractFileName( FileName ), '' );
        Info.ComponentName := PasInfo.Name;
        Info.DfmType := '';
        Info.PasType := PasInfo.TypeName;
        Info.InconsistencyType := itMissingInDfm;
        Info.DfmFileName := ChangeFileExt( FileName, '.dfm' );
        Info.PasFileName := FileName;
        Info.DfmLineNumber := 0; // Not in DFM
        Info.PasLineNumber := PasInfo.LineNumber;
        Results.Add( Info );
      end;
    end;

    Result          := Results.ToArray;
  finally
    DfmComponents.Free;
    PasComponents.Free;
    Results.Free;
  end;
end;

function DfmBytesToText( const DfmBytes: TBytes ): string;
var
  Input, Output     : TMemoryStream;
begin
  if ( Length( DfmBytes ) = 0 ) then
    Exit( '' );

  { Binary ( TPF0 ) and resource-stream ( $FF header, as the designer hands a form out ) resources
    are converted by the RTL; anything else is already text. }
  var bBinary       := ( Length( DfmBytes ) >= 4 ) and ( DfmBytes[ 0 ] = Ord( 'T' ) ) and ( DfmBytes[ 1 ] = Ord( 'P' ) ) and
    ( DfmBytes[ 2 ] = Ord( 'F' ) ) and ( DfmBytes[ 3 ] = Ord( '0' ) );
  { FF FE / FE FF is a UTF-16 text DFM, not a resource stream: DecodeSourceBytes reads it. }
  var bUtf16        := ( Length( DfmBytes ) >= 2 ) and ( ( ( DfmBytes[ 0 ] = $FF ) and ( DfmBytes[ 1 ] = $FE ) ) or
    ( ( DfmBytes[ 0 ] = $FE ) and ( DfmBytes[ 1 ] = $FF ) ) );
  var bResource     := ( not bUtf16 ) and ( DfmBytes[ 0 ] = $FF );
  if ( not ( bBinary or bResource ) ) then
    Exit( string( DecodeSourceBytes( DfmBytes ) ) );

  Input             := TMemoryStream.Create;
  Output            := TMemoryStream.Create;
  try
    Input.WriteBuffer( DfmBytes[ 0 ], Length( DfmBytes ) );
    Input.Position  := 0;
    if bBinary then
      ObjectBinaryToText( Input, Output )
    else
      ObjectResourceToText( Input, Output );
    var Text: TBytes;
    SetLength( Text, Output.Size );
    if ( Output.Size > 0 ) then
      Move( Output.Memory^, Text[ 0 ], Output.Size );
    Result          := string( DecodeSourceBytes( Text ) );
  finally
    Output.Free;
    Input.Free;
  end;
end;

function AnalyseFormUnit( const PasSource: UTF8String; const DfmBytes: TBytes;
  const FileName: string ): TArray<TInconsistencyInfo>;
begin
  Result            := AnalyseFormUnitText( PasSource, DfmBytesToText( DfmBytes ), FileName );
end;

end.

