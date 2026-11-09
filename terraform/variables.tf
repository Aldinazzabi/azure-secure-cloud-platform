variable "location" {
  description = "Azure region for the project resource group"
  type        = string
  default     = "westeurope"
}
variable "resource_location" {
  description = "Azure region for deployed infrastructure resources"
  type        = string
  default     = "belgiumcentral"
}

variable "resource_group_name" {
  description = "Resource group used by this portfolio project"
  type        = string
  default     = "rg-azure-platform-dev"
}
variable "vnet_name" {
  description = "Project virtual network"
  type        = string
  default     = "vnet-azure-platform-dev"
}
variable "vnet_address_space" {
  description = "VNet address space"
  type        = list(string)
  default     = ["10.10.0.0/16"]
}
variable "vm_subnet_name" {
  description = "Subnet for Linux workload"
  type        = string
  default     = "snet-workload"
}
variable "vm_subnet_prefix" {
  description = "Subnet address range"
  type        = list(string)
  default     = ["10.10.1.0/24"]
}
variable "admin_username" {
  description = "Linux administrator username"
  type        = string
  default     = "azureadmin"
}
variable "ssh_allowed_source_cidr" {
  description = "Your public IPv4 address followed by /32"
  type        = string
  sensitive   = true
}
variable "vm_size" {
  description = "Small learning VM SKU; verify availability and price"
  type        = string
  default     = "Standard_D2as_v4"
}
variable "vm_name" {
  description = "Linux VM name"
  type        = string
  default     = "vm-linux-dev-01"
}
variable "admin_ssh_public_key" {
  description = "Contents of the SSH public key"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags used to identify project resources"
  type        = map(string)
  default = {
    project     = "azure-secure-cloud-platform"
    environment = "dev"
    managed_by  = "terraform"
  }
}
variable "postgres_admin_password" {
  description = "Administrator password for PostgreSQL"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.postgres_admin_password) >= 12
    error_message = "The PostgreSQL password must contain at least 12 characters."
  }
}