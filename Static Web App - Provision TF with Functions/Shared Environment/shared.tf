##############################################################################
# THESE SCRIPTS, INCLUDING ANY ADDITIONAL CONTENT CONTRIBUTED BY MICROSOFT 
# OR ANY 3RD PARTY, IS PROVIDED ON AN "AS-IS" BASIS, AND MICROSOFT GIVES NO 
# EXPRESS WARRANTIES, GUARANTEES OR CONDITIONS. TO THE EXTENT PERMITTED BY 
# APPLICABLE LAW, MICROSOFT DISCLAIMS THE IMPLIED WARRANTIES OF 
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. 
# YOUR USE OF THE SCRIPT AND ADDITIONAL CONTENT IS AT YOUR SOLE
# RISK AND RESPONSIBILITY.
##############################################################################

##############################################################################
# Minimum Terraform version required: 1.13
# This Terraform configuration will create the following:
#
# Solution Resource Group
##############################################################################
# * Initialize providers

# Configure the top-level Terraform block
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.92.0"
    }
  }
  backend "azurerm" {
    # Backend configuration intentionally left blank
    # It will be populated by the pipeline
    resource_group_name  = "p-igl"
    storage_account_name = "pigltfstorage"
    container_name       = "tfstate"
    key                  = "shared.tfstate"
  }
}

# Configure the Azure Provider
provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

##############################################################################
# * Shared Resource Group
resource "azurerm_resource_group" "group" {
  name     = "${var.solution_prefix_dashed}"
  location = var.location
}

resource "azurerm_shared_image_gallery" "gallery" {
  name                = "${var.solution_prefix}acg"
  resource_group_name = azurerm_resource_group.group.name
  location            = azurerm_resource_group.group.location
}

resource "azurerm_shared_image" "image" {
  name                = "winsvriis"
  gallery_name        = azurerm_shared_image_gallery.gallery.name
  resource_group_name = azurerm_resource_group.group.name
  location            = azurerm_resource_group.group.location
  os_type             = "Windows"

  identifier {
    publisher = "miguels-enterprise-company"
    offer     = "winweb-basic-offer"
    sku       = "winweb-basic-sku"
  }
}