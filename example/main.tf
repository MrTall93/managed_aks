provider "azurerm" {
  features {}
}

locals {
    is_linux = substr(pathexpand("~"), 0, 1) == "/"
    module_path = abspath(path.module)
    telemetry_tags = {
    "azservicehubProduct" = "BK8s",
    "azservicehubProductVersion" = "0.1",
    "enviroment" = "DEV"
    }  
    tags = merge(local.telemetry_tags)
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "shared_cluster_resource_group" {
  name = "bk8s_uksouth_dev"
  location = "uksouth"
}


########################################################################
###                       Network
########################################################################


resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-az001"
  location            = azurerm_resource_group.shared_cluster_resource_group.location
  resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
  address_space       = ["10.42.0.0/16"]
#   dns_servers         = ["10.20.0.4"]
  tags = local.tags
}

resource "azurerm_subnet" "fw-subnet" {
  resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
  address_prefixes = ["10.42.2.0/24"]
  name               = "AzureFirewallSubnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
}

resource "azurerm_subnet" "aks-subnet" {
  resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
  address_prefixes = ["10.42.1.0/24"]
  name               = "aks-subnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  
}

resource "azurerm_public_ip" "fwpub-ip" {
  name                = "fwaksPublicIp"
  resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
  location            = azurerm_resource_group.shared_cluster_resource_group.location
  allocation_method   = "Static"
  sku = "Standard"

  tags = local.tags
}

resource "azurerm_firewall" "aks_firwall" {
  name                = "aksfirewall"
  location            = azurerm_resource_group.shared_cluster_resource_group.location
  resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  dns_proxy_enabled = true

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.fw-subnet.id
    public_ip_address_id = azurerm_public_ip.fwpub-ip.id
  }
}

resource "azurerm_route_table" "aks_routetable" {
    name = "aksroutetable"
    location                      = azurerm_resource_group.shared_cluster_resource_group.location
    resource_group_name           = azurerm_resource_group.shared_cluster_resource_group.name
    disable_bgp_route_propagation = false

    route {
        name           = "privateroute"
        address_prefix = "0.0.0.0/0"
        next_hop_type  = "VirtualAppliance"
        next_hop_in_ip_address = azurerm_firewall.aks_firwall.ip_configuration[0].private_ip_address
    }

  tags = local.tags
}

resource "azurerm_route" "aks_routetable_pub" {
    name = "publicroute"
    route_table_name = azurerm_route_table.aks_routetable.name
    next_hop_type = "Internet"
    address_prefix = "${azurerm_public_ip.fwpub-ip.ip_address}/32"
    resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
}

resource "azurerm_subnet_route_table_association" "name" {
  subnet_id      = azurerm_subnet.aks-subnet.id
  route_table_id = azurerm_route_table.aks_routetable.id
}

resource "azurerm_firewall_network_rule_collection" "aksfwnr" {
    name = "aksfwnr"
    azure_firewall_name = azurerm_firewall.aks_firwall.name
    resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
    priority            = 100
    action              = "Allow"
    rule {
        name = "apiudp"
        source_addresses = ["*"]
        destination_ports = ["1194"]
        destination_addresses = ["AzureCloud.uksouth"]
        protocols = ["UDP"]      
    }
    rule {
        name = "apitcp"
        source_addresses = ["*"]
        destination_ports = ["9000"]
        destination_addresses = ["AzureCloud.uksouth"]
        protocols = ["TCP"]      
    }
    rule {
        name = "time"
        source_addresses = ["*"]
        destination_ports = ["123"]
        destination_fqdns = ["ntp.ubuntu.com"]
        protocols = ["UDP"]      
    }
    rule {
        name = "ghcr"
        source_addresses = ["*"]
        destination_ports = ["443"]
        destination_fqdns = ["ghcr.io","pkg-containers.githubusercontent.com"]
        protocols = ["TCP"]      
    }
    rule {
        name = "docker"
        source_addresses = ["*"]
        destination_ports = ["443"]
        destination_fqdns = ["docker.io","registry-1.docker.io","production.cloudflare.docker.com"]
        protocols = ["TCP"]      
    }
}

resource "azurerm_firewall_application_rule_collection" "aksfwar" {
    name = "aksfwar"
    azure_firewall_name = azurerm_firewall.aks_firwall.name
    resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
    priority            = 100
    action              = "Allow"
    rule {
        name = "fqdn"
        protocol {
            port = "443"
            type = "Https"
            } 
        protocol {
            port = "80"
            type = "Http"
            } 
        source_addresses = ["*"]
        target_fqdns = ["AzureCloud.uksouth"]

    }
}


# ########################################################################
# ############                         CMK Key Vault
# ########################################################################

resource "azurerm_key_vault" "cmk_keyvault" {
  name                = "bk8s-CMK-Keyvault-2"
  location            = azurerm_resource_group.shared_cluster_resource_group.location
  resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"
  soft_delete_retention_days = 90
  purge_protection_enabled   = true
  enable_rbac_authorization =  true
  enabled_for_disk_encryption =  true
  public_network_access_enabled = true


  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = local.tags
}


resource "azurerm_role_assignment" "access_policy" {
    principal_id = data.azurerm_client_config.current.object_id
    scope = azurerm_key_vault.cmk_keyvault.id
    role_definition_name = "Key Vault Administrator"
}

resource "azurerm_key_vault_key" "cmk" {
  depends_on = [ azurerm_role_assignment.access_policy ]
  name         = "bk8s-cmk"
  key_vault_id = azurerm_key_vault.cmk_keyvault.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["encrypt", "decrypt", "sign", "verify", "wrapKey", "unwrapKey"]

  tags = local.tags
}


# resource "azurerm_private_dns_zone" "privateDNS" {
#   name                = "dev6-privateDNS"
#   resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
# }


# resource "azurerm_route_table" "route_table" {
#   name                = "bk8s-route-table"
#   resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
#   location            = azurerm_resource_group.shared_cluster_resource_group.location
#   route {
#     name           = "route1"
#     address_prefix = "0.0.0.0/0"
#     next_hop_type  = "VirtualAppliance"
#     next_hop_in_ip_address = "10.20.0.4"
#   }
# }


# # resource "azurerm_subnet_route_table_association" "route_table_association" {
# #   subnet_id      = azurerm_subnet.user-0001.id
# #   route_table_id = azurerm_route_table.route_table.id  # Specify the ID of your route table
# # }

resource "azurerm_user_assigned_identity" "control_plane_uami" {
  name = "bk8s_uami"
  location = "uksouth"
  resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
}

resource "azurerm_disk_encryption_set" "des" {
  name                = "bk8s-des"
  location            = azurerm_resource_group.shared_cluster_resource_group.location
  resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
  key_vault_key_id    = azurerm_key_vault_key.cmk.id
  encryption_type     = "EncryptionAtRestWithPlatformAndCustomerKeys"
  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane_uami.id]
  }
}

resource "azurerm_role_assignment" "control_plane_uami_access" {
  scope                = azurerm_key_vault.cmk_keyvault.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.control_plane_uami.principal_id
}

module "barclays_cluster" {
  source = "./.."
  cluster_name_suffix = "bk8s"
  node_subnet_id = azurerm_subnet.aks-subnet.id
  location = azurerm_resource_group.shared_cluster_resource_group.location
  resource_group_name = azurerm_resource_group.shared_cluster_resource_group.name
  control_plane_uami = ["${azurerm_user_assigned_identity.control_plane_uami.id}"]
  cluster_ssh_public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
  central_loganaltics_workspace_id = "/subscriptions/07ee7055-7a0c-4503-9d3b-31ff18f8e443/resourceGroups/dev6-log-rg-uks-01/providers/Microsoft.OperationalInsights/workspaces/dev6-log-law-uks-01"
  disk_encyryption_id = azurerm_disk_encryption_set.des.id
}
