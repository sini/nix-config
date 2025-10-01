{
  writeShellApplication,
  age,
  openssh,
  jq,
  nix,
  coreutils,
}:
writeShellApplication {
  name = "update-host-keys";
  runtimeInputs = [
    age
    openssh
    jq
    nix
    coreutils
  ];
  text = ''
    # Configuration
    REPO_ROOT="$(pwd)"
    KEYS_DIR="$REPO_ROOT/.secrets/host-keys"

    # SSH key types to collect
    KEY_TYPES=("ed25519" "rsa")

    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
    }

    error() {
        log "ERROR: $*"
        exit 1
    }

    check_dependencies() {
        local missing=()
        command -v age >/dev/null || missing+=("age")
        command -v age-plugin-yubikey >/dev/null || missing+=("age-plugin-yubikey")
        command -v ssh >/dev/null || missing+=("ssh")
        command -v scp >/dev/null || missing+=("scp")
        command -v nix >/dev/null || missing+=("nix")
        command -v jq >/dev/null || missing+=("jq")

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

    get_hosts() {
        log "Discovering hosts from flake configuration..."

        # Get host names from the flake
        if ! nix eval --json .#hosts --apply 'builtins.attrNames' 2>/dev/null | jq -r '.[]' 2>/dev/null; then
            error "Failed to get hosts from flake. Make sure you're in a valid nix flake directory."
        fi
    }

    collect_and_encrypt_host_keys() {
        local host="$1"
        local age_recipient="$2"
        local host_dir="$KEYS_DIR/$host"

        # Create host directory if it doesn't exist
        mkdir -p "$host_dir"

        # Check which keys need to be collected
        local keys_to_collect=()
        for key_type in "''${KEY_TYPES[@]}"; do
            local key_file="ssh_host_''${key_type}_key"
            local age_file="$host_dir/''${key_file}.age"

            # Only collect if encrypted file doesn't exist
            if [[ ! -f "$age_file" ]]; then
                keys_to_collect+=("$key_type")
            fi
        done

        if [[ ''${#keys_to_collect[@]} -eq 0 ]]; then
            return 0  # No keys needed
        fi

        log "Collecting and encrypting keys for host: $host (''${keys_to_collect[*]})"

        local collected_count=0

        # Collect and encrypt each missing key type
        for key_type in "''${keys_to_collect[@]}"; do
            local key_file="ssh_host_''${key_type}_key"
            local pub_file="''${key_file}.pub"
            local age_file="$host_dir/''${key_file}.age"

            # Stream private key directly from SSH to age encryption
            log "  Encrypting $key_file directly from $host"
            if ssh -o ConnectTimeout=10 -o BatchMode=yes "root@$host" "cat /etc/ssh/$key_file" 2>/dev/null | \
               age -r "$age_recipient" > "$age_file" 2>/dev/null; then
                log "  ✓ Encrypted: $host/$key_file"
                ((collected_count++))
            else
                log "  ✗ Failed to encrypt: $host/$key_file"
                # Remove partial file if it exists
                [[ -f "$age_file" ]] && rm "$age_file"
            fi

            # Collect public key (these are safe to store unencrypted)
            if scp -o ConnectTimeout=10 -o BatchMode=yes "root@$host:/etc/ssh/$pub_file" "$host_dir/" 2>/dev/null; then
                log "  ✓ Collected: $host/$pub_file"
                chmod 644 "$host_dir/$pub_file"
            else
                log "  ✗ Warning: Could not collect $host/$pub_file"
            fi
        done

        if [[ $collected_count -eq 0 ]]; then
            return 1  # Failed to collect any keys
        fi

        return 0
    }

    main() {
        log "Starting SSH host key collection and encryption"

        check_dependencies

        # Get YubiKey recipient
        local age_recipient
        age_recipient=$(get_yubikey_recipient)

        # Get list of hosts
        local hosts
        readarray -t hosts < <(get_hosts)

        if [[ ''${#hosts[@]} -eq 0 ]]; then
            error "No hosts found in flake configuration"
        fi

        log "Found ''${#hosts[@]} hosts: ''${hosts[*]}"

        # Collect keys from each host
        local failed_hosts=()
        local skipped_hosts=()
        local collected_from_hosts=()

        for host in "''${hosts[@]}"; do
            local host_dir="$KEYS_DIR/$host"

            # Check if this host needs any keys
            local needs_keys=false
            for key_type in "''${KEY_TYPES[@]}"; do
                local key_file="ssh_host_''${key_type}_key"
                local age_file="$host_dir/''${key_file}.age"
                if [[ ! -f "$age_file" ]]; then
                    needs_keys=true
                    break
                fi
            done

            if [[ "$needs_keys" == false ]]; then
                skipped_hosts+=("$host")
                continue
            fi

            if ! collect_and_encrypt_host_keys "$host" "$age_recipient"; then
                failed_hosts+=("$host")
            else
                collected_from_hosts+=("$host")
            fi
        done

        # Report results
        if [[ ''${#skipped_hosts[@]} -gt 0 ]]; then
            log "Skipped hosts (already have encrypted keys): ''${skipped_hosts[*]}"
        fi

        if [[ ''${#failed_hosts[@]} -gt 0 ]]; then
            log "Warning: Failed to collect keys from: ''${failed_hosts[*]}"
        fi

        # Report collection results
        if [[ ''${#collected_from_hosts[@]} -gt 0 ]]; then
            log "Successfully processed hosts: ''${collected_from_hosts[*]}"
        else
            log "No new keys collected"
        fi

        log "SSH host key collection and encryption completed"
    }

    main "$@"
  '';
}
