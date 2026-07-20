# Shared helpers for subscription migration scripts (PowerShell)

function Get-SubAlias {
    param([int]$Sub)
    return "sub$Sub"
}

function Get-TerraformDir {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-SubPaths {
    param([int]$Sub)
    $alias = Get-SubAlias -Sub $Sub
    $terraformDir = Get-TerraformDir
    return [PSCustomObject]@{
        Alias        = $alias
        Tfvars       = Join-Path $terraformDir "subscriptions\$alias.tfvars"
        Example      = Join-Path $terraformDir "subscriptions\$alias.tfvars.example"
        State        = Join-Path $terraformDir "terraform-$alias.tfstate"
        BackupDir    = Join-Path $terraformDir "backups\$alias"
        DatabaseDump = Join-Path $terraformDir "backups\$alias\margem.dump"
        BlobsDir     = Join-Path $terraformDir "backups\$alias\blobs"
        TerraformDir = $terraformDir
    }
}

function Get-TfVarValue {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Default = ""
    )
    if (-not (Test-Path $Path)) {
        if ($Default) { return $Default }
        throw "Missing tfvars file: $Path"
    }
    $content = Get-Content $Path -Raw
    if ($content -match "(?m)^\s*$([regex]::Escape($Name))\s*=\s*""([^""]*)""") {
        return $Matches[2]
    }
    if ($content -match "(?m)^\s*$([regex]::Escape($Name))\s*=\s*([^\s#]+)") {
        return $Matches[2].Trim()
    }
    if ($Default) { return $Default }
    throw "Variable '$Name' not found in $Path"
}

function Get-TerraformOutputValue {
    param(
        [string]$State,
        [string]$Name,
        [string]$TerraformDir
    )
    Push-Location $TerraformDir
    try {
        $value = terraform output -state=$State -raw $Name 2>$null
        if (-not $value) { throw "terraform output '$Name' failed (is $State deployed?)" }
        return $value.Trim()
    }
    finally {
        Pop-Location
    }
}

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-PgDump {
    param(
        [string]$ConnectionUri,
        [string]$OutputFile
    )
    $parent = Split-Path $OutputFile -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (Test-CommandExists "pg_dump") {
        & pg_dump $ConnectionUri -Fc -f $OutputFile
    }
    elseif (Test-CommandExists "docker") {
        $dir = (Resolve-Path $parent).Path
        $file = Split-Path $OutputFile -Leaf
        docker run --rm -v "${dir}:/backup" postgres:16 `
            pg_dump $ConnectionUri -Fc -f "/backup/$file"
    }
    else {
        throw "Install PostgreSQL client tools (pg_dump) or Docker to back up the database."
    }
}

function Invoke-PgRestore {
    param(
        [string]$ConnectionUri,
        [string]$DumpFile
    )
    if (-not (Test-Path $DumpFile)) {
        throw "Database dump not found: $DumpFile"
    }

    if (Test-CommandExists "pg_restore") {
        & pg_restore --clean --if-exists --no-owner --no-acl -d $ConnectionUri $DumpFile
        if ($LASTEXITCODE -gt 1) { throw "pg_restore failed with exit code $LASTEXITCODE" }
    }
    elseif (Test-CommandExists "docker") {
        $dir = (Resolve-Path (Split-Path $DumpFile -Parent)).Path
        $file = Split-Path $DumpFile -Leaf
        docker run --rm -v "${dir}:/backup" postgres:16 `
            pg_restore --clean --if-exists --no-owner --no-acl -d $ConnectionUri "/backup/$file"
        if ($LASTEXITCODE -gt 1) { throw "pg_restore failed with exit code $LASTEXITCODE" }
    }
    else {
        throw "Install PostgreSQL client tools (pg_restore) or Docker to restore the database."
    }
}

function Get-PostgresConnectionUri {
    param(
        [int]$Sub
    )
    $paths = Get-SubPaths -Sub $Sub
    $pgHost = Get-TerraformOutputValue -State $paths.State -Name "postgres_host" -TerraformDir $paths.TerraformDir
    $login = Get-TfVarValue -Path $paths.Tfvars -Name "postgres_admin_login" -Default "margemadmin"
    $password = Get-TfVarValue -Path $paths.Tfvars -Name "postgres_admin_password"
    return "postgresql://${login}:$([uri]::EscapeDataString($password))@${pgHost}:5432/margem?sslmode=require"
}

function Backup-SubscriptionBlobs {
    param([int]$Sub)

    $paths = Get-SubPaths -Sub $Sub
    $storage = Get-TerraformOutputValue -State $paths.State -Name "storage_account_name" -TerraformDir $paths.TerraformDir
    $rg = Get-TerraformOutputValue -State $paths.State -Name "resource_group_name" -TerraformDir $paths.TerraformDir

    if (-not (Test-Path $paths.BlobsDir)) {
        New-Item -ItemType Directory -Path $paths.BlobsDir -Force | Out-Null
    }

    $conn = az storage account show-connection-string `
        --resource-group $rg `
        --name $storage `
        --query connectionString -o tsv

    if (-not $conn) { throw "Could not read storage connection string for $storage" }

    az storage blob download-batch `
        --destination $paths.BlobsDir `
        --source margem-media `
        --connection-string $conn `
        --pattern "*" | Out-Null
}

function Restore-SubscriptionBlobsToTarget {
    param(
        [int]$FromSub,
        [int]$ToSub
    )
    $fromPaths = Get-SubPaths -Sub $FromSub
    $toPaths = Get-SubPaths -Sub $ToSub

    if (-not (Test-Path $fromPaths.BlobsDir)) {
        Write-Host "No blob backup at $($fromPaths.BlobsDir) — skipping media restore."
        return
    }

    $storage = Get-TerraformOutputValue -State $toPaths.State -Name "storage_account_name" -TerraformDir $toPaths.TerraformDir
    $rg = Get-TerraformOutputValue -State $toPaths.State -Name "resource_group_name" -TerraformDir $toPaths.TerraformDir

    $conn = az storage account show-connection-string `
        --resource-group $rg `
        --name $storage `
        --query connectionString -o tsv

    az storage blob upload-batch `
        --destination margem-media `
        --source $fromPaths.BlobsDir `
        --connection-string $conn `
        --overwrite true | Out-Null
}

function Copy-JwtSecretFromPreviousSub {
    param(
        [int]$FromSub,
        [int]$ToSub
    )
    $from = Get-SubPaths -Sub $FromSub
    $to = Get-SubPaths -Sub $ToSub
    $jwt = Get-TfVarValue -Path $from.Tfvars -Name "jwt_secret_key"
    $content = Get-Content $to.Tfvars -Raw
    if ($content -match '(?m)^\s*jwt_secret_key\s*=') {
        $content = [regex]::Replace($content, '(?m)^\s*jwt_secret_key\s*=.*$', "jwt_secret_key          = `"$jwt`"")
    }
    else {
        $content += "`njwt_secret_key          = `"$jwt`"`n"
    }
    Set-Content -Path $to.Tfvars -Value $content -NoNewline
    Write-Host "Copied jwt_secret_key from sub$FromSub → sub$ToSub (users stay logged in after migration)."
}
