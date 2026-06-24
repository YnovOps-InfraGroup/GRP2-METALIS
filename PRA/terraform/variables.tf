# ================================================================
# PRA METALIS — Variables
# ================================================================

# ─── Azure Identity ───────────────────────────────────────────

variable "subscription_id" {
  description = "Azure Subscription ID (sub-t-dabbadie-student)"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

# ─── Localisation ─────────────────────────────────────────────

variable "location" {
  description = "Région Azure (contrainte subscription)"
  type        = string
  default     = "switzerlandnorth"
}

variable "resource_group_name" {
  description = "Nom du Resource Group PRA"
  type        = string
  default     = "rg-metalis-pra"
}

# ─── Réseau ───────────────────────────────────────────────────

variable "vnet_name" {
  description = "Nom du VNet PRA"
  type        = string
  default     = "vnet-metalis-pra"
}

variable "vnet_address_space" {
  description = "Plage d'adresses du VNet"
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "subnet_name" {
  description = "Nom du subnet PRA"
  type        = string
  default     = "snet-metalis-pra"
}

variable "subnet_address_prefixes" {
  description = "Plage d'adresses du subnet"
  type        = list(string)
  default     = ["10.10.1.0/24"]
}

variable "admin_source_address" {
  description = "IP source autorisée pour SSH et k8s API (restreindre en prod)"
  type        = string
  default     = "*"
}

# ─── VM ───────────────────────────────────────────────────────

variable "vm_name" {
  description = "Nom de la VM PRA"
  type        = string
  default     = "vm-metalis-pra"
}

variable "vm_size" {
  description = "Taille VM (B2s=4GB, B2ms=8GB si workloads lourds)"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Utilisateur SSH de la VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "Clé publique SSH (contenu du fichier .pub)"
  type        = string
}

variable "os_disk_size_gb" {
  description = "Taille du disque OS (64GB min pour k3s + apps)"
  type        = number
  default     = 64
}

variable "create_public_ip" {
  description = "Créer une IP publique (true=~4€/mois, false=0€ mais IP créée à l'activation)"
  type        = bool
  default     = true
}

# ─── Velero ───────────────────────────────────────────────────

variable "velero_version" {
  description = "Version de Velero CLI à installer"
  type        = string
  default     = "v1.14.0"
}

variable "velero_storage_account" {
  description = "Storage Account Velero (existant)"
  type        = string
  default     = "stobkpmetalis974"
}

variable "velero_container" {
  description = "Container Blob Velero (existant)"
  type        = string
  default     = "contmetalisbkp974"
}

variable "velero_resource_group" {
  description = "Resource Group du Storage Account Velero"
  type        = string
  default     = "rg-metalis"
}

# ─── Tags ─────────────────────────────────────────────────────

variable "tags" {
  description = "Tags Azure"
  type        = map(string)
  default = {
    project     = "metalis"
    environment = "pra"
    managed_by  = "terraform"
  }
}
