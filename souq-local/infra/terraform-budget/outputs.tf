output "vm_public_ip" {
  description = "Public IP of the budget VM"
  value       = azurerm_public_ip.vm.ip_address
}

output "api_url" {
  description = "HTTP API URL (budget tier — add HTTPS/domain later for Play Store)"
  value       = "http://${azurerm_public_ip.vm.ip_address}:8000"
}

output "ssh_command" {
  description = "SSH into the VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.vm.ip_address}"
}

output "storage_connection_string" {
  description = "Blob storage connection string for image uploads"
  value       = azurerm_storage_account.media.primary_connection_string
  sensitive   = true
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.margem.name
}
