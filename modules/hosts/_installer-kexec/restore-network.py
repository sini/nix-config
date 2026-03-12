#!/usr/bin/env python3
"""
Restore network configuration after kexec.
This reads saved network state and recreates systemd-networkd configuration.
"""

import json
import sys
from pathlib import Path


def restore_network(addrs_file, routes_v4_file, routes_v6_file, networkd_dir):
    """Restore network configuration from saved JSON files."""
    networkd_path = Path(networkd_dir)
    networkd_path.mkdir(parents=True, exist_ok=True)

    # Load saved network configuration
    try:
        with open(addrs_file) as f:
            addrs = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        print(f"Warning: Could not load {addrs_file}", file=sys.stderr)
        return

    # Process each interface
    for iface in addrs:
        ifname = iface.get("ifname")
        if not ifname or ifname == "lo":
            continue

        addr_info = iface.get("addr_info", [])
        if not addr_info:
            continue

        # Create .network file for this interface
        network_file = networkd_path / f"10-{ifname}.network"

        with open(network_file, "w") as f:
            f.write(f"[Match]\n")
            f.write(f"Name={ifname}\n\n")
            f.write(f"[Network]\n")

            # Add IP addresses
            for addr in addr_info:
                ip_addr = addr.get("local")
                prefix_len = addr.get("prefixlen")
                if ip_addr and prefix_len:
                    f.write(f"Address={ip_addr}/{prefix_len}\n")

        print(f"Created {network_file}")

    # Restore routes
    try:
        with open(routes_v4_file) as f:
            routes_v4 = json.load(f)

        # Add default gateway if present
        for route in routes_v4:
            if route.get("dst") == "default":
                gateway = route.get("gateway")
                if gateway:
                    # Add to first network file found
                    for net_file in networkd_path.glob("10-*.network"):
                        with open(net_file, "a") as f:
                            f.write(f"Gateway={gateway}\n")
                        print(f"Added gateway {gateway} to {net_file}")
                        break
    except (FileNotFoundError, json.JSONDecodeError):
        print(f"Warning: Could not load routes", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) != 5:
        print(f"Usage: {sys.argv[0]} <addrs.json> <routes-v4.json> <routes-v6.json> <networkd-dir>")
        sys.exit(1)

    restore_network(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
