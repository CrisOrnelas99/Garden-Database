$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
    Write-Error 'Install Python 3.9 or newer, then run this script again.'
    exit 1
}

if (-not (Test-Path '.venv\Scripts\python.exe')) {
    py -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the Python environment.' }
}

& '.venv\Scripts\python.exe' -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }

$secureUri = Read-Host 'Paste the Supabase Session pooler URI (input is hidden)' -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureUri)
try {
    $env:DATABASE_URL = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    $secureUri.Dispose()
}

try {
    Start-Process 'http://localhost:8000'
    & '.venv\Scripts\python.exe' app.py
}
finally {
    Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue
}
