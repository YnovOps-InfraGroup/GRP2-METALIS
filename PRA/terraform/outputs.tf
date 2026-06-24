# ================================================================
# PRA METALIS — Outputs
# ================================================================

output "resource_group_name" {
  description = "Nom du Resource Group PRA"
  value       = azurerm_resource_group.pra.name
}

output "vm_name" {
  description = "Nom de la VM PRA"
  value       = azurerm_linux_virtual_machine.pra.name
}

output "vm_id" {
  description = "ID de la VM PRA"
  value       = azurerm_linux_virtual_machine.pra.id
}

output "public_ip_address" {
  description = "IP publique de la VM (vide si create_public_ip=false)"
  value       = var.create_public_ip ? azurerm_public_ip.pra[0].ip_address : "N/A"
}

output "private_ip_address" {
  description = "IP privée de la VM"
  value       = azurerm_network_interface.pra.private_ip_address
}

output "admin_username" {
  description = "Utilisateur SSH"
  value       = var.admin_username
}

output "ssh_command" {
  description = "Commande SSH pour se connecter"
  value       = var.create_public_ip ? "ssh ${var.admin_username}@${azurerm_public_ip.pra[0].ip_address}" : "ssh ${var.admin_username}@<IP après démarrage>"
}

output "deallocate_command" {
  description = "Commande pour désallouer la VM (0€ compute)"
  value       = "az vm deallocate --resource-group ${azurerm_resource_group.pra.name} --name ${azurerm_linux_virtual_machine.pra.name}"
}

output "start_command" {
  description = "Commande pour démarrer la VM PRA"
  value       = "az vm start --resource-group ${azurerm_resource_group.pra.name} --name ${azurerm_linux_virtual_machine.pra.name}"
}

output "cost_estimate" {
  description = "Estimation des coûts mensuels"
  value       = "VM éteinte: ~${var.create_public_ip ? "7" : "3"}€/mois | VM allumée: ~40€/mois"
}
