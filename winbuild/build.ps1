<#
.SYNOPSIS
  Build OpenOCD with the MSYS2 UCRT64 toolchain kept in winbuild\toolchain\msys64.

.EXAMPLE
  .\winbuild\build.ps1                  # build\base -> bin\base\openocd.exe
  .\winbuild\build.ps1 -Name dev        # separate build dir and output (bin\dev)
  .\winbuild\build.ps1 -Reconfigure     # run bootstrap + configure again
  .\winbuild\build.ps1 -Clean           # wipe build\<Name> first

The source tree must have LF line endings (see winbuild\README.md).
#>
param(
    [string]$Name = 'base',
    [switch]$Reconfigure,
    [switch]$Clean
)
$wb   = $PSScriptRoot
$bash = Join-Path $wb 'toolchain\msys64\usr\bin\bash.exe'
if (-not (Test-Path $bash)) { throw "Toolchain not found: $bash (see winbuild\README.md)" }

# Clean environment: nothing from the user's profile may leak into MSYS2 (HOME, GNUPGHOME).
$env:MSYSTEM        = 'UCRT64'
$env:CHERE_INVOKING = '1'
$env:WB_ROOT        = $wb
Remove-Item Env:HOME, Env:GNUPGHOME -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force (Join-Path $wb 'logs') | Out-Null
$log = Join-Path $wb ('logs\build_{0}_{1:yyyyMMdd_HHmmss}.log' -f $Name, (Get-Date))

$ErrorActionPreference = 'Continue'   # native stderr must not abort the script

# Tee-Object would write the log as UTF-16 in Windows PowerShell 5.1; write UTF-8 (no BOM) instead.
$sw = New-Object System.IO.StreamWriter($log, $false, (New-Object System.Text.UTF8Encoding($false)))
try {
    & $bash -l (Join-Path $wb 'build.sh') $Name ([int]$Reconfigure.IsPresent) ([int]$Clean.IsPresent) 2>&1 |
        ForEach-Object { $line = "$_"; $sw.WriteLine($line); $line }
    $rc = $LASTEXITCODE
} finally {
    $sw.Close()
}
if ($rc -ne 0) { throw "Build failed (exit code $rc). Log: $log" }
Write-Host "OK: $wb\bin\$Name\openocd.exe   (log: $log)"
