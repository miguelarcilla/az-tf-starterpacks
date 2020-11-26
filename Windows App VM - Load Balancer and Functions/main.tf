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

resource "azurerm_subnet" "management_subnet" {
  name                    = "ManagementSubnet"
  virtual_network_name    = azurerm_virtual_network.vnet.name
  resource_group_name     = azurerm_resource_group.group.name
  address_prefixes        = [var.management_subnet_prefix]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

##############################################################################
# * Network Security Groups
resource "azurerm_network_security_group" "app_subnet_nsg" {
  name                = var.app_subnet_nsg_name
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name

  security_rule {
    name                       = "AllowHttp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHealth"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "15672"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

resource "azurerm_subnet_network_security_group_association" "app_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.app_subnet_nsg.id
}

resource "azurerm_network_security_group" "management_subnet_nsg" {
  name                = var.management_subnet_nsg_name
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_subnet_network_security_group_association" "management_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.management_subnet.id
  network_security_group_id = azurerm_network_security_group.management_subnet_nsg.id
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

resource "azurerm_network_interface" "win_vm2_nic" {
  name                = "${var.win_vm_name}2-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name

  ip_configuration {
    name                          = "${var.win_vm_name}2-ipconfig"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "win_vm2" {
  name                = "${var.win_vm_name}-vm2"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  size                = "Standard_D2as_v4"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.win_vm2_nic.id
  ]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    name                  = "${var.win_vm_name}2-osdisk"
    storage_account_type  = "Standard_LRS"
    caching               = "ReadWrite"
  }
}

##############################################################################
# * Load Balancer
resource "azurerm_lb" "app_internal_lb" {
  name                = var.app_internal_lb_name
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "${var.app_internal_lb_name}-frontend-ipconfig"
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    subnet_id = azurerm_subnet.app_subnet.id
  }
}

resource "azurerm_lb_backend_address_pool" "app_internal_lb_backend_pool" {
  resource_group_name = azurerm_resource_group.group.name
  loadbalancer_id     = azurerm_lb.app_internal_lb.id
  name                = "${var.app_internal_lb_name}-backend-pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "app_internal_lb_backend_pool_win_vm" {
  network_interface_id    = azurerm_network_interface.win_vm_nic.id
  ip_configuration_name   = "${var.win_vm_name}-ipconfig"
  backend_address_pool_id = azurerm_lb_backend_address_pool.app_internal_lb_backend_pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "app_internal_lb_backend_pool_win_vm2" {
  network_interface_id    = azurerm_network_interface.win_vm2_nic.id
  ip_configuration_name   = "${var.win_vm_name}2-ipconfig"
  backend_address_pool_id = azurerm_lb_backend_address_pool.app_internal_lb_backend_pool.id
}

resource "azurerm_lb_probe" "app_internal_lb_http_probe" {
  resource_group_name = azurerm_resource_group.group.name
  loadbalancer_id     = azurerm_lb.app_internal_lb.id
  name                = "${var.app_internal_lb_name}-http-probe"
  port                = 80
  protocol            = "http"
  request_path        = "/"
}

resource "azurerm_lb_rule" "app_internal_lb_rule" {
  resource_group_name            = azurerm_resource_group.group.name
  loadbalancer_id                = azurerm_lb.app_internal_lb.id
  name                           = "${var.app_internal_lb_name}-health-rule"
  protocol                       = "Tcp"
  frontend_port                  = 15672
  backend_port                   = 15672
  frontend_ip_configuration_name = "${var.app_internal_lb_name}-frontend-ipconfig"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.app_internal_lb_backend_pool.id
  probe_id                       = azurerm_lb_probe.app_internal_lb_http_probe.id
}

##############################################################################
# * Azure Function Plan
resource "azurerm_storage_account" "func_storage" {
  name                     = var.func_storage_name
  location                 = var.location
  resource_group_name      = azurerm_resource_group.group.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "func_plan" {
  name                = "${var.func_name}-plan"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  kind                = "elastic"

  sku {
    tier = "ElasticPremium"
    size = "EP1"
  }
}

resource "azurerm_application_insights" "func_ai" {
  name                = "${var.func_name}-ai"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  application_type    = "other"
}

resource "azurerm_function_app" "func" {
  name                       = var.func_name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.group.name
  app_service_plan_id        = azurerm_app_service_plan.func_plan.id
  storage_account_name       = azurerm_storage_account.func_storage.name
  storage_account_access_key = azurerm_storage_account.func_storage.primary_access_key

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "powershell"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = "${azurerm_application_insights.func_ai.instrumentation_key}"
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "example" {
  app_service_id = azurerm_function_app.func.id
  subnet_id      = azurerm_subnet.management_subnet.id
}