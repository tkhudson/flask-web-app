### Dev/Designer: Tyler Hudson

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.91.0"
    }
  }
}

provider "azurerm" {
  features {}
}


variable "rg-name" {
  type    = string
  default = "flaskwebapp-rg"
}

variable "location" {
  type    = string
  default = "East US"
}

variable "vnet-name" {
  type    = string
  default = "flaskwebapp-vnet"
}

variable "sg-name" {
  type    = string
  default = "flaskwebapp-sg"
}

variable "host_os" {
  type    = string
  default = "windows"
}

resource "azurerm_resource_group" "rg-name" {
  name     = "flaskwebapp-rg"
  location = var.location
}

resource "azurerm_virtual_network" "flaskwebapp-vnet" {
  name                = "flaskwebapp-vnet"
  resource_group_name = azurerm_resource_group.rg-name.name
  location            = var.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "dev"
  }
}

# creating a subnet
resource "azurerm_subnet" "flaskwebapp-subnet-1" {
  name                 = "flaskwebapp-subnet-1"
  resource_group_name  = azurerm_resource_group.rg-name.name
  virtual_network_name = azurerm_virtual_network.flaskwebapp-vnet.name

  address_prefixes = ["10.123.1.0/24"]

}

# creating security group
resource "azurerm_network_security_group" "flaskwebapp-sg" {
  name                = "flaskwebapp-sg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-name.name

  tags = {
    environment = "dev"
  }

}

#creating security rule
resource "azurerm_network_security_rule" "flaskwebapp-dev-rule" {
  name      = "flaskwebapp-dev-rule"
  priority  = 100
  direction = "Inbound"
  access    = "Allow"
  protocol  = "*"
  # changed protocol from TCP to * to allow for ICMP or anything else
  source_port_range      = "*"
  destination_port_range = "22"
  source_address_prefix  = "*"
  ### ^^ changed to *, was running into ssh/ip issues, want to deploy then change in azure portal to my ip for security
  ### will need to use "chmod 600 id_rsa" to change the 
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg-name.name
  network_security_group_name = azurerm_network_security_group.flaskwebapp-sg.name
}

# created association with subnet and security group. This allows the security group (with the rule) to protect our subnet
resource "azurerm_subnet_network_security_group_association" "subnetassociation" {
  subnet_id                 = azurerm_subnet.flaskwebapp-subnet-1.id
  network_security_group_id = azurerm_network_security_group.flaskwebapp-sg.id
}

# creating a public ip for future virtual machine. This will allow it to connect to the internet 
resource "azurerm_public_ip" "flaskwebapp-ip" {
  name                = "flaskwebapp-ip"
  resource_group_name = azurerm_resource_group.rg-name.name
  location            = var.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

# creating a NIC for the future VM
resource "azurerm_network_interface" "flaskwebapp-vm-nic" {
  name                = "flaskwebapp-vm-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-name.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.flaskwebapp-subnet-1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.flaskwebapp-ip.id
  }

  tags = {
    environment = "dev"
  }
}

# Create a new Linux VM for the group
resource "azurerm_linux_virtual_machine" "flaskwebapp-vm" {
  name                  = "flaskwebapp-vm"
  resource_group_name   = azurerm_resource_group.rg-name.name
  location              = var.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.flaskwebapp-vm-nic.id]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}