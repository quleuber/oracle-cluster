variable "compartment_ocid" {}
variable "region" {}
variable "net_id" {}

terraform {
  required_providers {
    oci = {
      source = "hashicorp/oci"
    }
  }
}
provider "oci" {
  region              = var.region
  auth                = "SecurityToken"
  config_file_profile = "terraform"
}

# networks

resource "oci_core_vcn" "main_net" {
  display_name   = "main net"
  dns_label      = "main"
  cidr_block     = "10.${var.net_id}.0.0/16"
  compartment_id = var.compartment_ocid
}

resource "oci_core_subnet" "private_subnet" {
  cidr_block        = "10.${var.net_id}.0.0/24"
  display_name      = "private subnet"
  dns_label         = "private"
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main_net.id
  security_list_ids = [oci_core_vcn.main_net.default_security_list_id]
  route_table_id    = oci_core_vcn.main_net.default_route_table_id
  dhcp_options_id   = oci_core_vcn.main_net.default_dhcp_options_id
}

resource "oci_core_subnet" "public_subnet" {
  cidr_block        = "10.${var.net_id}.1.0/24"
  display_name      = "public subnet"
  dns_label         = "public"
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main_net.id
  security_list_ids = [oci_core_vcn.main_net.default_security_list_id]
  route_table_id    = oci_core_route_table.route_table_public.id
  dhcp_options_id   = oci_core_dhcp_options.dhcp_options_public.id
}

# gateways

resource "oci_core_nat_gateway" "nat_gateway" {
  display_name   = "nat gateway"
  vcn_id         = oci_core_vcn.main_net.id
  compartment_id = var.compartment_ocid
}

resource "oci_core_internet_gateway" "internet_gateway" {
  display_name   = "internet gateway"
  vcn_id         = oci_core_vcn.main_net.id
  compartment_id = var.compartment_ocid
}

# route tables

resource "oci_core_default_route_table" "default_route_table" {
  display_name               = "default route table"
  manage_default_resource_id = oci_core_vcn.main_net.default_route_table_id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat_gateway.id
  }
}

resource "oci_core_route_table" "route_table_public" {
  display_name   = "route table - public"
  vcn_id         = oci_core_vcn.main_net.id
  compartment_id = var.compartment_ocid

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.internet_gateway.id
  }
}

# dhcp

resource "oci_core_default_dhcp_options" "default_dhcp_options" {
  display_name               = "default dhcp options"
  manage_default_resource_id = oci_core_vcn.main_net.default_dhcp_options_id

  // required
  options {
    type        = "DomainNameServer"
    server_type = "VcnLocal"
  }

  # // optional
  # options {
  #   type                = "SearchDomain"
  #   search_domain_names = [
  #     oci_core_vcn.main_net.vcn_domain_name,
  #     oci_core_subnet.public_subnet.subnet_domain_name,
  #     oci_core_subnet.private_subnet.subnet_domain_name,
  #   ]
  # }
}

resource "oci_core_dhcp_options" "dhcp_options_public" {
  display_name   = "dhcp options - public"
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main_net.id

  // required
  options {
    type        = "DomainNameServer"
    server_type = "VcnLocalPlusInternet"
  }

  # // optional
  # options {
  #   type                = "SearchDomain"
  #   search_domain_names = [
  #     oci_core_vcn.main_net.vcn_domain_name,
  #     # oci_core_subnet.public_subnet.subnet_domain_name,
  #     oci_core_subnet.private_subnet.subnet_domain_name,
  #   ]
  # }
}

resource "oci_core_default_security_list" "default_security_list" {
  display_name               = "default security list"
  manage_default_resource_id = oci_core_vcn.main_net.default_security_list_id

  // allow outbound tcp traffic on all ports
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "6" // tcp
  }

  // allow inbound ssh traffic
  ingress_security_rules {
    source    = "0.0.0.0/0"
    protocol  = "6" // tcp
    stateless = false

    tcp_options {
      min = 22 // SSH
      max = 22
    }
  }

  // allow inbound icmp traffic of a specific type
  ingress_security_rules {
    protocol  = 1
    source    = "0.0.0.0/0"
    stateless = true

    icmp_options {
      type = 3 // Destination Unreachable
      code = 4 // Fragmentation Needed and Don't Fragment was Set
    }
  }
}
