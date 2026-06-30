# OCI Foundations Lab Terraform

Terraform automation for the OCI Foundations lab.

This repository provisions a complete workshop environment on Oracle Cloud
Infrastructure and bootstraps the Flask application from the online app
repository. The local app source and manual screenshot guide are not required
in this repo.

## What Terraform Creates

- Lab compartment
- VCN with public and private subnets
- Internet gateway, NAT gateway, service gateway, and route tables
- Private Oracle Linux compute instance
- Block volume attached to the instance and mounted at `/mnt/data`
- Dynamic group and IAM policy for Object Storage access
- Private Object Storage bucket
- Autonomous JSON Database
- Public load balancer on port `5000`
- Cloud-init bootstrap for the Flask application

The app source is cloned on the VM from:

```hcl
app_source_repo_url = "https://github.com/OCISRAEL/oci-foundations-lab.git"
```

Override `app_source_repo_url` in `terraform.tfvars` if you want to point the
lab at another app repository.

## Prerequisites

- Terraform
- OCI CLI already configured with an API key
- Python 3 for the post-deployment collection helper
- `jq` and `curl` for optional validation commands

You still need to set `tenancy_ocid` in `terraform.tfvars`; Terraform uses it as
the root compartment OCID.

## Quick Start

After cloning this repository from GitHub, `terraform.tfvars` will not exist.
Only `terraform.tfvars.example` is committed.

Create your working variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Then prepare an SSH key and inject its public key into `terraform.tfvars`:

```bash
bash scripts/prepare_ssh_key.sh
```

The SSH script is safe to run even if `terraform.tfvars` does not exist; it will
copy `terraform.tfvars.example` for you. The explicit `cp` command above is
shown so the required file is clear for new users.

Edit the required values before running `terraform plan` or `terraform apply`:

```bash
vi terraform.tfvars
```

At minimum, review:

- `tenancy_ocid`
- `region`
- `config_file_profile`
- `compartment_name`
- `adb_admin_password`
- `ssh_public_key`, filled by `prepare_ssh_key.sh`

Deploy:

```bash
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

## Post Deployment

Terraform creates the Autonomous Database. After `terraform apply`, create and
verify the MongoDB-compatible JSON collection:

```bash
python3 -m venv .venv
.venv/bin/pip install pymongo certifi
.venv/bin/python scripts/create_adb_json_collection.py --terraform-dir .
```

For a clean rebuild where the collection already exists and should be emptied:

```bash
.venv/bin/python scripts/create_adb_json_collection.py --terraform-dir . --recreate
```

`--recreate` deletes existing documents in that collection.

Read useful outputs:

```bash
terraform output
terraform output application_url
terraform output cloud_shell_ssh_command
terraform output bucket_name
```

Probe the app URL:

```bash
curl -I --max-time 15 "$(terraform output -raw application_url)"
```

Expected healthy result:

```text
HTTP/1.1 200 OK
```

If the app returns `502 Bad Gateway`, wait a few minutes and retry. Cloud-init
needs time to install packages, open the Linux firewall, mount the block volume,
and start the Flask service.

Run an end-to-end upload test:

```bash
curl -sS -i --max-time 60 \
  -F "myFile=@README.md;filename=agent-upload-verification.txt" \
  "$(terraform output -raw application_url)/upload"
```

Verify the object exists:

```bash
oci os object list \
  -bn "$(terraform output -raw bucket_name)" \
  --prefix agent-upload-verification.txt \
  --fields name,size,timeCreated \
  --output json
```

Optional final drift check:

```bash
terraform plan -detailed-exitcode
```

Expected result:

```text
No changes. Your infrastructure matches the configuration.
```

## Optional VM Diagnostics

Use this only if the app stays unhealthy.

1. Open OCI Cloud Shell.
2. Start ephemeral private networking on the Terraform private subnet.
3. SSH to the private VM using the generated key and the
   `cloud_shell_ssh_command` output.

On the VM, run:

```bash
sudo systemctl status oci-foundations-bootstrap --no-pager
sudo journalctl -u oci-foundations-bootstrap -n 200 --no-pager
sudo tail -n 200 /var/log/oci-foundations-lab-bootstrap.log
sudo systemctl status oci-foundations-lab --no-pager
sudo journalctl -u oci-foundations-lab -n 100 --no-pager
sudo firewall-cmd --zone=public --list-ports
sudo ss -lntp | grep :5000
curl -I http://127.0.0.1:5000
df -h /mnt/data
```

To rerun bootstrap after fixing a transient issue:

```bash
sudo systemctl restart oci-foundations-bootstrap
```

## Manual Collection Fallback

If the Python helper cannot create the collection, use Database Actions:

1. Open the created Autonomous Database from the `autonomous_database_ocid`
   output.
2. Open **Database Actions** and choose **SQL**.
3. Run [scripts/create_collection.sql](./scripts/create_collection.sql).
4. Confirm the result says `PL/SQL procedure successfully completed`.
5. In Database Actions, open **JSON** and verify `MY_COLLECTION` exists.

## Destroy

Use the staged destroy helper:

```bash
bash scripts/destroy_lab.sh --yes
```

The helper empties the bucket, destroys app-facing resources first, checks for
OCI subnet private-IP dependencies, deletes unmanaged console history artifacts,
and then destroys the remaining resources.

If OCI still holds a VNIC/private-IP reference after instance termination, wait
and rerun the same script later.

## Repository Safety

Do not commit generated local files or credentials.

Ignored files include:

- `terraform.tfvars`
- `terraform.tfstate`
- `terraform.tfstate.*`
- `tfplan*`
- `.terraform/`
- `.venv/`
- `ssh/`
- private keys such as `*.pem`, `*.key`, `id_rsa`, and `id_ed25519`

The ADB admin password and generated MongoDB connection string are stored in
Terraform state during a real deployment. Keep local state private, or move it
to encrypted, access-controlled remote state for anything beyond a lab.

## Notes

- The VM is private. Use OCI Cloud Shell ephemeral private networking with the
  private subnet, then SSH using the `cloud_shell_ssh_command` output.
- Developer-tier Autonomous AI Database requires `adb_compute_count = 4` and
  `adb_data_storage_size_in_gb = 20`.
- If `VM.Standard.A1.Flex` capacity is unavailable in your region or
  availability domain, override `instance_shape`, `instance_ocpus`,
  `instance_memory_gbs`, and optionally `image_ocid`.
