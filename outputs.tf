output "compartment_ocid" {
  description = "Created lab compartment OCID."
  value       = oci_identity_compartment.lab.id
}

output "compartment_name" {
  description = "Created lab compartment name."
  value       = oci_identity_compartment.lab.name
}

output "vcn_ocid" {
  description = "Created VCN OCID."
  value       = oci_core_vcn.lab.id
}

output "public_subnet_ocid" {
  description = "Public load balancer subnet OCID."
  value       = oci_core_subnet.public.id
}

output "private_subnet_ocid" {
  description = "Private app subnet OCID."
  value       = oci_core_subnet.private.id
}

output "instance_private_ip" {
  description = "Private IP of the Flask app compute instance."
  value       = oci_core_instance.app.private_ip
}

output "cloud_shell_ssh_command" {
  description = "Use this from OCI Cloud Shell after selecting the private subnet as the active ephemeral private network."
  value       = "ssh -i <private_key_file> opc@${oci_core_instance.app.private_ip}"
}

output "bucket_name" {
  description = "Object Storage bucket used by the Flask app."
  value       = oci_objectstorage_bucket.app.name
}

output "autonomous_database_ocid" {
  description = "Autonomous JSON Database OCID."
  value       = oci_database_autonomous_database.adb.id
}

output "autonomous_database_name" {
  description = "Autonomous JSON Database display name."
  value       = oci_database_autonomous_database.adb.display_name
}

output "adb_admin_username" {
  description = "ADB admin username for Database Actions."
  value       = var.adb_admin_username
}

output "adb_mongodb_url_template" {
  description = "MongoDB API URL template from ADB before ADMIN credentials are inserted."
  value       = local.adb_mongodb_url_template
}

output "adb_mongodb_connection_string" {
  description = "MongoDB API connection string written to the instance app config."
  value       = local.adb_mongodb_connection_string
  sensitive   = true
}

output "load_balancer_ip" {
  description = "Public IP address of the load balancer."
  value       = oci_load_balancer_load_balancer.app.ip_address_details[0].ip_address
}

output "application_url" {
  description = "Workshop application URL."
  value       = "http://${oci_load_balancer_load_balancer.app.ip_address_details[0].ip_address}:${var.app_port}"
}

output "app_collection_name" {
  description = "MongoDB-compatible JSON collection name expected by the Flask app."
  value       = var.app_collection_name
}

output "next_steps" {
  description = "Next step after Terraform apply."
  value       = "Create the JSON collection and verify the app. See README.md."
}
