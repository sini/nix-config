#!/usr/bin/env bash
set -eu -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Preparing to kexec into NixOS installer..."
echo ""
echo "This will replace the running kernel with the NixOS installer."
echo "You will be disconnected briefly while the system reboots into the installer."
echo ""

# Check if we're running from the kexec directory
if [[ ! -f "$SCRIPT_DIR/bzImage" ]] || [[ ! -f "$SCRIPT_DIR/initrd" ]]; then
    echo "Error: bzImage or initrd not found in $SCRIPT_DIR"
    exit 1
fi

# Save network configuration before kexec
echo "Saving current network configuration..."
NETWORK_DIR="/root/network"
mkdir -p "$NETWORK_DIR"

"$SCRIPT_DIR/ip" -json addr show > "$NETWORK_DIR/addrs.json" 2>/dev/null || true
"$SCRIPT_DIR/ip" -json -4 route show > "$NETWORK_DIR/routes-v4.json" 2>/dev/null || true
"$SCRIPT_DIR/ip" -json -6 route show > "$NETWORK_DIR/routes-v6.json" 2>/dev/null || true

echo "Network configuration saved to $NETWORK_DIR"

echo "Countdown: 6 seconds..."
for i in 6 5 4 3 2 1; do
    echo "$i..."
    sleep 1
done

echo "Loading new kernel and initrd..."

# Load the new kernel and initrd
# The @init@ and @kernelParams@ placeholders will be replaced during build
"$SCRIPT_DIR/kexec" \
    --load "$SCRIPT_DIR/bzImage" \
    --initrd="$SCRIPT_DIR/initrd" \
    --command-line="init=@init@ @kernelParams@"

echo "Executing kexec now!"

# Execute the loaded kernel
exec "$SCRIPT_DIR/kexec" -e
