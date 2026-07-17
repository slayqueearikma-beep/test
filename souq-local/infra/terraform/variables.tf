variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
  default     = "rg-margem-prod"
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
  description = "ACR name (globally unique, alphanumeric only)"
  type        = string
  default     = "margemregistry"
}

variable "cors_origins" {
  description = "JSON array of allowed CORS origins for the API"
  type        = string
  default     = "[\"*\"]"
}
