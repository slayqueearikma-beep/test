output "network_security_group_id" {
  description = "Network security group ID."
  value       = azurerm_network_security_group.this.id
}

output "managed_identity_id" {
  description = "User-assigned managed identity ID for the VM."
  value       = azurerm_user_assigned_identity.vm.id
}

output "managed_identity_client_id" {
  description = "User-assigned managed identity client ID used by cloud-init to fetch Key Vault secrets."
  value       = azurerm_user_assigned_identity.vm.client_id
}

output "managed_identity_principal_id" {
  description = "User-assigned managed identity principal ID."
  value       = azurerm_user_assigned_identity.vm.principal_id
}

output "key_vault_name" {
  description = "Key Vault name."
  value       = azurerm_key_vault.this.name
}

output "rcon_password_secret_name" {
  description = "Minecraft RCON Key Vault secret name."
  value       = azurerm_key_vault_secret.minecraft_rcon_password.name
}

output "server_pack_url_secret_name" {
  description = "Superior RPG server pack URL Key Vault secret name."
  value       = azurerm_key_vault_secret.server_pack_url.name
}
