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

variable "eventhub_subnet" {
  description = "The Event Hub subnet in the vnet."
}

variable "storage_account" {
  description = "The utility Storage account to capture Event Hub logs."
}