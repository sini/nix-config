#!/usr/bin/env bash
# This script saves the current network configuration before kexec
# so it can be restored after the new kernel boots

set -eu -o pipefail

NETWORK_DIR="/root/network"

mkdir -p "$NETWORK_DIR"

echo "Saving network configuration to $NETWORK_DIR..."

# Save current IP addresses
ip -json addr show > "$NETWORK_DIR/addrs.json" || true

# Save current routes (IPv4 and IPv6)
ip -json -4 route show > "$NETWORK_DIR/routes-v4.json" || true
ip -json -6 route show > "$NETWORK_DIR/routes-v6.json" || true

# Save interface states
ip -json link show > "$NETWORK_DIR/links.json" || true

# Save DNS configuration
cp /etc/resolv.conf "$NETWORK_DIR/resolv.conf" || true

echo "Network configuration saved:"
ls -lh "$NETWORK_DIR"
