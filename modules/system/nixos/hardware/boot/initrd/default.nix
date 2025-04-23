{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = {
    boot = {
      initrd = {
        availableKernelModules = [
          "r8169" # Host: surge, burst, pulse
          "mlx4_core"
          "mlx4_en" # Hosts: uplink, cortex
          "bonding"
          "tun"
          "tap"
          "bridge"
          "stp"
          "llc"
        ];

        systemd = {
          enable = true;

          initrdBin = with pkgs; [
            cryptsetup
          ];

          network = {
            enable = true;
            inherit (config.systemd.network) links;
            inherit (config.systemd.network) netdevs;
            inherit (config.systemd.network) networks;
          };

          targets.network-pre = {
            requires = [ "sys-subsystem-net-devices-${config.hardware.networking.interface}.device" ];
            after = [ "sys-subsystem-net-devices-${config.hardware.networking.interface}.device" ];
          };

          users.root.shell = "/bin/systemd-tty-ask-password-agent";
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

      loader = {
        systemd-boot = {
          enable = true;
          configurationLimit = 10;
          consoleMode = "0"; # increase font size
        };

        efi.canTouchEfiVariables = true;
      };

      tmp.cleanOnBoot = true;

      kernelParams = [
        # For AMD Zen 4 this is no longer needed: https://www.phoronix.com/news/AMD-Zen-4-Mitigations-Off
        "mitigations=off"
        #"quiet"
        #"udev.log_level=3"
      ];

      #plymouth.enable = true; # Display loading screen

      #consoleLogLevel = 0;
    };
  };
}
