variable "subscription_id" {
  description = "Azure subscription to deploy into. Run `az account list --output table` to find IDs. Terraform always uses this value instead of the CLI default."
  type        = string
}

variable "subscription_alias" {
  description = "Short label for this subscription (e.g. sub1, sub2). Included in resource names so each subscription gets an isolated, uniquely named stack."
  type        = string
  default     = "sub1"

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.subscription_alias))
    error_message = "subscription_alias must be 2-8 lowercase alphanumeric characters (e.g. sub1, credits2)."
  }
}

variable "resource_group_name" {
  description = "Azure resource group name. Leave empty to auto-generate from environment_name and subscription_alias."
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure region (e.g. westeurope, francecentral)"
  type        = string
  default     = "westeurope"
}

variable "environment_name" {
  description = "Environment label: dev, staging, prod"
  type        = string
  default     = "prod"
}

variable "postgres_admin_login" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "margemadmin"
}

variable "postgres_admin_password" {
  description = "PostgreSQL administrator password (min 8 chars)"
  type        = string
  sensitive   = true
}

variable "jwt_secret_key" {
  description = "JWT signing secret for the API (min 32 characters)"
  type        = string
  sensitive   = true
}

variable "api_image" {
  description = "Container image for the MarGem API (ACR or Docker Hub)"
  type        = string
  default     = "margemapi:latest"
}

variable "create_container_registry" {
  description = "Create Azure Container Registry for API images"
  type        = bool
  default     = true
}

variable "acr_name" {
  description = "ACR name (globally unique, alphanumeric only). Leave empty to auto-generate from subscription_alias."
  type        = string
  default     = ""
}

variable "cors_origins" {
  description = "JSON array of allowed CORS origins for the API (no wildcard in production)"
  type        = string
  default     = "[\"https://margem.app\"]"
}

variable "min_replicas" {
  description = "Minimum API container replicas (use 1+ in production to avoid cold starts)"
  type        = number
  default     = 1
}

variable "allowed_hosts" {
  description = "JSON array of allowed Host headers (API FQDN only in production)"
  type        = string
  default     = "[\"margem-prod-api.azurecontainerapps.io\"]"
}

variable "enable_key_vault_purge_protection" {
  description = "Enable Key Vault purge protection (recommended for production)"
  type        = bool
  default     = true
}
