#!/usr/bin/env bash
set -euo pipefail

# Generate certificates for Vault raft cluster
# This creates a CA and individual certificates for each vault node
#
# Usage: ./generate-vault-certs.sh [environment]
# Example: ./generate-vault-certs.sh dev
# If no environment specified, will generate for all environments

ENVIRONMENT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CERT_DIR="$(mktemp -d)"

echo "Working in: $CERT_DIR"
echo "Repository root: $REPO_ROOT"

cd "$CERT_DIR"

# Use nix run for openssl
OPENSSL="nix run nixpkgs#openssl --"

# Get vault hosts from flake for specified environment
get_vault_hosts() {
  local env="$1"

  (cd "$REPO_ROOT" && nix eval --json .#hosts --apply 'hosts: builtins.mapAttrs (name: host: { inherit (host) system roles environment ipv4; }) hosts' 2>/dev/null) |
    jq -r "to_entries | map(select(.value.environment == \"$env\" and (.value.roles | contains([\"vault\"])))) | .[] | \"\(.key) \(.value.ipv4[0])\""
}

# Get environment domain
get_environment_domain() {
  local env="$1"
  (cd "$REPO_ROOT" && nix eval --raw .#environments.$env.domain 2>/dev/null) || echo "local"
}

# Function to generate node certificate
generate_node_cert() {
  local hostname="$1"
  local ip="$2"
  local domain="$3"
  local env="$4"

  echo "Generating certificate for $hostname ($ip) in domain $domain"

  # Generate private key
  $OPENSSL genpkey -algorithm RSA -out "vault-${hostname}-key.pem"

  # Create certificate signing request
  $OPENSSL req -new -key "vault-${hostname}-key.pem" -out "vault-${hostname}.csr" \
    -subj "/C=US/ST=Local/L=Local/O=Vault/CN=${hostname}"

  # Create certificate extensions
  cat >"vault-${hostname}.ext" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${hostname}
DNS.2 = ${hostname}.${domain}
DNS.3 = vault.${domain}
IP.1 = ${ip}
IP.2 = 127.0.0.1
EOF

  # Sign the certificate using the environment-specific CA
  $OPENSSL x509 -req -in "vault-${hostname}.csr" -CA "$env/vault-ca.pem" -CAkey "$env/vault-ca-key.pem" \
    -out "vault-${hostname}.pem" -days 365 -extfile "vault-${hostname}.ext" \
    -CAcreateserial

  # Clean up CSR and extensions file
  rm "vault-${hostname}.csr" "vault-${hostname}.ext"
}

# Generate certificates for vault nodes
if [ -n "$ENVIRONMENT" ]; then
  environments=("$ENVIRONMENT")
else
  # Get all environments that have vault hosts
  readarray -t environments < <((cd "$REPO_ROOT" && nix eval --json .#hosts --apply 'hosts: builtins.mapAttrs (name: host: { inherit (host) system roles environment ipv4; }) hosts' 2>/dev/null | jq -r 'to_entries | map(select(.value.roles | contains(["vault"]))) | map(.value.environment) | unique | .[]'))
fi

for env in "${environments[@]}"; do
  echo "=== Processing environment: $env ==="

  domain=$(get_environment_domain "$env")
  echo "Domain for $env: $domain"

  # Create environment-specific directory
  mkdir -p "$env"

  # Generate CA for this environment
  $OPENSSL genpkey -algorithm RSA -out "$env/vault-ca-key.pem"
  $OPENSSL req -new -x509 -key "$env/vault-ca-key.pem" -out "$env/vault-ca.pem" -days 3650 \
    -subj "/C=US/ST=Local/L=Local/O=Vault CA $env/CN=Vault Root CA ($env)"

  # Generate certificates for each vault node in this environment
  while IFS=' ' read -r hostname ip; do
    [ -n "$hostname" ] && generate_node_cert "$hostname" "$ip" "$domain" "$env"
    # Move generated files to environment directory
    [ -f "vault-${hostname}.pem" ] && mv "vault-${hostname}.pem" "$env/"
    [ -f "vault-${hostname}-key.pem" ] && mv "vault-${hostname}-key.pem" "$env/"
  done < <(get_vault_hosts "$env")

  echo "Generated certificates for $env:"
  ls -la "$CERT_DIR/$env/"
  echo ""
done

echo "All certificates generated in: $CERT_DIR"
echo ""
echo "Next steps:"
echo "1. Copy certificates to .secrets/services/vault/[environment]/ directories"
echo "2. Encrypt them with: agenix-rekey edit .secrets/services/vault/[environment]/[file].age"
echo "3. Deploy to the vault cluster: colmena apply --on @vault"
echo ""
echo "Example commands:"
for env in "${environments[@]}"; do
  echo "# For $env environment:"
  echo "mkdir -p .secrets/services/vault/$env"
  echo "cp $CERT_DIR/$env/* .secrets/services/vault/$env/"
  echo ""
done
