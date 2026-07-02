# OCI Foundations Lab Terraform

Deploy the OCI Foundations lab with Terraform. The configuration creates a
dedicated compartment, network, private VM, Object Storage bucket, Autonomous
JSON Database, and a public load balancer for the lab application.

## Start Here: Deploy the Lab

These are the only steps needed for a clean, first-time deployment.

### 1. Clone the Repository Locally

Terraform runs from a local working directory. Clone this repository and run
every command in the rest of this guide from that local copy; do not try to
deploy from the GitHub website.

~~~bash
git clone https://github.com/OCISRAEL/oci-foundation-lab-tf.git
cd oci-foundation-lab-tf
~~~

If you already cloned the repository, open a terminal and change to that
directory before continuing.

### 2. Prerequisites

- Terraform 1.6 or later
- OCI CLI configured and authenticated with an API key
- OpenSSH (<code>ssh-keygen</code>) for the VM access key

For first-time OCI CLI installation, configuration, and API signing-key setup,
follow Oracle's [OCI CLI Quickstart](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm).

Python 3, <code>curl</code>, and <code>jq</code> are only needed for the optional
verification and database helper steps later in this document.

Your OCI CLI identity needs permission to create the resources listed in
[What Terraform Creates](#what-terraform-creates). The deployment creates
billable OCI resources; use the destroy instructions when you finish the lab.

### 3. Create Your Local Variables File

<code>terraform.tfvars</code> holds local settings and credentials, so it is deliberately
not committed to Git.

~~~bash
cp terraform.tfvars.example terraform.tfvars
bash scripts/prepare_ssh_key.sh
~~~

The SSH script creates <code>ssh/lab_ssh_key</code> and inserts its public key into
<code>terraform.tfvars</code>. Keep the private key safe; it is required to connect to
the private VM later.

Open the variables file and set the required values:

~~~bash
vi terraform.tfvars
~~~

Review these settings before continuing:

- <code>tenancy_ocid</code>: your tenancy's root OCID
- <code>region</code>: the OCI region in which to deploy
- <code>config_file_profile</code>: usually <code>DEFAULT</code>; change it only when your OCI CLI
  uses a different profile
- <code>compartment_name</code>: a new, meaningful lab compartment name
- <code>adb_admin_password</code>: a unique 12-30 character password with uppercase,
  lowercase, and a number. It must not contain <code>admin</code>, <code>@</code>, or a double quote.
- <code>ssh_public_key</code>: populated by the script above

### 4. Initialize, Plan, and Apply

Run these commands from the repository root:

~~~bash
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
~~~

Read the plan before applying it. The saved <code>tfplan</code> ensures the reviewed plan
is the one Terraform applies.

### 5. Create the JSON Collection

Terraform creates the Autonomous Database, but the application also needs its
MongoDB-compatible JSON collection. Run this after a successful <code>terraform apply</code>:

~~~bash
python3 -m venv .venv
.venv/bin/pip install pymongo certifi
.venv/bin/python scripts/create_adb_json_collection.py --terraform-dir .
~~~

The helper uses the Terraform outputs and the ADB admin password in your local
variables file to create <code>MY_COLLECTION</code>.

### 6. Confirm the Deployment

Terraform prints all outputs after a successful apply. The most useful ones
are:

~~~bash
terraform output
terraform output application_url
terraform output cloud_shell_ssh_command
terraform output bucket_name
~~~

The VM bootstrap takes a few minutes after Terraform completes. Check the
application URL with:

~~~bash
curl -I --max-time 15 "$(terraform output -raw application_url)"
~~~

A healthy application returns <code>HTTP/1.1 200 OK</code>. A temporary <code>502 Bad Gateway</code>
usually means cloud-init is still installing and starting the application;
wait a few minutes and retry.

### 7. Validate an Application Upload Before Destroying

Complete an upload and confirm that the object reached Object Storage before
you destroy the lab. You can use the browser, the CLI, or both.

**Upload through the application UI**

1. Open the application URL in a browser:

   ~~~bash
   terraform output -raw application_url
   ~~~

2. Use the upload form to select a small test file, such as <code>README.md</code>, and submit it.
3. Note the uploaded file name.

**Upload through the CLI**

~~~bash
curl -sS -i --max-time 60 \
  -F "myFile=@README.md;filename=agent-upload-verification.txt" \
  "$(terraform output -raw application_url)/upload"
~~~

**Verify the uploaded object in the OCI Console**

1. In the OCI Console, open **Object Storage & Archive Storage**, then **Buckets**.
2. Open the bucket named by <code>terraform output -raw bucket_name</code>.
3. Open **Objects**, refresh the list, and confirm the uploaded file name is present.

**Verify the uploaded object through the CLI**

~~~bash
oci os object list \
  -bn "$(terraform output -raw bucket_name)" \
  --prefix agent-upload-verification.txt \
  --fields name,size,timeCreated \
  --output json
~~~

## Destroy the Lab

Proceed only after the upload validation above is complete and you have saved
anything you want to keep. Destroying the lab permanently deletes the test
objects in its bucket as well as the Terraform-managed infrastructure.

Run destruction from the same directory, with the same OCI profile,
<code>terraform.tfvars</code>, and Terraform state used for deployment:

~~~bash
bash scripts/destroy_lab.sh
~~~

Type <code>destroy</code> when prompted. For non-interactive use only, add <code>--yes</code>:

~~~bash
bash scripts/destroy_lab.sh --yes
~~~

The helper empties the lab bucket, so any objects in it are permanently
deleted. It then removes the load balancer, VM, and volume first, checks for
delayed subnet dependencies, and destroys the remaining Terraform resources.

If it stops because a subnet still has a private-IP dependency:

1. Disconnect OCI Cloud Shell's Ephemeral Private Network, if one is active.
2. Wait for OCI to release the VNIC or load-balancer private IP.
3. Run the same destroy command again.

## What Terraform Creates

- Lab compartment
- VCN with public and private subnets
- Internet gateway, NAT gateway, service gateway, and route tables
- Private Oracle Linux compute instance
- Block volume attached to the instance and mounted at <code>/mnt/data</code>
- Dynamic group and IAM policy for Object Storage access
- Private Object Storage bucket
- Autonomous JSON Database
- Public load balancer on port <code>5000</code>
- Cloud-init bootstrap for the Flask application

By default, cloud-init clones the application from:

~~~hcl
app_source_repo_url = "https://github.com/OCISRAEL/oci-foundations-lab.git"
~~~

Override <code>app_source_repo_url</code> or <code>app_source_branch</code> in <code>terraform.tfvars</code>
only if you need to deploy a different application source.

## Advanced Workflows and Troubleshooting

### Recreate the Database Collection

To remove existing documents and recreate <code>MY_COLLECTION</code>:

~~~bash
.venv/bin/python scripts/create_adb_json_collection.py --terraform-dir . --recreate
~~~

If the collection helper in step 5 cannot create the collection, use Database
Actions:

1. Open the Autonomous Database named by the <code>autonomous_database_ocid</code> output.
2. Open **Database Actions** and choose **SQL**.
3. Run [scripts/create_collection.sql](./scripts/create_collection.sql).
4. Confirm that it reports <code>PL/SQL procedure successfully completed</code>.
5. Open **JSON** in Database Actions and verify <code>MY_COLLECTION</code> exists.

### Connect to the Private VM

The VM has no public IP. In OCI Cloud Shell, start Ephemeral Private Networking
on the Terraform private subnet, then use the generated SSH command together
with the private key in <code>ssh/lab_ssh_key</code>.

~~~bash
terraform output cloud_shell_ssh_command
~~~

### Diagnose an Unhealthy Application

Use these commands on the VM after connecting through Cloud Shell:

~~~bash
sudo systemctl status oci-foundations-bootstrap --no-pager
sudo journalctl -u oci-foundations-bootstrap -n 200 --no-pager
sudo tail -n 200 /var/log/oci-foundations-lab-bootstrap.log
sudo systemctl status oci-foundations-lab --no-pager
sudo journalctl -u oci-foundations-lab -n 100 --no-pager
sudo firewall-cmd --zone=public --list-ports
sudo ss -lntp | grep :5000
curl -I http://127.0.0.1:5000
df -h /mnt/data
~~~

After resolving a transient bootstrap problem, rerun it with:

~~~bash
sudo systemctl restart oci-foundations-bootstrap
~~~

### Common Terraform Problems

| Symptom | What to check |
| --- | --- |
| Terraform asks for required variables or reports no value for <code>tenancy_ocid</code> | Create <code>terraform.tfvars</code> from the example and run commands from the repository root. |
| <code>Invalid multi-line string</code> or similar HCL errors | Check every quoted value in <code>terraform.tfvars</code>, especially <code>tenancy_ocid</code>, has a closing quote. |
| OCI <code>401</code>, authentication, or authorization errors | Confirm <code>oci</code> works with <code>config_file_profile</code>, that its API key is readable, and that the profile tenancy matches <code>tenancy_ocid</code>. |
| <code>502 Bad Gateway</code> after apply | Wait for cloud-init to finish, then use the VM diagnostics above. |
| A1 capacity error | Try another availability domain, reduce the requested A1 resources, or override <code>instance_shape</code>, <code>instance_ocpus</code>, <code>instance_memory_gbs</code>, and optionally <code>image_ocid</code>. |
| Destroy stops on subnet dependencies | Disconnect Cloud Shell private networking, wait for OCI cleanup, and rerun <code>destroy_lab.sh</code>. |

Run a drift check at any time with:

~~~bash
terraform plan -detailed-exitcode
~~~

An exit code of <code>0</code> means no changes; <code>2</code> means Terraform detected changes.

## Repository Safety

Do not commit generated local files or credentials. <code>.gitignore</code> excludes:

- <code>terraform.tfvars</code> and other <code>.tfvars</code> files
- Terraform state, plans, crash logs, and <code>.terraform/</code>
- the generated <code>ssh/</code> directory and common private-key extensions
- local Python virtual environments

The ADB password and MongoDB connection string are stored in Terraform state
after deployment. Keep local state private. For shared or long-lived
environments, use encrypted, access-controlled remote state.
