#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(pwd)"
KEYS_DIR="$REPO_ROOT/.secrets/hosts"
KEY_TYPES=("ed25519" "rsa")

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

Provision SSH host keys and disk encryption secrets for a NixOS host.

Arguments:
  hostname    The name of the host configuration in the flake

Options:
  --disk-password PASSWORD    Disk encryption password (prompts if not provided)
  --force-regenerate-jwe      Regenerate Tang JWE even if it already exists
  --help                      Show this help message

The script will:
  1. Generate and encrypt SSH host keys if they don't exist
  2. Generate and encrypt disk encryption key if it doesn't exist
  3. Generate Tang-only Clevis JWE for boot-time unlock (if Tang servers exist)
  4. Run agenix generate to create age keys from host keys
  5. Run agenix rekey to encrypt secrets for the new host
  6. Commit the generated keys and secrets to git

Note: The JWE uses Tang-only encryption (no TPM2) for bootstrap. After install,
run 'update-tang-disk-keys' on the live host to add TPM2 binding.
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

get_yubikey_recipient() {
    log "Discovering YubiKey age recipient..."

    local recipient
    if ! recipient=$(age-plugin-yubikey -l | grep '^age1yubikey1'); then
        error "No YubiKey age recipient found. Make sure your YubiKey is inserted and configured for age encryption."
    fi

    if [[ -z "$recipient" ]]; then
        error "Failed to extract YubiKey age recipient"
    fi

    log "Found YubiKey recipient: $recipient"
    echo "$recipient"
}

get_or_prompt_disk_password() {
    local provided_password="$1"

    if [[ -n "$provided_password" ]]; then
        echo "$provided_password"
        return 0
    fi

    echo -n "Enter disk encryption password (or press Enter to generate random): " >&2
    read -r -s password
    echo >&2

    if [[ -z "$password" ]]; then
        password=$(openssl rand -base64 32)
        log "Generated random disk encryption password"
    fi

    echo "$password"
}

generate_ssh_host_keys() {
    local hostname="$1"
    local age_recipient="$2"
    local host_dir="$KEYS_DIR/$hostname"

    mkdir -p "$host_dir"

    log "Generating SSH host keys for: $hostname"

    local temp_key_dir
    temp_key_dir=$(mktemp -d)
    register_cleanup "$temp_key_dir"

    for key_type in "${KEY_TYPES[@]}"; do
        local key_file="ssh_host_${key_type}_key"
        local pub_file="${key_file}.pub"
        local age_file="$host_dir/${key_file}.age"
        local temp_key="$temp_key_dir/${key_file}"

        if [[ -f "$age_file" ]]; then
            log "  ✓ Key already exists: $hostname/$key_file"
            continue
        fi

        log "  Generating $key_type key for $hostname"

        local keygen_args=(-t "$key_type" -f "$temp_key" -N "" -C "root@$hostname")
        [[ "$key_type" == "rsa" ]] && keygen_args+=(-b 4096)

        if ! ssh-keygen "${keygen_args[@]}" >/dev/null 2>&1; then
            log "  ✗ Failed to generate: $hostname/$key_file"
            continue
        fi

        log "  ✓ Generated: $hostname/$key_file"

        if age -r "$age_recipient" < "$temp_key" > "$age_file" 2>/dev/null; then
            chmod 600 "$age_file"
            log "  ✓ Encrypted: $hostname/$key_file"
        else
            log "  ✗ Failed to encrypt: $hostname/$key_file"
            rm -f "$age_file"
            continue
        fi

        if cp "${temp_key}.pub" "$host_dir/$pub_file" 2>/dev/null; then
            chmod 644 "$host_dir/$pub_file"
            log "  ✓ Stored public key: $hostname/$pub_file"
        else
            log "  ✗ Failed to store public key: $hostname/$pub_file"
        fi

        rm -f "$temp_key" "${temp_key}.pub"
    done

    # Verify at least one key exists (either pre-existing or newly generated)
    local key_count=0
    for age_file in "$host_dir"/ssh_host_*_key.age; do
        [[ -f "$age_file" ]] && key_count=$((key_count + 1))
    done

    if [[ $key_count -eq 0 ]]; then
        error "No SSH host keys available for $hostname after generation attempt"
    fi

    log "  ✓ SSH host keys ready ($key_count keys)"
}

decrypt_disk_password() {
    local hostname="$1"
    local disk_key_file="$KEYS_DIR/$hostname/root-disk-key.age"

    if [[ ! -f "$disk_key_file" ]]; then
        error "Disk encryption key not found: $disk_key_file"
    fi

    log "  Decrypting disk encryption key from age..."

    local yubikey_identity_file
    yubikey_identity_file=$(mktemp)
    register_cleanup "$yubikey_identity_file"

    age-plugin-yubikey -i > "$yubikey_identity_file"

    local password
    if password=$(age -d -i "$yubikey_identity_file" "$disk_key_file" 2>/dev/null); then
        log "  ✓ Disk encryption key decrypted"
        echo "$password"
    else
        error "Failed to decrypt disk encryption key"
    fi
}

generate_tang_jwe() {
    local hostname="$1"
    local disk_password="$2"
    local host_dir="$KEYS_DIR/$hostname"
    local jwe_file="$host_dir/zroot-key.jwe"

    if [[ -f "$jwe_file" ]]; then
        log "  ✓ Tang JWE already exists: $jwe_file"
        return 0
    fi

    log "  Discovering Tang servers..."

    local tang_ips=()
    mapfile -t tang_ips < <(
        nix eval --json .#hosts \
            --apply "hosts: builtins.mapAttrs (name: host: { inherit (host) roles ipv4; }) (builtins.removeAttrs hosts [\"$hostname\"])" 2>/dev/null |
        jq -r 'to_entries[] | select(.value.roles | contains(["unlock"])) | .value.ipv4[0]' 2>/dev/null |
        sort
    )

    # Filter out empty entries
    local valid_ips=()
    for ip in "${tang_ips[@]}"; do
        [[ -n "$ip" ]] && valid_ips+=("$ip")
    done

    if [[ ${#valid_ips[@]} -eq 0 ]]; then
        log "  No Tang servers found (no hosts with 'unlock' role), skipping JWE generation"
        return 0
    fi

    log "  Found ${#valid_ips[@]} Tang servers:"
    for ip in "${valid_ips[@]}"; do
        log "    - http://$ip:7654"
    done

    # Tang-only SSS for bootstrap (no TPM2 — add TPM2 post-install via update-tang-disk-keys)
    local threshold=$(( ${#valid_ips[@]} < 2 ? ${#valid_ips[@]} : 2 ))

    local tang_pins
    tang_pins=$(printf '%s\n' "${valid_ips[@]}" | jq -R '{"url": "http://\(.):7654"}' | jq -s '.')

    local clevis_config
    clevis_config=$(jq -n \
        --argjson tang_pins "$tang_pins" \
        --argjson threshold "$threshold" \
        '{
            "t": $threshold,
            "pins": {
                "tang": $tang_pins
            }
        }'
    )

    log "  Encrypting disk password with Clevis (Tang-only, threshold=$threshold)..."

    if echo -n "$disk_password" | clevis encrypt sss "$clevis_config" -y > "$jwe_file"; then
        log "  ✓ Tang JWE generated: zroot-key.jwe"
    else
        rm -f "$jwe_file"
        error "Failed to encrypt disk password with Clevis"
    fi
}

generate_disk_key() {
    local hostname="$1"
    local age_recipient="$2"
    local disk_password="$3"
    local host_dir="$KEYS_DIR/$hostname"
    local disk_key_file="$host_dir/root-disk-key.age"

    if [[ -f "$disk_key_file" ]]; then
        log "  ✓ Disk encryption key already exists: $disk_key_file"
        return 0
    fi

    if [[ -z "$disk_password" ]]; then
        error "Disk password is required but was not provided"
    fi

    if echo -n "$disk_password" | age -r "$age_recipient" > "$disk_key_file" 2>/dev/null; then
        chmod 600 "$disk_key_file"
        log "  ✓ Encrypted and stored disk key: root-disk-key.age"
    else
        rm -f "$disk_key_file"
        error "Failed to encrypt disk key"
    fi
}

main() {
    local hostname=""
    local disk_password=""
    local force_regenerate_jwe=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --disk-password)
                disk_password="$2"
                shift 2
                ;;
            --force-regenerate-jwe)
                force_regenerate_jwe=true
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

    log "Provisioning secrets for $hostname"

    local age_recipient
    age_recipient=$(get_yubikey_recipient)

    # Generate SSH host keys if needed
    local host_dir="$KEYS_DIR/$hostname"
    if [[ ! -d "$host_dir" ]] || [[ -z "$(ls -A "$host_dir" 2>/dev/null)" ]]; then
        log "  Host keys not found, generating..."
        generate_ssh_host_keys "$hostname" "$age_recipient"
    else
        log "  ✓ SSH host keys already exist"
    fi

    # Generate disk encryption key if needed
    local resolved_password=""
    local disk_key_generated=false
    local disk_key_file="$host_dir/root-disk-key.age"
    if [[ ! -f "$disk_key_file" ]]; then
        log "  Disk encryption key not found, generating..."
        resolved_password=$(get_or_prompt_disk_password "$disk_password")
        generate_disk_key "$hostname" "$age_recipient" "$resolved_password"
        disk_key_generated=true
    else
        log "  ✓ Disk encryption key already exists"
    fi

    # Generate Tang JWE for boot-time unlock
    # Regenerate JWE if:
    # 1. JWE doesn't exist
    # 2. Disk key was just generated (passwords must match)
    # 3. User explicitly requested regeneration
    local jwe_file="$host_dir/zroot-key.jwe"
    if [[ ! -f "$jwe_file" ]]; then
        log "  Tang JWE not found, generating..."
        # Decrypt password from age if we don't already have it
        if [[ -z "$resolved_password" ]]; then
            resolved_password=$(decrypt_disk_password "$hostname")
        fi
        generate_tang_jwe "$hostname" "$resolved_password"
    elif [[ "$disk_key_generated" == true ]] || [[ "$force_regenerate_jwe" == true ]]; then
        if [[ "$disk_key_generated" == true ]]; then
            log "  Disk key was regenerated, updating Tang JWE to match..."
        else
            log "  Force-regenerating Tang JWE..."
        fi
        # Decrypt password from age if we don't already have it
        if [[ -z "$resolved_password" ]]; then
            resolved_password=$(decrypt_disk_password "$hostname")
        fi
        rm -f "$jwe_file"
        generate_tang_jwe "$hostname" "$resolved_password"
    else
        log "  ✓ Tang JWE already exists"
    fi

    # Run agenix generate and rekey
    log "  Running agenix generate..."
    if ! agenix generate; then
        error "Failed to generate age keys with agenix"
    fi
    log "  ✓ Age keys generated from host keys"

    log "  Running agenix rekey..."
    if ! agenix rekey; then
        error "Failed to rekey secrets with agenix"
    fi
    log "  ✓ Secrets rekeyed for all hosts"

    # Commit changes to git
    log "  Committing keys and secrets to git..."
    if ! git add "$KEYS_DIR/$hostname" .secrets/; then
        error "Failed to stage keys and secrets"
    fi

    if git diff --cached --quiet; then
        log "  ✓ No changes to commit (already up to date)"
    else
        if ! git commit -m "feat(secrets): provision host keys and secrets for $hostname

Generated SSH host keys and age keys for new host $hostname.
Rekeyed all secrets to include the new host."; then
            error "Failed to commit keys and secrets to git"
        fi
        log "  ✓ Keys and secrets committed to git"
    fi

    log "✓ Host provisioning completed"
}

main "$@"
