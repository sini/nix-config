#!/usr/bin/env bash
set -euo pipefail

# Configuration
REPO_ROOT="$(pwd)"
KEYS_DIR="$REPO_ROOT/.secrets/host-keys"

# SSH key types to generate
KEY_TYPES=("ed25519" "rsa")

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

usage() {
    echo "Usage: $0 <hostname> <target-ip> [disk-encryption-password]"
    echo
    echo "Install NixOS on a remote host using nixos-anywhere with automated provisioning."
    echo
    echo "Arguments:"
    echo "  hostname                    The name of the host configuration in the flake"
    echo "  target-ip                   IP address of the target host"
    echo "  disk-encryption-password    Optional disk encryption password (will prompt if not provided)"
    echo
    echo "Options:"
    echo "  -i, --identity FILE        SSH identity file to use for authentication"
    echo "  --disko-mode MODE          Disko mode (format, mount, or destroy) [default: format]"
    echo "  --no-reboot                Don't reboot after installation"
    echo "  --no-kexec                 Don't use custom kexec installer (kexec is used by default)"
    echo "  --help                     Show this help message"
    echo
    echo "Examples:"
    echo "  $0 myhost 192.168.1.100"
    echo "  $0 myhost 192.168.1.100 mypassword"
    echo "  $0 myhost 192.168.1.100 --disko-mode mount"
    echo "  $0 myhost 192.168.1.100 -i ~/.ssh/id_rsa"
    echo "  $0 myhost 192.168.1.100 --no-kexec"
    echo
    echo "The script will:"
    echo "  1. Generate and encrypt SSH host keys if they don't exist"
    echo "  2. Generate and encrypt disk encryption key if it doesn't exist"
    echo "  3. Run agenix generate to create age keys from host keys"
    echo "  4. Run agenix rekey to encrypt secrets for the new host"
    echo "  5. Commit the generated keys and secrets to git"
    echo "  6. Decrypt and install SSH host keys on the target"
    echo "  7. Set up disk encryption with the stored/provided password"
    echo "  8. Run nixos-anywhere to install the system"
    echo
    echo "Note: By default, a host-specific kexec installer is built and used"
    exit 1
}

check_dependencies() {
    local missing=()
    command -v age >/dev/null || missing+=("age")
    command -v age-plugin-yubikey >/dev/null || missing+=("age-plugin-yubikey")
    command -v ssh >/dev/null || missing+=("ssh")
    command -v ssh-keygen >/dev/null || missing+=("ssh-keygen")
    command -v scp >/dev/null || missing+=("scp")
    command -v nix >/dev/null || missing+=("nix")
    command -v nixos-anywhere >/dev/null || missing+=("nixos-anywhere")
    command -v git >/dev/null || missing+=("git")
    command -v agenix >/dev/null || missing+=("agenix")
    command -v openssl >/dev/null || missing+=("openssl")

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing[*]}"
    fi
}

validate_host_exists() {
    local hostname="$1"

    # Check if host exists in flake
    if ! nix eval --json .#hosts --apply "builtins.hasAttr \"$hostname\"" 2>/dev/null | jq -r '.' 2>/dev/null | grep -q "true"; then
        error "Host '$hostname' not found in flake configuration"
    fi
}

get_or_prompt_disk_password() {
    local provided_password="$1"

    # If provided password, use it
    if [[ -n "$provided_password" ]]; then
        echo "$provided_password"
        return 0
    fi

    # Prompt for password
    echo -n "Enter disk encryption password (or press Enter to generate random): " >&2
    read -r -s password
    echo >&2

    # If empty, generate random password
    if [[ -z "$password" ]]; then
        password=$(openssl rand -base64 32)
        log "Generated random disk encryption password"
    fi

    echo "$password"
}

get_disk_encryption_password() {
    local hostname="$1"
    local host_dir="$KEYS_DIR/$hostname"
    local disk_key_file="$host_dir/root-disk-key.age"

    # Decrypt the stored disk key
    if [[ ! -f "$disk_key_file" ]]; then
        error "Disk encryption key not found: $disk_key_file. This should have been created during provisioning."
    fi

    log "Decrypting disk encryption key..."
    local yubikey_identity_file
    yubikey_identity_file=$(mktemp)
    trap 'rm -f "$yubikey_identity_file"' EXIT

    age-plugin-yubikey -i > "$yubikey_identity_file"

    local password
    if password=$(age -d -i "$yubikey_identity_file" "$disk_key_file" 2>/dev/null); then
        log "  ✓ Disk encryption key decrypted"
        rm -f "$yubikey_identity_file"
        echo "$password"
        return 0
    else
        rm -f "$yubikey_identity_file"
        error "Failed to decrypt disk encryption key"
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

generate_and_encrypt_disk_key() {
    local hostname="$1"
    local age_recipient="$2"
    local disk_password="$3"
    local host_dir="$KEYS_DIR/$hostname"
    local disk_key_file="$host_dir/root-disk-key.age"

    # Check if disk key already exists
    if [[ -f "$disk_key_file" ]]; then
        log "  ✓ Disk encryption key already exists: $disk_key_file"
        return 0
    fi

    if [[ -z "$disk_password" ]]; then
        error "Disk password is required but was not provided"
    fi

    # Encrypt the disk password
    if echo -n "$disk_password" | age -r "$age_recipient" > "$disk_key_file" 2>/dev/null; then
        log "  ✓ Encrypted and stored disk key: root-disk-key.age"
        chmod 600 "$disk_key_file"
        return 0
    else
        log "  ✗ Failed to encrypt disk key"
        [[ -f "$disk_key_file" ]] && rm "$disk_key_file"
        return 1
    fi
}

generate_and_encrypt_host_keys() {
    local hostname="$1"
    local age_recipient="$2"
    local host_dir="$KEYS_DIR/$hostname"

    # Create host directory
    mkdir -p "$host_dir"

    log "Generating SSH host keys for: $hostname"

    local generated_count=0

    # Generate each key type
    for key_type in "${KEY_TYPES[@]}"; do
        local key_file="ssh_host_${key_type}_key"
        local pub_file="${key_file}.pub"
        local age_file="$host_dir/${key_file}.age"
        local temp_key="/tmp/${hostname}_${key_file}"

        # Check if encrypted key already exists
        if [[ -f "$age_file" ]]; then
            log "  ✓ Key already exists: $hostname/$key_file"
            continue
        fi

        # Generate the key in a temporary location
        log "  Generating $key_type key for $hostname"
        case "$key_type" in
            "ed25519")
                if ssh-keygen -t ed25519 -f "$temp_key" -N "" -C "root@$hostname" >/dev/null 2>&1; then
                    log "  ✓ Generated: $hostname/$key_file"
                    ((generated_count++))
                else
                    log "  ✗ Failed to generate: $hostname/$key_file"
                    continue
                fi
                ;;
            "rsa")
                if ssh-keygen -t rsa -b 4096 -f "$temp_key" -N "" -C "root@$hostname" >/dev/null 2>&1; then
                    log "  ✓ Generated: $hostname/$key_file"
                    ((generated_count++))
                else
                    log "  ✗ Failed to generate: $hostname/$key_file"
                    continue
                fi
                ;;
            *)
                log "  ✗ Unsupported key type: $key_type"
                continue
                ;;
        esac

        # Encrypt the private key
        if age -r "$age_recipient" > "$age_file" 2>/dev/null < "$temp_key"; then
            log "  ✓ Encrypted: $hostname/$key_file"
            chmod 600 "$age_file"
        else
            log "  ✗ Failed to encrypt: $hostname/$key_file"
            # Remove partial file if it exists
            [[ -f "$age_file" ]] && rm "$age_file"
        fi

        # Copy public key to final location
        if cp "${temp_key}.pub" "$host_dir/$pub_file" 2>/dev/null; then
            log "  ✓ Stored public key: $hostname/$pub_file"
            chmod 644 "$host_dir/$pub_file"
        else
            log "  ✗ Failed to store public key: $hostname/$pub_file"
        fi

        # Clean up temporary files
        rm -f "$temp_key" "${temp_key}.pub"
    done

    if [[ $generated_count -eq 0 ]]; then
        return 1
    fi

    return 0
}

provision_host_secrets() {
    local hostname="$1"
    local provided_disk_password="$2"

    log "Provisioning secrets for $hostname"

    # Get YubiKey recipient
    local age_recipient
    age_recipient=$(get_yubikey_recipient)

    # Check if host keys need to be generated
    local host_dir="$KEYS_DIR/$hostname"
    if [[ ! -d "$host_dir" ]] || [[ -z "$(ls -A "$host_dir" 2>/dev/null)" ]]; then
        log "  Host keys not found, generating..."

        # Generate and encrypt keys
        if ! generate_and_encrypt_host_keys "$hostname" "$age_recipient"; then
            error "Failed to generate SSH host keys for: $hostname"
        fi

        log "  ✓ SSH host keys generated and encrypted"
    else
        log "  ✓ SSH host keys already exist"
    fi

    # Check if disk encryption key already exists
    local disk_key_file="$host_dir/root-disk-key.age"
    if [[ -f "$disk_key_file" ]]; then
        log "  ✓ Disk encryption key already exists"
    else
        # Get or prompt for disk encryption password only if key doesn't exist
        log "  Disk encryption key not found, generating..."
        local disk_password
        disk_password=$(get_or_prompt_disk_password "$provided_disk_password")

        # Generate and encrypt disk encryption key
        if ! generate_and_encrypt_disk_key "$hostname" "$age_recipient" "$disk_password"; then
            error "Failed to generate disk encryption key for: $hostname"
        fi
    fi

    # Run agenix generate to create age keys from host keys
    log "  Running agenix generate..."
    if agenix generate; then
        log "  ✓ Age keys generated from host keys"
    else
        error "Failed to generate age keys with agenix"
    fi

    # Run agenix rekey to encrypt secrets for the new host
    log "  Running agenix rekey..."
    if agenix rekey; then
        log "  ✓ Secrets rekeyed for all hosts"
    else
        error "Failed to rekey secrets with agenix"
    fi

    # Commit the changes to git
    log "  Committing keys and secrets to git..."
    if git add "$KEYS_DIR/$hostname" .secrets/; then
        if git diff --cached --quiet; then
            log "  ✓ No changes to commit (already up to date)"
        else
            if git commit -m "feat(secrets): provision host keys and secrets for $hostname

Generated SSH host keys and age keys for new host $hostname.
Rekeyed all secrets to include the new host.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"; then
                log "  ✓ Keys and secrets committed to git"
            else
                error "Failed to commit keys and secrets to git"
            fi
        fi
    else
        error "Failed to stage keys and secrets"
    fi

    log "✓ Host provisioning completed"
}

prepare_ssh_host_keys() {
    local hostname="$1"
    local host_dir="$KEYS_DIR/$hostname"

    log "Preparing SSH host keys for $hostname"

    # Check if host keys exist
    if [[ ! -d "$host_dir" ]]; then
        error "No SSH host keys found for $hostname. Run 'generate-host-keys $hostname' first."
    fi

    # Create temporary directory with /persist/etc/ssh structure for --extra-files
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT

    install -d -m755 "$temp_dir/persist/etc/ssh"

    # Get YubiKey identity once
    log "  Getting YubiKey identity..."
    local yubikey_identity_file="$temp_dir/yubikey_identity"
    age-plugin-yubikey -i > "$yubikey_identity_file"
    log "  ✓ YubiKey identity obtained"

    # Decrypt and prepare host keys
    local key_count=0
    for age_file in "$host_dir"/ssh_host_*_key.age; do
        if [[ ! -f "$age_file" ]]; then
            continue
        fi

        local key_file
        key_file=$(basename "$age_file" .age)
        local temp_key="$temp_dir/persist/etc/ssh/$key_file"

        # Decrypt the key using the cached identity
        set +e  # Temporarily disable exit on error
        age -d -i "$yubikey_identity_file" "$age_file" > "$temp_key"
        local decrypt_result=$?
        set -e  # Re-enable exit on error

        if [[ $decrypt_result -eq 0 ]]; then
            chmod 600 "$temp_key"
            log "  ✓ Decrypted: $key_file"
            key_count=$((key_count + 1))
        else
            log "  ✗ Failed to decrypt: $key_file (exit code: $decrypt_result)"
        fi
    done

    # Copy public keys as well
    for pub_file in "$host_dir"/ssh_host_*_key.pub; do
        if [[ -f "$pub_file" ]]; then
            cp "$pub_file" "$temp_dir/persist/etc/ssh/"
            chmod 644 "$temp_dir/persist/etc/ssh/$(basename "$pub_file")"
            log "  ✓ Prepared: $(basename "$pub_file")"
        fi
    done

    if [[ $key_count -eq 0 ]]; then
        error "Failed to decrypt any SSH host keys"
    fi

    log "  ✓ SSH host keys prepared ($key_count keys)"
}

cleanup_ssh_agent() {
    log "Cleaning up SSH agent temporary key"

    if [[ "$SSH_AUTH_SOCK" =~ gpg-agent ]]; then
        log "  Detected gpg-agent, removing key from agent"

        # Remove keys from gpg-agent
        gpg-connect-agent 'keyinfo --ssh-list --ssh-fpr' /bye |
        awk '$1 == "S" { print $3 }' |
        while IFS= read -r key; do
            gpg-connect-agent "delete_key $key --force" /bye
        done

        # Also run ssh-add -D
        ssh-add -D 2>/dev/null || true

        # Remove last 3 lines from sshcontrol
        local sshcontrol="$HOME/.gnupg/sshcontrol"
        if [[ -f "$sshcontrol" ]]; then
            local linecount
            linecount=$(wc -l < "$sshcontrol")
            if [[ $linecount -gt 3 ]]; then
                head -n $((linecount - 3)) "$sshcontrol" > "$sshcontrol.tmp"
                mv "$sshcontrol.tmp" "$sshcontrol"
                log "  ✓ Removed last 3 lines from ~/.gnupg/sshcontrol"
            else
                # If file has 3 or fewer lines, just truncate it
                : > "$sshcontrol"
                log "  ✓ Cleared ~/.gnupg/sshcontrol"
            fi
        fi
    else
        log "  Detected regular ssh-agent, removing key"
        ssh-add -D 2>/dev/null || true
    fi

    log "  ✓ SSH agent cleanup completed"
}

run_nixos_anywhere() {
    local hostname="$1"
    local target_ip="$2"
    local disk_password="$3"
    local disko_mode="$4"
    local no_reboot="$5"
    local identity_file="$6"
    local use_kexec="$7"

    log "Running nixos-anywhere for $hostname on $target_ip"

    # Store disk encryption password in temp directory for disko
    install -d -m755 "$temp_dir/tmp"
    echo -n "$disk_password" > "$temp_dir/tmp/secret.key"
    chmod 600 "$temp_dir/tmp/secret.key"
    log "  ✓ Disk encryption key written to /tmp/secret.key"

    # Prepare nixos-anywhere arguments
    local nix_anywhere_args=(
        "--flake" ".#$hostname"
        "--target-host" "root@$target_ip"
        "--disko-mode" "$disko_mode"
        "--extra-files" "$temp_dir"
        "--disk-encryption-keys" "/tmp/secret.key" "$temp_dir/tmp/secret.key"
    )

    # Build and use custom kexec if requested
    if [[ "$use_kexec" == "true" ]]; then
        log "Building custom kexec installer for $hostname..."
        local kexec_path
        kexec_path=$(nix build --print-out-paths ".#nixosConfigurations.$hostname-kexec.config.system.build.kexecTarball")

        # Find the tarball in the output
        local kexec_tarball
        kexec_tarball=$(find "$kexec_path" -name "*.tar.gz" -type f | head -1)

        if [[ -z "$kexec_tarball" ]]; then
            error "Failed to find kexec tarball in build output"
        fi

        log "  ✓ Host-specific kexec installer built: $kexec_tarball"
        nix_anywhere_args+=("--kexec" "$kexec_tarball")
    fi

    # Handle SSH identity file
    local should_cleanup=false
    if [[ -n "$identity_file" ]]; then
        # User explicitly provided an identity file
        nix_anywhere_args+=("-i" "$identity_file")
        log "  Using SSH identity file: $identity_file"
    else
        # Check for agenix identity file
        local agenix_identity="/var/run/agenix/user-${USER}-id_agenix"
        if [[ -f "$agenix_identity" ]]; then
            nix_anywhere_args+=("-i" "$agenix_identity")
            log "  Using agenix SSH identity file: $agenix_identity"
        else
            log "  No identity file specified or found, using default SSH authentication"
            should_cleanup=true
        fi
    fi

    if [[ "$no_reboot" == "true" ]]; then
        nix_anywhere_args+=("--no-reboot")
    fi

    # Set disk encryption password as environment variable (for compatibility)
    export DISK_ENCRYPTION_PASSWORD="$disk_password"

    log "Executing: nixos-anywhere ${nix_anywhere_args[*]}"

    # Run nixos-anywhere
    if nixos-anywhere "${nix_anywhere_args[@]}"; then
        log "✓ nixos-anywhere completed successfully"
        log "Host $hostname has been installed on $target_ip"

        # Cleanup SSH agent if needed
        if [[ "$should_cleanup" == "true" ]]; then
            cleanup_ssh_agent
        fi
    else
        error "nixos-anywhere failed"
    fi
}

main() {
    local hostname=""
    local target_ip=""
    local disk_password=""
    local disko_mode="disko"
    local no_reboot="false"
    local identity_file=""
    local use_kexec="true"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--identity)
                identity_file="$2"
                shift 2
                ;;
            --disko-mode)
                disko_mode="$2"
                shift 2
                ;;
            --no-reboot)
                no_reboot="true"
                shift
                ;;
            --no-kexec)
                use_kexec="false"
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
                elif [[ -z "$target_ip" ]]; then
                    target_ip="$1"
                elif [[ -z "$disk_password" ]]; then
                    disk_password="$1"
                else
                    error "Too many arguments"
                fi
                shift
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$hostname" || -z "$target_ip" ]]; then
        usage
    fi

    # Validate identity file if provided
    if [[ -n "$identity_file" && ! -f "$identity_file" ]]; then
        error "SSH identity file not found: $identity_file"
    fi

    # Validate disko mode
    case "$disko_mode" in
        format|mount|disko)
            ;;
        *)
            error "Invalid disko mode: $disko_mode. Must be format, mount, or disko."
            ;;
    esac

    log "Starting nixos-anywhere installation for $hostname on $target_ip"

    check_dependencies
    validate_host_exists "$hostname"

    # Provision host secrets (generate keys, disk key, agenix generate/rekey, commit)
    # This will prompt for disk password if not provided and store it encrypted
    provision_host_secrets "$hostname" "$disk_password"

    # Get disk encryption password (decrypt from stored key)
    disk_password=$(get_disk_encryption_password "$hostname")

    # Prepare SSH host keys for installation
    prepare_ssh_host_keys "$hostname"

    # Run nixos-anywhere
    run_nixos_anywhere "$hostname" "$target_ip" "$disk_password" "$disko_mode" "$no_reboot" "$identity_file" "$use_kexec"

    log "Installation completed successfully!"
}

main "$@"
