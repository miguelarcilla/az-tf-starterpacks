##############################################################################
# Outputs File
#
# Expose the outputs you want your users to see after a successful 
# `terraform apply` or `terraform output` command. You can add your own text 
# and include any data from the state file. Outputs are sorted alphabetically;
# use an underscore _ to move things to the bottom. 

output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "acr_uri" {
  value = azurerm_container_registry.acr.login_server
}

output "keyvault_uri" {
  value = azurerm_key_vault.keyvault.vault_uri
}

output "aks_node_resource_group" {
  value = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "appgw_public_ip_address" {
  value = azurerm_public_ip.appgw_ip.ip_address
}

output "appgw_public_ip_fqdn" {
  value = azurerm_public_ip.appgw_ip.fqdn
}