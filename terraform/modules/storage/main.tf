resource "azurerm_managed_disk" "minecraft" {
  name                 = "disk-${var.name_prefix}-data"
  resource_group_name  = var.resource_group_name
  location             = var.location
  storage_account_type = var.data_disk_storage_account_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  tags                 = var.tags
}
