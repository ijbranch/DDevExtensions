{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude Code                                           *}
{*                                                                            *}
{******************************************************************************}

unit DfmLinkGuardCore;

/// <summary>
/// The decision behind the DFM Link Guard: given a form's <c>.dfm</c> text before and after an IDE
/// save, which links to a component of another module ( <c>DataSource = dmMain.dsCustomers</c> ) the
/// save dropped.  The IDE drops such a link, silently, when it saves a form while the other module
/// is not loaded; the next save makes the loss permanent.  Pure RTL plus the DFM parser and
/// <c>gllDfmCompare</c>, so the DUnitX suite tests it directly; <c>DfmLinkGuard</c> is the IDE side.
/// </summary>
/// <remarks>
/// Measured before it was built ( <c>Tools\DfmNoiseMeasure\Findings-2026-11-28.md</c> ): in 3,179
/// DBiWorkflow DFM commits, 26 such links were removed, 7 because their target was deleted ( a
/// deliberate edit ) and 19 lost and later restored by hand, one form's 11 bindings after a year.
/// </remarks>

interface

uses
  System.SysUtils;

type
  /// <summary>One link to another module's component that a save removed.</summary>
  TDfmLostLink = record
    /// <summary>Dotted path of the component that held the link, the root's name first ( <c>Form1.Grid1</c> ).</summary>
    Path: string;
    /// <summary>The property that held it ( <c>DataSource</c> ).</summary>
    PropName: string;
    /// <summary>The removed value, trimmed ( <c>dmMain.dsCustomers</c> ).</summary>
    Value: string;
    /// <summary>The linked module's root component name ( <c>dmMain</c> ).</summary>
    ModuleName: string;
    /// <summary>The linked component's name in that module ( <c>dsCustomers</c> ).</summary>
    ComponentName: string;
  end;

  /// <summary>Decides whether a linked component still exists, so a deliberate deletion is not reported.</summary>
  /// <param name="ModuleName">The linked module's root component name.</param>
  /// <param name="ComponentName">The component's name in that module.</param>
  /// <returns>True when the component is known to exist; False when it is gone or cannot be found.</returns>
  TDfmLinkTargetExists = reference to function( const ModuleName, ComponentName: string ): Boolean;

/// <summary>
/// Finds the links to another module's components that a save removed.  A link counts only when its
/// component is in both texts ( a deleted component takes its links with it ), its value no longer
/// appears anywhere in the new text ( a link moved to another property or component is not lost ),
/// and <paramref name="TargetExists"/> confirms the linked component still exists.
/// </summary>
/// <param name="OldText">The <c>.dfm</c> text before the save.</param>
/// <param name="NewText">The <c>.dfm</c> text after the save.</param>
/// <param name="TargetExists">Asked once per candidate; nil reports every candidate.</param>
/// <returns>The lost links in file order; empty when none.</returns>
function FindLostModuleLinks( const OldText, NewText: string; const TargetExists: TDfmLinkTargetExists ): TArray<TDfmLostLink>;

/// <summary>Returns the name of a <c>.dfm</c> text's root component ( the form or data module ).</summary>
/// <param name="DfmText">The <c>.dfm</c> text.</param>
/// <returns>The root's name; empty when it has none.</returns>
function DfmRootName( const DfmText: string ): string;

/// <summary>Whether a <c>.dfm</c> text declares a component of this name below its root, at any depth.</summary>
/// <param name="DfmText">The <c>.dfm</c> text.</param>
/// <param name="ComponentName">The name, compared case-insensitively.</param>
/// <returns>True when a component below the root has that name.</returns>
function DfmDeclaresComponent( const DfmText, ComponentName: string ): Boolean;

/// <summary>The warning written to the Messages pane for one lost link.</summary>
/// <param name="Link">The lost link.</param>
/// <returns>One line naming the component, the property, the removed value and what to do.</returns>
function FormatLostLinkMessage( const Link: TDfmLostLink ): string;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, gllDelphiDFMParser, gllDfmCompare;

/// <summary>Counts how often each trimmed raw value occurs in a component and its descendants.</summary>
/// <param name="Component">The component to walk.</param>
/// <param name="Counts">Value -> occurrences, case-insensitive; added to.</param>
procedure CountValues( Component: TDfmComponent; Counts: TDictionary<string, Integer> );
begin
  for var oProp in Component.Properties do
  begin
    var sValue      := Trim( oProp.RawValue );
    var iCount      : Integer;
    if not Counts.TryGetValue( sValue, iCount ) then iCount := 0;
    Counts.AddOrSetValue( sValue, iCount + 1 );
  end;
  for var oChild in Component.Children do
    CountValues( oChild, Counts );
end;

/// <summary>Counts the values of a whole <c>.dfm</c> text.</summary>
/// <param name="DfmText">The text.</param>
/// <returns>Value -> occurrences, case-insensitive; the caller frees it.</returns>
function CountTextValues( const DfmText: string ): TDictionary<string, Integer>;
begin
  Result            := TDictionary<string, Integer>.Create( TIStringComparer.Ordinal );
  try
    var oDoc        := TDelphiDfmParser.Parse( DfmText );
    try
      CountValues( oDoc.Root, Result );
    finally
      oDoc.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

/// <summary>Whether a component or one of its descendants has this name.</summary>
/// <param name="Component">The component whose children are searched.</param>
/// <param name="ComponentName">The name, compared case-insensitively.</param>
/// <returns>True when a descendant has that name.</returns>
function HasDescendant( Component: TDfmComponent; const ComponentName: string ): Boolean;
begin
  for var oChild in Component.Children do
    if SameText( oChild.Name, ComponentName ) or HasDescendant( oChild, ComponentName ) then Exit( True );
  Result            := False;
end;

function FindLostModuleLinks( const OldText, NewText: string; const TargetExists: TDfmLinkTargetExists ): TArray<TDfmLostLink>;
begin
  Result            := nil;
  var aChanges      := CompareDfmText( OldText, NewText );

  // Value -> how many more removals of it may still be losses: its count in the old text less its count in the
  // new.  A value that appears as often as before was moved ( renamed property, another component ), not lost;
  // one that appears less often lost that many holders, even while another component still holds it.
  var dBudget: TDictionary<string, Integer> := nil;
  try
    for var rChange in aChanges do
    begin
      // ncModuleLinkLost is only ever a removed property of a component still present: a component removed
      // whole is one ncComponent change, so its links never get here.
      if rChange.Category <> ncModuleLinkLost then Continue;

      if dBudget = nil then
      begin
        dBudget     := CountTextValues( OldText );
        var dNew    := CountTextValues( NewText );
        try
          for var rPair in dNew do
          begin
            var iOld: Integer;
            if dBudget.TryGetValue( rPair.Key, iOld ) then dBudget[ rPair.Key ] := iOld - rPair.Value;
          end;
        finally
          dNew.Free;
        end;
      end;

      var sValue    := Trim( rChange.OldValue );
      var iBudget   : Integer;
      if not dBudget.TryGetValue( sValue, iBudget ) or ( iBudget <= 0 ) then Continue; // moved, not lost
      dBudget[ sValue ] := iBudget - 1;

      var iDot      := Pos( '.', sValue );
      var rLink     : TDfmLostLink;
      rLink.Path    := rChange.Path;
      rLink.PropName := rChange.PropName;
      rLink.Value   := sValue;
      rLink.ModuleName := Copy( sValue, 1, iDot - 1 );
      rLink.ComponentName := Copy( sValue, iDot + 1, MaxInt );

      if Assigned( TargetExists ) and not TargetExists( rLink.ModuleName, rLink.ComponentName ) then Continue;
      Result        := Result + [ rLink ];
    end;
  finally
    dBudget.Free;
  end;
end;

function DfmRootName( const DfmText: string ): string;
begin
  var oDoc          := TDelphiDfmParser.Parse( DfmText );
  try
    if oDoc.Root <> nil then
      Result        := oDoc.Root.Name
    else
      Result        := '';
  finally
    oDoc.Free;
  end;
end;

function DfmDeclaresComponent( const DfmText, ComponentName: string ): Boolean;
begin
  var oDoc          := TDelphiDfmParser.Parse( DfmText );
  try
    Result          := ( oDoc.Root <> nil ) and HasDescendant( oDoc.Root, ComponentName );
  finally
    oDoc.Free;
  end;
end;

function FormatLostLinkMessage( const Link: TDfmLostLink ): string;
begin
  Result            := Format( 'This save removed %s.%s = %s, but %s still exists in %s.  ' +
    'The IDE drops such a link when %s is not loaded: open it ( or Undo in the designer ), put the link back and save again.',
    [ Link.Path, Link.PropName, Link.Value, Link.ComponentName, Link.ModuleName, Link.ModuleName ] );
end;

end.
