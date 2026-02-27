#!/usr/bin/env bash
set -euo pipefail

# Script to convert existing age-encrypted OIDC secrets to SOPS-encrypted YAML format
# Usage: convert-oidc-secrets [environment] [service-name]
#   e.g., convert-oidc-secrets prod grafana
#   or    convert-oidc-secrets prod all  (converts all OIDC secrets)

ENVIRONMENT="${1:-prod}"
SERVICE="${2:-all}"

# Detect git root
GIT_ROOT=$(git rev-parse --show-toplevel)
if [[ -z $GIT_ROOT ]]; then
  echo "Error: Not running from within a git repository"
  exit 1
fi

SECRETS_DIR="${GIT_ROOT}/.secrets/env/${ENVIRONMENT}/oidc"
IDENTITY_KEY="${GIT_ROOT}/.secrets/pub/master.pub"
SOPS_CONFIG="${GIT_ROOT}/.sops.yaml"

# Verify required files exist
if [[ ! -f $IDENTITY_KEY ]]; then
  echo "Error: Identity key not found at $IDENTITY_KEY"
  exit 1
fi

if [[ ! -f $SOPS_CONFIG ]]; then
  echo "Error: SOPS config not found at $SOPS_CONFIG"
  exit 1
fi

if [[ ! -d $SECRETS_DIR ]]; then
  echo "Error: Secrets directory not found at $SECRETS_DIR"
  exit 1
fi

convert_secret() {
  local service="$1"
  local age_file="${SECRETS_DIR}/${service}-oidc-client-secret.age"
  local yaml_file="${SECRETS_DIR}/${service}-oidc-client-secret.enc.yaml"

  if [[ ! -f $age_file ]]; then
    echo "Warning: $age_file not found, skipping..."
    return
  fi

  if [[ -f $yaml_file ]]; then
    echo "Skipping ${service}: $yaml_file already exists"
    return
  fi

  echo "Converting ${service}..."

  # Decrypt the age-encrypted secret
  secret=$(age --decrypt -i "$IDENTITY_KEY" "$age_file")

  # Encrypt directly via stdin so unencrypted content never touches filesystem
  echo "${service}-oidc-client-secret: $secret" | sops \
    --config "$SOPS_CONFIG" \
    --filename-override "$yaml_file" \
    --input-type yaml \
    --output-type yaml \
    -e /dev/stdin >"$yaml_file"

  echo "Created and encrypted $yaml_file"
}

if [[ $SERVICE == "all" ]]; then
  echo "Converting all OIDC secrets for environment: $ENVIRONMENT"
  echo "Git root: $GIT_ROOT"
  echo ""

  # Dynamically discover services from *-oidc-client-secret.age files
  shopt -s nullglob
  age_files=("${SECRETS_DIR}"/*-oidc-client-secret.age)
  shopt -u nullglob

  if [[ ${#age_files[@]} -eq 0 ]]; then
    echo "No OIDC secret files found in $SECRETS_DIR"
    exit 1
  fi

  for age_file in "${age_files[@]}"; do
    # Extract service name from filename
    filename=$(basename "$age_file")
    svc="${filename%-oidc-client-secret.age}"
    convert_secret "$svc"
  done
else
  echo "Converting OIDC secret for service: $SERVICE (environment: $ENVIRONMENT)"
  echo "Git root: $GIT_ROOT"
  echo ""
  convert_secret "$SERVICE"
fi

echo ""
echo "Done! SOPS-encrypted YAML files created in $SECRETS_DIR"
