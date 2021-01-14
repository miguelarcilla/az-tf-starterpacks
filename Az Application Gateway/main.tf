##############################################################################
# This Terraform configuration will create the following:
#
# Resource group with a virtual network and standard subnets
# An Ubuntu Linux server running Apache

##############################################################################
# * Shared infrastructure resources

# Configure the Azure Provider
provider "azurerm" {
  version = "=2.37.0"
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

resource "azurerm_subnet" "bastion_subnet" {
  name                    = "AzureBastionSubnet"
  virtual_network_name    = azurerm_virtual_network.vnet.name
  resource_group_name     = azurerm_resource_group.group.name
  address_prefixes        = [var.bastion_subnet_prefix]
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
}

resource "azurerm_network_interface" "app2_nic" {
  name                = "${var.app_name}2-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name

  ip_configuration {
    name                          = "${var.app_name}2-ipconfig"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "app2" {
  name                = "${var.app_name}2"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  size                = "Standard_DS12_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.app2_nic.id
  ]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    name                  = "${var.app_name}2-osdisk"
    storage_account_type  = "Standard_LRS"
    caching               = "ReadWrite"
  }
}

##############################################################################
# * Key Vault
resource "azurerm_key_vault" "sslvault" {
  name                            = "${var.app_name}-vault"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.group.name
  tenant_id                       = "72f988bf-86f1-41af-91ab-2d7cd011db47"
  sku_name                        = "standard"
  soft_delete_enabled             = true
  soft_delete_retention_days      = 7 #90
  enabled_for_template_deployment = true
}

resource "azurerm_key_vault_certificate" "sslcert" {
  name         = "SSL-ol-miguelarcilla-com"
  key_vault_id = azurerm_key_vault.sslvault.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = false
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry  = 0
        lifetime_percentage = 80
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      extended_key_usage = [
        "1.3.6.1.5.5.7.3.1",
        "1.3.6.1.5.5.7.3.2",
      ]
      key_usage = [ 
        "digitalSignature",
        "keyEncipherment"
      ]
      subject            = "CN=miguelarcilla.com"
      validity_in_months = 12
    }
  }
}

##############################################################################
# * Application Gateway
resource "azurerm_public_ip" "appgw_ip" {
  name                = "${var.app_name}-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_user_assigned_identity" "appgw_mi" {
  location                    = var.location
  resource_group_name         = azurerm_resource_group.group.name
  name                        = "${var.app_name}-mi"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "${var.app_name}-gw"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name

  identity {
    identity_ids = [ azurerm_user_assigned_identity.appgw_mi.id ]
  }

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "${var.app_name}-gw-ipconfig"
    subnet_id = azurerm_subnet.public_subnet.id
  }

  frontend_port {
    name = "${var.app_name}-gw-http-port"
    port = 80
  }

  frontend_port {
    name = "port_443"
    # name = "${var.app_name}-gw-https-port"
    port = 443
  }

  frontend_ip_configuration {
    name                          = "${var.app_name}-gw-frontend-ipconfig"
    public_ip_address_id          = azurerm_public_ip.appgw_ip.id
  }

  backend_address_pool {
    name          = "${var.app_name}-gw-backend-pool"
    ip_addresses  = [
      azurerm_windows_virtual_machine.app.private_ip_address,
      azurerm_windows_virtual_machine.app2.private_ip_address
    ]
  }

  backend_http_settings {
    name                  = "${var.app_name}-gw-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 10
  }

  http_listener {
    name                           = "${var.app_name}-gw-http-listener"
    frontend_ip_configuration_name = "${var.app_name}-gw-frontend-ipconfig"
    frontend_port_name             = "${var.app_name}-gw-http-port"
    protocol                       = "Http"
  }
  
  http_listener {
    name                           = "${var.app_name}-gw-https-listener"
    frontend_ip_configuration_name = "${var.app_name}-gw-frontend-ipconfig"
    # frontend_port_name             = "${var.app_name}-gw-https-port"
    frontend_port_name             = "port_443"
    protocol                       = "Https"
    ssl_certificate_name           = "${var.app_name}-gw-https-listenervaultCert"
  }

  rewrite_rule_set {
    name = "olrewrite"
    rewrite_rule {
      name          = "tenant-rewrite"
      rule_sequence = 200

      condition {
        variable    = "var_host"
        pattern     = "^(.*)\\\\.(.*)\\\\.(.*)$"
        ignore_case = true
        negate      = false
      }
    }
  }

  request_routing_rule {
    name                       = "${var.app_name}-gw-http-rule"
    rule_type                  = "Basic"
    http_listener_name         = "${var.app_name}-gw-http-listener"
    backend_address_pool_name  = "${var.app_name}-gw-backend-pool"
    backend_http_settings_name = "${var.app_name}-gw-http-settings"
    rewrite_rule_set_name      = "olrewrite"
  }
  
  request_routing_rule {
    name                       = "${var.app_name}-gw-https-rule"
    rule_type                  = "Basic"
    http_listener_name         = "${var.app_name}-gw-https-listener"
    backend_address_pool_name  = "${var.app_name}-gw-backend-pool"
    backend_http_settings_name = "${var.app_name}-gw-http-settings"
    rewrite_rule_set_name      = "olrewrite"
  }

  ssl_certificate {
    name = "${var.app_name}-gw-https-listenervaultCert"
    key_vault_secret_id = azurerm_key_vault_certificate.sslcert.id
  }
}