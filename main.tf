provider "azurerm" {

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  skip_provider_registration = true
}

data "azurerm_resource_group" "rg" {
  name = "example-resources"
}

data "azurerm_virtual_network" "net" {
  name                = "example-network-2"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_subnet" "subnet" {
  name                 = "example-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.net.name
}

resource "azurerm_public_ip" "pip" {
  name                = "webserver-public-ip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic" {
  name                = "webserver"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  ip_configuration {
    primary                       = true
    name                          = "public"
    subnet_id                     = data.azurerm_subnet.subnet.id
    public_ip_address_id          = azurerm_public_ip.pip.id
    private_ip_address_allocation = "Dynamic"
  }
}

data "azurerm_image" "webserver" {
  name                = "webserver"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_virtual_machine" "webserver" {
  count               = 1
  name                = "webserver-vm"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]
  vm_size                       = "Standard_DS1_v2"
  delete_os_disk_on_termination = true

  storage_image_reference {
    id = data.azurerm_image.webserver.id
  }

  storage_os_disk {
    name              = "webserver-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "adminuser"
    admin_password = "P@ssw0rd1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

output "ip" {
  value = azurerm_public_ip.pip.ip_address
}