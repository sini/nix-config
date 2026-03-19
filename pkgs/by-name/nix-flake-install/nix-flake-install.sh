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
Usage: $0 <hostname> <target-ip> [options]

Install NixOS on a remote host using nixos-anywhere with automated provisioning.

Arguments:
  hostname      The name of the host configuration in the flake
  target-ip     IP address of the target host

Options:
  -i, --identity FILE        SSH identity file to use for authentication
  --disk-password PASSWORD   Disk encryption password (passed to provisioning if keys don't exist)
  --disko-mode MODE          Disko mode: format, mount, or disko [default: disko]
  --no-reboot                Don't reboot after installation
  --no-kexec                 Don't use custom kexec installer (kexec is used by default)
  --dry-run                  Show what would be done without executing
  --help                     Show this help message

Examples:
  $0 myhost 192.168.1.100
  $0 myhost 192.168.1.100 --disk-password mypassword
  $0 myhost 192.168.1.100 --disko-mode mount
  $0 myhost 192.168.1.100 -i ~/.ssh/id_rsa
  $0 myhost 192.168.1.100 --no-kexec
  $0 myhost 192.168.1.100 --dry-run

The script will:
  1. Run nix-flake-provision-keys to generate/encrypt keys (if needed)
  2. Decrypt and prepare SSH host keys for the target
  3. Set up disk encryption with the stored password
  4. Run nixos-anywhere to install the system

Note: By default, a host-specific kexec installer is built and used
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

decrypt_disk_password() {
    local hostname="$1"
    local disk_key_file="$KEYS_DIR/$hostname/root-disk-key.age"

    if [[ ! -f "$disk_key_file" ]]; then
        error "Disk encryption key not found: $disk_key_file. Run 'nix-flake-provision-keys $hostname' first."
    fi

    log "Decrypting disk encryption key..."

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

prepare_ssh_host_keys() {
    local hostname="$1"
    local extra_files_dir="$2"
    local host_dir="$KEYS_DIR/$hostname"

    log "Preparing SSH host keys for $hostname"

    if [[ ! -d "$host_dir" ]]; then
        error "No SSH host keys found for $hostname. Run 'nix-flake-provision-keys $hostname' first."
    fi

    install -d -m755 "$extra_files_dir/persist/etc/ssh"

    log "  Getting YubiKey identity..."
    local yubikey_identity_file
    yubikey_identity_file=$(mktemp)
    register_cleanup "$yubikey_identity_file"

    age-plugin-yubikey -i > "$yubikey_identity_file"
    log "  ✓ YubiKey identity obtained"

    local key_count=0
    for age_file in "$host_dir"/ssh_host_*_key.age; do
        [[ -f "$age_file" ]] || continue

        local key_file
        key_file=$(basename "$age_file" .age)
        local dest_key="$extra_files_dir/persist/etc/ssh/$key_file"

        local decrypt_result=0
        age -d -i "$yubikey_identity_file" "$age_file" > "$dest_key" || decrypt_result=$?

        if [[ $decrypt_result -eq 0 ]]; then
            chmod 600 "$dest_key"
            log "  ✓ Decrypted: $key_file"
            key_count=$((key_count + 1))
        else
            log "  ✗ Failed to decrypt: $key_file (exit code: $decrypt_result)"
            rm -f "$dest_key"
        fi
    done

    for pub_file in "$host_dir"/ssh_host_*_key.pub; do
        if [[ -f "$pub_file" ]]; then
            cp "$pub_file" "$extra_files_dir/persist/etc/ssh/"
            chmod 644 "$extra_files_dir/persist/etc/ssh/$(basename "$pub_file")"
            log "  ✓ Prepared: $(basename "$pub_file")"
        fi
    done

    if [[ $key_count -eq 0 ]]; then
        error "Failed to decrypt any SSH host keys"
    fi

    log "  ✓ SSH host keys prepared ($key_count keys)"
}

main() {
    local hostname=""
    local target_ip=""
    local disk_password=""
    local disko_mode="disko"
    local no_reboot=false
    local identity_file=""
    local use_kexec=true
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--identity)
                identity_file="$2"
                shift 2
                ;;
            --disk-password)
                disk_password="$2"
                shift 2
                ;;
            --disko-mode)
                disko_mode="$2"
                shift 2
                ;;
            --no-reboot)
                no_reboot=true
                shift
                ;;
            --no-kexec)
                use_kexec=false
                shift
                ;;
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
                elif [[ -z "$target_ip" ]]; then
                    target_ip="$1"
                else
                    error "Too many positional arguments"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$hostname" || -z "$target_ip" ]]; then
        usage
    fi

    validate_hostname "$hostname"

    if [[ -n "$identity_file" && ! -f "$identity_file" ]]; then
        error "SSH identity file not found: $identity_file"
    fi

    case "$disko_mode" in
        format|mount|disko) ;;
        *) error "Invalid disko mode: $disko_mode. Must be format, mount, or disko." ;;
    esac

    log "Starting nixos-anywhere installation for $hostname on $target_ip"

    validate_host_exists "$hostname"

    # Provision keys if needed
    local host_dir="$KEYS_DIR/$hostname"
    if [[ ! -d "$host_dir" ]] || [[ -z "$(ls -A "$host_dir" 2>/dev/null)" ]]; then
        log "Host keys not found, running nix-flake-provision-keys..."
        if [[ "$dry_run" == true ]]; then
            log "[DRY RUN] Would run: nix-flake-provision-keys $hostname"
        else
            local provision_args=("$hostname")
            [[ -n "$disk_password" ]] && provision_args+=("--disk-password" "$disk_password")
            nix-flake-provision-keys "${provision_args[@]}"
        fi
    else
        log "✓ Host keys already provisioned"
    fi

    if [[ "$dry_run" == true ]]; then
        log "[DRY RUN] Would decrypt disk encryption key"
        log "[DRY RUN] Would prepare SSH host keys"
        log "[DRY RUN] Would run nixos-anywhere with:"
        log "  --flake .#$hostname"
        log "  --target-host root@$target_ip"
        log "  --disko-mode $disko_mode"
        [[ "$use_kexec" == true ]] && log "  --kexec <host-specific kexec tarball>"
        [[ -n "$identity_file" ]] && log "  -i $identity_file"
        [[ "$no_reboot" == true ]] && log "  --no-reboot"
        log "[DRY RUN] No changes made"
        return 0
    fi

    # Decrypt disk password
    local resolved_disk_password
    resolved_disk_password=$(decrypt_disk_password "$hostname")

    # Prepare extra-files directory
    local extra_files_dir
    extra_files_dir=$(mktemp -d)
    register_cleanup "$extra_files_dir"

    # Prepare SSH host keys
    prepare_ssh_host_keys "$hostname" "$extra_files_dir"

    # Write disk encryption key to extra-files
    install -d -m755 "$extra_files_dir/tmp"
    echo -n "$resolved_disk_password" > "$extra_files_dir/tmp/secret.key"
    chmod 600 "$extra_files_dir/tmp/secret.key"
    log "✓ Disk encryption key staged"

    # Build nixos-anywhere arguments
    local nix_anywhere_args=(
        "--flake" ".#$hostname"
        "--target-host" "root@$target_ip"
        "--disko-mode" "$disko_mode"
        "--extra-files" "$extra_files_dir"
        "--disk-encryption-keys" "/tmp/secret.key" "$extra_files_dir/tmp/secret.key"
    )

    if [[ "$use_kexec" == true ]]; then
        log "Building custom kexec installer for $hostname..."
        local kexec_path
        kexec_path=$(nix build --print-out-paths ".#kexecNixosConfigurations.$hostname-kexec.config.system.build.kexecTarball")

        local kexec_tarball
        kexec_tarball=$(find "$kexec_path" -name "*.tar.gz" -type f | head -1)

        if [[ -z "$kexec_tarball" ]]; then
            error "Failed to find kexec tarball in build output"
        fi

        log "  ✓ Host-specific kexec installer built: $kexec_tarball"
        nix_anywhere_args+=("--kexec" "$kexec_tarball")
    fi

    if [[ -n "$identity_file" ]]; then
        nix_anywhere_args+=("-i" "$identity_file")
        log "  Using SSH identity file: $identity_file"
    else
        local agenix_identity="/var/run/agenix/user-${USER}-id_agenix"
        if [[ -f "$agenix_identity" ]]; then
            nix_anywhere_args+=("-i" "$agenix_identity")
            log "  Using agenix SSH identity file: $agenix_identity"
        else
            log "  No identity file specified, using default SSH authentication"
        fi
    fi

    [[ "$no_reboot" == true ]] && nix_anywhere_args+=("--no-reboot")

    log "Executing: nixos-anywhere ${nix_anywhere_args[*]}"

    if nixos-anywhere "${nix_anywhere_args[@]}"; then
        log "✓ nixos-anywhere completed successfully"
        log "Host $hostname has been installed on $target_ip"
    else
        error "nixos-anywhere failed"
    fi

    log "Installation completed successfully!"
}

main "$@"
