variable "name_prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID."
  type        = string
}

variable "current_object_id" {
  description = "Object ID of the identity running Terraform."
  type        = string
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
}

variable "admin_ssh_source_cidrs" {
  description = "CIDRs allowed to reach SSH."
  type        = list(string)
}

variable "minecraft_source_cidrs" {
  description = "CIDRs allowed to reach Minecraft."
  type        = list(string)
}

variable "enable_http_https" {
  description = "Whether to open HTTP and HTTPS."
  type        = bool
}

variable "minecraft_port" {
  description = "Minecraft server port."
  type        = number
}

variable "minecraft_rcon_password" {
  description = "Minecraft RCON password."
  type        = string
  sensitive   = true
}

variable "superior_rpg_server_pack_url" {
  description = "Superior RPG server pack URL."
  type        = string
  sensitive   = true
}
