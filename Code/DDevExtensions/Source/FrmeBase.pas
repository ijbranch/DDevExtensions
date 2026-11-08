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
/// <see cref="TFrameBase.ReadState"/> lets an option page's DFM load past a property this IDE version does not
/// know, logging what it skipped.
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
    /// <summary>Reader error handler: skips the offending DFM entry and logs it, instead of failing the page.</summary>
    /// <param name="Reader">The reader streaming this frame.</param>
    /// <param name="Message">The reader's error message.</param>
    /// <param name="Handled">Set to True to carry on reading.</param>
    procedure ReaderError(Reader: TReader; const Message: string; var Handled: Boolean);
  protected
    /// <summary>Sets the page caption shown at the top of the frame.</summary>
    /// <param name="ACaption">Text to show in the frame's caption label.</param>
    procedure SetTitle(const ACaption: string);
    /// <summary>
    /// Streams the frame's DFM with <see cref="ReaderError"/> attached to this reader only.  The handler used to
    /// be installed by patching the VMT of the RTL's shared <c>TReader</c> class for the whole IDE while the frame
    /// loaded, which also silenced DFM errors of any other form streamed in that window.
    /// </summary>
    /// <param name="Reader">The reader streaming this frame (one per inheritance level).</param>
    procedure ReadState(Reader: TReader); override;
  public
    { Public-Deklarationen }
    /// <summary>
    /// Constructs the frame (DFM reader errors are handled by <see cref="ReadState"/>) and aligns it to its host.
    /// </summary>
    /// <param name="AOwner">Owner component.</param>
    constructor Create(AOwner: TComponent); override;
  end;

implementation

{$R *.dfm}

{ TFrameBase }

procedure TFrameBase.ReaderError(Reader: TReader; const Message: string; var Handled: Boolean);
begin
  OutputDebugString( PChar( 'DDevExtensions ' + ClassName + ': DFM entry skipped - ' + Message ) );
  Handled := True;
end;

procedure TFrameBase.ReadState(Reader: TReader);
begin
  Reader.OnError := ReaderError;
  inherited ReadState( Reader );
end;

constructor TFrameBase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

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
