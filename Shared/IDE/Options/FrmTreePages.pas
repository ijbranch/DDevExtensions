{******************************************************************************}
{*                                                                            *}
{* (C) 2005-2009 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}
{$A+,B-,C+,D+,E-,F-,G+,H+,I+,J-,K-,L+,M-,N-,O+,P+,Q-,R-,S-,T-,U-,V+,W-,X+,Y+,Z1}

unit FrmTreePages;

/// <summary>
/// Generic tree-and-frame options dialog: a TTreeView on the left selects pages whose contents
/// are dynamically created from a TComponentClass that implements ITreePageComponent. Used as
/// the base for the plugin's environment-options dialogs.
/// </summary>

interface

uses
  Winapi.Windows, Winapi.Messages, System.Contnrs, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, FrmBase;

type
  /// <summary>Implemented by every options page so the environment-options dialog can load/save the corresponding personality option.</summary>
  ITreePageComponent = interface
    ['{353613EA-B5BF-43BC-A7D0-0AADD9388A03}']
    /// <summary>Loads the personality options into the dialog controls.</summary>
    procedure LoadData;
    /// <summary>Stores the data from the dialog controls into the personality options.</summary>
    procedure SaveData;

    /// <summary>Called when this page becomes selected in the tree.</summary>
    procedure Selected;
    /// <summary>Called when this page is no longer selected.</summary>
    procedure Unselected;

    /// <summary>Receives the UserData parameter that was supplied when the page was registered.</summary>
    /// <param name="UserData">The object given to TTreePage.Create; may be nil.</param>
    procedure SetUserData(UserData: TObject);
  end;

  /// <summary>Optional second interface that allows a page to display its caption.</summary>
  ITreePageComponentEx = interface
    ['{9260B5AB-8021-4208-9EEF-B3BD24C3AF9B}']
    /// <summary>Receives the page caption so the implementor can display it.</summary>
    /// <param name="ACaption">Caption of the page's node in the tree.</param>
    procedure SetTitle(const ACaption: string);
  end;

  /// <summary>Definition of a single page in the options tree: name, component class and optional user data.</summary>
  TTreePage = class(TObject)
  private
    /// <summary>Owned list of child pages.</summary>
    FItems: TObjectList;
    /// <summary>Parent page in the tree; nil at the root.</summary>
    FParent: TTreePage;
    /// <summary>Display name shown in the TreeView.</summary>
    FName: string;
    /// <summary>Component class instantiated when the page is selected.</summary>
    FComponentClass: TComponentClass;
    /// <summary>Caller-supplied object handed to the page's SetUserData.</summary>
    FUserData: TObject;
    /// <summary>Returns the number of child pages.</summary>
    /// <returns>Number of child pages.</returns>
    function GetCount: Integer;
    /// <summary>Returns the child page at Index.</summary>
    /// <param name="Index">Zero-based child index.</param>
    /// <returns>The child page at Index.</returns>
    function GetItem(Index: Integer): TTreePage;
  public
    /// <summary>Initialises the page; AComponentClass must implement ITreePageComponent or be nil for grouping nodes.</summary>
    /// <exception cref="ETreePageError">Raised when AComponentClass does not implement ITreePageComponent.</exception>
    /// <param name="AName">Caption shown in the tree.</param>
    /// <param name="AComponentClass">Page component class, created when the page is first selected; nil for a grouping node.</param>
    /// <param name="AUserData">Object handed to the page through ITreePageComponent.SetUserData; not owned.</param>
    constructor Create(const AName: string; AComponentClass: TComponentClass; AUserData: TObject = nil);
    /// <summary>Detaches from the parent and frees every child page.</summary>
    destructor Destroy; override;

    /// <summary>Appends Page as a child and assumes ownership.</summary>
    /// <param name="Page">Child page; must not be nil.  This page takes ownership.</param>
    procedure Add(Page: TTreePage);
    /// <summary>Removes the child page at Index.</summary>
    /// <param name="Index">Zero-based index of the child page to remove and free.</param>
    procedure Delete(Index: Integer);
    /// <summary>Removes every child page.</summary>
    procedure Clear;

    /// <summary>Parent page (nil at the root).</summary>
    property Parent: TTreePage read FParent;
    /// <summary>Number of child pages.</summary>
    property Count: Integer read GetCount;
    /// <summary>Indexed accessor for child pages.</summary>
    property Items[Index: Integer]: TTreePage read GetItem; default;

    /// <summary>Caller-supplied user data.</summary>
    property UserData: TObject read FUserData;
    /// <summary>Display name shown in the tree.</summary>
    property Name: string read FName;
    /// <summary>Component class instantiated when the page is selected.</summary>
    property ComponentClass: TComponentClass read FComponentClass;
  end;

  /// <summary>Raised when a TTreePage is constructed with a TComponentClass that does not implement ITreePageComponent.</summary>
  ETreePageError = class(Exception);

  /// <summary>Generic tree-and-pane options dialog. Subclasses populate the tree by overriding PopulateRootPage.</summary>
  TFormTreePages = class(TFormBase)
    /// <summary>Bottom button panel.</summary>
    PanelButtons: TPanel;
    /// <summary>OK button.</summary>
    btnOk: TButton;
    /// <summary>Cancel button.</summary>
    btnCancel: TButton;
    /// <summary>Visual separator between the buttons and the working area.</summary>
    bvlDivider: TBevel;
    /// <summary>Container for the tree view, splitter and page client area.</summary>
    PanelWorkingArea: TPanel;
    /// <summary>Tree view used to navigate between pages.</summary>
    TreeView: TTreeView;
    /// <summary>Container that hosts the currently selected page component.</summary>
    PanelClient: TPanel;
    /// <summary>Splitter between the tree view and the page client area.</summary>
    SplitterTree: TSplitter;
    /// <summary>Activates the selected page, instantiating its component on demand.</summary>
    /// <param name="Sender">The tree view.</param>
    /// <param name="Node">Newly selected node, or nil to unselect.</param>
    procedure TreeViewChange(Sender: TObject; Node: TTreeNode);
    /// <summary>Frees the root TTreePage on form destruction.</summary>
    /// <param name="Sender">The form.</param>
    procedure FormDestroy(Sender: TObject);
    /// <summary>Anchors the OK/Cancel buttons and creates the root page.</summary>
    /// <param name="Sender">The form.</param>
    procedure FormCreate(Sender: TObject);
    /// <summary>Hooks up the TreeView OnChange handler and forces an initial selection.</summary>
    /// <param name="Sender">The form.</param>
    procedure FormShow(Sender: TObject);
  private
    { Private-Deklarationen }
    /// <summary>Root TTreePage that owns the entire page hierarchy.</summary>
    FRootPage: TTreePage;
    /// <summary>Currently selected page component (or nil).</summary>
    FSelected: TComponent;
    /// <summary>
    /// Page components whose LoadData raised.  Their controls hold the designer defaults, not the
    /// stored settings, so they are not saved on OK (that would overwrite the stored settings).
    /// </summary>
    FFailedPages: TList;
    /// <summary>Returns the Index'th page component currently parented to PanelClient.</summary>
    /// <param name="Index">Zero-based index among the page components.</param>
    /// <returns>The page component at Index.</returns>
    /// <exception cref="EListError">Raised when Index is negative or not below PageComponentCount.</exception>
    function GetPageComponent(Index: Integer): ITreePageComponent;
    /// <summary>Number of page components currently parented to PanelClient.</summary>
    /// <returns>Number of components on PanelClient that implement ITreePageComponent.</returns>
    function GetPageComponentCount: Integer;
    /// <summary>Rebuilds TreeView nodes from FRootPage.</summary>
    procedure PopulateTreeNodes;
  protected
    /// <summary>
    /// Shows the dialog modally and persists the page data when the user clicks OK.  Every page
    /// is saved even if one raises, and AfterSaveData always runs; pages whose LoadData failed are
    /// skipped.
    /// </summary>
    /// <returns>True when the user accepted the dialog.</returns>
    /// <exception cref="ETreePageError">Raised after saving when one or more pages failed to save; the message lists them.</exception>
    function DoExecute: Boolean; virtual;
    /// <summary>Invoked after a TreeView selection change; default implementation does nothing.</summary>
    /// <param name="Node">Newly selected node, or nil.</param>
    procedure SelectionChanged(Node: TTreeNode); virtual;

    /// <summary>Subclasses must populate Root with the pages they want to display.</summary>
    /// <param name="Root">Root page to add the dialog's pages to.</param>
    procedure PopulateRootPage(Root: TTreePage); virtual; abstract;
    /// <summary>Hook called immediately before SaveData is invoked on every page.</summary>
    procedure BeforeSaveData; virtual;
    /// <summary>Hook called immediately after SaveData was invoked on every page.</summary>
    procedure AfterSaveData; virtual;
    /// <summary>Hook called after the dialog has finished closing (regardless of OK/Cancel).</summary>
    procedure AfterClose; virtual;

    /// <summary>Root TTreePage that owns the page hierarchy.</summary>
    property RootPage: TTreePage read FRootPage;
    /// <summary>Number of page components currently parented to PanelClient.</summary>
    property PageComponentCount: Integer read GetPageComponentCount;
    /// <summary>Indexed accessor for the page components currently parented to PanelClient.</summary>
    property PageComponents[Index: Integer]: ITreePageComponent read GetPageComponent;
  public
    { Public-Deklarationen }
    /// <summary>Convenience method that creates the dialog, runs DoExecute and frees it.</summary>
    /// <returns>True when the user accepted the dialog.</returns>
    class function Execute: Boolean;
  end;

implementation

uses
  {$IFDEF COMPILER5}
  Vcl.Consts,
  {$ELSE}
  System.RTLConsts,
  {$ENDIF COMPILER5}
  IDEUtils;

{$R *.dfm}

resourcestring
  RsTreePageError = 'TreePage does not support the ITreePageComponent interface.';

{ TTreePage }

constructor TTreePage.Create(const AName: string; AComponentClass: TComponentClass; AUserData: TObject);
begin
  inherited Create;
  if (AComponentClass <> nil) and not Supports(AComponentClass, ITreePageComponent) then
    raise ETreePageError.CreateFmt(RsTreePageError, [AComponentClass.ClassName]);
  FName := AName;
  FComponentClass := AComponentClass;
  FUserData := AUserData;
  FItems := TObjectList.Create;
end;

destructor TTreePage.Destroy;
begin
  if Parent <> nil then
    Parent.FItems.Extract(Self);
  FItems.Free;
  inherited Destroy;
end;

procedure TTreePage.Add(Page: TTreePage);
begin
  Assert(Page <> nil, 'TreePage must not be nil');
  Page.FParent := Self;
  FItems.Add(Page);
end;

function TTreePage.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TTreePage.GetItem(Index: Integer): TTreePage;
begin
  Result := TTreePage(FItems[Index]);
end;

procedure TTreePage.Delete(Index: Integer);
begin
  FItems.Delete(Index);
end;

procedure TTreePage.Clear;
begin
  FItems.Clear;
end;

{ TFormEnvironmentOptions }

procedure TFormTreePages.AfterClose;
begin
end;

procedure TFormTreePages.AfterSaveData;
begin
end;

procedure TFormTreePages.BeforeSaveData;
begin
end;

function TFormTreePages.GetPageComponent(Index: Integer): ITreePageComponent;
var
  i, Idx: Integer;
begin
  if Index >= 0 then
  begin
    Idx := Index;
    for i := 0 to PanelClient.ComponentCount - 1 do
    begin
      if SupportsEx(PanelClient.Components[i], ITreePageComponent, Result) then
      begin
        if Idx = 0 then
          Exit;
        Result := nil;
        Dec(Idx);
      end;
    end;
  end;
  raise EListError.CreateFmt(SListIndexError, [Index]);
end;

function TFormTreePages.GetPageComponentCount: Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to PanelClient.ComponentCount - 1 do
    if Supports(PanelClient.Components[i], ITreePageComponent) then
      Inc(Result);
end;

class function TFormTreePages.Execute: Boolean;
begin
  with Self.Create(Application) do
  try
    Result := DoExecute;
  finally
    Free;
  end;
end;

function TFormTreePages.DoExecute: Boolean;
var
  i: Integer;
  Comp: ITreePageComponent;
begin
  TreeView.OnChange := nil;
  FRootPage.Clear;
  PopulateRootPage(FRootPage);

  PopulateTreeNodes;

  Result := ShowModal = mrOk;
  if Result then
  begin
    BeforeSaveData;
    TreeViewChange(TreeView, nil); // unselect
    var sErrors := '';
    try
      for i := 0 to PanelClient.ComponentCount - 1 do
        if ( FFailedPages.IndexOf( PanelClient.Components[i] ) < 0 ) and
           SupportsEx(PanelClient.Components[i], ITreePageComponent, Comp) then
        try
          Comp.SaveData;
        except
          on E: Exception do
            sErrors := sErrors + sLineBreak + PanelClient.Components[i].ClassName + ': ' + E.Message;
        end;
    finally
      Comp := nil;
    end;
    AfterSaveData;
    if ( sErrors <> '' ) then
    begin
      AfterClose;
      raise ETreePageError.Create( 'Some option pages could not be saved:' + sErrors );
    end;
  end;
  AfterClose;
end;

procedure TFormTreePages.PopulateTreeNodes;

  procedure CreateTreeNode(ParentPage: TTreePage; Parent: TTreeNode);
  var
    i: Integer;
  begin
    for i := 0 to ParentPage.Count - 1 do
    begin
      CreateTreeNode(
        ParentPage[i],
        TreeView.Items.AddChildObject(Parent, ParentPage[i].Name, ParentPage[i])
      );
    end;
  end;

var
  i: Integer;
begin
  TreeView.Items.BeginUpdate;
  try
    TreeView.Items.Clear;
    CreateTreeNode(FRootPage, nil);
    for i := 0 to TreeView.Items.Count - 1 do
      TreeView.Items[i].Expand(True);
    if TreeView.Items.Count > 0 then
      TreeView.Items[0].Selected := True;
  finally
    TreeView.Items.EndUpdate;
  end;
end;

procedure TFormTreePages.FormCreate(Sender: TObject);
begin
  btnOk.Anchors := [akBottom, akRight];
  btnCancel.Anchors := [akBottom, akRight];

  FRootPage := TTreePage.Create('', nil);
  FFailedPages := TList.Create;
end;

procedure TFormTreePages.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FRootPage);
  FreeAndNil( FFailedPages );
end;

procedure TFormTreePages.FormShow(Sender: TObject);
begin
  TreeView.OnChange := TreeViewChange;
  TreeViewChange(TreeView, TreeView.Selected);
end;

procedure TFormTreePages.TreeViewChange(Sender: TObject; Node: TTreeNode);
var
  Comp: TComponent;
  LastSelected: TComponent;
  Intf: ITreePageComponent;
  IntfEx: ITreePageComponentEx;
begin
  if csDestroying in ComponentState then
    Exit;

  LastSelected := FSelected;
  if Node <> nil then
  begin
    { create if necessary and select }
    if TObject(Node.Data) is TTreePage then
    begin
      Comp := nil;
      if TTreePage(Node.Data).ComponentClass <> nil then
      begin
        Comp := TTreePage(Node.Data).ComponentClass.Create(PanelClient);
        if SupportsEx(Comp, ITreePageComponent, Intf) then
          Intf.SetUserData(TTreePage(Node.Data).UserData); // set before replacing Node.Data
        Comp.Name := '';
        Node.Data := Comp; // replace TTreePage by TComponent
        if Comp is TControl then
        begin
          TControl(Comp).Left := 0;
          TControl(Comp).Top := 0;
          TControl(Comp).Parent := PanelClient;
          if Supports(Comp, ITreePageComponentEx, IntfEx) then
            IntfEx.SetTitle(Node.Text);
        end;
        if Assigned(Intf) then
        try
          Intf.LoadData;
        except
          FFailedPages.Add( Comp ); // shown, but never saved: see FFailedPages
          raise;
        end;
      end
      else
      begin
        // select first child
        if Node.Count > 0 then
        begin
          if FSelected = Node.Item[0].Data then
            FSelected := nil;
          Node.Item[0].Selected := True;
          Exit;
        end;
      end;
    end
    else
      Comp := Node.Data;

    { set selected and show }
    FSelected := Comp;
    if Comp <> nil then
    begin
      if SupportsEx(Comp, ITreePageComponent, Intf) then
        Intf.Selected;
      if Comp is TControl then
        TControl(Comp).Show;
    end;
  end
  else
    FSelected := nil;

  if Assigned(LastSelected) and (LastSelected <> FSelected) then
  begin
    { unselect }
    if LastSelected is TControl then
      TControl(LastSelected).Hide;
    if SupportsEx(LastSelected, ITreePageComponent, Intf) then
      Intf.Unselected;
  end;
  SelectionChanged(Node);
end;

procedure TFormTreePages.SelectionChanged(Node: TTreeNode);
begin
end;

end.
