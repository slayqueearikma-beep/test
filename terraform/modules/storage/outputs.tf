output "data_disk_id" {
  description = "Minecraft managed data disk ID."
  value       = azurerm_managed_disk.minecraft.id
}
