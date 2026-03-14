# clevis-minimal

A minimal, cross-platform build of [Clevis](https://github.com/latchset/clevis) focused on Tang-based network encryption.

## Why This Fork Exists

The upstream Clevis package in nixpkgs has hard dependencies on Linux-only packages (cryptsetup, luksmeta, libpwquality, tpm2-tools), which prevents it from being used on Darwin (macOS) systems. This fork removes those dependencies to enable:

- **Darwin systems to provision NixOS hosts** with Tang-based disk encryption
- **Remote key management** from macOS workstations using `nix-flake-provision-keys` and `update-tang-disk-keys`
- **Cross-platform secret management** without requiring a Linux VM

## What We Changed

### Fork: [sini/clevis](https://github.com/sini/clevis) (`darwin-support` branch)

The package sources from our fork which contains the following upstream-ready patches:

1. **Remove unused `sys/epoll.h` include** from `clevis-encrypt-sss.c`
2. **Replace Linux `epoll` with POSIX `poll`** in `clevis-decrypt-sss.c` - functionally equivalent for the small fd counts clevis uses
3. **Replace `pipe2` with portable `pipe` + `fcntl`** in `sss.c` - safe because the program is single-threaded
4. **Make `cryptsetup` optional in test suite** - uses `subdir_done()` to skip LUKS tests when cryptsetup is unavailable

### Removed Linux-Only Dependencies

Removed from `buildInputs`:

- `cryptsetup` - LUKS disk encryption (Linux kernel feature)
- `luksmeta` - LUKS metadata management (Linux-specific)
- `libpwquality` - Password quality checking (primarily for PAM)
- `tpm2-tools` - TPM 2.0 support (hardware-specific)

### jose Darwin Fix

jose v14 is marked broken on Darwin in nixpkgs because its meson build passes
`-export-symbols-regex=^jose_.*` (a GNU ld flag) which Apple's clang linker doesn't
understand. We apply the upstream fix ([PR #163](https://github.com/latchset/jose/pull/163))
via `fetchpatch` and unmark it as broken.

### Distribution-Specific Patch

#### [0000-tang-timeout.patch](0000-tang-timeout.patch)

- Reduces `clevis-decrypt-tang` network timeout from 300s to 10s
- Prevents boot hangs when Tang servers are unreachable
- Source: https://github.com/latchset/clevis/issues/289
- Not upstreamed (distribution-specific preference)

### Disabled Tests

Tests are disabled because most require LUKS devices and cryptsetup, which aren't available in the Nix sandbox or on Darwin.

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

- **Upstream**: https://github.com/latchset/clevis
- **Fork**: https://github.com/sini/clevis (`darwin-support` branch)
- **Nixpkgs**: `pkgs/by-name/cl/clevis/package.nix`
- **Goal**: Merge Darwin patches upstream, at which point we can switch back to upstream source

## Maintenance Notes

When updating to new Clevis versions:

1. Rebase the `darwin-support` branch onto the new upstream tag
2. Update `rev` and `hash` in [package.nix](package.nix)
3. Check if upstream added new Linux-only dependencies
4. Test builds on both Linux and Darwin
5. Verify JWE generation still works for Tang encryption

## Related Files

- [nix-flake-provision-keys](../nix-flake-provision-keys/) - Uses this package to generate Tang JWE files
- [update-tang-disk-keys](../update-tang-disk-keys/) - Uses this package to re-encrypt with TPM2+Tang
- [modules/services/network-boot.nix](../../../modules/services/network-boot.nix) - Consumes JWE files at boot
