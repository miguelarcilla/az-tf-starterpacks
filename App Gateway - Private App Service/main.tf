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
# Minimum Terraform version required: 0.13
# This Terraform configuration will create the following:
#
# Solution Resource Group
# Virtual Network and subnets
# Network Security Groups
# Azure Kubernetes Service with configured Application Gateway Ingress
# Application Gateway
##############################################################################
# * Initialize providers

# Configure the top-level Terraform block
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.33.0"
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
  name     = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-rg"
  location = var.location
}

##############################################################################
# * Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-vnet"
  location            = var.location
  address_space       = ["172.16.0.0/21"]
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_subnet" "appgw_subnet" {
  name                 = "AppGatewaySubnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.group.name
  address_prefixes     = ["172.16.1.0/24"]
}

resource "azurerm_subnet" "appsvc_subnet" {
  name                                      = "AppServiceSubnet"
  virtual_network_name                      = azurerm_virtual_network.vnet.name
  resource_group_name                       = azurerm_resource_group.group.name
  address_prefixes                          = ["172.16.2.0/24"]
  private_endpoint_network_policies_enabled = true
}

resource "azurerm_subnet" "database_subnet" {
  name                                      = "DatabaseSubnet"
  virtual_network_name                      = azurerm_virtual_network.vnet.name
  resource_group_name                       = azurerm_resource_group.group.name
  address_prefixes                          = ["172.16.3.0/24"]
  private_endpoint_network_policies_enabled = true
}

##############################################################################
# * Network Security Groups
resource "azurerm_network_security_group" "appgw_nsg" {
  name                = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-subnet-appgateway-nsg"
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
    name                       = "AllowHttps"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAppGatewayManager"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "default_nsg" {
  name                = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-default-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_subnet_network_security_group_association" "appgw_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.appgw_subnet.id
  network_security_group_id = azurerm_network_security_group.appgw_nsg.id
}


resource "azurerm_subnet_network_security_group_association" "appsvc_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.appsvc_subnet.id
  network_security_group_id = azurerm_network_security_group.default_nsg.id
}


resource "azurerm_subnet_network_security_group_association" "database_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.database_subnet.id
  network_security_group_id = azurerm_network_security_group.default_nsg.id
}

##############################################################################
# * App Service
resource "azurerm_service_plan" "appsvc_plan" {
  name                = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appsvc-plan"
  resource_group_name = azurerm_resource_group.group.name
  location            = var.location
  sku_name            = "P1v2"
  os_type             = "Windows"
}

resource "azurerm_windows_web_app" "appsvc_app" {
  name                = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appsvc-app1"
  resource_group_name = azurerm_resource_group.group.name
  location            = var.location
  service_plan_id     = azurerm_service_plan.appsvc_plan.id

  site_config {}
}

resource "azurerm_private_endpoint" "appsvc_private_endpoint" {
  name                = "${azurerm_windows_web_app.appsvc_app.name}-private-endpoint"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  subnet_id           = azurerm_subnet.appsvc_subnet.id

  private_service_connection {
    name                           = "${azurerm_windows_web_app.appsvc_app.name}-private-link"
    is_manual_connection           = "false"
    private_connection_resource_id = azurerm_windows_web_app.appsvc_app.id
    subresource_names              = ["sites"]
  }
}

resource "azurerm_private_dns_zone" "appsvc_private_dns_zone" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_private_dns_a_record" "appsvc_private_endpoint_a_record" {
  name                = azurerm_windows_web_app.appsvc_app.name
  zone_name           = azurerm_private_dns_zone.appsvc_private_dns_zone.name
  resource_group_name = azurerm_resource_group.group.name
  ttl                 = 10
  records             = [azurerm_private_endpoint.appsvc_private_endpoint.private_service_connection.0.private_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "appsvc_private_dns_zone_vnet_link" {
  name                  = "${azurerm_windows_web_app.appsvc_app.name}-vnet-link"
  resource_group_name   = azurerm_resource_group.group.name
  private_dns_zone_name = azurerm_private_dns_zone.appsvc_private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

# ##############################################################################
# # * Application Gateway
resource "azurerm_public_ip" "appgw_ip" {
  name                = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appgw-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appgw"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  autoscale_configuration {
    min_capacity = 0
    max_capacity = 2
  }

  gateway_ip_configuration {
    name      = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appgw-ipconfig"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_ip_configuration {
    name                 = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appgw-frontend-ipconfig"
    public_ip_address_id = azurerm_public_ip.appgw_ip.id
  }

  frontend_port {
    name = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appgw-http-port"
    port = 80
  }

  backend_address_pool {
    name         = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appgw-backend-pool"
    fqdns        = [azurerm_windows_web_app.appsvc_app.default_hostname]
    ip_addresses = []
  }

  backend_http_settings {
    name                                = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appgw-http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 1
    pick_host_name_from_backend_address = true
  }

  http_listener {
    name                           = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appgw-http-listener"
    frontend_ip_configuration_name = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appgw-frontend-ipconfig"
    frontend_port_name             = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appgw-http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appgw-http-rule"
    rule_type                  = "Basic"
    http_listener_name         = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appgw-http-listener"
    backend_address_pool_name  = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appgw-backend-pool"
    backend_http_settings_name = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-appgw-http-settings"
    priority                   = 10
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Detection"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  ### Application Gateway properties are modified by Kubernetes as Ingress features are applied,
  ### adding a lifecycle block ignores updates to those properties after resource creation
  lifecycle {
    ignore_changes = [
      tags
    ]
  }

  depends_on = [azurerm_subnet.appgw_subnet]
}

##############################################################################
# * SQL Azure Database
resource "azurerm_mssql_server" "sqldb_server" {
  name                          = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-db-server"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.group.name
  version                       = "12.0"
  administrator_login           = "badmin"
  administrator_login_password  = "VMPass@word1!"
  public_network_access_enabled = false

  lifecycle {
    ignore_changes = [
      identity
    ]
  }

  depends_on = [azurerm_subnet.database_subnet]
}

resource "azurerm_mssql_database" "sqldb" {
  name      = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-sqldb"
  server_id = azurerm_mssql_server.sqldb_server.id
  sku_name  = "S0"
}

resource "azurerm_private_endpoint" "sqldb_private_endpoint" {
  name                = "${azurerm_mssql_server.sqldb_server.name}-private-endpoint"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  subnet_id           = azurerm_subnet.database_subnet.id

  private_service_connection {
    name                           = "${azurerm_mssql_server.sqldb_server.name}-private-link"
    is_manual_connection           = "false"
    private_connection_resource_id = azurerm_mssql_server.sqldb_server.id
    subresource_names              = ["sqlServer"]
  }
}

resource "azurerm_private_dns_zone" "sqldb_private_dns_zone" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_private_dns_a_record" "sqldb_private_endpoint_a_record" {
  name                = azurerm_mssql_server.sqldb_server.name
  zone_name           = azurerm_private_dns_zone.sqldb_private_dns_zone.name
  resource_group_name = azurerm_resource_group.group.name
  ttl                 = 10
  records             = [azurerm_private_endpoint.sqldb_private_endpoint.private_service_connection.0.private_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "sqldb_private_dns_zone_vnet_link" {
  name                  = "${azurerm_mssql_server.sqldb_server.name}-vnet-link"
  resource_group_name   = azurerm_resource_group.group.name
  private_dns_zone_name = azurerm_private_dns_zone.sqldb_private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}