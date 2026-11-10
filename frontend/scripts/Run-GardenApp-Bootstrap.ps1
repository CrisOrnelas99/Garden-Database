param([int]$BootstrapProcessId = $PID)

$ErrorActionPreference = 'Stop'
$bootstrapLocation = $PSScriptRoot
if (-not $bootstrapLocation) {
    $bootstrapPath = $MyInvocation.MyCommand.Path
    if (-not $bootstrapPath) {
        $bootstrapPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    }
    if ($bootstrapPath) { $bootstrapLocation = Split-Path -Parent $bootstrapPath }
}
$frontendRoot = $bootstrapLocation
while ($frontendRoot -and -not (Test-Path -LiteralPath (Join-Path $frontendRoot 'app.py'))) {
    $parent = Split-Path -Parent $frontendRoot
    if (-not $parent -or $parent -eq $frontendRoot) { break }
    $frontendRoot = $parent
}
if (-not (Test-Path -LiteralPath (Join-Path $frontendRoot 'app.py'))) {
    throw 'Could not find app.py. Keep Run-GardenApp.exe in the frontend folder.'
}
$scriptsRoot = Join-Path $frontendRoot 'scripts'
$updater = Join-Path $scriptsRoot 'Update-GardenApp.ps1'
$launcher = Join-Path $scriptsRoot 'Run-GardenApp.ps1'

if (-not (Get-Command py.exe -ErrorAction SilentlyContinue)) {
    Write-Host 'Python was not found. Install Python 3.9 or newer, then run this app again.' -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}

if (Test-Path -LiteralPath $updater) {
    $arguments = '-NoProfile -NoExit -ExecutionPolicy Bypass -File "{0}" -BootstrapProcessId {1}' -f $updater, $BootstrapProcessId
    Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WorkingDirectory $frontendRoot
} else {
    $arguments = '-NoProfile -NoExit -ExecutionPolicy Bypass -File "{0}"' -f $launcher
    Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WorkingDirectory $frontendRoot
}
