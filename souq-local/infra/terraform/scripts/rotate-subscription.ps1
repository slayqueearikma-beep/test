# Rotate to the next subscription AND keep all data (DB + images).
# Usage: .\rotate-subscription.ps1 -FromSub 1 -ToSub 2

param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 98)]
    [int]$FromSub,
    [Parameter(Mandatory = $true)]
    [ValidateRange(2, 99)]
    [int]$ToSub,
    [switch]$SkipDestroy
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

if ($ToSub -le $FromSub) {
    Write-Error "ToSub must be greater than FromSub (e.g. -FromSub 1 -ToSub 2)"
}

$toPaths = Get-SubPaths -Sub $ToSub
if (-not (Test-Path $toPaths.Tfvars)) {
    if (Test-Path $toPaths.Example) {
        Copy-Item $toPaths.Example $toPaths.Tfvars
        Copy-JwtSecretFromPreviousSub -FromSub $FromSub -ToSub $ToSub
        Write-Host ""
        Write-Host "Created $($toPaths.Tfvars) and copied jwt_secret_key from sub$FromSub."
        Write-Host "Edit subscription_id and postgres_admin_password, then re-run this script."
        exit 1
    }
    Write-Error "Missing $($toPaths.Tfvars)"
}

Write-Host ""
Write-Host "=========================================="
Write-Host " MarGem subscription rotation with data"
Write-Host " sub$FromSub  -->  sub$ToSub"
Write-Host "=========================================="
Write-Host ""

Write-Host "[1/4] Backing up sub$FromSub (database + images)..."
& "$PSScriptRoot\backup-subscription-data.ps1" -Sub $FromSub

Write-Host ""
Write-Host "[2/4] Deploying sub$ToSub infrastructure..."
& "$PSScriptRoot\switch-subscription.ps1" -Sub $ToSub

Write-Host ""
Write-Host "[3/4] Restoring data onto sub$ToSub..."
& "$PSScriptRoot\restore-subscription-data.ps1" -Sub $ToSub -FromSub $FromSub

Write-Host ""
Write-Host "[4/4] Old subscription cleanup"
if ($SkipDestroy) {
    Write-Host "Skipped destroy ( -SkipDestroy ). Destroy sub$FromSub manually when ready:"
    Write-Host "  .\scripts\destroy-subscription.ps1 -Sub $FromSub"
}
else {
    $confirm = Read-Host "Destroy sub$FromSub now to stop billing? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        & "$PSScriptRoot\destroy-subscription.ps1" -Sub $FromSub
    }
    else {
        Write-Host "Left sub$FromSub running — destroy it soon to avoid extra charges."
    }
}

$api = Get-TerraformOutputValue -State $toPaths.State -Name "api_url" -TerraformDir $toPaths.TerraformDir
Write-Host ""
Write-Host "=== Done — same users/sellers/data on sub$ToSub ==="
Write-Host "API URL: $api"
Write-Host ""
Write-Host "Rebuild mobile app with the new API URL (only the host changes)."
