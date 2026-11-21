# Dot-source to point every language at the vcpkg-installed SDL3 (Windows/PowerShell):
#   . .\scripts\env.ps1
# Sets SIM_VCPKG_TRIPLET, SIM_VCPKG_PREFIX, PKG_CONFIG_LIBDIR and adds the SDL3 and pkgconf
# directories to PATH for this session.
$simRoot = Split-Path -Parent $PSScriptRoot
$env:SIM_VCPKG_TRIPLET = 'x64-windows'
$env:SIM_VCPKG_PREFIX = Join-Path $simRoot "vcpkg_installed/$($env:SIM_VCPKG_TRIPLET)"
# pkgconf wants ';' on Windows. LIBDIR replaces the default search path so no other SDL3 is used.
$env:PKG_CONFIG_LIBDIR = (Join-Path $env:SIM_VCPKG_PREFIX 'lib/pkgconfig') + ';' + (Join-Path $env:SIM_VCPKG_PREFIX 'share/pkgconfig')

$pkgconfTools = Join-Path $env:SIM_VCPKG_PREFIX 'tools/pkgconf'
# Cabal looks for an executable named pkg-config; vcpkg's pkgconf port only ships pkgconf.exe.
if ((Test-Path (Join-Path $pkgconfTools 'pkgconf.exe')) -and -not (Test-Path (Join-Path $pkgconfTools 'pkg-config.exe'))) {
    Copy-Item (Join-Path $pkgconfTools 'pkgconf.exe') (Join-Path $pkgconfTools 'pkg-config.exe')
}
foreach ($dir in @((Join-Path $env:SIM_VCPKG_PREFIX 'bin'), $pkgconfTools)) {
    if (($env:PATH -split ';') -notcontains $dir) { $env:PATH = "$dir;$env:PATH" }
}
