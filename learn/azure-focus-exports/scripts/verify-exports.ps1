# Verify FOCUS lab exports without the Azure Portal.
# Run from repo root or pass -LabDir to the terraform folder.

param(
    [string]$LabDir = (Join-Path $PSScriptRoot "..\lab\terraform")
)

$ErrorActionPreference = "Stop"
Push-Location $LabDir

Write-Host "=== Terraform outputs ===" -ForegroundColor Cyan
terraform output

$sub = az account show --query id -o tsv
$rg = terraform output -raw resource_group_name
$account = terraform output -raw storage_account_name
$container = terraform output -raw container_name
$focusName = (terraform output -json 2>$null | ConvertFrom-Json).focus_export_name
if (-not $focusName) { $focusName = "lab-focus-daily" }

Write-Host "`n=== Subscription exports (API 2025-03-01) ===" -ForegroundColor Cyan
az rest --method GET `
    --uri "https://management.azure.com/subscriptions/$sub/providers/Microsoft.CostManagement/exports?api-version=2025-03-01"

Write-Host "`n=== Resource group exports ($rg) ===" -ForegroundColor Cyan
az rest --method GET `
    --uri "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.CostManagement/exports?api-version=2025-03-01"

Write-Host "`n=== FOCUS run history ($focusName) ===" -ForegroundColor Cyan
az rest --method GET `
    --uri "https://management.azure.com/subscriptions/$sub/providers/Microsoft.CostManagement/exports/$focusName/runHistory?api-version=2025-03-01"

Write-Host "`n=== Blobs in storage ($account / $container) ===" -ForegroundColor Cyan
az storage blob list `
    --account-name $account `
    --container-name $container `
    --prefix focus-parquet/ `
    --auth-mode login `
    -o table

Pop-Location
Write-Host "`nDone." -ForegroundColor Green
