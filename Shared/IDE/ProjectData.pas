{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit ProjectData;

/// <summary>
/// Per-project key/value store backed by an XML side-car file (Project.dproj.projdata) that is
/// saved alongside the project. Subscribers receive notifications when projects are added,
/// destroyed, renamed or when the data is being loaded/saved so they can read/write their own
/// XML nodes inside the side-car document.
/// </summary>

interface

uses
  System.Variants, System.SysUtils, System.Classes, System.Contnrs, ToolsAPI, Vcl.Forms, SimpleXmlImport, SimpleXmlIntf,
  IDENotifiers;

type
  /// <summary>Forward declaration of the project-data registry.</summary>
  TProjectDataList = class;

  /// <summary>Wrapper that holds a Variant value for storage in TProjectData's name/value list.</summary>
  TDataVariantItem = class( TObject )
  private
    /// <summary>Backing Variant value.</summary>
    FValue: Variant;
  public
    /// <summary>Initialises the wrapper with the supplied value.</summary>
    /// <param name="AValue">Initial value.</param>
    constructor Create( const AValue: Variant );
    /// <summary>Wrapped Variant value.</summary>
    property Value: Variant read FValue write FValue;
  end;

  /// <summary>
  /// Per-project record installed as an IOTAModuleNotifier; persists Variant Values to a
  /// .projdata XML side-car and exposes a non-persistent object map for in-memory state.
  /// </summary>
  TProjectData = class( TInterfacedObject, IOTANotifier, IOTAModuleNotifier )
  private
    /// <summary>Cached project filename used to detect renames and locate the side-car.</summary>
    FFilename: string;
    /// <summary>Owning registry.</summary>
    FOwner: TProjectDataList;
    /// <summary>Notifier ID returned by Project.AddNotifier; -1 once Destroyed has fired.</summary>
    FId: Integer;
    /// <summary>String list mapping Variant value names to TDataVariantItem objects.</summary>
    FItems: TStrings;
    /// <summary>String list mapping non-persistent object names to caller-owned TObject references.</summary>
    FNonPersistents: TStrings;
    /// <summary>The wrapped IOTAProject.</summary>
    FProject: IOTAProject;
    /// <summary>When False, AfterSave does not write the side-car file (used by transient projects).</summary>
    FAllowSaveData: Boolean;
    /// <summary>True while Reload is parsing the side-car so SetValue does not mark the project modified.</summary>
    FLoading: Boolean;
    /// <summary>Reads a Variant value by name; returns Null when missing.</summary>
    /// <param name="Name">Value name.</param>
    /// <returns>The stored value, or Null when Name has none.</returns>
    function GetValue( const Name: string ): Variant;
    /// <summary>Writes a Variant value by name and marks the project modified outside Loading.</summary>
    /// <param name="Name">Value name.</param>
    /// <param name="Value">New value.</param>
    procedure SetValue( const Name: string; const Value: Variant );
    /// <summary>Reads a non-persistent object reference by name.</summary>
    /// <param name="Name">Object name.</param>
    /// <returns>The stored object, or nil.</returns>
    function GetNonPersistent( const Name: string ): TObject;
    /// <summary>Stores or replaces a non-persistent object reference by name.</summary>
    /// <param name="Name">Object name.</param>
    /// <param name="Value">Object to store; not owned.</param>
    procedure SetNonPersistent( const Name: string; const Value: TObject );
  protected
    /// <summary>Frees and removes every TDataVariantItem in FItems.</summary>
    procedure Clear;
  protected
    { IOTAModuleNotifier }
    /// <summary>Writes the persistent values plus subscriber-supplied XML nodes to the .projdata file.</summary>
    procedure AfterSave;
    /// <summary>IOTAModuleNotifier no-op.</summary>
    procedure BeforeSave;
    /// <summary>IOTAModuleNotifier: always returns True.</summary>
    /// <returns>Always True: the project may be overwritten.</returns>
    function CheckOverwrite: Boolean;
    /// <summary>IOTANotifier: handles Destroyed, broadcasts to subscribers and detaches.</summary>
    procedure Destroyed;
    /// <summary>IOTAModuleNotifier no-op.</summary>
    procedure Modified;
    /// <summary>Renames the .projdata side-car file alongside the project rename.</summary>
    /// <param name="NewName">New project file name.</param>
    procedure ModuleRenamed( const NewName: string );

    /// <summary>True while a Reload pass is in progress.</summary>
    property Loading: Boolean read FLoading;
  public
    /// <summary>Registers as a notifier on AProject and announces the new entry to subscribers.</summary>
    /// <param name="AOwner">Registry that lists this entry.</param>
    /// <param name="AProject">Project to watch.</param>
    constructor Create( AOwner: TProjectDataList; AProject: IOTAProject );
    /// <summary>Detaches from the project and frees value/non-persistent maps.</summary>
    destructor Destroy; override;
    /// <summary>
    /// Raises the Destroying event once and unregisters from the IDE.  The IDE then drops its
    /// reference, which normally frees this object, so the caller must hold its own interface
    /// reference across the call and must not touch the object afterwards without one.
    /// </summary>
    procedure Detach;
    /// <summary>Reloads persistent values from the .projdata side-car (if present).</summary>
    procedure Reload;
    /// <summary>True when Name has a stored persistent value (even if Null).</summary>
    /// <param name="Name">Value name.</param>
    /// <returns>True when Name has a stored value.</returns>
    function HasValue( const Name: string ): Boolean;

    /// <summary>The wrapped project.</summary>
    property Project: IOTAProject read FProject;

    /// <summary>Whether AfterSave writes the .projdata side-car. Default True.</summary>
    property AllowSaveData: Boolean read FAllowSaveData write FAllowSaveData;
    /// <summary>Indexed access to non-persistent (in-memory only) objects keyed by name.</summary>
    property NonPersistents[ const Name: string ]: TObject read GetNonPersistent write SetNonPersistent;
    /// <summary>Indexed access to persistent Variant values keyed by name.</summary>
    property Values[ const Name: string ]: Variant read GetValue write SetValue;
  end;

  /// <summary>Skeleton for transactional changes across every TProjectData; rollback is currently unimplemented.</summary>
  TProjectDataTransaction = class( TObject )
  private
    /// <summary>Owning registry.</summary>
    FOwner: TProjectDataList;
    /// <summary>Snapshot of project references at transaction start.</summary>
    FProjects: TList;
    /// <summary>Captured value lists for rollback (currently unused).</summary>
    FItems: TObjectList;
  public
    /// <summary>Snapshots the current project list.</summary>
    /// <param name="AOwner">Registry whose projects are captured.</param>
    constructor Create( AOwner: TProjectDataList );
    /// <summary>Releases the snapshot.</summary>
    destructor Destroy; override;

    /// <summary>Reverts changes made since this transaction started. Currently a no-op.</summary>
    procedure Rollback;
  end;

  /// <summary>Event signature for project lifecycle notifications (added, destroying).</summary>
  TProjectDataEvent = procedure( Data: TProjectData ) of object;
  /// <summary>Event signature for save/load callbacks; Node is the .projdata document element.</summary>
  TProjectDataSavingEvent = procedure( Data: TProjectData; Node: IXmlNode ) of object;
  /// <summary>Event signature for project rename notifications.</summary>
  TProjectRenamedEvent = procedure( Data: TProjectData; const Filename, NewName: string ) of object;

  /// <summary>Subscriber object that registers itself with the project registry on construction.</summary>
  TProjectDataNotifier = class( TObject )
  public
    /// <summary>Raised when a new project becomes known to the registry.</summary>
    Added: TProjectDataEvent;
    /// <summary>Raised when a project is being destroyed.</summary>
    Destroying: TProjectDataEvent;
    /// <summary>Raised while saving the .projdata file so subscribers can append XML nodes.</summary>
    Saving: TProjectDataSavingEvent;
    /// <summary>Raised while loading the .projdata file so subscribers can read XML nodes.</summary>
    Loading: TProjectDataSavingEvent;
    /// <summary>Raised when a project is renamed.</summary>
    Renamed: TProjectRenamedEvent;

    /// <summary>Registers this subscriber with the project registry singleton.</summary>
    constructor Create;
    /// <summary>Unregisters this subscriber from the project registry.</summary>
    destructor Destroy; override;
  end;

  /// <summary>Registry of TProjectData entries plus a subscriber list and a transaction stack.</summary>
  TProjectDataList = class( TObject )
  private
    /// <summary>
    /// Non-owning list of the live TProjectData entries.  They are reference-counted (the IDE
    /// holds each one through AddNotifier) and remove themselves when freed, so the list must never
    /// free them: freeing one the IDE still references raised EInvalidPointer.
    /// </summary>
    FList: TObjectList;
    /// <summary>Active TProjectDataTransaction stack.</summary>
    FTransactions: TObjectList;
    /// <summary>Subscriber list of TProjectDataNotifier objects.</summary>
    FNotifiers: TList;
    /// <summary>Indexed accessor; lazily creates a TProjectData and reloads its side-car.</summary>
    /// <param name="Project">Project to look up.</param>
    /// <returns>The project's entry; created, registered and loaded from its side-car on first use.</returns>
    function GetProjectData( const Project: IOTAProject ): TProjectData;
    /// <summary>Subscriber accessor.</summary>
    /// <param name="Index">Zero-based subscriber index.</param>
    /// <returns>The subscriber at Index.</returns>
    function GetNotifier( Index: Integer ): TProjectDataNotifier;
    /// <summary>Number of registered subscribers.</summary>
    /// <returns>Number of registered subscribers.</returns>
    function GetNotifierCount: Integer;
  protected
    /// <summary>Broadcasts the Saving event to every subscriber.</summary>
    /// <param name="Data">The project whose side-car is processed.</param>
    /// <param name="Node">Document element of the .projdata file.</param>
    procedure Saving( Data: TProjectData; Node: IXmlNode ); virtual;
    /// <summary>Broadcasts the Loading event to every subscriber.</summary>
    /// <param name="Data">The project whose side-car is processed.</param>
    /// <param name="Node">Document element of the .projdata file.</param>
    procedure Loading( Data: TProjectData; Node: IXmlNode ); virtual;
    /// <summary>Broadcasts the Added event to every subscriber.</summary>
    /// <param name="Data">The project the event concerns.</param>
    procedure ProjectAdded( Data: TProjectData ); virtual;
    /// <summary>Broadcasts the Destroying event to every subscriber.</summary>
    /// <param name="Data">The project the event concerns.</param>
    procedure ProjectDestroying( Data: TProjectData ); virtual;
    /// <summary>Broadcasts the Renamed event to every subscriber.</summary>
    /// <param name="Data">The project being renamed.</param>
    /// <param name="Filename">Old project file name.</param>
    /// <param name="NewName">New project file name.</param>
    procedure ProjectRenamed( Data: TProjectData; const Filename, NewName: string ); virtual;

    /// <summary>
    /// Copy of the subscriber list for a broadcast: a handler may free a subscriber (its own or
    /// another) and shrink FNotifiers, so broadcasts iterate the copy and skip any subscriber that
    /// is no longer registered.
    /// </summary>
    /// <returns>The subscribers registered when the broadcast started.</returns>
    function NotifierSnapshot: TArray<TProjectDataNotifier>;

    /// <summary>Number of registered subscribers.</summary>
    property NotifierCount: Integer read GetNotifierCount;
    /// <summary>Indexed accessor for subscribers.</summary>
    property Notifiers[ Index: Integer ]: TProjectDataNotifier read GetNotifier;

    /// <summary>Adds a subscriber; usually invoked by TProjectDataNotifier.Create.</summary>
    /// <param name="ANotifier">Subscriber to add.</param>
    procedure AddNotifier( ANotifier: TProjectDataNotifier );
    /// <summary>Removes a subscriber; usually invoked by TProjectDataNotifier.Destroy.</summary>
    /// <param name="ANotifier">Subscriber to remove; not freed.</param>
    procedure RemoveNotifier( ANotifier: TProjectDataNotifier );

    // not working yet
    /// <summary>Pushes a new transaction onto the stack. Currently incomplete.</summary>
    procedure StartTransaction;
    /// <summary>Pops the topmost transaction without rolling back.</summary>
    procedure Commit;
    /// <summary>Pops the topmost transaction and asks it to roll back. Currently a no-op.</summary>
    procedure Rollback;
  public
    /// <summary>Initialises the registry; subscribers must be added separately.</summary>
    constructor Create;
    /// <summary>Releases the registry plus its transaction and subscriber lists.</summary>
    destructor Destroy; override;

    /// <summary>Default indexed accessor mapping IOTAProject to the matching TProjectData (created on demand).</summary>
    property ProjectData[ const Project: IOTAProject ]: TProjectData read GetProjectData; default;
  end;

/// <summary>Returns the lazily-instantiated project-registry singleton.</summary>
/// <returns>The registry, created on first use.</returns>
function ProjectDataList: TProjectDataList;

implementation

const
  sSuffix           = '.projdata';

var
  GlobalProjectDataList: TProjectDataList;

function ProjectDataList: TProjectDataList;
begin
  if not Assigned( GlobalProjectDataList ) then
    GlobalProjectDataList := TProjectDataList.Create;
  Result            := GlobalProjectDataList;
end;

{ TDataVariantItem }

constructor TDataVariantItem.Create( const AValue: Variant );
begin
  inherited Create;
  FValue            := AValue;
end;

{ TProjectDataList }

constructor TProjectDataList.Create;
begin
  inherited Create;
  FList             := TObjectList.Create( False );
  FTransactions     := TObjectList.Create;
  FNotifiers        := TList.Create;
end;

destructor TProjectDataList.Destroy;
begin
  // Unregister every entry the IDE still holds; dropping the IDE's reference frees it, and it
  // extracts itself from FList.
  // Downwards, because each entry extracts itself from FList when it is freed.
  for var iIndex: Integer := FList.Count - 1 downto 0 do
  begin
    if ( iIndex >= FList.Count ) then
      Continue;
    var oData       := TProjectData( FList[ iIndex ] );
    var oKeepAlive: IInterface := oData;
    oData.Detach;
    oKeepAlive      := nil; // may free oData now, while FList still exists
  end;

  FNotifiers.Free;
  FTransactions.Free;
  // Anything left is still referenced by the IDE and must not be freed here; cut its link to this
  // list, so its later Destroy ( or a late notification ) does not reach freed memory.
  for var iIndex: Integer := 0 to FList.Count - 1 do
    TProjectData( FList[ iIndex ] ).FOwner := nil;
  FList.Free;
  inherited Destroy;
end;

function TProjectDataList.GetProjectData( const Project: IOTAProject ): TProjectData;
var
  I                 : Integer;
begin
  for I := 0 to FList.Count - 1 do
  begin
    Result          := TProjectData( FList[ I ] );
    if Result.Project = Project then
      Exit;
  end;
  Result            := TProjectData.Create( Self, Project );
  Result.Reload;
end;

procedure TProjectDataList.Rollback;
begin
  TProjectDataTransaction( FTransactions[ FTransactions.Count - 1 ] ).Rollback;
end;

procedure TProjectDataList.StartTransaction;
begin
  FTransactions.Add( TProjectDataTransaction.Create( Self ) );
end;

procedure TProjectDataList.Commit;
begin
  FTransactions.Delete( FTransactions.Count - 1 );
end;

procedure TProjectDataList.Loading( Data: TProjectData; Node: IXmlNode );
begin
  // Every subscriber is called; the first exception is re-raised afterwards.
  var oFirstError: Exception := nil;
  for var oNotifier in NotifierSnapshot do
    if ( FNotifiers.IndexOf( oNotifier ) >= 0 ) and Assigned( oNotifier.Loading ) then
      try
        oNotifier.Loading( Data, Node );
      except
        on E: Exception do
          KeepFirstSubscriberError( oFirstError, 'Loading', E );
      end;
  if ( oFirstError <> nil ) then
    raise oFirstError;
end;

procedure TProjectDataList.Saving( Data: TProjectData; Node: IXmlNode );
begin
  // Every subscriber is called; the first exception is re-raised afterwards.
  var oFirstError: Exception := nil;
  for var oNotifier in NotifierSnapshot do
    if ( FNotifiers.IndexOf( oNotifier ) >= 0 ) and Assigned( oNotifier.Saving ) then
      try
        oNotifier.Saving( Data, Node );
      except
        on E: Exception do
          KeepFirstSubscriberError( oFirstError, 'Saving', E );
      end;
  if ( oFirstError <> nil ) then
    raise oFirstError;
end;

procedure TProjectDataList.ProjectAdded( Data: TProjectData );
begin
  // Every subscriber is called; the first exception is re-raised afterwards.
  var oFirstError: Exception := nil;
  for var oNotifier in NotifierSnapshot do
    if ( FNotifiers.IndexOf( oNotifier ) >= 0 ) and Assigned( oNotifier.Added ) then
      try
        oNotifier.Added( Data );
      except
        on E: Exception do
          KeepFirstSubscriberError( oFirstError, 'Added', E );
      end;
  if ( oFirstError <> nil ) then
    raise oFirstError;
end;

procedure TProjectDataList.ProjectDestroying( Data: TProjectData );
begin
  // Every subscriber is called; the first exception is re-raised afterwards.
  var oFirstError: Exception := nil;
  for var oNotifier in NotifierSnapshot do
    if ( FNotifiers.IndexOf( oNotifier ) >= 0 ) and Assigned( oNotifier.Destroying ) then
      try
        oNotifier.Destroying( Data );
      except
        on E: Exception do
          KeepFirstSubscriberError( oFirstError, 'Destroying', E );
      end;
  if ( oFirstError <> nil ) then
    raise oFirstError;
end;

procedure TProjectDataList.ProjectRenamed( Data: TProjectData;
  const Filename, NewName: string );
begin
  // Every subscriber is called; the first exception is re-raised afterwards.
  var oFirstError: Exception := nil;
  for var oNotifier in NotifierSnapshot do
    if ( FNotifiers.IndexOf( oNotifier ) >= 0 ) and Assigned( oNotifier.Renamed ) then
      try
        oNotifier.Renamed( Data, Filename, NewName );
      except
        on E: Exception do
          KeepFirstSubscriberError( oFirstError, 'Renamed', E );
      end;
  if ( oFirstError <> nil ) then
    raise oFirstError;
end;

procedure TProjectDataList.AddNotifier( ANotifier: TProjectDataNotifier );
begin
  FNotifiers.Add( ANotifier );
end;

procedure TProjectDataList.RemoveNotifier( ANotifier: TProjectDataNotifier );
begin
  FNotifiers.Extract( ANotifier );
end;

function TProjectDataList.GetNotifier( Index: Integer ): TProjectDataNotifier;
begin
  Result            := TProjectDataNotifier( FNotifiers[ Index ] );
end;

function TProjectDataList.NotifierSnapshot: TArray<TProjectDataNotifier>;
begin
  SetLength( Result, FNotifiers.Count );
  for var iIndex: Integer := 0 to FNotifiers.Count - 1 do
    Result[ iIndex ] := TProjectDataNotifier( FNotifiers[ iIndex ] );
end;

function TProjectDataList.GetNotifierCount: Integer;
begin
  Result            := FNotifiers.Count;
end;

{ TProjectData }

constructor TProjectData.Create( AOwner: TProjectDataList; AProject: IOTAProject );
begin
  inherited Create;
  FId               := -1; // not registered yet: a failed AddNotifier must not make Destroy remove notifier 0
  FOwner            := AOwner;
  FOwner.FList.Add( Self );
  FProject          := AProject;
  FFilename         := FProject.FileName;
  FId               := Project.AddNotifier( Self );
  FItems            := TStringList.Create;
  FAllowSaveData    := True;
  FNonPersistents   := TStringList.Create;
  try
    FOwner.ProjectAdded( Self );
  except
    Application.HandleException( Self );
  end;
end;

destructor TProjectData.Destroy;
begin
  if FId <> -1 then
  begin
    try
      if ( FOwner <> nil ) then
        FOwner.ProjectDestroying( Self );
    except
      Application.HandleException( Self );
    end;
  end;
  if ( FOwner <> nil ) then
    FOwner.FList.Extract( Self );
  Clear;
  FItems.Free;
  FNonPersistents.Free;

  if FId <> -1 then
    Project.RemoveNotifier( FId );
  inherited Destroy;
end;

procedure TProjectData.Clear;
var
  I                 : Integer;
begin
  for I := 0 to FItems.Count - 1 do
    if FItems.Objects[ I ] is TDataVariantItem then
      FItems.Objects[ I ].Free;
  FItems.Clear;
end;

procedure TProjectData.BeforeSave;
begin
end;

procedure TProjectData.Modified;
begin
end;

procedure TProjectData.ModuleRenamed( const NewName: string );
var
  Filename          : string;
begin
  Filename          := ChangeFileExt( FFileName, sSuffix );
  if FileExists( Filename ) then
    RenameFile( Filename, ChangeFileExt( NewName, sSuffix ) );
  try
    if ( FOwner <> nil ) then
      FOwner.ProjectRenamed( Self, FFilename, NewName );
  finally
    FFilename       := NewName;
  end;
end;

function TProjectData.CheckOverwrite: Boolean;
begin
  Result            := True;
end;

procedure TProjectData.Detach;
begin
  if ( FId = -1 ) then
    Exit;

  // Clear FId first: if RemoveNotifier drops the last reference, Destroy must not raise the
  // event or unregister a second time.
  var iId           := FId;
  FId               := -1;
  try
    if ( FOwner <> nil ) then
      FOwner.ProjectDestroying( Self );
  except
    Application.HandleException( Self );
  end;
  if ( FProject <> nil ) then
    FProject.RemoveNotifier( iId );
end;

procedure TProjectData.Destroyed;
begin
  // Hold a reference until this method returns: RemoveNotifier may drop the IDE's last one,
  // and the field below must not be written after the object has been freed.
  var oKeepAlive: IInterface := Self;
  Detach;
  FProject          := nil;
end;

procedure TProjectData.AfterSave;
var
  Doc               : IXmlDocument;
  Filename          : string;
  Node              : IXmlNode;
  I                 : Integer;
begin
  if not AllowSaveData then
    Exit;

  Filename          := ChangeFileExt( Project.FileName, sSuffix );

  {if IsReadOnly(Filename) then // we can't overwrite a read only file
    Exit;}
  try
    Doc             := NewXMLDocument;
    Doc.DocumentElement := Doc.CreateElement( 'Project', '' );
    Node            := Doc.DocumentElement.AddChild( 'Options' );
    for I := 0 to FItems.Count - 1 do
      Node.AddChild( FItems[ I ] ).Attributes[ 'Value' ] := ( FItems.Objects[ I ] as TDataVariantItem ).Value;
    if ( FOwner <> nil ) then
      FOwner.Saving( Self, Doc.DocumentElement );

    if ( Node.ChildNodes.Count > 0 ) or ( Doc.DocumentElement.ChildNodes.Count > 1 ) then
      Doc.SaveToFile( Filename )
    else
      DeleteFile( Filename );
  except
    Application.HandleException( Self );
  end;
end;

procedure TProjectData.Reload;
var
  Doc               : IXmlDocument;
  Filename          : string;
  Node              : IXmlNode;
  I                 : Integer;
begin
  if FLoading then
    Exit;

  Filename          := ChangeFileExt( Project.FileName, sSuffix );
  if FileExists( Filename ) then
  begin
    try
      FLoading      := True;
      try
        Doc         := LoadXmlDocument( Filename );
        Node        := Doc.DocumentElement.ChildNodes.FindNode( 'Options' );
        if Node <> nil then
        begin
          Clear;
          for I := 0 to Node.ChildNodes.Count - 1 do
            Values[ Node.ChildNodes[ I ].NodeName ] := Node.ChildNodes[ I ].Attributes[ 'Value' ];
        end;
        if ( FOwner <> nil ) then
          FOwner.Loading( Self, Doc.DocumentElement );
      finally
        FLoading    := False;
      end;
    except
      Application.HandleException( Self );
      Exit;
    end;
  end;
end;

function TProjectData.GetValue( const Name: string ): Variant;
var
  Index             : Integer;
begin
  Index             := FItems.IndexOf( Name );
  if Index = -1 then
    Result          := Null
  else if FItems.Objects[ Index ] is TDataVariantItem then
    Result          := TDataVariantItem( FItems.Objects[ Index ] ).Value
  else
    Result          := Null;
end;

function TProjectData.HasValue( const Name: string ): Boolean;
begin
  Result            := FItems.IndexOf( Name ) <> -1;
end;

procedure TProjectData.SetValue( const Name: string; const Value: Variant );
var
  Index             : Integer;
begin
  Index             := FItems.IndexOf( Name );
  if Index = -1 then
  begin
    FItems.AddObject( Name, TDataVariantItem.Create( Value ) );
    if not Loading then
    begin
      Project.MarkModified;
    end;
  end
  else if FItems.Objects[ Index ] is TDataVariantItem then
  begin
    if TDataVariantItem( FItems.Objects[ Index ] ).Value <> Value then
    begin
      TDataVariantItem( FItems.Objects[ Index ] ).Value := Value;
      if not Loading then
      begin
        Project.MarkModified;
      end;
    end;
  end;
end;

function TProjectData.GetNonPersistent( const Name: string ): TObject;
var
  Index             : Integer;
begin
  Index             := FNonPersistents.IndexOf( Name );
  if Index <> -1 then
    Result          := FNonPersistents.Objects[ Index ]
  else
    Result          := nil;
end;

procedure TProjectData.SetNonPersistent( const Name: string; const Value: TObject );
var
  Index             : Integer;
begin
  Index             := FNonPersistents.IndexOf( Name );
  if Index <> -1 then
    FNonPersistents.Objects[ Index ] := Value
  else
    FNonPersistents.AddObject( Name, Value );
end;

{ TProjectDataTransaction }

constructor TProjectDataTransaction.Create( AOwner: TProjectDataList );
var
  I                 : Integer;
begin
  inherited Create;
  FOwner            := AOwner;
  FProjects         := TList.Create;
  FItems            := TObjectList.Create;

  for I := 0 to AOwner.FList.Count - 1 do
  begin
    FProjects.Add( Pointer( TProjectData( AOwner.FList[ I ] ).Project ) );
    //    FItems.Add(
    //    FProjects.
  end;
end;

destructor TProjectDataTransaction.Destroy;
begin
  FProjects.Free;
  inherited Destroy;
end;

procedure TProjectDataTransaction.Rollback;
begin

end;

{ TProjectDataNotifier }

constructor TProjectDataNotifier.Create;
begin
  inherited Create;
  ProjectDataList.AddNotifier( Self );
end;

destructor TProjectDataNotifier.Destroy;
begin
  ProjectDataList.RemoveNotifier( Self );
  inherited Destroy;
end;

initialization

finalization
  FreeAndNil( GlobalProjectDataList );

end.

