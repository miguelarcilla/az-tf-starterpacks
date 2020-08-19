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

variable "bastion_subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "192.168.0.0/27"
}

variable "gateway_subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "192.168.0.32/28"
}

variable "public_subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "192.168.0.48/28"
}

variable "app_subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "192.168.0.64/28"
}

variable "database_subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "192.168.0.80/28"
}

variable "diag_storage_prefix" {
  description = "The storage account prefix for diagnostics collection."
  default     = "demodiag"
}

variable "admin_username" {
  description = "Administrator user name."
  default     = "adminuser"
}

variable "admin_password" {
  description = "Administrator password for new VMs."
  default     = "null"
}

variable "bastion_name" {
  description = "The name and prefix for Azure Bastion resources."
  default     = "demo-bastion"
}

variable "app_name" {
  description = "The name and prefix for public application resources."
  default     = "demo-app"
}

variable "db_name" {
  description = "The name and prefix for application database resource."
  default     = "demo-db"
}

variable "db_admin_username" {
  description = "Database Administrator user name."
  default     = "adminuser"
}

variable "db_admin_password" {
  description = "Database Administrator password for new DBs."
  default     = "null"
}