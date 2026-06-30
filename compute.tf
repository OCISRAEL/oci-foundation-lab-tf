resource "oci_core_instance" "app" {
  availability_domain = local.availability_domain
  compartment_id      = oci_identity_compartment.lab.id
  display_name        = "${local.name_prefix}-app"
  shape               = var.instance_shape
  freeform_tags       = local.common_tags

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = local.image_id
    boot_volume_size_in_gbs = var.boot_volume_size_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.private.id
    assign_public_ip = false
    nsg_ids          = [oci_core_network_security_group.app.id]
    display_name     = "${local.name_prefix}-app-vnic"
    hostname_label   = "app"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      app_config_json      = local.app_config_json
      app_directory_name   = var.app_directory_name
      app_port             = var.app_port
      app_source_branch    = var.app_source_branch
      app_source_repo_url  = var.app_source_repo_url
      block_mount_point    = "/mnt/data"
      block_volume_size_gb = var.block_volume_size_gbs
    }))
  }

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false

    plugins_config {
      name          = "Block Volume Management"
      desired_state = "ENABLED"
    }
  }

  depends_on = [
    oci_identity_policy.app_object_storage,
    oci_objectstorage_bucket.app,
    oci_database_autonomous_database.adb
  ]

}

resource "oci_core_volume_attachment" "data" {
  attachment_type                   = "iscsi"
  instance_id                       = oci_core_instance.app.id
  volume_id                         = oci_core_volume.data.id
  display_name                      = "${local.name_prefix}-data-attachment"
  is_read_only                      = false
  is_shareable                      = false
  is_agent_auto_iscsi_login_enabled = true
}
