{ config, lib, ... }:
{
  sops.secrets."initrd_ssh_key" = {
    sopsFile = "${config.sops.defaultSopsFile}";
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
      systemd = {
        enable = true;
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
            "/etc/secrets/initrd/ssh_host_ed25519_key"
          ];
        };
      };
      secrets = {
        "/etc/secrets/initrd/ssh_host_ed25519_key" = lib.mkForce config.sops.secrets."initrd_ssh_key".path;
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
