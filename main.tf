variable "region" {}
variable "compartment_ocid" {}
variable "availability_domain" {}

variable "net_id" {}

variable "ssh_authorized_keys" {
  type = string
}

variable "num_master_nodes" {
  type    = number
}
variable "num_worker_nodes" {
  type    = number
}

module "infra" {
    source = "./infra"

    region              = var.region
    compartment_ocid    = var.compartment_ocid
    availability_domain = var.availability_domain

    net_id              = var.net_id
    ssh_authorized_keys = var.ssh_authorized_keys

    num_master_nodes = var.num_master_nodes
    num_worker_nodes = var.num_worker_nodes
}
