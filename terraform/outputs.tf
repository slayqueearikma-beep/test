output "resource_group_name" {
  description = "Azure resource group name."
  value       = azurerm_resource_group.this.name
}

output "public_ip_address" {
  description = "Static public IP address for AMP and Minecraft."
  value       = module.network.public_ip_address
}

output "ssh_command" {
  description = "SSH command for the VM."
  value       = "ssh ${var.admin_username}@${module.network.public_ip_address}"
}

output "amp_panel_url" {
  description = "AMP ADS web panel URL."
  value       = "http://${module.network.public_ip_address}:${var.amp_panel_port}"
}

output "amp_minecraft_instance_url" {
  description = "AMP Minecraft instance management URL."
  value       = "http://${module.network.public_ip_address}:${var.amp_instance_port}"
}

output "minecraft_server_address" {
  description = "Minecraft multiplayer server address."
  value       = "${module.network.public_ip_address}:${var.minecraft_port}"
}

output "key_vault_name" {
  description = "Key Vault containing AMP bootstrap secrets."
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

output "generated_amp_admin_password_secret_name" {
  description = "Key Vault secret name containing the AMP admin password."
  value       = module.security.amp_admin_password_secret_name
}

output "data_disk_id" {
  description = "Managed data disk containing AMP and Minecraft state."
  value       = module.storage.data_disk_id
}
