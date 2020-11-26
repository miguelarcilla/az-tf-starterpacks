##############################################################################
# This Terraform configuration will create the following:
#
# Resource group with a virtual network and standard subnets
# A Windows Server 2019 Virtual Machine

##############################################################################
# * Shared infrastructure resources

# Configure the Azure Provider
provider "azurerm" {
  version = "=2.34.0"
  subscription_id = var.subscription_id
  features {}
}

resource "azurerm_resource_group" "group" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network_name
  location            = var.location
  address_space       = var.virtual_network_address_space
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_subnet" "app_subnet" {
  name                    = "ApplicationSubnet"
  virtual_network_name    = azurerm_virtual_network.vnet.name
  resource_group_name     = azurerm_resource_group.group.name
  address_prefixes        = [var.app_subnet_prefix]
}


##############################################################################
# * Network Security Groups
resource "azurerm_network_security_group" "app_subnet_nsg" {
  name                = var.app_subnet_nsg_name
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_subnet_network_security_group_association" "app_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.app_subnet_nsg.id
}

##############################################################################
# * Windows Virtual Machine
resource "azurerm_network_interface" "win_vm_nic" {
  name                = "${var.win_vm_name}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name

  ip_configuration {
    name                          = "${var.win_vm_name}-ipconfig"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "win_vm" {
  name                = "${var.win_vm_name}-vm"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  size                = "Standard_D2as_v4"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.win_vm_nic.id
  ]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    name                  = "${var.win_vm_name}-osdisk"
    storage_account_type  = "Standard_LRS"
    caching               = "ReadWrite"
  }
}