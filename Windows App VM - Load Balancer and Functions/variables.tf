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

variable "resource_group_name" {
  description = "The name of your Azure Resource Group."
  default     = "demo-rg"
}

variable "virtual_network_name" {
  description = "The name for your virtual network."
  default     = "demo-vnet"
}

variable "virtual_network_address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space. Changing this forces a new resource to be created."
  default     = ["192.168.0.0/24"]
}

variable "app_subnet_prefix" {
  description = "The address prefix to use for the Application subnet."
  default     = "192.168.0.0/28"
}

variable "app_subnet_nsg_name" {
  description = "The name of the NSG for the Application subnet."
  default     = "app-subnet-nsg"
}

variable "management_subnet_prefix" {
  description = "The address prefix to use for the Management subnet."
  default     = "192.168.0.16/28"
}

variable "management_subnet_nsg_name" {
  description = "The name of the NSG for the Management subnet."
  default     = "management-subnet-nsg"
}

variable "admin_username" {
  description = "Administrator user name."
  default     = "adminuser"
}

variable "admin_password" {
  description = "Administrator password for new VMs."
  default     = "null"
}

variable "win_vm_name" {
  description = "The name and prefix for public application resources."
  default     = "demo-win-vm"
}

variable "app_internal_lb_name" {
  description = "The name of the internal Load Balancer for app VMs."
  default     = "demo-internal-lb"
}

variable "func_storage_name" {
  default     = "demofuncstorage"
}

variable "func_name" {
  default     = "demo-func"
}