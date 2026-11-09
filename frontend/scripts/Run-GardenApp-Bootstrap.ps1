param([int]$BootstrapProcessId = $PID)

$ErrorActionPreference = 'Stop'
$bootstrapLocation = $PSScriptRoot
if (-not $bootstrapLocation) {
    $bootstrapLocation = Split-Path -Parent $MyInvocation.MyCommand.Path
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
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $updater + '"'), '-BootstrapProcessId', $BootstrapProcessId)
    Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WorkingDirectory $frontendRoot -NoNewWindow
} else {
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $launcher + '"'))
    Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WorkingDirectory $frontendRoot -NoNewWindow
}
