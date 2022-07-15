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
      version = "~> 3.13.0"
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
  name     = "${var.solution_prefix}-rg"
  location = var.location
}

##############################################################################
# * Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.solution_prefix}-vnet"
  location            = var.location
  address_space       = ["172.16.0.0/21"]
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_subnet" "kubernetes_subnet" {
  name                 = "KubernetesSubnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.group.name
  address_prefixes     = ["172.16.0.0/22"]
}

resource "azurerm_subnet" "appgw_subnet" {
  name                 = "AppGatewaySubnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.group.name
  address_prefixes     = ["172.16.4.0/24"]
}

##############################################################################
# * Network Security Groups
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.solution_prefix}-subnet-appgateway-nsg"
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

resource "azurerm_subnet_network_security_group_association" "kubernetes_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.kubernetes_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "appgw_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.appgw_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

##############################################################################
# * Kubernetes Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.solution_prefix}-aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  dns_prefix          = var.solution_prefix
  kubernetes_version  = "1.22.6"
  node_resource_group = "${var.solution_prefix}-nodes-rg"

  default_node_pool {
    name            = "agentpool"
    node_count      = 1
    vm_size         = "Standard_D2as_v4"
    vnet_subnet_id  = azurerm_subnet.kubernetes_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  ### Temporarily commented out until the AGIC MI is more configurable in Terraform
  # ingress_application_gateway {
  #   gateway_id = azurerm_application_gateway.appgw.id
  # }

  depends_on = [azurerm_subnet.kubernetes_subnet]
}

# ##############################################################################
# # * Application Gateway
resource "azurerm_public_ip" "appgw_ip" {
  name                = "${var.solution_prefix}-appgw-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "${var.solution_prefix}-appgw"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
  }

  autoscale_configuration {
    min_capacity = 0
    max_capacity = 2
  }

  gateway_ip_configuration {
    name      = "${var.solution_prefix}-appgw-ipconfig"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_ip_configuration {
    name                 = "${var.solution_prefix}-appgw-frontend-ipconfig"
    public_ip_address_id = azurerm_public_ip.appgw_ip.id
  }

  frontend_port {
    name = "${var.solution_prefix}-appgw-http-port"
    port = 80
  }

  backend_address_pool {
    name          = "${var.solution_prefix}-appgw-backend-pool"
  }

  backend_http_settings {
    name                  = "${var.solution_prefix}-appgw-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = "${var.solution_prefix}-appgw-http-listener"
    frontend_ip_configuration_name = "${var.solution_prefix}-appgw-frontend-ipconfig"
    frontend_port_name             = "${var.solution_prefix}-appgw-http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "${var.solution_prefix}-appgw-http-rule"
    rule_type                  = "Basic"
    http_listener_name         = "${var.solution_prefix}-appgw-http-listener"
    backend_address_pool_name  = "${var.solution_prefix}-appgw-backend-pool"
    backend_http_settings_name = "${var.solution_prefix}-appgw-http-settings"
    priority                   = 10
  }
  
  ### Application Gateway properties are modified by Kubernetes as Ingress features are applied,
  ### adding a lifecycle block ignores updates to those properties after resource creation
  lifecycle {
    ignore_changes = [
      tags,
      backend_address_pool,
      backend_http_settings,
      http_listener,
      request_routing_rule,
      probe,
      frontend_port,
      redirect_configuration
    ]
  }

  depends_on = [azurerm_subnet.appgw_subnet]
}