# Deploy (or update) MarGem on subscription N for monthly credit rotation.
# Usage: .\switch-subscription.ps1 -Sub 1
#        .\switch-subscription.ps1 -Sub 2

param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 99)]
    [int]$Sub
)

$ErrorActionPreference = "Stop"
$alias = "sub$Sub"
$tfvars = Join-Path $PSScriptRoot "..\subscriptions\$alias.tfvars"
$example = Join-Path $PSScriptRoot "..\subscriptions\$alias.tfvars.example"
$state = Join-Path $PSScriptRoot "..\terraform-$alias.tfstate"
$terraformDir = Resolve-Path (Join-Path $PSScriptRoot "..")

if (-not (Test-Path $tfvars)) {
    if (Test-Path $example) {
        Copy-Item $example $tfvars
        Write-Host ""
        Write-Host "Created $tfvars"
        Write-Host "Edit it: set subscription_id, postgres_admin_password, jwt_secret_key"
        Write-Host "Then run: .\scripts\switch-subscription.ps1 -Sub $Sub"
        exit 1
    }
    Write-Error "Missing $tfvars — copy subscriptions/sub1.tfvars.example to subscriptions/$alias.tfvars and edit it."
}

Push-Location $terraformDir
try {
    if (-not (Test-Path ".terraform")) {
        terraform init
    }

    Write-Host ""
    Write-Host "Deploying to subscription alias '$alias' (state: terraform-$alias.tfstate)"
    Write-Host ""

    terraform apply -state=$state -var-file="subscriptions/$alias.tfvars"

    Write-Host ""
    Write-Host "=== Active API URL ==="
    terraform output -state=$state -raw api_url
    Write-Host ""
    Write-Host "Rebuild mobile:"
    Write-Host "  flutter build apk --dart-define=PRODUCTION=true --dart-define=API_BASE_URL=<api_url above>"
}
finally {
    Pop-Location
}
