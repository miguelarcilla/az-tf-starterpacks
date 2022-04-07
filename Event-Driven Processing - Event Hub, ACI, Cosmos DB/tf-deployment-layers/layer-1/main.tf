# * Initialize providers
# Configure the top-level Terraform block
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

resource "random_id" "solution_random_suffix" {
    byte_length = 4
}

data "azurerm_client_config" "current" {
}

##############################################################################
# * Resource Group
resource "azurerm_resource_group" "group" {
  name     = "${var.solution_prefix}${random_id.solution_random_suffix.dec}-rg"
  location = var.location
}

##############################################################################
# * Modules
module foundation {
  source          = "../../tf-modules/foundation"
  client_config   = data.azurerm_client_config.current
  resource_group  = azurerm_resource_group.group
  location        = var.location
  solution_prefix = var.solution_prefix
  solution_suffix = random_id.solution_random_suffix.dec
}

module nsg {
  source          = "../../tf-modules/nsg"
  resource_group  = azurerm_resource_group.group
  location        = var.location
  solution_prefix = var.solution_prefix
  solution_suffix = random_id.solution_random_suffix.dec
  vnet            = module.foundation.vnet
  bastion_subnet  = module.foundation.bastion_subnet
}

module eventhub {
  source          = "../../tf-modules/eventhub"
  resource_group  = azurerm_resource_group.group
  location        = var.location
  solution_prefix = var.solution_prefix
  solution_suffix = random_id.solution_random_suffix.dec
  vnet            = module.foundation.vnet
  eventhub_subnet = module.foundation.eventhub_subnet
  storage_account = module.foundation.storage_account
}

module cosmosdb {
  source          = "../../tf-modules/cosmosdb"
  resource_group  = azurerm_resource_group.group
  location        = var.location
  solution_prefix = var.solution_prefix
  solution_suffix = random_id.solution_random_suffix.dec
  vnet            = module.foundation.vnet
  database_subnet = module.foundation.eventhub_subnet
}