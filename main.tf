locals {
  resource_group_name = "app-grp"
  location = "East US"

  virtual_network = {
    name = "app-network"
    address_space = "10.0.0.0/16"
  }

  subnets = [
    {
      name = "subnetA"
      address_prefix = "10.0.0.0/24"
    },
    {
      name = "subnetB"
      address_prefix = "10.0.1.0/24"
    }
  ]
}

resource "azurerm_resource_group" "appgrp" {
  name     = local.resource_group_name
  location = local.location
}

resource "azurerm_storage_account" "mystuff" {
  name                     = "mystuff3000"
  resource_group_name      = local.resource_group_name
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind            = "StorageV2"

  depends_on = [ azurerm_resource_group.appgrp ]
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.mystuff.name
  container_access_type = "blob"

  depends_on = [ azurerm_storage_account.mystuff ]
}

resource "azurerm_storage_blob" "maintf" {
  name                   = "dog.jpg"
  storage_account_name   = azurerm_storage_account.mystuff.name
  storage_container_name = azurerm_storage_container.data.name
  type                   = "Block"
  source                 = "dog.jpg"

  depends_on = [ azurerm_storage_container.data ]
}

resource "azurerm_subnet" "subnetA" {
  name                 = local.subnets[0].name
  resource_group_name  = local.resource_group_name
  virtual_network_name = local.virtual_network.name
  address_prefixes     = [local.subnets[0].address_prefix]

  depends_on = [ azurerm_virtual_network.appnetwork ]
}

resource "azurerm_subnet" "subnetB" {
  name                 = local.subnets[1].name
  resource_group_name  = local.resource_group_name
  virtual_network_name = local.virtual_network.name
  address_prefixes     = [local.subnets[1].address_prefix]

  depends_on = [ azurerm_virtual_network.appnetwork ]
}

resource "azurerm_virtual_network" "appnetwork" {
  name                = local.virtual_network.name
  location            = local.location
  resource_group_name = local.resource_group_name
  address_space       = [local.virtual_network.address_space]

  depends_on = [ azurerm_resource_group.appgrp ]
}

resource "azurerm_public_ip" "appip" {
  name                = "app-ip"
  resource_group_name = local.resource_group_name
  location            = local.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "appinterface" {
  name                = "appinterface"
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnetA.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    azurerm_virtual_network.appnetwork
  ]
}

resource "azurerm_network_security_group" "appnsg" {
  name                = "app-nsg"
  location            = local.location
  resource_group_name = local.resource_group_name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [ azurerm_resource_group.appgrp ]
}

resource "azurerm_subnet_network_security_group_association" "appnsglink" {
  subnet_id                 = azurerm_subnet.subnetA.id
  network_security_group_id = azurerm_network_security_group.appnsg.id
}

resource "azurerm_linux_virtual_machine" "linuxvm" {
  name                = "linuxvm"
  resource_group_name = local.resource_group_name
  location            = local.location
  size                = "Standard_D2s_v3"
  admin_username      = var.admin_username
  # admin_password      = var.admin_password
  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.linuxkey.public_key_openssh
  }
  network_interface_ids = [
    azurerm_network_interface.appinterface.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  depends_on = [ azurerm_network_interface.appinterface, azurerm_resource_group.appgrp, tls_private_key.linuxkey ]
}

resource "tls_private_key" "linuxkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "linuxkey" {
  content  = tls_private_key.linuxkey.private_key_pem
  filename = "linuxkey.pem"
  depends_on = [ tls_private_key.linuxkey ]
}

# resource "azurerm_managed_disk" "appdisk" {
#   name                 = "appdisk"
#   location             = local.location
#   resource_group_name  = local.resource_group_name
#   storage_account_type = "Standard_LRS"
#   create_option        = "Empty"
#   disk_size_gb         = "1"

#   tags = {
#     environment = "staging"
#   }
# }

# resource "azurerm_virtual_machine_data_disk_attachment" "appdiskattach" {
#   managed_disk_id    = azurerm_managed_disk.appdisk.id
#   virtual_machine_id = azurerm_windows_virtual_machine.linuxvm.id
#   lun                = "10"
#   caching            = "ReadWrite"
# }


output "public_ip_address" {
  value = azurerm_public_ip.appip.ip_address
}
