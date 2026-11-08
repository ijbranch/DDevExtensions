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
/// Common ancestor for every dialog the plugin presents. Suppresses resource errors while its own
/// .dfm stream is read, so stale streams still load, normalises every control's font to the IDE default and swaps
/// in THtHintWindow for the duration of ShowModal so hints can use inline mark-up.
/// </summary>

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs;

type
  /// <summary>Base form class for plugin dialogs; see the unit summary for behavioural details.</summary>
  TFormBase = class( TForm )
  private
    /// <summary>
    /// TReader.OnError handler for this form's own resource: marks every error handled, so a
    /// property the stream names but the class no longer has is skipped instead of aborting.
    /// </summary>
    /// <param name="Reader">The reader reporting the error.</param>
    /// <param name="Message">Error text.</param>
    /// <param name="Handled">Set to True to continue reading.</param>
    procedure ReaderError( Reader: TReader; const Message: string; var Handled: Boolean );
  protected
    /// <summary>
    /// Installs ReaderError on the reader that streams this form, then reads it.  Replaces the
    /// former patch of the IDE-wide TReader.NewInstance VMT slot, which also silenced errors in
    /// every other TReader the IDE created while the dialog was being constructed.
    /// </summary>
    /// <remarks>
    /// Covers this form's own stream only.  A frame reads its own class resource with a separate
    /// reader: option-page frames derive from TFrameBase, which installs the same handler; no form
    /// of ours embeds an inline frame of another class ( checked 2026-11-09 ), but one that did
    /// would not have its stream errors suppressed.
    /// </remarks>
    /// <param name="Reader">Reader streaming this form's resource.</param>
    procedure ReadState( Reader: TReader ); override;
    /// <summary>Persists dialog state when the form closes (placeholder).</summary>
    /// <param name="Action">Close action chosen so far; passed on to the inherited handler, which may change it.</param>
    procedure DoClose( var Action: TCloseAction ); override;
    /// <summary>Restores state and rewrites every "Tahoma" font to the IDE default font.</summary>
    procedure DoShow; override;
  public
    /// <summary>Creates the form and applies the IDE's default font.</summary>
    /// <param name="AOwner">Owner component.</param>
    constructor Create( AOwner: TComponent ); override;
    /// <summary>Installs THtHintWindow and a long hint timeout for the duration of the modal display.</summary>
    /// <returns>The modal result, as returned by TForm.ShowModal.</returns>
    function ShowModal: Integer; override;
  end;

var
  /// <summary>Auto-created singleton declared by the .dfm; not used directly.</summary>
  FormBase          : TFormBase;

implementation

uses
  HtHint;

{$R *.dfm}

type
  TControlAccess = class( TControl );

  { TFormBase }

procedure TFormBase.ReaderError( Reader: TReader; const Message: string; var Handled: Boolean );
begin
  Handled           := True;
end;

procedure TFormBase.ReadState( Reader: TReader );
begin
  Reader.OnError    := ReaderError;
  inherited ReadState( Reader );
end;

constructor TFormBase.Create( AOwner: TComponent );
begin
  inherited Create( AOwner );
  Font.Name         := UTF8ToString( DefFontData.Name );
  Font.Height       := DefFontData.Height;
end;

procedure TFormBase.DoClose( var Action: TCloseAction );
begin
  inherited DoClose( Action );
  if Action <> caNone then
  begin
    // Save state
  end;
end;

procedure TFormBase.DoShow;

// Set the dialogs base font name to every control that uses "Tahoma" (all MS Sans Serif were eliminated)
  procedure SetControlFonts( ParentControl: TWinControl );
  var
    I               : Integer;
    Control         : TControl;
  begin
    for I := 0 to ParentControl.ControlCount - 1 do
    begin
      Control       := ParentControl.Controls[ I ];
      if TControlAccess( Control ).Font.Name = 'Tahoma' then
        TControlAccess( Control ).Font.Name := Self.Font.Name;
      if Control is TWinControl then
        SetControlFonts( TWinControl( Control ) );
    end;
  end;

begin
  // restore state
  inherited DoShow;

  if Self.Font.Name <> 'Tahoma' then
    SetControlFonts( Self );
end;

function TFormBase.ShowModal: Integer;
var
  HintClass         : THintWindowClass;
  HintHidePause     : Integer;
begin
  HintHidePause     := Application.HintHidePause;
  HintClass         := HintWindowClass;
  try
    HintWindowClass := THtHintWindow;
    Application.HintHidePause := 30000;
    Result          := inherited ShowModal;
  finally
    Application.HintHidePause := HintHidePause;
    HintWindowClass := HintClass;
  end;
end;

end.

