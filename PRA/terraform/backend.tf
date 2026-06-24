terraform {
  backend "azurerm" {
    storage_account_name = "stobkpmetalis974"
    container_name       = "tfstate"
    key                  = "pra.terraform.tfstate"
    resource_group_name  = "rg-metalis"
    subscription_id      = "***REDACTED_SUB_ID***"
  }
}
