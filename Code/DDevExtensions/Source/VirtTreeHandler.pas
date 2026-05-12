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
  Windows, Messages, SysUtils, Classes, Controls, ImgList, Rtti, IDEHooks;

type
  /// <summary>Opaque pointer alias for the IDE Virtual Tree's <c>PVirtualNode</c>.</summary>
  PVirtualNode = type Pointer;

  /// <summary>Subset of <c>TVSTTextType</c> mirrored for the IDE's tree.</summary>
  TVSTTextType = (
    ttNormal,      // normal label of the node, this is also the text which can be edited
    ttStatic       // static (non-editable) text after the normal text
  );

  /// <summary>Signature mirroring the IDE Virtual Tree's <c>OnGetText</c> event.</summary>
  TVSTGetTextEvent = procedure(Sender: TObject; Node: PVirtualNode; Column: Integer;
    TextType: TVSTTextType; var CellText: WideString) of object;


  /// <summary>Marker attribute: tag a method-of-object field to be resolved by RTTI method lookup at run-time.</summary>
  TreeMethod = class(TCustomAttribute)
  end;

  /// <summary>Base attribute carrying the property name for getter/setter resolution.</summary>
  TreePropertyAccessor = class(TCustomAttribute)
  private
    /// <summary>Name of the RTTI property to bind to.</summary>
    FPropertyName: string;
  public
    /// <summary>Stores the property name to look up.</summary>
    constructor Create(const APropertyName: string);
    /// <summary>Property name to look up via RTTI.</summary>
    property PropertyName: string read FPropertyName;
  end;

  /// <summary>Tags a field as the read-accessor of a tree property.</summary>
  TreePropertyGetter = class(TreePropertyAccessor);
  /// <summary>Tags a field as the write-accessor of a tree property.</summary>
  TreePropertySetter = class(TreePropertyAccessor);

  /// <summary>
  /// Marker attribute: tag a method-of-object field to be resolved by direct
  /// mangled-symbol import from <c>vclide.bpl</c>.
  /// </summary>
  TreeImport = class(TCustomAttribute)
  private
    /// <summary>BCC-mangled function signature exported by <c>vclide.bpl</c>.</summary>
    FSignature: AnsiString;
  public
    /// <summary>Stores the mangled symbol name.</summary>
    constructor Create(const ASignature: AnsiString);
    /// <summary>Mangled function signature used to import the symbol.</summary>
    property Signature: AnsiString read FSignature;
  end;

  /// <summary>
  /// Run-time facade over the IDE's hidden Virtual Tree control: exposes the
  /// tree's enumerator and accessor methods through ordinary Pascal calls.
  /// </summary>
  TIDEVirtualTreeHandler = class(TObject)
  private
    /// <summary>The wrapped IDE Virtual Tree instance.</summary>
    FTree: TCustomControl;

    /// <summary>Imported text getter (<c>TCustomVirtualStringTree.GetText</c>).</summary>
    [TreeImport('@Idevirtualtrees@TCustomVirtualStringTree@GetText$qqrp28Idevirtualtrees@TVirtualNodei')]
    FTextGetter: function(Node: PVirtualNode; Column: Integer): WideString of object;
    /// <summary>Imported selected-state getter.</summary>
    [TreeImport('@Idevirtualtrees@TBaseVirtualTree@GetSelected$qqrp28Idevirtualtrees@TVirtualNode')]
    FSelectedGetter: function(Node: PVirtualNode): Boolean of object;
    /// <summary>Imported selected-state setter.</summary>
    [TreeImport('@Idevirtualtrees@TBaseVirtualTree@SetSelected$qqrp28Idevirtualtrees@TVirtualNodeo')]
    FSelectedSetter: procedure(Node: PVirtualNode; Value: Boolean) of object;
    /// <summary>Imported parent-node getter.</summary>
    [TreeImport('@Idevirtualtrees@TBaseVirtualTree@GetNodeParent$qqrp28Idevirtualtrees@TVirtualNode')]
    FNodeParentGetter: function(Node: PVirtualNode): PVirtualNode of object;

    /// <summary>RTTI-resolved setter for the <c>FocusedNode</c> property.</summary>
    [TreePropertySetter('FocusedNode')]
    FFocusedNodeSetter: procedure(Node: PVirtualNode) of object;


    /// <summary>Walks every published field of <c>Self</c> and binds it according to its attribute (TreeMethod, TreePropertyAccessor or TreeImport).</summary>
    procedure InitMethods;
    /// <summary>Resolves a tree method by RTTI name and stores the resulting <c>TMethod</c> in <paramref name="M"/>.</summary>
    procedure GetMethod(TreeType: TRttiType; const MethodName: string; var M);
    /// <summary>Resolves a property getter or setter by RTTI name and stores the resulting <c>TMethod</c> in <paramref name="M"/>.</summary>
    procedure GetProperty(TreeType: TRttiType; const PropertyName: string; Setter: Boolean; var M);

    /// <summary>Returns the text of the given column on the given node.</summary>
    function GetText(Node: PVirtualNode; Column: Integer): string;
    /// <summary>Returns whether the node is selected.</summary>
    function GetSelected(Node: PVirtualNode): Boolean;
    /// <summary>Sets the node's selected state.</summary>
    procedure SetSelected(Node: PVirtualNode; const Value: Boolean);
    /// <summary>Returns the currently focused node, or nil.</summary>
    function GetFocusedNode: PVirtualNode;
    /// <summary>Focuses the given node.</summary>
    procedure SetFocusedNode(Node: PVirtualNode);
    /// <summary>Returns the tree's <c>Images</c> property reflected via RTTI.</summary>
    function GetImages: TCustomImageList;
    /// <summary>Returns the parent of the given node, or nil for top-level nodes.</summary>
    function GetNodeParent(Node: PVirtualNode): PVirtualNode;
    /// <summary>Returns the tree's <c>OnGetText</c> handler.</summary>
    function GetOnGetText: TVSTGetTextEvent;
    /// <summary>Installs an <c>OnGetText</c> handler on the tree.</summary>
    procedure SetOnGetText(const Value: TVSTGetTextEvent);
  public
    /// <summary>Wraps <paramref name="ATree"/> and binds every accessor field.</summary>
    constructor Create(ATree: TCustomControl);
    /// <summary>Forwards a synthetic <c>DblClick</c> to the wrapped tree.</summary>
    procedure DblClick;
    /// <summary>Invalidates the wrapped tree's display.</summary>
    procedure Invalidate;

    /// <summary>The wrapped IDE Virtual Tree instance.</summary>
    property Tree: TCustomControl read FTree;
  public
    /// <summary>Returns the first node, or nil if the tree is empty.</summary>
    [TreeMethod] GetFirst: function: PVirtualNode of object;
    /// <summary>Returns the first selected node, or nil.</summary>
    [TreeMethod] GetFirstSelected: function: PVirtualNode of object;
    /// <summary>Returns the first visible (expanded) node.</summary>
    [TreeMethod] GetFirstVisible: function: PVirtualNode of object;
    /// <summary>Returns the first visible child of the given node.</summary>
    [TreeMethod] GetFirstVisibleChild: function(Node: PVirtualNode): PVirtualNode of object;

    /// <summary>Returns the next node in document order.</summary>
    [TreeMethod] GetNext: function(Node: PVirtualNode): PVirtualNode of object;
    /// <summary>Returns the next selected node after <paramref name="Node"/>.</summary>
    [TreeMethod] GetNextSelected: function(Node: PVirtualNode): PVirtualNode of object;
    /// <summary>Returns the next sibling at the same level.</summary>
    [TreeMethod] GetNextSibling: function(Node: PVirtualNode): PVirtualNode of object;
    /// <summary>Returns the next visible node.</summary>
    [TreeMethod] GetNextVisible: function(Node: PVirtualNode): PVirtualNode of object;
    /// <summary>Returns the next visible sibling at the same level.</summary>
    [TreeMethod] GetNextVisibleSibling: function(Node: PVirtualNode): PVirtualNode of object;

    /// <summary>Returns the user-data pointer associated with a node.</summary>
    [TreeMethod] GetNodeData: function(Node: PVirtualNode): Pointer of object;
    /// <summary>Returns the zero-based depth of <paramref name="Node"/> in the tree.</summary>
    [TreeMethod] GetNodeLevel: function(Node: PVirtualNode): Cardinal of object;

    /// <summary>Clears the entire selection.</summary>
    [TreeMethod] ClearSelection: procedure of object;
    /// <summary>Scrolls a node into view.</summary>
    [TreeMethod] ScrollIntoView: function(Node: PVirtualNode; Center: Boolean; Horizontally: Boolean = False): Boolean of object;
    /// <summary>Returns True while the user is editing a node label.</summary>
    [TreeMethod] IsEditing: function: Boolean of object;

    /// <summary>Indexed read-only access to the cell text.</summary>
    property Text[Node: PVirtualNode; Column: Integer]: string read GetText;
    /// <summary>Per-node selected state.</summary>
    property Selected[Node: PVirtualNode]: Boolean read GetSelected write SetSelected;
    /// <summary>Currently focused node.</summary>
    property FocusedNode: PVirtualNode read GetFocusedNode write SetFocusedNode;
    /// <summary>Read-only parent lookup.</summary>
    property NodeParent[Node: PVirtualNode]: PVirtualNode read GetNodeParent;

    /// <summary>Bridged <c>OnGetText</c> handler of the wrapped tree.</summary>
    property OnGetText: TVSTGetTextEvent read GetOnGetText write SetOnGetText;

    /// <summary>The image list assigned to the wrapped tree.</summary>
    property Images: TCustomImageList read GetImages;
  end;

implementation

uses
  TypInfo;

type
  TOpenControl = class(TControl);

procedure NotSupported; overload;
begin
  raise Exception.Create('Not Supported');
end;

procedure NotSupportedMsg(const Msg: string); overload;
begin
  raise Exception.Create(Msg);
end;

procedure GetPropAccessor(Instance: TObject; Accessor: Pointer; var M);
type
  PINT_PTR = ^INT_PTR;
var
  Offset: INT_PTR;
begin
  TMethod(M).Data := Instance;
  if (Instance = nil) or (Accessor = nil) then
    TMethod(M).Code := @NotSupported
  else
  begin
    Offset := INT_PTR(Accessor);
    if (Offset and $FF000000) = $FE000000 then
    begin
      // Virtual dispatch, but with offset, not slot
      TMethod(M).Code := PPointer(PINT_PTR(Instance)^ + SmallInt(Offset))^;
    end
    else
    begin
      // Static dispatch
      TMethod(M).Code := Pointer(Offset);
    end;
  end;
end;

{ TreePropertyAccessor }

constructor TreePropertyAccessor.Create(const APropertyName: string);
begin
  inherited Create;
  FPropertyName := APropertyName;
end;

{ TreeImport }

constructor TreeImport.Create(const ASignature: AnsiString);
begin
  inherited Create;
  FSignature :=  ASignature;
end;

{ TIDEVirtualTreeHandler }

constructor TIDEVirtualTreeHandler.Create(ATree: TCustomControl);
begin
  inherited Create;
  FTree := ATree;
  InitMethods;
end;

procedure TIDEVirtualTreeHandler.DblClick;
begin
  TOpenControl(FTree).DblClick;
end;

procedure TIDEVirtualTreeHandler.Invalidate;
begin
  FTree.Invalidate;
end;

procedure TIDEVirtualTreeHandler.GetMethod(TreeType: TRttiType; const MethodName: string; var M);
var
  Method: TRttiMethod;
begin
  TMethod(M).Data := FTree;
  TMethod(M).Code := @NotSupported;
  if TreeType <> nil then
  begin
    Method := TreeType.GetMethod(MethodName);
    if Method <> nil then
      TMethod(M).Code := Method.CodeAddress;
  end;
end;

procedure TIDEVirtualTreeHandler.GetProperty(TreeType: TRttiType; const PropertyName: string; Setter: Boolean; var M);
var
  Prop: TRttiProperty;
begin
  TMethod(M).Data := FTree;
  TMethod(M).Code := @NotSupported;
  if TreeType <> nil then
  begin
    Prop := TreeType.GetProperty(PropertyName);
    if Prop is TRttiInstanceProperty then
    begin
      if Setter then
        GetPropAccessor(FTree, TRttiInstanceProperty(Prop).PropInfo.SetProc, M)
      else
        GetPropAccessor(FTree, TRttiInstanceProperty(Prop).PropInfo.GetProc, M);
    end;
  end;
end;

function TIDEVirtualTreeHandler.GetSelected(Node: PVirtualNode): Boolean;
begin
  Result := FSelectedGetter(Node);
end;

procedure TIDEVirtualTreeHandler.SetSelected(Node: PVirtualNode; const Value: Boolean);
begin
  FSelectedSetter(Node, Value);
end;

function TIDEVirtualTreeHandler.GetText(Node: PVirtualNode; Column: Integer): string;
begin
  Result := FTextGetter(Node, Column);
end;

function TIDEVirtualTreeHandler.GetFocusedNode: PVirtualNode;
var
  Ctx: TRttiContext;
  TreeType: TRttiType;
  Prop: TRttiProperty;
begin
  Result := nil;
  Ctx := TRttiContext.Create;
  try
    TreeType := Ctx.GetType(FTree.ClassInfo);
    if TreeType <> nil then
    begin
      Prop := TreeType.GetProperty('FocusedNode');
      if Prop <> nil then
        Result := PVirtualNode(Prop.GetValue(FTree).AsObject);
    end;
  finally
    Ctx.Free;
  end;
end;

procedure TIDEVirtualTreeHandler.SetFocusedNode(Node: PVirtualNode);
begin
  FFocusedNodeSetter(Node);
end;

function TIDEVirtualTreeHandler.GetNodeParent(Node: PVirtualNode): PVirtualNode;
begin
  Result := FNodeParentGetter(Node);
end;

function TIDEVirtualTreeHandler.GetImages: TCustomImageList;
begin
  Result := TCustomImageList(GetObjectProp(FTree, 'Images', TCustomImageList));
end;

function TIDEVirtualTreeHandler.GetOnGetText: TVSTGetTextEvent;
begin
  Result := TVSTGetTextEvent(GetMethodProp(FTree, 'OnGetText'));
end;

procedure TIDEVirtualTreeHandler.SetOnGetText(const Value: TVSTGetTextEvent);
begin
  SetMethodProp(FTree, 'OnGetText', TMethod(Value));
end;

procedure TIDEVirtualTreeHandler.InitMethods;
var
  Ctx: TRttiContext;
  TreeType, SelfType: TRttiType;
  Fields: TArray<TRttiField>;
  Field: TRttiField;
  I: Integer;
  Attributes: TArray<TCustomAttribute>;
  AttrIndex: Integer;
  M: TMethod;
  VclIdeLib: THandle;
begin
  Ctx := TRttiContext.Create;
  try
    TreeType := Ctx.GetType(FTree.ClassInfo);
    if TreeType <> nil then
    begin
      VclIdeLib := GetModuleHandle(vclide_bpl);

      SelfType := Ctx.GetType(ClassInfo);
      Fields := SelfType.GetFields;
      Assert(Fields <> nil);
      for I := 0 to High(Fields) do
      begin
        Field := Fields[I];
        Attributes := Field.GetAttributes; // Error Insight Generic Array bug
        M.Code := nil;
        for AttrIndex := 0 to High(Attributes) do
        begin
          if Attributes[AttrIndex] is TreeMethod then
          begin
            GetMethod(TreeType, Field.Name, M);
            Break;
          end
          else if Attributes[AttrIndex] is TreePropertyAccessor then
          begin
            GetProperty(TreeType, TreePropertyAccessor(Attributes[AttrIndex]).PropertyName,
              Attributes[AttrIndex] is TreePropertySetter, M);
            Break;
          end
          else if Attributes[AttrIndex] is TreeImport then
          begin
            M.Data := FTree;
            M.Code := @NotSupported;
            if VclIdeLib <> 0 then
            begin
              M.Code := DbgStrictGetProcAddress(VclIdeLib, PAnsiChar(TreeImport(Attributes[AttrIndex]).Signature));
              if M.Code = nil then
                M.Code := @NotSupported;
            end;
            Break;
          end;
        end;

        if M.Code <> nil then
        begin
          TMethod(Pointer(INT_PTR(Self) + Field.Offset)^) := M;
          //Field.SetValue(Self, TValue.From<TMethod>(M));  => exception
          {$IFNDEF CPUX64}
          // x86: an unresolved IDE virtual-tree import is a hard error during init so
          // developers see it immediately. On Win64 the vclide BPL uses a different C++
          // name-mangling for these symbols, so every TreeImport would fail — silently
          // accept @NotSupported and let it raise on actual call instead of blocking
          // IDE startup.
          if M.Code = @NotSupported then
             NotSupportedMsg(Field.Name);
          {$ENDIF CPUX64}
        end;
      end;
    end;
  finally
    Ctx.Free;
  end;

end;


end.

