resource "azurerm_linux_virtual_machine" "this" {
  name                            = "vm-${var.name_prefix}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [var.network_interface_id]
  custom_data                     = base64encode(var.custom_data)
  tags                            = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = var.managed_identity_ids
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = trimspace(var.ssh_public_key)
  }

  os_disk {
    name                 = "disk-${var.name_prefix}-os"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_account_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  boot_diagnostics {}
}

resource "azurerm_virtual_machine_data_disk_attachment" "minecraft" {
  managed_disk_id    = var.data_disk_id
  virtual_machine_id = azurerm_linux_virtual_machine.this.id
  lun                = 0
  caching            = var.data_disk_caching
}
