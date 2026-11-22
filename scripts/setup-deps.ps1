# Fetch, bootstrap and run vcpkg to install the pinned SDL3 (see vcpkg.json). Windows/PowerShell.
# Idempotent: does nothing when vcpkg.json and the vcpkg checkout are unchanged.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'env.ps1')

function Invoke-Native {
    param([Parameter(Mandatory)][string]$Command, [string[]]$Arguments = @())
    # Windows PowerShell 5.1 turns native stderr output into a terminating error under 'Stop';
    # judge success by the exit code instead.
    $ErrorActionPreference = 'Continue'
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "'$Command $($Arguments -join ' ')' failed with exit code $LASTEXITCODE" }
}

$vcpkgDir = Join-Path $root 'vendor/vcpkg'
Invoke-Native git @('-C', $root, 'submodule', 'update', '--init', 'vendor/vcpkg')   # offline and instant when up to date

$stampDir = Join-Path $root 'vcpkg_installed'
$stamp = Join-Path $stampDir ".stamp-$($env:SIM_VCPKG_TRIPLET)"
$manifestHash = (Get-FileHash (Join-Path $root 'vcpkg.json') -Algorithm SHA256).Hash
$vcpkgRev = (& git -C $vcpkgDir rev-parse HEAD).Trim()
$want = "$manifestHash $vcpkgRev"
if ((Test-Path $stamp) -and ((Get-Content $stamp -Raw).Trim() -eq $want) -and (Test-Path (Join-Path $env:SIM_VCPKG_PREFIX 'share/sdl3'))) {
    return   # up to date: no network
}

# (Re)bootstrap the vcpkg tool if it is missing or the pinned tool version changed.
$vcpkgExe = Join-Path $vcpkgDir 'vcpkg.exe'
$toolStamp = Join-Path $stampDir '.tool-stamp'
$toolWant = (Get-FileHash (Join-Path $vcpkgDir 'scripts/vcpkg-tool-metadata.txt') -Algorithm SHA256).Hash
if (-not (Test-Path $vcpkgExe) -or -not (Test-Path $toolStamp) -or ((Get-Content $toolStamp -Raw).Trim() -ne $toolWant)) {
    Invoke-Native (Join-Path $vcpkgDir 'bootstrap-vcpkg.bat') @('-disableMetrics')
    New-Item -ItemType Directory -Force $stampDir | Out-Null
    Set-Content -Path $toolStamp -Value $toolWant
}

Write-Host "setup-deps: installing vcpkg dependencies ($($env:SIM_VCPKG_TRIPLET))..."
$env:VCPKG_DISABLE_METRICS = '1'
Invoke-Native $vcpkgExe @('install', '--triplet', $env:SIM_VCPKG_TRIPLET,
    "--x-manifest-root=$root", "--x-install-root=$(Join-Path $root 'vcpkg_installed')")
New-Item -ItemType Directory -Force $stampDir | Out-Null
Set-Content -Path $stamp -Value $want
