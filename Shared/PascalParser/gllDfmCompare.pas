{******************************************************************************}
{*                                                                            *}
{* gllDfmCompare - compares two texts of one .dfm, component by component    *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit gllDfmCompare;

/// <summary>
/// Compares two texts of one <c>.dfm</c> ( before and after a save ) component by component and
/// sorts every difference into a category: the noise the IDE is known to write ( <c>Explicit*</c>,
/// <c>PixelsPerInch</c>, <c>TextHeight</c>, <c>DesignSize</c>, shifted <c>[n]</c> indexes,
/// reordering ), links the IDE drops ( image lists, components of other modules ) and everything
/// else.  Also proves the DFM parser round-trips a file byte for byte.  Pure RTL plus
/// <c>gllDelphiDFMParser</c>, so the DUnitX suite tests it directly.
/// </summary>
/// <remarks>
/// Built to measure, before any design work, how much DFM noise our cleaners still leave behind
/// ( recommendation of 2026-11-28, after reviewing Cesar Romero's delphi-dfm-noise-filter ).  Used by
/// <c>Tools\DfmNoiseMeasure</c> and by the DFM Link Guard in the DDevExtensions DLL.
/// </remarks>

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, gllDelphiDFMParser;

type
  /// <summary>Raised when a text cannot be compared because it has no root object.</summary>
  EDfmCompareError = class( Exception );

  /// <summary>What kind of difference one change is.</summary>
  TDfmChangeKind = (
    dckPropertyAdded, //< The property is only in the new text.
    dckPropertyRemoved, //< The property is only in the old text.
    dckPropertyChanged, //< The property is in both, with different values.
    dckComponentAdded, //< The component is only in the new text.
    dckComponentRemoved, //< The component is only in the old text.
    dckTypeChanged, //< The component's class or keyword changed.
    dckOrderIndexChanged, //< The <c>[n]</c> index of an inherited component changed.
    dckChildrenReordered, //< The same child components, in another order.
    dckPropertiesReordered //< The same properties, in another order.
    );

  /// <summary>The category a change is counted under.</summary>
  TDfmNoiseCategory = (
    ncExplicit, //< <c>ExplicitLeft/Top/Width/Height</c>.
    ncPixelsPerInch, //< <c>PixelsPerInch</c>.
    ncTextHeight, //< <c>TextHeight</c>.
    ncDesignSize, //< <c>DesignSize</c>.
    ncOrderIndex, //< A shifted <c>[n]</c> index.
    ncChildOrder, //< Child components reordered.
    ncPropertyOrder, //< Properties reordered.
    ncModuleLinkLost, //< A link to a component of another module ( <c>Module.Name</c> ) removed.
    ncImageLinkLost, //< An <c>Images</c>, <c>ImageIndex</c> or <c>ImageName</c> property removed.
    ncGeometry, //< <c>Left</c>, <c>Top</c>, <c>Width</c>, <c>Height</c>, <c>ClientWidth</c> or <c>ClientHeight</c> changed.
    ncFont, //< A <c>Font.*</c> property added, removed or changed.
    ncComponent, //< A component added, removed or retyped: an edit, not noise.
    ncOther //< Anything else.
    );

  /// <summary>One difference between the old and the new text of a DFM.</summary>
  TDfmChange = record
    /// <summary>Dotted component path, the root's name first ( <c>Form1.Panel1.Button1</c> ).</summary>
    Path: string;
    /// <summary>Property name; empty for a component-level change.</summary>
    PropName: string;
    /// <summary>What changed.</summary>
    Kind: TDfmChangeKind;
    /// <summary>Old raw value ( or old header detail ); empty when there was none.</summary>
    OldValue: string;
    /// <summary>New raw value ( or new header detail ); empty when there is none.</summary>
    NewValue: string;
    /// <summary>The category it is counted under.</summary>
    Category: TDfmNoiseCategory;
  end;

/// <summary>Compares the old and the new text of one DFM.</summary>
/// <param name="OldText">The text before the save.</param>
/// <param name="NewText">The text after the save.</param>
/// <returns>Every difference, classified; empty when the two parse to the same tree.</returns>
/// <exception cref="EDfmCompareError">Either text has no root object ( empty, or not a text DFM ).</exception>
function CompareDfmText( const OldText, NewText: string ): TArray<TDfmChange>;

/// <summary>Classifies one change by its kind, property name and values.</summary>
/// <param name="Change">The change; its <c>Category</c> is ignored.</param>
/// <returns>The category to count it under.</returns>
function ClassifyChange( const Change: TDfmChange ): TDfmNoiseCategory;

/// <summary>Whether a category is noise the IDE writes on its own, never a user's edit.</summary>
/// <param name="Category">The category.</param>
/// <returns>True for <c>Explicit*</c>, <c>PixelsPerInch</c>, <c>TextHeight</c>, <c>DesignSize</c>, <c>[n]</c> shifts and reordering.</returns>
function IsKnownIdeNoise( Category: TDfmNoiseCategory ): Boolean;

/// <summary>A short display name for a category.</summary>
/// <param name="Category">The category.</param>
/// <returns>The name used in reports.</returns>
function CategoryName( Category: TDfmNoiseCategory ): string;

/// <summary>A short display name for a change kind.</summary>
/// <param name="Kind">The kind.</param>
/// <returns>The name used in reports.</returns>
function ChangeKindName( Kind: TDfmChangeKind ): string;

/// <summary>Whether file bytes are a binary DFM resource rather than text.</summary>
/// <param name="Bytes">The file's bytes.</param>
/// <returns>True when they start with <c>TPF0</c> or the resource header <c>$FF $0A</c>.</returns>
function IsBinaryDfm( const Bytes: TBytes ): Boolean;

/// <summary>
/// Decodes file bytes one byte per character ( ISO-8859-1 ), so ANSI and UTF-8 files alike come
/// back to the very same bytes through <see cref="DfmTextToBytes"/>; the DFM structure is ASCII.
/// </summary>
/// <param name="Bytes">The file's bytes.</param>
/// <returns>The text, one character per byte.</returns>
function DfmBytesToText( const Bytes: TBytes ): string;

/// <summary>Encodes text made by <see cref="DfmBytesToText"/> back to the original bytes.</summary>
/// <param name="Text">The text.</param>
/// <returns>The bytes, one per character.</returns>
function DfmTextToBytes( const Text: string ): TBytes;

/// <summary>Parses and re-serialises a text DFM and reports whether the bytes come back unchanged.</summary>
/// <param name="Bytes">The file's bytes ( a text DFM ).</param>
/// <param name="FirstDifference">
/// On a mismatch, the 1-based line number and both versions of the first line that differs;
/// empty when the bytes match.
/// </param>
/// <returns>True when serialising the parsed text gives exactly the original bytes.</returns>
function RoundTripsExactly( const Bytes: TBytes; out FirstDifference: string ): Boolean;

implementation

uses
  System.StrUtils;

const
  /// <summary>The <c>Explicit*</c> properties the VCL writes to remember a control's undocked bounds.</summary>
  CExplicitProps: array[ 0..3 ] of string = ( 'ExplicitLeft', 'ExplicitTop', 'ExplicitWidth', 'ExplicitHeight' );
  /// <summary>Bounds properties: changed by a user's move, and also by DPI scaling.</summary>
  CGeometryProps: array[ 0..5 ] of string = ( 'Left', 'Top', 'Width', 'Height', 'ClientWidth', 'ClientHeight' );

var
  /// <summary>ISO-8859-1, one byte per character in both directions; created at start-up, freed at shut-down.</summary>
  GLatin1: TEncoding;

function CategoryName( Category: TDfmNoiseCategory ): string;
begin
  case Category of
    ncExplicit: Result := 'Explicit*';
    ncPixelsPerInch: Result := 'PixelsPerInch';
    ncTextHeight: Result := 'TextHeight';
    ncDesignSize: Result := 'DesignSize';
    ncOrderIndex: Result := '[n] index shift';
    ncChildOrder: Result := 'Child order';
    ncPropertyOrder: Result := 'Property order';
    ncModuleLinkLost: Result := 'Other-module link removed';
    ncImageLinkLost: Result := 'Image link removed';
    ncGeometry: Result := 'Geometry';
    ncFont: Result := 'Font';
    ncComponent: Result := 'Component added/removed/retyped';
  else
    Result          := 'Other';
  end;
end;

function ChangeKindName( Kind: TDfmChangeKind ): string;
begin
  case Kind of
    dckPropertyAdded: Result := 'added';
    dckPropertyRemoved: Result := 'removed';
    dckPropertyChanged: Result := 'changed';
    dckComponentAdded: Result := 'component added';
    dckComponentRemoved: Result := 'component removed';
    dckTypeChanged: Result := 'type changed';
    dckOrderIndexChanged: Result := 'index changed';
    dckChildrenReordered: Result := 'children reordered';
  else
    Result          := 'properties reordered';
  end;
end;

function IsKnownIdeNoise( Category: TDfmNoiseCategory ): Boolean;
begin
  Result            := Category in [ ncExplicit, ncPixelsPerInch, ncTextHeight, ncDesignSize, ncOrderIndex, ncChildOrder, ncPropertyOrder ];
end;

/// <summary>Whether a raw value is an unquoted reference to a component of another module.</summary>
/// <param name="RawValue">The raw value text.</param>
/// <returns>True for <c>Module.Component</c>: two identifiers joined by one dot, nothing else.</returns>
function IsOtherModuleReference( const RawValue: string ): Boolean;
begin
  var sValue        := Trim( RawValue );
  var iDot          := Pos( '.', sValue );
  Result            := ( iDot > 1 ) and ( iDot < Length( sValue ) ) and ( Pos( '.', sValue, iDot + 1 ) = 0 ) and
    IsValidIdent( Copy( sValue, 1, iDot - 1 ) ) and IsValidIdent( Copy( sValue, iDot + 1, MaxInt ) );
end;

function ClassifyChange( const Change: TDfmChange ): TDfmNoiseCategory;
begin
  case Change.Kind of
    dckComponentAdded, dckComponentRemoved, dckTypeChanged: Exit( ncComponent );
    dckOrderIndexChanged: Exit( ncOrderIndex );
    dckChildrenReordered: Exit( ncChildOrder );
    dckPropertiesReordered: Exit( ncPropertyOrder );
  end;

  var sName         := Change.PropName;
  if MatchText( sName, CExplicitProps ) then Exit( ncExplicit );
  if SameText( sName, 'PixelsPerInch' ) then Exit( ncPixelsPerInch );
  if SameText( sName, 'TextHeight' ) then Exit( ncTextHeight );
  if SameText( sName, 'DesignSize' ) then Exit( ncDesignSize );

  if Change.Kind = dckPropertyRemoved then
  begin
    if IsOtherModuleReference( Change.OldValue ) then Exit( ncModuleLinkLost );
    if EndsText( 'Images', sName ) or EndsText( 'ImageIndex', sName ) or EndsText( 'ImageName', sName ) then Exit( ncImageLinkLost );
  end;

  if StartsText( 'Font.', sName ) or ContainsText( sName, '.Font.' ) then Exit( ncFont );
  if ( Change.Kind = dckPropertyChanged ) and MatchText( sName, CGeometryProps ) then Exit( ncGeometry );

  Result            := ncOther;
end;

/// <summary>The key a child component is matched by: its name, or for an unnamed one its class and position.</summary>
/// <param name="Component">The child.</param>
/// <param name="Index">Its position among its siblings.</param>
/// <returns>The key, compared case-insensitively.</returns>
function ChildKey( Component: TDfmComponent; Index: Integer ): string;
begin
  if Component.Name <> '' then
    Result          := UpperCase( Component.Name )
  else
    Result          := '#' + UpperCase( Component.TypeName ) + '#' + IntToStr( Index );
end;

/// <summary>The keyword a component was declared with, for a header comparison.</summary>
/// <param name="Kind">The object kind.</param>
/// <returns><c>object</c>, <c>inherited</c> or <c>inline</c>.</returns>
function KeywordOf( Kind: TDfmObjectKind ): string;
begin
  case Kind of
    dokInherited: Result := 'inherited';
    dokInline: Result := 'inline';
  else
    Result          := 'object';
  end;
end;

type
  /// <summary>Walks two parsed trees side by side and collects the differences.</summary>
  TDfmComparer = class
  private
    /// <summary>The differences found so far.</summary>
    FChanges: TList<TDfmChange>;
    /// <summary>Adds one change, classified.</summary>
    /// <param name="Path">Component path.</param>
    /// <param name="PropName">Property name, or empty.</param>
    /// <param name="Kind">What changed.</param>
    /// <param name="OldValue">Old value, or empty.</param>
    /// <param name="NewValue">New value, or empty.</param>
    procedure Add( const Path, PropName: string; Kind: TDfmChangeKind; const OldValue, NewValue: string );
    /// <summary>Compares the property lists of two matched components.</summary>
    /// <param name="Path">Their path.</param>
    /// <param name="OldComp">The old component.</param>
    /// <param name="NewComp">The new component.</param>
    procedure CompareProperties( const Path: string; OldComp, NewComp: TDfmComponent );
    /// <summary>Records every property and child of a component added or removed whole, as one component change.</summary>
    /// <param name="Path">The component's path.</param>
    /// <param name="Comp">The component.</param>
    /// <param name="Kind"><c>dckComponentAdded</c> or <c>dckComponentRemoved</c>.</param>
    procedure AddWholeComponent( const Path: string; Comp: TDfmComponent; Kind: TDfmChangeKind );
  public
    /// <summary>Creates the comparer with an empty change list.</summary>
    constructor Create;
    /// <summary>Frees the change list.</summary>
    destructor Destroy; override;
    /// <summary>Compares two matched components and, recursively, their children.</summary>
    /// <param name="Path">Their path.</param>
    /// <param name="OldComp">The old component.</param>
    /// <param name="NewComp">The new component.</param>
    procedure CompareComponents( const Path: string; OldComp, NewComp: TDfmComponent );
    /// <summary>The differences found.</summary>
    property Changes: TList<TDfmChange> read FChanges;
  end;

constructor TDfmComparer.Create;
begin
  inherited Create;
  FChanges          := TList<TDfmChange>.Create;
end;

destructor TDfmComparer.Destroy;
begin
  FChanges.Free;
  inherited Destroy;
end;

procedure TDfmComparer.Add( const Path, PropName: string; Kind: TDfmChangeKind; const OldValue, NewValue: string );
var
  rChange           : TDfmChange;
begin
  rChange.Path      := Path;
  rChange.PropName  := PropName;
  rChange.Kind      := Kind;
  rChange.OldValue  := OldValue;
  rChange.NewValue  := NewValue;
  rChange.Category  := ClassifyChange( rChange );
  FChanges.Add( rChange );
end;

procedure TDfmComparer.AddWholeComponent( const Path: string; Comp: TDfmComponent; Kind: TDfmChangeKind );
begin
  if Kind = dckComponentAdded then
    Add( Path, '', Kind, '', Comp.TypeName )
  else
    Add( Path, '', Kind, Comp.TypeName, '' );
end;

procedure TDfmComparer.CompareProperties( const Path: string; OldComp, NewComp: TDfmComponent );
begin
  var slOldOrder    := TStringList.Create;
  var slNewOrder    := TStringList.Create;
  try
    for var oOld in OldComp.Properties do
    begin
      var oNew      := NewComp.FindProperty( oOld.Name );
      if oNew = nil then
        Add( Path, oOld.Name, dckPropertyRemoved, oOld.RawValue, '' )
      else
      begin
        slOldOrder.Add( UpperCase( oOld.Name ) );
        if oOld.RawValue <> oNew.RawValue then Add( Path, oOld.Name, dckPropertyChanged, oOld.RawValue, oNew.RawValue );
      end;
    end;

    for var oNew in NewComp.Properties do
    begin
      if OldComp.FindProperty( oNew.Name ) = nil then
        Add( Path, oNew.Name, dckPropertyAdded, '', oNew.RawValue )
      else
        slNewOrder.Add( UpperCase( oNew.Name ) );
    end;

    if slOldOrder.Text <> slNewOrder.Text then Add( Path, '', dckPropertiesReordered, '', '' );
  finally
    slNewOrder.Free;
    slOldOrder.Free;
  end;
end;

procedure TDfmComparer.CompareComponents( const Path: string; OldComp, NewComp: TDfmComponent );
begin
  if ( OldComp.ObjectKind <> NewComp.ObjectKind ) or not SameText( OldComp.TypeName, NewComp.TypeName ) then
    Add( Path, '', dckTypeChanged, KeywordOf( OldComp.ObjectKind ) + ' ' + OldComp.TypeName,
      KeywordOf( NewComp.ObjectKind ) + ' ' + NewComp.TypeName );
  if OldComp.OrderIndex <> NewComp.OrderIndex then Add( Path, '', dckOrderIndexChanged, OldComp.OrderIndex, NewComp.OrderIndex );

  CompareProperties( Path, OldComp, NewComp );

  var dNew          := TDictionary<string, TDfmComponent>.Create;
  var slOldOrder    := TStringList.Create;
  var slNewOrder    := TStringList.Create;
  try
    for var I := 0 to NewComp.Children.Count - 1 do
      dNew.AddOrSetValue( ChildKey( NewComp.Children[ I ], I ), NewComp.Children[ I ] );

    var dOldKeys    := TDictionary<string, Boolean>.Create;
    try
      for var I := 0 to OldComp.Children.Count - 1 do
      begin
        var oOld    := OldComp.Children[ I ];
        var sKey    := ChildKey( oOld, I );
        dOldKeys.AddOrSetValue( sKey, True );
        var sChildPath := Path + '.' + IfThen( oOld.Name <> '', oOld.Name, oOld.TypeName );
        var oNew: TDfmComponent;
        if dNew.TryGetValue( sKey, oNew ) then
        begin
          slOldOrder.Add( sKey );
          CompareComponents( sChildPath, oOld, oNew );
        end
        else
          AddWholeComponent( sChildPath, oOld, dckComponentRemoved );
      end;

      for var I := 0 to NewComp.Children.Count - 1 do
      begin
        var oNew    := NewComp.Children[ I ];
        var sKey    := ChildKey( oNew, I );
        if dOldKeys.ContainsKey( sKey ) then
          slNewOrder.Add( sKey )
        else
          AddWholeComponent( Path + '.' + IfThen( oNew.Name <> '', oNew.Name, oNew.TypeName ), oNew, dckComponentAdded );
      end;
    finally
      dOldKeys.Free;
    end;

    if slOldOrder.Text <> slNewOrder.Text then Add( Path, '', dckChildrenReordered, '', '' );
  finally
    slNewOrder.Free;
    slOldOrder.Free;
    dNew.Free;
  end;
end;

function CompareDfmText( const OldText, NewText: string ): TArray<TDfmChange>;
begin
  var oOldDoc       := TDelphiDfmParser.Parse( OldText );
  try
    var oNewDoc     := TDelphiDfmParser.Parse( NewText );
    try
      // The document always holds a root; it is an empty placeholder until an object header is read.
      if ( oOldDoc.Root.TypeName = '' ) or ( oNewDoc.Root.TypeName = '' ) then
        raise EDfmCompareError.Create( 'Cannot compare a DFM text that has no root object' );
      var oComparer := TDfmComparer.Create;
      try
        oComparer.CompareComponents( oNewDoc.Root.Name, oOldDoc.Root, oNewDoc.Root );
        Result      := oComparer.Changes.ToArray;
      finally
        oComparer.Free;
      end;
    finally
      oNewDoc.Free;
    end;
  finally
    oOldDoc.Free;
  end;
end;

function IsBinaryDfm( const Bytes: TBytes ): Boolean;
begin
  Result            := ( ( Length( Bytes ) >= 2 ) and ( Bytes[ 0 ] = $FF ) and ( Bytes[ 1 ] = $0A ) ) or
    ( ( Length( Bytes ) >= 4 ) and ( Bytes[ 0 ] = Ord( 'T' ) ) and ( Bytes[ 1 ] = Ord( 'P' ) ) and
    ( Bytes[ 2 ] = Ord( 'F' ) ) and ( Bytes[ 3 ] = Ord( '0' ) ) );
end;

function DfmBytesToText( const Bytes: TBytes ): string;
begin
  Result            := GLatin1.GetString( Bytes );
end;

function DfmTextToBytes( const Text: string ): TBytes;
begin
  Result            := GLatin1.GetBytes( Text );
end;

function RoundTripsExactly( const Bytes: TBytes; out FirstDifference: string ): Boolean;
begin
  FirstDifference   := '';
  var sOriginal     := DfmBytesToText( Bytes );
  var sSerialised: string;
  var oDoc          := TDelphiDfmParser.Parse( sOriginal );
  try
    sSerialised     := TDelphiDfmParser.Serialize( oDoc );
  finally
    oDoc.Free;
  end;

  var aOut          := DfmTextToBytes( sSerialised );
  Result            := ( Length( aOut ) = Length( Bytes ) ) and ( ( Length( Bytes ) = 0 ) or CompareMem( @aOut[ 0 ], @Bytes[ 0 ], Length( Bytes ) ) );
  if Result then Exit;

  var slOld         := TStringList.Create;
  var slNew         := TStringList.Create;
  try
    slOld.Text      := sOriginal;
    slNew.Text      := sSerialised;
    var iLine       := 0;
    while ( iLine < slOld.Count ) and ( iLine < slNew.Count ) and ( slOld[ iLine ] = slNew[ iLine ] ) do
      Inc( iLine );
    if ( iLine >= slOld.Count ) and ( iLine >= slNew.Count ) then
      FirstDifference := Format( 'same lines; size %d -> %d ( line endings, blank lines or the final line break )', [ Length( Bytes ), Length( aOut ) ] )
    else
      FirstDifference := Format( 'line %d: [%s] -> [%s]', [ iLine + 1, IfThen( iLine < slOld.Count, Trim( slOld[ iLine ] ), '<none>' ),
        IfThen( iLine < slNew.Count, Trim( slNew[ iLine ] ), '<none>' ) ] );
  finally
    slNew.Free;
    slOld.Free;
  end;
end;

initialization
  GLatin1           := TEncoding.GetEncoding( 28591 );

finalization
  GLatin1.Free;

end.
