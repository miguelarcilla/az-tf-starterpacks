##############################################################################
# Minimum Terraform version required: 0.13
# This Terraform configuration will create the following:
#
# Resource group with a virtual network and standard subnets
# An Ubuntu Linux server running Apache
##############################################################################
# * Initialize providers

# Configure the top-level Terraform block
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.45.0"
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
  address_space       = ["172.16.0.0/20"]
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
  address_prefixes     = ["172.16.4.0/22"]
}

resource "azurerm_subnet" "database_subnet" {
  name                                            = "DatabaseSubnet"
  virtual_network_name                            = azurerm_virtual_network.vnet.name
  resource_group_name                             = azurerm_resource_group.group.name
  address_prefixes                                = ["172.16.8.0/22"]
  enforce_private_link_endpoint_network_policies  = true
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
  kubernetes_version  = "1.18.10"
  node_resource_group = "${var.solution_prefix}-nodes-rg"

  default_node_pool {
    name            = "agentpool"
    node_count      = 1
    vm_size         = "Standard_D2as_v4"
    vnet_subnet_id  = azurerm_subnet.kubernetes_subnet.id
  }

  identity {
    type = "UserAssigned"
    user_assigned_identity_id = azurerm_user_assigned_identity.aks_mi.id
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  addon_profile {
    kube_dashboard {
      enabled = false
    }

    http_application_routing {
      enabled = false
    }

    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.la_workspace.id
    }
  }

  role_based_access_control {
    enabled = false
  }
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
  depends_on           = [azurerm_kubernetes_cluster.aks, azurerm_container_registry.acr]
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
    min_capacity = 1
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
  }
}

resource "azurerm_role_assignment" "aks_role_appgwcontributor" {
  scope                = azurerm_application_gateway.appgw.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  depends_on           = [azurerm_kubernetes_cluster.aks, azurerm_application_gateway.appgw]
}

resource "null_resource" "aks_add_appgwingress" {
  provisioner "local-exec" {
    command = "az aks enable-addons -n ${azurerm_kubernetes_cluster.aks.name} -g ${azurerm_resource_group.group.name} -a ingress-appgw --appgw-id ${azurerm_application_gateway.appgw.id}"
  }
  depends_on = [azurerm_kubernetes_cluster.aks, azurerm_application_gateway.appgw]
}

##############################################################################
# * Key Vault
resource "azurerm_key_vault" "keyvault" {
  name                = "${var.solution_prefix}-keyvault"
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
    "get",
    "list",
    "set",
    "delete"
  ]
}

resource "azurerm_key_vault_access_policy" "keyvault_azcli_policy" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"

  secret_permissions = [
    "get",
    "list",
    "set",
    "delete",
    "recover",
    "backup",
    "restore",
    "purge"
  ]
}

resource "azurerm_key_vault_access_policy" "keyvault_aks_policy" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id

  secret_permissions = [
    "get",
    "list",
    "set",
    "delete"
  ]
}

resource "azurerm_key_vault_access_policy" "keyvault_aksmi_policy" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.aks_mi.principal_id

  secret_permissions = [
    "get",
    "list",
    "set",
    "delete"
  ]
}

resource "azurerm_key_vault_secret" "keyvault_secret_mssql_dbadmin" {
  name         = "mssql-dbadmin"
  value        = "4dm1n157r470r"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvault_currentuser_policy , azurerm_key_vault_access_policy.keyvault_azcli_policy]
}

resource "azurerm_key_vault_secret" "keyvault_secret_mssql_dbpassword" {
  name         = "mssql-password"
  value        = "4-v3ry-53cr37-p455w0rd"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvault_currentuser_policy , azurerm_key_vault_access_policy.keyvault_azcli_policy]
}

##############################################################################
# * SQL Azure Database
resource "azurerm_mssql_server" "db_server" {
  name                          = "${var.solution_prefix}-db-server"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.group.name
  version                       = "12.0"
  administrator_login           = azurerm_key_vault_secret.keyvault_secret_mssql_dbadmin.value
  administrator_login_password  = azurerm_key_vault_secret.keyvault_secret_mssql_dbpassword.value
  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "db" {
  name                = "${var.solution_prefix}-db"
  server_id           = azurerm_mssql_server.db_server.id
  sku_name            = "S0"
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
  ttl                 = 10
  records             = [azurerm_private_endpoint.db_private_endpoint.private_service_connection.0.private_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "db_private_dns_zone_vnet_link" {
  name                  = "${azurerm_mssql_server.db_server.name}-vnet-link"
  resource_group_name   = azurerm_resource_group.group.name
  private_dns_zone_name = azurerm_private_dns_zone.db_private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = true
}

resource "azurerm_key_vault_secret" "keyvault_secret_mssql_dbconnstr" {
  name         = "mssql-dbconnstr"
  value        = "Server=tcp:${azurerm_private_dns_a_record.db_private_endpoint_a_record.fqdn},1433;Initial Catalog=${var.solution_prefix}-db;Persist Security Info=False;User ID=${azurerm_key_vault_secret.keyvault_secret_mssql_dbadmin.value};Password=${azurerm_key_vault_secret.keyvault_secret_mssql_dbpassword.value};MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_private_dns_a_record.db_private_endpoint_a_record, azurerm_key_vault_access_policy.keyvault_currentuser_policy, azurerm_key_vault_access_policy.keyvault_azcli_policy]
}