resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  name_prefix  = "margem-home-${var.subscription_alias}"
  storage_name = substr(replace("${local.name_prefix}st${random_string.suffix.result}", "-", ""), 0, 24)
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = { project = "margem", tier = "home-blob-only" }
}

resource "azurerm_storage_account" "media" {
  name                       = local.storage_name
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  account_tier               = "Standard"
  account_replication_type   = "LRS"
  account_kind               = "StorageV2"
  min_tls_version            = "TLS1_2"
  https_traffic_only_enabled = true
  shared_access_key_enabled  = true

  tags = azurerm_resource_group.rg.tags

  timeouts {
    create = "30m"
    update = "30m"
  }
}

# Azure often returns 404 on key/blob APIs for a few seconds after create.
resource "time_sleep" "after_storage_account" {
  depends_on      = [azurerm_storage_account.media]
  create_duration = "60s"
}

resource "azurerm_storage_container" "media" {
  depends_on            = [time_sleep.after_storage_account]
  name                  = "margem-media"
  storage_account_id    = azurerm_storage_account.media.id
  container_access_type = "private"
}
