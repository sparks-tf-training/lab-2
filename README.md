### Lab 2: Packer

In this lab, you will use Packer to create a custom image for an Azure virtual machine.

**Steps**:

1. Create a new file named `packer.pkr.hcl`.

2. Add the following configuration to the `packer.pkr.hcl` file:

```hcl
packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 1"
    }
  }
}

source "azure-arm" "webserver" {
  azure_tags = {
    dept = "Engineering"
    task = "Image deployment"
  }
  use_azure_cli_auth = true
  image_offer                       = "0001-com-ubuntu-server-jammy"
  image_publisher                   = "canonical"
  image_sku                         = "22_04-lts"
  location                          = "France Central"
  managed_image_name                = "webserver"
  managed_image_resource_group_name = "example-resources"
  os_type                           = "Linux"
  subscription_id                   = "52f807ce-4261-4df0-b2de-5e1faf190119"
  tenant_id                         = "c69c9775-e9f0-49db-b9aa-9ef3d3d04f75"
  vm_size                           = "Standard_DS2_v2"
}

build {
  sources = ["source.azure-arm.webserver"]

  provisioner "file" {
    source      = "index.html"
    destination = "~/index.html"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline          = [
      "apt-get update", 
      "apt-get upgrade -y", 
      "apt-get -y install nginx",
      "mv ~/index.html /var/www/html/index.html",
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync",
    ]
    inline_shebang  = "/bin/sh -x"
  }


}
```

3. Create a new file named `index.html` in the `vm` directory and add the following content:

```html
<!DOCTYPE html>
<html>
<head>
  <title>Welcome to nginx!</title>
</head>
<body>
  <h1>Hello, World!</h1>
</body>
</html>
```

4. Run the following command to build the image:

```sh
packer init ./packer.pkr.hcl
packer build ./packer.pkr.hcl
```

5. After the image is built, navigate to the Azure portal and verify that the image has been created.

6. Create a main.tf file in the folder of your repository and add the following configuration to deploy a virtual machine using the custom image:

```hcl
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
```

7. Run the following commands to deploy the virtual machine:

```sh
terraform init
terraform apply
```

8. After the deployment is complete, verify that the virtual machine is running and accessible via the public IP address.

9. Clean up the resources by running the following command:

```sh
terraform destroy
```