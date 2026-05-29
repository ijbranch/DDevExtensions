{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2009 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit FrmDDevExtOptions;

/// <summary>
/// DDevExtensions options dialog: the tabbed configuration window invoked
/// from the IDE's <c>Tools | DDevExtensions | Options...</c> menu. Each
/// plug-in registers its own page on the embedded tree at startup.
/// </summary>

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, FrmOptions, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.StdCtrls;

type
  /// <summary>Concrete options form used by DDevExtensions; descends from the generic <c>TFormOptions</c> tree-page host.</summary>
  TFormDDevExtOptions = class(TFormOptions)
    /// <summary>Sets the version and copyright labels at form creation time.</summary>
    procedure FormCreate(Sender: TObject);
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
  end;

implementation

uses
  AppConsts;

{$R *.dfm}

procedure TFormDDevExtOptions.FormCreate(Sender: TObject);
begin
  inherited;
  lblVersion.Caption := 'Version ' + sPluginVersion;
  lblURL.Caption := sPluginSmallCopyright;
end;

end.
