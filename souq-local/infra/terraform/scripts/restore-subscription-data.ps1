# Restore PostgreSQL + blob media onto a newly deployed subscription.
# Usage: .\restore-subscription-data.ps1 -Sub 2 -FromSub 1

param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 99)]
    [int]$Sub,
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 99)]
    [int]$FromSub
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$paths = Get-SubPaths -Sub $Sub
$fromPaths = Get-SubPaths -Sub $FromSub

if (-not (Test-Path $paths.State)) {
    Write-Error "No deployment found for sub$Sub. Run switch-subscription.ps1 -Sub $Sub first."
}
if (-not (Test-Path $fromPaths.DatabaseDump)) {
    Write-Error "No database backup at $($fromPaths.DatabaseDump). Run backup-subscription-data.ps1 -Sub $FromSub first."
}

$fromJwt = Get-TfVarValue -Path $fromPaths.Tfvars -Name "jwt_secret_key"
$toJwt = Get-TfVarValue -Path $paths.Tfvars -Name "jwt_secret_key"
if ($fromJwt -ne $toJwt) {
    Write-Warning "jwt_secret_key differs between sub$FromSub and sub$Sub — users will need to log in again."
    Write-Warning "To keep sessions: copy jwt_secret_key from sub$FromSub tfvars to sub$Sub, then re-apply terraform."
}

Write-Host ""
Write-Host "=== Restoring sub$FromSub data onto sub$Sub ==="
Write-Host ""

$uri = Get-PostgresConnectionUri -Sub $Sub
Write-Host "Restoring database..."
Invoke-PgRestore -ConnectionUri $uri -DumpFile $fromPaths.DatabaseDump
Write-Host "Database restore complete."

Write-Host "Restoring blob media..."
Restore-SubscriptionBlobsToTarget -FromSub $FromSub -ToSub $Sub
Write-Host "Blob restore complete."

Write-Host ""
Write-Host "Data migration complete. Verify: curl $(Get-TerraformOutputValue -State $paths.State -Name api_url -TerraformDir $paths.TerraformDir)/health"
