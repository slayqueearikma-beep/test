output "storage_account_name" {
  description = "FinOps storage account name."
  value       = azurerm_storage_account.finops.name
}

output "storage_account_id" {
  description = "FinOps storage account resource ID."
  value       = azurerm_storage_account.finops.id
}

output "focus_cost_container" {
  description = "Container for cost exports."
  value       = azurerm_storage_container.focus_cost.name
}

output "pipeline_metrics_container" {
  description = "Container for CI/CD pipeline metrics JSON."
  value       = azurerm_storage_container.pipeline_metrics.name
}

output "curated_container" {
  description = "Container for normalized analytics files."
  value       = azurerm_storage_container.curated.name
}

output "sql_server_fqdn" {
  description = "Azure SQL server FQDN for Power BI."
  value       = azurerm_mssql_server.finops.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Azure SQL database name."
  value       = azurerm_mssql_database.finops.name
}

output "function_app_name" {
  description = "FinOps ingestion function app name."
  value       = azurerm_linux_function_app.ingestion.name
}

output "application_insights_connection_string" {
  description = "Application Insights connection string for FinOps ingestion."
  value       = azurerm_application_insights.finops.connection_string
  sensitive   = true
}

output "actual_cost_export_name" {
  description = "Resource group actual cost export name."
  value       = azurerm_resource_group_cost_management_export.actual_cost.name
}

output "focus_export_name" {
  description = "FOCUS export name when enabled."
  value       = var.enable_focus_export ? azapi_resource.focus_export[0].name : null
}
