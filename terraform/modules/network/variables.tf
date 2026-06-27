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

variable "address_space" {
  description = "Virtual network address space."
  type        = list(string)
}

variable "subnet_prefixes" {
  description = "Subnet prefixes."
  type        = list(string)
}

variable "nsg_id" {
  description = "Network security group ID associated to the subnet."
  type        = string
}
