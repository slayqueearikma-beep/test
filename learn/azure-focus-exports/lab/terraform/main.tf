terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

data "azurerm_client_config" "current" {}

resource "time_static" "export_start" {}

resource "azurerm_resource_group" "focus_lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "focus_lab" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.focus_lab.name
  location                 = azurerm_resource_group.focus_lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_storage_container" "focus_exports" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.focus_lab.id
  container_access_type = "private"
}

# ActualCost export at resource-group scope (CSV) — compare with FOCUS Parquet below.
resource "azurerm_resource_group_cost_management_export" "actual_cost" {
  name                         = var.actual_cost_export_name
  resource_group_id            = azurerm_resource_group.focus_lab.id
  recurrence_type              = "Daily"
  recurrence_period_start_date = time_static.export_start.rfc3339
  recurrence_period_end_date   = timeadd(time_static.export_start.rfc3339, "${24 * 365 * 5}h")
  file_format                  = "Csv"

  export_data_storage_location {
    container_id     = azurerm_storage_container.focus_exports.id
    root_folder_path = "actual-cost"
  }

  export_data_options {
    type       = "ActualCost"
    time_frame = "MonthToDate"
  }
}

# FOCUS export — same AzAPI pattern as infrastructure/terraform/modules/finops/main.tf
resource "azapi_resource" "focus_export" {
  type      = "Microsoft.CostManagement/exports@2025-03-01"
  name      = var.focus_export_name
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  location  = var.location

  body = {
    properties = {
      exportDescription = "FOCUS learning lab export"
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
        recurrence = "Daily"
        recurrencePeriod = {
          from = time_static.export_start.rfc3339
          to   = timeadd(time_static.export_start.rfc3339, "${24 * 365 * 5}h")
        }
      }
      format = "Parquet"
      deliveryInfo = {
        destination = {
          type           = "AzureBlob"
          resourceId     = azurerm_storage_account.focus_lab.id
          container      = azurerm_storage_container.focus_exports.name
          rootFolderPath = "focus-parquet"
        }
      }
      partitionData         = true
      dataOverwriteBehavior = "OverwritePreviousReport"
      compressionMode       = "None"
    }
  }

  response_export_values = ["properties"]
}

output "resource_group_name" {
  value = azurerm_resource_group.focus_lab.name
}

output "storage_account_name" {
  value = azurerm_storage_account.focus_lab.name
}

output "container_name" {
  value = azurerm_storage_container.focus_exports.name
}

output "focus_export_path" {
  value = "focus-parquet/"
}

output "actual_cost_path" {
  value = "actual-cost/"
}

output "portal_exports_url" {
  value = "https://portal.azure.com/#view/Microsoft_Azure_CostManagement/Menu/~/costmanagementexports"
}

output "subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}

output "focus_export_name" {
  value = azapi_resource.focus_export.name
}

output "focus_export_id" {
  value = azapi_resource.focus_export.id
}

output "actual_cost_export_name" {
  value = azurerm_resource_group_cost_management_export.actual_cost.name
}

output "verify_commands" {
  value = <<-EOT
    # List exports (use 2025 API — az costmanagement export list may miss FOCUS):
    az rest --method GET --uri "https://management.azure.com/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.CostManagement/exports?api-version=2025-03-01"

    # FOCUS run history:
    az rest --method GET --uri "https://management.azure.com/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.CostManagement/exports/${var.focus_export_name}/runHistory?api-version=2025-03-01"

    # List blob files:
    az storage blob list --account-name ${azurerm_storage_account.focus_lab.name} --container-name ${azurerm_storage_container.focus_exports.name} --prefix focus-parquet/ --auth-mode login -o table
  EOT
}
