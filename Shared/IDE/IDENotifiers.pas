{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit IDENotifiers;

/// <summary>
/// Helper layer over IOTAIDENotifier that lets multiple subscribers receive BeforeCompile,
/// AfterCompile and FileNotification callbacks via Delphi-style event handlers without each
/// extension having to implement a separate ToolsAPI notifier.
/// </summary>

interface

uses
  System.SysUtils, System.Classes, System.Contnrs, ToolsAPI;

type
  /// <summary>Event raised before the IDE starts compiling Project. Set Cancel to True to abort.</summary>
  TBeforeCompileEvent = procedure( const Project: IOTAProject; IsCodeInsight: Boolean;
    var Cancel: Boolean ) of object;
  /// <summary>Event raised after the IDE has finished compiling Project; Succeeded reports the outcome.</summary>
  TAfterCompileEvent = procedure( const Project: IOTAProject; Succeeded: Boolean; IsCodeInsight: Boolean ) of object;
  /// <summary>Event raised when the IDE notifies of a file-level event (open/close/save/...). Set Cancel to True to suppress the operation.</summary>
  TFileNotificationEvent = procedure( NotifyCode: TOTAFileNotification; const FileName: string;
    var Cancel: Boolean ) of object;

  /// <summary>
  /// Subscriber object that registers itself with the global IDE notifier list on construction and
  /// re-publishes ToolsAPI notifications via Delphi event properties.
  /// </summary>
  TIDENotifier = class( TObject )
  private
    /// <summary>Handler invoked before each compile.</summary>
    FOnBeforeCompile: TBeforeCompileEvent;
    /// <summary>Handler invoked when the IDE raises a file notification.</summary>
    FOnFileNotification: TFileNotificationEvent;
    /// <summary>Handler invoked after each compile.</summary>
    FOnAfterCompile: TAfterCompileEvent;
  protected
    /// <summary>Calls FOnBeforeCompile if assigned. Override to extend behaviour.</summary>
    /// <param name="Project">Project about to be compiled.</param>
    /// <param name="IsCodeInsight">True for a Code Insight background compile.</param>
    /// <param name="Cancel">Set to True to cancel the compile.</param>
    procedure BeforeCompile( const Project: IOTAProject; IsCodeInsight: Boolean; var Cancel: Boolean ); virtual;
    /// <summary>Calls FOnAfterCompile if assigned. Override to extend behaviour.</summary>
    /// <param name="Project">Project that was compiled.</param>
    /// <param name="Succeeded">True when the compile succeeded.</param>
    /// <param name="IsCodeInsight">True for a Code Insight background compile.</param>
    procedure AfterCompile( Project: IOTAProject; Succeeded: Boolean; IsCodeInsight: Boolean ); virtual;
    /// <summary>Calls FOnFileNotification if assigned. Override to extend behaviour.</summary>
    /// <param name="NotifyCode">The kind of file event.</param>
    /// <param name="FileName">File the event concerns.</param>
    /// <param name="Cancel">Set to True to cancel the operation, where the IDE allows it.</param>
    procedure FileNotification( NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean ); virtual;
  public
    /// <summary>
    /// Registers this notifier with the IDE notifier list.
    /// </summary>
    /// <remarks>
    /// On Win64 the IDE registration is skipped — registering a multi-interface
    /// IOTAIDENotifier / IOTAIDENotifier50 / IOTAIDENotifier80 wrapper with the
    /// Delphi 13 64-bit IDE makes it AV deterministically at
    /// <c>rtl370.bpl + 0x19AC54</c> during the "Checking project dependencies..."
    /// phase of any compile. The object is still constructed so call-sites with
    /// typed fields don't get nil derefs; it simply never receives callbacks.
    /// </remarks>
    constructor Create;
    /// <summary>Unregisters this notifier from the IDE notifier list (Win32 only — Win64 never registered).</summary>
    destructor Destroy; override;

    /// <summary>Event raised before each project compile.</summary>
    property OnBeforeCompile: TBeforeCompileEvent read FOnBeforeCompile write FOnBeforeCompile;
    /// <summary>Event raised after each project compile.</summary>
    property OnAfterCompile: TAfterCompileEvent read FOnAfterCompile write FOnAfterCompile;
    /// <summary>Event raised on each ToolsAPI file notification.</summary>
    property OnFileNotification: TFileNotificationEvent read FOnFileNotification write FOnFileNotification;
  end;

/// <summary>
/// Collects subscriber exceptions during a broadcast so every subscriber is still called: the
/// first exception is kept ( taken over with AcquireExceptionObject ) for the caller to re-raise
/// after the loop, so EurekaLog and the IDE still see it; later ones are written to the debugger
/// output.  Call it only from inside an exception handler, passing the handled exception.
/// </summary>
/// <param name="AFirst">Holds the first exception; nil until one is kept.  The caller raises it after the loop.</param>
/// <param name="AEvent">Name of the notification being broadcast, for the log.</param>
/// <param name="E">The exception being handled.</param>
procedure KeepFirstSubscriberError( var AFirst: Exception; const AEvent: string; E: Exception );

implementation

uses
  Winapi.Windows;

procedure KeepFirstSubscriberError( var AFirst: Exception; const AEvent: string; E: Exception );
begin
  if ( AFirst = nil ) then
    AFirst          := Exception( AcquireExceptionObject )
  else
    OutputDebugString( PChar( Format( 'DDevExtensions: %s subscriber raised %s: %s', [ AEvent, E.ClassName, E.Message ] ) ) );
end;

type
  TIDENotifierList = class( TComponent, IOTANotifier, IOTAIDENotifier80, IOTAIDENotifier, IOTAIDENotifier50 )
  private
    FId: Integer;
    FNotifiers: TList;
    function GetNotifier( Index: Integer ): TIDENotifier;
    function GetNotifierCount: Integer;
    function Snapshot: TArray<TIDENotifier>;
    function IsLive( ANotifier: TIDENotifier ): Boolean;
  protected
    property NotifierCount: Integer read GetNotifierCount;
    property Notifiers[ Index: Integer ]: TIDENotifier read GetNotifier;

    procedure AddNotifier( ANotifier: TIDENotifier );
    procedure RemoveNotifier( ANotifier: TIDENotifier );
  protected
    { IOTAIDENotifier }
    procedure AfterCompile( Succeeded: Boolean ); overload;
    procedure AfterSave;
    procedure BeforeCompile( const Project: IOTAProject; var Cancel: Boolean ); overload;
    procedure BeforeSave;
    procedure Destroyed;
    procedure FileNotification( NotifyCode: TOTAFileNotification; const FileName: string;
      var Cancel: Boolean );
    procedure Modified;

    { IOTAIDENotifier50 }
    procedure BeforeCompile( const Project: IOTAProject; IsCodeInsight: Boolean;
      var Cancel: Boolean ); overload;
    procedure AfterCompile( Succeeded: Boolean; IsCodeInsight: Boolean ); overload;

    { IOTAIDENotifier80 }
    procedure AfterCompile( const Project: IOTAProject; Succeeded: Boolean; IsCodeInsight: Boolean ); overload;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
  end;

function IDENotifierList: TIDENotifierList; forward;

var
  GlobalIDENotifierList: TIDENotifierList;

function IDENotifierList: TIDENotifierList;
begin
  if not Assigned( GlobalIDENotifierList ) then
    GlobalIDENotifierList := TIDENotifierList.Create;
  Result            := GlobalIDENotifierList;
end;

{ TIDENotifierList }

constructor TIDENotifierList.Create;
begin
  inherited Create( nil );
  FNotifiers        := TList.Create;
  FId               := ( BorlandIDEServices as IOTAServices ).AddNotifier( Self );
end;

destructor TIDENotifierList.Destroy;
begin
  if FId <> -1 then
    ( BorlandIDEServices as IOTAServices ).RemoveNotifier( FId );
  FNotifiers.Free;
  inherited Destroy;
end;

procedure TIDENotifierList.AddNotifier( ANotifier: TIDENotifier );
begin
  FNotifiers.Add( ANotifier );
end;

procedure TIDENotifierList.RemoveNotifier( ANotifier: TIDENotifier );
begin
  FNotifiers.Extract( ANotifier );
end;

function TIDENotifierList.GetNotifier( Index: Integer ): TIDENotifier;
begin
  Result            := TIDENotifier( FNotifiers[ Index ] );
end;

function TIDENotifierList.GetNotifierCount: Integer;
begin
  Result            := FNotifiers.Count;
end;

function TIDENotifierList.Snapshot: TArray<TIDENotifier>;
begin
  // A subscriber may free itself, or another, from inside its handler and shrink FNotifiers;
  // broadcasting over a copy keeps the loop's indexes valid.
  SetLength( Result, FNotifiers.Count );
  for var iIndex: Integer := 0 to FNotifiers.Count - 1 do
    Result[ iIndex ] := TIDENotifier( FNotifiers[ iIndex ] );
end;

function TIDENotifierList.IsLive( ANotifier: TIDENotifier ): Boolean;
begin
  // Skip a subscriber that an earlier handler of the same broadcast has freed.
  Result            := FNotifiers.IndexOf( ANotifier ) >= 0;
end;

procedure TIDENotifierList.FileNotification( NotifyCode: TOTAFileNotification;
  const FileName: string; var Cancel: Boolean );
begin
  var oFirstError: Exception := nil;
  for var oNotifier in Snapshot do
  begin
    if not IsLive( oNotifier ) then
      Continue;
    try
      oNotifier.FileNotification( NotifyCode, FileName, Cancel );
    except
      on E: Exception do
        KeepFirstSubscriberError( oFirstError, 'FileNotification', E );
    end;
    if Cancel then
      Break;
  end;
  if ( oFirstError <> nil ) then
    raise oFirstError;
end;

procedure TIDENotifierList.AfterCompile( Succeeded: Boolean );
begin
end;

procedure TIDENotifierList.AfterSave;
begin
end;

procedure TIDENotifierList.BeforeCompile( const Project: IOTAProject; var Cancel: Boolean );
begin
end;

procedure TIDENotifierList.BeforeSave;
begin
end;

procedure TIDENotifierList.Destroyed;
begin
  FID               := -1;
end;

procedure TIDENotifierList.Modified;
begin
end;

procedure TIDENotifierList.AfterCompile( Succeeded, IsCodeInsight: Boolean );
begin
end;

procedure TIDENotifierList.BeforeCompile( const Project: IOTAProject;
  IsCodeInsight: Boolean; var Cancel: Boolean );
begin
  var oFirstError: Exception := nil;
  for var oNotifier in Snapshot do
  begin
    if not IsLive( oNotifier ) then
      Continue;
    try
      oNotifier.BeforeCompile( Project, IsCodeInsight, Cancel );
    except
      on E: Exception do
        KeepFirstSubscriberError( oFirstError, 'BeforeCompile', E );
    end;
    if Cancel then
      Break;
  end;
  if ( oFirstError <> nil ) then
    raise oFirstError;
end;

procedure TIDENotifierList.AfterCompile( const Project: IOTAProject; Succeeded: Boolean; IsCodeInsight: Boolean );
begin
  var oFirstError: Exception := nil;
  for var oNotifier in Snapshot do
  begin
    if not IsLive( oNotifier ) then
      Continue;
    try
      oNotifier.AfterCompile( Project, Succeeded, IsCodeInsight );
    except
      on E: Exception do
        KeepFirstSubscriberError( oFirstError, 'AfterCompile', E );
    end;
  end;
  if ( oFirstError <> nil ) then
    raise oFirstError;
end;

{ TIDENotifier }

constructor TIDENotifier.Create;
begin
  inherited Create;
{$IFNDEF CPUX64}
  // Win64 (Delphi 13.1): registering this notifier with the IDE via
  // (BorlandIDEServices as IOTAServices).AddNotifier(Self) makes the IDE AV at
  // rtl370.bpl + 0x19AC54 reading $FFFFFFFFFFFFFFFF during the
  // "Checking project dependencies..." phase of any Win64 build. The crash
  // happens regardless of whether any handlers are attached (FNotifiers can be
  // empty) and is deterministic and bisected to AddNotifier on this multi-
  // interface class (IOTAIDENotifier + 50 + 80 with overloaded BeforeCompile/
  // AfterCompile signatures). The TIDENotifier object is still constructed so
  // call-sites holding a typed field don't get nil derefs; it just never
  // receives compile / file callbacks on Win64.
  IDENotifierList.AddNotifier( Self );
{$ENDIF}
end;

destructor TIDENotifier.Destroy;
begin
{$IFNDEF CPUX64}
  IDENotifierList.RemoveNotifier( Self );
{$ENDIF}
  inherited Destroy;
end;

procedure TIDENotifier.AfterCompile( Project: IOTAProject; Succeeded, IsCodeInsight: Boolean );
begin
  if Assigned( FOnAfterCompile ) then
    FOnAfterCompile( project, Succeeded, IsCodeInsight );
end;

procedure TIDENotifier.BeforeCompile( const Project: IOTAProject;
  IsCodeInsight: Boolean; var Cancel: Boolean );
begin
  if Assigned( FOnBeforeCompile ) then
    FOnBeforeCompile( Project, IsCodeInsight, Cancel );
end;

procedure TIDENotifier.FileNotification( NotifyCode: TOTAFileNotification;
  const FileName: string; var Cancel: Boolean );
begin
  if Assigned( FOnFileNotification ) then
    FOnFileNotification( NotifyCode, FileName, Cancel );
end;

initialization

finalization
  FreeAndNil( GlobalIDENotifierList );

end.

