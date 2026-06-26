output "data_disk_id" {
  description = "Minecraft managed data disk ID."
  value       = azurerm_managed_disk.minecraft.id
}

output "server_pack_blob_url" {
  description = "Private Azure Blob URL for the uploaded server pack, without SAS."
  value       = try(azurerm_storage_blob.server_pack[0].url, null)
}

output "server_pack_blob_sas_url" {
  description = "Read-only SAS URL for the uploaded server pack."
  value       = try("${azurerm_storage_blob.server_pack[0].url}${data.azurerm_storage_account_blob_container_sas.server_pack[0].sas}", null)
  sensitive   = true
}

output "server_pack_storage_account_name" {
  description = "Storage account name used for uploaded server pack."
  value       = try(azurerm_storage_account.server_pack[0].name, null)
}
