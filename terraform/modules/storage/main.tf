resource "azurerm_managed_disk" "minecraft" {
  name                 = "disk-${var.name_prefix}-data"
  resource_group_name  = var.resource_group_name
  location             = var.location
  storage_account_type = var.data_disk_storage_account_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  tags                 = var.tags
}

resource "random_string" "server_pack_suffix" {
  count = var.server_pack_local_path == null ? 0 : 1

  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "server_pack" {
  count = var.server_pack_local_path == null ? 0 : 1

  name                            = "st${substr(replace(var.name_prefix, "-", ""), 0, 16)}${random_string.server_pack_suffix[0].result}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
  tags                            = var.tags
}

resource "azurerm_storage_container" "server_pack" {
  count = var.server_pack_local_path == null ? 0 : 1

  name                  = "serverpacks"
  storage_account_id    = azurerm_storage_account.server_pack[0].id
  container_access_type = "private"
}

resource "azurerm_storage_blob" "server_pack" {
  count = var.server_pack_local_path == null ? 0 : 1

  name                 = var.server_pack_blob_name
  storage_container_id = azurerm_storage_container.server_pack[0].id
  type                 = "Block"
  source               = var.server_pack_local_path
  content_type         = "application/zip"
}

data "azurerm_storage_account_blob_container_sas" "server_pack" {
  count = var.server_pack_local_path == null ? 0 : 1

  connection_string = azurerm_storage_account.server_pack[0].primary_connection_string
  container_name    = azurerm_storage_container.server_pack[0].name
  https_only        = true
  start             = "2025-01-01T00:00:00Z"
  expiry            = var.server_pack_sas_expiry

  permissions {
    read   = true
    list   = true
    add    = false
    create = false
    write  = false
    delete = false
  }

  depends_on = [
    azurerm_storage_blob.server_pack,
  ]
}
