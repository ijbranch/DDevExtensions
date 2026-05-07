{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}
{$A+,B-,C+,D+,E-,F-,G+,H+,I+,J-,K-,L+,M-,N-,O+,P+,Q-,R-,S-,T-,U-,V+,W-,X+,Y+,Z1}

unit FrmBase;

/// <summary>
/// Common ancestor for every dialog the plugin presents. Suppresses TReader resource errors so
/// stale .dfm streams still load, normalises every control's font to the IDE default and swaps
/// in THtHintWindow for the duration of ShowModal so hints can use inline mark-up.
/// </summary>

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs;

type
  /// <summary>Base form class for plugin dialogs; see the unit summary for behavioural details.</summary>
  TFormBase = class(TForm)
  private
    { Private-Deklarationen }
  protected
    /// <summary>Persists dialog state when the form closes (placeholder).</summary>
    procedure DoClose(var Action: TCloseAction); override;
    /// <summary>Restores state and rewrites every "Tahoma" font to the IDE default font.</summary>
    procedure DoShow; override;
  public
    { Public-Deklarationen }
    /// <summary>Patches TReader.NewInstance for the duration of construction so resource-load errors are swallowed.</summary>
    constructor Create(AOwner: TComponent); override;
    /// <summary>Installs THtHintWindow and a long hint timeout for the duration of the modal display.</summary>
    function ShowModal: Integer; override;
  end;

var
  /// <summary>Auto-created singleton declared by the .dfm; not used directly.</summary>
  FormBase: TFormBase;

implementation

uses
  HtHint;

{$R *.dfm}

type
  PPointer = ^Pointer;
  {$IF not declared(SIZE_T)}
  SIZE_T = DWORD;
  {$IFEND}

  TControlAccess = class(TControl);

function GetVirtualMethod(AClass: TClass; const Index: Integer): Pointer;
begin
  Result := PPointer(PAnsiChar(AClass) + Index * SizeOf(Pointer))^;
end;

procedure SetVirtualMethod(AClass: TClass; const Index: Integer; const Method: Pointer);
var
  WrittenBytes: SIZE_T;
  PatchAddress: PPointer;
begin
  PatchAddress := Pointer(PAnsiChar(AClass) + Index * SizeOf(Pointer));
  WriteProcessMemory(GetCurrentProcess, PatchAddress, @Method, SizeOf(Method), WrittenBytes);
end;

procedure ReaderError(Self: TObject; Reader: TReader; const Message: string; var Handled: Boolean);
begin
  Handled := True;
end;

function IgnoreReader_NewInstance(AClass: TClass): TObject;
var
  M: TMethod;
begin
  M.Code := @ReaderError;
  M.Data := nil;
  Result := TReader.NewInstance;
  TReader(Result).OnError := TReaderError(M);
end;

{ TFormBase }

constructor TFormBase.Create(AOwner: TComponent);
const
  {$WARNINGS OFF}
  Index = vmtNewInstance div SizeOf(Pointer);
  {$WARNINGS ON}
var
  NewInst: procedure;
begin
  NewInst := GetVirtualMethod(TReader, Index);
  try
    SetVirtualMethod(TReader, Index, @IgnoreReader_NewInstance);
    inherited Create(AOwner);
  finally
    SetVirtualMethod(TReader, Index, @NewInst);
  end;
  Font.Name := UTF8ToString(DefFontData.Name);
  Font.Height := DefFontData.Height;
end;

procedure TFormBase.DoClose(var Action: TCloseAction);
begin
  inherited DoClose(Action);
  if Action <> caNone then
  begin
    // Save state
  end;
end;

procedure TFormBase.DoShow;

  // Set the dialogs base font name to every control that uses "Tahoma" (all MS Sans Serif were eliminated)
  procedure SetControlFonts(ParentControl: TWinControl);
  var
    I: Integer;
    Control: TControl;
  begin
    for I := 0 to ParentControl.ControlCount - 1 do
    begin
      Control := ParentControl.Controls[I];
      if TControlAccess(Control).Font.Name = 'Tahoma' then
        TControlAccess(Control).Font.Name := Self.Font.Name;
      if Control is TWinControl then
        SetControlFonts(TWinControl(Control));
    end;
  end;

begin
  // restore state
  inherited DoShow;

  if Self.Font.Name <> 'Tahoma' then
    SetControlFonts(Self);
end;

function TFormBase.ShowModal: Integer;
var
  HintClass: THintWindowClass;
  HintHidePause: Integer;
begin
  HintHidePause := Application.HintHidePause;
  HintClass := HintWindowClass;
  try
    HintWindowClass := THtHintWindow;
    Application.HintHidePause := 30000;
    Result := inherited ShowModal;
  finally
    Application.HintHidePause := HintHidePause;
    HintWindowClass := HintClass;
  end;
end;

end.
 
