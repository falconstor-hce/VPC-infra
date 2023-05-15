
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
  #placement_group = [for x in data.ibm_pi_placement_groups.cloud_instance_groups.placement_groups : x if x.name == var.placement_group]
  #placement_group_id = length(local.placement_group) > 0 ? local.placement_group[0].id : ""
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
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
  pi_key_name          = module.powervs_infra.powervs_sshkey_name
}

data "ibm_pi_network" "network_1" {
  depends_on                   = [module.powervs_infra]
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
  pi_network_name      = var.powervs_management_network.name
}

data "ibm_pi_network" "network_2" {
  depends_on                   = [module.powervs_infra]
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
  pi_network_name      = var.powervs_backup_network.name
}

data "ibm_pi_catalog_images" "catalog_images" {
  sap                  = true
  vtl                  = true
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}
data "ibm_pi_images" "cloud_instance_images" {
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}
/*data "ibm_pi_placement_groups" "cloud_instance_groups" {
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}*/

resource "ibm_pi_image" "stock_image_copy" {
 #count = length(local.private_image_id)
  pi_image_name       = local.stock_image_name
  pi_image_id         = local.catalog_image.image_id
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}

resource "ibm_pi_instance" "instance" {
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
  pi_memory            = var.memory
  pi_processors        = var.processors
  pi_instance_name     = var.powervs_instance_name
  pi_proc_type         = var.processor_type
  pi_image_id          = ibm_pi_image.stock_image_copy.pi_image_id
  pi_sys_type          = var.sys_type
  pi_storage_type      = var.storage_type
  pi_key_pair_name     = data.ibm_pi_key.key_ds.id
  pi_health_status         = "OK"
  pi_storage_pool_affinity = false
  # pi_affinity_policy   = length(var.pvm_instances) > 0 ? var.affinity_policy : null
  #pi_anti_affinity_instances = length(var.pvm_instances) > 0 ? split(",", var.pvm_instances) : null
  #pi_placement_group_id = local.placement_group_id
  #pi_license_repository_capacity = var.license_repository_capacity
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
  depends_on           = [ibm_pi_instance.instance]
  pi_network_name      = data.ibm_pi_network.network_1.pi_network_name
  pi_instance_name     = ibm_pi_instance.instance.pi_instance_name
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}

data "ibm_pi_instance" "instance_ips_ds" {
  depends_on           = [ibm_pi_instance.instance]
  pi_instance_name     = ibm_pi_instance.instance.pi_instance_name
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}

#####################################################
# Create servers (Linux,IBMI,AIX) in power-workspace
#####################################################

data "ibm_pi_catalog_images" "catalog_images_ds" {
 sap                  = true
 vtl = true
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}

locals {
  images_length              = length(var.powervs_image_names)
  split_images_index         = ceil(local.images_length / 3)
  catalog_images_to_import_3 = flatten([for stock_image in data.ibm_pi_catalog_images.catalog_images_ds.images : [for image_name in slice(var.powervs_image_names, 0, local.split_images_index) : stock_image if stock_image.name == image_name]])
  catalog_images_to_import_4 = flatten([for stock_image in data.ibm_pi_catalog_images.catalog_images_ds.images : [for image_name in slice(var.powervs_image_names, 1, local.split_images_index) : stock_image if stock_image.name == image_name]])
  catalog_images_to_import_5 = flatten([for stock_image in data.ibm_pi_catalog_images.catalog_images_ds.images : [for image_name in slice(var.powervs_image_names, local.split_images_index, local.images_length) : stock_image if stock_image.name == image_name]])
  split_images_3             = slice(var.powervs_image_names, 0, local.split_images_index)
  split_images_4             = slice(var.powervs_image_names, 1, local.split_images_index)
  split_images_5             = slice(var.powervs_image_names, local.split_images_index, local.images_length)

}

resource "ibm_pi_image" "import_images_3" {
  count                = length(local.split_images_3)
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
  pi_image_id          = local.catalog_images_to_import_3[count.index].image_id
  pi_image_name        = local.catalog_images_to_import_3[count.index].name

  timeouts {
    create = "9m"
  }
}

resource "ibm_pi_image" "import_images_4" {
  count                = length(local.split_images_4)
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
  pi_image_id          = local.catalog_images_to_import_4[count.index].image_id
  pi_image_name        = local.catalog_images_to_import_4[count.index].name

  timeouts {
    create = "9m"
  }
}

resource "ibm_pi_image" "import_images_5" {
  count                = length(local.split_images_5)
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
  pi_image_id          = local.catalog_images_to_import_5[count.index].image_id
  pi_image_name        = local.catalog_images_to_import_5[count.index].name

  timeouts {
    create = "9m"
  }
}


resource "ibm_pi_key" "linux_sshkey" {
  pi_key_name          = var.linux_sshkey_name
  pi_ssh_key           = var.linux_ssh_publickey
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}

data "ibm_pi_network" "ds_network" {
  pi_network_name = "vtl-subnet"
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}

resource "ibm_pi_instance" "linux-instance" {
    pi_memory             = var.linux_memory
    pi_processors         = var.linux_processors
    pi_instance_name      = var.linux_instance_name
    pi_proc_type          = var.linux_proc_type
    count                 = length(local.split_images_3)
    pi_image_id           = ibm_pi_image.import_images_3[count.index].image_id
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
  pi_key_name          = var.AIX_sshkey_name
  pi_ssh_key           = var.AIX_ssh_publickey
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}

resource "ibm_pi_instance" "AIX-instance" {
    pi_memory             = var.AIX_memory
    pi_processors         = var.AIX_processors
    pi_instance_name      = var.AIX_instance_name
    pi_proc_type          = var.AIX_proc_type
    count                 = length(local.split_images_4)
    pi_image_id           = ibm_pi_image.import_images_4[count.index].image_id
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
  pi_key_name          = var.IBMI_sshkey_name
  pi_ssh_key           = var.IBMI_ssh_publickey
  pi_cloud_instance_id = data.ibm_resource_instance.powervs_workspace_ds.guid
}

resource "ibm_pi_instance" "IBMI-instance" {
    pi_memory             = var.IBMI_memory
    pi_processors         = var.IBMI_processors
    pi_instance_name      = var.IBMI_instance_name
    pi_proc_type          = var.IBMI_proc_type
    count                 = length(local.split_images_5)
    pi_image_id           = ibm_pi_image.import_images_5[count.index].image_id
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



#####################################################
# Create servers (Windows server in VPC-infrastructure
#####################################################


data "ibm_is_image" "example" {
  name = "ibm-windows-server-2022-full-standard-amd64-7"
}

resource "ibm_is_vpc" "example" {
  name = "windows-vpc"
}

resource "ibm_is_subnet" "example" {
  name            = "windows-subnet"
  vpc             = ibm_is_vpc.example.id
  zone            = var.region
  ipv4_cidr_block = "10.240.0.0/24"
}

resource "ibm_is_ssh_key" "example" {
  name       = "windows-ssh"
  public_key = var.windows_ssh_publickey
}

resource "ibm_is_instance" "example" {
  name    = "windows-instance"
  image   = data.ibm_is_image.example.id
  profile = "bx2-2x8"
  metadata_service_enabled  = false

  primary_network_interface {
    subnet = ibm_is_subnet.example.id
    primary_ipv4_address = "10.240.0.6"  // will be deprecated. Use primary_ip.[0].address
    allow_ip_spoofing = true
  }

  network_interfaces {
    name   = "eth1"
    subnet = ibm_is_subnet.example.id
    allow_ip_spoofing = false
  }

  vpc  = ibm_is_vpc.example.id
  zone = var.region
  keys = [ibm_is_ssh_key.example.id]

  //User can configure timeouts
  timeouts {
    create = "15m"
    update = "15m"
    delete = "15m"
  }
}
