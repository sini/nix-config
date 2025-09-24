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
      "laptop"
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-single
      cpu-intel
      gpu-intel
      podman
    ];
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFWHgNoj7RnyW213YGiB8aQR3RK7HQvUmGHsqM0ZMsC4";
    facts = ./facter.json;
    nixosConfiguration =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        wiface = "wlp1s0";
      in
      {
        age.secrets.wpa-supplicant = {
          rekeyFile = rootPath + "/.secrets/user/wpa_supplicant-arcade.age";
        };

        age.secrets.wpa-supplicant-config = {
          rekeyFile = rootPath + "/.secrets/user/wpa_supplicant-config.age";
          path = "/root/.wpa_supplicant/wpa_supplicant-wlp1s0.conf";
          symlink = false;
        };

        system.activationScripts.agenixEnsureWpaSupplicantConfig = {
          text = ''
            [[ -e ${config.age.secrets.wpa-supplicant-config.path} ]] \
              || touch ${config.age.secrets.wpa-supplicant-config.path}
          '';
          deps = [
            "agenixInstall"
            "users"
          ];
        };
        system.activationScripts.agenixChown.deps = [ "agenixEnsureWpaSupplicantConfig" ];

        boot.kernelPackages = pkgs.linuxPackages_cachyos-gcc; # TODO: https://github.com/chaotic-cx/nyx/issues/1178

        boot.initrd = {
          availableKernelModules = [
            "ccm"
            "ctr"
            "iwlmvm"
            "iwlwifi"
            "cfg80211"
            "mwifiex"
            "mwifiex_pcie"
          ];
          systemd = {
            packages = [ pkgs.wpa_supplicant ];
            initrdBin = [
              pkgs.wpa_supplicant
              pkgs.coreutils
              pkgs.systemd
              pkgs.iproute2
            ];

            targets.initrd.wants = [ "wpa_supplicant@${wiface}.service" ];
            services."wpa_supplicant@".unitConfig.DefaultDependencies = false;

            network.wait-online.enable = lib.mkForce true;
            emergencyAccess = true;

          };
          secrets."/etc/wpa_supplicant/wpa_supplicant-${wiface}.conf" =
            "/root/.wpa_supplicant/wpa_supplicant-${wiface}.conf";
        };

        systemd.network = {
          networks."10-wlan" = {
            enable = true;
            matchConfig.Name = "wlp1s0";
            networkConfig.DHCP = "yes";
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
