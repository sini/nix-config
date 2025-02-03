{
  config,
  lib,
  pkgs,
  ...
}:
{
  age.secrets.initrd_host_ed25519_key.generator.script = "ssh-ed25519";

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
            config.age.secrets.initrd_host_ed25519_key.path

          ];
        };
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
}
