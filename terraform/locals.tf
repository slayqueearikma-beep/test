locals {
  name_prefix = lower(replace("${var.project_name}-${var.environment}", "/[^a-z0-9-]/", "-"))

  common_tags = merge(
    {
      Application = "Superior RPG Minecraft"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Panel       = "CubeCoders AMP"
    },
    var.tags
  )

  amp_admin_password = var.amp_admin_password != null ? var.amp_admin_password : random_password.amp_admin_password.result

  bootstrap_script = templatefile("${path.module}/scripts/bootstrap.sh.tftpl", {
    key_vault_name                 = module.security.key_vault_name
    managed_identity_client_id     = module.security.managed_identity_client_id
    amp_license_secret_name        = module.security.amp_license_secret_name
    amp_admin_username_secret_name = module.security.amp_admin_username_secret_name
    amp_admin_password_secret_name = module.security.amp_admin_password_secret_name
    rcon_password_secret_name      = module.security.rcon_password_secret_name
    server_pack_url_secret_name    = module.security.server_pack_url_secret_name
    admin_ssh_source_cidrs_json    = jsonencode(var.admin_ssh_source_cidrs)
    amp_panel_source_cidrs_json    = jsonencode(var.amp_panel_source_cidrs)
    minecraft_source_cidrs_json    = jsonencode(var.minecraft_source_cidrs)
    enable_http_https              = var.enable_http_https
    amp_panel_port                 = var.amp_panel_port
    amp_instance_port              = var.amp_instance_port
    minecraft_port                 = var.minecraft_port
    minecraft_rcon_port            = var.minecraft_rcon_port
    minecraft_instance_name        = var.minecraft_instance_name
    minecraft_memory_mb            = var.minecraft_memory_mb
    minecraft_max_players          = var.minecraft_max_players
    backup_retention_days          = var.backup_retention_days
    enable_idle_shutdown           = var.enable_idle_shutdown
    idle_shutdown_grace_minutes    = var.idle_shutdown_grace_minutes
    timezone                       = var.timezone
  })

  cloud_init = templatefile("${path.module}/cloud-init/cloud-init.yaml.tftpl", {
    bootstrap_script_b64 = base64encode(local.bootstrap_script)
  })
}

resource "random_password" "amp_admin_password" {
  length           = 24
  special          = true
  override_special = "!#%*-_=+?"
}

resource "random_password" "minecraft_rcon_password" {
  length           = 32
  special          = true
  override_special = "!#%*-_=+?"
}
