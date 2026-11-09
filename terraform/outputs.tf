output "resource_group_name" {
  description = "Name of the project resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Azure region selected for the resource group"
  value       = azurerm_resource_group.main.location
}

output "subscription_id" {
  description = "Subscription ID used by the authenticated Azure provider"
  value       = data.azurerm_client_config.current.subscription_id
}
output "postgres_server_fqdn" {
  description = "Private PostgreSQL server hostname"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}