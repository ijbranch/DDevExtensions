{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit FeatureSwitches;

/// <summary>
/// Parses the <c>DDevExtensions.DisabledFeatures</c> environment variable (a <c>;</c>-separated list of feature
/// names) and reports names that matched no feature, so a typo in a test switch is not silently ignored.
/// </summary>

interface

uses
  System.Classes;

const
  /// <summary>
  /// Every feature switch name any DDevExtensions build registers, across all IDE versions.  The environment
  /// variable is shared by every installed IDE, so a name that this build's <c>{$IFDEF}</c>s exclude (Old Palette
  /// on Delphi 13, say) is still a real feature and must not be reported as a typo.
  /// </summary>
  AllFeatureNames   : array[ 0..36 ] of string = (
    'CodeInsightHandling', 'CodeQualityAnalyzer', 'CodeStyleChecker', 'CompileBackup', 'CompileProgress',
    'ComponentSelector', 'DSUFeatures', 'DeadCodeDetector', 'Decirculariser', 'DependencyViewer',
    'DfmPasConsistency', 'Editor', 'EmptyEventHandlerDetector', 'ExternalModMonitor', 'FileCleaner',
    'FocusEditor', 'FormDesigner', 'IDEMenuHandler', 'Keybindings', 'LibraryPathSorter', 'MethodSeparators',
    'OldPalette', 'ParallelBuild', 'PathCompactor', 'ProjectDesktopState', 'ProjectGroupSorter', 'ProjectMgrShortCuts',
    'ProjectSettingsSetVersioninfo', 'ReloadFiles', 'StartParameter', 'StartParameterTeam', 'StrucViewSearch',
    'TodoAggregator', 'UnitSelector', 'UnreachableCodeDetector', 'UnusedUnitDetector', 'UsesClauseManager' );

type
  /// <summary>The set of features switched off for this session.</summary>
  TFeatureSwitches = class( TObject )
  private
    /// <summary>The disabled names, trimmed, sorted, case-insensitive, no empties.</summary>
    FDisabled: TStringList;
    /// <summary>Every feature name asked about through <see cref="IsDisabled"/>.</summary>
    FKnown: TStringList;
  public
    /// <summary>
    /// Parses the list the way the switch always has (<c>TStrings.DelimitedText</c>): <c>;</c> and spaces both
    /// separate names, and a name in double quotes may contain either.
    /// </summary>
    /// <param name="DisabledList">The variable's value (may be empty).</param>
    constructor Create( const DisabledList: string );
    /// <summary>Frees the lists.</summary>
    destructor Destroy; override;
    /// <summary>True when <paramref name="FeatureName"/> is switched off; also records the name as a known feature.</summary>
    /// <param name="FeatureName">The feature's switch name, as registered.</param>
    /// <returns>True when the feature is listed in the variable.</returns>
    function IsDisabled( const FeatureName: string ): Boolean;
    /// <summary>
    /// Names in the variable that match no feature: neither one asked about through <see cref="IsDisabled"/> nor any
    /// name in <see cref="AllFeatureNames"/>.
    /// </summary>
    /// <returns>The unmatched names, in sorted order.</returns>
    function UnknownNames: TArray<string>;
  end;

implementation

uses
  System.SysUtils;

constructor TFeatureSwitches.Create( const DisabledList: string );
begin
  inherited Create;
  FDisabled         := TStringList.Create;
  FDisabled.CaseSensitive := False;
  FDisabled.Sorted  := True;
  FDisabled.Duplicates := dupIgnore;
  FKnown            := TStringList.Create;
  FKnown.CaseSensitive := False;
  FKnown.Sorted     := True;
  FKnown.Duplicates := dupIgnore;
  // Same splitting as the switch has always had, so existing values keep working: ';' and white space
  // separate, double quotes group
  var Parts         := TStringList.Create;
  try
    Parts.Delimiter := ';';
    Parts.QuoteChar := '"';
    Parts.StrictDelimiter := False;
    Parts.DelimitedText := DisabledList;
    for var Part in Parts do
    begin
      var Name := Part.Trim;
      if Name <> '' then
        FDisabled.Add( Name );
    end;
  finally
    Parts.Free;
  end;
end;

destructor TFeatureSwitches.Destroy;
begin
  FKnown.Free;
  FDisabled.Free;
  inherited Destroy;
end;

function TFeatureSwitches.IsDisabled( const FeatureName: string ): Boolean;
begin
  FKnown.Add( FeatureName );
  Result            := FDisabled.IndexOf( FeatureName ) <> -1;
end;

function TFeatureSwitches.UnknownNames: TArray<string>;
begin
  Result            := nil;
  for var Name in FDisabled do
  begin
    var Known := FKnown.IndexOf( Name ) <> -1;
    for var Feature in AllFeatureNames do
      if SameText( Feature, Name ) then
        Known       := True;
    if not Known then
      Result        := Result + [ Name ];
  end;
end;

end.

