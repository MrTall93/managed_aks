provider "azurerm" {
  features {}
}

data "azurerm_subscription" "current" {}

resource "azurerm_kubernetes_cluster" "cluster" {
  name                     = "k${var.environment}${substr(data.azurerm_subscription.current.subscription_id, 0, 4)}${var.cluster_name_suffix}"
  location	               = var.location
  resource_group_name      = var.resource_group_name

# This enables admin group to the cluster with RBAC - We create a group who will be manageing this cluster.
  azure_active_directory_role_based_access_control {
    managed = true
    # admin_group_object_ids = var.aad_admin_group_object_id
    azure_rbac_enabled = true
    tenant_id = data.azurerm_subscription.current.tenant_id
  }

#   disk_encryption_set_id = var.disk_encyryption_id
  
  
  automatic_channel_upgrade = var.cluster_upgrade_channel
  node_os_channel_upgrade = var.node_os_upgrade_channel
  
  private_cluster_enabled = true
  private_cluster_public_fqdn_enabled = true
  private_dns_zone_id = "None"

  kubernetes_version = var.kubernetes_version
  dns_prefix = "k${var.environment}${substr(data.azurerm_subscription.current.subscription_id, 0, 4)}${var.cluster_name_suffix}k8s"

  linux_profile {
    admin_username = "localadmin"
    ssh_key {
      key_data = var.cluster_ssh_public_key
    }
  }

#   microsoft_defender {
#     log_analytics_workspace_id = var.defender_loganaltics_workspace_id
#   }

  workload_identity_enabled = true
  
  identity {
    type = "UserAssigned"
    identity_ids = var.control_plane_uami
  }

  service_mesh_profile {
    mode = var.service_mesh_profile.mode
    internal_ingress_gateway_enabled = var.service_mesh_profile.internal_ingress_gateway_enabled
    external_ingress_gateway_enabled = var.service_mesh_profile.external_ingress_gateway_enabled
  }

  storage_profile {
    blob_driver_enabled = false
    disk_driver_enabled = true
    file_driver_enabled = true
    snapshot_controller_enabled = false
  }

  workload_autoscaler_profile {
    keda_enabled = true
  }

  # Uncomment the following block for oms
  # oms_agent {
  #   log_analytics_workspace_id = var.central_loganaltics_workspace_id
  # }


  # https://learn.microsoft.com/en-ie/azure/governance/policy/concepts/policy-for-kubernetes
  azure_policy_enabled = true


 # https://stackoverflow.com/questions/74809390/terraform-azure-aks-how-to-install-azure-keyvault-secrets-provider-add-on
  key_vault_secrets_provider {
    secret_rotation_enabled = true
    
  }

# https://learn.microsoft.com/en-us/azure/aks/use-oidc-issuer
  oidc_issuer_enabled = true
  
  cost_analysis_enabled = true
  
  network_profile {
    network_plugin = var.network_plugin
    network_plugin_mode = var.network_plugin_mode
    ebpf_data_plane = var.network_dataplane
    network_policy = var.network_policy
    load_balancer_sku = "standard"
    pod_cidr = var.pod_cidr
    service_cidr = var.cluster_service_cidr
    dns_service_ip = var.dns_service_ip
    outbound_type = var.outbound_type
  }

   sku_tier = var.cluster_sku

  
  default_node_pool {
    name = "sysnpl1"
    node_count = 1
    min_count = 1
    max_count = 2
    enable_auto_scaling = true
    vm_size = "Standard_D4s_v3"
    max_pods = 110
    os_disk_size_gb = 100
    os_disk_type = "Managed"
    os_sku = "AzureLinux"
    vnet_subnet_id = var.node_subnet_id
    type = "VirtualMachineScaleSets"
    only_critical_addons_enabled = true
    orchestrator_version = "1.25.6"
    zones = ["1", "2", "3"]
    custom_ca_trust_enabled = true
  }
} 
