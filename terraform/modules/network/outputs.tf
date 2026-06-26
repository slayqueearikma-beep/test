output "virtual_network_id" {
  description = "Virtual network ID."
  value       = azurerm_virtual_network.this.id
}

output "subnet_id" {
  description = "Minecraft subnet ID."
  value       = azurerm_subnet.minecraft.id
}

output "public_ip_id" {
  description = "Static public IP resource ID."
  value       = azurerm_public_ip.this.id
}

output "public_ip_address" {
  description = "Static public IP address."
  value       = azurerm_public_ip.this.ip_address
}

output "network_interface_id" {
  description = "VM network interface ID."
  value       = azurerm_network_interface.this.id
}
