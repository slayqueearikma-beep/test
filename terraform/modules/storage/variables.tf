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

variable "data_disk_size_gb" {
  description = "Managed data disk size."
  type        = number
}

variable "data_disk_storage_account_type" {
  description = "Managed data disk storage type."
  type        = string
}
