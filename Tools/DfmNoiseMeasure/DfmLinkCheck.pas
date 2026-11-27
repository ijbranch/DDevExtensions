{******************************************************************************}
{*                                                                            *}
{* DfmLinkCheck - checks the links between modules across a set of .dfm files *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit DfmLinkCheck;

/// <summary>
/// The decisions of <c>DfmNoiseMeasure links</c>, on texts only ( the command reads the files ).  An index of
/// every module's <c>.dfm</c> answers whether a <c>Module.Component</c> link has a target; a form's links are
/// checked against it; and a link the DFM Link Guard's rule finds lost in a past save is classified by the
/// file as it is today.  RTL only.
/// </summary>

interface

uses
  System.SysUtils, System.Generics.Collections, DfmLinkGuardCore;

type
  /// <summary>Why a link in today's file has no target.</summary>
  TDfmDanglingKind = (
    /// <summary>The module exists, but no <c>.dfm</c> with that root declares the component.</summary>
    dkComponentMissing,
    /// <summary>No <c>.dfm</c> in the index has that root name ( a module renamed or deleted ).</summary>
    dkModuleNotFound );

  /// <summary>A link in today's file whose target cannot be found.</summary>
  TDfmDanglingLink = record
    /// <summary>The component holding the link, as a dotted path from the root.</summary>
    Path: string;
    /// <summary>The property holding the link.</summary>
    PropName: string;
    /// <summary>The link, <c>Module.Component</c>.</summary>
    Value: string;
    /// <summary>Why it has no target.</summary>
    Kind: TDfmDanglingKind;
  end;

  /// <summary>What today's file says about a link a past save lost.</summary>
  TDfmLossToday = (
    /// <summary>The same property of the same component holds the link again.</summary>
    ltRestored,
    /// <summary>The link is not back on that property, but another property holds exactly that value ( moved ).</summary>
    ltValueElsewhere,
    /// <summary>The component that held the link is no longer in the file.</summary>
    ltComponentGone,
    /// <summary>The file is no longer there ( or is binary ).</summary>
    ltFileGone,
    /// <summary>The component is there, and the link is nowhere in the file: still lost.</summary>
    ltStillLost );

  /// <summary>
  /// The root names of a set of <c>.dfm</c> texts, each with the repository it came from, to answer whether a
  /// <c>Module.Component</c> link has a target.
  /// </summary>
  TDfmModuleIndex = class
  private
    /// <summary>Root name -> the modules with that root, case-insensitive.</summary>
    FModules: TObjectDictionary<string, TList<TPair<string, string>>>;
    /// <summary>Backing for <see cref="ModuleCount"/>.</summary>
    /// <returns>The number of distinct root names.</returns>
    function GetModuleCount: Integer;
  public
    /// <summary>Creates an empty index.</summary>
    constructor Create;
    /// <summary>Frees the index.</summary>
    destructor Destroy; override;
    /// <summary>Adds one module's text; a text with no root object is ignored.</summary>
    /// <param name="Repo">The repository ( or any group name ) the file belongs to.</param>
    /// <param name="DfmText">The <c>.dfm</c> text.</param>
    procedure Add( const Repo, DfmText: string );
    /// <summary>Whether any text in the index has this root name.</summary>
    /// <param name="ModuleName">The root name.</param>
    /// <returns>True when known.</returns>
    function IsKnownModule( const ModuleName: string ): Boolean;
    /// <summary>
    /// Whether a module of that root name declares the component.  The modules of the link's own repository are
    /// asked when it has any of that name ( several applications each have a <c>MainForm</c> ); otherwise every
    /// repository's ( a shared data module ).
    /// </summary>
    /// <param name="Repo">The repository of the file holding the link.</param>
    /// <param name="ModuleName">The linked module's root name.</param>
    /// <param name="ComponentName">The linked component's name.</param>
    /// <returns>True when the target exists.</returns>
    function TargetExists( const Repo, ModuleName, ComponentName: string ): Boolean;
    /// <summary>The number of distinct root names.</summary>
    property ModuleCount: Integer read GetModuleCount;
  end;

/// <summary>
/// Finds every link in a <c>.dfm</c> text to another module's component ( a value <c>Name.Name</c> whose first
/// name is not this form's root and not a component of this form, such as an embedded frame ) and returns the
/// ones whose target the index cannot find.
/// </summary>
/// <param name="Index">Every module's text.</param>
/// <param name="Repo">The repository of this text.</param>
/// <param name="DfmText">The <c>.dfm</c> text.</param>
/// <param name="LinkCount">Set to the number of links to another module found, with or without a target.</param>
/// <returns>The links without a target; empty when all resolve.</returns>
function FindDanglingLinks( Index: TDfmModuleIndex; const Repo, DfmText: string; out LinkCount: Integer ): TArray<TDfmDanglingLink>;

/// <summary>Classifies a link a past save lost by the file as it is today.</summary>
/// <param name="Link">The lost link, as <c>FindLostModuleLinks</c> reported it.</param>
/// <param name="TodayText">Today's text of the same file; empty when the file is gone or binary.</param>
/// <returns>Its state today.</returns>
function LossToday( const Link: TDfmLostLink; const TodayText: string ): TDfmLossToday;

/// <summary>A short name for a state, as the CSV writes it.</summary>
/// <param name="State">The state.</param>
/// <returns>The name.</returns>
function LossTodayName( State: TDfmLossToday ): string;

/// <summary>A short name for a dangling kind, as the CSV writes it.</summary>
/// <param name="Kind">The kind.</param>
/// <returns>The name.</returns>
function DanglingKindName( Kind: TDfmDanglingKind ): string;

implementation

uses
  System.StrUtils, System.Generics.Defaults, gllDelphiDFMParser;

/// <summary>Splits a value of exactly two names joined by one dot ( <c>dmMain.dsCustomers</c> ).</summary>
/// <param name="Value">The trimmed raw value.</param>
/// <param name="First">Set to the first name.</param>
/// <param name="Second">Set to the second name.</param>
/// <returns>True when the value has that shape.</returns>
function SplitDottedPair( const Value: string; out First, Second: string ): Boolean;

  function IsName( const S: string ): Boolean;
  begin
    Result          := ( S <> '' ) and CharInSet( S[ 1 ], [ 'A'..'Z', 'a'..'z', '_' ] );
    for var iI := 2 to Length( S ) do
      if not CharInSet( S[ iI ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) then Exit( False );
  end;

begin
  var iDot          := Pos( '.', Value );
  First             := Copy( Value, 1, iDot - 1 );
  Second            := Copy( Value, iDot + 1, MaxInt );
  Result            := ( iDot > 0 ) and IsName( First ) and IsName( Second );
end;

/// <summary>Finds a component by the dotted path <c>FindLostModuleLinks</c> reports ( root name first ).</summary>
/// <param name="Root">The document's root.</param>
/// <param name="Path">The path.</param>
/// <returns>The component; nil when any step is missing.</returns>
function FindByPath( Root: TDfmComponent; const Path: string ): TDfmComponent;
begin
  var aParts        := Path.Split( [ '.' ] );
  if ( Length( aParts ) = 0 ) or not SameText( aParts[ 0 ], Root.Name ) then Exit( nil );
  Result            := Root;
  for var iI := 1 to High( aParts ) do
  begin
    Result          := Result.FindChild( aParts[ iI ] );
    if Result = nil then Exit;
  end;
end;

{ TDfmModuleIndex }

constructor TDfmModuleIndex.Create;
begin
  inherited Create;
  FModules          := TObjectDictionary<string, TList<TPair<string, string>>>.Create( [ doOwnsValues ], TIStringComparer.Ordinal );
end;

destructor TDfmModuleIndex.Destroy;
begin
  FModules.Free;
  inherited Destroy;
end;

function TDfmModuleIndex.GetModuleCount: Integer;
begin
  Result            := FModules.Count;
end;

procedure TDfmModuleIndex.Add( const Repo, DfmText: string );
begin
  var sRoot         := DfmRootName( DfmText ); // empty for a text with no object header
  if sRoot = '' then Exit;
  var oList         : TList<TPair<string, string>>;
  if not FModules.TryGetValue( sRoot, oList ) then
  begin
    oList           := TList<TPair<string, string>>.Create;
    FModules.Add( sRoot, oList );
  end;
  oList.Add( TPair<string, string>.Create( Repo, DfmText ) );
end;

function TDfmModuleIndex.IsKnownModule( const ModuleName: string ): Boolean;
begin
  Result            := FModules.ContainsKey( ModuleName );
end;

function TDfmModuleIndex.TargetExists( const Repo, ModuleName, ComponentName: string ): Boolean;
begin
  Result            := False;
  var oList         : TList<TPair<string, string>>;
  if not FModules.TryGetValue( ModuleName, oList ) then Exit;

  var bOwnRepo      := False;
  for var rModule in oList do
    if SameText( rModule.Key, Repo ) then
    begin
      bOwnRepo      := True;
      if DfmDeclaresComponent( rModule.Value, ComponentName ) then Exit( True );
    end;
  if bOwnRepo then Exit;

  for var rModule in oList do
    if DfmDeclaresComponent( rModule.Value, ComponentName ) then Exit( True );
end;

/// <summary>Adds the name of a component and of every descendant to a set.</summary>
/// <param name="Component">The component to walk.</param>
/// <param name="Names">The set, case-insensitive.</param>
procedure CollectNames( Component: TDfmComponent; Names: TDictionary<string, Boolean> );
begin
  if Component.Name <> '' then Names.AddOrSetValue( Component.Name, True );
  for var oChild in Component.Children do
    CollectNames( oChild, Names );
end;

function FindDanglingLinks( Index: TDfmModuleIndex; const Repo, DfmText: string; out LinkCount: Integer ): TArray<TDfmDanglingLink>;
var
  aResult           : TArray<TDfmDanglingLink>;
  iLinks            : Integer;
  dLocal            : TDictionary<string, Boolean>;
  sOwnRoot          : string;

  procedure Walk( Component: TDfmComponent; const Path: string );
  begin
    for var oProp in Component.Properties do
    begin
      var sModule, sComponent: string;
      if not SplitDottedPair( Trim( oProp.RawValue ), sModule, sComponent ) then Continue;
      // The form's own root: not a link to another module, but its component must still be in this form.
      if SameText( sModule, sOwnRoot ) then
      begin
        if not DfmDeclaresComponent( DfmText, sComponent ) then
        begin
          var rOwn  : TDfmDanglingLink;
          rOwn.Path := Path;
          rOwn.PropName := oProp.Name;
          rOwn.Value := sModule + '.' + sComponent;
          rOwn.Kind := dkComponentMissing;
          aResult   := aResult + [ rOwn ];
        end;
        Continue;
      end;
      // One of the form's own components ( an embedded frame ): not a link to another module.
      if dLocal.ContainsKey( sModule ) then Continue;
      Inc( iLinks );
      var rLink     : TDfmDanglingLink;
      if not Index.IsKnownModule( sModule ) then rLink.Kind := dkModuleNotFound
      else if not Index.TargetExists( Repo, sModule, sComponent ) then rLink.Kind := dkComponentMissing
      else Continue;
      rLink.Path    := Path;
      rLink.PropName := oProp.Name;
      rLink.Value   := sModule + '.' + sComponent;
      aResult       := aResult + [ rLink ];
    end;
    for var oChild in Component.Children do
      Walk( oChild, Path + '.' + IfThen( oChild.Name <> '', oChild.Name, oChild.TypeName ) );
  end;

begin
  aResult           := nil;
  iLinks            := 0;
  var oDoc          := TDelphiDfmParser.Parse( DfmText );
  dLocal            := TDictionary<string, Boolean>.Create( TIStringComparer.Ordinal );
  try
    // The parser always gives a root; for a text with no object header it is empty, and has no properties.
    sOwnRoot        := oDoc.Root.Name;
    CollectNames( oDoc.Root, dLocal );
    Walk( oDoc.Root, oDoc.Root.Name );
  finally
    dLocal.Free;
    oDoc.Free;
  end;
  LinkCount         := iLinks;
  Result            := aResult;
end;

/// <summary>Whether a component or any descendant has a property whose trimmed value is exactly this one ( any case ).</summary>
/// <param name="Component">The component to walk.</param>
/// <param name="Value">The value.</param>
/// <returns>True when found.</returns>
function HoldsValue( Component: TDfmComponent; const Value: string ): Boolean;
begin
  for var oProp in Component.Properties do
    if SameText( Trim( oProp.RawValue ), Value ) then Exit( True );
  for var oChild in Component.Children do
    if HoldsValue( oChild, Value ) then Exit( True );
  Result            := False;
end;

function LossToday( const Link: TDfmLostLink; const TodayText: string ): TDfmLossToday;
begin
  if TodayText = '' then Exit( ltFileGone );
  var oDoc          := TDelphiDfmParser.Parse( TodayText );
  try
    var oComponent  := FindByPath( oDoc.Root, Link.Path );
    if oComponent = nil then Exit( ltComponentGone );
    var oProp       := oComponent.FindProperty( Link.PropName );
    if ( oProp <> nil ) and SameText( Trim( oProp.RawValue ), Link.Value ) then Exit( ltRestored );
    // Exactly that value on another property or component: text inside a caption, or the start of a longer
    // name, is not the link.
    if HoldsValue( oDoc.Root, Link.Value ) then Exit( ltValueElsewhere );
    Result          := ltStillLost;
  finally
    oDoc.Free;
  end;
end;

function LossTodayName( State: TDfmLossToday ): string;
const
  CNames: array[ TDfmLossToday ] of string = ( 'restored', 'value elsewhere in file', 'component gone', 'file gone', 'STILL LOST' );
begin
  Result            := CNames[ State ];
end;

function DanglingKindName( Kind: TDfmDanglingKind ): string;
const
  CNames: array[ TDfmDanglingKind ] of string = ( 'COMPONENT MISSING', 'MODULE NOT FOUND' );
begin
  Result            := CNames[ Kind ];
end;

end.
