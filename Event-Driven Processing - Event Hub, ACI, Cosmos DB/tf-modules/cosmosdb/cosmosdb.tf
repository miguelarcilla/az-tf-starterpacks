##############################################################################
# * Cosmos DB
resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                      = "${var.solution_prefix}${var.solution_suffix}-cosmosdb-server"
  location                  = var.location
  resource_group_name       = var.resource_group.name
  offer_type                = "Standard"
  kind                      = "GlobalDocumentDB"
  # Disabled just in case a Free Tier DB is already in use
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

resource "azurerm_private_endpoint" "cosmosdb_private_endpoint" {
  name                     = "${azurerm_cosmosdb_account.cosmosdb.name}-private-endpoint"
  location                 = var.location
  resource_group_name      = var.resource_group.name
  subnet_id                = var.database_subnet.id

  private_service_connection {
    name                           = "${azurerm_cosmosdb_account.cosmosdb.name}-private-link"
    is_manual_connection           = "false"
    private_connection_resource_id = azurerm_cosmosdb_account.cosmosdb.id
    subresource_names              = ["Sql"]
  }
}

resource "azurerm_private_dns_zone" "cosmosdb_private_dns_zone" {
  name                = "privatelink.documents.azure.com"
  resource_group_name = var.resource_group.name
}

resource "azurerm_private_dns_a_record" "cosmosdb_private_endpoint_a_record" {
  name                = azurerm_cosmosdb_account.cosmosdb.name
  zone_name           = azurerm_private_dns_zone.cosmosdb_private_dns_zone.name
  resource_group_name = var.resource_group.name
  ttl                 = 10
  records             = [azurerm_private_endpoint.cosmosdb_private_endpoint.custom_dns_configs.0.ip_addresses.0]
}

resource "azurerm_private_dns_a_record" "cosmosdb_private_endpoint_region1_a_record" {
  name                = "${azurerm_cosmosdb_account.cosmosdb.name}-${var.location}"
  zone_name           = azurerm_private_dns_zone.cosmosdb_private_dns_zone.name
  resource_group_name = var.resource_group.name
  ttl                 = 10
  records             = [azurerm_private_endpoint.cosmosdb_private_endpoint.custom_dns_configs.1.ip_addresses.0]
}

resource "azurerm_private_dns_zone_virtual_network_link" "cosmosdb_private_dns_zone_vnet_link" {
  name                  = "${azurerm_cosmosdb_account.cosmosdb.name}-vnet-link"
  resource_group_name   = var.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.cosmosdb_private_dns_zone.name
  virtual_network_id    = var.vnet.id
  registration_enabled  = false
}