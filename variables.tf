##############################################################################
# Account Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "The IBM Cloud platform API key needed to deploy IAM enabled resources."
  type        = string
  sensitive   = true
  default     = "5Frgf9C72JYeD0NlnP2Flo1qJu8v3BvQ2WdeaGDyzI1v"
}

variable "prefix" {
  description = "A unique identifier for resources. Must begin with a lowercase letter and end with a lowerccase letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  type        = string
  default     = "fs-draas"

  validation {
    error_message = "Prefix must begin with a lowercase letter and contain only lowercase letters, numbers, and - characters. Prefixes must end with a lowercase letter or number and be 16 or fewer characters."
    condition     = can(regex("^([a-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix)) && length(var.prefix) <= 16
  }
}

variable "preset" {
  description = "Use one of supported [configurations](https://github.com/terraform-ibm-modules/terraform-ibm-powervs-infrastructure/tree/main/examples/ibm-catalog/presets/slz-for-powervs). Copy the configuration from the link into the `preset` deployment value."
  type        = string
  default     = <<EOF
   {
    "enable_transit_gateway": true,
    "transit_gateway_connections": [
      "management"
    ],
    "transit_gateway_resource_group": "slz-service-rg",
    "service_endpoints": "private",
    "security_groups": [],
    "atracker": {
      "collector_bucket_name": "",
      "receive_global_events": true,
      "resource_group": "",
      "add_route": false
    },
    "cos": [
      {
        "buckets": [
          {
            "endpoint_type": "public",
            "force_delete": true,
            "name": "falconstor-bucket",
            "storage_class": "standard",
            "kms_key": "slz-cos-key"
          }
        ],
        "keys": [
          {
              "name": "falconstor-cos",
              "role": "Object Writer",
              "enable_HMAC": true
          }
        ],
        "name": "falconstor-cos",
        "plan": "standard",
        "random_suffix": true,
        "resource_group": "slz-service-rg",
        "use_data": false
      }
    ],
    "iam_account_settings": {
      "enable": false
    },
    "key_management": {
      "keys": [
        {
          "key_ring": "slz-slz-ring",
          "name": "slz-cos-key",
          "root_key": true
        }
      ],
      "name": "slz-kms",
      "resource_group": "slz-service-rg",
      "use_hs_crypto": false
    },
    "resource_groups": [
      {
        "create": true,
        "name": "slz-service-rg",
        "use_prefix": true
      },
      {
        "create": true,
        "name": "slz-management-rg",
        "use_prefix": true
      }
    ],
    "secrets_manager": {
      "kms_key_name": null,
      "name": null,
      "resource_group": null,
      "use_secrets_manager": false
    },
    "network_cidr": "10.0.0.0/8",
    "vpcs": [
      {
        "address_prefixes": {
          "zone-1": [],
          "zone-2": [],
          "zone-3": []
        },
        "default_security_group_rules": [],
        "flow_logs_bucket_name": null,
        "network_acls": [
          {
            "name": "management-acl",
            "rules": [
              {
                "action": "allow",
                "destination": "0.0.0.0/0",
                "direction": "inbound",
                "name": "allow-all-inbound",
                "source": "0.0.0.0/0"
              },
              {
                "action": "allow",
                "destination": "0.0.0.0/0",
                "direction": "outbound",
                "name": "allow-all-outbound",
                "source": "0.0.0.0/0"
              }
            ]
          }
        ],
        "prefix": "management",
        "resource_group": "slz-management-rg",
        "subnets": {
          "zone-1": [
            {
              "acl_name": "management-acl",
              "cidr": "10.10.10.0/24",
              "name": "zone-1",
              "public_gateway": false
            }
          ],
          "zone-2": null,
          "zone-3": null
        },
        "use_public_gateways": {
          "zone-1": false,
          "zone-2": false,
          "zone-3": false
        }
      }
    ],
    "vsi": [],
    "vpn_gateways": [],
    "virtual_private_endpoints": [
      {
          "service_name": "falconstor-cos",
          "service_type": "cloud-object-storage",
          "resource_group": "slz-service-rg",
          "vpcs": [
              {
                  "name": "management",
                  "subnets": [
                      "zone-1"
                  ]
              }
          ]
      }
  ]
}
EOF

  validation {
    condition     = (var.preset != null && var.preset != "")
    error_message = "Please enter the required preset json."
  }
}

variable "region" {
  description = "Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions."
  type        = string
  default     = "jp-tok"
}

variable "zone" {
  description = "zone where VPC will be created. To find your VPC zone, ex:jp-tok-1,us-south-1"
  type        = string
  default     = "jp-tok-1"
}


variable "resource_tags" {
  type        = list(string)
  description = "Optional list of tags to be added to created resources"
  default     = ["vtl"]
}

variable "powervs_zone" {
  description = "IBM Cloud data center location where IBM PowerVS infrastructure will be created."
  type        = string
  default     = "tok04"
}

variable "powervs_resource_group_name" {
  description = "Existing IBM Cloud resource group name."
  type        = string
  default     = "Default"

}



variable "ssh_public_key" {
  description = "Public SSH Key for VSI creation. Must be an RSA key with a key size of either 2048 bits or 4096 bits (recommended). Must be a valid SSH key that does not already exist in the deployment region."
  type        = string
  default     ="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCNOUy7yc2SK9A5GBoiq47TPRcv1PkwOzTwE4h85MzZZIZ54Q5g3T/qFd3njz41ifHBKuXX+UxZftUo4oZkpvFNGUqxEvapXaB4MbfetXcteWvl7gMjFr/ZSEYB4rRNicIFco+f2/ko5Imu8Gsp0K7sUbr6jTTeUSjHaQM6m8UlavO/8ffG+dMUkiGEBjXAn9yYeudE4CuxQ9+P1bJaNL/NcWxiGfpmYy/hkQNj/ZTacqJlym8rzxK+Y4TfrPEgSCHSMprUpShOD2ba3FMqXH7VjxRD2ypj7VKVsHKHeZrMKhIyZX0U4oaH0uWbLF/dNZ3HeUQTkfCkFi9VLeC+hX0T rsa-key-20230519"
}

variable "ssh_private_key" {
  description = "Private SSH key (RSA format) used to login to IBM PowerVS instances. Should match to public SSH key referenced by 'ssh_public_key'. Entered data must be in [heredoc strings format](https://www.terraform.io/language/expressions/strings#heredoc-strings). The key is not uploaded or stored. For more information about SSH keys, see [SSH keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
  type        = string
  sensitive   = true
  default     ="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCNOUy7yc2SK9A5GBoiq47TPRcv1PkwOzTwE4h85MzZZIZ54Q5g3T/qFd3njz41ifHBKuXX+UxZftUo4oZkpvFNGUqxEvapXaB4MbfetXcteWvl7gMjFr/ZSEYB4rRNicIFco+f2/ko5Imu8Gsp0K7sUbr6jTTeUSjHaQM6m8UlavO/8ffG+dMUkiGEBjXAn9yYeudE4CuxQ9+P1bJaNL/NcWxiGfpmYy/hkQNj/ZTacqJlym8rzxK+Y4TfrPEgSCHSMprUpShOD2ba3FMqXH7VjxRD2ypj7VKVsHKHeZrMKhIyZX0U4oaH0uWbLF/dNZ3HeUQTkfCkFi9VLeC+hX0T rsa-key-20230519"
}

variable "IBMI_ssh_publickey" {
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCXO+Or21SmybJYgZfv6+N4QvwEFw3Lc971G1vpFtOh5Y4Tfaym7K7jEuyuqJTP1xzqfVWC3QEHgGPj3X6jaJ02+rDxSHbYpl78UVwSlFwAerZKQ0U/Ju28RsZMqvxKGv9yrCX0kkapFbOf0jZR/Cf33KSK8f3Rzod7knM9nvXujbjNlixN12KBlFvk2H6m+KKZOeeZz5boAOVMYZhWEcYn8ktv0iYl/57lj4QUEDq4LPDyBToq8SxfAD2PV8hfVvD4dZCdKH6R+SNI5kSBCN67ck/pWKFn4TrlCkz3sUZlDpdxfyCUOfNUItXfxW+tfIo+Ax5SNxt3c6vXTwjskAjT rsa-key-20230519"
  description = "IBMI_ssh_publickey"
}

variable "AIX_ssh_publickey" {
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCMejnM4lNDhcOtQPKfn7SlhaeK6+cTpJgsMF0d8RY6xwnkuIXnpyEX76A2w3CE0XEMc0IzcSpQWgAwV70nAXYjWUC1U2hedQzVzplJN6Yakyfi81O/TjCRnd1DrTfxVkUWsJPy4JcRKkWFBRAvW4W6zaNi6R+8HUObfplSls9HTfyK+p5+UGPusFN4VJe9zers4pcQc4rPH2dHuZ4LiWZntFheCDPPrEuJB0t6k9i2rw29EG1lPua7oM0SWO1md0U7zLZzwDtvn/LWuPuOfcefVSTWoQEfQnS8BAgp7MUA43WhgZSVhakuSP2UbgNDl1Pv47Q/C8KXZrobeMYPkl6D rsa-key-20230519"
  description = "AIX_ssh_publickey"
}

variable "linux_ssh_publickey" {
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCYzPKhAEjr6jIO97DSRDHCc1dPPfBXFx3mst01MU61L3R68/z3/XHTiRnrSqFddLzJ8xNmA1oTdmYEiuq68M3ycNOhwPry+t9yScYBgLBP7i/DAn6vfDig8ozxA/XpEbkTvVg7y2F2euB1N154hVmwOB5yTAWmf+gEoUq80emwi+vNOoMEoPmDy9auIjYHRb2wqPt7ZJTbBI4QXlP10oXAz/jdvyMGwrZZalvyFLDJfvSkg3PfTKtOiC35L+rYMt75RTXRvZoZLpl9AWDa+x/CMpshtlsfdFRuFY+mp06f1YBNCw/wZddoPxlpf3lWhRfw8KXOcQMJnWJ6E0uA2INh rsa-key-20230519"
  description = "linux_ssh_publickey"
}

variable "windows_ssh_publickey" {
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCd7/BNidtNn38eSUPoGKm0JgKoWuf+Hxems377a3miEnM8tw46z42wadpOVtv1QZACGs1EsNOi09c1xqYv6jn4MkO86x0GZYbCe6Lbkz/h9tHkAr7nUV+0Rdi3c81iGYORcTD7mq9C752Lt1/ZUxZJxZs+HoJAYUyxmeKtSzREQd/ePLXpqJN5h4/2HB50jn13K06rUgDNCyL53xipV/LdPZjBZcaTDxknOXWwlWkldifSGBD3faRzTS1fWFI1dGBy5mxOp8FQxtiroeHbs0lDjn3IG0x4qGgB2Yp4sT3Pqrmio4F6Poc0sGXsVi1wVGh6s2Hjkx4pU8Htsqw9fYad rsa-key-20230519"
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
variable "powervs_image_names" {
  description = "List of Images to be imported into cloud account from catalog images."
  type        = list(string)
  default     = ["RHEL8-SP6","7200-05-05","IBMi-71-11-2984-6"]
}

variable "cloud_connection_gr" {
  description = "Whether to enable global routing for this IBM Cloud connection. You can specify this value when you create a connection."
  type        = bool
  default     = null
}

variable "cloud_connection_metered" {
  description = "Whether to enable metering for this IBM Cloud connection. You can specify this value when you create a connection."
  type        = bool
  default     = null
}

variable "access_host_or_ip" {
  description = "The public IP address or hostname for the access host. The address is used to reach the target or server_host IP address and to configure the DNS, NTP, NFS, and Squid proxy services. Set it to null if you do not want to configure any services."
  type        = string
  default     = null
}

variable "squid_config" {
  description = "Configuration for the Squid proxy setup."
  type = object({
    squid_enable      = bool
    server_host_or_ip = string
    squid_port        = string
  })
  default = {
    "squid_enable"      = "false"
    "server_host_or_ip" = ""
    "squid_port"        = "3128"
  }
}

variable "dns_forwarder_config" {
  description = "Configuration for the DNS forwarder to a DNS service that is not reachable directly from PowerVS."
  type = object({
    dns_enable        = bool
    server_host_or_ip = string
    dns_servers       = string
  })
  default = {
    "dns_enable"        = "false"
    "server_host_or_ip" = ""
    "dns_servers"       = "161.26.0.7; 161.26.0.8; 9.9.9.9;"
  }
}

variable "ntp_forwarder_config" {
  description = "Configuration for the NTP forwarder to an NTP service that is not reachable directly from PowerVS."
  type = object({
    ntp_enable        = bool
    server_host_or_ip = string
  })
  default = {
    "ntp_enable"        = "false"
    "server_host_or_ip" = ""
  }
}

variable "nfs_config" {
  description = "Configuration for the shared NFS file system (for example, for the installation media). Creates a filesystem of disk size specified, mounts and NFS exports it."
  type = object({
    nfs_enable        = bool
    server_host_or_ip = string
    nfs_file_system = list(object({
      name       = string
      mount_path = string
      size       = number
    }))
  })
  default = {
    "nfs_enable"        = "false"
    "server_host_or_ip" = ""
    "nfs_file_system"   = [{ name : "nfs", mount_path : "/nfs", size : 1000 }]
  }
}

variable "perform_proxy_client_setup" {
  description = "Proxy configuration to allow internet access for a VM or LPAR."
  type = object(
    {
      squid_client_ips = list(string)
      squid_server_ip  = string
      squid_port       = string
      no_proxy_hosts   = string
    }
  )
  default = null
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
    counts     = "3"
    tiers      = "tier1,tier1,tier1"
    #paths      = ""
  }
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

variable "powervs_os_image_name1" {
  description = "Image Name for PowerVS Instance"
  type        = string
  default     = "RHEL8-SP6"
}
variable "powervs_os_image_name2" {
  description = "Image Name for PowerVS Instance"
  type        = string
  default     = "7200-05-05"
}
variable "powervs_os_image_name3" {
  description = "Image Name for PowerVS Instance"
  type        = string
  default     = "IBMi-71-11-2984-6"
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
