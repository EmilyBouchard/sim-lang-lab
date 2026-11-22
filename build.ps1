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
# Always sync submodules (vcpkg, sdl3-hs): offline and instant when already up to date.
$ErrorActionPreference = 'Continue'   # git reports progress on stderr; judge by exit code (PS 5.1)
git -C $Root submodule update --init
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) { throw 'git submodule update --init failed' }
# SDL3 comes from the pinned vcpkg install (see docs/architecture/dependencies.md).
& (Join-Path $Root 'scripts/setup-deps.ps1')
. (Join-Path $Root 'scripts/env.ps1')

$SmokeApp = if ($App) { $App } else { 'hello-window' }

# Run a native command and fail the script if it returns a non-zero exit code.
function Invoke-Native {
    param([Parameter(Mandatory)][string]$Command, [string[]]$Arguments = @())
    # Windows PowerShell 5.1 turns native stderr output into a terminating error under 'Stop';
    # judge success by the exit code instead.
    $ErrorActionPreference = 'Continue'
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

# Run the shared command-line contract test (scripts/check_hello_window_cli.py) against an app.
function Invoke-CliCheck {
    param([Parameter(Mandatory)][string[]]$Command)
    if ($SmokeApp -ne 'hello-window') { return }
    $py = Get-Command python, python3 -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $py) { throw 'Python 3 is required for -Test (command-line checks).' }
    Invoke-Native $py.Source (@('-I', (Join-Path $Root 'scripts/check_hello_window_cli.py'), '--') + $Command)
}

# hello-window -> HelloWindow
function ConvertTo-Pascal([string]$Name) {
    ($Name -split '-' | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ''
}

function Build-Cpp {
    # MSVC environment (cl, link, ASan runtime on PATH). vcvars also sets Platform=x64, which
    # MSBuild would pick up and change dotnet's output path, so restore the environment afterwards.
    $savedEnv = [Environment]::GetEnvironmentVariables('Process')
    . (Join-Path $Root 'scripts/vsenv.ps1')
    Push-Location (Join-Path $Root 'cpp')
    try {
        Invoke-Native cmake @('--preset', 'debug')
        $buildArgs = @('--build', '--preset', 'debug')
        if ($App) { $buildArgs += @('--target', $App) }
        Invoke-Native cmake $buildArgs
        if ($Test) { Invoke-Native ctest @('--preset', 'debug') }
        if ($Run) { Invoke-Native (Join-Path "build/debug/apps/$SmokeApp" "$SmokeApp.exe") }
    }
    finally {
        Pop-Location
        foreach ($name in @([Environment]::GetEnvironmentVariables('Process').Keys)) {
            if (-not $savedEnv.Contains($name)) { Remove-Item "env:$name" }
        }
        foreach ($name in $savedEnv.Keys) { Set-Item "env:$name" $savedEnv[$name] }
    }
}

function Build-Csharp {
    Push-Location (Join-Path $Root 'csharp')
    try {
        $proj = if ($App) { $p = ConvertTo-Pascal $App; "Apps/$p/$p.csproj" } else { 'SimLangLab.sln' }
        Invoke-Native dotnet @('build', $proj, '--nologo', '-v', 'q')
        $runProj = "Apps/$(ConvertTo-Pascal $SmokeApp)"
        if ($Test) {
            Invoke-Headless { Invoke-Native dotnet @('run', '--project', $runProj, '--no-build', '--', '--frames', '5') }
            Invoke-CliCheck @('dotnet', 'run', '--project', $runProj, '--no-build', '--')
        }
        if ($Run) { Invoke-Native dotnet @('run', '--project', $runProj, '--no-build') }
    }
    finally { Pop-Location }
}

function Build-Haskell {
    Push-Location (Join-Path $Root 'haskell')
    try {
        Invoke-Native cabal @('build', $(if ($App) { $App } else { 'all' }))
        # cabal has no post-build hook, so copy SDL3.dll next to each executable (the C++ build and the
        # C# project do the same). Then it runs by double-click or from a shell without the vcpkg setup.
        $apps = if ($App) { @($App) } else { @(Get-ChildItem (Join-Path $Root 'haskell/app') -Directory | ForEach-Object Name) }
        foreach ($name in $apps) {
            $bin = & { $ErrorActionPreference = 'Continue'; cabal list-bin "exe:$name" 2>$null } | Select-Object -Last 1
            if (-not $bin) { throw "cabal list-bin exe:$name returned nothing" }
            Copy-Item (Join-Path $env:SIM_VCPKG_PREFIX 'bin/SDL3.dll') (Split-Path -Parent $bin) -Force
        }
        if ($Test) {
            Invoke-Headless { Invoke-Native cabal @('run', '-v0', $SmokeApp, '--', '--frames', '5') }
            Invoke-CliCheck @('cabal', 'run', '-v0', $SmokeApp, '--')
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
