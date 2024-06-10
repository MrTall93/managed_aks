variable "resource_group_name" {
  type = string
  description = "Resource Group Name"
}

variable "environment" {
  type = string
  default = "DEV"
}

variable "location" {
  type = string
}

variable "cluster_name_suffix" {
  description = "The cluster name suffix - will be appended at the end"
  type        = string

  validation {
    condition     = length(var.cluster_name_suffix) >= 1 && length(var.cluster_name_suffix) <= 5
    error_message = "The cluster name suffix must be between 1 and 5 characters long."
  }
}

variable "disk_encyryption_id" {
  description = "ResourceID of the disk encryption set - will be used to encrypt the os node disks"
  type        = string
  default     = ""
}

variable "node_subnet_id" {
  type = string
  description = "subnet resoure id for the default nodepool"
  default = ""
}

variable "cluster_upgrade_channel" {
  description = "The type of cluster upgrade to perform automatically For mor infomation - https://learn.microsoft.com/en-us/azure/aks/auto-upgrade-cluster?tabs=azure-cli"
  type        = string
  default = "patch"

  validation {
    condition     = contains(["patch"],var.cluster_upgrade_channel)
    error_message = "Only minor updates allowed - set this to patch only"
  }
}

variable "node_os_upgrade_channel" {
  description = "The type of node os upgrade to perform automatically For mor infomation - https://azure.microsoft.com/en-us/updates/public-preview-aks-nodeosupgrade-channel/"
  type        = string
  default = "NodeImage"

  validation {
    condition     = contains(["NodeImage"],var.node_os_upgrade_channel)
    error_message = "Only Node Image allowed - Provides a fresh weekly (default) node image (VHD) to the VM with all the up to date security patches or in a schedule & cadence of your choice if given."
  }
}

variable "cluster_pool_profile" {
  description = "Configuration for AKS node pools"
  type = list(object({
    name                 = string
    count                = number
    maxCount             = number
    minCount             = number
    enableAutoScaling    = bool
    availabilityZones    = list(string)
    enableCustomCATrust  = bool
    vmSize               = string
    osDiskSizeGB         = number
    osDiskType           = string
    vnetSubnetID         = string
    maxPods              = number
    type                 = string
    mode                 = string
    orchestratorVersion  = string
    nodeTaints           = list(string)
    osType               = string
    osSKU                = string
  }))

  default = [ 
    {
      name                 = "sysnpl1"
      count                = 1
      maxCount             = 2
      minCount             = 1
      enableAutoScaling    = true
      availabilityZones    = ["1", "2", "3"]
      enableCustomCATrust  = true
      vmSize               = "Standard_D4s_v3"
      osDiskSizeGB         = 100
      osDiskType           = "Managed"
      vnetSubnetID         = ""
      maxPods              = 110
      type                 = "VirtualMachineScaleSets"
      mode                 = "System"
      orchestratorVersion  = "1.25.6"
      nodeTaints           = ["CriticalAddonsOnly=true:NoSchedule"]
      osType               = "Linux"
      osSKU                = "AzureLinux"
    },
    {
      name                 = "usernpl1"
      count                = 1
      maxCount             = 6
      minCount             = 1
      enableAutoScaling    = true
      availabilityZones    = ["1", "2", "3"]
      enableCustomCATrust  = true
      vmSize               = ""
      osDiskSizeGB         = 0
      osDiskType           = "Managed"
      vnetSubnetID         = ""
      maxPods              = 110
      type                 = "VirtualMachineScaleSets"
      mode                 = "System"
      orchestratorVersion  = "1.25.6"
      nodeTaints           = ["CriticalAddonsOnly=true:NoSchedule"]
      osType               = "Linux"
      osSKU                = "AzureLinux"
    }
  ]
}


variable "cluster_ssh_public_key" {
  description = "The ssh public key for the AKS cluster"
  type        = string
  sensitive   = true
}


variable "cluster_sku" {
    description = "Azure Kubernetes Service (AKS) offers three pricing tiers for cluster management: the Free tier, the Standard tier, and the Premium tier."
    type = string
    default = "Standard"

    validation {
        condition     = contains(["Standard"],var.cluster_sku)
        error_message = "Use Standard tier, permium is just standard with 2 year support $$$"
    }
}

variable "cluster_service_cidr" {
  description = "This defines the IP address range from which Kubernetes assigns cluster-internal IP addresses for services, such as ClusterIPs. These IP addresses are used for internal communication between different services and are not exposed to the external network."
  type        = string
  default     = "10.3.0.0/17"
}

variable "dns_service_ip" {
  description = "This specifies the IP address of the DNS service within the cluster. It should be an IP address within the service_cidr range."
  type        = string
  default     = "10.3.0.10"
}

variable "control_plane_uami" {
  type = list(string)
  description = "The user assigned managed identity used by AKS data plane."
}

variable "aad_admin_group_object_id" {
  type = string
  description = "The Administrator Group for managing AKS cluster"
  default     = ""
}

variable "kubernetes_version" {
  type = string
  default = "1.29.4"
}

variable "network_plugin" {
    type = string
    default = "azure"
    description = "Network plugin used for building the Kubernetes network."
}

variable "network_plugin_mode" {
    type = string
    description = "Network plugin mode used for building the Kubernetes network."
    default = "overlay"
}

variable "network_policy" {
  description = "Network policy used for building the Kubernetes network."
  type        = string
  default     = "cilium"
  validation {
        condition     = contains(["azure", "calico", "cilium", "none"],var.network_policy)
        error_message = "Pick none or overlay, none if network_plugin is kubenet"
    }
}

variable "network_dataplane" {
  description = "Network dataplane used in the Kubernetes cluster onlt we need the deploy a cilium pluging"
  type        = string
  default     = "cilium"
    validation {
        condition     = contains(["azure", "cilium"],var.network_dataplane)
        error_message = "Pick none or overlay, none if network_plugin is kubenet"
    }
}

variable "pod_cidr" {
  description = "Only required when using kubenet (BASIC) networking, ignored for Azure (ADVANCED) networking"
  type = string
  default = "10.2.128.0/17"
}

variable "central_loganaltics_workspace_id" {
  type = string
  description = "log analytics workspace rescourceID for container insights"
  default = ""
}
variable "defender_loganaltics_workspace_id" {
  type = string
  description = "log analytics workspace rescourceID set up for ms defender"
  default = ""
}

variable "outbound_type" {
    type = string
    default = "userDefinedRouting"
}

# variable "keyvault_secret_provider" {
#   type = object({
#     secret_identity = string
#     secret_rotation_enabled = bool
#     secret_rotation_interval = string
#   })
#   description = "Enbales Key Vault Provider for Secret Store CSI Driver in AKS"
# }

variable "oidc_issuer_profile" {
  type = bool
  default = false
  description = "Enables the OIDC issuer in AKS"
}

variable "service_mesh_profile" {
  type = object({
    mode = string
    internal_ingress_gateway_enabled = bool
    external_ingress_gateway_enabled = bool
  })
  default = {
    mode = "Istio"
    internal_ingress_gateway_enabled = true
    external_ingress_gateway_enabled = false
  }
}

