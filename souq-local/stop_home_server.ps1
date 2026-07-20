# Stop MarGem home server (Docker only — Azure blob stays, ~$1-3/mo)
# Usage: .\stop_home_server.ps1

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

Write-Host ""
Write-Host "Stopping home server containers..."
Push-Location $Root
try {
    docker compose -f docker-compose.home.yml --env-file .env.home down
}
finally {
    Pop-Location
}
Write-Host "Stopped. Azure blob storage is still active (minimal cost)."
Write-Host ""
