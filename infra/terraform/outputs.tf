output "resource_group_name" {
  description = "Resource group containing the bot hosting resources."
  value       = azurerm_resource_group.bot.name
}

output "container_app_name" {
  description = "Azure Container App running the Discord bot."
  value       = azurerm_container_app.bot.name
}

output "container_registry_login_server" {
  description = "Azure Container Registry login server used for bot images."
  value       = azurerm_container_registry.bot.login_server
}

output "deployed_image" {
  description = "Container image deployed to the bot."
  value       = local.image_name
}

output "database_file_share" {
  description = "Azure Files share mounted at /app/data for SQLite persistence."
  value       = azurerm_storage_share.bot_data.name
}
