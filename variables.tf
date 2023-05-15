##############################################################################
# Account Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "The IBM Cloud platform API key needed to deploy IAM enabled resources."
  type        = string
  sensitive   = true
  default     = ""
}

variable "prefix" {
  description = "A unique identifier for resources. Must begin with a lowercase letter and end with a lowerccase letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  type        = string
  default     = ""

  validation {
    error_message = "Prefix must begin with a lowercase letter and contain only lowercase letters, numbers, and - characters. Prefixes must end with a lowercase letter or number and be 16 or fewer characters."
    condition     = can(regex("^([a-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix)) && length(var.prefix) <= 16
  }
}

variable "preset" {
  description = "Use one of supported [configurations](https://github.com/terraform-ibm-modules/terraform-ibm-powervs-infrastructure/tree/main/examples/ibm-catalog/presets/slz-for-powervs). Copy the configuration from the link into the `preset` deployment value."
  type        = string
  

  validation {
    condition     = (var.preset != null && var.preset != "")
    error_message = "Please enter the required preset json."
  }
}

variable "region" {
  description = "Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions."
  type        = string
  default     = ""
}

variable "resource_tags" {
  type        = list(string)
  description = "Optional list of tags to be added to created resources"
  default     = ["Vtl"]
}

variable "powervs_zone" {
  description = "IBM Cloud data center location where IBM PowerVS infrastructure will be created."
  type        = string
  default     = ""
}

variable "powervs_resource_group_name" {
  description = "Existing IBM Cloud resource group name."
  type        = string
  default     = ""

}



variable "ssh_public_key" {
  description = "Public SSH Key for VSI creation. Must be an RSA key with a key size of either 2048 bits or 4096 bits (recommended). Must be a valid SSH key that does not already exist in the deployment region."
  type        = string
  default     =""
}

variable "ssh_private_key" {
  description = "Private SSH key (RSA format) used to login to IBM PowerVS instances. Should match to public SSH key referenced by 'ssh_public_key'. Entered data must be in [heredoc strings format](https://www.terraform.io/language/expressions/strings#heredoc-strings). The key is not uploaded or stored. For more information about SSH keys, see [SSH keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
  type        = string
  sensitive   = true
  default     =""
}

variable "IBMI_ssh_publickey" {
  type        = string
  default     = ""
  description = "IBMI_ssh_publickey"
}

variable "AIX_ssh_publickey" {
  type        = string
  default     = ""
  description = "AIX_ssh_publickey"
}

variable "linux_ssh_publickey" {
  type        = string
  default     = ""
  description = "linux_ssh_publickey"
}

variable "windows_ssh_publickey" {
  type        = string
  default     = ""
  description = "windows_ssh_publickey"
}



#####################################################
# Optional Parameters
#####################################################

variable "powervs_management_network" {
  description = "Name of the IBM Cloud PowerVS management subnet and CIDR to create."
  type = object({
    name = string
    cidr = string
  })
  default = {
    name = "mgmt_net"
    cidr = "10.51.0.0/24"
  }
}

variable "powervs_backup_network" {
  description = "Name of the IBM Cloud PowerVS backup network and CIDR to create."
  type = object({
    name = string
    cidr = string
  })
  default = {
    name = "bkp_net"
    cidr = "10.52.0.0/24"
  }
}

variable "cloud_connection" {
  description = "Cloud connection configuration: speed (50, 100, 200, 500, 1000, 2000, 5000, 10000 Mb/s), count (1 or 2 connections), global_routing (true or false), metered (true or false)"
  type = object({
    count          = number
    speed          = number
    global_routing = bool
    metered        = bool
  })

  default = {
    count          = 2
    speed          = 5000
    global_routing = true
    metered        = true
  }
}


variable "tags" {
  description = "List of tag names for the IBM Cloud PowerVS workspace"
  type        = list(string)
  default     = ["Vtl"]
}


variable "memory" {
  type        = number
  default     = 18
  description = "The amount of memory to assign to the VTL in GB according to the following formula: memory >= 16 + (2 * license_repository_capacity)"
}
variable "processors" {
  type        = number
  default     = 1
  description = "The number of vCPUs, AKA virtual processors, to assign to the VTL virtual machine instance; one vCPU is equal to one physical CPU core."
}
variable "powervs_instance_name" {
  description = "Name of instance which will be created"
  type        = string
  default     = "vtl-vpe"
  validation {
    condition     = length(var.powervs_instance_name) <= 13
    error_message = "Maximum length of Instance name must be less or equal to 13 characters only."
  }
}
variable "processor_type" {
  type        = string
  default     = "shared"
  description = "The type of processor mode in which the VTL will run: 'shared', 'capped', or 'dedicated'"
}
variable "sys_type" {
  type        = string
  default     = "s922"
  description = "The type of system on which to create the VTL: Processor type e980/s922/e1080/s1022"
}
variable "storage_type" {
  type        = string
  default     = "tier1"
  description = "The type of storage tier for used volumes: 'tier1' (high performance) or 'tier3'"
}

variable "powervs_storage_config" {
  description = "DISKS To be created and attached to PowerVS Instance. Comma separated values.'disk_sizes' are in GB. 'count' specify over how many storage volumes the file system will be striped. 'tiers' specifies the storage tier in PowerVS workspace. For creating multiple file systems, specify multiple entries in each parameter in the structure. E.g., for creating 2 file systems, specify 2 names, 2 disk sizes, 2 counts, 2 tiers and 2 paths."
  type = object({
    names      = string
    disks_size = string
    counts     = string
    tiers      = string
    #paths      = string
  })
  default = {
    names      = "configuration-volume,index_volume,tape_volume"
    disks_size = "20,1024,1024"
    counts     = "1,1,1"
    tiers      = "tier1,tier1,tier1"
    #paths      = ""
  }
}

variable "IBMI_sshkey_name" {
  type        = string
  default     = "FS_IBMI_sshkey"
  description = "IBMI_sshkey_name"
}

variable "IBMI_memory" {
  type        = number
  default     = "2"
  description = "IBMI_memory"
}

variable "IBMI_processors" {
  type        = number
  default     = "0.25"
  description = "IBMI_processors"
}

variable "IBMI_instance_name" {
  type        = string
  default     = "FS_DraaS_IBMI_instance"
  description = "IBMI_instance_name"
}

variable "IBMI_proc_type" {
  type        = string
  default     = "shared"
  description = "IBMI_proc_type"
}

variable "IBMI_sys_type" {
  type        = string
  default     = "s922"
  description = "IBMI_sys_type"
}

variable "IBMI_storage_type" {
  type        = string
  default     = "tier3"
  description = "Type of storage tier to assign to the VTL instance based on required performance: 'tier1' or 'tier3'"
}

variable "powervs_image_names" {
  description = "List of Images to be imported into cloud account from catalog images."
  type        = list(string)
  default = [ "RHEL8-SP6","7200-05-05","IBMi-72-09-2924-8" ]
}


variable "AIX_sshkey_name" {
  type        = string
  default     = "fs_AIX_sshkey"
  description = "AIX_sshkey_name"
}



variable "AIX_memory" {
  type        = number
  default     = "2"
  description = "AIX_memory"
}

variable "AIX_processors" {
  type        = number
  default     = "0.25"
  description = "AIX_processors"
}

variable "AIX_instance_name" {
  type        = string
  default     = "fs_DraaS_AIX_instance"
  description = "AIX_instance_name"
}

variable "AIX_proc_type" {
  type        = string
  default     = "shared"
  description = "AIX_proc_type"
}

variable "AIX_sys_type" {
  type        = string
  default     = "s922"
  description = "AIX_sys_type"
}

variable "AIX_storage_type" {
  type        = string
  default     = "tier3"
  description = "Type of storage tier to assign to the VTL instance based on required performance: 'tier1' or 'tier3'"
}

variable "linux_sshkey_name" {
  type        = string
  default     = "fs_linux_sshkey"
  description = "linux_sshkey_name"
}



variable "linux_memory" {
  type        = number
  default     = "2"
  description = "linux_memory"
}

variable "linux_processors" {
  type        = number
  default     = "0.25"
  description = "linux_processors"
}

variable "linux_instance_name" {
  type        = string
  default     = "fs_DraaS_linux_instance"
  description = "linux_instance_name"
}

variable "linux_proc_type" {
  type        = string
  default     = "shared"
  description = "linux_proc_type"
}

variable "linux_sys_type" {
  type        = string
  default     = "s922"
  description = "linux_sys_type"
}

variable "linux_storage_type" {
  type        = string
  default     = "tier3"
  description = "Type of storage tier to assign to the VTL instance based on required performance: 'tier1' or 'tier3'"
}


#############################################################################
# Schematics Output
#############################################################################

# tflint-ignore: terraform_naming_convention
variable "IC_SCHEMATICS_WORKSPACE_ID" {
  default     = ""
  type        = string
  description = "leave blank if running locally. This variable will be automatically populated if running from an IBM Cloud Schematics workspace"
}


