output "storage_account_name" {
  value = azurerm_storage_account.media.name
}

output "storage_connection_string" {
  value     = azurerm_storage_account.media.primary_connection_string
  sensitive = true
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "estimated_monthly_cost" {
  value = "~$1-3 USD for blob storage only (pay per GB stored + transfers)"
}
