# Tear down MarGem on subscription N when credits/budget are exhausted.
# Usage: .\destroy-subscription.ps1 -Sub 1

param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 99)]
    [int]$Sub
)

$ErrorActionPreference = "Stop"
$alias = "sub$Sub"
$tfvars = Join-Path $PSScriptRoot "..\subscriptions\$alias.tfvars"
$state = Join-Path $PSScriptRoot "..\terraform-$alias.tfstate"
$terraformDir = Resolve-Path (Join-Path $PSScriptRoot "..")

if (-not (Test-Path $tfvars)) {
    Write-Error "Missing $tfvars"
}
if (-not (Test-Path $state)) {
    Write-Error "No state file $state — nothing to destroy for $alias"
}

Write-Host ""
Write-Host "This will DESTROY all MarGem resources in $alias and stop billing for that stack."
Write-Host "Back up PostgreSQL first if you need your data (see subscriptions/MONTHLY-ROTATION.md)."
Write-Host ""

$confirm = Read-Host "Type $alias to confirm destroy"
if ($confirm -ne $alias) {
    Write-Host "Cancelled."
    exit 0
}

Push-Location $terraformDir
try {
    terraform destroy -state=$state -var-file="subscriptions/$alias.tfvars"
    Write-Host ""
    Write-Host "Destroyed $alias. Deploy the next month with:"
    Write-Host "  .\scripts\switch-subscription.ps1 -Sub $($Sub + 1)"
}
finally {
    Pop-Location
}
