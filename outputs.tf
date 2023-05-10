##############################################################################
# Outputs
##############################################################################

output "landing_zone" {
  value       = module.landing_zone
  description = "Landing zone configuration"
}

output "access_key_id" {
  value = nonsensitive(data.ibm_resource_key.key.credentials["cos_hmac_keys.access_key_id"])
}
output "secret_access_key" {
  value = nonsensitive(data.ibm_resource_key.key.credentials["cos_hmac_keys.secret_access_key"])
}


output "prefix" {
  description = "The prefix that is associated with all resources"
  value       = var.prefix
}

output "vpc_names" {
  description = "A list of the names of the VPC."
  value       = module.landing_zone.vpc_names
}


output "transit_gateway_name" {
  description = "The name of the transit gateway."
  value       = module.landing_zone.transit_gateway_name
}
output "powervs_workspace_name" {
  description = "PowerVS infrastructure workspace name."
  value       = module.powervs_infra.powervs_workspace_name
}

output "powervs_sshkey_name" {
  description = "SSH public key name in created PowerVS infrastructure."
  value       = module.powervs_infra.powervs_sshkey_name
}

output "powervs_zone" {
  description = "Zone where PowerVS infrastructure is created."
  value       = module.powervs_infra.powervs_zone
}

output "powervs_resource_group_name" {
  description = "IBM Cloud resource group where PowerVS infrastructure is created."
  value       = module.powervs_infra.powervs_resource_group_name
}

output "cloud_connection_count" {
  description = "Number of cloud connections configured in created PowerVS infrastructure."
  value       = module.powervs_infra.cloud_connection_count
}

output "powervs_management_network_name" {
  description = "Name of management network in created PowerVS infrastructure."
  value       = module.powervs_infra.powervs_management_network_name
}

output "powervs_backup_network_name" {
  description = "Name of backup network in created PowerVS infrastructure."
  value       = module.powervs_infra.powervs_backup_network_name
}

output "instance_private_ips" {
  description = "All private IP addresses (as a list) of IBM PowerVS instance."
  value       = join(", ", [for ip in data.ibm_pi_instance.instance_ips_ds.networks[*].ip : format("%s", ip)])
}


output "instance_mgmt_ip" {
  description = "IP address of the management network interface of IBM PowerVS instance."
  value       = data.ibm_pi_instance_ip.instance_mgmt_ip_ds.ip
}

output "instance_wwns" {
  description = "Unique volume IDs (wwns) of all volumes attached to IBM PowerVS instance."
  depends_on  = [ibm_pi_volume.create_volume]
  value       = ibm_pi_volume.create_volume[*].wwn
}