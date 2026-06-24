# ================================================================
# PRA METALIS — VM Azure (k3s PRA dormante)
# ================================================================

# ─── IP Publique (optionnelle) ────────────────────────────────

resource "azurerm_public_ip" "pra" {
  count               = var.create_public_ip ? 1 : 0
  name                = "pip-metalis-pra"
  location            = azurerm_resource_group.pra.location
  resource_group_name = azurerm_resource_group.pra.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# ─── NIC ──────────────────────────────────────────────────────

resource "azurerm_network_interface" "pra" {
  name                = "nic-metalis-pra"
  location            = azurerm_resource_group.pra.location
  resource_group_name = azurerm_resource_group.pra.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.pra.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.create_public_ip ? azurerm_public_ip.pra[0].id : null
  }
}

# ─── VM Linux ─────────────────────────────────────────────────

resource "azurerm_linux_virtual_machine" "pra" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.pra.name
  location            = azurerm_resource_group.pra.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.pra.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "osdisk-metalis-pra"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  # Ubuntu 24.04 LTS — même OS que le cluster on-prem
  # Image disponible en switzerlandnorth : az vm image list --publisher Canonical --offer ubuntu-24_04-lts --location switzerlandnorth --all
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    admin_username = var.admin_username
    velero_version = var.velero_version
  }))

  tags = var.tags
}
