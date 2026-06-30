#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

KEY_NAME="${KEY_NAME:-lab_ssh_key}"
KEY_DIR="${KEY_DIR:-${TERRAFORM_DIR}/ssh}"
TFVARS_FILE="${TFVARS_FILE:-${TERRAFORM_DIR}/terraform.tfvars}"
TFVARS_EXAMPLE="${TERRAFORM_DIR}/terraform.tfvars.example"

usage() {
  cat <<USAGE
Usage: bash scripts/prepare_ssh_key.sh [options]

Creates or reuses an SSH key pair for the lab VM and writes the public key into
terraform.tfvars as ssh_public_key.

Options:
  --key-name NAME       Key file basename. Default: lab_ssh_key
  --key-dir PATH        Directory for the key pair. Default: ./ssh
  --tfvars-file PATH    tfvars file to update. Default: ./terraform.tfvars
  -h, --help            Show this help.

Environment overrides:
  KEY_NAME, KEY_DIR, TFVARS_FILE
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key-name)
      KEY_NAME="$2"
      shift 2
      ;;
    --key-dir)
      KEY_DIR="$2"
      shift 2
      ;;
    --tfvars-file)
      TFVARS_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

KEY_PATH="${KEY_DIR}/${KEY_NAME}"
PUB_KEY_PATH="${KEY_PATH}.pub"

mkdir -p "${KEY_DIR}"
chmod 700 "${KEY_DIR}"

if [[ -f "${KEY_PATH}" && -f "${PUB_KEY_PATH}" ]]; then
  echo "Reusing existing SSH key pair:"
  echo "  private: ${KEY_PATH}"
  echo "  public : ${PUB_KEY_PATH}"
elif [[ -f "${KEY_PATH}" && ! -f "${PUB_KEY_PATH}" ]]; then
  echo "Private key exists but public key is missing; recreating the public key."
  ssh-keygen -y -f "${KEY_PATH}" > "${PUB_KEY_PATH}"
  chmod 644 "${PUB_KEY_PATH}"
elif [[ ! -f "${KEY_PATH}" && -f "${PUB_KEY_PATH}" ]]; then
  cat >&2 <<ERROR
Public key exists but private key is missing:
  ${PUB_KEY_PATH}

Terraform can inject the public key, but you will not be able to SSH without
the matching private key. Move the matching private key to:
  ${KEY_PATH}

Or delete the orphan public key and rerun this script to create a new pair.
ERROR
  exit 1
else
  echo "Creating new SSH key pair:"
  echo "  private: ${KEY_PATH}"
  echo "  public : ${PUB_KEY_PATH}"
  ssh-keygen -t ed25519 -f "${KEY_PATH}" -N "" -C "oci-foundations-lab"
fi

chmod 600 "${KEY_PATH}"
chmod 644 "${PUB_KEY_PATH}"

if [[ ! -f "${TFVARS_FILE}" ]]; then
  if [[ ! -f "${TFVARS_EXAMPLE}" ]]; then
    echo "Missing ${TFVARS_FILE} and ${TFVARS_EXAMPLE}; cannot prepare tfvars." >&2
    exit 1
  fi
  cp "${TFVARS_EXAMPLE}" "${TFVARS_FILE}"
  echo "Created ${TFVARS_FILE} from terraform.tfvars.example."
fi

PUBLIC_KEY="$(tr -d '\n' < "${PUB_KEY_PATH}")"
TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/terraform.tfvars.XXXXXX")"

awk -v pub="${PUBLIC_KEY}" '
  BEGIN { updated = 0 }
  /^[[:space:]]*ssh_public_key[[:space:]]*=/ {
    if (updated == 0) {
      print "ssh_public_key = \"" pub "\""
      updated = 1
    }
    next
  }
  { print }
  END {
    if (updated == 0) {
      print ""
      print "ssh_public_key = \"" pub "\""
    }
  }
' "${TFVARS_FILE}" > "${TMP_FILE}"

mv "${TMP_FILE}" "${TFVARS_FILE}"
chmod 600 "${TFVARS_FILE}"

cat <<DONE

Updated:
  ${TFVARS_FILE}

Injected:
  ssh_public_key = contents of ${PUB_KEY_PATH}

Keep this private key for OCI Cloud Shell SSH:
  ${KEY_PATH}

After terraform apply, connect from OCI Cloud Shell private networking with:
  ssh -i ${KEY_PATH} opc@<instance_private_ip>

Next required tfvars values to review:
  tenancy_ocid
  compartment_name
  adb_admin_password
  config_file_profile, if your OCI CLI profile is not DEFAULT
DONE
