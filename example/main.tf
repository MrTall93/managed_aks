provider "azurerm" {
  features {}
}

locals {
    is_linux = substr(pathexpand("~"), 0, 1) == "/"
    module_path = abspath(path.module)
    telemetry_tags = {
    TELEMETRY_TAG_KEY = "TELEMETRY_TAG_VALUES"
    }
    tags = merge(local.telemetry_tags)
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "shared_cluster_resource_group" {
  name = "bk8s_dev"
  location = "uksouth"
}

resource "azurerm_virtual_network" "bk8s_vnet" {
  resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
  name = "aks_vnet_0001"
  location = azurerm_resource_group.shared_cluster_resource_group.location
  address_space = ["10.2.0.0/22"]
}

resource "azurerm_subnet" "bk8s_subnet" {
  name                 = "cluster_subnet"
  resource_group_name  = azurerm_resource_group.shared_cluster_resource_group.name
  virtual_network_name = azurerm_virtual_network.bk8s_vnet.name
  address_prefixes     = ["10.2.1.0/24"] 
}

resource "azurerm_route_table" "route_table" {
  name                = "bk8s-route-table"
  resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
  location            = azurerm_resource_group.shared_cluster_resource_group.location
}

resource "azurerm_subnet_route_table_association" "route_table_association" {
  subnet_id      = azurerm_subnet.bk8s_subnet.id
  route_table_id = azurerm_route_table.route_table.id  # Specify the ID of your route table
}

resource "azurerm_user_assigned_identity" "control_plane_uami" {
  name = "bk8s_uami"
  location = "uksouth"
  resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
}


module "barclays_cluster" {
  source = "./.."
  cluster_name_suffix = "bk8s"
  node_subnet_id = azurerm_subnet.bk8s_subnet.id
  location = azurerm_resource_group.shared_cluster_resource_group.location
  resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
  control_plane_uami = ["${azurerm_user_assigned_identity.control_plane_uami.id}"]
  cluster_ssh_public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
}
