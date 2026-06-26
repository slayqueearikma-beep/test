resource "random_string" "key_vault_suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  key_vault_name = "kv${substr(replace(var.name_prefix, "-", ""), 0, 15)}${random_string.key_vault_suffix.result}"
}

resource "azurerm_user_assigned_identity" "vm" {
  name                = "id-${var.name_prefix}-vm"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  security_rule {
    name                       = "Allow-SSH-Admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.admin_ssh_source_cidrs
    destination_address_prefix = "*"
    description                = "Administrative SSH. Restrict to trusted administrator public IP ranges."
  }

  security_rule {
    name                       = "Allow-AMP-ADS-Admin"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.amp_panel_port)
    source_address_prefixes    = var.amp_panel_source_cidrs
    destination_address_prefix = "*"
    description                = "CubeCoders AMP ADS web panel. Restrict to administrators."
  }

  security_rule {
    name                       = "Allow-AMP-Minecraft-Admin"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.amp_instance_port)
    source_address_prefixes    = var.amp_panel_source_cidrs
    destination_address_prefix = "*"
    description                = "AMP management endpoint for the Minecraft instance. Restrict to administrators."
  }

  security_rule {
    name                       = "Allow-Minecraft-Public"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.minecraft_port)
    source_address_prefixes    = var.minecraft_source_cidrs
    destination_address_prefix = "*"
    description                = "Public Minecraft Java gameplay traffic."
  }

  dynamic "security_rule" {
    for_each = var.enable_http_https ? toset(["80", "443"]) : toset([])

    content {
      name                       = "Allow-Web-${security_rule.value}"
      priority                   = security_rule.value == "80" ? 140 : 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Optional HTTP/HTTPS reverse proxy traffic."
    }
  }
}

resource "azurerm_key_vault" "this" {
  name                       = local.key_vault_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.tags

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }

  access_policy {
    tenant_id = var.tenant_id
    object_id = var.current_object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
      "Recover",
      "Backup",
      "Restore",
    ]
  }

  access_policy {
    tenant_id = var.tenant_id
    object_id = azurerm_user_assigned_identity.vm.principal_id

    secret_permissions = [
      "Get",
      "List",
    ]
  }
}

resource "azurerm_key_vault_secret" "amp_license_key" {
  name         = "amp-license-key"
  value        = var.amp_license_key
  key_vault_id = azurerm_key_vault.this.id
  content_type = "CubeCoders AMP license key"
}

resource "azurerm_key_vault_secret" "amp_admin_username" {
  name         = "amp-admin-username"
  value        = var.amp_admin_username
  key_vault_id = azurerm_key_vault.this.id
  content_type = "CubeCoders AMP administrator username"
}

resource "azurerm_key_vault_secret" "amp_admin_password" {
  name         = "amp-admin-password"
  value        = var.amp_admin_password
  key_vault_id = azurerm_key_vault.this.id
  content_type = "CubeCoders AMP administrator password"
}

resource "azurerm_key_vault_secret" "minecraft_rcon_password" {
  name         = "minecraft-rcon-password"
  value        = var.minecraft_rcon_password
  key_vault_id = azurerm_key_vault.this.id
  content_type = "Local-only Minecraft RCON password for health checks"
}

resource "azurerm_key_vault_secret" "server_pack_url" {
  name         = "superior-rpg-server-pack-url"
  value        = var.superior_rpg_server_pack_url
  key_vault_id = azurerm_key_vault.this.id
  content_type = "Superior RPG server pack HTTPS URL"
}
