output "vnet" {
  value = azurerm_virtual_network.vnet
}

output "eventhub_subnet" {
  value = azurerm_subnet.eventhub_subnet
}

output "bastion_subnet" {
  value = azurerm_subnet.bastion_subnet
}

output "storage_account" {
  value = azurerm_storage_account.storage
}