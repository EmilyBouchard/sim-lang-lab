# Top-level orchestrator (Windows/PowerShell). Mirrors build.sh.
#   .\build.ps1 <cpp|csharp|haskell|all> [apps/<name>] [-Test] [-Run]
# -Test  run the headless smoke test after building
# -Run   run the app normally (opens a real window; Esc or close to quit)
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('cpp', 'csharp', 'haskell', 'all')]
    [string]$Lang = 'all',

    [Parameter(Position = 1)]
    [string]$Target = '',

    [switch]$Test,
    [switch]$Run
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$App = $Target -replace '^apps[/\\]', ''   # e.g. hello-window ("" = everything)
$SmokeApp = if ($App) { $App } else { 'hello-window' }

# Run a native command and fail the script if it returns a non-zero exit code.
function Invoke-Native {
    param([Parameter(Mandatory)][string]$Command, [string[]]$Arguments = @())
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "'$Command $($Arguments -join ' ')' failed with exit code $LASTEXITCODE"
    }
}

# Run a script block with the headless SDL drivers set, restoring the environment afterwards.
function Invoke-Headless {
    param([Parameter(Mandatory)][scriptblock]$Block)
    $oldVideo = $env:SDL_VIDEO_DRIVER
    $oldRender = $env:SDL_RENDER_DRIVER
    $env:SDL_VIDEO_DRIVER = 'dummy'
    $env:SDL_RENDER_DRIVER = 'software'
    try { & $Block }
    finally {
        $env:SDL_VIDEO_DRIVER = $oldVideo
        $env:SDL_RENDER_DRIVER = $oldRender
    }
}

# hello-window -> HelloWindow
function ConvertTo-Pascal([string]$Name) {
    ($Name -split '-' | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ''
}

function Build-Cpp {
    Push-Location (Join-Path $Root 'cpp')
    try {
        Invoke-Native cmake @('--preset', 'debug')
        $buildArgs = @('--build', '--preset', 'debug')
        if ($App) { $buildArgs += @('--target', $App) }
        Invoke-Native cmake $buildArgs
        if ($Test) { Invoke-Native ctest @('--preset', 'debug') }
        if ($Run) { Invoke-Native (Join-Path "build/debug/apps/$SmokeApp" "$SmokeApp.exe") }
    }
    finally { Pop-Location }
}

function Build-Csharp {
    Push-Location (Join-Path $Root 'csharp')
    try {
        $proj = if ($App) { $p = ConvertTo-Pascal $App; "Apps/$p/$p.csproj" } else { 'SimLangLab.sln' }
        Invoke-Native dotnet @('build', $proj, '--nologo', '-v', 'q')
        $runProj = "Apps/$(ConvertTo-Pascal $SmokeApp)"
        if ($Test) {
            Invoke-Headless { Invoke-Native dotnet @('run', '--project', $runProj, '--no-build', '--', '--frames', '5') }
        }
        if ($Run) { Invoke-Native dotnet @('run', '--project', $runProj, '--no-build') }
    }
    finally { Pop-Location }
}

function Build-Haskell {
    Push-Location (Join-Path $Root 'haskell')
    try {
        Invoke-Native cabal @('build', $(if ($App) { $App } else { 'all' }))
        if ($Test) {
            Invoke-Headless { Invoke-Native cabal @('run', '-v0', $SmokeApp, '--', '--frames', '5') }
        }
        if ($Run) { Invoke-Native cabal @('run', '-v0', $SmokeApp) }
    }
    finally { Pop-Location }
}

switch ($Lang) {
    'cpp'     { Build-Cpp }
    'csharp'  { Build-Csharp }
    'haskell' { Build-Haskell }
    'all'     { Build-Cpp; Build-Csharp; Build-Haskell }
}
