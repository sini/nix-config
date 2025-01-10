{ config, lib, ... }:
{
  # Install boot keys
  environment.etc = {
    "secrets/initrd".source = ./boot-keys;
  };

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
        consoleMode = "0"; # increase font size
      };

      efi.canTouchEfiVariables = true;
    };

    initrd = {
      availableKernelModules = [ "r8169" ];
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 22;
          shell = "/bin/cryptsetup-askpass";
          authorizedKeys =
            with lib;
            concatLists (
              mapAttrsToList (
                _name: user: if elem "wheel" user.extraGroups then user.openssh.authorizedKeys.keys else [ ]
              ) config.users.users
            );
          hostKeys = [
            "/etc/ssh/ssh_host_ed25519_key"
            "/etc/ssh/ssh_host_rsa_key"
          ];
        };
      };
      secrets = {
        "/etc/ssh/ssh_host_ed25519_key" = lib.mkDefault ./boot-keys/ssh_host_ed25519_key;
        "/etc/ssh/ssh_host_rsa_key" = lib.mkDefault ./boot-keys/ssh_host_rsa_key;
      };
      verbose = false;
    };

    tmp.cleanOnBoot = true;

    kernelParams = [
      # For AMD Zen 4 this is no longer needed: https://www.phoronix.com/news/AMD-Zen-4-Mitigations-Off
      "mitigations=off"
      "quiet"
      "udev.log_level=3"
      "ip=dhcp"
    ];

    plymouth.enable = true; # Display loading screen

    consoleLogLevel = 0;

  };
}
