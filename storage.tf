resource "oci_objectstorage_bucket" "app" {
  compartment_id = oci_identity_compartment.lab.id
  namespace      = data.oci_objectstorage_namespace.current.namespace
  name           = local.bucket_name
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = var.bucket_versioning_enabled ? "Enabled" : "Disabled"
  freeform_tags  = local.common_tags
}

resource "oci_core_volume" "data" {
  availability_domain = local.availability_domain
  compartment_id      = oci_identity_compartment.lab.id
  display_name        = "${local.name_prefix}-data-volume"
  size_in_gbs         = var.block_volume_size_gbs
  freeform_tags       = local.common_tags
}
