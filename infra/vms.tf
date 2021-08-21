variable "num_master_nodes" {
  type    = number
  default = 1
}
variable "num_worker_nodes" {
  type    = number
  default = 1
}

variable "ssh_authorized_keys" {
  type = string
}
variable "images" {
  type = map(map(map(string)))
  default = {
    "oracle-linux-8" = {
      "x86_64" = {
        "sa-saopaulo-1" = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaajofvurybp4m47a3kiwd5ya5yx46utqct3rhjai4qtgwkliuae6ba"
      }
      "aarch64" = {
        "sa-saopaulo-1" = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaarsndqfas5ay4gh4u7be2zezkzaiv6hwhbncolvmgegujxl3tyl5q"
      }
    }
  }
}
variable "availability_domain" {
  # default = "AD-1"
}

resource "oci_core_instance" "cluster_master_node" {
  count = var.num_master_nodes

  display_name   = "cluster-master-node-${format("%02d", count.index + 1)}"
  compartment_id = var.compartment_ocid

  state = "RUNNING"

  source_details {
    source_type = "image"
    source_id   = var.images["oracle-linux-8"]["aarch64"][var.region]
  }

  shape = "VM.Standard.A1.Flex"
  shape_config {
    baseline_ocpu_utilization = ""
    memory_in_gbs             = "6"
    ocpus                     = "1"
  }

  availability_domain = var.availability_domain
  availability_config {
    recovery_action = "RESTORE_INSTANCE"
  }

  create_vnic_details {
    display_name     = "cluster-master-node-${format("%02d", count.index + 1)}"
    hostname_label   = "cluster-master-node-${format("%02d", count.index + 1)}"
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = "true"
  }

  launch_options {
    boot_volume_type                    = "PARAVIRTUALIZED"
    firmware                            = "UEFI_64"
    is_consistent_volume_naming_enabled = "true"
    is_pv_encryption_in_transit_enabled = "true"
    network_type                        = "PARAVIRTUALIZED"
    remote_data_volume_type             = "PARAVIRTUALIZED"
  }

  metadata = {
    "ssh_authorized_keys" = var.ssh_authorized_keys
  }
  extended_metadata = {}

  agent_config {
    # are_all_plugins_disabled = "false"
    # is_management_disabled   = "false"
    # is_monitoring_disabled   = "false"
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Run Command"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
    # plugins_config {
    #   desired_state = "DISABLED"
    #   name          = "Bastion"
    # }
  }
}

resource "oci_core_instance" "cluster_worker_node" {
  count = var.num_worker_nodes

  display_name   = "cluster-worker-node-${format("%02d", count.index + 1)}"
  compartment_id = var.compartment_ocid

  state = "RUNNING"

  source_details {
    source_type = "image"
    source_id   = var.images["oracle-linux-8"]["aarch64"][var.region]
  }

  shape = "VM.Standard.A1.Flex"
  shape_config {
    baseline_ocpu_utilization = ""
    memory_in_gbs             = "6"
    ocpus                     = "1"
  }

  availability_domain = var.availability_domain
  availability_config {
    recovery_action = "RESTORE_INSTANCE"
  }

  create_vnic_details {
    display_name   = "cluster-worker-node-${format("%02d", count.index + 1)}"
    hostname_label = "cluster-worker-node-${format("%02d", count.index + 1)}"
    subnet_id      = oci_core_subnet.public_subnet.id
    # assign_public_ip = "true"
  }

  launch_options {
    boot_volume_type                    = "PARAVIRTUALIZED"
    firmware                            = "UEFI_64"
    is_consistent_volume_naming_enabled = "true"
    is_pv_encryption_in_transit_enabled = "true"
    network_type                        = "PARAVIRTUALIZED"
    remote_data_volume_type             = "PARAVIRTUALIZED"
  }

  metadata = {
    "ssh_authorized_keys" = var.ssh_authorized_keys
  }
  extended_metadata = {}

  agent_config {
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Run Command"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
    # plugins_config {
    #   desired_state = "DISABLED"
    #   name          = "Bastion"
    # }
  }
}

output "instances_ip_addr" {
  value = {
    master = {
      for name, inst in oci_core_instance.cluster_master_node :
      (inst.display_name) => {
        "group"   = "master"
        "private" = inst.private_ip
        "public"  = inst.public_ip
      }
    },
    worker = {
      for name, inst in oci_core_instance.cluster_worker_node :
      (inst.display_name) => {
        "group"   = "worker"
        "private" = inst.private_ip
        # "public"  = inst.public_ip
      }
    },
  }
}
