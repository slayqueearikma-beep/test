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

variable "tags" {
  description = "Resource tags."
  type        = map(string)
}

variable "admin_username" {
  description = "Linux administrator username."
  type        = string
}

variable "ssh_public_key" {
  description = "Linux administrator SSH public key."
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
}

variable "network_interface_id" {
  description = "Primary network interface ID."
  type        = string
}

variable "managed_identity_ids" {
  description = "User-assigned managed identity IDs."
  type        = list(string)
}

variable "os_disk_size_gb" {
  description = "OS disk size."
  type        = number
}

variable "os_disk_storage_account_type" {
  description = "OS disk storage type."
  type        = string
}

variable "data_disk_id" {
  description = "Managed data disk ID."
  type        = string
}

variable "data_disk_caching" {
  description = "Data disk host caching mode."
  type        = string
}

variable "custom_data" {
  description = "Cloud-init custom data."
  type        = string
  sensitive   = true
}
