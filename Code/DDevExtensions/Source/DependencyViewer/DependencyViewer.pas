{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{* (C) 2021-2025 DelphiPraxis                                                 *}
{* (C) 2026 Ian Branch, Claude code                                           *}
{*                                                                            *}
{******************************************************************************}

unit DependencyViewer;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Generics.Collections, Menus, Variants,
  ToolsAPI, FrmTreePages, PluginConfig, Main;

type
  TUnitDependency = record
    UnitName: string;
    FileName: string;
    IsInterface: Boolean; // True if in interface uses, False if in implementation uses
  end;

  {$WARN HIDING_MEMBER OFF}
  TUnitInfo = class
  private
    FUnitName: string;
    FFileName: string;
    FDependencies: TList<TUnitDependency>;
    FParsed: Boolean;
  public
    constructor Create( const AUnitName, AFileName: string );
    destructor Destroy; override;
    property UnitName: string read FUnitName;
    property FileName: string read FFileName;
    property Dependencies: TList<TUnitDependency> read FDependencies;
    property Parsed: Boolean read FParsed write FParsed;
  end;
  {$WARN HIDING_MEMBER ON}

  TCircularReferenceStep = record
    UnitName: string;
    IsInterface: Boolean;  // True if this unit is referenced via interface uses
  end;

  TCircularReference = record
    Steps: TArray<TCircularReferenceStep>;
  end;

  TImpactAnalysis = record
    UnitName: string;
    DirectDependents: TArray<string>;      // Units that directly use this unit
    TransitiveDependents: TArray<string>;  // All units affected (recursive)
    DirectCount: Integer;
    TransitiveCount: Integer;
    RiskLevel: Integer;                    // 0=Safe, 1=Low, 2=Medium, 3=High
    function RiskLevelText: string;
  end;

  TDependencyScanner = class
  private
    FUnits: TObjectDictionary<string, TUnitInfo>;
    FSearchPaths: TStringList;
    FCircularRefs: TList<TCircularReference>;
    FReverseDeps: TObjectDictionary<string, TStringList>;
    FDepthMap: TDictionary<string, Integer>;
    FOnProgress: TNotifyEvent;
    FProgressUnit: string;
    FProjectDefines: TStringList;
    FRespectConditionals: Boolean;
    procedure ParseUsesClause( const Content: string; UnitInfo: TUnitInfo );
    procedure ScanUnit( const UnitName, FileName: string );
    procedure DetectCircularReferences;
    function CheckCircular( const UnitName: string; IsInterface: Boolean;
      const Path: TList<TCircularReferenceStep>;
      var Visited: TDictionary<string, Boolean> ): Boolean;
    procedure BuildReverseDependencies;
    procedure CalculateDepths;
    function CalculateUnitDepth( const UnitName: string;
      var Calculating: TDictionary<string, Boolean> ): Integer;
    function IsDefineDefined( const DefineName: string ): Boolean;
    function EvaluateIfCondition( const Condition: string ): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure AddSearchPath( const Path: string );
    procedure ScanProject( const Project: IOTAProject );
    procedure ScanFile( const FileName: string );
    function GetUnitInfo( const UnitName: string ): TUnitInfo;
    function GetAllUnits: TArray<TUnitInfo>;
    function GetReverseDependencies( const UnitName: string ): TStringList;
    function GetUnitDepth( const UnitName: string ): Integer;
    function AnalyzeImpact( const UnitName: string ): TImpactAnalysis;
    property CircularReferences: TList<TCircularReference> read FCircularRefs;
    property OnProgress: TNotifyEvent read FOnProgress write FOnProgress;
    property ProgressUnit: string read FProgressUnit;
    property RespectConditionals: Boolean read FRespectConditionals write FRespectConditionals;
  end;

  TDependencyViewerPlugin = class( TPluginConfig )
  private
    FEnabled: Boolean;
    FRespectConditionals: Boolean;
    FMenuItem: TMenuItem;
    procedure MenuItemClick( Sender: TObject );
  protected
    function GetOptionPages: TTreePage; override;
    procedure Init; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ShowDependencyViewer;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
    property RespectConditionals: Boolean read FRespectConditionals write FRespectConditionals;
  end;

procedure InitPlugin( Unload: Boolean );

var
  DependencyViewerPlugin: TDependencyViewerPlugin;

implementation

uses
  Forms, Controls, ToolsAPIHelpers, AppConsts,
  FrmDependencyViewer, FrmeOptionPageDependencyViewer;

{ TUnitInfo }

constructor TUnitInfo.Create( const AUnitName, AFileName: string );
begin

  inherited Create;
  FUnitName     := AUnitName;
  FFileName     := AFileName;
  FDependencies := TList<TUnitDependency>.Create;
  FParsed       := False;

end;

destructor TUnitInfo.Destroy;
begin

  FDependencies.Free;
  inherited Destroy;

end;

{ TDependencyScanner }

constructor TDependencyScanner.Create;
begin

  inherited Create;
  FUnits                     := TObjectDictionary<string, TUnitInfo>.Create( [ doOwnsValues ] );
  FSearchPaths               := TStringList.Create;
  FSearchPaths.CaseSensitive := False;
  FSearchPaths.Duplicates    := dupIgnore;
  FCircularRefs              := TList<TCircularReference>.Create;
  FReverseDeps               := TObjectDictionary<string, TStringList>.Create( [ doOwnsValues ] );
  FDepthMap                  := TDictionary<string, Integer>.Create;
  FProjectDefines            := TStringList.Create;
  FProjectDefines.CaseSensitive := False;
  FProjectDefines.Sorted     := True;
  FProjectDefines.Duplicates := dupIgnore;
  FRespectConditionals       := True;

end;

destructor TDependencyScanner.Destroy;
begin

  FProjectDefines.Free;
  FDepthMap.Free;
  FReverseDeps.Free;
  FCircularRefs.Free;
  FSearchPaths.Free;
  FUnits.Free;
  inherited Destroy;

end;

procedure TDependencyScanner.Clear;
begin

  FUnits.Clear;
  FSearchPaths.Clear;
  FCircularRefs.Clear;
  FReverseDeps.Clear;
  FDepthMap.Clear;
  FProjectDefines.Clear;

end;

procedure TDependencyScanner.AddSearchPath( const Path: string );
var
  ExpandedPath: string;
begin

  ExpandedPath := ExcludeTrailingPathDelimiter( Path );

  if ( ExpandedPath <> '' ) and DirectoryExists( ExpandedPath ) then
    FSearchPaths.Add( ExpandedPath );

end;

function TDependencyScanner.IsDefineDefined( const DefineName: string ): Boolean;
begin

  Result := FProjectDefines.IndexOf( DefineName ) >= 0;

end;

function TDependencyScanner.EvaluateIfCondition( const Condition: string ): Integer;
var
  TrimmedCond: string;
  P1, P2: Integer;
  DefName: string;
  InnerResult: Integer;
  NotPrefix: Boolean;

  function EvaluateSingleTerm( const Term: string ): Integer;
  var
    TTerm: string;
    IsNot: Boolean;
    TP1, TP2: Integer;
    TDefName: string;
  begin
    // Returns: 1 = true, 0 = false, -1 = unknown
    Result := -1;
    TTerm  := Trim( Term );

    if TTerm = '' then
      Exit;

    // Handle NOT prefix
    IsNot := False;

    if SameText( Copy( TTerm, 1, 4 ), 'NOT ' ) then
    begin
      IsNot := True;
      TTerm := Trim( Copy( TTerm, 5, MaxInt ) );
    end;

    // Handle Defined(X) syntax
    if SameText( Copy( TTerm, 1, 8 ), 'DEFINED(' ) then
    begin
      TP1 := Pos( '(', TTerm );
      TP2 := Pos( ')', TTerm );

      if ( TP1 > 0 ) and ( TP2 > TP1 ) then
      begin
        TDefName := Trim( Copy( TTerm, TP1 + 1, TP2 - TP1 - 1 ) );

        if IsDefineDefined( TDefName ) then
          Result := 1
        else
          Result := 0;

        if IsNot then
          Result := 1 - Result;

        Exit;
      end;
    end;

    // Handle simple identifier (treat as Defined(X))
    if ( Pos( '(', TTerm ) = 0 ) and ( Pos( ' ', TTerm ) = 0 ) then
    begin

      if IsDefineDefined( TTerm ) then
        Result := 1
      else
        Result := 0;

      if IsNot then
        Result := 1 - Result;
    end;

  end;

  function SplitByOperator( const S, Op: string ): TArray<string>;
  var
    UpperS: string;
    StartPos, FoundPos: Integer;
    Count: Integer;
  begin
    SetLength( Result, 0 );
    UpperS   := UpperCase( S );
    StartPos := 1;
    Count    := 0;

    while StartPos <= Length( S ) do
    begin
      FoundPos := Pos( Op, Copy( UpperS, StartPos, MaxInt ) );

      if FoundPos = 0 then
      begin
        SetLength( Result, Count + 1 );
        Result[ Count ] := Trim( Copy( S, StartPos, MaxInt ) );
        Break;
      end
      else
      begin
        SetLength( Result, Count + 1 );
        Result[ Count ] := Trim( Copy( S, StartPos, FoundPos - 1 ) );
        Inc( Count );
        StartPos := StartPos + FoundPos + Length( Op ) - 1;
      end;
    end;

  end;

var
  OrParts, AndParts: TArray<string>;
  I, J: Integer;
  OrResult, AndResult, TermResult: Integer;
  HasUnknown: Boolean;
begin

  // Returns: 1 = true, 0 = false, -1 = unknown/cannot evaluate
  Result      := -1;
  TrimmedCond := Trim( Condition );

  if TrimmedCond = '' then
    Exit;

  // Handle NOT prefix for entire expression
  NotPrefix := False;

  if SameText( Copy( TrimmedCond, 1, 4 ), 'NOT ' ) then
  begin
    NotPrefix   := True;
    TrimmedCond := Trim( Copy( TrimmedCond, 5, MaxInt ) );
  end;

  // Check for compound OR expression
  if Pos( ' OR ', UpperCase( TrimmedCond ) ) > 0 then
  begin
    OrParts    := SplitByOperator( TrimmedCond, ' OR ' );
    OrResult   := 0;     // Start with false for OR
    HasUnknown := False;

    for I := 0 to High( OrParts ) do
    begin
      // Each OR part might have AND sub-parts
      if Pos( ' AND ', UpperCase( OrParts[ I ] ) ) > 0 then
      begin
        AndParts  := SplitByOperator( OrParts[ I ], ' AND ' );
        AndResult := 1; // Start with true for AND

        for J := 0 to High( AndParts ) do
        begin
          TermResult := EvaluateSingleTerm( AndParts[ J ] );

          if TermResult = -1 then
            HasUnknown := True
          else if TermResult = 0 then
          begin
            AndResult := 0;
            Break; // AND fails if any term is false
          end;
        end;

        if AndResult = 1 then
        begin
          OrResult := 1;
          Break; // OR succeeds if any term is true
        end;
      end
      else
      begin
        TermResult := EvaluateSingleTerm( OrParts[ I ] );

        if TermResult = -1 then
          HasUnknown := True
        else if TermResult = 1 then
        begin
          OrResult := 1;
          Break; // OR succeeds if any term is true
        end;
      end;
    end;

    if OrResult = 1 then
      Result := 1
    else if HasUnknown then
      Result := -1
    else
      Result := 0;

    if NotPrefix and ( Result >= 0 ) then
      Result := 1 - Result;

    Exit;
  end;

  // Check for compound AND expression (without OR)
  if Pos( ' AND ', UpperCase( TrimmedCond ) ) > 0 then
  begin
    AndParts   := SplitByOperator( TrimmedCond, ' AND ' );
    AndResult  := 1; // Start with true for AND
    HasUnknown := False;

    for I := 0 to High( AndParts ) do
    begin
      TermResult := EvaluateSingleTerm( AndParts[ I ] );

      if TermResult = -1 then
        HasUnknown := True
      else if TermResult = 0 then
      begin
        AndResult := 0;
        Break; // AND fails if any term is false
      end;
    end;

    if AndResult = 0 then
      Result := 0
    else if HasUnknown then
      Result := -1
    else
      Result := 1;

    if NotPrefix and ( Result >= 0 ) then
      Result := 1 - Result;

    Exit;
  end;

  // Handle Defined(X) syntax - simple case
  if SameText( Copy( TrimmedCond, 1, 8 ), 'DEFINED(' ) then
  begin
    P1 := Pos( '(', TrimmedCond );
    P2 := Pos( ')', TrimmedCond );

    if ( P1 > 0 ) and ( P2 > P1 ) then
    begin
      DefName := Trim( Copy( TrimmedCond, P1 + 1, P2 - P1 - 1 ) );

      if IsDefineDefined( DefName ) then
        InnerResult := 1
      else
        InnerResult := 0;

      if NotPrefix then
        InnerResult := 1 - InnerResult;

      Result := InnerResult;
      Exit;
    end;
  end;

  // Handle simple identifier (treat as Defined(X))
  if ( Pos( '(', TrimmedCond ) = 0 ) and ( Pos( ' ', TrimmedCond ) = 0 ) then
  begin

    if IsDefineDefined( TrimmedCond ) then
      InnerResult := 1
    else
      InnerResult := 0;

    if NotPrefix then
      InnerResult := 1 - InnerResult;

    Result := InnerResult;
  end;

end;

procedure TDependencyScanner.ParseUsesClause( const Content: string; UnitInfo: TUnitInfo );
type
  TCondState = record
    Active: Boolean;       // Is this block active (condition was true)?
    WasActive: Boolean;    // Was any branch in this IF/ELSE chain active?
    ParentActive: Boolean; // Was parent block active when we entered?
  end;
var
  I, Len, BraceEnd: Integer;
  InInterface, InImplementation: Boolean;
  InUses, InString, InComment, InLineComment: Boolean;
  Token: string;
  Ch: Char;
  Dep: TUnitDependency;
  CondStack: TList<TCondState>;
  DirectiveContent, DefineName, IfCondition: string;

  function IsCodeActive: Boolean;
  var
    J: Integer;
  begin

    Result := True;

    if FRespectConditionals then
    begin

      for J := 0 to CondStack.Count - 1 do
      begin

        if not CondStack[ J ].Active then
        begin
          Result := False;
          Exit;
        end;
      end;
    end;

  end;

  procedure AddToken;
  begin

    if Token <> '' then
    begin

      if SameText( Token, 'interface' ) then
      begin
        InInterface      := True;
        InImplementation := False;
      end
      else if SameText( Token, 'implementation' ) then
      begin
        InInterface      := False;
        InImplementation := True;
        InUses           := False;
      end
      else if SameText( Token, 'uses' ) and IsCodeActive then
        InUses := True
      else if InUses and IsCodeActive and ( not SameText( Token, 'in' ) ) then
      begin
        Dep.UnitName    := Token;
        Dep.FileName    := '';
        Dep.IsInterface := InInterface;
        UnitInfo.Dependencies.Add( Dep );
      end;

      Token := '';
    end;

  end;

  procedure ProcessDirective( const Directive: string );
  var
    DirUpper: string;
    NewState: TCondState;
    TopState: TCondState;
    EvalResult: Integer;
  begin

    DirUpper := UpperCase( Trim( Directive ) );

    // {$IFDEF X}
    if Copy( DirUpper, 1, 6 ) = 'IFDEF ' then
    begin
      DefineName          := Trim( Copy( Directive, 7, MaxInt ) );
      NewState.ParentActive := IsCodeActive;
      NewState.Active     := NewState.ParentActive and IsDefineDefined( DefineName );
      NewState.WasActive  := NewState.Active;
      CondStack.Add( NewState );
    end
    // {$IFNDEF X}
    else if Copy( DirUpper, 1, 7 ) = 'IFNDEF ' then
    begin
      DefineName          := Trim( Copy( Directive, 8, MaxInt ) );
      NewState.ParentActive := IsCodeActive;
      NewState.Active     := NewState.ParentActive and ( not IsDefineDefined( DefineName ) );
      NewState.WasActive  := NewState.Active;
      CondStack.Add( NewState );
    end
    // {$IF ...}
    else if ( Copy( DirUpper, 1, 3 ) = 'IF ' ) or ( Copy( DirUpper, 1, 3 ) = 'IF(' ) then
    begin

      if Copy( DirUpper, 1, 3 ) = 'IF ' then
        IfCondition := Trim( Copy( Directive, 4, MaxInt ) )
      else
        IfCondition := Trim( Copy( Directive, 3, MaxInt ) );

      NewState.ParentActive := IsCodeActive;
      EvalResult          := EvaluateIfCondition( IfCondition );

      if EvalResult = 1 then
        NewState.Active := NewState.ParentActive
      else if EvalResult = 0 then
        NewState.Active := False
      else
        NewState.Active := NewState.ParentActive; // Unknown - include for safety

      NewState.WasActive := NewState.Active;
      CondStack.Add( NewState );
    end
    // {$ELSEIF ...}
    else if ( Copy( DirUpper, 1, 7 ) = 'ELSEIF ' ) or ( Copy( DirUpper, 1, 7 ) = 'ELSEIF(' ) then
    begin

      if CondStack.Count > 0 then
      begin
        TopState := CondStack[ CondStack.Count - 1 ];

        // Only consider ELSEIF if no previous branch was active
        if TopState.WasActive then
          TopState.Active := False
        else
        begin

          if Copy( DirUpper, 1, 7 ) = 'ELSEIF ' then
            IfCondition := Trim( Copy( Directive, 8, MaxInt ) )
          else
            IfCondition := Trim( Copy( Directive, 7, MaxInt ) );

          EvalResult := EvaluateIfCondition( IfCondition );

          if EvalResult = 1 then
          begin
            TopState.Active    := TopState.ParentActive;
            TopState.WasActive := True;
          end
          else
            TopState.Active := False;
        end;

        CondStack[ CondStack.Count - 1 ] := TopState;
      end;
    end
    // {$ELSE}
    else if DirUpper = 'ELSE' then
    begin

      if CondStack.Count > 0 then
      begin
        TopState := CondStack[ CondStack.Count - 1 ];

        // ELSE is active only if no previous branch was active
        if TopState.WasActive then
          TopState.Active := False
        else
        begin
          TopState.Active    := TopState.ParentActive;
          TopState.WasActive := True;
        end;

        CondStack[ CondStack.Count - 1 ] := TopState;
      end;
    end
    // {$ENDIF} or {$IFEND}
    else if ( DirUpper = 'ENDIF' ) or ( DirUpper = 'IFEND' ) then
    begin

      if CondStack.Count > 0 then
        CondStack.Delete( CondStack.Count - 1 );
    end;

  end;

begin

  I                := 1;
  Len              := Length( Content );
  InInterface      := False;
  InImplementation := False;
  InUses           := False;
  InString         := False;
  InComment        := False;
  InLineComment    := False;
  Token            := '';
  CondStack        := TList<TCondState>.Create;

  try

    while I <= Len do
    begin
      Ch := Content[ I ];

      // Handle line comments
      if InLineComment then
      begin

        if ( Ch = #13 ) or ( Ch = #10 ) then
          InLineComment := False;

        Inc( I );
        Continue;
      end;

      // Handle block comments (* ... *)
      if InComment then
      begin

        if ( Ch = '*' ) and ( I < Len ) and ( Content[ I + 1 ] = ')' ) then
        begin
          InComment := False;
          Inc( I );
        end;

        Inc( I );
        Continue;
      end;

      // Handle strings
      if InString then
      begin

        if Ch = '''' then
          InString := False;

        Inc( I );
        Continue;
      end;

      // Check for comment start //
      if ( Ch = '/' ) and ( I < Len ) and ( Content[ I + 1 ] = '/' ) then
      begin
        AddToken;
        InLineComment := True;
        Inc( I, 2 );
        Continue;
      end;

      // Check for comment start (*
      if ( Ch = '(' ) and ( I < Len ) and ( Content[ I + 1 ] = '*' ) then
      begin
        AddToken;
        InComment := True;
        Inc( I, 2 );
        Continue;
      end;

      // Handle braces { ... } - could be comment or directive
      if Ch = '{' then
      begin
        AddToken;

        // Find the closing brace
        BraceEnd := I + 1;

        while ( BraceEnd <= Len ) and ( Content[ BraceEnd ] <> '}' ) do
          Inc( BraceEnd );

        if BraceEnd <= Len then
        begin
          // Extract content between braces
          DirectiveContent := Copy( Content, I + 1, BraceEnd - I - 1 );

          // Check if it's a compiler directive
          if ( Length( DirectiveContent ) > 0 ) and ( DirectiveContent[ 1 ] = '$' ) then
          begin
            // It's a directive - process it
            DirectiveContent := Copy( DirectiveContent, 2, MaxInt ); // Remove $
            ProcessDirective( DirectiveContent );
          end;
          // Else it's just a comment - ignore

          I := BraceEnd + 1;
          Continue;
        end
        else
        begin
          // No closing brace found - skip to end
          I := Len + 1;
          Continue;
        end;
      end;

      if Ch = '''' then
      begin
        AddToken;
        InString := True;
        Inc( I );
        Continue;
      end;

      // Parse tokens
      if CharInSet( Ch, [ 'A'..'Z', 'a'..'z', '_', '0'..'9', '.' ] ) then
        Token := Token + Ch
      else
      begin
        AddToken;

        if InUses and ( Ch = ';' ) then
          InUses := False;
      end;

      Inc( I );
    end;

    AddToken;
  finally
    CondStack.Free;
  end;

end;

procedure TDependencyScanner.ScanUnit( const UnitName, FileName: string );
var
  UnitInfo: TUnitInfo;
  Content: string;
  SL: TStringList;
  LowerName: string;
begin

  LowerName := LowerCase( UnitName );

  if FUnits.ContainsKey( LowerName ) then
  begin
    UnitInfo := FUnits[ LowerName ];

    if UnitInfo.Parsed then
      Exit;
  end
  else
  begin
    UnitInfo := TUnitInfo.Create( UnitName, FileName );
    FUnits.Add( LowerName, UnitInfo );
  end;

  FProgressUnit := UnitName;

  if Assigned( FOnProgress ) then
    FOnProgress( Self );

  if ( FileName <> '' ) and FileExists( FileName ) then
  begin
    SL := TStringList.Create;

    try
      SL.LoadFromFile( FileName );
      Content := SL.Text;
    finally
      SL.Free;
    end;

    ParseUsesClause( Content, UnitInfo );
    UnitInfo.Parsed := True;

    // Recursively scan dependencies
    // (Disabled for performance - only scan on demand)
  end;

end;

procedure TDependencyScanner.ScanProject( const Project: IOTAProject );
var
  I: Integer;
  ModuleInfo: IOTAModuleInfo;
  FileName, UnitName: string;
  Options: IOTAProjectOptions;
  SearchPath, OutputDir, DefinesStr: string;
  SL: TStringList;
begin

  if Project = nil then
    Exit;

  Clear;

  // Add project directory as search path
  AddSearchPath( ExtractFileDir( Project.FileName ) );

  // Get search paths and defines from project options
  Options := Project.ProjectOptions;

  if Options <> nil then
  begin
    // Extract conditional defines
    if FRespectConditionals then
    begin
      DefinesStr := VarToStr( Options.Values[ 'Defines' ] );

      if DefinesStr <> '' then
      begin
        SL := TStringList.Create;

        try
          SL.Delimiter       := ';';
          SL.StrictDelimiter := True;
          SL.DelimitedText   := DefinesStr;

          for I := 0 to SL.Count - 1 do
          begin

            if Trim( SL[ I ] ) <> '' then
              FProjectDefines.Add( Trim( SL[ I ] ) );
          end;
        finally
          SL.Free;
        end;
      end;
    end;

    // Extract search paths
    SearchPath := VarToStr( Options.Values[ 'UnitDir' ] );
    SL         := TStringList.Create;

    try
      SL.Delimiter       := ';';
      SL.StrictDelimiter := True;
      SL.DelimitedText   := SearchPath;

      for I := 0 to SL.Count - 1 do
        AddSearchPath( ExpandFileName( SL[ I ] ) );
    finally
      SL.Free;
    end;

    OutputDir := VarToStr( Options.Values[ 'UnitOutputDir' ] );

    if OutputDir <> '' then
      AddSearchPath( ExpandFileName( OutputDir ) );
  end;

  // Scan all units in the project
  for I := 0 to Project.GetModuleCount - 1 do
  begin
    ModuleInfo := Project.GetModule( I );
    FileName   := ModuleInfo.FileName;

    if SameText( ExtractFileExt( FileName ), '.pas' ) then
    begin
      UnitName := ChangeFileExt( ExtractFileName( FileName ), '' );
      ScanUnit( UnitName, FileName );
    end;
  end;

  DetectCircularReferences;
  BuildReverseDependencies;
  CalculateDepths;

end;

procedure TDependencyScanner.ScanFile( const FileName: string );
var
  UnitName: string;
begin

  if FileExists( FileName ) and SameText( ExtractFileExt( FileName ), '.pas' ) then
  begin
    UnitName := ChangeFileExt( ExtractFileName( FileName ), '' );
    AddSearchPath( ExtractFileDir( FileName ) );
    ScanUnit( UnitName, FileName );
  end;

end;

function TDependencyScanner.GetUnitInfo( const UnitName: string ): TUnitInfo;
begin

  if ( not FUnits.TryGetValue( LowerCase( UnitName ), Result ) ) then
    Result := nil;

end;

function TDependencyScanner.GetAllUnits: TArray<TUnitInfo>;
var
  List: TList<TUnitInfo>;
  Pair: TPair<string, TUnitInfo>;
begin

  List := TList<TUnitInfo>.Create;

  try

    for Pair in FUnits do
      List.Add( Pair.Value );

    Result := List.ToArray;
  finally
    List.Free;
  end;

end;

function TDependencyScanner.GetReverseDependencies( const UnitName: string ): TStringList;
begin

  if not FReverseDeps.TryGetValue( LowerCase( UnitName ), Result ) then
    Result := nil;

end;

function TDependencyScanner.GetUnitDepth( const UnitName: string ): Integer;
begin

  if not FDepthMap.TryGetValue( LowerCase( UnitName ), Result ) then
    Result := 0;

end;

{ TImpactAnalysis }

function TImpactAnalysis.RiskLevelText: string;
begin

  case RiskLevel of
    0: Result := 'Safe';
    1: Result := 'Low';
    2: Result := 'Medium';
    3: Result := 'High';
  else
    Result := 'Unknown';
  end;

end;

function TDependencyScanner.AnalyzeImpact( const UnitName: string ): TImpactAnalysis;
var
  Visited: TStringList;
  RevDeps: TStringList;
  I: Integer;

  procedure CollectTransitive( const Name: string );
  var
    ChildRevDeps: TStringList;
    J: Integer;
  begin

    ChildRevDeps := GetReverseDependencies( Name );

    if ChildRevDeps = nil then
      Exit;

    for J := 0 to ChildRevDeps.Count - 1 do
    begin

      if Visited.IndexOf( ChildRevDeps[ J ] ) < 0 then
      begin
        Visited.Add( ChildRevDeps[ J ] );
        CollectTransitive( ChildRevDeps[ J ] );
      end;
    end;

  end;

begin

  Result.UnitName := UnitName;

  // Get direct dependents
  RevDeps := GetReverseDependencies( UnitName );

  if RevDeps <> nil then
  begin
    SetLength( Result.DirectDependents, RevDeps.Count );

    for I := 0 to RevDeps.Count - 1 do
      Result.DirectDependents[ I ] := RevDeps[ I ];
  end
  else
    SetLength( Result.DirectDependents, 0 );

  Result.DirectCount := Length( Result.DirectDependents );

  // Collect transitive dependents
  Visited := TStringList.Create;

  try
    Visited.CaseSensitive := False;
    Visited.Sorted        := True;
    Visited.Duplicates    := dupIgnore;

    CollectTransitive( UnitName );

    SetLength( Result.TransitiveDependents, Visited.Count );

    for I := 0 to Visited.Count - 1 do
      Result.TransitiveDependents[ I ] := Visited[ I ];

    Result.TransitiveCount := Visited.Count;
  finally
    Visited.Free;
  end;

  // Calculate risk level based on transitive impact
  if Result.TransitiveCount = 0 then
    Result.RiskLevel := 0      // Safe - nothing depends on it
  else if Result.TransitiveCount <= 3 then
    Result.RiskLevel := 1      // Low
  else if Result.TransitiveCount <= 10 then
    Result.RiskLevel := 2      // Medium
  else
    Result.RiskLevel := 3;     // High - many units affected

end;

procedure TDependencyScanner.BuildReverseDependencies;
var
  Pair: TPair<string, TUnitInfo>;
  UnitInfo: TUnitInfo;
  Dep: TUnitDependency;
  LowerDepName: string;
  RevList: TStringList;
begin

  FReverseDeps.Clear;

  // Build reverse dependency map: for each unit, find all units that use it
  for Pair in FUnits do
  begin
    UnitInfo := Pair.Value;

    for Dep in UnitInfo.Dependencies do
    begin
      LowerDepName := LowerCase( Dep.UnitName );

      if not FReverseDeps.TryGetValue( LowerDepName, RevList ) then
      begin
        RevList            := TStringList.Create;
        RevList.Sorted     := True;
        RevList.Duplicates := dupIgnore;
        FReverseDeps.Add( LowerDepName, RevList );
      end;

      RevList.Add( UnitInfo.UnitName );
    end;
  end;

end;

procedure TDependencyScanner.CalculateDepths;
var
  Calculating: TDictionary<string, Boolean>;
  Pair: TPair<string, TUnitInfo>;
begin

  FDepthMap.Clear;
  Calculating := TDictionary<string, Boolean>.Create;

  try

    for Pair in FUnits do
      CalculateUnitDepth( Pair.Key, Calculating );
  finally
    Calculating.Free;
  end;

end;

function TDependencyScanner.CalculateUnitDepth( const UnitName: string;
  var Calculating: TDictionary<string, Boolean> ): Integer;
var
  UnitInfo: TUnitInfo;
  Dep: TUnitDependency;
  DepDepth: Integer;
  LowerName, LowerDepName: string;
  IsCalculating: Boolean;
begin

  LowerName := LowerCase( UnitName );

  // Return cached depth if already calculated
  if FDepthMap.TryGetValue( LowerName, Result ) then
    Exit;

  // Check for circular dependency (being calculated)
  if Calculating.TryGetValue( LowerName, IsCalculating ) and IsCalculating then
  begin
    Result := 0;
    Exit;
  end;

  // If unit not in project, depth is 0 (external dependency)
  if not FUnits.TryGetValue( LowerName, UnitInfo ) then
  begin
    Result := 0;
    FDepthMap.Add( LowerName, Result );
    Exit;
  end;

  // Mark as being calculated
  Calculating.AddOrSetValue( LowerName, True );

  try
    Result := 0;

    // Depth is 1 + max depth of dependencies (only project units count)
    for Dep in UnitInfo.Dependencies do
    begin
      LowerDepName := LowerCase( Dep.UnitName );

      if FUnits.ContainsKey( LowerDepName ) then
      begin
        DepDepth := CalculateUnitDepth( Dep.UnitName, Calculating );

        if DepDepth + 1 > Result then
          Result := DepDepth + 1;
      end;
    end;

    FDepthMap.AddOrSetValue( LowerName, Result );
  finally
    Calculating.AddOrSetValue( LowerName, False );
  end;

end;

procedure TDependencyScanner.DetectCircularReferences;
var
  Visited: TDictionary<string, Boolean>;
  Path: TList<TCircularReferenceStep>;
  Pair: TPair<string, TUnitInfo>;
begin

  FCircularRefs.Clear;
  Visited := TDictionary<string, Boolean>.Create;
  Path    := TList<TCircularReferenceStep>.Create;

  try

    for Pair in FUnits do
    begin
      Visited.Clear;
      Path.Clear;
      CheckCircular( Pair.Key, True, Path, Visited );
    end;
  finally
    Path.Free;
    Visited.Free;
  end;

end;

function TDependencyScanner.CheckCircular( const UnitName: string; IsInterface: Boolean;
  const Path: TList<TCircularReferenceStep>;
  var Visited: TDictionary<string, Boolean> ): Boolean;
var
  UnitInfo: TUnitInfo;
  Dep: TUnitDependency;
  CircRef: TCircularReference;
  Step: TCircularReferenceStep;
  I, J, StartIdx: Integer;
  IsVisited: Boolean;
  LowerName: string;
begin

  Result    := False;
  LowerName := LowerCase( UnitName );

  // Check if we've found a cycle
  for I := 0 to Path.Count - 1 do
  begin

    if SameText( Path[ I ].UnitName, UnitName ) then
    begin
      // Found a cycle - record it
      StartIdx := I;
      SetLength( CircRef.Steps, Path.Count - StartIdx + 1 );

      for J := StartIdx to Path.Count - 1 do
        CircRef.Steps[ J - StartIdx ] := Path[ J ];

      // Last step closes the cycle with current IsInterface info
      CircRef.Steps[ High( CircRef.Steps ) ].UnitName    := UnitName;
      CircRef.Steps[ High( CircRef.Steps ) ].IsInterface := IsInterface;
      FCircularRefs.Add( CircRef );
      Result := True;
      Exit;
    end;
  end;

  if Visited.TryGetValue( LowerName, IsVisited ) and IsVisited then
    Exit;

  Visited.AddOrSetValue( LowerName, True );

  Step.UnitName    := UnitName;
  Step.IsInterface := IsInterface;
  Path.Add( Step );

  try

    if FUnits.TryGetValue( LowerName, UnitInfo ) then
    begin

      for Dep in UnitInfo.Dependencies do
        CheckCircular( Dep.UnitName, Dep.IsInterface, Path, Visited );
    end;
  finally
    Path.Delete( Path.Count - 1 );
  end;

end;

{ TDependencyViewerPlugin }

constructor TDependencyViewerPlugin.Create;
begin

  inherited Create( AppDataDirectory + '\DependencyViewer.xml', 'DependencyViewer' );

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem         := TMenuItem.Create( DDevExtensionsMenu );
    FMenuItem.Caption := '&Dependency Viewer...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add( FMenuItem );
  end;

end;

destructor TDependencyViewerPlugin.Destroy;
begin

  FreeAndNil( FMenuItem );
  inherited Destroy;

end;

procedure TDependencyViewerPlugin.Init;
begin

  FEnabled             := True;
  FRespectConditionals := True;

end;

function TDependencyViewerPlugin.GetOptionPages: TTreePage;
begin

  Result := TTreePage.Create( 'Dependency Viewer', TFrameOptionPageDependencyViewer, Self );

end;

procedure TDependencyViewerPlugin.MenuItemClick( Sender: TObject );
begin

  ShowDependencyViewer;

end;

procedure TDependencyViewerPlugin.ShowDependencyViewer;
begin

  TFormDependencyViewer.Execute;

end;

procedure InitPlugin( Unload: Boolean );
begin

  if ( not Unload ) then
    DependencyViewerPlugin := TDependencyViewerPlugin.Create
  else
  begin
    DependencyViewerPlugin.Free;
    DependencyViewerPlugin := nil;
  end;

end;

end.
