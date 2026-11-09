{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude Code                                           *}
{*                                                                            *}
{* Parallel Build All: the IDE hook, the settings and the progress window     *}
{*                                                                            *}
{******************************************************************************}

unit ParallelBuild;

/// <summary>
/// Implements "Parallel Build All": when the option is on, the IDE's Build All Projects command builds the
/// projects of the open project group several at a time, each in its own MSBuild process, in place of the
/// IDE's one-at-a-time build.  When the option is off, or the group is one the parallel build does not
/// handle, the IDE's own Build All runs unchanged.
/// </summary>
/// <remarks>
/// This unit owns the IDE side only: taking over the Build All action, reading the group from the
/// ToolsAPI, the progress window and the Messages view.  The rules ( what may build together, what waits
/// for what, EurekaLog ) are in <c>ParallelBuildCore</c>; the processes and threads are in
/// <c>ParallelBuildRunner</c>.
/// </remarks>

{$I ..\DelphiExtension.inc}

interface

uses
  System.SysUtils, System.Classes,
  PluginConfig, FrmTreePages;

type
  /// <summary>Plug-in configuration that owns the Parallel Build All feature and its settings.</summary>
  TParallelBuildConfig = class( TPluginConfig )
  private
    /// <summary>Backing field for Active.</summary>
    FActive: Boolean;
    /// <summary>Backing field for MaxWorkers.</summary>
    FMaxWorkers: Integer;
    /// <summary>Backing field for RunEurekaLog.</summary>
    FRunEurekaLog: Boolean;
    /// <summary>Backing field for Ecc32Path.</summary>
    FEcc32Path: string;
    /// <summary>The IDE's own Build All handler, kept so it can be called and put back.</summary>
    FOrgBuildAllExecute: TNotifyEvent;
    /// <summary>The IDE's Build All action, the sender its own handler expects; nil until the action is taken over.</summary>
    FBuildAllAction: TBasicAction;
    /// <summary>True once the Build All action has been taken over.</summary>
    FHooked: Boolean;
    /// <summary>True while a parallel build is running, so a second Build All goes nowhere.</summary>
    FBusy: Boolean;
    /// <summary>Index of our Project Manager menu creator, or -1 when it is not registered.</summary>
    FMenuCreatorIndex: Integer;
    /// <summary>
    /// Build All, from the main menu or the Project Manager: a parallel build when it applies.
    /// </summary>
    /// <returns>
    /// True when nothing more is to be done ( the parallel build ran, or one is already running ); False when
    /// the IDE's own build must run.
    /// </returns>
    function HandleBuildAll: Boolean;
    /// <summary>Takes over the IDE's Build All action.</summary>
    procedure HookBuildAll;
    /// <summary>Puts the IDE's own handler back, if ours is still the one installed.</summary>
    procedure UnhookBuildAll;
    /// <summary>The Build All handler: a parallel build when it applies, otherwise the IDE's own.</summary>
    /// <param name="Sender">The action.</param>
    procedure BuildAllExecute( Sender: TObject );
    /// <summary>Runs the parallel build for the open group.</summary>
    /// <returns>False when the group is not one the parallel build handles, so the IDE's own build must run.</returns>
    /// <exception cref="EInvalidOpException">
    /// The build environment could not be read from <c>rsvars.bat</c>, or MSBuild was not found.  Caught by
    /// <see cref="BuildAllExecute"/>, which tells the user and runs the IDE's own build.
    /// </exception>
    function TryParallelBuild: Boolean;
  protected
    /// <summary>Sets default values for a new configuration.</summary>
    procedure Init; override;
    /// <summary>Returns the options-tree page used to edit this plug-in's settings.</summary>
    /// <returns>The Parallel Build All options page.</returns>
    function GetOptionPages: TTreePage; override;
  public
    /// <summary>Creates the configuration, loads its settings and takes over the Build All action.</summary>
    constructor Create;
    /// <summary>Puts the IDE's Build All handler back.</summary>
    destructor Destroy; override;
    /// <summary>The path of <c>ecc32.exe</c> in use: the setting, or EurekaLog's default for this IDE when the setting is empty.</summary>
    /// <returns>The full path; the file may not exist.</returns>
    function EffectiveEcc32Path: string;
  published
    /// <summary>Master switch: True builds a project group in parallel, False leaves Build All to the IDE.</summary>
    property Active: Boolean read FActive write FActive;
    /// <summary>The most projects built at once; 0 means one per logical CPU, up to eight.</summary>
    property MaxWorkers: Integer read FMaxWorkers write FMaxWorkers;
    /// <summary>Run EurekaLog's <c>ecc32</c> on a Release build of a project that has a <c>.eof</c>.</summary>
    property RunEurekaLog: Boolean read FRunEurekaLog write FRunEurekaLog;
    /// <summary>Full path of <c>ecc32.exe</c>; empty means EurekaLog's default folder for this IDE.</summary>
    property Ecc32Path: string read FEcc32Path write FEcc32Path;
  end;

/// <summary>
/// Initialises or shuts down the Parallel Build All plug-in by creating or freeing the global
/// TParallelBuildConfig instance.
/// </summary>
/// <param name="Unload">False to load the plug-in, True to unload it.</param>
procedure InitPlugin( Unload: Boolean );

implementation

uses
  Winapi.Windows,
  System.IOUtils, System.Diagnostics, System.UITypes, System.Math,
  Vcl.Controls, Vcl.Forms, Vcl.Menus, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Buttons, Vcl.Dialogs,
  ToolsAPI, ToolsAPIHelpers,
  Main, ParallelBuildCore, ParallelBuildRunner, FrmeOptionPageParallelBuild;

const
  /// <summary>The name of the IDE's Project > Build All Projects menu item.</summary>
  BUILD_ALL_MENU_ITEM = 'ProjectBuildAllItem';
  /// <summary>The name of the group this feature writes to in the Messages view.</summary>
  MESSAGE_GROUP = 'Parallel Build';
  /// <summary>EurekaLog's package folder for the IDE this DLL is built for.</summary>
  EUREKALOG_STUDIO_FOLDER =
    {$IF CompilerVersion >= 37.0} 'Studio37'
    {$ELSEIF CompilerVersion >= 36.0} 'Studio29'
    {$ELSEIF CompilerVersion >= 35.0} 'Studio28'
    {$ELSEIF CompilerVersion >= 34.0} 'Studio27'
    {$ELSE} 'Studio26'
    {$IFEND};

type
  /// <summary>
  /// The modal window shown while a parallel build runs: one row per project with its state, and a button
  /// that cancels the build and then closes the window.
  /// </summary>
  TParallelBuildProgressForm = class( TForm )
  private
    /// <summary>One row per project.  Rows are always written by index, never through a kept item reference.</summary>
    FListView: TListView;
    /// <summary>The running totals under the list.</summary>
    FSummary: TLabel;
    /// <summary>Cancels a running build; closes the window once it has finished.</summary>
    FButton: TBitBtn;
    /// <summary>Refreshes the elapsed time while the build runs.</summary>
    FTimer: TTimer;
    /// <summary>The plan being built.</summary>
    FPlan: TArray<TParallelProject>;
    /// <summary>The co-ordinator; owned by this form.</summary>
    FBuild: TParallelBuild;
    /// <summary>Times the whole build.</summary>
    FWatch: TStopwatch;
    /// <summary>The Messages-view group the results go to.</summary>
    FGroup: IOTAMessageGroup;
    /// <summary>True once the co-ordinator has finished.</summary>
    FDone: Boolean;
    /// <summary>Counts of projects by final state.</summary>
    FSucceeded, FFailed, FSkipped: Integer;
    /// <summary>Counts of hints and warnings across every project.</summary>
    FHints, FWarnings: Integer;
    /// <summary>Main thread: a project has started building.</summary>
    /// <param name="AIndex">The plan index.</param>
    procedure ProjectStarted( AIndex: Integer );
    /// <summary>Main thread: a project has finished or been skipped.</summary>
    /// <param name="AIndex">The plan index.</param>
    /// <param name="AState">Its final state.</param>
    /// <param name="AResult">Its result.</param>
    procedure ProjectFinished( AIndex: Integer; AState: TProjectState; const AResult: TProjectResult );
    /// <summary>Main thread ( the thread's OnTerminate ): the whole build has finished.</summary>
    /// <param name="Sender">The co-ordinator.</param>
    procedure BuildTerminated( Sender: TObject );
    /// <summary>Writes one project's outcome to the Messages view.</summary>
    /// <param name="AIndex">The plan index.</param>
    /// <param name="AState">Its final state.</param>
    /// <param name="AResult">Its result.</param>
    procedure AddMessages( AIndex: Integer; AState: TProjectState; const AResult: TProjectResult );
    /// <summary>Sets a row's state text.</summary>
    /// <param name="AIndex">The plan index, which is also the row index.</param>
    /// <param name="AText">The state text.</param>
    /// <param name="ATime">The time text, or empty.</param>
    procedure SetRow( AIndex: Integer; const AText, ATime: string );
    /// <summary>Rewrites the totals line.</summary>
    procedure UpdateSummary;
    /// <summary>The button: cancel while building, close when done.</summary>
    /// <param name="Sender">The button.</param>
    procedure ButtonClick( Sender: TObject );
    /// <summary>The timer: refreshes the totals line so the elapsed time moves.</summary>
    /// <param name="Sender">The timer.</param>
    procedure TimerTick( Sender: TObject );
    /// <summary>The window may close only once the build has finished; before that a close request cancels it.</summary>
    /// <param name="Sender">The form.</param>
    /// <param name="CanClose">Set to False while the build runs.</param>
    procedure FormCloseQuery( Sender: TObject; var CanClose: Boolean );
  public
    /// <summary>Builds the window and the co-ordinator; the build starts when the window is shown.</summary>
    /// <param name="APlan">The plan to build.</param>
    /// <param name="AMaxWorkers">The most projects built at once.</param>
    /// <param name="ASettings">Where MSBuild and <c>ecc32</c> are.</param>
    constructor CreateFor( const APlan: TArray<TParallelProject>; AMaxWorkers: Integer; const ASettings: TMSBuildSettings );
    /// <summary>Stops the build if it is still running and frees the co-ordinator.</summary>
    destructor Destroy; override;
  end;

var
  ParallelBuildConfig: TParallelBuildConfig;

procedure InitPlugin( Unload: Boolean );
begin

  if not Unload then
    ParallelBuildConfig := TParallelBuildConfig.Create
  else
    FreeAndNil( ParallelBuildConfig );

end;

{ Helpers }

/// <summary>A project's name for display: its file name without path or extension.</summary>
/// <param name="AProject">The project.</param>
/// <returns>The name.</returns>
function DisplayName( const AProject: TParallelProject ): string;
begin

  Result := ChangeFileExt( ExtractFileName( AProject.FileName ), '' );

end;

/// <summary>Formats a duration in milliseconds as seconds with one decimal.</summary>
/// <param name="AMilliseconds">The duration.</param>
/// <returns>For example <c>12.3 s</c>.</returns>
function FormatSeconds( AMilliseconds: Int64 ): string;
begin

  Result := Format( '%.1f s', [ AMilliseconds / 1000 ] );

end;

/// <summary>True when the IDE has a package loaded whose name begins with a project's name.</summary>
/// <param name="AProjectName">The package project's name.</param>
/// <returns>True when building it outside the IDE would fail on the loaded BPL.</returns>
function IsPackageLoadedInIDE( const AProjectName: string ): Boolean;
var
  intfPackages      : IOTAPackageServices;
begin

  Result := False;

  if not Supports( BorlandIDEServices, IOTAPackageServices, intfPackages ) then Exit;

  for var iI := 0 to intfPackages.PackageCount - 1 do
    if intfPackages.PackageNames[ iI ].StartsWith( AProjectName, True ) then Exit( True );

end;

{ TParallelBuildProgressForm }

constructor TParallelBuildProgressForm.CreateFor( const APlan: TArray<TParallelProject>; AMaxWorkers: Integer;
  const ASettings: TMSBuildSettings );
var
  intfMessages      : IOTAMessageServices;
begin

  inherited CreateNew( Application );

  FPlan        := APlan;
  Caption      := Format( 'Parallel Build All - %d projects, %d at a time', [ Length( FPlan ), AMaxWorkers ] );
  BorderIcons  := [ biSystemMenu ];
  BorderStyle  := bsSizeable;
  Position     := poMainFormCenter;
  ClientWidth  := 520;
  ClientHeight := 420;
  OnCloseQuery := FormCloseQuery;

  var oBottom := TPanel.Create( Self );
  oBottom.Parent     := Self;
  oBottom.Align      := alBottom;
  oBottom.Height     := 44;
  oBottom.BevelOuter := bvNone;

  FButton := TBitBtn.Create( Self );
  FButton.Parent  := oBottom;
  FButton.Caption := '&Cancel';
  FButton.SetBounds( oBottom.ClientWidth - 108, 8, 100, 28 );
  FButton.Anchors := [ akTop, akRight ];
  FButton.OnClick := ButtonClick;

  FSummary := TLabel.Create( Self );
  FSummary.Parent := oBottom;
  FSummary.SetBounds( 8, 14, 380, 16 );

  FListView := TListView.Create( Self );
  FListView.Parent    := Self;
  FListView.Align     := alClient;
  FListView.ViewStyle := vsReport;
  FListView.ReadOnly  := True;
  FListView.RowSelect := True;

  var oColumn := FListView.Columns.Add;
  oColumn.Caption := 'Project';
  oColumn.Width   := 240;
  oColumn := FListView.Columns.Add;
  oColumn.Caption := 'State';
  oColumn.Width   := 170;
  oColumn := FListView.Columns.Add;
  oColumn.Caption := 'Time';
  oColumn.Width   := 80;

  for var iI := 0 to High( FPlan ) do
  begin
    var oItem := FListView.Items.Add;
    oItem.Caption := DisplayName( FPlan[ iI ] ) + ' ( ' + FPlan[ iI ].Config + ', ' + FPlan[ iI ].Platform + ' )';
    oItem.SubItems.Add( 'waiting' );
    oItem.SubItems.Add( '' );
  end;

  if Supports( BorlandIDEServices, IOTAMessageServices, intfMessages ) then
  begin
    FGroup := intfMessages.GetGroup( MESSAGE_GROUP );
    if FGroup = nil then FGroup := intfMessages.AddMessageGroup( MESSAGE_GROUP );
    intfMessages.ClearMessageGroup( FGroup );
  end;

  FBuild := TParallelBuild.Create( FPlan, AMaxWorkers, MSBuildAction( ASettings ) );

  // Both events arrive on the co-ordinator's thread.  They are queued against the thread object, so
  // freeing it ( in Destroy ) discards any that have not run yet.
  var oBuild := FBuild;
  FBuild.OnStarted :=
    procedure( AIndex: Integer )
    begin
      TThread.Queue( oBuild,
        procedure
        begin
          ProjectStarted( AIndex );
        end );
    end;
  FBuild.OnFinished :=
    procedure( AIndex: Integer; AState: TProjectState; const AResult: TProjectResult )
    begin
      var rResult := AResult;   // copied now: the closure runs later, on the main thread
      TThread.Queue( oBuild,
        procedure
        begin
          ProjectFinished( AIndex, AState, rResult );
        end );
    end;
  FBuild.OnTerminate := BuildTerminated;

  FTimer := TTimer.Create( Self );
  FTimer.Interval := 250;
  FTimer.OnTimer  := TimerTick;

  FWatch := TStopwatch.StartNew;
  UpdateSummary;
  FBuild.Start;

end;

destructor TParallelBuildProgressForm.Destroy;
begin

  // Cancels if still running, waits for the workers, and discards the queued events that touch this form.
  FreeAndNil( FBuild );

  inherited Destroy;

end;

procedure TParallelBuildProgressForm.SetRow( AIndex: Integer; const AText, ATime: string );
begin

  if ( AIndex < 0 ) or ( AIndex >= FListView.Items.Count ) then Exit;

  FListView.Items[ AIndex ].SubItems[ 0 ] := AText;
  FListView.Items[ AIndex ].SubItems[ 1 ] := ATime;

end;

procedure TParallelBuildProgressForm.UpdateSummary;
begin

  FSummary.Caption := Format( '%d built, %d failed, %d not built of %d   -   %s', [ FSucceeded, FFailed, FSkipped,
    Length( FPlan ), FormatSeconds( FWatch.ElapsedMilliseconds ) ] );

end;

procedure TParallelBuildProgressForm.ProjectStarted( AIndex: Integer );
begin

  SetRow( AIndex, 'building...', '' );

  if ( AIndex >= 0 ) and ( AIndex < FListView.Items.Count ) then FListView.Items[ AIndex ].MakeVisible( False );

end;

procedure TParallelBuildProgressForm.ProjectFinished( AIndex: Integer; AState: TProjectState; const AResult: TProjectResult );
begin

  var iHints    := 0;
  var iWarnings := 0;

  for var rDiagnostic in AResult.Diagnostics do
    case rDiagnostic.Kind of
      dkHint: Inc( iHints );
      dkWarning: Inc( iWarnings );
    end;

  Inc( FHints, iHints );
  Inc( FWarnings, iWarnings );

  case AState of
    psSucceeded:
      begin
        Inc( FSucceeded );
        if iHints + iWarnings > 0 then
          SetRow( AIndex, Format( 'built ( %d warnings, %d hints )', [ iWarnings, iHints ] ), FormatSeconds( AResult.ElapsedMs ) )
        else
          SetRow( AIndex, 'built', FormatSeconds( AResult.ElapsedMs ) );
      end;
    psFailed:
      begin
        Inc( FFailed );
        if AResult.Cancelled then
          SetRow( AIndex, 'cancelled', FormatSeconds( AResult.ElapsedMs ) )
        else
          SetRow( AIndex, 'FAILED', FormatSeconds( AResult.ElapsedMs ) );
      end;
  else
    Inc( FSkipped );
    SetRow( AIndex, 'not built', '' );
  end;

  AddMessages( AIndex, AState, AResult );
  UpdateSummary;

end;

procedure TParallelBuildProgressForm.AddMessages( AIndex: Integer; AState: TProjectState; const AResult: TProjectResult );
const
  PREFIXES: array[ TDiagnosticKind ] of string = ( 'Hint', 'Warning', 'Error', 'Fatal' );
var
  intfMessages      : IOTAMessageServices;
  pLineRef          : Pointer;
begin

  if not Supports( BorlandIDEServices, IOTAMessageServices, intfMessages ) then Exit;

  var sName    := DisplayName( FPlan[ AIndex ] );
  var sOutcome := 'not built';

  case AState of
    psSucceeded: sOutcome := 'built in ' + FormatSeconds( AResult.ElapsedMs );
    psFailed: sOutcome := 'FAILED after ' + FormatSeconds( AResult.ElapsedMs );
  end;

  intfMessages.AddTitleMessage( sName + ': ' + sOutcome, FGroup );

  for var sNote in AResult.Notes do
    intfMessages.AddTitleMessage( '    ' + sNote, FGroup );

  var sProjectDir := ExtractFilePath( FPlan[ AIndex ].FileName );

  for var rDiagnostic in AResult.Diagnostics do
  begin
    var sFile := rDiagnostic.FileName;
    // The compiler names a file as the project refers to it, which may be relative to the project.
    if ( sFile <> '' ) and ( ExtractFileDrive( sFile ) = '' ) and FileExists( sProjectDir + sFile ) then
      sFile := ExpandFileName( sProjectDir + sFile );
    if sFile = '' then sFile := FPlan[ AIndex ].FileName;
    intfMessages.AddToolMessage( sFile, rDiagnostic.Code + ' ' + rDiagnostic.Text, PREFIXES[ rDiagnostic.Kind ],
      rDiagnostic.Line, 1, nil, pLineRef, FGroup );
  end;

  // A failure with nothing parsed from it: show the end of what was printed, where the reason is.
  if ( AState = psFailed ) and ( not HasErrors( AResult.Diagnostics ) ) and ( Trim( AResult.Output ) <> '' ) then
  begin
    var saLines := Trim( AResult.Output ).Split( [ #13#10, #10 ], TStringSplitOptions.ExcludeEmpty );
    for var iI := Max( 0, Length( saLines ) - 15 ) to High( saLines ) do
      intfMessages.AddTitleMessage( '    ' + saLines[ iI ], FGroup );
  end;

end;

procedure TParallelBuildProgressForm.BuildTerminated( Sender: TObject );
var
  intfMessages      : IOTAMessageServices;
begin

  FDone := True;
  FWatch.Stop;
  FTimer.Enabled  := False;
  FButton.Caption := '&Close';
  FButton.Enabled := True;
  UpdateSummary;

  if Supports( BorlandIDEServices, IOTAMessageServices, intfMessages ) then
  begin
    if ( FBuild <> nil ) and ( FBuild.FatalException is Exception ) then
      intfMessages.AddTitleMessage( 'Parallel Build All stopped: ' + Exception( FBuild.FatalException ).Message, FGroup );
    intfMessages.AddTitleMessage( Format( 'Parallel Build All: %d built, %d failed, %d not built, %d warnings, %d hints in %s',
      [ FSucceeded, FFailed, FSkipped, FWarnings, FHints, FormatSeconds( FWatch.ElapsedMilliseconds ) ] ), FGroup );
    intfMessages.ShowMessageView( FGroup );
  end;

  // The window stays open even after a clean build, so the times and the total can be read ( Ian, 2026-11-10 ).
  if FButton.CanFocus then FButton.SetFocus;

end;

procedure TParallelBuildProgressForm.ButtonClick( Sender: TObject );
begin

  if FDone then
    ModalResult := mrClose
  else
  begin
    FButton.Enabled := False;
    FButton.Caption := 'Cancelling...';
    FBuild.Cancel;
  end;

end;

procedure TParallelBuildProgressForm.TimerTick( Sender: TObject );
begin

  UpdateSummary;

end;

procedure TParallelBuildProgressForm.FormCloseQuery( Sender: TObject; var CanClose: Boolean );
begin

  CanClose := FDone;

  if ( not FDone ) and FButton.Enabled then ButtonClick( FButton );

end;

{ Project Manager context menu }

type
  /// <summary>
  /// The Build All item of a project group's context menu in the Project Manager.  It takes the place of
  /// the IDE's own item there, which does not go through the main menu's action.
  /// </summary>
  TBuildAllMenu = class( TInterfacedObject, IOTANotifier, IOTALocalMenu, IOTAProjectManagerMenu )
  private
    /// <summary>The caption.</summary>
    FCaption: string;
    /// <summary>The checked state.</summary>
    FChecked: Boolean;
    /// <summary>The enabled state.</summary>
    FEnabled: Boolean;
    /// <summary>The help context.</summary>
    FHelpContext: Integer;
    /// <summary>The item name.</summary>
    FName: string;
    /// <summary>The parent item's name; empty for the top level.</summary>
    FParent: string;
    /// <summary>The position in the menu.</summary>
    FPosition: Integer;
    /// <summary>The verb.</summary>
    FVerb: string;
  public
    /// <summary>Creates the item with our own name and verb, so the IDE calls <see cref="Execute"/> for it.</summary>
    constructor Create;
    // IOTANotifier
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;
    // IOTALocalMenu
    function GetCaption: string;
    function GetChecked: Boolean;
    function GetEnabled: Boolean;
    function GetHelpContext: Integer;
    function GetName: string;
    function GetParent: string;
    function GetPosition: Integer;
    function GetVerb: string;
    procedure SetCaption( const Value: string );
    procedure SetChecked( Value: Boolean );
    procedure SetEnabled( Value: Boolean );
    procedure SetHelpContext( Value: Integer );
    procedure SetName( const Value: string );
    procedure SetParent( const Value: string );
    procedure SetPosition( Value: Integer );
    procedure SetVerb( const Value: string );
    // IOTAProjectManagerMenu
    function GetIsMultiSelectable: Boolean;
    procedure SetIsMultiSelectable( Value: Boolean );
    procedure Execute( const MenuContextList: IInterfaceList ); overload;
    function PreExecute( const MenuContextList: IInterfaceList ): Boolean;
    function PostExecute( const MenuContextList: IInterfaceList ): Boolean;
  end;

  /// <summary>Puts <see cref="TBuildAllMenu"/> into the Project Manager's context menu of a project group.</summary>
  TBuildAllMenuCreator = class( TNotifierObject, IOTANotifier, IOTAProjectMenuItemCreatorNotifier )
  public
    /// <summary>Replaces the IDE's Build All item of a project group with ours.</summary>
    /// <param name="Project">The project of the selected node; unused.</param>
    /// <param name="IdentList">What the selected node is.</param>
    /// <param name="ProjectManagerMenuList">The menu items so far; changed.</param>
    /// <param name="IsMultiSelect">Not used: the IDE passes True for a single selected group node.</param>
    procedure AddMenu( const Project: IOTAProject; const IdentList: TStrings; const ProjectManagerMenuList: IInterfaceList;
      IsMultiSelect: Boolean );
  end;

constructor TBuildAllMenu.Create;
begin

  inherited Create;

  FCaption  := '&Build All';
  FEnabled  := True;
  FName     := 'DDevExtParallelBuildAll';
  FVerb     := 'DDevExtParallelBuildAll';
  FPosition := pmmpBuildAll;

end;

procedure TBuildAllMenu.AfterSave;
begin
end;

procedure TBuildAllMenu.BeforeSave;
begin
end;

procedure TBuildAllMenu.Destroyed;
begin
end;

procedure TBuildAllMenu.Modified;
begin
end;

function TBuildAllMenu.GetCaption: string;
begin
  Result := FCaption;
end;

function TBuildAllMenu.GetChecked: Boolean;
begin
  Result := FChecked;
end;

function TBuildAllMenu.GetEnabled: Boolean;
begin
  Result := FEnabled;
end;

function TBuildAllMenu.GetHelpContext: Integer;
begin
  Result := FHelpContext;
end;

function TBuildAllMenu.GetName: string;
begin
  Result := FName;
end;

function TBuildAllMenu.GetParent: string;
begin
  Result := FParent;
end;

function TBuildAllMenu.GetPosition: Integer;
begin
  Result := FPosition;
end;

function TBuildAllMenu.GetVerb: string;
begin
  Result := FVerb;
end;

procedure TBuildAllMenu.SetCaption( const Value: string );
begin
  FCaption := Value;
end;

procedure TBuildAllMenu.SetChecked( Value: Boolean );
begin
  FChecked := Value;
end;

procedure TBuildAllMenu.SetEnabled( Value: Boolean );
begin
  FEnabled := Value;
end;

procedure TBuildAllMenu.SetHelpContext( Value: Integer );
begin
  FHelpContext := Value;
end;

procedure TBuildAllMenu.SetName( const Value: string );
begin
  FName := Value;
end;

procedure TBuildAllMenu.SetParent( const Value: string );
begin
  FParent := Value;
end;

procedure TBuildAllMenu.SetPosition( Value: Integer );
begin
  FPosition := Value;
end;

procedure TBuildAllMenu.SetVerb( const Value: string );
begin
  FVerb := Value;
end;

function TBuildAllMenu.GetIsMultiSelectable: Boolean;
begin
  // False is what the live run of 2026-11-10 proved: the IDE shows and runs the item on a group node all the same.
  Result := False;
end;

procedure TBuildAllMenu.SetIsMultiSelectable( Value: Boolean );
begin
end;

function TBuildAllMenu.PreExecute( const MenuContextList: IInterfaceList ): Boolean;
begin
  Result := True;
end;

function TBuildAllMenu.PostExecute( const MenuContextList: IInterfaceList ): Boolean;
begin
  Result := True;
end;

procedure TBuildAllMenu.Execute( const MenuContextList: IInterfaceList );
begin

  // The plug-in may have been unloaded while the menu was open.
  if ParallelBuildConfig = nil then Exit;

  if ParallelBuildConfig.HandleBuildAll then Exit;

  // The IDE's own Build All, through the main menu's handler and with its action as the sender.
  if not Assigned( ParallelBuildConfig.FOrgBuildAllExecute ) then Exit;

  ParallelBuildConfig.FOrgBuildAllExecute( ParallelBuildConfig.FBuildAllAction );

end;

procedure TBuildAllMenuCreator.AddMenu( const Project: IOTAProject; const IdentList: TStrings;
  const ProjectManagerMenuList: IInterfaceList; IsMultiSelect: Boolean );
var
  intfMenu          : IOTAProjectManagerMenu;
begin

  // IsMultiSelect is not tested: the IDE passes True for a single selected group node ( logged 2026-11-10 ).
  if IdentList.IndexOf( sProjectGroupContainer ) < 0 then Exit;

  // Without the main menu's handler there is nothing to fall back to, so the IDE's item is left alone.
  if ( ParallelBuildConfig = nil ) or ( not Assigned( ParallelBuildConfig.FOrgBuildAllExecute ) ) then Exit;

  // The IDE's own Build All item is known by its position, which no translation changes.
  for var iI := 0 to ProjectManagerMenuList.Count - 1 do
    if Supports( ProjectManagerMenuList[ iI ], IOTAProjectManagerMenu, intfMenu ) and ( intfMenu.Position = pmmpBuildAll ) then
    begin
      // Replaced by an item wholly ours, keeping the IDE's caption, place and enabled state.
      var intfOurs: IOTAProjectManagerMenu := TBuildAllMenu.Create;
      intfOurs.Caption  := intfMenu.Caption;
      intfOurs.Position := intfMenu.Position;
      intfOurs.Parent   := intfMenu.Parent;
      intfOurs.Enabled  := intfMenu.Enabled;
      ProjectManagerMenuList[ iI ] := intfOurs;
      Exit;
    end;

end;

{ TParallelBuildConfig }

constructor TParallelBuildConfig.Create;
begin

  inherited Create( AppDataDirectory + '\ParallelBuild.xml', 'ParallelBuild' );

  HookBuildAll;

  // The Project Manager's right-click Build All does not go through the main menu's action.
  var intfProjectManager: IOTAProjectManager;

  FMenuCreatorIndex := -1;

  if Supports( BorlandIDEServices, IOTAProjectManager, intfProjectManager ) then
    FMenuCreatorIndex := intfProjectManager.AddMenuItemCreatorNotifier( TBuildAllMenuCreator.Create );

end;

destructor TParallelBuildConfig.Destroy;
begin

  var intfProjectManager: IOTAProjectManager;

  if ( FMenuCreatorIndex >= 0 ) and Supports( BorlandIDEServices, IOTAProjectManager, intfProjectManager ) then
    intfProjectManager.RemoveMenuItemCreatorNotifier( FMenuCreatorIndex );

  FMenuCreatorIndex := -1;

  UnhookBuildAll;

  inherited Destroy;

end;

procedure TParallelBuildConfig.Init;
begin

  inherited Init;

  FActive       := True;
  FMaxWorkers   := 0;
  FRunEurekaLog := True;
  FEcc32Path    := '';

end;

function TParallelBuildConfig.GetOptionPages: TTreePage;
begin

  Result := TTreePage.Create( 'Parallel Build All', TFrameOptionPageParallelBuild, Self );

end;

function TParallelBuildConfig.EffectiveEcc32Path: string;
begin

  if Trim( FEcc32Path ) <> '' then Exit( Trim( FEcc32Path ) );

  var sProgramFiles := GetEnvironmentVariable( 'ProgramFiles(x86)' );

  if sProgramFiles = '' then sProgramFiles := GetEnvironmentVariable( 'ProgramFiles' );

  Result := DefaultEcc32Path( sProgramFiles, EUREKALOG_STUDIO_FOLDER );

end;

procedure TParallelBuildConfig.HookBuildAll;
begin

  var oItem := FindMenuItem( BUILD_ALL_MENU_ITEM );

  // No such item, or no handler to call back into: leave the IDE alone.
  if ( oItem = nil ) or ( oItem.Action = nil ) or ( not Assigned( oItem.Action.OnExecute ) ) then Exit;

  FOrgBuildAllExecute     := oItem.Action.OnExecute;
  FBuildAllAction         := oItem.Action;
  oItem.Action.OnExecute  := BuildAllExecute;
  FHooked                 := True;

end;

procedure TParallelBuildConfig.UnhookBuildAll;
begin

  if not FHooked then Exit;

  FHooked := False;
  var oItem := FindMenuItem( BUILD_ALL_MENU_ITEM );

  if ( oItem = nil ) or ( oItem.Action = nil ) then Exit;

  // Only if ours is still the handler installed: something that hooked after us keeps its chain.
  var evCurrent: TNotifyEvent := oItem.Action.OnExecute;
  var evOurs: TNotifyEvent    := BuildAllExecute;

  if ( TMethod( evCurrent ).Code = TMethod( evOurs ).Code ) and ( TMethod( evCurrent ).Data = TMethod( evOurs ).Data ) then
    oItem.Action.OnExecute := FOrgBuildAllExecute;

end;

procedure TParallelBuildConfig.BuildAllExecute( Sender: TObject );
begin

  if ( not HandleBuildAll ) and Assigned( FOrgBuildAllExecute ) then FOrgBuildAllExecute( Sender );

end;

function TParallelBuildConfig.HandleBuildAll: Boolean;
begin

  // A second Build All while ours is running goes nowhere: the IDE's own build must not run beside it.
  if FBusy then Exit( True );

  var bHandled := False;

  if FActive then
  begin
    FBusy := True;
    try
      try
        bHandled := TryParallelBuild;
      except
        on E: Exception do
        begin
          // Whatever went wrong setting up, the user still gets a build: the IDE's own.
          bHandled := False;
          MessageDlg( 'Parallel Build All could not start, so the IDE''s own Build All will run:'#13#10#13#10 + E.Message,
            mtWarning, [ mbOK ], 0 );
        end;
      end;
    finally
      FBusy := False;
    end;
  end;

  Result := bHandled;

end;

function TParallelBuildConfig.TryParallelBuild: Boolean;
var
  intfModules       : IOTAModuleServices;
  intfServices      : IOTAServices;
  intfDebugger      : IOTADebuggerServices;
  raInputs         : TArray<TPlanInput>;
  saVariables       : TArray<string>;
  sError            : string;
  rSettings         : TMSBuildSettings;
begin

  Result := False;

  var intfGroup := GetActiveProjectGroup;

  if ( intfGroup = nil ) or ( intfGroup.ProjectCount < 2 ) then Exit;

  if not Supports( BorlandIDEServices, IOTAModuleServices, intfModules ) then Exit;

  if not Supports( BorlandIDEServices, IOTAServices, intfServices ) then Exit;

  // Only Delphi projects that exist on disk as a .dproj; anything else is the IDE's to build.
  for var iI := 0 to intfGroup.ProjectCount - 1 do
  begin
    var intfProject := intfGroup.Projects[ iI ];
    if ( intfProject.Personality <> sDelphiPersonality ) or ( not SameText( ExtractFileExt( intfProject.FileName ), '.dproj' ) ) then
      Exit;
    // Never saved, so there is nothing on disk for MSBuild to build.
    if not FileExists( intfProject.FileName ) then Exit;
    // A package the IDE has loaded cannot be overwritten from outside it.
    if ( ProjectKindFromDproj( TFile.ReadAllText( intfProject.FileName ) ) = pkPackage ) and
      IsPackageLoadedInIDE( ChangeFileExt( ExtractFileName( intfProject.FileName ), '' ) ) then
      Exit;
  end;

  // A program being debugged holds its exe open; the IDE's own build asks to end it first.
  if Supports( BorlandIDEServices, IOTADebuggerServices, intfDebugger ) and ( intfDebugger.ProcessCount > 0 ) then Exit;

  // Every reason to hand back to the IDE is above this line, so nothing is saved for a build we do not run.
  // MSBuild reads the disk, not the editor: everything is saved first.  Declining the save stops the build.
  if not intfModules.SaveAll then Exit( True );

  SetLength( raInputs, intfGroup.ProjectCount );

  for var iI := 0 to intfGroup.ProjectCount - 1 do
  begin
    var intfProject := intfGroup.Projects[ iI ];
    raInputs[ iI ].FileName  := intfProject.FileName;
    raInputs[ iI ].DprojText := TFile.ReadAllText( intfProject.FileName );
    raInputs[ iI ].Config    := intfProject.CurrentConfiguration;
    raInputs[ iI ].Platform  := intfProject.CurrentPlatform;
  end;

  var sGroupFile := intfGroup.FileName;
  var sGroupText := '';

  if FileExists( sGroupFile ) then sGroupText := TFile.ReadAllText( sGroupFile );

  var raPlan := BuildPlan( sGroupFile, sGroupText, raInputs );

  if not CaptureEnvironment( IncludeTrailingPathDelimiter( intfServices.GetRootDirectory ) + 'bin\rsvars.bat', saVariables,
    sError ) then
    raise EInvalidOpException.Create( sError );

  rSettings.MSBuildExe       := MSBuildExeFromEnvironment( saVariables );
  rSettings.EnvironmentBlock := EnvironmentBlock( saVariables );
  rSettings.RunEurekaLog     := FRunEurekaLog;
  rSettings.Ecc32Exe         := EffectiveEcc32Path;
  rSettings.AppDataDir       := GetEnvironmentVariable( 'APPDATA' );

  if not FileExists( rSettings.MSBuildExe ) then
    raise EInvalidOpException.Create( 'MSBuild.exe was not found at ' + rSettings.MSBuildExe );

  // From here the parallel build owns this Build All, whatever its outcome.
  Result := True;

  var oForm := TParallelBuildProgressForm.CreateFor( raPlan, EffectiveWorkerCount( FMaxWorkers, CPUCount ), rSettings );
  try
    oForm.ShowModal;
  finally
    oForm.Free;
  end;

  // The build may have rewritten project files ( the build number ): let the IDE pick the changes up.
  for var iI := 0 to intfGroup.ProjectCount - 1 do
    try
      intfGroup.Projects[ iI ].Refresh( False );
    except
      on E: Exception do
        OutputDebugString( PChar( 'DDevExtensions ParallelBuild: refresh failed: ' + E.Message ) );
    end;

end;

end.
