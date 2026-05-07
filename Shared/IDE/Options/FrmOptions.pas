{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2009 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}
{$A+,B-,C+,D+,E-,F-,G+,H+,I+,J-,K-,L+,M-,N-,O+,P+,Q-,R-,S-,T-,U-,V+,W-,X+,Y+,Z1}

unit FrmOptions;

/// <summary>
/// Top-level "Options" dialog used by the plugin. Subclasses or callers register page
/// providers (TOptionPagesEvent/TOptionPagesProc) which are queried whenever the dialog opens
/// to build the tree on the left. Includes a clickable URL label that opens in the default
/// browser.
/// </summary>

interface

uses
  Windows, Messages, SysUtils, Classes, Contnrs, Graphics, Controls, Forms,
  Dialogs, FrmTreePages, StdCtrls, ExtCtrls, ComCtrls, ShellAPI;

type
  /// <summary>Method-typed callback that returns a TTreePage to display in the options dialog.</summary>
  TOptionPagesEvent = function: TTreePage of object;
  /// <summary>Function-typed callback that returns a TTreePage to display in the options dialog.</summary>
  TOptionPagesProc = function: TTreePage;

  /// <summary>Concrete options dialog. Maintains a class-level registry of page providers.</summary>
  TFormOptions = class(TFormTreePages)
    /// <summary>Clickable URL label; the URL is taken from the label's Hint.</summary>
    lblURL: TLabel;
    /// <summary>Static "Version:" caption.</summary>
    Label1: TLabel;
    /// <summary>Plug-in version string displayed alongside Label1.</summary>
    lblVersion: TLabel;
    /// <summary>Opens the URL stored in the label's Hint via ShellExecute.</summary>
    procedure lblURLClick(Sender: TObject);
  private
    { Private-Deklarationen }
  protected
    /// <summary>Returns the global registry of page providers; overridable for subclassed dialogs.</summary>
    class function GetGlobalOptionPages: TObjectList; virtual;
    /// <summary>Replaces the global registry of page providers.</summary>
    class procedure SetGlobalOptionPages(Value: TObjectList); virtual;
    /// <summary>Invokes every registered page provider and adds the returned pages to Root.</summary>
    procedure PopulateRootPage(Root: TTreePage); override;
  public
    { Public-Deklarationen }
    /// <summary>Registers a method-typed page provider so it is invoked the next time the dialog is opened.</summary>
    class procedure RegisterPages(const OptionPages: TOptionPagesEvent);
    /// <summary>Removes a previously registered method-typed page provider.</summary>
    class procedure UnregisterPages(const OptionPages: TOptionPagesEvent);
    /// <summary>Registers a function-typed page provider.</summary>
    class procedure RegisterPagesEx(const OptionPages: TOptionPagesProc);
    /// <summary>Removes a previously registered function-typed page provider.</summary>
    class procedure UnregisterPagesEx(const OptionPages: TOptionPagesProc);
  end;

implementation

{$R *.dfm}

var
  GlobalOptionPages: TObjectList;

type
  TOptionPages = class(TObject)
    Event: TOptionPagesEvent;
    Proc: TOptionPagesProc;
  end;

{ TFormOptions }

class procedure TFormOptions.SetGlobalOptionPages(Value: TObjectList);
begin
  GlobalOptionPages := Value;
end;

class function TFormOptions.GetGlobalOptionPages: TObjectList;
begin
  Result := GlobalOptionPages;
end;

class procedure TFormOptions.RegisterPages(const OptionPages: TOptionPagesEvent);
var
  Item: TOptionPages;
begin
  if GetGlobalOptionPages = nil then
    SetGlobalOptionPages(TObjectList.Create);

  Item := TOptionPages.Create;
  Item.Event := OptionPages;
  GetGlobalOptionPages.Add(Item);
end;

class procedure TFormOptions.UnregisterPages(const OptionPages: TOptionPagesEvent);
var
  i: Integer;
begin
  if GetGlobalOptionPages <> nil then
  begin
    for i := GetGlobalOptionPages.Count - 1 downto 0 do
    begin
      if CompareMem(Addr(TMethod(TOptionPages(GetGlobalOptionPages[i]).Event)), Addr(TMethod(OptionPages)), SizeOf(TMethod)) then
      begin
        GetGlobalOptionPages.Delete(i);
        Break;
      end;
    end;
  end;
end;

class procedure TFormOptions.RegisterPagesEx(const OptionPages: TOptionPagesProc);
var
  Item: TOptionPages;
begin
  if GetGlobalOptionPages = nil then
    SetGlobalOptionPages(TObjectList.Create);

  Item := TOptionPages.Create;
  Item.Proc := OptionPages;
  GetGlobalOptionPages.Add(Item);
end;

class procedure TFormOptions.UnregisterPagesEx(const OptionPages: TOptionPagesProc);
var
  i: Integer;
begin
  if GetGlobalOptionPages <> nil then
  begin
    for i := GetGlobalOptionPages.Count - 1 downto 0 do
    begin
      if Addr(TOptionPages(GetGlobalOptionPages[i]).Proc) <> Addr(OptionPages) then
      begin
        GetGlobalOptionPages.Delete(i);
        Break;
      end;
    end;
  end;
end;

procedure TFormOptions.PopulateRootPage(Root: TTreePage);
var
  i: Integer;
  OptionPages: TOptionPages;
  Page: TTreePage;
begin
  if GetGlobalOptionPages <> nil then
  begin
    for i := 0 to GetGlobalOptionPages.Count - 1 do
    begin
      OptionPages := TOptionPages(GetGlobalOptionPages[i]);
      if Assigned(OptionPages.Event) then
        Page := OptionPages.Event()
      else
        Page := OptionPages.Proc();

      if Page <> nil then
        Root.Add(Page);
    end;
  end;
end;

procedure TFormOptions.lblURLClick(Sender: TObject);
begin
  with TLabel(Sender) do
  begin
    if ShellExecute(Handle, 'open', PChar(Hint), nil, nil, SW_SHOWMAXIMIZED) < 32 then
    begin
      Font.Color := clWindowText;
      Font.Style := [];
      OnClick := nil;
    end;
  end;
end;

initialization

finalization
  FreeAndNil(GlobalOptionPages);

end.
