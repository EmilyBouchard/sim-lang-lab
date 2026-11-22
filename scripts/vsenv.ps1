# Dot-source to load the MSVC x64 build environment into this PowerShell session (Windows):
#   . .\scripts\vsenv.ps1
# Finds the newest Visual Studio with the C++ tools via vswhere and imports the variables set by
# vcvars64.bat (cl, link, INCLUDE, LIB, ...). Does nothing if an x64 MSVC shell is already active
# (e.g. a "Developer PowerShell for VS"); an x86 shell is not enough, so it is replaced.
if ((Get-Command cl.exe -ErrorAction SilentlyContinue) -and $env:VSCMD_ARG_TGT_ARCH -eq 'x64') { return }

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (-not (Test-Path $vswhere)) {
    throw "vswhere.exe not found. Install Visual Studio (or Build Tools) with the 'Desktop development with C++' workload."
}
$vsPath = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) {
    throw "No Visual Studio with the MSVC x64 tools found. Install the 'Desktop development with C++' workload."
}
$vcvars = Join-Path $vsPath 'VC/Auxiliary/Build/vcvars64.bat'
$installerDir = Split-Path -Parent $vswhere   # vcvars64.bat itself calls vswhere; it may not be on PATH
cmd /c "set `"PATH=%PATH%;$installerDir`" && `"$vcvars`" >nul && set" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] }
}
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
    throw "vcvars64.bat ran but cl.exe is still not on PATH. Run `"$vcvars`" in a cmd window to see why."
}
