output "virtual_machine_id" {
  description = "Linux VM ID."
  value       = azurerm_linux_virtual_machine.this.id
}

output "virtual_machine_name" {
  description = "Linux VM name."
  value       = azurerm_linux_virtual_machine.this.name
}
