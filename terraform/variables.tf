variable "project_name" {
  description = "Short workload name used in Azure resource names."
  type        = string
  default     = "superior-rpg"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.project_name))
    error_message = "project_name must be 3-30 characters and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,16}$", var.environment))
    error_message = "environment must be 2-16 characters and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "location" {
  description = "Azure region. Choose the region closest to the players for lower latency."
  type        = string
  default     = "swedencentral"
}

variable "tags" {
  description = "Additional Azure resource tags."
  type        = map(string)
  default     = {}
}

variable "address_space" {
  description = "Virtual network CIDR."
  type        = list(string)
  default     = ["10.60.0.0/24"]
}

variable "subnet_prefixes" {
  description = "Minecraft VM subnet CIDR."
  type        = list(string)
  default     = ["10.60.0.0/27"]
}

variable "admin_username" {
  description = "Linux administrator username for SSH access."
  type        = string
  default     = "azureadmin"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{2,30}$", var.admin_username))
    error_message = "admin_username must be a valid Linux username."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for the Linux administrator account. Password SSH is disabled."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp[0-9]+) ", var.ssh_public_key))
    error_message = "ssh_public_key must be a valid OpenSSH public key."
  }
}

variable "admin_ssh_source_cidrs" {
  description = "CIDR ranges allowed to SSH to the VM. Set this to your fixed public IP range."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "minecraft_source_cidrs" {
  description = "CIDR ranges allowed to reach the public Minecraft server port."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_http_https" {
  description = "Open HTTP/HTTPS in NSG and UFW for an optional reverse proxy or status page."
  type        = bool
  default     = false
}

variable "minecraft_port" {
  description = "Public Minecraft Java TCP port."
  type        = number
  default     = 25565
}

variable "minecraft_rcon_port" {
  description = "Local RCON TCP port used by monitoring. This port is not opened in Azure NSG or UFW."
  type        = number
  default     = 25575
}

variable "vm_size" {
  description = "Azure VM size. Default is the recommended performance-per-dollar size for 8 modded players; use Standard_D4as_v5 for about 20 players."
  type        = string
  default     = "Standard_D2as_v5"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GiB."
  type        = number
  default     = 64
}

variable "os_disk_storage_account_type" {
  description = "OS disk storage type."
  type        = string
  default     = "StandardSSD_LRS"
}

variable "data_disk_size_gb" {
  description = "Minecraft data disk size in GiB."
  type        = number
  default     = 128
}

variable "data_disk_storage_account_type" {
  description = "Minecraft data disk storage type."
  type        = string
  default     = "Premium_LRS"
}

variable "data_disk_caching" {
  description = "Azure host caching mode for the Minecraft data disk."
  type        = string
  default     = "ReadOnly"

  validation {
    condition     = contains(["None", "ReadOnly", "ReadWrite"], var.data_disk_caching)
    error_message = "data_disk_caching must be None, ReadOnly, or ReadWrite."
  }
}

variable "superior_rpg_server_pack_url" {
  description = "HTTPS URL to the Superior RPG server pack zip. The VM downloads and installs this during first boot."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^https://", var.superior_rpg_server_pack_url))
    error_message = "superior_rpg_server_pack_url must be an HTTPS URL."
  }
}

variable "minecraft_instance_name" {
  description = "Friendly instance name for the Superior RPG server."
  type        = string
  default     = "SuperiorRPG01"
}

variable "minecraft_memory_mb" {
  description = "JVM maximum heap allocation for the Minecraft server."
  type        = number
  default     = 6144
}

variable "minecraft_max_players" {
  description = "Configured Minecraft max players."
  type        = number
  default     = 8
}

variable "backup_retention_days" {
  description = "Number of days to retain compressed local backups."
  type        = number
  default     = 14
}

variable "enable_idle_shutdown" {
  description = "Enable automatic VM deallocation when the Minecraft server remains empty after the idle grace period."
  type        = bool
  default     = true
}

variable "idle_shutdown_grace_minutes" {
  description = "Minutes to wait and re-check after the server first appears empty before deallocating the VM."
  type        = number
  default     = 5

  validation {
    condition     = var.idle_shutdown_grace_minutes >= 1 && var.idle_shutdown_grace_minutes <= 120
    error_message = "idle_shutdown_grace_minutes must be between 1 and 120."
  }
}

variable "timezone" {
  description = "Linux timezone for scheduled backup and monitoring logs."
  type        = string
  default     = "UTC"
}
