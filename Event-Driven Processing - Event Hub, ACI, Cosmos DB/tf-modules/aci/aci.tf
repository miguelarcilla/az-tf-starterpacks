##############################################################################
# * Azure Container Instances
resource "azurerm_network_profile" "aci_network_profile" {
  name                = "${var.solution_prefix}-aci-network-profile"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name

  container_network_interface {
    name = "${var.solution_prefix}-aci-nic"

    ip_configuration {
      name      = "${var.solution_prefix}-aci-ipconfig"
      subnet_id = azurerm_subnet.aci_subnet.id
    }
  }
}

resource "azurerm_container_group" "aci" {
  name                = "${var.solution_prefix}-aci"
  location            = var.location
  resource_group_name = azurerm_resource_group.group.name
  ip_address_type     = "Private"
  os_type             = "Linux"
  restart_policy      = "OnFailure"
  network_profile_id  = azurerm_network_profile.aci_network_profile.id

  container {
    name   = "pyreceiver"
    image  = "${azurerm_container_registry.acr.name}.azurecr.io/receivepy:latest"
    cpu    = "1"
    memory = "1"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  image_registry_credential {
    server   = "${azurerm_container_registry.acr.name}.azurecr.io"
    username = azurerm_container_registry.acr.admin_username
    password = azurerm_container_registry.acr.admin_password
  }
}