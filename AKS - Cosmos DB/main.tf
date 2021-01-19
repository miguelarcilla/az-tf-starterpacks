##############################################################################
# This Terraform configuration will create the following:
#
# Resource group with a virtual network and standard subnets
# An Ubuntu Linux server running Apache

##############################################################################
# * Shared infrastructure resources

# Configure the Azure Provider
provider "azurerm" {
  version         = "=2.40.0"
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
  address_space       = ["172.16.0.0/16"]
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_subnet" "kubernetes_subnet" {
  name                 = "KubernetesSubnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.group.name
  address_prefixes     = ["172.16.128.0/17"]
}

##############################################################################
# * Container Registry
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  sku                 = "Basic"
  admin_enabled       = false
}

##############################################################################
# * Kubernetes Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  dns_prefix          = var.kubernetes_dns_prefix
  kubernetes_version  = "1.18.10"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  linux_profile {
    admin_username = "badmin"
    ssh_key {
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDi7Ad3zVh+lr/ATZn+njbba9SU1IEqcuARjWqEpV6a6slga8iCXaeWwZlrC5VTneJ5ov05IChxrR6UgF86kRn58hVBVZuLTJID58lL4NwAt0Is3IoDgH+EzQZV0EIA/xMyW2kpqZvdtonCFI390pGbOOGLrT3WXYFHwKRd+ZPj3Od/pQh/dIWHMa2FC6idFWFBsSAaAIriuWheYIJncTxDq28zHQW5HIALtxsbyeHQ76j7Iu8TJDDfupAMQhC+OXcm5z86+qwPXnjvhZy/iio8XhvkzJ6aQlmW70NFjfk0gHCb3riMVuXI9HmyHl8mJv7y2v41gyfgIobNm3sjJ4TNlk6RxOcQZa0cXs+TUa5kPMsBrkX3/vfACpiNr+Y3Mx5iqXWaKScS+vGiATKPlhKKuLCdYjH0rPI7eo9q7KaoPUAvanHV6bIjh1kgvubIhC9jTcR5U8ZVAsX2pardOj69+NTgxIqHH9pK6QnqJR5xTaZRYcZOHsJucrG2peJ5p7U= generated-by-azure"
    }
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    dns_service_ip     = "10.0.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
    service_cidr       = "10.0.0.0/16"
  }

  role_based_access_control {
    enabled = true
  }
}


# ##############################################################################
# # * Application Gateway
# resource "azurerm_public_ip" "appgw_ip" {
#   name                = "${var.app_name}-pip"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.group.name
#   allocation_method   = "Dynamic"
#   sku                 = "Basic"
# }

# resource "azurerm_application_gateway" "appgw" {
#   name                = "${var.app_name}gw"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.group.name

#   sku {
#     name     = "WAF_Medium"
#     tier     = "WAF"
#     capacity = 1
#   }

#   gateway_ip_configuration {
#     name      = "${var.app_name}gw-ipconfig"
#     subnet_id = azurerm_subnet.public_subnet.id
#   }

#   frontend_port {
#     name = "${var.app_name}gw-http-port"
#     port = 80
#   }

#   frontend_ip_configuration {
#     name                 = "${var.app_name}gw-frontend-ipconfig"
#     public_ip_address_id = azurerm_public_ip.appgw_ip.id
#   }

#   backend_address_pool {
#     name          = "${var.app_name}gw-backend-pool"
#     ip_addresses  = [
#       azurerm_windows_virtual_machine.app.private_ip_address,
#       azurerm_windows_virtual_machine.app2.private_ip_address
#     ]
#   }

#   backend_http_settings {
#     name                  = "${var.app_name}gw-http-settings"
#     cookie_based_affinity = "Disabled"
#     port                  = 80
#     protocol              = "Http"
#     request_timeout       = 10
#   }

#   http_listener {
#     name                           = "${var.app_name}gw-http-listener"
#     frontend_ip_configuration_name = "${var.app_name}gw-frontend-ipconfig"
#     frontend_port_name             = "${var.app_name}gw-http-port"
#     protocol                       = "Http"
#   }

#   request_routing_rule {
#     name                       = "${var.app_name}gw-http-rule"
#     rule_type                  = "Basic"
#     http_listener_name         = "${var.app_name}gw-http-listener"
#     backend_address_pool_name  = "${var.app_name}gw-backend-pool"
#     backend_http_settings_name = "${var.app_name}gw-http-settings"
#   }
# }

# ##############################################################################
# # * SQL Azure Database
# resource "azurerm_mssql_server" "db_server" {
#   name                          = "${var.db_name}-server"
#   location                      = var.location
#   resource_group_name           = azurerm_resource_group.group.name
#   version                       = "12.0"
#   administrator_login           = var.db_admin_username
#   administrator_login_password  = var.db_admin_password
#   public_network_access_enabled = false
# }

# resource "azurerm_mssql_database" "db" {
#   name                = var.db_name
#   server_id           = azurerm_mssql_server.db_server.id
#   sku_name            = "GP_Gen5_4"
#   max_size_gb         = 512
#   collation           = "SQL_Latin1_General_CP1_CI_AS"
# }

# resource "azurerm_private_endpoint" "db_private_endpoint" {
#   name                     = "${azurerm_mssql_server.db_server.name}-private-endpoint"
#   location                 = var.location
#   resource_group_name      = azurerm_resource_group.group.name
#   subnet_id                = azurerm_subnet.database_subnet.id

#   private_service_connection {
#     name                           = "${azurerm_mssql_server.db_server.name}-private-link"
#     is_manual_connection           = "false"
#     private_connection_resource_id = azurerm_mssql_server.db_server.id
#     subresource_names              = ["sqlServer"]
#   }
# }

# resource "azurerm_private_dns_zone" "db_private_dns_zone" {
#   name                = "privatelink.database.windows.net"
#   resource_group_name = azurerm_resource_group.group.name
# }

# resource "azurerm_private_dns_a_record" "db_private_endpoint_a_record" {
#   name                = azurerm_mssql_server.db_server.name
#   zone_name           = azurerm_private_dns_zone.db_private_dns_zone.name
#   resource_group_name = azurerm_resource_group.group.name
#   ttl                 = 300
#   records             = [azurerm_private_endpoint.db_private_endpoint.private_service_connection.0.private_ip_address]
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "db_private_dns_zone_vnet_link" {
#   name                  = "${azurerm_mssql_server.db_server.name}-vnet-link"
#   resource_group_name   = azurerm_resource_group.group.name
#   private_dns_zone_name = azurerm_private_dns_zone.db_private_dns_zone.name
#   virtual_network_id    = azurerm_virtual_network.vnet.id
# }