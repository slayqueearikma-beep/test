variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "subscription_alias" {
  description = "Short label (sub1, sub2) for unique naming"
  type        = string
  default     = "sub1"
}

variable "vm_size" {
  description = "VM SKU — Standard_B1s is cheapest (~$8/mo). Use Standard_B1ms (2GB RAM) if the API runs out of memory."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Linux admin username on the VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "Your SSH public key (contents of id_rsa.pub)"
  type        = string
}

variable "postgres_password" {
  description = "PostgreSQL password (8+ chars)"
  type        = string
  sensitive   = true
}

variable "jwt_secret_key" {
  description = "JWT secret (32+ chars)"
  type        = string
  sensitive   = true
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH (use your IP/32 for security, or 0.0.0.0/0 for easy access)"
  type        = string
  default     = "0.0.0.0/0"
}
