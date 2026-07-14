output "resource_group_name" {
  description = "Name of the Azure resource group."
  value       = azurerm_resource_group.this.name
}

output "container_registry_login_server" {
  description = "Azure Container Registry login server."
  value       = azurerm_container_registry.this.login_server
}

output "container_app_url" {
  description = "Public URL of the SCAD API."
  value       = "https://${azurerm_container_app.api.latest_revision_fqdn}"
}

output "key_vault_name" {
  description = "Name of the Azure Key Vault."
  value       = azurerm_key_vault.this.name
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.name
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "finops_storage_account_name" {
  description = "FinOps storage account for cost exports and pipeline metrics."
  value       = var.enable_finops ? module.finops[0].storage_account_name : null
}

output "finops_pipeline_metrics_container" {
  description = "Blob container for CI/CD pipeline metrics JSON."
  value       = var.enable_finops ? module.finops[0].pipeline_metrics_container : null
}

output "finops_sql_server_fqdn" {
  description = "Azure SQL server for Power BI / Fabric analytics."
  value       = var.enable_finops ? module.finops[0].sql_server_fqdn : null
}

output "finops_sql_database_name" {
  description = "Azure SQL database for analytics."
  value       = var.enable_finops ? module.finops[0].sql_database_name : null
}

output "finops_function_app_name" {
  description = "FinOps ingestion Azure Function name."
  value       = var.enable_finops ? module.finops[0].function_app_name : null
}

