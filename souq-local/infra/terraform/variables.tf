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

variable "upload_token_secret" {
  description = "Independent HMAC secret for local upload tokens (min 32 characters)"
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

variable "max_replicas" {
  description = "Maximum API replicas. Values above 1 require redis_url for shared rate limiting."
  type        = number
  default     = 1
  validation {
    condition     = var.max_replicas >= var.min_replicas
    error_message = "max_replicas must be greater than or equal to min_replicas."
  }
}

variable "redis_url" {
  description = "Optional managed Redis URL for distributed rate limits; required when max_replicas > 1."
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgres_backup_retention_days" {
  description = "Managed PostgreSQL point-in-time recovery retention (7–35 days)"
  type        = number
  default     = 14
  validation {
    condition     = var.postgres_backup_retention_days >= 7 && var.postgres_backup_retention_days <= 35
    error_message = "postgres_backup_retention_days must be between 7 and 35."
  }
}

variable "postgres_geo_redundant_backup_enabled" {
  description = "Enable geo-redundant PostgreSQL backups for production recovery"
  type        = bool
  default     = true
}

variable "allowed_hosts" {
  description = "JSON array of allowed Host headers (API FQDN only in production)"
  type        = string
  default     = "[\"margem-prod-api.azurecontainerapps.io\"]"
}

variable "public_app_url" {
  description = "Public app / deep-link base URL used in transactional emails"
  type        = string
  default     = "https://margem.ma"
}

variable "public_api_url" {
  description = "Public HTTPS API base URL"
  type        = string
  default     = "https://api.margem.ma"
}

variable "smtp_host" {
  description = "SMTP host for transactional email (required for production mail delivery)"
  type        = string
}

variable "smtp_port" {
  description = "SMTP port"
  type        = number
  default     = 587
}

variable "smtp_username" {
  description = "SMTP username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "smtp_password" {
  description = "SMTP password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "smtp_from" {
  description = "From header for transactional email"
  type        = string
  default     = "MarGem <noreply@margem.ma>"
}

variable "smtp_use_tls" {
  description = "Whether to STARTTLS on the SMTP connection"
  type        = bool
  default     = true
}

variable "enable_key_vault_purge_protection" {
  description = "Enable Key Vault purge protection (recommended for production)"
  type        = bool
  default     = true
}
