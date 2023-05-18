locals {
  ibm_powervs_zone_region_map = {
    "syd04"    = "syd"
    "syd05"    = "syd"
    "eu-de-1"  = "eu-de"
    "eu-de-2"  = "eu-de"
    "lon04"    = "lon"
    "lon06"    = "lon"
    "tok04"    = "tok"
    "us-east"  = "us-east"
    "us-south" = "us-south"
    "dal12"    = "us-south"
    "tor01"    = "tor"
    "osa21"    = "osa"
    "sao01"    = "sao"
    "mon01"    = "mon"
    "wdc06"    = "us-east"
  }

  ibm_powervs_zone_cloud_region_map = {
    "syd04"    = "au-syd"
    "syd05"    = "au-syd"
    "eu-de-1"  = "eu-de"
    "eu-de-2"  = "eu-de"
    "lon04"    = "eu-gb"
    "lon06"    = "eu-gb"
    "tok04"    = "jp-tok"
    "us-east"  = "us-east"
    "us-south" = "us-south"
    "dal12"    = "us-south"
    "tor01"    = "ca-tor"
    "osa21"    = "jp-osa"
    "sao01"    = "br-sao"
    "mon01"    = "ca-tor"
    "wdc06"    = "us-east"
  }
}

module "landing_zone" {
  source           = "git::https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone//patterns/vpc?ref=v3.6.1"
  prefix           = var.prefix
  region           = var.region
  ibmcloud_api_key = var.ibmcloud_api_key
  override_json_string = var.preset
  tags             = var.resource_tags
}

locals {
 # powervs_resource_group_name =module.landing_zone.resource_groups.name
  hmac_key_name = module.landing_zone.cos_data[0].name
  transit_gateway_name = module.landing_zone.transit_gateway_name
  powervs_workspace_type = "power-iaas"

  stock_image_name = "VTL-FalconStor-10_03-001"
  catalog_image = [for x in data.ibm_pi_catalog_images.catalog_images.images : x if x.name == local.stock_image_name]
  private_image = [for x in data.ibm_pi_images.cloud_instance_images.image_info : x if x.name == local.stock_image_name]
  private_image_id = length(local.private_image) > 0 ? local.private_image[0].id  : ""
}

data "ibm_resource_key" "key" {
  name                  = local.hmac_key_name
  resource_instance_id  = module.landing_zone.cos_data[0].id
}

#####################################################
# PowerVS Infrastructure module
#####################################################


module "powervs_infra" {
  source     = "git::https://github.com/terraform-ibm-modules/terraform-ibm-powervs-infrastructure?ref=v6.3.0"
  providers  = { ibm = ibm.ibm-pvs }
  depends_on = [module.landing_zone]

  powervs_zone                = var.powervs_zone
  powervs_resource_group_name = var.powervs_resource_group_name
  powervs_workspace_name      = "${var.prefix}-${var.powervs_zone}-power-workspace"
  tags                        = var.tags
  powervs_sshkey_name         = "${var.prefix}-${var.powervs_zone}-ssh-pvs-key"
  ssh_public_key              = var.ssh_public_key
  ssh_private_key             = var.ssh_private_key
  powervs_management_network  = var.powervs_management_network
  powervs_backup_network      = var.powervs_backup_network
  transit_gateway_name        = local.transit_gateway_name
  reuse_cloud_connections     = false
  cloud_connection_count      = var.cloud_connection["count"]
  cloud_connection_speed      = var.cloud_connection["speed"]
  cloud_connection_gr         = var.cloud_connection["global_routing"]
  cloud_connection_metered    = var.cloud_connection["metered"]
}

#####################################################
# Create PowerVs Instance
#####################################################

data "ibm_resource_group" "resource_group_ds" {
  name = var.powervs_resource_group_name
}

data "ibm_resource_instance" "powervs_workspace_ds" {
  depends_on = [module.powervs_infra]
  name              = module.powervs_infra.powervs_workspace_name
  service           = local.powervs_workspace_type
  location          = var.powervs_zone
  resource_group_id = data.ibm_resource_group.resource_group_ds.id
}

data "ibm_pi_key" "key_ds" {
  provider  =  ibm.ibm-pvs
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
  pi_key_name          = module.powervs_infra.powervs_sshkey_name
}

data "ibm_pi_network" "network_1" {
  provider  =  ibm.ibm-pvs
  depends_on                   = [module.powervs_infra]
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
  pi_network_name      = var.powervs_management_network.name
}

data "ibm_pi_network" "network_2" {
  provider  =  ibm.ibm-pvs
  depends_on                   = [module.powervs_infra]
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
  pi_network_name      = var.powervs_backup_network.name
}

data "ibm_pi_catalog_images" "catalog_images" {
  sap                  = true
  vtl                  = true
  provider  =  ibm.ibm-pvs
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}
data "ibm_pi_images" "cloud_instance_images" {
  provider  =  ibm.ibm-pvs
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}


resource "ibm_pi_image" "stock_image_copy" {
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
  provider  =  ibm.ibm-pvs
  pi_image_name       = local.stock_image_name
  pi_image_id         = local.catalog_image[0].image_id
}

resource "ibm_pi_instance" "instance" {
  provider  =  ibm.ibm-pvs
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
  pi_memory            = var.memory
  pi_processors        = var.processors
  pi_instance_name     = "${var.prefix}-vtl"
  pi_proc_type         = var.processor_type
  pi_image_id          = length(local.private_image_id) == 0 ? ibm_pi_image.stock_image_copy.image_id : local.private_image_id
  pi_sys_type          = var.sys_type
  pi_storage_type      = var.storage_type
  pi_key_pair_name     = data.ibm_pi_key.key_ds.id
  pi_health_status         = "OK"
  pi_storage_pool_affinity = false
   pi_network {
    network_id = data.ibm_pi_network.network_1.id
  }
  dynamic "pi_network" {
    for_each = var.powervs_backup_network["name"] == "" ? [] : [1]
    content {
      network_id = data.ibm_pi_network.network_2.id
    }
}

  timeouts {
    create = "30m"
  }

}

#####################################################
# Create Disks mapping variables
#####################################################

locals {
  disks_counts   = length(var.powervs_storage_config["counts"]) > 0 ? [for x in(split(",", var.powervs_storage_config["counts"])) : tonumber(trimspace(x))] : null
  disks_size_tmp = length(var.powervs_storage_config["counts"]) > 0 ? [for disk_size in split(",", var.powervs_storage_config["disks_size"]) : tonumber(trimspace(disk_size))] : null
  disks_size     = length(var.powervs_storage_config["counts"]) > 0 ? flatten([for idx, disk_count in local.disks_counts : [for i in range(disk_count) : local.disks_size_tmp[idx]]]) : null

  tier_types_tmp = length(var.powervs_storage_config["counts"]) > 0 ? [for tier_type in split(",", var.powervs_storage_config["tiers"]) : trimspace(tier_type)] : null
  tiers_type     = length(var.powervs_storage_config["counts"]) > 0 ? flatten([for idx, disk_count in local.disks_counts : [for i in range(disk_count) : local.tier_types_tmp[idx]]]) : null

  disks_name_tmp = length(var.powervs_storage_config["counts"]) > 0 ? [for disk_name in split(",", var.powervs_storage_config["names"]) : trimspace(disk_name)] : null
  disks_name     = length(var.powervs_storage_config["counts"]) > 0 ? flatten([for idx, disk_count in local.disks_counts : [for i in range(disk_count) : local.disks_name_tmp[idx]]]) : null

  disks_number = length(var.powervs_storage_config["counts"]) > 0 ? sum([for x in(split(",", var.powervs_storage_config["counts"])) : tonumber(trimspace(x))]) : 0
}

#####################################################
# Create Volumes
#####################################################

resource "ibm_pi_volume" "create_volume" {
  provider  =  ibm.ibm-pvs
  depends_on           = [ibm_pi_instance.instance]
  count                = local.disks_number
  pi_volume_size       = local.disks_size[count.index - (local.disks_number * floor(count.index / local.disks_number))]
  pi_volume_name       = "${var.powervs_instance_name}-${local.disks_name[count.index - (local.disks_number * floor(count.index / local.disks_number))]}-volume${count.index + 1}"
  pi_volume_type       = local.tiers_type[count.index - (local.disks_number * floor(count.index / local.disks_number))]
  pi_volume_shareable  = false
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid

  timeouts {
    create = "15m"
  }
}

#####################################################
# Attach Volumes to the Instance
#####################################################

resource "ibm_pi_volume_attach" "instance_volumes_attach" {
  provider  =  ibm.ibm-pvs
  depends_on           = [ibm_pi_volume.create_volume, ibm_pi_instance.instance]
  count                = local.disks_number
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
  pi_volume_id         = ibm_pi_volume.create_volume[count.index].volume_id
  pi_instance_id       = ibm_pi_instance.instance.instance_id


  timeouts {
    create = "50m"
    delete = "50m"
  }
}

data "ibm_pi_instance_ip" "instance_mgmt_ip_ds" {
  provider  =  ibm.ibm-pvs
  depends_on           = [ibm_pi_instance.instance]
  pi_network_name      = data.ibm_pi_network.network_1.pi_network_name
  pi_instance_name     = ibm_pi_instance.instance.pi_instance_name
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}

data "ibm_pi_instance" "instance_ips_ds" {
  provider  =  ibm.ibm-pvs
  depends_on           = [ibm_pi_instance.instance]
  pi_instance_name     = ibm_pi_instance.instance.pi_instance_name
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}

#####################################################
# Create servers (Linux,IBMI,AIX) in power-workspace
#####################################################

data "ibm_pi_image" "image1" {
  depends_on = [ module.powervs_infra ]
  provider  =  ibm.ibm-pvs
  pi_image_name        = var.powervs_os_image_name1
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}
data "ibm_pi_image" "image2" {
  depends_on = [ module.powervs_infra ]
 provider  =  ibm.ibm-pvs
  pi_image_name        = var.powervs_os_image_name2
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}
data "ibm_pi_image" "image3" {
  depends_on = [ module.powervs_infra ]
  provider  =  ibm.ibm-pvs
  pi_image_name        = var.powervs_os_image_name3
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}



resource "ibm_pi_key" "linux_sshkey" {
  provider  =  ibm.ibm-pvs
  pi_key_name          = "${var.prefix}-linux-sshkey"
  pi_ssh_key           = var.linux_ssh_publickey
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}

resource "ibm_pi_instance" "linux-instance" {
    provider  =  ibm.ibm-pvs
    pi_memory             = var.linux_memory
    pi_processors         = var.linux_processors
    pi_instance_name      = "${var.prefix}-linux"
    pi_proc_type          = var.linux_proc_type
    pi_image_id           = data.ibm_pi_image.image1.id
    pi_key_pair_name      = ibm_pi_key.linux_sshkey.pi_key_name
    pi_sys_type           = var.linux_sys_type
    pi_cloud_instance_id  = data.ibm_resource_instance.powervs_workspace_ds.guid
    pi_pin_policy         = "none"
    pi_health_status      = "WARNING"
    pi_storage_type       = var.linux_storage_type
    pi_network {
      network_id = data.ibm_pi_network.network_1.id
    }
}

resource "ibm_pi_key" "AIX_sshkey" {
  provider  =  ibm.ibm-pvs
  pi_key_name          = "${var.prefix}-aix-sshkey"
  pi_ssh_key           = var.AIX_ssh_publickey
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}

resource "ibm_pi_instance" "AIX-instance" {
    provider  =  ibm.ibm-pvs
    pi_memory             = var.AIX_memory
    pi_processors         = var.AIX_processors
    pi_instance_name      = "${var.prefix}-aix"
    pi_proc_type          = var.AIX_proc_type
    pi_image_id           = data.ibm_pi_image.image2.id
    pi_key_pair_name      = ibm_pi_key.AIX_sshkey.pi_key_name
    pi_sys_type           = var.AIX_sys_type
    pi_cloud_instance_id  = data.ibm_resource_instance.powervs_workspace_ds.guid
    pi_pin_policy         = "none"
    pi_health_status      = "WARNING"
    pi_storage_type       = var.AIX_storage_type
    pi_network {
      network_id = data.ibm_pi_network.network_1.id
    }
}


resource "ibm_pi_key" "IBMI_sshkey" {
  provider  =  ibm.ibm-pvs
  pi_key_name          = "${var.prefix}-ibmi-sshkey"
  pi_ssh_key           = var.IBMI_ssh_publickey
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}

resource "ibm_pi_instance" "IBMI-instance" {
    provider  =  ibm.ibm-pvs
    pi_memory             = var.IBMI_memory
    pi_processors         = var.IBMI_processors
    pi_instance_name      = "${var.prefix}-ibmi"
    pi_proc_type          = var.IBMI_proc_type
    pi_image_id           = data.ibm_pi_image.image3.id
    pi_key_pair_name      = ibm_pi_key.IBMI_sshkey.pi_key_name
    pi_sys_type           = var.IBMI_sys_type
    pi_cloud_instance_id  = data.ibm_resource_instance.powervs_workspace_ds.guid
    pi_pin_policy         = "none"
    pi_health_status      = "WARNING"
    pi_storage_type       = var.IBMI_storage_type
    pi_network {
      network_id = data.ibm_pi_network.network_1.id
    }
}

####################################################
# Create servers (Windows server in VPC-infrastructure
#################################################

resource "ibm_is_vpc" "example" {
  name = "${var.prefix}-windows-vpc"
}

data "ibm_is_image" "example" {
  name = "ibm-windows-server-2022-full-standard-amd64-7"
}

resource "ibm_is_vpc_address_prefix" "example" {
  cidr = "10.0.1.0/24"
  name = "add-prefix"
  vpc  = ibm_is_vpc.example.id
  zone = var.zone
}

resource "ibm_is_subnet" "example" {
  depends_on = [
    ibm_is_vpc_address_prefix.example
  ]
  name            = "${var.prefix}-windows-subnet"
  vpc             = ibm_is_vpc.example.id
  zone            = var.zone
  ipv4_cidr_block = "10.0.1.0/24"
}

resource "ibm_is_ssh_key" "example" {
  name       = "${var.prefix}-windows-ssh"
  public_key = var.windows_ssh_publickey
}

resource "ibm_is_instance" "example" {
  name    = "${var.prefix}-windows-instance"
  image   = data.ibm_is_image.example.id
  profile = "bx2-2x8"
  metadata_service_enabled  = false

  primary_network_interface {
    subnet = ibm_is_subnet.example.id
    #allow_ip_spoofing = true
  }

  network_interfaces {
    name   = "eth1"
    subnet = ibm_is_subnet.example.id
    allow_ip_spoofing = false
  }

  vpc  = ibm_is_vpc.example.id
  zone = var.zone
  keys = [ibm_is_ssh_key.example.id]

  //User can configure timeouts
  timeouts {
    create = "15m"
    update = "15m"
    delete = "15m"
  }
}