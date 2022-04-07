variable "resource_group" {
  description = "The resource group where resources will be created."
}

variable "location" {
  description = "The region where resources will be created."
}

variable "solution_prefix" {
  description = "Solution prefix which will be used to generate resource names"
}

variable "solution_suffix" {
  description = "Solution suffix which will be used to generate resource names"
}

variable "vnet" {
  description = "The provisioned Virtual Network resource."
}

variable "bastion_subnet" {
  description = "The Azure Bastion subnet in the vnet."
}