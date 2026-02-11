{
  writeShellApplication,
  nix,
  jq,
  coreutils,
  clevis,
}:
writeShellApplication {
  name = "update-tang-disk-keys";
  meta.description = "Update disk encryption keys using Tang servers and TPM2";
  runtimeInputs = [
    nix
    jq
    coreutils
    clevis
  ];
  excludeShellChecks = [ "SC2029" ];
  text = ''
    set -euo pipefail

    # Check if a hostname is provided as an argument
    if [ $# -ne 1 ]; then
      echo "Usage: update-tang-disk-keys <hostname>"
      echo "Example: update-tang-disk-keys cortex"
      exit 1
    fi

    HOSTNAME="$1"

    # Find git repo root
    GIT_ROOT=$(git rev-parse --show-toplevel)

    # Create output directory if it doesn't exist
    OUTPUT_DIR="$GIT_ROOT/.secrets/host-keys/$HOSTNAME"
    mkdir -p "$OUTPUT_DIR"

    OUTPUT_FILE="$OUTPUT_DIR/zroot-key.jwe"

    # Function to extract Tang server URLs from existing JWE
    extract_tang_urls() {
      local jwe_file="$1"

      # Extract the outer SSS JWE
      local outer_header
      outer_header=$(cut -d . -f1 "$jwe_file" | basenc --base64url -d)

      # Navigate to the inner SSS structure and extract all Tang URLs
      echo "$outer_header" | jq -r '
        .clevis.sss.jwe[1] |
        split(".")[0] |
        @base64d |
        fromjson |
        .clevis.sss.jwe[] |
        split(".")[0] |
        @base64d |
        fromjson |
        select(.clevis.tang.url != null) |
        .clevis.tang.url
      '
    }

    # Check if output file already exists
    REUSE_PASSPHRASE=false
    if [ -f "$OUTPUT_FILE" ]; then
      echo "Existing encrypted key found at: $OUTPUT_FILE"
      echo ""
      echo "Configured Tang servers:"
      extract_tang_urls "$OUTPUT_FILE" | while read -r url; do
        echo "  - $url"
      done
      echo ""
      read -p "Decrypt and reuse existing passphrase? (Y/n): " -n 1 -r
      echo ""
      if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        REUSE_PASSPHRASE=true
      else
        read -p "Overwrite with new passphrase? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          echo "Aborted."
          exit 0
        fi
      fi
    fi

    # Discover Tang servers from Nix configuration
    # Get all hosts with role "server" and extract their first IP address
    mapfile -t TANG_SERVER_IPS < <(
      nix eval --json "$GIT_ROOT#hosts" \
        --apply "hosts: builtins.mapAttrs (name: host: { inherit (host) roles ipv4; }) (builtins.removeAttrs hosts [\"$HOSTNAME\"])" | \
      jq -r 'to_entries[] | select(.value.roles | contains(["unlock"])) | .value.ipv4[0]' | \
      sort
    )

    # Build array of Tang server URLs with port 7654
    TANG_SERVERS=()
    for ip in "''${TANG_SERVER_IPS[@]}"; do
      TANG_SERVERS+=("http://$ip:7654")
    done

    echo "Discovered ''${#TANG_SERVERS[@]} Tang servers:"
    for server in "''${TANG_SERVERS[@]}"; do
      echo "  - $server"
    done
    echo ""

    # Build Tang servers JSON array
    build_tang_array() {
      local tang_json="["
      local first=true
      for server in "''${TANG_SERVERS[@]}"; do
        if [ "$first" = true ]; then
          first=false
        else
          tang_json+=","
        fi
        tang_json+=$(jq -n --arg url "$server" '{"url": $url}')
      done
      tang_json+="]"
      echo "$tang_json"
    }

    # Calculate threshold: 2 of N Tang servers
    TANG_THRESHOLD=2

    # Build Clevis config: TPM2 OR (2 of N Tang servers)
    CLEVIS_CONFIG=$(jq -n \
      --argjson tang_pins "$(build_tang_array)" \
      --argjson threshold "$TANG_THRESHOLD" \
      '{
        "t": 2,
        "pins": {
          "tpm2": {},
          "sss": {
            "t": $threshold,
            "pins": {
              "tang": $tang_pins
            }
          }
        }
      }'
    )

    echo "Encrypting passphrase for $HOSTNAME with Clevis..."
    echo "Output will be written to: $OUTPUT_FILE"
    echo ""
    echo "CLEVIS_CONFIG="
    echo "$CLEVIS_CONFIG"
    echo

    # Get passphrase - either decrypt existing or prompt for new
    if [ "$REUSE_PASSPHRASE" = true ]; then
      echo "Decrypting existing passphrase from $HOSTNAME..."
      if ! PASSPHRASE=$(cat "$OUTPUT_FILE" | ssh "root@$HOSTNAME" "clevis decrypt"); then
        echo "Error: Failed to decrypt existing passphrase"
        exit 1
      fi
    else
      echo "Enter passphrase (input will be hidden):"
      read -rs PASSPHRASE
      echo ""
    fi

    # Verify passphrase is not empty
    if [ -z "$PASSPHRASE" ]; then
      echo "Error: Passphrase cannot be empty"
      exit 1
    fi

    # Encrypt on the target host - TPM2 access requires running on the actual hardware
    # The clevis output is captured and written locally
    if ! echo -n "$PASSPHRASE" | ssh "root@$HOSTNAME" "clevis encrypt sss '$CLEVIS_CONFIG' -y" > "$OUTPUT_FILE"; then
      echo "Error: Encryption failed"
      exit 1
    fi

    # Verify the output file is not empty
    if [ ! -s "$OUTPUT_FILE" ]; then
      echo "Error: Output file is empty"
      exit 1
    fi

    echo "Encryption complete: $OUTPUT_FILE"
    echo "File size: $(stat -c%s "$OUTPUT_FILE") bytes"
  '';
}
