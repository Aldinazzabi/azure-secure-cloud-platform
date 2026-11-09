# --------------------------------------------------
# PostgreSQL delegated subnet
# --------------------------------------------------
resource "azurerm_subnet" "postgres" {
  name                 = "snet-postgres"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.3.0/28"]

  delegation {
    name = "postgresql-flexible-server"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# --------------------------------------------------
# Private DNS zone
# --------------------------------------------------
resource "azurerm_private_dns_zone" "postgres" {
  name                = "azure-platform-dev.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "link-postgres-vnet"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

# --------------------------------------------------
# Generate a unique PostgreSQL server name
# --------------------------------------------------
resource "random_string" "postgres_suffix" {
  length  = 6
  upper   = false
  lower   = true
  numeric = true
  special = false
}

# --------------------------------------------------
# PostgreSQL Flexible Server
# --------------------------------------------------
resource "azurerm_postgresql_flexible_server" "main" {
  name                = "psql-asp-${random_string.postgres_suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.resource_location

  version = "16"

  administrator_login    = "pgadminuser"
  administrator_password = var.postgres_admin_password

  sku_name   = "GP_Standard_D2ds_v5"
  storage_mb = 32768

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  delegated_subnet_id = azurerm_subnet.postgres.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  public_network_access_enabled = false

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres
  ]

  tags = var.tags
}

# --------------------------------------------------
# Application database
# --------------------------------------------------
resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "appdb"
  server_id = azurerm_postgresql_flexible_server.main.id
}