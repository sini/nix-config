{
  flake.features.kexec = {
    # Exclude features that don't make sense for kexec installers
    # These require host-specific configuration or secrets
    excludes = [
      "network-boot"
      "systemd-boot"
      "avahi"
      "power-mgmt"
      "ssd"
    ];

    nixos =
      {
        config,
        pkgs,
        lib,
        modulesPath,
        ...
      }:
      {
        imports = [
          (modulesPath + "/installer/netboot/netboot-minimal.nix")
        ];

        boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-server-lto;

        # Set stateVersion for kexec installers
        system.stateVersion = lib.mkDefault "25.11";

        # Minimal filesystem configuration for kexec
        fileSystems."/" = {
          device = "tmpfs";
          fsType = "tmpfs";
          options = [ "mode=0755" ];
        };
        impermanence.enable = false;

        environment.systemPackages = [
          pkgs.nixos-install-tools
          # for zapping of disko
          pkgs.jq
          # for copying extra files of nixos-anywhere
          pkgs.rsync
          # alternative to nixos-generate-config
          # TODO: use nixpkgs again after next nixos release
          pkgs.nixos-facter

          pkgs.disko
        ];

        networking.firewall.enable = lib.mkForce false;
        documentation.enable = lib.mkForce false;
        documentation.man.man-db.enable = lib.mkForce false;

        # Boot configuration for kexec
        boot = {
          loader.grub.enable = lib.mkForce false;
          # loader.systemd-boot.enable = lib.mkForce false;

          # Enable bcachefs support
          supportedFilesystems.bcachefs = lib.mkDefault true;

          # use latest kernel we can support to get more hardware support
          supportedFilesystems.zfs = true;
          zfs.package = pkgs.zfs_unstable;

          # enable zswap to help with low memory systems
          kernelParams = [
            "zswap.enabled=1"
            "zswap.max_pool_percent=50"
            "zswap.compressor=zstd"
            # recommended for systems with little memory
            "zswap.zpool=zsmalloc"
          ];

          initrd = {
            # make it easier to debug boot failures
            systemd.emergencyAccess = true;

            # Use xz compression for faster boot
            compressor = "xz";

            # Ensure kernel modules are available for common network interfaces
            availableKernelModules = [
              "r8169" # Host: surge, burst, pulse
              "mlx4_core"
              "mlx4_en" # Hosts: uplink
              "atlantic" # Hosts: cortex
              "bridge"
              "bonding"
              "8021q"
              "tpm_crb" # TPM support
              "tpm_tis"
            ];
          };
        };
        # Allow mutable users for the ephemeral installer
        users.mutableUsers = lib.mkForce true;
        users.deterministicIds.nixos =
          let
            uid = 1100;
            gid = 1100;
            # Calculate subUid/subGid ranges: startUid = 100000 + ((uid - 1000) * 65536)
            subUidStart = 100000 + ((uid - 1000) * 65536);
            subGidStart = subUidStart;
          in
          {
            inherit uid gid;
            subUidRanges = [
              {
                startUid = subUidStart;
                count = 65536;
              }
            ];
            subGidRanges = [
              {
                startGid = subGidStart;
                count = 65536;
              }
            ];
          };
        # Build the kexec tarball (override the one from netboot-minimal.nix)
        system.build.kexecTarball = lib.mkForce (
          let
            kexecInstallerName = "nixos-kexec-installer-${config.networking.hostName}";
            iprouteStatic = pkgs.pkgsStatic.iproute2.override { iptables = null; };

            # Create a kexec run script
            kexecRun = pkgs.writeScript "kexec-run" ''
              #!/usr/bin/env bash
              set -efu

              # Get the directory where this script is located
              SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"

              echo "Loading ${config.networking.hostName} kexec image..."

              # Preserve network configuration
              ip addr show
              ip route show

              # Load and execute kexec
              "$SCRIPT_DIR/kexec" -l "$SCRIPT_DIR/bzImage" \
                --initrd="$SCRIPT_DIR/initrd" \
                --command-line="init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}"

              # Sync and execute
              sync
              echo "Executing kexec..."
              exec "$SCRIPT_DIR/kexec" -e
            '';
          in
          pkgs.runCommand "kexec-tarball" { } ''
            mkdir kexec $out

            # Copy kernel and initrd (using netbootRamdisk from netboot-minimal.nix)
            cp "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}" kexec/bzImage
            cp "${config.system.build.netbootRamdisk}/initrd" kexec/initrd

            # Copy static binaries
            cp "${pkgs.pkgsStatic.kexec-tools}/bin/kexec" kexec/kexec
            cp "${iprouteStatic}/bin/ip" kexec/ip

            # Copy run script
            cp "${kexecRun}" kexec/run
            chmod +x kexec/run

            # Create tarball
            tar -czvf $out/${kexecInstallerName}-${pkgs.stdenv.hostPlatform.system}.tar.gz kexec
          ''
        );
      };
  };
}
