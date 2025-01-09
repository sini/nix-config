_: {
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "0"; # increase font size
      };

      efi.canTouchEfiVariables = true;
    };

    initrd = {
      availableKernelModules = [ "r8169" ];
      systemd.enable = true;
      systemd.users.root.shell = "/bin/cryptsetup-askpass";
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 22;
          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAOa9kFogEBODAU4YVs4hxfVx3b5ryBzct4HoAHgwPio"
          ];
          hostKeys = [
            "/etc/ssh/ssh_host_rsa_key"
            "/etc/ssh/ssh_host_ed25519_key"
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
}
