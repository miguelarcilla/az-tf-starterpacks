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
# Azure Container Registry
# Log Analytics and Container Insights Configuration
# Azure Kubernetes Service with User-Managed Identity
#   Configuration scripts for AAD Pod Identity and Application Gateway Ingress
# Azure Key Vault and SQL Azure Database secrets
# Application Gateway
# SQL Azure Database with Private Link
# Cosmos DB Account with Private Link
##############################################################################
# * Initialize providers

# Configure the top-level Terraform block
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.12.0"
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

resource "azurerm_subnet" "database_subnet" {
  name                                            = "DatabaseSubnet"
  virtual_network_name                            = azurerm_virtual_network.vnet.name
  resource_group_name                             = azurerm_resource_group.group.name
  address_prefixes                                = ["172.16.5.0/24"]
  enforce_private_link_endpoint_network_policies  = true
}

##############################################################################
# * Network Security Groups
resource "azurerm_network_security_group" "appgw_nsg" {
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

resource "azurerm_subnet_network_security_group_association" "appgw_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.appgw_subnet.id
  network_security_group_id = azurerm_network_security_group.appgw_nsg.id
}

##############################################################################
# * Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "${var.solution_prefix}acr${random_id.solution_random_suffix.dec}"
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
    sku                 = "PerGB2018"
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
# resource "azurerm_storage_account" "static_web_storage" {
#     name                     = "${var.solution_prefix}${random_id.solution_random_suffix.dec}"
#     resource_group_name      = azurerm_resource_group.group.name
#     location                 = var.location
#     account_replication_type = "LRS"
#     account_tier             = "Standard"
#     account_kind             = "StorageV2"

#     static_website {
#       index_document = "index.html"
#     }
# }

# resource "azurerm_storage_blob" "static_web_file_index_html" {
#   name                   = "index.html"
#   storage_account_name   = azurerm_storage_account.static_web_storage.name
#   storage_container_name = "$web"
#   type                   = "Block"
#   content_type           = "text/html"
#   source                 = "web/index.html"
# }

##############################################################################
# * Kubernetes Cluster
resource "azurerm_user_assigned_identity" "aks_mi" {
  name                = "${var.solution_prefix}-aks-cluster-mi"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.solution_prefix}-aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  dns_prefix          = var.solution_prefix
  kubernetes_version  = "1.24.6"
  node_resource_group = "${var.solution_prefix}-nodes-rg"

  default_node_pool {
    name            = "agentpool"
    node_count      = 1
    vm_size         = "Standard_D2as_v4"
    vnet_subnet_id  = azurerm_subnet.kubernetes_subnet.id
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.aks_mi.id
    ]
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.appgw.id
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.la_workspace.id
  }

  depends_on = [azurerm_subnet.kubernetes_subnet]
}

resource "azurerm_role_assignment" "aks_role_mioperator" {
  scope                = azurerm_user_assigned_identity.aks_mi.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.aks_mi.principal_id
  depends_on           = [azurerm_kubernetes_cluster.aks]
}

resource "null_resource" "aks_update" {
  provisioner "local-exec" {
    command = "az aks update -g ${azurerm_resource_group.group.name} -n ${azurerm_kubernetes_cluster.aks.name} --enable-pod-identity"
  }
  depends_on = [azurerm_kubernetes_cluster.aks, azurerm_role_assignment.aks_role_mioperator]
}

resource "null_resource" "aks_add_podidentity" {
  provisioner "local-exec" {
    command = "az aks pod-identity add --namespace weather-share -g ${azurerm_resource_group.group.name} --cluster-name ${azurerm_kubernetes_cluster.aks.name} --name ${azurerm_user_assigned_identity.aks_mi.name} --identity-resource-id ${azurerm_user_assigned_identity.aks_mi.id}"
  }
  depends_on = [azurerm_kubernetes_cluster.aks, null_resource.aks_update, azurerm_role_assignment.aks_role_mioperator]
}

resource "azurerm_role_assignment" "aks_role_rgmioperator" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_kubernetes_cluster.aks.node_resource_group}"
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  depends_on           = [azurerm_kubernetes_cluster.aks]
}

resource "azurerm_role_assignment" "aks_role_rgvmcontributor" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_kubernetes_cluster.aks.node_resource_group}"
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  depends_on           = [azurerm_kubernetes_cluster.aks]
}

resource "azurerm_role_assignment" "aks_role_acrpull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  depends_on = [azurerm_kubernetes_cluster.aks, azurerm_application_gateway.appgw, null_resource.aks_update, null_resource.aks_add_podidentity]
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

resource "azurerm_user_assigned_identity" "appgw_mi" {
  name                = "${var.solution_prefix}-appgw-mi"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_application_gateway" "appgw" {
  name                = "${var.solution_prefix}-appgw"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name

  identity {
    type = "UserAssigned"
    identity_ids = [ azurerm_user_assigned_identity.appgw_mi.id ]
  }

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

  ssl_certificate {
    name                = azurerm_key_vault_certificate.keyvault_cert_appgwssl.name
    key_vault_secret_id = azurerm_key_vault_certificate.keyvault_cert_appgwssl.secret_id
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

resource "azurerm_role_assignment" "appgw_role_mioperator" {
  scope                = azurerm_user_assigned_identity.appgw_mi.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.appgw_mi.principal_id
  depends_on           = [azurerm_application_gateway.appgw]
}

resource "azurerm_role_assignment" "aks_role_appgwcontributor" {
  scope                = azurerm_application_gateway.appgw.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  depends_on           = [azurerm_kubernetes_cluster.aks, azurerm_application_gateway.appgw]
}

##############################################################################
# * Key Vault
resource "azurerm_key_vault" "keyvault" {
  name                = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-keyvault"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
}

resource "azurerm_key_vault_access_policy" "keyvault_currentuser_policy" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Backup",
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Set"
  ]
  
  certificate_permissions = [
    "Backup",
    "Create",
    "Delete",
    "DeleteIssuers",
    "Get",
    "GetIssuers",
    "Import",
    "List",
    "ListIssuers",
    "ManageContacts",
    "ManageIssuers",
    "Purge",
    "Recover",
    "Restore",
    "SetIssuers",
    "Update"
  ]
}

resource "azurerm_key_vault_access_policy" "keyvault_aks_policy" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

resource "azurerm_key_vault_access_policy" "keyvault_aksmi_policy" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.aks_mi.principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

resource "azurerm_key_vault_access_policy" "keyvault_appgwmi_policy" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.appgw_mi.principal_id

  secret_permissions = [
    "Get"
  ]
  certificate_permissions = [
    "Get"
  ]
}

resource "azurerm_key_vault_certificate" "keyvault_cert_appgwssl" {
  name         = "${var.solution_prefix}-appgwsslcert"
  key_vault_id = azurerm_key_vault.keyvault.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject            = "CN=${var.solution_prefix}"
      validity_in_months = 12
    }
  }
  
  depends_on = [azurerm_key_vault_access_policy.keyvault_currentuser_policy]
}

resource "azurerm_key_vault_secret" "keyvault_secret_mssql_dbadmin" {
  name         = "mssql-dbadmin"
  value        = "4dm1n157r470r"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvault_currentuser_policy]
}

resource "azurerm_key_vault_secret" "keyvault_secret_mssql_dbpassword" {
  name         = "mssql-password"
  value        = "4-v3ry-53cr37-p455w0rd"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvault_currentuser_policy]
}

##############################################################################
# * SQL Azure Database
resource "azurerm_mssql_server" "sqldb_server" {
  name                          = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-db-server"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.group.name
  version                       = "12.0"
  administrator_login           = azurerm_key_vault_secret.keyvault_secret_mssql_dbadmin.value
  administrator_login_password  = azurerm_key_vault_secret.keyvault_secret_mssql_dbpassword.value
  public_network_access_enabled = false

  lifecycle {
    ignore_changes = [ 
      identity
     ]
  }

  depends_on = [azurerm_subnet.database_subnet]
}

resource "azurerm_mssql_database" "sqldb" {
  name                = "${var.solution_prefix}-sqldb"
  server_id           = azurerm_mssql_server.sqldb_server.id
  sku_name            = "S0"
}

resource "azurerm_private_endpoint" "sqldb_private_endpoint" {
  name                     = "${azurerm_mssql_server.sqldb_server.name}-private-endpoint"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.group.name
  subnet_id                = azurerm_subnet.database_subnet.id

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

resource "azurerm_key_vault_secret" "keyvault_secret_mssql_dbconnstr" {
  name         = "mssql-dbconnstr"
  value        = "Server=tcp:${azurerm_private_dns_a_record.sqldb_private_endpoint_a_record.fqdn},1433;Initial Catalog=${var.solution_prefix}-sqldb;Persist Security Info=False;User ID=${azurerm_key_vault_secret.keyvault_secret_mssql_dbadmin.value};Password=${azurerm_key_vault_secret.keyvault_secret_mssql_dbpassword.value};MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_private_dns_a_record.sqldb_private_endpoint_a_record, azurerm_key_vault_access_policy.keyvault_currentuser_policy]
}

##############################################################################
# * Cosmos DB
resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                      = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-cosmosdb-server"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.group.name
  offer_type                = "Standard"
  kind                      = "GlobalDocumentDB"
  # enable_free_tier          = true

  capabilities {
    name = "EnableServerless"
  }

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 10
    max_staleness_prefix    = 200
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "cosmosdb_sql_db" {
  name                = "weather-share-cosmosdb"
  resource_group_name = azurerm_resource_group.group.name
  account_name        = azurerm_cosmosdb_account.cosmosdb.name
  ### Throughput should not be set when azurerm_cosmosdb_account is configured with EnableServerless capability
  # throughput          = 400
}

resource "azurerm_private_endpoint" "cosmosdb_private_endpoint" {
  name                     = "${azurerm_cosmosdb_account.cosmosdb.name}-private-endpoint"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.group.name
  subnet_id                = azurerm_subnet.database_subnet.id

  private_service_connection {
    name                           = "${azurerm_cosmosdb_account.cosmosdb.name}-private-link"
    is_manual_connection           = "false"
    private_connection_resource_id = azurerm_cosmosdb_account.cosmosdb.id
    subresource_names              = ["Sql"]
  }
}

resource "azurerm_private_dns_zone" "cosmosdb_private_dns_zone" {
  name                = "privatelink.documents.azure.com"
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_private_dns_a_record" "cosmosdb_private_endpoint_a_record" {
  name                = azurerm_cosmosdb_account.cosmosdb.name
  zone_name           = azurerm_private_dns_zone.cosmosdb_private_dns_zone.name
  resource_group_name = azurerm_resource_group.group.name
  ttl                 = 10
  records             = [azurerm_private_endpoint.cosmosdb_private_endpoint.custom_dns_configs.0.ip_addresses.0]
}

resource "azurerm_private_dns_a_record" "cosmosdb_private_endpoint_region1_a_record" {
  name                = "${azurerm_cosmosdb_account.cosmosdb.name}-${var.location}"
  zone_name           = azurerm_private_dns_zone.cosmosdb_private_dns_zone.name
  resource_group_name = azurerm_resource_group.group.name
  ttl                 = 10
  records             = [azurerm_private_endpoint.cosmosdb_private_endpoint.custom_dns_configs.1.ip_addresses.0]
}

resource "azurerm_private_dns_zone_virtual_network_link" "cosmosdb_private_dns_zone_vnet_link" {
  name                  = "${azurerm_cosmosdb_account.cosmosdb.name}-vnet-link"
  resource_group_name   = azurerm_resource_group.group.name
  private_dns_zone_name = azurerm_private_dns_zone.cosmosdb_private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

resource "azurerm_key_vault_secret" "keyvault_secret_cosmosdb_accountendpoint" {
  name         = "cosmosdb-accountendpoint"
  value        = azurerm_cosmosdb_account.cosmosdb.endpoint
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_cosmosdb_account.cosmosdb, azurerm_key_vault_access_policy.keyvault_currentuser_policy]
}

resource "azurerm_key_vault_secret" "keyvault_secret_cosmosdb_primarykey" {
  name         = "cosmosdb-primarykey"
  value        = azurerm_cosmosdb_account.cosmosdb.primary_key
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_cosmosdb_account.cosmosdb, azurerm_key_vault_access_policy.keyvault_currentuser_policy]
}

##############################################################################
# * MariaDB
resource "azurerm_mariadb_server" "mariadb_server" {
  name                          = "${var.solution_prefix}-${random_id.solution_random_suffix.dec}-mariadb-server"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.group.name
  
  administrator_login           = "A${azurerm_key_vault_secret.keyvault_secret_mssql_dbadmin.value}"
  administrator_login_password  = azurerm_key_vault_secret.keyvault_secret_mssql_dbpassword.value
  
  version                       = "10.2"
  sku_name                      = "GP_Gen5_2"
  storage_mb                    = 5120

  public_network_access_enabled = false
  ssl_enforcement_enabled       = true
  
  depends_on = [azurerm_subnet.database_subnet]
}

resource "azurerm_mariadb_database" "mariadb" {
  name                = "${var.solution_prefix}mariadb"
  resource_group_name = azurerm_resource_group.group.name
  server_name         = azurerm_mariadb_server.mariadb_server.name
  charset             = "utf8"
  collation           = "utf8_general_ci"
}

resource "azurerm_private_endpoint" "mariadb_private_endpoint" {
  name                     = "${azurerm_mariadb_server.mariadb_server.name}-private-endpoint"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.group.name
  subnet_id                = azurerm_subnet.database_subnet.id

  private_service_connection {
    name                           = "${azurerm_mariadb_server.mariadb_server.name}-private-link"
    is_manual_connection           = "false"
    private_connection_resource_id = azurerm_mariadb_server.mariadb_server.id
    subresource_names              = ["mariadbServer"]
  }
}

resource "azurerm_private_dns_zone" "mariadb_private_dns_zone" {
  name                = "privatelink.mariadb.database.azure.com"
  resource_group_name = azurerm_resource_group.group.name
}

resource "azurerm_private_dns_a_record" "mariadb_private_endpoint_a_record" {
  name                = azurerm_mariadb_server.mariadb_server.name
  zone_name           = azurerm_private_dns_zone.mariadb_private_dns_zone.name
  resource_group_name = azurerm_resource_group.group.name
  ttl                 = 10
  records             = [azurerm_private_endpoint.mariadb_private_endpoint.private_service_connection.0.private_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "mariadb_private_dns_zone_vnet_link" {
  name                  = "${azurerm_mariadb_server.mariadb_server.name}-vnet-link"
  resource_group_name   = azurerm_resource_group.group.name
  private_dns_zone_name = azurerm_private_dns_zone.mariadb_private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}