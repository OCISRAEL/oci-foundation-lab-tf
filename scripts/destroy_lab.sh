#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

AUTO_APPROVE=""
if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
  AUTO_APPROVE="-auto-approve"
fi

if [[ -z "$AUTO_APPROVE" ]]; then
  cat <<'MSG'
This will destroy the OCI Foundations lab resources managed by this Terraform state.

The script runs destroy in stages so it can stop before subnet/VCN deletion if OCI
still has delayed VNIC/private-IP cleanup from the instance, load balancer, or
Cloud Shell ephemeral private network.
MSG
  read -r -p "Type 'destroy' to continue: " CONFIRM
  if [[ "$CONFIRM" != "destroy" ]]; then
    echo "Cancelled."
    exit 1
  fi
fi

echo
echo "Step 0: empty Object Storage bucket, if it still exists."
if BUCKET_NAME="$(terraform output -raw bucket_name 2>/dev/null)"; then
  oci os object bulk-delete -bn "$BUCKET_NAME" --force || true
else
  echo "Bucket output not available; skipping bucket empty step."
fi

echo
echo "Step 1: destroy app-facing resources first."
terraform destroy $AUTO_APPROVE \
  -target=oci_load_balancer_listener.app \
  -target=oci_load_balancer_backend.app \
  -target=oci_load_balancer_backend_set.app \
  -target=oci_load_balancer_load_balancer.app \
  -target=oci_core_volume_attachment.data \
  -target=oci_core_instance.app \
  -target=oci_core_volume.data

check_subnet_private_ips() {
  local name="$1"
  local output_name="$2"
  local state_address="$3"
  local subnet_id
  local count

  if ! subnet_id="$(terraform output -raw "$output_name" 2>/dev/null)"; then
    subnet_id="$(
      terraform state show -no-color "$state_address" 2>/dev/null |
        awk -F'= ' '/^[[:space:]]*id[[:space:]]*=/ {gsub(/"/, "", $2); print $2; exit}'
    )"
  fi

  if [[ -z "${subnet_id:-}" ]]; then
    echo "Subnet $name is no longer in Terraform state; skipping dependency check."
    return 0
  fi

  echo
  echo "Checking $name subnet private-IP dependencies..."
  if ! count="$(oci network private-ip list --subnet-id "$subnet_id" --all --query 'length(data)' --raw-output 2>/dev/null)"; then
    echo "Could not query private IPs for $name subnet. Stop here and retry later."
    return 2
  fi
  count="${count:-0}"

  if [[ "$count" != "0" ]]; then
    echo "$name subnet still has $count private IP dependency/dependencies:"
    oci network private-ip list \
      --subnet-id "$subnet_id" \
      --all \
      --query 'data[].{ip:"ip-address",displayName:"display-name",vnicId:"vnic-id"}' \
      --output table || true
    return 2
  fi

  echo "$name subnet is clear."
}

delete_console_histories() {
  local compartment_id
  local tmp_file
  local ids=()

  if ! compartment_id="$(terraform output -raw compartment_ocid 2>/dev/null)"; then
    compartment_id="$(
      terraform state show -no-color oci_identity_compartment.lab 2>/dev/null |
        awk -F'= ' '/^[[:space:]]*id[[:space:]]*=/ {gsub(/"/, "", $2); print $2; exit}'
    )"
  fi

  if [[ -z "${compartment_id:-}" ]]; then
    echo "Compartment is no longer in Terraform state; skipping console history cleanup."
    return 0
  fi

  echo
  echo "Step 1.5: delete unmanaged console history artifacts, if any."
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/oci-console-histories.XXXXXX")"
  if ! oci compute console-history list --compartment-id "$compartment_id" --all --output json > "$tmp_file"; then
    rm -f "$tmp_file"
    echo "Could not list console histories. Continuing; Terraform may still stop on compartment deletion."
    return 0
  fi

  while IFS= read -r id; do
    ids+=("$id")
  done < <(
    python3 - "$tmp_file" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    payload = json.load(fh)

for item in payload.get("data", []):
    item_id = item.get("id")
    if item_id:
        print(item_id)
PY
  )
  rm -f "$tmp_file"

  if [[ "${#ids[@]}" == "0" ]]; then
    echo "No console history artifacts found."
    return 0
  fi

  for id in "${ids[@]}"; do
    echo "Deleting console history: $id"
    oci compute console-history delete --instance-console-history-id "$id" --force || true
  done
}

BLOCKED=0
check_subnet_private_ips "public" public_subnet_ocid oci_core_subnet.public || BLOCKED=1
check_subnet_private_ips "private" private_subnet_ocid oci_core_subnet.private || BLOCKED=1

if [[ "$BLOCKED" == "1" ]]; then
  cat <<'MSG'

Stopping before full network destroy.

OCI still has subnet dependencies. Common causes:
- Cloud Shell ephemeral private network is still active.
- Deleted instance VNIC cleanup has not propagated yet.
- Load balancer/private IP cleanup has not propagated yet.

Action:
1. Disconnect Cloud Shell Ephemeral Private Network.
2. Wait until OCI releases the VNIC/private IP dependency.
3. Rerun this script:

   bash scripts/destroy_lab.sh

MSG
  exit 2
fi

delete_console_histories

echo
echo "Step 2: subnets are clear; destroy remaining Terraform resources."
terraform destroy $AUTO_APPROVE
