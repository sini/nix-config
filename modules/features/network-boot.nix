{ rootPath, ... }:
{
  flake.features.network-boot.nixos =
    {
      config,
      lib,
      activeFeatures,
      ...
    }:
    let
      zfsEnabled = lib.elem "zfs" activeFeatures;
      jweToken = builtins.path {
        path = rootPath + "/.secrets/host-keys/${config.networking.hostName}/zroot-key.jwe";
        name = "zroot-key.jwe";
      };
    in
    {
      boot = {

        initrd = {
          availableKernelModules = [
            "r8169" # Host: surge, burst, pulse
            "mlx4_core"
            "mlx4_en" # Hosts: uplink, cortex
            "bridge"
            "bonding"
            "8021q"
            "tpm_crb" # TPM support
            "tpm_tis"
          ];

          clevis = lib.mkIf zfsEnabled {
            enable = true;
            useTang = true;
            devices.zroot.secretFile = jweToken;
          };

          systemd = {
            inherit (config.systemd) network;
            users.root.shell = "/bin/systemd-tty-ask-password-agent";

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
    };
}
