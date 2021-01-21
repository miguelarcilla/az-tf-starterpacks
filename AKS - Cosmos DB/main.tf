##############################################################################
# Minimum Terraform version required: 0.13
# This Terraform configuration will create the following:
#
# Resource group with a virtual network and standard subnets
# An Ubuntu Linux server running Apache
##############################################################################
# * Shared infrastructure resources

# Configure the top-level Terraform block
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.40.0"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

resource "random_id" "solution_random_suffix" {
    byte_length = 8
}

resource "azurerm_resource_group" "group" {
  name     = "${var.solution_prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.solution_prefix}-vnet"
  location            = var.location
  address_space       = ["172.16.0.0/20"]
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_subnet" "kubernetes_subnet" {
  name                 = "KubernetesSubnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.group.name
  address_prefixes     = ["172.16.0.0/22"]
}

##############################################################################
# * Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "${var.solution_prefix}acr"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  sku                 = "Basic"
  admin_enabled       = false
}

##############################################################################
# * Logging Container Insights
resource "azurerm_log_analytics_workspace" "la_workspace" {
    name                = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-workspace"
    location            = var.location
    resource_group_name = azurerm_resource_group.group.name
    sku                 = "Free"
}

resource "azurerm_log_analytics_solution" "la_solution_containerinsights" {
    solution_name         = "ContainerInsights"
    location              = var.location
    resource_group_name   = azurerm_resource_group.group.name
    workspace_resource_id = azurerm_log_analytics_workspace.la_workspace.id
    workspace_name        = azurerm_log_analytics_workspace.la_workspace.name

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}

##############################################################################
# * Static Web Files Storage Account
resource "azurerm_storage_account" "static_web_storage" {
    name                     = "${var.solution_prefix}${random_id.solution_random_suffix.dec}"
    resource_group_name      = azurerm_resource_group.group.name
    location                 = var.location
    account_replication_type = "LRS"
    account_tier             = "Standard"
    account_kind             = "StorageV2"

    static_website {
      index_document = "index.html"
    }
}

resource "azurerm_storage_blob" "static_web_file_index_html" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.static_web_storage.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source                 = "web/index.html"
}

##############################################################################
# * Kubernetes Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.solution_prefix}-aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  dns_prefix          = var.solution_prefix
  kubernetes_version  = "1.18.10"
  node_resource_group = "${var.solution_prefix}-nodes-rg"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2as_v4"
  }

  identity {
    type = "SystemAssigned"
  }

  addon_profile {
    kube_dashboard {
      enabled = false
    }

    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.la_workspace.id
    }
  }

  role_based_access_control {
    enabled = true
  }
}

resource "azurerm_role_assignment" "aks_mi_role_acrpull" {
  scope                            = azurerm_container_registry.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
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