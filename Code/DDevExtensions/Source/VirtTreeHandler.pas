unit VirtTreeHandler;

/// <summary>
/// Generic adapter that drives the IDE's internal Virtual Tree (the IDE
/// ships its own copy of <c>VirtualTrees</c> inside <c>vclide.bpl</c>) by
/// resolving its methods and properties at run-time via RTTI plus the
/// <c>TreeMethod</c>/<c>TreeImport</c>/<c>TreePropertyAccessor</c> attributes.
/// </summary>
/// <remarks>
/// Because the IDE Virtual Tree types are not exposed through ToolsAPI we
/// cannot link against them directly. <see cref="TIDEVirtualTreeHandler"/>
/// stores a method-of-object pointer for each operation it needs and
/// resolves the address either by RTTI lookup on the tree's type, by
/// property-accessor introspection, or by direct symbol import from
/// <c>vclide.bpl</c>.
/// </remarks>

interface

{$RTTI EXPLICIT METHODS([vcPrivate, vcProtected, vcPublic, vcPublished])
                PROPERTIES([vcPrivate, vcProtected, vcPublic, vcPublished])
                FIELDS([vcPrivate, vcProtected, vcPublic, vcPublished])}

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Controls, Vcl.ImgList, System.Rtti, IDEHooks;

type
  /// <summary>Opaque pointer alias for the IDE Virtual Tree's <c>PVirtualNode</c>.</summary>
  PVirtualNode = type Pointer;

  /// <summary>Subset of <c>TVSTTextType</c> mirrored for the IDE's tree.</summary>
  TVSTTextType = (
    ttNormal, // normal label of the node, this is also the text which can be edited
    ttStatic // static (non-editable) text after the normal text
    );

  /// <summary>Signature mirroring the IDE Virtual Tree's <c>OnGetText</c> event.</summary>
  TVSTGetTextEvent = procedure( Sender: TObject; Node: PVirtualNode; Column: Integer;
    TextType: TVSTTextType; var CellText: WideString ) of object;

  /// <summary>Marker attribute: tag a method-of-object field to be resolved by RTTI method lookup at run-time.</summary>
  TreeMethod = class( TCustomAttribute )
  end;

  /// <summary>Base attribute carrying the property name for getter/setter resolution.</summary>
  TreePropertyAccessor = class( TCustomAttribute )
  private
    /// <summary>Name of the RTTI property to bind to.</summary>
    FPropertyName: string;
  public
    /// <summary>Stores the property name to look up.</summary>
    /// <param name="APropertyName">Name of the tree property whose accessor the tagged field binds to.</param>
    constructor Create( const APropertyName: string );
    /// <summary>Property name to look up via RTTI.</summary>
    property PropertyName: string read FPropertyName;
  end;

  /// <summary>Tags a field as the read-accessor of a tree property.</summary>
  TreePropertyGetter = class( TreePropertyAccessor );
  /// <summary>Tags a field as the write-accessor of a tree property.</summary>
  TreePropertySetter = class( TreePropertyAccessor );

  /// <summary>
  /// Marker attribute: tag a method-of-object field to be resolved by direct
  /// mangled-symbol import from <c>vclide.bpl</c>.
  /// </summary>
  TreeImport = class( TCustomAttribute )
  private
    /// <summary>BCC-mangled function signature exported by <c>vclide.bpl</c>.</summary>
    FSignature: AnsiString;
  public
    /// <summary>Stores the mangled symbol name.</summary>
    /// <param name="ASignature">Mangled export name to import from <c>vclide.bpl</c>.</param>
    constructor Create( const ASignature: AnsiString );
    /// <summary>Mangled function signature used to import the symbol.</summary>
    property Signature: AnsiString read FSignature;
  end;

  /// <summary>
  /// Run-time facade over the IDE's hidden Virtual Tree control: exposes the
  /// tree's enumerator and accessor methods through ordinary Pascal calls.
  /// </summary>
  TIDEVirtualTreeHandler = class( TObject )
  private
    /// <summary>The wrapped IDE Virtual Tree instance.</summary>
    FTree: TCustomControl;

    /// <summary>Imported text getter (<c>TCustomVirtualStringTree.GetText</c>).</summary>
    [ TreeImport( '@Idevirtualtrees@TCustomVirtualStringTree@GetText$qqrp28Idevirtualtrees@TVirtualNodei' ) ]
    FTextGetter: function( Node: PVirtualNode; Column: Integer ): WideString of object;
    /// <summary>Imported selected-state getter.</summary>
    [ TreeImport( '@Idevirtualtrees@TBaseVirtualTree@GetSelected$qqrp28Idevirtualtrees@TVirtualNode' ) ]
    FSelectedGetter: function( Node: PVirtualNode ): Boolean of object;
    /// <summary>Imported selected-state setter.</summary>
    [ TreeImport( '@Idevirtualtrees@TBaseVirtualTree@SetSelected$qqrp28Idevirtualtrees@TVirtualNodeo' ) ]
    FSelectedSetter: procedure( Node: PVirtualNode; Value: Boolean ) of object;
    /// <summary>Imported parent-node getter.</summary>
    [ TreeImport( '@Idevirtualtrees@TBaseVirtualTree@GetNodeParent$qqrp28Idevirtualtrees@TVirtualNode' ) ]
    FNodeParentGetter: function( Node: PVirtualNode ): PVirtualNode of object;

    /// <summary>RTTI-resolved setter for the <c>FocusedNode</c> property.</summary>
    [ TreePropertySetter( 'FocusedNode' ) ]
    FFocusedNodeSetter: procedure( Node: PVirtualNode ) of object;

    /// <summary>Walks every published field of <c>Self</c> and binds it according to its attribute (TreeMethod, TreePropertyAccessor or TreeImport).</summary>
    procedure InitMethods;
    /// <summary>Resolves a tree method by RTTI name and stores the resulting <c>TMethod</c> in <paramref name="M"/>.</summary>
    /// <param name="TreeType">RTTI type of the wrapped tree, or nil.</param>
    /// <param name="MethodName">Name of the tree method to resolve.</param>
    /// <param name="M">Receives a <c>TMethod</c> bound to the tree; its code is <c>NotSupported</c> when the method is not found.</param>
    procedure GetMethod( TreeType: TRttiType; const MethodName: string; var M );
    /// <summary>Resolves a property getter or setter by RTTI name and stores the resulting <c>TMethod</c> in <paramref name="M"/>.</summary>
    /// <param name="TreeType">RTTI type of the wrapped tree, or nil.</param>
    /// <param name="PropertyName">Name of the tree property whose accessor is wanted.</param>
    /// <param name="Setter">True for the write accessor, False for the read accessor.</param>
    /// <param name="M">Receives a <c>TMethod</c> bound to the tree; its code is <c>NotSupported</c> when the property is not found.</param>
    procedure GetProperty( TreeType: TRttiType; const PropertyName: string; Setter: Boolean; var M );

    /// <summary>Returns the text of the given column on the given node.</summary>
    /// <param name="Node">Tree node to query.</param>
    /// <param name="Column">Zero-based column index.</param>
    /// <returns>The cell text.</returns>
    function GetText( Node: PVirtualNode; Column: Integer ): string;
    /// <summary>Returns whether the node is selected.</summary>
    /// <param name="Node">Tree node to query.</param>
    /// <returns>True when the node is selected.</returns>
    function GetSelected( Node: PVirtualNode ): Boolean;
    /// <summary>Sets the node's selected state.</summary>
    /// <param name="Node">Tree node to change.</param>
    /// <param name="Value">True to select the node, False to deselect it.</param>
    procedure SetSelected( Node: PVirtualNode; const Value: Boolean );
    /// <summary>Returns the currently focused node, or nil.</summary>
    /// <returns>The tree's focused node, or nil.</returns>
    function GetFocusedNode: PVirtualNode;
    /// <summary>Focuses the given node.</summary>
    /// <param name="Node">Node to focus.</param>
    procedure SetFocusedNode( Node: PVirtualNode );
    /// <summary>Returns the tree's <c>Images</c> property reflected via RTTI.</summary>
    /// <returns>The tree's image list, or nil when none is assigned.</returns>
    function GetImages: TCustomImageList;
    /// <summary>Returns the parent of the given node, or nil for top-level nodes.</summary>
    /// <param name="Node">Tree node to query.</param>
    /// <returns>The parent node, or nil for a top-level node.</returns>
    function GetNodeParent( Node: PVirtualNode ): PVirtualNode;
    /// <summary>Returns the tree's <c>OnGetText</c> handler.</summary>
    /// <returns>The handler currently assigned to the tree's <c>OnGetText</c> event.</returns>
    function GetOnGetText: TVSTGetTextEvent;
    /// <summary>Installs an <c>OnGetText</c> handler on the tree.</summary>
    /// <param name="Value">Handler to assign to the tree's <c>OnGetText</c> event.</param>
    procedure SetOnGetText( const Value: TVSTGetTextEvent );
  public
    /// <summary>Wraps <paramref name="ATree"/> and binds every accessor field.</summary>
    /// <param name="ATree">The IDE Virtual Tree control to wrap; not owned.</param>
    constructor Create( ATree: TCustomControl );
    /// <summary>Forwards a synthetic <c>DblClick</c> to the wrapped tree.</summary>
    procedure DblClick;
    /// <summary>Invalidates the wrapped tree's display.</summary>
    procedure Invalidate;

    /// <summary>The wrapped IDE Virtual Tree instance.</summary>
    property Tree: TCustomControl read FTree;
  public
    /// <summary>Returns the first node, or nil if the tree is empty.</summary>
    [ TreeMethod ]GetFirst: function: PVirtualNode of object;
    /// <summary>Returns the first selected node, or nil.</summary>
    [ TreeMethod ]GetFirstSelected: function: PVirtualNode of object;
    /// <summary>Returns the first visible (expanded) node.</summary>
    [ TreeMethod ]GetFirstVisible: function: PVirtualNode of object;
    /// <summary>Returns the first visible child of the given node.</summary>
    [ TreeMethod ]GetFirstVisibleChild: function( Node: PVirtualNode ): PVirtualNode of object;

    /// <summary>Returns the next node in document order.</summary>
    [ TreeMethod ]GetNext: function( Node: PVirtualNode ): PVirtualNode of object;
    /// <summary>Returns the next selected node after <paramref name="Node"/>.</summary>
    [ TreeMethod ]GetNextSelected: function( Node: PVirtualNode ): PVirtualNode of object;
    /// <summary>Returns the next sibling at the same level.</summary>
    [ TreeMethod ]GetNextSibling: function( Node: PVirtualNode ): PVirtualNode of object;
    /// <summary>Returns the next visible node.</summary>
    [ TreeMethod ]GetNextVisible: function( Node: PVirtualNode ): PVirtualNode of object;
    /// <summary>Returns the next visible sibling at the same level.</summary>
    [ TreeMethod ]GetNextVisibleSibling: function( Node: PVirtualNode ): PVirtualNode of object;

    /// <summary>Returns the user-data pointer associated with a node.</summary>
    [ TreeMethod ]GetNodeData: function( Node: PVirtualNode ): Pointer of object;
    /// <summary>Returns the zero-based depth of <paramref name="Node"/> in the tree.</summary>
    [ TreeMethod ]GetNodeLevel: function( Node: PVirtualNode ): Cardinal of object;

    /// <summary>Clears the entire selection.</summary>
    [ TreeMethod ]ClearSelection: procedure of object;
    /// <summary>Scrolls a node into view.</summary>
    [ TreeMethod ]ScrollIntoView: function( Node: PVirtualNode; Center: Boolean; Horizontally: Boolean = False ): Boolean of object;
    /// <summary>Returns True while the user is editing a node label.</summary>
    [ TreeMethod ]IsEditing: function: Boolean of object;

    /// <summary>Indexed read-only access to the cell text.</summary>
    property Text[ Node: PVirtualNode; Column: Integer ]: string read GetText;
    /// <summary>Per-node selected state.</summary>
    property Selected[ Node: PVirtualNode ]: Boolean read GetSelected write SetSelected;
    /// <summary>Currently focused node.</summary>
    property FocusedNode: PVirtualNode read GetFocusedNode write SetFocusedNode;
    /// <summary>Read-only parent lookup.</summary>
    property NodeParent[ Node: PVirtualNode ]: PVirtualNode read GetNodeParent;

    /// <summary>Bridged <c>OnGetText</c> handler of the wrapped tree.</summary>
    property OnGetText: TVSTGetTextEvent read GetOnGetText write SetOnGetText;

    /// <summary>The image list assigned to the wrapped tree.</summary>
    property Images: TCustomImageList read GetImages;
  end;

/// <summary>
/// Decodes a published property's <c>GetProc</c>/<c>SetProc</c> accessor into the code address of the
/// accessor method, for a property whose accessor is a method (static or virtual).
/// </summary>
/// <param name="Instance">Object whose class supplies the virtual method table.</param>
/// <param name="Accessor">The raw <c>PPropInfo.GetProc</c> or <c>PPropInfo.SetProc</c> value.</param>
/// <returns>
/// The method's code address, or <c>nil</c> when <paramref name="Instance"/> or <paramref name="Accessor"/> is
/// nil or the accessor is a field (a field accessor has no code to call).
/// </returns>
function ResolvePropAccessorCode( Instance: TObject; Accessor: Pointer ): Pointer;

implementation

uses
  System.TypInfo;

type
  TOpenControl = class( TControl );

procedure NotSupported; overload;
begin
  raise Exception.Create( 'Not Supported' );
end;

procedure NotSupportedMsg( const Msg: string ); overload;
begin
  raise Exception.Create( Msg );
end;

function ResolvePropAccessorCode( Instance: TObject; Accessor: Pointer ): Pointer;
begin
  Result            := nil;
  if ( Instance = nil ) or ( Accessor = nil ) then
    Exit;
  // The slot flags occupy the top byte of a pointer-width value: $FF... on Win32 is bits 24..31, on Win64
  // bits 56..63.  System.TypInfo declares the masks at the right width for the platform being compiled.
  var Slot          := UIntPtr( Accessor ) and UIntPtr( PROPSLOT_MASK );
  if Slot = UIntPtr( PROPSLOT_FIELD ) then
    Exit; // a field, not a method: nothing to call
  if Slot = UIntPtr( PROPSLOT_VIRTUAL ) then
    // Virtual method: the low 16 bits are the byte offset into the instance's VMT
    Result          := PPointer( PNativeUInt( Instance )^ + ( UIntPtr( Accessor ) and $FFFF ) )^
  else
    Result          := Accessor; // static method: the value is the code address
end;

procedure GetPropAccessor( Instance: TObject; Accessor: Pointer; var M );
begin
  TMethod( M ).Data := Instance;
  TMethod( M ).Code := ResolvePropAccessorCode( Instance, Accessor );
  if TMethod( M ).Code = nil then
    TMethod( M ).Code := @NotSupported;
end;

{ TreePropertyAccessor }

constructor TreePropertyAccessor.Create( const APropertyName: string );
begin
  inherited Create;
  FPropertyName     := APropertyName;
end;

{ TreeImport }

constructor TreeImport.Create( const ASignature: AnsiString );
begin
  inherited Create;
  FSignature        := ASignature;
end;

{ TIDEVirtualTreeHandler }

constructor TIDEVirtualTreeHandler.Create( ATree: TCustomControl );
begin
  inherited Create;
  FTree             := ATree;
  InitMethods;
end;

procedure TIDEVirtualTreeHandler.DblClick;
begin
  TOpenControl( FTree ).DblClick;
end;

procedure TIDEVirtualTreeHandler.Invalidate;
begin
  FTree.Invalidate;
end;

procedure TIDEVirtualTreeHandler.GetMethod( TreeType: TRttiType; const MethodName: string; var M );
var
  Method            : TRttiMethod;
begin
  TMethod( M ).Data := FTree;
  TMethod( M ).Code := @NotSupported;
  if TreeType <> nil then
  begin
    Method          := TreeType.GetMethod( MethodName );
    if Method <> nil then
      TMethod( M ).Code := Method.CodeAddress;
  end;
end;

procedure TIDEVirtualTreeHandler.GetProperty( TreeType: TRttiType; const PropertyName: string; Setter: Boolean; var M );
var
  Prop              : TRttiProperty;
begin
  TMethod( M ).Data := FTree;
  TMethod( M ).Code := @NotSupported;
  if TreeType <> nil then
  begin
    Prop            := TreeType.GetProperty( PropertyName );
    if Prop is TRttiInstanceProperty then
    begin
      if Setter then
        GetPropAccessor( FTree, TRttiInstanceProperty( Prop ).PropInfo.SetProc, M )
      else
        GetPropAccessor( FTree, TRttiInstanceProperty( Prop ).PropInfo.GetProc, M );
    end;
  end;
end;

function TIDEVirtualTreeHandler.GetSelected( Node: PVirtualNode ): Boolean;
begin
  Result            := FSelectedGetter( Node );
end;

procedure TIDEVirtualTreeHandler.SetSelected( Node: PVirtualNode; const Value: Boolean );
begin
  FSelectedSetter( Node, Value );
end;

function TIDEVirtualTreeHandler.GetText( Node: PVirtualNode; Column: Integer ): string;
begin
  Result            := FTextGetter( Node, Column );
end;

function TIDEVirtualTreeHandler.GetFocusedNode: PVirtualNode;
var
  Ctx               : TRttiContext;
  TreeType          : TRttiType;
  Prop              : TRttiProperty;
begin
  Result            := nil;
  Ctx               := TRttiContext.Create;
  try
    TreeType        := Ctx.GetType( FTree.ClassInfo );
    if TreeType <> nil then
    begin
      Prop          := TreeType.GetProperty( 'FocusedNode' );
      if ( Prop <> nil ) and ( Prop.PropertyType <> nil ) and ( Prop.PropertyType.TypeKind = tkPointer ) then
      begin
        // FocusedNode is a pointer type: TValue.AsObject would raise EInvalidCast, so read the raw pointer
        var Value   := Prop.GetValue( FTree );
        if not Value.IsEmpty then
          Result    := PVirtualNode( PPointer( Value.GetReferenceToRawData )^ );
      end;
    end;
  finally
    Ctx.Free;
  end;
end;

procedure TIDEVirtualTreeHandler.SetFocusedNode( Node: PVirtualNode );
begin
  FFocusedNodeSetter( Node );
end;

function TIDEVirtualTreeHandler.GetNodeParent( Node: PVirtualNode ): PVirtualNode;
begin
  Result            := FNodeParentGetter( Node );
end;

function TIDEVirtualTreeHandler.GetImages: TCustomImageList;
begin
  Result            := TCustomImageList( GetObjectProp( FTree, 'Images', TCustomImageList ) );
end;

function TIDEVirtualTreeHandler.GetOnGetText: TVSTGetTextEvent;
begin
  Result            := TVSTGetTextEvent( GetMethodProp( FTree, 'OnGetText' ) );
end;

procedure TIDEVirtualTreeHandler.SetOnGetText( const Value: TVSTGetTextEvent );
begin
  SetMethodProp( FTree, 'OnGetText', TMethod( Value ) );
end;

procedure TIDEVirtualTreeHandler.InitMethods;
var
  Ctx               : TRttiContext;
  TreeType, SelfType: TRttiType;
  Fields            : TArray<TRttiField>;
  Field             : TRttiField;
  I                 : Integer;
  Attributes        : TArray<TCustomAttribute>;
  AttrIndex         : Integer;
  M                 : TMethod;
  VclIdeLib         : THandle;
begin
  Ctx               := TRttiContext.Create;
  try
    TreeType        := Ctx.GetType( FTree.ClassInfo );
    if TreeType <> nil then
    begin
      VclIdeLib     := GetModuleHandle( vclide_bpl );

      SelfType      := Ctx.GetType( ClassInfo );
      Fields        := SelfType.GetFields;
      Assert( Fields <> nil );
      for I := 0 to High( Fields ) do
      begin
        Field       := Fields[ I ];
        Attributes  := Field.GetAttributes; // Error Insight Generic Array bug
        M.Code      := nil;
        for AttrIndex := 0 to High( Attributes ) do
        begin
          if Attributes[ AttrIndex ] is TreeMethod then
          begin
            GetMethod( TreeType, Field.Name, M );
            Break;
          end
          else if Attributes[ AttrIndex ] is TreePropertyAccessor then
          begin
            GetProperty( TreeType, TreePropertyAccessor( Attributes[ AttrIndex ] ).PropertyName,
              Attributes[ AttrIndex ] is TreePropertySetter, M );
            Break;
          end
          else if Attributes[ AttrIndex ] is TreeImport then
          begin
            M.Data  := FTree;
            M.Code  := @NotSupported;
            if VclIdeLib <> 0 then
            begin
              M.Code := DbgStrictGetProcAddress( VclIdeLib, PAnsiChar( TreeImport( Attributes[ AttrIndex ] ).Signature ) );
              if M.Code = nil then
                M.Code := @NotSupported;
            end;
            Break;
          end;
        end;

        if M.Code <> nil then
        begin
          TMethod( Pointer( INT_PTR( Self ) + Field.Offset )^ ) := M;
          //Field.SetValue(Self, TValue.From<TMethod>(M));  => exception
{$IFNDEF CPUX64}
          if M.Code = @NotSupported then
            NotSupportedMsg( Field.Name );
{$ENDIF}
          // Win64: TreeImport lookups against vclide370.bpl fail because the C++
          // name mangling differs; leave the field pointing at @NotSupported and
          // rely on call-site guards to skip the feature.
        end;
      end;
    end;
  finally
    Ctx.Free;
  end;

end;

end.

