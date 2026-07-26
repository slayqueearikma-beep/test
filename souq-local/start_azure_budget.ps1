# MarGem — cheapest Azure deploy (1 small VM + blob storage)
# Usage: .\start_azure_budget.ps1
#        .\start_azure_budget.ps1 -InfraOnly   # terraform only, skip app deploy

param(
    [switch]$InfraOnly,
    [Parameter(Mandatory = $false)][string]$SmtpHost = $env:SMTP_HOST,
    [Parameter(Mandatory = $false)][string]$SmtpUsername = $env:SMTP_USERNAME,
    [Parameter(Mandatory = $false)][string]$SmtpPassword = $env:SMTP_PASSWORD,
    [Parameter(Mandatory = $false)][string]$SmtpFrom = $env:SMTP_FROM
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$TfDir = Join-Path $Root "infra\terraform-budget"
$TfVars = Join-Path $TfDir "terraform.tfvars"
$TfExample = Join-Path $TfDir "terraform.tfvars.example"
$SshKey = Join-Path $env:USERPROFILE ".ssh\id_rsa"
$SshPub = "$SshKey.pub"

function Get-TfVarValue {
    param([string]$Path, [string]$Name, [string]$Default = "")
    $line = Select-String -Path $Path -Pattern "^\s*$Name\s*=" | Select-Object -First 1
    if ($line -match '=\s*"(.*)"') { return $Matches[1] }
    if ($Default) { return $Default }
    throw "Missing $Name in $Path"
}

Write-Host ""
Write-Host "=== MarGem Budget Azure Deploy ===" -ForegroundColor Cyan
Write-Host "  ~`$15-25/month (1 VM + storage)" -ForegroundColor DarkGray
Write-Host ""

foreach ($cmd in @("az", "terraform", "ssh", "scp")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "Missing '$cmd'. Install Azure CLI, Terraform, and OpenSSH client."
    }
}

az account show 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Logging into Azure..."
    az login | Out-Null
}

if (-not (Test-Path $TfVars)) {
    if (Test-Path $TfExample) {
        Copy-Item $TfExample $TfVars
        Write-Host "Created $TfVars — edit subscription_id, ssh_public_key, passwords, then re-run."
        exit 1
    }
    Write-Error "Missing $TfVars"
}

if (-not (Test-Path $SshKey)) {
    Write-Error "SSH private key not found at $SshKey — run: ssh-keygen -t rsa -b 4096"
}

Push-Location $TfDir
try {
    if (-not (Test-Path ".terraform")) { terraform init }
    Write-Host "[1/4] Creating Azure resources (VM + storage)..."
    terraform apply -auto-approve
    if ($LASTEXITCODE -ne 0) { throw "terraform apply failed" }

    $vmIp = terraform output -raw vm_public_ip
    $apiUrl = terraform output -raw api_url
    $storageConn = terraform output -raw storage_connection_string
}
finally {
    Pop-Location
}

$adminUser = Get-TfVarValue -Path $TfVars -Name "admin_username" -Default "azureuser"
$pgPass = Get-TfVarValue -Path $TfVars -Name "postgres_password"
$jwt = Get-TfVarValue -Path $TfVars -Name "jwt_secret_key"
$uploadTokenSecret = Get-TfVarValue -Path $TfVars -Name "upload_token_secret"

Write-Host ""
Write-Host "  VM IP:   $vmIp"
Write-Host "  API URL: $apiUrl"
Write-Host ""

if ($InfraOnly) {
    Write-Host "Infra only (-InfraOnly). Deploy app later with: .\start_azure_budget.ps1"
    exit 0
}

if ([string]::IsNullOrWhiteSpace($SmtpHost)) {
    throw "SMTP is required for a production deploy. Set SMTP_HOST/SMTP_USERNAME/SMTP_PASSWORD/SMTP_FROM environment variables or pass -SmtpHost."
}

Write-Host "[2/4] Waiting for VM + Docker (up to 3 min)..."
$sshReady = $false
for ($i = 1; $i -le 36; $i++) {
    ssh -i $SshKey -o StrictHostKeyChecking=no -o ConnectTimeout=5 `
        "${adminUser}@${vmIp}" "docker compose version" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $sshReady = $true
        break
    }
    Start-Sleep -Seconds 5
}
if (-not $sshReady) {
    Write-Error "SSH/Docker not ready. Wait 2 min and run: .\start_azure_budget.ps1"
}

$envContent = @"
POSTGRES_PASSWORD=$pgPass
JWT_SECRET_KEY=$jwt
UPLOAD_TOKEN_SECRET=$uploadTokenSecret
AZURE_STORAGE_CONNECTION_STRING=$storageConn
CORS_ORIGINS=["http://${vmIp}:8000"]
ALLOWED_HOSTS=["${vmIp}","${vmIp}:8000"]
SMTP_HOST=$SmtpHost
SMTP_USERNAME=$SmtpUsername
SMTP_PASSWORD=$SmtpPassword
SMTP_FROM=$SmtpFrom
"@
$envFile = Join-Path $Root ".budget-deploy.env"
Set-Content -Path $envFile -Value $envContent -NoNewline

Write-Host "[3/4] Uploading app to VM..."
ssh -i $SshKey -o StrictHostKeyChecking=no "${adminUser}@${vmIp}" "mkdir -p ~/margem/backend"
scp -i $SshKey -o StrictHostKeyChecking=no `
    (Join-Path $Root "docker-compose.budget.yml") `
    "${adminUser}@${vmIp}:~/margem/docker-compose.budget.yml"
scp -i $SshKey -o StrictHostKeyChecking=no `
    $envFile "${adminUser}@${vmIp}:~/margem/.env"

$backendSrc = Join-Path $Root "backend"
scp -i $SshKey -o StrictHostKeyChecking=no -r `
    "$backendSrc\app" `
    "$backendSrc\scripts" `
    "$backendSrc\alembic" `
    "$backendSrc\alembic.ini" `
    "$backendSrc\requirements.txt" `
    "$backendSrc\Dockerfile" `
    "${adminUser}@${vmIp}:~/margem/backend/"

Write-Host "[4/4] Building and starting containers..."
ssh -i $SshKey -o StrictHostKeyChecking=no "${adminUser}@${vmIp}" `
    "cd ~/margem && docker compose -f docker-compose.budget.yml --env-file .env up -d --build"

Start-Sleep -Seconds 10
try {
    $health = Invoke-WebRequest -Uri "$apiUrl/health" -UseBasicParsing -TimeoutSec 20
    if ($health.StatusCode -eq 200) {
        Write-Host ""
        Write-Host "=== Budget deploy OK ===" -ForegroundColor Green
    }
}
catch {
    Write-Warning "API not up yet. Logs: ssh ${adminUser}@${vmIp} 'cd margem && docker compose -f docker-compose.budget.yml logs api'"
}

Write-Host ""
Write-Host "API URL:  $apiUrl"
Write-Host "Flutter:  flutter run --dart-define=API_BASE_URL=$apiUrl"
Write-Host ""
Write-Host "Pause billing: .\stop_azure_budget.ps1 -Deallocate"
Write-Host "Delete all:    .\stop_azure_budget.ps1 -Destroy"
Write-Host ""

Remove-Item $envFile -Force -ErrorAction SilentlyContinue
