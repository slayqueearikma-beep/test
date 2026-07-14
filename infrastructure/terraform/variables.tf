variable "project_name" {
  description = "Short project name used for Azure resource naming."
  type        = string
  default     = "scad"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "image_tag" {
  description = "Container image tag to deploy."
  type        = string
  default     = "latest"
}

variable "container_cpu" {
  description = "CPU allocated to the container app."
  type        = number
  default     = 0.25
}

variable "container_memory" {
  description = "Memory allocated to the container app."
  type        = string
  default     = "0.5Gi"
}

variable "enable_finops" {
  description = "Provision FinOps exports, ingestion function, SQL, and analytics storage."
  type        = bool
  default     = true
}

variable "enable_focus_export" {
  description = "Enable FOCUS parquet export. Disable if subscription does not support FOCUS."
  type        = bool
  default     = true
}

variable "ci_principal_id" {
  description = "Optional Entra object ID for GitHub Actions OIDC principal to upload pipeline metrics."
  type        = string
  default     = ""
}

