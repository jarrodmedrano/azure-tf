terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.113.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  subscription_id = var.subscription_id
  tenant_id = var.tenant_id
  client_id = var.client_id
  client_secret = var.client_secret
  features {

  }
}

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


output "public_ip_address" {
  value = azurerm_public_ip.appip.ip_address
}
