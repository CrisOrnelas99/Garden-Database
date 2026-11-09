param()

$ErrorActionPreference = 'Stop'
$frontendRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $frontendRoot

if (-not (Get-Command py.exe -ErrorAction SilentlyContinue)) {
    Write-Host 'Python was not found. Install Python 3.9 or newer from https://www.python.org/downloads/windows/ and select the option to install the Python launcher.' -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}

$venvPython = Join-Path $frontendRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $venvPython)) {
    Write-Host 'Creating the app environment...'
    & py.exe -3 -m venv (Join-Path $frontendRoot '.venv')
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the Python environment.' }
}

Write-Host 'Installing or updating the app requirements...'
& $venvPython -m pip install -r (Join-Path $frontendRoot 'requirements.txt')
if ($LASTEXITCODE -ne 0) { throw 'Could not install app requirements.' }

Write-Host 'Starting the Garden Database app...'
Start-Process 'http://localhost:8000'
& $venvPython (Join-Path $frontendRoot 'app.py')
