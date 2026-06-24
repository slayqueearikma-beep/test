locals {
  compact_prefix       = replace(var.name_prefix, "/[^a-z0-9]/", "")
  resource_suffix      = random_string.suffix.result
  resource_prefix      = "${var.name_prefix}-${local.resource_suffix}"
  acr_name             = substr("acr${local.compact_prefix}${local.resource_suffix}", 0, 50)
  storage_account_name = substr("st${local.compact_prefix}${local.resource_suffix}", 0, 24)
  image_name           = "${azurerm_container_registry.bot.login_server}/${var.image_repository}:${var.image_tag}"
  repo_root            = abspath("${path.module}/../..")
  source_files = sort(concat(
    [
      "Dockerfile",
      "bot.py",
      "requirements.txt",
    ],
    fileset(local.repo_root, "sevenamidelmath/**/*.py")
  ))
  source_hash = sha1(join("", [for file in local.source_files : filesha256("${local.repo_root}/${file}")]))
}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "azurerm_resource_group" "bot" {
  name     = "rg-${local.resource_prefix}"
  location = var.location

  tags = {
    app      = "7amidelmath"
    workload = "discord-bot"
    budget   = "low"
  }
}

resource "azurerm_log_analytics_workspace" "bot" {
  name                = "log-${local.resource_prefix}"
  location            = azurerm_resource_group.bot.location
  resource_group_name = azurerm_resource_group.bot.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = azurerm_resource_group.bot.tags
}

resource "azurerm_container_registry" "bot" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.bot.name
  location            = azurerm_resource_group.bot.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = azurerm_resource_group.bot.tags
}

resource "azurerm_storage_account" "bot" {
  name                            = local.storage_account_name
  resource_group_name             = azurerm_resource_group.bot.name
  location                        = azurerm_resource_group.bot.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = azurerm_resource_group.bot.tags
}

resource "azurerm_storage_share" "bot_data" {
  name               = "bot-data"
  storage_account_id = azurerm_storage_account.bot.id
  quota              = 1
}

resource "azurerm_container_app_environment" "bot" {
  name                       = "cae-${local.resource_prefix}"
  location                   = azurerm_resource_group.bot.location
  resource_group_name        = azurerm_resource_group.bot.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.bot.id

  tags = azurerm_resource_group.bot.tags
}

resource "azurerm_container_app_environment_storage" "bot_data" {
  name                         = "bot-data"
  container_app_environment_id = azurerm_container_app_environment.bot.id
  account_name                 = azurerm_storage_account.bot.name
  share_name                   = azurerm_storage_share.bot_data.name
  access_key                   = azurerm_storage_account.bot.primary_access_key
  access_mode                  = "ReadWrite"
}

resource "azurerm_user_assigned_identity" "bot" {
  name                = "id-${local.resource_prefix}"
  location            = azurerm_resource_group.bot.location
  resource_group_name = azurerm_resource_group.bot.name

  tags = azurerm_resource_group.bot.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.bot.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.bot.principal_id
}

resource "terraform_data" "build_image" {
  triggers_replace = {
    image_name  = local.image_name
    source_hash = local.source_hash
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "az acr build --registry '${azurerm_container_registry.bot.name}' --image '${var.image_repository}:${var.image_tag}' '${local.repo_root}'"
  }

  depends_on = [azurerm_container_registry.bot]
}

resource "azurerm_container_app" "bot" {
  name                         = "ca-${local.resource_prefix}"
  container_app_environment_id = azurerm_container_app_environment.bot.id
  resource_group_name          = azurerm_resource_group.bot.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.bot.id]
  }

  registry {
    server   = azurerm_container_registry.bot.login_server
    identity = azurerm_user_assigned_identity.bot.id
  }

  secret {
    name  = "discord-token"
    value = var.discord_token
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    volume {
      name         = "bot-data"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.bot_data.name
    }

    container {
      name   = "bot"
      image  = local.image_name
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name        = "DISCORD_TOKEN"
        secret_name = "discord-token"
      }

      env {
        name  = "DATABASE_PATH"
        value = "/app/data/tournaments.db"
      }

      env {
        name  = "AUTO_SYNC_COMMANDS"
        value = tostring(var.auto_sync_commands)
      }

      dynamic "env" {
        for_each = var.guild_id == "" ? [] : [var.guild_id]
        content {
          name  = "GUILD_ID"
          value = env.value
        }
      }

      volume_mounts {
        name = "bot-data"
        path = "/app/data"
      }
    }
  }

  tags = azurerm_resource_group.bot.tags

  depends_on = [
    azurerm_container_app_environment_storage.bot_data,
    azurerm_role_assignment.acr_pull,
    terraform_data.build_image,
  ]
}
