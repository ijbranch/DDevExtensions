{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit UsesClauseManagerCore;

/// <summary>
/// Pure analysis core for the Uses Clause Manager: builds a database of what each unit exports
/// from its interface section, records which identifiers a unit actually uses in its own interface
/// and implementation sections, and from those two facts decides where each used unit belongs and
/// rewrites the uses clauses accordingly.
/// </summary>
/// <remarks>
/// RTL and <c>DelphiLexer</c> only by design - no ToolsAPI, no VCL and no IDE - so the interesting
/// logic is unit-testable outside the IDE, in the same way as <c>PathCompactorCore</c> and
/// <c>ProjectGroupSorterCore</c>.
///
/// The one thing the IDE knows and this unit does not is which directories to scan, so the caller
/// supplies them to <see cref="TUnitExportsDatabase.BuildFromDirectories"/>. That, and
/// <see cref="TUnitExportsDatabase.ScanSource"/> taking source text rather than a file name, are
/// what keep this unit free of the IDE.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  /// <summary>Identifies which uses-clause section a unit appears in.</summary>
  TUsesSection = ( usInterface, usImplementation );

  /// <summary>Categorises an identifier exported from a unit's interface section.</summary>
  TExportKind = ( ekType, ekProcedure, ekFunction, ekConst, ekVar );

  /// <summary>One identifier exported from a unit's interface section.</summary>
  TUnitExport = record
    /// <summary>The exported identifier name.</summary>
    Identifier: string;
    /// <summary>The kind of declaration (type, procedure, function, const, var).</summary>
    Kind: TExportKind;
  end;

  /// <summary>
  /// Result for a single used unit: where it currently lives, where it should live and why.
  /// The two TStringList fields are owned and must be freed by the caller.
  /// </summary>
  TUnitPlacement = record
    /// <summary>Name of the used unit.</summary>
    UnitName: string;
    /// <summary>Section in which the unit currently appears.</summary>
    CurrentSection: TUsesSection;
    /// <summary>Section the analyser recommends.</summary>
    RecommendedSection: TUsesSection;
    /// <summary>Human-readable explanation of the recommendation.</summary>
    Reason: string;
    /// <summary>Identifiers from this unit detected in the interface section.</summary>
    IdentifiersUsedInInterface: TStringList;
    /// <summary>Identifiers from this unit detected in the implementation section.</summary>
    IdentifiersUsedInImplementation: TStringList;
  end;

  /// <summary>
  /// Database of what identifiers each unit exports. Built by scanning the interface
  /// sections of every .pas file found in the project's search path.
  /// </summary>
  TUnitExportsDatabase = class
  private
    /// <summary>Maps lower-case unit name -&gt; its list of exports.</summary>
    FExports: TDictionary<string, TList<TUnitExport>>;
    /// <summary>Reverse lookup: lower-case identifier -&gt; list of unit names that export it.</summary>
    FIdentifierToUnits: TDictionary<string, TStringList>;
    /// <summary>Priority-ordered list of RTL/VCL units used to break ties when an identifier has many providers.</summary>
    FRTLVCLPriority: TStringList;
    /// <summary>Backing field for <see cref="ProgressFileName"/>.</summary>
    FProgressFileName: string;
    /// <summary>Populates <see cref="FRTLVCLPriority"/> with the standard preferred-unit ordering.</summary>
    procedure BuildRTLVCLPriority;
  public
    /// <summary>Creates an empty database and seeds the RTL/VCL priority list.</summary>
    constructor Create;
    /// <summary>Releases all owned resources.</summary>
    destructor Destroy; override;
    /// <summary>Empties the exports and reverse-lookup dictionaries.</summary>
    procedure Clear;
    /// <summary>Builds the database by scanning every .pas file in each of the supplied directories.</summary>
    /// <param name="ADirectories">Directories to scan, in search order. Entries are trimmed and expanded,
    /// a relative entry against <paramref name="ABaseDirectory"/>; missing and repeated ones are skipped.</param>
    /// <param name="AOnProgress">Optional callback fired per file (read <see cref="ProgressFileName"/> for the current file).</param>
    /// <param name="ABaseDirectory">Directory relative entries are resolved against ( the project's
    /// folder ); empty to resolve them against the process's current directory.</param>
    /// <remarks>The IDE-facing <c>BuildFromSearchPath</c>, which derives these directories from an
    /// <c>IOTAProject</c>, is a class helper in the <c>UsesClauseManager</c> unit. Keeping it there is
    /// what leaves this unit free of ToolsAPI, and therefore testable outside the IDE.  When two
    /// directories hold a unit of the same name, the first one found wins, as it does for the compiler.</remarks>
    procedure BuildFromDirectories( ADirectories: TStrings; AOnProgress: TNotifyEvent; const ABaseDirectory: string = '' );
    /// <summary>Returns the absolute form of one search-path entry.</summary>
    /// <param name="ADirectory">The entry, absolute or relative.</param>
    /// <param name="ABaseDirectory">Directory a relative entry is resolved against; empty for the current directory.</param>
    /// <returns>The expanded directory without a trailing delimiter, or an empty string for a blank entry.</returns>
    class function ResolveDirectory( const ADirectory, ABaseDirectory: string ): string;
    /// <summary>Scans a single unit file and adds its interface exports to the database.</summary>
    /// <param name="UnitPath">Full path of the .pas file. A file that does not exist, that fails to
    /// load, or whose unit name was already scanned, is skipped and reported through
    /// OutputDebugString rather than raising.</param>
    procedure ScanUnit( const UnitPath: string );
    /// <summary>Adds the interface exports of an already-loaded unit source to the database.</summary>
    /// <param name="UnitName">Name to record the exports under, without path or extension.</param>
    /// <param name="UnitPath">Path the lexer reports in diagnostics. Any label will do when the source
    /// did not come from disk.</param>
    /// <param name="Source">UTF-8 source text of the unit.</param>
    /// <remarks>This is the seam the unit tests use: it needs no file on disk.  Only declared names
    /// are recorded: the name starting each type, const and var declaration and each routine's
    /// name, never a parameter, return, field or member.  A second unit of a name already in the
    /// database is skipped and logged, never added.</remarks>
    procedure ScanSource( const UnitName, UnitPath: string; const Source: UTF8String );
    /// <summary>Returns the list of exports for a unit, or nil if the unit was not scanned.</summary>
    /// <param name="UnitName">Unit name, matched case-insensitively.</param>
    /// <returns>The unit's exports, owned by the database, or nil.</returns>
    function GetExports( const UnitName: string ): TList<TUnitExport>;
    /// <summary>Returns the units that export the given identifier, or nil if unknown.</summary>
    /// <param name="Identifier">Identifier, matched case-insensitively.</param>
    /// <returns>The providing units, owned by the database, or nil.</returns>
    function FindUnitsForIdentifier( const Identifier: string ): TStringList;
    /// <summary>Picks the preferred providing unit for an identifier, honouring the RTL/VCL priority list.</summary>
    /// <param name="Identifier">The identifier being resolved.</param>
    /// <param name="CandidateUnits">The units that export it; may be nil.</param>
    /// <returns>The only candidate; else the first whose unqualified name is on the priority list; else the first candidate.
    /// An empty string when there are no candidates.</returns>
    function GetPreferredUnit( const Identifier: string; const CandidateUnits: TStringList ): string;
    /// <summary>Returns the number of units currently held in the database.</summary>
    /// <returns>The number of units scanned into the database.</returns>
    function GetUnitCount: Integer;
    /// <summary>Name of the file currently being scanned (updated for the <c>OnProgress</c> callback).</summary>
    property ProgressFileName: string read FProgressFileName;
    /// <summary>Number of units in the database.</summary>
    property UnitCount: Integer read GetUnitCount;
  end;

  /// <summary>One reference to a unit appearing in a uses clause, along with its line number.</summary>
  TUsedUnitInfo = record
    /// <summary>Name of the unit (may include dotted prefixes).</summary>
    UnitName: string;
    /// <summary>The section (interface/implementation) in which the unit was used.</summary>
    Section: TUsesSection;
    /// <summary>Source line number of the unit reference.</summary>
    LineNumber: Integer;
  end;

  /// <summary>
  /// Tokenises a unit's source and records which identifiers are used in the interface
  /// vs implementation sections, plus any qualified references (UnitName.Identifier).
  /// </summary>
  TIdentifierUsageAnalyzer = class
  private
    /// <summary>Identifiers seen in the interface section.</summary>
    FInterfaceIdentifiers: TStringList;
    /// <summary>Identifiers seen in the implementation section.</summary>
    FImplementationIdentifiers: TStringList;
    /// <summary>Qualified references: lower-case identifier -&gt; the qualifying unit name.</summary>
    FQualifiedReferences: TDictionary<string, string>;
    /// <summary>Units listed in the interface uses clause.</summary>
    FInterfaceUsedUnits: TList<TUsedUnitInfo>;
    /// <summary>Units listed in the implementation uses clause.</summary>
    FImplementationUsedUnits: TList<TUsedUnitInfo>;
  public
    /// <summary>Creates the analyser with empty result collections.</summary>
    constructor Create;
    /// <summary>Releases all owned collections.</summary>
    destructor Destroy; override;
    /// <summary>Tokenises the supplied source and populates all result properties.</summary>
    /// <param name="Source">UTF-8 source code of a single Pascal unit.</param>
    procedure Analyze( const Source: UTF8String );
    /// <summary>Clears all collected identifiers and unit references.</summary>
    procedure Clear;
    /// <summary>Identifiers detected in the interface section of the analysed source.</summary>
    property InterfaceIdentifiers: TStringList read FInterfaceIdentifiers;
    /// <summary>Identifiers detected in the implementation section of the analysed source.</summary>
    property ImplementationIdentifiers: TStringList read FImplementationIdentifiers;
    /// <summary>Map of identifier -&gt; qualifying unit for "Unit.Identifier" references.</summary>
    property QualifiedReferences: TDictionary<string, string> read FQualifiedReferences;
    /// <summary>Units found in the interface uses clause.</summary>
    property InterfaceUsedUnits: TList<TUsedUnitInfo> read FInterfaceUsedUnits;
    /// <summary>Units found in the implementation uses clause.</summary>
    property ImplementationUsedUnits: TList<TUsedUnitInfo> read FImplementationUsedUnits;
  end;

  /// <summary>
  /// One text edit of a uses clause: <see cref="DeleteCount"/> bytes at byte offset
  /// <see cref="Offset"/> of the UTF-8 source are replaced by <see cref="Text"/>.
  /// </summary>
  /// <remarks>Offsets are 0-based UTF-8 byte offsets into the ORIGINAL source, which is what an
  /// <c>IOTAEditWriter</c> takes, so a list sorted by offset can be replayed through one writer
  /// ( CopyTo, DeleteTo, Insert ) without touching any other part of the buffer.</remarks>
  TUsesEdit = record
    /// <summary>0-based byte offset of the first byte replaced ( or of the insertion point ).</summary>
    Offset: Integer;
    /// <summary>Number of bytes removed at <see cref="Offset"/>; 0 for a pure insertion.</summary>
    DeleteCount: Integer;
    /// <summary>UTF-8 text inserted at <see cref="Offset"/>; empty for a pure deletion.</summary>
    Text: UTF8String;
  end;

  /// <summary>
  /// Combines the exports database and a usage analyser to compute placement
  /// recommendations for each used unit and to rewrite the source's uses clauses.
  /// </summary>
  TUsesClauseRefactorer = class
  private
    /// <summary>Reference to the project-wide exports database (not owned).</summary>
    FExportsDB: TUnitExportsDatabase;
    /// <summary>Owned analyser used to inspect the source.</summary>
    FUsageAnalyzer: TIdentifierUsageAnalyzer;
    /// <summary>True when an identifier used by the analysed source comes from the named used unit.</summary>
    /// <param name="AIdentifier">The identifier, as the source spells it.</param>
    /// <param name="AUnitName">The used unit's name as the uses clause spells it ( may be dotted ).</param>
    /// <param name="ALeafName">The last part of a dotted unit name; the name itself when undotted.</param>
    /// <returns>True when a qualified reference names the unit, or, without one, when the unit
    /// declares the identifier in its interface.</returns>
    function IdentifierComesFrom( const AIdentifier, AUnitName, ALeafName: string ): Boolean;
    /// <summary>Returns the exports of a used unit, looked up by its full and then its leaf name.</summary>
    /// <param name="AUnitName">The used unit's name as the uses clause spells it.</param>
    /// <param name="ALeafName">The last part of a dotted unit name.</param>
    /// <returns>The unit's exports, or nil when the database does not know it.</returns>
    function ExportsOfUsedUnit( const AUnitName, ALeafName: string ): TList<TUnitExport>;
  public
    /// <summary>Creates a refactorer that consults the supplied exports database.</summary>
    /// <param name="AExportsDB">Database to consult; not owned by this instance.</param>
    constructor Create( AExportsDB: TUnitExportsDatabase );
    /// <summary>Releases the owned analyser.</summary>
    destructor Destroy; override;
    /// <summary>Analyses the source and returns one <see cref="TUnitPlacement"/> per used unit.</summary>
    /// <remarks>The caller takes ownership of the TStringList fields inside each returned record.</remarks>
    /// <returns>One placement per unit in either uses clause.</returns>
    /// <param name="Source">The unit's source as UTF-8.</param>
    function Analyze( const Source: UTF8String ): TArray<TUnitPlacement>;
    /// <summary>
    /// Plans the uses-clause edits that move every unit whose placement differs from its current
    /// section, entry by entry: the entry's own text ( a dotted name, an <c>in '...'</c> path ) is
    /// moved, and every other part of both clauses - comments, compiler directives, layout - is kept.
    /// </summary>
    /// <param name="Source">UTF-8 source the placements were computed from.</param>
    /// <param name="Placements">Placements; those with CurrentSection &lt;&gt; RecommendedSection move.</param>
    /// <param name="Edits">On success, the edits sorted by offset, non-overlapping; empty when nothing moves.</param>
    /// <param name="ErrorMessage">On refusal, why the source cannot be edited safely.</param>
    /// <returns>True with the edits, or False ( and no edits ) when the clause shape cannot be edited
    /// safely: a moved unit inside a conditional block or missing from the source, a deletion that
    /// would swallow a comment or directive, or a clause whose conditional blocks do not balance.</returns>
    function PlanMoves( const Source: UTF8String; const Placements: TArray<TUnitPlacement>;
      out Edits: TArray<TUsesEdit>; out ErrorMessage: string ): Boolean;
    /// <summary>Applies planned edits to a copy of the source.</summary>
    /// <param name="Source">The source the edits were planned against.</param>
    /// <param name="Edits">Edits sorted by offset, as <see cref="PlanMoves"/> returns them.</param>
    /// <returns>The edited source.</returns>
    class function ApplyEdits( const Source: UTF8String; const Edits: TArray<TUsesEdit> ): UTF8String;
    /// <summary>Returns a rewritten copy of <paramref name="Source"/> with uses clauses adjusted to match the placements.</summary>
    /// <param name="Source">UTF-8 source the placements were computed from.</param>
    /// <param name="Placements">Placements; those with CurrentSection &lt;&gt; RecommendedSection move.</param>
    /// <param name="ErrorMessage">Empty on success; on refusal, why the source was left unchanged.</param>
    /// <returns>The rewritten source, or <paramref name="Source"/> itself when nothing moves or the
    /// edit was refused.</returns>
    function GenerateRefactoredSource( const Source: UTF8String;
      const Placements: TArray<TUnitPlacement>; out ErrorMessage: string ): UTF8String; overload;
    /// <summary>As the three-parameter overload, discarding the refusal reason.</summary>
    /// <param name="Source">UTF-8 source the placements were computed from.</param>
    /// <param name="Placements">Placements; those with CurrentSection &lt;&gt; RecommendedSection move.</param>
    /// <returns>The rewritten source, or <paramref name="Source"/> unchanged.</returns>
    function GenerateRefactoredSource( const Source: UTF8String;
      const Placements: TArray<TUnitPlacement> ): UTF8String; overload;
  end;

implementation

uses
  Winapi.Windows, System.Generics.Defaults, DelphiLexer;

{ TUnitExportsDatabase }

constructor TUnitExportsDatabase.Create;
begin
  inherited Create;
  FExports := TDictionary<string, TList<TUnitExport>>.Create;
  FIdentifierToUnits := TDictionary<string, TStringList>.Create;
  FRTLVCLPriority := TStringList.Create;
  FRTLVCLPriority.CaseSensitive := False;
  BuildRTLVCLPriority;
end;

destructor TUnitExportsDatabase.Destroy;
begin
  Clear;
  FExports.Free;
  FIdentifierToUnits.Free;
  FRTLVCLPriority.Free;
  inherited Destroy;
end;

procedure TUnitExportsDatabase.BuildRTLVCLPriority;
begin
  // RTL/VCL units in priority order - these take precedence when
  // the same identifier is exported by multiple units
  FRTLVCLPriority.Add( 'System' );
  FRTLVCLPriority.Add( 'SysUtils' );
  FRTLVCLPriority.Add( 'Classes' );
  FRTLVCLPriority.Add( 'Types' );
  FRTLVCLPriority.Add( 'TypInfo' );
  FRTLVCLPriority.Add( 'Windows' );
  FRTLVCLPriority.Add( 'Messages' );
  FRTLVCLPriority.Add( 'Vcl.Forms' );
  FRTLVCLPriority.Add( 'Forms' );
  FRTLVCLPriority.Add( 'Vcl.Controls' );
  FRTLVCLPriority.Add( 'Controls' );
  FRTLVCLPriority.Add( 'Vcl.StdCtrls' );
  FRTLVCLPriority.Add( 'StdCtrls' );
  FRTLVCLPriority.Add( 'Vcl.ExtCtrls' );
  FRTLVCLPriority.Add( 'ExtCtrls' );
  FRTLVCLPriority.Add( 'Vcl.Graphics' );
  FRTLVCLPriority.Add( 'Graphics' );
  FRTLVCLPriority.Add( 'Vcl.Dialogs' );
  FRTLVCLPriority.Add( 'Dialogs' );
  FRTLVCLPriority.Add( 'Vcl.Menus' );
  FRTLVCLPriority.Add( 'Menus' );
  FRTLVCLPriority.Add( 'Vcl.ComCtrls' );
  FRTLVCLPriority.Add( 'ComCtrls' );
  FRTLVCLPriority.Add( 'Vcl.Grids' );
  FRTLVCLPriority.Add( 'Grids' );
  FRTLVCLPriority.Add( 'Data.DB' );
  FRTLVCLPriority.Add( 'DB' );
  FRTLVCLPriority.Add( 'Generics.Collections' );
  FRTLVCLPriority.Add( 'Generics.Defaults' );
  FRTLVCLPriority.Add( 'System.IOUtils' );
  FRTLVCLPriority.Add( 'System.JSON' );
  FRTLVCLPriority.Add( 'System.RegularExpressions' );
end;

procedure TUnitExportsDatabase.Clear;
var
  Pair: TPair<string, TList<TUnitExport>>;
  Pair2: TPair<string, TStringList>;
begin
  for Pair in FExports do
    Pair.Value.Free;
  FExports.Clear;

  for Pair2 in FIdentifierToUnits do
    Pair2.Value.Free;
  FIdentifierToUnits.Clear;
end;

procedure TUnitExportsDatabase.ScanUnit( const UnitPath: string );
var
  Source: UTF8String;
begin
  if not FileExists( UnitPath ) then
    Exit;

  // The first unit of a name found on the search path is the one the compiler uses; a later
  // one of the same name is not read at all.
  if FExports.ContainsKey( LowerCase( ChangeFileExt( ExtractFileName( UnitPath ), '' ) ) ) then
  begin
    OutputDebugString( PChar( Format( 'UsesClauseManager: skipped %s - a unit of that name was found earlier on the path',
      [ UnitPath ] ) ) );
    Exit;
  end;

  try
    Source := LoadTextFileToUtf8String( UnitPath, 0 );
  except
    on E: Exception do
    begin
      // Do not swallow silently: a file that fails to load is dropped from the
      // export database and degrades later placement analysis, so log it.
      OutputDebugString( PChar( Format( 'UsesClauseManager: skipped %s - %s: %s',
        [ UnitPath, E.ClassName, E.Message ] ) ) );
      Exit;
    end;
  end;

  ScanSource( ChangeFileExt( ExtractFileName( UnitPath ), '' ), UnitPath, Source );
end;

procedure TUnitExportsDatabase.ScanSource( const UnitName, UnitPath: string;
  const Source: UTF8String );
type
  TScanSection = ( ssNone, ssType, ssConst, ssVar );
var
  Lexer: TDelphiLexer;
  Token: TToken;
  Sig: TList<TToken>;
  InInterface: Boolean;
  Section: TScanSection;
  P: Integer;
  ExportList: TList<TUnitExport>;
  UnitList: TStringList;
  LowerIdent: string;
  Stored: Boolean;

  function Kind( AIndex: Integer ): TTokenKind;
  begin
    if ( AIndex >= 0 ) and ( AIndex < Sig.Count ) then
      Result := Sig[ AIndex ].Kind
    else
      Result := tkNone;
  end;

  procedure AddExport( const AIdentifier: string; AKind: TExportKind );
  var
    Item: TUnitExport;
  begin
    Item.Identifier := AIdentifier;
    Item.Kind := AKind;
    ExportList.Add( Item );
  end;

  // AIndex is on AOpen; returns the index after the matching AClose.
  function SkipPair( AIndex: Integer; AOpen, AClose: TTokenKind ): Integer;
  var
    Depth: Integer;
  begin
    Depth := 0;
    Result := AIndex;
    while Result < Sig.Count do
    begin
      if Kind( Result ) = AOpen then
        Inc( Depth )
      else if Kind( Result ) = AClose then
      begin
        Dec( Depth );
        if Depth = 0 then
          Exit( Result + 1 );
      end;
      Inc( Result );
    end;
  end;

  // AIndex is just after a routine keyword; returns the index of the ";" ending the header.
  function SkipHeader( AIndex: Integer ): Integer;
  begin
    Result := AIndex;
    while ( Result < Sig.Count ) and ( Kind( Result ) <> tkSemicolon ) do
      if Kind( Result ) = tkLParan then
        Result := SkipPair( Result, tkLParan, tkRParan )
      else
        Inc( Result );
  end;

  // True when "record" at AIndex opens a body ( not the generic constraint "<T: record>" ).
  function IsRecordBody( AIndex: Integer ): Boolean;
  begin
    Result := ( Kind( AIndex ) = tkI_record ) and not ( Kind( AIndex + 1 ) in [ tkGreaterThan, tkComma, tkSemicolon ] );
  end;

  // True when the structured-type keyword at AIndex follows "=" or "= packed".
  function FollowsEqual( AIndex: Integer ): Boolean;
  begin
    Result := ( Kind( AIndex - 1 ) = tkEqual ) or ( ( Kind( AIndex - 1 ) = tkI_packed ) and ( Kind( AIndex - 2 ) = tkEqual ) );
  end;

  // AIndex is on class / object / interface / dispinterface / record after "=".  Returns the
  // index after the body's "end", or of the token ending a body-less declaration.
  function SkipTypeBody( AIndex: Integer ): Integer;
  var
    Depth: Integer;
  begin
    Result := AIndex + 1;
    if Kind( AIndex ) <> tkI_record then
    begin
      if ( Kind( AIndex ) = tkI_class ) and ( Kind( Result ) = tkI_of ) then
        Exit; // "class of TFoo"
      // Modifiers: sealed, abstract, "helper for TType".
      while ( ( Kind( Result ) >= tkIdent ) and ( Kind( Result ) < tkIdentStrictReserved ) ) or ( Kind( Result ) in [ tkI_for, tkQualifier ] ) do
      begin
        if Kind( Result + 1 ) = tkColon then
          Break; // A field directly after "class": the body has started.
        Inc( Result );
      end;
      if Kind( Result ) = tkLParan then
        Result := SkipPair( Result, tkLParan, tkRParan );
      if Kind( Result ) = tkSemicolon then
        Exit; // Forward declaration or "TFoo = class( TBar );"
    end;

    Depth := 1;
    while Result < Sig.Count do
    begin
      case Kind( Result ) of
        tkLParan:
          begin
            Result := SkipPair( Result, tkLParan, tkRParan );
            Continue;
          end;
        tkLBracket:
          begin
            Result := SkipPair( Result, tkLBracket, tkRBracket );
            Continue;
          end;
        tkI_end:
          begin
            Dec( Depth );
            if Depth = 0 then
              Exit( Result + 1 );
          end;
        tkI_record:
          if IsRecordBody( Result ) and not FollowsEqual( Result ) then
            Inc( Depth ); // An anonymous record field type.
      end;
      if ( Kind( Result ) in [ tkI_class, tkI_object, tkI_interface, tkI_dispinterface, tkI_record ] ) and FollowsEqual( Result ) then
      begin
        // A nested type declaration with a body of its own.
        Result := SkipTypeBody( Result );
        Continue;
      end;
      Inc( Result );
    end;
  end;

  // True when the identifier at AIndex starts a declaration of the current section.
  function IsDeclarationStart( AIndex: Integer ): Boolean;
  begin
    case Kind( AIndex - 1 ) of
      tkNone, tkSemicolon, tkRBracket, tkI_type, tkI_const, tkI_resourcestring, tkI_var, tkI_threadvar:
        Result := True;
      tkComma:
        Result := Section = ssVar; // "A, B: Integer;"
    else
      Result := False;
    end;
  end;

  // AIndex is on "(" of an enumerated type; exports each value and returns the index after ")".
  // A unit's enumeration values are as much its exports as its types: an interface that uses
  // only [fsBold] needs Vcl.Graphics.
  function ExportEnumValues( AIndex: Integer ): Integer;
  var
    Depth: Integer;
  begin
    Depth := 0;
    Result := AIndex;
    while Result < Sig.Count do
    begin
      case Kind( Result ) of
        tkLParan:
          Inc( Depth );
        tkRParan:
          begin
            Dec( Depth );
            if Depth = 0 then
              Exit( Result + 1 );
          end;
        tkIdent:
          // A value name follows "(" or "," at the enumeration's own level ( not "= Expression" ).
          if ( Depth = 1 ) and ( Kind( Result - 1 ) in [ tkLParan, tkComma ] ) then
            AddExport( Sig[ Result ].Value, ekConst );
      end;
      Inc( Result );
    end;
  end;

  // AIndex is on a declared type name; returns the index to resume scanning at.
  function SkipTypeDeclaration( AIndex: Integer ): Integer;
  begin
    Result := AIndex + 1;
    if Kind( Result ) = tkLessThan then
      Result := SkipPair( Result, tkLessThan, tkGreaterThan );
    if Kind( Result ) <> tkEqual then
      Exit;
    Inc( Result );
    if Kind( Result ) = tkI_packed then
      Inc( Result );
    if Kind( Result ) = tkLParan then
      Result := ExportEnumValues( Result )
    else if Kind( Result ) in [ tkI_class, tkI_object, tkI_interface, tkI_dispinterface, tkI_record ] then
      Result := SkipTypeBody( Result );
  end;

begin
  // The first unit of a name is the one the compiler finds; a second one is reported and skipped,
  // never added twice ( which raised EListError into the IDE ).
  if FExports.ContainsKey( LowerCase( UnitName ) ) then
  begin
    OutputDebugString( PChar( Format( 'UsesClauseManager: skipped %s - a unit named %s was already scanned',
      [ UnitPath, UnitName ] ) ) );
    Exit;
  end;

  Stored := False;
  ExportList := TList<TUnitExport>.Create;
  Sig := TList<TToken>.Create;
  try
    Lexer := TDelphiLexer.Create( UnitPath, Source );
    try
      // The interface section's significant tokens.  The lexer owns them, so they are used
      // before it is freed.
      InInterface := False;
      while Lexer.NextToken( Token ) do
      begin
        if Token.Kind in [ tkComment, tkDirective ] then
          Continue;
        if not InInterface then
        begin
          InInterface := Token.Kind = tkI_interface;
          Continue;
        end;
        if Token.Kind = tkI_implementation then
          Break;
        Sig.Add( Token );
      end;

      { Only DECLARED names are exports: the name that starts each declaration of a type, const or
        var section, and each routine's name.  Everything inside parentheses, brackets and type
        bodies is skipped, so a parameter type, a return type, a field type or a member name is
        never recorded.  "FCount: Integer" inside a class used to export Integer, which made the
        placement analysis believe any unit with an Integer field provided Integer. }
      Section := ssNone;
      P := 0;
      while P < Sig.Count do
      begin
        case Kind( P ) of
          tkLParan:
            begin
              P := SkipPair( P, tkLParan, tkRParan );
              Continue;
            end;
          tkLBracket:
            begin
              P := SkipPair( P, tkLBracket, tkRBracket );
              Continue;
            end;
          tkI_type:
            Section := ssType;
          tkI_const, tkI_resourcestring:
            Section := ssConst;
          tkI_var, tkI_threadvar:
            Section := ssVar;
          tkI_uses:
            begin
              Section := ssNone;
              while ( P < Sig.Count ) and ( Kind( P ) <> tkSemicolon ) do
                Inc( P );
            end;
          tkI_record:
            if IsRecordBody( P ) then
            begin
              // An anonymous record type of a var or typed constant.
              P := SkipTypeBody( P );
              Continue;
            end;
          tkI_procedure, tkI_function:
            begin
              if Kind( P - 1 ) in [ tkEqual, tkColon, tkI_to, tkI_of ] then
              begin
                // A procedural type ( "= procedure", "reference to function", ": procedure" ).
                P := SkipHeader( P + 1 );
                Continue;
              end;
              Section := ssNone;
              if Kind( P + 1 ) = tkIdent then
                if Kind( P ) = tkI_procedure then
                  AddExport( Sig[ P + 1 ].Value, ekProcedure )
                else
                  AddExport( Sig[ P + 1 ].Value, ekFunction );
              P := SkipHeader( P + 1 );
              Continue;
            end;
          tkIdent:
            if ( Section <> ssNone ) and IsDeclarationStart( P ) then
              case Section of
                ssType:
                  begin
                    AddExport( Sig[ P ].Value, ekType );
                    P := SkipTypeDeclaration( P );
                    Continue;
                  end;
                ssConst:
                  AddExport( Sig[ P ].Value, ekConst );
                ssVar:
                  AddExport( Sig[ P ].Value, ekVar );
              end;
        end;
        Inc( P );
      end;
    finally
      Lexer.Free;
    end;

    // Store in exports dictionary
    if ExportList.Count > 0 then
    begin
      FExports.Add( LowerCase( UnitName ), ExportList );
      Stored := True;

      // Build reverse lookup
      for var Item in ExportList do
      begin
        LowerIdent := LowerCase( Item.Identifier );
        if not FIdentifierToUnits.TryGetValue( LowerIdent, UnitList ) then
        begin
          UnitList := TStringList.Create;
          UnitList.CaseSensitive := False;
          UnitList.Duplicates := dupIgnore;
          FIdentifierToUnits.Add( LowerIdent, UnitList );
        end;
        UnitList.Add( UnitName );
      end;
    end;
  finally
    Sig.Free;
    if not Stored then
      ExportList.Free;
  end;
end;

procedure TUnitExportsDatabase.BuildFromDirectories( ADirectories: TStrings;
  AOnProgress: TNotifyEvent; const ABaseDirectory: string );
var
  I: Integer;
  SR: TSearchRec;
  Path: string;
  Seen: TStringList;
begin
  Clear;

  if ADirectories = nil then
    Exit;

  Seen := TStringList.Create;
  try
    Seen.CaseSensitive := False;
    Seen.Sorted := True;

    // Scan all .pas files in the supplied directories, in order: the first unit of a name wins.
    for I := 0 to ADirectories.Count - 1 do
    begin
      Path := ResolveDirectory( ADirectories[ I ], ABaseDirectory );
      if ( Path = '' ) or not DirectoryExists( Path ) then
        Continue;
      // A directory listed twice ( Base and configuration search paths concatenated ) is scanned once.
      if Seen.IndexOf( Path ) >= 0 then
        Continue;
      Seen.Add( Path );

      if FindFirst( IncludeTrailingPathDelimiter( Path ) + '*.pas', faAnyFile, SR ) = 0 then
      try
        repeat
          FProgressFileName := SR.Name;
          if Assigned( AOnProgress ) then
            AOnProgress( Self );

          ScanUnit( IncludeTrailingPathDelimiter( Path ) + SR.Name );
        until FindNext( SR ) <> 0;
      finally
        // Qualified: Winapi.Windows also exports FindClose, taking a THandle, and it is in
        // this unit's implementation uses clause - so an unqualified call resolves to the
        // wrong overload. The original unit was shielded by its uses-clause order.
        System.SysUtils.FindClose( SR );
      end;
    end;
  finally
    Seen.Free;
  end;
end;

class function TUnitExportsDatabase.ResolveDirectory( const ADirectory, ABaseDirectory: string ): string;
begin
  Result := Trim( ADirectory );
  if Result = '' then
    Exit;
  // A relative search-path entry is relative to the project, not to the IDE's current directory.
  if ( ABaseDirectory <> '' ) and ( ExtractFileDrive( Result ) = '' ) and not Result.StartsWith( PathDelim ) then
    Result := IncludeTrailingPathDelimiter( ABaseDirectory ) + Result;
  Result := ExcludeTrailingPathDelimiter( ExpandFileName( Result ) );
end;

function TUnitExportsDatabase.GetExports( const UnitName: string ): TList<TUnitExport>;
begin
  if not FExports.TryGetValue( LowerCase( UnitName ), Result ) then
    Result := nil;
end;

function TUnitExportsDatabase.FindUnitsForIdentifier( const Identifier: string ): TStringList;
begin
  if not FIdentifierToUnits.TryGetValue( LowerCase( Identifier ), Result ) then
    Result := nil;
end;

function TUnitExportsDatabase.GetPreferredUnit( const Identifier: string;
  const CandidateUnits: TStringList ): string;
var
  I, J: Integer;
  LowerUnit: string;
  CandLeaf: string;
begin
  Result := '';
  if ( CandidateUnits = nil ) or ( CandidateUnits.Count = 0 ) then
    Exit;

  if CandidateUnits.Count = 1 then
  begin
    Result := CandidateUnits[ 0 ];
    Exit;
  end;

  // Check RTL/VCL priority list. The priority entries are dotted (e.g.
  // 'Vcl.Forms') while the candidate reverse-lookup names are bare file names
  // (e.g. 'Forms'), so compare on the unqualified leaf name on both sides.
  for I := 0 to FRTLVCLPriority.Count - 1 do
  begin
    LowerUnit := LowerCase( FRTLVCLPriority[ I ] );
    if Pos( '.', LowerUnit ) > 0 then
      LowerUnit := Copy( LowerUnit, LastDelimiter( '.', LowerUnit ) + 1, MaxInt );

    for J := 0 to CandidateUnits.Count - 1 do
    begin
      CandLeaf := LowerCase( CandidateUnits[ J ] );
      if Pos( '.', CandLeaf ) > 0 then
        CandLeaf := Copy( CandLeaf, LastDelimiter( '.', CandLeaf ) + 1, MaxInt );

      if CandLeaf = LowerUnit then
      begin
        Result := CandidateUnits[ J ];
        Exit;
      end;
    end;
  end;

  // Default to first candidate
  Result := CandidateUnits[ 0 ];
end;

function TUnitExportsDatabase.GetUnitCount: Integer;
begin
  Result := FExports.Count;
end;

{ TIdentifierUsageAnalyzer }

constructor TIdentifierUsageAnalyzer.Create;
begin
  inherited Create;
  FInterfaceIdentifiers := TStringList.Create;
  FInterfaceIdentifiers.CaseSensitive := False;
  FInterfaceIdentifiers.Sorted := True;
  FInterfaceIdentifiers.Duplicates := dupIgnore;

  FImplementationIdentifiers := TStringList.Create;
  FImplementationIdentifiers.CaseSensitive := False;
  FImplementationIdentifiers.Sorted := True;
  FImplementationIdentifiers.Duplicates := dupIgnore;

  FQualifiedReferences := TDictionary<string, string>.Create;
  FInterfaceUsedUnits := TList<TUsedUnitInfo>.Create;
  FImplementationUsedUnits := TList<TUsedUnitInfo>.Create;
end;

destructor TIdentifierUsageAnalyzer.Destroy;
begin
  FInterfaceIdentifiers.Free;
  FImplementationIdentifiers.Free;
  FQualifiedReferences.Free;
  FInterfaceUsedUnits.Free;
  FImplementationUsedUnits.Free;
  inherited Destroy;
end;

procedure TIdentifierUsageAnalyzer.Clear;
begin
  FInterfaceIdentifiers.Clear;
  FImplementationIdentifiers.Clear;
  FQualifiedReferences.Clear;
  FInterfaceUsedUnits.Clear;
  FImplementationUsedUnits.Clear;
end;

procedure TIdentifierUsageAnalyzer.Analyze( const Source: UTF8String );
var
  Lexer: TDelphiLexer;
  Token, NextToken: TToken;
  InInterface, InImplementation: Boolean;
  InUses: Boolean;
  CurrentIdentList: TStringList;
  CurrentUnitList: TList<TUsedUnitInfo>;
  UsedUnit: TUsedUnitInfo;
  PrevIdentifier: string;
  TokenList: TList<TToken>;
  I: Integer;
begin
  Clear;

  // First pass: collect all tokens
  // IMPORTANT: TToken is a class owned by the lexer - don't free lexer until done!
  TokenList := TList<TToken>.Create;
  Lexer := TDelphiLexer.Create( '', Source );
  try
    while Lexer.NextToken( Token ) do
    begin
      // Skip comments but keep directives for tracking
      if Token.Kind = tkComment then
        Continue;
      TokenList.Add( Token );
    end;

    // Second pass: analyze tokens (must be inside lexer's try block)
    InInterface := False;
    InImplementation := False;
    InUses := False;
    CurrentIdentList := nil;
    CurrentUnitList := nil;
    PrevIdentifier := '';
    I := 0;

    while I < TokenList.Count do
    begin
      Token := TokenList[ I ];

      // Skip directives
      if Token.Kind = tkDirective then
      begin
        Inc( I );
        Continue;
      end;

      // Track sections
      // Only the first "interface" is the section keyword: a later one is a type ( IFoo = interface ),
      // and one in the implementation section used to switch the analyser back to the interface.
      if ( Token.Kind = tkI_interface ) and not InInterface and not InImplementation and
         not ( ( I > 0 ) and ( TokenList[ I - 1 ].Kind in [ tkEqual, tkI_packed ] ) ) then
      begin
        InInterface := True;
        InImplementation := False;
        CurrentIdentList := FInterfaceIdentifiers;
        CurrentUnitList := FInterfaceUsedUnits;
        Inc( I );
        Continue;
      end;

      if Token.Kind = tkI_implementation then
      begin
        InInterface := False;
        InImplementation := True;
        CurrentIdentList := FImplementationIdentifiers;
        CurrentUnitList := FImplementationUsedUnits;
        Inc( I );
        Continue;
      end;

      // Track uses clauses - extract unit names
      if Token.Kind = tkI_uses then
      begin
        InUses := True;
        Inc( I );
        Continue;
      end;

      if InUses then
      begin
        if Token.Kind = tkSemicolon then
        begin
          InUses := False;
          Inc( I );
          Continue;
        end;

        // Collect unit names in uses clause
        if ( Token.Kind = tkIdent ) and ( CurrentUnitList <> nil ) then
        begin
          UsedUnit.UnitName := Token.Value;

          // Handle dotted unit names (e.g., System.SysUtils)
          while ( I + 2 < TokenList.Count ) and ( TokenList[ I + 1 ].Kind = tkDot ) do
          begin
            UsedUnit.UnitName := UsedUnit.UnitName + '.' + TokenList[ I + 2 ].Value;
            Inc( I, 2 );
          end;

          if InInterface and not InImplementation then
            UsedUnit.Section := usInterface
          else
            UsedUnit.Section := usImplementation;

          UsedUnit.LineNumber := Token.Line;
          CurrentUnitList.Add( UsedUnit );
        end;

        Inc( I );
        Continue;
      end;

      // Collect identifiers outside of uses clauses
      if ( CurrentIdentList <> nil ) and ( Token.Kind = tkIdent ) then
      begin
        // Check for qualified reference: Identifier.Something
        if ( I + 1 < TokenList.Count ) and ( TokenList[ I + 1 ].Kind = tkDot ) then
        begin
          // This might be a qualified reference like SysUtils.Format
          // Record it as a qualified reference
          if I + 2 < TokenList.Count then
          begin
            NextToken := TokenList[ I + 2 ];
            if NextToken.Kind = tkIdent then
            begin
              // Record: NextToken.Value came from Token.Value unit
              FQualifiedReferences.AddOrSetValue( LowerCase( NextToken.Value ), Token.Value );
            end;
          end;

          // Also add the unit name itself as a used identifier
          CurrentIdentList.Add( Token.Value );
        end
        else
        begin
          // Regular identifier - add it
          CurrentIdentList.Add( Token.Value );
        end;
      end;

      Inc( I );
    end;
  finally
    TokenList.Free;
    Lexer.Free;  // Free lexer AFTER processing all tokens
  end;
end;

{ TUsesClauseRefactorer }

constructor TUsesClauseRefactorer.Create( AExportsDB: TUnitExportsDatabase );
begin
  inherited Create;
  FExportsDB := AExportsDB;
  FUsageAnalyzer := TIdentifierUsageAnalyzer.Create;
end;

destructor TUsesClauseRefactorer.Destroy;
begin
  FUsageAnalyzer.Free;
  inherited Destroy;
end;

function TUsesClauseRefactorer.ExportsOfUsedUnit( const AUnitName, ALeafName: string ): TList<TUnitExport>;
begin
  Result := FExportsDB.GetExports( AUnitName );
  if ( Result = nil ) and not SameText( AUnitName, ALeafName ) then
    Result := FExportsDB.GetExports( ALeafName );
end;

function TUsesClauseRefactorer.IdentifierComesFrom( const AIdentifier, AUnitName, ALeafName: string ): Boolean;
var
  Qualifier: string;
begin
  // The caller has established that the unit declares AIdentifier; only a qualified reference to
  // another unit ( Other.AIdentifier ) says the source means someone else's.
  if FUsageAnalyzer.QualifiedReferences.TryGetValue( LowerCase( AIdentifier ), Qualifier ) then
    Result := SameText( Qualifier, AUnitName ) or SameText( Qualifier, ALeafName )
  else
    Result := True;
end;

function TUsesClauseRefactorer.Analyze( const Source: UTF8String ): TArray<TUnitPlacement>;
var
  ResultList: TList<TUnitPlacement>;
  UsedUnit: TUsedUnitInfo;
  Placement: TUnitPlacement;
  LeafName: string;
  UsedInInterface, UsedInImplementation: Boolean;

  // Records in Placement which identifiers of the unit each section uses.  The same rule serves
  // a unit of either clause, so an implementation-clause unit is no longer judged by a bare name
  // match that ignored qualified references.
  procedure CollectUsage( const AUnitName: string );
  var
    I: Integer;
    UnitExports: TList<TUnitExport>;
  begin
    // Qualified references to the unit itself ( SysUtils.Format ).
    for I := 0 to FUsageAnalyzer.InterfaceIdentifiers.Count - 1 do
      if SameText( FUsageAnalyzer.InterfaceIdentifiers[ I ], AUnitName ) or
         SameText( FUsageAnalyzer.InterfaceIdentifiers[ I ], LeafName ) then
      begin
        UsedInInterface := True;
        Placement.IdentifiersUsedInInterface.Add( '(qualified reference)' );
      end;
    for I := 0 to FUsageAnalyzer.ImplementationIdentifiers.Count - 1 do
      if SameText( FUsageAnalyzer.ImplementationIdentifiers[ I ], AUnitName ) or
         SameText( FUsageAnalyzer.ImplementationIdentifiers[ I ], LeafName ) then
      begin
        UsedInImplementation := True;
        Placement.IdentifiersUsedInImplementation.Add( '(qualified reference)' );
      end;

    UnitExports := ExportsOfUsedUnit( AUnitName, LeafName );
    if UnitExports = nil then
      Exit;
    for var Item in UnitExports do
    begin
      if ( FUsageAnalyzer.InterfaceIdentifiers.IndexOf( Item.Identifier ) >= 0 ) and
         IdentifierComesFrom( Item.Identifier, AUnitName, LeafName ) then
      begin
        UsedInInterface := True;
        Placement.IdentifiersUsedInInterface.Add( Item.Identifier );
      end;
      if ( FUsageAnalyzer.ImplementationIdentifiers.IndexOf( Item.Identifier ) >= 0 ) and
         IdentifierComesFrom( Item.Identifier, AUnitName, LeafName ) then
      begin
        UsedInImplementation := True;
        Placement.IdentifiersUsedInImplementation.Add( Item.Identifier );
      end;
    end;
  end;

begin
  // Step 1: Analyze the source to extract uses clauses and identifier usage
  FUsageAnalyzer.Analyze( Source );

  ResultList := TList<TUnitPlacement>.Create;
  try
    // Step 2: For each unit in the interface uses clause, determine optimal placement
    for UsedUnit in FUsageAnalyzer.InterfaceUsedUnits do
    begin
      Placement.UnitName := UsedUnit.UnitName;
      Placement.CurrentSection := usInterface;
      Placement.IdentifiersUsedInInterface := TStringList.Create;
      Placement.IdentifiersUsedInImplementation := TStringList.Create;
      LeafName := Copy( UsedUnit.UnitName, LastDelimiter( '.', UsedUnit.UnitName ) + 1, MaxInt );
      UsedInInterface := False;
      UsedInImplementation := False;

      CollectUsage( UsedUnit.UnitName );

      if UsedInInterface then
      begin
        Placement.RecommendedSection := usInterface;
        if UsedInImplementation then
          Placement.Reason := 'OK - used in both sections'
        else
          Placement.Reason := 'OK - used in interface section';
      end
      else if UsedInImplementation then
      begin
        Placement.RecommendedSection := usImplementation;
        Placement.Reason := 'Only used in implementation section';
      end
      else
      begin
        // No detected usage - might be unused or used implicitly
        Placement.RecommendedSection := usInterface;
        Placement.Reason := 'No direct usage detected - review manually';
      end;

      ResultList.Add( Placement );
    end;

    // Step 3: units of the implementation uses clause move up only when the interface uses them.
    for UsedUnit in FUsageAnalyzer.ImplementationUsedUnits do
    begin
      Placement.UnitName := UsedUnit.UnitName;
      Placement.CurrentSection := usImplementation;
      Placement.IdentifiersUsedInInterface := TStringList.Create;
      Placement.IdentifiersUsedInImplementation := TStringList.Create;
      LeafName := Copy( UsedUnit.UnitName, LastDelimiter( '.', UsedUnit.UnitName ) + 1, MaxInt );
      UsedInInterface := False;
      UsedInImplementation := False;

      CollectUsage( UsedUnit.UnitName );

      if UsedInInterface then
      begin
        Placement.RecommendedSection := usInterface;
        Placement.Reason := 'Identifiers used in interface section';
      end
      else
      begin
        Placement.RecommendedSection := usImplementation;
        Placement.Reason := 'OK - only used in implementation';
      end;

      ResultList.Add( Placement );
    end;

    Result := ResultList.ToArray;
  finally
    ResultList.Free;
  end;
end;

{ Uses-clause editing }

type
  /// <summary>An inclusive range of 1-based byte indexes.</summary>
  TByteRange = record
    /// <summary>First byte of the range.</summary>
    First: Integer;
    /// <summary>Last byte of the range.</summary>
    Last: Integer;
    /// <summary>True for a "//" comment, which runs to the end of its line.</summary>
    LineComment: Boolean;
  end;

  /// <summary>One entry of a uses clause.</summary>
  TClauseEntry = record
    /// <summary>The unit name, dotted parts joined with ".".</summary>
    Name: string;
    /// <summary>1-based byte index of the entry's first byte.</summary>
    StartIdx: Integer;
    /// <summary>1-based byte index of the entry's last byte ( the name, or the "in" path string ).</summary>
    EndIdx: Integer;
    /// <summary>Conditional-directive nesting depth at the entry, relative to the clause.</summary>
    Depth: Integer;
    /// <summary>1-based byte index of the "," after the entry; 0 when the ";" follows it.</summary>
    CommaIdx: Integer;
  end;

  /// <summary>What the editor needs to know about one section's uses clause.</summary>
  TClauseInfo = record
    /// <summary>True when the section keyword exists.</summary>
    SectionFound: Boolean;
    /// <summary>1-based byte index of the section keyword's last byte.</summary>
    SectionEnd: Integer;
    /// <summary>True when the section starts with a uses clause.</summary>
    Present: Boolean;
    /// <summary>1-based byte index of "uses".</summary>
    UsesIdx: Integer;
    /// <summary>1-based byte index of the terminating ";" ( 0 when none was found ).</summary>
    SemicolonIdx: Integer;
    /// <summary>Conditional depth at the ";", relative to the clause.</summary>
    SemicolonDepth: Integer;
    /// <summary>True when the clause can be edited at all: its conditional blocks balance, no
    /// {$ELSE} sits at its own level, its entries have the expected shape, and the clause itself
    /// is not inside a conditional block.</summary>
    Editable: Boolean;
    /// <summary>The entries, in source order.</summary>
    Entries: TArray<TClauseEntry>;
    /// <summary>Byte ranges of the comments and directives inside the clause.</summary>
    Noise: TArray<TByteRange>;
    /// <summary>True when an include directive ( {$I file} ) sits between the section keyword and
    /// its first significant token: the included file may hold the section's uses clause.</summary>
    IncludeBeforeClause: Boolean;
  end;

/// <summary>Classifies a compiler directive for conditional nesting.</summary>
/// <param name="AValue">The directive token's text, braces included.</param>
/// <param name="IsElse">Set when the directive is {$ELSE} or {$ELSEIF}.</param>
/// <returns>+1 for a directive opening a conditional block, -1 for one closing it, 0 otherwise.</returns>
function DirectiveNesting( const AValue: string; out IsElse: Boolean ): Integer;
var
  S: string;
begin
  S := UpperCase( AValue ).TrimLeft( [ '{', '(', '*', '$', ' ' ] );
  IsElse := S.StartsWith( 'ELSE' );
  if S.StartsWith( 'ENDIF' ) or S.StartsWith( 'IFEND' ) then
    Result := -1
  else if S.StartsWith( 'IFDEF' ) or S.StartsWith( 'IFNDEF' ) or S.StartsWith( 'IFOPT' ) or
          ( S.StartsWith( 'IF' ) and ( Length( S ) > 2 ) and CharInSet( S[ 3 ], [ ' ', '(', #9 ] ) ) then
    Result := 1
  else
    Result := 0;
end;

/// <summary>True for an include directive ( {$I file}, {$INCLUDE file} ), not the {$I+} / {$I-} switch.</summary>
/// <param name="AValue">The directive token's text, braces included.</param>
/// <returns>True when the directive includes a file.</returns>
function IsIncludeDirective( const AValue: string ): Boolean;
var
  S: string;
begin
  S := UpperCase( AValue ).TrimLeft( [ '{', '(', '*', '$' ] );
  Result := S.StartsWith( 'INCLUDE' ) or ( ( Length( S ) > 1 ) and ( S[ 1 ] = 'I' ) and CharInSet( S[ 2 ], [ ' ', #9 ] ) );
end;

/// <summary>True when a token kind can be part of a unit name.</summary>
/// <param name="AKind">The token kind.</param>
/// <returns>True for an identifier, including the directive words ( name, index, ... ).</returns>
function IsNameKind( AKind: TTokenKind ): Boolean;
begin
  Result := ( AKind >= tkIdent ) and ( AKind < tkIdentStrictReserved );
end;

/// <summary>Reads the uses clause that starts a section.</summary>
/// <param name="Tokens">Every token of the source, comments and directives included.</param>
/// <param name="ASection">tkI_interface or tkI_implementation.</param>
/// <returns>The clause description; SectionFound is False for a program, library or package.</returns>
function ReadClause( Tokens: TList<TToken>; ASection: TTokenKind ): TClauseInfo;
type
  TEntryState = ( esExpectName, esInName, esExpectPart, esExpectPath, esAfterEntry );
var
  I, K: Integer;
  OuterDepth, Depth, Delta: Integer;
  IsElse: Boolean;
  Token: TToken;
  State: TEntryState;
  Entry: TClauseEntry;
  Entries: TList<TClauseEntry>;
  Noise: TList<TByteRange>;
  Range: TByteRange;
begin
  Result := Default( TClauseInfo );

  // Only a unit has sections.
  I := 0;
  while ( I < Tokens.Count ) and ( Tokens[ I ].Kind in [ tkComment, tkDirective ] ) do
    Inc( I );
  if ( I >= Tokens.Count ) or ( Tokens[ I ].Kind <> tkI_unit ) then
    Exit;

  // The section keyword, tracking the conditional depth around it.
  OuterDepth := 0;
  while ( I < Tokens.Count ) and ( Tokens[ I ].Kind <> ASection ) do
  begin
    if Tokens[ I ].Kind = tkDirective then
      Inc( OuterDepth, DirectiveNesting( Tokens[ I ].Value, IsElse ) );
    Inc( I );
  end;
  if I >= Tokens.Count then
    Exit;
  Result.SectionFound := True;
  Result.SectionEnd := Tokens[ I ].EndIndex;

  // A uses clause is the first significant token of the section.
  Inc( I );
  while ( I < Tokens.Count ) and ( Tokens[ I ].Kind in [ tkComment, tkDirective ] ) do
  begin
    if Tokens[ I ].Kind = tkDirective then
    begin
      Inc( OuterDepth, DirectiveNesting( Tokens[ I ].Value, IsElse ) );
      if IsIncludeDirective( Tokens[ I ].Value ) then
        Result.IncludeBeforeClause := True;
    end;
    Inc( I );
  end;
  if ( I >= Tokens.Count ) or ( Tokens[ I ].Kind <> tkI_uses ) then
    Exit;
  Result.Present := True;
  Result.UsesIdx := Tokens[ I ].Index;
  Result.Editable := OuterDepth = 0;

  Entries := TList<TClauseEntry>.Create;
  Noise := TList<TByteRange>.Create;
  try
    Depth := 0;
    State := esExpectName;
    Entry := Default( TClauseEntry );
    for K := I + 1 to Tokens.Count - 1 do
    begin
      Token := Tokens[ K ];
      case Token.Kind of
        tkComment, tkDirective:
          begin
            Range.First := Token.Index;
            Range.Last := Token.EndIndex;
            Range.LineComment := ( Token.Kind = tkComment ) and Token.Value.StartsWith( '//' );
            Noise.Add( Range );
            if Token.Kind = tkDirective then
            begin
              Delta := DirectiveNesting( Token.Value, IsElse );
              if IsElse and ( Depth = 0 ) then
                Result.Editable := False; // An {$ELSE} of a block opened outside the clause.
              Inc( Depth, Delta );
              if Depth < 0 then
                Result.Editable := False;
            end;
          end;
        tkSemicolon, tkComma:
          begin
            if State in [ esInName, esAfterEntry ] then
            begin
              if Token.Kind = tkComma then
                Entry.CommaIdx := Token.Index
              else
                Entry.CommaIdx := 0;
              Entries.Add( Entry );
            end
            else
              Result.Editable := False; // ",," or a dangling "in".
            State := esExpectName;
            if Token.Kind = tkSemicolon then
            begin
              Result.SemicolonIdx := Token.Index;
              Result.SemicolonDepth := Depth;
              Break;
            end;
          end;
        tkQualifier:
          if State = esInName then
            State := esExpectPart
          else
            Result.Editable := False;
        tkI_in:
          if State = esInName then
            State := esExpectPath
          else
            Result.Editable := False;
        tkString:
          if State = esExpectPath then
          begin
            Entry.EndIdx := Token.EndIndex;
            State := esAfterEntry;
          end
          else
            Result.Editable := False;
      else
        if IsNameKind( Token.Kind ) and ( State = esExpectName ) then
        begin
          Entry.Name := Token.Value;
          Entry.StartIdx := Token.Index;
          Entry.EndIdx := Token.EndIndex;
          Entry.Depth := Depth;
          State := esInName;
        end
        else if IsNameKind( Token.Kind ) and ( State = esExpectPart ) then
        begin
          Entry.Name := Entry.Name + '.' + Token.Value;
          Entry.EndIdx := Token.EndIndex;
          State := esInName;
        end
        else
          Result.Editable := False; // Not a shape this editor understands.
      end;
    end;
    if Result.SemicolonIdx = 0 then
      Result.Editable := False;
    Result.Entries := Entries.ToArray;
    Result.Noise := Noise.ToArray;
  finally
    Noise.Free;
    Entries.Free;
  end;
end;

/// <summary>True when no comment or directive of the clause overlaps a byte range.</summary>
/// <param name="AInfo">The clause.</param>
/// <param name="AFirst">First byte of the range ( 1-based ).</param>
/// <param name="ALast">Last byte of the range ( 1-based ).</param>
/// <returns>True when the range holds code and white space only.</returns>
function RangeIsPlain( const AInfo: TClauseInfo; AFirst, ALast: Integer ): Boolean;
begin
  for var Range in AInfo.Noise do
    if ( Range.First <= ALast ) and ( Range.Last >= AFirst ) then
      Exit( False );
  Result := True;
end;

/// <summary>Returns an edit replacing the 1-based inclusive byte range with a text.</summary>
/// <param name="AFirst">First byte replaced ( 1-based ).</param>
/// <param name="ALast">Last byte replaced; AFirst - 1 for a pure insertion before AFirst.</param>
/// <param name="AText">The replacement text.</param>
/// <returns>The edit, in 0-based offsets.</returns>
function MakeEdit( AFirst, ALast: Integer; const AText: UTF8String ): TUsesEdit;
begin
  Result.Offset := AFirst - 1;
  Result.DeleteCount := ALast - AFirst + 1;
  Result.Text := AText;
end;

/// <summary>Joins unit entry texts with ", ".</summary>
/// <param name="ATexts">The entry texts.</param>
/// <returns>The joined text.</returns>
function JoinEntries( ATexts: TList<UTF8String> ): UTF8String;
begin
  Result := '';
  for var I := 0 to ATexts.Count - 1 do
  begin
    if I > 0 then
      Result := Result + UTF8String( ', ' );
    Result := Result + ATexts[ I ];
  end;
end;

function TUsesClauseRefactorer.PlanMoves( const Source: UTF8String; const Placements: TArray<TUnitPlacement>;
  out Edits: TArray<TUsesEdit>; out ErrorMessage: string ): Boolean;
const
  SectionNames: array[ TUsesSection ] of string = ( 'interface', 'implementation' );
var
  Tokens: TList<TToken>;
  Lexer: TDelphiLexer;
  Token: TToken;
  Clauses: array[ TUsesSection ] of TClauseInfo;
  Removed: array[ TUsesSection ] of TArray<Boolean>;
  Incoming: array[ TUsesSection ] of TList<UTF8String>;
  EditList: TList<TUsesEdit>;
  Section, Target: TUsesSection;
  Placement: TUnitPlacement;
  Index, Found, I, J, K, Last: Integer;
  AnyMove: Boolean;
  LineBreak: UTF8String;

  function Fail( const AMessage: string ): Boolean;
  begin
    ErrorMessage := AMessage;
    Edits := nil;
    Result := False;
  end;

  function EntryText( const AEntry: TClauseEntry ): UTF8String;
  begin
    Result := Copy( Source, AEntry.StartIdx, AEntry.EndIdx - AEntry.StartIdx + 1 );
  end;

  function FindEntry( const AInfo: TClauseInfo; const AName: string; out AIndex: Integer ): Integer;
  begin
    AIndex := -1;
    Result := 0;
    for var N := 0 to High( AInfo.Entries ) do
      if SameText( AInfo.Entries[ N ].Name, AName ) then
      begin
        AIndex := N;
        Inc( Result );
      end;
  end;

  // Column ( in bytes ) of a 1-based byte index on its line.
  function ColumnOf( AIdx: Integer ): Integer;
  var
    P: Integer;
  begin
    P := AIdx - 1;
    while ( P >= 1 ) and not ( Source[ P ] in [ #10, #13 ] ) do
      Dec( P );
    Result := AIdx - P;
  end;

  // 1-based index of the first byte of the line holding AIdx.
  function LineStartOf( AIdx: Integer ): Integer;
  begin
    Result := AIdx;
    while ( Result > 1 ) and not ( Source[ Result - 1 ] in [ #10, #13 ] ) do
      Dec( Result );
  end;

  // 1-based index of the last byte of the line holding AIdx, its line break included.
  function LineEndOf( AIdx: Integer ): Integer;
  begin
    Result := AIdx;
    while ( Result < Length( Source ) ) and not ( Source[ Result + 1 ] in [ #10, #13 ] ) do
      Inc( Result );
    if ( Result < Length( Source ) ) and ( Source[ Result + 1 ] = #13 ) then
      Inc( Result );
    if ( Result < Length( Source ) ) and ( Source[ Result + 1 ] = #10 ) then
      Inc( Result );
  end;

  // True when bytes AFirst..ALast are spaces and tabs only ( an empty range included ).
  function IsBlank( AFirst, ALast: Integer ): Boolean;
  begin
    for var P := AFirst to ALast do
      if not ( Source[ P ] in [ #9, ' ' ] ) then
        Exit( False );
    Result := True;
  end;

  // True when a "//" comment follows one of the entries AFirst..ALast on that entry's own line.
  function RunHasLineComment( const AInfo: TClauseInfo; AFirst, ALast: Integer ): Boolean;
  begin
    for var N := AFirst to ALast do
    begin
      var LineEnd := LineEndOf( AInfo.Entries[ N ].EndIdx );
      for var Range in AInfo.Noise do
        if Range.LineComment and ( Range.First > AInfo.Entries[ N ].EndIdx ) and ( Range.First <= LineEnd ) then
          Exit( True );
    end;
    Result := False;
  end;

  // True when every comment or directive overlapping AFirst..ALast is a "//" comment.
  function OnlyLineComments( const AInfo: TClauseInfo; AFirst, ALast: Integer ): Boolean;
  begin
    for var Range in AInfo.Noise do
      if ( Range.First <= ALast ) and ( Range.Last >= AFirst ) and not Range.LineComment then
        Exit( False );
    Result := True;
  end;

begin
  Edits := nil;
  ErrorMessage := '';

  // Inserted text uses the buffer's own line break, so an LF buffer does not get mixed endings.
  LineBreak := #13#10;
  for var P := 1 to Length( Source ) do
    if Source[ P ] = #10 then
    begin
      if ( P = 1 ) or ( Source[ P - 1 ] <> #13 ) then
        LineBreak := #10;
      Break;
    end;

  AnyMove := False;
  for Placement in Placements do
    if Placement.CurrentSection <> Placement.RecommendedSection then
      AnyMove := True;
  if not AnyMove then
    Exit( True );

  Incoming[ usInterface ] := nil;
  Incoming[ usImplementation ] := nil;
  Tokens := TList<TToken>.Create;
  Lexer := TDelphiLexer.Create( '', Source );
  try
    while Lexer.NextToken( Token ) do
      Tokens.Add( Token );
    Clauses[ usInterface ] := ReadClause( Tokens, tkI_interface );
    Clauses[ usImplementation ] := ReadClause( Tokens, tkI_implementation );
  finally
    // The clause descriptions hold copies, not tokens, so the lexer can go.
    Lexer.Free;
    Tokens.Free;
  end;

  if not ( Clauses[ usInterface ].SectionFound and Clauses[ usImplementation ].SectionFound ) then
    Exit( Fail( 'The source has no interface and implementation sections, so no unit can be moved between them.' ) );

  Incoming[ usInterface ] := TList<UTF8String>.Create;
  Incoming[ usImplementation ] := TList<UTF8String>.Create;
  EditList := TList<TUsesEdit>.Create;
  try
    for Section := Low( TUsesSection ) to High( TUsesSection ) do
      SetLength( Removed[ Section ], Length( Clauses[ Section ].Entries ) );

    // Which entries leave which clause, and what each target clause receives.
    for Placement in Placements do
    begin
      if Placement.CurrentSection = Placement.RecommendedSection then
        Continue;
      Section := Placement.CurrentSection;
      Target := Placement.RecommendedSection;
      if not Clauses[ Section ].Present then
        Exit( Fail( Format( '%s is not in the %s uses clause any more; analyse the unit again.',
          [ Placement.UnitName, SectionNames[ Section ] ] ) ) );
      Found := FindEntry( Clauses[ Section ], Placement.UnitName, Index );
      if Found = 0 then
        Exit( Fail( Format( '%s is not in the %s uses clause any more; analyse the unit again.',
          [ Placement.UnitName, SectionNames[ Section ] ] ) ) );
      if Found > 1 then
        Exit( Fail( Format( '%s is listed more than once in the %s uses clause; tidy the clause first.',
          [ Placement.UnitName, SectionNames[ Section ] ] ) ) );
      if not Clauses[ Section ].Editable then
        Exit( Fail( Format( 'The %s uses clause has conditional blocks ( {$IFDEF} ... ) or a layout that '
          + 'cannot be edited safely; move %s by hand.', [ SectionNames[ Section ], Placement.UnitName ] ) ) );
      if Clauses[ Section ].Entries[ Index ].Depth <> 0 then
        Exit( Fail( Format( '%s sits inside a conditional block ( {$IFDEF} ... ) of the %s uses clause; move it by hand.',
          [ Placement.UnitName, SectionNames[ Section ] ] ) ) );
      Removed[ Section ][ Index ] := True;
      // A unit already listed in the target clause is only removed from the source clause.
      if FindEntry( Clauses[ Target ], Placement.UnitName, J ) = 0 then
        Incoming[ Target ].Add( EntryText( Clauses[ Section ].Entries[ Index ] ) );
    end;

    for Section := Low( TUsesSection ) to High( TUsesSection ) do
    begin
      var Info := Clauses[ Section ];
      Last := High( Info.Entries );

      var AllRemoved := Info.Present;
      for I := 0 to Last do
        if not Removed[ Section ][ I ] then
          AllRemoved := False;

      if Info.Present and ( Incoming[ Section ].Count > 0 ) and not Info.Editable then
        Exit( Fail( Format( 'The %s uses clause has conditional blocks ( {$IFDEF} ... ) or a layout that '
          + 'cannot be edited safely; move the units by hand.', [ SectionNames[ Section ] ] ) ) );

      if AllRemoved and ( Last >= 0 ) then
      begin
        if Incoming[ Section ].Count > 0 then
        begin
          // Every entry leaves and others arrive: replace the entries, keeping "uses" and ";".
          if not RangeIsPlain( Info, Info.Entries[ 0 ].StartIdx, Info.Entries[ Last ].EndIdx ) then
            Exit( Fail( Format( 'Moving the units of the %s uses clause would delete a comment or compiler '
              + 'directive inside it; move them by hand.', [ SectionNames[ Section ] ] ) ) );
          EditList.Add( MakeEdit( Info.Entries[ 0 ].StartIdx, Info.Entries[ Last ].EndIdx, JoinEntries( Incoming[ Section ] ) ) );
        end
        else
        begin
          // The clause empties: delete it, with the white space that follows it.
          if not RangeIsPlain( Info, Info.UsesIdx, Info.SemicolonIdx ) then
            Exit( Fail( Format( 'Emptying the %s uses clause would delete a comment or compiler directive '
              + 'inside it; move the units by hand.', [ SectionNames[ Section ] ] ) ) );
          K := Info.SemicolonIdx;
          while ( K < Length( Source ) ) and ( Source[ K + 1 ] in [ #9, #10, #13, ' ' ] ) do
            Inc( K );
          EditList.Add( MakeEdit( Info.UsesIdx, K, '' ) );
        end;
        Continue;
      end;

      // Remove each run of consecutive leaving entries with one separating comma.
      I := 0;
      while I <= Last do
      begin
        if not Removed[ Section ][ I ] then
        begin
          Inc( I );
          Continue;
        end;
        J := I;
        while ( J < Last ) and Removed[ Section ][ J + 1 ] do
          Inc( J );

        // A "//" comment after an entry on its line describes that entry: it goes with it, and
        // then only when the entries have their lines to themselves; otherwise the comment would
        // be left describing the next unit, so the move is refused.
        if RunHasLineComment( Info, I, J ) then
        begin
          var LineFirst := LineStartOf( Info.Entries[ I ].StartIdx );
          var LineLast := LineEndOf( Info.Entries[ J ].EndIdx );
          if ( J < Last ) and ( Info.Entries[ J ].CommaIdx > 0 ) and ( Info.Entries[ J ].CommaIdx <= LineLast ) and
             ( Info.Entries[ J + 1 ].StartIdx > LineLast ) and IsBlank( LineFirst, Info.Entries[ I ].StartIdx - 1 ) and
             OnlyLineComments( Info, LineFirst, LineLast ) then
            EditList.Add( MakeEdit( LineFirst, LineLast, '' ) )
          else
            Exit( Fail( Format( 'Removing %s from the %s uses clause would leave its trailing // comment behind; '
              + 'move it by hand.', [ Info.Entries[ I ].Name, SectionNames[ Section ] ] ) ) );
        end
        // Forward: the run, the "," after it and the white space after that ( "B, " of "A, B, C" ),
        // so a comment or directive before the next entry stays.  Backward: the "," after the kept
        // entry before the run, and the run ( ", B" ); the only choice for a run ending the clause.
        else if ( J < Last ) and ( Info.Entries[ J ].CommaIdx > 0 ) and
           RangeIsPlain( Info, Info.Entries[ I ].StartIdx, Info.Entries[ J ].CommaIdx ) then
        begin
          K := Info.Entries[ J ].CommaIdx;
          while ( K < Length( Source ) ) and ( Source[ K + 1 ] in [ #9, #10, #13, ' ' ] ) do
            Inc( K );
          EditList.Add( MakeEdit( Info.Entries[ I ].StartIdx, K, '' ) );
        end
        else if ( I > 0 ) and ( Info.Entries[ I - 1 ].CommaIdx > 0 ) and
                RangeIsPlain( Info, Info.Entries[ I - 1 ].CommaIdx, Info.Entries[ J ].EndIdx ) then
          EditList.Add( MakeEdit( Info.Entries[ I - 1 ].CommaIdx, Info.Entries[ J ].EndIdx, '' ) )
        else
          Exit( Fail( Format( 'Removing %s from the %s uses clause would delete a comment or compiler directive '
            + 'next to it; move it by hand.', [ Info.Entries[ I ].Name, SectionNames[ Section ] ] ) ) );
        I := J + 1;
      end;

      if Incoming[ Section ].Count = 0 then
        Continue;

      if Info.Present then
      begin
        // Append before the ";", which must not sit inside a conditional block.
        if Info.SemicolonDepth <> 0 then
          Exit( Fail( Format( 'The %s uses clause ends inside a conditional block ( {$IFDEF} ... ); move the units by hand.',
            [ SectionNames[ Section ] ] ) ) );
        var Added := JoinEntries( Incoming[ Section ] );
        if ColumnOf( Info.SemicolonIdx ) + Length( Added ) + 2 > 160 then
          Added := UTF8String( ',' ) + LineBreak + UTF8String( '  ' ) + Added
        else
          Added := UTF8String( ', ' ) + Added;
        EditList.Add( MakeEdit( Info.SemicolonIdx, Info.SemicolonIdx - 1, Added ) );
      end
      else
      begin
        // No clause yet: create one straight after the section keyword - unless an include file
        // there may hold the section's clause, which a second clause would duplicate.
        if Info.IncludeBeforeClause then
          Exit( Fail( Format( 'An include file ( {$I ...} ) starts the %s section and may hold its uses clause; '
            + 'move the units by hand.', [ SectionNames[ Section ] ] ) ) );
        EditList.Add( MakeEdit( Info.SectionEnd + 1, Info.SectionEnd,
          LineBreak + LineBreak + UTF8String( 'uses' ) + LineBreak + UTF8String( '  ' ) + JoinEntries( Incoming[ Section ] ) + UTF8String( ';' ) ) );
      end;
    end;

    // Sorted by offset, an insertion before a deletion at the same offset.
    EditList.Sort( TComparer<TUsesEdit>.Construct(
      function( const ALeft, ARight: TUsesEdit ): Integer
      begin
        Result := ALeft.Offset - ARight.Offset;
        if Result = 0 then
          Result := ALeft.DeleteCount - ARight.DeleteCount;
      end ) );
    for I := 1 to EditList.Count - 1 do
      if EditList[ I - 1 ].Offset + EditList[ I - 1 ].DeleteCount > EditList[ I ].Offset then
        Exit( Fail( 'The planned uses-clause edits overlap; nothing was changed.' ) );

    Edits := EditList.ToArray;
    Result := True;
  finally
    EditList.Free;
    Incoming[ usInterface ].Free;
    Incoming[ usImplementation ].Free;
  end;
end;

class function TUsesClauseRefactorer.ApplyEdits( const Source: UTF8String; const Edits: TArray<TUsesEdit> ): UTF8String;
var
  Size, Done, Written: Integer;
begin
  Size := Length( Source );
  for var Edit in Edits do
    Inc( Size, Length( Edit.Text ) - Edit.DeleteCount );
  SetLength( Result, Size );

  Done := 0; // Bytes of Source consumed.
  Written := 0; // Bytes of Result written.
  for var Edit in Edits do
  begin
    if Edit.Offset > Done then
    begin
      Move( Source[ Done + 1 ], Result[ Written + 1 ], Edit.Offset - Done );
      Inc( Written, Edit.Offset - Done );
    end;
    if Edit.Text <> '' then
    begin
      Move( Edit.Text[ 1 ], Result[ Written + 1 ], Length( Edit.Text ) );
      Inc( Written, Length( Edit.Text ) );
    end;
    Done := Edit.Offset + Edit.DeleteCount;
  end;
  if Done < Length( Source ) then
    Move( Source[ Done + 1 ], Result[ Written + 1 ], Length( Source ) - Done );
end;

function TUsesClauseRefactorer.GenerateRefactoredSource( const Source: UTF8String;
  const Placements: TArray<TUnitPlacement>; out ErrorMessage: string ): UTF8String;
var
  Edits: TArray<TUsesEdit>;
begin
  if PlanMoves( Source, Placements, Edits, ErrorMessage ) and ( Length( Edits ) > 0 ) then
    Result := ApplyEdits( Source, Edits )
  else
    Result := Source;
end;

function TUsesClauseRefactorer.GenerateRefactoredSource( const Source: UTF8String;
  const Placements: TArray<TUnitPlacement> ): UTF8String;
var
  Ignored: string;
begin
  Result := GenerateRefactoredSource( Source, Placements, Ignored );
end;

end.
