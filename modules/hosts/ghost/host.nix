{ config, rootPath, ... }:
{
  flake.hosts.ghost = {
    ipv4 = [
      "10.10.10.7"
    ];
    ipv6 = [
      "2001:5a8:608c:4a00::7/64"
    ];
    environment = "dev";
    roles = [
      "server"
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-single
      cpu-intel
      gpu-intel
      podman
      performance
    ];
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIKFdt1A2dHlqDpSTvw85Iu6JHlVM/ERYAeMT95vLaVc";
    facts = ./facter.json;
    nixosConfiguration =
      {
        pkgs,
        ...
      }:
      {
        age.secrets.wpa-supplicant = {
          rekeyFile = rootPath + "/.secrets/user/wpa_supplicant-arcade.age";
        };

        age.secrets.wpa-supplicant-config = {
          rekeyFile = rootPath + "/.secrets/user/wpa_supplicant-config.age";
          path = "/root/.wpa_supplicant/wpa_supplicant-wlp1s0.conf";
          symlink = false;
        };
        boot.kernelPackages = pkgs.linuxPackages_cachyos-gcc; # TODO: https://github.com/chaotic-cx/nyx/issues/1178
        boot.initrd = {
          availableKernelModules = [
            "ccm"
            "ctr"
            "iwlmvm"
            "iwlwifi"
          ];
          systemd = {
            packages = [ pkgs.wpa_supplicant ];
            initrdBin = [ pkgs.wpa_supplicant ];
            targets.initrd.wants = [ "wpa_supplicant@wlp1s0.service" ];
            services."wpa_supplicant@".unitConfig.DefaultDependencies = false;
          };
          secrets."/etc/wpa_supplicant/wpa_supplicant-wlp1s0.conf" =
            /root/.wpa_supplicant/wpa_supplicant-wlp1s0.conf;
        };

        systemd.network = {
          networks."10-wlan" = {
            enable = true;
            matchConfig.Name = "wlp1s0";
            DHCP = "yes";
          };
        };

        networking.wireless = {
          enable = true;
          interfaces = [ "wlp1s0" ];
          secretsFile = config.age.secrets.wpa-supplicant.path;
          networks = {
            "The Arcade".pskRaw = "ext:psk_arcade";
          };
        };
        system.stateVersion = "25.05";
      };
  };
}
