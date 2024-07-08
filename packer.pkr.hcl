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