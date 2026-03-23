#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(pwd)"
KEYS_DIR="$REPO_ROOT/.secrets/hosts"

# Cleanup tracking
CLEANUP_PATHS=()

cleanup() {
    for path in "${CLEANUP_PATHS[@]}"; do
        rm -rf "$path"
    done
}
trap cleanup EXIT

register_cleanup() {
    CLEANUP_PATHS+=("$1")
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

usage() {
    cat >&2 <<EOF
Usage: $0 <hostname> [options]

Re-encrypt the disk passphrase with TPM2 + Tang on a running host.

This is a post-install operation. The passphrase is decrypted from the
age-encrypted source of truth (root-disk-key.age) and re-encrypted on
the target host using Clevis with TPM2 OR (2-of-N Tang servers).

Arguments:
  hostname    The name of the host configuration in the flake

Options:
  --dry-run   Show what would be done without executing
  --help      Show this help message

The script will:
  1. Decrypt the disk passphrase from the age-encrypted key (via YubiKey)
  2. Discover Tang servers from the flake configuration
  3. SSH to the target host and encrypt with Clevis (TPM2 + Tang SSS)
  4. Write the JWE to .secrets/hosts/<hostname>/zroot-key.jwe
  5. Commit the updated JWE to git
EOF
    exit 1
}

validate_hostname() {
    local hostname="$1"
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Invalid hostname '$hostname': must contain only alphanumeric characters, hyphens, and underscores"
    fi
}

validate_host_exists() {
    local hostname="$1"
    if ! nix eval --json .#hosts --apply "builtins.hasAttr \"$hostname\"" 2>/dev/null | jq -r '.' 2>/dev/null | grep -q "true"; then
        error "Host '$hostname' not found in flake configuration"
    fi
}

get_host_ip() {
    local hostname="$1"

    local ip
    ip=$(nix eval --json .#hosts --apply "hosts: (builtins.getAttr \"$hostname\" hosts).ipv4" 2>/dev/null | jq -r '.[0]' 2>/dev/null)

    if [[ -z "$ip" || "$ip" == "null" ]]; then
        error "Could not resolve IP for host '$hostname' from flake configuration"
    fi

    echo "$ip"
}

decrypt_disk_password() {
    local hostname="$1"
    local disk_key_file="$KEYS_DIR/$hostname/root-disk-key.age"

    if [[ ! -f "$disk_key_file" ]]; then
        error "Disk encryption key not found: $disk_key_file. Run 'nix-flake-provision-keys $hostname' first."
    fi

    log "Decrypting disk passphrase from age-encrypted key..."

    local yubikey_identity_file
    yubikey_identity_file=$(mktemp)
    register_cleanup "$yubikey_identity_file"

    age-plugin-yubikey -i > "$yubikey_identity_file"

    local password
    if password=$(age -d -i "$yubikey_identity_file" "$disk_key_file" 2>/dev/null); then
        log "  ✓ Disk passphrase decrypted"
        echo "$password"
    else
        error "Failed to decrypt disk encryption key"
    fi
}

discover_tang_servers() {
    local hostname="$1"

    local tang_ips=()
    mapfile -t tang_ips < <(
        nix eval --json .#hosts \
            --apply "hosts: builtins.mapAttrs (name: host: { inherit (host) features ipv4; }) (builtins.removeAttrs hosts [\"$hostname\"])" 2>/dev/null |
        jq -r 'to_entries[] | select(.value.features | contains(["unlock"])) | .value.ipv4[0]' 2>/dev/null |
        sort
    )

    # Filter out empty entries
    for ip in "${tang_ips[@]}"; do
        [[ -n "$ip" ]] && echo "$ip"
    done
}

main() {
    local hostname=""
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --help)
                usage
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                if [[ -z "$hostname" ]]; then
                    hostname="$1"
                else
                    error "Too many arguments"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$hostname" ]]; then
        usage
    fi

    validate_hostname "$hostname"
    validate_host_exists "$hostname"

    local host_dir="$KEYS_DIR/$hostname"
    local jwe_file="$host_dir/zroot-key.jwe"

    # Resolve target IP from flake
    log "Resolving target IP for $hostname..."
    local target_ip
    target_ip=$(get_host_ip "$hostname")
    log "  ✓ Target: root@$target_ip"

    # Decrypt passphrase from age-encrypted source of truth
    local disk_password
    disk_password=$(decrypt_disk_password "$hostname")

    # Discover Tang servers
    log "Discovering Tang servers..."

    local valid_ips=()
    mapfile -t valid_ips < <(discover_tang_servers "$hostname")

    if [[ ${#valid_ips[@]} -eq 0 ]]; then
        error "No Tang servers found (no hosts with 'unlock' role). Cannot generate TPM2+Tang JWE."
    fi

    log "  Found ${#valid_ips[@]} Tang servers:"
    for ip in "${valid_ips[@]}"; do
        log "    - http://$ip:7654"
    done

    # Build Clevis config: TPM2 OR (2-of-N Tang servers)
    local tang_threshold=$(( ${#valid_ips[@]} < 2 ? ${#valid_ips[@]} : 2 ))

    local tang_pins
    tang_pins=$(printf '%s\n' "${valid_ips[@]}" | jq -R '{"url": "http://\(.):7654"}' | jq -s '.')

    local clevis_config
    clevis_config=$(jq -n \
        --argjson tang_pins "$tang_pins" \
        --argjson tang_threshold "$tang_threshold" \
        '{
            "t": 1,
            "pins": {
                "tpm2": {},
                "sss": {
                    "t": $tang_threshold,
                    "pins": {
                        "tang": $tang_pins
                    }
                }
            }
        }'
    )

    log "Clevis config: TPM2 OR ($tang_threshold-of-${#valid_ips[@]} Tang)"

    if [[ "$dry_run" == true ]]; then
        log "[DRY RUN] Would SSH to root@$target_ip and encrypt with Clevis"
        log "[DRY RUN] Clevis config:"
        echo "$clevis_config" | jq . >&2
        log "[DRY RUN] Would write JWE to: $jwe_file"
        log "[DRY RUN] No changes made"
        return 0
    fi

    # Encrypt on the target host — TPM2 binding requires the actual hardware
    log "Encrypting passphrase on $hostname via SSH (TPM2 + Tang)..."

    mkdir -p "$host_dir"

    # $clevis_config is intentionally expanded locally before SSH sends it
    # shellcheck disable=SC2029
    if ! echo -n "$disk_password" | ssh "root@$target_ip" "clevis encrypt sss '$clevis_config' -y" > "$jwe_file"; then
        rm -f "$jwe_file"
        error "Clevis encryption failed on $hostname"
    fi

    # Verify output
    if [[ ! -s "$jwe_file" ]]; then
        rm -f "$jwe_file"
        error "Clevis produced empty output"
    fi

    log "  ✓ JWE generated: $jwe_file ($(stat -c%s "$jwe_file") bytes)"

    # Commit to git
    log "Committing updated JWE to git..."
    if ! git add "$jwe_file"; then
        error "Failed to stage JWE file"
    fi

    if git diff --cached --quiet; then
        log "  ✓ No changes to commit (JWE unchanged)"
    else
        if ! git commit -m "feat(secrets): update TPM2+Tang disk key for $hostname

Re-encrypted disk passphrase with TPM2 OR ($tang_threshold-of-${#valid_ips[@]} Tang servers)."; then
            error "Failed to commit JWE"
        fi
        log "  ✓ JWE committed to git"
    fi

    log "✓ Disk key rotation complete for $hostname"
}

main "$@"
