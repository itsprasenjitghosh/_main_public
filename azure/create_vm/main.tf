# 1. Define required providers and versions
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# 2. Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# 3. Create a Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "pg-nginx"
  location = "East US"
}

# 4. Create a Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-india"
  address_space       = ["10.0.0.0/24"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# 5. Create a Subnet within the Virtual Network
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-nginx"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/29"]
}

# 6. Create a Public IP Address (Optional, for SSH access)
resource "azurerm_public_ip" "public_ip" {
  name                = "nginx-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 7. Create a Network Interface Card (NIC)
resource "azurerm_network_interface" "nic" {
  name                = "nic-vm-nginx"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# 8. Create the Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "nginx-vm-linux"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2ls_v7"
  admin_username      = "auser"

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  # Configuration for password authentication (Alternative to SSH keys)
  admin_password                  = "Admin@123456789"
  disable_password_authentication = false

  # OS Disk settings
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Reference an official Marketplace image (Ubuntu 24.04 LTS)
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

# Create a Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-nginx"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 9. Output the public IP address after deployment
output "public_ip" {
  value       = azurerm_public_ip.public_ip.ip_address
  description = "The public IP address of the deployed virtual machine."
}
