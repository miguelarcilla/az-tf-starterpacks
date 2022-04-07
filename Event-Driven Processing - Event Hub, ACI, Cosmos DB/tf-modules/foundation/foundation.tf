##############################################################################
# * Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.solution_prefix}${var.solution_suffix}-vnet"
  location            = var.location
  address_space       = ["10.0.0.0/16"]
  resource_group_name = var.resource_group.name
}

resource "azurerm_subnet" "eventhub_subnet" {
  name                                            = "EventHubSubnet"
  virtual_network_name                            = azurerm_virtual_network.vnet.name
  resource_group_name                             = var.resource_group.name
  address_prefixes                                = ["10.0.1.0/24"]
  enforce_private_link_endpoint_network_policies  = true
}

resource "azurerm_subnet" "aci_subnet" {
  name                                            = "AciSubnet"
  virtual_network_name                            = azurerm_virtual_network.vnet.name
  resource_group_name                             = var.resource_group.name
  address_prefixes                                = ["10.0.3.0/24"]
  enforce_private_link_endpoint_network_policies  = true
  delegation {
    name = "ACIDelegationService"
    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
      name = "Microsoft.ContainerInstance/containerGroups"
    }
  }
}

resource "azurerm_subnet" "database_subnet" {
  name                                            = "DatabaseSubnet"
  virtual_network_name                            = azurerm_virtual_network.vnet.name
  resource_group_name                             = var.resource_group.name
  address_prefixes                                = ["10.0.4.0/24"]
  enforce_private_link_endpoint_network_policies  = true
}

resource "azurerm_subnet" "vm_subnet" {
  name                                            = "VmSubnet"
  virtual_network_name                            = azurerm_virtual_network.vnet.name
  resource_group_name                             = var.resource_group.name
  address_prefixes                                = ["10.0.5.0/24"]
  enforce_private_link_endpoint_network_policies  = true
  service_endpoints                               = []
}

resource "azurerm_subnet" "bastion_subnet" {
  name                                            = "AzureBastionSubnet"
  virtual_network_name                            = azurerm_virtual_network.vnet.name
  resource_group_name                             = var.resource_group.name
  address_prefixes                                = ["10.0.6.0/24"]
  enforce_private_link_endpoint_network_policies  = true
  service_endpoints                               = []
}

##############################################################################
# * Azure Bastion
resource "azurerm_public_ip" "bastion_ip" {
  name                = "${var.solution_prefix}${var.solution_suffix}-bastion-pip"
  location            = var.location
  resource_group_name = var.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "${var.solution_prefix}${var.solution_suffix}-bastion"
  location            = var.location
  resource_group_name = var.resource_group.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_ip.id
  }
}


##############################################################################
# * Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "${var.solution_prefix}${var.solution_suffix}acr"
  location            = var.location
  resource_group_name = var.resource_group.name
  sku                 = "Basic"
  admin_enabled       = true
}

##############################################################################
# * Logging Container Insights
resource "azurerm_log_analytics_workspace" "la_workspace" {
    name                = "${var.solution_prefix}${var.solution_suffix}-workspace"
    location            = var.location
    resource_group_name = var.resource_group.name
    sku                 = "Free"
}

resource "azurerm_log_analytics_solution" "la_solution_containerinsights" {
    solution_name         = "ContainerInsights"
    location              = var.location
    resource_group_name   = var.resource_group.name
    workspace_resource_id = azurerm_log_analytics_workspace.la_workspace.id
    workspace_name        = azurerm_log_analytics_workspace.la_workspace.name

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}

##############################################################################
# * Key Vault
resource "azurerm_key_vault" "keyvault" {
  name                = "${var.solution_prefix}${var.solution_suffix}-keyvault"
  location            = var.location
  resource_group_name = var.resource_group.name
  sku_name            = "standard"
  tenant_id           = var.client_config.tenant_id
}

resource "azurerm_key_vault_access_policy" "keyvault_currentuser_policy" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = var.client_config.tenant_id
  object_id    = var.client_config.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge"
  ]

  certificate_permissions = [
    "Get",
    "List",
    "Update",
    "Create",
    "Import",
    "Delete",
    "Purge"
  ]
}

##############################################################################
# * Azure Utility Storage
resource "azurerm_storage_account" "storage" {
  name                     = "${var.solution_prefix}${var.solution_suffix}stg"
  location                 = var.location
  resource_group_name      = var.resource_group.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}