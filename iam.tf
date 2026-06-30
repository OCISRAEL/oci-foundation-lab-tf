resource "oci_identity_compartment" "lab" {
  compartment_id = var.tenancy_ocid
  name           = var.compartment_name
  description    = var.compartment_description
  enable_delete  = true
  freeform_tags  = local.common_tags
}

resource "oci_identity_dynamic_group" "app" {
  compartment_id = var.tenancy_ocid
  name           = "${local.name_prefix}-app-dg"
  description    = "Instances in ${oci_identity_compartment.lab.name} that run the OCI Foundations Flask app"
  matching_rule  = "ANY {instance.compartment.id = '${oci_identity_compartment.lab.id}'}"
  freeform_tags  = local.common_tags
}

resource "oci_identity_policy" "app_object_storage" {
  compartment_id = var.tenancy_ocid
  name           = "${local.name_prefix}-app-object-storage"
  description    = "Allow the app instance dynamic group to write workshop uploads to Object Storage"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.app.name} to read objectstorage-namespaces in tenancy",
    "Allow dynamic-group ${oci_identity_dynamic_group.app.name} to read buckets in compartment id ${oci_identity_compartment.lab.id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.app.name} to manage objects in compartment id ${oci_identity_compartment.lab.id} where target.bucket.name = '${local.bucket_name}'"
  ]

  freeform_tags = local.common_tags
}
