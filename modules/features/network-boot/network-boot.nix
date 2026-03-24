{
  features.network-boot.linux =
    {
      config,
      lib,
      host,
      pkgs,
      ...
    }:
    let
      zfsEnabled = host.hasFeature "zfs-root";
      jweToken = builtins.path {
        path = host.secretPath + "/zroot-key.jwe";
        name = "zroot-key.jwe";
      };

      # Automatically collect all network driver modules from facter hardware report
      networkDriverModules = lib.unique (
        lib.flatten (
          lib.filter (x: x != null) (
            map (iface: iface.driver_modules or null) config.facter.report.hardware.network_interface
          )
        )
      );

      initrdBootstrapKeys = host.hasFeature "initrd-bootstrap-keys";
    in
    {
      boot = lib.mkIf (!initrdBootstrapKeys) {
        initrd = {
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
            emergencyAccess = true;

            # Wait for clevis to do its thing...
            services.zfs-import-zroot = {
              after = lib.mkForce [ "network.target" ];
              preStart = ''
                /bin/sleep 10
                ${lib.getExe config.boot.zfs.package} load-key -a
              '';
            };
          };

          network = {
            enable = true;
            ssh = {
              enable = true;
              port = 22;
              authorizedKeys =
                with lib;
                concatLists (
                  mapAttrsToList (
                    _name: user: if elem "wheel" user.extraGroups then user.openssh.authorizedKeys.keys else [ ]
                  ) config.users.users
                );
              hostKeys = [
                config.age.secrets.initrd_host_ed25519_key.path
              ];
            };
          };
        };
      };

      age.secrets.initrd_host_ed25519_key.generator.script = "ssh-key";

      # Make sure that there is always a valid initrd hostkey available that can be installed into
      # the initrd. When bootstrapping a system (or re-installing), agenix cannot succeed in decrypting
      # whatever is given, since the correct hostkey doesn't even exist yet. We still require
      # a valid hostkey to be available so that the initrd can be generated successfully.
      # The correct initrd host-key will be installed with the next update after the host is booted
      # for the first time, and the secrets were rekeyed for the the new host identity.
      system.activationScripts.agenixEnsureInitrdHostkey = {
        text = ''
          [[ -e ${config.age.secrets.initrd_host_ed25519_key.path} ]] \
            || ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f ${config.age.secrets.initrd_host_ed25519_key.path}
        '';
        deps = [
          "agenixInstall"
          "users"
        ];
      };
      system.activationScripts.agenixChown.deps = [ "agenixEnsureInitrdHostkey" ];
    };
}
