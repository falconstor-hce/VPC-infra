provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

provider "ibm" {
  alias            = "ibm-pvs"
  region           = var.region
  zone             = var.powervs_zone
  ibmcloud_api_key = var.ibmcloud_api_key
}
