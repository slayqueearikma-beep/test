# Try common Azure regions and report which ones your subscription allows.
# Use the first "OK" region as `location` in terraform.tfvars.

$ErrorActionPreference = "Continue"
$testName = "rg-focus-region-probe-$(Get-Random -Maximum 99999)"
$candidates = @(
    "eastus",
    "eastus2",
    "westus2",
    "centralus",
    "northeurope",
    "westeurope",
    "uksouth",
    "francecentral"
)

Write-Host "Probing allowed regions for your subscription..." -ForegroundColor Cyan
Write-Host "Test resource group prefix: $testName`n"

$allowed = @()

foreach ($region in $candidates) {
    $rg = "$testName-$region"
    Write-Host "Trying $region ... " -NoNewline
    $result = az group create --name $rg --location $region 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK" -ForegroundColor Green
        $allowed += $region
        az group delete --name $rg --yes --no-wait 2>$null | Out-Null
    }
    else {
        if ($result -match "RequestDisallowedByAzure|disallowed") {
            Write-Host "BLOCKED (policy)" -ForegroundColor Yellow
        }
        else {
            Write-Host "FAILED" -ForegroundColor Red
            Write-Host "  $result"
        }
    }
}

Write-Host ""
if ($allowed.Count -gt 0) {
    Write-Host "Use one of these in terraform.tfvars:" -ForegroundColor Green
    $allowed | ForEach-Object { Write-Host "  location = `"$_`"" }
    Write-Host "`nRecommended: location = `"$($allowed[0])`""
}
else {
    Write-Host "No candidate region worked. Run:" -ForegroundColor Red
    Write-Host "  az account list-locations -o table"
    Write-Host "Contact your subscription admin or Azure support for allowed regions."
}
