{
  features.network-boot = {
    requires = [ "initrd-bootstrap-keys" ];
    linux =
      {
        config,
        lib,
        host,
        flakeLib,
        users,
        ...
      }:
      let
        zfsEnabled = host.hasFeature "zfs-root";
        jweToken = builtins.path {
          path = host.secretPath + "/zroot-key.jwe";
          name = "zroot-key.jwe";
        };

        # Automatically collect all network driver modules from facter hardware report
        baseNetworkDriverModules = lib.unique (
          lib.flatten (
            lib.filter (x: x != null) (
              map (iface: iface.driver_modules or null) config.facter.report.hardware.network_interface
            )
          )
        );

        # Map of kernel modules to their required dependencies
        moduleDependencies = {
          "mlx4_core" = [ "mlx4_en" ];
          "iwlwifi" = [ "iwlmvm" ];
        };

        # Expand modules to include their dependencies
        additionalDriverModules = lib.unique (
          lib.flatten (map (mod: moduleDependencies.${mod} or [ ]) baseNetworkDriverModules)
        );

        networkDriverModules = lib.unique (baseNetworkDriverModules ++ additionalDriverModules);
      in
      {
        boot.initrd = {
          availableKernelModules = [
            # Network utilities
            "bridge"
            "bonding"
            "8021q"
            # TPM support
            "tpm_crb"
            "tpm_tis"
          ]
          ++ networkDriverModules;

          clevis = lib.mkIf zfsEnabled {
            enable = true;
            useTang = true;
            devices.zroot.secretFile = jweToken;
          };

          systemd = {
            inherit (config.systemd) network;
            # users.root.shell = "/bin/systemd-tty-ask-password-agent";

            # Wait for clevis to do its thing...
            services.zfs-import-zroot.preStart = ''
              /bin/sleep 10
              ${lib.getExe config.boot.zfs.package} load-key -a
            '';
          };

          network = {
            enable = true;
            ssh = {
              enable = true;
              port = 22;
              authorizedKeys = flakeLib.users.getSshKeysForGroup users "wheel";
              hostKeys = [
                config.age.secrets.initrd_host_ed25519_key.path
              ];
            };
          };
        };
      };
  };
}
