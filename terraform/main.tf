terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
provider "azurerm" {
  features {}
}
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}
data "azurerm_client_config" "current" {}
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  address_space       = var.vnet_address_space
  location            = var.resource_location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}
resource "azurerm_subnet" "workload" {
  name                 = var.vm_subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.vm_subnet_prefix
}
resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.2.0/24"]
}
resource "azurerm_network_security_group" "workload" {
  name                = "nsg-workload-dev"
  location            = var.resource_location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
  security_rule {
    name                       = "Allow-SSH-From-My-IP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_allowed_source_cidr
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}
output "vnet_name" {
  value = azurerm_virtual_network.main.name
}
output "vnet_address_space" {
  value = azurerm_virtual_network.main.address_space
}
output "subnet_name" {
  value = azurerm_subnet.workload.name
}
output "subnet_id" {
  value = azurerm_subnet.workload.id
}
output "nsg_name" {
  value = azurerm_network_security_group.workload.name
}
resource "azurerm_public_ip" "vm" {
  name                = "pip-linux-dev-01"
  location            = var.resource_location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}
resource "azurerm_network_interface" "vm" {
  name                = "nic-linux-dev-01"
  location            = var.resource_location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}
resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.resource_location
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.vm.id
  ]
  disable_password_authentication = true
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }
  os_disk {
    name                 = "osdisk-linux-dev-01"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  tags = var.tags
}
output "vm_name" {
  value = azurerm_linux_virtual_machine.vm.name
}
output "vm_private_ip" {
  value = azurerm_network_interface.vm.private_ip_address
}
output "vm_public_ip" {
  value = azurerm_public_ip.vm.ip_address
}
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-dev"
  location            = var.resource_location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_web_application_firewall_policy" "main" {
  name                = "waf-policy-dev"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.resource_location
  tags                = var.tags

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}
resource "azurerm_application_gateway" "main" {
  name                = "appgw-dev"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.resource_location
  tags                = var.tags

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }
  autoscale_configuration {
    min_capacity = 1
    max_capacity = 2
  }

  firewall_policy_id = azurerm_web_application_firewall_policy.main.id

  # 1. The Frontend IP
  frontend_ip_configuration {
    name                 = "appgw-public-ip"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  # 2. The Subnet
  gateway_ip_configuration {
    name      = "appgw-subnet"
    subnet_id = azurerm_subnet.appgw.id
  }

  # 3. The Frontend Port (80)
  frontend_port {
    name = "port-80"
    port = 80
  }

  # 4. The Listener
  http_listener {
    name                           = "listener-80"
    frontend_ip_configuration_name = "appgw-public-ip"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  # 5. The Backend Pool (Your VM's Private IP)
  backend_address_pool {
    name         = "vm-backend-pool"
    ip_addresses = [azurerm_network_interface.vm.private_ip_address]
  }

  # 6. HTTP Settings (How to talk to the VM)
  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  # 7. Health Probe
  probe {
    name                                      = "health-probe"
    protocol                                  = "Http"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
  }

  # 8. Routing Rule
  request_routing_rule {
    name                       = "rule-80"
    rule_type                  = "Basic"
    http_listener_name         = "listener-80"
    backend_address_pool_name  = "vm-backend-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 100
  }
}