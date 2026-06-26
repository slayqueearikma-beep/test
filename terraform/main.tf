data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

module "security" {
  source = "./modules/security"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  current_object_id   = data.azurerm_client_config.current.object_id
  tags                = local.common_tags

  admin_ssh_source_cidrs = var.admin_ssh_source_cidrs
  amp_panel_source_cidrs = var.amp_panel_source_cidrs
  minecraft_source_cidrs = var.minecraft_source_cidrs
  enable_http_https      = var.enable_http_https
  amp_panel_port         = var.amp_panel_port
  amp_instance_port      = var.amp_instance_port
  minecraft_port         = var.minecraft_port

  amp_license_key              = var.amp_license_key
  amp_admin_username           = var.amp_admin_username
  amp_admin_password           = local.amp_admin_password
  minecraft_rcon_password      = random_password.minecraft_rcon_password.result
  superior_rpg_server_pack_url = var.superior_rpg_server_pack_url
}

module "network" {
  source = "./modules/network"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.common_tags

  address_space   = var.address_space
  subnet_prefixes = var.subnet_prefixes
  nsg_id          = module.security.network_security_group_id
}

module "storage" {
  source = "./modules/storage"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.common_tags

  data_disk_size_gb              = var.data_disk_size_gb
  data_disk_storage_account_type = var.data_disk_storage_account_type
}

module "compute" {
  source = "./modules/compute"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.common_tags

  admin_username               = var.admin_username
  ssh_public_key               = var.ssh_public_key
  vm_size                      = var.vm_size
  network_interface_id         = module.network.network_interface_id
  managed_identity_ids         = [module.security.managed_identity_id]
  os_disk_size_gb              = var.os_disk_size_gb
  os_disk_storage_account_type = var.os_disk_storage_account_type
  data_disk_id                 = module.storage.data_disk_id
  data_disk_caching            = var.data_disk_caching
  custom_data                  = local.cloud_init
}
