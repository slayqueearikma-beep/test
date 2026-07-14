locals {
  finops_suffix = replace(lower("${var.name_prefix}finops"), "-", "")
}

resource "azurerm_storage_account" "finops" {
  name                     = substr("st${local.finops_suffix}", 0, 24)
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "focus_cost" {
  name                  = "focus-cost"
  storage_account_id    = azurerm_storage_account.finops.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "pipeline_metrics" {
  name                  = "pipeline-metrics"
  storage_account_id    = azurerm_storage_account.finops.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "curated" {
  name                  = "curated"
  storage_account_id    = azurerm_storage_account.finops.id
  container_access_type = "private"
}

resource "azurerm_resource_group_cost_management_export" "actual_cost" {
  name                         = "${var.name_prefix}-actual-cost"
  resource_group_id            = var.resource_group_id
  recurrence_type              = var.cost_export_recurrence
  recurrence_period_start_date = time_static.export_start.rfc3339
  recurrence_period_end_date   = timeadd(time_static.export_start.rfc3339, "${24 * 365 * 5}h")
  file_format                  = "Csv"

  export_data_storage_location {
    container_id     = azurerm_storage_container.focus_cost.id
    root_folder_path = "actual-cost"
  }

  export_data_options {
    type       = "ActualCost"
    time_frame = "MonthToDate"
  }
}

resource "azurerm_resource_group_cost_management_export" "usage" {
  name                         = "${var.name_prefix}-usage"
  resource_group_id            = var.resource_group_id
  recurrence_type              = var.cost_export_recurrence
  recurrence_period_start_date = time_static.export_start.rfc3339
  recurrence_period_end_date   = timeadd(time_static.export_start.rfc3339, "${24 * 365 * 5}h")
  file_format                  = "Csv"

  export_data_storage_location {
    container_id     = azurerm_storage_container.focus_cost.id
    root_folder_path = "usage"
  }

  export_data_options {
    type       = "Usage"
    time_frame = "MonthToDate"
  }
}

resource "time_static" "export_start" {}

resource "azapi_resource" "focus_export" {
  count = var.enable_focus_export ? 1 : 0

  type      = "Microsoft.CostManagement/exports@2025-03-01"
  name      = "${var.name_prefix}-focus-export"
  parent_id = var.subscription_id
  location  = var.location

  body = {
    properties = {
      exportDescription = "SCAD FOCUS daily export"
      definition = {
        type = "FocusCost"
        dataSet = {
          configuration = {
            dataVersion = "1.0"
          }
          granularity = "Daily"
        }
        timeframe = "MonthToDate"
      }
      schedule = {
        status     = "Active"
        recurrence = var.cost_export_recurrence
        recurrencePeriod = {
          from = time_static.export_start.rfc3339
          to   = timeadd(time_static.export_start.rfc3339, "${24 * 365 * 5}h")
        }
      }
      format = "Parquet"
      deliveryInfo = {
        destination = {
          type           = "AzureBlob"
          resourceId     = azurerm_storage_account.finops.id
          container      = azurerm_storage_container.focus_cost.name
          rootFolderPath = "focus-parquet"
        }
      }
      partitionData         = true
      dataOverwriteBehavior = "OverwritePreviousReport"
      compressionMode       = "None"
    }
  }
}

resource "random_password" "sql_admin" {
  length  = 24
  special = true
}

resource "azurerm_mssql_server" "finops" {
  name                         = "sql-${local.finops_suffix}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = "scadadmin"
  administrator_login_password = random_password.sql_admin.result
  minimum_tls_version          = "1.2"
  tags                         = var.tags
}

resource "azurerm_mssql_database" "finops" {
  name           = "scad-finops"
  server_id      = azurerm_mssql_server.finops.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb    = 2
  sku_name       = "Basic"
  zone_redundant = false
  tags           = var.tags
}

resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "allow-azure-services"
  server_id        = azurerm_mssql_server.finops.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_key_vault_secret" "sql_connection_string" {
  name         = "scad-finops-sql-connection-string"
  value        = "Server=tcp:${azurerm_mssql_server.finops.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.finops.name};Persist Security Info=False;User ID=${azurerm_mssql_server.finops.administrator_login};Password=${random_password.sql_admin.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = var.key_vault_id
  tags         = var.tags
}

resource "azurerm_service_plan" "finops" {
  name                = "asp-${local.finops_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

resource "azurerm_application_insights" "finops" {
  name                = "appi-${local.finops_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = var.log_analytics_workspace_id
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "finops_function" {
  name                = "id-${local.finops_suffix}-fn"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_storage_account" "function" {
  name                     = substr("stfn${local.finops_suffix}", 0, 24)
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

data "archive_file" "function_zip" {
  depends_on = [null_resource.prepare_function]

  type        = "zip"
  source_dir  = "${path.module}/../../../../finops/ingestion-function"
  output_path = "${path.module}/build/ingestion-function.zip"
  excludes    = ["node_modules/.cache", ".git", "local.settings.json"]
}

resource "null_resource" "prepare_function" {
  triggers = {
    package_json = filemd5("${path.module}/../../../../finops/ingestion-function/package.json")
  }

  provisioner "local-exec" {
    command = "cd ${path.module}/../../../../finops/ingestion-function && npm ci --omit=dev"
  }
}

resource "azurerm_linux_function_app" "ingestion" {
  name                       = "func-${local.finops_suffix}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.finops.id
  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key
  https_only                 = true
  tags                       = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.finops_function.id]
  }

  site_config {
    application_stack {
      node_version = "20"
    }
    application_insights_connection_string = azurerm_application_insights.finops.connection_string
    application_insights_key               = azurerm_application_insights.finops.instrumentation_key
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME           = "node"
    WEBSITE_RUN_FROM_PACKAGE           = "1"
    AzureWebJobsStorage                = azurerm_storage_account.function.primary_connection_string
    SCAD_FINOPS_STORAGE_ACCOUNT        = azurerm_storage_account.finops.name
    SCAD_FINOPS_SQL_CONNECTION_STRING  = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/${azurerm_key_vault_secret.sql_connection_string.name}/)"
    PIPELINE_METRICS_CONTAINER         = azurerm_storage_container.pipeline_metrics.name
    FOCUS_COST_CONTAINER               = azurerm_storage_container.focus_cost.name
    CURATED_CONTAINER                  = azurerm_storage_container.curated.name
  }

  zip_deploy_file = data.archive_file.function_zip.output_path

  depends_on = [
    azurerm_key_vault_secret.sql_connection_string,
    azurerm_mssql_firewall_rule.allow_azure,
  ]
}

resource "azurerm_role_assignment" "function_storage_reader" {
  scope                = azurerm_storage_account.finops.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.finops_function.principal_id
}

resource "azurerm_role_assignment" "function_storage_contributor" {
  scope                = azurerm_storage_account.finops.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.finops_function.principal_id
}

resource "azurerm_role_assignment" "function_key_vault_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.finops_function.principal_id
}

resource "azurerm_eventgrid_event_subscription" "focus_blob_created" {
  name  = "${var.name_prefix}-focus-ingest"
  scope = azurerm_storage_account.finops.id

  included_event_types = ["Microsoft.Storage.BlobCreated"]

  subject_filter {
    subject_begins_with = "/blobServices/default/containers/${azurerm_storage_container.focus_cost.name}/"
  }

  azure_function_endpoint {
    function_id = "${azurerm_linux_function_app.ingestion.id}/functions/FocusIngest"
    max_events_per_batch              = 1
    preferred_batch_size_in_kilobytes = 64
  }

  depends_on = [azurerm_linux_function_app.ingestion]
}

resource "azurerm_eventgrid_event_subscription" "pipeline_metrics_created" {
  name  = "${var.name_prefix}-pipeline-metrics-ingest"
  scope = azurerm_storage_account.finops.id

  included_event_types = ["Microsoft.Storage.BlobCreated"]

  subject_filter {
    subject_begins_with = "/blobServices/default/containers/${azurerm_storage_container.pipeline_metrics.name}/"
  }

  azure_function_endpoint {
    function_id = "${azurerm_linux_function_app.ingestion.id}/functions/PipelineMetricsIngest"
    max_events_per_batch              = 5
    preferred_batch_size_in_kilobytes = 64
  }

  depends_on = [azurerm_linux_function_app.ingestion]
}

resource "azurerm_monitor_diagnostic_setting" "finops_storage" {
  name                       = "${var.name_prefix}-finops-storage-diag"
  target_resource_id         = azurerm_storage_account.finops.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "Transaction"
    enabled  = true
  }
}
