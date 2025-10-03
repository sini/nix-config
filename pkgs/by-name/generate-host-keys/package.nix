{
  writeShellApplication,
  age,
  openssh,
  coreutils,
}:
writeShellApplication {
  name = "generate-host-keys";
  runtimeInputs = [
    age
    openssh
    coreutils
  ];
  text = ''
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
        echo "Usage: $0 <hostname>"
        echo
        echo "Generate SSH host keys for a new host and encrypt them with YubiKey."
        echo
        echo "Arguments:"
        echo "  hostname    The name of the host to generate keys for"
        echo
        echo "Example:"
        echo "  $0 myhost"
        exit 1
    }

    check_dependencies() {
        local missing=()
        command -v age >/dev/null || missing+=("age")
        command -v age-plugin-yubikey >/dev/null || missing+=("age-plugin-yubikey")
        command -v ssh-keygen >/dev/null || missing+=("ssh-keygen")

        if [[ ''${#missing[@]} -gt 0 ]]; then
            error "Missing required dependencies: ''${missing[*]}"
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

    generate_and_encrypt_host_keys() {
        local hostname="$1"
        local age_recipient="$2"
        local host_dir="$KEYS_DIR/$hostname"

        # Create host directory
        mkdir -p "$host_dir"

        log "Generating SSH host keys for: $hostname"

        local generated_count=0

        # Generate each key type
        for key_type in "''${KEY_TYPES[@]}"; do
            local key_file="ssh_host_''${key_type}_key"
            local pub_file="''${key_file}.pub"
            local age_file="$host_dir/''${key_file}.age"
            local temp_key="/tmp/''${hostname}_''${key_file}"

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
            if cp "''${temp_key}.pub" "$host_dir/$pub_file" 2>/dev/null; then
                log "  ✓ Stored public key: $hostname/$pub_file"
                chmod 644 "$host_dir/$pub_file"
            else
                log "  ✗ Failed to store public key: $hostname/$pub_file"
            fi

            # Clean up temporary files
            rm -f "$temp_key" "''${temp_key}.pub"
        done

        if [[ $generated_count -eq 0 ]]; then
            return 1
        fi

        return 0
    }

    main() {
        if [[ $# -ne 1 ]]; then
            usage
        fi

        local hostname="$1"

        # Validate hostname
        if [[ ! "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$ ]]; then
            error "Invalid hostname: $hostname. Hostname must contain only alphanumeric characters and hyphens."
        fi

        log "Starting SSH host key generation for: $hostname"

        check_dependencies

        # Get YubiKey recipient
        local age_recipient
        age_recipient=$(get_yubikey_recipient)

        # Generate and encrypt keys
        if generate_and_encrypt_host_keys "$hostname" "$age_recipient"; then
            log "Successfully generated and encrypted SSH host keys for: $hostname"
            log "Keys stored in: $KEYS_DIR/$hostname"
        else
            error "Failed to generate SSH host keys for: $hostname"
        fi
    }

    main "$@"
  '';
}
