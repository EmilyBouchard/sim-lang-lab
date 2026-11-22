# Format all languages (Windows/PowerShell). Thin wrapper around format.sh, so there is one
# implementation of the formatting logic.
#   .\format.ps1 [cpp|csharp|haskell|all] [-Check]
# -Check verifies formatting without changing files.
# Needs clang-format, dotnet and fourmolu on PATH (see README, "Formatting and git hooks").
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('cpp', 'csharp', 'haskell', 'all')]
    [string]$Lang = 'all',

    [switch]$Check
)

$ErrorActionPreference = 'Stop'

# Use the bash that ships with Git for Windows. A plain `bash` on PATH can be WSL's launcher
# (C:\Windows\System32\bash.exe), which would run format.sh in a Linux distro instead.
$git = (Get-Command git.exe -ErrorAction Stop).Source
$bash = Join-Path (Split-Path -Parent (Split-Path -Parent $git)) 'bin/bash.exe'
if (-not (Test-Path $bash)) { throw "Git for Windows' bash.exe not found at $bash" }

$shArgs = @('./format.sh', $Lang)
if ($Check) { $shArgs += '--check' }

Push-Location $PSScriptRoot
try {
    $ErrorActionPreference = 'Continue'   # formatters log to stderr; PS 5.1 would treat that as fatal
    & $bash @shArgs
    exit $LASTEXITCODE
}
finally { Pop-Location }
