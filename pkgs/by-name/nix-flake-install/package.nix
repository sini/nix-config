{
  writeShellApplication,
  age,
  age-plugin-yubikey,
  openssh,
  jq,
  nix,
  coreutils,
  nixos-anywhere,
}:
writeShellApplication {
  name = "nix-flake-install";
  runtimeInputs = [
    age
    age-plugin-yubikey
    openssh
    jq
    nix
    coreutils
    nixos-anywhere
  ];
  text = ''
    # Configuration
    REPO_ROOT="$(pwd)"
    KEYS_DIR="$REPO_ROOT/.secrets/host-keys"

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
        echo "Install NixOS on a remote host using nixos-anywhere with pre-generated SSH host keys."
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
        echo "  --help                     Show this help message"
        echo
        echo "Examples:"
        echo "  $0 myhost 192.168.1.100"
        echo "  $0 myhost 192.168.1.100 mypassword"
        echo "  $0 myhost 192.168.1.100 --disko-mode mount"
        echo "  $0 myhost 192.168.1.100 -i ~/.ssh/id_rsa"
        echo
        echo "The script will:"
        echo "  1. Decrypt and install SSH host keys on the target"
        echo "  2. Set up disk encryption with the provided password"
        echo "  3. Run nixos-anywhere to install the system"
        exit 1
    }

    check_dependencies() {
        local missing=()
        command -v age >/dev/null || missing+=("age")
        command -v age-plugin-yubikey >/dev/null || missing+=("age-plugin-yubikey")
        command -v ssh >/dev/null || missing+=("ssh")
        command -v scp >/dev/null || missing+=("scp")
        command -v nix >/dev/null || missing+=("nix")
        command -v nixos-anywhere >/dev/null || missing+=("nixos-anywhere")

        if [[ ''${#missing[@]} -gt 0 ]]; then
            error "Missing required dependencies: ''${missing[*]}"
        fi
    }

    validate_host_exists() {
        local hostname="$1"

        # Check if host exists in flake
        if ! nix eval --json .#hosts --apply "builtins.hasAttr \"$hostname\"" 2>/dev/null | jq -r '.' 2>/dev/null | grep -q "true"; then
            error "Host '$hostname' not found in flake configuration"
        fi
    }

    get_disk_encryption_password() {
        local password="$1"

        if [[ -n "$password" ]]; then
            echo "$password"
            return 0
        fi

        # Prompt for password
        echo -n "Enter disk encryption password: " >&2
        read -r -s password
        echo >&2

        if [[ -z "$password" ]]; then
            error "Disk encryption password cannot be empty"
        fi

        echo "$password"
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

        # Handle SSH identity file
        local should_cleanup=false
        if [[ -n "$identity_file" ]]; then
            # User explicitly provided an identity file
            nix_anywhere_args+=("-i" "$identity_file")
            log "  Using SSH identity file: $identity_file"
        else
            # Check for agenix identity file
            local agenix_identity="/var/run/agenix/user-''${USER}-id_agenix"
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

        log "Executing: nixos-anywhere ''${nix_anywhere_args[*]}"

        # Run nixos-anywhere
        if nixos-anywhere "''${nix_anywhere_args[@]}"; then
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

        # Get disk encryption password
        disk_password=$(get_disk_encryption_password "$disk_password")

        # Prepare SSH host keys for installation
        prepare_ssh_host_keys "$hostname"

        # Run nixos-anywhere
        run_nixos_anywhere "$hostname" "$target_ip" "$disk_password" "$disko_mode" "$no_reboot" "$identity_file"

        log "Installation completed successfully!"
    }

    main "$@"
  '';
}
