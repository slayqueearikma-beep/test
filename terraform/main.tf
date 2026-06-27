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
  minecraft_source_cidrs = var.minecraft_source_cidrs
  enable_http_https      = var.enable_http_https
  minecraft_port         = var.minecraft_port

  minecraft_rcon_password      = random_password.minecraft_rcon_password.result
  superior_rpg_server_pack_url = local.server_pack_download_url
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
  server_pack_local_path         = var.server_pack_local_path
  server_pack_blob_name          = var.server_pack_blob_name
  server_pack_sas_expiry         = var.server_pack_sas_expiry
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

resource "azurerm_role_assignment" "vm_self_deallocate" {
  count = var.enable_idle_shutdown ? 1 : 0

  scope                            = module.compute.virtual_machine_id
  role_definition_name             = "Virtual Machine Contributor"
  principal_id                     = module.security.managed_identity_principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
