{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit ModuleData;

/// <summary>
/// Per-module bookkeeping layer that tracks every IOTAModule open in the IDE, hangs an
/// arbitrary key/value bucket off each one and broadcasts module lifecycle events (added,
/// destroyed, before/after save, modified, renamed) to subscribed TModuleDataNotifier objects.
/// Use ModuleDataList to access the singleton instance.
/// </summary>

interface

uses
  System.SysUtils, System.Classes, System.Contnrs, ToolsAPI, Vcl.Forms, IDENotifiers;

type
  /// <summary>Forward declaration of the module-data registry.</summary>
  TModuleDataList = class;

  /// <summary>Per-module record installed as an IOTAModuleNotifier; holds an arbitrary bucket dictionary keyed by TObject.</summary>
  TModuleData = class( TInterfacedObject, IOTANotifier, IOTAModuleNotifier )
  private
    /// <summary>Owning registry.</summary>
    FOwner: TModuleDataList;
    /// <summary>Notifier ID returned by Module.AddNotifier; -1 once Destroyed has been received.</summary>
    FId: Integer;
    /// <summary>The wrapped IOTAModule.</summary>
    FModule: IOTAModule;
    /// <summary>Lazily-created bucket dictionary (key TObject -> value TObject).</summary>
    FBucket: TBucketList;
    /// <summary>Cached filename used to detect renames.</summary>
    FFilename: string;
    /// <summary>Indexed-property getter for the bucket dictionary.</summary>
    /// <param name="Index">Key object, usually the subscriber that stored the value.</param>
    /// <returns>The stored object, or nil when none is stored.</returns>
    function GetBucket( Index: TObject ): TObject;
    /// <summary>Indexed-property setter; assigning nil removes the entry.</summary>
    /// <param name="Index">Key object.</param>
    /// <param name="Value">Object to store; nil removes the entry.  Not owned.</param>
    procedure SetBucket( Index: TObject; const Value: TObject );
  protected
    { IOTAModuleNotifier }
    /// <summary>IOTAModuleNotifier: forwards the event to the owning registry.</summary>
    procedure AfterSave;
    /// <summary>IOTAModuleNotifier: forwards the event to the owning registry.</summary>
    procedure BeforeSave;
    /// <summary>IOTAModuleNotifier: always returns True (overwrite allowed).</summary>
    /// <returns>Always True: the module may be overwritten.</returns>
    function CheckOverwrite: Boolean;
    /// <summary>IOTANotifier: handles the module-destroyed event and detaches.</summary>
    procedure Destroyed;
    /// <summary>IOTAModuleNotifier: forwards the event to the owning registry.</summary>
    procedure Modified;
    /// <summary>IOTAModuleNotifier: forwards the rename event and updates FFilename.</summary>
    /// <param name="NewName">New file name of the module.</param>
    procedure ModuleRenamed( const NewName: string );
  public
    /// <summary>Registers this object as a notifier on AModule and adds it to AOwner.</summary>
    /// <param name="AOwner">Registry that lists this entry.</param>
    /// <param name="AModule">Module to watch.</param>
    constructor Create( AOwner: TModuleDataList; AModule: IOTAModule );
    /// <summary>Removes the notifier and frees the bucket dictionary.</summary>
    destructor Destroy; override;
    /// <summary>
    /// Raises the Destroying event once and unregisters from the IDE.  The IDE then drops its
    /// reference, which normally frees this object, so the caller must hold its own interface
    /// reference across the call and must not touch the object afterwards without one.
    /// </summary>
    procedure Detach;

    /// <summary>Indexed access to the bucket dictionary; assigning nil removes the entry.</summary>
    property Bucket[ Index: TObject ]: TObject read GetBucket write SetBucket;

    /// <summary>The wrapped IOTAModule.</summary>
    property Module: IOTAModule read FModule;
    /// <summary>Last-known filename of the module.</summary>
    property Filename: string read FFilename;
  end;

  /// <summary>Event signature for module lifecycle notifications (added, modified, save, destroying).</summary>
  TModuleDataEvent = procedure( Data: TModuleData ) of object;
  /// <summary>Event signature raised when a module is renamed; NewName is the new filename.</summary>
  TModuleDataRenamedEvent = procedure( Data: TModuleData; const NewName: string ) of object;

  /// <summary>Subscriber object that registers itself with the module registry on construction.</summary>
  TModuleDataNotifier = class( TObject )
  public
    /// <summary>Raised once the registry first sees a module.</summary>
    Added: TModuleDataEvent;
    /// <summary>Raised when a module is being destroyed.</summary>
    Destroying: TModuleDataEvent;
    /// <summary>Raised before a module is saved.</summary>
    BeforeSave: TModuleDataEvent;
    /// <summary>Raised after a module has been saved.</summary>
    AfterSave: TModuleDataEvent;
    /// <summary>Raised whenever the IDE marks the module as modified.</summary>
    Modified: TModuleDataEvent;
    /// <summary>Raised when a module is renamed.</summary>
    Renamed: TModuleDataRenamedEvent;

    /// <summary>Registers this notifier with the module registry singleton.</summary>
    constructor Create;
    /// <summary>Unregisters this notifier from the module registry.</summary>
    destructor Destroy; override;
  end;

  /// <summary>
  /// Registry of TModuleData entries plus a subscriber list of TModuleDataNotifier objects.
  /// On construction it scans every currently open module and installs a TIDENotifier so newly
  /// opened modules are picked up automatically.
  /// </summary>
  TModuleDataList = class( TObject )
  private
    /// <summary>
    /// Non-owning list of the live TModuleData instances.  They are reference-counted (the IDE
    /// holds each one through AddNotifier) and remove themselves when freed, so the list must never
    /// free them: freeing one the IDE still references raised EInvalidPointer.
    /// </summary>
    FList: TObjectList;
    /// <summary>Subscriber list of TModuleDataNotifier objects.</summary>
    FNotifiers: TList;
    /// <summary>IDE notifier that triggers UpdateModules whenever a file is opened.</summary>
    FIDENotifier: TIDENotifier;
    /// <summary>Indexed accessor by module; lazily creates a TModuleData for unseen modules.</summary>
    /// <param name="Module">Module to look up.</param>
    /// <returns>The module's entry; created and registered as a notifier on first use.</returns>
    function GetModuleData( const Module: IOTAModule ): TModuleData;
    /// <summary>Subscriber accessor.</summary>
    /// <param name="Index">Zero-based subscriber index.</param>
    /// <returns>The subscriber at Index.</returns>
    function GetNotifier( Index: Integer ): TModuleDataNotifier;
    /// <summary>Number of registered subscribers.</summary>
    /// <returns>Number of registered subscribers.</returns>
    function GetNotifierCount: Integer;
  protected
    /// <summary>Walks IOTAModuleServices.Modules and ensures a TModuleData exists for each entry.</summary>
    procedure UpdateModules;

    /// <summary>Broadcasts the Added event to every subscriber.</summary>
    /// <param name="Data">The module the event concerns.</param>
    procedure ModuleAdded( Data: TModuleData ); virtual;
    /// <summary>Broadcasts the Destroying event to every subscriber.</summary>
    /// <param name="Data">The module the event concerns.</param>
    procedure ModuleDestroying( Data: TModuleData ); virtual;
    /// <summary>Broadcasts the BeforeSave event to every subscriber.</summary>
    /// <param name="Data">The module the event concerns.</param>
    procedure ModuleBeforeSave( Data: TModuleData ); virtual;
    /// <summary>Broadcasts the AfterSave event to every subscriber.</summary>
    /// <param name="Data">The module the event concerns.</param>
    procedure ModuleAfterSave( Data: TModuleData ); virtual;
    /// <summary>Broadcasts the Modified event to every subscriber.</summary>
    /// <param name="Data">The module the event concerns.</param>
    procedure ModuleModified( Data: TModuleData ); virtual;
    /// <summary>Broadcasts the Renamed event to every subscriber.</summary>
    /// <param name="Data">The module being renamed.</param>
    /// <param name="NewName">New file name.</param>
    procedure ModuleRenamed( Data: TModuleData; const NewName: string ); virtual;

    /// <summary>
    /// Copy of the subscriber list for a broadcast: a handler may free a subscriber (its own or
    /// another) and shrink FNotifiers, so broadcasts iterate the copy and skip any subscriber that
    /// is no longer registered.
    /// </summary>
    /// <returns>The subscribers registered when the broadcast started.</returns>
    function NotifierSnapshot: TArray<TModuleDataNotifier>;

    /// <summary>Number of registered subscribers.</summary>
    property NotifierCount: Integer read GetNotifierCount;
    /// <summary>Indexed accessor for subscribers.</summary>
    property Notifiers[ Index: Integer ]: TModuleDataNotifier read GetNotifier;

    /// <summary>Adds a subscriber; usually called by TModuleDataNotifier.Create.</summary>
    /// <param name="ANotifier">Subscriber to add.</param>
    procedure AddNotifier( ANotifier: TModuleDataNotifier );
    /// <summary>Removes a subscriber; usually called by TModuleDataNotifier.Destroy.</summary>
    /// <param name="ANotifier">Subscriber to remove; not freed.</param>
    procedure RemoveNotifier( ANotifier: TModuleDataNotifier );
  protected
    /// <summary>IDE file-notification handler; calls UpdateModules whenever a file is opened.</summary>
    /// <param name="NotifyCode">The kind of file event.</param>
    /// <param name="FileName">File the event concerns.</param>
    /// <param name="Cancel">Not changed.</param>
    procedure FileNotification( NotifyCode: TOTAFileNotification; const FileName: string;
      var Cancel: Boolean );
  public
    /// <summary>Initialises the registry, populates it from currently open modules and installs the IDE notifier.</summary>
    constructor Create;
    /// <summary>Releases the registry, the IDE notifier and the subscriber list.</summary>
    destructor Destroy; override;

    /// <summary>Default indexed accessor mapping IOTAModule to the matching TModuleData (created on demand).</summary>
    property ModuleData[ const Module: IOTAModule ]: TModuleData read GetModuleData; default;
  end;

/// <summary>Returns the lazily-instantiated module-registry singleton.</summary>
/// <returns>The registry, created on first use.</returns>
function ModuleDataList: TModuleDataList;

implementation

var
  GlobalModuleDataList: TModuleDataList;

function ModuleDataList: TModuleDataList;
begin
  if not Assigned( GlobalModuleDataList ) then
    GlobalModuleDataList := TModuleDataList.Create;
  Result            := GlobalModuleDataList;
end;

{ TModuleDataList }

constructor TModuleDataList.Create;
begin
  inherited Create;
  FList             := TObjectList.Create( False );
  FNotifiers        := TList.Create;
  UpdateModules;
  FIDENotifier      := TIDENotifier.Create;
  FIDENotifier.OnFileNotification := FileNotification;
end;

destructor TModuleDataList.Destroy;
begin
  FIDENotifier.Free;

  // Unregister every entry the IDE still holds; dropping the IDE's reference frees it, and it
  // extracts itself from FList.
  // Downwards, because each entry extracts itself from FList when it is freed.
  for var iIndex: Integer := FList.Count - 1 downto 0 do
  begin
    if ( iIndex >= FList.Count ) then
      Continue;
    var oData       := TModuleData( FList[ iIndex ] );
    var oKeepAlive: IInterface := oData;
    oData.Detach;
    oKeepAlive      := nil; // may free oData now, while FList still exists
  end;

  FNotifiers.Free;
  // Anything left is still referenced by the IDE and must not be freed here; cut its link to this
  // list, so its later Destroy ( or a late notification ) does not reach freed memory.
  for var iIndex: Integer := 0 to FList.Count - 1 do
    TModuleData( FList[ iIndex ] ).FOwner := nil;
  FList.Free;
  inherited Destroy;
end;

function TModuleDataList.GetModuleData( const Module: IOTAModule ): TModuleData;
var
  i                 : Integer;
begin
  for i := 0 to FList.Count - 1 do
  begin
    Result          := TModuleData( FList[ i ] );
    if Result.Module = Module then
      Exit;
  end;
  Result            := TModuleData.Create( Self, Module );
end;

procedure TModuleDataList.ModuleAdded( Data: TModuleData );
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

procedure TModuleDataList.ModuleDestroying( Data: TModuleData );
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

procedure TModuleDataList.ModuleBeforeSave( Data: TModuleData );
begin
  // Every subscriber is called; the first exception is re-raised afterwards.
  var oFirstError: Exception := nil;
  for var oNotifier in NotifierSnapshot do
    if ( FNotifiers.IndexOf( oNotifier ) >= 0 ) and Assigned( oNotifier.BeforeSave ) then
      try
        oNotifier.BeforeSave( Data );
      except
        on E: Exception do
          KeepFirstSubscriberError( oFirstError, 'BeforeSave', E );
      end;
  if ( oFirstError <> nil ) then
    raise oFirstError;
end;

procedure TModuleDataList.ModuleAfterSave( Data: TModuleData );
begin
  // Every subscriber is called; the first exception is re-raised afterwards.
  var oFirstError: Exception := nil;
  for var oNotifier in NotifierSnapshot do
    if ( FNotifiers.IndexOf( oNotifier ) >= 0 ) and Assigned( oNotifier.AfterSave ) then
      try
        oNotifier.AfterSave( Data );
      except
        on E: Exception do
          KeepFirstSubscriberError( oFirstError, 'AfterSave', E );
      end;
  if ( oFirstError <> nil ) then
    raise oFirstError;
end;

procedure TModuleDataList.ModuleModified( Data: TModuleData );
begin
  // Every subscriber is called; the first exception is re-raised afterwards.
  var oFirstError: Exception := nil;
  for var oNotifier in NotifierSnapshot do
    if ( FNotifiers.IndexOf( oNotifier ) >= 0 ) and Assigned( oNotifier.Modified ) then
      try
        oNotifier.Modified( Data );
      except
        on E: Exception do
          KeepFirstSubscriberError( oFirstError, 'Modified', E );
      end;
  if ( oFirstError <> nil ) then
    raise oFirstError;
end;

procedure TModuleDataList.ModuleRenamed( Data: TModuleData; const NewName: string );
begin
  // Every subscriber is called; the first exception is re-raised afterwards.
  var oFirstError: Exception := nil;
  for var oNotifier in NotifierSnapshot do
    if ( FNotifiers.IndexOf( oNotifier ) >= 0 ) and Assigned( oNotifier.Renamed ) then
      try
        oNotifier.Renamed( Data, NewName );
      except
        on E: Exception do
          KeepFirstSubscriberError( oFirstError, 'Renamed', E );
      end;
  if ( oFirstError <> nil ) then
    raise oFirstError;
end;

procedure TModuleDataList.AddNotifier( ANotifier: TModuleDataNotifier );
begin
  FNotifiers.Add( ANotifier );
end;

procedure TModuleDataList.RemoveNotifier( ANotifier: TModuleDataNotifier );
begin
  FNotifiers.Extract( ANotifier );
end;

function TModuleDataList.GetNotifier( Index: Integer ): TModuleDataNotifier;
begin
  Result            := TModuleDataNotifier( FNotifiers[ Index ] );
end;

function TModuleDataList.NotifierSnapshot: TArray<TModuleDataNotifier>;
begin
  SetLength( Result, FNotifiers.Count );
  for var iIndex: Integer := 0 to FNotifiers.Count - 1 do
    Result[ iIndex ] := TModuleDataNotifier( FNotifiers[ iIndex ] );
end;

function TModuleDataList.GetNotifierCount: Integer;
begin
  Result            := FNotifiers.Count;
end;

procedure TModuleDataList.UpdateModules;
var
  Modules           : IOTAModuleServices;
  i                 : Integer;
begin
  { Create TModuleData objects for all opened modules }
  if Supports( BorlandIDEServices, IOTAModuleServices, Modules ) then
  begin
    try
      for i := 0 to Modules.ModuleCount - 1 do
        ModuleData[ Modules.Modules[ i ] ];
    except
      // catch Delphi 5 exceptions
    end;
  end;
end;

procedure TModuleDataList.FileNotification(
  NotifyCode: TOTAFileNotification; const FileName: string;
  var Cancel: Boolean );
begin
  case NotifyCode of
    ofnFileOpened:
      UpdateModules;
  end;
end;

{ TModuleData }

constructor TModuleData.Create( AOwner: TModuleDataList; AModule: IOTAModule );
begin
  inherited Create;
  FId               := -1; // not registered yet: a failed AddNotifier must not make Destroy remove notifier 0
  FOwner            := AOwner;
  FOwner.FList.Add( Self );
  FModule           := AModule;
  FFilename         := Module.FileName;
  FId               := Module.AddNotifier( Self );
end;

destructor TModuleData.Destroy;
begin
  if FId <> -1 then
  begin
    try
      if ( FOwner <> nil ) then
        FOwner.ModuleDestroying( Self );
    except
      Application.HandleException( Self );
    end;
  end;
  if ( FOwner <> nil ) then
    FOwner.FList.Extract( Self );
  FBucket.Free;

  if FId <> -1 then
    Module.RemoveNotifier( FId );
  inherited Destroy;
end;

procedure TModuleData.Detach;
begin
  if ( FId = -1 ) then
    Exit;

  // Clear FId first: if RemoveNotifier drops the last reference, Destroy must not raise the
  // event or unregister a second time.
  var iId           := FId;
  FId               := -1;
  try
    if ( FOwner <> nil ) then
      FOwner.ModuleDestroying( Self );
  except
    Application.HandleException( Self );
  end;
  if ( FModule <> nil ) then
    FModule.RemoveNotifier( iId );
end;

procedure TModuleData.Destroyed;
begin
  // Hold a reference until this method returns: RemoveNotifier may drop the IDE's last one,
  // and the fields below must not be written after the object has been freed.
  var oKeepAlive: IInterface := Self;
  Detach;
  FModule           := nil;
end;

function TModuleData.CheckOverwrite: Boolean;
begin
  Result            := True;
end;

procedure TModuleData.BeforeSave;
begin
  if ( FOwner <> nil ) then
    FOwner.ModuleBeforeSave( Self );
end;

procedure TModuleData.AfterSave;
begin
  if ( FOwner <> nil ) then
    FOwner.ModuleAfterSave( Self );
end;

procedure TModuleData.Modified;
begin
  if ( FOwner <> nil ) then
    FOwner.ModuleModified( Self );
end;

procedure TModuleData.ModuleRenamed( const NewName: string );
begin
  if ( FOwner <> nil ) then
    FOwner.ModuleRenamed( Self, NewName );
  FFilename         := NewName;
end;

function TModuleData.GetBucket( Index: TObject ): TObject;
begin
  if not Assigned( FBucket ) or not FBucket.Find( Index, Pointer( Result ) ) then
    Result          := nil;
end;

procedure TModuleData.SetBucket( Index: TObject; const Value: TObject );
begin
  if not Assigned( FBucket ) then
  begin
    if Value = nil then
      Exit;
    FBucket         := TBucketList.Create( bl128 );
  end;
  if FBucket.Exists( Index ) then
  begin
    if Value = nil then
      FBucket.Remove( Index )
    else
      FBucket.Data[ Index ] := Value;
  end
  else if Value <> nil then
    FBucket.Add( Index, Value );
end;

{ TModuleDataNotifier }

constructor TModuleDataNotifier.Create;
begin
  inherited Create;
  ModuleDataList.AddNotifier( Self );
end;

destructor TModuleDataNotifier.Destroy;
begin
  ModuleDataList.RemoveNotifier( Self );
  inherited Destroy;
end;

initialization

finalization
  FreeAndNil( GlobalModuleDataList );

end.

