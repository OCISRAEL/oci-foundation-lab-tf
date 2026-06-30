variable "tenancy_ocid" {
  description = "OCI tenancy OCID. This is also the root compartment OCID."
  type        = string
}

variable "region" {
  description = "OCI region identifier, for example il-jerusalem-1."
  type        = string
  default     = "il-jerusalem-1"
}

variable "config_file_profile" {
  description = "OCI CLI config profile to use from ~/.oci/config. Defaults to DEFAULT."
  type        = string
  default     = "DEFAULT"
}

variable "user_ocid" {
  description = "OCI API user OCID. Leave null when using instance/resource principal auth supported by your environment."
  type        = string
  default     = null
}

variable "fingerprint" {
  description = "Fingerprint for the OCI API signing key. Leave null when using non-user auth."
  type        = string
  default     = null
}

variable "private_key_path" {
  description = "Path to the OCI API private key. Leave null when private_key or non-user auth is used."
  type        = string
  default     = null
}

variable "private_key" {
  description = "OCI API private key contents. Prefer private_key_path or environment config when possible."
  type        = string
  default     = null
  sensitive   = true
}

variable "project_name" {
  description = "Short project name used as a prefix for display names."
  type        = string
  default     = "oci-foundations-lab"
}

variable "compartment_name" {
  description = "Name of the lab compartment to create under the tenancy root."
  type        = string
  default     = "demo"
}

variable "compartment_description" {
  description = "Description for the lab compartment."
  type        = string
  default     = "OCI Foundations workshop lab resources managed by Terraform"
}

variable "freeform_tags" {
  description = "Freeform tags applied to supported resources."
  type        = map(string)
  default = {
    environment = "lab"
  }
}

variable "vcn_cidr" {
  description = "CIDR block for the lab VCN."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public load balancer subnet."
  type        = string
  default     = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private app subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "vcn_dns_label" {
  description = "DNS label for the VCN. Must be unique within the compartment and 15 chars or fewer."
  type        = string
  default     = "ocilab"
}

variable "public_subnet_dns_label" {
  description = "DNS label for the public subnet."
  type        = string
  default     = "edge"
}

variable "private_subnet_dns_label" {
  description = "DNS label for the private subnet."
  type        = string
  default     = "app"
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed to reach the public load balancer on the app port."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_ingress_cidrs" {
  description = "CIDR blocks allowed to SSH to the private instance. The default allows OCI Cloud Shell ephemeral private networking inside the VCN."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "app_port" {
  description = "Port where the Flask app listens and where the load balancer accepts traffic."
  type        = number
  default     = 5000
}

variable "lb_health_check_port" {
  description = "TCP port used by the load balancer backend health check. The workshop guide uses 22 for demo simplicity."
  type        = number
  default     = 22
}

variable "ssh_public_key" {
  description = "Public SSH key injected into the opc user's authorized_keys."
  type        = string
}

variable "availability_domain_index" {
  description = "Zero-based availability domain index for AD-specific resources."
  type        = number
  default     = 0
}

variable "image_ocid" {
  description = "Optional custom Oracle Linux image OCID. When null, the latest matching Oracle Linux image is discovered."
  type        = string
  default     = null
}

variable "oracle_linux_version" {
  description = "Oracle Linux version used when discovering the compute image."
  type        = string
  default     = "8"
}

variable "instance_shape" {
  description = "Compute shape for the Flask app instance."
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  description = "OCPUs assigned to the flexible compute shape."
  type        = number
  default     = 2
}

variable "instance_memory_gbs" {
  description = "Memory in GB assigned to the flexible compute shape."
  type        = number
  default     = 8
}

variable "boot_volume_size_gbs" {
  description = "Boot volume size in GB for the app instance."
  type        = number
  default     = 50
}

variable "block_volume_size_gbs" {
  description = "Data block volume size in GB, matching README Step 5."
  type        = number
  default     = 50
}

variable "bucket_name" {
  description = "Optional Object Storage bucket name. When null, a deterministic tenancy-scoped name is generated."
  type        = string
  default     = null
}

variable "bucket_versioning_enabled" {
  description = "Enable Object Storage bucket versioning."
  type        = bool
  default     = false
}

variable "adb_display_name" {
  description = "Autonomous JSON Database display name."
  type        = string
  default     = "adb-demo"
}

variable "adb_db_name" {
  description = "Autonomous JSON Database name. Must be alphanumeric, start with a letter, and be unique in the tenancy."
  type        = string
  default     = "adbdbdemo"
}

variable "adb_admin_username" {
  description = "ADB admin user used by the Flask MongoDB API connection string."
  type        = string
  default     = "ADMIN"
}

variable "adb_admin_password" {
  description = "Password for the ADB ADMIN user."
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.adb_admin_password) >= 12 &&
      length(var.adb_admin_password) <= 30 &&
      can(regex("[A-Z]", var.adb_admin_password)) &&
      can(regex("[a-z]", var.adb_admin_password)) &&
      can(regex("[0-9]", var.adb_admin_password)) &&
      !strcontains(lower(var.adb_admin_password), "admin") &&
      !strcontains(var.adb_admin_password, "\"") &&
      !strcontains(var.adb_admin_password, "@")
    )
    error_message = "ADB password must be 12-30 chars, include uppercase/lowercase/number, and must not contain admin, double quotes, or @."
  }
}

variable "adb_db_version" {
  description = "ADB database version. README uses 19c for JSON/MongoDB compatibility."
  type        = string
  default     = "19c"
}

variable "adb_compute_model" {
  description = "ADB compute model."
  type        = string
  default     = "ECPU"
}

variable "adb_compute_count" {
  description = "ADB compute count."
  type        = number
  default     = 4
}

variable "adb_data_storage_size_in_gb" {
  description = "ADB storage size in GB. Developer-tier Autonomous AI Database requires 20 GB."
  type        = number
  default     = 20
}

variable "adb_is_dev_tier" {
  description = "Enable Autonomous Database developer mode, matching the workshop."
  type        = bool
  default     = true
}

variable "adb_allowed_cidrs" {
  description = "CIDRs allowed to access ADB public endpoints. The README uses 0.0.0.0/0 for testing only."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_collection_name" {
  description = "MongoDB-compatible SODA collection name used by the Flask app."
  type        = string
  default     = "MY_COLLECTION"
}

variable "app_source_repo_url" {
  description = "Git repository cloned by cloud-init onto the instance."
  type        = string
  default     = "https://github.com/OCISRAEL/oci-foundations-lab.git"
}

variable "app_source_branch" {
  description = "Preferred Git branch for app bootstrap. Cloud-init falls back to the repo default branch if this branch is absent."
  type        = string
  default     = "main"
}

variable "app_directory_name" {
  description = "Directory name under /opt where the workshop app is cloned."
  type        = string
  default     = "oci-foundations-lab"
}

variable "lb_min_bandwidth_mbps" {
  description = "Minimum flexible load balancer bandwidth."
  type        = number
  default     = 10
}

variable "lb_max_bandwidth_mbps" {
  description = "Maximum flexible load balancer bandwidth."
  type        = number
  default     = 10
}
