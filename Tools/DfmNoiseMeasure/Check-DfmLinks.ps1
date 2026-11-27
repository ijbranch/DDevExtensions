#Requires -PSEdition Core
<#
.SYNOPSIS
    Checks the links between modules in every .dfm of a set of repositories, today and through their history.

.DESCRIPTION
    Run by hand; nothing calls it.  Exports every .dfm change from the git history of each repository directly
    under -Root ( Export-DfmHistory.py ), then runs "DfmNoiseMeasure links", which:
      - checks every Module.Component link in today's text .dfm files has a target, and
      - runs the DFM Link Guard's rule over every past save and says which lost links are still lost today.
    Read-only on the repositories.  Writes links-today.csv and links-history.csv to -Out.
    Exit code: 0 nothing found, 3 something found, 1 a step could not run.  A past save that cannot be read is
    listed but does not change the exit code.

.PARAMETER Root
    One repository, or a folder whose first-level folders are the repositories.  Default: the DBiWorkflow
    development folder.

.PARAMETER Since
    Only history from this date ( YYYY-MM-DD ).  Default: all of it.

.PARAMETER Out
    Where the history export and the CSV files go.  Default: a dated folder under %TEMP%.

.EXAMPLE
    pwsh -File Check-DfmLinks.ps1
    pwsh -File Check-DfmLinks.ps1 -Root 'E:\DBiWorkflow Development' -Since 2026-01-01
#>
param(
    [string] $Root = 'E:\DBiWorkflow Development',
    [string] $Since = '',
    [string] $Out = ( Join-Path $env:TEMP ( 'DfmLinkCheck-' + ( Get-Date -Format 'yyyy-MM-dd-HHmm' ) ) )
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$exe = Join-Path $here 'bin\Win64\Release\DfmNoiseMeasure.exe'
if ( -not ( Test-Path $exe ) ) {
    Write-Host "DfmNoiseMeasure.exe is not built: build $here\DfmNoiseMeasure.dproj ( Win64 Release ) first."
    exit 1
}
if ( -not ( Test-Path $Root ) ) {
    Write-Host "No folder $Root"
    exit 1
}

if ( Test-Path ( Join-Path $Root '.git' ) ) {
    $repos = @( ( Resolve-Path $Root ).Path ) # the root is one repository ( GITLAKLib )
}
else {
    $repos = @( Get-ChildItem -Directory $Root | Where-Object { Test-Path ( Join-Path $_.FullName '.git' ) } | ForEach-Object FullName )
}
Write-Host "$( $repos.Count ) repositories under $Root; output in $Out"

$history = Join-Path $Out 'history'
if ( Test-Path $history ) { Remove-Item -Recurse -Force $history }
$exportArgs = @( ( Join-Path $here 'Export-DfmHistory.py' ), $history ) + $repos
if ( $Since ) { $exportArgs += @( '--since', $Since ) }
$exportLog = & python -I @exportArgs 2>&1
if ( $LASTEXITCODE -ne 0 ) {
    $exportLog | Write-Host
    Write-Host 'The history export failed.'
    exit 1
}
$exportLog | Select-Object -Last 1 | Write-Host

# Only the .dfm files git knows ( tracked, or new and not ignored ): a build's copies beside its DCUs are ignored
# files, and a stale copy could still declare a component deleted from the real form.
$list = Join-Path $Out 'dfm-files.txt'
$files = [System.Collections.Generic.List[string]]::new()
foreach ( $repo in $repos ) {
    # A failing native command does not stop pwsh: check each one, or an empty list would read as all clear.
    $listed = & git -C $repo -c core.quotePath=false ls-files --cached --others --exclude-standard -- '*.dfm'
    if ( $LASTEXITCODE -ne 0 ) {
        Write-Host "git ls-files failed in $repo"
        exit 1
    }
    foreach ( $name in @( $listed ) ) { if ( $name ) { $files.Add( ( Join-Path $repo ( $name -replace '/', '\' ) ) ) } }
}
if ( $files.Count -eq 0 ) {
    Write-Host "git knows no .dfm files under $Root"
    exit 1
}
$files | Set-Content -Encoding utf8NoBOM $list
Write-Host "$( $files.Count ) .dfm files known to git"

& $exe links $Root ( Join-Path $history 'pairs.tsv' ) --out $Out --files $list
exit $LASTEXITCODE
