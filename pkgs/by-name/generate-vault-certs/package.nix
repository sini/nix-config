{
  writeShellApplication,
  openssl,
  nix,
  jq,
  coreutils,
}:
writeShellApplication {
  name = "generate-vault-certs";
  runtimeInputs = [
    openssl
    nix
    jq
    coreutils
  ];
  text = ''
    # Configuration
    REPO_ROOT="$(pwd)"

    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
    }

    error() {
        log "ERROR: $*"
        exit 1
    }

    usage() {
        echo "Usage: $0 [environment]"
        echo
        echo "Generate certificates for Vault raft cluster."
        echo "This creates a CA and individual certificates for each vault node."
        echo
        echo "Arguments:"
        echo "  environment    Optional: specify environment to generate certs for"
        echo "                 If not specified, will generate for all environments"
        echo
        echo "Examples:"
        echo "  $0              # Generate for all environments"
        echo "  $0 dev          # Generate only for dev environment"
        echo "  $0 prod         # Generate only for prod environment"
        echo
        echo "The script will:"
        echo "  1. Create a CA certificate for each environment"
        echo "  2. Generate node certificates for each vault host"
        echo "  3. Output certificates to a temporary directory"
        echo "  4. Provide instructions for manual deployment"
        exit 1
    }

    check_dependencies() {
        local missing=()
        command -v openssl >/dev/null || missing+=("openssl")
        command -v nix >/dev/null || missing+=("nix")
        command -v jq >/dev/null || missing+=("jq")

        if [[ ''${#missing[@]} -gt 0 ]]; then
            error "Missing required dependencies: ''${missing[*]}"
        fi
    }

    # Get vault hosts from flake for specified environment
    get_vault_hosts() {
        local env="$1"

        (cd "$REPO_ROOT" && nix eval --json .#hosts --apply 'hosts: builtins.mapAttrs (name: host: { inherit (host) system roles environment ipv4; }) hosts' 2>/dev/null) |
        jq -r "to_entries | map(select(.value.environment == \"$env\" and (.value.roles | contains([\"vault\"])))) | .[] | \"\(.key) \(.value.ipv4[0])\""
    }

    # Get environment domain
    get_environment_domain() {
        local env="$1"
        (cd "$REPO_ROOT" && nix eval --raw .#environments."$env".domain 2>/dev/null) || echo "local"
    }

    # Function to generate node certificate
    generate_node_cert() {
        local hostname="$1"
        local ip="$2"
        local domain="$3"
        local env="$4"
        local cert_dir="$5"

        log "Generating certificate for $hostname ($ip) in domain $domain"

        # Generate private key
        openssl genpkey -algorithm RSA -out "$cert_dir/vault-''${hostname}-key.pem"

        # Create certificate signing request
        openssl req -new -key "$cert_dir/vault-''${hostname}-key.pem" -out "$cert_dir/vault-''${hostname}.csr" \
        -subj "/C=US/ST=Local/L=Local/O=Vault/CN=''${hostname}"

        # Create certificate extensions
        cat >"$cert_dir/vault-''${hostname}.ext" <<EOF
    authorityKeyIdentifier=keyid,issuer
    basicConstraints=CA:FALSE
    keyUsage = critical, digitalSignature, keyEncipherment
    extendedKeyUsage = serverAuth, clientAuth
    subjectAltName = @alt_names

    [alt_names]
    DNS.1 = ''${hostname}
    DNS.2 = ''${hostname}.''${domain}
    DNS.3 = vault.''${domain}
    IP.1 = ''${ip}
    IP.2 = 127.0.0.1
    EOF

        # Sign the certificate using the environment-specific CA
        openssl x509 -req -in "$cert_dir/vault-''${hostname}.csr" -CA "$cert_dir/$env/vault-ca.pem" -CAkey "$cert_dir/$env/vault-ca-key.pem" \
        -out "$cert_dir/vault-''${hostname}.pem" -days 365 -extfile "$cert_dir/vault-''${hostname}.ext" \
        -CAcreateserial

        # Clean up CSR and extensions file
        rm "$cert_dir/vault-''${hostname}.csr" "$cert_dir/vault-''${hostname}.ext"
    }

    main() {
        local environment="''${1:-}"

        # Parse arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --help)
                    usage
                    ;;
                -*)
                    error "Unknown option: $1"
                    ;;
                *)
                    if [[ -z "$environment" ]]; then
                        environment="$1"
                    else
                        error "Too many arguments"
                    fi
                    shift
                    ;;
            esac
        done

        log "Starting Vault certificate generation"

        check_dependencies

        # Create temporary directory for certificates
        local cert_dir
        cert_dir="$(mktemp -d)"
        log "Working in: $cert_dir"

        # Generate certificates for vault nodes
        local environments=()
        if [ -n "$environment" ]; then
            environments=("$environment")
        else
            # Get all environments that have vault hosts
            readarray -t environments < <((cd "$REPO_ROOT" && nix eval --json .#hosts --apply 'hosts: builtins.mapAttrs (name: host: { inherit (host) system roles environment ipv4; }) hosts' 2>/dev/null | jq -r 'to_entries | map(select(.value.roles | contains(["vault"]))) | map(.value.environment) | unique | .[]'))
        fi

        if [[ ''${#environments[@]} -eq 0 ]]; then
            error "No environments with vault hosts found"
        fi

        for env in "''${environments[@]}"; do
            log "=== Processing environment: $env ==="

            local domain
            domain=$(get_environment_domain "$env")
            log "Domain for $env: $domain"

            # Create environment-specific directory
            mkdir -p "$cert_dir/$env"

            # Generate CA for this environment
            log "Generating CA certificate for $env"
            openssl genpkey -algorithm RSA -out "$cert_dir/$env/vault-ca-key.pem"
            openssl req -new -x509 -key "$cert_dir/$env/vault-ca-key.pem" -out "$cert_dir/$env/vault-ca.pem" -days 3650 \
            -subj "/C=US/ST=Local/L=Local/O=Vault CA $env/CN=Vault Root CA ($env)"

            # Generate certificates for each vault node in this environment
            local node_count=0
            while IFS=' ' read -r hostname ip; do
                if [ -n "$hostname" ]; then
                    generate_node_cert "$hostname" "$ip" "$domain" "$env" "$cert_dir"
                    # Move generated files to environment directory
                    [ -f "$cert_dir/vault-''${hostname}.pem" ] && mv "$cert_dir/vault-''${hostname}.pem" "$cert_dir/$env/"
                    [ -f "$cert_dir/vault-''${hostname}-key.pem" ] && mv "$cert_dir/vault-''${hostname}-key.pem" "$cert_dir/$env/"
                    ((node_count++))
                fi
            done < <(get_vault_hosts "$env")

            if [[ $node_count -eq 0 ]]; then
                log "Warning: No vault hosts found for environment $env"
            else
                log "Generated certificates for $env environment ($node_count nodes):"
                ls -la "$cert_dir/$env/"
            fi
            echo
        done

        echo
        log "All certificates generated in: $cert_dir"
        echo
        echo "Next steps:"
        echo "1. Copy certificates to .secrets/services/vault/[environment]/ directories"
        echo "2. Encrypt them with: agenix-rekey edit .secrets/services/vault/[environment]/[file].age"
        echo "3. Deploy to the vault cluster: colmena apply --on @vault"
        echo
        echo "Example commands:"
        for env in "''${environments[@]}"; do
            echo "# For $env environment:"
            echo "mkdir -p .secrets/services/vault/$env"
            echo "cp $cert_dir/$env/* .secrets/services/vault/$env/"
            echo
        done
    }

    main "$@"
  '';
}
