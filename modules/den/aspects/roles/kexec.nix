_: {
  den.aspects.roles.kexec = {
    colmena-tags = [ "kexec" ];
    nixos =
      {
        config,
        pkgs,
        lib,
        modulesPath,
        ...
      }:
      let
        # Automatically collect all network driver modules from facter hardware report
        baseNetworkDriverModules = lib.unique (
          lib.flatten (
            lib.filter (x: x != null) (
              map (iface: iface.driver_modules or null) config.facter.report.hardware.network_interface
            )
          )
        );

        moduleDependencies = {
          "mlx4_core" = [ "mlx4_en" ];
          "iwlwifi" = [ "iwlmvm" ];
        };

        additionalDriverModules = lib.unique (
          lib.flatten (map (mod: moduleDependencies.${mod} or [ ]) baseNetworkDriverModules)
        );

        networkDriverModules = lib.unique (baseNetworkDriverModules ++ additionalDriverModules);
      in
      {
        imports = [
          (modulesPath + "/installer/netboot/netboot-minimal.nix")
        ];

        boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-server-lto;

        system.stateVersion = lib.mkDefault "25.11";

        fileSystems."/" = {
          device = "tmpfs";
          fsType = "tmpfs";
          options = [ "mode=0755" ];
        };
        impermanence.enable = false;

        environment.systemPackages = [
          pkgs.nixos-install-tools
          pkgs.jq
          pkgs.rsync
          pkgs.nixos-facter
          pkgs.disko
        ];

        networking.firewall.enable = lib.mkForce false;
        documentation.enable = lib.mkForce false;
        documentation.man.man-db.enable = lib.mkForce false;

        boot = {
          loader.grub.enable = lib.mkForce false;

          supportedFilesystems.bcachefs = lib.mkDefault true;

          supportedFilesystems.zfs = true;
          zfs.package = pkgs.zfs_unstable;

          kernelParams = [
            "zswap.enabled=1"
            "zswap.max_pool_percent=50"
            "zswap.compressor=zstd"
            "zswap.zpool=zsmalloc"
          ];

          initrd = {
            systemd.emergencyAccess = true;

            compressor = "zstd";
            compressorArgs = [ "-12" ];

            availableKernelModules = [
              "bridge"
              "bonding"
              "8021q"
              "tpm_crb"
              "tpm_tis"
            ]
            ++ networkDriverModules;
          };
        };

        users.mutableUsers = lib.mkForce true;
        users.deterministicIds.system =
          let
            uid = 1100;
            gid = 1100;
            subUidStart = 100000 + ((uid - 1000) * 65536);
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
                startGid = subUidStart;
                count = 65536;
              }
            ];
          };

        # Build the kexec tarball (override the one from netboot-minimal.nix)
        system.build.kexecTarball = lib.mkForce (
          let
            kexecInstallerName = "nixos-kexec-installer-${config.networking.hostName}";
            iprouteStatic = pkgs.pkgsStatic.iproute2.override { iptables = null; };

            kexecRun = pkgs.writeScript "kexec-run" ''
              #!/usr/bin/env bash
              set -efu

              SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"

              echo "Loading ${config.networking.hostName} kexec image..."

              ip addr show
              ip route show

              "$SCRIPT_DIR/kexec" -l "$SCRIPT_DIR/bzImage" \
                --initrd="$SCRIPT_DIR/initrd" \
                --command-line="init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}"

              sync
              echo "Executing kexec..."
              exec "$SCRIPT_DIR/kexec" -e
            '';
          in
          pkgs.runCommand "kexec-tarball" { } ''
            mkdir kexec $out

            cp "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}" kexec/bzImage
            cp "${config.system.build.netbootRamdisk}/initrd" kexec/initrd

            cp "${pkgs.pkgsStatic.kexec-tools}/bin/kexec" kexec/kexec
            cp "${iprouteStatic}/bin/ip" kexec/ip

            cp "${kexecRun}" kexec/run
            chmod +x kexec/run

            tar -czvf $out/${kexecInstallerName}-${pkgs.stdenv.hostPlatform.system}.tar.gz kexec
          ''
        );
      };
  };
}
