{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit DecirculariserCore;

/// <summary>
/// Pure analysis core for the Decirculariser: finds the entangled groups of units in a
/// project, judges how dangerous each one is, and works out what it would actually take to
/// break them - down to naming the individual identifiers that hold each edge in place.
/// </summary>
/// <remarks>
/// RTL, <c>DelphiLexer</c> and <c>UsesClauseManagerCore</c> only - no ToolsAPI, no VCL and
/// no IDE - so it is unit-testable outside the IDE like the other <c>*Core</c> units.
///
/// Three decisions here are deliberate, and they are the reason this is worth having over a
/// plain cycle report:
///
/// - <b>Entanglement is reported as strongly-connected components, not as cycles.</b> A group
///   of n mutually-dependent units can contain a factorial number of distinct cycles, so
///   enumerating them does not terminate usefully on a real project. The group is the honest
///   unit of "these units are stuck together".
///
/// - <b>Not every cycle is a problem, and the dangerous ones are the SMALL ones.</b> Delphi
///   permits a cycle through <c>implementation</c> sections - that is what the two-part unit
///   is FOR - and such a cycle costs nothing at compile time. What bites is a group held
///   together by exactly ONE implementation edge: the other direction is already an interface
///   use, so the day somebody needs that type in the interface they get <c>E2004 Circular
///   unit reference</c> and a hard stop, with no prior warning. Those are reported as
///   <c>dcgFragile</c> and sorted to the top.
///
/// - <b>An edge is judged by the identifiers that actually cross it</b>, not by its
///   existence. An edge nothing crosses is a dead uses entry and can simply be deleted; an
///   edge carrying two identifiers is an extract-to-leaf-unit job; an edge carrying forty is
///   genuine collaboration and no tool should pretend to automate it. That distinction is the
///   whole value of this unit, and it is why it needs the exports database from
///   <c>UsesClauseManagerCore</c> rather than just a graph.
///
/// This unit deliberately does NOT rewrite source. It reports what to do and how big the job
/// is; applying the trivial cases is a separate, explicit step.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  UsesClauseManagerCore;

type
  /// <summary>One directed uses-clause reference between two units of the analysed set.</summary>
  TDcEdge = record
    /// <summary>Unit whose uses clause carries the reference.</summary>
    FromUnit: string;
    /// <summary>Unit being referred to.</summary>
    ToUnit: string;
    /// <summary>Section the reference appears in.</summary>
    Section: TUsesSection;
    /// <summary>Source line of the reference, for navigation.</summary>
    LineNumber: Integer;
  end;

  /// <summary>How dangerous an entangled group is.</summary>
  TDcGroupKind = (
    /// <summary>Held together by several implementation edges. Legal, idiomatic Delphi, and
    /// free at compile time. Worth breaking for comprehensibility, not for correctness.</summary>
    dcgBenign,
    /// <summary>Held together by exactly ONE implementation edge, so the opposite direction is
    /// already an interface use. Promoting that one uses clause to the interface section yields
    /// E2004 and a hard build break, with nothing to warn you beforehand.</summary>
    dcgFragile,
    /// <summary>Every edge in the group is an interface edge, which cannot compile. Only
    /// reachable when the analysed set is partial or the sources are inconsistent.</summary>
    dcgUncompilable
  );

  /// <summary>What breaking one edge would cost.</summary>
  TDcVerdict = (
    /// <summary>No identifier of the target is referenced. The uses entry is dead - delete it.</summary>
    dcvUnusedEdge,
    /// <summary>Nothing UNIQUE to the target is referenced, but identifiers that several
    /// units declare are. The edge may be dead or may not - this cannot tell, and says so
    /// rather than advising a deletion it cannot justify. The compiler settles it.</summary>
    dcvAmbiguous,
    /// <summary>A handful of identifiers cross it. Movable to a shared leaf unit.</summary>
    dcvFewSymbols,
    /// <summary>Genuine collaboration. Needs an interface, an event or a registry - a design
    /// decision, not a refactoring a tool should make.</summary>
    dcvManySymbols
  );

  /// <summary>One edge of an entangled group, with what holds it in place.</summary>
  TDcBreakCandidate = record
    /// <summary>The edge that would be removed.</summary>
    Edge: TDcEdge;
    /// <summary>Identifiers exported by <c>Edge.ToUnit</c> that <c>Edge.FromUnit</c> references.</summary>
    CrossingSymbols: TArray<string>;
    /// <summary>Identifiers excluded because more than one unit in the analysed set
    /// exports them, so they are no evidence for THIS edge. A form's FormCreate is the
    /// usual case - the exports scanner records class member names as unit exports, and
    /// forty forms all declare one.</summary>
    AmbiguousSymbolCount: Integer;
    /// <summary>How big the job is.</summary>
    Verdict: TDcVerdict;
    /// <summary>One line saying what to do about it.</summary>
    Advice: string;
  end;

  /// <summary>One group of mutually entangled units.</summary>
  TDcGroup = record
    /// <summary>Members of the group, alphabetically.</summary>
    Units: TArray<string>;
    /// <summary>How dangerous it is.</summary>
    Kind: TDcGroupKind;
    /// <summary>Interface-section edges wholly inside the group.</summary>
    InterfaceEdgeCount: Integer;
    /// <summary>Implementation-section edges wholly inside the group.</summary>
    ImplementationEdgeCount: Integer;
    /// <summary>The implementation edges, cheapest to break first. Interface edges are never
    /// offered: a group that compiles is always held together by implementation edges, and
    /// those are the only ones that can actually be moved.</summary>
    Candidates: TArray<TDcBreakCandidate>;
  end;

  /// <summary>
  /// Builds the unit graph for a set of sources, finds the entangled groups and ranks the
  /// break candidates within each.
  /// </summary>
  TDecirculariser = class
  private
    /// <summary>Source text of each added unit, keyed by lower-case unit name.</summary>
    FSources: TDictionary<string, UTF8String>;
    /// <summary>Added unit names in their original casing, keyed by lower-case name.</summary>
    FNames: TDictionary<string, string>;
    /// <summary>Every edge whose two ends are both in the analysed set.</summary>
    FEdges: TList<TDcEdge>;
    /// <summary>Identifiers each unit references anywhere in its own source.</summary>
    FUsedIdents: TObjectDictionary<string, TStringList>;
    /// <summary>What each unit exports, shared with the usage analysis.</summary>
    FExports: TUnitExportsDatabase;
    /// <summary>Result of the last <see cref="Analyse"/>.</summary>
    FGroups: TArray<TDcGroup>;
    /// <summary>Threshold at and below which an edge is judged extractable.</summary>
    FFewSymbolsLimit: Integer;
    /// <summary>Parses every added unit into edges, exports and referenced identifiers.</summary>
    procedure BuildGraph;
    /// <summary>Iterative Tarjan. Returns only components of more than one unit.</summary>
    function FindGroups: TArray<TArray<string>>;
    /// <summary>Identifiers of <paramref name="AToUnit"/> that <paramref name="AFromUnit"/> uses.</summary>
    function CrossingSymbols( const AFromUnit, AToUnit: string;
      out AAmbiguous: Integer ): TArray<string>;
    /// <summary>Fills in the candidates, counts and kind for one group.</summary>
    function DescribeGroup( const AMembers: TArray<string> ): TDcGroup;
  public
    /// <summary>Creates an empty analyser.</summary>
    constructor Create;
    /// <summary>Releases all owned collections.</summary>
    destructor Destroy; override;
    /// <summary>Adds one unit's source to the set to be analysed.</summary>
    /// <param name="AUnitName">Unit name without path or extension.</param>
    /// <param name="ASource">UTF-8 source text.</param>
    /// <remarks>Only references BETWEEN added units become edges; anything else - the RTL, the
    /// VCL, units outside the project - is ignored, which is what keeps the result about the
    /// code you can actually change.</remarks>
    procedure AddUnit( const AUnitName: string; const ASource: UTF8String );
    /// <summary>Adds every .pas file in a directory. Returns how many were added.</summary>
    function AddDirectory( const ADirectory: string ): Integer;
    /// <summary>Runs the analysis. Safe to call again after adding more units.</summary>
    procedure Analyse;
    /// <summary>Renders the analysis as a plain-text report.</summary>
    function Report: string;
    /// <summary>Entangled groups, most dangerous first, then largest.</summary>
    property Groups: TArray<TDcGroup> read FGroups;
    /// <summary>Number of units added.</summary>
    function UnitCount: Integer;
    /// <summary>At and below this many crossing identifiers an edge is judged extractable
    /// rather than genuine collaboration. Defaults to 3.</summary>
    property FewSymbolsLimit: Integer read FFewSymbolsLimit write FFewSymbolsLimit;
  end;

/// <summary>Human-readable name of a group kind.</summary>
function DcGroupKindToStr( AKind: TDcGroupKind ): string;
/// <summary>Human-readable name of a verdict.</summary>
function DcVerdictToStr( AVerdict: TDcVerdict ): string;

implementation

uses
  System.Generics.Defaults, System.Math;

const
  /// <summary>Default for <see cref="TDecirculariser.FewSymbolsLimit"/>.</summary>
  DEFAULT_FEW_SYMBOLS = 3;

function DcGroupKindToStr( AKind: TDcGroupKind ): string;
begin
  case AKind of
    dcgFragile:
      Result := 'FRAGILE';
    dcgUncompilable:
      Result := 'UNCOMPILABLE';
  else
    Result := 'benign';
  end;
end;

function DcVerdictToStr( AVerdict: TDcVerdict ): string;
begin
  case AVerdict of
    dcvUnusedEdge:
      Result := 'dead uses entry';
    dcvAmbiguous:
      Result := 'cannot tell';
    dcvFewSymbols:
      Result := 'extractable';
  else
    Result := 'collaboration';
  end;
end;

{ TDecirculariser }

constructor TDecirculariser.Create;
begin
  inherited Create;
  FSources         := TDictionary<string, UTF8String>.Create;
  FNames           := TDictionary<string, string>.Create;
  FEdges           := TList<TDcEdge>.Create;
  FUsedIdents      := TObjectDictionary<string, TStringList>.Create( [ doOwnsValues ] );
  FExports         := TUnitExportsDatabase.Create;
  FFewSymbolsLimit := DEFAULT_FEW_SYMBOLS;
end;

destructor TDecirculariser.Destroy;
begin
  FExports.Free;
  FUsedIdents.Free;
  FEdges.Free;
  FNames.Free;
  FSources.Free;
  inherited Destroy;
end;

procedure TDecirculariser.AddUnit( const AUnitName: string; const ASource: UTF8String );
var
  sKey: string;
begin
  sKey := LowerCase( Trim( AUnitName ) );
  if sKey = '' then
    Exit;

  FSources.AddOrSetValue( sKey, ASource );
  FNames.AddOrSetValue( sKey, Trim( AUnitName ) );
end;

function TDecirculariser.AddDirectory( const ADirectory: string ): Integer;
var
  SR: TSearchRec;
  sPath: string;
  sFile: string;
  sl: TStringList;
begin
  Result := 0;
  sPath  := IncludeTrailingPathDelimiter( ADirectory );
  if not DirectoryExists( sPath ) then
    Exit;

  if FindFirst( sPath + '*.pas', faAnyFile, SR ) <> 0 then
    Exit;
  try
    repeat
      sFile := sPath + SR.Name;
      sl := TStringList.Create;
      try
        try
          sl.LoadFromFile( sFile );
        except
          { A file that will not load is skipped rather than aborting the scan - one
            unreadable unit should not cost the whole analysis. }
          Continue;
        end;
        AddUnit( ChangeFileExt( SR.Name, '' ), UTF8Encode( sl.Text ) );
        Inc( Result );
      finally
        sl.Free;
      end;
    until FindNext( SR ) <> 0;
  finally
    System.SysUtils.FindClose( SR );
  end;
end;

function TDecirculariser.UnitCount: Integer;
begin
  Result := FSources.Count;
end;

procedure TDecirculariser.BuildGraph;
var
  Analyzer: TIdentifierUsageAnalyzer;
  Pair: TPair<string, UTF8String>;
  Used: TUsedUnitInfo;
  Edge: TDcEdge;
  Idents: TStringList;
  I: Integer;

  procedure AddEdge( const AFrom: string; const AUsed: TUsedUnitInfo );
  var
    sTo: string;
  begin
    { A dotted reference resolves on its leaf name, which is how the unit would be found
      on the search path. }
    sTo := LowerCase( AUsed.UnitName );
    if Pos( '.', sTo ) > 0 then
      sTo := LowerCase( Copy( AUsed.UnitName, LastDelimiter( '.', AUsed.UnitName ) + 1, MaxInt ) );

    { Only edges INSIDE the analysed set are of interest - the RTL and the VCL are not
      things the caller can restructure. }
    if not FSources.ContainsKey( sTo ) or SameText( sTo, AFrom ) then
      Exit;

    Edge.FromUnit   := FNames[ AFrom ];
    Edge.ToUnit     := FNames[ sTo ];
    Edge.Section    := AUsed.Section;
    Edge.LineNumber := AUsed.LineNumber;
    FEdges.Add( Edge );
  end;

begin
  FEdges.Clear;
  FUsedIdents.Clear;
  FExports.Clear;

  { Pass one: every unit's exports, so that symbol attribution can resolve either way round. }
  for Pair in FSources do
    FExports.ScanSource( FNames[ Pair.Key ], FNames[ Pair.Key ] + '.pas', Pair.Value );

  { Pass two: the uses clauses and the identifiers each unit actually mentions. }
  Analyzer := TIdentifierUsageAnalyzer.Create;
  try
    for Pair in FSources do
    begin
      Analyzer.Clear;
      Analyzer.Analyze( Pair.Value );

      for Used in Analyzer.InterfaceUsedUnits do
        AddEdge( Pair.Key, Used );
      for Used in Analyzer.ImplementationUsedUnits do
        AddEdge( Pair.Key, Used );

      Idents := TStringList.Create;
      Idents.CaseSensitive := False;
      Idents.Duplicates    := dupIgnore;
      Idents.Sorted        := True;
      for I := 0 to Analyzer.InterfaceIdentifiers.Count - 1 do
        Idents.Add( Analyzer.InterfaceIdentifiers[ I ] );
      for I := 0 to Analyzer.ImplementationIdentifiers.Count - 1 do
        Idents.Add( Analyzer.ImplementationIdentifiers[ I ] );
      FUsedIdents.AddOrSetValue( Pair.Key, Idents );
    end;
  finally
    Analyzer.Free;
  end;
end;

function TDecirculariser.FindGroups: TArray<TArray<string>>;
var
  Nodes: TArray<string>;
  Index, LowLink: TDictionary<string, Integer>;
  OnStack: TDictionary<string, Boolean>;
  Adjacency: TObjectDictionary<string, TStringList>;
  Stack: TStack<string>;
  Counter: Integer;
  Result_: TList<TArray<string>>;
  Edge: TDcEdge;
  Node: string;
  sKey: string;
  Members: TStringList;

  procedure StrongConnect( const ARoot: string );
  type
    TFrame = record
      Node: string;
      Next: Integer;
    end;
  var
    Frames: TList<TFrame>;
    Frame: TFrame;
    Child: string;
    Neighbours: TStringList;
    Popped: string;
    Comp: TStringList;
    Arr: TArray<string>;
    J: Integer;
  begin
    { Iterative, with an explicit frame stack. A recursive Tarjan overflows on an
      estate-sized graph, and the depth here is bounded only by the unit count. }
    Frames := TList<TFrame>.Create;
    try
      Frame.Node := ARoot;
      Frame.Next := 0;
      Frames.Add( Frame );

      Index.AddOrSetValue( ARoot, Counter );
      LowLink.AddOrSetValue( ARoot, Counter );
      Inc( Counter );
      Stack.Push( ARoot );
      OnStack.AddOrSetValue( ARoot, True );

      while Frames.Count > 0 do
      begin
        Frame := Frames[ Frames.Count - 1 ];
        if not Adjacency.TryGetValue( Frame.Node, Neighbours ) then
          Neighbours := nil;

        if ( Neighbours <> nil ) and ( Frame.Next < Neighbours.Count ) then
        begin
          Child := Neighbours[ Frame.Next ];
          Inc( Frame.Next );
          Frames[ Frames.Count - 1 ] := Frame;

          if not Index.ContainsKey( Child ) then
          begin
            Index.AddOrSetValue( Child, Counter );
            LowLink.AddOrSetValue( Child, Counter );
            Inc( Counter );
            Stack.Push( Child );
            OnStack.AddOrSetValue( Child, True );

            Frame.Node := Child;
            Frame.Next := 0;
            Frames.Add( Frame );
          end
          else if OnStack.ContainsKey( Child ) and OnStack[ Child ] then
            LowLink[ Frame.Node ] := Min( LowLink[ Frame.Node ], Index[ Child ] );

          Continue;
        end;

        { Every neighbour done - close this node off. }
        Frames.Delete( Frames.Count - 1 );
        if Frames.Count > 0 then
        begin
          Child := Frames[ Frames.Count - 1 ].Node;
          LowLink[ Child ] := Min( LowLink[ Child ], LowLink[ Frame.Node ] );
        end;

        if LowLink[ Frame.Node ] = Index[ Frame.Node ] then
        begin
          Comp := TStringList.Create;
          try
            repeat
              Popped := Stack.Pop;
              OnStack[ Popped ] := False;
              Comp.Add( FNames[ Popped ] );
            until Popped = Frame.Node;

            { A single unit is not an entanglement - only groups of two or more. }
            if Comp.Count > 1 then
            begin
              Comp.Sort;
              SetLength( Arr, Comp.Count );
              for J := 0 to Comp.Count - 1 do
                Arr[ J ] := Comp[ J ];
              Result_.Add( Arr );
            end;
          finally
            Comp.Free;
          end;
        end;
      end;
    finally
      Frames.Free;
    end;
  end;

begin
  Index      := TDictionary<string, Integer>.Create;
  LowLink    := TDictionary<string, Integer>.Create;
  OnStack    := TDictionary<string, Boolean>.Create;
  Adjacency  := TObjectDictionary<string, TStringList>.Create( [ doOwnsValues ] );
  Stack      := TStack<string>.Create;
  Result_    := TList<TArray<string>>.Create;
  try
    for Edge in FEdges do
    begin
      sKey := LowerCase( Edge.FromUnit );
      if not Adjacency.TryGetValue( sKey, Members ) then
      begin
        Members := TStringList.Create;
        Members.Duplicates := dupIgnore;
        Members.Sorted     := True;
        Adjacency.Add( sKey, Members );
      end;
      Members.Add( LowerCase( Edge.ToUnit ) );
    end;

    Nodes := FSources.Keys.ToArray;
    TArray.Sort<string>( Nodes );
    Counter := 0;
    for Node in Nodes do
      if not Index.ContainsKey( Node ) then
        StrongConnect( Node );

    Result := Result_.ToArray;
  finally
    Result_.Free;
    Stack.Free;
    Adjacency.Free;
    OnStack.Free;
    LowLink.Free;
    Index.Free;
  end;
end;

function TDecirculariser.CrossingSymbols( const AFromUnit, AToUnit: string;
  out AAmbiguous: Integer ): TArray<string>;
var
  Exported: TList<TUnitExport>;
  Used: TStringList;
  Found: TStringList;
  Providers: TStringList;
  Item: TUnitExport;
  I: Integer;
begin
  Result     := nil;
  AAmbiguous := 0;

  Exported := FExports.GetExports( AToUnit );
  if Exported = nil then
    Exit;
  if not FUsedIdents.TryGetValue( LowerCase( AFromUnit ), Used ) then
    Exit;

  Found := TStringList.Create;
  try
    Found.CaseSensitive := False;
    Found.Duplicates    := dupIgnore;
    Found.Sorted        := True;
    for Item in Exported do
    begin
      if Used.IndexOf( Item.Identifier ) < 0 then
        Continue;

      { An identifier several units in the set export is no evidence for THIS edge.
        The exports scanner records class member names, so every form "exports"
        FormCreate - and without this, forty unrelated forms each look as though they
        depend on the main form because of it. Counted rather than silently dropped. }
      Providers := FExports.FindUnitsForIdentifier( Item.Identifier );
      if ( Providers <> nil ) and ( Providers.Count > 1 ) then
      begin
        Inc( AAmbiguous );
        Continue;
      end;

      Found.Add( Item.Identifier );
    end;

    SetLength( Result, Found.Count );
    for I := 0 to Found.Count - 1 do
      Result[ I ] := Found[ I ];
  finally
    Found.Free;
  end;
end;

function TDecirculariser.DescribeGroup( const AMembers: TArray<string> ): TDcGroup;
var
  InGroup: TStringList;
  Edge: TDcEdge;
  Candidate: TDcBreakCandidate;
  Candidates: TList<TDcBreakCandidate>;
  Member: string;
begin
  Result                         := Default( TDcGroup );
  Result.Units                   := AMembers;
  Result.InterfaceEdgeCount      := 0;
  Result.ImplementationEdgeCount := 0;

  InGroup := TStringList.Create;
  Candidates := TList<TDcBreakCandidate>.Create;
  try
    InGroup.CaseSensitive := False;
    InGroup.Sorted        := True;
    for Member in AMembers do
      InGroup.Add( LowerCase( Member ) );

    for Edge in FEdges do
    begin
      if ( InGroup.IndexOf( LowerCase( Edge.FromUnit ) ) < 0 ) or
         ( InGroup.IndexOf( LowerCase( Edge.ToUnit ) ) < 0 ) then
        Continue;

      if Edge.Section = usInterface then
      begin
        Inc( Result.InterfaceEdgeCount );
        Continue;
      end;

      Inc( Result.ImplementationEdgeCount );

      Candidate.Edge            := Edge;
      Candidate.CrossingSymbols := CrossingSymbols( Edge.FromUnit, Edge.ToUnit,
        Candidate.AmbiguousSymbolCount );

      if ( Length( Candidate.CrossingSymbols ) = 0 ) and
         ( Candidate.AmbiguousSymbolCount > 0 ) then
      begin
        Candidate.Verdict := dcvAmbiguous;
        Candidate.Advice  := Format( 'Cannot tell. Nothing unique to %s is referenced by %s, but %d identifier(s) that several units here declare are - most often inherited form members. Remove the entry and let the compiler decide.',
          [ Edge.ToUnit, Edge.FromUnit, Candidate.AmbiguousSymbolCount ] );
      end
      else if Length( Candidate.CrossingSymbols ) = 0 then
      begin
        Candidate.Verdict := dcvUnusedEdge;
        Candidate.Advice := Format( 'No identifier of %s is referenced at all - remove it ' +
          'from the implementation uses clause of %s.', [ Edge.ToUnit, Edge.FromUnit ] );
      end
      else if Length( Candidate.CrossingSymbols ) <= FFewSymbolsLimit then
      begin
        Candidate.Verdict := dcvFewSymbols;
        Candidate.Advice  := Format( 'Only %d identifier(s) cross this edge (%s) - move them to ' +
          'a shared leaf unit and both sides can use that instead.',
          [ Length( Candidate.CrossingSymbols ), string.Join( ', ', Candidate.CrossingSymbols ) ] );
      end
      else
      begin
        Candidate.Verdict := dcvManySymbols;
        Candidate.Advice  := Format( '%d identifiers cross this edge - genuine collaboration. ' +
          'Breaking it needs an interface, an event or a registry, which is a design decision.',
          [ Length( Candidate.CrossingSymbols ) ] );
      end;

      Candidates.Add( Candidate );
    end;

    { Cheapest first: a dead entry, then the smallest extraction. }
    Candidates.Sort( TComparer<TDcBreakCandidate>.Construct(
      function( const A, B: TDcBreakCandidate ): Integer
      begin
        Result := Length( A.CrossingSymbols ) - Length( B.CrossingSymbols );
        if Result = 0 then
          Result := CompareText( A.Edge.FromUnit, B.Edge.FromUnit );
      end ) );
    Result.Candidates := Candidates.ToArray;

    if Result.ImplementationEdgeCount = 0 then
      Result.Kind := dcgUncompilable
    else if Result.ImplementationEdgeCount = 1 then
      Result.Kind := dcgFragile
    else
      Result.Kind := dcgBenign;
  finally
    Candidates.Free;
    InGroup.Free;
  end;
end;

procedure TDecirculariser.Analyse;
var
  Raw: TArray<TArray<string>>;
  Built: TList<TDcGroup>;
  Members: TArray<string>;
begin
  BuildGraph;

  Built := TList<TDcGroup>.Create;
  try
    Raw := FindGroups;
    for Members in Raw do
      Built.Add( DescribeGroup( Members ) );

    { Most dangerous first, then the biggest - an uncompilable group outranks a fragile one,
      and a fragile one outranks a large benign mesh however impressive the mesh looks. }
    Built.Sort( TComparer<TDcGroup>.Construct(
      function( const A, B: TDcGroup ): Integer
      begin
        Result := Ord( B.Kind ) - Ord( A.Kind );
        if Result = 0 then
          Result := Length( B.Units ) - Length( A.Units );
        if ( Result = 0 ) and ( Length( A.Units ) > 0 ) and ( Length( B.Units ) > 0 ) then
          Result := CompareText( A.Units[ 0 ], B.Units[ 0 ] );
      end ) );
    FGroups := Built.ToArray;
  finally
    Built.Free;
  end;
end;

function TDecirculariser.Report: string;
var
  sb: TStringBuilder;
  Group: TDcGroup;
  Candidate: TDcBreakCandidate;
  I, iShown: Integer;
  iFragile, iUncompilable: Integer;
begin
  sb := TStringBuilder.Create;
  try
    sb.AppendLine( 'Circular unit references' );
    sb.AppendLine( '========================' );
    sb.AppendLine( Format( 'Units analysed: %d    Edges between them: %d',
      [ FSources.Count, FEdges.Count ] ) );
    sb.AppendLine;

    if Length( FGroups ) = 0 then
    begin
      sb.AppendLine( 'No entangled groups. Every unit dependency in this set is acyclic.' );
      Exit( sb.ToString );
    end;

    iFragile      := 0;
    iUncompilable := 0;
    for Group in FGroups do
      if Group.Kind = dcgFragile then
        Inc( iFragile )
      else if Group.Kind = dcgUncompilable then
        Inc( iUncompilable );

    sb.AppendLine( Format( '%d entangled group(s): %d uncompilable, %d FRAGILE, %d benign.',
      [ Length( FGroups ), iUncompilable, iFragile,
        Length( FGroups ) - iFragile - iUncompilable ] ) );
    if iFragile > 0 then
    begin
      sb.AppendLine;
      sb.AppendLine( 'A FRAGILE group is held together by a single implementation-section edge, so the' );
      sb.AppendLine( 'opposite direction is already an interface use. Promote that one uses clause and' );
      sb.AppendLine( 'the build stops with E2004. Nothing warns you until it does.' );
    end;
    sb.AppendLine;

    for I := 0 to High( FGroups ) do
    begin
      Group := FGroups[ I ];
      sb.AppendLine( Format( '[%d] %s - %d units, %d interface / %d implementation edges',
        [ I + 1, DcGroupKindToStr( Group.Kind ), Length( Group.Units ),
          Group.InterfaceEdgeCount, Group.ImplementationEdgeCount ] ) );
      sb.AppendLine( '    ' + string.Join( '  ', Group.Units ) );

      if Length( Group.Candidates ) = 0 then
      begin
        sb.AppendLine( '    No implementation edge to cut. A group that compiles always has one, so' );
        sb.AppendLine( '    either the analysed set is partial or these sources do not compile.' );
        sb.AppendLine;
        Continue;
      end;

      iShown := 0;
      for Candidate in Group.Candidates do
      begin
        sb.AppendLine( Format( '    %s -> %s  (line %d)  %s',
          [ Candidate.Edge.FromUnit, Candidate.Edge.ToUnit, Candidate.Edge.LineNumber,
            DcVerdictToStr( Candidate.Verdict ) ] ) );
        sb.AppendLine( '        ' + Candidate.Advice );
        Inc( iShown );
        if iShown >= 5 then
        begin
          if Length( Group.Candidates ) > iShown then
            sb.AppendLine( Format( '    ... and %d more edge(s) in this group.',
              [ Length( Group.Candidates ) - iShown ] ) );
          Break;
        end;
      end;
      sb.AppendLine;
    end;

    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

end.
