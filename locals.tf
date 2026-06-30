locals {
  project_slug      = trim(replace(lower(var.project_name), "/[^a-z0-9]+/", "-"), "-")
  safe_project_slug = local.project_slug != "" ? local.project_slug : "oci-lab"
  name_prefix       = substr(local.safe_project_slug, 0, 32)

  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
  image_id            = var.image_ocid != null && var.image_ocid != "" ? var.image_ocid : data.oci_core_images.oracle_linux.images[0].id

  bucket_name = var.bucket_name != null && var.bucket_name != "" ? var.bucket_name : substr("${local.safe_project_slug}-${substr(sha1(var.tenancy_ocid), 0, 8)}-bucket", 0, 63)

  adb_mongodb_url_template = oci_database_autonomous_database.adb.connection_urls[0].mongo_db_url
  adb_mongodb_connection_string = replace(
    replace(local.adb_mongodb_url_template, "[user:password@]", "${var.adb_admin_username}:${urlencode(var.adb_admin_password)}@"),
    "[user]",
    var.adb_admin_username
  )

  app_config_json = jsonencode({
    CONNECTION_STRING = local.adb_mongodb_connection_string
    bucketName        = local.bucket_name
    coll_name         = var.app_collection_name
  })

  common_tags = merge(var.freeform_tags, {
    managed-by = "terraform"
    workshop   = local.safe_project_slug
  })
}
