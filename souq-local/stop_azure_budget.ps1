# Stop or delete MarGem budget Azure resources
# Usage: .\stop_azure_budget.ps1 -Deallocate    # pause VM, keep data (~$3/mo disk only)
#        .\stop_azure_budget.ps1 -Destroy       # delete everything

param(
    [switch]$Deallocate,
    [switch]$Destroy
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$TfDir = Join-Path $Root "infra\terraform-budget"

if (-not $Deallocate -and -not $Destroy) {
    Write-Host ""
    Write-Host "Choose one:"
    Write-Host "  .\stop_azure_budget.ps1 -Deallocate   # stop VM billing, keep data"
    Write-Host "  .\stop_azure_budget.ps1 -Destroy      # delete all Azure resources"
    Write-Host ""
    exit 1
}

Push-Location $TfDir
try {
    if ($Destroy) {
        Write-Host ""
        Write-Host "=== Destroying budget Azure stack ===" -ForegroundColor Red
        $confirm = Read-Host "Type 'destroy' to confirm"
        if ($confirm -ne "destroy") {
            Write-Host "Cancelled."
            exit 0
        }
        terraform destroy -auto-approve
        Write-Host "All budget resources deleted."
    }
    else {
        $rg = terraform output -raw resource_group_name 2>$null
        $vm = terraform output -raw vm_name 2>$null
        if (-not $rg -or -not $vm) {
            Write-Error "No deployment found. Run start_azure_budget.ps1 first."
        }
        Write-Host ""
        Write-Host "=== Deallocating VM (stopping compute charges) ===" -ForegroundColor Cyan
        az vm deallocate --resource-group $rg --name $vm
        Write-Host "VM stopped. Storage + disk still billed (~few dollars/month)."
        Write-Host "Start again: az vm start --resource-group $rg --name $vm"
        Write-Host "Or redeploy app: .\start_azure_budget.ps1"
    }
}
finally {
    Pop-Location
}

Write-Host ""
