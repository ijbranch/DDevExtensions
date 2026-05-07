{******************************************************************************}
{*                                                                            *}
{* DDevExtensions                                                             *}
{*                                                                            *}
{* (C) 2006-2024 Andreas Hausladen                                            *}
{*                                                                            *}
{******************************************************************************}

unit UnitMetrics;

/// <summary>
/// Calculates basic source-code metrics for a single Delphi unit. The metrics are used by
/// the Build Statistics dialog to summarise lines of code and cyclomatic complexity per
/// unit after a successful compile.
/// </summary>

{$I ..\DelphiExtension.inc}

interface

type
  /// <summary>
  /// Aggregated metrics for a single Delphi unit.
  /// </summary>
  TUnitMetrics = record
    /// <summary>Number of source lines that contain non-comment, non-directive tokens.</summary>
    LinesOfCode: Integer;
    /// <summary>Cyclomatic complexity ( base 1 plus one per control-flow branch ).</summary>
    CyclomaticComplexity: Integer;
  end;

/// <summary>
/// Computes lines of code and cyclomatic complexity for the supplied Delphi unit by
/// running the file through TDelphiLexer and counting branching tokens.
/// </summary>
/// <param name="FileName">Absolute path to the .pas file to analyse.</param>
/// <returns>Populated TUnitMetrics; returns zero values when the file cannot be loaded.</returns>
function CalculateUnitMetrics(const FileName: string): TUnitMetrics;

implementation

uses
  SysUtils, Classes, DelphiLexer;

function CalculateUnitMetrics(const FileName: string): TUnitMetrics;
var
  Lexer: TDelphiLexer;
  Token: TToken;
  Content: UTF8String;
  CodeLines: array of Boolean;
  MaxLine: Integer;
  I: Integer;
  InCaseStatement: Boolean;
  CaseDepth: Integer;
begin
  Result.LinesOfCode := 0;
  Result.CyclomaticComplexity := 1; // Base complexity

  if not FileExists(FileName) then
    Exit;

  try
    Content := LoadTextFileToUtf8String(FileName);
  except
    Exit;
  end;

  if Content = '' then
    Exit;

  Lexer := TDelphiLexer.Create(FileName, Content);
  try
    MaxLine := 0;
    InCaseStatement := False;
    CaseDepth := 0;

    // First pass: find max line and calculate complexity
    while Lexer.NextToken(Token) do
    begin
      // Track max line for LOC calculation
      if Token.Line > MaxLine then
        MaxLine := Token.Line;

      // Skip comments and directives for LOC
      if not (Token.Kind in [tkComment, tkDirective]) then
      begin
        // Ensure array is large enough
        if Token.Line >= Length(CodeLines) then
          SetLength(CodeLines, Token.Line + 100);

        CodeLines[Token.Line] := True;
      end;

      // Calculate cyclomatic complexity
      case Token.Kind of
        tkI_if:
          Inc(Result.CyclomaticComplexity);

        tkI_while:
          Inc(Result.CyclomaticComplexity);

        tkI_for:
          Inc(Result.CyclomaticComplexity);

        tkI_repeat:
          Inc(Result.CyclomaticComplexity);

        tkI_except:
          Inc(Result.CyclomaticComplexity);

        tkI_and:
          Inc(Result.CyclomaticComplexity);

        tkI_or:
          Inc(Result.CyclomaticComplexity);

        tkI_case:
          begin
            InCaseStatement := True;
            CaseDepth := 1;
          end;

        tkI_end:
          begin
            if InCaseStatement then
            begin
              Dec(CaseDepth);
              if CaseDepth <= 0 then
                InCaseStatement := False;
            end;
          end;

        tkI_begin, tkI_try:
          begin
            if InCaseStatement then
              Inc(CaseDepth);
          end;

        tkColon:
          begin
            // Count case labels (colon after case value, not in declarations)
            if InCaseStatement and (CaseDepth = 1) then
              Inc(Result.CyclomaticComplexity);
          end;
      end;
    end;

    // Count lines with code
    for I := 0 to Length(CodeLines) - 1 do
    begin
      if CodeLines[I] then
        Inc(Result.LinesOfCode);
    end;

  finally
    Lexer.Free;
  end;
end;

end.
