resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : "rg-margem-${var.environment_name}-${var.subscription_alias}"
  name_prefix         = "margem-${var.environment_name}-${var.subscription_alias}"
  acr_name            = var.acr_name != "" ? var.acr_name : "margemreg${var.subscription_alias}"
  storage_name        = substr(replace("${local.name_prefix}media${random_string.suffix.result}", "-", ""), 0, 24)
  key_vault_name      = substr("${local.name_prefix}-kv-${random_string.suffix.result}", 0, 24)
  database_url        = "postgresql+asyncpg://${var.postgres_admin_login}:${var.postgres_admin_password}@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/margem?ssl=require"

  common_tags = {
    project             = "margem"
    environment         = var.environment_name
    subscription_alias  = var.subscription_alias
    subscription_id     = var.subscription_id
    managed_by          = "terraform"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# --- PostgreSQL Flexible Server ---
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                   = "${local.name_prefix}-pg"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = "16"
  administrator_login    = var.postgres_admin_login
  administrator_password = var.postgres_admin_password
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
  backup_retention_days  = 7
  geo_redundant_backup_enabled = false

  tags = local.common_tags
}

resource "azurerm_postgresql_flexible_server_database" "margem" {
  name      = "margem"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# --- Blob Storage ---
resource "azurerm_storage_account" "media" {
  name                     = local.storage_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"
  min_tls_version          = "TLS1_2"
  https_traffic_only_enabled = true
  allow_nested_items_to_be_public = false

  tags = local.common_tags
}

resource "azurerm_storage_container" "media" {
  name                  = "margem-media"
  storage_account_id    = azurerm_storage_account.media.id
  container_access_type = "private"
}

# --- Key Vault ---
resource "azurerm_key_vault" "kv" {
  name                       = local.key_vault_name
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 90
  purge_protection_enabled   = var.enable_key_vault_purge_protection
  rbac_authorization_enabled = true

  tags = local.common_tags
}

# --- Container Registry (optional) ---
resource "azurerm_container_registry" "acr" {
  count               = var.create_container_registry ? 1 : 0
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = local.common_tags
}

# --- Log Analytics (required for Container Apps) ---
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "${local.name_prefix}-logs"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}

# --- Container Apps ---
resource "azurerm_container_app_environment" "env" {
  name                       = "${local.name_prefix}-cae"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id

  tags = local.common_tags
}

resource "azurerm_container_app" "api" {
  name                         = "${local.name_prefix}-api"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.api.id]
  }

  tags = local.common_tags

  dynamic "registry" {
    for_each = var.create_container_registry ? [1] : []
    content {
      server   = azurerm_container_registry.acr[0].login_server
      identity = azurerm_user_assigned_identity.api.id
    }
  }

  secret {
    name                = "database-url"
    key_vault_secret_id = azurerm_key_vault_secret.database_url.versionless_id
    identity            = azurerm_user_assigned_identity.api.id
  }

  secret {
    name                = "jwt-secret"
    key_vault_secret_id = azurerm_key_vault_secret.jwt_secret.versionless_id
    identity            = azurerm_user_assigned_identity.api.id
  }

  secret {
    name                = "storage-conn"
    key_vault_secret_id = azurerm_key_vault_secret.storage_connection.versionless_id
    identity            = azurerm_user_assigned_identity.api.id
  }

  secret {
    name                = "smtp-password"
    key_vault_secret_id = azurerm_key_vault_secret.smtp_password.versionless_id
    identity            = azurerm_user_assigned_identity.api.id
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = 1

    container {
      name   = "margem-api"
      image  = var.api_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "APP_ENV"
        value = var.environment_name
      }
      env {
        name  = "DEBUG"
        value = "false"
      }
      env {
        name  = "AUTH_DEV_BYPASS"
        value = "false"
      }
      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }
      env {
        name        = "JWT_SECRET_KEY"
        secret_name = "jwt-secret"
      }
      env {
        name        = "AZURE_STORAGE_CONNECTION_STRING"
        secret_name = "storage-conn"
      }
      env {
        name  = "AZURE_STORAGE_CONTAINER"
        value = azurerm_storage_container.media.name
      }
      env {
        name  = "CORS_ORIGINS"
        value = var.cors_origins
      }
      env {
        name  = "ALLOWED_HOSTS"
        value = var.allowed_hosts
      }
      env {
        name  = "JWT_ACCESS_EXPIRE_MINUTES"
        value = "60"
      }
      env {
        name  = "JWT_REFRESH_EXPIRE_DAYS"
        value = "7"
      }
      env {
        name  = "AUTH_RATE_LIMIT"
        value = "30/minute"
      }
      env {
        name  = "RATE_LIMIT"
        value = "300/minute"
      }
      env {
        name  = "PUBLIC_APP_URL"
        value = var.public_app_url
      }
      env {
        name  = "PUBLIC_API_URL"
        value = var.public_api_url
      }
      env {
        name  = "SMTP_HOST"
        value = var.smtp_host
      }
      env {
        name  = "SMTP_PORT"
        value = tostring(var.smtp_port)
      }
      env {
        name  = "SMTP_USERNAME"
        value = var.smtp_username
      }
      env {
        name        = "SMTP_PASSWORD"
        secret_name = "smtp-password"
      }
      env {
        name  = "SMTP_FROM"
        value = var.smtp_from
      }
      env {
        name  = "SMTP_USE_TLS"
        value = tostring(var.smtp_use_tls)
      }
      env {
        name  = "ALLOW_INSECURE_EMAIL_FALLBACK"
        value = "false"
      }
      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.api.connection_string
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "auto"
    allow_insecure_connections = false

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  depends_on = [
    azurerm_role_assignment.api_key_vault_secrets_user,
    azurerm_key_vault_secret.database_url,
    azurerm_key_vault_secret.jwt_secret,
    azurerm_key_vault_secret.storage_connection,
    azurerm_key_vault_secret.smtp_password,
  ]
}
