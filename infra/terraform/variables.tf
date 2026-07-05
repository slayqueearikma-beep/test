variable "name_prefix" {
  description = "Short lowercase prefix used for Azure resource names."
  type        = string
  default     = "7amidelmath"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name_prefix))
    error_message = "name_prefix must be 3-20 characters and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "location" {
  description = "Azure region for the low-cost bot hosting resources."
  type        = string
  default     = "eastus"
}

variable "discord_token" {
  description = "Discord bot token. This is stored as a Container Apps secret."
  type        = string
  sensitive   = true
}

variable "guild_id" {
  description = "Optional Discord guild ID for fast slash-command sync while developing."
  type        = string
  default     = ""
}

variable "auto_sync_commands" {
  description = "Whether the bot should sync slash commands on startup."
  type        = bool
  default     = true
}

variable "image_repository" {
  description = "Container image repository name inside Azure Container Registry."
  type        = string
  default     = "7amidelmath"
}

variable "image_tag" {
  description = "Container image tag built and deployed by Terraform."
  type        = string
  default     = "latest"
}

variable "container_cpu" {
  description = "CPU cores for the bot container. Keep this low for a low-budget Discord bot."
  type        = number
  default     = 0.25
}

variable "container_memory" {
  description = "Memory for the bot container."
  type        = string
  default     = "0.5Gi"
}

variable "min_replicas" {
  description = "Minimum running bot replicas. Discord gateway bots should usually stay at 1."
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum running bot replicas. Keep at 1 to avoid duplicate Discord gateway sessions."
  type        = number
  default     = 1
}
