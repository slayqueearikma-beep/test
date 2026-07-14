variable "resource_group_name" {
  type = string
}

variable "resource_group_id" {
  type = string
}

variable "location" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "key_vault_id" {
  type        = string
  description = "Key Vault ID for storing SQL admin password."
}

variable "key_vault_uri" {
  type        = string
  description = "Key Vault URI for Function App Key Vault references."
}

variable "name_prefix" {
  type    = string
  default = "scad"
}

variable "enable_focus_export" {
  type        = bool
  default     = true
  description = "Enable FOCUS export via AzAPI. Disable if subscription type does not support FOCUS."
}

variable "cost_export_recurrence" {
  type    = string
  default = "Daily"
}
