# clevis-minimal

A minimal, cross-platform build of [Clevis](https://github.com/latchset/clevis) focused on Tang-based network encryption.

## Why This Fork Exists

The upstream Clevis package in nixpkgs has hard dependencies on Linux-only packages (cryptsetup, luksmeta, libpwquality, tpm2-tools), which prevents it from being used on Darwin (macOS) systems. This fork removes those dependencies to enable:

- **Darwin systems to provision NixOS hosts** with Tang-based disk encryption
- **Remote key management** from macOS workstations using `nix-flake-provision-keys` and `update-tang-disk-keys`
- **Cross-platform secret management** without requiring a Linux VM

## What We Changed

### 1. Removed Linux-Only Dependencies

Removed from `buildInputs`:

- `cryptsetup` - LUKS disk encryption (Linux kernel feature)
- `luksmeta` - LUKS metadata management (Linux-specific)
- `libpwquality` - Password quality checking (primarily for PAM)
- `tpm2-tools` - TPM 2.0 support (hardware-specific)

### 2. Overrode `jose` Package

```nix
jose-unbroken = jose.overrideAttrs (old: {
  meta = old.meta // { broken = false; };
});
```

The `jose` package is marked as broken on Darwin in nixpkgs, but it builds fine and is only needed for JWE/JWK operations which are platform-agnostic.

### 3. Applied Patches

#### [0000-tang-timeout.patch](0000-tang-timeout.patch)

- Reduces `clevis-decrypt-tang` network timeout from 300s to 10s
- Prevents boot hangs when Tang servers are unreachable
- Source: https://github.com/latchset/clevis/issues/289

#### [0001-make-cryptsetup-optional.patch](0001-make-cryptsetup-optional.patch)

- Makes cryptsetup optional in test suite
- Skips LUKS2 tests when cryptsetup is unavailable
- Allows build to succeed without Linux-only dependencies

### 4. Disabled Tests

```nix
doCheck = false;
```

Most Clevis tests require LUKS devices and cryptsetup, which aren't available in the Nix sandbox or on Darwin.

## What Still Works

This minimal build fully supports:

✅ **Tang encryption** (`clevis encrypt tang`)
✅ **SSS (Shamir Secret Sharing)** (`clevis encrypt sss`)
✅ **JWE generation** for storing encrypted passphrases
✅ **Threshold encryption** (e.g., "2 of 3 Tang servers")

## What Doesn't Work

This minimal build excludes:

❌ **LUKS binding** (`clevis luks bind`) - requires cryptsetup (Linux-only)
❌ **TPM2 encryption** (`clevis encrypt tpm2`) - requires tpm2-tools (hardware-specific)
❌ **Dracut/systemd integration** - requires LUKS support

## Usage in This Flake

### From Darwin: Provision NixOS Hosts

```bash
# Generate SSH keys, disk encryption keys, and Tang JWE
nix-flake-provision-keys <hostname>

# Install NixOS remotely with encryption
nix-flake-install <hostname> <target-ip>
```

### From Darwin: Update Tang Keys on Running Hosts

```bash
# Re-encrypt disk password with TPM2 + Tang (executed on target host)
update-tang-disk-keys <hostname>
```

### On NixOS: Boot-Time Decryption

The generated JWE files are consumed by NixOS hosts via:

```nix
boot.initrd.clevis = {
  enable = true;
  useTang = true;
  devices.zroot.secretFile = /path/to/zroot-key.jwe;
};
```

## Relationship to Upstream

- **Upstream**: https://github.com/latchset/clevis/tree/v21
- **Nixpkgs**: `pkgs/by-name/cl/clevis/package.nix`
- **Fork status**: Tracking v21 with minimal patches
- **Update strategy**: Review upstream changes periodically, reapply patches as needed

## Maintenance Notes

When updating to new Clevis versions:

1. Update `version` and `hash` in [package.nix](package.nix)
1. Verify patches still apply cleanly (adjust line numbers if needed)
1. Check if upstream added new Linux-only dependencies
1. Test builds on both Linux and Darwin
1. Verify JWE generation still works for Tang encryption

## Related Files

- [nix-flake-provision-keys](../nix-flake-provision-keys/) - Uses this package to generate Tang JWE files
- [update-tang-disk-keys](../update-tang-disk-keys/) - Uses this package to re-encrypt with TPM2+Tang
- [modules/services/network-boot.nix](../../../modules/services/network-boot.nix) - Consumes JWE files at boot
