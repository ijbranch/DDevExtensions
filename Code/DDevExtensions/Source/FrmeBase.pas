{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FrmeBase;

/// <summary>
/// Base frame for every DDevExtensions option page hosted on the
/// <see cref="TFormDDevExtOptions"/> dialog. Provides the standard caption
/// bar plus a description panel and implements <c>ITreePageComponentEx</c>
/// so the tree-page host can manage layout.
/// </summary>
/// <remarks>
/// The constructor temporarily redirects <c>TReader.NewInstance</c> via
/// virtual-method patching so missing properties on legacy DFMs do not raise
/// during loading.
/// </remarks>

{$I DelphiExtension.inc}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls, FrmTreePages;


type
  /// <summary>
  /// Visual base class for option-page frames. Holds a client panel, a
  /// description panel with caption/description labels and a splitter bevel.
  /// </summary>
  TFrameBase = class(TFrame, ITreePageComponentEx)
    /// <summary>Client panel that derived frames place their controls on.</summary>
    pnlClient: TPanel;
    /// <summary>Top panel containing the caption and description labels.</summary>
    pnlDescription: TPanel;
    /// <summary>Visual splitter between description and client area.</summary>
    bvlSplitter: TBevel;
    /// <summary>Description label below the page caption.</summary>
    lblDescription: TLabel;
    /// <summary>Page caption label.</summary>
    lblCaption: TLabel;
  private
    { Private-Deklarationen }
  protected
    /// <summary>Sets the page caption shown at the top of the frame.</summary>
    procedure SetTitle(const ACaption: string);
  public
    { Public-Deklarationen }
    /// <summary>
    /// Constructs the frame, suppressing reader errors for unknown DFM
    /// properties via temporary virtual-method patching of <c>TReader</c>.
    /// </summary>
    constructor Create(AOwner: TComponent); override;
  end;

implementation

{$R *.dfm}

type
  PPointer = ^Pointer;
  {$IF not declared(SIZE_T)}
  SIZE_T = DWORD;
  {$IFEND}

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

{ TFrameBase }

constructor TFrameBase.Create(AOwner: TComponent);
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

  Align := alClient;
  {$IFDEF COMPILER7_UP}
  pnlDescription.Color := clBtnFace;
  pnlDescription.ParentBackground := True;
  {$ENDIF COMPILER7_UP}
end;

procedure TFrameBase.SetTitle(const ACaption: string);
begin
  lblCaption.Caption := ACaption;
end;

end.
