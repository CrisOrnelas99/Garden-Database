param([int]$BootstrapProcessId = 0)

$ErrorActionPreference = 'Stop'
$frontendRoot = Split-Path -Parent $PSScriptRoot
$repoOwner = 'CrisOrnelas99'
$repoName = 'Garden-Database'
$branch = 'main'
$versionFile = Join-Path $frontendRoot '.garden-app-version'
$localVersion = if (Test-Path -LiteralPath $versionFile) { (Get-Content -LiteralPath $versionFile -Raw).Trim() } else { '' }

# Let the bootstrap executable exit before mirroring files, so Windows can replace it.
if ($BootstrapProcessId -gt 0) {
    try { Wait-Process -Id $BootstrapProcessId -Timeout 20 -ErrorAction SilentlyContinue } catch {}
}

try {
    $headers = @{ 'User-Agent' = 'GardenDatabaseLocalUpdater' }
    $commit = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/commits/$branch" -Headers $headers -TimeoutSec 20
    $remoteVersion = [string]$commit.sha

    if ($remoteVersion -and $remoteVersion -ne $localVersion) {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('GardenDatabase-' + [guid]::NewGuid().ToString('N'))
        $archivePath = Join-Path $tempRoot 'source.zip'
        $extractPath = Join-Path $tempRoot 'extract'
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        Invoke-WebRequest -Uri "https://codeload.github.com/$repoOwner/$repoName/zip/refs/heads/$branch" -OutFile $archivePath -TimeoutSec 60
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force
        $sourceFrontend = Join-Path (Join-Path $extractPath "$repoName-$branch") 'frontend'

        if (-not (Test-Path -LiteralPath $sourceFrontend)) {
            throw 'The downloaded GitHub archive did not contain the frontend folder.'
        }

        # Back up local files before replacing them. This includes uncommitted changes.
        $backupRoot = Join-Path $env:LOCALAPPDATA 'GardenDatabase\frontend-backups'
        $backupPath = Join-Path $backupRoot (Get-Date -Format 'yyyyMMdd-HHmmss')
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
        Get-ChildItem -LiteralPath $frontendRoot -Force | Where-Object { $_.Name -ne '.venv' } | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $backupPath -Recurse -Force
        }

        # Preserve machine-specific files and the virtual environment during the update.
        robocopy $sourceFrontend $frontendRoot /MIR /R:2 /W:1 /XD (Join-Path $frontendRoot '.venv') /XF '.env' '.garden-app-version' | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Frontend file update failed (robocopy exit code $LASTEXITCODE)." }
        Set-Content -LiteralPath $versionFile -Value $remoteVersion -NoNewline
        Write-Host "Garden Database frontend updated. A backup of the previous files is at: $backupPath" -ForegroundColor Green
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host 'Garden Database frontend is already up to date.'
    }
} catch {
    Write-Warning "Could not check or install GitHub updates: $($_.Exception.Message)"
    Write-Host 'Starting the local frontend files instead.'
}

$launcher = Join-Path $PSScriptRoot 'Run-GardenApp.ps1'
if (-not (Test-Path -LiteralPath $launcher)) {
    throw "The local launcher was not found: $launcher"
}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher
