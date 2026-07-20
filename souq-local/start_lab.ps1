# MarGem local lab — start backend (Docker) + Flutter app
# Usage: .\start_lab.ps1
#        .\start_lab.ps1 -NoFlutter    # backend only

param(
    [switch]$NoFlutter,
    [string]$DeviceId = ""
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$Mobile = Join-Path $Root "mobile"
$LabDir = Join-Path $Root ".lab"
New-Item -ItemType Directory -Path $LabDir -Force | Out-Null

function Get-LanIp {
    $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.InterfaceAlias -notmatch 'Loopback' -and
            $_.IPAddress -notmatch '^169\.' -and
            $_.IPAddress -notmatch '^127\.'
        } |
        Select-Object -First 1 -ExpandProperty IPAddress
    if ($ip) { return $ip }
    return "127.0.0.1"
}

Write-Host ""
Write-Host "=== MarGem Lab — starting ===" -ForegroundColor Cyan
Write-Host ""

# Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker not found. Install Docker Desktop and try again."
}
$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker is not running. Start Docker Desktop, then retry."
}

Push-Location $Root
try {
    Write-Host "[1/3] Starting Postgres + API (docker compose)..."
    docker compose up -d --build
    if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }

    Write-Host "[2/3] Waiting for API health..."
    $ready = $false
    for ($i = 1; $i -le 45; $i++) {
        try {
            $resp = Invoke-WebRequest -Uri "http://localhost:8000/health" -UseBasicParsing -TimeoutSec 3
            if ($resp.StatusCode -eq 200) {
                $ready = $true
                break
            }
        } catch {
            Start-Sleep -Seconds 2
        }
    }
    if (-not $ready) {
        Write-Warning "API health check timed out. Logs: docker compose logs api"
    } else {
        Write-Host "      API ready at http://localhost:8000" -ForegroundColor Green
    }
}
finally {
    Pop-Location
}

$lanIp = Get-LanIp
$apiUrl = "http://${lanIp}:8000"
Set-Content -Path (Join-Path $LabDir "api_url.txt") -Value $apiUrl

Write-Host ""
Write-Host "  Emulator API:  http://10.0.2.2:8000"
Write-Host "  Physical phone: $apiUrl"
Write-Host "  API docs:       http://localhost:8000/docs"
Write-Host ""

if ($NoFlutter) {
    Write-Host "Backend only (-NoFlutter). Stop with: .\stop_lab.ps1"
    exit 0
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Warning "Flutter not in PATH. Start the app manually:"
    Write-Host "  cd mobile"
    Write-Host "  flutter run --dart-define=API_BASE_URL=$apiUrl"
    exit 0
}

Write-Host "[3/3] Launching Flutter (new window)..."
$flutterArgs = @(
    "run",
    "--dart-define=API_BASE_URL=$apiUrl"
)
if ($DeviceId) {
    $flutterArgs += @("-d", $DeviceId)
}

$argList = "-NoExit -Command cd '$Mobile'; flutter $($flutterArgs -join ' ')"
Start-Process powershell -ArgumentList $argList -WorkingDirectory $Mobile

Set-Content -Path (Join-Path $LabDir "started_at.txt") -Value (Get-Date -Format o)

Write-Host ""
Write-Host "Lab started. Stop everything with: .\stop_lab.ps1" -ForegroundColor Green
Write-Host ""
