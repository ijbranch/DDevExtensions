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
  SysUtils, Classes, Contnrs, ToolsAPI, Forms, IDENotifiers;

type
  /// <summary>Forward declaration of the module-data registry.</summary>
  TModuleDataList = class;

  /// <summary>Per-module record installed as an IOTAModuleNotifier; holds an arbitrary bucket dictionary keyed by TObject.</summary>
  TModuleData = class(TInterfacedObject, IOTANotifier, IOTAModuleNotifier)
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
    function GetBucket(Index: TObject): TObject;
    /// <summary>Indexed-property setter; assigning nil removes the entry.</summary>
    procedure SetBucket(Index: TObject; const Value: TObject);
  protected
    { IOTAModuleNotifier }
    /// <summary>IOTAModuleNotifier: forwards the event to the owning registry.</summary>
    procedure AfterSave;
    /// <summary>IOTAModuleNotifier: forwards the event to the owning registry.</summary>
    procedure BeforeSave;
    /// <summary>IOTAModuleNotifier: always returns True (overwrite allowed).</summary>
    function CheckOverwrite: Boolean;
    /// <summary>IOTANotifier: handles the module-destroyed event and detaches.</summary>
    procedure Destroyed;
    /// <summary>IOTAModuleNotifier: forwards the event to the owning registry.</summary>
    procedure Modified;
    /// <summary>IOTAModuleNotifier: forwards the rename event and updates FFilename.</summary>
    procedure ModuleRenamed(const NewName: String);
  public
    /// <summary>Registers this object as a notifier on AModule and adds it to AOwner.</summary>
    constructor Create(AOwner: TModuleDataList; AModule: IOTAModule);
    /// <summary>Removes the notifier and frees the bucket dictionary.</summary>
    destructor Destroy; override;

    /// <summary>Indexed access to the bucket dictionary; assigning nil removes the entry.</summary>
    property Bucket[Index: TObject]: TObject read GetBucket write SetBucket;

    /// <summary>The wrapped IOTAModule.</summary>
    property Module: IOTAModule read FModule;
    /// <summary>Last-known filename of the module.</summary>
    property Filename: string read FFilename;
  end;


  /// <summary>Event signature for module lifecycle notifications (added, modified, save, destroying).</summary>
  TModuleDataEvent = procedure(Data: TModuleData) of object;
  /// <summary>Event signature raised when a module is renamed; NewName is the new filename.</summary>
  TModuleDataRenamedEvent = procedure(Data: TModuleData; const NewName: string) of object;

  /// <summary>Subscriber object that registers itself with the module registry on construction.</summary>
  TModuleDataNotifier = class(TObject)
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
  TModuleDataList = class(TObject)
  private
    /// <summary>Owned list of TModuleData instances.</summary>
    FList: TObjectList;
    /// <summary>Subscriber list of TModuleDataNotifier objects.</summary>
    FNotifiers: TList;
    /// <summary>IDE notifier that triggers UpdateModules whenever a file is opened.</summary>
    FIDENotifier: TIDENotifier;
    /// <summary>Indexed accessor by module; lazily creates a TModuleData for unseen modules.</summary>
    function GetModuleData(const Module: IOTAModule): TModuleData;
    /// <summary>Subscriber accessor.</summary>
    function GetNotifier(Index: Integer): TModuleDataNotifier;
    /// <summary>Number of registered subscribers.</summary>
    function GetNotifierCount: Integer;
  protected
    /// <summary>Walks IOTAModuleServices.Modules and ensures a TModuleData exists for each entry.</summary>
    procedure UpdateModules;

    /// <summary>Broadcasts the Added event to every subscriber.</summary>
    procedure ModuleAdded(Data: TModuleData); virtual;
    /// <summary>Broadcasts the Destroying event to every subscriber.</summary>
    procedure ModuleDestroying(Data: TModuleData); virtual;
    /// <summary>Broadcasts the BeforeSave event to every subscriber.</summary>
    procedure ModuleBeforeSave(Data: TModuleData); virtual;
    /// <summary>Broadcasts the AfterSave event to every subscriber.</summary>
    procedure ModuleAfterSave(Data: TModuleData); virtual;
    /// <summary>Broadcasts the Modified event to every subscriber.</summary>
    procedure ModuleModified(Data: TModuleData); virtual;
    /// <summary>Broadcasts the Renamed event to every subscriber.</summary>
    procedure ModuleRenamed(Data: TModuleData; const NewName: string); virtual;

    /// <summary>Number of registered subscribers.</summary>
    property NotifierCount: Integer read GetNotifierCount;
    /// <summary>Indexed accessor for subscribers.</summary>
    property Notifiers[Index: Integer]: TModuleDataNotifier read GetNotifier;

    /// <summary>Adds a subscriber; usually called by TModuleDataNotifier.Create.</summary>
    procedure AddNotifier(ANotifier: TModuleDataNotifier);
    /// <summary>Removes a subscriber; usually called by TModuleDataNotifier.Destroy.</summary>
    procedure RemoveNotifier(ANotifier: TModuleDataNotifier);
  protected
    /// <summary>IDE file-notification handler; calls UpdateModules whenever a file is opened.</summary>
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string;
      var Cancel: Boolean);
  public
    /// <summary>Initialises the registry, populates it from currently open modules and installs the IDE notifier.</summary>
    constructor Create;
    /// <summary>Releases the registry, the IDE notifier and the subscriber list.</summary>
    destructor Destroy; override;

    /// <summary>Default indexed accessor mapping IOTAModule to the matching TModuleData (created on demand).</summary>
    property ModuleData[const Module: IOTAModule]: TModuleData read GetModuleData; default;
  end;

/// <summary>Returns the lazily-instantiated module-registry singleton.</summary>
function ModuleDataList: TModuleDataList;

implementation

var
  GlobalModuleDataList: TModuleDataList;

function ModuleDataList: TModuleDataList;
begin
  if not Assigned(GlobalModuleDataList) then
    GlobalModuleDataList := TModuleDataList.Create;
  Result := GlobalModuleDataList;
end;

{ TModuleDataList }

constructor TModuleDataList.Create;
begin
  inherited Create;
  FList := TObjectList.Create;
  FNotifiers := TList.Create;
  UpdateModules;
  FIDENotifier := TIDENotifier.Create;
  FIDENotifier.OnFileNotification := FileNotification;
end;

destructor TModuleDataList.Destroy;
begin
  FIDENotifier.Free;
  FNotifiers.Free;
  FList.Free;
  inherited Destroy;
end;

function TModuleDataList.GetModuleData(const Module: IOTAModule): TModuleData;
var
  i: Integer;
begin
  for i := 0 to FList.Count - 1 do
  begin
    Result := TModuleData(FList[i]);
    if Result.Module = Module then
      Exit;
  end;
  Result := TModuleData.Create(Self, Module);
end;

procedure TModuleDataList.ModuleAdded(Data: TModuleData);
var
  i: Integer;
begin
  for i := 0 to NotifierCount - 1 do
    if Assigned(Notifiers[i].Added) then
      Notifiers[i].Added(Data);
end;

procedure TModuleDataList.ModuleDestroying(Data: TModuleData);
var
  i: Integer;
begin
  for i := 0 to NotifierCount - 1 do
    if Assigned(Notifiers[i].Destroying) then
      Notifiers[i].Destroying(Data);
end;

procedure TModuleDataList.ModuleBeforeSave(Data: TModuleData);
var
  i: Integer;
begin
  for i := 0 to NotifierCount - 1 do
    if Assigned(Notifiers[i].BeforeSave) then
      Notifiers[i].BeforeSave(Data);
end;

procedure TModuleDataList.ModuleAfterSave(Data: TModuleData);
var
  i: Integer;
begin
  for i := 0 to NotifierCount - 1 do
    if Assigned(Notifiers[i].AfterSave) then
      Notifiers[i].AfterSave(Data);
end;

procedure TModuleDataList.ModuleModified(Data: TModuleData);
var
  i: Integer;
begin
  for i := 0 to NotifierCount - 1 do
    if Assigned(Notifiers[i].Modified) then
      Notifiers[i].Modified(Data);
end;

procedure TModuleDataList.ModuleRenamed(Data: TModuleData; const NewName: string);
var
  i: Integer;
begin
  for i := 0 to NotifierCount - 1 do
    if Assigned(Notifiers[i].Renamed) then
      Notifiers[i].Renamed(Data, NewName);
end;

procedure TModuleDataList.AddNotifier(ANotifier: TModuleDataNotifier);
begin
  FNotifiers.Add(ANotifier);
end;

procedure TModuleDataList.RemoveNotifier(ANotifier: TModuleDataNotifier);
begin
  FNotifiers.Extract(ANotifier);
end;

function TModuleDataList.GetNotifier(Index: Integer): TModuleDataNotifier;
begin
  Result := TModuleDataNotifier(FNotifiers[Index]);
end;

function TModuleDataList.GetNotifierCount: Integer;
begin
  Result := FNotifiers.Count;
end;

procedure TModuleDataList.UpdateModules;
var
  Modules: IOTAModuleServices;
  i: Integer;
begin
  { Create TModuleData objects for all opened modules }
  if Supports(BorlandIDEServices, IOTAModuleServices, Modules) then
  begin
    try
      for i := 0 to Modules.ModuleCount - 1 do
        ModuleData[Modules.Modules[i]];
    except
      // catch Delphi 5 exceptions
    end;
  end;
end;

procedure TModuleDataList.FileNotification(
  NotifyCode: TOTAFileNotification; const FileName: string;
  var Cancel: Boolean);
begin
  case NotifyCode of
    ofnFileOpened:
      UpdateModules;
  end;
end;

{ TModuleData }

constructor TModuleData.Create(AOwner: TModuleDataList; AModule: IOTAModule);
begin
  inherited Create;
  FOwner := AOwner;
  FOwner.FList.Add(Self);
  FModule := AModule;
  FFilename := Module.FileName;
  FId := Module.AddNotifier(Self);
end;

destructor TModuleData.Destroy;
begin
  if FId <> -1 then
  begin
    try
      FOwner.ModuleDestroying(Self);
    except
      Application.HandleException(Self);
    end;
  end;
  FOwner.FList.Extract(Self);
  FBucket.Free;

  if FId <> -1 then
    Module.RemoveNotifier(FId);
  inherited Destroy;
end;

procedure TModuleData.Destroyed;
begin
  if FId <> -1 then
  begin
    try
      FOwner.ModuleDestroying(Self);
    except
      Application.HandleException(Self);
    end;
    Module.RemoveNotifier(FId);
  end;
  FModule := nil;
  FId := -1;
end;

function TModuleData.CheckOverwrite: Boolean;
begin
  Result := True;
end;

procedure TModuleData.BeforeSave;
begin
  FOwner.ModuleBeforeSave(Self);
end;

procedure TModuleData.AfterSave;
begin
  FOwner.ModuleAfterSave(Self);
end;

procedure TModuleData.Modified;
begin
  FOwner.ModuleModified(Self);
end;

procedure TModuleData.ModuleRenamed(const NewName: String);
begin
  FOwner.ModuleRenamed(Self, NewName);
  FFilename := NewName;
end;

function TModuleData.GetBucket(Index: TObject): TObject;
begin
  if not Assigned(FBucket) or not FBucket.Find(Index, Pointer(Result)) then
    Result := nil;
end;

procedure TModuleData.SetBucket(Index: TObject; const Value: TObject);
begin
  if not Assigned(FBucket) then
  begin
    if Value = nil then
      Exit;
    FBucket := TBucketList.Create(bl128);
  end;
  if FBucket.Exists(Index) then
  begin
    if Value = nil then
      FBucket.Remove(Index)
    else
      FBucket.Data[Index] := Value;
  end
  else
  if Value <> nil then
    FBucket.Add(Index, Value);
end;

{ TModuleDataNotifier }

constructor TModuleDataNotifier.Create;
begin
  inherited Create;
  ModuleDataList.AddNotifier(Self);
end;

destructor TModuleDataNotifier.Destroy;
begin
  ModuleDataList.RemoveNotifier(Self);
  inherited Destroy;
end;

initialization

finalization
  FreeAndNil(GlobalModuleDataList);

end.
