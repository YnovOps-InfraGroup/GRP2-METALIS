# ================================================================
# PRA METALIS — Terraform Provider Configuration
# ================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80"
    }
  }

  # ─── Backend distant (recommandé) ───────────────────────────
  # Si le site on-prem est détruit, le state Terraform doit rester accessible.
  # Décommenter et configurer après création du container "tfstate" :
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-metalis"
  #   storage_account_name = "stobkpmetalis974"
  #   container_name       = "tfstate"
  #   key                  = "pra.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}
