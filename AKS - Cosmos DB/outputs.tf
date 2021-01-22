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

output "identity_resource_id" {
    value = azurerm_user_assigned_identity.aks_mi.id
}

output "identity_client_id" {
    value = azurerm_user_assigned_identity.aks_mi.client_id
}
