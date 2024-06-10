terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "RSG" {
  name     = "rsg"
  location = "southeastasia"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "VN" {
  name                = "vn"
  location            = azurerm_resource_group.RSG.location
  resource_group_name = azurerm_resource_group.RSG.name
  address_space       = ["10.123.0.0/16"]
  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet" "SN" {
  name                 = "sn"
  resource_group_name  = azurerm_resource_group.RSG.name
  virtual_network_name = azurerm_virtual_network.VN.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "NSG" {
  name                = "nsg"
  location            = azurerm_resource_group.RSG.location
  resource_group_name = azurerm_resource_group.RSG.name
  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "S_RULE" {
  name                        = "s_rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "118.189.40.39/32"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.RSG.name
  network_security_group_name = azurerm_network_security_group.NSG.name
}

resource "azurerm_subnet_network_security_group_association" "SNSA" {
  subnet_id                 = azurerm_subnet.SN.id
  network_security_group_id = azurerm_network_security_group.NSG.id
}

resource "azurerm_public_ip" "IP" {
  name                = "ip"
  resource_group_name = azurerm_resource_group.RSG.name
  location            = azurerm_resource_group.RSG.location
  allocation_method   = "Dynamic"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "NIC" {
  name                = "nic"
  location            = azurerm_resource_group.RSG.location
  resource_group_name = azurerm_resource_group.RSG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SN.id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = azurerm_public_ip.IP.id
  }
  enable_accelerated_networking = true  # Enable Accelerated Networking

  tags = {
    environment = "dev"
  }
}

resource "azurerm_linux_virtual_machine" "VM" {
  name                  = "vm"
  resource_group_name   = azurerm_resource_group.RSG.name
  location              = azurerm_resource_group.RSG.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.NIC.id]

  custom_data = filebase64("customdata.tpl")
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/mtcazurekey.pub")
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

resource "azurerm_subnet" "BSN"{
  name = "bsn"
  resource_group_name = azurerm_resource_group.RSG.name
  virtual_network_name = azurerm_virtual_network.VN.name
  address_prefixes = ["10.0.101.0/27"]
} 

resource "azurerm_public_ip" "BIP"{
  name = "${local.resource_name_prefix}-bip"
  resource_group_name = azurerm_resource_group.RSG.name
  location = azurerm_resource_group.RSG.location
  allocation_method = "Static"
  sku = "Standard"
}

resource "azurerm_bastion_host" "BH"{
  name = "${local.resource_name_prefix}-bh"
  resource_group_name = azurerm_resource_group.RSG.name
  location = azurerm_resource_group.RSG.location

  ip_configuration{
    name = "configuration"
    subnet_id = azurerm_subnet.BSN.id
    public_ip_address_id = azurerm_public_ip.BIP.id
  } 
}

