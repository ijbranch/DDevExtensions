{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2011 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmTypePrefixEditor;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, CodeStyleChecker;

type
  TFormTypePrefixEditor = class( TForm )
    lblInstructions: TLabel;
    lblWarning: TLabel;
    memRules: TMemo;
    btnOK: TButton;
    btnCancel: TButton;
    btnResetDefaults: TButton;
    procedure btnResetDefaultsClick( Sender: TObject );
    procedure FormCreate( Sender: TObject );
    procedure memRulesChange( Sender: TObject );
  private
    FPlugin: TCodeStyleCheckerPlugin;
    procedure LoadRules;
    procedure SaveRules;
    procedure CheckForConflicts;
  public
    class function Execute( APlugin: TCodeStyleCheckerPlugin ): Boolean;
  end;

implementation

{$R *.dfm}

{ TFormTypePrefixEditor }

class function TFormTypePrefixEditor.Execute( APlugin: TCodeStyleCheckerPlugin ): Boolean;
var
  Form: TFormTypePrefixEditor;
begin

  Result := False;
  Form   := TFormTypePrefixEditor.Create( Application );

  try
    Form.FPlugin := APlugin;
    Form.LoadRules;

    if Form.ShowModal = mrOK then
    begin
      Form.SaveRules;
      Result := True;
    end;
  finally
    Form.Free;
  end;

end;

procedure TFormTypePrefixEditor.FormCreate( Sender: TObject );
begin

  // Nothing needed - just for designer

end;

procedure TFormTypePrefixEditor.LoadRules;
var
  I: Integer;
  Rules: TArray<TTypePrefixRule>;
begin

  memRules.Lines.Clear;
  Rules := FPlugin.TypePrefixRules;

  for I := 0 to High( Rules ) do
  begin
    if Rules[ I ].Enabled then
      memRules.Lines.Add( Rules[ I ].TypePattern + '=' + Rules[ I ].Prefix );
  end;

  CheckForConflicts;

end;

procedure TFormTypePrefixEditor.SaveRules;
var
  I, Count: Integer;
  Line, TypePattern, Prefix: string;
  EqPos: Integer;
  Rules: TArray<TTypePrefixRule>;
begin

  // Count valid lines
  Count := 0;

  for I := 0 to memRules.Lines.Count - 1 do
  begin
    Line := Trim( memRules.Lines[ I ] );

    if ( Line <> '' ) and ( Pos( '=', Line ) > 0 ) then
      Inc( Count );
  end;

  SetLength( Rules, Count );
  Count := 0;

  for I := 0 to memRules.Lines.Count - 1 do
  begin
    Line := Trim( memRules.Lines[ I ] );

    if Line = '' then
      Continue;

    EqPos := Pos( '=', Line );

    if EqPos > 0 then
    begin
      TypePattern := Trim( Copy( Line, 1, EqPos - 1 ) );
      Prefix      := Trim( Copy( Line, EqPos + 1, MaxInt ) );

      if ( TypePattern <> '' ) and ( Prefix <> '' ) then
      begin
        Rules[ Count ].TypePattern := TypePattern;
        Rules[ Count ].Prefix      := Prefix;
        Rules[ Count ].Enabled     := True;
        Inc( Count );
      end;
    end;
  end;

  SetLength( Rules, Count );
  FPlugin.TypePrefixRules := Rules;

end;

procedure TFormTypePrefixEditor.btnResetDefaultsClick( Sender: TObject );
begin

  FPlugin.InitDefaultTypePrefixRules;
  LoadRules;

end;

procedure TFormTypePrefixEditor.memRulesChange( Sender: TObject );
begin

  CheckForConflicts;

end;

procedure TFormTypePrefixEditor.CheckForConflicts;
var
  I, J, EqPos: Integer;
  Line, Pattern1, Pattern2: string;
  Patterns: TStringList;
  Conflicts: TStringList;
begin

  Patterns  := TStringList.Create;
  Conflicts := TStringList.Create;

  try
    // Extract all patterns from the memo
    for I := 0 to memRules.Lines.Count - 1 do
    begin
      Line := Trim( memRules.Lines[ I ] );

      if Line = '' then
        Continue;

      EqPos := Pos( '=', Line );

      if EqPos > 1 then
        Patterns.Add( Trim( Copy( Line, 1, EqPos - 1 ) ) );
    end;

    // Check for conflicts (pattern A is a prefix of pattern B)
    for I := 0 to Patterns.Count - 1 do
    begin
      Pattern1 := UpperCase( Patterns[ I ] );

      for J := 0 to Patterns.Count - 1 do
      begin
        if I = J then
          Continue;

        Pattern2 := UpperCase( Patterns[ J ] );

        // Check if Pattern1 is a prefix of Pattern2
        if ( Length( Pattern1 ) < Length( Pattern2 ) ) and
           ( Pos( Pattern1, Pattern2 ) = 1 ) then
        begin
          // Pattern1 would match Pattern2's types before Pattern2 gets a chance
          Conflicts.Add( Patterns[ I ] + ' -> ' + Patterns[ J ] );
        end;
      end;
    end;

    // Display warning if conflicts found
    if Conflicts.Count > 0 then
    begin
      lblWarning.Caption := 'Warning: Rule order matters. "' + Conflicts[ 0 ] +
                            '" - first pattern may match types intended for second.';
    end
    else
      lblWarning.Caption := '';

  finally
    Patterns.Free;
    Conflicts.Free;
  end;

end;

end.
