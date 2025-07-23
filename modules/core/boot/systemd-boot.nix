{
  # TODO: Split this configuration into multiple files and only have servers and desktops enable initrd network booting
  flake.modules = {
    nixos.systemd-boot =
      { config, lib, ... }:
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
            ];

            systemd = {
              enable = true;
              inherit (config.systemd) network;

              users.root.shell = "/bin/systemd-tty-ask-password-agent";
            };

            network = lib.mkIf config.systemd.network.enable {
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

          loader = {
            systemd-boot = {
              enable = true;
              configurationLimit = 10;
              consoleMode = "0"; # increase font size
            };

            efi = {
              canTouchEfiVariables = true;
              efiSysMountPoint = "/boot";
            };

          };

          kernelParams = [
            # For AMD Zen 4 this is no longer needed: https://www.phoronix.com/news/AMD-Zen-4-Mitigations-Off
            "mitigations=off"
            #"quiet"
            #"udev.log_level=3"
          ];

        };
      };
  };
}
