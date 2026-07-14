module "finops" {
  source = "./modules/finops"
  count  = var.enable_finops ? 1 : 0

  resource_group_name        = azurerm_resource_group.this.name
  resource_group_id          = azurerm_resource_group.this.id
  location                   = azurerm_resource_group.this.location
  subscription_id            = data.azurerm_client_config.current.subscription_id
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  tags                       = local.tags
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  key_vault_id               = azurerm_key_vault.this.id
  key_vault_uri              = azurerm_key_vault.this.vault_uri
  name_prefix                = var.project_name
  enable_focus_export        = var.enable_focus_export
}

resource "azurerm_role_assignment" "ci_pipeline_metrics_writer" {
  count = var.enable_finops && var.ci_principal_id != "" ? 1 : 0

  scope                = module.finops[0].storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.ci_principal_id
}
