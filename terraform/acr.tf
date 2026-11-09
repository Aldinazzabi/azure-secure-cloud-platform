resource "azurerm_container_registry" "acr" {
  name                = "acrazureplatformdev" # Must be globally unique, no hyphens
  resource_group_name = azurerm_resource_group.main.name
  location            = var.resource_location
  sku                 = "Basic"
  admin_enabled       = false

  tags = var.tags
}