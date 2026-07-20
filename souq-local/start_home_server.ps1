# Start MarGem on your laptop (API + Postgres) using Azure Blob for images
# Usage: .\start_home_server.ps1

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$EnvFile = Join-Path $Root ".env.home"
$EnvExample = Join-Path $Root "env.home.example"

function Get-LanIp {
    $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.InterfaceAlias -notmatch 'Loopback' -and
            $_.IPAddress -notmatch '^169\.' -and
            $_.IPAddress -notmatch '^127\.'
        } | Select-Object -First 1 -ExpandProperty IPAddress
    if ($ip) { return $ip }
    return "127.0.0.1"
}

Write-Host ""
Write-Host "=== MarGem Home Server ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker not found. Install Docker Desktop."
}

docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker is not running. Start Docker Desktop."
}

if (-not (Test-Path $EnvFile)) {
    if (Test-Path $EnvExample) {
        Copy-Item $EnvExample $EnvFile
        Write-Host "Created .env.home"
        Write-Host ""
        Write-Host "Run first: .\setup_azure_blob.ps1"
        Write-Host "Then edit .env.home (passwords + ALLOWED_HOSTS)"
        exit 1
    }
    Write-Error "Missing .env.home — run .\setup_azure_blob.ps1 first"
}

$lanIp = Get-LanIp
$port = 8000
if ((Get-Content $EnvFile) -match 'API_PORT=(\d+)') { $port = $Matches[1] }

Write-Host "[1/2] Starting Postgres + API..."
Push-Location $Root
try {
    docker compose -f docker-compose.home.yml --env-file .env.home up -d --build
    if ($LASTEXITCODE -ne 0) { throw "docker compose failed" }
}
finally {
    Pop-Location
}

Write-Host "[2/2] Waiting for health..."
$apiUrl = "http://${lanIp}:${port}"
$ready = $false
for ($i = 1; $i -le 30; $i++) {
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:${port}/health" -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    } catch { Start-Sleep -Seconds 2 }
}

Write-Host ""
if ($ready) {
    Write-Host "=== Home server running ===" -ForegroundColor Green
} else {
    Write-Warning "API not ready yet. Check: docker compose -f docker-compose.home.yml logs api"
}

Write-Host ""
Write-Host "  Same Wi-Fi:     $apiUrl"
Write-Host "  This PC:        http://localhost:${port}"
Write-Host "  Health:         http://localhost:${port}/health"
Write-Host "  Images:         Azure Blob (cloud)"
Write-Host ""
Write-Host "Phone on same Wi-Fi:"
Write-Host "  flutter run --dart-define=API_BASE_URL=$apiUrl"
Write-Host ""
Write-Host "Phone elsewhere → install Tailscale on laptop + phone, then use Tailscale IP in .env.home ALLOWED_HOSTS"
Write-Host ""
Write-Host "Stop: .\stop_home_server.ps1"
Write-Host ""
