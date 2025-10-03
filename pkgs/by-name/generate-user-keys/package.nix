{
  writeShellApplication,
  age,
  openssh,
  coreutils,
  jq,
  nix,
}:
writeShellApplication {
  name = "generate-user-keys";
  runtimeInputs = [
    age
    openssh
    coreutils
    jq
    nix
  ];
  text = ''
    # Configuration
    REPO_ROOT="$(pwd)"
    USERS_SECRETS_DIR="$REPO_ROOT/.secrets/users"

    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
    }

    error() {
        log "ERROR: $*"
        exit 1
    }

    usage() {
        echo "Usage: $0 <username> [key-name]"
        echo
        echo "Generate ed25519 SSH keys for a user and encrypt them with YubiKey."
        echo
        echo "Arguments:"
        echo "  username    The name of the user to generate keys for"
        echo "  key-name    Optional name for the key (default: id_ed25519)"
        echo
        echo "Options:"
        echo "  --list      List all configured users"
        echo "  --help      Show this help message"
        echo
        echo "Examples:"
        echo "  $0 sini"
        echo "  $0 sini laptop-key"
        echo "  $0 --list"
        echo
        echo "The script will:"
        echo "  1. Generate an ed25519 SSH key pair"
        echo "  2. Encrypt the private key with YubiKey age encryption"
        echo "  3. Store both keys in .secrets/users/<username>/"
        exit 1
    }

    check_dependencies() {
        local missing=()
        command -v age >/dev/null || missing+=("age")
        command -v age-plugin-yubikey >/dev/null || missing+=("age-plugin-yubikey")
        command -v ssh-keygen >/dev/null || missing+=("ssh-keygen")
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

    list_users() {
        log "Discovering users from flake configuration..."

        # Get user names from the flake
        if ! nix eval --json .#users --apply 'builtins.attrNames' 2>/dev/null | jq -r '.[]' 2>/dev/null; then
            error "Failed to get users from flake. Make sure you're in a valid nix flake directory."
        fi
    }

    validate_user_exists() {
        local username="$1"

        # Check if user exists in flake
        if ! nix eval --json .#users --apply "builtins.hasAttr \"$username\"" 2>/dev/null | jq -r '.' 2>/dev/null | grep -q "true"; then
            error "User '$username' not found in flake configuration"
        fi
    }

    generate_and_encrypt_user_keys() {
        local username="$1"
        local key_name="$2"
        local age_recipient="$3"
        local user_secrets_dir="$USERS_SECRETS_DIR/$username"

        # Create user secrets directory if it doesn't exist
        mkdir -p "$user_secrets_dir"

        log "Generating ed25519 SSH keys for user: $username (key: $key_name)"

        local private_key_file="$key_name"
        local public_key_file="''${key_name}.pub"
        local age_file="$user_secrets_dir/''${private_key_file}.age"
        local pub_file="$user_secrets_dir/$public_key_file"
        local temp_key="/tmp/''${username}_''${key_name}"

        # Check if encrypted key already exists
        if [[ -f "$age_file" ]]; then
            error "Key already exists: $username/$private_key_file.age"
        fi

        # Generate the ed25519 key in a temporary location
        log "  Generating ed25519 key pair for $username"
        if ssh-keygen -t ed25519 -f "$temp_key" -N "" -C "$username@$(hostname)" >/dev/null 2>&1; then
            log "  ✓ Generated: $username/$key_name"
        else
            error "  ✗ Failed to generate ed25519 key for $username"
        fi

        # Encrypt the private key
        if age -r "$age_recipient" > "$age_file" 2>/dev/null < "$temp_key"; then
            log "  ✓ Encrypted private key: $username/$private_key_file.age"
            chmod 600 "$age_file"
        else
            log "  ✗ Failed to encrypt private key"
            # Clean up and exit
            rm -f "$temp_key" "''${temp_key}.pub"
            [[ -f "$age_file" ]] && rm "$age_file"
            error "Failed to encrypt private key for $username"
        fi

        # Copy public key to final location
        if cp "''${temp_key}.pub" "$pub_file" 2>/dev/null; then
            log "  ✓ Stored public key: $username/$public_key_file"
            chmod 644 "$pub_file"
        else
            log "  ✗ Failed to store public key"
            # Clean up and exit
            rm -f "$temp_key" "''${temp_key}.pub" "$age_file"
            error "Failed to store public key for $username"
        fi

        # Clean up temporary files
        rm -f "$temp_key" "''${temp_key}.pub"

        log "✓ Successfully generated and encrypted SSH keys for $username"
        log "  Private key (encrypted): $age_file"
        log "  Public key: $pub_file"

        # Display the public key for easy copying
        echo
        log "Public key content:"
        cat "$pub_file"
        echo
    }

    main() {
        local username=""
        local key_name="id_ed25519"

        # Parse arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --list)
                    echo "Configured users:"
                    list_users
                    exit 0
                    ;;
                --help)
                    usage
                    ;;
                -*)
                    error "Unknown option: $1"
                    ;;
                *)
                    if [[ -z "$username" ]]; then
                        username="$1"
                    elif [[ "$key_name" == "id_ed25519" ]]; then
                        key_name="$1"
                    else
                        error "Too many arguments"
                    fi
                    shift
                    ;;
            esac
        done

        # Validate required arguments
        if [[ -z "$username" ]]; then
            usage
        fi

        # Validate username
        if [[ ! "$username" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$ ]]; then
            error "Invalid username: $username. Username must contain only alphanumeric characters, underscores, and hyphens."
        fi

        # Validate key name
        if [[ ! "$key_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$ ]]; then
            error "Invalid key name: $key_name. Key name must contain only alphanumeric characters, underscores, and hyphens."
        fi

        log "Starting SSH key generation for user: $username"

        check_dependencies
        validate_user_exists "$username"

        # Get YubiKey recipient
        local age_recipient
        age_recipient=$(get_yubikey_recipient)

        # Generate and encrypt keys
        generate_and_encrypt_user_keys "$username" "$key_name" "$age_recipient"

        log "Key generation completed successfully!"
        log "You can now add the public key to the user's authorized keys or use it for authentication."
    }

    main "$@"
  '';
}
