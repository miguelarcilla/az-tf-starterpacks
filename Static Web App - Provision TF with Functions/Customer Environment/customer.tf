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
    key                  = "customer1.tfstate"
  }
}

# Configure the Azure Provider
provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

##############################################################################
# * Import Existing Resources
# Remote State of shared Azure resources provisioned with Terraform
data "terraform_remote_state" "shared" {
  backend = "azurerm"
  config  = {
    resource_group_name  = var.remote_state_resource_group_name
    storage_account_name = var.remote_state_storage_account_name
    container_name       = var.remote_state_container_name
    key                  = var.remote_state_key
  }
}

##############################################################################
# * Customer Resource Group
resource "azurerm_resource_group" "customer_group" {
  name     = "${var.solution_prefix_dashed}"
  location = var.location
}

##############################################################################
# * Windows Server 2019 Virtual Machine with Public IP Address
resource "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network_name
  location            = var.location
  address_space       = ["172.16.0.0/24"]
  resource_group_name = azurerm_resource_group.customer_group.name
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "ApplicationSubnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.customer_group.name
  address_prefixes     = ["172.16.0.0/28"]
}

resource "azurerm_public_ip" "win_vm_pip" {
  name                = "${var.win_vm_name}-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.customer_group.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "win_vm_nic" {
  name                = "${var.win_vm_name}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.customer_group.name

  ip_configuration {
    name                          = "${var.win_vm_name}-ipconfig"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.win_vm_pip.id
  }
}

resource "azurerm_windows_virtual_machine" "win_vm" {
  name                = "${var.win_vm_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.customer_group.name
  size                = var.win_vm_size
  admin_username      = "AdminUser"
  admin_password      = "Adm1nPa55w0rd!"
  source_image_id     = data.terraform_remote_state.shared.outputs.azurerm_shared_image_id

  network_interface_ids = [
    azurerm_network_interface.win_vm_nic.id
  ]

  os_disk {
    name                 = "${var.win_vm_name}-osdisk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}