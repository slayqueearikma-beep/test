variable "resource_group_name" {
  description = "Resource group for the FOCUS export learning lab."
  type        = string
  default     = "rg-focus-export-lab"
}

variable "location" {
  description = "Azure region. Many student/trial subscriptions block westeurope — try eastus or westus2. Run scripts/pick-allowed-region.ps1 to find allowed regions."
  type        = string
  default     = "eastus"
}

variable "storage_account_name" {
  description = "Globally unique storage account name (3-24 lowercase letters/numbers)."
  type        = string
}

variable "container_name" {
  description = "Blob container for cost exports."
  type        = string
  default     = "cost-exports"
}

variable "actual_cost_export_name" {
  description = "Name of the ActualCost export resource."
  type        = string
  default     = "lab-actual-cost-daily"
}

variable "focus_export_name" {
  description = "Name of the FOCUS export resource."
  type        = string
  default     = "lab-focus-daily"
}

variable "tags" {
  description = "Tags applied to lab resources."
  type        = map(string)
  default = {
    project = "focus-learning-lab"
    owner   = "scad"
  }
}
