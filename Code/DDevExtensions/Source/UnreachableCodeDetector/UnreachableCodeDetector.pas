{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2025 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit UnreachableCodeDetector;

{$I ..\DelphiExtension.inc}

interface

uses
  Windows, SysUtils, Classes, Generics.Collections, Menus,
  ToolsAPI, FrmTreePages, PluginConfig, Main;

type
  TUnreachableReason = (
    urAfterExit,
    urAfterRaise,
    urAfterBreak,
    urAfterContinue,
    urAfterHalt,
    urAfterAbort
  );

  TUnreachableCodeItem = record
    FileName: string;
    UnitName: string;
    Line: Integer;
    Column: Integer;
    Reason: TUnreachableReason;
    TerminatorLine: Integer;
    CodePreview: string;
    function ReasonText: string;
  end;

  TUnreachableCodeScanner = class
  private
    FItems: TList<TUnreachableCodeItem>;
    FOnProgress: TNotifyEvent;
    FProgressUnit: string;
    FProjectDefines: TStringList;
    procedure ScanUnit( const FileName: string );
    procedure ScanSource( const Source, FileName, UnitName: string );
    function GetCodePreview( const Source: string; StartPos: Integer ): string;
    function SkipWhitespaceAndComments( const Source: string; StartPos: Integer ): Integer;
    function SkipWhitespaceAndCommentsBackward( const Source: string; StartPos: Integer ): Integer;
    function IsConditionalTerminator( const Source: string; TerminatorPos: Integer ): Boolean;
    function GetLineNumber( const Source: string; Position: Integer ): Integer;
    function IsDefineDefined( const DefineName: string ): Boolean;
    function EvaluateIfCondition( const Condition: string ): Integer;  // 1=true, 0=false, -1=unknown
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure ScanProject( const Project: IOTAProject );
    procedure ScanFile( const FileName: string );
    function GetItems: TArray<TUnreachableCodeItem>;
    property OnProgress: TNotifyEvent read FOnProgress write FOnProgress;
    property ProgressUnit: string read FProgressUnit;
  end;

  TUnreachableCodeDetectorPlugin = class( TPluginConfig )
  private
    FEnabled: Boolean;
    FMenuItem: TMenuItem;
    procedure MenuItemClick( Sender: TObject );
  protected
    function GetOptionPages: TTreePage; override;
    procedure Init; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ShowUnreachableCodeDetector;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

procedure InitPlugin( Unload: Boolean );

var
  UnreachableCodeDetectorPlugin: TUnreachableCodeDetectorPlugin;

implementation

uses
  Forms, Controls, Variants, ToolsAPIHelpers, AppConsts,
  FrmUnreachableCodeDetector, FrmeOptionPageUnreachableCode;

const
  // Control flow terminators
  Terminators: array[0..5] of record
    Keyword: string;
    Reason: TUnreachableReason;
  end = (
    ( Keyword: 'exit'; Reason: urAfterExit ),
    ( Keyword: 'raise'; Reason: urAfterRaise ),
    ( Keyword: 'break'; Reason: urAfterBreak ),
    ( Keyword: 'continue'; Reason: urAfterContinue ),
    ( Keyword: 'halt'; Reason: urAfterHalt ),
    ( Keyword: 'abort'; Reason: urAfterAbort )
  );

{ TUnreachableCodeItem }

function TUnreachableCodeItem.ReasonText: string;
begin

  case Reason of
    urAfterExit:     Result := 'After Exit';
    urAfterRaise:    Result := 'After Raise';
    urAfterBreak:    Result := 'After Break';
    urAfterContinue: Result := 'After Continue';
    urAfterHalt:     Result := 'After Halt';
    urAfterAbort:    Result := 'After Abort';
  else
    Result := 'Unknown';
  end;

end;

{ TUnreachableCodeScanner }

constructor TUnreachableCodeScanner.Create;
begin

  inherited Create;
  FItems          := TList<TUnreachableCodeItem>.Create;
  FProjectDefines := TStringList.Create;
  FProjectDefines.CaseSensitive := False;
  FProjectDefines.Sorted        := True;
  FProjectDefines.Duplicates    := dupIgnore;

end;

destructor TUnreachableCodeScanner.Destroy;
begin

  FProjectDefines.Free;
  FItems.Free;
  inherited Destroy;

end;

procedure TUnreachableCodeScanner.Clear;
begin

  FItems.Clear;

end;

function TUnreachableCodeScanner.IsDefineDefined( const DefineName: string ): Boolean;
begin

  Result := FProjectDefines.IndexOf( DefineName ) >= 0;

end;

function TUnreachableCodeScanner.EvaluateIfCondition( const Condition: string ): Integer;
var
  TrimmedCond: string;
  DefName: string;
  P1, P2: Integer;
  InnerResult: Integer;
  IsNot: Boolean;
begin

  // Returns: 1 = true (scan block), 0 = false (skip block), -1 = unknown (skip block to be safe)
  TrimmedCond := Trim( Condition );

  if TrimmedCond = '' then
  begin
    Result := -1;
    Exit;
  end;

  // Handle NOT prefix
  IsNot := False;

  if SameText( Copy( TrimmedCond, 1, 4 ), 'NOT ' ) then
  begin
    IsNot       := True;
    TrimmedCond := Trim( Copy( TrimmedCond, 5, MaxInt ) );
  end;

  // Handle Defined(X)
  if SameText( Copy( TrimmedCond, 1, 8 ), 'Defined(' ) then
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

      if IsNot then
        InnerResult := 1 - InnerResult;

      Result := InnerResult;
      Exit;
    end;
  end;

  // Handle simple define name (like {$IF MyDefine})
  if ( Pos( '(', TrimmedCond ) = 0 ) and ( Pos( ' ', TrimmedCond ) = 0 ) then
  begin

    if IsDefineDefined( TrimmedCond ) then
      InnerResult := 1
    else
      InnerResult := 0;

    if IsNot then
      InnerResult := 1 - InnerResult;

    Result := InnerResult;
    Exit;
  end;

  // Complex expression - can't evaluate, skip to be safe
  Result := -1;

end;

function TUnreachableCodeScanner.GetLineNumber( const Source: string; Position: Integer ): Integer;
var
  I: Integer;
begin

  Result := 1;

  for I := 1 to Position - 1 do
  begin

    if I <= Length( Source ) then
    begin

      if Source[ I ] = #10 then
        Inc( Result )
      else if ( Source[ I ] = #13 ) and ( I < Length( Source ) ) and ( Source[ I + 1 ] <> #10 ) then
        Inc( Result );
    end;
  end;

end;

function TUnreachableCodeScanner.SkipWhitespaceAndComments( const Source: string; StartPos: Integer ): Integer;
var
  I, Len: Integer;
begin

  I   := StartPos;
  Len := Length( Source );

  while I <= Len do
  begin
    // Skip whitespace
    while ( I <= Len ) and CharInSet( Source[ I ], [ ' ', #9, #10, #13 ] ) do
      Inc( I );

    if I > Len then
      Break;

    // Skip brace comments
    if Source[ I ] = '{' then
    begin

      while ( I <= Len ) and ( Source[ I ] <> '}' ) do
        Inc( I );

      if I <= Len then
        Inc( I );

      Continue;
    end;

    // Skip paren comments
    if ( I < Len ) and ( Source[ I ] = '(' ) and ( Source[ I + 1 ] = '*' ) then
    begin
      Inc( I, 2 );

      while ( I < Len ) and not ( ( Source[ I ] = '*' ) and ( Source[ I + 1 ] = ')' ) ) do
        Inc( I );

      if I < Len then
        Inc( I, 2 );

      Continue;
    end;

    // Skip line comments
    if ( I < Len ) and ( Source[ I ] = '/' ) and ( Source[ I + 1 ] = '/' ) then
    begin

      while ( I <= Len ) and ( Source[ I ] <> #10 ) and ( Source[ I ] <> #13 ) do
        Inc( I );

      Continue;
    end;

    // Not whitespace or comment
    Break;
  end;

  Result := I;

end;

function TUnreachableCodeScanner.SkipWhitespaceAndCommentsBackward( const Source: string; StartPos: Integer ): Integer;
var
  I: Integer;
begin

  I := StartPos;

  while I >= 1 do
  begin
    // Skip whitespace backward
    while ( I >= 1 ) and CharInSet( Source[ I ], [ ' ', #9, #10, #13 ] ) do
      Dec( I );

    if I < 1 then
      Break;

    // Skip brace comments backward (find opening brace)
    if Source[ I ] = '}' then
    begin
      Dec( I );

      while ( I >= 1 ) and ( Source[ I ] <> '{' ) do
        Dec( I );

      if I >= 1 then
        Dec( I );

      Continue;
    end;

    // Skip paren comments backward
    if ( I > 1 ) and ( Source[ I ] = ')' ) and ( Source[ I - 1 ] = '*' ) then
    begin
      Dec( I, 2 );

      while ( I > 1 ) and not ( ( Source[ I ] = '*' ) and ( Source[ I - 1 ] = '(' ) ) do
        Dec( I );

      if I > 1 then
        Dec( I, 2 );

      Continue;
    end;

    // Skip line comments backward - find start of line and check for //
    // This is complex, so we'll just stop at // for now
    if ( I > 1 ) and ( Source[ I ] = '/' ) and ( Source[ I - 1 ] = '/' ) then
    begin
      Dec( I, 2 );
      Continue;
    end;

    // Not whitespace or comment
    Break;
  end;

  Result := I;

end;

function TUnreachableCodeScanner.IsConditionalTerminator( const Source: string; TerminatorPos: Integer ): Boolean;
var
  I: Integer;
  WordEnd, WordStart: Integer;
  PrevWord: string;
begin

  // Check if this terminator is a single statement after 'then' (conditional)
  // Pattern: "if condition then Exit;" - the Exit is conditional, not unconditional
  // We need to scan backward to see if 'then' precedes this terminator

  Result := False;

  // Skip backward past whitespace and comments before the terminator
  I := SkipWhitespaceAndCommentsBackward( Source, TerminatorPos - 1 );

  if I < 1 then
    Exit;

  // Check if previous token is 'then'
  // First, find the end of the previous word/token
  WordEnd := I;

  // If we're at a non-alpha char, it's not 'then'
  if not CharInSet( Source[ WordEnd ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) then
    Exit;

  // Find the start of this word
  WordStart := WordEnd;

  while ( WordStart > 1 ) and CharInSet( Source[ WordStart - 1 ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) do
    Dec( WordStart );

  PrevWord := Copy( Source, WordStart, WordEnd - WordStart + 1 );

  // Check if previous word is 'then'
  if SameText( PrevWord, 'then' ) then
    Result := True;

end;

function TUnreachableCodeScanner.GetCodePreview( const Source: string; StartPos: Integer ): string;
var
  EndPos, I: Integer;
begin

  // Get up to 50 characters of the code for preview
  EndPos := StartPos;
  I      := 0;

  while ( EndPos <= Length( Source ) ) and ( I < 50 ) do
  begin

    if CharInSet( Source[ EndPos ], [ #10, #13 ] ) then
      Break;

    Inc( EndPos );
    Inc( I );
  end;

  Result := Trim( Copy( Source, StartPos, EndPos - StartPos ) );

  if Length( Result ) >= 50 then
    Result := Result + '...';

end;

procedure TUnreachableCodeScanner.ScanSource( const Source, FileName, UnitName: string );
var
  I, Len, J, K: Integer;
  LowerSource: string;
  TerminatorPos: Integer;
  AfterSemicolon: Integer;
  NextPos: Integer;
  Item: TUnreachableCodeItem;
  FoundEnd: Boolean;
  ImplPos: Integer;
  IfNestLevel: Integer;
  DirectiveStart, DirectiveEnd: Integer;
  DirectiveContent: string;
  DefineName: string;
  ConditionStr: string;
  CondResult: Integer;
  ShouldScan: Boolean;
  CaseLabelEnd: Integer;
begin

  LowerSource := LowerCase( Source );
  Len         := Length( Source );

  // Find the 'implementation' keyword - skip the interface section
  // Interface section contains no executable code, only declarations
  ImplPos := Pos( 'implementation', LowerSource );

  if ImplPos > 0 then
    I := ImplPos + Length( 'implementation' )
  else
    I := 1;  // No implementation section found (e.g., .dpr file), scan from start

  while I <= Len do
  begin
    // Skip strings
    if Source[ I ] = '''' then
    begin
      // Check for triple-quoted string (Delphi 12+ multi-line strings)
      if ( I + 2 <= Len ) and ( Source[ I + 1 ] = '''' ) and ( Source[ I + 2 ] = '''' ) then
      begin
        // Triple-quoted string: skip until closing '''
        Inc( I, 3 );

        while I + 2 <= Len do
        begin
          if ( Source[ I ] = '''' ) and ( Source[ I + 1 ] = '''' ) and ( Source[ I + 2 ] = '''' ) then
          begin
            Inc( I, 3 );
            Break;
          end;

          Inc( I );
        end;

        Continue;
      end;

      // Regular string (handle escaped quotes - doubled single quotes like 'It''s')
      Inc( I );

      while I <= Len do
      begin
        if Source[ I ] = '''' then
        begin
          // Check for escaped quote (doubled single quote)
          if ( I < Len ) and ( Source[ I + 1 ] = '''' ) then
            Inc( I, 2 )  // Skip both quotes and continue in string
          else
          begin
            Inc( I );  // End of string
            Break;
          end;
        end
        else
          Inc( I );
      end;

      Continue;
    end;

    // Skip brace comments and handle conditional compilation directives
    if Source[ I ] = '{' then
    begin
      // Check for conditional compilation directives
      if ( I + 3 <= Len ) and ( Source[ I + 1 ] = '$' ) then
      begin
        // Extract the directive content
        DirectiveStart := I;
        DirectiveEnd   := I;

        while ( DirectiveEnd <= Len ) and ( Source[ DirectiveEnd ] <> '}' ) do
          Inc( DirectiveEnd );

        DirectiveContent := Copy( Source, DirectiveStart + 2, DirectiveEnd - DirectiveStart - 2 );  // Skip {$ and }

        // Check for {$IFDEF X}
        if SameText( Copy( DirectiveContent, 1, 6 ), 'IFDEF ' ) then
        begin
          DefineName  := Trim( Copy( DirectiveContent, 7, MaxInt ) );
          ShouldScan  := IsDefineDefined( DefineName );

          if ShouldScan then
          begin
            // Define IS defined - scan the block, just skip this directive
            I := DirectiveEnd + 1;
            Continue;
          end
          else
          begin
            // Define NOT defined - skip entire block to matching {$ENDIF}/{$ELSE}
            IfNestLevel := 1;
            I           := DirectiveEnd + 1;

            while ( I <= Len ) and ( IfNestLevel > 0 ) do
            begin

              if Source[ I ] = '{' then
              begin

                if ( I + 5 <= Len ) and ( Source[ I + 1 ] = '$' ) then
                begin
                  // Check for nested {$IF, {$IFDEF, {$IFNDEF
                  if ( UpCase( Source[ I + 2 ] ) = 'I' ) and ( UpCase( Source[ I + 3 ] ) = 'F' ) then
                    Inc( IfNestLevel )
                  // Check for {$ENDIF or {$IFEND
                  else if ( ( UpCase( Source[ I + 2 ] ) = 'E' ) and ( UpCase( Source[ I + 3 ] ) = 'N' ) and
                            ( UpCase( Source[ I + 4 ] ) = 'D' ) and ( UpCase( Source[ I + 5 ] ) = 'I' ) ) or
                          ( ( UpCase( Source[ I + 2 ] ) = 'I' ) and ( UpCase( Source[ I + 3 ] ) = 'F' ) and
                            ( UpCase( Source[ I + 4 ] ) = 'E' ) and ( UpCase( Source[ I + 5 ] ) = 'N' ) ) then
                    Dec( IfNestLevel )
                  // Check for {$ELSE at nest level 1 - switch to scanning
                  else if ( IfNestLevel = 1 ) and ( UpCase( Source[ I + 2 ] ) = 'E' ) and
                          ( UpCase( Source[ I + 3 ] ) = 'L' ) and ( UpCase( Source[ I + 4 ] ) = 'S' ) and
                          ( UpCase( Source[ I + 5 ] ) = 'E' ) then
                  begin
                    // Skip to end of {$ELSE} and start scanning
                    while ( I <= Len ) and ( Source[ I ] <> '}' ) do
                      Inc( I );

                    if I <= Len then
                      Inc( I );

                    Break;  // Exit the skip loop, continue scanning
                  end;
                end;

                // Skip to end of this directive
                while ( I <= Len ) and ( Source[ I ] <> '}' ) do
                  Inc( I );

                if I <= Len then
                  Inc( I );
              end
              else
                Inc( I );
            end;

            Continue;
          end;
        end

        // Check for {$IFNDEF X}
        else if SameText( Copy( DirectiveContent, 1, 7 ), 'IFNDEF ' ) then
        begin
          DefineName := Trim( Copy( DirectiveContent, 8, MaxInt ) );
          ShouldScan := not IsDefineDefined( DefineName );

          if ShouldScan then
          begin
            // Define NOT defined - scan the block, just skip this directive
            I := DirectiveEnd + 1;
            Continue;
          end
          else
          begin
            // Define IS defined - skip entire block to matching {$ENDIF}/{$ELSE}
            IfNestLevel := 1;
            I           := DirectiveEnd + 1;

            while ( I <= Len ) and ( IfNestLevel > 0 ) do
            begin

              if Source[ I ] = '{' then
              begin

                if ( I + 5 <= Len ) and ( Source[ I + 1 ] = '$' ) then
                begin

                  if ( UpCase( Source[ I + 2 ] ) = 'I' ) and ( UpCase( Source[ I + 3 ] ) = 'F' ) then
                    Inc( IfNestLevel )
                  else if ( ( UpCase( Source[ I + 2 ] ) = 'E' ) and ( UpCase( Source[ I + 3 ] ) = 'N' ) and
                            ( UpCase( Source[ I + 4 ] ) = 'D' ) and ( UpCase( Source[ I + 5 ] ) = 'I' ) ) or
                          ( ( UpCase( Source[ I + 2 ] ) = 'I' ) and ( UpCase( Source[ I + 3 ] ) = 'F' ) and
                            ( UpCase( Source[ I + 4 ] ) = 'E' ) and ( UpCase( Source[ I + 5 ] ) = 'N' ) ) then
                    Dec( IfNestLevel )
                  else if ( IfNestLevel = 1 ) and ( UpCase( Source[ I + 2 ] ) = 'E' ) and
                          ( UpCase( Source[ I + 3 ] ) = 'L' ) and ( UpCase( Source[ I + 4 ] ) = 'S' ) and
                          ( UpCase( Source[ I + 5 ] ) = 'E' ) then
                  begin

                    while ( I <= Len ) and ( Source[ I ] <> '}' ) do
                      Inc( I );

                    if I <= Len then
                      Inc( I );

                    Break;
                  end;
                end;

                while ( I <= Len ) and ( Source[ I ] <> '}' ) do
                  Inc( I );

                if I <= Len then
                  Inc( I );
              end
              else
                Inc( I );
            end;

            Continue;
          end;
        end

        // Check for {$IF condition}
        else if SameText( Copy( DirectiveContent, 1, 3 ), 'IF ' ) then
        begin
          ConditionStr := Trim( Copy( DirectiveContent, 4, MaxInt ) );
          CondResult   := EvaluateIfCondition( ConditionStr );

          if CondResult = 1 then
          begin
            // Condition is TRUE - scan the block
            I := DirectiveEnd + 1;
            Continue;
          end
          else
          begin
            // Condition is FALSE or UNKNOWN - skip the block
            IfNestLevel := 1;
            I           := DirectiveEnd + 1;

            while ( I <= Len ) and ( IfNestLevel > 0 ) do
            begin

              if Source[ I ] = '{' then
              begin

                if ( I + 5 <= Len ) and ( Source[ I + 1 ] = '$' ) then
                begin

                  if ( UpCase( Source[ I + 2 ] ) = 'I' ) and ( UpCase( Source[ I + 3 ] ) = 'F' ) then
                    Inc( IfNestLevel )
                  else if ( ( UpCase( Source[ I + 2 ] ) = 'E' ) and ( UpCase( Source[ I + 3 ] ) = 'N' ) and
                            ( UpCase( Source[ I + 4 ] ) = 'D' ) and ( UpCase( Source[ I + 5 ] ) = 'I' ) ) or
                          ( ( UpCase( Source[ I + 2 ] ) = 'I' ) and ( UpCase( Source[ I + 3 ] ) = 'F' ) and
                            ( UpCase( Source[ I + 4 ] ) = 'E' ) and ( UpCase( Source[ I + 5 ] ) = 'N' ) ) then
                    Dec( IfNestLevel )
                  else if ( IfNestLevel = 1 ) and ( UpCase( Source[ I + 2 ] ) = 'E' ) and
                          ( UpCase( Source[ I + 3 ] ) = 'L' ) and ( UpCase( Source[ I + 4 ] ) = 'S' ) and
                          ( UpCase( Source[ I + 5 ] ) = 'E' ) then
                  begin

                    while ( I <= Len ) and ( Source[ I ] <> '}' ) do
                      Inc( I );

                    if I <= Len then
                      Inc( I );

                    Break;
                  end;
                end;

                while ( I <= Len ) and ( Source[ I ] <> '}' ) do
                  Inc( I );

                if I <= Len then
                  Inc( I );
              end
              else
                Inc( I );
            end;

            Continue;
          end;
        end

        // Check for {$ENDIF} or {$IFEND} - just skip the directive
        else if SameText( Copy( DirectiveContent, 1, 5 ), 'ENDIF' ) or
                SameText( Copy( DirectiveContent, 1, 5 ), 'IFEND' ) then
        begin
          I := DirectiveEnd + 1;
          Continue;
        end

        // Check for {$ELSE} - need to skip to {$ENDIF} (we were scanning, now skip)
        else if SameText( Copy( DirectiveContent, 1, 4 ), 'ELSE' ) then
        begin
          // We were in a TRUE branch, now skip the ELSE branch
          IfNestLevel := 1;
          I           := DirectiveEnd + 1;

          while ( I <= Len ) and ( IfNestLevel > 0 ) do
          begin

            if Source[ I ] = '{' then
            begin

              if ( I + 5 <= Len ) and ( Source[ I + 1 ] = '$' ) then
              begin

                if ( UpCase( Source[ I + 2 ] ) = 'I' ) and ( UpCase( Source[ I + 3 ] ) = 'F' ) then
                  Inc( IfNestLevel )
                else if ( ( UpCase( Source[ I + 2 ] ) = 'E' ) and ( UpCase( Source[ I + 3 ] ) = 'N' ) and
                          ( UpCase( Source[ I + 4 ] ) = 'D' ) and ( UpCase( Source[ I + 5 ] ) = 'I' ) ) or
                        ( ( UpCase( Source[ I + 2 ] ) = 'I' ) and ( UpCase( Source[ I + 3 ] ) = 'F' ) and
                          ( UpCase( Source[ I + 4 ] ) = 'E' ) and ( UpCase( Source[ I + 5 ] ) = 'N' ) ) then
                  Dec( IfNestLevel );
              end;

              while ( I <= Len ) and ( Source[ I ] <> '}' ) do
                Inc( I );

              if I <= Len then
                Inc( I );
            end
            else
              Inc( I );
          end;

          Continue;
        end;
      end;

      // Regular brace comment or other directive - skip to closing brace
      while ( I <= Len ) and ( Source[ I ] <> '}' ) do
        Inc( I );

      if I <= Len then
        Inc( I );

      Continue;
    end;

    // Skip paren comments
    if ( I < Len ) and ( Source[ I ] = '(' ) and ( Source[ I + 1 ] = '*' ) then
    begin
      Inc( I, 2 );

      while ( I < Len ) and not ( ( Source[ I ] = '*' ) and ( Source[ I + 1 ] = ')' ) ) do
        Inc( I );

      if I < Len then
        Inc( I, 2 );

      Continue;
    end;

    // Skip line comments
    if ( I < Len ) and ( Source[ I ] = '/' ) and ( Source[ I + 1 ] = '/' ) then
    begin

      while ( I <= Len ) and ( Source[ I ] <> #10 ) do
        Inc( I );

      Continue;
    end;

    // Check for terminators
    for J := Low( Terminators ) to High( Terminators ) do
    begin

      if ( I + Length( Terminators[ J ].Keyword ) - 1 <= Len ) and
         ( Copy( LowerSource, I, Length( Terminators[ J ].Keyword ) ) = Terminators[ J ].Keyword ) then
      begin
        // Check it's a whole word
        if ( I > 1 ) and CharInSet( Source[ I - 1 ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) then
          Continue;

        K := I + Length( Terminators[ J ].Keyword );

        if ( K <= Len ) and CharInSet( Source[ K ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) then
          Continue;

        // Check if this is actually a variable, not a control flow statement
        // Case 1: Assignment target - "Continue := False"
        while ( K <= Len ) and CharInSet( Source[ K ], [ ' ', #9 ] ) do
          Inc( K );

        if ( K < Len ) and ( Source[ K ] = ':' ) and ( Source[ K + 1 ] = '=' ) then
          Continue;  // It's a variable assignment, skip it

        // Case 2: Used as value/parameter - "X := Continue" or "Func(Continue)" or "Func(A, Continue)"
        // Check character before the keyword (skip whitespace backwards)
        K := I - 1;
        while ( K >= 1 ) and CharInSet( Source[ K ], [ ' ', #9 ] ) do
          Dec( K );

        if ( K >= 1 ) and CharInSet( Source[ K ], [ '=', '(', ',' ] ) then
          Continue;  // It's being used as a value/parameter, skip it

        // Case 3: Parameter declaration - "var Continue" or "const Continue" or "out Continue"
        // Check if preceded by 'var ', 'const ', or 'out '
        if ( K >= 3 ) and SameText( Copy( Source, K - 2, 3 ), 'var' ) and
           ( ( K < 4 ) or not CharInSet( Source[ K - 3 ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) ) then
          Continue;  // It's a parameter declaration, skip it

        if ( K >= 5 ) and SameText( Copy( Source, K - 4, 5 ), 'const' ) and
           ( ( K < 6 ) or not CharInSet( Source[ K - 5 ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) ) then
          Continue;  // It's a parameter declaration, skip it

        if ( K >= 3 ) and SameText( Copy( Source, K - 2, 3 ), 'out' ) and
           ( ( K < 4 ) or not CharInSet( Source[ K - 3 ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) ) then
          Continue;  // It's a parameter declaration, skip it

        // Found a terminator keyword
        TerminatorPos := I;

        // Check if this is a conditional terminator (after 'then')
        // e.g., "if condition then Exit;" - the code after is reachable
        if IsConditionalTerminator( Source, TerminatorPos ) then
        begin
          Inc( I );
          Continue;
        end;

        // Find the semicolon after the terminator statement
        K := I + Length( Terminators[ J ].Keyword );

        // For 'raise', we need to skip the exception expression
        // For 'exit', we need to handle Exit(value)
        // For others, we just find the semicolon
        while K <= Len do
        begin
          // Skip triple-quoted strings
          if ( K + 2 <= Len ) and ( Source[ K ] = '''' ) and ( Source[ K + 1 ] = '''' ) and ( Source[ K + 2 ] = '''' ) then
          begin
            Inc( K, 3 );

            while K + 2 <= Len do
            begin
              if ( Source[ K ] = '''' ) and ( Source[ K + 1 ] = '''' ) and ( Source[ K + 2 ] = '''' ) then
              begin
                Inc( K, 3 );
                Break;
              end;

              Inc( K );
            end;

            Continue;
          end;

          // Skip regular strings (with escaped quote handling)
          if Source[ K ] = '''' then
          begin
            Inc( K );

            while K <= Len do
            begin
              if Source[ K ] = '''' then
              begin
                if ( K < Len ) and ( Source[ K + 1 ] = '''' ) then
                  Inc( K, 2 )
                else
                begin
                  Inc( K );
                  Break;
                end;
              end
              else
                Inc( K );
            end;

            Continue;
          end;

          if Source[ K ] = ';' then
            Break;

          Inc( K );
        end;

        if K > Len then
        begin
          Inc( I );
          Continue;
        end;

        AfterSemicolon := K + 1;

        // Skip whitespace and comments after semicolon
        NextPos := SkipWhitespaceAndComments( Source, AfterSemicolon );

        if NextPos > Len then
        begin
          Inc( I );
          Continue;
        end;

        // Check if next thing is 'end', 'else', 'except', 'finally', 'until', or end of file
        FoundEnd := False;

        if ( NextPos + 2 <= Len ) and SameText( Copy( Source, NextPos, 3 ), 'end' ) and
           ( ( NextPos + 3 > Len ) or not CharInSet( Source[ NextPos + 3 ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) ) then
          FoundEnd := True
        else if ( NextPos + 3 <= Len ) and SameText( Copy( Source, NextPos, 4 ), 'else' ) and
           ( ( NextPos + 4 > Len ) or not CharInSet( Source[ NextPos + 4 ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) ) then
          FoundEnd := True
        else if ( NextPos + 5 <= Len ) and SameText( Copy( Source, NextPos, 6 ), 'except' ) and
           ( ( NextPos + 6 > Len ) or not CharInSet( Source[ NextPos + 6 ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) ) then
          FoundEnd := True
        else if ( NextPos + 6 <= Len ) and SameText( Copy( Source, NextPos, 7 ), 'finally' ) and
           ( ( NextPos + 7 > Len ) or not CharInSet( Source[ NextPos + 7 ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) ) then
          FoundEnd := True
        else if ( NextPos + 4 <= Len ) and SameText( Copy( Source, NextPos, 5 ), 'until' ) and
           ( ( NextPos + 5 > Len ) or not CharInSet( Source[ NextPos + 5 ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) ) then
          FoundEnd := True;

        // Check for case label (e.g., "1:", "mrOK:", "'A':") - indicates we're in a case statement
        if not FoundEnd then
        begin
          CaseLabelEnd := NextPos;

          // Skip number, identifier, or char literal
          if CharInSet( Source[ CaseLabelEnd ], [ '0'..'9' ] ) then
          begin
            // Number (could be part of range like 1..5)
            while ( CaseLabelEnd <= Len ) and CharInSet( Source[ CaseLabelEnd ], [ '0'..'9', '.', '$' ] ) do
              Inc( CaseLabelEnd );
          end
          else if CharInSet( Source[ CaseLabelEnd ], [ 'A'..'Z', 'a'..'z', '_' ] ) then
          begin
            // Identifier
            while ( CaseLabelEnd <= Len ) and CharInSet( Source[ CaseLabelEnd ], [ 'A'..'Z', 'a'..'z', '0'..'9', '_' ] ) do
              Inc( CaseLabelEnd );
          end
          else if Source[ CaseLabelEnd ] = '''' then
          begin
            // Character literal
            Inc( CaseLabelEnd );

            while ( CaseLabelEnd <= Len ) and ( Source[ CaseLabelEnd ] <> '''' ) do
              Inc( CaseLabelEnd );

            if CaseLabelEnd <= Len then
              Inc( CaseLabelEnd );
          end;

          // Skip whitespace
          while ( CaseLabelEnd <= Len ) and CharInSet( Source[ CaseLabelEnd ], [ ' ', #9 ] ) do
            Inc( CaseLabelEnd );

          // Check for colon (but not :=)
          if ( CaseLabelEnd <= Len ) and ( Source[ CaseLabelEnd ] = ':' ) and
             ( ( CaseLabelEnd >= Len ) or ( Source[ CaseLabelEnd + 1 ] <> '=' ) ) then
            FoundEnd := True;  // It's a case label - the Exit was inside a case branch
        end;

        if not FoundEnd then
        begin
          // Found unreachable code!
          Item.FileName       := FileName;
          Item.UnitName       := UnitName;
          Item.Line           := GetLineNumber( Source, NextPos );
          Item.Column         := 1;
          Item.Reason         := Terminators[ J ].Reason;
          Item.TerminatorLine := GetLineNumber( Source, TerminatorPos );
          Item.CodePreview    := GetCodePreview( Source, NextPos );

          FItems.Add( Item );
        end;

        // Move past this terminator
        I := K;
        Break;
      end;
    end;

    Inc( I );
  end;

end;

procedure TUnreachableCodeScanner.ScanUnit( const FileName: string );
var
  SL: TStringList;
  UnitName: string;
begin

  if not FileExists( FileName ) then
    Exit;

  UnitName      := ChangeFileExt( ExtractFileName( FileName ), '' );
  FProgressUnit := UnitName;

  if Assigned( FOnProgress ) then
    FOnProgress( Self );

  SL := TStringList.Create;

  try
    SL.LoadFromFile( FileName );
    ScanSource( SL.Text, FileName, UnitName );
  finally
    SL.Free;
  end;

end;

procedure TUnreachableCodeScanner.ScanProject( const Project: IOTAProject );
var
  I: Integer;
  ModuleInfo: IOTAModuleInfo;
  FileName: string;
  ProjectOptions: IOTAProjectOptions;
  DefinesStr: string;
  DefinesList: TStringList;
begin

  if Project = nil then
    Exit;

  Clear;
  FProjectDefines.Clear;

  // Get project conditional defines
  ProjectOptions := Project.ProjectOptions;

  if ProjectOptions <> nil then
  begin
    DefinesStr := VarToStrDef( ProjectOptions.Values[ 'Defines' ], '' );

    if DefinesStr <> '' then
    begin
      DefinesList := TStringList.Create;

      try
        DefinesList.Delimiter       := ';';
        DefinesList.StrictDelimiter := True;
        DefinesList.DelimitedText   := DefinesStr;

        for I := 0 to DefinesList.Count - 1 do
        begin

          if Trim( DefinesList[ I ] ) <> '' then
            FProjectDefines.Add( Trim( DefinesList[ I ] ) );
        end;
      finally
        DefinesList.Free;
      end;
    end;
  end;

  for I := 0 to Project.GetModuleCount - 1 do
  begin
    ModuleInfo := Project.GetModule( I );
    FileName   := ModuleInfo.FileName;

    if SameText( ExtractFileExt( FileName ), '.pas' ) then
      ScanUnit( FileName );
  end;

end;

procedure TUnreachableCodeScanner.ScanFile( const FileName: string );
begin

  Clear;
  ScanUnit( FileName );

end;

function TUnreachableCodeScanner.GetItems: TArray<TUnreachableCodeItem>;
begin

  Result := FItems.ToArray;

end;

{ TUnreachableCodeDetectorPlugin }

constructor TUnreachableCodeDetectorPlugin.Create;
begin

  inherited Create( AppDataDirectory + '\UnreachableCodeDetector.xml', 'UnreachableCodeDetector' );

  // Add menu item under DDevExtensions submenu
  if DDevExtensionsMenu <> nil then
  begin
    FMenuItem         := TMenuItem.Create( DDevExtensionsMenu );
    FMenuItem.Caption := 'Unreachable Code Detector...';
    FMenuItem.OnClick := MenuItemClick;
    DDevExtensionsMenu.Add( FMenuItem );
  end;

end;

destructor TUnreachableCodeDetectorPlugin.Destroy;
begin

  FreeAndNil( FMenuItem );
  inherited Destroy;

end;

procedure TUnreachableCodeDetectorPlugin.Init;
begin

  FEnabled := True;

end;

function TUnreachableCodeDetectorPlugin.GetOptionPages: TTreePage;
begin

  Result := TTreePage.Create( 'Unreachable Code', TFrameOptionPageUnreachableCode, Self );

end;

procedure TUnreachableCodeDetectorPlugin.MenuItemClick( Sender: TObject );
begin

  ShowUnreachableCodeDetector;

end;

procedure TUnreachableCodeDetectorPlugin.ShowUnreachableCodeDetector;
begin

  TFormUnreachableCodeDetector.Execute;

end;

procedure InitPlugin( Unload: Boolean );
begin

  if not Unload then
    UnreachableCodeDetectorPlugin := TUnreachableCodeDetectorPlugin.Create
  else
  begin
    UnreachableCodeDetectorPlugin.Free;
    UnreachableCodeDetectorPlugin := nil;
  end;

end;

end.
