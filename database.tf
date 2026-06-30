resource "oci_database_autonomous_database" "adb" {
  compartment_id              = oci_identity_compartment.lab.id
  display_name                = var.adb_display_name
  db_name                     = var.adb_db_name
  db_workload                 = "AJD"
  db_version                  = var.adb_db_version
  admin_password              = var.adb_admin_password
  compute_model               = var.adb_compute_model
  compute_count               = var.adb_compute_count
  data_storage_size_in_gb     = var.adb_data_storage_size_in_gb
  is_dev_tier                 = var.adb_is_dev_tier
  is_auto_scaling_enabled     = false
  is_mtls_connection_required = false
  license_model               = "LICENSE_INCLUDED"
  whitelisted_ips             = var.adb_allowed_cidrs
  freeform_tags               = local.common_tags

  lifecycle {
    precondition {
      condition     = !var.adb_is_dev_tier || var.adb_compute_count == 4
      error_message = "Autonomous AI Database for Developers requires adb_compute_count = 4 when adb_is_dev_tier = true."
    }

    precondition {
      condition     = !var.adb_is_dev_tier || var.adb_data_storage_size_in_gb == 20
      error_message = "Autonomous AI Database for Developers requires adb_data_storage_size_in_gb = 20 when adb_is_dev_tier = true."
    }
  }
}
