# MarGem local lab — stop backend + Flutter
# Usage: .\stop_lab.ps1

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

Write-Host ""
Write-Host "=== MarGem Lab — stopping ===" -ForegroundColor Cyan
Write-Host ""

Push-Location $Root
try {
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Host "[1/2] Stopping Docker containers..."
        docker compose down
    } else {
        Write-Warning "Docker not found — skipping container stop."
    }
}
finally {
    Pop-Location
}

Write-Host "[2/2] Stopping Flutter/Dart lab processes..."
$stopped = 0
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -match '^(dart|flutter)\.exe$' -and
        $_.CommandLine -match 'souq-local[\\/]mobile'
    } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        $stopped++
    }

if ($stopped -gt 0) {
    Write-Host "      Stopped $stopped Flutter process(es)."
} else {
    Write-Host "      No Flutter lab processes found (close the Flutter window manually if still open)."
}

$labDir = Join-Path $Root ".lab"
if (Test-Path $labDir) {
    Remove-Item (Join-Path $labDir "*") -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Lab stopped." -ForegroundColor Green
Write-Host ""
