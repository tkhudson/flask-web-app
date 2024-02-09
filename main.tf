### Dev/Designer: Tyler Hudson

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.91.0"
    }
  }
}

provider "azurerm" {
  features {}
}


variable "rg-name" {
    type = string
  default = "flaskwebwapp-rg"
}

variable "location" {
    type = string
  default = "East US"
}

variable "vnet-name" {
    type = string
  default = "flaskwebapp-vnet"
}

variable "sg-name" {
    type = string
  default = "flaskwebapp-sg"
}

variable "host_os" {
    type = string
    default = "windows"
}

resource "azurerm_resource_group" "rg-name" {
  name = var.rg-name
  location = var.location
}

resource "azurerm_virtual_network" "flaskwebwapp-vnet" {
  name                = var.vnet-name
  resource_group_name = var.rg-name
  location      = var.location
  address_space = ["10.123.0.0/16"]

  tags = {
    environment = "dev"
  }
}

# creating a subnet
resource "azurerm_subnet" "flaskwebapp-subnet-1" {
  name                 = "flaskwebapp-subnet-1"
  resource_group_name = var.rg-name
  virtual_network_name = var.vnet-name

  address_prefixes = ["10.123.1.0/24"]

}

# creating security group
resource "azurerm_network_security_group" "flaskwebapp-sg" {
  name                = var.sg-name
  location            = var.location
  resource_group_name = var.rg-name

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
  destination_port_range = "*"
  source_address_prefix  = "10.192.1.150"
  # changed from "*" (public) to my own public ip addresses to allow private access
  destination_address_prefix  = "*"
  resource_group_name         = var.rg-name
  network_security_group_name = var.sg-name
}

# created association with subnet and security group. This allows the security group (with the rule) to protect our subnet
resource "azurerm_subnet_network_security_group_association" "subnetassociation" {
  subnet_id                 = azurerm_subnet.flaskwebapp-subnet-1.id
  network_security_group_id = azurerm_network_security_group.flaskwebapp-sg.id
}

# creating a public ip for future virtual machine. This will allow it to connect to the internet 
resource "azurerm_public_ip" "flaskwebapp-ip" {
  name                = "flaskwebapp-ip"
  resource_group_name = var.rg-name
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
  resource_group_name = var.rg-name

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
  resource_group_name   = var.rg-name
  location              = var.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.flaskwebapp-vm-nic.id]

  custom_data = filebase64("customdata.tpl")
  # ^ this is added after creating the customdata.tpl file in the step after creating the linux VM.
  # this line and file does update your linux vm. Don't worry if the terraform plan says 1 to destroy (it is supposed to)

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/flaskazkey.pub")
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

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityfile = "~/.ssh/flaskazkey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }

  tags = {
    environment = "dev"
  }
}

# After the azure linux vm resource, we need to create an ssh key pair.
# Within the terminal, enter "ssh-keygen -t rsa" and generate. 
# To confirm, type "ls ~/.ssh" and find the key you just made.
# Since we created a public ip for our VM we can now ssh into it with our key.
# Copy the public ip address of your vm
#      - if you don't know where to find it, just type "terraform state list"
#      - then find your VM, copy it. Then run the command "terraform state show <your vm name>". You can find the public IP there.

# We are now going to connect to the VM through SSH.
# To do so, run the command "ssh -i ~/.ssh/<name of key> <adminusername>@<public ip of vm>"
# Congrats! You are now in your VM!!! You can close it after this step with "exit" in the terminal.data

# Next step is adding the customdata template file and introducing filebase64 to the VM.
# After adding the script, apply the settings through terraform and connect to your VM. Check to see if docker is installed with "docker --version"

# Next step is adding the operating systems ssh script. Mine is "windows-ssh-script.tpl"
#    - if wanting to introduce the ability to choose OS, then add the linux ssh script as well

# Now we need to add a provisioner

#  name = azurerm_public_ip.expedition-ip.name
#  resource_group_name = azurerm_resource_group.Expedition-rg.name 
#}

# creating a new data resource to collect the public ip 
# query the ip address we created to get its ip address. This will allow us to not have to dig through terraform state to get the ip.

#output "public_ip_address" {
#  value = "${azurerm_linux_virtual_machine.exp-vm.name}: ${data.azurerm_public_ip.exp-ip-data.ip_address}"
#}

# After completing the output function, you can now enter the command "terraform output" and it will pull the data from your ip-data file

# Next step is adding the ability to choose between Linux and Windows OS
# Create the variables.tf file and you give the option to choose. 
#   - you can also give a default os by including it there or in a .tfvars file (more sensitive)
#   - you can also change the os with this code by running "terraform console -var="host_os=linux"" in the terminal. Then see that by running "var.host_os"

# Last step within this project is using conditionals. Utilize conditional expressions to choose the interpreter we need dynamically based on definition of the host_os variable.
# change the interpreter line within the provisioner function to "var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]"



