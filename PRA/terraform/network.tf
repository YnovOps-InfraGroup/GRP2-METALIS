# ================================================================
# PRA METALIS — Réseau Azure (VNet + Subnet + NSG)
# ================================================================

resource "azurerm_resource_group" "pra" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ─── VNet ─────────────────────────────────────────────────────

resource "azurerm_virtual_network" "pra" {
  name                = var.vnet_name
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.pra.location
  resource_group_name = azurerm_resource_group.pra.name
  tags                = var.tags
}

resource "azurerm_subnet" "pra" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.pra.name
  virtual_network_name = azurerm_virtual_network.pra.name
  address_prefixes     = var.subnet_address_prefixes
}

# ─── NSG ──────────────────────────────────────────────────────

resource "azurerm_network_security_group" "pra" {
  name                = "nsg-metalis-pra"
  location            = azurerm_resource_group.pra.location
  resource_group_name = azurerm_resource_group.pra.name
  tags                = var.tags

  # SSH — restreint à l'IP admin
  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_source_address
    destination_address_prefix = "*"
  }

  # HTTP — accès web PRA (WordPress, Odoo)
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # HTTPS
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # k8s API — restreint à l'IP admin
  security_rule {
    name                       = "AllowK8sAPI"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = var.admin_source_address
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "pra" {
  subnet_id                 = azurerm_subnet.pra.id
  network_security_group_id = azurerm_network_security_group.pra.id
}
