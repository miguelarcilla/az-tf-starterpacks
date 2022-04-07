##############################################################################
# * Azure Event Hub
resource "azurerm_eventhub_namespace" "eventhub_namespace" {
  name                = "${var.solution_prefix}${var.solution_suffix}-eventhub"
  location            = var.location
  resource_group_name = var.resource_group.name
  sku                 = "Standard"
  capacity            = 1
}

resource "azurerm_eventhub" "eventhub" {
  name                = "${var.solution_prefix}EventHub"
  namespace_name      = azurerm_eventhub_namespace.eventhub_namespace.name
  resource_group_name = var.resource_group.name
  partition_count     = 2
  message_retention   = 1

  capture_description {
    enabled             = true
    encoding            = "Avro"
    interval_in_seconds = 300
    size_limit_in_bytes = 314572800
    skip_empty_archives = false

    destination {
      archive_name_format = "{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}"
      blob_container_name = "eventhubcaptures"
      name                = "EventHubArchive.AzureBlockBlob"
      storage_account_id  = var.storage_account.id
    }
  }
}

resource "azurerm_private_endpoint" "eventhub_private_endpoint" {
  name                     = "${azurerm_eventhub_namespace.eventhub_namespace.name}-private-endpoint"
  location                 = var.location
  resource_group_name      = var.resource_group.name
  subnet_id                = var.eventhub_subnet.id

  private_service_connection {
    name                           = "${azurerm_eventhub_namespace.eventhub_namespace.name}-private-link"
    is_manual_connection           = "false"
    private_connection_resource_id = azurerm_eventhub_namespace.eventhub_namespace.id
    subresource_names              = ["namespace"]
  }
}

resource "azurerm_private_dns_zone" "eventhub_private_dns_zone" {
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = var.resource_group.name
}

resource "azurerm_private_dns_a_record" "eventhub_private_endpoint_a_record" {
  name                = azurerm_eventhub_namespace.eventhub_namespace.name
  zone_name           = azurerm_private_dns_zone.eventhub_private_dns_zone.name
  resource_group_name = var.resource_group.name
  ttl                 = 10
  records             = [azurerm_private_endpoint.eventhub_private_endpoint.private_service_connection.0.private_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "eventhub_private_dns_zone_vnet_link" {
  name                  = "${azurerm_eventhub.eventhub.name}-vnet-link"
  resource_group_name   = var.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.eventhub_private_dns_zone.name
  virtual_network_id    = var.vnet.id
  registration_enabled  = false
}