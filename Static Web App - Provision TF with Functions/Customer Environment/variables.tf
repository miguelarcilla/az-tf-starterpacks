##############################################################################
# Variables File
# 
# Here is where we store the default values for all the variables used in our
# Terraform code. If you create a variable with no default, the user will be
# prompted to enter it (or define it via config file or command line flags.)
 
variable "subscription_id" {
  description = "The ID of your Azure Subscripion."
  default     = "null"
}

variable "location" {
  description = "The default region where the virtual network and app resources are created."
  default     = "southeastasia"
}

variable "remote_state_resource_group_name" {
  description = "The name of the TF remote state resource group."
  default     = "remote-rg"
}

variable "remote_state_storage_account_name" {
  description = "The name of the TF remote state storage account."
  default     = "remotestorage"
}

variable "remote_state_container_name" {
  description = "The name of the TF remote state container."
  default     = "remote-container"
}

variable "remote_state_key" {
  description = "The name of the TF remote state file."
  default     = "remote-key"
}

variable "solution_prefix" {
  description = "The name of the Azure Resource Group."
  default     = "demo"
}

variable "solution_prefix_dashed" {
  description = "The name of the Azure Resource Group with a dash."
  default     = "demo"
}

variable "virtual_network_name" {
  description = "The name for your virtual network."
  default     = "demo-vnet"
}

variable "virtual_network_address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space. Changing this forces a new resource to be created."
  default     = ["192.168.0.0/24"]
}

variable "win_vm_name" {
  description = "The name and prefix for Windows VM related resources."
  default     = "demo-win-vm"
}

variable "win_vm_size" {
  description = "The size SKU of the Windows VM."
  default     = "Standard_D2as_v4"
}