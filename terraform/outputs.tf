output "resource_group_name" {
  description = "Azure resource group name."
  value       = azurerm_resource_group.this.name
}

output "public_ip_address" {
  description = "Static public IP address for Minecraft."
  value       = module.network.public_ip_address
}

output "ssh_command" {
  description = "SSH command for the VM."
  value       = "ssh ${var.admin_username}@${module.network.public_ip_address}"
}

output "minecraft_server_address" {
  description = "Minecraft multiplayer server address."
  value       = "${module.network.public_ip_address}:${var.minecraft_port}"
}

output "key_vault_name" {
  description = "Key Vault containing Minecraft bootstrap secrets."
  value       = module.security.key_vault_name
}

output "virtual_machine_id" {
  description = "Azure VM resource ID."
  value       = module.compute.virtual_machine_id
}

output "virtual_machine_name" {
  description = "Azure VM resource name."
  value       = module.compute.virtual_machine_name
}

output "data_disk_id" {
  description = "Managed data disk containing Minecraft state."
  value       = module.storage.data_disk_id
}

output "server_pack_storage_account_name" {
  description = "Storage account name used when server_pack_local_path uploads the server pack."
  value       = module.storage.server_pack_storage_account_name
}

output "server_pack_blob_url" {
  description = "Private blob URL for the uploaded server pack, without SAS."
  value       = module.storage.server_pack_blob_url
}
