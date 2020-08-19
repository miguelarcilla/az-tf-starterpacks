##############################################################################
# Outputs File
#
# Expose the outputs you want your users to see after a successful 
# `terraform apply` or `terraform output` command. You can add your own text 
# and include any data from the state file. Outputs are sorted alphabetically;
# use an underscore _ to move things to the bottom. 

output "_instructions" {
  value = "This output contains plain text. You can add variables too."
}

output "private_link_endpoint_ip" {
  value = azurerm_private_endpoint.db_private_endpoint.private_service_connection.0.private_ip_address
}

# output "public_dns" {
#   value = azurerm_public_ip.tf-guide-pip.fqdn
# }

# output "App_Server_URL" {
#   value = "http://${azurerm_public_ip.tf-guide-pip.fqdn}"
# }

