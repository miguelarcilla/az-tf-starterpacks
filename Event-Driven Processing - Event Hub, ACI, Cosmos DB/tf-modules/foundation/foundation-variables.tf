variable "client_config" {
  description = "The Azure client details in use for this deployment."
}

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