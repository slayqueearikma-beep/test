# Back up PostgreSQL + blob media from a subscription before rotating away.
# Usage: .\backup-subscription-data.ps1 -Sub 1

param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 99)]
    [int]$Sub
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$paths = Get-SubPaths -Sub $Sub
if (-not (Test-Path $paths.State)) {
    Write-Error "No deployment found for sub$Sub (missing $($paths.State)). Deploy first with switch-subscription.ps1"
}

Write-Host ""
Write-Host "=== Backing up sub$Sub data ==="
Write-Host "  Database → $($paths.DatabaseDump)"
Write-Host "  Blobs    → $($paths.BlobsDir)"
Write-Host ""

$uri = Get-PostgresConnectionUri -Sub $Sub
Invoke-PgDump -ConnectionUri $uri -OutputFile $paths.DatabaseDump
Write-Host "Database backup complete."

Backup-SubscriptionBlobs -Sub $Sub
Write-Host "Blob backup complete."

Write-Host ""
Write-Host "Backup saved under: $($paths.BackupDir)"
Write-Host "Next: deploy the new subscription, then run restore-subscription-data.ps1"
