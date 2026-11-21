# Fetch, bootstrap and run vcpkg to install the pinned SDL3 (see vcpkg.json). Windows/PowerShell.
# Idempotent: does nothing when vcpkg.json and the vcpkg checkout are unchanged.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'env.ps1')

function Invoke-Native {
    param([Parameter(Mandatory)][string]$Command, [string[]]$Arguments = @())
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "'$Command $($Arguments -join ' ')' failed with exit code $LASTEXITCODE" }
}

$vcpkgDir = Join-Path $root 'vendor/vcpkg'
if (-not (Test-Path (Join-Path $vcpkgDir 'bootstrap-vcpkg.bat'))) {
    Invoke-Native git @('-C', $root, 'submodule', 'update', '--init', 'vendor/vcpkg')
}
$vcpkgExe = Join-Path $vcpkgDir 'vcpkg.exe'
if (-not (Test-Path $vcpkgExe)) {
    Invoke-Native (Join-Path $vcpkgDir 'bootstrap-vcpkg.bat') @('-disableMetrics')
}

$stampDir = Join-Path $root 'vcpkg_installed'
$stamp = Join-Path $stampDir ".stamp-$($env:SIM_VCPKG_TRIPLET)"
$manifestHash = (Get-FileHash (Join-Path $root 'vcpkg.json') -Algorithm SHA256).Hash
$vcpkgRev = (& git -C $vcpkgDir rev-parse HEAD).Trim()
$want = "$manifestHash $vcpkgRev"
if ((Test-Path $stamp) -and ((Get-Content $stamp -Raw).Trim() -eq $want) -and (Test-Path (Join-Path $env:SIM_VCPKG_PREFIX 'share/sdl3'))) {
    return
}

Write-Host "setup-deps: installing vcpkg dependencies ($($env:SIM_VCPKG_TRIPLET))..."
$env:VCPKG_DISABLE_METRICS = '1'
Invoke-Native $vcpkgExe @('install', '--triplet', $env:SIM_VCPKG_TRIPLET,
    "--x-manifest-root=$root", "--x-install-root=$(Join-Path $root 'vcpkg_installed')")
New-Item -ItemType Directory -Force $stampDir | Out-Null
Set-Content -Path $stamp -Value $want
