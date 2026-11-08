unit TaskbarIntf;

/// <summary>
/// Delphi import declarations for the Windows 7+ Shell Taskbar API
/// (<c>ITaskbarList</c> through <c>ITaskbarList4</c>) plus the related
/// <c>THUMBBUTTON</c>/<c>TBPF_*</c>/<c>STPF_*</c> constants. Used by the
/// Compile Progress feature to display compile state on the IDE's taskbar
/// button.
/// </summary>
/// <remarks>
/// COM is initialised lazily on the first call to <see cref="CreateTaskbarList"/>
/// and uninitialised in the unit's finalisation section.
/// </remarks>

interface

uses
  Winapi.Windows, Winapi.CommCtrl, System.Win.ComObj, Winapi.ActiveX;

const
  /// <summary>COM class ID of the Shell Taskbar List object.</summary>
  {$EXTERNALSYM CLSID_TaskbarList}
  CLSID_TaskbarList: TGUID = '{56FDF344-FD6D-11d0-958A-006097C9A090}';

const
  /// <summary>Interface ID of <see cref="ITaskbarList"/>.</summary>
  {$EXTERNALSYM IID_ITaskbarList}
  IID_ITaskbarList: TGUID = '{56FDF342-FD6D-11d0-958A-006097C9A090}';

type
  /// <summary>
  /// Original Windows 95+ taskbar interface that lets an application add,
  /// remove, activate or alt-mark its taskbar tab.
  /// </summary>
  {$EXTERNALSYM ITaskbarList}
  ITaskbarList = interface(IUnknown)
  ['{56FDF342-FD6D-11d0-958A-006097C9A090}']
    /// <summary>Initialises the taskbar-list object; call once before any other method.</summary>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function HrInit: HResult; stdcall;
    /// <summary>Adds an item to the taskbar.</summary>
    /// <param name="hwnd">Handle of the window whose taskbar button is affected.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function AddTab(hwnd: HWND): HResult; stdcall;
    /// <summary>Removes an item from the taskbar.</summary>
    /// <param name="hwnd">Handle of the window whose taskbar button is affected.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function DeleteTab(hwnd: HWND): HResult; stdcall;
    /// <summary>Marks an item as the active tab.</summary>
    /// <param name="hwnd">Handle of the window whose taskbar button is affected.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function ActivateTab(hwnd: HWND): HResult; stdcall;
    /// <summary>Marks the alt-tab focus on the given item without activating it.</summary>
    /// <param name="hwnd">Handle of the window whose taskbar button is affected.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function SetActiveAlt(hwnd: HWND): HResult; stdcall;
  end;

const
  /// <summary>Interface ID of <see cref="ITaskbarList2"/>.</summary>
  {$EXTERNALSYM IID_ITaskbarList2}
  IID_ITaskbarList2: TGUID = '{602D4995-B13A-429b-A66E-1935E44F4317}';

type
  /// <summary>Adds full-screen-window marking on top of <see cref="ITaskbarList"/>.</summary>
  {$EXTERNALSYM ITaskbarList2}
  ITaskbarList2 = interface(ITaskbarList)
  ['{602D4995-B13A-429b-A66E-1935E44F4317}']
    /// <summary>Marks a window as occupying the full screen so the shell can hide its UI.</summary>
    /// <param name="hwnd">Handle of the window whose taskbar button is affected.</param>
    /// <param name="fFullscreen">True to mark the window full screen, False to remove the mark.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function MarkFullscreenWindow(hwnd: HWND;
      fFullscreen: BOOL): HResult; stdcall;
  end;

const
  /// <summary>The button is active and available to the user.</summary>
  {$EXTERNALSYM THBF_ENABLED}
  THBF_ENABLED        = 0;
  /// <summary>The button is disabled.  It is present, but has a visual state that indicates that it will not respond to user action.</summary>
  {$EXTERNALSYM THBF_DISABLED}
  THBF_DISABLED       = $1;
  /// <summary>When the button is clicked, the taskbar button's flyout closes immediately.</summary>
  {$EXTERNALSYM THBF_DISMISSONCLICK}
  THBF_DISMISSONCLICK = $2;
  /// <summary>Do not draw a button border, use only the image.</summary>
  {$EXTERNALSYM THBF_NOBACKGROUND}
  THBF_NOBACKGROUND   = $4;
  /// <summary>The button is not shown to the user.</summary>
  {$EXTERNALSYM THBF_HIDDEN}
  THBF_HIDDEN         = $8;
  /// <summary>The button is enabled but not interactive; no pressed button state is drawn.  This value is intended for instances where the button is used in a
  /// notification.</summary>
  {$EXTERNALSYM THBF_NONINTERACTIVE}
  THBF_NONINTERACTIVE = $10;

  /// <summary>The iBitmap member contains valid information.</summary>
  {$EXTERNALSYM THB_BITMAP}
  THB_BITMAP  = $1;
  /// <summary>The hIcon member contains valid information.</summary>
  {$EXTERNALSYM THB_ICON}
  THB_ICON    = $2;
  /// <summary>The szTip member contains valid information.</summary>
  {$EXTERNALSYM THB_TOOLTIP}
  THB_TOOLTIP = $4;
  /// <summary>The dwFlags member contains valid information.</summary>
  {$EXTERNALSYM THB_FLAGS}
  THB_FLAGS   = $8;

type
  /// <summary>Pointer to <see cref="TThumbButton"/>.</summary>
  PThumbButton = ^TThumbButton;
  /// <summary>Describes a single button on a thumbnail toolbar (Win7+).</summary>
  {$EXTERNALSYM THUMBBUTTON}
  THUMBBUTTON = record
    /// <summary>A combination of THUMBBUTTONMASK values that specify which members of this structure contain valid data; other members are ignored, with the
    /// exception of iId, which is always required.</summary>
    dwMask: DWORD;
    /// <summary>Application-defined button identifier, unique within the toolbar; always required.</summary>
    iID: UINT;
    /// <summary>Zero-based image index in the toolbar's image list; valid when <c>dwMask</c> has <c>THB_BITMAP</c>.</summary>
    iBitmap: UINT;
    /// <summary>Icon drawn on the button; valid when <c>dwMask</c> has <c>THB_ICON</c>.</summary>
    hIcon: HICON;
    /// <summary>Null-terminated tooltip text; valid when <c>dwMask</c> has <c>THB_TOOLTIP</c>.</summary>
    szTip: array [0..259] of WCHAR;
    /// <summary>Combination of <c>THBF_*</c> state flags; valid when <c>dwMask</c> has <c>THB_FLAGS</c>.</summary>
    dwFlags: DWORD;
  end;
  /// <summary>Pascal-style alias for <see cref="THUMBBUTTON"/>.</summary>
  TThumbButton = THUMBBUTTON;
  /// <summary>Win32-style pointer alias for <see cref="THUMBBUTTON"/>.</summary>
  {$EXTERNALSYM LPTHUMBBUTTON}
  LPTHUMBBUTTON = PThumbButton;

const
  /// <summary>When a button in a thumbnail toolbar is clicked, the window associated with that thumbnail is sent a WM_COMMAND message with the HIWORD of its
  /// wParam parameter set to THBN_CLICKED and the LOWORD to the button ID.</summary>
  {$EXTERNALSYM THBN_CLICKED}
  THBN_CLICKED = $1800;

  /// <summary>Stops displaying progress and returns the button to its normal state.  Call this method with this flag to dismiss the progress bar when the
  /// operation is complete or cancelled.</summary>
  {$EXTERNALSYM TBPF_NOPROGRESS}
  TBPF_NOPROGRESS = 0;
  /// <summary>The progress indicator does not grow in size, but cycles repeatedly along the length of the taskbar button.  This indicates activity without
  /// specifying what proportion of the progress is complete.  Progress is taking place, but there is no prediction as to how long the operation will
  /// take.</summary>
  {$EXTERNALSYM TBPF_INDETERMINATE}
  TBPF_INDETERMINATE  = $1;
  /// <summary>The progress indicator grows in size from left to right in proportion to the estimated amount of the operation completed.  This is a determinate
  /// progress indicator; a prediction is being made as to the duration of the operation.</summary>
  {$EXTERNALSYM TBPF_NORMAL}
  TBPF_NORMAL = $2;
  /// <summary>The progress indicator turns red to show that an error has occurred in one of the windows that is broadcasting progress.  This is a determinate
  /// state.  If the progress indicator is in the indeterminate state, it switches to a red determinate display of a generic percentage not indicative of actual
  /// progress.</summary>
  {$EXTERNALSYM TBPF_ERROR}
  TBPF_ERROR  = $4;
  /// <summary>The progress indicator turns yellow to show that progress is currently stopped in one of the windows but can be resumed by the user.  No error
  /// condition exists and nothing is preventing the progress from continuing.  This is a determinate state.  If the progress indicator is in the indeterminate
  /// state, it switches to a yellow determinate display of a generic percentage not indicative of actual progress.</summary>
  {$EXTERNALSYM TBPF_PAUSED}
  TBPF_PAUSED = $8;

const
  /// <summary>Interface ID of <see cref="ITaskbarList3"/>.</summary>
  {$EXTERNALSYM IID_ITaskbarList3}
  IID_ITaskbarList3: TGUID = '{ea1afb91-9e28-4b86-90e9-9e9f8a5eefaf}';

type
  /// <summary>
  /// Windows 7+ taskbar interface adding progress bars, overlay icons,
  /// thumbnail toolbars and tab grouping to <see cref="ITaskbarList2"/>.
  /// </summary>
  {$EXTERNALSYM ITaskbarList3}
  ITaskbarList3 = interface(ITaskBarList2)
  ['{ea1afb91-9e28-4b86-90e9-9e9f8a5eefaf}']
    /// <summary>Sets a determinate progress value (completed/total) on the window's taskbar button.</summary>
    /// <param name="hwnd">Handle of the window whose taskbar button is affected.</param>
    /// <param name="ullCompleted">Amount of the operation completed so far.</param>
    /// <param name="ullTotal">Amount that marks the operation complete.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function SetProgressValue(hwnd: HWND;
                              ullCompleted,
                              ullTotal: ULONGLONG): HRESULT ; stdcall;
    /// <summary>Sets the progress-bar state (one of the <c>TBPF_*</c> flags).</summary>
    /// <param name="hwnd">Handle of the window whose taskbar button is affected.</param>
    /// <param name="tbpFlags">One <c>TBPF_*</c> value.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function SetProgressState(hwnd: HWND; tbpFlags: DWORD): HRESULT; stdcall;
    /// <summary>Registers a child tab window with its MDI parent for taskbar tab grouping.</summary>
    /// <param name="hwndTab">Handle of the tab window.</param>
    /// <param name="hwndMDI">Handle of the MDI or tabbed main window that hosts the tab.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function RegisterTab(hwndTab, hwndMDI: HWND): HRESULT; stdcall;
    /// <summary>Removes a previously registered tab.</summary>
    /// <param name="hwndTab">Handle of the tab window.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function UnregisterTab(hwndTab: HWND): HRESULT; stdcall;
    /// <summary>Sets the relative order of taskbar thumbnail tabs.</summary>
    /// <param name="hwndTab">Handle of the tab window.</param>
    /// <param name="hwndInsertBefore">Tab to insert before, or 0 to move the tab to the end.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function SetTabOrder(hwndTab, hwndInsertBefore: HWND): HRESULT; stdcall;
    /// <summary>Marks a tab as the active tab within its MDI group.</summary>
    /// <param name="hwndTab">Handle of the tab window.</param>
    /// <param name="hwndMDI">Handle of the MDI or tabbed main window that hosts the tab.</param>
    /// <param name="dwReserved">Reserved; pass 0.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function SetTabActive(hwndTab, hwndMDI: HWND;
                          dwReserved: DWORD): HRESULT; stdcall;
    /// <summary>Adds buttons to the window's thumbnail toolbar (max 7).</summary>
    /// <param name="hwnd">Handle of the window whose taskbar button is affected.</param>
    /// <param name="cButtons">Number of entries in <paramref name="pButton"/>.</param>
    /// <param name="pButton">First element of an array of button definitions.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function ThumbBarAddButtons(hwnd: HWND; cButtons: UINT;
                                pButton: LPTHUMBBUTTON): HRESULT; stdcall;
    /// <summary>Updates state/image of previously added thumbnail-toolbar buttons.</summary>
    /// <param name="hwnd">Handle of the window whose taskbar button is affected.</param>
    /// <param name="cButtons">Number of entries in <paramref name="pButton"/>.</param>
    /// <param name="pButton">First element of an array of button definitions to apply, matched by <c>iID</c>.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function ThumbBarUpdateButtons(hwnd: HWND; cButtons: UINT;
                                   pButton: LPTHUMBBUTTON): HRESULT; stdcall;
    /// <summary>Sets the image list used by the thumbnail toolbar.</summary>
    /// <param name="hwnd">Handle of the window whose taskbar button is affected.</param>
    /// <param name="himl">Image list holding the button images.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function ThumbBarSetImageList(hwnd: HWND;
                                  himl: HIMAGELIST): HRESULT; stdcall;
    /// <summary>Overlays the taskbar icon with a small icon plus description.</summary>
    /// <param name="hwnd">Handle of the window whose taskbar button is affected.</param>
    /// <param name="hIcon">Overlay icon, or 0 to remove the overlay.</param>
    /// <param name="pszDescription">Accessibility text describing the overlay.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function SetOverlayIcon(hwnd: HWND; hIcon: HICON;
                            pszDescription: LPCWSTR): HRESULT; stdcall;
    /// <summary>Sets the tooltip text shown on the thumbnail.</summary>
    /// <param name="hwnd">Handle of the window whose taskbar button is affected.</param>
    /// <param name="pszTip">Tooltip text, or nil to restore the window title.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function SetThumbnailTooltip(hwnd: HWND;
                                 pszTip: LPCWSTR): HRESULT; stdcall;
    /// <summary>Restricts the thumbnail to a sub-rectangle of the window.</summary>
    /// <param name="hwnd">Handle of the window whose taskbar button is affected.</param>
    /// <param name="prcClip">Client-area rectangle to show, or nil to show the whole window.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function SetThumbnailClip(hwnd: HWND; prcClip: PRECT): HRESULT; stdcall;

  end;

const
  /// <summary>No specific property values are specified.  The default behavior is used: the tab window provides a thumbnail and peek image, either live or static
  /// as appropriate.</summary>
  {$EXTERNALSYM STPF_NONE}
  STPF_NONE                       = $0;
  /// <summary>Always use the thumbnail provided by the main application frame window rather than a thumbnail provided by the individual tab window.  Do not
  /// combine this value with STPF_USEAPPTHUMBNAILWHENACTIVE; doing so will result in an error.</summary>
  {$EXTERNALSYM STPF_USEAPPTHUMBNAILALWAYS}
  STPF_USEAPPTHUMBNAILALWAYS      = $1;
  /// <summary>When the application tab is active and a live representation of its window is available, use the main application frame window thumbnail.  At other
  /// times, use the tab window thumbnail.  Do not combine this value with STPF_USEAPPTHUMBNAILALWAYS; doing so will result in an error.</summary>
  {$EXTERNALSYM STPF_USEAPPTHUMBNAILWHENACTIVE}
  STPF_USEAPPTHUMBNAILWHENACTIVE  = $2;
  /// <summary>Always use the peek image provided by the main application frame window rather than a peek image provided by the individual tab window.  Do not
  /// combine this value with STPF_USEAPPPEEKWHENACTIVE; doing so will result in an error.</summary>
  {$EXTERNALSYM STPF_USEAPPPEEKALWAYS}
  STPF_USEAPPPEEKALWAYS           = $4;

  /// <summary>When the application tab is active and a live representation of its window is available, show the main application frame in the peek feature.  At
  /// other times, use the tab window.  Do not combine this value with STPF_USEAPPPEEKALWAYS; doing so will result in an error.</summary>
  {$EXTERNALSYM STPF_USEAPPPEEKWHENACTIVE}
  STPF_USEAPPPEEKWHENACTIVE       = $8;

  /// <summary>Interface ID of <see cref="ITaskbarList4"/>.</summary>
  {$EXTERNALSYM IID_ITaskbarList4}
  IID_ITaskbarList4: TGUID = '{c43dc798-95d1-4bea-9030-bb99e2983a1a}';

type
  /// <summary>Adds <see cref="ITaskbarList4.SetTabProperties"/> on top of <see cref="ITaskbarList3"/>.</summary>
  {$EXTERNALSYM ITaskbarList4}
  ITaskbarList4 = interface(ITaskbarList3)
  ['{c43dc798-95d1-4bea-9030-bb99e2983a1a}']
    /// <summary>Sets per-tab thumbnail/peek behaviour using the <c>STPF_*</c> flags.</summary>
    /// <param name="hwndTab">Handle of the tab window.</param>
    /// <param name="stpFlags">Combination of <c>STPF_*</c> flags.</param>
    /// <returns><c>S_OK</c> on success, otherwise a COM error code.</returns>
    function SetTabProperties(hwndTab: HWND; stpFlags: DWORD): HRESULT; stdcall;
  end;

/// <summary>
/// Creates and initialises an <see cref="ITaskbarList"/> COM object,
/// initialising COM apartment-threaded on first use.
/// </summary>
/// <returns>An initialised taskbar-list interface, or nil if creation failed.</returns>
function CreateTaskbarList: ITaskbarList;

implementation

uses
  System.SysUtils;

var
  CoInitialized: Boolean = False;

function CreateTaskbarList: ITaskbarList;
begin
  if not CoInitialized then
  begin
    case CoInitializeEx(nil, COINIT_APARTMENTTHREADED) of
      S_OK, S_FALSE:
        CoInitialized := True;
    end;
  end;

  // Ask the object for the interface ( QueryInterface ) instead of hard-casting the IUnknown it returns
  if not Supports( CreateComObject( CLSID_TaskbarList ), ITaskbarList, Result ) then
    Result := nil;
  if Result <> nil then
    Result.HrInit;
end;


initialization

finalization
  if CoInitialized then
    CoUninitialize;

end.
