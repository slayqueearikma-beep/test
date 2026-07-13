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
