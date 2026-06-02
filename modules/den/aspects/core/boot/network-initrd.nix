# Network initrd unlock — initrd networking, Clevis+Tang LUKS/ZFS unlock, initrd SSH.
#
# Ported from main:modules/features/network-boot/ (network-boot.nix + initrd-bootstrap-keys.nix).
# Wireless (wpa_supplicant) support lives in the separate core.boot.wireless-initrd aspect.
_: {
  den.aspects.core.boot.network-initrd = {
    nixos =
      {
        config,
        pkgs,
        host,
        lib,
        resolved-users,
        ...
      }:
      let
        # SSH keys for users in the "wheel" or "admins" groups, from the
        # host-scoped resolved-users quirk collection.
        wheelSshKeys = lib.concatMap (
          u:
          lib.optionals (builtins.any (g: g == "admins" || g == "wheel") (u.groups or [ ])) (u.sshKeys or [ ])
        ) resolved-users;

        jweToken = builtins.path {
          path = host.secretPath + "/zroot-key.jwe";
          name = "zroot-key.jwe";
        };

        # Collect network driver modules from facter hardware report
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

        inherit (config.age) secrets;
      in
      {
        boot.initrd = {
          availableKernelModules = [
            "bridge"
            "bonding"
            "8021q"
            "tpm_crb"
            "tpm_tis"
          ]
          ++ networkDriverModules;

          clevis = lib.mkIf (config.boot.supportedFilesystems.zfs or false) {
            enable = true;
            useTang = true;
            devices.zroot.secretFile = jweToken;
          };

          systemd = {
            inherit (config.systemd) network;

            # Wait for clevis to do its thing before loading ZFS keys.
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
              authorizedKeys = wheelSshKeys;
              hostKeys = [
                secrets.initrd_host_ed25519_key.path
              ];
            };
          };
        };

        # Ensure valid initrd host key exists even on first boot
        system.activationScripts = {
          agenixEnsureInitrdHostkey = {
            text = ''
              [[ -e ${secrets.initrd_host_ed25519_key.path} ]] \
                || ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f ${secrets.initrd_host_ed25519_key.path}
            '';
            deps = [
              "agenixInstall"
              "users"
            ];
          };

          agenixChown.deps = [
            "agenixEnsureInitrdHostkey"
          ];
        };
      };

    persist = {
      files = [
        "/etc/ssh/initrd_host_ed25519_key"
        "/etc/ssh/initrd_host_ed25519_key.pub"
      ];
    };

    age-secrets = {
      age.secrets.initrd_host_ed25519_key.generator.script = "ssh-key";
    };
  };
}
