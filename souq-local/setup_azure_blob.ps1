# Create Azure Blob Storage only (~$1-3/mo) for home server image uploads
# Usage: .\setup_azure_blob.ps1

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$TfDir = Join-Path $Root "infra\terraform-storage"
$TfVars = Join-Path $TfDir "terraform.tfvars"
$Example = Join-Path $TfDir "terraform.tfvars.example"
$EnvHome = Join-Path $Root ".env.home"
$EnvExample = Join-Path $Root "env.home.example"

Write-Host ""
Write-Host "=== MarGem Azure Blob only (~`$1-3/mo) ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Install Azure CLI: https://aka.ms/installazurecliwindows"
}

az account show 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    az login | Out-Null
}

if (-not (Test-Path $TfVars)) {
    if (Test-Path $Example) {
        Copy-Item $Example $TfVars
        Write-Host "Created $TfVars"
        Write-Host "Edit subscription_id in terraform.tfvars, then re-run this script."
        exit 1
    }
    Write-Error "Missing $TfVars and $Example"
}

Push-Location $TfDir
try {
    if (-not (Test-Path ".terraform")) {
        terraform init
    }
    terraform apply -auto-approve
    if ($LASTEXITCODE -ne 0) {
        throw "terraform apply failed"
    }
    $conn = terraform output -raw storage_connection_string
    $rg = terraform output -raw resource_group_name
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Blob storage created in $rg" -ForegroundColor Green
Write-Host ""

if (-not (Test-Path $EnvHome)) {
    if (Test-Path $EnvExample) {
        Copy-Item $EnvExample $EnvHome
        Write-Host "Created .env.home - edit ALLOWED_HOSTS with your laptop IP."
    }
}

if (Test-Path $EnvHome) {
    $content = Get-Content $EnvHome -Raw
    if ($content -match 'AZURE_STORAGE_CONNECTION_STRING=' -and $conn) {
        $content = $content -replace 'AZURE_STORAGE_CONNECTION_STRING=.*', "AZURE_STORAGE_CONNECTION_STRING=$conn"
        Set-Content -Path $EnvHome -Value $content -NoNewline
        Write-Host "Updated AZURE_STORAGE_CONNECTION_STRING in .env.home"
    }
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Edit .env.home on the laptop (passwords + ALLOWED_HOSTS)"
Write-Host "  2. On laptop run: docker compose -f docker-compose.home.yml --env-file .env.home up -d --build"
Write-Host ""

Write-Host "Connection string (copy to laptop .env.home if needed):"
Write-Host $conn
Write-Host ""
