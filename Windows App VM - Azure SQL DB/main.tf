##############################################################################
# This Terraform configuration will create the following:
#
# Resource group with a virtual network and standard subnets
# An Ubuntu Linux server running Apache

##############################################################################
# * Shared infrastructure resources

# Configure the Azure Provider
provider "azurerm" {
  version = "=2.20.0"
  subscription_id = var.subscription_id
  features {}
}

provider "random" {
  version = "=2.3"
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

resource "azurerm_subnet" "bastion_subnet" {
  name                    = "AzureBastionSubnet"
  virtual_network_name    = azurerm_virtual_network.vnet.name
  resource_group_name     = azurerm_resource_group.group.name
  address_prefixes        = [var.bastion_subnet_prefix]
}

resource "azurerm_subnet" "gateway_subnet" {
  name                    = "GatewaySubnet"
  virtual_network_name    = azurerm_virtual_network.vnet.name
  resource_group_name     = azurerm_resource_group.group.name
  address_prefixes        = [var.gateway_subnet_prefix]
}

resource "azurerm_subnet" "public_subnet" {
  name                    = "PublicSubnet"
  virtual_network_name    = azurerm_virtual_network.vnet.name
  resource_group_name     = azurerm_resource_group.group.name
  address_prefixes        = [var.public_subnet_prefix]
}

resource "azurerm_subnet" "app_subnet" {
  name                    = "AppSubnet"
  virtual_network_name    = azurerm_virtual_network.vnet.name
  resource_group_name     = azurerm_resource_group.group.name
  address_prefixes        = [var.app_subnet_prefix]
}

resource "azurerm_subnet" "database_subnet" {
  name                                            = "DatabaseSubnet"
  virtual_network_name                            = azurerm_virtual_network.vnet.name
  resource_group_name                             = azurerm_resource_group.group.name
  address_prefixes                                = [var.database_subnet_prefix]
  enforce_private_link_endpoint_network_policies  = true
}

resource "random_id" "diagnostics_id" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.group.name
    }   
    byte_length = 8
}

resource "azurerm_storage_account" "diagnostics" {
    name                        = "${var.diag_storage_prefix}${random_id.diagnostics_id.hex}"
    resource_group_name         = azurerm_resource_group.group.name
    location                    = var.location
    account_replication_type    = "LRS"
    account_tier                = "Standard"

    tags = {
        role = "diagnostics"
    }
}

##############################################################################
# * Azure Bastion
resource "azurerm_public_ip" "bastion_ip" {
  name                = "${var.bastion_name}-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = var.bastion_name
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_ip.id
  }
}


##############################################################################
# * App Server
resource "azurerm_network_interface" "app_nic" {
  name                = "${var.app_name}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name

  ip_configuration {
    name                          = "${var.app_name}-ipconfig"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "app" {
  name                = var.app_name
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  size                = "Standard_DS12_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.app_nic.id
  ]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    name                  = "${var.app_name}-osdisk"
    storage_account_type  = "Standard_LRS"
    caching               = "ReadWrite"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }
}

##############################################################################
# * Application Gateway
resource "azurerm_public_ip" "app_ip" {
  name                = "${var.app_name}-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

resource "azurerm_application_gateway" "app" {
  name                = "${var.app_name}gw"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "${var.app_name}-ipconfig"
    subnet_id = azurerm_subnet.public_subnet.id
  }

  frontend_port {
    name = "${var.app_name}-http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "${var.app_name}-frontend-ipconfig"
    public_ip_address_id = azurerm_public_ip.app_ip.id
  }

  backend_address_pool {
    name          = "${var.app_name}-backend-pool"
    ip_addresses  = [
      azurerm_windows_virtual_machine.app.private_ip_address
    ]
  }

  backend_http_settings {
    name                  = "${var.app_name}-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 10
  }

  http_listener {
    name                           = "${var.app_name}-http-listener"
    frontend_ip_configuration_name = "${var.app_name}-frontend-ipconfig"
    frontend_port_name             = "${var.app_name}-http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "${var.app_name}-http-rule"
    rule_type                  = "Basic"
    http_listener_name         = "${var.app_name}-http-listener"
    backend_address_pool_name  = "${var.app_name}-backend-pool"
    backend_http_settings_name = "${var.app_name}-http-settings"
  }
}

##############################################################################
# * SQL Azure Database
resource "azurerm_mssql_server" "db_server" {
  name                         = "${var.db_name}-server"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.group.name
  version                      = "12.0"
  administrator_login          = var.db_admin_username
  administrator_login_password = var.db_admin_password
}

resource "azurerm_mssql_database" "db" {
  name                = var.db_name
  server_id           = azurerm_mssql_server.db_server.id
  sku_name            = "GP_Gen5_4"
  max_size_gb         = 512
  collation           = "SQL_Latin1_General_CP1_CI_AS"
}

resource "azurerm_private_endpoint" "db_private_endpoint" {
  name                     = "${azurerm_mssql_server.db_server.name}-private-endpoint"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.group.name
  subnet_id                = azurerm_subnet.database_subnet.id

  private_service_connection {
    name                           = "${azurerm_mssql_server.db_server.name}-private-link"
    is_manual_connection           = "false"
    private_connection_resource_id = azurerm_mssql_server.db_server.id
    subresource_names              = ["sqlServer"]
  }
}

resource "azurerm_private_dns_zone" "db_private_dns_zone" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_private_dns_a_record" "db_private_endpoint_a_record" {
  name                = azurerm_mssql_server.db_server.name
  zone_name           = azurerm_private_dns_zone.db_private_dns_zone.name
  resource_group_name = azurerm_resource_group.group.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.db_private_endpoint.private_service_connection.0.private_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "db_private_dns_zone_vnet_link" {
  name                  = "${azurerm_mssql_server.db_server.name}-vnet-link"
  resource_group_name   = azurerm_resource_group.group.name
  private_dns_zone_name = azurerm_private_dns_zone.db_private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}