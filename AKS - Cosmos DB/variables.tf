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
  description = "The name of the Azure Resource Group."
  default     = "demo-rg"
}

variable "virtual_network_name" {
  description = "The name of the virtual network."
  default     = "demo-vnet"
}

variable "acr_name" {
  description = "The name of the Azure Container Registry."
  default     = "demoacr"
}

variable "cluster_name" {
  description = "The name of the AKS Cluster."
  default     = "demo-aks-cluster"
}

variable "kubernetes_dns_prefix" {
  description = "The DNS prefix to apply to Kubernetes nodes."
  default     = "demoDNS"
}