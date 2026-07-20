output "subscription_id" {
  description = "Azure subscription this stack was deployed to"
  value       = var.subscription_id
}

output "subscription_alias" {
  description = "Short label for this subscription stack (sub1, sub2, ...)"
  value       = var.subscription_alias
}

output "acr_name" {
  description = "Container registry name used for this stack"
  value       = local.acr_name
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.api.connection_string
  sensitive   = true
}

output "api_url" {
  description = "Public HTTPS URL for the MarGem API"
  value       = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}

output "postgres_host" {
  description = "PostgreSQL flexible server FQDN"
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
}

output "storage_account_name" {
  description = "Blob storage account for media uploads"
  value       = azurerm_storage_account.media.name
}

output "key_vault_name" {
  description = "Key Vault name for secrets"
  value       = azurerm_key_vault.kv.name
}

output "resource_group_name" {
  description = "Deployed resource group"
  value       = azurerm_resource_group.rg.name
}

output "container_registry_login_server" {
  description = "ACR login server (if created)"
  value       = var.create_container_registry ? azurerm_container_registry.acr[0].login_server : null
}

output "database_url_hint" {
  description = "Use this format for local alembic migrations (replace password)"
  value       = "postgresql+asyncpg://${var.postgres_admin_login}:<password>@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/margem?ssl=require"
  sensitive   = true
}
