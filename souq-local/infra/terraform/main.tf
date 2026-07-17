resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  name_prefix  = "margem-${var.environment_name}"
  storage_name = substr(replace("${local.name_prefix}media${random_string.suffix.result}", "-", ""), 0, 24)
  key_vault_name = substr("${local.name_prefix}-kv-${random_string.suffix.result}", 0, 24)
  database_url = "postgresql+asyncpg://${var.postgres_admin_login}:${var.postgres_admin_password}@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/margem?ssl=require"
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    project     = "margem"
    environment = var.environment_name
    managed_by  = "terraform"
  }
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

  tags = azurerm_resource_group.rg.tags
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
  allow_nested_items_to_be_public = false

  tags = azurerm_resource_group.rg.tags
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
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  rbac_authorization_enabled = true

  tags = azurerm_resource_group.rg.tags
}

# --- Container Registry (optional) ---
resource "azurerm_container_registry" "acr" {
  count               = var.create_container_registry ? 1 : 0
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = azurerm_resource_group.rg.tags
}

# --- Container Apps ---
resource "azurerm_container_app_environment" "env" {
  name                       = "${local.name_prefix}-cae"
  location                   = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  log_analytics_workspace_id = null

  tags = azurerm_resource_group.rg.tags
}

resource "azurerm_container_app" "api" {
  name                         = "${local.name_prefix}-api"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  tags = azurerm_resource_group.rg.tags

  secret {
    name  = "database-url"
    value = local.database_url
  }

  secret {
    name  = "jwt-secret"
    value = var.jwt_secret_key
  }

  secret {
    name  = "storage-conn"
    value = azurerm_storage_account.media.primary_connection_string
  }

  template {
    min_replicas = 0
    max_replicas = 3

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
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
